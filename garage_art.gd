extends RefCounted
## The little living scenes in the garage's left panel: Gus's bay, the parts website, the
## workbench, the scrapyard, the paint job, training, the team and the trophy wall.
## draw_back() draws behind the robot, draw_front() draws the people and props in front.

const I18n = preload("res://i18n.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")
const Light = preload("res://light.gd")

## Where the robot stands in each scene: [x as fraction of width, height as fraction of panel]
const ROBOT_SPOT := {
	"build": [0.55, 0.64], "shop": [0.8, 0.5], "brass": [0.8, 0.5], "hell": [0.8, 0.5], "volta": [0.78, 0.5], "nimbus": [0.8, 0.5], "kane": [0.78, 0.5], "tenryu": [0.8, 0.5], "circus": [0.8, 0.5], "workshop": [0.74, 0.56], "scrap": [0.8, 0.5],
	"paint": [0.5, 0.72], "moves": [0.62, 0.7], "team": [0.64, 0.66], "cups": [0.68, 0.62],
	"storage": [0.72, 0.5],
}


static func robot_spot(scene: String) -> Array:
	return ROBOT_SPOT.get(scene, [0.5, 0.85])


## info: {"pilot": look, "paint": Color, "spark": seconds since last spark burst, "dig": seconds since last dig,
##        "found": text of the last dig find, "trophies": int, "backup": look or {}}
## The whole-screen background for a scene. stage = where the robot panel is (people and props go there).
static func draw_back(ci: CanvasItem, screen: Vector2, stage: Rect2, scene: String, t: float, info: Dictionary) -> void:
	PilotArt.light = scene_light(scene)
	var floor_screen := stage.end.y - 20.0
	_environment(ci, screen, floor_screen, scene, t, info)
	_begin(scene)
	_room_dim(ci, screen, stage, floor_screen, scene)
	ci.draw_set_transform(stage.position, 0.0, Vector2.ONE)
	info["_stage"] = stage.position
	_props_back(ci, stage.size, scene, t, info)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_room_floor(ci, screen, stage, floor_screen, scene)
	_on = false


