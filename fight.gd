extends Node2D
## Championship fight: ECHO vs the current opponent. One knockout bout with a timer.
##
## Every part (head, torso, 2 arms, 2 legs) has its own health. Tap a part of the enemy to aim
## at it - a crosshair locks on and your hits go there. Parts that reach 0 are ripped off:
##   arm gone  -> can't punch with it (no arms = no punches, no blocking)
##   leg gone  -> slower, no jumping (no legs = crawling, no kicks)
##   head or torso gone -> knockout
## Damage to your robot carries over to the garage. Parts ripped off are lost.
##
## Touch: left pad < > move, ^ jump, v crouch | right pad P punch, K kick, B block (hold)
## Keyboard: A/D move, W jump, S crouch, J punch, K kick, L block, Esc quit, click enemy to aim
## Crouch + P = uppercut, Crouch + K = sweep (low). Crouching ducks under punches.

const GRAVITY := 2200.0
const WALK_SPEED := 260.0
const JUMP_SPEED := 860.0
const FIGHT_TIME := 90.0
const BUTTON_SCALES := [0.8, 1.0, 1.25]
const DIFF_THINK := [1.4, 1.0, 0.7]
const DIFF_BLOCK := [0.7, 1.0, 1.25]
const DIFF_DAMAGE := [0.75, 1.0, 1.2]
const CORE_SHARE := 0.35      # share of a limb/head hit that also hurts the torso
const HEAD_FACTOR := 0.6      # heads are hard to hit cleanly
const BODY_PARTS := ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]
const PART_LABELS := {"head": "HEAD", "torso": "TORSO", "arm_front": "FRONT ARM", "arm_back": "BACK ARM",
		"leg_front": "FRONT LEG", "leg_back": "BACK LEG"}

const ATTACKS := {
	"punch":    {"startup": 0.07, "active": 0.10, "recovery": 0.16, "reach": 82.0,  "damage": 7.0,  "height": "high", "stun": 0.22, "limb": "arm"},
	"kick":     {"startup": 0.14, "active": 0.10, "recovery": 0.26, "reach": 100.0, "damage": 10.0, "height": "mid",  "stun": 0.28, "limb": "leg"},
	"uppercut": {"startup": 0.12, "active": 0.10, "recovery": 0.35, "reach": 72.0,  "damage": 13.0, "height": "mid",  "stun": 0.50, "limb": "arm"},
	"sweep":    {"startup": 0.12, "active": 0.12, "recovery": 0.30, "reach": 105.0, "damage": 8.0,  "height": "low",  "stun": 0.35, "limb": "leg"},
}
# Where each attack can land, and how often when you're not aiming.
const ZONES := {
	"punch": {"head": 0.25, "torso": 0.45, "arm_front": 0.25, "arm_back": 0.05},
	"uppercut": {"head": 0.6, "torso": 0.4},
	"kick": {"torso": 0.35, "arm_front": 0.15, "arm_back": 0.05, "leg_front": 0.35, "leg_back": 0.1},
	"sweep": {"leg_front": 0.7, "leg_back": 0.3},
}


