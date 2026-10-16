--[[
	BUILD - construye el club (edificio de 3 pisos, exterior, parqueadero, mobiliario) con geometria.
	Es el codigo de v1 convertido en modulo: Build.run(deps) devuelve el contexto con helpers y
	registros para que Extras/Interactions añadan NPC, asientos, cabina DJ, pantallas, etc.
	No hay ninguna logica de compra, inventario ni musica aqui.
]]
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local CONFIG = require(Shared.Config)
local Util = require(Shared.Util)
local LOOK = CONFIG.Look
CONFIG.LogoImageId = Util.normalizeAssetId(CONFIG.LogoImageId)

local function run(deps)
deps = deps or {}
local ctx -- se rellena al final; los ganchos de deps lo reciben
-- PERFILES GRAFICOS (decision de construccion; el jugador sigue eligiendo su calidad en Roblox)
local PROFILES = {
	Equilibrado = {
		tiles = 12, -- baldosas por lado de la pista
		mirrorStep = 18, -- grados entre anillos de la bola de espejos (menos facetas)
		shadowLights = 4, -- luces con sombras (la parte mas cara del renderizado)
		laserLayers = 2, -- capas translucidas por laser
		shaftEvery = 2, -- 1 de cada N conos de luz
		haze = false, -- sin humo de escenario ni de calderos (particulas)
		dof = false, -- sin profundidad de campo
		bloomScale = 0.75,
		pruneMinor = true, -- quita las luces decorativas menores (velas, calabazas, llamas, tiras de barra)
		fallbackRates = { fast = 0.1, tiles = 0.5, glows = 0.5, mirror = 0.25 },
	},
	Alta = {
		tiles = 16,
		mirrorStep = 12,
		shadowLights = 12,
		laserLayers = 3,
		shaftEvery = 1,
		haze = true,
		dof = true,
		bloomScale = 1,
		pruneMinor = false,
		fallbackRates = { fast = 0.05, tiles = 0.25, glows = 0.25, mirror = 0.15 },
	},
}
local PROFILE_NAME = (PROFILES[CONFIG.Quality] and CONFIG.Quality) or "Equilibrado"
local PROFILE = PROFILES[PROFILE_NAME]
local TILE_COUNT = (CONFIG.TileCount and CONFIG.TileCount > 0) and CONFIG.TileCount or PROFILE.tiles
local shadowBudget = PROFILE.shadowLights

-- segundos entre actualizaciones de cada efecto (cada cambio de propiedad se replica a los clientes)
local RATES = PROFILE.fallbackRates
if CONFIG.LowPerformance then
	RATES = { fast = RATES.fast * 2, tiles = RATES.tiles * 2, glows = RATES.glows * 2, mirror = RATES.mirror * 2 }
end

local FLOOR_Y = { 0, 24, 48 }
local FLOOR_H = 22 -- altura libre entre piso y techo (losa de 2 studs)
local BEAM_LEN = 43
local BEAM_PITCH = math.rad(-68)

local C = {
	-- paleta LUXURY: negro lacado, marfil, cromo y champan; los acentos de color son suaves
	black = Color3.fromRGB(10, 10, 12),
	dark = Color3.fromRGB(26, 26, 30),
	wall = Color3.fromRGB(30, 29, 34),
	floor = Color3.fromRGB(12, 12, 15),
	deck = Color3.fromRGB(44, 42, 46),
	purple = Color3.fromRGB(176, 160, 208), -- lila suave
	magenta = Color3.fromRGB(226, 190, 156), -- oro rosa
	cyan = Color3.fromRGB(196, 224, 238), -- hielo
	blue = Color3.fromRGB(160, 180, 215),
	white = Color3.fromRGB(255, 255, 255),
	gold = Color3.fromRGB(222, 178, 98),
	velvet = Color3.fromRGB(15, 15, 18), -- cuero negro
	glass = Color3.fromRGB(150, 200, 255),
	wood = Color3.fromRGB(70, 45, 35),
	green = Color3.fromRGB(30, 120, 60),
	fire = Color3.fromRGB(255, 140, 40),
	sofaWarm = Color3.fromRGB(238, 234, 226), -- cuero marfil
	warmWhite = Color3.fromRGB(255, 214, 170),
	orange = Color3.fromRGB(255, 120, 20),
	pumpkin = Color3.fromRGB(240, 105, 15),
	stem = Color3.fromRGB(90, 110, 40),
	flame = Color3.fromRGB(255, 196, 60),
	candle = Color3.fromRGB(238, 222, 188),
	web = Color3.fromRGB(225, 225, 240),
	violet = Color3.fromRGB(128, 100, 196), -- acento del monograma (suave)
	silver = Color3.fromRGB(214, 217, 230),
	navy = Color3.fromRGB(14, 12, 24),
	ivory = Color3.fromRGB(240, 237, 230),
	chrome = Color3.fromRGB(206, 210, 220),
}
local M = Enum.Material
local DECOR = { CanCollide = false, CastShadow = false }
local BOTTLES = {
	Color3.fromRGB(205, 150, 80),
	Color3.fromRGB(228, 232, 238),
	C.gold,
	Color3.fromRGB(140, 90, 60),
	Color3.fromRGB(150, 180, 150),
	Color3.fromRGB(200, 210, 225),
}
-- acabados pulidos: cuero lacado, marmol y cromo
local LACQUER = { Reflectance = 0.22 }
local MARBLE_W = { Reflectance = 0.3 }

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
for _, n in { "Exterior", "Streets", "Parking", "Perimeter", "Floor1", "Floor2", "Floor3", "Stairs", "Effects" } do
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
	lamps = {}, -- luces de relleno (cobertura de luz real)
	flames = {}, -- luces de velas/calabazas con parpadeo
}
local lightCount = 0

------------------------------------------------------------------------
-- Helpers de construccion
------------------------------------------------------------------------
local function P(parent, name, cf, size, color, material, extra)
	local p = Instance.new((extra and extra.Wedge) and "WedgePart" or "Part")
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
			if k ~= "Wedge" then
				p[k] = v
			end
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

local lightShaft -- se define mas abajo (necesita lighten)
local shaftSeen = 0

local function addLight(part, color, range, spot, brightness, shadows)
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
	l.Brightness = (brightness or 1.2) * LOOK.LightIntensity
	local useShadow = false
	if shadows and LOOK.KeyShadows and shadowBudget > 0 then
		shadowBudget -= 1
		useShadow = true
	end
	l.Shadows = useShadow
	l.Parent = part
	lightCount += 1
	return l
end

-- neon (decorativo, sin colision). opts: cycle, phase, light, spot, brightness
-- marcos, esquinas y remates que antes eran neon ahora son filetes de laton pulido (menos neon, mas lujo)
local METAL_TRIM = { "^MainSignFrame", "^FacadeBanner%a$", "^Corner%d", "^ScreenFrame", "^CeilStrip", "^Pillar%aCap$", "^Door_Top$", "^StageCeil$" }
local function glow(parent, name, x1, y1, z1, x2, y2, z2, color, opts)
	for _, pat in METAL_TRIM do
		if string.find(name, pat) then
			return B(parent, name, x1, y1, z1, x2, y2, z2, C.gold, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.6 })
		end
	end
	local p = B(parent, name, x1, y1, z1, x2, y2, z2, color, M.Neon, DECOR)
	if opts then
		local light
		if opts.light then
			light = addLight(p, color, opts.light, opts.spot, opts.brightness, opts.shadows)
		end
		local entry
		if opts.cycle then
			entry = { part = p, light = light, phase = opts.phase or 0 }
			table.insert(fx.glows, entry)
		end
		-- cono de luz translucido bajo el foco: opts.shaft = { largo, ancho arriba, ancho abajo }
		if opts.shaft and lightShaft then
			shaftSeen += 1
		end
		if opts.shaft and lightShaft and shaftSeen % PROFILE.shaftEvery == 0 then
			local b = lightShaft(p, color, opts.shaft[1], opts.shaft[2], opts.shaft[3])
			if entry then
				entry.beam = b
			end
		end
	end
	return p
end

