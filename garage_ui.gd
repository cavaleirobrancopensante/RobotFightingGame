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
const HP_UNIT := 25.0                           # one block in a health bar = 25 HP, always

static var _fonts := {}


static func _file(path: String) -> Font:
	var f = load(path) if ResourceLoader.exists(path) else null
	if f == null and FileAccess.file_exists(path):
		# not imported (a fresh copy of the project opened in an editor): read the .ttf itself
		var raw := FontFile.new()
		if raw.load_dynamic_font(path) == OK:
			f = raw
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


## Every bar in the game is drawn as blocks (health, power, damage, speed, progress...).
## r: where; n: how many blocks; filled: how many are full (fractions fill the last one part-way);
## from_right: fill from the right end (the enemy's bars in fights).
static func draw_blocks(ci: CanvasItem, r: Rect2, n: int, filled: float, col: Color,
		empty: Color = Color(0.15, 0.17, 0.155), from_right: bool = false) -> void:
	n = maxi(1, n)
	var gap := clampf(r.size.x / n * 0.14, 1.0, 3.0)
	var bw := (r.size.x - gap * (n - 1)) / n
	for i in n:
		var x := r.end.x - (i + 1) * bw - i * gap if from_right else r.position.x + i * (bw + gap)
		ci.draw_rect(Rect2(x, r.position.y, bw, r.size.y), empty)
		var part := clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			var fw := bw * part
			ci.draw_rect(Rect2(x + (bw - fw if from_right else 0.0), r.position.y, fw, r.size.y), col)


## Bars longer than WRAP blocks (high-grade parts have hundreds of HP) wrap onto more rows of
## thinner blocks: a block is still HP_UNIT, so a tougher part has a bigger bar.
const WRAP := 30


static func rows_height(n: int, one_row: float) -> float:
	if n <= WRAP:
		return one_row
	return ceilf(float(n) / WRAP) * 7.0 - 2.0


static func draw_wrapped(ci: CanvasItem, n: int, filled: float, bw: float, col: Color) -> void:
	for i in n:
		var x := (i % WRAP) * bw
		var y := (i / WRAP) * 7.0
		ci.draw_rect(Rect2(x, y, bw - 1.0, 5.0), Color(0.15, 0.17, 0.155))
		var part := clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			ci.draw_rect(Rect2(x, y, (bw - 1.0) * part, 5.0), col)


