extends Node2D
const Light = preload("res://light.gd")

# helper scripts, loaded by path so the game also runs without an editor scan
const Arena = preload("res://arena.gd")
const Scoreboard = preload("res://scoreboard.gd")
const GUI = preload("res://garage_ui.gd")
const PartIcon = preload("res://part_icon.gd")
const Catalog = preload("res://catalog.gd")
const Controls = preload("res://controls.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")
const Specials = preload("res://specials.gd")
const Story = preload("res://story_data.gd")
## Championship fight: ECHO vs the current opponent. One knockout bout with a timer.
##
## PARTS: every part (head, torso, 2 arms, 2 legs) has its own health. Tap a part of the enemy to
## aim at it. Parts at 0 are ripped off. Head or torso gone = knockout. Damage carries over.
## COMBOS: hits that land while the enemy is still reeling chain into combos (+8% damage per hit).
##   A normal attack that lands can be cancelled straight into the next one (P, P, K...).
## SPECIALS: training chips teach input sequences (see specials.gd), e.g. down, toward, punch.
## GADGETS: some parts add buttons (rocket fist, laser, shield...) or passive tricks (double jump).
##
## Touch: left pad LEFT/RIGHT move, UP / DOWN set the height of the next hit (down alone = crouch) |
##        right pad (same diamond shape): BLOCK on top, PUNCH left, KICK right, JUMP bottom |
##        gadget buttons along the bottom middle | MOVES (top) pauses and lists your moves
## PUNCH and KICK take turns between the arms (legs). Hold PUNCH or KICK to charge a heavier hit.
## Keyboard: A/D move, W/S up/down, Space jump, J punch, K kick, L block, 1 2 3 gadgets, M moves, Esc pause

## Pace (1.41): a fight you can read. Every move runs TEMPO times slower, robots walk and jump slower
## and float a little longer, hits push further apart, and the clock runs three minutes.
const TEMPO := 1.25
const GRAVITY := 1800.0
const WALK_SPEED := 240.0
## Moving while fighting (1.51): you can walk while a punch comes out and while you block (slower),
## and a kick turns a push on the pad into a little hop with the leg still out. The recovery after
## a strike stays rooted, so a whiff still leaves you open.
const MOVE_PUNCH := 0.6
const MOVE_BLOCK := 0.4
const MOVE_CHARGE := 0.35
const KICK_HOP_UP := 300.0
const PUNCHES := ["punch", "low_punch", "uppercut"]
const KICKS := ["kick", "high_kick", "sweep"]
const JUMP_SPEED := 860.0
const STUN_K := 1.18          # hit stun and knockback a bit longer: room after each hit, less mashing
const KNOCK_K := 1.125
const THINK_K := 1.3          # the CPU re-plans a bit less often
const THINK_MIN := 0.32
const BOT_SCALE := 1.3        # fighters are drawn this much bigger than in the garage
const FIGHT_TIME := 180.0
const UI_SCALE := 1.25
const UIK = preload("res://ui.gd")
const BUTTON_SCALES := [0.8, 1.0, 1.25]
const DIFF_THINK := [1.4, 1.0, 0.7]
const DIFF_BLOCK := [0.7, 1.0, 1.25]
const DIFF_DAMAGE := [0.75, 1.0, 1.2]
const CORE_SHARE := 0.25      # share of a limb/head hit that also hurts the torso
const HEAD_FACTOR := 0.6      # heads are hard to hit cleanly
const COMBO_BONUS := 0.08     # extra damage per hit in a combo
const BODY_PARTS := ["head", "head2", "torso", "arm_front", "arm_back", "arm_front2", "arm_back2", "leg_front", "leg_back"]
const ARM_SLOTS := ["arm_front", "arm_back", "arm_front2", "arm_back2"]
const PART_LABELS := {"head": "HEAD", "head2": "2ND HEAD", "torso": "TORSO", "arm_front": "LEFT ARM", "arm_back": "RIGHT ARM",
		"arm_front2": "LOWER LEFT ARM", "arm_back2": "LOWER RIGHT ARM", "leg_front": "LEFT LEG", "leg_back": "RIGHT LEG"}
const WEAK_BONUS := 0.15      # extra damage on the part the scanner marks as weakest
const GADGET_KEYS := [KEY_1, KEY_2, KEY_3]
## Charge: hold PUNCH or KICK. A tap shorter than CHARGE_TAP is a normal hit; longer holds charge up
## to CHARGE_MAX seconds (draining power), hitting up to CHARGE_DMG times harder. A full charge breaks a guard.
const CHARGE_TAP := 0.16
const CHARGE_MAX := 1.2
const CHARGE_DMG := 2.2
const CHARGE_DRAIN := 0.22    # share of the tank per second while charging

## The six normal hits: PUNCH or KICK, with the pad held up, level or down.
const ATTACKS := {
	"punch":     {"startup": 0.07, "active": 0.10, "recovery": 0.16, "reach": 82.0,  "damage": 7.0,  "height": "high", "stun": 0.22, "limb": "arm", "zone": "punch", "family": "punch"},
	"low_punch": {"startup": 0.08, "active": 0.10, "recovery": 0.20, "reach": 80.0,  "damage": 6.0,  "height": "low",  "stun": 0.22, "limb": "arm", "zone": "low_punch", "family": "punch"},
	"uppercut":  {"startup": 0.12, "active": 0.10, "recovery": 0.35, "reach": 72.0,  "damage": 13.0, "height": "mid",  "stun": 0.50, "limb": "arm", "zone": "uppercut", "launch": -700.0, "family": "punch"},
	"kick":      {"startup": 0.14, "active": 0.10, "recovery": 0.26, "reach": 100.0, "damage": 10.0, "height": "mid",  "stun": 0.28, "limb": "leg", "zone": "kick", "family": "kick"},
	"high_kick": {"startup": 0.17, "active": 0.10, "recovery": 0.30, "reach": 96.0,  "damage": 12.0, "height": "high", "stun": 0.32, "limb": "leg", "zone": "high_kick", "family": "kick"},
	"sweep":     {"startup": 0.12, "active": 0.12, "recovery": 0.30, "reach": 105.0, "damage": 8.0,  "height": "low",  "stun": 0.35, "limb": "leg", "zone": "sweep", "family": "kick"},
	# in the air: KICK = flying kick (dives to the floor, lands it on the way down), PUNCH = hammer
	# (both fists overhead, smashed down: blocked only standing)
	"fly_kick":  {"startup": 0.08, "active": 0.60, "recovery": 0.25, "reach": 100.0, "damage": 11.0, "height": "mid",  "stun": 0.34, "limb": "leg", "zone": "kick", "family": "kick", "air": true},
	"hammer":    {"startup": 0.16, "active": 0.12, "recovery": 0.30, "reach": 70.0,  "damage": 12.0, "height": "overhead", "stun": 0.40, "limb": "arm", "zone": "head_torso", "family": "punch", "air": true},
}
## Which hit a button makes, by the pad's height: [up, level, down]
const HITS_BY_HEIGHT := {"punch": ["uppercut", "punch", "low_punch"], "kick": ["high_kick", "kick", "sweep"]}


class Fighter:
	var label := ""
	var pilot_name := ""   # who's at the controls (HUD)
	var parts := {}
	var spec := {}
	var look := {}
	var pre_walk := false   # (1.71) walking up to its mark during the countdown
	var pre_mark := -1.0    # (1.72) how far from the middle it waits (from its reach)
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
	var vis_pose := {}       # which pose each limb was in (RobotArt.limb_poses), for the hit test
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
	var punch_turn := 0      # arms take turns: jab, cross, jab...
	var kick_turn := 0       # legs take turns too
	var aim_ang := 0.0       # the current punch/kick tilts this much toward its target (radians, - = up)
	# aiming (1.44): the head sets how long before the crosshair can go on a part again (aim_time) and how
	# long it takes to find the weakest part (scan_time); a pilot's aim level scales both for the CPU
	var aim_time := 2.5
	var scan_time := 4.0
	var aim_cd := 0.0        # seconds until this robot can aim again
	var scan_t := 0.0        # scanning progress (seconds)
	var weak := ""           # the enemy part the scan found (hits there do WEAK_BONUS more)
	var scan_on = null       # the enemy being scanned
	var ai_level := 3        # CPU pilots: 1 rookie .. 5 champion
	var ai_rattled := false  # a bad run has got to the pilot (their Read is down for now)
	var aim_acc := 0.0       # extra share of hits that go to the aimed part (aim level)
	var stance_swap := false # switched stance: the right side leads
	var daze_t := 0.0        # guard smashed open: arms flung wide, wobbling
	var knocked := false     # this hit launched it: it lands on its back (state "down") and gets up
	var last_hitter = null   # who hit it last (for the big moments)
	var special_moment := false   # this special already had its big moment
	var block_tap_t := -10.0 # when BLOCK was last pressed (a double tap switches stance)
	var charge_btn := ""     # "punch"/"kick" while the button is held (a tap or a charge)
	var charge_t := 0.0
	var charge_h := 1        # height picked when the button went down: 0 up, 1 level, 2 down
	var charge_mult := 1.0   # the hit being thrown was charged this much
	var guard_break := false # ...and fully: it breaks a guard
	var recovered_at := -10.0   # when this fighter last recovered from being hit
	var flash := 0.0
	var crouching := false
	var blocking := false
	var on_ground := true
	var walk_phase := 0.0
	var kick_hop := false   # this kick has already hopped (one hop a kick)
	var roll_a := 0.0        # no arms and no legs: the robot rolls along on its head and torso
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
	var slow_t := 0.0        # frost
	var hobble_t := 0.0      # leg got hit: slower walking
	var numb_t := 0.0        # arm got hit: weaker hits
	var armor_t := 0.0       # bulwark slam armor buff
	var haste_t := 0.0       # overclock
	var burns: Array = []    # [{slot, dps, t}]
	# teams (multibot fights)
	var team := 0            # 0 = player's side, 1 = CPU's side
	var foe = null           # the enemy this fighter is fighting right now
	var ai := {}             # this robot's own AI state (CPU robots)
	var wingman := -1        # which of the player's wingmen this is (-1 = main robot / not ours)
	var tag := ""            # little label over its head in team fights
	var gpow := 1.0          # average grade multiplier of the body parts (specials and gadgets hit this hard)
	var hp_scale := 1.0      # team robots fight with less health (your parts' real damage is scaled back after)
	var ctrl := {}           # the pilot's controller bonuses (see GameData.CONTROLLER_INFO)
	# power: every move costs some; run dry and the robot burns out for a moment
	var power := 10.0
	var power_max := 10.0
	var idle_t := 0.0        # seconds since power was last spent (refill starts after a pause)
	var burn_t := 0.0        # burned out: can't act or block
	var burn_pending := false

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

	## The limb a special move uses: the first working one (specials that hit many times take turns, see next_limb).
	func limb_for(kind: String, prefer_back: bool = false) -> String:
		if kind == "arm":
			var order := ["arm_back", "arm_front", "arm_back2", "arm_front2"] if prefer_back else ["arm_front", "arm_back", "arm_front2", "arm_back2"]
			for s in order:
				if usable_arm(s):
					return s
			return ""
		if kind == "leg":
			return "leg_front" if alive("leg_front") else ("leg_back" if alive("leg_back") else "")
		return "torso"

	## Arms (legs) take turns: jab, cross, jab. With one left it does every hit; none = "".
	## peek: don't move the turn on (just ask who would go next).
	func next_limb(kind: String, peek: bool = false) -> String:
		var ok: Array = []
		if kind == "arm":
			for s in ["arm_front", "arm_back", "arm_front2", "arm_back2"]:
				if usable_arm(s):
					ok.append(s)
		elif kind == "leg":
			for s in ["leg_front", "leg_back"]:
				if alive(s):
					ok.append(s)
		else:
			return "torso"
		if ok.is_empty():
			return ""
		var turn := punch_turn if kind == "arm" else kick_turn
		var pick: String = ok[turn % ok.size()]
		if not peek:
			if kind == "arm":
				punch_turn += 1
			else:
				kick_turn += 1
		return pick

	func has_gadget(id: String) -> bool:
		for g in gadgets:
			if g["id"] == id and gadget_working(g):
				return true
		return false

	func gadget_working(g: Dictionary) -> bool:
		var slot: String = g["slot"]
		return not parts.has(slot) or alive(slot)

	## A hit thrown with one limb: that limb's grade decides how hard it lands.
	func limb_damage(limb: Dictionary) -> float:
		return mod_damage() / gpow * float(limb.get("gm", 1.0))

	func mod_damage() -> float:
		return gpow * dmg_mult * eff * (1.4 if over_t > 0.0 else 1.0) * (0.85 if burnout else 1.0) \
				* (1.15 if style == "striker" else 1.0) * (0.85 if numb_t > 0.0 else 1.0) * (1.0 + ctrl.get("damage", 0.0))

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
		if n == 0:
			leg_factor = [0.22, 0.28, 0.35][clampi(arms(), 0, 2)]   # crawling on two arms, one, or rolling
		return (1.0 + (s / maxf(1, n) + torso_speed()) / 100.0) * leg_factor * mod_speed() * (0.8 if hobble_t > 0.0 else 1.0) * (1.0 + ctrl.get("move", 0.0))

	func attack_speed(limb: String) -> float:
		var s: float = parts[limb]["speed"] if parts.has(limb) and alive(limb) else 0.0
		var bonus: float = (1.1 if style == "striker" else 1.0) * (1.0 + 0.08 * extra_arms()) * (1.0 + ctrl.get("atk_speed", 0.0))
		return maxf(0.5, (1.0 + (s + torso_speed()) / 100.0) * mod_speed() * bonus)

	func get_look() -> Dictionary:
		if look_dirty:
			spec["parts"] = parts
			look = GameData.look_from_spec(spec)
			look_dirty = false
		look["swap"] = stance_swap
		return look

	## Arm and leg slots on the side facing the enemy right now.
	func lead_slots() -> Array:
		return ["arm_back", "arm_back2", "leg_back"] if stance_swap else ["arm_front", "arm_front2", "leg_front"]


var player: Fighter        # your main robot (first one still standing)
var cpu: Fighter           # the enemy you're focused on (the one you aimed at, or the closest)
var team_p: Array = []     # every robot on your side
var team_c: Array = []     # every robot on the CPU's side
var focus = null           # enemy picked by tapping it (team fights)
var opp: Dictionary
var fight_idx := 0
var exhibition := false
var mode := "story"
var title_text := ""
var screen := Vector2(1152, 648)
## Where draw calls go (1.57): the fight node itself for the world (the camera zooms and follows it),
## the HUD canvas on its own layer for everything on the glass (bars, buttons, captions), which stays
## sharp and the same size whatever the camera does.
var ci: CanvasItem
var hud_layer: CanvasLayer
var hud_canvas: HudCanvas


func _init() -> void:
	ci = self


## The screen layer: it asks the fight to draw the HUD onto it.
class HudCanvas extends Node2D:
	var fight: Node2D

	func _draw() -> void:
		if fight:
			fight.draw_ui(self)


## A point in the ring (world) to where it shows on the screen, through the camera.
func w2s(p: Vector2) -> Vector2:
	return position + p * scale


func s2w(p: Vector2) -> Vector2:
	return (p - position) / scale


func redraw_all() -> void:
	queue_redraw()
	if hud_canvas:
		hud_canvas.queue_redraw()
var floor_y := 420.0
var font: Font
var clock := 0.0

var touches := {}
var buttons: Array = []
var gadget_buttons: Array = []
var held_buttons := {}
var prev_held := {}
var tap_pending := false
var pressed_since := {}     # buttons pressed since the last input read (taps quicker than a frame, presses during a hit-freeze)
var quit_rect := Rect2()
var moves_rect := Rect2()
var reset_rect := Rect2()   # Test Drive: start over
var hitbox_rect := Rect2()  # Test Drive: show the hit boxes
var hitbox_view := false
var touch_device := false
var control_pads := 1      # movement pads on screen (multibot split controls use more)
var paused := false
var quit_ask := false      # the pause screen is asking "quit this fight?"
var quit_rect_p := Rect2()   # pause screen buttons
var resume_rect_p := Rect2()

var ai_timer := 0.0
var ai_plan := {}
var ai_think := 0.4
var ai_block := 0.2
var ai_smart := 0.0
# what each side has been doing lately (decays), so the CPU - and Gus - can read habits
var habit := {"punch": 0.0, "kick": 0.0, "hold": 0.0, "block": 0.0}
var limb_use := {}         # your limbs: how many hits each has thrown (sharp CPU pilots aim at your favourite)
var cpu_habit := {"punch": 0.0, "kick": 0.0, "hold": 0.0, "block": 0.0}
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
# ---- the walk-in: the announcer's show (skippable), then 3-2-1 with a barrier in the middle
var intro_step := "show"      # "show" = the announcer's cutscene, "count" = 3, 2, 1
var beat := 0                 # which part of the show
var beat_t := 0.0
var talk_beep := 0.0
var count_t := 0.0
var count_shown := -1
var barrier_kind := "crate"   # crate (scrap), podium (regional, cups), gate (championship)
var barrier_gone := false
var fight_flash := 0.0        # "FIGHT!" stays up a moment after the bell
var cam_z := 1.0
var cam_c := Vector2.ZERO
var intro_layer: CanvasLayer
var skip_rect := Rect2()
# the enemy first (that's what you want to know before you skip), then you
const SHOW_BEATS := [["b_call", 2.6], ["b_zoom", 3.4], ["a_call", 2.2], ["a_zoom", 3.0]]
const WALKIN_MUSIC := {"crate": "walkin_scrap", "podium": "walkin_arena", "gate": "walkin_grand"}
var show_paused := false
var card_t := 0.0   # how long the current card/caption has been up (keeps running while paused)
var pause_rect := Rect2()
var fight_track := ""
const COUNT_STEP := 0.8
# the same three announcers as in the story scenes: the scrap heap's rough fellow (sunburnt, stubble,
# red bandana, olive vest, a dented megaphone), the Regional / cups' ordinary fellow (red jacket, a
# plain mic) and the Championship's man in a tuxedo (silver slicked hair, bow tie, gold mic)
const ANNOUNCERS := {
	"crate": {"skin": "#b87a56", "hair": "#bf2a20", "hat": "headband", "outfit": "#5c5e38", "beard": "stubble",
		"eyes": "#3a2a1e", "glasses": "none", "scar": true, "prop": "megaphone"},
	"podium": {"skin": "#d9a07a", "hair": "#1a1a1a", "hat": "", "outfit": "#9a1a26", "beard": "none",
		"eyes": "#3a2a1e", "glasses": "none", "prop": "mic"},
	"gate": {"skin": "#ebc7a8", "hair": "#c8ccd4", "hat": "", "outfit": "#121216", "beard": "none",
		"eyes": "#2a2a35", "glasses": "none", "prop": "gold_mic"},
}


## The overlay for the show: captions, the robot's card and the SKIP button. It sits on its own
## layer so the camera zoom doesn't touch it.
class IntroOverlay extends Control:
	var fight
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if fight:
			fight.draw_intro_overlay(self)

var shake := 0.0
# Demo mode (set before the scene enters the tree): a little looping showcase of one special move,
# shown in the garage. Your robot does the move on a training dummy, over and over.
var demo_move := ""
var demo_specs: Array = []
var demo_t := 0.0
var demo_fired := false
var hitstop := 0.0          # tiny freeze on big hits
var slowmo := 0.0           # slow motion after a knockout
# big moments (1.45): a few earned moments play as short scenes you can't skip: slow motion, the
# camera punching in, the HUD out of the way. At most one every MOMENT_GAP seconds (KOs always).
const MOMENT_GAP := 8.0
var moment_t := 0.0
# (1.73) live betting while you watch: odds move with the fight, each bet keeps its price
var live_bets: Array = []      # [{side, stake, odds}]
var live_odds := [2.0, 2.0]
var live_p0 := 0.5             # the bookies' chance for the left robot before the bell
var live_t := 0.0
var live_stake_i := 1
var live_bar: Control = null
var live_btns: Array = []
var live_info: Label = null
var moment_kind := ""
var moment_on = null        # the robot the camera follows
var moment_name := ""
var last_moment_at := -100.0
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
	return UIK.tsz(size)   # the player's text size (Settings > Text size)


func _ready() -> void:
	font = ThemeDB.fallback_font
	if demo_move != "":
		setup_demo()
		return
	touch_device = DisplayServer.is_touchscreen_available()
	if GameData.fight_mode() == "open":
		GameData.start_pickup()   # (shouldn't happen: with nothing booked, FIGHT sends you to the bar first)
	fight_idx = GameData.current_opponent_index()
	mode = GameData.fight_mode()
	exhibition = mode != "story"
	title_text = GameData.fight_title()
	opp = GameData.current_opponent()
	var pspecs: Array = GameData.fight_player_team()
	var cspecs: Array = GameData.current_opponent_team()
	for k in pspecs.size():
		var f := make_fighter(pspecs[k])
		f.team = 0
		f.wingman = int(pspecs[k].get("wingman", -1))
		team_p.append(f)
	for k in cspecs.size():
		var f := make_fighter(cspecs[k])
		f.team = 1
		f.facing = -1
		team_c.append(f)
	# who's at the controls (1.56): shown under each robot's name on the HUD
	match mode:
		"watch":
			team_p[0].pilot_name = str(GameData.watch_robot(0).get("pilot", ""))
			team_c[0].pilot_name = str(GameData.watch_robot(1).get("pilot", ""))
		"quick":
			pass
		"test":
			team_p[0].pilot_name = GameData.pilot_name
			team_c[0].pilot_name = "GUS"
		_:
			team_p[0].pilot_name = GameData.pilot_name
			team_c[0].pilot_name = str(opp.get("pilot", ""))
	for t in [team_p, team_c]:
		if t.size() == 1:
			t[0].scale = maxf(t[0].scale, BOT_SCALE)   # a robot fighting alone is always full size
			t[0].spec["scale"] = t[0].scale
			t[0].look_dirty = true
		else:
			# team robots are drawn by weight class: lightweights small, middleweights medium
			for f in t:
				var power := 0.0
				for slot in f.parts:
					if not f.parts[slot].is_empty():
						power += float(GameData.part_def(f.parts[slot]["id"])["draw"])
				var wc := tr(GameData.weight_class(power))
				f.scale = BOT_SCALE * {"LIGHTWEIGHT": 0.78, "MIDDLEWEIGHT": 0.9}.get(wc, 1.0)
				f.spec["scale"] = f.scale
				f.look_dirty = true
	player = team_p[0]
	cpu = team_c[0]
	var split: bool = GameData.settings.get("team_controls", "linked") == "split"
	var humans := team_p.filter(func(f): return not f.spec.has("ai_src")).size()   # a tag partner drives itself
	control_pads = humans if humans > 1 and split and touch_device else 1   # keyboard: every robot follows WASD
	if humans > 1:
		for k in humans:
			team_p[k].tag = str(k + 1) if control_pads > 1 else "▲"
	layout()
	screen = get_viewport_rect().size
	for k in team_p.size():
		team_p[k].pos = Vector2(screen.x * (0.3 - 0.085 * k), floor_y)
	for k in team_c.size():
		team_c[k].pos = Vector2(screen.x * (0.7 + 0.085 * k), floor_y)
	var diff: int = GameData.settings["difficulty"] if mode != "watch" else 1   # a watched fight is a fair fight
	for f in team_c:
		f.dmg_mult *= DIFF_DAMAGE[diff]
		f.foe = player
		f.ai = {"timer": randf() * 0.3, "plan": {}, "think": maxf(THINK_MIN, opp["think"] * DIFF_THINK[diff] * THINK_K),
				"block": minf(0.85, opp["block"] * DIFF_BLOCK[diff]), "smart": opp["smart"],
				"special_cd": 3.0 + randf(), "gadget_cd": 1.5 + randf(), "kit": {}}
		set_aim_level(f, GameData.pilot_aim_level(opp) if diff >= 1 else maxi(1, GameData.pilot_aim_level(opp) - 1))
		f.ai_rattled = bool(opp.get("rattled", false))
		ai_load(f)
		ai_build_kit()
		ai_save(f)
	for f in team_p:
		f.foe = cpu
	# a tag partner (1.58): a world pilot on your side, with their own brain
	for f in team_p:
		if f.spec.has("ai_src") and mode != "watch":
			var src: Dictionary = f.spec["ai_src"]
			f.ai = {"timer": randf() * 0.3, "plan": {}, "think": maxf(THINK_MIN, float(src.get("think", 0.4)) * THINK_K),
					"block": minf(0.85, float(src.get("block", 0.2))), "smart": float(src.get("smart", 0.0)),
					"special_cd": 3.0 + randf(), "gadget_cd": 1.5 + randf(), "kit": {}}
			set_aim_level(f, GameData.pilot_aim_level(src))
			f.ai_rattled = bool(src.get("rattled", false))
			f.pilot_name = str(src.get("pilot", ""))
			f.foe = team_c[0]
			ai_load(f)
			ai_build_kit()
			ai_save(f)
	if GameData.is_tag() and team_c.size() > 1:
		var foes: Array = GameData.pickup.get("foes", [])
		for k in mini(foes.size(), team_c.size()):
			team_c[k].pilot_name = str(GameData.World.pilot(int(foes[k])).get("name", ""))
	if mode == "test":
		# Gus's Junkers: each one has a silly habit instead of a brain, and there's no clock
		for f in team_c:
			f.spec["junk"] = str(opp.get("junk", "dummy"))
			f.spec["next_t"] = 1.5
			f.spec["hit_t"] = -10.0
		time_left = 5999.0
	# Gus spots a part that's far better than the rest of an enemy robot
	for f in team_c:
		var ids := {}
		for slot in BODY_PARTS:
			if not f.parts[slot].is_empty():
				ids[slot] = str(f.parts[slot]["id"])
		f.spec["standout"] = GameData.World.standout_slot(ids)
	if mode == "watch":
		# both corners are computer pilots: the left robot gets a brain too
		var left_o: Dictionary = GameData.watch_robot(0)
		for f in team_p:
			f.ai = {"timer": randf() * 0.3, "plan": {}, "think": maxf(THINK_MIN, float(left_o.get("think", 0.4)) * THINK_K),
					"block": minf(0.85, float(left_o.get("block", 0.2))), "smart": float(left_o.get("smart", 0.0)),
					"special_cd": 3.0 + randf(), "gadget_cd": 1.5 + randf(), "kit": {}}
			set_aim_level(f, GameData.pilot_aim_level(left_o))
			f.ai_rattled = bool(left_o.get("rattled", false))
			ai_load(f)
			ai_build_kit()
			ai_save(f)
		assign_foes()
	cpu = team_c[0]
	player = team_p[0]
	var venue: Array = GameData.current_arena()
	arena_id = venue[0]
	crowd_id = venue[1]
	crowd = Arena.make_crowd(crowd_id, screen)
	setup_pilots()
	barrier_kind = barrier_for(arena_id)
	cam_c = screen * 0.5
	if mode == "pickup" and GameData.pickup.get("first", false) and gus_here():
		course_step = 0   # the very first fight: Old Pike, Gus's five-step course
	if mode == "test" or GameData.settings.get("skip_intros", false) or course_step >= 0:
		intro_step = "count"
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 3
	add_child(hud_layer)
	hud_canvas = HudCanvas.new()
	hud_canvas.fight = self
	hud_layer.add_child(hud_canvas)
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 5
	add_child(intro_layer)
	var ov := IntroOverlay.new()
	ov.fight = self
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(ov)
	arena_layer = ArenaLayer.new()
	arena_layer.fight = self
	arena_layer.show_behind_parent = true
	add_child(arena_layer)
	OS.low_processor_usage_mode = false   # fights animate every frame
	# boss music for OVERLORD and for any final
	var boss: bool = fight_idx == GameData.OPPONENTS.size() - 1 or GameData.fight_is_final()
	var pick: int = fight_idx if fight_idx >= 0 else randi() % 97
	fight_track = "boss" if boss else Sfx.FIGHT_TRACKS[pick % Sfx.FIGHT_TRACKS.size()]
	Sfx.music(WALKIN_MUSIC.get(barrier_kind, "walkin_arena") if intro_step == "show" else fight_track)
	Sfx.play("crowd_cheer", 0.0, -9.0)   # the crowd warms up quietly; it gets loud on big moments
	cheer = 3.0


## Robots point at each other (foe), which would keep them alive forever after the fight.
## Break those links when the fight screen closes so the memory is freed.
func _exit_tree() -> void:
	if demo_move != "":
		Sfx.quiet = maxi(0, Sfx.quiet - 1)
	for f in team_p + team_c:
		f.foe = null
		f.ai.clear()
	team_p.clear()
	team_c.clear()
	projectiles.clear()
	gadget_buttons.clear()
	pilots.clear()
	player = null
	cpu = null
	focus = null
	if arena_layer:
		arena_layer.fight = null
	OS.low_processor_usage_mode = true   # menus only redraw when something changes


## A computer pilot's aim level: its timers run faster or slower, and it lands more of its aimed hits.
func set_aim_level(f: Fighter, lv: int) -> void:
	f.ai_level = clampi(lv, 1, 5)
	var k: float = GameData.AIM_LEVEL_K[f.ai_level - 1]
	f.aim_time *= k
	f.scan_time *= k
	f.aim_cd = f.aim_time
	f.aim_acc = (f.ai_level - 3) * 0.05


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
	f.hp_scale = float(spec.get("hp_scale", 1.0))
	var gsum := 0.0
	var gn := 0
	for slot in BODY_PARTS:
		if not f.parts[slot].is_empty():
			gsum += float(f.parts[slot].get("gm", 1.0))
			gn += 1
	f.gpow = gsum / gn if gn > 0 else 1.0
	if f.hp_scale != 1.0:
		for slot in f.parts:
			if not f.parts[slot].is_empty():
				f.parts[slot]["hp"] = f.parts[slot]["hp"] * f.hp_scale
				f.parts[slot]["max_hp"] = f.parts[slot]["max_hp"] * f.hp_scale
	f.spec["scale"] = f.scale   # draw at the same size the hit boxes use
	f.specials = spec.get("specials", []).duplicate()
	f.gadgets = spec.get("gadgets", []).duplicate()
	f.style = spec.get("style", "striker")
	f.ctrl = GameData.CONTROLLER_INFO.get(str(spec.get("controller", "")), {}).get("mods", {})
	f.power_max = maxf(6.0, float(spec.get("power", 10.0))) * (1.25 if spec.get("style", "") == "tank" else 1.0)
	f.power = f.power_max
	# the best head on the robot sets how fast it aims and scans
	f.aim_time = 5.0
	f.scan_time = 8.0
	for hs in ["head", "head2"]:
		if not f.parts[hs].is_empty() and f.parts[hs].has("id"):
			var ht := GameData.head_times(GameData.part_def(str(f.parts[hs]["id"])))
			f.aim_time = minf(f.aim_time, float(ht[0]))
			f.scan_time = minf(f.scan_time, float(ht[1]))
	f.aim_cd = f.aim_time
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
	# touch buttons: default diamonds, or the player's own layout from Settings > Edit controls
	var active: Array = []
	var owners: Array = []
	for f in team_p:
		for g in f.gadgets:
			if Specials.GADGETS[g["id"]]["active"] and active.size() < 3:
				active.append(g)
				owners.append(f)
	var labels: Array = []
	for g in active:
		labels.append(tr(Specials.GADGETS[g["id"]]["short"]))
	buttons = []
	gadget_buttons = []
	for btn in Controls.make_buttons(screen, labels, control_pads):
		if str(btn["name"]).begins_with("gadget"):
			btn["gadget"] = active[int(str(btn["name"]).substr(6))]
			btn["owner"] = owners[int(str(btn["name"]).substr(6))]
			gadget_buttons.append(btn)
		else:
			buttons.append(btn)
	quit_rect = Rect2(w * 0.5 - 140.0, h * 0.04 + 52.0, 130.0, 44.0)
	moves_rect = Rect2(w * 0.5 + 10.0, h * 0.04 + 52.0, 130.0, 44.0)
	reset_rect = Rect2(w * 0.5 - 290.0, h * 0.04 + 52.0, 130.0, 44.0)
	hitbox_rect = Rect2(w * 0.5 + 160.0, h * 0.04 + 52.0, 130.0, 44.0)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if demo_move != "":
		return
	# taps on the BotMedia card on the results screen belong to its buttons, not "tap to leave"
	if post_card != null and is_instance_valid(post_card) and (event is InputEventScreenTouch or event is InputEventMouseButton) \
			and post_card.get_global_rect().has_point(event.position):
		return
	# (1.73) and taps on the live betting bar belong to its buttons
	if live_bar != null and live_bar.visible and (event is InputEventScreenTouch or event is InputEventMouseButton) \
			and live_bar.get_global_rect().has_point(event.position):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if handle_tap(event.position):
				return
			touches[event.index] = event.position
			tap_pending = true
			note_press_at(event.position)
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	elif event is InputEventMouseButton and not touch_device and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not handle_tap(event.position):
			tap_pending = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var kb := {KEY_J: "punch", KEY_K: "kick", KEY_SPACE: "jump", KEY_L: "block"}
		if kb.has(event.physical_keycode) and phase == "fight" and not paused and not tut_pause:
			pressed_since[kb[event.physical_keycode]] = true
		if phase == "intro" and intro_step == "show":
			if event.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
				skip_show()   # computers: any of these skips the announcer's show
				return
			if event.physical_keycode == KEY_P:
				show_paused = not show_paused
				return
		match event.physical_keycode:
			KEY_ENTER, KEY_SPACE:
				if paused:
					quit_ask = false
					toggle_pause()
					return
				tap_pending = true
				if Time.get_ticks_msec() - tut_pause_at > TUT_GRACE_MS:
					tut_pause = false
			KEY_ESCAPE, KEY_M:
				if paused:
					quit_ask = false
					toggle_pause()
				elif phase == "intro" or phase == "fight":
					if mode == "watch":
						quit_fight()
					else:
						toggle_pause()
			KEY_TAB, KEY_RIGHT, KEY_LEFT:
				if paused and not quit_ask:
					var i := PAUSE_TABS.find(pause_tab)
					i = (i + (PAUSE_TABS.size() - 1 if event.physical_keycode == KEY_LEFT else 1)) % PAUSE_TABS.size()
					pause_tab = PAUSE_TABS[i]
					Sfx.play("click")
			KEY_Q:
				if paused:
					if quit_ask:
						quit_fight()
					else:
						quit_ask = true
						Sfx.play("click")


## A touch landed on PUNCH / KICK / JUMP: remember it, so a tap shorter than a frame, or one during
## a hit-freeze, still counts.
func note_press_at(p: Vector2) -> void:
	if phase != "fight" or paused or tut_pause:
		return
	for b in buttons:
		if b["name"] in ["punch", "kick", "jump", "block"] and p.distance_to(b["pos"]) <= b["r"] * 1.2:
			pressed_since[b["name"]] = true


