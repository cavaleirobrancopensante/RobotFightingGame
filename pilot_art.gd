extends RefCounted
## Draws pilots: the little doll in the fight corner, the story portraits and the garage preview.
##
## look: {"skin", "hair" (hair/hat color), "eyes" (eye color), "outfit", "hat", "beard", "glasses",
##        "controller", "long_hair" (bool), "scar" (bool)}

const RA = preload("res://robot_art.gd")

## Diagnostic Noir (1.60): the light set the next people are drawn in ("" = the old flat look). Each
## scene that draws people sets it first (the fight: its venue; the garage: the room; faces in the
## menus: "neutral"); the opening and the main menu set "" until their own restyle.
static var light := ""
const HATS := ["", "beanie", "cap", "helmet", "mohawk", "bun", "bald", "cowboy", "headband", "tophat"]
const HAT_NAMES := {"": "Short hair", "beanie": "Beanie", "cap": "Cap", "helmet": "Helmet", "mohawk": "Mohawk",
		"bun": "Hair bun", "bald": "Bald", "cowboy": "Cowboy hat", "headband": "Headband", "tophat": "Top hat"}
const BEARDS := ["none", "stubble", "full", "goatee", "mustache", "handlebar", "chinstrap", "muttonchops", "long", "braided"]
const BEARD_NAMES := {"none": "None", "stubble": "Stubble", "full": "Full beard", "goatee": "Goatee", "mustache": "Mustache",
		"handlebar": "Handlebar", "chinstrap": "Chin strap", "muttonchops": "Mutton chops", "long": "Long beard", "braided": "Braided"}
const GLASSES := ["none", "round", "square", "shades", "goggles", "monocle", "visor", "eyepatch", "cateye", "cyber"]
const GLASSES_NAMES := {"none": "None", "round": "Round", "square": "Square", "shades": "Shades", "goggles": "Goggles",
		"monocle": "Monocle", "visor": "Visor", "eyepatch": "Eye patch", "cateye": "Cat-eye", "cyber": "Cyber eye"}
const CONTROLLERS := ["gamepad", "arcade", "joysticks", "yoke", "tablet", "wheel", "radio", "keyboard", "gloves", "brick"]
const CONTROLLER_NAMES := {"gamepad": "Gamepad", "arcade": "Arcade stick", "joysticks": "Twin sticks", "yoke": "Flight yoke",
		"tablet": "Tablet", "wheel": "Wheel", "radio": "RC radio", "keyboard": "Keyboard", "gloves": "Motion gloves", "brick": "Retro brick"}
const EYES := ["#5b3a1e", "#2e86de", "#27ae60", "#9c7a3c", "#8395a7", "#f39c12", "#8e44ad", "#c0392b"]
const EYE_NAMES := ["Brown", "Blue", "Green", "Hazel", "Grey", "Amber", "Violet", "Red"]
const SKINS := ["#f1d0b5", "#e2b48c", "#c8946e", "#b07a52", "#8d5a3b", "#5e3a24"]
const COLORS := ["#d9482f", "#2a1d14", "#e8d36a", "#7a4b2a", "#c0c0c0", "#1f6fd1", "#2ecc71", "#e056fd", "#f39c12", "#ecf0f1", "#3e5c4f", "#34495e", "#8e2c1c", "#222222"]
const EXTRAS := [[], ["long_hair"], ["scar"], ["long_hair", "scar"]]


## Older saves and story faces used true/false for beard / glasses / goggles.
## Roll a random face and outfit (keeps the controller).
static func randomize_look(look: Dictionary) -> void:
	look["skin"] = SKINS[randi() % SKINS.size()]
	look["eyes"] = EYES[randi() % EYES.size()]
	look["hair"] = COLORS[randi() % COLORS.size()]
	look["outfit"] = COLORS[randi() % COLORS.size()]
	look["hat"] = HATS[randi() % HATS.size()]
	look["beard"] = BEARDS[randi() % BEARDS.size()]
	look["glasses"] = GLASSES[randi() % GLASSES.size()]
	var ex: Array = EXTRAS[randi() % EXTRAS.size()]
	for e in ["long_hair", "scar"]:
		look[e] = ex.has(e)


static func normalize(look: Dictionary) -> Dictionary:
	var l := look.duplicate()
	var beard = l.get("beard", "none")
	l["beard"] = ("full" if beard else "none") if typeof(beard) == TYPE_BOOL else str(beard)
	var gl = l.get("glasses", "none")
	if typeof(gl) == TYPE_BOOL:
		gl = "round" if gl else "none"
	if l.get("goggles", false) == true:
		gl = "goggles"
	l["glasses"] = str(gl)
	if not l.has("eyes"):
		l["eyes"] = EYES[0]
	if not l.has("controller"):
		l["controller"] = "gamepad"
	return l


## A head. dir: 1 = looking right, -1 = left, 0 = facing you. mouth: how open (pixels).
## Everyone blinks: one blink every 1-5 seconds, at a random-looking moment. Each person's rhythm
## comes from their look, so two people in the same scene don't blink in sync.
const BLINK_TIME := 0.13
static func blinking(look: Dictionary) -> bool:
	var seed := absi(hash(str(look.get("skin", "")) + str(look.get("hair", "")) + str(look.get("eyes", "")) + str(look.get("outfit", "")) + str(look.get("hat", ""))))
	var t := Time.get_ticks_msec() / 1000.0 + float(seed % 1000) * 0.37
	# 3-second windows, each with one blink somewhere in its first 2 seconds: gaps of 1 to 5 seconds
	var k := int(floor(t / 3.0))
	var at := float(k) * 3.0 + float(absi(hash(seed + k * 7919)) % 1000) / 1000.0 * 2.0
	return t >= at and t < at + BLINK_TIME


