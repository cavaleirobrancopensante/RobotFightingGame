extends RefCounted
## The little living scenes in the garage's left panel: Gus's bay, the parts website, the
## workbench, the scrapyard, the paint job, training, the team and the trophy wall.
## draw_back() draws behind the robot, draw_front() draws the people and props in front.

const I18n = preload("res://i18n.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")

## Where the robot stands in each scene: [x as fraction of width, height as fraction of panel]
const ROBOT_SPOT := {
	"build": [0.55, 0.64], "shop": [0.8, 0.5], "workshop": [0.74, 0.56], "scrap": [0.8, 0.5],
	"paint": [0.5, 0.72], "moves": [0.62, 0.7], "team": [0.64, 0.66], "cups": [0.68, 0.62],
	"storage": [0.72, 0.5],
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
## Places outside Gus's building have their own colour, so you know where you are at a glance.
## Rooms inside his building share the bay's bare steel and are told apart by what's in them
## (crates in the storeroom, the workbench, the chalkboard, the cork board, gantries...).
## [wall, wall stripes, floor]
const BAY_COLORS := [Color(0.19, 0.19, 0.18), Color(0.23, 0.23, 0.22), Color(0.28, 0.27, 0.27)]
const SCENE_COLORS := {
	"build": BAY_COLORS, "storage": BAY_COLORS, "workshop": BAY_COLORS, "moves": BAY_COLORS,
	"paint": BAY_COLORS, "team": BAY_COLORS, "office": BAY_COLORS, "cups": BAY_COLORS,
	"shop": [Color(0.07, 0.12, 0.27), Color(0.09, 0.15, 0.32), Color(0.17, 0.19, 0.26)],       # the dealer's: shop-window blue
	"pub": [Color(0.25, 0.06, 0.09), Color(0.29, 0.08, 0.11), Color(0.16, 0.08, 0.07)],        # The Rusty Bolt: wine red
	# (the scrapyard is outdoors: a sunset sky)
}


static func _environment(ci: CanvasItem, screen: Vector2, floor_y: float, scene: String, t: float, info: Dictionary) -> void:
	if scene == "scrap":
		for k in 10:
			var c := Color(0.95, 0.55, 0.3).lerp(Color(0.15, 0.12, 0.25), k / 9.0)
			ci.draw_rect(Rect2(0, k * floor_y / 10.0, screen.x, floor_y / 10.0 + 1), c)
		ci.draw_circle(Vector2(screen.x * 0.72, floor_y * 0.35), 30, Color(1.0, 0.75, 0.4, 0.9))
		# more junk mountains far away, behind the menus
		_scrap_pile(ci, Vector2(screen.x * 0.62, floor_y), screen.x * 0.3, floor_y * 0.45, t)
		_scrap_pile(ci, Vector2(screen.x * 0.95, floor_y), screen.x * 0.2, floor_y * 0.6, t + 3.0)
		ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), Color(0.25, 0.2, 0.15))
	elif scene == "phone":
		# night, your room above the bay: dark walls, the city through the window
		ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.06, 0.06, 0.1))
		var win := Rect2(screen.x * 0.03, screen.y * 0.12, screen.x * 0.22, floor_y * 0.55)
		ci.draw_rect(win, Color(0.08, 0.1, 0.2))
		for k in 9:
			var bx := win.position.x + k * win.size.x / 9.0
			var bh := win.size.y * (0.3 + 0.5 * fmod(k * 0.37, 1.0))
			ci.draw_rect(Rect2(bx, win.end.y - bh, win.size.x / 9.0 - 2.0, bh), Color(0.12, 0.13, 0.2))
			for j in 4:
				if fmod(k * 7.0 + j * 3.0 + floor(t * 0.3), 5.0) < 2.0:
					ci.draw_rect(Rect2(bx + 3.0, win.end.y - bh + 6.0 + j * 10.0, 4.0, 4.0), Color(1.0, 0.85, 0.45, 0.7))
		ci.draw_rect(win, Color(0.25, 0.25, 0.3), false, 4.0)
		ci.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.25, 0.25, 0.3), 3.0)
		# a neon glow from the street (the Rusty Bolt's sign), pulsing
		ci.draw_circle(Vector2(win.end.x, win.position.y), screen.x * 0.12, Color(0.9, 0.2, 0.35, 0.05 + 0.03 * sin(t * 2.0)))
	elif SCENE_COLORS.has(scene):
		var c: Array = SCENE_COLORS[scene]
		if scene == "pub":
			# wood panelling instead of corrugated metal, with a warm glow from the bar
			ci.draw_rect(Rect2(Vector2.ZERO, screen), c[0])
			for k in int(screen.x / 46.0) + 1:
				ci.draw_rect(Rect2(k * 46.0, 0, 2.0, floor_y), c[1].darkened(0.3))
			ci.draw_rect(Rect2(0, floor_y - 60, screen.x, 60), c[0].darkened(0.3))
			ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), c[2])
		else:
			_wall(ci, screen, floor_y, c[0], c[1], c[2])
	else:
		ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.12, 0.12, 0.17))
	if scene != "scrap" and scene != "phone":
		ci.draw_line(Vector2(0, floor_y), Vector2(screen.x, floor_y), Color(0.4, 0.4, 0.45), 2.0)


