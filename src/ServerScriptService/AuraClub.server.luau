--[[
	AURA CLUB - discoteca de 3 pisos generada 100% por codigo (Luau).

	Piso 1: hall + pista LED + escenario DJ + barra + booths + lasers
	Piso 2: VIP lounge de cristal con barra, sofas y balcon sobre la pista
	Piso 3: rooftop con DJ, barra, piscina, fire pits y loungers

	Coordenadas: edificio de 100x100 studs centrado en (0,0,0).
	Suelo de cada piso (parte superior): Y = 0 / 24 / 48. Entrada por el sur (+Z).
	Escaleras: P1->P2 al este, P2->P3 al oeste.

	Ponlo en ServerScriptService y dale a Play.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local CONFIG = {
	Name = "AuraClub",
	-- Pega aqui un audio que tengas permiso de usar, ej: "rbxassetid://1234567890"
	MusicId = "",
	MusicVolume = 2,
	-- Borra el Baseplate y el SpawnLocation de la plantilla (tapan/duplican el suelo del club)
	RemoveTemplateObjects = true,
	TileCount = 12, -- pista LED de TileCount x TileCount baldosas
}

local FLOOR_Y = { 0, 24, 48 }
local FLOOR_H = 22 -- altura libre entre piso y techo (losa de 2 studs)
local BEAM_LEN = 43
local BEAM_PITCH = math.rad(-68)

local C = {
	black = Color3.fromRGB(10, 8, 18),
	dark = Color3.fromRGB(24, 19, 40),
	wall = Color3.fromRGB(32, 25, 52),
	floor = Color3.fromRGB(18, 13, 30),
	deck = Color3.fromRGB(46, 38, 50),
	purple = Color3.fromRGB(150, 60, 255),
	magenta = Color3.fromRGB(255, 40, 170),
	cyan = Color3.fromRGB(0, 230, 255),
	blue = Color3.fromRGB(70, 100, 255),
	white = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(255, 190, 80),
	velvet = Color3.fromRGB(95, 15, 70),
	glass = Color3.fromRGB(150, 200, 255),
	wood = Color3.fromRGB(70, 45, 35),
	green = Color3.fromRGB(30, 120, 60),
	fire = Color3.fromRGB(255, 140, 40),
}
local M = Enum.Material
local DECOR = { CanCollide = false, CastShadow = false }
local BOTTLES = { C.magenta, C.cyan, C.gold, C.purple, C.green, C.blue }

------------------------------------------------------------------------
-- Limpieza de ejecuciones anteriores
------------------------------------------------------------------------
local old = Workspace:FindFirstChild(CONFIG.Name)
if old then
	old:Destroy()
end
if CONFIG.RemoveTemplateObjects then
	for _, n in { "Baseplate", "SpawnLocation" } do
		local o = Workspace:FindFirstChild(n)
		if o and o:IsA("BasePart") then
			o:Destroy()
		end
	end
end

local club = Instance.new("Model")
club.Name = CONFIG.Name

local folders = {}
for _, n in { "Exterior", "Floor1", "Floor2", "Floor3", "Stairs", "Effects" } do
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = club
	folders[n] = f
end

-- registros para las animaciones
local fx = {
	tiles = {}, -- baldosas de la pista
	glows = {}, -- neones que ciclan de color (y sus luces)
	signs = {}, -- carteles que ciclan de color
	beams = {}, -- lasers
	strobes = {}, -- estrobos
	screens = {}, -- pantalla LED del DJ
	mirror = {}, -- facetas de la bola de espejos
}
local lightCount = 0

------------------------------------------------------------------------
-- Helpers de construccion
------------------------------------------------------------------------
local function P(parent, name, cf, size, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- caja por limites (x1,y1,z1) -> (x2,y2,z2)
local function B(parent, name, x1, y1, z1, x2, y2, z2, color, material, extra)
	return P(
		parent,
		name,
		CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
		Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1)),
		color,
		material,
		extra
	)
end

local function withShape(shape, extra)
	local e = { Shape = shape }
	if extra then
		for k, v in extra do
			e[k] = v
		end
	end
	return e
end

-- cilindro vertical (eje Y)
local function cyl(parent, name, x, y, z, height, diameter, color, material, extra)
	return P(
		parent,
		name,
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		color,
		material,
		withShape(Enum.PartType.Cylinder, extra)
	)
end

-- cilindro con eje Z (mirando al norte/sur)
local function cylZ(parent, name, x, y, z, length, diameter, color, material, extra)
	return P(
		parent,
		name,
		CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(length, diameter, diameter),
		color,
		material,
		withShape(Enum.PartType.Cylinder, extra)
	)
end

local function ball(parent, name, x, y, z, diameter, color, material, extra)
	return P(
		parent,
		name,
		CFrame.new(x, y, z),
		Vector3.new(diameter, diameter, diameter),
		color,
		material,
		withShape(Enum.PartType.Ball, extra)
	)
end

local function addLight(part, color, range, spot, brightness)
	local l
	if spot then
		l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Angle = 70
	else
		l = Instance.new("PointLight")
	end
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = part
	lightCount += 1
	return l
end

-- neon (decorativo, sin colision). opts: cycle, phase, light, spot, brightness
local function glow(parent, name, x1, y1, z1, x2, y2, z2, color, opts)
	local p = B(parent, name, x1, y1, z1, x2, y2, z2, color, M.Neon, DECOR)
	if opts then
		local light
		if opts.light then
			light = addLight(p, color, opts.light, opts.spot, opts.brightness)
		end
		if opts.cycle then
			table.insert(fx.glows, { part = p, light = light, phase = opts.phase or 0 })
		end
	end
	return p
end

local function cycleColor(t, phase)
	local a = 0.5 + 0.5 * math.sin(t * 0.6 + phase)
	return Color3.fromHSV(0.5 + 0.4 * a, 0.85, 1)
end

-- cartel con SurfaceGui. (dx,dz) = hacia donde mira el cartel
local function sign(parent, name, cx, cy, cz, w, h, dx, dz, text, color, cycle)
	local pos = Vector3.new(cx, cy, cz)
	local p = P(
		parent,
		name,
		CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)),
		Vector3.new(w, h, 0.5),
		C.black,
		M.SmoothPlastic,
		DECOR
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = p
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Text = text
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.TextColor3 = color
	tl.Parent = gui
	if cycle then
		table.insert(fx.signs, { label = tl, phase = #fx.signs * 0.7 })
	end
	return p, tl
end

-- losa rectangular con huecos. holes = { {x1,z1,x2,z2}, ... }
local function slab(parent, name, x1, z1, x2, z2, top, thick, holes, color, material)
	local xs, zs = { x1, x2 }, { z1, z2 }
	for _, h in holes do
		table.insert(xs, h[1])
		table.insert(xs, h[3])
		table.insert(zs, h[2])
		table.insert(zs, h[4])
	end
	table.sort(xs)
	table.sort(zs)
	local n = 0
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local ax, bx, az, bz = xs[i], xs[i + 1], zs[j], zs[j + 1]
			if bx - ax > 0.01 and bz - az > 0.01 then
				local cx, cz = (ax + bx) / 2, (az + bz) / 2
				local inHole = false
				for _, h in holes do
					if cx > h[1] and cx < h[3] and cz > h[2] and cz < h[4] then
						inHole = true
						break
					end
				end
				if not inHole then
					n += 1
					B(parent, name .. "_" .. n, ax, top - thick, az, bx, top, bz, color, material)
				end
			end
		end
	end
end

-- baranda de cristal con remate de neon, segmento alineado a un eje
local function rail(parent, name, x1, z1, x2, z2, y, color)
	local tx = (x1 == x2) and 0.2 or 0
	local tz = (z1 == z2) and 0.2 or 0
	B(parent, name .. "_Glass", x1 - tx, y, z1 - tz, x2 + tx, y + 4, z2 + tz, C.glass, M.Glass, { Transparency = 0.6 })
	glow(parent, name .. "_Cap", x1 - tx, y + 4, z1 - tz, x2 + tx, y + 4.3, z2 + tz, color or C.cyan, { cycle = true })
end

local function railLoop(parent, name, x1, z1, x2, z2, y, color)
	rail(parent, name .. "_N", x1, z1, x2, z1, y, color)
	rail(parent, name .. "_S", x1, z2, x2, z2, y, color)
	rail(parent, name .. "_W", x1, z1, x1, z2, y, color)
	rail(parent, name .. "_E", x2, z1, x2, z2, y, color)
end

-- pared con ventanal: base, cristal, remate y pilares
local function glassWall(parent, name, x1, z1, x2, z2, y0)
	local alongX = (x2 - x1) > (z2 - z1)
	B(parent, name .. "_Base", x1, y0, z1, x2, y0 + 3, z2, C.wall, M.Concrete)
	B(parent, name .. "_Glass", x1, y0 + 3, z1, x2, y0 + 19, z2, C.glass, M.Glass, { Transparency = 0.55 })
	B(parent, name .. "_Top", x1, y0 + 19, z1, x2, y0 + FLOOR_H, z2, C.wall, M.Concrete)
	for i = 0, 4 do
		local f = i / 4
		if alongX then
			local a = math.clamp(x1 + (x2 - x1) * f - 1, x1, x2 - 2)
			B(parent, name .. "_Pillar" .. i, a, y0, z1, a + 2, y0 + FLOOR_H, z2, C.dark, M.Concrete)
		else
			local a = math.clamp(z1 + (z2 - z1) * f - 1, z1, z2 - 2)
			B(parent, name .. "_Pillar" .. i, x1, y0, a, x2, y0 + FLOOR_H, a + 2, C.dark, M.Concrete)
		end
	end
end

-- escalera maciza de 24 peldanos (sube 24 studs). dir = sentido en Z en que se sube
local function stairs(parent, name, x1, x2, baseY, zStart, dir)
	for i = 0, 23 do
		local zc = zStart + dir * (2 * i + 1)
		local top = baseY + i + 1
		B(parent, name .. "_Step" .. i, x1, baseY, zc - 1, x2, top, zc + 1, C.dark, M.Concrete)
		local lipZ = zc - dir * 1
		glow(
			parent,
			name .. "_Lip" .. i,
			x1,
			top,
			math.min(lipZ, lipZ + dir * 0.4),
			x2,
			top + 0.1,
			math.max(lipZ, lipZ + dir * 0.4),
			C.cyan,
			{ cycle = true, phase = i * 0.15 }
		)
	end
end

-- sofa: asiento mirando a -Z local, respaldo en +Z local
local function sofa(parent, name, x, y, z, ry, w, color, glowColor)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, ry, 0)
	P(parent, name .. "_Seat", cf * CFrame.new(0, 1, 0), Vector3.new(w, 2, 3), color, M.Fabric)
	P(parent, name .. "_Back", cf * CFrame.new(0, 3, 1.25), Vector3.new(w, 4, 0.5), color, M.Fabric)
	for s = -1, 1, 2 do
		P(parent, name .. "_Arm" .. s, cf * CFrame.new(s * (w / 2 - 0.4), 1.9, 0), Vector3.new(0.8, 1.8, 3), color, M.Fabric)
	end
	P(parent, name .. "_Glow", cf * CFrame.new(0, 0.2, 0), Vector3.new(w - 0.5, 0.2, 2.6), glowColor or C.magenta, M.Neon, DECOR)
end

local function roundTable(parent, name, x, y, z, radius, high, glowColor)
	local h = high and 4.2 or 2.2
	cyl(parent, name .. "_Leg", x, y + h / 2, z, h, 0.7, C.black, M.Metal)
	cyl(parent, name .. "_Top", x, y + h + 0.15, z, 0.3, radius * 2, C.black, M.Marble)
	cyl(parent, name .. "_Glow", x, y + 0.1, z, 0.2, radius * 1.2, glowColor or C.cyan, M.Neon, DECOR)
end

local function stool(parent, name, x, y, z)
	cyl(parent, name .. "_Post", x, y + 1.2, z, 2.4, 0.5, C.black, M.Metal)
	cyl(parent, name .. "_Seat", x, y + 2.6, z, 0.6, 2, C.velvet, M.Fabric)
end

-- cabina de DJ mirando al sur (+Z). cx, y = suelo, z = mesa
local function djDeck(parent, name, cx, y, z, glowColor)
	B(parent, name .. "_Table", cx - 6, y, z - 1, cx + 6, y + 3.5, z + 1, C.black, M.SmoothPlastic)
	glow(parent, name .. "_TableGlow", cx - 6, y + 1, z + 1, cx + 6, y + 1.4, z + 1.1, glowColor, { cycle = true })
	for s = -1, 1, 2 do
		cyl(parent, name .. "_Deck" .. s, cx + s * 3, y + 3.7, z, 0.4, 2.6, C.dark, M.Metal)
		cyl(parent, name .. "_Disc" .. s, cx + s * 3, y + 3.95, z, 0.1, 2.2, C.cyan, M.Neon, DECOR)
	end
	B(parent, name .. "_Mixer", cx - 1, y + 3.5, z - 0.8, cx + 1, y + 4, z + 0.8, C.dark, M.Metal)
	B(parent, name .. "_Laptop", cx + 4.2, y + 3.5, z - 0.6, cx + 5.6, y + 3.7, z + 0.6, C.black, M.Metal)
end

local function speaker(parent, name, x, y, z, height, withSound)
	local body = B(parent, name, x - 3, y, z - 3, x + 3, y + height, z + 3, C.black, M.SmoothPlastic)
	local yy = y + 3
	while yy < y + height - 1 do
		cylZ(parent, name .. "_Woofer" .. yy, x, yy, z + 3, 0.4, 4, C.dark, M.Metal, { CanCollide = false })
		cylZ(parent, name .. "_Ring" .. yy, x, yy, z + 3.1, 0.2, 4.6, C.magenta, M.Neon, DECOR)
		yy += 5
	end
	if withSound then
		local s = Instance.new("Sound")
		s.Name = "ClubMusic"
		s.SoundId = CONFIG.MusicId
		s.Looped = true
		s.Volume = CONFIG.MusicVolume
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 160
		s.Parent = body
		if CONFIG.MusicId ~= "" then
			s:Play()
		end
	end
	return body
end

-- barra recta. side = lado de los clientes ("E","W","S","N")
local function barCounter(parent, name, x1, z1, x2, z2, y, side, glowColor)
	B(parent, name .. "_Body", x1, y, z1, x2, y + 4, z2, C.dark, M.Concrete)
	B(parent, name .. "_Top", x1 - 0.4, y + 4, z1 - 0.4, x2 + 0.4, y + 4.5, z2 + 0.4, C.black, M.Marble)
	local g = glowColor or C.magenta
	if side == "E" then
		glow(parent, name .. "_Strip", x2, y + 0.6, z1, x2 + 0.15, y + 1.1, z2, g, { cycle = true, light = 14 })
	elseif side == "W" then
		glow(parent, name .. "_Strip", x1 - 0.15, y + 0.6, z1, x1, y + 1.1, z2, g, { cycle = true, light = 14 })
	elseif side == "S" then
		glow(parent, name .. "_Strip", x1, y + 0.6, z2, x2, y + 1.1, z2 + 0.15, g, { cycle = true, light = 14 })
	else
		glow(parent, name .. "_Strip", x1, y + 0.6, z1 - 0.15, x2, y + 1.1, z1, g, { cycle = true, light = 14 })
	end
end

-- estanteria de botellas. eje = "Z": estantes a lo largo de Z, botellas mirando a +/-X
local function bottleShelf(parent, name, x, y, zFrom, zTo, depth)
	for k = 0, 2 do
		local sy = y + 3 + k * 2.6
		B(parent, name .. "_Board" .. k, x, sy, zFrom, x + depth, sy + 0.3, zTo, C.wood, M.Wood)
		glow(parent, name .. "_Led" .. k, x, sy - 0.15, zFrom, x + depth, sy, zTo, BOTTLES[k + 1], { cycle = true })
		local z = zFrom + 1
		local n = 0
		while z < zTo - 0.5 do
			n += 1
			cyl(
				parent,
				name .. "_Bottle" .. k .. "_" .. n,
				x + depth / 2,
				sy + 1,
				z,
				1.4,
				0.6,
				BOTTLES[(n + k) % #BOTTLES + 1],
				M.Glass,
				{ CanCollide = false, Transparency = 0.2 }
			)
			z += 2
		end
	end
end

------------------------------------------------------------------------
-- Exterior y estructura
------------------------------------------------------------------------
local function buildShell()
	local e = folders.Exterior
	B(e, "Street", -120, -6, -120, 120, -0.2, 120, Color3.fromRGB(28, 28, 34), M.Asphalt)
	B(e, "Sidewalk", -60, -3, -60, 60, -0.1, 75, Color3.fromRGB(70, 66, 80), M.Concrete)

	-- paredes del piso 1 (entrada al sur: hueco de 14 x 11)
	local f1 = folders.Floor1
	B(f1, "Wall_N", -50, 0, -50, 50, FLOOR_H, -48, C.wall, M.Concrete)
	B(f1, "Wall_W", -50, 0, -48, -48, FLOOR_H, 48, C.wall, M.Concrete)
	B(f1, "Wall_E", 48, 0, -48, 50, FLOOR_H, 48, C.wall, M.Concrete)
	B(f1, "Wall_S_L", -50, 0, 48, -7, FLOOR_H, 50, C.wall, M.Concrete)
	B(f1, "Wall_S_R", 7, 0, 48, 50, FLOOR_H, 50, C.wall, M.Concrete)
	B(f1, "Wall_S_Top", -7, 11, 48, 7, FLOOR_H, 50, C.wall, M.Concrete)

	-- pared del piso 2 (ventanales salvo el norte)
	local f2 = folders.Floor2
	local y2 = FLOOR_Y[2]
	B(f2, "Wall_N", -50, y2, -50, 50, y2 + FLOOR_H, -48, C.wall, M.Concrete)
	glassWall(f2, "Glass_W", -50, -48, -48, 48, y2)
	glassWall(f2, "Glass_E", 48, -48, 50, 48, y2)
	glassWall(f2, "Glass_S", -50, 48, 50, 50, y2)

	-- arco neon de la puerta
	glow(e, "Door_L", -7.6, 0, 50, -7, 11.6, 50.5, C.magenta, { cycle = true, light = 24 })
	glow(e, "Door_R", 7, 0, 50, 7.6, 11.6, 50.5, C.magenta, { cycle = true, light = 24, phase = 1 })
	glow(e, "Door_Top", -7.6, 11, 50, 7.6, 11.6, 50.5, C.cyan, { cycle = true })

	-- cantos verticales de neon en las 4 esquinas
	for i, c in { { -50.3, -50.3 }, { 50.3, -50.3 }, { -50.3, 50.3 }, { 50.3, 50.3 } } do
		glow(e, "Corner" .. i, c[1] - 0.2, 0, c[2] - 0.2, c[1] + 0.2, FLOOR_Y[3], c[2] + 0.2, C.purple, { cycle = true, phase = i })
	end

	sign(e, "MainSign", 0, 17, 50.3, 36, 7, 0, 1, "AURA CLUB", C.cyan, true)
	glow(e, "MainSignFrameT", -18.4, 20.5, 50.2, 18.4, 20.9, 50.5, C.magenta, { cycle = true })
	glow(e, "MainSignFrameB", -18.4, 13.1, 50.2, 18.4, 13.5, 50.5, C.magenta, { cycle = true })

	-- cola de entrada: postes dorados y cuerdas de terciopelo
	for _, sx in { -6, 6 } do
		for k = 0, 3 do
			local z = 54 + k * 5
			cyl(e, "Post", sx, 1.5, z, 3, 0.6, C.gold, M.Metal)
			ball(e, "PostTop", sx, 3.1, z, 0.9, C.gold, M.Metal)
			if k < 3 then
				B(e, "Rope", sx - 0.15, 2.3, z, sx + 0.15, 2.7, z + 5, C.velvet, M.Fabric, DECOR)
			end
		end
	end
	for _, sx in { -12, 12 } do
		B(e, "Planter", sx - 1.5, 0, 52, sx + 1.5, 2.5, 55, C.dark, M.Concrete)
		ball(e, "PlanterLeaf", sx, 4.2, 53.5, 4, C.green, M.Grass)
	end
end

------------------------------------------------------------------------
-- PISO 1
------------------------------------------------------------------------
local function buildFloor1()
	local f = folders.Floor1
	B(f, "Floor1_Slab", -50, -3, -50, 50, 0, 50, C.floor, M.Concrete)

	-- alfombra del hall
	B(f, "Carpet", -4, 0, 28, 4, 0.1, 48, C.velvet, M.Fabric)

	-- pista LED
	local n = CONFIG.TileCount
	local size = 48 / n
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			local x1 = -24 + ix * size
			local z1 = -34 + iz * size
			local tile = B(f, "Tile", x1 + 0.1, 0, z1 + 0.1, x1 + size - 0.1, 0.2, z1 + size - 0.1, C.cyan, M.Neon)
			table.insert(fx.tiles, { part = tile, ix = ix, iz = iz })
		end
	end

	-- escenario DJ (norte) con 3 escalones de acceso
	B(f, "Stage", -18, 0, -46.5, 18, 3, -37, C.black, M.SmoothPlastic)
	B(f, "StageStepB", -6, 0, -37, 6, 2, -36, C.black, M.SmoothPlastic)
	B(f, "StageStepA", -6, 0, -36, 6, 1, -35, C.black, M.SmoothPlastic)
	glow(f, "StageTrim", -18, 0.8, -37.15, 18, 1.3, -37, C.magenta, { cycle = true, light = 18 })
	djDeck(f, "DJ1", 0, 3, -42, C.cyan)

	-- pantalla LED gigante
	local _, label = sign(f, "DJScreen", 0, 13, -47.6, 40, 14, 0, 1, "AURA", C.cyan, false)
	table.insert(fx.screens, label)
	glow(f, "ScreenFrameT", -20.4, 20, -47.7, 20.4, 20.5, -47.2, C.purple, { cycle = true })
	glow(f, "ScreenFrameB", -20.4, 5.5, -47.7, 20.4, 6, -47.2, C.purple, { cycle = true })

	-- altavoces (el de la izquierda lleva el Sound)
	speaker(f, "Speaker_L", -22, 0, -43, 12, true)
	speaker(f, "Speaker_R", 22, 0, -43, 12, false)

	-- truss del escenario con focos y estrobos
	B(f, "StageTruss", -20, 19.5, -40.3, 20, 20, -39.7, C.dark, M.Metal)
	for i, x in { -16, -8, 0, 8, 16 } do
		glow(f, "StageSpot" .. i, x - 0.6, 18.6, -40.6, x + 0.6, 19.5, -39.4, C.magenta, {
			cycle = true,
			phase = i,
			light = 36,
			spot = true,
			brightness = 3,
		})
	end
	for i, x in { -12, -4, 4, 12 } do
		local s = B(f, "Strobe" .. i, x - 1.5, 17.6, -38.6, x + 1.5, 18.1, -37.8, C.dark, M.Neon, DECOR)
		table.insert(fx.strobes, { part = s, light = addLight(s, C.white, 40, true, 6) })
	end


	-- bola de espejos colgada del techo del atrio (gira lento)
	local mc = Vector3.new(0, 36, -10)
	B(f, "MirrorRod", mc.X - 0.15, mc.Y + 3, mc.Z - 0.15, mc.X + 0.15, FLOOR_Y[3] - 2, mc.Z + 0.15, C.dark, M.Metal, DECOR)
	local core = ball(f, "MirrorCore", mc.X, mc.Y, mc.Z, 6, C.dark, M.Metal, { Reflectance = 0.6 })
	addLight(core, C.white, 40, false, 2)
	local rings = { { -60, 6 }, { -30, 10 }, { 0, 12 }, { 30, 10 }, { 60, 6 } }
	for _, ring in rings do
		local lat = math.rad(ring[1])
		for k = 0, ring[2] - 1 do
			local lon = k / ring[2] * math.pi * 2
			local dir = Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon))
			local local_cf = CFrame.lookAt(dir * 3, dir * 4)
			local facet = P(f, "MirrorFacet", CFrame.new(mc) * local_cf, Vector3.new(1.1, 1.1, 0.15), C.white, M.Metal, { Reflectance = 1, CanCollide = false, CastShadow = false })
			table.insert(fx.mirror, { part = facet, center = mc, offset = local_cf })
		end
	end

	-- truss del atrio con 6 lasers (3 por lado)
	for _, side in { -1, 1 } do
		local x = side * 22
		B(f, "AtriumTruss", x - 0.3, 41, -34, x + 0.3, 41.6, -6, C.dark, M.Metal)
		for _, z in { -33, -7 } do
			B(f, "AtriumRod", x - 0.2, 41.6, z - 0.2, x + 0.2, FLOOR_Y[3] - 2, z + 0.2, C.dark, M.Metal)
		end
		for k, z in { -32, -20, -8 } do
			local colors = { C.cyan, C.magenta, C.purple }
			local col = colors[k]
			glow(f, "LaserHead", x - 0.8, 39.4, z - 0.8, x + 0.8, 40.6, z + 0.8, col, { light = 10 })
			local beam = P(
				folders.Effects,
				"Laser",
				CFrame.new(x, 40, z),
				Vector3.new(0.5, 0.5, BEAM_LEN),
				col,
				M.Neon,
				{ CanCollide = false, CastShadow = false, Transparency = 0.45 }
			)
			table.insert(fx.beams, {
				part = beam,
				origin = Vector3.new(x, 40, z),
				yaw = math.pi + side * -0.4,
				swing = 0.4,
				speed = 1 + k * 0.35,
				phase = k * 1.7 + (side + 1),
				side = side,
			})
		end
	end

	-- barra oeste
	B(f, "BackBar", -48, 0, -26, -46, 6, 8, C.dark, M.Concrete)
	bottleShelf(f, "BarShelf", -46.8, 0, -26, 8, 0.8)
	barCounter(f, "Bar1", -43, -26, -40, 6, 0, "E", C.magenta)
	for k = 0, 5 do
		stool(f, "BarStool" .. k, -36, 0, -22 + k * 5)
	end
	sign(f, "BarSign", -47.6, 17, -9, 14, 4, 1, 0, "BAR", C.magenta, true)

	-- booths (suroeste): sofas contra la pared oeste + mesa
	for i, z in { 18, 28, 38 } do
		sofa(f, "Booth" .. i, -46.2, 0, z, -math.pi / 2, 9, C.velvet, C.magenta)
		roundTable(f, "BoothTable" .. i, -41.5, 0, z, 1.8, false, C.cyan)
	end

	-- mesas altas este de la pista
	for i, z in { 18, 30, 42 } do
		roundTable(f, "HighTable" .. i, 31, 0, z, 1.6, true, C.purple)
	end
	for i, z in { 22, 34 } do
		roundTable(f, "HighTableW" .. i, -28, 0, z, 1.6, true, C.cyan)
	end

	-- escalera P1 -> P2 (este): se sube hacia el norte
	stairs(folders.Stairs, "Stairs1", 40, 48, FLOOR_Y[1], 46, -1)

	-- tiras de luz en el techo del hall
	for i, x in { -14, 14 } do
		glow(f, "HallStrip" .. i, x - 0.3, 21.6, 18, x + 0.3, 22, 46, C.purple, { cycle = true, phase = i, light = 24 })
	end
	glow(f, "StageCeil", -20, 21.6, -46, 20, 22, -45.4, C.cyan, { cycle = true })
	sign(f, "Floor1Label", 47.6, 16, 24, 10, 3, -1, 0, "LEVEL 1", C.cyan, true)
