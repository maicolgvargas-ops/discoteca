--[[
	DRINKMODELS - botellas, copas y vasos 3D ORIGINALES hechos solo con geometria (Parts) y texto.
	Ningun logo, textura ni asset externo: cada etiqueta es una placa con un SurfaceGui de texto.

	DrinkModels.build(item, opts)  -> Model  (Handle invisible en el centro + piezas soldadas)
	    opts.parent    : donde colgar el modelo
	    opts.cframe    : CFrame de la BASE (centro del fondo) - por defecto el origen
	    opts.scale     : escala (1 = tamaño de exhibicion/vista previa; 0.55 en la mano)
	    opts.tool      : true -> piezas sin anclar, Massless, soldadas al Handle
	    opts.level     : 0..1 nivel inicial del liquido (1 = lleno)
	    opts.noLabels  : true -> sin SurfaceGui (vista previa en ViewportFrame, que no los dibuja)
	DrinkModels.makeTool(item, servingsLeft) -> Tool con Handle y atributos ItemId / Servings
	DrinkModels.setLevel(model, frac)        -> baja/sube el liquido (Weld.C0 + Size del liquido)
	DrinkModels.height(item, scale)          -> altura aproximada para encuadrar la camara
]]

local Catalog = require(script.Parent.Catalog)

local DrinkModels = {}

local function px(v, s)
	return math.max(v * s, 0.05)
end

