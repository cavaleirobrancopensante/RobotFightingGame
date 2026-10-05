extends RefCounted
## The little living scenes in the garage's left panel: Gus's bay, the parts website, the
## workbench, the scrapyard, the paint job, training, the team and the trophy wall.
## draw_back() draws behind the robot, draw_front() draws the people and props in front.

const I18n = preload("res://i18n.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")

## Where the robot stands in each scene: [x as fraction of width, height as fraction of panel]
const ROBOT_SPOT := {
	"build": [0.62, 0.74], "shop": [0.8, 0.5], "workshop": [0.74, 0.56], "scrap": [0.8, 0.5],
	"paint": [0.5, 0.72], "moves": [0.62, 0.7], "team": [0.64, 0.66], "cups": [0.68, 0.62],
}


static func robot_spot(scene: String) -> Array:
	return ROBOT_SPOT.get(scene, [0.5, 0.85])


## info: {"pilot": look, "paint": Color, "spark": seconds since last spark burst, "dig": seconds since last dig,
##        "found": text of the last dig find, "trophies": int, "backup": look or {}}
## The whole-screen background for a scene. stage = where the robot panel is (people and props go there).
static func draw_back(ci: CanvasItem, screen: Vector2, stage: Rect2, scene: String, t: float, info: Dictionary) -> void:
	var floor_screen := stage.end.y - 20.0
	_environment(ci, screen, floor_screen, scene, t, info)
	ci.draw_set_transform(stage.position, 0.0, Vector2.ONE)
	_props_back(ci, stage.size, scene, t, info)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Walls, sky and floor across the whole screen.
static func _environment(ci: CanvasItem, screen: Vector2, floor_y: float, scene: String, t: float, info: Dictionary) -> void:
	match scene:
		"build":
			_wall(ci, screen, floor_y, Color(0.2, 0.19, 0.17), Color(0.24, 0.23, 0.2))
		"shop":
			_wall(ci, screen, floor_y, Color(0.16, 0.17, 0.22), Color(0.2, 0.21, 0.27))
		"workshop":
			_wall(ci, screen, floor_y, Color(0.18, 0.16, 0.14), Color(0.22, 0.19, 0.16))
		"scrap":
			for k in 10:
				var c := Color(0.95, 0.55, 0.3).lerp(Color(0.15, 0.12, 0.25), k / 9.0)
				ci.draw_rect(Rect2(0, k * floor_y / 10.0, screen.x, floor_y / 10.0 + 1), c)
			ci.draw_circle(Vector2(screen.x * 0.72, floor_y * 0.35), 30, Color(1.0, 0.75, 0.4, 0.9))
			# more junk mountains far away, behind the menus
			_scrap_pile(ci, Vector2(screen.x * 0.62, floor_y), screen.x * 0.3, floor_y * 0.45, t)
			_scrap_pile(ci, Vector2(screen.x * 0.95, floor_y), screen.x * 0.2, floor_y * 0.6, t + 3.0)
			ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), Color(0.25, 0.2, 0.15))
		"paint":
			_wall(ci, screen, floor_y, Color(0.22, 0.22, 0.24), Color(0.26, 0.26, 0.28))
		"moves":
			_wall(ci, screen, floor_y, Color(0.15, 0.18, 0.2), Color(0.18, 0.21, 0.24))
		"team":
			_wall(ci, screen, floor_y, Color(0.18, 0.18, 0.22), Color(0.22, 0.22, 0.27))
		"cups":
			_wall(ci, screen, floor_y, Color(0.2, 0.16, 0.2), Color(0.24, 0.2, 0.24))
		_:
			ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.12, 0.12, 0.17))
	if scene != "scrap":
		ci.draw_line(Vector2(0, floor_y), Vector2(screen.x, floor_y), Color(0.4, 0.4, 0.45), 2.0)


