local function __world()
-- PRUEBAS DE MUNDO (simulador): geometria, navegacion, luces y estilo del club v2. NO son pruebas en Studio.
local SS = __serverScripts:FindFirstChild("LaAlfombraRoja")
local Shared = __replicated:FindFirstChild("AlfombraShared")
__runScript(SS)
local ctx = require(SS.Build).last
local club, fx, LAYOUT, PROFILE, PROFILE_NAME, TILE_COUNT = ctx.club, ctx.fx, ctx.LAYOUT, ctx.PROFILE, ctx.PROFILE_NAME, ctx.TILE_COUNT
local Config = require(Shared.Config)
local CONFIG, LOOK = Config, Config.Look
local normalizeAudioId = require(Shared.Util).normalizeAssetId
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
local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

print("\n=== TESTS LA ALFOMBRA ROJA (perfil " .. PROFILE_NAME .. ") ===")

check("modelo LaAlfombraRoja en Workspace", club ~= nil and workspace:FindFirstChild("LaAlfombraRoja") == club)
check("Baseplate de plantilla eliminado", workspace:FindFirstChild("Baseplate") == nil)

-- piezas y colisionadores ------------------------------------------------
local parts, colliders = {}, {}
local badPart
for _, d in club:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		local s, cf = d.Size, d.CFrame
		local inNpc, anc = false, d.Parent
		while anc and anc ~= club do
			if anc:GetAttribute("AR_Npc") ~= nil then inNpc = true break end
			anc = anc.Parent
		end
		if not (finite(s.X) and finite(s.Y) and finite(s.Z) and finite(cf.px) and finite(cf.py) and finite(cf.pz)) or (d.Anchored ~= true and not inNpc) then
			badPart = badPart or d.Name
		end
		if d.CanCollide ~= false and d:GetAttribute("AR_Role") ~= "entrance_barrier" then -- la barrera de la puerta no frena a quien ya tiene credencial
			local r = cf.r
			local hx = (math.abs(r[1]) * s.X + math.abs(r[2]) * s.Y + math.abs(r[3]) * s.Z) / 2
			local hy = (math.abs(r[4]) * s.X + math.abs(r[5]) * s.Y + math.abs(r[6]) * s.Z) / 2
			local hz = (math.abs(r[7]) * s.X + math.abs(r[8]) * s.Y + math.abs(r[9]) * s.Z) / 2
			table.insert(colliders, {
				x1 = cf.px - hx, x2 = cf.px + hx,
				y1 = cf.py - hy, y2 = cf.py + hy,
				z1 = cf.pz - hz, z2 = cf.pz + hz,
				name = d.Name, part = d,
			})
		end
	end