-- Contexto de construccion: crea piezas en coordenadas locales (sin escalar) respecto a la base.
local function newContext(item, opts)
	local s = opts.scale or 1
	local base = opts.cframe or CFrame.new(0, 0, 0)
	local ctx = { s = s, base = base, parts = {}, liquids = {}, st = item.Style, item = item }
	ctx.model = Instance.new("Model")
	ctx.model.Name = item.Id
	local anchored = not opts.tool

	local function mk(name, cf, size, color, material, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = anchored
		p.CanCollide = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if opts.tool then
			p.Massless = true
		end
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		p.Parent = ctx.model
		table.insert(ctx.parts, p)
		return p
	end

	function ctx.box(name, lx, ly, lz, sx, sy, sz, color, material, props)
		return mk(name, base * CFrame.new(lx * s, ly * s, lz * s), Vector3.new(px(sx, s), px(sy, s), px(sz, s)), color, material, props)
	end
	function ctx.cyl(name, lx, ly, lz, h, d, color, material, props)
		local p = props or {}
		p.Shape = Enum.PartType.Cylinder
		return mk(name, base * CFrame.new(lx * s, ly * s, lz * s) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(px(h, s), px(d, s), px(d, s)), color, material, p)
	end
	function ctx.ball(name, lx, ly, lz, d, color, material, props)
		local p = props or {}
		p.Shape = Enum.PartType.Ball
		return mk(name, base * CFrame.new(lx * s, ly * s, lz * s), Vector3.new(px(d, s), px(d, s), px(d, s)), color, material, p)
	end
	function ctx.wedge(name, lx, ly, lz, sx, sy, sz, color, material, props)
		local p = Instance.new("WedgePart")
		p.Name = name
		p.Anchored = anchored
		p.CanCollide = false
		p.CastShadow = false
		p.Size = Vector3.new(px(sx, s), px(sy, s), px(sz, s))
		p.CFrame = base * CFrame.new(lx * s, ly * s, lz * s)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if opts.tool then
			p.Massless = true
		end
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		p.Parent = ctx.model
		table.insert(ctx.parts, p)
		return p
	end
	-- liquido: cilindro vertical cuya altura se puede cambiar con setLevel
	function ctx.liquid(name, lx, bottomY, lz, fullH, d, color, transparency)
		local level = opts.level or 1
		local h = math.max(fullH * level, 0.05)
		local p = ctx.cyl(name, lx, bottomY + h / 2, lz, h, d, color, Enum.Material.SmoothPlastic, { Transparency = transparency or 0.2, Reflectance = 0.05 })
		p:SetAttribute("FullH", fullH)
		p:SetAttribute("BottomY", bottomY)
		p:SetAttribute("LX", lx)
		p:SetAttribute("LZ", lz)
		p:SetAttribute("Diam", d)
		table.insert(ctx.liquids, p)
		return p
	end
	-- etiqueta: placa (cara frontal = -Z) con lineas de texto legibles
	function ctx.label(name, lx, ly, lz, w, h, color, textColor, lines, fonts)
		local plate = ctx.box(name, lx, ly, lz, w, h, 0.04, color, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
		if opts.noLabels then
			return plate
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LabelGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = math.clamp(160 / math.max(w * s, 0.05), 8, 500)
		gui.LightInfluence = 1
		gui.Parent = plate
		local n = #lines
		local y = 0.06
		local weights = { 0.42, 0.3, 0.22 }
		local total = 0
		for i = 1, n do
			total += weights[math.min(i, 3)]
		end
		for i, text in lines do
			local frac = weights[math.min(i, 3)] / total * 0.88
			local tl = Instance.new("TextLabel")
			tl.Name = "Line" .. i
			tl.BackgroundTransparency = 1
			tl.Position = UDim2.fromScale(0.05, y)
			tl.Size = UDim2.fromScale(0.9, frac)
			tl.Text = text
			tl.TextScaled = true
			tl.Font = (fonts and fonts[i]) or ((i == 1) and Enum.Font.GothamBold or Enum.Font.Garamond)
			tl.TextColor3 = textColor
			tl.Parent = gui
			y += frac
		end
		return plate
	end
	return ctx
end

local KINDS = {}

-- cuerpo de cristal con liquido interior
local function glassBody(ctx, h, d, y0, glassTransparency)
	local st = ctx.st
	return ctx.cyl("Body", 0, y0 + h / 2, 0, h, d, st.glass, Enum.Material.Glass, { Transparency = glassTransparency, Reflectance = 0.12 })
end

KINDS.champagne = function(ctx)
	local st = ctx.st
	ctx.cyl("Foot", 0, 0.05, 0, 0.1, 1.02, st.glass, Enum.Material.Glass, { Transparency = 0.1, Reflectance = 0.15 })
	glassBody(ctx, 2.0, 1.0, 0.1, 0.12)
	ctx.cyl("Shoulder1", 0, 2.25, 0, 0.3, 0.78, st.glass, Enum.Material.Glass, { Transparency = 0.12, Reflectance = 0.15 })
	ctx.cyl("Shoulder2", 0, 2.55, 0, 0.3, 0.58, st.glass, Enum.Material.Glass, { Transparency = 0.12, Reflectance = 0.15 })
	ctx.cyl("Neck", 0, 3.15, 0, 0.9, 0.42, st.glass, Enum.Material.Glass, { Transparency = 0.12, Reflectance = 0.15 })
	ctx.cyl("Foil", 0, 3.3, 0, 0.75, 0.5, st.foil, Enum.Material.Metal, { Reflectance = 0.35 })
	ctx.cyl("FoilTop", 0, 3.7, 0, 0.06, 0.52, st.foil, Enum.Material.Metal, { Reflectance = 0.35 })
	ctx.cyl("Cage", 0, 3.5, 0, 0.06, 0.56, st.accent, Enum.Material.Metal, { Reflectance = 0.5 })
	ctx.cyl("NeckBand", 0, 2.95, 0, 0.16, 0.46, st.accent, Enum.Material.Metal, { Reflectance = 0.4 })
	ctx.liquid("Liquid", 0, 0.14, 0, 1.9, 0.78, st.liquid, 0.55)
	local n = ctx.item.Label
	ctx.label("Label", 0, 1.05, -0.505, 0.62, 1.0, st.label, st.text, n)
	return { handleY = 1.05, height = 3.75 }
end

KINDS.flask = function(ctx)
	local st = ctx.st
	ctx.cyl("Base", 0, 0.14, 0, 0.28, 1.34, st.glass, Enum.Material.Glass, { Transparency = 0.2, Reflectance = 0.2 })
	glassBody(ctx, 1.55, 1.3, 0.28, 0.35)
	ctx.cyl("Shoulder", 0, 1.9, 0, 0.22, 1.1, st.glass, Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.2 })
	ctx.cyl("Neck", 0, 2.45, 0, 0.9, 0.5, st.glass, Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.2 })
	ctx.cyl("Collar", 0, 2.1, 0, 0.12, 0.62, st.accent, Enum.Material.Metal, { Reflectance = 0.5 })
	ctx.cyl("Cork", 0, 3.1, 0, 0.45, 0.58, Color3.fromRGB(182, 142, 92), Enum.Material.Wood, { Reflectance = 0 })
	ctx.cyl("CorkTop", 0, 3.35, 0, 0.06, 0.62, st.foil, Enum.Material.Metal, { Reflectance = 0.3 })
	ctx.liquid("Liquid", 0, 0.32, 0, 1.5, 1.1, st.liquid, 0.3)
	ctx.label("Label", 0, 1.0, -0.655, 0.95, 0.72, st.label, st.text, ctx.item.Label)
	ctx.box("Seal", 0, 1.5, -0.66, 0.5, 0.06, 0.03, st.accent, Enum.Material.Metal, { Reflectance = 0.4 })
	return { handleY = 1.0, height = 3.4 }