class Fighter:
	var label := ""
	var parts := {}          # slot -> {hp, max_hp, armor, damage, speed, aim, shape, size, color, id}
	var spec := {}
	var look := {}
	var look_dirty := true
	var eff := 1.0
	var dmg_mult := 1.0
	var spd_mult := 1.0
	var scale := 1.0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var facing := 1
	var state := "idle"      # idle, walk, jump, hit, ko, or an attack name
	var attack_limb := ""
	var timer := 0.0
	var hit_done := false
	var flash := 0.0
	var crouching := false
	var blocking := false
	var on_ground := true
	var walk_phase := 0.0
	var step_timer := 0.0
	var target := ""         # part of the enemy being aimed at
	var ripped: Array = []   # ids of this robot's parts that were ripped off

	func alive(slot: String) -> bool:
		return not parts[slot].is_empty() and parts[slot]["hp"] > 0.0

	func ratio(slot: String) -> float:
		if parts[slot].is_empty():
			return 0.0
		return clampf(parts[slot]["hp"] / parts[slot]["max_hp"], 0.0, 1.0)

	func legs() -> int:
		return int(alive("leg_front")) + int(alive("leg_back"))

	func arms() -> int:
		return int(alive("arm_front")) + int(alive("arm_back"))

	func limb_for(attack: String) -> String:
		match attack:
			"punch":
				return "arm_front" if alive("arm_front") else ("arm_back" if alive("arm_back") else "")
			"uppercut":
				return "arm_back" if alive("arm_back") else ("arm_front" if alive("arm_front") else "")
			_:
				return "leg_front" if alive("leg_front") else ("leg_back" if alive("leg_back") else "")

	func torso_speed() -> float:
		return parts["torso"]["speed"] if alive("torso") else 0.0

	func move_speed() -> float:
		var s := 0.0
		var n := 0
		for slot in ["leg_front", "leg_back"]:
			if alive(slot):
				s += parts[slot]["speed"]
				n += 1
		var leg_factor: float = [0.35, 0.65, 1.0][n]
		return (1.0 + (s / maxf(1, n) + torso_speed()) / 100.0) * leg_factor * spd_mult * eff

	func attack_speed(limb: String) -> float:
		var s: float = parts[limb]["speed"] if alive(limb) else 0.0
		return maxf(0.5, (1.0 + (s + torso_speed()) / 100.0) * spd_mult * eff)

	func get_look() -> Dictionary:
		if look_dirty:
			spec["parts"] = parts
			look = GameData.look_from_spec(spec)
			look_dirty = false
		return look


var player: Fighter
var cpu: Fighter
var opp: Dictionary
var fight_idx := 0
var exhibition := false
var screen := Vector2(1152, 648)
var floor_y := 420.0
var font: Font
var clock := 0.0

var touches := {}
var buttons: Array = []
var held_buttons := {}
var prev_punch := false
var prev_kick := false
var tap_pending := false
var quit_rect := Rect2()
var touch_device := false

var ai_timer := 0.0
var ai_plan := {}
var ai_think := 0.4
var ai_block := 0.2
var ai_smart := 0.0
var ai_damage := 1.0

var phase := "intro"   # intro, fight, ko, results
var phase_timer := 0.0
var time_left := FIGHT_TIME
var ko_text := ""
var won := false
var result := {}
var fight_called := false

var shake := 0.0
var cheer := 0.0
var sparks: Array = []
var debris: Array = []
var smoke: Array = []
var popups: Array = []
var crowd: Array = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	touch_device = DisplayServer.is_touchscreen_available()
	layout()
	fight_idx = GameData.current_opponent_index()
	exhibition = GameData.champion
	opp = GameData.current_opponent()
	player = make_fighter(GameData.player_spec())
	cpu = make_fighter(GameData.opponent_spec(fight_idx))
	var diff: int = GameData.settings["difficulty"]
	ai_think = opp["think"] * DIFF_THINK[diff]
	ai_block = minf(0.85, opp["block"] * DIFF_BLOCK[diff])
	ai_smart = opp["smart"]
	ai_damage = DIFF_DAMAGE[diff]
	cpu.dmg_mult *= ai_damage

	player.pos = Vector2(screen.x * 0.3, floor_y)
	cpu.pos = Vector2(screen.x * 0.7, floor_y)
	cpu.facing = -1
	for k in 70:
		crowd.append({"x": randf() * screen.x, "row": k % 3, "phase": randf() * TAU,
				"color": Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.25, 0.55))})
	crowd.sort_custom(func(a, b): return a["row"] < b["row"])
	Sfx.music("fight")
	Sfx.play("crowd_cheer")
	cheer = 3.0


func make_fighter(spec: Dictionary) -> Fighter:
	var f := Fighter.new()
	f.spec = spec.duplicate()
	f.label = spec["name"]
	f.parts = {}
	for slot in BODY_PARTS:
		f.parts[slot] = (spec["parts"][slot] as Dictionary).duplicate()
	f.eff = spec["efficiency"]
	f.dmg_mult = spec["damage_mult"]
	f.spd_mult = spec["speed_mult"]
	f.scale = spec["scale"]
	return f


func layout() -> void:
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.68
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
	quit_rect = Rect2(w * 0.5 - 55.0, h * 0.04 + 46.0, 110.0, 38.0)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if handle_tap(event.position):
				return
			touches[event.index] = event.position
			tap_pending = true
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	elif event is InputEventMouseButton and not touch_device and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not handle_tap(event.position):
			tap_pending = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			tap_pending = true
		elif event.physical_keycode == KEY_ESCAPE and (phase == "intro" or phase == "fight"):
			quit_fight()


