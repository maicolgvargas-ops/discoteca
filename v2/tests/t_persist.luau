-- PRUEBAS DE PERSISTENCIA (simulador): alquiler de sesion (lease) entre servidores, recibos atomicos, liberacion segura.
-- El DataStore es simulado y de un solo hilo: simula "otro servidor" editando el registro guardado a mano.
-- NO son pruebas en Studio ni con servidores reales.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then
		print("  PASS  " .. name)
	else
		failures += 1
		print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or ""))
	end
end
local function run(seconds, dt)
	for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end
end
print("\n=== PRUEBAS DE PERSISTENCIA v2 (alquiler de sesion) ===")

local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog = require(Shared.Config), require(Shared.Catalog)
local Inventory = require(SS.Inventory)
local DS = Config.Data.StoreName
local function rec(id) return __ds.stores[DS]["u" .. id] end
local function makeP(name, id)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, Vector3.new(0, 3, 91), "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local function leave(p) __removePlayer(p) end
local function receipt(pid, prod, user) return { PlayerId = user, ProductId = prod, PurchaseId = pid, CurrencySpent = 0, CurrencyType = "Robux" } end
local NOT, OK = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
Catalog.Products[1].ProductId = 555 -- ProductId de PRUEBA solo en memoria

do -- ===================================================== alquiler al cargar / renovar / liberar
	local p = makeP("Ana", 101)
	local r = rec(101)
	check("al cargar se toma el alquiler dentro del registro (lock.o y caducidad futura)", r and r.lock and type(r.lock.o) == "string" and r.lock.e > os.time(), r and r.lock and r.lock.e)
	check("la sesion queda cargada y editable", Inventory.get(p) ~= nil and Inventory.snapshot(p).blocked == false)
	local e0 = r.lock.e
	run(100, 1)
	check("el alquiler se RENUEVA solo mientras el jugador esta (autoguardado/renovacion)", rec(101).lock.e > e0 and rec(101).lock.o == r.lock.o, rec(101).lock.e - e0)
	check("el alquiler nunca caduca estando el jugador (margen > 0)", rec(101).lock.e > os.time())
	check("ProcessReceipt concede y guarda recibo + inventario en el mismo registro", __market.ProcessReceipt(receipt("A-1", 555, 101)) == OK and rec(101).vouchers.bottle == 1 and rec(101).receipts["A-1"] ~= nil)
	leave(p)
	check("al salir se guarda y se LIBERA el alquiler (lock = nil) conservando datos y recibos", rec(101).lock == nil and rec(101).vouchers.bottle == 1 and rec(101).receipts["A-1"] ~= nil)
	local p2 = makeP("Ana", 101)
	check("reentrar tras liberar carga al instante con el inventario", Inventory.get(p2) ~= nil and Inventory.get(p2).vouchers.bottle == 1 and rec(101).lock ~= nil)
	check("el mismo recibo tras reconectar NO duplica (idempotente) y se confirma", __market.ProcessReceipt(receipt("A-1", 555, 101)) == OK and rec(101).vouchers.bottle == 1)
	leave(p2)
end

