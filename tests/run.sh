#!/usr/bin/env bash
# Ejecuta LaAlfombraRoja.server.luau contra el mock de Roblox, lanza las comprobaciones y valida los archivos generados.
# El script se envuelve en una funcion para que su limite de 200 locales sea independiente del mock y los tests.
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
SRC="${SRC:-src/ServerScriptService/LaAlfombraRoja.server.luau}"
if [ -n "${QUALITY:-}" ]; then
	QF="$(mktemp -d)/q.luau"; sed "s/Quality = \"Equilibrado\"/Quality = \"$QUALITY\"/" "$SRC" > "$QF"; SRC="$QF"
fi
MODE="${MODE:-fallback}"
CLIENT_SRC="src/StarterPlayer/StarterPlayerScripts/LaAlfombraRojaFX.client.luau"
OUT="$(mktemp -d)/run.luau"
{
	cat tests/mock_roblox.luau
	[ "$MODE" = "client" ] && echo "__withClient = true"
	echo "local AURA = (function()"
	cat "$SRC"
	echo "return { club = club, fx = fx, CONFIG = CONFIG, LOOK = LOOK, normalizeAudioId = normalizeAudioId, LAYOUT = LAYOUT, PROFILE = PROFILE, PROFILE_NAME = PROFILE_NAME, TILE_COUNT = TILE_COUNT }"
	echo "end)()"
	echo "local club, fx, CONFIG, LOOK, normalizeAudioId, LAYOUT, PROFILE, PROFILE_NAME, TILE_COUNT = AURA.club, AURA.fx, AURA.CONFIG, AURA.LOOK, AURA.normalizeAudioId, AURA.LAYOUT, AURA.PROFILE, AURA.PROFILE_NAME, AURA.TILE_COUNT"
	if [ "$MODE" = "client" ]; then
		echo "local function __loadClient()"
		cat "$CLIENT_SRC"
		echo "end"
		cat tests/checks_client.luau
	else
		cat tests/checks.luau
	fi
} > "$OUT"
"$LUAU" "$OUT"
[ "$SRC" = "src/ServerScriptService/LaAlfombraRoja.server.luau" ] && python3 tests/check_files.py || true
