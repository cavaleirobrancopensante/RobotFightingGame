extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotArt = preload("res://robot_art.gd")
## Draws a single robot part (from a part definition) zoomed to fit the box.

var part := {}       # part definition from GameData.PARTS
var health := 1.0
var trim := Color(0.85, 0.85, 0.9)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.14))
	if part.is_empty():
		return
	var kind: String = part["kind"]
	if kind == "reactor":
		var c := size * 0.5
		var col := Color(part["color"])
		draw_circle(c, size.y * 0.34, col.darkened(0.6))
		draw_circle(c, size.y * 0.26, col)
		draw_circle(c, size.y * 0.1, Color(1, 1, 1, 0.8))
		return
	if kind == "back":
		var bparts := {}
		for s2 in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
			bparts[s2] = {"alive": false}
		bparts["torso"] = {"alive": true, "shape": "box", "size": 1.0, "color": Color(0.25, 0.25, 0.3), "health": 1.0}
		var blook := {"parts": bparts, "trim": trim, "eye": Color(0.3, 0.3, 0.3), "scale": 1.0, "icon": true,
				"back": {"shape": part["shape"], "color": Color(part["color"])}}
		var bg := RobotArt.geom(blook)
		var br := Rect2((bg["torso"] as Rect2).position.x - 40.0, bg["top"] - 34.0, 70.0, bg["th"] + 50.0)
		var bsc := minf((size.x - 8.0) / br.size.x, (size.y - 8.0) / br.size.y)
		RobotArt.draw(self, size * 0.5 - br.get_center() * bsc, blook, {"scale": bsc, "jet": true, "boost": true})
		return
	var slot: String = {"head": "head", "torso": "torso", "arm": "arm_front", "leg": "leg_front"}[kind]
	var parts := {}
	for s in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		parts[s] = {"alive": false}
	parts[slot] = {"alive": true, "shape": part["shape"], "size": part["size"],
			"color": Color(part["color"]), "health": health}
	var look := {"parts": parts, "trim": trim, "eye": Color(1.0, 0.35, 0.2), "scale": 1.0, "icon": true}
	var rect := _bounds(look, slot)
	var sc := minf((size.x - 8.0) / rect.size.x, (size.y - 8.0) / rect.size.y)
	var base := size * 0.5 - rect.get_center() * sc
	RobotArt.draw(self, base, look, {"scale": sc})


func _bounds(look: Dictionary, slot: String) -> Rect2:
	var g := RobotArt.geom(look)
	match slot:
		"head":
			return (g["head"] as Rect2).grow_individual(10, 26, 10, 4)
		"torso":
			return (g["torso"] as Rect2).grow(8.0)
		"arm_front":
			var s: Vector2 = g["shoulder_front"]
			return Rect2(s.x - 14.0, s.y - 16.0, 70.0, 64.0)
		_:
			var h: Vector2 = g["hip_front"]
			return Rect2(h.x - 26.0, h.y - 8.0, 60.0, g["L"] + 14.0)
