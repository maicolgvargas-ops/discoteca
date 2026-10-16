--[[
	EXTRAS - lo nuevo de v2 que se construye con geometria sobre el club de Build:
	  * botellas 3D reales en las estanterias (DrinkModels) y lamparas calidas sobre las barras
	  * cabina DJ detallada (doble deck, platos, mezcladora con faders, VU, monitor central, cables)
	  * 2 pantallas de "ahora suena" con visualizador (las anima el cliente)
	  * bartenders (NPC) que abren la tienda, 2 guardias en la entrada, bailarinas en el VIP
	Aqui solo hay GEOMETRIA, prompts (con atributo AR_Action) y etiquetas: la logica de servidor esta en
	Interactions.luau y toda la animacion decorativa la hace el cliente.
]]

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local DrinkModels = require(Shared.DrinkModels)
local Rig = require(Shared.Rig)

local Extras = {}

local function bottleItems()
	local out = {}
	for _, it in Catalog.Items do
		if it.Tier == "bottle" then
			table.insert(out, it)
		end
	end
	return out
end

local function addPrompt(parent, name, action, actionText, objectText, distance)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0.25
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Parent = parent
	p:SetAttribute("AR_Action", action)
	return p
end

------------------------------------------------------------------------
-- Estanterias con botellas 3D (estante central de cada barra)
------------------------------------------------------------------------
function Extras.shelfBottles(ctx, parent, name, x, y, zFrom, zTo, depth, k)
	local items = bottleItems()
	local step = (ctx.PROFILE_NAME == "Alta") and 3.4 or 4.6
	local ry = (x > 0) and math.pi / 2 or -math.pi / 2 -- las etiquetas miran a los clientes
	local z, i = zFrom + 2.4, 0
	while z < zTo - 1.5 do
		i += 1
		local item = items[(i - 1) % #items + 1]
		DrinkModels.build(item, { parent = parent, cframe = CFrame.new(x + depth / 2, y, z) * CFrame.Angles(0, ry, 0), scale = 0.62 })
		z += step
	end
end

function Extras.vipShelfBottles(ctx, parent, name, xFrom, xTo, y, z, k)
	local items = bottleItems()
	local step = (ctx.PROFILE_NAME == "Alta") and 3.6 or 5.2
	local x, i = xFrom + 1.5, 0
	while x < xTo - 1 do
		i += 1
		local item = items[(i + 2) % #items + 1]
		DrinkModels.build(item, { parent = parent, cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.pi, 0), scale = 0.62 })
		x += step
	end
end

-- lamparas colgantes calidas sobre las barras (luz suave, no neon)
local function pendants(ctx, f, name, positions, y0)
	for i, p in positions do
		local x, z = p[1], p[2]
		ctx.B(f, name .. "Rod" .. i, x - 0.06, y0 + 13.4, z - 0.06, x + 0.06, y0 + 21.9, z + 0.06, ctx.C.dark, ctx.M.Metal, ctx.DECOR)
		ctx.cyl(f, name .. "Shade" .. i, x, y0 + 13.1, z, 0.9, 1.7, ctx.C.gold, ctx.M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.5 })
		local bulb = ctx.ball(f, name .. "Bulb" .. i, x, y0 + 12.5, z, 0.6, ctx.C.warmWhite, ctx.M.Neon, ctx.DECOR)
		ctx.addLight(bulb, ctx.C.warmWhite, 22, false, 0.8)
	end
end

