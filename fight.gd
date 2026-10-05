extends Node2D
## Championship fight: ECHO vs the current opponent. One knockout bout with a timer.
##
## PARTS: every part (head, torso, 2 arms, 2 legs) has its own health. Tap a part of the enemy to
## aim at it. Parts at 0 are ripped off. Head or torso gone = knockout. Damage carries over.
## COMBOS: hits that land while the enemy is still reeling chain into combos (+8% damage per hit).
##   A normal attack that lands can be cancelled straight into the next one (P, P, K...).
## SPECIALS: training chips teach input sequences (see specials.gd), e.g. down, toward, punch.
## GADGETS: some parts add buttons (rocket fist, laser, shield...) or passive tricks (double jump).
##
## Touch: left pad LEFT/RIGHT move, JUMP, CROUCH | right pad (same diamond shape): BLOCK on top,
##        PUNCH left, KICK right, GRAB bottom | gadget buttons along the bottom middle
##        MOVES (top) pauses and lists your moves
## Keyboard: A/D move, W jump, S crouch, J punch, K kick, L block, H grab, U/I/O gadgets, M moves, Esc quit

const GRAVITY := 2200.0
const WALK_SPEED := 300.0
const JUMP_SPEED := 950.0
const BOT_SCALE := 1.3        # fighters are drawn this much bigger than in the garage
const FIGHT_TIME := 90.0
const UI_SCALE := 1.25
const BUTTON_SCALES := [0.8, 1.0, 1.25]
const DIFF_THINK := [1.4, 1.0, 0.7]
const DIFF_BLOCK := [0.7, 1.0, 1.25]
const DIFF_DAMAGE := [0.75, 1.0, 1.2]
const CORE_SHARE := 0.35      # share of a limb/head hit that also hurts the torso
const HEAD_FACTOR := 0.6      # heads are hard to hit cleanly
const COMBO_BONUS := 0.08     # extra damage per hit in a combo
const BODY_PARTS := ["head", "head2", "torso", "arm_front", "arm_back", "arm_front2", "arm_back2", "leg_front", "leg_back"]
const ARM_SLOTS := ["arm_front", "arm_back", "arm_front2", "arm_back2"]
const PART_LABELS := {"head": "HEAD", "head2": "2ND HEAD", "torso": "TORSO", "arm_front": "FRONT ARM", "arm_back": "BACK ARM",
		"arm_front2": "LOWER FRONT ARM", "arm_back2": "LOWER BACK ARM", "leg_front": "FRONT LEG", "leg_back": "BACK LEG"}
const WEAK_BONUS := 0.15      # extra damage on the part the scanner marks as weakest
const GADGET_KEYS := [KEY_U, KEY_I, KEY_O]

const ATTACKS := {
	"punch":    {"startup": 0.07, "active": 0.10, "recovery": 0.16, "reach": 82.0,  "damage": 7.0,  "height": "high", "stun": 0.22, "limb": "arm", "zone": "punch"},
	"kick":     {"startup": 0.14, "active": 0.10, "recovery": 0.26, "reach": 100.0, "damage": 10.0, "height": "mid",  "stun": 0.28, "limb": "leg", "zone": "kick"},
	"uppercut": {"startup": 0.12, "active": 0.10, "recovery": 0.35, "reach": 72.0,  "damage": 13.0, "height": "mid",  "stun": 0.50, "limb": "arm", "zone": "uppercut", "launch": -700.0},
	"sweep":    {"startup": 0.12, "active": 0.12, "recovery": 0.30, "reach": 105.0, "damage": 8.0,  "height": "low",  "stun": 0.35, "limb": "leg", "zone": "sweep"},
	# grab beats block: slow and short, but can't be blocked
	"grab":     {"startup": 0.14, "active": 0.08, "recovery": 0.45, "reach": 72.0,  "damage": 9.0,  "height": "mid",  "stun": 0.6,  "limb": "arm", "zone": "torso",
			"unblockable": true, "launch": -380.0, "knock": -140.0},
}


class Fighter:
	var label := ""
	var parts := {}
	var spec := {}
	var look := {}
	var look_dirty := true
	var eff := 1.0
	var dmg_mult := 1.0
	var spd_mult := 1.0
	var scale := 1.0
	# where the robot was actually drawn last frame (lunges, leans, squash), so crosshairs stick to the parts
	var vis_base := Vector2.ZERO
	var vis_rot := 0.0
	var vis_sx := 1.0
	var vis_sy := 1.0
	var vis_ok := false
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var facing := 1
	var state := "idle"      # idle, walk, jump, hit, ko, special, or a normal attack name
	var attack_limb := ""
	var timer := 0.0
	var hit_done := false
	var landed := false      # the current attack connected (allows combo cancels)
	var queued := ""         # attack pressed slightly early, waiting for the current one to allow it
	var queued_t := 0.0
	var recovered_at := -10.0   # when this fighter last recovered from being hit
	var flash := 0.0
	var crouching := false
	var blocking := false
	var on_ground := true
	var walk_phase := 0.0
	var step_timer := 0.0
	var target := ""
	var ripped: Array = []
	# specials & combos
	var specials: Array = []
	var cooldowns := {}      # special id or gadget id -> seconds left
	var buffer: Array = []   # [{tok, t}]
	var special_id := ""
	var hits_done := 0
	var projectile_fired := false
	var combo := 0
	var combo_timer := 0.0
	var combo_show := 0.0
	# gadgets
	var gadgets: Array = []  # [{id, slot}]
	var fist_out := {}       # slot -> true while a rocket fist / grapple is flying
	var shield_t := 0.0
	var over_t := 0.0
	var overcharged := false
	var burnout := false
	var counter_t := 0.0
	var invuln_t := 0.0
	var stun_t := 0.0
	var boost_t := 0.0
	var boost_hit := false
	var jet_t := 0.0
	var air_jumps := 0
	var squash := 0.0        # landing squash timer (animation)
	# fighting style, traits and status effects
	var style := "striker"
	var gtraits := {}        # robot-wide traits from reactor / back gear: trait -> value
	var arm_turn := 0        # extra arms take turns punching
	var slow_t := 0.0        # frost
	var hobble_t := 0.0      # leg got hit: slower walking
	var numb_t := 0.0        # arm got hit: weaker hits
	var armor_t := 0.0       # bulwark slam armor buff
	var haste_t := 0.0       # overclock
	var burns: Array = []    # [{slot, dps, t}]

	func alive(slot: String) -> bool:
		return parts.has(slot) and not parts[slot].is_empty() and parts[slot]["hp"] > 0.0

	func ratio(slot: String) -> float:
		if not parts.has(slot) or parts[slot].is_empty():
			return 0.0
		return clampf(parts[slot]["hp"] / parts[slot]["max_hp"], 0.0, 1.0)

	func legs() -> int:
		return int(alive("leg_front")) + int(alive("leg_back"))

	func arms() -> int:
		var n := 0
		for s in ["arm_front", "arm_back", "arm_front2", "arm_back2"]:
			n += int(usable_arm(s))
		return n

	func heads() -> int:
		return int(alive("head")) + int(alive("head2"))

	func extra_arms() -> int:
		return int(alive("arm_front2")) + int(alive("arm_back2"))

	func best_aim() -> float:
		var a := 0.0
		for s in ["head", "head2"]:
			if alive(s):
				a = maxf(a, parts[s].get("aim", 0.0))
		return a

	func usable_arm(slot: String) -> bool:
		return alive(slot) and not fist_out.has(slot)

	func limb_for(kind: String, prefer_back: bool = false) -> String:
		if kind == "arm":
			var order := ["arm_back", "arm_front", "arm_back2", "arm_front2"] if prefer_back else ["arm_front", "arm_back", "arm_front2", "arm_back2"]
			var ok: Array = []
			for s in order:
				if usable_arm(s):
					ok.append(s)
			if ok.is_empty():
				return ""
			if ok.size() > 2:
				return ok[arm_turn % ok.size()]   # four-armed robots punch with each arm in turn
			return ok[0]
		if kind == "leg":
			return "leg_front" if alive("leg_front") else ("leg_back" if alive("leg_back") else "")
		return "torso"

	func has_gadget(id: String) -> bool:
		for g in gadgets:
			if g["id"] == id and gadget_working(g):
				return true
		return false

	func gadget_working(g: Dictionary) -> bool:
		var slot: String = g["slot"]
		return not parts.has(slot) or alive(slot)

	func mod_damage() -> float:
		return dmg_mult * eff * (1.4 if over_t > 0.0 else 1.0) * (0.85 if burnout else 1.0) \
				* (1.15 if style == "striker" else 1.0) * (0.85 if numb_t > 0.0 else 1.0)

	func mod_speed() -> float:
		return spd_mult * eff * (1.5 if over_t > 0.0 else 1.0) * (0.75 if burnout else 1.0) \
				* (0.9 if style == "tank" else 1.0) * (0.65 if slow_t > 0.0 else 1.0) * (1.3 if haste_t > 0.0 else 1.0)

	func torso_speed() -> float:
		return parts["torso"]["speed"] if alive("torso") else 0.0

	func move_speed() -> float:
		var s := 0.0
		var n := 0
		for slot in ["leg_front", "leg_back"]:
			if alive(slot):
				s += parts[slot]["speed"]
				n += 1
		var leg_factor: float = [0.35, 0.65, 1.0][clampi(n, 0, 2)]
		return (1.0 + (s / maxf(1, n) + torso_speed()) / 100.0) * leg_factor * mod_speed() * (0.8 if hobble_t > 0.0 else 1.0)

	func attack_speed(limb: String) -> float:
		var s: float = parts[limb]["speed"] if parts.has(limb) and alive(limb) else 0.0
		var bonus := (1.1 if style == "striker" else 1.0) * (1.0 + 0.08 * extra_arms())
		return maxf(0.5, (1.0 + (s + torso_speed()) / 100.0) * mod_speed() * bonus)

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
var mode := "story"
var title_text := ""
var screen := Vector2(1152, 648)
var floor_y := 420.0
var font: Font
var clock := 0.0

var touches := {}
var buttons: Array = []
var gadget_buttons: Array = []
var held_buttons := {}
var prev_held := {}
var tap_pending := false
var quit_rect := Rect2()
var moves_rect := Rect2()
var touch_device := false
var paused := false

var ai_timer := 0.0
var ai_plan := {}
var ai_think := 0.4
var ai_block := 0.2
var ai_smart := 0.0
var ai_special_cd := 3.0   # CPU waits between specials so it doesn't spam them
var ai_gadget_cd := 1.5
var ai_kit := {"range": 0.0, "air": false}

var phase := "intro"   # intro, fight, ko, results
var phase_timer := 0.0
var time_left := FIGHT_TIME
var ko_text := ""
var won := false
var result := {}
var fight_called := false

var shake := 0.0
var hitstop := 0.0          # tiny freeze on big hits
var slowmo := 0.0           # slow motion after a knockout
var wall_l := 80.0
var wall_r := 1000.0
var cheer := 0.0
var sparks: Array = []
var debris: Array = []
var smoke: Array = []
var popups: Array = []
var rings: Array = []
var projectiles: Array = []
var crowd: Array = []
var arena_id := "fish_market"
var crowd_id := "fishmongers"


func fs(size: float) -> int:
	return int(size * UI_SCALE)


func _ready() -> void:
	font = ThemeDB.fallback_font
	touch_device = DisplayServer.is_touchscreen_available()
	fight_idx = GameData.current_opponent_index()
	mode = GameData.fight_mode()
	exhibition = mode != "story"
	title_text = GameData.fight_title()
	opp = GameData.current_opponent()
	player = make_fighter(GameData.fight_player_spec())
	cpu = make_fighter(GameData.current_opponent_spec())
	layout()
	var diff: int = GameData.settings["difficulty"]
	ai_think = opp["think"] * DIFF_THINK[diff]
	ai_block = minf(0.85, opp["block"] * DIFF_BLOCK[diff])
	ai_smart = opp["smart"]
	cpu.dmg_mult *= DIFF_DAMAGE[diff]
	ai_build_kit()

	player.pos = Vector2(screen.x * 0.3, floor_y)
	cpu.pos = Vector2(screen.x * 0.7, floor_y)
	cpu.facing = -1
	var seed_value := int(GameData.circuit.get("seed", 0)) if mode == "circuit" else 0
	var venue := Arena.pick(mode, fight_idx, seed_value)
	arena_id = venue[0]
	crowd_id = venue[1]
	crowd = Arena.make_crowd(crowd_id, screen)
	var boss := false
	var pick := randi()
	match mode:
		"story", "exhibition":
			boss = fight_idx == GameData.OPPONENTS.size() - 1
			pick = fight_idx
		"circuit":
			boss = fight_idx == int(GameData.circuit["size"]) - 1
			pick = int(GameData.circuit["seed"]) % 97 + fight_idx
	Sfx.music("boss" if boss else Sfx.FIGHT_TRACKS[pick % Sfx.FIGHT_TRACKS.size()])
	Sfx.play("crowd_cheer")
	cheer = 3.0


