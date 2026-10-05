extends Node2D
## Championship fight: your robot vs the current opponent, best of 3 rounds.
## Everything (robots, arena, buttons) is drawn in code.
##
## Touch controls (phone):  left pad = < > move, ^ jump, v crouch
##                          right pad = P punch, K kick, B block (hold)
## Keyboard (PC):           A/D move, W jump, S crouch, J punch, K kick, L block, Esc quit
## Crouch + P = uppercut (launches), Crouch + K = sweep (low, must crouch-block)
## Crouching ducks under punches.

const GRAVITY := 2200.0
const WALK_SPEED := 260.0
const JUMP_SPEED := 860.0
const ROUNDS_TO_WIN := 2
const BUTTON_SCALES := [0.8, 1.0, 1.25]
const DIFF_THINK := [1.4, 1.0, 0.7]
const DIFF_BLOCK := [0.7, 1.0, 1.25]

# Attack data. height: "high" misses crouching targets, "low" must be blocked crouching.
const ATTACKS := {
	"punch":    {"startup": 0.07, "active": 0.10, "recovery": 0.16, "reach": 80.0,  "damage": 6.0,  "height": "high", "stun": 0.22},
	"kick":     {"startup": 0.14, "active": 0.10, "recovery": 0.26, "reach": 100.0, "damage": 10.0, "height": "mid",  "stun": 0.28},
	"uppercut": {"startup": 0.12, "active": 0.10, "recovery": 0.35, "reach": 70.0,  "damage": 14.0, "height": "mid",  "stun": 0.50},
	"sweep":    {"startup": 0.12, "active": 0.12, "recovery": 0.30, "reach": 105.0, "damage": 8.0,  "height": "low",  "stun": 0.35},
}


class Fighter:
	var label := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var facing := 1
	var max_hp := 100.0
	var hp := 100.0
	var dmg_mult := 1.0
	var spd_mult := 1.0
	var look := {}
	var rounds := 0
	var state := "idle"   # idle, walk, jump, hit, ko, or an attack name
	var timer := 0.0
	var hit_done := false
	var flash := 0.0
	var crouching := false
	var blocking := false
	var on_ground := true
	var walk_phase := 0.0
	var step_timer := 0.0


var player: Fighter
var cpu: Fighter
var opp: Dictionary
var screen := Vector2(1152, 648)
var floor_y := 420.0
var font: Font

var touches := {}          # touch index -> position
var buttons: Array = []    # on-screen buttons
var held_buttons := {}
var prev_punch := false
var prev_kick := false
var tap_pending := false
var quit_rect := Rect2()

var ai_timer := 0.0
var ai_plan := {}
var ai_think := 0.4
var ai_block := 0.2

var phase := "intro"   # intro, fight, ko, results
var phase_timer := 0.0
var round_num := 1
var ko_text := ""
var won := false
var reward := 0
var fight_called := false

var shake := 0.0
var sparks: Array = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	layout()
	var s := GameData.stats()
	opp = GameData.current_opponent()

	player = Fighter.new()
	player.label = "YOU"
	player.max_hp = s["max_hp"]
	player.dmg_mult = s["damage"] / 100.0
	player.spd_mult = s["speed"] / 100.0
	player.look = GameData.look()

	cpu = Fighter.new()
	cpu.label = opp["name"]
	cpu.max_hp = opp["hp"]
	cpu.dmg_mult = opp["damage"]
	cpu.spd_mult = opp["speed"]
	cpu.look = GameData.opponent_look(GameData.fight_index)

	var diff: int = GameData.settings["difficulty"]
	ai_think = opp["think"] * DIFF_THINK[diff]
	ai_block = minf(0.85, opp["block"] * DIFF_BLOCK[diff])
	start_round()


