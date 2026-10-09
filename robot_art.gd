extends RefCounted
## Draws robots out of simple shapes. Every part (head, torso, 2 arms, 2 legs) has its own
## shape, size, color and health, so robots look different and show their damage.
##
## look: {"parts": {slot: {"alive", "shape", "size", "color", "health"}}, "trim", "eye", "scale"}
## pose (all optional): facing, state, extended, attack_limb, swing, crouch, blocking, flash, rot, scale
##
## Local coordinates: origin = between the feet on the floor, +x = the way the robot faces, -y = up.

const Logos = preload("res://logos.gd")
const Light = preload("res://light.gd")

## Diagnostic Noir (1.50, see the Art Study): every plate gets two tones (the paint, and a shadow face away
## from the light), one dark outline, a light edge where the key light hits and a rim on the far side.
## classic = the old flat look (Settings > Classic look, only while the restyle is under way).
static var classic := false
static var _L: Dictionary = {}       # the light set the robot being drawn stands in
static var _from := -0.55            # where the key light comes from, in the part's own coordinates
static var _flash := false           # hit flash: plain white, no shading
static var _grade := 3               # the grade of the part being drawn (its finish)
const OUTLINE := Color(0.035, 0.035, 0.045)
## How strong the light edge is by grade: scrap and rust are dull, steel and titanium catch the light.
const GRADE_EDGE := [0.35, 0.45, 0.6, 0.8, 1.0, 1.0]

# [length, thickness] at size 1.0
# (1.52: limbs a few pixels thicker so a sponsor's sticker fits on the hip and shoulder)
const LEGS := {"rod": [60.0, 14.0], "piston": [62.0, 18.0], "spring": [66.0, 13.0],
		"reverse": [70.0, 16.0], "pillar": [48.0, 27.0], "thick": [56.0, 23.0],
		"pogo": [68.0, 13.0], "wheel": [58.0, 16.0], "tread": [52.0, 25.0],
		"blade": [64.0, 12.0], "hover": [50.0, 18.0], "spider": [62.0, 13.0],
		"stomper": [56.0, 22.0], "pipe": [62.0, 14.0], "bellows": [60.0, 17.0], "tripod": [64.0, 13.0],
		"excavator": [50.0, 22.0], "hydraulic": [64.0, 17.0], "hotrod": [66.0, 13.0], "maglev": [58.0, 15.0],
		"gear": [62.0, 13.0], "ductfan": [56.0, 14.0]}
# [width, height]
const TORSOS := {"barrel": [60.0, 70.0], "box": [56.0, 76.0], "vee": [70.0, 78.0],
		"core": [60.0, 76.0], "tank": [84.0, 82.0], "slim": [42.0, 82.0],
		"ribcage": [54.0, 74.0], "hex": [70.0, 80.0], "cannon": [66.0, 78.0],
		"crate": [62.0, 66.0], "furnace": [64.0, 78.0], "orb": [70.0, 70.0],
		"yoke": [82.0, 74.0], "quad": [74.0, 84.0], "monster": [92.0, 90.0],
		"engine": [74.0, 74.0], "loco": [70.0, 80.0], "drum": [58.0, 72.0], "boiler": [62.0, 80.0], "clockwork": [62.0, 76.0],
		"fueltank": [62.0, 78.0], "hull": [78.0, 80.0], "coupe": [58.0, 74.0], "dynamo": [62.0, 76.0], "twincoil": [80.0, 72.0],
		"fuselage": [54.0, 80.0], "cryopod": [60.0, 76.0], "biplane": [78.0, 78.0]}
const HEADS := {"bucket": [34.0, 32.0], "box": [38.0, 34.0], "dome": [42.0, 34.0], "cyclops": [40.0, 40.0],
		"visor": [48.0, 28.0], "horned": [40.0, 34.0], "skull": [40.0, 42.0], "wedge": [44.0, 30.0],
		"tall": [26.0, 52.0], "bulb": [44.0, 44.0], "tv": [46.0, 36.0], "dish": [40.0, 34.0], "laser": [38.0, 34.0],
		"knight": [40.0, 42.0], "orb": [38.0, 38.0], "speaker": [44.0, 38.0],
		"rivet": [38.0, 36.0], "grille": [50.0, 38.0], "peeper": [34.0, 32.0], "busted": [46.0, 36.0],
		"periscope": [36.0, 34.0], "divingbell": [44.0, 42.0], "welder": [40.0, 40.0], "beacon": [36.0, 30.0],
		"tesla": [34.0, 30.0], "racer": [42.0, 36.0], "canopy": [42.0, 34.0], "radarnose": [44.0, 30.0]}
const PUNCH_LEN := 84.0   # how far a punching hand reaches from the lead shoulder

# [thickness, fist radius]
const ARMS := {"rod": [12.0, 10.0], "piston": [15.0, 12.0], "claw": [14.0, 7.0], "spike": [15.0, 12.0],
		"bulky": [20.0, 16.0], "hammer": [16.0, 7.0], "drill": [15.0, 7.0],
		"rocket": [16.0, 14.0], "grapple": [14.0, 7.0], "saw": [14.0, 7.0],
		"blade": [13.0, 7.0], "flame": [16.0, 7.0], "magnet": [15.0, 7.0],
		"anvil": [18.0, 9.0], "crane": [13.0, 7.0], "wrench": [12.0, 7.0], "grabber": [11.0, 6.0],
		"gauntlet": [15.0, 13.0], "riveter": [12.0, 7.0], "wrecker": [15.0, 13.0], "torch": [13.0, 7.0], "arcfist": [14.0, 13.0], "magclamp": [12.0, 7.0],
		"wingblade": [12.0, 7.0], "turbine": [14.0, 13.0]}


## (1.93) Normal hits by limb, techniques included, and the arm poses that reach as far as a punch
## (the rear hand crosses over and the shoulder turns into them).
const ARM_HITS := ["punch", "low_punch", "uppercut", "hook", "overhand", "shove", "elbow"]
const LEG_HITS := ["kick", "sweep", "high_kick", "push_kick", "roundhouse", "axe_kick", "knee"]
const REACH_POSES := ["punch", "low_punch", "uppercut", "hammer", "overhand", "shove"]


## (1.93) Where a leg's hip is in a pose: a rear leg that kicks turns the hips, so its hip comes
## through to the front (the body pivots on the planted lead foot, like a real rear kick).
static func kick_hip(look: Dictionary, g: Dictionary, slot: String, pose: String) -> Vector2:
	var hip: Vector2 = g["hip_front"] if slot == "leg_front" else g["hip_back"]
	if LEG_HITS.has(pose) and pose != "sweep" and is_rear(look, slot):
		var other: Vector2 = g["hip_back"] if slot == "leg_front" else g["hip_front"]
		return Vector2(maxf(hip.x, other.x) + 6.0, hip.y)
	return hip


static func _part(look: Dictionary, slot: String) -> Dictionary:
	return look["parts"].get(slot, {"alive": false})


static func _alive(look: Dictionary, slot: String) -> bool:
	return _part(look, slot).get("alive", false)


## Body measurements for a look (unscaled, standing).
static func geom(look: Dictionary) -> Dictionary:
	var L := 0.0
	for slot in ["leg_front", "leg_back"]:
		var p := _part(look, slot)
		if p.get("alive", false):
			L = maxf(L, LEGS.get(p["shape"], LEGS["rod"])[0] * p["size"])
	if L == 0.0:
		L = 6.0   # no legs: the torso sits on the floor
	var t := _part(look, "torso")
	var ts: Array = TORSOS.get(t.get("shape", "box"), TORSOS["box"])
	var tsz: float = t.get("size", 1.0)
	var tw: float = ts[0] * tsz
	var th: float = ts[1] * tsz
	var top := -L - th
	var h := _part(look, "head")
	var hs: Array = HEADS.get(h.get("shape", "box"), HEADS["box"])
	var hsz: float = h.get("size", 1.0)
	var hw: float = hs[0] * hsz
	var hh: float = hs[1] * hsz
	var two_heads: bool = _alive(look, "head2") or look["parts"].get("head2", {}).has("shape")
	var hx := tw * 0.16 if two_heads else 0.0
	var head := Rect2(-hw * 0.5 + 2.0 + hx, top - 6.0 - hh, hw, hh)
	var h2 := _part(look, "head2")
	var hs2: Array = HEADS.get(h2.get("shape", "box"), HEADS["box"])
	var hw2: float = hs2[0] * h2.get("size", 1.0)
	var hh2: float = hs2[1] * h2.get("size", 1.0)
	var head2 := Rect2(-tw * 0.22 - hw2 * 0.5, top - 4.0 - hh2, hw2, hh2)
	# limbs spread wide so each one is easy to see and tap
	var sf := Vector2(tw * 0.22, top + 12.0)
	var sb := Vector2(-tw * 0.5 - 4.0, top + 12.0)
	var hf := Vector2(tw * 0.26, -L)
	var hb := Vector2(-tw * 0.3, -L)
	var sf2 := Vector2(tw * 0.3, top + th * 0.55)
	var sb2 := Vector2(-tw * 0.5 - 8.0, top + th * 0.55)
	if look.get("swap", false):
		# switched stance: the right side (_back slots) leads, the left side (_front slots) is behind
		var t1 := sf
		sf = sb
		sb = t1
		var t2 := hf
		hf = hb
		hb = t2
		var t3 := sf2
		sf2 = sb2
		sb2 = t3
	return {
		"L": L, "tw": tw, "th": th, "top": top,
		"torso": Rect2(-tw * 0.5, top, tw, th), "head": head, "head2": head2,
		"shoulder_front": sf, "shoulder_back": sb, "hip_front": hf, "hip_back": hb,
		"shoulder_front2": sf2, "shoulder_back2": sb2,
	}


## Is this limb on the side away from the enemy right now? (normally the _back slots; switched
## stance (look "swap") turns it round.)
static func is_rear(look: Dictionary, slot: String) -> bool:
	var b := slot.begins_with("arm_back") or slot == "leg_back"
	return b != bool(look.get("swap", false))


## Rectangles (local, standing) used for tapping/aiming at parts. Order = tap priority.
static func regions(look: Dictionary) -> Array:
	var g := geom(look)
	var out: Array = []
	if _alive(look, "head"):
		out.append(["head", (g["head"] as Rect2).grow(6.0)])
	if _alive(look, "head2"):
		out.append(["head2", (g["head2"] as Rect2).grow(6.0)])
	# lead limbs reach forward, rear ones hang behind (a switched stance swaps which is which)
	for slot in ["arm_front", "arm_front2", "leg_front", "leg_back", "arm_back", "arm_back2"]:
		if not _alive(look, slot):
			continue
		var rear := is_rear(look, slot)
		if slot.begins_with("leg"):
			var hp: Vector2 = g["hip_front"] if slot == "leg_front" else g["hip_back"]
			out.append([slot, Rect2(hp.x - (26.0 if rear else 14.0), hp.y, 36.0 if rear else 38.0, g["L"])])
		else:
			var sp := shoulder_of(g, slot)
			var low: bool = slot.ends_with("2")
			if rear:
				out.append([slot, Rect2(sp.x - 34.0, sp.y - (10.0 if low else 12.0), 40.0, 52.0 if low else 56.0)])
			else:
				out.append([slot, Rect2(sp.x - 6.0, sp.y - (10.0 if low else 14.0), 62.0 if low else 66.0, 44.0 if low else 50.0)])
	if _alive(look, "torso"):
		out.append(["torso", g["torso"]])
	return out


## Center of a part in local coords (for the crosshair).
static func part_center(look: Dictionary, slot: String) -> Vector2:
	for r in regions(look):
		if r[0] == slot:
			return (r[1] as Rect2).get_center()
	return (geom(look)["torso"] as Rect2).get_center()


# ---------------------------------------------------------------- poses and hit shapes

## Which pose every arm and leg is in, for a pose dictionary (see draw).
static func limb_poses(look: Dictionary, pose: Dictionary) -> Dictionary:
	var state: String = pose.get("state", "idle")
	var extended: bool = pose.get("extended", false)
	var limb: String = pose.get("attack_limb", "")
	var blocking: bool = pose.get("blocking", false)
	var arm_pose := {"arm_front": "guard", "arm_back": "guard", "arm_front2": "guard", "arm_back2": "guard"}
	var leg_pose := {"leg_front": "stand", "leg_back": "stand"}
	if pose.get("dazed", false):
		# guard smashed open: arms flung up and out
		arm_pose = {"arm_front": "flung", "arm_back": "flung", "arm_front2": "flung", "arm_back2": "flung"}
	elif state == "hit" or state == "ko" or state == "down":
		arm_pose = {"arm_front": "limp", "arm_back": "limp", "arm_front2": "limp", "arm_back2": "limp"}
	elif state == "hammer":
		# both fists together: raised overhead, then smashed down in front
		var hp := "hammer" if extended else "hammer_up"
		arm_pose = {"arm_front": hp, "arm_back": hp, "arm_front2": hp, "arm_back2": hp}
	elif blocking:
		arm_pose = {"arm_front": "block", "arm_back": "block", "arm_front2": "block", "arm_back2": "block"}
	if extended and limb != "":
		if ARM_HITS.has(state) and limb.begins_with("arm"):
			arm_pose[limb] = state
		elif LEG_HITS.has(state) and limb.begins_with("leg"):
			leg_pose[limb] = state
	elif state == "charge" and limb != "" and limb.begins_with("arm"):
		arm_pose[limb] = "charge"   # winding up a charged hit: the arm drawn back
	if state == "fly_kick":
		# both legs together, pointing down and forward
		leg_pose = {"leg_front": "fly_kick", "leg_back": "fly_kick"}
	elif pose.get("tuck", false):
		leg_pose = {"leg_front": "tuck", "leg_back": "tuck"}
	# crawling with no legs: the arms that are left claw at the floor in turn and drag the robot
	var crawl: float = pose.get("crawl", -1.0)
	if crawl >= 0.0:
		var clawing: Array = []
		for k in ["arm_front", "arm_back", "arm_front2", "arm_back2"]:
			if _alive(look, k) and not pose.get("fist_out", []).has(k):
				clawing.append(k)
		for i in clawing.size():
			arm_pose[clawing[i]] = "claw:%f" % fmod(crawl + float(i) / clawing.size(), 1.0)
	return {"arms": arm_pose, "legs": leg_pose}


## What a hit has to touch, in local coordinates, for the robot as it's drawn in a pose: the head(s)
## and torso as boxes, every arm and leg as a chain of capsules along the drawn limb.
## [[slot, "rect", Rect2] or [slot, "cap", a, b, radius], ...]
static func hit_shapes(look: Dictionary, pose: Dictionary) -> Array:
	var g := geom(look)
	var lp := limb_poses(look, pose)
	var limb: String = pose.get("attack_limb", "")
	var aim: float = pose.get("aim", 0.0)
	var out: Array = []
	for hs in ["head", "head2"]:
		if _alive(look, hs):
			out.append([hs, "rect", g[hs]])
	for slot in ["arm_front", "arm_back", "arm_front2", "arm_back2"]:
		if not _alive(look, slot):
			continue
		var p := _part(look, slot)
		var dims: Array = ARMS.get(p.get("shape", "rod"), ARMS["rod"])
		var sz: float = p.get("size", 1.0)
		var s := shoulder_of(g, slot)
		var ap: String = lp["arms"][slot]
		var pts := arm_pose_points(s, ap, is_rear(look, slot), punch_reach_x(g) if REACH_POSES.has(ap) else 0.0, aim if slot == limb else 0.0, Vector2.ZERO, arm_len_of(look, slot))
		out.append([slot, "cap", pts[2], pts[0], dims[0] * sz * 0.55])
		out.append([slot, "cap", pts[0], pts[1], maxf(dims[0] * sz * 0.5, dims[1] * sz)])
	for slot in ["leg_front", "leg_back"]:
		if not _alive(look, slot):
			continue
		var p2 := _part(look, slot)
		var ld: Array = LEGS.get(p2.get("shape", "rod"), LEGS["rod"])
		var hip := kick_hip(look, g, slot, lp["legs"][slot])
		var foot := leg_pose_foot(hip, lp["legs"][slot], 0.0, aim if slot == limb else 0.0, leg_len_of(look, slot), float(pose.get("drop", 0.0)))
		out.append([slot, "cap", hip, foot, maxf(8.0, ld[1] * float(p2.get("size", 1.0)) * 0.6)])
	if _alive(look, "torso"):
		out.append(["torso", "rect", g["torso"]])
	return out


## Distance from a point to a segment.
static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------- drawing

