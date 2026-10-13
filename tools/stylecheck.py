#!/usr/bin/env python3
"""The consistency rules (Consistency Study, 1.121+) that code can check. Run before every release:
    python3 tools/stylecheck.py      (exit 1 = a rule broken)
Rules checked:
  1. No text in Godot's built-in font: ThemeDB.fallback_font only in the files still on ALLOW_FALLBACK
     (each later release empties this list a little).
  2. No orange screen titles (Color(1.0, 0.45, 0.2)): headings go through GUI.heading.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# files still allowed the built-in font (to be emptied by 1.122 / 1.125), with how many uses
ALLOW_FALLBACK = {
	"fight.gd": 1, "arena.gd": 14, "city_map.gd": 5, "garage_art.gd": 17, "garage.gd": 4,
	"garage_ui.gd": 4, "part_icon.gd": 1, "robot_preview.gd": 2, "saves.gd": 1, "story.gd": 1,
	"controls_editor.gd": 1,
}
bad = []
for f in sorted(ROOT.glob("*.gd")):
	src = f.read_text(encoding="utf-8")
	n = src.count("ThemeDB.fallback_font")
	if n > ALLOW_FALLBACK.get(f.name, 0):
		bad.append(f"{f.name}: {n} uses of ThemeDB.fallback_font (allowed {ALLOW_FALLBACK.get(f.name, 0)})")
	for i, line in enumerate(src.splitlines(), 1):
		if re.search(r"UI\.label\([^\n]*Color\(1\.0, 0\.45, 0\.2\)\)", line):
			bad.append(f"{f.name}:{i}: orange title, use GUI.heading")
for b in bad:
	print("STYLE", b)
print("stylecheck: %d problem(s)" % len(bad))
sys.exit(1 if bad else 0)