## Walls, sky and floor across the whole screen.
## Places outside Gus's building have their own colour, so you know where you are at a glance.
## Rooms inside his building share the bay's bare steel and are told apart by what's in them
## (crates in the storeroom, the workbench, the chalkboard, the fight-net screen, gantries...).
## [wall, wall stripes, floor]
const BAY_COLORS := [Color(0.19, 0.19, 0.18), Color(0.23, 0.23, 0.22), Color(0.28, 0.27, 0.27)]
const SCENE_COLORS := {
	"build": BAY_COLORS, "storage": BAY_COLORS, "workshop": BAY_COLORS, "moves": BAY_COLORS,
	"paint": BAY_COLORS, "team": BAY_COLORS, "office": BAY_COLORS, "cups": BAY_COLORS,
	"shop": [Color(0.07, 0.12, 0.27), Color(0.09, 0.15, 0.32), Color(0.17, 0.19, 0.26)],       # the dealer's: shop-window blue
	"pub": [Color(0.25, 0.06, 0.09), Color(0.29, 0.08, 0.11), Color(0.16, 0.08, 0.07)],        # The Rusty Bolt: wine red
	"brass": [Color(0.2, 0.13, 0.08), Color(0.24, 0.16, 0.09), Color(0.17, 0.11, 0.07)],      # (1.98) Brassworks & Sons: dark wood panels
	"volta": [Color(0.1, 0.06, 0.18), Color(0.13, 0.08, 0.22), Color(0.08, 0.06, 0.12)],      # (1.100) Volta Motor: night purple, neon
	"nimbus": [Color(0.55, 0.6, 0.66), Color(0.6, 0.65, 0.71), Color(0.4, 0.42, 0.45)],        # (1.101) Nimbus Aerial: a pale hangar
	"kane": [Color(0.05, 0.05, 0.07), Color(0.07, 0.07, 0.09), Color(0.08, 0.08, 0.1)],        # (1.102) Kane Dynamics: black glass
	"tenryu": [Color(0.3, 0.19, 0.12), Color(0.34, 0.22, 0.14), Color(0.42, 0.3, 0.18)],        # (1.103) Tenryu: a wooden dojo
	"circus": [Color(0.06, 0.07, 0.16), Color(0.08, 0.09, 0.2), Color(0.36, 0.24, 0.15)],       # (1.109) the Menagerie: night harbour, a wooden deck
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
	elif scene == "hell":
		# (1.99) the breaker's yard on the docks at dusk: a bruised sky, the harbour, cranes against it
		for k in 10:
			var c := Color(0.95, 0.45, 0.22).lerp(Color(0.16, 0.1, 0.22), 1.0 - k / 9.0)
			ci.draw_rect(Rect2(0, k * floor_y * 0.07, screen.x, floor_y * 0.07 + 1), c)
		ci.draw_rect(Rect2(0, floor_y * 0.7, screen.x, floor_y * 0.3), Color(0.12, 0.1, 0.16))   # the water
		for k in 6:
			var wy := floor_y * (0.74 + k * 0.04)
			ci.draw_line(Vector2(fmod(k * 137.0 + t * 8.0, screen.x * 0.6), wy), Vector2(fmod(k * 137.0 + t * 8.0, screen.x * 0.6) + 40.0, wy), Color(1.0, 0.55, 0.3, 0.18), 2.0)
		for cx in [screen.x * 0.3, screen.x * 0.58, screen.x * 0.9]:
			var hb := floor_y * 0.7
			var top := floor_y * 0.16
			var col := Color(0.1, 0.08, 0.13)
			ci.draw_line(Vector2(cx - 18, hb), Vector2(cx - 6, top), col, 4.0)
			ci.draw_line(Vector2(cx + 18, hb), Vector2(cx + 6, top), col, 4.0)
			for j in 4:
				var yy := lerpf(hb, top, (j + 1) / 5.0)
				ci.draw_line(Vector2(cx - 15 + j * 2.4, yy), Vector2(cx + 15 - j * 2.4, yy), col, 2.0)
			ci.draw_line(Vector2(cx - 70, top), Vector2(cx + 50, top), col, 5.0)
			ci.draw_line(Vector2(cx + 30, top), Vector2(cx + 30, top + 40), col, 1.5)
			if fmod(t * 0.8 + cx, 2.0) < 1.0:
				ci.draw_circle(Vector2(cx - 6, top - 4), 2.5, Color(1.0, 0.25, 0.2))
		ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), Color(0.24, 0.22, 0.22))   # concrete
		for k in int(screen.x / 120.0) + 1:
			ci.draw_line(Vector2(k * 120.0, floor_y), Vector2(k * 120.0 - 40.0, screen.y), Color(0.18, 0.17, 0.17), 2.0)
	elif scene == "circus":
		# (1.109) the circus ship at night: a deep blue sky with stars, the harbour lights in the water, a planked deck
		for k in 10:
			var c2 := Color(0.04, 0.05, 0.13).lerp(Color(0.16, 0.12, 0.26), k / 9.0)
			ci.draw_rect(Rect2(0, k * floor_y * 0.08, screen.x, floor_y * 0.08 + 1), c2)
		for k in 40:
			var sp := Vector2(fmod(k * 197.0, screen.x), fmod(k * 61.0, floor_y * 0.5))
			ci.draw_circle(sp, 1.0 + (k % 3) * 0.4, Color(1, 1, 1, 0.35 + 0.35 * sin(t * 2.0 + k)))
		ci.draw_rect(Rect2(0, floor_y * 0.78, screen.x, floor_y * 0.22), Color(0.05, 0.07, 0.13))   # the water
		for k in 14:
			var lx := fmod(k * 113.0, screen.x)
			ci.draw_line(Vector2(lx, floor_y * 0.8 + (k % 4) * 6.0), Vector2(lx + 18.0 + sin(t + k) * 6.0, floor_y * 0.8 + (k % 4) * 6.0), Color(1.0, 0.75, 0.35, 0.25), 2.0)
		ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), Color(0.36, 0.24, 0.15))   # the deck
		for k in 6:
			var py := floor_y + pow((k + 1) / 7.0, 1.4) * (screen.y - floor_y)
			ci.draw_line(Vector2(0, py), Vector2(screen.x, py), Color(0.26, 0.17, 0.1), 2.0)
	elif scene == "volta":
		var vc: Array = SCENE_COLORS["volta"]
		ci.draw_rect(Rect2(Vector2.ZERO, screen), vc[0])
		ci.draw_rect(Rect2(0, floor_y, screen.x, screen.y - floor_y), vc[2])
		# a neon grid floor running to the horizon
		for k in 7:
			var gy := floor_y + pow(k / 6.0, 1.8) * (screen.y - floor_y)
			ci.draw_line(Vector2(0, gy), Vector2(screen.x, gy), Color(1.0, 0.3, 0.75, 0.35), 1.5)
		for k in 21:
			var gx := screen.x * 0.5 + (k - 10) * 60.0
			ci.draw_line(Vector2(screen.x * 0.5 + (k - 10) * 18.0, floor_y), Vector2(screen.x * 0.5 + (gx - screen.x * 0.5) * 3.0, screen.y), Color(0.3, 0.9, 1.0, 0.3), 1.5)
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
			_ln(ci, Vector2(lx - rh * 0.07, floor_y), Vector2(lx, top_y), wood, 4.0)
			_ln(ci, Vector2(lx + rh * 0.1, floor_y), Vector2(lx + rh * 0.02, top_y), wood.darkened(0.25), 4.0)
			for k in 5:
				var f := float(k + 1) / 6.0
				var ry := lerpf(floor_y, top_y, f)
				_ln(ci, Vector2(lerpf(lx - rh * 0.07, lx, f), ry), Vector2(lerpf(lx + rh * 0.1, lx + rh * 0.02, f), ry), wood, 3.0)
			var ps := clampf(size.y / 300.0, 0.6, 1.3)
			PilotArt.draw_person(ci, Vector2(lx + 4.0, lerpf(floor_y, top_y, 0.68)), ps, info.get("pilot", {}), -1.0, "point", t + 1.3)
			_head(info, "YOU", Vector2(lx + 4.0, lerpf(floor_y, top_y, 0.68)), ps)
			if info.has("gantry"):
				_gantry(ci, info["gantry"], floor_y)
			# lift platform
			_rc(ci, Rect2(size.x * 0.56 - 50, floor_y - 6, 100, 8), Color(0.75, 0.6, 0.15))
			for k in 6:
				_ln(ci, Vector2(size.x * 0.56 - 48 + k * 18, floor_y - 6), Vector2(size.x * 0.56 - 40 + k * 18, floor_y + 2), Color(0.15, 0.15, 0.15), 3.0)
		"pub":
			_pub_back(ci, size, floor_y, t, info)
		"office":
			_office_back(ci, size, floor_y, t, info)
		"shop":
			# window with the city at night
			var w := Rect2(size.x * 0.58, 22, size.x * 0.36, size.y * 0.32)
			_rc(ci, w, Color(0.05, 0.06, 0.12))
			for k in 6:
				var bx := w.position.x + 4 + k * w.size.x / 6.0
				var bh := w.size.y * (0.3 + 0.5 * fmod(k * 0.37, 1.0))
				_rc(ci, Rect2(bx, w.end.y - bh, w.size.x / 6.0 - 3, bh), Color(0.12, 0.13, 0.2))
				if int(t * 0.7 + k) % 3 == 0:
					_rc(ci, Rect2(bx + 4, w.end.y - bh + 6, 3, 3), Color(1.0, 0.85, 0.4))
			_rc(ci, w, Color(0.35, 0.35, 0.4), false, 3.0)
			# (1.97) Parts-R-Us is Old Iron's dealer: the foundry's enamel sign on the wall
			_maker_plaque(ci, Rect2(size.x * 0.06, 26, size.x * 0.4, 40), "oldiron", I18n.t("OLD IRON FOUNDRY"), I18n.t("AUTHORISED DEALER"))
		"brass":
			_brass_back(ci, size, floor_y, t)
		"hell":
			_hell_back(ci, size, floor_y, t)
		"volta":
			_volta_back(ci, size, floor_y, t)
		"nimbus":
			_nimbus_back(ci, size, floor_y, t)
		"kane":
			_kane_back(ci, size, floor_y, t)
		"tenryu":
			_tenryu_back(ci, size, floor_y, t)
		"circus":
			_circus_back(ci, size, floor_y, t)
		"workshop":
			_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("CUSTOM ORDERS"), Color(0.6, 0.85, 1.0))
			# shelves of parts
			for row in 2:
				var y := 50.0 + row * 34.0
				_rc(ci, Rect2(size.x * 0.5, y, size.x * 0.45, 4), Color(0.4, 0.3, 0.2))
				for k in 4:
					_rc(ci, Rect2(size.x * 0.52 + k * size.x * 0.1, y - 12 - (k + row) % 2 * 4, 14, 12 + (k + row) % 2 * 4), Color.from_hsv(fmod(k * 0.23 + row * 0.4, 1.0), 0.3, 0.55))
		"scrap":
			# a crane with its hook
			_ln(ci, Vector2(size.x * 0.12, floor_y), Vector2(size.x * 0.12, 24), Color(0.25, 0.22, 0.2), 6.0)
			_ln(ci, Vector2(size.x * 0.12, 26), Vector2(size.x * 0.62, 26), Color(0.25, 0.22, 0.2), 5.0)
			var hook_x := size.x * 0.5 + sin(t * 0.8) * 8.0
			_ln(ci, Vector2(size.x * 0.5, 26), Vector2(hook_x, 70), Color(0.2, 0.2, 0.2), 2.0)
			_ac(ci, Vector2(hook_x, 76), 6, 0, PI * 1.3, 8, Color(0.3, 0.3, 0.3), 3.0)
			_scrap_pile(ci, Vector2(size.x * 0.38, floor_y), size.x * 0.42, size.y * 0.45, t)
			# (1.97) Scrapworks' hand-painted board, nailed to a post and taped where it split
			var pl := Rect2(size.x * 0.18, 72, size.x * 0.24, 32)   # hung from the crane's jib on two ropes
			_ln(ci, Vector2(pl.position.x + 6, 26), Vector2(pl.position.x + 6, pl.position.y + 3), Color(0.55, 0.45, 0.3), 1.5)
			_ln(ci, Vector2(pl.end.x - 6, 26), Vector2(pl.end.x - 6, pl.position.y + 1), Color(0.55, 0.45, 0.3), 1.5)
			_maker_plaque(ci, pl, "scrapworks", I18n.t("SCRAPWORKS"), I18n.t("WE BUY JUNK"))
		"paint":
			# drop cloth with splatters in the paint colour
			var pc: Color = info.get("paint", Color(0.8, 0.3, 0.2))
			_rc(ci, Rect2(10, floor_y - 4, size.x - 20, 10), Color(0.85, 0.82, 0.75))
			for k in 7:
				_cr(ci, Vector2(20 + k * (size.x - 40) / 6.0, floor_y + fmod(k * 3.7, 4.0)), 3 + k % 3, pc)
			for k in 5:
				_cr(ci, Vector2(size.x * (0.2 + k * 0.15), 40 + fmod(k * 13.0, 30.0)), 4 + k % 3, Color(pc.r, pc.g, pc.b, 0.5))
			# the spray booth: a rail with plastic curtains pulled back at both sides, an extractor fan,
			# and years of old paint jobs sprayed over the back wall
			for k in 14:
				var old_c := Color.from_hsv(fmod(k * 0.27, 1.0), 0.6, 0.7, 0.35)
				_cr(ci, Vector2(size.x * (0.12 + fmod(k * 0.41, 0.8)), size.y * (0.15 + fmod(k * 0.23, 0.5))), 6 + (k * 5) % 9, old_c)
			_ln(ci, Vector2(0, 16), Vector2(size.x, 16), Color(0.55, 0.56, 0.6), 4.0)
			for side in [0.0, 1.0]:
				var x0 := 4.0 if side == 0.0 else size.x * 0.83
				var curtain := PackedVector2Array([Vector2(x0, 18), Vector2(x0 + size.x * 0.13, 18), Vector2(x0 + size.x * 0.08, floor_y), Vector2(x0, floor_y)])
				_pg(ci, curtain, Color(0.8, 0.88, 0.9, 0.22))
				for f in 4:
					var fx := x0 + 6 + f * size.x * 0.03
					_ln(ci, Vector2(fx, 18), Vector2(fx - 2, floor_y), Color(1, 1, 1, 0.12), 2.0)
			var fan := Vector2(size.x * 0.5, 52)
			_cr(ci, fan, 22, Color(0.15, 0.15, 0.17))
			for k in 4:
				var a := t * 9.0 + k * PI / 2.0
				_ln(ci, fan, fan + Vector2(cos(a), sin(a)) * 18, Color(0.5, 0.5, 0.55), 5.0)
			_ac(ci, fan, 22, 0, TAU, 24, Color(0.4, 0.4, 0.45), 3.0)
			_sign(ci, Vector2(size.x * 0.5, 96), I18n.t("PAINT BOOTH"), Color(0.95, 0.5, 0.8))
		"moves":
			# chalkboard of move inputs
			var b := Rect2(12, 22, size.x * 0.5, size.y * 0.3)
			_rc(ci, b, Color(0.1, 0.22, 0.15))
			_rc(ci, b, Color(0.5, 0.35, 0.2), false, 4.0)
			var f := ThemeDB.fallback_font
			ci.draw_string(f, b.position + Vector2(8, 24), I18n.t("↓ → P"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85))
			ci.draw_string(f, b.position + Vector2(8, 48), I18n.t("← → K"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.85, 0.8))
			_rc(ci, Rect2(size.x * 0.45, floor_y - 6, size.x * 0.4, 6), Color(0.3, 0.3, 0.35))   # practice mat
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
			_rc(ci, Rect2(12, 70, size.x - 24, 5), Color(0.45, 0.32, 0.2))
			for k in mini(cups.size(), int((size.x - 30) / 24.0)):
				draw_trophy(ci, Vector2(26.0 + k * 24.0, 70), "cup", int(cups[k].get("medal", 1)), 1.0)
			# posters
			for k in 2:
				var p := Rect2(16 + k * 70, 90, 56, 70)
				_rc(ci, p, Color.from_hsv(0.05 + k * 0.5, 0.5, 0.45))
				ci.draw_string(ThemeDB.fallback_font, p.position + Vector2(4, 20), I18n.t("CUP"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
		_:
			pass


## People and props in front, around the robot. robot_base / robot_h are in stage coordinates.
static func draw_front(ci: CanvasItem, stage: Rect2, scene: String, t: float, info: Dictionary, robot_base: Vector2, robot_h: float) -> void:
	_begin(scene)
	ci.draw_set_transform(stage.position, 0.0, Vector2.ONE)
	info["_stage"] = stage.position
	_front(ci, stage.size, scene, t, info, robot_base, robot_h)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_room_edges(ci, stage, scene)
	_on = false


## The light the people in a scene stand in (1.60): Gus's building is the bay's work lamp, the places
## outside have their own.
static func scene_light(scene: String) -> String:
	return scene if scene in ["pub", "shop", "scrap", "phone", "brass", "hell", "volta", "nimbus", "kane", "tenryu", "circus"] else "bay"


static func _front(ci: CanvasItem, size: Vector2, scene: String, t: float, info: Dictionary, robot_base: Vector2, robot_h: float) -> void:
	PilotArt.light = scene_light(scene)
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
			_rc(ci, Rect2(desk.position.x + 8, desk.end.y, 6, floor_y - desk.end.y), Color(0.3, 0.22, 0.15))
			_rc(ci, Rect2(desk.end.x - 14, desk.end.y, 6, floor_y - desk.end.y), Color(0.3, 0.22, 0.15))
			_rc(ci, desk, Color(0.45, 0.32, 0.2))
			_rc(ci, Rect2(mon.get_center().x - 4, mon.end.y, 8, desk.position.y - mon.end.y), Color(0.2, 0.2, 0.22))
			_rc(ci, mon, Color(0.12, 0.12, 0.14))
			var scr := mon.grow(-4)
			_rc(ci, scr, Color(0.9, 0.93, 0.97))
			_rc(ci, Rect2(scr.position, Vector2(scr.size.x, 9 * s)), Color(0.9, 0.45, 0.2))
			ci.draw_string(ThemeDB.fallback_font, scr.position + Vector2(3, 8 * s), I18n.t("PARTS-R-US"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), Color.WHITE)
			var scroll := fmod(t * 6.0, 14.0 * s)
			for k in 6:
				var tile := Rect2(scr.position.x + 4 + (k % 3) * scr.size.x / 3.0, scr.position.y + 12 * s + int(k / 3.0) * 20 * s - scroll + 14 * s,
						scr.size.x / 3.0 - 6, 16 * s)
				if tile.position.y > scr.position.y + 10 * s and tile.end.y < scr.end.y:
					_rc(ci, tile, Color.from_hsv(fmod(k * 0.19, 1.0), 0.35, 0.8))
			_rc(ci, Rect2(mon.position.x + 10 * s, desk.position.y - 4 * s, 40 * s, 4 * s), Color(0.25, 0.25, 0.28))   # keyboard
			# the pilot types, Gus leans in and points at the screen
			PilotArt.draw_seat(ci, Vector2(mon.position.x + 8 * s, floor_y), s, 1.0)   # (1.81) a real chair
			PilotArt.draw_person(ci, Vector2(mon.position.x + 8 * s, floor_y), s, pilot, 1.0, "sit_type", t)
			_head(info, "YOU", Vector2(mon.position.x + 8 * s, floor_y), s, true)
			PilotArt.draw_person(ci, Vector2(mon.end.x + 22 * s, floor_y), s, gus, -1.0, "point", t + 0.7)
			_head(info, "GUS", Vector2(mon.end.x + 22 * s, floor_y), s)
		"brass":
			# (1.98) old Silas behind the counter, polishing a gauge; you at the counter
			var ct := Rect2(10, floor_y - 46 * s, size.x * 0.5, 46 * s)
			var silas := {"skin": "#d8b08c", "hair": "#e8e4dc", "eyes": "#3a2a1a", "outfit": "#5a3a22", "hat": "bald", "beard": "handlebar", "glasses": "round"}
			var sf := Vector2(ct.position.x + ct.size.x * 0.36, floor_y - 22 * s)   # he stands on a step behind the counter
			PilotArt.draw_person(ci, sf, s, silas, 1.0, "wipe", t)
			_head(info, "SILAS", sf, s)
			_rc(ci, ct, Color(0.36, 0.22, 0.12))
			_rc(ci, Rect2(ct.position.x - 4, ct.position.y - 5 * s, ct.size.x + 8, 6 * s), Color(0.78, 0.6, 0.22))   # the brass rail
			for k in 4:
				_rc(ci, Rect2(ct.position.x + 10 + k * ct.size.x / 4.0, ct.position.y + 10 * s, ct.size.x / 4.0 - 20, ct.size.y - 18 * s), Color(0.3, 0.18, 0.1), false, 2.0)
			# a gauge on the counter, its needle wobbling
			var gc := Vector2(ct.position.x + ct.size.x * 0.75, ct.position.y - 12 * s)
			_cr(ci, gc, 9 * s, Color(0.78, 0.6, 0.22))
			ci.draw_circle(gc, 6.5 * s, Color(0.95, 0.92, 0.82))
			var na := -2.0 + 1.6 * (0.5 + 0.5 * sin(t * 1.3))
			ci.draw_line(gc, gc + Vector2(cos(na), sin(na)) * 5.5 * s, Color(0.6, 0.1, 0.08), 1.5)
			PilotArt.draw_person(ci, Vector2(ct.end.x + 26 * s, floor_y), s, pilot, -1.0, "point", t + 0.5)
			_head(info, "YOU", Vector2(ct.end.x + 26 * s, floor_y), s)
		"circus":
			# (1.109) Ringmaster Esme in her red tailcoat and top hat presents the show; you with your controller
			var esme := {"skin": "#c98a5e", "hair": "#1a1a1a", "eyes": "#6b3a1e", "outfit": "#b8282e", "hat": "tophat", "beard": "none",
					"glasses": "none", "long_hair": true, "female": true}
			var ef := Vector2(size.x * 0.56, floor_y)
			PilotArt.draw_person(ci, ef, s, esme, 1.0, "point", t)
			_head(info, "ESME", ef, s)
			_rc(ci, Rect2(ef.x - 12 * s, ef.y - 46 * s, 24 * s, 3 * s), Color(0.95, 0.75, 0.25))   # her gold sash
			PilotArt.draw_person(ci, Vector2(size.x * 0.3, floor_y), s, pilot, 1.0, "hold", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.3, floor_y), s)
		"tenryu":
			# (1.103) Haru in a red jacket and headband, pointing like a hero; you with your controller
			var haru := {"skin": "#e2b48c", "hair": "#222222", "eyes": "#5b3a1e", "outfit": "#b8282e", "hat": "headband", "beard": "none", "glasses": "none"}
			var hf2 := Vector2(size.x * 0.55, floor_y)
			PilotArt.draw_person(ci, hf2, s, haru, 1.0, "point", t)
			_head(info, "HARU", hf2, s)
			PilotArt.draw_person(ci, Vector2(size.x * 0.3, floor_y), s, pilot, 1.0, "hold", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.3, floor_y), s)
		"kane":
			# (1.102) Ms. Vale in a black suit with a gold earpiece; you, a little out of place
			var vale := {"skin": "#f1d0b5", "hair": "#e8d36a", "eyes": "#8395a7", "outfit": "#222222", "hat": "bun", "beard": "none",
					"glasses": "none", "female": true}
			var vf := Vector2(size.x * 0.55, floor_y)
			PilotArt.draw_person(ci, vf, s, vale, 1.0, "clipboard", t)
			_head(info, "VALE", vf, s)
			ci.draw_circle(vf + Vector2(-3 * s, -62 * s), 1.6 * s, Color(0.95, 0.8, 0.35))
			PilotArt.draw_person(ci, Vector2(size.x * 0.3, floor_y), s, pilot, 1.0, "hold", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.3, floor_y), s)
		"nimbus":
			# (1.101) Captain Wren in her flight jacket, goggles up, a clipboard of test notes; you with your controller
			var wren := {"skin": "#b07a52", "hair": "#2a1d14", "eyes": "#27ae60", "outfit": "#7a4b2a", "hat": "bun", "beard": "none",
					"glasses": "goggles", "female": true, "scar": false}
			var wf := Vector2(size.x * 0.56, floor_y)
			PilotArt.draw_person(ci, wf, s, wren, 1.0, "clipboard", t)
			_head(info, "WREN", wf, s)
			PilotArt.draw_person(ci, Vector2(size.x * 0.32, floor_y), s, pilot, 1.0, "hold", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.32, floor_y), s)
		"volta":
			# (1.100) Dex in his pastel jacket and shades sells you the future; you hold your controller and try to look calm
			var dex := {"skin": "#e2b48c", "hair": "#c49a3c", "eyes": "#2e86de", "outfit": "#4ecdc4", "hat": "", "beard": "stubble",
					"glasses": "shades", "long_hair": true}
			var df := Vector2(size.x * 0.56, floor_y)
			PilotArt.draw_person(ci, df, s, dex, 1.0, "clipboard", t)
			_head(info, "DEX", df, s)
			PilotArt.draw_person(ci, Vector2(size.x * 0.3, floor_y), s, pilot, 1.0, "hold", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.3, floor_y), s)
		"hell":
			# (1.99) Magda welds a crushed bale in her mask, sparks everywhere; you watch from a safe distance
			var magda := {"skin": "#c8946e", "hair": "#2a1d14", "eyes": "#5b3a1e", "outfit": "#d35400", "hat": "headband", "beard": "none",
					"glasses": "goggles", "long_hair": true, "female": true, "scar": true}
			var bale := Rect2(size.x * 0.06, floor_y - 44 * s, 62 * s, 44 * s)
			_crushed(ci, bale, 3)
			var mf := Vector2(bale.end.x + 24 * s, floor_y)
			PilotArt.draw_person(ci, mf, s, magda, -1.0, "wrench", t)
			_head(info, "MAGDA", mf, s)
			if fmod(t, 1.6) < 0.9:
				_sparks(ci, Vector2(bale.end.x - 2 * s, bale.position.y + 18 * s), t, 1.2)
				ci.draw_circle(Vector2(bale.end.x - 2 * s, bale.position.y + 18 * s), 16 * s, Color(0.7, 0.85, 1.0, 0.25 + 0.15 * sin(t * 40.0)))
			PilotArt.draw_person(ci, Vector2(size.x * 0.37, floor_y), s, pilot, -1.0, "point", t + 0.5)
			_head(info, "YOU", Vector2(size.x * 0.37, floor_y), s)
		"workshop":
			# workbench with a vise and a spinning grinder; both of them hard at work
			var bench := Rect2(10, floor_y - 40 * s, size.x * 0.62, 8 * s)
			_rc(ci, Rect2(bench.position.x + 6, bench.end.y, 8, floor_y - bench.end.y), Color(0.35, 0.25, 0.15))
			_rc(ci, Rect2(bench.end.x - 14, bench.end.y, 8, floor_y - bench.end.y), Color(0.35, 0.25, 0.15))
			_rc(ci, bench, Color(0.5, 0.36, 0.22))
			var vise := Vector2(bench.position.x + bench.size.x * 0.35, bench.position.y)
			_rc(ci, Rect2(vise + Vector2(-10 * s, -12 * s), Vector2(20 * s, 12 * s)), Color(0.35, 0.4, 0.5))
			_rc(ci, Rect2(vise + Vector2(-4 * s, -20 * s), Vector2(8 * s, 9 * s)), Color(0.6, 0.6, 0.65))   # the part being worked on
			var gr := Vector2(bench.position.x + bench.size.x * 0.82, bench.position.y - 10 * s)
			_cr(ci, gr, 9 * s, Color(0.3, 0.3, 0.32))
			for k in 4:
				var a := t * 14.0 + k * PI / 2.0
				_ln(ci, gr, gr + Vector2(cos(a), sin(a)) * 8 * s, Color(0.6, 0.6, 0.62), 2.0)
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
					_cr(ci, Vector2(pile_x + 30 * s, floor_y - 10) + Vector2(cos(a), sin(a)) * r, 3.0 * (1.2 - dig_age), Color(0.5, 0.42, 0.3, 1.0 - dig_age / 1.2))
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
				_rc(ci, Rect2(cx, floor_y - 18, 16, 18), Color(0.7, 0.7, 0.72))
				_rc(ci, Rect2(cx, floor_y - 12, 16, 8), pc if k == 0 else Color.from_hsv(fmod(k * 0.33 + 0.1, 1.0), 0.7, 0.8))
				_rc(ci, Rect2(cx - 1, floor_y - 20, 18, 3), Color(0.5, 0.5, 0.52))
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
				_rc(ci, Rect2(14, floor_y - 6, 70, 6), Color(0.45, 0.45, 0.5))
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
			# Gus's desk sits under the fight-net screen (the keyboard's cable runs up to it). When he
			# talks about the trophies, he and you stand to the right of the shelves and point up at them.
			var dx := office_desk_x(size)
			_rc(ci, Rect2(dx - 70 * s, floor_y - 40 * s, 150 * s, 8 * s), Color(0.42, 0.3, 0.18))
			_rc(ci, Rect2(dx - 64 * s, floor_y - 32 * s, 6 * s, 32 * s), Color(0.3, 0.2, 0.12))
			_rc(ci, Rect2(dx + 68 * s, floor_y - 32 * s, 6 * s, 32 * s), Color(0.3, 0.2, 0.12))
			# desk lamp and a coffee
			_ln(ci, Vector2(dx + 50 * s, floor_y - 40 * s), Vector2(dx + 40 * s, floor_y - 70 * s), Color(0.2, 0.2, 0.22), 3.0)
			_pg(ci, PackedVector2Array([Vector2(dx + 28 * s, floor_y - 66 * s), Vector2(dx + 50 * s, floor_y - 76 * s), Vector2(dx + 48 * s, floor_y - 64 * s)]), Color(0.75, 0.7, 0.2))
			_pg(ci, PackedVector2Array([Vector2(dx + 36 * s, floor_y - 66 * s), Vector2(dx + 22 * s, floor_y - 41 * s), Vector2(dx + 60 * s, floor_y - 41 * s), Vector2(dx + 48 * s, floor_y - 66 * s)]), Color(1.0, 0.9, 0.5, 0.12))
			_rc(ci, Rect2(dx + 4 * s, floor_y - 48 * s, 8 * s, 8 * s), Color(0.9, 0.9, 0.85))
			if info.get("gus_point", false):
				# up from the desk, standing right of the shelves and pointing up at your dad's trophies
				PilotArt.draw_person(ci, Vector2(size.x * 0.8, floor_y), s, PilotArt.GUS_LOOK, -1.0, "point_up", t)
				_head(info, "GUS", Vector2(size.x * 0.8, floor_y), s)
				PilotArt.draw_person(ci, Vector2(size.x * 0.66, floor_y), s, info.get("pilot", {}), -1.0, "point_up", t + 0.4)
				_head(info, "YOU", Vector2(size.x * 0.66, floor_y), s)
			else:
				# Gus at his keyboard; you looking at the table on the screen
				PilotArt.draw_seat(ci, Vector2(dx - 20 * s, floor_y), s, -1.0)   # (1.81) his chair
				PilotArt.draw_person(ci, Vector2(dx - 20 * s, floor_y), s, PilotArt.GUS_LOOK, -1.0, "sit_type", t)
				_head(info, "GUS", Vector2(dx - 20 * s, floor_y), s, true)
				PilotArt.draw_person(ci, Vector2(size.x * 0.7, floor_y), s, info.get("pilot", {}), -1.0, "point", t + 0.4)
				_head(info, "YOU", Vector2(size.x * 0.7, floor_y), s)
		"storage":
			# two crates being opened: one lid already off with parts sticking out, Gus prying the other
			var a := Rect2(size.x * 0.1, floor_y - 40 * s, 70 * s, 40 * s)
			var b := Rect2(size.x * 0.5, floor_y - 36 * s, 62 * s, 36 * s)
			# what's inside crate A: an arm, a wheel and a head poking out of the straw
			_ln(ci, a.position + Vector2(18 * s, 4 * s), a.position + Vector2(30 * s, -22 * s), Color(0.6, 0.6, 0.66), 6 * s)
			_cr(ci, a.position + Vector2(30 * s, -22 * s), 5 * s, Color(0.5, 0.5, 0.55))
			_cr(ci, a.position + Vector2(48 * s, -4 * s), 9 * s, Color(0.12, 0.12, 0.12))
			_cr(ci, a.position + Vector2(48 * s, -4 * s), 4 * s, Color(0.55, 0.5, 0.45))
			_rc(ci, Rect2(a.position + Vector2(52 * s, -14 * s), Vector2(16 * s, 14 * s)), Color(0.45, 0.5, 0.58))
			_cr(ci, a.position + Vector2(62 * s, -8 * s), 2 * s, Color(1.0, 0.4, 0.2) if fmod(t, 1.4) < 0.7 else Color(0.3, 0.2, 0.2))
			for k in 6:
				_ln(ci, a.position + Vector2((6 + k * 10) * s, 2 * s), a.position + Vector2((10 + k * 10) * s, -4 * s), Color(0.85, 0.75, 0.4), 1.5)
			_crate(ci, a, 0.9)
			# the lid leans against it
			_pg(ci, PackedVector2Array([a.position + Vector2(-4 * s, a.size.y), a.position + Vector2(4 * s, a.size.y),
					a.position + Vector2(-10 * s, -6 * s), a.position + Vector2(-18 * s, -6 * s)]), Color(0.55, 0.4, 0.25))
			# crate B: the lid lifts a little each heave
			var heave := maxf(0.0, sin(t * 2.6)) * 6 * s
			_crate(ci, b, 0.8)
			_rc(ci, Rect2(b.position + Vector2(-2 * s, -6 * s - heave), Vector2(b.size.x + 4 * s, 6 * s)), Color(0.6, 0.45, 0.28))
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
		_rc(ci, Rect2(x - 4, top, 8, floor_y - top), steel)
		_rc(ci, Rect2(x - 10, floor_y - 5, 20, 5), steel.darkened(0.3))
	var beam := Rect2(cx - half - 6, top - 5, half * 2 + 12, 11)
	_rc(ci, beam, Color(0.1, 0.1, 0.1))
	var x := beam.position.x + 2.0
	while x < beam.end.x - 10.0:
		_pg(ci, PackedVector2Array([Vector2(x, beam.end.y - 2), Vector2(x + 5, beam.end.y - 2),
				Vector2(x + 10, beam.position.y + 2), Vector2(x + 5, beam.position.y + 2)]), Color(0.95, 0.76, 0.19))
		x += 12.0
	_ln(ci, Vector2(cx, beam.end.y), Vector2(cx, beam.end.y + 18), Color(0.55, 0.56, 0.6), 2.0)
	_ac(ci, Vector2(cx, beam.end.y + 23), 5.0, -PI * 0.3, PI * 1.1, 8, Color(0.7, 0.7, 0.74), 2.5)


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
		_rc(ci, Rect2(x - 5, beam_y, 10, floor_y - beam_y), steel)
		_rc(ci, Rect2(x - 5, beam_y, 3, floor_y - beam_y), steel.lightened(0.15))
		_rc(ci, Rect2(x - 12, floor_y - 6, 24, 6), steel.darkened(0.3))   # foot plate
	# corner braces
	_ln(ci, Vector2(xl + 4, beam_y + 30), Vector2(xl + 30, beam_y + 8), steel, 4.0)
	_ln(ci, Vector2(xr - 4, beam_y + 30), Vector2(xr - 30, beam_y + 8), steel, 4.0)
	# the beam, hazard striped
	var beam := Rect2(xl - 8, beam_y - 6, xr - xl + 16, 13)
	_rc(ci, beam, Color(0.1, 0.1, 0.1))
	var x := beam.position.x + 2.0
	while x < beam.end.x - 10.0:
		_pg(ci, PackedVector2Array([Vector2(x, beam.end.y - 2), Vector2(x + 6, beam.end.y - 2),
				Vector2(x + 12, beam.position.y + 2), Vector2(x + 6, beam.position.y + 2)]), Color(0.95, 0.76, 0.19))
		x += 14.0
	_rc(ci, beam, Color(0.05, 0.05, 0.05), false, 2.0)
	# chains down to the shoulders, with a hook at the end
	for sh in [sl, sr]:
		var top := Vector2(sh.x, beam.end.y)
		var n := int((sh.y - 10.0 - top.y) / 7.0)
		for k in maxi(n, 0):
			var p := top + Vector2(0, 4 + k * 7.0)
			if k % 2 == 0:
				_rc(ci, Rect2(p - Vector2(2.5, 3.5), Vector2(5, 7)), Color(0.55, 0.56, 0.6), false, 1.6)
			else:
				_ln(ci, p - Vector2(0, 3.5), p + Vector2(0, 3.5), Color(0.55, 0.56, 0.6), 2.0)
		_ac(ci, Vector2(sh.x, sh.y - 6.0), 5.0, PI * 0.1, PI * 1.2, 8, Color(0.7, 0.7, 0.74), 2.5)