static func draw(ci: CanvasItem, base: Vector2, look: Dictionary, pose: Dictionary = {}) -> void:
	var facing: int = pose.get("facing", 1)
	var state: String = pose.get("state", "idle")
	var extended: bool = pose.get("extended", false)
	var limb: String = pose.get("attack_limb", "")
	var swing: float = pose.get("swing", 0.0)
	var crouch: bool = pose.get("crouch", false)
	var blocking: bool = pose.get("blocking", false)
	var flash: bool = pose.get("flash", false)
	var rot: float = pose.get("rot", 0.0)
	var sc: float = pose.get("scale", 1.0) * look.get("scale", 1.0)
	var t: float = pose.get("time", 0.0)

	var sx: float = pose.get("sx", 1.0)
	var sy: float = pose.get("sy", 1.0)
	ci.draw_set_transform(base, rot, Vector2(facing * sc * sx, (0.7 if crouch else 1.0) * sc * sy))
	_set_light(str(pose.get("light", "neutral" if look.get("icon", false) else "fight")), float(facing))
	_flash = flash
	var g := geom(look)
	var trim: Color = Color.WHITE if flash else look["trim"]
	var eye: Color = look["eye"] if not pose.get("eye_off", false) else Color(0.12, 0.1, 0.1)

	# --- arm and leg poses
	var lp := limb_poses(look, pose)
	var arm_pose: Dictionary = lp["arms"]
	var leg_pose: Dictionary = lp["legs"]
	var aim: float = pose.get("aim", 0.0)

	var fist_out: Array = pose.get("fist_out", [])
	if pose.get("overcharge", false):
		var pulse := 0.5 + 0.5 * sin(t * 14.0)
		ci.draw_circle(Vector2(0, -(g["L"] + g["th"]) * 0.6), (g["L"] + g["th"]) * 0.75, Color(1.0, 0.15, 0.35, 0.12 + 0.1 * pulse))

	# back gear, rear arm, rear leg, torso, lead leg, head, lead arm (switched stance swaps the sides)
	var sw: bool = look.get("swap", false)
	var ra := "arm_front" if sw else "arm_back"
	var ra2 := "arm_front2" if sw else "arm_back2"
	var la := "arm_back" if sw else "arm_front"
	var la2 := "arm_back2" if sw else "arm_front2"
	var rl := "leg_front" if sw else "leg_back"
	var ll := "leg_back" if sw else "leg_front"
	var bob_l: Vector2 = pose.get("bob_l", Vector2.ZERO)   # lead fist
	var bob_r: Vector2 = pose.get("bob_r", Vector2.ZERO)   # rear fist (out of step with the lead one)
	_draw_back(ci, look, g, pose, flash, trim, t)
	if look["parts"].has(ra2) and look["parts"][ra2].has("shape"):   # (a reactor pod has shape "pod")
		_draw_arm(ci, look, ra2, shoulder_of(g, ra2), arm_pose[ra2], true, flash, trim, t, fist_out.has(ra2), aim if limb == ra2 else 0.0, bob_r)
	_draw_arm(ci, look, ra, shoulder_of(g, ra), arm_pose[ra], true, flash, trim, t, fist_out.has(ra), aim if limb == ra else 0.0, bob_r)
	var drop: float = pose.get("drop", 0.0)   # a sweep sinks the body; the standing leg bends to stay on the floor
	# (1.93) a rear leg that kicks swings through in front of the body, so it's seen (a high kick or an
	# axe kick would otherwise vanish behind the torso)
	var rear_kick: bool = limb == rl and LEG_HITS.has(str(leg_pose[rl]))
	if not rear_kick:
		_draw_leg(ci, look, rl, g["hip_back"], g["L"], leg_pose[rl], -swing, true, flash, trim, aim if limb == rl else 0.0, drop)
	_draw_torso(ci, look, g, flash, trim, eye, t)
	_sticker(ci, look, rl, g["hip_back"] + Vector2(0, 14), 7.0)
	_sticker(ci, look, "torso", (g["torso"] as Rect2).get_center() + Vector2(0, g["th"] * 0.14), minf(g["tw"], g["th"]) * 0.2)
	_draw_leg(ci, look, ll, g["hip_front"], g["L"], leg_pose[ll], swing, false, flash, trim, aim if limb == ll else 0.0, drop)
	_sticker(ci, look, ll, g["hip_front"] + Vector2(0, 14), 8.0)
	if rear_kick:
		_draw_leg(ci, look, rl, kick_hip(look, g, rl, str(leg_pose[rl])), g["L"], leg_pose[rl], -swing, true, flash, trim, aim, drop)
	# the head pans a little while it waits (pose "head_dx")
	var gh := g
	var hdx: float = pose.get("head_dx", 0.0)
	if hdx != 0.0:
		gh = g.duplicate()
		gh["head"] = (g["head"] as Rect2).grow_individual(-hdx, 0, hdx, 0)
		gh["head2"] = (g["head2"] as Rect2).grow_individual(-hdx, 0, hdx, 0)
	if look["parts"].has("head2") and look["parts"]["head2"].has("shape"):
		_draw_head(ci, look, gh, flash, trim, eye, t, "head2")
	_draw_head(ci, look, gh, flash, trim, eye, t, "head")
	_sticker(ci, look, "head", (gh["head"] as Rect2).get_center() + Vector2(0, (gh["head"] as Rect2).size.y * 0.22), minf((gh["head"] as Rect2).size.x, (gh["head"] as Rect2).size.y) * 0.2)
	if look["parts"].has(la2) and look["parts"][la2].has("shape"):
		_draw_arm(ci, look, la2, shoulder_of(g, la2), arm_pose[la2], false, flash, trim, t, fist_out.has(la2), aim if limb == la2 else 0.0, bob_l)
	_draw_arm(ci, look, la, shoulder_of(g, la), arm_pose[la], false, flash, trim, t, fist_out.has(la), aim if limb == la else 0.0, bob_l)
	_sticker(ci, look, la, shoulder_of(g, la), 8.0)

	if pose.get("shield", false):
		var c := Vector2(0, -(g["L"] + g["th"] + 40.0) * 0.55)
		var r: float = (g["L"] + g["th"] + 50.0) * 0.62
		ci.draw_circle(c, r, Color(0.3, 0.7, 1.0, 0.18 + 0.06 * sin(t * 10.0)))
		ci.draw_arc(c, r, 0, TAU, 40, Color(0.5, 0.85, 1.0, 0.8), 3.0)
	if pose.get("stunned", false):
		for k in 3:
			var a := t * 6.0 + k * TAU / 3.0
			ci.draw_circle(Vector2(cos(a) * 26.0, (g["head"] as Rect2).position.y - 12.0 + sin(a) * 6.0), 4.0, Color(0.6, 0.8, 1.0))

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- front view (the bay's gantry)

## Body measurements seen from the front: torso in the middle, the left arm/leg (the _front slots)
## on the left of the picture, the right ones on the right. Shoulder/hip points are for the right
## side; the left side is the same point mirrored.
static func front_geom(look: Dictionary) -> Dictionary:
	var g := geom(look)
	var tw: float = g["tw"]
	var top: float = g["top"]
	var th: float = g["th"]
	var head: Rect2 = g["head"]
	var head2: Rect2 = g["head2"]
	var two_heads: bool = _alive(look, "head2") or look["parts"].get("head2", {}).has("shape")
	head.position.x = (tw * 0.2 if two_heads else 0.0) - head.size.x * 0.5
	head2.position.x = -tw * 0.2 - head2.size.x * 0.5
	g["head"] = head
	g["head2"] = head2
	g["shoulder"] = Vector2(tw * 0.5 + 3.0, top + 12.0)
	g["shoulder2"] = Vector2(tw * 0.5 + 5.0, top + th * 0.55)
	g["hip"] = Vector2(maxf(tw * 0.3, 16.0), -g["L"])
	return g


## The robot facing you, arms hanging open (the bay, hanging on Gus's gantry).
static func draw_front(ci: CanvasItem, base: Vector2, look: Dictionary, pose: Dictionary = {}) -> void:
	var sc: float = pose.get("scale", 1.0) * look.get("scale", 1.0)
	var t: float = pose.get("time", 0.0)
	var g := front_geom(look)
	var trim: Color = look["trim"]
	var eye: Color = look["eye"]
	var right := Transform2D(0.0, Vector2(sc, sc), 0.0, base)
	var left := right * Transform2D(0.0, Vector2(-1.0, 1.0), 0.0, Vector2.ZERO)
	_set_light(str(pose.get("light", "neutral")), 1.0)
	_flash = false
	var lf := _from   # the left side is drawn mirrored, so its light comes from the other way
	ci.draw_set_transform_matrix(right)
	_draw_back(ci, look, g, pose, false, trim, t)   # back gear peeks out from behind
	ci.draw_set_transform_matrix(left)
	_from = -lf
	_front_legs = true
	_draw_leg(ci, look, "leg_front", g["hip"], g["L"], "stand", 0.0, false, false, trim)
	_sticker(ci, look, "leg_front", g["hip"] + Vector2(0, 16), 8.0)
	ci.draw_set_transform_matrix(right)
	_from = lf
	_draw_leg(ci, look, "leg_back", g["hip"], g["L"], "stand", 0.0, false, false, trim)
	_front_legs = false
	_sticker(ci, look, "leg_back", g["hip"] + Vector2(0, 16), 8.0)
	_draw_torso(ci, look, g, false, trim, eye, t, true)
	_sticker(ci, look, "torso", (g["torso"] as Rect2).get_center() + Vector2(0, g["th"] * 0.14), minf(g["tw"], g["th"]) * 0.2)
	for side in [["arm_front", left], ["arm_back", right]]:
		ci.draw_set_transform_matrix(side[1])
		_from = -lf if side[0] == "arm_front" else lf
		if look["parts"].has(side[0] + "2") and look["parts"][side[0] + "2"].has("shape"):
			_draw_arm(ci, look, side[0] + "2", g["shoulder2"], "open", false, false, trim, t)
		_draw_arm(ci, look, side[0], g["shoulder"], "open", false, false, trim, t)
		_sticker(ci, look, side[0], g["shoulder"] + Vector2(4, 4), 8.0)
	ci.draw_set_transform_matrix(right)
	_from = lf
	if look["parts"].has("head2") and look["parts"]["head2"].has("shape"):
		_draw_head(ci, look, g, false, trim, eye, t, "head2", true)
	_draw_head(ci, look, g, false, trim, eye, t, "head", true)
	_sticker(ci, look, "head", (g["head"] as Rect2).get_center() + Vector2(0, (g["head"] as Rect2).size.y * 0.22), minf((g["head"] as Rect2).size.x, (g["head"] as Rect2).size.y) * 0.2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A sponsor's sticker on a part (look "stickers": {slot: sponsor id}), only while the part is on.
static func _sticker(ci: CanvasItem, look: Dictionary, slot: String, at: Vector2, r: float) -> void:
	var st: Dictionary = look.get("stickers", {})
	if st.is_empty() or not st.has(slot) or not _alive(look, slot):
		return
	Logos.draw_logo(ci, str(st[slot]), at, maxf(5.0, r), true)


## Tap boxes for the front view (local coordinates, standing). Order = tap priority.
static func front_regions(look: Dictionary) -> Array:
	var g := front_geom(look)
	var sh: Vector2 = g["shoulder"]
	var sh2: Vector2 = g["shoulder2"]
	var hip: Vector2 = g["hip"]
	var L: float = g["L"]
	var out: Array = []
	for k in ["head", "head2"]:
		if _alive(look, k):
			out.append([k, (g[k] as Rect2).grow(6.0)])
	var arm := Rect2(sh.x - 8.0, sh.y - 12.0, 50.0, 80.0)
	var arm2 := Rect2(sh2.x - 8.0, sh2.y - 10.0, 48.0, 76.0)
	var leg := Rect2(hip.x - 13.0, hip.y, 26.0, L)
	for pair in [["arm_back", arm], ["arm_back2", arm2], ["leg_back", leg]]:
		if _alive(look, pair[0]):
			out.append([pair[0], pair[1]])
		var lslot: String = str(pair[0]).replace("_back", "_front")
		if _alive(look, lslot):
			var r: Rect2 = pair[1]
			out.append([lslot, Rect2(-r.end.x, r.position.y, r.size.x, r.size.y)])
	if _alive(look, "torso"):
		out.append(["torso", g["torso"]])
	return out


static func _col(p: Dictionary, flash: bool, back: bool) -> Color:
	if flash:
		return Color.WHITE
	var c: Color = p["color"]
	var hp: float = p.get("health", 1.0)
	c = c.lerp(Color(0.12, 0.1, 0.09), (1.0 - hp) * 0.45)   # scorched as it gets damaged
	return c.darkened(0.35) if back else c


## (1.66) Damage on an arm or leg: a dent, then a jagged crack across the limb with a lit lip,
## then a split that glows from the wiring inside.
# ---- (1.90) maker finishes: each maker's surface details on top of the paint (study: Parts & Makers)

## On a torso (torso = true) or a head: bolts, trim, gauges, stripes, seams, by the part's maker.
static func _finish_plate(ci: CanvasItem, r: Rect2, p: Dictionary, t: float, torso: bool) -> void:
	var m := str(p.get("maker", ""))
	if m == "" or classic or r.size.x < 12.0:
		return
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	match m:
		"scrapworks":
			# a strip of tape across it and one odd bolt
			var y := o.y + h * (0.62 if torso else 0.3)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(o.x + w * 0.08, y - 3), Vector2(o.x + w * 0.62, y - 6), Vector2(o.x + w * 0.64, y + 1), Vector2(o.x + w * 0.1, y + 4)]), Color(0.82, 0.74, 0.5, 0.85))
			ci.draw_circle(o + Vector2(w * 0.82, h * 0.2), 2.4, Color(0.55, 0.5, 0.42))
		"oldiron":
			# big hex bolts at the corners
			for cpt in [o + Vector2(5, 5), o + Vector2(w - 5, 5), o + Vector2(5, h - 5), o + Vector2(w - 5, h - 5)]:
				_hexbolt(ci, cpt, 3.2 if torso else 2.4)
			if torso:
				ci.draw_rect(Rect2(o.x + w * 0.12, o.y + h * 0.78, w * 0.3, 3.0), Color(0.95, 0.92, 0.82, 0.55))   # a painted stripe
		"brassworks":
			var brass := Color(0.86, 0.68, 0.25)
			ci.draw_rect(Rect2(o.x + 2, o.y + 2, w - 4, 3.0), brass)
			if torso:
				# a pressure gauge with a needle that wanders
				var gc := o + Vector2(w * 0.74, h * 0.66)
				var gr := minf(w, h) * 0.11
				ci.draw_circle(gc, gr + 1.5, brass.darkened(0.3))
				ci.draw_circle(gc, gr, Color(0.95, 0.9, 0.78))
				var na := -2.4 + 1.6 * (0.5 + 0.5 * sin(t * 1.3))
				ci.draw_line(gc, gc + Vector2(cos(na), sin(na)) * gr * 0.85, Color(0.6, 0.12, 0.08), 1.4)
				ci.draw_line(Vector2(o.x + w * 0.1, o.y + h * 0.9), Vector2(o.x + w * 0.5, o.y + h * 0.9), brass.darkened(0.15), 3.0)   # a pipe run
			else:
				ci.draw_arc(o + Vector2(w * 0.5, h * 0.5), minf(w, h) * 0.46, PI * 0.15, PI * 0.85, 10, brass, 2.0)
		"hellfire":
			# a band of hazard stripes along the bottom
			var bh := 6.0 if torso else 4.0
			var y0 := o.y + h - bh - 3.0
			ci.draw_rect(Rect2(o.x + 3, y0, w - 6, bh), Color(0.95, 0.78, 0.1))
			var x := o.x + 3.0
			while x < o.x + w - 6.0:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y0 + bh), Vector2(x + 3.0, y0 + bh), Vector2(minf(x + 3.0 + bh, o.x + w - 3), y0), Vector2(minf(x + bh, o.x + w - 3), y0)]), Color(0.1, 0.1, 0.1))
				x += 7.0
		"volta":
			# neon tube edges, flickering a little
			var na := 0.75 + 0.25 * sin(t * 17.0 + w)
			ci.draw_line(o + Vector2(3, h * 0.25), o + Vector2(3, h - 4), Color(0.0, 0.8, 1.0, na), 2.0)
			ci.draw_line(o + Vector2(3, h - 4), o + Vector2(w * 0.55, h - 4), Color(1.0, 0.3, 0.75, na), 2.0)
			if torso:
				ci.draw_rect(Rect2(o.x + w * 0.42, o.y + 3, 4.0, h - 8), Color(0.92, 0.95, 1.0, 0.45))   # a racing stripe
		"nimbus":
			# panel lines and a blinking landing light
			ci.draw_line(o + Vector2(w * 0.33, 3), o + Vector2(w * 0.33, h - 3), Color(0, 0, 0, 0.22), 1.0)
			ci.draw_line(o + Vector2(3, h * 0.55), o + Vector2(w - 3, h * 0.55), Color(0, 0, 0, 0.22), 1.0)
			if fmod(t, 1.4) < 0.25:
				ci.draw_circle(o + Vector2(w - 5, 5), 2.2, Color(0.4, 1.0, 0.6))
		"kane":
			# gold seams, a light line pulsing along one
			var gold := Color(0.88, 0.72, 0.29)
			ci.draw_line(o + Vector2(w * 0.5, 3), o + Vector2(w * 0.5, h - 3), gold, 1.2)
			ci.draw_line(o + Vector2(3, h * 0.3), o + Vector2(w - 3, h * 0.3), gold, 1.2)
			var k := fmod(t * 0.7, 1.0)
			ci.draw_circle(o + Vector2(w * 0.5, 3 + (h - 6) * k), 2.0, Color(1.0, 0.9, 0.5, 0.9))
		"tenryu":
			# a yellow V on the chest, a V-fin on the head
			var yel := Color(0.95, 0.77, 0.06)
			if torso:
				var cx := o.x + w * 0.5
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.36, o.y + 4), Vector2(cx - w * 0.24, o.y + 4), Vector2(cx, o.y + h * 0.34),
						Vector2(cx + w * 0.24, o.y + 4), Vector2(cx + w * 0.36, o.y + 4), Vector2(cx, o.y + h * 0.46)]), yel)
				ci.draw_rect(Rect2(o.x + w * 0.2, o.y + h * 0.7, w * 0.6, 3.0), Color(0.9, 0.22, 0.27))
			else:
				var cx2 := o.x + w * 0.5
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx2, o.y + 2), Vector2(cx2 - w * 0.45, o.y - h * 0.32), Vector2(cx2 - w * 0.12, o.y + 2)]), yel)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx2, o.y + 2), Vector2(cx2 + w * 0.45, o.y - h * 0.32), Vector2(cx2 + w * 0.12, o.y + 2)]), yel)
		"menagerie":
			var red := Color(0.84, 0.19, 0.19)
			for k2 in 3:
				var dc := o + Vector2(w * (0.3 + 0.2 * k2), h * 0.82)
				ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -3), dc + Vector2(3, 0), dc + Vector2(0, 3), dc + Vector2(-3, 0)]), Color(0.88, 0.72, 0.29) if k2 % 2 else red)


## On an arm or a leg: a band round the upper segment in the maker's way.
static func _finish_limb(ci: CanvasItem, a: Vector2, b: Vector2, p: Dictionary, th: float, t: float) -> void:
	var m := str(p.get("maker", ""))
	if m == "" or classic or (b - a).length() < 8.0:
		return
	var dir := (b - a).normalized()
	var perp := dir.orthogonal() * (th * 0.55 + 1.0)
	var c := a.lerp(b, 0.5)
	var band := func(col: Color, wd: float) -> void:
		ci.draw_line(c - perp, c + perp, col, wd)
	match m:
		"scrapworks":
			band.call(Color(0.82, 0.74, 0.5, 0.85), 5.0)
		"oldiron":
			_hexbolt(ci, c, 2.4)
		"brassworks":
			band.call(Color(0.86, 0.68, 0.25), 3.5)
		"hellfire":
			band.call(Color(0.95, 0.78, 0.1), 4.0)
			ci.draw_line(c - perp * 0.4 - dir * 1.5, c + perp * 0.4 + dir * 1.5, Color(0.1, 0.1, 0.1), 1.5)
		"volta":
			band.call(Color(0.0, 0.8, 1.0, 0.75 + 0.25 * sin(t * 17.0)), 2.0)
		"nimbus":
			band.call(Color(0, 0, 0, 0.25), 1.0)
		"kane":
			band.call(Color(0.88, 0.72, 0.29), 1.6)
		"tenryu":
			band.call(Color(0.9, 0.22, 0.27), 3.5)
		"menagerie":
			band.call(Color(0.84, 0.19, 0.19), 3.0)


static var _front_legs := false   # (1.90) legs drawn by draw_front (the bay's gantry)


static func _hexbolt(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, Color(0.22, 0.22, 0.24))
	ci.draw_circle(c, r * 0.4, Color(0.55, 0.55, 0.58))


static func _damage_marks(ci: CanvasItem, a: Vector2, b: Vector2, health: float, t: float) -> void:
	if health >= 0.75 or (b - a).length() < 4.0:
		return
	var d := (b - a).normalized()
	var n := d.orthogonal()
	if health < 0.75:
		_dent(ci, a.lerp(b, 0.62) + n * 2.0, 3.5)
	if health < 0.55:
		var m := a.lerp(b, 0.42)
		_crack(ci, PackedVector2Array([m - n * 7.0, m - n * 2.0 + d * 3.0, m + n * 1.5 - d * 1.5, m + n * 6.0 + d * 2.0]))
	if health < 0.3:
		var m2 := a.lerp(b, 0.3)
		_split(ci, m2 - n * 4.0, m2 + n * 4.0 + d * 2.0, t)


## A crack in a plate: a dark jagged line with the light catching its lower lip.
static func _crack(ci: CanvasItem, pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	if _lit():
		var off := Vector2(0, 1.4)
		ci.draw_polyline(_shift(pts, off), _key_col(0.55), 1.2)
	ci.draw_polyline(pts, Color(0.04, 0.035, 0.035), 2.2)
	# hairline branches off the middle
	if pts.size() >= 3:
		var m: Vector2 = pts[1]
		var e: Vector2 = pts[pts.size() - 1]
		ci.draw_line(m, m.lerp(e, 0.5) + (e - m).orthogonal().normalized() * 4.0, Color(0.04, 0.035, 0.035), 1.2)


static func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + off)
	return out


## A dent: the metal pushed in, so the shadow sits on the lit side and the light on the far side.
static func _dent(ci: CanvasItem, at: Vector2, r: float) -> void:
	var tw := _toward() if _lit() else Vector2(0, -1)
	ci.draw_circle(at, r, Color(0, 0, 0, 0.28))
	ci.draw_circle(at + tw * r * 0.35, r * 0.7, Color(0, 0, 0, 0.22))
	if _lit():
		var ang := (-tw).angle()
		ci.draw_arc(at, r * 0.9, ang - 0.9, ang + 0.9, 8, _key_col(0.6), 1.2)


## A split torn open: a dark gash with hot wiring glowing inside.
static func _split(ci: CanvasItem, a: Vector2, b: Vector2, t: float) -> void:
	var d := b - a
	var n := d.orthogonal().normalized() * 2.6
	var mid := a.lerp(b, 0.5)
	var gash := PackedVector2Array([a, mid + n + d * 0.1, b, mid - n - d * 0.08])
	ci.draw_colored_polygon(gash, Color(0.03, 0.02, 0.02))
	var glow := Color(1.0, 0.42, 0.12, 0.55 + 0.35 * sin(t * 12.0))
	ci.draw_line(a.lerp(b, 0.25), a.lerp(b, 0.75), glow, 1.6)
	ci.draw_circle(mid, 5.0, Color(glow.r, glow.g, glow.b, 0.15))
	if _lit():
		ci.draw_line(gash[3] + Vector2(0, 1.2), b + Vector2(0, 1.2), _key_col(0.5), 1.0)


## (1.66) Wear on a big plate (torsos, heads) as the part loses health, always in the same places
## for the same part: dents, scorch, a crack with a lit lip, then a torn hole glowing inside.
static func _wear(ci: CanvasItem, r: Rect2, hp: float, seed: int, t: float) -> void:
	if hp >= 0.8:
		return
	var hx := func(k: int) -> float: return float(absi(hash(seed * 131 + k * 17)) % 1000) / 1000.0
	var at := func(k: int) -> Vector2: return r.position + Vector2(r.size.x * (0.2 + 0.6 * hx.call(k)), r.size.y * (0.2 + 0.6 * hx.call(k + 50)))
	var u := minf(r.size.x, r.size.y)
	# scorch: soft soot where it's been hit
	var sc: Vector2 = at.call(1)
	ci.draw_circle(sc, u * 0.16, Color(0.05, 0.04, 0.03, 0.16 * (1.0 - hp)))
	ci.draw_circle(sc, u * 0.09, Color(0.05, 0.04, 0.03, 0.18 * (1.0 - hp)))
	_dent(ci, at.call(2), clampf(u * 0.08, 3.0, 7.0))
	if hp < 0.65:
		_dent(ci, at.call(3), clampf(u * 0.06, 2.5, 5.5))
	if hp < 0.55:
		var c0: Vector2 = at.call(4)
		var s := u * 0.14
		_crack(ci, PackedVector2Array([c0 + Vector2(-s, -s * 0.8), c0 + Vector2(-s * 0.2, -s * 0.15), c0 + Vector2(s * 0.15, s * 0.35), c0 + Vector2(s * 0.75, s * 0.9)]))
	if hp < 0.3:
		var h0: Vector2 = at.call(6)
		var hr := clampf(u * 0.1, 4.0, 9.0)
		var hole := PackedVector2Array()
		for k in 7:
			var a := TAU * k / 7.0
			hole.append(h0 + Vector2(cos(a), sin(a) * 0.8) * hr * (0.7 + 0.5 * hx.call(k + 80)))
		ci.draw_colored_polygon(hole, Color(0.03, 0.02, 0.02))
		var glow := Color(1.0, 0.42, 0.12, 0.6 + 0.35 * sin(t * 10.0 + seed))
		ci.draw_circle(h0 + Vector2(0, hr * 0.2), hr * 0.45, glow)
		ci.draw_circle(h0, hr * 1.6, Color(glow.r, glow.g, glow.b, 0.12))
		var rim := hole.duplicate()
		rim.append(hole[0])
		ci.draw_polyline(rim, Color(0.04, 0.035, 0.035), 1.6)
		if _lit():
			ci.draw_polyline(PackedVector2Array([hole[1], hole[2], hole[3]]), _key_col(0.6), 1.2)


static func _stump(ci: CanvasItem, at: Vector2, t: float) -> void:
	if t < 0.0:
		return   # icons: no stumps
	ci.draw_circle(at, 6.0, Color(0.15, 0.15, 0.15))
	if fmod(t * 7.0, 1.0) < 0.5:
		ci.draw_circle(at + Vector2(4, 2), 3.0, Color(1.0, 0.8, 0.3))


# ---------------------------------------------------------------- Diagnostic Noir: painting tools

## Light the robot about to be drawn: a light set by name, mirrored for a robot facing left.
static func _set_light(name: String, facing: float) -> void:
	_L = Light.get_set(name)
	_from = float(_L.get("from", -0.55)) * facing
	# (1.83) looked up once here, not for every plate
	_amb = float(_L.get("amb", 0.3))
	_key = _L.get("key", Color(1.0, 0.96, 0.88))
	_rim = _L.get("rim", Color(0, 0, 0, 0))


static var _amb := 0.3
static var _key := Color(1.0, 0.96, 0.88)
static var _rim := Color(0, 0, 0, 0)


static func _lit() -> bool:
	return not classic and not _flash and not _L.is_empty()


static func _shadow_col(c: Color) -> Color:
	return c.darkened(_amb)


static func _key_col(alpha: float = 1.0) -> Color:
	return Color(_key.r, _key.g, _key.b, alpha * float(GRADE_EDGE[clampi(_grade, 0, 5)]))


## Which way the key light is, from a part (local, unit length).
static func _toward() -> Vector2:
	return Vector2(_from * 0.7, -1.0).normalized()


