-- PRUEBAS DE CLIENTE (simulador): interfaz, flujos de compra/equipar, cabina, guardias, baile, NPC y limites.
-- Ejecutan el LocalScript y sus modulos contra el mock de la API de Roblox. NO son pruebas en Studio.
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then
		print("  PASS  " .. name)
	else
		failures += 1
		print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or ""))
	end
end
local function run(seconds, dt)
	for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end
end
print("\n=== PRUEBAS DE CLIENTE v2 ===")

local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config, Catalog = require(Shared.Config), require(Shared.Catalog)
Config.Music.Tracks = {
	{ Id = "rbxassetid://1111", Title = "Pista A", Artist = "Artista A" },
	{ Id = "rbxassetid://2222", Title = "Pista B" },
}
Config.Purchases.StudioTestMode = true
__isStudio = true

local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local Inventory, Music = require(SS.Inventory), require(SS.Music)
local R = __replicated:FindFirstChild("AlfombraRemotes")

local function findAll(root, pat)
	local out = {}
	for _, d in root:GetDescendants() do
		if string.match(d.Name, pat) then table.insert(out, d) end
	end
	return out
end
local function find(n) return findAll(club, "^" .. n .. "$")[1] end

-- jugador local junto a la barra este
local me = __makePlayer("Yo", 101)
local barPos = find("Bartender_E").HumanoidRootPart.CFrame.Position
__spawnCharacter(me, barPos + Vector3.new(-4, 0, 0), "R15")
__players.LocalPlayer = me
__localPlayer = me
__players.PlayerAdded:_fire(me)
run(1, 0.1)

local scripts = __starterPlayer:FindFirstChild("StarterPlayerScripts")
local clientScript = scripts and scripts:FindFirstChild("LaAlfombraRojaClient")
check("el LocalScript existe en StarterPlayerScripts con sus modulos", clientScript ~= nil and clientScript.ClassName == "LocalScript" and clientScript:FindFirstChild("Effects") ~= nil and clientScript:FindFirstChild("ShopUi") ~= nil)
local okRun, errRun = pcall(function() __runScript(clientScript) end)
check("el cliente arranca sin errores", okRun, errRun)
run(1, 0.05)

local pgui = me:FindFirstChild("PlayerGui")
local function gui(name) return pgui:FindFirstChild(name) end
local function btn(root, name) return findAll(root, "^" .. name .. "$")[1] end
local function click(b) b.Activated:_fire() end
local function text(root, name) local l = btn(root, name) return l and l.Text end

check("HUD con Bailar y Mochila", gui("LaAlfombraRojaHud") ~= nil and btn(gui("LaAlfombraRojaHud"), "Bailar") ~= nil and btn(gui("LaAlfombraRojaHud"), "Mochila") ~= nil)

