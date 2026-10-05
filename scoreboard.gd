extends RefCounted
## The boards that show the fight name and the clock above the ring. All three have the same
## layout: the fight name on the left in two rows (the event, then the round), the countdown
## big on the right.
##   chalk: a slate hung crooked on rusty chains, next to a busted old clock (scrapyard)
##   flip:  a stadium split-flap board hanging on two steel rods (Regional and cups)
##   dots:  a red dot-matrix LED board (Championship)

## 5x7 dot font: each glyph is 7 rows of 5 bits.
const I18n = preload("res://i18n.gd")
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


## "REGIONAL - LEAGUE ROUND 1/8" -> ["REGIONAL", "LEAGUE ROUND 1/8"]
static func split_title(title: String) -> Array:
	var parts := title.split(" - ", false, 1)
	return [parts[0] if parts.size() > 0 else "", parts[1] if parts.size() > 1 else ""]


static func seconds_text(secs: float) -> String:
	return str(mini(99, ceili(maxf(0.0, secs)))).lpad(2, "0")


static func clock_text(seconds: float) -> String:
	var s := ceili(maxf(0.0, seconds))
	return "%d:%02d" % [s / 60, s % 60]


static func fit_size(font: Font, text: String, width: float, max_size: int) -> int:
	var size := max_size
	while size > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


# ---------------------------------------------------------------- scrapyard slate + busted clock