## Props around the robot (in stage coordinates).
static func _props_back(ci: CanvasItem, size: Vector2, scene: String, t: float, info: Dictionary) -> void:
	var floor_y := size.y - 20.0
	match scene:
		"build":
			# pegboard of tools
			var pb := Rect2(10, 96, size.x * 0.34, size.y * 0.2)
			ci.draw_rect(pb, Color(0.42, 0.33, 0.22))
			for k in 4:
				var x := pb.position.x + 10 + k * (pb.size.x - 20) / 3.0
				ci.draw_line(Vector2(x, pb.position.y + 8), Vector2(x, pb.position.y + 8 + 22 + k % 2 * 10), Color(0.6, 0.6, 0.65), 3.0)
			ci.draw_circle(pb.get_center() + Vector2(0, 16), 7, Color(0.75, 0.2, 0.2))
			_sign(ci, Vector2(size.x * 0.62, 30), I18n.t("GUS'S BAY"), Color(0.95, 0.65, 0.35))
			_bay_trophies(ci, size, info)
			_lamp(ci, Vector2(size.x * 0.62, 0), size, t)
			# behind the robot: a stepladder, and your pilot up it checking the robot's head
			var spot: Array = ROBOT_SPOT["build"]
			var rh: float = size.y * float(spot[1]) - 10.0
			var lx: float = size.x * float(spot[0]) + rh * 0.2
			var top_y := floor_y - rh * 0.62
			var wood := Color(0.6, 0.45, 0.25)
			ci.draw_line(Vector2(lx - rh * 0.07, floor_y), Vector2(lx, top_y), wood, 4.0)
			ci.draw_line(Vector2(lx + rh * 0.1, floor_y), Vector2(lx + rh * 0.02, top_y), wood.darkened(0.25), 4.0)
			for k in 5:
				var f := float(k + 1) / 6.0
				var ry := lerpf(floor_y, top_y, f)
				ci.draw_line(Vector2(lerpf(lx - rh * 0.07, lx, f), ry), Vector2(lerpf(lx + rh * 0.1, lx + rh * 0.02, f), ry), wood, 3.0)
			var ps := clampf(size.y / 300.0, 0.6, 1.3)
			PilotArt.draw_person(ci, Vector2(lx + 4.0, lerpf(floor_y, top_y, 0.68)), ps, info.get("pilot", {}), -1.0, "point", t + 1.3)
			# oil stain and lift platform
			ci.draw_set_transform(Vector2(size.x * 0.3, floor_y + 8), 0, Vector2(1.0, 0.25))
			ci.draw_circle(Vector2.ZERO, 26, Color(0.05, 0.05, 0.06, 0.6))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			ci.draw_rect(Rect2(size.x * 0.56 - 50, floor_y - 6, 100, 8), Color(0.75, 0.6, 0.15))
			for k in 6:
				ci.draw_line(Vector2(size.x * 0.56 - 48 + k * 18, floor_y - 6), Vector2(size.x * 0.56 - 40 + k * 18, floor_y + 2), Color(0.15, 0.15, 0.15), 3.0)
		"shop":
			# window with the city at night
			var w := Rect2(size.x * 0.58, 22, size.x * 0.36, size.y * 0.32)
			ci.draw_rect(w, Color(0.05, 0.06, 0.12))
			for k in 6:
				var bx := w.position.x + 4 + k * w.size.x / 6.0
				var bh := w.size.y * (0.3 + 0.5 * fmod(k * 0.37, 1.0))
				ci.draw_rect(Rect2(bx, w.end.y - bh, w.size.x / 6.0 - 3, bh), Color(0.12, 0.13, 0.2))
				if int(t * 0.7 + k) % 3 == 0:
					ci.draw_rect(Rect2(bx + 4, w.end.y - bh + 6, 3, 3), Color(1.0, 0.85, 0.4))
			ci.draw_rect(w, Color(0.35, 0.35, 0.4), false, 3.0)
		"workshop":
			_sign(ci, Vector2(size.x * 0.3, 30), I18n.t("WORKSHOP"), Color(0.6, 0.85, 1.0))
			# shelves of parts
			for row in 2:
				var y := 50.0 + row * 34.0
				ci.draw_rect(Rect2(size.x * 0.5, y, size.x * 0.45, 4), Color(0.4, 0.3, 0.2))
				for k in 4:
					ci.draw_rect(Rect2(size.x * 0.52 + k * size.x * 0.1, y - 12 - (k + row) % 2 * 4, 14, 12 + (k + row) % 2 * 4), Color.from_hsv(fmod(k * 0.23 + row * 0.4, 1.0), 0.3, 0.55))
		"scrap":
			# a crane with its hook
			ci.draw_line(Vector2(size.x * 0.12, floor_y), Vector2(size.x * 0.12, 24), Color(0.25, 0.22, 0.2), 6.0)
			ci.draw_line(Vector2(size.x * 0.12, 26), Vector2(size.x * 0.62, 26), Color(0.25, 0.22, 0.2), 5.0)
			var hook_x := size.x * 0.5 + sin(t * 0.8) * 8.0
			ci.draw_line(Vector2(size.x * 0.5, 26), Vector2(hook_x, 70), Color(0.2, 0.2, 0.2), 2.0)
			ci.draw_arc(Vector2(hook_x, 76), 6, 0, PI * 1.3, 8, Color(0.3, 0.3, 0.3), 3.0)
			_scrap_pile(ci, Vector2(size.x * 0.38, floor_y), size.x * 0.42, size.y * 0.45, t)
		"paint":
			# drop cloth with splatters in the paint colour
			var pc: Color = info.get("paint", Color(0.8, 0.3, 0.2))
			ci.draw_rect(Rect2(10, floor_y - 4, size.x - 20, 10), Color(0.85, 0.82, 0.75))
			for k in 7:
				ci.draw_circle(Vector2(20 + k * (size.x - 40) / 6.0, floor_y + fmod(k * 3.7, 4.0)), 3 + k % 3, pc)
			for k in 5:
				ci.draw_circle(Vector2(size.x * (0.2 + k * 0.15), 40 + fmod(k * 13.0, 30.0)), 4 + k % 3, Color(pc.r, pc.g, pc.b, 0.5))
		"moves":
			# chalkboard of move inputs
			var b := Rect2(12, 22, size.x * 0.5, size.y * 0.3)
			ci.draw_rect(b, Color(0.1, 0.22, 0.15))
			ci.draw_rect(b, Color(0.5, 0.35, 0.2), false, 4.0)
			var f := ThemeDB.fallback_font
			ci.draw_string(f, b.position + Vector2(8, 24), I18n.t("↓ → P"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85))
			ci.draw_string(f, b.position + Vector2(8, 48), I18n.t("← → K"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85, 0.8))
			ci.draw_rect(Rect2(size.x * 0.45, floor_y - 6, size.x * 0.4, 6), Color(0.3, 0.3, 0.35))   # practice mat
		"team":
			_sign(ci, Vector2(size.x * 0.5, 30), I18n.t("TEAM"), Color(0.5, 0.8, 1.0))
		"cups":
			# trophy shelf: the cup trophies you've won
			var cups: Array = info.get("medals", []).filter(func(x): return x.get("kind", "") == "cup")
			ci.draw_rect(Rect2(12, 70, size.x - 24, 5), Color(0.45, 0.32, 0.2))
			for k in mini(cups.size(), int((size.x - 30) / 24.0)):
				draw_trophy(ci, Vector2(26.0 + k * 24.0, 70), "cup", int(cups[k].get("medal", 1)), 1.0)
			# posters
			for k in 2:
				var p := Rect2(16 + k * 70, 90, 56, 70)
				ci.draw_rect(p, Color.from_hsv(0.05 + k * 0.5, 0.5, 0.45))
				ci.draw_string(ThemeDB.fallback_font, p.position + Vector2(4, 20), I18n.t("CUP"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
		_:
			pass


## People and props in front, around the robot. robot_base / robot_h are in stage coordinates.
static func draw_front(ci: CanvasItem, stage: Rect2, scene: String, t: float, info: Dictionary, robot_base: Vector2, robot_h: float) -> void:
	ci.draw_set_transform(stage.position, 0.0, Vector2.ONE)
	info["_stage"] = stage.position
	_front(ci, stage.size, scene, t, info, robot_base, robot_h)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _front(ci: CanvasItem, size: Vector2, scene: String, t: float, info: Dictionary, robot_base: Vector2, robot_h: float) -> void:
	var floor_y := size.y - 20.0
	var s := clampf(size.y / 300.0, 0.6, 1.3)
	var pilot: Dictionary = info.get("pilot", {})
	var gus := PilotArt.GUS_LOOK
	match scene:
		"build":
			# Gus works on the robot's leg with a wrench, sparks fly (the pilot is up the ladder behind)
			PilotArt.draw_person(ci, Vector2(robot_base.x - 52 * s, floor_y), s, gus, 1.0, "wrench", t)
			var spark_age: float = info.get("spark", 99.0)
			if fmod(t, 2.4) < 0.25 or spark_age < 0.6:
				_sparks(ci, Vector2(robot_base.x - 22 * s, floor_y - robot_h * 0.25), t, 1.5 if spark_age < 0.6 else 1.0)
		"shop":
			# a desk with a computer showing the parts website
			var desk := Rect2(12, floor_y - 44 * s, size.x * 0.6, 8 * s)
			var mon := Rect2(desk.position.x + 50 * s, desk.position.y - 62 * s, 96 * s, 58 * s)
			ci.draw_rect(Rect2(desk.position.x + 8, desk.end.y, 6, floor_y - desk.end.y), Color(0.3, 0.22, 0.15))
			ci.draw_rect(Rect2(desk.end.x - 14, desk.end.y, 6, floor_y - desk.end.y), Color(0.3, 0.22, 0.15))
			ci.draw_rect(desk, Color(0.45, 0.32, 0.2))
			ci.draw_rect(Rect2(mon.get_center().x - 4, mon.end.y, 8, desk.position.y - mon.end.y), Color(0.2, 0.2, 0.22))
			ci.draw_rect(mon, Color(0.12, 0.12, 0.14))
			var scr := mon.grow(-4)
			ci.draw_rect(scr, Color(0.9, 0.93, 0.97))
			ci.draw_rect(Rect2(scr.position, Vector2(scr.size.x, 9 * s)), Color(0.9, 0.45, 0.2))
			ci.draw_string(ThemeDB.fallback_font, scr.position + Vector2(3, 8 * s), I18n.t("PARTS-R-US"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), Color.WHITE)
			var scroll := fmod(t * 6.0, 14.0 * s)
			for k in 6:
				var tile := Rect2(scr.position.x + 4 + (k % 3) * scr.size.x / 3.0, scr.position.y + 12 * s + int(k / 3.0) * 20 * s - scroll + 14 * s,
						scr.size.x / 3.0 - 6, 16 * s)
				if tile.position.y > scr.position.y + 10 * s and tile.end.y < scr.end.y:
					ci.draw_rect(tile, Color.from_hsv(fmod(k * 0.19, 1.0), 0.35, 0.8))
			ci.draw_rect(Rect2(mon.position.x + 10 * s, desk.position.y - 4 * s, 40 * s, 4 * s), Color(0.25, 0.25, 0.28))   # keyboard
			# the pilot types, Gus leans in and points at the screen
			ci.draw_rect(Rect2(mon.position.x - 2 * s, floor_y - 30 * s, 22 * s, 4 * s), Color(0.25, 0.25, 0.3))   # chair
			PilotArt.draw_person(ci, Vector2(mon.position.x + 8 * s, floor_y), s, pilot, 1.0, "sit_type", t)
			PilotArt.draw_person(ci, Vector2(mon.end.x + 22 * s, floor_y), s, gus, -1.0, "point", t + 0.7)
		"workshop":
			# workbench with a vise and a spinning grinder; both of them hard at work
			var bench := Rect2(10, floor_y - 40 * s, size.x * 0.62, 8 * s)
			ci.draw_rect(Rect2(bench.position.x + 6, bench.end.y, 8, floor_y - bench.end.y), Color(0.35, 0.25, 0.15))
			ci.draw_rect(Rect2(bench.end.x - 14, bench.end.y, 8, floor_y - bench.end.y), Color(0.35, 0.25, 0.15))
			ci.draw_rect(bench, Color(0.5, 0.36, 0.22))
			var vise := Vector2(bench.position.x + bench.size.x * 0.35, bench.position.y)
			ci.draw_rect(Rect2(vise + Vector2(-10 * s, -12 * s), Vector2(20 * s, 12 * s)), Color(0.35, 0.4, 0.5))
			ci.draw_rect(Rect2(vise + Vector2(-4 * s, -20 * s), Vector2(8 * s, 9 * s)), Color(0.6, 0.6, 0.65))   # the part being worked on
			var gr := Vector2(bench.position.x + bench.size.x * 0.82, bench.position.y - 10 * s)
			ci.draw_circle(gr, 9 * s, Color(0.3, 0.3, 0.32))
			for k in 4:
				var a := t * 14.0 + k * PI / 2.0
				ci.draw_line(gr, gr + Vector2(cos(a), sin(a)) * 8 * s, Color(0.6, 0.6, 0.62), 2.0)
			_sparks(ci, gr + Vector2(-8 * s, 4 * s), t * 1.7, 0.8)
			PilotArt.draw_person(ci, Vector2(vise.x - 22 * s, floor_y), s, gus, 1.0, "hammer", t)
			var goggled: Dictionary = pilot.duplicate()
			goggled["glasses"] = "goggles"
			PilotArt.draw_person(ci, Vector2(gr.x + 24 * s, floor_y), s, goggled, -1.0, "hold", t + 0.4)
			if fmod(t, 1.0) < 0.12:
				_sparks(ci, vise + Vector2(0, -20 * s), t, 1.0)
		"scrap":
			# the pilot digs into the pile; Gus points out something shiny
			var dig_age: float = info.get("dig", 99.0)
			var pile_x := size.x * 0.38
			PilotArt.draw_person(ci, Vector2(pile_x + 44 * s, floor_y), s, pilot, -1.0, "dig", t * (2.0 if dig_age < 1.0 else 0.6))
			PilotArt.draw_person(ci, Vector2(18 * s, floor_y), s * 0.95, gus, 1.0, "point", t + 0.3)
			if dig_age < 1.2:
				for k in 8:
					var a := -PI * (0.2 + 0.6 * k / 7.0)
					var r := 10.0 + dig_age * 60.0
					ci.draw_circle(Vector2(pile_x + 30 * s, floor_y - 10) + Vector2(cos(a), sin(a)) * r, 3.0 * (1.2 - dig_age), Color(0.5, 0.42, 0.3, 1.0 - dig_age / 1.2))
				var found: String = info.get("found", "")
				if found != "":
					var f := ThemeDB.fallback_font
					var y := floor_y - 90 * s - dig_age * 20.0
					ci.draw_string(f, Vector2(4, y), found, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 15, Color(1.0, 0.9, 0.5, 1.0 - dig_age / 1.2))
		"paint":
			var pc: Color = info.get("paint", Color(0.8, 0.3, 0.2))
			# cans of paint, and the two of them spraying the robot
			for k in 3:
				var cx := 20.0 + k * 22.0
				ci.draw_rect(Rect2(cx, floor_y - 18, 16, 18), Color(0.7, 0.7, 0.72))
				ci.draw_rect(Rect2(cx, floor_y - 12, 16, 8), pc if k == 0 else Color.from_hsv(fmod(k * 0.33 + 0.1, 1.0), 0.7, 0.8))
				ci.draw_rect(Rect2(cx - 1, floor_y - 20, 18, 3), Color(0.5, 0.5, 0.52))
			PilotArt.draw_person(ci, Vector2(robot_base.x - 60 * s, floor_y), s, pilot, 1.0, "spray", t, pc)
			PilotArt.draw_person(ci, Vector2(robot_base.x + 62 * s, floor_y), s, gus, -1.0, "spray", t + 0.9, pc)
		"moves":
			# training: the pilot drills inputs on the controller, Gus times it
			PilotArt.draw_person(ci, Vector2(26 * s, floor_y), s, pilot, 1.0, "hold", t)
			PilotArt.draw_person(ci, Vector2(size.x - 24 * s, floor_y), s * 0.95, gus, -1.0, "clipboard", t + 0.5)
		"team":
			var backup: Dictionary = info.get("backup", {})
			if not backup.is_empty():
				# the backup robot stands beside the main one, a little smaller
				var g := RobotArt.geom(backup)
				var tall: float = -(g["head"] as Rect2).position.y + 30.0
				var sc: float = robot_h * 0.75 / tall / float(backup.get("scale", 1.0))
				var origin: Vector2 = info.get("_stage", Vector2.ZERO)
				RobotArt.draw(ci, origin + Vector2(size.x * 0.24, floor_y), backup, {"scale": sc, "facing": 1, "time": t + 0.8})
				ci.draw_set_transform(origin, 0.0, Vector2.ONE)   # RobotArt changes the transform; put ours back
			if backup.is_empty():
				# an empty stand waiting for a backup robot
				ci.draw_rect(Rect2(14, floor_y - 6, 70, 6), Color(0.45, 0.45, 0.5))
				ci.draw_string(ThemeDB.fallback_font, Vector2(10, floor_y - 14), "backup?", HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color(1, 1, 1, 0.4))
			PilotArt.draw_person(ci, Vector2(size.x - 22 * s, floor_y), s * 0.9, pilot, -1.0, "cheer" if not backup.is_empty() else "idle", t)
		"cups":
			PilotArt.draw_person(ci, Vector2(28 * s, floor_y), s, pilot, 1.0, "cheer" if not info.get("medals", []).is_empty() else "point", t)


# ---------------------------------------------------------------- bits

static func _wall(ci: CanvasItem, size: Vector2, floor_y: float, c1: Color, c2: Color) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), c1)
	for k in int(size.x / 18.0) + 1:   # corrugated metal
		ci.draw_rect(Rect2(k * 18.0, 0, 9.0, floor_y), c2)
	ci.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color(0.28, 0.27, 0.27))


