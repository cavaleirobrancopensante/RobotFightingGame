extends RefCounted
## (1.91) Stat icons: every part stat has a small drawn glyph, shown with its number in part rows,
## part cards and the robot's stats panel. Tapping one says its name (a little note above it).
## Glyphs are drawn live (no images), in the stat's own colour.

const GUI = preload("res://garage_ui.gd")
const UI = preload("res://ui.gd")

## key -> [name (translated when shown), colour]
const STATS := {
	"hp": ["Health", Color(0.553, 1.0, 0.651)],
	"core": ["Core health", Color(0.553, 1.0, 0.651)],
	"gm": ["Hit power (grade)", Color(1.0, 0.83, 0.4)],
	"armor": ["Armor", Color(0.62, 0.78, 0.95)],
	"damage": ["Damage", Color(1.0, 0.5, 0.42)],
	"speed": ["Speed", Color(0.43, 0.88, 1.0)],
	"aim": ["Aim", Color(0.95, 0.76, 0.19)],
	"aim_in": ["Time to aim", Color(0.95, 0.76, 0.19)],
	"scan": ["Time to scan for a weak spot", Color(0.55, 1.0, 0.75)],
	"chips": ["Chip slots", Color(0.75, 0.6, 1.0)],
	"output": ["Power output", Color(0.25, 0.8, 1.0)],
	"draw": ["Power use", Color(0.6, 0.7, 0.85)],
	"power": ["Power used / output", Color(0.25, 0.8, 1.0)],
	"size": ["Size", Color(0.8, 0.8, 0.85)],
	"reach": ["Reach", Color(0.95, 0.65, 0.3)],
	"arms": ["Arm mounts", Color(0.8, 0.8, 0.85)],
	"heads": ["Head mounts", Color(0.8, 0.8, 0.85)],
	"reactors": ["Reactor mounts", Color(0.25, 0.8, 1.0)],
	"trait": ["Trait", Color(1.0, 0.85, 0.3)],
	"gadget": ["Gadget", Color(0.43, 0.88, 1.0)],
	"price": ["Price", Color(1.0, 0.765, 0.353)],
	"sell": ["Sells for", Color(1.0, 0.765, 0.353)],
	"hours": ["Hours in the bay to bolt on", Color(0.6, 0.7, 0.85)],
	"tech": ["Technique", Color(1.0, 0.62, 0.35)],
}


static func name_of(key: String) -> String:
	return str(STATS.get(key, [key])[0])


static func color_of(key: String) -> Color:
	if key.begins_with("mk:"):
		return load("res://makers.gd").color(key.substr(3)).lightened(0.3) if key != "mk:" else Color(0.55, 0.56, 0.6)
	return STATS.get(key, ["", Color(0.8, 0.8, 0.85)])[1]


