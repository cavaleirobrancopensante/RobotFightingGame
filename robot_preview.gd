class_name RobotPreview
extends Control
## A box that shows a robot standing on a floor. Used in the garage, menu and story.

var look := {}
var facing := 1
var show_floor := true
var anim := true
var t := 0.0


func _process(delta: float) -> void:
	if anim:
		t += delta
		queue_redraw()


func _draw() -> void:
	if look.is_empty():
		return
	var floor_y := size.y - 20.0
	if show_floor:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.17))
		draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color(0.4, 0.4, 0.5), 2.0)
	var g := RobotArt.geom(look)
	var tall: float = -(g["head"] as Rect2).position.y + 30.0
	var sc: float = clampf((size.y - 30.0) / tall, 0.3, 2.5) / look.get("scale", 1.0)
	RobotArt.draw(self, Vector2(size.x * 0.5, floor_y), look, {"scale": sc, "facing": facing, "time": t})
