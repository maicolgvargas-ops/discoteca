--[[
	UI - ayudas comunes de interfaz: colores del club, creacion de instancias, avisos (toast).
	Todos los botones usan `Activated` (sirve para raton, tactil y mando).
]]

local Players = game:GetService("Players")

local Ui = {}

Ui.GOLD = Color3.fromRGB(232, 188, 98)
Ui.BLACK = Color3.fromRGB(14, 14, 16)
Ui.PANEL = Color3.fromRGB(24, 24, 28)
Ui.ON = Color3.fromRGB(150, 112, 40)
Ui.TEXT = Color3.fromRGB(235, 235, 240)
Ui.MUTED = Color3.fromRGB(160, 160, 168)
Ui.RED = Color3.fromRGB(214, 40, 52)

local player = Players.LocalPlayer
local toastGui, toastLabel, toastUntil = nil, nil, 0

function Ui.make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

function Ui.corner(parent, r)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

function Ui.button(name, text, parent, size, pos)
	local b = Ui.make("TextButton", { Name = name, Size = size, Position = pos or UDim2.new(), BackgroundColor3 = Ui.PANEL, Font = Enum.Font.GothamMedium, Text = text, TextScaled = true, TextColor3 = Ui.TEXT, AutoButtonColor = true }, parent)
	Ui.corner(b, 8)
	return b
end

function Ui.label(props, parent)
	local p = { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextScaled = true, TextColor3 = Ui.TEXT, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in props do
		p[k] = v
	end
	return Ui.make("TextLabel", p, parent)
end

function Ui.paint(b, on)
	b.BackgroundColor3 = on and Ui.ON or Ui.PANEL
	b.TextColor3 = on and Color3.fromRGB(255, 244, 214) or Ui.TEXT
end

function Ui.screenGui(name, order, enabled)
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return Ui.make("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = order or 20, Enabled = enabled ~= false }, pg)
end

function Ui.toast(text)
	if type(text) ~= "string" or text == "" then
		return
	end
	if not toastLabel then
		toastGui = Ui.screenGui("LaAlfombraRojaAviso", 40, true)
		toastLabel = Ui.make("TextLabel", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(460, 38), BackgroundColor3 = Ui.BLACK, BackgroundTransparency = 0.12, Font = Enum.Font.GothamMedium, Text = "", TextScaled = true, TextColor3 = Ui.GOLD, Visible = false }, toastGui)
		Ui.corner(toastLabel, 8)
	end
	toastLabel.Text = text
	toastLabel.Visible = true
	toastUntil = os.clock() + 4
end

-- se llama a baja frecuencia desde el bucle principal
function Ui.tick()
	if toastLabel and toastLabel.Visible and os.clock() > toastUntil then
		toastLabel.Visible = false
	end
end

return Ui
