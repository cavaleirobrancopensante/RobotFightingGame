extends RefCounted
## Company logos (all made up), drawn: on robots as sponsor stickers, on BotMedia avatars and
## on contract offers. draw_logo(ci, id, centre, radius) draws one in a circle of that radius.

static func _bolt(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(2, -14) * s, c + Vector2(-8, 2) * s, c + Vector2(0, 2) * s, c + Vector2(-2, 14) * s,
			c + Vector2(8, -2) * s, c + Vector2(0, -2) * s])


## sticker = true adds a backing disc so it reads on any paint.
static func draw_logo(ci: CanvasItem, id: String, c: Vector2, r: float, sticker: bool = false) -> void:
	var s := r / 20.0
	var white := Color(0.97, 0.96, 0.92)
	if sticker:
		ci.draw_circle(c, r * 1.08, Color(0.1, 0.1, 0.1))
		ci.draw_circle(c, r, white)
	match id:
		"boltcola":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * (0.92 if i % 2 else 0.8))
			ci.draw_colored_polygon(pts, Color("#e8352c"))
			ci.draw_colored_polygon(_bolt(c, s * 0.9), white)
		"voltaic":
			ci.draw_circle(c, r * 0.9, Color("#141414"))
			ci.draw_colored_polygon(_bolt(c, s), Color("#f2c230"))
		"ferrum":
			var blue := Color("#2f6fd6")
			ci.draw_rect(Rect2(c + Vector2(-14, 2) * s, Vector2(28, 10) * s), blue)
			ci.draw_arc(c + Vector2(0, -12) * s, 3 * s, 0, TAU, 10, blue, 2 * s)
			ci.draw_line(c + Vector2(0, -9) * s, c + Vector2(0, 2) * s, blue, 2.5 * s)
			ci.draw_arc(c + Vector2(0, -4) * s, 7 * s, PI * 0.15, PI * 0.85, 10, blue, 2.5 * s)
		"rustbuster":
			var g := Color("#2fae6b")
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16) * s, c + Vector2(10, 2) * s, c + Vector2(7, 11) * s,
					c + Vector2(0, 14) * s, c + Vector2(-7, 11) * s, c + Vector2(-10, 2) * s]), g)
			ci.draw_line(c + Vector2(-5, 9) * s, c + Vector2(5, -1) * s, white, 2.5 * s)
			ci.draw_arc(c + Vector2(6, -2) * s, 3 * s, 0, TAU, 8, white, 2 * s)
		"gearhead":
			var o := Color("#f07a1a")
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.72, r * 0.2, o)
			ci.draw_circle(c, r * 0.62, o)
			ci.draw_arc(c + Vector2(0, 1) * s, 6 * s, PI * 0.2, PI * 0.8, 8, white, 2 * s)
			ci.draw_circle(c + Vector2(-4, -4) * s, 1.6 * s, white)
			ci.draw_circle(c + Vector2(4, -4) * s, 1.6 * s, white)
		"neon":
			var pk := Color("#ff4fb8")
			ci.draw_rect(Rect2(c + Vector2(-12, 5) * s, Vector2(24, 8) * s), Color("#1a1a2a"))
			ci.draw_line(c + Vector2(0, 6) * s, c + Vector2(-4, -8) * s, pk, 3 * s)
			ci.draw_circle(c + Vector2(-4, -10) * s, 5 * s, pk)
		"nova":
			var pu := Color("#8a5cf0")
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 0) * s, c + Vector2(13, 0) * s, c + Vector2(8, 10) * s, c + Vector2(-8, 10) * s]), pu)
			ci.draw_line(c + Vector2(4, 0) * s, c + Vector2(12, -14) * s, Color("#ffd84a"), 2 * s)
			ci.draw_line(c + Vector2(7, 0) * s, c + Vector2(15, -12) * s, Color("#ffd84a"), 2 * s)
			ci.draw_line(c + Vector2(-6, -3) * s, c + Vector2(-5, -12) * s, Color(0.6, 0.6, 0.65), 1.5 * s)
		"harbour":
			var rd := Color("#e05a5a")
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 14) * s, c + Vector2(5, 14) * s, c + Vector2(3, -6) * s, c + Vector2(-3, -6) * s]), rd)
			ci.draw_rect(Rect2(c + Vector2(-4, -12) * s, Vector2(8, 6) * s), rd)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -10) * s, c + Vector2(16, -15) * s, c + Vector2(16, -4) * s]), Color(rd, 0.4))
		"rustybolt":
			ci.draw_circle(c, r * 0.9, Color("#2a0e0e"))
			ci.draw_colored_polygon(_bolt(c, s * 0.9), Color("#ff7a33"))
		"kane":
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color("#141414"))
			ci.draw_line(c + Vector2(-6, -11) * s, c + Vector2(-6, 11) * s, Color("#c8102e"), 4 * s)
			ci.draw_line(c + Vector2(-5, 1) * s, c + Vector2(8, -11) * s, Color("#c8102e"), 4 * s)
			ci.draw_line(c + Vector2(-3, -1) * s, c + Vector2(8, 11) * s, Color("#c8102e"), 4 * s)
		"botmedia":
			ci.draw_circle(c, r * 0.9, Color("#2a2f3a"))
			ci.draw_rect(Rect2(c + Vector2(-7, -12) * s, Vector2(14, 24) * s), Color("#7cc4ff"))
			ci.draw_rect(Rect2(c + Vector2(-5, -9) * s, Vector2(10, 16) * s), Color("#1a1f2a"))
			ci.draw_colored_polygon(_bolt(c + Vector2(0, -1) * s, s * 0.45), Color("#f2c230"))
		"mic":
			ci.draw_circle(c, r * 0.9, Color("#3a2a10"))
			ci.draw_rect(Rect2(c + Vector2(-4, -12) * s, Vector2(8, 13) * s), Color("#e0b84a"))
			ci.draw_line(c + Vector2(0, 1) * s, c + Vector2(0, 11) * s, Color("#e0b84a"), 2 * s)
		"partsrus":
			ci.draw_rect(Rect2(c + Vector2(-12, -10) * s, Vector2(24, 20) * s), Color("#a0723f"))
			ci.draw_line(c + Vector2(-12, -10) * s, c + Vector2(12, 10) * s, Color("#6a4a28"), 2 * s)
			ci.draw_line(c + Vector2(12, -10) * s, c + Vector2(-12, 10) * s, Color("#6a4a28"), 2 * s)
		# (1.90) the makers
		"mk_scrapworks":
			ci.draw_circle(c, r * 0.9, Color("#5d4037"))
			ci.draw_line(c + Vector2(-10, 10) * s, c + Vector2(7, -7) * s, Color("#c8b8a8"), 4 * s)
			ci.draw_arc(c + Vector2(9, -9) * s, 5 * s, PI * 0.9, PI * 2.4, 10, Color("#c8b8a8"), 3 * s)
			ci.draw_line(c + Vector2(-6, 0) * s, c + Vector2(0, 6) * s, Color("#d9c27a"), 5 * s)   # a strip of tape
		"mk_oldiron":
			var red := Color("#c0392b")
			var hx := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				hx.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
			ci.draw_colored_polygon(hx, Color("#2b2b2b"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -6) * s, c + Vector2(11, -6) * s, c + Vector2(7, -1) * s,
					c + Vector2(4, -1) * s, c + Vector2(4, 4) * s, c + Vector2(8, 9) * s, c + Vector2(-8, 9) * s, c + Vector2(-4, 4) * s,
					c + Vector2(-4, -1) * s, c + Vector2(-13, -2) * s]), red)   # an anvil
		"mk_brassworks":
			var brass := Color("#c9a227")
			for i in 10:
				var a := TAU * i / 10.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.78, r * 0.14, brass)
			ci.draw_circle(c, r * 0.72, brass)
			ci.draw_circle(c, r * 0.5, Color("#f3e9cf"))
			ci.draw_line(c, c + Vector2(6, -6) * s, Color("#3a2a10"), 2 * s)   # a gauge needle
			ci.draw_circle(c, 2 * s, Color("#3a2a10"))
		"mk_hellfire":
			ci.draw_circle(c, r * 0.92, Color("#1f1f1f"))
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_arc(c, r * 0.8, a, a + TAU / 16.0, 4, Color("#f1c40f"), 3 * s)   # a hazard ring
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * s, c + Vector2(6, -2) * s, c + Vector2(4, 9) * s,
					c + Vector2(-4, 9) * s, c + Vector2(-6, 0) * s, c + Vector2(-2, -4) * s]), Color("#e67e22"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3) * s, c + Vector2(3, 3) * s, c + Vector2(0, 8) * s, c + Vector2(-3, 3) * s]), Color("#f9e05a"))
		"mk_volta":
			ci.draw_circle(c, r * 0.92, Color("#101828"))
			ci.draw_line(c + Vector2(-10, -9) * s, c + Vector2(0, 10) * s, Color("#d6e4f0"), 4 * s)
			ci.draw_line(c + Vector2(10, -9) * s, c + Vector2(0, 10) * s, Color("#d6e4f0"), 4 * s)
			ci.draw_colored_polygon(_bolt(c + Vector2(0, -1) * s, s * 0.5), Color("#00b7ff"))
			ci.draw_arc(c, r * 0.86, 0, TAU, 28, Color("#ff4fb8"), 1.5 * s)   # neon rim
		"mk_nimbus":
			ci.draw_circle(c, r * 0.92, Color("#16323a"))
			for k in 3:
				var y := (k - 1) * 6.0
				ci.draw_polyline(PackedVector2Array([c + Vector2(-12, y + 3) * s, c + Vector2(0, y - 4) * s, c + Vector2(12, y + 3) * s]),
						Color("#ecf0f1") if k == 1 else Color("#81ecec"), 2.5 * s)
		"mk_tenryu":
			ci.draw_circle(c, r * 0.92, Color("#1d3557"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 4) * s, c + Vector2(-14, -11) * s, c + Vector2(-5, -1) * s]), Color("#f1c40f"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 4) * s, c + Vector2(14, -11) * s, c + Vector2(5, -1) * s]), Color("#f1c40f"))
			ci.draw_rect(Rect2(c + Vector2(-5, 2) * s, Vector2(10, 9) * s), Color("#f5f5f5"))   # a mecha face plate
			ci.draw_rect(Rect2(c + Vector2(-4, 4) * s, Vector2(8, 2) * s), Color("#e63946"))
		"mk_menagerie":
			ci.draw_circle(c, r * 0.92, Color("#2a1010"))
			for i in 4:
				var x0 := -12.0 + i * 6.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * s, c + Vector2(x0, 10) * s, c + Vector2(x0 + 6, 10) * s]),
						Color("#d63031") if i % 2 == 0 else Color("#f3e9cf"))
			ci.draw_circle(c + Vector2(0, -13) * s, 2.5 * s, Color("#e0b84a"))
		_:
			ci.draw_circle(c, r * 0.8, Color(0.5, 0.5, 0.55))


## A logo as a control (rows, avatars, offers).
class LogoIcon extends Control:
	var id := ""
	var sticker := false

	func _init(logo_id: String = "", px: float = 40.0) -> void:
		id = logo_id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.45
		load("res://logos.gd").draw_logo(self, id, size * 0.5, r, sticker)