## A list row that never pushes the screen wider: child 0 is the icon, child 1 the text (it fills),
## everything after it (buttons, health bars) sits on the right while the text keeps at least
## TEXT_MIN of room; otherwise those drop to a line of their own under the text, right-aligned,
## wrapping again if they still don't fit (big text, narrow phones).
class WrapRow extends Container:
	const SEP := 10.0
	const TEXT_MIN := 0.42      # the share of the row the text keeps before the buttons drop down
	var _min_h := 0.0
	var _laid_w := -1.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_layout(true)
		elif what == NOTIFICATION_RESIZED and absf(size.x - _laid_w) > 0.5:
			update_minimum_size()

	func _kids() -> Array:
		return get_children().filter(func(c): return c is Control and c.visible and not c.is_set_as_top_level())

	func _get_minimum_size() -> Vector2:
		var h := _layout(false)
		var kids := _kids()
		var w := 0.0
		if kids.size() > 0:
			w = kids[0].get_combined_minimum_size().x + SEP + 40.0
		for c in kids.slice(2):
			w = maxf(w, c.get_combined_minimum_size().x)
		return Vector2(w, h)

	## Lays the children out for the current width (or only measures); returns the height needed.
	func _layout(place: bool) -> float:
		var kids := _kids()
		if kids.is_empty():
			return 0.0
		var W := size.x if size.x > 1.0 else 600.0
		var icon: Control = kids[0]
		var text: Control = kids[1] if kids.size() > 1 else null
		var trail: Array = kids.slice(2)
		var iw := icon.get_combined_minimum_size().x
		var tw := 0.0
		for c in trail:
			tw += c.get_combined_minimum_size().x + SEP
		var room := W - iw - SEP - tw
		var one_line := trail.is_empty() or room >= W * TEXT_MIN
		var text_w := maxf(room if one_line else W - iw - SEP, 10.0)
		var text_h := 0.0
		if text:
			if place:
				# a wrapping label measures its height at its width: size it first
				text.size.x = text_w
			text_h = text.get_combined_minimum_size().y
		var h1 := maxf(icon.get_combined_minimum_size().y, text_h)
		if one_line:
			for c in trail:
				h1 = maxf(h1, c.get_combined_minimum_size().y)
		var total := h1
		var lines: Array = []   # [[controls], width, height] for the dropped-down trailing items
		if not one_line:
			var cur: Array = []
			var cw := 0.0
			var ch := 0.0
			for c in trail:
				var m: Vector2 = c.get_combined_minimum_size()
				if not cur.is_empty() and cw + SEP + m.x > W:
					lines.append([cur, cw, ch])
					cur = []
					cw = 0.0
					ch = 0.0
				cw += (SEP if not cur.is_empty() else 0.0) + m.x
				ch = maxf(ch, m.y)
				cur.append(c)
			if not cur.is_empty():
				lines.append([cur, cw, ch])
			for ln in lines:
				total += 6.0 + float(ln[2])
		if place:
			_laid_w = W
			var im := icon.get_combined_minimum_size()
			fit_child_in_rect(icon, Rect2(0, (h1 - im.y) * 0.5, iw, im.y))
			if text:
				fit_child_in_rect(text, Rect2(iw + SEP, (h1 - text_h) * 0.5, text_w, text_h))
			if one_line:
				var x := W
				for i in range(trail.size() - 1, -1, -1):
					var c: Control = trail[i]
					var m: Vector2 = c.get_combined_minimum_size()
					x -= m.x
					var ch2: float = m.y if (c.size_flags_vertical & SIZE_FILL) == 0 or c is Button else h1
					fit_child_in_rect(c, Rect2(x, (h1 - ch2) * 0.5, m.x, ch2))
					x -= SEP
			else:
				var y := h1
				for ln in lines:
					y += 6.0
					var x := W - float(ln[1])
					for c in ln[0]:
						var m: Vector2 = c.get_combined_minimum_size()
						fit_child_in_rect(c, Rect2(x, y + (float(ln[2]) - m.y) * 0.5, m.x, m.y))
						x += m.x + SEP
					y += float(ln[2])
			if absf(total - _min_h) > 0.5:
				_min_h = total
				update_minimum_size.call_deferred()
		return total


## A block bar for a value: one block per `per_block` up to `max_value`.
class BlockBar extends Control:
	var n := 10
	var filled := 0.0
	var color := Color(0.553, 1.0, 0.651)
	var block_w := 7.0
	var height := 12.0

	func setup(value: float, per_block: float, max_value: float, col: Color) -> void:
		n = maxi(1, int(ceilf(max_value / per_block)))
		filled = value / per_block
		color = col
		custom_minimum_size = Vector2(mini(n, WRAP) * block_w, load("res://garage_ui.gd").rows_height(n, height))
		queue_redraw()

	func set_fill(f: float) -> void:
		if absf(f - filled) > 0.001:
			filled = f
			queue_redraw()

	func _draw() -> void:
		if n <= WRAP:
			var y := (size.y - height) * 0.5
			var GUI = load("res://garage_ui.gd")
			GUI.draw_blocks(self, Rect2(0, y, size.x, height), n, filled, color)
			return
		load("res://garage_ui.gd").draw_wrapped(self, n, filled, block_w, color)


## Health as joined blocks: every block is HP_UNIT (25 HP), so a tough part has a longer bar and the dark blocks
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
		var nb := int(ceilf(max_hp / HP_UNIT))
		custom_minimum_size = Vector2(mini(nb, WRAP) * BLOCK, load("res://garage_ui.gd").rows_height(nb, 12.0))
		queue_redraw()

	func _draw() -> void:
		var n := int(ceilf(max_hp / HP_UNIT))
		var filled := hp / HP_UNIT
		if n > WRAP:
			load("res://garage_ui.gd").draw_wrapped(self, n, filled, BLOCK, color)
			return
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


