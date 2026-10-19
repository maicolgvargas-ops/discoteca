--[[
	EVENTDECOR 1.0.0 - ModuleScript NUEVO y AUTOCONTENIDO para La Alfombra Roja (decoracion estatica).

	Devuelve tres funciones. Todas crean un Model con Parts NATIVAS ANCLADAS (sin assets externos, sin IDs, sin require, sin
	scripts, sin bucles en ejecucion, sin PointLight/SpotLight, sin sonidos) y lo parentan a `parent`:

	    local EventDecor = require(ruta.a.EventDecor)
	    local piano = EventDecor.buildPiano(workspace.LaAlfombraRoja.Floor3, CFrame.new(10, 48, -20) * CFrame.Angles(0, math.pi, 0))
	    local perro = EventDecor.buildRottweiler(parent, cf)
	    local banos = EventDecor.buildBathroom(parent, cf)

	`cf` = CFrame del ORIGEN LOCAL del modulo, que esta SIEMPRE en el SUELO (y local = 0). Un tercer argumento opcional
	`opts` admite { solid = true } para que tambien colisione el mobiliario (por defecto NO: solo arquitectura y suelo del
	bano colisionan) y { name = "..." } para renombrar el Model.

	SISTEMAS LOCALES (mira hacia -Z cuando cf no tiene rotacion):
	  * buildPiano:      el TECLADO esta en z = 0 y el cuerpo crece hacia +Z (cola en z ~ 7); x = -2.6..2.6; el banco (Seat nativo)
	                     esta delante, en z ~ -1.7, y mira hacia el teclado (+Z). Altura sin tapa ~ 3,5; con tapa abierta ~ 6,5.
	  * buildRottweiler: perro SENTADO que mira hacia -Z; ~ 2,2 de ancho x 4,3 de largo x 3,6 de alto. Decorativo, quieto,
	                     sin IA, sin ataques, sin scripts.
	  * buildBathroom:   huella 32 (x: -16..16) x 28 (z: -14..14), altura 12 (y: 0..12), suelo con la cara superior en y = 0
	                     (la losa baja hasta y = -0,4). ENTRADA hacia -Z: dos aberturas de 8 de ancho x 9 de alto en el muro
	                     z = -14. Dos cabinas privadas (puerta de 3,7 de ancho, abierta), tres lavabos con espejos y marco LED
	                     (Neon, sin luz real), sin camaras ni mecanicas intimas (los inodoros son solo decorativos, no Seat).

	COLISION: Piano y perro: nada colisiona (los dos son decoracion; el banco es un Seat nativo no colisionable). Bano: colisionan
	suelo, muros, dinteles, techo y tabiques de las cabinas; el resto (sanitarios, lavabos, espejos, molduras, puertas) no.

	NO se ha probado en Roblox Studio: solo en un simulador (geometria, solapes, colisiones, limites). Revisa huecos y
	proporciones a ojo al integrarlo.
]]

local EventDecor = {}
EventDecor.Version = "1.0.0"

------------------------------------------------------------------------
-- Paleta (negro / dorado / caoba)
------------------------------------------------------------------------
local COL = {
	mahogany = Color3.fromRGB(92, 36, 22),
	mahoganyDark = Color3.fromRGB(62, 24, 16),
	black = Color3.fromRGB(16, 15, 17),
	ebony = Color3.fromRGB(10, 10, 12),
	gold = Color3.fromRGB(214, 170, 86),
	goldDark = Color3.fromRGB(160, 120, 52),
	ivory = Color3.fromRGB(226, 221, 208),
	porcelain = Color3.fromRGB(230, 230, 226),
	silver = Color3.fromRGB(196, 198, 205),
	marble = Color3.fromRGB(26, 24, 28),
	wall = Color3.fromRGB(30, 27, 32),
	ledWarm = Color3.fromRGB(255, 226, 170),
	mirror = Color3.fromRGB(204, 216, 226),
	tan = Color3.fromRGB(168, 96, 44),
	fur = Color3.fromRGB(17, 15, 14),
	nose = Color3.fromRGB(8, 8, 9),
	eye = Color3.fromRGB(50, 28, 14),
	leather = Color3.fromRGB(34, 22, 16),
}
local M = Enum.Material