# ---------------------------------------------------------------- Gus's office (the Season screens)

## Gus's desk: under the fight-net screen, on the left (people stand right of it).
static func office_desk_x(size: Vector2) -> float:
	return size.x * 0.3


## The trophy shelves, the fight-net screen under them, the wall clock and the sign.
static func _office_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float, info: Dictionary) -> void:
	_trophy_wall(ci, size, info)
	_office_terminal(ci, size, floor_y, t, info)
	# a wall clock
	var cc := Vector2(size.x * 0.68, size.y * 0.24)
	_cr(ci, cc, 18, Color(0.92, 0.92, 0.88))
	_ac(ci, cc, 18, 0, TAU, 24, Color(0.2, 0.2, 0.2), 2.0)
	_ln(ci, cc, cc + Vector2(cos(t * 0.1 - PI / 2), sin(t * 0.1 - PI / 2)) * 13, Color(0.15, 0.15, 0.15), 2.0)
	_ln(ci, cc, cc + Vector2(cos(t * 1.2 - PI / 2), sin(t * 1.2 - PI / 2)) * 15, Color(0.8, 0.1, 0.1), 1.0)
	_sign(ci, Vector2(size.x * 0.8, 30), I18n.t("GUS'S OFFICE"), Color(0.85, 0.9, 0.45))


## The big screen under the trophies: Gus's fight-net terminal, a green CRT on the wall with the
## tables scrolling, your record and a blinking prompt. A cable runs down to the keyboard on his desk.
static func _office_terminal(ci: CanvasItem, size: Vector2, floor_y: float, t: float, info: Dictionary) -> void:
	var scr := Rect2(size.x * 0.05, size.y * 0.4, size.x * 0.5, size.y * 0.3)
	var font := ThemeDB.fallback_font
	var green := Color(0.35, 1.0, 0.5)
	# bezel, wall mount and the screen glow
	ci.draw_rect(Rect2(scr.get_center().x - 10, scr.position.y - 14, 20, 14), Color(0.2, 0.2, 0.22))
	ci.draw_rect(scr.grow(9), Color(0.13, 0.13, 0.15))
	ci.draw_rect(scr.grow(9), Color(0.3, 0.3, 0.33), false, 2.0)
	ci.draw_rect(scr.grow(16), Color(0.3, 1.0, 0.45, 0.04))
	ci.draw_rect(scr, Color(0.02, 0.07, 0.04))
	# a power light on the bezel
	ci.draw_circle(Vector2(scr.end.x + 4, scr.end.y + 5), 2.0, Color(0.3, 1.0, 0.4) if fmod(t, 2.0) < 1.6 else Color(0.1, 0.3, 0.12))
	var fs := int(clampf(scr.size.y / 9.0, 9, 15))
	var lh := fs + 3.0
	var x := scr.position.x + 8
	var y := scr.position.y + lh
	ci.draw_string(font, Vector2(x, y), "PORT FERRUM FIGHT NET", HORIZONTAL_ALIGNMENT_LEFT, scr.size.x - 16, fs, green)
	ci.draw_line(Vector2(x, y + 4), Vector2(scr.end.x - 8, y + 4), Color(green, 0.5), 1.0)
	y += lh + 4
	ci.draw_string(font, Vector2(x, y), "> %s %d-%d" % [I18n.t("RECORD"), int(info.get("wins", 0)), int(info.get("losses", 0))], HORIZONTAL_ALIGNMENT_LEFT, scr.size.x - 16, fs, green)
	y += lh
	# the table scrolling past: rank, a name-length bar, points
	var rows := int((scr.end.y - y - lh) / lh)
	var off := int(t * 0.8)
	for k in rows:
		var n := k + off
		var ry := y + k * lh
		ci.draw_string(font, Vector2(x, ry), "%2d" % (n % 32 + 1), HORIZONTAL_ALIGNMENT_LEFT, 30, fs, Color(green, 0.8))
		var w := scr.size.x * (0.25 + 0.3 * fmod(n * 0.618, 1.0))
		ci.draw_rect(Rect2(x + 30, ry - fs * 0.6, w, fs * 0.55), Color(green, 0.35))
		ci.draw_string(font, Vector2(scr.end.x - 36, ry), "%2d" % int(24 - fmod(n * 2.7, 20.0)), HORIZONTAL_ALIGNMENT_LEFT, 30, fs, Color(green, 0.8))
	# the prompt and its cursor
	var py := scr.end.y - 6
	ci.draw_string(font, Vector2(x, py), "GUS@BAY:~$", HORIZONTAL_ALIGNMENT_LEFT, scr.size.x, fs, green)
	if fmod(t, 1.0) < 0.55:
		ci.draw_rect(Rect2(x + fs * 6.2, py - fs * 0.75, fs * 0.55, fs * 0.85), green)
	# scanlines and a soft sheen
	var sl := scr.position.y
	while sl < scr.end.y:
		ci.draw_line(Vector2(scr.position.x, sl), Vector2(scr.end.x, sl), Color(0, 0, 0, 0.22), 1.0)
		sl += 3.0
	var band := scr.position.y + fmod(t * 30.0, scr.size.y)
	ci.draw_rect(Rect2(scr.position.x, band, scr.size.x, 6), Color(0.4, 1.0, 0.5, 0.05))
	# the cable down the wall to the keyboard on Gus's desk
	var s := clampf(size.y / 300.0, 0.6, 1.3)
	var kb := Vector2(office_desk_x(size) - 20 * s, floor_y - 40 * s)
	ci.draw_polyline(PackedVector2Array([Vector2(scr.end.x + 9, scr.end.y - 10), Vector2(scr.end.x + 18, scr.end.y - 10),
			Vector2(scr.end.x + 18, kb.y - 2), kb + Vector2(14 * s, -2)]), Color(0.1, 0.1, 0.1), 2.0)
	ci.draw_rect(Rect2(kb + Vector2(-20 * s, -5 * s), Vector2(34 * s, 5 * s)), Color(0.22, 0.22, 0.24))
	for k in 6:
		ci.draw_line(kb + Vector2(-18 * s + k * 5.5 * s, -3 * s), kb + Vector2(-15 * s + k * 5.5 * s, -3 * s), Color(0.5, 0.5, 0.52), 1.0)


# ---------------------------------------------------------------- The Rusty Bolt (the Bets screen)

static func _pub_counter_x(size: Vector2) -> float:
	return size.x * 0.52


## Behind the bar: the neon sign, bottles, the TV with tonight's fights, the bartender and the counter.
static func _pub_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float, info: Dictionary) -> void:
	var s := clampf(size.y / 300.0, 0.6, 1.3)
	# the TV: big on the wall, 16:9 (1.79). The week's clips play on it (garage.update_tv lays a player
	# over tv_rect); with nothing to show it's the fight net's test card.
	var tvw := minf(size.x * 0.86, size.y * 0.36 * 16.0 / 9.0)
	var tvh := tvw * 9.0 / 16.0
	var tv := Rect2((size.x - tvw) * 0.5, maxf(size.y * 0.11, 64.0), tvw, tvh)   # under the top strip
	info["tv_rect"] = tv   # (1.76) the week's best clips play on it (garage.update_tv)
	_ln(ci, Vector2(tv.position.x + tv.size.x * 0.3, tv.position.y - 4), Vector2(tv.position.x + tv.size.x * 0.3, 0), Color(0.2, 0.2, 0.22), 3.0)
	_ln(ci, Vector2(tv.position.x + tv.size.x * 0.7, tv.position.y - 4), Vector2(tv.position.x + tv.size.x * 0.7, 0), Color(0.2, 0.2, 0.22), 3.0)
	_rc(ci, tv.grow(6), Color(0.1, 0.1, 0.11))
	ci.draw_rect(tv, Color(0.04, 0.07, 0.1))
	var lf := ThemeDB.fallback_font
	var lfs := int(clampf(tv.size.y / 9.0, 10, 22))
	ci.draw_string(lf, Vector2(tv.position.x, tv.get_center().y), "PORT FERRUM", HORIZONTAL_ALIGNMENT_CENTER, tv.size.x, lfs, Color(0.55, 1.0, 0.65, 0.7))
	ci.draw_string(lf, Vector2(tv.position.x, tv.get_center().y + lfs * 1.2), "FIGHT NET", HORIZONTAL_ALIGNMENT_CENTER, tv.size.x, lfs, Color(0.95, 0.76, 0.19, 0.7))
	var scl := tv.position.y
	while scl < tv.end.y:
		ci.draw_line(Vector2(tv.position.x, scl), Vector2(tv.end.x, scl), Color(0, 0, 0, 0.25), 1.0)
		scl += 3.0
	ci.draw_circle(Vector2(tv.end.x - 6, tv.end.y + 3), 1.5, Color(0.3, 1.0, 0.4))
	var tvi: Dictionary = info.get("tv", {})
	if tvi.get("live", false) or tvi.is_empty():
		pass
	if not tvi.is_empty():
		# the channel's banner along the bottom of the screen: which league, who's fighting
		var band := Rect2(tv.position.x - 6, tv.end.y + 6, tv.size.x + 12, 26 * s)
		_rc(ci, band, Color(0.05, 0.05, 0.08))
		_rc(ci, Rect2(band.position, Vector2(4, band.size.y)), Color(1.0, 0.8, 0.2))
		var f := ThemeDB.fallback_font
		var fs := int(10 * s)
		var ttl := str(tvi.get("title", ""))
		if tvi.get("live", false):
			ci.draw_circle(band.position + Vector2(12, 7 * s), 3.0 * s, Color(1, 0.3, 0.3) if fmod(t, 1.0) < 0.6 else Color(0.5, 0.2, 0.2))
			ci.draw_string(f, band.position + Vector2(8, 11 * s), "      " + ttl, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 12, fs, Color(1.0, 0.8, 0.2))
		else:
			ci.draw_string(f, band.position + Vector2(8, 11 * s), ttl, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 12, fs, Color(1.0, 0.8, 0.2))
		var who := str(tvi.get("a", "")) + ("  vs  " + str(tvi["b"]) if str(tvi.get("b", "")) != "" else "")
		ci.draw_string(f, band.position + Vector2(8, 22 * s), who, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 12, fs, Color(0.9, 0.9, 0.95))
	# neon sign, flickering now and then
	var on := fmod(t, 7.0) > 0.12 and not (fmod(t, 7.0) > 0.3 and fmod(t, 7.0) < 0.38)
	var neon := Color(1.0, 0.45, 0.2) if on else Color(0.35, 0.18, 0.12)
	var sign_r := Rect2(size.x * 0.04, tv.end.y + 46 * s, size.x * 0.44, 30 * s)   # under the TV, over the jukebox
	_rc(ci, sign_r.grow(6), Color(neon.r, neon.g, neon.b, 0.12 if on else 0.0))
	_rc(ci, sign_r, Color(0.08, 0.05, 0.05))
	_rc(ci, sign_r, neon, false, 2.0)
	ci.draw_string(ThemeDB.fallback_font, sign_r.position + Vector2(0, sign_r.size.y * 0.72), I18n.t("THE RUSTY BOLT"),
			HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x, int(14 * s), neon)
	# shelves of bottles behind the bar
	var cx := _pub_counter_x(size)
	var shelf0 := maxf(size.y * 0.36, tv.end.y + 66 * s)   # below the TV and its banner
	var shelves := clampi(int((floor_y - 70 * s - shelf0) / (size.y * 0.12)) + 1, 1, 2)
	for row in shelves:
		var y := shelf0 + size.y * row * 0.12
		_rc(ci, Rect2(cx, y, size.x - cx, 4), Color(0.35, 0.22, 0.12))
		var k := 0
		var x := cx + 8.0
		while x < size.x - 10:
			var hue := fmod(k * 0.37 + row * 0.2, 1.0)
			var h := (16 + (k * 7) % 9) * s
			_rc(ci, Rect2(x, y - h, 7 * s, h), Color.from_hsv(hue, 0.55, 0.55, 0.9))
			_rc(ci, Rect2(x + 2 * s, y - h - 5 * s, 3 * s, 5 * s), Color.from_hsv(hue, 0.4, 0.4))
			x += 13 * s
			k += 1
	_jukebox(ci, Vector2(size.x * 0.035, floor_y), s, t, bool(info.get("juke", false)))
	# the bartender behind the counter, polishing a glass
	var keep := {"skin": "#8d5a3b", "hair": "#2b2b2b", "hat": "none", "outfit": "#3b2a1e", "beard": "full", "beard_color": "#2b2b2b", "eyes": "#3a2a1e"}
	PilotArt.draw_person(ci, Vector2(size.x * 0.72, floor_y - 16 * s), s, keep, -1.0, "wipe", t)   # on the raised step behind the bar
	# the counter (covers the bartender's legs)
	var top := floor_y - 44 * s
	_rc(ci, Rect2(cx, top, size.x - cx, floor_y - top), Color(0.32, 0.19, 0.1))
	_rc(ci, Rect2(cx - 6, top - 6 * s, size.x - cx + 6, 7 * s), Color(0.5, 0.31, 0.16))
	for k in 4:
		var px := cx + 14 + k * (size.x - cx - 20) / 3.0
		_ln(ci, Vector2(px, top + 6), Vector2(px, floor_y - 4), Color(0.25, 0.15, 0.08), 2.0)
	_ln(ci, Vector2(cx, floor_y - 8 * s), Vector2(size.x, floor_y - 8 * s), Color(0.7, 0.6, 0.35), 3.0)   # foot rail


