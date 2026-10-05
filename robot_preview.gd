extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotArt = preload("res://robot_art.gd")
## A box that shows a robot standing on a floor. Used in the garage, menu, cups and story.
## With interactive = true, tapping a part emits part_tapped(slot) and highlights it.

signal part_tapped(slot: String)

var look := {}
var facing := 1
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
var robot_height := 0.0   # how tall the robot is drawn, in pixels (for the people around it)


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
	if look.is_empty():
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
	RobotArt.draw(self, _base, look, {"scale": _sc, "facing": facing, "time": t})
	if interactive and highlight != "":
		for r in _regions():
			if r[0] == highlight:
				var rect: Rect2 = r[1]
				var k: float = _sc * look.get("scale", 1.0)
				var world := Rect2(_base + rect.position * k * Vector2(facing, 1), rect.size * k)
				world = world.abs()
				draw_rect(world.grow(4.0), Color(1.0, 0.85, 0.2, 0.9 + 0.1 * sin(t * 6.0)), false, 3.0)
	if interactive:
		draw_string(ThemeDB.fallback_font, Vector2(6, 22), "Tap a part", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.45))


func _regions() -> Array:
	var list := RobotArt.regions(look)
	var g := RobotArt.geom(look)
	var tr: Rect2 = g["torso"]
	list.insert(0, ["back", Rect2(tr.position.x - 34.0, tr.position.y, 34.0, tr.size.y * 0.8)])
	return list


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k: float = _sc * look.get("scale", 1.0)
		var l: Vector2 = (event.position - _base) / k
		l.x *= facing
		for r in _regions():
			if (r[1] as Rect2).grow(8.0).has_point(l):
				part_tapped.emit(r[0])
				accept_event()
				return