static func _sign(ci: CanvasItem, center: Vector2, text: String, c: Color) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
	ci.draw_rect(Rect2(center.x - w * 0.5, center.y - 14, w, 22), Color(0.08, 0.08, 0.1))
	ci.draw_rect(Rect2(center.x - w * 0.5, center.y - 14, w, 22), c, false, 2.0)
	ci.draw_string(f, Vector2(center.x - w * 0.5, center.y + 3), text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, c)


static func _lamp(ci: CanvasItem, top: Vector2, size: Vector2, t: float) -> void:
	var sway := sin(t * 0.9) * 6.0
	var bulb := top + Vector2(sway, 46)
	ci.draw_line(top, bulb, Color(0.15, 0.15, 0.15), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-12, 0), bulb + Vector2(12, 0), bulb + Vector2(70 + sway, size.y), bulb + Vector2(-70 + sway, size.y)]), Color(1.0, 0.9, 0.6, 0.07))
	ci.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-12, 0), bulb + Vector2(12, 0), bulb + Vector2(6, -8), bulb + Vector2(-6, -8)]), Color(0.3, 0.3, 0.3))
	ci.draw_circle(bulb + Vector2(0, 2), 4, Color(1.0, 0.9, 0.6))


static func _sparks(ci: CanvasItem, at: Vector2, t: float, power: float) -> void:
	for k in 7:
		var a := -PI * 0.15 - k * 0.42 + sin(t * 23.0 + k) * 0.3
		var r := (6.0 + fmod(t * 90.0 + k * 13.0, 22.0)) * power
		ci.draw_line(at + Vector2(cos(a), sin(a)) * r * 0.5, at + Vector2(cos(a), sin(a)) * r, Color(1.0, 0.8 - k * 0.05, 0.3), 2.0)