func layout() -> void:
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.66
	var h := screen.y
	var w := screen.x
	var r: float = clampf(h * 0.085, 34.0, 60.0) * BUTTON_SCALES[GameData.settings["button_size"]]
	var lc := Vector2(r * 2.6, h - r * 2.4)
	buttons = [
		{"name": "left",  "pos": lc + Vector2(-r * 1.6, 0), "r": r, "label": "<"},
		{"name": "right", "pos": lc + Vector2(r * 1.6, 0),  "r": r, "label": ">"},
		{"name": "up",    "pos": lc + Vector2(0, -r * 1.6), "r": r, "label": "^"},
		{"name": "down",  "pos": lc + Vector2(0, r * 1.4),  "r": r, "label": "v"},
		{"name": "punch", "pos": Vector2(w - r * 4.4, h - r * 1.5), "r": r, "label": "P"},
		{"name": "kick",  "pos": Vector2(w - r * 1.8, h - r * 2.2), "r": r, "label": "K"},
		{"name": "block", "pos": Vector2(w - r * 3.4, h - r * 3.9), "r": r, "label": "B"},
	]
	quit_rect = Rect2(w * 0.5 - 60.0, h * 0.04 + 40.0, 120.0, 40.0)


func start_round() -> void:
	for f in [player, cpu]:
		f.hp = f.max_hp
		f.vel = Vector2.ZERO
		f.state = "idle"
		f.timer = 0.0
		f.flash = 0.0
		f.crouching = false
		f.blocking = false
		f.on_ground = true
	player.pos = Vector2(screen.x * 0.3, floor_y)
	cpu.pos = Vector2(screen.x * 0.7, floor_y)
	player.facing = 1
	cpu.facing = -1
	phase = "intro"
	phase_timer = 0.0
	fight_called = false
	sparks.clear()
	ai_plan = {}
	ai_timer = 0.5
	Sfx.play("round")


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if quit_rect.has_point(event.position) and (phase == "intro" or phase == "fight"):
				quit_fight()
				return
			touches[event.index] = event.position
			tap_pending = true
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			tap_pending = true
		elif event.physical_keycode == KEY_ESCAPE and (phase == "intro" or phase == "fight"):
			quit_fight()


func empty_input() -> Dictionary:
	return {"left": false, "right": false, "up": false, "down": false,
			"block": false, "punch": false, "kick": false}


func key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func read_player_input() -> Dictionary:
	held_buttons = {}
	for b in buttons:
		held_buttons[b["name"]] = false
	for t in touches.values():
		for b in buttons:
			if t.distance_to(b["pos"]) <= b["r"] * 1.25:
				held_buttons[b["name"]] = true

	var i := empty_input()
	i["left"] = held_buttons["left"] or key(KEY_A) or key(KEY_LEFT)
	i["right"] = held_buttons["right"] or key(KEY_D) or key(KEY_RIGHT)
	i["up"] = held_buttons["up"] or key(KEY_W) or key(KEY_UP)
	i["down"] = held_buttons["down"] or key(KEY_S) or key(KEY_DOWN)
	i["block"] = held_buttons["block"] or key(KEY_L)
	var p_now: bool = held_buttons["punch"] or key(KEY_J)
	var k_now: bool = held_buttons["kick"] or key(KEY_K)
	i["punch"] = p_now and not prev_punch
	i["kick"] = k_now and not prev_kick
	prev_punch = p_now
	prev_kick = k_now
	return i


func read_ai_input(delta: float) -> Dictionary:
	var i := empty_input()
	if phase != "fight":
		return i
	ai_timer -= delta
	var dx := player.pos.x - cpu.pos.x
	var dist := absf(dx)
	var toward := "right" if dx > 0 else "left"
	var away := "left" if dx > 0 else "right"

	if ai_timer <= 0.0:
		ai_timer = randf_range(ai_think * 0.5, ai_think)
		var r := randf()
		if ATTACKS.has(player.state) and dist < 150.0 and randf() < ai_block:
			ai_plan = {"hold": ["block"]}
		elif dist > 120.0:
			ai_plan = {"hold": [toward]}
			if r < 0.08:
				ai_plan["tap"] = "up"
		elif r < 0.30:
			ai_plan = {"tap": "punch"}
		elif r < 0.50:
			ai_plan = {"tap": "kick"}
		elif r < 0.60:
			ai_plan = {"hold": ["down"], "tap": "kick"}
		elif r < 0.68:
			ai_plan = {"hold": ["down"], "tap": "punch"}
		elif r < 0.85:
			ai_plan = {"hold": ["block"]}
		else:
			ai_plan = {"hold": [away]}
		ai_plan["fresh"] = true

	for k in ai_plan.get("hold", []):
		i[k] = true
	if ai_plan.get("fresh", false) and ai_plan.has("tap"):
		i[ai_plan["tap"]] = true
	ai_plan["fresh"] = false
	return i


