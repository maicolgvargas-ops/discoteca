--[[
	VIPUPGRADE - parche ADITIVO y AUTOCONTENIDO para La Alfombra Roja (ModuleScript en ReplicatedStorage/AlfombraShared).
	No toca ni sustituye ningun otro modulo: musica, inventario, chat, compras y permisos quedan como estan.

	1) CRISTAL DEL VIP (segundo piso, y = 24 hasta el techo inferior y = 46)
	   Cierra con cristal el perimetro del atrio (LAYOUT.atrium) desde el suelo VIP hasta el techo: 4 paneles, cada uno UNA
	   sola pieza COLISIONABLE (no hay dobles paredes). Visualmente es "polarizado" SOLO en tu pantalla:
	     * el servidor deja el panel NEGRO pulido (Transparency = 0): por defecto (sin cliente) se ve oscuro por los dos lados;
	     * el cliente, segun de que lado de cada panel esta TU camara, fija BasePart.LocalTransparencyModifier (propiedad
	       local, no replicada): camara en el VIP -> casi transparente (ves la pista); camara en la pista -> negro.
	   Nunca cambia la Transparency global ni la de otros jugadores. No es privacidad real ni cambia permisos: es solo
	   presentacion (un cliente modificado vera a traves). Opcional (desactivado): piel de cristal interior en el muro
	   exterior (Glass.Exterior = true) con la misma logica "negro desde fuera, transparente desde dentro".

	2) AROS DE FUEGO decorativos (3 en Equilibrado, 4 en Alta) suspendidos del techo del VIP
	   Anillo metalico dorado + banda interior negra (12/16 segmentos), 3 varillas negras hasta el techo, pequenas llamas
	   (ParticleEmitter, sin dano: no hay Touched/Fire/Explosion) repartidas por la circunferencia y UNA PointLight calida por
	   aro, SIN sombras. Todo con CanCollide/CanTouch/CanQuery = false: no bloquean camara, raycasts ni circulacion. Cada aro
	   se comprueba contra la geometria existente (GetPartBoundsInBox) y se OMITE si choca con algo (aviso en Output).
	   El cliente apaga las llamas y la luz de los aros lejanos (localmente) y hace un parpadeo suave de la luz.

	CALIDAD: Equilibrado / Alta = solo cuanto se construye y a que distancia se animan las llamas. Este modulo NUNCA toca
	UserGameSettings, RenderSettings, resolucion ni calidad grafica, ni baja nada automaticamente.

	INTEGRACION MINIMA (ver INTEGRACION_VipUpgrade.md):
	  Servidor (despues de Build.run y de Control.init, p. ej. en init.server tras `Control.init(ctx)`):
	      local VipUpgrade = require(Shared.VipUpgrade)
	      pcall(VipUpgrade.build, ctx)                -- ctx de Build.run (usa ctx.club, ctx.LAYOUT.atrium, ctx.PROFILE_NAME)
	  Cliente (LocalScript, con el club ya en Workspace):
	      pcall(function() require(ReplicatedStorage.AlfombraShared.VipUpgrade).initClient() end)

	AVISO: el comportamiento visual (negro/transparente por lado, aspecto de las llamas) NO ha sido comprobado en Studio; las
	pruebas que acompanan se ejecutan en un simulador.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local VipUpgrade = {}
VipUpgrade.Version = "1.0.0"

