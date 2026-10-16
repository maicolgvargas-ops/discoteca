--[[
	MOOD - "Discoteca oscura": baja la luz AMBIENTAL de tu pantalla segun el atributo Dark de la cabina (0..1).
	* Solo cambia Lighting.Ambient / OutdoorAmbient / ExposureCompensation en TU cliente, con transicion suave.
	* Nunca baja del MinKeep (30 %) de los valores originales: el club sigue siendo legible; ademas las luces de
	  escaleras, entrada y bar tienen su propio minimo (ver Control.SAFE).
	* No toca UserGameSettings ni RenderSettings ni la calidad grafica.
]]

local Lighting = game:GetService("Lighting")

local Mood = {}

local MIN_KEEP = 0.3
local S
local base = nil
local cur = 0
local acc = 0

local function capture()
	base = { amb = Lighting.Ambient, out = Lighting.OutdoorAmbient, exp = Lighting.ExposureCompensation }
end

local function apply(dark)
	local k = 1 - (1 - MIN_KEEP) * dark -- 1 -> 0.45
	local function sc(c)
		return Color3.new(c.R * k, c.G * k, c.B * k)
	end
	Lighting.Ambient = sc(base.amb)
	Lighting.OutdoorAmbient = sc(base.out)
	Lighting.ExposureCompensation = base.exp - 0.4 * dark
end

function Mood.init(effects)
	S = effects.S
	capture()
end

function Mood.current()
	return cur
end

function Mood.step(dt)
	local want = math.clamp(S.Dark or 0, 0, 1)
	if math.abs(want - cur) < 0.002 then
		return
	end
	acc += dt
	if acc < 0.05 then
		return
	end
	local step = acc
	acc = 0
	if not base then
		capture()
	end
	local d = want - cur
	local maxStep = step / 1.5 -- transicion de ~1,5 s
	cur = cur + math.clamp(d, -maxStep, maxStep)
	apply(cur)
end

return Mood
