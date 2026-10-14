-- Mock minimo de la API de Roblox para ejecutar AuraClub.server.luau fuera de Studio.
-- Valida clases, propiedades y miembros de Enum: un typo falla aqui en vez de en Studio.
-- Se concatena delante del script (ver tests/run.sh), por eso todo son `local`.

------------------------------------------------------------------------
-- Vector3 / Color3 / UDim2
------------------------------------------------------------------------
local _G = {} -- en Roblox _G es una tabla normal; en el CLI de Luau es solo lectura
local Vector3 = {}
Vector3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return rawget(Vector3, k)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.new(x, y, z)
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "Vector3.new: argumentos invalidos")
	return setmetatable({ X = x, Y = y, Z = z, __type = "Vector3" }, Vector3)
end

local Color3 = {}
function Color3.new(r, g, b)
	return { R = r, G = g, B = b, __type = "Color3" }
end
function Color3.fromRGB(r, g, b)
	assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255, "Color3.fromRGB fuera de rango")
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3.fromHSV(h, s, v)
	assert(h >= 0 and h <= 1 and s >= 0 and s <= 1 and v >= 0 and v <= 1, "Color3.fromHSV fuera de rango: " .. h .. "," .. s .. "," .. v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	local r, g, b
	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	else r, g, b = v, p, q end
	return Color3.new(r, g, b)
end

local UDim2 = {}
function UDim2.fromScale(x, y)
	return { X = x, Y = y, __type = "UDim2" }
end

local Vector2 = {}
function Vector2.new(x, y)
	return { X = x, Y = y, __type = "Vector2" }
end

------------------------------------------------------------------------
-- CFrame (posicion + matriz de rotacion 3x3, columnas = ejes locales)
------------------------------------------------------------------------
local CFrame = {}
local function mat3mul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function makeCF(px, py, pz, r)
	return setmetatable({ px = px, py = py, pz = pz, r = r, __type = "CFrame" }, CFrame)
end
CFrame.__index = function(self, k)
	if k == "Position" then
		return Vector3.new(self.px, self.py, self.pz)
	elseif k == "LookVector" then
		return Vector3.new(-self.r[3], -self.r[6], -self.r[9])
	end
	return rawget(CFrame, k)
end
CFrame.__mul = function(a, b)
	if b.__type == "Vector3" then
		local r = a.r
		return Vector3.new(
			a.px + r[1] * b.X + r[2] * b.Y + r[3] * b.Z,
			a.py + r[4] * b.X + r[5] * b.Y + r[6] * b.Z,
			a.pz + r[7] * b.X + r[8] * b.Y + r[9] * b.Z
		)
	end
	local r = a.r
	return makeCF(
		a.px + r[1] * b.px + r[2] * b.py + r[3] * b.pz,
		a.py + r[4] * b.px + r[5] * b.py + r[6] * b.pz,
		a.pz + r[7] * b.px + r[8] * b.py + r[9] * b.pz,
		mat3mul(a.r, b.r)
	)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return makeCF(x.X, x.Y, x.Z, IDENT)
	end
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "CFrame.new: argumentos invalidos")
	return makeCF(x, y, z, IDENT)
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return makeCF(0, 0, 0, mat3mul(mat3mul(Rx, Ry), Rz))
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local back = at - target
	local len = back.Magnitude
	assert(len > 0, "lookAt: mismo punto")
	local zx, zy, zz = back.X / len, back.Y / len, back.Z / len
	-- x = up x z
	local xx, xy, xz = up.Y * zz - up.Z * zy, up.Z * zx - up.X * zz, up.X * zy - up.Y * zx
	local xl = math.sqrt(xx * xx + xy * xy + xz * xz)
	assert(xl > 1e-6, "lookAt: paralelo a up")
	xx, xy, xz = xx / xl, xy / xl, xz / xl
	-- y = z x x
	local yx, yy, yz = zy * xz - zz * xy, zz * xx - zx * xz, zx * xy - zy * xx
	return makeCF(at.X, at.Y, at.Z, { xx, yx, zx, xy, yy, zy, xz, yz, zz })
end

------------------------------------------------------------------------
-- Enum con miembros validados
------------------------------------------------------------------------
local function enumOf(name, members)
	local set = {}
	for _, m in members do
		set[m] = "Enum." .. name .. "." .. m
	end
	return setmetatable(set, {
		__index = function(_, k)
			error("Enum." .. name .. "." .. tostring(k) .. " no existe", 2)
		end,
	})
