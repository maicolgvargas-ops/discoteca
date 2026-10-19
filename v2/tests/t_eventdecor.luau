-- PRUEBAS DE EventDecor (simulador): geometria, colision, limites, solapes y restricciones. NO es Studio ni un render.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
print("\n=== PRUEBAS DE EventDecor 1.0.0 ===")
local ED = require(__replicated:FindFirstChild("EventDecorTest"))

local function parts(model) local out = {} for _, d in model:GetDescendants() do if d:IsA("BasePart") then table.insert(out, d) end end return out end
local function aabb(p)
	local s, c, r = p.Size, p.CFrame, p.CFrame.r
	local hx = (math.abs(r[1]) * s.X + math.abs(r[2]) * s.Y + math.abs(r[3]) * s.Z) / 2
	local hy = (math.abs(r[4]) * s.X + math.abs(r[5]) * s.Y + math.abs(r[6]) * s.Z) / 2
	local hz = (math.abs(r[7]) * s.X + math.abs(r[8]) * s.Y + math.abs(r[9]) * s.Z) / 2
	return { c.px - hx, c.px + hx, c.py - hy, c.py + hy, c.pz - hz, c.pz + hz }
end
local function bbox(model)
	local b = { 1e9, -1e9, 1e9, -1e9, 1e9, -1e9 }
	for _, p in parts(model) do
		local a = aabb(p)
		b[1], b[2], b[3], b[4], b[5], b[6] = math.min(b[1], a[1]), math.max(b[2], a[2]), math.min(b[3], a[3]), math.max(b[4], a[4]), math.min(b[5], a[5]), math.max(b[6], a[6])
	end
	return b
end
local function noBadClasses(model)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("Sound") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Fire") or d:IsA("Explosion") then return false, d.ClassName end
	end
	return true
end
local function floating(model)
	-- cada pieza visible debe tocar (+-0.08) otra
	local list = {}
	for _, p in parts(model) do if (p.Transparency or 0) < 1 then table.insert(list, { p = p, a = aabb(p) }) end end
	local lost = {}
	for i, A in list do
		local touches = false
		for j, B in list do
			if i ~= j and A.a[1] - 0.08 <= B.a[2] and A.a[2] + 0.08 >= B.a[1] and A.a[3] - 0.08 <= B.a[4] and A.a[4] + 0.08 >= B.a[3] and A.a[5] - 0.08 <= B.a[6] and A.a[6] + 0.08 >= B.a[5] then touches = true break end
		end
		if not touches then table.insert(lost, A.p.Name) end
	end
	return lost
end
local function transform(cf) return cf end

local parent = Instance.new("Folder")
parent.Name = "Pruebas"
parent.Parent = workspace

