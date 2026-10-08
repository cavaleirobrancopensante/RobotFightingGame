extends Control
## The opening: a cutscene in eight shots that shows the world before the first fight.
##   1 the city   2 the stadium   3 your dad's night   4 OVERLORD   5 the fall
##   6 the scrapyard (the tarp comes off)   7 the road (the ladder lights up)   8 the bell (Old Pike)
## Design: "Robot Fighting · Opening & Teaching Study". One tap = next shot, SKIP (or Esc / Enter)
## goes straight to the fight. The overture (music/overture.ogg) is written to these timings.
## Played once for a new game (then Old Pike's course); BotMedia > Story can play it again.
##
## Everything is drawn here, live, from the game's own art: robots (RobotArt), people (PilotArt),
## the arena (Arena), trophies and the scrap pile (GarageArt), the LED and split-flap boards
## (Scoreboard). The world sits on a Stage child whose transform is the camera; the words sit on top.

const RobotArt = preload("res://robot_art.gd")
const PilotArt = preload("res://pilot_art.gd")
const GarageArt = preload("res://garage_art.gd")
const Arena = preload("res://arena.gd")
const Scoreboard = preload("res://scoreboard.gd")
const UI = preload("res://ui.gd")
const GUI = preload("res://garage_ui.gd")
const I18n = preload("res://i18n.gd")

## [id, seconds, camera from [x, y, zoom], camera to] (x, y = fractions of the screen)
const SHOTS := [
	["city", 8.0, [0.5, 0.5, 1.0], [0.62, 0.6, 1.18]],
	["stadium", 7.0, [0.5, 0.5, 1.0], [0.5, 0.52, 1.6]],
	# your dad's night: hard cuts, like a fight broadcast
	["dad_face", 2.6, [0.5, 0.5, 1.0], [0.5, 0.48, 1.12]],
	["dad_clash", 1.8, [0.5, 0.5, 1.15], [0.5, 0.5, 1.3]],
	["dad_uppercut", 4.2, [0.5, 0.56, 1.12], [0.56, 0.42, 1.2]],   # one shot: the uppercut takes SLEDGE's head off
	["dad_win", 3.4, [0.5, 0.52, 1.18], [0.46, 0.56, 1.05]],
	["overlord", 10.0, [0.5, 0.5, 1.0], [0.6, 0.55, 1.3]],
	["fall", 10.0, [0.5, 0.3, 1.5], [0.5, 0.72, 1.5]],
	["scrap", 13.0, [0.5, 0.5, 1.0], [0.5, 0.64, 1.55]],
	["road", 10.0, [0.3, 0.68, 1.7], [0.5, 0.5, 1.0]],
	["bell", 8.0, [0.5, 0.5, 1.0], [0.6, 0.58, 1.25]],
]
## [shot id, seconds in, speaker, text]
const LINES := [
	["city", 0.8, "NARRATOR", "Port Ferrum, 2047. Kane Dynamics owns the city."],
	["stadium", 0.6, "NARRATOR", "And on Saturday nights, the whole city comes here."],
	["dad_face", 0.3, "NARRATOR", "Pilots ran the ring. Your father was one of the best."],
	["overlord", 2.4, "NARRATOR", "Then Kane built a fighter that needs nobody."],
	["fall", 1.0, "NARRATOR", "The pilots were sent home. Your father was the first."],
	["scrap", 6.0, "GUS", "Your dad's. Still yours, if it still works."],
	["scrap", 9.6, "ECHO", "[ HANDLER LINK FOUND ]"],
	["road", 1.0, "NARRATOR", "From the gutter to the Titanium Championship. One rung a year."],
	["bell", 1.2, "GUS", "Old Pike fights anybody for a hundred bucks. Let's see what you've got."],
]
## Shots that cut straight to the next one (no fade between them)
const CUTS := ["dad_face", "dad_clash", "dad_uppercut"]
const FADE := 0.45
const CPS := 40.0   # letters a second as a line types out

var shot := 0
var t := 0.0
var clock := 0.0
var line_i := -1
var shown := 0.0
var beep := 0.0
var done := false
var stage: Stage
var overlay: Overlay
var heads := {}          # who -> head position in stage coordinates (for the bubble's tail)
var crowd: Array = []
var looks := {}
var dad := {}
var you := {}
var pike_look := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	OS.low_processor_usage_mode = false
	stage = Stage.new()
	stage.op = self
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	overlay = Overlay.new()
	overlay.op = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	dad = GameData.dad_look()
	you = GameData.pilot_look
	var mine: Dictionary = GameData.player_look()
	looks["echo_dad"] = repaint(mine, Color("#24467a"), Color("#e0b030"), 1.0)
	looks["echo_rust"] = repaint(mine, Color("#7a5236"), Color("#5a4a3a"), 0.45)
	looks["overlord"] = rival_look(9)
	looks["foe_a"] = rival_look(6)   # SLEDGE: your dad's opponent that night
	looks["foe_b"] = rival_look(4)   # HAMMERHEAD: the piloted robot OVERLORD tears up
	if not GameData.opening_replay and GameData.wins + GameData.losses == 0 and GameData.pickup.is_empty():
		GameData.start_first_fight()   # so the last shot shows Old Pike's real robot
	var pk: Array = GameData.current_opponent_team() if not GameData.pickup.is_empty() and GameData.pickup.get("first", false) else []
	pike_look = GameData.look_from_spec(pk[0]) if not pk.is_empty() else rival_look(0)
	Sfx.music("overture")
	_start_shot(0)


## A robot repainted (your dad's colours, or the rust under the tarp), every part whole or worn.
func repaint(look: Dictionary, body: Color, trim: Color, health: float) -> Dictionary:
	var l := look.duplicate(true)
	l.erase("stickers")
	for slot in l["parts"]:
		var p: Dictionary = l["parts"][slot]
		if p.has("shape"):
			var c := body
			if slot.begins_with("arm"):
				c = body.lightened(0.12)
			elif slot.begins_with("leg"):
				c = body.darkened(0.18)
			p["color"] = c
			p["health"] = health
			p["alive"] = true
	l["trim"] = trim
	return l


func rival_look(i: int) -> Dictionary:
	var spec: Dictionary = GameData.opponent_spec_from(GameData.OPPONENTS[i], 1.0)
	var l := GameData.look_from_spec(spec)
	for slot in l["parts"]:
		if l["parts"][slot].has("health"):
			l["parts"][slot]["health"] = 1.0
	return l


func _start_shot(i: int) -> void:
	shot = i
	t = 0.0
	if line_i >= 0 and not line_shot(line_i):
		line_i = -1
	if sid() == "dad_face":
		Sfx.play("crowd_cheer", 0.0, -8.0)
	if sid() == "bell":
		Sfx.play("crowd_ooh", 0.0, -14.0)


func sid() -> String:
	return str(SHOTS[shot][0])


## A line belongs to the shot it names; the narrator's line over the fight stays up through the cuts.
func line_shot(k: int) -> bool:
	var ls := str(LINES[k][0])
	return ls == sid() or (ls == "dad_face" and sid().begins_with("dad_"))


func shot_start_time(i: int) -> float:
	var s := 0.0
	for k in i:
		s += float(SHOTS[k][1])
	return s


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	clock += delta
	# the line for this moment of the shot
	for k in LINES.size():
		if str(LINES[k][0]) == sid() and t >= float(LINES[k][1]) and k > line_i:
			line_i = k
			shown = 0.0
	if line_i >= 0 and line_shot(line_i):
		var full := line_text(line_i).length()
		if shown < full:
			shown += delta * CPS
			beep -= delta
			if beep <= 0.0 and str(LINES[line_i][2]) != "NARRATOR":
				beep = 0.07
				Sfx.voice(str(LINES[line_i][2]))
	_events()
	if t >= float(SHOTS[shot][1]):
		if shot + 1 >= SHOTS.size():
			finish()
			return
		_start_shot(shot + 1)
	_camera()
	stage.queue_redraw()
	overlay.queue_redraw()


## Sounds that land on a beat of the picture.
var _fired := {}
func _events() -> void:
	var cues := {"dad_bell": ["dad_face", 0.1, "round"], "clash": ["dad_clash", 0.75, "hit_big"], "upper": ["dad_uppercut", 0.85, "uppercut"],
			"upper2": ["dad_uppercut", 0.9, "hit_big"], "pop": ["dad_uppercut", 0.95, "break"], "ko": ["dad_uppercut", 1.2, "ko"],
			"roar": ["dad_win", 0.0, "crowd_cheer"], "ol_hit1": ["overlord", 5.0, "hit_big"], "ol_hit2": ["overlord", 6.6, "break"],
			"lever": ["scrap", 2.6, "click"], "tarp": ["scrap", 3.0, "swing"], "lamp": ["scrap", 7.2, "equip"], "eye": ["scrap", 8.0, "target"], "bell": ["bell", 6.8, "round"]}
	for k in cues:
		var c: Array = cues[k]
		if sid() == str(c[0]) and t >= float(c[1]) and not _fired.has(k):
			_fired[k] = true
			Sfx.play(str(c[2]), 0.0, -4.0)


func line_text(k: int) -> String:
	return tr(str(LINES[k][3])).replace("ECHO", GameData.robot_name) if str(LINES[k][2]) != "ECHO" else tr(str(LINES[k][3]))


## The camera: one smooth move per shot (eased), applied to the stage.
func _camera() -> void:
	var sh: Array = SHOTS[shot]
	var k := smoothstep(0.0, float(sh[1]), t)
	var a: Array = sh[2]
	var b: Array = sh[3]
	var z := lerpf(float(a[2]), float(b[2]), k)
	var c := Vector2(lerpf(float(a[0]), float(b[0]), k), lerpf(float(a[1]), float(b[1]), k)) * size
	# keep the frame inside the stage (no empty edges when zoomed)
	var half := size * 0.5 / z
	c.x = clampf(c.x, half.x, size.x - half.x)
	c.y = clampf(c.y, half.y, size.y - half.y)
	stage.size = size
	stage.scale = Vector2(z, z)
	stage.position = size * 0.5 - c * z


func to_screen(p: Vector2) -> Vector2:
	return stage.position + p * stage.scale


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if overlay.skip_rect.has_point(event.position):
		finish()
		return
	next()
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_ENTER:
				finish()
			KEY_SPACE, KEY_RIGHT:
				next()


## A tap: finish the line that's typing, otherwise on to the next shot (the music follows).
func next() -> void:
	if line_i >= 0 and line_shot(line_i) and shown < line_text(line_i).length():
		shown = 9999.0
		return
	if shot + 1 >= SHOTS.size():
		finish()
		return
	_start_shot(shot + 1)
	if Sfx.music_player and Sfx.music_player.playing:
		Sfx.music_player.seek(shot_start_time(shot))


func finish() -> void:
	if done:
		return
	done = true
	Sfx.play("click")
	if GameData.opening_replay:
		GameData.opening_replay = false
		Loading.go("res://garage.tscn")
		return
	GameData.mark_story_seen("intro")
	if GameData.pickup.is_empty() and GameData.wins + GameData.losses == 0:
		GameData.start_first_fight()
	GameData.save_game()
	Loading.go("res://fight.tscn")


# ================================================================ the world

class Stage extends Control:
	var op

	func _draw() -> void:
		PilotArt.light = op.shot_light()   # (1.62) every shot has its own light
		var W := size.x
		var H := size.y
		if W < 10.0:
			return
		match str(SHOTS[op.shot][0]):
			"city":
				op.draw_city(self, W, H, op.t)
			"stadium":
				op.draw_stadium(self, W, H, op.t)
			"dad_face":
				op.draw_dad_face(self, W, H, op.t)
			"dad_clash":
				op.draw_dad_clash(self, W, H, op.t)
			"dad_uppercut":
				op.draw_dad_uppercut(self, W, H, op.t)
			"dad_win":
				op.draw_dad_win(self, W, H, op.t)
			"overlord":
				op.draw_overlord(self, W, H, op.t)
			"fall":
				op.draw_fall(self, W, H, op.t)
			"scrap":
				op.draw_scrap(self, W, H, op.t)
			"road":
				op.draw_road(self, W, H, op.t)
			"bell":
				op.draw_bell(self, W, H, op.t)
		GarageArt._on = false


## The light each shot is lit by (light.gd), for the robots, people and props in it.
const SHOT_LIGHT := {"city": "city", "stadium": "stadium_ext", "dad_face": "champ_arena", "dad_clash": "champ_arena", "dad_uppercut": "champ_arena",
		"dad_win": "champ_arena", "overlord": "overlord", "fall": "fall", "scrap": "scrap_ring", "road": "road", "bell": "pub"}


func shot_light() -> String:
	return SHOT_LIGHT.get(str(SHOTS[shot][0]), "neutral")


static func hsh(k: int) -> float:
	return float(absi(hash(k * 7919 + 13)) % 10000) / 10000.0


func sky(ci: CanvasItem, W: float, H: float, top: Color, bottom: Color, to_y: float) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, to_y), Vector2(0, to_y)]),
			PackedColorArray([top, top, bottom, bottom]))


