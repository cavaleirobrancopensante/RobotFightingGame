extends RefCounted
## Draws robots out of simple shapes. Every part (head, torso, 2 arms, 2 legs) has its own
## shape, size, color and health, so robots look different and show their damage.
##
## look: {"parts": {slot: {"alive", "shape", "size", "color", "health"}}, "trim", "eye", "scale"}
## pose (all optional): facing, state, extended, attack_limb, swing, crouch, blocking, flash, rot, scale
##
## Local coordinates: origin = between the feet on the floor, +x = the way the robot faces, -y = up.

# [length, thickness] at size 1.0
const LEGS := {"rod": [60.0, 11.0], "piston": [62.0, 15.0], "spring": [66.0, 12.0],
		"reverse": [70.0, 13.0], "pillar": [48.0, 26.0], "thick": [56.0, 21.0],
		"pogo": [68.0, 10.0], "wheel": [58.0, 13.0], "tread": [52.0, 24.0],
		"blade": [64.0, 9.0], "hover": [50.0, 16.0], "spider": [62.0, 10.0]}
# [width, height]
const TORSOS := {"barrel": [60.0, 70.0], "box": [56.0, 76.0], "vee": [70.0, 78.0],
		"core": [60.0, 76.0], "tank": [84.0, 82.0], "slim": [42.0, 82.0],
		"ribcage": [54.0, 74.0], "hex": [70.0, 80.0], "cannon": [66.0, 78.0],
		"crate": [62.0, 66.0], "furnace": [64.0, 78.0], "orb": [70.0, 70.0],
		"yoke": [82.0, 74.0], "quad": [74.0, 84.0], "monster": [92.0, 90.0]}
const HEADS := {"bucket": [34.0, 32.0], "box": [38.0, 34.0], "dome": [42.0, 34.0], "cyclops": [40.0, 40.0],
		"visor": [48.0, 28.0], "horned": [40.0, 34.0], "skull": [40.0, 42.0], "wedge": [44.0, 30.0],
		"tall": [26.0, 52.0], "bulb": [44.0, 44.0], "tv": [46.0, 36.0], "dish": [40.0, 34.0], "laser": [38.0, 34.0],
		"knight": [40.0, 42.0], "orb": [38.0, 38.0], "speaker": [44.0, 38.0]}
const PUNCH_LEN := 84.0   # how far a punching hand reaches from the lead shoulder

