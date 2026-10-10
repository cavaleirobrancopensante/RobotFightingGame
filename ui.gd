extends RefCounted
const PlayLog = preload("res://playlog.gd")   # (1.87) the playtest log
## Small helpers for building menus in code, sized for a phone screen.
## SCALE makes every font and button bigger at once (1.25 = 25% bigger).

const SCALE := 1.25

## Text size (Settings > Text size): small text grows the most, big titles hardly at all.
## Level 0 is the old size; the default (2) makes body text about 25% bigger.
const TEXT_LEVELS := [0.0, 0.12, 0.25, 0.4, 0.55]
const TEXT_NAMES := ["Classic", "Medium", "Large", "Larger", "Huge"]
const TEXT_DEFAULT := 2
static var text_boost := 0.25


static func set_text_level(lv: int) -> void:
	text_boost = TEXT_LEVELS[clampi(lv, 0, TEXT_LEVELS.size() - 1)]


## A design size (as written in the code) at the player's text size, before SCALE.
static func tk(size: float) -> float:
	var s := maxf(size, 10.0 + 10.0 * text_boost)   # nothing smaller than this stays on screen
	var big := clampf((size - 14.0) / 30.0, 0.0, 1.0)   # 14 and under: full boost; 44 and over: none
	return s * (1.0 + text_boost * (1.0 - big))


## Font size for labels and buttons (with SCALE).
static func tsz(size: float) -> int:
	return int(round(tk(size) * SCALE))


## Font size for text drawn straight onto a control (draw_string sizes were written without SCALE).
static func px(size: float) -> int:
	return int(round(tk(size)))


static func label(text: String, size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", tsz(size))
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, size: int = 26, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", tsz(size))
	b.custom_minimum_size = min_size * SCALE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05); PlayLog.add("tap", b.text))
	b.pressed.connect(callback)
	return b


## (1.113) A whole screen's column that always fits: centred while it fits, scrolls when it's taller
## than the screen (big text, long translations). Returns the CenterContainer to put the column in.
static func fit_screen(parent: Control, px: int = 24) -> CenterContainer:
	var m := margin(parent, px)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(sc)
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	return c


## (1.113) A button whose words wrap onto a second line instead of making it wider than its room.
static func wrap_button(b: Button) -> Button:
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	t.default_font_size = tsz(20)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.14, 0.18)
	track.set_corner_radius_all(8)
	track.content_margin_left = 14.4 * SCALE
	track.content_margin_right = 14.4 * SCALE
	track.content_margin_top = 12 * SCALE
	track.content_margin_bottom = 12 * SCALE
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.5, 0.5, 0.58)
	grab.set_corner_radius_all(8)
	grab.content_margin_left = 14.4 * SCALE
	grab.content_margin_right = 14.4 * SCALE
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


## Drag anywhere on a list to scroll it (not only on the scroll bar), like a phone list.
## A small drag still counts as a tap; once it's a real drag, the button under the finger lets go.
class DragScroll extends Node:
	const START := 14.0   # pixels before a press turns into a drag
	var sc: ScrollContainer
	var blocked := Callable()   # returns true while something covers the list (a popup)
	var down := false
	var dragging := false
	var start := Vector2.ZERO
	var last_y := 0.0

	func _input(ev: InputEvent) -> void:
		if not is_instance_valid(sc) or not sc.is_visible_in_tree():
			return
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				down = sc.get_global_rect().has_point(ev.position) and not (blocked.is_valid() and blocked.call())
				dragging = false
				start = ev.position
				last_y = ev.position.y
			else:
				down = false
				dragging = false
		elif ev is InputEventMouseMotion and down:
			if not dragging and absf(ev.position.y - start.y) > START:
				dragging = true
				sc.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)   # cancels the press on the button below
			if dragging:
				sc.scroll_vertical -= int(ev.position.y - last_y)
				sc.get_viewport().set_input_as_handled()
			last_y = ev.position.y


static func drag_scroll(sc: ScrollContainer, blocked: Callable = Callable()) -> void:
	var d := DragScroll.new()
	d.sc = sc
	d.blocked = blocked
	sc.add_child(d)

