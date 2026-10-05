class_name RobotArt
extends RefCounted
## Draws a robot out of simple shapes. Used by the fight and the garage preview.
##
## look: {"head","torso","arms","legs","trim","eye": Color, "fist": float}
## p (pose, all optional): facing, state, extended, swing, crouch, blocking, flash, rot, scale


static func draw(ci: CanvasItem, base: Vector2, look: Dictionary, p: Dictionary = {}) -> void:
	var facing: int = p.get("facing", 1)
	var state: String = p.get("state", "idle")
	var extended: bool = p.get("extended", false)
	var swing: float = p.get("swing", 0.0)
	var crouch: bool = p.get("crouch", false)
	var blocking: bool = p.get("blocking", false)
	var flash: bool = p.get("flash", false)
	var rot: float = p.get("rot", 0.0)
	var sc: float = p.get("scale", 1.0)

	ci.draw_set_transform(base, rot, Vector2(facing * sc, (0.68 if crouch else 1.0) * sc))

	var head: Color = look["head"]
	var torso: Color = look["torso"]
	var arms: Color = look["arms"]
	var legs: Color = look["legs"]
	var trim: Color = look["trim"]
	var eye: Color = look["eye"]
	var fist: float = look.get("fist", 11.0)
	if flash:
		head = Color.WHITE
		torso = Color.WHITE
		arms = Color.WHITE
		legs = Color.WHITE
		trim = Color.WHITE

	# back arm
	if blocking:
		ci.draw_rect(Rect2(2, -152, 14, 48), arms.darkened(0.35))
	else:
		ci.draw_rect(Rect2(-14, -126, 14, 44), arms.darkened(0.35))

	# back leg
	ci.draw_rect(Rect2(-22 - swing, -60, 16, 60), legs.darkened(0.35))
	ci.draw_rect(Rect2(-26 - swing, -8, 26, 8), trim.darkened(0.3))

	# torso
	ci.draw_rect(Rect2(-28, -134, 56, 76), torso)
	ci.draw_rect(Rect2(-28, -70, 56, 10), trim)
	ci.draw_rect(Rect2(-32, -136, 64, 12), trim)
	ci.draw_circle(Vector2(6, -106), 9.0, eye.darkened(0.4))
	ci.draw_circle(Vector2(6, -106), 6.0, eye)

	# front leg
	if state == "kick" and extended:
		ci.draw_rect(Rect2(8, -88, 92, 18), legs)
		ci.draw_rect(Rect2(94, -98, 14, 32), trim)
	elif state == "sweep" and extended:
		ci.draw_rect(Rect2(8, -22, 100, 18), legs)
		ci.draw_rect(Rect2(102, -30, 14, 30), trim)
	else:
		ci.draw_rect(Rect2(6 + swing, -60, 16, 60), legs)
		ci.draw_rect(Rect2(4 + swing, -8, 26, 8), trim)

	# head
	ci.draw_rect(Rect2(-6, -144, 12, 10), torso.darkened(0.35))
	ci.draw_rect(Rect2(-18, -176, 38, 34), head)
	ci.draw_rect(Rect2(4, -164, 16, 7), eye)
	ci.draw_line(Vector2(-8, -176), Vector2(-12, -190), trim, 3.0)
	ci.draw_circle(Vector2(-12, -191), 3.0, eye)

	# front arm
	var arm := arms.lightened(0.1)
	if state == "punch" and extended:
		ci.draw_rect(Rect2(8, -128, 80, 16), arm)
		ci.draw_circle(Vector2(92, -120), fist + 2.0, trim)
	elif state == "uppercut" and extended:
		ci.draw_rect(Rect2(12, -200, 16, 76), arm)
		ci.draw_circle(Vector2(20, -204), fist + 2.0, trim)
	elif blocking:
		ci.draw_rect(Rect2(14, -160, 16, 56), arm)
		ci.draw_circle(Vector2(22, -162), fist, trim)
	elif state == "hit" or state == "ko":
		ci.draw_rect(Rect2(6, -124, 14, 48), arm)
		ci.draw_circle(Vector2(13, -74), fist - 1.0, trim)
	else:
		ci.draw_rect(Rect2(10, -128, 14, 30), arm)
		ci.draw_rect(Rect2(10, -110, 36, 14), arm)
		ci.draw_circle(Vector2(48, -103), fist, trim)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