static func draw_head(ci: CanvasItem, c: Vector2, r: float, raw: Dictionary, dir: float, mouth: float) -> void:
	var look := normalize(raw)
	_begin()
	var skin := Color(look.get("skin", "#c8946e"))
	var hair := Color(look.get("hair", "#2a1d14"))
	var eyes := Color(look.get("eyes", EYES[0]))
	var ex := dir * r * 0.15   # eyes shift toward where they look
	if look.get("long_hair", false):
		_rc(ci, Rect2(c + Vector2(-r * 1.05, -r * 0.5), Vector2(r * 2.1, r * 1.5)), hair)
	_head_disc(ci, c, r, skin)
	# headwear
	match str(look.get("hat", "")):
		"beanie":
			_rc(ci, Rect2(c + Vector2(-r, -r * 1.05), Vector2(r * 2.0, r * 0.6)), hair)
			_cr(ci, c + Vector2(0, -r * 1.1), r * 0.18, hair.lightened(0.3))
		"cap":
			_rc(ci, Rect2(c + Vector2(-r * 1.05, -r * 1.05), Vector2(r * 2.1, r * 0.5)), hair)
			var bx := -r * 0.2 if dir >= 0.0 else -r * 1.2
			_rc(ci, Rect2(c + Vector2(bx, -r * 0.65), Vector2(r * 1.4, r * 0.16)), hair.darkened(0.2))
		"helmet":
			_ac(ci, c, r * 1.05, PI, TAU, 16, hair, r * 0.35)
			_ln2(ci, c + Vector2(-r * 0.2, -r * 1.2), c + Vector2(r * 0.2, -r * 1.2), hair.lightened(0.4), r * 0.12)
		"mohawk":
			_rc(ci, Rect2(c + Vector2(-r * 0.18, -r * 1.6), Vector2(r * 0.36, r * 0.8)), hair)
		"bun":
			_cr(ci, c + Vector2(0, -r * 1.05), r * 0.35, hair)
			_rc(ci, Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.35)), hair)
		"bald":
			_cr(ci, c + Vector2(-r * 0.35, -r * 0.6), r * 0.15, Color(1, 1, 1, 0.25))
		"cowboy":
			_rc(ci, Rect2(c + Vector2(-r * 1.6, -r * 0.75), Vector2(r * 3.2, r * 0.2)), hair)
			_rc(ci, Rect2(c + Vector2(-r * 0.75, -r * 1.45), Vector2(r * 1.5, r * 0.75)), hair)
			_rc(ci, Rect2(c + Vector2(-r * 0.75, -r * 0.95), Vector2(r * 1.5, r * 0.12)), hair.lightened(0.35))
		"headband":
			_rc(ci, Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.35)), Color(0.15, 0.1, 0.08))
			_rc(ci, Rect2(c + Vector2(-r * 1.02, -r * 0.62), Vector2(r * 2.04, r * 0.22)), hair)
			_ln2(ci, c + Vector2(-dir * r, -r * 0.5), c + Vector2(-dir * r * 1.5, -r * 0.1), hair, r * 0.15)
		"tophat":
			_rc(ci, Rect2(c + Vector2(-r * 1.15, -r * 0.8), Vector2(r * 2.3, r * 0.18)), hair)
			_rc(ci, Rect2(c + Vector2(-r * 0.7, -r * 1.85), Vector2(r * 1.4, r * 1.1)), hair)
			_rc(ci, Rect2(c + Vector2(-r * 0.7, -r * 0.98), Vector2(r * 1.4, r * 0.15)), Color(0.75, 0.2, 0.2))
		_:
			_rc(ci, Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.4)), hair)
	# eyes
	var el := c + Vector2(ex - r * 0.33, -r * 0.08)
	var er := c + Vector2(ex + r * 0.33, -r * 0.08)
	var shut := blinking(look)
	for e in [el, er]:
		if shut:
			ci.draw_line(e + Vector2(-r * 0.14, 0), e + Vector2(r * 0.14, 0), skin.darkened(0.55), maxf(1.0, r * 0.06))
			continue
		ci.draw_circle(e, r * 0.14, Color.WHITE)
		ci.draw_circle(e + Vector2(dir * r * 0.04, 0), r * 0.08, eyes)
	# glasses
	var gc := Color(0.1, 0.1, 0.1)
	var w := maxf(1.5, r * 0.08)
	match str(look.get("glasses", "none")):
		"round":
			for e in [el, er]:
				ci.draw_arc(e, r * 0.22, 0, TAU, 12, gc, w)
			ci.draw_line(el + Vector2(r * 0.22, 0), er - Vector2(r * 0.22, 0), gc, w)
		"square":
			for e in [el, er]:
				ci.draw_rect(Rect2(e - Vector2(r * 0.22, r * 0.18), Vector2(r * 0.44, r * 0.36)), gc, false, w)
			ci.draw_line(el + Vector2(r * 0.22, 0), er - Vector2(r * 0.22, 0), gc, w)
		"shades":
			for e in [el, er]:
				ci.draw_rect(Rect2(e - Vector2(r * 0.24, r * 0.15), Vector2(r * 0.48, r * 0.3)), Color(0.05, 0.05, 0.08))
			ci.draw_line(el, er, Color(0.05, 0.05, 0.08), w)
		"goggles":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.78 + ex, -r * 0.32), Vector2(r * 1.56, r * 0.46)), Color(0.2, 0.5, 0.6, 0.85))
			ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.16), Vector2(r * 2.0, r * 0.12)), Color(0.25, 0.2, 0.15))
		"monocle":
			ci.draw_arc(er, r * 0.24, 0, TAU, 12, Color(0.85, 0.7, 0.2), w)
			ci.draw_line(er + Vector2(0, r * 0.24), er + Vector2(r * 0.15, r * 0.8), Color(0.85, 0.7, 0.2), 1.0)
		"visor":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.85 + ex, -r * 0.25), Vector2(r * 1.7, r * 0.3)), Color(1.0, 0.3, 0.3, 0.75))
		"eyepatch":
			ci.draw_circle(el, r * 0.2, Color(0.05, 0.05, 0.05))
			ci.draw_line(el + Vector2(-r * 0.2, -r * 0.1), c + Vector2(r * 0.9, -r * 0.6), Color(0.05, 0.05, 0.05), w)
		"cateye":
			for e in [el, er]:
				ci.draw_colored_polygon(PackedVector2Array([e + Vector2(-r * 0.25, -r * 0.05), e + Vector2(r * 0.25, -r * 0.2), e + Vector2(r * 0.2, r * 0.12), e + Vector2(-r * 0.2, r * 0.12)]), Color(0.8, 0.15, 0.5, 0.6))
		"cyber":
			ci.draw_circle(er, r * 0.2, Color(0.15, 0.15, 0.18))
			ci.draw_circle(er, r * 0.1, Color(1.0, 0.2, 0.2))
			ci.draw_line(er + Vector2(r * 0.2, 0), er + Vector2(r * 0.55, -r * 0.1), Color(0.6, 0.6, 0.65), w)
	# mouth, then facial hair over it
	var mc := c + Vector2(ex - r * 0.25, r * 0.36)
	ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
	var bc := Color(look["beard_color"]) if look.has("beard_color") else hair.lightened(0.12)
	match str(look.get("beard", "none")):
		"stubble":
			for k in 9:
				_cr(ci, c + Vector2(-r * 0.5 + (k % 5) * r * 0.25, r * 0.55 + (k / 5) * r * 0.18), r * 0.04, bc.darkened(0.2))
		"full":
			_cr(ci, c + Vector2(0, r * 0.55), r * 0.5, bc)
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
		"goatee":
			_rc(ci, Rect2(c + Vector2(-r * 0.15 + ex, r * 0.55), Vector2(r * 0.3, r * 0.4)), bc)
		"mustache":
			_rc(ci, Rect2(c + Vector2(-r * 0.32 + ex, r * 0.24), Vector2(r * 0.64, r * 0.13)), bc)
		"handlebar":
			_rc(ci, Rect2(c + Vector2(-r * 0.32 + ex, r * 0.24), Vector2(r * 0.64, r * 0.12)), bc)
			_ln2(ci, c + Vector2(-r * 0.32 + ex, r * 0.3), c + Vector2(-r * 0.55 + ex, r * 0.08), bc, w * 1.5)
			_ln2(ci, c + Vector2(r * 0.32 + ex, r * 0.3), c + Vector2(r * 0.55 + ex, r * 0.08), bc, w * 1.5)
		"chinstrap":
			_ac(ci, c, r * 0.95, 0.25, PI - 0.25, 14, bc, r * 0.15)
		"muttonchops":
			_rc(ci, Rect2(c + Vector2(-r * 0.98, -r * 0.1), Vector2(r * 0.3, r * 0.65)), bc)
			_rc(ci, Rect2(c + Vector2(r * 0.68, -r * 0.1), Vector2(r * 0.3, r * 0.65)), bc)
		"long":
			_pg(ci, PackedVector2Array([c + Vector2(-r * 0.6, r * 0.4), c + Vector2(r * 0.6, r * 0.4), c + Vector2(r * 0.15, r * 1.5), c + Vector2(-r * 0.15, r * 1.5)]), bc)
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
		"braided":
			_cr(ci, c + Vector2(0, r * 0.55), r * 0.4, bc)
			for k in 3:
				_cr(ci, c + Vector2(0, r * (0.95 + k * 0.2)), r * 0.12, bc.darkened(0.1 * k))
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
	if look.get("scar", false):
		_scar(ci, er, r, skin)


