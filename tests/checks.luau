-- Comprobaciones sobre el club ya construido (se concatena DESPUES del script).

local failures = 0
local function check(name, cond, detail)
	if cond then
		print("  PASS  " .. name)
	else
		failures += 1
		print("  FAIL  " .. name .. (detail and (" -> " .. tostring(detail)) or ""))
	end
end

print("\n=== TESTS AURA CLUB ===")

local built = workspace:FindFirstChild("AuraClub")
check("modelo AuraClub en Workspace", built ~= nil and built == club)
check("Baseplate de plantilla eliminado", workspace:FindFirstChild("Baseplate") == nil)

-- piezas y colisionadores ------------------------------------------------
local parts, colliders = {}, {}
local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end
local badPart
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		local s, cf = d.Size, d.CFrame
		if not (finite(s.X) and finite(s.Y) and finite(s.Z) and finite(cf.px) and finite(cf.py) and finite(cf.pz)) or d.Anchored ~= true then
			badPart = badPart or d.Name
		end
		if d.CanCollide ~= false then
			local r = cf.r
			local hx = (math.abs(r[1]) * s.X + math.abs(r[2]) * s.Y + math.abs(r[3]) * s.Z) / 2
			local hy = (math.abs(r[4]) * s.X + math.abs(r[5]) * s.Y + math.abs(r[6]) * s.Z) / 2
			local hz = (math.abs(r[7]) * s.X + math.abs(r[8]) * s.Y + math.abs(r[9]) * s.Z) / 2
			table.insert(colliders, {
				x1 = cf.px - hx, x2 = cf.px + hx,
				y1 = cf.py - hy, y2 = cf.py + hy,
				z1 = cf.pz - hz, z2 = cf.pz + hz,
				name = d.Name,
			})
		end
	end