end

KINDS.round = function(ctx)
	local st = ctx.st
	ctx.cyl("Foot", 0, 0.08, 0, 0.16, 0.95, st.glass, Enum.Material.SmoothPlastic, { Reflectance = 0.25 })
	ctx.ball("Body", 0, 0.9, 0, 1.7, st.glass, Enum.Material.SmoothPlastic, { Reflectance = 0.25 })
	ctx.cyl("Band", 0, 0.9, 0, 0.32, 1.74, st.accent, Enum.Material.SmoothPlastic, { Reflectance = 0.2 })
	ctx.cyl("Neck", 0, 1.95, 0, 0.7, 0.5, st.glass, Enum.Material.SmoothPlastic, { Reflectance = 0.25 })
	ctx.cyl("Stopper", 0, 2.7, 0, 0.85, 0.62, st.foil, Enum.Material.Metal, { Reflectance = 0.45 })
	ctx.cyl("StopperRing", 0, 2.35, 0, 0.1, 0.68, st.accent, Enum.Material.Metal, { Reflectance = 0.4 })
	ctx.ball("StopperTop", 0, 3.15, 0, 0.62, st.foil, Enum.Material.Metal, { Reflectance = 0.45 })
	ctx.ball("Window", 0, 0.9, 0, 0.5, st.liquid, Enum.Material.SmoothPlastic, { Transparency = 0.6 })
	ctx.label("Label", 0, 0.9, -0.88, 0.95, 0.5, st.label, st.text, ctx.item.Label)
	ctx.liquid("Liquid", 0, 0.5, 0, 0.8, 0.5, st.liquid, 0.7)
	return { handleY = 0.9, height = 3.5 }
end

