--[[
	SHOPUI - carta de bebidas (categorias, vista previa 3D, cantidad, comprar/canjear) y mochila
	(equipar/guardar). El cliente SOLO pide acciones; el servidor valida todo (cercania, cantidades,
	vales, ProductIds) y es quien concede. El precio mostrado es el REAL de MarketplaceService; si el
	producto no esta enlazado (ProductId = 0) se muestra "Precio pendiente" (nunca el borrador).
]]

local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)
local Shared = ReplicatedStorage:WaitForChild("AlfombraShared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local DrinkModels = require(Shared:WaitForChild("DrinkModels"))

local ShopUi = {}

local make, button, paint = Ui.make, Ui.button, Ui.paint
local GOLD = Ui.GOLD

local remote
local snap = { loaded = false, items = {}, vouchers = {}, open = {}, equipped = "" }
local gui, widgets = nil, {}
local sel = { tab = "carta", category = Catalog.Categories[1], item = nil, qty = 1 }
local priceCache = {} -- [productId] = number | false (consultado)
local preview = { vp = nil, model = nil, cam = nil, yaw = 0.6, pitch = 0.15, dist = 4, center = Vector3.new(0, 0, 0), drag = false }
local lastSend = 0

local function send(action, a, b)
	local now = os.clock()
	if now - lastSend < 0.15 then
		return
	end
	lastSend = now
	remote:FireServer(action, a, b)
end

local function studioTest()
	local ok, studio = pcall(function()
		return RunService:IsStudio()
	end)
	return Config.Purchases.StudioTestMode == true and ok and studio == true
end

-- precio real (Robux) de un Developer Product: nil si no esta enlazado o aun no se sabe
local function realPrice(product)
	if not product or product.ProductId == 0 then
		return nil
	end
	local c = priceCache[product.ProductId]
	if c == nil then
		priceCache[product.ProductId] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(product.ProductId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				priceCache[product.ProductId] = info.PriceInRobux
				task.defer(function()
					if widgets.refresh then
						widgets.refresh()
					end
				end)
			end
		end)
		return nil
	end
	return c or nil
end

------------------------------------------------------------------------
-- vista previa 3D (ViewportFrame; solo geometria: las etiquetas se leen debajo)
------------------------------------------------------------------------
local function updateCamera()
	if not preview.cam then
		return
	end
	local rot = CFrame.Angles(0, preview.yaw, 0) * CFrame.Angles(preview.pitch, 0, 0)
	local pos = preview.center + rot * Vector3.new(0, 0, preview.dist)
	preview.cam.CFrame = CFrame.lookAt(pos, preview.center)
end

local function showPreview(item)
	if not preview.vp then
		return
	end
	if preview.model then
		preview.model:Destroy()
		preview.model = nil
	end
	if not item then
		return
	end
	local ok, model = pcall(function()
		return (DrinkModels.build(item, { parent = preview.vp, anchored = true }))
	end)
	if not ok or not model then
		return
	end
	preview.model = model
	local h = model:GetAttribute("Height") or 2
	preview.center = Vector3.new(0, h / 2, 0)
	preview.dist = math.max(3, h * 1.7)
	updateCamera()
end

------------------------------------------------------------------------
-- construccion
------------------------------------------------------------------------
local function owned(id)
	return snap.items[id] or 0
end

local function tierName(item)
	return Catalog.Tiers[item.Tier].Label
end

local function buildGui()
	gui = Ui.screenGui("LaAlfombraRojaTienda", 25, false)
	local frame = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 720, 0, 440), BackgroundColor3 = Ui.BLACK, BackgroundTransparency = 0.04, BorderSizePixel = 0 }, gui)
	make("UISizeConstraint", { MaxSize = Vector2.new(720, 440), MinSize = Vector2.new(320, 300) }, frame)
	Ui.corner(frame, 12)
	make("UIStroke", { Color = GOLD, Thickness = 1.5 }, frame)
	Ui.label({ Name = "Title", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(0.5, 0, 0, 28), Font = Enum.Font.Bodoni, Text = "CARTA DE LA BARRA", TextColor3 = GOLD }, frame)
	local close = button("Close", "Cerrar", frame, UDim2.fromOffset(70, 28), UDim2.new(1, -84, 0, 8))
	close.TextColor3 = GOLD
	close.Activated:Connect(function()
		ShopUi.close()
	end)
	local banner = Ui.label({ Name = "Banner", Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 16), Font = Enum.Font.Gotham, Text = "", TextColor3 = Color3.fromRGB(240, 170, 110) }, frame)
	local tabs = make("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 28) }, frame)
	local tabButtons = {}
	for i, t in { { "carta", "Carta" }, { "mochila", "Mochila" } } do
		local b = button("Tab_" .. t[1], t[2], tabs, UDim2.new(0, 110, 1, 0), UDim2.new(0, (i - 1) * 116, 0, 0))
		tabButtons[t[1]] = b
		b.Activated:Connect(function()
			sel.tab = t[1]
			widgets.refresh()
		end)
	end
	local vouchersL = Ui.label({ Name = "Vales", Position = UDim2.new(0, 240, 0, 0), Size = UDim2.new(1, -240, 1, 0), Text = "", TextColor3 = Ui.MUTED, TextXAlignment = Enum.TextXAlignment.Right }, tabs)

	-- categorias (solo carta)
	local cats = make("Frame", { Name = "Categorias", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 92), Size = UDim2.new(0, 150, 1, -104) }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 4) }, cats)
	local catButtons = {}
	for _, c in Catalog.Categories do
		local b = button("Cat_" .. c, c, cats, UDim2.new(1, 0, 0, 30))
		catButtons[c] = b
		b.Activated:Connect(function()
			sel.category = c
			sel.item = nil
			sel.qty = 1
			widgets.refresh()
		end)
	end

	-- lista de articulos
	local list = make("ScrollingFrame", { Name = "Lista", BackgroundTransparency = 1, Position = UDim2.fromOffset(172, 92), Size = UDim2.new(0, 230, 1, -104), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, BorderSizePixel = 0 }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	-- detalle
	local detail = make("Frame", { Name = "Detalle", BackgroundTransparency = 1, Position = UDim2.fromOffset(410, 92), Size = UDim2.new(1, -424, 1, -104) }, frame)
	local vp = make("ViewportFrame", { Name = "Vista3D", Size = UDim2.new(1, 0, 0, 170), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Ambient = Color3.fromRGB(150, 150, 150), LightColor = Color3.fromRGB(255, 240, 220) }, detail)
	Ui.corner(vp, 8)
	local cam = make("Camera", { FieldOfView = 35 }, vp)
	vp.CurrentCamera = cam
	preview.vp, preview.cam = vp, cam
	vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			preview.drag = true
		end
	end)
	vp.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			preview.drag = false
		end
	end)
	vp.InputChanged:Connect(function(input)
		if preview.drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			preview.yaw -= input.Delta.X * 0.012
			preview.pitch = math.clamp(preview.pitch + input.Delta.Y * 0.008, -0.6, 0.9)
			updateCamera()
		end
	end)
	local nameL = Ui.label({ Name = "Nombre", Position = UDim2.fromOffset(0, 174), Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.Bodoni, Text = "", TextColor3 = GOLD }, detail)
	local descL = Ui.label({ Name = "Descripcion", Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 42), Font = Enum.Font.Gotham, TextScaled = false, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", TextColor3 = Ui.MUTED }, detail)
	local priceL = Ui.label({ Name = "Precio", Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = Color3.fromRGB(225, 225, 230) }, detail)
	local qtyRow = make("Frame", { Name = "Cantidad", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 0, 28) }, detail)
	Ui.label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = "Cantidad" }, qtyRow)
	local minus = button("Minus", "-", qtyRow, UDim2.fromOffset(30, 26), UDim2.new(0.42, 0, 0, 1))
	local qtyL = Ui.label({ Position = UDim2.new(0.42, 34, 0, 0), Size = UDim2.fromOffset(34, 28), Text = "1", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center }, qtyRow)
	local plus = button("Plus", "+", qtyRow, UDim2.fromOffset(30, 26), UDim2.new(0.42, 72, 0, 1))
	minus.Activated:Connect(function()
		sel.qty = math.max(1, sel.qty - 1)
		widgets.refresh()
	end)
	plus.Activated:Connect(function()
		sel.qty = math.min(Config.Shop.MaxQty, sel.qty + 1)
		widgets.refresh()
	end)
	local buy = button("Comprar", "Comprar", detail, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 296))
	buy.BackgroundColor3 = Ui.ON
	buy.Activated:Connect(function()
		if sel.item and sel.tab == "carta" then
			send("Buy", sel.item, sel.qty)
		end
	end)
	local equip = button("Equipar", "Equipar", detail, UDim2.new(0.5, -3, 0, 34), UDim2.new(0, 0, 0, 296))
	local stow = button("Guardar", "Guardar", detail, UDim2.new(0.5, -3, 0, 34), UDim2.new(0.5, 3, 0, 296))
	equip.Activated:Connect(function()
		if sel.item then
			send("Equip", sel.item)
		end
	end)
	stow.Activated:Connect(function()
		send("Stow")
	end)
	local hint = Ui.label({ Name = "Aviso", Position = UDim2.fromOffset(0, 334), Size = UDim2.new(1, 0, 1, -334), Font = Enum.Font.Gotham, TextScaled = false, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "Bebidas virtuales: son objetos cosméticos del juego (no hay azar ni ventajas).", TextColor3 = Ui.MUTED }, detail)

	local rows = {}
	local function buildRows(items)
		for _, r in rows do
			r:Destroy()
		end
		rows = {}
		for i, item in items do
			local n = owned(item.Id)
			local text = Catalog.displayName(item)
			if sel.tab == "mochila" then
				local open = snap.open[item.Id]
				text = string.format("%s  ×%d%s", text, n, (open and open > 0) and string.format("  (%d sorbos)", open) or "")
			elseif n > 0 then
				text = string.format("%s  (tienes %d)", text, n)
			end
			local b = button("Item_" .. item.Id, text, list, UDim2.new(1, -6, 0, 32))
			b.LayoutOrder = i
			b.TextXAlignment = Enum.TextXAlignment.Left
			paint(b, sel.item == item.Id)
			b.Activated:Connect(function()
				sel.item = item.Id
				sel.qty = 1
				widgets.refresh()
			end)
			table.insert(rows, b)
		end
	end

	widgets.refresh = function()
		if not gui or not gui.Enabled then
			return
		end
		local isShop = sel.tab == "carta"
		for k, b in tabButtons do
			paint(b, k == sel.tab)
		end
		for c, b in catButtons do
			b.Visible = isShop
			paint(b, c == sel.category)
		end
		if snap.temporary then
			banner.Text = "MODO STUDIO TEMPORAL: el inventario NO se guarda" .. (studioTest() and " · compras GRATIS (sin Robux)." or " · compras con Robux desactivadas.")
		elseif snap.persistence == "none" or snap.unavailable then
			banner.Text = "SIN PERSISTENCIA: inventario y compras con Robux bloqueados en este servidor."
		else
			banner.Text = studioTest() and "MODO DE PRUEBA EN STUDIO: las compras son GRATIS y no usan Robux." or ""
		end
		local vb, vs = snap.vouchers.bottle or 0, snap.vouchers.shot or 0
		vouchersL.Text = string.format("Vales: %d botella · %d shot", vb, vs)
		local items = {}
		if isShop then
			items = Catalog.itemsByCategory(sel.category)
		else
			for _, it in Catalog.Items do
				if owned(it.Id) > 0 or (snap.open[it.Id] or 0) > 0 then
					table.insert(items, it)
				end
			end
		end
		local keep = false
		for _, it in items do
			if it.Id == sel.item then
				keep = true
			end
		end
		if not keep then
			sel.item = items[1] and items[1].Id or nil
		end
		buildRows(items)
		local item = Catalog.getItem(sel.item)
		if preview.model == nil or preview.model:GetAttribute("ItemId") ~= (item and item.Id) then
			showPreview(item)
		end
		buy.Visible = isShop
		qtyRow.Visible = isShop
		priceL.Visible = isShop
		equip.Visible = not isShop
		stow.Visible = not isShop
		if not item then
			nameL.Text = isShop and "" or "Tu mochila está vacía"
			descL.Text = isShop and "" or "Pide algo en la barra y aparecerá aquí."
			return
		end
		nameL.Text = Catalog.displayName(item)
		local lines = table.concat(item.Label, " · ")
		descL.Text = (item.Description or "") .. "\nEtiqueta: " .. lines
		qtyL.Text = tostring(sel.qty)
		if isShop then
			local tier = item.Tier
			local have = snap.vouchers[tier] or 0
			local product = Catalog.productForTier(tier)
			local missing = math.max(0, sel.qty - have)
			if not snap.loaded then
				buy.Text = snap.blocked and "Inventario en uso en otro servidor" or (snap.lost and "Reconectando inventario…" or ((snap.unavailable or snap.persistence == "none") and "Inventario no disponible" or "Cargando inventario…"))
				priceL.Text = snap.blocked and "Tu inventario se está cerrando en otro servidor: reintentando solo." or ((snap.unavailable or snap.persistence == "none") and "El servidor no tiene DataStore (place sin publicar o sin acceso a la API)." or "")
			elseif have >= sel.qty then
				buy.Text = string.format("Canjear %d vale(s) de %s", sel.qty, string.lower(tierName(item)))
				priceL.Text = string.format("Tienes %d vale(s): no se gastan Robux.", have)
			elseif studioTest() then
				buy.Text = "Probar gratis (Studio)"
				priceL.Text = "Gratis en modo de prueba."
			elseif product and product.ProductId ~= 0 then
				local p = realPrice(product)
				buy.Text = string.format("Comprar con Robux (%d)", missing)
				priceL.Text = p and string.format("%s: %d R$ cada una · %d por comprar", tierName(item), p, missing) or "Consultando precio…"
			else
				buy.Text = "Compra con Robux no disponible"
				priceL.Text = "Precio pendiente (producto sin enlazar)."
			end
		else
			local n, open = owned(item.Id), snap.open[item.Id] or 0
			nameL.Text = string.format("%s  ×%d", Catalog.displayName(item), n)
			equip.Text = (snap.equipped == item.Id) and "Equipada" or "Equipar"
			paint(equip, snap.equipped == item.Id)
			stow.Visible = snap.equipped ~= ""
			priceL.Text = ""
			hint.Text = open > 0 and string.format("Botella abierta: %d sorbos restantes.", open) or "Bebidas virtuales: son objetos cosméticos del juego (no hay azar ni ventajas)."
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
function ShopUi.open(tab)
	if not gui then
		buildGui()
	end
	if tab then
		sel.tab = tab
	end
	gui.Enabled = true
	widgets.refresh()
	if remote then
		remote:FireServer("State")
	end
end

function ShopUi.close()
	if gui then
		gui.Enabled = false
	end
	remote:FireServer("Cancel")
end

function ShopUi.isOpen()
	return gui ~= nil and gui.Enabled
end

function ShopUi.state()
	return snap
end

function ShopUi.init(deps)
	remote = deps.remotes.Shop
	deps.remotes.ShopNotice.OnClientEvent:Connect(function(kind, a, b)
		if kind == "State" and type(a) == "table" then
			snap = a
			if widgets.refresh then
				widgets.refresh()
			end
		elseif kind == "OpenShop" then
			ShopUi.open("carta")
		elseif kind == "Toast" then
			Ui.toast(a)
		elseif kind == "Sip" then
			local item = Catalog.getItem(a)
			if item then
				Ui.toast(b and ("Has terminado: " .. Catalog.displayName(item)) or ("Salud · " .. Catalog.displayName(item)))
			end
		end
	end)
	remote:FireServer("State")
end

return ShopUi