-- luz de relleno: fuente invisible. Los neones brillan pero NO iluminan, asi que sin esto
-- grandes zonas caminables quedan negras (sobre todo mientras el motor calcula la luz).
local function lamp(parent, name, x, y, z, color, range, brightness)
	local p = P(parent, name, CFrame.new(x, y, z), Vector3.new(0.4, 0.4, 0.4), C.black, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CastShadow = false })
	local l = addLight(p, color, range, false, brightness)
	table.insert(fx.lamps, { light = l, phase = #fx.lamps * 0.9 })
	return p
end

-- rejilla 3x3 de luces de relleno cubriendo todo el piso de 160 (separacion 56, alcance 60)
local function fillGrid(parent, name, y, color, range, brightness)
	for _, x in { -56, 0, 56 } do
		for _, z in { -56, 0, 56 } do
			lamp(parent, name, x, y, z, color, range, brightness)
		end
	end
end

-- estrobo: empieza APAGADO (la luz se enciende solo durante las rafagas)
local function addStrobe(parent, name, x1, y1, z1, x2, y2, z2)
	local s = B(parent, name, x1, y1, z1, x2, y2, z2, C.dark, M.Neon, DECOR)
	local l = addLight(s, C.white, 40, true, 4)
	l.Enabled = false
	table.insert(fx.strobes, { part = s, light = l, on = false })
end

local function mix(c1, c2, a)
	return Color3.new(c1.R + (c2.R - c1.R) * a, c1.G + (c2.G - c1.G) * a, c1.B + (c2.B - c1.B) * a)
end

local function scaleColor(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- el color de letreros y neones oscila despacio entre dos tonos calidos/neutros (nada saturado)
local TONE_A, TONE_B = Color3.fromRGB(246, 240, 228), Color3.fromRGB(238, 198, 140)
local function cycleColor(t, phase)
	local a = 0.5 + 0.5 * math.sin(t * 0.6 + phase)
	return mix(TONE_A, TONE_B, a)
end

-- cartel con SurfaceGui. (dx,dz) = hacia donde mira el cartel
local GOLD_TXT = Color3.fromRGB(232, 188, 98)
-- "ROJA" siempre en rojo (identidad del logo): texto enriquecido
local function brandRich(text)
	return (string.gsub(text, "ROJA", '<font color="#D4182A">ROJA</font>'))
end

local function sign(parent, name, cx, cy, cz, w, h, dx, dz, text, color, cycle, style, image)
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
	if style == "chrome" then
		-- rotulo de marca: serif dorada sobre negro con ROJA en rojo y marco dorado fino
		tl.Font = Enum.Font.Bodoni
		tl.RichText = true
		tl.Text = brandRich(text)
		tl.TextColor3 = GOLD_TXT
		local border = Instance.new("Frame")
		border.Name = "Border"
		border.BackgroundTransparency = 1
		border.Size = UDim2.fromScale(0.985, 0.94)
		border.Position = UDim2.fromScale(0.0075, 0.03)
		border.Parent = gui
		local bs = Instance.new("UIStroke")
		bs.Color = GOLD_TXT
		bs.Thickness = 2
		bs.Parent = border
	elseif style == "screen" then
		tl.Font = Enum.Font.Bodoni
		tl.RichText = true
		tl.Text = brandRich(text)
	end
	if image and image ~= "" then
		-- logo opcional importado como imagen: va a la izquierda del texto
		local img = Instance.new("ImageLabel")
		img.Name = "Logo"
		img.BackgroundTransparency = 1
		img.Image = image
		img.ScaleType = Enum.ScaleType.Fit
		img.Position = UDim2.fromScale(0.02, 0.08)
		img.Size = UDim2.fromScale(0.2, 0.84)
		img.Parent = gui
		tl.Position = UDim2.fromScale(0.24, 0)
		tl.Size = UDim2.fromScale(0.74, 1)
	end
	if cycle then
		table.insert(fx.signs, { label = tl, phase = #fx.signs * 0.7 })
	end
	return p, tl
end

-- losa rectangular con huecos. holes = { {x1,z1,x2,z2}, ... }
local function slab(parent, name, x1, z1, x2, z2, top, thick, holes, color, material, extra)
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
					B(parent, name .. "_" .. n, ax, top - thick, az, bx, top, bz, color, material, extra)
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
-- Seat REAL discreto (invisible, sin colision, sin Touched): solo se usa con el ProximityPrompt "Sentarse".
-- Mira hacia -Z local, que es hacia donde mira quien se sienta.
local function addSeat(parent, name, cf)
	local st = Instance.new("Seat")
	st.Name = name
	st.Anchored = true
	st.Size = Vector3.new(2, 0.3, 2)
	st.CFrame = cf
	st.Transparency = 1
	st.CanCollide = false
	st.CanTouch = false
	st.CastShadow = false
	st.TopSurface = Enum.SurfaceType.Smooth
	st.BottomSurface = Enum.SurfaceType.Smooth
	st.Parent = parent
	return st
end

local function sofa(parent, name, x, y, z, ry, w, color, glowColor)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, ry, 0)
	local cuero = { Reflectance = 0.2 }
	P(parent, name .. "_Seat", cf * CFrame.new(0, 1, 0), Vector3.new(w, 2, 3), color, M.SmoothPlastic, cuero)
	P(parent, name .. "_Back", cf * CFrame.new(0, 3, 1.25), Vector3.new(w, 4, 0.5), color, M.SmoothPlastic, cuero)
	for s = -1, 1, 2 do
		P(parent, name .. "_Arm" .. s, cf * CFrame.new(s * (w / 2 - 0.4), 1.9, 0), Vector3.new(0.8, 1.8, 3), color, M.SmoothPlastic, cuero)
	end
	-- zocalo cromado en lugar de luz de neon, y vivo dorado en el borde del respaldo
	P(parent, name .. "_Plinth", cf * CFrame.new(0, 0.12, 0), Vector3.new(w - 0.3, 0.24, 2.7), C.chrome, M.Metal, { Reflectance = 0.6, CanCollide = false, CastShadow = false })
	P(parent, name .. "_Piping", cf * CFrame.new(0, 5.04, 1.25), Vector3.new(w, 0.1, 0.56), C.gold, M.Metal, { Reflectance = 0.5, CanCollide = false, CastShadow = false })
	-- un asiento por cada ~3 studs de sofa
	local n = math.max(1, math.floor(w / 3))
	local step = (w - 1.6) / n
	for i = 1, n do
		addSeat(parent, name .. "_Sit" .. i, cf * CFrame.new((i - (n + 1) / 2) * step, 2.2, 0.15))
	end
end

-- mesa redonda: sobremesa de marmol blanco (baja) o lacado negro (alta), pie cromado
local function roundTable(parent, name, x, y, z, radius, high, glowColor)
	local h = high and 4.2 or 2.2
	cyl(parent, name .. "_Leg", x, y + h / 2, z, h, 0.7, C.chrome, M.Metal, { Reflectance = 0.5 })
	if high then
		cyl(parent, name .. "_Top", x, y + h + 0.15, z, 0.3, radius * 2, C.black, M.SmoothPlastic, LACQUER)
	else
		cyl(parent, name .. "_Top", x, y + h + 0.15, z, 0.3, radius * 2, C.ivory, M.Marble, MARBLE_W)
	end
	cyl(parent, name .. "_Foot", x, y + 0.1, z, 0.2, radius * 1.2, C.black, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.35 })
end

local function stool(parent, name, x, y, z, ry)
	cyl(parent, name .. "_Post", x, y + 1.2, z, 2.4, 0.5, C.chrome, M.Metal, { Reflectance = 0.5 })
	cyl(parent, name .. "_Seat", x, y + 2.6, z, 0.6, 2, C.velvet, M.SmoothPlastic, LACQUER)
	addSeat(parent, name .. "_Sit", CFrame.new(x, y + 3.05, z) * CFrame.Angles(0, ry or 0, 0))
end

-- cabina de DJ mirando al sur (+Z). cx, y = suelo, z = mesa
local function djDeck(parent, name, cx, y, z, glowColor)
	B(parent, name .. "_Table", cx - 6, y, z - 1, cx + 6, y + 3.5, z + 1, C.black, M.SmoothPlastic, LACQUER)
	glow(parent, name .. "_TableGlow", cx - 6, y + 1, z + 1, cx + 6, y + 1.4, z + 1.1, glowColor, { cycle = true })
	for s = -1, 1, 2 do
		cyl(parent, name .. "_Deck" .. s, cx + s * 3, y + 3.7, z, 0.4, 2.6, C.dark, M.Metal)
		cyl(parent, name .. "_Disc" .. s, cx + s * 3, y + 3.95, z, 0.1, 2.2, C.chrome, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.6 })
	end
	B(parent, name .. "_Mixer", cx - 1, y + 3.5, z - 0.8, cx + 1, y + 4, z + 0.8, C.dark, M.Metal)
	B(parent, name .. "_Laptop", cx + 4.2, y + 3.5, z - 0.6, cx + 5.6, y + 3.7, z + 0.6, C.black, M.Metal)
end

local function speaker(parent, name, x, y, z, height, withSound)
	local body = B(parent, name, x - 3, y, z - 3, x + 3, y + height, z + 3, C.black, M.SmoothPlastic, LACQUER)
	local yy = y + 3
	while yy < y + height - 1 do
		cylZ(parent, name .. "_Woofer" .. yy, x, yy, z + 3, 0.4, 4, C.dark, M.Metal, { CanCollide = false })
		cylZ(parent, name .. "_Ring" .. yy, x, yy, z + 3.1, 0.2, 4.6, C.gold, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.5 })
		yy += 5
	end
	if withSound then
		local s = Instance.new("Sound")
		s.Name = "ClubMusic"
		s.SoundId = "" -- lo gestiona el modulo Music (lista blanca); aqui no hay ningun id
		s.Looped = false
		s.Volume = 0
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 160
		s.Parent = body
	end
	return body
end

-- barra recta. side = lado de los clientes ("E","W","S","N")
local function barCounter(parent, name, x1, z1, x2, z2, y, side, glowColor)
	B(parent, name .. "_Body", x1, y, z1, x2, y + 4, z2, C.black, M.SmoothPlastic, LACQUER)
	B(parent, name .. "_Top", x1 - 0.4, y + 4, z1 - 0.4, x2 + 0.4, y + 4.5, z2 + 0.4, C.ivory, M.Marble, MARBLE_W)
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
local function bottleShelf(parent, name, x, y, zFrom, zTo, depth, base)
	for k = 0, 2 do
		local sy = y + (base or 3) + k * 2.6
		B(parent, name .. "_Board" .. k, x, sy, zFrom, x + depth, sy + 0.3, zTo, C.black, M.SmoothPlastic, LACQUER)
		glow(parent, name .. "_Led" .. k, x, sy - 0.15, zFrom, x + depth, sy, zTo, BOTTLES[k + 1], { cycle = true })
		if k == 1 and deps.shelfBottles then
			-- estante central: botellas 3D reales (DrinkModels), colocadas por Extras
			deps.shelfBottles(ctx, parent, name, x, sy + 0.3, zFrom, zTo, depth, k)
		else
			local z = zFrom + 1
			local n = 0
			while z < zTo - 0.5 do
				n += 1
				cyl(parent, name .. "_Bottle" .. k .. "_" .. n, x + depth / 2, sy + 1, z, 1.4, 0.6, BOTTLES[(n + k) % #BOTTLES + 1], M.Glass, { CanCollide = false, Transparency = 0.2 })
				z += 2
			end
		end
	end
end


------------------------------------------------------------------------
-- Detalle "de sala real": trusses, neon en techo, cuerdas, humo, altavoces colgados
------------------------------------------------------------------------
-- barra cilindrica entre dos puntos
local function seg(parent, name, a, b, thick, color, material, extra)
	local len = (b - a).Magnitude
	-- en segmentos casi verticales lookAt degenera con el "arriba" por defecto: usa otro eje
	local up = (math.abs(b.Y - a.Y) > 0.99 * len) and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	return P(parent, name, CFrame.lookAt((a + b) * 0.5, b, up), Vector3.new(thick, thick, len), color, material, extra or DECOR)
end

-- truss reticulado 1.2x1.2 (4 cordones + zigzag en las dos caras). y = centro
local function truss(parent, name, x1, z1, x2, z2, y)
	local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local len = alongX and math.abs(x2 - x1) or math.abs(z2 - z1)
	local function pt(t, ox, oy)
		if alongX then
			return Vector3.new(math.min(x1, x2) + t, y + oy, z1 + ox)
		end
		return Vector3.new(x1 + ox, y + oy, math.min(z1, z2) + t)
	end
	for _, ox in { -0.6, 0.6 } do
		for _, oy in { -0.6, 0.6 } do
			seg(parent, name .. "_Chord", pt(0, ox, oy), pt(len, ox, oy), 0.18, C.dark, M.Metal)
		end
		local n = math.floor(len / 1.2)
		for i = 0, n - 1 do
			local lo, hi = (i % 2 == 0) and -0.6 or 0.6, (i % 2 == 0) and 0.6 or -0.6
			seg(parent, name .. "_Web", pt(i * 1.2, ox, lo), pt((i + 1) * 1.2, ox, hi), 0.1, C.dark, M.Metal)
		end
	end
end

-- foco empotrado en el techo (disco calido + luz suave)
local function downlight(parent, name, x, y, z)
	local d = cyl(parent, name, x, y, z, 0.15, 1.6, C.warmWhite, M.Neon, DECOR)
	addLight(d, C.warmWhite, 24, false, 0.8)
end

-- arte de neon rosa en el techo: polilineas con giros de 90 y diagonales
local function neonArt(parent, name, x1, z1, x2, z2, y, seed, count, color)
	local state = seed
	local function rnd()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	local function clampX(v)
		return math.clamp(v, x1 + 2, x2 - 2)
	end
	local function clampZ(v)
		return math.clamp(v, z1 + 2, z2 - 2)
	end
	local DX, DZ = { 1, 0, -1, 0 }, { 0, 1, 0, -1 }
	for _ = 1, count do
		local x = x1 + 6 + rnd() * (x2 - x1 - 12)
		local z = z1 + 6 + rnd() * (z2 - z1 - 12)
		local dir = math.floor(rnd() * 4)
		for step = 1, 8 do
			local len = 4 + math.floor(rnd() * 9)
			local nx, nz = clampX(x + DX[dir + 1] * len), clampZ(z + DZ[dir + 1] * len)
			if nx ~= x or nz ~= z then
				seg(parent, name, Vector3.new(x, y, z), Vector3.new(nx, y, nz), 0.2, C.gold, M.Metal, { Reflectance = 0.5 })
				x, z = nx, nz
			end
			if step % 3 == 0 then
				local sx = (rnd() < 0.5) and 1 or -1
				local dx2, dz2 = clampX(x + sx * 5), clampZ(z + 5)
				if dx2 ~= x or dz2 ~= z then
					seg(parent, name, Vector3.new(x, y, z), Vector3.new(dx2, y, dz2), 0.2, C.gold, M.Metal, { Reflectance = 0.5 })
					x, z = dx2, dz2
				end
			end
			dir = (dir + ((rnd() < 0.5) and 1 or 3)) % 4
		end
	end
end

-- poste dorado + cuerda de terciopelo (la cuerda no colisiona)
local function ropeLine(parent, name, x1, z1, x2, z2, y, skipA, skipB)
	for idx, p in { { x1, z1 }, { x2, z2 } } do
		if not ((idx == 1 and skipA) or (idx == 2 and skipB)) then
			cyl(parent, name .. "_Post", p[1], y + 1.5, p[2], 3, 0.5, C.gold, M.Metal)
			ball(parent, name .. "_Cap", p[1], y + 3.1, p[2], 0.8, C.gold, M.Metal, DECOR)
		end
	end
	seg(parent, name .. "_Rope", Vector3.new(x1, y + 2.5, z1), Vector3.new(x2, y + 2.5, z2), 0.25, C.velvet, M.Fabric)
end

-- columna de altavoces colgados (line array), mirando al sur
local function flownArray(parent, name, x, z, yTop, count)
	for k = 0, count - 1 do
		local cf = CFrame.new(x, yTop - 1.2 - k * 1.8, z) * CFrame.Angles(math.rad(k * 2.5), 0, 0)
		P(parent, name .. "_Cab" .. k, cf, Vector3.new(3.2, 1.6, 2.6), C.black, M.Metal)
		P(parent, name .. "_Grille" .. k, cf * CFrame.new(0, 0, 1.32), Vector3.new(2.9, 1.2, 0.1), C.dark, M.Metal, DECOR)
	end
	for _, sx in { -1.4, 1.4 } do
		B(parent, name .. "_Rod", x + sx - 0.08, yTop - 0.2, z - 0.08, x + sx + 0.08, FLOOR_H, z + 0.08, C.dark, M.Metal, DECOR)
	end
end

-- humo / niebla de escenario
local function haze(parent, name, x, y, z, size)
	if not PROFILE.haze then
		return
	end
	local p = P(parent, name, CFrame.new(x, y, z), Vector3.new(1, 1, 1), C.white, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	local sm = Instance.new("Smoke")
	sm.Size = size
	sm.Opacity = 0.12
	sm.RiseVelocity = 1.5
	sm.Color = Color3.fromRGB(190, 150, 255)
	sm.Parent = p
end

-- listones de madera oscura en pared (acustico). axis "x": a lo largo de X (pared norte/sur)
local function slats(parent, name, axis, fixed, from, to, y1, y2, depthDir)
	local c = from
	while c < to do
		if axis == "z" then
			B(parent, name, fixed, y1, c, fixed + depthDir * 0.5, y2, c + 0.45, Color3.fromRGB(46, 28, 26), M.Wood, DECOR)
		else
			B(parent, name, c, y1, fixed, c + 0.45, y2, fixed + depthDir * 0.5, Color3.fromRGB(46, 28, 26), M.Wood, DECOR)
		end
		c += 1.2
	end
end

------------------------------------------------------------------------
-- Escaleras: descansos y pasamanos
------------------------------------------------------------------------
-- descanso: losa decorativa a ras del suelo con borde de neon naranja (sin colision)
local function landing(parent, name, x1, z1, x2, z2, y)
	B(parent, name .. "_Pad", x1, y, z1, x2, y + 0.06, z2, Color3.fromRGB(58, 36, 80), M.Marble, { CanCollide = false, CastShadow = false, Reflectance = 0.2 })
	glow(parent, name .. "_EdgeN", x1, y, z1, x2, y + 0.09, z1 + 0.15, C.orange)
	glow(parent, name .. "_EdgeS", x1, y, z2 - 0.15, x2, y + 0.09, z2, C.orange)
	glow(parent, name .. "_EdgeW", x1, y, z1, x1 + 0.15, y + 0.09, z2, C.orange)
	glow(parent, name .. "_EdgeE", x2 - 0.15, y, z1, x2, y + 0.09, z2, C.orange)
end

-- pasamanos de neon sobre postes que apoyan en los peldanos (sin colision)
local function stairRail(parent, name, xs, baseY, zStart, dir)
	local prev
	for _, i in { 0, 5, 10, 15, 20 } do
		local zc = zStart + dir * (2 * i + 1)
		local top = baseY + i + 1
		B(parent, name .. "_Post" .. i, xs - 0.1, top, zc - 0.1, xs + 0.1, top + 3, zc + 0.1, C.dark, M.Metal, DECOR)
		local tip = Vector3.new(xs, top + 3, zc)
		if prev then
			seg(parent, name .. "_Rail" .. i, prev, tip, 0.16, C.chrome, M.Metal, { Reflectance = 0.5 })
		end
		prev = tip
	end
end

------------------------------------------------------------------------
-- Cristaleria del bar: vasos de cristal con base, borde, liquido, hielo y pajilla
------------------------------------------------------------------------
local LIQUIDS = {
	orange = Color3.fromRGB(226, 146, 58), -- ambar
	purple = Color3.fromRGB(120, 40, 70), -- burdeos
	green = Color3.fromRGB(168, 200, 150), -- menta
	pink = Color3.fromRGB(232, 184, 170), -- rosado
	cyan = Color3.fromRGB(200, 224, 240), -- hielo
}
local GLASS_TINT = Color3.fromRGB(205, 232, 255)
local ICE_COLOR = Color3.fromRGB(225, 245, 255)
local GLASS_KINDS = {
	tumbler = { d = 1.7, h = 1.7, fill = 0.62, ice = 2 },
	highball = { d = 1.3, h = 2.8, fill = 0.7, ice = 2 },
	shot = { d = 0.8, h = 1.0, fill = 0.75, ice = 0 },
}
local ICE_OFFSETS = { { -0.25, 0.12, 0.15 }, { 0.3, 0.02, -0.1 } }

local function lighten(c, a)
	return Color3.new(c.R + (1 - c.R) * a, c.G + (1 - c.G) * a, c.B + (1 - c.B) * a)
end

local function glassProps(transparency, reflectance)
	return { CanCollide = false, CastShadow = false, Transparency = transparency, Reflectance = reflectance }
end

-- copa de coctel: base, tallo y copa escalonada en 3 niveles con liquido y borde
local function martini(parent, name, x, y, z, liquid)
	cyl(parent, name .. "_Base", x, y + 0.05, z, 0.1, 1.5, GLASS_TINT, M.Glass, glassProps(0.35, 0.2))
	cyl(parent, name .. "_Stem", x, y + 0.7, z, 1.2, 0.16, GLASS_TINT, M.Glass, glassProps(0.45, 0.2))
	local tiers = { { 1.3, 0.7 }, { 1.6, 1.2 }, { 1.9, 1.7 } } -- {altura de inicio, diametro}
	for i, t in tiers do
		cyl(parent, name .. "_Wall" .. i, x, y + t[1] + 0.15, z, 0.3, t[2], GLASS_TINT, M.Glass, glassProps(0.72, 0.1))
	end
	cyl(parent, name .. "_Liquid1", x, y + 1.45, z, 0.3, 0.52, liquid, M.SmoothPlastic, glassProps(0.15, 0.1))
	cyl(parent, name .. "_Liquid2", x, y + 1.75, z, 0.3, 1.0, liquid, M.SmoothPlastic, glassProps(0.15, 0.1))
	cyl(parent, name .. "_Liquid3", x, y + 1.975, z, 0.15, 1.45, liquid, M.SmoothPlastic, glassProps(0.15, 0.1))
	cyl(parent, name .. "_LiquidTop", x, y + 2.065, z, 0.05, 1.45, lighten(liquid, 0.4), M.Neon, glassProps(0.45, 0))
	cyl(parent, name .. "_Rim", x, y + 2.225, z, 0.05, 1.8, C.white, M.Glass, glassProps(0.4, 0.3))
end

-- y = superficie donde apoya (la barra). opts: coaster, glow, straw (Color3), garnish
local function glassware(parent, name, x, y, z, kind, liquid, opts)
	opts = opts or {}
	if opts.coaster then
		cyl(parent, name .. "_Coaster", x, y + 0.04, z, 0.08, 2.3, C.black, M.Marble, DECOR)
		cyl(parent, name .. "_CoasterGlow", x, y + 0.025, z, 0.05, 2.5, opts.glow or C.orange, M.Neon, DECOR)
		y += 0.08
	end
	if kind == "martini" then
		martini(parent, name, x, y, z, liquid)
		return
	end
	local k = GLASS_KINDS[kind]
	local d, h, baseH = k.d, k.h, 0.22
	local lh = (h - baseH) * k.fill
	cyl(parent, name .. "_Base", x, y + baseH / 2, z, baseH, d, GLASS_TINT, M.Glass, glassProps(0.35, 0.2))
	cyl(parent, name .. "_Wall", x, y + baseH + (h - baseH) / 2, z, h - baseH, d, GLASS_TINT, M.Glass, glassProps(0.78, 0.1))
	cyl(parent, name .. "_Liquid", x, y + baseH + lh / 2, z, lh, d - 0.24, liquid, M.SmoothPlastic, glassProps(0.15, 0.1))
	cyl(parent, name .. "_LiquidTop", x, y + baseH + lh + 0.02, z, 0.05, d - 0.24, lighten(liquid, 0.4), M.Neon, glassProps(0.45, 0))
	cyl(parent, name .. "_Rim", x, y + h + 0.025, z, 0.05, d + 0.1, C.white, M.Glass, glassProps(0.4, 0.3))
	local s = d / 1.7
	for n = 1, k.ice do
		local o = ICE_OFFSETS[n]
		P(
			parent,
			name .. "_Ice" .. n,
			CFrame.new(x + o[1] * s, y + baseH + lh - 0.08 + o[2], z + o[3] * s) * CFrame.Angles(0.4 * n, 0.7 * n, 0.2 * n),
			Vector3.new(0.4, 0.4, 0.4),
			ICE_COLOR,
			M.Glass,
			glassProps(0.3, 0.3)
		)
	end
	if opts.straw then
		seg(
			parent,
			name .. "_Straw",
			Vector3.new(x + 0.2 * s, y + baseH + 0.15, z + 0.1 * s),
			Vector3.new(x + 0.5 * s, y + h + 1.1, z - 0.1 * s),
			0.1,
			opts.straw,
			M.SmoothPlastic
		)
	end
	if opts.garnish then
		cylZ(parent, name .. "_Slice", x + d / 2, y + h - 0.15, z, 0.07, 0.95, C.orange, M.Neon, DECOR)
	end
end

-- bandeja con 3 chupitos de colores. alongZ = true si la barra corre a lo largo de Z
local function shotTray(parent, name, x, y, z, alongZ)
	local size = alongZ and Vector3.new(1.5, 0.12, 3.8) or Vector3.new(3.8, 0.12, 1.5)
	P(parent, name .. "_Tray", CFrame.new(x, y + 0.06, z), size, C.black, M.Metal, DECOR)
	P(parent, name .. "_TrayGlow", CFrame.new(x, y + 0.02, z), size + Vector3.new(0.2, 0, 0.2), C.orange, M.Neon, DECOR)
	local cols = { LIQUIDS.orange, LIQUIDS.purple, LIQUIDS.green }
	for i = 1, 3 do
		local o = (i - 2) * 1.2
		local sx, sz = x, z
		if alongZ then
			sz = z + o
		else
			sx = x + o
		end
		glassware(parent, name .. "_Shot" .. i, sx, y + 0.12, sz, "shot", cols[i])
	end
end

------------------------------------------------------------------------
-- Halloween
------------------------------------------------------------------------
local FLICKER = { 0.8, 1.0, 1.25 }

local function flameLight(part, color, range, brightness)
	local l = addLight(part, color, range, false, brightness)
	table.insert(fx.flames, { light = l, base = l.Brightness, phase = #fx.flames * 1.3 })
	return l
end

local function pball(parent, name, cf, d, color, material, extra)
	return P(parent, name, cf, Vector3.new(d, d, d), color, material, withShape(Enum.PartType.Ball, extra))
end

-- calabaza con cara iluminada. y = apoyo, ry = giro (el frente es -Z local). s = escala
-- opts: mini (sin lobulos), light (luz interior parpadeante)
local function pumpkin(parent, name, x, y, z, ry, s, opts)
	opts = opts or {}
	local cf = CFrame.new(x, y + 1.0 * s, z) * CFrame.Angles(0, ry, 0)
	local body = pball(parent, name .. "_Body", cf, 2.2 * s, C.pumpkin, M.SmoothPlastic, DECOR)
	if not opts.mini then
		for sx = -1, 1, 2 do
			pball(parent, name .. "_Lobe" .. sx, cf * CFrame.new(sx * 0.75 * s, -0.05 * s, 0.1 * s), 1.9 * s, C.pumpkin, M.SmoothPlastic, DECOR)
		end
	end
	cyl(parent, name .. "_Stem", x, y + 2.3 * s, z, 0.5 * s, 0.4 * s, C.stem, M.Wood, DECOR)
	-- cara: ojos triangulares y boca
	local face = { CanCollide = false, CastShadow = false, Wedge = true }
	P(parent, name .. "_EyeL", cf * CFrame.new(-0.5 * s, 0.3 * s, -0.93 * s), Vector3.new(0.45 * s, 0.45 * s, 0.14 * s), C.flame, M.Neon, face)
	P(parent, name .. "_EyeR", cf * CFrame.new(0.5 * s, 0.3 * s, -0.93 * s) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.45 * s, 0.45 * s, 0.14 * s), C.flame, M.Neon, face)
	P(parent, name .. "_Mouth", cf * CFrame.new(0, -0.4 * s, -1.0 * s), Vector3.new(1.1 * s, 0.2 * s, 0.14 * s), C.flame, M.Neon, DECOR)
	if not opts.mini then
		for sx = -1, 1, 2 do
			P(parent, name .. "_Smile" .. sx, cf * CFrame.new(sx * 0.55 * s, -0.2 * s, -0.93 * s) * CFrame.Angles(0, 0, sx * math.rad(30)), Vector3.new(0.4 * s, 0.18 * s, 0.14 * s), C.flame, M.Neon, DECOR)
		end
	end
	if opts.light then
		flameLight(body, C.orange, opts.range or 16, 1.3)
	end
	return body
end

-- racimo de 3 velas con llama de neon. light = true anade una luz calida parpadeante
local function candleCluster(parent, name, x, y, z, light)
	cyl(parent, name .. "_Dish", x, y + 0.05, z, 0.1, 2.0, C.black, M.Metal, DECOR)
	local spec = { { 0, 0, 1.0 }, { 0.55, 0.25, 0.65 }, { -0.45, 0.4, 1.3 } }
	for i, c in spec do
		cyl(parent, name .. "_Candle" .. i, x + c[1], y + c[3] / 2, z + c[2], c[3], 0.5, C.candle, M.SmoothPlastic, DECOR)
		local flame = pball(parent, name .. "_Flame" .. i, CFrame.new(x + c[1], y + c[3] + 0.12, z + c[2]), 0.24, C.flame, M.Neon, DECOR)
		if light and i == 1 then
			flameLight(flame, C.fire, 14, 1.0)
		end
	end
end

-- telarana en un cuarto de abanico sobre la pared. a = a lo largo del techo, b = hacia abajo
local WEB = { CanCollide = false, CastShadow = false, Transparency = 0.35 }
local function cobweb(parent, name, corner, a, b, size)
	local dirs = {}
	for r = 0, 3 do
		local ang = (r / 3) * math.pi / 2
		dirs[r + 1] = a * math.cos(ang) + b * math.sin(ang)
		seg(parent, name .. "_R" .. r, corner, corner + dirs[r + 1] * size, 0.06, C.web, M.SmoothPlastic, WEB)
	end
	for ring, f in { 0.45, 0.8 } do
		for r = 1, 3 do
			seg(parent, name .. "_C" .. ring .. r, corner + dirs[r] * (size * f), corner + dirs[r + 1] * (size * f), 0.05, C.web, M.SmoothPlastic, WEB)
		end
	end
end

-- murcielago: cuerpo, 4 tramos de ala y ojos. cf = pose (el frente es -Z; alas en el plano XY)
local function bat(parent, name, cf)
	local dark = Color3.fromRGB(16, 12, 22)
	pball(parent, name .. "_Body", cf, 0.75, dark, M.SmoothPlastic, DECOR)
	for s = -1, 1, 2 do
		P(parent, name .. "_WingIn" .. s, cf * CFrame.new(s * 1.0, 0.1, 0) * CFrame.Angles(0, 0, s * 0.25), Vector3.new(1.5, 0.8, 0.08), dark, M.SmoothPlastic, DECOR)
		P(parent, name .. "_WingOut" .. s, cf * CFrame.new(s * 2.1, 0.45, 0) * CFrame.Angles(0, 0, s * 0.6), Vector3.new(1.3, 0.6, 0.08), dark, M.SmoothPlastic, DECOR)
		pball(parent, name .. "_Eye" .. s, cf * CFrame.new(s * 0.15, 0.1, -0.33), 0.1, C.orange, M.Neon, DECOR)
	end
end

-- murcielago pegado a una pared. normal = hacia donde mira (saliendo de la pared)
local function wallBat(parent, name, x, y, z, nx, nz)
	local pos = Vector3.new(x, y, z)
	bat(parent, name, CFrame.lookAt(pos, pos + Vector3.new(nx, 0, nz)))
end

-- murcielago colgado de un hilo desde el techo. face = hacia donde mira
local function hangBat(parent, name, x, y, z, ceilY, fx_, fz)
	B(parent, name .. "_Thread", x - 0.03, y + 0.3, z - 0.03, x + 0.03, ceilY, z + 0.03, C.black, M.SmoothPlastic, DECOR)
	local pos = Vector3.new(x, y, z)
	bat(parent, name, CFrame.lookAt(pos, pos + Vector3.new(fx_, 0, fz)))
end

-- guirnalda de bombillas naranja/morado. out = desplazamiento del centro (para despegarla de la pared)
local function garland(parent, name, a, b, sag, n, out)
	local prev
	for i = 0, n do
		local t = i / n
		local w = 4 * t * (1 - t)
		local p = a + (b - a) * t + Vector3.new(0, -sag * w, 0) + (out or Vector3.new(0, 0, 0)) * w
		local col = (i % 2 == 0) and C.orange or C.purple
		pball(parent, name .. "_Bulb" .. i, CFrame.new(p), 0.45, col, M.Neon, DECOR)
		if prev then
			seg(parent, name .. "_Wire" .. i, prev, p, 0.05, C.black, M.SmoothPlastic)
		end
		prev = p
	end
end

-- caldero con liquido verde, burbujas y humo
local function cauldron(parent, name, x, y, z)
	cyl(parent, name .. "_Pot", x, y + 0.65, z, 1.3, 2.4, C.black, M.Metal, DECOR)
	cyl(parent, name .. "_Lip", x, y + 1.25, z, 0.1, 2.6, C.black, M.Metal, DECOR)
	local liquid = cyl(parent, name .. "_Liquid", x, y + 1.43, z, 0.06, 2.1, Color3.fromRGB(90, 255, 70), M.Neon, DECOR)
	for i, b in { { -0.4, 0.2, 0.35 }, { 0.3, -0.3, 0.25 }, { 0.5, 0.4, 0.2 } } do
		pball(parent, name .. "_Bubble" .. i, CFrame.new(x + b[1], y + 1.5 + b[3] / 2, z + b[2]), b[3], Color3.fromRGB(150, 255, 120), M.Neon, DECOR)
	end
	flameLight(liquid, Color3.fromRGB(90, 255, 70), 14, 1.1)
	if not PROFILE.haze then
		return
	end
	local sm = Instance.new("Smoke")
	sm.Size = 2.5
	sm.Opacity = 0.12
	sm.RiseVelocity = 2
	sm.Color = Color3.fromRGB(120, 255, 100)
	sm.Parent = liquid
end

------------------------------------------------------------------------
-- Haces de luz translucidos (laseres y conos de focos)
------------------------------------------------------------------------
local function clamp01(v)
	return math.clamp(v, 0, 1)
end

-- capas del laser: nucleo fino, capa media y halo ancho. Cada una con su transparencia y
-- su brillo; juntas dan un borde suave y se puede ver a traves del haz.
local LASER_LAYERS = {
	{ width = 0.12, trans = 0.62, emission = 0.9, mix = 0.55 },
	{ width = 0.45, trans = 0.86, emission = 0.6, mix = 0.15 },
	{ width = 1.1, trans = 0.95, emission = 0.35, mix = 0 },
}

-- crea las 3 capas entre el centro de `head` y un Attachment "punta" que se mueve cada tick
local function laserBeam(head, color)
	local a0 = Instance.new("Attachment")
	a0.Name = "LaserOrigin"
	a0.Parent = head
	local tip = Instance.new("Attachment")
	tip.Name = "LaserTip"
	tip.Parent = head
	for i, L in LASER_LAYERS do
		if i > PROFILE.laserLayers then
			break
		end
		local b = Instance.new("Beam")
		b.Name = "LaserBeam" .. i
		b.Attachment0 = a0
		b.Attachment1 = tip
		b.Color = ColorSequence.new(lighten(color, L.mix))
		local t = clamp01(L.trans + LOOK.BeamTransparency)
		-- se desvanece en el origen y en la punta; el centro es el mas visible
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, t),
			NumberSequenceKeypoint.new(0.7, math.min(1, t + 0.04)),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.Width0 = L.width * LOOK.BeamWidth
		b.Width1 = L.width * LOOK.BeamWidth * 0.6
		b.LightEmission = clamp01(L.emission * LOOK.BeamBrightness)
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = head
	end
	return tip
end

-- cono de luz suave bajo un foco: un unico Beam muy transparente que se ensancha hacia el suelo
lightShaft = function(part, color, length, w0, w1)
	local a0 = Instance.new("Attachment")
	a0.Name = "ShaftTop"
	a0.Position = Vector3.new(0, -0.5, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "ShaftBottom"
	a1.Position = Vector3.new(0, -length, 0)
	a1.Parent = part
	local b = Instance.new("Beam")
	b.Name = "LightShaft"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, clamp01(0.9 + LOOK.ShaftTransparency)),
		NumberSequenceKeypoint.new(0.55, clamp01(0.95 + LOOK.ShaftTransparency)),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Width0 = w0 * LOOK.BeamWidth
	b.Width1 = w1 * LOOK.BeamWidth
	b.LightEmission = clamp01(0.5 * LOOK.BeamBrightness)
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = part
	return b
end

------------------------------------------------------------------------
-- Identidad LA ALFOMBRA ROJA: corona dorada + serif dorada + ROJA en rojo (recreado con piezas y texto)
------------------------------------------------------------------------
local SILVER, VIOLET, NAVY = C.silver, C.violet, C.navy

-- trazo 2D del logo entre (u1,v1) y (u2,v2). zoff > 0 queda DETRAS de la cara frontal.
-- base = CFrame del logo (origen abajo-centro, frente = -Z local), S = escala
local function mbar(parent, name, base, S, u1, v1, u2, v2, thick, depth, zoff, color, material)
	local len = math.sqrt((u2 - u1) ^ 2 + (v2 - v1) ^ 2) * S
	local ang = math.atan2(v2 - v1, u2 - u1)
	return P(
		parent,
		name,
		base * CFrame.new((u1 + u2) / 2 * S, (v1 + v2) / 2 * S, zoff * S) * CFrame.Angles(0, 0, ang),
		Vector3.new(len, thick * S, depth * S),
		color,
		material,
		DECOR
	)
end

local LOGO_GOLD = Color3.fromRGB(226, 178, 86)
local LOGO_RED = Color3.fromRGB(212, 24, 42)

local function logoLabel(gui, name, text, font, color, x, y, w, h, gradient)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = color
	l.Parent = gui
	if gradient then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(196, 142, 52))
		g.Rotation = 90
		g.Parent = l
	end
	return l
end

local function logoLine(gui, name, x, y, w)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = LOGO_GOLD
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, 0.006)
	f.Parent = gui
end

-- LOGO "LA ALFOMBRA ROJA": corona dorada arriba (piezas), "LA" y "ALFOMBRA" en serif dorada,
-- "ROJA" en rojo y filetes dorados, sobre negro. Mide 50 x 42 studs a escala 1 (la placa).
-- (x,y,z) = abajo-centro; (nx,nz) = hacia donde mira. withPlate = placa negra visible.
-- Con CONFIG.LogoImageId la placa muestra esa imagen en lugar de la corona y el texto.
local function monogram(parent, name, x, y, z, nx, nz, S, withPlate)
	local base = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + nx, y, z + nz))
	local plate = P(parent, name .. "_Plate", base * CFrame.new(0, 19 * S, 0.85 * S), Vector3.new(50 * S, 42 * S, math.max(0.5 * S, 0.06)), C.black, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.12, Transparency = withPlate and 0 or 1 })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.clamp(20 / S, 20, 400)
	gui.LightInfluence = 0
	gui.Parent = plate
	if CONFIG.LogoImageId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Logo"
		img.BackgroundTransparency = 1
		img.Image = CONFIG.LogoImageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = gui
		return
	end
	-- corona: banda, contorno en zigzag de 5 puntas y 3 perlas
	mbar(parent, name .. "_CrownBand", base, S, -5.4, 29.4, 5.4, 29.4, 1.5, 1.2, 0, LOGO_GOLD, M.Metal)
	local pts = { { -5.4, 29.4 }, { -5.9, 35.4 }, { -2.7, 32.2 }, { 0, 37.2 }, { 2.7, 32.2 }, { 5.9, 35.4 }, { 5.4, 29.4 } }
	for i = 1, #pts - 1 do
		mbar(parent, name .. "_Crown" .. i, base, S, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.8, 1.2, 0, LOGO_GOLD, M.Metal)
	end
	for i, pt in { { -5.9, 36.2 }, { 0, 38 }, { 5.9, 36.2 } } do
		P(parent, name .. "_Pearl" .. i, base * CFrame.new(pt[1] * S, pt[2] * S, 0), Vector3.new(1.3 * S, 1.3 * S, 1.3 * S), LOGO_GOLD, M.Metal, withShape(Enum.PartType.Ball, DECOR))
	end
	logoLabel(gui, "LA", "LA", Enum.Font.Bodoni, LOGO_GOLD, 0.3, 0.255, 0.4, 0.1, true)
	logoLine(gui, "LineTop", 0.12, 0.385, 0.76)
	logoLabel(gui, "ALFOMBRA", "ALFOMBRA", Enum.Font.Bodoni, LOGO_GOLD, 0.04, 0.4, 0.92, 0.22, true)
	logoLine(gui, "LineMid", 0.12, 0.628, 0.76)
	logoLabel(gui, "ROJA", "ROJA", Enum.Font.Bodoni, LOGO_RED, 0.18, 0.64, 0.64, 0.22, false)
	logoLine(gui, "LineBottom", 0.12, 0.885, 0.76)