static func _bounds_of(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r


## A rectangle with its corners cut off (machined plates).
static func _chamfer(r: Rect2, k: float = -1.0) -> PackedVector2Array:
	if k < 0.0:
		k = minf(r.size.x, r.size.y) * 0.14
	k = minf(k, minf(r.size.x, r.size.y) * 0.45)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([Vector2(x0 + k, y0), Vector2(x1 - k, y0), Vector2(x1, y0 + k), Vector2(x1, y1 - k),
			Vector2(x1 - k, y1), Vector2(x0 + k, y1), Vector2(x0, y1 - k), Vector2(x0, y0 + k)])


## A flat-sided plate: the paint, a shadow face on the side away from the light, one dark outline,
## a light edge on the edges that face up, a rim on the edges that face away.
static func _plate(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	ci.draw_colored_polygon(pts, c)
	if not _lit() or pts.size() < 3:
		return
	var bb := _bounds_of(pts)
	var n_pts := pts.size()
	if bb.size.x < 7.0 and bb.size.y < 7.0:
		# (1.83) tiny bits (rivets, trim ends): just the outline, the light can't show on them
		ci.draw_polyline(pts, OUTLINE, 2.0)
		ci.draw_line(pts[n_pts - 1], pts[0], OUTLINE, 2.0)
		return
	var cut: PackedVector2Array
	if absf(_from) < 0.2:
		var bh := bb.size.y * 0.3   # light from above: the shadow is the bottom of the plate
		cut = PackedVector2Array([Vector2(bb.position.x - 2, bb.end.y - bh), Vector2(bb.end.x + 2, bb.end.y - bh), Vector2(bb.end.x + 2, bb.end.y + 2), Vector2(bb.position.x - 2, bb.end.y + 2)])
	else:
		var sw := bb.size.x * 0.34
		var x := bb.position.x - 2.0 if _from > 0.0 else bb.end.x - sw
		cut = PackedVector2Array([Vector2(x, bb.position.y - 2), Vector2(x + sw + 2, bb.position.y - 2), Vector2(x + sw + 2, bb.end.y + 2), Vector2(x, bb.end.y + 2)])
	var shade := c.darkened(_amb)
	for poly in Geometry2D.intersect_polygons(pts, cut):
		if (poly as PackedVector2Array).size() >= 3:
			ci.draw_colored_polygon(poly, shade)
	ci.draw_polyline(pts, OUTLINE, 2.5)
	ci.draw_line(pts[n_pts - 1], pts[0], OUTLINE, 2.5)
	var cen := bb.get_center()
	var rim_on := _rim.a > 0.0 and absf(_from) >= 0.2
	var key := _key_col(0.95)
	var kw := 2.2 if _grade < 5 else 2.8
	for i in n_pts:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n_pts]
		var d := b - a
		var dl := d.length()
		if dl < 5.0:
			continue
		var n := Vector2(-d.y, d.x) / dl
		if n.dot((a + b) * 0.5 - cen) < 0.0:
			n = -n
		if n.y < -0.5:
			ci.draw_line(a + d * 0.1 - n * 2.6, a + d * 0.9 - n * 2.6, key, kw)
		elif rim_on and n.x * _from < -0.6:
			ci.draw_line(a + d * 0.1 - n * 2.6, a + d * 0.9 - n * 2.6, _rim, 1.6)
	if _grade >= 5 and bb.size.x > 20.0:
		# titanium: a brushed sheen across the plate
		ci.draw_line(Vector2(bb.position.x + bb.size.x * 0.2, bb.position.y + bb.size.y * 0.55), Vector2(bb.position.x + bb.size.x * 0.55, bb.position.y + bb.size.y * 0.3), Color(1, 1, 1, 0.22), 2.0)


## A round part (orbs, domes, barrels seen end on): a crescent of shadow away from the light, an arc of light.
static func _round(ci: CanvasItem, cen: Vector2, r: float, c: Color) -> void:
	if not _lit():
		ci.draw_circle(cen, r, c)
		return
	ci.draw_circle(cen, r + 1.25, OUTLINE)
	ci.draw_circle(cen, r, _shadow_col(c))
	var tw := _toward()
	ci.draw_circle(cen + tw * r * 0.2, r * 0.8, c)
	if r < 5.0:
		return
	var ang := tw.angle()
	ci.draw_arc(cen, r - 2.4, ang - 0.75, ang + 0.75, 10, _key_col(0.95), 2.0)
	if _rim.a > 0.0 and absf(_from) >= 0.2:
		ci.draw_arc(cen, r - 2.0, ang + PI - 0.55, ang + PI + 0.55, 8, _rim, 1.5)


## An arm or leg segment: a dark outline, the paint, a shadow down the side away from the light,
## a thin light edge down the other side.
static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	if not _lit():
		ci.draw_line(a, b, c, w)
		return
	ci.draw_line(a, b, OUTLINE, w + 3.0)
	ci.draw_line(a, b, c, w)
	var d := b - a
	if d.length() < 1.0 or w < 4.0:
		return
	var p := d.orthogonal().normalized()
	if p.dot(_toward()) > 0.0:
		p = -p   # p points away from the light
	ci.draw_line(a + p * w * 0.25, b + p * w * 0.25, _shadow_col(c), w * 0.5)
	ci.draw_line(a.lerp(b, 0.12) - p * w * 0.3, a.lerp(b, 0.88) - p * w * 0.3, _key_col(0.85), maxf(1.4, w * 0.13))


## A joint, a knuckle or a bolt head: outlined, with a speck of light.
static func _joint(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	if not _lit():
		ci.draw_circle(at, r, c)
		return
	ci.draw_circle(at, r + 1.2, OUTLINE)
	ci.draw_circle(at, r, c)
	if r >= 4.0:
		ci.draw_circle(at + _toward() * r * 0.45, r * 0.22, _key_col(0.8))


## Small bits that stick out of the silhouette (weapons, horns, antennas, pods, feet) still get the
## one dark outline: a line, a polyline, a filled shape, a disc and an arc, each outlined when lit.
static func _ln(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	if _lit():
		ci.draw_line(a, b, OUTLINE, w + 2.5)
	ci.draw_line(a, b, c, w)


static func _pl(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	if _lit():
		ci.draw_polyline(pts, OUTLINE, w + 2.5)
	ci.draw_polyline(pts, c, w)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	ci.draw_colored_polygon(pts, c)
	if _lit() and pts.size() >= 3:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, OUTLINE, 2.2)


static func _box(ci: CanvasItem, r: Rect2, c: Color) -> void:
	_poly(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), c)


static func _disc(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	if _lit():
		ci.draw_circle(at, r + 1.2, OUTLINE)
	ci.draw_circle(at, r, c)


static func _arc(ci: CanvasItem, at: Vector2, r: float, a0: float, a1: float, n: int, c: Color, w: float) -> void:
	if _lit():
		ci.draw_arc(at, r, a0, a1, n, OUTLINE, w + 2.5)
	ci.draw_arc(at, r, a0, a1, n, c, w)


## Four bolts in the corners of a plate.
static func _bolts(ci: CanvasItem, r: Rect2) -> void:
	if not _lit() or r.size.x < 30.0 or r.size.y < 30.0:
		return
	var k := minf(r.size.x, r.size.y) * 0.16
	for q in [Vector2(r.position.x + k, r.position.y + k), Vector2(r.end.x - k, r.position.y + k),
			Vector2(r.position.x + k, r.end.y - k), Vector2(r.end.x - k, r.end.y - k)]:
		ci.draw_circle(q, 2.4, OUTLINE)
		ci.draw_circle(q, 1.6, Color(0.62, 0.64, 0.7))


## Scrap and junk grade: a few rust spots (always in the same places on the same part).
static func _rust(ci: CanvasItem, r: Rect2, seed: int) -> void:
	if not _lit() or _grade > 1:
		return
	for i in 3:
		var hx := float(absi(hash(seed * 31 + i * 7)) % 1000) / 1000.0
		var hy := float(absi(hash(seed * 17 + i * 13)) % 1000) / 1000.0
		ci.draw_circle(r.position + Vector2(r.size.x * (0.2 + hx * 0.6), r.size.y * (0.2 + hy * 0.6)), 2.0 + hx * 2.0, Color(0.55, 0.28, 0.12, 0.7))


## A light that glows (eyes, cores, screens): a soft halo behind it. No blur, two see-through circles.
static func _glow(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	if not _lit():
		return
	ci.draw_circle(at, r * 2.2, Color(col.r, col.g, col.b, 0.12))
	ci.draw_circle(at, r * 1.5, Color(col.r, col.g, col.b, 0.2))


# ---- arms
## Elbow and hand of an arm in a pose (local, unscaled), from its shoulder s. Drawing and the fight's
## hit test both use this, so a fist lands exactly where it's drawn.
## reach_x: where a punching hand ends up (the rear hand crosses over to land about as far as the lead one).
## aim: the punch tilts this many radians toward its target (negative = up).
## arm_len > 0 (1.51): the arm keeps its length. The pose's hand position is the goal; the shoulder
## turns forward into punches (the rear one across the chest), the hand stops where the arm runs out
## and the elbow bends to fit (two-bone IK). Returns [elbow, hand, shoulder].
static func arm_pose_points(s: Vector2, pose: String, back: bool, reach_x: float = 0.0, aim: float = 0.0, bob: Vector2 = Vector2.ZERO, arm_len: float = 0.0) -> Array:
	var e := s
	var h := s
	var tilt := false
	match pose:
		"punch":
			var reach := PUNCH_LEN if reach_x <= 0.0 or not back else maxf(PUNCH_LEN, reach_x - s.x)
			e = s + Vector2(reach * 0.48, 0)
			h = s + Vector2(reach, 2)
			tilt = true
		"low_punch":
			var reach2 := PUNCH_LEN - 4.0 if reach_x <= 0.0 or not back else maxf(PUNCH_LEN - 4.0, reach_x - s.x - 4.0)
			e = s + Vector2(reach2 * 0.45, 22)
			h = s + Vector2(reach2 * 0.92, 44)
			tilt = true
		"uppercut":
			# rises forward on a diagonal, not straight up (the rear hand crosses over as far)
			var ux := 70.0 if reach_x <= 0.0 or not back else maxf(70.0, reach_x - PUNCH_LEN + 62.0 - s.x)
			e = s + Vector2(ux * 0.5, 6)
			h = s + Vector2(ux, -56)
			tilt = true
		# (1.93) techniques
		"hook":
			# the elbow comes up and out, the fist swings round into the side of the head
			e = s + Vector2(42, 2)
			h = s + Vector2(58, -22)
			tilt = true
		"overhand":
			# the haymaker: over the top and down onto them
			var ox := PUNCH_LEN if reach_x <= 0.0 or not back else maxf(PUNCH_LEN, reach_x - s.x)
			e = s + Vector2(ox * 0.42, -38)
			h = s + Vector2(ox * 0.95, 6)
			tilt = true
		"shove":
			# a flat palm, straight out at chest height
			var sx2 := PUNCH_LEN if reach_x <= 0.0 or not back else maxf(PUNCH_LEN, reach_x - s.x)
			e = s + Vector2(sx2 * 0.5, 10)
			h = s + Vector2(sx2 * 0.95, 12)
			tilt = true
		"elbow":
			# folded: the elbow drives forward, the fist tucked by the head
			e = s + Vector2(40, -2)
			h = s + Vector2(16, -20)
		"charge":
			# drawn back, ready to let go
			e = s + Vector2(-26 if not back else -18, 14)
			h = s + Vector2(-10 if not back else -4, -14)
		"hammer_up":
			# both fists raised overhead (the rear one reaches over the head too)
			e = s + Vector2(6 if not back else 20, -34)
			h = s + Vector2(14 if not back else 30, -76)
		"hammer":
			# smashed down in front, both fists meeting
			var hx := 64.0 if reach_x <= 0.0 or not back else maxf(64.0, reach_x - PUNCH_LEN + 56.0 - s.x)
			e = s + Vector2(hx * 0.55, -22)
			h = s + Vector2(hx, 30)
		"flung":
			e = s + Vector2(-14 if not back else -20, -22)
			h = s + Vector2(-20 if not back else -30, -52)
		"block":
			e = s + Vector2(20 if not back else 26, 20)
			h = s + Vector2(24 if not back else 30, -26)
		"limp":
			e = s + Vector2(4 if not back else -6, 26)
			h = s + Vector2(10 if not back else 0, 50)
		"open":
			# front view on the gantry: hanging down and out to the side
			e = s + Vector2(12, 28)
			h = s + Vector2(26, 58)
		_ when pose.begins_with("claw:"):
			# crawling: the hand plants far out in front and pulls back along the floor (the robot
			# slides forward over it), then lifts and swings forward for the next grab
			var k := float(pose.substr(5))
			var floor_y := -20.0   # the fist (and its claws or spike) end up on the floor line
			if k < 0.6:
				h = Vector2(s.x + lerpf(72.0, 12.0, k / 0.6), floor_y)
			else:
				var u := (k - 0.6) / 0.4
				h = Vector2(s.x + lerpf(12.0, 72.0, u), floor_y - sin(u * PI) * 30.0)
			e = Vector2(lerpf(s.x, h.x, 0.45), minf(s.y + 10.0, h.y - 30.0))   # elbow up, forearm reaching down to the floor
		_:
			e = s + Vector2(6 if not back else -8, 26)
			h = s + Vector2(36 if not back else 30, 18 if not back else 24)
			# the guard bobs and twitches while the robot waits (fight.body_pose sends "bob")
			e += bob * 0.5
			h += bob
	if tilt and aim != 0.0:
		e = s + (e - s).rotated(aim)
		h = s + (h - s).rotated(aim)
	if arm_len <= 0.0 or pose.begins_with("claw:"):
		return [e, h, s]   # (crawling arms reach for the floor however they can)
	var slide := 0.0
	if REACH_POSES.has(pose) or pose == "hook" or pose == "elbow":
		slide = 12.0
		if back:
			slide = 24.0
			if reach_x > 0.0:
				slide = maxf(slide, (reach_x - PUNCH_LEN + 8.0 - s.x) * 0.85)   # the hips turn: the rear shoulder comes through
	elif pose == "block":
		slide = 4.0
	var s2 := s + Vector2(slide, 0.0)
	var up_len := arm_len * 0.47
	var fore_len := arm_len * 0.53
	var d := h - s2
	var maxr := (up_len + fore_len) * 0.985
	if d.length() > maxr:
		h = s2 + d.normalized() * maxr
	e = ik_joint(s2, h, up_len, fore_len, e + Vector2(0.0, 4.0))
	return [e, h, s2]


## Two bones from a to t (lengths l1, l2): where the joint between them goes, bent toward hint.
static func ik_joint(a: Vector2, t: Vector2, l1: float, l2: float, hint: Vector2) -> Vector2:
	var d := t - a
	var dist := clampf(d.length(), 0.001, l1 + l2 - 0.001)
	var dir := d.normalized() if d.length() > 0.001 else Vector2.DOWN
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hh := sqrt(maxf(0.0, l1 * l1 - x * x))
	var perp := dir.orthogonal()
	if perp.dot(hint - a) < 0.0:
		perp = -perp
	return a + dir * x + perp * hh


## How long an arm is, shoulder to fist (local): a bigger part reaches further.
static func arm_len_of(look: Dictionary, slot: String) -> float:
	return 58.0 * float(_part(look, slot).get("size", 1.0))


## (1.89) Legs of different lengths: [how much shorter the short one is (local), its slot], or [0, ""].
static func limp_of(look: Dictionary) -> Array:
	if not (_alive(look, "leg_front") and _alive(look, "leg_back")):
		return [0.0, ""]
	var lf := leg_len_of(look, "leg_front")
	var lb := leg_len_of(look, "leg_back")
	if absf(lf - lb) < 4.0:
		return [0.0, ""]
	return [absf(lf - lb), "leg_front" if lf < lb else "leg_back"]


## How long a leg is, hip to foot (local).
static func leg_len_of(look: Dictionary, slot: String) -> float:
	var p := _part(look, slot)
	return float(LEGS.get(p.get("shape", "rod"), LEGS["rod"])[0]) * float(p.get("size", 1.0))


## How far a weapon on the end of an arm sticks out past the hand, and how thick the striking end is.
static func arm_tip_extra(look: Dictionary, slot: String, pose: String) -> Vector2:
	var p := _part(look, slot)
	var dims: Array = ARMS.get(p.get("shape", "rod"), ARMS["rod"])
	var sz: float = p.get("size", 1.0)
	var fr: float = dims[1] * sz
	var th: float = dims[0] * sz
	var ext := fr
	match str(p.get("shape", "")):
		"spike": ext = fr + 16.0
		"claw": ext = 20.0
		"hammer": ext = 10.0 + 16.0 * sz
		"drill": ext = 34.0 * sz
		"blade": ext = 44.0 * sz
		"saw": ext = 12.0 + 16.0 * sz
		"magnet": ext = 8.0 + 13.0 * sz
		"grapple": ext = 18.0
		"flame": ext = 60.0 if pose == "punch" or pose == "low_punch" else 16.0
		"anvil": ext = 22.0 * sz
		"crane": ext = 22.0 * sz
		"wrench": ext = 21.0 * sz
		"grabber": ext = 22.0 * sz
		"gauntlet": ext = fr + 3.0
		"riveter": ext = 24.0 * sz
		"wrecker": ext = 30.0 * sz + fr if REACH_POSES.has(pose) or LEG_HITS.has(pose) else fr + 8.0
		"torch": ext = 60.0 if pose == "punch" or pose == "low_punch" else 22.0 * sz
		"arcfist": ext = fr + 8.0 * sz
		"magclamp": ext = 8.0 + 15.0 * sz
		"wingblade": ext = 40.0 * sz
		"turbine": ext = fr + 10.0 * sz
	if pose == "elbow" or pose == "shove":
		ext = 6.0   # the elbow (or a flat palm) does the hitting, not the weapon
	return Vector2(ext, maxf(fr, th * 0.5))


## Shoulder of an arm slot.
static func shoulder_of(g: Dictionary, slot: String) -> Vector2:
	return g.get("shoulder" + slot.substr(3), g["shoulder_front"])


## Where a punching hand ends up (local x): the lead hand's reach, used for the rear hand too.
static func punch_reach_x(g: Dictionary) -> float:
	return maxf(float((g["shoulder_front"] as Vector2).x), float((g["shoulder_back"] as Vector2).x)) + PUNCH_LEN - 8.0


## The striking line of a limb in a pose (local, unscaled): from the elbow/knee out to the very tip,
## plus how thick the end is. {"a": inner point, "b": tip, "r": radius}
static func limb_strike(look: Dictionary, slot: String, pose: String, aim: float = 0.0, drop: float = 0.0) -> Dictionary:
	var g := geom(look)
	if slot.begins_with("arm"):
		var s := shoulder_of(g, slot)
		var pts := arm_pose_points(s, pose, is_rear(look, slot), punch_reach_x(g), aim, Vector2.ZERO, arm_len_of(look, slot))
		var ex := arm_tip_extra(look, slot, pose)
		if pose == "elbow":
			# the point of the elbow does the hitting
			var ed: Vector2 = ((pts[0] as Vector2) - (pts[2] as Vector2)).normalized()
			return {"a": pts[2], "b": (pts[0] as Vector2) + ed * 8.0, "r": maxf(ex.y, 10.0)}
		var dir: Vector2 = ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()
		return {"a": pts[0], "b": (pts[1] as Vector2) + dir * ex.x, "r": ex.y}
	if slot.begins_with("leg"):
		var hip := kick_hip(look, g, slot, pose)
		var ll := leg_len_of(look, slot)
		var foot := leg_pose_foot(hip, pose, 0.0, aim, ll, drop)
		var p := _part(look, slot)
		if pose == "knee":
			# the knee does the hitting
			var kn := ik_joint(hip, foot, ll * 0.5, ll * 0.5, hip.lerp(foot, 0.5) + Vector2(8.0, 0.0))
			return {"a": hip, "b": kn + (kn - hip).normalized() * 8.0, "r": 14.0 * maxf(0.8, float(p.get("size", 1.0)))}
		return {"a": hip.lerp(foot, 0.45), "b": foot + (foot - hip).normalized() * 8.0, "r": 12.0 * maxf(0.8, float(p.get("size", 1.0)))}
	# no limb: the front of the torso (shoulder charges, slams)
	var t: Rect2 = g["torso"]
	return {"a": Vector2(t.end.x - 6.0, t.position.y + t.size.y * 0.25), "b": Vector2(t.end.x + 8.0, t.position.y + t.size.y * 0.75), "r": 14.0}


## Where a foot goes in a pose (local, unscaled), from its hip.
## leg_len > 0 (1.51): the leg keeps its length; drop = how far the body has sunk (a sweep drops low
## so the foot can run along the floor).
static func leg_pose_foot(hip: Vector2, pose: String, swing: float = 0.0, aim: float = 0.0, leg_len: float = 0.0, drop: float = 0.0) -> Vector2:
	if leg_len > 0.0 and pose != "stand" and pose != "":
		var goal := _leg_goal(hip, pose, aim, leg_len, drop)
		var gd := goal - hip
		if gd.length() > leg_len * 0.985:
			goal = hip + gd.normalized() * leg_len * 0.985
		return goal
	if leg_len > 0.0:
		# (1.89) a leg shorter than the other can't reach the floor: it hangs at its own length
		var ft := Vector2(hip.x + swing, -drop)
		if (ft - hip).length() > leg_len:
			ft = hip + (ft - hip).normalized() * leg_len
		return ft
	match pose:
		# the rear leg (hip behind the middle) swings through to land about as far as the lead one
		"kick":
			var v := Vector2(maxf(108.0, 120.0 - hip.x), -18.0)
			return hip + (v.rotated(aim) if aim != 0.0 else v)
		"high_kick":
			var hv := Vector2(maxf(90.0, 102.0 - hip.x), -78.0)
			return hip + (hv.rotated(aim) if aim != 0.0 else hv)
		"sweep":
			return Vector2(maxf(hip.x + 112.0, 124.0), -10.0)
		"tuck":
			return hip + Vector2(16.0, 34.0)   # knees up at the top of a jump
		"fly_kick":
			return Vector2(maxf(hip.x + 70.0, 84.0), hip.y + 58.0)
		"push_kick", "roundhouse", "axe_kick", "knee":
			return _leg_goal(hip, pose, aim, 60.0, 0.0)
	return Vector2(hip.x + swing, 0.0)


static func _leg_goal(hip: Vector2, pose: String, aim: float, leg_len: float, drop: float) -> Vector2:
	match pose:
		"kick":
			return hip + Vector2(1.0, -0.17).normalized().rotated(aim) * leg_len
		"high_kick":
			return hip + Vector2(0.76, -0.65).normalized().rotated(aim) * leg_len
		"sweep":
			# low along the floor: the body has dropped, so the floor is `drop` above the usual line
			var vd := maxf(0.0, -hip.y - drop)
			return hip + Vector2(sqrt(maxf(0.0, leg_len * leg_len - vd * vd)), vd)
		"tuck":
			return hip + Vector2(16.0, 34.0)
		"fly_kick":
			return hip + Vector2(0.77, 0.64) * leg_len
		# (1.93) techniques
		"push_kick":
			return hip + Vector2(1.0, -0.32).normalized().rotated(aim) * leg_len   # the sole, flat out at the belly
		"roundhouse":
			return hip + Vector2(0.84, -0.54).normalized().rotated(aim) * leg_len
		"axe_kick":
			return hip + Vector2(0.42, -0.91).normalized() * leg_len   # up high, about to chop down
		"knee":
			return hip + Vector2(0.12, 0.42) * leg_len   # foot tucked under: the knee drives up and forward
	return Vector2(hip.x, -drop)


static func _draw_arm(ci: CanvasItem, look: Dictionary, slot: String, s: Vector2, pose: String,
		back: bool, flash: bool, trim: Color, t: float, fist_gone: bool = false, aim: float = 0.0, bob: Vector2 = Vector2.ZERO) -> void:
	var p := _part(look, slot)
	if p.has("pod"):
		_pod(ci, s, p["pod"], t)   # a reactor strapped on where the arm should be
		return
	if not p.get("alive", false):
		_stump(ci, s, -1.0 if look.get("icon", false) else t)
		return
	var dims: Array = ARMS.get(p["shape"], ARMS["rod"])
	if str(p.get("swap", "")) == "leg":
		dims = [LEGS.get(p["shape"], LEGS["rod"])[1] * 0.85, 6.0]   # a leg doing an arm's job keeps its own thickness
	var sz: float = p["size"]
	var th: float = dims[0] * sz
	var fr: float = dims[1] * sz
	var reach_x := punch_reach_x(geom(look)) if REACH_POSES.has(pose) else 0.0
	var ph := arm_pose_points(s, pose, back, reach_x, aim, bob, arm_len_of(look, slot))
	var e: Vector2 = ph[0]
	var h: Vector2 = ph[1]
	s = ph[2]   # the shoulder turns forward into a punch
	var c := _col(p, flash, back)
	var tc := trim.darkened(0.35) if back else trim
	var dir := (h - e).normalized()
	var perp := dir.orthogonal()
	_grade = int(p.get("grade", 3))

	if p["shape"] == "bulky":
		_round(ci, s, th * 0.8, c.darkened(0.1))
	_limb(ci, s, e, c, th)
	_limb(ci, e, h, c, th * 0.9)
	_joint(ci, s, th * 0.55, c.darkened(0.25))
	_joint(ci, e, th * 0.5, c.darkened(0.25))
	if str(p.get("swap", "")) == "leg":
		# a leg bolted on as an arm: it punches with a foot
		var heel := h - perp * 7.0
		_plate(ci, PackedVector2Array([heel - dir * 4.0, h + perp * 7.0 - dir * 4.0, h + perp * 9.0 + dir * 16.0, heel + dir * 20.0]), tc)
		_damage_marks(ci, s, h, p.get("health", 1.0), t)
		return
	match p["shape"]:
		"piston":
			_limb(ci, e + dir * 4.0, e.lerp(h, 0.6), c.darkened(0.3), th * 1.4)
			_limb(ci, e.lerp(h, 0.6), h, tc, th * 0.45)
			_round(ci, h, fr, tc)
		"spike":
			_round(ci, h, fr, c.darkened(0.15))
			_poly(ci, PackedVector2Array([h + dir * (fr + 16.0), h + perp * fr * 0.6, h - perp * fr * 0.6]), tc)
			_poly(ci, PackedVector2Array([h + perp * (fr + 8.0), h + dir * fr * 0.5, h - dir * fr * 0.5]), tc)
		"claw":
			var tip1 := h + dir * 16.0 + perp * 10.0
			var tip2 := h + dir * 16.0 - perp * 10.0
			_pl(ci, PackedVector2Array([h, tip1, tip1 - perp * 6.0 + dir * 4.0]), tc, 5.0)
			_pl(ci, PackedVector2Array([h, tip2, tip2 + perp * 6.0 + dir * 4.0]), tc, 5.0)
			_joint(ci, h, fr, c.darkened(0.2))
		"hammer":
			var cen := h + dir * 10.0
			var a := dir * 16.0 * sz
			var b := perp * 14.0 * sz
			_plate(ci, PackedVector2Array([cen - a - b, cen + a - b, cen + a + b, cen - a + b]), tc)
			ci.draw_line(cen - b * 0.9, cen + b * 0.9, c.darkened(0.3), 3.0)
		"drill":
			var cone := PackedVector2Array([h + perp * 11.0 * sz, h + dir * 34.0 * sz, h - perp * 11.0 * sz])
			_poly(ci, cone, tc)
			var spin := fmod(t * 3.0, 1.0)
			for k in 3:
				var f := (k + spin) / 3.0
				var q := h + dir * 34.0 * sz * f
				var w := 11.0 * sz * (1.0 - f)
				ci.draw_line(q + perp * w, q - perp * w + dir * 4.0, c.darkened(0.4), 2.0)
		"bulky":
			_round(ci, h, fr, tc)
			ci.draw_circle(h + dir * 3.0, fr * 0.55, tc.darkened(0.15))
		"blade":
			var tip := h + dir * 44.0 * sz
			_poly(ci, PackedVector2Array([h + perp * 6.0, tip, h - perp * 6.0]), tc.lightened(0.2))
			ci.draw_line(h, tip, Color(1, 1, 1, 0.5), 1.5)
			_joint(ci, h, th * 0.6, c.darkened(0.3))
		"flame":
			_box(ci, Rect2(h - Vector2(8, 8), Vector2(16, 16)), c.darkened(0.3))
			_ln(ci, h, h + dir * 14.0, tc, 8.0)
			if pose == "punch":
				var fl := 0.7 + 0.3 * sin(t * 40.0)
				ci.draw_colored_polygon(PackedVector2Array([h + dir * 14.0 + perp * 6.0, h + dir * (60.0 * fl), h + dir * 14.0 - perp * 6.0]), Color(1.0, 0.5, 0.1, 0.85))
				ci.draw_colored_polygon(PackedVector2Array([h + dir * 14.0 + perp * 3.0, h + dir * (36.0 * fl), h + dir * 14.0 - perp * 3.0]), Color(1.0, 0.95, 0.5))
			else:
				ci.draw_circle(h + dir * 16.0, 3.0, Color(0.3, 0.6, 1.0, 0.6 + 0.4 * sin(t * 9.0)))
		"magnet":
			var mc := h + dir * 8.0
			_ln(ci, mc + perp * 13.0 * sz, mc + perp * 13.0 * sz + dir * 10.0, Color(0.85, 0.85, 0.9), 9.0)
			_ln(ci, mc - perp * 13.0 * sz, mc - perp * 13.0 * sz + dir * 10.0, Color(0.85, 0.85, 0.9), 9.0)
			_arc(ci, mc, 13.0 * sz, dir.angle() + PI * 0.5, dir.angle() + PI * 1.5, 12, Color(0.75, 0.15, 0.15), 9.0)
		"rocket":
			ci.draw_rect(Rect2(e.lerp(h, 0.4) - perp * th * 0.7, Vector2(4, 4)), c.darkened(0.4))
			for k in 2:
				var q := e.lerp(h, 0.45 + k * 0.2)
				ci.draw_line(q - perp * th * 0.6, q + perp * th * 0.6, c.darkened(0.35), 3.0)
			if fist_gone:
				ci.draw_circle(h, th * 0.5, Color(0.15, 0.15, 0.15))
				ci.draw_circle(h + dir * 3.0, th * 0.3, Color(1.0, 0.6, 0.2, 0.7 + 0.3 * sin(t * 30.0)))
			else:
				draw_rocket_fist(ci, h, dir, fr, c, tc, false, t)
		"grapple":
			if not fist_gone:
				var tip1 := h + dir * 18.0 + perp * 9.0
				var tip2 := h + dir * 18.0 - perp * 9.0
				_pl(ci, PackedVector2Array([h, tip1, tip1 - perp * 7.0 + dir * 2.0]), tc, 4.0)
				_pl(ci, PackedVector2Array([h, tip2, tip2 + perp * 7.0 + dir * 2.0]), tc, 4.0)
			_joint(ci, h, th * 0.7, c.darkened(0.3))
		"saw":
			var cen := h + dir * 12.0
			var rr := 16.0 * sz
			var spin := t * 25.0
			for k in 8:
				var a := spin + k * TAU / 8.0
				var o := Vector2(cos(a), sin(a))
				_poly(ci, PackedVector2Array([cen + o * rr * 0.9, cen + o.rotated(0.35) * (rr + 6.0), cen + o.rotated(0.5) * rr * 0.9]), tc.darkened(0.2))
			_disc(ci, cen, rr, tc)
			ci.draw_circle(cen, rr * 0.3, c.darkened(0.4))
		"anvil":
			# (1.97) Old Iron: a forged anvil for a fist
			var k := sz
			# its height runs along the punch: the flat top face is the striking face, the horn sticks out sideways
			var uv := [Vector2(0, -10), Vector2(5, -10), Vector2(9, -5), Vector2(12, -13), Vector2(22, -13), Vector2(22, 14),
					Vector2(19, 26), Vector2(15, 13), Vector2(12, 12), Vector2(9, 5), Vector2(5, 10), Vector2(0, 10)]
			var body := PackedVector2Array()
			for q in uv:
				body.append(h + dir * (q as Vector2).x * k + perp * (q as Vector2).y * k)
			_plate(ci, body, Color(0.24, 0.26, 0.29) if not flash else Color.WHITE)
			ci.draw_line(h + dir * 21.0 * k - perp * 12.0 * k, h + dir * 21.0 * k + perp * 12.0 * k, Color(0.78, 0.8, 0.82, 0.75), 2.5)
			_hexbolt(ci, h + dir * 16.0 * k, 3.0 * k)
		"crane":
			# (1.97) Old Iron: a pulley block and a yellow crane hook
			_plate(ci, PackedVector2Array([h - dir * 4.0 - perp * 8.0 * sz, h + dir * 8.0 * sz - perp * 8.0 * sz, h + dir * 8.0 * sz + perp * 8.0 * sz, h - dir * 4.0 + perp * 8.0 * sz]), Color(0.28, 0.29, 0.31))
			_joint(ci, h + dir * 2.0 * sz, 3.0 * sz, tc)
			var hook := PackedVector2Array([h + dir * 8.0 * sz, h + dir * 16.0 * sz, h + dir * 21.0 * sz + perp * 4.0 * sz,
					h + dir * 19.0 * sz + perp * 10.0 * sz, h + dir * 12.0 * sz + perp * 11.0 * sz, h + dir * 9.0 * sz + perp * 6.0 * sz])
			_pl(ci, hook, Color(0.9, 0.68, 0.12) if not flash else Color.WHITE, 5.0 * sz)
		"wrench":
			# (1.97) Scrapworks: a big open-end wrench where the hand should be
			var wc := h + dir * 10.0 * sz
			_disc(ci, wc, 11.0 * sz, tc)
			ci.draw_colored_polygon(PackedVector2Array([wc + dir * 12.0 * sz + perp * 5.0 * sz, wc + dir * 1.0 * sz + perp * 3.5 * sz,
					wc + dir * 1.0 * sz - perp * 3.5 * sz, wc + dir * 12.0 * sz - perp * 5.0 * sz]), Color(0.07, 0.07, 0.08))
			_ln(ci, h - dir * 2.0, wc - dir * 6.0 * sz, tc, 7.0 * sz)
		"grabber":
			# (1.97) Scrapworks: a litter picker's jaws on the end of a long pipe
			_ln(ci, h, h + dir * 10.0 * sz, tc, 4.0)
			_pl(ci, PackedVector2Array([h + dir * 10.0 * sz, h + dir * 17.0 * sz + perp * 6.0 * sz, h + dir * 22.0 * sz + perp * 3.0 * sz]), tc, 3.0)
			_pl(ci, PackedVector2Array([h + dir * 10.0 * sz, h + dir * 17.0 * sz - perp * 6.0 * sz, h + dir * 22.0 * sz - perp * 3.0 * sz]), tc, 3.0)
			_joint(ci, h, th * 0.5, c.darkened(0.3))
		"gauntlet":
			# (1.98) Brassworks: a piston rod along the forearm, a steam valve and a big brass gauntlet
			_limb(ci, e + dir * 3.0, e.lerp(h, 0.75), c.darkened(0.25), th * 1.25)
			_ln(ci, e.lerp(h, 0.2) + perp * th * 0.55, h + perp * fr * 0.6, Color(0.82, 0.82, 0.86), 3.0)
			_disc(ci, e.lerp(h, 0.45) - perp * th * 0.7, 3.5, Color(0.75, 0.2, 0.15))   # the valve wheel
			_round(ci, h, fr, tc)
			for k in 3:
				var kp := h + dir * fr * 0.55 + perp * (k - 1) * fr * 0.5
				ci.draw_circle(kp, fr * 0.22, tc.darkened(0.25))
		"riveter":
			# (1.98) Brassworks: a pneumatic riveter, a hose looping back to the elbow
			var body0 := h - dir * 2.0
			_plate(ci, PackedVector2Array([body0 - perp * 7.0 * sz, body0 + dir * 16.0 * sz - perp * 6.0 * sz, body0 + dir * 16.0 * sz + perp * 6.0 * sz, body0 + perp * 7.0 * sz]), tc)
			_ln(ci, body0 + dir * 16.0 * sz, body0 + dir * 24.0 * sz, Color(0.75, 0.75, 0.78), 3.5)
			for k in 3:
				var rq := body0 + dir * (3.0 + k * 4.0) * sz
				ci.draw_line(rq - perp * 6.0 * sz, rq + perp * 6.0 * sz, tc.darkened(0.3), 1.5)
			_pl(ci, PackedVector2Array([body0 + perp * 6.0, body0 + perp * 14.0 - dir * 6.0, e + perp * 10.0, e + perp * 3.0]), Color(0.18, 0.16, 0.14), 3.0)
		"wrecker":
			# (1.99) Hellfire: a wrecking ball on a short chain. It hangs and sways, and flies out straight on a punch
			_plate(ci, _chamfer(Rect2(h - Vector2(7, 7) * sz, Vector2(14, 14) * sz), 3.0), c.darkened(0.2))
			var ball := h + dir * 30.0 * sz
			if not REACH_POSES.has(pose):
				ball = h + Vector2(sin(t * 2.2) * 7.0 * sz + dir.x * 4.0, 26.0 * sz)
			var links := 5
			for k in links:
				var lp := h.lerp(ball, (k + 0.5) / float(links + 1))
				var ld := (ball - h).normalized()
				if k % 2 == 1:
					ld = ld.orthogonal() * 0.55   # every other link turned edge on
				ci.draw_line(lp - ld * 4.0 * sz, lp + ld * 4.0 * sz, OUTLINE, 5.0 * sz)
				ci.draw_line(lp - ld * 3.2 * sz, lp + ld * 3.2 * sz, Color(0.55, 0.55, 0.58), 2.6 * sz)
			_round(ci, ball, fr, Color(0.22, 0.22, 0.24) if not flash else Color.WHITE)
			ci.draw_arc(ball, fr * 0.7, -2.4, -1.2, 8, Color(1, 1, 1, 0.18), 2.0)
			_joint(ci, ball - (ball - h).normalized() * fr, 3.0 * sz, c.darkened(0.2))
		"arcfist":
			# (1.100) Volta: a chrome fist with two electrode prongs and an arc jumping between them
			_limb(ci, e.lerp(h, 0.35), h - dir * 3.0, Color(0.85, 0.88, 0.92), th * 1.15)
			ci.draw_line(e.lerp(h, 0.4) + perp * th * 0.3, h - dir * 5.0 + perp * th * 0.3, Color(0.0, 0.85, 1.0, 0.9), 2.0)   # neon tube
			_round(ci, h, fr, tc)
			var p1 := h + dir * (fr + 7.0 * sz) + perp * fr * 0.55
			var p2 := h + dir * (fr + 7.0 * sz) - perp * fr * 0.55
			_ln(ci, h + dir * fr * 0.5 + perp * fr * 0.55, p1, Color(0.8, 0.55, 0.25), 3.0)
			_ln(ci, h + dir * fr * 0.5 - perp * fr * 0.55, p2, Color(0.8, 0.55, 0.25), 3.0)
			if fmod(t * 7.0, 1.0) < 0.6 or REACH_POSES.has(pose):
				var zz := PackedVector2Array([p1])
				for k in 4:
					zz.append(p1.lerp(p2, (k + 1) / 5.0) + dir * (4.0 if (k + int(t * 20.0)) % 2 == 0 else -2.0))
				zz.append(p2)
				ci.draw_polyline(zz, Color(0.6, 0.95, 1.0), 2.0)
				ci.draw_circle(p1.lerp(p2, 0.5), 5.0, Color(0.5, 0.9, 1.0, 0.25))
		"wingblade":
			# (1.101) Nimbus: the forearm ends in a swept wing, white with a blue leading edge, a red tip light
			var wt := h + dir * 40.0 * sz
			var wing2 := PackedVector2Array([h - perp * 5.0, h + perp * 9.0 * sz + dir * 6.0, wt + perp * 2.0, wt - perp * 3.0, h - perp * 7.0 + dir * 10.0])
			_plate(ci, wing2, tc if flash else c)
			ci.draw_line(h + perp * 9.0 * sz + dir * 6.0, wt + perp * 2.0, Color(0.3, 0.6, 1.0), 2.5)
			ci.draw_line(h + dir * 12.0 * sz, h + dir * 30.0 * sz, c.darkened(0.25), 1.5)
			ci.draw_circle(wt, 2.2, Color(1.0, 0.25, 0.2) if fmod(t * 1.5, 1.0) < 0.5 else Color(0.5, 0.15, 0.12))
			_joint(ci, h, th * 0.55, c.darkened(0.25))
		"turbine":
			# (1.101) Nimbus: a little jet engine for a hand, the fan face spinning at the front
			var nb := h - dir * 4.0
			_plate(ci, PackedVector2Array([nb - perp * fr * 0.8, nb + dir * fr * 1.6 - perp * fr, nb + dir * fr * 1.6 + perp * fr, nb + perp * fr * 0.8]), c)
			var face := nb + dir * fr * 1.6
			_disc(ci, face, fr * 0.95, Color(0.2, 0.22, 0.26))
			for k in 6:
				var a4 := t * 30.0 + k * TAU / 6.0
				ci.draw_line(face, face + perp * cos(a4) * fr * 0.85 + dir * sin(a4) * fr * 0.2, Color(0.75, 0.78, 0.82), 2.0)
			ci.draw_circle(face, fr * 0.22, Color(0.85, 0.87, 0.9))
			ci.draw_line(nb + dir * fr * 0.4 - perp * fr * 0.85, nb + dir * fr * 0.4 + perp * fr * 0.85, Color(0.3, 0.6, 1.0), 2.0)
		"magclamp":
			# (1.100) Volta: an electromagnet clamp, a horseshoe in hot pink with its poles glowing
			var mc2 := h + dir * 7.0 * sz
			var rr2 := 11.0 * sz
			_arc(ci, mc2, rr2, dir.angle() + PI * 0.5, dir.angle() + PI * 1.5, 12, tc if flash else c, 8.0 * sz)
			for sgn in [1.0, -1.0]:
				var pole: Vector2 = mc2 + perp * rr2 * float(sgn)
				_ln(ci, pole, pole + dir * 9.0 * sz, Color(0.85, 0.87, 0.9), 8.0 * sz)
				ci.draw_circle(pole + dir * 9.0 * sz, 3.0 * sz, Color(0.5, 0.85, 1.0, 0.5 + 0.4 * sin(t * 8.0)))
			_joint(ci, h, th * 0.55, c.darkened(0.3))
		"torch":
			# (1.99) Hellfire: a cutting torch, a gas bottle on the forearm, a blue pilot flame; a punch is a jet of fire
			_plate(ci, PackedVector2Array([e.lerp(h, 0.25) + perp * th * 0.5, e.lerp(h, 0.7) + perp * th * 0.5, e.lerp(h, 0.7) + perp * th * 1.2, e.lerp(h, 0.25) + perp * th * 1.2]), Color(0.75, 0.55, 0.12))
			_pl(ci, PackedVector2Array([e.lerp(h, 0.7) + perp * th * 0.9, h + perp * 6.0 - dir * 4.0, h]), Color(0.15, 0.13, 0.12), 2.5)
			_plate(ci, _chamfer(Rect2(h - Vector2(6, 6), Vector2(12, 12)), 2.0), c.darkened(0.3))
			var nz := h + dir * 18.0 * sz + perp * 3.0
			_ln(ci, h, nz, Color(0.72, 0.6, 0.35), 5.0)
			if pose == "punch" or pose == "low_punch":
				var fl := 0.7 + 0.3 * sin(t * 40.0)
				ci.draw_colored_polygon(PackedVector2Array([nz + perp * 7.0, nz + dir * (44.0 * fl), nz - perp * 7.0]), Color(1.0, 0.45, 0.08, 0.85))
				ci.draw_colored_polygon(PackedVector2Array([nz + perp * 4.0, nz + dir * (28.0 * fl), nz - perp * 4.0]), Color(1.0, 0.92, 0.5))
				ci.draw_colored_polygon(PackedVector2Array([nz + perp * 2.0, nz + dir * 10.0, nz - perp * 2.0]), Color(0.5, 0.75, 1.0))
			else:
				var pf := 0.75 + 0.25 * sin(t * 30.0)
				ci.draw_colored_polygon(PackedVector2Array([nz + perp * 2.5, nz + dir * 9.0 * pf, nz - perp * 2.5]), Color(0.45, 0.7, 1.0, 0.9))
		_:
			_round(ci, h, fr, tc)
	_finish_limb(ci, s, e, p, th, t)
	_damage_marks(ci, s, h, p.get("health", 1.0), t)


## A reactor strapped to the shoulder in place of an arm (off-label, 1.54): a box with straps and its light.
static func _pod(ci: CanvasItem, s: Vector2, col: Color, t: float) -> void:
	var r := Rect2(s + Vector2(-9, -6), Vector2(18, 26))
	_plate(ci, _chamfer(r, 4.0), Color(0.24, 0.25, 0.28))
	_ln(ci, Vector2(r.position.x - 2, r.position.y + 7), Vector2(r.end.x + 2, r.position.y + 7), Color(0.35, 0.28, 0.2), 3.0)
	var c: Color = col
	_glow(ci, r.get_center() + Vector2(0, 4), 5.0, c)
	ci.draw_rect(Rect2(r.position + Vector2(5, 12), Vector2(8, 8)), Color(c, 0.7 + 0.3 * sin(t * 5.0)))
	_joint(ci, s, 5.0, Color(0.3, 0.3, 0.33))


static func draw_rocket_fist(ci: CanvasItem, h: Vector2, dir: Vector2, fr: float, c: Color, tc: Color, flying: bool, t: float) -> void:
	var perp := dir.orthogonal()
	if flying:
		var fl := 14.0 + 6.0 * sin(t * 40.0)
		ci.draw_colored_polygon(PackedVector2Array([h - dir * fr * 0.6 + perp * 6.0, h - dir * (fr + fl), h - dir * fr * 0.6 - perp * 6.0]), Color(1.0, 0.6, 0.15))
	_disc(ci, h, fr, tc)
	ci.draw_rect(Rect2(h - Vector2(fr * 0.3, fr * 0.9), Vector2(fr * 0.6, fr * 1.8)), c.darkened(0.2))
	ci.draw_circle(h + dir * fr * 0.5, fr * 0.5, tc.lightened(0.1))


# ---- back gear
static func _draw_back(ci: CanvasItem, look: Dictionary, g: Dictionary, pose: Dictionary, flash: bool, trim: Color, t: float) -> void:
	var b: Dictionary = look.get("back", {})
	if b.is_empty():
		return
	var c: Color = Color.WHITE if flash else b["color"]
	var tw: float = g["tw"]
	var top: float = g["top"]
	var bx := -tw * 0.5
	var flame := 0.7 + 0.3 * sin(t * 40.0)
	match b["shape"]:
		"battery":
			_box(ci, Rect2(bx - 16, top + 12, 18, 44), c)
			ci.draw_rect(Rect2(bx - 16, top + 24, 18, 4), c.darkened(0.4))
			ci.draw_rect(Rect2(bx - 16, top + 40, 18, 4), c.darkened(0.4))
			_box(ci, Rect2(bx - 12, top + 6, 6, 6), Color(0.9, 0.2, 0.2))
		"spikes":
			for k in 5:
				var y := top + 6 + k * 14.0
				_poly(ci, PackedVector2Array([Vector2(bx + 2, y), Vector2(bx - 18, y + 6), Vector2(bx + 2, y + 12)]), c)
			_poly(ci, PackedVector2Array([Vector2(-8, top), Vector2(-2, top - 14), Vector2(4, top)]), c)
		"booster":
			for k in 2:
				var y := top + 14 + k * 26.0
				_box(ci, Rect2(bx - 30, y + 2, 6, 10), c.darkened(0.4))
				_box(ci, Rect2(bx - 24, y, 26, 14), c)
				if pose.get("boost", false):
					ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 30, y + 1), Vector2(bx - 30 - 40 * flame, y + 7), Vector2(bx - 30, y + 13)]), Color(1.0, 0.55, 0.1, 0.9))
		"jet":
			_box(ci, Rect2(bx - 18, top + 52, 8, 12), c.darkened(0.4))
			_box(ci, Rect2(bx - 8, top + 52, 8, 12), c.darkened(0.4))
			_box(ci, Rect2(bx - 20, top + 8, 22, 46), c)
			if pose.get("jet", false):
				for nx in [bx - 14, bx - 4]:
					ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 4, top + 64), Vector2(nx, top + 64 + 36 * flame), Vector2(nx + 4, top + 64)]), Color(1.0, 0.6, 0.15, 0.9))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 2, top + 64), Vector2(nx, top + 64 + 18 * flame), Vector2(nx + 2, top + 64)]), Color(1.0, 1.0, 0.7))
		"plating":
			_box(ci, Rect2(bx - 14, top + 4, 18, g["th"] - 8), c)
			for k in 4:
				ci.draw_circle(Vector2(bx - 6, top + 14 + k * (g["th"] - 24) / 3.0), 3.0, c.darkened(0.4))
		"wings":
			var flap := sin(t * 6.0) * 6.0
			for k in 2:
				var root := Vector2(bx - 2, top + 16 + k * 10)
				_poly(ci, PackedVector2Array([root, root + Vector2(-56, -40 - k * 8 + flap), root + Vector2(-40, -6 + flap), root + Vector2(-60, 6 + flap * 0.5)]), Color(c.r, c.g, c.b, 0.85 - k * 0.25))
		"flywheel":
			# (1.97) Old Iron: a spoked flywheel on the back, spinning
			var fc := Vector2(bx - 6.0, top + float(g["th"]) * 0.42)
			var fr2 := 24.0
			_box(ci, Rect2(fc.x - 2.0, fc.y - 5.0, 10.0, 10.0), c.darkened(0.3))
			_disc(ci, fc, fr2, c.darkened(0.1))
			ci.draw_arc(fc, fr2 * 0.78, 0, TAU, 24, c.darkened(0.45), 3.0)
			for k in 6:
				var a := t * 5.0 + k * TAU / 6.0
				ci.draw_line(fc, fc + Vector2(cos(a), sin(a)) * fr2 * 0.76, c.darkened(0.4), 3.0)
			_joint(ci, fc, 6.0, trim)
		"tarp":
			# (1.97) Scrapworks: a green tarp tied on at the shoulders, flapping
			var fl := sin(t * 3.0) * 5.0
			var th2: float = g["th"]
			_plate(ci, PackedVector2Array([Vector2(bx + 6, top + 2), Vector2(bx - 6, top), Vector2(bx - 22 + fl, top + th2 * 0.5),
					Vector2(bx - 30 + fl * 1.4, top + th2 + 14), Vector2(bx - 8 + fl * 0.6, top + th2 + 8), Vector2(bx + 6, top + th2 * 0.85)]), c)
			ci.draw_line(Vector2(bx - 4, top + 6), Vector2(bx - 18 + fl, top + th2 + 6), c.darkened(0.25), 2.0)
			ci.draw_line(Vector2(bx + 2, top + 10), Vector2(bx - 6 + fl * 0.5, top + th2 + 4), c.darkened(0.2), 2.0)
			for gp in [Vector2(bx - 2, top + 4), Vector2(bx - 12 + fl * 0.3, top + th2 * 0.3)]:
				ci.draw_circle(gp, 2.5, Color(0.8, 0.8, 0.75))
			_ln(ci, Vector2(bx + 6, top + 4), Vector2(bx + 14, top + 9), Color(0.62, 0.5, 0.3), 2.0)
		"smokestack":
			# (1.98) Brassworks: a chimney on the back, brass bands, puffing
			var sk := Rect2(bx - 14.0, top - 30.0, 14.0, float(g["th"]) * 0.7 + 30.0)
			_plate(ci, _chamfer(sk, 2.0), c)
			_plate(ci, _chamfer(Rect2(sk.position.x - 3.0, sk.position.y - 6.0, sk.size.x + 6.0, 8.0), 2.0), c.darkened(0.2))
			for k in 3:
				var by2 := sk.position.y + 10.0 + k * sk.size.y * 0.28
				ci.draw_line(Vector2(sk.position.x, by2), Vector2(sk.end.x, by2), Color(0.8, 0.64, 0.2), 3.0)
			for k in 3:
				var ph := fmod(t * 0.7 + k * 0.33, 1.0)
				ci.draw_circle(Vector2(sk.get_center().x - ph * 14.0, sk.position.y - 8.0 - ph * 30.0), 4.0 + ph * 8.0, Color(0.92, 0.93, 0.95, 0.45 * (1.0 - ph)))
		"jetwings":
			# (1.101) Nimbus: swept white wings with a jet pod under each, blue tips, a flame on the double jump
			var th4: float = g["th"]
			var root2 := Vector2(bx + 4, top + th4 * 0.3)
			for k in 2:
				var off2 := k * 8.0
				var wing3 := PackedVector2Array([root2 + Vector2(0, off2), root2 + Vector2(-52, -26 + off2), root2 + Vector2(-60, -20 + off2), root2 + Vector2(-20, 10 + off2)])
				_plate(ci, wing3, c if k == 0 else c.darkened(0.15))
				ci.draw_line(root2 + Vector2(-52, -26 + off2), root2 + Vector2(-60, -20 + off2), Color(0.3, 0.6, 1.0), 3.0)
			var pod := root2 + Vector2(-22, 10)
			_plate(ci, _rounded(Rect2(pod.x - 10, pod.y - 5, 20, 10), 4.0), Color(0.75, 0.78, 0.82))
			if pose.get("jet", false):
				var ff2 := 0.7 + 0.3 * sin(t * 40.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(pod.x - 3, pod.y + 4), Vector2(pod.x, pod.y + 4 + 30.0 * ff2), Vector2(pod.x + 3, pod.y + 4)]), Color(0.4, 0.7, 1.0, 0.85))
			ci.draw_circle(root2 + Vector2(-58, -21), 2.0, Color(1.0, 0.25, 0.2) if fmod(t, 1.0) < 0.5 else Color(0.4, 0.1, 0.1))
		"spoiler":
			# (1.100) Volta: a racing spoiler on two struts, its edge a neon tube that blazes on a sprint
			var th3: float = g["th"]
			var wy := top - 6.0
			_ln(ci, Vector2(bx + 2, top + th3 * 0.3), Vector2(bx - 14, wy), Color(0.2, 0.22, 0.26), 4.0)
			_ln(ci, Vector2(bx + 2, top + th3 * 0.5), Vector2(bx - 22, wy + 4), Color(0.2, 0.22, 0.26), 4.0)
			var wing := PackedVector2Array([Vector2(bx - 40, wy - 6), Vector2(bx - 4, wy - 10), Vector2(bx - 2, wy - 4), Vector2(bx - 38, wy + 4)])
			_plate(ci, wing, c)
			var glow := 1.0 if pose.get("sprint", false) else 0.55 + 0.25 * sin(t * 5.0)
			ci.draw_line(Vector2(bx - 40, wy - 7), Vector2(bx - 4, wy - 11), Color(0.0, 0.9, 1.0, glow), 2.5)
			ci.draw_line(Vector2(bx - 38, wy + 5), Vector2(bx - 2, wy - 3), Color(1.0, 0.3, 0.7, glow), 2.0)
			_plate(ci, PackedVector2Array([Vector2(bx - 42, wy - 10), Vector2(bx - 36, wy - 10), Vector2(bx - 36, wy + 8), Vector2(bx - 42, wy + 6)]), c.darkened(0.25))
		"exhaust":
			# (1.99) Hellfire: two truck exhaust stacks; they belch smoke, and fire on a flame dash
			for k in 2:
				var sx := bx + 5.0 - k * 10.0
				var sy := top - 24.0 + k * 10.0
				_limb(ci, Vector2(sx, top + float(g["th"]) * 0.5), Vector2(sx, sy), Color(0.75, 0.76, 0.8), 8.0)
				_plate(ci, PackedVector2Array([Vector2(sx - 4, sy + 2), Vector2(sx + 4, sy + 2), Vector2(sx + 1, sy - 6), Vector2(sx - 6, sy - 4)]), Color(0.62, 0.63, 0.67))
				_plate(ci, _chamfer(Rect2(sx - 6, sy + 16, 12, 14), 2.0), c)   # heat shield
				if pose.get("boost", false):
					var ff := 0.7 + 0.3 * sin(t * 40.0 + k)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 5, sy - 5), Vector2(sx - 30.0 * ff, sy - 22.0 * ff), Vector2(sx + 2, sy - 7)]), Color(1.0, 0.45, 0.1, 0.9))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 3, sy - 5), Vector2(sx - 16.0 * ff, sy - 14.0 * ff), Vector2(sx, sy - 6)]), Color(1.0, 0.92, 0.5))
				else:
					var ph := fmod(t * 0.9 + k * 0.5, 1.0)
					ci.draw_circle(Vector2(sx - 3.0 - ph * 10.0, sy - 8.0 - ph * 24.0), 3.0 + ph * 6.0, Color(0.16, 0.15, 0.16, 0.45 * (1.0 - ph)))
		"shield":
			_ln(ci, Vector2(bx - 6, top + 40), Vector2(bx - 14, top - 18), c.darkened(0.3), 4.0)
			_arc(ci, Vector2(bx - 14, top - 18), 14.0, PI * 0.6, PI * 1.6, 12, c, 5.0)
			ci.draw_circle(Vector2(bx - 14, top - 18), 4.0, Color(0.6, 0.9, 1.0, 0.6 + 0.4 * sin(t * 6.0)))


