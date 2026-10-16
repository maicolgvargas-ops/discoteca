--[[
	EFFECTS - efectos LOCALES de la discoteca (luces, neones, laseres, bola de espejos, estrobo, llamas)
	y pantallas "Ahora suena". Nada se replica desde el servidor: aqui solo se lee el estado compartido
	(atributos de club.Control y club.Music) y se anima en tu pantalla.

	* No toca UserGameSettings ni RenderSettings. Si tu equipo va justo, solo espacia SUS PROPIAS animaciones.
	* El visualizador de las pantallas usa Sound.PlaybackLoudness REAL; sin audio sonando, las barras quedan planas.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Effects = {}

function Effects.init(club, control)
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
	local reg = { tile = {}, glow = {}, lamp = {}, light = {}, strobe = {}, laser = {}, mirror = {}, flame = {}, sign = {}, screen = {}, shaft = {}, spot = {}, status = {}, desk = {}, nowTitle = {}, nowArtist = {}, nowState = {}, visBar = {} }
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
		AR_NowTitle = function(i)
			reg.nowTitle[i] = { label = i }
		end,
		AR_NowArtist = function(i)
			reg.nowArtist[i] = { label = i }
		end,
		AR_NowState = function(i)
			reg.nowState[i] = { label = i }
		end,
		AR_VisBar = function(i)
			reg.visBar[i] = { frame = i, index = i:GetAttribute("Index") or 1, h = 0.02 }
		end,
	}
	local TAG_TABLE = { AR_Tile = "tile", AR_Glow = "glow", AR_Lamp = "lamp", AR_Light = "light", AR_Strobe = "strobe", AR_Laser = "laser", AR_Mirror = "mirror", AR_Flame = "flame", AR_Sign = "sign", AR_Screen = "screen", AR_Shaft = "shaft", AR_Spot = "spot", AR_Status = "status", AR_Desk = "desk", AR_NowTitle = "nowTitle", AR_NowArtist = "nowArtist", AR_NowState = "nowState", AR_VisBar = "visBar" }
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
-- Pantallas "Ahora suena" + visualizador (sonoridad REAL del audio; sin audio, barras planas)
------------------------------------------------------------------------
local musicFolder = club:FindFirstChild("Music")
local sounds = {}
for _, d in club:GetDescendants() do
	if d:IsA("Sound") and d.Name == "ClubMusic" then
		table.insert(sounds, d)
	end
end
local visT, visAcc, nowAcc = 0, 0, 0
local loud = 0
local EMPTY_TITLE = "Sin música configurada"

local function nowTexts()
	local m = musicFolder
	if not m or (m:GetAttribute("Count") or 0) == 0 then
		return EMPTY_TITLE, "", "Añade pistas en Config.Music.Tracks"
	end
	local status = m:GetAttribute("Status")
	local title = m:GetAttribute("Title") or ""
	if title == "" then
		return "Cabina lista", "", "Pulsa Reproducir en la mesa de DJ"
	end
	local st = status == "playing" and "▶ Sonando" or (status == "paused" and "❚❚ En pausa" or "■ Detenida")
	return title, m:GetAttribute("Artist") or "", st
end

local function updateNow(dt)
	nowAcc += dt
	if nowAcc < 0.5 then
		return
	end
	nowAcc = 0
	local tt, aa, ss = nowTexts()
	for _, r in reg.nowTitle do
		if r.label.Text ~= tt then
			r.label.Text = tt
		end
	end
	for _, r in reg.nowArtist do
		if r.label.Text ~= aa then
			r.label.Text = aa
		end
	end
	for _, r in reg.nowState do
		if r.label.Text ~= ss then
			r.label.Text = ss
		end
	end
end

local function updateVisualizer(dt)
	visAcc += dt
	local period = (QUALITY == "Alta") and 0.05 or 0.08
	if visAcc < period then
		return
	end
	local elapsed = visAcc
	visAcc = 0
	visT += elapsed
	local playing = musicFolder and musicFolder:GetAttribute("Playing") == true
	local level = 0
	if playing then
		for _, s in sounds do
			if s.IsPlaying then
				level = math.max(level, s.PlaybackLoudness)
			end
		end
		level = math.clamp(level / 450, 0, 1)
	end
	loud = loud + (level - loud) * math.min(1, elapsed * 10)
	for _, b in reg.visBar do
		local shape = 0.55 + 0.45 * math.sin(visT * (2.2 + b.index * 0.31) + b.index * 1.7)
		local target = 0.02 + 0.8 * loud * shape
		if math.abs(target - b.h) > 0.01 then
			b.h = b.h + (target - b.h) * 0.6
			b.frame.Size = UDim2.new(b.frame.Size.X.Scale, 0, b.h, 0)
		end
	end
end

------------------------------------------------------------------------
-- placa de operador (el panel lo gestiona ControlUi)
------------------------------------------------------------------------
local plateAcc = 0
local function updatePlate(dt)
	plateAcc += dt
	if plateAcc < 0.5 then
		return
	end
	plateAcc = 0
	local name = S.OperatorName
	local txt = (name and name ~= "") and ("OPERADOR: " .. string.upper(name)) or "OPERADOR: LIBRE"
	for _, st in reg.status do
		if st.label.Text ~= txt then
			st.label.Text = txt
		end
	end
end

Effects.S = S
Effects.reg = reg
Effects.KEYS = KEYS
Effects.control = control

-- bucle principal (lo llama init.client en Heartbeat)
function Effects.step(dt)
	animate(dt)
	if near then
		updateNow(dt)
		updateVisualizer(dt)
	end
	updatePlate(dt)
end

function Effects.deskParts()
	local out = {}
	for _, d in reg.desk do
		table.insert(out, d.part)
	end
	return out
end

function Effects.onStateChanged(fn)
	for _, k in KEYS do
		control:GetAttributeChangedSignal(k):Connect(fn)
	end
end

end

return Effects
