#!/usr/bin/env python3
"""Comprueba AuraClub.rbxlx / .rbxmx: XML valido, Source identico al .luau y Lighting.Technology=Future."""
import pathlib
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "src/ServerScriptService/AuraClub.server.luau").read_text(encoding="utf-8")
ok = True


def check(name, cond):
    global ok
    print(("  PASS  " if cond else "  FAIL  ") + name)
    ok = ok and cond


place = ET.parse(root / "AuraClub.rbxlx").getroot()
model = ET.parse(root / "AuraClub.rbxmx").getroot()
check("rbxlx: Source del Script identico al .luau", [e.text for e in place.iter("ProtectedString")] == [src])
check("rbxmx: Source del Script identico al .luau", [e.text for e in model.iter("ProtectedString")] == [src])
lighting = [i for i in place.iter("Item") if i.get("class") == "Lighting"]
check("rbxlx: hay un Lighting", len(lighting) == 1)
tech = [t.text for t in lighting[0].iter("token") if t.get("name") == "Technology"] if lighting else []
check("rbxlx: Lighting.Technology = 4 (Future), evita la migracion a Voxel", tech == ["4"])
check("rbxlx: Script dentro de ServerScriptService", any(
    i.get("class") == "ServerScriptService" and any(c.get("class") == "Script" for c in i.findall("Item"))
    for i in place.iter("Item")))
check("rbxmx: raiz es un Script", model.find("Item").get("class") == "Script")
sys.exit(0 if ok else 1)
