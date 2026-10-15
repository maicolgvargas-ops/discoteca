#!/usr/bin/env python3
"""Genera LaAlfombraRoja.rbxlx (place completo: Script en ServerScriptService y LocalScript en
StarterPlayerScripts) y LaAlfombraRoja.rbxmx (el Script con el LocalScript como hijo "ClientEffects",
para 'Insert from File...' en un place ya abierto; el Script lo copia a StarterPlayerScripts)."""
import pathlib
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "src/ServerScriptService/LaAlfombraRoja.server.luau").read_text(encoding="utf-8")
client = (root / "src/StarterPlayer/StarterPlayerScripts/LaAlfombraRojaFX.client.luau").read_text(encoding="utf-8")
assert "]]>" not in src and "]]>" not in client, "los scripts no pueden contener ']]>' dentro de CDATA"

HEADER = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
)


def script_item(referent: str, indent: str, children: str = "") -> str:
    return (
        f'{indent}<Item class="Script" referent="{referent}">\n'
        f"{indent}\t<Properties>\n"
        f'{indent}\t\t<string name="Name">LaAlfombraRoja</string>\n'
        f'{indent}\t\t<token name="RunContext">0</token>\n'
        f'{indent}\t\t<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>\n'
        f"{indent}\t</Properties>\n"
        f"{children}"
        f"{indent}</Item>\n"
    )


def local_item(referent: str, indent: str, name: str) -> str:
    return (
        f'{indent}<Item class="LocalScript" referent="{referent}">\n'
        f"{indent}\t<Properties>\n"
        f'{indent}\t\t<string name="Name">{name}</string>\n'
        f'{indent}\t\t<ProtectedString name="Source"><![CDATA[{client}]]></ProtectedString>\n'
        f"{indent}\t</Properties>\n"
        f"{indent}</Item>\n"
    )


# Lighting con Technology = Future (Enum.Technology: Legacy 0, Voxel 1, Compatibility 2,
# ShadowMap 3, Future 4). Sin esta propiedad Studio abre el place con Compatibility y lo
# migra a Voxel. Los valores de ambiente coinciden con buildLighting() del script.
LIGHTING = (
    '\t<Item class="Lighting" referent="RBX1">\n\t\t<Properties>\n'
    '\t\t\t<string name="Name">Lighting</string>\n'
    '\t\t\t<token name="Technology">4</token>\n'
    '\t\t\t<Color3 name="Ambient"><R>0.21176471</R><G>0.18823530</G><B>0.20392157</B></Color3>\n'
    '\t\t\t<Color3 name="OutdoorAmbient"><R>0.18823530</R><G>0.17254902</G><B>0.21176471</B></Color3>\n'
    '\t\t\t<float name="Brightness">1</float>\n'
    '\t\t\t<float name="ExposureCompensation">0.5</float>\n'
    '\t\t\t<float name="EnvironmentDiffuseScale">0.5</float>\n'
    '\t\t\t<float name="EnvironmentSpecularScale">1</float>\n'
    '\t\t\t<float name="ShadowSoftness">0.35</float>\n'
    '\t\t\t<bool name="GlobalShadows">true</bool>\n'
    '\t\t</Properties>\n\t</Item>\n'
)

place = (
    HEADER
    + '\t<Item class="Workspace" referent="RBX0">\n\t\t<Properties>\n'
    '\t\t\t<string name="Name">Workspace</string>\n\t\t</Properties>\n\t</Item>\n'
    + LIGHTING
    + '\t<Item class="ServerScriptService" referent="RBX2">\n\t\t<Properties>\n'
    '\t\t\t<string name="Name">ServerScriptService</string>\n\t\t</Properties>\n'
    + script_item("RBX3", "\t\t")
    + "\t</Item>\n"
    + '\t<Item class="StarterPlayer" referent="RBX4">\n\t\t<Properties>\n'
    '\t\t\t<string name="Name">StarterPlayer</string>\n\t\t</Properties>\n'
    + '\t\t<Item class="StarterPlayerScripts" referent="RBX5">\n\t\t\t<Properties>\n'
    '\t\t\t\t<string name="Name">StarterPlayerScripts</string>\n\t\t\t</Properties>\n'
    + local_item("RBX6", "\t\t\t", "LaAlfombraRojaFX")
    + "\t\t</Item>\n\t</Item>\n</roblox>\n"
)
model = HEADER + script_item("RBX0", "\t", local_item("RBX1", "\t\t", "ClientEffects")) + "</roblox>\n"

for name, xml in (("LaAlfombraRoja.rbxlx", place), ("LaAlfombraRoja.rbxmx", model)):
    tree = ET.fromstring(xml)  # valida que sea XML bien formado
    got = [e.text for e in tree.iter("ProtectedString")]
    assert got == [src, client] or got == [src, client][::1], f"{name}: el Source no coincide con los scripts"
    (root / name).write_text(xml, encoding="utf-8")
    print(f"escrito {name} ({len(xml) // 1024} KiB), Source identico a los .luau")