## Props around the robot (in stage coordinates).
static func _props_back(ci: CanvasItem, size: Vector2, scene: String, t: float, info: Dictionary) -> void:
	var floor_y := size.y - 20.0
	match scene:
		"build":
			# pegboard of tools
			var pb := Rect2(10, 118, size.x * 0.34, size.y * 0.2)
			_tool_board(ci, pb)
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
			_head(info, "YOU", Vector2(lx + 4.0, lerpf(floor_y, top_y, 0.68)), ps)
			if info.has("gantry"):
				_gantry(ci, info["gantry"], floor_y)
			# lift platform
			ci.draw_rect(Rect2(size.x * 0.56 - 50, floor_y - 6, 100, 8), Color(0.75, 0.6, 0.15))
			for k in 6:
				ci.draw_line(Vector2(size.x * 0.56 - 48 + k * 18, floor_y - 6), Vector2(size.x * 0.56 - 40 + k * 18, floor_y + 2), Color(0.15, 0.15, 0.15), 3.0)
		"pub":
			_pub_back(ci, size, floor_y, t, info)
		"office":
			_office_back(ci, size, floor_y, t, info)
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
			_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("CUSTOM ORDERS"), Color(0.6, 0.85, 1.0))
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
			# the spray booth: a rail with plastic curtains pulled back at both sides, an extractor fan,
			# and years of old paint jobs sprayed over the back wall
			for k in 14:
				var old_c := Color.from_hsv(fmod(k * 0.27, 1.0), 0.6, 0.7, 0.35)
				ci.draw_circle(Vector2(size.x * (0.12 + fmod(k * 0.41, 0.8)), size.y * (0.15 + fmod(k * 0.23, 0.5))), 6 + (k * 5) % 9, old_c)
			ci.draw_line(Vector2(0, 16), Vector2(size.x, 16), Color(0.55, 0.56, 0.6), 4.0)
			for side in [0.0, 1.0]:
				var x0 := 4.0 if side == 0.0 else size.x * 0.83
				var curtain := PackedVector2Array([Vector2(x0, 18), Vector2(x0 + size.x * 0.13, 18), Vector2(x0 + size.x * 0.08, floor_y), Vector2(x0, floor_y)])
				ci.draw_colored_polygon(curtain, Color(0.8, 0.88, 0.9, 0.22))
				for f in 4:
					var fx := x0 + 6 + f * size.x * 0.03
					ci.draw_line(Vector2(fx, 18), Vector2(fx - 2, floor_y), Color(1, 1, 1, 0.12), 2.0)
			var fan := Vector2(size.x * 0.5, 52)
			ci.draw_circle(fan, 22, Color(0.15, 0.15, 0.17))
			for k in 4:
				var a := t * 9.0 + k * PI / 2.0
				ci.draw_line(fan, fan + Vector2(cos(a), sin(a)) * 18, Color(0.5, 0.5, 0.55), 5.0)
			ci.draw_arc(fan, 22, 0, TAU, 24, Color(0.4, 0.4, 0.45), 3.0)
			_sign(ci, Vector2(size.x * 0.5, 96), I18n.t("PAINT BOOTH"), Color(0.95, 0.5, 0.8))
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
			_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("TEAM"), Color(0.5, 0.8, 1.0))
			# the crew bay: a gantry for each robot - the main one, and the backup's beside it
			var spot: Array = ROBOT_SPOT["team"]
			var rh: float = size.y * float(spot[1]) - 10.0
			_frame(ci, size.x * float(spot[0]), rh * 0.42, floor_y - rh - 26.0, floor_y)
			if GameData.gantries >= 1:   # one more gantry for each backup robot you've paid for
				_frame(ci, size.x * 0.24, rh * 0.34, floor_y - rh * 0.8 - 26.0, floor_y)
			if GameData.gantries >= 2:
				_frame(ci, size.x * 0.08, rh * 0.3, floor_y - rh * 0.72 - 26.0, floor_y)
		"storage":
			_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("STOREROOM"), Color(0.95, 0.75, 0.4))
			_lamp(ci, Vector2(size.x * 0.42, 0), size, t)
			# crates stacked to the ceiling at the back
			var cw := 46.0
			for col in int(size.x / (cw + 4.0)):
				var h := 2 + (col * 7) % 3
				for row in h:
					var r := Rect2(6 + col * (cw + 4.0), floor_y - (row + 1) * 34.0 - 26.0, cw, 32.0)
					_crate(ci, r, 0.75 + 0.1 * float((col + row) % 3))
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
			PilotArt.draw_person(ci, Vector2(robot_base.x - 84 * s, floor_y), s, gus, 1.0, "wrench", t)
			_head(info, "GUS", Vector2(robot_base.x - 84 * s, floor_y), s)
			var spark_age: float = info.get("spark", 99.0)
			if fmod(t, 2.4) < 0.25 or spark_age < 0.6:
				_sparks(ci, Vector2(robot_base.x - 50 * s, floor_y - robot_h * 0.25), t, 1.5 if spark_age < 0.6 else 1.0)
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
			_head(info, "YOU", Vector2(mon.position.x + 8 * s, floor_y), s, true)
			PilotArt.draw_person(ci, Vector2(mon.end.x + 22 * s, floor_y), s, gus, -1.0, "point", t + 0.7)
			_head(info, "GUS", Vector2(mon.end.x + 22 * s, floor_y), s)
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
			_head(info, "GUS", Vector2(vise.x - 22 * s, floor_y), s)
			var goggled: Dictionary = pilot.duplicate()
			goggled["glasses"] = "goggles"
			PilotArt.draw_person(ci, Vector2(gr.x + 24 * s, floor_y), s, goggled, -1.0, "hold", t + 0.4)
			_head(info, "YOU", Vector2(gr.x + 24 * s, floor_y), s)
			if fmod(t, 1.0) < 0.12:
				_sparks(ci, vise + Vector2(0, -20 * s), t, 1.0)
		"scrap":
			# the pilot digs into the pile; Gus points out something shiny
			var dig_age: float = info.get("dig", 99.0)
			var pile_x := size.x * 0.38
			PilotArt.draw_person(ci, Vector2(pile_x + 44 * s, floor_y), s, pilot, -1.0, "dig", t * (2.0 if dig_age < 1.0 else 0.6))
			_head(info, "YOU", Vector2(pile_x + 44 * s, floor_y), s)
			PilotArt.draw_person(ci, Vector2(18 * s, floor_y), s * 0.95, gus, 1.0, "point", t + 0.3)
			_head(info, "GUS", Vector2(18 * s, floor_y), s * 0.95)
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
			_head(info, "YOU", Vector2(robot_base.x - 60 * s, floor_y), s)
			PilotArt.draw_person(ci, Vector2(robot_base.x + 62 * s, floor_y), s, gus, -1.0, "spray", t + 0.9, pc)
			_head(info, "GUS", Vector2(robot_base.x + 62 * s, floor_y), s)
		"moves":
			# training: the pilot drills inputs on the controller, Gus times it
			PilotArt.draw_person(ci, Vector2(26 * s, floor_y), s, pilot, 1.0, "hold", t)
			_head(info, "YOU", Vector2(26 * s, floor_y), s)
			PilotArt.draw_person(ci, Vector2(size.x * 0.8, floor_y), s * 0.95, gus, -1.0, "clipboard", t + 0.5)
			_head(info, "GUS", Vector2(size.x * 0.8, floor_y), s * 0.95)
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
			PilotArt.draw_person(ci, Vector2(size.x * 0.84, floor_y), s * 0.9, pilot, -1.0, "cheer" if not backup.is_empty() else "idle", t)
			_head(info, "YOU", Vector2(size.x * 0.84, floor_y), s * 0.9)
			PilotArt.draw_person(ci, Vector2(size.x * 0.42, floor_y), s * 0.95, gus, 1.0, "clipboard", t + 0.5)
			_head(info, "GUS", Vector2(size.x * 0.42, floor_y), s * 0.95)
		"cups":
			PilotArt.draw_person(ci, Vector2(28 * s, floor_y), s, pilot, 1.0, "cheer" if not info.get("medals", []).is_empty() else "point", t)
			_head(info, "YOU", Vector2(28 * s, floor_y), s)
			PilotArt.draw_person(ci, Vector2(size.x * 0.84, floor_y), s * 0.95, gus, -1.0, "point", t + 0.6)
			_head(info, "GUS", Vector2(size.x * 0.84, floor_y), s * 0.95)
		"pub":
			_pub_front(ci, size, floor_y, s, t, info)
		"phone":
			_phone_closeup(ci, size, t, info)
		"office":
			# Gus at the desk going through the fixtures; you at the board
			var dx := size.x * 0.62
			ci.draw_rect(Rect2(dx - 70 * s, floor_y - 40 * s, 150 * s, 8 * s), Color(0.42, 0.3, 0.18))
			ci.draw_rect(Rect2(dx - 64 * s, floor_y - 32 * s, 6 * s, 32 * s), Color(0.3, 0.2, 0.12))
			ci.draw_rect(Rect2(dx + 68 * s, floor_y - 32 * s, 6 * s, 32 * s), Color(0.3, 0.2, 0.12))
			# desk lamp and a coffee
			ci.draw_line(Vector2(dx + 50 * s, floor_y - 40 * s), Vector2(dx + 40 * s, floor_y - 70 * s), Color(0.2, 0.2, 0.22), 3.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(dx + 28 * s, floor_y - 66 * s), Vector2(dx + 50 * s, floor_y - 76 * s), Vector2(dx + 48 * s, floor_y - 64 * s)]), Color(0.75, 0.7, 0.2))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(dx + 36 * s, floor_y - 66 * s), Vector2(dx + 22 * s, floor_y - 41 * s), Vector2(dx + 60 * s, floor_y - 41 * s), Vector2(dx + 48 * s, floor_y - 66 * s)]), Color(1.0, 0.9, 0.5, 0.12))
			ci.draw_rect(Rect2(dx - 40 * s, floor_y - 48 * s, 8 * s, 8 * s), Color(0.9, 0.9, 0.85))
			PilotArt.draw_person(ci, Vector2(dx + 8 * s, floor_y), s, PilotArt.GUS_LOOK, -1.0, "sit_type", t)
			_head(info, "GUS", Vector2(dx + 8 * s, floor_y), s, true)
			PilotArt.draw_person(ci, Vector2(size.x * 0.3, floor_y), s, info.get("pilot", {}), -1.0, "point", t + 0.4)
			_head(info, "YOU", Vector2(size.x * 0.3, floor_y), s)
		"storage":
			# two crates being opened: one lid already off with parts sticking out, Gus prying the other
			var a := Rect2(size.x * 0.1, floor_y - 40 * s, 70 * s, 40 * s)
			var b := Rect2(size.x * 0.5, floor_y - 36 * s, 62 * s, 36 * s)
			# what's inside crate A: an arm, a wheel and a head poking out of the straw
			ci.draw_line(a.position + Vector2(18 * s, 4 * s), a.position + Vector2(30 * s, -22 * s), Color(0.6, 0.6, 0.66), 6 * s)
			ci.draw_circle(a.position + Vector2(30 * s, -22 * s), 5 * s, Color(0.5, 0.5, 0.55))
			ci.draw_circle(a.position + Vector2(48 * s, -4 * s), 9 * s, Color(0.12, 0.12, 0.12))
			ci.draw_circle(a.position + Vector2(48 * s, -4 * s), 4 * s, Color(0.55, 0.5, 0.45))
			ci.draw_rect(Rect2(a.position + Vector2(52 * s, -14 * s), Vector2(16 * s, 14 * s)), Color(0.45, 0.5, 0.58))
			ci.draw_circle(a.position + Vector2(62 * s, -8 * s), 2 * s, Color(1.0, 0.4, 0.2) if fmod(t, 1.4) < 0.7 else Color(0.3, 0.2, 0.2))
			for k in 6:
				ci.draw_line(a.position + Vector2((6 + k * 10) * s, 2 * s), a.position + Vector2((10 + k * 10) * s, -4 * s), Color(0.85, 0.75, 0.4), 1.5)
			_crate(ci, a, 0.9)
			# the lid leans against it
			ci.draw_colored_polygon(PackedVector2Array([a.position + Vector2(-4 * s, a.size.y), a.position + Vector2(4 * s, a.size.y),
					a.position + Vector2(-10 * s, -6 * s), a.position + Vector2(-18 * s, -6 * s)]), Color(0.55, 0.4, 0.25))
			# crate B: the lid lifts a little each heave
			var heave := maxf(0.0, sin(t * 2.6)) * 6 * s
			_crate(ci, b, 0.8)
			ci.draw_rect(Rect2(b.position + Vector2(-2 * s, -6 * s - heave), Vector2(b.size.x + 4 * s, 6 * s)), Color(0.6, 0.45, 0.28))
			PilotArt.draw_person(ci, Vector2(b.position.x - 14 * s, floor_y), s, gus, 1.0, "pry", t)
			_head(info, "GUS", Vector2(b.position.x - 14 * s, floor_y), s)
			# the pilot holds up a find and looks it over
			PilotArt.draw_person(ci, Vector2(a.end.x + 30 * s, floor_y), s, pilot, -1.0, "lift", t + 0.5, Color(0.55, 0.58, 0.62))
			_head(info, "YOU", Vector2(a.end.x + 30 * s, floor_y), s)