## Draws the glyph for `key` in the square r.
static func draw_icon(ci: CanvasItem, key: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.5
	var w := maxf(1.5, s * 0.22)
	if key.begins_with("mk:"):
		# (1.91) a maker's logo (junk: a plain rusty washer)
		if key == "mk:":
			ci.draw_arc(c, s * 0.7, 0, TAU, 14, col, w * 1.2)
		else:
			load("res://logos.gd").draw_logo(ci, load("res://makers.gd").logo(key.substr(3)), c, s * 1.05)
		return
	match key:
		"hp", "core":
			# a heart (core: inside a ring)
			var pts := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y + 1.5) * s * (0.048 if key == "core" else 0.058))
			ci.draw_colored_polygon(pts, col)
			if key == "core":
				ci.draw_arc(c, s * 0.95, 0, TAU, 20, col, w * 0.6)
		"gm":
			# a starburst: the grade makes every hit land harder
			var pts := PackedVector2Array()
			for i in 16:
				var rr := s * (0.95 if i % 2 == 0 else 0.45)
				var a := TAU * i / 16.0 - PI / 2
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"armor":
			var pts := PackedVector2Array([c + Vector2(-0.8, -0.85) * s, c + Vector2(0.8, -0.85) * s, c + Vector2(0.8, 0.0) * s,
					c + Vector2(0.0, 0.95) * s, c + Vector2(-0.8, 0.0) * s])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.75) * s, col.darkened(0.45), w * 0.7)
		"damage":
			# a sword, point up
			var tip := c + Vector2(0.55, -0.95) * s
			var hilt := c + Vector2(-0.35, 0.45) * s
			var dir := (tip - hilt).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			ci.draw_colored_polygon(PackedVector2Array([tip, hilt + nrm * s * 0.17, hilt - nrm * s * 0.17]), col)
			ci.draw_line(hilt + nrm * s * 0.42, hilt - nrm * s * 0.42, col, w)
			ci.draw_line(hilt, hilt - dir * s * 0.5, col, w)
		"speed":
			for k in 2:
				var x0 := -0.75 + k * 0.7
				ci.draw_polyline(PackedVector2Array([c + Vector2(x0, -0.75) * s, c + Vector2(x0 + 0.55, 0) * s, c + Vector2(x0, 0.75) * s]), col, w, true)
		"aim_in":
			# a stopwatch: how long the head takes to aim
			ci.draw_arc(c + Vector2(0, 0.12) * s, s * 0.72, 0, TAU, 20, col, w * 0.8, true)
			ci.draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, -0.95) * s, col, w)
			ci.draw_line(c + Vector2(-0.25, -0.98) * s, c + Vector2(0.25, -0.98) * s, col, w)
			ci.draw_line(c + Vector2(0, 0.12) * s, c + Vector2(0.32, -0.25) * s, col, w * 0.8)
		"aim":
			ci.draw_arc(c, s * 0.62, 0, TAU, 20, col, w * 0.8, true)
			for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + v * s * 0.3, c + v * s * 0.98, col, w * 0.8)
			ci.draw_circle(c, s * 0.1, col)
		"scan":
			ci.draw_arc(c, s * 0.9, 0, TAU, 22, col, w * 0.6, true)
			ci.draw_arc(c, s * 0.5, 0, TAU, 16, col, w * 0.5, true)
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(-1.2), sin(-1.2)) * s * 0.9,
					c + Vector2(cos(-0.6), sin(-0.6)) * s * 0.9, c + Vector2(1, 0) * s * 0.9]), Color(col, 0.75))
		"chips":
			var b := Rect2(c - Vector2(0.55, 0.55) * s, Vector2(1.1, 1.1) * s)
			ci.draw_rect(b, col)
			ci.draw_rect(b.grow(-s * 0.25), col.darkened(0.5))
			for i in 3:
				var o := -0.35 + i * 0.35
				ci.draw_line(c + Vector2(o, -0.55) * s, c + Vector2(o, -0.9) * s, col, w * 0.6)
				ci.draw_line(c + Vector2(o, 0.55) * s, c + Vector2(o, 0.9) * s, col, w * 0.6)
				ci.draw_line(c + Vector2(-0.55, o) * s, c + Vector2(-0.9, o) * s, col, w * 0.6)
				ci.draw_line(c + Vector2(0.55, o) * s, c + Vector2(0.9, o) * s, col, w * 0.6)
		"output", "power", "reactors":
			var pts := PackedVector2Array([c + Vector2(0.2, -1.0) * s, c + Vector2(-0.55, 0.12) * s, c + Vector2(-0.02, 0.12) * s,
					c + Vector2(-0.2, 1.0) * s, c + Vector2(0.55, -0.15) * s, c + Vector2(0.03, -0.15) * s])
			ci.draw_colored_polygon(pts, col)
			if key == "reactors":
				ci.draw_arc(c, s * 0.98, 0, TAU, 6, col, w * 0.6)
		"draw":
			# a plug: what the part takes from the reactor
			ci.draw_rect(Rect2(c + Vector2(-0.5, -0.2) * s, Vector2(1.0, 0.75) * s), col)
			ci.draw_line(c + Vector2(-0.25, -0.2) * s, c + Vector2(-0.25, -0.85) * s, col, w)
			ci.draw_line(c + Vector2(0.25, -0.2) * s, c + Vector2(0.25, -0.85) * s, col, w)
			ci.draw_line(c + Vector2(0, 0.55) * s, c + Vector2(0, 0.98) * s, col, w)
		"size":
			# arrows to the corners
			for v in [Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
				var e: Vector2 = c + v * s * 0.85
				ci.draw_line(c + v * s * 0.2, e, col, w * 0.8)
				ci.draw_line(e, e - Vector2(v.x, 0) * s * 0.4, col, w * 0.8)
				ci.draw_line(e, e - Vector2(0, v.y) * s * 0.4, col, w * 0.8)
		"reach":
			ci.draw_line(c + Vector2(-0.9, -0.6) * s, c + Vector2(-0.9, 0.6) * s, col, w)
			ci.draw_line(c + Vector2(-0.9, 0) * s, c + Vector2(0.85, 0) * s, col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(1.0, 0) * s, c + Vector2(0.45, -0.45) * s, c + Vector2(0.45, 0.45) * s]), col)
		"arms":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.8, -0.6) * s, c + Vector2(0.1, -0.6) * s, c + Vector2(0.4, 0.4) * s]), col, w * 1.3, true)
			ci.draw_circle(c + Vector2(0.45, 0.65) * s, s * 0.3, col)
		"heads":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.8) * s, Vector2(1.2, 1.0) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.35, -0.5) * s, Vector2(0.7, 0.25) * s), col.darkened(0.6))
			ci.draw_line(c + Vector2(0, 0.2) * s, c + Vector2(0, 0.95) * s, col, w)
		"trait":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := s * (0.95 if i % 2 == 0 else 0.4)
				var a := TAU * i / 10.0 - PI / 2
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"gadget":
			ci.draw_arc(c, s * 0.55, 0, TAU, 16, col, w * 1.2)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.6, c + Vector2(cos(a), sin(a)) * s * 0.95, col, w * 1.1)
			ci.draw_circle(c, s * 0.18, col)
		"price", "sell":
			ci.draw_arc(c, s * 0.85, 0, TAU, 18, col, w * 0.7)
			var f := GUI.headb()
			var fs := int(s * 1.3)
			ci.draw_string(f, c + Vector2(-f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, s * 0.45), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		"tech":
			# a fist with a motion line: the limb's technique
			ci.draw_rect(Rect2(c + Vector2(-0.3, -0.55) * s, Vector2(1.1, 1.0) * s), col)
			ci.draw_line(c + Vector2(-1.0, -0.2) * s, c + Vector2(-0.45, -0.2) * s, col, w * 0.7)
			ci.draw_line(c + Vector2(-1.0, 0.2) * s, c + Vector2(-0.55, 0.2) * s, col, w * 0.7)
		"hours":
			ci.draw_arc(c, s * 0.85, 0, TAU, 18, col, w * 0.8)
			ci.draw_line(c, c + Vector2(0, -0.6) * s, col, w * 0.8)
			ci.draw_line(c, c + Vector2(0.45, 0.1) * s, col, w * 0.8)
		_:
			ci.draw_circle(c, s * 0.5, col)


## A short note with a stat's name, shown above whatever was tapped, gone after a moment.
static var _note: Control = null

static func flash_name(from: Control, text: String) -> void:
	if from == null or not is_instance_valid(from) or not from.is_inside_tree():
		return
	if _note != null and is_instance_valid(_note):
		_note.get_parent().queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 95
	from.get_tree().root.add_child(layer)
	var p := PanelContainer.new()
	var sb := GUI.box(Color(0.05, 0.05, 0.07, 0.95), 6, 6)
	sb.border_color = GUI.YELLOW
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := GUI.text(text, 13, GUI.TEXT, "headb")
	if text.length() > 34:
		# long lines (traits, gadgets, makers) wrap at a fixed width; short names stay on one line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = UI.tk(13) * 24.0
	p.add_child(l)
	layer.add_child(p)
	_note = p
	var vp := from.get_viewport_rect().size
	(func():
		if not is_instance_valid(p):
			return
		var r := from.get_global_rect() if is_instance_valid(from) else Rect2(vp * 0.5, Vector2.ZERO)
		var ps := p.get_combined_minimum_size()
		p.size = ps
		var pos := Vector2(r.position.x + r.size.x * 0.5 - ps.x * 0.5, r.position.y - ps.y - 4.0)
		if pos.y < 4.0:
			pos.y = r.end.y + 4.0
		pos.x = clampf(pos.x, 4.0, vp.x - ps.x - 4.0)
		p.position = pos).call_deferred()
	var tw := p.create_tween()
	tw.tween_interval(1.6 + text.length() * 0.03)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)