## "Here, something to do": the bay's marching hazard stripes running clockwise round anything new
## (a section, a toggle, a button, a pilot with something to say). Sits over its parent, takes no taps.
class MarchFrame extends Control:
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var lengths: Array = []
		var perimeter := 0.0
		for i in 4:
			var l: float = (corners[i] as Vector2).distance_to(corners[(i + 1) % 4])
			lengths.append(l)
			perimeter += l
		var pairs := maxi(4, int(round(perimeter / 16.0)))
		var stripe := perimeter / (pairs * 2.0)
		var offset := fmod(t * 34.0, stripe * 2.0)
		draw_polyline(PackedVector2Array(corners + [corners[0]]), Color(0.08, 0.08, 0.08), 3.0)
		for k in pairs:
			var a := fmod(offset + k * stripe * 2.0, perimeter)
			_seg(corners, lengths, a, a + stripe)

	func _seg(corners: Array, lengths: Array, from: float, to: float) -> void:
		var pos := 0.0
		for lap in 2:
			for i in 4:
				var l: float = lengths[i]
				var s0 := maxf(from, pos)
				var s1 := minf(to, pos + l)
				if s1 > s0:
					var a: Vector2 = corners[i]
					var dir: Vector2 = ((corners[(i + 1) % 4] as Vector2) - a) / maxf(l, 0.001)
					draw_line(a + dir * (s0 - pos), a + dir * (s1 - pos), Color(0.95, 0.76, 0.19), 3.0)
				pos += l


## Puts the marching stripes round a control (or takes them off).
static func mark_new(c: Control, on: bool) -> void:
	var old := c.get_node_or_null("March")
	if on and old == null:
		var m := MarchFrame.new()
		m.name = "March"
		c.add_child(m)
	elif not on and old != null:
		old.queue_free()


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
		var fs := UI.px(13)
		var txt := tr(label)
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
			"pub":   # a beer mug: The Rusty Bolt
				draw_rect(Rect2(c + Vector2(-9, -7), Vector2(14, 18)), col, false, w)
				draw_arc(c + Vector2(5, 2), 5.0, -PI * 0.5, PI * 0.5, 10, col, w)
				draw_line(c + Vector2(-9, -3), c + Vector2(5, -3), col, w)
				draw_arc(c + Vector2(-5, -9), 3.0, PI, TAU, 8, col, w)
				draw_arc(c + Vector2(1, -9), 3.0, PI, TAU, 8, col, w)
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
			"feed":   # a phone with a speech bubble: messages
				draw_rect(Rect2(c + Vector2(-8, -12), Vector2(16, 24)), col, false, w)
				draw_line(c + Vector2(-3, 9), c + Vector2(3, 9), col, w)
				draw_rect(Rect2(c + Vector2(-4, -6), Vector2(8, 6)), col, false, 1.5)
				draw_line(c + Vector2(-2, 0), c + Vector2(-4, 3), col, 1.5)
			"menu":
				for k in 3:
					draw_line(c + Vector2(-10, -7 + k * 7), c + Vector2(10, -7 + k * 7), col, w)