------------------------------------------------------------------------
-- Configuracion (puedes pasar un override a build(ctx, opts) / initClient(opts); se mezcla en profundidad)
------------------------------------------------------------------------
VipUpgrade.Config = {
	Enabled = true,
	FloorY = 24, -- cara superior del suelo VIP (Floor2 y2)
	CeilingY = 46, -- cara inferior del techo del VIP
	Atrium = { x1 = -40, z1 = -58, x2 = 40, z2 = 18 }, -- por defecto; se usa ctx.LAYOUT.atrium si existe
	Half = 80, -- mitad del edificio (solo para Glass.Exterior)

	Glass = {
		Enabled = true,
		Inset = 0.5, -- los paneles van 0,5 studs FUERA del atrio, del lado del VIP (la barandilla existente queda dentro)
		Thickness = 0.3,
		Color = { 10, 10, 13 },
		Reflectance = 0.18,
		ClearTransparency = 0.88, -- transparencia efectiva vista desde el lado "claro" (LocalTransparencyModifier)
		Hysteresis = 0.4, -- studs de histeresis para que no parpadee al cruzar el plano
		CullDistance = 260, -- mas lejos que esto el cliente no actualiza el panel
		UpdateHz = 10,
		Exterior = false, -- piel de cristal en el interior del muro exterior (DESACTIVADA: revisa tu fachada antes)
		ExteriorInset = 0.6,
	},

	Rings = {
		Enabled = true,
		Radius = 3.2,
		Height = 13, -- altura del aro sobre el suelo VIP
		RingThickness = 0.3,
		-- centros (x, z) candidatos, en los pasillos entre lounges. Se usan los primeros `count` que quepan.
		Positions = { { -55, -24 }, { 55, -24 }, { -55, 24 }, { 55, 24 } },
		Gold = { 222, 178, 98 },
		Black = { 16, 16, 18 },
		FlameColor = { 255, 150, 50 },
		LightColor = { 255, 170, 90 },
		LightRange = 24,
		LightBrightness = 1.1,
		FlickerHz = 6,
		Profiles = {
			Equilibrado = { count = 3, segments = 12, flames = 6, rate = 6, cull = 90 },
			Alta = { count = 4, segments = 16, flames = 8, rate = 10, cull = 140 },
		},
	},
}

-- mezcla en profundidad los diccionarios; las listas (Positions, colores {r,g,b}) se REEMPLAZAN enteras
local function deepMerge(base, over)
	local out = {}
	for k, v in base do
		out[k] = (type(v) == "table") and deepMerge(v, nil) or v
	end
	if type(over) == "table" then
		for k, v in over do
			if type(v) == "table" and type(out[k]) == "table" and v[1] == nil and out[k][1] == nil then
				out[k] = deepMerge(out[k], v)
			else
				out[k] = v
			end
		end
	end
	return out
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

------------------------------------------------------------------------
-- SERVIDOR
------------------------------------------------------------------------
local FOLDER = "VipUpgrade"

local function newPart(parent, name, cf, size, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local DECOR = { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }

local function buildGlass(folder, cfg, A)
	local g = cfg.Glass
	local H = cfg.CeilingY - cfg.FloorY
	local cy = cfg.FloorY + H / 2
	local t = g.Thickness
	local color = rgb(g.Color)
	local walls = {}
	local ins = g.Inset
	-- normal (nx, nz) = lado CLARO (el VIP, hacia fuera del atrio)
	table.insert(walls, { name = "N", cx = (A.x1 + A.x2) / 2, cz = A.z1 - ins, sx = (A.x2 - A.x1) + 2 * (ins + t / 2), sz = t, nx = 0, nz = -1 })
	table.insert(walls, { name = "S", cx = (A.x1 + A.x2) / 2, cz = A.z2 + ins, sx = (A.x2 - A.x1) + 2 * (ins + t / 2), sz = t, nx = 0, nz = 1 })
	-- W/E se alargan igual que N/S para que las esquinas queden CERRADAS (sin rendija)
	table.insert(walls, { name = "W", cx = A.x1 - ins, cz = (A.z1 + A.z2) / 2, sx = t, sz = (A.z2 - A.z1) + 2 * (ins + t / 2), nx = -1, nz = 0 })
	table.insert(walls, { name = "E", cx = A.x2 + ins, cz = (A.z1 + A.z2) / 2, sx = t, sz = (A.z2 - A.z1) + 2 * (ins + t / 2), nx = 1, nz = 0 })
	if g.Exterior then
		-- piel interior del muro exterior: el lado CLARO es el interior del edificio (normal hacia el centro)
		local h, e = cfg.Half, g.ExteriorInset
		local span = 2 * (h - e)
		table.insert(walls, { name = "XN", cx = 0, cz = -h + e, sx = span, sz = t, nx = 0, nz = 1 })
		table.insert(walls, { name = "XS", cx = 0, cz = h - e, sx = span, sz = t, nx = 0, nz = -1 })
		table.insert(walls, { name = "XW", cx = -h + e, cz = 0, sx = t, sz = span, nx = 1, nz = 0 })
		table.insert(walls, { name = "XE", cx = h - e, cz = 0, sx = t, sz = span, nx = -1, nz = 0 })
	end
	local n = 0
	for _, w in walls do
		local p = newPart(folder, "VipGlass_" .. w.name, CFrame.new(w.cx, cy, w.cz), Vector3.new(w.sx, H, w.sz), color, Enum.Material.Glass, {
			Transparency = 0, -- negro por defecto; el cliente lo aclara SOLO en su pantalla desde el lado del VIP
			Reflectance = g.Reflectance,
			CanCollide = true, -- UNICO colisionable del cierre
			CanTouch = false,
			CastShadow = false,
		})
		p:SetAttribute("nx", w.nx)
		p:SetAttribute("nz", w.nz)
		p:SetAttribute("wall", w.name)
		CollectionService:AddTag(p, "AR_VipGlass")
		n += 1
	end
	return n
end

-- ¿hay geometria colisionable en este volumen? (para no meter un aro dentro de lamparas, escaleras, sofas...)
local function blocked(center, size, ignore)
	local ok, parts = pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:GetPartBoundsInBox(CFrame.new(center), size, params)
	end)
	if not ok then
		return false, nil
	end
	for _, p in parts do
		if p.CanCollide then
			return true, p
		end
	end
	return false, nil
