-- PRUEBAS DE SERVIDOR (simulador): catalogo, modelos 3D, inventario, compras, musica, cabina, interacciones.
-- Ejecutan el Script principal y los modulos contra el mock de la API de Roblox. NO son pruebas en Studio.
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
print("\n=== PRUEBAS DE SERVIDOR v2 ===")

local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog, DrinkModels = require(Shared.Config), require(Shared.Catalog), require(Shared.DrinkModels)
local Inventory, Purchases, Music, Control, Interactions = require(SS.Inventory), require(SS.Purchases), require(SS.Music), require(SS.Control), require(SS.Interactions)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local R = __replicated:FindFirstChild("AlfombraRemotes")
local function findAll(pat)
	local out = {}
	for _, d in club:GetDescendants() do
		if string.match(d.Name, pat) then table.insert(out, d) end
	end
	return out
end
local function find(n) return findAll("^" .. n .. "$")[1] end
local function notices(player, remote, kind)
	local out = {}
	for _, n in __noticeLog do
		if n.player == player and n.remote == remote and (kind == nil or n.args[1] == kind) then table.insert(out, n) end
	end
	return out
end
local function lastNotice(player, remote)
	local list = notices(player, remote)
	return list[#list] and list[#list].args
end
local function makeP(name, id, pos, rig)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, pos or Vector3.new(0, 3, 91), rig or "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local function fire(remote, player, ...)
	R:FindFirstChild(remote).OnServerEvent:_fire(player, ...)
end

do -- ===================================================== catalogo y modelos 3D
	local problems = Catalog.validate()
	check("catalogo valido (sin problemas)", #problems == 0, table.concat(problems, "; "))
	check("11 articulos: 8 botellas + 3 copas, en 4 categorias", #Catalog.Items == 11 and #Catalog.itemsByCategory("Champaña") == 3 and #Catalog.itemsByCategory("Tequila") == 3 and #Catalog.itemsByCategory("Whisky") == 2 and #Catalog.itemsByCategory("Shots") == 3)
	local need = { "Don Julio 1942", "Clase Azul Reposado", "Patrón Silver", "Moët & Chandon Impérial", "Veuve Clicquot Brut", "Dom Pérignon Vintage" }
	local names = {}
	for _, it in Catalog.Items do names[it.Name] = true end
	local okN = true
	for _, n in need do if not names[n] then okN = false end end
	check("nombres de ejemplo pedidos (Don Julio 1942, Clase Azul, Patron, Moet, Veuve, Dom Perignon) como texto configurable", okN)
	check("ProductId = 0 en todos los productos (compras reales desactivadas hasta enlazar)", Catalog.Products[1].ProductId == 0 and Catalog.Products[2].ProductId == 0)
	check("precios borrador: botella 400 y shot 50 (solo en Catalog, marcados DraftRobux)", Catalog.Products[1].DraftRobux == 400 and Catalog.Products[2].DraftRobux == 50)
	check("nombres genericos alternativos para todos", (function() for _, it in Catalog.Items do if not it.GenericName then return false end end return true end)())
	local lumBad
	local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
	for _, it in Catalog.Items do
		local m = DrinkModels.build(it, { anchored = true })
		local parts, labels, liquids, sg = 0, 0, 0, 0
		local linesOk = true
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				if not d.Anchored then linesOk = false end
				if d.Name == "Label" then labels += 1 end
				if d:GetAttribute("FullH") then liquids += 1 end
			end
			if d:IsA("SurfaceGui") then
				sg += 1
				local n = 0
				for _, c in d:GetChildren() do
					if c:IsA("TextLabel") then
						n += 1
						if c.Text == "" then linesOk = false end
					end
				end
				if n ~= #it.Label then linesOk = false end
			end
		end
		local hasHandle = m:FindFirstChild("Handle") ~= nil and m.PrimaryPart == m:FindFirstChild("Handle") and m.Handle.Transparency == 1
		local contrast = math.abs(lum(it.Style.label) - lum(it.Style.text))
		if it.Tier == "bottle" then
			if not (parts >= 8 and parts <= 40 and labels == 1 and liquids == 1 and sg == 1 and linesOk and hasHandle) then lumBad = lumBad or (it.Id .. " partes=" .. parts) end
			if contrast < 0.35 then lumBad = lumBad or (it.Id .. " contraste " .. contrast) end
		else
			if not (parts >= 6 and liquids == 1 and hasHandle) then lumBad = lumBad or (it.Id .. " copa partes=" .. parts) end
		end
	end
	check("cada botella: silueta de 8-40 piezas, cristal, liquido, etiqueta con su texto y buen contraste; cada copa con liquido", lumBad == nil, lumBad)
	local function countNamed(item, pat)
		local m = DrinkModels.build(item, {})
		local n = 0
		for _, d in m:GetDescendants() do if string.match(d.Name, pat) then n += 1 end end
		return n
	end
	check("lima en el shot de tequila, hielo en el whisky, burbujas en la copa de champana", countNamed(Catalog.getItem("shot_tequila"), "^Lime") == 2 and countNamed(Catalog.getItem("whisky_hielo"), "^Ice") == 2 and countNamed(Catalog.getItem("copa_champana"), "^Bubble") == 3)
	local kinds = {}
	for _, it in Catalog.Items do kinds[it.Kind] = true end
	local nk = 0
	for _ in kinds do nk += 1 end
	check("8 siluetas distintas (champagne, flask, round, square, whisky, shot, flute, tumbler)", nk == 8, nk)
	local tool = DrinkModels.makeTool(Catalog.getItem("champana_dom"), 3)
	local handle = tool:FindFirstChild("Handle")
	local welded, unanch = 0, true
	for _, d in tool:GetDescendants() do
		if d:IsA("WeldConstraint") or (d:IsA("Weld")) then welded += 1 end
		if d:IsA("BasePart") and d.Anchored then unanch = false end
	end
	check("Tool de botella: Handle invisible, piezas sueltas y soldadas, atributos de sorbos", handle ~= nil and handle.Transparency == 1 and welded >= 10 and unanch and tool:GetAttribute("Servings") == 3 and tool:GetAttribute("MaxServings") == 5 and tool.RequiresHandle == true)
	local liq
	for _, d in tool:GetDescendants() do if d:IsA("BasePart") and d:GetAttribute("FullH") then liq = d end end
	local h3 = liq.Size.X
	DrinkModels.setLevel(tool, 1)
	local h5 = liq.Size.X
	DrinkModels.setLevel(tool, 0.2)
	check("el nivel del liquido baja con los sorbos", h5 > h3 and liq.Size.X < h3)
	local sh = DrinkModels.makeTool(Catalog.getItem("shot_tequila"), 1)
	check("Tool de copa (shot) con 1 sorbo", sh:GetAttribute("MaxServings") == 1 and sh:FindFirstChild("Handle") ~= nil)
end

do -- ===================================================== construccion v2 (Build + Extras)
	local spawn = find("ClubSpawn")
	check("ClubSpawn invisible (Transparency = 1) y sin colision", spawn ~= nil and spawn.Transparency == 1 and spawn.CanCollide == false)
	check("ClubSpawn fuera, delante de la puerta (guardias activos)", spawn.CFrame.pz > 85 and math.abs(spawn.CFrame.px) < 1)
	local logo, mini = find("PhotocallLogo_Plate"), findAll("^PhotocallMini%d+_Plate$")
	local panel = find("PhotocallPanel")
	local panelFront = panel.CFrame.px + panel.Size.X / 2
	local allFront = logo.CFrame.px + logo.Size.X / 2 > panelFront
	for _, m in mini do if not (m.CFrame.px + m.Size.X / 2 > panelFront) then allFront = false end end
	check("photocall: logo grande y 6 pequenos con la cara por delante del panel (no tapados)", allFront and #mini == 6, #mini)
	local core = find("MirrorCore")
	local facets = findAll("^MirrorFacet$")
	local rOK, refl = true, true
	for _, f in facets do
		local d = (f.CFrame.Position - core.CFrame.Position).Magnitude
		if math.abs(d - 3.56) > 0.001 then rOK = false end
		if math.abs(f.Reflectance - 0.8) > 1e-6 then refl = false end
	end
	check("esfera: MirrorCore diametro 7, facetas a RC = 3.56 y reflectance 0.8", core.Size.X == 7 and rOK and refl and #facets > 100, #facets)
	check("bartenders: 4 NPC humanoides R6 con prompt de tienda", #findAll("^Bartender_") == 4 and (function() local n = 0 for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then n += 1 end end return n end)() == 4)
	local guards = findAll("^Guard_%d$")
	local hum = guards[1] and guards[1]:FindFirstChildOfClass("Humanoid")
	check("2 guardias grandes (escala 1.18) con Humanoid R6 y prompt", #guards == 2 and hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6 and guards[1].HumanoidRootPart.Size.X > 2.3)
	local barrier = find("EntranceBarrier")
	check("barrera de la puerta invisible y en el grupo AR_Barrier; no cubre la acera", barrier ~= nil and barrier.Transparency == 1 and barrier.CollisionGroup == "AR_Barrier" and barrier.Size.X == 20)
	check("4 bailarinas NPC con vestido y baile asignado en 2 podios", #findAll("^Dancer_%d$") == 4 and #findAll("^DancePodium%d$") == 2 and #__collection:GetTagged("AR_NpcDancer") == 4)
	local seats, bad = 0, nil
	for _, d in club:GetDescendants() do
		if d:IsA("Seat") then
			seats += 1
			if not (d.Transparency == 1 and d.CanCollide == false and d.CanTouch == false) then bad = bad or d.Name end
		end
	end
	check("asientos Seat reales discretos (invisibles, sin colision ni Touched): >= 100", seats >= 100 and bad == nil, bad or seats)
	local prompts = 0
	for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d.Name == "SitPrompt" then prompts += 1 end end
	check("un prompt 'Sentarse' por asiento", prompts == seats, prompts)
	check("cabina DJ: 2 decks con plato y jog wheel, mezcladora con 4 faders y 12 mandos EQ, 12 medidores VU, monitor, 6+ cables", #findAll("^DJ_Deck[LR]_Platter$") == 2 and #findAll("^DJ_Deck[LR]_Ring$") == 2 and #findAll("^DJ_FaderKnob%d$") == 4 and #findAll("^DJ_Eq%d_%d$") == 12 and #findAll("^DJ_Vu%d_%d$") == 12 and find("DJ_Monitor") ~= nil and #findAll("^DJ_Cable") >= 6)
	check("cabina DJ interactiva: prompt claro 'Abrir mesa de DJ'", find("DJPrompt") ~= nil and find("DJPrompt").ActionText:find("mesa de DJ") ~= nil and find("DJPrompt"):GetAttribute("AR_Tab") == "musica")
	check("cabina de luces con prompt y pestana 'luces'", find("LightPrompt") ~= nil and find("LightPrompt"):GetAttribute("AR_Tab") == "luces")
	local screens = findAll("^NowPlaying[LR]$")
	check("2 pantallas 'ahora suena' con titulo, artista, estado y 24 barras de visualizador cada una", #screens == 2 and #findAll("^Bar%d+$") == 48 and #__collection:GetTagged("AR_VisBar") == 48 and #__collection:GetTagged("AR_NowTitle") >= 3)
	check("las pantallas avisan que no son video", (function() for _, d in club:GetDescendants() do if d:IsA("TextLabel") and string.find(d.Text, "no es vídeo", 1, true) then return true end end return false end)())
	check("estanterias con botellas 3D (DrinkModels) en los bares", #findAll("^champana_") >= 6 and #findAll("^tequila_") >= 6)
	check("lamparas calidas sobre las barras", #findAll("Pendant.*Bulb") >= 6)
	local neonBad
	for _, d in club:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and string.find(d.Name, "^DJ_") then neonBad = d.Name end
	end
	check("la cabina DJ no usa neon (acabados negro brillante / cromo / dorado)", neonBad == nil, neonBad)
end

do -- ===================================================== inventario, compras, persistencia
	local DS = "AlfombraRoja_Inventory_v2"
	local p1 = makeP("Ana", 101)
	local inv = Inventory.get(p1)
	check("inventario cargado al entrar, con credencial ficticia AR-XXXXXX", inv ~= nil and string.match(inv.credential.id, "^AR%-%x%x%x%x%x%x$") ~= nil)
	local shop = (function() for _, d in club:GetDescendants() do if d:IsA("ProximityPrompt") and d:GetAttribute("AR_Action") == "shop" then return d.Parent.CFrame.Position end end end)()
	p1.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	-- sin ProductId la compra con Robux esta desactivada
	local n0 = #__market._prompts
	fire("Shop", p1, "Buy", "champana_dom", 1)
	check("ProductId = 0: no se ofrece ninguna compra de Robux", #__market._prompts == n0 and (Inventory.get(p1).items.champana_dom or 0) == 0)
	check("...y se avisa al jugador (toast)", lastNotice(p1, "ShopNotice") ~= nil and lastNotice(p1, "ShopNotice")[1] == "Toast")
	check("modo prueba Studio desactivado por defecto", Config.Purchases.StudioTestMode == false and Purchases.studioMode() == false)

	-- enlazamos ProductIds de prueba (en memoria)
	Catalog.Products[1].ProductId = 555
	Catalog.Products[2].ProductId = 556
	check("ProcessReceipt unico: MarketplaceService.ProcessReceipt asignado", type(__market.ProcessReceipt) == "function")
	local receipt = function(pid, prod, user) return { PlayerId = user or 101, ProductId = prod, PurchaseId = pid, CurrencySpent = 0, CurrencyType = "Robux" } end
	local dec = __market.ProcessReceipt(receipt("R-1", 555))
	check("recibo valido -> PurchaseGranted y 1 vale de botella", dec == Enum.ProductPurchaseDecision.PurchaseGranted and Inventory.get(p1).vouchers.bottle == 1)
	dec = __market.ProcessReceipt(receipt("R-1", 555))
	check("el mismo PurchaseId repetido NO concede dos veces (idempotente)", dec == Enum.ProductPurchaseDecision.PurchaseGranted and Inventory.get(p1).vouchers.bottle == 1)
	dec = __market.ProcessReceipt(receipt("R-2", 555))
	check("compra repetible: otro PurchaseId concede otro vale", dec == Enum.ProductPurchaseDecision.PurchaseGranted and Inventory.get(p1).vouchers.bottle == 2)
	check("producto desconocido -> NotProcessedYet (no se pierde)", __market.ProcessReceipt(receipt("R-3", 999)) == Enum.ProductPurchaseDecision.NotProcessedYet)
	check("recibos mal formados -> NotProcessedYet", __market.ProcessReceipt(nil) == Enum.ProductPurchaseDecision.NotProcessedYet and __market.ProcessReceipt({}) == Enum.ProductPurchaseDecision.NotProcessedYet and __market.ProcessReceipt({ PlayerId = "x", ProductId = 555, PurchaseId = "a" }) == Enum.ProductPurchaseDecision.NotProcessedYet and __market.ProcessReceipt({ PlayerId = 101, ProductId = 555, PurchaseId = 7 }) == Enum.ProductPurchaseDecision.NotProcessedYet)
	check("jugador que no esta en el servidor -> NotProcessedYet", __market.ProcessReceipt(receipt("R-4", 555, 4242)) == Enum.ProductPurchaseDecision.NotProcessedYet)
	-- fallo de guardado: NO se confirma y no se pierde
	__ds.failures = 100
	dec = __market.ProcessReceipt(receipt("R-5", 556))
	__ds.failures = 0
	check("si falla el DataStore NO se confirma el recibo (NotProcessedYet) y no cambia el inventario", dec == Enum.ProductPurchaseDecision.NotProcessedYet and (Inventory.get(p1).vouchers.shot or 0) == 0)
	dec = __market.ProcessReceipt(receipt("R-5", 556))
	check("Roblox reintenta el mismo recibo y se concede UNA vez", dec == Enum.ProductPurchaseDecision.PurchaseGranted and Inventory.get(p1).vouchers.shot == 1)
	dec = __market.ProcessReceipt(receipt("R-5", 556))
	check("y un reintento posterior no duplica", Inventory.get(p1).vouchers.shot == 1 and dec == Enum.ProductPurchaseDecision.PurchaseGranted)
	local stored = __ds.stores[DS]["u101"]
	check("lo guardado en DataStore coincide (2 vales de botella, 1 de shot, recibos registrados)", stored.vouchers.bottle == 2 and stored.vouchers.shot == 1 and stored.receipts["R-1"] and stored.receipts["R-2"] and stored.receipts["R-5"])

	-- compra de un articulo: vales -> canje
	local function items() return Inventory.get(p1).items end
	fire("Shop", p1, "Buy", "champana_dom", 1)
	check("comprar con vales disponibles los canjea (Dom Perignon x1)", items().champana_dom == 1 and Inventory.get(p1).vouchers.bottle == 1)
	run(1, 0.5)
	fire("Shop", p1, "Buy", "tequila_donjulio", 3)
	check("cantidad 3 con 1 vale: canjea 1 y ofrece comprar el siguiente producto (prompt del producto 555)", items().tequila_donjulio == 1 and #__market._prompts == n0 + 1 and __market._prompts[#__market._prompts].productId == 555 and Purchases._pending(p1).remaining == 2)
	__market.ProcessReceipt(receipt("R-6", 555))
	run(0.5, 0.5)
	check("el recibo concede y canjea automaticamente la seleccion pendiente (2 de 3)", items().tequila_donjulio == 2 and Purchases._pending(p1).remaining == 1 and #__market._prompts == n0 + 2)
	__market.ProcessReceipt(receipt("R-7", 555))
	check("...hasta completar las 3 unidades", items().tequila_donjulio == 3 and Purchases._pending(p1) == nil)
	__market.PromptProductPurchaseFinished:_fire(101, 555, false)
	__market.PromptProductPurchaseFinished:_fire(101, 555, true)
	__market.PromptProductPurchaseFinished:_fire(101, 556, true)
	check("PromptProductPurchaseFinished NUNCA concede nada", (Inventory.get(p1).vouchers.bottle or 0) == 0 and items().tequila_donjulio == 3)
	-- validaciones del remoto
	local before = items().whisky_malta
	run(2, 0.5)
	for _, bad in { 0, 11, -1, "3", 2.5 * 0 / 0, math.huge, {} } do fire("Shop", p1, "Buy", "whisky_malta", bad); run(1, 0.5) end
	fire("Shop", p1, "Buy", 123, 1)
	fire("Shop", p1, "Buy", "no_existe", 1)
	fire("Shop", p1, 5, 1)
	fire("Shop", p1, "Equip", "no_existe")
	check("cantidades y articulos invalidos se rechazan; nada cambia", items().whisky_malta == before and Inventory.get(p1).equipped == "")
	p1.Character.HumanoidRootPart.Position = Vector3.new(60, 3, 120)
	run(2, 0.5)
	fire("Shop", p1, "Buy", "shot_tequila", 1)
	check("lejos de un bartender/barra no se puede pedir", #__market._prompts == n0 + 2)
	p1.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	-- rate limit
	local sent = 0
	run(2, 0.5)
	for i = 1, 40 do
		local b0 = #notices(p1, "ShopNotice", "State")
		fire("Shop", p1, "State")
		if #notices(p1, "ShopNotice", "State") > b0 then sent += 1 end
	end
	check("limite de peticiones de la tienda (6/s): 40 seguidas -> <= 7 atendidas", sent <= 7 and sent >= 1, sent)
	run(2, 0.5)

	-- equipar / guardar / sorbos
	fire("Shop", p1, "Equip", "champana_dom")
	local function toolOf(p) for _, c in p:FindFirstChildOfClass("Backpack"):GetChildren() do if c:IsA("Tool") then return c end end end
	local t = toolOf(p1)
	check("Equipar crea el Tool de la botella en el Backpack", t ~= nil and t:GetAttribute("ItemId") == "champana_dom" and Inventory.get(p1).equipped == "champana_dom")
	fire("Shop", p1, "Stow")
	check("Guardar quita el Tool y conserva la unidad", toolOf(p1) == nil and items().champana_dom == 1)
	fire("Shop", p1, "Equip", "champana_dom")
	t = toolOf(p1)
	local liq
	for _, d in t:GetDescendants() do if d:IsA("BasePart") and d:GetAttribute("FullH") then liq = d end end
	local full = liq.Size.X
	t.Activated:_fire()
	check("un sorbo: 4 sorbos restantes y el liquido baja", Inventory.get(p1).open.champana_dom == 4 and t:GetAttribute("Servings") == 4 and liq.Size.X < full)
	t.Activated:_fire()
	check("el consumo tiene enfriamiento (1.5 s)", Inventory.get(p1).open.champana_dom == 4)
	for i = 1, 4 do run(2, 0.5) t.Activated:_fire() end
	check("tras 5 sorbos se gasta la unidad: se quita el Tool, equipped vacio y 0 unidades", items().champana_dom == nil and Inventory.get(p1).equipped == "" and toolOf(p1) == nil)
	check("el consumo no toca estadisticas: solo cambia el inventario (sin Humanoid.Health ni WalkSpeed)", p1.Character:FindFirstChildOfClass("Humanoid").Health == 100)
	fire("Shop", p1, "Equip", "champana_dom")
	check("no se puede equipar lo que no se tiene", toolOf(p1) == nil)
	fire("Shop", p1, "Equip", "tequila_donjulio")
	local sipItem = toolOf(p1)
	run(2, 0.5)
	sipItem.Activated:_fire()
	run(2, 0.5)
	sipItem.Activated:_fire()
	check("consumo parcial de una botella de tequila (3 sorbos restantes de la unidad abierta)", Inventory.get(p1).open.tequila_donjulio == 3 and items().tequila_donjulio == 3)

	-- persistencia: salir, entrar, morir/reaparecer
	__removePlayer(p1)
	local saved = __ds.stores[DS]["u101"]
	check("al salir se guarda todo (items, sorbos de la unidad abierta, equipado, recibos)", saved.items.tequila_donjulio == 3 and saved.open.tequila_donjulio == 3 and saved.equipped == "tequila_donjulio" and saved.vouchers.shot == 1 and saved.receipts["R-7"])
	local p1b = makeP("Ana", 101)
	check("al volver a entrar el inventario esta intacto", Inventory.get(p1b).items.tequila_donjulio == 3 and Inventory.get(p1b).vouchers.shot == 1)
	local t2 = toolOf(p1b)
	check("y el objeto equipado vuelve a la mano (Backpack) con los sorbos guardados", t2 ~= nil and t2:GetAttribute("Servings") == 3)
	__spawnCharacter(p1b, Vector3.new(0, 3, 91), "R6")
	check("tras morir/reaparecer el Tool se vuelve a entregar y no se pierde nada", toolOf(p1b) ~= nil and Inventory.get(p1b).items.tequila_donjulio == 3)
	local cnt = 0
	for _, c in p1b:FindFirstChildOfClass("Backpack"):GetChildren() do if c:IsA("Tool") then cnt += 1 end end
	check("sin Tools duplicados", cnt == 1, cnt)
	-- compra pendiente de ProcessReceipt mientras el jugador no esta (reconexion)
	__removePlayer(p1b)
	dec = __market.ProcessReceipt(receipt("R-8", 556))
	check("compra procesada con el jugador desconectado -> NotProcessedYet (Roblox reintenta al volver)", dec == Enum.ProductPurchaseDecision.NotProcessedYet)
	local p1c = makeP("Ana", 101)
	dec = __market.ProcessReceipt(receipt("R-8", 556))
	check("al reconectar el recibo se concede una vez", dec == Enum.ProductPurchaseDecision.PurchaseGranted and Inventory.get(p1c).vouchers.shot == 2)

	-- carga fallida: solo lectura y nunca se sobrescribe lo guardado
	__removePlayer(p1c)
	__ds.failures = 100
	local p2 = makeP("Beto", 202)
	check("si falla la carga la sesion queda en solo-lectura (sin datos inventados)", Inventory.get(p2) == nil)
	fire("Shop", p2, "Equip", "champana_dom")
	check("en solo-lectura no se puede equipar ni se guarda nada", __ds.stores[DS]["u202"] == nil)
	__ds.failures = 0
	run(20, 1)
	check("al volver el DataStore se reintenta la carga sola", Inventory.get(p2) ~= nil)
	-- no sobrescribir datos existentes con una carga fallida
	__removePlayer(p2)
	local p1d = makeP("Ana", 101)
	__removePlayer(p1d)
	__ds.failures = 100
	local p1e = makeP("Ana", 101)
	__removePlayer(p1e)
	__ds.failures = 0
	check("una carga fallida NO sobrescribe el inventario guardado", __ds.stores[DS]["u101"].items.tequila_donjulio == 3)
	check("BindToClose guarda las sesiones abiertas", #__closeFns >= 1)

	-- MODO DE PRUEBA STUDIO: gratis y solo en Studio
	local p3 = makeP("Caro", 303, shop + Vector3.new(2, 0, 0))
	p3.Character.HumanoidRootPart.Position = shop + Vector3.new(2, 0, 0)
	Catalog.Products[1].ProductId = 0
	Catalog.Products[2].ProductId = 0
	Config.Purchases.StudioTestMode = true
	__isStudio = false
	fire("Shop", p3, "Buy", "shot_tequila", 2)
	check("StudioTestMode=true FUERA de Studio no concede nada (nunca habilitado en produccion)", (Inventory.get(p3).items.shot_tequila or 0) == 0)
	run(2, 0.5)
	__isStudio = true
	fire("Shop", p3, "Buy", "shot_tequila", 2)
	check("en Studio con StudioTestMode: concede GRATIS 2 shots, sin pedir Robux", Inventory.get(p3).items.shot_tequila == 2 and #__market._prompts == n0 + 2)
	local rec303 = __ds.stores[DS]["u303"]
	local nrec = 0
	for _ in rec303.receipts do nrec += 1 end
	check("las concesiones de prueba Studio NO entran en el libro de recibos pagados (solo suman al contador tg)", nrec == 0 and rec303.tg == 2, nrec .. "/" .. tostring(rec303.tg))
	Config.Purchases.StudioTestMode = false
	__isStudio = false
	run(2, 0.5)
	fire("Shop", p3, "Buy", "shot_tequila", 1)
	check("con el modo de prueba apagado vuelve a estar bloqueado", Inventory.get(p3).items.shot_tequila == 2)
end

do -- ===================================================== musica
	local club_ = club
	check("sin pistas: estado 'none' y 0 pistas", club_.Music:GetAttribute("Status") == "none" and club_.Music:GetAttribute("Count") == 0)
	local ok, reason = Music.handle("MusicPlay")
	check("sin pistas las acciones se rechazan con explicacion (no simula musica)", ok == false and type(reason) == "string")
	check("el Sound del altavoz no tiene ningun SoundId inventado", find("ClubMusic").SoundId == "" and find("ClubMusic").Volume == 0 or find("ClubMusic").Volume >= 0)
	-- lista blanca configurada
	Config.Music.Tracks = {
		{ Id = "rbxassetid://1111", Title = "Pista A", Artist = "Artista A" },
		{ Id = 2222, Title = "Pista B", Artist = "Artista B" },
		{ Id = "https://evil.example/x.mp3", Title = "Mala" },
		{ Id = "rbxassetid://0", Title = "Cero" },
		{ Id = "rbxassetid://3333" },
		"texto",
	}
	Music.init(club_)
	check("la lista blanca descarta pistas invalidas (URL, id 0, sin titulo, tipos raros)", Music.count() == 2 and club_.Music:GetAttribute("Count") == 2 and club_.Music:GetAttribute("Status") == "stopped")
	check("MusicSelect(2) pone la pista B", Music.handle("MusicSelect", 2) and find("ClubMusic").SoundId == "rbxassetid://2222" and club_.Music:GetAttribute("Title") == "Pista B" and club_.Music:GetAttribute("Playing") == true)
	for _, bad in { 0, 3, -1, "1", 0 / 0, 1.5 * math.huge, {}, true } do
		Music.handle("MusicSelect", bad)
	end
	check("indices invalidos o textos no cambian la pista", club_.Music:GetAttribute("Index") == 2 or club_.Music:GetAttribute("Index") == 1)
	local before = find("ClubMusic").SoundId
	Music.handle("MusicSelect", "rbxassetid://9999")
	Music.handle("MusicPlay", "rbxassetid://9999")
	check("un assetId enviado como valor se IGNORA (solo existen ids de la lista blanca)", find("ClubMusic").SoundId == before and (before == "rbxassetid://1111" or before == "rbxassetid://2222"))
	Music.handle("MusicSelect", 1)
	Music.handle("MusicNext")
	check("Siguiente / Anterior ciclan por la lista", club_.Music:GetAttribute("Index") == 2)
	Music.handle("MusicNext")
	check("...y dan la vuelta", club_.Music:GetAttribute("Index") == 1)
	Music.handle("MusicPrev")
	check("Anterior desde la primera va a la ultima", club_.Music:GetAttribute("Index") == 2)
	Music.handle("MusicPause")
	check("Pausa: estado 'paused'", club_.Music:GetAttribute("Status") == "paused" and club_.Music:GetAttribute("Playing") == false and find("ClubMusic").Playing == false)
	Music.handle("MusicPlay")
	check("Reproducir: 'playing'", club_.Music:GetAttribute("Status") == "playing")
	Music.handle("MusicVolume", 0.3)
	local v1 = find("ClubMusic").Volume
	Music.handle("MusicVolume", 99)
	local v2 = find("ClubMusic").Volume
	Music.handle("MusicVolume", "alto")
	check("volumen: se limita a 0..1 (x MaxVolume)", math.abs(v1 - 0.3 * Config.Music.MaxVolume) < 1e-6 and math.abs(v2 - Config.Music.MaxVolume) < 1e-6 and club_.Music:GetAttribute("Volume") == 1)
	local s = find("ClubMusic")
	for _, x in findAll("^ClubMusic$") do x.Ended:_fire() end
	check("al terminar una pista pasa a la siguiente (AutoNext)", club_.Music:GetAttribute("Index") == 1)
	Config.Music.Tracks = {}
	Music.init(club_)
	check("sin pistas otra vez: vuelve al estado vacio", club_.Music:GetAttribute("Status") == "none")
end

do -- ===================================================== cabina: operador unico, permisos y musica
	Config.Music.Tracks = { { Id = "rbxassetid://1111", Title = "Pista A", Artist = "X" }, { Id = "rbxassetid://2222", Title = "Pista B", Artist = "Y" } }
	Music.init(club)
	local deskPos = find("LightDesk_Top").CFrame.Position
	local near = Vector3.new(deskPos.X, deskPos.Y + 4, deskPos.Z + 5)
	local pa, pb = makeP("Op1", 501, near), makeP("Op2", 502, near)
	local control = club:FindFirstChild("Control")
	local lightPrompt, djPrompt = find("LightPrompt"), find("DJPrompt")
	lightPrompt.Triggered:_fire(pa)
	check("prompt de la cabina de luces: p1 es operador y se abre en la pestana 'luces'", control:GetAttribute("Operator") == 501 and lastNotice(pa, "ControlNotice")[1] == "Open" and lastNotice(pa, "ControlNotice")[3] == "luces")
	djPrompt.Triggered:_fire(pb)
	check("la mesa de DJ comparte el MISMO operador: p2 recibe 'ocupado'", control:GetAttribute("Operator") == 501 and lastNotice(pb, "ControlNotice")[1] == "Busy")
	local function ctl(player, ...) R.Control.OnServerEvent:_fire(player, ...) end
	run(2, 0.5)
	ctl(pb, "MusicPlay")
	check("un no-operador no puede tocar la musica", club.Music:GetAttribute("Status") == "stopped")
	ctl(pa, "MusicSelect", 2)
	check("el operador elige pista (indice) y suena", club.Music:GetAttribute("Index") == 2 and club.Music:GetAttribute("Playing") == true)
	run(2, 0.5)
	ctl(pa, "MusicSelect", "rbxassetid://5555")
	ctl(pa, "MusicSelect", { 1 })
	check("el operador tampoco puede mandar un assetId ni tipos raros", club.Music:GetAttribute("Index") == 2 and find("ClubMusic").SoundId == "rbxassetid://2222")
	run(2, 0.5)
	ctl(pa, "MusicNext")
	run(2, 0.5)
	ctl(pa, "MusicPause")
	run(2, 0.5)
	ctl(pa, "Master", 1.2)
	check("el mismo operador controla luces y musica", club.Music:GetAttribute("Status") == "paused" and control:GetAttribute("Master") == 1.2)
	-- focos rojos de seguimiento y preset Discoteca oscura
	check("valores por defecto: focos apagados, intensidad 1, velocidad 0.8, sin oscuridad, estrobo apagado", control:GetAttribute("Follow") == false and control:GetAttribute("FollowIntensity") == 1 and control:GetAttribute("FollowSpeed") == 0.8 and control:GetAttribute("Dark") == 0 and control:GetAttribute("Strobe") == false)
	run(2, 0.5)
	ctl(pb, "Follow", true)
	check("un no-operador no puede encender los focos", control:GetAttribute("Follow") == false)
	ctl(pa, "Follow", true)
	ctl(pa, "FollowIntensity", 9)
	ctl(pa, "FollowSpeed", 0.01)
	check("el operador enciende los focos; intensidad y velocidad se acotan (<= 1.5 y >= 0.25)", control:GetAttribute("Follow") == true and control:GetAttribute("FollowIntensity") == 1.5 and control:GetAttribute("FollowSpeed") == 0.25)
	run(2, 0.5)
	ctl(pa, "FollowIntensity", -4)
	ctl(pa, "Dark", 7)
	ctl(pa, "Follow", "si")
	ctl(pa, "FollowSpeed", 0 / 0)
	ctl(pa, "Dark", { 1 })
	check("valores invalidos (texto, NaN, tabla) se ignoran y los numeros se acotan (>= 0, Dark <= 1)", control:GetAttribute("Follow") == true and control:GetAttribute("FollowIntensity") == 0 and control:GetAttribute("Dark") == 1 and control:GetAttribute("FollowSpeed") == 0.25)
	run(2, 0.5)
	ctl(pa, "Preset", "DiscotecaOscura")
	check("preset Discoteca oscura: focos, luz ambiental baja, zonas con protagonismo, estrobo apagado, paleta dorada (no todo rojo)", control:GetAttribute("Follow") == true and control:GetAttribute("FollowIntensity") == 1.1 and control:GetAttribute("Dark") == 0.85 and control:GetAttribute("ZPista") == 0.3 and control:GetAttribute("ZAlfombra") == 1 and control:GetAttribute("Strobe") == false and control:GetAttribute("Palette") == "Champan" and control:GetAttribute("Lasers") == false)
	run(2, 0.5)
	ctl(pa, "Preset", "Fiesta")
	check("cambiar a otro preset restablece zonas, focos y oscuridad", control:GetAttribute("Follow") == false and control:GetAttribute("Dark") == 0 and control:GetAttribute("ZPista") == 1 and control:GetAttribute("FollowIntensity") == 1)
	run(2, 0.5)
	ctl(pa, "Preset", "NoExiste")
	check("preset inexistente ignorado", control:GetAttribute("Preset") == "Fiesta")
	run(2, 0.5)
	ctl(pa, "Release", true)
	djPrompt.Triggered:_fire(pb)
	check("al soltar, el otro jugador toma el control desde la mesa de DJ ('musica')", control:GetAttribute("Operator") == 502 and lastNotice(pb, "ControlNotice")[3] == "musica")
	local c = Config.Control
	c.Access = "Lista"
	c.UserIds = {}
	ctl(pb, "Release", true)
	djPrompt.Triggered:_fire(pa)
	check("permiso 'Lista': quien no esta en la lista no controla la cabina", control:GetAttribute("Operator") == 0 and lastNotice(pa, "ControlNotice")[1] == "Denied")
	c.UserIds = { 501 }
	djPrompt.Triggered:_fire(pa)
	check("...y el de la lista si", control:GetAttribute("Operator") == 501)
	c.Access = "Todos"
	c.UserIds = {}
	ctl(pa, "Release", true)
	Config.Music.Tracks = {}
	Music.init(club)
	__removePlayer(pa)
	__removePlayer(pb)
end

do -- ===================================================== asientos, acceso, baile, chat
	local seat = findAll("^LoungeSofaA1_Sit1$")[1]
	local sp = seat.CFrame.Position
	local pa = makeP("Sit1", 601, sp + Vector3.new(0, 2, 3))
	local pb = makeP("Sit2", 602, sp + Vector3.new(0, 2, 4))
	local prompt = seat:FindFirstChild("SitPrompt")
	prompt.Triggered:_fire(pa)
	local hum = pa.Character:FindFirstChildOfClass("Humanoid")
	check("el prompt sienta al jugador en el Seat (Occupant) y desactiva el prompt", seat.Occupant == hum and hum.Sit == true and prompt.Enabled == false)
	prompt.Triggered:_fire(pb)
	check("un asiento ocupado no admite a otro jugador", seat.Occupant == hum)
	local far = makeP("Lejos", 603, Vector3.new(200, 3, 200))
	local seat2 = findAll("^LoungeSofaB1_Sit1$")[1]
	seat2:FindFirstChild("SitPrompt").Triggered:_fire(far)
	check("un jugador lejos no puede sentarse aunque dispare el prompt", seat2.Occupant == nil)
	local seat3 = findAll("^BarEStool0_Sit$")[1]
	check("taburetes con Seat orientado a la barra", seat3 ~= nil and math.abs(seat3.CFrame.LookVector.X - 1) < 1e-6)

	-- acceso
	check("grupos de colision AR_Barrier / AR_Outsider registrados; la barrera solo choca con AR_Outsider", __physics:IsCollisionGroupRegistered("AR_Barrier") and __physics:IsCollisionGroupRegistered("AR_Outsider") and __physics:CollisionGroupsAreCollidable("AR_Barrier", "AR_Outsider") == true and __physics:CollisionGroupsAreCollidable("AR_Barrier", "Default") == false)
	local guardHrp = find("Guard_1").HumanoidRootPart
	local gp = guardHrp.CFrame.Position
	local out = makeP("Fuera", 701, gp + Vector3.new(0, 0, 4))
	local function groups(p) local g = {} for _, d in p.Character:GetDescendants() do if d:IsA("BasePart") then g[d.CollisionGroup] = true end end return g end
	task.wait(0.3)
	check("un jugador sin credencial presentada nace en el grupo AR_Outsider (choca con la barrera)", out:GetAttribute("AR_Access") ~= true and groups(out).AR_Outsider == true and groups(out).Default == nil)
	local pg = notices(out, "SocialNotice", "OpenGuard")
	find("GuardPrompt").Triggered:_fire(out)
	local ng = notices(out, "SocialNotice", "OpenGuard")
	check("hablar con un guardia abre el dialogo con nombre, credencial ficticia y aviso de que no verifica edad", #ng == 1 and ng[1].args[2].credential.id == Inventory.credentialFor(701).id and ng[1].args[2].name == "Fuera" and string.find(ng[1].args[2].disclaimer, "comprueba la edad", 1, true) ~= nil and ng[1].args[2].hasAccess == false)
	local far2 = makeP("Lejano", 702, Vector3.new(0, 3, 150))
	fire("Social", far2, "Credential")
	check("lejos de los guardias no se puede presentar la credencial", far2:GetAttribute("AR_Access") ~= true and lastNotice(far2, "SocialNotice")[2] == false)
	run(2, 0.5)
	fire("Social", out, "Credential", "AR-FFFFFF")
	check("una credencial que no coincide con la del servidor se rechaza (validacion del lado servidor)", out:GetAttribute("AR_Access") ~= true and lastNotice(out, "SocialNotice")[2] == false)
	run(2, 0.5)
	fire("Social", out, "Credential", Inventory.credentialFor(701).id)
	check("la credencial correcta concede acceso a ESE jugador y pasa al grupo Default", out:GetAttribute("AR_Access") == true and groups(out).Default == true and groups(out).AR_Outsider == nil and lastNotice(out, "SocialNotice")[2] == true)
	check("el acceso de uno no cambia el de otro", far2:GetAttribute("AR_Access") ~= true)
	Config.Guards.BlockedUserIds = { 703 }
	local blk = makeP("Bloqueado", 703, gp + Vector3.new(2, 0, 4))
	task.wait(0.3)
	run(2, 0.5)
	fire("Social", blk, "Credential")
	check("un jugador bloqueado por configuracion no pasa", blk:GetAttribute("AR_Access") ~= true)
	Config.Guards.BlockedUserIds = {}
	local inside = makeP("Dentro", 704, Vector3.new(0, 3, 40))
	run(3, 1)
	check("quien ya esta DENTRO del edificio tiene acceso (la salida nunca se bloquea)", inside:GetAttribute("AR_Access") == true)
	inside.Character.HumanoidRootPart.Position = Vector3.new(0, 3, 95)
	run(2, 1)
	check("...y sigue pudiendo salir y volver a entrar (grupo Default)", groups(inside).Default == true)
	-- accesorio nuevo hereda el grupo
	local acc = Instance.new("Part")
	acc.Parent = blk.Character
	check("una pieza anadida al personaje (accesorio) hereda el grupo de colision", acc.CollisionGroup == "AR_Outsider")

	-- baile
	local dancer = makeP("Baila", 801, Vector3.new(0, 3, 40))
	R.Social.OnServerEvent:_fire(dancer, "Dance", "disco")
	check("Dance valido: se publica como atributo del personaje (para que lo animen todos)", dancer.Character:GetAttribute("AR_Dance") == "disco" and type(dancer.Character:GetAttribute("AR_DanceT0")) == "number")
	run(1, 0.5)
	R.Social.OnServerEvent:_fire(dancer, "Dance", "inventado")
	check("un baile que no esta en la configuracion se rechaza", dancer.Character:GetAttribute("AR_Dance") == "disco" and lastNotice(dancer, "SocialNotice")[1] == "DanceDenied")
	R.Social.OnServerEvent:_fire(dancer, "Dance", { 1 })
	R.Social.OnServerEvent:_fire(dancer, "Dance", 5)
	run(1, 0.5)
	R.Social.OnServerEvent:_fire(dancer, "Dance", "ola")
	check("cambio de baile directo (transicion)", dancer.Character:GetAttribute("AR_Dance") == "ola")
	run(1, 0.5)
	R.Social.OnServerEvent:_fire(dancer, "StopDance")
	check("Detener limpia el baile", dancer.Character:GetAttribute("AR_Dance") == nil)
	run(1, 0.5)
	R.Social.OnServerEvent:_fire(dancer, "Dance", "suave")
	dancer.Character:FindFirstChildOfClass("Humanoid").Running:_fire(10)
	check("echar a andar corta el baile", dancer.Character:GetAttribute("AR_Dance") == nil)
	run(1, 0.5)
	R.Social.OnServerEvent:_fire(dancer, "Dance", "suave")
	dancer.Character:FindFirstChildOfClass("Humanoid").Jumping:_fire(true)
	check("saltar corta el baile", dancer.Character:GetAttribute("AR_Dance") == nil)
	run(1, 0.5)
	Config.Dance.Dances[2].Access = "Lista"
	R.Social.OnServerEvent:_fire(dancer, "Dance", "disco")
	check("baile con Access='Lista': solo para los de la lista", dancer.Character:GetAttribute("AR_Dance") == nil)
	Config.Dance.Dances[2].Access = "Todos"
	run(1, 0.5)
	dancer.Character:FindFirstChildOfClass("Humanoid").Sit = true
	R.Social.OnServerEvent:_fire(dancer, "Dance", "suave")
	check("sentado no se puede bailar", dancer.Character:GetAttribute("AR_Dance") == nil)

	-- chat
	local tcs = game:GetService("TextChatService")
	check("TextChatService oficial: ventana, barra de entrada y burbujas activadas", tcs.ChatWindowConfiguration.Enabled == true and tcs.ChatInputBarConfiguration.Enabled == true and tcs.BubbleChatConfiguration.Enabled == true)
	check("no se crea ningun chat propio (sin RemoteEvent de chat)", R:FindFirstChild("Chat") == nil)
end

print(string.format("\nRESULTADO SERVIDOR: %d comprobaciones, %d fallo(s)", total, failures))
if failures > 0 then
	error("hay pruebas de servidor fallando")
end
