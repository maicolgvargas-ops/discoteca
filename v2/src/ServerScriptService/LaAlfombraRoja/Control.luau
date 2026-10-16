--[[
	CONTROL - cabina de control: ESTADO de luces y musica, OPERADOR UNICO y peticiones validadas.

	* El estado vive en atributos de club.Control (replicados por Roblox): todos ven lo mismo.
	* Un solo operador a la vez (luces + musica comparten el mismo operador y los mismos permisos).
	* Peticiones por RemoteEvent "Control": el servidor valida accion, tipo, rango, operador y cercania,
	  y limita la frecuencia por jugador. Los clientes no pueden mandar assetIds ni valores sin acotar.
	* Las luces de seguridad (pasillos, escaleras) nunca bajan del 45 % (lo aplica el cliente).
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Music = require(script.Parent.Music)

local CONFIG = Config
local club, fx, LAYOUT, PROFILE_NAME

local Control = {}
Control.DEFAULT = {
	Preset = "Elegante",
	Master = 1, ZPista = 1, ZVip = 1, ZRooftop = 1, ZAlfombra = 1,
	OnPista = true, OnVip = true, OnRooftop = true, OnAlfombra = true,
	Lasers = false, Shafts = true, SpotMove = false, Pulse = true,
	Speed = 0.6, MirrorSpin = true, MirrorSpeed = 0.5,
	Strobe = false, -- opcional y APAGADO de inicio (luces intermitentes)
	Palette = "Champan",
}
Control.PRESETS = {
	Elegante = { Master = 1, Lasers = false, Shafts = true, SpotMove = false, Pulse = true, Speed = 0.6, MirrorSpin = true, MirrorSpeed = 0.5, Strobe = false, Palette = "Champan" },
	Fiesta = { Master = 1.1, Lasers = true, Shafts = true, SpotMove = true, Pulse = true, Speed = 1.1, MirrorSpin = true, MirrorSpeed = 1, Strobe = false, Palette = "Rosa" },
	Discoteca = { Master = 1.2, Lasers = true, Shafts = true, SpotMove = true, Pulse = true, Speed = 1.6, MirrorSpin = true, MirrorSpeed = 1.5, Strobe = false, Palette = "Multicolor" },
	SinEfectos = { Lasers = false, Shafts = false, SpotMove = false, Pulse = false, MirrorSpin = false, Strobe = false, Speed = 0.6, Palette = "Champan" },
}
Control.NUM = {
	Master = { 0, 1.5 }, ZPista = { 0, 1.5 }, ZVip = { 0, 1.5 }, ZRooftop = { 0, 1.5 }, ZAlfombra = { 0, 1.5 },
	Speed = { 0.25, 2 }, MirrorSpeed = { 0, 2 },
}
Control.BOOL = { "OnPista", "OnVip", "OnRooftop", "OnAlfombra", "Lasers", "Shafts", "SpotMove", "Pulse", "MirrorSpin", "Strobe" }
Control.PALETTES = { Champan = true, Hielo = true, Rosa = true, Violeta = true, Rojo = true, Multicolor = true }
Control.SAFE = { "^Fill", "HallStrip", "^Door_", "Stair", "Landing", "CarpetFill", "LightDeskFill" }
Control.op = { player = nil, last = 0 } -- operador actual
Control.buckets = {}
Control.clock = 0
Control.warnAt = 0

-- zona de una luz segun su posicion: Pista (planta baja y atrio), Vip, Rooftop, Alfombra o Ext
function Control.zoneOf(pos)
	local A = LAYOUT.atrium
	if math.abs(pos.X) > 80 or pos.Z > 80 or pos.Z < -80 then
		return "Ext"
	end
	if pos.Y >= 46 then
		return "Rooftop"
	end
	if pos.Y >= 22 and not (pos.X >= A.x1 and pos.X <= A.x2 and pos.Z >= A.z1 and pos.Z <= A.z2) then
		return "Vip"
	end
	if pos.X < -8 and pos.Z > 46 then
		return "Alfombra"
	end
	return "Pista"
end

local function findDesc(name)
	for _, d in club:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

-- etiqueta y atributos de todo lo que el cliente anima o regula
function Control.tag()
	local CS = game:GetService("CollectionService")
	local function add(inst, tag, attrs)
		-- primero los atributos y despues la etiqueta: el cliente los lee al recibir la etiqueta
		if attrs then
			for k, v in attrs do
				inst:SetAttribute(k, v)
			end
		end
		CS:AddTag(inst, tag)
	end
	local flameSet = {}
	for _, fl in fx.flames do
		flameSet[fl.light] = true
		add(fl.light, "AR_Flame", { phase = fl.phase, base = fl.base })
	end
	for _, t in fx.tiles do
		add(t.part, "AR_Tile", { ix = t.ix, iz = t.iz, n = t.n, dim = t.dim })
	end
	for _, g in fx.glows do
		add(g.part, "AR_Glow", { phase = g.phase, z = Control.zoneOf(g.part.CFrame.Position) })
	end
	for _, l in fx.lamps do
		add(l.light.Parent, "AR_Lamp", { phase = l.phase, z = Control.zoneOf(l.light.Parent.CFrame.Position) })
	end
	for _, st in fx.strobes do
		CS:AddTag(st.part, "AR_Strobe")
	end
	for _, b in fx.beams do
		add(b.tip, "AR_Laser", { o = b.origin, yaw = b.yaw, swing = b.swing, speed = b.speed, phase = b.phase })
	end
	for _, m in fx.mirror do
		CS:AddTag(m.part, "AR_Mirror")
	end
	if fx.mirror[1] then
		club:SetAttribute("MirrorCenter", fx.mirror[1].center)
	end
	for _, sg in fx.signs do
		add(sg.label, "AR_Sign", { phase = sg.phase })
	end
	for _, l in fx.screens do
		CS:AddTag(l, "AR_Screen")
	end
	local spots = 0
	for _, d in club:GetDescendants() do
		if d:IsA("Beam") and d.Name == "LightShaft" then
			add(d, "AR_Shaft", { z = Control.zoneOf(d.Parent.CFrame.Position) })
		elseif d:IsA("BasePart") and (string.match(d.Name, "^StageSpot%d+$") or string.match(d.Name, "^RoofSpot%d+$")) then
			spots += 1
			add(d, "AR_Spot", { phase = spots * 0.9 })
		elseif (d:IsA("PointLight") or d:IsA("SpotLight")) and not flameSet[d] then
			local pn = d.Parent.Name
			if not (string.match(pn, "^Strobe%d+$") or string.match(pn, "^RoofStrobe%d+$")) then
				local safe = false
				for _, pat in Control.SAFE do
					if string.find(pn, pat) then
						safe = true
						break
					end
				end
				add(d, "AR_Light", { z = Control.zoneOf(d.Parent.CFrame.Position), safe = safe, b = d.Brightness })
			end
		elseif d.Name == "ControlStatusLabel" then
			CS:AddTag(d, "AR_Status")
		elseif d.Name == "LightDesk_Top" or d.Name == "DJ_ConsoleHit" then
			CS:AddTag(d, "AR_Desk")
		end
	end
end

function Control.canOperate(player)
	local c = CONFIG.Control
	if c.Access == "Todos" then
		return true
	end
	if c.Access == "Dueno" then
		local okS, studio = pcall(function()
			return RunService:IsStudio()
		end)
		if okS and studio then
			return true
		end
		local ok, cid = pcall(function()
			return game.CreatorId
		end)
		return ok and cid ~= nil and cid ~= 0 and player.UserId == cid
	end
	for _, id in c.UserIds do
		if id == player.UserId then
			return true
		end
	end
	if c.GroupId > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(c.GroupId)
		end)
		if ok and type(rank) == "number" and rank >= c.MinRank then
			return true
		end
	end
	return false
end

-- cerca de CUALQUIERA de los puntos de control (consola de luces o mesa de DJ)
function Control.near(player, range)
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp or not Control.points or #Control.points == 0 then
		return false
	end
	for _, pt in Control.points do
		if (hrp.Position - pt.CFrame.Position).Magnitude <= range then
			return true
		end
	end
	return false
end

function Control.notice(player, kind, text, extra)
	Remotes.fire(player, "ControlNotice", kind, text, extra)
end

function Control.setOperator(player)
	Control.op.player = player
	Control.op.last = Control.clock
	local f = club:FindFirstChild("Control")
	f:SetAttribute("Operator", player and player.UserId or 0)
	f:SetAttribute("OperatorName", player and player.Name or "")
end

function Control.release(player, reason)
	if Control.op.player ~= nil and Control.op.player == player then
		Control.setOperator(nil)
		Control.notice(player, "Closed", reason or "Control liberado.")
	end
end

function Control.allow(player)
	return Remotes.allow(player, "Control", CONFIG.Control.MaxRequestsPerSecond)
end

function Control.set(attr, v)
	club:FindFirstChild("Control"):SetAttribute(attr, v)
end

-- aplica una accion ya autenticada; devuelve true si el valor era valido
function Control.apply(action, value)
	if Music.isMusicAction(action) then
		local ok, reason = Music.handle(action, value)
		return ok, reason
	end
	if action == "Restore" then
		for k, v in Control.DEFAULT do
			Control.set(k, v)
		end
		return true
	elseif action == "Preset" then
		local p = type(value) == "string" and Control.PRESETS[value]
		if not p then
			return false
		end
		for k, v in p do
			Control.set(k, v)
		end
		Control.set("Preset", value)
		return true
	end
	local rg = Control.NUM[action]
	if rg then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		local v = math.clamp(math.floor(value * 20 + 0.5) / 20, rg[1], rg[2])
		Control.set(action, v)
		Control.set("Preset", "Personalizado")
		return true
	end
	if table.find(Control.BOOL, action) then
		if type(value) ~= "boolean" then
			return false
		end
		Control.set(action, value)
		Control.set("Preset", "Personalizado")
		return true
	end
	if action == "Palette" then
		if type(value) ~= "string" or not Control.PALETTES[value] then
			return false
		end
		Control.set(action, value)
		Control.set("Preset", "Personalizado")
		return true
	end
	return false
end

function Control.handle(player, action, value)
	if not Control.allow(player) then
		if Control.clock - Control.warnAt > 3 then
			Control.warnAt = Control.clock
			Control.notice(player, "Info", "Demasiadas acciones seguidas: ve un poco más despacio.")
		end
		return false
	end
	if type(action) ~= "string" then
		return false
	end
	if Control.op.player ~= player then
		Control.notice(player, "Denied", "No eres el operador de la cabina.")
		return false
	end
	if action == "Release" then
		Control.release(player, "Has soltado el control de las luces.")
		return true
	end
	if not Control.near(player, CONFIG.Control.Range * 3) then
		Control.release(player, "Te alejaste de la cabina: control liberado.")
		return false
	end
	Control.op.last = Control.clock
	local ok, reason = Control.apply(action, value)
	if not ok and reason then
		Control.notice(player, "Info", reason)
	end
	return ok
end

function Control.trigger(player, tab)
	local c = CONFIG.Control
	if not Control.canOperate(player) then
		Control.notice(player, "Denied", "No tienes permiso para operar la cabina.")
		return
	end
	if not Control.near(player, c.Range * 1.5) then
		Control.notice(player, "Denied", "Acércate a la cabina de luces o a la mesa de DJ.")
		return
	end
	local cur = Control.op.player
	if cur ~= nil and cur ~= player then
		Control.notice(player, "Busy", "La cabina está en uso por " .. cur.Name .. ".")
		return
	end
	Control.setOperator(player)
	Control.notice(player, "Open", "Eres el operador de la cabina.", tab or "luces")
end


function Control.init(ctx)
	club, fx, LAYOUT, PROFILE_NAME = ctx.club, ctx.fx, ctx.LAYOUT, ctx.PROFILE_NAME
	local old = club:FindFirstChild("Control")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Control"
	folder.Parent = club
	for k, v in Control.DEFAULT do
		folder:SetAttribute(k, v)
	end
	folder:SetAttribute("Operator", 0)
	folder:SetAttribute("OperatorName", "")
	club:SetAttribute("Quality", PROFILE_NAME)
	club:SetAttribute("ClientFX", true)
	Control.tag()
	Control.desk = findDesc("LightDesk_Top")
	Control.points = {}
	for _, d in club:GetDescendants() do
		if d.Name == "LightDesk_Top" or d.Name == "DJ_ConsoleHit" then
			table.insert(Control.points, d)
		end
	end
	if not CONFIG.Control.Enabled or #Control.points == 0 then
		return
	end
	local req = Remotes.get("Control")
	req.OnServerEvent:Connect(function(player, action, value)
		Control.handle(player, action, value)
	end)
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player)
		Control.release(player, "")
	end)
	-- vigilante: libera el control por inactividad o si el operador se aleja
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		Control.clock += dt
		acc += dt
		if acc < 2 then
			return
		end
		acc = 0
		local p = Control.op.player
		if p then
			if Control.clock - Control.op.last > CONFIG.Control.IdleTimeout then
				Control.release(p, "Control liberado por inactividad.")
			elseif not Control.near(p, CONFIG.Control.Range * 3) then
				Control.release(p, "Te alejaste de la cabina: control liberado.")
			end
		end
	end)
end

return Control