static func _scrap_pile(ci: CanvasItem, base: Vector2, w: float, h: float, t: float) -> void:
	# a big heap of dead robots: a dark mound with wheels, limbs and heads sticking out
	var pts := PackedVector2Array()
	for k in 13:
		var x := base.x - w + k * (2.0 * w / 12.0)
		var bump := sin(k * 1.7) * 0.12 + 1.0
		var y := base.y - h * bump * (1.0 - pow(absf(k - 6) / 6.0, 1.6))
		pts.append(Vector2(x, y))
	pts.append(base + Vector2(w, 0))
	pts.append(base + Vector2(-w, 0))
	ci.draw_colored_polygon(pts, Color(0.28, 0.24, 0.22))
	var junk := [[-0.6, 0.3, "wheel"], [-0.25, 0.7, "head"], [0.1, 0.85, "arm"], [0.4, 0.5, "wheel"], [-0.45, 0.55, "arm"],
			[0.25, 0.3, "head"], [0.65, 0.25, "plate"], [-0.05, 0.45, "plate"], [-0.8, 0.12, "plate"]]
	for j in junk:
		var p: Vector2 = base + Vector2(j[0] * w, -j[1] * h * 0.9)
		var c := Color(0.42, 0.38, 0.35).lerp(Color(0.55, 0.3, 0.2), fmod(absf(j[0]) * 3.0, 1.0))
		match j[2]:
			"wheel":
				ci.draw_circle(p, 9, Color(0.12, 0.12, 0.12))
				ci.draw_circle(p, 4, c)
			"head":
				ci.draw_rect(Rect2(p - Vector2(10, 8), Vector2(20, 16)), c)
				ci.draw_circle(p + Vector2(4, -1), 2.5, Color(0.2, 0.2, 0.2) if int(t * 0.5 + j[0] * 10) % 4 else Color(1.0, 0.3, 0.2))
			"arm":
				ci.draw_line(p, p + Vector2(18, -14), c, 6.0)
				ci.draw_circle(p + Vector2(18, -14), 4, c.darkened(0.2))
			"plate":
				ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(16, -6), p + Vector2(20, 6), p + Vector2(2, 8)]), c.darkened(0.15))