func make_fighter(spec: Dictionary) -> Fighter:
	var f := Fighter.new()
	f.spec = spec.duplicate()
	f.label = spec["name"]
	f.parts = {}
	for slot in BODY_PARTS:
		f.parts[slot] = (spec["parts"].get(slot, {}) as Dictionary).duplicate()
	f.eff = spec["efficiency"]
	f.dmg_mult = spec["damage_mult"]
	f.spd_mult = spec["speed_mult"]
	f.scale = minf(spec["scale"] * BOT_SCALE, 1.5)   # cap so giants still fit under the HUD
	f.spec["scale"] = f.scale   # draw at the same size the hit boxes use
	f.specials = spec.get("specials", []).duplicate()
	f.gadgets = spec.get("gadgets", []).duplicate()
	f.style = spec.get("style", "striker")
	if Catalog.STYLES.has(f.style):
		var sig: String = Catalog.STYLES[f.style]["signature"]
		if Specials.MOVES.has(sig) and not f.specials.has(sig):
			f.specials.append(sig)
	for t in spec.get("traits", []):
		var tid: String = t["trait"]
		f.gtraits[tid] = f.gtraits.get(tid, 0.0) + Catalog.trait_value(t)
	return f


func layout() -> void:
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.68
	wall_l = screen.x * 0.07
	wall_r = screen.x * 0.93
	var h := screen.y
	var w := screen.x
	var r: float = clampf(h * 0.085, 34.0, 60.0) * BUTTON_SCALES[GameData.settings["button_size"]] * UI_SCALE
	# two mirrored diamonds: movement on the left, actions on the right
	var lc := Vector2(r * 2.75, h - r * 2.4)
	var rc := Vector2(w - r * 2.75, h - r * 2.4)
	buttons = [
		{"name": "left",  "pos": lc + Vector2(-r * 1.55, 0), "r": r, "label": "◀ LEFT"},
		{"name": "right", "pos": lc + Vector2(r * 1.55, 0),  "r": r, "label": "RIGHT ▶"},
		{"name": "up",    "pos": lc + Vector2(0, -r * 1.55), "r": r, "label": "JUMP"},
		{"name": "down",  "pos": lc + Vector2(0, r * 1.3),  "r": r, "label": "CROUCH"},
		{"name": "punch", "pos": rc + Vector2(-r * 1.55, 0), "r": r, "label": "PUNCH"},
		{"name": "kick",  "pos": rc + Vector2(r * 1.55, 0),  "r": r, "label": "KICK"},
		{"name": "block", "pos": rc + Vector2(0, -r * 1.55), "r": r, "label": "BLOCK"},
		{"name": "grab",  "pos": rc + Vector2(0, r * 1.3),  "r": r, "label": "GRAB"},
	]
	# gadget buttons along the bottom middle, one per active gadget (max 3)
	gadget_buttons = []
	if player:
		var active: Array = []
		for g in player.gadgets:
			if Specials.GADGETS[g["id"]]["active"] and active.size() < 3:
				active.append(g)
		var gr := r * 0.72
		for k in active.size():
			var x := w * 0.5 + (k - (active.size() - 1) * 0.5) * gr * 2.4
			gadget_buttons.append({"name": "gadget%d" % k, "gadget": active[k], "pos": Vector2(x, h - gr * 1.25), "r": gr,
					"label": Specials.GADGETS[active[k]["id"]]["short"]})
	quit_rect = Rect2(w * 0.5 - 140.0, h * 0.04 + 52.0, 130.0, 44.0)
	moves_rect = Rect2(w * 0.5 + 10.0, h * 0.04 + 52.0, 130.0, 44.0)


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
		match event.physical_keycode:
			KEY_ENTER, KEY_SPACE:
				tap_pending = true
			KEY_ESCAPE:
				if phase == "intro" or phase == "fight":
					quit_fight()
			KEY_M:
				toggle_pause()


## Quit, moves list and aiming. Returns true if the tap was used.
func handle_tap(p: Vector2) -> bool:
	if paused:
		toggle_pause()
		return true
	if phase != "intro" and phase != "fight":
		return false
	if quit_rect.has_point(p):
		quit_fight()
		return true
	if moves_rect.has_point(p):
		toggle_pause()
		return true
	for b in buttons + gadget_buttons:
		if p.distance_to(b["pos"]) <= b["r"] * 1.2:
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


func toggle_pause() -> void:
	if phase != "fight" and phase != "intro":
		return
	paused = not paused
	touches.clear()
	Sfx.play("click")


func to_local_point(f: Fighter, p: Vector2) -> Vector2:
	var l := (p - f.pos) / f.scale
	l.x *= f.facing
	if f.crouching:
		l.y /= 0.7
	return l


func to_world_point(f: Fighter, l: Vector2) -> Vector2:
	var y := l.y * (0.7 if f.crouching else 1.0)
	return f.pos + Vector2(l.x * f.facing, y) * f.scale


## Same as to_world_point, but follows the drawn pose (lean, lunge, squash).
func visual_point(f: Fighter, l: Vector2) -> Vector2:
	if not f.vis_ok:
		return to_world_point(f, l)
	var v := Vector2(l.x * f.facing * f.scale * f.vis_sx, l.y * (0.7 if f.crouching else 1.0) * f.scale * f.vis_sy)
	return f.vis_base + v.rotated(f.vis_rot)


func visual_local(f: Fighter, p: Vector2) -> Vector2:
	if not f.vis_ok:
		return to_local_point(f, p)
	var v := (p - f.vis_base).rotated(-f.vis_rot)
	return Vector2(v.x / (f.facing * f.scale * f.vis_sx), v.y / ((0.7 if f.crouching else 1.0) * f.scale * f.vis_sy))


func part_at(f: Fighter, p: Vector2) -> String:
	var l := visual_local(f, p)
	for r in RobotArt.regions(f.get_look()):
		if (r[1] as Rect2).grow(10.0).has_point(l):
			return r[0]
	return ""


func empty_input() -> Dictionary:
	return {"left": false, "right": false, "up": false, "down": false, "block": false,
			"punch": false, "kick": false, "grab": false, "up_press": false, "gadget": -1}


func key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func read_player_input() -> Dictionary:
	held_buttons = {}
	for b in buttons + gadget_buttons:
		held_buttons[b["name"]] = false
	for t in touches.values():
		for b in buttons + gadget_buttons:
			if t.distance_to(b["pos"]) <= b["r"] * 1.2:
				held_buttons[b["name"]] = true
	var now := {
		"left": held_buttons["left"] or key(KEY_A) or key(KEY_LEFT),
		"right": held_buttons["right"] or key(KEY_D) or key(KEY_RIGHT),
		"up": held_buttons["up"] or key(KEY_W) or key(KEY_UP),
		"down": held_buttons["down"] or key(KEY_S) or key(KEY_DOWN),
		"block": held_buttons["block"] or key(KEY_L),
		"punch": held_buttons["punch"] or key(KEY_J),
		"kick": held_buttons["kick"] or key(KEY_K),
		"grab": held_buttons["grab"] or key(KEY_H),
	}
	for k in gadget_buttons.size():
		now["gadget%d" % k] = held_buttons["gadget%d" % k] or key(GADGET_KEYS[k])
	var i := empty_input()
	for k in ["left", "right", "up", "down", "block"]:
		i[k] = now[k]
	i["punch"] = now["punch"] and not prev_held.get("punch", false)
	i["kick"] = now["kick"] and not prev_held.get("kick", false)
	i["grab"] = now["grab"] and not prev_held.get("grab", false)
	i["up_press"] = now["up"] and not prev_held.get("up", false)
	for k in gadget_buttons.size():
		if now["gadget%d" % k] and not prev_held.get("gadget%d" % k, false):
			i["gadget"] = k
	# record direction presses for special-move sequences
	for d in ["left", "right", "up", "down"]:
		if now[d] and not prev_held.get(d, false):
			push_token(player, dir_token(player, d))
	prev_held = now
	return i


func dir_token(f: Fighter, d: String) -> String:
	match d:
		"right":
			return "F" if f.facing == 1 else "B"
		"left":
			return "B" if f.facing == 1 else "F"
		"up":
			return "U"
	return "D"


func push_token(f: Fighter, tok: String) -> void:
	f.buffer.append({"tok": tok, "t": clock})
	if f.buffer.size() > 10:
		f.buffer.pop_front()


## If the input buffer + this button completes a special the fighter knows, return its id.
func match_special(f: Fighter, button: String) -> String:
	var best := ""
	var best_len := 0
	for id in f.specials:
		var m: Dictionary = Specials.MOVES[id]
		var seq: Array = m["seq"]
		if seq[-1] != button or seq.size() <= best_len:
			continue
		var need := seq.size() - 1
		# the button press itself is the last thing in the buffer: skip it, match what came before
		var buf: Array = f.buffer
		if not buf.is_empty() and buf[-1]["tok"] == button and clock - buf[-1]["t"] < 0.5:
			buf = buf.slice(0, buf.size() - 1)
		if buf.size() < need:
			continue
		var ok := true
		var last_t := clock
		for k in need:
			var e: Dictionary = buf[buf.size() - 1 - k]
			if e["tok"] != seq[need - 1 - k] or last_t - e["t"] > Specials.SEQ_WINDOW:
				ok = false
				break
			last_t = e["t"]
		if ok and can_special(f, id):
			best = id
			best_len = seq.size()
	return best


func can_special(f: Fighter, id: String) -> bool:
	var m: Dictionary = Specials.MOVES[id]
	if f.cooldowns.get(id, 0.0) > 0.0:
		return false
	if m.get("air", false) != (not f.on_ground):
		return false
	if m.has("limb") and f.limb_for(m["limb"]) == "":
		return false
	return true


func read_ai_input(delta: float) -> Dictionary:
	var i := empty_input()
	if phase != "fight":
		return i
	ai_timer -= delta
	ai_special_cd -= delta
	ai_gadget_cd -= delta
	var dx := player.pos.x - cpu.pos.x
	var dist := absf(dx)
	var toward := "right" if dx > 0 else "left"
	var away := "left" if dx > 0 else "right"

	# react to incoming shots: shield, jump over, or block (smarter bots react more often)
	for p in projectiles:
		if p["owner"] != player or p["returning"] or p.get("ai_seen", false):
			continue
		var pdx: float = cpu.pos.x - p["pos"].x
		if absf(pdx) < 300.0 and signf(pdx) == signf(p["vel"].x):
			p["ai_seen"] = true
			if not cpu.on_ground and cpu.air_jumps > 0 and randf() < 0.4 + ai_smart * 0.5:
				ai_plan = {"hold": ["up", away], "fresh": true, "air": true, "air_in": false, "dj_now": true}   # jet over it
				ai_timer = 0.4
			elif randf() < 0.25 + ai_smart * 0.6 and cpu.state in ["idle", "walk"]:
				var sh := ai_gadget("shield")
				if not sh.is_empty():
					use_gadget(cpu, sh)
				elif cpu.legs() > 0 and cpu.on_ground and randf() < 0.6:
					ai_plan = {"hold": ["up", away], "fresh": true}
				elif cpu.arms() > 0:
					ai_plan = {"hold": ["block"], "fresh": true}
				ai_timer = 0.4

	if ai_timer <= 0.0:
		ai_timer = randf_range(ai_think * 0.5, ai_think)
		ai_pick_target()
		ai_plan = ai_decide(dist, toward, away)
		ai_plan["fresh"] = true

	for k in ai_plan.get("hold", []):
		i[k] = true
	if ai_plan.get("fresh", false) and ai_plan.has("tap"):
		i[ai_plan["tap"]] = true
	ai_plan["fresh"] = false
	var melee := 82.0 * cpu.scale + 25.0 * player.scale
	# follow-up after a hook / EMP / booster: they're helpless, so hit them with the best thing we have
	if ai_plan.get("follow", "") != "" and (player.state == "hit" or player.stun_t > 0.0 or dist < melee) and dist < melee + 40.0 and cpu.state in ["idle", "walk"]:
		var punish := ai_pick_special(dist, false, true)
		if punish != "":
			start_special(cpu, punish)
		else:
			i[ai_plan["follow"]] = true
		ai_plan["follow"] = ""
	# jet packs: second jump at the top of the first one (or right now, to hop over a shot)
	if ai_plan.get("air", false) and not cpu.on_ground and cpu.air_jumps > 0 and (ai_plan.get("dj_now", false) or (cpu.vel.y > -150.0 and randf() < 0.25)):
		i["up_press"] = true
		ai_plan["dj_now"] = false
		var ad := toward if ai_plan.get("air_in", true) else away
		i[ad] = true
	# booster in the air: rocket down onto them from above
	if not cpu.on_ground and cpu.state == "jump" and ai_plan.get("air_in", false) and dist < 300.0 and dist > 90.0:
		var bo := ai_gadget("booster")
		if not bo.is_empty() and randf() < 0.1 + ai_smart * 0.1:
			use_gadget(cpu, bo)
	# combo cancel: a normal that landed flows straight into a special
	if ATTACKS.has(cpu.state) and cpu.landed and not ai_plan.get("cancel_tried", false) \
			and cpu.timer >= ATTACKS[cpu.state]["startup"] + ATTACKS[cpu.state]["active"]:
		ai_plan["cancel_tried"] = true
		if randf() < 0.15 + ai_smart * 0.55:
			var chain := ai_pick_special(dist, false, true)
			if chain != "":
				start_special(cpu, chain)
	# in the air above the enemy: dive stomp if we know it
	if not cpu.on_ground and cpu.state == "jump" and dist < 200.0 and cpu.specials.has("dive_stomp") and can_special(cpu, "dive_stomp") and randf() < 0.08 + ai_smart * 0.15:
		start_special(cpu, "dive_stomp")
	# combo: smarter bots follow up a landed hit
	if ATTACKS.has(cpu.state) and cpu.landed and randf() < ai_smart * 0.08 + (0.05 if cpu.style == "striker" else 0.0):
		i["punch" if randf() < 0.6 else "kick"] = true
	return i


