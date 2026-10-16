-- PRUEBAS MODO STUDIO TEMPORAL (simulador): inventario en memoria, explicito y separado de produccion. NO es Studio real.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
local function run(seconds, dt) for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end end
print("\n=== PRUEBAS MODO STUDIO TEMPORAL v2 ===")

local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog = require(Shared.Config), require(Shared.Catalog)
local PROD = true
Config.Data.StudioTemporaryMode = true
Config.Purchases.StudioTestMode = true
__isStudio = not PROD
__ds.getFails = 1e9 -- ademas el DataStore real falla
local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
local okRun, errRun = pcall(function() __runScript(SS) end)
check("el servidor arranca sin abortar", okRun, errRun)
local Inventory, Purchases = require(SS.Inventory), require(SS.Purchases)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local R = __replicated:FindFirstChild("AlfombraRemotes")
local function find(n) for _, d in club:GetDescendants() do if d.Name == n then return d end end end
local function makeP(name, id)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, Vector3.new(0, 3, 91), "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local p = makeP("Tester", 101)
if PROD then
	check("FUERA de Studio el modo temporal se IGNORA (sin persistencia, nada en memoria)", Inventory.persistence() == "none" and Inventory.get(p) == nil and Inventory.snapshot(p).temporary == false)
	check("...y StudioTestMode tampoco concede nada fuera de Studio", Purchases.studioMode() == false)
else
	check("persistencia = memory y el snapshot lo marca como temporal (para el aviso en pantalla)", Inventory.persistence() == "memory" and Inventory.snapshot(p).temporary == true and Inventory.snapshot(p).loaded == true)
	local shop = (function() for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then return d.Parent.CFrame.Position end end end)()
	p.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	R.Shop.OnServerEvent:_fire(p, "Buy", "champana_dom", 2)
	run(1, 0.1)
	check("comprar en modo de prueba GRATIS concede en memoria (sin Robux)", Inventory.get(p).items.champana_dom == 2 and #__market._prompts == 0)
	check("NO se ha escrito nada en ningun DataStore (no se finge persistencia)", next(__ds.stores) == nil)
	Inventory.equip(p, "champana_dom")
	check("equipar y beber funcionan en memoria", Inventory.get(p).equipped == "champana_dom")
	Catalog.Products[1].ProductId = 555
	local dec = __market.ProcessReceipt({ PlayerId = 101, ProductId = 555, PurchaseId = "R-1", CurrencySpent = 0, CurrencyType = "Robux" })
	check("un recibo REAL de Robux sigue sin confirmarse en modo temporal (NotProcessedYet)", dec == Enum.ProductPurchaseDecision.NotProcessedYet and (Inventory.get(p).vouchers.bottle or 0) == 0)
	Config.Purchases.StudioTestMode = false
	R.Shop.OnServerEvent:_fire(p, "Buy", "champana_veuve", 1)
	run(0.5, 0.1)
	check("sin StudioTestMode no hay forma de comprar con Robux en modo temporal (no se abre el cobro)", #__market._prompts == 0)
	-- reentrar: los datos en memoria se conservan mientras dure el servidor (y solo eso)
	__removePlayer(p)
	local p2 = makeP("Tester", 101)
	check("al reentrar en el mismo servidor los datos temporales siguen (solo memoria)", Inventory.get(p2) ~= nil and Inventory.get(p2).items.champana_dom == 2 and next(__ds.stores) == nil)
end
print(string.format("\nRESULTADO STUDIO TEMPORAL%s: %d comprobaciones, %d fallo(s)", PROD and " (produccion)" or "", total, failures))
