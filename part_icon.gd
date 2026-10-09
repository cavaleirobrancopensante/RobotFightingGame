extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotArt = preload("res://robot_art.gd")
## Draws a single robot part (from a part definition) zoomed to fit the box.

var part := {}       # part definition from GameData.PARTS
var health := 1.0
var trim := Color(0.85, 0.85, 0.9)


func _draw() -> void:
	draw_part(self, Rect2(Vector2.ZERO, size), part, health, trim)
	draw_grade(self, Rect2(Vector2.ZERO, size), part)
	draw_maker(self, Rect2(Vector2.ZERO, size), part)


const GRADE_TAGS := ["", "S", "R", "I", "St", "Ti"]


## The grade chip in the icon's corner: Scrap, Rust, Iron, Steel, Titanium (junk has none).
static func draw_grade(ci: CanvasItem, box: Rect2, part: Dictionary) -> void:
	var g := int(part.get("grade", 0))
	if g < 1 or g >= GRADE_TAGS.size():
		return
	var col := Color(GameData.GRADE_COLORS[g])
	var fs := int(clampf(box.size.y * 0.24, 9.0, 16.0))
	var w := fs * (1.3 if GRADE_TAGS[g].length() > 1 else 0.95) + 4.0
	var r := Rect2(box.end - Vector2(w + 2.0, fs + 4.0), Vector2(w, fs + 2.0))
	ci.draw_rect(r, col)
	ci.draw_rect(r, col.darkened(0.5), false, 1.0)
	ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y - fs * 0.22), GRADE_TAGS[g], HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0.08, 0.08, 0.1))


## (1.90) The maker's logo in the icon's top-left corner (opposite the grade chip).
static func draw_maker(ci: CanvasItem, box: Rect2, part: Dictionary) -> void:
	var m := str(part.get("maker", ""))
	if m == "" or box.size.y < 26.0:
		return
	var r := clampf(box.size.y * 0.15, 6.0, 14.0)
	load("res://logos.gd").draw_logo(ci, load("res://makers.gd").logo(m), box.position + Vector2(r + 3.0, r + 3.0), r)


## Draw a part picture into any rect of any canvas (the results screen uses this too).
static func draw_part(ci: CanvasItem, box: Rect2, part: Dictionary, health: float = 1.0, trim: Color = Color(0.85, 0.85, 0.9)) -> void:
	ci.draw_rect(box, Color(0.1, 0.1, 0.14))
	if part.is_empty():
		return
	var size := box.size
	var o := box.position
	var kind: String = part["kind"]
	if kind == "reactor":
		var c := o + size * 0.5
		var col := Color(part["color"])
		ci.draw_circle(c, size.y * 0.34, col.darkened(0.6))
		ci.draw_circle(c, size.y * 0.26, col)
		ci.draw_circle(c, size.y * 0.1, Color(1, 1, 1, 0.8))
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
		RobotArt.draw(ci, o + size * 0.5 - br.get_center() * bsc, blook, {"scale": bsc, "jet": true, "boost": true})
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var slot: String = {"head": "head", "torso": "torso", "arm": "arm_front", "leg": "leg_front"}[kind]
	var parts := {}
	for s in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		parts[s] = {"alive": false}
	parts[slot] = {"alive": true, "shape": part["shape"], "size": part["size"],
			"color": Color(part["color"]), "health": health, "grade": int(part.get("grade", 3)), "maker": str(part.get("maker", ""))}
	var look := {"parts": parts, "trim": trim, "eye": Color(1.0, 0.35, 0.2), "scale": 1.0, "icon": true}
	var rect := _bounds(look, slot)
	var sc := minf((size.x - 8.0) / rect.size.x, (size.y - 8.0) / rect.size.y)
	var base := o + size * 0.5 - rect.get_center() * sc
	RobotArt.draw(ci, base, look, {"scale": sc})
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A part on its own in the world (a ripped-off part lying in the ring): centred on `center`,
## about `span` px across, turned by `rot`. No background box.
static func draw_part_at(ci: CanvasItem, center: Vector2, span: float, part: Dictionary, health: float, rot: float, trim: Color = Color(0.85, 0.85, 0.9), light: String = "") -> void:
	var kind: String = part.get("kind", "")
	if not kind in ["head", "torso", "arm", "leg"]:
		return
	var slot: String = {"head": "head", "torso": "torso", "arm": "arm_front", "leg": "leg_front"}[kind]
	var parts := {}
	for s in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		parts[s] = {"alive": false}
	parts[slot] = {"alive": true, "shape": part["shape"], "size": part["size"], "color": Color(part["color"]), "health": health, "grade": int(part.get("grade", 3)), "maker": str(part.get("maker", ""))}
	var look := {"parts": parts, "trim": trim, "eye": Color(0.25, 0.1, 0.08), "scale": 1.0, "icon": true}
	var rect := _bounds(look, slot)
	var sc := span / maxf(rect.size.x, rect.size.y)
	var base := center - (rect.get_center() * sc).rotated(rot)
	var pose := {"scale": sc, "rot": rot, "state": "limp"}
	if light != "":
		pose["light"] = light
	RobotArt.draw(ci, base, look, pose)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _bounds(look: Dictionary, slot: String) -> Rect2:
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