# ---- legs
static func _draw_leg(ci: CanvasItem, look: Dictionary, slot: String, hip: Vector2, L: float, pose: String,
		swing: float, back: bool, flash: bool, trim: Color, aim: float = 0.0, drop: float = 0.0) -> void:
	var p := _part(look, slot)
	if not p.get("alive", false):
		_stump(ci, hip, -1.0 if look.get("icon", false) else 0.0)
		return
	var dims: Array = LEGS.get(p["shape"], LEGS["rod"])
	var arm_leg := str(p.get("swap", "")) == "arm"   # an arm doing a leg's job: it walks on its fist
	if arm_leg:
		dims = [60.0, ARMS.get(p["shape"], ARMS["rod"])[0] * 1.1]
	var sz: float = p["size"]
	var th: float = dims[1] * sz
	var own_len := leg_len_of(look, slot)
	var foot := leg_pose_foot(hip, pose, swing, aim, own_len, drop)
	var c := _col(p, flash, back)
	var tc := trim.darkened(0.3) if back else trim
	var dir := (foot - hip).normalized()
	var perp := dir.orthogonal()
	# the knee: two equal bones, bent forward when the foot comes in closer than the leg is long
	var knee := ik_joint(hip, foot, own_len * 0.5, own_len * 0.5, hip.lerp(foot, 0.5) + Vector2(8.0, 0.0))
	_grade = int(p.get("grade", 3))
	if arm_leg:
		_limb(ci, hip, knee, c, th)
		_limb(ci, knee, foot + Vector2(0, -9), c, th * 0.9)
		_joint(ci, knee, th * 0.5, c.darkened(0.25))
		_joint(ci, hip, th * 0.5, c.darkened(0.3))
		var fr: float = ARMS.get(p["shape"], ARMS["rod"])[1] * sz
		_round(ci, foot + Vector2(0, -maxf(fr, 7.0)), maxf(fr, 7.0), tc)   # the fist it stands on
		_damage_marks(ci, hip, foot, p.get("health", 1.0), 0.0)
		return
	match p["shape"]:
		"spring":
			_ln(ci, hip, foot, c.darkened(0.3), 3.0)
			var pts := PackedVector2Array()
			for k in 11:
				var f := k / 10.0
				var off := (perp * th * (1 if k % 2 else -1)) if k > 0 and k < 10 else Vector2.ZERO
				pts.append(hip.lerp(foot, f) + off)
			_pl(ci, pts, c, 4.0)
		"reverse":
			# (1.90) seen from the front the first bend goes outward, away from the other leg
			var ks := -1.0 if _front_legs else 1.0
			var k1 := hip.lerp(foot, 0.35) - perp * 14.0 * ks
			var k2 := hip.lerp(foot, 0.75) + (perp * 14.0 if not _front_legs else -perp * 6.0)   # front: both bends bow outward
			_limb(ci, hip, k1, c, th * 1.2)
			_limb(ci, k1, k2, c, th * 0.9)
			_limb(ci, k2, foot, c, th * 0.7)
			_joint(ci, k1, th * 0.6, c.darkened(0.25))
			_joint(ci, k2, th * 0.45, c.darkened(0.25))
		"pillar":
			_limb(ci, hip, foot, c, th)
			ci.draw_line(hip.lerp(foot, 0.3) - perp * th * 0.5, hip.lerp(foot, 0.3) + perp * th * 0.5, c.darkened(0.3), 3.0)
			ci.draw_line(hip.lerp(foot, 0.7) - perp * th * 0.5, hip.lerp(foot, 0.7) + perp * th * 0.5, c.darkened(0.3), 3.0)
		"piston":
			_limb(ci, hip, knee, c, th * 1.2)
			_limb(ci, knee, foot, c.darkened(0.2), th * 0.6)
			_limb(ci, knee, knee.lerp(foot, 0.6), c, th)
			_joint(ci, knee, th * 0.55, c.darkened(0.3))
		"thick":
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot, c, th * 0.9)
			_joint(ci, knee, th * 0.6, tc)
		"blade":
			_limb(ci, hip, knee, c, th * 1.2)
			var pts := PackedVector2Array()
			for k in 8:
				var f := k / 7.0
				pts.append(knee.lerp(foot, f) + perp * sin(f * PI) * 14.0)
			_pl(ci, pts, tc.darkened(0.15), 6.0)
		"hover":
			_limb(ci, hip, foot + Vector2(0, -14), c, th)
			_plate(ci, _chamfer(Rect2(foot.x - 12.0, foot.y - 20.0, 24.0, 10.0), 3.0), c.darkened(0.3))
		"spider":
			var up := hip + Vector2(16.0, -22.0) if pose == "stand" else hip.lerp(foot, 0.4) - perp * 20.0
			_limb(ci, hip, up, c, th)
			_limb(ci, up, foot, c, th * 0.8)
			_joint(ci, up, th * 0.6, c.darkened(0.3))
		"pogo":
			var mid := hip.lerp(foot, 0.45)
			_limb(ci, hip, mid, c, th * 1.3)
			var pts := PackedVector2Array()
			for k in 9:
				var f := k / 8.0
				pts.append(mid.lerp(foot, f) + perp * (9.0 if k % 2 else -9.0) * (0.0 if k == 0 or k == 8 else 1.0))
			_ln(ci, mid, foot, c.darkened(0.3), 3.0)
			_pl(ci, pts, tc, 3.0)
		"wheel":
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -12), c, th * 0.8)
		"tread":
			_limb(ci, hip, foot + Vector2(0, -10), c, th)
		"stomper":
			# (1.97) Old Iron: a thick leg with a ram at the ankle
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -10), c, th * 0.85)
			_ln(ci, knee + perp * th * 0.6, foot + Vector2(0, -12) + perp * th * 0.6, c.darkened(0.35), 4.0)
			_joint(ci, knee, th * 0.62, c.darkened(0.2))
			_hexbolt(ci, knee, 3.0)
		"bellows":
			# (1.98) Brassworks: a brass thigh and an accordion bellows shin
			_limb(ci, hip, knee, c, th)
			var bp := PackedVector2Array()
			for k in 9:
				var f3 := k / 8.0
				bp.append(knee.lerp(foot + Vector2(0, -6), f3) + perp * th * (0.75 if k % 2 == 0 else 0.35) )
			for k in 9:
				var f4 := 1.0 - k / 8.0
				bp.append(knee.lerp(foot + Vector2(0, -6), f4) - perp * th * (0.75 if (8 - k) % 2 == 0 else 0.35))
			_plate(ci, bp, Color(0.36, 0.26, 0.18))
			_joint(ci, knee, th * 0.6, c.darkened(0.2))
		"tripod":
			# (1.98) Brassworks: a telescoping brass strut
			_limb(ci, hip, knee, c, th * 1.2)
			_limb(ci, knee, foot + Vector2(0, -4), c.lightened(0.15), th * 0.7)
			_ln(ci, knee.lerp(foot, 0.3) - perp * th * 0.5, knee.lerp(foot, 0.3) + perp * th * 0.5, c.darkened(0.35), 3.0)
			_joint(ci, knee, th * 0.6, c.darkened(0.25))
		"gear":
			# (1.101) Nimbus: a landing gear leg, a chrome oleo strut with a torque link at the knee
			_limb(ci, hip, knee, c, th)
			var axle := foot + Vector2(0, -9)
			_limb(ci, knee, knee.lerp(axle, 0.55), c.darkened(0.1), th * 1.05)
			_limb(ci, knee.lerp(axle, 0.5), axle, Color(0.85, 0.87, 0.9), th * 0.5)
			_pl(ci, PackedVector2Array([knee + perp * th * 0.5, knee.lerp(axle, 0.32) + perp * th * 1.1, knee.lerp(axle, 0.6) + perp * th * 0.4]), Color(0.45, 0.47, 0.5), 2.5)
			_joint(ci, knee, th * 0.55, c.darkened(0.25))
			ci.draw_circle(hip.lerp(knee, 0.5) - perp * th * 0.5, 2.0, Color(0.2, 1.0, 0.4) if fmod(Time.get_ticks_msec() * 0.0012, 1.0) < 0.5 else Color(0.1, 0.4, 0.15))   # nav light
		"ductfan":
			# (1.101) Nimbus: a slim leg on a ducted fan that holds it a little off the floor
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -16), c.darkened(0.05), th * 0.75)
			_joint(ci, knee, th * 0.55, c.darkened(0.25))
		"hotrod":
			# (1.100) Volta: a chrome coilover, a hot red spring round the shock
			_limb(ci, hip, knee, c, th)
			var sh_end := foot + Vector2(0, -8)
			_limb(ci, knee, sh_end, Color(0.82, 0.85, 0.9), th * 0.42)
			var pts2 := PackedVector2Array()
			for k in 11:
				var f5 := k / 10.0
				var q5 := knee.lerp(sh_end, 0.08 + f5 * 0.78)
				pts2.append(q5 + perp * th * (0.62 if k % 2 == 0 else -0.62))
			ci.draw_polyline(pts2, OUTLINE, 5.0)
			ci.draw_polyline(pts2, Color(0.9, 0.15, 0.2), 3.0)
			ci.draw_line(hip.lerp(knee, 0.2), hip.lerp(knee, 0.85), Color(0.0, 0.85, 1.0, 0.85), 2.0)   # racing stripe
			_joint(ci, knee, th * 0.55, c.darkened(0.3))
		"maglev":
			# (1.100) Volta: a sleek leg on a magnetic skid that floats over the floor
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -16), c.lightened(0.2), th * 0.75)
			ci.draw_line(hip.lerp(knee, 0.15), knee.lerp(foot, 0.7), Color(1.0, 0.3, 0.7, 0.8), 2.0)
			_joint(ci, knee, th * 0.55, c.darkened(0.3))
		"excavator":
			# (1.99) Hellfire: an excavator's boom for a thigh, a hydraulic ram along it, and a track unit for a foot
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -16), c, th * 0.8)
			_ln(ci, hip.lerp(knee, 0.15) + perp * th * 0.7, knee.lerp(foot, 0.6) + perp * th * 0.6, Color(0.2, 0.2, 0.22), 5.0)
			_ln(ci, knee + perp * th * 0.66, knee.lerp(foot, 0.6) + perp * th * 0.6, Color(0.82, 0.84, 0.88), 2.5)
			_joint(ci, knee, th * 0.55, c.darkened(0.25))
		"hydraulic":
			# (1.99) Hellfire: a big hydraulic cylinder and a chrome ram that telescopes into a stamping pad
			_limb(ci, hip, knee, c, th)
			var rod_end := foot + Vector2(0, -8)
			_limb(ci, knee, knee.lerp(rod_end, 0.5), c.darkened(0.15), th * 1.1)
			_limb(ci, knee.lerp(rod_end, 0.45), rod_end, Color(0.82, 0.84, 0.88), th * 0.45)
			for k in 3:
				var hq := hip.lerp(knee, 0.25 + k * 0.22)
				ci.draw_line(hq - perp * th * 0.45, hq + perp * th * 0.45, Color(0.08, 0.08, 0.08) if k % 2 == 0 else Color(0.95, 0.75, 0.1), 3.0)
			_joint(ci, knee, th * 0.6, c.darkened(0.3))
		"pipe":
			# (1.97) Scrapworks: plumbing, with an elbow fitting for a knee
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot + Vector2(0, -6), c, th)
			for f2 in [0.5]:
				var q := hip.lerp(knee, f2)
				_ln(ci, q - perp * th * 0.62, q + perp * th * 0.62, c.darkened(0.3), 4.0)
			var q2 := knee.lerp(foot, 0.55)
			_ln(ci, q2 - perp * th * 0.62, q2 + perp * th * 0.62, c.darkened(0.3), 4.0)
			_plate(ci, _chamfer(Rect2(knee - Vector2(th * 0.7, th * 0.7), Vector2(th * 1.4, th * 1.4)), 3.0), c.darkened(0.15))
		_:
			_limb(ci, hip, knee, c, th)
			_limb(ci, knee, foot, c, th * 0.85)
			_joint(ci, knee, th * 0.5, c.darkened(0.25))
	_joint(ci, hip, th * 0.5, c.darkened(0.3))
	# foot
	var fw := 26.0 * maxf(sz, 0.8)
	if p["shape"] == "pillar":
		fw = 36.0
	if p["shape"] == "wheel":
		var wc := foot + Vector2(0, -12)
		ci.draw_circle(wc, 14.0 if _lit() else 13.0, OUTLINE if _lit() else Color(0.12, 0.12, 0.14))
		ci.draw_circle(wc, 13.0, Color(0.12, 0.12, 0.14))
		_round(ci, wc, 6.0, tc)
		var a := -foot.x * 0.15
		ci.draw_line(wc + Vector2(cos(a), sin(a)) * 11.0, wc - Vector2(cos(a), sin(a)) * 11.0, tc.darkened(0.3), 2.0)
	elif p["shape"] == "tread":
		var tr := Rect2(foot.x - 22.0, foot.y - 18.0, 46.0, 18.0)
		_box(ci, tr, Color(0.15, 0.15, 0.17))
		for k in 6:
			ci.draw_line(Vector2(tr.position.x + 4 + k * 8, tr.position.y), Vector2(tr.position.x + 4 + k * 8, tr.end.y), Color(0.3, 0.3, 0.32), 2.0)
		_joint(ci, Vector2(tr.position.x + 8, tr.get_center().y), 5.0, tc)
		_joint(ci, Vector2(tr.end.x - 8, tr.get_center().y), 5.0, tc)
	elif p["shape"] == "pogo":
		_box(ci, Rect2(foot.x - 14.0, foot.y - 6.0, 28.0, 6.0), Color(0.15, 0.15, 0.17))
	elif p["shape"] == "tripod":
		# three toes spread on the floor
		for dx in [-12.0, 2.0, 16.0]:
			_ln(ci, foot + Vector2(2, -5), foot + Vector2(dx, 0), tc, 3.5)
		_joint(ci, foot + Vector2(2, -5), 4.0, tc.darkened(0.2))
	elif p["shape"] == "gear":
		# a pair of small tyres on the axle
		var ax := foot + Vector2(0, -9)
		for wx in [-7.0, 7.0]:
			ci.draw_circle(ax + Vector2(wx, 0), 9.5, OUTLINE)
			ci.draw_circle(ax + Vector2(wx, 0), 8.5, Color(0.12, 0.12, 0.14))
			ci.draw_circle(ax + Vector2(wx, 0), 3.5, Color(0.8, 0.82, 0.86))
	elif p["shape"] == "ductfan":
		# the shroud seen edge on, the blades a blur inside, a downdraft under it
		var dc2 := foot + Vector2(4, -12)
		_plate(ci, _rounded(Rect2(dc2.x - 18, dc2.y - 6, 36, 12), 5.0), c if not flash else Color.WHITE)
		ci.draw_rect(Rect2(dc2.x - 14, dc2.y - 2, 28, 4), Color(0.15, 0.17, 0.2))
		var bl2 := fmod(Time.get_ticks_msec() * 0.025, 1.0)
		ci.draw_line(Vector2(dc2.x - 13 + bl2 * 26, dc2.y - 2), Vector2(dc2.x - 13 + bl2 * 26, dc2.y + 2), Color(0.8, 0.85, 0.9), 2.0)
		ci.draw_line(Vector2(dc2.x - 16, dc2.y - 6), Vector2(dc2.x + 16, dc2.y - 6), Color(0.3, 0.6, 1.0), 1.5)
		for k in 3:
			var ph3 := fmod(Time.get_ticks_msec() * 0.002 + k * 0.33, 1.0)
			ci.draw_line(Vector2(dc2.x - 10 + k * 10, dc2.y + 6 + ph3 * 6), Vector2(dc2.x - 10 + k * 10, dc2.y + 9 + ph3 * 6), Color(0.85, 0.92, 1.0, 0.5 * (1.0 - ph3)), 2.0)
	elif p["shape"] == "maglev":
		# the skid hovers a hand over the floor, magnet light under it
		var lift := 6.0 + 2.0 * sin(Time.get_ticks_msec() * 0.006 + foot.x * 0.1)
		var sk2 := PackedVector2Array([foot + Vector2(-16, -14 - lift + 6), foot + Vector2(22, -14 - lift + 6), foot + Vector2(28, -6 - lift + 6), foot + Vector2(-14, -4 - lift + 6)])
		_plate(ci, sk2, Color(0.82, 0.85, 0.9) if not flash else Color.WHITE)
		ci.draw_line(foot + Vector2(-12, -6 - lift + 6), foot + Vector2(24, -6 - lift + 6), Color(0.0, 0.9, 1.0), 2.0)
		for k in 3:
			ci.draw_line(foot + Vector2(-8 + k * 12, -3 - lift + 6), foot + Vector2(-8 + k * 12, 2), Color(0.3, 0.85, 1.0, 0.35), 3.0)
	elif p["shape"] == "hotrod":
		_plate(ci, _chamfer(Rect2(foot.x - 10.0, foot.y - 8.0, 26.0, 8.0), 3.0), Color(0.15, 0.15, 0.17))
		ci.draw_line(Vector2(foot.x - 8, foot.y - 2), Vector2(foot.x + 14, foot.y - 2), Color(0.95, 0.95, 0.95, 0.7), 2.0)
	elif p["shape"] == "excavator":
		# a yellow-framed track unit: black links, rollers, a hazard edge
		var er := Rect2(foot.x - 24.0, foot.y - 22.0, 52.0, 22.0)
		_plate(ci, _rounded(er, 10.0), Color(0.12, 0.12, 0.13))
		for k in 7:
			var lx := er.position.x + 5.0 + k * 7.0 + fmod(-foot.x * 0.3, 7.0)
			if lx < er.end.x - 3.0:
				ci.draw_line(Vector2(lx, er.position.y + 1), Vector2(lx, er.position.y + 4), Color(0.32, 0.32, 0.34), 2.0)
				ci.draw_line(Vector2(lx, er.end.y - 4), Vector2(lx, er.end.y - 1), Color(0.32, 0.32, 0.34), 2.0)
		_plate(ci, _chamfer(Rect2(er.position.x + 6, er.position.y + 5, er.size.x - 12, er.size.y - 10), 3.0), tc if not flash else Color.WHITE)
		for k in 3:
			_joint(ci, Vector2(er.position.x + 13 + k * 13.0, er.get_center().y), 3.5, Color(0.2, 0.2, 0.22))
	elif p["shape"] == "hydraulic":
		# a stamping pad
		var hp2 := Rect2(foot.x - 16.0, foot.y - 9.0, 34.0, 9.0)
		_plate(ci, _chamfer(hp2, 2.0), Color(0.28, 0.28, 0.3))
		ci.draw_line(Vector2(hp2.position.x + 3, hp2.position.y + 2), Vector2(hp2.end.x - 3, hp2.position.y + 2), Color(0.95, 0.75, 0.1), 2.0)
	elif p["shape"] == "stomper":
		# a huge cast boot that kicks and stamps flat
		var bt := Rect2(foot.x - 16.0, foot.y - 14.0, 40.0, 14.0)
		_plate(ci, _chamfer(bt, 3.0), tc.darkened(0.15))
		_hexbolt(ci, Vector2(bt.position.x + 6, bt.position.y + 5), 2.5)
		_hexbolt(ci, Vector2(bt.end.x - 6, bt.position.y + 5), 2.5)
	elif p["shape"] == "hover":
		var gl := 0.6 + 0.4 * sin(foot.x * 0.3 + Time.get_ticks_msec() * 0.02)
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-10, -10), foot + Vector2(10, -10), foot + Vector2(0, 6.0 + 8.0 * gl)]), Color(0.4, 0.8, 1.0, 0.8))
	elif p["shape"] == "spider":
		_pl(ci, PackedVector2Array([foot + Vector2(-6, 4), foot, foot + Vector2(10, 4)]), tc, 4.0)
	elif p["shape"] == "blade":
		_ln(ci, foot + Vector2(-4, 0), foot + Vector2(18, 0), tc, 4.0)
	elif (LEG_HITS.has(pose) and pose != "knee") or pose == "fly_kick":
		_plate(ci, _chamfer(Rect2(foot.x - 2.0, foot.y - 12.0, 12.0, 22.0), 3.0), tc)
	elif p["shape"] == "reverse":
		_plate(ci, PackedVector2Array([foot + Vector2(-8, 0), foot + Vector2(22, 0), foot + Vector2(-2, -10)]), tc)
	else:
		_plate(ci, _chamfer(Rect2(foot.x - fw * 0.3, foot.y - 8.0, fw, 8.0), 3.0), tc)
	_finish_limb(ci, hip, knee, p, th, 0.0)
	_damage_marks(ci, hip, foot, p.get("health", 1.0), 0.0)


