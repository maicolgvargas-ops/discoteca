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
check("atrio: techo/azotea del piso 3 sobre la pista", hasTop(0.5, -11, 48))
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
check("escalera 1: 24 peldanos de 1 stud hasta y=24", stairInfo(43, 38, -1, 0))
check("escalera 2: 24 peldanos de 1 stud hasta y=48", stairInfo(-43, -38, 1, 24))
check("salida escalera 1 conecta con el suelo del piso 2", hasTop(43, -12, 24))
check("salida escalera 2 conecta con el suelo del piso 3", hasTop(-43, 12, 48))

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

-- cobertura de luz: >= 90% de las celdas caminables de cada piso con una luz cerca ---
local lightsList = {}
for _, d in club:GetDescendants() do
	if (d:IsA("PointLight") or d:IsA("SpotLight")) and d.Enabled ~= false then
		local part = d.Parent
		table.insert(lightsList, { x = part.CFrame.px, y = part.CFrame.py, z = part.CFrame.pz, r = d.Range })
	end
end
local function lit(x, y, z)
	for _, l in lightsList do
		local dx, dy, dz = x - l.x, y - l.y, z - l.z
		if dy < 1 and (dx * dx + dy * dy + dz * dz) <= (0.75 * l.r) ^ 2 then
			return true
		end
	end
	return false
end
for _, lvl in { { 0.2, "piso 1" }, { 24, "piso 2" }, { 48, "piso 3" } } do
	local tot, ok = 0, 0
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			for _, h in nodes[i][j] do
				if math.abs(h - lvl[1]) < 0.06 and visited[key(i, j, h)] then
					tot += 1
					if lit(ORIGIN + (i + 0.5) * CELL, h + 3, ORIGIN + (j + 0.5) * CELL) then
						ok += 1
					end
				end
			end
		end
	end
	check(string.format("cobertura de luz %s: %d/%d celdas (%.0f%%)", lvl[2], ok, tot, 100 * ok / math.max(1, tot)), tot > 0 and ok / tot >= 0.9)