func stars(ci: CanvasItem, W: float, H: float, tt: float, n: int, max_y: float) -> void:
	for k in n:
		var p := Vector2(hsh(k) * W, hsh(k + 500) * max_y)
		var tw := 0.5 + 0.5 * sin(tt * (1.0 + hsh(k + 900) * 3.0) + k)
		ci.draw_circle(p, 0.8 + hsh(k + 77) * 1.2, Color(1, 1, 1, 0.25 + 0.5 * tw))


## A city skyline: far towers, then near towers with lit windows. Kane towers carry the logo.
func skyline(ci: CanvasItem, W: float, base_y: float, scale_h: float, tt: float, far_col: Color, near_col: Color, lit_share: float) -> void:
	var x := -10.0
	var k := 0
	while x < W + 10.0:
		var w := 22.0 + hsh(k) * 40.0
		var h := (0.06 + hsh(k + 40) * 0.12) * scale_h
		ci.draw_rect(Rect2(x, base_y - h, w, h), far_col)
		x += w - 4.0
		k += 1
	x = -20.0
	k = 200
	while x < W + 20.0:
		var w := 30.0 + hsh(k) * 50.0
		var kane := k % 7 == 3
		var h := (0.12 + hsh(k + 40) * 0.16 + (0.18 if kane else 0.0)) * scale_h
		var r := Rect2(x, base_y - h, w, h)
		GarageArt._rc(ci, r, near_col)
		# lit windows, a few flickering
		var cols := int(w / 9.0)
		var rows := int(h / 11.0)
		for c in cols:
			for rr in rows:
				var id := k * 1000 + c * 37 + rr
				if hsh(id) < lit_share:
					var on := not (hsh(id + 3) < 0.04 and fmod(tt + hsh(id + 9) * 5.0, 3.0) < 1.0)
					if on:
						ci.draw_rect(Rect2(x + 4 + c * 9.0, base_y - h + 6 + rr * 11.0, 4, 5), Color(1.0, 0.82, 0.45, 0.75) if hsh(id + 5) < 0.85 else Color(0.6, 0.85, 1.0, 0.7))
		if kane:
			# the Kane logo near the top and a blinking red light on the roof
			var lc := Vector2(x + w * 0.5, base_y - h + 18)
			ci.draw_rect(Rect2(lc - Vector2(11, 11), Vector2(22, 22)), Color(0.05, 0.05, 0.07))
			ci.draw_string(GUI.headb(), lc + Vector2(-11, 8), "K", HORIZONTAL_ALIGNMENT_CENTER, 22, 20, Color(1.0, 0.25, 0.3))
			GarageArt._ln(ci, Vector2(x + w * 0.5, base_y - h), Vector2(x + w * 0.5, base_y - h - 18), near_col, 2.5)
			if fmod(tt + k, 1.6) < 0.5:
				ci.draw_circle(Vector2(x + w * 0.5, base_y - h - 18), 3.0, Color(1.0, 0.2, 0.2))
				ci.draw_circle(Vector2(x + w * 0.5, base_y - h - 18), 8.0, Color(1.0, 0.2, 0.2, 0.2))
		x += w + 6.0 + hsh(k + 60) * 14.0
		k += 1


func crane(ci: CanvasItem, foot: Vector2, h: float, reach: float, c: Color) -> void:
	var top := foot + Vector2(0, -h)
	GarageArt._ln(ci, foot, top, c, 4.0)
	ci.draw_line(foot + Vector2(-10, 0), top + Vector2(-3, 0), c, 2.0)
	GarageArt._ln(ci, top + Vector2(-reach * 0.25, 0), top + Vector2(reach, 0), c, 3.0)
	ci.draw_line(top + Vector2(0, -12), top + Vector2(reach, 0), c, 1.5)
	ci.draw_line(top + Vector2(0, -12), top + Vector2(-reach * 0.25, 0), c, 1.5)
	ci.draw_line(top + Vector2(reach * 0.8, 0), top + Vector2(reach * 0.8, h * 0.4), c, 1.0)


func stadium_dome(ci: CanvasItem, c: Vector2, w: float, h: float, tt: float, glow: float) -> void:
	# searchlights first, then the bowl
	for k in 3:
		var a := -PI / 2.0 + sin(tt * 0.6 + k * 2.1) * 0.5
		var tip := c + Vector2(cos(a), sin(a)) * h * 9.0
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6 + k * 6, -h * 0.6), tip + Vector2(-h * 0.9, 0), tip + Vector2(h * 0.9, 0)]), Color(1.0, 0.95, 0.75, 0.07 * glow))
	ci.draw_circle(c, w * 0.8, Color(1.0, 0.8, 0.4, 0.06 * glow))
	var pts := PackedVector2Array()
	for k in 25:
		var a := PI + PI * k / 24.0
		pts.append(c + Vector2(cos(a) * w * 0.5, sin(a) * h))
	pts.append(c + Vector2(w * 0.5, h * 0.3))
	pts.append(c + Vector2(-w * 0.5, h * 0.3))
	GarageArt._pg(ci, pts, Color(0.16, 0.14, 0.2))
	for k in 12:
		var a := PI + PI * (k + 0.5) / 12.0
		ci.draw_circle(c + Vector2(cos(a) * w * 0.47, sin(a) * h * 0.92), 1.6, Color(1.0, 0.85, 0.5, 0.9 * glow))
	ci.draw_rect(Rect2(c.x - w * 0.5, c.y - 2, w, 4), Color(1.0, 0.8, 0.4, 0.5 * glow))


func scrap_glow(ci: CanvasItem, c: Vector2, w: float, h: float, tt: float) -> void:
	ci.draw_circle(c, w * 0.9, Color(1.0, 0.45, 0.15, 0.08 + 0.02 * sin(tt * 2.0)))
	ci.draw_circle(c, w * 0.5, Color(1.0, 0.5, 0.2, 0.1))
	var pts := PackedVector2Array([c + Vector2(-w * 0.6, 0)])
	for k in 9:
		pts.append(c + Vector2(-w * 0.6 + w * 1.2 * (k + 0.5) / 9.0, -h * (0.4 + 0.6 * hsh(k + 300)) * sin(PI * (k + 0.5) / 9.0)))
	pts.append(c + Vector2(w * 0.6, 0))
	GarageArt._pg(ci, pts, Color(0.12, 0.08, 0.07))
	crane(ci, c + Vector2(w * 0.2, 0), h * 2.2, w * 0.5, Color(0.12, 0.08, 0.07))


# ---------------------------------------------------------------- 1 the city

func draw_city(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var hz := H * 0.66
	sky(ci, W, H, Color(0.02, 0.03, 0.09), Color(0.2, 0.1, 0.25), hz)
	stars(ci, W, H, tt, 90, hz * 0.6)
	lit()
	var moon := Vector2(W * 0.84, H * 0.16)
	ci.draw_circle(moon, H * 0.09, Color(0.9, 0.9, 1.0, 0.05))
	ci.draw_circle(moon, H * 0.035, Color(0.92, 0.92, 0.85))
	ci.draw_circle(moon + Vector2(H * 0.012, -H * 0.006), H * 0.03, Color(0.86, 0.86, 0.8))
	stadium_dome(ci, Vector2(W * 0.62, hz - H * 0.13), W * 0.16, H * 0.07, tt, 1.0)
	skyline(ci, W, hz, H, tt, Color(0.09, 0.08, 0.16), Color(0.1, 0.1, 0.17), 0.3)
	# the docks: cranes along the water on the left
	for k in 4:
		crane(ci, Vector2(W * (0.03 + k * 0.07), hz), H * (0.16 + 0.03 * (k % 2)), W * 0.06, Color(0.07, 0.07, 0.12))
	# far in the right corner: the scrapyard, glowing orange
	scrap_glow(ci, Vector2(W * 0.95, hz), W * 0.12, H * 0.05, tt)
	# the sea, the city's reflection and the moon's path on the water
	ci.draw_rect(Rect2(0, hz, W, H - hz), Color(0.02, 0.03, 0.07))
	for k in 26:
		var y := hz + 6 + k * (H - hz) / 26.0
		var half := 6.0 + k * 2.2
		var wob := sin(tt * 1.7 + k * 0.9) * 5.0
		ci.draw_line(Vector2(moon.x - half + wob, y), Vector2(moon.x + half + wob, y), Color(0.85, 0.9, 1.0, 0.16 - k * 0.004), 2.0)
	for k in 60:
		var x := hsh(k + 1200) * W
		var y := hz + 4 + hsh(k + 1300) * (H - hz) * 0.8
		var len := 10.0 + hsh(k + 1400) * 40.0
		var wob := sin(tt * 1.5 + k) * 6.0
		ci.draw_line(Vector2(x + wob, y), Vector2(x + wob + len, y), Color(1.0, 0.75, 0.4, 0.12 + 0.1 * hsh(k)), 2.0)
	for k in 6:
		var y := hz + (H - hz) * (0.2 + k * 0.13)
		ci.draw_line(Vector2(0, y + sin(tt + k) * 2.0), Vector2(W, y + sin(tt * 1.3 + k) * 2.0), Color(0.3, 0.35, 0.6, 0.08), 1.0)
	ci.draw_line(Vector2(0, hz), Vector2(W, hz), Color(0.78, 0.85, 1.0, 0.25), 1.5)


# ---------------------------------------------------------------- 2 the stadium

const LEAGUE_BANNERS := [["SCRAP", "scrap", "#7a5236"], ["RUST", "rust", "#b5582a"], ["IRON", "iron", "#5f6f86"],
		["STEEL", "steel", "#9aa6b8"], ["TITANIUM", "title", "#1c1722"]]


func draw_stadium(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	sky(ci, W, H, Color(0.03, 0.03, 0.1), Color(0.2, 0.08, 0.22), H * 0.6)
	ci.draw_rect(Rect2(0, H * 0.6, W, H * 0.4), Color(0.2, 0.08, 0.22))
	stars(ci, W, H, tt, 40, H * 0.25)
	# searchlights from behind the roof, crossing
	for k in 6:
		var a := -PI / 2.0 + sin(tt * 0.55 + k * 1.3) * 0.55
		var base := Vector2(W * (0.12 + k * 0.152), H * 0.24)
		var tip := base + Vector2(cos(a), sin(a)) * H * 1.3
		ci.draw_polygon(PackedVector2Array([base, tip + Vector2(-70, 0), tip + Vector2(70, 0)]),
				PackedColorArray([Color(1.0, 0.95, 0.8, 0.12), Color(1.0, 0.95, 0.8, 0.0), Color(1.0, 0.95, 0.8, 0.0)]))
	lit()
	var eave := H * 0.3
	var crown := H * 0.23
	var bot := H * 0.86
	# the roof: a long curved shell with a row of bulbs along its lip
	var roof := PackedVector2Array()
	for k in 33:
		var f := float(k) / 32.0
		roof.append(Vector2(W * (0.01 + 0.98 * f), eave - (eave - crown) * sin(PI * f)))
	for k in range(32, -1, -1):
		var f := float(k) / 32.0
		roof.append(Vector2(W * (0.01 + 0.98 * f), eave + H * 0.045 - (eave - crown) * sin(PI * f) * 0.6))
	GarageArt._pg(ci, roof, Color(0.22, 0.21, 0.27))
	# the front wall, then its pillars
	ci.draw_polygon(PackedVector2Array([Vector2(W * 0.02, eave + H * 0.04), Vector2(W * 0.98, eave + H * 0.04), Vector2(W * 0.98, bot), Vector2(W * 0.02, bot)]),
			PackedColorArray([Color(0.09, 0.085, 0.12), Color(0.09, 0.085, 0.12), Color(0.16, 0.13, 0.17), Color(0.16, 0.13, 0.17)]))
	for px in [0.02, 0.18, 0.37, 0.63, 0.82, 0.98]:
		var pw := W * 0.026
		GarageArt._rc(ci, Rect2(W * px - pw * 0.5, eave + H * 0.03, pw, bot - eave - H * 0.03), Color(0.24, 0.22, 0.27))
	for k in 33:
		var f := (k + 0.5) / 33.0
		var p := Vector2(W * (0.01 + 0.98 * f), eave + H * 0.03 - (eave - crown) * sin(PI * f) * 0.6)
		var on := fmod(tt * 3.0 + k * 0.4, 4.0) > 0.4
		ci.draw_circle(p, 6.0, Color(1.0, 0.85, 0.45, 0.18 if on else 0.0))
		ci.draw_circle(p, 3.0, Color(1.0, 0.88, 0.5) if on else Color(0.5, 0.4, 0.2))
	# the name in red LED dots on top of the roof
	var label := I18n.t("KANE ARENA")
	var p := W * 0.27 / (label.length() * 6.0 + 2.0)
	var sw := label.length() * 6.0 * p + p * 2.0
	var sr := Rect2(W * 0.5 - sw * 0.5 - p, crown - p * 10.5, sw + p * 2.0, p * 9.0)
	GarageArt._ln(ci, Vector2(sr.position.x + sr.size.x * 0.2, sr.end.y), Vector2(sr.position.x + sr.size.x * 0.2, crown + 4), Color(0.3, 0.3, 0.34), 4.0)
	GarageArt._ln(ci, Vector2(sr.position.x + sr.size.x * 0.8, sr.end.y), Vector2(sr.position.x + sr.size.x * 0.8, crown + 4), Color(0.3, 0.3, 0.34), 4.0)
	GarageArt._rc(ci, sr.grow(4), Color(0.2, 0.2, 0.23))
	ci.draw_rect(sr, Color(0.05, 0.02, 0.02))
	ci.draw_rect(sr.grow(p * 2.0), Color(1.0, 0.2, 0.2, 0.06))
	Scoreboard.dot_text(ci, label, sr.position.x + p * 2.0, sr.position.y + p, p, sr.position.x, sr.end.x, Color(1.0, 0.25, 0.25))
	# the doors under the Titanium banner, light spilling out onto the plaza
	var door := Rect2(W * 0.42, bot - H * 0.12, W * 0.16, H * 0.12)
	ci.draw_colored_polygon(PackedVector2Array([door.position + Vector2(0, door.size.y), Vector2(door.end.x, door.end.y), Vector2(door.end.x + W * 0.12, H), Vector2(door.position.x - W * 0.12, H)]), Color(1.0, 0.85, 0.55, 0.08))
	ci.draw_rect(door, Color(1.0, 0.86, 0.58))
	ci.draw_rect(door.grow(10), Color(1.0, 0.86, 0.58, 0.08))
	for k in 4:
		GarageArt._rc(ci, Rect2(door.position.x - 7 + k * door.size.x / 3.0, door.position.y - 6, 12, door.size.y + 6), Color(0.28, 0.25, 0.22))
	GarageArt._rc(ci, Rect2(door.position.x - 12, door.position.y - 16, door.size.x + 24, 12), Color(0.3, 0.27, 0.24))
	plaza_y = bot + 6.0
	# the league banners: the ladder climbs from the outside in, the crown in the middle
	for k in 5:
		var b: Array = LEAGUE_BANNERS[k]
		var at: Array = BANNER_AT[k]
		draw_banner(ci, W * float(at[0]), H * 0.36, W * float(at[1]), H * float(at[2]), Color(str(b[2])), str(b[1]), I18n.t(str(b[0])), tt, k * 1.3, k == 4)
	# the plaza and the crowd going in
	ci.draw_rect(Rect2(0, bot, W, H - bot), Color(0.08, 0.075, 0.09))
	ci.draw_line(Vector2(0, bot), Vector2(W, bot), Color(1.0, 0.88, 0.65, 0.3), 1.5)
	for k in 70:
		var lane := hsh(k + 2000)
		var x := fmod(hsh(k) * W * 1.2 + tt * 30.0 * (1.0 if hsh(k + 3) > 0.5 else -1.0), W * 1.2) - W * 0.1
		x = lerpf(x, W * 0.5, clampf((tt - 1.0) * 0.04, 0.0, 0.3))
		var y := bot + (H - bot) * (0.2 + lane * 0.7)
		var s := 0.6 + lane * 0.6
		var c := Color.from_hsv(hsh(k + 9), 0.4, 0.25 + 0.15 * lane)
		ci.draw_rect(Rect2(x - 5 * s, y - 16 * s, 10 * s, 16 * s), c)
		ci.draw_rect(Rect2(x - 5 * s, y - 16 * s, 10 * s, 2 * s), Color(1.0, 0.88, 0.65, 0.35))
		ci.draw_circle(Vector2(x, y - 20 * s), 5 * s, Color(0.1, 0.08, 0.08))


# ---------------------------------------------------------------- the arena (dad's night, OVERLORD)

func arena_bg(ci: CanvasItem, W: float, H: float, floor_y: float, tt: float, cheer: float) -> void:
	var screen := Vector2(W, H)
	if crowd.is_empty() or crowd.size() < 2:
		crowd = Arena.make_crowd("champ_fans", screen)
	Arena.draw_ring_scene(ci, "champ_arena", "champ_fans", crowd, screen, floor_y, tt, cheer, W * 0.07, W * 0.93)


func robot_scale(look: Dictionary, tall_px: float) -> float:
	var g := RobotArt.geom(look)
	var tall: float = -(g["head"] as Rect2).position.y + 30.0
	return tall_px / tall / float(look.get("scale", 1.0))


# ---------------------------------------------------------------- 3 your dad's night (five cuts)
# Like a fight on TV: his face in the corner, fists meeting, the uppercut, the head popping off,
# then the win and his three trophies.

## A dark arena with the crowd as soft lights (bokeh), camera flashes going off.
func bokeh(ci: CanvasItem, W: float, H: float, tt: float, tint: Color) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.08))
	for k in 46:
		var p := Vector2(hsh(k + 3000) * W, hsh(k + 3100) * H * 0.85)
		var r := 10.0 + hsh(k + 3200) * 34.0
		var c := Color.from_hsv(hsh(k + 3300), 0.5, 1.0).lerp(tint, 0.5)
		ci.draw_circle(p + Vector2(sin(tt * 0.6 + k) * 6.0, 0), r, Color(c, 0.07 + 0.05 * hsh(k)))
	for k in 6:
		var at := fmod(tt * 1.7 + hsh(k + 3400) * 3.0, 3.0)
		if at < 0.08:
			var p := Vector2(hsh(k + 3500 + int(tt)) * W, hsh(k + 3600) * H * 0.6)
			ci.draw_circle(p, 26.0, Color(1, 1, 1, 0.35))
			ci.draw_circle(p, 6.0, Color(1, 1, 1, 0.9))