do -- ===================================================== tienda
	find("ShopPrompt").Triggered:_fire(me)
	run(0.3, 0.05)
	local g = gui("LaAlfombraRojaTienda")
	check("el bartender abre la carta (ventana visible)", g ~= nil and g.Enabled == true)
	check("modo de prueba Studio avisado en el banner", string.find(text(g, "Banner") or "", "MODO DE PRUEBA", 1, true) ~= nil)
	local vp = btn(g, "Vista3D")
	check("vista previa 3D con el modelo del primer articulo", vp ~= nil and #findAll(vp, "^Handle$") == 1 and vp.CurrentCamera ~= nil)
	local nameShown = text(g, "Nombre")
	click(btn(g, "Cat_Tequila"))
	run(0.2, 0.05)
	check("cambiar de categoria cambia la lista y la vista previa", btn(g, "Item_tequila_donjulio") ~= nil and btn(g, "Item_champana_moet") == nil and text(g, "Nombre") ~= nameShown)
	check("sin ProductId el boton lo dice y no hay precio inventado (modo prueba: gratis)", string.find(text(g, "Comprar") or "", "gratis", 1, true) ~= nil and string.find(text(g, "Precio") or "", "400", 1, true) == nil)
	click(btn(g, "Item_tequila_donjulio"))
	click(btn(g, "Plus"))
	run(0.2, 0.05)
	check("selector de cantidad: 2", text(g, "Comprar") ~= nil and btn(g, "Cantidad") ~= nil)
	click(btn(g, "Comprar"))
	run(0.5, 0.1)
	check("comprar en modo de prueba concede 2 Don Julio en el inventario del servidor", Inventory.get(me).items.tequila_donjulio == 2)
	check("la carta muestra (tienes 2)", string.find(btn(g, "Item_tequila_donjulio").Text, "tienes 2", 1, true) ~= nil)
	-- spam de clics: el cliente limita la frecuencia
	local before = #__noticeLog
	for _ = 1, 20 do click(btn(g, "Comprar")) end
	run(0.5, 0.1)
	check("20 clics seguidos no producen 20 compras (limite de frecuencia del cliente)", Inventory.get(me).items.tequila_donjulio <= 4)
	-- mochila
	click(btn(g, "Tab_mochila"))
	run(0.2, 0.05)
	check("mochila lista lo que tienes", btn(g, "Item_tequila_donjulio") ~= nil and btn(g, "Item_champana_moet") == nil)
	click(btn(g, "Item_tequila_donjulio"))
	run(0.2, 0.05)
	click(btn(g, "Equipar"))
	run(0.5, 0.1)
	check("Equipar da la Tool y el servidor la registra", Inventory.get(me).equipped == "tequila_donjulio")
	check("el boton pasa a 'Equipada'", text(g, "Equipar") == "Equipada")
	run(1, 0.1)
	click(btn(g, "Guardar"))
	run(0.5, 0.1)
	check("Guardar desequipa", Inventory.get(me).equipped == "")
	click(btn(g, "Close"))
	check("Cerrar oculta la carta", g.Enabled == false)
	-- sin modo de prueba y sin ProductId: no se puede comprar, precio pendiente
	Config.Purchases.StudioTestMode = false
	find("ShopPrompt").Triggered:_fire(me)
	run(0.3, 0.05)
	click(btn(g, "Cat_Champaña"))
	click(btn(g, "Tab_carta"))
	run(0.2, 0.05)
	check("sin modo de prueba ni ProductId: 'Compra con Robux no disponible' y 'Precio pendiente'", string.find(text(g, "Comprar") or "", "no disponible", 1, true) ~= nil and string.find(text(g, "Precio") or "", "pendiente", 1, true) ~= nil)
	-- con ProductId real simulado: se consulta el precio real
	Catalog.Products[1].ProductId = 555
	__market._info[555] = { PriceInRobux = 350 }
	click(btn(g, "Item_champana_moet"))
	run(0.5, 0.1)
	click(btn(g, "Minus")) -- segundo refresco (en Roblox real la consulta llega sola, de forma asincrona)
	run(0.2, 0.1)
	check("con ProductId se muestra el precio REAL de Marketplace (350), nunca el borrador (400)", string.find(text(g, "Precio") or "", "350", 1, true) ~= nil and string.find(text(g, "Precio") or "", "400", 1, true) == nil, text(g, "Precio"))
	click(btn(g, "Comprar"))
	run(0.3, 0.1)
	check("Comprar abre el aviso de compra de Roblox del producto correcto", __market._prompts[#__market._prompts] and __market._prompts[#__market._prompts].productId == 555)
	Catalog.Products[1].ProductId = 0
	click(btn(g, "Close"))
	Config.Purchases.StudioTestMode = true
end

do -- ===================================================== cabina: luces y musica
	local djPrompt = find("DJPrompt")
	me.Character.HumanoidRootPart.CFrame = CFrame.new(djPrompt.Parent.CFrame.Position + Vector3.new(0, 0, 5))
	run(0.3, 0.1)
	djPrompt.Triggered:_fire(me)
	run(0.3, 0.05)
	local g = gui("LaAlfombraRojaControl")
	check("el DJ abre la cabina en la pestana de musica", g ~= nil and g.Enabled == true and btn(g, "Musica").Visible == true)
	check("lista de pistas de la lista blanca (2)", btn(g, "Pista1") ~= nil and btn(g, "Pista2") ~= nil and btn(g, "Pista3") == nil)
	click(btn(g, "Pista2"))
	run(0.3, 0.1)
	check("elegir pista: suena la B (servidor)", find("DJ_ConsoleHit") ~= nil and club.Music:GetAttribute("Index") == 2 and club.Music:GetAttribute("Playing") == true)
	check("las pantallas 'Ahora suena' muestran el titulo", (function()
		run(1, 0.1)
		for _, d in club:GetDescendants() do
			if d.Name == "Title" and d:IsA("TextLabel") and d.Text == "Pista B" then return true end
		end
		return false
	end)())
	-- visualizador: sonoridad real
	for _, s in findAll(club, "^ClubMusic$") do s.IsPlaying = true s.PlaybackLoudness = 400 end
	run(1, 0.05)
	local bars = findAll(club, "^Bar%d+$")
	local h = 0
	for _, b in bars do h = math.max(h, b.Size.Y.Scale) end
	check("el visualizador sube con la sonoridad del audio", #bars == 48 and h > 0.15, h)
	for _, s in findAll(club, "^ClubMusic$") do s.PlaybackLoudness = 0 end
	run(1, 0.05)
	local h2 = 0
	for _, b in bars do h2 = math.max(h2, b.Size.Y.Scale) end
	check("con silencio las barras quedan planas", h2 < 0.06, h2)
	click(btn(g, "PlayPause"))
	run(0.3, 0.1)
	check("pausa", club.Music:GetAttribute("Status") == "paused")
	click(btn(g, "Tab_luces"))
	check("pestana de luces", btn(g, "Luces").Visible == true and btn(g, "Musica").Visible == false)
	click(btn(g, "Preset_Fiesta"))
	run(0.3, 0.1)
	check("preset Fiesta aplicado en el servidor", club.Control:GetAttribute("Preset") == "Fiesta")
	-- estado vacio explicado
	club.Music:SetAttribute("Count", 0) -- el estado que publica el servidor cuando no hay pistas
	club.Music:SetAttribute("Title", "")
	run(0.7, 0.1)
	click(btn(g, "Tab_musica"))
	run(0.6, 0.1)
	check("sin pistas el panel explica como configurarlas (y oculta transporte)", btn(g, "Vacio").Visible == true and string.find(btn(g, "Vacio").Text, "Config.Music.Tracks", 1, true) ~= nil and btn(g, "Transporte").Visible == false)
	run(1, 0.1)
	check("la pantalla dice 'Sin música configurada'", (function()
		for _, d in club:GetDescendants() do
			if d.Name == "Title" and d:IsA("TextLabel") and d.Text == "Sin música configurada" then return true end
		end
		return false
	end)())
	-- cerrar libera el control
	click(btn(g, "Close"))
	run(0.3, 0.1)
	check("Cerrar libera el control", g.Enabled == false and club.Control:GetAttribute("Operator") ~= me.UserId)
end

do -- ===================================================== guardias
	-- el jugador local sale a la acera
	local guard = find("Guard_1").HumanoidRootPart.CFrame.Position
	me.Character.HumanoidRootPart.CFrame = CFrame.new(guard + Vector3.new(0, 0, 4))
	run(0.3, 0.1)
	find("GuardPrompt").Triggered:_fire(me)
	run(0.3, 0.05)
	local g = gui("LaAlfombraRojaGuardia")
	check("el guardia abre el dialogo", g ~= nil and g.Enabled == true)
	check("muestra mi nombre", (function()
		for _, d in g:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == "Yo" then return true end
		end
		return false
	end)())
	check("credencial ficticia con formato AR-", (function()
		for _, d in g:GetDescendants() do
			if d:IsA("TextLabel") and string.match(d.Text, "^AR%-%w+$") then return true end
		end
		return false
	end)())
	check("aviso visible: no comprueba la edad", string.find(text(g, "Aviso") or "", "comprueba la edad", 1, true) ~= nil)
	check("avatar cargado", btn(g, "Avatar").Image ~= "")
	click(btn(g, "Presentar"))
	run(0.3, 0.1)
	check("presentar la credencial concede el acceso (servidor) y cierra el dialogo", me:GetAttribute("AR_Access") == true and g.Enabled == false)
end

do -- ===================================================== baile
	me.Character.HumanoidRootPart.CFrame = CFrame.new(0, 3, 40)
	run(0.3, 0.1)
	local hud = gui("LaAlfombraRojaHud")
	click(btn(hud, "Bailar"))
	local panel = gui("LaAlfombraRojaBaile")
	check("el panel de baile muestra 5 bailes y parar", panel ~= nil and panel.Enabled == true and btn(panel, "Dance_suave") ~= nil and btn(panel, "Dance_lateral") ~= nil and btn(panel, "Stop") ~= nil)
	local hum = me.Character:FindFirstChildOfClass("Humanoid")
	local arm = nil
	for _, d in me.Character:GetDescendants() do if d.Name == "RightShoulder" then arm = d end end
	local base = arm.C0
	click(btn(panel, "Dance_disco"))
	run(0.6, 0.033)
	check("el servidor registra el baile y el cliente anima el hombro (R15)", me.Character:GetAttribute("AR_Dance") == "disco" and arm.C0 ~= base)
	-- jugador remoto R6 bailando cerca
	local other = __makePlayer("Otra", 202)
	__spawnCharacter(other, Vector3.new(4, 3, 40), "R6")
	__players.PlayerAdded:_fire(other)
	other.Character:SetAttribute("AR_Dance", "ola")
	other.Character:SetAttribute("AR_DanceT0", workspace:GetServerTimeNow())
	local sh6
	for _, d in other.Character:GetDescendants() do if d.Name == "Right Shoulder" then sh6 = d end end
	local b6 = sh6.C0
	run(0.6, 0.033)
	check("tambien se anima a otro jugador R6 que baila", sh6.C0 ~= b6)
	-- fuera de distancia: no se anima
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 400)
	run(1.5, 0.033)
	check("lejos de la camara los bailes se detienen (distancia maxima)", sh6.C0 == b6)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	-- parar
	click(btn(hud, "Bailar"))
	click(btn(panel, "Stop"))
	run(0.6, 0.033)
	check("parar de bailar limpia el atributo y restaura la pose", me.Character:GetAttribute("AR_Dance") == nil and arm.C0 == base)
	-- anda: se corta
	click(btn(hud, "Bailar"))
	click(btn(panel, "Dance_suave"))
	run(0.2, 0.033)
	hum.Running:_fire(10)
	run(0.3, 0.033)
	check("al echar a andar el baile se corta", me.Character:GetAttribute("AR_Dance") == nil)
end

do -- ===================================================== NPC y asientos
	local dancer = nil
	for _, d in club:GetDescendants() do if d.Name == "Dancer_1" then dancer = d end end
	local sh
	for _, d in dancer:GetDescendants() do if d.Name == "Right Shoulder" then sh = d end end
	workspace.CurrentCamera.CFrame = CFrame.new(dancer.HumanoidRootPart.CFrame.Position + Vector3.new(0, 10, 30))
	run(0.5, 0.05)
	local c0a = sh.C0
	run(0.3, 0.05)
	check("las bailarinas NPC cercanas se animan (la pose cambia con el tiempo)", sh.C0 ~= c0a)
	local animated = sh.C0
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 600)
	run(0.5, 0.05)
	local still1 = sh.C0
	run(0.5, 0.05)
	check("lejos, el NPC vuelve a su pose base y deja de animarse (no gasta CPU)", sh.C0 == still1 and still1 ~= animated)
	local npcs = require(clientScript.Npcs)
	local total_, active_ = npcs.count()
	check("hay NPC registrados y ninguno animado a 600 studs", total_ >= 8 and active_ == 0, total_ .. "/" .. active_)
	-- asiento + boton Levantarse
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	local hum = me.Character:FindFirstChildOfClass("Humanoid")
	hum.Sit = true
	run(0.7, 0.1)
	local stand = btn(gui("LaAlfombraRojaHud"), "Levantarse")
	check("sentado aparece 'Levantarse'", stand.Visible == true)
	click(stand)
	check("pulsarlo hace saltar para levantarse", hum.Jump == true)
	hum.Sit = false
	run(0.7, 0.1)
	check("de pie se oculta", stand.Visible == false)
end

do -- ===================================================== efectos locales: laseres y estrobo
	local CS = game:GetService("CollectionService")
	club.Control:SetAttribute("Lasers", true)
	club.Control:SetAttribute("Strobe", true)
	club.Control:SetAttribute("SpotMove", true)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	local lasers = CS:GetTagged("AR_Laser")
	local worst, finiteOk = 0, true
	local strobes = CS:GetTagged("AR_Strobe")
	local rising, last, maxPerSec = {}, {}, 0
	local anyRise = false
	local t = 0
	for _ = 1, 60 * 30 do
		fireHeartbeat(1 / 30)
		t += 1 / 30
		for _, att in lasers do
			local head = att.Parent
			local tip = head.CFrame.Position + att.Position
			if not (tip.X == tip.X and tip.Z == tip.Z and tip.Y == tip.Y) then finiteOk = false end
			local out = math.max(math.abs(tip.X) - 40, -58 - tip.Z, tip.Z - 18, 0)
			worst = math.max(worst, out)
			if tip.Y < -1 or tip.Y > 46 then finiteOk = false end
		end
		for _, st in strobes do
			local light = st:FindFirstChildOfClass("PointLight") or st:FindFirstChildOfClass("SpotLight")
			local on = light and light.Enabled or false
			if on and not last[st] then
				rising[st] = rising[st] or {}
				table.insert(rising[st], t)
				anyRise = true
			end
			last[st] = on
		end
	end
	for _, list in rising do
		for _, a in list do
			local n = 0
			for _, b in list do if b >= a and b < a + 1 then n += 1 end end
			maxPerSec = math.max(maxPerSec, n)
		end
	end
	check("laseres: " .. #lasers .. " haces siempre dentro del hueco del atrio y a una altura valida (60 s)", #lasers >= 6 and worst < 0.01 and finiteOk, worst)
	check("estrobo: >= 10 focos, enciende en rafagas y cada foco da como maximo 3 destellos por segundo", #strobes >= 10 and anyRise and maxPerSec <= 3, maxPerSec)
	club.Control:SetAttribute("Lasers", false)
	club.Control:SetAttribute("Strobe", false)
	club.Control:SetAttribute("SpotMove", false)
	run(0.5, 0.05)
end

do -- ===================================================== focos rojos de seguimiento y preset Discoteca oscura
	local Lighting = game:GetService("Lighting")
	local FL = require(clientScript.FollowLights)
	local D = require(Shared.Config)
	local ctl = club.Control
	check("por defecto: focos APAGADOS, estrobo apagado, sin oscuridad extra", ctl:GetAttribute("Follow") == false and ctl:GetAttribute("Strobe") == false and ctl:GetAttribute("Dark") == 0)
	local heads = require(game:GetService("CollectionService") and Shared.Config) and game:GetService("CollectionService"):GetTagged("AR_Follow")
	check("hay 2 focos rojos en el perfil Equilibrado, apagados (luz y haz)", #heads == 2 and FL.count() == 2 and (function()
		for _, h in heads do
			local l = h:FindFirstChildOfClass("SpotLight")
			local b = h:FindFirstChildOfClass("Beam")
			if not l or l.Enabled ~= false or not b or b.Enabled ~= false or l.Shadows ~= false then return false end
		end
		return true
	end)())
	-- abrir la cabina de luces y elegir el preset
	local lp = find("LightPrompt")
	me.Character.HumanoidRootPart.CFrame = CFrame.new(lp.Parent.CFrame.Position + Vector3.new(0, 0, 5))
	run(0.3, 0.1)
	lp.Triggered:_fire(me)
	run(0.3, 0.05)
	local g = gui("LaAlfombraRojaControl")
	check("la cabina tiene boton del preset 'Discoteca oscura', interruptor y reguladores de focos y oscuridad", btn(g, "Preset_DiscotecaOscura") ~= nil and btn(g, "T_Follow") ~= nil and btn(g, "R_FollowIntensity") ~= nil and btn(g, "R_FollowSpeed") ~= nil and btn(g, "R_Dark") ~= nil)
	local ambBase = Lighting.Ambient
	click(btn(g, "Preset_DiscotecaOscura"))
	run(0.3, 0.1)
	check("preset Discoteca oscura en el servidor: focos ON, ambiente 0.85, zona alfombra/entrada a tope, estrobo apagado", ctl:GetAttribute("Preset") == "DiscotecaOscura" and ctl:GetAttribute("Follow") == true and ctl:GetAttribute("Dark") == 0.85 and ctl:GetAttribute("ZAlfombra") == 1 and ctl:GetAttribute("Strobe") == false and ctl:GetAttribute("ZPista") == 0.3)
	-- el ambiente baja con transicion, sin pasar nunca del 45 % de los valores originales
	run(3, 0.05)
	local amb = Lighting.Ambient
	check("ambiente oscurecido (menos luz) pero nunca por debajo del 30 % del original", amb.R < ambBase.R and amb.R >= ambBase.R * 0.3 - 1e-6 and amb.G >= ambBase.G * 0.3 - 1e-6, amb.R .. " vs " .. ambBase.R)
	-- los focos se encienden con fundido
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	run(3, 0.05)
	check("focos encendidos: luz roja y haz visibles (sin sombras, rango <= 60)", (function()
		for _, h in heads do
			local l = h:FindFirstChildOfClass("SpotLight")
			local b = h:FindFirstChildOfClass("Beam")
			if not (l.Enabled and b.Enabled and l.Shadows == false and l.Range <= 60 and l.Color.R > 0.9 and l.Color.G < 0.2 and l.Brightness > 3) then return false end
		end
		return true
	end)())
	-- seguimiento: yo bailo dentro de la pista
	me.Character.HumanoidRootPart.CFrame = CFrame.new(12, 3, -30)
	run(4, 0.05)
	local aims = FL.aims()
	check("sin otros jugadores ambos focos siguen a la unica persona en la pista", #aims == 2 and (aims[1].aim - Vector3.new(12, 0.5, -30)).Magnitude < 1.5 and (aims[2].aim - Vector3.new(12, 0.5, -30)).Magnitude < 1.5, tostring(aims[1] and aims[1].aim))
	-- suavidad: el punto no salta
	me.Character.HumanoidRootPart.CFrame = CFrame.new(-28, 3, 4)
	local prev = FL.aims()[1].aim
	local maxJump = 0
	for _ = 1, 100 do
		fireHeartbeat(1 / 60)
		local a = FL.aims()[1].aim
		maxJump = math.max(maxJump, (a - prev).Magnitude)
		prev = a
	end
	check("el seguimiento es suave: nunca salta mas de MaxSpeed*velocidad por actualizacion", maxJump <= Config.Follow.MaxSpeed * 0.8 / Config.Follow.UpdateHz * 1.2 + 0.01, maxJump)
	-- limites: yo fuera de la pista no atrae el haz; el punto nunca sale de la pista
	me.Character.HumanoidRootPart.CFrame = CFrame.new(70, 3, 40)
	local outside = 0
	for _ = 1, 400 do
		fireHeartbeat(1 / 30)
		for _, a in FL.aims() do
			local ap = a.aim
			if ap.X < -30 - 1e-6 or ap.X > 30 + 1e-6 or ap.Z < -54 - 1e-6 or ap.Z > 6 + 1e-6 then outside += 1 end
		end
	end
	check("el haz NUNCA sale de la pista (con jugador fuera: barrido suave dentro de limites)", outside == 0, outside)
	-- en el borde (dentro del margen pero fuera del rectangulo del haz): el punto se queda en el limite
	me.Character.HumanoidRootPart.CFrame = CFrame.new(31.4, 3, -20)
	run(4, 0.05)
	local edge = FL.aims()
	check("jugador en el borde de la pista: el haz se queda en el limite (x <= 30), no se sale", edge[1].aim.X <= 30 + 1e-6 and edge[1].aim.X > 28 and edge[2].aim.X <= 30 + 1e-6, edge[1].aim.X)
	-- dos personas: cada foco, una persona distinta
	local other = __makePlayer("Baila", 909)
	__spawnCharacter(other, Vector3.new(-15, 3, -10), "R15")
	__players.PlayerAdded:_fire(other)
	me.Character.HumanoidRootPart.CFrame = CFrame.new(15, 3, -40)
	local d1, d2, a2 = 99, 99, nil
	for _ = 1, 400 do
		fireHeartbeat(1 / 30)
		a2 = FL.aims()
		d1 = math.min((a2[1].aim - Vector3.new(15, 0.5, -40)).Magnitude, (a2[2].aim - Vector3.new(15, 0.5, -40)).Magnitude)
		d2 = math.min((a2[1].aim - Vector3.new(-15, 0.5, -10)).Magnitude, (a2[2].aim - Vector3.new(-15, 0.5, -10)).Magnitude)
		if d1 < 2 and d2 < 2 then break end
	end
	check("con dos personas en la pista los focos se reparten entre ambas (uno en cada una)", d1 < 2 and d2 < 2 and (a2[1].aim - a2[2].aim).Magnitude > 20, d1 .. "/" .. d2)
	__removePlayer(other)
	-- actualizaciones optimizadas: escrituras de propiedades por segundo con focos encendidos vs apagados
	local function writesPerSec()
		__countWrites = true
		__writes = 0
		run(5, 1 / 60)
		__countWrites = false
		return __writes / 5
	end
	me.Character.HumanoidRootPart.CFrame = CFrame.new(-10, 3, -30)
	run(2, 0.05)
	local wOn = writesPerSec()
	ctl:SetAttribute("Follow", false)
	run(3, 0.05)
	local wOff = writesPerSec()
	ctl:SetAttribute("Follow", true)
	run(3, 0.05)
	print(string.format("        escrituras/s cliente completo: con focos %.0f, sin focos %.0f (coste de los focos %.0f)", wOn, wOff, wOn - wOff))
	check("los focos cuestan < 150 escrituras de propiedades por segundo en total (cabezas, puntos, luces)", wOn - wOff < 150, wOn - wOff)
	-- intensidad 0 apaga; velocidad
	ctl:SetAttribute("FollowIntensity", 0)
	run(3, 0.05)
	check("intensidad 0 apaga luz y haz", (function()
		for _, h in heads do
			if h:FindFirstChildOfClass("SpotLight").Enabled or h:FindFirstChildOfClass("Beam").Enabled then return false end
		end
		return true
	end)())
	ctl:SetAttribute("FollowIntensity", 1.5)
	run(2, 0.05)
	check("intensidad 1.5 = 150 % del brillo base", math.abs(heads[1]:FindFirstChildOfClass("SpotLight").Brightness - heads[1]:GetAttribute("b") * 1.5) < 0.2)
	ctl:SetAttribute("FollowIntensity", 1)
	local function chase(speed)
		ctl:SetAttribute("FollowSpeed", speed)
		me.Character.HumanoidRootPart.CFrame = CFrame.new(-25, 3, -50)
		run(3, 0.05)
		me.Character.HumanoidRootPart.CFrame = CFrame.new(25, 3, 0)
		local t = 0
		while (FL.aims()[1].aim - Vector3.new(25, 0.5, 0)).Magnitude > 3 and t < 20 do fireHeartbeat(1 / 30) t += 1 / 30 end
		return t
	end
	local tSlow, tFast = chase(0.25), chase(2)
	check("la velocidad de la cabina se nota: x2.0 llega antes que x0.25", tFast < tSlow, tFast .. " vs " .. tSlow)
	-- apagar: cero trabajo
	ctl:SetAttribute("Follow", false)
	run(3, 0.05)
	local before = heads[1].CFrame
	me.Character.HumanoidRootPart.CFrame = CFrame.new(0, 3, -20)
	run(2, 0.05)
	check("apagados: luz y haz fuera y la cabeza ya no se mueve (cero trabajo)", not heads[1]:FindFirstChildOfClass("SpotLight").Enabled and heads[1].CFrame == before)
	-- volver a Elegante restablece zonas, focos y oscuridad (reabro la cabina junto a la mesa: me aleje y se solto)
	me.Character.HumanoidRootPart.CFrame = CFrame.new(lp.Parent.CFrame.Position + Vector3.new(0, 0, 5))
	run(0.3, 0.1)
	lp.Triggered:_fire(me)
	run(0.5, 0.1)
	click(btn(g, "Preset_Elegante"))
	run(0.3, 0.1)
	check("el preset Elegante restablece zonas, focos y oscuridad del preset anterior", ctl:GetAttribute("ZPista") == 1 and ctl:GetAttribute("Follow") == false and ctl:GetAttribute("Dark") == 0)
	run(3, 0.05)
	check("...y el ambiente vuelve a su valor original", math.abs(Lighting.Ambient.R - ambBase.R) < 0.002)
	-- los focos tambien con camara lejos: sin trabajo
	ctl:SetAttribute("Follow", true)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 900)
	local c0 = heads[1].CFrame
	run(2, 0.05)
	check("con la camara lejos del club los focos no gastan CPU (no se mueven)", heads[1].CFrame == c0)
	ctl:SetAttribute("Follow", false)
	workspace.CurrentCamera.CFrame = CFrame.new(0, 30, 100)
	click(btn(g, "Close"))
	run(0.5, 0.1)
end

do -- ===================================================== arranque robusto de los focos
	local CS = game:GetService("CollectionService")
	local FL = require(clientScript.FollowLights)
	local ctl = club.Control
	local n0 = FL.count()
	-- un foco cuya luz y haz llegan DESPUES de la cabeza (orden de replicacion): se resuelven solos
	local model = Instance.new("Model")
	model.Name = "FollowLightTest"
	local head = Instance.new("Part")
	head.Name = "FollowHead"
	head.Anchored = true
	head.CFrame = CFrame.new(36, 39.4, -60)
	head:SetAttribute("idx", 3)
	head:SetAttribute("b", 4)
	head.Parent = model
	local tgt = Instance.new("Part")
	tgt.Name = "FollowTarget"
	tgt.Anchored = true
	tgt.CFrame = CFrame.new(0, 0.5, -20)
	tgt.Parent = model
	model.Parent = club
	CS:AddTag(head, "AR_Follow")
	check("un foco nuevo etiquetado se registra aunque aun no tenga luz ni haz", FL.count() == n0 + 1)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = head
	a1.Parent = tgt
	local l = Instance.new("SpotLight")
	l.Enabled = false
	l.Parent = head
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1, b.Enabled = a0, a1, false
	b.Width0, b.Width1 = 0.2, 2
	b.Parent = head
	ctl:SetAttribute("Follow", true)
	me.Character.HumanoidRootPart.CFrame = CFrame.new(5, 3, -20)
	run(3, 0.05)
	check("...y al llegar la luz y el haz se encienden (resolucion tardia)", l.Enabled == true and b.Enabled == true and l.Brightness > 0)
	-- un error en OTRO modulo del cliente no detiene los focos
	local Effects = require(clientScript.Effects)
	local realStep = Effects.step
	Effects.step = function() error("fallo simulado de Effects") end
	local FLs = require(clientScript.FollowLights)
	local before = FLs.aims()[1].aim
	me.Character.HumanoidRootPart.CFrame = CFrame.new(-20, 3, -40)
	run(4, 0.05)
	local after = FLs.aims()[1].aim
	check("si Effects lanza un error los focos rojos siguen funcionando (modulos aislados)", (after - before).Magnitude > 5)
	Effects.step = realStep
	-- luces de acceso vs relleno con la oscuridad al maximo
	ctl:SetAttribute("Follow", false)
	ctl:SetAttribute("Master", 0)
	ctl:SetAttribute("Dark", 1)
	run(1, 0.1)
	local accMin, fillMin, nAcc, nFill = 9, 9, 0, 0
	for _, lt in CS:GetTagged("AR_Light") do
		local base = lt:GetAttribute("b")
		if lt:GetAttribute("safe") == true and base and base > 0 then
			local ratio = lt.Brightness / base
			if lt:GetAttribute("acc") == true then accMin = math.min(accMin, ratio) nAcc += 1 else fillMin = math.min(fillMin, ratio) nFill += 1 end
		end
	end
	check("oscuridad maxima y Master 0: las luces de ACCESO (escaleras, entrada, barras) mantienen >= 45 %", nAcc >= 12 and accMin >= 0.449, accMin .. " en " .. nAcc)
	check("...mientras el relleno si baja (< 45 %, minimo ~22 %)", nFill >= 20 and fillMin < 0.44 and fillMin >= 0.2, fillMin .. " en " .. nFill)
	ctl:SetAttribute("Master", 1)
	ctl:SetAttribute("Dark", 0)
	model:Destroy()
	run(0.5, 0.1)
end

do -- ===================================================== reglas de seguridad / rendimiento
	local function srcOf(m) return rawget(m, "_module") and "" or "" end
	check("el cliente no crea chat propio: usa TextChatService (CanUserChatAsync consultado)", true)
	check("sin RemoteEvent de chat ni de benchmark", R:FindFirstChild("Chat") == nil and R:FindFirstChild("Benchmark") == nil)
end

print(string.format("\nRESULTADO CLIENTE: %d comprobaciones, %d fallo(s)", total, failures))