# ---------------------------------------------------------------- bits

## A plain work gantry (crew bay): two posts, a hazard-striped beam and a hook hanging in the middle.
static func _frame(ci: CanvasItem, cx: float, half: float, top: float, floor_y: float) -> void:
	var steel := Color(0.36, 0.38, 0.43)
	for x in [cx - half, cx + half]:
		ci.draw_rect(Rect2(x - 4, top, 8, floor_y - top), steel)
		ci.draw_rect(Rect2(x - 10, floor_y - 5, 20, 5), steel.darkened(0.3))
	var beam := Rect2(cx - half - 6, top - 5, half * 2 + 12, 11)
	ci.draw_rect(beam, Color(0.1, 0.1, 0.1))
	var x := beam.position.x + 2.0
	while x < beam.end.x - 10.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, beam.end.y - 2), Vector2(x + 5, beam.end.y - 2),
				Vector2(x + 10, beam.position.y + 2), Vector2(x + 5, beam.position.y + 2)]), Color(0.95, 0.76, 0.19))
		x += 12.0
	ci.draw_line(Vector2(cx, beam.end.y), Vector2(cx, beam.end.y + 18), Color(0.55, 0.56, 0.6), 2.0)
	ci.draw_arc(Vector2(cx, beam.end.y + 23), 5.0, -PI * 0.3, PI * 1.1, 8, Color(0.7, 0.7, 0.74), 2.5)


## Gus's gantry: two steel posts, a hazard-striped beam over the robot's head, and chains down to
## its shoulders, so it hangs there arms open while he works on it.
## g = {"left": shoulder, "right": shoulder, "top": y above the head, "reach": half the width with arms}
static func _gantry(ci: CanvasItem, g: Dictionary, floor_y: float) -> void:
	var sl: Vector2 = g["left"]
	var sr: Vector2 = g["right"]
	var mid := (sl.x + sr.x) * 0.5
	var reach: float = g["reach"]
	var beam_y: float = g["top"] - 26.0
	var steel := Color(0.36, 0.38, 0.43)
	var xl := mid - reach - 12.0
	var xr := mid + reach + 12.0
	for x in [xl, xr]:
		ci.draw_rect(Rect2(x - 5, beam_y, 10, floor_y - beam_y), steel)
		ci.draw_rect(Rect2(x - 5, beam_y, 3, floor_y - beam_y), steel.lightened(0.15))
		ci.draw_rect(Rect2(x - 12, floor_y - 6, 24, 6), steel.darkened(0.3))   # foot plate
	# corner braces
	ci.draw_line(Vector2(xl + 4, beam_y + 30), Vector2(xl + 30, beam_y + 8), steel, 4.0)
	ci.draw_line(Vector2(xr - 4, beam_y + 30), Vector2(xr - 30, beam_y + 8), steel, 4.0)
	# the beam, hazard striped
	var beam := Rect2(xl - 8, beam_y - 6, xr - xl + 16, 13)
	ci.draw_rect(beam, Color(0.1, 0.1, 0.1))
	var x := beam.position.x + 2.0
	while x < beam.end.x - 10.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, beam.end.y - 2), Vector2(x + 6, beam.end.y - 2),
				Vector2(x + 12, beam.position.y + 2), Vector2(x + 6, beam.position.y + 2)]), Color(0.95, 0.76, 0.19))
		x += 14.0
	ci.draw_rect(beam, Color(0.05, 0.05, 0.05), false, 2.0)
	# chains down to the shoulders, with a hook at the end
	for sh in [sl, sr]:
		var top := Vector2(sh.x, beam.end.y)
		var n := int((sh.y - 10.0 - top.y) / 7.0)
		for k in maxi(n, 0):
			var p := top + Vector2(0, 4 + k * 7.0)
			if k % 2 == 0:
				ci.draw_rect(Rect2(p - Vector2(2.5, 3.5), Vector2(5, 7)), Color(0.55, 0.56, 0.6), false, 1.6)
			else:
				ci.draw_line(p - Vector2(0, 3.5), p + Vector2(0, 3.5), Color(0.55, 0.56, 0.6), 2.0)
		ci.draw_arc(Vector2(sh.x, sh.y - 6.0), 5.0, PI * 0.1, PI * 1.2, 8, Color(0.7, 0.7, 0.74), 2.5)


# ---------------------------------------------------------------- Gus's office (the Season screens)

