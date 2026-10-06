extends RefCounted
## The garage's look ("Mix B · Clean Diagnostic"): fonts, the theme, and the little custom pieces -
## rail icons, the 10-HP block bar, the hazard-stripe frame around the Fight button.
##
##   Chakra Petch      - buttons, headings
##   Public Sans       - body text
##   VT323             - glowing numbers: money, date, health, prices
##   Saira Stencil One - the FIGHT button
## All four are free (SIL Open Font License, see fonts/OFL-*.txt).

const UI = preload("res://ui.gd")

const BG := Color(0.063, 0.063, 0.082)         # #101015
const PANEL := Color(0.04, 0.04, 0.063, 0.6)   # see-through dark panels over the scene
const ROW := Color(0.137, 0.137, 0.173)         # #23232c
const BTN := Color(0.188, 0.188, 0.235)         # #30303c
const BTN_EDGE := Color(0.29, 0.29, 0.37)       # #4a4a5e
const TEXT := Color(0.91, 0.91, 0.93)
const MUTED := Color(0.6, 0.6, 0.67)
const YELLOW := Color(0.95, 0.76, 0.19)         # #f2c230
const GREEN := Color(0.553, 1.0, 0.651)         # #8dffa6 - phosphor green
const AMBER := Color(1.0, 0.765, 0.353)         # #ffc35a
const RED := Color(1.0, 0.478, 0.353)           # #ff7a5a
const CYAN := Color(0.43, 0.88, 1.0)
const HP_UNIT := 10.0                           # one block in a health bar = 10 HP, always

static var _fonts := {}


static func _file(path: String) -> Font:
	var f = load(path)
	if f is FontFile:
		(f as FontFile).fallbacks = [ThemeDB.fallback_font]   # ★ ▾ → and other symbols come from the default font
	return f


static func _font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match key:
		"body", "bold":
			var v := FontVariation.new()
			v.base_font = _file("res://fonts/PublicSans-Variable.ttf")
			var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
			v.variation_opentype = {tag: 700 if key == "bold" else 500}
			f = v
		"head":
			f = _file("res://fonts/ChakraPetch-SemiBold.ttf")
		"headb":
			f = _file("res://fonts/ChakraPetch-Bold.ttf")
		"num":
			f = _file("res://fonts/VT323-Regular.ttf")
		"stencil":
			f = _file("res://fonts/SairaStencilOne-Regular.ttf")
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[key] = f
	return f


static func body() -> Font: return _font("body")
static func bold() -> Font: return _font("bold")
static func head() -> Font: return _font("head")
static func headb() -> Font: return _font("headb")
static func num() -> Font: return _font("num")
static func stencil() -> Font: return _font("stencil")


static func box(color: Color, radius: float = 10.0, margin: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(margin)
	return s


## The garage theme: dark rounded buttons with a yellow edge when pressed, rows as dark cards.
static func theme() -> Theme:
	var t := UI.make_theme()
	t.default_font = body()
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", head())
	t.set_font("font", "OptionButton", head())
	var normal := box(BTN, 10, 6)
	normal.border_color = BTN_EDGE
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate()
	hover.bg_color = BTN.lightened(0.06)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.15, 0.15, 0.185)
	pressed.border_color = YELLOW
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.133, 0.133, 0.165)
	disabled.border_color = Color(0.19, 0.19, 0.235)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, Color(0.94, 0.94, 0.96))
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color(1.0, 0.88, 0.54))
		t.set_color("font_hover_pressed_color", cls, Color(1.0, 0.88, 0.54))
		t.set_color("font_disabled_color", cls, Color(0.42, 0.42, 0.5))
	t.set_stylebox("panel", "PanelContainer", box(ROW, 10, 4))
	var pm := box(Color(0.1, 0.1, 0.13), 10, 8)
	pm.border_color = BTN_EDGE
	pm.set_border_width_all(1)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_font("font", "PopupMenu", body())
	return t


## A label in one of the garage fonts.
static func text(s: String, size: int, color: Color = TEXT, font_key: String = "body") -> Label:
	var l := UI.label(s, size, color)
	l.add_theme_font_override("font", _font(font_key))
	return l


## A glowing number (money, health, prices): VT323, green or amber.
static func readout(s: String, size: int, color: Color = GREEN) -> Label:
	var l := text(s, size, color, "num")
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.35))
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


## Toggle-bar button: flat, with a yellow line under the one that's on.
static func seg_style(on: bool) -> Array:
	var n := box(Color(0, 0, 0, 0) if not on else Color(0.2, 0.2, 0.247), 8, 4)
	if on:
		n.border_color = YELLOW
		n.border_width_bottom = 3
	var h := n.duplicate()
	h.bg_color = Color(0.2, 0.2, 0.247) if not on else Color(0.22, 0.22, 0.27)
	return [n, h]


## Health as joined blocks: every block is 10 HP, so a tough part has a longer bar and the dark blocks
## are the damage.
class SegBar extends Control:
	const BLOCK := 7.0
	var hp := 0.0
	var max_hp := 10.0
	var color := Color(0.553, 1.0, 0.651)

	func setup(value: float, maximum: float, col: Color) -> void:
		hp = value
		max_hp = maxf(1.0, maximum)
		color = col
		custom_minimum_size = Vector2(ceilf(max_hp / 10.0) * BLOCK, 12)
		queue_redraw()

	func _draw() -> void:
		var n := int(ceilf(max_hp / 10.0))
		var filled := hp / 10.0
		var y := (size.y - 12.0) * 0.5
		for i in n:
			var x := i * BLOCK
			draw_rect(Rect2(x, y, BLOCK - 1.0, 12), Color(0.15, 0.17, 0.155))
			var part := clampf(filled - i, 0.0, 1.0)
			if part > 0.0:
				draw_rect(Rect2(x, y, (BLOCK - 1.0) * part, 12), color)