## One stat: its glyph and its number. A button of its own, so tapping it says the name and doesn't
## press the row it sits in.
class StatChip extends Button:
	var key := ""
	var value := ""
	var col := Color.WHITE
	var val_col := Color.WHITE
	var tip := ""        # what the tap shows (the name, or a longer line for traits and gadgets)
	var fs := 14
	var icon_px := 14.0

	func setup(k: String, v: String, value_col = null, note := "", font_size := 14) -> void:
		var SI = load("res://stat_icons.gd")
		key = k
		value = v
		col = SI.color_of(k)
		val_col = col.lerp(Color.WHITE, 0.35) if value_col == null else value_col
		tip = SI.name_of(k) if note == "" else note
		fs = load("res://ui.gd").px(font_size)
		icon_px = fs * 0.95
		flat = true
		focus_mode = Control.FOCUS_NONE
		tooltip_text = TranslationServer.translate(tip) if note == "" else note
		mouse_filter = Control.MOUSE_FILTER_STOP
		var f: Font = load("res://garage_ui.gd").num()
		var tw := 0.0 if v == "" else f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 3).x + 3.0
		custom_minimum_size = Vector2(icon_px + tw + 4.0, maxf(icon_px + 6.0, fs + 6.0))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pressed.connect(_on_tap)
		queue_redraw()

	func _on_tap() -> void:
		var SI = load("res://stat_icons.gd")
		var t: String = TranslationServer.translate(SI.name_of(key)) if tip == SI.name_of(key) else tip
		if value != "" and tip == SI.name_of(key):
			t += ": " + value
		SI.flash_name(self, t)

	func _draw() -> void:
		var SI = load("res://stat_icons.gd")
		var y := (size.y - icon_px) * 0.5
		SI.draw_icon(self, key, Rect2(1, y, icon_px, icon_px), col)
		if value != "":
			var f: Font = load("res://garage_ui.gd").num()
			var asc := f.get_ascent(fs + 3)
			draw_string(f, Vector2(icon_px + 4.0, size.y * 0.5 + asc * 0.36 + 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 3, val_col)


## A row of stat chips that wraps: [[key, value, value colour or null, note], ...].
static func chips(stats: Array, font_size := 14) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 7)
	flow.add_theme_constant_override("v_separation", 0)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in stats:
		var c := StatChip.new()
		c.setup(str(s[0]), str(s[1]), s[2] if s.size() > 2 else null, str(s[3]) if s.size() > 3 else "", font_size)
		flow.add_child(c)
	return flow


## Just the glyph, as a control (labels in the stats panel and the compare grid). Tap = its name.
static func icon(key: String, font_size := 14) -> StatChip:
	var c := StatChip.new()
	c.setup(key, "", null, "", font_size)
	return c