## Gus talking: a paper speech bubble over the scene. Tap it to make it go away.
## Everything people say in the garage: Gus and you in speech bubbles pointing at your heads,
## rivals, Kane and the announcer on a video call, the narrator in a caption strip.
## A ✓ closes it (or moves the story on to the next line), a bar shows how long it stays up.
class TalkBox extends PanelContainer:
	signal tapped
	signal checked
	var mode := "bubble"
	var name_label: Label
	var text_label: Label
	var face_slot: Control
	var ok: Button
	var bar: TalkBar
	var tail := Vector2.INF    # where the tail points, in local coordinates (bubbles only)
	var _style := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style.set_corner_radius_all(14)
		_style.set_content_margin_all(10)
		_style.content_margin_left = 14
		add_theme_stylebox_override("panel", _style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		face_slot = Control.new()
		face_slot.custom_minimum_size = Vector2(92, 92)
		face_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face_slot.clip_contents = true
		row.add_child(face_slot)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", UI.px(14))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(name_label)
		ok = CheckMark.new()
		ok.pressed.connect(func(): checked.emit())
		head.add_child(ok)
		text_label = Label.new()
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # full size from the start
		text_label.add_theme_font_size_override("font_size", UI.px(17))
		text_label.custom_minimum_size = Vector2(290, 0)
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(text_label)
		bar = TalkBar.new()
		col.add_child(bar)
		gui_input.connect(func(e):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				tapped.emit())

	## bubble (paper), call (a dark monitor with a coloured frame) or caption (a dark strip).
	func set_mode(m: String, accent: Color) -> void:
		mode = m
		tail = Vector2.INF
		face_slot.visible = m == "call"
		_style.set_border_width_all(0)
		match m:
			"bubble":
				_style.bg_color = Color(0.957, 0.945, 0.902)
				_style.set_corner_radius_all(14)
				text_label.add_theme_color_override("font_color", Color(0.125, 0.125, 0.153))
				name_label.add_theme_color_override("font_color", accent.darkened(0.45))
				bar.color = Color(0.3, 0.3, 0.33, 0.5)
			"call":
				_style.bg_color = Color(0.05, 0.06, 0.08, 0.96)
				_style.set_corner_radius_all(12)
				_style.border_color = accent
				_style.set_border_width_all(3)
				text_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.95))
				name_label.add_theme_color_override("font_color", accent)
				bar.color = accent
			_:
				_style.bg_color = Color(0, 0, 0, 0.8)
				_style.set_corner_radius_all(8)
				text_label.add_theme_color_override("font_color", accent)
				name_label.add_theme_color_override("font_color", accent)
				bar.color = Color(accent, 0.6)
		queue_redraw()

	func _draw() -> void:
		if mode != "bubble" or tail == Vector2.INF:
			return
		# the tail runs from the nearest edge of the bubble to the speaker's head
		var c := Color(0.957, 0.945, 0.902)
		var x := clampf(tail.x, 22.0, size.x - 22.0)
		var from_y := size.y - 2.0 if tail.y > size.y * 0.5 else 2.0
		if tail.x > size.x + 10.0 or tail.x < -10.0:
			var y := clampf(tail.y, 18.0, size.y - 18.0)
			var fx := size.x - 2.0 if tail.x > size.x else 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx, y - 9), Vector2(fx, y + 9), tail]), c)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 9, from_y), Vector2(x + 9, from_y), tail]), c)


## Gus's tour: a fat yellow arrow bouncing next to what you should tap, with a pulsing frame
## round it. It sits beside the target and points at it from wherever there's room.
class TourArrow extends Control:
	## Gus's tour: the thing to tap next gets the marching hazard stripes (the same "here, something
	## to do" as anything new), drawn a little outside it so the button itself stays readable.
	var target := Rect2()

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var r := target.grow(5.0)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var lengths: Array = []
		var perimeter := 0.0
		for i in 4:
			var l: float = (corners[i] as Vector2).distance_to(corners[(i + 1) % 4])
			lengths.append(l)
			perimeter += l
		var pairs := maxi(4, int(round(perimeter / 18.0)))
		var stripe := perimeter / (pairs * 2.0)
		var offset := fmod(t * 40.0, stripe * 2.0)
		draw_polyline(PackedVector2Array(corners + [corners[0]]), Color(0.08, 0.08, 0.08), 5.0)
		for k in pairs:
			var a := fmod(offset + k * stripe * 2.0, perimeter)
			var pos := 0.0
			for lap in 2:
				for i in 4:
					var l: float = lengths[i]
					var s0 := maxf(a, pos)
					var s1 := minf(a + stripe, pos + l)
					if s1 > s0:
						var c0: Vector2 = corners[i]
						var dir: Vector2 = ((corners[(i + 1) % 4] as Vector2) - c0) / maxf(l, 0.001)
						draw_line(c0 + dir * (s0 - pos), c0 + dir * (s1 - pos), Color(0.95, 0.76, 0.19), 5.0)
					pos += l


