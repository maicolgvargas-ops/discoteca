--[[
	CATALOGO DE BEBIDAS Y PRODUCTOS (modulo compartido servidor/cliente).

	* Las bebidas son OBJETOS VIRTUALES cosmeticos: no afectan a estadisticas, no hay azar.
	* Las botellas y copas son geometria ORIGINAL hecha por codigo (DrinkModels.luau) con el nombre
	  escrito como texto. No se usa ningun logo ni asset externo.
	* Los nombres de marcas conocidas (Don Julio 1942, Clase Azul, Patrón, Moët, Veuve Clicquot, Dom
	  Pérignon) los ha pedido el titular del proyecto como texto de ejemplo. Son marcas registradas
	  de terceros: revisa permisos y politicas de Roblox antes de publicar, o pon UseGenericNames = true
	  (o cambia los Name) para usar nombres genericos.

	COMO CAMBIAR EL CATALOGO: edita/añade filas en Items (Id unico, Tier "bottle" o "shot", Kind = tipo
	de modelo de DrinkModels) y, si quieres otros precios o productos, en Products.

	ROBUX: ver Products. ProductId = 0 significa "sin enlazar": esa compra queda DESACTIVADA. El
	precio mostrado al jugador es el real que devuelve MarketplaceService:GetProductInfoAsync; las cifras
	DraftRobux son un BORRADOR interno (400 botella / 50 shot) y no se muestran como precio real.
]]

local Catalog = {}

Catalog.UseGenericNames = false

Catalog.Categories = { "Champaña", "Tequila", "Whisky", "Shots" }

