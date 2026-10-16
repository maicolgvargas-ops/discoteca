--[[
	INTERACTIONS - todo lo que el jugador "toca" en el club y se decide en el SERVIDOR:
	  * asientos (Seat reales con ProximityPrompt), bartenders/barras (abren la tienda), cabina (luces/musica)
	  * guardias de la entrada: credencial FICTICIA del club y control de acceso por jugador
	  * baile (estado replicado como atributo del personaje; cada cliente lo anima)
	  * activacion del chat oficial (TextChatService)

	Control de acceso: la puerta tiene una barrera invisible en un grupo de colision propio que SOLO
	choca con los jugadores sin acceso. Quien esta dentro del edificio tiene acceso siempre, asi que la
	salida nunca queda bloqueada. La credencial NO verifica edad ni identidad: es un carnet del club;
	la edad y la clasificacion las gestiona Roblox.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AlfombraShared")
local Config = require(Shared.Config)
local Remotes = require(script.Parent.Remotes)
local Inventory = require(script.Parent.Inventory)
local Control = require(script.Parent.Control)

local Interactions = {}

local GROUP_BARRIER, GROUP_OUTSIDER = "AR_Barrier", "AR_Outsider"
local club
local shopPoints = {} -- posiciones de bartenders/barras (para limitar compras por cercania)
local guardParts = {}
local seatCooldown = {} -- [player] = os.clock()
local standAt = {} -- [player] = os.clock() de la ultima vez que se levanto (por cualquier causa)
local lastSeatOf = {} -- [player] = { seat, t }
local seatSet = {} -- [Seat] = true: SOLO los asientos de este club (no se acepta ninguno mas)
local occupantOf = {} -- [Seat] = Humanoid que lo ocupaba (para anotar quien se levanto)
local danceConns = {} -- [player] = { conns }

local function hrpOf(player)
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart"), ch and ch:FindFirstChildOfClass("Humanoid")
end

------------------------------------------------------------------------
-- asientos
------------------------------------------------------------------------
local function sit(player, seat)
	local hrp, hum = hrpOf(player)
	if not hrp or not hum or hum.Health <= 0 or hum.Sit then
		return false
	end
	if seat.Occupant ~= nil then
		return false
	end
	local now = os.clock()
	if now - (seatCooldown[player] or -100) < Config.Seats.Cooldown then
		return false
	end
	-- tras levantarse no se vuelve a sentar de inmediato (ni en el mismo asiento durante un poco mas)
	if now - (standAt[player] or -100) < Config.Seats.StandCooldown then
		return false
	end
	local last = lastSeatOf[player]
	if last and last.seat == seat and now - (last.t or -100) < Config.Seats.SameSeatCooldown then
		return false
	end
	seatCooldown[player] = now
	if (hrp.Position - seat.CFrame.Position).Magnitude > Config.Seats.PromptDistance + 8 then
		return false
	end
	local ok = pcall(function()
		seat:Sit(hum)
	end)
	-- el Occupant se actualiza un instante despues del Sit: se espera brevemente antes de recurrir a la alternativa
	local waited = 0
	while ok and seat.Occupant ~= hum and waited < 0.3 do
		task.wait(0.05)
		waited += 0.05
	end
	if ok and seat.Occupant == hum then
		lastSeatOf[player] = { seat = seat, t = os.clock() }
	end
	if not ok or seat.Occupant ~= hum then
		-- alternativa: acercar al personaje y dejar que el asiento lo detecte durante un instante
		seat.CanTouch = true
		hrp.CFrame = seat.CFrame * CFrame.new(0, 2.5, 0)
		task.delay(1.0, function()
			seat.CanTouch = false
		end)
	end
	return true
end

-- Sale del asiento PROPIO del jugador: validado en el servidor. Solo si el jugador esta sentado en un asiento de este
-- club, que le tiene a el como ocupante. Nunca libera a otros ocupantes ni acepta posiciones del cliente: el servidor
-- elige un punto de salida cercano (<= ExitDistance + margen) y libre.
local function exitCFrame(seat, hrp)
	local look = seat.CFrame.LookVector
	local right = seat.CFrame.RightVector
	local base = seat.CFrame.Position + Vector3.new(0, 2.8, 0)
	local d = Config.Seats.ExitDistance
	local cands = { -look * d, right * d, -right * d, look * d }
	local params
	local okP = pcall(function()
		params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { hrp.Parent, seat }
	end)
	for _, off in cands do
		local pos = base + off
		local free = true
		if okP then
			local okQ, parts = pcall(function()
				return Workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(2.6, 4.6, 2.6), params)
			end)
			if okQ then
				for _, p in parts do
					if p.CanCollide then
						free = false
						break
					end
				end
			end
		end
		if free then
			return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-off.X, -off.Z), 0)
		end
	end
	return CFrame.new(base + Vector3.new(0, 0.7, 0)) -- sin hueco lateral: justo encima del asiento (cae al suelo)
