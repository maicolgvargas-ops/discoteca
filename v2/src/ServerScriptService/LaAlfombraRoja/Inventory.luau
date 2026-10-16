--[[
	INVENTORY - inventario persistente de bebidas (objetos VIRTUALES y cosmeticos).

	Datos por jugador (DataStore, clave "u<UserId>"):
	  items     { [itemId] = unidades }          vouchers { [tier] = vales }
	  open      { [itemId] = sorbos restantes de la unidad abierta }
	  equipped  itemId o ""                       credential { id, issued }  (carnet FICTICIO del club)
	  receipts  { [PurchaseId] = os.time() }  LIBRO DE RECIBOS PAGADOS, duradero y SIN purga   rcount = n recibos   tg = concesiones de prueba Studio
	  v = version

	Garantias:
	  * BLOQUEO DE SESION (lease) entre servidores: al cargar, el servidor toma un "alquiler" dentro del propio
	    registro con UpdateAsync (lock = { o = token de sesion, e = caducidad }). Mientras dure, NINGUN otro
	    servidor carga ni escribe a ese jugador (espera, y si no se libera queda en solo lectura). El dueño lo
	    renueva con cada guardado/renovacion; si el servidor cae, caduca solo. Toda escritura comprueba en el
	    mismo UpdateAsync que el alquiler sigue siendo suyo; si no, no escribe y la sesion pasa a solo lectura.
	  * Las operaciones criticas (conceder una compra, canjear vales) se escriben con UpdateAsync
	    (lectura-modificacion-escritura atomica) y el recibo (PurchaseId) se guarda EN EL MISMO registro y
	    en la MISMA escritura que el inventario: o se guardan los dos o ninguno. Idempotentes por PurchaseId.
	  * Si el guardado falla o no tenemos el alquiler se DEVUELVE "failed": quien llama NO confirma el recibo
	    (ProcessReceipt devuelve NotProcessedYet y Roblox lo reintenta, tambien tras reconectar).
	  * Si la carga inicial falla o el registro esta alquilado por otro servidor, la sesion queda en
	    solo-lectura y NUNCA se sobrescribe lo guardado; se reintenta cada 15 s.
	  * Al salir se guarda y se LIBERA el alquiler en una sola escritura; al cerrar el servidor se liberan todos.
	  * El estado no critico (equipado, sorbos) se guarda por intervalo, al salir y al cerrar el servidor.
	  * Limite: la caducidad usa os.time() de cada servidor (relojes sincronizados por Roblox; el alquiler de
	    120 s deja margen de sobra). UpdateAsync es atomico por clave en Roblox; aqui solo se simula.
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
local storeNameUsed = nil
local storeKind = "none" -- "datastore" | "memory" (modo Studio temporal) | "none" (sin persistencia)
local sessions = {} -- [player] = session
local TOOL_ATTR = "AR_DrinkTool"
local serverId = "studio"
local sessionCounter = 0
local SIP_COOLDOWN = 1.5

local function isStudio()
	local ok, studio = pcall(function()
		return RunService:IsStudio()
	end)
	return ok and studio == true
end

-- almacen EN MEMORIA solo para el modo Studio temporal: mismas operaciones que usa este modulo, pero NADA se guarda
-- al cerrar la partida. Nunca se usa fuera de Studio.
local function newMemoryStore()
	local mem = {}
	local m = {}
	function m:GetAsync(key)
		return Util.deepCopy(mem[key])
	end
	function m:UpdateAsync(key, fn)
		local newV = fn(Util.deepCopy(mem[key]))
		if newV == nil then
			return nil
		end
		mem[key] = Util.deepCopy(newV)
		return Util.deepCopy(newV)
	end
	return m
end

-- Obtiene el almacen SIN abortar nunca: GetDataStore falla (p. ej. "You must publish this place to the web to access
-- DataStore") en Studio con un place sin publicar o sin acceso a la API. Devuelve true si hay almacen.
local function acquireStore()
	if store then
		return true
	end
	if Config.Data.StudioTemporaryMode == true then
		if isStudio() then
			store = newMemoryStore()
			storeKind = "memory"
			warn("[Inventory] MODO STUDIO TEMPORAL: el inventario vive en memoria y NO se guarda. Solo para probar tienda e inventario en Studio.")
			return true
		end
		warn("[Inventory] Config.Data.StudioTemporaryMode esta activo pero esto NO es Studio: se ignora (no hay modo temporal en produccion).")
	end
	-- en Studio SIEMPRE otro almacen: las pruebas jamas tocan los registros de produccion
	local storeName = isStudio() and Config.Data.StudioStoreName or Config.Data.StoreName
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if ok and res ~= nil then
		store = res
		storeKind = "datastore"
		storeNameUsed = storeName
		return true
	end
	storeKind = "none"
	if not Inventory._warnedStore then
		Inventory._warnedStore = true
		warn("[Inventory] SIN PERSISTENCIA: no se pudo obtener el DataStore (" .. tostring(res) .. "). Inventario y compras con Robux bloqueados; el resto del club funciona. En Studio: publica el place y activa 'Enable Studio Access to API Services', o usa Config.Data.StudioTemporaryMode para probar sin guardar.")
	end
	return false
end

function Inventory.storeName()
	return storeNameUsed
end

-- "datastore" | "memory" | "none"
function Inventory.persistence()
	return storeKind
end

local function newData()
	return { v = 1, items = {}, vouchers = {}, open = {}, equipped = "", receipts = {}, rcount = 0, tg = 0, credential = false }
end

local function normalize(d)
	if type(d) ~= "table" then
		d = newData()
	end
	d.v = 1
	for _, k in { "items", "vouchers", "open", "receipts" } do
		if type(d[k]) ~= "table" then
			d[k] = {}
		end
	end
	d.receiptOrder = nil -- campo antiguo (v2.0-v2.1.2): el orden ya no se usa porque nada se purga
	local n = 0
	for _ in d.receipts do
		n += 1
	end
	d.rcount = n -- siempre recalculado del propio libro: no puede desincronizarse
	if type(d.tg) ~= "number" then
		d.tg = 0
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
-- alquiler (lease) de la sesion
------------------------------------------------------------------------
local function leaseNow(s)
	return { o = s.token, e = os.time() + Config.Data.LeaseSeconds }
end

-- ¿el registro guardado sigue alquilado por ESTA sesion?
local function owns(old, s)
	return type(old.lock) == "table" and old.lock.o == s.token
end

-- perdimos el alquiler (otro servidor lo tomo): no escribimos mas; solo lectura y se recarga
local function handleLost(s)
	if s.lost then
		return
	end
	s.lost = true
	s.loaded = false
	s.readOnly = true
	s.dirty = false
	s.retryAt = os.clock() + 5
	warn("[Inventory] alquiler de sesion perdido para " .. s.player.Name .. ": solo lectura; se descartan cambios no guardados")
	task.spawn(function()
		Inventory.refreshTool(s.player)
		Remotes.fire(s.player, "ShopNotice", "State", Inventory.snapshot(s.player))
	end)
end

------------------------------------------------------------------------
-- carga / guardado
------------------------------------------------------------------------
-- Toma el alquiler y carga. Devuelve "ok" | "held" (otro servidor lo tiene vivo) | "error".
local function tryLoad(s)
	if not acquireStore() then
		s.unavailable = true
		return "error"
	end
	local info
	local uid = s.player.UserId
	local ok, res = retry(function()
		return store:UpdateAsync(s.key, function(old)
			old = normalize(old)
			local lk = old.lock
			if type(lk) == "table" and lk.o ~= s.token and (tonumber(lk.e) or 0) > os.time() then
				info = "held"
				return nil -- no se escribe nada
			end
			old.lock = leaseNow(s)
			if not old.credential then
				old.credential = Inventory.credentialFor(uid)
			end
			info = "ok"
			return old
		end)
	end)
	if not ok then
		s.unavailable = true
		return "error"
	end
	if info ~= "ok" or type(res) ~= "table" then
		return "held"
	end
	s.unavailable = false
	s.data = normalize(res)
	s.loaded = true
	s.readOnly = false
	s.lost = false
	s.blocked = false
	s.retryAt = nil
	s.dirty = false
	s.lastSave = os.clock()
	s.lastRenew = os.clock()
	return "ok"
end

-- libera el alquiler guardando el estado (una sola escritura). Asume el cerrojo local tomado.
local function unlock(s)
	if not s.loaded then
		return true
	end
	local snapshot = Util.deepCopy(s.data)
	local ok = retry(function()
		store:UpdateAsync(s.key, function(old)
			old = normalize(old)
			if not owns(old, s) then
				return nil -- ya no es nuestro: no tocar
			end
			for id, t in old.receipts do
				if snapshot.receipts[id] == nil then
					snapshot.receipts[id] = t -- el libro es una UNION: nunca se pierde un recibo guardado
				end
			end
			snapshot.rcount = nil
			snapshot.lock = nil
			return snapshot
		end)
	end)
	if ok then
		s.loaded = false
		s.dirty = false
	end
	return ok
end

function Inventory.load(player)
	sessionCounter += 1
	local s = {
		player = player, key = "u" .. player.UserId, data = newData(), loaded = false, readOnly = false, dirty = false, busy = false,
		lastSave = os.clock(), lastRenew = os.clock(), token = string.format("%s:%d:%d", serverId, sessionCounter, math.random(1, 2147483646)),
	}
	sessions[player] = s
	local deadline = os.clock() + Config.Data.LockWaitSeconds
	while true do
		local r = tryLoad(s)
		if r == "ok" then
			break
		end
		if s.gone then
			return s
		end
		if os.clock() >= deadline then
			s.readOnly = true
			s.blocked = (r == "held")
			s.retryAt = os.clock() + 15
			warn("[Inventory] " .. (s.blocked and "inventario en uso en otro servidor" or "no se pudo cargar el inventario") .. " de " .. player.Name .. ": solo lectura hasta reintentar")
			return s
		end
		if r == "error" and storeKind == "none" then
			s.readOnly = true
			s.retryAt = os.clock() + 15
			return s -- sin DataStore: no tiene sentido esperar
		end
		task.wait(r == "held" and Config.Data.LockRetrySeconds or 0.5)
	end
	if s.gone then -- el jugador se fue mientras esperabamos: devolver el alquiler
		withLock(s, function()
			unlock(s)
		end)
		sessions[player] = nil
	end
	return s
end

-- escribe el estado en cache (y renueva el alquiler). Asume el cerrojo local tomado.
-- force = true: tambien si no hay cambios (renovacion).
local function flush(s, force)
	if not s.loaded or (not s.dirty and not force) then
		return true
	end
	local snapshot = Util.deepCopy(s.data)
	local lost = false
	local ok = retry(function()
		store:UpdateAsync(s.key, function(old)
			old = normalize(old)
			if not owns(old, s) then
				lost = true
				return nil
			end
			for id, t in old.receipts do
				if snapshot.receipts[id] == nil then
					snapshot.receipts[id] = t -- el libro es una UNION: nunca se pierde un recibo guardado
				end
			end
			snapshot.rcount = nil
			snapshot.lock = leaseNow(s)
			return snapshot
		end)
	end)
	if lost then
		handleLost(s)
		return false
	end
	if ok then
		s.dirty = false
		s.lastSave = os.clock()
		s.lastRenew = os.clock()
		s.data.receipts = snapshot.receipts
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
		if s.readOnly and not s.busy and not s.gone then
			withLock(s, function()
				if not s.loaded then
					tryLoad(s)
				end
			end)
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
-- operaciones CRITICAS (atomicas con UpdateAsync, idempotentes, con alquiler)
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

-- Anota un recibo PAGADO en el libro. NUNCA purga. Devuelve true, o false + motivo si no cabe (fallo cerrado).
local function recordReceipt(data, id)
	if type(id) ~= "string" or id == "" or #id > Config.Data.MaxReceiptIdLength then
		return false, "id_invalid"
	end
	if data.receipts[id] ~= nil then
		return true
	end
	local n = 0
	for _ in data.receipts do
		n += 1
	end
	if n >= Config.Data.MaxReceipts then
		return false, "ledger_full"
	end
	data.receipts[id] = os.time()
	data.rcount = n + 1
	return true
end

-- Escritura critica: `mutate(old)` modifica el registro y devuelve true, o devuelve false/"x" para no escribir.
-- Comprueba el alquiler DENTRO del UpdateAsync. Devuelve ok, info.
local function criticalWrite(s, mutate)
	local info
	local lost = false
	local ok, newData = retry(function()
		return store:UpdateAsync(s.key, function(old)
			old = normalize(old)
			if not owns(old, s) then
				lost = true
				info = "lost"
				return nil
			end
			local res = mutate(old)
			if res ~= true then
				info = res
				return nil
			end
			old.lock = leaseNow(s)
			return old
		end)
	end)
	if lost then
		handleLost(s)
		return false, "lost"
	end
	if not ok then
		return false, "error"
	end
	if info ~= nil then
		return false, info -- el cambio no procedia (p. ej. vales insuficientes): no se escribio nada
	end
	return true, nil, newData
end

-- Concede `grant` ({vouchers={tier=n}, items={id=n}}). purchaseId evita la doble concesion.
-- Devuelve "granted" | "duplicate" | "failed".
-- opts.test = true: concesion GRATIS de prueba de Studio. NO lleva PurchaseId, NO entra en el libro de recibos pagados
-- (solo suma al contador `tg`) y solo se admite dentro de Studio. Un PurchaseId con prefijo "STUDIO-" nunca se admite
-- como recibo.
function Inventory.grant(player, grant, purchaseId, opts)
	local s = sessions[player]
	if not s or not s.loaded then
		return "failed"
	end
	local isTest = type(opts) == "table" and opts.test == true
	if isTest then
		if purchaseId ~= nil or not isStudio() then
			return "failed"
		end
	elseif type(purchaseId) ~= "string" or string.sub(purchaseId, 1, 7) == "STUDIO-" then
		return "failed" -- una compra real exige PurchaseId; los ids de prueba no son recibos
	end
	local result = "failed"
	withLock(s, function()
		if not s.loaded or (s.dirty and not flush(s)) then
			return
		end
		local dup = false
		local ok, why, newData = criticalWrite(s, function(old)
			if isTest then
				applyGrant(old, grant)
				old.tg = (old.tg or 0) + 1
				return true
			end
			if old.receipts[purchaseId] then
				dup = true
				return true -- ya concedido: se reescribe tal cual (solo renueva el alquiler)
			end
			local okR, why = recordReceipt(old, purchaseId)
			if not okR then
				return why -- ledger_full / id_invalid: NO se concede nada
			end
			applyGrant(old, grant) -- inventario y recibo en la MISMA escritura atomica
			return true
		end)
		if not ok then
			if why == "ledger_full" or why == "id_invalid" then
				warn("[Inventory] recibo NO registrado (" .. tostring(why) .. "): se devuelve NotProcessedYet. Revisa Config.Data.MaxReceipts / PurchaseId.")
			end
			return
		end
		if type(newData) ~= "table" then
			return
		end
		local cnt = newData.rcount or 0
		if not isTest and cnt >= Config.Data.MaxReceipts * Config.Data.ReceiptWarnFraction and not s.ledgerWarned then
			s.ledgerWarned = true
			warn(string.format("[Inventory] libro de recibos de %s al %d%% (%d/%d). Al llegar al tope se bloquean las compras nuevas.", s.player.Name, math.floor(100 * cnt / Config.Data.MaxReceipts), cnt, Config.Data.MaxReceipts))
		end
		s.data = normalize(newData)
		s.dirty = false
		s.lastSave, s.lastRenew = os.clock(), os.clock()
		ensureCredential(s)
		result = dup and "duplicate" or "granted"
	end)
	if result == "granted" then
		Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	end
	return result
end

-- ¿se puede ofrecer AHORA una compra nueva con Robux a este jugador? Solo si garantizamos guardar el recibo: DataStore real
-- (no memoria), sesion cargada con alquiler propio y hueco en el libro de recibos. Devuelve ok, motivo.
function Inventory.canTakePayment(player)
	local s = sessions[player]
	if storeKind ~= "datastore" then
		return false, "persistence"
	end
	if not s or not s.loaded or s.lost then
		return false, "not_loaded"
	end
	local n = 0
	for _ in s.data.receipts do
		n += 1
	end
	if n >= Config.Data.MaxReceipts then
		return false, "ledger_full"
	end
	return true
end

-- Canjea `qty` vales del tier del articulo por `qty` unidades. "ok" | "insufficient" | "failed".
function Inventory.redeem(player, itemId, qty)
	local item = Catalog.getItem(itemId)
	local s = sessions[player]
	if not item or not s or not s.loaded or type(qty) ~= "number" or qty < 1 then
		return "failed"
	end
	local tier = item.Tier
	local result = "failed"
	withLock(s, function()
		if not s.loaded or (s.dirty and not flush(s)) then
			return
		end
		local ok, info, newData = criticalWrite(s, function(old)
			if (old.vouchers[tier] or 0) < qty then
				return "insufficient"
			end
			old.vouchers[tier] -= qty
			if old.vouchers[tier] <= 0 then
				old.vouchers[tier] = nil
			end
			old.items[itemId] = (old.items[itemId] or 0) + qty
			return true
		end)
		if not ok then
			if info == "insufficient" then
				result = "insufficient"
			end
			return
		end
		if type(newData) ~= "table" then
			return
		end
		s.data = normalize(newData)
		s.dirty = false
		s.lastSave, s.lastRenew = os.clock(), os.clock()
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
		return { loaded = false, items = {}, vouchers = {}, open = {}, equipped = "", persistence = storeKind, temporary = storeKind == "memory", unavailable = storeKind == "none" }
	end
	local d = s.data
	return {
		loaded = s.loaded,
		readOnly = s.readOnly,
		blocked = s.blocked == true, -- el registro esta alquilado por otro servidor
		unavailable = s.unavailable == true, -- sin persistencia (DataStore no disponible)
		temporary = storeKind == "memory", -- modo Studio temporal: NO se guarda
		persistence = storeKind,
		lost = s.lost == true,
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

-- sale el jugador: guarda y LIBERA el alquiler en una sola escritura
function Inventory.release(player)
	local s = sessions[player]
	if not s then
		return
	end
	s.gone = true
	local ok = true
	if s.loaded then
		withLock(s, function()
			ok = unlock(s)
		end)
	end
	if not ok then
		warn("[Inventory] no se pudo liberar el alquiler de " .. player.Name .. ": caducara solo en <= " .. Config.Data.LeaseSeconds .. " s")
	end
	sessions[player] = nil
end

-- cierre del servidor: guarda y libera TODOS los alquileres en paralelo (BindToClose dispone de ~30 s)
function Inventory.releaseAll()
	local pending = 0
	for _, s in table.clone(sessions) do
		pending += 1
		task.spawn(function()
			Inventory.release(s.player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		task.wait(0.1)
		waited += 0.1
	end
end

function Inventory.flushAll()
	for _, s in table.clone(sessions) do
		withLock(s, function()
			flush(s)
		end)
	end
end

function Inventory.init()
	local okJ, jid = pcall(function()
		return game.JobId
	end)
	if okJ and type(jid) == "string" and jid ~= "" then
		serverId = jid
	end
	acquireStore() -- nunca aborta: sin DataStore el modulo queda en "none" y bloquea inventario/compras
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
			if s.gone or s.busy then
				continue
			end
			if s.retryAt and now >= s.retryAt and not s.loaded then
				task.spawn(function()
					local done = false
					withLock(s, function()
						done = (not s.loaded) and tryLoad(s) == "ok"
					end)
					if done then
						Inventory.refreshTool(s.player)
						Remotes.fire(s.player, "ShopNotice", "State", Inventory.snapshot(s.player))
					elseif not s.loaded then
						s.retryAt = os.clock() + 15
					end
				end)
			elseif s.loaded then
				local renewDue = now - s.lastRenew >= Config.Data.RenewSeconds
				local saveDue = s.dirty and now - s.lastSave >= Config.Data.AutosaveSeconds
				if renewDue or saveDue then
					task.spawn(function()
						withLock(s, function()
							flush(s, true)
						end)
					end)
				end
			end
		end
	end)
	game:BindToClose(function()
		Inventory.releaseAll()
	end)
end

-- solo para pruebas del simulador
function Inventory._reset()
	sessions = {}
end

return Inventory