func speed_lines(ci: CanvasItem, c: Vector2, W: float, H: float, tt: float, alpha: float) -> void:
	for k in 40:
		var a := hsh(k + 3700) * TAU
		var r0 := W * (0.18 + 0.1 * hsh(k + 3800))
		var r1 := W * 0.9
		var d := Vector2(cos(a), sin(a))
		var flick := 0.5 + 0.5 * sin(tt * 30.0 + k * 1.7)
		ci.draw_line(c + d * r0, c + d * r1, Color(1, 1, 1, alpha * 0.18 * flick), 2.0 + hsh(k) * 3.0)


func starburst(ci: CanvasItem, c: Vector2, r: float, k: float, col: Color) -> void:
	if k <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0 + 0.13
		var rr := r * (1.0 if i % 2 == 0 else 0.42) * (0.6 + 0.4 * hsh(i + 3900))
		pts.append(c + Vector2(cos(a), sin(a)) * rr * k)
	ci.draw_colored_polygon(pts, Color(col, minf(1.0, k * 1.2)))
	ci.draw_circle(c, r * 0.28 * k, Color(1, 1, 1, minf(1.0, k * 1.4)))


func sparks(ci: CanvasItem, c: Vector2, age: float, n: int, speed: float, seed: int) -> void:
	if age < 0.0 or age > 1.2:
		return
	for i in n:
		var a := -PI + hsh(seed + i) * TAU
		var v := Vector2(cos(a), sin(a)) * speed * (0.4 + hsh(seed + i + 50))
		var p := c + v * age + Vector2(0, 900.0 * age * age)
		var tail := p - v.normalized() * 14.0
		ci.draw_line(tail, p, Color(1.0, 0.8, 0.3, 1.0 - age / 1.2), 3.0)


func shake_off(tt: float, at: float, amount: float) -> Vector2:
	var k := 1.0 - clampf((tt - at) / 0.35, 0.0, 1.0)
	if tt < at or k <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(tt * 90.0), cos(tt * 77.0)) * amount * k


## SLEDGE's TV head, on its own: the box, the screen (static once it's dead), the antennae.
func tv_head(ci: CanvasItem, c: Vector2, sz: float, rot: float, tt: float, dead: bool) -> void:
	var col: Color = looks["foe_a"]["parts"]["head"].get("color", Color(0.5, 0.2, 0.2))
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_line(Vector2(-sz * 0.2, -sz * 0.45), Vector2(-sz * 0.45, -sz * 0.95), Color(0.7, 0.7, 0.72), 3.0)
	ci.draw_line(Vector2(sz * 0.2, -sz * 0.45), Vector2(sz * 0.4, -sz * 0.95), Color(0.7, 0.7, 0.72), 3.0)
	ci.draw_rect(Rect2(-sz * 0.6, -sz * 0.45, sz * 1.2, sz * 0.9), col)
	ci.draw_rect(Rect2(-sz * 0.6, -sz * 0.45, sz * 1.2, sz * 0.9), col.darkened(0.4), false, 3.0)
	var scr := Rect2(-sz * 0.45, -sz * 0.32, sz * 0.9, sz * 0.62)
	ci.draw_rect(scr, Color(0.05, 0.06, 0.05))
	if dead:
		for i in 18:
			var y := scr.position.y + hsh(i + int(tt * 20.0) * 31) * scr.size.y
			ci.draw_rect(Rect2(scr.position.x, y, scr.size.x, 2.0), Color(0.8, 0.8, 0.8, 0.5))
	else:
		ci.draw_rect(Rect2(-sz * 0.25, -sz * 0.12, sz * 0.14, sz * 0.12), Color(1.0, 0.9, 0.3))
		ci.draw_rect(Rect2(sz * 0.11, -sz * 0.12, sz * 0.14, sz * 0.12), Color(1.0, 0.9, 0.3))
	# torn wires out of the neck
	for i in 3:
		ci.draw_line(Vector2(-sz * 0.2 + i * sz * 0.2, sz * 0.45), Vector2(-sz * 0.25 + i * sz * 0.22, sz * 0.7 + i * 4.0), [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.9, 0.8, 0.2)][i], 2.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where a robot's punching hand ends up, in screen space, for a robot drawn at base with a scale.
func hand_at(look: Dictionary, slot: String, pose: String, base: Vector2, sc: float, facing: int) -> Vector2:
	var st := RobotArt.limb_strike(look, slot, pose)
	var b: Vector2 = st["b"]
	return base + Vector2(b.x * facing, b.y) * sc * float(look.get("scale", 1.0))


func draw_dad_face(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	bokeh(ci, W, H, tt, Color(0.4, 0.5, 1.0))
	# a spotlight from above on him
	ci.draw_colored_polygon(PackedVector2Array([Vector2(W * 0.36, 0), Vector2(W * 0.2, H), Vector2(W * 0.72, H), Vector2(W * 0.5, 0)]), Color(1.0, 0.95, 0.8, 0.06))
	var c := Vector2(W * 0.42, H * 0.42)
	var r := H * 0.2
	# shoulders in the leather jacket, the collar up
	var jacket := Color(str(dad.get("outfit", "#5a3a22")))
	ci.draw_rect(Rect2(c.x - r * 1.9, c.y + r * 1.05, r * 3.8, H), jacket)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.95), c + Vector2(-r * 0.15, r * 1.5), c + Vector2(-r * 0.9, r * 1.6)]), jacket.lightened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.7, r * 0.95), c + Vector2(r * 0.15, r * 1.5), c + Vector2(r * 0.9, r * 1.6)]), jacket.lightened(0.15))
	ci.draw_rect(Rect2(c.x - r * 0.35, c.y + r * 0.75, r * 0.7, r * 0.4), Color(str(dad.get("skin", "#b07a52"))).darkened(0.1))
	# his face: eyes on the ring, jaw set, the light of the ring on one side
	var mouth := 1.5 if tt < 1.6 else 4.0 + 3.0 * absf(sin(tt * 10.0))
	PilotArt.draw_head(ci, c, r, dad, 1.0, mouth)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.22), Vector2(r * 0.6, r * 0.12)), Color(str(dad.get("beard_color", "#3a2e28"))))   # the moustache
	ci.draw_arc(c, r * 1.02, -PI * 0.45, PI * 0.35, 24, Color(1.0, 0.85, 0.55, 0.45), r * 0.08)
	# a drop of sweat running down
	var sy := fmod(tt * 0.5, 1.0)
	ci.draw_circle(c + Vector2(-r * 0.75, -r * 0.2 + sy * r * 0.8), r * 0.04, Color(0.8, 0.9, 1.0, 0.7))
	# the stick in his hands, its light magenta
	var stick := Vector2(W * 0.68, H * 0.8)
	var s := H / 75.0
	PilotArt.draw_controller(ci, stick, s, str(dad.get("controller", "arcade")), true, tt)
	var skin := Color(str(dad.get("skin", "#b07a52")))
	var jab := sin(tt * 22.0) * 4.0 * s if tt > 1.4 else 0.0
	ci.draw_circle(stick + Vector2(-14 * s, -6 * s + jab), 3.6 * s, skin)
	ci.draw_circle(stick + Vector2(12 * s, -5 * s - jab), 3.6 * s, skin)
	ci.draw_circle(stick + Vector2(-6 * s, 2 * s), 3 * s, Color("#ff00aa", 0.25 + 0.15 * sin(tt * 6.0)))
	ci.draw_circle(stick + Vector2(-6 * s, 2 * s), 1.2 * s, Color("#ff00aa"))