## (1.66) A scar through the brow and down the cheek, broken where it crosses the eye: pale healed
## skin with a darker edge, a few stitch marks on a big face.
static func _scar(ci: CanvasItem, e: Vector2, r: float, skin: Color) -> void:
	var a := e + Vector2(-r * 0.1, -r * 0.46)
	var b := e + Vector2(r * 0.2, r * 0.46)
	var d := (b - a).normalized()
	var gap := r * 0.2
	var edge := skin.darkened(0.32)
	var pale := skin.lightened(0.28).lerp(Color(0.95, 0.72, 0.68), 0.35)
	var w := maxf(1.2, r * 0.07)
	for seg in [[a, e - d * gap], [e + d * gap, b]]:
		var p0: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		var mid := p0.lerp(p1, 0.5) + d.orthogonal() * r * 0.02
		ci.draw_polyline(PackedVector2Array([p0, mid, p1]), edge, w)
		ci.draw_polyline(PackedVector2Array([p0, mid, p1]), pale, maxf(0.8, w * 0.45))
		if r >= 16.0:
			for k in 2:
				var q := p0.lerp(p1, 0.33 + k * 0.33)
				var o := d.orthogonal() * r * 0.04
				ci.draw_line(q - o, q + o, edge, maxf(0.8, w * 0.35))