# [thickness, fist radius]
const ARMS := {"rod": [9.0, 9.0], "piston": [13.0, 12.0], "claw": [11.0, 6.0], "spike": [13.0, 12.0],
		"bulky": [19.0, 16.0], "hammer": [15.0, 6.0], "drill": [13.0, 6.0],
		"rocket": [14.0, 14.0], "grapple": [12.0, 6.0], "saw": [12.0, 6.0],
		"blade": [11.0, 6.0], "flame": [14.0, 6.0], "magnet": [13.0, 6.0]}


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
	if state == "hit" or state == "ko":
		arm_pose = {"arm_front": "limp", "arm_back": "limp", "arm_front2": "limp", "arm_back2": "limp"}
	elif blocking:
		arm_pose = {"arm_front": "block", "arm_back": "block", "arm_front2": "block", "arm_back2": "block"}
	if extended and limb != "":
		if state in ["punch", "uppercut", "low_punch"] and limb.begins_with("arm"):
			arm_pose[limb] = state
		elif state in ["kick", "sweep", "high_kick"] and limb.begins_with("leg"):
			leg_pose[limb] = state
	elif state == "charge" and limb != "" and limb.begins_with("arm"):
		arm_pose[limb] = "charge"   # winding up a charged hit: the arm drawn back
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
		var pts := arm_pose_points(s, ap, is_rear(look, slot), punch_reach_x(g) if ap in ["punch", "low_punch", "uppercut"] else 0.0, aim if slot == limb else 0.0)
		out.append([slot, "cap", s, pts[0], dims[0] * sz * 0.55])
		out.append([slot, "cap", pts[0], pts[1], maxf(dims[0] * sz * 0.5, dims[1] * sz)])
	for slot in ["leg_front", "leg_back"]:
		if not _alive(look, slot):
			continue
		var p2 := _part(look, slot)
		var ld: Array = LEGS.get(p2.get("shape", "rod"), LEGS["rod"])
		var hip: Vector2 = g["hip_front"] if slot == "leg_front" else g["hip_back"]
		var foot := leg_pose_foot(hip, lp["legs"][slot], 0.0, aim if slot == limb else 0.0)
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
	_draw_back(ci, look, g, pose, flash, trim, t)
	if look["parts"].has(ra2) and look["parts"][ra2].has("shape"):
		_draw_arm(ci, look, ra2, shoulder_of(g, ra2), arm_pose[ra2], true, flash, trim, t, fist_out.has(ra2), aim if limb == ra2 else 0.0)
	_draw_arm(ci, look, ra, shoulder_of(g, ra), arm_pose[ra], true, flash, trim, t, fist_out.has(ra), aim if limb == ra else 0.0)
	_draw_leg(ci, look, rl, g["hip_back"], g["L"], leg_pose[rl], -swing, true, flash, trim, aim if limb == rl else 0.0)
	_draw_torso(ci, look, g, flash, trim, eye, t)
	_draw_leg(ci, look, ll, g["hip_front"], g["L"], leg_pose[ll], swing, false, flash, trim, aim if limb == ll else 0.0)
	if look["parts"].has("head2") and look["parts"]["head2"].has("shape"):
		_draw_head(ci, look, g, flash, trim, eye, t, "head2")
	_draw_head(ci, look, g, flash, trim, eye, t, "head")
	if look["parts"].has(la2) and look["parts"][la2].has("shape"):
		_draw_arm(ci, look, la2, shoulder_of(g, la2), arm_pose[la2], false, flash, trim, t, fist_out.has(la2), aim if limb == la2 else 0.0)
	_draw_arm(ci, look, la, shoulder_of(g, la), arm_pose[la], false, flash, trim, t, fist_out.has(la), aim if limb == la else 0.0)

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
	ci.draw_set_transform_matrix(right)
	_draw_back(ci, look, g, pose, false, trim, t)   # back gear peeks out from behind
	ci.draw_set_transform_matrix(left)
	_draw_leg(ci, look, "leg_front", g["hip"], g["L"], "stand", 0.0, false, false, trim)
	ci.draw_set_transform_matrix(right)
	_draw_leg(ci, look, "leg_back", g["hip"], g["L"], "stand", 0.0, false, false, trim)
	_draw_torso(ci, look, g, false, trim, eye, t, true)
	for side in [["arm_front", left], ["arm_back", right]]:
		ci.draw_set_transform_matrix(side[1])
		if look["parts"].has(side[0] + "2") and look["parts"][side[0] + "2"].has("shape"):
			_draw_arm(ci, look, side[0] + "2", g["shoulder2"], "open", false, false, trim, t)
		_draw_arm(ci, look, side[0], g["shoulder"], "open", false, false, trim, t)
	ci.draw_set_transform_matrix(right)
	if look["parts"].has("head2") and look["parts"]["head2"].has("shape"):
		_draw_head(ci, look, g, false, trim, eye, t, "head2", true)
	_draw_head(ci, look, g, false, trim, eye, t, "head", true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


static func _damage_marks(ci: CanvasItem, a: Vector2, b: Vector2, health: float, t: float) -> void:
	if health < 0.6:
		var m := a.lerp(b, 0.5)
		var d := (b - a).normalized().orthogonal() * 6.0
		ci.draw_line(m - d, m + d * 0.4 + (b - a) * 0.12, Color(0.05, 0.05, 0.05), 2.0)
	if health < 0.3:
		var glow := Color(1.0, 0.35, 0.1, 0.5 + 0.4 * sin(t * 12.0))
		ci.draw_circle(a.lerp(b, 0.35), 4.0, glow)


static func _stump(ci: CanvasItem, at: Vector2, t: float) -> void:
	if t < 0.0:
		return   # icons: no stumps
	ci.draw_circle(at, 6.0, Color(0.15, 0.15, 0.15))
	if fmod(t * 7.0, 1.0) < 0.5:
		ci.draw_circle(at + Vector2(4, 2), 3.0, Color(1.0, 0.8, 0.3))


# ---- arms
## Elbow and hand of an arm in a pose (local, unscaled), from its shoulder s. Drawing and the fight's
## hit test both use this, so a fist lands exactly where it's drawn.
## reach_x: where a punching hand ends up (the rear hand crosses over to land about as far as the lead one).
## aim: the punch tilts this many radians toward its target (negative = up).
static func arm_pose_points(s: Vector2, pose: String, back: bool, reach_x: float = 0.0, aim: float = 0.0) -> Array:
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
		"charge":
			# drawn back, ready to let go
			e = s + Vector2(-26 if not back else -18, 14)
			h = s + Vector2(-10 if not back else -4, -14)
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
	if tilt and aim != 0.0:
		e = s + (e - s).rotated(aim)
		h = s + (h - s).rotated(aim)
	return [e, h]


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
	return Vector2(ext, maxf(fr, th * 0.5))


## Shoulder of an arm slot.
static func shoulder_of(g: Dictionary, slot: String) -> Vector2:
	return g.get("shoulder" + slot.substr(3), g["shoulder_front"])


## Where a punching hand ends up (local x): the lead hand's reach, used for the rear hand too.
static func punch_reach_x(g: Dictionary) -> float:
	return maxf(float((g["shoulder_front"] as Vector2).x), float((g["shoulder_back"] as Vector2).x)) + PUNCH_LEN - 8.0


## The striking line of a limb in a pose (local, unscaled): from the elbow/knee out to the very tip,
## plus how thick the end is. {"a": inner point, "b": tip, "r": radius}
static func limb_strike(look: Dictionary, slot: String, pose: String, aim: float = 0.0) -> Dictionary:
	var g := geom(look)
	if slot.begins_with("arm"):
		var s := shoulder_of(g, slot)
		var pts := arm_pose_points(s, pose, is_rear(look, slot), punch_reach_x(g), aim)
		var ex := arm_tip_extra(look, slot, pose)
		var dir: Vector2 = ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()
		return {"a": pts[0], "b": (pts[1] as Vector2) + dir * ex.x, "r": ex.y}
	if slot.begins_with("leg"):
		var hip: Vector2 = g["hip_front"] if slot == "leg_front" else g["hip_back"]
		var foot := leg_pose_foot(hip, pose, 0.0, aim)
		var p := _part(look, slot)
		return {"a": hip.lerp(foot, 0.45), "b": foot + (foot - hip).normalized() * 8.0, "r": 12.0 * maxf(0.8, float(p.get("size", 1.0)))}
	# no limb: the front of the torso (shoulder charges, slams)
	var t: Rect2 = g["torso"]
	return {"a": Vector2(t.end.x - 6.0, t.position.y + t.size.y * 0.25), "b": Vector2(t.end.x + 8.0, t.position.y + t.size.y * 0.75), "r": 14.0}


## Where a foot goes in a pose (local, unscaled), from its hip.
static func leg_pose_foot(hip: Vector2, pose: String, swing: float = 0.0, aim: float = 0.0) -> Vector2:
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
	return Vector2(hip.x + swing, 0.0)


static func _draw_arm(ci: CanvasItem, look: Dictionary, slot: String, s: Vector2, pose: String,
		back: bool, flash: bool, trim: Color, t: float, fist_gone: bool = false, aim: float = 0.0) -> void:
	var p := _part(look, slot)
	if not p.get("alive", false):
		_stump(ci, s, -1.0 if look.get("icon", false) else t)
		return
	var dims: Array = ARMS.get(p["shape"], ARMS["rod"])
	var sz: float = p["size"]
	var th: float = dims[0] * sz
	var fr: float = dims[1] * sz
	var reach_x := punch_reach_x(geom(look)) if pose in ["punch", "low_punch", "uppercut"] else 0.0
	var ph := arm_pose_points(s, pose, back, reach_x, aim)
	var e: Vector2 = ph[0]
	var h: Vector2 = ph[1]
	var c := _col(p, flash, back)
	var tc := trim.darkened(0.35) if back else trim
	var dir := (h - e).normalized()
	var perp := dir.orthogonal()

	if p["shape"] == "bulky":
		ci.draw_circle(s, th * 0.8, c.darkened(0.1))
	ci.draw_line(s, e, c, th)
	ci.draw_line(e, h, c, th * 0.9)
	ci.draw_circle(s, th * 0.55, c.darkened(0.25))
	ci.draw_circle(e, th * 0.5, c.darkened(0.25))
	match p["shape"]:
		"piston":
			ci.draw_line(e + dir * 4.0, e.lerp(h, 0.6), c.darkened(0.3), th * 1.4)
			ci.draw_line(e.lerp(h, 0.6), h, tc, th * 0.45)
			ci.draw_circle(h, fr, tc)
		"spike":
			ci.draw_circle(h, fr, c.darkened(0.15))
			ci.draw_colored_polygon(PackedVector2Array([h + dir * (fr + 16.0), h + perp * fr * 0.6, h - perp * fr * 0.6]), tc)
			ci.draw_colored_polygon(PackedVector2Array([h + perp * (fr + 8.0), h + dir * fr * 0.5, h - dir * fr * 0.5]), tc)
		"claw":
			var tip1 := h + dir * 16.0 + perp * 10.0
			var tip2 := h + dir * 16.0 - perp * 10.0
			ci.draw_line(h, tip1, tc, 5.0)
			ci.draw_line(h, tip2, tc, 5.0)
			ci.draw_line(tip1, tip1 - perp * 6.0 + dir * 4.0, tc, 4.0)
			ci.draw_line(tip2, tip2 + perp * 6.0 + dir * 4.0, tc, 4.0)
			ci.draw_circle(h, fr, c.darkened(0.2))
		"hammer":
			var cen := h + dir * 10.0
			var a := dir * 16.0 * sz
			var b := perp * 14.0 * sz
			ci.draw_colored_polygon(PackedVector2Array([cen - a - b, cen + a - b, cen + a + b, cen - a + b]), tc)
			ci.draw_line(cen - b * 0.9, cen + b * 0.9, c.darkened(0.3), 3.0)
		"drill":
			var cone := PackedVector2Array([h + perp * 11.0 * sz, h + dir * 34.0 * sz, h - perp * 11.0 * sz])
			ci.draw_colored_polygon(cone, tc)
			var spin := fmod(t * 3.0, 1.0)
			for k in 3:
				var f := (k + spin) / 3.0
				var q := h + dir * 34.0 * sz * f
				var w := 11.0 * sz * (1.0 - f)
				ci.draw_line(q + perp * w, q - perp * w + dir * 4.0, c.darkened(0.4), 2.0)
		"bulky":
			ci.draw_circle(h, fr, tc)
			ci.draw_circle(h + dir * 3.0, fr * 0.55, tc.darkened(0.15))
		"blade":
			var tip := h + dir * 44.0 * sz
			ci.draw_colored_polygon(PackedVector2Array([h + perp * 6.0, tip, h - perp * 6.0]), tc.lightened(0.2))
			ci.draw_line(h, tip, Color(1, 1, 1, 0.5), 1.5)
			ci.draw_circle(h, th * 0.6, c.darkened(0.3))
		"flame":
			ci.draw_rect(Rect2(h - Vector2(8, 8), Vector2(16, 16)), c.darkened(0.3))
			ci.draw_line(h, h + dir * 14.0, tc, 8.0)
			if pose == "punch":
				var fl := 0.7 + 0.3 * sin(t * 40.0)
				ci.draw_colored_polygon(PackedVector2Array([h + dir * 14.0 + perp * 6.0, h + dir * (60.0 * fl), h + dir * 14.0 - perp * 6.0]), Color(1.0, 0.5, 0.1, 0.85))
				ci.draw_colored_polygon(PackedVector2Array([h + dir * 14.0 + perp * 3.0, h + dir * (36.0 * fl), h + dir * 14.0 - perp * 3.0]), Color(1.0, 0.95, 0.5))
			else:
				ci.draw_circle(h + dir * 16.0, 3.0, Color(0.3, 0.6, 1.0, 0.6 + 0.4 * sin(t * 9.0)))
		"magnet":
			var mc := h + dir * 8.0
			ci.draw_arc(mc, 13.0 * sz, dir.angle() + PI * 0.5, dir.angle() + PI * 1.5, 12, Color(0.75, 0.15, 0.15), 9.0)
			ci.draw_line(mc + perp * 13.0 * sz, mc + perp * 13.0 * sz + dir * 10.0, Color(0.85, 0.85, 0.9), 9.0)
			ci.draw_line(mc - perp * 13.0 * sz, mc - perp * 13.0 * sz + dir * 10.0, Color(0.85, 0.85, 0.9), 9.0)
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
			ci.draw_circle(h, th * 0.7, c.darkened(0.3))
			if not fist_gone:
				var tip1 := h + dir * 18.0 + perp * 9.0
				var tip2 := h + dir * 18.0 - perp * 9.0
				ci.draw_line(h, tip1, tc, 4.0)
				ci.draw_line(h, tip2, tc, 4.0)
				ci.draw_line(tip1, tip1 - perp * 7.0 + dir * 2.0, tc, 4.0)
				ci.draw_line(tip2, tip2 + perp * 7.0 + dir * 2.0, tc, 4.0)
		"saw":
			var cen := h + dir * 12.0
			var rr := 16.0 * sz
			ci.draw_circle(cen, rr, tc)
			var spin := t * 25.0
			for k in 8:
				var a := spin + k * TAU / 8.0
				var o := Vector2(cos(a), sin(a))
				ci.draw_colored_polygon(PackedVector2Array([cen + o * rr, cen + o.rotated(0.35) * (rr + 6.0), cen + o.rotated(0.5) * rr]), tc.darkened(0.2))
			ci.draw_circle(cen, rr * 0.3, c.darkened(0.4))
		_:
			ci.draw_circle(h, fr, tc)
	_damage_marks(ci, s, h, p.get("health", 1.0), t)


static func draw_rocket_fist(ci: CanvasItem, h: Vector2, dir: Vector2, fr: float, c: Color, tc: Color, flying: bool, t: float) -> void:
	var perp := dir.orthogonal()
	if flying:
		var fl := 14.0 + 6.0 * sin(t * 40.0)
		ci.draw_colored_polygon(PackedVector2Array([h - dir * fr * 0.6 + perp * 6.0, h - dir * (fr + fl), h - dir * fr * 0.6 - perp * 6.0]), Color(1.0, 0.6, 0.15))
	ci.draw_circle(h, fr, tc)
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
			ci.draw_rect(Rect2(bx - 16, top + 12, 18, 44), c)
			ci.draw_rect(Rect2(bx - 16, top + 24, 18, 4), c.darkened(0.4))
			ci.draw_rect(Rect2(bx - 16, top + 40, 18, 4), c.darkened(0.4))
			ci.draw_rect(Rect2(bx - 12, top + 6, 6, 6), Color(0.9, 0.2, 0.2))
		"spikes":
			for k in 5:
				var y := top + 6 + k * 14.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(bx + 2, y), Vector2(bx - 18, y + 6), Vector2(bx + 2, y + 12)]), c)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, top), Vector2(-2, top - 14), Vector2(4, top)]), c)
		"booster":
			for k in 2:
				var y := top + 14 + k * 26.0
				ci.draw_rect(Rect2(bx - 24, y, 26, 14), c)
				ci.draw_rect(Rect2(bx - 30, y + 2, 6, 10), c.darkened(0.4))
				if pose.get("boost", false):
					ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 30, y + 1), Vector2(bx - 30 - 40 * flame, y + 7), Vector2(bx - 30, y + 13)]), Color(1.0, 0.55, 0.1, 0.9))
		"jet":
			ci.draw_rect(Rect2(bx - 20, top + 8, 22, 46), c)
			ci.draw_rect(Rect2(bx - 18, top + 54, 8, 10), c.darkened(0.4))
			ci.draw_rect(Rect2(bx - 8, top + 54, 8, 10), c.darkened(0.4))
			if pose.get("jet", false):
				for nx in [bx - 14, bx - 4]:
					ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 4, top + 64), Vector2(nx, top + 64 + 36 * flame), Vector2(nx + 4, top + 64)]), Color(1.0, 0.6, 0.15, 0.9))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(nx - 2, top + 64), Vector2(nx, top + 64 + 18 * flame), Vector2(nx + 2, top + 64)]), Color(1.0, 1.0, 0.7))
		"plating":
			ci.draw_rect(Rect2(bx - 14, top + 4, 18, g["th"] - 8), c)
			for k in 4:
				ci.draw_circle(Vector2(bx - 6, top + 14 + k * (g["th"] - 24) / 3.0), 3.0, c.darkened(0.4))
		"wings":
			var flap := sin(t * 6.0) * 6.0
			for k in 2:
				var root := Vector2(bx - 2, top + 16 + k * 10)
				ci.draw_colored_polygon(PackedVector2Array([root, root + Vector2(-56, -40 - k * 8 + flap), root + Vector2(-40, -6 + flap), root + Vector2(-60, 6 + flap * 0.5)]), Color(c.r, c.g, c.b, 0.85 - k * 0.25))
		"shield":
			ci.draw_line(Vector2(bx - 6, top + 40), Vector2(bx - 14, top - 18), c.darkened(0.3), 4.0)
			ci.draw_arc(Vector2(bx - 14, top - 18), 14.0, PI * 0.6, PI * 1.6, 12, c, 5.0)
			ci.draw_circle(Vector2(bx - 14, top - 18), 4.0, Color(0.6, 0.9, 1.0, 0.6 + 0.4 * sin(t * 6.0)))