do -- ===================================================== otro servidor tiene el alquiler
	__ds.stores[DS]["u202"] = { v = 1, items = { champana_dom = 2 }, vouchers = {}, open = {}, equipped = "", receipts = {}, receiptOrder = {}, credential = false, lock = { o = "OTRO-SERVIDOR", e = os.time() + 500 } }
	local t0 = os.clock()
	local p = makeP("Beto", 202)
	check("espera como mucho LockWaitSeconds y despues queda bloqueado en solo lectura", os.clock() - t0 >= Config.Data.LockWaitSeconds - 0.5 and os.clock() - t0 <= Config.Data.LockWaitSeconds + Config.Data.LockRetrySeconds + 1 and Inventory.get(p) == nil and Inventory.snapshot(p).blocked == true and Inventory.snapshot(p).readOnly == true, os.clock() - t0)
	check("NO escribe nada en un registro alquilado por otro (lock y datos intactos)", rec(202).lock.o == "OTRO-SERVIDOR" and rec(202).items.champana_dom == 2 and next(rec(202).receipts) == nil)
	local dec = __market.ProcessReceipt(receipt("B-1", 555, 202))
	check("un recibo con el registro alquilado por otro servidor -> NotProcessedYet y NO se guarda", dec == NOT and rec(202).receipts["B-1"] == nil and (rec(202).vouchers.bottle or 0) == 0 and rec(202).lock.o == "OTRO-SERVIDOR")
	check("grant/redeem/equip/stow sobre sesion bloqueada fallan sin escribir", Inventory.grant(p, { vouchers = { bottle = 1 } }, "B-2") == "failed" and Inventory.redeem(p, "champana_dom", 1) == "failed" and Inventory.equip(p, "champana_dom") == false and rec(202).lock.o == "OTRO-SERVIDOR")
	-- el otro servidor libera
	rec(202).lock = nil
	rec(202).items.champana_dom = 3 -- el otro servidor guardo un cambio mas
	run(20, 1)
	check("al liberarse, el reintento automatico carga los datos del otro servidor (no los pisa)", Inventory.get(p) ~= nil and Inventory.get(p).items.champana_dom == 3 and rec(202).lock.o ~= "OTRO-SERVIDOR", Inventory.get(p) and Inventory.get(p).items.champana_dom)
	check("...y el recibo pendiente ya se puede conceder (Roblox lo reintenta)", __market.ProcessReceipt(receipt("B-1", 555, 202)) == OK and rec(202).vouchers.bottle == 1 and rec(202).receipts["B-1"] ~= nil)
	leave(p)
end

do -- ===================================================== alquiler caducado / servidor caido
	__ds.stores[DS]["u303"] = { v = 1, items = { tequila_donjulio = 1 }, vouchers = {}, open = {}, equipped = "", receipts = {}, receiptOrder = {}, credential = false, lock = { o = "SERVIDOR-CAIDO", e = os.time() - 10 } }
	local p = makeP("Caro", 303)
	check("un alquiler ya caducado (servidor caido) se toma al instante y se conservan los datos", Inventory.get(p) ~= nil and Inventory.get(p).items.tequila_donjulio == 1 and rec(303).lock.o ~= "SERVIDOR-CAIDO")
	leave(p)
	__ds.stores[DS]["u304"] = { v = 1, items = {}, vouchers = {}, open = {}, equipped = "", receipts = {}, receiptOrder = {}, credential = false, lock = { o = "OTRO", e = os.time() + 60 } }
	local q = makeP("Dani", 304)
	check("alquiler que caduca en 60 s: primero bloqueado...", Inventory.get(q) == nil and Inventory.snapshot(q).blocked == true)
	run(70, 1)
	check("...y a los 60 s caduca y carga solo (sin intervencion)", Inventory.get(q) ~= nil and rec(304).lock.o ~= "OTRO")
	leave(q)
end

do -- ===================================================== perdida del alquiler a mitad de sesion
	local p = makeP("Eva", 505)
	check("grant normal antes de perder el alquiler", __market.ProcessReceipt(receipt("E-1", 555, 505)) == OK and rec(505).vouchers.bottle == 1)
	local orig = rec(505).lock.o
	rec(505).lock = { o = "SERVIDOR-NUEVO", e = os.time() + 100 } -- otro servidor se hizo con el registro
	rec(505).items.whisky_reserva = 7 -- ...y guardo cosas
	local dec = __market.ProcessReceipt(receipt("E-2", 555, 505))
	check("con el alquiler perdido el recibo NO se confirma (NotProcessedYet) y NO se escribe", dec == NOT and rec(505).receipts["E-2"] == nil and rec(505).vouchers.bottle == 1 and rec(505).lock.o == "SERVIDOR-NUEVO")
	check("la sesion pasa a solo lectura y avisa (lost) sin sobrescribir lo del otro servidor", Inventory.get(p) == nil and Inventory.snapshot(p).lost == true and rec(505).items.whisky_reserva == 7)
	check("equipar/canjear tampoco escriben", Inventory.equip(p, "champana_dom") == false and Inventory.redeem(p, "champana_dom", 1) == "failed" and rec(505).lock.o == "SERVIDOR-NUEVO")
	rec(505).lock = nil
	run(12, 1)
	check("cuando el otro servidor suelta, se recarga lo SUYO (mas reciente) y se retoma", Inventory.get(p) ~= nil and Inventory.get(p).items.whisky_reserva == 7 and rec(505).lock ~= nil and rec(505).lock.o ~= "SERVIDOR-NUEVO")
	check("y el recibo E-2 se concede ahora una sola vez", __market.ProcessReceipt(receipt("E-2", 555, 505)) == OK and __market.ProcessReceipt(receipt("E-2", 555, 505)) == OK and rec(505).vouchers.bottle == 2)
	leave(p)
