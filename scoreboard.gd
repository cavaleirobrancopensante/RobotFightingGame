extends RefCounted
## The boards that show the fight name and the clock above the ring.
##   flip: a stadium split-flap board hanging on two steel rods (Regional and cups)
##   dots: a red dot-matrix LED board, the title scrolling like a ticker (Championship)
## (The scrapyard's chalk slate on chains is drawn in fight.gd.)

## 5x7 dot font: each glyph is 7 rows of 5 bits.
const GLYPHS := {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11100", "10010", "10001", "10001", "10001", "10010", "11100"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	"&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
	"'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
}


static func clock_text(seconds: float) -> String:
	var s := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [s / 60, s % 60]


static func fit_size(font: Font, text: String, width: float, max_size: int) -> int:
	var size := max_size
	while size > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


# ---------------------------------------------------------------- split-flap

## One flap tile: lighter top half, darker bottom half, a split line with hinge notches.
static func flap(ci: CanvasItem, tile: Rect2, ch: String, font: Font, size: int, ink: Color) -> void:
	var half := tile.size.y * 0.5
	ci.draw_rect(Rect2(tile.position, Vector2(tile.size.x, half)), Color(0.11, 0.11, 0.12))
	ci.draw_rect(Rect2(tile.position + Vector2(0, half), Vector2(tile.size.x, half)), Color(0.06, 0.06, 0.07))
	ci.draw_rect(tile, Color(0.3, 0.3, 0.32), false, 1.0)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var cap := font.get_ascent(size) * 0.72   # roughly the capital height
	var at := Vector2(tile.get_center().x - w * 0.5, tile.get_center().y + cap * 0.5)
	ci.draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	ci.draw_string(font, at + Vector2(0.7, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)   # painted thick
	var mid := tile.position.y + half
	ci.draw_line(Vector2(tile.position.x, mid), Vector2(tile.end.x, mid), Color(0, 0, 0, 0.55), 1.0)
	var notch := Vector2(maxf(1.5, tile.size.x * 0.07), maxf(2.0, tile.size.y * 0.1))
	ci.draw_rect(Rect2(Vector2(tile.position.x, mid - notch.y * 0.5), notch), Color(0.45, 0.45, 0.47))
	ci.draw_rect(Rect2(Vector2(tile.end.x - notch.x, mid - notch.y * 0.5), notch), Color(0.45, 0.45, 0.47))


## One row of letter flaps, left-aligned in area, as big as the row allows.
static func flap_row(ci: CanvasItem, area: Rect2, text: String, font: Font, ink: Color) -> void:
	var gap := 1.5
	var n := maxi(1, text.length())
	var cell := minf(area.size.y * 0.74, (area.size.x - n * gap) / n)
	var size := int(minf(cell * 1.5, area.size.y * 0.86))
	for k in n:
		var ch := text.substr(k, 1)
		if ch != " ":
			flap(ci, Rect2(area.position.x + k * (cell + gap), area.position.y, cell, area.size.y), ch, font, size, ink)


## Split-flap board: the fight name on the left in two rows (event / round), the countdown on the
## right in two tall flaps.
static func draw_flip(ci: CanvasItem, r: Rect2, title: String, secs: float, hurry: bool, font: Font, _max_size: int) -> void:
	# two steel rods from the roof, a charcoal board with a raised edge
	for side in [0.16, 0.84]:
		var x: float = r.position.x + r.size.x * side
		ci.draw_rect(Rect2(x - 3, -4, 6, r.position.y + 6), Color(0.45, 0.47, 0.5))
		ci.draw_rect(Rect2(x - 1, -4, 1.5, r.position.y + 6), Color(0.8, 0.82, 0.85))
	ci.draw_rect(r.grow(3), Color(0.38, 0.39, 0.41))
	ci.draw_rect(r.grow(1), Color(0.04, 0.04, 0.05))
	ci.draw_rect(r, Color(0.17, 0.17, 0.18))
	var white := Color(1, 1, 1)
	# right: the countdown (seconds), two tall flaps
	var dh := r.size.y - 8.0
	var dw := dh * 0.66
	var clock_w := dw * 2.0 + 3.0
	var cr := Rect2(Vector2(r.end.x - 4.0 - clock_w, r.position.y + 4.0), Vector2(clock_w, dh))
	var digits := str(ceili(maxf(0.0, secs))).lpad(2, "0")
	if digits.length() > 2:
		digits = "99"
	var ink := Color(1.0, 0.35, 0.25) if hurry else white
	for k in 2:
		flap(ci, Rect2(cr.position.x + k * (dw + 3.0), cr.position.y, dw, dh), digits.substr(k, 1), font, int(dh * 0.9), ink)
	ci.draw_rect(Rect2(cr.position.x - 5.0, r.position.y + 3.0, 1.5, r.size.y - 6.0), Color(0.05, 0.05, 0.05))
	# left: the fight name in two rows - the event, then the round
	var parts := title.split(" - ", false, 1)
	var top_line: String = parts[0]
	var bottom_line: String = parts[1] if parts.size() > 1 else ""
	var left := Rect2(r.position + Vector2(5, 4), Vector2(cr.position.x - 10.0 - r.position.x - 5.0, r.size.y - 8.0))
	if bottom_line == "":
		flap_row(ci, left, top_line, font, white)
	else:
		var rh := (left.size.y - 3.0) * 0.5
		flap_row(ci, Rect2(left.position, Vector2(left.size.x, rh)), top_line, font, white)
		flap_row(ci, Rect2(left.position + Vector2(0, rh + 3.0), Vector2(left.size.x, rh)), bottom_line, font, Color(1.0, 0.85, 0.35))


# ---------------------------------------------------------------- red dot-matrix LED

## Draw text in lit dots, its left edge at x, clipped to [clip_l, clip_r].
static func dot_text(ci: CanvasItem, text: String, x: float, y: float, p: float, clip_l: float, clip_r: float, lit: Color) -> void:
	var d := p * 0.72
	for k in text.length():
		var gx := x + k * 6 * p
		if gx > clip_r or gx + 5 * p < clip_l:
			continue
		var g: Array = GLYPHS.get(text.substr(k, 1), [])
		for row in g.size():
			var bits: String = g[row]
			for col in 5:
				if bits[col] == "1":
					var px := gx + col * p
					if px >= clip_l and px + d <= clip_r:
						ci.draw_rect(Rect2(px - p * 0.2, y + row * p - p * 0.2, d + p * 0.4, d + p * 0.4), Color(lit, 0.22))
						ci.draw_rect(Rect2(px, y + row * p, d, d), lit)


## The dark, unlit dots that fill the panel.
static func dot_grid(ci: CanvasItem, area: Rect2, p: float, rows: int) -> void:
	for row in rows:
		var y := area.position.y + row * p + p * 0.36
		ci.draw_dashed_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.24, 0.04, 0.04), p * 0.72, p * 0.5)