------------------------------------------------------------------------
-- Constructor comun: todo local a `base`, anclado, sin colision salvo que se pida
------------------------------------------------------------------------
local function newBuilder(model, base, solid)
	local b = { model = model, base = base, solid = solid, count = 0 }

	-- pieza generica. props.collide = true la hace colisionable (solo arquitectura); props.shadow = true proyecta sombra
	function b.part(name, lcf, size, color, material, props)
		props = props or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = base * lcf
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local collide = props.collide == true or (props.furniture == true and solid == true)
		p.CanCollide = collide
		p.CanTouch = false
		p.CanQuery = collide
		p.CastShadow = props.shadow == true or props.collide == true -- solo la arquitectura proyecta sombra (coste bajo)
		if props.reflectance then
			p.Reflectance = props.reflectance
		end
		if props.transparency then
			p.Transparency = props.transparency
		end
		if props.shape then
			p.Shape = props.shape
		end
		p.Parent = model
		b.count += 1
		return p
	end

	-- caja por esquinas locales (x1,y1,z1)-(x2,y2,z2)
	function b.box(name, x1, y1, z1, x2, y2, z2, color, material, props)
		return b.part(name, CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1)), color, material, props)
	end

	-- esfera de diametro d
	function b.ball(name, pos, d, color, material, props)
		props = props or {}
		props.shape = Enum.PartType.Ball
		return b.part(name, CFrame.new(pos), Vector3.new(d, d, d), color, material, props)
	end

	-- cilindro VERTICAL (eje Y): centro (x, y, z), altura h, diametro d
	function b.vcyl(name, x, y, z, h, d, color, material, props)
		props = props or {}
		props.shape = Enum.PartType.Cylinder
		return b.part(name, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(h, d, d), color, material, props)
	end

	-- cilindro entre dos puntos locales a -> b, diametro d
	function b.limb(name, a, c, d, color, material, props)
		props = props or {}
		props.shape = Enum.PartType.Cylinder
		local len = (c - a).Magnitude
		return b.part(name, CFrame.lookAt((a + c) / 2, c) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(len, d, d), color, material, props)
	end

	-- barra fina entre dos puntos (caja) con grosor t
	function b.bar(name, a, c, t, color, material, props)
		local len = (c - a).Magnitude
		return b.part(name, CFrame.lookAt((a + c) / 2, c), Vector3.new(t, t, len), color, material, props)
	end
	return b
end

local function finish(model, parent, primary)
	if primary then
		model.PrimaryPart = primary
	end
	model.Parent = parent
	return model
end

