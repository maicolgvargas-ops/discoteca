-- PRUEBAS DE ASIENTOS (simulador): sentarse, salir (boton / salto), cooldowns, ocupados y spam. El mock reproduce el fallo REAL
-- visto en Studio: sentado en un Seat anclado, Humanoid.Jump y Sit=false NO liberan; solo destruir el SeatWeld (servidor).
local failures, total = 0, 0
local function check(name, cond, detail)
	total += 1
	if cond then print("  PASS  " .. name) else failures += 1 print("  FAIL  " .. name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end
local function run(seconds, dt) for _ = 1, math.max(1, math.floor(seconds / dt)) do fireHeartbeat(dt) end end
print("\n=== PRUEBAS DE ASIENTOS v2.1.4 ===")

local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
__runScript(SS)
local Shared = __replicated:FindFirstChild("AlfombraShared")
local Config = require(Shared.Config)
local club = workspace:FindFirstChild("LaAlfombraRoja")
local R = __replicated:FindFirstChild("AlfombraRemotes")
local function find(n) for _, d in club:GetDescendants() do if d.Name == n then return d end end end
local function makeP(name, id, pos)
	local p = __makePlayer(name, id)
	__spawnCharacter(p, pos or Vector3.new(0, 3, 91), "R15")
	__players.PlayerAdded:_fire(p)
	return p
end
local function stand(p, ...) R.Social.OnServerEvent:_fire(p, "Stand", ...) end
local function hum(p) return p.Character:FindFirstChildOfClass("Humanoid") end
local function hrp(p) return p.Character.HumanoidRootPart end

local seatA = find("BarWStool3_Sit")
local seatB = find("BarWStool2_Sit") or find("BarWStool1_Sit")
local promptA = seatA:FindFirstChild("SitPrompt")
local promptB = seatB:FindFirstChild("SitPrompt")
check("los asientos del bar existen, son Seat y tienen prompt", seatA ~= nil and seatA:IsA("Seat") and promptA ~= nil and seatB ~= nil and promptB ~= nil and seatA ~= seatB)

local ana = makeP("Ana", 101, seatA.Position + Vector3.new(2, 0, 0))
check("1) E en el asiento: Ana queda sentada (Occupant, SeatPart, Sit)", (function()
	promptA.Triggered:_fire(ana)
	return seatA.Occupant == hum(ana) and hum(ana).SeatPart == seatA and hum(ana).Sit == true and promptA.Enabled == false
end)())

hum(ana).Jump = true
hum(ana).Sit = false
run(3, 0.1)
check("2) (reproduce el fallo real) Jump y Sit=false NO la liberan: sigue Sit=true y SeatPart", hum(ana).Sit == true and hum(ana).SeatPart == seatA and seatA.Occupant == hum(ana))

-- el cliente envia Stand; el servidor valida y libera SOLO su asiento
run(0.5, 0.1)
local before = hrp(ana).Position
stand(ana)
local d = (hrp(ana).Position - seatA.Position).Magnitude
check("3) 'Levantarse' (Stand) libera: Occupant nil, Sit=false, SeatPart nil, prompt reactivado", seatA.Occupant == nil and hum(ana).Sit == false and hum(ana).SeatPart == nil and seatA:FindFirstChild("SeatWeld") == nil and promptA.Enabled == true)
check("...y el servidor la deja cerca del asiento (<= 4.2 studs), no donde diga el cliente", d <= 4.2 and d > 0.5, d)
check("...en un hueco libre (sin piezas con colision en su volumen) o justo encima del asiento", (function()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ana.Character, seatA }
	local parts = workspace:GetPartBoundsInBox(CFrame.new(hrp(ana).Position), Vector3.new(2.6, 4.6, 2.6), params)
	for _, p in parts do if p.CanCollide then return hrp(ana).Position.Y - seatA.Position.Y < 3.6 end end
	return true
end)())

-- cooldown: no vuelve a sentarse de inmediato
promptA.Triggered:_fire(ana)
check("4a) tocar E justo despues de levantarse NO la vuelve a sentar (cooldown)", seatA.Occupant == nil and hum(ana).Sit == false)
run(0.5, 0.1)
hrp(ana).CFrame = CFrame.new(seatB.Position + Vector3.new(2, 0, 0))
promptB.Triggered:_fire(ana)
check("4a2) tampoco se sienta de inmediato en OTRO asiento (StandCooldown por jugador)", seatB.Occupant == nil and hum(ana).Sit == false)
run(1.0, 0.1)
promptA.Triggered:_fire(ana)
check("4b) pasado StandCooldown pero en el MISMO asiento aun no (SameSeatCooldown)", seatA.Occupant == nil)
run(2.0, 0.1)
promptA.Triggered:_fire(ana)
check("4c) pasados los cooldowns puede volver a sentarse en el mismo asiento", seatA.Occupant == hum(ana) and hum(ana).Sit == true)
run(0.5, 0.1)
stand(ana)
run(1.2, 0.1)
hrp(ana).CFrame = CFrame.new(seatB.Position + Vector3.new(2, 0, 0))
promptB.Triggered:_fire(ana)
check("4d) en OTRO asiento puede sentarse tras el StandCooldown (sin esperar el del mismo asiento)", seatB.Occupant == hum(ana))
run(0.5, 0.1)
stand(ana)
run(1.2, 0.1)