func draw_dad_clash(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var hit := 0.75
	var sh := shake_off(tt, hit, 14.0)
	bokeh(ci, W, H, tt, Color(1.0, 0.6, 0.3))
	var mid := Vector2(W * 0.5, H * 0.45) + sh
	speed_lines(ci, mid, W, H, tt, 1.0 if tt > hit else tt / hit)
	var echo: Dictionary = looks["echo_dad"]
	var foe: Dictionary = looks["foe_a"]
	var tall := H * 1.3
	var se := robot_scale(echo, tall)
	var sf := robot_scale(foe, tall)
	# they lunge in from the sides, fists meeting in the middle at the hit, then bounce apart
	var k := clampf(tt / hit, 0.0, 1.0)
	var apart := (1.0 - k * k) * W * 0.25 + maxf(0.0, tt - hit) * W * 0.12
	var ext := tt > hit - 0.12
	var pose := "punch" if ext else "guard"
	var he := hand_at(echo, "arm_front", "punch", Vector2.ZERO, se, 1)
	var hf := hand_at(foe, "arm_front", "punch", Vector2.ZERO, sf, -1)
	var be := mid - he - Vector2(apart, 0)
	var bf := mid - hf + Vector2(apart, 0)
	RobotArt.draw(ci, bf, foe, {"light": shot_light(), "scale": sf, "facing": -1, "time": tt, "state": "punch", "attack_limb": "arm_front", "extended": ext})
	RobotArt.draw(ci, be, echo, {"light": shot_light(), "scale": se, "facing": 1, "time": tt, "state": "punch", "attack_limb": "arm_front", "extended": ext})
	var f := 1.0 - clampf((tt - hit) / 0.5, 0.0, 1.0)
	if tt >= hit:
		starburst(ci, mid, H * 0.42, f, Color(1.0, 0.85, 0.4))
		sparks(ci, mid, tt - hit, 26, 900.0, 4000)
		ci.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.5 * maxf(0.0, f - 0.5)))


func draw_dad_uppercut(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	# one continuous shot: ECHO dips, drives the uppercut through SLEDGE's chin, the TV head pops off
	# and spins up into the lights in slow motion while the headless body staggers back
	var hit := 0.9
	var sh := shake_off(tt, hit, 16.0)
	var floor_y := H * 0.86
	arena_bg(ci, W, H, floor_y, tt, 1.0)
	var echo: Dictionary = looks["echo_dad"]
	var foe: Dictionary = looks["foe_a"].duplicate(true)
	var tall := H * 0.6
	var se := robot_scale(echo, tall)
	var sf := robot_scale(foe, tall)
	var fk := sf * float(foe.get("scale", 1.0))
	var after := maxf(0.0, tt - hit)
	var dip := clampf(tt / 0.6, 0.0, 1.0) * (1.0 - clampf((tt - 0.72) / 0.14, 0.0, 1.0))
	var ext := tt > hit - 0.12 and tt < hit + 2.4
	var eb := Vector2(W * 0.4, floor_y + 6.0 + dip * 12.0) + sh
	if tt > hit:
		speed_lines(ci, Vector2(W * 0.55, H * 0.25), W, H, tt, 1.0 - clampf(after / 1.2, 0.0, 0.8))
	# SLEDGE stands where the fist comes up under its chin
	var fist := hand_at(echo, "arm_back", "uppercut", Vector2(W * 0.4, floor_y + 6.0), se, 1)
	var g := RobotArt.geom(foe)
	var hr: Rect2 = g["head"]
	var fb := Vector2(fist.x + hr.get_center().x * fk + 6.0, floor_y + 6.0)
	var stagger := minf(1.0, after * 0.8)
	fb += Vector2(stagger * W * 0.06, 0) + sh
	var neck := fb + Vector2(-hr.get_center().x * fk, (hr.end.y) * fk)
	if tt < hit:
		RobotArt.draw(ci, fb, foe, {"light": shot_light(), "scale": sf, "facing": -1, "time": tt, "state": "punch", "attack_limb": "arm_front", "extended": tt > 0.45 and tt < 0.75})
	else:
		foe["parts"]["head"]["alive"] = false
		RobotArt.draw(ci, fb, foe, {"light": shot_light(), "scale": sf, "facing": -1, "time": tt, "state": "hit", "rot": stagger * 0.3, "eye_off": true})
	RobotArt.draw(ci, eb, echo, {"light": shot_light(), "scale": se, "facing": 1, "time": tt, "state": "uppercut" if ext else "idle", "attack_limb": "arm_back",
			"extended": ext, "crouch": dip > 0.5 and not ext})
	if tt < hit:
		return
	# the neck spits sparks and smoke
	for i in 3:
		sparks(ci, neck, fmod(after * 1.5 + i * 0.33, 1.0), 8, 400.0, 4200 + i * 40)
	for i in 5:
		var a := fmod(after * 0.8 + i * 0.2, 1.0)
		ci.draw_circle(neck + Vector2(sin(i * 2.0 + tt) * 20.0, -a * H * 0.25), 12.0 + a * 26.0, Color(0.2, 0.2, 0.22, 0.4 * (1.0 - a)))
	# the head: fast off the fist, then slow motion up into the lights, spinning, with a trail
	var ht := minf(after, 0.12) * 1.2 + maxf(0.0, after - 0.12) * 0.3
	var start := Vector2(fist.x + 4.0, neck.y - hr.size.y * fk * 0.5)
	var hpos := func(u: float) -> Vector2: return start + Vector2(W * 0.2 * u, -H * 0.8 * u + H * 0.6 * u * u)
	var hs := hr.size.x * fk * 1.7
	for i in 7:
		var pt := maxf(0.0, ht - i * 0.035)
		ci.draw_circle(hpos.call(pt), hs * 0.3 * (1.0 - i / 7.0), Color(1.0, 0.8, 0.4, 0.15))
	tv_head(ci, hpos.call(ht), hs, after * 4.5, tt, true)
	# the impact: a starburst at the chin, sparks, a white flash
	var f := 1.0 - clampf(after / 0.45, 0.0, 1.0)
	starburst(ci, start, H * 0.3, f, Color(1.0, 0.75, 0.3))
	sparks(ci, start, after, 24, 820.0, 4100)
	ci.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.45 * maxf(0.0, f - 0.4)))


func draw_dad_win(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var floor_y := H * 0.8
	arena_bg(ci, W, H, floor_y, tt, 1.0)
	var br := Rect2(W * 0.4, H * 0.19, W * 0.2, H * 0.08)
	ci.draw_rect(br.grow(3), Color(0.1, 0.1, 0.11))
	ci.draw_rect(br, Color(0.05, 0.01, 0.01))
	var word: String = I18n.t("WINNER") if fmod(tt, 0.8) < 0.55 else GameData.robot_name.to_upper()
	var p := br.size.y / 9.0
	var tw: float = (word.length() * 6 - 1) * p
	Scoreboard.dot_text(ci, word, br.get_center().x - tw * 0.5, br.position.y + p, p, br.position.x, br.end.x, Color(1.0, 0.3, 0.2))
	var tall := H * 0.42
	# SLEDGE flat on its back without a head; the TV lies by the ropes, still fizzing
	var foe: Dictionary = looks["foe_a"].duplicate(true)
	foe["parts"]["head"]["alive"] = false
	RobotArt.draw(ci, Vector2(W * 0.68, floor_y - 6), foe, {"light": shot_light(), "scale": robot_scale(foe, tall), "facing": -1, "time": tt, "state": "ko", "rot": 1.4, "eye_off": true})
	tv_head(ci, Vector2(W * 0.86, floor_y - 18), 34.0, 0.4, tt, true)
	# ECHO, the fist up
	RobotArt.draw(ci, Vector2(W * 0.42, floor_y + 6), looks["echo_dad"], {"light": shot_light(), "scale": robot_scale(looks["echo_dad"], tall), "facing": 1, "time": tt,
			"state": "uppercut", "attack_limb": "arm_back", "extended": true})
	# your dad in the corner, both arms up
	var df := Vector2(W * 0.12, floor_y + H * 0.17)
	var ds := H / 260.0
	PilotArt.draw_person(ci, df, ds, dad, 1.0, "cheer", tt)
	# confetti
	for i in 60:
		var x := fmod(hsh(i + 4400) * W + sin(tt * 2.0 + i) * 20.0, W)
		var y := fmod(hsh(i + 4500) * H + tt * (120.0 + 80.0 * hsh(i)), H)
		ci.draw_rect(Rect2(x, y, 5, 3), Color.from_hsv(hsh(i + 4600), 0.7, 1.0, 0.8))
	# his three trophies rise, one after another
	for k in 3:
		var at := 0.8 + k * 0.5
		if tt < at:
			continue
		var rise := clampf((tt - at) / 0.35, 0.0, 1.0)
		var base := Vector2(W * (0.39 + k * 0.11), H * 0.52 + (1.0 - rise) * 30.0)
		ci.draw_circle(base + Vector2(0, -36), 52.0, Color(1.0, 0.9, 0.5, 0.12 * rise))
		GarageArt.draw_trophy(ci, base, ["scrap", "rust", "iron"][k], [1, 1, 2][k], 3.2)


# ---------------------------------------------------------------- 4 OVERLORD

func kane_face(ci: CanvasItem, c: Vector2, r: float, tt: float) -> void:
	var mouth := 3.0 + (5.0 * absf(sin(tt * 14.0)) if fmod(tt, 3.0) < 1.6 else 0.0)
	ci.draw_rect(Rect2(c.x - r * 1.2, c.y + r * 0.95, r * 2.4, r), Color(0.15, 0.15, 0.2))
	ci.draw_circle(c + Vector2(0, -r * 0.15), r * 1.05, Color(0.08, 0.08, 0.1))
	ci.draw_circle(c, r * 0.85, Color(0.93, 0.8, 0.72))
	ci.draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.9, r * 1.9, r * 0.5), Color(0.08, 0.08, 0.1))
	ci.draw_line(c + Vector2(-r * 0.5, -r * 0.15), c + Vector2(-r * 0.15, -r * 0.05), Color.BLACK, 3.0)
	ci.draw_line(c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.15, -r * 0.05), Color.BLACK, 3.0)
	ci.draw_rect(Rect2(c.x - r * 0.25, c.y + r * 0.35, r * 0.5, mouth * 0.7), Color(0.75, 0.1, 0.2))


func draw_overlord(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var floor_y := H * 0.8
	arena_bg(ci, W, H, floor_y, tt, 0.15)
	# the house lights go red
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.5, 0.0, 0.05, 0.28 + 0.06 * sin(tt * 4.0)))
	lit()
	# Kane on the big screen
	var scr := Rect2(W * 0.4, H * 0.12, W * 0.2, H * 0.26)
	GarageArt._rc(ci, scr.grow(8), Color(0.16, 0.16, 0.18))
	ci.draw_rect(scr, Color(0.12, 0.05, 0.08))
	ci.draw_rect(scr.grow(24), Color(1.0, 0.3, 0.35, 0.05))
	kane_face(ci, scr.get_center() + Vector2(0, -scr.size.y * 0.08), scr.size.y * 0.24, tt)
	var sl := scr.position.y
	while sl < scr.end.y:
		ci.draw_line(Vector2(scr.position.x, sl), Vector2(scr.end.x, sl), Color(0, 0, 0, 0.25), 1.0)
		sl += 3.0
	ci.draw_string(GUI.headb(), Vector2(scr.position.x, scr.end.y - 6), "KANE DYNAMICS", HORIZONTAL_ALIGNMENT_CENTER, scr.size.x, 12, Color(1.0, 0.4, 0.45))
	# the piloted robot on the left, its pilot in the corner
	var tall := H * 0.4
	var hit1 := tt >= 5.0
	var hit2 := tt >= 6.6
	var fl: Dictionary = looks["foe_b"].duplicate(true)
	if hit1:
		fl["parts"]["arm_front"]["alive"] = false
	var fall := clampf((tt - 6.6) / 0.5, 0.0, 1.0)
	RobotArt.draw(ci, Vector2(W * 0.36 - fall * 40.0, floor_y + 6 - fall * 8.0), fl, {"light": shot_light(), "scale": robot_scale(fl, tall), "facing": 1, "time": tt,
			"state": "hit" if hit1 else "idle", "blocking": tt > 3.5 and not hit1, "rot": -fall * 1.4, "eye_off": hit2})
	PilotArt.draw_person(ci, Vector2(W * 0.1, floor_y + H * 0.17), H / 260.0, {"skin": "#b07850", "hair": "#3b1f14", "hat": "bun", "outfit": "#8e2c1c", "long_hair": true, "female": true},
			1.0, "hold" if not hit2 else "idle", tt)
	lit()
	# the arm that came off, flying
	if hit1:
		var k := tt - 5.0
		var p := Vector2(W * 0.4 - k * 260.0, floor_y - tall * 0.6 - 500.0 * k + 900.0 * k * k)
		var arm_c := Color(0.25, 0.37, 0.56)
		if p.y < floor_y:
			ci.draw_set_transform(p, k * 9.0, Vector2.ONE)
			GarageArt._rc(ci, Rect2(-30, -9, 60, 18), arm_c)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			GarageArt._rc(ci, Rect2(p.x - 30, floor_y - 12, 60, 14), arm_c)
	# OVERLORD walks in from the right, alone: nobody in its corner
	var walk := clampf(tt / 3.2, 0.0, 1.0)
	var ox := lerpf(W * 1.1, W * 0.6, walk)
	var lunge := (1.0 if (tt > 4.8 and tt < 5.3) or (tt > 6.4 and tt < 6.9) else 0.0)
	var ol: Dictionary = looks["overlord"]
	RobotArt.draw(ci, Vector2(ox - lunge * 40.0, floor_y + 6), ol, {"light": shot_light(), "scale": robot_scale(ol, H * 0.52), "facing": -1, "time": tt,
			"state": "punch" if lunge > 0.0 else "idle", "attack_limb": "arm_front" if tt < 6.0 else "arm_back", "extended": lunge > 0.0,
			"swing": sin(tt * 6.0) * 0.4 if walk < 1.0 else 0.0})
	lit()
	# its empty corner: a pilot's stool and nobody on it
	var stool := Vector2(W * 0.9, floor_y + H * 0.16)
	GarageArt._ln(ci, stool + Vector2(-12, -20), stool + Vector2(-14, 0), Color(0.3, 0.3, 0.32), 3.0)
	GarageArt._ln(ci, stool + Vector2(12, -20), stool + Vector2(14, 0), Color(0.3, 0.3, 0.32), 3.0)
	GarageArt._rc(ci, Rect2(stool + Vector2(-17, -27), Vector2(34, 8)), Color(0.34, 0.34, 0.36))
	# the hits: a flash
	for at in [5.0, 6.6]:
		var f := 1.0 - clampf((tt - at) / 0.25, 0.0, 1.0)
		if tt >= at and f > 0.0:
			ci.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.35 * f))
			ci.draw_circle(Vector2(W * 0.42, floor_y - tall * 0.6), 60.0 * (1.2 - f), Color(1.0, 0.8, 0.4, 0.7 * f))


