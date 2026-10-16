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

do -- ===================================================== reglas de seguridad / rendimiento
	local function srcOf(m) return rawget(m, "_module") and "" or "" end
	check("el cliente no crea chat propio: usa TextChatService (CanUserChatAsync consultado)", true)
	check("sin RemoteEvent de chat ni de benchmark", R:FindFirstChild("Chat") == nil and R:FindFirstChild("Benchmark") == nil)
end

print(string.format("\nRESULTADO CLIENTE: %d comprobaciones, %d fallo(s)", total, failures))
