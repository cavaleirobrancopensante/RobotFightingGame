extends Node2D
## Robot Fighting Game - first playable prototype.
## A simple Mortal Kombat-style 1v1: you vs a CPU robot.
## Everything (robots, arena, buttons) is drawn in code, so no art is needed yet.
##
## Touch controls (phone):  left pad = < > move, ^ jump, v crouch
##                          right pad = P punch, K kick, B block (hold)
## Keyboard (PC):           A/D move, W jump, S crouch, J punch, K kick, L block
## Crouch + P = uppercut (launches), Crouch + K = sweep (low, must crouch-block)
## Crouching ducks under punches.

const GRAVITY := 2200.0
const WALK_SPEED := 260.0
const JUMP_SPEED := 860.0
const ROUND_INTRO := 1.0

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
	var hp := 100.0
	var state := "idle"   # idle, walk, jump, hit, ko, or an attack name
	var timer := 0.0
	var hit_done := false
	var flash := 0.0
	var body := Color.WHITE
	var trim := Color.WHITE
	var eye := Color.RED
	var crouching := false
	var blocking := false
	var on_ground := true
	var walk_phase := 0.0


var player: Fighter
var cpu: Fighter
var screen := Vector2(1152, 648)
var floor_y := 420.0
var font: Font

var touches := {}          # touch index -> position
var buttons: Array = []    # on-screen buttons
var held_buttons := {}     # which buttons are held this frame (for highlighting)
var prev_punch := false
var prev_kick := false
var tap_pending := false

var ai_timer := 0.0
var ai_plan := {}

var round_over := false
var round_timer := 0.0
var winner_text := ""
var player_wins := 0
var cpu_wins := 0

var shake := 0.0
var sparks: Array = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	layout()
	new_round()


func layout() -> void:
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.66
	var h := screen.y
	var w := screen.x
	var r := clampf(h * 0.085, 34.0, 60.0)
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


func make_fighter(label: String, x: float, body: Color, trim: Color, eye: Color) -> Fighter:
	var f := Fighter.new()
	f.label = label
	f.pos = Vector2(x, floor_y)
	f.body = body
	f.trim = trim
	f.eye = eye
	return f


func new_round() -> void:
	player = make_fighter("IRONCLAD", screen.x * 0.3, Color(0.25, 0.45, 0.85), Color(0.85, 0.85, 0.9), Color(0.3, 1.0, 1.0))
	cpu = make_fighter("RUSTBUCKET", screen.x * 0.7, Color(0.75, 0.35, 0.15), Color(0.35, 0.3, 0.3), Color(1.0, 0.2, 0.1))
	cpu.facing = -1
	round_over = false
	round_timer = 0.0
	winner_text = ""
	sparks.clear()
	ai_plan = {}
	ai_timer = 0.5


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			tap_pending = true
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			tap_pending = true


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
	if round_over:
		return i
	ai_timer -= delta
	var dx := player.pos.x - cpu.pos.x
	var dist := absf(dx)
	var toward := "right" if dx > 0 else "left"
	var away := "left" if dx > 0 else "right"

	if ai_timer <= 0.0:
		ai_timer = randf_range(0.18, 0.45)
		var r := randf()
		if ATTACKS.has(player.state) and dist < 140.0 and r < 0.45:
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
	round_timer += delta

	var p_in := read_player_input()
	var c_in := read_ai_input(delta)
	if round_timer < ROUND_INTRO and not round_over:
		p_in = empty_input()
		c_in = empty_input()

	update_fighter(player, cpu, p_in, delta)
	update_fighter(cpu, player, c_in, delta)
	separate()

	if round_over and round_timer > 1.5 and tap_pending:
		new_round()
	tap_pending = false

	shake = maxf(0.0, shake - delta * 30.0)
	for s in sparks:
		s["t"] += delta
	sparks = sparks.filter(func(s): return s["t"] < 0.25)

	queue_redraw()


