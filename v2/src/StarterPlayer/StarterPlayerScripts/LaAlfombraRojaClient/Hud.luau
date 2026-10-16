--[[
	HUD - botones discretos en pantalla: Mochila, Bailar y Levantarse (solo sentado).
	Todos usan `Activated`.
]]

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer
local gui, bar, standBtn
local callbacks = {}

local function humanoid()
	local ch = player.Character
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

function Hud.init(cb)
	callbacks = cb
	gui = Ui.screenGui("LaAlfombraRojaHud", 15, true)
	bar = Ui.make("Frame", { Name = "Barra", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14), Size = UDim2.fromOffset(330, 40), BackgroundTransparency = 1 }, gui)
	Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }, bar)
	local function add(name, text, order, fn)
		local b = Ui.button(name, text, bar, UDim2.fromOffset(100, 38))
		b.LayoutOrder = order
		b.TextColor3 = Ui.GOLD
		b.BackgroundTransparency = 0.1
		b.Activated:Connect(fn)
		return b
	end
	standBtn = add("Levantarse", "Levantarse", 1, function()
		-- pide salir al servidor (que valida que es TU asiento); ademas Jump, que es el camino normal del motor
		if callbacks.stand then
			callbacks.stand()
		else
			local h = humanoid()
			if h and h.Sit then
				h.Jump = true
			end
		end
	end)
	standBtn.Visible = false
	add("Bailar", "Bailar", 2, function()
		if callbacks.dance then
			callbacks.dance()
		end
	end)
	add("Mochila", "Mochila", 3, function()
		if callbacks.backpack then
			callbacks.backpack()
		end
	end)
end

-- se llama a baja frecuencia
function Hud.tick()
	if not standBtn then
		return
	end
	local h = humanoid()
	standBtn.Visible = h ~= nil and (h.Sit == true or h.SeatPart ~= nil)
end

return Hud