const MEDAL_COLORS := [Color(0.5, 0.5, 0.5), Color(0.95, 0.78, 0.25), Color(0.8, 0.82, 0.88), Color(0.8, 0.5, 0.25)]


## The bay's trophy wall: one trophy per medal - first, second or third place in a league, a
## playoff or a cup. Gold, silver or bronze; the shape tells you which event it's from.
static func _bay_trophies(ci: CanvasItem, size: Vector2, info: Dictionary) -> void:
	var list: Array = info.get("medals", [])
	var x0 := size.x * 0.42
	var w := size.x * 0.56
	var per_shelf := maxi(1, int((w - 10.0) / 26.0))
	var shown := mini(list.size(), per_shelf * 2)
	for k in shown:
		var shelf := k / per_shelf
		var shelf_y := 86.0 + shelf * 44.0
		if k % per_shelf == 0:
			ci.draw_rect(Rect2(x0, shelf_y, w, 5), Color(0.45, 0.32, 0.2))
		var tr: Dictionary = list[list.size() - shown + k]   # the newest ones
		var x := x0 + 14.0 + (k % per_shelf) * 26.0
		draw_trophy(ci, Vector2(x, shelf_y), str(tr.get("kind", "cup")), int(tr.get("medal", 1)), 1.0)
	_scoreboard(ci, Rect2(10, 24, size.x * 0.4, 62), info)
	# the championship belt hangs on the wall under the scoreboard
	if info.get("champion", false):
		var gold: Color = MEDAL_COLORS[1]
		var bc := Vector2(62, size.y * 0.47)
		ci.draw_rect(Rect2(bc.x - 52, bc.y - 6, 104, 12), Color(0.15, 0.12, 0.1))
		ci.draw_circle(bc, 16, gold)
		ci.draw_circle(bc, 10, Color(0.8, 0.15, 0.2))
		ci.draw_circle(bc, 4, gold)
		for side in [-1.0, 1.0]:
			ci.draw_circle(bc + Vector2(side * 32, 0), 7, gold)


