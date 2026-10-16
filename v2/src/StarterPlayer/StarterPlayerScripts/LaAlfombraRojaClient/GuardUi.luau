--[[
	GUARDUI - dialogo con los guardias y credencial FICTICIA del club.
	La credencial (id AR-XXXXXX) la genera y valida el servidor. NO es un documento, no pide datos
	reales y NO verifica la edad: lo dice el propio dialogo.
]]

local Players = game:GetService("Players")

local Ui = require(script.Parent.Ui)

local GuardUi = {}

local player = Players.LocalPlayer
local social
local gui, widgets = nil, {}
local payload = nil

local function build()
	gui = Ui.screenGui("LaAlfombraRojaGuardia", 26, false)
	local frame = Ui.make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 290), BackgroundColor3 = Ui.BLACK, BackgroundTransparency = 0.04, BorderSizePixel = 0 }, gui)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(460, 290), MinSize = Vector2.new(300, 260) }, frame)
	Ui.corner(frame, 12)
	Ui.make("UIStroke", { Color = Ui.GOLD, Thickness = 1.5 }, frame)
	Ui.label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -100, 0, 26), Font = Enum.Font.Bodoni, Text = "SEGURIDAD · LA ALFOMBRA ROJA", TextColor3 = Ui.GOLD }, frame)
	local close = Ui.button("Close", "Cerrar", frame, UDim2.fromOffset(70, 26), UDim2.new(1, -84, 0, 8))
	close.TextColor3 = Ui.GOLD
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	widgets.line = Ui.label({ Name = "Frase", Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 44), Font = Enum.Font.Gotham, TextScaled = false, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "" }, frame)
	-- tarjeta de credencial
	local card = Ui.make("Frame", { Name = "Credencial", Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 100), BackgroundColor3 = Color3.fromRGB(34, 12, 16), BorderSizePixel = 0 }, frame)
	Ui.corner(card, 8)
	Ui.make("UIStroke", { Color = Ui.GOLD, Thickness = 1 }, card)
	widgets.avatar = Ui.make("ImageLabel", { Name = "Avatar", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Image = "" }, card)
	Ui.corner(widgets.avatar, 6)
	Ui.label({ Position = UDim2.fromOffset(102, 6), Size = UDim2.new(1, -112, 0, 16), Font = Enum.Font.GothamMedium, Text = "CREDENCIAL DEL CLUB (ficticia)", TextColor3 = Ui.GOLD }, card)
	widgets.name = Ui.label({ Position = UDim2.fromOffset(102, 28), Size = UDim2.new(1, -112, 0, 26), Font = Enum.Font.Bodoni, Text = "", TextColor3 = Color3.fromRGB(246, 240, 228) }, card)
	widgets.id = Ui.label({ Position = UDim2.fromOffset(102, 60), Size = UDim2.new(1, -112, 0, 24), Font = Enum.Font.Code, Text = "", TextColor3 = Ui.GOLD }, card)
	widgets.disc = Ui.label({ Name = "Aviso", Position = UDim2.fromOffset(14, 198), Size = UDim2.new(1, -28, 0, 38), Font = Enum.Font.Gotham, TextScaled = false, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", TextColor3 = Ui.MUTED }, frame)
	widgets.present = Ui.button("Presentar", "Presentar credencial", frame, UDim2.new(1, -28, 0, 36), UDim2.new(0, 14, 1, -46))
	widgets.present.BackgroundColor3 = Ui.ON
	widgets.present.Activated:Connect(function()
		if payload then
			social:FireServer("Credential", payload.credential and payload.credential.id or nil)
		end
	end)
end

function GuardUi.open(data)
	payload = data
	if not gui then
		build()
	end
	gui.Enabled = true
	widgets.line.Text = data.hasAccess and "Ya tienes acceso. Pasa cuando quieras." or tostring(data.greeting or "")
	widgets.name.Text = tostring(data.name or player.DisplayName)
	widgets.id.Text = data.credential and tostring(data.credential.id) or "—"
	widgets.disc.Text = tostring(data.disclaimer or "")
	widgets.present.Visible = not data.hasAccess
	task.spawn(function()
		local ok, img = pcall(function()
			return (Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100))
		end)
		if ok and widgets.avatar then
			widgets.avatar.Image = img
		end
	end)
end

function GuardUi.init(deps)
	social = deps.remotes.Social
	deps.remotes.SocialNotice.OnClientEvent:Connect(function(kind, a, b)
		if kind == "OpenGuard" and type(a) == "table" then
			GuardUi.open(a)
		elseif kind == "GuardResult" then
			Ui.toast(b)
			if a == true and gui then
				gui.Enabled = false
			elseif gui and gui.Enabled and widgets.line then
				widgets.line.Text = tostring(b or "")
			end
		end
	end)
end

return GuardUi
