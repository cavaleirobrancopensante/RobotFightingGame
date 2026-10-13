#!/usr/bin/env python3
"""The consistency rules (Consistency Study, 1.121+) that code can check. Run before every release:
    python3 tools/stylecheck.py      (exit 1 = a rule broken)
Rules checked:
  1. No text in Godot's built-in font (ThemeDB.fallback_font), except lines marked "style-ok".
  2. No orange screen titles (Color(1.0, 0.45, 0.2)): headings go through GUI.heading.
  3. Text colours come from the palette: no Color(r, g, b) literal on a label, GUI.text / readout or a
     font_color override (mark a deliberate exception "style-ok").
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
bad = []
for f in sorted(ROOT.glob("*.gd")):
	src = f.read_text(encoding="utf-8")
	for i, line in enumerate(src.splitlines(), 1):
		if "ThemeDB.fallback_font" in line and "style-ok" not in line:
			bad.append(f"{f.name}:{i}: Godot's built-in font, use GUI.body / head / headb / num / world")
		if (re.search(r"(UI\.label|GUI\.text|GUI\.readout)\(", line) or re.search(r'add_theme_color_override\("(font_color|default_color)", ', line)) \
				and re.search(r"Color\(\d*\.?\d+, \d*\.?\d+, \d*\.?\d+\)", line) and "style-ok" not in line:
			bad.append(f"{f.name}:{i}: a text colour outside the palette, use GUI.TEXT / MUTED / HEAD / YELLOW / GREEN / AMBER / RED / CYAN / INK")
		if re.search(r"UI\.label\([^\n]*Color\(1\.0, 0\.45, 0\.2\)\)", line):
			bad.append(f"{f.name}:{i}: orange title, use GUI.heading")
for b in bad:
	print("STYLE", b)
print("stylecheck: %d problem(s)" % len(bad))
sys.exit(1 if bad else 0)
