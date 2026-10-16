--[[
	LA ALFOMBRA ROJA v2 - Script principal (servidor). Solo orquesta los modulos:

	  Build         construye el club (v1 convertido en modulo)
	  Extras        botellas 3D, cabina DJ detallada, pantallas, bartenders, guardias, bailarinas
	  Remotes       RemoteEvents con limite de frecuencia por jugador
	  Inventory     inventario persistente (DataStore) y Tools de bebida
	  Purchases     Developer Products (ProcessReceipt unico) y atencion de la tienda
	  Music         reproductor de la cabina (lista blanca)
	  Control       cabina: luces + musica, operador unico y permisos
	  Interactions  asientos, guardias/credencial, baile, chat

	Config y Catalog (en ReplicatedStorage/AlfombraShared) contienen todo lo configurable.
	Los LocalScripts del cliente estan en StarterPlayerScripts/LaAlfombraRojaClient.
]]

local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)

local Remotes = require(script.Remotes)
local Build = require(script.Build)
local Extras = require(script.Extras)
local Inventory = require(script.Inventory)
local Purchases = require(script.Purchases)
local Music = require(script.Music)
local Control = require(script.Control)
local Interactions = require(script.Interactions)

for _, problem in Catalog.validate() do
	warn("[LaAlfombraRoja] catalogo: " .. problem)
end

local remotes = Remotes.init()

-- con guardias el spawn queda en la acera, delante de la puerta (invisible: sin cuadrado en la alfombra)
local guards = Config.Guards.Enabled
local ctx = Build.run({
	spawn = (guards and Config.Guards.SpawnOutside) and { 0, 91 } or nil,
	shelfBottles = Extras.shelfBottles,
	vipShelfBottles = Extras.vipShelfBottles,
	djBooth = Extras.djBooth,
	extras = function(c)
		Extras.build(c, { guards = guards })
	end,
})

Music.init(ctx.club)
Control.init(ctx)
local report = Interactions.init(ctx)
ctx.club.Parent = Workspace

if Config.Shop.Enabled then
	Inventory.init()
	Purchases.init(remotes)
	Purchases.setNearShop(Interactions.nearShop)
end

local partCount = 0
for _, d in ctx.club:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
print(string.format("[LaAlfombraRoja] listo: %d partes, %d luces, %d asientos, perfil %s.", partCount, ctx.getLightCount(), report.seats, ctx.PROFILE_NAME))
if Music.count() == 0 then
	print("[LaAlfombraRoja] Musica: sin pistas en Config.Music.Tracks (opcional; ver README).")
end
for tier in Catalog.Tiers do
	local p = Catalog.productForTier(tier)
	if p and p.ProductId == 0 then
		print("[LaAlfombraRoja] Compras con Robux DESACTIVADAS para '" .. tier .. "': ProductId = 0 en Catalog.Products.")
	end
end
