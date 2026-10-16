--[[
	PURCHASES - compras REPETIBLES con Robux (Developer Products) y atencion de la tienda.

	* UN SOLO manejador de MarketplaceService.ProcessReceipt para todo (tambien futuras compras:
	  Purchases.registerHandler(productId, fn)). No se da nada por PromptProductPurchaseFinished.
	* ProcessReceipt valida PlayerId/ProductId/PurchaseId, concede de forma atomica e idempotente
	  (Inventory.grant) y SOLO devuelve PurchaseGranted si el guardado ha ido bien; si falla devuelve
	  NotProcessedYet y Roblox lo reintenta (al reconectar tambien): no se pierde ninguna compra.
	* ProductId = 0 en Catalog.Products => esa compra con Robux esta DESACTIVADA (no se ofrece).
	* MODO DE PRUEBA EN STUDIO (Config.Purchases.StudioTestMode): concede GRATIS y sin Robux; exige
	  RunService:IsStudio(), asi que aunque se deje en true en produccion no hace nada.
	* El cliente nunca decide precios, productos, cantidades concedidas ni el recibo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Util = require(Shared.Util)
local Inventory = require(script.Parent.Inventory)
local Remotes = require(script.Parent.Remotes)

local Purchases = {}

local handlers = {} -- [productId] = function(player, receiptInfo) -> "granted" | "duplicate" | "failed"
local pending = {} -- [player] = { itemId, tier, remaining, t }
local studioCounter = 0
local nearShop = function(_player)
	return true
end

function Purchases.setNearShop(fn)
	nearShop = fn
end

-- manejador de un producto: los registrados a mano o, si no, el que concede el Grant del catalogo
-- (se resuelve al procesar el recibo, asi un ProductId nuevo funciona sin reiniciar)
local function handlerFor(productId)
	if handlers[productId] then
		return handlers[productId]
	end
	local p = Catalog.productById(productId)
	if p and p.Grant then
		return function(player, info)
			return Inventory.grant(player, p.Grant, info.PurchaseId)
		end
	end
	return nil
end

function Purchases.registerHandler(productId, fn)
	assert(type(productId) == "number" and productId > 0, "ProductId invalido")
	handlers[productId] = fn
end

function Purchases.studioMode()
	local okS, studio = pcall(function()
		return RunService:IsStudio()
	end)
	return Config.Purchases.StudioTestMode == true and okS and studio == true
end

local function productFor(tier)
	return Catalog.productForTier(tier)
end

-- ¿se puede comprar este tier ahora? (producto enlazado o modo de prueba de Studio)
local function purchasable(tier)
	local p = productFor(tier)
	return p ~= nil and (p.ProductId ~= 0 or Purchases.studioMode())
end

function Purchases.productView()
	local out = {}
	for tier in Catalog.Tiers do
		local p = productFor(tier)
		out[tier] = { productId = p and p.ProductId or 0, available = purchasable(tier) }
	end
	return out
end

------------------------------------------------------------------------
-- ProcessReceipt
------------------------------------------------------------------------
local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

function Purchases.processReceipt(info)
	local okCall, decision = pcall(function()
		if type(info) ~= "table" or type(info.PlayerId) ~= "number" or type(info.ProductId) ~= "number" or type(info.PurchaseId) ~= "string" or info.PurchaseId == "" then
			warn("[Purchases] recibo con formato invalido: se deja sin procesar")
			return NOT_YET
		end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return NOT_YET -- se reintentara cuando el jugador vuelva a entrar
		end
		local handler = handlerFor(info.ProductId)
		if not handler then
			warn("[Purchases] ProductId sin manejador: " .. tostring(info.ProductId))
			return NOT_YET
		end
		if not Inventory.waitLoaded(player, 10) then
			return NOT_YET
		end
		local status = handler(player, info)
		if status == "granted" or status == "duplicate" then
			task.spawn(function()
				Purchases.advance(player)
			end)
			return GRANTED
		end
		return NOT_YET
	end)
	if not okCall then
		warn("[Purchases] error procesando recibo: " .. tostring(decision))
		return NOT_YET
	end
	return decision
end

------------------------------------------------------------------------
-- compra de un articulo (flujo: vales existentes -> comprar los que falten -> canjear)
------------------------------------------------------------------------
local function toast(player, text)
	Remotes.fire(player, "ShopNotice", "Toast", text)
end

-- canjea los vales disponibles y, si faltan, ofrece el siguiente producto
function Purchases.advance(player)
	local pen = pending[player]
	if not pen then
		return
	end
	if os.clock() - pen.t > Config.Purchases.PromptTimeout then
		pending[player] = nil
		return
	end
	local inv = Inventory.get(player)
	if not inv then
		return
	end
	local have = inv.vouchers[pen.tier] or 0
	local n = math.min(have, pen.remaining)
	if n > 0 then
		local r = Inventory.redeem(player, pen.itemId, n)
		if r == "ok" then
			pen.remaining -= n
			local item = Catalog.getItem(pen.itemId)
			toast(player, string.format("Has canjeado %d × %s", n, Catalog.displayName(item)))
		else
			toast(player, "No se pudo canjear ahora. Tus vales siguen guardados.")
			pending[player] = nil
			return
		end
	end
	if pen.remaining <= 0 then
		pending[player] = nil
		return
	end
	local product = productFor(pen.tier)
	if not product or not purchasable(pen.tier) then
		pending[player] = nil
		toast(player, "La compra con Robux aún no está disponible.")
		return
	end
	if Purchases.studioMode() then
		-- prueba en Studio: GRATIS, sin Robux ni recibo de Roblox
		studioCounter += 1
		local pid = string.format("STUDIO-%d-%d-%d", player.UserId, studioCounter, os.time())
		local status = Inventory.grant(player, product.Grant, pid)
		if status == "failed" then
			pending[player] = nil
			toast(player, "No se pudo guardar (prueba Studio).")
			return
		end
		return Purchases.advance(player)
	end
	MarketplaceService:PromptProductPurchase(player, product.ProductId)
end

function Purchases.begin(player, itemId, qty)
	local item = Catalog.getItem(itemId)
	local q = Util.intInRange(qty, 1, Config.Shop.MaxQty)
	if not item or not q then
		return false
	end
	local inv = Inventory.get(player)
	if not inv then
		toast(player, "Tu inventario aún no está disponible. Inténtalo en unos segundos.")
		return false
	end
	local have = inv.vouchers[item.Tier] or 0
	if have < q and not purchasable(item.Tier) then
		toast(player, "La compra con Robux todavía no está activada en este servidor.")
		return false
	end
	pending[player] = { itemId = itemId, tier = item.Tier, remaining = q, t = os.clock() }
	Purchases.advance(player)
	return true
end

-- Atiende los mensajes del remoto "Shop" (client -> server). Valida TODO.
function Purchases.handleShop(player, action, a, b)
	if not Remotes.allow(player, "Shop", Config.Shop.MaxRequestsPerSecond) then
		return
	end
	if type(action) ~= "string" then
		return
	end
	if action == "State" then
		Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	elseif action == "Buy" then
		if type(a) ~= "string" then
			return
		end
		if not nearShop(player) then
			toast(player, "Acércate a un bartender o a la barra para pedir.")
			return
		end
		Purchases.begin(player, a, b)
	elseif action == "Cancel" then
		pending[player] = nil
	elseif action == "Equip" then
		if type(a) == "string" and Inventory.equip(player, a) then
			Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
		else
			toast(player, "No tienes ese artículo.")
		end
	elseif action == "Stow" then
		Inventory.stow(player)
		Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
	end
end

function Purchases.init(remotes)
	MarketplaceService.ProcessReceipt = Purchases.processReceipt
	-- solo limpieza de la interfaz: NUNCA concede nada
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		local player = Players:GetPlayerByUserId(userId)
		if player and not isPurchased then
			pending[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		Remotes.forget(player)
	end)
	remotes.Shop.OnServerEvent:Connect(function(player, action, a, b)
		Purchases.handleShop(player, action, a, b)
	end)
end

function Purchases._pending(player)
	return pending[player]
end

return Purchases