end
local Enum = {
	Material = enumOf("Material", { "SmoothPlastic", "Neon", "Concrete", "Metal", "Glass", "Marble", "Wood", "WoodPlanks", "Fabric", "Slate", "Asphalt", "Grass" }),
	PartType = enumOf("PartType", { "Block", "Ball", "Cylinder" }),
	SurfaceType = enumOf("SurfaceType", { "Smooth" }),
	NormalId = enumOf("NormalId", { "Front", "Bottom" }),
	SurfaceGuiSizingMode = enumOf("SurfaceGuiSizingMode", { "PixelsPerStud" }),
	Font = enumOf("Font", { "GothamBlack" }),
	RollOffMode = enumOf("RollOffMode", { "InverseTapered" }),
}

------------------------------------------------------------------------
-- Instance
------------------------------------------------------------------------
local PART_PROPS = { "Name", "Parent", "Anchored", "Size", "CFrame", "Color", "Material", "TopSurface", "BottomSurface", "CanCollide", "CastShadow", "Transparency", "Shape", "Reflectance" }
local function concat(...)
	local out = {}
	for _, list in { ... } do
		for _, v in list do
			table.insert(out, v)
		end
	end
	return out
end
local LIGHT = { "Name", "Parent", "Color", "Range", "Brightness", "Shadows", "Enabled" }
local CLASSES = {
	Part = { props = PART_PROPS, base = true },
	WedgePart = { props = PART_PROPS, base = true },
	SpawnLocation = { props = concat(PART_PROPS, { "Neutral", "Duration", "Enabled", "AllowTeamChangeOnTouch", "TeamColor" }), base = true },
	Model = { props = { "Name", "Parent" } },
	Folder = { props = { "Name", "Parent" } },
	SurfaceGui = { props = { "Name", "Parent", "Face", "SizingMode", "PixelsPerStud", "LightInfluence", "Brightness", "AlwaysOnTop" } },
	TextLabel = { props = { "Name", "Parent", "BackgroundTransparency", "Size", "Text", "TextScaled", "Font", "TextColor3" } },
	PointLight = { props = LIGHT },
	SpotLight = { props = concat(LIGHT, { "Face", "Angle" }) },
	Sound = { props = { "Name", "Parent", "SoundId", "Looped", "Volume", "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance", "Playing" } },
	Fire = { props = { "Name", "Parent", "Size", "Heat", "Color", "SecondaryColor", "Enabled" } },
	BloomEffect = { props = { "Name", "Parent", "Intensity", "Size", "Threshold" } },
	ColorCorrectionEffect = { props = { "Name", "Parent", "Contrast", "Saturation", "TintColor", "Brightness" } },
	Smoke = { props = { "Name", "Parent", "Size", "Opacity", "RiseVelocity", "Color", "Enabled" } },
	DepthOfFieldEffect = { props = { "Name", "Parent", "FarIntensity", "NearIntensity", "FocusDistance", "InFocusRadius" } },
	Atmosphere = { props = { "Name", "Parent", "Density", "Offset", "Color", "Decay", "Glare", "Haze" } },
	Workspace = { props = { "Name", "Parent" } },
	Lighting = { props = { "Name", "Parent", "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness" } },
	RunService = { props = { "Name", "Parent" } },
}

local __countWrites, __writes = false, 0
local Inst = {}
local function newInstance(className)
	local def = CLASSES[className]
	assert(def, "Instance.new: clase desconocida '" .. tostring(className) .. "'")
	local allowed = {}
	for _, p in def.props do
		allowed[p] = true
	end
	local self = { ClassName = className, _props = { Name = className }, _children = {}, _allowed = allowed, _parent = nil, _def = def }
	return setmetatable(self, Inst)
end
Inst.__index = function(self, k)
	local m = rawget(Inst, k)
	if m then
		return m
	end
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	local v = self._props[k]
	if v ~= nil then
		return v
	end
	if self._allowed[k] then
		return nil
	end
	error(self.ClassName .. "." .. tostring(k) .. " no es una propiedad valida", 2)
