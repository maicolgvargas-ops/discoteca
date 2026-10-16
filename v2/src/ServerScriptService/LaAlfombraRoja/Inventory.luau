--[[
	INVENTORY - inventario persistente de bebidas (objetos VIRTUALES y cosmeticos).

	Datos por jugador (DataStore, clave "u<UserId>"):
	  items     { [itemId] = unidades }          vouchers { [tier] = vales }
	  open      { [itemId] = sorbos restantes de la unidad abierta }
	  equipped  itemId o ""                       credential { id, issued }  (carnet FICTICIO del club)
	  receipts  { [PurchaseId] = os.time() } + receiptOrder (ultimos N)       v = version

	Garantias:
	  * Las operaciones criticas (conceder una compra, canjear vales) se escriben con UpdateAsync
	    (lectura-modificacion-escritura atomica sobre lo guardado) y son idempotentes por PurchaseId.
	  * Si el guardado falla se DEVUELVE "failed": quien llama NO debe confirmar el recibo.
	  * Si la carga inicial falla, la sesion queda en solo-lectura y NUNCA se sobrescribe lo guardado
	    con datos vacios; se reintenta la carga cada 15 s.
	  * El estado no critico (equipado, sorbos) se guarda por intervalo, al salir y al cerrar el servidor.
	  * Sin bloqueo de sesion entre servidores (ver README: para produccion con muchos servidores se
	    recomienda ProfileService o equivalente).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local DrinkModels = require(Shared.DrinkModels)
local Util = require(Shared.Util)
local Remotes = require(script.Parent.Remotes)

local Inventory = {}

local store
local sessions = {} -- [player] = session
local TOOL_ATTR = "AR_DrinkTool"
local SIP_COOLDOWN = 1.5

local function newData()
	return { v = 1, items = {}, vouchers = {}, open = {}, equipped = "", receipts = {}, receiptOrder = {}, credential = false }
end

local function normalize(d)
	if type(d) ~= "table" then
		d = newData()
	end
	d.v = 1
	for _, k in { "items", "vouchers", "open", "receipts", "receiptOrder" } do
		if type(d[k]) ~= "table" then
			d[k] = {}
		end
	end
	if type(d.equipped) ~= "string" then
		d.equipped = ""
	end
	if d.credential == nil then
		d.credential = false
	end
	return d
end

local function retry(fn)
	local lastErr
	for attempt = 1, Config.Data.Retries do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(0.5 * 2 ^ (attempt - 1))
	end
	return false, lastErr
end

-- carnet FICTICIO del club: un codigo derivado del UserId; no es un documento ni verifica nada
function Inventory.credentialFor(userId)
	local n = (userId * 2654435761 + 12345) % 16777216
	return { id = string.format("AR-%06X", n), issued = os.time() }
end

local function ensureCredential(s)
	if not s.data.credential then
		s.data.credential = Inventory.credentialFor(s.player.UserId)
		s.dirty = true
	end
end

local function withLock(s, fn)
	local waited = 0
	while s.busy do
		task.wait(0.05)
		waited += 0.05
		if waited > 30 then
			return nil, "timeout"
		end
	end
	s.busy = true
	local ok, err = pcall(fn)
	s.busy = false
	if not ok then
		warn("[Inventory] error en operacion: " .. tostring(err))
		return nil, err
	end
	return true
end

------------------------------------------------------------------------
-- carga / guardado
------------------------------------------------------------------------
local function tryLoad(s)
	local ok, res = retry(function()
		return store:GetAsync(s.key)
	end)
	if ok then
		s.data = normalize(res)
		s.loaded = true
		s.readOnly = false
		s.retryAt = nil
		ensureCredential(s)
		return true
	end
	return false
end

function Inventory.load(player)
	local s = { player = player, key = "u" .. player.UserId, data = newData(), loaded = false, readOnly = false, dirty = false, busy = false, lastSave = os.clock() }
	sessions[player] = s
	if not tryLoad(s) then
		s.readOnly = true
		s.retryAt = os.clock() + 15
		warn("[Inventory] no se pudo cargar el inventario de " .. player.Name .. ": solo lectura hasta reintentar")
	end
	return s
end

-- escribe el estado en cache conservando los recibos ya guardados. Asume el cerrojo tomado.
local function flush(s)
	if not s.loaded or not s.dirty then
		return true
	end
	local snapshot = Util.deepCopy(s.data)
	local ok = retry(function()
		store:UpdateAsync(s.key, function(old)
			old = normalize(old)
			for id, t in old.receipts do
				if snapshot.receipts[id] == nil then
					snapshot.receipts[id] = t
					table.insert(snapshot.receiptOrder, id)
				end
			end
			return snapshot
		end)
	end)
	if ok then
		s.dirty = false
		s.lastSave = os.clock()
		s.data.receipts = snapshot.receipts
		s.data.receiptOrder = snapshot.receiptOrder
	end
	return ok
end

function Inventory.flush(player)
	local s = sessions[player]
	if not s then
		return false
	end
	local okFlag = false
	withLock(s, function()
		okFlag = flush(s)
	end)
	return okFlag
end

function Inventory.waitLoaded(player, timeout)
	local s = sessions[player]
	if not s then
		return false
	end
	local waited = 0
	while not s.loaded and waited < (timeout or 20) do
		if s.readOnly and not s.busy then
			tryLoad(s)
		end
		if s.loaded then
			break
		end
		task.wait(0.5)
		waited += 0.5
	end
	return s.loaded
end

------------------------------------------------------------------------
-- operaciones CRITICAS (atomicas con UpdateAsync, idempotentes)
------------------------------------------------------------------------
local function applyGrant(data, grant)
	for tier, n in (grant.vouchers or {}) do
		if Catalog.Tiers[tier] and type(n) == "number" and n > 0 then
			data.vouchers[tier] = (data.vouchers[tier] or 0) + math.floor(n)
		end
	end
	for id, n in (grant.items or {}) do
		if Catalog.getItem(id) and type(n) == "number" and n > 0 then
			data.items[id] = (data.items[id] or 0) + math.floor(n)
		end
	end
end

local function recordReceipt(data, id)
	data.receipts[id] = os.time()
	table.insert(data.receiptOrder, id)
	while #data.receiptOrder > Config.Data.MaxReceipts do
		local old = table.remove(data.receiptOrder, 1)
		data.receipts[old] = nil
	end
end

-- Concede `grant` ({vouchers={tier=n}, items={id=n}}). purchaseId evita la doble concesion.
-- Devuelve "granted" | "duplicate" | "failed".
function Inventory.grant(player, grant, purchaseId)
	local s = sessions[player]
	if not s then
		return "failed"
	end
	local result = "failed"
	withLock(s, function()
		if s.loaded and s.dirty and not flush(s) then
			return
		end
		local info
		local ok, newData = retry(function()
			return store:UpdateAsync(s.key, function(old)
				old = normalize(old)
				if purchaseId and old.receipts[purchaseId] then
					info = "duplicate"
					return old
				end
				applyGrant(old, grant)
				if purchaseId then
					recordReceipt(old, purchaseId)
				end
				info = "granted"
				return old
			end)
		end)
		if not ok or type(newData) ~= "table" then
			return
		end
		s.data = normalize(newData)
		s.loaded, s.readOnly, s.dirty = true, false, false
		s.lastSave = os.clock()
		ensureCredential(s)
		result = info
	end)
	if result == "granted" then
		Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	end
	return result
end

-- Canjea `qty` vales del tier del articulo por `qty` unidades. "ok" | "insufficient" | "failed".
function Inventory.redeem(player, itemId, qty)
	local item = Catalog.getItem(itemId)
	local s = sessions[player]
	if not item or not s or type(qty) ~= "number" or qty < 1 then
		return "failed"
	end
	local tier = item.Tier
	local result = "failed"
	withLock(s, function()
		if s.loaded and s.dirty and not flush(s) then
			return
		end
		local info
		local ok, newData = retry(function()
			return store:UpdateAsync(s.key, function(old)
				old = normalize(old)
				if (old.vouchers[tier] or 0) < qty then
					info = "insufficient"
					return nil
				end
				old.vouchers[tier] -= qty
				if old.vouchers[tier] <= 0 then
					old.vouchers[tier] = nil
				end
				old.items[itemId] = (old.items[itemId] or 0) + qty
				info = "ok"
				return old
			end)
		end)
		if not ok then
			return
		end
		if info == "insufficient" then
			result = "insufficient"
			return
		end
		if type(newData) ~= "table" then
			return
		end
		s.data = normalize(newData)
		s.loaded, s.readOnly, s.dirty = true, false, false
		s.lastSave = os.clock()
		result = "ok"
	end)
	if result == "ok" then
		Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	end
	return result
end

------------------------------------------------------------------------
-- estado NO critico: equipar, guardar, sorbos (cache + guardado por intervalo)
------------------------------------------------------------------------
local function removeTools(player)
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, c in containers do
		if c then
			for _, ch in c:GetChildren() do
				if ch:IsA("Tool") and ch:GetAttribute(TOOL_ATTR) then
					ch:Destroy()
				end
			end
		end
	end
end

function Inventory.refreshTool(player)
	removeTools(player)
	local s = sessions[player]
	if not s or not s.loaded then
		return
	end
	local id = s.data.equipped
	if id == "" then
		return
	end
	local item = Catalog.getItem(id)
	if not item or (s.data.items[id] or 0) <= 0 then
		s.data.equipped = ""
		s.dirty = true
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local total = Catalog.servings(item)
	local tool = DrinkModels.makeTool(item, s.data.open[id] or total)
	tool:SetAttribute(TOOL_ATTR, true)
	tool.Activated:Connect(function()
		Inventory.sip(player, tool)
	end)
	tool.Parent = backpack
end

function Inventory.equip(player, itemId)
	local s = sessions[player]
	local item = Catalog.getItem(itemId)
	if not s or not s.loaded or not item or (s.data.items[itemId] or 0) <= 0 then
		return false
	end
	s.data.equipped = itemId
	s.dirty = true
	Inventory.refreshTool(player)
	return true
end

function Inventory.stow(player)
	local s = sessions[player]
	if not s or not s.loaded then
		return false
	end
	s.data.equipped = ""
	s.dirty = true
	removeTools(player)
	return true
end

-- un sorbo (consumo cosmetico): no afecta a nada mas que al inventario y al nivel del liquido
function Inventory.sip(player, tool)
	local s = sessions[player]
	if not s or not s.loaded then
		return false
	end
	local now = os.clock()
	if now - (s.lastSip or -100) < SIP_COOLDOWN then
		return false
	end
	local id = s.data.equipped
	if id == "" or tool:GetAttribute("ItemId") ~= id then
		return false
	end
	local item = Catalog.getItem(id)
	local owned = s.data.items[id] or 0
	if not item or owned <= 0 then
		return false
	end
	s.lastSip = now
	local total = Catalog.servings(item)
	local left = (s.data.open[id] or total) - 1
	local finishedUnit = false
	if left <= 0 then
		finishedUnit = true
		s.data.open[id] = nil
		owned -= 1
		if owned <= 0 then
			s.data.items[id] = nil
			s.data.equipped = ""
		else
			s.data.items[id] = owned
		end
	else
		s.data.open[id] = left
	end
	s.dirty = true
	if s.data.equipped == "" then
		tool:Destroy()
	elseif finishedUnit then
		DrinkModels.setLevel(tool, 1)
		tool:SetAttribute("Servings", total)
	else
		DrinkModels.setLevel(tool, left / total)
		tool:SetAttribute("Servings", left)
	end
	Remotes.fire(player, "ShopNotice", "Sip", id, finishedUnit)
	Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	return true
end

------------------------------------------------------------------------
-- consulta
------------------------------------------------------------------------
function Inventory.get(player)
	local s = sessions[player]
	return s and s.loaded and s.data or nil
end

function Inventory.snapshot(player)
	local s = sessions[player]
	if not s then
		return { loaded = false, items = {}, vouchers = {}, open = {}, equipped = "" }
	end
	local d = s.data
	return {
		loaded = s.loaded,
		readOnly = s.readOnly,
		items = Util.deepCopy(d.items),
		vouchers = Util.deepCopy(d.vouchers),
		open = Util.deepCopy(d.open),
		equipped = d.equipped,
		credential = d.credential and { id = d.credential.id } or nil,
	}
end

function Inventory.credential(player)
	local s = sessions[player]
	return s and s.loaded and s.data.credential or nil
end

------------------------------------------------------------------------
-- ciclo de vida
------------------------------------------------------------------------
local function onPlayerAdded(player)
	local s = Inventory.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		Inventory.refreshTool(player)
	end)
	if s.loaded then
		Inventory.refreshTool(player)
	end
	Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
end

function Inventory.release(player)
	local s = sessions[player]
	if not s then
		return
	end
	withLock(s, function()
		flush(s)
	end)
	sessions[player] = nil
end

function Inventory.flushAll()
	for _, s in table.clone(sessions) do
		withLock(s, function()
			flush(s)
		end)
	end
end

function Inventory.init()
	store = DataStoreService:GetDataStore(Config.Data.StoreName)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		Inventory.release(player)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 5 then
			return
		end
		acc = 0
		local now = os.clock()
		for _, s in sessions do
			if s.retryAt and now >= s.retryAt and not s.loaded and not s.busy then
				if tryLoad(s) then
					task.spawn(function()
						Inventory.refreshTool(s.player)
						Remotes.fire(s.player, "ShopNotice", "State", Inventory.snapshot(s.player))
					end)
				else
					s.retryAt = now + 15
				end
			end
			if s.loaded and s.dirty and now - s.lastSave >= Config.Data.AutosaveSeconds and not s.busy then
				task.spawn(Inventory.flush, s.player)
			end
		end
	end)
	game:BindToClose(function()
		Inventory.flushAll()
	end)
end

-- solo para pruebas del simulador
function Inventory._reset()
	sessions = {}
end

return Inventory