-- Tiers: cuantos "sorbos" tiene cada unidad. Los vales (vouchers) se canjean por articulos del mismo tier.
Catalog.Tiers = {
	bottle = { Label = "Botella", Servings = 5 },
	shot = { Label = "Copa / shot", Servings = 1 },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Style: colores de cristal, liquido, etiqueta, texto de etiqueta, capsula/tapon y acento.
Catalog.Items = {
	{
		Id = "champana_moet", Category = "Champaña", Tier = "bottle", Kind = "champagne",
		Name = "Moët & Chandon Impérial", GenericName = "Champán Imperial",
		Label = { "MOËT & CHANDON", "IMPÉRIAL", "BRUT" },
		Description = "Champán brut en botella verde oscura con capsula dorada.",
		Style = { glass = rgb(30, 58, 38), liquid = rgb(232, 206, 120), label = rgb(240, 236, 224), text = rgb(30, 30, 34), foil = rgb(205, 165, 72), accent = rgb(205, 165, 72) },
	},
	{
		Id = "champana_veuve", Category = "Champaña", Tier = "bottle", Kind = "champagne",
		Name = "Veuve Clicquot Brut", GenericName = "Champán Brut Etiqueta Amarilla",
		Label = { "VEUVE CLICQUOT", "BRUT" },
		Description = "Champán brut con etiqueta amarilla anaranjada.",
		Style = { glass = rgb(34, 54, 36), liquid = rgb(232, 206, 120), label = rgb(240, 176, 24), text = rgb(40, 28, 10), foil = rgb(240, 176, 24), accent = rgb(240, 176, 24) },
	},
	{
		Id = "champana_dom", Category = "Champaña", Tier = "bottle", Kind = "champagne",
		Name = "Dom Pérignon Vintage", GenericName = "Champán Vintage",
		Label = { "DOM PÉRIGNON", "VINTAGE" },
		Description = "Champán de añada en botella casi negra con etiqueta sobria.",
		Style = { glass = rgb(16, 24, 20), liquid = rgb(232, 206, 120), label = rgb(236, 230, 214), text = rgb(24, 24, 28), foil = rgb(26, 26, 30), accent = rgb(205, 165, 72) },
	},
	{
		Id = "tequila_donjulio", Category = "Tequila", Tier = "bottle", Kind = "flask",
		Name = "Don Julio 1942", GenericName = "Tequila Añejo 1942",
		Label = { "DON JULIO", "1942", "AÑEJO" },
		Description = "Tequila añejo en botella achaparrada de hombros planos y tapon de corcho.",
		Style = { glass = rgb(214, 226, 222), liquid = rgb(208, 142, 58), label = rgb(236, 224, 196), text = rgb(60, 36, 16), foil = rgb(196, 150, 66), accent = rgb(196, 150, 66) },
	},
	{
		Id = "tequila_claseazul", Category = "Tequila", Tier = "bottle", Kind = "round",
		Name = "Clase Azul Reposado", GenericName = "Tequila Reposado Azul",
		Label = { "CLASE AZUL", "REPOSADO" },
		Description = "Tequila reposado en botella redondeada blanca con bandas azules y tapon alto.",
		Style = { glass = rgb(238, 240, 246), liquid = rgb(214, 160, 76), label = rgb(34, 74, 170), text = rgb(244, 244, 250), foil = rgb(206, 208, 214), accent = rgb(34, 74, 170) },
	},
	{
		Id = "tequila_patron", Category = "Tequila", Tier = "bottle", Kind = "square",
		Name = "Patrón Silver", GenericName = "Tequila Silver",
		Label = { "PATRÓN", "SILVER" },
		Description = "Tequila blanco en botella cuadrada de cristal transparente con corcho.",
		Style = { glass = rgb(206, 224, 222), liquid = rgb(222, 236, 232), label = rgb(244, 244, 240), text = rgb(24, 70, 40), foil = rgb(120, 82, 46), accent = rgb(24, 70, 40) },
	},
	{
		Id = "whisky_reserva", Category = "Whisky", Tier = "bottle", Kind = "whisky",
		Name = "Whisky Reserva 12", GenericName = "Whisky Reserva 12",
		Label = { "WHISKY", "RESERVA", "12 AÑOS" },
		Description = "Whisky ambar de la casa en botella alta con tapon de corcho.",
		Style = { glass = rgb(210, 220, 214), liquid = rgb(196, 112, 28), label = rgb(232, 220, 190), text = rgb(48, 28, 12), foil = rgb(86, 56, 30), accent = rgb(176, 126, 52) },
	},
	{
		Id = "whisky_malta", Category = "Whisky", Tier = "bottle", Kind = "whisky",
		Name = "Single Malt 18", GenericName = "Single Malt 18",
		Label = { "SINGLE MALT", "18 AÑOS" },
		Description = "Whisky de malta añejo, ambar oscuro, etiqueta negra y dorada.",
		Style = { glass = rgb(200, 210, 204), liquid = rgb(150, 76, 20), label = rgb(24, 24, 28), text = rgb(222, 178, 90), foil = rgb(20, 20, 22), accent = rgb(222, 178, 90) },
	},
	{
		Id = "shot_tequila", Category = "Shots", Tier = "shot", Kind = "shot",
		Name = "Shot de tequila con lima", GenericName = "Shot de tequila con lima",
		Label = { "TEQUILA" },
		Description = "Chupito de tequila con una cuña de lima en el borde.",
		Style = { glass = rgb(214, 228, 232), liquid = rgb(236, 220, 150), label = rgb(236, 224, 196), text = rgb(40, 40, 40), foil = rgb(90, 160, 40), accent = rgb(90, 160, 40) },
	},
	{
		Id = "copa_champana", Category = "Shots", Tier = "shot", Kind = "flute",
		Name = "Copa de champaña", GenericName = "Copa de champán",
		Label = { "CHAMPAÑA" },
		Description = "Copa alta con champán y burbujas.",
		Style = { glass = rgb(214, 228, 240), liquid = rgb(236, 214, 130), label = rgb(236, 224, 196), text = rgb(40, 40, 40), foil = rgb(205, 165, 72), accent = rgb(205, 165, 72) },
	},
	{
		Id = "whisky_hielo", Category = "Shots", Tier = "shot", Kind = "tumbler",
		Name = "Whisky con hielo", GenericName = "Whisky con hielo",
		Label = { "WHISKY" },
		Description = "Vaso corto con whisky y dos cubos de hielo.",
		Style = { glass = rgb(214, 228, 240), liquid = rgb(196, 112, 28), label = rgb(236, 224, 196), text = rgb(40, 40, 40), foil = rgb(205, 165, 72), accent = rgb(205, 165, 72) },
	},
}

-- PRODUCTOS DE ROBUX (Developer Products). Una compra concede VALES; el jugador los canjea por el
-- articulo que quiera de ese tier. Se puede repetir sin limite.
--   ProductId = 0  -> sin enlazar: la compra con Robux de este producto esta DESACTIVADA.
--   DraftRobux     -> BORRADOR (no es un precio real; no se muestra como tal). El precio real se
--                     fija en el panel de Creator Hub al crear el producto.
-- Para enlazar: crea el Developer Product en Creator Hub, copia su ID aqui. Para productos futuros
-- (otro tipo de compra) añade una fila con Grant y, si hace falta, registra un manejador propio con
-- Purchases.registerHandler(productId, fn).
Catalog.Products = {
	{ Key = "vale_botella", ProductId = 0, Title = "Vale de botella", DraftRobux = 400, Grant = { vouchers = { bottle = 1 } } },
	{ Key = "vale_shot", ProductId = 0, Title = "Vale de shot / copa", DraftRobux = 50, Grant = { vouchers = { shot = 1 } } },
}

local itemById = {}
for _, item in Catalog.Items do
	itemById[item.Id] = item
end

function Catalog.getItem(id)
	if type(id) ~= "string" then
		return nil
	end
	return itemById[id]
end

function Catalog.displayName(item)
	if Catalog.UseGenericNames and item.GenericName then
		return item.GenericName
	end
	return item.Name
end

function Catalog.itemsByCategory(cat)
	local out = {}
	for _, item in Catalog.Items do
		if item.Category == cat then
			table.insert(out, item)
		end
	end
	return out
end

function Catalog.servings(item)
	return Catalog.Tiers[item.Tier].Servings
end

-- producto que concede un unico vale del tier (el que se ofrece al comprar un articulo de ese tier)
function Catalog.productForTier(tier)
	for _, p in Catalog.Products do
		local v = p.Grant and p.Grant.vouchers
		if v and v[tier] == 1 then
			local only = true
			for k in v do
				if k ~= tier then
					only = false
				end
			end
			if only and not p.Grant.items then
				return p
			end
		end
	end
	return nil
end

function Catalog.productById(productId)
	if type(productId) ~= "number" or productId == 0 then
		return nil
	end
	for _, p in Catalog.Products do
		if p.ProductId == productId then
			return p
		end
	end
	return nil
end

-- comprueba el catalogo: devuelve una lista de problemas (vacia = correcto)
function Catalog.validate()
	local problems = {}
	local seen = {}
	for _, item in Catalog.Items do
		if type(item.Id) ~= "string" or item.Id == "" then
			table.insert(problems, "articulo sin Id")
		elseif seen[item.Id] then
			table.insert(problems, "Id repetido: " .. item.Id)
		end
		seen[item.Id] = true
		if not Catalog.Tiers[item.Tier] then
			table.insert(problems, item.Id .. ": tier desconocido " .. tostring(item.Tier))
		end
		if not table.find(Catalog.Categories, item.Category) then
			table.insert(problems, item.Id .. ": categoria desconocida " .. tostring(item.Category))
		end
		if type(item.Name) ~= "string" or item.Name == "" then
			table.insert(problems, item.Id .. ": sin Name")
		end
		if type(item.Label) ~= "table" or #item.Label == 0 then
			table.insert(problems, item.Id .. ": sin Label (texto de la etiqueta)")
		end
	end
	local ids = {}
	for _, p in Catalog.Products do
		if type(p.ProductId) ~= "number" or p.ProductId < 0 then
			table.insert(problems, p.Key .. ": ProductId invalido")
		elseif p.ProductId ~= 0 then
			if ids[p.ProductId] then
				table.insert(problems, "ProductId repetido: " .. p.ProductId)
			end
			ids[p.ProductId] = true
		end
		for tier in (p.Grant and p.Grant.vouchers) or {} do
			if not Catalog.Tiers[tier] then
				table.insert(problems, p.Key .. ": concede un tier desconocido " .. tostring(tier))
			end
		end
		for id in (p.Grant and p.Grant.items) or {} do
			if not itemById[id] then
				table.insert(problems, p.Key .. ": concede un articulo desconocido " .. tostring(id))
			end
		end
	end
	for tier in Catalog.Tiers do
		if not Catalog.productForTier(tier) then
			table.insert(problems, "no hay producto de 1 vale para el tier " .. tier)
		end
	end
	return problems
end

return Catalog