## Quit button and aiming. Returns true if the tap was used.
func handle_tap(p: Vector2) -> bool:
	if phase != "intro" and phase != "fight":
		return false
	if quit_rect.has_point(p):
		quit_fight()
		return true
	for b in buttons:
		if p.distance_to(b["pos"]) <= b["r"] * 1.25:
			return false
	var slot := part_at(cpu, p)
	if slot == "":
		return false
	if player.target == slot:
		player.target = ""
		Sfx.play("untarget")
	else:
		player.target = slot
		Sfx.play("target")
	return true


func to_local_point(f: Fighter, p: Vector2) -> Vector2:
	var l := (p - f.pos) / f.scale
	l.x *= f.facing
	if f.crouching:
		l.y /= 0.7
	return l


func to_world_point(f: Fighter, l: Vector2) -> Vector2:
	var y := l.y * (0.7 if f.crouching else 1.0)
	return f.pos + Vector2(l.x * f.facing, y) * f.scale


func part_at(f: Fighter, p: Vector2) -> String:
	var l := to_local_point(f, p)
	for r in RobotArt.regions(f.get_look()):
		if (r[1] as Rect2).grow(10.0).has_point(l):
			return r[0]
	return ""


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
		ai_pick_target()
		var r := randf()
		var can_punch := cpu.arms() > 0
		var can_kick := cpu.legs() > 0
		if ATTACKS.has(player.state) and dist < 150.0 and cpu.arms() > 0 and randf() < ai_block:
			ai_plan = {"hold": ["block"]}
		elif dist > 120.0 * cpu.scale:
			ai_plan = {"hold": [toward]}
			if r < 0.08:
				ai_plan["tap"] = "up"
		elif r < 0.30 and can_punch:
			ai_plan = {"tap": "punch"}
		elif r < 0.50 and can_kick:
			ai_plan = {"tap": "kick"}
		elif r < 0.60 and can_kick:
			ai_plan = {"hold": ["down"], "tap": "kick"}
		elif r < 0.68 and can_punch:
			ai_plan = {"hold": ["down"], "tap": "punch"}
		elif r < 0.85 and cpu.arms() > 0:
			ai_plan = {"hold": ["block"]}
		elif can_punch:
			ai_plan = {"tap": "punch"}
		elif can_kick:
			ai_plan = {"tap": "kick"}
		else:
			ai_plan = {"hold": [away]}
		ai_plan["fresh"] = true

	for k in ai_plan.get("hold", []):
		i[k] = true
	if ai_plan.get("fresh", false) and ai_plan.has("tap"):
		i[ai_plan["tap"]] = true
	ai_plan["fresh"] = false
	return i


## Smarter opponents aim at your weakest part.
func ai_pick_target() -> void:
	if randf() >= ai_smart:
		cpu.target = ""
		return
	var best := ""
	var best_score := 99.0
	for slot in BODY_PARTS:
		if not player.alive(slot):
			continue
		var score := player.ratio(slot)
		if slot == "torso":
			score += 0.1
		if score < best_score:
			best_score = score
			best = slot
	cpu.target = best


# ---------------------------------------------------------------- game loop

func _process(delta: float) -> void:
	layout()
	clock += delta
	phase_timer += delta

	var p_in := read_player_input()
	var c_in := read_ai_input(delta)
	if phase != "fight":
		p_in = empty_input()
		c_in = empty_input()

	match phase:
		"intro":
			if phase_timer >= 0.4 and not fight_called and phase_timer < 0.5:
				Sfx.play("round")
			if phase_timer >= 1.0 and not fight_called:
				fight_called = true
				Sfx.play("fight")
			if phase_timer >= 1.7:
				phase = "fight"
				phase_timer = 0.0
		"fight":
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				time_up()
		"ko":
			if phase_timer > 2.0 and tap_pending:
				finish_match()
		"results":
			if phase_timer > 1.0 and tap_pending:
				leave_after_results()
	tap_pending = false

	update_fighter(player, cpu, p_in, delta)
	update_fighter(cpu, player, c_in, delta)
	separate()

	if player.target != "" and not cpu.alive(player.target):
		player.target = ""

	update_effects(delta)
	queue_redraw()