## The jukebox: knocked together from scrap - patchwork plates, pipe legs, a record spinning behind
## a scratched window, chasing bulbs round the arch, and a brass gramophone horn on top. When it's
## playing, the bulbs run, the record spins and notes drift out of the horn.
	# the rest of tonight's crowd, standing around with their drinks (further back, a bit smaller)
	var crowd: Array = info.get("patron", {}).get("crowd", [])
	var cgap := 58.0 if crowd.size() <= 4 else 48.0
	for k in crowd.size():
		var cs := s * 0.82
		var cx2 := _pub_counter_x(size) - (30 + cgap * k) * s
		var cy := floor_y - 16 * s
		if crowd[k].get("hungover", false):
			# last night's leftovers: flat out on the floor, an empty bottle rolled away, snoring
			var feet := Vector2(cx2 + 30 * s, cy - 9 * cs)
			_turned(ci, info, feet, -PI * 0.5)
			PilotArt.draw_person(ci, Vector2.ZERO, cs, crowd[k]["look"], 1.0, "stand", 0.0)
			_turned(ci, info, Vector2.ZERO, 0.0)
			_bottle_down(ci, Vector2(cx2 + 40 * s, cy - 3 * s), s)
			var head := feet + Vector2(-70 * cs, 0)
			_zzz(ci, head + Vector2(0, -10 * s), s, t + k)
			if not info.has("heads"):
				info["heads"] = {}
			info["heads"][str(crowd[k]["name"])] = head
		else:
			PilotArt.draw_person(ci, Vector2(cx2, cy), cs, crowd[k]["look"], 1.0 if k % 2 == 0 else -1.0, "hold", t + 1.3 * k)
			_head(info, str(crowd[k]["name"]), Vector2(cx2, cy), cs)

static func _jukebox(ci: CanvasItem, base: Vector2, s: float, t: float, playing: bool) -> void:
	var w := 50.0 * s
	var h := 80.0 * s
	var body := Rect2(base.x, base.y - h - 8 * s, w, h)
	# pipe legs
	for lx in [body.position.x + 6 * s, body.end.x - 9 * s]:
		_rc(ci, Rect2(lx, body.end.y, 3 * s, 8 * s), Color(0.45, 0.45, 0.48))
	# patchwork body: plates of different scrap riveted together
	var plates := [[Rect2(body.position, Vector2(w * 0.55, h * 0.5)), Color(0.42, 0.28, 0.18)],
			[Rect2(body.position + Vector2(w * 0.55, 0), Vector2(w * 0.45, h * 0.5)), Color(0.35, 0.38, 0.33)],
			[Rect2(body.position + Vector2(0, h * 0.5), Vector2(w * 0.4, h * 0.5)), Color(0.38, 0.33, 0.4)],
			[Rect2(body.position + Vector2(w * 0.4, h * 0.5), Vector2(w * 0.6, h * 0.5)), Color(0.48, 0.3, 0.16)]]
	for p in plates:
		_rc(ci, p[0], p[1])
		_rc(ci, p[0], (p[1] as Color).darkened(0.4), false, 1.5)
		var r: Rect2 = p[0]
		for c in [r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3), Vector2(r.position.x + 3, r.end.y - 3), r.end - Vector2(3, 3)]:
			_cr(ci, c, 1.3, Color(0.75, 0.7, 0.6))
	# rust streaks
	for k in 3:
		var rx := body.position.x + w * (0.2 + k * 0.28)
		_ln(ci, Vector2(rx, body.position.y + h * 0.3), Vector2(rx - 2, body.position.y + h * 0.55), Color(0.55, 0.25, 0.1, 0.6), 2.0)
	# the arch on top, with bulbs that chase round when it plays
	var arch_c := Vector2(body.get_center().x, body.position.y)
	_cr(ci, arch_c, w * 0.5, Color(0.3, 0.2, 0.14))
	_rc(ci, Rect2(body.position.x, arch_c.y, w, 2), Color(0.3, 0.2, 0.14))
	for k in 9:
		var a := PI + PI * (k + 0.5) / 9.0
		var lit := playing and (int(t * 8.0) + k) % 3 == 0
		var col := Color.from_hsv(fmod(k * 0.13, 1.0), 0.7, 1.0) if lit else Color.from_hsv(fmod(k * 0.13, 1.0), 0.4, 0.4)
		_cr(ci, arch_c + Vector2(cos(a), sin(a)) * w * 0.42, 2.6 * s * 0.6 + 1.0, col)
	# the window: a record on a turntable
	var win := Rect2(body.position + Vector2(w * 0.12, h * 0.08), Vector2(w * 0.76, h * 0.36))
	_rc(ci, win, Color(0.08, 0.06, 0.05))
	var rec := win.get_center() + Vector2(0, 2)
	var rr := win.size.y * 0.42
	_cr(ci, rec, rr, Color(0.06, 0.06, 0.06))
	for k in 3:
		_ac(ci, rec, rr * (0.45 + k * 0.17), 0, TAU, 18, Color(0.18, 0.18, 0.18), 1.0)
	_cr(ci, rec, rr * 0.3, Color(0.8, 0.25, 0.15))
	var spin := t * 5.0 if playing else 0.6
	_ln(ci, rec, rec + Vector2(cos(spin), sin(spin)) * rr * 0.28, Color(1, 0.9, 0.7), 1.5)
	_ln(ci, win.position + Vector2(win.size.x * 0.85, 3), rec + Vector2(rr * 0.6, -rr * 0.3), Color(0.75, 0.75, 0.8), 1.5)   # tone arm
	_rc(ci, win, Color(0.7, 0.85, 0.9, 0.12))
	_ln(ci, win.position + Vector2(4, win.size.y - 4), win.position + Vector2(win.size.x * 0.4, 4), Color(1, 1, 1, 0.15), 1.0)   # scratch
	# speaker grille and the coin slot
	var gr := Rect2(body.position + Vector2(w * 0.12, h * 0.56), Vector2(w * 0.5, h * 0.34))
	_rc(ci, gr, Color(0.15, 0.12, 0.1))
	for k in 5:
		_ln(ci, Vector2(gr.position.x + 2, gr.position.y + 4 + k * gr.size.y / 5.0), Vector2(gr.end.x - 2, gr.position.y + 4 + k * gr.size.y / 5.0), Color(0.5, 0.42, 0.3), 1.5)
	_rc(ci, Rect2(body.position + Vector2(w * 0.72, h * 0.62), Vector2(w * 0.12, h * 0.05)), Color(0.08, 0.08, 0.08))
	_cr(ci, body.position + Vector2(w * 0.78, h * 0.78), 3.0, Color(0.3, 1.0, 0.4) if playing else Color(0.5, 0.15, 0.1))
	# the gramophone horn: a brass flower on a crooked neck
	var neck0 := Vector2(body.end.x - w * 0.2, arch_c.y - w * 0.4)
	var neck1 := neck0 + Vector2(6 * s, -14 * s)
	_ln(ci, neck0, neck1, Color(0.6, 0.45, 0.2), 3.0 * s)
	var mouth := neck1 + Vector2(20 * s, -16 * s)
	var dirv := (mouth - neck1).normalized()
	var perp := dirv.orthogonal()
	var pulse := (1.0 + 0.06 * sin(t * 10.0)) if playing else 1.0
	_pg(ci, PackedVector2Array([neck1 + perp * 2 * s, mouth + perp * 15 * s * pulse, mouth - perp * 15 * s * pulse, neck1 - perp * 2 * s]), Color(0.8, 0.6, 0.22))
	_ln(ci, mouth + perp * 15 * s * pulse, mouth - perp * 15 * s * pulse, Color(0.95, 0.8, 0.4), 3.0)
	for k in 3:
		_ln(ci, neck1, mouth + perp * (-12 + k * 12) * s * pulse, Color(0.62, 0.45, 0.15), 1.0)
	# notes drifting out of the horn
	if playing:
		for k in 4:
			var ph := fmod(t * 0.6 + k * 0.25, 1.0)
			var np := mouth + dirv * 10 * s + Vector2(ph * 30 * s + sin(t * 3.0 + k) * 5, -ph * 46 * s)
			var nc := Color(1.0, 0.85, 0.45, 1.0 - ph)
			_cr(ci, np, 2.6 * s * 0.7 + 0.5, nc)
			_ln(ci, np + Vector2(2.2 * s * 0.7, 0), np + Vector2(2.2 * s * 0.7, -8 * s * 0.7), nc, 1.5)
			if k % 2 == 0:
				_ln(ci, np + Vector2(2.2 * s * 0.7, -8 * s * 0.7), np + Vector2(6 * s * 0.7, -6 * s * 0.7), nc, 1.5)


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
			_cr(ci, at + Vector2(k * 3, -k * 2.5 * s), 3.2 * s, Color(0.95, 0.78, 0.25, 1.0 - maxf(0.0, bet_age - 1.2) * 2.5))
	# stools: today's pilot at the bar nearest the bartender, then you, then Gus
	var patron: Dictionary = info.get("patron", {})
	var qx := cx - 24 * s
	var px := cx - (66 if not patron.is_empty() else 26) * s
	for x in [px - 4 * s, px - 48 * s]:
		PilotArt.draw_seat(ci, Vector2(x, floor_y), s, 1.0, "stool")   # (1.81) stools you can see
	PilotArt.draw_person(ci, Vector2(px - 4 * s, floor_y), s, pilot, 1.0, "push" if bet_age < 1.2 else "drink", t)
	_head(info, "YOU", Vector2(px - 4 * s, floor_y), s, true)
	# Gus on the next stool, nursing a coffee
	PilotArt.draw_person(ci, Vector2(px - 48 * s, floor_y), s, PilotArt.GUS_LOOK, 1.0, "drink", t + 2.2)
	_head(info, "GUS", Vector2(px - 48 * s, floor_y), s, true)
	# today's pilot at the bar: a real pilot from the rankings (your pickup fight, if you want it)
	if not patron.is_empty():
		PilotArt.draw_seat(ci, Vector2(qx, floor_y), s, 1.0, "stool")
		if patron.get("hungover", false):
			# slumped forward onto the bar, head on the counter, out cold since last night
			var hip := Vector2(qx, floor_y - 26 * s)
			_turned(ci, info, hip, 0.55)
			PilotArt.draw_person(ci, Vector2(0, 26 * s), s, patron["look"], 1.0, "drink", 0.0)
			_turned(ci, info, Vector2.ZERO, 0.0)
			var head := hip + Vector2(0, -52 * s).rotated(0.55)
			_zzz(ci, head + Vector2(4 * s, -12 * s), s, t)
			if not info.has("heads"):
				info["heads"] = {}
			info["heads"][str(patron["name"])] = head
		else:
			PilotArt.draw_person(ci, Vector2(qx, floor_y), s, patron["look"], 1.0, "drink", t + 4.1)
			_head(info, str(patron["name"]), Vector2(qx, floor_y), s, true)


## Draw the next thing turned by rot around at (stage coordinates); call with rot 0 and ZERO to go back.
static func _turned(ci: CanvasItem, info: Dictionary, at: Vector2, rot: float) -> void:
	var st: Vector2 = info.get("_stage", Vector2.ZERO)
	ci.draw_set_transform(st + at, rot, Vector2.ONE)


## Snoring: little z's drifting up from a sleeper's head.
static func _zzz(ci: CanvasItem, at: Vector2, s: float, t: float) -> void:
	var f := ThemeDB.fallback_font
	for k in 3:
		var ph := fmod(t * 0.45 + k / 3.0, 1.0)
		var pos := at + Vector2(ph * 16 * s + sin(t * 2.0 + k) * 2 * s, -ph * 34 * s)
		ci.draw_string(f, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int((9.0 + ph * 9.0) * s), Color(0.95, 0.95, 1.0, 0.9 * (1.0 - ph)))