## One trophy standing on a shelf at base. kind: scrap / regional / championship / cup.
static func draw_trophy(ci: CanvasItem, base: Vector2, kind: String, medal: int, s: float) -> void:
	var c: Color = MEDAL_COLORS[clampi(medal, 0, 3)]
	var dark := c.darkened(0.3)
	var wood := Color(0.35, 0.25, 0.18)
	match kind:
		"scrap":
			# a little robot welded together from scrap, arms up: bolt base, leg strut, box body, round head
			ci.draw_rect(Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), Color(0.3, 0.3, 0.32))
			ci.draw_circle(base + Vector2(-5, -2.5) * s, 1.3 * s, c)
			ci.draw_circle(base + Vector2(5, -2.5) * s, 1.3 * s, c)
			ci.draw_line(base + Vector2(-3, -5) * s, base + Vector2(-4, -12) * s, dark, 2.5 * s)
			ci.draw_line(base + Vector2(3, -5) * s, base + Vector2(4, -12) * s, dark, 2.5 * s)
			ci.draw_rect(Rect2(base + Vector2(-6, -21) * s, Vector2(12, 10) * s), c)
			ci.draw_line(base + Vector2(-6, -19) * s, base + Vector2(-11, -27) * s, c, 2.5 * s)
			ci.draw_line(base + Vector2(6, -19) * s, base + Vector2(11, -27) * s, c, 2.5 * s)
			ci.draw_circle(base + Vector2(-11, -28) * s, 2.0 * s, dark)   # gear fists
			ci.draw_circle(base + Vector2(11, -28) * s, 2.0 * s, dark)
			ci.draw_circle(base + Vector2(0, -26) * s, 5.0 * s, c)
			ci.draw_rect(Rect2(base + Vector2(-3.5, -27) * s, Vector2(7, 2) * s), Color(0.15, 0.1, 0.08))
		"regional":
			ci.draw_rect(Rect2(base + Vector2(-7, -6) * s, Vector2(14, 6) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-2, -13) * s, Vector2(4, 7) * s), c)
			ci.draw_arc(base + Vector2(0, -20) * s, 8 * s, 0, PI, 10, c, 6.0 * s)
			ci.draw_rect(Rect2(base + Vector2(-8.5, -26) * s, Vector2(17, 3) * s), c)
			ci.draw_arc(base + Vector2(-9, -21) * s, 3.5 * s, PI * 0.5, PI * 1.5, 6, c, 1.8 * s)
			ci.draw_arc(base + Vector2(9, -21) * s, 3.5 * s, -PI * 0.5, PI * 0.5, 6, c, 1.8 * s)
		"championship":
			# the big one: two-step base, tall stem, wide cup and a little robot on the lid
			ci.draw_rect(Rect2(base + Vector2(-10, -5) * s, Vector2(20, 5) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-7, -9) * s, Vector2(14, 4) * s), wood.lightened(0.1))
			ci.draw_rect(Rect2(base + Vector2(-2, -19) * s, Vector2(4, 10) * s), c)
			ci.draw_arc(base + Vector2(0, -27) * s, 10 * s, 0, PI, 12, c, 8.0 * s)
			ci.draw_rect(Rect2(base + Vector2(-11, -35) * s, Vector2(22, 3) * s), c)
			ci.draw_arc(base + Vector2(-12, -28) * s, 5 * s, PI * 0.5, PI * 1.5, 6, c, 2.0 * s)
			ci.draw_arc(base + Vector2(12, -28) * s, 5 * s, -PI * 0.5, PI * 0.5, 6, c, 2.0 * s)
			ci.draw_circle(base + Vector2(0, -38) * s, 3.0 * s, c)
			ci.draw_circle(base + Vector2(0, -28) * s, 2.5 * s, Color(0.9, 0.2, 0.25))
		_:   # cups: a small cup on a plinth
			ci.draw_rect(Rect2(base + Vector2(-5, -5) * s, Vector2(10, 5) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-1.5, -10) * s, Vector2(3, 5) * s), c)
			ci.draw_arc(base + Vector2(0, -15) * s, 6 * s, 0, PI, 8, c, 5.0 * s)
			ci.draw_rect(Rect2(base + Vector2(-6.5, -20) * s, Vector2(13, 2) * s), c)