func update_effects(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 30.0)
	if not GameData.settings["shake"]:
		shake = 0.0
	cheer = maxf(0.0, cheer - delta)
	for s in sparks:
		s["t"] += delta
	sparks = sparks.filter(func(s): return s["t"] < 0.25)
	for d in debris:
		d["vel"].y += GRAVITY * 0.8 * delta
		d["pos"] += d["vel"] * delta
		d["rot"] += d["rv"] * delta
		if d["pos"].y > floor_y - 4.0:
			d["pos"].y = floor_y - 4.0
			d["vel"].y *= -0.35
			d["vel"].x *= 0.6
			d["rv"] *= 0.5
			if absf(d["vel"].y) > 120.0:
				Sfx.play("land", 0.3, -10.0)
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.4)
	# smoke from badly damaged parts
	for f in [player, cpu]:
		for slot in BODY_PARTS:
			if f.alive(slot) and f.ratio(slot) < 0.3 and randf() < delta * 5.0:
				smoke.append({"pos": to_world_point(f, RobotArt.part_center(f.get_look(), slot)), "t": 0.0})
	for s in smoke:
		s["t"] += delta
		s["pos"] += Vector2(randf_range(-10, 10), -40.0) * delta
	smoke = smoke.filter(func(s): return s["t"] < 1.2)


func time_up() -> void:
	Sfx.play("time")
	var p := player.ratio("torso")
	var c := cpu.ratio("torso")
	var winner := player if p >= c else cpu
	end_by(winner, "TIME!")


func end_by(winner: Fighter, title: String) -> void:
	phase = "ko"
	phase_timer = 0.0
	won = winner == player
	ko_text = title
	cheer = 4.0
	Sfx.play("crowd_cheer")
	var loser := cpu if won else player
	if loser.state != "ko":
		loser.state = "ko"
		loser.vel = Vector2(-loser.facing * 300.0, -400.0)
		loser.on_ground = false


func finish_match() -> void:
	var part_hp := {}
	for slot in BODY_PARTS:
		if not player.parts[slot].is_empty():
			part_hp[slot] = player.parts[slot]["hp"]
	result = GameData.record_result(won, part_hp, cpu.ripped.size(), cpu.ripped)
	phase = "results"
	phase_timer = 0.0
	Sfx.play("victory" if won else "defeat")


func leave_after_results() -> void:
	Sfx.play("click")
	var post := "post_%d" % fight_idx
	if won and not exhibition and GameData.queue_story(post, "res://garage.tscn"):
		get_tree().change_scene_to_file("res://story.tscn")
		return
	get_tree().change_scene_to_file("res://garage.tscn")


func quit_fight() -> void:
	Sfx.play("error")
	# walking out still costs you the damage you took
	var part_hp := {}
	for slot in BODY_PARTS:
		if not player.parts[slot].is_empty():
			part_hp[slot] = maxf(1.0, player.parts[slot]["hp"])
	for slot in part_hp:
		var p := GameData.equipped_inst(slot)
		if not p.is_empty():
			p["hp"] = part_hp[slot]
	GameData.last_result = {"quit": true, "opponent": opp["name"]}
	GameData.save_game()
	get_tree().change_scene_to_file("res://garage.tscn")


func start_attack(f: Fighter, attack: String) -> void:
	var limb := f.limb_for(attack)
	if limb == "":
		return
	f.state = attack
	f.attack_limb = limb
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
		f.timer += delta * f.attack_speed(f.attack_limb)
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
		f.crouching = i["down"] and f.on_ground and f.legs() > 0
		f.blocking = i["block"] and f.on_ground and f.arms() > 0
		if i["punch"] and f.arms() > 0:
			start_attack(f, "uppercut" if f.crouching else "punch")
		elif i["kick"] and f.legs() > 0:
			start_attack(f, "sweep" if f.crouching else "kick")
		elif f.on_ground:
			var dir := 0
			if not f.crouching and not f.blocking:
				dir = int(i["right"]) - int(i["left"])
			var spd := f.move_speed()
			f.vel.x = dir * WALK_SPEED * spd
			f.state = "walk" if dir != 0 else "idle"
			if dir != 0:
				f.walk_phase += delta * 12.0 * spd
				f.step_timer -= delta
				if f.step_timer <= 0.0:
					f.step_timer = 0.28 / maxf(0.4, spd)
					Sfx.play("step", 0.2, -10.0)
			if i["up"] and not f.crouching and not f.blocking and f.legs() > 0:
				f.vel.y = -JUMP_SPEED * (1.0 if f.legs() == 2 else 0.75)
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


