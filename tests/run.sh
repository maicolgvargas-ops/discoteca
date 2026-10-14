#!/usr/bin/env bash
# Ejecuta MayaClub.server.luau contra el mock de Roblox, lanza las comprobaciones y valida los archivos generados.
# El script se envuelve en una funcion para que su limite de 200 locales sea independiente del mock y los tests.
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
SRC="${SRC:-src/ServerScriptService/MayaClub.server.luau}"
OUT="$(mktemp -d)/run.luau"
{
	cat tests/mock_roblox.luau
	echo "local AURA = (function()"
	cat "$SRC"
	echo "return { club = club, fx = fx, CONFIG = CONFIG, LOOK = LOOK, normalizeAudioId = normalizeAudioId, LAYOUT = LAYOUT }"
	echo "end)()"
	echo "local club, fx, CONFIG, LOOK, normalizeAudioId, LAYOUT = AURA.club, AURA.fx, AURA.CONFIG, AURA.LOOK, AURA.normalizeAudioId, AURA.LAYOUT"
	cat tests/checks.luau
} > "$OUT"
"$LUAU" "$OUT"
[ "$SRC" = "src/ServerScriptService/MayaClub.server.luau" ] && python3 tests/check_files.py || true
