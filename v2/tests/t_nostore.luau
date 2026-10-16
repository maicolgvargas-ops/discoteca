-- PRUEBAS SIN DATASTORE (simulador): GetDataStore LANZA ERROR ("You must publish this place to the web...").
-- El servidor NO debe abortar; inventario y cobros bloqueados; el resto del club funciona. NO es Studio real.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
local function run(seconds, dt) for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end end
print("\n=== PRUEBAS SIN DATASTORE v2 (GetDataStore lanza error) ===")

__ds.getFails = 1e9
__isStudio = true
local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
local okRun, errRun = pcall(function() __runScript(SS) end)
check("el Script principal NO aborta aunque GetDataStore lance error", okRun, errRun)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog = require(Shared.Config), require(Shared.Catalog)
local Inventory, Purchases = require(SS.Inventory), require(SS.Purchases)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local R = __replicated:FindFirstChild("AlfombraRemotes")
check("el club se construye y esta en Workspace", club ~= nil and #club:GetDescendants() > 3000)
check("remotos, cabina y tienda siguen inicializados (Control, Music, ProcessReceipt asignado)", R ~= nil and R:FindFirstChild("Shop") ~= nil and club:FindFirstChild("Control") ~= nil and club:FindFirstChild("Music") ~= nil and type(__market.ProcessReceipt) == "function")
check("persistencia = none", Inventory.persistence() == "none")
local function findAll(pat) local out = {} for _, d in club:GetDescendants() do if string.match(d.Name, pat) then table.insert(out, d) end end return out end
local function find(n) return findAll("^" .. n .. "$")[1] end
local function makeP(name, id, pos)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, pos or Vector3.new(0, 3, 91), "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local t0 = os.clock()
local p = makeP("Sin", 101)
check("un jugador entra sin esperar 20 s inutilmente y sin errores", os.clock() - t0 < 5 and Inventory.get(p) == nil)
local snap = Inventory.snapshot(p)
check("snapshot: sesion creada, sin persistencia, no temporal, solo lectura", snap.readOnly == true and snap.unavailable == true and snap.temporary == false and snap.persistence == "none" and snap.loaded == false)
check("grant/redeem/equip fallan sin escribir nada", Inventory.grant(p, { vouchers = { bottle = 1 } }, "X-1") == "failed" and Inventory.redeem(p, "champana_dom", 1) == "failed" and Inventory.equip(p, "champana_dom") == false and next(__ds.stores) == nil)
Catalog.Products[1].ProductId = 555
local dec = __market.ProcessReceipt({ PlayerId = 101, ProductId = 555, PurchaseId = "R-1", CurrencySpent = 0, CurrencyType = "Robux" })
check("ProcessReceipt -> NotProcessedYet (nunca se confirma un cobro sin persistencia)", dec == Enum.ProductPurchaseDecision.NotProcessedYet)
-- comprar en la tienda
local shop = (function() for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then return d.Parent.CFrame.Position end end end)()
p.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
local n0 = #__market._prompts
R.Shop.OnServerEvent:_fire(p, "Buy", "champana_dom", 1)
check("intentar comprar NO abre ninguna compra de Robux", #__market._prompts == n0)
run(40, 1)
check("tras reintentos periodicos sigue sin persistencia y sin errores", Inventory.get(p) == nil and Inventory.persistence() == "none")
-- el resto del club sigue
local gp = find("Guard_1").HumanoidRootPart.CFrame.Position
p.Character.HumanoidRootPart.CFrame = CFrame.new(gp + Vector3.new(0, 0, 4))
find("GuardPrompt").Triggered:_fire(p)
R.Social.OnServerEvent:_fire(p, "Credential", Inventory.credentialFor(101).id)
check("los guardias y la credencial siguen funcionando sin persistencia (acceso a la entrada intacto)", p:GetAttribute("AR_Access") == true)
local deskPos = find("LightDesk_Top").CFrame.Position
p.Character.HumanoidRootPart.CFrame = CFrame.new(deskPos.X, deskPos.Y + 4, deskPos.Z + 5)
find("LightPrompt").Triggered:_fire(p)
R.Control.OnServerEvent:_fire(p, "Preset", "DiscotecaOscura")
check("la cabina de luces sigue funcionando (preset Discoteca oscura)", club.Control:GetAttribute("Preset") == "DiscotecaOscura" and club.Control:GetAttribute("Follow") == true)
check("el jugador puede salir sin errores", pcall(function() __removePlayer(p) end))
for _, fn in __closeFns do fn() end
check("BindToClose sin almacen no falla", true)
-- DataStore disponible pero las operaciones fallan (place sin acceso a la API)
print(string.format("\nRESULTADO SIN DATASTORE: %d comprobaciones, %d fallo(s)", total, failures))
