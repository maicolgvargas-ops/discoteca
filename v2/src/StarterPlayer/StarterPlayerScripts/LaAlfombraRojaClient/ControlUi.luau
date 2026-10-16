--[[
	CONTROLUI - panel de la cabina (pestanas "Luces" y "Música"). Solo el operador autorizado por el
	servidor puede cambiar algo: aqui solo se piden acciones (el servidor valida todo).

	Musica: solo se muestran las pistas de la lista blanca (Config.Music.Tracks). Sin pistas, el panel
	explica como configurarlas y no ofrece botones que simulen musica.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)
local Config = require(ReplicatedStorage:WaitForChild("AlfombraShared"):WaitForChild("Config"))

local ControlUi = {}

local player = Players.LocalPlayer
local make, button, paint = Ui.make, Ui.button, Ui.paint
local GOLD, BLACK = Ui.GOLD, Ui.BLACK

local S, club, control, music, request, effects
local st = { gui = nil, open = false, widgets = {}, lastSend = 0, tab = "luces", frames = {}, tabButtons = {} }

local function send(action, value)
	if not request then
		return
	end
	local now = os.clock()
	if now - st.lastSend < 0.12 then -- maximo ~8 peticiones por segundo desde la interfaz
		return
	end
	st.lastSend = now
	request:FireServer(action, value)
end

local function refresh()
	if not st.gui then
		return
	end
	for _, fn in st.widgets do
		fn()
	end
end

local function setTab(name)
	st.tab = name
	for key, f in st.frames do
		f.Visible = key == name
	end
	for key, b in st.tabButtons do
		paint(b, key == name)
	end
end

local function build()
	local gui = Ui.screenGui("LaAlfombraRojaControl", 20, false)
	st.gui = gui
	local frame = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0, 360, 0.86, 0), BackgroundColor3 = BLACK, BackgroundTransparency = 0.06, BorderSizePixel = 0 }, gui)
	Ui.corner(frame, 12)
	make("UIStroke", { Color = GOLD, Thickness = 1.5 }, frame)
	Ui.label({ Name = "Title", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 28), Font = Enum.Font.Bodoni, Text = "CABINA", TextColor3 = GOLD }, frame)
	local operatorLabel = Ui.label({ Name = "Operator", Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 16), Text = "", TextColor3 = Color3.fromRGB(200, 200, 205) }, frame)
	local close = button("Close", "Cerrar", frame, UDim2.fromOffset(62, 26), UDim2.new(1, -74, 0, 8))
	close.TextColor3 = GOLD
	local tabs = make("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 0, 28) }, frame)
	for i, t in { { "luces", "Luces" }, { "musica", "Música" } } do
		local b = button("Tab_" .. t[1], t[2], tabs, UDim2.new(0.5, -4, 1, 0), UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0))
		st.tabButtons[t[1]] = b
		b.Activated:Connect(function()
			setTab(t[1])
		end)
	end

	------------------------------------------------------------------ luces
	local list = make("ScrollingFrame", { Name = "Luces", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 88), Size = UDim2.new(1, -16, 1, -96), CanvasSize = UDim2.new(0, 0, 0, 1330), ScrollBarThickness = 6, BorderSizePixel = 0 }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	st.frames.luces = list
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function header(text, parent, ord)
		Ui.label({ Name = "H_" .. text, LayoutOrder = ord or nextOrder(), Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.Bodoni, Text = text, TextColor3 = GOLD }, parent or list)
	end
	local function row(name)
		return make("Frame", { Name = name, LayoutOrder = nextOrder(), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 36) }, list)
	end
	local function stepper(key, label, lo, hi, step, fmt, onOffKey)
		local r = row("R_" .. key)
		Ui.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.34, 0, 1, 0), Text = label, TextColor3 = Color3.fromRGB(225, 225, 230) }, r)
		local minus = button("Minus", "-", r, UDim2.fromOffset(30, 26), UDim2.new(0.36, 0, 0, 5))
		local val = Ui.label({ Name = "Value", Position = UDim2.new(0.36, 34, 0, 0), Size = UDim2.fromOffset(52, 36), Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center }, r)
		local plus = button("Plus", "+", r, UDim2.fromOffset(30, 26), UDim2.new(0.36, 90, 0, 5))
		local tog
		if onOffKey then
			tog = button("Toggle", "", r, UDim2.fromOffset(52, 26), UDim2.new(1, -58, 0, 5))
		end
		minus.Activated:Connect(function()
			send(key, math.clamp(math.floor(((S[key] or 1) - step) * 20 + 0.5) / 20, lo, hi))
		end)
		plus.Activated:Connect(function()
			send(key, math.clamp(math.floor(((S[key] or 1) + step) * 20 + 0.5) / 20, lo, hi))
		end)
		if tog then
			tog.Activated:Connect(function()
				send(onOffKey, not (S[onOffKey] ~= false))
			end)
		end
		st.widgets[key] = function()
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
	local function toggle(key, label)
		local r = row("T_" .. key)
		Ui.label({ Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = label, TextColor3 = Color3.fromRGB(225, 225, 230) }, r)
		local b = button("Toggle", "", r, UDim2.fromOffset(80, 26), UDim2.new(1, -88, 0, 5))
		b.Activated:Connect(function()
			send(key, not S[key])
		end)
		st.widgets["t_" .. key] = function()
			b.Text = S[key] and "Activado" or "Apagado"
			paint(b, S[key] == true)
		end
	end

	header("Intensidad")
	stepper("Master", "General", 0, 1.5, 0.1, pct)
	stepper("ZPista", "Pista", 0, 1.5, 0.1, pct, "OnPista")
	stepper("ZVip", "VIP", 0, 1.5, 0.1, pct, "OnVip")
	stepper("ZRooftop", "Rooftop", 0, 1.5, 0.1, pct, "OnRooftop")
	stepper("ZAlfombra", "Alfombra roja", 0, 1.5, 0.1, pct, "OnAlfombra")
	Ui.label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham, Text = "Las luces de pasillos y escaleras nunca bajan del 45 %.", TextColor3 = Ui.MUTED, TextWrapped = true }, list)

	header("Presets")
	local presets = row("Presets")
	presets.Size = UDim2.new(1, 0, 0, 112)
	for i, p in { { "Elegante", "Elegante cálido" }, { "Fiesta", "Fiesta" }, { "Discoteca", "Discoteca" }, { "DiscotecaOscura", "Discoteca oscura" }, { "SinEfectos", "Apagado de efectos" } } do
		local b = button("Preset_" .. p[1], p[2], presets, UDim2.new(0.5, -8, 0, 30), UDim2.new((i - 1) % 2 * 0.5, 4, 0, 4 + math.floor((i - 1) / 2) * 36))
		b.Activated:Connect(function()
			send("Preset", p[1])
		end)
		st.widgets["preset_" .. p[1]] = function()
			paint(b, S.Preset == p[1])
		end
	end

	header("Focos rojos y ambiente")
	toggle("Follow", "Focos rojos de seguimiento")
	stepper("FollowIntensity", "Intensidad focos", 0, 1.5, 0.1, pct)
	stepper("FollowSpeed", "Velocidad focos", 0.25, 2, 0.25, mult)
	stepper("Dark", "Oscuridad ambiente", 0, 1, 0.1, pct)
	Ui.label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.Gotham, Text = "Los focos siguen a quien baila en la pista. Escaleras, entrada y barras mantienen su luz mínima.", TextColor3 = Ui.MUTED, TextWrapped = true }, list)

	header("Efectos")
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
	for i, p in { { "Champan", "Champán" }, { "Hielo", "Hielo" }, { "Rosa", "Rosa" }, { "Violeta", "Violeta" }, { "Rojo", "Rojo" }, { "Multicolor", "Multicolor" } } do
		local b = button("Palette_" .. p[1], p[2], colors, UDim2.new(1 / 3, -6, 0, 30), UDim2.new((i - 1) % 3 / 3, 3, 0, 4 + math.floor((i - 1) / 3) * 36))
		b.Activated:Connect(function()
			send("Palette", p[1])
		end)
		st.widgets["pal_" .. p[1]] = function()
			paint(b, S.Palette == p[1])
		end
	end

	header("Estrobo (opcional)")
	toggle("Strobe", "Estrobo")
	Ui.label({ LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.Gotham, Text = "Aviso: son luces intermitentes (máx. 2,5 por segundo) y pueden afectar a personas fotosensibles. Está apagado de inicio.", TextColor3 = Color3.fromRGB(210, 160, 120), TextWrapped = true }, list)

	local restore = button("Restore", "Restaurar iluminación elegante", list, UDim2.new(1, 0, 0, 40))
	restore.LayoutOrder = nextOrder()
	restore.BackgroundColor3 = Ui.ON
	restore.Activated:Connect(function()
		send("Restore", true)
	end)

	------------------------------------------------------------------ musica
	local mf = make("Frame", { Name = "Musica", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 88), Size = UDim2.new(1, -16, 1, -96), Visible = false }, frame)
	st.frames.musica = mf
	local count = #Config.Music.Tracks
	local empty = Ui.label({ Name = "Vacio", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 150), Font = Enum.Font.Gotham, TextWrapped = true, TextScaled = false, TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(215, 200, 170), Text = "" }, mf)
	local nowL = Ui.label({ Name = "Ahora", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.Bodoni, Text = "", TextColor3 = GOLD }, mf)
	local tracks = make("ScrollingFrame", { Name = "Pistas", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -200), CanvasSize = UDim2.new(0, 0, 0, math.max(1, count) * 34), ScrollBarThickness = 5, BorderSizePixel = 0 }, mf)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tracks)
	local trackBtns = {}
	for i, t in Config.Music.Tracks do
		if type(t) == "table" and type(t.Title) == "string" then
			local b = button("Pista" .. i, string.format("%d. %s%s", i, t.Title, (type(t.Artist) == "string" and t.Artist ~= "") and ("  ·  " .. t.Artist) or ""), tracks, UDim2.new(1, -6, 0, 30))
			b.LayoutOrder = i
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Activated:Connect(function()
				send("MusicSelect", i)
			end)
			trackBtns[i] = b
		end
	end
	local transport = make("Frame", { Name = "Transporte", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -146), Size = UDim2.new(1, 0, 0, 40) }, mf)
	local prev = button("Prev", "◀◀", transport, UDim2.new(0.3, -4, 1, 0), UDim2.new(0, 0, 0, 0))
	local play = button("PlayPause", "▶", transport, UDim2.new(0.4, -4, 1, 0), UDim2.new(0.3, 2, 0, 0))
	local nxt = button("Next", "▶▶", transport, UDim2.new(0.3, -4, 1, 0), UDim2.new(0.7, 8, 0, 0))
	prev.Activated:Connect(function()
		send("MusicPrev", true)
	end)
	nxt.Activated:Connect(function()
		send("MusicNext", true)
	end)
	play.Activated:Connect(function()
		if music:GetAttribute("Playing") then
			send("MusicPause", true)
		else
			send("MusicPlay", true)
		end
	end)
	local vol = make("Frame", { Name = "Volumen", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -98), Size = UDim2.new(1, 0, 0, 36) }, mf)
	Ui.label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.3, 0, 1, 0), Text = "Volumen" }, vol)
	local vminus = button("VolMinus", "-", vol, UDim2.fromOffset(34, 28), UDim2.new(0.34, 0, 0, 4))
	local vval = Ui.label({ Position = UDim2.new(0.34, 38, 0, 0), Size = UDim2.fromOffset(56, 36), Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center }, vol)
	local vplus = button("VolPlus", "+", vol, UDim2.fromOffset(34, 28), UDim2.new(0.34, 98, 0, 4))
	vminus.Activated:Connect(function()
		send("MusicVolume", math.clamp((music:GetAttribute("Volume") or 0.5) - Config.Music.VolumeStep, 0, 1))
	end)
	vplus.Activated:Connect(function()
		send("MusicVolume", math.clamp((music:GetAttribute("Volume") or 0.5) + Config.Music.VolumeStep, 0, 1))
	end)
	Ui.label({ Name = "Nota", Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 50), Font = Enum.Font.Gotham, Text = "Solo suenan las pistas de la lista del club. Las pantallas muestran un visualizador de audio, no vídeo.", TextColor3 = Ui.MUTED, TextWrapped = true }, mf)

	st.widgets.music = function()
		local has = (music:GetAttribute("Count") or 0) > 0
		empty.Visible = not has
		nowL.Visible = has
		tracks.Visible = has
		transport.Visible = has
		vol.Visible = has
		if not has then
			empty.Text = "Aún no hay música configurada.\n\nEl propietario debe añadir pistas con permiso de uso en Config.Music.Tracks (Id de audio + Título). Cuando existan, aquí podrás elegir pista, pausar y subir o bajar el volumen. No se reproduce nada que no esté en esa lista."
			return
		end
		local title = music:GetAttribute("Title") or ""
		nowL.Text = (title ~= "") and title or "Elige una pista"
		play.Text = music:GetAttribute("Playing") and "❚❚" or "▶"
		vval.Text = string.format("%d%%", math.floor((music:GetAttribute("Volume") or 0) * 100 + 0.5))
		for i, b in trackBtns do
			paint(b, music:GetAttribute("Index") == i)
		end
	end
	st.widgets.operator = function()
		local name = S.OperatorName
		operatorLabel.Text = (name and name ~= "") and ("Operador: " .. name) or "Operador: libre"
	end
	local function closePanel()
		send("Release", true)
		gui.Enabled = false
		st.open = false
	end
	close.Activated:Connect(closePanel)
	setTab(st.tab)
	refresh()