## The ✓ button (drawn, so it doesn't depend on the font having the glyph).
class CheckMark extends Button:
	var count := 0   # lines waiting behind this one

	func _init() -> void:
		custom_minimum_size = Vector2(56, 30)
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var c := size * 0.5 - Vector2(8 if count > 0 else 0, 0)
		draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 6), c + Vector2(9, -6)]), Color(0.553, 1.0, 0.651), 3.0, true)
		if count > 0:
			var r := Rect2(Vector2(size.x - 24, size.y * 0.5 - 10), Vector2(20, 20))
			draw_circle(r.get_center(), 10.0, Color(0.95, 0.76, 0.19))
			draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y - 5), str(mini(count, 99)), HORIZONTAL_ALIGNMENT_CENTER, 20, 12 if count < 10 else 10, Color(0.08, 0.08, 0.1))


## How long a line stays up: a thin bar that runs down.
class TalkBar extends Control:
	var ratio := 1.0
	var color := Color(0.3, 0.3, 0.33, 0.5)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ratio(r: float) -> void:
		if absf(r - ratio) > 0.002:
			ratio = r
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x * clampf(ratio, 0.0, 1.0), size.y), color)




# ---------------------------------------------------------------- calendar symbols

## One symbol per kind of fight night, so calendar days stay the same size:
## scrap = rusty gear, regional = blue shield, championship = gold crown, cup = purple trophy,
## pickup = a green coin, rent = red bill, stock = a crate.
const EVENT_COLORS := {"open": Color(0.6, 0.75, 0.7), "scrap": Color(0.62, 0.5, 0.36), "rust": Color(0.82, 0.42, 0.18),
		"iron": Color(0.55, 0.62, 0.72), "steel": Color(0.8, 0.88, 1.0), "title": YELLOW, "exhibition": YELLOW,
		"cup": Color(0.75, 0.5, 1.0), "pickup": Color(0.55, 0.78, 0.42), "rent": Color(1.0, 0.42, 0.35), "stock": Color(0.62, 0.5, 0.36)}