## The controller in the pilot's hands. s = scale, active = buttons being pressed right now.
static func draw_controller(ci: CanvasItem, p: Vector2, s: float, kind: String, active: bool, t: float) -> void:
	var dark := Color(0.15, 0.15, 0.18)
	var lit := Color(0.3, 0.8, 1.0) if active else Color(0.2, 0.4, 0.5)
	var red := Color(0.9, 0.3, 0.3)
	match kind:
		"arcade":
			ci.draw_rect(Rect2(p + Vector2(-13 * s, -4 * s), Vector2(26 * s, 9 * s)), Color(0.2, 0.2, 0.25))
			ci.draw_line(p + Vector2(-6 * s, -4 * s), p + Vector2(-6 * s + (3 * s if active else 0.0), -12 * s), Color(0.6, 0.6, 0.6), 2.0 * s)
			ci.draw_circle(p + Vector2(-6 * s + (3 * s if active else 0.0), -12 * s), 3 * s, red)
			for k in 3:
				ci.draw_circle(p + Vector2((2 + k * 4) * s, -1 * s), 1.6 * s, lit if k == 0 else Color(0.9, 0.8, 0.2))
		"joysticks":
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(p + Vector2(side * 9 * s - 4 * s, -2 * s), Vector2(8 * s, 6 * s)), dark)
				var tip := p + Vector2(side * 9 * s + (sin(t * 30.0) * 2 * s if active else 0.0), -10 * s)
				ci.draw_line(p + Vector2(side * 9 * s, -2 * s), tip, Color(0.6, 0.6, 0.65), 2.0 * s)
				ci.draw_circle(tip, 2.2 * s, lit)
		"yoke":
			ci.draw_rect(Rect2(p + Vector2(-2 * s, -2 * s), Vector2(4 * s, 10 * s)), dark)
			ci.draw_line(p + Vector2(-12 * s, -6 * s), p + Vector2(12 * s, -6 * s), dark, 3 * s)
			ci.draw_line(p + Vector2(-12 * s, -6 * s), p + Vector2(-12 * s, 2 * s), dark, 3 * s)
			ci.draw_line(p + Vector2(12 * s, -6 * s), p + Vector2(12 * s, 2 * s), dark, 3 * s)
			ci.draw_circle(p + Vector2(10 * s, -6 * s), 1.5 * s, red)
		"tablet":
			ci.draw_rect(Rect2(p + Vector2(-12 * s, -8 * s), Vector2(24 * s, 15 * s)), dark)
			ci.draw_rect(Rect2(p + Vector2(-10 * s, -6 * s), Vector2(20 * s, 11 * s)), Color(0.1, 0.3, 0.45) if not active else Color(0.2, 0.55, 0.8))
			ci.draw_circle(p + Vector2(-4 * s + sin(t * 3.0) * 3 * s, -1 * s), 1.5 * s, Color(1, 1, 1, 0.7))
		"wheel":
			ci.draw_arc(p, 9 * s, 0, TAU, 18, dark, 3 * s)
			var a := sin(t * 20.0) * 0.4 if active else 0.0
			ci.draw_line(p, p + Vector2(cos(a - PI / 2.0), sin(a - PI / 2.0)) * 9 * s, dark, 2 * s)
			ci.draw_circle(p, 2.5 * s, red)
		"radio":
			ci.draw_rect(Rect2(p + Vector2(-10 * s, -7 * s), Vector2(20 * s, 14 * s)), Color(0.85, 0.82, 0.75))
			ci.draw_line(p + Vector2(8 * s, -7 * s), p + Vector2(12 * s, -24 * s), Color(0.6, 0.6, 0.65), 1.5)
			for side in [-1.0, 1.0]:
				ci.draw_circle(p + Vector2(side * 5 * s, -1 * s), 2.5 * s, dark)
				ci.draw_line(p + Vector2(side * 5 * s, -1 * s), p + Vector2(side * 5 * s + (sin(t * 25.0) * 2 * s if active else 0.0), -6 * s), Color(0.5, 0.5, 0.5), 1.5 * s)
		"keyboard":
			ci.draw_rect(Rect2(p + Vector2(-14 * s, -4 * s), Vector2(28 * s, 8 * s)), dark)
			for k in 6:
				var hit := active and int(t * 20.0 + k) % 3 == 0
				ci.draw_rect(Rect2(p + Vector2((-12 + k * 4) * s, -2 * s), Vector2(3 * s, 3 * s)), lit if hit else Color(0.5, 0.5, 0.55))
		"gloves":
			for side in [-1.0, 1.0]:
				ci.draw_circle(p + Vector2(side * 7 * s, 0), 4 * s, Color(0.2, 0.2, 0.25))
				ci.draw_circle(p + Vector2(side * 7 * s, 0), 2 * s, lit if active or int(t * 2.0) % 2 == 0 else Color(0.2, 0.4, 0.5))
		"brick":
			ci.draw_rect(Rect2(p + Vector2(-11 * s, -5 * s), Vector2(22 * s, 10 * s)), Color(0.78, 0.78, 0.76))
			ci.draw_rect(Rect2(p + Vector2(-8 * s, -1 * s), Vector2(5 * s, 1.6 * s)), dark)
			ci.draw_rect(Rect2(p + Vector2(-6.2 * s, -3 * s), Vector2(1.6 * s, 5 * s)), dark)
			ci.draw_circle(p + Vector2(4 * s, 1 * s), 1.6 * s, red if not active else Color(1, 0.6, 0.6))
			ci.draw_circle(p + Vector2(8 * s, -1 * s), 1.6 * s, red)
		_:   # gamepad
			ci.draw_rect(Rect2(p + Vector2(-10 * s, -5 * s), Vector2(20 * s, 10 * s)), dark)
			ci.draw_circle(p + Vector2(-10 * s, 2 * s), 4 * s, dark)
			ci.draw_circle(p + Vector2(10 * s, 2 * s), 4 * s, dark)
			ci.draw_circle(p + Vector2(-5 * s, 0), 2 * s, red)
			ci.draw_circle(p + Vector2(5 * s, 0), 2 * s, lit)
			ci.draw_line(p + Vector2(7 * s, -5 * s), p + Vector2(9 * s, -12 * s), Color(0.5, 0.5, 0.55), 1.5)


