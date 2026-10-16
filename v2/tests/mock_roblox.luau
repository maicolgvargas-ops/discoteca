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
	NormalId = enumOf("NormalId", { "Front", "Bottom", "Top" }),
	SurfaceGuiSizingMode = enumOf("SurfaceGuiSizingMode", { "PixelsPerStud" }),
	Font = enumOf("Font", { "GothamBlack", "GothamMedium", "GothamBold", "Bodoni", "Garamond", "Gotham", "SourceSans", "SourceSansBold" }),
	ScaleType = enumOf("ScaleType", { "Fit" }),
	RollOffMode = enumOf("RollOffMode", { "InverseTapered" }),
	TextXAlignment = enumOf("TextXAlignment", { "Left", "Center", "Right" }),
	TextYAlignment = enumOf("TextYAlignment", { "Top", "Center", "Bottom" }),
	SortOrder = enumOf("SortOrder", { "LayoutOrder" }),
	KeyCode = enumOf("KeyCode", { "E" }),
	HumanoidRigType = enumOf("HumanoidRigType", { "R6", "R15" }),
	HumanoidHealthDisplayType = enumOf("HumanoidHealthDisplayType", { "AlwaysOff", "DisplayWhenDamaged" }),
	ProductPurchaseDecision = enumOf("ProductPurchaseDecision", { "PurchaseGranted", "NotProcessedYet" }),
	InfoType = enumOf("InfoType", { "Product" }),
	ThumbnailType = enumOf("ThumbnailType", { "HeadShot", "AvatarBust" }),
	ThumbnailSize = enumOf("ThumbnailSize", { "Size100x100", "Size150x150" }),
	ChatVersion = enumOf("ChatVersion", { "LegacyChatService", "TextChatService" }),
	AutomaticSize = enumOf("AutomaticSize", { "None", "Y", "XY" }),
	ZIndexBehavior = enumOf("ZIndexBehavior", { "Sibling", "Global" }),
}