------------------------------------------------------------------------
-- Cabina DJ detallada
------------------------------------------------------------------------
function Extras.djBooth(ctx, f, cx, y0, z)
	local C, M, B, P, cyl = ctx.C, ctx.M, ctx.B, ctx.P, ctx.cyl
	local GOLD = { CanCollide = false, CastShadow = false, Reflectance = 0.5 }
	local DK = { CanCollide = false, CastShadow = false, Reflectance = 0.15 }
	local yT = y0 + 3.5
	-- mesa: cuerpo negro lacado con filete dorado y fajas cromadas
	B(f, "DJ_Table", cx - 8.4, y0, z - 1.7, cx + 8.4, yT, z + 1.7, C.black, M.SmoothPlastic, ctx.LACQUER)
	B(f, "DJ_TrimTop", cx - 8.6, yT - 0.12, z - 1.9, cx + 8.6, yT + 0.05, z + 1.9, C.gold, M.Metal, ctx.GOLD_DECOR)
	B(f, "DJ_TrimFront", cx - 8.4, y0 + 0.8, z + 1.7, cx + 8.4, y0 + 1.0, z + 1.78, C.chrome, M.Metal, ctx.GOLD_DECOR)
	B(f, "DJ_TrimFront2", cx - 8.4, y0 + 2.4, z + 1.7, cx + 8.4, y0 + 2.5, z + 1.78, C.gold, M.Metal, ctx.GOLD_DECOR)

	-- DOS DECKS con plato (disco de vinilo), anillo del jog wheel, pantalla, botones y fader de tono
	for side = -1, 1, 2 do
		local dx = cx + side * 5.4
		local tag = side < 0 and "DJ_DeckL" or "DJ_DeckR"
		B(f, tag .. "_Body", dx - 2.2, yT, z - 1.45, dx + 2.2, yT + 0.4, z + 1.45, C.dark, M.Metal, DK)
		cyl(f, tag .. "_Platter", dx - 0.2, yT + 0.46, z + 0.1, 0.12, 2.7, C.black, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.35 })
		cyl(f, tag .. "_Ring", dx - 0.2, yT + 0.53, z + 0.1, 0.05, 2.9, C.chrome, M.Metal, GOLD)
		cyl(f, tag .. "_Groove", dx - 0.2, yT + 0.55, z + 0.1, 0.05, 2.0, C.dark, M.SmoothPlastic, DK)
		cyl(f, tag .. "_Label", dx - 0.2, yT + 0.58, z + 0.1, 0.05, 0.7, C.gold, M.Metal, GOLD)
		cyl(f, tag .. "_Spindle", dx - 0.2, yT + 0.62, z + 0.1, 0.05, 0.12, C.chrome, M.Metal, GOLD)
		-- pantalla del deck (cristal oscuro) y botones play/cue
		B(f, tag .. "_Display", dx - 0.9, yT + 0.4, z + 0.95, dx + 0.5, yT + 0.46, z + 1.35, Color3.fromRGB(14, 20, 26), M.Glass, { CanCollide = false, CastShadow = false, Reflectance = 0.2 })
		for b = 0, 3 do
			local col = (b == 0) and C.gold or C.chrome
			cyl(f, tag .. "_Btn" .. b, dx - 1.9 + b * 0.5, yT + 0.43, z - 1.1, 0.07, 0.34, col, M.Metal, GOLD)
		end
		-- fader de tono
		B(f, tag .. "_PitchSlot", dx + 1.7, yT + 0.4, z - 1.2, dx + 1.82, yT + 0.47, z + 0.8, C.black, M.SmoothPlastic, DK)
		B(f, tag .. "_PitchKnob", dx + 1.55, yT + 0.47, z - 0.4, dx + 1.97, yT + 0.64, z - 0.2, C.chrome, M.Metal, GOLD)
	end

	-- MEZCLADORA central: 4 canales con faders y 3 mandos EQ, crossfader y medidores VU (pocos LED, apagados)
	B(f, "DJ_Mixer", cx - 2.6, yT, z - 1.45, cx + 2.6, yT + 0.45, z + 1.45, C.black, M.SmoothPlastic, { CanCollide = false, Reflectance = 0.25 })
	B(f, "DJ_MixerTrim", cx - 2.7, yT + 0.41, z - 1.5, cx + 2.7, yT + 0.47, z - 1.4, C.gold, M.Metal, GOLD)
	for ch = 0, 3 do
		local fx_ = cx - 1.8 + ch * 1.2
		B(f, "DJ_FaderSlot" .. ch, fx_ - 0.06, yT + 0.45, z - 0.2, fx_ + 0.06, yT + 0.52, z + 1.1, C.dark, M.Metal, DK)
		B(f, "DJ_FaderKnob" .. ch, fx_ - 0.22, yT + 0.52, z + 0.1 + ((ch * 29) % 10) / 14, fx_ + 0.22, yT + 0.72, z + 0.3 + ((ch * 29) % 10) / 14, C.chrome, M.Metal, GOLD)
		for e = 0, 2 do
			local col = (e == 1) and C.gold or C.chrome
			cyl(f, "DJ_Eq" .. ch .. "_" .. e, fx_, yT + 0.52, z - 1.15 + e * 0.38, 0.14, 0.3, col, M.Metal, GOLD)
		end
	end
	B(f, "DJ_CrossSlot", cx - 0.9, yT + 0.45, z + 1.2, cx + 0.9, yT + 0.52, z + 1.3, C.dark, M.Metal, DK)
	B(f, "DJ_CrossKnob", cx - 0.1, yT + 0.52, z + 1.1, cx + 0.3, yT + 0.72, z + 1.4, C.gold, M.Metal, GOLD)
	for col = 0, 1 do
		for seg = 0, 5 do
			local c = (seg < 3) and Color3.fromRGB(40, 120, 60) or ((seg < 5) and Color3.fromRGB(190, 150, 40) or Color3.fromRGB(170, 40, 40))
			B(f, "DJ_Vu" .. col .. "_" .. seg, cx + 1.95 + col * 0.35 - 0.12, yT + 0.45, z - 1.3 + seg * 0.22, cx + 1.95 + col * 0.35 + 0.12, yT + 0.52, z - 1.12 + seg * 0.22, c, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.1 })
		end
	end

	-- MONITOR central sobre soporte cromado (muestra la pista actual; lo actualiza el cliente)
	cyl(f, "DJ_MonitorStand", cx, yT + 1.1, z + 0.9, 1.6, 0.25, C.chrome, M.Metal, GOLD)
	B(f, "DJ_MonitorBase", cx - 0.7, yT, z + 0.55, cx + 0.7, yT + 0.12, z + 1.25, C.chrome, M.Metal, GOLD)
	local mon = P(f, "DJ_Monitor", CFrame.lookAt(Vector3.new(cx, yT + 2.5, z + 0.95), Vector3.new(cx, yT + 2.5, z - 3)), Vector3.new(4.4, 2.2, 0.16), C.black, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.1 })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MonitorGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = mon
	local function lbl(nm, text, y, h, font, tag)
		local tl = Instance.new("TextLabel")
		tl.Name = nm
		tl.BackgroundTransparency = 1
		tl.Position = UDim2.fromScale(0.05, y)
		tl.Size = UDim2.fromScale(0.9, h)
		tl.Text = text
		tl.TextScaled = true
		tl.Font = font
		tl.TextColor3 = ctx.GOLD_TXT
		tl.Parent = gui
		if tag then
			CollectionService:AddTag(tl, tag)
		end
		return tl
	end
	lbl("Caption", "DJ  -  AHORA SUENA", 0.06, 0.16, Enum.Font.GothamMedium)
	lbl("Title", "Sin música configurada", 0.27, 0.34, Enum.Font.Bodoni, "AR_NowTitle")
	lbl("Artist", "", 0.62, 0.2, Enum.Font.Garamond, "AR_NowArtist")
	lbl("State", "", 0.82, 0.14, Enum.Font.GothamMedium, "AR_NowState")
	B(f, "DJ_MonitorFrame", cx - 2.3, yT + 1.3, z + 0.97, cx + 2.3, yT + 1.4, z + 1.07, C.gold, M.Metal, GOLD)

	-- cables discretos: del deck a la mezcladora sobre la mesa, y dos bajan por detras al suelo
	local cableC = Color3.fromRGB(18, 18, 20)
	for i, side in { -1, 1 } do
		local a = Vector3.new(cx + side * 3.2, yT + 0.1, z - 1.3)
		local b = Vector3.new(cx + side * 2.6, yT + 0.1, z - 1.3)
		ctx.seg(f, "DJ_CableMix" .. i, a, b, 0.1, cableC, M.SmoothPlastic, DK)
		ctx.seg(f, "DJ_CableDown" .. i, Vector3.new(cx + side * 6.5, yT - 0.2, z - 1.72), Vector3.new(cx + side * 6.5, y0 + 0.1, z - 2.4), 0.1, cableC, M.SmoothPlastic, DK)
		ctx.seg(f, "DJ_CableFloor" .. i, Vector3.new(cx + side * 6.5, y0 + 0.1, z - 2.4), Vector3.new(cx + side * 4.0, y0 + 0.1, z - 2.6), 0.1, cableC, M.SmoothPlastic, DK)
	end

	-- control interactivo: abre el panel de la cabina (musica y luces)
	local hit = P(f, "DJ_ConsoleHit", CFrame.new(cx, yT + 0.6, z), Vector3.new(5.0, 0.3, 2.4), C.black, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CastShadow = false })
	addPrompt(hit, "DJPrompt", "control", "Abrir mesa de DJ (música y luces)", "Cabina DJ", 12)
	CollectionService:AddTag(hit, "AR_DjConsole")
	-- placa dorada
	ctx.sign(f, "DJ_Plate", cx, y0 + 1.7, z + 1.86, 5.0, 0.8, 0, 1, "MESA DE DJ", ctx.SILVER, false, "chrome")