end

do -- ===================================================== fallos de DataStore: nada se pierde ni se duplica
	local p = makeP("Fran", 606)
	__ds.failures = 100
	local dec = __market.ProcessReceipt(receipt("F-1", 555, 606))
	__ds.failures = 0
	check("DataStore caido durante la compra -> NotProcessedYet y NADA guardado (ni recibo ni vale)", dec == NOT and rec(606).receipts["F-1"] == nil and (rec(606).vouchers.bottle or 0) == 0)
	check("el reintento de Roblox concede UNA vez", __market.ProcessReceipt(receipt("F-1", 555, 606)) == OK and rec(606).vouchers.bottle == 1)
	-- fallo al salir: el alquiler no se libera pero caduca solo y nada se pierde
	Inventory.equip(p, "champana_dom") -- sin articulos: no cambia nada
	__ds.failures = 100
	leave(p)
	__ds.failures = 0
	check("si falla la liberacion al salir, el alquiler queda (caducara solo) y los datos guardados siguen intactos", rec(606).lock ~= nil and rec(606).vouchers.bottle == 1 and rec(606).receipts["F-1"] ~= nil)
	local t0 = os.clock()
	local p2 = makeP("Fran", 606)
	check("al reentrar espera/bloquea sin pisar el registro", Inventory.get(p2) == nil and Inventory.snapshot(p2).blocked == true and rec(606).vouchers.bottle == 1)
	run(Config.Data.LeaseSeconds + 10, 1)
	check("tras caducar el alquiler (<= LeaseSeconds) carga de nuevo con vale y recibo", Inventory.get(p2) ~= nil and Inventory.get(p2).vouchers.bottle == 1 and __market.ProcessReceipt(receipt("F-1", 555, 606)) == OK and rec(606).vouchers.bottle == 1)
	leave(p2)
end

do -- ===================================================== cierre del servidor
	local a, b = makeP("Gus", 707), makeP("Hana", 808)
	Inventory.equip(a, "champana_dom")
	__market.ProcessReceipt(receipt("G-1", 555, 707))
	check("hay dos alquileres vivos", rec(707).lock ~= nil and rec(808).lock ~= nil)
	for _, fn in __closeFns do fn() end
	check("BindToClose guarda y libera TODOS los alquileres", rec(707).lock == nil and rec(808).lock == nil and rec(707).receipts["G-1"] ~= nil and rec(707).vouchers.bottle == 1)
end

do -- ===================================================== recibos con el jugador ausente / sin cobros activos
	check("recibo de un jugador que no esta en este servidor -> NotProcessedYet", __market.ProcessReceipt(receipt("Z-1", 555, 99999)) == NOT)
	Catalog.Products[1].ProductId = 0
	check("ProductId 0 (por defecto) = sin cobros: no hay manejador, NotProcessedYet", __market.ProcessReceipt(receipt("Z-2", 0, 101)) == NOT)
end

print(string.format("\nRESULTADO PERSISTENCIA: %d comprobaciones, %d fallo(s)", total, failures))