func choose_part(att: Fighter, d: Fighter, attack: String) -> String:
	var zone: Dictionary = ZONES[attack]
	if att.target != "" and zone.has(att.target) and d.alive(att.target):
		var accuracy := 0.45 if att.target == "head" else 0.8
		if randf() < accuracy:
			return att.target
	var total := 0.0
	for slot in zone:
		if d.alive(slot):
			total += zone[slot]
	if total <= 0.0:
		return "torso"
	var r := randf() * total
	for slot in zone:
		if d.alive(slot):
			r -= zone[slot]
			if r <= 0.0:
				return slot
	return "torso"


func try_hit(att: Fighter, d: Fighter, a: Dictionary) -> void:
	var dx := (d.pos.x - att.pos.x) * att.facing
	var reach: float = a["reach"] * sqrt(att.scale)
	if dx < -10.0 or dx > reach + 35.0 * d.scale:
		return
	if absf(d.pos.y - att.pos.y) > 130.0:
		return
	if d.state == "ko" or phase != "fight":
		return
	if a["height"] == "high" and d.crouching:
		return  # ducked under it
	if a["height"] == "low" and not d.on_ground:
		return  # jumped over it
	att.hit_done = true

	var limb: Dictionary = att.parts[att.attack_limb] if att.alive(att.attack_limb) else {"damage": 0}
	var dmg: float = a["damage"] * (1.0 + limb["damage"] / 100.0) * att.dmg_mult * att.eff
	var slot := choose_part(att, d, att.state)
	var hit_at := to_world_point(d, RobotArt.part_center(d.get_look(), slot))
	var spark_pos := Vector2(att.pos.x + att.facing * minf(dx, reach), hit_at.y)

	var blocked: bool = d.blocking and d.arms() > 0 and (a["height"] != "low" or d.crouching)
	if blocked:
		# the blocking arm soaks some of it
		var arm := "arm_front" if d.alive("arm_front") else "arm_back"
		damage_part(d, arm, dmg * 0.3)
		d.pos.x += att.facing * 25.0
		add_spark(spark_pos, Color(0.7, 0.85, 1.0), 18.0)
		Sfx.play("block", 0.15)
	else:
		var aim_bonus := 1.0
		if slot == att.target and att.alive("head"):
			aim_bonus += att.parts["head"]["aim"] / 100.0
		var part_dmg := dmg * aim_bonus * (HEAD_FACTOR if slot == "head" else 1.0)
		damage_part(d, slot, part_dmg)
		if slot != "torso" and d.alive("torso"):
			damage_part(d, "torso", dmg * CORE_SHARE)
		if d.state != "ko":
			d.state = "hit"
			d.timer = a["stun"]
			d.crouching = false
			d.blocking = false
			d.vel.x = att.facing * 320.0
			if att.state == "uppercut":
				d.vel.y = -700.0
				d.on_ground = false
		d.flash = 0.12
		shake = maxf(shake, 8.0)
		add_spark(spark_pos, Color(1.0, 0.85, 0.3), 30.0)
		Sfx.play("hit_big" if dmg >= 12.0 else "hit", 0.15)

	if phase == "fight":
		if not d.alive("torso"):
			knockout(att, d, "CORE DESTROYED")
		elif not d.alive("head"):
			knockout(att, d, "HEAD KNOCKED OFF")


func damage_part(f: Fighter, slot: String, amount: float) -> void:
	if not f.alive(slot):
		return
	var p: Dictionary = f.parts[slot]
	p["hp"] -= amount * (1.0 - p["armor"] / 100.0)
	f.look_dirty = true
	if p["hp"] <= 0.0:
		p["hp"] = 0.0
		if slot != "torso":   # a dead torso means a knockout, not a missing torso
			rip_off(f, slot)


