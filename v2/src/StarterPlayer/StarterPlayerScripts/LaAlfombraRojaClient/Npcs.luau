--[[
	NPCS - animacion LOCAL de los NPC decorativos (guardias, bartenders y bailarinas de la zona VIP).
	Los NPC son modelos R6 hechos por codigo con el HumanoidRootPart anclado: el servidor no los mueve.
	Aqui cada cliente anima solo los que tiene cerca (Config.Npcs.AnimateDistance) y como mucho
	Config.Npcs.MaxAnimated a la vez, a baja frecuencia. Fuera de distancia vuelven a su pose base.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AlfombraShared")
local Config = require(Shared:WaitForChild("Config"))
local DancePoses = require(Shared:WaitForChild("DancePoses"))

local Npcs = {}

local list = {} -- [model] = { model, root, state, role, dance, phase, active }
local acc = 0
local activeCount = 0

local function register(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or list[model] then
		return
	end
	local role = model:GetAttribute("AR_Role")
	local id = (role == "guard") and "guardia" or ((role == "bartender") and "barra" or model:GetAttribute("Dance"))
	list[model] = { model = model, root = root, state = nil, role = role, id = id, phase = model:GetAttribute("Phase") or 0, active = false }
end

function Npcs.init()
	if not Config.Npcs.Enabled then
		return
	end
	for _, m in CollectionService:GetTagged("AR_Npc") do
		register(m)
	end
	CollectionService:GetInstanceAddedSignal("AR_Npc"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("AR_Npc"):Connect(function(m)
		list[m] = nil
	end)
end

function Npcs.count()
	local n = 0
	for _ in list do
		n += 1
	end
	return n, activeCount
end

-- se llama desde el bucle principal; trabaja a ~15-20 Hz
function Npcs.step(dt)
	acc += dt
	if acc < 0.06 then
		return
	end
	acc = 0
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local maxD = Config.Npcs.AnimateDistance
	-- candidatos dentro de distancia, los mas cercanos primero
	local cands = {}
	for _, n in list do
		local d = (n.root.Position - camPos).Magnitude
		if d <= maxD then
			table.insert(cands, { n = n, d = d })
		elseif n.active then
			DancePoses.reset(n.state)
			n.active = false
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	activeCount = 0
	local now = Workspace:GetServerTimeNow()
	for i, c in cands do
		local n = c.n
		if i > Config.Npcs.MaxAnimated then
			if n.active then
				DancePoses.reset(n.state)
				n.active = false
			end
		else
			if not n.state then
				n.state = DancePoses.new(n.model)
			end
			if n.state and n.id then
				n.active = true
				activeCount += 1
				DancePoses.apply(n.state, n.id, now + n.phase, 1)
			end
		end
	end
end

return Npcs