------------------------------------------------------------------------
-- Instance
------------------------------------------------------------------------
local PART_PROPS = { "Name", "Parent", "Anchored", "Size", "CFrame", "Color", "Material", "TopSurface", "BottomSurface", "CanCollide", "CastShadow", "Transparency", "Shape", "Reflectance", "Massless", "CanTouch", "CanQuery", "CollisionGroup", "Locked", "Position" }
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
	Seat = { props = concat(PART_PROPS, { "Disabled" }), base = true },
	Model2 = { props = { "Name", "Parent" } },
	Humanoid = { props = { "Name", "Parent", "RigType", "DisplayName", "NameDisplayDistance", "HealthDisplayType", "Health", "MaxHealth", "Sit", "WalkSpeed", "JumpPower", "JumpHeight", "SeatPart", "HipHeight", "PlatformStand", "BreakJointsOnDeath" } },
	Motor6D = { props = { "Name", "Parent", "Part0", "Part1", "C0", "C1", "Transform" } },
	Weld = { props = { "Name", "Parent", "Part0", "Part1", "C0", "C1" } },
	WeldConstraint = { props = { "Name", "Parent", "Part0", "Part1" } },
	Tool = { props = { "Name", "Parent", "ToolTip", "CanBeDropped", "RequiresHandle", "GripPos", "GripForward", "GripUp", "GripRight", "Grip", "Enabled" } },
	Backpack = { props = { "Name", "Parent" } },
	PlayerGui = { props = { "Name", "Parent" } },
	Player = { props = { "Name", "Parent", "UserId", "DisplayName", "Character" } },
	ModuleScript = { props = { "Name", "Parent", "Source" } },
	Script = { props = { "Name", "Parent", "Source", "RunContext", "Disabled" } },
	RemoteFunction = { props = { "Name", "Parent" } },
	ViewportFrame = { props = { "Name", "Parent", "Size", "Position", "BackgroundTransparency", "BackgroundColor3", "CurrentCamera", "LayoutOrder", "Ambient", "LightColor", "LightDirection", "AnchorPoint", "BorderSizePixel" } },
	WorldModel = { props = { "Name", "Parent" } },
	ImageButton = { props = { "Name", "Parent", "Image", "Size", "Position", "BackgroundTransparency", "LayoutOrder" } },
	UIPadding = { props = { "Name", "Parent", "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } },
	UIGridLayout = { props = { "Name", "Parent", "CellSize", "CellPadding", "SortOrder" } },
	TextBox = { props = { "Name", "Parent", "Text", "PlaceholderText", "Size", "Position", "Font", "TextColor3", "TextScaled", "BackgroundColor3", "ClearTextOnFocus", "LayoutOrder" } },
	BillboardGui = { props = { "Name", "Parent", "Size", "StudsOffset", "AlwaysOnTop", "MaxDistance", "Adornee", "LightInfluence" } },
	ProximityPromptService = { props = { "Name", "Parent" } },
	ServerScriptService = { props = { "Name", "Parent" } },
	TextChatService = { props = { "Name", "Parent" } },
	ChatWindowConfiguration = { props = { "Name", "Parent", "Enabled" } },
	ChatInputBarConfiguration = { props = { "Name", "Parent", "Enabled" } },
	BubbleChatConfiguration = { props = { "Name", "Parent", "Enabled" } },
	LocalScript = { props = { "Name", "Parent", "Source", "Disabled" } },
}
CLASSES.Frame.props = concat(CLASSES.Frame.props, { "LayoutOrder", "Visible" })
CLASSES.TextLabel.props = concat(CLASSES.TextLabel.props, { "LayoutOrder", "TextWrapped", "BackgroundColor3", "AnchorPoint" })
CLASSES.ScreenGui.props = concat(CLASSES.ScreenGui.props, { "Enabled" })
CLASSES.Workspace.props = concat(CLASSES.Workspace.props, { "CurrentCamera" })
CLASSES.Model.props = concat(CLASSES.Model.props, { "PrimaryPart" })
CLASSES.Sound.props = concat(CLASSES.Sound.props, { "TimePosition", "TimeLength", "PlaybackLoudness", "IsPlaying" })
CLASSES.Camera.props = concat(CLASSES.Camera.props, { "FieldOfView", "Focus" })
CLASSES.Frame.props = concat(CLASSES.Frame.props, { "ClipsDescendants", "ZIndex" })
CLASSES.TextButton.props = concat(CLASSES.TextButton.props, { "ZIndex", "TextXAlignment" })
CLASSES.ImageLabel.props = concat(CLASSES.ImageLabel.props, { "LayoutOrder", "ZIndex" })
CLASSES.TextLabel.props = concat(CLASSES.TextLabel.props, { "TextTransparency" })

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
	if k == "Position" and self._def.base then
		local cf = self._props.CFrame
		return cf and cf.Position or nil
	end
	if k == "Occupant" then
		return rawget(self, "_occupant")
	end
	if k == "SeatPart" and self.ClassName == "Humanoid" then
		return rawget(self, "_seatPart")
	end
	if k == "DescendantAdded" or k == "ChildAdded" then
		local key = "_sig_" .. k
		local sg = rawget(self, key)
		if not sg then sg = Inst._makeSignal() rawset(self, key, sg) end
		return sg
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
	for _, c in self._children do
		if c._props.Name == k then
			return c
		end
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
	if k == "Position" and self._def.base then
		local cf = self._props.CFrame
		local r = cf and cf.r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		self._props.CFrame = CFrame.new(v.X, v.Y, v.Z) * CFrame.new(0, 0, 0)
		self._props.CFrame = makeCF(v.X, v.Y, v.Z, r)
		return
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
			local ca = rawget(v, "_sig_ChildAdded")
			if ca then ca:_fire(self) end
			local anc = v
			while anc do
				local da = rawget(anc, "_sig_DescendantAdded")
				if da then da:_fire(self) end
				anc = rawget(anc, "_parent")
			end
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
	local old = self._props[k]
	self._props[k] = v
	local ps = rawget(self, "_propSigs")
	if ps and ps[k] and old ~= v then
		ps[k]:_fire()
	end
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
local GUI_OBJECTS = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true }
local SOURCES = { Script = true, LocalScript = true, ModuleScript = true }
function Inst:IsA(cls)
	return self.ClassName == cls or cls == "Instance" or (cls == "BasePart" and self._def.base == true) or (cls == "GuiObject" and GUI_OBJECTS[self.ClassName] == true) or (cls == "LuaSourceContainer" and SOURCES[self.ClassName] == true) or (cls == "Light" and (self.ClassName == "PointLight" or self.ClassName == "SpotLight"))
end
function Inst:GetPropertyChangedSignal(k)
	local ps = rawget(self, "_propSigs")
	if not ps then ps = {} rawset(self, "_propSigs", ps) end
	if not ps[k] then ps[k] = makeSignal() end
	return ps[k]
end
function Inst:IsDescendantOf(anc)
	local p = rawget(self, "_parent")
	while p do
		if p == anc then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function Inst:GetFullName()
	local n = self._props.Name
	local p = rawget(self, "_parent")
	while p do
		n = p._props.Name .. "." .. n
		p = rawget(p, "_parent")
	end
	return n