end

function Interactions.stand(player)
	local hrp, hum = hrpOf(player)
	if not hrp or not hum then
		return false
	end
	local now = os.clock()
	local seat = hum.SeatPart
	if not seat or not seatSet[seat] or seat.Occupant ~= hum then
		return false -- no esta sentado en un asiento de este club (o el ocupante es otro)
	end
	if now - (lastSeatOf[player] and lastSeatOf[player].t or -100) < Config.Seats.StandMinInterval then
		return false -- anti-spam: acaba de sentarse
	end
	standAt[player] = now
	lastSeatOf[player] = { seat = seat, t = now }
	-- libera SOLO la soldadura de ESTE ocupante con ESTE asiento
	pcall(function()
		hum.Sit = false
	end)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy() -- un Seat solo tiene la soldadura de su unico ocupante, ya comprobado arriba
	end
	hrp.CFrame = exitCFrame(seat, hrp)
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
	return true
end

local function setupSeats()
	if not Config.Seats.Enabled then
		return 0
	end
	local n = 0
	for _, d in club:GetDescendants() do
		if d:IsA("Seat") then
			n += 1
			seatSet[d] = true
			d.Disabled = false
			local p = Instance.new("ProximityPrompt")
			p.Name = "SitPrompt"
			p.ActionText = "Sentarse"
			p.ObjectText = "Asiento"
			p.HoldDuration = 0
			p.MaxActivationDistance = Config.Seats.PromptDistance
			p.RequiresLineOfSight = false
			p.Parent = d
			local seat = d
			p.Triggered:Connect(function(player)
				sit(player, seat)
			end)
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local occ = seat.Occupant
				p.Enabled = (occ == nil)
				-- quien se levanta (por salto, boton o lo que sea) queda en espera para no volver a sentarse al instante
				if occ == nil and occupantOf[seat] then
					local who = Players:GetPlayerFromCharacter(occupantOf[seat].Parent)
					if who then
						standAt[who] = os.clock()
						lastSeatOf[who] = { seat = seat, t = os.clock() }
					end
				end
				occupantOf[seat] = occ
			end)
		end
	end
	return n
end

------------------------------------------------------------------------
-- control de acceso (guardias + credencial ficticia)
------------------------------------------------------------------------
local function setGroup(character, group)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

local function applyAccessGroup(player)
	local ch = player.Character
	if not ch then
		return
	end
	local group = (player:GetAttribute("AR_Access") == true) and "Default" or GROUP_OUTSIDER
	setGroup(ch, group)
	if not ch:GetAttribute("AR_AccessHooked") then
		ch:SetAttribute("AR_AccessHooked", true)
		ch.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = (player:GetAttribute("AR_Access") == true) and "Default" or GROUP_OUTSIDER
			end
		end)
	end
end

function Interactions.hasAccess(player)
	return player:GetAttribute("AR_Access") == true
end

function Interactions.grantAccess(player)
	player:SetAttribute("AR_Access", true)
	applyAccessGroup(player)
end