end

-- monograma pegado a una pared: (wx,wz) = punto de la pared, (nx,nz) = normal saliendo de ella
local function wallMonogram(parent, name, wx, y, wz, nx, nz, S)
	monogram(parent, name, wx + nx * 1.1 * S, y, wz + nz * 1.1 * S, nx, nz, S, true)
end

------------------------------------------------------------------------
-- Coches deportivos decorativos (frente = -Z local). Largo 16, ancho 7, alto <= 4.4.
-- Solo la carroceria baja (_Body) y la cabina (_Cabin) colisionan; el resto es visual.
------------------------------------------------------------------------
local CAR_PAINT = {
	red = Color3.fromRGB(190, 22, 36),
	blue = Color3.fromRGB(26, 68, 205),
	white = Color3.fromRGB(240, 240, 246),
	black = Color3.fromRGB(22, 22, 28),
}
local CAR_GLASS = Color3.fromRGB(26, 38, 56)
local CHROME = Color3.fromRGB(215, 218, 230)

local function cpart(parent, name, cf, size, color, material, extra)
	local e = { CanCollide = false, CastShadow = false }
	if extra then
		for k, v in extra do
			e[k] = v
		end
	end
	return P(parent, name, cf, size, color, material, e)
end

-- 4 ruedas: neumatico, llanta cromada y buje. track = distancia al centro, zf/zr = ejes, r = radio
local function carWheels(parent, name, cf, track, zf, zr, r)
	local shape = withShape(Enum.PartType.Cylinder)
	for _, sx in { -1, 1 } do
		for _, sz in { zf, zr } do
			local w = cf * CFrame.new(sx * track, r, sz)
			cpart(parent, name .. "_Tire", w, Vector3.new(1.3, 2 * r, 2 * r), C.black, M.SmoothPlastic, shape)
			cpart(parent, name .. "_Rim", w, Vector3.new(1.4, 1.5 * r, 1.5 * r), CHROME, M.Metal, withShape(Enum.PartType.Cylinder, { Reflectance = 0.3 }))
			cpart(parent, name .. "_Hub", w, Vector3.new(1.5, 0.5 * r, 0.5 * r), C.dark, M.Metal, shape)
		end
	end
end

-- cilindro con el eje a lo largo de Z (luces traseras redondas, escapes)
local function cylCar(parent, name, cf, length, diameter, color, material, extra)
	return cpart(parent, name, cf * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(length, diameter, diameter), color, material, withShape(Enum.PartType.Cylinder, extra))
end