## The CPU's plan for the next fraction of a second, built around the parts it actually has.
func ai_decide(dist: float, toward: String, away: String) -> Dictionary:
	var free := cpu.state in ["idle", "walk", "jump"]
	var can_punch := cpu.arms() > 0
	var can_kick := cpu.legs() > 0
	var melee := 82.0 * cpu.scale + 25.0 * player.scale
	# threatened = their attack is still coming; once it's in recovery they're open to a punish
	var threatened := false
	var p_open := player.stun_t > 0.0
	if ATTACKS.has(player.state):
		var pa: Dictionary = ATTACKS[player.state]
		threatened = player.timer <= pa["startup"] + pa["active"]
		p_open = p_open or not threatened
	elif player.state == "special":
		var pm: Dictionary = Specials.MOVES[player.special_id]
		threatened = not pm.get("nohit", false) and player.timer <= pm["startup"] + pm["active"]
		p_open = p_open or not threatened
	var hurt := cpu.ratio("torso")
	var aggro: bool = cpu.over_t > 0.0 or cpu.haste_t > 0.0 or cpu.style == "striker"
	var r := randf()

	# 1) gadgets, used for what they're good at
	if free and ai_gadget_cd <= 0.0:
		var plan := ai_use_gadgets(dist, threatened, toward)
		if not plan.is_empty():
			ai_gadget_cd = randf_range(0.6, 1.4) - ai_smart * 0.4
			return plan
	# 2) special moves
	if free:
		var special := ai_pick_special(dist, threatened)
		if special != "":
			start_special(cpu, special)
			return {}
	# punish a whiffed attack
	if p_open and dist < melee + 20.0 and randf() < 0.45 + ai_smart * 0.45:
		if can_punch and (randf() < 0.6 or not can_kick):
			return {"tap": "punch"}
		if can_kick:
			return {"tap": "kick"}
	# 3) defend
	if threatened and dist < 170.0 * cpu.scale:
		if cpu.arms() > 0 and (randf() < ai_block or (cpu.style == "tank" and randf() < 0.5)):
			return {"hold": ["block"]}
		if aggro and dist < melee and can_punch and randf() < 0.4:
			return {"tap": "punch"}   # strikers trade blows
		if ai_kit["air"] and can_kick and randf() < 0.45:
			return {"hold": ["up", away], "air": true, "air_in": false}   # jump away
		return {"hold": [away]}
	# grab beats a turtle
	if player.blocking and dist < 100.0 * cpu.scale and can_punch and randf() < 0.3 + ai_smart * 0.5:
		return {"tap": "grab"}
	# 4) self-repairing robots back off to heal when hurt
	if (cpu.style == "mechanic" or cpu.has_gadget("regen")) and hurt < 0.4 and dist < 320.0 and randf() < 0.55:
		return {"hold": [away]}
	# 5) shooters keep their distance while a shot is ready
	if ai_kit["range"] > 0.0 and ai_ranged_ready() and not aggro:
		var want: float = ai_kit["range"]
		var near_wall := cpu.pos.x < wall_l + 140.0 or cpu.pos.x > wall_r - 140.0
		if dist < want * 0.7 and not near_wall:
			if ai_kit["air"] and randf() < 0.3:
				return {"hold": ["up", away], "air": true, "air_in": false}
			return {"hold": [away]}
		if dist > want * 1.4:
			return {"hold": [toward]}
		if dist > melee:
			return {"hold": ["down"]} if randf() < 0.3 else {}   # wait for the gadget, duck under high shots
	# cornered: jump gadgets vault right over the enemy
	var cornered := (cpu.pos.x < wall_l + 130.0 * cpu.scale and toward == "right") or (cpu.pos.x > wall_r - 130.0 * cpu.scale and toward == "left")
	if cornered and dist < 220.0 * cpu.scale and ai_kit["air"] and cpu.on_ground and randf() < 0.3 + ai_smart * 0.4:
		return {"hold": ["up", toward], "air": true, "air_in": true}
	# 6) jumpers come in from above
	if ai_kit["air"] and can_kick and dist > melee and dist < 420.0 and randf() < 0.35:
		return {"hold": ["up", toward], "air": true, "air_in": true}
	# 7) close the distance
	if dist > melee:
		var plan := {"hold": [toward]}
		if r < 0.06 and can_kick:
			plan["tap"] = "up_press"
		return plan
	# 8) up close
	if cpu.has_gadget("thorns") and not threatened and randf() < 0.3:
		return {"hold": ["down"]} if randf() < 0.3 else {}   # spiky bots stand there and dare you to hit the spikes
	var atk := 0.68 if aggro else 0.55
	if cpu.style == "tank":
		atk = 0.45
	if r < atk * 0.45 and can_punch:
		return {"tap": "punch"}
	if r < atk * 0.75 and can_kick:
		return {"tap": "kick"}
	if r < atk * 0.88 and can_kick:
		return {"hold": ["down"], "tap": "kick"}
	if r < atk and can_punch:
		return {"hold": ["down"], "tap": "punch"}
	if r < 0.88 and cpu.arms() > 0:
		return {"hold": ["block"]}
	if can_punch:
		return {"tap": "punch"}
	if can_kick:
		return {"tap": "kick"}
	return {"hold": [away]}


func ai_pick_special(dist: float, threatened: bool = false, punish: bool = false) -> String:
	if cpu.specials.is_empty() or (ai_special_cd > 0.0 and not punish):
		return ""
	var best := ""
	var best_score := 0.0
	var total := 0.0
	var scores := {}
	for id in cpu.specials:
		if not can_special(cpu, id):
			continue
		var sc := ai_special_score(id, dist, threatened, punish)
		if sc > 0.0:
			scores[id] = sc
			total += sc
			if sc > best_score:
				best_score = sc
				best = id
	if best == "":
		return ""
	# situational moves (anti-air, counters, punishes) get used much more often than "just because"
	var gate := 0.35 + ai_smart * 0.45 if best_score >= 3.0 else 0.1 + ai_smart * 0.2
	if not punish and randf() > gate:
		return ""
	var pick := best
	if randf() > 0.4 + ai_smart * 0.5:
		var r := randf() * total
		for id in scores:
			r -= scores[id]
			if r <= 0.0:
				pick = id
				break
	ai_special_cd = randf_range(1.6, 3.5) - ai_smart
	return pick


## How good a special move is right now (0 = don't).
func ai_special_score(id: String, dist: float, threatened: bool, punish: bool) -> float:
	var m: Dictionary = Specials.MOVES[id]
	var reach: float = (m.get("reach", 0.0) + m.get("dash", 0.0) * m.get("active", 0.0) * 0.6) * cpu.scale + 30.0 * player.scale
	var in_reach := dist < reach
	var p_air := not player.on_ground
	var p_open: bool = punish or player.state == "hit" or player.stun_t > 0.0 \
			or (ATTACKS.has(player.state) and player.timer > ATTACKS[player.state]["startup"] + ATTACKS[player.state]["active"])
	var lined := absf(player.pos.y - cpu.pos.y) < 120.0
	var behind_wall := (player.pos.x < wall_l + 160.0 and player.pos.x < cpu.pos.x) or (player.pos.x > wall_r - 160.0 and player.pos.x > cpu.pos.x)
	if m.get("air", false):
		return 0.0   # dive stomp is used while jumping
	match id:
		"field_repair":
			return 3.5 if cpu.ratio("torso") < 0.55 and dist > 240.0 and not punish else 0.0
		"overclock":
			if punish or dist < 180.0:
				return 0.0
			for g in cpu.gadgets:
				if Specials.GADGETS[g["id"]]["active"] and cpu.cooldowns.get(g["id"], 0.0) > 2.0:
					return 3.0
			return 0.0
		"counter_protocol":
			return 4.5 if threatened and dist < 170.0 * cpu.scale else 0.0
		"rising_piston":
			if p_air and dist < 170.0 * cpu.scale:
				return 4.5   # anti-air
			if p_open and in_reach:
				return 2.5
			return 2.0 if threatened and dist < 140.0 * cpu.scale else 0.0
		"grab_slam":
			if not in_reach:
				return 0.0
			return 4.0 if player.blocking else (1.5 if p_open else 0.6)
		"emp_pulse":
			if not in_reach:
				return 0.0
			return 3.5 if player.blocking or threatened else 0.8
		"scissor_sweep":
			if not in_reach or p_air or player.crouching:
				return 0.0
			return 3.0 if player.blocking else 1.2   # standing guard can't stop a low
		"haymaker":
			if not in_reach:
				return 0.0
			return 4.0 if p_open else 0.5   # slow wind-up: only when it can't be punished
		"shoulder_charge", "bulwark_slam":
			if not in_reach:
				return 0.0
			if behind_wall:
				return 3.5   # pin them against the ropes
			if id == "bulwark_slam" and (threatened or cpu.ratio("torso") < 0.5):
				return 3.0
			return 1.0
		"rocket_punch":
			if not in_reach:
				return 0.0
			return 3.0 if dist > 150.0 * cpu.scale else (2.0 if p_open else 0.8)   # gap closer
		"bolt_toss":
			if punish:
				return 0.0
			return 2.5 if dist > 230.0 and lined else 0.0
	# generic: projectiles at range, multi-hit combos up close
	if m.has("projectile"):
		return 2.0 if dist > 230.0 and lined and not punish else 0.0
	if m.get("nohit", false) or m.has("counter"):
		return 0.0
	if not in_reach:
		return 0.0
	if m.get("hits", 1) > 1:
		return 3.5 if p_open else 1.2   # combo extenders
	return 2.0 if p_open else 1.0


func ai_gadget(id: String) -> Dictionary:
	for g in cpu.gadgets:
		if g["id"] == id and cpu.gadget_working(g) and cpu.cooldowns.get(id, 0.0) <= 0.0:
			if id in ["rocket_fist", "grapple"] and cpu.fist_out.has(g["slot"]):
				continue
			return g
	return {}


func ai_ranged_ready() -> bool:
	for id in ["rocket_fist", "laser", "cannon", "grapple"]:
		for g in cpu.gadgets:
			if g["id"] == id and cpu.gadget_working(g) and cpu.cooldowns.get(id, 0.0) < 1.2:
				return true
	return cpu.specials.has("bolt_toss") and cpu.cooldowns.get("bolt_toss", 0.0) < 1.0