KINDS.square = function(ctx)
	local st = ctx.st
	ctx.box("Body", 0, 0.95, 0, 1.3, 1.8, 1.3, st.glass, Enum.Material.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	ctx.box("Shoulder", 0, 2.0, 0, 0.95, 0.25, 0.95, st.glass, Enum.Material.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	ctx.cyl("Neck", 0, 2.5, 0, 0.75, 0.5, st.glass, Enum.Material.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	ctx.cyl("Cork", 0, 3.05, 0, 0.4, 0.56, Color3.fromRGB(190, 150, 100), Enum.Material.Wood, { Reflectance = 0 })
	ctx.cyl("Band", 0, 2.85, 0, 0.14, 0.6, st.foil, Enum.Material.SmoothPlastic, { Reflectance = 0.1 })
	ctx.liquid("Liquid", 0, 0.12, 0, 1.7, 1.12, st.liquid, 0.5)
	ctx.label("Label", 0, 1.0, -0.665, 0.9, 0.75, st.label, st.text, ctx.item.Label)
	return { handleY = 1.0, height = 3.3 }
end

KINDS.whisky = function(ctx)
	local st = ctx.st
	ctx.cyl("Foot", 0, 0.06, 0, 0.12, 1.12, st.glass, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.15 })
	glassBody(ctx, 2.2, 1.1, 0.12, 0.4)
	ctx.cyl("Shoulder", 0, 2.45, 0, 0.3, 0.82, st.glass, Enum.Material.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	ctx.cyl("Neck", 0, 2.95, 0, 0.7, 0.5, st.glass, Enum.Material.Glass, { Transparency = 0.4, Reflectance = 0.15 })
	ctx.cyl("Stopper", 0, 3.5, 0, 0.5, 0.56, st.foil, Enum.Material.Wood, { Reflectance = 0.05 })
	ctx.cyl("StopperTop", 0, 3.77, 0, 0.06, 0.6, st.accent, Enum.Material.Metal, { Reflectance = 0.5 })
	ctx.liquid("Liquid", 0, 0.16, 0, 2.1, 0.92, st.liquid, 0.35)
	ctx.label("Label", 0, 1.15, -0.555, 0.84, 1.1, st.label, st.text, ctx.item.Label)
	ctx.box("NeckTag", 0, 2.7, -0.27, 0.34, 0.2, 0.03, st.accent, Enum.Material.Metal, { Reflectance = 0.4 })
	return { handleY = 1.2, height = 3.85 }
end

KINDS.shot = function(ctx)
	local st = ctx.st
	ctx.cyl("Base", 0, 0.12, 0, 0.24, 0.8, st.glass, Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.2 })
	ctx.cyl("Body", 0, 0.62, 0, 0.8, 0.82, st.glass, Enum.Material.Glass, { Transparency = 0.6, Reflectance = 0.15 })
	ctx.liquid("Liquid", 0, 0.24, 0, 0.62, 0.66, st.liquid, 0.25)
	ctx.cyl("SaltRim", 0, 1.03, 0, 0.04, 0.84, Color3.fromRGB(246, 246, 250), Enum.Material.SmoothPlastic, { Transparency = 0.15 })
	-- cuña de lima apoyada en el borde
	ctx.wedge("Lime", 0.42, 1.12, 0, 0.62, 0.3, 0.16, st.foil, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
	ctx.wedge("LimeFlesh", 0.42, 1.12, -0.09, 0.5, 0.22, 0.04, Color3.fromRGB(176, 218, 96), Enum.Material.SmoothPlastic)
	return { handleY = 0.6, height = 1.3 }
end

KINDS.flute = function(ctx)
	local st = ctx.st
	ctx.cyl("Foot", 0, 0.04, 0, 0.08, 0.8, st.glass, Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.2 })
	ctx.cyl("Stem", 0, 0.62, 0, 1.1, 0.12, st.glass, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.2 })
	ctx.cyl("BowlLow", 0, 1.3, 0, 0.35, 0.32, st.glass, Enum.Material.Glass, { Transparency = 0.45, Reflectance = 0.15 })
	ctx.cyl("Bowl", 0, 1.95, 0, 1.0, 0.54, st.glass, Enum.Material.Glass, { Transparency = 0.6, Reflectance = 0.15 })
	ctx.liquid("Liquid", 0, 1.45, 0, 0.95, 0.44, st.liquid, 0.3)
	for i, b in { { 0.05, 1.7, 0.05 }, { -0.08, 1.95, -0.02 }, { 0.02, 2.2, 0.08 } } do
		ctx.ball("Bubble" .. i, b[1], b[2], b[3], 0.07, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Transparency = 0.35 })
	end
	return { handleY = 1.0, height = 2.5 }
end

KINDS.tumbler = function(ctx)
	local st = ctx.st
	ctx.cyl("Base", 0, 0.14, 0, 0.28, 1.02, st.glass, Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.2 })
	ctx.cyl("Body", 0, 0.7, 0, 0.84, 1.04, st.glass, Enum.Material.Glass, { Transparency = 0.62, Reflectance = 0.15 })
	ctx.liquid("Liquid", 0, 0.28, 0, 0.58, 0.88, st.liquid, 0.25)
	ctx.box("Ice1", -0.18, 0.78, 0.05, 0.34, 0.34, 0.34, Color3.fromRGB(232, 244, 252), Enum.Material.Glass, { Transparency = 0.35, Reflectance = 0.25 })
	ctx.box("Ice2", 0.2, 0.74, -0.1, 0.3, 0.3, 0.3, Color3.fromRGB(232, 244, 252), Enum.Material.Glass, { Transparency = 0.35, Reflectance = 0.25 })
	return { handleY = 0.6, height = 1.2 }