func start_attack(f: Fighter, attack: String) -> void:
	f.state = attack
	f.timer = 0.0
	f.hit_done = false
	f.blocking = false
	f.crouching = attack == "sweep"


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
		f.timer += delta
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
			f.vel.x = dir * WALK_SPEED
			f.state = "walk" if dir != 0 else "idle"
			if dir != 0:
				f.walk_phase += delta * 12.0
			if i["up"] and not f.crouching and not f.blocking:
				f.vel.y = -JUMP_SPEED
				f.on_ground = false
				f.state = "jump"

	# physics
	f.vel.y += GRAVITY * delta
	f.pos += f.vel * delta
	if f.pos.y >= floor_y:
		f.pos.y = floor_y
		f.vel.y = 0.0
		if not f.on_ground and f.state == "jump":
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

	var blocked: bool = d.blocking and (a["height"] != "low" or d.crouching)
	if blocked:
		d.hp -= a["damage"] * 0.1
		d.pos.x += att.facing * 25.0
		add_spark(spark_pos, Color(0.7, 0.85, 1.0), 18.0)
	else:
		d.hp -= a["damage"]
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

	if d.hp <= 0.0:
		d.hp = 0.0
		d.state = "ko"
		d.vel = Vector2(att.facing * 400.0, -500.0)
		d.on_ground = false
		round_over = true
		round_timer = 0.0
		winner_text = "%s WINS" % att.label
		if att == player:
			player_wins += 1
		else:
			cpu_wins += 1
		shake = 14.0


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
		draw_circle(Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.2), 5.0, Color(1.0, 0.9, 0.6, 0.45))
	draw_rect(Rect2(Vector2(0, floor_y) + off, Vector2(screen.x, screen.y - floor_y + 20.0)), Color(0.17, 0.17, 0.21))
	draw_line(Vector2(0, floor_y) + off, Vector2(screen.x, floor_y) + off, Color(0.55, 0.55, 0.65), 3.0)
	for k in range(3):
		var y := floor_y - 70.0 - k * 45.0
		draw_line(Vector2(0, y) + off, Vector2(screen.x, y) + off, Color(0.65, 0.1, 0.1, 0.55), 3.0)

	draw_robot(cpu, off)
	draw_robot(player, off)

	for s in sparks:
		var t: float = s["t"] / 0.25
		var c: Color = s["color"]
		c.a = 1.0 - t
		draw_circle(s["pos"] + off, s["size"] * (0.4 + t), c)

	draw_hud()
	draw_buttons()