## Uses a gadget when it makes sense and returns what to do next ({} = nothing used).
func ai_use_gadgets(dist: float, threatened: bool, toward: String) -> Dictionary:
	var lined_up := absf(player.pos.y - cpu.pos.y) < 120.0
	var g := {}
	g = ai_gadget("shield")
	if not g.is_empty() and threatened and dist < 200.0 * cpu.scale and randf() < 0.4 + ai_smart * 0.4:
		use_gadget(cpu, g)
		return {"hold": [toward]}   # walk through their attack behind the bubble
	g = ai_gadget("emp")
	if not g.is_empty() and dist < 200.0 and (player.blocking or threatened or randf() < 0.35):
		use_gadget(cpu, g)
		return {"hold": [toward], "follow": "punch"}   # stunned enemy: go hit it
	g = ai_gadget("grapple")
	if not g.is_empty() and dist > 180.0 and dist < 540.0 and lined_up:
		use_gadget(cpu, g)
		return {"follow": "punch"}   # reel in, then punch
	for id in ["cannon", "laser", "rocket_fist"]:
		g = ai_gadget(id)
		if not g.is_empty() and dist > 170.0 and lined_up and player.invuln_t <= 0.0 and randf() < 0.35 + ai_smart * 0.5:
			use_gadget(cpu, g)
			return {}
	g = ai_gadget("booster")
	var whiffed: bool = ATTACKS.has(player.state) and player.timer > ATTACKS[player.state]["startup"] + ATTACKS[player.state]["active"]
	if not g.is_empty() and dist > 160.0 and dist < 620.0 and lined_up and (whiffed or player.stun_t > 0.0 or randf() < 0.45):
		use_gadget(cpu, g)
		return {"follow": "kick"}
	g = ai_gadget("overcharge")
	if not g.is_empty() and ((dist < 260.0 and cpu.ratio("torso") > 0.3) or cpu.ratio("torso") < 0.5):
		use_gadget(cpu, g)
		return {"hold": [toward]}   # burn it while it lasts
	return {}


## What the CPU's parts are good at (worked out once, at the start of the fight).
func ai_build_kit() -> void:
	ai_kit = {"range": 0.0, "air": false}
	for g in cpu.gadgets:
		match g["id"]:
			"laser", "cannon":
				ai_kit["range"] = maxf(ai_kit["range"], 420.0)
			"rocket_fist":
				ai_kit["range"] = maxf(ai_kit["range"], 320.0)
			"grapple":
				ai_kit["range"] = maxf(ai_kit["range"], 300.0)
			"double_jump", "high_jump":
				ai_kit["air"] = true
	if cpu.specials.has("bolt_toss"):
		ai_kit["range"] = maxf(ai_kit["range"], 380.0)
	if cpu.specials.has("rocket_punch") or cpu.specials.has("shoulder_charge"):
		ai_kit["dash"] = true
	if cpu.specials.has("dive_stomp"):
		ai_kit["air"] = true


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
	if paused:
		queue_redraw()
		return
	if hitstop > 0.0:
		hitstop -= delta
		queue_redraw()
		return
	if slowmo > 0.0:
		slowmo -= delta
		delta *= 0.35
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
	update_projectiles(delta)

	if player.target != "" and not cpu.alive(player.target):
		player.target = ""
	if cpu.target != "" and not player.alive(cpu.target):
		cpu.target = ""

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
	for r in rings:
		r["t"] += delta
	rings = rings.filter(func(r): return r["t"] < 0.4)
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
	for f in [player, cpu]:
		for slot in BODY_PARTS:
			if f.alive(slot) and f.ratio(slot) < 0.3 and randf() < delta * 5.0:
				smoke.append({"pos": to_world_point(f, RobotArt.part_center(f.get_look(), slot)), "t": 0.0, "dark": false})
		if f.burnout and randf() < delta * 6.0:
			smoke.append({"pos": f.pos + Vector2(-f.facing * 20.0, -90.0 * f.scale), "t": 0.0, "dark": true})
	for s in smoke:
		s["t"] += delta
		s["pos"] += Vector2(randf_range(-10, 10), -40.0) * delta
	smoke = smoke.filter(func(s): return s["t"] < 1.2)


func popup(text: String, at: Vector2, color: Color) -> void:
	popups.append({"text": text, "pos": at, "t": 0.0, "color": color})


func time_up() -> void:
	Sfx.play("time")
	var winner := player if player.ratio("torso") >= cpu.ratio("torso") else cpu
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
	if mode == "quick":
		result = {"won": won, "reward": 0}
		phase = "results"
		phase_timer = 0.0
		Sfx.play("victory" if won else "defeat")
		return
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
	if mode == "quick":
		GameData.quick = {}
		get_tree().change_scene_to_file("res://main.tscn")
		return
	var post := "post_%d" % fight_idx
	if won and not exhibition and GameData.queue_story(post, "res://garage.tscn"):
		get_tree().change_scene_to_file("res://story.tscn")
		return
	get_tree().change_scene_to_file("res://garage.tscn")


func quit_fight() -> void:
	Sfx.play("error")
	if mode == "quick":
		GameData.quick = {}
		get_tree().change_scene_to_file("res://main.tscn")
		return
	for slot in BODY_PARTS:
		if not player.parts[slot].is_empty():
			var p := GameData.equipped_inst(slot)
			if not p.is_empty():
				p["hp"] = maxf(1.0, player.parts[slot]["hp"])
	GameData.last_result = {"quit": true, "opponent": opp["name"]}
	GameData.save_game()
	get_tree().change_scene_to_file("res://garage.tscn")


# ---------------------------------------------------------------- moves

func start_attack(f: Fighter, attack: String) -> void:
	var a: Dictionary = ATTACKS[attack]
	var limb := f.limb_for(a["limb"], attack == "uppercut")
	if limb == "":
		return
	f.state = attack
	f.attack_limb = limb
	f.arm_turn += 1
	f.timer = 0.0
	f.hit_done = false
	f.landed = false
	f.blocking = false
	f.crouching = attack == "sweep"
	Sfx.play("uppercut" if attack == "uppercut" else ("equip" if attack == "grab" else "swing"), 0.15)


## Fire the buffered attack (or a special, if the buffered button completes a sequence).
func start_queued(f: Fighter) -> bool:
	var q := f.queued
	f.queued = ""
	var button := "P" if q == "punch" or q == "uppercut" else "K"
	var sp := match_special(f, button)
	if sp != "":
		start_special(f, sp)
		return true
	var a: Dictionary = ATTACKS[q]
	if f.limb_for(a["limb"], q == "uppercut") == "":
		return false
	start_attack(f, q)
	return true


func start_special(f: Fighter, id: String) -> void:
	var m: Dictionary = Specials.MOVES[id]
	f.state = "special"
	f.special_id = id
	f.attack_limb = f.limb_for(m["limb"]) if m.has("limb") else ""
	f.timer = 0.0
	f.hits_done = 0
	f.hit_done = false
	f.landed = false
	f.projectile_fired = false
	f.blocking = false
	f.crouching = m.get("pose", "") == "sweep"
	f.cooldowns[id] = m["cd"]
	f.buffer.clear()
	if m.has("rise"):
		f.vel.y = -m["rise"]
		f.on_ground = false
	if m.has("counter"):
		f.counter_t = m["counter"]
	if m.has("invuln"):
		f.invuln_t = m["invuln"]
	match m.get("effect", ""):
		"armor_up":
			f.armor_t = 4.0
		"repair":
			var heal_t: float = f.parts["torso"]["max_hp"] * 0.22
			f.parts["torso"]["hp"] = minf(f.parts["torso"]["max_hp"], f.parts["torso"]["hp"] + heal_t)
			var worst := ""
			for slot in BODY_PARTS:
				if slot != "torso" and f.alive(slot) and (worst == "" or f.ratio(slot) < f.ratio(worst)):
					worst = slot
			if worst != "":
				f.parts[worst]["hp"] = minf(f.parts[worst]["max_hp"], f.parts[worst]["hp"] + f.parts[worst]["max_hp"] * 0.3)
			f.look_dirty = true
			rings.append({"pos": f.pos + Vector2(0, -90.0 * f.scale), "t": 0.0, "color": Color(0.3, 1.0, 0.5), "r": 140.0})
			Sfx.play("repair")
		"overclock":
			for g in f.gadgets:
				if g["id"] != "overcharge":
					f.cooldowns[g["id"]] = 0.0
			f.haste_t = 4.0
			rings.append({"pos": f.pos + Vector2(0, -90.0 * f.scale), "t": 0.0, "color": Color(0.75, 0.45, 1.0), "r": 160.0})
	popup(m["name"].to_upper() + "!", f.pos + Vector2(0, -230.0 * f.scale), Color(0.5, 0.9, 1.0) if f == player else Color(1.0, 0.6, 0.3))
	Sfx.play("uppercut", 0.1)
	Sfx.play("target", 0.2, -6.0)


func update_special(f: Fighter, o: Fighter, delta: float) -> void:
	var m: Dictionary = Specials.MOVES[f.special_id]
	var spd := f.attack_speed(f.attack_limb) if f.attack_limb != "" else f.mod_speed()
	f.timer += delta * spd
	var st: float = m["startup"]
	var act: float = m["active"]
	var active := f.timer >= st and f.timer <= st + act
	if active and m.has("dash"):
		f.vel.x = f.facing * m["dash"] * f.scale
	elif f.on_ground:
		f.vel.x = move_toward(f.vel.x, 0.0, 3000.0 * delta)
	if active and m.has("dive"):
		f.vel.y = m["dive"]
	if m.has("projectile"):
		if f.timer >= st and not f.projectile_fired:
			f.projectile_fired = true
			fire_projectile(f, m["projectile"], m["damage"] * f.mod_damage(), m["zone"])
	elif not m.has("counter") and not m.get("nohit", false):
		var hits: int = m.get("hits", 1)
		if hits == 1:
			if active and not f.hit_done:
				try_hit(f, o, m)
		else:
			var interval: float = m.get("interval", 0.12)
			if active and f.hits_done < hits and f.timer >= st + f.hits_done * interval:
				f.hits_done += 1
				var hit := m.duplicate()
				if m.get("finisher", false) and f.hits_done == hits:
					hit["launch"] = -650.0
					hit["knock"] = 450.0
					hit["damage"] = m["damage"] * 2.0
				f.hit_done = false
				try_hit(f, o, hit)
	if f.timer >= st + act + m.get("recovery", 0.2):
		f.state = "idle" if f.on_ground else "jump"
		f.crouching = false
		f.counter_t = 0.0


func use_gadget(f: Fighter, g: Dictionary) -> void:
	var id: String = g["id"]
	var info: Dictionary = Specials.GADGETS[id]
	if f.cooldowns.get(id, 0.0) > 0.0 or not f.gadget_working(g) or f.state in ["ko", "hit"] or f.stun_t > 0.0:
		return
	var o := cpu if f == player else player
	match id:
		"rocket_fist", "grapple":
			if f.fist_out.has(g["slot"]):
				return
			f.fist_out[g["slot"]] = true
			var arm: Dictionary = f.parts[g["slot"]]
			var dmg: float = (12.0 if id == "rocket_fist" else 5.0) * (1.0 + arm["damage"] / 100.0) * f.mod_damage()
			fire_projectile(f, "fist" if id == "rocket_fist" else "claw", dmg, "punch", g["slot"])
			Sfx.play("uppercut", 0.1)
		"laser":
			fire_projectile(f, "laser", 9.0 * f.mod_damage(), "any")
			Sfx.play("target", 0.1)
		"cannon":
			fire_projectile(f, "shell", 16.0 * f.mod_damage(), "any")
			Sfx.play("hit_big", 0.1)
			f.vel.x -= f.facing * 200.0
		"overcharge":
			if f.overcharged:
				return
			f.overcharged = true
			f.over_t = 6.0
			popup("OVERCHARGE!", f.pos + Vector2(0, -230.0 * f.scale), Color(1.0, 0.3, 0.5))
			Sfx.play("uppercut")
			Sfx.play("crowd_ooh", 0.1)
		"emp":
			rings.append({"pos": f.pos + Vector2(0, -80.0 * f.scale), "t": 0.0, "color": Color(0.7, 0.55, 1.0), "r": 220.0})
			Sfx.play("spark")
			Sfx.play("block")
			if absf(o.pos.x - f.pos.x) < 220.0 * f.scale and o.state != "ko":
				apply_hit(f, o, {"damage": 6.0 * f.mod_damage(), "zone": "head_torso", "unblockable": true,
						"emp": 1.0, "knock": 120.0, "stun": 0.3}, o.pos + Vector2(0, -90))
		"shield":
			f.shield_t = 2.5
			Sfx.play("repair", 0.1)
		"booster":
			f.boost_t = 0.3
			f.boost_hit = false
			if not f.on_ground:
				f.vel.y = minf(f.vel.y, -150.0)
			Sfx.play("swing")
			Sfx.play("jump", 0.2)
	f.cooldowns[id] = info["cd"] * (0.6 if f.style == "specialist" else 1.0)


func shoulder_key(slot: String) -> String:
	if slot.begins_with("arm"):
		return slot.replace("arm", "shoulder")
	return "shoulder_front"