end

function ControlUi.open(tab)
	if not st.gui then
		build()
	end
	st.gui.Enabled = true
	st.open = true
	setTab(tab == "musica" and "musica" or "luces")
	refresh()
end

function ControlUi.close()
	if st.gui then
		st.gui.Enabled = false
	end
	st.open = false
end

function ControlUi.isOpen()
	return st.open
end

function ControlUi.init(deps)
	club, control, effects, request = deps.club, deps.control, deps.effects, deps.remotes.Control
	S = effects.S
	music = club:WaitForChild("Music", 30) or control
	deps.remotes.ControlNotice.OnClientEvent:Connect(function(kind, text, extra)
		if kind == "Open" then
			ControlUi.open(extra)
		elseif kind == "Closed" then
			ControlUi.close()
		end
		if type(text) == "string" and text ~= "" then
			Ui.toast(text)
		end
	end)
	control.AttributeChanged:Connect(function()
		if st.open then
			refresh()
		end
	end)
	music.AttributeChanged:Connect(function()
		if st.open then
			refresh()
		end
	end)
end

-- cierre por distancia a TODAS las mesas de la cabina (lo llama el bucle a baja frecuencia)
function ControlUi.houseKeeping()
	if not st.open then
		return
	end
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local desks = effects.deskParts()
	if hrp and #desks > 0 then
		local nearAny = false
		for _, d in desks do
			if (hrp.Position - d.CFrame.Position).Magnitude <= 45 then
				nearAny = true
			end
		end
		if not nearAny then
			send("Release", true)
			ControlUi.close()
			Ui.toast("Te alejaste de la cabina: control liberado.")
		end
	end
	refresh()
end

return ControlUi