end

------------------------------------------------------------------------
-- Pantallas "ahora suena" con visualizador (2 en la pared norte)
------------------------------------------------------------------------
local BARS = 24
function Extras.musicScreens(ctx)
	local f = ctx.folders.Floor1
	local C, M, B, P = ctx.C, ctx.M, ctx.B, ctx.P
	for i, x in { -64, 64 } do
		local tag = (i == 1) and "NowPlayingL" or "NowPlayingR"
		B(f, tag .. "_FrameT", x - 10.4, 17.2, -77.7, x + 10.4, 17.6, -77.3, C.gold, M.Metal, ctx.GOLD_DECOR)
		B(f, tag .. "_FrameB", x - 10.4, 5.9, -77.7, x + 10.4, 6.3, -77.3, C.gold, M.Metal, ctx.GOLD_DECOR)
		B(f, tag .. "_FrameL", x - 10.4, 5.9, -77.7, x - 10.0, 17.6, -77.3, C.gold, M.Metal, ctx.GOLD_DECOR)
		B(f, tag .. "_FrameR", x + 10.0, 5.9, -77.7, x + 10.4, 17.6, -77.3, C.gold, M.Metal, ctx.GOLD_DECOR)
		local panel = P(f, tag, CFrame.new(x, 11.75, -77.65), Vector3.new(20, 11, 0.3), C.black, M.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.08 })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "ScreenGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = panel
		local function lbl(nm, text, px, py, w, h, font, color, tag2)
			local tl = Instance.new("TextLabel")
			tl.Name = nm
			tl.BackgroundTransparency = 1
			tl.Position = UDim2.fromScale(px, py)
			tl.Size = UDim2.fromScale(w, h)
			tl.Text = text
			tl.TextScaled = true
			tl.Font = font
			tl.TextColor3 = color
			tl.Parent = gui
			if tag2 then
				CollectionService:AddTag(tl, tag2)
			end
			return tl
		end
		lbl("Caption", "AHORA SUENA", 0.05, 0.05, 0.9, 0.09, Enum.Font.GothamMedium, ctx.GOLD_TXT)
		lbl("Title", "Sin música configurada", 0.05, 0.16, 0.9, 0.22, Enum.Font.Bodoni, Color3.fromRGB(246, 240, 228), "AR_NowTitle")
		lbl("Artist", "", 0.05, 0.4, 0.9, 0.12, Enum.Font.Garamond, ctx.GOLD_TXT, "AR_NowArtist")
		lbl("State", "", 0.05, 0.53, 0.9, 0.08, Enum.Font.GothamMedium, Color3.fromRGB(190, 190, 196), "AR_NowState")
		-- visualizador: 24 barras (las mueve el cliente con la sonoridad REAL del audio; sin audio quedan planas)
		local bw = 0.9 / BARS
		for b = 1, BARS do
			local fr = Instance.new("Frame")
			fr.Name = "Bar" .. b
			fr.BackgroundColor3 = ctx.GOLD_TXT
			fr.BorderSizePixel = 0
			fr.AnchorPoint = Vector2.new(0, 1)
			fr.Position = UDim2.fromScale(0.05 + (b - 1) * bw, 0.88)
			fr.Size = UDim2.fromScale(bw * 0.7, 0.02)
			fr.Parent = gui
			CollectionService:AddTag(fr, "AR_VisBar")
			fr:SetAttribute("Index", b)
		end
		lbl("Note", "Visualizador de audio · no es vídeo", 0.05, 0.9, 0.9, 0.07, Enum.Font.GothamMedium, Color3.fromRGB(140, 140, 148))
	end