func draw_robot(f: Fighter, off: Vector2) -> void:
	# shadow
	draw_set_transform(Vector2(f.pos.x, floor_y) + off, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 42.0, Color(0, 0, 0, 0.35))

	var base := f.pos + off
	var rot := 0.0
	if f.state == "ko":
		if f.on_ground:
			rot = -f.facing * PI / 2.0
			base.y -= 18.0
		else:
			rot = -f.facing * PI / 4.0
	var sy := 0.68 if f.crouching else 1.0
	draw_set_transform(base, rot, Vector2(f.facing, sy))

	var body := f.body
	var trim := f.trim
	var eye := f.eye
	if f.flash > 0.0:
		body = Color.WHITE
		trim = Color.WHITE
	var dark := body.darkened(0.35)
	var mid := body.darkened(0.15)

	var extended := false
	if ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		extended = f.timer >= a["startup"] * 0.6 and f.timer <= a["startup"] + a["active"] + a["recovery"] * 0.5
	var swing := sin(f.walk_phase) * 10.0 if f.state == "walk" else 0.0

	# back arm
	if f.blocking:
		draw_rect(Rect2(2, -152, 14, 48), dark)
	else:
		draw_rect(Rect2(-14, -126, 14, 44), dark)

	# back leg
	draw_rect(Rect2(-22 - swing, -60, 16, 60), dark)
	draw_rect(Rect2(-26 - swing, -8, 26, 8), trim.darkened(0.3))

	# torso
	draw_rect(Rect2(-28, -134, 56, 76), body)
	draw_rect(Rect2(-28, -70, 56, 10), trim)
	draw_rect(Rect2(-32, -136, 64, 12), trim)
	draw_circle(Vector2(6, -106), 8.0, eye)

	# front leg
	if f.state == "kick" and extended:
		draw_rect(Rect2(8, -88, 92, 18), mid)
		draw_rect(Rect2(94, -98, 14, 32), trim)
	elif f.state == "sweep" and extended:
		draw_rect(Rect2(8, -22, 100, 18), mid)
		draw_rect(Rect2(102, -30, 14, 30), trim)
	else:
		draw_rect(Rect2(6 + swing, -60, 16, 60), mid)
		draw_rect(Rect2(4 + swing, -8, 26, 8), trim)

	# head
	draw_rect(Rect2(-6, -144, 12, 10), dark)
	draw_rect(Rect2(-18, -176, 38, 34), body)
	draw_rect(Rect2(4, -164, 16, 7), eye)
	draw_line(Vector2(-8, -176), Vector2(-12, -190), trim, 3.0)
	draw_circle(Vector2(-12, -191), 3.0, eye)

	# front arm
	var arm := body.lightened(0.1)
	if f.state == "punch" and extended:
		draw_rect(Rect2(8, -128, 80, 16), arm)
		draw_circle(Vector2(92, -120), 13.0, trim)
	elif f.state == "uppercut" and extended:
		draw_rect(Rect2(12, -200, 16, 76), arm)
		draw_circle(Vector2(20, -204), 13.0, trim)
	elif f.blocking:
		draw_rect(Rect2(14, -160, 16, 56), arm)
		draw_circle(Vector2(22, -162), 11.0, trim)
	elif f.state == "hit" or f.state == "ko":
		draw_rect(Rect2(6, -124, 14, 48), arm)
		draw_circle(Vector2(13, -74), 10.0, trim)
	else:
		draw_rect(Rect2(10, -128, 14, 30), arm)
		draw_rect(Rect2(10, -110, 36, 14), arm)
		draw_circle(Vector2(48, -103), 11.0, trim)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_hud() -> void:
	var w := screen.x * 0.38
	var y := screen.y * 0.04
	var bh := 24.0
	# player bar (fills left to right)
	draw_rect(Rect2(30, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(30, y, w * player.hp / 100.0, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(30, y, w, bh), Color.WHITE, false, 2.0)
	# cpu bar (fills right to left)
	var cx := screen.x - 30.0 - w
	var cw := w * cpu.hp / 100.0
	draw_rect(Rect2(cx, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(cx + w - cw, y, cw, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(cx, y, w, bh), Color.WHITE, false, 2.0)

	draw_string(font, Vector2(30, y + bh + 26), "%s  (%d)" % [player.label, player_wins], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(cx, y + bh + 26), "(%d)  %s" % [cpu_wins, cpu.label], HORIZONTAL_ALIGNMENT_RIGHT, w, 22, Color.WHITE)

	if not round_over and round_timer < ROUND_INTRO:
		draw_string(font, Vector2(0, screen.y * 0.4), "FIGHT!", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 80, Color(1.0, 0.3, 0.2))
	if round_over:
		draw_string(font, Vector2(0, screen.y * 0.35), "K.O.", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 96, Color(1.0, 0.2, 0.1))
		draw_string(font, Vector2(0, screen.y * 0.35 + 60), winner_text, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 40, Color.WHITE)
		if round_timer > 1.5:
			draw_string(font, Vector2(0, screen.y * 0.35 + 105), "Tap to fight again", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 28, Color(0.8, 0.8, 0.8))


func draw_buttons() -> void:
	for b in buttons:
		var held: bool = held_buttons.get(b["name"], false)
		var fill := Color(1, 1, 1, 0.35 if held else 0.12)
		draw_circle(b["pos"], b["r"], fill)
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		draw_string(font, b["pos"] + Vector2(-b["r"], 10.0), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, 30, Color(1, 1, 1, 0.85))