func fire_projectile(f: Fighter, kind: String, dmg: float, zone: String, slot: String = "") -> void:
	var start := f.pos + Vector2(f.facing * 50.0, -110.0) * f.scale
	if slot != "":
		var g := RobotArt.geom(f.get_look())
		start = to_world_point(f, g[shoulder_key(slot)] + Vector2(40, 10))
	elif kind == "laser" and (f.alive("head") or f.alive("head2")):
		var hs := "head" if f.alive("head") else "head2"
		start = to_world_point(f, RobotArt.part_center(f.get_look(), hs) + Vector2(24, 0))
	elif kind == "shell":
		start = to_world_point(f, (RobotArt.geom(f.get_look())["torso"] as Rect2).get_center() + Vector2(40, 0))
	var speed: float = {"bolt": 900.0, "fist": 1050.0, "claw": 1100.0, "laser": 1700.0, "shell": 760.0}[kind]
	var src := slot
	if kind == "laser":
		src = "head" if f.alive("head") else "head2"
	elif kind == "bolt":
		src = f.attack_limb
	projectiles.append({"owner": f, "kind": kind, "pos": start, "src": src, "vel": Vector2(f.facing * speed, 0.0),
			"damage": dmg, "zone": zone, "travel": 0.0, "max": 560.0 if kind in ["fist", "claw"] else 2000.0,
			"returning": false, "slot": slot, "hit": false, "spin": 0.0})


func update_projectiles(delta: float) -> void:
	var keep: Array = []
	for p in projectiles:
		var owner: Fighter = p["owner"]
		var o := cpu if owner == player else player
		p["spin"] += delta * 20.0
		if p["returning"]:
			var hand := to_world_point(owner, RobotArt.geom(owner.get_look())[shoulder_key(p["slot"])])
			var to: Vector2 = hand - p["pos"]
			if to.length() < 40.0 or owner.state == "ko" and to.length() < 400.0:
				owner.fist_out.erase(p["slot"])
				owner.look_dirty = true
				continue
			p["pos"] += to.normalized() * 1300.0 * delta
			keep.append(p)
			continue
		p["pos"] += p["vel"] * delta
		p["travel"] += absf(p["vel"].x) * delta
		var hit_now := false
		if not p["hit"] and o.state != "ko" and o.invuln_t <= 0.0:
			var top := o.pos.y - 200.0 * o.scale
			if absf(p["pos"].x - o.pos.x) < 36.0 * o.scale and p["pos"].y > top and p["pos"].y < o.pos.y + 5.0:
				hit_now = true
		if hit_now:
			p["hit"] = true
			var a := {"damage": p["damage"], "zone": p["zone"], "stun": 0.3, "knock": 260.0, "height": "mid", "src": p.get("src", "")}
			if p["kind"] == "claw":
				a["stun"] = 0.6
				a["knock"] = -700.0   # reel them in
			if p["kind"] == "shell":
				a["knock"] = 480.0
				a["stun"] = 0.45
			apply_hit(owner, o, a, p["pos"])
		if p["slot"] != "" and (p["hit"] or p["travel"] > p["max"] or p["pos"].x < 0 or p["pos"].x > screen.x):
			p["returning"] = true
			keep.append(p)
		elif p["slot"] == "" and (p["hit"] or p["pos"].x < -50 or p["pos"].x > screen.x + 50):
			continue
		else:
			keep.append(p)
	projectiles = keep


func update_fighter(f: Fighter, o: Fighter, i: Dictionary, delta: float) -> void:
	f.flash = maxf(0.0, f.flash - delta)
	f.queued_t -= delta
	if f.queued_t <= 0.0:
		f.queued = ""
	for k in f.cooldowns.keys():
		f.cooldowns[k] = maxf(0.0, f.cooldowns[k] - delta)
	f.shield_t = maxf(0.0, f.shield_t - delta)
	f.invuln_t = maxf(0.0, f.invuln_t - delta)
	f.stun_t = maxf(0.0, f.stun_t - delta)
	f.jet_t = maxf(0.0, f.jet_t - delta)
	f.combo_show = maxf(0.0, f.combo_show - delta)
	f.combo_timer = maxf(0.0, f.combo_timer - delta)
	if f.combo_timer <= 0.0:
		f.combo = 0
	if f.over_t > 0.0:
		f.over_t -= delta
		if f.over_t <= 0.0:
			f.burnout = true
			popup("BURNOUT", f.pos + Vector2(0, -230.0 * f.scale), Color(0.6, 0.6, 0.6))
			Sfx.play("ko", 0.1, -8.0)
	if f.has_gadget("regen") and f.alive("torso") and phase == "fight":
		f.parts["torso"]["hp"] = minf(f.parts["torso"]["max_hp"], f.parts["torso"]["hp"] + 1.2 * delta)
	f.slow_t = maxf(0.0, f.slow_t - delta)
	f.hobble_t = maxf(0.0, f.hobble_t - delta)
	f.numb_t = maxf(0.0, f.numb_t - delta)
	f.armor_t = maxf(0.0, f.armor_t - delta)
	f.haste_t = maxf(0.0, f.haste_t - delta)
	if phase == "fight" and f.state != "ko":
		# mechanics patch themselves up as they fight
		if f.style == "mechanic":
			for slot in BODY_PARTS:
				if f.alive(slot) and f.parts[slot]["hp"] < f.parts[slot]["max_hp"]:
					f.parts[slot]["hp"] = minf(f.parts[slot]["max_hp"], f.parts[slot]["hp"] + (1.0 if slot == "torso" else 0.4) * delta)
		# burning parts
		for b in f.burns:
			b["t"] -= delta
			if f.alive(b["slot"]):
				damage_part(f, b["slot"], b["dps"] * delta, true)
				if randf() < delta * 12.0:
					add_spark(visual_point(f, RobotArt.part_center(f.get_look(), b["slot"])) + Vector2(randf_range(-14, 14), randf_range(-14, 8)), Color(1.0, 0.5, 0.1), 12.0)
		f.burns = f.burns.filter(func(b): return b["t"] > 0.0)
		check_ko(o, f)
	if i["gadget"] >= 0 and i["gadget"] < gadget_buttons.size():
		use_gadget(f, gadget_buttons[i["gadget"]]["gadget"])
	if f.boost_t > 0.0:
		f.boost_t -= delta
		f.vel.x = f.facing * 1100.0 * f.scale
		if not f.boost_hit and absf(o.pos.x - f.pos.x) < 90.0 * (f.scale + o.scale) * 0.5 and absf(o.pos.y - f.pos.y) < 150.0:
			f.boost_hit = true
			apply_hit(f, o, {"damage": 10.0 * f.mod_damage(), "zone": "torso", "knock": 520.0, "stun": 0.4}, o.pos + Vector2(0, -90))

	var punch: bool = i["punch"]
	var kick: bool = i["kick"]
	if punch:
		push_token(f, "P")
	if kick:
		push_token(f, "K")

	if f.state == "ko":
		f.vel.x = move_toward(f.vel.x, 0.0, 900.0 * delta)
	elif f.state == "hit":
		f.timer -= delta
		f.vel.x = move_toward(f.vel.x, 0.0, 1200.0 * delta)
		if f.timer <= 0.0 and f.on_ground:
			f.state = "idle"
			f.recovered_at = clock
			if f == cpu:
				ai_timer = minf(ai_timer, randf_range(0.02, 0.1) + ai_think * 0.15)   # react right after recovering
	elif f.state == "special":
		update_special(f, o, delta)
	elif ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		f.timer += delta * f.attack_speed(f.attack_limb)
		if f.on_ground and f.boost_t <= 0.0:
			f.vel.x = 0.0
		if not f.hit_done and f.timer >= a["startup"] and f.timer <= a["startup"] + a["active"]:
			try_hit(f, o, a)
		# remember an attack pressed a little early so slower button presses still chain
		if punch or kick:
			f.queued = ("uppercut" if i["down"] else "punch") if punch else ("sweep" if i["down"] else "kick")
			f.queued_t = 0.45
		# combo cancel: a normal that landed can go straight into the next attack or a special
		if f.landed and f.timer >= a["startup"] + a["active"] and f.queued != "":
			if start_queued(f):
				return
		elif f.timer >= a["startup"] + a["active"] + a["recovery"]:
			f.state = "idle"
			f.crouching = false
			if f.queued != "" and start_queued(f):
				return
	else:
		if f.on_ground:
			f.facing = 1 if o.pos.x >= f.pos.x else -1
		f.crouching = i["down"] and f.on_ground and f.legs() > 0
		f.blocking = i["block"] and f.on_ground and f.arms() > 0
		var sp := ""
		if punch or kick:
			sp = match_special(f, "P" if punch else "K")
		if sp != "":
			start_special(f, sp)
		elif punch and f.arms() > 0:
			start_attack(f, "uppercut" if f.crouching else "punch")
		elif kick and f.legs() > 0:
			start_attack(f, "sweep" if f.crouching else "kick")
		elif i["grab"] and f.arms() > 0 and f.on_ground:
			start_attack(f, "grab")
		elif f.on_ground:
			var dir := 0
			if not f.crouching and not f.blocking:
				dir = int(i["right"]) - int(i["left"])
			var spd := f.move_speed()
			if f.boost_t <= 0.0:
				f.vel.x = dir * WALK_SPEED * spd
			f.state = "walk" if dir != 0 else "idle"
			if dir != 0:
				f.walk_phase += delta * 12.0 * spd
				f.step_timer -= delta
				if f.step_timer <= 0.0:
					f.step_timer = 0.28 / maxf(0.4, spd)
					Sfx.play("step", 0.2, -10.0)
			if i["up"] and not f.crouching and not f.blocking and f.legs() > 0:
				var jump := JUMP_SPEED * (1.0 if f.legs() == 2 else 0.75)
				if f.has_gadget("high_jump"):
					jump *= 1.4
				f.vel.y = -jump
				f.on_ground = false
				f.state = "jump"
				f.air_jumps = 1 if f.has_gadget("double_jump") else 0
				Sfx.play("jump", 0.1)
		elif i["up_press"] and f.air_jumps > 0:
			f.air_jumps -= 1
			f.vel.y = -JUMP_SPEED * 0.9
			f.vel.x = (int(i["right"]) - int(i["left"])) * WALK_SPEED * f.move_speed()
			f.jet_t = 0.35
			Sfx.play("swing", 0.1)
			Sfx.play("jump", 0.2, -4.0)
		elif not f.on_ground:
			# air control: steer left/right while jumping or falling
			var adir := int(i["right"]) - int(i["left"])
			if adir != 0:
				f.vel.x = move_toward(f.vel.x, adir * WALK_SPEED * f.move_speed(), 2200.0 * delta)

	# physics
	f.vel.y += GRAVITY * delta
	f.pos += f.vel * delta
	if f.pos.y >= floor_y:
		f.pos.y = floor_y
		f.vel.y = 0.0
		if not f.on_ground:
			Sfx.play("land", 0.15, -6.0)
			f.squash = 0.18
			for k in 2:
				add_spark(Vector2(f.pos.x + (k * 2 - 1) * 30.0 * f.scale, floor_y - 6.0), Color(0.6, 0.6, 0.6, 0.6), 16.0 * f.scale)
			if f.state == "jump":
				f.state = "idle"
			if f.state == "special" and Specials.MOVES[f.special_id].get("air", false):
				f.state = "idle"
		f.on_ground = true
	else:
		f.on_ground = false
	f.pos.x = clampf(f.pos.x, wall_l + 55.0 * f.scale, wall_r - 55.0 * f.scale)
	f.squash = maxf(0.0, f.squash - delta)


func choose_part(att: Fighter, d: Fighter, zone_name: String, sure: bool = false) -> String:
	var zone: Dictionary = Specials.ZONES.get(zone_name, Specials.ZONES["any"])
	if att.target != "" and d.alive(att.target) and (zone.has(att.target) or zone_name == "any"):
		var accuracy := 0.45 if att.target.begins_with("head") else 0.8
		if sure or randf() < accuracy:
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


## Melee hit check: range and height. If it connects, apply it.
func try_hit(att: Fighter, d: Fighter, a: Dictionary) -> void:
	var dx := (d.pos.x - att.pos.x) * att.facing
	var reach: float = (a.get("reach", 80.0) + limb_trait(att, att.attack_limb, "magnet")) * att.scale
	if dx < -10.0 or dx > reach + 35.0 * d.scale:
		return
	if absf(d.pos.y - att.pos.y) > 130.0:
		return
	if d.state == "ko" or phase != "fight":
		return
	if a.get("height", "mid") == "high" and d.crouching:
		return  # ducked under it
	if a.get("height", "mid") == "low" and not d.on_ground:
		return  # jumped over it
	if d.invuln_t > 0.0:
		return
	att.hit_done = true
	var limb: Dictionary = att.parts[att.attack_limb] if att.parts.has(att.attack_limb) and att.alive(att.attack_limb) else {"damage": 0}
	var hit := a.duplicate()
	hit["damage"] = a["damage"] * (1.0 + limb["damage"] / 100.0) * att.mod_damage()
	hit["src"] = att.attack_limb
	var at := Vector2(att.pos.x + att.facing * minf(dx, reach), d.pos.y - 90.0 * d.scale)
	apply_hit(att, d, hit, at)


