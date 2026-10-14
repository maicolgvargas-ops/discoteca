#!/usr/bin/env bash
# Ejecuta AuraClub.server.luau contra el mock de Roblox y lanza las comprobaciones.
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
OUT="$(mktemp -d)/run.luau"
cat tests/mock_roblox.luau src/ServerScriptService/AuraClub.server.luau tests/checks.luau > "$OUT"
"$LUAU" "$OUT"
python3 tests/check_files.py
