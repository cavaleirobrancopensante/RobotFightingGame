extends Control
## (1.77) Port Ferrum on your pilot's tablet: a map app over a night-time satellite view of the
## city, drawn live. Districts, roads, the places you can go (pins) and the venues you fight in
## (landmarks). Your pilot is a little walking figure; pick a place and a dashed route runs to it
## along the avenue with the hours it takes. go() walks the figure there, then `arrived` fires.
## (1.110) A real map app: pinch or scroll to zoom (ZOOM_MIN..ZOOM_MAX), drag to pan, + / - and a
## "me" button in the corner. Every bit of land is built on: a street grid per district with blocks
## of rooftops, parks with trees, named plazas and streets (shown as you zoom in), cars on the
## avenue, rooftop details close up. The map draws in its own clipped screen (MapView).

signal picked(place: String)
signal arrived(place: String)

const UI = preload("res://ui.gd")
const I18n = preload("res://i18n.gd")
const VW := 1000.0
const VH := 560.0
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.5
## The avenue that runs from the Docks up to Kane Heights; every place joins it at PLACES "road".
const AVENUE := [Vector2(110, 476), Vector2(230, 420), Vector2(320, 352), Vector2(470, 304), Vector2(600, 292), Vector2(720, 222), Vector2(870, 160)]
const PIN := {"home": Color(0.95, 0.76, 0.19), "pub": Color(1.0, 0.45, 0.3), "shop": Color(0.4, 0.75, 1.0), "scrap": Color(0.85, 0.55, 0.25), "venue": Color(0.62, 0.62, 0.7), "maker": Color(0.85, 0.68, 0.22)}
const SEA := [Vector2(-600, -400), Vector2(70, -400), Vector2(70, 0), Vector2(90, 180), Vector2(60, 330), Vector2(120, 410), Vector2(300, 520), Vector2(520, 560), Vector2(640, 1000), Vector2(-600, 1000)]

## The districts' street grids: [rect, block size, roof colour, kind]. Together they cover all the land.
const REGIONS := [
	[Rect2(80, 0, 630, 150), 26.0, Color(0.21, 0.18, 0.16), "houses"],     # Northside
	[Rect2(70, 150, 110, 260), 28.0, Color(0.2, 0.18, 0.16), "houses"],    # Westside
	[Rect2(180, 150, 330, 260), 30.0, Color(0.22, 0.19, 0.16), "old"],     # Old Town
	[Rect2(510, 150, 200, 80), 30.0, Color(0.19, 0.19, 0.2), "mixed"],     # Midtown north
	[Rect2(510, 230, 270, 180), 34.0, Color(0.18, 0.19, 0.22), "offices"],  # Midtown
	[Rect2(710, 0, 290, 230), 46.0, Color(0.13, 0.13, 0.17), "towers"],    # Kane Heights
	[Rect2(780, 230, 220, 210), 30.0, Color(0.2, 0.19, 0.18), "houses"],   # East End
	[Rect2(70, 410, 290, 150), 44.0, Color(0.24, 0.25, 0.27), "sheds"],    # the Docks
	[Rect2(360, 410, 420, 150), 34.0, Color(0.2, 0.19, 0.19), "mixed"],    # Southbank
]
## Named open spaces: [name, rect, kind]
const PARKS := [
	["Founders' Square", Rect2(352, 248, 34, 30), "plaza"],
	["Harbour Green", Rect2(192, 350, 52, 38), "park"],
	["Piston Plaza", Rect2(630, 318, 36, 28), "plaza"],
	["Kane Plaza", Rect2(752, 170, 34, 28), "plaza"],
	["Bellows Park", Rect2(420, 56, 92, 52), "park"],
	["Gearwheel Park", Rect2(860, 330, 70, 50), "park"],
	["Quay Square", Rect2(398, 504, 26, 20), "plaza"],
	["Lantern Gardens", Rect2(560, 168, 50, 36), "park"],
]
## Places the city doesn't build over: the arenas, the scrapyard, the container yard, the airfield.
const KEEP_CLEAR := [Rect2(212, 460, 68, 48), Rect2(556, 334, 80, 52), Rect2(656, 272, 88, 56), Rect2(750, 204, 100, 64),
		Rect2(810, 74, 140, 92), Rect2(90, 392, 128, 100), Rect2(244, 398, 166, 70), Rect2(780, 440, 220, 120), Rect2(420, 530, 70, 30)]
## Street names (proper names, not translated): one vertical and one across per district, in REGIONS order.
const STREETS := [["Rivet Row", "Northgate Road"], ["Saltmarsh Lane", "Tidewater Street"], ["Foundry Street", "Copper Lane"],
		["Lantern Way", "Spring Lane"], ["Volt Street", "Signal Road"], ["Gilt Avenue", "Kane Boulevard"],
		["Gearwheel Street", "Union Street"], ["Crane Lane", "Harbour Road"], ["Anvil Lane", "Old Mill Road"]]

var selected := ""
var walk_t := -1.0          # 0..1 while the figure walks
var walk_route: Array = []
var walk_to := ""
var by_taxi := false   # (1.117) the trip is a BotTaxi ride: quicker, a little yellow car
var t := 0.0
var zoom := 1.0
var cam := Vector2(VW * 0.5, VH * 0.5)   # the map point in the middle of the screen
var view: Control           # the clipped screen the map draws in
var cv: CanvasItem          # what the map functions draw on (the view, while it draws)

var _blocks: Array = []     # [rect, colour, lit, kind, seed]
var _streets: Array = []    # [a, b, width]
var _names: Array = []      # [a, b, name]
var _greens: Array = []     # [polygon, park?]
var _trees: Array = []      # [pos, r]
var _ground: Array = []     # [polygon, colour]: each district's pavement, cut to the shore
var _touches := {}
var _drag_from := Vector2.INF
var _dragged := 0.0
var _pinch := 0.0
var _touch_seen := false
var _redraw := 0.0
var _dirty := true
var sv: SubViewport
var painter: Node2D
var _static_key := ""
var _static_age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	view = MapView.new()
	view.map = self
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	# (1.110) the still part of the map (ground, streets, rooftops, names, pins) is painted into a
	# texture, again only when the camera or the picks change; the moving bits are drawn live on top
	sv = SubViewport.new()
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	painter = StaticPainter.new()
	painter.map = self
	sv.add_child(painter)
	view.add_child(sv)
	_build()


class MapView extends Control:
	var map
	func _draw() -> void:
		map.draw_map(self)


class StaticPainter extends Node2D:
	var map
	func _draw() -> void:
		map.draw_static(self)


