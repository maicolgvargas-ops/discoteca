#!/usr/bin/env python3
"""Genera UN archivo Luau para el simulador: mock + arbol de scripts de v2/src + codigo de prueba.
Uso: assemble_tests.py <prueba.luau> [salida.luau] [--set Config.Ruta=valor ...]
Las sustituciones --set modifican Config.luau (p.ej. Quality = "Alta") sin tocar los fuentes."""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import tree  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARENT_EXPR = {"ReplicatedStorage": "__replicated", "ServerScriptService": "__serverScripts", "StarterPlayer": "__starterPlayer"}


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


counter = [0]


def emit(node, parent_expr, sets):
    counter[0] += 1
    v = f"__n{counter[0]}"
    out = []
    if node.cls in ("Folder",) or node.cls in ("StarterPlayerScripts", "StarterCharacterScripts"):
        if node.cls in ("StarterPlayerScripts", "StarterCharacterScripts"):
            out.append(f'local {v} = {parent_expr}:FindFirstChild("{node.name}")')
        else:
            out.append(f'local {v} = Instance.new("Folder")\n{v}.Name = "{node.name}"\n{v}.Parent = {parent_expr}')
    elif node.cls in ("Script", "LocalScript", "ModuleScript"):
        src = node.source
        if node.name == "Config" and sets:
            for key, val in sets:
                pat = re.compile(r"^(\s*" + re.escape(key) + r"\s*=\s*)(.*?)(,?)\s*(--.*)?$", re.M)
                assert pat.search(src), f"--set: no encuentro {key} en Config"
                src = pat.sub(lambda m: m.group(1) + val + (m.group(3) or ",") + (("  " + m.group(4)) if m.group(4) else ""), src, count=1)
        out.append(f'local {v} = __defineScript({parent_expr}, "{node.cls}", "{node.name}", function(script)\n{src}\nend)')
    else:
        raise Exception("clase no soportada: " + node.cls)
    for c in node.children:
        out.append(emit(c, v, sets))
    return "do\n" + "\n".join(out) + "\nend"


def main():
    args = sys.argv[1:]
    sets = []
    rest = []
    i = 0
    while i < len(args):
        if args[i] == "--set":
            k, val = args[i + 1].split("=", 1)
            sets.append((k, val))
            i += 2
        else:
            rest.append(args[i])
            i += 1
    test = pathlib.Path(rest[0]).read_text(encoding="utf-8")
    parts = [(ROOT / "tests" / "mock_roblox.luau").read_text(encoding="utf-8")]
    for r in tree.load():
        if r.name in PARENT_EXPR:
            for c in r.children:
                parts.append(emit(c, PARENT_EXPR[r.name], sets))
    parts.append(test)
    text = "\n".join(parts)
    if len(rest) > 1:
        pathlib.Path(rest[1]).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)


main()