## A cork board full of fixtures, results and pilot photos, with red string between them.
static func _office_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float, info: Dictionary) -> void:
	_trophy_wall(ci, size, info)
	var board := Rect2(size.x * 0.05, size.y * 0.4, size.x * 0.5, size.y * 0.3)
	ci.draw_rect(board.grow(5), Color(0.38, 0.25, 0.13))
	ci.draw_rect(board, Color(0.62, 0.45, 0.28))
	var pins: Array = []
	for k in 7:
		var r := Rect2(board.position + Vector2(10 + (k % 4) * board.size.x / 4.2, 10 + int(k / 4.0) * board.size.y / 2.1),
				Vector2(board.size.x / 5.5, board.size.y / 2.8))
		var paper := Color(0.95, 0.94, 0.88) if k % 3 else Color(0.98, 0.9, 0.55)
		ci.draw_rect(r, paper)
		for ln in 4:
			ci.draw_line(r.position + Vector2(4, 8 + ln * 7), r.position + Vector2(r.size.x - 4 - (ln % 2) * 8, 8 + ln * 7), Color(0.4, 0.4, 0.45), 1.0)
		var pin := r.position + Vector2(r.size.x * 0.5, 2)
		ci.draw_circle(pin, 3.0, Color(0.85, 0.15, 0.15))
		pins.append(pin)
	ci.draw_line(pins[0], pins[5], Color(0.85, 0.1, 0.1), 1.5)
	ci.draw_line(pins[2], pins[6], Color(0.85, 0.1, 0.1), 1.5)
	# a wall clock
	var cc := Vector2(size.x * 0.68, size.y * 0.24)
	ci.draw_circle(cc, 18, Color(0.92, 0.92, 0.88))
	ci.draw_arc(cc, 18, 0, TAU, 24, Color(0.2, 0.2, 0.2), 2.0)
	ci.draw_line(cc, cc + Vector2(cos(t * 0.1 - PI / 2), sin(t * 0.1 - PI / 2)) * 13, Color(0.15, 0.15, 0.15), 2.0)
	ci.draw_line(cc, cc + Vector2(cos(t * 1.2 - PI / 2), sin(t * 1.2 - PI / 2)) * 15, Color(0.8, 0.1, 0.1), 1.0)
	_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("GUS'S OFFICE"), Color(0.85, 0.9, 0.45))


# ---------------------------------------------------------------- The Rusty Bolt (the Bets screen)

static func _pub_counter_x(size: Vector2) -> float:
	return size.x * 0.52