static func draw_event_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, ring: bool = false) -> void:
	var col: Color = EVENT_COLORS.get(kind, MUTED)
	var dark := Color(0.08, 0.08, 0.1)
	match kind:
		"open":
			# a torn entry ticket: the Open Trials, for pilots with no league at all
			var tk := Rect2(c - Vector2(r * 0.95, r * 0.55), Vector2(r * 1.9, r * 1.1))
			ci.draw_rect(tk, col)
			ci.draw_circle(Vector2(tk.position.x, c.y), r * 0.22, dark)
			ci.draw_circle(Vector2(tk.end.x, c.y), r * 0.22, dark)
			ci.draw_line(Vector2(c.x + r * 0.3, tk.position.y + 2), Vector2(c.x + r * 0.3, tk.end.y - 2), dark, 1.5)
		"rust":
			# a rusty hex nut
			var hexp := PackedVector2Array()
			for k in 6:
				var a := k * TAU / 6.0 + PI / 6.0
				hexp.append(c + Vector2(cos(a), sin(a)) * r * 0.9)
			ci.draw_colored_polygon(hexp, col)
			ci.draw_circle(c, r * 0.38, dark)
		"scrap":
			for k in 8:
				var a := k * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.55 + n * r * 0.18, c + d * r * 0.95 + n * r * 0.14,
						c + d * r * 0.95 - n * r * 0.14, c + d * r * 0.55 - n * r * 0.18]), col)
			ci.draw_circle(c, r * 0.68, col)
			ci.draw_circle(c, r * 0.28, dark)
		"iron":
			var pts := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.85), c + Vector2(r * 0.8, -r * 0.85), c + Vector2(r * 0.8, r * 0.05),
					c + Vector2(0, r * 0.95), c + Vector2(-r * 0.8, r * 0.05)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.3), Vector2(r * 1.6, r * 0.28)), Color(1, 1, 1, 0.85))
		"steel":
			# a steel star
			var star := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * PI / 5.0
				star.append(c + Vector2(cos(a), sin(a)) * r * (0.95 if k % 2 == 0 else 0.42))
			ci.draw_colored_polygon(star, col)
		"title", "exhibition":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, r * 0.45), c + Vector2(-r * 0.9, -r * 0.6), c + Vector2(-r * 0.45, -r * 0.05),
					c + Vector2(0, -r * 0.85), c + Vector2(r * 0.45, -r * 0.05), c + Vector2(r * 0.9, -r * 0.6), c + Vector2(r * 0.9, r * 0.45)]), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.9, r * 0.55), Vector2(r * 1.8, r * 0.3)), col)
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.16, Color(0.9, 0.2, 0.25))
		"cup":
			var bowl := PackedVector2Array()
			for k in 9:
				var a := PI * k / 8.0
				bowl.append(c + Vector2(-cos(a) * r * 0.62, -r * 0.75 + sin(a) * r * 0.9))
			ci.draw_colored_polygon(bowl, col)
			ci.draw_arc(c + Vector2(-r * 0.62, -r * 0.4), r * 0.28, PI * 0.5, PI * 1.5, 8, col, maxf(2.0, r * 0.14))
			ci.draw_arc(c + Vector2(r * 0.62, -r * 0.4), r * 0.28, -PI * 0.5, PI * 0.5, 8, col, maxf(2.0, r * 0.14))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.1), Vector2(r * 0.2, r * 0.45)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.55), Vector2(r * 0.9, r * 0.3)), col)
		"pickup":
			ci.draw_circle(c, r * 0.85, col)
			ci.draw_circle(c, r * 0.65, col.darkened(0.25))
			var f := headb()
			var fsz := int(r * 1.2)
			ci.draw_string(f, c + Vector2(-r, fsz * 0.36), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fsz, Color(0.95, 1, 0.9))
		"rent":
			ci.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.55), Vector2(r * 1.8, r * 1.1)), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.55), Vector2(r * 1.8, r * 1.1)), col.darkened(0.4), false, 1.5)
			var f2 := headb()
			var fs2 := int(r * 1.0)
			ci.draw_string(f2, c + Vector2(-r, fs2 * 0.36), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs2, Color(1, 0.95, 0.9))
		"stock":
			var b := Rect2(c - Vector2(r * 0.75, r * 0.7), Vector2(r * 1.5, r * 1.4))
			ci.draw_rect(b, col)
			ci.draw_rect(b, col.darkened(0.45), false, 1.5)
			ci.draw_line(b.position, b.end, col.darkened(0.45), 1.5)
			ci.draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), col.darkened(0.45), 1.5)
		_:
			ci.draw_circle(c, r * 0.6, col)
	if ring:
		ci.draw_arc(c, r * 1.12, 0, TAU, 20, YELLOW, 2.0)


## A small control that draws one event symbol (for legends and popups).
class EventIcon extends Control:
	var kind := "pickup"
	var ring := false
	func _init(k: String = "pickup", sz: float = 22.0, playoff: bool = false) -> void:
		kind = k
		ring = playoff
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var GUI = load("res://garage_ui.gd")
		GUI.draw_event_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.42, ring)