func rip_off(f: Fighter, slot: String) -> void:
	var p: Dictionary = f.parts[slot]
	f.ripped.append(p["id"])
	var at := to_world_point(f, RobotArt.part_center(f.get_look(), slot))
	var size := Vector2(46, 14) if slot.begins_with("arm") else (Vector2(16, 52) if slot.begins_with("leg") else Vector2(36, 32))
	if slot == "torso":
		size = Vector2(56, 70)
	debris.append({"pos": at, "vel": Vector2(-f.facing * randf_range(150, 350), randf_range(-650, -400)),
			"rot": 0.0, "rv": randf_range(-12, 12), "size": size * f.scale, "color": p["color"]})
	for k in 3:
		add_spark(at + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(1.0, 0.6, 0.2), 26.0)
	popups.append({"text": "%s LOST!" % PART_LABELS[slot] if f == player else "%s DESTROYED!" % PART_LABELS[slot],
			"pos": at, "t": 0.0, "color": Color(1.0, 0.3, 0.2) if f == player else Color(1.0, 0.85, 0.2)})
	if f.blocking and f.arms() == 0:
		f.blocking = false
	shake = 16.0
	cheer = maxf(cheer, 1.5)
	Sfx.play("break")
	Sfx.play("crowd_ooh", 0.1)


func knockout(att: Fighter, d: Fighter, why: String) -> void:
	d.state = "ko"
	d.vel = Vector2(att.facing * 400.0, -500.0)
	d.on_ground = false
	shake = 14.0
	Sfx.play("ko")
	end_by(att, why)


func separate() -> void:
	var dx := cpu.pos.x - player.pos.x
	var gap := 70.0 * (player.scale + cpu.scale) * 0.5
	if absf(dx) < gap and absf(cpu.pos.y - player.pos.y) < 120.0:
		var push := (gap - absf(dx)) * 0.5
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

	draw_arena(off)
	draw_fighter(cpu, off)
	draw_fighter(player, off)

	for d in debris:
		draw_set_transform(d["pos"] + off, d["rot"], Vector2.ONE)
		var sz: Vector2 = d["size"]
		draw_rect(Rect2(-sz * 0.5, sz), d["color"])
		draw_rect(Rect2(-sz * 0.5, sz), (d["color"] as Color).darkened(0.5), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for s in smoke:
		var t: float = s["t"] / 1.2
		draw_circle(s["pos"] + off, 6.0 + t * 14.0, Color(0.3, 0.3, 0.32, 0.5 * (1.0 - t)))
	for s in sparks:
		var t: float = s["t"] / 0.25
		var c: Color = s["color"]
		c.a = 1.0 - t
		draw_circle(s["pos"] + off, s["size"] * (0.4 + t), c)

	draw_crosshair(off)
	for p in popups:
		var t: float = p["t"] / 1.4
		var c: Color = p["color"]
		c.a = 1.0 - t * t
		draw_string(font, p["pos"] + Vector2(-200, -40.0 - t * 50.0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 28, c)

	draw_hud()
	if phase == "intro" or phase == "fight":
		draw_buttons()


func draw_arena(off: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.07, 0.11))
	# crowd
	var top := screen.y * 0.22
	for c in crowd:
		var row: int = c["row"]
		var y: float = top + row * 34.0 + 20.0
		var bob := 0.0
		if cheer > 0.0:
			bob = -absf(sin(clock * 9.0 + c["phase"])) * 10.0 * minf(1.0, cheer)
		else:
			bob = sin(clock * 1.5 + c["phase"]) * 1.5
		var col: Color = (c["color"] as Color).darkened(0.25 * (2 - row))
		var p := Vector2(c["x"], y + bob) + off * 0.3
		draw_rect(Rect2(p.x - 13, p.y + 6, 26, 40), col.darkened(0.2))
		draw_circle(p, 10.0, col)
		if cheer > 0.5 and int(c["phase"] * 10) % 3 == 0:
			draw_line(p + Vector2(8, 10), p + Vector2(16, -14 + bob * 0.5), col, 5.0)   # arms up
	draw_rect(Rect2(0, top + 95.0, screen.x, floor_y - top - 95.0), Color(0.07, 0.07, 0.11, 0.6))
	for k in range(14):
		draw_circle(Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.19), 5.0, Color(1.0, 0.9, 0.6, 0.45))
	draw_rect(Rect2(Vector2(0, floor_y) + off, Vector2(screen.x, screen.y - floor_y + 20.0)), Color(0.17, 0.17, 0.21))
	draw_line(Vector2(0, floor_y) + off, Vector2(screen.x, floor_y) + off, Color(0.55, 0.55, 0.65), 3.0)
	for k in range(3):
		var y := floor_y - 70.0 - k * 45.0
		draw_line(Vector2(0, y) + off, Vector2(screen.x, y) + off, Color(0.65, 0.1, 0.1, 0.55), 3.0)