## An empty bottle lying on the floor.
static func _bottle_down(ci: CanvasItem, at: Vector2, s: float) -> void:
	_rc(ci, Rect2(at + Vector2(-8 * s, -4 * s), Vector2(12 * s, 7 * s)), Color(0.2, 0.42, 0.22))
	_rc(ci, Rect2(at + Vector2(4 * s, -2.5 * s), Vector2(6 * s, 4 * s)), Color(0.2, 0.42, 0.22))
	_ln(ci, at + Vector2(-6 * s, -3 * s), at + Vector2(2 * s, -3 * s), Color(1, 1, 1, 0.3), 1.0)


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
		_rc(ci, Rect2(size.x * 0.645, y, size.x * 0.24, 5), Color(0.45, 0.32, 0.2))
		_rc(ci, Rect2(size.x * 0.655, y + 5, 4, 8), Color(0.3, 0.22, 0.14))
		_rc(ci, Rect2(size.x * 0.87, y + 5, 4, 8), Color(0.3, 0.22, 0.14))
	for sp in gear_spots(size, owned):
		var on: bool = str(sp[0]) == using
		if on:
			_cr(ci, sp[1], 20.0, Color(0.95, 0.76, 0.19, 0.18 + 0.08 * sin(t * 3.0)))
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
	_pg(ci, body, outfit)
	_rc(ci, Rect2(c.x - r * 0.3, c.y + r * 0.75, r * 0.6, r * 0.4), skin.darkened(0.12))   # neck
	if look.get("female", false):
		for side in [-1.0, 1.0]:
			_ac(ci, c + Vector2(side * r * 0.62, r * 1.85), r * 0.42, PI * 0.15, PI * 0.85, 12, outfit.darkened(0.45), maxf(1.5, r * 0.05))
	# the head, tipped down a touch toward the screen
	PilotArt.draw_head(ci, c, r, look, 0.0, 2.0)
	# eyes on the screen: lids half down, pupils low
	if str(look.get("glasses", "none")) in ["none", "round"]:
		for side in [-1.0, 1.0]:
			# (1.79) plain shapes (no outlines): the white again, the iris low, the lid half down over it
			var e := c + Vector2(side * r * 0.33, -r * 0.08)
			ci.draw_circle(e, r * 0.14, Color.WHITE)
			ci.draw_circle(e + Vector2(0, r * 0.07), r * 0.075, Color(look.get("eyes", "#5b3a1e")))
			ci.draw_rect(Rect2(e.x - r * 0.16, e.y - r * 0.17, r * 0.32, r * 0.16), skin)
			ci.draw_line(Vector2(e.x - r * 0.15, e.y - r * 0.01), Vector2(e.x + r * 0.15, e.y - r * 0.01), skin.darkened(0.5), maxf(1.5, r * 0.045))
	# glow from the screen on the face
	_cr(ci, c + Vector2(0, r * 0.45), r * 0.95, Color(0.45, 0.75, 1.0, 0.12 + 0.03 * sin(t * 3.0)))
	# arms come up from the elbows to the phone held in front of the chest
	var ph := Rect2(c.x - r * 0.62, c.y + r * 1.55, r * 1.24, r * 1.9)
	for side in [-1.0, 1.0]:
		var elbow := Vector2(c.x + side * r * 1.7, size.y + r * 0.2)
		var hand := Vector2(c.x + side * r * 0.62, ph.position.y + ph.size.y * 0.62)
		_ln(ci, elbow, hand, outfit.darkened(0.15), r * 0.42)
	# the back of the phone (the screen faces your pilot): plain black, a camera lens in the corner
	_rc(ci, ph.grow(r * 0.04), Color(0.03, 0.03, 0.04))
	_rc(ci, ph, Color(0.07, 0.07, 0.08))
	_cr(ci, ph.position + Vector2(r * 0.22, r * 0.22), r * 0.09, Color(0.02, 0.02, 0.03))
	_cr(ci, ph.position + Vector2(r * 0.22, r * 0.22), r * 0.05, Color(0.12, 0.14, 0.2))
	# thumbs on the screen edge
	for side in [-1.0, 1.0]:
		_cr(ci, Vector2(c.x + side * r * 0.6, ph.position.y + ph.size.y * 0.6), r * 0.17, skin)
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
	_rc(ci, r, wood)
	_rc(ci, r, wood.darkened(0.35), false, 2.0)
	for k in 3:
		var y := r.position.y + r.size.y * (k + 1) / 4.0
		_ln(ci, Vector2(r.position.x, y), Vector2(r.end.x, y), wood.darkened(0.2), 1.0)
	_ln(ci, r.position, r.end, wood.darkened(0.3), 2.0)
	_rc(ci, Rect2(r.get_center() + Vector2(-r.size.x * 0.18, -4), Vector2(r.size.x * 0.36, 8)), Color(0.15, 0.12, 0.1, 0.45))

static func _wall(ci: CanvasItem, size: Vector2, floor_y: float, c1: Color, c2: Color, floor_c: Color = Color(0.28, 0.27, 0.27)) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), c1)
	for k in int(size.x / 18.0) + 1:   # corrugated metal
		ci.draw_rect(Rect2(k * 18.0, 0, 9.0, floor_y), c2)
	ci.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), floor_c)


## (1.98) Brassworks & Sons: dark wood panels, glass cabinets of brass parts, gas lamps and copper
## pipes along the ceiling with a valve that lets off steam now and then.
static func _brass_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	# copper pipes under the ceiling, a valve that puffs
	_ln(ci, Vector2(0, 14), Vector2(size.x, 14), Color(0.72, 0.45, 0.24), 6.0)
	_ln(ci, Vector2(size.x * 0.66, 14), Vector2(size.x * 0.66, 60), Color(0.72, 0.45, 0.24), 5.0)
	_cr(ci, Vector2(size.x * 0.66, 34), 6, Color(0.75, 0.2, 0.15))
	var ph := fmod(t * 0.4, 1.0)
	if ph < 0.35:
		for k in 4:
			var u := ph / 0.35
			ci.draw_circle(Vector2(size.x * 0.66 + 8 + k * 7 * u, 60 + k * 4 - u * 20), 4.0 + u * 9.0, Color(0.95, 0.95, 0.97, 0.35 * (1.0 - u)))
	# two glass cabinets with brass parts on their shelves
	for cb in 2:
		var r := Rect2(size.x * (0.06 + cb * 0.27), 48, size.x * 0.22, floor_y - 120)
		_rc(ci, r, Color(0.3, 0.19, 0.1))
		var glass := r.grow(-5)
		ci.draw_rect(glass, Color(0.55, 0.7, 0.75, 0.12))
		for sh in 3:
			var sy := glass.position.y + (sh + 1) * glass.size.y / 3.0 - 4
			_rc(ci, Rect2(glass.position.x, sy, glass.size.x, 3), Color(0.3, 0.19, 0.1))
			for it in 3:
				var ip := Vector2(glass.position.x + 10 + it * glass.size.x / 3.0, sy - 8)
				match (sh + it + cb) % 3:
					0:
						_cr(ci, ip, 6, Color(0.8, 0.64, 0.2))
						ci.draw_circle(ip, 4.0, Color(0.95, 0.92, 0.82))
					1:
						for k in 6:
							var a := t * 0.6 * (1 if it % 2 == 0 else -1) + k * TAU / 6.0
							ci.draw_line(ip, ip + Vector2(cos(a), sin(a)) * 7.0, Color(0.8, 0.64, 0.2), 2.0)
						ci.draw_circle(ip, 3.0, Color(0.6, 0.45, 0.15))
					_:
						_rc(ci, Rect2(ip.x - 4, ip.y - 8, 8, 14), Color(0.72, 0.45, 0.24))
		ci.draw_line(glass.position + Vector2(6, 6), glass.position + Vector2(20, 40), Color(1, 1, 1, 0.15), 2.0)
	# gas lamps on the wall, real light
	for lx in [size.x * 0.04, size.x * 0.6]:
		var lp := Vector2(lx + 10, 74)
		_ln(ci, lp + Vector2(-8, 0), lp, Color(0.78, 0.6, 0.22), 3.0)
		var fl := 0.85 + 0.15 * sin(t * 7.0 + lx)
		ci.draw_circle(lp + Vector2(0, -4), 22, Color(1.0, 0.8, 0.45, 0.07 * fl))
		ci.draw_circle(lp + Vector2(0, -4), 5, Color(1.0, 0.88, 0.6, 0.9 * fl))
		_rc(ci, Rect2(lp.x - 6, lp.y - 12, 12, 14), Color(0.78, 0.6, 0.22), false, 1.5)
	_maker_plaque(ci, Rect2(size.x * 0.66, 70, size.x * 0.3, 36), "brassworks", I18n.t("BRASSWORKS & SONS"), I18n.t("EST. 1898 · BUILT BY HAND"))


## (1.103) Tenryu's dojo: wooden walls, shoji screens with one slid open on a blossom tree and Midtown at night,
## red paper lanterns, the banner with the rising sun and the logo, a model kit box on the shelf, petals drifting in.
## (1.109) The Menagerie's circus ship: the big top on deck in red and cream stripes, a mast with
## pennants, bulb strings that chase, a cage wagon with a mechanical beast pacing inside, the gold rail.
static func _circus_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	var red := Color(0.72, 0.13, 0.12)
	var cream := Color(0.93, 0.86, 0.72)
	var gold := Color(0.95, 0.75, 0.25)
	# the mast and its pennants
	var mx := size.x * 0.9
	_ln(ci, Vector2(mx, floor_y), Vector2(mx, 8), Color(0.32, 0.2, 0.12), 6.0)
	_ln(ci, Vector2(mx - 40, 40), Vector2(mx + 30, 40), Color(0.32, 0.2, 0.12), 4.0)
	for k in 7:
		var u := float(k) / 6.0
		var a := Vector2(mx, 12).lerp(Vector2(size.x * 0.08, 60), u)
		var b := Vector2(mx, 12).lerp(Vector2(size.x * 0.08, 60), u + 1.0 / 7.0)
		var mid := a.lerp(b, 0.5) + Vector2(0, 8 + sin(t * 2.0 + k) * 2.0)
		ci.draw_colored_polygon(PackedVector2Array([a, b, mid]), red if k % 2 == 0 else gold)
	ci.draw_line(Vector2(mx, 12), Vector2(size.x * 0.08, 60), Color(0.25, 0.18, 0.12), 1.5)
	# the big top: a striped tent with a scalloped gold hem and a flag on its peak
	var tl := Vector2(size.x * 0.06, floor_y - 30)
	var tw := size.x * 0.46
	var peak := Vector2(tl.x + tw * 0.5, floor_y - 200)
	var hem_y := floor_y - 120
	var stripes := 8
	for k in stripes:
		var x0 := tl.x + tw * float(k) / stripes
		var x1 := tl.x + tw * float(k + 1) / stripes
		_pg(ci, PackedVector2Array([peak, Vector2(x0, hem_y), Vector2(x1, hem_y)]), red if k % 2 == 0 else cream)
	for k in stripes:
		var x0 := tl.x + tw * float(k) / stripes
		var x1 := tl.x + tw * float(k + 1) / stripes
		_rc(ci, Rect2(x0, hem_y, x1 - x0, tl.y - hem_y), cream.darkened(0.08) if k % 2 == 0 else red.darkened(0.1))
		ci.draw_arc(Vector2((x0 + x1) * 0.5, hem_y), (x1 - x0) * 0.5, 0.0, PI, 8, gold, 3.0)   # the scalloped hem
	# the door flaps tied back, the ring glowing inside
	var dr := Rect2(tl.x + tw * 0.38, hem_y + 6, tw * 0.24, tl.y - hem_y - 6)
	ci.draw_rect(dr, Color(0.25, 0.1, 0.06))
	ci.draw_circle(Vector2(dr.get_center().x, dr.end.y), dr.size.x * 0.4, Color(1.0, 0.7, 0.3, 0.3))
	_ln(ci, Vector2(peak.x, peak.y), Vector2(peak.x, peak.y - 26), Color(0.3, 0.2, 0.12), 2.0)
	var fl := sin(t * 3.0) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(peak.x, peak.y - 26), Vector2(peak.x + 18, peak.y - 21 + fl), Vector2(peak.x, peak.y - 16)]), gold)
	# the bulb string across the top, chasing
	for k in 22:
		var u2 := float(k) / 21.0
		var bp := Vector2(lerpf(4.0, size.x - 4.0, u2), 22.0 + sin(u2 * PI) * 22.0)
		var on := int(t * 6.0 + k) % 3 == 0
		ci.draw_circle(bp, 3.0, Color(1.0, 0.85, 0.45) if on else Color(0.45, 0.35, 0.2))
		if on:
			ci.draw_circle(bp, 7.0, Color(1.0, 0.8, 0.4, 0.18))
	# the plaque on the tent
	_maker_plaque(ci, Rect2(tl.x + 6, floor_y - 116, tw - 12, 30), "menagerie", I18n.t("THE MENAGERIE"), I18n.t("MECHANICAL MARVELS · SEE THEM ALL"))
	# a cage wagon with a mechanical beast pacing behind the bars
	var cg := Rect2(size.x * 0.56, floor_y - 74, size.x * 0.22, 60)
	_rc(ci, cg, red.darkened(0.25))
	ci.draw_rect(cg.grow(-6), Color(0.08, 0.06, 0.08))
	var bx := cg.position.x + 14 + (0.5 + 0.5 * sin(t * 0.6)) * (cg.size.x - 52)
	_cr(ci, Vector2(bx + 12, cg.position.y + 30), 12, Color(0.42, 0.35, 0.3))   # its head
	_rc(ci, Rect2(bx, cg.position.y + 34, 28, 14), Color(0.38, 0.3, 0.26))
	ci.draw_circle(Vector2(bx + 17, cg.position.y + 27), 2.2, Color(1.0, 0.3, 0.2) if fmod(t, 3.0) > 0.2 else Color(0.2, 0.05, 0.05))
	for k in 9:
		var gx := cg.position.x + 6 + k * (cg.size.x - 12) / 8.0
		ci.draw_line(Vector2(gx, cg.position.y + 6), Vector2(gx, cg.end.y - 6), gold, 2.0)
	_rc(ci, Rect2(cg.position.x - 4, cg.position.y - 6, cg.size.x + 8, 8), gold)
	for wx in [cg.position.x + 14, cg.end.x - 14]:
		_cr(ci, Vector2(wx, cg.end.y + 4), 10, Color(0.85, 0.65, 0.2))
		ci.draw_circle(Vector2(wx, cg.end.y + 4), 3.0, Color(0.3, 0.2, 0.1))
	# the ship's gold rail along the deck's edge
	_rc(ci, Rect2(0, floor_y - 26, size.x, 4), gold)
	for k in int(size.x / 26.0) + 1:
		ci.draw_line(Vector2(k * 26.0, floor_y - 22), Vector2(k * 26.0, floor_y), gold.darkened(0.25), 2.0)