# ---- legs
static func _draw_leg(ci: CanvasItem, look: Dictionary, slot: String, hip: Vector2, L: float, pose: String,
		swing: float, back: bool, flash: bool, trim: Color, aim: float = 0.0) -> void:
	var p := _part(look, slot)
	if not p.get("alive", false):
		_stump(ci, hip, -1.0 if look.get("icon", false) else 0.0)
		return
	var dims: Array = LEGS.get(p["shape"], LEGS["rod"])
	var sz: float = p["size"]
	var th: float = dims[1] * sz
	var foot := leg_pose_foot(hip, pose, swing, aim)
	var c := _col(p, flash, back)
	var tc := trim.darkened(0.3) if back else trim
	var dir := (foot - hip).normalized()
	var perp := dir.orthogonal()
	var knee := hip.lerp(foot, 0.5) - perp * 6.0
	match p["shape"]:
		"spring":
			ci.draw_line(hip, foot, c.darkened(0.3), 3.0)
			var pts := PackedVector2Array()
			for k in 11:
				var f := k / 10.0
				var off := (perp * th * (1 if k % 2 else -1)) if k > 0 and k < 10 else Vector2.ZERO
				pts.append(hip.lerp(foot, f) + off)
			ci.draw_polyline(pts, c, 4.0)
		"reverse":
			var k1 := hip.lerp(foot, 0.35) - perp * 14.0
			var k2 := hip.lerp(foot, 0.75) + perp * 14.0
			ci.draw_line(hip, k1, c, th * 1.2)
			ci.draw_line(k1, k2, c, th * 0.9)
			ci.draw_line(k2, foot, c, th * 0.7)
			ci.draw_circle(k1, th * 0.6, c.darkened(0.25))
			ci.draw_circle(k2, th * 0.45, c.darkened(0.25))
		"pillar":
			ci.draw_line(hip, foot, c, th)
			ci.draw_line(hip.lerp(foot, 0.3) - perp * th * 0.5, hip.lerp(foot, 0.3) + perp * th * 0.5, c.darkened(0.3), 3.0)
			ci.draw_line(hip.lerp(foot, 0.7) - perp * th * 0.5, hip.lerp(foot, 0.7) + perp * th * 0.5, c.darkened(0.3), 3.0)
		"piston":
			ci.draw_line(hip, knee, c, th * 1.2)
			ci.draw_line(knee, foot, c.darkened(0.2), th * 0.6)
			ci.draw_line(knee, knee.lerp(foot, 0.6), c, th)
			ci.draw_circle(knee, th * 0.55, c.darkened(0.3))
		"thick":
			ci.draw_line(hip, knee, c, th)
			ci.draw_line(knee, foot, c, th * 0.9)
			ci.draw_circle(knee, th * 0.6, tc)
		"blade":
			ci.draw_line(hip, knee, c, th * 1.2)
			var pts := PackedVector2Array()
			for k in 8:
				var f := k / 7.0
				pts.append(knee.lerp(foot, f) + perp * sin(f * PI) * 14.0)
			ci.draw_polyline(pts, tc.darkened(0.15), 6.0)
		"hover":
			ci.draw_line(hip, foot + Vector2(0, -14), c, th)
			ci.draw_rect(Rect2(foot.x - 12.0, foot.y - 20.0, 24.0, 10.0), c.darkened(0.3))
		"spider":
			var up := hip + Vector2(16.0, -22.0) if pose == "stand" else hip.lerp(foot, 0.4) - perp * 20.0
			ci.draw_line(hip, up, c, th)
			ci.draw_line(up, foot, c, th * 0.8)
			ci.draw_circle(up, th * 0.6, c.darkened(0.3))
		"pogo":
			var mid := hip.lerp(foot, 0.45)
			ci.draw_line(hip, mid, c, th * 1.3)
			var pts := PackedVector2Array()
			for k in 9:
				var f := k / 8.0
				pts.append(mid.lerp(foot, f) + perp * (9.0 if k % 2 else -9.0) * (0.0 if k == 0 or k == 8 else 1.0))
			ci.draw_polyline(pts, tc, 3.0)
			ci.draw_line(mid, foot, c.darkened(0.3), 3.0)
		"wheel":
			ci.draw_line(hip, knee, c, th)
			ci.draw_line(knee, foot + Vector2(0, -12), c, th * 0.8)
		"tread":
			ci.draw_line(hip, foot + Vector2(0, -10), c, th)
		_:
			ci.draw_line(hip, knee, c, th)
			ci.draw_line(knee, foot, c, th * 0.85)
			ci.draw_circle(knee, th * 0.5, c.darkened(0.25))
	ci.draw_circle(hip, th * 0.5, c.darkened(0.3))
	# foot
	var fw := 26.0 * maxf(sz, 0.8)
	if p["shape"] == "pillar":
		fw = 36.0
	if p["shape"] == "wheel":
		var wc := foot + Vector2(0, -12)
		ci.draw_circle(wc, 13.0, Color(0.12, 0.12, 0.14))
		ci.draw_circle(wc, 6.0, tc)
		var a := -foot.x * 0.15
		ci.draw_line(wc + Vector2(cos(a), sin(a)) * 11.0, wc - Vector2(cos(a), sin(a)) * 11.0, tc.darkened(0.3), 2.0)
	elif p["shape"] == "tread":
		var tr := Rect2(foot.x - 22.0, foot.y - 18.0, 46.0, 18.0)
		ci.draw_rect(tr, Color(0.15, 0.15, 0.17))
		for k in 6:
			ci.draw_line(Vector2(tr.position.x + 4 + k * 8, tr.position.y), Vector2(tr.position.x + 4 + k * 8, tr.end.y), Color(0.3, 0.3, 0.32), 2.0)
		ci.draw_circle(Vector2(tr.position.x + 8, tr.get_center().y), 5.0, tc)
		ci.draw_circle(Vector2(tr.end.x - 8, tr.get_center().y), 5.0, tc)
	elif p["shape"] == "pogo":
		ci.draw_rect(Rect2(foot.x - 14.0, foot.y - 6.0, 28.0, 6.0), Color(0.15, 0.15, 0.17))
	elif p["shape"] == "hover":
		var gl := 0.6 + 0.4 * sin(foot.x * 0.3 + Time.get_ticks_msec() * 0.02)
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-10, -10), foot + Vector2(10, -10), foot + Vector2(0, 6.0 + 8.0 * gl)]), Color(0.4, 0.8, 1.0, 0.8))
	elif p["shape"] == "spider":
		ci.draw_line(foot, foot + Vector2(10, 4), tc, 4.0)
		ci.draw_line(foot, foot + Vector2(-6, 4), tc, 4.0)
	elif p["shape"] == "blade":
		ci.draw_line(foot + Vector2(-4, 0), foot + Vector2(18, 0), tc, 4.0)
	elif pose == "kick" or pose == "sweep" or pose == "high_kick":
		ci.draw_rect(Rect2(foot.x - 2.0, foot.y - 12.0, 12.0, 22.0), tc)
	elif p["shape"] == "reverse":
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-8, 0), foot + Vector2(22, 0), foot + Vector2(-2, -10)]), tc)
	else:
		ci.draw_rect(Rect2(foot.x - fw * 0.3, -8.0, fw, 8.0), tc)
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
	match p["shape"]:
		"barrel":
			ci.draw_colored_polygon(_rounded(r, w * 0.3), c)
			ci.draw_line(Vector2(x0 + 4, y0 + r.size.y * 0.25), Vector2(x1 - 4, y0 + r.size.y * 0.25), trim, 4.0)
			ci.draw_line(Vector2(x0 + 4, y0 + r.size.y * 0.75), Vector2(x1 - 4, y0 + r.size.y * 0.75), trim, 4.0)
		"vee":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - w * 0.2, y1), Vector2(x0 + w * 0.2, y1)]), c)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 12), trim)
			ci.draw_line(Vector2(x0 + w * 0.2, y1 - 6), Vector2(x1 - w * 0.2, y1 - 6), trim, 6.0)
		"tank":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 6, y0 - 4, w + 12, 16), trim)
			for row in 3:
				for col in 4:
					ci.draw_circle(Vector2(x0 + 10 + col * (w - 20) / 3.0, y0 + 24 + row * (r.size.y - 34) / 2.0), 2.5, c.darkened(0.4))
			ci.draw_line(Vector2(x0, y0 + r.size.y * 0.55), Vector2(x1, y0 + r.size.y * 0.55), c.darkened(0.3), 3.0)
		"crate":
			ci.draw_rect(r, c)
			ci.draw_rect(r, c.darkened(0.4), false, 3.0)
			ci.draw_line(r.position, r.end, c.darkened(0.3), 4.0)
			ci.draw_line(Vector2(x1, y0), Vector2(x0, y1), c.darkened(0.3), 4.0)
			ci.draw_rect(Rect2(x0 + w * 0.3, y0 + 8, w * 0.4, 10), trim)
		"furnace":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 10), trim)
			var grill := Rect2(x0 + w * 0.2, y0 + r.size.y * 0.45, w * 0.6, r.size.y * 0.35)
			ci.draw_rect(grill, Color(0.08, 0.05, 0.03))
			var fire := 0.6 + 0.4 * sin(t * 15.0)
			ci.draw_rect(grill.grow(-4.0), Color(1.0, 0.45 * fire, 0.1, 0.9))
			for k in 4:
				ci.draw_line(Vector2(grill.position.x + 4 + k * grill.size.x / 4.0, grill.position.y), Vector2(grill.position.x + 4 + k * grill.size.x / 4.0, grill.end.y), Color(0.15, 0.15, 0.15), 3.0)
			ci.draw_rect(Rect2(x1 - 14, y0 - 22, 10, 22), c.darkened(0.3))   # chimney
		"orb":
			var oc := r.get_center()
			ci.draw_circle(oc, minf(w, r.size.y) * 0.5, c)
			ci.draw_arc(oc, minf(w, r.size.y) * 0.5, PI * 1.1, PI * 1.9, 14, trim, 5.0)
			ci.draw_line(Vector2(oc.x - w * 0.45, oc.y), Vector2(oc.x + w * 0.45, oc.y), c.darkened(0.3), 3.0)
		"yoke", "quad", "monster":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 8, y0 - 4, w + 16, 16), trim)
			ci.draw_rect(Rect2(x0 + 6, y1 - 16, w - 12, 12), trim.darkened(0.2))
			ci.draw_rect(Rect2(x0 + w * 0.3, y0 + 20, w * 0.4, r.size.y * 0.45), c.darkened(0.25))
			if p["shape"] != "yoke":
				ci.draw_rect(Rect2(x0 - 6, y0 + r.size.y * 0.5, w + 12, 10), trim.darkened(0.1))   # second shoulder bar
			if p["shape"] == "monster":
				for k in 4:
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 8 + k * (w - 16) / 3.0 - 6, y0 - 4), Vector2(x0 + 8 + k * (w - 16) / 3.0, y0 - 18), Vector2(x0 + 8 + k * (w - 16) / 3.0 + 6, y0 - 4)]), trim)
		"ribcage":
			ci.draw_rect(Rect2(x0 + w * 0.42, y0, w * 0.16, r.size.y), c.darkened(0.2))
			for k in 5:
				var y := y0 + 8 + k * (r.size.y - 16) / 4.0
				ci.draw_line(Vector2(x0, y), Vector2(x1, y), c, 7.0)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 10), trim)
		"hex":
			var hc := r.get_center()
			var hp_pts := PackedVector2Array()
			for k in 6:
				var a := PI / 6.0 + k * TAU / 6.0
				hp_pts.append(hc + Vector2(cos(a) * w * 0.55, sin(a) * r.size.y * 0.55))
			ci.draw_colored_polygon(hp_pts, c)
			hp_pts.append(hp_pts[0])
			ci.draw_polyline(hp_pts, trim, 4.0)
			ci.draw_line(hc - Vector2(w * 0.3, 0), hc + Vector2(w * 0.3, 0), c.darkened(0.35), 3.0)
		"cannon":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 12), trim)
			if front:
				# the cannon's muzzle, looking straight at you
				var m := Vector2(r.get_center().x, y0 + r.size.y * 0.66)
				ci.draw_circle(m, 13.0, c.darkened(0.3))
				ci.draw_circle(m, 9.0, Color(0.08, 0.08, 0.08))
				ci.draw_arc(m, 9.0, 0, TAU, 16, trim, 3.0)
			else:
				var mouth := Vector2(x1, y0 + r.size.y * 0.5)
				ci.draw_rect(Rect2(x1 - 10, mouth.y - 11, 26, 22), c.darkened(0.3))
				ci.draw_circle(mouth + Vector2(16, 0), 10.0, Color(0.08, 0.08, 0.08))
				ci.draw_arc(mouth + Vector2(16, 0), 10.0, 0, TAU, 16, trim, 3.0)
		"slim":
			ci.draw_rect(r, c)
			ci.draw_line(Vector2(x0, y1 - 10), Vector2(x1, y0 + 20), trim, 5.0)
			ci.draw_rect(Rect2(x0 - 3, y0, w + 6, 8), trim)
		"core":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 12), trim)
			ci.draw_rect(Rect2(x0, y1 - 12, w, 10), trim)
			var pulse := 0.85 + 0.15 * sin(t * 4.0)
			ci.draw_circle(chest + Vector2(0, 6), w * 0.27, c.darkened(0.45))
			ci.draw_circle(chest + Vector2(0, 6), w * 0.2 * pulse, eye)
			ci.draw_circle(chest + Vector2(0, 6), w * 0.09, Color(1, 1, 1, 0.8))
		_:
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 - 4, y0 - 2, w + 8, 12), trim)
			ci.draw_rect(Rect2(x0, y1 - 14, w, 10), trim)
	if p["shape"] != "core":
		ci.draw_circle(chest, 9.0, eye.darkened(0.45))
		ci.draw_circle(chest, 6.0, eye)
	# damage
	var hp: float = p.get("health", 1.0)
	if hp < 0.7:
		ci.draw_line(Vector2(x0 + w * 0.2, y0 + 20), Vector2(x0 + w * 0.4, y0 + 34), Color(0.05, 0.05, 0.05), 2.0)
		ci.draw_line(Vector2(x0 + w * 0.4, y0 + 34), Vector2(x0 + w * 0.3, y0 + 46), Color(0.05, 0.05, 0.05), 2.0)
	if hp < 0.4:
		ci.draw_circle(Vector2(x1 - w * 0.25, y1 - 22), 7.0, Color(0.08, 0.07, 0.07, 0.8))
		ci.draw_line(Vector2(x0 + 6, y1 - 30), Vector2(x0 + w * 0.5, y1 - 20), Color(1.0, 0.4, 0.1, 0.5 + 0.4 * sin(t * 10.0)), 2.0)


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
	if not look.get("icon", false):
		ci.draw_rect(Rect2(r.get_center().x - 6.0, g["top"] - 8.0, 12, 10), c.darkened(0.35))   # neck
	match p["shape"]:
		"bucket":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 5, y0), Vector2(x0 + w - 5, y0), Vector2(x0 + w + 2, y0 + h), Vector2(x0 - 2, y0 + h)]), c)
			ci.draw_arc(Vector2(cen.x, y0), w * 0.35, PI, TAU, 10, trim, 2.0)
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
			ci.draw_colored_polygon(pts, c)
			ci.draw_rect(Rect2(cen.x - (w * 0.3 if front else w * 0.1), y0 + h * 0.5, w * 0.6 if front else w * 0.55, 6), eye)
			ci.draw_circle(Vector2(cen.x - w * 0.15, y0 + h * 0.25), 4.0, Color(1, 1, 1, 0.35))
		"cyclops":
			var rad := minf(w, h) * 0.5
			ci.draw_circle(cen, rad, c)
			var cx := 0.0 if front else 1.0
			ci.draw_circle(cen + Vector2(rad * 0.25 * cx, 0), rad * 0.55, trim)
			ci.draw_circle(cen + Vector2(rad * 0.3 * cx, 0), rad * 0.42, eye)
			ci.draw_circle(cen + Vector2(rad * 0.4 * cx, 0), rad * 0.15, Color(0.05, 0.05, 0.05))
		"visor":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 + 2, y0 + h * 0.35, w - 2, h * 0.3), eye)
			for k in 3:
				ci.draw_line(Vector2(x0 + 5 + k * 5, y0 + h * 0.75), Vector2(x0 + 5 + k * 5, y0 + h - 3), c.darkened(0.4), 2.0)
		"horned":
			ci.draw_rect(r, c)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0 + 4), Vector2(x0 + 10, y0), Vector2(x0 - 8, y0 - 18)]), trim)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + w, y0 + 4), Vector2(x0 + w - 10, y0), Vector2(x0 + w + 8, y0 - 18)]), trim)
			ci.draw_rect(Rect2(cen.x - (w * 0.25 if front else 2.0), y0 + h * 0.38, w * 0.5 if front else w * 0.45, 6), eye)
		"skull":
			ci.draw_rect(Rect2(x0, y0, w, h * 0.62), c)
			ci.draw_rect(Rect2(x0 + 2, y0 + h * 0.68, w - 2, h * 0.32), c.darkened(0.15))
			for k in 5:
				var tx := x0 + 6 + k * (w - 10) / 4.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, y0 + h * 0.62), Vector2(tx + 3, y0 + h * 0.62), Vector2(tx, y0 + h * 0.75)]), Color(0.9, 0.9, 0.85))
			var kx := -w * 0.175 if front else 0.0
			ci.draw_circle(Vector2(cen.x + w * 0.05 + kx, y0 + h * 0.3), 4.5, eye)
			ci.draw_circle(Vector2(cen.x + w * 0.3 + kx, y0 + h * 0.3), 4.5, eye)
		"wedge":
			if front:
				# a wedge seen nose-on: a shield shape with a fin on top and a V of an eye
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, y0 + h * 0.6), Vector2(cen.x, y0 + h + 4), Vector2(x0, y0 + h * 0.6)]), c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cen.x - 4, y0), Vector2(cen.x, y0 - 14), Vector2(cen.x + 4, y0)]), trim)
				ci.draw_line(Vector2(x0 + w * 0.2, y0 + h * 0.4), Vector2(cen.x, y0 + h * 0.55), eye, 4.0)
				ci.draw_line(Vector2(x0 + w * 0.8, y0 + h * 0.4), Vector2(cen.x, y0 + h * 0.55), eye, 4.0)
			else:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w * 0.55, y0), Vector2(x0 + w + 8, y0 + h * 0.7), Vector2(x0 + w, y0 + h), Vector2(x0, y0 + h)]), c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + w * 0.2, y0), Vector2(x0 + w * 0.35, y0 - 14), Vector2(x0 + w * 0.5, y0)]), trim)
				ci.draw_line(Vector2(x0 + w * 0.5, y0 + h * 0.45), Vector2(x0 + w + 2, y0 + h * 0.62), eye, 4.0)
		"tall":
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(x0 + 4, y0 + 8, w - 4, 6), eye)
			ci.draw_line(Vector2(cen.x, y0), Vector2(cen.x, y0 - 22), trim, 3.0)
			ci.draw_line(Vector2(cen.x - 10, y0 - 12), Vector2(cen.x + 10, y0 - 12), trim, 2.0)
			ci.draw_line(Vector2(cen.x - 7, y0 - 18), Vector2(cen.x + 7, y0 - 18), trim, 2.0)
			ci.draw_circle(Vector2(cen.x, y0 - 23), 3.0, eye if fmod(t, 1.0) < 0.5 else eye.darkened(0.6))
			for k in 3:
				ci.draw_line(Vector2(x0 + 3, y0 + 22 + k * 8), Vector2(x0 + w - 3, y0 + 22 + k * 8), c.darkened(0.35), 2.0)
		"knight":
			ci.draw_rect(Rect2(x0, y0 + h * 0.15, w, h * 0.85), c)
			var dome := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				dome.append(Vector2(cen.x, y0 + h * 0.2) + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.22))
			ci.draw_colored_polygon(dome, c)
			ci.draw_rect(Rect2(x0 + (w * 0.15 if front else w * 0.35), y0 + h * 0.38, w * (0.7 if front else 0.62), 5), Color(0.05, 0.05, 0.05))
			ci.draw_rect(Rect2(x0 + (w * 0.3 if front else w * 0.45), y0 + h * 0.38, w * 0.4, 5), eye)
			for k in 3:
				ci.draw_line(Vector2(x0 + w * 0.5 + k * 6, y0 + h * 0.58), Vector2(x0 + w * 0.5 + k * 6, y0 + h * 0.85), c.darkened(0.45), 2.0)
			ci.draw_line(Vector2(cen.x - 4, y0), Vector2(cen.x - 16, y0 - 16), trim, 6.0)
			ci.draw_line(Vector2(cen.x - 10, y0 - 4), Vector2(cen.x - 22, y0 - 12), trim.darkened(0.2), 5.0)
		"orb":
			var rad := minf(w, h) * 0.5
			ci.draw_circle(cen, rad, c)
			if front:
				ci.draw_arc(cen + Vector2(0, rad * 0.1), rad * 0.55, 0.5, PI - 0.5, 12, eye, 3.0)
				ci.draw_circle(cen + Vector2(0, -rad * 0.1), rad * 0.22, eye)
			else:
				ci.draw_arc(cen, rad * 0.8, -0.8, 0.8, 12, eye, 4.0)
				ci.draw_circle(cen + Vector2(rad * 0.45, -rad * 0.1), rad * 0.22, eye)
			ci.draw_circle(cen + Vector2(-rad * 0.35, -rad * 0.4), rad * 0.18, Color(1, 1, 1, 0.3))
		"speaker":
			ci.draw_rect(r, c)
			var sc2 := Vector2(cen.x + (0.0 if front else w * 0.12), cen.y + h * 0.05)
			for k in 3:
				ci.draw_arc(sc2, h * (0.12 + k * 0.1), 0, TAU, 16, c.darkened(0.35 + k * 0.1), 3.0)
			ci.draw_circle(sc2, h * 0.08, eye)
			var pulse := 0.6 + 0.4 * sin(t * 12.0)
			ci.draw_arc(sc2, h * 0.48 * pulse, -0.5, 0.5, 8, Color(eye.r, eye.g, eye.b, 0.5), 2.0)
			ci.draw_rect(Rect2(x0 + 3, y0 + 3, w * 0.25, 5), eye)
		"tv":
			ci.draw_rect(r, c)
			var scr := Rect2(x0 + 5, y0 + 5, w - 14, h - 10)
			ci.draw_rect(scr, Color(0.05, 0.12, 0.08))
			var face_y := scr.position.y + scr.size.y * 0.4
			var tvx := -scr.size.x * 0.2 if front else 0.0
			ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.45 + tvx, face_y, 5, 5), eye)
			ci.draw_rect(Rect2(scr.position.x + scr.size.x * 0.75 + tvx, face_y, 5, 5), eye)
			ci.draw_line(Vector2(scr.position.x + scr.size.x * 0.45 + tvx, face_y + 12), Vector2(scr.end.x - 4 + tvx, face_y + 12), eye, 2.0)
			var scan := scr.position.y + fmod(t * 30.0, scr.size.y)
			ci.draw_line(Vector2(scr.position.x, scan), Vector2(scr.end.x, scan), Color(1, 1, 1, 0.12), 2.0)
			ci.draw_line(Vector2(cen.x - 6, y0), Vector2(cen.x - 14, y0 - 14), trim, 2.0)
			ci.draw_line(Vector2(cen.x + 2, y0), Vector2(cen.x + 10, y0 - 14), trim, 2.0)
		"dish":
			ci.draw_rect(Rect2(x0 + w * 0.2, y0 + h * 0.45, w * 0.6, h * 0.55), c)
			ci.draw_rect(Rect2(cen.x - (w * 0.16 if front else 0.0), y0 + h * 0.6, w * 0.32, 6), eye)
			var dc := Vector2(cen.x - 2, y0 + h * 0.2)
			var wob := sin(t * 2.0) * 0.4
			ci.draw_arc(dc, w * 0.45, PI + 0.3 + wob, TAU - 0.3 + wob, 14, trim, 5.0)
			ci.draw_line(dc, dc + Vector2(sin(wob) * 4.0, -w * 0.3), trim, 2.0)
			ci.draw_circle(dc + Vector2(sin(wob) * 4.0, -w * 0.3), 3.0, eye)
		"laser":
			ci.draw_rect(r, c)
			var lz := Vector2(cen.x, cen.y + 2) if front else Vector2(x0 + w + 10, cen.y)
			if front:
				ci.draw_circle(lz, 10.0, c.darkened(0.3))
			else:
				ci.draw_rect(Rect2(x0 + w - 4, cen.y - 8, 14, 16), c.darkened(0.3))
			ci.draw_circle(lz, 7.0, eye)
			ci.draw_circle(lz, 3.0, Color(1, 1, 1, 0.9))
			ci.draw_line(Vector2(x0 + 3, y0 + 6), Vector2(x0 + w - 6, y0 + 6), c.darkened(0.4), 2.0)
		"bulb":
			ci.draw_rect(Rect2(cen.x - w * 0.3, y0 + h * 0.75, w * 0.6, h * 0.25), trim)
			ci.draw_circle(Vector2(cen.x, y0 + h * 0.42), w * 0.45, Color(c.r, c.g, c.b, 0.45))
			ci.draw_arc(Vector2(cen.x, y0 + h * 0.42), w * 0.45, 0, TAU, 24, c, 2.0)
			var fil := PackedVector2Array()
			for k in 7:
				fil.append(Vector2(cen.x - 10 + k * 3.3, y0 + h * 0.5 + (-6.0 if k % 2 else 0.0) + sin(t * 20.0 + k) * 1.5))
			ci.draw_polyline(fil, eye, 2.0)
		_:
			ci.draw_rect(r, c)
			ci.draw_rect(Rect2(cen.x - (w * 0.25 if front else -2.0), y0 + h * 0.36, w * (0.5 if front else 0.42), 7), eye)
			ci.draw_line(Vector2(x0 + 8, y0), Vector2(x0 + 4, y0 - 14), trim, 3.0)
			ci.draw_circle(Vector2(x0 + 4, y0 - 15), 3.0, eye)
	var hp: float = p.get("health", 1.0)
	if hp < 0.6:
		ci.draw_line(Vector2(x0 + w * 0.2, y0 + 3), Vector2(x0 + w * 0.35, y0 + h * 0.5), Color(0.05, 0.05, 0.05), 2.0)
	if hp < 0.3 and fmod(t * 5.0, 1.0) < 0.5:
		ci.draw_circle(Vector2(x0 + w * 0.3, y0 + h * 0.2), 3.0, Color(1.0, 0.8, 0.3))