func draw_fighter(f: Fighter, off: Vector2) -> void:
	draw_set_transform(Vector2(f.pos.x, floor_y) + off, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 42.0 * f.scale, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := f.pos + off
	var rot := 0.0
	if f.state == "ko":
		if f.on_ground:
			rot = -f.facing * PI / 2.0
			base.y -= 18.0 * f.scale
		else:
			rot = -f.facing * PI / 4.0
	var extended := false
	if ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		extended = f.timer >= a["startup"] * 0.6 and f.timer <= a["startup"] + a["active"] + a["recovery"] * 0.5
	RobotArt.draw(self, base, f.get_look(), {
		"facing": f.facing, "state": f.state, "extended": extended, "attack_limb": f.attack_limb,
		"swing": sin(f.walk_phase) * 10.0 if f.state == "walk" else 0.0,
		"crouch": f.crouching, "blocking": f.blocking, "flash": f.flash > 0.0, "rot": rot, "time": clock,
	})


func draw_crosshair(off: Vector2) -> void:
	if player.target == "" or phase != "fight" and phase != "intro":
		return
	var p := to_world_point(cpu, RobotArt.part_center(cpu.get_look(), player.target)) + off
	var r := 22.0 + sin(clock * 6.0) * 3.0
	var c := Color(1.0, 0.2, 0.2, 0.9)
	draw_arc(p, r, 0.0, TAU, 32, c, 3.0)
	var spin := clock * 2.0
	for k in 4:
		var a := spin + k * PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(p + dir * (r - 8.0), p + dir * (r + 10.0), c, 3.0)
	draw_circle(p, 3.0, c)
	draw_string(font, p + Vector2(-80, -r - 10.0), PART_LABELS[player.target], HORIZONTAL_ALIGNMENT_CENTER, 160, 18, c)


func draw_part_map(f: Fighter, at: Vector2, mirror: bool) -> void:
	## Tiny robot diagram: each box is a part, colored by its health.
	var m := -1.0 if mirror else 1.0
	var boxes := {
		"head": Rect2(-7, 0, 14, 12), "torso": Rect2(-10, 14, 20, 22),
		"arm_front": Rect2(12 * m - (6 if mirror else 0), 14, 6, 20), "arm_back": Rect2(-18 * m - (6 if mirror else 0), 14, 6, 20),
		"leg_front": Rect2(1 * m - (7 if mirror else 0), 38, 7, 18), "leg_back": Rect2(-8 * m - (7 if mirror else 0), 38, 7, 18),
	}
	for slot in boxes:
		var r: Rect2 = boxes[slot]
		r.position += at
		var c := Color(0.25, 0.25, 0.28)
		if f.alive(slot):
			var h := f.ratio(slot)
			c = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.35), h) if h < 1.0 else Color(0.3, 0.9, 0.35)
		draw_rect(r, c)
		if f == cpu and player.target == slot:
			draw_rect(r.grow(2.0), Color(1, 0.2, 0.2), false, 2.0)