static func _tenryu_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	var wood := Color(0.42, 0.28, 0.16)
	# the beams
	_rc(ci, Rect2(0, 54, size.x, 10), wood.darkened(0.25))
	for k in 5:
		_rc(ci, Rect2(size.x * (0.02 + k * 0.24), 54, 10, floor_y - 54), wood.darkened(0.2))
	# shoji screens, the middle one slid open: a blossom tree and the city at night
	var sh := Rect2(size.x * 0.04, 70, size.x * 0.44, floor_y - 74)
	var open := Rect2(sh.position.x + sh.size.x * 0.34, sh.position.y, sh.size.x * 0.33, sh.size.y)
	ci.draw_rect(open, Color(0.09, 0.07, 0.16))
	for k in 5:
		var bx := open.position.x + k * open.size.x / 5.0
		var bh := open.size.y * (0.3 + 0.35 * fmod(k * 0.47, 1.0))
		ci.draw_rect(Rect2(bx, open.end.y - bh, open.size.x / 5.0 - 3, bh), Color(0.14, 0.11, 0.22))
		if k % 2 == 0:
			ci.draw_rect(Rect2(bx + 3, open.end.y - bh + 6, 3, 3), Color(1.0, 0.7, 0.85, 0.7))
	var tr0 := Vector2(open.position.x + open.size.x * 0.35, open.end.y)
	ci.draw_line(tr0, tr0 + Vector2(6, -70), Color(0.25, 0.15, 0.12), 5.0)
	ci.draw_line(tr0 + Vector2(4, -50), tr0 + Vector2(30, -80), Color(0.25, 0.15, 0.12), 3.0)
	for k in 9:
		ci.draw_circle(tr0 + Vector2(-14 + (k * 37) % 50, -96 + (k * 23) % 40), 12.0, Color(1.0, 0.7, 0.82, 0.85))
	for side in 2:
		var pr := Rect2(sh.position.x if side == 0 else open.end.x, sh.position.y, open.position.x - sh.position.x if side == 0 else sh.end.x - open.end.x, sh.size.y)
		ci.draw_rect(pr, Color(0.93, 0.89, 0.8))
		for gx in 4:
			ci.draw_line(Vector2(pr.position.x + (gx + 1) * pr.size.x / 4.0, pr.position.y), Vector2(pr.position.x + (gx + 1) * pr.size.x / 4.0, pr.end.y), wood, 2.0)
		for gy in 6:
			ci.draw_line(Vector2(pr.position.x, pr.position.y + (gy + 1) * pr.size.y / 6.0), Vector2(pr.end.x, pr.position.y + (gy + 1) * pr.size.y / 6.0), wood, 2.0)
		ci.draw_rect(pr, wood.darkened(0.2), false, 4.0)
	# petals drifting in through the open screen
	for k in 6:
		var ph := fmod(t * 0.15 + k * 0.17, 1.0)
		var pp := Vector2(open.get_center().x + ph * size.x * 0.4 + sin(t * 2.0 + k) * 12.0, open.position.y + 30 + ph * (floor_y - open.position.y - 30))
		ci.draw_circle(pp, 2.5, Color(1.0, 0.72, 0.84, 0.9 * (1.0 - ph)))
	# the banner: a red sun and the logo
	var bn := Rect2(size.x * 0.54, 74, size.x * 0.17, 120)
	_rc(ci, bn, Color(0.95, 0.93, 0.88))
	ci.draw_circle(bn.get_center() + Vector2(0, -12), bn.size.x * 0.3, Color(0.8, 0.15, 0.18))
	load("res://logos.gd").draw_logo(ci, load("res://makers.gd").logo("tenryu"), bn.get_center() + Vector2(0, 38), 12.0)
	ci.draw_line(Vector2(bn.position.x - 6, bn.position.y), Vector2(bn.end.x + 6, bn.position.y), wood.darkened(0.3), 4.0)
	# paper lanterns, glowing
	for lx in [size.x * 0.5, size.x * 0.76]:
		var lp := Vector2(lx, 100.0 + sin(t * 1.3 + lx) * 2.0)
		ci.draw_line(Vector2(lx, 64), lp + Vector2(0, -16), Color(0.15, 0.1, 0.08), 1.5)
		ci.draw_circle(lp, 30.0, Color(1.0, 0.5, 0.35, 0.08))
		_cr(ci, lp, 14, Color(0.85, 0.2, 0.18))
		for j in 3:
			ci.draw_line(lp + Vector2(-13, -8 + j * 8), lp + Vector2(13, -8 + j * 8), Color(0.6, 0.12, 0.1), 1.0)
		ci.draw_circle(lp, 8.0, Color(1.0, 0.75, 0.4, 0.5))
	# a model kit box: box art of a hero robot
	var bx2 := Rect2(size.x * 0.07, floor_y - 40, 60, 40)   # on the floor by the screens
	_rc(ci, bx2, Color(0.95, 0.95, 0.97))
	ci.draw_rect(Rect2(bx2.position.x, bx2.position.y, bx2.size.x, 9), Color(0.8, 0.15, 0.18))
	ci.draw_colored_polygon(PackedVector2Array([bx2.position + Vector2(30, 13), bx2.position + Vector2(40, 22), bx2.position + Vector2(36, 38), bx2.position + Vector2(24, 38), bx2.position + Vector2(20, 22)]), Color(0.17, 0.31, 0.66))
	ci.draw_colored_polygon(PackedVector2Array([bx2.position + Vector2(30, 18), bx2.position + Vector2(22, 10), bx2.position + Vector2(38, 10)]), Color(1.0, 0.82, 0.15))
	# floor planks
	for k in 6:
		ci.draw_line(Vector2(0, floor_y + 4 + k * 4), Vector2(size.x, floor_y + 4 + k * 4), Color(0.3, 0.2, 0.12, 0.5), 1.0)


## (1.102) Kane Dynamics' showroom: black glass walls, gold seams, a part in a lit glass case, the logo on a screen,
## a spotlight on the plinth where your robot stands, Kane Heights through the window at night.
static func _kane_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	var gold := Color(0.88, 0.72, 0.29)
	# glass panels with gold seams, a light running along them now and then
	for k in 8:
		var gx := size.x * (0.02 + k * 0.125)
		ci.draw_line(Vector2(gx, 0), Vector2(gx, floor_y), Color(gold, 0.35), 1.5)
		var run := fmod(t * 0.35 + k * 0.13, 1.0)
		ci.draw_line(Vector2(gx, floor_y * run), Vector2(gx, floor_y * run + 24), Color(1.0, 0.85, 0.45, 0.6), 2.0)
	ci.draw_line(Vector2(0, floor_y * 0.3), Vector2(size.x, floor_y * 0.3), Color(gold, 0.25), 1.0)
	# the window on Kane Heights at night: towers and their lit windows
	var win := Rect2(size.x * 0.05, 70, size.x * 0.34, floor_y - 170)
	ci.draw_rect(win, Color(0.04, 0.05, 0.1))
	for k in 7:
		var bx := win.position.x + 4 + k * win.size.x / 7.0
		var bh := win.size.y * (0.45 + 0.5 * fmod(k * 0.53, 1.0))
		ci.draw_rect(Rect2(bx, win.end.y - bh, win.size.x / 7.0 - 5, bh), Color(0.08, 0.09, 0.14))
		for j in 5:
			if fmod(k * 3.0 + j * 7.0, 4.0) < 1.6:
				ci.draw_rect(Rect2(bx + 3, win.end.y - bh + 5 + j * 9, 3, 3), Color(1.0, 0.85, 0.5, 0.6))
	ci.draw_rect(win, gold, false, 2.0)
	# the logo on its screen, KANE DYNAMICS under it
	var sc := Rect2(size.x * 0.44, 74, size.x * 0.24, 64)
	ci.draw_rect(sc, Color(0.02, 0.02, 0.03))
	ci.draw_rect(sc, Color(gold, 0.6), false, 1.5)
	load("res://logos.gd").draw_logo(ci, "kane", sc.get_center() + Vector2(0, -6), 18.0)
	var f := ThemeDB.fallback_font
	ci.draw_string(f, Vector2(sc.position.x, sc.end.y - 6), I18n.t("KANE DYNAMICS"), HORIZONTAL_ALIGNMENT_CENTER, sc.size.x, 11, gold)
	# a glass case on a plinth with an arm in it, lit from below
	var cs := Rect2(size.x * 0.42, floor_y - 120, 46, 120)
	_rc(ci, Rect2(cs.position.x - 4, cs.end.y - 40, cs.size.x + 8, 40), Color(0.1, 0.1, 0.12))
	ci.draw_line(Vector2(cs.position.x - 4, cs.end.y - 40), Vector2(cs.end.x + 4, cs.end.y - 40), gold, 2.0)
	ci.draw_rect(Rect2(cs.position, Vector2(cs.size.x, cs.size.y - 40)), Color(0.6, 0.75, 0.9, 0.08))
	ci.draw_rect(Rect2(cs.position, Vector2(cs.size.x, cs.size.y - 40)), Color(0.75, 0.85, 1.0, 0.3), false, 1.0)
	var ac := Vector2(cs.get_center().x, cs.position.y + 40)
	ci.draw_line(ac + Vector2(0, -24), ac + Vector2(0, 20), Color(0.1, 0.1, 0.14), 6.0)
	ci.draw_colored_polygon(PackedVector2Array([ac + Vector2(-6, 20), ac + Vector2(6, 20), ac + Vector2(0, 36)]), gold)
	ci.draw_colored_polygon(PackedVector2Array([cs.position + Vector2(4, cs.size.y - 40), cs.position + Vector2(cs.size.x - 4, cs.size.y - 40), cs.position + Vector2(cs.size.x * 0.5, 10)]), Color(1.0, 0.9, 0.6, 0.06))
	# the spotlight on the plinth where your robot stands
	var px := size.x * float(ROBOT_SPOT["kane"][0])
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 14, 0), Vector2(px + 14, 0), Vector2(px + 80, floor_y), Vector2(px - 80, floor_y)]), Color(1.0, 0.97, 0.88, 0.07))
	var pl := PackedVector2Array()
	for k in 24:
		pl.append(Vector2(px + cos(k * TAU / 24.0) * 70.0, floor_y + 4 + sin(k * TAU / 24.0) * 12.0))
	ci.draw_colored_polygon(pl, Color(0.12, 0.12, 0.15))
	ci.draw_polyline(pl + PackedVector2Array([pl[0]]), gold, 2.0)


## (1.101) Nimbus Aerial's hangar: the door open on the airfield, a fan on its test stand, landing lights on the floor.
static func _nimbus_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	# the arch's ribs across the roof
	for k in 5:
		var rx := size.x * (0.1 + k * 0.22)
		ci.draw_line(Vector2(rx, 0), Vector2(rx, floor_y - 8), Color(0.48, 0.52, 0.58), 4.0)
	# the hangar door, open on the airfield: sky, clouds, the runway, a windsock
	var dr := Rect2(size.x * 0.03, 70, size.x * 0.46, floor_y - 70)
	for k in 8:
		ci.draw_rect(Rect2(dr.position.x, dr.position.y + k * dr.size.y * 0.09, dr.size.x, dr.size.y * 0.09 + 1), Color(0.45, 0.68, 0.95).lerp(Color(0.85, 0.92, 0.98), k / 7.0))
	for k in 3:
		var cx := dr.position.x + fmod(k * 113.0 + t * 6.0, dr.size.x + 60.0) - 30.0
		var cy := dr.position.y + 22.0 + k * 22.0
		for j in 3:
			var cp := Vector2(cx + j * 12.0, cy - (6.0 if j == 1 else 0.0))
			if cp.x > dr.position.x + 8 and cp.x < dr.end.x - 8:
				ci.draw_circle(cp, 9.0, Color(1, 1, 1, 0.85))
	var gy := dr.position.y + dr.size.y * 0.72
	ci.draw_rect(Rect2(dr.position.x, gy, dr.size.x, dr.end.y - gy), Color(0.45, 0.6, 0.38))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(dr.get_center().x - 14, gy), Vector2(dr.get_center().x + 14, gy), Vector2(dr.end.x, dr.end.y), Vector2(dr.position.x, dr.end.y)]), Color(0.32, 0.33, 0.36))
	for k in 4:
		var f0 := k / 4.0
		var f1 := f0 + 0.12
		var y0 := lerpf(gy, dr.end.y, f0)
		var y1 := lerpf(gy, dr.end.y, f1)
		ci.draw_line(Vector2(dr.get_center().x, y0), Vector2(dr.get_center().x, y1), Color(0.95, 0.95, 0.95), 1.0 + f0 * 4.0)
	var ws := Vector2(dr.end.x - 40, gy)
	ci.draw_line(ws, ws + Vector2(0, -40), Color(0.85, 0.85, 0.88), 2.0)
	var flap := sin(t * 3.0) * 4.0
	ci.draw_colored_polygon(PackedVector2Array([ws + Vector2(0, -40), ws + Vector2(22, -36 + flap), ws + Vector2(22, -30 + flap), ws + Vector2(0, -32)]), Color(1.0, 0.5, 0.15))
	ci.draw_line(ws + Vector2(8, -39 + flap * 0.4), ws + Vector2(8, -31 + flap * 0.4), Color(1, 1, 1), 2.0)
	# the sliding door leaves, pushed open to each side
	for side in 2:
		var lx := dr.position.x - 10.0 if side == 0 else dr.end.x - 6.0
		_rc(ci, Rect2(lx, 66, 16, floor_y - 66), Color(0.82, 0.85, 0.88))
		ci.draw_line(Vector2(lx + 2, floor_y * 0.55), Vector2(lx + 14, floor_y * 0.55), Color(0.2, 0.45, 0.9), 3.0)
	# the sign over it all
	_maker_plaque(ci, Rect2(size.x * 0.06, 24, size.x * 0.4, 36), "nimbus", I18n.t("NIMBUS AERIAL"), I18n.t("HANGAR 3 · TEST AND FIT"))
	# a ducted fan on its test stand, spinning, streamers blowing off it
	var fc := Vector2(size.x * 0.18, floor_y - 74)
	_ln(ci, Vector2(fc.x - 10, floor_y), Vector2(fc.x, fc.y), Color(0.35, 0.38, 0.42), 4.0)
	_ln(ci, Vector2(fc.x + 10, floor_y), Vector2(fc.x, fc.y), Color(0.35, 0.38, 0.42), 4.0)
	_cr(ci, fc, 24, Color(0.85, 0.88, 0.92))
	ci.draw_circle(fc, 18.0, Color(0.16, 0.18, 0.22))
	for k in 5:
		var a := t * 14.0 + k * TAU / 5.0
		ci.draw_line(fc, fc + Vector2(cos(a), sin(a)) * 16.0, Color(0.7, 0.74, 0.8), 3.0)
	ci.draw_circle(fc, 4.0, Color(0.9, 0.92, 0.95))
	for k in 3:
		var st := fc + Vector2(24, -10 + k * 10)
		ci.draw_line(st, st + Vector2(18, sin(t * 12.0 + k) * 3.0), Color(1.0, 0.3, 0.25), 2.0)
	# the taxi line and landing lights on the floor
	ci.draw_line(Vector2(size.x * 0.02, floor_y + 6), Vector2(size.x, floor_y + 6), Color(0.95, 0.8, 0.15, 0.8), 3.0)
	for k in 8:
		var lp := Vector2(size.x * (0.06 + k * 0.12), floor_y + 12)
		var on := int(t * 4.0) % 8 == k
		ci.draw_circle(lp, 3.0, Color(0.4, 0.7, 1.0) if on else Color(0.2, 0.35, 0.6))
		if on:
			ci.draw_circle(lp, 8.0, Color(0.4, 0.7, 1.0, 0.25))


