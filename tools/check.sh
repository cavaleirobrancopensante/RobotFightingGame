#!/bin/bash
# (1.151) The safety net. Run before every release (the release script does):
#   GODOT=/path/to/godot tools/check.sh
# Copies the project, runs tools/tests/smoke.gd.txt as the main scene (with a screen through xvfb
# when it's there, so the layout checks are real), and fails on any FAIL line or SCRIPT ERROR.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
P="$(mktemp -d)"
trap 'rm -rf "$P"' EXIT
(cd "$ROOT" && tar cf - --exclude=./build --exclude=./.git .) | (cd "$P" && tar xf -)
cp "$ROOT/tools/tests/smoke.gd.txt" "$P/zz_smoke.gd"
printf '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://zz_smoke.gd" id="1"]\n[node name="Smoke" type="Node"]\nscript = ExtResource("1")\n' > "$P/zz_smoke.tscn"
(cd "$ROOT" && python3 tools/stylecheck.py >/dev/null 2>&1) || { (cd "$ROOT" && python3 tools/stylecheck.py); echo "CHECK FAILED: stylecheck"; exit 1; }
OUT="$P/out.txt"
if command -v xvfb-run >/dev/null 2>&1; then
	timeout ${CHECK_TIMEOUT:-400} xvfb-run -a -s "-screen 0 1152x648x24" "$G" --path "$P" --rendering-driver opengl3 --resolution 1152x648 res://zz_smoke.tscn > "$OUT" 2>&1
else
	timeout ${CHECK_TIMEOUT:-400} "$G" --headless --path "$P" res://zz_smoke.tscn > "$OUT" 2>&1
fi
[ -n "${CHECK_LOG:-}" ] && cp "$OUT" "$CHECK_LOG"
grep -E "^(OK|FAIL) |SMOKE DONE" "$OUT"
ERRS=$(grep -E "SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Invalid get|Invalid set" "$OUT" | sort | uniq -c | sort -rn | head -12)
if [ -n "$ERRS" ]; then
	echo "SCRIPT ERRORS:"; echo "$ERRS"
	grep -A3 -m3 "SCRIPT ERROR" "$OUT"
fi
if ! grep -q "SMOKE DONE ok=[0-9]* fail=0" "$OUT" || [ -n "$ERRS" ]; then
	echo "CHECK FAILED"
	exit 1
fi
echo "CHECK PASSED"