# ---- torso
static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.position.x + rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.end.x - rad, r.end.y - rad)]
	for k in 4:
		for j in 5:
			var a := -PI / 2.0 * k - PI / 2.0 * j / 4.0
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _draw_torso(ci: CanvasItem, look: Dictionary, g: Dictionary, flash: bool, trim: Color, eye: Color, t: float, front: bool = false) -> void:
	var p := _part(look, "torso")
	if not p.get("alive", false):
		return
	var r: Rect2 = g["torso"]
	var c := _col(p, flash, false)
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var w := r.size.x
	var chest := Vector2(r.get_center().x + (0.0 if front else w * 0.1), y0 + r.size.y * 0.38)
	_grade = int(p.get("grade", 3))
	var plate := _chamfer(r)   # machined plates: the corners cut off
	match p["shape"]:
		"barrel":
			_plate(ci, _rounded(r, w * 0.3), c)
			ci.draw_line(Vector2(x0 + 4, y0 + r.size.y * 0.25), Vector2(x1 - 4, y0 + r.size.y * 0.25), trim, 4.0)
			ci.draw_line(Vector2(x0 + 4, y0 + r.size.y * 0.75), Vector2(x1 - 4, y0 + r.size.y * 0.75), trim, 4.0)
		"vee":
			_plate(ci, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - w * 0.2, y1), Vector2(x0 + w * 0.2, y1)]), c)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 12), 3.0), trim)
			ci.draw_line(Vector2(x0 + w * 0.2, y1 - 6), Vector2(x1 - w * 0.2, y1 - 6), trim, 6.0)
		"tank":
			_plate(ci, plate, c)
			_plate(ci, _chamfer(Rect2(x0 - 6, y0 - 4, w + 12, 16), 3.0), trim)
			for row in 3:
				for col in 4:
					ci.draw_circle(Vector2(x0 + 10 + col * (w - 20) / 3.0, y0 + 24 + row * (r.size.y - 34) / 2.0), 2.5, c.darkened(0.4))
			ci.draw_line(Vector2(x0, y0 + r.size.y * 0.55), Vector2(x1, y0 + r.size.y * 0.55), c.darkened(0.3), 3.0)
		"crate":
			_plate(ci, plate, c)
			ci.draw_rect(r, c.darkened(0.4), false, 3.0)
			ci.draw_line(r.position, r.end, c.darkened(0.3), 4.0)
			ci.draw_line(Vector2(x1, y0), Vector2(x0, y1), c.darkened(0.3), 4.0)
			_plate(ci, _chamfer(Rect2(x0 + w * 0.3, y0 + 8, w * 0.4, 10), 3.0), trim)
		"furnace":
			_plate(ci, plate, c)
			_bolts(ci, r)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 10), 3.0), trim)
			var grill := Rect2(x0 + w * 0.2, y0 + r.size.y * 0.45, w * 0.6, r.size.y * 0.35)
			ci.draw_rect(grill, Color(0.08, 0.05, 0.03))
			var fire := 0.6 + 0.4 * sin(t * 15.0)
			ci.draw_rect(grill.grow(-4.0), Color(1.0, 0.45 * fire, 0.1, 0.9))
			for k in 4:
				ci.draw_line(Vector2(grill.position.x + 4 + k * grill.size.x / 4.0, grill.position.y), Vector2(grill.position.x + 4 + k * grill.size.x / 4.0, grill.end.y), Color(0.15, 0.15, 0.15), 3.0)
			_box(ci, Rect2(x1 - 14, y0 - 22, 10, 24), c.darkened(0.3))   # chimney
		"orb":
			var oc := r.get_center()
			_round(ci, oc, minf(w, r.size.y) * 0.5, c)
			ci.draw_arc(oc, minf(w, r.size.y) * 0.5, PI * 1.1, PI * 1.9, 14, trim, 5.0)
			ci.draw_line(Vector2(oc.x - w * 0.45, oc.y), Vector2(oc.x + w * 0.45, oc.y), c.darkened(0.3), 3.0)
		"yoke", "quad", "monster":
			_plate(ci, plate, c)
			_bolts(ci, r)
			_plate(ci, _chamfer(Rect2(x0 - 8, y0 - 4, w + 16, 16), 3.0), trim)
			_plate(ci, _chamfer(Rect2(x0 + 6, y1 - 16, w - 12, 12), 3.0), trim.darkened(0.2))
			ci.draw_rect(Rect2(x0 + w * 0.3, y0 + 20, w * 0.4, r.size.y * 0.45), c.darkened(0.25))
			if p["shape"] != "yoke":
				_plate(ci, _chamfer(Rect2(x0 - 6, y0 + r.size.y * 0.5, w + 12, 10), 3.0), trim.darkened(0.1))   # second shoulder bar
			if p["shape"] == "monster":
				for k in 4:
					_poly(ci, PackedVector2Array([Vector2(x0 + 8 + k * (w - 16) / 3.0 - 6, y0 - 4), Vector2(x0 + 8 + k * (w - 16) / 3.0, y0 - 18), Vector2(x0 + 8 + k * (w - 16) / 3.0 + 6, y0 - 4)]), trim)
		"ribcage":
			_plate(ci, _chamfer(Rect2(x0 + w * 0.42, y0, w * 0.16, r.size.y), 3.0), c.darkened(0.2))
			for k in 5:
				var y := y0 + 8 + k * (r.size.y - 16) / 4.0
				_limb(ci, Vector2(x0, y), Vector2(x1, y), c, 7.0)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 10), 3.0), trim)
		"hex":
			var hc := r.get_center()
			var hp_pts := PackedVector2Array()
			for k in 6:
				var a := PI / 6.0 + k * TAU / 6.0
				hp_pts.append(hc + Vector2(cos(a) * w * 0.55, sin(a) * r.size.y * 0.55))
			_plate(ci, hp_pts, c)
			hp_pts.append(hp_pts[0])
			ci.draw_polyline(hp_pts, trim, 4.0)
			ci.draw_line(hc - Vector2(w * 0.3, 0), hc + Vector2(w * 0.3, 0), c.darkened(0.35), 3.0)
		"cannon":
			_plate(ci, plate, c)
			_bolts(ci, r)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 12), 3.0), trim)
			if front:
				# the cannon's muzzle, looking straight at you
				var m := Vector2(r.get_center().x, y0 + r.size.y * 0.66)
				_disc(ci, m, 13.0, c.darkened(0.3))
				ci.draw_circle(m, 9.0, Color(0.08, 0.08, 0.08))
				ci.draw_arc(m, 9.0, 0, TAU, 16, trim, 3.0)
			else:
				var mouth := Vector2(x1, y0 + r.size.y * 0.5)
				_box(ci, Rect2(x1 - 10, mouth.y - 11, 26, 22), c.darkened(0.3))
				ci.draw_circle(mouth + Vector2(16, 0), 10.0, Color(0.08, 0.08, 0.08))
				ci.draw_arc(mouth + Vector2(16, 0), 10.0, 0, TAU, 16, trim, 3.0)
		"slim":
			_plate(ci, plate, c)
			ci.draw_line(Vector2(x0, y1 - 10), Vector2(x1, y0 + 20), trim, 5.0)
			_plate(ci, _chamfer(Rect2(x0 - 3, y0, w + 6, 8), 3.0), trim)
		"core":
			_plate(ci, plate, c)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 12), 3.0), trim)
			_plate(ci, _chamfer(Rect2(x0, y1 - 12, w, 10), 3.0), trim)
			var pulse := 0.85 + 0.15 * sin(t * 4.0)
			ci.draw_circle(chest + Vector2(0, 6), w * 0.27, c.darkened(0.45))
			_glow(ci, chest + Vector2(0, 6), w * 0.2, eye)
			ci.draw_circle(chest + Vector2(0, 6), w * 0.2 * pulse, eye)
			ci.draw_circle(chest + Vector2(0, 6), w * 0.09, Color(1, 1, 1, 0.8))
		"engine":
			# (1.97) Old Iron: an engine block, two valve covers on top, cooling fins, a pulley and its belt
			_plate(ci, plate, c)
			for k in 2:
				var vr := Rect2(x0 + w * (0.06 + 0.48 * k), y0 - 10.0, w * 0.42, 14.0)
				_plate(ci, _chamfer(vr, 4.0), trim)
				ci.draw_circle(vr.get_center() + Vector2(w * 0.08, -1.0), 2.5, trim.darkened(0.45))
			for k in 6:
				var fy := y0 + r.size.y * (0.22 + k * 0.08)
				ci.draw_line(Vector2(x0 + 5, fy), Vector2(x1 - 5, fy), c.darkened(0.32), 2.0)
			var pc := Vector2(r.get_center().x if front else x1 - w * 0.2, y1 - r.size.y * 0.2)
			_disc(ci, pc, w * 0.13, trim.darkened(0.15))
			ci.draw_circle(pc, w * 0.05, c.darkened(0.4))
			_ln(ci, pc + Vector2(-w * 0.13, 0), pc + Vector2(-w * 0.09, -r.size.y * 0.42), Color(0.12, 0.12, 0.13), 3.0)
			if not front:
				_limb(ci, Vector2(x0 + 6, y0 + 8), Vector2(x0 - 6, y0 + r.size.y * 0.55), Color(0.36, 0.3, 0.27), 7.0)   # exhaust
			for bp in [Vector2(x0 + 6, y1 - 7), Vector2(x1 - 6, y1 - 7), Vector2(x0 + 6, y0 + 7), Vector2(x1 - 6, y0 + 7)]:
				_hexbolt(ci, bp, 3.2)
		"loco":
			# (1.97) Old Iron: a locomotive's front, the round smokebox door, headlamp and cowcatcher
			_plate(ci, _rounded(r, w * 0.18), c)
			var sbc := Vector2(r.get_center().x if front else x1 - w * 0.12, y0 + r.size.y * 0.42)
			var sbr := r.size.y * 0.27
			_round(ci, sbc, sbr, c.darkened(0.28))
			ci.draw_arc(sbc, sbr * 0.82, 0, TAU, 24, trim, 3.0)
			ci.draw_circle(sbc, 3.5, trim)
			ci.draw_line(sbc, sbc + Vector2(sbr * 0.8, 0), trim.darkened(0.2), 2.5)
			var lamp := sbc + Vector2(0, -sbr - 7.0)
			_disc(ci, lamp, 7.0, trim.darkened(0.2))
			_glow(ci, lamp, 5.0, Color(1.0, 0.88, 0.5))
			ci.draw_circle(lamp, 4.5, Color(1.0, 0.92, 0.6))
			_plate(ci, _chamfer(Rect2(sbc.x - 9, sbc.y + sbr * 0.4, 18, 8), 2.0), Color(0.85, 0.7, 0.3))   # brass number plate
			var cw := w * 0.5
			var cx := r.get_center().x if front else x1 - cw * 0.5
			var cow := PackedVector2Array([Vector2(cx - cw * 0.5, y1 - 14), Vector2(cx + cw * 0.5, y1 - 14), Vector2(cx + cw * 0.5 + (0.0 if front else 10.0), y1 + 2), Vector2(cx - cw * 0.5 - (6.0 if front else 0.0), y1 + 2)])
			_plate(ci, cow, Color(0.22, 0.22, 0.24))
			for k in 5:
				var bx2 := cx - cw * 0.4 + k * cw * 0.2
				ci.draw_line(Vector2(bx2, y1 - 12), Vector2(bx2 + (0.0 if front else 4.0), y1), Color(0.5, 0.5, 0.52), 2.0)
		"boiler":
			# (1.98) Brassworks: an upright copper boiler, riveted bands, the firebox glowing, a gauge
			_plate(ci, _rounded(r, w * 0.28), c)
			for k in 3:
				var ry2 := y0 + r.size.y * (0.12 + k * 0.38)
				ci.draw_line(Vector2(x0 + 3, ry2), Vector2(x1 - 3, ry2), Color(0.8, 0.64, 0.2), 4.0)
				for q in 5:
					ci.draw_circle(Vector2(x0 + 8 + q * (w - 16) / 4.0, ry2), 1.6, Color(0.45, 0.32, 0.12))
			var fb := Rect2(r.get_center().x - w * (0.2 if front else 0.05), y0 + r.size.y * 0.6, w * 0.4, r.size.y * 0.22)
			_plate(ci, _chamfer(fb, 3.0), Color(0.2, 0.17, 0.15))
			var fire := 0.6 + 0.4 * sin(t * 9.0)
			ci.draw_rect(fb.grow(-4.0), Color(1.0, 0.42 * fire + 0.2, 0.08, 0.9))
			for k in 3:
				ci.draw_line(Vector2(fb.position.x + 6 + k * (fb.size.x - 12) / 2.0, fb.position.y + 3), Vector2(fb.position.x + 6 + k * (fb.size.x - 12) / 2.0, fb.end.y - 3), Color(0.15, 0.12, 0.1), 2.0)
			var gp := Vector2(r.get_center().x + (0.0 if front else w * 0.12), y0 + r.size.y * 0.32)
			_disc(ci, gp, w * 0.15, Color(0.8, 0.64, 0.2))
			ci.draw_circle(gp, w * 0.11, Color(0.95, 0.92, 0.82))
			var na := -2.2 + 2.6 * (0.5 + 0.5 * sin(t * 0.6))
			ci.draw_line(gp, gp + Vector2(cos(na), sin(na)) * w * 0.1, Color(0.6, 0.1, 0.08), 2.0)
			if not front:
				_limb(ci, Vector2(x0 + 6, y0 + 6), Vector2(x0 - 4, y0 - 12), Color(0.3, 0.24, 0.18), 6.0)   # a steam pipe
		"clockwork":
			# (1.98) Brassworks: a cage of brass bars with the gears turning inside
			_plate(ci, plate, c.darkened(0.45))
			var gears := [[Vector2(0.38, 0.38), 0.22, 1.0], [Vector2(0.66, 0.56), 0.17, -1.4], [Vector2(0.4, 0.74), 0.14, 1.8]]
			for gq in gears:
				var gc2 := Vector2(x0 + w * float((gq[0] as Vector2).x), y0 + r.size.y * float((gq[0] as Vector2).y))
				var gr2 := w * float(gq[1])
				var spin2 := t * float(gq[2])
				var teeth := PackedVector2Array()
				for k in 24:
					var a2 := spin2 + k * TAU / 24.0
					teeth.append(gc2 + Vector2(cos(a2), sin(a2)) * gr2 * (1.0 if k % 2 == 0 else 0.82))
				_poly(ci, teeth, Color(0.85, 0.68, 0.22))
				ci.draw_circle(gc2, gr2 * 0.35, c.darkened(0.5))
			for k in 5:
				var bxk := x0 + 4 + k * (w - 8) / 4.0
				_ln(ci, Vector2(bxk, y0 + 3), Vector2(bxk, y1 - 3), c, 3.5)
			_plate(ci, _chamfer(Rect2(x0 - 3, y0 - 2, w + 6, 9), 2.0), trim)
			_plate(ci, _chamfer(Rect2(x0 - 3, y1 - 8, w + 6, 9), 2.0), trim)
		"fuselage":
			# (1.101) Nimbus: a white fuselage section, rounded, a blue cheat line, portholes and a tail fin
			_plate(ci, _rounded(r, w * 0.42), c)
			var cl := y0 + r.size.y * 0.58
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 2, cl), Vector2(x1 - 2, cl), Vector2(x1 - 3, cl + 6), Vector2(x0 + 3, cl + 6)]), Color(0.2, 0.45, 0.9))
			for k in 3:
				var pw := Vector2(x0 + w * (0.25 + k * 0.25) + (0.0 if front else w * 0.04), y0 + r.size.y * 0.38)
				ci.draw_circle(pw, 4.2, OUTLINE)
				ci.draw_circle(pw, 3.4, Color(0.55, 0.75, 0.95))
			for k in 2:
				ci.draw_line(Vector2(x0 + 4, y0 + r.size.y * (0.2 + k * 0.6)), Vector2(x1 - 4, y0 + r.size.y * (0.2 + k * 0.6)), c.darkened(0.18), 1.5)
			if not front:
				_plate(ci, PackedVector2Array([Vector2(x0 + 6, y0 + 10), Vector2(x0 + 16, y0 + 4), Vector2(x0 - 6, y0 - 16), Vector2(x0 - 10, y0 - 14)]), c.darkened(0.08))
		"cryopod":
			# (1.101) Nimbus: a cryo pod, a frosted window with the blue cold inside, vents breathing frost
			_plate(ci, _rounded(r, w * 0.3), c.lightened(0.55))
			var wn := Rect2(x0 + w * 0.2, y0 + r.size.y * 0.18, w * 0.6, r.size.y * 0.5)
			_plate(ci, _rounded(wn, wn.size.x * 0.3), Color(0.2, 0.45, 0.75))
			ci.draw_rect(wn.grow(-wn.size.x * 0.22), Color(0.6, 0.85, 1.0, 0.35 + 0.15 * sin(t * 2.0)))
			for k in 4:
				ci.draw_line(wn.position + Vector2(5 + k * 6, 4), wn.position + Vector2(2 + k * 6, 14), Color(1, 1, 1, 0.35), 1.5)   # frost streaks
			for k in 3:
				var vy := y0 + r.size.y * (0.76 + k * 0.06)
				ci.draw_line(Vector2(x0 + w * 0.25, vy), Vector2(x1 - w * 0.25, vy), c.darkened(0.3), 2.0)
			var vph := fmod(t * 0.8, 1.0)
			ci.draw_circle(Vector2(x0 - 4 - vph * 10.0, y1 - 10 - vph * 8.0), 3.0 + vph * 6.0, Color(0.9, 0.96, 1.0, 0.4 * (1.0 - vph)))
		"biplane":
			# (1.101) Nimbus: a biplane's centre section, an upper and a lower wing stub with struts between
			_plate(ci, _rounded(r, w * 0.2), c)
			for k in 2:
				var wy2 := y0 + r.size.y * (0.12 + k * 0.62)
				_plate(ci, _chamfer(Rect2(x0 - 8, wy2, w + 16, 9), 3.0), c.darkened(0.1))
				ci.draw_line(Vector2(x0 - 8, wy2 + 1), Vector2(x1 + 8, wy2 + 1), Color(0.2, 0.45, 0.9), 2.0)
			for sx4 in [x0 + 3, x1 - 3]:
				_ln(ci, Vector2(sx4, y0 + r.size.y * 0.2), Vector2(sx4, y0 + r.size.y * 0.74), Color(0.55, 0.42, 0.28), 3.0)
			ci.draw_circle(Vector2(r.get_center().x, y0 + r.size.y * 0.45), 6.0, Color(0.2, 0.45, 0.9))
		"coupe":
			# (1.100) Volta: a chrome body shaped like a sports car's nose: a raked front, fins, a racing stripe, neon edge
			var cp2 := PackedVector2Array([Vector2(x0 + w * 0.08, y0), Vector2(x1 - w * 0.25, y0), Vector2(x1, y0 + r.size.y * 0.35),
					Vector2(x1 - w * 0.06, y1), Vector2(x0 + w * 0.12, y1), Vector2(x0, y0 + r.size.y * 0.45)])
			if front:
				cp2 = PackedVector2Array([Vector2(x0 + w * 0.14, y0), Vector2(x1 - w * 0.14, y0), Vector2(x1, y0 + r.size.y * 0.4),
						Vector2(x1 - w * 0.1, y1), Vector2(x0 + w * 0.1, y1), Vector2(x0, y0 + r.size.y * 0.4)])
			_plate(ci, cp2, c)
			var sx3 := r.get_center().x + (0.0 if front else w * 0.05)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx3 - 5, y0 + 1), Vector2(sx3 + 5, y0 + 1), Vector2(sx3 + 5, y1 - 1), Vector2(sx3 - 5, y1 - 1)]), Color(0.9, 0.15, 0.25))
			ci.draw_line(Vector2(sx3 - 8, y0 + 1), Vector2(sx3 - 8, y1 - 1), Color(0.95, 0.95, 0.98), 2.0)
			var nc := Color(0.0, 0.9, 1.0, 0.75 + 0.25 * sin(t * 6.0))
			ci.draw_line(Vector2(x0 + w * 0.12, y1 - 3), Vector2(x1 - w * 0.06, y1 - 3), nc, 2.5)
			if not front:
				_plate(ci, PackedVector2Array([Vector2(x0 + 2, y0 + 4), Vector2(x0 + 12, y0 + 2), Vector2(x0 - 8, y0 - 12)]), c.darkened(0.15))   # a tail fin
			ci.draw_line(Vector2(x0 + w * 0.2, y0 + 5), Vector2(x0 + w * 0.5, y0 + 5), Color(1, 1, 1, 0.55), 2.0)   # chrome glint
		"dynamo":
			# (1.100) Volta: a dynamo, copper windings turning in a dark frame, terminals sparking (extra power)
			_plate(ci, plate, c)
			var dw := Rect2(x0 + w * 0.14, y0 + r.size.y * 0.16, w * 0.72, r.size.y * 0.6)
			_plate(ci, _rounded(dw, dw.size.x * 0.3), Color(0.7, 0.4, 0.18))
			var roll := fmod(t * 3.0, 1.0)
			for k in 7:
				var yy := dw.position.y + 4.0 + fmod(k / 7.0 + roll / 7.0, 1.0) * (dw.size.y - 8.0)
				ci.draw_line(Vector2(dw.position.x + 4, yy), Vector2(dw.end.x - 4, yy), Color(0.45, 0.24, 0.1), 2.0)
			ci.draw_line(Vector2(dw.position.x + 6, dw.position.y + 6), Vector2(dw.position.x + 6, dw.end.y - 6), Color(1, 0.85, 0.6, 0.4), 2.0)
			for k in 2:
				var tp := Vector2(x0 + w * (0.28 + k * 0.44), y0 - 2.0)
				_plate(ci, _chamfer(Rect2(tp.x - 4, tp.y - 6, 8, 8), 1.5), Color(0.85, 0.85, 0.9))
			if fmod(t * 2.0, 1.0) < 0.3:
				ci.draw_polyline(PackedVector2Array([Vector2(x0 + w * 0.28, y0 - 8), Vector2(x0 + w * 0.42, y0 - 14), Vector2(x0 + w * 0.56, y0 - 7), Vector2(x0 + w * 0.72, y0 - 9)]), Color(0.6, 0.95, 1.0), 2.0)
			ci.draw_line(Vector2(x0 + 4, y1 - 6), Vector2(x1 - 4, y1 - 6), Color(1.0, 0.3, 0.7, 0.8), 2.0)
		"twincoil":
			# (1.100) Volta: a wide chrome yoke, a tesla coil insulator under each neck
			_plate(ci, _rounded(r, 12.0), c)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + w * 0.47, y0 + 1), Vector2(x0 + w * 0.53, y0 + 1), Vector2(x0 + w * 0.53, y1 - 1), Vector2(x0 + w * 0.47, y1 - 1)]), Color(0.9, 0.15, 0.25))
			for k in 2:
				var ix := x0 + w * (0.28 + k * 0.44)
				for j in 3:
					_disc(ci, Vector2(ix, y0 + 6 + j * 6.0), 6.0 - j, Color(0.92, 0.9, 0.85))
			ci.draw_line(Vector2(x0 + 6, y1 - 4), Vector2(x1 - 6, y1 - 4), Color(0.0, 0.9, 1.0, 0.8), 2.5)
		"fueltank":
			# (1.99) Hellfire: an upright fuel tank, red, two straps, a valve on top and the flame diamond
			_plate(ci, _rounded(r, w * 0.36), c)
			for k in 2:
				var sy2 := y0 + r.size.y * (0.24 + k * 0.5)
				_limb(ci, Vector2(x0 + 1, sy2), Vector2(x1 - 1, sy2), Color(0.2, 0.2, 0.22), 6.0)
				_hexbolt(ci, Vector2(x0 + w * 0.5, sy2), 2.6)
			_plate(ci, _chamfer(Rect2(x0 + w * 0.4, y0 - 9, w * 0.2, 10), 2.0), Color(0.62, 0.63, 0.67))
			_disc(ci, Vector2(x0 + w * 0.5, y0 - 11), 5.0, Color(0.85, 0.25, 0.15))
			var dc := Vector2(r.get_center().x + (0.0 if front else w * 0.12), y0 + r.size.y * 0.5)
			var dd := w * 0.17
			ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -dd), dc + Vector2(dd, 0), dc + Vector2(0, dd), dc + Vector2(-dd, 0)]), Color(0.98, 0.8, 0.15))
			ci.draw_polyline(PackedVector2Array([dc + Vector2(0, -dd), dc + Vector2(dd, 0), dc + Vector2(0, dd), dc + Vector2(-dd, 0), dc + Vector2(0, -dd)]), OUTLINE, 1.5)
			ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(-dd * 0.32, dd * 0.42), dc + Vector2(dd * 0.32, dd * 0.42), dc + Vector2(dd * 0.18, -dd * 0.1),
					dc + Vector2(0, -dd * 0.55), dc + Vector2(-dd * 0.1, -dd * 0.15), dc + Vector2(-dd * 0.25, 0)]), Color(0.1, 0.08, 0.08))
		"hull":
			# (1.99) Hellfire: a bulldozer's hull, thick plate, a hazard band, the push blade bolted across the front
			_plate(ci, plate, c)
			var hb2 := Rect2(x0 + 3, y1 - r.size.y * 0.26, w - 6, 11)
			ci.draw_rect(hb2, Color(0.95, 0.75, 0.1))
			for k in int(hb2.size.x / 12.0) + 1:
				var sx2 := hb2.position.x + k * 12.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sx2, hb2.end.y), Vector2(minf(sx2 + 6.0, hb2.end.x), hb2.end.y), Vector2(minf(sx2 + 12.0, hb2.end.x), hb2.position.y), Vector2(minf(sx2 + 6.0, hb2.end.x), hb2.position.y)]), Color(0.08, 0.08, 0.08))
			var bl := Rect2(x1 - 10.0, y0 + r.size.y * 0.22, 16.0, r.size.y * 0.7) if not front else Rect2(x0 - 4.0, y1 - 18.0, w + 8.0, 16.0)
			_plate(ci, _chamfer(bl, 3.0), Color(0.38, 0.38, 0.4))
			for k in 3:
				var hpnt := bl.position + (Vector2(bl.size.x * 0.5, bl.size.y * (0.2 + k * 0.3)) if not front else Vector2(bl.size.x * (0.2 + k * 0.3), bl.size.y * 0.5))
				_hexbolt(ci, hpnt, 2.6)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 12), 3.0), trim)
		"drum":
			# (1.97) Scrapworks: an oil drum, ribbed and dented, a bung on top
			_plate(ci, _rounded(r, w * 0.12), c)
			for k in 3:
				var ry := y0 + r.size.y * (0.18 + k * 0.32)
				_limb(ci, Vector2(x0 + 2, ry), Vector2(x1 - 2, ry), c.darkened(0.18), 5.0)
			_box(ci, Rect2(x0 + w * 0.62, y0 - 5, 8, 6), trim)
			ci.draw_rect(Rect2(x0 + w * 0.18, y0 + r.size.y * 0.38, w * 0.46, r.size.y * 0.17), Color(0.86, 0.74, 0.3, 0.75))
			ci.draw_line(Vector2(x0 + w * 0.22, y0 + r.size.y * 0.47), Vector2(x0 + w * 0.58, y0 + r.size.y * 0.47), Color(0.2, 0.15, 0.1, 0.7), 2.0)
			_dent(ci, Vector2(x0 + w * 0.32, y0 + r.size.y * 0.72), 6.0)
			_dent(ci, Vector2(x0 + w * 0.76, y0 + r.size.y * 0.3), 4.0)
		_:
			_plate(ci, plate, c)
			_bolts(ci, r)
			_plate(ci, _chamfer(Rect2(x0 - 4, y0 - 2, w + 8, 12), 3.0), trim)
			_plate(ci, _chamfer(Rect2(x0, y1 - 14, w, 10), 3.0), trim)
	if not p["shape"] in ["core", "loco", "boiler", "fueltank", "cryopod"]:
		ci.draw_circle(chest, 9.0, eye.darkened(0.45))
		_glow(ci, chest, 6.0, eye)
		ci.draw_circle(chest, 6.0, eye)
	_rust(ci, r, hash(str(p.get("shape", ""))))
	_finish_plate(ci, r, p, t, true)
	# damage
	var hp: float = p.get("health", 1.0)
	_wear(ci, r, hp, hash(str(p.get("shape", ""))) + 11, t)