static func draw_chalk(ci: CanvasItem, r: Rect2, title: String, secs: float, hurry: bool, t: float, font: Font) -> void:
	# the whole thing hangs crooked: the right chain is longer, and it sways a bit
	var swing := -0.08 + sin(t * 0.9) * 0.018
	var pivot := r.get_center()
	ci.draw_set_transform(pivot, swing, Vector2.ONE)
	var lr := Rect2(r.position - pivot, r.size)
	for side in [0.1, 0.62]:
		var x: float = lr.position.x + lr.size.x * side
		var y := lr.position.y - 70.0
		var link := 0
		while y < lr.position.y - 2:
			if link % 2 == 0:
				ci.draw_arc(Vector2(x, y + 3.5), 4.0, 0, TAU, 8, Color(0.72, 0.55, 0.38), 3.0)
			else:
				ci.draw_line(Vector2(x, y), Vector2(x, y + 7), Color(0.62, 0.47, 0.32), 3.5)
			y += 5.0
			link += 1
	# right: the busted clock, wired onto the side of the slate
	var ch := lr.size.y + 4.0
	var cw := ch * 1.25
	var clock_r := Rect2(Vector2(lr.end.x - cw, lr.position.y - 2.0), Vector2(cw, ch))
	var slate := Rect2(lr.position, Vector2(clock_r.position.x - 8.0 - lr.position.x, lr.size.y))
	# the slate in a battered wooden frame
	ci.draw_rect(slate.grow(4), Color(0.42, 0.28, 0.16))
	ci.draw_rect(slate.grow(4), Color(0.25, 0.16, 0.09), false, 2.0)
	ci.draw_rect(slate, Color(0.13, 0.17, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(slate.position.x - 4, slate.end.y + 4), Vector2(slate.position.x + 18, slate.end.y + 4),
			Vector2(slate.position.x - 4, slate.end.y - 12)]), Color(0.1, 0.08, 0.06))   # broken corner
	ci.draw_rect(Rect2(slate.position + Vector2(-8, slate.size.y * 0.4), Vector2(14, 11)), Color(0.5, 0.48, 0.44))   # nailed-on patch
	ci.draw_circle(slate.position + Vector2(-5, slate.size.y * 0.4 + 3), 1.4, Color(0.2, 0.2, 0.2))
	for k in 3:   # old chalk smudges
		ci.draw_rect(Rect2(slate.position + Vector2(slate.size.x * (0.1 + k * 0.3), slate.size.y * (0.3 + 0.25 * (k % 2))), Vector2(slate.size.x * 0.2, 5)), Color(1, 1, 1, 0.05))
	var lines := split_title(title)
	var chalk := Color(0.95, 0.95, 0.9)
	var inner := slate.grow(-4)
	var rows: Array = [lines[0]] if lines[1] == "" else lines
	var rh := inner.size.y / rows.size()
	for k in rows.size():
		var text: String = rows[k]
		var size := fit_size(font, text, inner.size.x, int(rh * 0.95))
		var base := Vector2(inner.position.x, inner.position.y + rh * (k + 1) - rh * 0.18)
		var c := chalk if k == 0 else Color(1.0, 0.92, 0.55)   # second line in yellow chalk
		ci.draw_string(font, base + Vector2(0.8, 0.6), text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, size, Color(c, 0.3))
		ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, size, c)
	# the clock: a dented metal box hanging off a bit of wire, cracked glass over a green LCD
	ci.draw_line(Vector2(slate.end.x + 4, slate.position.y + 6), Vector2(clock_r.position.x + 4, clock_r.position.y + 6), Color(0.6, 0.6, 0.62), 1.5)
	ci.draw_set_transform(pivot + clock_r.get_center().rotated(swing), swing + 0.06, Vector2.ONE)
	var cr := Rect2(-clock_r.size * 0.5, clock_r.size)
	ci.draw_rect(cr, Color(0.36, 0.3, 0.24))
	ci.draw_rect(cr, Color(0.2, 0.16, 0.12), false, 2.0)
	ci.draw_circle(cr.position + Vector2(5, 5), 1.6, Color(0.6, 0.5, 0.35))   # rusty screws
	ci.draw_circle(cr.end - Vector2(5, 5), 1.6, Color(0.6, 0.5, 0.35))
	var screen := cr.grow(-6)
	ci.draw_rect(screen, Color(0.42, 0.5, 0.36))
	var digits := seconds_text(secs)
	var dsize := fit_size(font, "88", screen.size.x - 4, int(screen.size.y * 1.05))
	var lcd := Color(0.08, 0.1, 0.06) if not hurry else Color(0.45, 0.05, 0.03)
	ci.draw_string(font, Vector2(screen.position.x, screen.end.y - screen.size.y * 0.12), "88", HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, dsize, Color(0, 0, 0, 0.07))   # ghost segments
	ci.draw_string(font, Vector2(screen.position.x, screen.end.y - screen.size.y * 0.12), digits, HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, dsize, lcd)
	# the crack across the glass, with a spider web where something hit it
	var hit := screen.position + Vector2(screen.size.x * 0.72, screen.size.y * 0.3)
	ci.draw_polyline(PackedVector2Array([screen.position + Vector2(0, screen.size.y * 0.75), hit - Vector2(screen.size.x * 0.3, -2), hit]), Color(0.92, 0.95, 0.9, 0.85), 1.2)
	ci.draw_polyline(PackedVector2Array([hit, hit + Vector2(screen.size.x * 0.1, screen.size.y * 0.45), Vector2(screen.end.x - 3, screen.end.y)]), Color(0.92, 0.95, 0.9, 0.8), 1.2)
	ci.draw_line(hit, Vector2(screen.end.x, screen.position.y + 2), Color(0.92, 0.95, 0.9, 0.75), 1.0)
	ci.draw_line(hit, Vector2(hit.x - 4, screen.position.y), Color(0.92, 0.95, 0.9, 0.7), 1.0)
	ci.draw_arc(hit, 3.0, 0, TAU, 8, Color(0.95, 0.97, 0.93, 0.8), 1.0)
	ci.draw_rect(Rect2(screen.position + Vector2(-3, screen.size.y * 0.1), Vector2(10, 5)), Color(0.85, 0.8, 0.6, 0.9))   # a strip of tape
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	if size < 6:
		return
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
	var digits := seconds_text(secs)
	var ink := Color(1.0, 0.35, 0.25) if hurry else white
	for k in 2:
		flap(ci, Rect2(cr.position.x + k * (dw + 3.0), cr.position.y, dw, dh), digits.substr(k, 1), font, int(dh * 0.9), ink)
	ci.draw_rect(Rect2(cr.position.x - 5.0, r.position.y + 3.0, 1.5, r.size.y - 6.0), Color(0.05, 0.05, 0.05))
	# left: the fight name in two rows - the event, then the round
	var parts := split_title(title)
	var top_line: String = parts[0]
	var bottom_line: String = parts[1]
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
		var g: Array = GLYPHS.get(plain(text.substr(k, 1)), [])
		for row in g.size():
			var bits: String = g[row]
			for col in 5:
				if bits[col] == "1":
					var px := gx + col * p
					if px >= clip_l and px + d <= clip_r:
						ci.draw_rect(Rect2(px - p * 0.2, y + row * p - p * 0.2, d + p * 0.4, d + p * 0.4), Color(lit, 0.22))
						ci.draw_rect(Rect2(px, y + row * p, d, d), lit)


