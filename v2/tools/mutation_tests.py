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
    ("recibo: no es idempotente (ignora PurchaseId repetido)", SS + "Inventory.luau", "if purchaseId and old.receipts[purchaseId] then", "if false then", "server"),
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
    ("oscuridad sin minimo (ambiente puede llegar a negro)", CL + "Mood.luau", "local MIN_KEEP = 0.45", "local MIN_KEEP = 0", "client"),
    ("focos siguen a quien esta fuera de la pista", CL + "FollowLights.luau", "if p.X >= h.x1 - F.Inset and p.X <= h.x2 + F.Inset and p.Z >= h.z1 - F.Inset and p.Z <= h.z2 + F.Inset and p.Y < 8 then", "if true then", "client"),
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
