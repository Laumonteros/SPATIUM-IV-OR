#!/usr/bin/env bash
# Exporta el ejecutable de Windows a build/SPATIUM_IV.exe (
# se regenera y se commitea con cada cambio del juego, por Git LFS).
set -euo pipefail
GODOT="${GODOT:-Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build"
"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Desktop" ../build/SPATIUM_IV.exe
test -s "$ROOT/build/SPATIUM_IV.exe" || { echo "ERROR: no se generó el .exe"; exit 1; }
# Prueba rápida: el ejecutable arranca sin errores de script
if "$ROOT/build/SPATIUM_IV.exe" --headless --quit-after 300 2>&1 | grep -q "SCRIPT ERROR"; then
  echo "ERROR: el .exe arranca con errores de script"; exit 1
fi
ls -lh "$ROOT/build/SPATIUM_IV.exe"
echo "EXE LISTO: build/SPATIUM_IV.exe"