static func draw_dots(ci: CanvasItem, r: Rect2, title: String, secs: float, hurry: bool, t: float) -> void:
	ci.draw_rect(r.grow(3), Color(0.1, 0.1, 0.11))
	ci.draw_rect(r.grow(1), Color(0.02, 0.02, 0.02))
	ci.draw_rect(r, Color(0.05, 0.01, 0.01))
	var lit := Color(1.0, 0.24, 0.14)
	# top line: the fight name, scrolling like a ticker when it's too long
	var tp := floorf(maxf(2.0, r.size.y * 0.36 / 8.0))
	var tl := Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8, tp * 8))
	dot_grid(ci, tl, tp, 7)
	var width := title.length() * 6 * tp
	if width <= tl.size.x:
		var sx0 := tl.position.x + roundf((tl.size.x - width) * 0.5 / tp) * tp
		dot_text(ci, title, sx0, tl.position.y, tp, tl.position.x, tl.end.x, lit)
	else:
		var loop := width + 12 * tp
		var off := fmod(t * 34.0, loop)
		var sx := snappedf(tl.position.x - off, tp)
		dot_text(ci, title, sx, tl.position.y, tp, tl.position.x, tl.end.x, lit)
		dot_text(ci, title, sx + loop, tl.position.y, tp, tl.position.x, tl.end.x, lit)
	# bottom: the clock in big dots
	var cy := tl.end.y + tp
	var cp := floorf(maxf(3.0, (r.end.y - cy - 3) / 7.0))
	var cl := Rect2(Vector2(r.position.x + 4, cy), Vector2(r.size.x - 8, cp * 7))
	dot_grid(ci, cl, cp, 7)
	var ct := clock_text(secs)
	var cw := ct.length() * 6 * cp - cp
	var on := lit if not hurry or fmod(t, 0.5) < 0.35 else Color(0.5, 0.05, 0.03)
	dot_text(ci, ct, cl.position.x + roundf((cl.size.x - cw) * 0.5 / cp) * cp, cl.position.y, cp, cl.position.x, cl.end.x, on)