## Quit, moves list and aiming. Returns true if the tap was used.
func handle_tap(p: Vector2) -> bool:
	if tut_pause:
		# a tap that was meant for the fight (you were mashing PUNCH) mustn't skip Gus unread
		if Time.get_ticks_msec() - tut_pause_at > TUT_GRACE_MS:
			tut_pause = false   # read it: back to the fight
		return true
	if paused:
		if quit_rect_p.has_point(p):
			if quit_ask:
				quit_fight()
			else:
				quit_ask = true
				Sfx.play("click")
			return true
		if resume_rect_p.has_point(p):
			quit_ask = false
			toggle_pause()
		for k in pause_tab_rects:
			if (pause_tab_rects[k] as Rect2).has_point(p) and not quit_ask:
				pause_tab = k
				Sfx.play("click")
		return true   # (a stray tap on the move list doesn't throw you back into the fight)
	if phase != "intro" and phase != "fight":
		return false
	if phase == "intro" and intro_step == "show":
		if skip_rect.has_point(p):
			skip_show()
		elif pause_rect.has_point(p):
			show_paused = not show_paused
			Sfx.play("click")
		else:
			# tap a robot: straight to its specs (the camera is zoomed, so undo that first)
			var wp := (p - position) / scale
			for pair in [[cpu, "b_zoom"], [player, "a_zoom"]]:
				var f: Fighter = pair[0]
				if part_at(f, wp) != "" or (absf(wp.x - f.pos.x) < 130.0 * f.scale and wp.y > floor_y - 340.0 * f.scale and wp.y < floor_y + 10.0):
					for k in SHOW_BEATS.size():
						if SHOW_BEATS[k][0] == pair[1]:
							beat = k
							beat_t = 0.001
							card_t = 0.0
					Sfx.play("target")
					break
		return true
	if mode == "test" and reset_rect.has_point(p):
		Sfx.play("click")
		get_tree().reload_current_scene()
		return true
	if mode == "test" and hitbox_rect.has_point(p):
		hitbox_view = not hitbox_view
		Sfx.play("click")
		return true
	if quit_rect.has_point(p):
		if mode == "watch" or mode == "test":
			quit_fight()
		else:
			# quitting walks away with no pay: ask first, on the pause screen
			toggle_pause()
			quit_ask = true
		return true
	if moves_rect.has_point(p):
		if mode != "watch":
			toggle_pause()
		return true
	if mode == "watch":
		return false
	for b in buttons + gadget_buttons:
		if p.distance_to(b["pos"]) <= b["r"] * 1.2:
			return false
	var slot := ""
	var who: Fighter = null
	var wp := s2w(p)   # the tap, in the ring (the camera may be zoomed in)
	for e in team_c:
		if e.state == "ko":
			continue
		slot = part_at(e, wp)
		if slot != "":
			who = e
			break
	if slot == "":
		return false
	if player.target == slot and who == cpu:
		for f in team_p:
			f.target = ""
		Sfx.play("untarget")
	elif player.aim_cd > 0.0:
		# the head isn't ready: the crosshair icon is still filling
		popup(tr("AIMING... %.1fs") % player.aim_cd, visual_point(who, RobotArt.part_center(who.get_look(), slot)) + Vector2(0, -30), Color(1.0, 0.6, 0.4))
		Sfx.play("error", 0.05, -6.0)
	else:
		if team_c.size() > 1:
			focus = who
		for f in team_p:
			f.target = slot
			f.aim_cd = f.aim_time
		Sfx.play("target")
		if slot.begins_with("head"):
			coach("head", tr("Heads are small and tough, so aimed head shots miss a lot. Try the limbs!"))
	assign_foes()
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
			"punch": false, "kick": false, "punch_held": false, "kick_held": false,
			"jump": false, "jump_press": false, "gadget": -1}


func key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


## Input for each of your robots. Linked controls: every robot follows the one pad.
## Split controls: each robot has its own movement pad, the action buttons are shared.
func read_player_input() -> Array:
	held_buttons = {}
	for b in buttons + gadget_buttons:
		held_buttons[b["name"]] = false
	for t in touches.values():
		for b in buttons + gadget_buttons:
			if t.distance_to(b["pos"]) <= b["r"] * 1.2:
				held_buttons[b["name"]] = true
	var now := {
		"left": held_buttons.get("left", false) or key(KEY_A) or key(KEY_LEFT),
		"right": held_buttons.get("right", false) or key(KEY_D) or key(KEY_RIGHT),
		"up": held_buttons.get("up", false) or key(KEY_W) or key(KEY_UP),
		"down": held_buttons.get("down", false) or key(KEY_S) or key(KEY_DOWN),
		"block": held_buttons.get("block", false) or key(KEY_L),
		"punch": held_buttons.get("punch", false) or key(KEY_J),
		"kick": held_buttons.get("kick", false) or key(KEY_K),
		"jump": held_buttons.get("jump", false) or (key(KEY_SPACE) and not tut_pause),
	}
	for pad in range(1, control_pads):
		for d in Controls.MOVE_NAMES:
			now[Controls.pad_name(d, pad)] = held_buttons.get(Controls.pad_name(d, pad), false)
	for k in gadget_buttons.size():
		now["gadget%d" % k] = held_buttons["gadget%d" % k] or key(GADGET_KEYS[k])
	var shared := empty_input()
	shared["block"] = now["block"]
	# a press counts once, even if it came and went between two frames (pressed_since catches those)
	for nm in ["punch", "kick", "jump"]:
		shared[nm if nm != "jump" else "jump_press"] = (now[nm] and not prev_held.get(nm, false)) or pressed_since.has(nm)
	shared["block_press"] = (now["block"] and not prev_held.get("block", false)) or pressed_since.has("block")
	shared["punch_held"] = now["punch"]
	shared["kick_held"] = now["kick"]
	shared["jump"] = now["jump"] or pressed_since.has("jump")
	pressed_since.clear()
	for k in gadget_buttons.size():
		if now["gadget%d" % k] and not prev_held.get("gadget%d" % k, false):
			shared["gadget"] = k
	var out: Array = []
	for k in team_p.size():
		var f: Fighter = team_p[k]
		var pad := k if control_pads > 1 else 0
		var i := shared.duplicate()
		for d in Controls.MOVE_NAMES:
			var pn := Controls.pad_name(d, pad)
			i[d] = now[pn]
			# record direction presses for special-move sequences
			if now[pn] and not prev_held.get(pn, false):
				push_token(f, dir_token(f, d))
		out.append(i)
	prev_held = now
	return out


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
			if e["tok"] != seq[need - 1 - k] or last_t - e["t"] > Specials.SEQ_WINDOW + f.ctrl.get("seq", 0.0):
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


## The AI code thinks in terms of "cpu" (me) and "player" (my enemy). In team fights every CPU
## robot gets its own turn: load its state, think, save it back.
func ai_load(f: Fighter) -> void:
	cpu = f
	player = f.foe if f.foe != null else team_p[0]
	ai_timer = f.ai.get("timer", 0.0)
	ai_plan = f.ai.get("plan", {})
	ai_think = f.ai.get("think", 0.4)
	ai_block = f.ai.get("block", 0.2)
	ai_smart = f.ai.get("smart", 0.0)
	ai_special_cd = f.ai.get("special_cd", 3.0)
	ai_gadget_cd = f.ai.get("gadget_cd", 1.5)
	ai_kit = f.ai.get("kit", {"range": 0.0, "air": false})


func ai_save(f: Fighter) -> void:
	f.ai["timer"] = ai_timer
	f.ai["plan"] = ai_plan
	f.ai["special_cd"] = ai_special_cd
	f.ai["gadget_cd"] = ai_gadget_cd
	f.ai["kit"] = ai_kit


func ai_input_for(f: Fighter, delta: float) -> Dictionary:
	if f.state == "ko":
		return empty_input()
	ai_load(f)
	var i := read_ai_input(delta)
	ai_save(f)
	return i


func all_fighters() -> Array:
	return team_c + team_p


func enemies_of(f: Fighter) -> Array:
	return team_c if f.team == 0 else team_p


func team_alive(t: int) -> int:
	var n := 0
	for f in (team_p if t == 0 else team_c):
		if f.state != "ko":
			n += 1
	return n


func nearest_alive(f: Fighter, among: Array) -> Fighter:
	var best: Fighter = among[0]
	var bd := 1e9
	for e in among:
		if e.state == "ko":
			continue
		var d := absf(e.pos.x - f.pos.x)
		if d < bd:
			bd = d
			best = e
	return best


## Who fights whom: your robots go for the enemy you tapped (or the closest), CPU robots pick
## the closest of yours but don't switch targets every frame.
func assign_foes() -> void:
	if focus != null and focus.state == "ko":
		focus = null
	for f in team_p:
		f.foe = focus if focus != null else nearest_alive(f, team_c)
	for f in team_c:
		var n := nearest_alive(f, team_p)
		var cur = f.foe
		if cur == null or cur.state == "ko" or (n != cur and absf(n.pos.x - f.pos.x) + 150.0 < absf(cur.pos.x - f.pos.x)):
			f.foe = n
	# HUD / aiming: your first robot still standing, and the enemy it's on
	player = team_p[0]
	for f in team_p:
		if f.state != "ko":
			player = f
			break
	cpu = player.foe if player.foe != null else team_c[0]


func read_ai_input(delta: float) -> Dictionary:
	var i := empty_input()
	if phase != "fight":
		return i
	if str(cpu.spec.get("junk", "")) != "":
		return junk_input(i)
	ai_timer -= delta
	ai_special_cd -= delta
	ai_gadget_cd -= delta
	var dx := player.pos.x - cpu.pos.x
	var dist := absf(dx)
	var toward := "right" if dx > 0 else "left"
	var away := "left" if dx > 0 else "right"

	# react to incoming shots: shield, jump over, or block (smarter bots react more often)
	for p in projectiles:
		if (p["owner"] as Fighter).team == cpu.team or p["returning"] or p.get("ai_seen", false):
			continue
		var pdx: float = cpu.pos.x - p["pos"].x
		if absf(pdx) < 300.0 and signf(pdx) == signf(p["vel"].x):
			p["ai_seen"] = true
			if not cpu.on_ground and cpu.air_jumps > 0 and randf() < 0.4 + ai_smart * 0.5:
				ai_plan = {"hold": ["jump", away], "fresh": true, "air": true, "air_in": false, "dj_now": true}   # jet over it
				ai_timer = 0.4
			elif randf() < 0.25 + ai_smart * 0.6 and cpu.state in ["idle", "walk"]:
				var sh := ai_gadget("shield")
				if not sh.is_empty():
					use_gadget(cpu, sh)
				elif cpu.legs() > 0 and cpu.on_ground and randf() < 0.6:
					ai_plan = {"hold": ["jump", away], "fresh": true}
				elif cpu.arms() > 0:
					ai_plan = {"hold": ["block"], "fresh": true}
				ai_timer = 0.4

	if ai_timer <= 0.0:
		ai_timer = randf_range(ai_think * 0.5, ai_think)
		ai_pick_target()
		ai_plan = ai_decide(dist, toward, away)
		ai_plan["fresh"] = true
		if ai_plan.has("keep"):
			ai_timer = float(ai_plan["keep"])   # e.g. holding a charge
		# sharp pilots turn a limb you're aiming at away from you
		if cpu.ai_level >= 4 and player.target != "" and cpu.lead_slots().has(player.target) and cpu.ratio(player.target) < 0.75 \
				and cpu.on_ground and cpu.state in ["idle", "walk"] and randf() < (0.35 if cpu.ai_level == 4 else 0.55):
			switch_stance(cpu)

	for k in ai_plan.get("hold", []):
		i[k] = true
	if ai_plan.get("fresh", false) and ai_plan.has("tap"):
		i[ai_plan["tap"]] = true
	ai_plan["fresh"] = false
	var melee := ai_melee()
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
		i["jump_press"] = true
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
	# in the air and close: a flying kick or a hammer on the way down
	if not cpu.on_ground and cpu.state == "jump" and dist < 230.0 * cpu.scale and cpu.vel.y > -200.0 and randf() < 0.05 + ai_smart * 0.08:
		i["kick" if cpu.legs() > 0 and randf() < 0.6 else "punch"] = true
	# in the air above the enemy: dive stomp if we know it
	if not cpu.on_ground and cpu.state == "jump" and dist < 200.0 and cpu.specials.has("dive_stomp") and can_special(cpu, "dive_stomp") and randf() < 0.08 + ai_smart * 0.15:
		start_special(cpu, "dive_stomp")
	# combo: smarter bots follow up a landed hit (if they've got the power for it)
	if ATTACKS.has(cpu.state) and cpu.landed and cpu.power > cpu.power_max * 0.3 and randf() < ai_smart * 0.08 + (0.05 if cpu.style == "striker" else 0.0):
		i["punch" if randf() < 0.6 else "kick"] = true
	return i


## Gus's Junkers (Test Drive): no tactics, just one habit each.
func junk_input(i: Dictionary) -> Dictionary:
	var dx := player.pos.x - cpu.pos.x
	var dist := absf(dx)
	var toward := "right" if dx > 0 else "left"
	var melee := ai_melee()
	match str(cpu.spec["junk"]):
		"fridge":
			# The Fridge: blocks. Always. (a grab gets through)
			i["block"] = true
		"toaster":
			# Toaster Tim: rolls up slowly, then one big slow punch every couple of seconds
			if dist > melee:
				i[toward] = fmod(clock, 1.0) < 0.45
			elif clock > float(cpu.spec["next_t"]):
				i["punch"] = true
				cpu.spec["next_t"] = clock + 2.3
		"mower":
			# Lawnmower Larry: wanders off in a random direction, turns round, sometimes bumps into you
			if clock > float(cpu.spec["next_t"]):
				cpu.spec["next_t"] = clock + randf_range(1.0, 2.6)
				cpu.spec["wander"] = ["left", "right", ""][randi() % 3]
			var wd := str(cpu.spec.get("wander", ""))
			if wd != "":
				i[wd] = true
			if dist < melee and randf() < 0.01:
				i["kick"] = true
	return i   # (the Mop Bucket just stands there)


## The CPU's plan for the next fraction of a second, built around the parts it actually has.
func ai_decide(dist: float, toward: String, away: String) -> Dictionary:
	var free := cpu.state in ["idle", "walk", "jump"]
	var can_punch := cpu.arms() > 0
	var can_kick := cpu.legs() > 0
	var melee := ai_melee()
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
	var pw := cpu.power / maxf(1.0, cpu.power_max)
	# power: punish a burned-out enemy, and don't burn out yourself
	if player.burn_t > 0.0 and dist < melee + 40.0 and can_punch:
		return {"tap": "punch"}
	if player.burn_t > 0.0 and dist >= melee + 40.0:
		return {"hold": [toward]}
	if pw < 0.25 and not p_open and randf() < 0.35 + ai_smart * 0.6:
		if threatened and cpu.arms() > 0 and dist < 170.0 * cpu.scale:
			return {"hold": ["block"]}
		return {"hold": [away]}   # back off and recharge
	if pw < 0.45:
		can_kick = can_kick and randf() < 0.25   # kicks are hungry: save them
	# reading the player's habits (smarter bots read them more often)
	if dist < melee + 30.0 and not threatened and randf() < 0.1 + ai_smart * 0.45:
		var top := ""
		var most := 1.5
		for k in habit:
			if habit[k] > most:
				most = habit[k]
				top = k
		match top:
			"punch":
				if can_kick:
					return {"tap": "kick"}   # kicks power through punches
				if cpu.arms() > 0:
					return {"hold": ["block"]}
			"kick":
				if cpu.arms() > 0:
					return {"hold": ["block"]}   # block and let them burn their power
			"block":
				var cb := ai_charge_plan(can_punch, can_kick)
				if not cb.is_empty():
					return cb   # a full charge breaks a guard

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
			return {"hold": ["jump", away], "air": true, "air_in": false}   # jump away
		return {"hold": [away]}
	# a charged hit beats a turtle
	if player.blocking and dist < melee + 20.0 and randf() < 0.3 + ai_smart * 0.5:
		var cb2 := ai_charge_plan(can_punch, can_kick)
		if not cb2.is_empty():
			return cb2
	# 4) self-repairing robots back off to heal when hurt
	if cpu.has_gadget("regen") and hurt < 0.4 and dist < 320.0 and randf() < 0.55:
		return {"hold": [away]}
	# 5) shooters keep their distance while a shot is ready
	if ai_kit["range"] > 0.0 and ai_ranged_ready() and not aggro:
		var want: float = ai_kit["range"]
		var near_wall := cpu.pos.x < wall_l + 140.0 or cpu.pos.x > wall_r - 140.0
		if dist < want * 0.7 and not near_wall:
			if ai_kit["air"] and randf() < 0.3:
				return {"hold": ["jump", away], "air": true, "air_in": false}
			return {"hold": [away]}
		if dist > want * 1.4:
			return {"hold": [toward]}
		if dist > melee:
			return {"hold": ["down"]} if randf() < 0.3 else {}   # wait for the gadget, duck under high shots
	# cornered: jump gadgets vault right over the enemy
	var cornered := (cpu.pos.x < wall_l + 130.0 * cpu.scale and toward == "right") or (cpu.pos.x > wall_r - 130.0 * cpu.scale and toward == "left")
	if cornered and dist < 220.0 * cpu.scale and ai_kit["air"] and cpu.on_ground and randf() < 0.3 + ai_smart * 0.4:
		return {"hold": ["jump", toward], "air": true, "air_in": true}
	# 6) jumpers come in from above
	if ai_kit["air"] and can_kick and dist > melee and dist < 420.0 and randf() < 0.35:
		return {"hold": ["jump", toward], "air": true, "air_in": true}
	# 7) close the distance
	if dist > melee:
		var plan := {"hold": [toward]}
		if r < 0.06 and can_kick:
			plan["tap"] = "jump_press"
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
	if r < atk * 0.82 and can_kick:
		return {"hold": ["down"], "tap": "kick"}
	if r < atk * 0.88 and can_kick:
		return {"hold": ["up"], "tap": "kick"}   # high kick
	if r < atk * 0.94 and can_punch:
		return {"hold": ["up"], "tap": "punch"}   # uppercut
	if r < atk and can_punch:
		return {"hold": ["down"], "tap": "punch"}   # low jab
	if r < 0.88 and cpu.arms() > 0:
		return {"hold": ["block"]}
	if can_punch:
		return {"tap": "punch"}
	if can_kick:
		return {"tap": "kick"}
	return {"hold": [away]}


## How close the CPU needs to be for its punch to land: the real reach of its fist, plus a bit of the enemy.
func ai_melee() -> float:
	return maxf(strike_reach(cpu, "arm", "punch"), strike_reach(cpu, "leg", "kick")) * 0.9 + 18.0 * cpu.scale + 30.0 * player.scale


## Hold PUNCH (or KICK) for a full charge: it breaks a guard. Needs power to pay for it.
func ai_charge_plan(can_punch: bool, can_kick: bool) -> Dictionary:
	if cpu.power < cpu.power_max * 0.45 or not cpu.on_ground:
		return {}
	var btn := "punch" if can_punch and (not can_kick or randf() < 0.5) else ("kick" if can_kick else "")
	if btn == "":
		return {}
	return {"tap": btn, "hold": [btn + "_held"], "keep": CHARGE_MAX + 0.05}


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
## What the CPU puts its crosshair on, by its pilot's aim level. It can only aim when its head is
## ready (aim_cd), and every new target starts the wait again.
func ai_pick_target() -> void:
	if cpu.aim_cd > 0.0:
		return
	var want := ""
	match cpu.ai_level:
		1:
			# rookies: now and then, at whatever catches the eye
			if cpu.target == "" and randf() < 0.25:
				var opts: Array = []
				for slot in BODY_PARTS:
					if slot != "torso" and player.alive(slot):
						opts.append(slot)
				if not opts.is_empty():
					want = opts[randi() % opts.size()]
		2:
			want = cpu.weak
		3:
			# the weak spot, or the limb you keep hitting with
			want = cpu.weak if cpu.weak != "" else most_used_limb()
		_:
			# sharp pilots read the stance: the weak spot if it's in front, otherwise your lead arm
			if cpu.weak != "" and (player.lead_slots().has(cpu.weak) or cpu.weak.begins_with("head")):
				want = cpu.weak
			else:
				for slot in player.lead_slots():
					if slot.begins_with("arm") and player.alive(slot):
						want = slot
						break
				if want == "":
					want = cpu.weak
	if want != "" and want != cpu.target and player.alive(want):
		cpu.target = want
		cpu.aim_cd = cpu.aim_time


## The limb of yours that has thrown the most hits this fight.
func most_used_limb() -> String:
	var best := ""
	var most := 1.5
	for slot in limb_use:
		if float(limb_use[slot]) > most and player.alive(slot):
			most = float(limb_use[slot])
			best = slot
	return best


# ---------------------------------------------------------------- game loop

func _process(delta: float) -> void:
	if demo_move != "":
		demo_process(delta)
		return
	layout()
	if tut_pause:
		redraw_all()
		return
	if paused:
		redraw_all()
		return
	update_coach(delta)
	if mode == "watch":
		update_live_bets(delta)
	if hitstop > 0.0:
		hitstop -= delta
		redraw_all()
		return
	moment_t = maxf(0.0, moment_t - delta)
	if slowmo > 0.0:
		slowmo -= delta
		delta *= 0.35
	clock += delta
	phase_timer += delta

	assign_foes()
	var p_ins: Array = read_player_input()
	if mode == "watch":
		for k in team_p.size():
			p_ins[k] = ai_input_for(team_p[k], delta)
		assign_foes()
	else:
		var any_ally := false
		for k in team_p.size():
			if team_p[k].spec.has("ai_src"):
				p_ins[k] = ai_input_for(team_p[k], delta)   # your tag partner fights on its own
				any_ally = true
		if any_ally:
			assign_foes()
	var c_ins: Array = []
	for f in team_c:
		c_ins.append(ai_input_for(f, delta))
	assign_foes()   # restores player / cpu after the AI turns
	if course_step >= 0 and course_step < COURSE.size() - 1 and not c_ins.is_empty():
		c_ins[0] = course_input(delta)   # Old Pike does what the lesson needs
	if moment_t > 0.0:
		# a big moment plays out: nobody acts until it's done
		for k in p_ins.size():
			p_ins[k] = empty_input()
		for k in c_ins.size():
			c_ins[k] = empty_input()
	if phase == "intro" and intro_step == "count":
		# 3-2-1: walk about, but no hitting yet (and the barrier keeps you on your side)
		for k in p_ins.size():
			p_ins[k] = move_only(p_ins[k])
		# (1.71) the enemy walks steadily up to its mark and settles there. It used to roll the dice
		# every frame (walk 70% of frames), which made it stutter through the countdown.
		for k in c_ins.size():
			var cf: Fighter = team_c[k]
			c_ins[k] = empty_input()
			# (1.72) where it waits depends on its reach: long arms or legs hang back so the bell
			# finds the enemy at the tip of its fist, short ones crowd the line
			if cf.pre_mark < 0.0:
				var reach := maxf(strike_reach(cf, "arm", "punch"), strike_reach(cf, "leg", "kick"))
				cf.pre_mark = clampf(reach, 100.0, 260.0) + k * 90.0
			var mark := screen.x * 0.5 + cf.pre_mark
			if cf.pre_walk:
				if cf.pos.x <= mark:
					cf.pre_walk = false   # there: stop and hold the guard
			elif cf.pos.x > mark + 40.0:
				cf.pre_walk = true        # only starts again if it's well short of it
			c_ins[k]["left"] = cf.pre_walk
	elif phase != "fight":
		for k in p_ins.size():
			p_ins[k] = empty_input()
		for k in c_ins.size():
			c_ins[k] = empty_input()

	match phase:
		"intro":
			update_walk_in(delta)
		"fight":
			if course_step < 0 or course_step >= COURSE.size() - 1:
				time_left -= delta   # (the clock waits while you learn)
			update_course(delta)
			if time_left <= 0.0:
				time_left = 0.0
				time_up()
		"ko":
			# the KO lands, then the results come up by themselves (a tap hurries them)
			if phase_timer > 2.6 or (phase_timer > 1.0 and tap_pending):
				finish_match()
		"results":
			if phase_timer > 1.0 and tap_pending:
				leave_after_results()
	tap_pending = false

	for k in team_p.size():
		update_fighter(team_p[k], team_p[k].foe, p_ins[k], delta)
	for k in team_c.size():
		update_fighter(team_c[k], team_c[k].foe, c_ins[k], delta)
	separate()
	if phase == "intro":
		# the barrier in the middle: nobody crosses it before the bell
		var mid := screen.x * 0.5
		for f in team_p:
			f.pos.x = minf(f.pos.x, mid - 70.0)
		for f in team_c:
			f.pos.x = maxf(f.pos.x, mid + 70.0)
	fight_flash = maxf(0.0, fight_flash - delta)
	update_camera(delta)
	update_projectiles(delta)

	for f in all_fighters():
		if f.target != "" and (f.foe == null or not f.foe.alive(f.target)):
			f.target = ""

	update_effects(delta)
	update_pilots(delta)
	if mode == "test":
		for f in team_c:
			if f.spec.get("junk", "") == "dummy" and clock - float(f.spec.get("hit_t", 0.0)) > 1.6:
				for slot in f.parts:
					if not f.parts[slot].is_empty() and f.parts[slot]["hp"] < f.parts[slot]["max_hp"]:
						f.parts[slot]["hp"] = minf(f.parts[slot]["max_hp"], f.parts[slot]["hp"] + f.parts[slot]["max_hp"] * delta)
						f.look_dirty = true
	arena_redraw_t -= delta
	if arena_redraw_t <= 0.0 and arena_layer:
		arena_redraw_t = 1.0 / ARENA_FPS
		arena_layer.queue_redraw()
	redraw_all()


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
	# shards fade out; whole parts stay lying in the ring (the oldest go if there are too many)
	for d in debris:
		if d.has("life"):
			d["life"] = float(d["life"]) - delta
	debris = debris.filter(func(d): return not d.has("life") or float(d["life"]) > 0.0)
	if debris.size() > 30:
		debris = debris.slice(debris.size() - 30)
	for d in debris:
		d["vel"].y += GRAVITY * 0.8 * delta
		d["pos"] += d["vel"] * delta
		d["rot"] += d["rv"] * delta
		var rest: float = floor_y - (float((d["size"] as Vector2).y) * 0.22 if d.get("lie", false) else 4.0)
		if d["pos"].y > rest:
			d["pos"].y = rest
			d["vel"].y *= -0.35
			d["vel"].x *= 0.6
			d["rv"] *= 0.5
			if absf(d["vel"].y) > 120.0:
				Sfx.play("land", 0.3, -10.0)
			if d.get("lie", false) and absf(d["vel"].y) < 60.0:
				# settles flat on the floor
				var flat: float = PI * 0.5 if str((d["def"] as Dictionary).get("kind", "")) == "leg" else 0.0   # legs lie on their side
				d["rot"] = lerp_angle(d["rot"], round((d["rot"] - flat) / PI) * PI + flat, minf(1.0, delta * 6.0))
				d["rv"] = 0.0
				d["vel"].x = move_toward(d["vel"].x, 0.0, 600.0 * delta)
	for p in popups:
		p["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.4)
	for f in all_fighters():
		if f.state == "ko":
			continue
		for slot in BODY_PARTS:
			if slot != "torso" and f.alive(slot) and f.ratio(slot) < 0.3 and randf() < delta * 2.5:
				smoke.append({"pos": to_world_point(f, RobotArt.part_center(f.get_look(), slot)), "t": 0.0, "dark": false, "k": 0.6})
		# a hurt core smokes: a wisp under half, thick black smoke and sparks under a quarter
		if f.alive("torso"):
			var cr: float = f.ratio("torso")
			var top: Vector2 = to_world_point(f, Vector2(randf_range(-12, 12), RobotArt.geom(f.get_look())["top"] + 6.0))
			if cr < 0.25:
				if randf() < delta * 14.0:
					smoke.append({"pos": top, "t": 0.0, "dark": true, "k": 1.6})
				if randf() < delta * 3.0:
					add_spark(top + Vector2(randf_range(-20, 20), randf_range(-10, 20)), Color(1.0, 0.75, 0.3), 9.0)
			elif cr < 0.5 and randf() < delta * 4.0:
				smoke.append({"pos": top, "t": 0.0, "dark": false, "k": 0.8})
		if f.burn_t > 0.0 and randf() < delta * 6.0:
			smoke.append({"pos": f.pos + Vector2(-f.facing * 20.0, -90.0 * f.scale), "t": 0.0, "dark": true})
	for s in smoke:
		s["t"] += delta
		s["pos"] += Vector2(randf_range(-10, 10), -40.0) * delta
	smoke = smoke.filter(func(s): return s["t"] < 1.2)


func popup(text: String, at: Vector2, color: Color) -> void:
	popups.append({"text": text, "pos": at, "t": 0.0, "color": color})


func time_up() -> void:
	Sfx.play("time")
	var score := [0.0, 0.0]
	for f in team_p:
		score[0] += (f.ratio("torso") if f.state != "ko" else 0.0) / team_p.size()
	for f in team_c:
		score[1] += (f.ratio("torso") if f.state != "ko" else 0.0) / team_c.size()
	end_by(player if score[0] >= score[1] else cpu, "TIME!")


func end_by(winner: Fighter, title: String) -> void:
	phase = "ko"
	phase_timer = 0.0
	won = winner.team == 0
	pilot_say(winner.team, "win", true)
	pilot_say(1 - winner.team, "lose", true)
	ko_text = title
	cheer = 4.0
	Sfx.play("crowd_cheer")
	for loser in (team_c if won else team_p):
		if loser.state != "ko":
			loser.state = "ko"
			loser.vel = Vector2(-loser.facing * 300.0, -400.0)
			loser.on_ground = false


## A part that went in loose (half bolted on) only had half its HP in the fight; whatever it
## didn't lose in the ring it still has afterwards.
func bench_hp(p: Dictionary, scale: float) -> float:
	var hp := float(p["hp"])
	if hp > 0.0 and p.has("loose_cut"):
		hp += float(p["loose_cut"]) * scale
	return hp


func finish_match() -> void:
	if mode == "watch":
		var hp := [{}, {}]
		var torn := [[], []]
		for side in 2:
			var f: Fighter = (team_p if side == 0 else team_c)[0]
			for slot in BODY_PARTS:
				if not f.parts[slot].is_empty():
					hp[side][slot] = [float(f.parts[slot]["hp"]), float(f.parts[slot]["max_hp"])]
			torn[side] = f.ripped
		result = GameData.record_watch(won, hp, torn)
		result["watch"] = true
		settle_live_bets()
		phase = "results"
		phase_timer = 0.0
		Sfx.play("victory")
		show_post_card()
		return
	if mode == "quick" or mode == "test":
		result = {"won": won, "reward": 0}
		phase = "results"
		phase_timer = 0.0
		Sfx.play("victory" if won else "defeat")
		return
	var main: Fighter = team_p[0]
	var part_hp := {}
	for slot in BODY_PARTS:
		if main.wingman == -1 and not main.parts[slot].is_empty():
			part_hp[slot] = bench_hp(main.parts[slot], main.hp_scale) / main.hp_scale
	var team_hp: Array = []
	for f in team_p:
		if f.wingman >= 0:
			var hp := {}
			for slot in BODY_PARTS:
				if not f.parts[slot].is_empty():
					hp[slot] = bench_hp(f.parts[slot], f.hp_scale) / f.hp_scale
			team_hp.append({"wingman": f.wingman, "part_hp": hp})
	var ripped: Array = []
	for f in team_c:
		ripped += f.ripped
	GameData.last_ko = ko_text
	var ehp := {}
	for slot in BODY_PARTS:
		var ep: Dictionary = team_c[0].parts[slot]
		if not ep.is_empty():
			ehp[slot] = [float(ep["hp"]), float(ep["max_hp"])]
	GameData.last_enemy_hp = ehp
	# which of your parts came off whole (a wreck to rebuild) and which shattered (gone)
	var own_rips := {}
	for rp in main.ripped:
		own_rips[str(rp.get("slot", ""))] = bool(rp.get("intact", false))
	result = GameData.record_result(won, part_hp, ripped.size(), ripped, team_hp, own_rips)
	phase = "results"
	phase_timer = 0.0
	Sfx.play("victory" if won else "defeat")
	show_post_card()


func leave_after_results() -> void:
	Sfx.play("click")
	if mode == "test":
		leave_test_drive()
		return
	if mode == "watch":
		GameData.watching = {}
		GameData.last_result = {}
		Loading.go("res://garage.tscn")
		return
	if mode == "quick":
		GameData.quick = {}
		get_tree().change_scene_to_file("res://main.tscn")
		return
	var keys: Array = []
	if won and mode == "story" and fight_idx >= 0 and fight_idx != 9:
		keys.append("post_%d" % fight_idx)   # (OVERLORD's scene is the title: it comes with the table)
	keys += GameData.pending_stories   # emergent talk, then the year's results: medals, promotion
	GameData.pending_stories = []
	# the finale gets the big story screen; everything else plays in the garage when you get back
	if keys.has("post_9"):
		var named: Array = keys.filter(func(k): return typeof(k) == TYPE_STRING)
		if GameData.queue_stories(named, "res://garage.tscn"):
			GameData.bay_stories = keys.filter(func(k): return typeof(k) != TYPE_STRING)
			Loading.go("res://story.tscn")
			return
	GameData.bay_stories = keys
	Loading.go("res://garage.tscn")


## Back to where the test drive started (the scrapyard, or the dealer's part you were trying).
func leave_test_drive() -> void:
	var from := str(GameData.test_drive.get("from", "scrap"))
	GameData.test_drive = {}
	GameData.open_tab = "Parts"
	GameData.open_action = from
	GameData.last_result = {}
	Loading.go("res://garage.tscn")


func quit_fight() -> void:
	if mode == "test":
		Sfx.play("click")
		leave_test_drive()
		return
	Sfx.play("error")
	if mode == "watch":
		for b in live_bets:
			GameData.money += int(b["stake"])   # walked out: your live bets come back
		live_bets = []
		GameData.watching = {}   # walked out: the round will decide it on paper
		Loading.go("res://garage.tscn")
		return
	if mode == "quick":
		GameData.quick = {}
		get_tree().change_scene_to_file("res://main.tscn")
		return
	# a career fight: throwing in the towel counts as a loss, pays nothing, and the night goes on
	GameData.forfeit = true
	paused = false
	quit_ask = false
	end_by(team_c[0], "FORFEIT")
	finish_match()


# ---------------------------------------------------------------- moves

# ---------------------------------------------------------------- power
# The tank is the robot's power output (the number in Gus's bay). A move costs the power the
# limb draws, times the move's weight: punches are cheap, kicks are hungry. Refills when you
# stop attacking. Empty it and you burn out.

const MOVE_COST := {"punch": 1.0, "low_punch": 1.0, "uppercut": 1.3, "sweep": 2.0, "kick": 2.6, "high_kick": 2.8, "fly_kick": 2.4, "hammer": 1.6}
const REFILL := 0.20          # share of the tank refilled per second when not attacking
const REFILL_DELAY := 0.6     # seconds after a move before it starts refilling
const BURNOUT_TIME := 1.5
const POWER_COLOR := Color(0.25, 0.8, 1.0)


func limb_draw(f: Fighter, limb: String) -> float:
	if limb == "" or not f.parts.has(limb) or f.parts[limb].is_empty():
		return 1.0
	return maxf(1.0, float(f.parts[limb].get("draw", 1.0)))


func attack_cost(f: Fighter, attack: String, limb: String) -> float:
	var c: float = MOVE_COST.get(attack, 1.0) * limb_draw(f, limb)
	if f.style == "striker" and attack in ["punch", "low_punch", "uppercut"]:
		c *= 0.75
	return c


func special_cost(f: Fighter) -> float:
	return f.power_max * 0.28 * (0.7 if f.style == "specialist" else 1.0)


func spend(f: Fighter, cost: float) -> void:
	if phase != "fight" or cost <= 0.0:
		return
	if f.over_t > 0.0:
		cost *= 0.5   # overcharged: everything's cheap... until it isn't
	f.power -= cost
	f.idle_t = 0.0
	if f.power <= 0.0:
		f.power = 0.0
		f.burn_pending = true   # you can always throw it - but the tank's empty after


func update_power(f: Fighter, delta: float) -> void:
	f.idle_t += delta
	if f.burn_t > 0.0:
		f.burn_t -= delta
		if randf() < delta * 14.0:
			add_spark(f.pos + Vector2(randf_range(-30, 30), randf_range(-150, -60) * f.scale), POWER_COLOR, 10.0)
		if f.burn_t <= 0.0:
			f.power = f.power_max * 0.35
			f.idle_t = 0.0
		return
	var busy := ATTACKS.has(f.state) or f.state == "special" or f.state == "charge"
	if f.burn_pending and not busy and f.state != "ko":
		f.burn_pending = false
		f.burn_t = BURNOUT_TIME
		f.blocking = false
		Sfx.play("ko", 0.1, -6.0)   # the BURNOUT sign is drawn over its head (draw_burnout)
		return
	if not busy and f.idle_t > REFILL_DELAY and f.state != "ko":
		var rate := REFILL * (1.35 if f.style == "mechanic" else 1.0) * (0.4 if f.blocking else 1.0)
		f.power = minf(f.power_max, f.power + f.power_max * rate * delta)


## Throw a normal hit. charge: 0 = a plain tap, up to 1 = fully charged.
func start_attack(f: Fighter, attack: String, charge: float = 0.0) -> void:
	var a: Dictionary = ATTACKS[attack]
	var limb := f.next_limb(a["limb"])
	if limb == "":
		return
	f.state = attack
	f.kick_hop = false
	pilot_jerk(f.team)
	f.attack_limb = limb
	f.charge_mult = 1.0 + (CHARGE_DMG - 1.0) * clampf(charge, 0.0, 1.0)
	f.guard_break = charge >= 0.999
	spend(f, attack_cost(f, attack, limb))
	if f.team == 0 and ATTACKS[attack].has("family"):
		var fam: String = ATTACKS[attack]["family"]
		habit[fam] = habit.get(fam, 0.0) + 1.0
		limb_use[limb] = float(limb_use.get(limb, 0.0)) + 1.0
	elif f.team == 1 and ATTACKS[attack].has("family"):
		var fam2: String = ATTACKS[attack]["family"]
		cpu_habit[fam2] = cpu_habit.get(fam2, 0.0) + 1.0
	f.timer = 0.0
	f.hit_done = false
	f.landed = false
	f.blocking = false
	f.crouching = attack == "sweep" or attack == "low_punch"
	f.aim_ang = aim_angle(f, attack)
	if attack == "fly_kick":
		f.vel = Vector2(f.facing * 430.0 * f.scale, 620.0)   # dives at the floor, forward
	if charge > 0.0:
		Sfx.play("hit_big", 0.1, -4.0)
	Sfx.play("uppercut" if attack == "uppercut" else "swing", 0.15)


## Fire the buffered attack (or a special, if the buffered button completes a sequence).
func start_queued(f: Fighter) -> bool:
	var q := f.queued
	f.queued = ""
	var button := "P" if ATTACKS[q]["family"] == "punch" else "K"
	var sp := match_special(f, button)
	if sp != "":
		start_special(f, sp)
		return true
	var a: Dictionary = ATTACKS[q]
	if f.next_limb(a["limb"], true) == "":
		return false
	start_attack(f, q)
	return true


## Which hit a button throws at a height (0 up, 1 level, 2 down).
func hit_for(button: String, h: int) -> String:
	return HITS_BY_HEIGHT[button][clampi(h, 0, 2)]


func pad_height(i: Dictionary) -> int:
	return 0 if i["up"] and not i["down"] else (2 if i["down"] and not i["up"] else 1)


## Charging: the button is held past a tap. Returns true while the robot is busy charging.
## The head at work: the aim cooldown runs down, and the scan hunts for the enemy's weakest part.
## When the weakest part changes (a fresh dent somewhere else), the scan starts over.
func update_aim(f: Fighter, delta: float) -> void:
	f.aim_cd = maxf(0.0, f.aim_cd - delta)
	var o: Fighter = f.foe
	if o == null or o.state == "ko" or f.heads() == 0:
		return
	if f.scan_on != o:
		f.scan_on = o
		f.weak = ""
		f.scan_t = 0.0
	var wp := weak_point(o)
	if f.weak != "" and f.weak != wp:
		f.weak = ""
		f.scan_t = 0.0
	if f.weak == "" and wp != "":
		f.scan_t += delta
		if f.scan_t >= f.scan_time:
			f.weak = wp
			if f.team == 0 and f == player:
				popup(tr("WEAK SPOT FOUND"), visual_point(o, RobotArt.part_center(o.get_look(), wp)) + Vector2(0, -40), Color(1.0, 0.9, 0.2))
				Sfx.play("target", 0.1, -6.0)


## Switch stance: the other side leads (0.3 s, a little power). Anyone aiming at a limb that just
## turned away loses the crosshair, and their aim cooldown starts again.
func switch_stance(f: Fighter) -> void:
	f.stance_swap = not f.stance_swap
	f.look_dirty = true
	f.state = "switch"
	f.timer = 0.3
	f.blocking = false
	f.crouching = false
	f.squash = 0.12
	spend(f, f.power_max * 0.06)
	Sfx.play("step", 0.1, -4.0)
	var rear: Array = ["arm_front", "arm_front2", "leg_front"] if f.stance_swap else ["arm_back", "arm_back2", "leg_back"]
	for e in enemies_of(f):
		if e.foe == f and rear.has(e.target):
			e.target = ""
			e.aim_cd = e.aim_time
			if e.team == 0:
				popup(tr("LOST AIM"), visual_point(f, RobotArt.part_center(f.get_look(), "torso")) + Vector2(0, -80), Color(1.0, 0.5, 0.4))
	if f.team == 0:
		popup(tr("SWITCH!"), f.pos + Vector2(0, -230.0 * f.scale), Color(0.6, 0.9, 1.0))


func launch_jump(f: Fighter) -> void:
	var jump: float = JUMP_SPEED * (1.0 if f.legs() == 2 else 0.75) * (1.0 + f.ctrl.get("jump", 0.0))
	if f.has_gadget("high_jump"):
		jump *= 1.4
	f.vel.y = -jump
	f.on_ground = false
	f.crouching = false
	if f.team == 0:
		course_event("jump")
	f.state = "jump"
	spend(f, 0.5 * limb_draw(f, "leg_front"))
	f.air_jumps = 1 if f.has_gadget("double_jump") else 0
	Sfx.play("jump", 0.1)
	for k in 2:
		add_spark(Vector2(f.pos.x + (k * 2 - 1) * 26.0 * f.scale, floor_y - 6.0), Color(0.6, 0.6, 0.6, 0.6), 14.0 * f.scale)   # a puff of dust


func update_charge(f: Fighter, i: Dictionary, delta: float) -> bool:
	if f.charge_btn == "":
		return false
	var held: bool = i.get(f.charge_btn + "_held", false)
	var kind: String = "arm" if f.charge_btn == "punch" else "leg"
	if f.next_limb(kind, true) == "" or f.burn_t > 0.0:
		f.charge_btn = ""
		if f.state == "charge":
			f.state = "idle"
		return false
	f.charge_t += delta
	var k := clampf((f.charge_t - CHARGE_TAP) / (CHARGE_MAX - CHARGE_TAP), 0.0, 1.0)
	if held and f.charge_t < CHARGE_MAX:
		if f.charge_t >= CHARGE_TAP:
			if f.state != "charge":
				f.state = "charge"
				f.attack_limb = f.next_limb(kind, true)
				f.blocking = false
				Sfx.play("repair", 0.1, -8.0)
			if f.on_ground:
				var cdir := int(i["right"]) - int(i["left"])
				f.vel.x = cdir * WALK_SPEED * f.move_speed() * MOVE_CHARGE   # a slow step while it winds up
				if cdir != 0:
					f.walk_phase += delta * 8.0 * f.move_speed()
			spend(f, f.power_max * CHARGE_DRAIN * delta)
			if f.power <= 0.0:
				held = false   # the tank's dry: it goes now
			if randf() < delta * (6.0 + 20.0 * k):
				add_spark(visual_point(f, RobotArt.part_center(f.get_look(), f.attack_limb)) + Vector2(randf_range(-12, 12), randf_range(-12, 12)),
						Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.2), k), 10.0 + 14.0 * k)
		if held:
			return f.state == "charge"
	# let go (or the charge is full): throw it
	var btn := f.charge_btn
	var charged := f.charge_t >= CHARGE_TAP
	f.charge_btn = ""
	f.state = "idle"
	start_attack(f, hit_for(btn, f.charge_h), k if charged else 0.0)
	return true