## Your post waiting after a fight, as a card: a draft per tone (humble, hype, trash talk; five when
## you watched), with what each does and everyone's (+52) / (-61) next to their names, then Say
## nothing. Used on BotMedia's Home and on the results screen of a fight (1.63).
## Fill avatar first if you want your face in the corner, connect posted / skipped, then build().
class DraftCard extends PanelContainer:
	signal posted(tone: String)
	signal skipped
	var avatar: Control = null
	var row_h := 58.0
	var wrap := false   # narrow places (the results screen): the lines wrap and the rows grow

	func build() -> void:
		var G = load("res://garage_ui.gd")   # (an inner class can't call the outer script's statics by name)
		for c in get_children():
			c.queue_free()
		var S = GameData.Social
		var drafts: Array = S.drafts()
		var sb: StyleBoxFlat = G.box(ROW.lightened(0.04), 10, 10)
		sb.border_color = YELLOW
		sb.set_border_width_all(2)
		add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		add_child(col)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		col.add_child(top)
		if avatar:
			top.add_child(avatar)
		var watched: bool = S.st()["draft"].get("watch", false)
		var t: Label = G.text(tr("POST ABOUT THE FIGHT YOU WATCHED? Pick one.") if watched else tr("POST ABOUT TONIGHT? Pick one."), 15, YELLOW, "headb")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		var hints := {"humble": tr("Safe. Sponsors like it. They warm up to you (+4).") if not watched else tr("Safe. Both of them warm up to you (+3)."),
				"hype": tr("Big if you keep winning.") if not watched else tr("The winner loves it (+6)."),
				"trash": tr("Fans love it. They won't (-10).") if not watched else tr("Fans love it. Both of them will remember (-10 each)."),
				"trash_w": tr("Fans love it. The winner won't (-10)."), "trash_l": tr("Fans love it. The loser won't (-10).")}
		var names := {"humble": tr("HUMBLE"), "hype": tr("HYPE"), "trash": tr("TRASH TALK") if not watched else tr("TRASH TALK: BOTH"),
				"trash_w": tr("TRASH TALK: WINNER"), "trash_l": tr("TRASH TALK: LOSER")}
		# what's between you and each pilot named in the drafts: (+52) green, (-61) red
		var wids: Array = S.draft_wids()
		var bb_args: Array = []
		var plain: Array = S.draft_args()
		for k in plain.size():
			var nm := str(plain[k])
			var wid: int = int(wids[k]) if k < wids.size() else -1
			if wid >= 0 and GameData.rel_bb(wid) != "":
				nm += " " + GameData.rel_bb(wid)
			bb_args.append(nm)
		var no_trash: bool = GameData.Contracts.st()["active"].any(func(c): return c["reqs"].any(func(r): return r["kind"] == "no_trash"))
		for d in drafts:
			var tone := str(d[0])
			# a tappable row: in the narrow card it's a panel that sizes to its wrapped text
			var row: Control
			var v := VBoxContainer.new()
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 0)
			if wrap:
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", G.box(BG, 8, 8))
				pc.mouse_filter = Control.MOUSE_FILTER_STOP
				pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				pc.gui_input.connect(func(e):
					if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
						posted.emit(tone))
				pc.add_child(v)
				row = pc
			else:
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.custom_minimum_size = Vector2(0, row_h)
				for k in ["normal", "hover", "pressed", "hover_pressed"]:
					b.add_theme_stylebox_override(k, G.box(BG if k == "normal" else BG.lightened(0.08), 8, 6))
				b.pressed.connect(func(): posted.emit(tone))
				v.set_anchors_preset(Control.PRESET_FULL_RECT)
				v.offset_left = 10
				v.offset_right = -10
				v.alignment = BoxContainer.ALIGNMENT_CENTER
				b.add_child(v)
				row = b
			col.add_child(row)
			var warn := tone.begins_with("trash") and no_trash
			var hl: Label = G.text(str(names[tone]) + "  ·  " + (tr("Breaks your Harbour Mutual deal!") if warn else str(hints[tone])), 11, RED if warn or tone.begins_with("trash") else MUTED, "headb")
			if wrap:
				hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				hl.clip_text = true
			v.add_child(hl)
			var dt := RichTextLabel.new()
			dt.bbcode_enabled = true
			dt.fit_content = true
			dt.scroll_active = false
			dt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
			dt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dt.clip_contents = true
			dt.add_theme_font_override("normal_font", G.body())
			dt.add_theme_font_override("bold_font", G.headb())
			dt.add_theme_font_size_override("normal_font_size", UI.tsz(13))
			dt.add_theme_font_size_override("bold_font_size", UI.tsz(13))
			dt.add_theme_color_override("default_color", TEXT)
			dt.text = tr(str(d[1])) % bb_args
			v.add_child(dt)
		var bar := HBoxContainer.new()
		col.add_child(bar)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(sp)
		bar.add_child(UI.button(tr("Say nothing"), func(): skipped.emit(), 12, Vector2(130, 32)))