## Behind the bar: the neon sign, bottles, the TV with tonight's fights, the bartender and the counter.
static func _pub_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float, info: Dictionary) -> void:
	var s := clampf(size.y / 300.0, 0.6, 1.3)
	# neon sign, flickering now and then
	var on := fmod(t, 7.0) > 0.12 and not (fmod(t, 7.0) > 0.3 and fmod(t, 7.0) < 0.38)
	var neon := Color(1.0, 0.45, 0.2) if on else Color(0.35, 0.18, 0.12)
	var sign_r := Rect2(size.x * 0.06, size.y * 0.06, size.x * 0.44, 34 * s)
	ci.draw_rect(sign_r.grow(6), Color(neon.r, neon.g, neon.b, 0.12 if on else 0.0))
	ci.draw_rect(sign_r, Color(0.08, 0.05, 0.05))
	ci.draw_rect(sign_r, neon, false, 2.0)
	ci.draw_string(ThemeDB.fallback_font, sign_r.position + Vector2(0, sign_r.size.y * 0.72), I18n.t("THE RUSTY BOLT"),
			HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x, int(14 * s), neon)
	# the TV: two little robots slugging it out
	var tv := Rect2(size.x * 0.56, size.y * 0.05, size.x * 0.27, size.y * 0.19)
	ci.draw_rect(tv.grow(4), Color(0.1, 0.1, 0.11))
	ci.draw_rect(tv, Color(0.06, 0.12, 0.16))
	ci.draw_line(Vector2(tv.get_center().x, tv.position.y - 4), Vector2(tv.get_center().x, 0), Color(0.2, 0.2, 0.22), 3.0)
	var ring_y := tv.end.y - 8
	ci.draw_line(Vector2(tv.position.x + 4, ring_y), Vector2(tv.end.x - 4, ring_y), Color(0.5, 0.5, 0.55), 2.0)
	var gap := 18.0 + 10.0 * absf(sin(t * 1.3))
	var mid := tv.get_center().x + sin(t * 0.7) * 10.0
	for k in 2:
		var dirk := -1.0 if k == 0 else 1.0
		var bx := mid + dirk * gap
		var c := Color(0.9, 0.55, 0.25) if k == 0 else Color(0.4, 0.7, 1.0)
		ci.draw_rect(Rect2(bx - 5, ring_y - 26, 10, 16), c)
		ci.draw_rect(Rect2(bx - 4, ring_y - 34, 8, 7), c.lightened(0.2))
		ci.draw_line(Vector2(bx - 3, ring_y - 10), Vector2(bx - 3, ring_y), c, 2.0)
		ci.draw_line(Vector2(bx + 3, ring_y - 10), Vector2(bx + 3, ring_y), c, 2.0)
		var jab := maxf(0.0, sin(t * 5.0 + k * 1.7)) * 9.0
		ci.draw_line(Vector2(bx, ring_y - 22), Vector2(bx - dirk * (8 + jab), ring_y - 22), c, 3.0)
	var tvi: Dictionary = info.get("tv", {})
	if tvi.get("live", false) or tvi.is_empty():
		ci.draw_string(ThemeDB.fallback_font, tv.position + Vector2(4, 11), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.3, 0.3) if fmod(t, 1.0) < 0.6 else Color(0.5, 0.2, 0.2))
	if not tvi.is_empty():
		# the channel's banner along the bottom of the screen: which league, who's fighting
		var band := Rect2(tv.position.x, tv.end.y - 2, tv.size.x, 26 * s)
		ci.draw_rect(band, Color(0.05, 0.05, 0.08))
		ci.draw_rect(Rect2(band.position, Vector2(4, band.size.y)), Color(1.0, 0.8, 0.2))
		var f := ThemeDB.fallback_font
		var fs := int(10 * s)
		ci.draw_string(f, band.position + Vector2(8, 11 * s), str(tvi.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 12, fs, Color(1.0, 0.8, 0.2))
		var who := str(tvi.get("a", "")) + ("  vs  " + str(tvi["b"]) if str(tvi.get("b", "")) != "" else "")
		ci.draw_string(f, band.position + Vector2(8, 22 * s), who, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 12, fs, Color(0.9, 0.9, 0.95))
	# shelves of bottles behind the bar
	var cx := _pub_counter_x(size)
	for row in 2:
		var y := size.y * (0.36 + row * 0.13)
		ci.draw_rect(Rect2(cx, y, size.x - cx, 4), Color(0.35, 0.22, 0.12))
		var k := 0
		var x := cx + 8.0
		while x < size.x - 10:
			var hue := fmod(k * 0.37 + row * 0.2, 1.0)
			var h := (16 + (k * 7) % 9) * s
			ci.draw_rect(Rect2(x, y - h, 7 * s, h), Color.from_hsv(hue, 0.55, 0.55, 0.9))
			ci.draw_rect(Rect2(x + 2 * s, y - h - 5 * s, 3 * s, 5 * s), Color.from_hsv(hue, 0.4, 0.4))
			x += 13 * s
			k += 1
	_jukebox(ci, Vector2(size.x * 0.035, floor_y), s, t, bool(info.get("juke", false)))
	# the bartender behind the counter, polishing a glass
	var keep := {"skin": "#8d5a3b", "hair": "#2b2b2b", "hat": "none", "outfit": "#3b2a1e", "beard": "full", "beard_color": "#2b2b2b", "eyes": "#3a2a1e"}
	PilotArt.draw_person(ci, Vector2(size.x * 0.72, floor_y - 16 * s), s, keep, -1.0, "wipe", t)   # on the raised step behind the bar
	# the counter (covers the bartender's legs)
	var top := floor_y - 44 * s
	ci.draw_rect(Rect2(cx, top, size.x - cx, floor_y - top), Color(0.32, 0.19, 0.1))
	ci.draw_rect(Rect2(cx - 6, top - 6 * s, size.x - cx + 6, 7 * s), Color(0.5, 0.31, 0.16))
	for k in 4:
		var px := cx + 14 + k * (size.x - cx - 20) / 3.0
		ci.draw_line(Vector2(px, top + 6), Vector2(px, floor_y - 4), Color(0.25, 0.15, 0.08), 2.0)
	ci.draw_line(Vector2(cx, floor_y - 8 * s), Vector2(size.x, floor_y - 8 * s), Color(0.7, 0.6, 0.35), 3.0)   # foot rail


## The jukebox: knocked together from scrap - patchwork plates, pipe legs, a record spinning behind
## a scratched window, chasing bulbs round the arch, and a brass gramophone horn on top. When it's
## playing, the bulbs run, the record spins and notes drift out of the horn.
	# the rest of tonight's crowd, standing around with their drinks (further back, a bit smaller)
	var crowd: Array = info.get("patron", {}).get("crowd", [])
	for k in crowd.size():
		var cs := s * 0.82
		var cx2 := _pub_counter_x(size) - (30 + 58 * k) * s
		var cy := floor_y - 16 * s
		PilotArt.draw_person(ci, Vector2(cx2, cy), cs, crowd[k]["look"], 1.0 if k % 2 == 0 else -1.0, "hold", t + 1.3 * k)
		_head(info, str(crowd[k]["name"]), Vector2(cx2, cy), cs)

static func _jukebox(ci: CanvasItem, base: Vector2, s: float, t: float, playing: bool) -> void:
	var w := 50.0 * s
	var h := 80.0 * s
	var body := Rect2(base.x, base.y - h - 8 * s, w, h)
	# pipe legs
	for lx in [body.position.x + 6 * s, body.end.x - 9 * s]:
		ci.draw_rect(Rect2(lx, body.end.y, 3 * s, 8 * s), Color(0.45, 0.45, 0.48))
	# patchwork body: plates of different scrap riveted together
	var plates := [[Rect2(body.position, Vector2(w * 0.55, h * 0.5)), Color(0.42, 0.28, 0.18)],
			[Rect2(body.position + Vector2(w * 0.55, 0), Vector2(w * 0.45, h * 0.5)), Color(0.35, 0.38, 0.33)],
			[Rect2(body.position + Vector2(0, h * 0.5), Vector2(w * 0.4, h * 0.5)), Color(0.38, 0.33, 0.4)],
			[Rect2(body.position + Vector2(w * 0.4, h * 0.5), Vector2(w * 0.6, h * 0.5)), Color(0.48, 0.3, 0.16)]]
	for p in plates:
		ci.draw_rect(p[0], p[1])
		ci.draw_rect(p[0], (p[1] as Color).darkened(0.4), false, 1.5)
		var r: Rect2 = p[0]
		for c in [r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3), Vector2(r.position.x + 3, r.end.y - 3), r.end - Vector2(3, 3)]:
			ci.draw_circle(c, 1.3, Color(0.75, 0.7, 0.6))
	# rust streaks
	for k in 3:
		var rx := body.position.x + w * (0.2 + k * 0.28)
		ci.draw_line(Vector2(rx, body.position.y + h * 0.3), Vector2(rx - 2, body.position.y + h * 0.55), Color(0.55, 0.25, 0.1, 0.6), 2.0)
	# the arch on top, with bulbs that chase round when it plays
	var arch_c := Vector2(body.get_center().x, body.position.y)
	ci.draw_circle(arch_c, w * 0.5, Color(0.3, 0.2, 0.14))
	ci.draw_rect(Rect2(body.position.x, arch_c.y, w, 2), Color(0.3, 0.2, 0.14))
	for k in 9:
		var a := PI + PI * (k + 0.5) / 9.0
		var lit := playing and (int(t * 8.0) + k) % 3 == 0
		var col := Color.from_hsv(fmod(k * 0.13, 1.0), 0.7, 1.0) if lit else Color.from_hsv(fmod(k * 0.13, 1.0), 0.4, 0.4)
		ci.draw_circle(arch_c + Vector2(cos(a), sin(a)) * w * 0.42, 2.6 * s * 0.6 + 1.0, col)
	# the window: a record on a turntable
	var win := Rect2(body.position + Vector2(w * 0.12, h * 0.08), Vector2(w * 0.76, h * 0.36))
	ci.draw_rect(win, Color(0.08, 0.06, 0.05))
	var rec := win.get_center() + Vector2(0, 2)
	var rr := win.size.y * 0.42
	ci.draw_circle(rec, rr, Color(0.06, 0.06, 0.06))
	for k in 3:
		ci.draw_arc(rec, rr * (0.45 + k * 0.17), 0, TAU, 18, Color(0.18, 0.18, 0.18), 1.0)
	ci.draw_circle(rec, rr * 0.3, Color(0.8, 0.25, 0.15))
	var spin := t * 5.0 if playing else 0.6
	ci.draw_line(rec, rec + Vector2(cos(spin), sin(spin)) * rr * 0.28, Color(1, 0.9, 0.7), 1.5)
	ci.draw_line(win.position + Vector2(win.size.x * 0.85, 3), rec + Vector2(rr * 0.6, -rr * 0.3), Color(0.75, 0.75, 0.8), 1.5)   # tone arm
	ci.draw_rect(win, Color(0.7, 0.85, 0.9, 0.12))
	ci.draw_line(win.position + Vector2(4, win.size.y - 4), win.position + Vector2(win.size.x * 0.4, 4), Color(1, 1, 1, 0.15), 1.0)   # scratch
	# speaker grille and the coin slot
	var gr := Rect2(body.position + Vector2(w * 0.12, h * 0.56), Vector2(w * 0.5, h * 0.34))
	ci.draw_rect(gr, Color(0.15, 0.12, 0.1))
	for k in 5:
		ci.draw_line(Vector2(gr.position.x + 2, gr.position.y + 4 + k * gr.size.y / 5.0), Vector2(gr.end.x - 2, gr.position.y + 4 + k * gr.size.y / 5.0), Color(0.5, 0.42, 0.3), 1.5)
	ci.draw_rect(Rect2(body.position + Vector2(w * 0.72, h * 0.62), Vector2(w * 0.12, h * 0.05)), Color(0.08, 0.08, 0.08))
	ci.draw_circle(body.position + Vector2(w * 0.78, h * 0.78), 3.0, Color(0.3, 1.0, 0.4) if playing else Color(0.5, 0.15, 0.1))
	# the gramophone horn: a brass flower on a crooked neck
	var neck0 := Vector2(body.end.x - w * 0.2, arch_c.y - w * 0.4)
	var neck1 := neck0 + Vector2(6 * s, -14 * s)
	ci.draw_line(neck0, neck1, Color(0.6, 0.45, 0.2), 3.0 * s)
	var mouth := neck1 + Vector2(20 * s, -16 * s)
	var dirv := (mouth - neck1).normalized()
	var perp := dirv.orthogonal()
	var pulse := (1.0 + 0.06 * sin(t * 10.0)) if playing else 1.0
	ci.draw_colored_polygon(PackedVector2Array([neck1 + perp * 2 * s, mouth + perp * 15 * s * pulse, mouth - perp * 15 * s * pulse, neck1 - perp * 2 * s]), Color(0.8, 0.6, 0.22))
	ci.draw_line(mouth + perp * 15 * s * pulse, mouth - perp * 15 * s * pulse, Color(0.95, 0.8, 0.4), 3.0)
	for k in 3:
		ci.draw_line(neck1, mouth + perp * (-12 + k * 12) * s * pulse, Color(0.62, 0.45, 0.15), 1.0)
	# notes drifting out of the horn
	if playing:
		for k in 4:
			var ph := fmod(t * 0.6 + k * 0.25, 1.0)
			var np := mouth + dirv * 10 * s + Vector2(ph * 30 * s + sin(t * 3.0 + k) * 5, -ph * 46 * s)
			var nc := Color(1.0, 0.85, 0.45, 1.0 - ph)
			ci.draw_circle(np, 2.6 * s * 0.7 + 0.5, nc)
			ci.draw_line(np + Vector2(2.2 * s * 0.7, 0), np + Vector2(2.2 * s * 0.7, -8 * s * 0.7), nc, 1.5)
			if k % 2 == 0:
				ci.draw_line(np + Vector2(2.2 * s * 0.7, -8 * s * 0.7), np + Vector2(6 * s * 0.7, -6 * s * 0.7), nc, 1.5)


