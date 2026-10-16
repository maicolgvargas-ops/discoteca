--[[
	DANCE - panel de bailes y animacion LOCAL de los jugadores que bailan.
	* El servidor solo guarda el baile elegido en atributos del personaje (AR_Dance, AR_DanceT0) y corta
	  el baile si el jugador anda, salta o muere. Cada cliente anima a los que tiene cerca.
	* Procedural (sin ids de animacion) para R6 y R15; si Config.Dance.Dances[i].AnimationId es un id
	  valido con permiso de uso, se reproduce esa animacion en su lugar.
	* Solo se animan los MaxVisible mas cercanos dentro de MaxAnimateDistance.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)
local Shared = ReplicatedStorage:WaitForChild("AlfombraShared")
local Config = require(Shared:WaitForChild("Config"))
local DancePoses = require(Shared:WaitForChild("DancePoses"))
local Util = require(Shared:WaitForChild("Util"))

local Dance = {}

local player = Players.LocalPlayer
local social
local gui, panel
local active = {} -- [character] = { state, weight, id, t0, track }
local acc = 0
local mine = nil

local function def(id)
	for _, d in Config.Dance.Dances do
		if d.Id == id then
			return d
		end
	end
	return nil
end

local function stopChar(ch, a)
	if a.track then
		pcall(function()
			a.track:Stop(0.2)
		end)
	end
	DancePoses.reset(a.state)
	active[ch] = nil
end

------------------------------------------------------------------------
-- panel
------------------------------------------------------------------------
local function buildPanel()
	gui = Ui.screenGui("LaAlfombraRojaBaile", 18, false)
	panel = Ui.make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -70), Size = UDim2.fromOffset(220, 60 + #Config.Dance.Dances * 34), BackgroundColor3 = Ui.BLACK, BackgroundTransparency = 0.06, BorderSizePixel = 0 }, gui)
	Ui.corner(panel, 12)
	Ui.make("UIStroke", { Color = Ui.GOLD, Thickness = 1.5 }, panel)
	Ui.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.Bodoni, Text = "BAILAR", TextColor3 = Ui.GOLD }, panel)
	for i, d in Config.Dance.Dances do
		local b = Ui.button("Dance_" .. d.Id, d.Name, panel, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 34 + (i - 1) * 34))
		b.Activated:Connect(function()
			social:FireServer("Dance", d.Id)
			gui.Enabled = false
		end)
	end
	local stop = Ui.button("Stop", "Parar de bailar", panel, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 34 + #Config.Dance.Dances * 34))
	stop.Activated:Connect(function()
		social:FireServer("StopDance")
		gui.Enabled = false
	end)
end

function Dance.toggle()
	if not Config.Dance.Enabled then
		return
	end
	if not gui then
		buildPanel()
	end
	gui.Enabled = not gui.Enabled
end

function Dance.isMine()
	return mine
end

------------------------------------------------------------------------
-- animacion de quien baila cerca
------------------------------------------------------------------------
local function startChar(ch, id)
	local d = def(id)
	if not d then
		return
	end
	local state = DancePoses.new(ch)
	local a = { state = state, weight = 0, id = id, track = nil }
	local animId = Util.normalizeAssetId(d.AnimationId)
	if animId ~= "" then
		local hum = ch:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local ok, track = pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = animId
				local tr = animator:LoadAnimation(anim)
				tr.Looped = true
				tr:Play(0.3)
				return tr
			end)
			if ok then
				a.track = track
			end
		end
	end
	active[ch] = a
	return a
end

function Dance.step(dt)
	acc += dt
	if acc < 0.033 then
		return
	end
	local elapsed = acc
	acc = 0
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
	local now = Workspace:GetServerTimeNow()
	local cands = {}
	for _, pl in Players:GetPlayers() do
		local ch = pl.Character
		local id = ch and ch:GetAttribute("AR_Dance")
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if pl == player then
			mine = (type(id) == "string") and id or nil
		end
		if type(id) == "string" and hrp then
			local dist = (hrp.Position - camPos).Magnitude
			if dist <= Config.Dance.MaxAnimateDistance then
				table.insert(cands, { ch = ch, id = id, d = dist, pl = pl })
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	local keep = {}
	for i, c in cands do
		if i <= Config.Dance.MaxVisible then
			keep[c.ch] = c
		end
	end
	-- fuera: quitar
	for ch, a in active do
		local c = keep[ch]
		if not c or c.id ~= a.id then
			-- fundido de salida
			a.weight = math.max(0, a.weight - elapsed * 4)
			if a.weight <= 0 or not ch.Parent then
				stopChar(ch, a)
			elseif not a.track then
				DancePoses.apply(a.state, a.id, now, a.weight)
			end
		end
	end
	for ch, c in keep do
		local a = active[ch]
		if a and a.id ~= c.id then
			stopChar(ch, a)
			a = nil
		end
		if not a then
			a = startChar(ch, c.id)
		end
		if a then
			a.weight = math.min(1, a.weight + elapsed * 4)
			if not a.track then
				local t0 = ch:GetAttribute("AR_DanceT0")
				DancePoses.apply(a.state, c.id, now - (type(t0) == "number" and t0 or now), a.weight)
			end
		end
	end
end

function Dance.init(deps)
	social = deps.remotes.Social
	deps.remotes.SocialNotice.OnClientEvent:Connect(function(kind)
		if kind == "DanceDenied" then
			Ui.toast("Ahora mismo no puedes bailar (de pie y quieto, y con permiso).")
		elseif kind == "DanceStopped" then
			mine = nil
		end
	end)
end

return Dance