end
local amb = Lighting.Ambient
check("ambiente base legible (luminancia media >= 0.15)", (amb.R + amb.G + amb.B) / 3 >= 0.15, (amb.R + amb.G + amb.B) / 3)
check("luces < 150 con el relleno", lights + 0 < 150 and #lightsList < 150, #lightsList)

-- ================= ESCALERAS: ancho, descansos, altura libre, circulacion =================
local stepRows = {}
for _, d in club:GetDescendants() do
	local sn, idx = string.match(d.Name, "^(Stairs%d)_Step(%d+)$")
	if sn and d:IsA("BasePart") then
		stepRows[sn] = stepRows[sn] or {}
		stepRows[sn][tonumber(idx)] = d
	end
end
for _, sn in { "Stairs1", "Stairs2" } do
	local rows = stepRows[sn]
	local minW, maxRise = 1e9, 0
	for i = 0, 23 do
		minW = math.min(minW, rows[i].Size.X)
	end
	check(sn .. ": 24 peldanos y ancho util >= 10 studs", #rows + 1 == 24 and minW >= 10, minW)
end

-- descansos 10x10 libres de solidos (nada entre el suelo y 6 studs de altura)
local function rectClear(x1, z1, x2, z2, floorY)
	local bad
	for _, cl in colliders do
		if cl.x1 < x2 - 0.05 and cl.x2 > x1 + 0.05 and cl.z1 < z2 - 0.05 and cl.z2 > z1 + 0.05 and cl.y2 > floorY + 0.3 and cl.y1 < floorY + 6 then
			bad = bad or cl.name
		end
	end
	return bad == nil, bad
end
for _, l in {
	{ "descanso de entrada escalera 1 (piso 1)", 38, 38, 48, 48, 0 },
	{ "descanso de llegada escalera 1 (piso 2)", 38, -20, 48, -10, 24 },
	{ "descanso de entrada escalera 2 (piso 2)", -48, -48, -38, -38, 24 },
	{ "descanso de llegada escalera 2 (piso 3)", -48, 10, -38, 20, 48 },
} do
	local ok_, who = rectClear(l[2], l[3], l[4], l[5], l[6])
	check(l[1] .. ": 10x10 libre de muebles", ok_, who)
end

-- altura libre sobre cada peldano (>= 7 studs: avatar de 5 + margen)
local minClear, worstStep = 1e9, nil
for _, sn in { "Stairs1", "Stairs2" } do
	for i = 0, 23 do
		local st = stepRows[sn][i]
		local sx1, sx2 = st.CFrame.px - st.Size.X / 2 + 0.5, st.CFrame.px + st.Size.X / 2 - 0.5
		local sz1, sz2 = st.CFrame.pz - st.Size.Z / 2 + 0.1, st.CFrame.pz + st.Size.Z / 2 - 0.1
		local top = st.CFrame.py + st.Size.Y / 2
		local lowest = 1e9
		for _, cl in colliders do
			if not string.find(cl.name, "_Step") and cl.x1 < sx2 and cl.x2 > sx1 and cl.z1 < sz2 and cl.z2 > sz1 and cl.y2 > top + 0.3 then
				lowest = math.min(lowest, cl.y1)
			end
		end
		local clearance = lowest - top
		if clearance < minClear then
			minClear, worstStep = clearance, sn .. "_Step" .. i
		end
	end
end
print(string.format("        altura libre minima sobre peldanos = %.1f studs (%s)", minClear, tostring(worstStep)))
check("altura libre >= 7 studs sobre todos los peldanos", minClear >= 7, minClear)

-- circulacion: filas alcanzables a todo lo ancho de peldanos y descansos
local function visitedRow(x1, x2, z, h)
	local n = 0
	local j = math.floor((z - ORIGIN) / CELL)
	for i = math.floor((x1 - ORIGIN) / CELL), math.floor((x2 - ORIGIN) / CELL) do
		for _, hh in nodes[i][j] do
			if math.abs(hh - h) < 0.06 and visited[key(i, j, hh)] then
				n += 1
			end
		end
	end
	return n
end
local minRow = 1e9
for _, sn in { "Stairs1", "Stairs2" } do
	for _, i in { 0, 6, 12, 18, 23 } do
		local st = stepRows[sn][i]
		local top = st.CFrame.py + st.Size.Y / 2
		local n = visitedRow(st.CFrame.px - 5, st.CFrame.px + 5, st.CFrame.pz - 0.5, top)
		minRow = math.min(minRow, n)
	end
end
print("        celdas caminables a lo ancho (min en los peldanos muestreados) = " .. minRow)
check("ancho caminable >= 8 celdas de 1 stud en los peldanos", minRow >= 8, minRow)
check("descanso de entrada escalera 1 transitable", reachedIn(39, 39, 47, 47, 0) >= 50)
check("descanso de llegada escalera 1 transitable", reachedIn(39, -19, 47, -11, 24) >= 50)
check("descanso de entrada escalera 2 transitable", reachedIn(-47, -47, -39, -39, 24) >= 50)
check("descanso de llegada escalera 2 transitable", reachedIn(-47, 11, -39, 19, 48) >= 50)
check("los tres pisos conectados: P1 -> P2 -> P3 a pie", reachedIn(39, -19, 47, -11, 24) > 0 and reachedIn(-47, 11, -39, 19, 48) > 0)

-- pasillos: junto a las escaleras queda un pasillo de >= 4 studs libre
check("pasillo este del piso 2 (entre lounges y hueco)", reachedIn(34.5, -33, 37.5, 9, 24) >= 60)
check("pasillo oeste del piso 2 (entre escalera y lounges)", reachedIn(-37.5, -35, -34.5, 3, 24) >= 40)
check("pista de baile libre de solidos (nada sobre 0.3 studs)", (function()
	for _, cl in colliders do
		if cl.x1 < 24 and cl.x2 > -24 and cl.z1 < 14 and cl.z2 > -34 and cl.y2 > 0.3 and cl.y1 < 6 then
			return false
		end
	end
	return true
end)())

-- ================= VASOS DE CRISTAL =================
local function nameMatches(pat)
	local list = {}
	for _, d in club:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, pat) then
			table.insert(list, d)
		end
	end
	return list
end
local rims = nameMatches("Glass%d_Rim$")
local shotRims = nameMatches("_Shot%d_Rim$")
local walls = {}
for _, d in nameMatches("Glass%d_Wall%d?$") do
	table.insert(walls, d)
end
for _, d in nameMatches("_Shot%d_Wall$") do
	table.insert(walls, d)
end
local liquids, colorsSeen, ncolors = {}, {}, 0
for _, d in nameMatches("Glass%d_Liquid%d?$") do
	table.insert(liquids, d)
	local k = string.format("%.2f,%.2f,%.2f", d.Color.R, d.Color.G, d.Color.B)
	if not colorsSeen[k] then
		colorsSeen[k] = true
		ncolors += 1
	end
end
local okT = true
for _, w in walls do
	if w.Transparency < 0.6 or w.Transparency > 0.85 then
		okT = false
	end
end
print(string.format("        vasos: %d con borde, %d chupitos, %d paredes, %d liquidos, %d colores", #rims, #shotRims, #walls, #liquids, ncolors))
check("vasos de cristal con borde en las 3 barras (>= 13)", #rims >= 13, #rims)
check("vasos con base, pared translucida (0.6-0.85) y liquido", #walls >= 13 and okT and #liquids >= 13)
check("liquidos de al menos 5 colores distintos", ncolors >= 5, ncolors)
check("hielo en los vasos (>= 10 cubos)", #nameMatches("_Ice%d$") >= 10)
check("pajillas en los vasos (>= 5)", #nameMatches("_Straw$") >= 5)
check("posavasos con aro de neon (>= 13)", #nameMatches("_Coaster$") >= 13)
check("bandejas con 9 chupitos", #shotRims == 9, #shotRims)
local blocking
local maxTop = 0
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") and (string.find(d.Name, "^BarGlass") or string.find(d.Name, "^VipGlass") or string.find(d.Name, "^RoofGlass") or string.find(d.Name, "Shots_") or string.find(d.Name, "^BarShots") or string.find(d.Name, "^VipShots") or string.find(d.Name, "^RoofShots")) then
		if d.CanCollide ~= false then
			blocking = blocking or d.Name
		end
		maxTop = math.max(maxTop, d.CFrame.py + d.Size.Y / 2 - ((d.CFrame.py > 40 and 52.5) or (d.CFrame.py > 20 and 28.5) or 4.5))
	end
end
check("la cristaleria no colisiona (no bloquea la barra)", blocking == nil, blocking)
check("vasos bajos: altura maxima sobre la barra <= 4 studs", maxTop <= 4, maxTop)

-- ================= HALLOWEEN =================
local pumpkins = nameMatches("Pumpkin%d?_Body$")
check("calabazas con cara (>= 20)", #pumpkins >= 20 and #nameMatches("Pumpkin%d?_EyeL$") == #pumpkins, #pumpkins)
check("velas con llama (>= 12 racimos)", #nameMatches("Candle%d?_Candle1$") >= 12, #nameMatches("Candle%d?_Candle1$"))
check("telaranas (>= 7)", #nameMatches("Web%u?%d?_R0$") >= 7, #nameMatches("Web%u?%d?_R0$"))
check("murcielagos (>= 14)", #nameMatches("Bat%d+_Body$") >= 14, #nameMatches("Bat%d+_Body$"))
check("guirnaldas naranja/morado (>= 2) y calderos (>= 2)", #nameMatches("Garland_Bulb0$") >= 2 and #nameMatches("Cauldron_Pot$") >= 2)
check("luces de llama/calabaza/caldero con parpadeo (>= 15)", #fx.flames >= 15, #fx.flames)
local solidDecor
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide ~= false and string.find(d.Name, "Pumpkin") then
		solidDecor = solidDecor or d.Name
	end
end
check("la decoracion de Halloween no colisiona (no obstruye)", solidDecor == nil and (function()
	for _, d in club:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide ~= false and (string.find(d.Name, "Candle") or string.find(d.Name, "Web") or string.find(d.Name, "Bat%d") or string.find(d.Name, "Garland") or string.find(d.Name, "Cauldron")) then
			return false
		end
	end
	return true
end)(), solidDecor)
check("partes totales razonables (< 3500)", #parts < 3500, #parts)

-- idempotencia: relanzar no duplica (se prueba aparte en run.sh)
print(string.format("\nRESULTADO: %d fallo(s)", failures))
if failures > 0 then
	error("hay tests fallando")
end
