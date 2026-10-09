extends Control
## (1.77) Port Ferrum on your pilot's tablet: a map app over a night-time satellite view of the
## city, drawn live. Districts, roads, the places you can go (pins) and the venues you fight in
## (landmarks). Your pilot is a little walking figure; pick a place and a dashed route runs to it
## along the avenue with the hours it takes. go() walks the figure there, then `arrived` fires.

signal picked(place: String)
signal arrived(place: String)

const UI = preload("res://ui.gd")
const I18n = preload("res://i18n.gd")
const VW := 1000.0
const VH := 560.0
## The avenue that runs from the Docks up to Kane Heights; every place joins it at PLACES "road".
const AVENUE := [Vector2(110, 476), Vector2(230, 420), Vector2(320, 352), Vector2(470, 304), Vector2(600, 292), Vector2(720, 222), Vector2(870, 160)]
const PIN := {"home": Color(0.95, 0.76, 0.19), "pub": Color(1.0, 0.45, 0.3), "shop": Color(0.4, 0.75, 1.0), "scrap": Color(0.85, 0.55, 0.25), "venue": Color(0.62, 0.62, 0.7), "maker": Color(0.85, 0.68, 0.22)}

var selected := ""
var walk_t := -1.0          # 0..1 while the figure walks
var walk_route: Array = []
var walk_to := ""
var t := 0.0
var _city: Array = []       # rooftops etc., made once (seeded)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _process(delta: float) -> void:
	t += delta
	if walk_t >= 0.0:
		walk_t += delta / 1.6
		if walk_t >= 1.0:
			walk_t = -1.0
			var to := walk_to
			walk_to = ""
			arrived.emit(to)
	queue_redraw()


## Map space -> this control's space (the map keeps its shape inside the tablet's screen).
func _xf() -> Array:
	var scr := _screen()
	var k := minf(scr.size.x / VW, scr.size.y / VH)
	var off := scr.position + (scr.size - Vector2(VW, VH) * k) * 0.5
	return [k, off]


func _screen() -> Rect2:
	var bez := 14.0
	return Rect2(Vector2(bez, bez + 18.0), size - Vector2(bez * 2.0, bez * 2.0 + 18.0))


func m2c(p: Vector2) -> Vector2:
	var x := _xf()
	return x[1] + p * float(x[0])


func place_pos(place: String) -> Vector2:
	var pl: Dictionary = GameData.PLACES.get(place, {})
	var pp: Array = pl.get("pos", [500, 280])
	return Vector2(float(pp[0]), float(pp[1]))


## From one place to another along the avenue.
func route(from: String, to: String) -> Array:
	var a := int(GameData.PLACES.get(from, {}).get("road", 2))
	var b := int(GameData.PLACES.get(to, {}).get("road", 2))
	var pts: Array = [place_pos(from)]
	var step := 1 if b >= a else -1
	var i := a
	while true:
		pts.append(AVENUE[i])
		if i == b:
			break
		i += step
	pts.append(place_pos(to))
	return pts


func go(place: String) -> void:
	walk_route = route(GameData.pilot_at, place)
	walk_to = place
	walk_t = 0.0


func _gui_input(e: InputEvent) -> void:
	var p := Vector2.INF
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position
	elif e is InputEventScreenTouch and not e.pressed:
		p = e.position
	if p == Vector2.INF:
		return
	if walk_t >= 0.0:
		walk_t = 0.999   # a tap hurries the walk
		return
	var best := ""
	var bd := 34.0
	for k in GameData.PLACES:
		var d := m2c(place_pos(k)).distance_to(p)
		if d < bd:
			bd = d
			best = k
	if best != "":
		selected = best
		Sfx.play("click")
		picked.emit(best)
		accept_event()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_city = []
	# rooftops: [rect, colour, lit]
	var zones := [[Rect2(250, 200, 250, 210), 16.0, Color(0.2, 0.18, 0.17)], [Rect2(520, 250, 230, 160), 24.0, Color(0.18, 0.19, 0.21)],
			[Rect2(720, 60, 260, 230), 34.0, Color(0.15, 0.16, 0.2)]]
	for z in zones:
		var r: Rect2 = z[0]
		var cell: float = z[1]
		var y := r.position.y
		while y < r.end.y:
			var x := r.position.x
			while x < r.end.x:
				if rng.randf() < 0.82:
					var w := cell * rng.randf_range(0.55, 0.85)
					var h := cell * rng.randf_range(0.55, 0.85)
					var col: Color = (z[2] as Color).lightened(rng.randf_range(-0.05, 0.12))
					_city.append([Rect2(x + 2, y + 2, w, h), col, rng.randf() < 0.25])
				x += cell
			y += cell