# ---------------------------------------------------------------- full-body people (garage scenes)

const GUS_LOOK := {"skin": "#6b4530", "hair": "#33507a", "hat": "cap", "beard": "full", "beard_color": "#c4c4c4",
		"eyes": "#5b3a1e", "glasses": "none", "outfit": "#33507a", "gus": true}


## A standing person. feet = where they stand, s = scale (1.0 is about 70px tall), dir = 1 facing right.
## pose: idle, wrench, type, hammer, spray, dig, point, clipboard, cheer, sit_type, hold
## Gus (look.gus) wears overalls and has his robot arm.
## Where a "grab" pose puts the hands (set by the scene just before drawing).
static var grab_at := Vector2.ZERO


static func draw_person(ci: CanvasItem, feet: Vector2, s: float, raw: Dictionary, dir: float, pose: String, t: float, tool_color: Color = Color(0.7, 0.7, 0.75)) -> void:
	var look := normalize(raw)
	_begin()
	var gus: bool = look.get("gus", false)
	var outfit := Color(look.get("outfit", "#34495e"))
	var shirt := Color(0.55, 0.42, 0.3) if gus else outfit
	var pants := outfit.darkened(0.35) if not gus else outfit.darkened(0.15)
	var sitting := pose in ["sit_type", "drink", "push"]
	var bob := sin(t * 2.0) * 0.8 * s
	# legs
	if sitting:
		# (1.63) both legs: the far leg goes behind the body now, the near one over the lap after it
		_sit_leg(ci, feet, s, dir, pants, 0)
	else:
		_blk(ci, Rect2(feet + Vector2(-8 * s, -24 * s), Vector2(7 * s, 24 * s)), pants)
		_blk(ci, Rect2(feet + Vector2(1 * s, -24 * s), Vector2(7 * s, 24 * s)), pants)
		_rc(ci, Rect2(feet + Vector2(-9 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.13, 0.1, 0.08))
		_rc(ci, Rect2(feet + Vector2(1 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.13, 0.1, 0.08))
	# body
	var hip := feet + Vector2(0, (-26 if sitting else -24) * s + bob)
	var neck := hip + Vector2(0, -30 * s)
	_blk(ci, Rect2(neck + Vector2(-12 * s, 0), Vector2(24 * s, 30 * s)), shirt)
	if look.get("female", false):
		# a woman: two soft curves on the chest, just enough to read at a glance
		for side in [-1.0, 1.0]:
			ci.draw_arc(neck + Vector2(side * 5.5 * s, 9 * s), 4.2 * s, PI * 0.15, PI * 0.85, 8, shirt.darkened(0.4), maxf(1.0, 1.3 * s))
	if gus:
		_blk(ci, Rect2(hip + Vector2(-9 * s, -20 * s), Vector2(18 * s, 20 * s)), outfit)
		_ln2(ci, hip + Vector2(-7 * s, -20 * s), neck + Vector2(-7 * s, 0), outfit, 2.5 * s)
		_ln2(ci, hip + Vector2(7 * s, -20 * s), neck + Vector2(7 * s, 0), outfit, 2.5 * s)
	if sitting:
		_sit_leg(ci, feet, s, dir, pants, 1)
	# arms: where the hands go for each pose
	var sh_f := neck + Vector2(10 * s * dir, 3 * s)
	var sh_b := neck + Vector2(-10 * s * dir, 3 * s)
	var hf := sh_f + Vector2(4 * s * dir, 24 * s)
	var hb := sh_b + Vector2(-2 * s * dir, 24 * s)
	var swing := sin(t * 7.0)
	match pose:
		"wrench", "hammer":
			hf = sh_f + Vector2((14 + 4 * swing) * s * dir, (-6 + 14 * maxf(0.0, swing)) * s)
			hb = sh_b + Vector2(12 * s * dir, 14 * s)
		"type", "sit_type":
			hf = sh_f + Vector2(18 * s * dir, 10 * s + absf(sin(t * 14.0)) * 2 * s)
			hb = sh_b + Vector2(24 * s * dir, 12 * s + absf(cos(t * 13.0)) * 2 * s)
		"spray":
			hf = sh_f + Vector2(22 * s * dir, -4 * s + sin(t * 3.0) * 6 * s)
		"dig":
			var d := absf(sin(t * 3.0))
			hf = sh_f + Vector2(14 * s * dir, (4 + 16 * d) * s)
			hb = sh_b + Vector2(20 * s * dir, (10 + 16 * d) * s)
		"point":
			hf = sh_f + Vector2(24 * s * dir, -10 * s + sin(t * 5.0) * 2 * s)
		"point_up":
			hf = sh_f + Vector2(18 * s * dir, -24 * s + sin(t * 5.0) * 2 * s)
		"clipboard", "hold":
			hf = sh_f + Vector2(12 * s * dir, 12 * s)
			hb = sh_b + Vector2(18 * s * dir, 13 * s)
		"cheer":
			hf = sh_f + Vector2(6 * s * dir, -22 * s + swing * 3 * s)
			hb = sh_b + Vector2(-6 * s * dir, -22 * s - swing * 3 * s)
		"pry":
			var heave := maxf(0.0, sin(t * 2.6))
			hf = sh_f + Vector2(18 * s * dir, (18 - 8 * heave) * s)
			hb = sh_b + Vector2(22 * s * dir, (20 - 8 * heave) * s)
		"drink", "push":
			# at the bar: elbows on the counter; every few seconds the mug comes up for a sip,
			# and "push" slides a stack of coins forward (a bet)
			var rest := sh_f + Vector2(16 * s * dir, 8 * s)
			var mouth := neck + Vector2(5 * s * dir, -6 * s)
			var ph := fmod(t, 4.5)
			var sip := 0.0
			if ph > 3.0:
				sip = sin((ph - 3.0) / 1.5 * PI)
			hf = rest.lerp(mouth, clampf(sip * 1.3, 0.0, 1.0)) if pose == "drink" else rest + Vector2(fmod(t, 1.0) * 14 * s * dir, 0)
			hb = sh_b + Vector2(20 * s * dir, 9 * s)
		"announce", "announce_up":
			# the announcer: one hand points at the corner he's calling (or punches the air),
			# the other holds the mic / megaphone up to his mouth
			if pose == "announce":
				hf = sh_f + Vector2(24 * s * dir, -10 * s + sin(t * 5.0) * 2 * s)
			else:
				hf = sh_f + Vector2(6 * s * dir, -24 * s + absf(sin(t * 4.0)) * 3 * s)
			hb = neck + Vector2(9 * s * dir, -3 * s)
		"carry_up":
			# both hands up, holding something over his head (the announcer's crate)
			hf = sh_f + Vector2(5 * s * dir, -24 * s)
			hb = sh_b + Vector2(-3 * s * dir, -24 * s)
		"walk_mic":
			# walking off with the mic (or megaphone) in one hand, the other arm swinging
			hf = sh_f + Vector2((6 + swing * 3) * s * dir, 18 * s)
			hb = sh_b + Vector2((-2 - swing * 3) * s * dir, 22 * s)
		"wipe":
			# the bartender polishes a glass, round and round
			hf = sh_f + Vector2((12 + cos(t * 6.0) * 4) * s * dir, (10 + sin(t * 6.0) * 3) * s)
			hb = sh_b + Vector2(16 * s * dir, 10 * s)
		"grab":
			# (1.64) the front hand on something the scene draws (Gus's crane lever): grab_at
			hf = grab_at
		"lift":
			var up := sin(t * 1.5) * 2.0
			hf = sh_f + Vector2(8 * s * dir, (-14 + up) * s)
			hb = sh_b + Vector2(14 * s * dir, (-12 + up) * s)
	var arm_col := shirt.darkened(0.12)
	_limb2(ci, sh_b, hb, arm_col, 5 * s)
	_cr(ci, hb, 2.6 * s, Color(look.get("skin", "#c8946e")))
	# the front arm: Gus's is his Kane-built robot arm
	_limb2(ci, sh_f, hf, Color(0.62, 0.62, 0.68) if gus else arm_col, 5 * s)
	if gus:
		_cr(ci, sh_f, 3.5 * s, Color(0.45, 0.45, 0.5))
	_cr(ci, hf, 2.8 * s, Color(1.0, 0.6, 0.2) if gus else Color(look.get("skin", "#c8946e")))
	# tools
	match pose:
		"wrench":
			var a := -0.6 + swing * 0.5
			var tip := hf + Vector2(cos(a) * dir, sin(a)) * 13 * s
			_ln2(ci, hf, tip, tool_color, 3 * s)
			_cr(ci, tip, 3 * s, tool_color)
		"hammer":
			var top := hf + Vector2(0, -12 * s)
			_ln2(ci, hf, top, Color(0.5, 0.35, 0.2), 2.5 * s)
			_rc(ci, Rect2(top + Vector2(-6 * s, -3 * s), Vector2(12 * s, 6 * s)), Color(0.45, 0.45, 0.5))
		"spray":
			_rc(ci, Rect2(hf + Vector2(-3 * s, -8 * s), Vector2(6 * s, 12 * s)), tool_color)
			_rc(ci, Rect2(hf + Vector2(-2 * s, -10 * s), Vector2(4 * s, 2 * s)), Color(0.9, 0.9, 0.9))
			for k in 6:
				var m := hf + Vector2((12 + k * 6) * s * dir, -9 * s + sin(t * 9.0 + k) * 4 * s)
				_cr(ci, m, (2 + k * 0.8) * s, Color(tool_color.r, tool_color.g, tool_color.b, 0.35 - k * 0.05))
		"dig":
			var blade := hf + Vector2(10 * s * dir, 22 * s)
			_ln2(ci, hb, blade, Color(0.5, 0.35, 0.2), 2.5 * s)
			_pg(ci, PackedVector2Array([blade + Vector2(-5 * s, 0), blade + Vector2(5 * s, 0), blade + Vector2(0, 9 * s)]), Color(0.55, 0.55, 0.6))
		"clipboard":
			_rc(ci, Rect2((hf + hb) * 0.5 + Vector2(-7 * s, -10 * s), Vector2(14 * s, 18 * s)), Color(0.6, 0.45, 0.3))
			_rc(ci, Rect2((hf + hb) * 0.5 + Vector2(-5 * s, -7 * s), Vector2(10 * s, 13 * s)), Color(0.95, 0.95, 0.9))
		"pry":
			# a crowbar under a crate lid
			var tip := (hf + hb) * 0.5 + Vector2(16 * s * dir, 10 * s)
			_ln2(ci, (hf + hb) * 0.5 + Vector2(-4 * s * dir, -6 * s), tip, Color(0.75, 0.2, 0.15), 2.5 * s)
		"lift":
			# holding up a part to look at it
			var mid := (hf + hb) * 0.5 + Vector2(0, -5 * s)
			_rc(ci, Rect2(mid + Vector2(-8 * s, -6 * s), Vector2(16 * s, 10 * s)), tool_color)
			_cr(ci, mid + Vector2(4 * s, -1 * s), 2.0 * s, Color(1.0, 0.5, 0.2))
		"hold":
			draw_controller(ci, (hf + hb) * 0.5, s * 0.8, str(look.get("controller", "gamepad")), int(t * 3.0) % 2 == 0, t)
	# head
	var hc := neck + Vector2(dir * 1 * s, -11 * s)
	var talk := 2.0 * s * (1.0 + absf(sin(t * 3.1))) if pose in ["point", "point_up", "cheer"] else 1.4 * s
	draw_head(ci, hc, 10 * s, look, dir, talk if not pose.begins_with("announce") else 2.0 * s * (1.0 + absf(sin(t * 9.0))))
	match pose:
		"walk_mic":
			var prop := str(look.get("prop", "mic"))
			if prop == "megaphone":
				_pg(ci, PackedVector2Array([hf + Vector2(0, -2 * s), hf + Vector2(10 * s * dir, -6 * s), hf + Vector2(10 * s * dir, 6 * s), hf + Vector2(0, 2 * s)]), Color(0.85, 0.7, 0.2))
			else:
				_ln2(ci, hf, hf + Vector2(2 * s * dir, -9 * s), Color(0.75, 0.6, 0.2) if prop == "gold_mic" else Color(0.15, 0.15, 0.15), 2.2 * s)
				_cr(ci, hf + Vector2(2 * s * dir, -10 * s), 2.6 * s, Color(0.95, 0.8, 0.3) if prop == "gold_mic" else Color(0.55, 0.55, 0.6))
			_cr(ci, hf, 2.6 * s, Color(look.get("skin", "#c8946e")))
		"announce", "announce_up":
			# drawn after the head so it sits in front of his face; the hand is wrapped round it
			var prop := str(look.get("prop", "mic"))
			var mouth := hc + Vector2(7 * s * dir, 4 * s)
			if prop == "megaphone":
				var m := mouth + Vector2(2 * s * dir, 0)
				_pg(ci, PackedVector2Array([m + Vector2(0, -2 * s), m + Vector2(13 * s * dir, -7 * s), m + Vector2(13 * s * dir, 7 * s), m + Vector2(0, 2 * s)]), Color(0.85, 0.7, 0.2))
				_ln2(ci, m + Vector2(7 * s * dir, -3 * s), m + Vector2(8 * s * dir, 1 * s), Color(0.55, 0.42, 0.1), 1.5)   # the dent
				_ln2(ci, m + Vector2(3 * s * dir, 2 * s), hb + Vector2(0, 1 * s), Color(0.3, 0.3, 0.32), 2.5 * s)   # handle into the hand
			else:
				var gold := prop == "gold_mic"
				_ln2(ci, hb + Vector2(0, 3 * s), mouth + Vector2(0, 2 * s), Color(0.75, 0.6, 0.2) if gold else Color(0.15, 0.15, 0.15), 2.2 * s)
				_cr(ci, mouth, 2.8 * s, Color(0.95, 0.8, 0.3) if gold else Color(0.55, 0.55, 0.6))
			_cr(ci, hb, 2.6 * s, Color(look.get("skin", "#c8946e")))   # fingers round the handle
		"drink":
			# the beer mug (over the face when it's up for a sip)
			var m := hf + Vector2(1 * s * dir, -4 * s)
			_rc(ci, Rect2(m + Vector2(-4 * s, -5 * s), Vector2(8 * s, 10 * s)), Color(0.95, 0.68, 0.18, 0.95))
			_rc(ci, Rect2(m + Vector2(-4 * s, -7 * s), Vector2(8 * s, 3 * s)), Color(1, 1, 0.95))
			_ac(ci, m + Vector2(-5 * s * dir, 0), 3 * s, PI * 0.5, PI * 1.5, 6, Color(0.85, 0.85, 0.9), 1.5 * s)
		"push":
			for k in 3:
				_cr(ci, hf + Vector2(5 * s * dir, -2 * s - k * 2 * s), 3 * s, Color(0.95, 0.78, 0.25))
		"wipe":
			_rc(ci, Rect2(hf + Vector2(-3 * s, -8 * s), Vector2(6 * s, 9 * s)), Color(0.75, 0.9, 1.0, 0.6))
			_rc(ci, Rect2(hf + Vector2(-4 * s, -1 * s), Vector2(8 * s, 4 * s)), Color(0.95, 0.95, 0.92))


# ---------------------------------------------------------------- Diagnostic Noir: lit people (1.60)
# People follow the same rules as the robots: one dark outline, a shadow side away from the place's
# key light, a light edge where it hits, the rim on the far side. Small see-through things (mist,
# lenses, shines) and the face's eyes and mouth stay as they are.

static func lit() -> bool:
	return light != "" and not RA.classic


## Points the robot painting tools at this scene's light (they hold the light state).
static func _begin() -> void:
	if lit():
		RA._set_light(light, 1.0)
		RA._grade = 3
		RA._flash = false


static func _solid(c: Color) -> bool:
	return lit() and c.a > 0.99


## A body block (legs, torso, overalls): a lit plate.
static func _blk(ci: CanvasItem, r: Rect2, c: Color) -> void:
	if not _solid(c) or r.size.x < 2.0 or r.size.y < 2.0:
		ci.draw_rect(r, c)
		return
	RA._plate(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), c)


static func _rc(ci: CanvasItem, r: Rect2, c: Color, filled: bool = true, w: float = -1.0) -> void:
	if not filled:
		ci.draw_rect(r, c, false, w)
	elif _solid(c) and minf(r.size.x, r.size.y) >= 2.5:
		RA._box(ci, r, c)
	else:
		ci.draw_rect(r, c)


static func _cr(ci: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	if _solid(c) and r >= 1.5:
		RA._disc(ci, p, r, c)
	else:
		ci.draw_circle(p, r, c)


static func _ln2(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float = -1.0) -> void:
	if _solid(c) and w >= 2.0:
		RA._ln(ci, a, b, c, w)
	else:
		ci.draw_line(a, b, c, w)


static func _pg(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	if _solid(c):
		RA._poly(ci, pts, c)
	else:
		ci.draw_colored_polygon(pts, c)


static func _ac(ci: CanvasItem, at: Vector2, r: float, a0: float, a1: float, n: int, c: Color, w: float = -1.0) -> void:
	if _solid(c) and w >= 1.5:
		RA._arc(ci, at, r, a0, a1, n, c, w)
	else:
		ci.draw_arc(at, r, a0, a1, n, c, w)


static func _limb2(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	if _solid(c):
		RA._limb(ci, a, b, c, w)
	else:
		ci.draw_line(a, b, c, w)


## The head: a round, lit like a robot's orb (shadow crescent away from the light, an arc of light).
static func _head_disc(ci: CanvasItem, c: Vector2, r: float, skin: Color) -> void:
	if lit():
		RA._round(ci, c, r, skin)
	else:
		ci.draw_circle(c, r, skin)


## One leg of a sitting person (k 0 = the far leg, a touch back and darker; 1 = the near leg over
## the lap): the thigh along the seat, the knee bent, the shin down to the floor, the foot flat.
static func _sit_leg(ci: CanvasItem, feet: Vector2, s: float, dir: float, pants: Color, k: int) -> void:
	var hy := feet.y - 26 * s
	var back := (-5.0 if k == 0 else 0.0) * s
	var pc := pants.darkened(0.2) if k == 0 else pants
	var hx := feet.x + (-2 * s + back) * dir
	var kx := feet.x + (24 * s + back) * dir
	var top := hy - 8 * s + k * 1.5 * s
	_blk(ci, Rect2(Vector2(minf(hx, kx), top), Vector2(absf(kx - hx), 8 * s)), pc)
	var sx := minf(kx, kx - 8 * s * dir)
	_blk(ci, Rect2(Vector2(sx, top + 3 * s), Vector2(8 * s, feet.y - 3 * s - top - 3 * s)), pc)
	var shoe_x := minf(kx - 8 * s * dir, kx + 4 * s * dir)
	_rc(ci, Rect2(Vector2(shoe_x, feet.y - 3 * s), Vector2(12 * s, 3 * s)), Color(0.13, 0.1, 0.08).darkened(0.25 if k == 0 else 0.0))
