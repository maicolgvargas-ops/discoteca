#!/usr/bin/env python3
"""Lee v2/src y lo convierte en un arbol de instancias de Roblox (convenciones de Rojo):
  carpeta con init.server.luau -> Script (los demas archivos son sus hijos)
  carpeta con init.client.luau -> LocalScript
  carpeta con init.luau        -> ModuleScript
  X.luau -> ModuleScript, X.server.luau -> Script, X.client.luau -> LocalScript
  carpeta normal -> Folder (o el servicio si esta en el nivel superior)
"""
import pathlib

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
SERVICES = {"ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui", "Workspace", "Lighting"}
SERVICE_CHILDREN = {("StarterPlayer", "StarterPlayerScripts"): "StarterPlayerScripts", ("StarterPlayer", "StarterCharacterScripts"): "StarterCharacterScripts"}


class Node:
    def __init__(self, name, cls, source=None, path=None):
        self.name, self.cls, self.source, self.path, self.children = name, cls, source, path, []

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()


def _file_node(p: pathlib.Path):
    n = p.name
    if n.endswith(".server.luau"):
        return Node(n[: -len(".server.luau")], "Script", p.read_text(encoding="utf-8"), p)
    if n.endswith(".client.luau"):
        return Node(n[: -len(".client.luau")], "LocalScript", p.read_text(encoding="utf-8"), p)
    if n.endswith(".luau"):
        return Node(n[: -len(".luau")], "ModuleScript", p.read_text(encoding="utf-8"), p)
    return None


def _dir_node(d: pathlib.Path, parent_name=None):
    cls, source = "Folder", None
    if parent_name is None and d.name in SERVICES:
        cls = d.name
    elif (parent_name, d.name) in SERVICE_CHILDREN:
        cls = SERVICE_CHILDREN[(parent_name, d.name)]
    for init, c in (("init.server.luau", "Script"), ("init.client.luau", "LocalScript"), ("init.luau", "ModuleScript")):
        if (d / init).exists():
            cls, source = c, (d / init).read_text(encoding="utf-8")
    node = Node(d.name, cls, source, d)
    for child in sorted(d.iterdir()):
        if child.name.startswith("init."):
            continue
        if child.is_dir():
            node.children.append(_dir_node(child, d.name))
        else:
            fn = _file_node(child)
            if fn:
                node.children.append(fn)
    return node


def load():
    roots = []
    for d in sorted(SRC.iterdir()):
        if d.is_dir():
            roots.append(_dir_node(d))
    return roots


if __name__ == "__main__":
    for r in load():
        for n in r.walk():
            print(n.cls, n.name, "" if n.source is None else f"({len(n.source.splitlines())} lineas)")