## Yellow-and-black hazard stripes behind a child (the FIGHT button sits in one).
class HazardFrame extends MarginContainer:
	func _init() -> void:
		clip_contents = true
		for side in ["left", "right", "top", "bottom"]:
			add_theme_constant_override("margin_" + side, 4)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.08, 0.08))
		var step := 20.0
		var x := -size.y
		while x < size.x:
			var pts := PackedVector2Array([Vector2(x, size.y), Vector2(x + 10, size.y), Vector2(x + 10 + size.y, 0), Vector2(x + size.y, 0)])
			draw_colored_polygon(pts, Color(0.95, 0.76, 0.19))
			x += step


## A thin hazard stripe (under window titles).
class HazardStrip extends Control:
	func _init() -> void:
		clip_contents = true
		custom_minimum_size = Vector2(0, 4)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.08))
		var x := -size.y
		while x < size.x:
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + 8, size.y), Vector2(x + 8 + size.y, 0), Vector2(x + size.y, 0)]), Color(0.95, 0.76, 0.19))
			x += 16.0


## One button on the side rail: an outline icon over its name, yellow when it's the open section.
class RailButton extends Button:
	var kind := "bay"
	var label := ""
	var on := false
	var star := false
	var font: Font = ThemeDB.fallback_font

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(80, 76)

	func _draw() -> void:
		var col := Color(0.6, 0.6, 0.67)
		if on:
			draw_style_box(_box(), Rect2(Vector2.ZERO, size))
			draw_rect(Rect2(0, 8, 4, size.y - 16), Color(0.95, 0.76, 0.19))
			col = Color(0.95, 0.76, 0.19)
		var c := Vector2(size.x * 0.5, 28)
		_icon(c, col)
		var f: Font = font
		var fs := 13
		var txt := tr(label) + (" ★" if star else "")
		while fs > 9 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 6:
			fs -= 1
		draw_string(f, Vector2(0, size.y - 12), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)

	func _box() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.165, 0.165, 0.2)
		s.set_corner_radius_all(12)
		return s

	func _icon(c: Vector2, col: Color) -> void:
		var w := 2.0
		match kind:
			"bay":   # a house: the bay
				draw_polyline(PackedVector2Array([c + Vector2(-11, -1), c + Vector2(0, -10), c + Vector2(11, -1), c + Vector2(11, 11), c + Vector2(-11, 11), c + Vector2(-11, -1)]), col, w)
				draw_polyline(PackedVector2Array([c + Vector2(-4, 11), c + Vector2(-4, 4), c + Vector2(4, 4), c + Vector2(4, 11)]), col, w)
			"storage":   # a crate
				draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 17)), col, false, w)
				draw_line(c + Vector2(-11, -1), c + Vector2(11, -1), col, w)
				draw_polyline(PackedVector2Array([c + Vector2(-4, -6), c + Vector2(-4, -10), c + Vector2(4, -10), c + Vector2(4, -6)]), col, w)
			"parts":   # a wrench
				draw_line(c + Vector2(-9, 9), c + Vector2(4, -4), col, w + 1.5)
				draw_arc(c + Vector2(6, -6), 5.5, deg_to_rad(-200), deg_to_rad(70), 12, col, w)
			"season":   # a calendar
				draw_rect(Rect2(c + Vector2(-11, -8), Vector2(22, 19)), col, false, w)
				draw_line(c + Vector2(-11, -2), c + Vector2(11, -2), col, w)
				draw_line(c + Vector2(-5, -11), c + Vector2(-5, -6), col, w)
				draw_line(c + Vector2(5, -11), c + Vector2(5, -6), col, w)
			"crew":   # two people
				draw_arc(c + Vector2(-4, -5), 4.0, 0, TAU, 14, col, w)
				draw_arc(c + Vector2(7, -3), 3.0, 0, TAU, 12, col, w)
				draw_arc(c + Vector2(-4, 11), 8.0, PI, TAU, 12, col, w)
				draw_arc(c + Vector2(8, 11), 6.0, PI * 1.2, TAU, 10, col, w)
			"menu":
				for k in 3:
					draw_line(c + Vector2(-10, -7 + k * 7), c + Vector2(10, -7 + k * 7), col, w)


## Gus talking: a paper speech bubble over the scene. Tap it to make it go away.
class GusBubble extends PanelContainer:
	var label: Label

	func _init() -> void:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.957, 0.945, 0.902)
		s.set_corner_radius_all(14)
		s.set_content_margin_all(10)
		s.content_margin_left = 14
		s.content_margin_right = 14
		add_theme_stylebox_override("panel", s)
		label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(0.125, 0.125, 0.153))
		label.add_theme_font_size_override("font_size", 17)
		label.custom_minimum_size = Vector2(300, 0)
		add_child(label)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(func(e):
			if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
				visible = false)

	func say(t: String) -> void:
		label.text = t
		visible = t.strip_edges() != ""
		reset_size()

	func _draw() -> void:
		# the tail, pointing down at the scene
		var x := 34.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y - 1), Vector2(x + 16, size.y - 1), Vector2(x + 4, size.y + 12)]), Color(0.957, 0.945, 0.902))