## The LED scoreboard on the bay wall: wins, losses and what you've torn off other robots.
static func _scoreboard(ci: CanvasItem, r: Rect2, info: Dictionary) -> void:
	var st: Dictionary = info.get("stats", {})
	ci.draw_rect(r.grow(3), Color(0.25, 0.25, 0.28))
	ci.draw_rect(r, Color(0.03, 0.03, 0.04))
	var f := ThemeDB.fallback_font
	var fs := clampi(int(r.size.x / 11.5), 8, 13)
	var lines := [
		[I18n.t("W %d") % int(info.get("wins", 0)), I18n.t("L %d") % int(info.get("losses", 0)), Color(0.3, 1.0, 0.4), Color(1.0, 0.35, 0.25)],
		[I18n.t("HEADS %d") % int(st.get("heads", 0)), I18n.t("ARMS %d") % int(st.get("arms", 0)), Color(1.0, 0.75, 0.2), Color(1.0, 0.75, 0.2)],
		[I18n.t("LEGS %d") % int(st.get("legs", 0)), I18n.t("CORES %d") % int(st.get("cores", 0)), Color(1.0, 0.75, 0.2), Color(1.0, 0.45, 0.2)],
	]
	for k in lines.size():
		var y := r.position.y + (k + 1) * r.size.y / 3.0 - 5.0
		ci.draw_string(f, Vector2(r.position.x + 4, y), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, fs, lines[k][2])
		ci.draw_string(f, Vector2(r.position.x + r.size.x * 0.5, y), lines[k][1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5 - 2, fs, lines[k][3])