# ---------------------------------------------------------------- 5 the fall

const BOARD_NAMES := ["", "HAMMERHEAD", "JUGGERNAUT", "RIVET", "VOLTAGE", "SLEDGE", "TIN CAN"]


func draw_fall(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(0.05, 0.055, 0.07), Color(0.05, 0.055, 0.07), Color(0.1, 0.1, 0.12), Color(0.1, 0.1, 0.12)]))
	lit()
	# up top: the board of pilot licences, names going dark one by one (your dad's first)
	var b := Rect2(W * 0.25, H * 0.06, W * 0.5, H * 0.46)
	var fc := Color(0.34, 0.35, 0.38)
	ci.draw_rect(b, Color(0.04, 0.04, 0.05))
	GarageArt._rc(ci, Rect2(b.position.x - 12, b.position.y - 12, b.size.x + 24, 12), fc)
	GarageArt._rc(ci, Rect2(b.position.x - 12, b.end.y, b.size.x + 24, 12), fc)
	GarageArt._rc(ci, Rect2(b.position.x - 12, b.position.y, 12, b.size.y), fc)
	GarageArt._rc(ci, Rect2(b.end.x, b.position.y, 12, b.size.y), fc)
	ci.draw_string(GUI.headb(), Vector2(b.position.x, b.position.y + 26), I18n.t("PILOT LICENCES"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 20, Color(0.9, 0.9, 0.9))
	var row_h := (b.size.y - 44.0) / BOARD_NAMES.size()
	for k in BOARD_NAMES.size():
		var r := Rect2(b.position.x + 14, b.position.y + 38 + k * row_h, b.size.x - 28, row_h - 6)
		var name: String = GameData.robot_name.to_upper() if k == 0 else BOARD_NAMES[k]
		var gone := tt > 0.8 + k * 0.55
		if gone:
			ci.draw_rect(r, Color(0.02, 0.02, 0.02))
			ci.draw_string(GUI.headb(), Vector2(r.position.x, r.get_center().y + 7), I18n.t("REVOKED"), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 18, Color(0.85, 0.15, 0.15))
			ci.draw_rect(Rect2(r.end.x - 120, r.position.y, 120, r.size.y), Color(0.85, 0.15, 0.15, 0.06))
		else:
			Scoreboard.flap_row(ci, Rect2(r.position, Vector2(r.size.x * 0.7, r.size.y)), name, GUI.headb(), Color(1, 1, 1))
	# below: the controllers dropped in a Kane bin, and your dad's empty chair with his helmet on it
	var floor_y := H * 0.95
	ci.draw_rect(Rect2(0, floor_y, W, H - floor_y), Color(0.06, 0.06, 0.07))
	ci.draw_line(Vector2(0, floor_y), Vector2(W, floor_y), Color(0.75, 0.82, 0.95, 0.25), 1.5)
	var chair := Vector2(W * 0.62, floor_y)
	# a single lamp over the chair: its cable, its shade, the cone of light and the pool on the floor
	var lamp := chair + Vector2(-4, -H * 0.36)
	ci.draw_line(Vector2(lamp.x, H * 0.55), lamp, Color(0.2, 0.2, 0.22), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-8, 0), lamp + Vector2(8, 0), chair + Vector2(90, 0), chair + Vector2(-100, 0)]), Color(0.85, 0.9, 1.0, 0.07))
	ci.draw_set_transform(chair, 0.0, Vector2(1.0, 0.16))
	ci.draw_circle(Vector2.ZERO, 110.0, Color(0.85, 0.9, 1.0, 0.08))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GarageArt._pg(ci, PackedVector2Array([lamp + Vector2(-6, -10), lamp + Vector2(6, -10), lamp + Vector2(16, 2), lamp + Vector2(-16, 2)]), Color(0.3, 0.32, 0.36))
	ci.draw_circle(lamp + Vector2(0, 4), 5.0, Color(1.0, 0.97, 0.88))
	ci.draw_circle(lamp + Vector2(0, 4), 12.0, Color(1.0, 0.97, 0.88, 0.15))
	var bin := Rect2(W * 0.3, floor_y - H * 0.16, W * 0.14, H * 0.16)
	GarageArt._rc(ci, bin, Color(0.25, 0.27, 0.3))
	for k in 3:
		ci.draw_line(Vector2(bin.position.x + bin.size.x * (0.25 + k * 0.25), bin.position.y + 12), Vector2(bin.position.x + bin.size.x * (0.25 + k * 0.25), bin.end.y - 6), Color(0.18, 0.19, 0.22), 2.0)
	ci.draw_string(GUI.headb(), Vector2(bin.position.x, bin.get_center().y + 6), "KANE", HORIZONTAL_ALIGNMENT_CENTER, bin.size.x, 16, Color(1.0, 0.3, 0.35))
	for k in 5:
		var at := 4.0 + k * 0.7
		if tt < at:
			continue
		var f := clampf((tt - at) / 0.6, 0.0, 1.0)
		var p := Vector2(bin.get_center().x + (hsh(k) - 0.5) * 40.0, lerpf(H * 0.58, bin.position.y + 6, f * f))
		PilotArt.draw_controller(ci, p, 1.3, PilotArt.CONTROLLERS[k % PilotArt.CONTROLLERS.size()], false, tt)
	lit()
	GarageArt._rc(ci, Rect2(bin.position - Vector2(6, 6), Vector2(bin.size.x + 12, 10)), Color(0.36, 0.38, 0.41))
	var wood := Color(0.38, 0.24, 0.15)
	GarageArt._ln(ci, chair + Vector2(-22, -40), chair + Vector2(-22, 0), wood.darkened(0.15), 5.0)
	GarageArt._ln(ci, chair + Vector2(22, -40), chair + Vector2(22, 0), wood.darkened(0.15), 5.0)
	GarageArt._rc(ci, Rect2(chair + Vector2(20, -104), Vector2(10, 64)), wood)
	GarageArt._rc(ci, Rect2(chair + Vector2(-28, -50), Vector2(58, 10)), wood)
	# the helmet on the seat, the pad on the floor, its light still magenta
	GarageArt._cr(ci, chair + Vector2(-4, -64), 16.0, Color(0.2, 0.3, 0.5))
	GarageArt._rc(ci, Rect2(chair + Vector2(-20, -68), Vector2(32, 8)), Color(0.1, 0.1, 0.12))
	ci.draw_circle(chair + Vector2(-60, -6), 4.0, Color("#ff00aa", 0.5 + 0.5 * sin(tt * 3.0)))
	PilotArt.draw_controller(ci, chair + Vector2(-60, -2), 1.2, str(dad.get("controller", "arcade")), false, tt)


# ---------------------------------------------------------------- 6 the scrapyard