local function interp(points, z)
	-- interpolacion lineal de una lista { {z, x}, ... } ordenada por z
	if z <= points[1][1] then
		return points[1][2]
	end
	for i = 2, #points do
		if z <= points[i][1] then
			local a, c = points[i - 1], points[i]
			local t = (z - a[1]) / (c[1] - a[1])
			return a[2] + (c[2] - a[2]) * t
		end
	end
	return points[#points][2]
end

------------------------------------------------------------------------
-- PIANO DE COLA (caoba brillante, tapa inclinada, 88 teclas, patas, pedales, banco con Seat)
------------------------------------------------------------------------
function EventDecor.buildPiano(parent, cf, opts)
	opts = opts or {}
	cf = cf or CFrame.new(0, 0, 0)
	local model = Instance.new("Model")
	model.Name = opts.name or "GrandPiano"
	local b = newBuilder(model, cf, opts.solid)
	local F = { furniture = true }
	local GLOSS = { furniture = true, reflectance = 0.22 }
	local W = M.Wood

	-- contorno: borde izquierdo recto (x = -2.62) y borde derecho curvo hacia la cola
	local RIGHT = { { 1.35, 2.62 }, { 3.9, 2.55 }, { 5.6, 1.9 }, { 6.8, 0.5 }, { 7.1, -1.3 } }
	local LEFT = { { 1.35, -2.62 }, { 6.4, -2.62 }, { 7.1, -1.3 } }
	local function R(z) return interp(RIGHT, z) end
	local function L(z) return interp(LEFT, z) end

	-- teclado: 52 blancas + 36 negras (88 teclas); la primera blanca es La0
	local x0, kw = -2.45, 4.9 / 52
	for i = 0, 51 do
		b.box("KeyW" .. (i + 1), x0 + i * kw + 0.004, 2.05, 0, x0 + (i + 1) * kw - 0.004, 2.27, 0.95, COL.ivory, M.SmoothPlastic, F)
	end
	-- notas con tecla negra a su derecha: La, Do, Re, Fa, Sol (indice 0 = La)
	local hasBlack = { [0] = true, [2] = true, [3] = true, [5] = true, [6] = true }
	local nb = 0
	for i = 0, 50 do
		if hasBlack[i % 7] then
			nb += 1
			local cx = x0 + (i + 1) * kw
			b.box("KeyB" .. nb, cx - kw * 0.3, 2.26, 0.36, cx + kw * 0.3, 2.45, 0.95, COL.ebony, M.SmoothPlastic, F)
		end
	end
	-- lecho, listón frontal, mejillas y tabla del nombre
	b.box("KeyBed", -2.45, 1.85, 0, 2.45, 2.05, 1.35, COL.ebony, M.SmoothPlastic, F)
	b.box("KeySlip", -2.45, 1.9, -0.16, 2.45, 2.27, 0, COL.black, M.SmoothPlastic, { furniture = true, reflectance = 0.2 })
	b.box("CheekL", -2.62, 1.6, -0.16, -2.45, 2.75, 1.35, COL.mahogany, W, GLOSS)
	b.box("CheekR", 2.45, 1.6, -0.16, 2.62, 2.75, 1.35, COL.mahogany, W, GLOSS)
	b.box("Nameboard", -2.45, 2.27, 0.95, 2.45, 2.85, 1.35, COL.mahogany, W, GLOSS)
	b.box("NameboardGold", -2.2, 2.52, 0.89, 2.2, 2.58, 0.95, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })
	b.box("NameboardPlate", -0.35, 2.4, 0.89, 0.35, 2.7, 0.95, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })

	-- caja: paredes del contorno
	local poly = { { -2.62, 1.35 }, { -2.62, 6.4 }, { -1.3, 7.1 }, { 0.5, 6.8 }, { 1.9, 5.6 }, { 2.55, 3.9 }, { 2.62, 1.35 } }
	for i = 1, #poly - 1 do
		local p, q = poly[i], poly[i + 1]
		local a, c = Vector3.new(p[1], 2.15, p[2]), Vector3.new(q[1], 2.15, q[2])
		local seg = b.bar("CaseWall" .. i, a, c, 1, COL.mahogany, W, GLOSS)
		seg.Size = Vector3.new(0.22, 1.2, (c - a).Magnitude + 0.22)
	end
	-- fondo, arpa dorada (plancha) y cuerdas
	for slice = 1, 8 do
		local z = 1.35 + (slice - 1) * 0.7
		local zc = math.min(z + 0.35, 6.95)
		local xl, xr = L(zc), R(zc)
		b.box("CaseBottom" .. slice, xl, 1.5, z, xr, 1.65, math.min(z + 0.72, 7.0), COL.mahoganyDark, W, F)
		local inset = 0.3
		if xr - xl > 2 * inset + 0.2 then
			b.box("HarpPlate" .. slice, xl + inset, 2.5, z, xr - inset, 2.58, math.min(z + 0.72, 7.0), COL.goldDark, M.Metal, { furniture = true, reflectance = 0.3 })
		end
	end
	for i = 0, 13 do
		local x = -2.05 + i * 0.28
		local zEnd = 6.2 - i * 0.22
		b.box("String" .. (i + 1), x - 0.03, 2.58, 1.7, x + 0.03, 2.64, zEnd, COL.silver, M.Metal, F)
	end

	-- tapa inclinada: bisagra en el borde recto izquierdo, abierta 36 grados, apoyada en un puntal
	local theta = math.rad(36)
	local yHinge = 2.78
	local lidZ = 1.45
	for k = 0, 7 do
		local zc = lidZ + k * 0.7
		if zc <= 6.9 then
			local xl = L(zc)
			local w = R(zc) - xl + 0.1
			b.part("LidSlab" .. (k + 1), CFrame.new(xl, yHinge, zc) * CFrame.Angles(0, 0, theta) * CFrame.new(w / 2, 0.07, 0), Vector3.new(w, 0.14, 0.72), COL.mahogany, W, GLOSS)
		end
	end
	b.box("HingeGold", -2.66, 2.74, 1.5, -2.58, 2.82, 6.4, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })
	-- puntal vertical de la tapa (de la plancha a la cara inferior de la tapa)
	local propX = -2.62 + 3.4
	local propTop = yHinge + (propX - -2.62) * math.tan(theta)
	b.vcyl("LidProp", propX, (2.58 + propTop) / 2, 3.2, propTop - 2.58, 0.13, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })

	-- atril inclinado hacia atras
	b.box("DeskLedge", -1.6, 2.85, 1.3, 1.6, 2.95, 1.5, COL.mahogany, W, GLOSS)
	b.part("MusicDesk", CFrame.new(0, 3.42, 1.67) * CFrame.Angles(math.rad(-70), 0, 0), Vector3.new(3.2, 0.06, 1.0), COL.mahogany, W, GLOSS)
	b.box("DeskRail", -1.6, 2.95, 1.42, 1.6, 3.05, 1.5, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })

	-- patas (3): cilindro superior, cono inferior y dedal dorado
	for i, p in { { -2.15, 0.95 }, { 2.15, 0.95 }, { 0.2, 6.0 } } do
		b.vcyl("LegTop" .. i, p[1], 1.25, p[2], 0.5, 0.58, COL.mahogany, W, GLOSS)
		b.vcyl("LegMid" .. i, p[1], 0.65, p[2], 0.7, 0.42, COL.mahogany, W, GLOSS)
		b.vcyl("LegCup" .. i, p[1], 0.15, p[2], 0.3, 0.5, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })
	end

	-- lira de pedales: dos columnas, tablero y tres pedales dorados
	b.box("LyreColumnL", -0.95, 0, 0.45, -0.7, 1.7, 0.75, COL.mahogany, W, GLOSS)
	b.box("LyreColumnR", 0.7, 0, 0.45, 0.95, 1.7, 0.75, COL.mahogany, W, GLOSS)
	b.box("LyreBoard", -0.95, 0.8, 0.2, 0.95, 0.95, 0.95, COL.mahoganyDark, W, GLOSS)
	for i, x in { -0.4, 0, 0.4 } do
		b.box("Pedal" .. i, x - 0.14, 0.12, -0.1, x + 0.14, 0.2, 0.75, COL.gold, M.Metal, { furniture = true, reflectance = 0.5 })
		b.vcyl("PedalRod" .. i, x, 0.55, 0.45, 0.7, 0.07, COL.gold, M.Metal, { furniture = true })
	end

	-- banco: marco de caoba, patas, cojin negro y Seat nativo mirando al teclado (+Z local)
	local bz = -1.7
	b.box("BenchFrame", -1.3, 1.45, bz - 0.55, 1.3, 1.7, bz + 0.55, COL.mahogany, W, GLOSS)
	b.box("BenchCushion", -1.25, 1.7, bz - 0.5, 1.25, 2.0, bz + 0.5, COL.black, M.Fabric, F)
	b.box("BenchPiping", -1.27, 1.66, bz - 0.52, 1.27, 1.72, bz + 0.52, COL.gold, M.Metal, { furniture = true, reflectance = 0.4 })
	for i, c in { { -1.1, bz - 0.4 }, { 1.1, bz - 0.4 }, { -1.1, bz + 0.4 }, { 1.1, bz + 0.4 } } do
		b.vcyl("BenchLeg" .. i, c[1], 0.725, c[2], 1.45, 0.24, COL.mahogany, W, GLOSS)
		b.vcyl("BenchFoot" .. i, c[1], 0.07, c[2], 0.14, 0.3, COL.gold, M.Metal, { furniture = true })
	end
	local seat = Instance.new("Seat")
	seat.Name = "PianoBenchSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(2.4, 0.2, 1.0)
	seat.CFrame = cf * CFrame.new(0, 2.05, bz) * CFrame.Angles(0, math.pi, 0) -- su frente (-Z) apunta al teclado (+Z)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.CastShadow = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = model

	model:SetAttribute("EventDecor", "GrandPiano")
	return finish(model, parent, model:FindFirstChild("KeyBed"))
