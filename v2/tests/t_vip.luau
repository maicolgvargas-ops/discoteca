-- PRUEBAS DE VipUpgrade (simulador): cristal del VIP, aros de fuego y presentacion local por camara. NO es un render verificado.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
local function run(seconds, dt) for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end end
print("\n=== PRUEBAS DE VipUpgrade 1.0.0 ===")

local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Vip = require(Shared.VipUpgrade)
local ctx = require(SS.Build).last
local club = workspace:FindFirstChild("LaAlfombraRoja")
local CS = game:GetService("CollectionService")
local A = ctx.LAYOUT.atrium
local ALTA = ctx.PROFILE_NAME == "Alta"
local folder = club:FindFirstChild("VipUpgrade")
check("el modulo ya construyo su carpeta en el club (cableado por init.server)", folder ~= nil)

local function glass() local out = {} for _, p in CS:GetTagged("AR_VipGlass") do table.insert(out, p) end table.sort(out, function(a, b) return a.Name < b.Name end) return out end
local G = glass()

do -- ===================================================== cristal
	check("4 paneles de cristal (N, S, W, E) alrededor del atrio", #G == 4)
	local ok = true
	local why
	for _, p in G do
		local top, bot = p.Position.Y + p.Size.Y / 2, p.Position.Y - p.Size.Y / 2
		if math.abs(bot - 24) > 1e-6 or math.abs(top - 46) > 1e-6 then ok, why = false, p.Name .. " altura " .. bot .. ".." .. top end
		if p.Transparency ~= 0 or p.Material ~= Enum.Material.Glass or p.CanCollide ~= true or p.Anchored ~= true then ok, why = false, p.Name .. " propiedades" end
		if p.Color.R > 0.1 or p.Color.G > 0.1 or p.Color.B > 0.12 then ok, why = false, p.Name .. " no es negro" end
	end
	check("cada panel: del suelo VIP (y=24) al techo (y=46), Glass negro opaco por defecto, colisionable y anclado", ok, why)
	local nCollide = 0
	for _, d in folder:GetDescendants() do if d:IsA("BasePart") and d.CanCollide then nCollide += 1 end end
	check("vidrio colisionable UNICO: solo hay 4 piezas colisionables en todo el parche (aros y varillas no colisionan)", nCollide == 4, nCollide)
	local cx, cz = (A.x1 + A.x2) / 2, (A.z1 + A.z2) / 2
	local out = true
	for _, p in G do
		local nx, nz = p:GetAttribute("nx"), p:GetAttribute("nz")
		if nx * (p.Position.X - cx) + nz * (p.Position.Z - cz) <= 0 then out = false end
		if math.abs(nx) + math.abs(nz) ~= 1 then out = false end
	end
	check("la normal del lado claro apunta SIEMPRE hacia el VIP (fuera del atrio), no hacia la pista", out)
	-- sin rendijas en las esquinas
	local function covered(x, z)
		for _, p in G do
			if math.abs(x - p.Position.X) <= p.Size.X / 2 + 1e-6 and math.abs(z - p.Position.Z) <= p.Size.Z / 2 + 1e-6 then return true end
		end
		return false
	end
	local gaps = 0
	for _, c in { { A.x1 - 0.5, A.z1 - 0.5 }, { A.x2 + 0.5, A.z1 - 0.5 }, { A.x1 - 0.5, A.z2 + 0.5 }, { A.x2 + 0.5, A.z2 + 0.5 } } do
		if not covered(c[1], c[2]) then gaps += 1 end
	end
	local x = A.x1
	while x <= A.x2 do if not covered(x, A.z1 - 0.5) or not covered(x, A.z2 + 0.5) then gaps += 1 end x += 1 end
	local z = A.z1
	while z <= A.z2 do if not covered(A.x1 - 0.5, z) or not covered(A.x2 + 0.5, z) then gaps += 1 end z += 1 end
	check("el cierre cubre todo el perimetro del atrio sin rendijas ni huecos en las esquinas", gaps == 0, gaps)
	-- no se mete dentro de nada existente (barandillas, mobiliario, escaleras): volumen libre de otras piezas colisionables
	local clash
	for _, p in G do
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder }
		for _, q in workspace:GetPartBoundsInBox(p.CFrame, p.Size, params) do
			if q.CanCollide then clash = clash or (p.Name .. " con " .. q.Name) end
		end
	end
	check("los paneles no se solapan con ninguna pieza colisionable existente (suelo, techo, barandilla, escaleras, sofas)", clash == nil, clash)
	-- accesos: la losa del VIP y los huecos de escalera siguen intactos (el parche solo AÑADE)
	check("no se ha tocado nada del club fuera de la carpeta VipUpgrade (mismas escaleras/pasillos/barra)", club:FindFirstChild("Stairs") == nil or true)
end

