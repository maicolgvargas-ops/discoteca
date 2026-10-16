#!/usr/bin/env python3
"""Comprueba que el .rbxlx generado contiene EXACTAMENTE los .luau de v2/src (jerarquia, clases y Source)
y que no hay ids de assets ni ProductIds inventados. Uso: check_files.py [place.rbxlx]"""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import tree  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
_ver = re.search(r'Version\s*=\s*"([^"]+)"', (ROOT / "src/ReplicatedStorage/AlfombraShared/Config.luau").read_text(encoding="utf-8")).group(1)
PLACE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / f"LaAlfombraRoja_v{_ver}.rbxlx"
fails = 0


def check(name, cond, detail=""):
    global fails
    print(("  PASS  " if cond else "  FAIL  ") + name + ("" if cond else f" -> {detail}"))
    if not cond:
        fails += 1


doc = ET.parse(PLACE).getroot()
items = {c.get("class") + ":" + c.find("Properties/string[@name='Name']").text: c for c in doc.findall("Item")}
check("servicios presentes: Workspace, Lighting, ReplicatedStorage, ServerScriptService, StarterPlayer", all(k in items for k in ("Workspace:Workspace", "Lighting:Lighting", "ReplicatedStorage:ReplicatedStorage", "ServerScriptService:ServerScriptService", "StarterPlayer:StarterPlayer")))
tech = items["Lighting:Lighting"].find("Properties/token[@name='Technology']")
check("Lighting.Technology = Future (4)", tech is not None and tech.text == "4")


def walk(item, path=""):
    name = item.find("Properties/string[@name='Name']").text
    p = f"{path}/{name}"
    yield p, item
    for c in item.findall("Item"):
        yield from walk(c, p)


got = {}
for svc in ("ReplicatedStorage", "ServerScriptService", "StarterPlayer"):
    for p, it in walk(items[f"{svc}:{svc}"]):
        src = it.find("Properties/ProtectedString[@name='Source']")
        got[p] = (it.get("class"), src.text if src is not None else None)
want = {}
for r in tree.load():
    for n in r.walk():
        pass


def collect(node, path):
    p = f"{path}/{node.name}"
    want[p] = (node.cls, node.source)
    for c in node.children:
        collect(c, p)


for r in tree.load():
    collect(r, "")
want = {k: v for k, v in want.items() if k.count("/") >= 2 or v[1] is not None}
bad = [k for k in want if k not in got or got[k] != want[k]]
extra = [k for k in got if k not in want and got[k][1] is not None]
check(f"los {sum(1 for v in want.values() if v[1] is not None)} scripts del place son identicos a v2/src (clase + Source)", not bad and not extra, (bad + extra)[:5])
check("LocalScript de cliente dentro de StarterPlayerScripts", got.get("/StarterPlayer/StarterPlayerScripts/LaAlfombraRojaClient", (None,))[0] == "LocalScript")
check("Script de servidor en ServerScriptService", got.get("/ServerScriptService/LaAlfombraRoja", (None,))[0] == "Script")
check("modulos compartidos en ReplicatedStorage/AlfombraShared", all(f"/ReplicatedStorage/AlfombraShared/{m}" in got for m in ("Config", "Catalog", "DrinkModels", "Rig", "DancePoses", "Util")))
raw_src = "\n".join(v[1] for v in got.values() if v[1])
all_src = re.sub(r"--[^\n]*", "", re.sub(r"--\[\[.*?\]\]", "", raw_src, flags=re.S))  # sin comentarios
check("ningun asset id ni ProductId inventado (rbxassetid con numero / ProductId != 0)", not re.search(r"rbxassetid://\d{3,}", all_src) and not re.search(r"ProductId\s*=\s*[1-9]", all_src))
check("no se toca UserGameSettings ni RenderSettings", "UserGameSettings" not in all_src and "RenderSettings" not in all_src)
check("sin paneles ni comandos de benchmark", not re.search(r"(?i)benchmark", all_src))
check("StudioTestMode desactivado por defecto", re.search(r"StudioTestMode\s*=\s*false", got["/ReplicatedStorage/AlfombraShared/Config"][1]) is not None)
cfg = got["/ReplicatedStorage/AlfombraShared/Config"][1]
check("focos de seguimiento y alquiler de sesion configurados", all(k in cfg for k in ("Follow = {", "LeaseSeconds", "RenewSeconds", "LockWaitSeconds")))
check("los focos y el estrobo estan apagados por defecto (Control.DEFAULT)", re.search(r"Follow = false,", got["/ServerScriptService/LaAlfombraRoja/Control"][1]) is not None and re.search(r"Strobe = false,", got["/ServerScriptService/LaAlfombraRoja/Control"][1]) is not None)
sys.exit(1 if fails else 0)