end

local function buildRing(folder, cfg, profile, idx, x, z)
	local R = cfg.Rings
	local y = cfg.FloorY + R.Height
	local top = cfg.CeilingY
	local radius = R.Radius
	local th = R.RingThickness
	local gold, black = rgb(R.Gold), rgb(R.Black)
	local model = Instance.new("Model")
	model.Name = "VipRing" .. idx
	local N = profile.segments
	local chord = 2 * (radius + 0.05) * math.sin(math.pi / N) * 1.04
	local center = Vector3.new(x, y, z)
	-- gold: aro exterior; black: banda interior un poco mas baja
	local flameEvery = math.max(1, math.floor(N / profile.flames))
	local flames = 0
	for k = 0, N - 1 do
		local a = k / N * math.pi * 2
		local rot = CFrame.Angles(0, -(a + math.pi / 2), 0)
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local seg = newPart(model, "RingGold", CFrame.new(pos) * rot, Vector3.new(chord, th, th * 1.1), gold, Enum.Material.Metal, {
			CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.55,
		})
		local inner = center + Vector3.new(math.cos(a) * (radius - th * 1.05), -0.18, math.sin(a) * (radius - th * 1.05))
		newPart(model, "RingBlack", CFrame.new(inner) * rot, Vector3.new(chord * 0.98, th * 0.7, th * 0.9), black, Enum.Material.Metal, {
			CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.3,
		})
		if k % flameEvery == 0 and flames < profile.flames then
			flames += 1
			local att = Instance.new("Attachment")
			att.Name = "FlameAnchor"
			att.Position = Vector3.new(0, th / 2 + 0.05, 0)
			att.Parent = seg
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "Flame"
			pe.Color = ColorSequence.new(rgb(R.FlameColor))
			pe.LightEmission = 1
			pe.LightInfluence = 0
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(0.5, 0.9)
			pe.Speed = NumberRange.new(1.2, 2.2)
			pe.SpreadAngle = Vector2.new(10, 10)
			pe.Rate = profile.rate
			pe.Acceleration = Vector3.new(0, 1.5, 0)
			pe.EmissionDirection = Enum.NormalId.Top
			pe.Parent = att
			CollectionService:AddTag(pe, "AR_VipFlame")
		end
	end
	-- 3 varillas negras desde el aro hasta el techo (techo = cara inferior de la losa del piso 3)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + math.pi / 6
		local rx, rz = x + math.cos(a) * radius, z + math.sin(a) * radius
		local y0 = y + th / 2
		newPart(model, "RingRod", CFrame.new(rx, (y0 + top) / 2, rz), Vector3.new(0.12, top - y0, 0.12), black, Enum.Material.Metal, DECOR)
	end
	-- una luz calida por aro, sin sombras, en una pieza invisible en el centro (no es un objeto fisico)
	local anchor = newPart(model, "RingGlow", CFrame.new(x, y + 0.8, z), Vector3.new(0.2, 0.2, 0.2), black, Enum.Material.SmoothPlastic, {
		CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Name = "RingLight"
	light.Color = rgb(R.LightColor)
	light.Range = R.LightRange
	light.Brightness = R.LightBrightness
	light.Shadows = false -- NUNCA sombras extra
	light.Parent = anchor
	light:SetAttribute("base", R.LightBrightness)
	light:SetAttribute("phase", idx * 1.7)
	CollectionService:AddTag(light, "AR_VipFlameLight")
	model:SetAttribute("cx", x)
	model:SetAttribute("cy", y)
	model:SetAttribute("cz", z)
	model:SetAttribute("cull", profile.cull)
	CollectionService:AddTag(model, "AR_VipRing")
	model.Parent = folder
	return flames
end

-- Construye el cierre de cristal y los aros. ctx = el que devuelve Build.run (usa ctx.club, ctx.LAYOUT.atrium, ctx.PROFILE_NAME).
-- Devuelve un resumen { glass, rings, flames, lights, parts, skipped = { {ring, motivo} } }.
function VipUpgrade.build(ctx, opts)
	if RunService:IsClient() and not RunService:IsServer() then
		return nil
	end
	local cfg = deepMerge(VipUpgrade.Config, opts)
	if cfg.Enabled == false then
		return nil
	end
	local club = (ctx and ctx.club) or Workspace:FindFirstChild("LaAlfombraRoja")
	if not club then
		warn("[VipUpgrade] no encuentro el club (ctx.club / Workspace.LaAlfombraRoja)")
		return nil
	end
	local A = (ctx and ctx.LAYOUT and ctx.LAYOUT.atrium) or cfg.Atrium
	local quality = (opts and opts.quality) or (ctx and ctx.PROFILE_NAME) or "Equilibrado"
	local profile = cfg.Rings.Profiles[quality] or cfg.Rings.Profiles.Equilibrado
	local old = club:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local out = { glass = 0, rings = 0, flames = 0, lights = 0, skipped = {}, quality = quality }
	if cfg.Glass.Enabled then
		out.glass = buildGlass(folder, cfg, A)
	end
	if cfg.Rings.Enabled then
		local placed = 0
		for i, p in cfg.Rings.Positions do
			if placed >= profile.count then
				break
			end
			local x, z = p[1], p[2]
			local R = cfg.Rings.Radius
			local why
			if x - R < A.x2 + 1.5 and x + R > A.x1 - 1.5 and z - R < A.z2 + 1.5 and z + R > A.z1 - 1.5 then
				why = "sobre el atrio (el aro cuelga del techo del VIP, no del atrio)"
			else
				-- volumen del aro + varillas: desde un poco por debajo del aro hasta justo bajo el techo
				local yLow = cfg.FloorY + cfg.Rings.Height - 0.6
				local yHigh = cfg.CeilingY - 0.05
				local hit, who = blocked(Vector3.new(x, (yLow + yHigh) / 2, z), Vector3.new(2 * R + 0.8, yHigh - yLow, 2 * R + 0.8), { folder })
				if hit then
					why = "choca con " .. tostring(who and who.Name)
				end
			end
			if why then
				table.insert(out.skipped, { ring = i, reason = why })
				warn(string.format("[VipUpgrade] aro %d en (%d, %d) omitido: %s", i, x, z, why))
			else
				placed += 1
				out.flames += buildRing(folder, cfg, profile, placed, x, z)
				out.rings += 1
				out.lights += 1
			end
		end
	end
	folder.Parent = club
	local parts = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	out.parts = parts
	print(string.format("[VipUpgrade] %s: %d cristales, %d aros (%d llamas, %d luces sin sombras), %d piezas", quality, out.glass, out.rings, out.flames, out.lights, parts))
	return out
end

------------------------------------------------------------------------
-- CLIENTE (solo presentacion LOCAL: LocalTransparencyModifier, Enabled de llamas/luz y parpadeo)
------------------------------------------------------------------------
local clientHandle

function VipUpgrade.initClient(opts)
	if RunService:IsServer() and not RunService:IsClient() then
		return nil
	end
	if clientHandle then
		return clientHandle
	end
	local cfg = deepMerge(VipUpgrade.Config, opts)
	local G = cfg.Glass
	local panels = {} -- [part] = { nx, nz, clear }
	local rings = {} -- [model] = { cx, cy, cz, cull, emitters = {}, lights = {}, on }
	local connections = {}

	local function addPanel(part)
		if part:IsA("BasePart") then
			panels[part] = { nx = part:GetAttribute("nx") or 0, nz = part:GetAttribute("nz") or 0, clear = nil }
		end
	end
	local function addRing(model)
		rings[model] = { model = model, cx = model:GetAttribute("cx") or 0, cy = model:GetAttribute("cy") or 0, cz = model:GetAttribute("cz") or 0, cull = model:GetAttribute("cull") or 90, on = nil }
	end
	for _, p in CollectionService:GetTagged("AR_VipGlass") do
		addPanel(p)
	end
	for _, m in CollectionService:GetTagged("AR_VipRing") do
		addRing(m)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal("AR_VipGlass"):Connect(addPanel))
	table.insert(connections, CollectionService:GetInstanceAddedSignal("AR_VipRing"):Connect(addRing))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal("AR_VipGlass"):Connect(function(p)
		panels[p] = nil
	end))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal("AR_VipRing"):Connect(function(m)
		rings[m] = nil
	end))

	local acc, slow, clock = 0, 0, 0
	local flickerStep = {}
	local STEPS = { 0.78, 1.0, 0.9 }

	local function updateGlass(camPos)
		for part, info in panels do
			if part.Parent then
				local d = camPos - part.Position
				if d.Magnitude <= G.CullDistance then
					local s = d.X * info.nx + d.Z * info.nz
					local clear = info.clear
					if clear == nil then
						clear = s > 0
					elseif clear then
						clear = s > -G.Hysteresis
					else
						clear = s > G.Hysteresis
					end
					if clear ~= info.clear then
						info.clear = clear
						-- LocalTransparencyModifier es LOCAL (no se replica): efectiva = 1 - (1 - Transparency) * (1 - modifier)
						part.LocalTransparencyModifier = clear and G.ClearTransparency or 0
					end
				end
			end
		end
	end

	local function updateRings(camPos)
		for model, info in rings do
			if model.Parent then
				local d = (camPos - Vector3.new(info.cx, info.cy, info.cz)).Magnitude
				local on = d <= info.cull
				if on ~= info.on then
					info.on = on
					for _, d2 in model:GetDescendants() do
						if d2:IsA("ParticleEmitter") then
							d2.Enabled = on
						elseif d2:IsA("PointLight") then
							d2.Enabled = on
						end
					end
				end
			end
		end
	end

	local function flicker()
		for model, info in rings do
			if info.on and model.Parent then
				for _, l in model:GetDescendants() do
					if l:IsA("PointLight") then
						local base = l:GetAttribute("base") or l.Brightness
						local phase = l:GetAttribute("phase") or 0
						local q = (math.floor(clock * cfg.Rings.FlickerHz + phase) % 3) + 1
						if flickerStep[l] ~= q then
							flickerStep[l] = q
							l.Brightness = base * STEPS[q]
						end
					end
				end
			end
		end
	end

	local period = 1 / G.UpdateHz
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < period then
			return
		end
		local step = acc
		acc = 0
		clock += step
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local pos = cam.CFrame.Position
		updateGlass(pos)
		slow += step
		if slow >= 0.5 then
			slow = 0
			updateRings(pos)
		end
		flicker()
	end))

	clientHandle = {
		panels = panels,
		rings = rings,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			for part in panels do
				if part.Parent then
					part.LocalTransparencyModifier = 0
				end
			end
			clientHandle = nil
		end,
	}
	return clientHandle
end

return VipUpgrade