end

------------------------------------------------------------------------
-- ROTTWEILER (estatico, sentado, manso; negro con marcas fuego). Mira hacia -Z.
------------------------------------------------------------------------
function EventDecor.buildRottweiler(parent, cf, opts)
	opts = opts or {}
	cf = cf or CFrame.new(0, 0, 0)
	local model = Instance.new("Model")
	model.Name = opts.name or "Rottweiler"
	local b = newBuilder(model, cf, opts.solid)
	local F = { furniture = true }
	local SP = M.SmoothPlastic
	local V = Vector3.new

	-- grupa y cuerpo
	b.ball("RumpBall", V(0, 0.85, 0.95), 1.4, COL.fur, SP, F)
	b.ball("HaunchL", V(-0.72, 0.72, 0.78), 1.35, COL.fur, SP, F)
	b.ball("HaunchR", V(0.72, 0.72, 0.78), 1.35, COL.fur, SP, F)
	b.limb("Torso", V(0, 1.1, 0.85), V(0, 1.95, -0.5), 1.25, COL.fur, SP, F)
	b.ball("Chest", V(0, 1.85, -0.5), 1.5, COL.fur, SP, F)
	b.ball("ChestTanL", V(-0.28, 1.75, -1.15), 0.34, COL.tan, SP, F)
	b.ball("ChestTanR", V(0.28, 1.75, -1.15), 0.34, COL.tan, SP, F)
	-- cuello y cabeza
	b.limb("Neck", V(0, 2.05, -0.6), V(0, 2.85, -1.0), 0.95, COL.fur, SP, F)
	b.ball("Skull", V(0, 3.0, -1.15), 1.05, COL.fur, SP, F)
	b.box("Muzzle", -0.31, 2.62, -2.3, 0.31, 3.12, -1.4, COL.fur, SP, F)
	b.box("Jaw", -0.25, 2.5, -2.15, 0.25, 2.64, -1.45, COL.fur, SP, F)
	b.box("CheekTanL", -0.37, 2.62, -2.1, -0.31, 2.92, -1.55, COL.tan, SP, F)
	b.box("CheekTanR", 0.31, 2.62, -2.1, 0.37, 2.92, -1.55, COL.tan, SP, F)
	b.ball("Nose", V(0, 2.98, -2.3), 0.3, COL.nose, SP, { furniture = true })
	b.ball("EyeL", V(-0.28, 3.08, -1.6), 0.13, COL.eye, SP, F)
	b.ball("EyeR", V(0.28, 3.08, -1.6), 0.13, COL.eye, SP, F)
	b.ball("BrowTanL", V(-0.27, 3.23, -1.58), 0.15, COL.tan, SP, F)
	b.ball("BrowTanR", V(0.27, 3.23, -1.58), 0.15, COL.tan, SP, F)
	-- orejas caidas (planas, colgando a los lados del craneo)
	b.part("EarL", CFrame.new(-0.56, 3.12, -1.0) * CFrame.Angles(0, 0, math.rad(22)), V(0.1, 0.58, 0.5), COL.fur, SP, F)
	b.part("EarR", CFrame.new(0.56, 3.12, -1.0) * CFrame.Angles(0, 0, math.rad(-22)), V(0.1, 0.58, 0.5), COL.fur, SP, F)
	-- collar: banda de cuero con hebilla y chapa dorada
	local nDir = (V(0, 2.85, -1.0) - V(0, 2.05, -0.6)).Unit
	local nPos = V(0, 2.05, -0.6) + (V(0, 2.85, -1.0) - V(0, 2.05, -0.6)) * 0.45
	b.limb("Collar", nPos - nDir * 0.11, nPos + nDir * 0.11, 1.02, COL.leather, SP, F)
	b.box("CollarBuckle", -0.1, nPos.Y - 0.2, nPos.Z - 0.55, 0.1, nPos.Y + 0.2, nPos.Z - 0.44, COL.gold, M.Metal, { furniture = true, reflectance = 0.4 })
	b.ball("CollarTag", V(0, nPos.Y - 0.42, nPos.Z - 0.58), 0.22, COL.gold, M.Metal, { furniture = true, reflectance = 0.4 })
	-- patas delanteras (negro arriba, fuego abajo) y patas traseras plegadas
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local x = s[2] * 0.42
		b.limb("LegF" .. s[1], V(x, 1.6, -0.55), V(x, 0.95, -0.78), 0.46, COL.fur, SP, F)
		b.limb("LegLowF" .. s[1], V(x, 0.95, -0.78), V(x, 0.22, -0.98), 0.36, COL.tan, SP, F)
		b.box("PawF" .. s[1], x - 0.23, 0, -1.5, x + 0.23, 0.22, -0.8, COL.fur, SP, F)
		local hx = s[2] * 0.72
		b.limb("LegLowR" .. s[1], V(hx, 0.45, 0.45), V(hx * 0.97, 0.2, -0.2), 0.4, COL.tan, SP, F)
		b.box("PawR" .. s[1], hx - 0.23, 0, -0.75, hx + 0.23, 0.22, -0.05, COL.fur, SP, F)
		b.ball("HockTan" .. s[1], V(hx, 0.5, 0.35), 0.36, COL.tan, SP, F)
	end
	-- cola corta (rabo cortado, sin gesto agresivo)
	b.limb("Tail", V(0, 0.7, 1.5), V(0, 0.8, 1.85), 0.24, COL.fur, SP, F)

	model:SetAttribute("EventDecor", "StaticRottweiler")
	return finish(model, parent, model:FindFirstChild("Torso"))