end
check("todas las partes: Anchored, tamanos y posiciones finitos", badPart == nil, badPart)
check("cantidad de partes razonable (< 8000)", #parts < 8000, #parts)
print(string.format("        partes=%d  colisionables=%d", #parts, #colliders))

local lights = 0
for _, d in club:GetDescendants() do
	if d:IsA("PointLight") or d:IsA("SpotLight") then
		lights += 1
	end
end
check("luces < 150 (rendimiento)", lights < 150, lights)
print("        luces=" .. lights)

local spawnLoc = club:FindFirstChild("ClubSpawn")
check("SpawnLocation presente", spawnLoc ~= nil)

local hasSound = false
for _, d in club:GetDescendants() do
	if d:IsA("Sound") then
		hasSound = true
	end
end
check("objeto Sound de musica presente", hasSound)

-- consultas geometricas ---------------------------------------------------
local function topsAt(x, z)
	local seen, out = {}, {}
	for _, c in colliders do
		if x > c.x1 and x < c.x2 and z > c.z1 and z < c.z2 then
			local k = math.floor(c.y2 * 100 + 0.5)
			if not seen[k] then
				seen[k] = true
				table.insert(out, c.y2)
			end
		end
	end
	table.sort(out)
	return out
end
local function hasTop(x, z, y)
	for _, t in topsAt(x, z) do
		if math.abs(t - y) < 0.05 then
			return true
		end
	end
	return false
end
local function hasTopBetween(x, z, lo, hi)
	for _, t in topsAt(x, z) do
		if t >= lo and t <= hi then
			return true
		end
	end
	return false
end

-- pisos --------------------------------------------------------------------
check("piso 1 solido (suelo en y=0)", hasTop(40, -40, 0) or hasTop(-30, 40, 0))
check("piso 2 solido (suelo en y=24)", hasTop(0, 30, 24) and hasTop(-30, -40, 24))
check("piso 3 solido (suelo en y=48)", hasTop(-20, 20, 48) and hasTop(30, 0, 48))
check("atrio: sin losa del piso 2 sobre la pista", not hasTopBetween(0, -10, 20, 30))
check("atrio: techo/azotea del piso 3 sobre la pista", hasTop(0, -10, 48))
check("hueco escalera 1 en piso 2", not hasTop(44, 8, 24) and not hasTop(44, 0, 24))
check("hueco escalera 2 en piso 3", not hasTop(-44, -8, 48) and not hasTop(-44, 0, 48))
check("piscina: fondo a 47, sin losa a 48", hasTop(24, 33, 47) and not hasTop(24, 33, 48))
check("agua de la piscina sin colision", not hasTopBetween(24, 33, 47.1, 48.5))
check("entrada: hueco de puerta libre", not hasTopBetween(0, 49, 1, 10))
check("pared sur cerrada fuera de la puerta", hasTopBetween(20, 49, 21, 23))

-- escaleras: peldanos contiguos de 1 stud y alcanzan el piso siguiente
local function stairInfo(x, zStart, dir, baseY)
	local prev = baseY
	local okRise = true
	for i = 0, 23 do
		local zc = zStart + dir * (2 * i + 1)
		local want = baseY + i + 1
		if not hasTop(x, zc, want) then
			okRise = false
		end
		if want - prev > 1.01 then
			okRise = false
		end
		prev = want
	end
	return okRise
end
check("escalera 1: 24 peldanos de 1 stud hasta y=24", stairInfo(44, 46, -1, 0))
check("escalera 2: 24 peldanos de 1 stud hasta y=48", stairInfo(-44, -46, 1, 24))
check("salida escalera 1 conecta con el suelo del piso 2", hasTop(44, -3, 24))
check("salida escalera 2 conecta con el suelo del piso 3", hasTop(-44, 3, 48))

-- BFS de navegacion (jugador 2x2x5, escalon max 1.6) -------------------------
local CELL, ORIGIN, N = 1, -53, 106
local BODY = 1 -- semilado del cuerpo (jugador 2x2)
local cellColl = {}
for i = 0, N - 1 do
	cellColl[i] = {}
	for j = 0, N - 1 do
		cellColl[i][j] = {}
	end
end
for _, c in colliders do
	local i0 = math.max(0, math.floor((c.x1 - BODY - ORIGIN) / CELL))
	local i1 = math.min(N - 1, math.floor((c.x2 + BODY - ORIGIN) / CELL))
	local j0 = math.max(0, math.floor((c.z1 - BODY - ORIGIN) / CELL))
	local j1 = math.min(N - 1, math.floor((c.z2 + BODY - ORIGIN) / CELL))
	for i = i0, i1 do
		for j = j0, j1 do
			table.insert(cellColl[i][j], c)
		end
	end
end
local nodes = {} -- [i][j] = lista de alturas validas
local totalNodes = 0
for i = 0, N - 1 do
	nodes[i] = {}
	for j = 0, N - 1 do
		local cx, cz = ORIGIN + (i + 0.5) * CELL, ORIGIN + (j + 0.5) * CELL
		local list, seen = {}, {}
		for _, c in cellColl[i][j] do
			if cx > c.x1 and cx < c.x2 and cz > c.z1 and cz < c.z2 and c.y2 < 70 then
				local h = c.y2
				local k = math.floor(h * 10 + 0.5)
				if not seen[k] then
					seen[k] = true
					-- cuerpo libre entre h+1.7 y h+5 en toda la celda (lo bajo se sube de un escalon)
					local blocked = false
					for _, o in cellColl[i][j] do
						-- enterrado: el punto de apoyo esta dentro de otro solido
						if cx > o.x1 and cx < o.x2 and cz > o.z1 and cz < o.z2 and o.y1 < h - 0.05 and o.y2 > h + 0.1 then
							blocked = true
							break
						end
					end
					for _, o in cellColl[i][j] do
						local ox = o.x1 < cx + BODY - 0.05 and o.x2 > cx - BODY + 0.05
						local oz = o.z1 < cz + BODY - 0.05 and o.z2 > cz - BODY + 0.05
						if ox and oz and o.y2 > h + 1.7 and o.y1 < h + 5 then
							blocked = true
							break
						end
					end
					if not blocked then
						table.insert(list, h)
						totalNodes += 1
					end
				end
			end
		end
		nodes[i][j] = list
	end
end
local function key(i, j, h)
	return i * 100000 + j * 1000 + math.floor(h * 10 + 0.5)
end
local visited = {}
local queue, head = {}, 1
local function startNodeNear(x, z)
	local i, j = math.floor((x - ORIGIN) / CELL), math.floor((z - ORIGIN) / CELL)
	local best
	for _, h in nodes[i][j] do
		if not best or math.abs(h - 0.4) < math.abs(best - 0.4) then
			best = h
		end
	end
	return i, j, best
end
local si, sj, sh = startNodeNear(0.5, 38.5)
check("nodo de spawn transitable", sh ~= nil and math.abs(sh - 0.4) < 0.01, sh)
visited[key(si, sj, sh)] = true
table.insert(queue, { si, sj, sh })
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
while head <= #queue do
	local cur = queue[head]
	head += 1
	for _, d in DIRS do
		local ni, nj = cur[1] + d[1], cur[2] + d[2]
		if ni >= 0 and ni < N and nj >= 0 and nj < N then
			for _, h in nodes[ni][nj] do
				if math.abs(h - cur[3]) <= 1.6 then
					local k = key(ni, nj, h)
					if not visited[k] then
						visited[k] = true
						table.insert(queue, { ni, nj, h })
					end
				end
			end
		end
	end
end
local function reachedIn(x1, z1, x2, z2, h)
	local i0, i1 = math.floor((x1 - ORIGIN) / CELL), math.floor((x2 - ORIGIN) / CELL)
	local j0, j1 = math.floor((z1 - ORIGIN) / CELL), math.floor((z2 - ORIGIN) / CELL)
	local n = 0
	for i = i0, i1 do
		for j = j0, j1 do
			for _, hh in nodes[i][j] do
				if math.abs(hh - h) < 0.06 and visited[key(i, j, hh)] then
					n += 1
				end
			end
		end
	end
	return n
end
local function reached(x, z, h)
	local i, j = math.floor((x - ORIGIN) / CELL), math.floor((z - ORIGIN) / CELL)
	for _, hh in nodes[i][j] do
		if math.abs(hh - h) < 0.06 and visited[key(i, j, hh)] then
			return true
		end
	end
	return false
end
print(string.format("        nodos transitables=%d, alcanzados desde el spawn=%d", totalNodes, #queue))
check("alcanza el escenario DJ del piso 1 (y=3)", reachedIn(-17, -46, 17, -38, 3) > 100)
check("alcanza la pista LED (y=0.2)", reachedIn(-23, -33, 23, 13, 0.2) > 1000)
check("alcanza la zona de la barra del piso 1", reachedIn(-39, -25, -37.5, 5, 0) > 30)
check("alcanza los booths del piso 1", reachedIn(-45, 14, -38, 42, 0) > 50)
check("alcanza el piso 2 VIP por la escalera (barra, lounges)", reachedIn(-14, -38, 14, -35, 24) > 50 and reachedIn(-36, 20, 36, 45, 24) > 500)
check("alcanza el balcon del piso 2 junto al atrio", reachedIn(-24, -37.5, 24, -35, 24) > 20)
check("alcanza el piso 3 rooftop por la escalera", reachedIn(-30, 18, 30, 46, 48) > 500)
check("alcanza el DJ del rooftop (y=50)", reachedIn(-13, -46, 13, -38, 50) > 100)
check("alcanza la barra del rooftop", reachedIn(20, -30, 26, -4, 48) > 50)
check("alcanza el fondo de la piscina (y=47)", reachedIn(15, 23, 33, 43, 47) > 100)

-- ningun suelo "perdido": fraccion alcanzable por nivel
local function ratio(level)
	local tot, ok = 0, 0
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			for _, h in nodes[i][j] do
				if math.abs(h - level) < 0.06 then
					tot += 1
					if visited[key(i, j, h)] then
						ok += 1
					end
				end
			end
		end
	end
	return ok, tot
end
for _, lvl in { { 0.2, "piso 1 (pista)" }, { 24, "piso 2" }, { 48, "piso 3" } } do
	local ok, tot = ratio(lvl[1])
	check(string.format("%s: %d/%d celdas planas alcanzables", lvl[2], ok, tot), tot > 0 and ok / tot > 0.9)
end

-- animaciones: 90 s simulados a 30 fps sin errores, lasers dentro del atrio ----
local beams = club:FindFirstChild("Effects"):GetChildren()
check("6 lasers creados", #beams == 6, #beams)
local tileBefore = nil
for _, d in club:GetDescendants() do
	if d.Name == "Tile" then
		tileBefore = d.Color.R .. d.Color.G .. d.Color.B
		break
	end
end
local worst = 0
local strobeSeen = false
local ok, err = pcall(function()
	for _ = 1, 90 * 30 do
		fireHeartbeat(1 / 30)
		for _, b in beams do
			local cf = b.CFrame
			local tip = cf * Vector3.new(0, 0, -b.Size.Z / 2)
			local tail = cf * Vector3.new(0, 0, b.Size.Z / 2)
			for _, p in { tip, tail } do
				local out = math.max(math.abs(p.X) - 24, -34 - p.Z, p.Z - 14, 0)
				if out > worst then
					print(string.format("        laser fuera: (%.1f, %.1f, %.1f) out=%.1f", p.X, p.Y, p.Z, out))
				end
				worst = math.max(worst, out)
			end
			assert(tip.Y > -1 and tip.Y < 41, "punta de laser fuera de altura: " .. tip.Y)
			assert(finite(tip.X) and finite(tip.Z), "NaN en laser")
		end
		for _, d in club:GetDescendants() do
			if d.Name == "Strobe1" and d.Color.R > 0.9 then
				strobeSeen = true
			end
		end
	end
end)
check("90 s de animacion sin errores", ok, err)
check("lasers siempre dentro del hueco del atrio", worst < 0.01, worst)
check("estrobos se encienden en la rafaga", strobeSeen)
local tileAfter
for _, d in club:GetDescendants() do
	if d.Name == "Tile" then
		tileAfter = d.Color.R .. d.Color.G .. d.Color.B
		break
	end
end
check("la pista LED cambia de color", tileBefore ~= tileAfter)
local mirrorN, mirrorMoved = 0, false
for _, d in club:GetDescendants() do
	if d.Name == "MirrorFacet" then
		mirrorN += 1
	end
end
check("bola de espejos: 44 facetas + nucleo", mirrorN == 44 and club:FindFirstChild("Floor1"):FindFirstChild("MirrorCore") ~= nil, mirrorN)
local f1 = club:FindFirstChild("Floor1")
local first
for _, d in f1:GetChildren() do
	if d.Name == "MirrorFacet" then
		first = d
		break
	end
end
local x0, z0 = first.CFrame.px, first.CFrame.pz
fireHeartbeat(1 / 30); fireHeartbeat(1 / 30); fireHeartbeat(1 / 30)
check("la bola de espejos gira", math.abs(first.CFrame.px - x0) + math.abs(first.CFrame.pz - z0) > 0.001)
local screen = club:FindFirstChild("Floor1"):FindFirstChild("DJScreen")
check("pantalla LED con texto", screen ~= nil and #screen:GetChildren() > 0)

-- piezas flotantes: toda parte visible debe tocar (+-0.08) a otra -----------
local boxes = {}
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") and (d.Transparency or 0) < 1 and d.Parent.Name ~= "Effects" then
		local s, cf, r = d.Size, d.CFrame, d.CFrame.r
		local hx = (math.abs(r[1]) * s.X + math.abs(r[2]) * s.Y + math.abs(r[3]) * s.Z) / 2 + 0.08
		local hy = (math.abs(r[4]) * s.X + math.abs(r[5]) * s.Y + math.abs(r[6]) * s.Z) / 2 + 0.08
		local hz = (math.abs(r[7]) * s.X + math.abs(r[8]) * s.Y + math.abs(r[9]) * s.Z) / 2 + 0.08
		table.insert(boxes, { n = d.Name, x1 = cf.px - hx, x2 = cf.px + hx, y1 = cf.py - hy, y2 = cf.py + hy, z1 = cf.pz - hz, z2 = cf.pz + hz })
	end
end
local floating, seenName = {}, {}
for i, a in boxes do
	local touches = false
	for j, b in boxes do
		if i ~= j and a.x1 <= b.x2 and a.x2 >= b.x1 and a.y1 <= b.y2 and a.y2 >= b.y1 and a.z1 <= b.z2 and a.z2 >= b.z1 then
			touches = true
			break
		end
	end
	if not touches and not seenName[a.n] then
		seenName[a.n] = true
		table.insert(floating, string.format("%s@(%.0f,%.0f,%.0f)", a.n, (a.x1 + a.x2) / 2, (a.y1 + a.y2) / 2, (a.z1 + a.z2) / 2))
	end
end
check("ninguna pieza visible flota sin apoyo", #floating == 0, table.concat(floating, ", "))

-- estrobos apagados al construir y solo se encienden en rafagas
local strobesOn = 0
for _, st in fx.strobes do
	if st.light.Enabled ~= false then
		strobesOn += 1
	end
end
check("estrobos: todas las luces nacen apagadas", strobesOn == 0, strobesOn)

-- ID de audio opcional: nunca se inventa uno; normaliza formatos validos
check("MusicId vacio por defecto (sin ID inventado)", CONFIG.MusicId == "")
check("normalizeAudioId acepta numero, texto y rbxassetid", normalizeAudioId(123) == "rbxassetid://123" and normalizeAudioId(" 456 ") == "rbxassetid://456" and normalizeAudioId("rbxassetid://7") == "rbxassetid://7" and normalizeAudioId(nil) == "" and normalizeAudioId("") == "")

-- presupuesto de red: escrituras de propiedades por segundo en regimen estable
__countWrites = true
__writes = 0
for _ = 1, 10 * 30 do
	fireHeartbeat(1 / 30)
end
__countWrites = false
local perSec = __writes / 10
print(string.format("        escrituras de propiedades/s (animacion) = %.0f", perSec))
check("animacion < 1700 escrituras/s", perSec < 1700, perSec)

-- reejecutar no apila conexiones: la anterior se desconecta
check("existe handle de conexion para limpieza al relanzar", _G.AuraClubConnection ~= nil)

-- idempotencia: relanzar no duplica (se prueba aparte en run.sh)
print(string.format("\nRESULTADO: %d fallo(s)", failures))
if failures > 0 then
	error("hay tests fallando")
end