end

------------------------------------------------------------------------
-- NPC: bartenders, guardias y bailarinas
------------------------------------------------------------------------
local function npc(ctx, f, tagName, opts)
	opts.parent = f
	local m = Rig.build(opts)
	CollectionService:AddTag(m, tagName)
	return m
end

function Extras.bartenders(ctx)
	if not Config.Npcs.Enabled then
		return
	end
	local list = {
		{ "Bartender_E", ctx.folders.Floor1, Vector3.new(73.3, 0, -30), math.pi / 2, 0, "Hugo" },
		{ "Bartender_W", ctx.folders.Floor1, Vector3.new(-73.3, 0, -30), -math.pi / 2, 0, "Marta" },
		{ "Bartender_VIP", ctx.folders.Floor2, Vector3.new(0, 24, -74.0), math.pi, 0, "Leo" },
		{ "Bartender_Roof", ctx.folders.Floor3, Vector3.new(67.2, 48, -30), math.pi / 2, 0, "Ana" },
	}
	for i, d in list do
		local m = npc(ctx, d[2], "AR_Npc", {
			name = d[1], displayName = "Bartender " .. d[6], outfit = "bartender", cframe = CFrame.new(d[3]) * CFrame.Angles(0, d[4], 0),
			skin = Rig.Skins[(i % #Rig.Skins) + 1], hair = (i % 2 == 0) and Color3.fromRGB(40, 28, 20) or Color3.fromRGB(24, 18, 16),
			hairStyle = (i % 2 == 0) and "bun" or "short",
		})
		m:SetAttribute("AR_Role", "bartender")
		m:SetAttribute("Phase", i * 1.7)
		addPrompt(m:FindFirstChild("HumanoidRootPart"), "ShopPrompt", "shop", "Ver la carta de bebidas", "Bartender " .. d[6], 12)
	end
end

function Extras.guards(ctx, enabled)
	if not (Config.Npcs.Enabled and enabled) then
		return
	end
	local e = ctx.folders.Exterior
	local C, M, B = ctx.C, ctx.M, ctx.B
	local sides = { { -12, "Guardia Iván" }, { 12, "Guardia Rocío" } }
	for i, d in sides do
		local m = npc(ctx, e, "AR_Npc", {
			name = "Guard_" .. i, displayName = d[2], outfit = "guard", scale = 1.18,
			cframe = CFrame.new(d[1], 0, 85.5) * CFrame.Angles(0, math.pi, 0), skin = Rig.Skins[(i * 2) % #Rig.Skins + 1],
			hair = Color3.fromRGB(20, 16, 14), hairStyle = (i == 2) and "bun" or "short",
		})
		m:SetAttribute("AR_Role", "guard")
		m:SetAttribute("Phase", i * 2.3)
		addPrompt(m:FindFirstChild("HumanoidRootPart"), "GuardPrompt", "guard", "Hablar con seguridad", d[2], 12)
	end
	-- barrera de la puerta: invisible y SOLO colisiona con quien aun no ha presentado credencial
	-- (Interactions le asigna el grupo de colision). Cordones y cartel dorados como aviso visual.
	local bar = ctx.B(e, "EntranceBarrier", -10, 0, 80.6, 10, 12, 81.1, C.black, M.SmoothPlastic, { Transparency = 1, CastShadow = false })
	bar:SetAttribute("AR_Role", "entrance_barrier")
	CollectionService:AddTag(bar, "AR_Barrier")
	for _, sx in { -9.4, 9.4 } do
		ctx.cyl(e, "EntryPost", sx, 1.6, 82.2, 3.2, 0.4, C.gold, M.Metal, { CanCollide = false, Reflectance = 0.6 })
		ctx.ball(e, "EntryPostTop", sx, 3.35, 82.2, 0.8, C.gold, M.Metal, { CanCollide = false, Reflectance = 0.6 })
	end
	ctx.seg(e, "EntryRopeA", Vector3.new(-9.4, 3.0, 82.2), Vector3.new(0, 2.3, 82.2), 0.3, ctx.RED, M.Fabric, ctx.DECOR)
	ctx.seg(e, "EntryRopeB", Vector3.new(0, 2.3, 82.2), Vector3.new(9.4, 3.0, 82.2), 0.3, ctx.RED, M.Fabric, ctx.DECOR)
	ctx.sign(e, "EntrySign", 0, 3.2, 82.35, 6.5, 1.1, 0, 1, "CREDENCIAL DEL CLUB", ctx.SILVER, false, "chrome")
end

function Extras.dancers(ctx)
	if not (Config.Npcs.Enabled and Config.Npcs.Dancers > 0) then
		return
	end
	local f = ctx.folders.Floor2
	local C, M = ctx.C, ctx.M
	local y = 24
	local dresses = { Color3.fromRGB(16, 16, 20), Color3.fromRGB(120, 16, 34), Color3.fromRGB(236, 232, 224), Color3.fromRGB(22, 22, 28) }
	local dances = { "suave", "disco", "ola", "lateral" }
	local made = 0
	for pi_, px in { -52, 52 } do
		ctx.cyl(f, "DancePodium" .. pi_, px, y + 0.4, 62, 0.8, 11, C.black, M.SmoothPlastic, { Reflectance = 0.25 })
		ctx.cyl(f, "DancePodiumRing" .. pi_, px, y + 0.82, 62, 0.06, 11.2, C.gold, M.Metal, { CanCollide = false, CastShadow = false, Reflectance = 0.5 })
		for k = 1, 2 do
			if made >= Config.Npcs.Dancers then
				break
			end
			made += 1
			local ox = (k == 1) and -1.9 or 1.9
			local pos = Vector3.new(px + ox, y + 0.8, 62)
			local m = npc(ctx, f, "AR_Npc", {
				name = "Dancer_" .. made, displayName = "Bailarina " .. made, outfit = "dancer", dress = dresses[(made - 1) % #dresses + 1],
				cframe = CFrame.lookAt(pos, Vector3.new(0, y + 0.8, 36)), skin = Rig.Skins[(made % #Rig.Skins) + 1],
				hair = (made % 2 == 0) and Color3.fromRGB(34, 22, 16) or Color3.fromRGB(18, 14, 14), hairStyle = (made % 2 == 0) and "long" or "bun",
			})
			m:SetAttribute("AR_Role", "dancer")
			m:SetAttribute("Dance", dances[(made - 1) % #dances + 1])
			m:SetAttribute("Phase", made * 0.8)
			CollectionService:AddTag(m, "AR_NpcDancer")
		end
	end
end

------------------------------------------------------------------------
-- punto de entrada que Build llama al terminar su construccion
------------------------------------------------------------------------
function Extras.build(ctx, opts)
	opts = opts or {}
	Extras.musicScreens(ctx)
	pendants(ctx, ctx.folders.Floor1, "BarEPendant", { { 69.5, -38 }, { 69.5, -22 } }, 0)
	pendants(ctx, ctx.folders.Floor1, "BarWPendant", { { -69.5, -38 }, { -69.5, -22 } }, 0)
	pendants(ctx, ctx.folders.Floor2, "VipPendant", { { -10, -71.5 }, { 10, -71.5 } }, 24)
	for _, d in ctx.club:GetDescendants() do
		if d.Name == "LightDesk_Top" then
			local p = addPrompt(d, "LightPrompt", "control", "Abrir cabina de luces", "Cabina de luces", 12)
			p:SetAttribute("AR_Tab", "luces")
		end
	end
	for _, d in ctx.club:GetDescendants() do
		if d.Name == "DJPrompt" then
			d:SetAttribute("AR_Tab", "musica")
		end
	end
	Extras.bartenders(ctx)
	Extras.guards(ctx, opts.guards)
	Extras.dancers(ctx)
end

return Extras
