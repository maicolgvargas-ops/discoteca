#!/usr/bin/env python3
"""Ejecuta tests/t_eventdecor.luau contra el simulador (mock) con EventDecor.luau como ModuleScript.
Uso: run_tests.py [ruta/a/luau]   (por defecto el binario `luau` del PATH). NO es una prueba en Roblox Studio."""
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
mock = (root / "tests/mock_roblox.luau").read_text(encoding="utf-8")
mod = (pathlib.Path(__file__).resolve().parent / "EventDecor.luau").read_text(encoding="utf-8")
test = (root / "tests/t_eventdecor.luau").read_text(encoding="utf-8")
text = mock + '\n__defineScript(__replicated, "ModuleScript", "EventDecorTest", function(script)\n' + mod + "\nend)\n" + test
out = pathlib.Path(tempfile.mkdtemp()) / "run_eventdecor.luau"
out.write_text(text, encoding="utf-8")
import re
code = re.sub(r"--[^\n]*", "", re.sub(r"--\[\[.*?\]\]", "", mod, flags=re.S))
bad = [t for t in ("http", "rbxassetid", "rbxasset", "require", "PointLight", "SpotLight", "SurfaceLight", "Heartbeat", "RunService", "while ", "repeat", "task.", "Script", "GetService", "Sound", "Fire", "Explosion", "Touched", "InsertService", "HttpService", "LoadAsset", "MarketplaceService") if t in code]
print("  PASS  analisis estatico: sin assets/IDs, require, HTTP, luces, scripts, bucles de ejecucion ni servicios" if not bad else "  FAIL  analisis estatico: " + ", ".join(bad))
luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
r = subprocess.run([luau, str(out)], capture_output=True, text=True)
sys.stdout.write(r.stdout)
sys.stderr.write(r.stderr)
sys.exit(r.returncode)