func _process(delta: float) -> void:
	t += delta
	if walk_t >= 0.0:
		walk_t += delta / (0.9 if by_taxi else 1.6)
		if zoom > 1.15:
			cam = cam.lerp(_along(walk_route, walk_t), minf(1.0, delta * 4.0))   # follow the walk
		if walk_t >= 1.0:
			walk_t = -1.0
			var to := walk_to
			walk_to = ""
			arrived.emit(to)
		_dirty = true
	# a still map redraws 12 times a second (lights, the pulse round the pick); moving, every frame
	_redraw -= delta
	if _dirty or not _touches.is_empty() or _redraw <= 0.0:
		_redraw = 1.0 / 12.0
		_dirty = false
		queue_redraw()
		if view != null:
			var scr := _screen()
			view.position = scr.position
			view.size = scr.size
			# the still layer: painted again when anything it shows has changed (or every 2 s for state)
			_static_age += 1.0 / 12.0
			var key := "%s|%s|%s|%s|%s|%s|%s" % [str(cam.round()), str(snappedf(zoom, 0.001)), str(scr.size), selected, GameData.pilot_at, walk_to, str(UI.px(10))]
			if key != _static_key or _static_age > 2.0:
				_static_key = key
				_static_age = 0.0
				sv.size = Vector2i(maxi(8, int(scr.size.x)), maxi(8, int(scr.size.y)))
				painter.queue_redraw()
				sv.render_target_update_mode = SubViewport.UPDATE_ONCE
			view.queue_redraw()


# ---------------------------------------------------------------- the camera

func _screen() -> Rect2:
	var bez := 14.0
	return Rect2(Vector2(bez, bez + 18.0), size - Vector2(bez * 2.0, bez * 2.0 + 18.0))


func _fit() -> float:
	var s := _screen().size
	return minf(s.x / VW, s.y / VH)


## Map space -> the view's own space: [scale, offset].
func _xf() -> Array:
	var vs := _screen().size
	var k := _fit() * zoom
	_clamp_cam(k)
	return [k, vs * 0.5 - cam * k]


func _clamp_cam(k: float) -> void:
	var vs := _screen().size
	var hx := vs.x * 0.5 / k
	var hy := vs.y * 0.5 / k
	cam.x = VW * 0.5 if hx * 2.0 >= VW else clampf(cam.x, hx, VW - hx)
	cam.y = VH * 0.5 if hy * 2.0 >= VH else clampf(cam.y, hy, VH - hy)


## Map point -> the view's space.
func mv(p: Vector2) -> Vector2:
	var x := _xf()
	return Vector2(x[1]) + p * float(x[0])


## Map point -> this control's space.
func m2c(p: Vector2) -> Vector2:
	return _screen().position + mv(p)


## This control's space -> map point.
func c2m(p: Vector2) -> Vector2:
	var x := _xf()
	return (p - _screen().position - Vector2(x[1])) / float(x[0])


func zoom_at(cp: Vector2, factor: float) -> void:
	var before := c2m(cp)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var k := _fit() * zoom
	cam = before - (cp - _screen().position - _screen().size * 0.5) / k
	_dirty = true


func center_on(p: Vector2, z: float = -1.0) -> void:
	if z > 0.0:
		zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	cam = p
	_dirty = true


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


func go(place: String, taxi: bool = false) -> void:
	by_taxi = taxi
	walk_route = route(GameData.pilot_at, place)
	walk_to = place
	walk_t = 0.0


# ---------------------------------------------------------------- touch, mouse and the buttons

## The corner buttons: [rect, what] in this control's space.
func _buttons() -> Array:
	var scr := _screen()
	var b := 34.0
	var x := scr.end.x - b - 8.0
	var y := scr.end.y - b * 3.0 - 16.0
	return [[Rect2(x, y, b, b), "in"], [Rect2(x, y + b + 4.0, b, b), "out"], [Rect2(x, y + (b + 4.0) * 2.0, b, b), "me"]]


func _press_button(p: Vector2) -> bool:
	for bt in _buttons():
		if (bt[0] as Rect2).has_point(p):
			match str(bt[1]):
				"in":
					zoom_at(_screen().get_center(), 1.5)
				"out":
					zoom_at(_screen().get_center(), 1.0 / 1.5)
				"me":
					center_on(place_pos(GameData.pilot_at), maxf(zoom, 2.2))
			Sfx.play("click", 0.1, -6.0)
			return true
	return false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_touch_seen = true
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag_from = e.position
				_dragged = 0.0
			_pinch = _pinch_len()
		else:
			_touches.erase(e.index)
			if _touches.is_empty() and _dragged < 12.0 and _drag_from != Vector2.INF:
				_tap(e.position)
			if _touches.is_empty():
				_drag_from = Vector2.INF
			else:
				_dragged = 99.0   # one finger left after a pinch: don't count it as a tap
			_pinch = _pinch_len()
		accept_event()
		return
	if e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var d := _pinch_len()
			if _pinch > 1.0 and d > 1.0:
				zoom_at(_pinch_mid(), d / _pinch)
			_pinch = d
			_dragged = 99.0
		else:
			_pan(e.relative)
		accept_event()
		return
	if _touch_seen:
		return   # a phone sends a mouse copy of every touch: the touch already did it
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom_at(e.position, 1.15)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom_at(e.position, 1.0 / 1.15)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag_from = e.position
				_dragged = 0.0
			else:
				if _drag_from != Vector2.INF and _dragged < 12.0:
					_tap(e.position)
				_drag_from = Vector2.INF
			accept_event()
	elif e is InputEventMouseMotion and _drag_from != Vector2.INF and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_pan(e.relative)
		accept_event()


func _pan(rel: Vector2) -> void:
	_dragged += rel.length()
	if _dragged >= 12.0:
		cam -= rel / (_fit() * zoom)
		_dirty = true


func _pinch_len() -> float:
	if _touches.size() < 2:
		return 0.0
	var v: Array = _touches.values()
	return (v[0] as Vector2).distance_to(v[1])


func _pinch_mid() -> Vector2:
	var v: Array = _touches.values()
	return ((v[0] as Vector2) + (v[1] as Vector2)) * 0.5


func _tap(p: Vector2) -> void:
	if _press_button(p):
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
		_dirty = true


# ---------------------------------------------------------------- building the city (once, seeded)

var _sea_pa := PackedVector2Array(SEA)


func _on_land(p: Vector2) -> bool:
	return not Geometry2D.is_point_in_polygon(p, _sea_pa)


