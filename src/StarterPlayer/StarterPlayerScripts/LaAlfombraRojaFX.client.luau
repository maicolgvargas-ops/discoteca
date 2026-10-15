--[[
	LA ALFOMBRA ROJA - efectos de cliente y panel de control de luces (LocalScript).

	* Anima SOLO en tu pantalla: pista LED, neones, laseres, focos, bola de espejos, estrobo y
	  parpadeo de llamas. Nada de esto se replica desde el servidor (fluidez de red).
	* Lee el estado compartido (atributos de LaAlfombraRoja.Control) y lo aplica a las luces; asi
	  todos los jugadores ven lo mismo cuando el operador cambia algo.
	* Ofrece el panel en espanol de la cabina de luces (se abre con la tecla E junto a la cabina).
	* No toca tu configuracion grafica: solo reduce la frecuencia de sus propias animaciones si tu
	  equipo va justo (y se aleja cuando estas lejos del club).

	Colocalo en StarterPlayer > StarterPlayerScripts con el nombre LaAlfombraRojaFX (el .rbxlx ya lo
	trae; con el .rbxmx el Script del servidor lo copia por ti).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local club = Workspace:WaitForChild("LaAlfombraRoja", 60)
if not club then
	return
end
local control = club:WaitForChild("Control", 30)
if not control then
	return
end

------------------------------------------------------------------------
-- Estado compartido
------------------------------------------------------------------------
local S = {}
local KEYS = { "Preset", "Master", "ZPista", "ZVip", "ZRooftop", "ZAlfombra", "OnPista", "OnVip", "OnRooftop", "OnAlfombra", "Lasers", "Shafts", "SpotMove", "Pulse", "Speed", "MirrorSpin", "MirrorSpeed", "Strobe", "Palette", "Operator", "OperatorName" }
local function readState()
	for _, k in KEYS do
		S[k] = control:GetAttribute(k)
	end
end
readState()
local SAFE_MIN = 0.45 -- las luces de seguridad (pasillos, escaleras) nunca bajan de este nivel
local STROBE_HZ = 2.5 -- frecuencia maxima del estrobo (< 3 destellos por segundo)

local function zoneFactor(zone, safe)
	if zone == "Ext" or zone == nil then
		return 1
	end
	local f = (S.Master or 1) * (S["Z" .. zone] or 1)
	if S["On" .. zone] == false then
		f = 0
	end
	if safe then
		f = math.max(f, SAFE_MIN)
	end
	return math.min(f, 1.5) -- tope de intensidad: nunca mas del 150 % del brillo base
end

------------------------------------------------------------------------
-- Paletas (colores) y utilidades
------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function mix(c1, c2, a)
	return Color3.new(c1.R + (c2.R - c1.R) * a, c1.G + (c2.G - c1.G) * a, c1.B + (c2.B - c1.B) * a)
end
local function scale(c, k)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end
local PAL = {
	Champan = { glowA = rgb(236, 196, 138), glowB = rgb(214, 230, 242), lampA = rgb(255, 226, 190), lampB = rgb(240, 230, 246), tileA = rgb(255, 214, 160), tileB = rgb(205, 224, 245), txtA = rgb(246, 240, 228), txtB = rgb(238, 198, 140) },
	Hielo = { glowA = rgb(200, 225, 245), glowB = rgb(235, 242, 250), lampA = rgb(230, 238, 250), lampB = rgb(250, 250, 255), tileA = rgb(190, 215, 245), tileB = rgb(235, 240, 250), txtA = rgb(235, 242, 250), txtB = rgb(190, 215, 245) },
	Rosa = { glowA = rgb(236, 170, 170), glowB = rgb(255, 206, 200), lampA = rgb(255, 214, 205), lampB = rgb(250, 190, 210), tileA = rgb(255, 170, 190), tileB = rgb(255, 214, 200), txtA = rgb(255, 214, 205), txtB = rgb(240, 160, 180) },
	Violeta = { glowA = rgb(176, 150, 230), glowB = rgb(210, 190, 250), lampA = rgb(225, 215, 250), lampB = rgb(200, 180, 245), tileA = rgb(160, 130, 225), tileB = rgb(205, 185, 250), txtA = rgb(225, 215, 250), txtB = rgb(176, 150, 230) },
	Rojo = { glowA = rgb(214, 40, 52), glowB = rgb(255, 120, 90), lampA = rgb(255, 190, 170), lampB = rgb(255, 150, 120), tileA = rgb(200, 30, 46), tileB = rgb(255, 130, 100), txtA = rgb(255, 214, 190), txtB = rgb(230, 70, 60) },
	Multicolor = { rainbow = true, glowA = rgb(255, 180, 90), glowB = rgb(120, 200, 255), lampA = rgb(255, 230, 200), lampB = rgb(220, 230, 255), tileA = rgb(255, 160, 90), tileB = rgb(120, 190, 255), txtA = rgb(255, 235, 200), txtB = rgb(190, 220, 255) },
}
local function pal()
	return PAL[S.Palette] or PAL.Champan
end

------------------------------------------------------------------------
-- Registros: todo lo etiquetado por el servidor (tambien lo que llegue mas tarde)
------------------------------------------------------------------------
local reg = { tile = {}, glow = {}, lamp = {}, light = {}, strobe = {}, laser = {}, mirror = {}, flame = {}, sign = {}, screen = {}, shaft = {}, spot = {}, status = {}, desk = {} }
local function firstLight(inst)
	return inst:FindFirstChildOfClass("PointLight") or inst:FindFirstChildOfClass("SpotLight")
end
local HANDLERS = {
	AR_Tile = function(i)
		reg.tile[i] = { part = i, ix = i:GetAttribute("ix"), iz = i:GetAttribute("iz"), n = i:GetAttribute("n"), dim = i:GetAttribute("dim") or 1 }
	end,
	AR_Glow = function(i)
		reg.glow[i] = { part = i, light = firstLight(i), phase = i:GetAttribute("phase") or 0, zone = i:GetAttribute("z") }
	end,
	AR_Lamp = function(i)
		reg.lamp[i] = { part = i, light = firstLight(i), phase = i:GetAttribute("phase") or 0 }
	end,
	AR_Light = function(i)
		reg.light[i] = { zone = i:GetAttribute("z"), safe = i:GetAttribute("safe") == true, base = i:GetAttribute("b") or i.Brightness }
	end,
	AR_Strobe = function(i)
		local l = firstLight(i)
		if l then
			l.Brightness = math.min(l.Brightness, 2.5) -- brillo moderado
		end
		reg.strobe[i] = { part = i, light = l, on = false }
	end,
	AR_Laser = function(i)
		local head = i.Parent
		local beams = {}
		if head then
			for _, c in head:GetChildren() do
				if c:IsA("Beam") and c.Attachment1 == i then
					table.insert(beams, c)
				end
			end
		end
		reg.laser[i] = { att = i, head = head, beams = beams, o = i:GetAttribute("o"), yaw = i:GetAttribute("yaw") or 0, swing = i:GetAttribute("swing") or 0.4, speed = i:GetAttribute("speed") or 1, phase = i:GetAttribute("phase") or 0 }
	end,
	AR_Mirror = function(i)
		reg.mirror[i] = { part = i }
	end,
	AR_Flame = function(i)
		reg.flame[i] = { light = i, base = i:GetAttribute("base") or i.Brightness, phase = i:GetAttribute("phase") or 0 }
	end,
	AR_Sign = function(i)
		reg.sign[i] = { label = i, phase = i:GetAttribute("phase") or 0 }
	end,
	AR_Screen = function(i)
		reg.screen[i] = { label = i }
	end,
	AR_Shaft = function(i)
		reg.shaft[i] = { beam = i, zone = i:GetAttribute("z") }
	end,
	AR_Spot = function(i)
		reg.spot[i] = { part = i, base = i.CFrame, phase = i:GetAttribute("phase") or 0, moved = false }
	end,
	AR_Status = function(i)
		reg.status[i] = { label = i }
	end,
	AR_Desk = function(i)
		reg.desk[i] = { part = i }
	end,
}
local TAG_TABLE = { AR_Tile = "tile", AR_Glow = "glow", AR_Lamp = "lamp", AR_Light = "light", AR_Strobe = "strobe", AR_Laser = "laser", AR_Mirror = "mirror", AR_Flame = "flame", AR_Sign = "sign", AR_Screen = "screen", AR_Shaft = "shaft", AR_Spot = "spot", AR_Status = "status", AR_Desk = "desk" }
for tag, fn in HANDLERS do
	for _, inst in CollectionService:GetTagged(tag) do
		fn(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		reg[TAG_TABLE[tag]][inst] = nil
	end)
end

------------------------------------------------------------------------
-- Aplicar el estado a luces y haces (solo al cambiar el estado, como maximo 10 veces por segundo)
------------------------------------------------------------------------
local dirty = true
local paletteVersion = 0
local function applyState()
	dirty = false
	for light, info in reg.light do
		local f = zoneFactor(info.zone, info.safe)
		light.Brightness = info.base * f
		light.Enabled = f > 0.01
	end
	local pistaOn = zoneFactor("Pista", false) > 0.01
	for _, l in reg.laser do
		for _, b in l.beams do
			b.Enabled = S.Lasers == true and pistaOn
		end
	end
	for _, sh in reg.shaft do
		sh.beam.Enabled = S.Shafts == true and zoneFactor(sh.zone, false) > 0.01
	end
	for _, sp in reg.spot do
		if not S.SpotMove and sp.moved then
			sp.part.CFrame = sp.base
			sp.moved = false
		end
	end
	if not S.Strobe then
		for _, st in reg.strobe do
			if st.on then
				st.on = false
				st.part.Color = Color3.fromRGB(26, 26, 30)
				if st.light then
					st.light.Enabled = false
				end
			end
		end
	end
	paletteVersion += 1
end
for _, k in KEYS do
	control:GetAttributeChangedSignal(k):Connect(function()
		S[k] = control:GetAttribute(k)
		dirty = true
	end)
end

------------------------------------------------------------------------
-- Animaciones locales
------------------------------------------------------------------------
local QUALITY = club:GetAttribute("Quality") or "Equilibrado"
local RATE = QUALITY == "Alta" and { fast = 0.033, tiles = 0.125, glows = 0.2, mirror = 0.08 } or { fast = 0.05, tiles = 0.2, glows = 0.25, mirror = 0.15 }
local GLOW_STEPS = 16
local LAMP_STEPS = 8
local FLICKER = { 0.75, 1.0, 0.88 }
local SCREEN_TEXTS = { "LA ALFOMBRA ROJA", "ALFOMBRA", "ROJA", "LET'S GO", "LA ALFOMBRA ROJA" }
local function brandRich(text)
	return (string.gsub(text, "ROJA", '<font color="#D4182A">ROJA</font>'))
end
local center = club:GetAttribute("MirrorCenter") or Vector3.new(0, 36, -24)
local clubCenter = Vector3.new(0, 20, 0)
local acc = { fast = 0, tiles = 0, glows = 0, mirror = 0, near = 0, applied = 0 }
local t, rt, mirrorAng = 0, 0, 0
local avgDt = 1 / 60
local near = true
local lastScreen = 0
local tileKey, glowKey = {}, {}
local lastPalette = -1

local function animate(dt)
	-- frecuencia adaptativa: si tu equipo va justo, las animaciones decorativas se espacian
	avgDt = avgDt * 0.95 + dt * 0.05
	local th = avgDt > 1 / 28 and 3 or (avgDt > 1 / 42 and 2 or 1)
	acc.applied += dt
	if dirty and acc.applied >= 0.1 then
		acc.applied = 0
		applyState()
	end
	acc.near += dt
	if acc.near >= 0.5 then
		acc.near = 0
		local cam = Workspace.CurrentCamera
		near = cam == nil or (cam.CFrame.Position - clubCenter).Magnitude < 240
	end
	if not near then
		return
	end
	local sp = S.Speed or 0.6
	t += dt * sp
	rt += dt
	local P = pal()
	local pistaF = zoneFactor("Pista", false)
	if lastPalette ~= paletteVersion then
		lastPalette = paletteVersion
		tileKey, glowKey = {}, {}
	end
	for k, v in acc do
		if k ~= "near" and k ~= "applied" then
			acc[k] = v + dt
		end
	end

	if acc.fast >= RATE.fast * th then
		acc.fast = 0
		-- laseres
		if S.Lasers and pistaF > 0.01 then
			for _, l in reg.laser do
				if l.o and l.head then
					local ry = l.yaw + l.swing * math.sin(t * l.speed + l.phase)
					local tip = CFrame.new(l.o) * CFrame.Angles(0, ry, 0) * CFrame.Angles(math.rad(-68), 0, 0) * Vector3.new(0, 0, -43)
					l.att.Position = tip - l.head.CFrame.Position
				end
			end
		end
		-- movimiento de focos
		if S.SpotMove then
			for _, spt in reg.spot do
				spt.moved = true
				spt.part.CFrame = spt.base * CFrame.Angles(0.35 * math.sin(t * 0.8 + spt.phase), 0, 0.5 * math.sin(t * 0.6 + spt.phase * 1.3))
			end
		end
		-- estrobo: opcional y apagado de inicio; rafagas de 2 s cada 8 s a <= 2.5 destellos/s
		if S.Strobe then
			local on = (rt % 8) < 2 and (math.floor(rt * STROBE_HZ * 2) % 2 == 0)
			for _, st in reg.strobe do
				if st.on ~= on then
					st.on = on
					st.part.Color = on and Color3.new(1, 1, 1) or Color3.fromRGB(26, 26, 30)
					if st.light then
						st.light.Enabled = on
					end
				end
			end
		end
	end

	if acc.mirror >= RATE.mirror * th then
		local elapsed = acc.mirror
		acc.mirror = 0
		if S.MirrorSpin then
			mirrorAng += elapsed * 0.4 * (S.MirrorSpeed or 0.5)
			local spin = CFrame.new(center) * CFrame.Angles(0, mirrorAng, 0)
			for _, m in reg.mirror do
				if not m.offset then
					m.offset = CFrame.new(center):Inverse() * m.part.CFrame
				end
				m.part.CFrame = spin * m.offset
			end
		end
	end

	if acc.tiles >= RATE.tiles * th then
		acc.tiles = 0
		for _, tile in reg.tile do
			local dx, dz = tile.ix - (tile.n - 1) / 2, tile.iz - (tile.n - 1) / 2
			local d = math.sqrt(dx * dx + dz * dz)
			local wave = 0.5 + 0.5 * math.sin(d * 0.75 * (12 / tile.n) - t * 2.4)
			local tone = S.Pulse and (0.5 + 0.5 * math.sin(t * 0.3 + d * 0.15)) or 0
			local v = (0.16 + 0.5 * wave) * tile.dim * 0.7 * math.min(1.2, pistaF)
			local tq, vq = math.floor(tone * 6 + 0.5), math.floor(v * 12 + 0.5)
			local hq = P.rainbow and math.floor(((t * 0.04 + d * 0.02) % 1) * 24) or 0
			local key = (tq * 16 + vq) * 32 + hq
			if tileKey[tile] ~= key then
				tileKey[tile] = key
				local c = P.rainbow and Color3.fromHSV(hq / 24, 0.7, 1) or mix(P.tileA, P.tileB, tq / 6)
				tile.part.Color = scale(c, vq / 12)
			end
		end
	end

	if acc.glows >= RATE.glows * th then
		acc.glows = 0
		for _, g in reg.glow do
			local zf = math.min(1, zoneFactor(g.zone, false))
			local q = S.Pulse and math.floor((0.5 + 0.5 * math.sin(t * 0.6 + g.phase)) * GLOW_STEPS + 0.5) or 0
			local hq = P.rainbow and math.floor(((t * 0.05 + g.phase * 0.1) % 1) * 24) or 0
			local key = (q * 32 + math.floor(zf * 8)) * 32 + hq
			if glowKey[g] ~= key then
				glowKey[g] = key
				local c = P.rainbow and Color3.fromHSV(hq / 24, 0.65, 1) or mix(P.glowA, P.glowB, q / GLOW_STEPS)
				g.part.Color = scale(c, 0.72 * zf)
				if g.light then
					g.light.Color = c
				end
			end
		end
		for _, l in reg.lamp do
			if l.light then
				local q = S.Pulse and math.floor((0.5 + 0.5 * math.sin(t * 0.35 + l.phase)) * LAMP_STEPS + 0.5) or 0
				local key = q + 100 * paletteVersion
				if l.key ~= key then
					l.key = key
					l.light.Color = mix(P.lampA, P.lampB, q / LAMP_STEPS)
				end
			end
		end
		for _, fl in reg.flame do
			local q = (math.floor(rt * 6 + fl.phase) % 3) + 1
			if q ~= fl.q then
				fl.q = q
				fl.light.Brightness = fl.base * FLICKER[q]
			end
		end
		for _, sg in reg.sign do
			sg.label.TextColor3 = S.Pulse and mix(P.txtA, P.txtB, 0.5 + 0.5 * math.sin(t * 0.6 + sg.phase)) or P.txtB
		end
		local idx = math.floor(rt / 3) % #SCREEN_TEXTS + 1
		if idx ~= lastScreen then
			lastScreen = idx
			for _, sc in reg.screen do
				sc.label.Text = brandRich(SCREEN_TEXTS[idx])
			end
		end
	end
end

------------------------------------------------------------------------
-- Panel de control en espanol
------------------------------------------------------------------------
local GOLD = rgb(232, 188, 98)
local BLACK = rgb(14, 14, 16)
local PANEL = rgb(24, 24, 28)
local ON_COL = rgb(150, 112, 40)
local remotes = ReplicatedStorage:WaitForChild("AlfombraControl", 30)
local request = remotes and remotes:WaitForChild("Request", 10)
local notice = remotes and remotes:WaitForChild("Notice", 10)
local ui = { gui = nil, open = false, widgets = {}, lastSend = 0, toast = nil, toastUntil = 0, toastGui = nil }

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function send(action, value)
	if not request then
		return
	end
	local now = os.clock()
	if now - ui.lastSend < 0.12 then -- maximo ~8 peticiones por segundo desde la interfaz
		return
	end
	ui.lastSend = now
	request:FireServer(action, value)
end

local function toastMsg(text)
	if not ui.toast then
		local pg = player:WaitForChild("PlayerGui")
		ui.toastGui = make("ScreenGui", { Name = "LaAlfombraRojaAviso", ResetOnSpawn = false, DisplayOrder = 21 }, pg)
		ui.toast = make("TextLabel", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(420, 34), BackgroundColor3 = BLACK, BackgroundTransparency = 0.15, Font = Enum.Font.GothamMedium, Text = "", TextScaled = true, TextColor3 = GOLD, Visible = false }, ui.toastGui)
	end
	if ui.toast then
		ui.toast.Text = text
		ui.toast.Visible = true
		ui.toastUntil = os.clock() + 4
	end
end

local function refreshPanel()
	if not ui.gui then
		return
	end
	for _, fn in ui.widgets do
		fn()
	end
end

local function buildPanel()
	local pg = player:WaitForChild("PlayerGui")
	local gui = make("ScreenGui", { Name = "LaAlfombraRojaControl", ResetOnSpawn = false, Enabled = false, DisplayOrder = 20 }, pg)
	ui.gui = gui
	local frame = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0, 360, 0.86, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.06, BorderSizePixel = 0 }, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
	make("UIStroke", { Color = GOLD, Thickness = 1.5 }, frame)
	make("TextLabel", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 30), Font = Enum.Font.Bodoni, Text = "CONTROL DE LUCES", TextScaled = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, frame)
	local operatorLabel = make("TextLabel", { Name = "Operator", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 18), Font = Enum.Font.GothamMedium, Text = "", TextScaled = true, TextColor3 = rgb(200, 200, 205), TextXAlignment = Enum.TextXAlignment.Left }, frame)
	local close = make("TextButton", { Name = "Close", Position = UDim2.new(1, -74, 0, 8), Size = UDim2.fromOffset(62, 26), BackgroundColor3 = PANEL, Font = Enum.Font.GothamMedium, Text = "Cerrar", TextScaled = true, TextColor3 = GOLD, AutoButtonColor = true }, frame)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, close)
	local list = make("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 1, -68), CanvasSize = UDim2.new(0, 0, 0, 1040), ScrollBarThickness = 6, BorderSizePixel = 0 }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function header(text)
		make("TextLabel", { Name = "H_" .. text, LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.Bodoni, Text = text, TextScaled = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, list)
	end
	local function button(name, text, parent, size, pos)
		local b = make("TextButton", { Name = name, Size = size, Position = pos or UDim2.new(), BackgroundColor3 = PANEL, Font = Enum.Font.GothamMedium, Text = text, TextScaled = true, TextColor3 = rgb(235, 235, 240), AutoButtonColor = true }, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		return b
	end
	local function row(name)
		return make("Frame", { Name = name, LayoutOrder = nextOrder(), BackgroundColor3 = rgb(20, 20, 24), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36) }, list)
	end
	local function paint(b, on)
		b.BackgroundColor3 = on and ON_COL or PANEL
		b.TextColor3 = on and rgb(255, 244, 214) or rgb(235, 235, 240)
	end

	-- control numerico con - / +
	local function stepper(key, label, lo, hi, step, fmt, onOffKey)
		local r = row("R_" .. key)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.34, 0, 1, 0), Font = Enum.Font.GothamMedium, Text = label, TextScaled = true, TextColor3 = rgb(225, 225, 230), TextXAlignment = Enum.TextXAlignment.Left }, r)
		local minus = button("Minus", "-", r, UDim2.fromOffset(30, 26), UDim2.new(0.36, 0, 0, 5))
		local val = make("TextLabel", { Name = "Value", BackgroundTransparency = 1, Position = UDim2.new(0.36, 34, 0, 0), Size = UDim2.fromOffset(52, 36), Font = Enum.Font.GothamMedium, Text = "", TextScaled = true, TextColor3 = GOLD }, r)
		local plus = button("Plus", "+", r, UDim2.fromOffset(30, 26), UDim2.new(0.36, 90, 0, 5))
		local tog
		if onOffKey then
			tog = button("Toggle", "", r, UDim2.fromOffset(52, 26), UDim2.new(1, -58, 0, 5))
		end
		minus.MouseButton1Click:Connect(function()
			send(key, math.clamp(math.floor(((S[key] or 1) - step) * 20 + 0.5) / 20, lo, hi))
		end)
		plus.MouseButton1Click:Connect(function()
			send(key, math.clamp(math.floor(((S[key] or 1) + step) * 20 + 0.5) / 20, lo, hi))
		end)
		if tog then
			tog.MouseButton1Click:Connect(function()
				send(onOffKey, not (S[onOffKey] ~= false))
			end)
		end
		ui.widgets[key] = function()
			val.Text = fmt(S[key] or 1)
			if tog then
				local on = S[onOffKey] ~= false
				tog.Text = on and "Activa" or "Apagada"
				paint(tog, on)
			end
		end
	end
	local function pct(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end
	local function mult(v)
		return string.format("x%.2f", v)
	end

	header("Intensidad")
	stepper("Master", "General", 0, 1.5, 0.1, pct)
	stepper("ZPista", "Pista", 0, 1.5, 0.1, pct, "OnPista")
	stepper("ZVip", "VIP", 0, 1.5, 0.1, pct, "OnVip")
	stepper("ZRooftop", "Rooftop", 0, 1.5, 0.1, pct, "OnRooftop")
	stepper("ZAlfombra", "Alfombra roja", 0, 1.5, 0.1, pct, "OnAlfombra")
	make("TextLabel", { LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham, Text = "Las luces de pasillos y escaleras nunca bajan del 45 %.", TextScaled = true, TextColor3 = rgb(160, 160, 168), TextWrapped = true }, list)

	header("Presets")
	local presets = row("Presets")
	presets.Size = UDim2.new(1, 0, 0, 76)
	local PRESET_LIST = { { "Elegante", "Elegante cálido" }, { "Fiesta", "Fiesta" }, { "Discoteca", "Discoteca" }, { "SinEfectos", "Apagado de efectos" } }
	for i, p in PRESET_LIST do
		local b = button("Preset_" .. p[1], p[2], presets, UDim2.new(0.5, -8, 0, 30), UDim2.new((i - 1) % 2 * 0.5, 4, 0, 4 + math.floor((i - 1) / 2) * 36))
		b.MouseButton1Click:Connect(function()
			send("Preset", p[1])
		end)
		ui.widgets["preset_" .. p[1]] = function()
			paint(b, S.Preset == p[1])
		end
	end

	header("Efectos")
	local function toggle(key, label)
		local r = row("T_" .. key)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), Font = Enum.Font.GothamMedium, Text = label, TextScaled = true, TextColor3 = rgb(225, 225, 230), TextXAlignment = Enum.TextXAlignment.Left }, r)
		local b = button("Toggle", "", r, UDim2.fromOffset(80, 26), UDim2.new(1, -88, 0, 5))
		b.MouseButton1Click:Connect(function()
			send(key, not S[key])
		end)
		ui.widgets["t_" .. key] = function()
			b.Text = S[key] and "Activado" or "Apagado"
			paint(b, S[key] == true)
		end
	end
	toggle("Shafts", "Haces de luz")
	toggle("Lasers", "Láseres")
	toggle("SpotMove", "Movimiento de focos")
	toggle("Pulse", "Pulso de color")
	toggle("MirrorSpin", "Giro de la bola de espejos")
	stepper("Speed", "Velocidad efectos", 0.25, 2, 0.25, mult)
	stepper("MirrorSpeed", "Velocidad bola", 0, 2, 0.25, mult)

	header("Colores")
	local colors = row("Palettes")
	colors.Size = UDim2.new(1, 0, 0, 76)
	local PAL_LIST = { { "Champan", "Champán" }, { "Hielo", "Hielo" }, { "Rosa", "Rosa" }, { "Violeta", "Violeta" }, { "Rojo", "Rojo" }, { "Multicolor", "Multicolor" } }
	for i, p in PAL_LIST do
		local b = button("Palette_" .. p[1], p[2], colors, UDim2.new(1 / 3, -6, 0, 30), UDim2.new((i - 1) % 3 / 3, 3, 0, 4 + math.floor((i - 1) / 3) * 36))
		b.MouseButton1Click:Connect(function()
			send("Palette", p[1])
		end)
		ui.widgets["pal_" .. p[1]] = function()
			paint(b, S.Palette == p[1])
		end
	end

	header("Estrobo (opcional)")
	toggle("Strobe", "Estrobo")
	make("TextLabel", { LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.Gotham, Text = "Aviso: son luces intermitentes (máx. 2,5 por segundo) y pueden afectar a personas fotosensibles. Está apagado de inicio.", TextScaled = true, TextColor3 = rgb(210, 160, 120), TextWrapped = true }, list)

	local restore = button("Restore", "Restaurar iluminación elegante", list, UDim2.new(1, 0, 0, 40))
	restore.LayoutOrder = nextOrder()
	restore.BackgroundColor3 = ON_COL
	restore.MouseButton1Click:Connect(function()
		send("Restore", true)
	end)
	local release = button("Release", "Soltar el control", list, UDim2.new(1, 0, 0, 34))
	release.LayoutOrder = nextOrder()
	release.MouseButton1Click:Connect(function()
		send("Release", true)
		gui.Enabled = false
		ui.open = false
	end)
	close.MouseButton1Click:Connect(function()
		send("Release", true)
		gui.Enabled = false
		ui.open = false
	end)
	ui.widgets.operator = function()
		local name = S.OperatorName
		operatorLabel.Text = (name and name ~= "") and ("Operador: " .. name) or "Operador: libre"
	end
	refreshPanel()