-- asientos ocupados y no liberar a otros
local beto = makeP("Beto", 202, seatA.Position + Vector3.new(2, 0, 0))
promptA.Triggered:_fire(beto)
run(0.5, 0.1)
check("5a) Beto ocupa seatA", seatA.Occupant == hum(beto))
local cris = makeP("Cris", 303, seatA.Position + Vector3.new(0, 0, 2))
promptA.Triggered:_fire(cris)
check("5b) asiento ocupado: Cris NO puede sentarse", seatA.Occupant == hum(beto) and hum(cris).Sit == false)
local cPos = hrp(cris).Position
stand(cris)
check("5c) Cris (de pie) pide Stand: NO libera a Beto y NO la mueve (sin teleport)", seatA.Occupant == hum(beto) and hum(beto).Sit == true and (hrp(cris).Position - cPos).Magnitude < 1e-6)
-- Cris se sienta en otro y sale: solo el suyo
run(1.0, 0.1)
hrp(cris).CFrame = CFrame.new(seatB.Position + Vector3.new(2, 0, 0))
promptB.Triggered:_fire(cris)
run(0.5, 0.1)
stand(cris)
check("5d) Cris sentada en seatB sale: seatB libre y Beto sigue sentado en seatA", seatB.Occupant == nil and hum(cris).Sit == false and seatA.Occupant == hum(beto))

-- Stand con argumentos manipulados: se ignoran
local bPos = hrp(beto).Position
run(0.5, 0.1)
R.Social.OnServerEvent:_fire(beto, "Stand", Vector3.new(999, 999, 999), seatB, { x = 1 })
check("6) Stand con posicion/asiento ajenos en los argumentos: se libera SU asiento y el punto de salida lo elige el servidor", seatA.Occupant == nil and (hrp(beto).Position - seatA.Position).Magnitude <= 4.2 and (hrp(beto).Position - Vector3.new(999, 999, 999)).Magnitude > 100)

-- asientos que NO son del club: ignorados
local ext = Instance.new("Seat")
ext.Name = "AsientoAjeno"
ext.Anchored = true
ext.CFrame = CFrame.new(60, 3, 100)
ext.Parent = workspace
hrp(cris).CFrame = CFrame.new(60, 5, 100)
ext:Sit(hum(cris))
run(0.5, 0.1)
stand(cris)
check("7) un Seat que no es del club no lo gestiona el servidor (Stand ignorado)", ext.Occupant == hum(cris))
ext:FindFirstChild("SeatWeld"):Destroy()

-- spam
local dana = makeP("Dana", 404, seatB.Position + Vector3.new(2, 0, 0))
promptB.Triggered:_fire(dana)
run(0.5, 0.1)
local okSpam = pcall(function() for _ = 1, 60 do stand(dana) end end)
check("8a) 60 Stand seguidos no dan errores: libre una sola vez", okSpam and seatB.Occupant == nil and hum(dana).Sit == false)
local pos0 = hrp(dana).Position
for _ = 1, 30 do stand(dana) end
check("8b) con el jugador de pie, seguir enviando Stand no lo mueve", (hrp(dana).Position - pos0).Magnitude < 1e-6)
-- spam de E: solo una vez
local okE = true
for _ = 1, 30 do if not pcall(function() promptB.Triggered:_fire(dana) end) then okE = false end end
check("8c) 30 pulsaciones de E seguidas tras salir: no la sientan (cooldown) y sin errores", okE and seatB.Occupant == nil)
-- salida por otra via (el jugador se baja solo): tambien hay cooldown
run(4, 0.1)
promptB.Triggered:_fire(dana)
run(0.3, 0.1)
check("9a) puede sentarse otra vez pasado todo cooldown", seatB.Occupant == hum(dana))
seatB:FindFirstChild("SeatWeld"):Destroy() -- el motor la libera por otra causa
check("9b) liberada por otra via (soldadura destruida): sin ocupante", seatB.Occupant == nil)
promptB.Triggered:_fire(dana)
check("9c) y tampoco se vuelve a sentar de inmediato", seatB.Occupant == nil)

-- anti sentarse-y-levantarse instantaneo (StandMinInterval)
run(4, 0.1)
promptB.Triggered:_fire(dana)
stand(dana)
check("10) Stand dentro de StandMinInterval tras sentarse se ignora (anti-parpadeo)", seatB.Occupant == hum(dana))
run(0.5, 0.1)
stand(dana)
check("...y pasado el intervalo funciona", seatB.Occupant == nil)

-- sale del servidor sentado: sin errores
local eli = makeP("Eli", 505, seatA.Position + Vector3.new(2, 0, 0))
run(4, 0.1)
promptA.Triggered:_fire(eli)
check("11) salir del servidor sentado no da errores", pcall(function() __removePlayer(eli) end))

print(string.format("\nRESULTADO ASIENTOS: %d comprobaciones, %d fallo(s)", total, failures))