func start_special(f: Fighter, id: String) -> void:
	var m: Dictionary = Specials.MOVES[id]
	f.state = "special"
	pilot_jerk(f.team)
	if randf() < 0.6:
		pilot_say(f.team, "special", false, (tr(Specials.MOVES[id]["name"]) as String).to_upper() + "!" if not pilots.is_empty() and not pilots[f.team]["auto"] else tr("[ EXECUTE: %s ]") % (tr(Specials.MOVES[id]["name"]) as String).to_upper())
	f.special_id = id
	f.attack_limb = f.next_limb(m["limb"]) if m.has("limb") else ""
	f.aim_ang = aim_angle(f, str(m.get("pose", "")))
	f.special_moment = false
	f.charge_btn = ""
	f.charge_mult = 1.0
	f.guard_break = false
	f.timer = 0.0
	f.hits_done = 0
	f.hit_done = false
	f.landed = false
	f.projectile_fired = false
	f.blocking = false
	f.crouching = m.get("pose", "") == "sweep"
	f.cooldowns[id] = m["cd"]
	f.buffer.clear()
	spend(f, special_cost(f))
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
	popup(tr(m["name"]).to_upper() + "!", f.pos + Vector2(0, -230.0 * f.scale), Color(0.5, 0.9, 1.0) if f.team == 0 else Color(1.0, 0.6, 0.3))
	Sfx.play("uppercut", 0.1)
	Sfx.play("target", 0.2, -6.0)


func update_special(f: Fighter, o: Fighter, delta: float) -> void:
	var m: Dictionary = Specials.MOVES[f.special_id]
	var spd := f.attack_speed(f.attack_limb) if f.attack_limb != "" else f.mod_speed()
	f.timer += delta * spd / TEMPO
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
				if f.hits_done > 1 and m.has("limb"):
					# rapid jabs and kicks take turns between the arms (legs), like normal hits
					var nl := f.next_limb(m["limb"])
					if nl != "":
						f.attack_limb = nl
						f.aim_ang = aim_angle(f, str(m.get("pose", "")))
				if m.get("finisher", false) and f.hits_done == hits:
					hit["launch"] = -650.0
					hit["knock"] = 450.0
					hit["damage"] = m["damage"] * 2.0
				f.hit_done = false
				try_hit(f, o, hit)
	# jumping specials leave the floor once the first hit has had its chance, so it lands on the way up
	if m.has("rise") and f.on_ground and f.timer >= st and f.vel.y >= 0.0 and f.legs() > 0:   # no legs, no leap: it's an uppercut from the floor
		f.vel.y = -m["rise"]
		f.on_ground = false
	if f.timer >= st + act + m.get("recovery", 0.2):
		f.state = "idle" if f.on_ground else "jump"
		f.crouching = false
		f.counter_t = 0.0


func use_gadget(f: Fighter, g: Dictionary) -> void:
	var id: String = g["id"]
	var info: Dictionary = Specials.GADGETS[id]
	if f.cooldowns.get(id, 0.0) > 0.0 or not f.gadget_working(g) or f.state in ["ko", "hit"] or f.stun_t > 0.0 or f.burn_t > 0.0:
		return
	var o: Fighter = f.foe
	if info.get("active", true) and id != "overcharge":
		spend(f, f.power_max * 0.18)
	match id:
		"rocket_fist", "grapple":
			if f.fist_out.has(g["slot"]):
				return
			f.fist_out[g["slot"]] = true
			var arm: Dictionary = f.parts[g["slot"]]
			var dmg: float = (12.0 if id == "rocket_fist" else 5.0) * (1.0 + arm["damage"] / 100.0) * f.limb_damage(arm)
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
			popup(tr("OVERCHARGE!"), f.pos + Vector2(0, -230.0 * f.scale), Color(1.0, 0.3, 0.5))
			Sfx.play("uppercut")
			Sfx.play("crowd_ooh", 0.1)
		"emp":
			rings.append({"pos": f.pos + Vector2(0, -80.0 * f.scale), "t": 0.0, "color": Color(0.7, 0.55, 1.0), "r": 220.0})
			Sfx.play("spark")
			Sfx.play("block")
			for e in enemies_of(f):
				if absf(e.pos.x - f.pos.x) < 220.0 * f.scale and e.state != "ko":
					apply_hit(f, e, {"damage": 6.0 * f.mod_damage(), "zone": "head_torso", "unblockable": true,
							"emp": 1.0, "knock": 120.0, "stun": 0.3}, e.pos + Vector2(0, -90))
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
	f.cooldowns[id] = info["cd"] * (0.6 if f.style == "specialist" else 1.0) * f.ctrl.get("gadget_cd", 1.0)


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
		var o: Fighter = owner.foe
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
		if not p["hit"]:
			for e in enemies_of(owner):
				if e.state == "ko" or e.invuln_t > 0.0:
					continue
				# a shot hits only where it touches the robot (so a high shot sails over a crouch)
				var l := visual_local(e, p["pos"])
				for r in RobotArt.regions(e.get_look()):
					if (r[1] as Rect2).grow(4.0).has_point(l):
						hit_now = true
						break
				if hit_now:
					o = e
					break
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
			f.power = 0.0   # the overcharge drains the tank: burnout
			f.burn_pending = true
	if f.has_gadget("regen") and f.alive("torso") and phase == "fight":
		f.parts["torso"]["hp"] = minf(f.parts["torso"]["max_hp"], f.parts["torso"]["hp"] + 3.6 * f.gpow * delta)
	f.slow_t = maxf(0.0, f.slow_t - delta)
	f.hobble_t = maxf(0.0, f.hobble_t - delta)
	f.numb_t = maxf(0.0, f.numb_t - delta)
	f.armor_t = maxf(0.0, f.armor_t - delta)
	f.haste_t = maxf(0.0, f.haste_t - delta)
	if phase == "fight" and f.state != "ko":
		# (mechanics repair by landing hits - see mechanic_heal - not by just standing there: the old
		# repair-over-time patched a whole robot back to full over a long fight)
		# burning parts
		for b in f.burns:
			b["t"] -= delta
			if f.alive(b["slot"]):
				damage_part(f, b["slot"], b["dps"] * delta, true)
				if randf() < delta * 12.0:
					add_spark(visual_point(f, RobotArt.part_center(f.get_look(), b["slot"])) + Vector2(randf_range(-14, 14), randf_range(-14, 8)), Color(1.0, 0.5, 0.1), 12.0)
		f.burns = f.burns.filter(func(b): return b["t"] > 0.0)
		check_ko(o, f)
	if i["gadget"] >= 0 and i["gadget"] < gadget_buttons.size() and gadget_buttons[i["gadget"]]["owner"] == f:
		use_gadget(f, gadget_buttons[i["gadget"]]["gadget"])
	if f.boost_t > 0.0:
		f.boost_t -= delta
		f.vel.x = f.facing * 1100.0 * f.scale
		if not f.boost_hit and absf(o.pos.x - f.pos.x) < 90.0 * (f.scale + o.scale) * 0.5 and absf(o.pos.y - f.pos.y) < 150.0:
			f.boost_hit = true
			apply_hit(f, o, {"damage": 10.0 * f.mod_damage(), "zone": "torso", "knock": 520.0, "stun": 0.4}, o.pos + Vector2(0, -90))

	update_power(f, delta)
	if f.burn_t > 0.0:
		i = empty_input()   # burned out: no moves, no block
	if phase == "fight":
		update_aim(f, delta)
	# a double tap on BLOCK switches stance
	if i.get("block_press", false) and f.on_ground and f.state in ["idle", "walk"]:
		if clock - f.block_tap_t < 0.32:
			switch_stance(f)
			f.block_tap_t = -10.0
		else:
			f.block_tap_t = clock
	if f.state == "switch":
		f.timer -= delta
		f.vel.x = 0.0
		if f.timer <= 0.0:
			f.state = "idle"
		i = empty_input()
	elif f.state == "prejump":
		f.timer -= delta
		if f.timer <= 0.0:
			launch_jump(f)
		i = empty_input()
	elif f.state == "down":
		# on its back after a launcher: lies there, then gets up (untouchable while it does)
		f.timer -= delta
		f.vel.x = move_toward(f.vel.x, 0.0, 1500.0 * delta)
		f.invuln_t = maxf(f.invuln_t, 0.05)
		if f.timer <= 0.0:
			f.state = "getup"
			f.timer = 0.3
			f.invuln_t = 0.35
		i = empty_input()
	elif f.state == "getup":
		f.timer -= delta
		if f.timer <= 0.0:
			f.state = "idle"
			f.recovered_at = clock
		i = empty_input()
	f.daze_t = maxf(0.0, f.daze_t - delta)
	var punch: bool = i["punch"]
	var kick: bool = i["kick"]
	if punch:
		push_token(f, "P")
	if kick:
		push_token(f, "K")
	var h := pad_height(i)

	if f.state == "ko":
		f.vel.x = move_toward(f.vel.x, 0.0, 900.0 * delta)
		f.charge_btn = ""
	elif f.state == "hit":
		f.charge_btn = ""
		f.timer -= delta
		f.vel.x = move_toward(f.vel.x, 0.0, 1200.0 * delta)
		if f.timer <= 0.0 and f.on_ground:
			f.state = "idle"
			f.recovered_at = clock
			if f.team == 1:
				f.ai["timer"] = minf(f.ai.get("timer", 0.0), randf_range(0.02, 0.1) + f.ai.get("think", 0.4) * 0.15)   # react right after recovering
	elif f.state == "special":
		update_special(f, o, delta)
	elif ATTACKS.has(f.state):
		var a: Dictionary = ATTACKS[f.state]
		f.timer += delta * f.attack_speed(f.attack_limb) / TEMPO
		if f.on_ground and f.boost_t <= 0.0:
			var mdir := int(i["right"]) - int(i["left"])
			var rooted: bool = f.timer > a["startup"] + a["active"]   # the recovery: rooted
			if PUNCHES.has(f.state) and not rooted:
				f.vel.x = mdir * WALK_SPEED * f.move_speed() * MOVE_PUNCH
				if mdir != 0:
					f.walk_phase += delta * 12.0 * f.move_speed() * MOVE_PUNCH
			elif KICKS.has(f.state) and mdir != 0 and not f.kick_hop and not rooted and f.timer >= a["startup"] * 0.5 and f.legs() >= 2:
				# a push on the pad mid-kick: a little hop that way, the leg still out
				f.kick_hop = true
				f.vel.y = -KICK_HOP_UP
				f.vel.x = mdir * WALK_SPEED * 0.75 * f.move_speed()
			else:
				f.vel.x = 0.0
		elif f.state == "fly_kick" and f.timer >= a["startup"] and f.timer <= a["startup"] + a["active"]:
			f.vel.y = maxf(f.vel.y, 620.0)
		if not f.hit_done and f.timer >= a["startup"] and f.timer <= a["startup"] + a["active"]:
			try_hit(f, o, a)
		# remember an attack pressed a little early so slower button presses still chain
		if punch or kick:
			f.queued = hit_for("punch" if punch else "kick", h)
			f.queued_t = 0.45
		# combo cancel: a normal that landed can go straight into the next attack or a special
		if f.landed and f.timer >= a["startup"] + a["active"] and f.queued != "":
			if start_queued(f):
				return
		elif f.timer >= a["startup"] + a["active"] + a["recovery"]:
			f.state = "idle"
			f.crouching = false
			f.charge_mult = 1.0
			f.guard_break = false
			if f.queued != "" and start_queued(f):
				return
	elif f.state in ["switch", "prejump", "down", "getup"]:
		pass   # busy with its own timer (handled above)
	elif update_charge(f, i, delta):
		pass
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
		elif not f.on_ground and ((punch and f.arms() > 0) or (kick and f.legs() > 0)):
			start_attack(f, "hammer" if punch else "fly_kick")
		elif (punch and f.arms() > 0) or (kick and f.legs() > 0):
			var btn := "punch" if punch else "kick"
			if i.get(btn + "_held", false) and f.on_ground:
				# still held: a tap throws it on release, a hold charges it (update_charge)
				f.charge_btn = btn
				f.charge_t = 0.0
				f.charge_h = h
			else:
				start_attack(f, hit_for(btn, h))
		elif f.on_ground:
			var dir := 0
			if not f.crouching:
				dir = int(i["right"]) - int(i["left"])
			var spd := f.move_speed() * (MOVE_BLOCK if f.blocking else 1.0)   # you can back off (or press in) behind your guard
			if f.boost_t <= 0.0:
				f.vel.x = dir * WALK_SPEED * spd
			f.state = "walk" if dir != 0 else "idle"
			if f.legs() == 0 and f.arms() == 0 and dir != 0:
				f.roll_a += f.vel.x * delta / (18.0 * f.scale)   # rolling: the turn follows the ground covered
			elif absf(f.roll_a) > 0.001:
				f.roll_a = lerp_angle(f.roll_a, round(f.roll_a / TAU) * TAU, minf(1.0, delta * 8.0))   # rocks back upright
			if dir != 0:
				f.walk_phase += delta * (8.0 if f.legs() < 2 else 12.0) * spd
				f.step_timer -= delta
				if f.step_timer <= 0.0:
					f.step_timer = 0.28 / maxf(0.4, spd)
					Sfx.play("step", 0.2, -10.0)
			if i["jump"] and not f.blocking and f.legs() > 0:
				# the knees bend first (the warning the other side can read), then it launches
				f.state = "prejump"
				f.timer = 0.08
				f.vel.x *= 0.5
		elif i["jump_press"] and f.air_jumps > 0:
			f.air_jumps -= 1
			spend(f, 0.5 * limb_draw(f, "leg_front"))
			f.vel.y = -JUMP_SPEED * 0.9
			f.vel.x = (int(i["right"]) - int(i["left"])) * WALK_SPEED * f.move_speed()
			f.jet_t = 0.35
			Sfx.play("swing", 0.1)
			Sfx.play("jump", 0.2, -4.0)
		elif not f.on_ground:
			# air control: steer left/right while jumping or falling
			var adir := int(i["right"]) - int(i["left"])
			if adir != 0:
				f.vel.x = move_toward(f.vel.x, adir * WALK_SPEED * f.move_speed(), 2200.0 * (1.0 + f.ctrl.get("jump", 0.0) * 3.0) * delta)

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
			if f.state == "fly_kick" or f.state == "hammer":
				# the air move ends on the floor: straight into its landing recovery
				var aa: Dictionary = ATTACKS[f.state]
				f.timer = maxf(f.timer, float(aa["startup"]) + float(aa["active"]))
				f.vel.x *= 0.3
			if f.state == "hit" and f.knocked:
				# launched: it lands flat on its back
				f.knocked = false
				f.state = "down"
				f.timer = 0.55
				shake = maxf(shake, 8.0)
				Sfx.play("land", 0.1, -2.0)
		f.on_ground = true
	else:
		f.on_ground = false
	f.pos.x = clampf(f.pos.x, wall_l + body_half(f) + 8.0 * f.scale, wall_r - body_half(f) - 8.0 * f.scale)
	f.squash = maxf(0.0, f.squash - delta)


## Which part a hit lands on. touched = the parts the striking limb actually reached (melee); then
## the aimed part is hit if it was touched (and the aim holds), otherwise one of the touched parts.
## Without touched (shots, blasts) the move's zone decides, as before.
func choose_part(att: Fighter, d: Fighter, zone_name: String, sure: bool = false, touched: Array = []) -> String:
	var zone: Dictionary = Specials.ZONES.get(zone_name, Specials.ZONES["any"])
	var accuracy: float = (0.45 if att.target.begins_with("head") else 0.8) + att.ctrl.get("aim", 0.0) / 100.0 + att.aim_acc
	if not touched.is_empty():
		if att.target != "" and touched.has(att.target) and d.alive(att.target) and (sure or randf() < accuracy):
			return att.target
		var tw := 0.0
		for slot in touched:
			if d.alive(slot):
				tw += float(zone.get(slot, 0.1))
		var rr := randf() * tw
		for slot in touched:
			if d.alive(slot):
				rr -= float(zone.get(slot, 0.1))
				if rr <= 0.0:
					return slot
		return "torso" if d.alive("torso") else str(touched[0])
	if att.target != "" and d.alive(att.target) and (zone.has(att.target) or zone_name == "any"):
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


# ---------------------------------------------------------------- where limbs land
# Every melee hit comes from the drawn limb: RobotArt.limb_strike gives the line from the elbow (knee)
# out to the fist (foot, blade, drill...) in the pose being thrown, the same points the drawing uses.
# A hit lands where that line first touches one of the enemy's parts, and the spark goes there.

## The pose a move shows (normal hits are named after their pose; specials say theirs).
func strike_pose(f: Fighter) -> String:
	if f.state == "special" and Specials.MOVES.has(f.special_id):
		return str(Specials.MOVES[f.special_id].get("pose", "punch"))
	return f.state


## The striking line of f's limb in a pose, in world coordinates: {"a", "b", "r"}.
func strike_line(f: Fighter, slot: String, pose: String) -> Dictionary:
	var use := slot if slot != "" and f.alive(slot) else "torso"
	if pose == "block":
		use = "torso"   # shoulder charges and slams hit with the front of the body
	var st := RobotArt.limb_strike(f.get_look(), use, pose, f.aim_ang, float(f.vis_pose.get("drop", 0.0)))
	return {"a": visual_point(f, st["a"]), "b": visual_point(f, st["b"]), "r": float(st["r"]) * f.scale}


## Where f's strike touches d: {"at": contact point, "parts": [touched parts]} or {} for a miss.
func strike_contact(f: Fighter, d: Fighter, line: Dictionary) -> Dictionary:
	if d == null or d.state == "ko":
		return {}
	# what there is to hit: d's head, torso and every limb exactly as they're drawn this frame
	var shapes := RobotArt.hit_shapes(d.get_look(), d.vis_pose)
	var grow: float = line["r"] / maxf(0.1, d.scale)
	# walk the limb from the elbow (knee) out to the tip: the first touch is where the spark goes, and
	# every part the limb passes through can take the hit (at long range only their guard is in reach)
	var steps := 12
	var at := Vector2.ZERO
	var parts: Array = []
	for k in steps + 1:
		var p: Vector2 = (line["a"] as Vector2).lerp(line["b"], float(k) / steps)
		var l := visual_local(d, p)
		for sh in shapes:
			var hit := false
			if sh[1] == "rect":
				hit = (sh[2] as Rect2).grow(grow).has_point(l)
			else:
				hit = RobotArt.seg_dist(l, sh[2], sh[3]) <= float(sh[4]) + grow
			if hit and not parts.has(sh[0]):
				if parts.is_empty():
					at = p
				parts.append(sh[0])
	if parts.is_empty():
		return {}
	return {"at": at, "parts": parts}


## How far forward (world px from f's centre) f's strike reaches in a pose: the CPU uses this to judge range.
func strike_reach(f: Fighter, kind: String, pose: String) -> float:
	var slot := f.next_limb(kind, true)
	if slot == "":
		return 0.0
	var st := RobotArt.limb_strike(f.get_look(), slot, pose)
	return (float((st["b"] as Vector2).x) + float(st["r"])) * f.scale


## The tilt (radians) a punch or kick takes toward what it's aimed at: the aimed part, or the middle
## of the enemy's torso. Limited, so ducking under a high punch still works.
func aim_angle(f: Fighter, attack: String) -> float:
	var o: Fighter = f.foe
	if o == null or o.state == "ko" or not AIM_TILT.has(attack):
		return 0.0
	var slot := f.attack_limb
	var look := f.get_look()
	var g := RobotArt.geom(look)
	var from_l: Vector2 = RobotArt.shoulder_of(g, slot) if slot.begins_with("arm") else (g["hip_front"] if slot == "leg_front" else g["hip_back"])
	var from := visual_point(f, from_l)
	var aimed := f.target if f.target != "" and o.alive(f.target) else ""
	if aimed == "":
		aimed = "head" if attack in ["uppercut", "high_kick"] and o.alive("head") else "torso"
	var want := visual_point(o, RobotArt.part_center(o.get_look(), aimed))
	var v := want - from
	# the angle the limb would need, against the angle it's drawn at untilted
	var ang := atan2(v.y / maxf(0.1, f.scale), absf(v.x) / maxf(0.1, f.scale))
	var t: Array = AIM_TILT[attack]
	return clampf(ang - float(t[0]), -float(t[1]), float(t[2]))


## How far each hit can tilt toward its target: [its own angle, most it tilts up, most it tilts down].
## Small enough that crouching under a high punch, or jumping a sweep, still works.
const AIM_TILT := {"punch": [0.02, 0.30, 0.30], "low_punch": [0.46, 0.25, 0.25], "uppercut": [-0.67, 0.2, 0.55],
		"kick": [-0.17, 0.25, 0.25], "high_kick": [-0.69, 0.2, 0.5]}


## Melee hit check: does the limb (or the body, for slams) reach the enemy?
func melee_ok(att: Fighter, d: Fighter, a: Dictionary) -> bool:
	if a.has("emp"):
		# a pulse, not a limb: anything close enough
		var dx := (d.pos.x - att.pos.x) * att.facing
		return d.state != "ko" and dx >= -10.0 and dx <= (a.get("reach", 80.0) + 35.0) * att.scale and absf(d.pos.y - att.pos.y) <= 130.0
	return not strike_contact(att, d, strike_line(att, att.attack_limb, strike_pose(att))).is_empty()


func try_hit(att: Fighter, d: Fighter, a: Dictionary) -> void:
	if phase != "fight":
		return
	body_pose(att)   # where everything is this frame, exactly as it's about to be drawn
	var line := strike_line(att, att.attack_limb, strike_pose(att))
	var contact := {}
	var pool: Array = [d] if d != null else []
	for e in enemies_of(att):
		if e != d:
			pool.append(e)
	for e in pool:
		if e == null or e.state == "ko" or e.invuln_t > 0.0:
			continue
		body_pose(e)
		if a.has("emp"):
			if melee_ok(att, e, a):
				contact = {"at": e.pos + Vector2(0, -90.0 * e.scale), "parts": []}
		else:
			contact = strike_contact(att, e, line)
		if not contact.is_empty():
			d = e
			break
	if contact.is_empty():
		return
	if a.get("height", "mid") == "high" and d.crouching:
		return  # ducked under it
	if a.get("height", "mid") == "low" and not d.on_ground:
		return  # jumped over it
	att.hit_done = true
	var limb: Dictionary = att.parts[att.attack_limb] if att.parts.has(att.attack_limb) and att.alive(att.attack_limb) else {"damage": 0}
	var hit := a.duplicate()
	# a limb hits as hard as its grade; body moves (charges, slams, pulses) hit as hard as the whole robot
	var grade_k: float = att.limb_damage(limb) if limb.has("gm") else att.mod_damage()
	hit["damage"] = a["damage"] * (1.0 + limb["damage"] / 100.0) * grade_k * att.charge_mult
	hit["src"] = att.attack_limb
	hit["touched"] = contact["parts"]
	if att.guard_break:
		hit["guard_break"] = true
		hit["knock"] = float(a.get("knock", 320.0)) * 1.5
	apply_hit(att, d, hit, contact["at"])


