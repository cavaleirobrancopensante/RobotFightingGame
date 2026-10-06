extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotArt = preload("res://robot_art.gd")
## A box that shows a robot standing on a floor. Used in the garage, menu, cups and story.
## With interactive = true, tapping a part emits part_tapped(slot) and highlights it.

signal part_tapped(slot: String)
signal background_tapped(pos: Vector2)   # a tap that missed the robot (the garage checks the trophy shelf)

var look := {}
var facing := 1
## The bay: the robot faces you, hanging on Gus's gantry. Tapped parts get a hazard-stripe outline,
## and callouts (short notes about the selected part) are drawn off to the side with a line to it.
var front := false
var hide_robot := false   # scenes without the robot (the pub)
var callouts: Array = []
var callout_font: Font
var show_floor := true
var anim := true
var interactive := false
var highlight := ""
var t := 0.0
var _base := Vector2.ZERO
var _sc := 1.0
## Garage scenes: the panel turns transparent and the robot stands where the scene wants it
## ([x as fraction of width, height as fraction of the panel]). Empty = classic centered preview.
var spot: Array = []
var robot_height := 0.0
## Body damage map shown above the robot (same as in the arena): slot -> health 0..1,
## or -1 for a slot that should have a part and doesn't. Empty = no map.
var part_health := {}
const MAP_BOXES := {
	"head": Rect2(-7, 0, 14, 12), "head2": Rect2(-19, 2, 10, 10), "torso": Rect2(-10, 14, 20, 22),
	"arm_front": Rect2(-18, 14, 6, 20), "arm_back": Rect2(12, 14, 6, 20),
	"arm_front2": Rect2(-25, 20, 5, 16), "arm_back2": Rect2(20, 20, 5, 16),
	"leg_front": Rect2(-8, 38, 7, 18), "leg_back": Rect2(1, 38, 7, 18),
}   # how tall the robot is drawn, in pixels (for the people around it)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


var _redraw_t := 0.0


func _process(delta: float) -> void:
	if anim and is_visible_in_tree():
		t += delta
		_redraw_t -= delta
		if _redraw_t <= 0.0:
			_redraw_t = 1.0 / 30.0   # idle animation doesn't need 60 fps
			queue_redraw()


func _draw() -> void:
	if look.is_empty() or hide_robot:
		return
	var floor_y := size.y - 20.0
	if show_floor and spot.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.17))
		draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color(0.4, 0.4, 0.5), 2.0)
	var g := RobotArt.geom(look)
	var tall: float = -(g["head"] as Rect2).position.y + 30.0
	_sc = clampf((size.y - 30.0) / tall, 0.3, 2.5) / look.get("scale", 1.0)
	_base = Vector2(size.x * 0.5, floor_y)
	if not spot.is_empty():
		_sc = clampf((size.y * float(spot[1]) - 10.0) / tall, 0.2, 2.5) / look.get("scale", 1.0)
		_base = Vector2(size.x * float(spot[0]), floor_y)
	robot_height = tall * _sc * look.get("scale", 1.0)
	if front:
		RobotArt.draw_front(self, _base, look, {"scale": _sc, "time": t})
	else:
		RobotArt.draw(self, _base, look, {"scale": _sc, "facing": facing, "time": t})
	if interactive and highlight != "":
		for r in _regions():
			if r[0] == highlight:
				var rect: Rect2 = r[1]
				var k: float = _sc * look.get("scale", 1.0)
				var f := 1 if front else facing
				# mirrored robots: flip the box's size too, then abs() puts it back the right way round
				var world := Rect2(_base + rect.position * k * Vector2(f, 1), rect.size * k * Vector2(f, 1))
				world = world.abs().grow(4.0)
				_hazard_rect(world)
				if not callouts.is_empty():
					_draw_callouts(world)
	if not part_health.is_empty():
		var k := 1.25
		# top-right corner of the scene, clear of signs, the scoreboard and the people
		draw_body_map(Vector2(size.x - 36.0 * k, 40.0), k)
	if interactive and spot.is_empty():   # (the garage says it in its message line instead)
		draw_string(ThemeDB.fallback_font, Vector2(6, 22), tr("Tap a part"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.45))


func _regions() -> Array:
	if front:
		var fl := RobotArt.front_regions(look)
		var fg := RobotArt.geom(look)
		var ft: Rect2 = fg["torso"]
		fl.insert(fl.size() - 1, ["back", Rect2(ft.position.x - 30.0, ft.position.y + 6.0, 26.0, ft.size.y * 0.6)])
		return fl
	var list := RobotArt.regions(look)
	var g := RobotArt.geom(look)
	var tr: Rect2 = g["torso"]
	list.insert(0, ["back", Rect2(tr.position.x - 34.0, tr.position.y, 34.0, tr.size.y * 0.8)])
	return list


## The garage zooms the preview in, so its rect pokes out over the top strip: only take taps inside
## the panel that holds it (otherwise it swallows taps meant for NEXT and the date).
func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var holder := get_parent_control()
	return holder == null or holder.get_global_rect().has_point(get_global_transform() * point)


func _gui_input(event: InputEvent) -> void:
	if not interactive or hide_robot:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k: float = _sc * look.get("scale", 1.0)
		var l: Vector2 = (event.position - _base) / k
		l.x *= 1 if front else facing
		for r in _regions():
			if (r[1] as Rect2).grow(8.0).has_point(l):
				part_tapped.emit(r[0])
				accept_event()
				return
		background_tapped.emit(event.position)