end
function Inst:ClearAllChildren()
	for _, c in table.clone(self._children) do c:Destroy() end
end
function Inst:FindFirstAncestorOfClass(cls)
	local p = rawget(self, "_parent")
	while p do
		if p.ClassName == cls then return p end
		p = rawget(p, "_parent")
	end
	return nil
end
function Inst:Destroy()
	local d = rawget(self, "_destroying")
	if d then d:_fire() end
	self.Parent = nil
end
function Inst:Play()
	self._props.Playing = true
end

local __noticeLog = {}
local __localPlayer = nil
local __isStudio = false
local __tasks = {}

local function __newWithSignals(className)
	local o = newInstance(className)
	if className == "RemoteEvent" then
		rawset(o, "OnServerEvent", makeSignal())
		rawset(o, "OnClientEvent", makeSignal())
		rawset(o, "FireClient", function(self, player, ...)
			table.insert(__noticeLog, { player = player, remote = self._props.Name, args = { ... } })
			if player == __localPlayer then
				self.OnClientEvent:_fire(...)
			end
		end)
		rawset(o, "FireServer", function(self, ...)
			self.OnServerEvent:_fire(__localPlayer, ...)
		end)
	elseif className == "RemoteFunction" then
		rawset(o, "InvokeServer", function(self, ...)
			assert(self.OnServerInvoke, "RemoteFunction sin OnServerInvoke")
			return self.OnServerInvoke(__localPlayer, ...)
		end)
		rawset(o, "OnServerInvoke", nil)
	elseif className == "ProximityPrompt" then
		rawset(o, "Triggered", makeSignal())
	elseif className == "TextButton" or className == "ImageButton" then
		local sg = makeSignal()
		rawset(o, "MouseButton1Click", sg)
		rawset(o, "Activated", sg)
	elseif className == "TextBox" then
		rawset(o, "FocusLost", makeSignal())
	elseif className == "Tool" then
		rawset(o, "Activated", makeSignal())
		rawset(o, "Equipped", makeSignal())
		rawset(o, "Unequipped", makeSignal())
	elseif className == "Humanoid" then
		rawset(o, "Running", makeSignal())
		rawset(o, "Jumping", makeSignal())
		rawset(o, "Died", makeSignal())
		rawset(o, "ChangeState", function() end)
		o._props.Health = 100
		o._props.MaxHealth = 100
		o._props.Sit = false
	elseif className == "Seat" then
		rawset(o, "Sit", function(self, humanoid)
			local cur = rawget(self, "_occupant")
			if cur and cur ~= humanoid then
				return
			end
			rawset(self, "_occupant", humanoid)
			rawset(humanoid, "_seatPart", self)
			humanoid._props.Sit = true
			local ps = rawget(self, "_propSigs")
			if ps and ps.Occupant then ps.Occupant:_fire() end
		end)
	elseif className == "Sound" then
		rawset(o, "Ended", makeSignal())
		rawset(o, "Play", function(self)
			self._props.Playing = true
			self._props.IsPlaying = true
		end)
		rawset(o, "Pause", function(self)
			self._props.Playing = false
			self._props.IsPlaying = false
		end)
		rawset(o, "Stop", function(self)
			self._props.Playing = false
			self._props.IsPlaying = false
			self._props.TimePosition = 0
		end)
	elseif className == "Player" then
		rawset(o, "CharacterAdded", makeSignal())
		rawset(o, "GetRankInGroup", function(self, g)
			return rawget(self, "_rank") or 0
		end)
	end
	rawset(o, "_destroying", makeSignal())
	rawset(o, "Destroying", rawget(o, "_destroying"))
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
rawset(__runService, "Heartbeat", heartbeatSignal)
rawset(__runService, "RenderStepped", heartbeatSignal)
rawset(__runService, "IsRunning", function()
	return true
end)
rawset(__runService, "IsStudio", function()
	return __isStudio
end)
rawset(__runService, "IsServer", function()
	return true
end)
rawset(workspace, "GetServerTimeNow", function()
	return __now
end)

local function fireHeartbeat(dt)
	__now += dt
	-- tareas diferidas (task.delay)
	local due = {}
	for i = #__tasks, 1, -1 do
		if __tasks[i].at <= __now then
			table.insert(due, 1, table.remove(__tasks, i))
		end
	end
	for _, t in due do
		t.fn()
	end
	for _, entry in __heartbeat do
		if entry.active then
			entry.fn(dt)
		end
	end
end