func draw_scrap(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var floor_y := H * 0.82
	var hz := floor_y - H * 0.2
	sky(ci, W, H, Color(0.1, 0.12, 0.28), Color(0.98, 0.58, 0.32), hz)
	ci.draw_rect(Rect2(0, hz, W, floor_y - hz), Color(0.98, 0.58, 0.32))
	# the sun going down behind the heaps on the right (the key light of this shot)
	var sun := Vector2(W * 0.86, hz - H * 0.02)
	ci.draw_circle(sun, H * 0.2, Color(1.0, 0.7, 0.4, 0.12))
	ci.draw_circle(sun, H * 0.11, Color(1.0, 0.78, 0.5, 0.2))
	ci.draw_circle(sun, H * 0.055, Color(1.0, 0.9, 0.65))
	# far off: the city and the stadium in the haze
	stadium_dome(ci, Vector2(W * 0.2, hz - H * 0.04), W * 0.08, H * 0.035, tt, 0.4)
	ci.draw_set_transform(Vector2(-W * 0.12, 0), 0.0, Vector2.ONE)
	skyline(ci, W * 0.62, hz, H * 0.5, tt, Color(0.62, 0.4, 0.42), Color(0.55, 0.34, 0.38), 0.05)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# far heaps, flat in the haze, with a dead robot or two on the ridge
	var ridge := PackedVector2Array([Vector2(0, floor_y)])
	for i in 25:
		var f := float(i) / 24.0
		ridge.append(Vector2(W * f, hz + H * 0.05 - H * (0.06 + 0.06 * hsh(i + 800)) * (0.6 + 0.4 * sin(f * 9.0 + 1.0))))
	ridge.append(Vector2(W, floor_y))
	ci.draw_colored_polygon(ridge, Color(0.42, 0.24, 0.27))
	for i in 5:
		var rx := W * (0.08 + i * 0.21 + hsh(i + 820) * 0.05)
		var ry := hz - H * 0.02
		ci.draw_rect(Rect2(rx, ry - 10, 14, 12), Color(0.42, 0.24, 0.27))
		ci.draw_line(Vector2(rx + 7, ry), Vector2(rx + 18 + hsh(i) * 10, ry - 16), Color(0.42, 0.24, 0.27), 4.0)
	ci.draw_polygon(PackedVector2Array([Vector2(0, hz - H * 0.05), Vector2(W, hz - H * 0.05), Vector2(W, floor_y), Vector2(0, floor_y)]),
			PackedColorArray([Color(1.0, 0.6, 0.35, 0.0), Color(1.0, 0.6, 0.35, 0.0), Color(1.0, 0.6, 0.35, 0.3), Color(1.0, 0.6, 0.35, 0.3)]))
	lit()
	# the crane and its hook: the lever pulls at 2.6 s, the hook takes the tarp up from 3.0 s
	var rc := Vector2(W * 0.5, floor_y + 4)
	var tall := H * 0.4
	var ease := clampf((tt - 3.0) / 2.0, 0.0, 1.0)
	ease = ease * ease * (3.0 - 2.0 * ease)
	var lift := ease * H * 0.27
	var sway := sin((tt - 3.6) * 2.6) * 26.0 * exp(-maxf(0.0, tt - 4.2) * 0.45) if tt > 3.6 else 0.0
	var peak := Vector2(rc.x + sway * 0.25, floor_y - tall * 1.04 - lift)
	var jib_y := H * 0.1
	big_crane(ci, Vector2(W * 0.69, floor_y), jib_y, W * 0.26, peak + Vector2(0, -10), Color(0.72, 0.5, 0.16), tt)
	# the heaps on either side
	GarageArt._scrap_pile(ci, Vector2(W * 0.12, floor_y), W * 0.3, H * 0.34, tt)
	GarageArt._scrap_pile(ci, Vector2(W * 0.95, floor_y), W * 0.28, H * 0.42, tt + 3.0)
	# the ground: packed dirt and oil, junk lying about
	ci.draw_polygon(PackedVector2Array([Vector2(0, floor_y), Vector2(W, floor_y), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(0.36, 0.25, 0.19), Color(0.36, 0.25, 0.19), Color(0.16, 0.11, 0.1), Color(0.16, 0.11, 0.1)]))
	ci.draw_line(Vector2(0, floor_y), Vector2(W, floor_y), Color(1.0, 0.72, 0.42, 0.4), 1.5)
	ci.draw_set_transform(Vector2(W * 0.64, floor_y + H * 0.08), 0.0, Vector2(1.0, 0.2))
	ci.draw_circle(Vector2.ZERO, W * 0.07, Color(0.08, 0.06, 0.08))
	ci.draw_circle(Vector2(W * 0.01, -W * 0.01), W * 0.05, Color(0.98, 0.58, 0.32, 0.25))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GarageArt._cr(ci, Vector2(W * 0.08, floor_y + H * 0.1), 18.0, Color(0.12, 0.12, 0.13))
	GarageArt._cr(ci, Vector2(W * 0.08, floor_y + H * 0.1), 7.0, Color(0.4, 0.38, 0.36))
	GarageArt._pg(ci, PackedVector2Array([Vector2(W * 0.38, floor_y + H * 0.12), Vector2(W * 0.43, floor_y + H * 0.1), Vector2(W * 0.44, floor_y + H * 0.13), Vector2(W * 0.39, floor_y + H * 0.15)]), Color(0.45, 0.35, 0.3))
	GarageArt._rc(ci, Rect2(W * 0.88, floor_y + H * 0.02, 34, 46), Color(0.55, 0.22, 0.14))
	# the work lamp on the crane clicks on at 7.2 s and lights ECHO up
	var lamp := Vector2(W * 0.69 - 22.0, floor_y - H * 0.44)
	var lamp_on := tt > 7.2 and not (tt < 7.6 and fmod(tt, 0.12) < 0.06)
	if lamp_on:
		ci.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-4, -8), rc + Vector2(-tall * 0.55, 0), rc + Vector2(tall * 0.5, 0), lamp + Vector2(-4, 8)]), Color(1.0, 0.95, 0.8, 0.09))
		ci.draw_set_transform(rc, 0.0, Vector2(1.0, 0.18))
		ci.draw_circle(Vector2.ZERO, tall * 0.6, Color(1.0, 0.95, 0.8, 0.12))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ECHO
	var look: Dictionary = looks["echo_rust"].duplicate(true)
	var eye_on := tt > 8.0 and not (tt < 8.6 and fmod(tt, 0.15) < 0.07)
	if not eye_on:
		look["eye"] = Color(0.12, 0.1, 0.1)
	var sc := robot_scale(look, tall)
	RobotArt.draw(ci, rc, look, {"light": shot_light(), "scale": sc, "facing": 1, "time": tt, "state": "hit" if tt < 9.0 else "idle", "eye_off": not eye_on})
	var g := RobotArt.geom(look)
	var hc: Vector2 = (g["head"] as Rect2).get_center() * sc * float(look.get("scale", 1.0))
	if eye_on:
		ci.draw_circle(rc + hc, 26.0, Color(look["eye"], 0.18 + 0.1 * sin(tt * 5.0)))
	lit()
	# dust as the tarp comes off, rust flakes after
	if tt > 3.0 and tt < 6.0:
		var a := tt - 3.0
		for i in 14:
			var px := rc.x + (hsh(i + 400) - 0.5) * tall * 1.4 * (0.6 + a * 0.4)
			var py := floor_y - 6.0 - a * 18.0 * hsh(i + 410)
			ci.draw_circle(Vector2(px, py), 8.0 + a * 10.0 * hsh(i + 420), Color(0.75, 0.6, 0.45, 0.22 * (1.0 - a / 3.0)))
	if tt > 3.6 and tt < 9.0:
		for i in 16:
			var start := 3.6 + hsh(i + 500) * 2.5
			var a := tt - start
			if a > 0.0 and a < 1.6:
				var px := rc.x + (hsh(i + 510) - 0.5) * tall * 0.5 + sin(a * 4.0 + i) * 4.0
				var py := floor_y - tall * (0.4 + 0.5 * hsh(i + 520)) + a * a * 140.0
				if py < floor_y:
					ci.draw_rect(Rect2(px, py, 3, 3), Color(0.6, 0.32, 0.15))
	# the tarp, hooked to the crane
	draw_tarp(ci, peak, floor_y, tall * 0.42, tall, lift, sway, tt)
	# the work lamp itself
	GarageArt._rc(ci, Rect2(lamp + Vector2(-8, -12), Vector2(26, 24)), Color(0.3, 0.3, 0.32))
	ci.draw_circle(lamp + Vector2(-8, 0), 8.0, Color(1.0, 0.97, 0.85) if lamp_on else Color(0.35, 0.33, 0.3))
	if lamp_on:
		ci.draw_circle(lamp + Vector2(-8, 0), 20.0, Color(1.0, 0.95, 0.8, 0.2))
	# you on the left, watching; Gus at the crane's controls, pulling the lever
	var s := H / 240.0
	var you_at := Vector2(W * 0.3, floor_y)
	var gus_at := Vector2(W * 0.8, floor_y)
	var box := Rect2(gus_at + Vector2(-27 * s, -20 * s), Vector2(16 * s, 20 * s))
	GarageArt._rc(ci, box, Color(0.42, 0.42, 0.4))
	ci.draw_rect(Rect2(box.position + Vector2(3 * s, 5 * s), Vector2(4 * s, 3 * s)), Color(0.3, 1.0, 0.4) if tt > 2.6 else Color(1.0, 0.3, 0.2))
	ci.draw_rect(Rect2(box.position + Vector2(9 * s, 5 * s), Vector2(4 * s, 3 * s)), Color(1.0, 0.75, 0.2))
	var pull := clampf((tt - 2.6) / 0.4, 0.0, 1.0)
	var ang := lerpf(-0.45, 0.5, pull)
	var pivot := Vector2(box.get_center().x, box.position.y)
	var grip := pivot + Vector2(sin(ang), -cos(ang)) * 14.0 * s
	GarageArt._ln(ci, pivot, grip, Color(0.5, 0.5, 0.52), 3.0)
	GarageArt._cr(ci, grip, 3.0 * s, Color(0.85, 0.15, 0.12))
	PilotArt.grab_at = grip
	PilotArt.draw_person(ci, you_at, s, you, 1.0, "point" if tt > 8.3 else "idle", tt)
	PilotArt.draw_person(ci, gus_at, s, PilotArt.GUS_LOOK, -1.0, "grab" if tt < 6.0 else "idle", tt)
	heads["GUS"] = gus_at + Vector2(0, -68 * s)
	heads["ECHO"] = rc + Vector2(0, -tall * 0.9)
	ci.draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.6, 0.3, 0.05))


# ---------------------------------------------------------------- 7 the road

const RUNGS := ["GUTTER", "SCRAP", "RUST", "IRON", "STEEL", "TITANIUM"]


func draw_road(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var floor_y := H * 0.84
	var hz := floor_y - H * 0.15
	sky(ci, W, H, Color(0.05, 0.06, 0.16), Color(0.55, 0.3, 0.35), hz)
	ci.draw_rect(Rect2(0, hz, W, H * 0.15), Color(0.55, 0.3, 0.35))
	stars(ci, W, H, tt, 40, H * 0.3)
	lit()
	# Kane Hill: the stadium sits on top of the city, the stair climbs to its doors
	var top_lit := clampf((tt - (1.6 + 5 * 1.1)) / 0.5, 0.0, 1.0)
	var dome := Vector2(W * 0.82, H * 0.27)
	var hill := PackedVector2Array([Vector2(W * 0.5, hz), Vector2(W * 0.6, H * 0.5), Vector2(W * 0.68, H * 0.37), Vector2(W * 0.74, H * 0.3),
			Vector2(W * 0.92, H * 0.3), Vector2(W * 1.02, H * 0.38), Vector2(W * 1.02, hz)])
	GarageArt._pg(ci, hill, Color(0.17, 0.12, 0.2))
	for i in 40:
		var hx := W * (0.56 + hsh(i + 600) * 0.44)
		var hy := lerpf(H * 0.34, hz, hsh(i + 610))
		if Geometry2D.is_point_in_polygon(Vector2(hx, hy), hill):
			ci.draw_rect(Rect2(hx, hy, 3, 3), Color(1.0, 0.8, 0.45, 0.6))
	stadium_dome(ci, dome, W * 0.15, H * 0.06, tt, 1.0 + top_lit * (0.6 + 0.3 * sin(tt * 4.0)))
	skyline(ci, W, hz, H * 0.6, tt, Color(0.2, 0.14, 0.24), Color(0.15, 0.11, 0.19), 0.2)
	GarageArt._scrap_pile(ci, Vector2(W * 0.2, floor_y), W * 0.45, H * 0.28, tt)
	ci.draw_polygon(PackedVector2Array([Vector2(0, floor_y), Vector2(W, floor_y), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(0.24, 0.18, 0.15), Color(0.24, 0.18, 0.15), Color(0.12, 0.09, 0.09), Color(0.12, 0.09, 0.09)]))
	ci.draw_line(Vector2(0, floor_y), Vector2(W, floor_y), Color(1.0, 0.75, 0.55, 0.35), 1.5)
	# the ladder: a stair of light from the top of the scrap heap up to the stadium, one step a league,
	# lit step by step. It only ever climbs.
	var a := Vector2(W * 0.26, floor_y - H * 0.29)
	var b := Vector2(W * 0.76, dome.y + H * 0.03)
	var n := RUNGS.size()
	var dx := (b.x - a.x) / n
	for k in n:
		var at := 1.6 + k * 1.1
		var lt := clampf((tt - at) / 0.4, 0.0, 1.0)
		var y := lerpf(a.y, b.y, float(k) / (n - 1))
		var x0 := a.x + dx * k
		var x1 := x0 + dx
		var gold := Color(1.0, 0.85, 0.4)
		# the riser up from the step below
		if k > 0:
			var py := lerpf(a.y, b.y, float(k - 1) / (n - 1))
			ci.draw_line(Vector2(x0, py), Vector2(x0, y), Color(gold, 0.2 + 0.7 * lt), 4.0)
		# the step: dark until it's reached, then glowing
		ci.draw_rect(Rect2(x0, y - 3, dx, 9), Color(0.2, 0.17, 0.15) if lt <= 0.0 else Color(gold, 0.3 + 0.7 * lt))
		ci.draw_rect(Rect2(x0, y + 4, dx, 2), Color(0.5, 0.32, 0.12, 0.8 * lt))
		ci.draw_rect(Rect2(x0, y - 3, dx, 9), Color(0.08, 0.06, 0.05), false, 1.5)
		if lt > 0.0:
			ci.draw_rect(Rect2(x0 - 6, y - 10, dx + 12, 20), Color(1.0, 0.8, 0.35, 0.1 * lt))
			ci.draw_string(GUI.headb(), Vector2(x0 - 20, y - 14), I18n.t(RUNGS[k]), HORIZONTAL_ALIGNMENT_CENTER, dx + 40, 14 if k < n - 1 else 18, Color(1, 1, 1, lt) if k < n - 1 else Color(1.0, 0.88, 0.45, lt))
	# you, controller in hand, and the robot beside you
	var s := H / 220.0
	var you_at := Vector2(W * 0.22, floor_y + H * 0.02)
	PilotArt.draw_person(ci, you_at, s, you, 1.0, "hold", tt)   # "hold" draws the controller in your hands
	var look: Dictionary = looks["echo_rust"]
	RobotArt.draw(ci, Vector2(W * 0.34, floor_y + 4), look, {"light": shot_light(), "scale": robot_scale(look, H * 0.36), "facing": 1, "time": tt})


# ---------------------------------------------------------------- 8 the bell

func draw_bell(ci: CanvasItem, W: float, H: float, tt: float) -> void:
	var floor_y := H * 0.84
	ci.draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.05, 0.08))
	# the Rusty Bolt's brick wall, sinking into the dark toward the top
	for row in int(floor_y / 18.0):
		for col in int(W / 40.0) + 2:
			var x := col * 40.0 - (20.0 if row % 2 else 0.0)
			ci.draw_rect(Rect2(x + 1, row * 18.0 + 1, 38, 16), Color(0.22, 0.1, 0.09).lerp(Color(0.3, 0.13, 0.1), hsh(row * 100 + col)))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, floor_y), Vector2(0, floor_y)]),
			PackedColorArray([Color(0.02, 0.0, 0.02, 0.65), Color(0.02, 0.0, 0.02, 0.65), Color(0.02, 0.0, 0.02, 0.15), Color(0.02, 0.0, 0.02, 0.15)]))
	lit()
	var on := fmod(tt, 5.0) > 0.12 and not (fmod(tt, 5.0) > 0.3 and fmod(tt, 5.0) < 0.38)
	var neon := Color(1.0, 0.45, 0.2) if on else Color(0.35, 0.18, 0.12)
	var sr := Rect2(W * 0.04, H * 0.2, W * 0.36, H * 0.11)
	ci.draw_rect(sr.grow(30), Color(neon, 0.06 if on else 0.0))
	GarageArt._rc(ci, sr.grow(8), Color(0.2, 0.16, 0.14))
	ci.draw_rect(sr, Color(0.08, 0.05, 0.05))
	ci.draw_rect(sr, neon, false, 3.0)
	ci.draw_string(GUI.headb(), sr.position + Vector2(0, sr.size.y * 0.72), I18n.t("THE RUSTY BOLT"), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(sr.size.y * 0.5), neon)
	# the pub's back door, warm light through its little window
	var door := Rect2(W * 0.08, floor_y - H * 0.3, W * 0.09, H * 0.3)
	GarageArt._rc(ci, door, Color(0.32, 0.2, 0.13))
	ci.draw_rect(Rect2(door.position + Vector2(door.size.x * 0.25, door.size.y * 0.12), Vector2(door.size.x * 0.5, door.size.y * 0.2)), Color(1.0, 0.75, 0.4))
	ci.draw_rect(Rect2(door.position + Vector2(door.size.x * 0.25, door.size.y * 0.12), Vector2(door.size.x * 0.5, door.size.y * 0.2)).grow(10), Color(1.0, 0.75, 0.4, 0.1))
	# out back: the scrap ring under one bulb
	var ring := Rect2(W * 0.5, floor_y - H * 0.34, W * 0.46, H * 0.34)
	var bulb := Vector2(ring.get_center().x, H * 0.14)
	ci.draw_line(Vector2(bulb.x, 0), bulb + Vector2(0, -10), Color(0.12, 0.1, 0.1), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-10, 4), bulb + Vector2(10, 4), Vector2(ring.end.x + 30, floor_y), Vector2(ring.position.x - 30, floor_y)]), Color(1.0, 0.9, 0.6, 0.08))
	ci.draw_set_transform(Vector2(bulb.x, floor_y + 6), 0.0, Vector2(1.0, 0.16))
	ci.draw_circle(Vector2.ZERO, ring.size.x * 0.6, Color(1.0, 0.9, 0.6, 0.1))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	GarageArt._pg(ci, PackedVector2Array([bulb + Vector2(-6, -12), bulb + Vector2(6, -12), bulb + Vector2(14, 2), bulb + Vector2(-14, 2)]), Color(0.3, 0.32, 0.3))
	ci.draw_circle(bulb + Vector2(0, 5), 6.0, Color(1.0, 0.92, 0.65))
	ci.draw_circle(bulb + Vector2(0, 5), 16.0, Color(1.0, 0.92, 0.65, 0.18))
	for x in [ring.position.x, ring.end.x]:
		GarageArt._rc(ci, Rect2(x - 6, ring.position.y, 12, ring.size.y), Color(0.45, 0.33, 0.22))
	for k in 3:
		var y := ring.position.y + 20 + k * 30
		GarageArt._ln(ci, Vector2(ring.position.x, y), Vector2(ring.end.x, y + sin(tt + k) * 2.0), Color(0.6, 0.55, 0.42), 3.0)
	ci.draw_polygon(PackedVector2Array([Vector2(0, floor_y), Vector2(W, floor_y), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color(0.18, 0.13, 0.11), Color(0.18, 0.13, 0.11), Color(0.08, 0.06, 0.06), Color(0.08, 0.06, 0.06)]))
	ci.draw_line(Vector2(0, floor_y), Vector2(W, floor_y), Color(1.0, 0.76, 0.42, 0.3), 1.5)
	# Old Pike and FENCEPOST, waiting; he waves you in
	var s := H / 240.0
	var pike_at := Vector2(W * 0.92, floor_y)
	PilotArt.draw_person(ci, pike_at, s, {"skin": "#d8b49a", "hair": "#b8b8b8", "hat": "cap", "beard": "long", "beard_color": "#cfcfcf", "outfit": "#5b4a38"},
			-1.0, "cheer" if fmod(tt, 1.2) < 0.6 else "idle", tt)
	RobotArt.draw(ci, Vector2(W * 0.8, floor_y + 4), pike_look, {"light": shot_light(), "scale": robot_scale(pike_look, H * 0.36), "facing": -1, "time": tt})
	# you and Gus walk in from the left, ECHO behind you
	var walk := clampf(tt / 3.0, 0.0, 1.0)
	var gus_at := Vector2(lerpf(-W * 0.05, W * 0.3, walk), floor_y)
	var you_at := Vector2(lerpf(-W * 0.12, W * 0.38, walk), floor_y)
	var look: Dictionary = looks["echo_rust"]
	RobotArt.draw(ci, Vector2(lerpf(-W * 0.25, W * 0.55, walk), floor_y + 4), look, {"light": shot_light(), "scale": robot_scale(look, H * 0.4), "facing": 1, "time": tt,
			"swing": sin(tt * 7.0) * 0.5 if walk < 1.0 else 0.0})
	PilotArt.draw_person(ci, gus_at, s, PilotArt.GUS_LOOK, 1.0, "point" if walk >= 1.0 else "idle", tt)
	PilotArt.draw_person(ci, you_at, s, you, 1.0, "hold", tt)
	heads["GUS"] = gus_at + Vector2(0, -68 * s)


