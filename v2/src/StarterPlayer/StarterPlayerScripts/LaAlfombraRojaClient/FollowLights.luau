--[[
	FOLLOWLIGHTS - focos rojos de seguimiento (LOCALES). Cada cliente mueve SOLO su copia de los focos; el
	servidor solo guarda el estado de la cabina (Follow, FollowIntensity, FollowSpeed).

	* Siguen suavemente a quienes estan DENTRO de la pista (rectangulo con margen) y nunca apuntan fuera de ella.
	* Sin nadie en la pista barren la pista despacio (patron suave dentro de los limites).
	* Reparto: cada foco sigue a una persona distinta; cada `Dwell` segundos se reparten de nuevo.
	* Rendimiento: apagados = cero trabajo; encendidos = UpdateHz actualizaciones por segundo, solo si estas cerca
	  del club, y solo se escribe una propiedad cuando cambia de verdad. Sin sombras. No cambia ninguna opcion
	  grafica del jugador.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("AlfombraShared"):WaitForChild("Config"))

local FollowLights = {}

local F = Config.Follow
local heads = {} -- [head] = info
local S -- estado compartido (Effects.S)
local acc, retargetAt, clock = 0, 0, 0
local fade = 0 -- 0..1: encendido progresivo
local lastApplied = { on = false, k = -1 }
local announced, announcedAt = false, nil

-- luz y haces pueden replicarse DESPUES de la cabeza: se resuelven (y se reintentan) cuando hacen falta
local function resolve(h)
	if not h.light then
		h.light = h.head:FindFirstChildOfClass("SpotLight")
	end
	if #h.beams == 0 then
		for _, c in h.head:GetChildren() do
			if c:IsA("Beam") then
				table.insert(h.beams, { beam = c, w0 = c.Width0, w1 = c.Width1 })
			end
		end
		h.q = nil -- reaplicar anchura/brillo cuando por fin existen los haces
	end
	if h.base == nil and h.light then
		h.base = h.head:GetAttribute("b") or F.Brightness
	end
	return h.light ~= nil and #h.beams > 0
end

local function register(head)
	if heads[head] then
		return
	end
	local model = head.Parent
	-- el objetivo (hermano) puede llegar despues que la cabeza etiquetada: esperarlo sin bloquear
	local target = model and model:FindFirstChild("FollowTarget")
	if not target and model then
		task.spawn(function()
			local t = model:WaitForChild("FollowTarget", 15)
			if t and head.Parent and not heads[head] then
				register(head)
			end
		end)
		return
	end
	if not target then
		return
	end
	local a = head:GetAttribute("phase") or 0
	heads[head] = {
		head = head, target = target, light = nil, beams = {}, base = head:GetAttribute("b") or F.Brightness,
		idx = head:GetAttribute("idx") or 1, phase = a,
		x1 = head:GetAttribute("x1") or -30, z1 = head:GetAttribute("z1") or -54, x2 = head:GetAttribute("x2") or 30, z2 = head:GetAttribute("z2") or 6,
		y = head:GetAttribute("y") or 0.5,
		aim = target.Position, goal = target.Position, pos = head.Position, set = nil,
	}
	resolve(heads[head])
	print(string.format("[LaAlfombraRoja] foco rojo %s registrado en el cliente", head.Parent and head.Parent.Name or "?"))
end

function FollowLights.init(effects)
	S = effects.S
	for _, h in CollectionService:GetTagged("AR_Follow") do
		register(h)
	end
	CollectionService:GetInstanceAddedSignal("AR_Follow"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("AR_Follow"):Connect(function(h)
		heads[h] = nil
	end)
end

function FollowLights.count()
	local n = 0
	for _ in heads do
		n += 1
	end
	return n
end

function FollowLights.aims()
	local out = {}
	for _, h in heads do
		table.insert(out, { idx = h.idx, aim = h.aim, goal = h.goal })
	end
	table.sort(out, function(a, b)
		return a.idx < b.idx
	end)
	return out
end

local function clampToBounds(h, x, z)
	return Vector3.new(math.clamp(x, h.x1, h.x2), h.y, math.clamp(z, h.z1, h.z2))
end

-- personajes dentro de la pista (con margen), ordenados por UserId para un reparto estable
local function floorTargets(h)
	local list = {}
	for _, pl in Players:GetPlayers() do
		local ch = pl.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local p = hrp.Position
			if p.X >= h.x1 - F.Inset and p.X <= h.x2 + F.Inset and p.Z >= h.z1 - F.Inset and p.Z <= h.z2 + F.Inset and p.Y < 8 then
				table.insert(list, { id = pl.UserId, pos = p })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

local function retarget()
	local any
	for _, h in heads do
		any = h
		break
	end
	if not any then
		return
	end
	local list = floorTargets(any)
	local rot = math.floor(clock / F.Dwell)
	for _, h in heads do
		if #list > 0 then
			local t = list[((h.idx - 1 + rot) % #list) + 1]
			h.goal = clampToBounds(h, t.pos.X, t.pos.Z)
			h.idle = false
		else
			h.idle = true
		end
	end
end

local function idleGoal(h)
	-- barrido lento dentro de los limites (curva de Lissajous suave)
	local cx, cz = (h.x1 + h.x2) / 2, (h.z1 + h.z2) / 2
	local rx, rz = (h.x2 - h.x1) / 2 * 0.8, (h.z2 - h.z1) / 2 * 0.8
	local t = clock * 0.35 * (S.FollowSpeed or 0.8) + h.phase
	return clampToBounds(h, cx + rx * math.sin(t), cz + rz * math.sin(t * 0.73 + 1.3))
end

local function setEnabled(h, on)
	if h.set == on then
		return
	end
	h.set = on
	resolve(h)
	if h.light then
		h.light.Enabled = on
	end
	for _, b in h.beams do
		b.beam.Enabled = on
	end
end

function FollowLights.step(dt, nearClub)
	local want = S.Follow == true and (S.Master or 1) > 0.01
	if not want and fade <= 0 then
		if lastApplied.on then
			lastApplied.on = false
			for _, h in heads do
				setEnabled(h, false)
			end
		end
		return -- apagado: cero trabajo
	end
	if not nearClub then
		return
	end
	acc += dt
	local period = 1 / ((Config.Quality == "Alta" and 30) or F.UpdateHz)
	if acc < period then
		return
	end
	local step = acc
	acc = 0
	clock += step
	-- fundido de encendido / apagado
	local target = want and 1 or 0
	local df = step / math.max(0.1, F.FadeSeconds)
	if fade < target then
		fade = math.min(target, fade + df)
	elseif fade > target then
		fade = math.max(target, fade - df)
	end
	lastApplied.on = true
	if not announced then
		announced = true
		local n = 0
		for _ in heads do
			n += 1
		end
		if n == 0 then
			warn("[LaAlfombraRoja] focos rojos activados pero NO hay focos registrados en el cliente (etiqueta AR_Follow ausente o aun sin replicar)")
			announced = false -- reintentar el aviso mas tarde
			announcedAt = (announcedAt or 0) + 1
			if announcedAt > 3 then
				announced = true
			end
		else
			print(string.format("[LaAlfombraRoja] focos rojos ACTIVOS en el cliente (%d focos)", n))
		end
	end
	if clock >= retargetAt then
		retargetAt = clock + 0.6
		retarget()
	end
	local speed = S.FollowSpeed or 0.8
	local inten = math.clamp(S.FollowIntensity or 1, 0, 1.5)
	local k = 1 - math.exp(-F.Smooth * speed * step)
	local maxMove = F.MaxSpeed * speed * step
	local q = math.floor(inten * fade * 20 + 0.5) -- intensidad cuantizada: solo se escribe al cambiar
	for _, h in heads do
		local goal = h.idle and idleGoal(h) or h.goal
		local d = goal - h.aim
		local move = d * k
		local len = move.Magnitude
		if len > maxMove then
			move = move * (maxMove / len)
			len = maxMove
		end
		if len > 0.01 or h.set == nil then
			h.aim = clampToBounds(h, h.aim.X + move.X, h.aim.Z + move.Z)
			h.target.Position = h.aim
			h.head.CFrame = CFrame.lookAt(h.pos, h.aim)
		end
		local on = q > 0
		setEnabled(h, on)
		if h.q ~= q then
			h.q = q
			local f = q / 20
			if h.light then
				h.light.Brightness = h.base * f
			end
			local wscale = 0.35 + 0.65 * math.min(1, f)
			for _, b in h.beams do
				b.beam.Width0 = b.w0 * wscale
				b.beam.Width1 = b.w1 * wscale
			end
		end
	end
end

return FollowLights
