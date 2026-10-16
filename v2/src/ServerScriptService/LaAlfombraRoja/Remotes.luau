--[[
	REMOTES - crea los RemoteEvents y limita las peticiones por jugador y por remoto.
	Regla de oro: el servidor NO confia en nada del cliente. Cada remoto valida tipos y rangos y
	comprueba permisos/estado en el servidor; aqui solo se aplica el limite de frecuencia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage:WaitForChild("AlfombraShared"):WaitForChild("Util"))

local Remotes = {}

Remotes.NAMES = { "Shop", "ShopNotice", "Control", "ControlNotice", "Social", "SocialNotice" }

local folder
local buckets = {} -- [player] = { [remoteName] = bucket }

function Remotes.init()
	local old = ReplicatedStorage:FindFirstChild("AlfombraRemotes")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "AlfombraRemotes"
	for _, name in Remotes.NAMES do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

function Remotes.get(name)
	return folder and folder:FindFirstChild(name)
end

-- ficha de rate limit: `rate` peticiones por segundo (rafaga = rate). Devuelve true si se admite.
function Remotes.allow(player, name, rate)
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[name]
	if not b then
		b = Util.newBucket(rate, rate, now)
		pb[name] = b
	end
	return Util.take(b, now)
end

function Remotes.forget(player)
	buckets[player] = nil
end

function Remotes.fire(player, name, ...)
	local r = Remotes.get(name)
	if r and player then
		r:FireClient(player, ...)
	end
end

return Remotes