func draw_hud() -> void:
	var w := screen.x * 0.33
	var y := screen.y * 0.04
	var bh := 24.0
	var px := 90.0
	var cx := screen.x - 90.0 - w
	# core (torso) bars
	draw_rect(Rect2(px, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(px, y, w * player.ratio("torso"), bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(px, y, w, bh), Color.WHITE, false, 2.0)
	var cw := w * cpu.ratio("torso")
	draw_rect(Rect2(cx, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(cx + w - cw, y, cw, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(cx, y, w, bh), Color.WHITE, false, 2.0)
	draw_string(font, Vector2(px, y + bh + 24), player.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(cx, y + bh + 24), cpu.label, HORIZONTAL_ALIGNMENT_RIGHT, w, 22, Color.WHITE)
	if player.eff < 1.0:
		draw_string(font, Vector2(px + 90, y + bh + 24), "OVERLOADED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.5, 0.2))
	draw_part_map(player, Vector2(40, y), false)
	draw_part_map(cpu, Vector2(screen.x - 40, y), true)

	# fight number, timer, quit
	draw_string(font, Vector2(0, y + 16), "EXHIBITION" if exhibition else "FIGHT %d/%d" % [fight_idx + 1, GameData.OPPONENTS.size()],
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 18, Color(0.8, 0.8, 0.85))
	var tc := Color(1.0, 0.35, 0.3) if time_left < 10.0 else Color.WHITE
	draw_string(font, Vector2(0, y + 44), "%d" % ceili(time_left), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 32, tc)
	if phase == "intro" or phase == "fight":
		draw_rect(quit_rect, Color(1, 1, 1, 0.1))
		draw_rect(quit_rect, Color(1, 1, 1, 0.4), false, 2.0)
		draw_string(font, quit_rect.position + Vector2(0, 27), "QUIT", HORIZONTAL_ALIGNMENT_CENTER, quit_rect.size.x, 19, Color(1, 1, 1, 0.7))
		if phase == "fight" and phase_timer < 6.0 and player.target == "" and fight_idx < 2:
			draw_string(font, Vector2(0, screen.y * 0.36), "Tap a part of %s to aim at it" % cpu.label, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 24, Color(1, 1, 1, 0.7))

	var cy := screen.y * 0.42
	match phase:
		"intro":
			var t := cpu.label if phase_timer < 1.0 else "FIGHT!"
			draw_string(font, Vector2(0, cy), t, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 80, Color(1.0, 0.3, 0.2))
		"ko":
			var big := "K.O." if ko_text != "TIME!" else "TIME!"
			draw_string(font, Vector2(0, cy), big, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 96, Color(1.0, 0.2, 0.1))
			var sub := ko_text if ko_text != "TIME!" else "Judges' decision"
			draw_string(font, Vector2(0, cy + 50), sub, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 30, Color.WHITE)
			draw_string(font, Vector2(0, cy + 90), "%s WINS" % (player.label if won else cpu.label), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 36, Color(1.0, 0.85, 0.2))
			if phase_timer > 2.0:
				draw_string(font, Vector2(0, cy + 130), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 26, Color(0.8, 0.8, 0.8))
		"results":
			draw_results()


func draw_results() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.7))
	var y := screen.y * 0.22
	var title := "VICTORY!" if won else "DEFEAT"
	draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 80, Color(1.0, 0.85, 0.2) if won else Color(0.9, 0.3, 0.3))
	y += 55.0
	var lines: Array = []
	lines.append(["Prize money: +$%d" % result.get("reward", 0), Color(0.95, 0.85, 0.2)])
	if result.get("bonus", 0) > 0:
		lines.append(["Dismantle bonus: +$%d" % result["bonus"], Color(0.95, 0.85, 0.2)])
	for n in result.get("salvaged", []):
		lines.append(["Salvaged: %s" % n, Color(0.5, 1.0, 0.6)])
	for n in result.get("wrecked", []):
		lines.append(["Wrecked (rebuild in Spares): %s" % n, Color(1.0, 0.7, 0.3)])
	for n in result.get("lost", []):
		lines.append(["Lost: %s" % n, Color(1.0, 0.45, 0.4)])
	if result.get("champion", false):
		lines.append(["YOU ARE THE CHAMPION!", Color(1.0, 0.5, 0.2)])
	for l in lines:
		draw_string(font, Vector2(0, y), l[0], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 28, l[1])
		y += 36.0
	if phase_timer > 1.0:
		draw_string(font, Vector2(0, y + 20), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 24, Color(0.8, 0.8, 0.8))


func draw_buttons() -> void:
	for b in buttons:
		var held: bool = held_buttons.get(b["name"], false)
		var fill := Color(1, 1, 1, 0.35 if held else 0.12)
		draw_circle(b["pos"], b["r"], fill)
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		draw_string(font, b["pos"] + Vector2(-b["r"], 10.0), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, 30, Color(1, 1, 1, 0.85))