## Apply a hit that connected (melee, projectile or gadget).
func apply_hit(att: Fighter, d: Fighter, a: Dictionary, at: Vector2) -> void:
	if d.state == "ko" or phase != "fight":
		return
	att.landed = true
	var slot := choose_part(att, d, a.get("zone", "punch"), a.get("sure_aim", false))
	var hit_at := to_world_point(d, RobotArt.part_center(d.get_look(), slot))
	var spark_pos := Vector2(at.x, hit_at.y)
	var dmg: float = a["damage"]

	# shield bubble: nothing gets through
	if d.shield_t > 0.0:
		add_spark(spark_pos, Color(0.5, 0.85, 1.0), 26.0)
		Sfx.play("block", 0.2)
		return
	# counter stance: no damage, strike back
	if d.counter_t > 0.0 and d.state == "special":
		d.counter_t = 0.0
		var m: Dictionary = Specials.MOVES[d.special_id]
		popup("COUNTER!", d.pos + Vector2(0, -230.0 * d.scale), Color(1.0, 1.0, 0.4))
		Sfx.play("block")
		var back := m.duplicate()
		back["damage"] = m["damage"] * d.mod_damage()
		back["unblockable"] = true
		apply_hit(d, att, back, att.pos + Vector2(0, -90.0 * att.scale))
		return

	var src: String = a.get("src", "")
	var blocked: bool = d.blocking and d.arms() > 0 and not a.get("unblockable", false) \
			and (a.get("height", "mid") != "low" or d.crouching)
	# evasion: a clean miss
	var dodge: float = minf(25.0, part_trait_sum(d, "dodge") * 0.6 + d.gtraits.get("dodge", 0.0))
	if not blocked and not a.get("unblockable", false) and randf() * 100.0 < dodge:
		popup("DODGE", d.pos + Vector2(0, -200.0 * d.scale), Color(0.7, 1.0, 1.0))
		Sfx.play("swing", 0.2)
		d.pos.x += att.facing * 20.0
		return
	if blocked:
		var arm := "arm_front"
		for s2 in ARM_SLOTS:
			if d.alive(s2):
				arm = s2
				break
		damage_part(d, arm, dmg * (0.08 if d.style == "tank" else 0.3))
		d.pos.x += att.facing * 25.0
		add_spark(spark_pos, Color(0.7, 0.85, 1.0), 18.0)
		Sfx.play("block", 0.15)
	else:
		# combos: hits while the enemy is still reeling
		# still reeling, or only just recovered (a slightly late press still counts)
		if att.combo_timer > 0.0 and (d.state == "hit" or clock - d.recovered_at < 0.35):
			att.combo += 1
		else:
			att.combo = 1
		att.combo_timer = 1.25
		if att.combo >= 2:
			att.combo_show = 1.2
			if att.combo == 3 or att.combo == 5 or att.combo >= 8:
				Sfx.play("crowd_ooh", 0.2, -6.0)
		dmg *= 1.0 + COMBO_BONUS * minf(att.combo - 1, 6)
		if slot == att.target:
			dmg *= 1.0 + att.best_aim() / 100.0
			if att.style == "specialist":
				dmg *= 1.25
		if slot == weak_point(d):
			dmg *= 1.0 + WEAK_BONUS
		# precision: critical hits
		var crit: float = off_trait(att, src, "crit") + (5.0 if att.style == "striker" else 0.0)
		if randf() * 100.0 < crit:
			dmg *= 2.0
			popup("CRITICAL!", hit_at + Vector2(0, -30), Color(1.0, 0.95, 0.3))
		# reactive armor: this part may shrug it off
		if randf() * 100.0 < limb_trait(d, slot, "reactive") * 2.0 / (1.0 if slot.begins_with("head") or slot == "torso" else 2.0):
			dmg *= 0.25
			popup("DEFLECTED", hit_at + Vector2(0, -30), Color(0.7, 0.8, 1.0))
			add_spark(hit_at, Color(0.7, 0.8, 1.0), 30.0)
		var part_dmg := dmg * (HEAD_FACTOR if slot.begins_with("head") else 1.0)
		damage_part(d, slot, part_dmg)
		if slot != "torso" and d.alive("torso"):
			damage_part(d, "torso", dmg * CORE_SHARE)
		# every part matters: hurt legs slow you down, hurt arms hit softer
		if slot.begins_with("leg"):
			if d.hobble_t <= 0.0 and d == cpu:
				popup("HOBBLED", hit_at + Vector2(0, 20), Color(1.0, 0.75, 0.4))
			d.hobble_t = 1.5
		elif slot.begins_with("arm"):
			if d.numb_t <= 0.0 and d == cpu:
				popup("NUMBED", hit_at + Vector2(0, 20), Color(1.0, 0.75, 0.4))
			d.numb_t = 1.5
		# offensive traits
		var burn := off_trait(att, src, "burn")
		if burn > 0.0 and d.alive(slot):
			d.burns.append({"slot": slot, "dps": burn / 3.0, "t": 3.0})
		var chill := off_trait(att, src, "chill")
		if chill > 0.0:
			d.slow_t = maxf(d.slow_t, chill)
			add_spark(hit_at, Color(0.6, 0.85, 1.0), 26.0)
		var leech: float = off_trait(att, src, "leech") + (10.0 if att.style == "mechanic" else 0.0)
		if leech > 0.0 and att.alive("torso"):
			att.parts["torso"]["hp"] = minf(att.parts["torso"]["max_hp"], att.parts["torso"]["hp"] + dmg * leech / 100.0)
		# spikes hurt whoever hits the torso up close
		if d.has_gadget("thorns") and slot == "torso" and absf(att.pos.x - d.pos.x) < 160.0:
			var limb := att.attack_limb if att.alive(att.attack_limb) and att.attack_limb != "torso" else "torso"
			damage_part(att, limb, dmg * 0.25)
			add_spark(att.pos + Vector2(att.facing * 40.0, -100.0 * att.scale), Color(0.8, 0.8, 0.8), 14.0)
		if d.state != "ko":
			d.state = "hit"
			d.timer = maxf(a.get("stun", 0.25), a.get("emp", 0.0))
			d.crouching = false
			d.blocking = false
			d.special_id = ""
			d.boost_t = 0.0
			d.vel.x = att.facing * a.get("knock", 320.0)
			if off_trait(att, src, "magnet") > 0.0:
				d.vel.x = -att.facing * 260.0   # magnets yank the enemy in
			if a.has("launch"):
				d.vel.y = a["launch"]
				d.on_ground = false
			if randf() * 100.0 < off_trait(att, src, "stun"):
				d.timer = maxf(d.timer, 0.8)
				d.stun_t = maxf(d.stun_t, 0.8)
				popup("SHOCKED!", hit_at + Vector2(0, -30), Color(1.0, 1.0, 0.4))
				add_spark(hit_at, Color(1.0, 1.0, 0.5), 40.0)
		if a.has("emp"):
			d.stun_t = a["emp"]
			add_spark(hit_at, Color(0.7, 0.55, 1.0), 40.0)
		d.flash = 0.12
		shake = maxf(shake, 8.0 + minf(dmg, 20.0) * 0.3)
		hitstop = maxf(hitstop, 0.04 + minf(dmg, 25.0) * 0.004)
		add_spark(spark_pos, Color(1.0, 0.85, 0.3), 30.0)
		Sfx.play("hit_big" if dmg >= 12.0 else "hit", 0.15)

	check_ko(att, d)


## Knock out whoever has lost their core or every head. att = the fighter that caused it.
func check_ko(att: Fighter, d: Fighter) -> void:
	if phase != "fight":
		return
	if not d.alive("torso"):
		knockout(att, d, "CORE DESTROYED")
	elif d.heads() == 0:
		knockout(att, d, "HEAD KNOCKED OFF" if d.parts["head2"].is_empty() else "BOTH HEADS KNOCKED OFF")
	elif not att.alive("torso"):   # thorns or explosions can finish an attacker
		knockout(d, att, "BLOWN APART")
	elif att.heads() == 0:
		knockout(d, att, "BLOWN APART")


## Trait value on one part (heads and torso give half, limbs full).
func limb_trait(f: Fighter, slot: String, t: String) -> float:
	if slot == "" or not f.alive(slot):
		return 0.0
	var pd: Dictionary = f.parts[slot]
	if pd.get("trait", "") != t:
		return 0.0
	return Catalog.trait_value(pd) * (0.5 if slot.begins_with("head") or slot == "torso" else 1.0)


## Offensive trait for a hit: the striking part plus half of any robot-wide (reactor) trait.
func off_trait(f: Fighter, src: String, t: String) -> float:
	return limb_trait(f, src, t) + f.gtraits.get(t, 0.0) * 0.5


func part_trait_sum(f: Fighter, t: String) -> float:
	var n := 0.0
	for slot in BODY_PARTS:
		n += limb_trait(f, slot, t)
	return n


## The part the scanner marks: least effective health left, ignoring the torso.
func weak_point(f: Fighter) -> String:
	var best := ""
	var best_v := 1e9
	for slot in BODY_PARTS:
		if slot == "torso" or not f.alive(slot):
			continue
		var pd: Dictionary = f.parts[slot]
		var v: float = pd["hp"] / maxf(0.1, 1.0 - pd["armor"] / 100.0)
		if slot.begins_with("head"):
			v /= HEAD_FACTOR
		if v < best_v:
			best_v = v
			best = slot
	return best


func damage_part(f: Fighter, slot: String, amount: float, quiet: bool = false) -> void:
	if not f.alive(slot):
		return
	var p: Dictionary = f.parts[slot]
	var armor: float = p["armor"]
	if f.style == "tank":
		armor += 10.0
	if f.armor_t > 0.0:
		armor += 15.0
	if slot == "torso":
		armor += f.gtraits.get("plating", 0.0)
	if f.style == "striker":
		amount *= 1.1
	p["hp"] -= amount * (1.0 - minf(armor, 75.0) / 100.0)
	f.look_dirty = true
	if p["hp"] <= 0.0:
		p["hp"] = 0.0
		if slot != "torso":
			rip_off(f, slot)


func rip_off(f: Fighter, slot: String) -> void:
	var p: Dictionary = f.parts[slot]
	var o := cpu if f == player else player
	f.ripped.append({"id": p["id"], "aimed": o.target == slot})
	f.fist_out.erase(slot)
	f.burns = f.burns.filter(func(b): return b["slot"] != slot)
	var boom: float = limb_trait(f, slot, "explosive") + f.gtraits.get("explosive", 0.0)
	var at := to_world_point(f, RobotArt.part_center(f.get_look(), slot))
	var size := Vector2(46, 14) if slot.begins_with("arm") else (Vector2(16, 52) if slot.begins_with("leg") else Vector2(36, 32))
	debris.append({"pos": at, "vel": Vector2(-f.facing * randf_range(150, 350), randf_range(-650, -400)),
			"rot": 0.0, "rv": randf_range(-12, 12), "size": size * f.scale, "color": p["color"]})
	for k in 3:
		add_spark(at + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(1.0, 0.6, 0.2), 26.0)
	popup("%s LOST!" % PART_LABELS[slot] if f == player else "%s DESTROYED!" % PART_LABELS[slot], at,
			Color(1.0, 0.3, 0.2) if f == player else Color(1.0, 0.85, 0.2))
	if f.blocking and f.arms() == 0:
		f.blocking = false
	shake = 16.0
	hitstop = maxf(hitstop, 0.14)
	cheer = maxf(cheer, 1.5)
	Sfx.play("break")
	Sfx.play("crowd_ooh", 0.1)
	if boom > 0.0:
		rings.append({"pos": at, "t": 0.0, "color": Color(1.0, 0.5, 0.1), "r": 180.0})
		Sfx.play("hit_big")
		popup("KABOOM!", at + Vector2(0, -40), Color(1.0, 0.5, 0.1))
		if absf(o.pos.x - f.pos.x) < 200.0 * f.scale:
			damage_part(o, "torso", boom)
			o.flash = 0.12


func knockout(att: Fighter, d: Fighter, why: String) -> void:
	d.state = "ko"
	d.vel = Vector2(att.facing * 400.0, -500.0)
	d.on_ground = false
	shake = 18.0
	hitstop = 0.22
	slowmo = 1.3
	Sfx.play("ko")
	end_by(att, why)