end

------------------------------------------------------------------------
-- BANOS (32 x 28 x 12): entrada hacia -Z, dos cabinas privadas, tres lavabos con espejos y marco LED
------------------------------------------------------------------------
function EventDecor.buildBathroom(parent, cf, opts)
	opts = opts or {}
	cf = cf or CFrame.new(0, 0, 0)
	local model = Instance.new("Model")
	model.Name = opts.name or "Bathroom"
	local b = newBuilder(model, cf, opts.solid)
	local DEC = { furniture = true }
	local GOLD = { furniture = true, reflectance = 0.45 }
	local X1, X2, Z1, Z2, H = -16, 16, -14, 14, 12
	local T = 0.5 -- grosor de los muros (siempre DENTRO de la huella 32 x 28)

	-- suelo (cara superior en y = 0) con borde dorado
	local floor = b.box("FloorSlab", X1, -0.4, Z1, X2, 0, Z2, COL.marble, M.Marble, { collide = true, reflectance = 0.25 })
	b.box("FloorGoldN", X1 + 0.8, 0, Z1 + 0.8, X2 - 0.8, 0.05, Z1 + 1.0, COL.gold, M.Metal, GOLD)
	b.box("FloorGoldS", X1 + 0.8, 0, Z2 - 1.0, X2 - 0.8, 0.05, Z2 - 0.8, COL.gold, M.Metal, GOLD)
	b.box("FloorGoldW", X1 + 0.8, 0, Z1 + 1.0, X1 + 1.0, 0.05, Z2 - 1.0, COL.gold, M.Metal, GOLD)
	b.box("FloorGoldE", X2 - 1.0, 0, Z1 + 1.0, X2 - 0.8, 0.05, Z2 - 1.0, COL.gold, M.Metal, GOLD)
	b.box("FloorGoldMid", -0.1, 0, Z1 + 1.0, 0.1, 0.05, Z2 - 1.0, COL.gold, M.Metal, GOLD)

	-- muros y techo (arquitectura colisionable)
	b.box("WallW", X1, 0, Z1, X1 + T, H, Z2, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	b.box("WallE", X2 - T, 0, Z1, X2, H, Z2, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	b.box("WallBack", X1 + T, 0, Z2 - T, X2 - T, H, Z2, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	-- muro de entrada con DOS aberturas de 8 x 9 (x: -12..-4 y 4..12)
	b.box("WallFrontL", X1 + T, 0, Z1, -12, H, Z1 + T, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	b.box("WallFrontMid", -4, 0, Z1, 4, H, Z1 + T, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	b.box("WallFrontR", 12, 0, Z1, X2 - T, H, Z1 + T, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
	for i, c in { -8, 8 } do
		-- dintel: queda un rebaje de 0,06 en la cara exterior donde se asienta el cartel
		b.box("Lintel" .. i, c - 4, 9, Z1 + 0.06, c + 4, H, Z1 + T, COL.wall, M.Marble, { collide = true, reflectance = 0.12 })
		local plate = b.box("SignPlate" .. i, c - 2.2, 9.5, Z1, c + 2.2, 11.1, Z1 + 0.06, COL.black, M.SmoothPlastic, DEC)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = plate
		local tl = Instance.new("TextLabel")
		tl.Name = "Text"
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(1, 1)
		tl.Text = "BAÑOS"
		tl.TextScaled = true
		tl.Font = Enum.Font.Bodoni
		tl.TextColor3 = COL.gold
		tl.Parent = gui
		b.box("SignFrame" .. i .. "T", c - 2.35, 11.1, Z1, c + 2.35, 11.2, Z1 + 0.08, COL.gold, M.Metal, GOLD)
		b.box("SignFrame" .. i .. "B", c - 2.35, 9.4, Z1, c + 2.35, 9.5, Z1 + 0.08, COL.gold, M.Metal, GOLD)
		b.box("SignFrame" .. i .. "L", c - 2.35, 9.5, Z1, c - 2.2, 11.1, Z1 + 0.08, COL.gold, M.Metal, GOLD)
		b.box("SignFrame" .. i .. "R", c + 2.2, 9.5, Z1, c + 2.35, 11.1, Z1 + 0.08, COL.gold, M.Metal, GOLD)
		-- umbral dorado en cada entrada
		b.box("Threshold" .. i, c - 4, 0, Z1, c + 4, 0.05, Z1 + T, COL.gold, M.Metal, GOLD)
	end
	b.box("Ceiling", X1 + T, H - 0.4, Z1 + T, X2 - T, H, Z2 - T, COL.black, M.Marble, { collide = true, reflectance = 0.15 })

	-- molduras: zocalo y cornisa doradas, tiras de techo Neon (sin luz real)
	b.box("BaseN", X1 + T, 0, Z1 + T, X2 - T, 0.35, Z1 + T + 0.12, COL.gold, M.Metal, GOLD)
	b.box("BaseS", X1 + T, 0, Z2 - T - 0.12, X2 - T, 0.35, Z2 - T, COL.gold, M.Metal, GOLD)
	b.box("BaseW", X1 + T, 0, Z1 + T + 0.12, X1 + T + 0.12, 0.35, Z2 - T - 0.12, COL.gold, M.Metal, GOLD)
	b.box("BaseE", X2 - T - 0.12, 0, Z1 + T + 0.12, X2 - T, 0.35, Z2 - T - 0.12, COL.gold, M.Metal, GOLD)
	b.box("CorniceS", X1 + T, 8.95, Z2 - T - 0.1, X2 - T, 9.1, Z2 - T, COL.gold, M.Metal, GOLD)
	b.box("CorniceW", X1 + T, 8.95, Z1 + T, X1 + T + 0.1, 9.1, Z2 - T - 0.1, COL.gold, M.Metal, GOLD)
	b.box("CorniceE", X2 - T - 0.1, 8.95, Z1 + T, X2 - T, 9.1, Z2 - T - 0.1, COL.gold, M.Metal, GOLD)
	for i, z in { -6, 0, 6 } do
		b.box("CeilingLed" .. i, -10, H - 0.5, z - 0.15, 10, H - 0.4, z + 0.15, COL.ledWarm, M.Neon, DEC)
	end

	-- cabinas privadas: tabiques colisionables (0,6..8,4), puerta abierta pegada al tabique lateral
	local PT = 0.3
	for _, s in { { "W", -1 }, { "E", 1 } } do
		local sg = s[2]
		local xw = sg * 15.5 -- cara interior del muro lateral
		local xp = sg * 9.0 -- tabique lateral
		local function xr(a, c) return math.min(a, c), math.max(a, c) end
		-- tabique lateral
		local lo, hi = xr(xp - PT / 2, xp + PT / 2)
		b.box("Partition" .. s[1], lo, 0.6, 7.0, hi, 8.4, Z2 - T, COL.black, M.SmoothPlastic, { collide = true, reflectance = 0.2 })
		-- frente: solo un tramo junto al muro (la puerta es la abertura de 3,75 hasta el tabique)
		local fa, fb = xr(xw, sg * 12.9)
		b.box("PartitionFront" .. s[1], fa, 0.6, 6.85, fb, 8.4, 7.15, COL.black, M.SmoothPlastic, { collide = true, reflectance = 0.2 })
		-- puerta ABIERTA (decorativa, sin colision) pegada al tabique por dentro
		local dx = sg * 9.22
		local da, db = xr(dx - 0.06, dx + 0.06)
		b.box("Door" .. s[1], da, 0.5, 7.25, db, 7.9, 10.75, COL.mahoganyDark, M.Wood, { furniture = true, reflectance = 0.2 })
		b.box("DoorGold" .. s[1], da, 3.9, 7.25, db, 4.0, 10.75, COL.gold, M.Metal, GOLD)
		-- inodoro decorativo (NO es Seat) junto al muro del fondo
		local tx = sg * 12.2
		b.vcyl("ToiletBase" .. s[1], tx, 0.4, 12.1, 0.8, 1.4, COL.porcelain, M.SmoothPlastic, { furniture = true, reflectance = 0.15 })
		b.vcyl("ToiletRim" .. s[1], tx, 0.86, 12.1, 0.12, 1.6, COL.porcelain, M.SmoothPlastic, { furniture = true, reflectance = 0.15 })
		b.box("ToiletTank" .. s[1], tx - 0.85, 0.7, Z2 - T - 0.65, tx + 0.85, 2.2, Z2 - T, COL.porcelain, M.SmoothPlastic, { furniture = true, reflectance = 0.15 })
		b.box("ToiletButton" .. s[1], tx - 0.15, 2.2, Z2 - T - 0.4, tx + 0.15, 2.28, Z2 - T - 0.25, COL.gold, M.Metal, GOLD)
		-- portarrollos y percha dorados sobre el tabique
		local pa, pb = xr(xp + sg * 0.15, xp + sg * 0.55)
		b.box("PaperHolder" .. s[1], pa, 2.6, 11.3, pb, 3.1, 12.1, COL.gold, M.Metal, GOLD)
	end

	-- lavabos: encimera con cuerpo negro, 3 cuencos de porcelana y grifos dorados
	b.box("VanityBody", -8, 0, 12.2, 8, 3.2, Z2 - T, COL.black, M.SmoothPlastic, { furniture = true, reflectance = 0.25 })
	b.box("VanityTop", -8.2, 3.2, 12.1, 8.2, 3.5, Z2 - T, COL.marble, M.Marble, { furniture = true, reflectance = 0.3 })
	b.box("VanityGoldEdge", -8.2, 3.5, 12.1, 8.2, 3.58, 12.18, COL.gold, M.Metal, GOLD)
	for i, x in { -5, 0, 5 } do
		b.vcyl("Basin" .. i, x, 3.62, 12.5, 0.24, 2.0, COL.porcelain, M.SmoothPlastic, { furniture = true, reflectance = 0.2 })
		b.vcyl("Faucet" .. i, x, 4.05, 13.15, 0.9, 0.14, COL.gold, M.Metal, GOLD)
		b.box("FaucetSpout" .. i, x - 0.06, 4.45, 12.65, x + 0.06, 4.55, 13.2, COL.gold, M.Metal, GOLD)
		b.box("VanityHandle" .. i, x - 0.6, 1.6, 12.1, x + 0.6, 1.7, 12.2, COL.gold, M.Metal, GOLD)
		-- espejo con marco dorado y tira LED (Neon) interior
		local mx1, mx2, my1, my2, mz = x - 2.2, x + 2.2, 4.6, 8.6, Z2 - T
		b.box("Mirror" .. i, mx1, my1, mz - 0.1, mx2, my2, mz, COL.mirror, M.SmoothPlastic, { furniture = true, reflectance = 0.9 })
		b.box("MirrorFrameT" .. i, mx1 - 0.2, my2, mz - 0.18, mx2 + 0.2, my2 + 0.2, mz, COL.gold, M.Metal, GOLD)
		b.box("MirrorFrameB" .. i, mx1 - 0.2, my1 - 0.2, mz - 0.18, mx2 + 0.2, my1, mz, COL.gold, M.Metal, GOLD)
		b.box("MirrorFrameL" .. i, mx1 - 0.2, my1, mz - 0.18, mx1, my2, mz, COL.gold, M.Metal, GOLD)
		b.box("MirrorFrameR" .. i, mx2, my1, mz - 0.18, mx2 + 0.2, my2, mz, COL.gold, M.Metal, GOLD)
		b.box("MirrorLedT" .. i, mx1, my2 - 0.1, mz - 0.16, mx2, my2, mz - 0.1, COL.ledWarm, M.Neon, DEC)
		b.box("MirrorLedB" .. i, mx1, my1, mz - 0.16, mx2, my1 + 0.1, mz - 0.1, COL.ledWarm, M.Neon, DEC)
		b.box("MirrorLedL" .. i, mx1, my1 + 0.1, mz - 0.16, mx1 + 0.1, my2 - 0.1, mz - 0.1, COL.ledWarm, M.Neon, DEC)
		b.box("MirrorLedR" .. i, mx2 - 0.1, my1 + 0.1, mz - 0.16, mx2, my2 - 0.1, mz - 0.1, COL.ledWarm, M.Neon, DEC)
	end

	model:SetAttribute("EventDecor", "Bathroom")
	model:SetAttribute("Footprint", "32x28")
	model:SetAttribute("Height", H)
	return finish(model, parent, floor)
end

return EventDecor