## Apply a hit that connected (melee, projectile or gadget).
func apply_hit(att: Fighter, d: Fighter, a: Dictionary, at: Vector2) -> void:
	if d.state == "ko" or phase != "fight":
		return
	att.landed = true
	if att.state == "special" and not att.special_moment and Specials.MOVES.has(att.special_id) and Specials.MOVES[att.special_id]["seq"].size() >= 5:
		att.special_moment = true   # a finisher that lands: a short cinematic with its name
		big_moment("finisher", d, 1.5, tr(Specials.MOVES[att.special_id]["name"]).to_upper())
	var touched: Array = a.get("touched", [])
	var slot := choose_part(att, d, a.get("zone", "punch"), a.get("sure_aim", false), touched)
	var hit_at := to_world_point(d, RobotArt.part_center(d.get_look(), slot))
	# the spark goes where the limb met the body (shots and blasts: at the part they hit)
	var spark_pos := at if not touched.is_empty() else Vector2(at.x, hit_at.y)
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
		popup(tr("COUNTER!"), d.pos + Vector2(0, -230.0 * d.scale), Color(1.0, 1.0, 0.4))
		Sfx.play("block")
		var back := m.duplicate()
		back["damage"] = m["damage"] * d.mod_damage()
		back["unblockable"] = true
		apply_hit(d, att, back, att.pos + Vector2(0, -90.0 * att.scale))
		return

	var src: String = a.get("src", "")
	var blocked: bool = d.blocking and d.arms() > 0 and not a.get("unblockable", false) \
			and (a.get("height", "mid") != "low" or d.crouching) and (a.get("height", "mid") != "overhead" or not d.crouching)
	d.last_hitter = att
	if blocked and a.get("guard_break", false):
		# a fully charged hit smashes the guard open
		blocked = false
		d.blocking = false
		popup(tr("GUARD BROKEN!"), d.pos + Vector2(0, -220.0 * d.scale), Color(1.0, 0.6, 0.3))
		d.daze_t = 0.6
		Sfx.play("break", 0.1)
		shake = maxf(shake, 14.0)
	# evasion: a clean miss
	var dodge: float = minf(25.0, part_trait_sum(d, "dodge") * 0.6 + d.gtraits.get("dodge", 0.0))
	if not blocked and not a.get("unblockable", false) and randf() * 100.0 < dodge:
		popup(tr("DODGE"), d.pos + Vector2(0, -200.0 * d.scale), Color(0.7, 1.0, 1.0))
		Sfx.play("swing", 0.2)
		d.pos.x += att.facing * 20.0
		return
	if blocked:
		var family: String = a.get("family", "")
		spend(d, 0.3 + dmg * 0.04)   # taking hits on the guard costs power
		var arm := "arm_front"
		for s2 in ARM_SLOTS:
			if d.alive(s2):
				arm = s2
				break
		if family == "kick":
			# a kick only partly stops on a guard: some gets through and it shoves you back
			damage_part(d, arm, dmg * (0.2 if d.style == "tank" else 0.35) * d.ctrl.get("block", 1.0))
			if d.alive("torso"):
				damage_part(d, "torso", dmg * 0.1)
			d.pos.x += att.facing * 60.0
			popup(tr("CHIP"), d.pos + Vector2(0, -200.0 * d.scale), Color(1.0, 0.75, 0.4))
		else:
			damage_part(d, arm, dmg * (0.08 if d.style == "tank" else 0.3) * d.ctrl.get("block", 1.0))
			d.pos.x += att.facing * 25.0
		if family == "punch" and ATTACKS.has(att.state):
			# block beats punch: the fist bounces off and the puncher is left open
			att.state = "hit"
			att.timer = 0.32
			att.vel.x = -att.facing * 240.0
			att.crouching = false
			popup(tr("BLOCKED!"), att.pos + Vector2(0, -210.0 * att.scale), Color(0.6, 0.85, 1.0))
		add_spark(spark_pos, Color(0.7, 0.85, 1.0), 18.0)
		Sfx.play("block", 0.15)
		if d.team == 0 and family == "punch":
			course_event("block")
	else:
		if att.team == 0:
			course_event("hit")
		# combos: hits while the enemy is still reeling
		# still reeling, or only just recovered (a slightly late press still counts)
		if att.combo_timer > 0.0 and (d.state == "hit" or clock - d.recovered_at < 0.35):
			att.combo += 1
		else:
			att.combo = 1
		att.combo_timer = 1.25 + att.ctrl.get("combo", 0.0)
		if att.combo >= 2:
			att.combo_show = 1.2
			if att.combo == 3 or att.combo == 5 or att.combo >= 8:
				Sfx.play("crowd_ooh", 0.2, -6.0)
		dmg *= 1.0 + COMBO_BONUS * minf(att.combo - 1, 6)
		if att.combo >= 3:
			pilot_say(att.team, "combo")
		elif randf() < 0.35:
			pilot_say(att.team, "hit")
		if randf() < 0.3:
			pilot_say(d.team, "hurt")
		if slot == att.target:
			dmg *= 1.0 + att.best_aim() / 100.0
			if att.style == "specialist":
				dmg *= 1.25
		if att.weak != "" and slot == att.weak:
			dmg *= 1.0 + WEAK_BONUS   # only once your head's scan has found it
		# precision: critical hits
		var crit: float = off_trait(att, src, "crit") + (5.0 if att.style == "striker" else 0.0)
		if randf() * 100.0 < crit:
			dmg *= 2.0
			popup(tr("CRITICAL!"), hit_at + Vector2(0, -30), Color(1.0, 0.95, 0.3))
		# reactive armor: this part may shrug it off
		if randf() * 100.0 < limb_trait(d, slot, "reactive") * 2.0 / (1.0 if slot.begins_with("head") or slot == "torso" else 2.0):
			dmg *= 0.25
			popup(tr("DEFLECTED"), hit_at + Vector2(0, -30), Color(0.7, 0.8, 1.0))
			add_spark(hit_at, Color(0.7, 0.8, 1.0), 30.0)
		var part_dmg := dmg * (HEAD_FACTOR if slot.begins_with("head") else 1.0)
		damage_part(d, slot, part_dmg)
		if slot != "torso" and d.alive("torso"):
			damage_part(d, "torso", dmg * CORE_SHARE)
		# every part matters: hurt legs slow you down, hurt arms hit softer
		if att.team == 0 and slot.begins_with("leg"):
			coach("leg_hit", tr("Leg hit! Damaged legs make it slower."))
		elif att.team == 0 and slot.begins_with("arm"):
			coach("arm_hit", tr("Arm hit! Damaged arms make its punches go soft."))
		if slot.begins_with("leg"):
			if d.hobble_t <= 0.0 and d == cpu:
				popup(tr("HOBBLED"), hit_at + Vector2(0, 20), Color(1.0, 0.75, 0.4))
			d.hobble_t = 1.5
		elif slot.begins_with("arm"):
			if d.numb_t <= 0.0 and d == cpu:
				popup(tr("NUMBED"), hit_at + Vector2(0, 20), Color(1.0, 0.75, 0.4))
			d.numb_t = 1.5
		# offensive traits
		var burn := off_trait(att, src, "burn")
		if burn > 0.0 and d.alive(slot):
			d.burns.append({"slot": slot, "dps": burn / 3.0 * att.gpow, "t": 3.0})
		var chill := off_trait(att, src, "chill")
		if chill > 0.0:
			d.slow_t = maxf(d.slow_t, chill)
			add_spark(hit_at, Color(0.6, 0.85, 1.0), 26.0)
		var leech: float = off_trait(att, src, "leech")
		if leech > 0.0 and att.alive("torso"):
			att.parts["torso"]["hp"] = minf(att.parts["torso"]["max_hp"], att.parts["torso"]["hp"] + dmg * leech / 100.0)
		# mechanics fix themselves with every hit they land: 20% of the damage dealt goes to their most
		# beaten-up part - dents brought in from earlier fights included (and it stays fixed afterwards)
		if att.style == "mechanic":
			mechanic_heal(att, dmg * 0.2)
		# spikes hurt whoever hits the torso up close
		if d.has_gadget("thorns") and slot == "torso" and absf(att.pos.x - d.pos.x) < 160.0:
			var limb := att.attack_limb if att.alive(att.attack_limb) and att.attack_limb != "torso" else "torso"
			damage_part(att, limb, dmg * 0.25)
			add_spark(att.pos + Vector2(att.facing * 40.0, -100.0 * att.scale), Color(0.8, 0.8, 0.8), 14.0)
		# kick beats punch: a kick on its way powers through punches (it still takes the damage)
		var armored: bool = a.get("family", "") == "punch" and (d.state == "kick" or d.state == "sweep" or d.state == "high_kick") \
				and d.timer <= float(ATTACKS[d.state]["startup"]) + float(ATTACKS[d.state]["active"])
		if armored:
			popup(tr("POWERED THROUGH"), d.pos + Vector2(0, -220.0 * d.scale), Color(0.85, 0.9, 1.0))
			add_spark(hit_at, Color(0.85, 0.9, 1.0), 34.0)
		if d.state != "ko" and not armored:
			d.charge_btn = ""   # a hit knocks a charge out
			d.state = "hit"
			d.timer = maxf(float(a.get("stun", 0.25)) * STUN_K, a.get("emp", 0.0))
			if d.daze_t > 0.0:
				d.timer = maxf(d.timer, d.daze_t)
			d.crouching = false
			d.blocking = false
			d.special_id = ""
			d.boost_t = 0.0
			d.vel.x = att.facing * float(a.get("knock", 320.0)) * KNOCK_K
			if off_trait(att, src, "magnet") > 0.0:
				d.vel.x = -att.facing * 260.0   # magnets yank the enemy in
			if a.has("launch"):
				d.vel.y = a["launch"]
				d.on_ground = false
				d.knocked = true   # it lands on its back
			if randf() * 100.0 < off_trait(att, src, "stun"):
				d.timer = maxf(d.timer, 0.8)
				d.stun_t = maxf(d.stun_t, 0.8)
				popup(tr("SHOCKED!"), hit_at + Vector2(0, -30), Color(1.0, 1.0, 0.4))
				add_spark(hit_at, Color(1.0, 1.0, 0.5), 40.0)
		if a.has("emp"):
			d.stun_t = a["emp"]
			add_spark(hit_at, Color(0.7, 0.55, 1.0), 40.0)
		d.flash = 0.12
		shake = maxf(shake, 8.0 + minf(dmg, 20.0) * 0.3)
		hitstop = maxf(hitstop, 0.04 + minf(dmg, 25.0) * 0.004)
		add_spark(spark_pos, Color(1.0, 0.85, 0.3), 30.0)
		# a punch cracks, a kick thuds lower
		var fam_k := str(a.get("family", ""))
		Sfx.play("hit_big" if dmg >= 12.0 else "hit", 0.08, 0.0, 0.78 if fam_k == "kick" else (1.12 if fam_k == "punch" else 1.0))

	check_ko(att, d)


## Knock out whoever has lost their core or every head. att = the fighter that caused it.
func check_ko(att: Fighter, d: Fighter) -> void:
	if phase != "fight" or att == null or d == null:
		return
	if d.state == "ko":
		pass
	elif not d.alive("torso"):
		knockout(att, d, "CORE DESTROYED")
	elif d.heads() == 0:
		knockout(att, d, "HEAD KNOCKED OFF" if d.parts["head2"].is_empty() else "BOTH HEADS KNOCKED OFF")
	if att.state != "ko" and (not att.alive("torso") or att.heads() == 0):   # thorns or explosions can finish an attacker
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


func mechanic_heal(f: Fighter, amount: float) -> void:
	var worst := ""
	for s in BODY_PARTS:
		if f.alive(s) and f.parts[s]["hp"] < f.parts[s]["max_hp"] and (worst == "" or f.ratio(s) < f.ratio(worst)):
			worst = s
	if worst != "":
		f.parts[worst]["hp"] = minf(f.parts[worst]["max_hp"], f.parts[worst]["hp"] + amount)
		f.look_dirty = true


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
	if f.spec.get("junk", "") == "dummy":
		# the Mop Bucket never breaks: it dents, then pops back out
		p["hp"] = maxf(p["hp"], 1.0)
		f.spec["hit_t"] = clock
		return
	if p["hp"] <= 0.0:
		var overkill := -float(p["hp"]) / maxf(1.0, float(p["max_hp"]))   # how far past zero the hit went
		p["hp"] = 0.0
		if slot != "torso":
			rip_off(f, slot, overkill)


## A part comes off. A roll decides how: INTACT, the real part flies off and lies in the ring (salvage
## for the winner, a wreck you can rebuild if it was yours); BROKEN, it shatters into shards (gone).
## A clean aimed rip mostly comes off intact; an overkill hit or an explosion mostly breaks it.
func rip_off(f: Fighter, slot: String, overkill: float = 0.0) -> void:
	var p: Dictionary = f.parts[slot]
	var aimed := false
	for e in enemies_of(f):
		if e.target == slot and e.foe == f:
			aimed = true
	var boom: float = (limb_trait(f, slot, "explosive") + f.gtraits.get("explosive", 0.0)) * float(p.get("gm", f.gpow))
	var keep := 0.75 if aimed else 0.5
	if overkill > 0.6:
		keep *= 0.4
	if boom > 0.0:
		keep = 0.15
	var intact := randf() < keep
	f.ripped.append({"id": p["id"], "aimed": aimed, "slot": slot, "intact": intact})
	if f.team == 1:
		if aimed:
			coach("aimed_rip", tr("Clean rip! Parts you AIM at mostly come off in one piece, and whole parts come home with us after a win."))
		else:
			coach("rip_any", tr("Ripped off! Aim at a part first and it usually comes off whole. Free spare parts."))
	else:
		coach("own_lost", tr("We lost a part! If it came off whole we can rebuild it. If it shattered, it's gone."))
	f.fist_out.erase(slot)
	f.burns = f.burns.filter(func(b): return b["slot"] != slot)
	var at := to_world_point(f, RobotArt.part_center(f.get_look(), slot))
	var d := GameData.part_def(str(p["id"]))
	var big := Vector2(70, 70) if slot.begins_with("leg") or slot == "torso" else Vector2(56, 56)
	if intact:
		# the real part flies off, bounces, and stays lying in the ring
		debris.append({"pos": at, "vel": Vector2(-f.facing * randf_range(150, 350), randf_range(-650, -400)),
				"rot": 0.0, "rv": randf_range(-10, 10), "size": big * f.scale, "color": p["color"], "def": d, "lie": true})
		popup(tr("INTACT"), at + Vector2(0, -36), Color(0.6, 1.0, 0.7))
	else:
		# it shatters: shards in its colour, sparks and a puff of smoke
		for k in 8:
			debris.append({"pos": at + Vector2(randf_range(-14, 14), randf_range(-14, 14)), "vel": Vector2(randf_range(-420, 420), randf_range(-700, -250)),
					"rot": randf() * TAU, "rv": randf_range(-20, 20), "size": Vector2(randf_range(8, 18), randf_range(5, 12)) * f.scale, "color": p["color"], "shard": true, "life": 1.6})
		for k in 5:
			smoke.append({"pos": at + Vector2(randf_range(-16, 16), randf_range(-16, 16)), "t": 0.0, "dark": true, "k": 1.3})
		popup(tr("SHATTERED"), at + Vector2(0, -36), Color(1.0, 0.55, 0.4))
	for k in 3:
		add_spark(at + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(1.0, 0.6, 0.2), 26.0)
	# a rip plays in full when it's earned: your locked aim tore it off, it's the first of your career,
	# it's their last arm or leg, or a strong (4-key) special did it
	var hitter = f.last_hitter
	var strong: bool = hitter != null and hitter.state == "special" and Specials.MOVES.has(hitter.special_id) and Specials.MOVES[hitter.special_id]["seq"].size() >= 4
	var last_limb := (slot.begins_with("arm") and f.arms() == 0) or (slot.begins_with("leg") and f.legs() == 0)
	var first_ever: bool = mode != "quick" and mode != "test" and mode != "watch" and not GameData.story_seen.has("first_rip")
	if aimed or last_limb or first_ever or strong:
		if first_ever:
			GameData.story_seen.append("first_rip")
		big_moment("rip", f, 1.0)
	else:
		hitstop = maxf(hitstop, 0.1)
	popup(tr("%s LOST!") % tr(PART_LABELS[slot]) if f.team == 0 else tr("%s DESTROYED!") % tr(PART_LABELS[slot]), at,
			Color(1.0, 0.3, 0.2) if f.team == 0 else Color(1.0, 0.85, 0.2))
	if f.blocking and f.arms() == 0:
		f.blocking = false
	pilot_say(1 - f.team, "rip_enemy", true)
	pilot_say(f.team, "rip_own")
	shake = 16.0
	hitstop = maxf(hitstop, 0.14)
	cheer = maxf(cheer, 1.5)
	Sfx.play("break")
	Sfx.play("crowd_ooh", 0.1)
	if boom > 0.0:
		rings.append({"pos": at, "t": 0.0, "color": Color(1.0, 0.5, 0.1), "r": 180.0})
		Sfx.play("hit_big")
		popup(tr("KABOOM!"), at + Vector2(0, -40), Color(1.0, 0.5, 0.1))
		for e in enemies_of(f):
			if absf(e.pos.x - f.pos.x) < 200.0 * f.scale and e.state != "ko":
				damage_part(e, "torso", boom)
				e.flash = 0.12
				check_ko(f, e)


func knockout(att: Fighter, d: Fighter, why: String) -> void:
	d.state = "ko"
	d.vel = Vector2(att.facing * 400.0, -500.0)
	d.on_ground = false
	d.blocking = false
	d.burns.clear()
	if team_alive(d.team) > 0:
		# one robot down, the rest of its team fights on
		popup(tr("%s IS DOWN!") % d.label, d.pos + Vector2(0, -240.0 * d.scale), Color(1.0, 0.4, 0.3) if d.team == 0 else Color(1.0, 0.85, 0.2))
		shake = 14.0
		hitstop = 0.15
		cheer = 2.5
		Sfx.play("ko")
		Sfx.play("crowd_cheer")
		return
	shake = 18.0
	hitstop = 0.22
	slowmo = 1.3
	Sfx.play("ko")
	# the knockout always plays in full, longer when a playoff or the title is on the line
	var big := mode == "story" and (str(GameData.event.get("phase", "")) == "finals" or str(GameData.event.get("stage", "")) == "title")
	big_moment("ko", d, 2.8 if big else 2.2, tr("K.O."))
	end_by(att, why)


## A big moment: slow motion, the camera punches in on `on`, the HUD steps aside. Earned moments
## only, and at most one every MOMENT_GAP seconds; a second one inside the gap is a quick beat
## (a heavier hit-freeze and shake) instead. KOs always play.
func big_moment(kind: String, on: Fighter, dur: float, name: String = "") -> void:
	if kind != "ko" and clock - last_moment_at < MOMENT_GAP:
		hitstop = maxf(hitstop, 0.12)
		shake = maxf(shake, 14.0)
		return
	last_moment_at = clock
	moment_t = dur
	moment_kind = kind
	moment_on = on
	moment_name = name
	slowmo = maxf(slowmo, dur)
	if kind == "finisher":
		hitstop = maxf(hitstop, 0.25)   # a freeze frame first
		Sfx.play("crowd_ooh", 0.05)
	cheer = maxf(cheer, dur)


func separate() -> void:
	for a in team_p:
		for b in team_c:
			if a.state == "ko" or b.state == "ko":
				continue
			var dx: float = b.pos.x - a.pos.x
			# the bodies themselves can't overlap: each robot's real torso width
			var gap: float = body_half(a) + body_half(b) + 4.0
			if absf(dx) < gap and absf(b.pos.y - a.pos.y) < 120.0:
				var push := (gap - absf(dx)) * 0.5
				var sgn := 1.0 if dx >= 0.0 else -1.0
				a.pos.x = clampf(a.pos.x - push * sgn, wall_l + body_half(a) + 8.0 * a.scale, wall_r - body_half(a) - 8.0 * a.scale)
				b.pos.x = clampf(b.pos.x + push * sgn, wall_l + body_half(b) + 8.0 * b.scale, wall_r - body_half(b) - 8.0 * b.scale)


## Half the robot's real torso width, in world px.
func body_half(f: Fighter) -> float:
	return float(RobotArt.geom(f.get_look())["tw"]) * 0.5 * f.scale


func add_spark(p: Vector2, c: Color, size: float) -> void:
	sparks.append({"pos": p, "t": 0.0, "color": c, "size": size})


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	if arena_layer:
		arena_layer.position = off * 0.6   # screen shake moves the whole arena
	if demo_move == "":
		draw_gus(off)   # Gus stands behind your pilot, so draw him first
		for pd in pilots:
			draw_pilot(pd, off)
	draw_walk_in(off)
	draw_cables(off)
	# knocked-out robots first, so the ones still fighting are drawn on top
	for f in all_fighters():
		if f.state == "ko":
			draw_fighter(f, off)
	for f in all_fighters():
		if f.state != "ko":
			draw_fighter(f, off)
	if team_p.size() > 1 or team_c.size() > 1:
		for f in all_fighters():
			draw_tag(f, off)
	for f in all_fighters():
		draw_burnout(f, off)
	draw_projectiles(off)

	for d in debris:
		var sz: Vector2 = d["size"]
		if d.has("def"):
			PartIcon.draw_part_at(ci, d["pos"] + off, sz.x, d["def"], 0.25, d["rot"])   # the real part, lying where it fell
			continue
		ci.draw_set_transform(d["pos"] + off, d["rot"], Vector2.ONE)
		var col: Color = d["color"]
		if d.has("life"):
			col.a = clampf(float(d["life"]) / 0.6, 0.0, 1.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-sz.x * 0.5, -sz.y * 0.3), Vector2(sz.x * 0.4, -sz.y * 0.5), Vector2(sz.x * 0.5, sz.y * 0.4), Vector2(-sz.x * 0.2, sz.y * 0.5)]), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for s in smoke:
		var t: float = s["t"] / 1.2
		var c := Color(0.08, 0.08, 0.08, 0.65 * (1.0 - t)) if s["dark"] else Color(0.35, 0.35, 0.37, 0.45 * (1.0 - t))
		ci.draw_circle(s["pos"] + off, (6.0 + t * 14.0) * float(s.get("k", 1.0)), c)
	for s in sparks:
		var t: float = s["t"] / 0.25
		var c: Color = s["color"]
		c.a = 1.0 - t
		ci.draw_circle(s["pos"] + off, s["size"] * (0.4 + t), c)
	for r in rings:
		var t: float = r["t"] / 0.4
		var c: Color = r["color"]
		c.a = 1.0 - t
		ci.draw_arc(r["pos"] + off, r["r"] * t, 0, TAU, 40, c, 6.0)

	if hitbox_view:
		draw_hitboxes(off)
	draw_weak_point(cpu, off)
	draw_crosshair(player.target, cpu, Color(1.0, 0.2, 0.2, 0.9), off, 1.0)
	for e in team_c:
		if e.state != "ko" and e.foe != null:
			draw_crosshair(e.target, e.foe, Color(1.0, 0.6, 0.1, 0.75), off, 0.75 if e == team_c[0] else 0.6)
	for p in popups:
		var t: float = p["t"] / 1.4
		var c: Color = p["color"]
		c.a = 1.0 - t * t
		ci.draw_string(font, p["pos"] + Vector2(-260, -40.0 - t * 50.0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 520, fs(26), c)

	if demo_move != "":
		return   # the move showcase: just the robots
	if phase == "intro" and intro_step == "show":
		draw_show_marks(off)


## Everything on the glass, drawn onto the HUD layer (c): it doesn't zoom with the camera.
func draw_ui(c: CanvasItem) -> void:
	if demo_move != "" or player == null:
		return
	ci = c
	_draw_ui()
	ci = self


func _draw_ui() -> void:
	if phase == "intro" and intro_step == "show":
		return   # the show: no HUD, no buttons - the overlay does the talking
	if moment_t > 0.0:
		draw_moment_caption()
		return   # a big moment: the camera's in close, the HUD steps aside
	draw_hud()
	if mode == "test" and (phase == "fight" or phase == "intro"):
		draw_input_readout()
	draw_coach()
	if (phase == "intro" or phase == "fight") and mode != "watch":
		draw_buttons()
		if not touch_device:
			draw_key_strip()
	if course_on() and phase == "fight":
		draw_course()
	if paused:
		draw_moves_list()
	if tut_pause:
		ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.55))
		draw_coach()
		if Time.get_ticks_msec() - tut_pause_at > TUT_GRACE_MS:
			ci.draw_string(font, Vector2(0, screen.y * 0.62), tr("Tap to continue"), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(26),
					Color(1, 1, 1, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)))


## Test Drive's HITBOX switch: every part's box (what a hit has to touch) and every striking limb's line
## (what does the touching), so you can see exactly why a hit landed or missed.
func draw_hitboxes(off: Vector2) -> void:
	for f in all_fighters():
		if f.state == "ko":
			continue
		var look: Dictionary = f.get_look()
		var hc := Color(0.3, 1.0, 0.5, 0.8) if f.team == 0 else Color(1.0, 0.45, 0.35, 0.8)
		for sh in RobotArt.hit_shapes(look, f.vis_pose):
			if sh[1] == "rect":
				var rc: Rect2 = sh[2]
				var pts := PackedVector2Array()
				for c in [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y), rc.position]:
					pts.append(visual_point(f, c) + off)
				ci.draw_polyline(pts, hc, 2.0)
			else:
				var a2 := visual_point(f, sh[2]) + off
				var b2 := visual_point(f, sh[3]) + off
				var rr: float = float(sh[4]) * f.scale
				ci.draw_line(a2, b2, Color(hc.r, hc.g, hc.b, 0.25), rr * 2.0)
				ci.draw_circle(b2, rr, Color(hc.r, hc.g, hc.b, 0.25))
		var pose := strike_pose(f)
		var live: bool = (ATTACKS.has(f.state) or f.state == "special") and pose != ""
		var limb: String = f.attack_limb if live else f.next_limb("arm", true)
		if limb == "":
			continue
		var line := strike_line(f, limb, pose if live else "punch")
		var col := Color(1.0, 0.9, 0.2) if live else Color(1.0, 1.0, 1.0, 0.35)
		ci.draw_line(line["a"] + off, line["b"] + off, col, 3.0)
		ci.draw_arc(line["b"] + off, line["r"], 0.0, TAU, 20, col, 2.0)


## The arena lives on its own layer behind the fighters and is redrawn ~24 times a second
## (the crowd doesn't need 60), which saves a good chunk of work every frame.
class ArenaLayer extends Node2D:
	var fight: Node2D

	func _draw() -> void:
		if fight:
			fight.draw_arena(self)


var arena_layer: ArenaLayer
var arena_redraw_t := 0.0
const ARENA_FPS := 24.0


func draw_arena(ci: CanvasItem) -> void:
	var off := Vector2.ZERO
	var lit := Arena.noir()
	ci.draw_rect(Rect2(Vector2(-40, -40), screen + Vector2(80, 80)), Color(0.07, 0.07, 0.11))
	Arena.draw_backdrop(ci, arena_id, screen, floor_y, clock, off)
	Arena.draw_dim(ci, arena_id, screen, floor_y, clock)
	Arena.draw_crowd(ci, crowd, crowd_id, screen, clock, cheer, off, fight_light())
	var top := screen.y * 0.24
	var ar: Dictionary = Arena.ARENAS[arena_id]
	if lit:
		# the crowd falls back into the dark behind the ring
		var tint: Color = Arena.mood(arena_id)["tint"]
		ci.draw_polygon(PackedVector2Array([Vector2(-40, top + 60.0), Vector2(screen.x + 40, top + 60.0), Vector2(screen.x + 40, floor_y), Vector2(-40, floor_y)]),
				PackedColorArray([Color(tint, 0.0), Color(tint, 0.0), Color(tint, 0.7), Color(tint, 0.7)]))
	else:
		ci.draw_rect(Rect2(0, top + 95.0, screen.x, floor_y - top - 95.0), Color(Color(ar["sky"][0]), 0.6))
	var lc := Color(ar["light"])
	for k in range(14):
		var lp := Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.21)
		if lit:
			ci.draw_circle(lp, 11.0, Color(lc, 0.1))
			ci.draw_circle(lp, 4.0, Color(lc, 0.85))
		else:
			ci.draw_circle(lp, 5.0, Color(lc, 0.45))
	Arena.draw_midground(ci, arena_id, screen, floor_y, clock)
	Arena.draw_floor(ci, arena_id, screen, floor_y, clock, off)
	Arena.draw_floor_light(ci, arena_id, screen, floor_y, clock)
	# ring: corner posts mark the walls, ropes run between them
	if lit:
		RobotArt._set_light(fight_light(), 1.0)
		RobotArt._grade = 3
		RobotArt._flash = false
	var post_top := floor_y - 190.0
	var ring: String = ar.get("ring", "")
	var key: Color = Light.get_set(fight_light())["key"]
	for k in range(3):
		var y := floor_y - 70.0 - k * 50.0
		if ring == "junk":
			# chains strung between stacks of oil drums
			var x := wall_l
			while x < wall_r:
				var cy := y + sin(x * 0.01) * 4.0
				if lit:
					ci.draw_arc(Vector2(x + 6.0, cy), 6.0, 0, TAU, 8, RobotArt.OUTLINE, 4.5)
				ci.draw_arc(Vector2(x + 6.0, cy), 6.0, 0, TAU, 8, Color(ar["rope"]), 2.5)
				if lit:
					ci.draw_arc(Vector2(x + 6.0, cy), 6.0, PI * 1.15, PI * 1.6, 4, Color(key, 0.7), 1.2)
				x += 11.0
		else:
			var rw := 4.0 if ring != "gold" else 6.0
			if lit:
				ci.draw_line(Vector2(wall_l, y), Vector2(wall_r, y), RobotArt.OUTLINE, rw + 2.5)
				ci.draw_line(Vector2(wall_l, y), Vector2(wall_r, y), Color(ar["rope"]).darkened(0.25), rw)
				ci.draw_line(Vector2(wall_l, y - rw * 0.25), Vector2(wall_r, y - rw * 0.25), Color(key, 0.5), 1.3)
			else:
				ci.draw_line(Vector2(wall_l, y), Vector2(wall_r, y), Color(Color(ar["rope"]), 0.75), rw)
	for x in [wall_l, wall_r]:
		if ring == "junk":
			for k in range(3):
				var dy := floor_y - 62.0 - k * 64.0
				var dc: Color = [Color(0.5, 0.2, 0.12), Color(0.2, 0.35, 0.5), Color(0.55, 0.45, 0.15)][k]
				if lit:
					# oil drums: a lit plate with two ribs
					RobotArt._plate(ci, RobotArt._chamfer(Rect2(Vector2(x - 20.0, dy), Vector2(40.0, 60.0)), 4.0), dc)
					for ry in [18.0, 42.0]:
						ci.draw_line(Vector2(x - 19.0, dy + ry), Vector2(x + 19.0, dy + ry), RobotArt.OUTLINE, 2.5)
						ci.draw_line(Vector2(x - 17.0, dy + ry - 2.0), Vector2(x + 17.0, dy + ry - 2.0), Color(key, 0.35), 1.2)
					continue
				ci.draw_rect(Rect2(Vector2(x - 20.0, dy), Vector2(40.0, 60.0)), dc)
				ci.draw_line(Vector2(x - 20.0, dy + 18.0), Vector2(x + 20.0, dy + 18.0), dc.darkened(0.35), 3.0)
				ci.draw_line(Vector2(x - 20.0, dy + 42.0), Vector2(x + 20.0, dy + 42.0), dc.darkened(0.35), 3.0)
			continue
		var pad_c := Color(0.9, 0.9, 0.95) if ring != "gold" else Color(0.95, 0.8, 0.4)
		var cap_c := Color(ar["rope"]) if ring != "gold" else Color(ar["post"]).lightened(0.2)
		if lit:
			RobotArt._plate(ci, RobotArt._chamfer(Rect2(Vector2(x - 9.0, post_top), Vector2(18.0, floor_y - post_top)), 3.0), Color(ar["post"]))
			RobotArt._plate(ci, RobotArt._chamfer(Rect2(Vector2(x - 12.0, post_top - 10.0), Vector2(24.0, 14.0)), 3.0), cap_c)
			for k in range(3):
				RobotArt._plate(ci, RobotArt._chamfer(Rect2(Vector2(x - 11.0, floor_y - 76.0 - k * 50.0), Vector2(22.0, 12.0)), 2.5), pad_c.darkened(0.18))
			continue
		ci.draw_rect(Rect2(Vector2(x - 9.0, post_top), Vector2(18.0, floor_y - post_top)), Color(ar["post"]))
		ci.draw_rect(Rect2(Vector2(x - 12.0, post_top - 10.0), Vector2(24.0, 14.0)), cap_c)
		for k in range(3):
			ci.draw_rect(Rect2(Vector2(x - 11.0, floor_y - 76.0 - k * 50.0), Vector2(22.0, 12.0)), pad_c)
	Arena.draw_beams(ci, arena_id, screen, floor_y, clock)


func draw_cables(off: Vector2) -> void:
	for p in projectiles:
		if p["kind"] == "claw":
			var owner: Fighter = p["owner"]
			var g := RobotArt.geom(owner.get_look())
			var s := to_world_point(owner, g[shoulder_key(p["slot"])])
			ci.draw_line(s + off, p["pos"] + off, Color(0.3, 0.3, 0.32), 3.0)


func draw_projectiles(off: Vector2) -> void:
	for p in projectiles:
		var pos: Vector2 = p["pos"] + off
		var owner: Fighter = p["owner"]
		var dir := Vector2(signf(p["vel"].x), 0.0) if not p["returning"] else -Vector2(owner.facing, 0)
		match p["kind"]:
			"bolt":
				ci.draw_set_transform(pos, p["spin"], Vector2.ONE)
				ci.draw_rect(Rect2(-8, -8, 16, 16), Color(1.0, 0.45, 0.15))
				ci.draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.5))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"fist":
				var arm: Dictionary = owner.parts[p["slot"]]
				RobotArt.draw_rocket_fist(ci, pos, dir, 14.0 * owner.scale, arm["color"], owner.spec["trim"], not p["returning"], clock)
			"claw":
				ci.draw_circle(pos, 8.0, Color(0.3, 0.55, 0.55))
				ci.draw_line(pos, pos + dir * 16.0 + Vector2(0, 9), Color(0.8, 0.8, 0.85), 4.0)
				ci.draw_line(pos, pos + dir * 16.0 - Vector2(0, 9), Color(0.8, 0.8, 0.85), 4.0)
			"laser":
				ci.draw_line(pos - dir * 70.0, pos, Color(1.0, 0.2, 0.3, 0.6), 8.0)
				ci.draw_line(pos - dir * 70.0, pos, Color(1.0, 0.9, 0.9), 3.0)
			"shell":
				ci.draw_circle(pos, 11.0, Color(0.25, 0.25, 0.25))
				ci.draw_circle(pos - dir * 14.0, 7.0, Color(1.0, 0.6, 0.2, 0.7))


## How the robot stands right now: the lean, lunge, squash and stretch of its pose. The drawing and
## the hit test both use it (it also records it in f.vis_*), so hits follow what's on screen.
func body_pose(f: Fighter) -> Dictionary:
	var base := f.pos
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
	# --- exaggerated animation: lean, lunge, recoil, squash & stretch
	var sx := 1.0
	var sy := 1.0
	var lean := 0.0
	var dx := 0.0
	var swoosh := false
	var drop := 0.0      # a sweep sinks the body so the leg can run along the floor (local units)
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
			if state == "sweep":
				drop = float(RobotArt.geom(f.get_look())["L"]) * 0.5 * phase_t
				lean = 0.0
			if f.state == "special" and TELEGRAPH.has(f.special_id):
				dx += sin(clock * 70.0) * 3.0 * f.scale   # the heavy ones shake as they wind up
		elif f.timer <= st + act + a.get("recovery", 0.2) * 0.5:
			swoosh = f.timer <= st + act + 0.05
			match state:
				# (1.51) limbs keep their length: the body carries the reach (hips in, a step, a lunge)
				"kick":
					lean = -f.facing * 0.16
					dx = f.facing * 40.0 * f.scale
				"high_kick":
					lean = -f.facing * 0.26
					dx = f.facing * 34.0 * f.scale
				"fly_kick":
					lean = -f.facing * 0.38   # body tilted back, feet first
					dx = f.facing * 20.0 * f.scale
				"hammer":
					lean = f.facing * 0.2
				"low_punch":
					lean = f.facing * 0.16
					dx = f.facing * 28.0 * f.scale
				"uppercut":
					lean = -f.facing * 0.12
					dx = f.facing * 16.0 * f.scale
					sy = 1.14
					sx = 0.92
				"sweep":
					drop = float(RobotArt.geom(f.get_look())["L"]) * 0.5
					dx = f.facing * 40.0 * f.scale
				"block":
					lean = f.facing * 0.22
					dx = f.facing * 16.0 * f.scale
				_:
					lean = f.facing * 0.22
					dx = f.facing * 30.0 * f.scale
					sx = 1.08
	elif f.state == "prejump":
		# knees bend: the jump is coming
		sy = 0.84
		sx = 1.08
	elif f.state == "down" or f.state == "getup":
		# flat on its back, then pushing itself up
		var up := 0.0 if f.state == "down" else clampf(1.0 - f.timer / 0.3, 0.0, 1.0)
		rot = -f.facing * PI / 2.0 * (1.0 - up)
		base.y -= 18.0 * f.scale * (1.0 - up)
		state = "down" if f.state == "down" else "hit"
	elif f.daze_t > 0.0:
		# guard smashed: wobbling, arms flung wide
		lean = sin(clock * 18.0) * 0.12
		state = "hit"
	elif f.state == "switch":
		# a quick hop while the feet swap over
		base.y -= sin(clampf((0.3 - f.timer) / 0.3, 0.0, 1.0) * PI) * 14.0 * f.scale
		sx = 0.94
	elif f.state == "charge":
		# winding up: leaning back, shaking harder as it fills
		var ck := clampf((f.charge_t - CHARGE_TAP) / (CHARGE_MAX - CHARGE_TAP), 0.0, 1.0)
		lean = -f.facing * (0.08 + 0.1 * ck)
		dx = -f.facing * 8.0 * f.scale + sin(clock * 60.0) * 2.5 * ck * f.scale
		sy = 1.0 - 0.04 * ck
	elif f.burn_t > 0.0 and f.state != "ko":
		# burned out: slumped forward, head down
		lean = f.facing * 0.32
		sy = 0.9
		state = "hit"
	elif f.state == "hit":
		var k := clampf(f.timer / 0.45, 0.0, 1.0)
		lean = -f.facing * 0.38 * k
		dx = -f.facing * 12.0 * k * f.scale
		sx = 1.0 - 0.08 * k
	elif f.state == "walk" and f.legs() == 1:
		# one leg: hop, hop, hop. Up in an arc, squash on landing
		var hp := absf(sin(f.walk_phase))
		base.y -= hp * 16.0 * f.scale
		lean = signf(f.vel.x) * 0.14
		sy = 1.0 - 0.1 * pow(1.0 - hp, 6.0)
		sx = 1.0 + 0.06 * pow(1.0 - hp, 6.0)
	elif f.state == "walk" and f.legs() == 0 and f.arms() > 0:
		# no legs: claw the floor and drag the torso along, lurching with every pull
		var pull := sin(f.walk_phase * (1.0 if f.arms() == 1 else 2.0))
		lean = signf(f.vel.x) * (0.1 + 0.04 * pull) * (1.0 if f.facing == signf(f.vel.x) else 0.5)
		if f.arms() == 1:
			lean += 0.06 * pull * f.facing   # one arm: it lurches to that side with every pull
		dx = pull * 3.0 * f.scale * signf(f.vel.x)
	elif f.state == "walk":
		lean = signf(f.vel.x) * 0.08
		base.y -= absf(sin(f.walk_phase)) * 4.0 * f.scale
	elif f.blocking:
		lean = -f.facing * 0.07
	elif f.on_ground and f.state != "ko":
		pass   # robots don't breathe: the idle is in the guard and the head (idle_bits)
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
	base.y += drop * f.scale * sy
	if f.legs() == 0 and f.arms() == 0 and absf(f.roll_a) > 0.001 and f.state != "ko":
		# rolling round the middle of the torso, not the feet
		var gr := RobotArt.geom(f.get_look())
		var sv := Vector2(f.facing * f.scale * sx, f.scale * sy)
		var cl := Vector2(0, -(float(gr["L"]) + float(gr["th"]) * 0.5)) * sv
		rot = f.roll_a
		base += cl - cl.rotated(rot)
		# whatever end is down (the head, a corner of the torso) rides on the floor, never through it
		var low := 0.0
		for rc in [gr["torso"], gr["head"]]:
			var r2: Rect2 = rc
			for pt in [r2.position, r2.position + Vector2(r2.size.x, 0), r2.end, r2.position + Vector2(0, r2.size.y)]:
				low = maxf(low, (Vector2(pt) * sv).rotated(rot).y + (cl - cl.rotated(rot)).y)
		base.y -= low
	if f.state == "ko":
		if f.on_ground:
			rot = -f.facing * PI / 2.0
			base.y -= 18.0 * f.scale
		else:
			rot = -f.facing * (PI / 4.0 + clock * 3.0)
	f.vis_base = base
	f.vis_rot = rot
	f.vis_sx = sx
	f.vis_sy = sy
	f.vis_ok = true
	f.vis_pose = {"state": state, "extended": extended, "attack_limb": f.attack_limb, "aim": f.aim_ang,
			"dazed": f.daze_t > 0.0, "tuck": f.state == "jump" and not f.on_ground and absf(f.vel.y) < 330.0,
			"blocking": f.blocking or (f.state == "special" and state == "block"),
			"crawl": fmod(f.walk_phase / TAU, 1.0) if f.state == "walk" and f.legs() == 0 and f.arms() > 0 else -1.0,
			"fist_out": f.fist_out.keys(), "drop": drop}
	return {"base": base, "rot": rot, "sx": sx, "sy": sy, "state": state, "extended": extended, "swoosh": swoosh, "dx": dx}