end

local function openPanel()
	if not ui.gui then
		buildPanel()
	end
	ui.gui.Enabled = true
	ui.open = true
	refreshPanel()
end

if notice then
	notice.OnClientEvent:Connect(function(kind, text)
		if kind == "Open" then
			openPanel()
		elseif kind == "Closed" and ui.gui then
			ui.gui.Enabled = false
			ui.open = false
		end
		if type(text) == "string" and text ~= "" then
			toastMsg(text)
		end
	end)
end

------------------------------------------------------------------------
-- Estado de la placa de la cabina, aviso y cierre por distancia
------------------------------------------------------------------------
local housekeeping = 0
local function houseKeeping(dt)
	housekeeping += dt
	if housekeeping < 0.5 then
		return
	end
	housekeeping = 0
	local name = S.OperatorName
	local txt = (name and name ~= "") and ("OPERADOR: " .. string.upper(name)) or "OPERADOR: LIBRE"
	for _, st in reg.status do
		if st.label.Text ~= txt then
			st.label.Text = txt
		end
	end
	if ui.toast and ui.toast.Visible and os.clock() > ui.toastUntil then
		ui.toast.Visible = false
	end
	if ui.open then
		local deskPart
		for _, d in reg.desk do
			deskPart = d.part
		end
		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if deskPart and hrp and (hrp.Position - deskPart.CFrame.Position).Magnitude > 45 then
			send("Release", true)
			ui.gui.Enabled = false
			ui.open = false
			toastMsg("Te alejaste de la cabina: control liberado.")
		end
		refreshPanel()
	end
end
control.AttributeChanged:Connect(function()
	if ui.open then
		refreshPanel()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	animate(dt)
	houseKeeping(dt)
end)
