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
	ci.draw_rect(Rect2(tile.position, Vector2(tile.size.x, half)), Color(0.2, 0.2, 0.22))
	ci.draw_rect(Rect2(tile.position + Vector2(0, half), Vector2(tile.size.x, half)), Color(0.14, 0.14, 0.15))
	ci.draw_rect(tile, Color(0.36, 0.36, 0.38), false, 1.0)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size) * 0.72   # roughly the capital height
	ci.draw_string(font, Vector2(tile.get_center().x - w * 0.5, tile.get_center().y + asc * 0.5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	var mid := tile.position.y + half
	ci.draw_line(Vector2(tile.position.x, mid), Vector2(tile.end.x, mid), Color(0.02, 0.02, 0.02, 0.75), 1.0)
	var notch := Vector2(maxf(1.5, tile.size.x * 0.08), maxf(2.0, tile.size.y * 0.12))
	ci.draw_rect(Rect2(Vector2(tile.position.x, mid - notch.y * 0.5), notch), Color(0.5, 0.5, 0.52))
	ci.draw_rect(Rect2(Vector2(tile.end.x - notch.x, mid - notch.y * 0.5), notch), Color(0.5, 0.5, 0.52))


static func draw_flip(ci: CanvasItem, r: Rect2, title: String, secs: float, hurry: bool, font: Font, max_size: int) -> void:
	# two steel rods from the roof, a charcoal board with a raised edge
	for side in [0.16, 0.84]:
		var x: float = r.position.x + r.size.x * side
		ci.draw_rect(Rect2(x - 3, -4, 6, r.position.y + 6), Color(0.45, 0.47, 0.5))
		ci.draw_rect(Rect2(x - 1, -4, 1.5, r.position.y + 6), Color(0.8, 0.82, 0.85))
	ci.draw_rect(r.grow(3), Color(0.32, 0.33, 0.35))
	ci.draw_rect(r.grow(1), Color(0.07, 0.07, 0.08))
	ci.draw_rect(r, Color(0.12, 0.12, 0.13))
	var tr := Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, r.size.y * 0.36))
	var cr := Rect2(Vector2(r.position.x + 6, tr.end.y + 4), Vector2(r.size.x - 12, r.end.y - tr.end.y - 8))
	ci.draw_rect(Rect2(r.position.x + 4, tr.end.y + 1, r.size.x - 8, 1), Color(0.05, 0.05, 0.05))
	# the name: a row of small flaps, one per letter
	var gap := 1.0
	var n := maxi(1, title.length())
	var cell := minf(tr.size.y * 0.75, (tr.size.x - n * gap) / n)
	var size := mini(max_size, int(minf(cell * 1.45, tr.size.y * 0.8)))
	var x0 := tr.get_center().x - n * (cell + gap) * 0.5
	var white := Color(0.95, 0.95, 0.93)
	for k in n:
		var ch := title.substr(k, 1)
		var tile := Rect2(x0 + k * (cell + gap), tr.position.y, cell, tr.size.y)
		if ch == " ":
			continue
		flap(ci, tile, ch, font, size, white)
	# the clock: big flaps, m:ss
	var digits := clock_text(secs).replace(":", "")
	var dh := cr.size.y
	var dw := dh * 0.72
	var colon := dw * 0.45
	var total := digits.length() * (dw + 3) + colon
	var x := cr.get_center().x - total * 0.5
	var ink := Color(1.0, 0.4, 0.3) if hurry else white
	for k in digits.length():
		if k == digits.length() - 2:
			ci.draw_circle(Vector2(x + colon * 0.45, cr.position.y + dh * 0.32), maxf(1.5, dh * 0.06), ink)
			ci.draw_circle(Vector2(x + colon * 0.45, cr.position.y + dh * 0.68), maxf(1.5, dh * 0.06), ink)
			x += colon
		flap(ci, Rect2(x, cr.position.y, dw, dh), digits.substr(k, 1), font, int(dh * 0.95), ink)
		x += dw + 3


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