func draw_fighter(f: Fighter, off: Vector2) -> void:
	ci.draw_set_transform(Vector2(f.pos.x, floor_y) + off, 0.0, Vector2(1.0, 0.22))
	ci.draw_circle(Vector2.ZERO, 42.0 * f.scale, Color(0, 0, 0, 0.35))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bp := body_pose(f)
	var base: Vector2 = bp["base"] + off
	var rot: float = bp["rot"]
	var sx: float = bp["sx"]
	var sy: float = bp["sy"]
	var state: String = bp["state"]
	var extended: bool = bp["extended"]
	var swoosh: bool = bp["swoosh"]
	var dx: float = bp["dx"]
	if swoosh and extended:
		var g := RobotArt.geom(f.get_look())
		var low := state == "kick" or state == "sweep" or state == "high_kick"
		var pivot: Vector2 = (g["hip_front"] if f.attack_limb != "leg_back" else g["hip_back"]) if low else RobotArt.shoulder_of(g, f.attack_limb if f.attack_limb.begins_with("arm") else "arm_front")
		var c := to_world_point(f, pivot) + Vector2(dx, 0)
		var a0 := 0.0 if f.facing == 1 else PI
		var span: float = {"uppercut": -0.9, "sweep": 0.5, "high_kick": -0.85, "low_punch": 0.4}.get(state, -0.5)
		ci.draw_arc(c, 100.0 * f.scale, a0 + span * f.facing - 0.35, a0 + span * f.facing + 0.35, 14, Color(1, 1, 1, 0.28), 14.0 * f.scale)
	var fist_out: Array = f.fist_out.keys()
	RobotArt.draw(ci, base, f.get_look(), {
		"light": fight_light(),
		"facing": f.facing, "state": state, "extended": extended, "attack_limb": f.attack_limb, "aim": f.aim_ang,
		"swing": sin(f.walk_phase) * 10.0 if (f.state == "walk" or (f.on_ground and absf(f.vel.x) > 20.0 and f.state in ["punch", "low_punch", "uppercut", "charge"])) and f.legs() == 2 else 0.0,
		"drop": f.vis_pose.get("drop", 0.0),
		"crawl": fmod(f.walk_phase / TAU, 1.0) if f.state == "walk" and f.legs() == 0 and f.arms() > 0 else -1.0,
		"crouch": f.crouching, "blocking": f.blocking or (f.state == "special" and state == "block"),
		"flash": f.flash > 0.0, "rot": rot, "time": clock, "fist_out": fist_out,
		"shield": f.shield_t > 0.0, "overcharge": f.over_t > 0.0, "stunned": f.stun_t > 0.0,
		"jet": f.jet_t > 0.0 or (not f.on_ground and f.vel.y < -400.0 and f.has_gadget("double_jump")),
		"boost": f.boost_t > 0.0, "sx": sx, "sy": sy,
		"dazed": f.vis_pose.get("dazed", false), "tuck": f.vis_pose.get("tuck", false),
		"bob_l": idle_bits(f)[0], "bob_r": idle_bits(f)[1], "head_dx": idle_bits(f)[2],
		# a core under a quarter: its eye flickers like a bad bulb
		"eye_off": f.state != "ko" and f.alive("torso") and f.ratio("torso") < 0.25 and fmod(clock * 9.0 + f.team * 3.1, 3.7) < 0.9,
	})
	if f.state == "special" and TELEGRAPH.has(f.special_id) and f.timer < float(Specials.MOVES[f.special_id]["startup"]):
		# a heavy special winding up: an orange glow round the body
		var gc2 := visual_point(f, RobotArt.part_center(f.get_look(), "torso")) + off
		ci.draw_circle(gc2, (70.0 + sin(clock * 30.0) * 6.0) * f.scale, Color(1.0, 0.5, 0.1, 0.22))
	if f.state == "charge" and f.attack_limb != "":
		# the charging fist (foot) glows brighter as the charge fills
		var ck := clampf((f.charge_t - CHARGE_TAP) / (CHARGE_MAX - CHARGE_TAP), 0.0, 1.0)
		var tip := visual_point(f, RobotArt.limb_strike(f.get_look(), f.attack_limb, "charge" if f.attack_limb.begins_with("arm") else "stand")["b"]) + off
		var gc := Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.3, 0.15), ck)
		ci.draw_circle(tip, (14.0 + 18.0 * ck + sin(clock * 30.0) * 3.0) * f.scale, Color(gc.r, gc.g, gc.b, 0.25 + 0.3 * ck))
		ci.draw_arc(tip, (20.0 + 20.0 * ck) * f.scale, 0.0, TAU * ck, 24, gc, 3.0)


## Over a big moment: cinema bars, and the move's name or the K.O., drawn straight onto the screen
## (the camera's zoom is undone for it).
func draw_moment_caption() -> void:
	var bar := screen.y * 0.09 * clampf(moment_t * 4.0, 0.0, 1.0)
	ci.draw_rect(Rect2(0, 0, screen.x, bar), Color(0, 0, 0, 0.9))
	ci.draw_rect(Rect2(0, screen.y - bar, screen.x, bar), Color(0, 0, 0, 0.9))
	if moment_name != "" and moment_t > 0.0:
		var a := clampf(moment_t * 3.0, 0.0, 1.0)
		var col := Color(1.0, 0.2, 0.1, a) if moment_kind == "ko" else Color(1.0, 0.85, 0.2, a)
		var size := fs(84) if moment_kind == "ko" else fs(56)
		ci.draw_string(font, Vector2(4, screen.y * 0.36 + 4), moment_name, HORIZONTAL_ALIGNMENT_CENTER, screen.x, size, Color(0, 0, 0, a * 0.7))
		ci.draw_string(font, Vector2(0, screen.y * 0.36), moment_name, HORIZONTAL_ALIGNMENT_CENTER, screen.x, size, col)
		if moment_kind == "ko":
			ci.draw_string(font, Vector2(0, screen.y * 0.36 + 56), tr(ko_text) if ko_text != "TIME!" else "", HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(26), Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The heavy specials that shake and glow while they wind up, so a slow big hit can be read and answered.
const TELEGRAPH := ["haymaker", "grab_slam", "bulwark_slam", "scrap_fury"]

## Idle life (robots don't breathe): the guard fists bob out of step, the head pans, and now and then
## a shoulder twitches. Each style has its own rhythm. [lead fist offset, rear fist offset, head shift]
const IDLE_STYLE := {"striker": [3.4, 3.2, 1.0, 0.6], "tank": [1.6, 1.6, 0.6, 0.3], "mechanic": [2.4, 2.2, 0.8, 1.6], "specialist": [2.0, 2.0, 2.6, 0.5]}


func idle_bits(f: Fighter) -> Array:
	if not (f.state in ["idle", "walk"]) or f.blocking or not f.on_ground:
		return [Vector2.ZERO, Vector2.ZERO, 0.0]
	var st: Array = IDLE_STYLE.get(f.style, IDLE_STYLE["striker"])
	var ph := float(f.team) * 1.7 + float(f.wingman + 1) * 0.9
	var t := clock * float(st[0]) + ph
	var amp: float = st[1]
	var l := Vector2(0, sin(t) * amp)
	var r := Vector2(0, sin(t * 0.83 + 2.1) * amp)
	# twitches: short jerks of a shoulder, more often for twitchy mechanics
	var tw := fmod(clock * float(st[3]) + ph * 0.37, 1.0)
	if tw < 0.05:
		l += Vector2(3.0, -4.0)
	elif tw > 0.5 and tw < 0.53:
		r += Vector2(-2.0, -3.0)
	return [l, r, sin(clock * 0.6 + ph) * float(st[2])]


## Burned out: a red lightning bolt and BURNOUT right above the robot's head, blinking.
func draw_burnout(f: Fighter, off: Vector2) -> void:
	if f.burn_t <= 0.0 or f.state == "ko":
		return
	var g := RobotArt.geom(f.get_look())
	var top := visual_point(f, Vector2(0, (g["head"] as Rect2).position.y)) + off
	var c := top + Vector2(0, -34.0)
	var on := fmod(clock, 0.4) < 0.28
	var red := Color(1.0, 0.18, 0.12) if on else Color(0.55, 0.1, 0.08)
	var s := 1.3
	# the bolt
	var bolt := PackedVector2Array([c + Vector2(4, -26) * s, c + Vector2(-12, 2) * s, c + Vector2(-1, 2) * s,
			c + Vector2(-6, 24) * s, c + Vector2(12, -6) * s, c + Vector2(1, -6) * s])
	if on:
		ci.draw_circle(c, 30.0 * s, Color(1.0, 0.2, 0.1, 0.18))
	ci.draw_colored_polygon(bolt, red)
	ci.draw_polyline(bolt + PackedVector2Array([bolt[0]]), Color(0.15, 0.02, 0.02), 2.0)
	var fsz := fs(20)
	var tw := font.get_string_size("BURNOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	ci.draw_string(font, Vector2(c.x - tw * 0.5 + 2, c.y - 34.0 * s + 2), tr("BURNOUT"), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0, 0, 0, 0.7))
	ci.draw_string(font, Vector2(c.x - tw * 0.5, c.y - 34.0 * s), tr("BURNOUT"), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, red)


## Team fights: who's who. Your robots show their pad number, the focused enemy gets a red marker.
func draw_tag(f: Fighter, off: Vector2) -> void:
	var mates: Array = team_p if f.team == 0 else team_c
	if f.state == "ko" or not f.vis_ok or mates.size() < 2:
		return
	var top := visual_point(f, Vector2(0, -RobotArt.geom(f.get_look())["L"] - 150.0)) + off
	top.y = minf(top.y, f.pos.y - 200.0 * f.scale) - (mates.find(f) % 2) * 22.0   # stagger so names don't overlap
	if f.team == 0:
		if f.tag != "":
			ci.draw_circle(top, 15.0, Color(0.2, 0.6, 1.0, 0.85))
			ci.draw_string(font, top + Vector2(-20, 7), f.tag, HORIZONTAL_ALIGNMENT_CENTER, 40, fs(16), Color.WHITE)
	elif f == cpu:
		var r := 10.0 + sin(clock * 6.0) * 2.0
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-r, -r), top + Vector2(r, -r), top + Vector2(0, r * 0.4)]), Color(1.0, 0.25, 0.2, 0.9))
	ci.draw_string(font, top + Vector2(-100, -20), f.label, HORIZONTAL_ALIGNMENT_CENTER, 200, fs(12), Color(1, 1, 1, 0.7))


func draw_crosshair(slot: String, f: Fighter, c: Color, off: Vector2, size: float) -> void:
	if slot == "" or (phase != "fight" and phase != "intro") or not f.alive(slot):
		return
	var p := visual_point(f, RobotArt.part_center(f.get_look(), slot)) + off
	var r := (22.0 + sin(clock * 6.0) * 3.0) * size
	ci.draw_arc(p, r, 0.0, TAU, 32, c, 3.0)
	var spin := clock * 2.0 * (1.0 if size >= 1.0 else -1.0)
	for k in 4:
		var a := spin + k * PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		ci.draw_line(p + dir * (r - 8.0), p + dir * (r + 10.0), c, 3.0)
	ci.draw_circle(p, 3.0, c)
	var label: String = tr(PART_LABELS[slot]) if size >= 1.0 else tr("ENEMY AIM: ") + tr(PART_LABELS[slot])
	ci.draw_string(font, p + Vector2(-120, -r - 10.0), label, HORIZONTAL_ALIGNMENT_CENTER, 240, fs(15), c)


## Scanner: a small pulsing marker on the enemy's weakest part (hits there do +15%).
func draw_weak_point(f: Fighter, off: Vector2) -> void:
	if phase != "fight" or f.state == "ko":
		return
	var slot := player.weak if f == player.foe else ""   # only what your head's scan has found
	if slot == "" or slot == player.target or not f.alive(slot):
		return
	var p := visual_point(f, RobotArt.part_center(f.get_look(), slot)) + off
	var r := 9.0 + sin(clock * 5.0) * 2.0
	var c := Color(1.0, 0.9, 0.2, 0.85)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(c.r, c.g, c.b, 0.25))
	ci.draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)]), c, 2.0)
	ci.draw_string(font, p + Vector2(-60, r + 16), tr("WEAK"), HORIZONTAL_ALIGNMENT_CENTER, 120, fs(11), c)


func draw_part_map(f: Fighter, at: Vector2, _mirror: bool, k: float = UI_SCALE) -> void:
	var boxes := {
		"head": Rect2(-7, 0, 14, 12), "head2": Rect2(-19, 2, 10, 10), "torso": Rect2(-10, 14, 20, 22),
		"arm_front": Rect2(-18, 14, 6, 20), "arm_back": Rect2(12, 14, 6, 20),
		"arm_front2": Rect2(-25, 20, 5, 16), "arm_back2": Rect2(20, 20, 5, 16),
		"leg_front": Rect2(-8, 38, 7, 18), "leg_back": Rect2(1, 38, 7, 18),
	}
	for slot in boxes:
		if not f.parts.has(slot) or f.parts[slot].is_empty():
			continue
		var r: Rect2 = boxes[slot]
		# (no mirroring: the map is the robot seen from the front, left parts on the left, like the bay)
		r = Rect2(at + r.position * k, r.size * k)
		# green, amber, red by health (the same marks as DENTED / CRACKED on the walk-in card); ripped = an empty outline
		if f.state == "ko" or not f.alive(slot):
			ci.draw_rect(r, Color(0.12, 0.12, 0.14, 0.8))
			ci.draw_rect(r, Color(0.45, 0.45, 0.5, 0.8), false, 1.0)
		else:
			var h := f.ratio(slot)
			var c := Color(0.3, 0.9, 0.35) if h >= 0.6 else (Color(1.0, 0.72, 0.2) if h >= 0.3 else Color(0.95, 0.25, 0.2))
			ci.draw_rect(r, c)
			if h < 0.999:
				ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * (1.0 - h))), Color(0, 0, 0, 0.35))   # the missing share, darker
		if f.state != "ko" and f == player.foe and f.alive(slot) and slot == player.weak:
			var wc := r.get_center()
			var wr := 5.0 * k * 0.8
			ci.draw_colored_polygon(PackedVector2Array([wc + Vector2(0, -wr), wc + Vector2(wr, 0), wc + Vector2(0, wr), wc + Vector2(-wr, 0)]), Color(1.0, 0.9, 0.2, 0.95))
		var aimed: bool = (f == cpu and player.target == slot) or (f == player and cpu.target == slot)
		if aimed:
			ci.draw_rect(r.grow(2.0), Color(1, 0.2, 0.2) if f == cpu else Color(1, 0.6, 0.1), false, 2.0)


func part_map_step() -> float:
	return 50.0 * UI_SCALE * 0.72 + 6.0


## The head at work, by the health bar: a crosshair that fills while the aim cooldown runs (and blinks
## when you can aim), and a radar that sweeps while the scan hunts for the weak spot (a yellow diamond
## once it's found). The enemy has the same two, so you can see it's about to find your bad arm.
func draw_head_icons(f: Fighter, at: Vector2, right: bool) -> void:
	if f == null or f.state == "ko":
		return
	var r := 10.0 * UI_SCALE
	var step := r * 4.2 * (1.0 if not right else -1.0)
	# crosshair
	var c := at
	var ready := f.aim_cd <= 0.0
	var k := 1.0 - clampf(f.aim_cd / maxf(0.01, f.aim_time), 0.0, 1.0)
	var col := Color(1.0, 0.35, 0.3) if ready else Color(0.75, 0.75, 0.8)
	if ready and f == player:
		col.a = 0.6 + 0.4 * sin(clock * 8.0)
	ci.draw_circle(c, r + 2.0, Color(0, 0, 0, 0.55))
	ci.draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * k, 24, col, 3.0)
	ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), col, 1.5)
	ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), col, 1.5)
	ci.draw_string(font, c + Vector2(-40, r + fs(10) + 2.0), tr("AIM") if ready else "%.1f" % f.aim_cd, HORIZONTAL_ALIGNMENT_CENTER, 80, fs(10), col)
	# radar / weak spot
	var c2 := at + Vector2(step, 0)
	ci.draw_circle(c2, r + 2.0, Color(0, 0, 0, 0.55))
	if f.weak != "":
		var wc := Color(1.0, 0.9, 0.2)
		ci.draw_colored_polygon(PackedVector2Array([c2 + Vector2(0, -r * 0.8), c2 + Vector2(r * 0.8, 0), c2 + Vector2(0, r * 0.8), c2 + Vector2(-r * 0.8, 0)]), wc)
		ci.draw_string(font, c2 + Vector2(-40, r + fs(10) + 2.0), tr("WEAK"), HORIZONTAL_ALIGNMENT_CENTER, 80, fs(10), wc)
	else:
		var sc := Color(0.4, 1.0, 0.55)
		var sk := clampf(f.scan_t / maxf(0.01, f.scan_time), 0.0, 1.0)
		ci.draw_arc(c2, r, 0.0, TAU, 24, Color(sc.r, sc.g, sc.b, 0.35), 1.5)
		ci.draw_arc(c2, r, -PI / 2.0, -PI / 2.0 + TAU * sk, 24, sc, 3.0)
		var a := clock * 5.0
		ci.draw_line(c2, c2 + Vector2(cos(a), sin(a)) * r * 0.9, sc, 2.0)
		ci.draw_string(font, c2 + Vector2(-40, r + fs(10) + 2.0), tr("SCAN"), HORIZONTAL_ALIGNMENT_CENTER, 80, fs(10), sc)


## A body map for every robot on a team (smaller when there are several).
func draw_part_maps(team: Array, y: float, right: bool) -> void:
	if team.size() == 1:
		draw_part_map(team[0], Vector2(screen.x - 56 if right else 56, y), right, UI_SCALE * 1.45)
		return
	var k := UI_SCALE * 0.72
	var step := part_map_step()
	for i in team.size():
		var f: Fighter = team[i]
		var cx: float = 18.0 + 25.0 * k + i * step
		var at := Vector2(screen.x - cx if right else cx, y + 4.0)
		draw_part_map(f, at, right, k)
		var c := Color(1.0, 0.35, 0.3) if (right and f == cpu) else Color(0.75, 0.75, 0.8)
		var t := f.tag if f.tag != "" and f.team == 0 else ("▼" if right and f == cpu else "")
		if f.state == "ko":
			t = "KO"
		if t != "":
			ci.draw_string(font, at + Vector2(-30, 58.0 * k + 14.0), t, HORIZONTAL_ALIGNMENT_CENTER, 60, fs(12), c)


## Core health bars: one big bar, or a thin bar per robot in team fights.
func draw_team_bars(team: Array, x: float, y: float, w: float, bh: float, right: bool) -> void:
	var n := team.size()
	var gap := 3.0
	var h := (bh - gap * (n - 1)) / n
	for k in n:
		var f: Fighter = team[k]
		var by := y + k * (h + gap)
		# core health in blocks: 1 block = 25 HP, like the bars in the garage
		var ph := maxf(4.0, h * 0.28)
		var max_hp: float = f.parts["torso"].get("max_hp", 100.0) if not f.parts["torso"].is_empty() else 100.0
		# the blocks have a fixed size, so the length of the bar IS the robot's toughness:
		# 20 blocks (500 HP) fill the slot; a tougher robot squeezes its blocks in
		var hn := int(ceilf(max_hp / GUI.HP_UNIT))
		var hw := w * minf(1.0, hn / 20.0)
		var hb := Rect2(x + (w - hw if right else 0.0), by, hw, h - ph - 2.0)
		var hp: float = f.parts["torso"].get("hp", 0.0) if not f.parts["torso"].is_empty() and f.state != "ko" else 0.0
		var edge := Color(1.0, 0.35, 0.3) if (right and f == cpu and n > 1) else Color(1, 1, 1, 0.8)
		ci.draw_rect(hb.grow(2.0), Color(0.02, 0.02, 0.03, 0.9))
		GUI.draw_blocks(ci, hb, hn, hp / GUI.HP_UNIT, Color(0.95, 0.85, 0.2) if f.state != "ko" else Color(0.4, 0.4, 0.4), Color(0.3, 0.06, 0.06), right)
		ci.draw_rect(hb.grow(2.0), edge, false, 1.5)
		# power in blocks under it - 1 block = 1 point of power
		var pn := int(ceilf(f.power_max))
		var pw := w * minf(1.0, pn / 60.0)   # same idea: 60 power fills the slot
		var pr := Rect2(x + (w - pw if right else 0.0), by + h - ph, pw, ph)
		var pc := POWER_COLOR
		if f.burn_t > 0.0:
			pc = Color(1.0, 0.3, 0.2) if fmod(clock, 0.3) < 0.15 else Color(0.3, 0.3, 0.35)
		elif f.power < f.power_max * 0.25:
			pc = POWER_COLOR.lerp(Color.WHITE, 0.5 + 0.5 * sin(clock * 14.0))
		GUI.draw_blocks(ci, pr, pn, clampf(f.power, 0.0, f.power_max), pc, Color(0.02, 0.06, 0.1, 0.85), right)
		if n > 1:
			var t := (tr("%s  ") % f.tag if f.tag != "" else "") + f.label + (tr("  · DOWN") if f.state == "ko" else "")
			ci.draw_string(font, Vector2(x + 6, by + h - 1), t, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, w - 12, int(h * 0.95), Color(0.08, 0.08, 0.1))


func draw_hud() -> void:
	var w := screen.x * 0.32
	var y := screen.y * 0.03
	var bh := 28.0
	# soft dark band so the HUD reads on bright arenas
	for k in 6:   # (1.57: a slimmer, lighter band)
		ci.draw_rect(Rect2(0, k * (y + bh + 34) / 6.0, screen.x, (y + bh + 34) / 6.0 + 1), Color(0, 0, 0, 0.3 * (1.0 - k / 6.0)))
	# one body map per robot in the corners; the health bars move over to make room
	var px := 118.0 if team_p.size() == 1 else 30.0 + team_p.size() * part_map_step()
	var cx := screen.x - (118.0 if team_c.size() == 1 else 30.0 + team_c.size() * part_map_step()) - w
	draw_team_bars(team_p, px, y, w, bh, false)
	draw_team_bars(team_c, cx, y, w, bh, true)
	var my_team := player.label
	if team_p.size() > 1:
		my_team = str(GameData.quick["player"]["name"]) if mode == "quick" else tr("TEAM %s") % GameData.robot_name
	ci.draw_string(font, Vector2(px, y + bh + 28), my_team, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(22), Color.WHITE)
	ci.draw_string(font, Vector2(cx, y + bh + 28), cpu.label if team_c.size() == 1 else str(opp["name"]), HORIZONTAL_ALIGNMENT_RIGHT, w, fs(22), Color.WHITE)
	for f in ([player, cpu] if team_p.size() == 1 and team_c.size() == 1 else []):
		if Catalog.STYLES.has(f.style):
			var st: Dictionary = Catalog.STYLES[f.style]
			var sw := font.get_string_size(f.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(22)).x
			if f == player:
				ci.draw_string(font, Vector2(px + sw + 12, y + bh + 26), tr(st["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(14), Color(st["color"]).lightened(0.35))
			else:
				ci.draw_string(font, Vector2(cx, y + bh + 26), tr(st["name"]).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, w - sw - 12, fs(14), Color(st["color"]).lightened(0.35))
	var status: Array = []
	if player.eff < 1.0:
		status.append(tr("OVERLOADED"))
	if player.over_t > 0.0:
		status.append(tr("OVERCHARGE %.0f") % ceilf(player.over_t))
	if player.burn_t > 0.0:
		status.append(tr("BURNOUT"))
	if player.hobble_t > 0.0:
		status.append(tr("LEG HIT: SLOWED"))
	if player.numb_t > 0.0:
		status.append(tr("ARM HIT: WEAKER"))
	if player.slow_t > 0.0:
		status.append(tr("FROZEN"))
	if not player.burns.is_empty():
		status.append(tr("ON FIRE"))
	# the pilots, under the robots' names
	var pl_y := y + bh + 28 + fs(17) + 2
	var has_pilots := false
	if team_p.size() == 1 and player.pilot_name != "":
		ci.draw_string(font, Vector2(px, pl_y), tr("PILOT %s") % player.pilot_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(15), Color(0.75, 0.85, 1.0))
		has_pilots = true
	if team_c.size() == 1 and cpu.pilot_name != "":
		ci.draw_string(font, Vector2(cx, pl_y), tr("PILOT %s") % cpu.pilot_name.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, w, fs(15), Color(0.75, 0.85, 1.0))
		has_pilots = true
	if not status.is_empty():
		ci.draw_string(font, Vector2(px, (pl_y + fs(15) + 4) if has_pilots else (y + bh + 50)), "  ".join(status), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(16), Color(1.0, 0.5, 0.2))
	draw_part_maps(team_p, y, false)
	draw_part_maps(team_c, y, true)
	if phase == "fight" or phase == "intro":
		# under each corner's body map
		var iy := y + 58.0 * UI_SCALE * 1.45 + 22.0
		draw_head_icons(player, Vector2(34.0, iy), false)
		draw_head_icons(cpu, Vector2(screen.x - 34.0, iy), true)
	for f in [player, cpu]:
		if f.combo >= 2 and f.combo_show > 0.0:
			var x := px if f == player else cx
			ci.draw_string(font, Vector2(x, y + bh + 70), tr("%d HIT COMBO!") % f.combo, HORIZONTAL_ALIGNMENT_LEFT if f == player else HORIZONTAL_ALIGNMENT_RIGHT,
					w, fs(30), Color(1.0, 0.85, 0.2, minf(1.0, f.combo_show * 2.0)))

	# the fight name and clock hang on a board between the health bars
	var gap_l := px + w + 12.0
	var gap_r := cx - 12.0
	var bw := minf(gap_r - gap_l, 420.0)
	draw_title_board(Rect2(screen.x * 0.5 - bw * 0.5, 6.0, bw, minf(quit_rect.position.y - 12.0, 70.0)))
	if phase == "intro" or phase == "fight":
		var hud_btns: Array = [[quit_rect, "LEAVE"]] if mode == "watch" else [[quit_rect, "QUIT"], [moves_rect, "MOVES"]]
		if mode == "test":
			hud_btns = [[quit_rect, "LEAVE"], [moves_rect, "MOVES"], [reset_rect, "RESET"], [hitbox_rect, "HITBOX"]]
		for rr in hud_btns:
			ci.draw_rect(rr[0], Color(1, 1, 1, 0.1))
			ci.draw_rect(rr[0], Color(1, 1, 1, 0.4), false, 2.0)
			ci.draw_string(font, (rr[0] as Rect2).position + Vector2(0, 31), tr(rr[1]), HORIZONTAL_ALIGNMENT_CENTER, (rr[0] as Rect2).size.x, fs(19), Color(1, 1, 1, 0.75))

	var cy := screen.y * 0.42
	match phase:
		"intro":
			if intro_step == "count":
				var n := clampi(3 - int(count_t / COUNT_STEP), 1, 3)
				var k := fmod(count_t, COUNT_STEP) / COUNT_STEP
				ci.draw_string(font, Vector2(0, screen.y * 0.36), str(n), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(110 - 30 * k), Color(1.0, 0.85, 0.2, 1.0 - k * 0.6))
				ci.draw_string(font, Vector2(0, w2s(Vector2(0, floor_y + 44)).y), tr("You can move, but no hitting before the bell!"), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(18), Color(0.9, 0.9, 0.95, 0.85))
		"fight":
			if fight_flash > 0.0:
				ci.draw_string(font, Vector2(0, screen.y * 0.36), tr("FIGHT!"), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(96), Color(1.0, 0.3, 0.2, minf(1.0, fight_flash * 2.0)))
		"ko":
			var big := tr("K.O.") if ko_text != "TIME!" else tr("TIME!")
			ci.draw_string(font, Vector2(0, cy), big, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(84), Color(1.0, 0.2, 0.1))
			var sub := tr(ko_text) if ko_text != "TIME!" else tr("Judges' decision")
			ci.draw_string(font, Vector2(0, cy + 55), sub, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(26), Color.WHITE)
			var winner_name: String = (team_p[0].label if team_p.size() == 1 or mode == "watch" else tr("YOUR TEAM")) if won else str(opp["name"])
			ci.draw_string(font, Vector2(0, cy + 100), tr("%s WINS") % winner_name, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(32), Color(1.0, 0.85, 0.2))
			if phase_timer > 2.0:
				ci.draw_string(font, Vector2(0, cy + 145), tr("Tap to continue"), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(22), Color(0.8, 0.8, 0.8))
		"results":
			draw_results()


## Test Drive: what you just pressed (fades out), so you can see why a combo did or didn't come out.
func draw_input_readout() -> void:
	var toks: Array = []
	for b in player.buffer:
		if clock - float(b["t"]) < 2.5:
			toks.append(b["tok"])
	var y := screen.y * 0.04 + 112.0
	var box := Rect2(screen.x * 0.5 - 220, y, 440, 40)
	ci.draw_rect(box, Color(0, 0, 0, 0.55))
	ci.draw_string(font, box.position + Vector2(12, 27), tr("INPUT"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(14), Color(0.6, 0.6, 0.65))
	ci.draw_string(font, box.position + Vector2(80, 28), Specials.seq_text(toks) if not toks.is_empty() else "-", HORIZONTAL_ALIGNMENT_LEFT, 350, fs(22), Color(0.55, 1.0, 0.65))


func draw_results() -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.7))
	var res_w := results_width()
	var y := screen.y * 0.2
	var title := tr("VICTORY!") if won else tr("DEFEAT")
	if mode == "watch":
		title = tr("%s WINS") % str(result.get("winner", "?"))
	ci.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, res_w, fs(72 if mode != "watch" else 54), Color(1.0, 0.85, 0.2) if won or mode == "watch" else Color(0.9, 0.3, 0.3))
	y += 60.0
	var lines: Array = []
	if mode == "watch":
		lines.append([tr("That's the result on the books. Bets on it pay when the round is over."), Color(0.8, 0.8, 0.85)])
		for bl in result.get("live", {}).get("lines", []):
			lines.append([str(bl), Color(0.6, 1.0, 0.6) if str(bl).contains("+$") else Color(1.0, 0.55, 0.5)])
		if result.get("posted", "") == "" and post_card == null:
			lines.append([tr("A post about it is waiting on BotMedia."), Color(0.6, 0.85, 1.0)])
	elif mode == "quick":
		lines.append([tr("Quick fight, nothing saved."), Color(0.8, 0.8, 0.85)])
	elif mode == "test":
		lines.append([tr("Test drive. No damage, no prize, nothing saved."), Color(0.8, 0.8, 0.85)])
	else:
		var pay: int = result.get("reward", 0)
		if pay > 0:
			lines.append([tr("Prize money: +$%d") % pay, Color(0.95, 0.85, 0.2)])
		elif pay < 0:
			lines.append([tr("Paid the winner: -$%d") % -pay, Color(1.0, 0.45, 0.4)])
		else:
			lines.append([tr("No purse for the loser"), Color(0.75, 0.75, 0.8)])
		var bt: Dictionary = result.get("bets", {})
		for bl in bt.get("lines", []):
			lines.append([bl, Color(0.5, 1.0, 0.6) if str(bl).contains("+$") else Color(1.0, 0.45, 0.4)])
	if result.get("posted", "") != "":
		lines.append([str(result["posted"]), Color(0.6, 0.85, 1.0)])
	if result.get("bonus", 0) > 0:
		lines.append([tr("Dismantle bonus: +$%d") % result["bonus"], Color(0.95, 0.85, 0.2)])
	if result.get("champion", false):
		lines.append([tr("YOU ARE THE CHAMPION!"), Color(1.0, 0.5, 0.2)])
	if result.get("cup_done", "") != "":
		lines.append([tr("CUP OVER: %s") % result["cup_done"], Color(1.0, 0.5, 0.2)])
	if result.get("event_done", "") != "":
		lines.append([tr("SEASON OVER: %s") % result["event_done"], Color(1.0, 0.5, 0.2)])
	for l in lines:
		ci.draw_string(font, Vector2(0, y), l[0], HORIZONTAL_ALIGNMENT_CENTER, res_w, fs(24), l[1])
		y += 38.0
	y = draw_result_cards(y)
	if mode not in ["quick", "test", "watch"]:
		ci.draw_string(font, Vector2(0, y + 6), tr("The night goes by. Tomorrow morning, back in the bay."), HORIZONTAL_ALIGNMENT_CENTER, res_w, fs(18), Color(0.6, 0.85, 1.0))
	if phase_timer > 1.0:
		# one clear way out (a tap anywhere does the same)
		var label: String = {"quick": tr("BACK TO THE MENU"), "test": tr("BACK TO THE SCRAPYARD")}.get(mode, tr("BACK TO THE BAY"))
		var bw := minf(360.0, res_w * 0.6)
		var br := Rect2(res_w * 0.5 - bw * 0.5, screen.y - 78.0, bw, 56.0)
		ci.draw_rect(br, Color(0.95, 0.76, 0.19))
		ci.draw_rect(br, Color(0.08, 0.08, 0.08), false, 3.0)
		ci.draw_string(font, Vector2(br.position.x, br.position.y + br.size.y * 0.5 + fs(20) * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, fs(20), Color(0.08, 0.08, 0.08))


## Parts won and lost, as picture cards: green for parts you got, orange wrecked, red lost.
func draw_result_cards(y: float) -> float:
	var cards: Array = result.get("cards", [])
	if cards.is_empty():
		return y
	var tags := {"salvaged": ["SALVAGED", Color(0.5, 1.0, 0.6)], "trophy": ["TROPHY PART", Color(0.5, 1.0, 0.6)],
			"wrecked": ["WRECKED", Color(1.0, 0.7, 0.3)], "lost": ["LOST", Color(1.0, 0.45, 0.4)], "shattered": ["SHATTERED", Color(0.75, 0.75, 0.8)]}
	var n := mini(cards.size(), 6)
	var res_w := results_width()
	var cw := minf(150.0, (res_w - 40.0) / n)
	var icon := minf(cw - 30.0, 84.0)
	var x0 := res_w * 0.5 - n * cw * 0.5
	y += 4.0
	for k in n:
		var c: Dictionary = cards[k]
		var d := GameData.part_def(str(c["id"]))
		if d.is_empty():
			continue
		var tag: Array = tags.get(c["what"], ["", Color.WHITE])
		var cx := x0 + k * cw + cw * 0.5
		var box := Rect2(cx - icon * 0.5, y, icon, icon)
		# cards appear one after another
		if phase_timer < 0.3 + k * 0.25:
			continue
		PartIcon.draw_part(ci, box, d, float(c.get("health", 1.0)))
		ci.draw_rect(box, tag[1], false, 3.0)
		if c["what"] == "lost" or c["what"] == "shattered":
			ci.draw_line(box.position + Vector2(6, 6), box.end - Vector2(6, 6), Color(1.0, 0.3, 0.25, 0.85), 4.0)
			ci.draw_line(Vector2(box.end.x - 6, box.position.y + 6), Vector2(box.position.x + 6, box.end.y - 6), Color(1.0, 0.3, 0.25, 0.85), 4.0)
		ci.draw_string(font, Vector2(cx - cw * 0.5, box.end.y + 18), tr(tag[0]), HORIZONTAL_ALIGNMENT_CENTER, cw, fs(13), tag[1])
		ci.draw_string(font, Vector2(cx - cw * 0.5, box.end.y + 36), str(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, cw, fs(14), Color(0.92, 0.92, 0.95))
	if cards.size() > n:
		ci.draw_string(font, Vector2(0, y + icon + 56), tr("+%d more in Storage") % (cards.size() - n), HORIZONTAL_ALIGNMENT_CENTER, res_w, fs(14), Color(0.8, 0.8, 0.85))
	return y + icon + 50.0


func draw_buttons() -> void:
	for b in (buttons if touch_device else []):
		var held: bool = held_buttons.get(b["name"], false)
		ci.draw_circle(b["pos"], b["r"], Color(1, 1, 1, 0.3 if held else 0.07))   # see-through, so the fight shows behind
		ci.draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1, 1, 1, 0.38), 1.5)
		var size := fs(17) if str(b["label"]).length() <= 5 else fs(14)
		var btxt := tr(b["label"])
		while size > 9 and font.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > b["r"] * 1.9:
			size -= 1
		ci.draw_string(font, b["pos"] + Vector2(-b["r"], size * 0.35), btxt, HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, size, Color(1, 1, 1, 0.85))
		if player.state == "charge" and player.charge_btn == b["name"]:
			# the charge fills round the button
			var ck := clampf((player.charge_t - CHARGE_TAP) / (CHARGE_MAX - CHARGE_TAP), 0.0, 1.0)
			ci.draw_arc(b["pos"], b["r"] + 6.0, -PI / 2.0, -PI / 2.0 + TAU * ck, 40, Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.2), ck), 6.0)
	for b in gadget_buttons:
		var g: Dictionary = b["gadget"]
		var id: String = g["id"]
		var owner: Fighter = b["owner"]
		var cd: float = owner.cooldowns.get(id, 0.0)
		var ready := cd <= 0.0 and owner.gadget_working(g) and not (id == "overcharge" and owner.overcharged) \
				and not (owner.fist_out.has(g["slot"])) and owner.state != "ko"
		var col := Color(0.4, 0.8, 1.0) if ready else Color(0.5, 0.5, 0.55)
		ci.draw_circle(b["pos"], b["r"], Color(col.r, col.g, col.b, 0.3 if held_buttons.get(b["name"], false) else 0.15))
		ci.draw_arc(b["pos"], b["r"], 0.0, TAU, 40, col, 3.0)
		if cd > 0.0 and id != "overcharge":
			var frac := cd / float(Specials.GADGETS[id]["cd"])
			ci.draw_arc(b["pos"], b["r"] - 5.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(1, 1, 1, 0.5), 6.0)
		var glabel: String = tr(b["label"]) if touch_device else "%d  %s" % [gadget_buttons.find(b) + 1, tr(b["label"])]
		ci.draw_string(font, b["pos"] + Vector2(-b["r"] - 10, 7.0), glabel, HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0 + 20, fs(15), col)