func separate() -> void:
	var dx := cpu.pos.x - player.pos.x
	# keep bodies apart by their real torso widths, so wide robots don't overlap (and stay easy to tap)
	var tw_p: float = RobotArt.geom(player.get_look())["tw"]
	var tw_c: float = RobotArt.geom(cpu.get_look())["tw"]
	var gap := tw_p * 0.5 * player.scale + tw_c * 0.5 * cpu.scale + 12.0
	if absf(dx) < gap and absf(cpu.pos.y - player.pos.y) < 120.0:
		var push := (gap - absf(dx)) * 0.5
		var s := 1.0 if dx >= 0.0 else -1.0
		player.pos.x = clampf(player.pos.x - push * s, wall_l + 55.0 * player.scale, wall_r - 55.0 * player.scale)
		cpu.pos.x = clampf(cpu.pos.x + push * s, wall_l + 55.0 * cpu.scale, wall_r - 55.0 * cpu.scale)


func add_spark(p: Vector2, c: Color, size: float) -> void:
	sparks.append({"pos": p, "t": 0.0, "color": c, "size": size})


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	draw_arena(off)
	draw_cables(off)
	draw_fighter(cpu, off)
	draw_fighter(player, off)
	draw_projectiles(off)

	for d in debris:
		draw_set_transform(d["pos"] + off, d["rot"], Vector2.ONE)
		var sz: Vector2 = d["size"]
		draw_rect(Rect2(-sz * 0.5, sz), d["color"])
		draw_rect(Rect2(-sz * 0.5, sz), (d["color"] as Color).darkened(0.5), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for s in smoke:
		var t: float = s["t"] / 1.2
		var c := Color(0.12, 0.12, 0.12, 0.6 * (1.0 - t)) if s["dark"] else Color(0.3, 0.3, 0.32, 0.5 * (1.0 - t))
		draw_circle(s["pos"] + off, 6.0 + t * 14.0, c)
	for s in sparks:
		var t: float = s["t"] / 0.25
		var c: Color = s["color"]
		c.a = 1.0 - t
		draw_circle(s["pos"] + off, s["size"] * (0.4 + t), c)
	for r in rings:
		var t: float = r["t"] / 0.4
		var c: Color = r["color"]
		c.a = 1.0 - t
		draw_arc(r["pos"] + off, r["r"] * t, 0, TAU, 40, c, 6.0)

	draw_weak_point(cpu, off)
	draw_crosshair(player.target, cpu, Color(1.0, 0.2, 0.2, 0.9), off, 1.0)
	draw_crosshair(cpu.target, player, Color(1.0, 0.6, 0.1, 0.75), off, 0.75)
	for p in popups:
		var t: float = p["t"] / 1.4
		var c: Color = p["color"]
		c.a = 1.0 - t * t
		draw_string(font, p["pos"] + Vector2(-260, -40.0 - t * 50.0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 520, fs(26), c)

	draw_hud()
	if phase == "intro" or phase == "fight":
		draw_buttons()
	if paused:
		draw_moves_list()


func draw_arena(off: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.07, 0.11))
	Arena.draw_backdrop(self, arena_id, screen, floor_y, clock, off)
	Arena.draw_crowd(self, crowd, crowd_id, screen, clock, cheer, off)
	var top := screen.y * 0.24
	var ar: Dictionary = Arena.ARENAS[arena_id]
	draw_rect(Rect2(0, top + 95.0, screen.x, floor_y - top - 95.0), Color(Color(ar["sky"][0]), 0.6))
	var lc := Color(ar["light"])
	for k in range(14):
		draw_circle(Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.21), 5.0, Color(lc, 0.45))
	Arena.draw_floor(self, arena_id, screen, floor_y, clock, off)
	# ring: corner posts mark the walls, ropes run between them
	var post_top := floor_y - 190.0
	for k in range(3):
		var y := floor_y - 70.0 - k * 50.0
		draw_line(Vector2(wall_l, y) + off, Vector2(wall_r, y) + off, Color(Color(ar["rope"]), 0.75), 4.0)
	for x in [wall_l, wall_r]:
		draw_rect(Rect2(Vector2(x - 9.0, post_top) + off, Vector2(18.0, floor_y - post_top)), Color(ar["post"]))
		draw_rect(Rect2(Vector2(x - 12.0, post_top - 10.0) + off, Vector2(24.0, 14.0)), Color(ar["rope"]))
		for k in range(3):
			draw_rect(Rect2(Vector2(x - 11.0, floor_y - 76.0 - k * 50.0) + off, Vector2(22.0, 12.0)), Color(0.9, 0.9, 0.95))


func draw_cables(off: Vector2) -> void:
	for p in projectiles:
		if p["kind"] == "claw":
			var owner: Fighter = p["owner"]
			var g := RobotArt.geom(owner.get_look())
			var s := to_world_point(owner, g[shoulder_key(p["slot"])])
			draw_line(s + off, p["pos"] + off, Color(0.3, 0.3, 0.32), 3.0)


func draw_projectiles(off: Vector2) -> void:
	for p in projectiles:
		var pos: Vector2 = p["pos"] + off
		var owner: Fighter = p["owner"]
		var dir := Vector2(signf(p["vel"].x), 0.0) if not p["returning"] else -Vector2(owner.facing, 0)
		match p["kind"]:
			"bolt":
				draw_set_transform(pos, p["spin"], Vector2.ONE)
				draw_rect(Rect2(-8, -8, 16, 16), Color(1.0, 0.45, 0.15))
				draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.5))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"fist":
				var arm: Dictionary = owner.parts[p["slot"]]
				RobotArt.draw_rocket_fist(self, pos, dir, 14.0 * owner.scale, arm["color"], owner.spec["trim"], not p["returning"], clock)
			"claw":
				draw_circle(pos, 8.0, Color(0.3, 0.55, 0.55))
				draw_line(pos, pos + dir * 16.0 + Vector2(0, 9), Color(0.8, 0.8, 0.85), 4.0)
				draw_line(pos, pos + dir * 16.0 - Vector2(0, 9), Color(0.8, 0.8, 0.85), 4.0)
			"laser":
				draw_line(pos - dir * 70.0, pos, Color(1.0, 0.2, 0.3, 0.6), 8.0)
				draw_line(pos - dir * 70.0, pos, Color(1.0, 0.9, 0.9), 3.0)
			"shell":
				draw_circle(pos, 11.0, Color(0.25, 0.25, 0.25))
				draw_circle(pos - dir * 14.0, 7.0, Color(1.0, 0.6, 0.2, 0.7))


func draw_fighter(f: Fighter, off: Vector2) -> void:
	draw_set_transform(Vector2(f.pos.x, floor_y) + off, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 42.0 * f.scale, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := f.pos + off
	var rot := 0.0
	var state := f.state
	var extended := false
	if state == "special":
		var m: Dictionary = Specials.MOVES[f.special_id]
		state = m["pose"]
		var st: float = m["startup"]
		var act: float = m["active"]
		extended = f.timer >= st * 0.6 and f.timer <= st + act + m.get("recovery", 0.2) * 0.4
		if m.get("jab", false) and extended:
			extended = fmod(maxf(0.0, f.timer - st), m.get("interval", 0.12)) < m.get("interval", 0.12) * 0.6
		if m.get("spin", false) and f.timer >= st and f.timer <= st + act:
			rot = f.facing * (f.timer - st) * 25.0
		if state == "block":
			extended = false
	elif ATTACKS.has(state):
		var a: Dictionary = ATTACKS[state]
		extended = f.timer >= a["startup"] * 0.6 and f.timer <= a["startup"] + a["active"] + a["recovery"] * 0.5
		if state == "grab":
			state = "punch"
	# --- exaggerated animation: lean, lunge, recoil, squash & stretch
	var sx := 1.0
	var sy := 1.0
	var lean := 0.0
	var dx := 0.0
	var swoosh := false
	var phase_t := 0.0   # 0..1 progress through the attack's startup, then >1 once it's live
	if f.state == "special" or ATTACKS.has(f.state):
		var a: Dictionary = Specials.MOVES[f.special_id] if f.state == "special" else ATTACKS[f.state]
		var st: float = maxf(0.01, a["startup"])
		var act: float = a["active"]
		phase_t = f.timer / st
		if f.timer < st:
			# wind-up: lean back, coil
			lean = -f.facing * 0.16 * phase_t
			dx = -f.facing * 10.0 * phase_t * f.scale
			sy = 1.0 - 0.05 * phase_t
		elif f.timer <= st + act + a.get("recovery", 0.2) * 0.5:
			swoosh = f.timer <= st + act + 0.05
			match state:
				"kick":
					lean = -f.facing * 0.16
					dx = f.facing * 8.0 * f.scale
				"uppercut":
					lean = -f.facing * 0.12
					sy = 1.14
					sx = 0.92
				"sweep":
					lean = f.facing * 0.12
				"block":
					lean = f.facing * 0.22
					dx = f.facing * 16.0 * f.scale
				_:
					lean = f.facing * 0.22
					dx = f.facing * 18.0 * f.scale
					sx = 1.08
	elif f.state == "hit":
		var k := clampf(f.timer / 0.45, 0.0, 1.0)
		lean = -f.facing * 0.38 * k
		dx = -f.facing * 12.0 * k * f.scale
		sx = 1.0 - 0.08 * k
	elif f.state == "walk":
		lean = signf(f.vel.x) * 0.08
		base.y -= absf(sin(f.walk_phase)) * 4.0 * f.scale
	elif f.blocking:
		lean = -f.facing * 0.07
	elif f.on_ground and f.state != "ko":
		sy = 1.0 + sin(clock * 3.5 + (0.0 if f == player else 1.7)) * 0.018   # breathing
	if not f.on_ground and f.state != "ko":
		if f.vel.y < 0.0:
			sy *= 1.12
			sx *= 0.9
		else:
			sy *= 1.04
	if f.squash > 0.0:
		var q := f.squash / 0.18
		sy *= 1.0 - 0.22 * q
		sx *= 1.0 + 0.16 * q
	if rot == 0.0:
		rot = lean
	base.x += dx
	if f.state == "ko":
		if f.on_ground:
			rot = -f.facing * PI / 2.0
			base.y -= 18.0 * f.scale
		else:
			rot = -f.facing * (PI / 4.0 + clock * 3.0)
	if swoosh and extended:
		var g := RobotArt.geom(f.get_look())
		var low := state == "kick" or state == "sweep"
		var pivot: Vector2 = g["hip_front"] if low else g["shoulder_front"]
		var c := to_world_point(f, pivot) + Vector2(dx, 0)
		var a0 := 0.0 if f.facing == 1 else PI
		var span := -0.9 if state == "uppercut" else (0.5 if state == "sweep" else -0.5)
		draw_arc(c, 100.0 * f.scale, a0 + span * f.facing - 0.35, a0 + span * f.facing + 0.35, 14, Color(1, 1, 1, 0.28), 14.0 * f.scale)
	var fist_out: Array = f.fist_out.keys()
	f.vis_base = base - off
	f.vis_rot = rot
	f.vis_sx = sx
	f.vis_sy = sy
	f.vis_ok = true
	RobotArt.draw(self, base, f.get_look(), {
		"facing": f.facing, "state": state, "extended": extended, "attack_limb": f.attack_limb,
		"swing": sin(f.walk_phase) * 10.0 if f.state == "walk" else 0.0,
		"crouch": f.crouching, "blocking": f.blocking or (f.state == "special" and state == "block"),
		"flash": f.flash > 0.0, "rot": rot, "time": clock, "fist_out": fist_out,
		"shield": f.shield_t > 0.0, "overcharge": f.over_t > 0.0, "stunned": f.stun_t > 0.0,
		"jet": f.jet_t > 0.0 or (not f.on_ground and f.vel.y < -400.0 and f.has_gadget("double_jump")),
		"boost": f.boost_t > 0.0, "sx": sx, "sy": sy,
	})


func draw_crosshair(slot: String, f: Fighter, c: Color, off: Vector2, size: float) -> void:
	if slot == "" or (phase != "fight" and phase != "intro") or not f.alive(slot):
		return
	var p := visual_point(f, RobotArt.part_center(f.get_look(), slot)) + off
	var r := (22.0 + sin(clock * 6.0) * 3.0) * size
	draw_arc(p, r, 0.0, TAU, 32, c, 3.0)
	var spin := clock * 2.0 * (1.0 if size >= 1.0 else -1.0)
	for k in 4:
		var a := spin + k * PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(p + dir * (r - 8.0), p + dir * (r + 10.0), c, 3.0)
	draw_circle(p, 3.0, c)
	var label: String = PART_LABELS[slot] if size >= 1.0 else "ENEMY AIM: " + PART_LABELS[slot]
	draw_string(font, p + Vector2(-120, -r - 10.0), label, HORIZONTAL_ALIGNMENT_CENTER, 240, fs(15), c)


## Scanner: a small pulsing marker on the enemy's weakest part (hits there do +15%).
func draw_weak_point(f: Fighter, off: Vector2) -> void:
	if phase != "fight" or f.state == "ko":
		return
	var slot := weak_point(f)
	if slot == "" or slot == player.target:
		return
	var p := visual_point(f, RobotArt.part_center(f.get_look(), slot)) + off
	var r := 9.0 + sin(clock * 5.0) * 2.0
	var c := Color(1.0, 0.9, 0.2, 0.85)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(c.r, c.g, c.b, 0.25))
	draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)]), c, 2.0)
	draw_string(font, p + Vector2(-60, r + 16), "WEAK", HORIZONTAL_ALIGNMENT_CENTER, 120, fs(11), c)