func _clear(r: Rect2) -> bool:
	for k in KEEP_CLEAR:
		if (k as Rect2).intersects(r):
			return false
	for pk in PARKS:
		if (pk[1] as Rect2).grow(2.0).intersects(r):
			return false
	return true


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_blocks = []
	_streets = []
	_names = []
	_greens = []
	_trees = []
	_ground = []
	var sea := PackedVector2Array(SEA)
	for reg0 in REGIONS:
		var rr: Rect2 = reg0[0]
		var rp := PackedVector2Array([rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)])
		var gcol: Color = Color(0.16, 0.16, 0.16) if str(reg0[3]) == "sheds" else (reg0[2] as Color).darkened(0.35)
		for part in Geometry2D.clip_polygons(rp, sea):
			_ground.append([part, gcol])
	for ri in REGIONS.size():
		var reg: Array = REGIONS[ri]
		var r: Rect2 = reg[0]
		var sp: float = reg[1]
		var kind: String = reg[3]
		# the grid lines, a few dropped so some blocks are bigger, a little wobble so it isn't graph paper
		var xs: Array = [r.position.x]
		var x := r.position.x + sp
		while x < r.end.x - sp * 0.4:
			if rng.randf() > 0.18:
				xs.append(x + rng.randf_range(-2.0, 2.0))
			x += sp
		xs.append(r.end.x)
		var ys: Array = [r.position.y]
		var y := r.position.y + sp
		while y < r.end.y - sp * 0.4:
			if rng.randf() > 0.18:
				ys.append(y + rng.randf_range(-2.0, 2.0))
			y += sp
		ys.append(r.end.y)
		var sw := 2.6 if kind != "towers" else 3.4
		# streets: each piece between crossings, kept when it's on land and not over a cleared place
		for i in xs.size():
			for j in ys.size() - 1:
				var a := Vector2(xs[i], ys[j])
				var b := Vector2(xs[i], ys[j + 1])
				if _on_land(a.lerp(b, 0.5)) and _clear(Rect2(a - Vector2(1, 0), b - a + Vector2(2, 0))):
					_streets.append([a, b, sw * (1.5 if i == xs.size() / 2 else 1.0)])
		for j in ys.size():
			for i in xs.size() - 1:
				var a2 := Vector2(xs[i], ys[j])
				var b2 := Vector2(xs[i + 1], ys[j])
				if _on_land(a2.lerp(b2, 0.5)) and _clear(Rect2(a2 - Vector2(0, 1), b2 - a2 + Vector2(0, 2))):
					_streets.append([a2, b2, sw * (1.5 if j == ys.size() / 2 else 1.0)])
		# the district's two named streets: the middle line each way
		var mx: float = xs[xs.size() / 2]
		var my: float = ys[ys.size() / 2]
		_names.append([Vector2(mx, r.position.y), Vector2(mx, r.end.y), str(STREETS[ri][0])])
		_names.append([Vector2(r.position.x, my), Vector2(r.end.x, my), str(STREETS[ri][1])])
		# the blocks
		for i in xs.size() - 1:
			for j in ys.size() - 1:
				var cell := Rect2(Vector2(xs[i], ys[j]), Vector2(float(xs[i + 1]) - float(xs[i]), float(ys[j + 1]) - float(ys[j]))).grow(-sw * 0.5 - 0.6)
				if cell.size.x < 4.0 or cell.size.y < 4.0:
					continue
				var corners := [cell.position, Vector2(cell.end.x, cell.position.y), cell.end, Vector2(cell.position.x, cell.end.y)]
				var wet := 0
				for c in corners:
					if not _on_land(c):
						wet += 1
				if wet == 4:
					continue
				if not _clear(cell):
					continue
				if wet > 0 or rng.randf() < 0.05:
					# by the water, or now and then: a green (cut to the shore)
					var poly := PackedVector2Array(corners)
					for part in Geometry2D.clip_polygons(poly, sea):
						_greens.append([part, true])
						_scatter_trees(rng, (part as PackedVector2Array), 3 + int(cell.get_area() / 160.0))
					continue
				_fill_block(rng, cell, reg)
	# the named parks and plazas
	for pk in PARKS:
		var pr: Rect2 = pk[1]
		var pp := PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)])
		_greens.append([pp, str(pk[2]) == "park"])
		if str(pk[2]) == "park":
			_scatter_trees(rng, pp, int(pr.get_area() / 60.0))


func _scatter_trees(rng: RandomNumberGenerator, poly: PackedVector2Array, n: int) -> void:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		bb = bb.expand(q)
	for k in n:
		var p := Vector2(rng.randf_range(bb.position.x + 2, bb.end.x - 2), rng.randf_range(bb.position.y + 2, bb.end.y - 2))
		if Geometry2D.is_point_in_polygon(p, poly):
			_trees.append([p, rng.randf_range(1.6, 3.2)])


## Lots on a block: houses are many small roofs, sheds one or two long ones, towers a tall block with a plaza round it.
func _fill_block(rng: RandomNumberGenerator, cell: Rect2, reg: Array) -> void:
	var kind: String = reg[3]
	var base: Color = reg[2]
	var lots: Array = []
	match kind:
		"houses":
			var nx := maxi(1, int(cell.size.x / 9.0))
			var ny := maxi(1, int(cell.size.y / 9.0))
			for i in nx:
				for j in ny:
					if i > 0 and i < nx - 1 and j > 0 and j < ny - 1:
						continue   # back gardens in the middle
					lots.append(Rect2(cell.position + Vector2(i * cell.size.x / nx, j * cell.size.y / ny), Vector2(cell.size.x / nx, cell.size.y / ny)).grow(-0.8))
			if nx > 2 and ny > 2:
				_greens.append([PackedVector2Array([cell.position + Vector2(cell.size.x / nx, cell.size.y / ny), cell.position + Vector2(cell.size.x * (nx - 1) / nx, cell.size.y / ny),
						cell.position + Vector2(cell.size.x * (nx - 1) / nx, cell.size.y * (ny - 1) / ny), cell.position + Vector2(cell.size.x / nx, cell.size.y * (ny - 1) / ny)]), true])
		"sheds":
			if cell.size.x > cell.size.y:
				lots = [Rect2(cell.position, Vector2(cell.size.x * 0.55, cell.size.y)).grow(-1.0), Rect2(cell.position + Vector2(cell.size.x * 0.55, 0), Vector2(cell.size.x * 0.45, cell.size.y)).grow(-1.0)]
			else:
				lots = [cell.grow(-1.0)]
		"towers":
			if cell.size.x > 34.0 and rng.randf() < 0.6:
				lots = [Rect2(cell.position + Vector2(cell.size.x * 0.08, cell.size.y * 0.15), Vector2(cell.size.x * 0.38, cell.size.y * 0.7)),
						Rect2(cell.position + Vector2(cell.size.x * 0.56, cell.size.y * 0.25), Vector2(cell.size.x * 0.36, cell.size.y * 0.5))]
			else:
				lots = [Rect2(cell.position + cell.size * 0.18, cell.size * 0.64)]
			_greens.append([PackedVector2Array([cell.position, Vector2(cell.end.x, cell.position.y), cell.end, Vector2(cell.position.x, cell.end.y)]), rng.randf() < 0.5])
		_:
			var n := 1 + rng.randi() % 3
			var along := cell.size.x >= cell.size.y
			for i in n:
				var u0 := float(i) / n
				var u1 := float(i + 1) / n
				if along:
					lots.append(Rect2(cell.position.x + cell.size.x * u0, cell.position.y, cell.size.x * (u1 - u0), cell.size.y).grow(-0.9))
				else:
					lots.append(Rect2(cell.position.x, cell.position.y + cell.size.y * u0, cell.size.x, cell.size.y * (u1 - u0)).grow(-0.9))
	for l in lots:
		var lr: Rect2 = l
		if lr.size.x < 1.5 or lr.size.y < 1.5:
			continue
		var col := base.lightened(rng.randf_range(-0.06, 0.14))
		if kind == "sheds":
			col = [Color(0.3, 0.32, 0.35), Color(0.36, 0.22, 0.18), Color(0.24, 0.3, 0.36), Color(0.3, 0.3, 0.26)][rng.randi() % 4]
		var lit_odds: float = float({"towers": 0.7, "offices": 0.45, "old": 0.25, "houses": 0.2, "sheds": 0.08}.get(kind, 0.25))
		_blocks.append([lr, col, rng.randf() < lit_odds, kind, rng.randi()])


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var W := size.x
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


