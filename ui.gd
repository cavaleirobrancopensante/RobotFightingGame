class_name UI
extends RefCounted
## Small helpers for building menus in code, sized for a phone screen.
## SCALE makes every font and button bigger at once (1.25 = 25% bigger).

const SCALE := 1.25


static func label(text: String, size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * SCALE))
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, size: int = 26, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", int(size * SCALE))
	b.custom_minimum_size = min_size * SCALE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05))
	b.pressed.connect(callback)
	return b


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


static func margin(parent: Control, px: int = 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	parent.add_child(m)
	return m


## Game-wide theme: bigger default text and fat, finger-friendly scroll bars.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = int(20 * SCALE)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.14, 0.18)
	track.set_corner_radius_all(8)
	track.content_margin_left = 12 * SCALE
	track.content_margin_right = 12 * SCALE
	track.content_margin_top = 12 * SCALE
	track.content_margin_bottom = 12 * SCALE
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.5, 0.5, 0.58)
	grab.set_corner_radius_all(8)
	grab.content_margin_left = 12 * SCALE
	grab.content_margin_right = 12 * SCALE
	grab.content_margin_top = 12 * SCALE
	grab.content_margin_bottom = 12 * SCALE
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = Color(0.7, 0.7, 0.8)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("scroll_focus", bar, track)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab_hi)
		t.set_stylebox("grabber_pressed", bar, grab_hi)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.16, 0.16, 0.2)
	pb_bg.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	return t