func _draw() -> void:
	var W := size.x
	var H := size.y
	if W < 40.0:
		return
	var f := ThemeDB.fallback_font
	# the tablet: a dark rounded body with a thin bezel, a status bar along the top
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.05, 0.05, 0.06)
	body.set_corner_radius_all(18)
	body.border_color = Color(0.25, 0.25, 0.28)
	body.set_border_width_all(2)
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var scr := _screen()
	draw_rect(scr, Color(0.07, 0.08, 0.09))
	var fs := UI.px(11)
	draw_string(f, Vector2(scr.position.x + 6, scr.position.y - 5), "MAPS · PORT FERRUM", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 0.65, 0.7))
	draw_string(f, Vector2(scr.position.x, scr.position.y - 5), I18n.t(GameData.PHASE_NAMES[GameData.phase]), HORIZONTAL_ALIGNMENT_RIGHT, scr.size.x - 6, fs, Color(0.6, 0.65, 0.7))
	draw_circle(Vector2(W * 0.5, 9), 2.5, Color(0.2, 0.2, 0.22))
	var x := _xf()
	var k: float = x[0]
	draw_set_transform(x[1], 0.0, Vector2(k, k))
	_satellite()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the route to the picked place, with the hours it takes
	var dest := walk_to if walk_to != "" else selected
	if dest != "" and dest != GameData.pilot_at and not GameData.PLACES[dest].has("venue"):
		var pts: Array = route(GameData.pilot_at, dest) if walk_t < 0.0 else walk_route
		var cpts: Array = pts.map(func(q): return m2c(q))
		var dash := 0.0
		for i in cpts.size() - 1:
			var a: Vector2 = cpts[i]
			var b: Vector2 = cpts[i + 1]
			var L := a.distance_to(b)
			var s := 0.0
			while s < L:
				var e := minf(L, s + 8.0)
				if fmod(dash + s - t * 30.0, 14.0) < 8.0:
					draw_line(a.lerp(b, s / L), a.lerp(b, e / L), Color(0.95, 0.76, 0.19), 3.0)
				s += 4.0
			dash += L
		var hrs := GameData.travel_hours(GameData.pilot_at, dest)
		var mid: Vector2 = cpts[cpts.size() / 2]
		var txt := I18n.t("%s h") % ("%.1f" % hrs).trim_suffix(".0")
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(13)).x + 14.0
		draw_rect(Rect2(mid + Vector2(-tw * 0.5, -30), Vector2(tw, 22)), Color(0.05, 0.05, 0.07, 0.9))
		draw_rect(Rect2(mid + Vector2(-tw * 0.5, -30), Vector2(tw, 22)), Color(0.95, 0.76, 0.19), false, 1.5)
		draw_string(f, mid + Vector2(-tw * 0.5, -14), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, UI.px(13), Color(0.95, 0.76, 0.19))
	# pins: places you can go, landmarks you fight in
	for key in GameData.PLACES:
		var pl: Dictionary = GameData.PLACES[key]
		var c := m2c(place_pos(key))
		var kind := str(pl["kind"])
		var col: Color = PIN.get(kind, Color.WHITE)
		var locked := GameData.place_locked(key) != "" and kind != "venue"
		if locked:
			col = Color(0.35, 0.35, 0.38)
		var r := 10.0 if kind != "venue" else 8.0
		if key == selected:
			draw_circle(c, r + 7.0 + sin(t * 5.0) * 1.5, Color(0.95, 0.76, 0.19, 0.35))
		draw_circle(c, r + 2.0, Color(0.03, 0.03, 0.04))
		draw_circle(c, r, col)
		_glyph(kind, c, locked)
		if kind == "venue" and key != selected and key != "kane_arena":
			continue   # the halls are landmarks: named when you tap them
		var name := I18n.t(str(pl["name"]))
		var lfs := UI.px(11)
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		draw_string_outline(f, c + Vector2(-nw * 0.5, r + 15), name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, 4, Color(0.02, 0.02, 0.03))
		draw_string(f, c + Vector2(-nw * 0.5, r + 15), name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.92, 0.92, 0.95) if not locked else Color(0.55, 0.55, 0.6))
	# you: a little walking figure
	var me := m2c(place_pos(GameData.pilot_at)) + Vector2(-16, -16)
	var walking := walk_t >= 0.0
	if walking:
		me = _along(walk_route.map(func(q): return m2c(q)), walk_t) + Vector2(0, -14)
	_walker(me, walking)


