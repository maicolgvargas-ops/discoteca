--[[
	MUSIC - reproductor de la cabina. Estado SINCRONIZADO para todos (atributos de club.Music) y un
	unico Sound en el altavoz del escenario.

	* LISTA BLANCA: solo se reproducen las pistas de Config.Music.Tracks (validadas al arrancar).
	  Ningun cliente puede mandar un assetId: las acciones reciben un INDICE (entero) o un numero.
	* Sin pistas configuradas no hay nada que reproducir: el estado es "none" y la interfaz lo explica
	  (no hay botones que simulen musica inexistente). No se incluye ningun audio inventado.
	* Solo el OPERADOR de la cabina (el mismo de las luces) puede cambiar la musica (ver Control.luau).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Music = {}

local tracks = {} -- lista blanca validada: { Id = "rbxassetid://n", Title, Artist }
local state = { index = 0, status = "none", volume = Config.Music.Volume }
local sound, folder
local endedConn
local sounds = {} -- un Sound por altavoz; todos suenan a la vez (sound = el principal)

local function setAttr(k, v)
	if folder then
		folder:SetAttribute(k, v)
	end
end

local function publish()
	local t = tracks[state.index]
	setAttr("Count", #tracks)
	setAttr("Index", state.index)
	setAttr("Status", state.status) -- "none" | "stopped" | "playing" | "paused"
	setAttr("Volume", state.volume)
	setAttr("Title", t and t.Title or "")
	setAttr("Artist", t and t.Artist or "")
	setAttr("Playing", state.status == "playing")
end

local function applyVolume()
	for _, s in sounds do
		s.Volume = math.clamp(state.volume, 0, 1) * Config.Music.MaxVolume
	end
end

local function load(index)
	local t = tracks[index]
	if not t or not sound then
		return false
	end
	state.index = index
	for _, s in sounds do
		s.SoundId = t.Id -- unica fuente del id: la lista blanca del servidor
		s.TimePosition = 0
	end
	return true
end

local function play()
	if #tracks == 0 or not sound then
		return false
	end
	if state.index == 0 then
		load(1)
	end
	applyVolume()
	for _, s in sounds do
		s:Play()
	end
	state.status = "playing"
	publish()
	return true
end

function Music.count()
	return #tracks
end

function Music.getState()
	return { index = state.index, status = state.status, volume = state.volume, count = #tracks }
end

-- Aplica una accion YA autorizada (operador comprobado en Control). Devuelve true si es valida.
function Music.handle(action, value)
	if #tracks == 0 then
		return false, "Aún no hay pistas configuradas (Config.Music.Tracks)."
	end
	if action == "MusicPlay" then
		return play()
	elseif action == "MusicPause" then
		if sound and state.status == "playing" then
			for _, s in sounds do
			s:Pause()
		end
			state.status = "paused"
			publish()
		end
		return true
	elseif action == "MusicSelect" then
		local i = Util.intInRange(value, 1, #tracks)
		if not i then
			return false
		end
		load(i)
		return play()
	elseif action == "MusicNext" or action == "MusicPrev" then
		local dir = (action == "MusicNext") and 1 or -1
		local i
		if state.index == 0 then
			i = (dir == 1) and 1 or #tracks
		else
			i = (state.index - 1 + dir) % #tracks + 1
		end
		load(i)
		return play()
	elseif action == "MusicVolume" then
		if not Util.isNumber(value) then
			return false
		end
		state.volume = math.clamp(math.floor(value * 20 + 0.5) / 20, 0, 1)
		applyVolume()
		publish()
		return true
	end
	return false
end

function Music.isMusicAction(action)
	return type(action) == "string" and string.sub(action, 1, 5) == "Music"
end

function Music.init(club)
	local oldFolder = club:FindFirstChild("Music")
	if oldFolder then
		oldFolder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Music"
	folder.Parent = club
	-- lista blanca: solo ids validos con titulo
	tracks = {}
	for i, t in Config.Music.Tracks do
		local id = type(t) == "table" and Util.normalizeAssetId(t.Id) or ""
		local title = type(t) == "table" and Util.shortString(t.Title, 60) or nil
		if id ~= "" and title then
			table.insert(tracks, { Id = id, Title = title, Artist = (type(t.Artist) == "string" and #t.Artist <= 60) and t.Artist or "" })
		else
			warn(string.format("[Music] pista %d ignorada: necesita Id valido y Title", i))
		end
	end
	if endedConn then
		endedConn:Disconnect()
		endedConn = nil
	end
	sound = nil
	sounds = {}
	for _, d in club:GetDescendants() do
		if d:IsA("Sound") and d.Name == "ClubMusic" then
			d.Looped = false
			d.RollOffMinDistance = Config.Music.RollOffMin
			d.RollOffMaxDistance = Config.Music.RollOffMax
			table.insert(sounds, d)
		end
	end
	sound = sounds[1]
	applyVolume()
	if sound then
		endedConn = sound.Ended:Connect(function()
			if Config.Music.AutoNext and state.status == "playing" and #tracks > 0 then
				Music.handle("MusicNext")
			end
		end)
	end
	state.index = 0
	state.status = (#tracks > 0) and "stopped" or "none"
	state.volume = math.clamp(Config.Music.Volume, 0, 1)
	publish()
	if Config.Music.Autoplay and #tracks > 0 then
		play()
	end
end

return Music