# ---------------------------------------------------------------- game loop

func _process(delta: float) -> void:
	layout()
	phase_timer += delta

	var p_in := read_player_input()
	var c_in := read_ai_input(delta)
	if phase != "fight":
		p_in = empty_input()
		c_in = empty_input()

	if phase == "intro":
		if phase_timer >= 0.9 and not fight_called:
			fight_called = true
			Sfx.play("fight")
		if phase_timer >= 1.6:
			phase = "fight"
			phase_timer = 0.0

	update_fighter(player, cpu, p_in, delta)
	update_fighter(cpu, player, c_in, delta)
	separate()

	if phase == "ko" and phase_timer > 1.8 and tap_pending:
		after_ko()
	elif phase == "results" and phase_timer > 1.0 and tap_pending:
		Sfx.play("click")
		get_tree().change_scene_to_file("res://garage.tscn")
	tap_pending = false

	shake = maxf(0.0, shake - delta * 30.0)
	if not GameData.settings["shake"]:
		shake = 0.0
	for s in sparks:
		s["t"] += delta
	sparks = sparks.filter(func(s): return s["t"] < 0.25)

	queue_redraw()


func after_ko() -> void:
	if player.rounds >= ROUNDS_TO_WIN or cpu.rounds >= ROUNDS_TO_WIN:
		won = player.rounds >= ROUNDS_TO_WIN
		reward = GameData.record_result(won)
		phase = "results"
		phase_timer = 0.0
		Sfx.play("victory" if won else "defeat")
	else:
		round_num += 1
		start_round()


func quit_fight() -> void:
	Sfx.play("error")
	GameData.last_result = {"quit": true, "opponent": opp["name"]}
	get_tree().change_scene_to_file("res://garage.tscn")


func start_attack(f: Fighter, attack: String) -> void:
	f.state = attack
	f.timer = 0.0
	f.hit_done = false
	f.blocking = false
	f.crouching = attack == "sweep"
	Sfx.play("uppercut" if attack == "uppercut" else "swing", 0.15)


func update_fighter(f: Fighter, o: Fighter, i: Dictionary, delta: float) -> void:
	f.flash = maxf(0.0, f.flash - delta)

	if f.state == "ko":
		f.vel.x = move_toward(f.vel.x, 0.0, 900.0 * delta)
	elif f.state == "hit":
		f.timer -= delta
		f.vel.x = move_toward(f.vel.x, 0.0, 1200.0 * delta)
		if f.timer <= 0.0 and f.on_ground:
			f.state = "idle"
	elif ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		f.timer += delta * f.spd_mult
		if f.on_ground:
			f.vel.x = 0.0
		if not f.hit_done and f.timer >= a["startup"] and f.timer <= a["startup"] + a["active"]:
			try_hit(f, o, a)
		if f.timer >= a["startup"] + a["active"] + a["recovery"]:
			f.state = "idle"
			f.crouching = false
	else:
		if f.on_ground:
			f.facing = 1 if o.pos.x >= f.pos.x else -1
		f.crouching = i["down"] and f.on_ground
		f.blocking = i["block"] and f.on_ground
		if i["punch"]:
			start_attack(f, "uppercut" if f.crouching else "punch")
		elif i["kick"]:
			start_attack(f, "sweep" if f.crouching else "kick")
		elif f.on_ground:
			var dir := 0
			if not f.crouching and not f.blocking:
				dir = int(i["right"]) - int(i["left"])
			f.vel.x = dir * WALK_SPEED * f.spd_mult
			f.state = "walk" if dir != 0 else "idle"
			if dir != 0:
				f.walk_phase += delta * 12.0 * f.spd_mult
				f.step_timer -= delta
				if f.step_timer <= 0.0:
					f.step_timer = 0.28
					Sfx.play("step", 0.2, -10.0)
			if i["up"] and not f.crouching and not f.blocking:
				f.vel.y = -JUMP_SPEED
				f.on_ground = false
				f.state = "jump"
				Sfx.play("jump", 0.1)

	# physics
	f.vel.y += GRAVITY * delta
	f.pos += f.vel * delta
	if f.pos.y >= floor_y:
		f.pos.y = floor_y
		f.vel.y = 0.0
		if not f.on_ground:
			Sfx.play("land", 0.15, -6.0)
			if f.state == "jump":
				f.state = "idle"
		f.on_ground = true
	else:
		f.on_ground = false
	f.pos.x = clampf(f.pos.x, 50.0, screen.x - 50.0)