local function nearGuard(player)
	local hrp = hrpOf(player)
	if not hrp then
		return false
	end
	for _, g in guardParts do
		if (hrp.Position - g.CFrame.Position).Magnitude <= Config.Guards.Range + 6 then
			return true
		end
	end
	return false
end

local function isBlocked(player)
	return table.find(Config.Guards.BlockedUserIds, player.UserId) ~= nil
end

local function guardPayload(player)
	local cred = Inventory.credential(player) or Inventory.credentialFor(player.UserId)
	return {
		greeting = Config.Guards.Lines.Greeting,
		disclaimer = Config.Guards.Lines.Disclaimer,
		hasAccess = Interactions.hasAccess(player),
		credential = { id = cred.id },
		userId = player.UserId,
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
	}
end

function Interactions.guardTalk(player)
	if not nearGuard(player) then
		return
	end
	Remotes.fire(player, "SocialNotice", "OpenGuard", guardPayload(player))
end

-- el jugador pulsa "Presentar credencial": el servidor valida TODO (cercania, lista de bloqueados, id)
function Interactions.presentCredential(player, claimedId)
	if not nearGuard(player) then
		Remotes.fire(player, "SocialNotice", "GuardResult", false, "Acércate a los guardias de la entrada.")
		return false
	end
	if Interactions.hasAccess(player) then
		Remotes.fire(player, "SocialNotice", "GuardResult", true, Config.Guards.Lines.Already)
		return true
	end
	local expected = (Inventory.credential(player) or Inventory.credentialFor(player.UserId)).id
	if claimedId ~= nil and claimedId ~= expected then
		Remotes.fire(player, "SocialNotice", "GuardResult", false, Config.Guards.Lines.Denied)
		return false
	end
	if isBlocked(player) then
		Remotes.fire(player, "SocialNotice", "GuardResult", false, Config.Guards.Lines.Denied)
		return false
	end
	Interactions.grantAccess(player)
	Remotes.fire(player, "SocialNotice", "GuardResult", true, Config.Guards.Lines.Granted)
	return true
end

local function setupAccess()
	local barriers = {}
	for _, d in club:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("AR_Role") == "entrance_barrier" then
			table.insert(barriers, d)
		elseif d:IsA("BasePart") and d.Name == "HumanoidRootPart" and d.Parent and d.Parent:GetAttribute("AR_Role") == "guard" then
			table.insert(guardParts, d)
		end
	end
	if #barriers == 0 then
		return false -- sin guardias: todos entran libremente
	end
	local function reg(name)
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	reg(GROUP_BARRIER)
	reg(GROUP_OUTSIDER)
	PhysicsService:CollisionGroupSetCollidable(GROUP_BARRIER, GROUP_OUTSIDER, true)
	PhysicsService:CollisionGroupSetCollidable(GROUP_BARRIER, "Default", false)
	for _, b in barriers do
		b.CollisionGroup = GROUP_BARRIER
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			applyAccessGroup(player)
		end)
		if player.Character then
			applyAccessGroup(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	-- quien ya esta DENTRO del edificio (aparicion, teletransporte...) tiene acceso: la salida nunca se bloquea
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			if not Interactions.hasAccess(p) then
				local hrp = hrpOf(p)
				if hrp then
					local pos = hrp.Position
					if math.abs(pos.X) < 78 and pos.Z > -78 and pos.Z < 79.5 and pos.Y > -2 and pos.Y < 80 then
						Interactions.grantAccess(p)
					end
				end
			end
		end
	end)
	return true
end

------------------------------------------------------------------------
-- baile
------------------------------------------------------------------------
local function clearDance(player)
	local ch = player.Character
	if ch then
		ch:SetAttribute("AR_Dance", nil)
	end
	local conns = danceConns[player]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		danceConns[player] = nil
	end
end

local function danceDef(id)
	for _, d in Config.Dance.Dances do
		if d.Id == id then
			return d
		end
	end
	return nil
end

local function canDance(player, def)
	if def.Access == "Lista" then
		return table.find(Config.Control.UserIds, player.UserId) ~= nil
	end
	return true
end