## On a computer the touch buttons are hidden: one line of keys along the bottom instead.
func draw_key_strip() -> void:
	var t := tr("A D move · W / S high / low · Space jump · J punch · K kick · L block · hold J / K to charge · 1 2 3 gadgets · Esc pause")
	var size := fs(15)
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 28.0
	var r := Rect2(screen.x * 0.5 - w * 0.5, screen.y - size - 22.0, w, size + 14.0)
	ci.draw_rect(r, Color(0, 0, 0, 0.55))
	ci.draw_string(font, Vector2(r.position.x, r.end.y - 9.0), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(1, 1, 1, 0.8))


const PC_KEYS := "ON A COMPUTER: A D (or the arrows) move · W / S (up / down) aim your hit high or low, S alone crouches · Space jump · J punch · K kick · L block · hold J or K to charge · 1 2 3 gadgets · click an enemy part to aim · Esc or M pause · Enter to continue."


func draw_moves_list() -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.02, 0.03, 0.94))
	var x := screen.x * 0.08
	var y := screen.y * 0.1
	if quit_ask:
		ci.draw_string(font, Vector2(0, y), tr("QUIT THIS FIGHT?"), HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(30), Color(1.0, 0.45, 0.2))
		y += 50.0
	else:
		y = draw_pause_tabs(screen.y * 0.04) + 14.0
	# the two buttons along the bottom: resume, and quit (asks first: quitting pays nothing)
	var bw := minf(300.0, screen.x * 0.3)
	var bh := 56.0
	resume_rect_p = Rect2(screen.x * 0.5 - bw - 12.0, screen.y - bh - 18.0, bw, bh)
	quit_rect_p = Rect2(screen.x * 0.5 + 12.0, screen.y - bh - 18.0, bw, bh)
	if quit_ask:
		var q := tr("Nothing is lost in a quick fight.") if mode == "quick" else tr("You throw in the towel: it counts as a loss, there's no pay, and the damage comes home with you.")
		ci.draw_multiline_string(font, Vector2(screen.x * 0.15, y + 20.0), q, HORIZONTAL_ALIGNMENT_CENTER, screen.x * 0.7, fs(20), -1, Color(0.9, 0.9, 0.95))
	else:
		match pause_tab:
			"how":
				draw_how_cards(Rect2(x, y, screen.x - x * 2.0, resume_rect_p.position.y - 12.0 - y))
			"robots":
				draw_pause_robots(y, resume_rect_p.position.y - 10.0)
			"tips":
				draw_pause_tips(x, y, resume_rect_p.position.y - 10.0)
			_:
				_draw_pause_lines(x, y + fs(16), resume_rect_p.position.y - 10.0)
	for bt in [[resume_rect_p, tr("KEEP FIGHTING") if quit_ask else tr("RESUME"), Color(0.3, 0.3, 0.38)],
			[quit_rect_p, tr("YES, QUIT") if quit_ask else tr("QUIT FIGHT"), Color(0.55, 0.2, 0.15) if quit_ask else Color(0.3, 0.3, 0.38)]]:
		var rr: Rect2 = bt[0]
		ci.draw_rect(rr, bt[2])
		ci.draw_rect(rr, Color(1, 1, 1, 0.4), false, 2.0)
		ci.draw_string(font, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + fs(18) * 0.35), bt[1], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, fs(18), Color.WHITE)
	if not touch_device:
		var hint := tr("Esc / Space: resume      Tab: next page      Q: quit") if not quit_ask else tr("Esc: keep fighting      Q: quit")
		ci.draw_string(font, Vector2(0, screen.y - 4.0), hint, HORIZONTAL_ALIGNMENT_CENTER, screen.x, fs(13), Color(0.75, 0.75, 0.8))



# ---------------------------------------------------------------- the pause screen's pages
const PAUSE_TABS := ["moves", "how", "robots", "tips"]
var pause_tab := "moves"
var pause_tab_rects := {}


## The page tabs across the top. Returns the y under them.
func draw_pause_tabs(y: float) -> float:
	var names := {"moves": tr("MOVES"), "how": tr("HOW FIGHTING WORKS"), "robots": tr("THE ROBOTS"), "tips": tr("GUS'S TIPS")}
	var size := fs(17)
	var pad := 22.0
	var total := 0.0
	for k in PAUSE_TABS:
		total += font.get_string_size(names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + pad * 2.0 + 8.0
	while total > screen.x - 40.0 and size > 10:
		size -= 1
		total = 0.0
		for k in PAUSE_TABS:
			total += font.get_string_size(names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + pad * 2.0 + 8.0
	var x := (screen.x - total) * 0.5
	var h := size + 26.0
	pause_tab_rects = {}
	for k in PAUSE_TABS:
		var w: float = font.get_string_size(names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + pad * 2.0
		var r := Rect2(x, y, w, h)
		pause_tab_rects[k] = r
		var on: bool = k == pause_tab
		ci.draw_rect(r, Color(0.2, 0.2, 0.26) if on else Color(0.1, 0.1, 0.13))
		if on:
			ci.draw_rect(Rect2(r.position.x, r.end.y - 4.0, r.size.x, 4.0), GUI.YELLOW)
		ci.draw_string(font, Vector2(r.position.x, r.position.y + h * 0.5 + size * 0.35), names[k], HORIZONTAL_ALIGNMENT_CENTER, w, size, Color.WHITE if on else Color(0.65, 0.65, 0.7))
		x += w + 8.0
	return y + h


## HOW FIGHTING WORKS: one card per idea, each with a little picture.
func how_cards() -> Array:
	var block_word := tr("BLOCK") if touch_device else "L"
	return [
		["highlow", tr("HIGH OR LOW"), tr("Hold ▲ or ▼ as you hit. Low hits get under a standing guard. Crouch under high ones.") if touch_device else tr("Hold W or S as you hit. Low hits get under a standing guard. Crouch under high ones.")],
		["charge", tr("CHARGE"), tr("Hold PUNCH or KICK, let go to hit up to twice as hard. A full charge breaks a guard.")],
		["counters", tr("WHAT BEATS WHAT"), tr("Block beats punch. Kick beats punch. A full charge beats block.")],
		["aim", tr("AIM"), tr("Tap a part to aim at it. Your head decides how soon you can aim again.") if touch_device else tr("Click a part to aim at it. Your head decides how soon you can aim again.")],
		["weak", tr("WEAK SPOT"), tr("Your head scans for their weakest part. Hits on the yellow diamond do extra damage.")],
		["stance", tr("STANCE"), tr("Double-tap %s to switch your leading side. It knocks their aim off.") % block_word],
		["power", tr("POWER"), tr("Every move costs power, kicks the most. Run dry and you burn out: no blocking.")],
		["air", tr("IN THE AIR"), tr("KICK dives in feet first. PUNCH hammers down: block that one standing.")],
		["rips", tr("RIPS"), tr("Parts torn off whole are yours after a win. Shattered ones are gone.")],
	]


func draw_how_cards(area: Rect2) -> void:
	var cards := how_cards()
	var cols := 3
	var rows := int(ceil(cards.size() / float(cols)))
	var gap := 10.0
	var cw := (area.size.x - gap * (cols - 1)) / cols
	var ch := (area.size.y - gap * (rows - 1)) / rows
	var t := Time.get_ticks_msec() / 1000.0
	for k in cards.size():
		var r := Rect2(area.position + Vector2((k % cols) * (cw + gap), (k / cols) * (ch + gap)), Vector2(cw, ch))
		ci.draw_rect(r, Color(0.09, 0.09, 0.12))
		ci.draw_rect(r, Color(0.25, 0.25, 0.3), false, 2.0)
		var icon := minf(ch - 16.0, 64.0)
		draw_how_icon(cards[k][0], Rect2(r.position + Vector2(8, (ch - icon) * 0.5), Vector2(icon, icon)), t)
		var tx := r.position.x + icon + 18.0
		var tw := r.end.x - tx - 8.0
		var ts := fs(15)
		var bs := fs(13)
		# shrink the words until they fit the card
		while bs > 9 and font.get_multiline_string_size(cards[k][2], HORIZONTAL_ALIGNMENT_LEFT, tw, bs).y + ts + 14.0 > ch:
			bs -= 1
			ts = maxi(bs + 2, ts - 1)
		ci.draw_string(font, Vector2(tx, r.position.y + ts + 6.0), cards[k][1], HORIZONTAL_ALIGNMENT_LEFT, tw, ts, GUI.YELLOW)
		ci.draw_multiline_string(font, Vector2(tx, r.position.y + ts + bs + 12.0), cards[k][2], HORIZONTAL_ALIGNMENT_LEFT, tw, bs, -1, Color(0.85, 0.85, 0.9))


## The little pictures on the HOW FIGHTING WORKS cards (drawn, so they follow the game's look).
func draw_how_icon(kind: String, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var u := r.size.x / 64.0
	var y := GUI.YELLOW
	var w := Color(0.9, 0.9, 0.95)
	var bl := Color(0.45, 0.75, 1.0)
	ci.draw_rect(r, Color(0.05, 0.05, 0.07))
	match kind:
		"highlow":
			ci.draw_line(c + Vector2(-14, 18) * u, c + Vector2(-14, -18) * u, w, 4.0 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -12) * u, c + Vector2(-4, -12) * u, c + Vector2(-14, -26) * u]), w)
			ci.draw_line(c + Vector2(14, -18) * u, c + Vector2(14, 18) * u, y, 4.0 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, 12) * u, c + Vector2(24, 12) * u, c + Vector2(14, 26) * u]), y)
		"charge":
			var k := fmod(t * 0.8, 1.0)
			ci.draw_arc(c, 24.0 * u, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.2), k), 5.0 * u)
			ci.draw_rect(Rect2(c - Vector2(10, 9) * u, Vector2(20, 18) * u), w)
			for i in 3:
				ci.draw_line(c + Vector2(-10 + i * 7, -9) * u, c + Vector2(-10 + i * 7, -3) * u, Color(0.3, 0.3, 0.35), 1.5 * u)
		"counters":
			var pts := [c + Vector2(0, -22) * u, c + Vector2(20, 14) * u, c + Vector2(-20, 14) * u]
			for i in 3:
				ci.draw_line(pts[i], pts[(i + 1) % 3], Color(0.5, 0.5, 0.55), 2.0 * u)
			for i in 3:
				ci.draw_circle(pts[i], 8.0 * u, [bl, y, Color(1.0, 0.5, 0.3)][i])
			ci.draw_string(font, pts[0] + Vector2(-4, 5) * u, "B", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color.BLACK)
			ci.draw_string(font, pts[1] + Vector2(-4, 5) * u, "P", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color.BLACK)
			ci.draw_string(font, pts[2] + Vector2(-4, 5) * u, "K", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color.BLACK)
		"aim":
			ci.draw_arc(c, 20.0 * u, 0.0, TAU, 32, Color(1.0, 0.4, 0.3), 3.0 * u)
			ci.draw_arc(c, 20.0 * u, -PI / 2.0, -PI / 2.0 + TAU * fmod(t * 0.5, 1.0), 32, Color(1.0, 0.75, 0.3), 3.0 * u)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + d * 12.0 * u, c + d * 27.0 * u, Color(1.0, 0.4, 0.3), 2.5 * u)
		"weak":
			var a := t * 3.0
			ci.draw_arc(c, 24.0 * u, 0.0, TAU, 32, Color(0.3, 1.0, 0.5, 0.5), 2.0 * u)
			ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 24.0 * u, Color(0.3, 1.0, 0.5), 2.0 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10) * u, c + Vector2(10, 0) * u, c + Vector2(0, 10) * u, c + Vector2(-10, 0) * u]), y)
		"stance":
			ci.draw_line(c + Vector2(-20, -8) * u, c + Vector2(18, -8) * u, w, 3.5 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(14, -15) * u, c + Vector2(24, -8) * u, c + Vector2(14, -1) * u]), w)
			ci.draw_line(c + Vector2(20, 8) * u, c + Vector2(-18, 8) * u, y, 3.5 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 1) * u, c + Vector2(-24, 8) * u, c + Vector2(-14, 15) * u]), y)
		"power":
			var lvl := 0.5 + 0.5 * sin(t * 1.5)
			ci.draw_rect(Rect2(c + Vector2(-12, -20) * u, Vector2(24, 40) * u), Color(0.5, 0.5, 0.55), false, 3.0 * u)
			ci.draw_rect(Rect2(c + Vector2(-5, -25) * u, Vector2(10, 5) * u), Color(0.5, 0.5, 0.55))
			ci.draw_rect(Rect2(c + Vector2(-9, 17 - 34 * lvl) * u, Vector2(18, 34 * lvl) * u), POWER_COLOR if lvl > 0.2 else Color(1.0, 0.35, 0.3))
		"air":
			var pts2 := PackedVector2Array()
			for i in 13:
				var f := i / 12.0
				pts2.append(c + Vector2(-22 + 44 * f, 14 - 60 * f * (1.0 - f) * 1.4) * u)
			ci.draw_polyline(pts2, Color(0.6, 0.6, 0.65), 2.0 * u)
			ci.draw_line(c + Vector2(10, -6) * u, c + Vector2(20, 18) * u, y, 5.0 * u)
			ci.draw_line(c + Vector2(-26, 20) * u, c + Vector2(26, 20) * u, Color(0.4, 0.4, 0.45), 2.0 * u)
		"rips":
			ci.draw_line(c + Vector2(-20, -14) * u, c + Vector2(-2, 0) * u, Color(0.6, 0.62, 0.68), 7.0 * u)
			ci.draw_line(c + Vector2(6, 4) * u, c + Vector2(22, 18) * u, Color(0.6, 0.62, 0.68), 7.0 * u)
			ci.draw_circle(c + Vector2(22, 18) * u, 5.0 * u, Color(0.5, 0.5, 0.55))
			for d in [Vector2(2, -8), Vector2(-6, 9), Vector2(9, -2)]:
				ci.draw_line(c + Vector2(2, 2) * u, c + Vector2(2, 2) * u + d * u, Color(1.0, 0.6, 0.2), 2.0 * u)


## THE ROBOTS: both robots' parts and how much of each is left, side by side.
func draw_pause_robots(y: float, bottom: float) -> void:
	var keep := card_t
	card_t = 9.0
	draw_robot_card(self, player, true, screen.x, bottom, font, y)
	draw_robot_card(self, cpu, false, screen.x, bottom, font, y)
	card_t = keep


## GUS'S TIPS: everything he's told you in fights, newest first.
func draw_pause_tips(x: float, y: float, bottom: float) -> void:
	var tips: Array = GameData.tips_log.duplicate()
	tips.reverse()
	var width := screen.x - x * 2.0
	if tips.is_empty():
		ci.draw_string(font, Vector2(x, y + fs(18)), tr("No tips yet. Gus speaks up the first time something matters."), HORIZONTAL_ALIGNMENT_LEFT, width, fs(18), Color(0.7, 0.7, 0.75))
		return
	var size := fs(16)
	for t in tips:
		var text := str(t.get("text", ""))
		var hgt := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 30.0, size).y
		if y + hgt > bottom:
			break
		ci.draw_rect(Rect2(x, y + 4.0, 6.0, hgt - 6.0), Color(0.95, 0.6, 0.25))
		ci.draw_multiline_string(font, Vector2(x + 18.0, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, width - 30.0, size, -1, Color(0.92, 0.9, 0.85))
		y += hgt + 10.0


func _draw_pause_lines(x: float, y: float, bottom: float) -> void:
	var lines: Array = [
		[tr(PC_KEYS) if not touch_device else "", Color(0.55, 1.0, 0.7)],
		[tr("PUNCH · KICK · BLOCK · JUMP. The pad sets the height: up + PUNCH = uppercut, down + PUNCH = low jab, up + KICK = high kick, down + KICK = sweep. In combos, → means toward the enemy (P = punch, K = kick)."), Color(0.8, 0.8, 0.85)],
		[tr("Your arms take turns: jab, cross, jab. Kicks swap legs the same way. Lose a limb and the other one does all the work."), Color(0.8, 0.8, 0.85)],
		[tr("Combos: hit again while the enemy is still reeling. Landed attacks can chain into the next."), Color(0.8, 0.8, 0.85)],
		[tr("POWER (blue bar): punch %.1f  kick %.1f  special %.1f of %.0f. Charging drains it too. Refills when you stop attacking. Empty = BURNOUT.") % [attack_cost(player, "punch", "arm_front"), attack_cost(player, "kick", "leg_front"), special_cost(player), player.power_max], POWER_COLOR],
	]
	if team_p.size() > 1:
		lines.append([tr("TEAM: tap an enemy part to send your whole team after that robot. ") + (tr("Each numbered pad moves the robot with that number; PUNCH / KICK / BLOCK / JUMP work for all of them.") if control_pads > 1 else tr("Linked controls: every robot follows the one pad.")) + tr(" Switch in Settings > Team controls."), Color(0.5, 0.8, 1.0)])
	if player.specials.is_empty():
		lines.append([tr("No special moves installed. Buy training chips in the garage!"), Color(1.0, 0.7, 0.3)])
	for id in player.specials:
		var m: Dictionary = Specials.MOVES[id]
		var cd: float = player.cooldowns.get(id, 0.0)
		lines.append([tr("%s   %s%s   · %s") % [Specials.seq_text(m["seq"]), tr(m["name"]), tr("  (%.0fs)") % ceilf(cd) if cd > 0.0 else "", tr(m["desc"])], Color(0.5, 0.9, 1.0)])
	for g in player.gadgets:
		var info: Dictionary = Specials.GADGETS[g["id"]]
		lines.append([tr("%s%s: %s") % ["[" + info["short"] + "]  " if info["active"] else "", info["name"], tr(info["desc"])], Color(1.0, 0.85, 0.4)])
	lines = lines.filter(func(l): return str(l[0]) != "")
	var width := screen.x * 0.84
	# shrink the text until the whole list fits above the buttons
	var size := fs(16)
	while size > 9:
		var hgt := 0.0
		for l in lines:
			hgt += font.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, width, size).y + 5.0
		if y + hgt <= bottom:
			break
		size -= 1
	for l in lines:
		ci.draw_multiline_string(font, Vector2(x, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, l[1])
		y += font.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, width, size).y + 5.0


# ---------------------------------------------------------------- pilots in the corners

const PILOT_LINES := {
	"start": ["GO, %s!", "Let's work, %s!", "Show 'em, %s!", "Here we go!"],
	"hit": ["PUNCH IT!", "Smash it!", "Again! Again!", "Right there!", "Go in, %s!", "That's it!"],
	"combo": ["COMBO!", "Don't let up!", "Keep it coming!", "Pour it on!"],
	"hurt": ["Block! BLOCK!", "Get out of there!", "Move, %s, move!", "Watch it!"],
	"rip_enemy": ["It's coming apart!", "Take it apart!", "YES! Rip it off!"],
	"rip_own": ["No no no!", "We lost a part!", "Ugh! Keep going!"],
	"low": ["Hang in there, %s!", "Stay up, %s!", "Don't quit on me!"],
	"chatter": ["Watch the left!", "Find the opening!", "Go in, %s!", "Aim for the weak spot!", "Stay light!", "Wait for it..."],
	"win": ["THAT'S MY ROBOT!", "YES! YES! YES!", "Did you SEE that?!"],
	"lose": ["No...", "Get up, %s... please.", "We'll fix it. We'll fix it."],
}
const PROGRAM_LINES := {
	"start": ["[ ROUTINE ENGAGED ]", "[ COMBAT PROGRAM v%s ]"],
	"hit": ["[ HIT CONFIRMED ]", "[ DAMAGE APPLIED ]"],
	"combo": ["[ CHAIN SEQUENCE ]"],
	"hurt": ["[ RECALCULATING ]", "[ EVASION SUBROUTINE ]"],
	"rip_enemy": ["[ COMPONENT REMOVED ]"],
	"rip_own": ["[ PART LOSS DETECTED ]"],
	"low": ["[ WARNING: CORE 30% ]"],
	"chatter": ["[ ANALYZING PATTERNS ]", "[ PREDICTING INPUT ]", "[ TARGET LOCKED ]"],
	"win": ["[ OPPONENT TERMINATED ]"],
	"lose": ["[ ERROR ] [ ERROR ] [ ERROR ]"],
}

var pilots: Array = []   # one per side: {team, look, auto, bubble, bubble_t, jerk, talk_cd, chatter_t}


func setup_pilots() -> void:
	var mine: Dictionary = GameData.pilot_look
	var mine_auto := false
	if mode == "quick":
		mine = random_pilot_look(str(GameData.quick["player"]["name"]))
	elif mode == "watch":
		var lp := str(GameData.watch_robot(0).get("pilot", ""))
		mine_auto = lp == "" or lp == "KANE DYNAMICS"
		mine = Story.SPEAKERS.get(lp, {}).get("face", {})
		if mine.is_empty():
			mine = random_pilot_look(lp + str(team_p[0].label))
	var theirs := {}
	var auto := false
	if mode == "test":
		theirs = PilotArt.GUS_LOOK
	elif mode != "quick":
		var who := str(opp.get("pilot", ""))
		auto = who == ""
		theirs = Story.SPEAKERS.get(who, {}).get("face", {})
	if theirs.is_empty():
		theirs = random_pilot_look(str(opp["name"]))
	pilots = [
		{"team": 0, "look": mine, "auto": mine_auto, "bubble": "", "bubble_t": 0.0, "jerk": 0.0, "talk_cd": 0.0, "chatter_t": randf_range(5.0, 8.0)},
		{"team": 1, "look": theirs, "auto": auto, "bubble": "", "bubble_t": 0.0, "jerk": 0.0, "talk_cd": 0.0, "chatter_t": randf_range(6.0, 9.0)},
	]


## A random but stable pilot for a robot (same robot, same pilot).
func random_pilot_look(seed_text: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var skins := ["#f1d0b5", "#e2b48c", "#c8946e", "#a8714f", "#8d5a3b", "#5e3a24"]
	var hats := ["cap", "beanie", "mohawk", "helmet", "bun", "bald", ""]
	return {"skin": skins[rng.randi() % skins.size()], "hair": "#" + Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.9), rng.randf_range(0.15, 0.85)).to_html(false),
			"hat": hats[rng.randi() % hats.size()], "outfit": "#" + Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.25, 0.6)).to_html(false),
			"eyes": PilotArt.EYES[rng.randi() % PilotArt.EYES.size()],
			"glasses": PilotArt.GLASSES[rng.randi() % PilotArt.GLASSES.size()] if rng.randf() < 0.4 else "none",
			"beard": PilotArt.BEARDS[rng.randi() % PilotArt.BEARDS.size()] if rng.randf() < 0.45 else "none",
			"controller": PilotArt.CONTROLLERS[rng.randi() % PilotArt.CONTROLLERS.size()]}


func team_robot(team: int) -> Fighter:
	for f in (team_p if team == 0 else team_c):
		if f.state != "ko":
			return f
	return team_p[0] if team == 0 else team_c[0]


## A pilot shouts something (a speech bubble, no voice). force = ignore the cooldown.
func pilot_say(team: int, what: String, force: bool = false, custom: String = "") -> void:
	if pilots.size() < 2:
		return
	var pd: Dictionary = pilots[team]
	if not force and (pd["talk_cd"] > 0.0 or pd["bubble_t"] > 0.3):
		return
	var text := custom
	if text == "":
		var pool: Array = (PROGRAM_LINES if pd["auto"] else PILOT_LINES).get(what, [])
		if pool.is_empty():
			return
		text = tr(pool[randi() % pool.size()])
		if "%s" in text:
			text = text % (str(randi_range(9, 12)) if pd["auto"] else team_robot(team).label)
	pd["bubble"] = text
	pd["bubble_t"] = 1.8
	pd["talk_cd"] = randf_range(2.0, 3.2)


func pilot_jerk(team: int) -> void:
	if pilots.size() == 2:
		pilots[team]["jerk"] = 0.22


func update_pilots(delta: float) -> void:
	for pd in pilots:
		pd["bubble_t"] = maxf(0.0, pd["bubble_t"] - delta)
		pd["talk_cd"] = maxf(0.0, pd["talk_cd"] - delta)
		pd["jerk"] = maxf(0.0, pd["jerk"] - delta)
		if phase == "fight":
			pd["chatter_t"] -= delta
			if pd["chatter_t"] <= 0.0:
				pd["chatter_t"] = randf_range(6.0, 10.0)
				var r := team_robot(pd["team"])
				pilot_say(pd["team"], "low" if r.ratio("torso") < 0.3 else "chatter")


