--[[
	LA ALFOMBRA ROJA v2 - CONFIGURACION (modulo compartido servidor/cliente).

	Todo lo que puedes tocar sin leer el resto del codigo esta aqui. El catalogo de bebidas y los
	ProductIds estan en Catalog.luau. Nada de lo secreto o de seguridad se lee del cliente: el
	servidor valida siempre contra estas tablas.
]]

local Config = {
	Name = "LaAlfombraRoja",
	Version = "2.0.0",

	-- PERFIL GRAFICO: "Equilibrado" (por defecto, prioriza fluidez) o "Alta". Solo cambia lo que se
	-- construye y cuanto trabajo hacen las animaciones locales: NO toca la calidad grafica del jugador
	-- ni UserGameSettings/RenderSettings.
	Quality = "Equilibrado",
	TileCount = 0, -- 0 = segun el perfil (12 en Equilibrado, 16 en Alta)
	LowPerformance = false,
	Boundary = true, -- barrera invisible sobre el muro perimetral
	RemoveTemplateObjects = true, -- borra Baseplate/SpawnLocation de la plantilla

	-- OPCIONAL. Imagen del logo YA SUBIDA a tu cuenta ("rbxassetid://123", "123" o 123). Vacio = logo
	-- hecho con piezas y texto. Nunca se inventa un ID.
	LogoImageId = "",

	-- AJUSTES DE LUCES Y RENDER
	Look = {
		LightIntensity = 1.0,
		AmbientBoost = 1.0,
		Exposure = 0.5,
		Bloom = { Intensity = 0.3, Size = 18, Threshold = 1.0 },
		BeamTransparency = 0.0,
		BeamBrightness = 1.0,
		BeamWidth = 1.0,
		ShaftTransparency = 0.0,
		TileBrightness = 0.7,
		KeyShadows = true,
		Reflections = 1.0,
		ShadowSoftness = 0.35,
	},

	-- CABINA (luces + musica): UN solo operador a la vez. Access: "Todos" | "Lista" | "Dueno".
	-- "Dueno" = el creador del lugar (en Studio se permite siempre para poder probar).
	Control = {
		Enabled = true,
		Access = "Todos",
		UserIds = {}, -- con "Lista": { 123456, 789012 }
		GroupId = 0, -- 0 = sin grupo; si no, MinRank = rango minimo
		MinRank = 1,
		Range = 14, -- studs para tomar el control (se mantiene hasta 3x)
		IdleTimeout = 180,
		MaxRequestsPerSecond = 8,
	},

	-- MUSICA. Solo se reproducen las pistas de esta lista (lista blanca). Un cliente NUNCA puede
	-- mandar un assetId. Vacia por defecto: no hay ningun audio inventado. Para anadir uno:
	--   { Id = "rbxassetid://TU_ID", Title = "Titulo", Artist = "Artista" }
	-- El audio debe ser tuyo o tener permiso de uso en tu experiencia (los audios de terceros pueden
	-- no sonar si no los has subido tu o no son de la libreria publica).
	Music = {
		Enabled = true,
		Tracks = {},
		Volume = 0.5, -- volumen inicial 0..1 (se multiplica por MaxVolume)
		MaxVolume = 4, -- Sound.Volume al 100 % (Roblox admite hasta 10)
		VolumeStep = 0.1,
		Autoplay = false, -- true: empieza sola la primera pista al arrancar (si hay pistas)
		AutoNext = true, -- al terminar una pista pasa a la siguiente
		RollOffMin = 20,
		RollOffMax = 160,
	},

	-- TIENDA / INVENTARIO
	Shop = {
		Enabled = true,
		Range = 30, -- studs maximos desde un punto de venta (bartender / barra) para comprar o canjear
		MaxQty = 10, -- cantidad maxima por operacion
		MaxRequestsPerSecond = 6,
	},
	Data = {
		StoreName = "AlfombraRoja_Inventory_v2",
		AutosaveSeconds = 60,
		Retries = 4,
		MaxReceipts = 300, -- PurchaseIds recordados por jugador
	},

	-- COMPRAS CON ROBUX (Developer Products). Los ProductIds estan en Catalog.luau y valen 0 por
	-- defecto: con 0 NO se puede comprar nada con Robux. El precio que se muestra es el real que
	-- devuelve MarketplaceService; los precios del catalogo son BORRADOR y nunca se enseñan como reales.
	Purchases = {
		-- MODO DE PRUEBA EN STUDIO: concede los articulos GRATIS, sin Robux. Solo funciona si
		-- RunService:IsStudio() es verdadero (aunque lo dejes en true en produccion NO hace nada).
		StudioTestMode = false,
		PromptTimeout = 120, -- segundos que se recuerda una seleccion pendiente
	},

	-- SEGURIDAD DE LA ENTRADA. La "credencial" es un carnet FICTICIO del club (no es un documento,
	-- no pide datos reales y NO verifica la edad: la edad y la clasificacion las gestiona Roblox).
	Guards = {
		Enabled = true,
		BlockedUserIds = {}, -- jugadores a los que la seguridad no deja pasar
		SpawnOutside = true, -- con guardias, el spawn queda en la acera, delante de la puerta
		Range = 14,
		MaxRequestsPerSecond = 3,
		Lines = {
			Greeting = "Buenas noches. Para pasar a LA ALFOMBRA ROJA necesito ver tu credencial del club.",
			Granted = "Todo en orden. Adelante, bienvenido a LA ALFOMBRA ROJA.",
			Denied = "Lo siento, esta noche no puedo dejarte pasar.",
			Already = "Ya tienes acceso. Pasa cuando quieras.",
			Disclaimer = "Credencial ficticia del club. No es un documento oficial ni comprueba la edad: eso lo gestiona Roblox.",
		},
	},

	Seats = { Enabled = true, PromptDistance = 7, Cooldown = 0.6 },

	-- BAILE. Procedural y local por defecto (no hacen falta animaciones). AnimationId es OPCIONAL y
	-- vacio por defecto: si pones un id de animacion que tengas permiso de usar, se reproduce esa en vez de
	-- la procedural. Access: "Todos" o "Lista" (UserIds de Control.UserIds).
	Dance = {
		Enabled = true,
		MaxAnimateDistance = 80,
		MaxVisible = 12,
		MaxRequestsPerSecond = 3,
		Dances = {
			{ Id = "suave", Name = "Balanceo suave", AnimationId = "", Access = "Todos" },
			{ Id = "disco", Name = "Disco clásico", AnimationId = "", Access = "Todos" },
			{ Id = "rebote", Name = "Rebote", AnimationId = "", Access = "Todos" },
			{ Id = "ola", Name = "Ola de brazos", AnimationId = "", Access = "Todos" },
			{ Id = "lateral", Name = "Paso lateral", AnimationId = "", Access = "Todos" },
		},
	},

	-- NPC decorativos (bartenders, guardias, bailarinas): se animan en el cliente y solo cerca.
	Npcs = { Enabled = true, AnimateDistance = 90, MaxAnimated = 14, Dancers = 4 },

	-- CHAT: se usa SOLO el TextChatService oficial de Roblox (con su filtro). No se crea ningun chat
	-- propio. Si la cuenta del jugador no puede chatear, no se intenta evitarlo.
	Chat = { Enable = true },
}

return Config