function Interactions.setDance(player, id)
	if not Config.Dance.Enabled then
		return false
	end
	if id == nil then
		clearDance(player)
		return true
	end
	if type(id) ~= "string" then
		return false
	end
	local def = danceDef(id)
	if not def or not canDance(player, def) then
		return false
	end
	local hrp, hum = hrpOf(player)
	if not hrp or not hum or hum.Health <= 0 or hum.Sit then
		return false
	end
	clearDance(player)
	player.Character:SetAttribute("AR_Dance", id)
	player.Character:SetAttribute("AR_DanceT0", Workspace:GetServerTimeNow())
	-- el baile se corta si el jugador echa a andar, salta o muere
	local conns = {}
	table.insert(conns, hum.Running:Connect(function(speed)
		if speed > 3 then
			clearDance(player)
			Remotes.fire(player, "SocialNotice", "DanceStopped")
		end
	end))
	table.insert(conns, hum.Jumping:Connect(function()
		clearDance(player)
		Remotes.fire(player, "SocialNotice", "DanceStopped")
	end))
	table.insert(conns, hum.Died:Connect(function()
		clearDance(player)
	end))
	danceConns[player] = conns
	return true
end

local function handleSocial(player, action, a, b)
	if not Remotes.allow(player, "Social", math.max(Config.Dance.MaxRequestsPerSecond, Config.Guards.MaxRequestsPerSecond)) then
		return
	end
	if type(action) ~= "string" then
		return
	end
	if action == "Dance" then
		if not Interactions.setDance(player, a) then
			Remotes.fire(player, "SocialNotice", "DanceDenied")
		end
	elseif action == "StopDance" then
		clearDance(player)
	elseif action == "Stand" then
		Interactions.stand(player)
	elseif action == "Credential" then
		Interactions.presentCredential(player, (type(a) == "string") and a or nil)
	end
end

------------------------------------------------------------------------
-- chat oficial: solo se ACTIVAN las ventanas de TextChatService (con su filtro de Roblox)
------------------------------------------------------------------------
function Interactions.setupChat()
	if not Config.Chat.Enable then
		return false
	end
	local ok, tcs = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not ok then
		return false
	end
	for _, name in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" } do
		local cfg = tcs:FindFirstChild(name)
		if cfg then
			pcall(function()
				cfg.Enabled = true
			end)
		end
	end
	return true
end

------------------------------------------------------------------------
-- prompts de accion (tienda, guardias, cabina) y consultas
------------------------------------------------------------------------
function Interactions.nearShop(player)
	local hrp = hrpOf(player)
	if not hrp then
		return false
	end
	for _, p in shopPoints do
		if (hrp.Position - p).Magnitude <= Config.Shop.Range then
			return true
		end
	end
	return false
end

local function setupPrompts()
	for _, d in club:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local action = d:GetAttribute("AR_Action")
			if action == "shop" then
				local part = d.Parent
				table.insert(shopPoints, part.CFrame.Position)
				d.Triggered:Connect(function(player)
					Remotes.fire(player, "ShopNotice", "OpenShop")
					Remotes.fire(player, "ShopNotice", "State", Inventory.snapshot(player))
				end)
			elseif action == "guard" then
				d.Triggered:Connect(function(player)
					Interactions.guardTalk(player)
				end)
			elseif action == "control" then
				local tab = d:GetAttribute("AR_Tab") or "luces"
				d.Triggered:Connect(function(player)
					Control.trigger(player, tab)
				end)
			end
		end
	end
end

function Interactions.init(ctx)
	club = ctx.club
	local remotes = Remotes.get("Social")
	remotes.OnServerEvent:Connect(handleSocial)
	setupPrompts()
	local seats = setupSeats()
	local access = setupAccess()
	Interactions.setupChat()
	Players.PlayerRemoving:Connect(function(player)
		clearDance(player)
		seatCooldown[player] = nil
		standAt[player] = nil
		lastSeatOf[player] = nil
	end)
	return { seats = seats, access = access, shopPoints = #shopPoints }
end

return Interactions
