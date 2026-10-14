#!/usr/bin/env python3
"""Genera AuraClub.rbxlx (place de Roblox Studio) con el script dentro de ServerScriptService."""
import pathlib
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "src/ServerScriptService/AuraClub.server.luau").read_text(encoding="utf-8")
assert "]]>" not in src, "el script no puede contener ']]>' dentro de CDATA"

xml = f"""<?xml version="1.0" encoding="utf-8"?>
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="Workspace" referent="RBX0">
		<Properties>
			<string name="Name">Workspace</string>
		</Properties>
	</Item>
	<Item class="Lighting" referent="RBX1">
		<Properties>
			<string name="Name">Lighting</string>
		</Properties>
	</Item>
	<Item class="ServerScriptService" referent="RBX2">
		<Properties>
			<string name="Name">ServerScriptService</string>
		</Properties>
		<Item class="Script" referent="RBX3">
			<Properties>
				<string name="Name">AuraClub</string>
				<token name="RunContext">0</token>
				<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>
			</Properties>
		</Item>
	</Item>
</roblox>
"""
ET.fromstring(xml)  # valida que sea XML bien formado
out = root / "AuraClub.rbxlx"
out.write_text(xml, encoding="utf-8")
print(f"escrito {out} ({len(xml)//1024} KiB)")