end

-- API ------------------------------------------------------------------------

function DrinkModels.build(item, opts)
	opts = opts or {}
	local kind = KINDS[item.Kind]
	assert(kind, "DrinkModels: tipo de modelo desconocido " .. tostring(item.Kind))
	local ctx = newContext(item, opts)
	local info = kind(ctx)
	local s = ctx.s
	-- Handle invisible, sin rotar (ejes alineados con el mundo), en el centro de agarre
	local handle = ctx.box("Handle", 0, info.handleY, 0, 0.3, 0.3, 0.3, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, { Transparency = 1 })
	ctx.model.PrimaryPart = handle
	ctx.model:SetAttribute("ItemId", item.Id)
	ctx.model:SetAttribute("HandleY", info.handleY)
	ctx.model:SetAttribute("Height", info.height * s)
	ctx.model:SetAttribute("Scale", s)
	if opts.tool then
		for _, p in ctx.parts do
			if p ~= handle then
				if p:GetAttribute("FullH") then
					local w = Instance.new("Weld")
					w.Name = "LiquidWeld"
					w.Part0 = handle
					w.Part1 = p
					w.C0 = handle.CFrame:Inverse() * p.CFrame
					w.Parent = p
				else
					local w = Instance.new("WeldConstraint")
					w.Part0 = handle
					w.Part1 = p
					w.Parent = p
				end
			end
		end
	end
	if opts.parent then
		ctx.model.Parent = opts.parent
	end
	return ctx.model, info
end

-- ajusta el nivel del liquido (solo para modelos tool soldados con Weld)
function DrinkModels.setLevel(model, frac)
	frac = math.clamp(frac, 0, 1)
	local s = model:GetAttribute("Scale") or 1
	local hy = model:GetAttribute("HandleY") or 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("FullH") then
			local full, by = p:GetAttribute("FullH"), p:GetAttribute("BottomY")
			local lx, lz, d = p:GetAttribute("LX"), p:GetAttribute("LZ"), p:GetAttribute("Diam")
			local h = math.max(full * frac, 0.05)
			p.Size = Vector3.new(math.max(h * s, 0.05), math.max(d * s, 0.05), math.max(d * s, 0.05))
			p.Transparency = (frac <= 0.01) and 1 or p.Transparency
			local weld = p:FindFirstChild("LiquidWeld")
			local rel = CFrame.new(lx * s, (by + h / 2 - hy) * s, lz * s) * CFrame.Angles(0, 0, math.pi / 2)
			if weld then
				weld.C0 = rel
			else
				local par = model.PrimaryPart
				if par then
					p.CFrame = par.CFrame * rel
				end
			end
		end
	end
end

function DrinkModels.height(item, scale)
	local ctx = newContext(item, { scale = 1, cframe = CFrame.new(0, 0, 0) })
	local info = KINDS[item.Kind](ctx)
	return info.height * (scale or 1)
end

-- Tool para el Backpack: solo geometria + atributos. La logica (sorbos) la lleva el servidor.
function DrinkModels.makeTool(item, servingsLeft)
	local tier = Catalog.Tiers[item.Tier]
	local total = tier.Servings
	local left = servingsLeft or total
	local scale = (item.Tier == "bottle") and 0.5 or 0.8
	local tool = Instance.new("Tool")
	tool.Name = Catalog.displayName(item)
	tool.ToolTip = Catalog.displayName(item)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local model = DrinkModels.build(item, { tool = true, scale = scale, level = math.clamp(left / total, 0.05, 1) })
	for _, p in model:GetChildren() do
		p.Parent = tool
	end
	tool:SetAttribute("ItemId", item.Id)
	tool:SetAttribute("Servings", left)
	tool:SetAttribute("MaxServings", total)
	tool:SetAttribute("HandleY", model:GetAttribute("HandleY"))
	tool:SetAttribute("Scale", scale)
	model:Destroy()
	-- agarre: el centro del Handle queda en la mano, la botella en vertical (ajustable en Studio)
	tool.GripPos = Vector3.new(0, 0, 0)
	return tool
end

return DrinkModels