local task = {
	wait = function(t)
		__now += (t or 0.03)
		return t or 0.03
	end,
	spawn = function(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			print("[task.spawn error] " .. tostring(err))
		end
	end,
	defer = function(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			print("[task.defer error] " .. tostring(err))
		end
	end,
	delay = function(t, fn)
		table.insert(__tasks, { at = __now + t, fn = fn })
	end,
}

local __replicated = newInstance("ReplicatedStorage")
local __serverScripts = newInstance("ServerScriptService")
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

-- Players ---------------------------------------------------------------
local __players = { _list = {}, PlayerRemoving = makeSignal(), PlayerAdded = makeSignal(), LocalPlayer = nil }
function __players:GetPlayers() return table.clone(self._list) end
function __players:GetPlayerByUserId(id)
	for _, p in self._list do
		if p.UserId == id then return p end
	end
	return nil
end
function __players:GetUserThumbnailAsync(userId, thumbType, size)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150", true
end

local function __makePlayer(name, userId)
	local pl = __newWithSignals("Player")
	pl.Name = name
	pl.UserId = userId
	pl.DisplayName = name
	local bp = newInstance("Backpack")
	bp.Name = "Backpack"
	bp.Parent = pl
	local gui = newInstance("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = pl
	table.insert(__players._list, pl)
	return pl
end

local function __motor(parent, name, p0, p1, c0)
	local m = newInstance("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0 or CFrame.new(0, 0, 0)
	m.C1 = CFrame.new(0, 0, 0)
	m.Parent = parent
	return m
end

-- crea el personaje (R6 o R15) del jugador en `pos`
local function __spawnCharacter(pl, pos, rigType)
	rigType = rigType or "R15"
	local ch = newInstance("Model")
	ch.Name = pl.Name
	local function part(name, size, at)
		local p = newInstance("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos.X + at.X, pos.Y + at.Y, pos.Z + at.Z)
		p.Anchored = false
		p.Parent = ch
		return p
	end
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
	local hum = __newWithSignals("Humanoid")
	hum.Name = "Humanoid"
	hum.RigType = (rigType == "R6") and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
	hum.Parent = ch
	if rigType == "R6" then
		local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0))
		local aR = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
		local aL = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
		local lR = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
		local lL = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
		__motor(hrp, "RootJoint", hrp, torso, CFrame.new(0, 0, 0))
		__motor(torso, "Neck", torso, head, CFrame.new(0, 1, 0))
		__motor(torso, "Right Shoulder", torso, aR, CFrame.new(1, 0.5, 0))
		__motor(torso, "Left Shoulder", torso, aL, CFrame.new(-1, 0.5, 0))
		__motor(torso, "Right Hip", torso, lR, CFrame.new(1, -1, 0))
		__motor(torso, "Left Hip", torso, lL, CFrame.new(-1, -1, 0))
	else
		local lt = part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.8, 0))
		local ut = part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.4, 0))
		local uaR = part("RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.6, 0))
		local laR = part("RightLowerArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, -0.6, 0))
		local uaL = part("LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.6, 0))
		local laL = part("LeftLowerArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, -0.6, 0))
		local ulR = part("RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -1.6, 0))
		local llR = part("RightLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -2.6, 0))
		local ulL = part("LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -1.6, 0))
		local llL = part("LeftLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -2.6, 0))
		__motor(lt, "Root", hrp, lt, CFrame.new(0, 0, 0))
		__motor(ut, "Waist", lt, ut, CFrame.new(0, 0.2, 0))
		__motor(head, "Neck", ut, head, CFrame.new(0, 0.8, 0))
		__motor(uaR, "RightShoulder", ut, uaR, CFrame.new(1.2, 0.6, 0))
		__motor(laR, "RightElbow", uaR, laR, CFrame.new(0, -0.6, 0))
		__motor(uaL, "LeftShoulder", ut, uaL, CFrame.new(-1.2, 0.6, 0))
		__motor(laL, "LeftElbow", uaL, laL, CFrame.new(0, -0.6, 0))
		__motor(ulR, "RightHip", lt, ulR, CFrame.new(0.5, -0.2, 0))
		__motor(llR, "RightKnee", ulR, llR, CFrame.new(0, -0.6, 0))
		__motor(ulL, "LeftHip", lt, ulL, CFrame.new(-0.5, -0.2, 0))
		__motor(llL, "LeftKnee", ulL, llL, CFrame.new(0, -0.6, 0))
	end
	ch.PrimaryPart = hrp
	ch.Parent = workspace
	pl.Character = ch
	pl.CharacterAdded:_fire(ch)
	return ch
end

local function __removePlayer(pl)
	__players.PlayerRemoving:_fire(pl)
	for i, p in __players._list do
		if p == pl then
			table.remove(__players._list, i)
			break
		end
	end
	pl.Parent = nil
end

-- DataStoreService --------------------------------------------------------
local function __deepCopy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in v do o[k] = __deepCopy(x) end
	return o
end
local __ds = { stores = {}, failures = 0, calls = 0, log = {} }
local function __dsMaybeFail(what)
	__ds.calls += 1
	if __ds.failures > 0 then
		__ds.failures -= 1
		error("DataStore request was rejected (simulado): " .. what)
	end
end
local __dataStoreService = {
	GetDataStore = function(_, name)
		local data = __ds.stores[name]
		if not data then data = {} __ds.stores[name] = data end
		local store = {}
		function store:GetAsync(key)
			__dsMaybeFail("GetAsync")
			return __deepCopy(data[key])
		end
		function store:SetAsync(key, v)
			__dsMaybeFail("SetAsync")
			data[key] = __deepCopy(v)
		end
		function store:UpdateAsync(key, fn)
			__dsMaybeFail("UpdateAsync")
			local newV = fn(__deepCopy(data[key]))
			if newV == nil then return nil end
			data[key] = __deepCopy(newV)
			table.insert(__ds.log, { key = key })
			return __deepCopy(newV)
		end
		return store
	end,
}

-- MarketplaceService --------------------------------------------------------
local __market = { ProcessReceipt = nil, _prompts = {}, _info = {}, PromptProductPurchaseFinished = makeSignal() }
function __market:PromptProductPurchase(player, productId)
	table.insert(self._prompts, { player = player, productId = productId })
end
function __market:GetProductInfoAsync(id, infoType)
	local i = self._info[id]
	if not i then error("HTTP 400 (simulado): producto " .. tostring(id) .. " no existe") end
	return i
end

-- PhysicsService -------------------------------------------------------------
local __physics = { groups = { Default = true }, collide = {} }
function __physics:RegisterCollisionGroup(n)
	assert(not self.groups[n], "collision group already registered: " .. n)
	self.groups[n] = true
end
function __physics:IsCollisionGroupRegistered(n) return self.groups[n] == true end
function __physics:CollisionGroupSetCollidable(a, b, flag)
	assert(self.groups[a] and self.groups[b], "grupo no registrado: " .. a .. "/" .. b)
	self.collide[a .. "|" .. b] = flag
	self.collide[b .. "|" .. a] = flag
end
function __physics:CollisionGroupsAreCollidable(a, b)
	local v = self.collide[a .. "|" .. b]
	if v == nil then return true end
	return v
end

-- TextChatService ------------------------------------------------------------
local __textChat = newInstance("TextChatService")
rawset(__textChat, "ChatVersion", "TextChatService")
rawset(__textChat, "_canChat", true)
rawset(__textChat, "CanUserChatAsync", function(self, userId)
	return rawget(self, "_canChat")
end)
for _, n in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" } do
	local c = newInstance(n)
	c.Name = n
	c.Parent = __textChat
end

local __proximityService = newInstance("ProximityPromptService")

local __closeFns = {}
local game = {
	CreatorId = 0,
	BindToClose = function(_, fn)
		table.insert(__closeFns, fn)
	end,
	GetService = function(_, name)
		local s = ({
			Workspace = workspace, Lighting = __lighting, RunService = __runService, StarterGui = __starterGui,
			ReplicatedStorage = __replicated, ServerScriptService = __serverScripts, StarterPlayer = __starterPlayer,
			CollectionService = __collection, Players = __players, DataStoreService = __dataStoreService,
			MarketplaceService = __market, PhysicsService = __physics, TextChatService = __textChat,
			ProximityPromptService = __proximityService,
		})[name]
		if s == nil then
			error("GetService('" .. tostring(name) .. "') no soportado en el mock")
		end
		return s
	end,
}

-- modulos: require() y definicion de scripts ------------------------------------
local function require(inst)
	local e = rawget(inst, "_module")
	assert(e, "require: no es un ModuleScript registrado: " .. tostring(inst._props and inst._props.Name))
	if e.loaded then
		assert(not e.loading, "require ciclico: " .. inst._props.Name)
		return e.value
	end
	e.loading = true
	e.value = e.fn(inst)
	e.loading = false
	e.loaded = true
	return e.value
end
local function __defineScript(parent, class, name, fn)
	local m = newInstance(class)
	m.Name = name
	rawset(m, "_module", { fn = fn })
	if parent then m.Parent = parent end
	return m
end
local function __runScript(inst)
	local e = rawget(inst, "_module")
	return e.fn(inst)
end

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
