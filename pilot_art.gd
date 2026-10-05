extends RefCounted
## Draws pilots: the little doll in the fight corner, the story portraits and the garage preview.
##
## look: {"skin", "hair" (hair/hat color), "eyes" (eye color), "outfit", "hat", "beard", "glasses",
##        "controller", "long_hair" (bool), "scar" (bool)}

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
static func draw_head(ci: CanvasItem, c: Vector2, r: float, raw: Dictionary, dir: float, mouth: float) -> void:
	var look := normalize(raw)
	var skin := Color(look.get("skin", "#c8946e"))
	var hair := Color(look.get("hair", "#2a1d14"))
	var eyes := Color(look.get("eyes", EYES[0]))
	var ex := dir * r * 0.15   # eyes shift toward where they look
	if look.get("long_hair", false):
		ci.draw_rect(Rect2(c + Vector2(-r * 1.05, -r * 0.5), Vector2(r * 2.1, r * 1.5)), hair)
	ci.draw_circle(c, r, skin)
	# headwear
	match str(look.get("hat", "")):
		"beanie":
			ci.draw_rect(Rect2(c + Vector2(-r, -r * 1.05), Vector2(r * 2.0, r * 0.6)), hair)
			ci.draw_circle(c + Vector2(0, -r * 1.1), r * 0.18, hair.lightened(0.3))
		"cap":
			ci.draw_rect(Rect2(c + Vector2(-r * 1.05, -r * 1.05), Vector2(r * 2.1, r * 0.5)), hair)
			var bx := -r * 0.2 if dir >= 0.0 else -r * 1.2
			ci.draw_rect(Rect2(c + Vector2(bx, -r * 0.65), Vector2(r * 1.4, r * 0.16)), hair.darkened(0.2))
		"helmet":
			ci.draw_arc(c, r * 1.05, PI, TAU, 16, hair, r * 0.35)
			ci.draw_line(c + Vector2(-r * 0.2, -r * 1.2), c + Vector2(r * 0.2, -r * 1.2), hair.lightened(0.4), r * 0.12)
		"mohawk":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 1.6), Vector2(r * 0.36, r * 0.8)), hair)
		"bun":
			ci.draw_circle(c + Vector2(0, -r * 1.05), r * 0.35, hair)
			ci.draw_rect(Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.35)), hair)
		"bald":
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.6), r * 0.15, Color(1, 1, 1, 0.25))
		"cowboy":
			ci.draw_rect(Rect2(c + Vector2(-r * 1.6, -r * 0.75), Vector2(r * 3.2, r * 0.2)), hair)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 1.45), Vector2(r * 1.5, r * 0.75)), hair)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.95), Vector2(r * 1.5, r * 0.12)), hair.lightened(0.35))
		"headband":
			ci.draw_rect(Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.35)), Color(0.15, 0.1, 0.08))
			ci.draw_rect(Rect2(c + Vector2(-r * 1.02, -r * 0.62), Vector2(r * 2.04, r * 0.22)), hair)
			ci.draw_line(c + Vector2(-dir * r, -r * 0.5), c + Vector2(-dir * r * 1.5, -r * 0.1), hair, r * 0.15)
		"tophat":
			ci.draw_rect(Rect2(c + Vector2(-r * 1.15, -r * 0.8), Vector2(r * 2.3, r * 0.18)), hair)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 1.85), Vector2(r * 1.4, r * 1.1)), hair)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.98), Vector2(r * 1.4, r * 0.15)), Color(0.75, 0.2, 0.2))
		_:
			ci.draw_rect(Rect2(c + Vector2(-r, -r), Vector2(r * 2.0, r * 0.4)), hair)
	# eyes
	var el := c + Vector2(ex - r * 0.33, -r * 0.08)
	var er := c + Vector2(ex + r * 0.33, -r * 0.08)
	for e in [el, er]:
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
				ci.draw_circle(c + Vector2(-r * 0.5 + (k % 5) * r * 0.25, r * 0.55 + (k / 5) * r * 0.18), r * 0.04, bc.darkened(0.2))
		"full":
			ci.draw_circle(c + Vector2(0, r * 0.55), r * 0.5, bc)
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
		"goatee":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15 + ex, r * 0.55), Vector2(r * 0.3, r * 0.4)), bc)
		"mustache":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.32 + ex, r * 0.24), Vector2(r * 0.64, r * 0.13)), bc)
		"handlebar":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.32 + ex, r * 0.24), Vector2(r * 0.64, r * 0.12)), bc)
			ci.draw_line(c + Vector2(-r * 0.32 + ex, r * 0.3), c + Vector2(-r * 0.55 + ex, r * 0.08), bc, w * 1.5)
			ci.draw_line(c + Vector2(r * 0.32 + ex, r * 0.3), c + Vector2(r * 0.55 + ex, r * 0.08), bc, w * 1.5)
		"chinstrap":
			ci.draw_arc(c, r * 0.95, 0.25, PI - 0.25, 14, bc, r * 0.15)
		"muttonchops":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.98, -r * 0.1), Vector2(r * 0.3, r * 0.65)), bc)
			ci.draw_rect(Rect2(c + Vector2(r * 0.68, -r * 0.1), Vector2(r * 0.3, r * 0.65)), bc)
		"long":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.4), c + Vector2(r * 0.6, r * 0.4), c + Vector2(r * 0.15, r * 1.5), c + Vector2(-r * 0.15, r * 1.5)]), bc)
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
		"braided":
			ci.draw_circle(c + Vector2(0, r * 0.55), r * 0.4, bc)
			for k in 3:
				ci.draw_circle(c + Vector2(0, r * (0.95 + k * 0.2)), r * 0.12, bc.darkened(0.1 * k))
			ci.draw_rect(Rect2(mc, Vector2(r * 0.5, maxf(1.5, mouth))), Color(0.25, 0.08, 0.06))
	if look.get("scar", false):
		ci.draw_line(c + Vector2(r * 0.15, -r * 0.5), c + Vector2(r * 0.6, r * 0.2), Color(0.6, 0.25, 0.2), w * 1.3)


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
static func draw_person(ci: CanvasItem, feet: Vector2, s: float, raw: Dictionary, dir: float, pose: String, t: float, tool_color: Color = Color(0.7, 0.7, 0.75)) -> void:
	var look := normalize(raw)
	var gus: bool = look.get("gus", false)
	var outfit := Color(look.get("outfit", "#34495e"))
	var shirt := Color(0.55, 0.42, 0.3) if gus else outfit
	var pants := outfit.darkened(0.35) if not gus else outfit.darkened(0.15)
	var sitting := pose == "sit_type"
	var bob := sin(t * 2.0) * 0.8 * s
	# legs
	if sitting:
		ci.draw_rect(Rect2(feet + Vector2(-8 * s, -26 * s), Vector2(18 * s * dir if dir > 0 else 18 * s, 6 * s)), pants)
		ci.draw_rect(Rect2(feet + Vector2(4 * s * dir - 3 * s, -26 * s), Vector2(6 * s, 26 * s)), pants)
	else:
		ci.draw_rect(Rect2(feet + Vector2(-8 * s, -24 * s), Vector2(7 * s, 24 * s)), pants)
		ci.draw_rect(Rect2(feet + Vector2(1 * s, -24 * s), Vector2(7 * s, 24 * s)), pants)
	ci.draw_rect(Rect2(feet + Vector2(-9 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.13, 0.1, 0.08))
	ci.draw_rect(Rect2(feet + Vector2(1 * s, -3 * s), Vector2(9 * s, 3 * s)), Color(0.13, 0.1, 0.08))
	# body
	var hip := feet + Vector2(0, (-26 if sitting else -24) * s + bob)
	var neck := hip + Vector2(0, -30 * s)
	ci.draw_rect(Rect2(neck + Vector2(-12 * s, 0), Vector2(24 * s, 30 * s)), shirt)
	if gus:
		ci.draw_rect(Rect2(hip + Vector2(-9 * s, -20 * s), Vector2(18 * s, 20 * s)), outfit)
		ci.draw_line(hip + Vector2(-7 * s, -20 * s), neck + Vector2(-7 * s, 0), outfit, 2.5 * s)
		ci.draw_line(hip + Vector2(7 * s, -20 * s), neck + Vector2(7 * s, 0), outfit, 2.5 * s)
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
		"clipboard", "hold":
			hf = sh_f + Vector2(12 * s * dir, 12 * s)
			hb = sh_b + Vector2(18 * s * dir, 13 * s)
		"cheer":
			hf = sh_f + Vector2(6 * s * dir, -22 * s + swing * 3 * s)
			hb = sh_b + Vector2(-6 * s * dir, -22 * s - swing * 3 * s)
	var arm_col := shirt.darkened(0.12)
	ci.draw_line(sh_b, hb, arm_col, 5 * s)
	ci.draw_circle(hb, 2.6 * s, Color(look.get("skin", "#c8946e")))
	# the front arm: Gus's is his Kane-built robot arm
	ci.draw_line(sh_f, hf, Color(0.62, 0.62, 0.68) if gus else arm_col, 5 * s)
	if gus:
		ci.draw_circle(sh_f, 3.5 * s, Color(0.45, 0.45, 0.5))
	ci.draw_circle(hf, 2.8 * s, Color(1.0, 0.6, 0.2) if gus else Color(look.get("skin", "#c8946e")))
	# tools
	match pose:
		"wrench":
			var a := -0.6 + swing * 0.5
			var tip := hf + Vector2(cos(a) * dir, sin(a)) * 13 * s
			ci.draw_line(hf, tip, tool_color, 3 * s)
			ci.draw_circle(tip, 3 * s, tool_color)
		"hammer":
			var top := hf + Vector2(0, -12 * s)
			ci.draw_line(hf, top, Color(0.5, 0.35, 0.2), 2.5 * s)
			ci.draw_rect(Rect2(top + Vector2(-6 * s, -3 * s), Vector2(12 * s, 6 * s)), Color(0.45, 0.45, 0.5))
		"spray":
			ci.draw_rect(Rect2(hf + Vector2(-3 * s, -8 * s), Vector2(6 * s, 12 * s)), tool_color)
			ci.draw_rect(Rect2(hf + Vector2(-2 * s, -10 * s), Vector2(4 * s, 2 * s)), Color(0.9, 0.9, 0.9))
			for k in 6:
				var m := hf + Vector2((12 + k * 6) * s * dir, -9 * s + sin(t * 9.0 + k) * 4 * s)
				ci.draw_circle(m, (2 + k * 0.8) * s, Color(tool_color.r, tool_color.g, tool_color.b, 0.35 - k * 0.05))
		"dig":
			var blade := hf + Vector2(10 * s * dir, 22 * s)
			ci.draw_line(hb, blade, Color(0.5, 0.35, 0.2), 2.5 * s)
			ci.draw_colored_polygon(PackedVector2Array([blade + Vector2(-5 * s, 0), blade + Vector2(5 * s, 0), blade + Vector2(0, 9 * s)]), Color(0.55, 0.55, 0.6))
		"clipboard":
			ci.draw_rect(Rect2((hf + hb) * 0.5 + Vector2(-7 * s, -10 * s), Vector2(14 * s, 18 * s)), Color(0.6, 0.45, 0.3))
			ci.draw_rect(Rect2((hf + hb) * 0.5 + Vector2(-5 * s, -7 * s), Vector2(10 * s, 13 * s)), Color(0.95, 0.95, 0.9))
		"hold":
			draw_controller(ci, (hf + hb) * 0.5, s * 0.8, str(look.get("controller", "gamepad")), int(t * 3.0) % 2 == 0, t)
	# head
	var hc := neck + Vector2(dir * 1 * s, -11 * s)
	var talk := 2.0 * s * (1.0 + absf(sin(t * 3.1))) if pose in ["point", "cheer"] else 1.4 * s
	draw_head(ci, hc, 10 * s, look, dir, talk)