func try_hit(att: Fighter, d: Fighter, a: Dictionary) -> void:
	var dx := (d.pos.x - att.pos.x) * att.facing
	if dx < -10.0 or dx > a["reach"] + 35.0:
		return
	if absf(d.pos.y - att.pos.y) > 130.0:
		return
	if d.state == "ko":
		return
	if a["height"] == "high" and d.crouching:
		return  # ducked under it
	if a["height"] == "low" and not d.on_ground:
		return  # jumped over it

	att.hit_done = true
	var spark_y := 110.0
	if a["height"] == "mid":
		spark_y = 85.0
	elif a["height"] == "low":
		spark_y = 15.0
	var spark_pos := Vector2(att.pos.x + att.facing * minf(dx, a["reach"]), att.pos.y - spark_y)
	var dmg: float = a["damage"] * att.dmg_mult

	var blocked: bool = d.blocking and (a["height"] != "low" or d.crouching)
	if blocked:
		d.hp -= dmg * 0.1
		d.pos.x += att.facing * 25.0
		add_spark(spark_pos, Color(0.7, 0.85, 1.0), 18.0)
		Sfx.play("block", 0.15)
	else:
		d.hp -= dmg
		d.state = "hit"
		d.timer = a["stun"]
		d.flash = 0.12
		d.crouching = false
		d.blocking = false
		d.vel.x = att.facing * 320.0
		if att.state == "uppercut":
			d.vel.y = -700.0
			d.on_ground = false
		shake = maxf(shake, 8.0)
		add_spark(spark_pos, Color(1.0, 0.85, 0.3), 30.0)
		Sfx.play("hit_big" if dmg >= 12.0 else "hit", 0.15)

	if d.hp <= 0.0:
		d.hp = 0.0
		d.state = "ko"
		d.vel = Vector2(att.facing * 400.0, -500.0)
		d.on_ground = false
		att.rounds += 1
		phase = "ko"
		phase_timer = 0.0
		ko_text = "YOU WIN THE ROUND" if att == player else "%s WINS THE ROUND" % att.label
		shake = 14.0
		Sfx.play("ko")


func separate() -> void:
	var dx := cpu.pos.x - player.pos.x
	if absf(dx) < 70.0 and absf(cpu.pos.y - player.pos.y) < 120.0:
		var push := (70.0 - absf(dx)) * 0.5
		var s := 1.0 if dx >= 0.0 else -1.0
		player.pos.x = clampf(player.pos.x - push * s, 50.0, screen.x - 50.0)
		cpu.pos.x = clampf(cpu.pos.x + push * s, 50.0, screen.x - 50.0)


func add_spark(p: Vector2, c: Color, size: float) -> void:
	sparks.append({"pos": p, "t": 0.0, "color": c, "size": size})


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	# arena
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.07, 0.11))
	for k in range(14):
		draw_circle(Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.22), 5.0, Color(1.0, 0.9, 0.6, 0.45))
	draw_rect(Rect2(Vector2(0, floor_y) + off, Vector2(screen.x, screen.y - floor_y + 20.0)), Color(0.17, 0.17, 0.21))
	draw_line(Vector2(0, floor_y) + off, Vector2(screen.x, floor_y) + off, Color(0.55, 0.55, 0.65), 3.0)
	for k in range(3):
		var y := floor_y - 70.0 - k * 45.0
		draw_line(Vector2(0, y) + off, Vector2(screen.x, y) + off, Color(0.65, 0.1, 0.1, 0.55), 3.0)

	draw_fighter(cpu, off)
	draw_fighter(player, off)

	for s in sparks:
		var t: float = s["t"] / 0.25
		var c: Color = s["color"]
		c.a = 1.0 - t
		draw_circle(s["pos"] + off, s["size"] * (0.4 + t), c)

	draw_hud()
	if phase == "intro" or phase == "fight":
		draw_buttons()