## In front: your pilot on a stool at the bar with a beer (pushing coins over when you bet),
## and Gus at a little table with his coffee.
static func _pub_front(ci: CanvasItem, size: Vector2, floor_y: float, s: float, t: float, info: Dictionary) -> void:
	var cx := _pub_counter_x(size)
	var top := floor_y - 44 * s
	var pilot: Dictionary = info.get("pilot", {})
	var bet_age: float = info.get("bet", 99.0)
	# coins sliding down the bar towards the bartender after a bet
	if bet_age < 1.6:
		var f := clampf(bet_age / 1.2, 0.0, 1.0)
		var at := Vector2(lerpf(cx + 6, size.x * 0.74, f), top - 7 * s)
		for k in 4:
			ci.draw_circle(at + Vector2(k * 3, -k * 2.5 * s), 3.2 * s, Color(0.95, 0.78, 0.25, 1.0 - maxf(0.0, bet_age - 1.2) * 2.5))
	# stools: today's pilot at the bar nearest the bartender, then you, then Gus
	var patron: Dictionary = info.get("patron", {})
	var qx := cx - 24 * s
	var px := cx - (66 if not patron.is_empty() else 26) * s
	for x in [px, px - 44 * s]:
		ci.draw_rect(Rect2(x - 10 * s, floor_y - 27 * s, 20 * s, 4 * s), Color(0.55, 0.15, 0.12))
		ci.draw_line(Vector2(x - 6 * s, floor_y - 23 * s), Vector2(x - 9 * s, floor_y), Color(0.45, 0.45, 0.5), 2.0)
		ci.draw_line(Vector2(x + 6 * s, floor_y - 23 * s), Vector2(x + 9 * s, floor_y), Color(0.45, 0.45, 0.5), 2.0)
	PilotArt.draw_person(ci, Vector2(px - 4 * s, floor_y), s, pilot, 1.0, "push" if bet_age < 1.2 else "drink", t)
	_head(info, "YOU", Vector2(px - 4 * s, floor_y), s, true)
	# Gus on the next stool, nursing a coffee
	PilotArt.draw_person(ci, Vector2(px - 48 * s, floor_y), s, PilotArt.GUS_LOOK, 1.0, "drink", t + 2.2)
	_head(info, "GUS", Vector2(px - 48 * s, floor_y), s, true)
	# today's pilot at the bar: a real pilot from the rankings (your pickup fight, if you want it)
	if not patron.is_empty():
		ci.draw_rect(Rect2(qx - 10 * s, floor_y - 27 * s, 20 * s, 4 * s), Color(0.55, 0.15, 0.12))
		ci.draw_line(Vector2(qx - 6 * s, floor_y - 23 * s), Vector2(qx - 9 * s, floor_y), Color(0.45, 0.45, 0.5), 2.0)
		ci.draw_line(Vector2(qx + 6 * s, floor_y - 23 * s), Vector2(qx + 9 * s, floor_y), Color(0.45, 0.45, 0.5), 2.0)
		PilotArt.draw_person(ci, Vector2(qx, floor_y), s, patron["look"], 1.0, "drink", t + 4.1)
		_head(info, str(patron["name"]), Vector2(qx, floor_y), s, true)


## Remember where a person's head is (stage coordinates), so the garage can point speech bubbles at it.
## Your gear shelf in BotMedia's room: [controller id, centre] for every controller you own.
static func gear_spots(size: Vector2, owned: Array) -> Array:
	var out: Array = []
	for i in owned.size():
		var row := i / 3
		var col := i % 3
		out.append([owned[i], Vector2(size.x * (0.69 + col * 0.075), size.y * (0.1 + row * 0.15))])
	return out


static func _gear_shelf(ci: CanvasItem, size: Vector2, t: float, info: Dictionary) -> void:
	var owned: Array = info.get("controllers", [])
	var using: String = str(info.get("using", ""))
	var rows := int(ceil(owned.size() / 3.0))
	for row in maxi(1, rows):
		var y := size.y * (0.1 + row * 0.15) + 12.0
		ci.draw_rect(Rect2(size.x * 0.645, y, size.x * 0.24, 5), Color(0.45, 0.32, 0.2))
		ci.draw_rect(Rect2(size.x * 0.655, y + 5, 4, 8), Color(0.3, 0.22, 0.14))
		ci.draw_rect(Rect2(size.x * 0.87, y + 5, 4, 8), Color(0.3, 0.22, 0.14))
	for sp in gear_spots(size, owned):
		var on: bool = str(sp[0]) == using
		if on:
			ci.draw_circle(sp[1], 20.0, Color(0.95, 0.76, 0.19, 0.18 + 0.08 * sin(t * 3.0)))
		PilotArt.draw_controller(ci, sp[1], 0.85, str(sp[0]), on, t)


## BotMedia: a close-up of your pilot from the front, face lit blue by the phone in both hands.
static func _phone_closeup(ci: CanvasItem, size: Vector2, t: float, info: Dictionary) -> void:
	_gear_shelf(ci, size, t, info)
	var look: Dictionary = PilotArt.normalize(info.get("pilot", {}))
	var r := size.y * 0.19
	var c := Vector2(size.x * 0.4, size.y * 0.4)
	var outfit := Color(look.get("outfit", "#3e5c4f"))
	var skin := Color(look.get("skin", "#c8946e"))
	# shoulders and chest fill the bottom of the frame
	var body := PackedVector2Array([Vector2(c.x - r * 2.1, size.y), Vector2(c.x - r * 1.75, c.y + r * 1.35), Vector2(c.x - r * 0.5, c.y + r * 1.05),
			Vector2(c.x + r * 0.5, c.y + r * 1.05), Vector2(c.x + r * 1.75, c.y + r * 1.35), Vector2(c.x + r * 2.1, size.y)])
	ci.draw_colored_polygon(body, outfit)
	ci.draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.75, r * 0.6, r * 0.4), skin.darkened(0.12))   # neck
	if look.get("female", false):
		for side in [-1.0, 1.0]:
			ci.draw_arc(c + Vector2(side * r * 0.62, r * 1.85), r * 0.42, PI * 0.15, PI * 0.85, 12, outfit.darkened(0.45), maxf(1.5, r * 0.05))
	# the head, tipped down a touch toward the screen
	PilotArt.draw_head(ci, c, r, look, 0.0, 2.0)
	# eyes on the screen: lids half down, pupils low
	if str(look.get("glasses", "none")) in ["none", "round"]:
		for side in [-1.0, 1.0]:
			var e := c + Vector2(side * r * 0.33, -r * 0.08)
			ci.draw_rect(Rect2(e.x - r * 0.16, e.y - r * 0.17, r * 0.32, r * 0.15), skin)
			ci.draw_line(Vector2(e.x - r * 0.15, e.y - r * 0.02), Vector2(e.x + r * 0.15, e.y - r * 0.02), skin.darkened(0.45), maxf(1.5, r * 0.04))
			ci.draw_circle(e + Vector2(0, r * 0.06), r * 0.075, Color(look.get("eyes", "#5b3a1e")))
	# glow from the screen on the face
	ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.95, Color(0.45, 0.75, 1.0, 0.12 + 0.03 * sin(t * 3.0)))
	# arms come up from the elbows to the phone held in front of the chest
	var ph := Rect2(c.x - r * 0.62, c.y + r * 1.55, r * 1.24, r * 1.9)
	for side in [-1.0, 1.0]:
		var elbow := Vector2(c.x + side * r * 1.7, size.y + r * 0.2)
		var hand := Vector2(c.x + side * r * 0.62, ph.position.y + ph.size.y * 0.62)
		ci.draw_line(elbow, hand, outfit.darkened(0.15), r * 0.42)
	# the back of the phone (the screen faces your pilot): plain black, a camera lens in the corner
	ci.draw_rect(ph.grow(r * 0.04), Color(0.03, 0.03, 0.04))
	ci.draw_rect(ph, Color(0.07, 0.07, 0.08))
	ci.draw_circle(ph.position + Vector2(r * 0.22, r * 0.22), r * 0.09, Color(0.02, 0.02, 0.03))
	ci.draw_circle(ph.position + Vector2(r * 0.22, r * 0.22), r * 0.05, Color(0.12, 0.14, 0.2))
	# thumbs on the screen edge
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(c.x + side * r * 0.6, ph.position.y + ph.size.y * 0.6), r * 0.17, skin)
	if not info.has("heads"):
		info["heads"] = {}
	info["heads"]["YOU"] = c + Vector2(r * 0.6, -r * 0.9)


