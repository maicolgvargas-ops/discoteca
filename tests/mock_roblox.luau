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
Vector3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
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

local UDim = {}
function UDim.new(s, o)
	return { Scale = s, Offset = o, __type = "UDim" }
end
local UDim2 = {}
function UDim2.fromScale(x, y)
	return { X = x, Y = y, __type = "UDim2" }
end
function UDim2.fromOffset(x, y)
	return { OX = x, OY = y, __type = "UDim2" }
end
function UDim2.new(xs, xo, ys, yo)
	return { X = xs or 0, XO = xo or 0, Y = ys or 0, YO = yo or 0, __type = "UDim2" }
end

local ColorSequence = {}
function ColorSequence.new(a, b)
	assert(a ~= nil and a.__type == "Color3", "ColorSequence.new necesita un Color3")
	return { __type = "ColorSequence", first = a, last = b or a }
end
local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v)
	assert(type(t) == "number" and t >= 0 and t <= 1, "NumberSequenceKeypoint: tiempo fuera de [0,1]")
	assert(type(v) == "number" and v >= 0 and v <= 1, "NumberSequenceKeypoint: valor fuera de [0,1]: " .. tostring(v))
	return { Time = t, Value = v, __type = "NumberSequenceKeypoint" }
end
local NumberSequence = {}
function NumberSequence.new(keys)
	assert(type(keys) == "table" and #keys >= 2, "NumberSequence necesita >= 2 keypoints")
	assert(keys[1].Time == 0 and keys[#keys].Time == 1, "NumberSequence debe empezar en 0 y acabar en 1")
	for i = 2, #keys do
		assert(keys[i].Time > keys[i - 1].Time, "NumberSequence: tiempos no crecientes")
	end
	return { __type = "NumberSequence", Keypoints = keys }
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
function CFrame.Inverse(a)
	local r = a.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	return makeCF(-(rt[1] * a.px + rt[2] * a.py + rt[3] * a.pz), -(rt[4] * a.px + rt[5] * a.py + rt[6] * a.pz), -(rt[7] * a.px + rt[8] * a.py + rt[9] * a.pz), rt)
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
	Material = enumOf("Material", { "SmoothPlastic", "Neon", "Concrete", "Metal", "Glass", "Marble", "Wood", "WoodPlanks", "Fabric", "Slate", "Asphalt", "Grass", "Pavement", "Granite" }),
	PartType = enumOf("PartType", { "Block", "Ball", "Cylinder" }),
	SurfaceType = enumOf("SurfaceType", { "Smooth" }),
	NormalId = enumOf("NormalId", { "Front", "Bottom" }),
	SurfaceGuiSizingMode = enumOf("SurfaceGuiSizingMode", { "PixelsPerStud" }),
	Font = enumOf("Font", { "GothamBlack", "GothamMedium", "GothamBold", "Bodoni", "Garamond", "Gotham" }),
	ScaleType = enumOf("ScaleType", { "Fit" }),
	RollOffMode = enumOf("RollOffMode", { "InverseTapered" }),
	TextXAlignment = enumOf("TextXAlignment", { "Left", "Center", "Right" }),
	TextYAlignment = enumOf("TextYAlignment", { "Top", "Center", "Bottom" }),
	SortOrder = enumOf("SortOrder", { "LayoutOrder" }),
	KeyCode = enumOf("KeyCode", { "E" }),
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
	TextLabel = { props = { "Name", "Parent", "BackgroundTransparency", "Size", "Position", "Text", "TextScaled", "Font", "TextColor3", "TextStrokeColor3", "TextStrokeTransparency", "RichText", "TextXAlignment", "TextYAlignment", "ZIndex", "Visible" } },
	PointLight = { props = LIGHT },
	SpotLight = { props = concat(LIGHT, { "Face", "Angle" }) },
	Sound = { props = { "Name", "Parent", "SoundId", "Looped", "Volume", "RollOffMode", "RollOffMinDistance", "RollOffMaxDistance", "Playing" } },
	Fire = { props = { "Name", "Parent", "Size", "Heat", "Color", "SecondaryColor", "Enabled" } },
	BloomEffect = { props = { "Name", "Parent", "Intensity", "Size", "Threshold" } },
	ColorCorrectionEffect = { props = { "Name", "Parent", "Contrast", "Saturation", "TintColor", "Brightness" } },
	StarterGui = { props = { "Name", "Parent" } },
	ScreenGui = { props = { "Name", "Parent", "ResetOnSpawn", "IgnoreGuiInset", "DisplayOrder" } },
	Frame = { props = { "Name", "Parent", "AnchorPoint", "Position", "Size", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel" } },
	ImageLabel = { props = { "Name", "Parent", "BackgroundTransparency", "Image", "ScaleType", "Position", "Size", "AnchorPoint", "ImageTransparency" } },
	UICorner = { props = { "Name", "Parent", "CornerRadius" } },
	UIStroke = { props = { "Name", "Parent", "Color", "Thickness", "Transparency" } },
	UIGradient = { props = { "Name", "Parent", "Color", "Rotation" } },
	Attachment = { props = { "Name", "Parent", "Position", "CFrame" } },
	Beam = { props = { "Name", "Parent", "Attachment0", "Attachment1", "Color", "Transparency", "Width0", "Width1", "LightEmission", "LightInfluence", "FaceCamera", "Segments", "Enabled", "CurveSize0", "CurveSize1", "ZOffset" } },
	Smoke = { props = { "Name", "Parent", "Size", "Opacity", "RiseVelocity", "Color", "Enabled" } },
	DepthOfFieldEffect = { props = { "Name", "Parent", "FarIntensity", "NearIntensity", "FocusDistance", "InFocusRadius" } },
	Atmosphere = { props = { "Name", "Parent", "Density", "Offset", "Color", "Decay", "Glare", "Haze" } },
	Workspace = { props = { "Name", "Parent" } },
	Lighting = { props = { "Name", "Parent", "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness" } },
	RunService = { props = { "Name", "Parent" } },
	RemoteEvent = { props = { "Name", "Parent" } },
	ProximityPrompt = { props = { "Name", "Parent", "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight", "KeyboardKeyCode", "Enabled" } },
	LocalScript = { props = { "Name", "Parent", "Source", "Disabled" } },
	StarterPlayer = { props = { "Name", "Parent" } },
	ReplicatedStorage = { props = { "Name", "Parent" } },
	Players = { props = { "Name", "Parent" } },
	CollectionService = { props = { "Name", "Parent" } },
	Camera = { props = { "Name", "Parent", "CFrame" } },
	TextButton = { props = { "Name", "Parent", "BackgroundTransparency", "Size", "Position", "Text", "TextScaled", "Font", "TextColor3", "BackgroundColor3", "AutoButtonColor", "LayoutOrder", "TextWrapped", "Visible" } },
	ScrollingFrame = { props = { "Name", "Parent", "BackgroundTransparency", "Position", "Size", "CanvasSize", "ScrollBarThickness", "BorderSizePixel", "LayoutOrder" } },
	UIListLayout = { props = { "Name", "Parent", "Padding", "SortOrder" } },
}
CLASSES.Frame.props = concat(CLASSES.Frame.props, { "LayoutOrder", "Visible" })
CLASSES.TextLabel.props = concat(CLASSES.TextLabel.props, { "LayoutOrder", "TextWrapped", "BackgroundColor3", "AnchorPoint" })
CLASSES.ScreenGui.props = concat(CLASSES.ScreenGui.props, { "Enabled" })
CLASSES.Workspace.props = concat(CLASSES.Workspace.props, { "CurrentCamera" })

local __now = 0
local os = { clock = function() return __now end, time = os.time }
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
	if k == "AttributeChanged" then
		local any = rawget(self, "_anyAttr")
		if not any then any = Inst._makeSignal() rawset(self, "_anyAttr", any) end
		return any
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
	Beam = { LightEmission = { 0, 1 }, LightInfluence = { 0, 1 }, Width0 = { 0, 100 }, Width1 = { 0, 100 }, Segments = { 1, 300 } },
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
RANGES.Beam.Width0 = { 0, 100 }

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
local function makeSignal()
	local sig = { _fns = {} }
	function sig:Connect(fn)
		local e = { fn = fn, on = true }
		table.insert(self._fns, e)
		return { Disconnect = function() e.on = false end }
	end
	function sig:_fire(...)
		for _, e in self._fns do
			if e.on then e.fn(...) end
		end
	end
	return sig
end
Inst._makeSignal = makeSignal
function Inst:SetAttribute(k, v)
	local a = rawget(self, "_attrs")
	if not a then a = {} rawset(self, "_attrs", a) end
	if a[k] == v then return end
	a[k] = v
	local sigs = rawget(self, "_attrSigs")
	if sigs and sigs[k] then sigs[k]:_fire() end
	local any = rawget(self, "_anyAttr")
	if any then any:_fire(k) end
end
function Inst:GetAttribute(k)
	local a = rawget(self, "_attrs")
	return a and a[k]
end
function Inst:GetAttributeChangedSignal(k)
	local sigs = rawget(self, "_attrSigs")
	if not sigs then sigs = {} rawset(self, "_attrSigs", sigs) end
	if not sigs[k] then sigs[k] = makeSignal() end
	return sigs[k]
end
function Inst:WaitForChild(name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild: no existe " .. name .. " en " .. tostring(self._props.Name))
	return c
end
function Inst:Clone()
	local c = newInstance(self.ClassName)
	for k, v in self._props do
		c._props[k] = v
	end
	for _, ch in self._children do
		local cc = ch:Clone()
		cc.Parent = c
	end
	return c
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

local __noticeLog = {}
local __localPlayer = nil
local function __newWithSignals(className)
	local o = newInstance(className)
	if className == "RemoteEvent" then
		rawset(o, "OnServerEvent", makeSignal())
		rawset(o, "OnClientEvent", makeSignal())
		rawset(o, "FireClient", function(self, player, ...)
			table.insert(__noticeLog, { player = player, args = { ... } })
			self.OnClientEvent:_fire(...)
		end)
		rawset(o, "FireServer", function(self, ...)
			self.OnServerEvent:_fire(__localPlayer, ...)
		end)
	elseif className == "ProximityPrompt" then
		rawset(o, "Triggered", makeSignal())
	elseif className == "TextButton" then
		rawset(o, "MouseButton1Click", makeSignal())
	end
	if className == "Folder" or className == "Model" or className == "Part" then
		-- nada
	end
	return o
end
local Instance = {
	new = function(className)
		return __newWithSignals(className)
	end,
}

------------------------------------------------------------------------
-- Servicios / globals
------------------------------------------------------------------------
local __heartbeat = {}
local workspace = newInstance("Workspace")
local __lighting = newInstance("Lighting")
local __runService = newInstance("RunService")
local __starterGui = newInstance("StarterGui")
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
rawset(__runService, "IsStudio", function()
	return false
end)
local function fireHeartbeat(dt)
	__now += dt
	for _, entry in __heartbeat do
		if entry.active then
			entry.fn(dt)
		end
	end
end

local __replicated = newInstance("ReplicatedStorage")
local __starterPlayer = newInstance("StarterPlayer")
do
	local sps = newInstance("Folder")
	sps.Name = "StarterPlayerScripts"
	sps.Parent = __starterPlayer
end
local __collection = { _tags = {}, _added = {}, _removed = {} }
function __collection:AddTag(inst, tag)
	local list = self._tags[tag]
	if not list then list = {} self._tags[tag] = list end
	list[inst] = true
	if self._added[tag] then self._added[tag]:_fire(inst) end
end
function __collection:GetTagged(tag)
	local out = {}
	for inst in self._tags[tag] or {} do table.insert(out, inst) end
	return out
end
function __collection:GetInstanceAddedSignal(tag)
	if not self._added[tag] then self._added[tag] = makeSignal() end
	return self._added[tag]
end
function __collection:GetInstanceRemovedSignal(tag)
	if not self._removed[tag] then self._removed[tag] = makeSignal() end
	return self._removed[tag]
end
local __players = { _list = {}, PlayerRemoving = makeSignal(), PlayerAdded = makeSignal(), LocalPlayer = nil }
function __players:GetPlayers() return table.clone(self._list) end
-- jugador de prueba (tabla con la API que usan el servidor y el cliente)
local function __makePlayer(name, userId, pos)
	local gui = newInstance("Folder")
	gui.Name = "PlayerGui"
	local hrp = { Name = "HumanoidRootPart", Position = pos or Vector3.new(0, 3, 0) }
	local ch = { FindFirstChild = function(_, n) return n == "HumanoidRootPart" and hrp or nil end }
	local pl = { Name = name, UserId = userId, Character = ch, _gui = gui, _hrp = hrp, Parent = true }
	function pl:WaitForChild(n) return gui end
	function pl:FindFirstChildOfClass(c) return nil end
	function pl:GetRankInGroup(g) return self._rank or 0 end
	table.insert(__players._list, pl)
	return pl
end
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then return __replicated
		elseif name == "StarterPlayer" then return __starterPlayer
		elseif name == "CollectionService" then return __collection
		elseif name == "Players" then return __players
		end
		if name == "Workspace" then
			return workspace
		elseif name == "Lighting" then
			return __lighting
		elseif name == "RunService" then
			return __runService
		elseif name == "StarterGui" then
			return __starterGui
		end
		error("GetService('" .. tostring(name) .. "') no soportado en el mock")
	end,
}

-- Script del servidor: con __withClient = true tiene un hijo "ClientEffects" (el LocalScript)
local __withClient = false
local script = {
	FindFirstChild = function(_, n)
		if n == "ClientEffects" and __withClient then
			local ls = newInstance("LocalScript")
			ls.Name = "ClientEffects"
			return ls
		end
		return nil
	end,
}
do
	local cam = newInstance("Camera")
	cam.CFrame = CFrame.new(0, 30, 100)
	workspace.CurrentCamera = cam
end

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