# ---- head
static func _draw_head(ci: CanvasItem, look: Dictionary, g: Dictionary, flash: bool, trim: Color, eye: Color, t: float, slot: String = "head", front: bool = false) -> void:
	var p := _part(look, slot)
	if not p.get("alive", false):
		if _alive(look, "torso"):
			_stump(ci, Vector2((g[slot] as Rect2).get_center().x, g["top"] - 2.0), t)
		return
	var r: Rect2 = g[slot]
	var c := _col(p, flash, false)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	var cen := r.get_center()
	_grade = int(p.get("grade", 3))
	var plate := _chamfer(r, minf(w, h) * 0.12)
	if not look.get("icon", false):
		_box(ci, Rect2(r.get_center().x - 6.0, g["top"] - 8.0, 12, 10), c.darkened(0.35))   # neck
	match p["shape"]:
		"bucket":
			_plate(ci, PackedVector2Array([Vector2(x0 + 5, y0), Vector2(x0 + w - 5, y0), Vector2(x0 + w + 2, y0 + h), Vector2(x0 - 2, y0 + h)]), c)
			_arc(ci, Vector2(cen.x, y0), w * 0.35, PI, TAU, 10, trim, 2.0)
			var bx := -w * 0.21 if front else 0.0
			ci.draw_circle(Vector2(cen.x + w * 0.1 + bx, y0 + h * 0.45), 3.5, eye)
			ci.draw_circle(Vector2(cen.x + w * 0.32 + bx, y0 + h * 0.45), 3.5, eye)
		"dome":
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				pts.append(Vector2(cen.x, y0 + h * 0.6) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.6))
			pts.append(Vector2(x0 + w, y0 + h))
			pts.append(Vector2(x0, y0 + h))
			_plate(ci, pts, c)
			ci.draw_rect(Rect2(cen.x - (w * 0.3 if front else w * 0.1), y0 + h * 0.5, w * 0.6 if front else w * 0.55, 6), eye)
			ci.draw_circle(Vector2(cen.x - w * 0.15, y0 + h * 0.25), 4.0, Color(1, 1, 1, 0.35))
		"cyclops":
			var rad := minf(w, h) * 0.5
			_round(ci, cen, rad, c)
			var cx := 0.0 if front else 1.0
			ci.draw_circle(cen + Vector2(rad * 0.25 * cx, 0), rad * 0.55, trim)
			ci.draw_circle(cen + Vector2(rad * 0.3 * cx, 0), rad * 0.42, eye)
			ci.draw_circle(cen + Vector2(rad * 0.4 * cx, 0), rad * 0.15, Color(0.05, 0.05, 0.05))
		"visor":
			_plate(ci, plate, c)
			ci.draw_rect(Rect2(x0 + 2, y0 + h * 0.35, w - 2, h * 0.3), eye)
			for k in 3:
				ci.draw_line(Vector2(x0 + 5 + k * 5, y0 + h * 0.75), Vector2(x0 + 5 + k * 5, y0 + h - 3), c.darkened(0.4), 2.0)
		"horned":
			_plate(ci, plate, c)
			_poly(ci, PackedVector2Array([Vector2(x0, y0 + 4), Vector2(x0 + 10, y0), Vector2(x0 - 8, y0 - 18)]), trim)
			_poly(ci, PackedVector2Array([Vector2(x0 + w, y0 + 4), Vector2(x0 + w - 10, y0), Vector2(x0 + w + 8, y0 - 18)]), trim)
			ci.draw_rect(Rect2(cen.x - (w * 0.25 if front else 2.0), y0 + h * 0.38, w * 0.5 if front else w * 0.45, 6), eye)
		"skull":
			_plate(ci, _chamfer(Rect2(x0, y0, w, h * 0.62)), c)
			_plate(ci, _chamfer(Rect2(x0 + 2, y0 + h * 0.68, w - 2, h * 0.32), 3.0), c.darkened(0.15))
			for k in 5:
				var tx := x0 + 6 + k * (w - 10) / 4.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, y0 + h * 0.62), Vector2(tx + 3, y0 + h * 0.62), Vector2(tx, y0 + h * 0.75)]), Color(0.9, 0.9, 0.85))
			var kx := -w * 0.175 if front else 0.0
			ci.draw_circle(Vector2(cen.x + w * 0.05 + kx, y0 + h * 0.3), 4.5, eye)
			ci.draw_circle(Vector2(cen.x + w * 0.3 + kx, y0 + h * 0.3), 4.5, eye)
		"wedge":
			if front:
				# a wedge seen nose-on: a shield shape with a fin on top and a V of an eye
				_plate(ci, PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, y0 + h * 0.6), Vector2(cen.x, y0 + h + 4), Vector2(x0, y0 + h * 0.6)]), c)
				_poly(ci, PackedVector2Array([Vector2(cen.x - 4, y0), Vector2(cen.x, y0 - 14), Vector2(cen.x + 4, y0)]), trim)
				ci.draw_line(Vector2(x0 + w * 0.2, y0 + h * 0.4), Vector2(cen.x, y0 + h * 0.55), eye, 4.0)
				ci.draw_line(Vector2(x0 + w * 0.8, y0 + h * 0.4), Vector2(cen.x, y0 + h * 0.55), eye, 4.0)
			else:
				_plate(ci, PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w * 0.55, y0), Vector2(x0 + w + 8, y0 + h * 0.7), Vector2(x0 + w, y0 + h), Vector2(x0, y0 + h)]), c)
				_poly(ci, PackedVector2Array([Vector2(x0 + w * 0.2, y0), Vector2(x0 + w * 0.35, y0 - 14), Vector2(x0 + w * 0.5, y0)]), trim)
				ci.draw_line(Vector2(x0 + w * 0.5, y0 + h * 0.45), Vector2(x0 + w + 2, y0 + h * 0.62), eye, 4.0)
		"tall":
			_plate(ci, plate, c)
			ci.draw_rect(Rect2(x0 + 4, y0 + 8, w - 4, 6), eye)
			if _lit():
				ci.draw_line(Vector2(cen.x, y0), Vector2(cen.x, y0 - 22), OUTLINE, 5.5)
				ci.draw_line(Vector2(cen.x - 10, y0 - 12), Vector2(cen.x + 10, y0 - 12), OUTLINE, 4.5)
				ci.draw_line(Vector2(cen.x - 7, y0 - 18), Vector2(cen.x + 7, y0 - 18), OUTLINE, 4.5)
			ci.draw_line(Vector2(cen.x, y0), Vector2(cen.x, y0 - 22), trim, 3.0)
			ci.draw_line(Vector2(cen.x - 10, y0 - 12), Vector2(cen.x + 10, y0 - 12), trim, 2.0)
			ci.draw_line(Vector2(cen.x - 7, y0 - 18), Vector2(cen.x + 7, y0 - 18), trim, 2.0)
			ci.draw_circle(Vector2(cen.x, y0 - 23), 3.0, eye if fmod(t, 1.0) < 0.5 else eye.darkened(0.6))
			for k in 3:
				ci.draw_line(Vector2(x0 + 3, y0 + 22 + k * 8), Vector2(x0 + w - 3, y0 + 22 + k * 8), c.darkened(0.35), 2.0)
		"knight":
			var dome := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				dome.append(Vector2(cen.x, y0 + h * 0.2) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.22))
			dome.append(Vector2(x0 + w, y0 + h))
			dome.append(Vector2(x0, y0 + h))
			_plate(ci, dome, c)   # the helmet: a dome on a box, one plate
			ci.draw_rect(Rect2(x0 + (w * 0.15 if front else w * 0.35), y0 + h * 0.38, w * (0.7 if front else 0.62), 5), Color(0.05, 0.05, 0.05))
			ci.draw_rect(Rect2(x0 + (w * 0.3 if front else w * 0.45), y0 + h * 0.38, w * 0.4, 5), eye)
			for k in 3:
				ci.draw_line(Vector2(x0 + w * 0.5 + k * 6, y0 + h * 0.58), Vector2(x0 + w * 0.5 + k * 6, y0 + h * 0.85), c.darkened(0.45), 2.0)
			_ln(ci, Vector2(cen.x - 10, y0 - 4), Vector2(cen.x - 22, y0 - 12), trim.darkened(0.2), 5.0)
			_ln(ci, Vector2(cen.x - 4, y0), Vector2(cen.x - 16, y0 - 16), trim, 6.0)
		"orb":
			var rad := minf(w, h) * 0.5
			_round(ci, cen, rad, c)
			if front:
				ci.draw_arc(cen + Vector2(0, rad * 0.1), rad * 0.55, 0.5, PI - 0.5, 12, eye, 3.0)
				ci.draw_circle(cen + Vector2(0, -rad * 0.1), rad * 0.22, eye)
			else:
				ci.draw_arc(cen, rad * 0.8, -0.8, 0.8, 12, eye, 4.0)
				ci.draw_circle(cen + Vector2(rad * 0.45, -rad * 0.1), rad * 0.22, eye)
			ci.draw_circle(cen + Vector2(-rad * 0.35, -rad * 0.4), rad * 0.18, Color(1, 1, 1, 0.3))
		"speaker":
			_plate(ci, plate, c)
			var sc2 := Vector2(cen.x + (0.0 if front else w * 0.12), cen.y + h * 0.05)
			for k in 3:
				ci.draw_arc(sc2, h * (0.12 + k * 0.1), 0, TAU, 16, c.darkened(0.35 + k * 0.1), 3.0)
			ci.draw_circle(sc2, h * 0.08, eye)
			var pulse := 0.6 + 0.4 * sin(t * 12.0)
			ci.draw_arc(sc2, h * 0.48 * pulse, -0.5, 0.5, 8, Color(eye.r, eye.g, eye.b, 0.5), 2.0)
			ci.draw_rect(Rect2(x0 + 3, y0 + 3, w * 0.25, 5), eye)
		"tv":
			_plate(ci, plate, c)
			var scr := Rect2(x0 + 5, y0 + 5, w - 14, h - 10)
			ci.draw_rect(scr, Color(0.05, 0.12, 0.08))
			var face_y := scr.position.y + scr.size.y * 0.4
			var tvx := -scr.size.x * 0.2 if front else 0.0
			ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.45 + tvx, face_y, 5, 5), eye)
			ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.75 + tvx, face_y, 5, 5), eye)
			ci.draw_line(Vector2(scr.position.x + scr.size.x * 0.45 + tvx, face_y + 12), Vector2(scr.end.x - 4 + tvx, face_y + 12), eye, 2.0)
			var scan := scr.position.y + fmod(t * 30.0, scr.size.y)
			ci.draw_line(Vector2(scr.position.x, scan), Vector2(scr.end.x, scan), Color(1, 1, 1, 0.12), 2.0)
			_ln(ci, Vector2(cen.x - 6, y0), Vector2(cen.x - 14, y0 - 14), trim, 2.0)
			_ln(ci, Vector2(cen.x + 2, y0), Vector2(cen.x + 10, y0 - 14), trim, 2.0)
		"dish":
			_plate(ci, _chamfer(Rect2(x0 + w * 0.2, y0 + h * 0.45, w * 0.6, h * 0.55), 3.0), c)
			ci.draw_rect(Rect2(cen.x - (w * 0.16 if front else 0.0), y0 + h * 0.6, w * 0.32, 6), eye)
			var dc := Vector2(cen.x - 2, y0 + h * 0.2)
			var wob := sin(t * 2.0) * 0.4
			_ln(ci, dc, dc + Vector2(sin(wob) * 4.0, -w * 0.3), trim, 2.0)
			_arc(ci, dc, w * 0.45, PI + 0.3 + wob, TAU - 0.3 + wob, 14, trim, 5.0)
			ci.draw_circle(dc + Vector2(sin(wob) * 4.0, -w * 0.3), 3.0, eye)
		"laser":
			_plate(ci, plate, c)
			var lz := Vector2(cen.x, cen.y + 2) if front else Vector2(x0 + w + 10, cen.y)
			if front:
				_disc(ci, lz, 10.0, c.darkened(0.3))
			else:
				_box(ci, Rect2(x0 + w - 4, cen.y - 8, 14, 16), c.darkened(0.3))
			ci.draw_circle(lz, 7.0, eye)
			ci.draw_circle(lz, 3.0, Color(1, 1, 1, 0.9))
			ci.draw_line(Vector2(x0 + 3, y0 + 6), Vector2(x0 + w - 6, y0 + 6), c.darkened(0.4), 2.0)
		"bulb":
			_plate(ci, _chamfer(Rect2(cen.x - w * 0.3, y0 + h * 0.75, w * 0.6, h * 0.25), 3.0), trim)
			ci.draw_circle(Vector2(cen.x, y0 + h * 0.42), w * 0.45, Color(c.r, c.g, c.b, 0.45))
			_arc(ci, Vector2(cen.x, y0 + h * 0.42), w * 0.45, 0, TAU, 24, c, 2.0)
			if _lit():
				var gc := Vector2(cen.x, y0 + h * 0.42) + _toward() * w * 0.2
				ci.draw_arc(gc, w * 0.18, _toward().angle() - 0.9, _toward().angle() + 0.9, 8, Color(1, 1, 1, 0.45), 2.5)
			var fil := PackedVector2Array()
			for k in 7:
				fil.append(Vector2(cen.x - 10 + k * 3.3, y0 + h * 0.5 + (-6.0 if k % 2 else 0.0) + sin(t * 20.0 + k) * 1.5))
			ci.draw_polyline(fil, eye, 2.0)
		"rivet":
			# (1.97) Old Iron: an iron pail, rows of rivets, one porthole eye and a carry handle
			_plate(ci, PackedVector2Array([Vector2(x0 + 4, y0), Vector2(x0 + w - 4, y0), Vector2(x0 + w, y0 + h), Vector2(x0, y0 + h)]), c)
			_plate(ci, _chamfer(Rect2(x0 - 2, y0 + h - 8, w + 4, 8), 2.0), trim)
			_arc(ci, Vector2(cen.x, y0), w * 0.32, PI, TAU, 10, trim.darkened(0.2), 3.0)
			for k in 5:
				ci.draw_circle(Vector2(x0 + 6 + k * (w - 12) / 4.0, y0 + 5), 1.8, c.darkened(0.45))
				ci.draw_circle(Vector2(x0 + 5 + k * (w - 10) / 4.0, y0 + h - 12), 1.8, c.darkened(0.45))
			var ep := Vector2(cen.x if front else x0 + w * 0.68, y0 + h * 0.45)
			_disc(ci, ep, 7.5, trim)
			ci.draw_circle(ep, 5.0, eye)
			ci.draw_circle(ep + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.6))
		"grille":
			# (1.97) Old Iron: a bulldog's jowls with a chrome radiator grille for a mouth
			_plate(ci, PackedVector2Array([Vector2(x0 + 6, y0), Vector2(x0 + w - 6, y0), Vector2(x0 + w, y0 + h * 0.35),
					Vector2(x0 + w + 3, y0 + h), Vector2(x0 - 3, y0 + h), Vector2(x0, y0 + h * 0.35)]), c)
			_plate(ci, _chamfer(Rect2(x0 - 2, y0 + h * 0.12, w + 4, h * 0.18), 2.0), c.darkened(0.15))   # the brow
			if front:
				ci.draw_rect(Rect2(cen.x - w * 0.26, y0 + h * 0.36, 7, 4), eye)
				ci.draw_rect(Rect2(cen.x + w * 0.26 - 7, y0 + h * 0.36, 7, 4), eye)
			else:
				ci.draw_rect(Rect2(x0 + w * 0.72, y0 + h * 0.36, 8, 4), eye)
			var gr := Rect2(cen.x - w * 0.33, y0 + h * 0.55, w * 0.66, h * 0.36) if front else Rect2(x0 + w * 0.42, y0 + h * 0.55, w * 0.58, h * 0.36)
			_plate(ci, _chamfer(gr, 2.0), Color(0.78, 0.8, 0.82))
			for k in 6:
				var gx := gr.position.x + 3.0 + k * (gr.size.x - 6.0) / 5.0
				ci.draw_line(Vector2(gx, gr.position.y + 2), Vector2(gx, gr.end.y - 2), Color(0.25, 0.26, 0.28), 2.0)
			_hexbolt(ci, Vector2(x0 + 4, y0 + h - 5), 2.5)
			_hexbolt(ci, Vector2(x0 + w - 4, y0 + h - 5), 2.5)
		"peeper":
			# (1.97) Scrapworks: a bucket with a periscope sticking out of the top
			_plate(ci, PackedVector2Array([Vector2(x0 + 5, y0), Vector2(x0 + w - 5, y0), Vector2(x0 + w + 2, y0 + h), Vector2(x0 - 2, y0 + h)]), c)
			ci.draw_rect(Rect2(cen.x - (w * 0.2 if front else -w * 0.05), y0 + h * 0.45, w * 0.36, 4), Color(0.06, 0.06, 0.06))
			var px := cen.x - (0.0 if front else w * 0.1)
			_ln(ci, Vector2(px, y0 + 2), Vector2(px, y0 - 14), trim, 5.0)
			if front:
				_disc(ci, Vector2(px, y0 - 16), 5.5, trim)
				ci.draw_circle(Vector2(px, y0 - 16), 3.5, eye)
			else:
				_ln(ci, Vector2(px, y0 - 14), Vector2(px + 10, y0 - 14), trim, 5.0)
				_disc(ci, Vector2(px + 12, y0 - 14), 4.5, trim)
				ci.draw_circle(Vector2(px + 13, y0 - 14), 3.0, eye)
		"periscope":
			# (1.98) Brassworks: a brass helm with a tall periscope and its lens box
			_plate(ci, _rounded(Rect2(x0, y0 + h * 0.15, w, h * 0.85), w * 0.22), c)
			ci.draw_line(Vector2(x0 + 2, y0 + h * 0.52), Vector2(x0 + w - 2, y0 + h * 0.52), c.darkened(0.3), 3.0)
			var ex2 := Vector2(cen.x if front else x0 + w * 0.7, y0 + h * 0.36)
			_disc(ci, ex2, 5.5, Color(0.8, 0.64, 0.2))
			ci.draw_circle(ex2, 3.5, eye)
			var tx2 := cen.x - (0.0 if front else w * 0.18)
			_ln(ci, Vector2(tx2, y0 + h * 0.2), Vector2(tx2, y0 - 22), c.darkened(0.15), 6.0)
			ci.draw_line(Vector2(tx2 - 4, y0 - 4), Vector2(tx2 + 4, y0 - 4), Color(0.8, 0.64, 0.2), 2.5)
			var lb := Rect2(tx2 - (6.0 if front else 4.0), y0 - 30, 12.0 if front else 16.0, 10)
			_plate(ci, _chamfer(lb, 2.0), c)
			ci.draw_circle(Vector2(lb.get_center().x if front else lb.end.x - 2, lb.get_center().y), 3.0, eye)
		"divingbell":
			# (1.98) Brassworks: a copper diving helmet, a caged front porthole, bolts round the collar
			var hc2 := Vector2(cen.x, y0 + h * 0.46)
			_round(ci, hc2, minf(w, h) * 0.48, c)
			_plate(ci, _chamfer(Rect2(x0 - 2, y0 + h * 0.82, w + 4, h * 0.18), 2.0), c.darkened(0.2))
			for k in 6:
				ci.draw_circle(Vector2(x0 + 3 + k * (w - 6) / 5.0, y0 + h * 0.91), 1.8, Color(0.85, 0.7, 0.3))
			var pc2 := hc2 + Vector2(0.0 if front else w * 0.16, 0.0)
			var pr2 := h * (0.24 if front else 0.18)
			_disc(ci, pc2, pr2 + 2.5, Color(0.8, 0.64, 0.2))
			ci.draw_circle(pc2, pr2, Color(0.1, 0.16, 0.18))
			ci.draw_circle(pc2 + Vector2(pr2 * 0.3, -pr2 * 0.2), pr2 * 0.4, Color(eye, 0.85))
			for k in 2:
				var off2 := (k - 0.5) * pr2 * 0.8
				ci.draw_line(pc2 + Vector2(off2, -pr2), pc2 + Vector2(off2, pr2), Color(0.8, 0.64, 0.2), 2.0)
			if not front:
				_disc(ci, hc2 + Vector2(-w * 0.22, -h * 0.05), h * 0.1, Color(0.8, 0.64, 0.2))
		"canopy":
			# (1.101) Nimbus: a white collar under a tinted glass bubble canopy, the eye glowing inside
			_plate(ci, _chamfer(Rect2(x0, y0 + h * 0.62, w, h * 0.38), 4.0), c)
			var cc := Vector2(cen.x + (0.0 if front else w * 0.06), y0 + h * 0.62)
			var bub := PackedVector2Array()
			for k in 17:
				var a5 := PI + k * PI / 16.0
				bub.append(cc + Vector2(cos(a5) * w * 0.44, sin(a5) * h * 0.62))
			ci.draw_colored_polygon(bub, Color(0.25, 0.4, 0.55, 0.85))
			ci.draw_polyline(bub, OUTLINE, 2.0)
			ci.draw_arc(cc, w * 0.3, PI * 1.15, PI * 1.45, 6, Color(1, 1, 1, 0.5), 2.0)
			ci.draw_line(cc + Vector2(0, -h * 0.62), cc, Color(0.85, 0.87, 0.9), 2.0)
			ci.draw_circle(cc + Vector2((0.0 if front else w * 0.12), -h * 0.24), 4.0, eye)
			ci.draw_circle(Vector2(x0 + 3, y0 + h * 0.8), 2.0, Color(1.0, 0.25, 0.2))
			ci.draw_circle(Vector2(x0 + w - 3, y0 + h * 0.8), 2.0, Color(0.2, 1.0, 0.4))
		"radarnose":
			# (1.101) Nimbus: an aircraft nose, the black radome to the front, a pitot tube, an eye slit
			if front:
				_round(ci, cen, minf(w, h) * 0.5, c)
				_disc(ci, cen, minf(w, h) * 0.3, Color(0.12, 0.13, 0.16))
				ci.draw_rect(Rect2(cen.x - w * 0.3, y0 + h * 0.18, w * 0.6, 4), eye)
			else:
				var nose := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w * 0.55, y0), Vector2(x0 + w, y0 + h * 0.55), Vector2(x0 + w * 0.6, y0 + h), Vector2(x0, y0 + h)])
				_plate(ci, nose, c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + w * 0.78, y0 + h * 0.3), Vector2(x0 + w, y0 + h * 0.55), Vector2(x0 + w * 0.72, y0 + h * 0.88)]), Color(0.12, 0.13, 0.16))
				_ln(ci, Vector2(x0 + w * 0.9, y0 + h * 0.62), Vector2(x0 + w + 12, y0 + h * 0.62), Color(0.8, 0.82, 0.86), 2.0)
				ci.draw_rect(Rect2(x0 + w * 0.3, y0 + h * 0.3, w * 0.34, 4), eye)
				ci.draw_line(Vector2(x0 + 2, y0 + h * 0.75), Vector2(x0 + w * 0.6, y0 + h * 0.75), Color(0.2, 0.45, 0.9), 2.5)
		"tesla":
			# (1.100) Volta: a small chrome head with a tesla coil on top, a ball that crackles
			_plate(ci, _rounded(Rect2(x0, y0 + h * 0.25, w, h * 0.75), 6.0), c)
			ci.draw_rect(Rect2(cen.x - (w * 0.3 if front else -w * 0.02), y0 + h * 0.48, w * (0.6 if front else 0.44), h * 0.18), eye)
			var cx2 := cen.x - (0.0 if front else w * 0.08)
			for j in 4:
				_disc(ci, Vector2(cx2, y0 + h * 0.2 - j * 5.0), 5.5 - j * 0.6, Color(0.75, 0.45, 0.2) if j % 2 == 0 else Color(0.92, 0.9, 0.85))
			var tb := Vector2(cx2, y0 - 16.0)
			_disc(ci, tb, 6.0, Color(0.85, 0.87, 0.9))
			for k in 3:
				if fmod(t * 5.0 + k * 0.37, 1.0) < 0.5:
					var a3 := -PI * 0.5 + (k - 1) * 0.9 + sin(t * 13.0 + k) * 0.3
					var tip3 := tb + Vector2(cos(a3), sin(a3)) * 16.0
					ci.draw_polyline(PackedVector2Array([tb, tb.lerp(tip3, 0.4) + Vector2(3, 0).rotated(a3 + 1.0), tb.lerp(tip3, 0.7) - Vector2(3, 0).rotated(a3 + 1.0), tip3]), Color(0.6, 0.95, 1.0), 1.5)
		"racer":
			# (1.100) Volta: a white racing helmet, a wide tinted visor with the eye behind it, a stripe over the top
			var hc3 := Vector2(cen.x, y0 + h * 0.5)
			_round(ci, hc3, minf(w, h) * 0.5, c)
			ci.draw_colored_polygon(PackedVector2Array([hc3 + Vector2(-3, -h * 0.5), hc3 + Vector2(3, -h * 0.5), hc3 + Vector2(3, h * 0.1), hc3 + Vector2(-3, h * 0.1)]), Color(0.9, 0.15, 0.25))
			var vis := Rect2(cen.x - w * 0.36, y0 + h * 0.38, w * 0.72, h * 0.26) if front else Rect2(cen.x - w * 0.02, y0 + h * 0.36, w * 0.5, h * 0.28)
			_plate(ci, _rounded(vis, vis.size.y * 0.45), Color(0.08, 0.1, 0.16))
			ci.draw_rect(Rect2(vis.position.x + vis.size.x * 0.25, vis.get_center().y - 2, vis.size.x * 0.5, 4), eye)
			ci.draw_line(vis.position + Vector2(4, 3), vis.position + Vector2(vis.size.x * 0.4, 3), Color(1.0, 0.4, 0.8, 0.6), 2.0)
			_plate(ci, _chamfer(Rect2(x0 + w * 0.15, y0 + h * 0.86, w * 0.7, h * 0.14), 2.0), c.darkened(0.25))
		"welder":
			# (1.99) Hellfire: a welding mask, the dark glass glowing with the eye behind it, straps and a hinge
			var mk := PackedVector2Array([Vector2(x0 + w * 0.12, y0), Vector2(x0 + w * 0.88, y0), Vector2(x0 + w, y0 + h * 0.4),
					Vector2(x0 + w * 0.86, y0 + h), Vector2(x0 + w * 0.14, y0 + h), Vector2(x0, y0 + h * 0.4)])
			if not front:
				mk = PackedVector2Array([Vector2(x0 + w * 0.1, y0), Vector2(x0 + w * 0.8, y0), Vector2(x0 + w * 1.06, y0 + h * 0.5),
						Vector2(x0 + w * 0.9, y0 + h), Vector2(x0 + w * 0.15, y0 + h), Vector2(x0, y0 + h * 0.45)])
			_plate(ci, mk, c)
			var gl2 := Rect2(cen.x - w * 0.3, y0 + h * 0.3, w * 0.6, h * 0.2) if front else Rect2(x0 + w * 0.5, y0 + h * 0.3, w * 0.46, h * 0.2)
			ci.draw_rect(gl2, Color(0.08, 0.16, 0.1))
			ci.draw_rect(gl2.grow(-2.0), Color(eye.r, eye.g, eye.b, 0.55))
			ci.draw_rect(gl2, OUTLINE, false, 1.5)
			_joint(ci, Vector2(x0 + w * (0.08 if front else 0.18), y0 + h * 0.42), 3.2, Color(0.6, 0.6, 0.64))
			if front:
				_joint(ci, Vector2(x0 + w * 0.92, y0 + h * 0.42), 3.2, Color(0.6, 0.6, 0.64))
			ci.draw_line(Vector2(x0 + w * 0.2, y0 + h * 0.66), Vector2(x0 + w * 0.8, y0 + h * 0.66), c.darkened(0.3), 2.0)
			ci.draw_line(Vector2(x0 + w * 0.25, y0 + h * 0.8), Vector2(x0 + w * 0.75, y0 + h * 0.8), c.darkened(0.3), 2.0)
		"beacon":
			# (1.99) Hellfire: a squat box with one wide eye and an amber hazard beacon turning on top
			_plate(ci, plate, c)
			ci.draw_rect(Rect2(cen.x - (w * 0.3 if front else -w * 0.02), y0 + h * 0.4, w * (0.6 if front else 0.44), h * 0.22), Color(0.07, 0.07, 0.08))
			ci.draw_rect(Rect2(cen.x - (w * 0.24 if front else -w * 0.08), y0 + h * 0.45, w * (0.48 if front else 0.32), h * 0.12), eye)
			var bc := Vector2(cen.x, y0 - 9.0)
			_plate(ci, _chamfer(Rect2(bc.x - 9, y0 - 4, 18, 5), 1.5), Color(0.2, 0.2, 0.22))
			var on := 0.5 + 0.5 * sin(t * 7.0)
			ci.draw_circle(bc, 9.0, OUTLINE)
			ci.draw_circle(bc, 8.0, Color(1.0, 0.55 + 0.25 * on, 0.1))
			ci.draw_circle(bc + Vector2(-2, -2), 3.0, Color(1.0, 0.95, 0.7, 0.8))
			var ba := t * 5.0
			var bdir := Vector2(cos(ba), 0.0)
			if absf(bdir.x) > 0.2:
				ci.draw_colored_polygon(PackedVector2Array([bc, bc + Vector2(bdir.x * 48.0, -12.0), bc + Vector2(bdir.x * 48.0, 10.0)]), Color(1.0, 0.65, 0.15, 0.22 * absf(bdir.x)))
		"busted":
			# (1.97) Scrapworks: an old TV, screen cracked, one eye on the blink, an antenna bent and taped
			_plate(ci, plate, c)
			var scr := Rect2(x0 + 5, y0 + 5, w - 14, h - 10)
			ci.draw_rect(scr, Color(0.06, 0.1, 0.08))
			var rngs := int(t * 12.0)
			for k in 10:
				var sx := scr.position.x + fmod(float((k * 37 + rngs * 13) % 97) / 97.0 * scr.size.x, scr.size.x)
				var sy := scr.position.y + fmod(float((k * 53 + rngs * 7) % 89) / 89.0 * scr.size.y, scr.size.y)
				ci.draw_rect(Rect2(sx, sy, 2, 1), Color(1, 1, 1, 0.25))
			var fy := scr.position.y + scr.size.y * 0.4
			var bxs := -scr.size.x * 0.2 if front else 0.0
			ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.45 + bxs, fy, 5, 5), eye)
			if fmod(t * 3.0, 1.0) < 0.7:
				ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.75 + bxs, fy, 5, 5), eye)
			ci.draw_polyline(PackedVector2Array([scr.position + Vector2(scr.size.x * 0.2, 0), scr.position + Vector2(scr.size.x * 0.35, scr.size.y * 0.4),
					scr.position + Vector2(scr.size.x * 0.28, scr.size.y * 0.6), scr.position + Vector2(scr.size.x * 0.5, scr.size.y)]), Color(0.85, 0.9, 0.9, 0.7), 1.5)
			_ln(ci, Vector2(cen.x - 6, y0), Vector2(cen.x - 14, y0 - 14), trim, 2.0)
			_pl(ci, PackedVector2Array([Vector2(cen.x + 2, y0), Vector2(cen.x + 8, y0 - 8), Vector2(cen.x + 16, y0 - 10)]), trim, 2.0)
			ci.draw_rect(Rect2(cen.x + 4, y0 - 7, 6, 4), Color(0.85, 0.8, 0.6, 0.85))   # tape on the bent one
		_:
			_plate(ci, plate, c)
			ci.draw_rect(Rect2(cen.x - (w * 0.25 if front else -2.0), y0 + h * 0.36, w * (0.5 if front else 0.42), 7), eye)
			_ln(ci, Vector2(x0 + 8, y0), Vector2(x0 + 4, y0 - 14), trim, 3.0)
			ci.draw_circle(Vector2(x0 + 4, y0 - 15), 3.0, eye)
	_rust(ci, r, hash(str(p.get("shape", ""))) + 5)
	var hp: float = p.get("health", 1.0)
	_finish_plate(ci, Rect2(x0, y0, w, h), p, t, false)
	_wear(ci, Rect2(x0, y0, w, h), hp, hash(str(p.get("shape", ""))) + 29, t)
	if hp < 0.3 and fmod(t * 5.0, 1.0) < 0.5:
		ci.draw_circle(Vector2(x0 + w * 0.3, y0 + h * 0.2), 3.0, Color(1.0, 0.8, 0.3))