## (1.64) The props in a shot are lit plates like the rest of the game (GarageArt's painting tools:
## a shadow side, a light edge, one dark outline). Call it again after drawing robots or people,
## who leave their own light behind.
func lit(set_name: String = "") -> void:
	GarageArt._on = not RobotArt.classic
	RobotArt._set_light(set_name if set_name != "" else shot_light(), 1.0)
	RobotArt._grade = 2
	RobotArt._flash = false


## Where each league's banner hangs on the stadium's front: [x share, width share, length share of H].
## The four leagues climb from the outside in, the Titanium banner hangs in the middle over the doors.
const BANNER_AT := [[0.09, 0.085, 0.22], [0.27, 0.09, 0.25], [0.73, 0.09, 0.28], [0.91, 0.085, 0.31], [0.5, 0.16, 0.36]]


var plaza_y := 0.0   # where the stadium's uplights stand (set by draw_stadium)


## A banner's side sways in the wind more toward the bottom (f = 0 at the pole, 1 at the hem).
func wv(tt: float, ph: float, f: float, w: float) -> float:
	return sin(tt * 1.7 + ph + f * 3.2) * w * 0.06 * f


## (1.64) One league banner: a gold pole with finials, the cloth swaying with a swallowtail cut, a gold
## border, the league's trophy on a medallion, the name, tassels, and an uplight from the plaza.
func draw_banner(ci: CanvasItem, cx: float, top: float, w: float, L: float, cloth: Color, kind: String, name: String, tt: float, ph: float, grand: bool) -> void:
	var gold := Color(0.95, 0.76, 0.3)
	var foot_y := plaza_y
	# the uplight: a cone climbing the cloth from a lamp on the plaza
	var foot := Vector2(cx, foot_y)
	var beam := Color(1.0, 0.88, 0.62, 0.09 if grand else 0.06)
	ci.draw_polygon(PackedVector2Array([foot + Vector2(-w * 0.12, 0), foot + Vector2(w * 0.12, 0), Vector2(cx + w * 0.75, top - 16), Vector2(cx - w * 0.75, top - 16)]),
			PackedColorArray([Color(beam, beam.a * 0.4), Color(beam, beam.a * 0.4), Color(beam, beam.a * 0.5), Color(beam, beam.a * 0.5)]))
	ci.draw_circle(foot, 5.0, Color(1.0, 0.92, 0.7))
	ci.draw_circle(foot, 12.0, Color(1.0, 0.92, 0.7, 0.2))
	# cords up to the roof, the pole and its finials
	ci.draw_line(Vector2(cx - w * 0.55, top), Vector2(cx - w * 0.2, top - roof_cord(w)), Color(0.5, 0.45, 0.35), 1.5)
	ci.draw_line(Vector2(cx + w * 0.55, top), Vector2(cx + w * 0.2, top - roof_cord(w)), Color(0.5, 0.45, 0.35), 1.5)
	# the cloth
	var pts := PackedVector2Array()
	var n := 8
	for i in n + 1:
		var f := float(i) / n
		pts.append(Vector2(cx - w * 0.5 + wv(tt, ph, f, w) - sin(tt * 2.3 + ph + f * 5.0) * f * 1.5, top + L * f))
	pts.append(Vector2(cx + wv(tt, ph, 1.0, w), top + L * 0.86))
	for i in range(n, -1, -1):
		var f := float(i) / n
		pts.append(Vector2(cx + w * 0.5 + wv(tt, ph, f, w) + sin(tt * 2.1 + ph + f * 5.0) * f * 1.5, top + L * f))
	GarageArt._pg(ci, pts, cloth)
	# the light from the plaza warms the lower cloth
	var lo := PackedVector2Array()
	var lc := PackedColorArray()
	for q in pts:
		lo.append(q)
		var f := clampf((q.y - top) / L, 0.0, 1.0)
		lc.append(Color(1.0, 0.85, 0.6, 0.16 * f * (1.4 if grand else 1.0)))
	ci.draw_polygon(lo, lc)
	# the gold border, set in from the edge
	var bw := 2.5 if grand else 1.8
	for side in [-1.0, 1.0]:
		var line := PackedVector2Array()
		for i in n:
			var f := float(i) / n
			var y := top + L * (0.08 + f * 0.74)
			line.append(Vector2(cx + side * w * 0.38 + wv(tt, ph, (y - top) / L, w), y))
		ci.draw_polyline(line, gold, bw)
	var vy := top + L * 0.82
	ci.draw_polyline(PackedVector2Array([Vector2(cx - w * 0.38 + wv(tt, ph, 0.82, w), vy), Vector2(cx + wv(tt, ph, 0.92, w), top + L * 0.74),
			Vector2(cx + w * 0.38 + wv(tt, ph, 0.82, w), vy)]), gold, bw)
	# the sleeve over the pole
	GarageArt._rc(ci, Rect2(cx - w * 0.5, top - 2, w, w * 0.13), cloth.darkened(0.3))
	ci.draw_line(Vector2(cx - w * 0.5, top + w * 0.13), Vector2(cx + w * 0.5, top + w * 0.13), gold, bw)
	# the name
	var fs := Scoreboard.fit_size(GUI.headb(), name, w * 0.74, int(w * (0.2 if not grand else 0.17)))
	var ny := top + w * 0.13 + fs * 1.15
	var nx := cx - w * 0.5 + wv(tt, ph, 0.2, w)
	ci.draw_string(GUI.headb(), Vector2(nx + 2, ny + 2), name, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0, 0, 0, 0.6))
	ci.draw_string(GUI.headb(), Vector2(nx, ny), name, HORIZONTAL_ALIGNMENT_CENTER, w, fs, gold if grand else Color(0.96, 0.94, 0.88))
	# the medallion and the league's trophy on it
	var mr := minf(w * 0.3, L * 0.2)
	var mc := Vector2(cx + wv(tt, ph, 0.56, w), ny + fs * 0.45 + mr + L * 0.04)
	GarageArt._cr(ci, mc, mr, cloth.darkened(0.35))
	ci.draw_arc(mc, mr - 3.0, 0.0, TAU, 32, gold, bw)
	GarageArt.draw_trophy(ci, mc + Vector2(0, mr * 0.62), kind, 1, mr / 24.0)
	# tassels along the swallowtail
	var tl := Vector2(cx - w * 0.5 + wv(tt, ph, 1.0, w), top + L)
	var tm := Vector2(cx + wv(tt, ph, 1.0, w), top + L * 0.86)
	var tr2 := Vector2(cx + w * 0.5 + wv(tt, ph, 1.0, w), top + L)
	var steps := int(w / 7.0)
	for i in steps + 1:
		var f := float(i) / steps
		for seg in [[tl, tm], [tm, tr2]]:
			var q: Vector2 = (seg[0] as Vector2).lerp(seg[1], f)
			ci.draw_line(q, q + Vector2(sin(tt * 3.0 + i) * 1.5, 7.0 if grand else 5.0), gold.darkened(0.15), 1.6)
	# the pole
	GarageArt._ln(ci, Vector2(cx - w * 0.62, top), Vector2(cx + w * 0.62, top), gold.darkened(0.1), 5.0)
	GarageArt._cr(ci, Vector2(cx - w * 0.62, top), 5.0, gold)
	GarageArt._cr(ci, Vector2(cx + w * 0.62, top), 5.0, gold)
	if grand:
		# the champion's banner glitters
		for i in 5:
			var ph2 := fmod(tt * 0.9 + i * 0.37, 1.0)
			if ph2 < 0.35:
				var sp := Vector2(cx + (hsh(i + 70) - 0.5) * w * 0.8, top + L * (0.1 + hsh(i + 90) * 0.7))
				var r := 7.0 * sin(ph2 / 0.35 * PI)
				ci.draw_line(sp - Vector2(r, 0), sp + Vector2(r, 0), Color(1, 0.95, 0.75, 0.9), 1.6)
				ci.draw_line(sp - Vector2(0, r), sp + Vector2(0, r), Color(1, 0.95, 0.75, 0.9), 1.6)


