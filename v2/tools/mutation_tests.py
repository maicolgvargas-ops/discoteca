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