## The figure's spot along the route, 0..1.
func _along(pts: Array, u: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var want := total * clampf(u, 0.0, 1.0)
	for i in pts.size() - 1:
		var L: float = (pts[i] as Vector2).distance_to(pts[i + 1])
		if want <= L:
			return (pts[i] as Vector2).lerp(pts[i + 1], want / maxf(1.0, L))
		want -= L
	return pts[-1]


func _walker(p: Vector2, walking: bool) -> void:
	var c := Color(0.55, 1.0, 0.65)
	draw_circle(p + Vector2(0, 2), 13.0, Color(0, 0, 0, 0.55))
	var sw := sin(t * 12.0) * (5.0 if walking else 0.0)
	draw_circle(p + Vector2(0, -8), 3.5, c)
	draw_line(p + Vector2(0, -4), p + Vector2(0, 4), c, 2.5)
	draw_line(p + Vector2(0, 4), p + Vector2(-3 + sw * 0.5, 11), c, 2.0)
	draw_line(p + Vector2(0, 4), p + Vector2(3 - sw * 0.5, 11), c, 2.0)
	draw_line(p + Vector2(0, -2), p + Vector2(-4 - sw * 0.4, 3), c, 2.0)
	draw_line(p + Vector2(0, -2), p + Vector2(4 + sw * 0.4, 3), c, 2.0)


func _glyph(kind: String, c: Vector2, locked: bool) -> void:
	var g := Color(0.05, 0.05, 0.06)
	if locked:
		# a padlock
		draw_rect(Rect2(c + Vector2(-4, -1), Vector2(8, 6)), g)
		draw_arc(c + Vector2(0, -1), 3.0, PI, TAU, 8, g, 1.6)
		return
	match kind:
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(5, 5), c + Vector2(-5, 5)]), g)
		"pub":
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(6, 9)), g)
			draw_arc(c + Vector2(2.5, 0.5), 2.5, -PI * 0.5, PI * 0.5, 6, g, 1.5)
		"shop":
			draw_line(c + Vector2(-4, 4), c + Vector2(2, -2), g, 2.5)
			draw_arc(c + Vector2(3, -3), 2.6, deg_to_rad(-200), deg_to_rad(70), 8, g, 1.6)
		"scrap":
			draw_arc(c, 4.0, 0, TAU, 8, g, 2.0)
			draw_circle(c, 1.5, g)
		"maker":
			# a cog
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 3.0, c + Vector2(cos(a), sin(a)) * 5.5, g, 2.0)
			draw_circle(c, 3.2, g)
			draw_circle(c, 1.2, Color(0.85, 0.68, 0.22))
		"venue":
			draw_arc(c, 4.0, 0, TAU, 12, g, 1.6)
			draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), g, 1.2)