func draw_fighter(f: Fighter, off: Vector2) -> void:
	# shadow
	draw_set_transform(Vector2(f.pos.x, floor_y) + off, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 42.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var base := f.pos + off
	var rot := 0.0
	if f.state == "ko":
		if f.on_ground:
			rot = -f.facing * PI / 2.0
			base.y -= 18.0
		else:
			rot = -f.facing * PI / 4.0

	var extended := false
	if ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		extended = f.timer >= a["startup"] * 0.6 and f.timer <= a["startup"] + a["active"] + a["recovery"] * 0.5

	RobotArt.draw(self, base, f.look, {
		"facing": f.facing, "state": f.state, "extended": extended,
		"swing": sin(f.walk_phase) * 10.0 if f.state == "walk" else 0.0,
		"crouch": f.crouching, "blocking": f.blocking, "flash": f.flash > 0.0, "rot": rot,
	})


func draw_hud() -> void:
	var w := screen.x * 0.36
	var y := screen.y * 0.04
	var bh := 24.0
	# player bar (fills left to right)
	draw_rect(Rect2(30, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(30, y, w * player.hp / player.max_hp, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(30, y, w, bh), Color.WHITE, false, 2.0)
	# cpu bar (fills right to left)
	var cx := screen.x - 30.0 - w
	var cw := w * cpu.hp / cpu.max_hp
	draw_rect(Rect2(cx, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(cx + w - cw, y, cw, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(cx, y, w, bh), Color.WHITE, false, 2.0)

	draw_string(font, Vector2(30, y + bh + 26), player.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(cx, y + bh + 26), cpu.label, HORIZONTAL_ALIGNMENT_RIGHT, w, 22, Color.WHITE)
	# round win pips
	for k in ROUNDS_TO_WIN:
		var pc := Color(1.0, 0.8, 0.2) if player.rounds > k else Color(1, 1, 1, 0.2)
		draw_circle(Vector2(30 + w - 12 - k * 26, y + bh + 18), 8.0, pc)
		var cc := Color(1.0, 0.8, 0.2) if cpu.rounds > k else Color(1, 1, 1, 0.2)
		draw_circle(Vector2(cx + 12 + k * 26, y + bh + 18), 8.0, cc)

	# fight number + quit button
	draw_string(font, Vector2(0, y + 20), "FIGHT %d/%d" % [GameData.fight_index + 1, GameData.OPPONENTS.size()],
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 22, Color(0.8, 0.8, 0.85))
	if phase == "intro" or phase == "fight":
		draw_rect(quit_rect, Color(1, 1, 1, 0.1))
		draw_rect(quit_rect, Color(1, 1, 1, 0.4), false, 2.0)
		draw_string(font, quit_rect.position + Vector2(0, 28), "QUIT", HORIZONTAL_ALIGNMENT_CENTER, quit_rect.size.x, 20, Color(1, 1, 1, 0.7))

	var cy := screen.y * 0.4
	match phase:
		"intro":
			var t := "ROUND %d" % round_num if phase_timer < 0.9 else "FIGHT!"
			draw_string(font, Vector2(0, cy), t, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 80, Color(1.0, 0.3, 0.2))
		"ko":
			draw_string(font, Vector2(0, cy), "K.O.", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 96, Color(1.0, 0.2, 0.1))
			draw_string(font, Vector2(0, cy + 55), ko_text, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 36, Color.WHITE)
			if phase_timer > 1.8:
				draw_string(font, Vector2(0, cy + 100), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 28, Color(0.8, 0.8, 0.8))
		"results":
			draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.55))
			var title := "VICTORY!" if won else "DEFEAT"
			var tc := Color(1.0, 0.85, 0.2) if won else Color(0.9, 0.3, 0.3)
			draw_string(font, Vector2(0, cy), title, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 96, tc)
			draw_string(font, Vector2(0, cy + 60), "+$%d" % reward, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 44, Color(0.95, 0.85, 0.2))
			if GameData.champion and won:
				draw_string(font, Vector2(0, cy + 110), "YOU ARE THE CHAMPION!", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 40, Color(1.0, 0.5, 0.2))
			if phase_timer > 1.0:
				draw_string(font, Vector2(0, cy + 160), "Tap to return to the garage", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 28, Color(0.8, 0.8, 0.8))


func draw_buttons() -> void:
	for b in buttons:
		var held: bool = held_buttons.get(b["name"], false)
		var fill := Color(1, 1, 1, 0.35 if held else 0.12)
		draw_circle(b["pos"], b["r"], fill)
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		draw_string(font, b["pos"] + Vector2(-b["r"], 10.0), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, 30, Color(1, 1, 1, 0.85))
