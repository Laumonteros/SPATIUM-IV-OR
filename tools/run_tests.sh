#!/usr/bin/env bash
# Ejecuta los tests de SPATIUM IV (cada prueba de integración en su propio proceso).
set -u
GODOT="${GODOT:-Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../game" && pwd)"
fail=0
run() { "$GODOT" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@" -gexit 2>&1 | grep -E "\[Failed\]|Passing Tests|Failing Tests|SCRIPT ERROR" ; }
out=$(run -gdir=res://tests/unit); echo "unit: $out" | tr '\n' ' '; echo; grep -q "Failing\|Failed\|SCRIPT ERROR" <<<"$out" && fail=1
for f in "$ROOT"/tests/integration/test_*.gd; do
  n=$(basename "$f" .gd)
  out=$(run -gdir=res://tests/integration -gselect="$n"); echo "$n: $out" | tr '\n' ' '; echo
  grep -q "Failing\|Failed\|SCRIPT ERROR" <<<"$out" && fail=1
done
[ $fail -eq 0 ] && echo "TODOS LOS TESTS PASARON" || { echo "HAY TESTS FALLANDO"; exit 1; }