## Night-time satellite view of Port Ferrum, in map units.
func _satellite() -> void:
	# land, then the sea along the left and the bottom with the harbour cut in; both reach the edges
	# of the tablet's screen (the map's own box is letterboxed inside it)
	var x := _xf()
	var k: float = x[0]
	var scr := _screen()
	var vis := Rect2((scr.position - Vector2(x[1])) / k, scr.size / k)
	draw_rect(vis, Color(0.11, 0.12, 0.11))
	var sea := Color(0.04, 0.08, 0.13)
	var sea_poly := PackedVector2Array([Vector2(-600, -400), Vector2(70, -400), Vector2(70, 0), Vector2(90, 180), Vector2(60, 330), Vector2(120, 410), Vector2(300, 520), Vector2(520, 560), Vector2(640, 1000), Vector2(-600, 1000)])
	var box := PackedVector2Array([vis.position, Vector2(vis.end.x, vis.position.y), vis.end, Vector2(vis.position.x, vis.end.y)])
	for part in Geometry2D.intersect_polygons(sea_poly, box):
		draw_colored_polygon(part, sea)
	for i in 9:
		var y := 60.0 + i * 55.0
		draw_line(Vector2(6, y), Vector2(40 + (i % 3) * 8, y + 4), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	# the docks: piers into the water, container stacks, cranes seen from above
	for i in 4:
		var px := 150.0 + i * 70.0
		draw_rect(Rect2(px, 470 + i * 12, 18, 60), Color(0.22, 0.21, 0.2))
	var cc := [Color(0.6, 0.2, 0.15), Color(0.15, 0.35, 0.55), Color(0.65, 0.5, 0.15), Color(0.2, 0.45, 0.3)]
	for r in 3:
		for c in 7:
			draw_rect(Rect2(250 + c * 22, 430 + r * 11, 19, 8), (cc[(r * 7 + c) % 4] as Color).darkened(0.25))
	for i in 3:
		var cx := 270.0 + i * 60.0
		draw_line(Vector2(cx, 405), Vector2(cx + 30, 470), Color(0.8, 0.6, 0.2), 2.0)
		draw_rect(Rect2(cx - 4, 401, 8, 8), Color(0.75, 0.55, 0.2))
	# the scrapyard: heaps of dead robots
	var heaps := [[Vector2(120, 440), 26.0], [Vector2(165, 470), 20.0], [Vector2(140, 410), 16.0], [Vector2(190, 438), 14.0]]
	for h in heaps:
		draw_circle(h[0], h[1], Color(0.26, 0.19, 0.13))
		draw_circle(h[0] + Vector2(-4, -4), float(h[1]) * 0.6, Color(0.33, 0.24, 0.15))
	# (1.101) the airfield at the edge of Midtown: grass, a runway with its centre line, the hangar's roof
	draw_rect(Rect2(780, 440, 210, 90), Color(0.13, 0.17, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(800, 500), Vector2(990, 470), Vector2(994, 482), Vector2(804, 512)]), Color(0.24, 0.24, 0.26))
	for i in 8:
		var u := 0.08 + i * 0.12
		draw_line(Vector2(800, 506).lerp(Vector2(992, 476), u), Vector2(800, 506).lerp(Vector2(992, 476), u + 0.05), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	draw_rect(Rect2(830, 448, 40, 22), Color(0.55, 0.58, 0.62))
	draw_line(Vector2(830, 459), Vector2(870, 459), Color(0.42, 0.45, 0.5), 1.0)
	# district ground tints
	draw_rect(Rect2(240, 190, 270, 230), Color(0.16, 0.14, 0.12, 0.6))
	draw_rect(Rect2(510, 240, 250, 180), Color(0.14, 0.15, 0.17, 0.6))
	draw_rect(Rect2(710, 50, 280, 250), Color(0.12, 0.12, 0.17, 0.6))
	# rooftops, a few with lit windows
	for b in _city:
		var r: Rect2 = b[0]
		draw_rect(r, b[1])
		if b[2]:
			draw_rect(Rect2(r.position + r.size * 0.3, r.size * 0.4), Color(1.0, 0.8, 0.45, 0.35))
	# the halls and arenas, seen from above
	_stadium(Vector2(246, 484), Vector2(26, 16), Color(0.5, 0.35, 0.2))
	_stadium(Vector2(596, 360), Vector2(32, 20), Color(0.35, 0.45, 0.6))
	_stadium(Vector2(700, 300), Vector2(36, 22), Color(0.4, 0.5, 0.75))
	_stadium(Vector2(800, 236), Vector2(42, 26), Color(0.6, 0.5, 0.35))
	_stadium(Vector2(880, 120), Vector2(64, 40), Color(0.75, 0.15, 0.2))
	# the avenue and its street lights
	for i in AVENUE.size() - 1:
		draw_line(AVENUE[i], AVENUE[i + 1], Color(0.3, 0.3, 0.32), 7.0)
		draw_line(AVENUE[i], AVENUE[i + 1], Color(0.42, 0.42, 0.44), 1.0)
		var a: Vector2 = AVENUE[i]
		var b: Vector2 = AVENUE[i + 1]
		for s in 4:
			draw_circle(a.lerp(b, (s + 0.5) / 4.0) + (b - a).orthogonal().normalized() * 6.0, 1.6, Color(1.0, 0.8, 0.4, 0.8))
	# side streets to every place
	for key in GameData.PLACES:
		var pl: Dictionary = GameData.PLACES[key]
		draw_line(place_pos(key), AVENUE[int(pl["road"])], Color(0.27, 0.27, 0.29), 4.0)
	# district names
	var f := ThemeDB.fallback_font
	var spots := {"docks": Vector2(110, 380), "oldtown": Vector2(270, 190), "midtown": Vector2(530, 242), "heights": Vector2(730, 54)}
	for d in spots:
		draw_string(f, spots[d], I18n.t(GameData.DISTRICTS[d]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.72, 0.78, 0.55))


func _stadium(c: Vector2, r: Vector2, ring: Color) -> void:
	var x := _xf()
	var k: float = x[0]
	draw_set_transform(Vector2(x[1]) + c * k, 0.0, r * k)
	draw_circle(Vector2.ZERO, 1.0, Color(0.1, 0.1, 0.12))
	draw_arc(Vector2.ZERO, 0.85, 0, TAU, 32, ring, 0.18)
	draw_circle(Vector2.ZERO, 0.45, Color(0.16, 0.2, 0.17))
	draw_set_transform(x[1], 0.0, Vector2(k, k))