## The still layer (painted into the SubViewport): ground, streets, rooftops, names, pins.
func draw_static(c: CanvasItem) -> void:
	cv = c
	var f := ThemeDB.fallback_font
	var x := _xf()
	var k: float = x[0]
	cv.draw_set_transform(x[1], 0.0, Vector2(k, k))
	_satellite(k)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_labels(k)
	# pins: places you can go, landmarks you fight in (they stay the same size as you zoom)
	for key in GameData.PLACES:
		var pl: Dictionary = GameData.PLACES[key]
		var cp := mv(place_pos(key))
		var kind := str(pl["kind"])
		var col: Color = PIN.get(kind, Color.WHITE)
		var locked := GameData.place_locked(key) != "" and kind != "venue"
		if locked:
			col = Color(0.35, 0.35, 0.38)
		var r := 10.0 if kind != "venue" else 6.0
		if kind == "venue":
			# (1.116) the halls are landmarks, not places to walk to: a small marker, no pin (Gus drives you on fight night)
			var sq := Rect2(cp - Vector2(r, r), Vector2(r, r) * 2.0)
			cv.draw_rect(sq.grow(2.0), Color(0.03, 0.03, 0.04))
			cv.draw_rect(sq, Color(0.62, 0.62, 0.7, 0.55))
			cv.draw_rect(sq, Color(0.85, 0.85, 0.9), false, 1.5)
		else:
			cv.draw_circle(cp, r + 2.0, Color(0.03, 0.03, 0.04))
			cv.draw_circle(cp, r, col)
			_glyph(kind, cp, locked)
		if kind == "venue" and key != selected and key != "kane_arena" and zoom < 2.0:
			continue   # the halls are landmarks: named when you tap them (or zoom in)
		var name := I18n.t(str(pl["name"]))
		var lfs := UI.px(11)
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
		cv.draw_string_outline(f, cp + Vector2(-nw * 0.5, r + 15), name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, 4, Color(0.02, 0.02, 0.03))
		cv.draw_string(f, cp + Vector2(-nw * 0.5, r + 15), name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.92, 0.92, 0.95) if not locked else Color(0.55, 0.55, 0.6))


## Everything inside the screen (called by the MapView while it draws; cv = the view): the still
## layer's texture, then the moving bits live.
func draw_map(c: CanvasItem) -> void:
	cv = c
	var f := ThemeDB.fallback_font
	cv.draw_texture(sv.get_texture(), Vector2.ZERO)
	var x := _xf()
	var k: float = x[0]
	cv.draw_set_transform(x[1], 0.0, Vector2(k, k))
	_dynamic(k)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selected != "" and GameData.PLACES.has(selected):
		var sr := 10.0 if str(GameData.PLACES[selected]["kind"]) != "venue" else 8.0
		cv.draw_arc(mv(place_pos(selected)), sr + 6.0 + sin(t * 5.0) * 1.5, 0, TAU, 24, Color(0.95, 0.76, 0.19, 0.7), 3.0)
	# the route to the picked place, with the hours it takes
	var dest := walk_to if walk_to != "" else selected
	if dest != "" and dest != GameData.pilot_at and GameData.PLACES.has(dest) and not GameData.PLACES[dest].has("venue"):
		var pts: Array = route(GameData.pilot_at, dest) if walk_t < 0.0 else walk_route
		var cpts: Array = pts.map(func(q): return mv(q))
		var dash := 0.0
		for i in cpts.size() - 1:
			var a: Vector2 = cpts[i]
			var b: Vector2 = cpts[i + 1]
			var L := a.distance_to(b)
			var s := 0.0
			while s < L:
				var e := minf(L, s + 8.0)
				if fmod(dash + s - t * 30.0, 14.0) < 8.0:
					cv.draw_line(a.lerp(b, s / L), a.lerp(b, e / L), Color(0.95, 0.76, 0.19), 3.0)
				s += 4.0
			dash += L
		var hrs := GameData.travel_hours(GameData.pilot_at, dest)
		var mid: Vector2 = cpts[cpts.size() / 2]
		var txt := (I18n.t("%d min") % roundi(hrs * 60.0)) if hrs < 0.99 else I18n.t("%s h") % ("%.1f" % hrs).trim_suffix(".0")
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(13)).x + 14.0
		cv.draw_rect(Rect2(mid + Vector2(-tw * 0.5, -30), Vector2(tw, 22)), Color(0.05, 0.05, 0.07, 0.9))
		cv.draw_rect(Rect2(mid + Vector2(-tw * 0.5, -30), Vector2(tw, 22)), Color(0.95, 0.76, 0.19), false, 1.5)
		cv.draw_string(f, mid + Vector2(-tw * 0.5, -14), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, UI.px(13), Color(0.95, 0.76, 0.19))
	# you: a little walking figure
	var me := mv(place_pos(GameData.pilot_at)) + Vector2(-16, -16)
	var walking := walk_t >= 0.0
	if walking:
		me = _along(walk_route.map(func(q): return mv(q)), walk_t) + Vector2(0, -14)
	if walking and by_taxi:
		var ahead := _along(walk_route.map(func(q): return mv(q)), minf(1.0, walk_t + 0.02)) + Vector2(0, -14)
		_taxi(me, ahead.x >= me.x)
	else:
		_walker(me, walking)
	# the corner buttons: zoom in, zoom out, back to you
	var so := _screen().position
	for bt in _buttons():
		var br: Rect2 = (bt[0] as Rect2)
		br.position -= so
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.13, 0.88)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.4, 0.42, 0.46)
		sb.set_border_width_all(1)
		cv.draw_style_box(sb, br)
		var cc := br.get_center()
		var ic := Color(0.9, 0.9, 0.92)
		match str(bt[1]):
			"in":
				cv.draw_line(cc + Vector2(-7, 0), cc + Vector2(7, 0), ic, 2.5)
				cv.draw_line(cc + Vector2(0, -7), cc + Vector2(0, 7), ic, 2.5)
			"out":
				cv.draw_line(cc + Vector2(-7, 0), cc + Vector2(7, 0), ic, 2.5)
			"me":
				cv.draw_arc(cc, 7.0, 0, TAU, 16, Color(0.55, 1.0, 0.65), 2.0)
				cv.draw_circle(cc, 2.5, Color(0.55, 1.0, 0.65))
	# a zoom scale under the buttons
	var zt := "x%.1f" % zoom
	var zr: Rect2 = _buttons()[1][0]
	var zp := Vector2(zr.position.x - so.x - 44.0, zr.get_center().y - so.y + 5.0)
	cv.draw_string_outline(f, zp, zt, HORIZONTAL_ALIGNMENT_RIGHT, 40, UI.px(10), 3, Color(0.02, 0.02, 0.03))
	cv.draw_string(f, zp, zt, HORIZONTAL_ALIGNMENT_RIGHT, 40, UI.px(10), Color(0.7, 0.72, 0.78))


