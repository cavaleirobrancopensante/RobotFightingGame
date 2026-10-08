extends RefCounted

const I18n = preload("res://i18n.gd")
## Clips (1.74): a few seconds of a fight kept as the moves the robots made, not as video.
##
## While a fight runs (your own, or one you watch) fight.gd keeps every robot's state 15 times a
## second (position, what it's doing, how far into it, every part's health) plus what popped up
## (sparks, smoke, parts flying, damage numbers) and the sounds. When something worth showing
## happens (a K.O., a part torn off, a finisher, a knockdown, a guard smashed, a long combo, a
## comeback) it's marked with a score; at the bell the best three marks become clips.
##
## A clip is stored small: each number is only written when it stops doing what the last two
## frames said it would (a walk, a timer counting, a fall all go by themselves), so a five-second
## clip is a few kilobytes. The fight scene plays it back by putting the robots in those states
## and drawing them as usual (fight.gd "replay").
##
## clip = {id, v, kind, score, tpl, args (English, translated when shown), arena, crowd,
##         scr [w, h], floor, bots [{spec, team, scale}], ko, str (string table), fr (frames),
##         at (the moment's frame), made [year, week, day], mine (your fight), temp (not posted yet)}
## frame = [world delta, [fighter deltas], events, sounds, projectiles]

const FPS := 15.0
const PRE := 4.0            # seconds before the moment
const POST := 1.6           # seconds after it (a K.O. or a big moment keeps going to its end)
const KEEP := 3             # clips kept from one fight
const GAP := 3.0            # two marks closer than this are the same moment

## Per robot, per frame (vx / vy are never written: playback works the speed out from the
## positions; flash is just on / off). Strings (state, limb, special) are indices into the clip's string table.
const F := ["px", "py", "vx", "vy", "face", "state", "timer", "limb", "ground", "walk", "special", "block",
		"squash", "roll", "fist", "daze", "charge", "burn", "aim", "stun", "shield", "crouch", "flash",
		"over", "jet", "boost", "swap", "power",
		"hp_head", "hp_head2", "hp_torso", "hp_arm_front", "hp_arm_back", "hp_arm_front2", "hp_arm_back2", "hp_leg_front", "hp_leg_back"]