## Little green body over the robot: green = healthy, red = hurt, dark with a red edge = missing.
func draw_body_map(at: Vector2, k: float) -> void:
	var bg := Rect2(at + Vector2(-28, -4) * k, Vector2(56, 64) * k)
	draw_rect(bg, Color(0, 0, 0, 0.45))
	for slot in MAP_BOXES:
		if not part_health.has(slot):
			continue
		var r: Rect2 = MAP_BOXES[slot]
		r = Rect2(at + r.position * k, r.size * k)
		var h: float = part_health[slot]
		if h < 0.0:
			draw_rect(r, Color(0.15, 0.15, 0.17))
			draw_rect(r, Color(1.0, 0.25, 0.2), false, 1.5)
			continue
		var c := Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.35), h) if h < 1.0 else Color(0.3, 0.9, 0.35)
		draw_rect(r, c)



## A yellow-and-black striped outline that keeps running round and round the part (clockwise),
## one continuous loop: the stripes flow round the corners, and the stripe length is tuned so the
## pattern meets itself exactly where it starts.
func _hazard_rect(r: Rect2) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var lengths: Array = []
	var perimeter := 0.0
	for i in 4:
		var l: float = (corners[i] as Vector2).distance_to(corners[(i + 1) % 4])
		lengths.append(l)
		perimeter += l
	var pairs := maxi(4, int(round(perimeter / 16.0)))   # one yellow + one black stripe = a pair
	var stripe := perimeter / (pairs * 2.0)
	var offset := fmod(t * 34.0, stripe * 2.0)            # how far the loop has run
	draw_polyline(PackedVector2Array(corners + [corners[0]]), Color(0.08, 0.08, 0.08), 4.0)
	for k in pairs:
		var a := fmod(offset + k * stripe * 2.0, perimeter)
		_perimeter_line(corners, lengths, a, a + stripe, Color(0.95, 0.76, 0.19))


## Draws the stretch of a rectangle's outline between two distances along it (wrapping past the start).
func _perimeter_line(corners: Array, lengths: Array, from: float, to: float, c: Color) -> void:
	var pos := 0.0
	for lap in 2:   # a stripe can run past the start corner into the next lap
		for i in 4:
			var l: float = lengths[i]
			var s0 := maxf(from, pos)
			var s1 := minf(to, pos + l)
			if s1 > s0:
				var a: Vector2 = corners[i]
				var dir: Vector2 = ((corners[(i + 1) % 4] as Vector2) - a) / maxf(l, 0.001)
				draw_line(a + dir * (s0 - pos), a + dir * (s1 - pos), c, 4.0)
			pos += l


## Diagnostic callouts: a line from the part, an elbow, and a little dark label with the notes.
func _draw_callouts(part: Rect2) -> void:
	var font: Font = callout_font if callout_font else ThemeDB.fallback_font
	var fs := 13
	var w := 0.0
	for line in callouts:
		w = maxf(w, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var box := Vector2(w + 16.0, callouts.size() * 17.0 + 8.0)
	var anchor := part.get_center()
	var side := -1.0 if anchor.x <= _base.x + 4.0 else 1.0
	var edge := Vector2(part.position.x if side < 0 else part.end.x, anchor.y)
	# the garage zooms the scene in: keep the box inside the part of the panel you can actually see
	var lo := pivot_offset - pivot_offset / scale + Vector2(4, 4)
	var hi := pivot_offset + (size - pivot_offset) / scale - box - Vector2(4, 24)
	# first choice: up in the band over the gantry beam, with an elbow line climbing to it
	var k: float = _sc * look.get("scale", 1.0)
	var fg := RobotArt.front_geom(look)
	var top_y: float = (fg["head"] as Rect2).position.y
	if look["parts"].get("head2", {}).has("shape"):
		top_y = minf(top_y, (fg["head2"] as Rect2).position.y)
	var head_top := _base.y + top_y * k
	var line: PackedVector2Array
	var pos := Vector2.ZERO
	if head_top - 34.0 - box.y >= lo.y:
		var out_x := edge.x + side * 14.0
		pos = Vector2(clampf(out_x - box.x * 0.5, lo.x, maxf(lo.x, hi.x)), head_top - 34.0 - box.y)
		line = PackedVector2Array([edge, Vector2(out_x, edge.y), Vector2(out_x, pos.y + box.y)])
	else:
		var elbow := edge + Vector2(side * 22.0, -26.0)
		pos = Vector2(elbow.x - box.x if side < 0 else elbow.x, elbow.y - box.y * 0.5)
		pos.x = clampf(pos.x, lo.x, maxf(lo.x, hi.x))
		pos.y = clampf(pos.y, lo.y, maxf(lo.y, hi.y))
		var end := Vector2(pos.x + (box.x if side < 0 else 0.0), clampf(elbow.y, pos.y + 6.0, pos.y + box.y - 6.0))
		line = PackedVector2Array([edge, elbow, end])
	var lc := Color(0.95, 0.76, 0.19)
	draw_circle(edge, 3.5, lc)
	draw_polyline(line, lc, 2.0, true)
	draw_rect(Rect2(pos, box), Color(0.04, 0.04, 0.06, 0.88))
	draw_rect(Rect2(pos + Vector2(0, box.y - 3), Vector2(box.x, 3)), lc)
	for i in callouts.size():
		var c := Color(0.95, 0.95, 0.97) if i == 0 else Color(0.66, 0.67, 0.72)
		if str(callouts[i]).begins_with("!"):
			c = Color(1.0, 0.48, 0.35)
		draw_string(font, pos + Vector2(8, 18 + i * 17), str(callouts[i]).trim_prefix("!"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
