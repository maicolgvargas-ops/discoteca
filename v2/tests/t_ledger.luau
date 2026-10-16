-- PRUEBAS DEL LIBRO DE RECIBOS (ledger) duradero (simulador): nada se purga, idempotencia tras el limite antiguo (300),
-- rejoin, reintentos, tope con fallo cerrado, recibos de prueba Studio separados de los pagados. NO es Studio real.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
local function run(seconds, dt) for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end end
print("\n=== PRUEBAS DEL LIBRO DE RECIBOS v2.1.3 ===")

__isStudio = true -- el servidor arranca en Studio: debe usar el DataStore de pruebas, NO el de produccion
local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog = require(Shared.Config), require(Shared.Catalog)
local Inventory, Purchases = require(SS.Inventory), require(SS.Purchases)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local R = __replicated:FindFirstChild("AlfombraRemotes")
local DS = Config.Data.StudioStoreName
local function rec(id) return __ds.stores[DS]["u" .. id] end
local function count(t) local n = 0 for _ in t do n += 1 end return n end
local function makeP(name, id)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, Vector3.new(0, 3, 91), "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local NOT, OK = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
local function receipt(pid, user) return { PlayerId = user, ProductId = 555, PurchaseId = pid, CurrencySpent = 0, CurrencyType = "Robux" } end
Catalog.Products[1].ProductId = 555 -- ProductId de PRUEBA solo en memoria

do -- ===================================================== almacenes separados
	check("en Studio el servidor usa el DataStore de PRUEBAS (nombre distinto del de produccion)", Inventory.storeName() == Config.Data.StudioStoreName and Config.Data.StudioStoreName ~= Config.Data.StoreName)
end

local p = makeP("Ana", 101)
local N = 350 -- por encima del limite antiguo de 300

do -- ===================================================== superar el limite antiguo sin olvidar recibos
	local allGranted = true
	for i = 1, N do
		if __market.ProcessReceipt(receipt("PAGO-" .. i, 101)) ~= OK then allGranted = false end
	end
	check(N .. " recibos unicos (> 300 antiguo) se conceden y confirman", allGranted and rec(101).vouchers.bottle == N, rec(101).vouchers.bottle)
	check("el libro conserva los " .. N .. " PurchaseId (nada purgado) y rcount coincide", count(rec(101).receipts) == N and rec(101).rcount == N and rec(101).receiptOrder == nil, count(rec(101).receipts))
	check("el PRIMER recibo sigue en el libro", rec(101).receipts["PAGO-1"] ~= nil and rec(101).receipts["PAGO-" .. N] ~= nil)
	local dec = __market.ProcessReceipt(receipt("PAGO-1", 101))
	check("repetir el PRIMER recibo (el mas antiguo) devuelve PurchaseGranted y NO incrementa el saldo", dec == OK and rec(101).vouchers.bottle == N and Inventory.get(p).vouchers.bottle == N)
	local ok = true
	for _, i in { 2, 17, 150, 299, 300, 301, 349 } do
		if __market.ProcessReceipt(receipt("PAGO-" .. i, 101)) ~= OK then ok = false end
	end
	check("repetir recibos antiguos (2, 17, 150, 299, 300, 301, 349) tampoco incrementa nada", ok and rec(101).vouchers.bottle == N and count(rec(101).receipts) == N)
end

do -- ===================================================== rejoin
	__removePlayer(p)
	check("al salir el libro y el saldo quedan guardados y el alquiler liberado", count(rec(101).receipts) == N and rec(101).vouchers.bottle == N and rec(101).lock == nil)
	p = makeP("Ana", 101)
	check("al volver a entrar se carga el libro completo", Inventory.get(p) ~= nil and count(Inventory.get(p).receipts) == N)
	check("tras el rejoin, el recibo MAS antiguo repetido (callback de Roblox) no vuelve a conceder", __market.ProcessReceipt(receipt("PAGO-1", 101)) == OK and Inventory.get(p).vouchers.bottle == N and rec(101).vouchers.bottle == N)
end

do -- ===================================================== reintentos y errores
	__ds.failures = 100
	local dec = __market.ProcessReceipt(receipt("NUEVO-1", 101))
	__ds.failures = 0
	check("DataStore caido: recibo nuevo -> NotProcessedYet y NI saldo NI libro cambian", dec == NOT and rec(101).receipts["NUEVO-1"] == nil and rec(101).vouchers.bottle == N and count(rec(101).receipts) == N)
	check("el reintento de Roblox lo concede una sola vez", __market.ProcessReceipt(receipt("NUEVO-1", 101)) == OK and __market.ProcessReceipt(receipt("NUEVO-1", 101)) == OK and rec(101).vouchers.bottle == N + 1 and count(rec(101).receipts) == N + 1)
	-- recibo mal formado / id enorme / prefijo de prueba
	check("PurchaseId demasiado largo -> NotProcessedYet (fallo cerrado) sin escribir", __market.ProcessReceipt(receipt(string.rep("x", Config.Data.MaxReceiptIdLength + 1), 101)) == NOT and rec(101).vouchers.bottle == N + 1)
	check("un id con prefijo STUDIO- jamas se acepta como recibo pagado", __market.ProcessReceipt(receipt("STUDIO-1-1-1", 101)) == NOT and rec(101).receipts["STUDIO-1-1-1"] == nil and rec(101).vouchers.bottle == N + 1)
end