static func _head(info: Dictionary, who: String, feet: Vector2, s: float, sitting: bool = false) -> void:
	if not info.has("heads"):
		info["heads"] = {}
	info["heads"][who] = feet + Vector2(0, (-80.0 if sitting else -78.0) * s)

## A wooden crate with planks and a stencil mark. shade darkens or lightens the wood.
static func _crate(ci: CanvasItem, r: Rect2, shade: float) -> void:
	var wood := Color(0.55, 0.4, 0.25) * Color(shade, shade, shade)
	ci.draw_rect(r, wood)
	ci.draw_rect(r, wood.darkened(0.35), false, 2.0)
	for k in 3:
		var y := r.position.y + r.size.y * (k + 1) / 4.0
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), wood.darkened(0.2), 1.0)
	ci.draw_line(r.position, r.end, wood.darkened(0.3), 2.0)
	ci.draw_rect(Rect2(r.get_center() + Vector2(-r.size.x * 0.18, -4), Vector2(r.size.x * 0.36, 8)), Color(0.15, 0.12, 0.1, 0.45))

static func _wall(ci: CanvasItem, size: Vector2, floor_y: float, c1: Color, c2: Color, floor_c: Color = Color(0.28, 0.27, 0.27)) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), c1)
	for k in int(size.x / 18.0) + 1:   # corrugated metal
		ci.draw_rect(Rect2(k * 18.0, 0, 9.0, floor_y), c2)
	ci.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), floor_c)


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
## Where each trophy stands on the bay's shelves: [index into the trophy list, base point] (newest ones
## shown). Used for drawing them and for tapping them.
## The trophy wall in Gus's office (Season): two long shelves above the cork board, the newest
## trophies at the end. [index into the trophies list, base point]
const TROPHY_SCALE := 1.35
static func trophy_spots(size: Vector2, count: int) -> Array:
	var x0 := size.x * 0.05
	var w := size.x * 0.56
	var step := 26.0 * TROPHY_SCALE
	var per_shelf := maxi(1, int((w - 12.0) / step))
	var shown := mini(count, per_shelf * 2)
	var out: Array = []
	for k in shown:
		out.append([count - shown + k, Vector2(x0 + 8.0 + step * 0.5 + (k % per_shelf) * step, size.y * 0.17 + (k / per_shelf) * (size.y * 0.15))])
	return out


static func _trophy_wall(ci: CanvasItem, size: Vector2, info: Dictionary) -> void:
	var list: Array = info.get("medals", [])
	var x0 := size.x * 0.05
	var w := size.x * 0.56
	# two long shelves on brackets, whether there's anything on them yet or not
	for k in 2:
		var y := size.y * 0.17 + k * size.y * 0.15
		ci.draw_rect(Rect2(x0, y, w, 6), Color(0.45, 0.32, 0.2))
		ci.draw_rect(Rect2(x0, y + 6, w, 2), Color(0.3, 0.2, 0.12))
		for bx in [x0 + 10.0, x0 + w - 16.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, y + 6), Vector2(bx + 6, y + 6), Vector2(bx, y + 18)]), Color(0.3, 0.3, 0.32))
	if list.is_empty():
		ci.draw_string(ThemeDB.fallback_font, Vector2(x0, size.y * 0.17 - 8), I18n.t("(room for trophies)"), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.6, 0.6, 0.6, 0.6))
	for s in trophy_spots(size, list.size()):
		var tr: Dictionary = list[s[0]]
		draw_trophy(ci, s[1], str(tr.get("kind", "cup")), int(tr.get("medal", 1)), TROPHY_SCALE)
	# the championship belt hangs on the wall beside the shelves
	if info.get("champion", false):
		var gold: Color = MEDAL_COLORS[1]
		var bc := Vector2(size.x * 0.74, size.y * 0.42)
		ci.draw_rect(Rect2(bc.x - 52, bc.y - 6, 104, 12), Color(0.15, 0.12, 0.1))
		ci.draw_circle(bc, 16, gold)
		ci.draw_circle(bc, 10, Color(0.8, 0.15, 0.2))
		ci.draw_circle(bc, 4, gold)
		for side in [-1.0, 1.0]:
			ci.draw_circle(bc + Vector2(side * 32, 0), 7, gold)


static func _bay_trophies(ci: CanvasItem, size: Vector2, info: Dictionary) -> void:
	_scoreboard(ci, Rect2(10, 24, size.x * 0.4, 82), info)