func draw_part_map(f: Fighter, at: Vector2, mirror: bool) -> void:
	var m := -1.0 if mirror else 1.0
	var k := UI_SCALE
	var boxes := {
		"head": Rect2(-7, 0, 14, 12), "head2": Rect2(-19, 2, 10, 10), "torso": Rect2(-10, 14, 20, 22),
		"arm_front": Rect2(12, 14, 6, 20), "arm_back": Rect2(-18, 14, 6, 20),
		"arm_front2": Rect2(20, 20, 5, 16), "arm_back2": Rect2(-25, 20, 5, 16),
		"leg_front": Rect2(1, 38, 7, 18), "leg_back": Rect2(-8, 38, 7, 18),
	}
	for slot in boxes:
		if not f.parts.has(slot) or f.parts[slot].is_empty():
			continue
		var r: Rect2 = boxes[slot]
		if mirror:
			r.position.x = -(r.position.x + r.size.x)
		r = Rect2(at + r.position * k, r.size * k)
		var c := Color(0.25, 0.25, 0.28)
		if f.alive(slot):
			var h := f.ratio(slot)
			c = Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.35), h) if h < 1.0 else Color(0.3, 0.9, 0.35)
		draw_rect(r, c)
		var aimed: bool = (f == cpu and player.target == slot) or (f == player and cpu.target == slot)
		if aimed:
			draw_rect(r.grow(2.0), Color(1, 0.2, 0.2) if f == cpu else Color(1, 0.6, 0.1), false, 2.0)


func draw_hud() -> void:
	var w := screen.x * 0.32
	var y := screen.y * 0.03
	var bh := 28.0
	# soft dark band so the HUD reads on bright arenas
	for k in 6:
		draw_rect(Rect2(0, k * (y + bh + 50) / 6.0, screen.x, (y + bh + 50) / 6.0 + 1), Color(0, 0, 0, 0.42 * (1.0 - k / 6.0)))
	var px := 100.0
	var cx := screen.x - 100.0 - w
	draw_rect(Rect2(px, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(px, y, w * player.ratio("torso"), bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(px, y, w, bh), Color.WHITE, false, 2.0)
	var cw := w * cpu.ratio("torso")
	draw_rect(Rect2(cx, y, w, bh), Color(0.35, 0.05, 0.05))
	draw_rect(Rect2(cx + w - cw, y, cw, bh), Color(0.95, 0.85, 0.2))
	draw_rect(Rect2(cx, y, w, bh), Color.WHITE, false, 2.0)
	draw_string(font, Vector2(px, y + bh + 28), player.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(22), Color.WHITE)
	draw_string(font, Vector2(cx, y + bh + 28), cpu.label, HORIZONTAL_ALIGNMENT_RIGHT, w, fs(22), Color.WHITE)
	for f in [player, cpu]:
		if Catalog.STYLES.has(f.style):
			var st: Dictionary = Catalog.STYLES[f.style]
			var sw := font.get_string_size(f.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(22)).x
			if f == player:
				draw_string(font, Vector2(px + sw + 12, y + bh + 26), st["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(14), Color(st["color"]).lightened(0.35))
			else:
				draw_string(font, Vector2(cx, y + bh + 26), st["name"].to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, w - sw - 12, fs(14), Color(st["color"]).lightened(0.35))
	var status: Array = []
	if player.eff < 1.0:
		status.append("OVERLOADED")
	if player.over_t > 0.0:
		status.append("OVERCHARGE %.0f" % ceilf(player.over_t))
	if player.burnout:
		status.append("BURNOUT")
	if player.hobble_t > 0.0:
		status.append("LEG HIT: SLOWED")
	if player.numb_t > 0.0:
		status.append("ARM HIT: WEAKER")
	if player.slow_t > 0.0:
		status.append("FROZEN")
	if not player.burns.is_empty():
		status.append("ON FIRE")
	if not status.is_empty():
		draw_string(font, Vector2(px, y + bh + 50), "  ".join(status), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(16), Color(1.0, 0.5, 0.2))
	draw_part_map(player, Vector2(44, y), false)
	draw_part_map(cpu, Vector2(screen.x - 44, y), true)
	for f in [player, cpu]:
		if f.combo >= 2 and f.combo_show > 0.0:
			var x := px if f == player else cx
			draw_string(font, Vector2(x, y + bh + 70), "%d HIT COMBO!" % f.combo, HORIZONTAL_ALIGNMENT_LEFT if f == player else HORIZONTAL_ALIGNMENT_RIGHT,
					w, fs(30), Color(1.0, 0.85, 0.2, minf(1.0, f.combo_show * 2.0)))

	draw_string(font, Vector2(0, y + 18), title_text,
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(16), Color(0.8, 0.8, 0.85))
	var tc := Color(1.0, 0.35, 0.3) if time_left < 10.0 else Color.WHITE
	draw_string(font, Vector2(0, y + 50), "%d" % ceili(time_left), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(30), tc)
	if phase == "intro" or phase == "fight":
		for rr in [[quit_rect, "QUIT"], [moves_rect, "MOVES"]]:
			draw_rect(rr[0], Color(1, 1, 1, 0.1))
			draw_rect(rr[0], Color(1, 1, 1, 0.4), false, 2.0)
			draw_string(font, (rr[0] as Rect2).position + Vector2(0, 31), rr[1], HORIZONTAL_ALIGNMENT_CENTER, (rr[0] as Rect2).size.x, fs(19), Color(1, 1, 1, 0.75))
		if phase == "fight" and phase_timer < 6.0 and player.target == "" and fight_idx < 2 and mode == "story":
			draw_string(font, Vector2(0, screen.y * 0.38), "Tap a part of %s to aim at it" % cpu.label, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(22), Color(1, 1, 1, 0.75))

	var cy := screen.y * 0.42
	match phase:
		"intro":
			var t := cpu.label if phase_timer < 1.0 else "FIGHT!"
			draw_string(font, Vector2(0, cy), t, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(72), Color(1.0, 0.3, 0.2))
			draw_string(font, Vector2(0, cy + 44), "%s  -  %s" % [Arena.ARENAS[arena_id]["name"].to_upper(), Arena.CROWDS[crowd_id]["name"]],
					HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(18), Color(0.85, 0.85, 0.9))
		"ko":
			var big := "K.O." if ko_text != "TIME!" else "TIME!"
			draw_string(font, Vector2(0, cy), big, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(84), Color(1.0, 0.2, 0.1))
			var sub := ko_text if ko_text != "TIME!" else "Judges' decision"
			draw_string(font, Vector2(0, cy + 55), sub, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(26), Color.WHITE)
			draw_string(font, Vector2(0, cy + 100), "%s WINS" % (player.label if won else cpu.label), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(32), Color(1.0, 0.85, 0.2))
			if phase_timer > 2.0:
				draw_string(font, Vector2(0, cy + 145), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(22), Color(0.8, 0.8, 0.8))
		"results":
			draw_results()


func draw_results() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.7))
	var y := screen.y * 0.2
	var title := "VICTORY!" if won else "DEFEAT"
	draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(72), Color(1.0, 0.85, 0.2) if won else Color(0.9, 0.3, 0.3))
	y += 60.0
	var lines: Array = []
	if mode == "quick":
		lines.append(["Quick fight - nothing saved. Tap to go back to the menu.", Color(0.8, 0.8, 0.85)])
	else:
		lines.append(["Prize money: +$%d" % result.get("reward", 0), Color(0.95, 0.85, 0.2)])
	if result.get("bonus", 0) > 0:
		lines.append(["Dismantle bonus: +$%d" % result["bonus"], Color(0.95, 0.85, 0.2)])
	for n in result.get("salvaged", []):
		lines.append(["Salvaged: %s" % n, Color(0.5, 1.0, 0.6)])
	for n in result.get("wrecked", []):
		lines.append(["Wrecked (rebuild in Spares): %s" % n, Color(1.0, 0.7, 0.3)])
	for n in result.get("lost", []):
		lines.append(["Lost: %s" % n, Color(1.0, 0.45, 0.4)])
	if result.get("trophy", "") != "":
		lines.append(["Trophy part: %s (in Spares)" % result["trophy"], Color(0.5, 1.0, 0.6)])
	if result.get("champion", false):
		lines.append(["YOU ARE THE CHAMPION!", Color(1.0, 0.5, 0.2)])
	if result.get("cup_done", "") != "":
		lines.append(["CUP WON: %s" % result["cup_done"], Color(1.0, 0.5, 0.2)])
	for l in lines:
		draw_string(font, Vector2(0, y), l[0], HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(24), l[1])
		y += 38.0
	if phase_timer > 1.0:
		draw_string(font, Vector2(0, y + 20), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(22), Color(0.8, 0.8, 0.8))


func draw_buttons() -> void:
	for b in buttons:
		var held: bool = held_buttons.get(b["name"], false)
		draw_circle(b["pos"], b["r"], Color(1, 1, 1, 0.35 if held else 0.12))
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
		var size := fs(17) if str(b["label"]).length() <= 5 else fs(14)
		draw_string(font, b["pos"] + Vector2(-b["r"], size * 0.35), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, size, Color(1, 1, 1, 0.85))
	for b in gadget_buttons:
		var g: Dictionary = b["gadget"]
		var id: String = g["id"]
		var cd: float = player.cooldowns.get(id, 0.0)
		var ready := cd <= 0.0 and player.gadget_working(g) and not (id == "overcharge" and player.overcharged) \
				and not (player.fist_out.has(g["slot"]))
		var col := Color(0.4, 0.8, 1.0) if ready else Color(0.5, 0.5, 0.55)
		draw_circle(b["pos"], b["r"], Color(col.r, col.g, col.b, 0.3 if held_buttons.get(b["name"], false) else 0.15))
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, col, 3.0)
		if cd > 0.0 and id != "overcharge":
			var frac := cd / float(Specials.GADGETS[id]["cd"])
			draw_arc(b["pos"], b["r"] - 5.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(1, 1, 1, 0.5), 6.0)
		draw_string(font, b["pos"] + Vector2(-b["r"] - 10, 7.0), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0 + 20, fs(15), col)


func draw_moves_list() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.82))
	var x := screen.x * 0.08
	var y := screen.y * 0.1
	draw_string(font, Vector2(0, y), "PAUSED - MOVE LIST", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(30), Color(1.0, 0.45, 0.2))
	y += 50.0
	var lines: Array = [
		["P punch   K kick   B block   G grab (beats block)   v+P uppercut   v+K sweep   (→ = toward the enemy)", Color(0.8, 0.8, 0.85)],
		["Combos: hit again while the enemy is still reeling. Landed attacks can chain into the next.", Color(0.8, 0.8, 0.85)],
	]
	if player.specials.is_empty():
		lines.append(["No special moves installed. Buy training chips in the garage!", Color(1.0, 0.7, 0.3)])
	for id in player.specials:
		var m: Dictionary = Specials.MOVES[id]
		var cd: float = player.cooldowns.get(id, 0.0)
		lines.append(["%s   %s%s   - %s" % [Specials.seq_text(m["seq"]), m["name"], "  (%.0fs)" % ceilf(cd) if cd > 0.0 else "", m["desc"]], Color(0.5, 0.9, 1.0)])
	for g in player.gadgets:
		var info: Dictionary = Specials.GADGETS[g["id"]]
		lines.append(["%s%s - %s" % ["[" + info["short"] + "]  " if info["active"] else "", info["name"], info["desc"]], Color(1.0, 0.85, 0.4)])
	var width := screen.x * 0.84
	for l in lines:
		draw_multiline_string(font, Vector2(x, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, width, fs(16), -1, l[1])
		y += font.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, width, fs(16)).y + 6.0
	draw_string(font, Vector2(0, screen.y - 30), "Tap anywhere to resume", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(20), Color(0.8, 0.8, 0.8))