## The part of the map the screen shows, in map units.
func _vis() -> Rect2:
	var x := _xf()
	var k: float = x[0]
	return Rect2(-Vector2(x[1]) / k, _screen().size / k)


## Night-time satellite view of Port Ferrum, in map units (cv's transform is the camera).
func _satellite(k: float) -> void:
	var vis := _vis()
	var near := zoom >= 1.8     # close enough for rooftop bits, windows and cars
	cv.draw_rect(vis, Color(0.11, 0.12, 0.11))
	var sea := Color(0.04, 0.08, 0.13)
	var box := PackedVector2Array([vis.position, Vector2(vis.end.x, vis.position.y), vis.end, Vector2(vis.position.x, vis.end.y)])
	for part in Geometry2D.intersect_polygons(PackedVector2Array(SEA), box):
		cv.draw_colored_polygon(part, sea)
	# the shore: a lighter line of surf along the coast, waves out at sea
	for i in SEA.size() - 1:
		var a: Vector2 = SEA[i]
		var b: Vector2 = SEA[i + 1]
		if a.y > -10.0 and b.y < 700.0 and a.x > -100.0:
			cv.draw_line(a, b, Color(0.2, 0.3, 0.38, 0.6), 2.0)
	for i in 10:
		var wp := Vector2(160.0 + i * 46.0, 540.0 + (i % 3) * 8.0)
		if not _on_land(wp):
			cv.draw_line(wp, wp + Vector2(18, 2), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	for gr in _ground:
		if _poly_vis(gr[0], vis):
			cv.draw_colored_polygon(gr[0], gr[1])
	# the arenas' car parks: bays marked out, parked cars close up
	for ki in range(1, 5):
		var cp: Rect2 = KEEP_CLEAR[ki]
		if not vis.intersects(cp):
			continue
		cv.draw_rect(cp, Color(0.15, 0.15, 0.16))
		var rows := int(cp.size.y / 10.0)
		for rw in rows:
			var yy := cp.position.y + 4.0 + rw * 10.0
			var n := int(cp.size.x / 4.0)
			for j in n:
				var xx := cp.position.x + 2.0 + j * 4.0
				cv.draw_line(Vector2(xx, yy), Vector2(xx, yy + 5.0), Color(0.3, 0.3, 0.3), 0.3)
				if near and (j * 7 + rw * 3 + ki) % 5 < 2:
					cv.draw_rect(Rect2(xx + 0.6, yy + 0.8, 2.8, 3.6), [Color(0.6, 0.2, 0.18), Color(0.3, 0.4, 0.6), Color(0.75, 0.75, 0.78), Color(0.2, 0.2, 0.22)][(j + rw) % 4])
	# greens: parks, back gardens, the shore strip, tower plazas
	for g in _greens:
		var poly: PackedVector2Array = g[0]
		if not _poly_vis(poly, vis):
			continue
		cv.draw_colored_polygon(poly, Color(0.12, 0.19, 0.12) if g[1] else Color(0.2, 0.2, 0.21))
	for tr2 in _trees:
		var tp: Vector2 = tr2[0]
		if vis.has_point(tp):
			cv.draw_circle(tp, tr2[1], Color(0.1, 0.26, 0.13))
			if near:
				cv.draw_circle(tp + Vector2(-0.6, -0.6), float(tr2[1]) * 0.55, Color(0.16, 0.34, 0.18))
	# the streets, their kerbs and lights
	for s in _streets:
		var a2: Vector2 = s[0]
		var b2: Vector2 = s[1]
		if not vis.grow(4.0).intersects(Rect2(a2, Vector2.ZERO).expand(b2)):
			continue
		cv.draw_line(a2, b2, Color(0.25, 0.25, 0.27), s[2])
		if near:
			cv.draw_line(a2, b2, Color(0.33, 0.33, 0.35), 0.4)
			var L := a2.distance_to(b2)
			var n := int(L / 9.0)
			for j in n:
				cv.draw_circle(a2.lerp(b2, (j + 0.5) / maxf(1, n)) + (b2 - a2).orthogonal().normalized() * float(s[2]) * 0.6, 0.55, Color(1.0, 0.8, 0.45, 0.7))
	# rooftops: lit skylights, and close up the bits on the roofs
	for bl in _blocks:
		var r: Rect2 = bl[0]
		if not vis.intersects(r):
			continue
		var col: Color = bl[1]
		cv.draw_rect(r, col)
		if near:
			cv.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.65, 0), Vector2(r.size.x * 0.35, r.size.y)), col.darkened(0.12))   # the roof's shade side
			var sd := int(bl[4])
			if r.size.x > 6.0 and r.size.y > 6.0:
				cv.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, r.size.y * 0.2), Vector2(2.2, 2.2)), col.darkened(0.4))   # a roof unit
				if sd % 3 == 0:
					cv.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.55), Vector2(2.6, 1.6)), col.darkened(0.35))
			if str(bl[3]) == "towers":
				cv.draw_rect(r, Color(0.88, 0.72, 0.29, 0.5), false, 0.6)   # Kane Heights: gold trim on the towers
		if bl[2]:
			cv.draw_rect(Rect2(r.position + r.size * 0.3, r.size * 0.4), Color(1.0, 0.8, 0.45, 0.32))
	# the plazas: paving, a fountain or a statue in the middle
	for pk in PARKS:
		var pr: Rect2 = pk[1]
		if str(pk[2]) == "plaza" and vis.intersects(pr):
			cv.draw_rect(pr, Color(0.3, 0.29, 0.27))
			for gi in 4:
				cv.draw_line(Vector2(pr.position.x, pr.position.y + pr.size.y * (gi + 1) / 5.0), Vector2(pr.end.x, pr.position.y + pr.size.y * (gi + 1) / 5.0), Color(0.34, 0.33, 0.31), 0.5)
			cv.draw_circle(pr.get_center(), minf(pr.size.x, pr.size.y) * 0.26, Color(0.2, 0.3, 0.4))
			cv.draw_circle(pr.get_center(), minf(pr.size.x, pr.size.y) * 0.12, Color(0.45, 0.6, 0.75, 0.75))
			for ci in 4:
				var a3 := ci * TAU / 4.0 + PI * 0.25
				cv.draw_circle(pr.get_center() + Vector2(cos(a3), sin(a3)) * minf(pr.size.x, pr.size.y) * 0.42, 1.5, Color(0.1, 0.26, 0.13))
	# the docks: piers into the water, container stacks, cranes seen from above
	for i in 4:
		var px := 150.0 + i * 70.0
		cv.draw_rect(Rect2(px, 470 + i * 12, 18, 60), Color(0.22, 0.21, 0.2))
		if near:
			for j in 6:
				cv.draw_line(Vector2(px, 474 + i * 12 + j * 10), Vector2(px + 18, 474 + i * 12 + j * 10), Color(0.18, 0.17, 0.16), 0.6)
			cv.draw_rect(Rect2(px + 4, 500 + i * 12, 10, 26), Color(0.32, 0.12, 0.1))   # a boat moored alongside
	cv.draw_rect(Rect2(244, 424, 166, 44), Color(0.17, 0.17, 0.17))   # the container yard's concrete
	var cc := [Color(0.6, 0.2, 0.15), Color(0.15, 0.35, 0.55), Color(0.65, 0.5, 0.15), Color(0.2, 0.45, 0.3)]
	for r2 in 3:
		for c2 in 7:
			cv.draw_rect(Rect2(250 + c2 * 22, 430 + r2 * 11, 19, 8), (cc[(r2 * 7 + c2) % 4] as Color).darkened(0.25))
			if near:
				cv.draw_line(Vector2(250 + c2 * 22 + 6, 430 + r2 * 11), Vector2(250 + c2 * 22 + 6, 438 + r2 * 11), Color(0, 0, 0, 0.25), 0.5)
				cv.draw_line(Vector2(250 + c2 * 22 + 13, 430 + r2 * 11), Vector2(250 + c2 * 22 + 13, 438 + r2 * 11), Color(0, 0, 0, 0.25), 0.5)
	for i in 3:
		var cx := 270.0 + i * 60.0
		cv.draw_line(Vector2(cx, 405), Vector2(cx + 30, 470), Color(0.8, 0.6, 0.2), 2.0)
		cv.draw_rect(Rect2(cx - 4, 401, 8, 8), Color(0.75, 0.55, 0.2))
	# (1.109) the Menagerie's circus ship moored off the end of the docks: a red hull, the striped big top on deck
	if GameData.place_locked("ship") == "" or GameData.story_seen.has("ship_docked"):
		var hull := PackedVector2Array()
		for i in 16:
			var a4 := i * TAU / 16.0
			hull.append(Vector2(452, 546) + Vector2(cos(a4) * 34.0, sin(a4) * 11.0))
		cv.draw_colored_polygon(hull, Color(0.55, 0.12, 0.1))
		cv.draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.9, 0.7, 0.25), 1.0)
		for i in 8:
			var a5 := i * TAU / 8.0
			cv.draw_colored_polygon(PackedVector2Array([Vector2(452, 544), Vector2(452, 544) + Vector2(cos(a5), sin(a5) * 0.6) * 9.0,
					Vector2(452, 544) + Vector2(cos(a5 + TAU / 8.0), sin(a5 + TAU / 8.0) * 0.6) * 9.0]), Color(0.85, 0.2, 0.15) if i % 2 == 0 else Color(0.92, 0.86, 0.72))
	# the scrapyard: heaps of dead robots, a fence round them
	cv.draw_rect(Rect2(92, 394, 124, 96), Color(0.18, 0.15, 0.12))
	cv.draw_rect(Rect2(92, 394, 124, 96), Color(0.4, 0.38, 0.34, 0.6), false, 1.0)
	var heaps := [[Vector2(120, 440), 26.0], [Vector2(165, 470), 20.0], [Vector2(140, 410), 16.0], [Vector2(190, 438), 14.0], [Vector2(200, 410), 10.0], [Vector2(110, 476), 9.0]]
	for h in heaps:
		cv.draw_circle(h[0], h[1], Color(0.26, 0.19, 0.13))
		cv.draw_circle(h[0] + Vector2(-4, -4), float(h[1]) * 0.6, Color(0.33, 0.24, 0.15))
		if near:
			for j in 5:
				var hp: Vector2 = (h[0] as Vector2) + Vector2(cos(j * 2.3), sin(j * 2.3)) * float(h[1]) * 0.5
				cv.draw_rect(Rect2(hp, Vector2(2.5, 1.6)), Color(0.42, 0.34, 0.26))
	# (1.101) the airfield at the edge of Midtown: grass, a runway with its centre line, the hangar's roof
	cv.draw_rect(Rect2(780, 440, 220, 120), Color(0.13, 0.17, 0.12))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(800, 500), Vector2(990, 470), Vector2(994, 482), Vector2(804, 512)]), Color(0.24, 0.24, 0.26))
	for i in 8:
		var u := 0.08 + i * 0.12
		cv.draw_line(Vector2(800, 506).lerp(Vector2(992, 476), u), Vector2(800, 506).lerp(Vector2(992, 476), u + 0.05), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	cv.draw_colored_polygon(PackedVector2Array([Vector2(820, 530), Vector2(960, 508), Vector2(962, 514), Vector2(822, 536)]), Color(0.2, 0.2, 0.22))   # the taxiway
	cv.draw_rect(Rect2(830, 448, 40, 22), Color(0.55, 0.58, 0.62))
	cv.draw_line(Vector2(830, 459), Vector2(870, 459), Color(0.42, 0.45, 0.5), 1.0)
	if near:
		cv.draw_colored_polygon(PackedVector2Array([Vector2(900, 452), Vector2(916, 456), Vector2(900, 460), Vector2(904, 456)]), Color(0.85, 0.88, 0.92))   # a little plane
	# the halls and arenas, seen from above
	_stadium(Vector2(246, 484), Vector2(26, 16), Color(0.5, 0.35, 0.2))
	_stadium(Vector2(596, 360), Vector2(32, 20), Color(0.35, 0.45, 0.6))
	_stadium(Vector2(700, 300), Vector2(36, 22), Color(0.4, 0.5, 0.75))
	_stadium(Vector2(800, 236), Vector2(42, 26), Color(0.6, 0.5, 0.35))
	_stadium(Vector2(880, 120), Vector2(64, 40), Color(0.75, 0.15, 0.2))
	# the avenue, its street lights, and cars running both ways at night
	for i in AVENUE.size() - 1:
		cv.draw_line(AVENUE[i], AVENUE[i + 1], Color(0.3, 0.3, 0.32), 7.0)
		cv.draw_line(AVENUE[i], AVENUE[i + 1], Color(0.42, 0.42, 0.44), 1.0)
		var a6: Vector2 = AVENUE[i]
		var b6: Vector2 = AVENUE[i + 1]
		var nrm := (b6 - a6).orthogonal().normalized()
		for s2 in 4:
			cv.draw_circle(a6.lerp(b6, (s2 + 0.5) / 4.0) + nrm * 6.0, 1.6, Color(1.0, 0.8, 0.4, 0.8))
	# side streets to every place
	for key in GameData.PLACES:
		var pl: Dictionary = GameData.PLACES[key]
		cv.draw_line(place_pos(key), AVENUE[int(pl["road"])], Color(0.29, 0.29, 0.31), 3.0)


## The moving bits, drawn live over the still layer: waves, cars on the avenue, the towers'
## air-warning lights, the runway lights.
func _dynamic(k: float) -> void:
	var vis := _vis()
	for i in 16:
		var wy := 20.0 + i * 36.0
		var wx := fmod(i * 53.0 + t * 3.0, 50.0)
		cv.draw_line(Vector2(wx - 10, wy), Vector2(wx + 14, wy + 2), Color(0.16, 0.26, 0.36, 0.5), 1.0)
	if zoom >= 1.4:
		for i in AVENUE.size() - 1:
			var a6: Vector2 = AVENUE[i]
			var b6: Vector2 = AVENUE[i + 1]
			var nrm := (b6 - a6).orthogonal().normalized()
			for ci2 in 3:
				var u2 := fmod(t * 0.12 + ci2 / 3.0 + i * 0.37, 1.0)
				cv.draw_circle(a6.lerp(b6, u2) + nrm * 1.8, 0.9, Color(1.0, 0.95, 0.8))   # headlights one way
				cv.draw_circle(a6.lerp(b6, 1.0 - u2) - nrm * 1.8, 0.8, Color(1.0, 0.2, 0.15))   # tail lights the other
	if zoom >= 1.8:
		for bl in _blocks:
			if str(bl[3]) == "towers" and int(bl[4]) % 2 == 0:
				var r: Rect2 = bl[0]
				if vis.intersects(r):
					cv.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.18, Color(1.0, 0.25, 0.25, 0.5 + 0.5 * sin(t * 2.0 + int(bl[4]))))   # an air-warning light
	for i in 10:
		var lp := Vector2(800, 500).lerp(Vector2(990, 470), i / 9.0)
		if int(t * 4.0 + i) % 3 == 0:
			cv.draw_circle(lp, 0.9, Color(0.4, 0.7, 1.0))