## A little pilot doll standing in its corner, working the controller.
func draw_pilot(pd: Dictionary, off: Vector2) -> void:
	var team: int = pd["team"]
	var face := 1.0 if team == 0 else -1.0
	var x: float = wall_l * 0.45 if team == 0 else screen.x - wall_l * 0.45
	var s := clampf(wall_l / 58.0, 1.2, 2.0)
	var base := Vector2(x, floor_y) + off * 0.6
	var look: Dictionary = pd["look"]
	var r := team_robot(team)
	if pd["auto"]:
		# Kane's robots have no pilot: just a terminal running the fight program
		var tw := 30.0 * s
		var th := 22.0 * s
		var top := base + Vector2(-tw * 0.5, -th - 40.0 * s)
		ci.draw_rect(Rect2(base + Vector2(-4 * s, -40 * s), Vector2(8 * s, 40 * s)), Color(0.2, 0.2, 0.24))
		ci.draw_rect(Rect2(top, Vector2(tw, th)), Color(0.1, 0.1, 0.13))
		ci.draw_rect(Rect2(top + Vector2(3, 3), Vector2(tw - 6, th - 6)), Color(0.02, 0.08, 0.04))
		for k in 4:
			var w := (tw - 12) * (0.4 + 0.6 * absf(sin(clock * 3.0 + k * 1.7)))
			ci.draw_rect(Rect2(top + Vector2(6, 6 + k * (th - 12) / 4.0), Vector2(w, 2)), Color(0.3, 1.0, 0.5, 0.8))
		ci.draw_string(font, top + Vector2(0, -4), tr("KANE"), HORIZONTAL_ALIGNMENT_CENTER, tw, int(9 * s), Color(0.88, 0.72, 0.29))
		draw_pilot_bubble(pd, top + Vector2(tw * 0.5, -14.0 * s))
		return
	var outfit := Color(look.get("outfit", "#34495e"))
	# body language follows the robot: lean in on attacks, flinch when it gets hit, cheer when it wins
	var lean := 0.0
	var hands_up := 0.0
	if phase == "ko" or phase == "results":
		var happy := (won and team == 0) or (not won and team == 1)
		hands_up = (1.0 if happy else -0.4) * (0.7 + 0.3 * absf(sin(clock * 8.0)))
	elif r.state == "hit":
		lean = -0.35
	elif ATTACKS.has(r.state) or r.state == "special":
		lean = 0.45
	elif r.blocking:
		lean = -0.15
	var bob := absf(sin(clock * 6.0)) * 2.0 * s if r.state == "walk" else sin(clock * 2.0 + team) * 0.6 * s
	PilotArt.light = fight_light() if Arena.noir() else ""
	PilotArt._begin()
	# legs
	PilotArt._blk(ci, Rect2(base + Vector2(-9 * s, -24 * s), Vector2(7 * s, 24 * s)), outfit.darkened(0.45))
	PilotArt._blk(ci, Rect2(base + Vector2(2 * s, -24 * s), Vector2(7 * s, 24 * s)), outfit.darkened(0.45))
	PilotArt._rc(ci, Rect2(base + Vector2(-10 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.12, 0.12, 0.12))
	PilotArt._rc(ci, Rect2(base + Vector2(1 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.12, 0.12, 0.12))
	# torso
	var hip := base + Vector2(0, -24 * s - bob)
	var neck := hip + Vector2(face * lean * 6 * s, -30 * s)
	var torso := PackedVector2Array([hip + Vector2(-11 * s, 0), hip + Vector2(11 * s, 0), neck + Vector2(12 * s, 0), neck + Vector2(-12 * s, 0)])
	if PilotArt.lit():
		RobotArt._plate(ci, torso, outfit)
	else:
		ci.draw_colored_polygon(torso, outfit)
	# head
	var hc := neck + Vector2(face * lean * 3 * s, -11 * s)
	var hr := 10.0 * s
	var shouting: bool = pd["bubble_t"] > 0.0
	PilotArt.draw_head(ci, hc, hr, look, face, hr * (0.35 if shouting else 0.12))
	# arms and controller: little jerks when the robot attacks, held up high when it wins
	var j: float = pd["jerk"] / 0.22
	var jx := sin(clock * 40.0) * 3.0 * s * j
	var pad := neck + Vector2(face * (14 + lean * 4) * s + jx, (10 - hands_up * 26) * s - j * 4 * s)
	for side in [-1.0, 1.0]:
		var sh := neck + Vector2(side * 10 * s, 3 * s)
		PilotArt._limb2(ci, sh, pad + Vector2(side * 6 * s, 0), outfit.darkened(0.15), 5 * s)
	PilotArt.draw_controller(ci, pad, s, str(look.get("controller", "gamepad")), j > 0.0, clock)
	draw_pilot_bubble(pd, hc + Vector2(0, -hr - 10 * s))


func draw_pilot_bubble(pd: Dictionary, anchor: Vector2) -> void:
	if pd["bubble_t"] <= 0.0 or pd["bubble"] == "":
		return
	if pd["team"] == 0 and coach_t > 0.0 and gus_here():
		return   # Gus is talking
	var size := fs(15)
	var text: String = pd["bubble"]
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := tw + 18.0
	var h := size + 14.0
	var bx := clampf(anchor.x - w * 0.5, 6.0, screen.x - w - 6.0)
	var by := anchor.y - h - 10.0
	var a := minf(1.0, pd["bubble_t"] * 4.0)
	var bg := Color(1, 1, 1, 0.92 * a) if not pd["auto"] else Color(0.05, 0.12, 0.07, 0.9 * a)
	ci.draw_rect(Rect2(bx, by, w, h), bg)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 6, by + h), Vector2(anchor.x + 6, by + h), Vector2(anchor.x, by + h + 9)]), bg)
	var tc := Color(0.08, 0.08, 0.1, a) if not pd["auto"] else Color(0.3, 1.0, 0.5, a)
	ci.draw_string(font, Vector2(bx + 9, by + h - 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tc)


# ---------------------------------------------------------------- Gus's tips during fights
# Instead of a wall of tutorial text before the first fight, Gus shouts short tips from the
# corner at the moment they matter. Each tip shows once per save (not in quick fights).

# First fight only: Gus's first few words stop the fight so you can actually read them.
const TUTORIAL_PAUSES := 4
var tut_pause := false
var tut_pauses := 0
var tut_pause_at := 0   # msec when the pause began: taps in the first moments don't count
const TUT_GRACE_MS := 1500

var coach_queue: Array = []
var coach_text := ""
var coach_t := 0.0


func coach(id: String, text: String) -> void:
	if mode == "quick" or mode == "watch" or mode == "demo" or mode == "test" or GameData.tips_seen.has(id) or id == coach_id or course_on():
		return
	for q in coach_queue:
		if q["id"] == id:
			return
	coach_queue.append({"id": id, "text": text, "at": coach_clock})


var coach_clock := 0.0   # real time (not slowed by hit-freeze or slow motion)
var coach_id := ""
const COACH_SHOW := 3.5   # seconds a tip stays up
const COACH_STALE := 3.0  # tips that waited longer than this are dropped (they come back next time)


func update_coach(delta: float) -> void:
	coach_clock += delta
	for h in [habit, cpu_habit]:
		for k in h:
			h[k] = maxf(0.0, h[k] - h[k] * 0.45 * delta)
	if player.blocking:
		habit["block"] += delta
	if cpu.blocking:
		cpu_habit["block"] += delta
	if phase == "fight":
		if phase_timer > 0.5:
			coach("aim", (tr("Tap a part of %s to aim at it. %s hits where you point.") if touch_device else tr("Click a part of %s to aim at it. %s hits where you point.")) % [cpu.label, player.label])
		if player.weak != "":
			coach("weak", tr("Your head's scan found its weakest part: the yellow diamond. Hits there do extra damage."))
		if player.power < player.power_max * 0.5:
			coach("power", tr("That blue bar under your health is POWER. Every move costs some, and kicks cost the most. Run it dry and you burn out!"))
		if phase_timer > 16.0:
			coach("counters", tr("A block stops punches, a full charge breaks a block, and kicks power through punches. Hold PUNCH or KICK to charge."))
		if phase_timer > 22.0 and not player.specials.is_empty():
			coach("moves", tr("Tap MOVES to see your special moves and how to do them.") if touch_device else tr("Press Esc to pause. Your special moves and every key are listed there."))
		if player.ratio("torso") < 0.35:
			coach("low_core", tr("Core's hurting! Lose the torso or the head and it's lights out. BLOCK!"))
		if cpu.blocking and not cpu.crouching and phase_timer > 6.0 and absf(cpu.pos.x - player.pos.x) < 260.0:
			coach("highlow", tr("He's guarding high. Hold ▼ LOW and hit: low hits get under a standing guard.") if touch_device else tr("He's guarding high. Hold S and hit: low hits get under a standing guard."))
		var lead_arm: String = player.lead_slots()[0]
		if player.alive(lead_arm) and player.ratio(lead_arm) < 0.5 and phase_timer > 5.0:
			coach("stance", tr("Your lead arm takes most of the hits. Double-tap BLOCK to switch stance and turn it away.") if touch_device else tr("Your lead arm takes most of the hits. Double-tap L to switch stance and turn it away."))
		if not player.on_ground and player.legs() > 0 and phase_timer > 3.0:
			coach("air", tr("In the air, KICK dives in feet first and PUNCH hammers down with both fists."))
		if player.burn_t > 0.0:
			coach("burnout", tr("Burned out: no power means no blocking. Back off and let the blue bar refill."))
		live_coach(delta)
	elif phase != "intro":
		coach_queue.clear()   # the fight is over: no more tips
		coach_t = minf(coach_t, 0.3)
	coach_t = maxf(0.0, coach_t - delta)
	coach_queue = coach_queue.filter(func(q): return coach_clock - q["at"] < COACH_STALE)
	if coach_t <= 0.0 and not coach_queue.is_empty():
		var q: Dictionary = coach_queue.pop_front()
		coach_text = q["text"]
		coach_id = q["id"]
		coach_t = COACH_SHOW
		coach_shown()
		GameData.tip_once(q["id"])   # only counts as seen once it was actually shown
		GameData.log_tip(q["id"], q["text"])


# ---------------------------------------------------------------- the first fight: Gus's course
# A new game's first fight is a lesson against Old Pike's junk FENCEPOST, in five steps. Each step
# is one line from Gus, a goal on screen with a counter, and stripes round what to press. Pike does
# only what the step needs (stands still, then swings slowly), the clock waits, and nobody can be
# knocked out until the last step. Then it's a real fight against a weakened Pike: hard to lose, not impossible.

const COURSE := ["move", "hit", "block", "rip", "finish"]
const COURSE_NEED := {"move": 2, "hit": 3, "block": 2, "rip": 1, "finish": 1}
var course_step := -1       # -1 = no course; COURSE.size() = done
var course_count := 0
var course_walk := 0.0      # how far you've walked this step
var course_last_x := 0.0
var course_jumped := false
var course_gap := 0.0       # a beat between steps, so a finished goal can be seen ticking over
var course_pike_t := 0.0    # Pike's next swing
var course_flash := 0.0
var course_started := false


func course_on() -> bool:
	return course_step >= 0 and course_step < COURSE.size()


func course_key() -> String:
	return COURSE[course_step] if course_on() else ""


## What Gus says when a step starts.
func course_line(k: String) -> String:
	match k:
		"move":
			return tr("Get a feel for it. Walk with ◀ ▶, then JUMP.") if touch_device else tr("Get a feel for it. Walk with A and D, then jump with Space.")
		"hit":
			return tr("Now hit him. PUNCH and KICK. Your arms and legs take turns.") if touch_device else tr("Now hit him. J punches, K kicks. Your arms and legs take turns.")
		"block":
			return tr("He's swinging back. Hold BLOCK when he punches.") if touch_device else tr("He's swinging back. Hold L when he punches.")
		"rip":
			return tr("Tap his arm to aim at it, then hit it till it comes off.") if touch_device else tr("Click his arm to aim at it, then hit it till it comes off.")
		"finish":
			return tr("Now finish him. Hold PUNCH to charge a big one, let go to swing.") if touch_device else tr("Now finish him. Hold J to charge a big one, let go to swing.")
	return ""


## The goal on screen.
func course_goal(k: String) -> String:
	return tr({"move": "WALK AND JUMP", "hit": "LAND 3 HITS", "block": "BLOCK 2 PUNCHES", "rip": "RIP OFF AN ARM", "finish": "KNOCK HIM OUT"}.get(k, ""))


## Buttons that get the marching stripes for this step.
func course_buttons(k: String) -> Array:
	match k:
		"move":
			return ["right", "left"] if course_walk < 160.0 else ["jump"]
		"hit":
			return ["punch", "kick"]
		"block":
			return ["block"]
		"rip":
			return ["punch", "kick"] if player.target.begins_with("arm") else []
		"finish":
			return ["punch"]
	return []


func course_begin(step: int) -> void:
	course_step = step
	course_count = 0
	course_walk = 0.0
	course_jumped = false
	course_last_x = player.pos.x
	course_pike_t = clock + 1.6
	if not course_on():
		GameData.tip_once("course")
		return
	var k := course_key()
	match k:
		"rip":
			# his arms are rusted through: a few hits take one off
			for slot in ["arm_front", "arm_back"]:
				if cpu.alive(slot):
					cpu.parts[slot]["hp"] = minf(cpu.parts[slot]["hp"], cpu.parts[slot]["max_hp"] * 0.3)
			player.aim_cd = 0.0   # aim right away for the lesson
		"finish":
			if cpu.alive("torso"):
				cpu.parts["torso"]["hp"] = minf(cpu.parts["torso"]["hp"], cpu.parts["torso"]["max_hp"] * 0.45)
			if not cpu.ai.is_empty():
				cpu.ai["think"] = float(cpu.ai["think"]) * 1.6   # Pike's tired: he thinks slowly
	cpu.look_dirty = true
	coach_text = course_line(k)
	coach_id = "course_" + k
	coach_t = 6.0
	GameData.log_tip("course_" + k, coach_text)


## Something happened that a step may be waiting for.
func course_event(what: String) -> void:
	if not course_on() or course_gap > 0.0:
		return
	var k := course_key()
	if (k == "hit" and what == "hit") or (k == "block" and what == "block"):
		course_count += 1
	elif k == "move" and what == "jump" and not course_jumped:
		course_jumped = true
		course_count += 1
	else:
		return
	course_flash = 0.5
	Sfx.play("target")


func update_course(delta: float) -> void:
	if not course_on():
		return
	course_flash = maxf(0.0, course_flash - delta)
	if not course_started:
		course_started = true
		course_begin(course_step)   # the bell just rang: say the first line
	var k := course_key()
	if k == "move":
		var was := course_walk
		course_walk += absf(player.pos.x - course_last_x) if player.on_ground else 0.0
		if was < 160.0 and course_walk >= 160.0:
			course_count += 1
			course_flash = 0.5
			Sfx.play("target")
	course_last_x = player.pos.x
	if k == "rip" and cpu.arms() < 2:
		course_count = 1
	if k == "finish" and cpu.state == "ko":
		course_count = 1
	# nobody gets knocked out while learning; in the last step Pike can go down, you still can't
	# (the last step is a real fight against a tired old man: hard to lose, but you can)
	var learning := k != "finish"
	for slot in player.parts:
		if learning and player.alive(slot) and player.parts[slot]["hp"] < player.parts[slot]["max_hp"] * 0.5:
			player.parts[slot]["hp"] = player.parts[slot]["max_hp"] * 0.5
	if learning:
		for slot in ["torso", "head", "head2"]:
			if cpu.alive(slot) and cpu.parts[slot]["hp"] < cpu.parts[slot]["max_hp"] * 0.5:
				cpu.parts[slot]["hp"] = cpu.parts[slot]["max_hp"] * 0.5
	if course_gap > 0.0:
		course_gap -= delta
		if course_gap <= 0.0:
			course_begin(course_step + 1)
		return
	if course_count >= int(COURSE_NEED[k]) and k != "finish":
		course_gap = 1.0
		popup(tr("NICE!"), player.pos + Vector2(0, -240.0 * player.scale), Color(0.6, 1.0, 0.6))
		Sfx.play("crowd_ooh", 0.1, -8.0)


## Old Pike's brain for the lesson: stand there, then come in and swing slowly so you can block.
func course_input(_delta: float) -> Dictionary:
	var i := empty_input()
	var dx := player.pos.x - cpu.pos.x
	var toward := "right" if dx > 0 else "left"
	var melee := ai_melee()
	match course_key():
		"block":
			if absf(dx) > melee * 0.9:
				i[toward] = true
			elif clock > course_pike_t and cpu.state in ["idle", "walk"]:
				i["punch"] = true
				course_pike_t = clock + 2.2
		"rip":
			if absf(dx) > melee * 1.6:
				i[toward] = true   # stays close enough to be hit
	return i


func draw_course() -> void:
	var k := course_key()
	if k == "":
		return
	var t := Time.get_ticks_msec() / 1000.0
	# the goal: STEP 2 OF 5 · LAND 3 HITS  1/3, with a block per thing to do
	var need: int = COURSE_NEED[k]
	var done := mini(course_count, need)
	var head := tr("STEP %d OF %d") % [course_step + 1, COURSE.size()]
	var goal := course_goal(k) + ("   %d/%d" % [done, need] if need > 1 else "")
	var hs := fs(13)
	var gs := fs(22)
	var gw := maxf(font.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x, font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x) + 40.0
	var r := Rect2(screen.x * 0.5 - gw * 0.5, screen.y * 0.04 + 104.0, gw, hs + gs + 34.0)
	var ok := course_gap > 0.0
	ci.draw_rect(r, Color(0.04, 0.04, 0.06, 0.88))
	ci.draw_rect(r, Color(0.4, 1.0, 0.5) if ok else GUI.YELLOW.lerp(Color.WHITE, course_flash), false, 3.0)
	ci.draw_string(font, Vector2(r.position.x, r.position.y + hs + 6.0), head, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, hs, Color(0.7, 0.7, 0.75))
	ci.draw_string(font, Vector2(r.position.x, r.position.y + hs + gs + 8.0), ("✓ " if ok else "") + goal, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, gs, Color(0.5, 1.0, 0.6) if ok else Color.WHITE)
	GUI.draw_blocks(ci, Rect2(r.position.x + 14.0, r.end.y - 12.0, r.size.x - 28.0, 6.0), need, float(done), Color(0.5, 1.0, 0.6) if ok else GUI.YELLOW, Color(0.2, 0.2, 0.24))
	if ok:
		return
	# marching stripes round the buttons to press (touch), or the keys in the strip (computer)
	for b in buttons:
		if touch_device and b["name"] in course_buttons(k):
			_course_ring(b["pos"], b["r"] + 7.0, t)
	if k == "rip" and not player.target.begins_with("arm"):
		# the arm to aim at: stripes round it
		for slot in ["arm_front", "arm_back"]:
			if cpu.alive(slot):
				var c := w2s(visual_point(cpu, RobotArt.part_center(cpu.get_look(), slot)))
				_course_ring(c, 46.0 * cpu.scale * scale.x, t)
				break


## A ring of marching hazard stripes (yellow / black), turning.
func _course_ring(c: Vector2, rad: float, t: float) -> void:
	ci.draw_arc(c, rad, 0.0, TAU, 48, Color(0.08, 0.08, 0.08), 6.0)
	var n := 12
	for k in n:
		var a0 := t * 1.6 + k * TAU / n
		ci.draw_arc(c, rad, a0, a0 + TAU / n * 0.5, 6, GUI.YELLOW, 6.0)


# ---------------------------------------------------------------- Gus coaching live
# Every fight, forever: Gus reads the fight and shouts what to do. In your first fights he explains
# (tutorial); later he just shouts it. Settings > Gus's coaching sets how often (Off .. Lots).

const SHOUT_GAP := [999.0, 8.0, 4.0, 2.2]   # seconds between shouts, by coaching level
var shout_cd := {}        # id -> coach_clock when it may be shouted again
var shout_next := 0.0
var cpu_turtle_t := 0.0
var late_call := false


func first_fight() -> bool:
	return (mode == "story" or mode == "pickup") and GameData.wins + GameData.losses == 0


## Gus started saying something: in your first fight, the first few stop the action.
func coach_shown() -> void:
	if first_fight() and phase == "fight" and tut_pauses < TUTORIAL_PAUSES and course_step < 0:
		tut_pauses += 1
		tut_pause = true
		tut_pause_at = Time.get_ticks_msec()
		touches.clear()
		held_buttons = {}


func coach_level() -> int:
	return clampi(int(GameData.settings.get("coaching", 2)), 0, 3)


func tutorial_fights() -> bool:
	return GameData.wins + GameData.losses < 3


## Shout something now. prio 3 = urgent (interrupts whatever Gus is saying), 2 = an opening,
## 1 = advice. Each shout has its own cooldown so he doesn't repeat himself.
func shout(id: String, short_text: String, long_text: String, prio: int, need_level: int = 1, again: float = 7.0) -> void:
	var lv := coach_level()
	if lv < need_level or not gus_here() or course_on():
		return
	if coach_clock < shout_cd.get(id, 0.0):
		return
	if prio < 3 and (coach_clock < shout_next or coach_t > 0.6):
		return
	coach_text = long_text if tutorial_fights() and long_text != "" else short_text
	coach_id = id
	coach_t = 3.0 if tutorial_fights() else (1.4 if prio == 3 else 2.2)
	shout_cd[id] = coach_clock + again
	shout_next = coach_clock + SHOUT_GAP[lv]
	coach_shown()


func live_coach(delta: float) -> void:
	if coach_level() == 0 or player.state == "ko" or cpu.state == "ko":
		return
	var dist := absf(cpu.pos.x - player.pos.x)
	var close := dist < 170.0 * maxf(player.scale, cpu.scale)
	# --- power
	if cpu.burn_t > 0.0:
		shout("cpu_burn", tr("He's burned out! HIT HIM!"), tr("He ran out of power. He can't block or move. HIT HIM!"), 3, 1, 4.0)
	if player.burn_t > 0.0:
		shout("my_burn", tr("Burned out! Hang on..."), tr("You ran out of power! Every move costs some, and kicks cost the most. Pace yourself."), 2, 1, 6.0)
	elif player.power < player.power_max * 0.25 and player.idle_t < 0.5:
		shout("low_power", tr("Watch your power! Back off!"), tr("Your power's nearly gone. Back off a second and let it refill, or you'll burn out."), 2, 1, 6.0)
	# --- reading his habits
	if close and cpu_habit["punch"] > 2.5 and player.legs() > 0:
		shout("read_punch", tr("He's mashing punches. KICK!"), tr("He keeps punching. A kick powers right through punches!"), 2, 2, 9.0)
	if close and cpu_habit["kick"] > 1.8 and player.arms() > 0:
		shout("read_kick", tr("Block his kicks, he'll run dry!"), tr("He's kicking a lot, so block them. Kicks drink power, he'll burn out soon."), 2, 2, 9.0)
	if close and cpu.state == "charge":
		shout("read_charge", tr("He's charging. Hit him first!"), tr("He's winding up a charged hit. Hit him before he lets go, a hit knocks the charge out!"), 3, 2, 6.0)
	# --- danger first
	if cpu.combo >= 2 and player.state == "hit" and not player.blocking:
		shout("combo", tr("BLOCK!"), tr("He's chaining a combo. Hold BLOCK till it stops!"), 3, 1, 3.0)
	if ATTACKS.has(cpu.state) and cpu.timer < float(ATTACKS[cpu.state]["startup"]) and close and not player.blocking:
		if cpu.state == "sweep":
			shout("sweep_in", tr("JUMP!"), tr("He's sweeping low. JUMP over it!"), 3, 3, 4.0)
		else:
			shout("incoming", tr("BLOCK!"), tr("Here it comes. BLOCK!"), 3, 3, 3.0)
	if cpu.state == "special" and dist < 260.0 and not player.blocking:
		shout("special_in", tr("Big one coming. BLOCK!"), tr("He's winding up a special move. BLOCK!"), 3, 2, 5.0)
	if not cpu.on_ground and cpu.vel.y > 0.0 and dist < 200.0 and player.on_ground and player.arms() > 0:
		shout("anti_air", tr("Uppercut! ↑+P"), tr("He's dropping in on you. Uppercut him, hold up and PUNCH!"), 2, 2, 6.0)
	# --- openings
	cpu_turtle_t = cpu_turtle_t + delta if cpu.blocking else maxf(0.0, cpu_turtle_t - delta * 2.0)
	if cpu_turtle_t > 0.9 and dist < 220.0 and player.arms() > 0:
		shout("turtle", tr("Charge it up!"), tr("He's hiding behind his guard. Hold PUNCH or KICK till it's full: a full charge breaks a block!"), 2, 1, 6.0)
	if ATTACKS.has(cpu.state) and not cpu.landed and cpu.timer > float(ATTACKS[cpu.state]["startup"]) + float(ATTACKS[cpu.state]["active"]) and close:
		shout("punish", tr("NOW! Hit him!"), tr("He missed, he's wide open. Hit him NOW!"), 2, 2, 5.0)
	if (cpu.stun_t > 0.25 or (cpu.state == "hit" and not cpu.on_ground)) and close:
		var move := ready_special()
		if move != "":
			var m: Dictionary = Specials.MOVES[move]
			shout("finisher", tr("%s! %s") % [tr(m["name"]), Specials.seq_text(m["seq"])], tr("He's dazed! Hit him with your %s. %s") % [tr(m["name"]), Specials.seq_text(m["seq"])], 2, 1, 7.0)
		else:
			shout("dazed", tr("He's dazed! P, P, K!"), tr("He's dazed! Punch, punch, kick, chain it!"), 2, 1, 6.0)
	# --- they caught our scout and swapped a part: Gus spots it
	if mode != "quick" and GameData.scouted() and GameData.scout.get("spied_back", false) and phase_timer > 1.2:
		var ch: Dictionary = GameData.scout["change"]
		if ch.get("type", "") == "part" and cpu == team_c[0]:
			var nm: String = GameData.part_def(str(ch["id"]))["name"]
			shout("scout_swap", tr("New %s! That's not what the scout saw!") % nm,
					tr("They swapped in a %s. That's not what the scout saw! Watch it.") % nm, 3, 1, 999.0)
	# --- a part that's much better than the rest of his robot
	var so: String = cpu.spec.get("standout", "")
	if so != "" and cpu.alive(so) and phase_timer > 1.5:
		var pname: String = GameData.part_def(str(cpu.parts[so]["id"]))["name"]
		shout("standout", tr("Watch it for that %s! It's a powerful piece.") % pname,
				tr("Watch out for that %s! It's a powerful piece, way better than the rest of his robot. Block it, or aim at it and tear it off!") % pname, 2, 1, 30.0)
	# --- aiming and parts
	for slot in ["head", "arm_front", "arm_back", "leg_front", "leg_back"]:
		var r := cpu.ratio(slot)
		if r > 0.0 and r < 0.25 and player.target != slot:
			shout("finish_" + slot, tr("His %s is hanging off. Aim there!") % part_word(slot), tr("His %s is hanging by a wire. Tap it to aim, and finish it!") % part_word(slot), 1, 1, 14.0)
			break
	for slot in ["arm_front", "arm_back", "leg_front", "leg_back", "head"]:
		var r := player.ratio(slot)
		if r > 0.0 and r < 0.2:
			shout("own_" + slot, tr("Your %s's nearly gone. Careful!") % part_word(slot), tr("Your %s is nearly gone. Keep it out of trouble and BLOCK more.") % part_word(slot), 1, 2, 15.0)
			break
	# --- range and gadgets
	if dist > 300.0:
		for g in player.gadgets:
			var id: String = g["id"]
			if id in ["rocket_fist", "laser", "cannon", "grapple"] and player.gadget_working(g) and player.cooldowns.get(id, 0.0) <= 0.0:
				shout("gadget_" + id, tr("Fire the %s!") % tr(Specials.GADGETS[id]["name"]), tr("He's out of reach. Fire your %s!") % tr(Specials.GADGETS[id]["name"]), 1, 2, 9.0)
				break
		for g in cpu.gadgets:
			if g["id"] in ["rocket_fist", "laser", "cannon", "grapple", "bolt"] and cpu.gadget_working(g):
				shout("close_in", tr("Get in close!"), tr("He wants to shoot from range. Close the distance!"), 1, 2, 12.0)
				break
	# --- the clock
	if time_left < 12.0 and not late_call:
		late_call = true
		var mine := player.ratio("torso")
		var theirs := cpu.ratio("torso")
		if mine < theirs:
			shout("late_behind", tr("Time's running out. GO!"), tr("Ten seconds and you're behind. Throw everything!"), 2, 1, 99.0)
		else:
			shout("late_ahead", tr("Ten seconds. Play it safe!"), tr("Ten seconds and you're ahead. Block and run the clock!"), 2, 1, 99.0)


## A special move of yours that's ready to use right now ("" if none).
func ready_special() -> String:
	for id in player.specials:
		if not Specials.MOVES.has(id) or player.cooldowns.get(id, 0.0) > 0.0:
			continue
		var m: Dictionary = Specials.MOVES[id]
		if m.get("air", false) or not m.has("startup"):   # skip air-only and passive moves
			continue
		var limb: String = m.get("limb", "arm")
		if (limb == "arm" and player.arms() == 0) or (limb == "leg" and player.legs() == 0):
			continue
		return id
	return ""


func part_word(slot: String) -> String:
	return tr({"head": "head", "arm_front": "left arm", "arm_back": "right arm", "leg_front": "left leg", "leg_back": "right leg"}.get(slot, slot))


const GUS_LOOK := {"skin": "#6b4530", "hair": "#33507a", "hat": "cap", "beard": "full", "beard_color": "#c4c4c4",
		"eyes": "#5b3a1e", "glasses": "none"}


func gus_here() -> bool:
	return mode != "quick" and mode != "watch" and mode != "demo" and mode != "test"   # (in a test drive he pilots the Junker)


## Gus stands just behind your pilot in the corner, looking over their shoulder (so he never
## blocks the controller). His tips come out of his mouth as a speech bubble.
func draw_gus(off: Vector2) -> void:
	if not gus_here():
		return
	var s := clampf(wall_l / 58.0, 1.2, 2.0)
	var base := Vector2(maxf(wall_l * 0.45 - 15.0 * s, 13.0 * s), floor_y - 12.0 * s) + off * 0.6
	var talking := coach_t > 0.0
	var overalls := Color(0.2, 0.3, 0.45)
	var shirt := Color(0.55, 0.42, 0.3)
	# legs
	ci.draw_rect(Rect2(base + Vector2(-8 * s, -24 * s), Vector2(7 * s, 24 * s)), overalls.darkened(0.2))
	ci.draw_rect(Rect2(base + Vector2(1 * s, -24 * s), Vector2(7 * s, 24 * s)), overalls.darkened(0.2))
	ci.draw_rect(Rect2(base + Vector2(-9 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.15, 0.1, 0.08))
	ci.draw_rect(Rect2(base + Vector2(1 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.15, 0.1, 0.08))
	# body: shirt with overalls over it, a bit of a belly
	var hip := base + Vector2(0, -24 * s)
	ci.draw_rect(Rect2(hip + Vector2(-12 * s, -30 * s), Vector2(24 * s, 30 * s)), shirt)
	ci.draw_rect(Rect2(hip + Vector2(-9 * s, -20 * s), Vector2(18 * s, 20 * s)), overalls)
	ci.draw_line(hip + Vector2(-7 * s, -20 * s), hip + Vector2(-7 * s, -30 * s), overalls, 2.5 * s)
	ci.draw_line(hip + Vector2(7 * s, -20 * s), hip + Vector2(7 * s, -30 * s), overalls, 2.5 * s)
	var neck := hip + Vector2(0, -30 * s)
	# left arm: hand on hip. Right arm: the Kane-built robot arm, pointing at the ring while he talks
	ci.draw_line(neck + Vector2(-11 * s, 2 * s), hip + Vector2(-15 * s, -10 * s), shirt.darkened(0.1), 5 * s)
	ci.draw_line(hip + Vector2(-15 * s, -10 * s), hip + Vector2(-9 * s, -6 * s), shirt.darkened(0.1), 5 * s)
	var wave := sin(clock * 9.0) * 3.0 * s if talking else 0.0
	# talking: points up over the pilot's head at the ring. Quiet: hand on the pilot's shoulder
	var hand := neck + (Vector2(24 * s, -22 * s + wave) if talking else Vector2(17 * s, 6 * s))
	ci.draw_line(neck + Vector2(11 * s, 2 * s), hand, Color(0.62, 0.62, 0.68), 5 * s)
	ci.draw_circle(neck + Vector2(11 * s, 2 * s), 3.5 * s, Color(0.45, 0.45, 0.5))
	ci.draw_circle(hand, 3 * s, Color(1.0, 0.6, 0.2) if talking else Color(0.5, 0.5, 0.55))
	# head
	var hc := neck + Vector2(1 * s, -11 * s)
	var mouth := 10.0 * s * (0.15 + 0.25 * absf(sin(clock * 16.0))) if talking else 1.5 * s
	PilotArt.draw_head(ci, hc, 10.0 * s, GUS_LOOK, 1.0, mouth)
	gus_head = hc + Vector2(0, -10.0 * s)


var gus_head := Vector2.ZERO


## Which kind of board shows the fight name: a chalk slate on chains at the scrapyard, a
## split-flap stadium board at the Regional and cups, a red dot-matrix LED board at the Championship.
func board_style() -> String:
	if arena_id == "scrap_ring":
		return "chalk"
	if mode == "circuit":
		return "flip"
	if arena_id in ["champ_arena", "champ_gala", "main_event", "test_track", "rooftop"]:
		return "dots"
	return "flip"


## Biggest font size (up to max_size) that fits text in width.
func fit_size(text: String, width: float, max_size: int) -> int:
	var size := max_size
	while size > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


func draw_title_board(r: Rect2) -> void:
	var title := title_text.to_upper()
	var hurry := time_left < 10.0
	match board_style():
		"chalk":
			Scoreboard.draw_chalk(ci, Rect2(r.position + Vector2(r.size.x * 0.04, 12), r.size - Vector2(r.size.x * 0.08, 20)), title, time_left, hurry, clock, font)
		"flip":
			Scoreboard.draw_flip(ci, Rect2(r.position + Vector2(0, 10), r.size - Vector2(0, 10)), title, time_left, hurry, font, fs(17))
		_:
			Scoreboard.draw_dots(ci, r, title, time_left, hurry, clock)


func draw_coach() -> void:
	if coach_t <= 0.0 or coach_text == "":
		return
	if gus_here() and gus_head != Vector2.ZERO:
		# a speech bubble from Gus in the corner
		# up in the top-left, just under your robot's name: out of the fight, clear of the HUD buttons
		var size := fs(16) if not tut_pause else fs(21)   # bigger while the fight waits for you to read it
		var maxw := minf(560.0 if not tut_pause else 680.0, quit_rect.position.x - 50.0 if not tut_pause else screen.x - 80.0)
		var text_size := font.get_multiline_string_size(coach_text, HORIZONTAL_ALIGNMENT_LEFT, maxw, size)
		var w := text_size.x + 36.0
		var h := text_size.y + size + 22.0
		var bx := 12.0
		var by := screen.y * 0.03 + 28.0 + 38.0
		var a := minf(1.0, coach_t * 4.0)
		var bg := Color(1.0, 0.97, 0.9, 0.95 * a)
		ci.draw_rect(Rect2(bx, by, w, h), bg)
		ci.draw_rect(Rect2(bx, by, w, h), Color(0.95, 0.6, 0.25, a), false, 3.0)
		# the tail points down to Gus in the corner
		var tail_x := clampf(gus_head.x, bx + 14.0, bx + w - 14.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 8, by + h), Vector2(tail_x + 8, by + h), Vector2(gus_head.x, by + h + 18)]), bg)
		ci.draw_line(Vector2(gus_head.x, by + h + 18), gus_head + Vector2(0, -4), Color(1.0, 0.97, 0.9, 0.35 * a), 2.0)
		ci.draw_string(font, Vector2(bx + 12, by + size + 4), tr("GUS"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * 0.85), Color(0.85, 0.45, 0.1, a))
		ci.draw_multiline_string(font, Vector2(bx + 12, by + size * 2 + 8), coach_text, HORIZONTAL_ALIGNMENT_LEFT, maxw, size, -1, Color(0.1, 0.08, 0.06, a))
		return
	var size := fs(17)
	var label := tr("GUS: ")
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tw := font.get_string_size(coach_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := minf(screen.x - 40.0, lw + tw + 30.0)
	var x := (screen.x - w) * 0.5
	var y := screen.y * 0.23
	var a := minf(1.0, coach_t * 3.0)
	ci.draw_rect(Rect2(x, y, w, size + 18.0), Color(0.05, 0.05, 0.08, 0.85 * a))
	ci.draw_rect(Rect2(x, y, w, size + 18.0), Color(0.95, 0.65, 0.35, 0.8 * a), false, 2.0)
	ci.draw_string(font, Vector2(x + 14, y + size + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 0.65, 0.35, a))
	ci.draw_string(font, Vector2(x + 14 + lw, y + size + 6), coach_text, HORIZONTAL_ALIGNMENT_LEFT, w - lw - 28.0, size, Color(1, 1, 1, a))


# ---------------------------------------------------------------- move showcase (garage)

func setup_demo() -> void:
	mode = "demo"
	Sfx.quiet += 1   # the garage shouldn't sound like a fight
	var m: Dictionary = Specials.MOVES[demo_move]
	var ps: Dictionary = GameData.player_spec()
	ps["specials"] = [demo_move]
	ps["style"] = str(m.get("style", GameData.style))
	ps["gadgets"] = []
	opp = GameData.OPPONENTS[0].duplicate(true)
	opp["pilot"] = ""
	var dummy: Dictionary = GameData.opponent_spec_from(opp, 1.0)
	dummy["name"] = tr("DUMMY")
	dummy["gadgets"] = []
	dummy["specials"] = []
	dummy["style"] = ""
	demo_specs = [ps, dummy]
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.82
	wall_l = screen.x * 0.04
	wall_r = screen.x * 0.96
	arena_id = "docks"
	crowd_id = "dockers"
	crowd = []
	demo_reset()
	setup_pilots()
	arena_layer = ArenaLayer.new()
	arena_layer.fight = self
	arena_layer.show_behind_parent = true
	add_child(arena_layer)
	phase = "fight"
	fight_called = true


## Fresh robots for the next loop: yours on the left, a tough dummy on the right.
func demo_reset() -> void:
	team_p = [make_fighter(demo_specs[0])]
	team_c = [make_fighter(demo_specs[1])]
	var me: Fighter = team_p[0]
	var dummy: Fighter = team_c[0]
	me.team = 0
	dummy.team = 1
	dummy.facing = -1
	for f in [me, dummy]:
		f.scale = maxf(f.scale, BOT_SCALE)
		f.spec["scale"] = f.scale
		f.look_dirty = true
	for slot in dummy.parts:
		if not dummy.parts[slot].is_empty():
			dummy.parts[slot]["hp"] = dummy.parts[slot]["hp"] * 40.0   # it takes the move all day long
			dummy.parts[slot]["max_hp"] = dummy.parts[slot]["max_hp"] * 40.0
	me.foe = dummy
	dummy.foe = me
	player = me
	cpu = dummy
	var gap := screen.x * (0.24 if Specials.MOVES[demo_move].get("ranged", false) else 0.17)
	me.pos = Vector2(screen.x * 0.5 - gap, floor_y)
	dummy.pos = Vector2(screen.x * 0.5 + gap * 0.6, floor_y)
	projectiles.clear()
	debris.clear()
	popups.clear()
	demo_t = 0.7
	demo_fired = false


func demo_process(delta: float) -> void:
	clock += delta
	phase_timer += delta
	time_left = FIGHT_TIME
	if hitstop > 0.0:
		hitstop -= delta
		redraw_all()
		return
	if slowmo > 0.0:
		slowmo -= delta
		delta *= 0.35
	var m: Dictionary = Specials.MOVES[demo_move]
	demo_t -= delta
	if not demo_fired and demo_t <= 0.0:
		var air: bool = m.get("air", false)
		if air and player.on_ground:
			player.vel.y = -JUMP_SPEED   # air moves start with a jump
			player.on_ground = false
		elif not air or player.vel.y > -250.0:
			player.cooldowns.erase(demo_move)
			player.power = player.power_max
			if can_special(player, demo_move):
				start_special(player, demo_move)
				demo_fired = true
				demo_t = 2.4
	elif demo_fired and demo_t <= 0.0 and player.state != "special":
		demo_reset()
	update_fighter(player, cpu, empty_input(), delta)
	update_fighter(cpu, player, empty_input(), delta)
	separate()
	update_projectiles(delta)
	update_effects(delta)
	arena_redraw_t -= delta
	if arena_redraw_t <= 0.0 and arena_layer:
		arena_redraw_t = 1.0 / ARENA_FPS
		arena_layer.queue_redraw()
	redraw_all()



# ---------------------------------------------------------------- the walk-in
# Every fight opens with the announcer's show (he calls each corner, the camera zooms in on each
# robot and its specialities) - SKIP skips the lot - then 3, 2, 1, FIGHT! During the count you can
# move but not cross the middle: in the scrap league the announcer stands there on a crate and
# carries it off; in the Regional and the cups he has a steel podium that sinks into the floor; in
# the Championship a machined gate drops into the floor and he calls it from a gilded box.

func barrier_for(id: String) -> String:
	if id == "scrap_ring":
		return "crate"
	if id in ["champ_arena", "champ_gala", "main_event", "test_track", "rooftop"]:
		return "gate"
	return "podium"


func move_only(i: Dictionary) -> Dictionary:
	var o := empty_input()
	for k in ["left", "right", "up", "down", "jump", "jump_press"]:
		o[k] = i[k]
	return o


func update_walk_in(delta: float) -> void:
	if intro_step == "show":
		if beat_t == 0.0 and beat == 0:
			Sfx.play("crowd_cheer", 0.0, -6.0)
		card_t += delta
		if show_paused:
			return
		# the announcer's caption types out with his own voice
		if int(card_t * 45.0) < announcer_line().length():
			talk_beep -= delta
			if talk_beep <= 0.0:
				talk_beep = 0.07
				Sfx.voice({"crate": "ANNOUNCER_SCRAP", "gate": "ANNOUNCER_GRAND"}.get(barrier_kind, "ANNOUNCER"))
		beat_t += delta
		if beat_t >= float(SHOW_BEATS[beat][1]):
			beat += 1
			beat_t = 0.001
			card_t = 0.0
			if beat >= SHOW_BEATS.size():
				start_count()
		return
	count_t += delta
	var n := int(count_t / COUNT_STEP)
	if n != count_shown:
		count_shown = n
		if n < 3:
			Sfx.play("round" if n == 0 else "click", 0.0, -4.0)
	if count_t >= 3.0 * COUNT_STEP:
		phase = "fight"
		phase_timer = 0.0
		fight_called = true
		barrier_gone = true
		fight_flash = 0.9
		Sfx.play("fight", 0.0, -3.0)
		pilot_say(0, "start", true)
		pilot_say(1, "start", true)


func start_count() -> void:
	intro_step = "count"
	show_paused = false
	if fight_track != "":
		Sfx.music(fight_track)
	count_t = 0.0
	count_shown = -1


## SKIP: straight to the countdown.
func skip_show() -> void:
	Sfx.play("click")
	start_count()


func show_beat() -> String:
	return str(SHOW_BEATS[mini(beat, SHOW_BEATS.size() - 1)][0]) if intro_step == "show" and phase == "intro" else ""


## The camera: wide for the announcer, close on a robot while he talks it up, back out for the fight.
## The fight camera (1.57): it follows the fighters and closes in when they're close (up to
## CAM_CLOSE), pulling back out to the whole ring as they part. The floor line stays put on the
## screen; the zoom crops the sky and the sides. The HUD is on its own layer and doesn't zoom.
const CAM_CLOSE := 1.25
const CAM_NEAR := 260.0      # gap between the robots at full zoom
const CAM_FAR := 620.0       # gap at which the camera is all the way out


## The light set the robots stand in: the venue's own when it has one (light.gd), else "fight".
func fight_light() -> String:
	return arena_id if Light.SETS.has(arena_id) else "fight"


func follow_view() -> Array:
	var xs: Array = []
	for f in all_fighters():
		if f.state != "ko":
			xs.append(f.pos.x)
	if xs.size() < 2:
		return [1.0, screen * 0.5]
	var lo: float = xs.min()
	var hi: float = xs.max()
	var gap := hi - lo
	var z := lerpf(CAM_CLOSE, 1.0, clampf((gap - CAM_NEAR) / (CAM_FAR - CAM_NEAR), 0.0, 1.0))
	var hw := screen.x * 0.5 / z
	var hh := screen.y * 0.5 / z
	# the floor line stays where it is on the screen: the robots grow up from it, the sky is cropped
	var cy := floor_y - (floor_y - screen.y * 0.5) / z
	var c := Vector2(clampf((lo + hi) * 0.5, hw, screen.x - hw), clampf(cy, hh, screen.y - hh))
	return [z, c]


func update_camera(delta: float) -> void:
	var tz := 1.0
	var tc := screen * 0.5
	if (phase == "fight" or (phase == "intro" and intro_step == "count")) and demo_move == "" and not GameData.settings.get("still_camera", false):
		var fv := follow_view()
		tz = fv[0]
		tc = fv[1]
	match show_beat():
		"a_call", "b_call":
			tz = 1.25
			tc = Vector2(screen.x * 0.5, floor_y - screen.y * 0.25)
		"a_zoom":
			tz = 1.9
			tc = Vector2(player.pos.x + screen.x * 0.12, floor_y - screen.y * 0.22)
		"b_zoom":
			tz = 1.9
			tc = Vector2(cpu.pos.x - screen.x * 0.12, floor_y - screen.y * 0.22)
	if moment_t > 0.0 and moment_on != null:
		var mf: Fighter = moment_on
		tz = 1.3 if moment_kind == "ko" else 1.4
		tc = Vector2(mf.pos.x, mf.pos.y - 100.0 * mf.scale)
		# keep the view inside the ring
		var hw := screen.x * 0.5 / tz
		var hh := screen.y * 0.5 / tz
		tc.x = clampf(tc.x, hw, screen.x - hw)
		tc.y = clampf(tc.y, hh, screen.y - hh)
	if phase == "results":
		tz = 1.0
		tc = screen * 0.5
	var k := 1.0 - exp(-(9.0 if moment_t > 0.0 else 5.0) * delta)
	cam_z = lerpf(cam_z, tz, k)
	cam_c = cam_c.lerp(tc, k)
	if absf(cam_z - 1.0) < 0.002 and cam_c.distance_to(screen * 0.5) < 0.5:
		cam_z = 1.0
		cam_c = screen * 0.5
	scale = Vector2(cam_z, cam_z)
	position = screen * 0.5 - cam_c * cam_z


## The announcer and the barrier in the middle of the ring.
func draw_walk_in(off: Vector2) -> void:
	var mid := screen.x * 0.5
	var s := clampf(screen.y / 330.0, 1.2, 2.2)
	var t := count_t if intro_step == "count" else 0.0
	if phase != "intro":
		t = 99.0
	var pose := "announce_up"
	var pdir := 1.0
	match show_beat():
		"a_call", "a_zoom":
			pose = "announce"
			pdir = -1.0
		"b_call", "b_zoom":
			pose = "announce"
	var lit := Arena.noir()
	PilotArt.light = fight_light() if lit else ""
	if lit:
		RobotArt._set_light(fight_light(), 1.0)
		RobotArt._grade = 2
		RobotArt._flash = false
	match barrier_kind:
		"crate", "podium":
			var bh := 58.0 * s * 0.6 if barrier_kind == "crate" else 74.0 * s * 0.6
			var bw := 64.0 * s * 0.6 if barrier_kind == "crate" else 86.0 * s * 0.6
			# he hops down at "3", then (crate) carries it off into the back, or (podium) walks off as it sinks
			var hop := clampf(t / 0.35, 0.0, 1.0)
			var walk := clampf((t - 0.6) / 1.7, 0.0, 1.0)
			var feet := Vector2(mid, floor_y - bh).lerp(Vector2(mid + bw * 0.7, floor_y), hop)
			feet.y -= sin(hop * PI) * 26.0
			var ps := s
			var alpha := 1.0
			if walk > 0.0:
				feet = Vector2(mid + bw * 0.7 + walk * 60.0, floor_y - walk * 70.0)
				ps = s * (1.0 - 0.45 * walk)
				alpha = clampf((1.0 - walk) * 3.0, 0.0, 1.0)
			var box_r := Rect2(mid - bw * 0.5, floor_y - bh, bw, bh)
			if barrier_kind == "crate":
				# the crate goes with him once he's picked it up
				var lift := clampf((t - 0.35) / 0.25, 0.0, 1.0)
				if lift > 0.0:
					var held := feet + Vector2(-bw * 0.5 * ps / s, -76.0 * ps - bh * ps / s)   # carried over his head, both hands on it
					box_r = Rect2(Vector2(mid - bw * 0.5, floor_y - bh).lerp(held, lift), Vector2(bw, bh) * (ps / s))
				if lit and alpha >= 0.99:
					# a lit wooden crate: plate, cross braces, a stencil band
					var br := Rect2(box_r.position + off, box_r.size)
					RobotArt._plate(ci, RobotArt._chamfer(br, 4.0), Color(0.55, 0.38, 0.2))
					var inset := br.grow(-5.0)
					RobotArt._ln(ci, inset.position, inset.end, Color(0.42, 0.28, 0.14), 4.0)
					RobotArt._ln(ci, Vector2(inset.end.x, inset.position.y), Vector2(inset.position.x, inset.end.y), Color(0.42, 0.28, 0.14), 4.0)
					ci.draw_rect(Rect2(br.position.x + 3, br.position.y + br.size.y * 0.42, br.size.x - 6, br.size.y * 0.16), Color(0.1, 0.08, 0.05, 0.55))
				elif alpha > 0.0:
					var c := Color(0.55, 0.38, 0.2, alpha)
					ci.draw_rect(Rect2(box_r.position + off, box_r.size), c)
					ci.draw_rect(Rect2(box_r.position + off, box_r.size), Color(0.3, 0.2, 0.1, alpha), false, 3.0)
					ci.draw_line(box_r.position + off, box_r.end + off, Color(0.35, 0.24, 0.12, alpha), 3.0)
					ci.draw_line(Vector2(box_r.end.x, box_r.position.y) + off, Vector2(box_r.position.x, box_r.end.y) + off, Color(0.35, 0.24, 0.12, alpha), 3.0)
			else:
				# a steel podium with steps and a mic stand; it sinks into the floor during the count
				var sink := clampf((t - 0.6) / 1.6, 0.0, 1.0)
				var h := bh * (1.0 - sink)
				if h > 1.0 and lit:
					var pr2 := Rect2(Vector2(mid - bw * 0.5, floor_y - h) + off, Vector2(bw, h))
					RobotArt._plate(ci, RobotArt._chamfer(pr2, 4.0), Color(0.42, 0.45, 0.52))
					if h > 8.0:
						RobotArt._plate(ci, RobotArt._chamfer(Rect2(pr2.position, Vector2(bw, 7.0)), 2.0), Color(0.95, 0.76, 0.19))
					for k in 3:
						var sy := floor_y - h + (k + 1) * h / 4.0
						ci.draw_line(Vector2(pr2.position.x + 3, sy + off.y), Vector2(pr2.end.x - 3, sy + off.y), RobotArt.OUTLINE, 2.0)
					ci.draw_rect(Rect2(Vector2(mid - bw * 0.5 - 6, floor_y - 3) + off, Vector2(bw + 12, 3)), Color(0.1, 0.1, 0.1))
				elif h > 1.0:
					var pr := Rect2(mid - bw * 0.5, floor_y - h, bw, h)
					ci.draw_rect(Rect2(pr.position + off, pr.size), Color(0.42, 0.45, 0.52))
					ci.draw_rect(Rect2(pr.position + off, Vector2(bw, minf(6.0, h))), Color(0.95, 0.76, 0.19))
					for k in 3:
						var sy := floor_y - h + (k + 1) * h / 4.0
						ci.draw_line(Vector2(pr.position.x, sy) + off, Vector2(pr.end.x, sy) + off, Color(0.3, 0.32, 0.38), 2.0)
					ci.draw_rect(Rect2(Vector2(mid - bw * 0.5 - 6, floor_y - 3) + off, Vector2(bw + 12, 3)), Color(0.1, 0.1, 0.1))
			if alpha > 0.0 and t < 99.0:
				var look: Dictionary = ANNOUNCERS[barrier_kind]
				var p2 := pose if t <= 0.0 else ("carry_up" if barrier_kind == "crate" and t > 0.35 else "walk_mic")
				PilotArt.draw_person(ci, feet + off, ps, look, pdir if t <= 0.0 else 1.0, p2, clock)
				if barrier_kind == "gate":
					draw_announcer_prop(feet + off, ps, pdir)
		"gate":
			# the machined gate: two steel leaves with warning lights; they drop into the floor at the bell
			var drop := clampf(phase_timer / 0.45, 0.0, 1.0) if phase != "intro" else 0.0
			var gh := 150.0 * s * 0.6 * (1.0 - drop)
			if gh > 1.0:
				for side in [-1.0, 1.0]:
					var r := Rect2(mid + (0.0 if side > 0 else -22.0 * s * 0.6), floor_y - gh, 22.0 * s * 0.6, gh)
					if lit:
						RobotArt._plate(ci, RobotArt._chamfer(Rect2(r.position + off, r.size), 3.0), Color(0.24, 0.26, 0.32))
						if gh > 8.0:
							RobotArt._plate(ci, PackedVector2Array([r.position + off, r.position + off + Vector2(r.size.x, 0), r.position + off + Vector2(r.size.x, 6), r.position + off + Vector2(0, 6)]), Color(0.95, 0.76, 0.19))
					else:
						ci.draw_rect(Rect2(r.position + off, r.size), Color(0.2, 0.22, 0.27))
						ci.draw_rect(Rect2(r.position + off, Vector2(r.size.x, 5)), Color(0.95, 0.76, 0.19))
					var blink := fmod(clock * 2.0, 1.0) < 0.5
					for k in int(gh / 30.0):
						var on := blink != (k % 2 == 0)
						var wp := r.position + off + Vector2(r.size.x * 0.5, 14 + k * 30)
						if lit and on:
							ci.draw_circle(wp, 10.0, Color(1.0, 0.25, 0.2, 0.18))   # a warning light is a real light
						ci.draw_circle(wp, 4.0, Color(1.0, 0.25, 0.2) if on else Color(0.35, 0.1, 0.08))
				ci.draw_rect(Rect2(Vector2(mid - 30 * s, floor_y - 4) + off, Vector2(60 * s, 4)), Color(0.1, 0.1, 0.1))
			# the gilded announcer's box at the back, above the ring - he stays up there all fight
			var bx := Vector2(mid, floor_y - screen.y * 0.3) + off * 0.5
			var booth := Rect2(bx + Vector2(-46, 0), Vector2(92, 34))
			var bs := clampf(s * 0.75, 1.0, 1.6)
			PilotArt.draw_person(ci, bx + Vector2(0, 2), bs, ANNOUNCERS["gate"], pdir, pose if phase == "intro" or phase == "ko" else "walk_mic", clock)
			draw_announcer_prop(bx + Vector2(0, 2), bs, pdir)
			if lit:
				RobotArt._plate(ci, RobotArt._chamfer(booth, 4.0), Color(0.45, 0.08, 0.12))
				ci.draw_rect(booth.grow(-3.0), Color(0.88, 0.7, 0.25), false, 2.0)
				RobotArt._plate(ci, RobotArt._chamfer(Rect2(booth.position + Vector2(-2, -6), Vector2(booth.size.x + 4, 6)), 2.0), Color(0.88, 0.7, 0.25))
			else:
				ci.draw_rect(booth, Color(0.45, 0.08, 0.12))
				ci.draw_rect(booth, Color(0.88, 0.7, 0.25), false, 3.0)
				ci.draw_rect(Rect2(booth.position + Vector2(0, -5), Vector2(booth.size.x, 5)), Color(0.88, 0.7, 0.25))
			for k in 5:
				ci.draw_circle(booth.position + Vector2(10 + k * 18, booth.size.y * 0.55), 3.0, Color(0.95, 0.85, 0.4))
			ci.draw_line(booth.position + Vector2(20, booth.size.y), booth.position + Vector2(8, booth.size.y + 30), Color(0.88, 0.7, 0.25), 3.0)
			ci.draw_line(booth.position + Vector2(booth.size.x - 20, booth.size.y), booth.position + Vector2(booth.size.x - 8, booth.size.y + 30), Color(0.88, 0.7, 0.25), 3.0)


## What each announcer holds up to his mouth (and the tux's bow tie).
func draw_announcer_prop(feet: Vector2, s: float, dir: float) -> void:
	# the tuxedo's shirt front and bow tie (the mic itself is in his hand - see PilotArt "announce")
	if barrier_kind != "gate":
		return
	var neck := feet + Vector2(0, -53.0 * s)
	ci.draw_colored_polygon(PackedVector2Array([neck + Vector2(-4 * s, 2 * s), neck + Vector2(4 * s, 2 * s), neck + Vector2(0, 12 * s)]), Color(0.95, 0.95, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([neck + Vector2(-4 * s, 0), neck, neck + Vector2(-4 * s, 3 * s)]), Color(0.6, 0.05, 0.1))
	ci.draw_colored_polygon(PackedVector2Array([neck + Vector2(4 * s, 0), neck, neck + Vector2(4 * s, 3 * s)]), Color(0.6, 0.05, 0.1))


## Robots' special parts and moves get pulsing rings while the camera is on them.
func draw_show_marks(off: Vector2) -> void:
	var f: Fighter = null
	match show_beat():
		"a_zoom":
			f = player
		"b_zoom":
			f = cpu
	if f == null:
		return
	for slot in special_slots(f):
		var p := visual_point(f, RobotArt.part_center(f.get_look(), slot)) + off
		var r := 16.0 + sin(clock * 6.0) * 3.0
		ci.draw_arc(p, r, 0, TAU, 28, Color(1.0, 0.85, 0.2), 3.0)


## Parts worth shouting about: ones with a trait or a gadget.
## The walk-in spec card: name, class and style, every part with its health blocks (1 block =
## 25 HP) and its numbers, special parts starred, then the special moves.
func draw_robot_card(ci: CanvasItem, f: Fighter, left: bool, w: float, h: float, font: Font, top_at: float = -1.0) -> void:
	# every height comes from the font sizes, so the card grows with Settings > Text size
	var l1 := float(fs(14)) + 5.0      # a part's name line
	var l2 := float(fs(12)) + 7.0      # its health and numbers under it
	var parts_n := 0
	for slot in GameData.SLOTS:
		if not f.parts.get(slot, {}).is_empty():
			parts_n += 1
	var specials_shown: Array = []
	for slot in special_slots(f):
		var pid := str(f.parts[slot]["id"])
		if not specials_shown.has(pid) and specials_shown.size() < 3:
			specials_shown.append(pid)
	var head_h := fs(28) + fs(14) + fs(12) + 26.0
	var card_h := head_h + parts_n * (l1 + l2) + specials_shown.size() * l1 + fs(12) + 10.0 + (fs(13) + 4.0) * 2.0 + 16.0
	var top := clampf(h * 0.1, 8.0, maxf(8.0, h - card_h - 70.0)) if top_at < 0.0 else top_at
	var card := Rect2(w * 0.03 if left else w * 0.55, top, w * 0.42, card_h)
	var a := clampf(card_t * 3.0, 0.0, 1.0)
	var x := card.position.x + 16
	var cw := card.size.x - 32
	var gold := Color(1.0, 0.85, 0.2, a)
	ci.draw_rect(card, Color(0.04, 0.04, 0.07, 0.86 * a))
	ci.draw_rect(Rect2(card.position, Vector2(card.size.x, 5)), gold)
	var y := card.position.y + 8 + fs(28)
	ci.draw_string(font, Vector2(x, y), f.label, HORIZONTAL_ALIGNMENT_LEFT, cw, fs(28), Color(1, 1, 1, a))
	y += fs(14) + 8
	var power := 0.0
	for slot in f.parts:
		if not f.parts[slot].is_empty():
			power += float(GameData.part_def(f.parts[slot]["id"]).get("draw", 0))
	var sub := tr(GameData.weight_class(power))
	if Catalog.STYLES.has(f.style):
		sub += "  ·  " + tr(Catalog.STYLES[f.style]["name"]).to_upper()
	sub += "  ·  " + tr("fight power %d") % int(f.power_max)
	ci.draw_string(font, Vector2(x, y), sub, HORIZONTAL_ALIGNMENT_LEFT, cw, fs(14), Color(0.6, 0.85, 1.0, a))
	y += fs(12) + 10
	ci.draw_string(font, Vector2(x, y), tr("PARTS"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(12), gold)
	if f.team == 1 or mode == "watch":
		# the pilot's Read (and RATTLED after a bad run), right of the PARTS header
		var rd := tr("READ %s") % GameData.aim_dots(f.ai_level) + ("  " + tr("RATTLED") if f.ai_rattled else "")
		ci.draw_string(font, Vector2(x, y), rd, HORIZONTAL_ALIGNMENT_RIGHT, cw, fs(13), Color(1.0, 0.5, 0.4, a) if f.ai_rattled else Color(0.6, 0.85, 1.0, a))
	for slot in GameData.SLOTS:
		var pr: Dictionary = f.parts.get(slot, {})
		if pr.is_empty():
			continue
		var d := GameData.part_def(str(pr["id"]))
		# line 1: slot and name
		y += l1
		var special := str(d.get("trait", "")) != "" or str(d.get("gimmick", "")) != ""
		var slot_txt := tr(GameData.SLOT_NAMES[slot]).to_upper()
		var sw := font.get_string_size(slot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(11)).x
		ci.draw_string(font, Vector2(x, y), slot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(11), Color(0.62, 0.62, 0.7, a))
		ci.draw_string(font, Vector2(x + sw + 8, y), ("★ " if special else "") + tr(str(d["name"])), HORIZONTAL_ALIGNMENT_LEFT, cw - sw - 8,
				fs(14), gold if special else Color(1, 1, 1, a))
		# line 2: health blocks (1 block = 25 HP, dents show as empty blocks), HP numbers, then armor / damage / speed
		y += l2
		var bx := x
		if pr.has("max_hp") and float(pr["max_hp"]) > 0.0:
			var mx := float(pr["max_hp"])
			var hp := float(pr["hp"])
			var n := int(ceil(mx / GUI.HP_UNIT))
			var bw := minf(cw * 0.34, n * 6.0)
			var bh := float(fs(12)) * 0.7
			GUI.draw_blocks(ci, Rect2(x, y - bh, bw, bh), n, hp / GUI.HP_UNIT, Color(0.4, 0.95, 0.5, a), Color(0.25, 0.08, 0.08, a), false)
			var r := hp / mx
			var hc := Color(0.55, 0.95, 0.6, a) if r >= 0.6 else Color(1.0, 0.75, 0.3, a) if r >= 0.3 else Color(1.0, 0.4, 0.35, a)
			var ht := "%d/%d" % [int(round(hp)), int(round(mx))]
			if r < 0.3:
				ht += "  " + tr("CRACKED")
			elif r < 0.6:
				ht += "  " + tr("DENTED")
			ci.draw_string(font, Vector2(x + bw + 8, y), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(12), hc)
			bx = x + bw + 8 + font.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(12)).x + 12
		var stat := ""
		if str(d.get("kind", "")) == "reactor":
			stat = tr("out %d") % int(d["output"])
		else:
			var bits: Array = []
			if int(d.get("armor", 0)) > 0:
				bits.append(tr("arm %d") % int(d["armor"]))
			if int(d.get("damage", 0)) != 0:
				bits.append(tr("dmg %+d") % int(d["damage"]))
			if int(d.get("speed", 0)) != 0:
				bits.append(tr("spd %+d") % int(d["speed"]))
			if slot.begins_with("head"):
				bits.append(tr("aim in %.1fs · scan %.1fs") % [f.aim_time, f.scan_time])
			stat = " · ".join(bits)
		ci.draw_string(font, Vector2(bx, y), stat, HORIZONTAL_ALIGNMENT_RIGHT, maxf(0.0, x + cw - bx), fs(12), Color(0.75, 0.75, 0.82, a))
	# what the starred parts do
	for pid in specials_shown:
		var d := GameData.part_def(pid)
		var what := Catalog.trait_text(d).split(":")[0] if str(d.get("trait", "")) != "" else tr(Specials.GADGETS[d["gimmick"]]["name"]) if Specials.GADGETS.has(str(d.get("gimmick", ""))) else ""
		y += l1
		ci.draw_string(font, Vector2(x, y), "★ %s  ·  %s" % [tr(str(d["name"])), what], HORIZONTAL_ALIGNMENT_LEFT, cw, fs(13), gold)
	y += fs(12) + 14
	ci.draw_string(font, Vector2(x, y), tr("SPECIAL MOVES"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(12), gold)
	y += fs(13) + 6
	var moves: Array = []
	for id in f.specials:
		if Specials.MOVES.has(id):
			moves.append("%s %s" % [tr(Specials.MOVES[id]["name"]), Specials.seq_text(Specials.MOVES[id]["seq"])])
	var mt := tr("None, just fists and nerve") if moves.is_empty() else "   ".join(moves)
	ci.draw_multiline_string(font, Vector2(x, y), mt, HORIZONTAL_ALIGNMENT_LEFT, cw, fs(13), 2, Color(1, 1, 1, a) if not moves.is_empty() else Color(0.7, 0.7, 0.75, a))


func special_slots(f: Fighter) -> Array:
	var out: Array = []
	for slot in BODY_PARTS:
		var p: Dictionary = f.parts[slot]
		if p.is_empty():
			continue
		var d := GameData.part_def(str(p["id"]))
		if str(d.get("trait", "")) != "" or str(d.get("gimmick", "")) != "":
			out.append(slot)
	return out


func corner_pilot(team: int) -> String:
	if team == 0:
		if mode == "watch":
			return str(GameData.watch_robot(0).get("pilot", ""))
		if mode == "quick":
			return ""
		return GameData.pilot_name
	return str(opp.get("pilot", ""))


## What the announcer says while the show is on.
func announcer_line() -> String:
	var b := show_beat()
	var f: Fighter = player if b.begins_with("a") else cpu
	var who := corner_pilot(0 if b.begins_with("a") else 1)
	var name := f.label if (f == player and team_p.size() == 1) or (f == cpu and team_c.size() == 1) else (tr("TEAM %s") % f.label if f == player else str(opp["name"]))
	var opener: String = {"crate": tr("Alright, you lot, settle down!"), "podium": tr("Ladies and gentlemen, welcome to fight night!"),
			"gate": tr("LADIES AND GENTLEMEN... THIS... IS... THE CHAMPIONSHIP!")}[barrier_kind]
	match b:
		"b_call":
			if who == "" or who == "KANE DYNAMICS":
				return opener + " " + tr("In the right corner, no pilot, just Kane Dynamics' fight program...")
			return opener + " " + tr("In the right corner, piloted by %s...") % who
		"b_zoom":
			return tr("...%s!") % name
		"a_call":
			return tr("And in the left corner, piloted by %s...") % who if who != "" else tr("And in the left corner...")
		"a_zoom":
			return tr("...%s!") % name
	return ""


## The show's overlay: title band, the announcer's caption, the robot's card, SKIP.
func draw_intro_overlay(ci: CanvasItem) -> void:
	skip_rect = Rect2()
	if phase != "intro" or intro_step != "show":
		return
	var w := screen.x
	var h := screen.y
	# letterbox bars, cinema style
	ci.draw_rect(Rect2(0, 0, w, h * 0.09), Color(0, 0, 0, 0.85))
	ci.draw_rect(Rect2(0, h * 0.91, w, h * 0.09), Color(0, 0, 0, 0.85))
	ci.draw_string(font, Vector2(24, h * 0.065), title_text + "   ·   " + tr(Arena.ARENAS[arena_id]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 430, fs(18), Color(1.0, 0.85, 0.3))
	skip_rect = Rect2(w - 190, h * 0.012, 170, h * 0.07)
	pause_rect = Rect2(w - 380, h * 0.012, 170, h * 0.07)
	ci.draw_rect(pause_rect, Color(1, 1, 1, 0.22 if show_paused else 0.12))
	ci.draw_rect(pause_rect, Color(1, 1, 1, 0.6), false, 2.0)
	ci.draw_string(font, pause_rect.position + Vector2(0, pause_rect.size.y * 0.68), tr("PLAY") if show_paused else tr("PAUSE"), HORIZONTAL_ALIGNMENT_CENTER, pause_rect.size.x, fs(18), Color.WHITE)
	ci.draw_string(font, Vector2(24, h * 0.965), tr("PAUSED · ") if show_paused else "", HORIZONTAL_ALIGNMENT_LEFT, -1, fs(15), Color(1.0, 0.85, 0.3))
	ci.draw_string(font, Vector2(24 + (font.get_string_size(tr("PAUSED · "), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(15)).x if show_paused else 0.0), h * 0.965),
			tr("Tap a robot to see its specs"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(15), Color(0.8, 0.8, 0.85))
	ci.draw_rect(skip_rect, Color(1, 1, 1, 0.12))
	ci.draw_rect(skip_rect, Color(1, 1, 1, 0.6), false, 2.0)
	ci.draw_string(font, skip_rect.position + Vector2(0, skip_rect.size.y * 0.68), tr("SKIP ›"), HORIZONTAL_ALIGNMENT_CENTER, skip_rect.size.x, fs(20), Color.WHITE)
	# the announcer's caption, typed out
	var line := announcer_line()
	var shown := mini(line.length(), int(card_t * 45.0))
	var cap := Rect2(w * 0.18, h * 0.74, w * 0.64, h * 0.14)
	ci.draw_rect(cap, Color(0.05, 0.05, 0.08, 0.88))
	ci.draw_rect(Rect2(cap.position, Vector2(4, cap.size.y)), Color(1.0, 0.85, 0.2))
	ci.draw_string(font, cap.position + Vector2(16, 24), tr("ANNOUNCER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs(13), Color(1.0, 0.85, 0.2))
	ci.draw_multiline_string(font, cap.position + Vector2(16, 50), line.substr(0, shown), HORIZONTAL_ALIGNMENT_LEFT, cap.size.x - 32, fs(21), 2, Color.WHITE)
	# the robot's card while the camera is on it: everything about it, since you can see it anyway
	var b := show_beat()
	if b.ends_with("zoom"):
		draw_robot_card(ci, player if b == "a_zoom" else cpu, b == "b_zoom", w, h, font)



# ---------------------------------------------------------------- posting from the results (1.63)

var post_card: Control = null   # the BotMedia card on the results screen's right side


## The results text centres in this width (the post card takes the right side while it's up).
func results_width() -> float:
	return screen.x * 0.6 if post_card != null and is_instance_valid(post_card) else screen.x


## After your own fight (or one you watched): the post waiting on BotMedia, right there, the same
## card as BotMedia's Home. Pick one, or Say nothing; leaving keeps it waiting on BotMedia.
func show_post_card() -> void:
	if mode in ["quick", "test", "demo"] or GameData.Social.drafts().is_empty():
		return
	# (1.70) the picture that goes with the post: both robots as the bell left them
	if player != null and cpu != null:
		var pic := {"kind": "still", "a": player.get_look().duplicate(true), "b": cpu.get_look().duplicate(true), "venue": arena_id, "won": won,
				"an": player.pilot_name if player.pilot_name != "" else str(player.spec.get("name", "")),
				"bn": cpu.pilot_name if cpu.pilot_name != "" else str(cpu.spec.get("name", "")), "ko": ko_text}
		GameData.Social.st()["draft"]["pic"] = pic
		GameData.Social.st()["last_pic"] = pic
	var holder := ScrollContainer.new()
	holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.position = Vector2(screen.x * 0.61, screen.y * 0.22)
	holder.size = Vector2(screen.x * 0.37, screen.y * 0.66)
	var card := GUI.DraftCard.new()
	card.wrap = true
	card.custom_minimum_size = Vector2(holder.size.x - 6.0, 0)
	card.posted.connect(_on_results_post)
	card.skipped.connect(_on_results_skip)
	holder.add_child(card)
	hud_layer.add_child(holder)
	card.build()
	post_card = holder
	redraw_all()


func _on_results_post(tone: String) -> void:
	var before: int = GameData.Social.followers()
	GameData.Social.publish(tone)
	var d: int = GameData.Social.followers() - before
	result["posted"] = tr("Posted on BotMedia. Followers %s%d.") % ["+" if d >= 0 else "", d]
	Sfx.play("click")
	GameData.save_game()
	_close_post_card()


func _on_results_skip() -> void:
	GameData.Social.st()["draft"] = {}
	result["posted"] = tr("You kept quiet on BotMedia.")
	Sfx.play("click")
	GameData.save_game()
	_close_post_card()


func _close_post_card() -> void:
	if post_card != null and is_instance_valid(post_card):
		post_card.queue_free()
	post_card = null
	redraw_all()



# ---------------------------------------------------------------- live betting (1.73)
# While you watch, a bar along the bottom takes bets. The odds move every second with the fight
# (core left, parts still on, power in the tank) from the bookies' pre-fight price; a bet keeps
# the price it was placed at. Bets close in the last 10 seconds and during a big moment. They're
# paid at the bell; a long-odds win leaves a GLOAT post waiting on BotMedia.

const LIVE_EDGE := 0.92        # the house keeps 8%
const LIVE_SWING := 5.0        # how hard the fight moves the price
const LIVE_CLOSE := 10.0       # seconds left on the clock when bets close


func live_strength(f: Fighter) -> float:
	var core := 0.0
	var on := 0
	var total := 0
	for slot in f.parts:
		var pt: Dictionary = f.parts[slot]
		if pt.is_empty():
			continue
		total += 1
		if float(pt.get("hp", 0.0)) > 0.0:
			on += 1
		if slot == "torso":
			core = clampf(float(pt["hp"]) / maxf(1.0, float(pt["max_hp"])), 0.0, 1.0)
	return core * 0.6 + float(on) / maxf(1.0, total) * 0.25 + clampf(f.power / maxf(1.0, f.power_max), 0.0, 1.0) * 0.15


func live_closed() -> bool:
	return phase != "fight" or time_left < LIVE_CLOSE or moment_t > 0.0


func update_live_bets(delta: float) -> void:
	if live_bar == null:
		if phase != "fight":
			return
		setup_live_bets()
	live_bar.visible = phase == "fight" and not paused
	live_t -= delta
	if live_t > 0.0:
		return
	live_t = 1.0
	var a: Fighter = team_p[0]
	var b: Fighter = team_c[0]
	var lp0 := log(live_p0 / (1.0 - live_p0))
	var p := 1.0 / (1.0 + exp(-(lp0 + LIVE_SWING * (live_strength(a) - live_strength(b)))))
	p = clampf(p, 0.03, 0.97)
	live_odds = [snappedf(maxf(1.05, LIVE_EDGE / p), 0.05), snappedf(maxf(1.05, LIVE_EDGE / (1.0 - p)), 0.05)]
	var closed := live_closed()
	var stake: int = GameData.stakes()[live_stake_i]
	for k in 2:
		var btn: Button = live_btns[k]
		var f: Fighter = a if k == 0 else b
		btn.text = (tr("BETS CLOSED") if closed else tr("$%d on %s · %.2fx") % [stake, (f.pilot_name if f.pilot_name != "" else f.label), live_odds[k]])
		btn.disabled = closed or GameData.money < stake
	var mine: Array = []
	for bt in live_bets:
		var f2: Fighter = a if int(bt["side"]) == 0 else b
		mine.append(tr("$%d on %s at %.2fx") % [int(bt["stake"]), (f2.pilot_name if f2.pilot_name != "" else f2.label), float(bt["odds"])])
	live_info.text = (tr("Your bets: %s") % ", ".join(mine)) if not mine.is_empty() else tr("LIVE ODDS · tap a robot to back it at today's price")


func setup_live_bets() -> void:
	var ev: Dictionary = GameData.watch_event()
	if not ev.is_empty():
		var oa: float = GameData.Career.odds(ev, int(GameData.watching["a"]), int(GameData.watching["b"]))
		var ob: float = GameData.Career.odds(ev, int(GameData.watching["b"]), int(GameData.watching["a"]))
		live_p0 = clampf((1.0 / oa) / ((1.0 / oa) + (1.0 / ob)), 0.05, 0.95)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GUI.box(Color(0.05, 0.05, 0.07, 0.82), 10, 6))
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -UIK.tsz(13) * 2.0 - 58.0
	panel.offset_bottom = -6.0
	hud_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	live_info = GUI.text("", 12, GUI.AMBER)
	live_info.clip_text = true
	live_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(live_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var sb := UIK.button("", func(): pass, 13, Vector2(96, 40))
	sb.text = "$%d" % GameData.stakes()[live_stake_i]
	sb.pressed.connect(func():
		live_stake_i = (live_stake_i + 1) % GameData.stakes().size()
		sb.text = "$%d" % GameData.stakes()[live_stake_i]
		live_t = 0.0)
	row.add_child(sb)
	live_btns = []
	for k in 2:
		var b := UIK.button("", _on_live_bet.bind(k), 13, Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
		live_btns.append(b)
	live_bar = panel
	live_t = 0.0


func _on_live_bet(side: int) -> void:
	if live_closed():
		return
	var stake: int = GameData.stakes()[live_stake_i]
	if GameData.money < stake:
		return
	GameData.money -= stake
	live_bets.append({"side": side, "stake": stake, "odds": live_odds[side]})
	Sfx.play("buy", 0.05)
	live_t = 0.0


## At the bell: winning bets pay their own price. A big payday (4 to 1 or longer, or more than a
## week of running costs) leaves a GLOAT option on the post waiting on BotMedia.
func settle_live_bets() -> void:
	if live_bets.is_empty():
		return
	var out := {"lines": [], "paid": 0, "staked": 0}
	var big := false
	var a: Fighter = team_p[0]
	var b: Fighter = team_c[0]
	for bt in live_bets:
		var f: Fighter = a if int(bt["side"]) == 0 else b
		var name := f.pilot_name if f.pilot_name != "" else f.label
		out["staked"] += int(bt["stake"])
		if (int(bt["side"]) == 0) == won:
			var pay := int(int(bt["stake"]) * float(bt["odds"]))
			GameData.money += pay
			out["paid"] += pay
			out["lines"].append(tr("Live bet on %s at %.2fx: +$%d") % [name, float(bt["odds"]), pay])
			if float(bt["odds"]) >= 4.0 or pay >= GameData.living_cost() / 4:
				big = true
		else:
			out["lines"].append(tr("Live bet on %s: lost $%d") % [name, int(bt["stake"])])
	live_bets = []
	result["live"] = out
	if big and not GameData.Social.st()["draft"].is_empty():
		GameData.Social.st()["draft"]["gloat"] = true
	if live_bar:
		live_bar.visible = false
	GameData.save_game()