## How far up to the roof a banner's cords run.
func roof_cord(w: float) -> float:
	return w * 0.6


## The scrapyard's big crane (1.64): a lattice mast and A-frame, the operator's cab, the jib reaching
## left over the tarp with its trolley, the counterweight, the cable down to the hook, a warning light.
func big_crane(ci: CanvasItem, foot: Vector2, top_y: float, jib_l: float, hook: Vector2, c: Color, tt: float) -> void:
	var mw := 30.0
	var x0 := foot.x - mw * 0.5
	var x1 := foot.x + mw * 0.5
	var y := foot.y
	var step := 34.0
	var k := 0
	while y - step > top_y:
		GarageArt._ln(ci, Vector2(x0 if k % 2 == 0 else x1, y), Vector2(x1 if k % 2 == 0 else x0, y - step), c.darkened(0.1), 2.5)
		GarageArt._ln(ci, Vector2(x0, y), Vector2(x1, y), c.darkened(0.1), 2.5)
		y -= step
		k += 1
	GarageArt._ln(ci, Vector2(x0, foot.y), Vector2(x0, top_y), c, 6.0)
	GarageArt._ln(ci, Vector2(x1, foot.y), Vector2(x1, top_y), c, 6.0)
	# the jib: bottom chord, top chord, the zigzag between
	var jl := foot.x - jib_l
	var jr := foot.x + jib_l * 0.32
	var jt := top_y - 18.0
	var xx := jl + 14.0
	var up := true
	while xx < jr - 18.0:
		GarageArt._ln(ci, Vector2(xx, top_y if up else jt), Vector2(xx + 18.0, jt if up else top_y), c.darkened(0.1), 2.5)
		xx += 18.0
		up = not up
	GarageArt._ln(ci, Vector2(jl, top_y), Vector2(jr, top_y), c, 6.0)
	GarageArt._ln(ci, Vector2(jl + 14.0, jt), Vector2(jr - 6.0, jt), c, 4.0)
	# the A-frame on top and its pendant cables out to both ends
	var peak := Vector2(foot.x, jt - 54.0)
	GarageArt._ln(ci, Vector2(x0, jt), peak, c, 5.0)
	GarageArt._ln(ci, Vector2(x1, jt), peak, c, 5.0)
	ci.draw_line(peak, Vector2(jl + 20.0, jt), Color(0.15, 0.13, 0.12), 1.5)
	ci.draw_line(peak, Vector2(jr - 8.0, jt), Color(0.15, 0.13, 0.12), 1.5)
	# counterweight and the operator's cab
	GarageArt._rc(ci, Rect2(jr - 52.0, top_y + 2.0, 46.0, 34.0), Color(0.32, 0.31, 0.33))
	var cab := Rect2(x1, top_y + 4.0, 40.0, 34.0)
	GarageArt._rc(ci, cab, c)
	ci.draw_rect(Rect2(cab.position + Vector2(6, 6), Vector2(26, 14)), Color(1.0, 0.75, 0.4, 0.75))
	# the trolley, the cable and the hook block
	GarageArt._rc(ci, Rect2(hook.x - 14.0, top_y - 2.0, 28.0, 12.0), Color(0.3, 0.3, 0.32))
	ci.draw_line(Vector2(hook.x - 4.0, top_y + 10.0), hook + Vector2(-4, -14), Color(0.12, 0.12, 0.13), 2.0)
	ci.draw_line(Vector2(hook.x + 4.0, top_y + 10.0), hook + Vector2(4, -14), Color(0.12, 0.12, 0.13), 2.0)
	GarageArt._rc(ci, Rect2(hook + Vector2(-10, -16), Vector2(20, 14)), Color(0.85, 0.65, 0.15))
	GarageArt._ac(ci, hook + Vector2(0, 6), 7.0, -0.3, PI + 0.6, 10, Color(0.35, 0.35, 0.38), 4.0)
	# the warning light on the jib's tip
	if fmod(tt, 1.2) < 0.5:
		ci.draw_circle(Vector2(jl + 4.0, top_y - 6.0), 4.0, Color(1.0, 0.25, 0.2))
		ci.draw_circle(Vector2(jl + 4.0, top_y - 6.0), 11.0, Color(1.0, 0.25, 0.2, 0.2))


## The tarp over ECHO, hooked to the crane at its peak (1.64). Draped over the robot when lift is 0;
## as the hook rises it slides off, bunches and hangs, swinging (sway, px at the hem).
func draw_tarp(ci: CanvasItem, peak: Vector2, floor_y: float, half_w: float, tall: float, lift: float, sway: float, tt: float) -> void:
	var c := Color(0.33, 0.4, 0.3)
	var hang := clampf((lift - tall * 0.15) / (tall * 0.5), 0.0, 1.0)
	var L := lerpf(floor_y + 2.0 - (peak.y + lift), tall * 0.62, hang)
	var sh_w := lerpf(half_w * 0.85, half_w * 0.28, hang)
	var mid_w := lerpf(half_w * 0.95, half_w * 0.36, hang)
	var hem_w := lerpf(half_w * 1.12, half_w * 0.5, hang)
	var hem_y := peak.y + L
	var pts := PackedVector2Array()
	var left := [[0.0, half_w * 0.08], [0.12, sh_w * 0.7], [0.24, sh_w], [0.6, mid_w], [1.0, hem_w]]
	for q in left:
		var y: float = peak.y + L * float(q[0])
		pts.append(Vector2(peak.x - float(q[1]) + _tsw(y, peak.y, L, sway) + _trf(y, 0.0, peak.y, L, tt), y))
	# the hem, ragged
	var n := 7
	for i in range(1, n):
		var f := float(i) / n
		var x := lerpf(peak.x - hem_w, peak.x + hem_w, f)
		pts.append(Vector2(x + _tsw(hem_y, peak.y, L, sway), hem_y + sin(i * 2.3 + tt * 2.0) * 3.0 + (4.0 if i % 2 == 0 else -2.0)))
	for i in range(left.size() - 1, -1, -1):
		var q: Array = left[i]
		var y: float = peak.y + L * float(q[0])
		pts.append(Vector2(peak.x + float(q[1]) + _tsw(y, peak.y, L, sway) + _trf(y, 1.3, peak.y, L, tt), y))
	GarageArt._pg(ci, pts, c)
	# folds running down from the hook, a patch, the grommets along the hem
	for f in [-0.62, -0.28, 0.1, 0.45, 0.75]:
		var a := peak + Vector2(f * half_w * 0.1, L * 0.1)
		var b := Vector2(peak.x + f * hem_w * 0.95 + _tsw(hem_y, peak.y, L, sway), hem_y - 2.0)
		ci.draw_line(a, a.lerp(b, 0.5) + Vector2(f * 6.0, 0), c.darkened(0.32), 2.5)
		ci.draw_line(a.lerp(b, 0.5) + Vector2(f * 6.0, 0), b, c.darkened(0.32), 2.5)
		ci.draw_line(a + Vector2(3, 0), b + Vector2(4, 0), Color(c.lightened(0.2), 0.6), 1.2)
	var pc := Vector2(peak.x - mid_w * 0.35 + _tsw(peak.y + L * 0.55, peak.y, L, sway), peak.y + L * 0.55)
	ci.draw_colored_polygon(PackedVector2Array([pc, pc + Vector2(22, -4), pc + Vector2(26, 16), pc + Vector2(2, 20)]), c.darkened(0.15))
	ci.draw_polyline(PackedVector2Array([pc, pc + Vector2(22, -4), pc + Vector2(26, 16), pc + Vector2(2, 20), pc]), Color(0.75, 0.7, 0.55, 0.5), 1.0)
	for i in range(1, n):
		var x := lerpf(peak.x - hem_w * 0.9, peak.x + hem_w * 0.9, float(i) / n)
		ci.draw_circle(Vector2(x + _tsw(hem_y, peak.y, L, sway), hem_y - 6.0), 2.2, Color(0.75, 0.72, 0.6))
	# the hook gathers it at the top in a rope knot
	GarageArt._cr(ci, peak + Vector2(0, 2), 5.0, Color(0.6, 0.5, 0.32))
	ci.draw_line(peak + Vector2(0, -8), peak + Vector2(0, 2), Color(0.6, 0.5, 0.32), 3.0)


## How far the tarp swings at height y (more toward the hem).
func _tsw(y: float, top: float, L: float, sway: float) -> float:
	return sway * clampf((y - top) / maxf(L, 1.0), 0.0, 1.0)


## The wind ruffling the tarp's sides.
func _trf(y: float, k: float, top: float, L: float, tt: float) -> float:
	return sin(tt * 3.4 + y * 0.05 + k) * 2.0 * clampf((y - top) / maxf(L, 1.0), 0.0, 1.0)


# ================================================================ the words, the fades, SKIP

class Overlay extends Control:
	var op
	var skip_rect := Rect2()

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var tt: float = op.t
		var dur: float = float(SHOTS[op.shot][1])
		# cinema bars
		var bar := H * 0.07
		draw_rect(Rect2(0, 0, W, bar), Color.BLACK)
		draw_rect(Rect2(0, H - bar, W, bar), Color.BLACK)
		# fade in and out of every shot (OVERLORD's cut comes in hard)
		var a := 0.0
		var id: String = op.sid()
		var prev_cut: bool = op.shot > 0 and CUTS.has(str(SHOTS[op.shot - 1][0]))
		if tt < FADE and id != "overlord" and not prev_cut:
			a = 1.0 - tt / FADE
		if tt > dur - FADE and not CUTS.has(id) and id != "dad_win":
			a = maxf(a, (tt - (dur - FADE)) / FADE)
		if a > 0.0:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, clampf(a, 0.0, 1.0)))
		# SKIP
		var fs := UI.px(15)
		var sw := GUI.headb().get_string_size(tr("SKIP ▸▸"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
		skip_rect = Rect2(W - sw - 16.0, bar * 0.5 - (fs + 16) * 0.5 + 2.0, sw, fs + 16)
		draw_rect(skip_rect, Color(1, 1, 1, 0.1))
		draw_rect(skip_rect, Color(1, 1, 1, 0.4), false, 1.5)
		draw_string(GUI.headb(), Vector2(skip_rect.position.x, skip_rect.end.y - (skip_rect.size.y - fs) * 0.5 - 3.0), tr("SKIP ▸▸"), HORIZONTAL_ALIGNMENT_CENTER, sw, fs, Color(1, 1, 1, 0.85))
		# the line
		var li: int = op.line_i
		if li < 0 or not op.line_shot(li):
			return
		var who: String = LINES[li][2]
		var full: String = op.line_text(li)
		var text := full.substr(0, int(op.shown))
		if who == "NARRATOR":
			var ts := UI.px(20)
			var f := GUI.bold()
			var h := f.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, W * 0.8, ts).y
			var y := H - bar - h - 18.0
			draw_rect(Rect2(W * 0.08, y - 10, W * 0.84, h + 20), Color(0, 0, 0, 0.55))
			draw_multiline_string(f, Vector2(W * 0.1, y + ts * 0.85), text, HORIZONTAL_ALIGNMENT_CENTER, W * 0.8, ts, -1, Color(0.92, 0.92, 0.95))
			return
		# Gus and ECHO: a bubble above the speaker, its tail to their head
		var ts := UI.px(18) if who == "GUS" else UI.px(20)
		var f: Font = GUI.num() if who == "ECHO" else GUI.bold()
		var maxw := minf(W * 0.42, 520.0)
		var sz := f.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, maxw, ts)
		var name_s := UI.px(13)
		var box := Vector2(sz.x + 32.0, sz.y + name_s + 30.0)
		var head: Vector2 = op.to_screen(op.heads.get(who, Vector2(W * 0.5, H * 0.5) / op.stage.scale.x))
		var pos := Vector2(clampf(head.x - box.x * 0.5, 12.0, W - box.x - 12.0), clampf(head.y - box.y - 40.0, bar + 8.0, H - bar - box.y - 8.0))
		var paper := Color(0.957, 0.945, 0.902) if who == "GUS" else Color(0.03, 0.1, 0.05, 0.95)
		draw_rect(Rect2(pos, box), paper)
		var tail_x := clampf(head.x, pos.x + 20.0, pos.x + box.x - 20.0)
		if head.y > pos.y + box.y:
			draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 10, pos.y + box.y), Vector2(tail_x + 10, pos.y + box.y), head + Vector2(0, -6)]), paper)
		var ink := Color(0.13, 0.13, 0.15) if who == "GUS" else Color(0.4, 1.0, 0.5)
		draw_string(GUI.headb(), pos + Vector2(16, name_s + 8), "GUS" if who == "GUS" else GameData.robot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_s, Color(0.85, 0.45, 0.1) if who == "GUS" else Color(0.4, 1.0, 0.5, 0.7))
		draw_multiline_string(f, pos + Vector2(16, name_s + 14 + ts * 0.9), text, HORIZONTAL_ALIGNMENT_LEFT, maxw, ts, -1, ink)