end
-- rangos validos de propiedades numericas (los que Studio recorta o rechaza)
local RANGES = {
	Part = { Transparency = { 0, 1 }, Reflectance = { 0, 1 } },
	WedgePart = { Transparency = { 0, 1 }, Reflectance = { 0, 1 } },
	SpawnLocation = { Transparency = { 0, 1 }, Reflectance = { 0, 1 }, Duration = { 0, 1e6 } },
	PointLight = { Range = { 0, 60 }, Brightness = { 0, 1e4 } },
	SpotLight = { Range = { 0, 60 }, Brightness = { 0, 1e4 }, Angle = { 0, 180 } },
	Fire = { Size = { 2, 30 }, Heat = { -25, 25 } },
	Smoke = { Size = { 0.1, 100 }, Opacity = { 0, 1 }, RiseVelocity = { -25, 25 } },
	Sound = { Volume = { 0, 10 }, RollOffMinDistance = { 0, 1e5 }, RollOffMaxDistance = { 0, 1e5 } },
	BloomEffect = { Intensity = { 0, 100 }, Size = { 0, 56 }, Threshold = { 0, 100 } },
	ColorCorrectionEffect = { Contrast = { -1, 1 }, Saturation = { -1, 1 } },
	DepthOfFieldEffect = { FarIntensity = { 0, 1 }, NearIntensity = { 0, 1 }, FocusDistance = { 0, 1e5 }, InFocusRadius = { 0, 1e5 } },
	Atmosphere = { Density = { 0, 1 }, Offset = { 0, 1 }, Glare = { 0, 10 }, Haze = { 0, 10 } },
	Lighting = { ExposureCompensation = { -5, 5 }, ShadowSoftness = { 0, 1 }, EnvironmentDiffuseScale = { 0, 1 }, EnvironmentSpecularScale = { 0, 1 }, ClockTime = { 0, 24 } },
	SurfaceGui = { PixelsPerStud = { 1, 500 } },
	TextLabel = { BackgroundTransparency = { 0, 1 } },
}

Inst.__newindex = function(self, k, v)
	if not self._allowed[k] then
		error(self.ClassName .. "." .. tostring(k) .. " no es una propiedad valida (asignacion)", 2)
	end
	if v == nil and k ~= "Parent" then
		error(self.ClassName .. "." .. k .. " = nil", 2)
	end
	if k == "Parent" then
		if rawget(self, "_parent") then
			for i, c in rawget(self, "_parent")._children do
				if c == self then
					table.remove(rawget(self, "_parent")._children, i)
					break
				end
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(v._children, self)
		end
		return
	end
	local rg = RANGES[self.ClassName] and RANGES[self.ClassName][k]
	if rg and type(v) == "number" then
		assert(v >= rg[1] and v <= rg[2], string.format("%s.%s = %s fuera de rango [%s, %s]", self.ClassName, k, tostring(v), tostring(rg[1]), tostring(rg[2])))
	end
	if k == "Size" and self._def.base then
		assert(v.X >= 0.05 and v.Y >= 0.05 and v.Z >= 0.05, "Part con tamano < 0.05: " .. tostring(self._props.Name))
		assert(v.X <= 2048 and v.Y <= 2048 and v.Z <= 2048, "Part demasiado grande")
	end
	if __countWrites then
		__writes += 1
	end
	self._props[k] = v
end
function Inst:GetChildren()
	return table.clone(self._children)
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in n._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(name)
	for _, c in self._children do
		if c._props.Name == name then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(cls)
	for _, c in self._children do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function Inst:IsA(cls)
	return self.ClassName == cls or cls == "Instance" or (cls == "BasePart" and self._def.base == true)
end
function Inst:Destroy()
	self.Parent = nil
end
function Inst:Play()
	self._props.Playing = true
end

local Instance = {
	new = function(className)
		return newInstance(className)
	end,
}

------------------------------------------------------------------------
-- Servicios / globals
------------------------------------------------------------------------
local __heartbeat = {}
local workspace = newInstance("Workspace")
local __lighting = newInstance("Lighting")
local __runService = newInstance("RunService")
local heartbeatSignal = {
	Connect = function(_, fn)
		local entry = { fn = fn, active = true }
		table.insert(__heartbeat, entry)
		return {
			Disconnect = function()
				entry.active = false
			end,
		}
	end,
}
-- RunService.Heartbeat
rawset(__runService, "Heartbeat", heartbeatSignal)
rawset(__runService, "IsRunning", function()
	return true
end)
local function fireHeartbeat(dt)
	for _, entry in __heartbeat do
		if entry.active then
			entry.fn(dt)
		end
	end
end

local game = {
	GetService = function(_, name)
		if name == "Workspace" then
			return workspace
		elseif name == "Lighting" then
			return __lighting
		elseif name == "RunService" then
			return __runService
		end
		error("GetService('" .. tostring(name) .. "') no soportado en el mock")
	end,
}

local function warn(...)
	print("WARN:", ...)
end

-- plantilla "Baseplate" de Studio: el script debe borrarla
do
	local bp = newInstance("Part")
	bp.Name = "Baseplate"
	bp.Size = Vector3.new(512, 20, 512)
	bp.CFrame = CFrame.new(0, -10, 0)
	bp.Parent = workspace
end