## One trophy standing on a shelf at base, one design per league: open (ticket plaque), scrap (welded robot),
## rust (hex nut), iron (shield), steel (star), title (the big cup with a crown), cups (small cup, purple plinth).
static func draw_trophy(ci: CanvasItem, base: Vector2, kind: String, medal: int, s: float) -> void:
	var c: Color = MEDAL_COLORS[clampi(medal, 0, 3)]
	var dark := c.darkened(0.3)
	var wood := Color(0.35, 0.25, 0.18)
	match kind:
		"open":
			# Open Trials: a small wooden plaque with a ticket stub nailed to it
			ci.draw_rect(Rect2(base + Vector2(-9, -22) * s, Vector2(18, 22) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-9, -22) * s, Vector2(18, 22) * s), wood.darkened(0.3), false, 1.2 * s)
			ci.draw_rect(Rect2(base + Vector2(-6, -16) * s, Vector2(12, 8) * s), c)
			ci.draw_circle(base + Vector2(-6, -12) * s, 1.6 * s, wood)
			ci.draw_circle(base + Vector2(6, -12) * s, 1.6 * s, wood)
			ci.draw_circle(base + Vector2(0, -19.5) * s, 1.0 * s, Color(0.7, 0.7, 0.72))
		"rust":
			# Rust League: a giant hex nut, rusty orange inside the medal metal, on a plinth
			ci.draw_rect(Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), wood)
			var hc := base + Vector2(0, -16) * s
			var hexp := PackedVector2Array()
			for k in 6:
				hexp.append(hc + Vector2(cos(k * PI / 3.0 + PI / 6.0), sin(k * PI / 3.0 + PI / 6.0)) * 10.0 * s)
			ci.draw_colored_polygon(hexp, c)
			ci.draw_circle(hc, 4.5 * s, Color(0.55, 0.27, 0.12))
			ci.draw_arc(hc, 4.5 * s, 0, TAU, 10, dark, 1.2 * s)
		"iron", "regional":
			# Iron League: a shield on a stand
			ci.draw_rect(Rect2(base + Vector2(-7, -5) * s, Vector2(14, 5) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-1.5, -9) * s, Vector2(3, 4) * s), dark)
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -28) * s, base + Vector2(9, -28) * s, base + Vector2(9, -18) * s,
					base + Vector2(0, -9) * s, base + Vector2(-9, -18) * s]), c)
			ci.draw_line(base + Vector2(0, -27) * s, base + Vector2(0, -11) * s, dark, 1.6 * s)
			ci.draw_line(base + Vector2(-8, -21) * s, base + Vector2(8, -21) * s, dark, 1.6 * s)
		"steel":
			# Steel League: a five-pointed star on a tall stem
			ci.draw_rect(Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), Color(0.2, 0.22, 0.26))
			ci.draw_rect(Rect2(base + Vector2(-1.5, -16) * s, Vector2(3, 11) * s), Color(0.7, 0.75, 0.82))
			var sc := base + Vector2(0, -25) * s
			var star := PackedVector2Array()
			for k in 10:
				var rr := (10.0 if k % 2 == 0 else 4.2) * s
				star.append(sc + Vector2(cos(-PI / 2.0 + k * PI / 5.0), sin(-PI / 2.0 + k * PI / 5.0)) * rr)
			ci.draw_colored_polygon(star, c)
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
		"championship", "title":
			# the big one: two-step base, tall stem, wide cup and a little robot on the lid
			ci.draw_rect(Rect2(base + Vector2(-10, -5) * s, Vector2(20, 5) * s), wood)
			ci.draw_rect(Rect2(base + Vector2(-7, -9) * s, Vector2(14, 4) * s), wood.lightened(0.1))
			ci.draw_rect(Rect2(base + Vector2(-2, -19) * s, Vector2(4, 10) * s), c)
			ci.draw_arc(base + Vector2(0, -27) * s, 10 * s, 0, PI, 12, c, 8.0 * s)
			ci.draw_rect(Rect2(base + Vector2(-11, -35) * s, Vector2(22, 3) * s), c)
			ci.draw_arc(base + Vector2(-12, -28) * s, 5 * s, PI * 0.5, PI * 1.5, 6, c, 2.0 * s)
			ci.draw_arc(base + Vector2(12, -28) * s, 5 * s, -PI * 0.5, PI * 0.5, 6, c, 2.0 * s)
			# a crown on the lid: the Titanium Championship
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -36) * s, base + Vector2(-6, -41) * s, base + Vector2(-3, -38) * s,
					base + Vector2(0, -43) * s, base + Vector2(3, -38) * s, base + Vector2(6, -41) * s, base + Vector2(6, -36) * s]), c.lightened(0.15))
			ci.draw_circle(base + Vector2(0, -28) * s, 2.5 * s, Color(0.9, 0.2, 0.25))
		_:   # cups: a small cup on a purple plinth
			ci.draw_rect(Rect2(base + Vector2(-5, -5) * s, Vector2(10, 5) * s), Color(0.42, 0.25, 0.55))
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
		[I18n.t("WINS %d") % int(info.get("wins", 0)), I18n.t("LOSSES %d") % int(info.get("losses", 0)), Color(0.3, 1.0, 0.4), Color(1.0, 0.35, 0.25)],
		[I18n.t("ENEMY PARTS WE DESTROYED"), "", Color(0.75, 0.75, 0.8), Color.WHITE],
		[I18n.t("HEADS %d") % int(st.get("heads", 0)), I18n.t("ARMS %d") % int(st.get("arms", 0)), Color(1.0, 0.75, 0.2), Color(1.0, 0.75, 0.2)],
		[I18n.t("LEGS %d") % int(st.get("legs", 0)), I18n.t("CORES %d") % int(st.get("cores", 0)), Color(1.0, 0.75, 0.2), Color(1.0, 0.45, 0.2)],
	]
	for k in lines.size():
		var y := r.position.y + (k + 1) * r.size.y / lines.size() - 5.0
		if lines[k][1] == "":
			# a heading across the whole board
			ci.draw_line(Vector2(r.position.x + 4, y - fs - 2.0), Vector2(r.end.x - 4, y - fs - 2.0), Color(0.3, 0.3, 0.36), 1.0)
			var hs := fs - 1
			while hs > 7 and f.get_string_size(lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x > r.size.x - 8:
				hs -= 1
			ci.draw_string(f, Vector2(r.position.x + 4, y), lines[k][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, hs, lines[k][2])
			continue
		ci.draw_string(f, Vector2(r.position.x + 4, y), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, fs, lines[k][2])
		ci.draw_string(f, Vector2(r.position.x + r.size.x * 0.5, y), lines[k][1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5 - 2, fs, lines[k][3])


## Gus's tool board: a pegboard with a wrench, hammer, screwdriver, pliers and a roll of red tape on it.
static func _tool_board(ci: CanvasItem, pb: Rect2) -> void:
	ci.draw_rect(pb, Color(0.42, 0.33, 0.22))
	ci.draw_rect(pb, Color(0.3, 0.23, 0.15), false, 3.0)
	for gx in range(int(pb.size.x / 14.0)):
		for gy in range(int(pb.size.y / 14.0)):
			ci.draw_circle(pb.position + Vector2(8 + gx * 14.0, 8 + gy * 14.0), 1.3, Color(0.3, 0.23, 0.15))
	var steel := Color(0.68, 0.7, 0.75)
	var u := pb.size.x / 5.0
	var top := pb.position.y + 12.0
	var len := pb.size.y - 26.0
	# wrench: shaft with an open jaw on top
	var wx := pb.position.x + u * 0.6
	ci.draw_line(Vector2(wx, top + 10), Vector2(wx, top + len), steel, 5.0)
	ci.draw_circle(Vector2(wx, top + 6), 8, steel)
	ci.draw_rect(Rect2(wx - 3, top - 3, 6, 9), Color(0.42, 0.33, 0.22))
	# hammer: wooden handle, steel head
	var hx := pb.position.x + u * 1.6
	ci.draw_line(Vector2(hx, top + 4), Vector2(hx, top + len), Color(0.7, 0.5, 0.28), 5.0)
	ci.draw_rect(Rect2(hx - 13, top - 2, 26, 10), Color(0.45, 0.47, 0.52))
	# screwdriver: red handle, thin shaft
	var sx := pb.position.x + u * 2.5
	ci.draw_rect(Rect2(sx - 4, top, 8, len * 0.4), Color(0.8, 0.22, 0.2))
	ci.draw_line(Vector2(sx, top + len * 0.4), Vector2(sx, top + len), steel, 2.0)
	# pliers: two handles crossing at a pivot
	var px := pb.position.x + u * 3.4
	ci.draw_line(Vector2(px - 2, top), Vector2(px + 6, top + len), Color(0.2, 0.35, 0.75), 4.0)
	ci.draw_line(Vector2(px + 2, top), Vector2(px - 6, top + len), Color(0.2, 0.35, 0.75), 4.0)
	ci.draw_line(Vector2(px - 2, top - 4), Vector2(px + 2, top), steel, 4.0)
	ci.draw_circle(Vector2(px, top + len * 0.3), 3, steel)
	# roll of red tape on a peg
	var tc := Vector2(pb.position.x + u * 4.4, top + len * 0.45)
	ci.draw_circle(tc, 11, Color(0.75, 0.2, 0.2))
	ci.draw_circle(tc, 5, Color(0.42, 0.33, 0.22))
