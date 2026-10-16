#!/usr/bin/env python3
"""Genera LaAlfombraRoja_v2.rbxlx: place NUEVO con TODOS los scripts ya dentro (no sustituye al v1).
  ReplicatedStorage/AlfombraShared/*            (ModuleScripts compartidos)
  ServerScriptService/LaAlfombraRoja            (Script) + modulos hijos (Build, Extras, Inventory, ...)
  StarterPlayer/StarterPlayerScripts/LaAlfombraRojaClient (LocalScript) + modulos hijos
Los sources son identicos a los .luau de v2/src (lo comprueba tools/check_files.py).
Uso: make_place.py [salida.rbxlx]  (por defecto LaAlfombraRoja_v<Config.Version>.rbxlx)"""
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import tree  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
_ver = re.search(r'Version\s*=\s*"([^"]+)"', (ROOT / "src/ReplicatedStorage/AlfombraShared/Config.luau").read_text(encoding="utf-8")).group(1)
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / f"LaAlfombraRoja_v{_ver}.rbxlx"

HEADER = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
)

# Lighting con Technology = Future (Enum.Technology: Legacy 0, Voxel 1, Compatibility 2, ShadowMap 3, Future 4)
LIGHTING = (
    '\t<Item class="Lighting" referent="RBXL">\n\t\t<Properties>\n'
    '\t\t\t<string name="Name">Lighting</string>\n'
    '\t\t\t<token name="Technology">4</token>\n'
    '\t\t\t<Color3 name="Ambient"><R>0.11764706</R><G>0.10196078</G><B>0.11372549</B></Color3>\n'
    '\t\t\t<Color3 name="OutdoorAmbient"><R>0.10196078</R><G>0.09411765</G><B>0.11764706</B></Color3>\n'
    '\t\t\t<float name="Brightness">0.5</float>\n'
    '\t\t\t<float name="ExposureCompensation">-0.15</float>\n'
    '\t\t\t<float name="EnvironmentDiffuseScale">0.25</float>\n'
    '\t\t\t<float name="EnvironmentSpecularScale">1</float>\n'
    '\t\t\t<float name="ShadowSoftness">0.35</float>\n'
    '\t\t\t<bool name="GlobalShadows">true</bool>\n'
    '\t\t</Properties>\n\t</Item>\n'
)

counter = [0]


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def emit(node, indent: str) -> str:
    counter[0] += 1
    ref = f"RBX{counter[0]}"
    out = [f'{indent}<Item class="{node.cls}" referent="{ref}">\n', f"{indent}\t<Properties>\n", f'{indent}\t\t<string name="Name">{esc(node.name)}</string>\n']
    if node.cls == "Script":
        out.append(f'{indent}\t\t<token name="RunContext">0</token>\n')
    if node.source is not None:
        assert "]]>" not in node.source, f"{node.name}: el source no puede contener ']]>'"
        out.append(f'{indent}\t\t<ProtectedString name="Source"><![CDATA[{node.source}]]></ProtectedString>\n')
    out.append(f"{indent}\t</Properties>\n")
    for c in node.children:
        out.append(emit(c, indent + "\t"))
    out.append(f"{indent}</Item>\n")
    return "".join(out)


def main():
    roots = {r.name: r for r in tree.load()}
    parts = [HEADER, '\t<Item class="Workspace" referent="RBXW">\n\t\t<Properties>\n\t\t\t<string name="Name">Workspace</string>\n\t\t</Properties>\n\t</Item>\n', LIGHTING]
    for name in ("ReplicatedStorage", "ServerScriptService", "StarterPlayer"):
        r = roots[name]
        parts.append(f'\t<Item class="{name}" referent="RBX{name[:3].upper()}">\n\t\t<Properties>\n\t\t\t<string name="Name">{name}</string>\n\t\t</Properties>\n')
        for c in r.children:
            parts.append(emit(c, "\t\t"))
        parts.append("\t</Item>\n")
    parts.append("</roblox>\n")
    xml = "".join(parts)
    ET.fromstring(xml)  # XML bien formado
    OUT.write_text(xml, encoding="utf-8")
    n = sum(1 for r in roots.values() for x in r.walk() if x.source is not None)
    print(f"escrito {OUT.name} ({len(xml) // 1024} KiB, {n} scripts)")


main()