const N := 37
const HP0 := 28
const HOLD := [4, 5, 7, 8, 10, 11, 14, 21, 22, 26, 28, 29, 30, 31, 32, 33, 34, 35, 36]
const TOL := [2.5, 2.5, 1e9, 1e9, 0.0, 0.0, 0.02, 0.0, 0.0, 0.08, 0.0, 0.0,
		0.03, 0.03, 0.0, 0.03, 0.03, 0.03, 0.05, 0.03, 0.03, 0.0, 0.0,
		0.05, 0.03, 0.03, 0.0, 0.9,
		0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
## The world: [clock, moment_t, moment kind, moment name, moment on (robot index), shake, time_left]
const WN := 7
const W_HOLD := [2, 3, 4]
const W_TOL := [0.02, 0.03, 0.0, 0.0, 0.0, 3.0, 0.1]

## What a moment is called and how much it's worth (the best three of a fight become clips).
const KIND_NAMES := {"ko": "K.O.", "rip": "PART TORN OFF", "finisher": "FINISHER", "special": "SPECIAL",
		"down": "KNOCKDOWN", "guard": "GUARD BROKEN", "combo": "COMBO", "comeback": "COMEBACK", "close": "AT THE BELL"}


static func _hold(i: int, world: bool) -> bool:
	return (W_HOLD if world else HOLD).has(i)


## Turn full states (PackedFloat32Array each) into the small form: [i, v, i, v, ...] for what
## the last two frames didn't predict. enc = [prev, prev2] decoded states (kept in step with
## the decoder, so the error never grows past the tolerance).
static func _delta(cur: PackedFloat32Array, enc: Array, world: bool) -> Array:
	var prev: PackedFloat32Array = enc[0]
	var prev2: PackedFloat32Array = enc[1]
	var tol: Array = W_TOL if world else TOL
	var out: Array = []
	var dec := PackedFloat32Array()
	dec.resize(cur.size())
	for i in cur.size():
		var guess: float = prev[i] if _hold(i, world) else prev[i] + (prev[i] - prev2[i])
		var v: float = cur[i]
		var t: float = tol[i] if i < tol.size() else 0.02
		if absf(v - guess) > maxf(t, 0.0001):
			var sv: float = snappedf(v, 1.0 if (i < 4 or i >= HP0) and not world else 0.01)
			out.append(i)
			out.append(int(sv) if sv == floorf(sv) and absf(sv) < 1e8 else sv)   # whole numbers are written without the ".0"
			dec[i] = sv
		else:
			dec[i] = guess
	enc[1] = prev
	enc[0] = dec
	return out


static func _undelta(d: Array, enc: Array, world: bool) -> PackedFloat32Array:
	var prev: PackedFloat32Array = enc[0]
	var prev2: PackedFloat32Array = enc[1]
	var dec := PackedFloat32Array()
	dec.resize(prev.size())
	for i in prev.size():
		dec[i] = prev[i] if _hold(i, world) else prev[i] + (prev[i] - prev2[i])
	var k := 0
	while k + 1 < d.size():
		var i := int(d[k])
		if i < dec.size():
			dec[i] = float(d[k + 1])
		k += 2
	enc[1] = prev
	enc[0] = dec
	return dec


## frames (fight.gd's recording): [world, [fighters], events, sounds, projectiles], full states.
static func encode(frames: Array, from: int, to: int, nbots: int) -> Array:
	var out: Array = []
	var w_enc := [_zeros(WN), _zeros(WN)]
	var f_enc: Array = []
	for b in nbots:
		f_enc.append([_zeros(N), _zeros(N)])
	var pj_guess: Array = []
	for k in range(from, to):
		var fr: Array = frames[k]
		var fd: Array = []
		for b in nbots:
			fd.append(_delta(fr[1][b], f_enc[b], false))
		var row: Array = [_delta(fr[0], w_enc, true), fd]
		if k == from:
			# the first frame starts the prediction afresh: no motion carried in from nowhere
			w_enc[1] = w_enc[0]
			for b in nbots:
				f_enc[b][1] = f_enc[b][0]
		var ev: Array = fr[2]
		var snd: Array = fr[3]
		# projectiles fly in straight lines: written only when that stops being true (or they change)
		var pj = fr[4]
		if _pj_same(pj, pj_guess) and k != from:
			pj = null
		# the decoder moves what it has on by its speed; next frame is checked against that
		var base: Array = pj_guess if pj == null else pj
		pj_guess = []
		for p in base:
			var q: Array = (p as Array).duplicate()
			q[2] = float(q[2]) + float(q[4]) / FPS
			pj_guess.append(q)
		if not ev.is_empty() or not snd.is_empty() or pj != null:
			row.append(ev)
		if not snd.is_empty() or pj != null:
			row.append(snd)
		if pj != null:
			row.append(pj)
		out.append(row)
	return out


## Back to full states: [[world, [fighters], events, sounds, projectiles], ...].
static func decode(clip: Dictionary) -> Array:
	var nb: int = (clip.get("bots", []) as Array).size()
	var w_enc := [_zeros(WN), _zeros(WN)]
	var f_enc: Array = []
	for b in nb:
		f_enc.append([_zeros(N), _zeros(N)])
	var out: Array = []
	var first := true
	for row in clip.get("fr", []):
		var r: Array = row
		var w := _undelta(r[0], w_enc, true)
		var fs: Array = []
		for b in nb:
			fs.append(_undelta(r[1][b] if b < (r[1] as Array).size() else [], f_enc[b], false))
		if first:
			w_enc[1] = w_enc[0]
			for b in nb:
				f_enc[b][1] = f_enc[b][0]
			first = false
		out.append([w, fs, r[2] if r.size() > 2 else [], r[3] if r.size() > 3 else [], r[4] if r.size() > 4 else null])
	return out


static func _pj_same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		var p: Array = a[k]
		var q: Array = b[k]
		if str(p[0]) != str(q[0]) or int(p[1]) != int(q[1]) or int(p[5]) != int(q[5]) \
				or absf(float(p[2]) - float(q[2])) > 6.0 or absf(float(p[3]) - float(q[3])) > 6.0:
			return false
	return true


static func _zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


## How long it runs, in seconds.
static func length(clip: Dictionary) -> float:
	return (clip.get("fr", []) as Array).size() / FPS


## The line under it, in the player's language.
static func title(clip: Dictionary) -> String:
	var args: Array = []
	for a in clip.get("args", []):
		args.append(I18n.t(str(a)))
	var tpl := I18n.t(str(clip.get("tpl", "%s")))
	if tpl.count("%s") != args.size():
		return tpl
	return tpl % args


static func kind_name(clip: Dictionary) -> String:
	return I18n.t(KIND_NAMES.get(str(clip.get("kind", "")), "CLIP"))


## A rough size on disk (bytes), for the tests.
static func size_of(clip: Dictionary) -> int:
	return JSON.stringify(clip).length()


## Anything a JSON save can't hold as it is (colours, vectors) turned into plain values.
static func plain(v):
	if v is Color:
		return "#" + (v as Color).to_html()
	if v is Vector2 or v is Vector2i:
		return [v.x, v.y]
	if v is Dictionary:
		var d := {}
		for k in v:
			d[str(k)] = plain(v[k])
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(plain(x))
		return a
	if v is PackedStringArray or v is PackedFloat32Array or v is PackedInt32Array:
		return plain(Array(v))
	return v