-- Estilo Ferrari: deportivo central, muy bajo y ancho, capo corto, cabina adelantada,
-- parabrisas muy inclinado, tomas laterales, alerón pequeño y 4 luces traseras redondas.
local function carFerrari(parent, name, cf, color)
	local paint = { Reflectance = 0.22 }
	P(parent, name .. "_Body", cf * CFrame.new(0, 1.15, 0), Vector3.new(7, 1.3, 15.6), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Hood", cf * CFrame.new(0, 1.95, -5.0) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(6.6, 0.6, 5.6), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Windshield", cf * CFrame.new(0, 2.85, -1.7) * CFrame.Angles(math.rad(-34), 0, 0), Vector3.new(5.6, 0.16, 3.4), CAR_GLASS, M.Glass, { Transparency = 0.3, Reflectance = 0.28 })
	P(parent, name .. "_Cabin", cf * CFrame.new(0, 2.9, 0.9), Vector3.new(5.4, 1.9, 3.8), CAR_GLASS, M.Glass, { Transparency = 0.35, Reflectance = 0.2 })
	cpart(parent, name .. "_Roof", cf * CFrame.new(0, 3.85, 1.0), Vector3.new(5.2, 0.3, 3.2), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Deck", cf * CFrame.new(0, 3.15, 5.3) * CFrame.Angles(math.rad(15), 0, 0), Vector3.new(6.0, 0.4, 5.8), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Engine", cf * CFrame.new(0, 2.5, 4.3), Vector3.new(6.0, 1.2, 3.4), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Rear", cf * CFrame.new(0, 1.8, 7.6), Vector3.new(6.6, 1.4, 0.8), color, M.SmoothPlastic, paint)
	for _, sx in { -1, 1 } do
		cpart(parent, name .. "_Intake", cf * CFrame.new(sx * 3.5, 2.2, 3.6), Vector3.new(0.5, 1.0, 3.4), C.black, M.SmoothPlastic)
		cpart(parent, name .. "_FenderF", cf * CFrame.new(sx * 3.6, 1.9, -4.8), Vector3.new(0.7, 0.9, 3.6), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_FenderR", cf * CFrame.new(sx * 3.7, 2.0, 4.8), Vector3.new(0.8, 1.1, 3.8), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Mirror", cf * CFrame.new(sx * 2.95, 3.0, -0.6), Vector3.new(0.5, 0.45, 0.7), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Headlight", cf * CFrame.new(sx * 2.2, 1.95, -7.85) * CFrame.Angles(0, sx * 0.2, 0), Vector3.new(1.6, 0.34, 0.2), C.warmWhite, M.Neon)
		cpart(parent, name .. "_FrontIntake", cf * CFrame.new(sx * 2.0, 1.0, -7.9), Vector3.new(1.8, 0.5, 0.2), C.black, M.SmoothPlastic)
		for k, tx in { 2.0, 3.0 } do
			cylCar(parent, name .. "_Taillight" .. k, cf * CFrame.new(sx * tx, 2.05, 7.95), 0.16, 0.95, Color3.fromRGB(255, 40, 40), M.Neon)
		end
		cpart(parent, name .. "_SpoilerPost", cf * CFrame.new(sx * 2.0, 2.7, 7.7), Vector3.new(0.2, 0.9, 0.5), C.black, M.Metal)
		cylCar(parent, name .. "_Exhaust", cf * CFrame.new(sx * 1.2, 0.95, 8.15), 0.8, 0.7, CHROME, M.Metal, { Reflectance = 0.3 })
	end
	cpart(parent, name .. "_Spoiler", cf * CFrame.new(0, 3.1, 7.9), Vector3.new(5.6, 0.14, 1.2), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Splitter", cf * CFrame.new(0, 0.55, -7.6), Vector3.new(6.8, 0.2, 1.4), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Diffuser", cf * CFrame.new(0, 0.7, 7.4), Vector3.new(5.2, 0.6, 1.4), C.black, M.SmoothPlastic)
	carWheels(parent, name, cf, 2.9, -4.9, 4.9, 1.3)
end

-- Estilo Ford GT: cabina en gota muy estrecha, grandes caderas traseras, arbotantes laterales
-- (flying buttresses), tomas en tunel y dos faros traseros circulares. stripes = bandas blancas.
local function carGT(parent, name, cf, color, stripes)
	local paint = { Reflectance = 0.22 }
	P(parent, name .. "_Body", cf * CFrame.new(0, 1.1, 0), Vector3.new(7.2, 1.2, 15.8), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Hood", cf * CFrame.new(0, 1.8, -5.4) * CFrame.Angles(math.rad(-6), 0, 0), Vector3.new(6.0, 0.5, 5.0), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Windshield", cf * CFrame.new(0, 2.75, -2.2) * CFrame.Angles(math.rad(-33), 0, 0), Vector3.new(4.4, 0.16, 3.6), CAR_GLASS, M.Glass, { Transparency = 0.3, Reflectance = 0.28 })
	P(parent, name .. "_Cabin", cf * CFrame.new(0, 2.8, 0.4), Vector3.new(3.9, 1.7, 3.4), CAR_GLASS, M.Glass, { Transparency = 0.35, Reflectance = 0.2 })
	cpart(parent, name .. "_Roof", cf * CFrame.new(0, 3.75, -0.2), Vector3.new(3.4, 0.3, 2.0), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_RearGlass", cf * CFrame.new(0, 3.0, 3.0) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(3.8, 0.16, 4.4), CAR_GLASS, M.Glass, { Transparency = 0.3, Reflectance = 0.28 })
	cpart(parent, name .. "_Tail", cf * CFrame.new(0, 2.1, 6.6), Vector3.new(5.4, 0.8, 3.0), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Engine", cf * CFrame.new(0, 2.05, 4.0), Vector3.new(4.6, 0.9, 3.0), C.black, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		cpart(parent, name .. "_FenderF", cf * CFrame.new(sx * 3.4, 1.9, -4.5), Vector3.new(0.9, 0.9, 4.0), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Haunch", cf * CFrame.new(sx * 3.2, 2.1, 3.2), Vector3.new(1.3, 1.5, 5.4), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Buttress", cf * CFrame.new(sx * 2.4, 2.85, 3.6) * CFrame.Angles(math.rad(18), 0, 0), Vector3.new(0.9, 0.35, 4.8), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Scoop", cf * CFrame.new(sx * 3.55, 2.1, 1.0), Vector3.new(0.6, 1.2, 2.8), C.black, M.SmoothPlastic)
		cpart(parent, name .. "_Mirror", cf * CFrame.new(sx * 2.2, 3.0, -1.0), Vector3.new(0.5, 0.45, 0.7), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Headlight", cf * CFrame.new(sx * 2.3, 1.8, -7.9) * CFrame.Angles(0, sx * 0.2, 0), Vector3.new(1.5, 0.3, 0.2), C.warmWhite, M.Neon)
		cpart(parent, name .. "_FrontIntake", cf * CFrame.new(sx * 1.9, 1.0, -7.9), Vector3.new(2.0, 0.7, 0.2), C.black, M.SmoothPlastic)
		cylCar(parent, name .. "_Taillight", cf * CFrame.new(sx * 2.3, 2.2, 8.0), 0.16, 1.2, Color3.fromRGB(255, 40, 40), M.Neon)
		cylCar(parent, name .. "_Exhaust", cf * CFrame.new(sx * 0.7, 1.2, 8.15), 0.9, 0.9, CHROME, M.Metal, { Reflectance = 0.3 })
		cpart(parent, name .. "_WingPlate", cf * CFrame.new(sx * 3.1, 3.2, 7.2), Vector3.new(0.15, 0.9, 1.4), C.black, M.SmoothPlastic)
	end
	cpart(parent, name .. "_Wing", cf * CFrame.new(0, 3.3, 7.2), Vector3.new(6.2, 0.14, 1.4), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Splitter", cf * CFrame.new(0, 0.55, -7.7), Vector3.new(6.8, 0.2, 1.4), C.black, M.SmoothPlastic)
	if stripes then
		for _, sx in { -1, 1 } do
			cpart(parent, name .. "_StripeHood", cf * CFrame.new(sx * 0.9, 2.08, -5.4) * CFrame.Angles(math.rad(-6), 0, 0), Vector3.new(0.5, 0.06, 5.0), C.white, M.SmoothPlastic)
			cpart(parent, name .. "_StripeRoof", cf * CFrame.new(sx * 0.9, 3.93, -0.2), Vector3.new(0.5, 0.06, 2.0), C.white, M.SmoothPlastic)
		end
	end
	carWheels(parent, name, cf, 2.95, -5.0, 5.0, 1.3)
end

-- Estilo Ford Mustang: capo largo con toma de aire, parabrisas inclinado, techo fastback,
-- cola corta con alerón "pato", parrilla negra y 3 barras verticales de luz trasera por lado.
local function carMustang(parent, name, cf, color, stripes)
	local paint = { Reflectance = 0.22 }
	P(parent, name .. "_Body", cf * CFrame.new(0, 1.3, 0), Vector3.new(7.0, 1.5, 16), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Hood", cf * CFrame.new(0, 2.35, -4.9) * CFrame.Angles(math.rad(-4), 0, 0), Vector3.new(6.6, 0.55, 6.2), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_HoodScoop", cf * CFrame.new(0, 2.75, -4.2), Vector3.new(1.8, 0.3, 2.6), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Windshield", cf * CFrame.new(0, 3.15, -1.1) * CFrame.Angles(math.rad(-36), 0, 0), Vector3.new(5.6, 0.16, 3.2), CAR_GLASS, M.Glass, { Transparency = 0.3, Reflectance = 0.28 })
	P(parent, name .. "_Cabin", cf * CFrame.new(0, 2.9, 1.6), Vector3.new(5.5, 1.7, 4.6), CAR_GLASS, M.Glass, { Transparency = 0.35, Reflectance = 0.2 })
	cpart(parent, name .. "_Roof", cf * CFrame.new(0, 4.0, 1.5), Vector3.new(5.4, 0.3, 3.4), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Fastback", cf * CFrame.new(0, 3.45, 4.6) * CFrame.Angles(math.rad(24), 0, 0), Vector3.new(5.2, 0.16, 3.8), CAR_GLASS, M.Glass, { Transparency = 0.3, Reflectance = 0.28 })
	cpart(parent, name .. "_Trunk", cf * CFrame.new(0, 2.5, 7.2), Vector3.new(6.4, 0.3, 1.8), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_TrunkBody", cf * CFrame.new(0, 2.2, 6.2), Vector3.new(6.2, 0.9, 3.4), color, M.SmoothPlastic, paint)
	cpart(parent, name .. "_Duckbill", cf * CFrame.new(0, 2.78, 7.85), Vector3.new(6.2, 0.12, 0.8), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Grille", cf * CFrame.new(0, 1.5, -8.0), Vector3.new(4.0, 0.9, 0.25), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_GrilleBar", cf * CFrame.new(0, 1.5, -8.14), Vector3.new(3.6, 0.1, 0.1), CHROME, M.Metal)
	for _, sx in { -1, 1 } do
		cpart(parent, name .. "_FlareF", cf * CFrame.new(sx * 3.6, 2.0, -4.9), Vector3.new(0.6, 1.0, 3.6), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_FlareR", cf * CFrame.new(sx * 3.6, 2.0, 4.9), Vector3.new(0.6, 1.0, 3.6), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Mirror", cf * CFrame.new(sx * 3.2, 3.2, -1.1), Vector3.new(0.5, 0.45, 0.7), color, M.SmoothPlastic, paint)
		cpart(parent, name .. "_Headlight", cf * CFrame.new(sx * 2.9, 1.9, -8.0), Vector3.new(1.3, 0.55, 0.2), C.warmWhite, M.Neon)
		cpart(parent, name .. "_FogLight", cf * CFrame.new(sx * 2.0, 0.85, -8.0), Vector3.new(0.8, 0.35, 0.2), C.warmWhite, M.Neon)
		for k, tx in { 1.4, 2.1, 2.8 } do
			cpart(parent, name .. "_Taillight" .. k, cf * CFrame.new(sx * tx, 2.3, 8.05), Vector3.new(0.35, 1.0, 0.14), Color3.fromRGB(255, 40, 40), M.Neon)
		end
		cylCar(parent, name .. "_Exhaust", cf * CFrame.new(sx * 2.2, 0.9, 8.15), 0.9, 0.7, CHROME, M.Metal, { Reflectance = 0.3 })
	end
	cpart(parent, name .. "_Splitter", cf * CFrame.new(0, 0.55, -7.8), Vector3.new(6.8, 0.2, 1.2), C.black, M.SmoothPlastic)
	cpart(parent, name .. "_Diffuser", cf * CFrame.new(0, 0.7, 7.5), Vector3.new(5.4, 0.6, 1.2), C.black, M.SmoothPlastic)
	if stripes then
		for _, sx in { -1, 1 } do
			cpart(parent, name .. "_StripeHood", cf * CFrame.new(sx * 1.0, 2.66, -4.9) * CFrame.Angles(math.rad(-4), 0, 0), Vector3.new(0.5, 0.06, 6.2), stripes, M.SmoothPlastic)
			cpart(parent, name .. "_StripeRoof", cf * CFrame.new(sx * 1.0, 4.17, 1.5), Vector3.new(0.5, 0.06, 3.4), stripes, M.SmoothPlastic)
		end
	end
	carWheels(parent, name, cf, 2.9, -5.0, 5.0, 1.35)
end

-- coloca un coche en (x,z) sobre el suelo y; ry = giro (0: morro hacia -Z). model = ferrari|gt|mustang
local function placeCar(parent, name, model, x, y, z, ry, paintName)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, ry, 0)
	local color = CAR_PAINT[paintName]
	if model == "ferrari" then
		carFerrari(parent, name, cf, color)
	elseif model == "gt" then
		carGT(parent, name, cf, color, paintName == "blue")
	else
		carMustang(parent, name, cf, color, (paintName == "white" or paintName == "red") and C.black or (paintName == "black" and C.white or nil))
	end
end

------------------------------------------------------------------------
-- Disposicion general (160 x 160 el edificio; todo lo demas se calcula desde estas medidas)
------------------------------------------------------------------------
local HALF, IN = 80, 78 -- lado exterior/2 y cara interior de los muros del edificio
local LAYOUT = {
	half = HALF,
	inner = IN,
	-- pista de baile (dentro del atrio de doble altura)
	dance = { x1 = -32, z1 = -56, x2 = 32, z2 = 8 },
	atrium = { x1 = -40, z1 = -58, x2 = 40, z2 = 18 },
	stage = { x1 = -34, z1 = -78, x2 = 34, z2 = -64, top = 3.3 },
	-- escaleras de 10 studs: s1 piso1->2 (este, sube al norte), s2 piso2->3 (oeste, sube al sur)
	s1 = { x1 = 68, x2 = 78, baseY = 0, zStart = 64, dir = -1, hole = { 68, 16, 78, 36 }, landIn = { 68, 64, 78, 78 }, landOut = { 68, 6, 78, 16 } },
	s2 = { x1 = -78, x2 = -68, baseY = 24, zStart = -64, dir = 1, hole = { -78, -36, -68, -16 }, landIn = { -78, -78, -68, -64 }, landOut = { -78, -16, -68, -6 } },
	pool = { 16, 26, 56, 64 },
	spawn = { 0, 56 },
}
-- mundo exterior: acera interior (hasta 96), calzada de 20 (hasta 116), acera exterior (hasta 128)
local WORLD = { x1 = -128, x2 = 128, z1 = -128, z2 = 206 }
LAYOUT.world = WORLD
local ROAD_Y = -0.3 -- superficie del asfalto (las aceras estan en y = 0)
local LOT_Y = -0.24 -- superficie del parqueadero (losa fina sobre el asfalto)
local ASPHALT = Color3.fromRGB(32, 32, 40)
local WALK = Color3.fromRGB(84, 78, 98)
local WALK2 = Color3.fromRGB(96, 92, 110)
local CURB = Color3.fromRGB(176, 172, 184)
local PAINT_W = Color3.fromRGB(235, 235, 240)
local PAINT_Y = Color3.fromRGB(255, 200, 40)
local PAINT_B = Color3.fromRGB(40, 110, 230)
local PAINT = { CanCollide = false, CastShadow = false }

-- pintura plana (0.06 de alto) sobre el asfalto, sin colision
local function paint(parent, name, x1, z1, x2, z2, color, y)
	local y0 = y or ROAD_Y
	return B(parent, name, x1, y0, z1, x2, y0 + 0.06, z2, color, M.SmoothPlastic, PAINT)
end

-- paso de peatones ELEVADO: plataforma a ras de las aceras (y = 0) con franjas.
-- along = "z": los peatones caminan en Z (calzada E-W); "x": caminan en X. len = largo del cruce.
local function crosswalk(parent, name, cx, cz, along, len)
	local n = math.floor(len / 2)
	local slab_ = Color3.fromRGB(46, 46, 56)
	if along == "z" then
		B(parent, name .. "_Slab", cx - 6, -3, cz - len / 2, cx + 6, 0, cz + len / 2, slab_, M.Asphalt)
		for k = 0, n - 1 do
			local z = cz - len / 2 + 0.55 + k * 2
			B(parent, name .. "_Stripe" .. k, cx - 5, 0, z, cx + 5, 0.06, z + 0.9, PAINT_W, M.SmoothPlastic, PAINT)
		end
	else
		B(parent, name .. "_Slab", cx - len / 2, -3, cz - 6, cx + len / 2, 0, cz + 6, slab_, M.Asphalt)
		for k = 0, n - 1 do
			local x = cx - len / 2 + 0.55 + k * 2
			B(parent, name .. "_Stripe" .. k, x, 0, cz - 5, x + 0.9, 0.06, cz + 5, PAINT_W, M.SmoothPlastic, PAINT)
		end
	end
end

-- farola: base, poste, brazo corto, cabeza de neon calido y, opcionalmente, una luz real (range)
local function streetLamp(parent, name, x, y, z, range)
	cyl(parent, name .. "_Base", x, y + 0.5, z, 1.0, 1.8, C.dark, M.Metal)
	cyl(parent, name .. "_Pole", x, y + 7.6, z, 13.2, 0.5, C.dark, M.Metal)
	local head = B(parent, name .. "_Head", x - 1.1, y + 14.2, z - 1.1, x + 1.1, y + 14.7, z + 1.1, C.warmWhite, M.Neon, DECOR)
	B(parent, name .. "_Cap", x - 1.3, y + 14.7, z - 1.3, x + 1.3, y + 15.0, z + 1.3, C.dark, M.Metal, DECOR)
	B(parent, name .. "_Neck", x - 0.4, y + 14.0, z - 0.4, x + 0.4, y + 14.2, z + 0.4, C.dark, M.Metal, DECOR)
	if range then
		addLight(head, C.warmWhite, range, false, 0.9)
	end
end

-- senal: poste detras de la placa. (dx,dz) = hacia donde mira. height = altura del centro de la placa
local function signPost(parent, name, x, y, z, height, w, h, dx, dz, text, color)
	cyl(parent, name .. "_Post", x - dx * 0.45, y + height / 2, z - dz * 0.45, height, 0.4, C.dark, M.Metal)
	sign(parent, name .. "_Plate", x, y + height, z, w, h, dx, dz, text, color, false)
end

-- arbol: tronco + copa de 3 esferas. y = suelo
local function tree(parent, name, x, y, z, s)
	cyl(parent, name .. "_Trunk", x, y + 3 * s, z, 6 * s, 1.0 * s, C.wood, M.Wood)
	ball(parent, name .. "_Crown1", x, y + 8 * s, z, 8 * s, Color3.fromRGB(34, 120, 62), M.Grass, DECOR)
	ball(parent, name .. "_Crown2", x + 1.6 * s, y + 6.6 * s, z + 1.2 * s, 5.6 * s, Color3.fromRGB(44, 138, 70), M.Grass, DECOR)
	ball(parent, name .. "_Crown3", x - 1.6 * s, y + 7 * s, z - 1.2 * s, 5.6 * s, Color3.fromRGB(28, 104, 56), M.Grass, DECOR)
end

local function buildWorld()
	local s, pk, pr = folders.Streets, folders.Parking, folders.Perimeter

	-- terreno: un unico bloque que cubre calles, aceras y parqueadero (sin huecos al vacio)
	B(s, "Ground", -130, -4, -130, 130, ROAD_Y, 208, ASPHALT, M.Asphalt)

	-- aceras interiores (rodean el club) y exteriores (junto al muro). Todas en y = 0.
	B(s, "SidewalkIn_N", -96, -3, -96, 96, 0, -80, WALK, M.Pavement)
	B(s, "SidewalkIn_S", -96, -3, 80, 96, 0, 96, WALK, M.Pavement)
	B(s, "SidewalkIn_W", -96, -3, -80, -80, 0, 80, WALK, M.Pavement)
	B(s, "SidewalkIn_E", 80, -3, -80, 96, 0, 80, WALK, M.Pavement)
	B(s, "SidewalkOut_N", -128, -3, -128, 128, 0, -116, WALK, M.Pavement)
	B(s, "SidewalkOut_W", -128, -3, -116, -116, 0, 116, WALK, M.Pavement)
	B(s, "SidewalkOut_E", 116, -3, -116, 128, 0, 116, WALK, M.Pavement)
	-- acera sur partida por las dos entradas de vehiculos (x +-102..120), que quedan a ras del asfalto
	B(s, "SidewalkOut_S1", -128, -3, 116, -120, 0, 128, WALK, M.Pavement)
	B(s, "SidewalkOut_S2", -102, -3, 116, 102, 0, 128, WALK, M.Pavement)
	B(s, "SidewalkOut_S3", 120, -3, 116, 128, 0, 128, WALK, M.Pavement)
	-- plaza de granito frente a la puerta (baldosa decorativa a ras)
	B(s, "PlazaInlay", -30, -3, 82, 30, 0.04, 94, Color3.fromRGB(70, 64, 90), M.Granite)

	-- bordillos (franja clara de 0.5 en el borde de cada acera); abiertos en los pasos de peatones
	local function curb(name, x1, z1, x2, z2)
		B(s, name, x1, -3, z1, x2, 0.08, z2, CURB, M.Concrete)
	end
	curb("CurbIn_N1", -96, -96, -6, -95.5)
	curb("CurbIn_N2", 6, -96, 96, -95.5)
	curb("CurbIn_S1", -96, 95.5, -6, 96)
	curb("CurbIn_S2", 6, 95.5, 96, 96)
	curb("CurbIn_W1", -96, -80, -95.5, -6)
	curb("CurbIn_W2", -96, 6, -95.5, 80)
	curb("CurbIn_E1", 95.5, -80, 96, -6)
	curb("CurbIn_E2", 95.5, 6, 96, 80)
	curb("CurbOut_N1", -128, -116.5, -6, -116)
	curb("CurbOut_N2", 6, -116.5, 128, -116)
	curb("CurbOut_W1", -116.5, -116, -116, -6)
	curb("CurbOut_W2", -116.5, 6, -116, 116)
	curb("CurbOut_E1", 116, -116, 116.5, -6)
	curb("CurbOut_E2", 116, 6, 116.5, 116)
	curb("CurbOut_S1", -128, 116, -120, 116.5)
	curb("CurbOut_S2", -102, 116, -6, 116.5)
	curb("CurbOut_S3", 6, 116, 102, 116.5)
	curb("CurbOut_S4", 120, 116, 128, 116.5)

	-- pasos de peatones elevados (a ras de aceras): sur (frente a la puerta), norte, oeste y este
	crosswalk(s, "CrosswalkS", 0, 106, "z", 20)
	crosswalk(s, "CrosswalkN", 0, -106, "z", 20)
	crosswalk(s, "CrosswalkW", -106, 0, "x", 20)
	crosswalk(s, "CrosswalkE", 106, 0, "x", 20)

	-- lineas de detencion (una por sentido y paso)
	paint(s, "StopLine_S1", -8, 106.6, -7.4, 115.4, PAINT_W)
	paint(s, "StopLine_S2", 7.4, 96.6, 8, 105.4, PAINT_W)
	paint(s, "StopLine_N1", -8, -105.4, -7.4, -96.6, PAINT_W)
	paint(s, "StopLine_N2", 7.4, -115.4, 8, -106.6, PAINT_W)
	paint(s, "StopLine_W1", -115.4, -8, -106.6, -7.4, PAINT_W)
	paint(s, "StopLine_W2", -105.4, 7.4, -96.6, 8, PAINT_W)
	paint(s, "StopLine_E1", 96.6, -8, 105.4, -7.4, PAINT_W)
	paint(s, "StopLine_E2", 106.6, 7.4, 115.4, 8, PAINT_W)

	-- lineas de borde (blancas continuas) y eje central (amarillo discontinuo)
	paint(s, "EdgeLine_S_in", -116, 96.6, 116, 96.9, PAINT_W)
	paint(s, "EdgeLine_S_out", -102, 115.1, 102, 115.4, PAINT_W)
	paint(s, "EdgeLine_N_out", -116, -115.4, 116, -115.1, PAINT_W)
	paint(s, "EdgeLine_N_in", -116, -96.9, 116, -96.6, PAINT_W)
	paint(s, "EdgeLine_W_out", -115.4, -96, -115.1, 96, PAINT_W)
	paint(s, "EdgeLine_W_in", -96.9, -96, -96.6, 96, PAINT_W)
	paint(s, "EdgeLine_E_in", 96.6, -96, 96.9, 96, PAINT_W)
	paint(s, "EdgeLine_E_out", 115.1, -96, 115.4, 96, PAINT_W)
	local function dashes(name, along, fixed, from, to, y)
		local c = from
		while c < to do
			if not (c + 4 > -9 and c < 9) then
				if along == "x" then
					paint(s, name, c, fixed - 0.15, c + 4, fixed + 0.15, PAINT_Y, y)
				else
					paint(s, name, fixed - 0.15, c, fixed + 0.15, c + 4, PAINT_Y, y)
				end
			end
			c += 8
		end
	end
	dashes("Dash_S", "x", 106, -112, 112)
	dashes("Dash_N", "x", -106, -112, 112)
	dashes("Dash_W", "z", -106, -92, 92)
	dashes("Dash_E", "z", 106, -92, 92)

	------------------------------------------------------------------
	-- Parqueadero (Z 128..206): 2 filas de 18 plazas de 10 x 20 + calle interior de 28
	-- (plaza segun coche real ~7 x 16 studs: holgura de 1.5 a cada lado y 4 de fondo)
	------------------------------------------------------------------
	B(pk, "LotPad", -128, ROAD_Y, 128, 128, LOT_Y, 206, Color3.fromRGB(42, 40, 52), M.Asphalt)
	-- bordillo del lado de la acera (abierto en el paso peatonal central y en las 2 entradas)
	for i, r in { { -128, -120 }, { -102, -4 }, { 4, 102 }, { 120, 128 } } do
		B(pk, "LotCurb" .. i, r[1], -3, 127.5, r[2], 0.08, 128, CURB, M.Concrete)
	end
	-- camino peatonal central (a ras de las aceras) y paso elevado sobre la calle interior
	B(pk, "LotWalk1", -4, -3, 128, 4, 0, 148, WALK2, M.Pavement)
	B(pk, "LotWalk2", -4, -3, 176, 4, 0, 196, WALK2, M.Pavement)
	crosswalk(pk, "LotCross", 0, 162, "z", 28)

	-- plazas: lineas divisorias, linea frontal y topes de rueda, para las dos filas
	local rows = { { z1 = 128, z2 = 148, front = 148, stopZ = 128.6 }, { z1 = 176, z2 = 196, front = 176, stopZ = 195.4 } }
	for r, row in rows do
		for k = 0, 9 do
			local xl, xr = -98 + 10 * k, 8 + 10 * k
			paint(pk, "SlotLine", xl - 0.15, row.z1, xl + 0.15, row.z2, PAINT_W, LOT_Y)
			paint(pk, "SlotLine", xr - 0.15, row.z1, xr + 0.15, row.z2, PAINT_W, LOT_Y)
		end
		paint(pk, "SlotFront", -98, row.front - 0.15, -8, row.front + 0.15, PAINT_W, LOT_Y)
		paint(pk, "SlotFront", 8, row.front - 0.15, 98, row.front + 0.15, PAINT_W, LOT_Y)
		for k = 0, 8 do
			for _, xc in { -93 + 10 * k, 13 + 10 * k } do
				B(pk, "WheelStop", xc - 2.2, LOT_Y, row.stopZ - 0.3, xc + 2.2, LOT_Y + 0.5, row.stopZ + 0.3, CURB, M.Concrete)
			end
		end
	end
	dashes("LotDash", "x", 162, -118, 118, LOT_Y)
	-- flechas de sentido sobre la calle interior (2 por carril)
	for _, ax in { -70, 70 } do
		paint(pk, "LotArrow", ax - 3, 155.8, ax + 3, 156.2, PAINT_W, LOT_Y)
		paint(pk, "LotArrowHead", ax + 2.4, 154.6, ax + 3.0, 157.4, PAINT_W, LOT_Y)
		paint(pk, "LotArrow2", ax - 3, 167.8, ax + 3, 168.2, PAINT_W, LOT_Y)
		paint(pk, "LotArrow2Head", ax - 3.0, 166.6, ax - 2.4, 169.4, PAINT_W, LOT_Y)
	end

	-- plazas accesibles (las mas cercanas al camino peatonal), pintadas de azul y senalizadas
	paint(pk, "AccessL", -17, 129, -9, 147, PAINT_B, LOT_Y)
	paint(pk, "AccessR", 9, 129, 17, 147, PAINT_B, LOT_Y)
	signPost(pk, "AccessSignL", -18, LOT_Y, 129.5, 8, 7, 1.7, 0, 1, "ACCESIBLE", C.cyan)
	signPost(pk, "AccessSignR", 18, LOT_Y, 129.5, 8, 7, 1.7, 0, 1, "ACCESIBLE", C.cyan)

	-- coches deportivos aparcados: 20 en 36 plazas (las accesibles siempre libres).
	-- fila norte (morro hacia el norte) y fila sur (morro hacia el sur)
	local models = { "ferrari", "gt", "mustang" }
	local paints = { "red", "blue", "white", "black" }
	local carSlots = {
		{ 138, 0, { -93, -83, -63, -53, -33 } },
		{ 138, 0, { 33, 53, 63, 83, 93 } },
		{ 186, math.pi, { -93, -73, -63, -43, -23 } },
		{ 186, math.pi, { 13, 33, 53, 73, 93 } },
	}
	local n = 0
	for _, g in carSlots do
		for _, xc in g[3] do
			n += 1
			placeCar(pk, "Car" .. n, models[(n - 1) % 3 + 1], xc, LOT_Y, g[1], g[2], paints[(n * 3 - 1) % 4 + 1])
		end
	end

	-- entrada (este) y salida (oeste) de vehiculos: portico con cartel por ambos lados
	for _, g in { { 111, "ENTRADA", Color3.fromRGB(110, 235, 70) }, { -111, "SALIDA", Color3.fromRGB(255, 80, 80) } } do
		local gx = g[1]
		for _, px in { gx - 10.5, gx + 10.5 } do
			cyl(pk, "GatePost", px, 7, 122, 14, 0.7, C.dark, M.Metal)
		end
		B(pk, "GateBeam", gx - 11, 14, 121.7, gx + 11, 14.7, 122.3, C.dark, M.Metal)
		for _, hx in { gx - 4.5, gx + 4.5 } do
			B(pk, "GateHanger", hx - 0.1, 13, 121.9, hx + 0.1, 14, 122.1, C.dark, M.Metal, DECOR)
		end
		sign(pk, "GateSignN", gx, 11.5, 121.65, 12, 3.4, 0, -1, g[2], g[3], false)
		sign(pk, "GateSignS", gx, 11.5, 122.35, 12, 3.4, 0, 1, g[2], g[3], false)
	end
	signPost(pk, "StopSign", -99, 0, 122, 8, 3, 3, 0, 1, "PARE", Color3.fromRGB(255, 70, 70))

	-- carteles direccionales y nombres de calle
	signPost(s, "DirSignA", 22, 0, 122, 9, 9, 2.2, 0, -1, "PARQUEADERO v", C.cyan)
	signPost(s, "DirSignB", 22, 0, 122.9, 9, 9, 2.2, 0, 1, "LA ALFOMBRA ROJA ^", C.magenta)
	signPost(s, "NameSignS", -124, 0, 120, 8, 8, 2, 0, -1, "AV. ALFOMBRA", C.white)
	signPost(s, "NameSignN", 124, 0, -120, 8, 8, 2, 0, 1, "CALLE LUNA", C.white)
	signPost(s, "NameSignW", -120, 0, -60, 8, 8, 2, 1, 0, "CALLE SOL", C.white)
	signPost(s, "NameSignE", 120, 0, 60, 8, 8, 2, -1, 0, "CALLE ESTRELLA", C.white)
	-- aviso de paso de peatones a ambos lados de cada cruce, mirando al trafico
	for i, c in { { -9, 94.5, -1, 0 }, { 9, 94.5, 1, 0 }, { -9, -94.5, -1, 0 }, { 9, -94.5, 1, 0 }, { -94.5, -9, 0, -1 }, { -94.5, 9, 0, 1 }, { 94.5, -9, 0, -1 }, { 94.5, 9, 0, 1 } } do
		signPost(s, "PedSign" .. i, c[1], 0, c[2], 7, 4, 2, c[3], c[4], "PEATONES", C.cyan)
	end

	-- iluminacion: farolas con luz real (alcance 48) en el parqueadero, aceras exteriores y plaza
	for _, z in { 148, 176 } do
		for _, x in { -68, -28, 28, 68 } do
			streetLamp(pk, "LotLamp", x, LOT_Y, z, 48)
		end
	end
	for _, x in { -124, 124 } do
		for _, z in { 142, 166, 190 } do
			streetLamp(pk, "LotSideLamp", x, LOT_Y, z, 48)
		end
	end
	for _, x in { -90, -45, 0, 45, 90 } do
		streetLamp(s, "RingLamp", x, 0, -122, 48)
	end
	for _, x in { -75, -40, 40, 75 } do
		streetLamp(s, "RingLamp", x, 0, 122, 48)
	end
	for _, z in { -80, -40, 40, 80 } do
		streetLamp(s, "RingLamp", -122, 0, z, 48)
		streetLamp(s, "RingLamp", 122, 0, z, 48)
	end
	for _, x in { -60, -32, 32, 60 } do
		streetLamp(s, "PlazaLamp", x, 0, 90, 44)
	end
	for _, x in { -40, 40 } do
		streetLamp(s, "PlazaLampN", x, 0, -90, 44)
	end
	for _, z in { -40, 40 } do
		streetLamp(s, "PlazaLampW", -90, 0, z, 44)
		streetLamp(s, "PlazaLampE", 90, 0, z, 44)
	end

	-- vegetacion y paisajismo: arboles en las aceras exteriores, seto y arboles al fondo del parqueadero
	for i, x in { -112, -67, -22, 22, 67, 112 } do
		tree(s, "TreeN" .. i, x, 0, -124, 1)
	end
	for i, z in { -100, -60, -20, 20, 60, 100 } do
		tree(s, "TreeW" .. i, -124, 0, z, 1)
		tree(s, "TreeE" .. i, 124, 0, z, 1)
	end
	for i, x in { -112, -88, -64, -40, -16, 16, 40, 64, 88, 112 } do
		tree(pk, "LotTree" .. i, x, LOT_Y, 202, 1.1)
	end
	B(pk, "HedgeL", -126, LOT_Y, 198.4, -22, 1.6, 200.4, C.green, M.Grass)
	B(pk, "HedgeR", 22, LOT_Y, 198.4, 126, 1.6, 200.4, C.green, M.Grass)
	-- macizos de flores (naranja/morado, a juego con Halloween) junto al camino peatonal
	for i, fz in { 197, 197 } do
		local sx = (i == 1) and -1 or 1
		B(pk, "FlowerBed" .. i, sx * 8 - 4, LOT_Y, 197.2, sx * 8 + 4, 0.8, 199.8, Color3.fromRGB(70, 48, 36), M.Wood)
		for k = 0, 4 do
			ball(pk, "Flower" .. i .. k, sx * 8 - 3.2 + k * 1.6, 1.1, 198.5, 1.1, (k % 2 == 0) and C.orange or C.purple, M.SmoothPlastic, DECOR)
		end
	end
	for i, sx in { -1, 1 } do
		pumpkin(pk, "LotPumpkin" .. i, sx * 3.2, 0, 130, math.pi, 0.5, { mini = true })
	end

	------------------------------------------------------------------
	-- Perimetro: muro visible de 10 con pilares y neon, mas barrera invisible hasta y = 70
	------------------------------------------------------------------
	local WALLC = Color3.fromRGB(26, 20, 38)
	B(pr, "PerimeterWall_N", -130, -4, -130, 130, 10, WORLD.z1, WALLC, M.Concrete)
	B(pr, "PerimeterWall_S", -130, -4, WORLD.z2, 130, 10, 208, WALLC, M.Concrete)
	B(pr, "PerimeterWall_W", -130, -4, WORLD.z1, WORLD.x1, 10, WORLD.z2, WALLC, M.Concrete)
	B(pr, "PerimeterWall_E", WORLD.x2, -4, WORLD.z1, 130, 10, WORLD.z2, WALLC, M.Concrete)
	glow(pr, "PerimeterLed_N", WORLD.x1, 8.6, WORLD.z1, WORLD.x2, 8.9, WORLD.z1 + 0.15, C.warmWhite)
	glow(pr, "PerimeterLed_S", WORLD.x1, 8.6, WORLD.z2 - 0.15, WORLD.x2, 8.9, WORLD.z2, C.warmWhite)
	glow(pr, "PerimeterLed_W", WORLD.x1, 8.6, WORLD.z1, WORLD.x1 + 0.15, 8.9, WORLD.z2, C.warmWhite)
	glow(pr, "PerimeterLed_E", WORLD.x2 - 0.15, 8.6, WORLD.z1, WORLD.x2, 8.9, WORLD.z2, C.warmWhite)
	for i = 0, 7 do
		local x = -112 + i * 32
		B(pr, "PillarN", x - 1.2, 0, WORLD.z1, x + 1.2, 11, WORLD.z1 + 2.4, C.dark, M.Concrete)
		glow(pr, "PillarNCap", x - 1.2, 11, WORLD.z1, x + 1.2, 11.3, WORLD.z1 + 2.4, C.orange)
		B(pr, "PillarS", x - 1.2, 0, WORLD.z2 - 2.4, x + 1.2, 11, WORLD.z2, C.dark, M.Concrete)
		glow(pr, "PillarSCap", x - 1.2, 11, WORLD.z2 - 2.4, x + 1.2, 11.3, WORLD.z2, C.orange)
	end
	for i = 0, 9 do
		local z = -112 + i * 32
		B(pr, "PillarW", WORLD.x1, 0, z - 1.2, WORLD.x1 + 2.4, 11, z + 1.2, C.dark, M.Concrete)
		glow(pr, "PillarWCap", WORLD.x1, 11, z - 1.2, WORLD.x1 + 2.4, 11.3, z + 1.2, C.orange)
		B(pr, "PillarE", WORLD.x2 - 2.4, 0, z - 1.2, WORLD.x2, 11, z + 1.2, C.dark, M.Concrete)
		glow(pr, "PillarECap", WORLD.x2 - 2.4, 11, z - 1.2, WORLD.x2, 11.3, z + 1.2, C.orange)
	end
	if CONFIG.Boundary then
		local inv = { Transparency = 1, CastShadow = false }
		B(pr, "Boundary_N", -130, 10, -130, 130, 70, WORLD.z1, C.black, M.SmoothPlastic, inv)
		B(pr, "Boundary_S", -130, 10, WORLD.z2, 130, 70, 208, C.black, M.SmoothPlastic, inv)
		B(pr, "Boundary_W", -130, 10, WORLD.z1, WORLD.x1, 70, WORLD.z2, C.black, M.SmoothPlastic, inv)
		B(pr, "Boundary_E", WORLD.x2, 10, WORLD.z1, 130, 70, WORLD.z2, C.black, M.SmoothPlastic, inv)
	end
end

------------------------------------------------------------------------
-- Estructura y fachada (edificio de 160 x 160 con puerta de 20 x 12 al sur)
------------------------------------------------------------------------
local function palm(parent, name, x, z)
	cyl(parent, name .. "_Pot", x, 1.25, z, 2.5, 3.2, C.dark, M.Concrete)
	cyl(parent, name .. "_Trunk", x, 5.5, z, 6, 0.7, C.wood, M.Wood, DECOR)
	for i = 1, 3 do
		ball(parent, name .. "_Leaf" .. i, x + (i - 2) * 1.6, 9 + (i % 2) * 0.8, z + (i - 2) * 0.8, 4.2, C.green, M.Grass, DECOR)
	end
end

local function buildShell()
	local e = folders.Exterior
	local f1 = folders.Floor1
	local f2 = folders.Floor2
	local y2 = FLOOR_Y[2]

	-- paredes del piso 1 (puerta de 20 de ancho y 12 de alto en el sur)
	B(f1, "Wall_N", -80, 0, -80, 80, FLOOR_H, -78, C.wall, M.Concrete)
	B(f1, "Wall_W", -80, 0, -78, -78, FLOOR_H, 78, C.wall, M.Concrete)
	B(f1, "Wall_E", 78, 0, -78, 80, FLOOR_H, 78, C.wall, M.Concrete)
	B(f1, "Wall_S_L", -80, 0, 78, -10, FLOOR_H, 80, C.wall, M.Concrete)
	B(f1, "Wall_S_R", 10, 0, 78, 80, FLOOR_H, 80, C.wall, M.Concrete)
	B(f1, "Wall_S_Top", -10, 12, 78, 10, FLOOR_H, 80, C.wall, M.Concrete)

	-- pared del piso 2 (ventanales salvo el norte)
	B(f2, "Wall_N", -80, y2, -80, 80, y2 + FLOOR_H, -78, C.wall, M.Concrete)
	glassWall(f2, "Glass_W", -80, -78, -78, 78, y2)
	glassWall(f2, "Glass_E", 78, -78, 80, 78, y2)
	glassWall(f2, "Glass_S", -80, 78, 80, 80, y2)

	-- arco neon de la puerta (violeta/cian de la marca) y detalles naranja de Halloween
	glow(e, "Door_L", -10.6, 0, 80, -10, 12.6, 80.5, C.warmWhite, { cycle = true, light = 26 })
	glow(e, "Door_R", 10, 0, 80, 10.6, 12.6, 80.5, C.warmWhite, { cycle = true, light = 26, phase = 1 })
	glow(e, "Door_Top", -10.6, 12, 80, 10.6, 12.6, 80.5, C.cyan, { cycle = true })
	glow(e, "DoorAccentL", -10, 0, 80.2, -9.85, 12, 80.5, C.orange)
	glow(e, "DoorAccentR", 9.85, 0, 80.2, 10, 12, 80.5, C.orange)
	glow(e, "DoorAccentT", -10, 11.85, 80.2, 10, 12, 80.5, C.orange)
	-- cantos verticales de neon en las 4 esquinas
	for i, c in { { -80.3, -80.3 }, { 80.3, -80.3 }, { -80.3, 80.3 }, { 80.3, 80.3 } } do
		glow(e, "Corner" .. i, c[1] - 0.2, 0, c[2] - 0.2, c[1] + 0.2, FLOOR_Y[3], c[2] + 0.2, C.warmWhite, { cycle = true, phase = i })
	end

	-- letrero de la entrada: placa negra con serif dorada LA ALFOMBRA ROJA y marco dorado
	sign(e, "MainSign", 0, 18.5, 80.3, 56, 9, 0, 1, "LA ALFOMBRA ROJA", SILVER, false, "chrome", CONFIG.LogoImageId)
	glow(e, "MainSignFrameT", -28.4, 23, 80.2, 28.4, 23.4, 80.5, C.warmWhite, { cycle = true })
	glow(e, "MainSignFrameB", -28.4, 13.6, 80.2, 28.4, 14, 80.5, C.cyan, { cycle = true })
	glow(e, "MainSignFrameL", -28.4, 13.6, 80.2, -28, 23.4, 80.5, C.warmWhite, { cycle = true })
	glow(e, "MainSignFrameR", 28, 13.6, 80.2, 28.4, 23.4, 80.5, C.warmWhite, { cycle = true })
	-- fachada: panel oscuro con el monograma grande sobre el ventanal del piso 2
	B(e, "FacadeBanner", -18, 26.5, 80, 18, 46, 80.5, NAVY, M.Metal, DECOR)
	glow(e, "FacadeBannerT", -18, 45.8, 80.2, 18, 46, 80.6, C.warmWhite, { cycle = true, phase = 2 })
	glow(e, "FacadeBannerB", -18, 26.5, 80.2, 18, 26.7, 80.6, C.cyan, { cycle = true })
	glow(e, "FacadeBannerL", -18, 26.5, 80.2, -17.8, 46, 80.6, C.warmWhite, { cycle = true, phase = 1 })
	glow(e, "FacadeBannerR", 17.8, 26.5, 80.2, 18, 46, 80.6, C.warmWhite, { cycle = true, phase = 1 })
	wallMonogram(e, "FacadeMono", 0, 28, 80.5, 0, 1, 0.44)

	-- plaza de entrada: cola con postes dorados y cuerdas, macetas y calabazas de bienvenida
	for _, sx in { -8, 8 } do
		for k = 0, 2 do
			local z = 84 + k * 5
			cyl(e, "Post", sx, 1.5, z, 3, 0.6, C.gold, M.Metal)
			ball(e, "PostTop", sx, 3.1, z, 0.9, C.gold, M.Metal)
			if k < 2 then
				B(e, "Rope", sx - 0.15, 2.3, z, sx + 0.15, 2.7, z + 5, C.velvet, M.Fabric, DECOR)
			end
		end
	end
	for _, sx in { -24, 24 } do
		B(e, "Planter", sx - 1.5, 0, 82, sx + 1.5, 2.5, 85, C.dark, M.Concrete)
		ball(e, "PlanterLeaf", sx, 4.2, 83.5, 4, C.green, M.Grass)
	end
	for i, sx in { -1, 1 } do
		pumpkin(e, "EntrancePumpkin" .. i, sx * 15, 0, 81.7, math.pi, 1.5, { light = true, range = 20 })
	end
	garland(e, "DoorGarland", Vector3.new(-18, 12.6, 80.22), Vector3.new(18, 12.6, 80.22), 2.2, 20, Vector3.new(0, 0, 0.8))
end

------------------------------------------------------------------------
-- barra larga con vasos de cristal (sd = -1 oeste, 1 este). Clientes hacia la pista.
------------------------------------------------------------------------
local function buildBar(f, sd)
	local tag = (sd < 0) and "BarW" or "BarE"
	B(f, tag .. "Back", sd < 0 and -78 or 76, 0, -50, sd < 0 and -76 or 78, 6, -10, C.dark, M.Concrete)
	bottleShelf(f, tag .. "Shelf", sd < 0 and -78 or 76, 0, -50, -10, 2, 6)
	barCounter(f, tag, math.min(sd * 68, sd * 71), -50, math.max(sd * 68, sd * 71), -10, 0, sd < 0 and "E" or "W", C.magenta)
	for k = 0, 8 do
		stool(f, tag .. "Stool" .. k, sd * 64, 0, -46 + k * 5, -sd * math.pi / 2)
	end
	sign(f, tag .. "Sign", sd * 77.75, 17, -30, 18, 4, -sd, 0, "BAR", C.magenta, true)

	-- cristaleria, bandeja de chupitos, caldero y calabaza (superficie y = 4.5)
	local bx, by = sd * 69.5, 4.5
	pumpkin(f, tag .. "Pumpkin", bx, by, -48.6, sd * math.pi / 2, 0.7, { mini = true })
	local kinds = { "highball", "martini", "tumbler", "highball", "tumbler", "martini" }
	local liqs = { LIQUIDS.orange, LIQUIDS.green, LIQUIDS.purple, LIQUIDS.pink, LIQUIDS.cyan, LIQUIDS.orange }
	local off = (sd > 0) and 2 or 0
	for i = 1, 6 do
		local z = -44 + (i - 1) * 4.5
		local j = (i + off - 1) % 6 + 1
		glassware(f, tag .. "Glass" .. i, bx, by, z, kinds[j], liqs[j], {
			coaster = true,
			glow = (i % 2 == 0) and VIOLET or C.orange,
			straw = (i % 3 == 1) and C.white or ((i % 3 == 2) and C.orange or nil),
			garnish = (i % 3 == 0),
		})
	end
	shotTray(f, tag .. "Shots", bx, by, -16.5, true)
	cauldron(f, tag .. "Cauldron", bx, by, -11.8)
	garland(f, tag .. "Garland", Vector3.new(sd * 77.78, 20.6, -50), Vector3.new(sd * 77.78, 20.6, -10), 1.2, 16, Vector3.new(-sd * 0.55, 0, 0))
	cobweb(f, tag .. "Web", Vector3.new(sd * 77.95, 21.95, -10), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), 6)
end

------------------------------------------------------------------------
-- PISO 1: hall, pista LED, escenario DJ, 2 barras, booths y lobby
------------------------------------------------------------------------
------------------------------------------------------------------------
-- ZONA "LA ALFOMBRA ROJA": alfombra, postes dorados con cordones, photocall, softboxes y detalles
------------------------------------------------------------------------
local RED = Color3.fromRGB(168, 18, 34)
local GOLD_FX = { Reflectance = 0.6 }
local GOLD_DECOR = { CanCollide = false, CastShadow = false, Reflectance = 0.6 }

local function stanchion(parent, name, x, z)
	cyl(parent, name .. "_Base", x, 0.15, z, 0.3, 2.0, C.gold, M.Metal, GOLD_FX)
	cyl(parent, name .. "_Pole", x, 1.7, z, 3.0, 0.34, C.gold, M.Metal, GOLD_FX)
	ball(parent, name .. "_Top", x, 3.25, z, 0.9, C.gold, M.Metal, GOLD_FX)
end

-- cordon rojo que cuelga entre dos postes (no colisiona)
local function cordon(parent, name, x1, z1, x2, z2)
	local a, b = Vector3.new(x1, 3.0, z1), Vector3.new(x2, 3.0, z2)
	local mid = (a + b) / 2 - Vector3.new(0, 0.9, 0)
	seg(parent, name .. "_RopeA", a, mid, 0.3, RED, M.Fabric, DECOR)
	seg(parent, name .. "_RopeB", mid, b, 0.3, RED, M.Fabric, DECOR)
end

-- softbox de fotografia sobre tripode: cuerpo negro, difusor blanco con aro dorado y foco calido
local function softbox(parent, name, x, z, tx, tz)
	cyl(parent, name .. "_Pole", x, 4.2, z, 8.4, 0.3, C.black, M.Metal, { CanCollide = false })
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3 + 0.5
		seg(parent, name .. "_Leg" .. k, Vector3.new(x + 1.9 * math.cos(a), 0.1, z + 1.9 * math.sin(a)), Vector3.new(x, 5.8, z), 0.18, C.black, M.Metal, DECOR)
	end
	local cf = CFrame.lookAt(Vector3.new(x, 9.2, z), Vector3.new(tx, 6, tz))
	P(parent, name .. "_Box", cf * CFrame.new(0, 0, 0.5), Vector3.new(4.2, 4.2, 1.8), C.black, M.SmoothPlastic, { CanCollide = false, Reflectance = 0.2 })
	P(parent, name .. "_Rim", cf * CFrame.new(0, 0, -0.42), Vector3.new(4.4, 4.4, 0.12), C.gold, M.Metal, GOLD_DECOR)
	local diff = P(parent, name .. "_Diffuser", cf * CFrame.new(0, 0, -0.55), Vector3.new(3.8, 3.8, 0.2), Color3.fromRGB(236, 228, 214), M.Neon, { CanCollide = false, CastShadow = false })
	local l = addLight(diff, Color3.fromRGB(255, 240, 222), 34, true, 1.4, false)
	l.Face = Enum.NormalId.Front
	l.Angle = 65
end

-- camara de video en tripode apuntando a la alfombra
local function videoCamera(parent, name, x, z, tx, tz)
	cyl(parent, name .. "_Pole", x, 2.6, z, 5.2, 0.3, C.black, M.Metal, { CanCollide = false })
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3 + 0.3
		seg(parent, name .. "_Leg" .. k, Vector3.new(x + 1.5 * math.cos(a), 0.1, z + 1.5 * math.sin(a)), Vector3.new(x, 3.6, z), 0.16, C.black, M.Metal, DECOR)
	end
	local cf = CFrame.lookAt(Vector3.new(x, 6.0, z), Vector3.new(tx, 5.2, tz))
	P(parent, name .. "_Body", cf, Vector3.new(1.7, 1.5, 3.2), C.black, M.SmoothPlastic, { CanCollide = false, Reflectance = 0.25 })
	P(parent, name .. "_Lens", cf * CFrame.new(0, 0, -2.1) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1.0, 1.1, 1.1), C.dark, M.Metal, withShape(Enum.PartType.Cylinder, { CanCollide = false }))
	P(parent, name .. "_Screen", cf * CFrame.new(0.95, 0.1, 0.6), Vector3.new(0.1, 1.0, 1.3), Color3.fromRGB(150, 170, 190), M.Glass, { CanCollide = false, Reflectance = 0.2 })
end

-- maceta dorada con palmera de frondas largas
local function goldPalm(parent, name, x, z)
	cyl(parent, name .. "_Planter", x, 2.2, z, 4.4, 4.2, C.gold, M.Metal, GOLD_FX)
	cyl(parent, name .. "_Trunk", x, 6.4, z, 4.4, 0.55, Color3.fromRGB(86, 62, 40), M.Wood, DECOR)
	for k = 0, 6 do
		local a = k * 2 * math.pi / 7
		seg(parent, name .. "_Frond" .. k, Vector3.new(x, 8.6, z), Vector3.new(x + 3.6 * math.cos(a), 7.4, z + 3.6 * math.sin(a)), 0.5, Color3.fromRGB(52, 104, 62), M.SmoothPlastic, DECOR)
	end
end

local function buildRedCarpet(f)
	-- alfombra: pasillo central desde la puerta y brazo ancho (16) hasta el photocall, con filete dorado
	B(f, "RedCarpet", -77.2, 0, 56, -6, 0.12, 72, RED, M.Fabric, DECOR)
	for i, z in { 55.8, 71.9 } do
		B(f, "CarpetEdge" .. i, -77.2, 0, z, -6, 0.14, z + 0.3, C.gold, M.Metal, GOLD_DECOR)
	end
	for i, x in { -6.3, 6 } do
		B(f, "CarpetEdgeC" .. i, x, 0, 10, x + 0.3, 0.14, 78, C.gold, M.Metal, GOLD_DECOR)
	end

	-- postes dorados con cordones rojos a ambos lados del brazo (el lado este queda abierto)
	local xs = { -70, -60, -50, -40, -30, -20, -12 }
	for _, z in { 54.6, 73.4 } do
		for i, x in xs do
			stanchion(f, "Stanchion", x, z)
			if i < #xs then
				cordon(f, "Cordon", x, z, xs[i + 1], z)
			end
		end
	end

	-- photocall: panel negro apoyado en la pared oeste con marco dorado y el logo repetido
	B(f, "PhotocallPanel", -78, 0.4, 53, -77.2, 14, 75, Color3.fromRGB(12, 12, 14), M.SmoothPlastic, { Reflectance = 0.08 })
	B(f, "PhotocallPlinth", -78, 0, 52.6, -76.4, 0.4, 75.4, C.black, M.Marble, { Reflectance = 0.3 })
	B(f, "PhotocallFrameT", -78, 14, 52.6, -76.9, 14.8, 75.4, C.gold, M.Metal, GOLD_FX)
	B(f, "PhotocallFrameL", -78, 0.4, 52.6, -76.9, 14, 53.2, C.gold, M.Metal, GOLD_FX)
	B(f, "PhotocallFrameR", -78, 0.4, 74.8, -76.9, 14, 75.4, C.gold, M.Metal, GOLD_FX)
	monogram(f, "PhotocallLogo", -76.9, 2.2, 64, 1, 0, 0.22, true)
	for i, z in { 55.6, 72.4 } do
		for j, y in { 1.2, 5.0, 8.8 } do
			monogram(f, "PhotocallMini" .. i .. j, -76.9, y, z, 1, 0, 0.075, false)
		end
	end

	-- softboxes a ambos lados y camara de video, palmeras doradas y mesas de champan
	softbox(f, "SoftboxN", -52, 51.5, -70, 62)
	softbox(f, "SoftboxS", -52, 76, -70, 66)
	videoCamera(f, "VideoCam", -22, 51.5, -70, 64)
	goldPalm(f, "CarpetPalmN", -73.5, 51.5)
	goldPalm(f, "CarpetPalmS", -73.5, 76.5)
	for i, x in { -64, -38 } do
		roundTable(f, "CarpetTable" .. i, x, 0, 49, 1.6, true)
		cyl(f, "CarpetBucket" .. i, x - 0.6, 5.2, 49, 1.4, 1.5, C.gold, M.Metal, { CanCollide = false, Reflectance = 0.6 })
		cyl(f, "CarpetBottle" .. i, x - 0.6, 6.3, 49, 2.0, 0.5, Color3.fromRGB(24, 44, 30), M.Glass, { CanCollide = false })
		candleCluster(f, "CarpetCandle" .. i, x + 0.7, 4.5, 49, false)
	end
	lamp(f, "CarpetFill", -66, 9, 64, C.warmWhite, 34, 0.9)
	lamp(f, "CarpetFillE", -30, 9, 64, C.warmWhite, 30, 0.8)
	sign(f, "CarpetSign", -40, 9, 77.75, 26, 3, 0, -1, "BIENVENIDOS - FOTOS", SILVER, false, "chrome")
end

------------------------------------------------------------------------
-- CABINA DE CONTROL DE LUCES (escenario, a la izquierda del DJ): consola negra con filete dorado,
-- 8 faders, 3 pantallas y placa de operador. Mira a la pista; el operador se pone al norte.
------------------------------------------------------------------------
local function buildControlBooth(f)
	local y0 = LAYOUT.stage.top
	local x1, x2, z1, z2 = -26, -14, -72.5, -68.5
	B(f, "LightDesk_Base", x1, y0, z1, x2, y0 + 3, z2, C.black, M.SmoothPlastic, LACQUER)
	B(f, "LightDesk_Top", x1 - 0.3, y0 + 3, z1 - 0.3, x2 + 0.3, y0 + 3.3, z2 + 0.3, C.black, M.Marble, { Reflectance = 0.3 })
	B(f, "LightDesk_TrimF", x1 - 0.3, y0 + 2.7, z2 + 0.3, x2 + 0.3, y0 + 3, z2 + 0.45, C.gold, M.Metal, GOLD_DECOR)
	B(f, "LightDesk_TrimL", x1 - 0.45, y0 + 2.7, z1 - 0.3, x1 - 0.3, y0 + 3, z2 + 0.45, C.gold, M.Metal, GOLD_DECOR)
	B(f, "LightDesk_TrimR", x2 + 0.3, y0 + 2.7, z1 - 0.3, x2 + 0.45, y0 + 3, z2 + 0.45, C.gold, M.Metal, GOLD_DECOR)
	for i = 0, 7 do
		local cx = x1 + 1.5 + i * 1.3
		B(f, "LightDesk_Slot" .. i, cx - 0.12, y0 + 3.3, z1 + 0.6, cx + 0.12, y0 + 3.38, z1 + 2.6, C.dark, M.Metal, DECOR)
		local kz = z1 + 0.9 + ((i * 37) % 10) / 10 * 1.4
		B(f, "LightDesk_Knob" .. i, cx - 0.35, y0 + 3.38, kz - 0.2, cx + 0.35, y0 + 3.7, kz + 0.2, C.gold, M.Metal, GOLD_DECOR)
	end
	for i, label in { "PISTA - VIP", "ROOFTOP - ALFOMBRA", "EFECTOS" } do
		local cx = -23.5 + (i - 1) * 3.5
		B(f, "LightDesk_Stand" .. i, cx - 0.15, y0 + 3.3, z2 - 0.6, cx + 0.15, y0 + 3.7, z2 - 0.4, C.dark, M.Metal, DECOR)
		local cf = CFrame.lookAt(Vector3.new(cx, y0 + 4.4, z2 - 0.5), Vector3.new(cx, y0 + 4.4, z2 - 1.5))
		local scr = P(f, "LightDesk_Screen" .. i, cf, Vector3.new(3.1, 1.5, 0.15), C.black, M.SmoothPlastic, { CanCollide = false, Reflectance = 0.1 })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = scr
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(0.9, 0.5)
		tl.Position = UDim2.fromScale(0.05, 0.25)
		tl.Text = label
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamMedium
		tl.TextColor3 = GOLD_TXT
		tl.Parent = gui
	end
	sign(f, "LightDeskSign", -20, y0 + 0.8, z2 + 0.25, 10.5, 1.2, 0, 1, "CABINA DE LUCES", SILVER, false, "chrome")
	-- placa de operador (el cliente escribe aqui el estado: LIBRE / nombre del operador)
	local plate = P(f, "ControlStatusPlate", CFrame.lookAt(Vector3.new(-20, y0 + 1.95, z2 + 0.15), Vector3.new(-20, y0 + 1.95, z2 + 1.15)), Vector3.new(8, 0.9, 0.2), C.black, M.SmoothPlastic, { CanCollide = false, Reflectance = 0.1 })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = plate
	local st = Instance.new("TextLabel")
	st.Name = "ControlStatusLabel"
	st.BackgroundTransparency = 1
	st.Size = UDim2.fromScale(1, 1)
	st.Text = "OPERADOR: LIBRE"
	st.TextScaled = true
	st.Font = Enum.Font.GothamMedium
	st.TextColor3 = GOLD_TXT
	st.Parent = sg
	lamp(f, "LightDeskFill", -20, y0 + 6, -66, C.warmWhite, 22, 0.8)
end

local function buildFloor1()
	local f = folders.Floor1
	local D, St = LAYOUT.dance, LAYOUT.stage
	B(f, "Floor1_Slab", -80, -3, -80, 80, 0, 80, C.floor, M.Marble, { Reflectance = 0.24 })
	B(f, "Carpet", -6, 0, 10, 6, 0.1, 78, RED, M.Fabric, DECOR)

	-- PISTA LED: base oscura reflectante, juntas de 0.5, paneles de neon de brillo moderado en
	-- damero (la mitad mas tenue), cristal ahumado encima y bisel metalico con hilo de neon
	local n = TILE_COUNT
	local cell = (D.x2 - D.x1) / n
	B(f, "DanceBase", D.x1, 0, D.z1, D.x2, 0.1, D.z2, Color3.fromRGB(10, 8, 20), M.Marble, { Reflectance = 0.3 })
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			local x1, z1 = D.x1 + ix * cell, D.z1 + iz * cell
			local tile = B(f, "Tile", x1 + 0.25, 0.1, z1 + 0.25, x1 + cell - 0.25, 0.22, z1 + cell - 0.25, Color3.fromRGB(70, 56, 36), M.Neon, { CastShadow = false })
			table.insert(fx.tiles, { part = tile, ix = ix, iz = iz, n = n, dim = ((ix + iz) % 2 == 0) and 1 or 0.6 })
		end
	end
	B(f, "LedGlass", D.x1, 0.22, D.z1, D.x2, 0.28, D.z2, Color3.fromRGB(22, 18, 38), M.Glass, { Transparency = 0.5, Reflectance = 0.35, CanCollide = false, CastShadow = false })
	local bez = {
		{ D.x1 - 1.5, D.z1 - 1.5, D.x2 + 1.5, D.z1 - 0.5 },
		{ D.x1 - 1.5, D.z2 + 0.5, D.x2 + 1.5, D.z2 + 1.5 },
		{ D.x1 - 1.5, D.z1 - 0.5, D.x1 - 0.5, D.z2 + 0.5 },
		{ D.x2 + 0.5, D.z1 - 0.5, D.x2 + 1.5, D.z2 + 0.5 },
	}
	for i, r in bez do
		B(f, "DanceBezel" .. i, r[1], 0, r[2], r[3], 0.3, r[4], C.dark, M.Metal, DECOR)
	end
	glow(f, "DanceLedN", D.x1 - 0.5, 0.1, D.z1 - 0.5, D.x2 + 0.5, 0.25, D.z1 - 0.35, C.cyan, { cycle = true })
	glow(f, "DanceLedS", D.x1 - 0.5, 0.1, D.z2 + 0.35, D.x2 + 0.5, 0.25, D.z2 + 0.5, C.cyan, { cycle = true })
	glow(f, "DanceLedW", D.x1 - 0.5, 0.1, D.z1 - 0.35, D.x1 - 0.35, 0.25, D.z2 + 0.35, C.warmWhite, { cycle = true })
	glow(f, "DanceLedE", D.x2 + 0.35, 0.1, D.z1 - 0.35, D.x2 + 0.5, 0.25, D.z2 + 0.35, C.warmWhite, { cycle = true })

	-- ESCENARIO DJ (norte) con 2 escalones de acceso y pantalla LED
	B(f, "Stage", St.x1, 0, St.z1, St.x2, St.top, St.z2, C.black, M.SmoothPlastic)
	B(f, "StageStepB", -8, 0, -64, 8, 2.2, -62, C.black, M.SmoothPlastic)
	B(f, "StageStepA", -8, 0, -62, 8, 1.1, -60.5, C.black, M.SmoothPlastic)
	glow(f, "StageTrim", St.x1, 0.8, -64.15, St.x2, 1.3, -64, C.warmWhite, { cycle = true, light = 22 })
	if deps.djBooth then
		deps.djBooth(ctx, f, 0, St.top, -72)
	else
		djDeck(f, "DJ1", 0, St.top, -72, C.cyan)
	end
	buildControlBooth(f)
	sign(f, "DJFront", 0, St.top + 1.75, -70.75, 11, 2.4, 0, 1, "ALFOMBRA ROJA", SILVER, false, "chrome")
	local _, screen = sign(f, "DJScreen", 0, 14, -77.75, 44, 14, 0, 1, "LA ALFOMBRA ROJA", GOLD_TXT, false, "screen")
	table.insert(fx.screens, screen)
	glow(f, "ScreenFrameT", -22.4, 21, -77.7, 22.4, 21.5, -77.2, C.warmWhite, { cycle = true })
	glow(f, "ScreenFrameB", -22.4, 6.5, -77.7, 22.4, 7, -77.2, C.warmWhite, { cycle = true })
	wallMonogram(f, "StageMonoL", -36, 4.5, -78, 0, 1, 0.4)
	wallMonogram(f, "StageMonoR", 36, 4.5, -78, 0, 1, 0.4)
	speaker(f, "Speaker_L", -50, 0, -72, 12, true)
	speaker(f, "Speaker_R", 50, 0, -72, 12, false)
	flownArray(f, "FlownL", -44, -70, 21.5, 7)
	flownArray(f, "FlownR", 44, -70, 21.5, 7)
	haze(f, "StageHazeL", -16, 3.5, -66.5, 16)
	haze(f, "StageHazeR", 16, 3.5, -66.5, 16)

	-- truss del escenario con 7 focos (conos de luz translucidos y sombras) y 6 estrobos
	truss(f, "StageTruss", -32, -69, 32, -69, 20.6)
	for i, x in { -30, 0, 30 } do
		B(f, "StageHanger" .. i, x - 0.1, 21.2, -69.1, x + 0.1, FLOOR_H, -68.9, C.dark, M.Metal, DECOR)
	end
	for i, x in { -24, -16, -8, 0, 8, 16, 24 } do
		glow(f, "StageSpot" .. i, x - 0.6, 19, -69.6, x + 0.6, 20, -68.4, C.warmWhite, {
			cycle = true,
			phase = i,
			light = 36,
			spot = true,
			brightness = 3,
			shadows = true,
			shaft = { 16, 0.5, 5 },
		})
	end
	for i, x in { -20, -12, -4, 4, 12, 20 } do
		addStrobe(f, "Strobe" .. i, x - 1.5, 19.2, -69.4, x + 1.5, 20, -68.6)
	end

	-- BOLA DE ESPEJOS: nucleo oscuro mate (las juntas se ven negras) cubierto por ~175 facetas
	-- cuadradas de espejo (Metal + Reflectance 1) en anillos de latitud, alternando dos tonos de plata
	-- para que cada faceta se lea; casquete y varilla cromados y dos focos que la iluminan.
	local mc = Vector3.new(0, 36, -24)
	B(f, "MirrorRod", mc.X - 0.12, mc.Y + 3, mc.Z - 0.12, mc.X + 0.12, FLOOR_Y[3] - 2, mc.Z + 0.12, C.chrome, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.6 })
	cyl(f, "MirrorMotor", mc.X, mc.Y + 4.6, mc.Z, 1.2, 1.6, C.dark, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.4 })
	local core = ball(f, "MirrorCore", mc.X, mc.Y, mc.Z, 7.0, Color3.fromRGB(18, 18, 22), M.SmoothPlastic, { CanCollide = false, Reflectance = 0.1 })
	addLight(core, Color3.fromRGB(255, 244, 230), 40, false, 1)
	local SILVERS = { Color3.fromRGB(228, 231, 240), Color3.fromRGB(176, 184, 202) }
	local RC = 3.56 -- radio del centro de cada faceta: su cara interior toca el nucleo (r = 3.5), nunca dentro
	local fi = 0
	local step = PROFILE.mirrorStep
	local rings = math.floor(72 / step)
	for ri = 0, 2 * rings do
		local latDeg = -rings * step + ri * step
		local lat = math.rad(latDeg)
		local ringN = math.max(5, math.floor(2 * math.pi * (RC + 0.06) * math.cos(lat) / 1.05 + 0.5))
		for k = 0, ringN - 1 do
			fi += 1
			local lon = k / ringN * math.pi * 2 + (ri % 2 == 0 and 0 or math.pi / ringN)
			local dir = Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon))
			local local_cf = CFrame.lookAt(dir * RC, dir * (RC + 1))
			local facet = P(f, "MirrorFacet", CFrame.new(mc) * local_cf, Vector3.new(0.92, 0.92, 0.12), SILVERS[fi % 2 + 1], M.Metal, { Reflectance = 0.8, CanCollide = false, CastShadow = false })
			table.insert(fx.mirror, { part = facet, center = mc, offset = local_cf })
		end
	end
	-- dos focos de acento que bañan la bola
	for _, sx in { -1, 1 } do
		local canPos = Vector3.new(sx * 11, 41, mc.Z)
		B(f, "MirrorSpotRod", canPos.X - 0.1, canPos.Y, canPos.Z - 0.1, canPos.X + 0.1, FLOOR_Y[3] - 2, canPos.Z + 0.1, C.dark, M.Metal, DECOR)
		local can = P(f, "MirrorSpotCan", CFrame.lookAt(canPos, mc), Vector3.new(1.2, 1.2, 1.8), C.chrome, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.5 })
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Front
		l.Angle = 40
		l.Range = 30
		l.Brightness = 1.8 * LOOK.LightIntensity
		l.Color = Color3.fromRGB(255, 240, 220)
		l.Parent = can
		lightCount += 1
	end

	-- truss del atrio con 6 lasers translucidos (3 por lado)
	for _, side in { -1, 1 } do
		local x = side * 36
		truss(f, "AtriumTruss", x, -52, x, -4, 41.3)
		for _, z in { -51, -5 } do
			B(f, "AtriumRod", x - 0.2, 41.6, z - 0.2, x + 0.2, FLOOR_Y[3] - 2, z + 0.2, C.dark, M.Metal)
		end
		for k, z in { -48, -28, -8 } do
			local col = ({ C.cyan, C.magenta, VIOLET })[k]
			local head = glow(f, "LaserHead", x - 0.8, 39.5, z - 0.8, x + 0.8, 40.7, z + 0.8, col, { light = 10 })
			local tip = laserBeam(head, col)
			table.insert(fx.beams, {
				head = head,
				tip = tip,
				origin = Vector3.new(x, 40.1, z),
				yaw = math.pi + side * -0.4,
				swing = 0.4,
				speed = 1 + k * 0.35,
				phase = k * 1.7 + (side + 1),
				side = side,
			})
		end
	end

	-- barras (oeste y este) con cristaleria
	buildBar(f, -1)
	buildBar(f, 1)

	-- booths contra la pared oeste (+1 al este) con velas
	for i, z in { 8, 26, 44 } do
		sofa(f, "BoothW" .. i, -76.2, 0, z, -math.pi / 2, 9, C.velvet, C.magenta)
		roundTable(f, "BoothTableW" .. i, -70.5, 0, z, 1.8, false, C.cyan)
		candleCluster(f, "BoothCandleW" .. i, -70.5, 2.5, z, i == 2)
	end
	sofa(f, "BoothE", 76.2, 0, 2, math.pi / 2, 9, C.velvet, C.magenta)
	roundTable(f, "BoothTableE", 70.5, 0, 2, 1.8, false, C.cyan)
	candleCluster(f, "BoothCandleE", 70.5, 2.5, 2, false)

	-- mesas altas de pie, bien separadas (>= 12 studs entre mesas): calabazas al este, velas al oeste
	local ht = 0
	for _, x in { -56, -28, 28, 56 } do
		for _, z in { 22, 38 } do
			ht += 1
			roundTable(f, "HighTable" .. ht, x, 0, z, 1.6, true, (x < 0) and C.cyan or VIOLET)
			if x > 0 then
				pumpkin(f, "TablePumpkin" .. ht, x, 4.5, z, -math.pi / 2, 0.5, { mini = true })
			else
				candleCluster(f, "TableCandle" .. ht, x, 4.5, z, false)
			end
		end
	end

	-- lobby: zona LA ALFOMBRA ROJA (sustituye al guardarropa), boleteria, palmeras y logos
	buildRedCarpet(f)
	barCounter(f, "TicketDesk", 34, 72, 62, 75, 0, "N", C.cyan)
	sign(f, "TicketSign", 48, 9, 77.75, 16, 3, 0, -1, "BOLETERIA", SILVER, false, "chrome")
	for i, x in { -16, 16 } do
		palm(f, "LobbyPalm" .. i, x, 74)
	end
	wallMonogram(f, "LobbyMonoE", 78, 6, 72, -1, 0, 0.36)
	pumpkin(f, "TicketPumpkin", 48, 4.5, 73.5, math.pi, 0.6, { mini = true })

	-- escalera P1 -> P2 (este): 10 de ancho, sube al norte. Descanso de entrada 10x14 al sur.
	local S1 = LAYOUT.s1
	stairs(folders.Stairs, "Stairs1", S1.x1, S1.x2, S1.baseY, S1.zStart, S1.dir)
	stairRail(folders.Stairs, "Stairs1Rail", S1.x1 + 0.15, S1.baseY, S1.zStart, S1.dir)
	-- luces de seguridad en escaleras y descansos (nunca se apagan del todo desde la cabina)
	for _, p in { { 73, 7, 70 }, { 73, 16, 48 }, { 73, 31, 11 } } do
		lamp(folders.Stairs, "StairLamp", p[1], p[2], p[3], C.warmWhite, 22, 0.8)
	end
	landing(f, "Landing1In", S1.landIn[1], S1.landIn[2], S1.landIn[3], S1.landIn[4], 0)

	-- techo del hall: neon rosa, focos empotrados, tiras de luz y listones acusticos
	neonArt(f, "CeilArt1", -76, 24, 76, 76, 21.8, 7, 3, C.gold)
	for i, x in { -60, -30, 0, 30, 60 } do
		for j, z in { 30, 50, 70 } do
			downlight(f, "Downlight", x, 21.9, z)
		end
	end
	for i, x in { -22, 22 } do
		glow(f, "HallStrip" .. i, x - 0.3, 21.6, 22, x + 0.3, 22, 76, C.warmWhite, { cycle = true, phase = i, light = 24 })
	end
	glow(f, "StageCeil", -32, 21.6, -75, 32, 22, -74.4, C.cyan, { cycle = true })
	slats(f, "SlatNL", "x", -78, -76, -46, 1, 21, 1)
	slats(f, "SlatNR", "x", -78, 46, 76, 1, 21, 1)
	slats(f, "SlatW", "z", -78, -76, -52, 1, 21, 1)
	slats(f, "SlatE", "z", 77.5, -76, -52, 1, 21, 1)

	-- Halloween en el hall y la pista (nada sobre la pista ni en los pasos)
	for i, sx in { -1, 1 } do
		pumpkin(f, "StagePumpkin" .. i, sx * 31, St.top, -66, math.pi, 0.9, { light = true, range = 18 })
		pumpkin(f, "SpeakerPumpkin" .. i, sx * 50, 12, -72, math.pi, 0.8, { mini = true })
	end
	for _, side in { -1, 1 } do
		for _, z in { -38, -18 } do
			local x = side * 36
			pumpkin(f, "HungPumpkin", x, 36, z, side * math.pi / 2, 1.0, { light = true, range = 16 })
			B(f, "HungRod", x - 0.05, 38.5, z - 0.05, x + 0.05, 40.7, z + 0.05, C.dark, M.Metal, DECOR)
		end
	end
	local wallBats = {
		{ 77.1, 14, -60, -1, 0 }, { 77.1, 17.5, -68, -1, 0 }, { 77.1, 12, -56, -1, 0 },
		{ -66, 15.5, -77.1, 0, 1 }, { -56, 18, -77.1, 0, 1 }, { 56, 16, -77.1, 0, 1 }, { 66, 13.5, -77.1, 0, 1 },
		{ -77.1, 17, -64, 1, 0 }, { -77.1, 14, -72, 1, 0 },
	}
	for i, b in wallBats do
		wallBat(f, "Bat" .. i, b[1], b[2], b[3], b[4], b[5])
	end
	hangBat(f, "AtriumBat1", -20, 42, -40, 46, 0, 1)
	hangBat(f, "AtriumBat2", 20, 42.5, -14, 46, 0, 1)
	hangBat(f, "AtriumBat3", 0, 43, 6, 46, 0, 1)
	cobweb(f, "WebA", Vector3.new(-77.95, 21.95, 76), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), 6)
	cobweb(f, "WebB", Vector3.new(77.95, 21.95, 76), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), 6)
	cobweb(f, "WebC", Vector3.new(-77.95, 21.95, -76), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0), 6)

	fillGrid(f, "Fill1", 8, C.warmWhite, 60, 1.0)
	sign(f, "Floor1Label", 77.75, 16, 40, 10, 3, -1, 0, "NIVEL 1", C.cyan, true)