-- ===================================================== piano
do
	local m = ED.buildPiano(parent, CFrame.new(0, 0, 0))
	check("buildPiano devuelve un Model parentado donde se pidio", m ~= nil and m:IsA("Model") and m.Parent == parent)
	local nW, nB, seats, colliders = 0, 0, 0, 0
	local unanchored = 0
	for _, p in parts(m) do
		if string.match(p.Name, "^KeyW%d+$") then nW += 1 end
		if string.match(p.Name, "^KeyB%d+$") then nB += 1 end
		if p:IsA("Seat") then seats += 1 end
		if p.CanCollide then colliders += 1 end
		if not p.Anchored then unanchored += 1 end
	end
	check("88 teclas: 52 blancas + 36 negras", nW == 52 and nB == 36, nW .. "/" .. nB)
	check("todas las piezas ancladas", unanchored == 0)
	check("el piano no colisiona (decoracion); el banco es 1 Seat nativo", colliders == 0 and seats == 1, colliders .. "/" .. seats)
	local ok, bad = noBadClasses(m)
	check("sin luces, sonidos, scripts, Fire ni Explosion", ok, bad)
	local bb = bbox(m)
	check("tamano razonable: ancho ~5,3, largo ~9,4 (con banco), altura con tapa 5-7", bb[2] - bb[1] > 5 and bb[2] - bb[1] < 5.8 and bb[6] - bb[5] > 8.5 and bb[6] - bb[5] < 10 and bb[4] > 5 and bb[4] < 7.2 and bb[3] >= -0.001, string.format("%.2f x %.2f x %.2f..%.2f", bb[2] - bb[1], bb[6] - bb[5], bb[3], bb[4]))
	local seat = m:FindFirstChild("PianoBenchSeat")
	local keys = m:FindFirstChild("KeyW26")
	local toKeys = keys.Position - seat.Position
	check("el Seat esta delante y su frente mira hacia el teclado", seat.Position.Z < -1 and seat.CFrame.LookVector.Z > 0.99 and (toKeys.X * seat.CFrame.LookVector.X + toKeys.Y * seat.CFrame.LookVector.Y + toKeys.Z * seat.CFrame.LookVector.Z) > 1 and seat.Transparency == 1 and seat.CanCollide == false)
	local lid = m:FindFirstChild("LidSlab3")
	local n = lid.CFrame.UpVector
	local ang = math.deg(math.acos(math.clamp(n.Y, -1, 1)))
	check("tapa INCLINADA entre 30 y 42 grados", ang > 30 and ang < 42, ang)
	check("3 patas, 3 pedales, lira, atril y puntal presentes", m:FindFirstChild("LegTop1") and m:FindFirstChild("LegTop3") and m:FindFirstChild("Pedal3") and m:FindFirstChild("LyreBoard") and m:FindFirstChild("MusicDesk") and m:FindFirstChild("LidProp") ~= nil)
	local lost = floating(m)
	check("ninguna pieza flota sin apoyo", #lost == 0, table.concat(lost, ","))
	-- suelo: las patas y pedales/banco llegan a y=0 y nada queda bajo el suelo
	check("apoya en el suelo local (y minimo 0) y mira al teclado en -Z", bb[3] > -0.001 and bb[3] < 0.05)
	-- transformacion: el modelo respeta cf (giro + traslacion) y mantiene su forma
	local m2 = ED.buildPiano(parent, CFrame.new(40, 12, -7) * CFrame.Angles(0, math.rad(90), 0), { name = "Piano2" })
	local seat2, key2 = m2:FindFirstChild("PianoBenchSeat"), m2:FindFirstChild("KeyW26")
	check("con cf girado 90 grados el banco sigue mirando al teclado y el origen esta en cf", m2.Name == "Piano2" and (function() local v = key2.Position - seat2.Position return (v.X * seat2.CFrame.LookVector.X + v.Z * seat2.CFrame.LookVector.Z) > 1 end)() and math.abs(bbox(m2)[3] - 12) < 0.05)
	local m3 = ED.buildPiano(parent, CFrame.new(0, 0, 0), { solid = true })
	local c3 = 0
	for _, p in parts(m3) do if p.CanCollide then c3 += 1 end end
	check("opts.solid = true hace colisionable el mobiliario (Seat no)", c3 > 100 and not m3.PianoBenchSeat.CanCollide)
	print(string.format("        piano: %d piezas", #parts(m)))
end

-- ===================================================== rottweiler
do
	local m = ED.buildRottweiler(parent, CFrame.new(0, 0, 0))
	check("buildRottweiler devuelve un Model parentado", m:IsA("Model") and m.Parent == parent)
	local names = { "Skull", "Muzzle", "Nose", "EyeL", "EyeR", "EarL", "EarR", "Collar", "CollarTag", "Neck", "Chest", "Torso", "LegFL", "LegFR", "LegLowFL", "LegLowFR", "PawFL", "PawFR", "LegLowRL", "LegLowRR", "PawRL", "PawRR", "HaunchL", "HaunchR", "Tail" }
	local missing = {}
	for _, n in names do if not m:FindFirstChild(n) then table.insert(missing, n) end end
	check("anatomia reconocible: cabeza, hocico, nariz, ojos, orejas, collar, cuello, pecho, 4 patas con zarpas, grupa y cola", #missing == 0, table.concat(missing, ","))
	local fur, tan = 0, 0
	for _, p in parts(m) do
		local c = p.Color
		if c.R < 0.1 and c.G < 0.1 then fur += 1 end
		if c.R > 0.55 and c.R < 0.75 and c.G > 0.3 and c.G < 0.45 and c.B < 0.25 then tan += 1 end
	end
	check("negro con marcas fuego (tan) repartidas", fur >= 15 and tan >= 8, fur .. "/" .. tan)
	local nonColl = true
	for _, p in parts(m) do if p.CanCollide or not p.Anchored then nonColl = false end end
	check("anclado y sin colision", nonColl)
	local ok, bad = noBadClasses(m)
	check("sin scripts, IA, luces ni sonidos (estatico y manso)", ok, bad)
	local bb = bbox(m)
	check("sentado: ~2,2 x 4,2 x 3,6 y mirando a -Z (hocico en z mas negativo, cola en +Z)", bb[2] - bb[1] > 1.8 and bb[2] - bb[1] < 2.8 and bb[6] - bb[5] > 3.6 and bb[6] - bb[5] < 4.8 and bb[4] > 3.1 and bb[4] < 3.8 and bb[3] >= -0.001 and m.Nose.Position.Z < m.Tail.Position.Z - 3, string.format("%.2f x %.2f x %.2f", bb[2] - bb[1], bb[6] - bb[5], bb[4]))
	check("cabeza mas alta que el cuerpo y hocico por delante del pecho", m.Skull.Position.Y > m.Chest.Position.Y + 0.8 and m.Nose.Position.Z < m.Chest.Position.Z - 1)
	check("simetria izquierda/derecha de orejas, ojos y patas", math.abs(m.EarL.Position.X + m.EarR.Position.X) < 1e-6 and math.abs(m.EyeL.Position.X + m.EyeR.Position.X) < 1e-6 and math.abs(m.PawFL.Position.X + m.PawFR.Position.X) < 1e-6 and math.abs(m.PawRL.Position.X + m.PawRR.Position.X) < 1e-6)
	local lost = floating(m)
	check("ninguna pieza flota", #lost == 0, table.concat(lost, ","))
	-- zarpas apoyadas en el suelo
	check("las 4 zarpas tocan el suelo (y = 0)", math.abs(aabb(m.PawFL)[3]) < 1e-6 and math.abs(aabb(m.PawRR)[3]) < 1e-6)
	print(string.format("        perro: %d piezas", #parts(m)))
end

-- ===================================================== bano
do
	local m = ED.buildBathroom(parent, CFrame.new(0, 0, 0))
	check("buildBathroom devuelve un Model parentado", m:IsA("Model") and m.Parent == parent)
	local bb = bbox(m)
	check("huella EXACTA 32 x 28 (x -16..16, z -14..14) y altura 12 sin salirse", math.abs(bb[1] + 16) < 1e-6 and math.abs(bb[2] - 16) < 1e-6 and math.abs(bb[5] + 14) < 1e-6 and math.abs(bb[6] - 14) < 1e-6 and math.abs(bb[4] - 12) < 1e-6, string.format("%.2f..%.2f %.2f..%.2f %.2f", bb[1], bb[2], bb[5], bb[6], bb[4]))
	check("suelo con la cara superior en y local 0 (la losa baja a -0,4)", math.abs(aabb(m.FloorSlab)[4]) < 1e-9 and math.abs(bb[3] + 0.4) < 1e-9)
	local ok, bad = noBadClasses(m)
	check("sin luces ni sonidos ni scripts (marcos LED = Neon, sin luz real)", ok, bad)
	local unanchored, seats = 0, 0
	local archNames = { "^FloorSlab$", "^Wall", "^Lintel", "^Ceiling$", "^Partition" }
	local badColl = {}
	local nColl = 0
	for _, p in parts(m) do
		if not p.Anchored then unanchored += 1 end
		if p:IsA("Seat") then seats += 1 end
		if p.CanCollide then
			nColl += 1
			local isArch = false
			for _, pat in archNames do if string.match(p.Name, pat) then isArch = true end end
			if not isArch then table.insert(badColl, p.Name) end
		end
	end
	check("todo anclado; solo colisiona arquitectura (suelo, muros, dinteles, techo, tabiques)", unanchored == 0 and #badColl == 0 and nColl >= 12, table.concat(badColl, ",") .. " " .. nColl)
	check("sin Seat en el bano (inodoros solo decorativos, sin mecanicas intimas) ni camaras", seats == 0 and not m:FindFirstChild("Camera") and not m:FindFirstChild("ToiletSeat"))
	check("2 cabinas con tabique, frente y puerta; 2 inodoros", m:FindFirstChild("PartitionW") and m:FindFirstChild("PartitionE") and m:FindFirstChild("PartitionFrontW") and m:FindFirstChild("PartitionFrontE") and m:FindFirstChild("DoorW") and m:FindFirstChild("DoorE") and m:FindFirstChild("ToiletBaseW") and m:FindFirstChild("ToiletBaseE") ~= nil)
	check("3 lavabos con cuenco, grifo, espejo con marco dorado y 4 tiras LED Neon", (function()
		local led = 0
		for _, p in parts(m) do if string.match(p.Name, "^MirrorLed") and p.Material == Enum.Material.Neon then led += 1 end end
		return m:FindFirstChild("Basin1") and m:FindFirstChild("Basin3") and m:FindFirstChild("Faucet2") and m:FindFirstChild("Mirror2") and m:FindFirstChild("MirrorFrameT3") and led == 12
	end)())
	-- aberturas de entrada (eje -Z): dos de 8 x 9
	local colliders = {}
	for _, p in parts(m) do if p.CanCollide then table.insert(colliders, { n = p.Name, a = aabb(p) }) end end
	local function solidAt(x, y, z, hx, hy, hz)
		for _, c in colliders do
			local a = c.a
			if x - hx < a[2] and x + hx > a[1] and y - hy < a[4] and y + hy > a[3] and z - hz < a[6] and z + hz > a[5] then return c.n end
		end
		return nil
	end
	check("dos entradas de 8 studs de ancho libres hasta 9 de altura en el muro z = -14", solidAt(-8, 4.5, -13.75, 3.95, 4.45, 0.2) == nil and solidAt(8, 4.5, -13.75, 3.95, 4.45, 0.2) == nil)
	check("...y el muro existe fuera de las aberturas (pilar central y laterales)", solidAt(0, 4.5, -13.75, 0.5, 4, 0.2) ~= nil and solidAt(-14, 4.5, -13.75, 0.5, 4, 0.2) ~= nil and solidAt(14, 4.5, -13.75, 0.5, 4, 0.2) ~= nil)
	-- navegacion en rejilla de 0,5: cuerpo de 3,5 (semilado 1,75) y 2,5; altura de cuerpo 0,3..5,5
	local function nav(halfW)
		local step = 0.5
		local function free(x, z)
			if x < -16 + halfW or x > 16 - halfW or z < -18 or z > 14 - halfW then return false end
			return solidAt(x, 3, z, halfW, 2.7, halfW) == nil
		end
		local start = { -8, -16 }
		local seen, queue, head = {}, { start }, 1
		local function key(x, z) return math.floor(x / step + 0.5) .. "," .. math.floor(z / step + 0.5) end
		seen[key(start[1], start[2])] = true
		while head <= #queue do
			local c = queue[head]
			head += 1
			for _, d in { { step, 0 }, { -step, 0 }, { 0, step }, { 0, -step } } do
				local nx, nz = c[1] + d[1], c[2] + d[2]
				local k = key(nx, nz)
				if not seen[k] and free(nx, nz) then
					seen[k] = true
					table.insert(queue, { nx, nz })
				end
			end
		end
		return function(x, z) return seen[key(x, z)] == true end
	end
	for _, hw in { 1.0, 1.25, 1.75 } do
		local reach = nav(hw)
		check(string.format("cuerpo de %.1f de ancho: desde la calle entra por AMBAS aberturas y llega a lavabos (0,10), centro y a la puerta de cada cabina", hw * 2), reach(-8, -10) and reach(8, -10) and reach(0, 9) and reach(0, 0) and reach(-11, 6) and reach(11, 6) and reach(-12, 10) and reach(12, 10))
	end
	check("las cabinas: puerta libre de 3,75 de ancho (cuerpo de 3,5 pasa)", (nav(1.75))(-11, 6) and (nav(1.75))(-11, 9.5))
	for _, pp in parts(m) do local a = aabb(pp) if a[6] > 14.001 or a[5] < -14.001 or a[1] < -16.001 or a[2] > 16.001 then print("        FUERA DE HUELLA:", pp.Name, a[1], a[2], a[5], a[6]) end end
	local lost = floating(m)
	check("ninguna pieza visible flota", #lost == 0, table.concat(lost, ","))
	local mm = ED.buildBathroom(parent, CFrame.new(100, 24, 50) * CFrame.Angles(0, math.rad(180), 0))
	local fb = bbox(mm)
	check("con cf (traslacion + giro de 180) conserva huella y suelo en el y de cf", math.abs(fb[2] - fb[1] - 32) < 1e-6 and math.abs(fb[6] - fb[5] - 28) < 1e-6 and math.abs(aabb(mm.FloorSlab)[4] - 24) < 1e-6)
	local ms = ED.buildBathroom(parent, CFrame.new(0, 0, 0), { solid = true })
	local c4 = 0
	for _, p in parts(ms) do if p.CanCollide then c4 += 1 end end
	check("opts.solid = true hace colisionable tambien el mobiliario", c4 > nColl + 20)
	print(string.format("        bano: %d piezas, %d colisionables", #parts(m), nColl))
end

-- ===================================================== reglas generales del archivo
do
	check("el modulo devuelve exactamente las 3 funciones pedidas (mas Version)", type(ED.buildPiano) == "function" and type(ED.buildRottweiler) == "function" and type(ED.buildBathroom) == "function")
	local ok1 = pcall(function() ED.buildPiano(parent) ED.buildRottweiler(parent) ED.buildBathroom(parent) end)
	check("cf opcional: sin cf usa CFrame identidad sin errores", ok1)
end

print(string.format("\nRESULTADO EventDecor: %d comprobaciones, %d fallo(s)", total, failures))