do -- ===================================================== tope del libro: fallo cerrado, sin purgar
	local before = count(rec(101).receipts)
	local oldMax = Config.Data.MaxReceipts
	Config.Data.MaxReceipts = before -- el libro queda EXACTAMENTE lleno
	local dec = __market.ProcessReceipt(receipt("LLENO-1", 101))
	check("libro lleno: un recibo NUEVO -> NotProcessedYet, no se concede y NO se borra ningun id", dec == NOT and rec(101).receipts["LLENO-1"] == nil and count(rec(101).receipts) == before and rec(101).receipts["PAGO-1"] ~= nil and rec(101).vouchers.bottle == N + 1)
	check("libro lleno: un recibo YA conocido sigue devolviendo PurchaseGranted sin conceder", __market.ProcessReceipt(receipt("PAGO-1", 101)) == OK and __market.ProcessReceipt(receipt("NUEVO-1", 101)) == OK and rec(101).vouchers.bottle == N + 1)
	local okPay, why = Inventory.canTakePayment(p)
	check("libro lleno: canTakePayment = false (ledger_full)", okPay == false and why == "ledger_full", why)
	-- tienda: no se abre ningun prompt nuevo
	local shop = (function() for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then return d.Parent.CFrame.Position end end end)()
	p.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	-- gastamos los vales para forzar una compra nueva
	Inventory.get(p).vouchers.bottle = 0
	local n0 = #__market._prompts
	-- (el saldo real vive en el DataStore: lo dejamos a cero ahi tambien)
	rec(101).vouchers.bottle = 0
	Inventory.waitLoaded(p, 1)
	R.Shop.OnServerEvent:_fire(p, "Buy", "champana_dom", 1)
	run(1, 0.1)
	check("libro lleno: la tienda NO ofrece ningun cobro nuevo (cero PromptProductPurchase)", #__market._prompts == n0)
	Config.Data.MaxReceipts = oldMax
	check("con hueco otra vez se vuelve a poder ofrecer la compra", (Inventory.canTakePayment(p)) == true)
	R.Shop.OnServerEvent:_fire(p, "Buy", "champana_dom", 1)
	run(1, 0.1)
	check("...y se abre el cobro del producto correcto", #__market._prompts == n0 + 1 and __market._prompts[#__market._prompts].productId == 555)
end

do -- ===================================================== migracion de registros antiguos (receiptOrder, 300 ids)
	local old = { v = 1, items = {}, vouchers = { bottle = 3 }, open = {}, equipped = "", receipts = {}, receiptOrder = {}, credential = false }
	for i = 1, 300 do old.receipts["VIEJO-" .. i] = 1000 + i table.insert(old.receiptOrder, "VIEJO-" .. i) end
	__ds.stores[DS]["u404"] = old
	local q = makeP("Beto", 404)
	check("un registro antiguo (con receiptOrder) se carga y recalcula rcount", Inventory.get(q) ~= nil and Inventory.get(q).rcount == 300 and Inventory.get(q).receiptOrder == nil)
	check("sus 300 recibos antiguos siguen siendo duplicados", __market.ProcessReceipt(receipt("VIEJO-1", 404)) == OK and rec(404).vouchers.bottle == 3 and __market.ProcessReceipt(receipt("VIEJO-300", 404)) == OK and rec(404).vouchers.bottle == 3)
	check("un recibo nuevo se anade SIN purgar ninguno (301 en el libro)", __market.ProcessReceipt(receipt("NUEVO-404", 404)) == OK and count(rec(404).receipts) == 301 and rec(404).receipts["VIEJO-1"] ~= nil and rec(404).receiptOrder == nil and rec(404).vouchers.bottle == 4)
	__removePlayer(q)
end

do -- ===================================================== recibos de PRUEBA Studio separados de los pagados
	Config.Purchases.StudioTestMode = true
	Catalog.Products[1].ProductId = 0
	local tp = makeP("Test", 505)
	local shop = (function() for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then return d.Parent.CFrame.Position end end end)()
	tp.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	R.Shop.OnServerEvent:_fire(tp, "Buy", "champana_dom", 2)
	run(1, 0.1)
	check("modo de prueba Studio: concede gratis en el almacen de PRUEBAS", Inventory.get(tp).items.champana_dom == 2 and count(rec(505).receipts) == 0 and rec(505).tg == 2 and #__market._prompts == 1)
	check("...y el almacen de PRODUCCION no existe/esta vacio (no se contamina)", __ds.stores[Config.Data.StoreName] == nil or next(__ds.stores[Config.Data.StoreName]) == nil)
	check("una concesion de prueba con PurchaseId se rechaza", Inventory.grant(tp, { vouchers = { bottle = 1 } }, "X", { test = true }) == "failed")
	check("un recibo real sin PurchaseId se rechaza", Inventory.grant(tp, { vouchers = { bottle = 1 } }, nil) == "failed" and Inventory.grant(tp, { vouchers = { bottle = 1 } }, "STUDIO-9") == "failed")
	__isStudio = false
	check("fuera de Studio la concesion de prueba esta prohibida", Inventory.grant(tp, { vouchers = { bottle = 1 } }, nil, { test = true }) == "failed" and (rec(505).vouchers.bottle or 0) == 0)
	__isStudio = true
	Config.Purchases.StudioTestMode = false
end

print(string.format("\nRESULTADO LIBRO DE RECIBOS: %d comprobaciones, %d fallo(s)", total, failures))