end
check("todas las partes: Anchored, tamanos y posiciones finitos", badPart == nil, badPart)
check("cantidad de partes razonable (< 7000)", #parts < 7000, #parts)
print(string.format("        partes=%d  colisionables=%d", #parts, #colliders))

local lightsList = {}
for _, d in club:GetDescendants() do
	if d:IsA("PointLight") or d:IsA("SpotLight") then
		local part = d.Parent
		table.insert(lightsList, { x = part.CFrame.px, y = part.CFrame.py, z = part.CFrame.pz, r = d.Range, on = d.Enabled ~= false })
	end
end
check("luces dentro del limite del perfil (Equilibrado <= 145, Alta <= 200)", #lightsList <= (PROFILE_NAME == "Alta" and 200 or 145), #lightsList)
print("        luces=" .. #lightsList)
check("SpawnLocation presente", club:FindFirstChild("ClubSpawn") ~= nil)
local hasSound = false
for _, d in club:GetDescendants() do
	if d:IsA("Sound") then
		hasSound = true
	end
end
check("objeto Sound de musica presente", hasSound)
check("sin pistas por defecto (sin ID de audio inventado)", #Config.Music.Tracks == 0)
check("LogoImageId vacio por defecto (sin ID inventado)", CONFIG.LogoImageId == "")
check("normalizeAudioId acepta numero, texto y rbxassetid", normalizeAudioId(123) == "rbxassetid://123" and normalizeAudioId(" 456 ") == "rbxassetid://456" and normalizeAudioId("rbxassetid://7") == "rbxassetid://7" and normalizeAudioId(nil) == "" and normalizeAudioId("") == "")

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
local function named(pat)
	local out = {}
	for _, d in club:GetDescendants() do
		if string.match(d.Name, pat) then
			table.insert(out, d)
		end
	end
	return out
end
local function find(n)
	for _, d in club:GetDescendants() do
		if d.Name == n then return d end
	end
end
local function count(pat)
	return #named(pat)
end

-- ================= TAMANO 160 x 160 POR PISO =================
local function bbox(list)
	local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in list do
		local s, cf = p.Size, p.CFrame
		x1 = math.min(x1, cf.px - s.X / 2); x2 = math.max(x2, cf.px + s.X / 2)
		z1 = math.min(z1, cf.pz - s.Z / 2); z2 = math.max(z2, cf.pz + s.Z / 2)
	end
	return x1, z1, x2, z2
end
for k = 1, 3 do
	local slabs = {}
	for _, d in club:FindFirstChild("Floor" .. k):GetChildren() do
		if d:IsA("BasePart") and string.match(d.Name, "^Floor" .. k .. "_Slab") then
			table.insert(slabs, d)
		end
	end
	if k == 1 then
		for _, d in club:GetDescendants() do
			if d.Name == "Floor1_Slab" then table.insert(slabs, d) end
		end
	end
	local x1, z1, x2, z2 = bbox(slabs)
	check(string.format("piso %d: losa de %.0f x %.0f studs (>= 160 x 160)", k, x2 - x1, z2 - z1), x2 - x1 >= 159.9 and z2 - z1 >= 159.9 and #slabs > 0)
end
check("piso 1 solido (y=0)", hasTop(-60, 60, 0) and hasTop(60, -60, 0) and hasTop(-60, 20, 0))
check("piso 2 solido (y=24)", hasTop(0, 50, 24) and hasTop(-60, -60, 24) and hasTop(60, 40, 24))
check("piso 3 solido (y=48)", hasTop(-20, 50, 48) and hasTop(50, -50, 48))
check("atrio: sin losa del piso 2 sobre la pista", not hasTopBetween(0, -24, 20, 30))
check("hueco escalera 1 en piso 2", not hasTop(73, 26, 24))
check("hueco escalera 2 en piso 3", not hasTop(-73, -26, 48))
check("entrada: hueco de puerta libre", not hasTopBetween(0, 79, 1, 10))
check("pared sur cerrada fuera de la puerta", hasTopBetween(40, 79, 1, 22.5))

-- ================= IDENTIDAD MAYA CLUB =================
do
local oldBrand = {}
for _, d in club:GetDescendants() do
	if string.find(string.upper(d.Name), "MAYA") or string.find(string.upper(d.Name), "AURA") then
		table.insert(oldBrand, d.Name)
	end
	if d:IsA("TextLabel") and (string.find(string.upper(d.Text), "MAYA") or string.find(string.upper(d.Text), "AURA")) then
		table.insert(oldBrand, d.Text)
	end
end
check("sin rastro de las marcas antiguas (MAYA/AURA) en nombres ni textos", #oldBrand == 0, table.concat(oldBrand, ","))
local function plain(s) return (string.gsub(s, "<[^>]+>", "")) end
local brandLabels, redRoja = 0, 0
for _, d in club:GetDescendants() do
	if d:IsA("TextLabel") and plain(d.Text) == "LA ALFOMBRA ROJA" then
		brandLabels += 1
		if string.find(d.Text, '<font color="#D4182A">ROJA</font>', 1, true) then redRoja += 1 end
	end
end
check("rotulos 'LA ALFOMBRA ROJA' (fachada, rooftop, pantalla DJ) con ROJA en rojo", brandLabels >= 3 and redRoja == brandLabels, brandLabels .. "/" .. redRoja)
check("frente del DJ y del rooftop con ALFOMBRA ROJA", find("DJFront") ~= nil and count("^RoofDJFront$") == 1)
local logos = count("Mono[%a]*_Plate$") + count("Logo_Plate$") + count("Mini%d+_Plate$")
local crowns = count("_CrownBand$")
check("logos con corona dorada (>= 14: 7 de pared + photocall 1 grande + 6 pequenos)", logos >= 14 and crowns == logos, logos .. "/" .. crowns)
local goldLabels, redLabels, serif = 0, 0, true
for _, d in club:GetDescendants() do
	if d:IsA("TextLabel") and d.Name == "ALFOMBRA" then
		goldLabels += 1
		if d.Font ~= Enum.Font.Bodoni or d.TextColor3.R < 0.8 or d.TextColor3.B > 0.5 then serif = false end
	elseif d:IsA("TextLabel") and d.Name == "ROJA" then
		if d.TextColor3.R > 0.75 and d.TextColor3.G < 0.2 then redLabels += 1 end
	end
end
check("logo: ALFOMBRA en serif dorada y ROJA en rojo, en todos los logos", goldLabels == logos and redLabels == logos and serif, goldLabels .. "/" .. redLabels)
local ui = game:GetService("StarterGui"):FindFirstChild("LaAlfombraRojaUI")
local uiTitle
if ui then
	for _, d in ui:GetDescendants() do
		if d:IsA("TextLabel") and plain(d.Text) == "LA ALFOMBRA ROJA" then uiTitle = d end
	end
end
check("UI con titulo LA ALFOMBRA ROJA", ui ~= nil and uiTitle ~= nil)
check("sin imagen (LogoImageId vacio) no hay ImageLabel", #(function() local t = {} for _, d in club:GetDescendants() do if d:IsA("ImageLabel") then table.insert(t, d) end end return t end)() == 0)
end

-- ================= NAVEGACION (BFS por celdas de 1 stud) =================
-- body = semilado del cuerpo; obstaculos entre h+1.7 y h+5 bloquean; escalones de hasta maxStep
local function buildNav(BODY, OX, OZ, NX, NZ)
	local cellColl = {}
	for i = 0, NX - 1 do
		cellColl[i] = {}
		for j = 0, NZ - 1 do
			cellColl[i][j] = {}
		end
	end
	for _, c in colliders do
		local i0 = math.max(0, math.floor(c.x1 - BODY - OX))
		local i1 = math.min(NX - 1, math.floor(c.x2 + BODY - OX))
		local j0 = math.max(0, math.floor(c.z1 - BODY - OZ))
		local j1 = math.min(NZ - 1, math.floor(c.z2 + BODY - OZ))
		for i = i0, i1 do
			for j = j0, j1 do
				table.insert(cellColl[i][j], c)
			end
		end
	end
	local nodes, total = {}, 0
	for i = 0, NX - 1 do
		nodes[i] = {}
		for j = 0, NZ - 1 do
			local cx, cz = OX + i + 0.5, OZ + j + 0.5
			local list, seen = {}, {}
			for _, c in cellColl[i][j] do
				if cx > c.x1 and cx < c.x2 and cz > c.z1 and cz < c.z2 and c.y2 < 70 then
					local h = c.y2
					local k = math.floor(h * 10 + 0.5)
					if not seen[k] then
						seen[k] = true
						local blocked = false
						for _, o in cellColl[i][j] do
							if cx > o.x1 and cx < o.x2 and cz > o.z1 and cz < o.z2 and o.y1 < h - 0.05 and o.y2 > h + 0.1 then
								blocked = true
								break
							end
						end
						if not blocked then
							for _, o in cellColl[i][j] do
								local ox = o.x1 < cx + BODY - 0.05 and o.x2 > cx - BODY + 0.05
								local oz = o.z1 < cz + BODY - 0.05 and o.z2 > cz - BODY + 0.05
								if ox and oz and o.y2 > h + 1.7 and o.y1 < h + 5 then
									blocked = true
									break
								end
							end
						end
						if not blocked then
							table.insert(list, h)
							total += 1
						end
					end
				end
			end
			nodes[i][j] = list
		end
	end
	local nav = { nodes = nodes, total = total }
	function nav.key(i, j, h)
		return (i * 1000 + j) * 10000 + math.floor(h * 10 + 0.5) + 2000
	end
	function nav.ci(x) return math.floor(x - OX) end
	function nav.cj(z) return math.floor(z - OZ) end
	function nav.startNear(x, z, wantH)
		local i, j = nav.ci(x), nav.cj(z)
		local best
		for _, h in nodes[i][j] do
			if not best or math.abs(h - wantH) < math.abs(best - wantH) then best = h end
		end
		return i, j, best
	end
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	function nav.bfs(si, sj, sh, maxStep)
		local vis, queue, head = {}, {}, 1
		vis[nav.key(si, sj, sh)] = true
		table.insert(queue, { si, sj, sh })
		while head <= #queue do
			local cur = queue[head]
			head += 1
			for _, d in DIRS do
				local ni, nj = cur[1] + d[1], cur[2] + d[2]
				if ni >= 0 and ni < NX and nj >= 0 and nj < NZ then
					for _, h in nodes[ni][nj] do
						if math.abs(h - cur[3]) <= maxStep then
							local k = nav.key(ni, nj, h)
							if not vis[k] then
								vis[k] = true
								table.insert(queue, { ni, nj, h })
							end
						end
					end
				end
			end
		end
		return vis, #queue
	end
	function nav.countIn(set, x1, z1, x2, z2, h, tol)
		local n = 0
		for i = math.max(0, nav.ci(x1)), math.min(NX - 1, nav.ci(x2)) do
			for j = math.max(0, nav.cj(z1)), math.min(NZ - 1, nav.cj(z2)) do
				for _, hh in nodes[i][j] do
					if math.abs(hh - h) < (tol or 0.06) and set[nav.key(i, j, hh)] then n += 1 end
				end
			end
		end
		return n
	end
	function nav.levelRatio(set, level, x1, z1, x2, z2)
		local tot, ok = 0, 0
		for i = math.max(0, nav.ci(x1)), math.min(NX - 1, nav.ci(x2)) do
			for j = math.max(0, nav.cj(z1)), math.min(NZ - 1, nav.cj(z2)) do
				for _, h in nodes[i][j] do
					if math.abs(h - level) < 0.06 then
						tot += 1
						if set[nav.key(i, j, h)] then ok += 1 end
					end
				end
			end
		end
		return ok, tot
	end
	return nav
end

-- 1) terreno completo con cuerpo 2x2 (1 stud de semilado)
local W = LAYOUT.world
local OX1, OZ1 = W.x1 - 3, W.z1 - 3
local nav1 = buildNav(1, OX1, OZ1, (W.x2 - W.x1) + 6, (W.z2 - W.z1) + 6)
local si, sj, sh = nav1.startNear(LAYOUT.spawn[1] + 0.5, LAYOUT.spawn[2] + 0.5, 0)
check("nodo de punto de aparicion interior transitable (suelo del piso 1; el ClubSpawn es invisible y sin colision)", sh ~= nil and math.abs(sh) < 0.01, sh)
local visited, nVisited = nav1.bfs(si, sj, sh, 1.6)
print(string.format("        nodos transitables=%d, alcanzados desde el spawn=%d", nav1.total, nVisited))
local function reachedIn(x1, z1, x2, z2, h) return nav1.countIn(visited, x1, z1, x2, z2, h) end

local D, St = LAYOUT.dance, LAYOUT.stage
check("alcanza el escenario DJ del piso 1", reachedIn(-10, St.z1 + 4, 10, St.z2 - 2, St.top) > 60, reachedIn(-10, St.z1 + 4, 10, St.z2 - 2, St.top))
check("alcanza la pista LED", reachedIn(D.x1 + 4, D.z1 + 4, D.x2 - 4, D.z2 - 4, 0.2) > 2000, reachedIn(D.x1 + 4, D.z1 + 4, D.x2 - 4, D.z2 - 4, 0.2))
check("pisos 2 y 3 alcanzables por las escaleras", reachedIn(-60, 40, 60, 70, 24) > 800 and reachedIn(-60, 40, 60, 70, 48) > 800)
local rs = find("RoofStage")
check("alcanza el DJ del rooftop", reachedIn(-10, -76, 10, -64, rs.CFrame.py + rs.Size.Y / 2) > 60)
check("alcanza el fondo de la piscina (y=47)", reachedIn(LAYOUT.pool[1] + 4, LAYOUT.pool[2] + 4, LAYOUT.pool[3] - 4, LAYOUT.pool[4] - 4, 47) > 200)
for _, e in { { "s1", 0 }, { "s1", 24 }, { "s2", 24 }, { "s2", 48 } } do
	local s = LAYOUT[e[1]]
	local r = e[2] == s.baseY and s.landIn or s.landOut
	check(string.format("descanso %s a y=%d transitable", e[1], e[2]), reachedIn(r[1] + 1, r[2] + 1, r[3] - 1, r[4] - 1, e[2]) >= 30)
end
for _, lvl in { { 0.2, "piso 1 (pista)" }, { 24, "piso 2" }, { 48, "piso 3" } } do
	local ok, tot = nav1.levelRatio(visited, lvl[1], -78, -78, 78, 78)
	check(string.format("%s: %d/%d celdas planas alcanzables", lvl[2], ok, tot), tot > 0 and ok / tot > 0.9)
end

-- ruta peatonal SIN escalones (>0.35): puerta -> acera -> paso -> parqueadero
local fi, fj, fh = nav1.startNear(0.5, 70.5, 0)
local flat = nav1.bfs(fi, fj, fh, 0.35)
local function flatIn(x1, z1, x2, z2, h) return nav1.countIn(flat, x1, z1, x2, z2, h) end
check("ruta peatonal: acera frente a la puerta", flatIn(-5, 82, 5, 94, 0) >= 60)
check("ruta peatonal: paso elevado frente a la puerta", flatIn(-5, 97, 5, 115, 0) >= 150)
check("ruta peatonal: camino del parqueadero", flatIn(-3, 130, 3, 148, 0) >= 50 and flatIn(-3, 176, 3, 196, 0) >= 50)
print(string.format("        ruta sin escalones desde el spawn: %d celdas", (function() local n = 0 for _ in flat do n += 1 end return n end)()))

-- 2) pasillos: cuerpo de 7 studs (pasillo principal >= 8) y de 5 (secundario >= 6) dentro del edificio.
-- Las escaleras se recorren con el cuerpo normal (su pendiente "pared" a cuerpos anchos), por eso
-- cada nivel se recorre en anchura desde el descanso de llegada de la escalera.
local OXB, OZB = -84, -84
local function levelNav(body)
	local nav = buildNav(body, OXB, OZB, 168, 168)
	local sets = {}
	local starts = { [0] = { 0.5, 76.5, 0 }, [24] = { 73.5, 10.5, 24 }, [48] = { -73.5, -10.5, 48 } }
	for lvl, st in starts do
		local i, j, h = nav.startNear(st[1], st[2], st[3])
		sets[lvl] = h and nav.bfs(i, j, h, 1.6) or {}
		sets[lvl .. "ok"] = h ~= nil and math.abs(h - st[3]) < 0.06
	end
	return nav, sets
end
local nav35, sets35 = levelNav(3.5)
local function in35(lvl, x1, z1, x2, z2, h, tol) return nav35.countIn(sets35[lvl], x1, z1, x2, z2, h, tol) end
local s1_, s2_ = LAYOUT.s1, LAYOUT.s2
check("pasillos de 8: cuerpo de 7 studs entra por la puerta y recorre la pista", sets35["0ok"] and in35(0, D.x1 - 8, D.z1, D.x2 + 8, D.z2, 0.2) > 500)
check("pasillos de 8: llega al escenario y a la escalera 1 (piso 1)", in35(0, -10, St.z2 + 2, 10, St.z2 + 8, 0.2, 0.15) > 20 and in35(0, s1_.landIn[1] + 1, s1_.landIn[2] + 1, s1_.landIn[3] - 1, s1_.landIn[4] - 1, 0) > 10)
check("pasillos de 8 (piso 2): del descanso de llegada al pie de la escalera 2", sets35["24ok"] and in35(24, s2_.landIn[1] + 1, s2_.landIn[2] + 1, s2_.landIn[3] - 1, s2_.landIn[4] - 1, 24) > 10)
check("pasillos de 8 (piso 2): recorre el piso 2 (lounges y barras)", in35(24, -60, 30, 60, 70, 24) > 600, in35(24, -60, 30, 60, 70, 24))
check("pasillos de 8 (piso 3): del descanso de llegada a la barra y al DJ", sets35["48ok"] and in35(48, 40, -50, 76, -10, 48) > 30 and in35(48, -10, -62, 10, -50, rs and (rs.CFrame.py + rs.Size.Y / 2) or 50.2) >= 0, in35(48, 40, -50, 76, -10, 48))
local nav25, sets25 = levelNav(2.5)
local function in25(lvl, x1, z1, x2, z2, h) return nav25.countIn(sets25[lvl], x1, z1, x2, z2, h) end
check("pasillos de 6 (cuerpo de 5 studs): recorre pisos 1, 2 y 3", sets25["0ok"] and in25(0, -78, -78, 78, 78, 0) > 1500 and in25(24, -78, -78, 78, 78, 24) > 1500 and in25(48, -78, -78, 78, 78, 48) > 1500, in25(0, -78, -78, 78, 78, 0) .. "/" .. in25(24, -78, -78, 78, 78, 24) .. "/" .. in25(48, -78, -78, 78, 78, 48))

-- ================= PUNTOS DE INTERES: barras, VIP, rooftop =================
local function levelOf(y) return y > 40 and 48 or (y > 16 and 24 or 0) end
local function reachNear(part, m)
	local s, cf = part.Size, part.CFrame
	local lvl = levelOf(cf.py)
	return nav1.countIn(visited, cf.px - s.X / 2 - m, cf.pz - s.Z / 2 - m, cf.px + s.X / 2 + m, cf.pz + s.Z / 2 + m, lvl, 0.06)
end
for _, n in { "BarE_Top", "BarW_Top", "VIPBar_Top", "RoofBar_Top", "TicketDesk_Top" } do
	local p = find(n)
	check("acceso a pie junto a " .. n, p ~= nil and reachNear(p, 2.5) >= 8, p and reachNear(p, 2.5))
end

-- ================= ESCALERAS =================
local function stairCheck(label, s, nSteps)
	local steps = {}
	for _, c in colliders do
		if string.match(c.name, "^Stairs%d?_Step%d+$") and c.x1 >= s.x1 - 0.1 and c.x2 <= s.x2 + 0.1 and c.y2 > s.baseY - 0.1 and c.y2 <= s.baseY + 24.1 then
			table.insert(steps, c)
		end
	end
	table.sort(steps, function(a, b) return a.y2 < b.y2 end)
	local ok = #steps == nSteps
	for k, c in steps do
		if math.abs(c.y2 - (s.baseY + k)) > 0.06 then ok = false end
	end
	check(label .. ": 24 peldanos de 1 stud, 10 de ancho", ok and (steps[1].x2 - steps[1].x1) >= 9.9, #steps)
	-- altura libre >= 7 sobre cada peldano
	local minClear = 99
	for _, c in steps do
		for _, o in colliders do
			if o ~= c and not string.match(o.name, "^Stairs") and o.x1 < c.x2 - 0.5 and o.x2 > c.x1 + 0.5 and o.z1 < c.z2 and o.z2 > c.z1 and o.y1 >= c.y2 - 0.05 then
				minClear = math.min(minClear, o.y1 - c.y2)
			end
		end
	end
	check(label .. ": altura libre >= 7 studs sobre los peldanos", minClear >= 7, minClear)
end
stairCheck("escalera 1", LAYOUT.s1, 24)
stairCheck("escalera 2", LAYOUT.s2, 24)
local function rectClear(r, floorY)
	local bad
	for _, c in colliders do
		if c.x1 < r[3] and c.x2 > r[1] and c.z1 < r[4] and c.z2 > r[2] and c.y2 > floorY + 0.35 and c.y1 < floorY + 6 and not string.match(c.name, "^Landing") then
			bad = bad or c.name
		end
	end
	return bad
end
check("descanso de entrada escalera 1: libre de muebles", rectClear(LAYOUT.s1.landIn, 0) == nil, rectClear(LAYOUT.s1.landIn, 0))
check("descanso de llegada escalera 1 (piso 2): libre", rectClear(LAYOUT.s1.landOut, 24) == nil, rectClear(LAYOUT.s1.landOut, 24))
check("descanso de entrada escalera 2 (piso 2): libre", rectClear(LAYOUT.s2.landIn, 24) == nil, rectClear(LAYOUT.s2.landIn, 24))
check("descanso de llegada escalera 2 (piso 3): libre", rectClear(LAYOUT.s2.landOut, 48) == nil, rectClear(LAYOUT.s2.landOut, 48))

-- ================= SEPARACION DE MESAS Y LOUNGES =================
local function minDist(list)
	local m, who = math.huge, ""
	for i = 1, #list do
		for j = i + 1, #list do
			local d = math.sqrt((list[i].CFrame.px - list[j].CFrame.px) ^ 2 + (list[i].CFrame.pz - list[j].CFrame.pz) ^ 2)
			if d < m then m = d end
		end
	end
	return m
end
local lt = named("^LoungeTable%d+_Top$")
local ht = named("^HighTable%d+_Top$")
check("14 lounges VIP", #lt == 14, #lt)
check("8 mesas altas", #ht == 8, #ht)
local dLt, dHt = minDist(lt), minDist(ht)
print(string.format("        distancia minima entre lounges=%.1f, entre mesas altas=%.1f", dLt, dHt))
check("lounges separados >= 22 (grupos de 12 + pasillo >= 8 entre ellos)", dLt >= 22, dLt)
check("mesas altas separadas >= 12", dHt >= 12, dHt)

-- ================= PISTA LED =================
local tiles = named("^Tile$")
check("pista LED: baldosas del perfil (" .. TILE_COUNT .. " x " .. TILE_COUNT .. ") con juntas", #tiles == TILE_COUNT * TILE_COUNT and find("DanceBase") ~= nil, #tiles)
check("pista LED: bisel de 4 lados y 4 tiras LED", count("^DanceBezel%d$") == 4 and count("^DanceLed[NSEW]$") == 4)
local tileMaterialsOk, tMax = true, 0
for _, t in tiles do
	if t.Material ~= Enum.Material.SmoothPlastic and t.Material ~= Enum.Material.Glass then tileMaterialsOk = false end
	tMax = math.max(tMax, t.Color.R, t.Color.G, t.Color.B)
end
local lg = find("LedGlass")
check("pista LED: cristal superior translucido para reflejos", lg ~= nil and lg.Transparency >= 0.3 and lg.Transparency <= 0.9 and lg.CanCollide == false and lg.Reflectance > 0)
check("pista LED: baldosas no sobreexpuestas (canal max <= 0.85)", tMax <= 0.85, tMax)

-- ================= COCHES =================
local cars = {}
for _, b in named("^Car%d+_Body$") do
	table.insert(cars, tonumber(string.match(b.Name, "^Car(%d+)_")))
end
check("20 coches aparcados", #cars == 20, #cars)
local sil = { Hood = 0, Spoiler = 0, Wing = 0, Scoop = 0, Duckbill = 0, Fastback = 0, Grille = 0, Haunch = 0 }
check("3 siluetas: ferrari (Scoop/Haunch), GT (Wing/Duckbill) y mustang (Grille/Fastback)", count("_Haunch$") >= 14 and count("_Duckbill$") >= 6 and count("_Fastback$") >= 6 and count("_Grille$") >= 6)
check("cada coche con 4 neumaticos, llantas, bujes, parabrisas, faros y pilotos", count("^Car%d+_Tire$") == 80 and count("^Car%d+_Rim$") == 80 and count("^Car%d+_Hub$") == 80 and count("^Car%d+_Windshield$") == 20 and count("^Car%d+_Headlight$") == 40 and count("^Car%d+_Tail") >= 20)
local colorSeen, glassOk = {}, true
for _, d in named("^Car%d+_Body$") do
	local c = d.Color
	local k = (c.R > 0.6 and c.G < 0.3) and "rojo" or (c.B > 0.5 and c.R < 0.35) and "azul" or (c.R > 0.8 and c.G > 0.8 and c.B > 0.8) and "blanco" or (c.R < 0.15 and c.G < 0.15 and c.B < 0.18) and "negro" or "otro"
	colorSeen[k] = true
end
check("colores rojo, azul, blanco y negro presentes", colorSeen["rojo"] and colorSeen["azul"] and colorSeen["blanco"] and colorSeen["negro"], (function() local t = {} for k in colorSeen do table.insert(t, k) end return table.concat(t, ",") end)())
for _, d in named("^Car%d+_Windshield$") do
	if d.Transparency < 0.2 or d.Transparency > 0.8 then glassOk = false end
end
check("cristales con transparencia equilibrada (0.2-0.8)", glassOk)
-- caja de cada coche y ajuste en su plaza (plaza 10 x 20; margen >= 1 stud)
local carBox = {}
for _, p in parts do
	local n = tonumber(string.match(p.Name, "^Car(%d+)_"))
	if n then
		local b = carBox[n] or { x1 = math.huge, x2 = -math.huge, z1 = math.huge, z2 = -math.huge, y2 = -math.huge }
		local s, r = p.Size, p.CFrame.r
		local hx = (math.abs(r[1]) * s.X + math.abs(r[2]) * s.Y + math.abs(r[3]) * s.Z) / 2
		local hz = (math.abs(r[7]) * s.X + math.abs(r[8]) * s.Y + math.abs(r[9]) * s.Z) / 2
		local hy = (math.abs(r[4]) * s.X + math.abs(r[5]) * s.Y + math.abs(r[6]) * s.Z) / 2
		b.x1 = math.min(b.x1, p.CFrame.px - hx); b.x2 = math.max(b.x2, p.CFrame.px + hx)
		b.z1 = math.min(b.z1, p.CFrame.pz - hz); b.z2 = math.max(b.z2, p.CFrame.pz + hz)
		b.y2 = math.max(b.y2, p.CFrame.py + hy)
		carBox[n] = b
	end
end
local fitBad, overlapBad, accessBad, dims = nil, nil, nil, ""
for n, b in carBox do
	local cx = (b.x1 + b.x2) / 2
	local lo = cx < 0 and (-98 + 10 * math.floor((cx + 98) / 10)) or (8 + 10 * math.floor((cx - 8) / 10))
	local zlo, zhi = 128, 148
	if (b.z1 + b.z2) / 2 > 162 then zlo, zhi = 176, 196 end
	if b.x1 < lo + 0.7 or b.x2 > lo + 9.3 or b.z1 < zlo + 0.5 or b.z2 > zhi - 0.5 then
		fitBad = fitBad or string.format("Car%d x[%.1f,%.1f] z[%.1f,%.1f] plaza %d", n, b.x1, b.x2, b.z1, b.z2, lo)
	end
	for m, o in carBox do
		if m > n and b.x1 < o.x2 and b.x2 > o.x1 and b.z1 < o.z2 and b.z2 > o.z1 then overlapBad = overlapBad or (n .. "/" .. m) end
	end
	for _, a in { { -17, 129, -9, 147 }, { 9, 129, 17, 147 } } do
		if b.x1 < a[3] and b.x2 > a[1] and b.z1 < a[4] and b.z2 > a[2] then accessBad = accessBad or n end
	end
	if n == 1 then dims = string.format("%.1f x %.1f x %.1f", b.x2 - b.x1, b.z2 - b.z1, b.y2 + 0.24) end
end
check("cada coche (con espejos) cabe en su plaza de 10 x 20 con >= 0.7 de holgura lateral y 0.5 de fondo", fitBad == nil, fitBad)
check("los coches no se solapan entre si", overlapBad == nil, overlapBad)
check("las plazas accesibles estan libres de coches", accessBad == nil, accessBad)
local LOT_Y_T = -0.24
local minW, maxW, maxL = math.huge, 0, 0
for _, b in carBox do
	minW = math.min(minW, b.x2 - b.x1); maxW = math.max(maxW, b.x2 - b.x1); maxL = math.max(maxL, b.z2 - b.z1); assert(b.y2 - LOT_Y_T <= 4.6, "coche demasiado alto")
end
print(string.format("        coches: ancho %.1f..%.1f, largo max %.1f studs", minW, maxW, maxL))
local bw, bl = 0, 0
for _, d in named("^Car%d+_Body$") do bw = math.max(bw, d.Size.X); bl = math.max(bl, d.Size.Z) end
check("dimensiones realistas (carroceria 6-7.6 de ancho, 14-17 de largo, alto <= 4.5)", bw >= 6 and bw <= 7.6 and bl >= 14 and bl <= 17 and maxL <= 18)
local carCollidersOnly = true
for _, c in colliders do
	local n = string.match(c.name, "^Car%d+_(.+)$")
	if n and n ~= "Body" and n ~= "Cabin" then carCollidersOnly = false end
end
check("solo carroceria y cabina colisionan en los coches", carCollidersOnly)
-- circulacion: pasillos entre plazas y calle interior libres para cuerpos de 2 studs
check("parqueadero: calle interior transitable", nav1.countIn(visited, -60, 152, 60, 172, -0.24) >= 1500)
check("parqueadero: pasillos peatonales junto a plazas accesibles", nav1.countIn(visited, -8, 128, 8, 148, -0.24) >= 60 or flatIn(-3, 130, 3, 148, 0) >= 50)

-- ================= MUNDO EXTERIOR: PERIMETRO Y LIMITES =================
local function solidAt(x, y, z)
	for _, c in colliders do
		if x > c.x1 and x < c.x2 and y > c.y1 and y < c.y2 and z > c.z1 and z < c.z2 then return true end
	end
	return false
end
local gaps = 0
for t = W.x1 + 1, W.x2 - 1, 2 do
	for _, z in { W.z1 - 1, W.z2 + 1 } do
		if not (solidAt(t, 8, z) and solidAt(t, 60, z)) then gaps += 1 end
	end
end
for t = W.z1 + 1, W.z2 - 1, 2 do
	for _, x in { W.x1 - 1, W.x2 + 1 } do
		if not (solidAt(x, 8, t) and solidAt(x, 60, t)) then gaps += 1 end
	end
end
check("perimetro cerrado: muro + barrera invisible hasta y=70 sin huecos", gaps == 0, gaps)
local voids = 0
for x = W.x1 + 4, W.x2 - 4, 6 do
	for z = W.z1 + 4, W.z2 - 4, 6 do
		if #topsAt(x, z) == 0 then voids += 1 end
	end
end
check("sin vacio: suelo en todo el terreno jugable", voids == 0, voids)
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for i = 0, (W.x2 - W.x1) + 5 do
	for j = 0, (W.z2 - W.z1) + 5 do
		if #nav1.nodes[i][j] > 0 then
			for _, h in nav1.nodes[i][j] do
				if visited[nav1.key(i, j, h)] then
					local x, z = OX1 + i + 0.5, OZ1 + j + 0.5
					minX = math.min(minX, x); maxX = math.max(maxX, x); minZ = math.min(minZ, z); maxZ = math.max(maxZ, z)
				end
			end
		end
	end
end
print(string.format("        area alcanzable a pie: X %.1f..%.1f, Z %.1f..%.1f", minX, maxX, minZ, maxZ))
check("el jugador no sale del mapa", minX >= W.x1 and maxX <= W.x2 and minZ >= W.z1 and maxZ <= W.z2)
local outside
for _, p in parts do
	local s, cf = p.Size, p.CFrame
	if cf.px - s.X / 2 < W.x1 - 12 or cf.px + s.X / 2 > W.x2 + 12 or cf.pz - s.Z / 2 < W.z1 - 12 or cf.pz + s.Z / 2 > W.z2 + 12 then outside = outside or p.Name end
end
check("terreno ajustado: ninguna pieza fuera de 256 x 334 (+margen del muro)", outside == nil, outside)
check("senalizacion: pasos elevados, bordillos, lineas de detencion, eje discontinuo", count("^Crosswalk%a*_Slab$") + count("^LotCross_Slab$") == 5 and count("^Curb") >= 18 and count("^StopLine_") == 8 and count("^Dash_") >= 50)
check("plazas demarcadas: 40 lineas, 4 frontales, topes de rueda", count("^SlotLine$") == 40 and count("^SlotFront$") == 4 and count("^WheelStop$") >= 32)
check("2 plazas accesibles azules senalizadas", count("^Access[LR]$") == 2 and count("^AccessSign[LR]_Plate$") == 2)
local lampLights = 0
for _, d in club:GetDescendants() do
	if d:IsA("PointLight") and string.match(d.Parent.Name, "Head$") and string.match(d.Parent.Name, "Lamp") then lampLights += 1 end
end
check("farolas con luz real (>= 40)", lampLights >= 40, lampLights)
check("perimetro: 4 muros, pilares con neon y 4 barreras", count("^PerimeterWall_") == 4 and count("^Pillar[NSWE]$") >= 36 and count("^Boundary_") == 4)
check("jardineria: setos, arboles y jardineras", count("^Hedge[LR]$") >= 2 and count("Trunk$") >= 15 and count("^Planter") >= 10)

-- ================= EFECTOS, RENDIMIENTO =================
-- v2: TODA la animacion (luces, laseres, estrobo, pista, bola) es local en el cliente; el servidor no anima nada.
local beams = fx.beams
check("6 laseres creados", #beams == 6, #beams)
local mirrorN = count("^MirrorFacet$")
check("bola de espejos: facetas + nucleo", mirrorN > 100 and find("MirrorCore") ~= nil, mirrorN)
local screen = find("DJScreen")
check("pantalla LED con texto", screen ~= nil and #screen:GetChildren() > 0)
check("estrobos creados (>= 10)", #fx.strobes >= 10, #fx.strobes)
__countWrites = true
__writes = 0
for _ = 1, 10 * 30 do
	fireHeartbeat(1 / 30)
end
__countWrites = false
check("el servidor no anima nada: 0 escrituras de propiedades por segundo", __writes == 0, __writes)

-- piezas flotantes: toda parte visible debe tocar (+-0.08) a otra
local boxes = {}
for _, d in parts do
	if (d.Transparency or 0) < 1 and d.Parent.Name ~= "Effects" then
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

-- ================= LUZ: COBERTURA Y AJUSTES =================
local function lit(x, y, z)
	for _, l in lightsList do
		local dx, dy, dz = x - l.x, y - l.y, z - l.z
		if l.on and dy < 1 and (dx * dx + dy * dy + dz * dz) <= (0.75 * l.r) ^ 2 then return true end
	end
	return false
end
for _, lvl in { { 0.2, "piso 1" }, { 24, "piso 2" }, { 48, "piso 3" } } do
	local tot, okc = 0, 0
	for i = 0, (W.x2 - W.x1) + 5 do
		for j = 0, (W.z2 - W.z1) + 5 do
			local x, z = OX1 + i + 0.5, OZ1 + j + 0.5
			if math.abs(x) < 78 and math.abs(z) < 78 then
				for _, h in nav1.nodes[i][j] do
					if math.abs(h - lvl[1]) < 0.06 and visited[nav1.key(i, j, h)] then
						tot += 1
						if lit(x, h + 3, z) then okc += 1 end
					end
				end
			end
		end
	end
	check(string.format("cobertura de luz %s: %d/%d celdas (%.0f%%)", lvl[2], okc, tot, 100 * okc / math.max(1, tot)), tot > 0 and okc / tot >= 0.9)
end
local extTot, extOk = 0, 0
for i = 0, (W.x2 - W.x1) + 5, 2 do
	for j = 0, (W.z2 - W.z1) + 5, 2 do
		local x, z = OX1 + i + 0.5, OZ1 + j + 0.5
		if (math.abs(x) > 82 or z > 82 or z < -82) and x > W.x1 + 4 and x < W.x2 - 4 and z > W.z1 + 4 and z < W.z2 - 4 then
			for _, h in nav1.nodes[i][j] do
				if h < 1 and visited[nav1.key(i, j, h)] then
					extTot += 1
					if lit(x, h + 3, z) then extOk += 1 end
				end
			end
		end
	end
end
check(string.format("cobertura de luz exterior: %d/%d (%.0f%%)", extOk, extTot, 100 * extOk / math.max(1, extTot)), extTot > 0 and extOk / extTot >= 0.85)
local amb = __lighting.Ambient
check("ambiente base legible (luminancia media >= 0.15)", (amb.R + amb.G + amb.B) / 3 >= 0.15)

local beamLayers, shafts = {}, {}
for _, d in club:GetDescendants() do
	if d:IsA("Beam") and string.find(d.Name, "^LaserBeam") then
		table.insert(beamLayers, d)
	elseif d:IsA("Beam") and d.Name == "LightShaft" then
		table.insert(shafts, d)
	end
end
check("laseres: 6 haces x " .. PROFILE.laserLayers .. " capas de Beam (no son piezas solidas)", #beamLayers == 6 * PROFILE.laserLayers, #beamLayers)
local minCore, minMid, minHalo, endsOk = 1, 1, 1, true
local maxWidth, maxEmission = 0, 0
for _, b in beamLayers do
	local ks = b.Transparency.Keypoints
	if ks[1].Value ~= 1 or ks[#ks].Value ~= 1 then endsOk = false end
	local inner = 1
	for i = 2, #ks - 1 do inner = math.min(inner, ks[i].Value) end
	local layer = tonumber(string.match(b.Name, "(%d)$"))
	if layer == 1 then minCore = math.min(minCore, inner) elseif layer == 2 then minMid = math.min(minMid, inner) else minHalo = math.min(minHalo, inner) end
	maxWidth = math.max(maxWidth, b.Width0)
	maxEmission = math.max(maxEmission, b.LightEmission)
end
print(string.format("        haces: transparencia minima nucleo %.2f, media %.2f, halo %.2f; grosor max %.2f; emision max %.2f", minCore, minMid, minHalo, maxWidth, maxEmission))
check("laseres: transparencia nucleo >= 0.55, media >= 0.8, halo >= 0.9", minCore >= 0.55 and minMid >= 0.8 and minHalo >= 0.9)
check("laseres: degradado que se desvanece en origen y punta", endsOk)
check("laseres: grosor <= 1.2 studs y emision de luz <= 0.9", maxWidth <= 1.2 and maxEmission <= 0.9)
local shaftMin = 1
for _, b in shafts do
	for _, k in b.Transparency.Keypoints do
		if k.Value < 1 then shaftMin = math.min(shaftMin, k.Value) end
	end
end
check("conos de luz de focos (12 / " .. PROFILE.shaftEvery .. ") con transparencia >= 0.88", #shafts == 12 // PROFILE.shaftEvery and shaftMin >= 0.88, #shafts .. "/" .. shaftMin)
local bloom = __lighting:FindFirstChild("AlfombraBloom")
check("bloom moderado (intensidad <= 0.6, tamano <= 24, umbral >= 0.9)", bloom ~= nil and bloom.Intensity <= 0.6 and bloom.Size <= 24 and bloom.Threshold >= 0.9)
local shadowLights, strobeMax = 0, 0
for _, d in club:GetDescendants() do
	if d:IsA("SpotLight") and d.Shadows == true then shadowLights += 1 end
end
for _, st in fx.strobes do strobeMax = math.max(strobeMax, st.light.Brightness) end
check("sombras solo en " .. PROFILE.shadowLights .. " luces clave (limite del perfil)", shadowLights == PROFILE.shadowLights, shadowLights)
check("estrobos con brillo moderado (<= 4)", strobeMax <= 4, strobeMax)
local lookOk = true
for _, k in { "LightIntensity", "AmbientBoost", "Exposure", "Bloom", "BeamTransparency", "BeamBrightness", "BeamWidth", "ShaftTransparency", "TileBrightness", "KeyShadows", "Reflections", "ShadowSoftness" } do
	if LOOK[k] == nil then lookOk = false end
end
check("ajustes CONFIG.Look expuestos (12 parametros)", lookOk)


-- ================= ESTILO LUXURY: espejos, mobiliario, neon e iluminacion =================
local function sat(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	return mx > 0 and (mx - mn) / mx or 0, mx
end
do
local facets = named("^MirrorFacet$")
local allMirror, tones, maxRefl, maxColor = true, {}, 0, 0
for _, f in facets do
	if f.Material ~= Enum.Material.Metal then allMirror = false end
	maxRefl = math.max(maxRefl, f.Reflectance)
	maxColor = math.max(maxColor, f.Color.R, f.Color.G, f.Color.B)
	tones[string.format("%.2f", f.Color.R)] = true
end
local nTones = 0
for _ in tones do nTones += 1 end
check("espejo: facetas Metal, dos tonos de plata alternos, reflectancia <= 0.9 y color <= 0.95 (sin reflejos quemados)", allMirror and maxRefl <= 0.9 and maxRefl >= 0.7 and maxColor <= 0.95 and nTones == 2, nTones .. "/" .. maxRefl .. "/" .. maxColor)
local core = find("MirrorCore")
check("espejo: nucleo oscuro, casquete cromado y varilla", core ~= nil and core.Color.R < 0.15 and find("MirrorMotor") ~= nil and find("MirrorRod") ~= nil)
local spots, spotMax = 0, 0
for _, n in named("^MirrorSpotCan$") do
	for _, c in n:GetChildren() do if c:IsA("SpotLight") then spots += 1 spotMax = math.max(spotMax, c.Brightness) end end
end
check("espejo: 2 focos de acento suaves (brillo <= 2) sobre la bola", spots == 2 and spotMax <= 2, spots .. "/" .. spotMax)
local coreLight = core and core:FindFirstChildOfClass("PointLight")
check("espejo: luz interior suave (<= 1.2)", coreLight ~= nil and coreLight.Brightness <= 1.2)
-- ninguna faceta metida en el nucleo: todas las esquinas de su cara interior a >= radio del nucleo
local c0 = core.CFrame.Position
local inside, minD, maxD = 0, math.huge, 0
for _, f in facets do
	local sx, sy, sz = f.Size.X / 2, f.Size.Y / 2, f.Size.Z / 2
	for _, cx in { -sx, sx } do
		for _, cy in { -sy, sy } do
			local pt = f.CFrame * Vector3.new(cx, cy, sz) -- cara trasera (+Z local = hacia el nucleo)
			local d = (pt - c0).Magnitude
			minD = math.min(minD, d); maxD = math.max(maxD, d)
			if d < core.Size.X / 2 - 0.001 then inside += 1 end
		end
	end
end
print(string.format("        espejo: %d facetas, esquinas interiores a %.3f..%.3f del centro (nucleo r=%.2f)", #facets, minD, maxD, core.Size.X / 2))
check("espejo: ninguna faceta metida en el nucleo", inside == 0 and #facets > 0, inside)
local mirrorMin, mirrorMax = PROFILE_NAME == "Alta" and 200 or 110, PROFILE_NAME == "Alta" and 320 or 190
check(string.format("espejo: numero de facetas del perfil (%d-%d)", mirrorMin, mirrorMax), #facets >= mirrorMin and #facets <= mirrorMax, #facets)
end

do
-- mobiliario en blanco y negro, brillante
local badFurn, nFurn = nil, 0
local function furniture(pat)
	for _, d in named(pat) do
		nFurn += 1
		local sa, v = sat(d.Color)
		local polished = d.Reflectance >= 0.15 or d.Material == Enum.Material.Metal or d.Material == Enum.Material.Marble
		if (sa > 0.14 and v > 0.25) or not (v < 0.25 or v > 0.78 or d.Material == Enum.Material.Metal) or not polished then
			badFurn = badFurn or string.format("%s sat=%.2f v=%.2f refl=%.2f", d.Name, sa, v, d.Reflectance)
		end
	end
end
for _, pat in { "Sofa[%a]*%d*_Seat$", "Sofa[%a]*%d*_Back$", "Booth[EW]%d*_Seat$", "^LoungeTable%d+_Top$", "^HighTable%d+_Top$", "^BoothTable[EW]%d*_Top$", "Stool%d+_Seat$", "^Bar[EW]_Top$", "^Bar[EW]_Body$", "^VIPBar_Top$", "^RoofBar_Top$", "Lounger[EW]%d+_Base$" } do
	furniture(pat)
end
print("        muebles revisados: " .. nFurn)
check("mobiliario en blanco y negro (saturacion <= 0.14) y pulido (reflectancia/marmol/metal)", badFurn == nil and nFurn >= 90, badFurn or nFurn)
local whites, blacks = 0, 0
for _, d in named("Sofa[%a]*%d*_Seat$") do
	local _, v = sat(d.Color)
	if v > 0.78 then whites += 1 elseif v < 0.25 then blacks += 1 end
end
check("sofas en ambos tonos: blancos y negros", whites >= 6 and blacks >= 6, whites .. "/" .. blacks)

-- menos neon: todos los neones animados/acentos son suaves y escasos
local neonN, neonBright, worstNeon = 0, 0, nil
local skip = "Pumpkin[%w]*_|Flame|Eye|Mouth|Smile|Bulb|Bubble|Liquid|Taillight|Headlight|FogLight|Candle|Coaster|Slice|Tray|Landing|Door[AL]|Garland|Cauldron|Bat%d|Edge|Cyan|Strobe|^Tile$|Lip"
for _, d in parts do
	if d.Material == Enum.Material.Neon then
		local skipIt = false
		for pat in string.gmatch(skip, "[^|]+") do
			if string.find(d.Name, pat) then skipIt = true break end
		end
		if game:GetService("CollectionService"):HasTag(d, "AR_Glow") then skipIt = true end -- su color lo fija el cliente segun la paleta
		if not skipIt then
			neonN += 1
			local sa, v = sat(d.Color)
			if sa > 0.6 and v > 0.5 then worstNeon = worstNeon or (d.Name .. string.format(" sat=%.2f", sa)) end
		end
	end
end
print("        piezas de neon (sin Halloween/coches/identidad): " .. neonN)
check("neon contenido: sin colores saturados y <= 260 piezas (sin baldosas ni peldanos)", worstNeon == nil and neonN <= 260, worstNeon or neonN)
local ice, rest = 0, 0
local function hueCheck(t)
	local c = t
	return sat(c) < 0.5
end
local lampsBad
for _, l in fx.lamps do
	if not hueCheck(l.light.Color) then lampsBad = true end
end
check("luces de relleno blancas/calidas (sin tintes saturados)", not lampsBad)
local cc = game:GetService("Lighting"):FindFirstChildOfClass("ColorCorrectionEffect")
check("correccion de color elegante (saturacion <= 0, tinte calido)", cc ~= nil and cc.Saturation <= 0 and cc.TintColor.R >= cc.TintColor.B)
local ambS = sat(__lighting.Ambient)
check("ambiente casi neutro (saturacion <= 0.2)", ambS <= 0.2, ambS)
local floor1 = find("Floor1_Slab")
check("suelo de marmol negro pulido (Reflectance >= 0.2)", floor1 ~= nil and floor1.Material == Enum.Material.Marble and floor1.Reflectance >= 0.2)
end

-- ================= ZONA LA ALFOMBRA ROJA, CABINA DE LUCES Y SEGURIDAD =================
do
	local noCoat = count("^Coat") == 0
	for _, d in club:GetDescendants() do
		if d:IsA("TextLabel") and string.find(string.upper(d.Text), "GUARDARROPA") then noCoat = false end
	end
	check("el guardarropa ha desaparecido (sin piezas ni rotulos)", noCoat)
	local carpet = find("RedCarpet")
	check("alfombra roja amplia (16 de ancho x 71 de largo) con filetes dorados", carpet ~= nil and carpet.Size.Z >= 16 and carpet.Size.X >= 70 and carpet.Color.R > 0.55 and carpet.Color.G < 0.2 and carpet.Material == Enum.Material.Fabric and carpet.CanCollide == false and count("^CarpetEdge%d$") == 2)
	local central = find("Carpet")
	check("el pasillo de entrada tambien es alfombra roja", central ~= nil and central.Color.R > 0.55 and central.Color.G < 0.2)
	check("14 postes dorados con 12 cordones rojos que cuelgan", count("^Stanchion_Pole$") == 14 and count("^Stanchion_Base$") == 14 and count("^Stanchion_Top$") == 14 and count("^Cordon_RopeA$") == 12 and count("^Cordon_RopeB$") == 12)
	local pole, rope = find("Stanchion_Pole"), find("Cordon_RopeA")
	check("postes dorados (Metal) y cordones rojos sin colision", pole ~= nil and pole.Color.R > 0.8 and pole.Color.B < 0.5 and pole.Material == Enum.Material.Metal and rope.Color.R > 0.55 and rope.Color.G < 0.2 and rope.CanCollide == false)
	local panel = find("PhotocallPanel")
	check("photocall: panel negro con marco dorado (4 piezas) contra la pared", panel ~= nil and panel.Color.R < 0.1 and panel.Size.Z >= 20 and panel.Size.Y >= 13 and count("^PhotocallFrame[TLR]$") == 3 and find("PhotocallPlinth") ~= nil)
	check("photocall: logo grande + 6 pequenos repetidos", count("^PhotocallLogo_Plate$") == 1 and count("^PhotocallMini%d+_Plate$") == 6 and count("^PhotocallLogo_CrownBand$") == 1 and count("^PhotocallMini%d+_CrownBand$") == 6)
	local soft = {}
	for _, n in named("^Softbox[NS]_Diffuser$") do
		local l = n:FindFirstChildOfClass("SpotLight")
		table.insert(soft, { part = n, light = l })
	end
	local softOk = #soft == 2
	for _, sbx in soft do
		if not (sbx.light and sbx.light.Face == Enum.NormalId.Front and sbx.light.Brightness <= 2 and sbx.part.Color.R > 0.85) then softOk = false end
	end
	check("2 luces de fotografia tipo softbox (difusor blanco, foco calido suave, tripode y aro dorado)", softOk and count("^Softbox[NS]_Pole$") == 2 and count("^Softbox[NS]_Leg%d$") == 6 and count("^Softbox[NS]_Rim$") == 2)
	check("camara de video, 2 palmeras doradas y 2 mesas de champan con cubo, botella y velas", count("^VideoCam_Body$") == 1 and count("^CarpetPalm[NS]_Planter$") == 2 and count("^CarpetBucket%-?%d+$") == 2 and count("^CarpetBottle%-?%d+$") == 2 and count("^CarpetCandle%-?%d+_Candle1$") == 2)
	check("rotulo de bienvenida en la pared", find("CarpetSign") ~= nil)
	-- cabina de luces
	local top, base = find("LightDesk_Top"), find("LightDesk_Base")
	check("cabina de luces: consola negra con filete dorado, 8 faders con mandos dorados y 3 pantallas", top ~= nil and base ~= nil and base.Color.R < 0.12 and count("^LightDesk_Trim[FLR]$") == 3 and count("^LightDesk_Slot%d$") == 8 and count("^LightDesk_Knob%d$") == 8 and count("^LightDesk_Screen%d$") == 3 and find("LightDeskSign") ~= nil and find("ControlStatusLabel") ~= nil)
	local knob = find("LightDesk_Knob1")
	check("cabina: mandos y filetes en dorado pulido", knob.Color.R > 0.8 and knob.Color.B < 0.5 and knob.Material == Enum.Material.Metal)
	local cp = top.CFrame.Position
	check("cabina junto al DJ, sobre el escenario y con vista a la pista", cp.Z < LAYOUT.stage.z2 and cp.Z > LAYOUT.stage.z1 and cp.X > LAYOUT.stage.x1 and cp.X < -8 and math.abs(cp.X) > 8 and cp.Y > LAYOUT.stage.top)
	check("cabina accesible a pie (frente al escritorio, cuerpo de 2) y por el lado del operador", nav1.countIn(visited, cp.X - 6, cp.Z + 1.5, cp.X + 6, cp.Z + 5, LAYOUT.stage.top) >= 20 and nav1.countIn(visited, cp.X - 6, cp.Z - 4, cp.X + 6, cp.Z - 1.8, LAYOUT.stage.top) >= 8)
	-- circulacion alrededor de la alfombra y la cabina
	check("alfombra transitable para cuerpos de 7 studs desde la puerta", in35(0, -72, 58, -14, 70, 0) > 150, in35(0, -72, 58, -14, 70, 0))
	check("alfombra transitable con cuerpo de 2 hasta el photocall", reachedIn(-74, 58, -70, 70, 0) > 30)
	check("entre las mesas altas y la alfombra quedan >= 8 studs libres para cuerpos de 7", in35(0, -70, 42, -30, 47, 0) > 20, in35(0, -70, 42, -30, 47, 0))
	-- luces de seguridad: solo con ellas los pasillos, pisos y escaleras quedan cubiertos
	local safeLights = {}
	for _, d in club:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") then
			local pn = d.Parent.Name
			for _, pat in { "^Fill", "HallStrip", "^Door_", "Stair", "Landing", "CarpetFill", "LightDeskFill" } do
				if string.find(pn, pat) then
					table.insert(safeLights, { x = d.Parent.CFrame.px, y = d.Parent.CFrame.py, z = d.Parent.CFrame.pz, r = d.Range })
					break
				end
			end
		end
	end
	local function litSafe(x, y, z)
		for _, l in safeLights do
			local dx, dy, dz = x - l.x, y - l.y, z - l.z
			if dy < 1 and (dx * dx + dy * dy + dz * dz) <= (0.75 * l.r) ^ 2 then return true end
		end
		return false
	end
	for _, lvl in { { 0.2, "piso 1" }, { 24, "piso 2" }, { 48, "piso 3" } } do
		local tot, okc = 0, 0
		for i = 0, (W.x2 - W.x1) + 5 do
			for j = 0, (W.z2 - W.z1) + 5 do
				local x, z = OX1 + i + 0.5, OZ1 + j + 0.5
				if math.abs(x) < 78 and math.abs(z) < 78 then
					for _, h in nav1.nodes[i][j] do
						if math.abs(h - lvl[1]) < 0.06 and visited[nav1.key(i, j, h)] then
							tot += 1
							if litSafe(x, h + 3, z) then okc += 1 end
						end
					end
				end
			end
		end
		check(string.format("solo con las luces de seguridad (todo lo demas apagado) %s queda cubierto: %.0f%%", lvl[2], 100 * okc / math.max(1, tot)), tot > 0 and okc / tot >= 0.9)
	end
	local stTot, stOk = 0, 0
	for i = 0, (W.x2 - W.x1) + 5 do
		for j = 0, (W.z2 - W.z1) + 5 do
			local x, z = OX1 + i + 0.5, OZ1 + j + 0.5
			if (math.abs(x) > 67 and math.abs(x) < 79) and math.abs(z) < 66 then
				for _, h in nav1.nodes[i][j] do
					if h > 0.5 and h < 47 and visited[nav1.key(i, j, h)] and math.abs(h - 24) > 0.06 then
						stTot += 1
						if litSafe(x, h + 3, z) then stOk += 1 end
					end
				end
			end
		end
	end
	check(string.format("escaleras: %d/%d celdas de peldano iluminadas solo con luces de seguridad", stOk, stTot), stTot > 100 and stOk / stTot >= 0.9)
end

-- ================= CRISTALERIA Y HALLOWEEN =================
local rims = named("Glass%d+_Rim$")
local shotRims = named("Shot%d+_Rim$")
check("vasos de cristal con borde en las 4 barras (>= 20) y 12 chupitos", #rims >= 20 and #shotRims == 12, #rims .. "/" .. #shotRims)
check("vasos: pared translucida, liquido, hielo y posavasos", count("Glass%d+_Wall") >= 20 and count("Glass%d+_Liquid") >= 20 and count("_Ice%d+$") >= 20 and count("_Coaster$") >= 20)
local blocking
for _, c in colliders do
	if string.match(c.name, "Glass%d+_") or string.match(c.name, "Shot%d+_") then blocking = blocking or c.name end
end
check("la cristaleria no colisiona", blocking == nil, blocking)
check("calabazas con cara (>= 20)", count("Pumpkin%d*_EyeL$") >= 20, count("Pumpkin%d*_EyeL$"))
check("velas con llama (>= 12 racimos)", count("Candle%d*_Candle1$") >= 12, count("Candle%d*_Candle1$"))
check("telaranas (>= 7)", count("Web%u?%d*_R0$") >= 7, count("Web%u?%d*_R0$"))
check("murcielagos (>= 14)", count("Bat%d+_Body$") >= 14, count("Bat%d+_Body$"))
check("guirnaldas y calderos", count("Garland_Bulb0$") >= 3 and count("Cauldron_Pot$") >= 3)
check("luces de llama con parpadeo (>= 15, o ninguna si el perfil las recorta)", #fx.flames >= (PROFILE.pruneMinor and 0 or 15), #fx.flames)

print(string.format("\nRESULTADO: %d fallo(s)", failures))
if failures > 0 then
	error("hay tests fallando")
end

end
__world()
