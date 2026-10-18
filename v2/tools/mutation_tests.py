#!/usr/bin/env python3
"""Pruebas de sabotaje: rompe adrede una regla clave en una COPIA temporal de los fuentes y comprueba que las
pruebas la detectan (si no fallase ninguna, la prueba seria inutil). Restaura siempre el original.
Uso: mutation_tests.py   (necesita luau en LUAU o en la ruta indicada por la variable de entorno LUAU)."""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = os.environ.get("LUAU", "luau")
SRC = ROOT / "src"
SS = "ServerScriptService/LaAlfombraRoja/"
CL = "StarterPlayer/StarterPlayerScripts/LaAlfombraRojaClient/"
SH = "ReplicatedStorage/AlfombraShared/"

MUTATIONS = [
    ("recibo: devuelve PurchaseGranted aunque falle el guardado", SS + "Purchases.luau", 'if status == "granted" or status == "duplicate" then', "if true then", "server"),
    ("recibo: no es idempotente (ignora PurchaseId repetido)", SS + "Inventory.luau", "if old.receipts[purchaseId] then\n\t\t\t\tdup = true", "if false then\n\t\t\t\tdup = true", "server"),
    ("PromptProductPurchaseFinished concede la compra", SS + "Purchases.luau", "if player and not isPurchased then\n\t\t\tpending[player] = nil", "if player and isPurchased then\n\t\t\tInventory.grant(player, Catalog.productForTier('bottle').Grant, 'X' .. os.clock())\n\t\t\tpending[player] = nil", "server"),
    ("tienda: no exige estar junto a un bartender", SS + "Purchases.luau", "if not nearShop(player) then", "if false then", "server"),
    ("musica: acepta cualquier id (sin lista blanca)", SS + "Music.luau", 'local id = type(t) == "table" and Util.normalizeAssetId(t.Id) or ""', 'local id = type(t) == "table" and tostring(t.Id) or ""', "server"),
    ("cabina: cualquiera puede operar", SS + "Control.luau", "if Control.op.player ~= player then", "if false then", "server"),
    ("guardias: credencial sin estar cerca", SS + "Interactions.luau", "function Interactions.presentCredential(player, claimedId)\n\tif not nearGuard(player) then", "function Interactions.presentCredential(player, claimedId)\n\tif false then", "server"),
    ("baile: no se corta al andar", SS + "Interactions.luau", "if speed > 3 then", "if speed > 1e9 then", "server"),
    ("lease: escribe sin comprobar que el alquiler es suyo", SS + "Inventory.luau", 'if not owns(old, s) then\n\t\t\t\tlost = true\n\t\t\t\tinfo = "lost"', 'if false then\n\t\t\t\tlost = true\n\t\t\t\tinfo = "lost"', "persist"),
    ("lease: carga aunque otro servidor tenga el alquiler vivo", SS + "Inventory.luau", "lk.o ~= s.token and (tonumber(lk.e) or 0) > os.time()", "false", "persist"),
    ("lease: al salir no se libera el alquiler", SS + "Inventory.luau", "snapshot.lock = nil\n\t\t\treturn snapshot", "snapshot.lock = old.lock\n\t\t\treturn snapshot", "persist"),
    ("lease: no se renueva mientras el jugador esta", SS + "Inventory.luau", "local renewDue = now - s.lastRenew >= Config.Data.RenewSeconds", "local renewDue = false", "persist"),
    ("focos: el haz puede salir de la pista (sin limites)", CL + "FollowLights.luau", "return Vector3.new(math.clamp(x, h.x1, h.x2), h.y, math.clamp(z, h.z1, h.z2))", "return Vector3.new(x, h.y, z)", "client"),
    ("focos: encendidos por defecto", SS + "Control.luau", "	Follow = false, -- focos rojos de seguimiento (apagados de inicio)", "	Follow = true,", "server"),
    ("presets: no restablecen zonas/focos del preset anterior", SS + "Control.luau", "		for k, v in Control.PRESET_BASE do\n			Control.set(k, v)\n		end\n", "", "server"),
    ("focos con sombras (coste de render)", SS + "Extras.luau", "light.Enabled = false\n\t\thead:SetAttribute(\"b\"", "light.Enabled = false\n\t\tlight.Shadows = true\n\t\thead:SetAttribute(\"b\"", "world"),
    ("oscuridad sin minimo (ambiente puede llegar a negro)", CL + "Mood.luau", "local MIN_KEEP = 0.3", "local MIN_KEEP = 0", "client"),
    ("focos siguen a quien esta fuera de la pista", CL + "FollowLights.luau", "if p.X >= h.x1 - F.Inset and p.X <= h.x2 + F.Inset and p.Z >= h.z1 - F.Inset and p.Z <= h.z2 + F.Inset and p.Y < 8 then", "if true then", "client"),
    ("persistencia: GetDataStore fuera de pcall (aborta si falla)", SS + "Inventory.luau", "local ok, res = pcall(function()\n\t\treturn DataStoreService:GetDataStore(storeName)\n\tend)", "local ok, res = true, DataStoreService:GetDataStore(storeName)", "nostore"),
    ("recibo confirmado sin persistencia real (memoria)", SS + "Purchases.luau", 'if Inventory.persistence() ~= "datastore" then\n\t\t\twarn("[Purchases] recibo', 'if false then\n\t\t\twarn("[Purchases] recibo', "studiotemp"),
    ("modo Studio temporal activo fuera de Studio", SS + "Inventory.luau", "		if isStudio() then\n			store = newMemoryStore()", "		if true then\n			store = newMemoryStore()", "studiotemp_prod"),
    ("cliente: un error en un modulo detiene a los demas (focos incluidos)", CL + "init.client.luau", "local ok, err = pcall(fn, ...)\n\tif not ok and not failedOnce[name] then", "local ok, err = true, fn(...)\n\tif not ok and not failedOnce[name] then", "client"),
    ("oscuridad: las luces de acceso tambien se atenuan", CL + "Effects.luau", "local floor_ = (acc == false) and SAFE_MIN * (1 - 0.5 * math.clamp(S.Dark or 0, 0, 1)) or SAFE_MIN", "local floor_ = SAFE_MIN * (1 - 0.5 * math.clamp(S.Dark or 0, 0, 1))", "client"),
    ("exposicion alta otra vez (sobreexposicion)", SH + "Config.luau", "Exposure = -0.15,", "Exposure = 0.5,", "world"),
    ("baile: ignora AnimationConstraint (solo Motor6D, el bug real de Studio)", SH + "DancePoses.luau", 'local kind = j:IsA("AnimationConstraint") and "constraint" or "motor"', 'local kind = "motor"', "client"),
    ("baile: al parar no restaura Transform de AnimationConstraint", SH + "DancePoses.luau", "				j.inst.Transform = IDENT\n				j.last = nil", "				j.last = nil", "client"),
    ("baile: solo reconoce Motor6D al buscar articulaciones", SH + "DancePoses.luau", 'return d:IsA("Motor6D") or d:IsA("AnimationConstraint")', 'return d:IsA("Motor6D")', "client"),
    ("libro: purga el recibo mas antiguo al llenarse (bug original)", SS + "Inventory.luau", '	if n >= Config.Data.MaxReceipts then\n		return false, "ledger_full"\n	end\n	data.receipts[id] = os.time()', '	if n >= Config.Data.MaxReceipts then\n		for k in data.receipts do\n			data.receipts[k] = nil\n			break\n		end\n	end\n	data.receipts[id] = os.time()', "ledger"),
    ("libro: tope antiguo de 300 recibos", SH + "Config.luau", "MaxReceipts = 20000,", "MaxReceipts = 300,", "ledger"),
    ("libro lleno: se siguen ofreciendo cobros nuevos", SS + "Inventory.luau", '		return false, "ledger_full"\n	end\n	return true\nend', '		return true\n	end\n	return true\nend', "ledger"),
    ("recibos de prueba Studio contaminan el libro pagado", SS + "Purchases.luau", "Inventory.grant(player, product.Grant, nil, { test = true })", 'Inventory.grant(player, product.Grant, "STUDIO-" .. player.UserId .. "-" .. os.clock())', "ledger"),
    ("Studio usa el DataStore de produccion", SS + "Inventory.luau", "local storeName = isStudio() and Config.Data.StudioStoreName or Config.Data.StoreName", "local storeName = Config.Data.StoreName", "ledger"),
    ("PurchaseId enorme admitido (sin fallo cerrado)", SS + "Inventory.luau", '#id > Config.Data.MaxReceiptIdLength then', 'false then', "ledger"),
    ("asientos: Stand no hace nada en el servidor", SS + "Interactions.luau", "function Interactions.stand(player)\n	local hrp, hum = hrpOf(player)", "function Interactions.stand(player)\n	if true then return false end\n	local hrp, hum = hrpOf(player)", "seats"),
    ("asientos: Stand no destruye la soldadura (jugador sigue pegado)", SS + "Interactions.luau", "		weld:Destroy() -- un Seat solo", "		local _ = weld -- un Seat solo", "seats"),
    ("asientos: sin cooldown tras levantarse", SS + "Interactions.luau", "if now - (standAt[player] or -100) < Config.Seats.StandCooldown then", "if false then", "seats"),
    ("asientos: sin cooldown del mismo asiento", SS + "Interactions.luau", "if last and last.seat == seat and now - (last.t or -100) < Config.Seats.SameSeatCooldown then", "if false then", "seats"),
    ("asientos: Stand acepta asientos que no son del club", SS + "Interactions.luau", "if not seat or not seatSet[seat] or seat.Occupant ~= hum then", "if not seat or seat.Occupant ~= hum then", "seats"),
    ("asientos: sin anti-parpadeo sentar-levantar", SS + "Interactions.luau", "if now - (lastSeatOf[player] and lastSeatOf[player].t or -100) < Config.Seats.StandMinInterval then", "if false then", "seats"),
    ("asientos: la tecla de salto no pide Stand", CL + "init.client.luau", "game:GetService(\"UserInputService\").JumpRequest:Connect(requestStand)", "game:GetService(\"UserInputService\").JumpRequest:Connect(function() end)", "client"),
    ("asientos: sin limite de peticiones Stand en el cliente", CL + "init.client.luau", "if now - lastStand < 0.4 then", "if false then", "client"),
    ("pantallas NowPlaying hacia la pared (negras desde la pista)", SS + "Extras.luau", "		gui.Face = Enum.NormalId.Back", "		gui.Face = Enum.NormalId.Front", "world"),
    ("monitor del DJ invertido hacia el publico", SS + "Extras.luau", "CFrame.lookAt(Vector3.new(cx, yT + 2.5, z + 0.95), Vector3.new(cx, yT + 2.5, z - 3))", "CFrame.lookAt(Vector3.new(cx, yT + 2.5, z + 0.95), Vector3.new(cx, yT + 2.5, z + 6))", "world"),
    ("VIP: el cristal deja de colisionar", SH + "VipUpgrade.luau", "			CanCollide = true, -- UNICO colisionable del cierre", "			CanCollide = false,", "vip"),
    ("VIP: transparencia GLOBAL en vez de local", SH + "VipUpgrade.luau", "part.LocalTransparencyModifier = clear and G.ClearTransparency or 0", "part.Transparency = clear and G.ClearTransparency or 0", "vip"),
    ("VIP: sin histeresis (parpadeo en el plano)", SH + "VipUpgrade.luau", "clear = s > -G.Hysteresis", "clear = s > 0", "vip"),
    ("VIP: aros con sombras", SH + "VipUpgrade.luau", "light.Shadows = false -- NUNCA sombras extra", "light.Shadows = true", "vip"),
    ("VIP: aros colisionables (bloquean camara/circulacion)", SH + "VipUpgrade.luau", "			CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.55,", "			CanCollide = true, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.55,", "vip"),
    ("VIP: normal del lado claro invertida (transparente desde la pista)", SH + "VipUpgrade.luau", "nx = 0, nz = -1 })\n	table.insert(walls, { name = \"S\"", "nx = 0, nz = 1 })\n	table.insert(walls, { name = \"S\"", "vip"),
    ("VIP: llamas siempre encendidas (sin culling por distancia)", SH + "VipUpgrade.luau", "local on = d <= info.cull", "local on = true", "vip"),
    ("VIP: el aro no se omite aunque choque", SH + "VipUpgrade.luau", "				if hit then\n					why = \"choca con \" .. tostring(who and who.Name)\n				end", "", "vip"),
    ("VIP: llamas solo en parte del perimetro", SH + "VipUpgrade.luau", "local flameEvery = math.max(1, math.floor(N / profile.flames))", "local flameEvery = 2", "vip"),
    ("VIP: tensores verticales (no convergen al techo)", SH + "VipUpgrade.luau", "CFrame.lookAt((from + apex) / 2, apex), Vector3.new(0.1, 0.1, len)", "CFrame.lookAt((from + Vector3.new(from.X, top, from.Z)) / 2, Vector3.new(from.X, top, from.Z)), Vector3.new(0.1, 0.1, top - from.Y)", "vip"),
    ("VIP: todos los aros del mismo diametro", SH + "VipUpgrade.luau", "return R.Radii[(idx - 1) % #R.Radii + 1], R.Heights[(idx - 1) % #R.Heights + 1]", "return R.Radii[1], R.Heights[1]", "vip"),
    ("VIP: el marco decorativo colisiona", SH + "VipUpgrade.luau", "			CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.25,", "			CanCollide = true, CanTouch = false, CanQuery = false, CastShadow = false, Reflectance = 0.25,", "vip"),
    ("VIP: sin montantes ni cornisa", SH + "VipUpgrade.luau", "if fr.Enabled and not string.find(w.name, \"^X\") then", "if false then", "vip"),
    ("ClubSpawn visible", SS + "Build.luau", "ClubSpawn", "ClubSpawnX", "world"),
    ("cliente: sin limite de frecuencia en la tienda", CL + "ShopUi.luau", "if now - lastSend < 0.15 then", "if false then", "client"),
    ("cliente: precio borrador mostrado como real", CL + "ShopUi.luau", 'buy.Text = "Compra con Robux no disponible"\n\t\t\t\tpriceL.Text = "Precio pendiente (producto sin enlazar)."', 'buy.Text = "Comprar con Robux (400)"\n\t\t\t\tpriceL.Text = "400 R$"', "client"),
    ("cliente: el baile no respeta la distancia maxima", CL + "Dance.luau", "if dist <= Config.Dance.MaxAnimateDistance then", "if true then", "client"),
    ("cliente: NPC animados a cualquier distancia", CL + "Npcs.luau", "if d <= maxD then", "if true then", "client"),
]


def run_suite(suite):
    args = [sys.executable, str(ROOT / "tools/assemble_tests.py"), str(ROOT / f"tests/t_{suite}.luau"), f"/tmp/mut_{suite}.luau"]
    subprocess.run(args, check=True, capture_output=True)
    r = subprocess.run([LUAU, f"/tmp/mut_{suite}.luau"], capture_output=True, text=True)
    out = r.stdout + r.stderr
    return r.returncode != 0 or "  FAIL" in out


def main():
    bad = 0
    for name, rel, old, new, suite in MUTATIONS:
        p = SRC / rel
        orig = p.read_text(encoding="utf-8")
        if old not in orig:
            print(f"  ??    {name}: no encuentro el texto a sabotear")
            bad += 1
            continue
        try:
            p.write_text(orig.replace(old, new, 1), encoding="utf-8")
            caught = run_suite(suite)
        finally:
            p.write_text(orig, encoding="utf-8")
        print(("  DETECTADO  " if caught else "  NO DETECTADO  ") + name + f"  [{suite}]")
        bad += 0 if caught else 1
    sys.exit(1 if bad else 0)


main()