## (1.100) Volta Motor's showroom: a big window on Midtown at night, a neon sign, a grid floor, a palm, the turntable.
static func _volta_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	# the window: a sunset over the Midtown towers, striped sun and all
	var win := Rect2(size.x * 0.04, 26, size.x * 0.5, floor_y - 92)
	for k in 8:
		ci.draw_rect(Rect2(win.position.x, win.position.y + k * win.size.y / 8.0, win.size.x, win.size.y / 8.0 + 1), Color(0.28, 0.08, 0.36).lerp(Color(1.0, 0.45, 0.4), k / 7.0))
	var sun := Vector2(win.get_center().x, win.end.y - win.size.y * 0.5)
	for k in 6:
		var yy := sun.y - 34 + k * 7.0
		var hw := sqrt(maxf(0.0, 36.0 * 36.0 - (yy - sun.y) * (yy - sun.y)))
		ci.draw_rect(Rect2(sun.x - hw, yy, hw * 2.0, 4.0), Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.55), k / 5.0))
	for k in 9:
		var bx := win.position.x + k * win.size.x / 9.0
		var bh := win.size.y * (0.25 + 0.45 * fmod(k * 0.41, 1.0))
		ci.draw_rect(Rect2(bx, win.end.y - bh, win.size.x / 9.0 - 3, bh), Color(0.1, 0.05, 0.16))
		for j in 3:
			if fmod(k * 5.0 + j * 3.0 + floor(t * 0.4), 4.0) < 1.5:
				ci.draw_rect(Rect2(bx + 4, win.end.y - bh + 6 + j * 10, 3, 3), Color(1.0, 0.5, 0.85, 0.8))
	_rc(ci, win, Color(0.75, 0.78, 0.85), false, 4.0)
	ci.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.75, 0.78, 0.85), 3.0)
	# the neon sign: VOLTA in pink tube, MOTOR in cyan, a lightning bolt, flickering now and then
	var on := 0.25 if fmod(t * 0.7, 6.0) < 0.12 else 1.0
	var f := ThemeDB.fallback_font
	var sp := Vector2(size.x * 0.6, 58)
	ci.draw_string(f, sp + Vector2(0, 2), I18n.t("VOLTA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.25, 0.65, 0.3 * on))
	ci.draw_string(f, sp, I18n.t("VOLTA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.55, 0.85, on))
	ci.draw_string(f, sp + Vector2(4, 22), I18n.t("MOTOR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.95, 1.0, 0.95))
	var bolt := sp + Vector2(f.get_string_size(I18n.t("VOLTA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 10, -22)
	ci.draw_polyline(PackedVector2Array([bolt, bolt + Vector2(-8, 14), bolt + Vector2(0, 14), bolt + Vector2(-8, 30)]), Color(1.0, 0.95, 0.4, on), 3.0)
	# a palm in a chrome pot by the window
	var pp := Vector2(size.x * 0.48, floor_y)
	_rc(ci, Rect2(pp.x - 10, pp.y - 22, 20, 22), Color(0.75, 0.78, 0.85))
	_ln(ci, pp + Vector2(0, -22), pp + Vector2(4, -70), Color(0.45, 0.3, 0.18), 4.0)
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.55 + sin(t * 0.8 + k) * 0.05
		var tip := pp + Vector2(4, -70) + Vector2(cos(a), sin(a) + 0.7) * 26.0
		_ln(ci, pp + Vector2(4, -70), tip, Color(0.15, 0.55, 0.4), 4.0)
	# the turntable the robot stands on, lights chasing round its rim
	var tc := Vector2(size.x * float(ROBOT_SPOT["volta"][0]), floor_y + 2)
	var ell := func(r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 32:
			pts.append(tc + Vector2(cos(k * TAU / 32.0) * r, sin(k * TAU / 32.0) * r * 0.22))
		return pts
	ci.draw_colored_polygon(ell.call(74.0), Color(0.06, 0.05, 0.08))
	ci.draw_colored_polygon(ell.call(70.0), Color(0.72, 0.75, 0.82))
	ci.draw_colored_polygon(ell.call(62.0), Color(0.5, 0.52, 0.6))
	for k in 16:
		var a2 := k * TAU / 16.0 + t * 0.8
		var lit := int(t * 8.0 + k) % 4 == 0
		ci.draw_circle(tc + Vector2(cos(a2) * 66.0, sin(a2) * 66.0 * 0.22), 3.0, Color(0.4, 0.95, 1.0) if lit else Color(1.0, 0.4, 0.75, 0.6))


## (1.99) Hellfire Heavy's breaker's yard: a container office, crushed bales, a drum fire, a wrecking ball on a crane.
static func _hell_back(ci: CanvasItem, size: Vector2, floor_y: float, t: float) -> void:
	# the jib of a yard crane across the top, a wrecking ball swinging slowly on its chain
	_rc(ci, Rect2(size.x * 0.5, 18, size.x * 0.36, 12), Color(0.85, 0.6, 0.12))
	for k in 6:
		var jx := size.x * 0.5 + k * size.x * 0.06
		ci.draw_line(Vector2(jx, 18), Vector2(jx + size.x * 0.03, 30), Color(0.4, 0.28, 0.06), 2.0)
	var pivot := Vector2(size.x * 0.78, 30)
	var ang := sin(t * 0.7) * 0.12
	var ball := pivot + Vector2(sin(ang), cos(ang)) * 70.0
	for k in 9:
		var cp := pivot.lerp(ball, k / 9.0)
		ci.draw_arc(cp, 3.0, 0, TAU, 8, Color(0.25, 0.25, 0.27), 2.0)
	_cr(ci, ball + Vector2(0, 14), 18, Color(0.2, 0.2, 0.22))
	# the office: a shipping container with a door, a lit window and a hazard band
	var ct := Rect2(size.x * 0.02, floor_y - 132, size.x * 0.4, 132)
	_rc(ci, ct, Color(0.62, 0.22, 0.14))
	for k in int(ct.size.x / 9.0):
		ci.draw_line(Vector2(ct.position.x + 4 + k * 9.0, ct.position.y + 14), Vector2(ct.position.x + 4 + k * 9.0, ct.end.y - 2), Color(0.45, 0.15, 0.1), 2.0)
	var band := Rect2(ct.position.x, ct.position.y, ct.size.x, 12)
	ci.draw_rect(band, Color(0.95, 0.75, 0.1))
	for k in int(band.size.x / 14.0) + 1:
		var bx := band.position.x + k * 14.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, band.end.y), Vector2(bx + 7, band.end.y), Vector2(minf(bx + 14, band.end.x), band.position.y), Vector2(minf(bx + 7, band.end.x), band.position.y)]), Color(0.08, 0.08, 0.08))
	var win := Rect2(ct.position.x + ct.size.x * 0.58, ct.position.y + 34, ct.size.x * 0.3, 34)
	ci.draw_rect(win, Color(1.0, 0.78, 0.4, 0.85))
	ci.draw_rect(win, Color(0.15, 0.1, 0.08), false, 3.0)
	ci.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.15, 0.1, 0.08), 2.0)
	_rc(ci, Rect2(ct.position.x + ct.size.x * 0.12, ct.position.y + 30, ct.size.x * 0.22, ct.size.y - 30), Color(0.5, 0.17, 0.1))
	_maker_plaque(ci, Rect2(ct.position.x + 6, ct.position.y - 40, ct.size.x - 12, 34), "hellfire", I18n.t("HELLFIRE HEAVY"), I18n.t("DEMOLITION & SALVAGE"))
	# crushed robots stacked in bales, a heap behind them
	_scrap_pile(ci, Vector2(size.x * 0.66, floor_y), size.x * 0.14, 70.0, t)
	_crushed(ci, Rect2(size.x * 0.53, floor_y - 40, 52, 40), 1)
	_crushed(ci, Rect2(size.x * 0.53 + 54, floor_y - 40, 52, 40), 2)
	_crushed(ci, Rect2(size.x * 0.53 + 26, floor_y - 80, 52, 40), 4)
	# the oil drum fire: it flickers and lights the ground
	var dr := Rect2(size.x * 0.47 - 14, floor_y - 40, 28, 40)
	var fl := 0.8 + 0.2 * sin(t * 11.0) + 0.1 * sin(t * 23.0)
	ci.draw_circle(Vector2(dr.get_center().x, dr.position.y), 70.0 * fl, Color(1.0, 0.5, 0.15, 0.08))
	_rc(ci, dr, Color(0.25, 0.25, 0.28))
	for k in 2:
		ci.draw_line(Vector2(dr.position.x, dr.position.y + 12 + k * 14), Vector2(dr.end.x, dr.position.y + 12 + k * 14), Color(0.16, 0.16, 0.18), 2.0)
	for k in 5:
		var fx := dr.position.x + 4 + k * 5.0
		var fh := (14.0 + 10.0 * sin(t * 9.0 + k * 1.7)) * fl
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, dr.position.y), Vector2(fx + 1, dr.position.y - fh), Vector2(fx + 5, dr.position.y)]), Color(1.0, 0.45 + 0.1 * k, 0.1, 0.9))
	for k in 3:
		var ph := fmod(t * 0.6 + k * 0.33, 1.0)
		ci.draw_circle(Vector2(dr.get_center().x + sin(ph * 6.0 + k) * 6.0, dr.position.y - 20 - ph * 50.0), 3.0 + ph * 7.0, Color(0.15, 0.13, 0.14, 0.4 * (1.0 - ph)))


## A robot crushed into a bale: a dented block with bits of it sticking out.
static func _crushed(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var cols := [Color(0.42, 0.4, 0.38), Color(0.55, 0.32, 0.2), Color(0.35, 0.4, 0.45), Color(0.5, 0.45, 0.2), Color(0.4, 0.3, 0.3)]
	_rc(ci, r, cols[seed % cols.size()])
	for k in 3:
		var y := r.position.y + (k + 1) * r.size.y / 4.0
		ci.draw_line(Vector2(r.position.x + 2, y + (seed + k) % 3 - 1), Vector2(r.end.x - 2, y - (seed * k) % 3 + 1), Color(0, 0, 0, 0.35), 2.0)
	var bits := [Vector2(0.2, 0.3), Vector2(0.7, 0.55), Vector2(0.45, 0.8)]
	for k in 3:
		var b: Vector2 = r.position + r.size * (bits[(k + seed) % 3] as Vector2)
		match (k + seed) % 3:
			0:
				ci.draw_circle(b, 4.0, Color(0.15, 0.15, 0.15))
				ci.draw_circle(b, 1.8, Color(1.0, 0.3, 0.2) if seed % 2 == 0 else Color(0.3, 0.3, 0.3))
			1:
				ci.draw_rect(Rect2(b - Vector2(5, 3), Vector2(10, 6)), cols[(seed + 2) % cols.size()].darkened(0.2))
			_:
				ci.draw_line(b, b + Vector2(10, -6), Color(0.3, 0.3, 0.32), 3.0)


## (1.97) A maker's sign in its shop: enamel for Old Iron, a painted plank for Scrapworks.
static func _maker_plaque(ci: CanvasItem, r: Rect2, m: String, title: String, sub: String) -> void:
	var f := ThemeDB.fallback_font
	var col: Color = load("res://makers.gd").color(m)
	var room := r.size.x - (8.0 if m == "scrapworks" else r.size.y + 4.0)
	var tsz := mini(13, int(13.0 * room / maxf(1.0, f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)))
	var ssz := mini(10, int(10.0 * room / maxf(1.0, f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)))
	if m == "scrapworks":
		_pg(ci, PackedVector2Array([r.position + Vector2(0, 3), Vector2(r.end.x, r.position.y), r.end - Vector2(0, 2), Vector2(r.position.x, r.end.y)]), Color(0.55, 0.44, 0.3))
		ci.draw_line(r.position + Vector2(r.size.x * 0.55, 0), Vector2(r.position.x + r.size.x * 0.58, r.end.y), Color(0.3, 0.22, 0.14), 1.5)
		ci.draw_rect(Rect2(r.position.x + r.size.x * 0.5, r.position.y + 6, 16, 8), Color(0.85, 0.8, 0.6, 0.85))
		ci.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y * 0.5), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tsz, Color(0.95, 0.9, 0.8))
		ci.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y * 0.88), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, ssz, Color(0.15, 0.1, 0.06))
		return
	if m == "hellfire":
		# (1.99) a black steel sign, a hazard border, yellow stencil letters
		_rc(ci, r, Color(0.95, 0.75, 0.1))
		var inner := r.grow(-4)
		ci.draw_rect(inner, Color(0.09, 0.08, 0.08))
		ci.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y * 0.5), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tsz, Color(0.98, 0.78, 0.15))
		ci.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y * 0.86), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, ssz, Color(1.0, 0.5, 0.2))
		return
	_rc(ci, r, Color(0.93, 0.89, 0.8))
	_rc(ci, r.grow(-3), col, false, 2.0)
	load("res://logos.gd").draw_logo(ci, load("res://makers.gd").logo(m), r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.32)
	var tcol := col.darkened(0.2) if col.get_luminance() < 0.6 else col.darkened(0.6)   # (1.101) pale makers read dark on the enamel
	ci.draw_string(f, Vector2(r.position.x + r.size.y, r.position.y + r.size.y * 0.48), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - r.size.y - 4, tsz, tcol)
	ci.draw_string(f, Vector2(r.position.x + r.size.y, r.position.y + r.size.y * 0.82), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - r.size.y - 4, ssz, Color(0.2, 0.18, 0.16))


static func _sign(ci: CanvasItem, center: Vector2, text: String, c: Color) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0
	_rc(ci, Rect2(center.x - w * 0.5, center.y - 14, w, 22), Color(0.08, 0.08, 0.1))
	_rc(ci, Rect2(center.x - w * 0.5, center.y - 14, w, 22), c, false, 2.0)
	ci.draw_string(f, Vector2(center.x - w * 0.5, center.y + 3), text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, c)


static func _lamp(ci: CanvasItem, top: Vector2, size: Vector2, t: float) -> void:
	var sway := sin(t * 0.9) * 6.0
	var bulb := top + Vector2(sway, 46)
	ci.draw_line(top, bulb, Color(0.15, 0.15, 0.15), 2.0)
	if _on:
		# a real light: the beam fades as it falls, the bulb glows
		ci.draw_polygon(PackedVector2Array([bulb + Vector2(-12, 0), bulb + Vector2(12, 0), bulb + Vector2(90 + sway, size.y), bulb + Vector2(-90 + sway, size.y)]),
				PackedColorArray([Color(1.0, 0.85, 0.55, 0.16), Color(1.0, 0.85, 0.55, 0.16), Color(1.0, 0.85, 0.55, 0.02), Color(1.0, 0.85, 0.55, 0.02)]))
		ci.draw_circle(bulb + Vector2(0, 2), 26, Color(1.0, 0.85, 0.55, 0.08))
		ci.draw_circle(bulb + Vector2(0, 2), 12, Color(1.0, 0.88, 0.6, 0.18))
	else:
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
	_pg(ci, pts, Color(0.28, 0.24, 0.22))
	var junk := [[-0.6, 0.3, "wheel"], [-0.25, 0.7, "head"], [0.1, 0.85, "arm"], [0.4, 0.5, "wheel"], [-0.45, 0.55, "arm"],
			[0.25, 0.3, "head"], [0.65, 0.25, "plate"], [-0.05, 0.45, "plate"], [-0.8, 0.12, "plate"]]
	for j in junk:
		var p: Vector2 = base + Vector2(j[0] * w, -j[1] * h * 0.9)
		var c := Color(0.42, 0.38, 0.35).lerp(Color(0.55, 0.3, 0.2), fmod(absf(j[0]) * 3.0, 1.0))
		match j[2]:
			"wheel":
				_cr(ci, p, 9, Color(0.12, 0.12, 0.12))
				_cr(ci, p, 4, c)
			"head":
				_rc(ci, Rect2(p - Vector2(10, 8), Vector2(20, 16)), c)
				_cr(ci, p + Vector2(4, -1), 2.5, Color(0.2, 0.2, 0.2) if int(t * 0.5 + j[0] * 10) % 4 else Color(1.0, 0.3, 0.2))
			"arm":
				_ln(ci, p, p + Vector2(18, -14), c, 6.0)
				_cr(ci, p + Vector2(18, -14), 4, c.darkened(0.2))
			"plate":
				_pg(ci, PackedVector2Array([p, p + Vector2(16, -6), p + Vector2(20, 6), p + Vector2(2, 8)]), c.darkened(0.15))


const MEDAL_COLORS := [Color(0.5, 0.5, 0.5), Color(0.95, 0.78, 0.25), Color(0.8, 0.82, 0.88), Color(0.8, 0.5, 0.25)]


## The bay's trophy wall: one trophy per medal - first, second or third place in a league, a
## playoff or a cup. Gold, silver or bronze; the shape tells you which event it's from.
## Where each trophy stands on the bay's shelves: [index into the trophy list, base point] (newest ones
## shown). Used for drawing them and for tapping them.
## The trophy wall in Gus's office (Season): two long shelves above the fight-net screen, the newest
## trophies at the end. [index into the trophies list, base point]
const TROPHY_SCALE := 1.35
static func trophy_spots(size: Vector2, count: int) -> Array:
	var x0 := size.x * 0.05
	var w := size.x * 0.56
	var step := 26.0 * TROPHY_SCALE
	var per_shelf := maxi(1, int((w - 12.0) / step))
	var shown := mini(count, per_shelf * 2)
	# your dad's three always stay at the start of the top shelf; then the newest of yours
	var keep := mini(3, shown)
	var idx: Array = range(keep) + range(count - (shown - keep), count)
	var out: Array = []
	for k in shown:
		out.append([idx[k], Vector2(x0 + 8.0 + step * 0.5 + (k % per_shelf) * step, size.y * 0.17 + (k / per_shelf) * (size.y * 0.15))])
	return out


