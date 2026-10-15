-- Comprobaciones de la CABINA DE CONTROL y del LocalScript de efectos (modo "client": el Script del
-- servidor encuentra el hijo ClientEffects y delega las animaciones en el cliente).

local failures = 0
local function check(name, cond, detail)
	if cond then
		print("  PASS  " .. name)
	else
		failures += 1
		print("  FAIL  " .. name .. (detail and (" -> " .. tostring(detail)) or ""))
	end
end
local function run(seconds, dt)
	for _ = 1, math.floor(seconds / dt) do
		fireHeartbeat(dt)
	end
end
local function named(pat)
	local out = {}
	for _, d in club:GetDescendants() do
		if string.match(d.Name, pat) then table.insert(out, d) end
	end
	return out
end
local function find(n)
	for _, d in club:GetDescendants() do
		if d.Name == n then return d end
	end
end
local function tagged(tag) return __collection:GetTagged(tag) end
local function noticeKinds(player)
	local out = {}
	for _, n in __noticeLog do
		if n.player == player then table.insert(out, n.args[1]) end
	end
	return out
end
local function lastNotice(player)
	local k = noticeKinds(player)
	return k[#k]
end

print("\n=== TESTS CABINA DE CONTROL Y CLIENTE (perfil " .. PROFILE_NAME .. ") ===")
local control = club:FindFirstChild("Control")

do -- ---------------------------------------------------------------- servidor
	check("el servidor delega: LocalScript copiado a StarterPlayerScripts", __starterPlayer:FindFirstChild("StarterPlayerScripts"):FindFirstChild("LaAlfombraRojaFX") ~= nil)
	check("el servidor solo mantiene 1 conexion Heartbeat (vigilante del operador), sin animar", #__heartbeat == 1, #__heartbeat)
	check("estado compartido en club.Control con valores por defecto elegantes", control ~= nil and control:GetAttribute("Preset") == "Elegante" and control:GetAttribute("Master") == 1 and control:GetAttribute("Lasers") == false and control:GetAttribute("Palette") == "Champan")
	check("estrobo OPCIONAL y APAGADO de inicio", control:GetAttribute("Strobe") == false)
	check("sin operador al inicio", control:GetAttribute("Operator") == 0 and control:GetAttribute("OperatorName") == "")
	check("perfil visible para el cliente", club:GetAttribute("Quality") == PROFILE_NAME)
	check("etiquetas: baldosas, laseres, focos, estrobos, espejo", #tagged("AR_Tile") == TILE_COUNT * TILE_COUNT and #tagged("AR_Laser") == 6 and #tagged("AR_Spot") == 12 and #tagged("AR_Strobe") == 10 and #tagged("AR_Mirror") == #named("^MirrorFacet$"))
	check("etiquetas: neones, lamparas, conos, pantallas, placa y cabina", #tagged("AR_Glow") > 40 and #tagged("AR_Lamp") >= 36 and #tagged("AR_Shaft") == 12 // PROFILE.shaftEvery and #tagged("AR_Status") == 1 and #tagged("AR_Desk") == 1 and #tagged("AR_Screen") == 1, #tagged("AR_Glow") .. "/" .. #tagged("AR_Lamp") .. "/" .. #tagged("AR_Shaft") .. "/" .. #tagged("AR_Status") .. "/" .. #tagged("AR_Desk") .. "/" .. #tagged("AR_Screen"))
	local lights = tagged("AR_Light")
	local zones, bad, safeN = {}, 0, 0
	for _, l in lights do
		local z = l:GetAttribute("z")
		zones[z] = (zones[z] or 0) + 1
		if z == nil or l:GetAttribute("b") == nil then bad += 1 end
		if l:GetAttribute("safe") then safeN += 1 end
	end
	print(string.format("        luces reguladas: %d (Pista %d, Vip %d, Rooftop %d, Alfombra %d, Ext %d), de seguridad: %d", #lights, zones.Pista or 0, zones.Vip or 0, zones.Rooftop or 0, zones.Alfombra or 0, zones.Ext or 0, safeN))
	check("cada luz regulada tiene zona y brillo base; hay luces en las 4 zonas", bad == 0 and (zones.Pista or 0) > 5 and (zones.Vip or 0) > 3 and (zones.Rooftop or 0) > 3 and (zones.Alfombra or 0) >= 3)
	local safeStairs, safeFill = 0, 0
	for _, l in lights do
		if l:GetAttribute("safe") then
			if string.find(l.Parent.Name, "^StairLamp") then safeStairs += 1 end
			if string.find(l.Parent.Name, "^Fill") then safeFill += 1 end
		end
	end
	check("luces de seguridad: 6 en escaleras y 27 de relleno de pasillos", safeStairs == 6 and safeFill == 27, safeStairs .. "/" .. safeFill)
	local rf = __replicated:FindFirstChild("AlfombraControl")
	check("RemoteEvents Request y Notice en ReplicatedStorage", rf ~= nil and rf:FindFirstChild("Request") ~= nil and rf:FindFirstChild("Notice") ~= nil)
	local desk = find("LightDesk_Top")
	local prompt = desk and desk:FindFirstChildOfClass("ProximityPrompt") or (desk and desk:FindFirstChild("ControlPrompt"))
	check("ProximityPrompt en la cabina (E, <= 20 studs, en espanol)", prompt ~= nil and prompt.MaxActivationDistance <= 20 and prompt.ActionText == "Abrir panel de luces" and prompt.RequiresLineOfSight == false)
	__countWrites = true
	__writes = 0
	run(10, 1 / 30)
	__countWrites = false
	check("servidor: 0 escrituras de animacion decorativa por segundo", __writes == 0, __writes)
end

do -- ------------------------------------------------------- operador unico y permisos
	local desk = find("LightDesk_Top")
	local dp = desk.CFrame.Position
	local near = Vector3.new(dp.X, dp.Y + 4, dp.Z + 5)
	local p1 = __makePlayer("Ana", 101, near)
	local p2 = __makePlayer("Beto", 202, near)
	local pFar = __makePlayer("Lejos", 303, Vector3.new(60, 3, 60))
	local prompt = desk:FindFirstChild("ControlPrompt")
	local function op() return control:GetAttribute("Operator") end

	prompt.Triggered:_fire(pFar)
	check("jugador lejos de la cabina: acceso denegado", op() == 0 and lastNotice(pFar) == "Denied")
	prompt.Triggered:_fire(p1)
	check("p1 toma el control: operador = p1 y se abre su panel", op() == 101 and control:GetAttribute("OperatorName") == "Ana" and lastNotice(p1) == "Open")
	prompt.Triggered:_fire(p2)
	check("un solo operador a la vez: p2 recibe 'ocupado'", op() == 101 and lastNotice(p2) == "Busy")
	local req = __replicated:FindFirstChild("AlfombraControl"):FindFirstChild("Request")
	local function call(player, action, value)
		req.OnServerEvent:_fire(player, action, value)
	end
	-- avanzar el reloj para recargar fichas entre grupos de peticiones
	local function refill() run(2, 0.5) end

	call(p2, "Master", 0.2)
	check("un no-operador no puede cambiar nada", control:GetAttribute("Master") == 1 and lastNotice(p2) == "Denied")
	refill()
	call(p1, "Master", 1.3)
	check("operador: intensidad general 1.3 (y el preset pasa a Personalizado)", control:GetAttribute("Master") == 1.3 and control:GetAttribute("Preset") == "Personalizado")
	call(p1, "Master", 99)
	check("intensidad fuera de rango se limita a 1.5", control:GetAttribute("Master") == 1.5)
	call(p1, "Master", "alta")
	call(p1, "Master", 0 / 0)
	call(p1, "Master", math.huge)
	check("valores no numericos / NaN se rechazan; infinito se limita", control:GetAttribute("Master") == 1.5)
	refill()
	call(p1, "ZVip", 0.5)
	call(p1, "OnRooftop", false)
	call(p1, "ZAlfombra", 1.2)
	check("intensidad y encendido por zonas (VIP, rooftop, alfombra)", control:GetAttribute("ZVip") == 0.5 and control:GetAttribute("OnRooftop") == false and control:GetAttribute("ZAlfombra") == 1.2)
	refill()
	call(p1, "Lasers", true)
	call(p1, "Lasers", "si")
	call(p1, "Strobe", true)
	call(p1, "SpotMove", true)
	check("efectos booleanos (laseres, focos) y estrobo independiente; tipo invalido rechazado", control:GetAttribute("Lasers") == true and control:GetAttribute("Strobe") == true and control:GetAttribute("SpotMove") == true)
	call(p1, "Strobe", false)
	check("el estrobo se desactiva por separado sin tocar lo demas", control:GetAttribute("Strobe") == false and control:GetAttribute("Lasers") == true)
	refill()
	call(p1, "Speed", 5)
	call(p1, "MirrorSpeed", -3)
	check("velocidades limitadas (0.25-2 y 0-2)", control:GetAttribute("Speed") == 2 and control:GetAttribute("MirrorSpeed") == 0)
	call(p1, "Palette", "Rosa")
	call(p1, "Palette", "Hackeada")
	check("paleta valida aplicada; paleta desconocida rechazada", control:GetAttribute("Palette") == "Rosa")
	refill()
	call(p1, "Preset", "Discoteca")
	check("preset Discoteca: laseres, focos, paleta Multicolor y estrobo SIGUE apagado", control:GetAttribute("Preset") == "Discoteca" and control:GetAttribute("Lasers") == true and control:GetAttribute("Palette") == "Multicolor" and control:GetAttribute("Strobe") == false)
	call(p1, "Preset", "Fiesta")
	check("preset Fiesta", control:GetAttribute("Preset") == "Fiesta" and control:GetAttribute("Palette") == "Rosa" and control:GetAttribute("SpotMove") == true)
	refill()
	call(p1, "Preset", "SinEfectos")
	check("preset Apagado de efectos: sin laseres, haces, focos, pulso, giro ni estrobo", control:GetAttribute("Lasers") == false and control:GetAttribute("Shafts") == false and control:GetAttribute("SpotMove") == false and control:GetAttribute("Pulse") == false and control:GetAttribute("MirrorSpin") == false and control:GetAttribute("Strobe") == false)
	call(p1, "Preset", "Inexistente")
	call(p1, "NoExiste", 1)
	call(p1, 42, 1)
	check("preset inexistente / accion desconocida / accion no-texto se rechazan", control:GetAttribute("Preset") == "SinEfectos")
	refill()
	call(p1, "Restore", true)
	local ok = true
	for k, v in {} do ok = false end
	check("Restaurar iluminacion elegante: todo vuelve al estado por defecto (incluidas zonas)", control:GetAttribute("Preset") == "Elegante" and control:GetAttribute("Master") == 1 and control:GetAttribute("ZVip") == 1 and control:GetAttribute("OnRooftop") == true and control:GetAttribute("ZAlfombra") == 1 and control:GetAttribute("Palette") == "Champan" and control:GetAttribute("Strobe") == false and control:GetAttribute("Lasers") == false)

	-- limite de peticiones: cubo de 8 fichas
	refill()
	local accepted = 0
	local conn = control:GetAttributeChangedSignal("Master"):Connect(function() accepted += 1 end)
	for i = 1, 40 do
		call(p1, "Master", 0.05 + 0.05 * (i % 29))
	end
	conn.Disconnect()
	check("limite de peticiones: 40 seguidas -> como mucho 8 aceptadas (+ aviso al jugador)", accepted <= 9 and accepted >= 1, accepted)
	check("aviso 'Demasiadas acciones' enviado una vez", lastNotice(p1) == "Info")
	refill()
	call(p1, "Master", 1)
	check("tras esperar se recuperan las fichas", control:GetAttribute("Master") == 1)

	-- liberar, tomar otro, lejania, inactividad, salida del juego
	call(p1, "Release", true)
	check("Soltar control: operador libre y p1 recibe 'Closed'", op() == 0 and lastNotice(p1) == "Closed")
	prompt.Triggered:_fire(p2)
	check("tras soltar, p2 puede tomar el control", op() == 202)
	p2._hrp.Position = Vector3.new(60, 3, 60)
	refill()
	call(p2, "Master", 0.5)
	check("operador que se aleja pierde el control (peticion rechazada)", op() == 0 and control:GetAttribute("Master") == 1)
	p2._hrp.Position = near
	prompt.Triggered:_fire(p2)
	check("operador vuelve y retoma", op() == 202)
	p2._hrp.Position = Vector3.new(60, 3, 60)
	run(4, 1)
	check("vigilante: libera al operador que se aleja sin hacer nada", op() == 0)
	p2._hrp.Position = near
	prompt.Triggered:_fire(p2)
	run(CONFIG.Control.IdleTimeout - 30, 2)
	check("antes del limite de inactividad sigue siendo operador", op() == 202)
	run(60, 2)
	check("inactividad: control liberado tras " .. CONFIG.Control.IdleTimeout .. " s", op() == 0 and lastNotice(p2) == "Closed")
	prompt.Triggered:_fire(p1)
	__players.PlayerRemoving:_fire(p1)
	check("el operador sale del juego: control liberado", op() == 0)

	-- permisos configurables
	local C = CONFIG.Control
	C.Access = "Lista"
	C.UserIds = { 202 }
	prompt.Triggered:_fire(p1)
	check("permiso Lista: jugador fuera de la lista denegado", op() == 0 and lastNotice(p1) == "Denied")
	prompt.Triggered:_fire(p2)
	check("permiso Lista: jugador de la lista admitido", op() == 202)
	call(p2, "Release", true)
	C.UserIds = {}
	C.GroupId = 77
	C.MinRank = 3
	p1._rank = 5
	prompt.Triggered:_fire(p1)
	check("permiso Lista por grupo/rango: rango suficiente admitido", op() == 101)
	call(p1, "Release", true)
	p1._rank = 1
	prompt.Triggered:_fire(p1)
	check("permiso por grupo: rango insuficiente denegado", op() == 0)
	C.Access = "Dueno"
	prompt.Triggered:_fire(p2)
	check("permiso Dueno: fuera de Studio solo el creador (aqui nadie)", op() == 0)
	C.Access, C.GroupId = "Todos", 0
end

do -- ------------------------------------------------------------------- cliente
	local desk = find("LightDesk_Top")
	local dp = desk.CFrame.Position
	local lp = __makePlayer("Local", 111, Vector3.new(dp.X, dp.Y + 4, dp.Z + 5))
	__localPlayer = lp
	__players.LocalPlayer = lp
	__loadClient()
	check("cliente cargado: engancha su propio Heartbeat", #__heartbeat == 2, #__heartbeat)
	run(1, 1 / 60)

	-- luces: brillo = base * factor de zona; las de seguridad nunca bajan de 45 %
	local lights = tagged("AR_Light")
	local function checkLights(label, fn)
		local bad
		for _, l in lights do
			local f = fn(l:GetAttribute("z"), l:GetAttribute("safe"))
			local want = l:GetAttribute("b") * f
			if math.abs(l.Brightness - want) > 1e-6 or (l.Enabled ~= (f > 0.01)) then
				bad = bad or (l.Parent.Name .. " " .. l.Brightness .. " vs " .. want)
			end
		end
		check(label, bad == nil, bad)
	end
	checkLights("estado elegante: todas las luces a su brillo base", function() return 1 end)
	local lasersOn, lasersOff = 0, 0
	for _, a in tagged("AR_Laser") do
		for _, c in a.Parent:GetChildren() do
			if c:IsA("Beam") and c.Attachment1 == a then
				if c.Enabled then lasersOn += 1 else lasersOff += 1 end
			end
		end
	end
	check("elegante: laseres apagados y conos de luz activos", lasersOn == 0 and lasersOff == 6 * PROFILE.laserLayers)
	local shaftOn = 0
	for _, sh in tagged("AR_Shaft") do if sh.Enabled then shaftOn += 1 end end
	check("elegante: todos los conos de luz encendidos", shaftOn == #tagged("AR_Shaft"))

	-- zonas y minimos de seguridad
	control:SetAttribute("OnVip", false)
	control:SetAttribute("Master", 0.5)
	control:SetAttribute("ZPista", 1.4)
	run(0.5, 1 / 60)
	checkLights("zona VIP apagada, general 50 %, pista 140 %: factores por zona y luces de seguridad >= 45 %", function(z, safe)
		if z == "Ext" then return 1 end
		local f = 0.5 * ((z == "Pista") and 1.4 or 1)
		if z == "Vip" then f = 0 end
		if safe then f = math.max(f, 0.45) end
		return f
	end)
	control:SetAttribute("Master", 0)
	run(0.5, 1 / 60)
	local minSafe, maxDecor = math.huge, 0
	for _, l in lights do
		local z = l:GetAttribute("z")
		if z ~= "Ext" then
			if l:GetAttribute("safe") then minSafe = math.min(minSafe, l.Brightness / l:GetAttribute("b")) else maxDecor = math.max(maxDecor, l.Brightness) end
		end
	end
	check("general al 0 %: la decoracion se apaga pero pasillos y escaleras siguen al 45 %", maxDecor == 0 and math.abs(minSafe - 0.45) < 1e-6, minSafe .. "/" .. maxDecor)
	control:SetAttribute("Master", 1.5)
	control:SetAttribute("ZVip", 1.5)
	control:SetAttribute("OnVip", true)
	control:SetAttribute("ZPista", 1)
	run(0.5, 1 / 60)
	local maxRatio = 0
	for _, l in lights do maxRatio = math.max(maxRatio, l.Brightness / l:GetAttribute("b")) end
	check("intensidad maxima (general x zona) limitada al 150 % del brillo base", maxRatio <= 1.5001 and maxRatio >= 1.49, maxRatio)
	control:SetAttribute("Master", 1)
	control:SetAttribute("ZVip", 1)

	-- laseres, focos
	control:SetAttribute("Lasers", true)
	run(1, 1 / 60)
	local on = 0
	for _, a in tagged("AR_Laser") do
		for _, c in a.Parent:GetChildren() do if c:IsA("Beam") and c.Attachment1 == a and c.Enabled then on += 1 end end
	end
	check("activar laseres enciende todas sus capas", on == 6 * PROFILE.laserLayers, on)
	local a1 = tagged("AR_Laser")[1]
	local p0 = a1.Position
	run(1, 1 / 60)
	check("los laseres se mueven (solo se escribe la punta)", math.abs((a1.Position - p0).Magnitude) > 0.01)
	local spot = tagged("AR_Spot")[1]
	local cf0 = spot.CFrame
	control:SetAttribute("SpotMove", true)
	run(2, 1 / 60)
	check("movimiento de focos: los focos oscilan", spot.CFrame.pz ~= cf0.pz or spot.CFrame.r[1] ~= cf0.r[1] or spot.CFrame.r[5] ~= cf0.r[5] or spot.CFrame.r[9] ~= cf0.r[9] or math.abs(spot.CFrame.r[2] - cf0.r[2]) > 1e-6)
	control:SetAttribute("SpotMove", false)
	run(0.5, 1 / 60)
	check("al desactivarlos vuelven a su posicion original", math.abs(spot.CFrame.px - cf0.px) < 1e-9 and math.abs(spot.CFrame.r[2] - cf0.r[2]) < 1e-9)
	control:SetAttribute("Lasers", false)

	-- bola de espejos
	local facet = tagged("AR_Mirror")[1]
	local m0 = facet.CFrame
	run(2, 1 / 60)
	local moved = facet.CFrame.px ~= m0.px or facet.CFrame.pz ~= m0.pz
	check("la bola de espejos gira por defecto (suave)", moved)
	control:SetAttribute("MirrorSpin", false)
	run(0.5, 1 / 60)
	local m1 = facet.CFrame
	run(2, 1 / 60)
	check("giro desactivable desde el panel", facet.CFrame.px == m1.px and facet.CFrame.pz == m1.pz)
	control:SetAttribute("MirrorSpin", true)
	control:SetAttribute("MirrorSpeed", 2)
	local m2 = facet.CFrame
	run(1, 1 / 60)
	local d2 = math.abs(facet.CFrame.px - m2.px) + math.abs(facet.CFrame.pz - m2.pz)
	control:SetAttribute("MirrorSpeed", 0.5)
	local m3 = facet.CFrame
	run(1, 1 / 60)
	local d3 = math.abs(facet.CFrame.px - m3.px) + math.abs(facet.CFrame.pz - m3.pz)
	check("velocidad de la bola regulable (2x gira mas que 0.5x)", d2 > d3 * 1.5, d2 .. " vs " .. d3)

	-- estrobo
	local strobes = tagged("AR_Strobe")
	local anyOn = false
	for _ = 1, 60 * 30 do
		fireHeartbeat(1 / 30)
		for _, st in strobes do
			local l = st:FindFirstChildOfClass("SpotLight")
			if l and l.Enabled then anyOn = true end
		end
	end
	check("estrobo apagado: 30 s sin ningun destello", anyOn == false)
	control:SetAttribute("Strobe", true)
	local flashes, prevOn, maxPerSec, secBucket, cur = 0, false, 0, 0, 0
	local lightMax = 0
	for i = 1, 20 * 30 do
		fireHeartbeat(1 / 30)
		local l = strobes[1]:FindFirstChildOfClass("SpotLight")
		if l then lightMax = math.max(lightMax, l.Brightness) end
		local on = l ~= nil and l.Enabled == true
		if on and not prevOn then
			flashes += 1
			cur += 1
		end
		prevOn = on
		if i % 30 == 0 then
			maxPerSec = math.max(maxPerSec, cur)
			cur = 0
		end
	end
	check("estrobo activado: hay destellos en rafagas", flashes > 0, flashes)
	check("estrobo: nunca mas de 3 destellos por segundo y brillo <= 2.5", maxPerSec <= 3 and lightMax <= 2.5, maxPerSec .. " / " .. lightMax)
	control:SetAttribute("Strobe", false)
	run(1, 1 / 30)
	local stillOn = false
	for _, st in strobes do
		local l = st:FindFirstChildOfClass("SpotLight")
		if l and l.Enabled then stillOn = true end
	end
	check("estrobo: al desactivarlo se apaga de inmediato", stillOn == false)

	-- paletas
	local tile = tagged("AR_Tile")[1]
	control:SetAttribute("Palette", "Rojo")
	run(3, 1 / 30)
	local rs, bs = 0, 0
	for _, tl in tagged("AR_Tile") do rs += tl.Color.R; bs += tl.Color.B end
	check("paleta Rojo: las baldosas viran a rojo", rs > bs * 1.3, rs .. " vs " .. bs)
	control:SetAttribute("Palette", "Multicolor")
	local ok = pcall(function() run(5, 1 / 30) end)
	check("paleta Multicolor sin errores", ok)
	control:SetAttribute("Palette", "Champan")
	run(2, 1 / 30)

	-- rendimiento del cliente (escrituras de propiedades por segundo, simulador: NO son FPS)
	local function wps(label, dt)
		__countWrites = true
		__writes = 0
		run(6, dt)
		__countWrites = false
		local v = __writes / 6
		print(string.format("        %s: %.0f escrituras/s", label, v))
		return v
	end
	local base60 = wps("elegante a 60 fps", 1 / 60)
	local base20 = wps("elegante a 20 fps (equipo justo)", 1 / 20)
	check("frecuencia adaptativa: a 20 fps escribe menos que a 60 fps", base20 < base60 * 0.8, base20 .. " vs " .. base60)
	local capBase, capDisco = PROFILE_NAME == "Alta" and 3500 or 1800, PROFILE_NAME == "Alta" and 6000 or 4500
	check("elegante: < " .. capBase .. " escrituras/s en el cliente (locales, sin red)", base60 < capBase, base60)
	control:SetAttribute("Preset", "Discoteca")
	for k, v in { Lasers = true, SpotMove = true, Pulse = true, MirrorSpin = true, Speed = 1.6, MirrorSpeed = 1.5, Palette = "Multicolor" } do control:SetAttribute(k, v) end
	run(1, 1 / 60)
	local disco = wps("discoteca a 60 fps", 1 / 60)
	check("discoteca: < " .. capDisco .. " escrituras/s en el cliente", disco < capDisco, disco)
	for k, v in { Lasers = false, SpotMove = false, Pulse = false, MirrorSpin = false, Shafts = false, Speed = 0.6, Palette = "Champan" } do control:SetAttribute(k, v) end
	run(2, 1 / 60)
	local quiet = wps("apagado de efectos", 1 / 60)
	check("apagado de efectos: casi sin escrituras (< 700/s: solo ondas de pista y llamas)", quiet < 700, quiet)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 900)
	run(1, 1 / 60)
	local far = wps("camara lejos del club", 1 / 60)
	check("camara lejos del club (> 240 studs): no se anima nada", far < 5, far)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	for k, v in { Lasers = false, SpotMove = false, Pulse = true, MirrorSpin = true, Shafts = true, Speed = 0.6, MirrorSpeed = 0.5, Palette = "Champan", Preset = "Elegante" } do control:SetAttribute(k, v) end
	run(1, 1 / 60)
end

do -- ---------------------------------------------------------------- panel (UI)
	local lp = __players.LocalPlayer
	local desk = find("LightDesk_Top")
	local prompt = desk:FindFirstChild("ControlPrompt")
	local pg = lp._gui
	check("el panel no existe hasta abrir la cabina", pg:FindFirstChild("LaAlfombraRojaControl") == nil)
	-- el servidor registra cuantas peticiones llegan
	local req = __replicated:FindFirstChild("AlfombraControl"):FindFirstChild("Request")
	local received = 0
	req.OnServerEvent:Connect(function() received += 1 end)
	prompt.Triggered:_fire(lp)
	local gui = pg:FindFirstChild("LaAlfombraRojaControl")
	check("al interactuar (E) se abre el panel para el operador", gui ~= nil and gui.Enabled == true and control:GetAttribute("Operator") == 111)
	local function buttons()
		local out = {}
		for _, d in gui:GetDescendants() do
			if d.ClassName == "TextButton" then out[d.Text ~= "" and d.Text or d.Name] = d end
		end
		return out
	end
	local texts = {}
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextLabel" or d.ClassName == "TextButton" then table.insert(texts, d.Text) end
	end
	local all = table.concat(texts, "|")
	for _, need in { "CONTROL DE LUCES", "Intensidad", "General", "Pista", "VIP", "Rooftop", "Alfombra roja", "Elegante cálido", "Fiesta", "Discoteca", "Apagado de efectos", "Haces de luz", "Láseres", "Movimiento de focos", "Pulso de color", "Giro de la bola de espejos", "Velocidad efectos", "Velocidad bola", "Champán", "Hielo", "Rosa", "Violeta", "Rojo", "Multicolor", "Estrobo", "fotosensibles", "Restaurar iluminación elegante", "Soltar el control", "Operador: Local" } do
		check("panel en espanol: contiene '" .. need .. "'", string.find(all, need, 1, true) ~= nil)
	end
	local b = buttons()
	check("estrobo apagado y marcado como 'Apagado' en el panel", control:GetAttribute("Strobe") == false)
	local function click(btn)
		run(0.2, 1 / 60) -- pasa el minimo entre clics de la interfaz
		btn.MouseButton1Click:_fire()
	end
	click(b["Fiesta"])
	check("boton Fiesta aplica el preset (sincronizado: atributos compartidos)", control:GetAttribute("Preset") == "Fiesta" and control:GetAttribute("Lasers") == true)
	click(b["Discoteca"])
	check("boton Discoteca", control:GetAttribute("Preset") == "Discoteca")
	click(b["Apagado de efectos"])
	check("boton Apagado de efectos", control:GetAttribute("Lasers") == false and control:GetAttribute("Pulse") == false)
	click(b["Elegante cálido"])
	check("boton Elegante cálido", control:GetAttribute("Preset") == "Elegante")
	local minus, plus
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextFrame" then end
	end
	-- stepper "General": primer par de botones - / +
	local pm = {}
	for _, d in gui:GetDescendants() do
		if d.ClassName == "TextButton" and (d.Name == "Minus" or d.Name == "Plus") then table.insert(pm, d) end
	end
	click(pm[1])
	check("boton '-' de General baja la intensidad un 10 %", math.abs(control:GetAttribute("Master") - 0.9) < 1e-6, control:GetAttribute("Master"))
	click(pm[2])
	click(pm[2])
	check("boton '+' sube un 10 % (se limita a 150 %)", math.abs(control:GetAttribute("Master") - 1.1) < 1e-6, control:GetAttribute("Master"))
	-- giros de paleta y estrobo desde la UI
	click(b["Rosa"])
	check("boton de paleta Rosa", control:GetAttribute("Palette") == "Rosa")
	local strobeBtn
	for _, d in gui:GetDescendants() do
		if d.ClassName == "Frame" and d.Name == "T_Strobe" then
			for _, c in d:GetChildren() do if c.ClassName == "TextButton" then strobeBtn = c end end
		end
	end
	click(strobeBtn)
	check("el estrobo se activa solo si el operador lo pide", control:GetAttribute("Strobe") == true)
	click(strobeBtn)
	check("y se desactiva con el mismo control independiente", control:GetAttribute("Strobe") == false)
	click(b["Restaurar iluminación elegante"])
	check("boton Restaurar iluminación elegante", control:GetAttribute("Preset") == "Elegante" and control:GetAttribute("Palette") == "Champan" and control:GetAttribute("Master") == 1)

	-- limite de clics desde la interfaz
	run(0.5, 1 / 60)
	received = 0
	for _ = 1, 30 do b["Fiesta"].MouseButton1Click:_fire() end
	check("la interfaz limita los clics (30 clics en el mismo instante = 1 peticion)", received <= 1, received)

	-- placa de operador y cierre por distancia
	run(1, 1 / 60)
	local label = find("ControlStatusLabel")
	check("la placa de la cabina muestra al operador", label.Text == "OPERADOR: LOCAL", label.Text)
	lp._hrp.Position = Vector3.new(60, 3, 60)
	run(1.5, 1 / 60)
	check("al alejarse el panel se cierra y se libera el control", gui.Enabled == false and control:GetAttribute("Operator") == 0)
	run(1, 1 / 60)
	check("la placa vuelve a 'LIBRE'", label.Text == "OPERADOR: LIBRE", label.Text)
	-- aviso (toast) para el que no puede
	local dp = desk.CFrame.Position
	lp._hrp.Position = Vector3.new(dp.X, dp.Y + 4, dp.Z + 5)
	CONFIG.Control.Access = "Lista"
	CONFIG.Control.UserIds = {}
	prompt.Triggered:_fire(lp)
	local toast = pg:FindFirstChild("LaAlfombraRojaAviso")
	check("sin permiso: aviso en pantalla y el panel no se abre", toast ~= nil and toast:FindFirstChild("Toast").Visible == true and string.find(toast:FindFirstChild("Toast").Text, "permiso", 1, true) ~= nil and gui.Enabled == false)
	CONFIG.Control.Access = "Todos"
end

print(string.format("\nRESULTADO CLIENTE: %d fallo(s)", failures))
if failures > 0 then
	error("hay tests fallando")
end