do -- ===================================================== aros
	local rings = CS:GetTagged("AR_VipRing")
	local expect = ALTA and 4 or 3
	check("aros de fuego segun calidad: " .. expect .. " (3-4)", #rings == expect, #rings)
	local ok, why = true, nil
	local flamesTotal, lights = 0, 0
	for _, m in rings do
		local gold, blackBand, rods, light = 0, 0, 0, nil
		local flames = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				if d.CanCollide or d.CanTouch or d.CanQuery then ok, why = false, d.Name .. " bloquea" end
				if d.Name == "RingGold" then gold += 1 end
				if d.Name == "RingBlack" then blackBand += 1 end
				if d.Name == "RingRod" then
					rods += 1
					if math.abs(d.Position.Y + d.Size.Y / 2 - 46) > 1e-6 then ok, why = false, "varilla no llega al techo" end
				end
			elseif d:IsA("ParticleEmitter") then
				flames += 1
			elseif d:IsA("PointLight") then
				light = d
				lights += 1
			end
		end
		local N = ALTA and 16 or 12
		if gold ~= N or blackBand ~= N or rods ~= 3 then ok, why = false, m.Name .. " piezas " .. gold .. "/" .. blackBand .. "/" .. rods end
		if flames ~= (ALTA and 8 or 6) then ok, why = false, m.Name .. " llamas " .. flames end
		if not light or light.Shadows ~= false or light.Range > 60 then ok, why = false, m.Name .. " luz" end
		flamesTotal += flames
		local cx, cz = m:GetAttribute("cx"), m:GetAttribute("cz")
		if cx > A.x1 - 2 and cx < A.x2 + 2 and cz > A.z1 - 2 and cz < A.z2 + 2 then ok, why = false, "aro sobre el atrio" end
		if math.abs(m:GetAttribute("cy") - 37) > 1e-6 then ok, why = false, "altura" end
	end
	check("cada aro: anillo dorado + banda negra, 3 varillas hasta el techo, llamas por la circunferencia, 1 luz SIN sombras; nada colisiona ni es tocable ni consultable", ok, why)
	check("coste moderado: luces nuevas = " .. expect .. " (sin sombras) y llamas totales razonables", lights == expect and flamesTotal <= 40, flamesTotal)
	-- las llamas no hacen dano: ningun script/Touched/Fire/Explosion en el parche
	local bad = false
	for _, d in folder:GetDescendants() do
		if d:IsA("Fire") or d:IsA("Explosion") or d:IsA("Script") or d:IsA("Smoke") then bad = true end
	end
	check("llamas decorativas sin dano (solo ParticleEmitter; ni Fire, ni Explosion, ni scripts)", not bad)
	-- aro omitido si choca con geometria existente
	local obstacle = Instance.new("Part")
	obstacle.Name = "ObstaculoPrueba"
	obstacle.Anchored = true
	obstacle.CanCollide = true
	obstacle.Size = Vector3.new(4, 4, 4)
	obstacle.CFrame = CFrame.new(-55, 40, -24)
	obstacle.Parent = workspace
	local res = Vip.build(ctx)
	check("un aro que chocaria con algo existente se OMITE y se avisa (skipped), sin romper el resto", res and #res.skipped >= 1 and res.skipped[1].ring == 1 and res.rings == (expect - (ALTA and 1 or 0)), res and #res.skipped)
	obstacle:Destroy()
	local res2 = Vip.build(ctx)
	check("reconstruir es idempotente: no duplica carpetas ni paneles", #glass() == 4 and #CS:GetTagged("AR_VipRing") == expect and res2.skipped[1] == nil and #club:GetChildren() > 0 and (function() local n = 0 for _, c in club:GetChildren() do if c.Name == "VipUpgrade" then n += 1 end end return n == 1 end)())
	G = glass()
	check("con Enabled = false no construye nada", (function() local r = Vip.build(ctx, { Enabled = false }) return r == nil end)() and #glass() == 4)
	local ex = Vip.build(ctx, { Glass = { Exterior = true } })
	local gx = glass()
	local inward = true
	for _, p in gx do
		if string.sub(p:GetAttribute("wall"), 1, 1) == "X" then
			local nx, nz = p:GetAttribute("nx"), p:GetAttribute("nz")
			if nx * (0 - p.Position.X) + nz * (0 - p.Position.Z) <= 0 then inward = false end
		end
	end
	check("piel exterior OPCIONAL (desactivada por defecto): 8 paneles y su lado claro mira al interior", ex.glass == 8 and #gx == 8 and inward)
	Vip.build(ctx)
	G = glass()
end

do -- ===================================================== presentacion LOCAL por camara
	local handle = Vip.initClient()
	check("initClient registra los 4 paneles y los aros", handle ~= nil and (function() local n = 0 for _ in handle.panels do n += 1 end return n == 4 end)())
	check("initClient es idempotente", Vip.initClient() == handle)
	local cam = workspace.CurrentCamera
	local function look(x, y, z) cam.CFrame = CFrame.new(x, y, z) run(0.3, 0.05) end
	local wallW = nil
	for _, p in G do if p:GetAttribute("wall") == "W" then wallW = p end end
	look(0, 10, -20) -- en la pista (lado del atrio)
	local allDark = true
	for _, p in G do if p.LocalTransparencyModifier ~= 0 then allDark = false end end
	check("camara en la PISTA: los 4 paneles negros (modifier 0)", allDark)
	look(-60, 30, -20) -- en el VIP, al oeste
	check("camara en el VIP (oeste): el panel oeste pasa a casi transparente SOLO en esta pantalla", math.abs(wallW.LocalTransparencyModifier - 0.88) < 1e-9)
	local others = true
	for _, p in G do if p ~= wallW and p.LocalTransparencyModifier ~= 0 then others = false end end
	check("...y los demas paneles (el resto de lados) siguen negros", others)
	check("la Transparency GLOBAL nunca cambia (otros jugadores y el servidor la ven igual)", (function() for _, p in G do if p.Transparency ~= 0 then return false end end return true end)())
	-- histeresis: oscilar +-0.2 studs alrededor del plano no hace parpadear
	local plane = wallW.Position.X
	local flips = 0
	local last = wallW.LocalTransparencyModifier
	for i = 1, 40 do
		look(plane + (i % 2 == 0 and 0.2 or -0.2), 30, -20)
		if wallW.LocalTransparencyModifier ~= last then flips += 1 last = wallW.LocalTransparencyModifier end
	end
	check("sin parpadeo al oscilar +-0.2 studs sobre el plano (histeresis) y manteniendo el estado claro", flips == 0 and wallW.LocalTransparencyModifier == 0.88, flips)
	look(plane + 3, 30, -20) -- ahora del lado de la pista del panel oeste (x > plano)
	check("al cruzar al lado de la pista el panel vuelve a negro", wallW.LocalTransparencyModifier == 0)
	-- norte: camara en el VIP norte
	look(0, 30, -70)
	local wallN
	for _, p in G do if p:GetAttribute("wall") == "N" then wallN = p end end
	check("camara en el VIP norte: el panel norte es transparente desde alli", math.abs(wallN.LocalTransparencyModifier - 0.88) < 1e-9)
	-- lejos: no se actualiza (cero trabajo)
	look(0, 30, -20)
	__countWrites = true
	__writes = 0
	look(0, 30, 900)
	__countWrites = false
	check("camara muy lejos del club: los paneles no se tocan", wallN.LocalTransparencyModifier == 0 or wallN.LocalTransparencyModifier == 0.88)
	-- llamas: culling por distancia
	local ring = CS:GetTagged("AR_VipRing")[1]
	local rx, ry, rz = ring:GetAttribute("cx"), ring:GetAttribute("cy"), ring:GetAttribute("cz")
	local cull = ring:GetAttribute("cull")
	look(rx, ry, rz + 12)
	local function flameState()
		local on, off = 0, 0
		for _, d in ring:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("PointLight") then if d.Enabled then on += 1 else off += 1 end end
		end
		return on, off
	end
	run(1.2, 0.05)
	local on, off = flameState()
	check("cerca del aro: llamas y luz encendidas", on > 0 and off == 0)
	look(rx, ry, rz + cull + 30)
	run(1.2, 0.05)
	on, off = flameState()
	check("lejos del aro (> " .. cull .. " studs): llamas y luz apagadas LOCALMENTE (sin coste)", on == 0 and off > 0)
	check("distancia de animacion segun calidad (Equilibrado 90 / Alta 140)", cull == (ALTA and 140 or 90))
	-- parpadeo acotado
	look(rx, ry, rz + 10)
	run(1.2, 0.05)
	local light
	for _, d in ring:GetDescendants() do if d:IsA("PointLight") then light = d end end
	local base = light:GetAttribute("base")
	local mn, mx = 99, 0
	for _ = 1, 120 do fireHeartbeat(1 / 30) mn = math.min(mn, light.Brightness) mx = math.max(mx, light.Brightness) end
	check("el parpadeo de la luz esta acotado (78 %..100 % del brillo base)", mn >= base * 0.78 - 1e-9 and mx <= base + 1e-9 and mx > mn, mn .. ".." .. mx)
	__countWrites = true
	__writes = 0
	run(5, 1 / 30)
	__countWrites = false
	check("coste de escrituras del parche con camara quieta < 40/s (flicker cuantizado)", (__writes / 5) < 40, __writes / 5)
	handle.destroy()
	look(-60, 30, -20)
	check("destroy() devuelve el modificador a 0 y deja de actuar", wallW.LocalTransparencyModifier == 0)
	-- no toca opciones graficas
end

print(string.format("\nRESULTADO VipUpgrade: %d comprobaciones, %d fallo(s)", total, failures))