end

------------------------------------------------------------------------
-- PISO 2 (VIP)
------------------------------------------------------------------------
local function buildFloor2()
	local f = folders.Floor2
	local y = FLOOR_Y[2]
	slab(f, "Floor2_Slab", -50, -50, 50, 50, y, 2, { { -24, -34, 24, 14 }, { 40, -2, 48, 16 } }, Color3.fromRGB(34, 22, 44), M.Marble)

	-- barandillas del balcon sobre la pista y del hueco de la escalera
	railLoop(f, "AtriumRail", -24, -34, 24, 14, y, C.cyan)
	rail(f, "S1Rail_W", 40, -2, 40, 16, y, C.magenta)
	rail(f, "S1Rail_S", 40, 16, 48, 16, y, C.magenta)

	-- barra VIP norte
	B(f, "VIPBackBar", -16, y, -48, 16, y + 6, -46, C.dark, M.Concrete)
	for k = 0, 2 do
		local sy = y + 8 + k * 2.6
		B(f, "VIPShelf" .. k, -16, sy, -46, 16, sy + 0.3, -45, C.wood, M.Wood)
		glow(f, "VIPShelfLed" .. k, -16, sy - 0.15, -46, 16, sy, -45, BOTTLES[k + 1], { cycle = true, light = 16 })
		for n = 0, 7 do
			cyl(f, "VIPBottle", -14 + n * 4, sy + 1, -45.5, 1.4, 0.6, BOTTLES[(n + k) % #BOTTLES + 1], M.Glass, { CanCollide = false, Transparency = 0.2 })
		end
	end
	barCounter(f, "VIPBar", -14, -44, 14, -41, y, "S", C.gold)
	for k, x in { -12, -4, 4, 12 } do
		stool(f, "VIPStool" .. k, x, y, -39.5)
	end
	sign(f, "VIPSign", 0, y + 14, -47.6, 22, 6, 0, 1, "V.I.P", C.gold, false)

	-- lounges: mesa + 2 sofas enfrentados
	local lounges = {
		{ 32, -24 }, { 32, -10 }, { -32, -24 }, { -32, -8 }, { -32, 8 },
		{ -30, 30 }, { 0, 30 }, { 30, 30 },
	}
	for i, p in lounges do
		local x, z = p[1], p[2]
		roundTable(f, "LoungeTable" .. i, x, y, z, 2, false, C.gold)
		sofa(f, "LoungeSofaA" .. i, x, y, z - 5, math.pi, 7, C.velvet, C.gold)
		sofa(f, "LoungeSofaB" .. i, x, y, z + 5, 0, 7, C.velvet, C.gold)
		glow(f, "Chandelier" .. i, x - 3, y + 17, z - 3, x + 3, y + 17.3, z + 3, C.gold, { cycle = true, phase = i, light = 26 })
		B(f, "ChandelierRod" .. i, x - 0.1, y + 17.3, z - 0.1, x + 0.1, y + FLOOR_H, z + 0.1, C.dark, M.Metal, DECOR)
	end

	-- tiras en el techo (parte baja de la losa del piso 3)
	for i, z in { -30, 22, 38 } do
		glow(f, "CeilStrip" .. i, -46, y + 21.6, z, 46, y + 22, z + 0.6, C.purple, { cycle = true, phase = i })
	end
	sign(f, "Floor2Label", 47.6, y + 16, -20, 10, 3, -1, 0, "LEVEL 2", C.gold, false)

	-- escalera P2 -> P3 (oeste): se sube hacia el sur
	stairs(folders.Stairs, "Stairs2", -48, -40, y, -46, 1)
end

------------------------------------------------------------------------
-- PISO 3 (rooftop)
------------------------------------------------------------------------
local function lounger(parent, name, x, y, z)
	B(parent, name .. "_Base", x - 1.5, y, z - 3.5, x + 1.5, y + 1.2, z + 3.5, Color3.fromRGB(235, 235, 245), M.Fabric)
	P(parent, name .. "_Back", CFrame.new(x, y + 1.7, z + 3) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(3, 0.6, 2), Color3.fromRGB(235, 235, 245), M.Fabric)
	glow(parent, name .. "_Glow", x - 1.4, y, z - 3.4, x + 1.4, y + 0.15, z + 3.4, C.cyan, { cycle = true })
end

local function firePit(parent, name, x, y, z)
	cyl(parent, name .. "_Ring", x, y + 0.75, z, 1.5, 6, Color3.fromRGB(60, 56, 66), M.Slate)
	local flame = P(parent, name .. "_Flame", CFrame.new(x, y + 1.6, z), Vector3.new(1, 1, 1), C.fire, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 9
	fire.Color = C.fire
	fire.SecondaryColor = C.magenta
	fire.Parent = flame
	local l = Instance.new("PointLight")
	l.Color = C.fire
	l.Range = 26
	l.Brightness = 2
	l.Parent = flame
	lightCount += 1
	sofa(parent, name .. "_SofaS", x, y, z + 6.5, 0, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaN", x, y, z - 6.5, math.pi, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaE", x + 6.5, y, z, math.pi / 2, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaW", x - 6.5, y, z, -math.pi / 2, 6, C.velvet, C.fire)
end

local function buildFloor3()
	local f = folders.Floor3
	local y = FLOOR_Y[3]
	local pool = { 14, 22, 34, 44 }
	slab(f, "Floor3_Slab", -50, -50, 50, 50, y, 2, { { -48, -16, -40, 2 }, pool }, C.deck, M.WoodPlanks)

	-- parapeto de cristal + barandillas del hueco de escalera
	railLoop(f, "Parapet", -49.6, -49.6, 49.6, 49.6, y, C.magenta)
	rail(f, "S2Rail_N", -48, -16, -40, -16, y, C.cyan)
	rail(f, "S2Rail_E", -40, -16, -40, 2, y, C.cyan)

	-- piscina poco profunda (fondo neon + agua sin colision)
	B(f, "PoolFloor", pool[1], y - 2, pool[2], pool[3], y - 1, pool[4], Color3.fromRGB(0, 120, 200), M.Neon)
	B(f, "PoolWater", pool[1], y - 1, pool[2], pool[3], y - 0.2, pool[4], C.cyan, M.Glass, { Transparency = 0.45, CanCollide = false })
	glow(f, "PoolRim_N", pool[1], y, pool[2] - 0.2, pool[3], y + 0.15, pool[2], C.cyan, { cycle = true, light = 18 })
	glow(f, "PoolRim_S", pool[1], y, pool[4], pool[3], y + 0.15, pool[4] + 0.2, C.cyan, { cycle = true })
	glow(f, "PoolRim_W", pool[1] - 0.2, y, pool[2], pool[1], y + 0.15, pool[4], C.cyan, { cycle = true })
	glow(f, "PoolRim_E", pool[3], y, pool[2], pool[3] + 0.2, y + 0.15, pool[4], C.cyan, { cycle = true })

	-- escenario DJ del rooftop + arco
	B(f, "RoofStage", -14, y, -47, 14, y + 2, -37, C.black, M.SmoothPlastic)
	B(f, "RoofStageStep", -5, y, -37, 5, y + 1, -35.5, C.black, M.SmoothPlastic)
	glow(f, "RoofStageTrim", -14, y + 0.6, -37.15, 14, y + 1, -37, C.cyan, { cycle = true, light = 16 })
	djDeck(f, "DJ3", 0, y + 2, -43, C.magenta)
	speaker(f, "RoofSpeaker_L", -18, y + 2, -44, 9, true)
	speaker(f, "RoofSpeaker_R", 18, y + 2, -44, 9, false)
	B(f, "ArchPillarL", -15.5, y, -47, -14.5, y + 15, -46, C.dark, M.Metal)
	B(f, "ArchPillarR", 14.5, y, -47, 15.5, y + 15, -46, C.dark, M.Metal)
	B(f, "ArchBeam", -15.5, y + 14, -47, 15.5, y + 15, -46, C.dark, M.Metal)
	for i, x in { -8, 0, 8 } do
		glow(f, "RoofSpot" .. i, x - 0.6, y + 13.1, -46.8, x + 0.6, y + 14, -45.2, C.purple, {
			cycle = true,
			phase = i,
			light = 34,
			spot = true,
			brightness = 3,
		})
	end
	for i, x in { -10, 10 } do
		local s = B(f, "RoofStrobe" .. i, x - 1.5, y + 12.4, -46.8, x + 1.5, y + 12.9, -46, C.dark, M.Neon, DECOR)
		table.insert(fx.strobes, { part = s, light = addLight(s, C.white, 40, true, 6) })
	end
	sign(f, "RoofSign", 0, y + 24, -47.2, 24, 6, 0, 1, "AURA", C.magenta, true)
	B(f, "RoofSignPost1", -9, y + 15, -47.4, -8.5, y + 21, -47, C.dark, M.Metal, DECOR)
	B(f, "RoofSignPost2", 8.5, y + 15, -47.4, 9, y + 21, -47, C.dark, M.Metal, DECOR)

	-- barra del rooftop (isla + estanteria)
	B(f, "RoofRack", 34, y, -30, 36, y + 10, -4, C.dark, M.Concrete)
	bottleShelf(f, "RoofShelf", 33, y, -30, -4, 1)
	barCounter(f, "RoofBar", 27.5, -30, 30.5, -4, y, "W", C.cyan)
	for k = 0, 5 do
		stool(f, "RoofStool" .. k, 24, y, -27 + k * 4)
	end
	glow(f, "RoofRackLed", 34.9, y, -30, 35.1, y + 10, -4, C.purple, { cycle = true, light = 22 })

	-- loungers junto a la piscina y fire pits
	for i, z in { 25, 31, 37, 43 } do
		lounger(f, "Lounger" .. i, 8, y, z)
	end
	firePit(f, "FirePit1", -26, y, -4)
	firePit(f, "FirePit2", -26, y, 30)

	-- macetas
	for i = 0, 7 do
		local x = -42 + i * 12
		B(f, "Planter" .. i, x - 1.5, y, 45, x + 1.5, y + 2.2, 48, C.dark, M.Concrete)
		ball(f, "PlanterLeaf" .. i, x, y + 4.2, 46.5, 4, C.green, M.Grass)
	end
	sign(f, "Floor3Label", 47.5, y + 6, 20, 10, 3, -1, 0, "ROOFTOP", C.magenta, true)
end

------------------------------------------------------------------------
-- Spawn, ambiente y animaciones
------------------------------------------------------------------------
local function buildSpawn()
	local s = Instance.new("SpawnLocation")
	s.Name = "ClubSpawn"
	s.Anchored = true
	s.Size = Vector3.new(8, 0.4, 8)
	s.CFrame = CFrame.new(0, 0.2, 38)
	s.Color = C.cyan
	s.Material = M.Neon
	s.Transparency = 0.6
	s.Neutral = true
	s.Duration = 0
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = club
end

local function buildLighting()
	for _, n in { "AuraBloom", "AuraColor", "AuraAtmosphere" } do
		local o = Lighting:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(48, 32, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 26, 66)
	Lighting.GlobalShadows = true

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AuraBloom"
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AuraColor"
	cc.Contrast = 0.1
	cc.Saturation = 0.25
	cc.TintColor = Color3.fromRGB(235, 220, 255)
	cc.Parent = Lighting

	local atm = Instance.new("Atmosphere")
	atm.Name = "AuraAtmosphere"
	atm.Density = 0.22
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(120, 70, 190)
	atm.Decay = Color3.fromRGB(60, 30, 110)
	atm.Glare = 0.1
	atm.Haze = 1.2
	atm.Parent = Lighting
end

local function updateBeams(t)
	for _, b in fx.beams do
		local ry = b.yaw + b.swing * math.sin(t * b.speed + b.phase)
		b.part.CFrame = CFrame.new(b.origin)
			* CFrame.Angles(0, ry, 0)
			* CFrame.Angles(BEAM_PITCH, 0, 0)
			* CFrame.new(0, 0, -BEAM_LEN / 2)
	end
end

local function updateMirror(t)
	local spin = CFrame.new(fx.mirror[1].center) * CFrame.Angles(0, t * 0.5, 0)
	for _, m in fx.mirror do
		m.part.CFrame = spin * m.offset
	end
end

local SCREEN_TEXTS = { "AURA", "CLUB", "3 FLOORS", "LET'S GO", "AURA" }

local function startAnimations()
	local t, fast, slow = 0, 0, 0
	local lastScreen = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		fast += dt
		slow += dt

		if fast >= 0.05 then
			fast = 0
			updateBeams(t)
			updateMirror(t)
			-- rafaga de estrobos: 2 s de cada 24 s
			local burst = (t % 24) > 22
			local on = burst and (math.floor(t * 14) % 2 == 0)
			for _, s in fx.strobes do
				s.part.Color = on and C.white or C.dark
				s.light.Enabled = on
			end
		end

		if slow >= 0.2 then
			slow = 0
			for _, tile in fx.tiles do
				local hue = (0.5 + 0.4 * (0.5 + 0.5 * math.sin(t * 0.7 + (tile.ix + tile.iz) * 0.35))) % 1
				local v = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 3 + tile.ix * 0.8 - tile.iz * 0.8))
				tile.part.Color = Color3.fromHSV(hue, 0.9, v)
			end
			for _, g in fx.glows do
				local c = cycleColor(t, g.phase)
				g.part.Color = c
				if g.light then
					g.light.Color = c
				end
			end
			for _, s in fx.signs do
				s.label.TextColor3 = cycleColor(t, s.phase)
			end
			local idx = math.floor(t / 3) % #SCREEN_TEXTS + 1
			if idx ~= lastScreen then
				lastScreen = idx
				for _, l in fx.screens do
					l.Text = SCREEN_TEXTS[idx]
				end
			end
			for _, l in fx.screens do
				l.TextColor3 = cycleColor(t, 0)
			end
		end
	end)
end

------------------------------------------------------------------------
-- Ejecucion
------------------------------------------------------------------------
buildShell()
buildFloor1()
buildFloor2()
buildFloor3()
buildSpawn()
buildLighting()
updateMirror(0)
updateBeams(0) -- pose inicial correcta antes de aparecer
club.Parent = Workspace
startAnimations()

local partCount = 0
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
if CONFIG.MusicId == "" then
	warn("[AuraClub] CONFIG.MusicId esta vacio: pon un rbxassetid:// para tener musica.")
end
print(string.format("[AuraClub] listo: %d partes, %d luces, 3 pisos.", partCount, lightCount))