end

------------------------------------------------------------------------
-- PISO 2 (VIP): balcon sobre el atrio, barra VIP y 14 lounges con pasillos anchos
------------------------------------------------------------------------
local function buildFloor2()
	local f = folders.Floor2
	local y = FLOOR_Y[2]
	local A, S1, S2 = LAYOUT.atrium, LAYOUT.s1, LAYOUT.s2
	slab(f, "Floor2_Slab", -80, -80, 80, 80, y, 2, { { A.x1, A.z1, A.x2, A.z2 }, S1.hole }, Color3.fromRGB(34, 22, 44), M.Marble, { Reflectance = 0.12 })

	-- barandillas del balcon sobre la pista y del hueco de la escalera 1, y descansos
	railLoop(f, "AtriumRail", A.x1, A.z1, A.x2, A.z2, y, C.cyan)
	rail(f, "S1Rail_W", S1.hole[1], S1.hole[2], S1.hole[1], S1.hole[4], y, C.magenta)
	rail(f, "S1Rail_S", S1.hole[1], S1.hole[4], S1.hole[3], S1.hole[4], y, C.magenta)
	landing(f, "Landing1Out", S1.landOut[1], S1.landOut[2], S1.landOut[3], S1.landOut[4], y)
	for _, p in { { -73, 31, -70 }, { -73, 40, -48 }, { -73, 55, -11 } } do
		lamp(folders.Stairs, "StairLamp", p[1], p[2], p[3], C.warmWhite, 22, 0.8)
	end
	landing(f, "Landing2In", S2.landIn[1], S2.landIn[2], S2.landIn[3], S2.landIn[4], y)

	-- barra VIP norte (a 9 studs del balcon: pasillo principal libre)
	B(f, "VIPBackBar", -24, y, -78, 24, y + 6, -76.5, C.dark, M.Concrete)
	for k = 0, 2 do
		local sy = y + 6 + k * 2.6
		B(f, "VIPShelf" .. k, -24, sy, -78, 24, sy + 0.3, -75.2, C.wood, M.Wood)
		glow(f, "VIPShelfLed" .. k, -24, sy - 0.15, -78, 24, sy, -75.2, BOTTLES[k + 1], { cycle = true, light = 16 })
		if k == 1 and deps.vipShelfBottles then
			deps.vipShelfBottles(ctx, f, "VIPShelf" .. k, -22, 22, sy + 0.3, -76.6, k)
		else
			for nb = 0, 11 do
				cyl(f, "VIPBottle", -22 + nb * 4, sy + 1, -76.6, 1.4, 0.6, BOTTLES[(nb + k) % #BOTTLES + 1], M.Glass, { CanCollide = false, Transparency = 0.2 })
			end
		end
	end
	barCounter(f, "VIPBar", -22, -73, 22, -70, y, "S", C.gold)
	for k, x in { -18, -9, 0, 9, 18 } do
		stool(f, "VIPStool" .. k, x, y, -68.2, 0)
	end
	sign(f, "VIPSign", 0, y + 14, -77.75, 24, 6, 0, 1, "V.I.P", C.gold, false)
	wallMonogram(f, "VipMonoL", -44, y + 4, -78, 0, 1, 0.38)
	wallMonogram(f, "VipMonoR", 44, y + 4, -78, 0, 1, 0.38)

	-- vasos de cristal, bandeja de chupitos y calabazas en la barra VIP (superficie y = 28.5)
	local vy, vz = y + 4.5, -71.5
	for i, sx in { -1, 1 } do
		pumpkin(f, "VipPumpkin" .. i, sx * 21.5, vy, vz, math.pi, 0.6, { mini = true })
	end
	local vkinds = { "martini", "highball", "tumbler", "martini", "tumbler", "highball", "martini", "tumbler" }
	local vliqs = { LIQUIDS.orange, LIQUIDS.purple, LIQUIDS.green, LIQUIDS.pink, LIQUIDS.cyan, LIQUIDS.orange, LIQUIDS.purple, LIQUIDS.green }
	for i, x in { -19, -15.5, -12, -8.5, 8.5, 12, 15.5, 19 } do
		glassware(f, "VipGlass" .. i, x, vy, vz, vkinds[i], vliqs[i], {
			coaster = true,
			glow = (i % 2 == 0) and VIOLET or C.orange,
			straw = (vkinds[i] == "highball") and ((i % 2 == 0) and C.white or C.orange) or nil,
			garnish = (vkinds[i] == "tumbler"),
		})
	end
	shotTray(f, "VipShots", 0, vy, vz, false)

	-- 14 lounges (mesa + 2 sofas + cuerdas a +-4): 8 laterales y 6 al sur, con >= 9 studs entre cuerdas
	local lounges = {}
	for _, z in { -36, -12, 12, 36 } do
		table.insert(lounges, { -55, z })
		table.insert(lounges, { 55, z })
	end
	for _, x in { -28, 0, 28 } do
		for _, z in { 46, 68 } do
			table.insert(lounges, { x, z })
		end
	end
	for i, p in lounges do
		local x, z = p[1], p[2]
		roundTable(f, "LoungeTable" .. i, x, y, z, 2, false, C.gold)
		sofa(f, "LoungeSofaA" .. i, x, y, z - 5, math.pi, 7, C.sofaWarm, C.fire)
		sofa(f, "LoungeSofaB" .. i, x, y, z + 5, 0, 7, C.sofaWarm, C.fire)
		for _, px in { -2.2, 2.2 } do
			P(f, "PillowA" .. i, CFrame.new(x + px, y + 2.9, z - 5.7) * CFrame.Angles(0, math.rad(px * 8), 0), Vector3.new(1.4, 1.4, 0.5), C.velvet, M.Fabric, DECOR)
			P(f, "PillowB" .. i, CFrame.new(x + px, y + 2.9, z + 5.7) * CFrame.Angles(0, math.rad(-px * 8), 0), Vector3.new(1.4, 1.4, 0.5), C.velvet, M.Fabric, DECOR)
		end
		ropeLine(f, "RopeW" .. i, x - 4, z - 7.5, x - 4, z + 7.5, y)
		ropeLine(f, "RopeE" .. i, x + 4, z - 7.5, x + 4, z + 7.5, y)
		ropeLine(f, "RopeN" .. i, x - 4, z - 7.5, x + 4, z - 7.5, y, true, true)
		candleCluster(f, "LoungeCandle" .. i, x, y + 2.5, z, i % 4 == 1)
		glow(f, "Chandelier" .. i, x - 3, y + 17, z - 3, x + 3, y + 17.3, z + 3, C.warmWhite, { light = (i % 3 == 1) and 26 or nil, brightness = 1.4 })
		B(f, "ChandelierRod" .. i, x - 0.1, y + 17.3, z - 0.1, x + 0.1, y + FLOOR_H, z + 0.1, C.dark, M.Metal, DECOR)
	end

	-- techo: neon rosa, focos empotrados y tiras (parte baja de la losa del piso 3)
	neonArt(f, "CeilArt2", -76, 24, 76, 76, y + 21.8, 11, 3, C.gold)
	for _, x in { -60, -30, 0, 30, 60 } do
		for _, z in { 30, 50, 70 } do
			downlight(f, "Downlight2", x, y + 21.9, z)
		end
	end
	for i, z in { -64, 22 } do
		glow(f, "CeilStrip" .. i, -76, y + 21.6, z, 76, y + 22, z + 0.6, C.warmWhite, { cycle = true, phase = i })
	end

	-- Halloween VIP: telaranas en las esquinas del techo y murcielagos en la pared norte
	for i, c in { { -77.95, -76, 1 }, { 77.95, -76, 1 }, { -77.95, 76, -1 }, { 77.95, 76, -1 } } do
		cobweb(f, "VipWeb" .. i, Vector3.new(c[1], y + 21.95, c[2]), Vector3.new(0, 0, c[3]), Vector3.new(0, -1, 0), 4.5)
	end
	for i, b in { { -64, 15 }, { 64, 15 }, { -70, 11 }, { 70, 11 } } do
		wallBat(f, "VipBat" .. i, b[1], y + b[2], -77.6, 0, 1)
	end
	sign(f, "Floor2Label", 77.75, y + 16, -40, 10, 3, -1, 0, "NIVEL 2", C.gold, false)

	-- escalera P2 -> P3 (oeste): 10 de ancho, sube al sur. Descanso de entrada al norte (10 x 14).
	stairs(folders.Stairs, "Stairs2", S2.x1, S2.x2, S2.baseY, S2.zStart, S2.dir)
	stairRail(folders.Stairs, "Stairs2Rail", S2.x2 - 0.15, S2.baseY, S2.zStart, S2.dir)
	fillGrid(f, "Fill2", y + 8, C.warmWhite, 60, 0.9)
end

------------------------------------------------------------------------
-- PISO 3 (rooftop): escenario DJ con monograma, barra, piscina, fire pits y loungers
------------------------------------------------------------------------
local function lounger(parent, name, x, y, z)
	B(parent, name .. "_Base", x - 1.5, y, z - 3.5, x + 1.5, y + 1.2, z + 3.5, C.ivory, M.SmoothPlastic, LACQUER)
	P(parent, name .. "_Back", CFrame.new(x, y + 1.7, z + 3) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(3, 0.6, 2), C.ivory, M.SmoothPlastic, LACQUER)
	B(parent, name .. "_Glow", x - 1.4, y, z - 3.4, x + 1.4, y + 0.15, z + 3.4, C.black, M.Metal, DECOR)
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
	addLight(flame, C.fire, 26, false, 2)
	sofa(parent, name .. "_SofaS", x, y, z + 6.5, 0, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaN", x, y, z - 6.5, math.pi, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaE", x + 6.5, y, z, math.pi / 2, 6, C.velvet, C.fire)
	sofa(parent, name .. "_SofaW", x - 6.5, y, z, -math.pi / 2, 6, C.velvet, C.fire)
end

local function buildFloor3()
	local f = folders.Floor3
	local y = FLOOR_Y[3]
	local S2, pool = LAYOUT.s2, LAYOUT.pool
	slab(f, "Floor3_Slab", -80, -80, 80, 80, y, 2, { S2.hole, pool }, C.deck, M.WoodPlanks)

	-- parapeto de cristal + barandillas del hueco de escalera + descanso de llegada
	railLoop(f, "Parapet", -79.6, -79.6, 79.6, 79.6, y, C.magenta)
	rail(f, "S2Rail_N", S2.hole[1], S2.hole[2], S2.hole[3], S2.hole[2], y, C.cyan)
	rail(f, "S2Rail_E", S2.hole[3], S2.hole[2], S2.hole[3], S2.hole[4], y, C.cyan)
	landing(f, "Landing2Out", S2.landOut[1], S2.landOut[2], S2.landOut[3], S2.landOut[4], y)

	-- piscina poco profunda (fondo neon + agua sin colision), 40 x 38
	B(f, "PoolFloor", pool[1], y - 2, pool[2], pool[3], y - 1, pool[4], Color3.fromRGB(70, 140, 160), M.SmoothPlastic, { Reflectance = 0.2 })
	B(f, "PoolWater", pool[1], y - 1, pool[2], pool[3], y - 0.2, pool[4], C.cyan, M.Glass, { Transparency = 0.5, CanCollide = false })
	glow(f, "PoolRim_N", pool[1], y, pool[2] - 0.2, pool[3], y + 0.15, pool[2], C.cyan, { cycle = true, light = 22 })
	glow(f, "PoolRim_S", pool[1], y, pool[4], pool[3], y + 0.15, pool[4] + 0.2, C.cyan, { cycle = true })
	glow(f, "PoolRim_W", pool[1] - 0.2, y, pool[2], pool[1], y + 0.15, pool[4], C.cyan, { cycle = true })
	glow(f, "PoolRim_E", pool[3], y, pool[2], pool[3] + 0.2, y + 0.15, pool[4], C.cyan, { cycle = true })

	-- escenario DJ del rooftop: panel de fondo con el monograma, cartel y arco de focos
	B(f, "RoofStage", -30, y, -78, 30, y + 2.2, -62, C.black, M.SmoothPlastic)
	B(f, "RoofStageStep", -6, y, -62, 6, y + 1.1, -60.5, C.black, M.SmoothPlastic)
	glow(f, "RoofStageTrim", -30, y + 0.6, -62.15, 30, y + 1, -62, C.cyan, { cycle = true, light = 18 })
	B(f, "RoofBackdrop", -30, y, -78.6, 30, y + 24, -78, NAVY, M.Metal)
	wallMonogram(f, "RoofMono", 0, y + 6.2, -78, 0, 1, 0.42)
	sign(f, "RoofSign", 0, y + 4.1, -77.75, 30, 3.4, 0, 1, "LA ALFOMBRA ROJA", SILVER, false, "chrome")
	djDeck(f, "DJ3", 0, y + 2.2, -70, C.magenta)
	sign(f, "RoofDJFront", 0, y + 2.2 + 1.75, -68.75, 11, 2.4, 0, 1, "ALFOMBRA ROJA", SILVER, false, "chrome")
	haze(f, "RoofHazeL", -12, y + 2.4, -63.5, 12)
	haze(f, "RoofHazeR", 12, y + 2.4, -63.5, 12)
	speaker(f, "RoofSpeaker_L", -38, y, -70, 9, true)
	speaker(f, "RoofSpeaker_R", 38, y, -70, 9, false)
	B(f, "ArchPillarL", -32, y, -70.5, -31, y + 15, -69.5, C.dark, M.Metal)
	B(f, "ArchPillarR", 31, y, -70.5, 32, y + 15, -69.5, C.dark, M.Metal)
	B(f, "ArchBeam", -32, y + 14, -70.5, 32, y + 15, -69.5, C.dark, M.Metal)
	for i, x in { -16, -8, 0, 8, 16 } do
		glow(f, "RoofSpot" .. i, x - 0.6, y + 13.1, -70.6, x + 0.6, y + 14, -69.4, C.warmWhite, {
			cycle = true,
			phase = i,
			light = 34,
			spot = true,
			brightness = 3,
			shadows = true,
			shaft = { 11, 0.5, 4 },
		})
	end
	for i, x in { -14, -6, 6, 14 } do
		addStrobe(f, "RoofStrobe" .. i, x - 1.5, y + 13.2, -70.8, x + 1.5, y + 14, -70)
	end

	-- barra del rooftop (este): mostrador, estanteria alta, taburetes y cristaleria
	B(f, "RoofRack", 70, y, -50, 72, y + 10, -10, C.dark, M.Concrete)
	bottleShelf(f, "RoofShelf", 69, y, -50, -10, 1)
	barCounter(f, "RoofBar", 62, -50, 65, -10, y, "W", C.cyan)
	for k = 0, 8 do
		stool(f, "RoofStool" .. k, 58, y, -46 + k * 5, -math.pi / 2)
	end
	glow(f, "RoofRackLed", 72, y, -50, 72.15, y + 10, -10, C.warmWhite, { cycle = true, light = 22 })
	local rx, ry = 63.5, y + 4.5
	cauldron(f, "RoofCauldron", rx, ry, -48.2)
	local rk = { "highball", "martini", "tumbler", "highball", "martini" }
	local rl = { LIQUIDS.cyan, LIQUIDS.pink, LIQUIDS.orange, LIQUIDS.green, LIQUIDS.purple }
	for i, z in { -43.5, -39, -34.5, -30, -25.5 } do
		glassware(f, "RoofGlass" .. i, rx, ry, z, rk[i], rl[i], {
			coaster = true,
			glow = (i % 2 == 0) and VIOLET or C.orange,
			straw = (rk[i] == "highball") and C.white or nil,
			garnish = (rk[i] == "tumbler"),
		})
	end
	shotTray(f, "RoofShots", rx, ry, -19.5, true)
	for i, z in { -45, -15 } do
		pumpkin(f, "RackPumpkin" .. i, 71, y + 10, z, -math.pi / 2, 0.7, { mini = true })
	end

	-- loungers junto a la piscina (oeste y este) y 3 fire pits al oeste
	for i, z in { 31, 40, 49, 58 } do
		lounger(f, "LoungerW" .. i, 6, y, z)
		lounger(f, "LoungerE" .. i, 64, y, z)
	end
	for i, p in { { -44, -26 }, { -44, 12 }, { -44, 50 } } do
		firePit(f, "FirePit" .. i, p[1], y, p[2])
	end

	-- Halloween rooftop: calabazas en el escenario y murcielagos colgados del arco
	for i, sx in { -1, 1 } do
		pumpkin(f, "RoofStagePumpkin" .. i, sx * 27, y + 2.2, -64, math.pi, 0.9, { light = true, range = 18 })
	end
	for i, x in { -27, -21, 21, 27 } do
		hangBat(f, "ArchBat" .. i, x, y + 12, -70, y + 14, 0, 1)
	end

	-- macetas a lo largo del parapeto sur
	for i = 0, 10 do
		local x = -70 + i * 14
		B(f, "Planter" .. i, x - 1.5, y, 75, x + 1.5, y + 2.2, 78, C.dark, M.Concrete)
		ball(f, "PlanterLeaf" .. i, x, y + 4.2, 76.5, 4, C.green, M.Grass)
	end
	fillGrid(f, "Fill3", y + 7, Color3.fromRGB(235, 225, 240), 60, 1.0)
end

------------------------------------------------------------------------
-- Spawn, ambiente y animaciones
------------------------------------------------------------------------
local function buildSpawn()
	local s = Instance.new("SpawnLocation")
	s.Name = "ClubSpawn"
	s.Anchored = true
	s.Size = Vector3.new(8, 0.4, 8)
	local sp = deps.spawn or LAYOUT.spawn -- { x, z }
	s.CFrame = CFrame.new(sp[1], 0.2, sp[2])
	s.Color = C.black
	s.Material = M.SmoothPlastic
	s.Transparency = 1 -- invisible: sin cuadrado sobre la alfombra
	s.CanCollide = false
	s.CastShadow = false
	s.Neutral = true
	s.Duration = 0
	s.TopSurface = Enum.SurfaceType.Smooth
	s.Parent = club
end

-- interfaz: placa LA ALFOMBRA ROJA arriba al centro (logo opcional) que se clona a cada jugador
local function buildUI()
	local StarterGui = game:GetService("StarterGui")
	local old = StarterGui:FindFirstChild("LaAlfombraRojaUI")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LaAlfombraRojaUI"
	gui.ResetOnSpawn = false
	gui.Parent = StarterGui

	local frame = Instance.new("Frame")
	frame.Name = "Badge"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 10)
	frame.Size = UDim2.fromOffset(300, 58)
	frame.BackgroundColor3 = C.navy
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD_TXT
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = frame

	local hasLogo = CONFIG.LogoImageId ~= ""
	if hasLogo then
		local img = Instance.new("ImageLabel")
		img.Name = "Logo"
		img.BackgroundTransparency = 1
		img.Image = CONFIG.LogoImageId
		img.ScaleType = Enum.ScaleType.Fit
		img.Position = UDim2.fromOffset(8, 6)
		img.Size = UDim2.fromOffset(46, 46)
		img.Parent = frame
	end
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(hasLogo and 60 or 12, 4)
	title.Size = UDim2.new(1, hasLogo and -68 or -24, 0, 32)
	title.Font = Enum.Font.Bodoni
	title.RichText = true
	title.Text = brandRich("LA ALFOMBRA ROJA")
	title.TextScaled = true
	title.TextColor3 = GOLD_TXT
	title.TextStrokeColor3 = C.black
	title.TextStrokeTransparency = 0.5
	title.Parent = frame
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(hasLogo and 60 or 12, 36)
	sub.Size = UDim2.new(1, hasLogo and -68 or -24, 0, 16)
	sub.Font = Enum.Font.GothamMedium
	sub.Text = "Zona de fotos - 3 pisos - VIP - Rooftop"
	sub.TextScaled = true
	sub.TextColor3 = C.silver
	sub.Parent = frame
end

local function buildLighting()
	for _, n in { "AlfombraBloom", "AlfombraColor", "AlfombraAtmosphere", "AlfombraDOF" } do
		local o = Lighting:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	-- ambiente base morado oscuro pero legible (en Voxel/Compatibility no hay rebote de luz:
	-- con valores mas bajos el interior se ve negro mientras el motor construye la iluminacion)
	local amb = LOOK.AmbientBoost
	local function boosted(r, g, b)
		return Color3.fromRGB(math.min(255, math.floor(r * amb + 0.5)), math.min(255, math.floor(g * amb + 0.5)), math.min(255, math.floor(b * amb + 0.5)))
	end
	Lighting.Ambient = boosted(54, 48, 52)
	Lighting.OutdoorAmbient = boosted(48, 44, 54)
	Lighting.ExposureCompensation = LOOK.Exposure
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = LOOK.Reflections
	Lighting.ShadowSoftness = LOOK.ShadowSoftness
	Lighting.GlobalShadows = true

	-- bloom moderado: el neon brilla pero no tapa el detalle
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AlfombraBloom"
	bloom.Intensity = LOOK.Bloom.Intensity * PROFILE.bloomScale
	bloom.Size = LOOK.Bloom.Size
	bloom.Threshold = LOOK.Bloom.Threshold
	bloom.Parent = Lighting

	if PROFILE.dof then
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "AlfombraDOF"
		dof.FarIntensity = 0.1
		dof.NearIntensity = 0
		dof.FocusDistance = 45
		dof.InFocusRadius = 70
		dof.Parent = Lighting
	end

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AlfombraColor"
	cc.Contrast = 0.1
	cc.Saturation = -0.08
	cc.TintColor = Color3.fromRGB(255, 243, 230)
	cc.Parent = Lighting

	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
	end
	atm.Name = "AlfombraAtmosphere"
	atm.Density = 0.16
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(150, 128, 120)
	atm.Decay = Color3.fromRGB(78, 62, 58)
	atm.Glare = 0.1
	atm.Haze = 1.2
	atm.Parent = Lighting
end

local function updateBeams(t)
	for _, b in fx.beams do
		local ry = b.yaw + b.swing * math.sin(t * b.speed + b.phase)
		local tip = CFrame.new(b.origin)
			* CFrame.Angles(0, ry, 0)
			* CFrame.Angles(BEAM_PITCH, 0, 0)
			* Vector3.new(0, 0, -BEAM_LEN)
		b.tip.Position = tip - b.origin
	end
end

local function updateMirror(t)
	if #fx.mirror == 0 then
		return
	end
	local spin = CFrame.new(fx.mirror[1].center) * CFrame.Angles(0, t * 0.4, 0)
	for _, m in fx.mirror do
		m.part.CFrame = spin * m.offset
	end
end


-- perfil Equilibrado: quita las luces decorativas menores (velas, calabazas, llamas, calderos, tiras
-- de barra, leds de estanteria y la mitad de los downlights). Las luces de relleno, escaleras y
-- pasillos nunca se tocan.
local function pruneMinorLights()
	if not PROFILE.pruneMinor then
		return
	end
	local patterns = { "Candle", "Pumpkin", "Flame", "Cauldron", "_Strip$", "ShelfLed", "^Downlight$" }
	for _, d in club:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") then
			local n = d.Parent.Name
			for _, pat in patterns do
				if string.find(n, pat) then
					d:Destroy()
					lightCount -= 1
					break
				end
			end
		end
	end
	local keep = {}
	for _, fl in fx.flames do
		if fl.light.Parent ~= nil then
			table.insert(keep, fl)
		end
	end
	fx.flames = keep
	for _, g in fx.glows do
		if g.light and g.light.Parent == nil then
			g.light = nil
		end
	end
end


ctx = {
	Config = CONFIG, club = club, folders = folders, fx = fx, LAYOUT = LAYOUT, PROFILE = PROFILE, PROFILE_NAME = PROFILE_NAME, TILE_COUNT = TILE_COUNT,
	C = C, M = M, P = P, B = B, cyl = cyl, cylZ = cylZ, ball = ball, seg = seg, sign = sign, lamp = lamp, glow = glow, addLight = addLight,
	DECOR = DECOR, LACQUER = LACQUER, MARBLE_W = MARBLE_W, GOLD_TXT = GOLD_TXT, GOLD_DECOR = GOLD_DECOR, GOLD_FX = GOLD_FX, SILVER = SILVER, RED = RED,
	roundTable = roundTable, candleCluster = candleCluster, withShape = withShape, addSeat = addSeat, FLOOR_Y = FLOOR_Y, FLOOR_H = FLOOR_H,
	getLightCount = function() return lightCount end,
}

buildWorld()
buildShell()
buildFloor1()
buildFloor2()
buildFloor3()
buildSpawn()
buildLighting()
buildUI()
if deps.extras then
	deps.extras(ctx)
end
pruneMinorLights()
updateMirror(0)
updateBeams(0)
return ctx
end

return { run = run }