static func _trophy_wall(ci: CanvasItem, size: Vector2, info: Dictionary) -> void:
	var list: Array = info.get("wall", info.get("medals", []))
	var x0 := size.x * 0.05
	var w := size.x * 0.56
	# two long shelves on brackets, whether there's anything on them yet or not
	for k in 2:
		var y := size.y * 0.17 + k * size.y * 0.15
		_rc(ci, Rect2(x0, y, w, 6), Color(0.45, 0.32, 0.2))
		_rc(ci, Rect2(x0, y + 6, w, 2), Color(0.3, 0.2, 0.12))
		for bx in [x0 + 10.0, x0 + w - 16.0]:
			_pg(ci, PackedVector2Array([Vector2(bx, y + 6), Vector2(bx + 6, y + 6), Vector2(bx, y + 18)]), Color(0.3, 0.3, 0.32))
	if list.is_empty():
		ci.draw_string(ThemeDB.fallback_font, Vector2(x0, size.y * 0.17 - 8), I18n.t("(room for trophies)"), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.6, 0.6, 0.6, 0.6))
	for s in trophy_spots(size, list.size()):
		var tr: Dictionary = list[s[0]]
		draw_trophy(ci, s[1], str(tr.get("kind", "cup")), int(tr.get("medal", 1)), TROPHY_SCALE)
		if tr.get("dad", false):
			# older, a little dull
			_rc(ci, Rect2(Vector2(s[1]) + Vector2(-16, -46), Vector2(32, 46)), Color(0.25, 0.2, 0.15, 0.18))
	# a brass plate on the shelf edge under your dad's three
	var dads := 0
	for tr in list:
		if tr.get("dad", false):
			dads += 1
	if dads > 0:
		var step := 26.0 * TROPHY_SCALE
		var pr := Rect2(x0 + 8.0, size.y * 0.17 + 1, step * dads, 9)
		_rc(ci, pr, Color(0.62, 0.5, 0.25))
		_rc(ci, pr, Color(0.35, 0.27, 0.12), false, 1.0)
		ci.draw_string(ThemeDB.fallback_font, Vector2(pr.position.x, pr.end.y - 1), I18n.t("DAD"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 9, Color(0.2, 0.14, 0.06))
	# the championship belt hangs on the wall beside the shelves
	if info.get("champion", false):
		var gold: Color = MEDAL_COLORS[1]
		var bc := Vector2(size.x * 0.74, size.y * 0.42)
		_rc(ci, Rect2(bc.x - 52, bc.y - 6, 104, 12), Color(0.15, 0.12, 0.1))
		_cr(ci, bc, 16, gold)
		_cr(ci, bc, 10, Color(0.8, 0.15, 0.2))
		_cr(ci, bc, 4, gold)
		for side in [-1.0, 1.0]:
			_cr(ci, bc + Vector2(side * 32, 0), 7, gold)


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
			_rc(ci, Rect2(base + Vector2(-9, -22) * s, Vector2(18, 22) * s), wood)
			_rc(ci, Rect2(base + Vector2(-9, -22) * s, Vector2(18, 22) * s), wood.darkened(0.3), false, 1.2 * s)
			_rc(ci, Rect2(base + Vector2(-6, -16) * s, Vector2(12, 8) * s), c)
			_cr(ci, base + Vector2(-6, -12) * s, 1.6 * s, wood)
			_cr(ci, base + Vector2(6, -12) * s, 1.6 * s, wood)
			_cr(ci, base + Vector2(0, -19.5) * s, 1.0 * s, Color(0.7, 0.7, 0.72))
		"rust":
			# Rust League: a giant hex nut, rusty orange inside the medal metal, on a plinth
			_rc(ci, Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), wood)
			var hc := base + Vector2(0, -16) * s
			var hexp := PackedVector2Array()
			for k in 6:
				hexp.append(hc + Vector2(cos(k * PI / 3.0 + PI / 6.0), sin(k * PI / 3.0 + PI / 6.0)) * 10.0 * s)
			_pg(ci, hexp, c)
			_cr(ci, hc, 4.5 * s, Color(0.55, 0.27, 0.12))
			_ac(ci, hc, 4.5 * s, 0, TAU, 10, dark, 1.2 * s)
		"iron", "regional":
			# Iron League: a shield on a stand
			_rc(ci, Rect2(base + Vector2(-7, -5) * s, Vector2(14, 5) * s), wood)
			_rc(ci, Rect2(base + Vector2(-1.5, -9) * s, Vector2(3, 4) * s), dark)
			_pg(ci, PackedVector2Array([base + Vector2(-9, -28) * s, base + Vector2(9, -28) * s, base + Vector2(9, -18) * s,
					base + Vector2(0, -9) * s, base + Vector2(-9, -18) * s]), c)
			_ln(ci, base + Vector2(0, -27) * s, base + Vector2(0, -11) * s, dark, 1.6 * s)
			_ln(ci, base + Vector2(-8, -21) * s, base + Vector2(8, -21) * s, dark, 1.6 * s)
		"steel":
			# Steel League: a five-pointed star on a tall stem
			_rc(ci, Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), Color(0.2, 0.22, 0.26))
			_rc(ci, Rect2(base + Vector2(-1.5, -16) * s, Vector2(3, 11) * s), Color(0.7, 0.75, 0.82))
			var sc := base + Vector2(0, -25) * s
			var star := PackedVector2Array()
			for k in 10:
				var rr := (10.0 if k % 2 == 0 else 4.2) * s
				star.append(sc + Vector2(cos(-PI / 2.0 + k * PI / 5.0), sin(-PI / 2.0 + k * PI / 5.0)) * rr)
			_pg(ci, star, c)
		"scrap":
			# a little robot welded together from scrap, arms up: bolt base, leg strut, box body, round head
			_rc(ci, Rect2(base + Vector2(-8, -5) * s, Vector2(16, 5) * s), Color(0.3, 0.3, 0.32))
			_cr(ci, base + Vector2(-5, -2.5) * s, 1.3 * s, c)
			_cr(ci, base + Vector2(5, -2.5) * s, 1.3 * s, c)
			_ln(ci, base + Vector2(-3, -5) * s, base + Vector2(-4, -12) * s, dark, 2.5 * s)
			_ln(ci, base + Vector2(3, -5) * s, base + Vector2(4, -12) * s, dark, 2.5 * s)
			_rc(ci, Rect2(base + Vector2(-6, -21) * s, Vector2(12, 10) * s), c)
			_ln(ci, base + Vector2(-6, -19) * s, base + Vector2(-11, -27) * s, c, 2.5 * s)
			_ln(ci, base + Vector2(6, -19) * s, base + Vector2(11, -27) * s, c, 2.5 * s)
			_cr(ci, base + Vector2(-11, -28) * s, 2.0 * s, dark)   # gear fists
			_cr(ci, base + Vector2(11, -28) * s, 2.0 * s, dark)
			_cr(ci, base + Vector2(0, -26) * s, 5.0 * s, c)
			_rc(ci, Rect2(base + Vector2(-3.5, -27) * s, Vector2(7, 2) * s), Color(0.15, 0.1, 0.08))
		"championship", "title":
			# the big one: two-step base, tall stem, wide cup and a little robot on the lid
			_rc(ci, Rect2(base + Vector2(-10, -5) * s, Vector2(20, 5) * s), wood)
			_rc(ci, Rect2(base + Vector2(-7, -9) * s, Vector2(14, 4) * s), wood.lightened(0.1))
			_rc(ci, Rect2(base + Vector2(-2, -19) * s, Vector2(4, 10) * s), c)
			_ac(ci, base + Vector2(0, -27) * s, 10 * s, 0, PI, 12, c, 8.0 * s)
			_rc(ci, Rect2(base + Vector2(-11, -35) * s, Vector2(22, 3) * s), c)
			_ac(ci, base + Vector2(-12, -28) * s, 5 * s, PI * 0.5, PI * 1.5, 6, c, 2.0 * s)
			_ac(ci, base + Vector2(12, -28) * s, 5 * s, -PI * 0.5, PI * 0.5, 6, c, 2.0 * s)
			# a crown on the lid: the Titanium Championship
			_pg(ci, PackedVector2Array([base + Vector2(-6, -36) * s, base + Vector2(-6, -41) * s, base + Vector2(-3, -38) * s,
					base + Vector2(0, -43) * s, base + Vector2(3, -38) * s, base + Vector2(6, -41) * s, base + Vector2(6, -36) * s]), c.lightened(0.15))
			_cr(ci, base + Vector2(0, -28) * s, 2.5 * s, Color(0.9, 0.2, 0.25))
		_:   # cups: a small cup on a purple plinth
			_rc(ci, Rect2(base + Vector2(-5, -5) * s, Vector2(10, 5) * s), Color(0.42, 0.25, 0.55))
			_rc(ci, Rect2(base + Vector2(-1.5, -10) * s, Vector2(3, 5) * s), c)
			_ac(ci, base + Vector2(0, -15) * s, 6 * s, 0, PI, 8, c, 5.0 * s)
			_rc(ci, Rect2(base + Vector2(-6.5, -20) * s, Vector2(13, 2) * s), c)


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
	_rc(ci, pb, Color(0.42, 0.33, 0.22))
	_rc(ci, pb, Color(0.3, 0.23, 0.15), false, 3.0)
	for gx in range(int(pb.size.x / 14.0)):
		for gy in range(int(pb.size.y / 14.0)):
			_cr(ci, pb.position + Vector2(8 + gx * 14.0, 8 + gy * 14.0), 1.3, Color(0.3, 0.23, 0.15))
	var steel := Color(0.68, 0.7, 0.75)
	var u := pb.size.x / 5.0
	var top := pb.position.y + 12.0
	var len := pb.size.y - 26.0
	# wrench: shaft with an open jaw on top
	var wx := pb.position.x + u * 0.6
	_ln(ci, Vector2(wx, top + 10), Vector2(wx, top + len), steel, 5.0)
	_cr(ci, Vector2(wx, top + 6), 8, steel)
	_rc(ci, Rect2(wx - 3, top - 3, 6, 9), Color(0.42, 0.33, 0.22))
	# hammer: wooden handle, steel head
	var hx := pb.position.x + u * 1.6
	_ln(ci, Vector2(hx, top + 4), Vector2(hx, top + len), Color(0.7, 0.5, 0.28), 5.0)
	_rc(ci, Rect2(hx - 13, top - 2, 26, 10), Color(0.45, 0.47, 0.52))
	# screwdriver: red handle, thin shaft
	var sx := pb.position.x + u * 2.5
	_rc(ci, Rect2(sx - 4, top, 8, len * 0.4), Color(0.8, 0.22, 0.2))
	_ln(ci, Vector2(sx, top + len * 0.4), Vector2(sx, top + len), steel, 2.0)
	# pliers: two handles crossing at a pivot
	var px := pb.position.x + u * 3.4
	_ln(ci, Vector2(px - 2, top), Vector2(px + 6, top + len), Color(0.2, 0.35, 0.75), 4.0)
	_ln(ci, Vector2(px + 2, top), Vector2(px - 6, top + len), Color(0.2, 0.35, 0.75), 4.0)
	_ln(ci, Vector2(px - 2, top - 4), Vector2(px + 2, top), steel, 4.0)
	_cr(ci, Vector2(px, top + len * 0.3), 3, steel)
	# roll of red tape on a peg
	var tc := Vector2(pb.position.x + u * 4.4, top + len * 0.45)
	_cr(ci, tc, 11, Color(0.75, 0.2, 0.2))
	_cr(ci, tc, 5, Color(0.42, 0.33, 0.22))


# ---------------------------------------------------------------- Diagnostic Noir: rooms and props (1.61)
# Each place sits in its own light (light.gd: "bay" in Gus's building, "pub", "shop", "scrap",
# "phone"): the walls sink a little, the floor gets a pool of light where the robot stands and falls
# into the dark at the edges, and the props are lit plates with one dark outline (the same painting
# tools as the robots). Screens, bulbs, neon and fire stay bright. The Classic look keeps it flat.

static var _on := false   # true while a scene's props are being drawn lit

## dim: how far the walls sink (alpha of the tint). pool: how bright the floor's pool of light is.
const ROOM := {
	"bay": {"tint": Color(0.02, 0.02, 0.04), "dim": 0.3, "pool": 0.1},
	"pub": {"tint": Color(0.05, 0.0, 0.02), "dim": 0.32, "pool": 0.09},
	"shop": {"tint": Color(0.0, 0.02, 0.06), "dim": 0.22, "pool": 0.08},
	"brass": {"tint": Color(0.05, 0.02, 0.0), "dim": 0.26, "pool": 0.1},
	"hell": {"tint": Color(0.06, 0.02, 0.04), "dim": 0.14, "pool": 0.09},
	"volta": {"tint": Color(0.04, 0.0, 0.08), "dim": 0.2, "pool": 0.13},
	"nimbus": {"tint": Color(0.0, 0.02, 0.06), "dim": 0.14, "pool": 0.1},
	"kane": {"tint": Color(0.0, 0.0, 0.02), "dim": 0.3, "pool": 0.2},
	"tenryu": {"tint": Color(0.05, 0.01, 0.02), "dim": 0.2, "pool": 0.1},
	"circus": {"tint": Color(0.02, 0.02, 0.06), "dim": 0.16, "pool": 0.12},
	"scrap": {"tint": Color(0.06, 0.02, 0.08), "dim": 0.12, "pool": 0.07},
	"phone": {"tint": Color(0.0, 0.0, 0.03), "dim": 0.0, "pool": 0.0},
}


static func _begin(scene: String) -> void:
	_on = not RobotArt.classic
	if _on:
		RobotArt._set_light(scene_light(scene), 1.0)
		RobotArt._grade = 2
		RobotArt._flash = false


static func _room_dim(ci: CanvasItem, screen: Vector2, stage: Rect2, floor_y: float, scene: String) -> void:
	if not _on:
		return
	var m: Dictionary = ROOM.get(scene_light(scene), ROOM["bay"])
	var tint: Color = m["tint"]
	if float(m["dim"]) > 0.0:
		ci.draw_rect(Rect2(Vector2(-10, -10), screen + Vector2(20, 20)), Color(tint, float(m["dim"])))
		ci.draw_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(screen.x + 10, -10), Vector2(screen.x + 10, floor_y * 0.45), Vector2(-10, floor_y * 0.45)]),
				PackedColorArray([Color(tint, 0.45), Color(tint, 0.45), Color(tint, 0.0), Color(tint, 0.0)]))


## The floor: a pool of the place's light where the robot (or the bar) stands, then dark at the bottom.
static func _room_floor(ci: CanvasItem, screen: Vector2, stage: Rect2, floor_y: float, scene: String) -> void:
	if not _on:
		return
	var m: Dictionary = ROOM.get(scene_light(scene), ROOM["bay"])
	var key: Color = Light.get_set(scene_light(scene))["key"]
	var tint: Color = m["tint"]
	if float(m["pool"]) > 0.0:
		var cx := stage.position.x + stage.size.x * float(robot_spot(scene)[0])
		ci.draw_set_transform(Vector2(cx, floor_y + 8), 0.0, Vector2(1.0, 0.18))
		ci.draw_circle(Vector2.ZERO, stage.size.x * 0.32, Color(key, float(m["pool"]) * 0.6))
		ci.draw_circle(Vector2.ZERO, stage.size.x * 0.18, Color(key, float(m["pool"]) * 0.7))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_polygon(PackedVector2Array([Vector2(-10, floor_y + 4), Vector2(screen.x + 10, floor_y + 4), Vector2(screen.x + 10, screen.y + 10), Vector2(-10, screen.y + 10)]),
			PackedColorArray([Color(tint, 0.0), Color(tint, 0.0), Color(tint, 0.55), Color(tint, 0.55)]))
	ci.draw_line(Vector2(0, floor_y), Vector2(screen.x, floor_y), Color(key, 0.35), 1.5)


## The scene's sides fall into the dark (over the people in front too).
static func _room_edges(ci: CanvasItem, stage: Rect2, scene: String) -> void:
	if not _on or scene == "phone":
		return
	var sw := stage.size.x * 0.14
	var d := Color(0.0, 0.0, 0.02)
	var r := stage
	ci.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(sw, 0), Vector2(r.position.x + sw, r.end.y), Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color(d, 0.35), Color(d, 0.0), Color(d, 0.0), Color(d, 0.35)]))


static func _solid(c: Color) -> bool:
	return _on and c.a > 0.99


## Props: rectangles, discs, lines, polygons and arcs, lit when the room is (a plate with a shadow
## side and light edges when big enough, otherwise just the outline).
static func _rc(ci: CanvasItem, r: Rect2, c: Color, filled: bool = true, w: float = -1.0) -> void:
	if not filled:
		ci.draw_rect(r, c, false, w)
		if _solid(c) and w >= 2.0:
			ci.draw_rect(r.grow(w * 0.5 + 0.8), RobotArt.OUTLINE, false, 1.4)
		return
	var m := minf(absf(r.size.x), absf(r.size.y))
	if _solid(c) and m >= 10.0 and r.size.x * r.size.y < 160000.0:
		var a := r.abs()
		RobotArt._plate(ci, PackedVector2Array([a.position, Vector2(a.end.x, a.position.y), a.end, Vector2(a.position.x, a.end.y)]), c)
	elif _solid(c) and m >= 2.5:
		RobotArt._box(ci, r.abs(), c)
	else:
		ci.draw_rect(r, c)


static func _cr(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	if _solid(c) and r >= 8.0:
		RobotArt._round(ci, p, r, c)
	elif _solid(c) and r >= 2.5:
		RobotArt._disc(ci, p, r, c)
	else:
		ci.draw_circle(p, r, c)


static func _ln(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = -1.0) -> void:
	if _solid(c) and w >= 5.0:
		RobotArt._limb(ci, a, b, c, w)
	elif _solid(c) and w >= 2.5:
		RobotArt._ln(ci, a, b, c, w)
	else:
		ci.draw_line(a, b, c, w)


static func _pg(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	if _solid(c) and pts.size() >= 3:
		var bb := Rect2(pts[0], Vector2.ZERO)
		for q in pts:
			bb = bb.expand(q)
		if minf(bb.size.x, bb.size.y) >= 12.0:
			RobotArt._plate(ci, pts, c)
		else:
			RobotArt._poly(ci, pts, c)
	else:
		ci.draw_colored_polygon(pts, c)


static func _ac(ci: CanvasItem, at: Vector2, r: float, a0: float, a1: float, n: int, c: Color, w: float = -1.0) -> void:
	if _solid(c) and w >= 2.5:
		RobotArt._arc(ci, at, r, a0, a1, n, c, w)
	else:
		ci.draw_arc(at, r, a0, a1, n, c, w)