func _poly_vis(poly: PackedVector2Array, vis: Rect2) -> bool:
	var bb := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		bb = bb.expand(q)
	return vis.intersects(bb)


## Names on the map, drawn at screen size: districts (far out), the avenue, streets and plazas (closer in).
func _labels(k: float) -> void:
	var f := ThemeDB.fallback_font
	var vis := _vis()
	if zoom < 2.6:
		var spots := {"docks": Vector2(110, 380), "oldtown": Vector2(270, 190), "midtown": Vector2(530, 242), "heights": Vector2(730, 54)}
		for d in spots:
			var p := mv(spots[d])
			var dfs := UI.px(15) if zoom < 1.6 else UI.px(13)
			cv.draw_string_outline(f, p, I18n.t(GameData.DISTRICTS[d]), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, 3, Color(0.03, 0.03, 0.04, 0.7))
			cv.draw_string(f, p, I18n.t(GameData.DISTRICTS[d]), HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(0.7, 0.72, 0.78, 0.6))
	if zoom >= 1.3:
		_street_label(AVENUE[2], AVENUE[3], "FERRUM AVENUE", UI.px(10), Color(0.95, 0.85, 0.6))
		_street_label(AVENUE[4], AVENUE[5], "FERRUM AVENUE", UI.px(10), Color(0.95, 0.85, 0.6))
	if zoom >= 1.9:
		for n in _names:
			var a: Vector2 = n[0]
			var b: Vector2 = n[1]
			# keep the label on the part of the street that's on screen
			var seg_r := Rect2(a, Vector2.ZERO).expand(b)
			if not vis.intersects(seg_r):
				continue
			var ca := Vector2(clampf(a.x, vis.position.x + 20.0 / k, vis.end.x - 20.0 / k), clampf(a.y, vis.position.y + 20.0 / k, vis.end.y - 20.0 / k))
			var cb := Vector2(clampf(b.x, vis.position.x + 20.0 / k, vis.end.x - 20.0 / k), clampf(b.y, vis.position.y + 20.0 / k, vis.end.y - 20.0 / k))
			if ca.distance_to(cb) * k < 90.0 or not _on_land(ca.lerp(cb, 0.5)):
				continue
			_street_label(ca, cb, str(n[2]), UI.px(9), Color(0.8, 0.82, 0.86))
	if zoom >= 1.6:
		for pk in PARKS:
			var pr: Rect2 = pk[1]
			if not vis.intersects(pr):
				continue
			var p2 := mv(pr.get_center())
			if _near_pin(p2):
				p2 += Vector2(0, mv(pr.end).y - p2.y + 10.0)   # under the plaza instead
			var pfs := UI.px(9)
			var nm := str(pk[0])
			var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
			var col := Color(0.6, 0.9, 0.6) if str(pk[2]) == "park" else Color(0.92, 0.85, 0.7)
			cv.draw_string_outline(f, p2 + Vector2(-w * 0.5, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, 3, Color(0.02, 0.03, 0.02))
			cv.draw_string(f, p2 + Vector2(-w * 0.5, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, col)


## A name laid along a street (turned to its angle, never upside down).
## Is a screen point too close to a pin (where its name goes) for another label?
func _near_pin(p: Vector2) -> bool:
	for key in GameData.PLACES:
		var q := mv(place_pos(key))
		if absf(q.x - p.x) < 70.0 and p.y - q.y > -22.0 and p.y - q.y < 34.0:
			return true
	return false


func _street_label(a: Vector2, b: Vector2, text: String, fsz: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var pa := mv(a)
	var pb := mv(b)
	if _near_pin(pa.lerp(pb, 0.5)):
		# slide it along the street away from the pin
		var alt := pa.lerp(pb, 0.25)
		if _near_pin(alt):
			alt = pa.lerp(pb, 0.75)
			if _near_pin(alt):
				return
		var half := (pb - pa) * 0.25
		pa = alt - half
		pb = alt + half
	if pb.x < pa.x:
		var tmp := pa
		pa = pb
		pb = tmp
	var ang := (pb - pa).angle()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	if pa.distance_to(pb) < w + 10.0:
		return
	cv.draw_set_transform(pa.lerp(pb, 0.5), ang, Vector2.ONE)
	cv.draw_string_outline(f, Vector2(-w * 0.5, fsz * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 3, Color(0.03, 0.03, 0.04))
	cv.draw_string(f, Vector2(-w * 0.5, fsz * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stadium(c: Vector2, r: Vector2, ring: Color) -> void:
	var x := _xf()
	var k: float = x[0]
	cv.draw_set_transform(Vector2(x[1]) + c * k, 0.0, r * k)
	cv.draw_circle(Vector2.ZERO, 1.0, Color(0.1, 0.1, 0.12))
	cv.draw_arc(Vector2.ZERO, 0.85, 0, TAU, 32, ring, 0.18)
	cv.draw_circle(Vector2.ZERO, 0.45, Color(0.16, 0.2, 0.17))
	if zoom >= 1.8:
		for i in 12:
			var a := i * TAU / 12.0
			cv.draw_line(Vector2(cos(a), sin(a)) * 0.55, Vector2(cos(a), sin(a)) * 0.8, Color(0.2, 0.2, 0.24), 0.05)   # the stands' aisles
		cv.draw_rect(Rect2(-0.12, -0.08, 0.24, 0.16), Color(0.85, 0.85, 0.9, 0.5))   # the ring
	cv.draw_set_transform(x[1], 0.0, Vector2(k, k))


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
	cv.draw_circle(p + Vector2(0, 2), 13.0, Color(0, 0, 0, 0.55))
	var sw := sin(t * 12.0) * (5.0 if walking else 0.0)
	cv.draw_circle(p + Vector2(0, -8), 3.5, c)
	cv.draw_line(p + Vector2(0, -4), p + Vector2(0, 4), c, 2.5)
	cv.draw_line(p + Vector2(0, 4), p + Vector2(-3 + sw * 0.5, 11), c, 2.0)
	cv.draw_line(p + Vector2(0, 4), p + Vector2(3 - sw * 0.5, 11), c, 2.0)
	cv.draw_line(p + Vector2(0, -2), p + Vector2(-4 - sw * 0.4, 3), c, 2.0)
	cv.draw_line(p + Vector2(0, -2), p + Vector2(4 + sw * 0.4, 3), c, 2.0)


## (1.117) A BotTaxi from above-ish: a yellow cab with a checker stripe and a roof light.
func _taxi(p: Vector2, right: bool) -> void:
	var dx := 1.0 if right else -1.0
	cv.draw_circle(p + Vector2(0, 4), 14.0, Color(0, 0, 0, 0.5))
	var body := Rect2(p + Vector2(-13, -6), Vector2(26, 11))
	cv.draw_rect(body.grow(1.5), Color(0.05, 0.05, 0.06))
	cv.draw_rect(body, Color(0.98, 0.8, 0.15))
	cv.draw_rect(Rect2(p + Vector2(-7, -12), Vector2(14, 7)), Color(0.05, 0.05, 0.06))
	cv.draw_rect(Rect2(p + Vector2(-6, -11), Vector2(12, 6)), Color(0.98, 0.8, 0.15))
	cv.draw_rect(Rect2(p + Vector2(-5 + dx * 1.5, -10), Vector2(4, 4)), Color(0.55, 0.75, 0.9))
	for k in 6:
		cv.draw_rect(Rect2(p + Vector2(-12 + k * 4, -1), Vector2(2, 2)), Color(0.05, 0.05, 0.06) if k % 2 == 0 else Color(1, 1, 1))
	cv.draw_rect(Rect2(p + Vector2(-2, -15), Vector2(4, 3)), Color(1.0, 0.95, 0.6) if fmod(t, 0.6) < 0.3 else Color(0.9, 0.6, 0.1))
	cv.draw_circle(p + Vector2(-8, 5), 3.0, Color(0.05, 0.05, 0.06))
	cv.draw_circle(p + Vector2(8, 5), 3.0, Color(0.05, 0.05, 0.06))
	cv.draw_circle(p + Vector2(13 * dx, -2), 1.6, Color(1.0, 1.0, 0.8))


func _glyph(kind: String, c: Vector2, locked: bool) -> void:
	var g := Color(0.05, 0.05, 0.06)
	if locked:
		# a padlock
		cv.draw_rect(Rect2(c + Vector2(-4, -1), Vector2(8, 6)), g)
		cv.draw_arc(c + Vector2(0, -1), 3.0, PI, TAU, 8, g, 1.6)
		return
	match kind:
		"home":
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(5, 5), c + Vector2(-5, 5)]), g)
		"pub":
			cv.draw_rect(Rect2(c + Vector2(-4, -4), Vector2(6, 9)), g)
			cv.draw_arc(c + Vector2(2.5, 0.5), 2.5, -PI * 0.5, PI * 0.5, 6, g, 1.5)
		"shop":
			cv.draw_line(c + Vector2(-4, 4), c + Vector2(2, -2), g, 2.5)
			cv.draw_arc(c + Vector2(3, -3), 2.6, deg_to_rad(-200), deg_to_rad(70), 8, g, 1.6)
		"scrap":
			cv.draw_arc(c, 4.0, 0, TAU, 8, g, 2.0)
			cv.draw_circle(c, 1.5, g)
		"maker":
			# a cog
			for k in 8:
				var a := k * TAU / 8.0
				cv.draw_line(c + Vector2(cos(a), sin(a)) * 3.0, c + Vector2(cos(a), sin(a)) * 5.5, g, 2.0)
			cv.draw_circle(c, 3.2, g)
			cv.draw_circle(c, 1.2, Color(0.85, 0.68, 0.22))
		"venue":
			cv.draw_arc(c, 4.0, 0, TAU, 12, g, 1.6)
			cv.draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), g, 1.2)