## LED glyphs are plain A-Z: accented letters (translations) light up as their base letter.
static func plain(ch: String) -> String:
	const FROM := "ÁÀÂÃÄÇÉÈÊËÍÌÎÏÑÓÒÔÕÖÚÙÛÜ"
	const TO := "AAAAACEEEEIIIINOOOOOUUUU"
	var i := FROM.find(ch.to_upper())
	return TO[i] if i >= 0 else ch.to_upper()


## The dark, unlit dots that fill the panel.
static func dot_grid(ci: CanvasItem, area: Rect2, p: float, rows: int) -> void:
	for row in rows:
		var y := area.position.y + row * p + p * 0.36
		ci.draw_dashed_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.24, 0.04, 0.04), p * 0.72, p * 0.5)


## One row of dot text in area: as big as fits (between min_p and the row height), scrolling like
## a ticker if it still doesn't fit.
static func dot_row(ci: CanvasItem, area: Rect2, text: String, t: float, lit: Color) -> void:
	var cols := maxi(1, text.length() * 6 - 1)
	var p := minf(area.size.y / 7.0, maxf(2.0, area.size.x / cols))
	var row := Rect2(area.position.x, area.position.y + (area.size.y - p * 7.0) * 0.5, area.size.x, p * 7.0)
	dot_grid(ci, row, p, 7)
	var width := cols * p
	if width <= row.size.x + 0.5:
		dot_text(ci, text, row.position.x, row.position.y, p, row.position.x, row.end.x, lit)
	else:
		var loop := width + 8.0 * p
		var sx := row.position.x - snappedf(fmod(t * 30.0, loop), p)
		dot_text(ci, text, sx, row.position.y, p, row.position.x, row.end.x, lit)
		dot_text(ci, text, sx + loop, row.position.y, p, row.position.x, row.end.x, lit)


## Red LED board: the fight name in two dot rows on the left, the seconds in big dots on the right.
static func draw_dots(ci: CanvasItem, r: Rect2, title: String, secs: float, hurry: bool, t: float) -> void:
	ci.draw_rect(r.grow(3), Color(0.1, 0.1, 0.11))
	ci.draw_rect(r.grow(1), Color(0.02, 0.02, 0.02))
	ci.draw_rect(r, Color(0.05, 0.01, 0.01))
	var lit := Color(1.0, 0.24, 0.14)
	# right: the seconds
	var cp := floorf((r.size.y - 8.0) / 7.0 * 0.8)
	var cw := 11.0 * cp
	var cl := Rect2(Vector2(r.end.x - 5.0 - cw, r.position.y + (r.size.y - cp * 7.0) * 0.5), Vector2(cw, cp * 7.0))
	dot_grid(ci, Rect2(cl.position - Vector2(cp * 0.5, 0), cl.size + Vector2(cp, 0)), cp, 7)
	var on := lit if not hurry or fmod(t, 0.5) < 0.35 else Color(0.5, 0.05, 0.03)
	dot_text(ci, seconds_text(secs), cl.position.x, cl.position.y, cp, cl.position.x - cp, cl.end.x + cp, on)
	ci.draw_rect(Rect2(cl.position.x - cp - 4.0, r.position.y + 3.0, 1.5, r.size.y - 6.0), Color(0.18, 0.03, 0.03))
	# left: event, then round
	var left := Rect2(r.position + Vector2(5, 4), Vector2(cl.position.x - cp - 10.0 - r.position.x - 5.0, r.size.y - 8.0))
	var lines := split_title(title)
	if lines[1] == "":
		dot_row(ci, left, lines[0], t, lit)
	else:
		var rh := (left.size.y - 2.0) * 0.5
		dot_row(ci, Rect2(left.position, Vector2(left.size.x, rh)), lines[0], t, lit)
		dot_row(ci, Rect2(left.position + Vector2(0, rh + 2.0), Vector2(left.size.x, rh)), lines[1], t + 1.7, Color(1.0, 0.6, 0.15))
