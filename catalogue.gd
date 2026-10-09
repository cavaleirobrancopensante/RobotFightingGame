extends Control
## (1.96) The makers' catalogues: a magazine you flip page by page (swipe, tap a side, or the arrows).
## A cover (logo, slogan, the season's issue, a robot in their parts posed in their light), a contents
## page (every part with its page number and the set perk), then one part per page: drawn big and
## turning slowly, its name, a sales line in the maker's voice, the stats, the grades it comes in and
## its price, with Buy and Test drive when you're standing in Parts-R-Us. Every maker prints in its
## own style (STYLE): a photocopied flyer, a 1950s trade catalogue, a Victorian price list, a
## demolition trade sheet, an 80s brochure, an aerospace spec sheet, a luxury lookbook, a manga
## (read right to left) and a circus poster. The maker's music plays softly while it's open.
## Everything is drawn live. Painter draws pages; the shelf's covers (Thumb) use it too.

signal closed
signal buy(id: String)
signal test_drive(id: String)

const GUI = preload("res://garage_ui.gd")
const UI = preload("res://ui.gd")
const PlayLog = preload("res://playlog.gd")
const RobotArt = preload("res://robot_art.gd")
const PilotArt = preload("res://pilot_art.gd")
const PartIcon = preload("res://part_icon.gd")
const StatIcons = preload("res://stat_icons.gd")
const Logos = preload("res://logos.gd")

## paper, ink, accent, the title font, the light the parts and the cover robot are drawn in,
## and whether the stat icons keep their own colours (mono = all in ink, like print).
const STYLE := {
	"scrapworks": {"paper": "#e6e4dc", "ink": "#1c1c1c", "acc": "#2346b8", "title": "stencil", "light": "scrap", "mono": true},
	"oldiron": {"paper": "#efe3c4", "ink": "#1e1a17", "acc": "#b3261e", "title": "headb", "light": "neutral", "mono": true},
	"brassworks": {"paper": "#e7d09f", "ink": "#3b2410", "acc": "#8a5a16", "title": "script", "light": "bay", "mono": true},
	"hellfire": {"paper": "#f2c230", "ink": "#111111", "acc": "#b8261b", "title": "stencil", "light": "steelworks", "mono": true},
	"volta": {"paper": "#150b30", "ink": "#ffffff", "acc": "#00e5ff", "acc2": "#ff3ea5", "title": "italic", "light": "main_event", "mono": false},
	"nimbus": {"paper": "#f5f8fb", "ink": "#17324d", "acc": "#2f80c9", "title": "head", "light": "test_track", "mono": true},
	"kane": {"paper": "#0c0c0e", "ink": "#e9e3d3", "acc": "#e0b84a", "title": "head", "light": "champ_gala", "mono": true},
	"tenryu": {"paper": "#fbfaf5", "ink": "#0b0b0b", "acc": "#e63946", "title": "italic", "light": "fight", "mono": true},
	"menagerie": {"paper": "#861515", "ink": "#fff1c8", "acc": "#f2c14e", "title": "headb", "light": "pub", "mono": false},
}
## The line under the name on each cover.
const KICKER := {
	"scrapworks": "EVERYTHING MUST GO. AGAIN.", "oldiron": "THE FOUNDRY'S FINEST", "brassworks": "Price List & Particulars",
	"hellfire": "DEMOLITION RANGE", "volta": "THE NEW LINE", "nimbus": "TECHNICAL SPECIFICATIONS",
	"kane": "THE COLLECTION", "tenryu": "HERO MACHINES!", "menagerie": "THE GREATEST PARTS ON EARTH!",
}
const KIND_SHORT := {"head": "HEAD", "torso": "TORSO", "arm": "ARM", "leg": "LEG", "back": "BACK", "reactor": "POWER"}
const KIND_WORD := {"head": "HEADS", "torso": "TORSOS", "arm": "ARMS", "leg": "LEGS", "back": "BACK GEAR", "reactor": "REACTORS"}


# ---------------------------------------------------------------- the viewer

var maker := ""
var issue := ""
var pages: Array = []      # {"t": "cover" / "contents" / "part" / "soon", "id": design}
var at := 0
var t := 0.0
var rtl := false           # Tenryu's manga reads right to left
var painter: Painter
var view: Control          # the page (scaled on x to turn it)
var spin: Control          # the part on a part page, turning slowly
var over: Control          # stamps over the picture
var bar: HBoxContainer
var page_rect := Rect2()
var down := Vector2.INF
var turning := false
var _redraw_t := 0.0


## Opens on the cover, or on a design's page (`design` = a part id of any grade).
func setup(m: String, issue_key: String, design: String = "") -> void:
	maker = m
	issue = issue_key
	rtl = m == "tenryu"
	painter = Painter.new(m, issue_key)
	pages = [{"t": "cover"}, {"t": "contents"}]
	for id in GameData.catalogue_parts(m):
		pages.append({"t": "part", "id": id})
	if GameData.catalogue_parts(m).size() < 5:
		pages.append({"t": "soon"})
	if design != "":
		var base: String = GameData.design_of(design)
		for i in pages.size():
			if str(pages[i].get("id", "")) == base:
				at = i
	painter.pages = pages


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	view = PageView.new()
	view.cat = self
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	spin = SpinView.new()
	spin.cat = self
	spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(spin)
	over = OverView.new()
	over.cat = self
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(over)
	var close := UI.button(tr("Close"), _close, 16, Vector2(90, 44))
	close.name = "Close"
	add_child(close)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	PlayLog.add("window", "Catalogue: %s %s" % [maker, issue])
	Sfx.catalogue_music(maker)
	resized.connect(_layout)
	_layout()
	_build_bar()


func _layout() -> void:
	var close: Control = get_node("Close")
	close.position = Vector2(size.x - close.size.x - 12, 10)
	var bh := 54.0 * UI.SCALE
	var top := 12.0 + close.size.y * 0.15
	var avail := Vector2(size.x - 2.0 * 64.0, size.y - bh - top - 22.0)
	var pw := minf(avail.x, avail.y * 1.62)
	var ph := pw / 1.62
	page_rect = Rect2(Vector2((size.x - pw) * 0.5, top + maxf(0.0, (avail.y - ph) * 0.5)), Vector2(pw, ph))
	view.position = page_rect.position
	view.size = page_rect.size
	view.pivot_offset = page_rect.size * 0.5
	over.position = Vector2.ZERO
	over.size = page_rect.size
	_place_spin()
	bar.position = Vector2(12, size.y - bh - 8)
	bar.size = Vector2(size.x - 24, bh)
	queue_redraw()


func _place_spin() -> void:
	var pg: Dictionary = pages[at]
	spin.visible = pg["t"] == "part"
	if spin.visible:
		var pr: Rect2 = painter.pic_rect(Rect2(Vector2.ZERO, page_rect.size), pg)
		spin.position = pr.get_center() + Vector2(0, pr.size.y * 0.04)
		spin.size = Vector2.ZERO


func _build_bar() -> void:
	for c in bar.get_children():
		c.queue_free()
	var prev_txt := tr("Back ▶") if rtl else tr("◀ Back")
	var next_txt := tr("◀ Next") if rtl else tr("Next ▶")
	var b_left := UI.button(next_txt if rtl else prev_txt, turn.bind(1 if rtl else -1), 15, Vector2(120, 46))
	b_left.disabled = (at >= pages.size() - 1) if rtl else at <= 0
	bar.add_child(b_left)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(mid)
	var pl := GUI.text(tr("PAGE %d OF %d") % [at + 1, pages.size()], 13, GUI.MUTED, "headb")
	mid.add_child(pl)
	var pg: Dictionary = pages[at]
	if pg["t"] == "part":
		var base := str(pg["id"])
		var here: bool = GameData.pilot_at == "partsrus"
		var sid := stock_id(base)
		if sid != "":
			var cost: int = GameData.price_of(sid)
			var gname := tr(GameData.GRADES[GameData.grade_of(sid)])
			if here:
				var bb := UI.button(tr("Buy $%d · %s") % [cost, gname], func(): buy.emit(sid), 15, Vector2(0, 46))
				bb.disabled = GameData.money < cost
				bb.add_theme_color_override("font_color", GUI.YELLOW)
				mid.add_child(bb)
			else:
				mid.add_child(GUI.text(tr("On the shelf at Parts-R-Us this week (%s)") % gname, 13, GUI.GREEN))
		elif here:
			mid.add_child(GUI.text(tr("Not on the shelf this week"), 13, GUI.MUTED))
		if here and GameData.part_def(base).get("kind", "") in ["head", "torso", "arm", "leg", "back", "reactor"]:
			var tb := UI.button(tr("Test drive"), func(): test_drive.emit(GameData.graded_id(base, GameData.my_grade())), 15, Vector2(0, 46))
			tb.disabled = not GameData.can_fight()
			tb.add_theme_color_override("font_color", GUI.CYAN)
			mid.add_child(tb)
	var b_right := UI.button(prev_txt if rtl else next_txt, turn.bind(-1 if rtl else 1), 15, Vector2(120, 46))
	b_right.disabled = at <= 0 if rtl else at >= pages.size() - 1
	bar.add_child(b_right)


## The grade of this design on the Parts-R-Us shelf closest to yours ("" = none this week).
func stock_id(base: String) -> String:
	var best := ""
	var gap := 99
	for id in GameData.shop_stock:
		if GameData.design_of(str(id)) == base:
			var d := absi(GameData.grade_of(str(id)) - GameData.my_grade())
			if d < gap:
				gap = d
				best = str(id)
	return best


## Rebuilds the buttons after a purchase (the stamp and the shelf change).
func refresh() -> void:
	_build_bar()
	view.queue_redraw()
	over.queue_redraw()


func turn(dir: int) -> void:
	go_page(at + dir)


func go_page(i: int) -> void:
	i = clampi(i, 0, pages.size() - 1)
	if i == at or turning:
		return
	turning = true
	Sfx.play("click", 0.08)
	var forward := i > at
	var tw := create_tween()
	tw.tween_property(view, "scale", Vector2(0.02, 1.0), 0.11).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		at = i
		_place_spin()
		_build_bar()
		view.queue_redraw()
		over.queue_redraw()
		spin.queue_redraw())
	tw.tween_property(view, "scale", Vector2.ONE, 0.13).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): turning = false)
	# the page swings from the side it turns from
	view.pivot_offset = Vector2(page_rect.size.x * (0.0 if forward != rtl else 1.0), page_rect.size.y * 0.5)


func _close() -> void:
	Sfx.catalogue_music_end()
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	t += delta
	if spin.visible:
		# a slow turn, like a part on a turntable (never quite edge on)
		var c := cos(t * 0.45)
		spin.scale = Vector2(signf(c) * maxf(0.08, absf(c)), 1.0)
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 1.0 / 24.0
		painter.t = t
		view.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.92))
	# a soft shadow under the page
	draw_rect(Rect2(page_rect.position + Vector2(8, 10), page_rect.size), Color(0, 0, 0, 0.45))
	# side arrows (tap zones)
	var cy := page_rect.get_center().y
	for s in [-1.0, 1.0]:
		var x: float = page_rect.position.x - 32.0 if s < 0.0 else page_rect.end.x + 32.0
		var can: bool = (at > 0 if (s < 0.0) != rtl else at < pages.size() - 1)
		var col := Color(1, 1, 1, 0.55 if can else 0.12)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 10.0 * s, cy), Vector2(x - 8.0 * s, cy - 18.0), Vector2(x - 8.0 * s, cy + 18.0)]), col)
	if rtl:
		var f := GUI.headb()
		draw_string(f, Vector2(page_rect.position.x, page_rect.position.y - 4), tr("◀ READS RIGHT TO LEFT"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(12), Color(1, 1, 1, 0.5))


func _gui_input(e: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	elif e is InputEventScreenTouch:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	else:
		return
	if pressed:
		down = pos
		return
	if not released or down == Vector2.INF:
		return
	var dx := pos.x - down.x
	var start := down
	down = Vector2.INF
	accept_event()
	if absf(dx) > 50.0:
		# swipe: drag the page the way you'd turn it (left = on, unless it's the manga)
		turn((1 if dx < 0.0 else -1) * (-1 if rtl else 1))
		return
	if pos.distance_to(start) > 16.0:
		return
	# a contents line?
	if pages[at]["t"] == "contents":
		var lp := pos - page_rect.position
		for h in painter.hits:
			if (h[0] as Rect2).has_point(lp):
				go_page(int(h[1]))
				return
	# a tap on either side of the page turns it
	var rel := (pos.x - page_rect.position.x) / maxf(1.0, page_rect.size.x)
	if rel < 0.22:
		turn(1 if rtl else -1)
	elif rel > 0.78:
		turn(-1 if rtl else 1)


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				_close()
			KEY_LEFT:
				turn(1 if rtl else -1)
			KEY_RIGHT:
				turn(-1 if rtl else 1)
			_:
				return
		get_viewport().set_input_as_handled()


class PageView extends Control:
	var cat
	func _draw() -> void:
		cat.painter.draw_page(self, Rect2(Vector2.ZERO, size), cat.pages[cat.at])


class SpinView extends Control:
	var cat
	func _draw() -> void:
		var pg: Dictionary = cat.pages[cat.at]
		if pg["t"] != "part":
			return
		var pr: Rect2 = cat.painter.pic_rect(Rect2(Vector2.ZERO, cat.page_rect.size), pg)
		cat.painter.draw_part_pic(self, Vector2.ZERO, minf(pr.size.x, pr.size.y) * 0.78, str(pg["id"]))


class OverView extends Control:
	var cat
	func _draw() -> void:
		cat.painter.draw_over(self, Rect2(Vector2.ZERO, size), cat.pages[cat.at])


## A catalogue's cover, small: for the rack at Parts-R-Us and the shelf at home.
class Thumb extends Button:
	var painter: Painter
	func _init(m: String, issue_key: String, h: float = 132.0) -> void:
		painter = Painter.new(m, issue_key)
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(h * 1.62, h)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _draw() -> void:
		draw_rect(Rect2(Vector2(4, 5), size), Color(0, 0, 0, 0.4))
		painter.draw_page(self, Rect2(Vector2.ZERO, size), {"t": "cover"})


# ---------------------------------------------------------------- the painter

class Painter extends RefCounted:
	var m := ""
	var issue := ""
	var st: Dictionary
	var paper: Color
	var ink: Color
	var acc: Color
	var t := 0.0
	var pages: Array = []
	var hits: Array = []     # contents lines: [Rect2, page index]
	static var _fonts := {}
	static var _heroes := {}

	func _init(maker: String, issue_key: String) -> void:
		m = maker
		issue = issue_key
		st = STYLE.get(m, STYLE["oldiron"])
		paper = Color(str(st["paper"]))
		ink = Color(str(st["ink"]))
		acc = Color(str(st["acc"]))

	# ---- type

	static func font(k: String) -> Font:
		match k:
			"stencil":
				return GUI.stencil()
			"head":
				return GUI.head()
			"headb":
				return GUI.headb()
			"bold":
				return GUI.bold()
			"num":
				return GUI.num()
			"script", "italic", "ibody":
				if not _fonts.has(k):
					var v := FontVariation.new()
					v.base_font = GUI.bold() if k == "script" else (GUI.headb() if k == "italic" else GUI.body())
					v.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.3 if k == "script" else 0.22, 1.0), Vector2.ZERO)
					_fonts[k] = v
				return _fonts[k]
		return GUI.body()

	## A font size that grows with the page (and with the text size setting).
	func fz(r: Rect2, base: float) -> int:
		return maxi(5, int(round(UI.tk(base) * r.size.y / 520.0)))

	func tx(ci: CanvasItem, fk: String, pos: Vector2, s: String, sz: int, col: Color, w: float = -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		ci.draw_string(font(fk), pos, s, al, w, sz, col)

	## Wrapped text from its top-left corner; returns the height it took.
	func para(ci: CanvasItem, fk: String, top: Vector2, s: String, w: float, sz: int, col: Color, lines: int = 3, al := HORIZONTAL_ALIGNMENT_LEFT) -> float:
		var f := font(fk)
		ci.draw_multiline_string(f, top + Vector2(0, f.get_ascent(sz)), s, al, w, sz, lines, col)
		return f.get_multiline_string_size(s, al, w, sz, lines).y

	## Letter-spaced capitals (Kane), centred on x when `centre`.
	func spaced(ci: CanvasItem, fk: String, pos: Vector2, s: String, sz: int, col: Color, gap: float, centre := false) -> void:
		var f := font(fk)
		var w := 0.0
		for ch in s:
			w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + gap
		var x := pos.x - (w - gap) * 0.5 if centre else pos.x
		for ch in s:
			ci.draw_char(f, Vector2(x, pos.y), ch, sz, col)
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + gap

	func outlined(ci: CanvasItem, fk: String, pos: Vector2, s: String, sz: int, col: Color, line: Color, ow: int, w: float = -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		ci.draw_string_outline(font(fk), pos, s, al, w, sz, ow, line)
		ci.draw_string(font(fk), pos, s, al, w, sz, col)

	func text_w(fk: String, s: String, sz: int) -> float:
		return font(fk).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

	static func money(v: int) -> String:
		var s := str(absi(v))
		var out := ""
		while s.length() > 3:
			out = "," + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		return ("-" if v < 0 else "") + "$" + s + out

	# ---- pages

	func draw_page(ci: CanvasItem, r: Rect2, pg: Dictionary) -> void:
		_paper(ci, r)
		match str(pg["t"]):
			"cover":
				_cover(ci, r)
			"contents":
				_contents(ci, r)
			"part":
				_part_page(ci, r, str(pg["id"]))
			"soon":
				_soon(ci, r)
		_after(ci, r)

	## Where the part's picture sits on a part page.
	func pic_rect(r: Rect2, _pg: Dictionary) -> Rect2:
		var pad := r.size.y * 0.07
		if m == "tenryu":
			return Rect2(Vector2(r.position.x + r.size.x * 0.42, r.position.y + pad), Vector2(r.size.x * 0.58 - pad, r.size.y - 2.0 * pad))
		if m == "kane":
			return Rect2(Vector2(r.position.x + pad, r.position.y + pad), Vector2(r.size.x * 0.5, r.size.y - 2.0 * pad))
		return Rect2(Vector2(r.position.x + pad, r.position.y + pad * 1.4), Vector2(r.size.x * 0.52 - pad, r.size.y - pad * 2.6))

	func _text_rect(r: Rect2) -> Rect2:
		var pad := r.size.y * 0.07
		if m == "tenryu":
			return Rect2(Vector2(r.position.x + pad, r.position.y + r.size.y * 0.39), Vector2(r.size.x * 0.42 - pad * 1.5, r.size.y * 0.61 - pad * 1.2))
		if m == "kane":
			return Rect2(Vector2(r.position.x + r.size.x * 0.58, r.position.y + r.size.y * 0.2), Vector2(r.size.x * 0.36, r.size.y * 0.7))
		return Rect2(Vector2(r.position.x + r.size.x * 0.56, r.position.y + pad * 1.3), Vector2(r.size.x * 0.44 - pad, r.size.y - pad * 2.3))

	# ---- paper, by style

	func _paper(ci: CanvasItem, r: Rect2) -> void:
		var W := r.size.x
		var H := r.size.y
		var o := r.position
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(m)
		match m:
			"scrapworks":
				# a photocopy, a little crooked, on a dark table
				ci.draw_rect(r, Color(0.16, 0.14, 0.12))
				var k := H * 0.012
				var q := PackedVector2Array([o + Vector2(k, k * 2.0), o + Vector2(W - k * 0.5, k * 0.6), o + Vector2(W - k * 1.4, H - k * 0.4), o + Vector2(k * 0.3, H - k * 1.6)])
				ci.draw_colored_polygon(q, paper)
				for i in 2:
					var x := o.x + W * (0.18 + 0.55 * i) + rng.randf() * 20.0
					ci.draw_line(Vector2(x, o.y + k * 2.0), Vector2(x - 3.0, o.y + H - k), Color(0, 0, 0, 0.06), 6.0)
				for i in 90:
					ci.draw_circle(o + Vector2(rng.randf() * W, rng.randf() * H), rng.randf_range(0.4, 1.6) * H / 500.0, Color(0, 0, 0, rng.randf_range(0.15, 0.5)))
				ci.draw_rect(Rect2(o + Vector2(0, H * 0.96), Vector2(W, H * 0.04)), Color(0, 0, 0, 0.12))
			"oldiron":
				ci.draw_rect(r, paper)
				ci.draw_rect(r.grow(-H * 0.022), ink, false, maxf(1.5, H * 0.006))
				ci.draw_rect(r.grow(-H * 0.036), ink, false, maxf(1.0, H * 0.0025))
				for i in 70:
					ci.draw_circle(o + Vector2(rng.randf() * W, rng.randf() * H), H * 0.002, Color(0.4, 0.3, 0.2, 0.2))
			"brassworks":
				ci.draw_rect(r, paper)
				for i in 8:
					ci.draw_rect(r.grow(-i * H * 0.008), Color(0.35, 0.2, 0.05, 0.07 - i * 0.008), false, H * 0.012)
				var b := r.grow(-H * 0.035)
				ci.draw_rect(b, ink, false, maxf(1.5, H * 0.005))
				ci.draw_rect(b.grow(-H * 0.012), ink, false, maxf(1.0, H * 0.002))
				for c in [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]:
					ci.draw_circle(c, H * 0.022, paper)
					ci.draw_arc(c, H * 0.02, 0, TAU, 20, ink, maxf(1.0, H * 0.003))
					ci.draw_arc(c, H * 0.011, 0, TAU, 14, ink, maxf(1.0, H * 0.002))
					ci.draw_circle(c, H * 0.004, ink)
			"hellfire":
				ci.draw_rect(r, paper)
				_hazard(ci, Rect2(o, Vector2(W, H * 0.06)))
				_hazard(ci, Rect2(o + Vector2(0, H * 0.94), Vector2(W, H * 0.06)))
				for i in 5:
					var c := o + Vector2(rng.randf() * W, H * (0.1 + rng.randf() * 0.8))
					for k in 5:
						ci.draw_circle(c, H * (0.07 - k * 0.012), Color(0.2, 0.08, 0.0, 0.05))
				for c in [o + Vector2(H * 0.04, H * 0.1), o + Vector2(W - H * 0.04, H * 0.1), o + Vector2(H * 0.04, H * 0.9), o + Vector2(W - H * 0.04, H * 0.9)]:
					ci.draw_circle(c, H * 0.012, Color(0.25, 0.22, 0.15))
					ci.draw_circle(c + Vector2(-1, -1) * H * 0.003, H * 0.005, Color(0.6, 0.55, 0.4))
			"volta":
				# sunset sky down to the horizon, then the neon grid
				var hz := o.y + H * 0.64
				var top := Color("#120a2e")
				var mid := Color("#7a1c6e")
				var low := Color("#ff7a3c")
				var n := 24
				for i in n:
					var a := float(i) / n
					var col := top.lerp(mid, a * 1.6) if a < 0.62 else mid.lerp(low, (a - 0.62) / 0.38)
					ci.draw_rect(Rect2(Vector2(o.x, o.y + (hz - o.y) * a), Vector2(W, (hz - o.y) / n + 1.0)), col)
				ci.draw_rect(Rect2(Vector2(o.x, hz), Vector2(W, o.y + H - hz)), Color("#0d0620"))
				var grid := Color(1.0, 0.24, 0.65, 0.75)
				var vx := o.x + W * 0.5
				for i in 9:
					var y := minf(o.y + H - 1.0, hz + (o.y + H - hz) * pow(float(i) / 8.0, 1.8) + fmod(t * 6.0, 1.0) * (i * 0.6))
					ci.draw_line(Vector2(o.x, y), Vector2(o.x + W, y), grid, maxf(1.0, H * 0.003))
				for i in 17:
					var x := o.x + W * (i / 16.0)
					var a := Vector2(vx + (x - vx) * 0.12, hz)
					var b := Vector2(vx + (x - vx) * 2.2, o.y + H)
					if b.x < o.x or b.x > o.x + W:
						# stop where the line leaves the page's side
						var ex := o.x if b.x < o.x else o.x + W
						b = a.lerp(b, (ex - a.x) / (b.x - a.x))
					ci.draw_line(a, b, grid, maxf(1.0, H * 0.003))
				ci.draw_line(Vector2(o.x, hz), Vector2(o.x + W, hz), Color(1.0, 0.75, 0.9), maxf(1.5, H * 0.004))
			"nimbus":
				ci.draw_rect(r, paper)
				var g := H / 26.0
				var lc := Color(0.55, 0.72, 0.88, 0.22)
				var x := o.x
				var i := 0
				while x < o.x + W:
					ci.draw_line(Vector2(x, o.y), Vector2(x, o.y + H), Color(lc, lc.a * (2.2 if i % 5 == 0 else 1.0)), 1.0)
					x += g
					i += 1
				var y := o.y
				i = 0
				while y < o.y + H:
					ci.draw_line(Vector2(o.x, y), Vector2(o.x + W, y), Color(lc, lc.a * (2.2 if i % 5 == 0 else 1.0)), 1.0)
					y += g
					i += 1
				ci.draw_rect(r.grow(-H * 0.025), ink, false, maxf(1.0, H * 0.003))
			"kane":
				ci.draw_rect(r, paper)
				ci.draw_rect(r.grow(-H * 0.04), Color(acc, 0.7), false, maxf(1.0, H * 0.0018))
			"tenryu":
				ci.draw_rect(r, paper)
			"menagerie":
				ci.draw_rect(r, paper)
				var c := r.get_center()
				for k in 10:
					ci.draw_circle(c, W * (0.62 - k * 0.05), Color(1.0, 0.45, 0.25, 0.035))
				var b := r.grow(-H * 0.03)
				ci.draw_rect(b, acc, false, maxf(2.0, H * 0.008))
				ci.draw_rect(b.grow(-H * 0.018), Color(acc, 0.7), false, maxf(1.0, H * 0.003))
				# a row of bulbs round the frame, chasing
				var per := int(W / (H * 0.045))
				for k in per:
					var on := (k + int(t * 4.0)) % 3 != 0
					for yy in [b.position.y, b.end.y]:
						var p := Vector2(b.position.x + b.size.x * (k + 0.5) / per, yy)
						ci.draw_circle(p, H * 0.008, Color(1.0, 0.92, 0.6) if on else Color(0.45, 0.3, 0.15))
			_:
				ci.draw_rect(r, paper)

	## Anything that sits on top of the whole page (scrapworks' tape).
	func _after(ci: CanvasItem, r: Rect2) -> void:
		if m == "scrapworks":
			var H := r.size.y
			for c in [r.position + Vector2(r.size.x * 0.06, H * 0.02), r.position + Vector2(r.size.x * 0.92, H * 0.01)]:
				_tape(ci, c, H * 0.16, H * 0.045, -0.5 if c.x < r.get_center().x else 0.45)

	func _tape(ci: CanvasItem, c: Vector2, w: float, h: float, rot: float) -> void:
		var ax := Vector2(cos(rot), sin(rot))
		var ay := Vector2(-ax.y, ax.x)
		var pts := PackedVector2Array([c - ax * w * 0.5 - ay * h * 0.5, c + ax * w * 0.5 - ay * h * 0.5, c + ax * w * 0.5 + ay * h * 0.5, c - ax * w * 0.5 + ay * h * 0.5])
		ci.draw_colored_polygon(pts, Color(0.93, 0.88, 0.7, 0.62))

	func _hazard(ci: CanvasItem, b: Rect2) -> void:
		ci.draw_rect(b, Color(0.1, 0.1, 0.1))
		var s := b.size.y
		var x := b.position.x - s
		while x < b.end.x:
			var pts := PackedVector2Array([Vector2(maxf(b.position.x, x), b.end.y), Vector2(x + s, b.position.y), Vector2(minf(b.end.x, x + s * 1.6), b.position.y), Vector2(x + s * 0.6, b.end.y)])
			var clipped := Geometry2D.intersect_polygons(pts, PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]))
			for poly in clipped:
				ci.draw_colored_polygon(poly, Color(0.95, 0.76, 0.19))
			x += s * 1.2

	# ---- the cover

	func _cover(ci: CanvasItem, r: Rect2) -> void:
		var W := r.size.x
		var H := r.size.y
		var o := r.position
		var M = GameData.Makers
		var mi: Dictionary = M.info(m)
		var name := str(mi.get("name", "")).to_upper()
		var iss := GameData.issue_name(issue)
		var hero := Rect2(o + Vector2(W * 0.5, H * 0.1), Vector2(W * 0.46, H * 0.84))
		match m:
			"kane":
				hero = Rect2(o + Vector2(W * 0.3, H * 0.2), Vector2(W * 0.4, H * 0.7))
				_spot(ci, hero)
				_hero(ci, hero)
				spaced(ci, "head", o + Vector2(W * 0.5, H * 0.15), name, fz(r, 22), acc, H * 0.02, true)
				spaced(ci, "head", o + Vector2(W * 0.5, H * 0.92), tr(KICKER[m]) + "  ·  " + iss, fz(r, 11), ink, H * 0.008, true)
				Logos.draw_logo(ci, M.logo(m), o + Vector2(W * 0.08, H * 0.12), H * 0.045)
				return
			"tenryu":
				# a manga cover: speed lines, a red title block, the robot huge
				_speed(ci, Rect2(o, r.size), hero.get_center(), 60)
				ci.draw_rect(Rect2(o + Vector2(W * 0.04, H * 0.06), Vector2(W * 0.46, H * 0.3)), acc)
				outlined(ci, "italic", o + Vector2(W * 0.07, H * 0.2), "TENRYU", fz(r, 56), Color.WHITE, ink, maxi(2, fz(r, 5)))
				tx(ci, "italic", o + Vector2(W * 0.07, H * 0.31), tr("MECHA WORKS"), fz(r, 26), Color.WHITE)
				var vol := (int(issue.get_slice(":", 0)) - 1) * 4 + int(issue.get_slice(":", 1)) + 1
				var kw := text_w("italic", tr(KICKER[m]), fz(r, 26))
				ci.draw_rect(Rect2(o + Vector2(W * 0.04, H * 0.39), Vector2(maxf(kw, text_w("headb", tr("VOL. %d") % vol + "  ·  " + iss, fz(r, 15))) + W * 0.04, H * 0.2)), Color.WHITE)
				ci.draw_rect(Rect2(o + Vector2(W * 0.04, H * 0.39), Vector2(maxf(kw, text_w("headb", tr("VOL. %d") % vol + "  ·  " + iss, fz(r, 15))) + W * 0.04, H * 0.2)), ink, false, maxf(2.0, H * 0.006))
				tx(ci, "italic", o + Vector2(W * 0.06, H * 0.47), tr(KICKER[m]), fz(r, 26), ink)
				tx(ci, "headb", o + Vector2(W * 0.06, H * 0.55), tr("VOL. %d") % vol + "  ·  " + iss, fz(r, 15), ink)
				_hero(ci, hero.grow(H * 0.04))
				_balloon(ci, Rect2(o + Vector2(W * 0.05, H * 0.66), Vector2(W * 0.4, H * 0.24)), tr(str(mi.get("pitch", ""))), fz(r, 14))
				return
		# the rest: masthead on the left, the robot on the right
		var bg := hero
		match m:
			"oldiron":
				_halftone(ci, bg.grow(-H * 0.02), acc)
			"brassworks":
				_oval(ci, bg)
			"hellfire":
				_scorch(ci, bg.get_center(), H * 0.4)
			"volta":
				_sun(ci, Vector2(bg.get_center().x, o.y + H * 0.64), H * 0.3)
			"nimbus":
				_dims(ci, bg.grow(-H * 0.06), "3200", "2400")
			"menagerie":
				_burst(ci, bg.get_center() + Vector2(0, H * 0.05), H * 0.75)
			"scrapworks":
				_photo(ci, bg.grow(-H * 0.02))
		_hero(ci, hero)
		var x := o.x + W * 0.07
		var y := o.y + H * 0.2
		var ts := fz(r, 40)
		match m:
			"oldiron":
				ci.draw_rect(Rect2(o + Vector2(W * 0.045, H * 0.07), Vector2(W * 0.44, H * 0.09)), acc)
				tx(ci, "headb", o + Vector2(W * 0.06, H * 0.14), tr("EST. 1951 · TRADE CATALOGUE"), fz(r, 15), paper)
				tx(ci, "headb", Vector2(x + 3, y + H * 0.1 + 3), "OLD IRON", fz(r, 54), acc)
				tx(ci, "headb", Vector2(x, y + H * 0.1), "OLD IRON", fz(r, 54), ink)
				tx(ci, "headb", Vector2(x, y + H * 0.2), "FOUNDRY", fz(r, 40), acc)
				y += H * 0.24
			"brassworks":
				tx(ci, "script", Vector2(x, y + H * 0.08), "Brassworks", fz(r, 50), ink)
				tx(ci, "script", Vector2(x + W * 0.12, y + H * 0.17), "& Sons", fz(r, 34), acc)
				y += H * 0.2
			"hellfire":
				tx(ci, "stencil", Vector2(x, y + H * 0.08), "HELLFIRE", fz(r, 54), ink)
				tx(ci, "stencil", Vector2(x, y + H * 0.17), "HEAVY", fz(r, 40), acc)
				y += H * 0.21
			"volta":
				_chrome(ci, Vector2(x, y + H * 0.1), "VOLTA", fz(r, 66))
				tx(ci, "italic", Vector2(x + W * 0.02, y + H * 0.19), "MOTOR", fz(r, 30), Color(str(st["acc2"])))
				y += H * 0.23
			"nimbus":
				tx(ci, "head", Vector2(x, y + H * 0.08), "NIMBUS", fz(r, 50), ink)
				tx(ci, "head", Vector2(x, y + H * 0.15), "AERIAL", fz(r, 26), acc)
				ci.draw_line(Vector2(x, y + H * 0.18), Vector2(x + W * 0.36, y + H * 0.18), acc, maxf(1.0, H * 0.004))
				y += H * 0.2
			"menagerie":
				var ts2 := fz(r, 46)
				outlined(ci, "headb", Vector2(x, y + H * 0.08), "MENAGERIE", ts2, acc, Color(0.25, 0.03, 0.03), maxi(2, fz(r, 6)))
				outlined(ci, "headb", Vector2(x, y + H * 0.17), "MECHANICA", fz(r, 34), Color(1.0, 0.95, 0.8), Color(0.25, 0.03, 0.03), maxi(2, fz(r, 5)))
				y += H * 0.2
			"scrapworks":
				ci.draw_set_transform(Vector2(x, y + H * 0.09), -0.04, Vector2.ONE)
				tx(ci, "stencil", Vector2.ZERO, "SCRAPWORKS", fz(r, 48), ink)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				y += H * 0.14
			_:
				tx(ci, str(st["title"]), Vector2(x, y + H * 0.08), name, ts, ink)
				y += H * 0.12
		var kfont := "ibody" if m == "brassworks" else ("stencil" if m == "hellfire" else "headb")
		var kcol := ink if m in ["brassworks", "nimbus", "hellfire", "scrapworks"] else (acc if m != "oldiron" else ink)
		var kh := para(ci, kfont, Vector2(x, y + H * 0.01), tr(KICKER[m]), W * 0.4, fz(r, 20), kcol, 2)
		y += kh - fz(r, 20) * 1.1
		var ph := para(ci, "ibody" if m in ["brassworks", "menagerie"] else "body", Vector2(x, y + H * 0.1), tr(str(mi.get("pitch", ""))), W * 0.4, fz(r, 15), ink if m != "volta" else Color(1, 1, 1, 0.9), 3)
		Logos.draw_logo(ci, M.logo(m), Vector2(x + H * 0.07, minf(o.y + H * 0.84, y + H * 0.1 + ph + H * 0.1)), H * 0.06)
		# the issue, top right; "FREE" on a flash
		var iw := text_w("headb", iss, fz(r, 15))
		tx(ci, "headb", o + Vector2(W - iw - H * 0.07, H * 0.11), iss, fz(r, 15), ink if not m in ["volta", "menagerie"] else acc)
		var fc := o + Vector2(W * 0.88, H * 0.8)
		var pts := PackedVector2Array()
		for k in 24:
			var a := TAU * k / 24.0
			pts.append(fc + Vector2(cos(a), sin(a)) * H * (0.075 if k % 2 == 0 else 0.058))
		ci.draw_colored_polygon(pts, acc if m != "hellfire" else ink)
		var fs := fz(r, 15)
		tx(ci, "headb", fc + Vector2(-H * 0.06, fs * 0.35), tr("FREE"), fs, paper if m != "volta" else Color.WHITE, H * 0.12, HORIZONTAL_ALIGNMENT_CENTER)

	## The cover robot: the maker's parts on one robot, in its paint, in its light.
	func _hero(ci: CanvasItem, b: Rect2) -> void:
		var look := hero_look(m)
		if look.is_empty():
			return
		var g: Dictionary = RobotArt.front_geom(look)
		var head: Rect2 = g["head"]
		var sc := b.size.y / (-head.position.y + 60.0)
		RobotArt.draw_front(ci, Vector2(b.get_center().x, b.position.y + (-head.position.y) * sc), look, {"scale": sc, "light": str(st["light"]), "time": t})
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	static func hero_look(maker: String) -> Dictionary:
		if _heroes.has(maker):
			return _heroes[maker]
		var ids: Array = GameData.catalogue_parts(maker)
		var pick := {}
		for id in ids:
			var d: Dictionary = GameData.part_def(str(id))
			var k := str(d["kind"])
			if not pick.has(k) or (d.get("shop", false) and not GameData.part_def(pick[k]).get("shop", false)):
				if k != "torso" or not ((d["mounts"] as Array).has("arm_front2") or (d["mounts"] as Array).has("head2")):
					pick[k] = str(id)
		var fall := {"head": "head_box", "torso": "torso_box", "arm": "arm_rod", "leg": "leg_steel"}
		for k in fall:
			if not pick.has(k):
				pick[k] = fall[k]
		var g: int = clampi(GameData.my_grade(), 1, 5)
		var parts := {}
		for sl in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
			parts[sl] = GameData.graded_id(pick[GameData.SLOT_KIND[sl]], g)
		var paint: String = str(GameData.PAINTS[GameData.Makers.paint_of(maker)]["color"])
		var o := {"name": "", "body": paint, "trim": str(STYLE.get(maker, {}).get("acc", "#cccccc")), "eye": str(GameData.Makers.info(maker).get("color", "#ffcc33")),
				"hp": 1.0, "damage": 1.0, "speed": 1.0, "scale": 1.0, "parts": parts, "specials": [], "style": "striker"}
		var look: Dictionary = GameData.look_from_spec(GameData.opponent_spec_from(o, 0.0))
		_heroes[maker] = look
		return look

	# ---- contents

	func _contents(ci: CanvasItem, r: Rect2) -> void:
		hits = []
		var W := r.size.x
		var H := r.size.y
		var o := r.position
		var M = GameData.Makers
		var mi: Dictionary = M.info(m)
		var light_text := m in ["volta", "kane", "menagerie"]
		var tcol := ink
		var tf := str(st["title"])
		var pad := H * 0.08
		var x := o.x + pad
		if m == "volta":
			ci.draw_rect(Rect2(o + Vector2(pad * 0.6, pad * 0.6), Vector2(W * 0.58, H - pad * 1.2)), Color(0.05, 0.02, 0.12, 0.72))
		tx(ci, tf, Vector2(x, o.y + pad + fz(r, 30)), tr("IN THIS ISSUE") if m != "brassworks" else tr("Particulars of This Issue"), fz(r, 30), acc if light_text or m in ["oldiron", "tenryu"] else ink)
		if m == "kane":
			ci.draw_line(Vector2(x, o.y + pad + fz(r, 30) * 1.35), Vector2(x + W * 0.2, o.y + pad + fz(r, 30) * 1.35), acc, 1.0)
		var ids: Array = []
		for i in pages.size():
			if str(pages[i]["t"]) == "part":
				ids.append(i)
		var rows := ids.size()
		var cols := 1 if rows <= 10 else 2
		var per := int(ceil(float(rows) / cols))
		var top := o.y + pad + fz(r, 30) * 1.9
		var lh := minf(H * 0.06, (o.y + H - pad - top) / maxf(1.0, per))
		var fs := maxi(5, mini(fz(r, 15), int(lh * 0.78)))
		var colw := W * (0.56 if cols == 1 else 0.275)
		var kind_prev := ""
		for n in rows:
			var i: int = ids[n]
			var d: Dictionary = GameData.part_def(str(pages[i]["id"]))
			var cx := x + (n / per) * (colw + W * 0.02)
			var cy := top + (n % per) * lh
			var base := cy + lh * 0.75
			var label := M.ad_name(d)
			var k := str(d["kind"])
			var kw := tr(KIND_SHORT.get(k, k.to_upper()))
			var num := "%d" % (i + 1)
			var col := tcol if not light_text else ink
			tx(ci, "headb", Vector2(cx, base), (kw if k != kind_prev or n % per == 0 else ""), maxi(5, int(fs * 0.7)), acc, colw * 0.2)
			kind_prev = k
			var lx := cx + colw * 0.21
			var nw := text_w("headb", num, fs)
			var name_w := minf(text_w("body", label, fs), colw * 0.64)
			tx(ci, "ibody" if m == "brassworks" else "body", Vector2(lx, base), label, fs, col, colw * 0.64)
			# dotted leader to the page number
			var dx := lx + name_w + fs * 0.5
			while dx < cx + colw - nw - fs * 0.6:
				ci.draw_circle(Vector2(dx, base - fs * 0.15), maxf(0.6, fs * 0.06), Color(col, 0.6))
				dx += fs * 0.45
			tx(ci, "headb", Vector2(cx + colw - nw, base), num, fs, col)
			if GameData.owns_design(str(pages[i]["id"])):
				ci.draw_circle(Vector2(cx + colw + fs * 0.45, base - fs * 0.3), fs * 0.22, acc)
			hits.append([Rect2(Vector2(cx - 4, cy) - o, Vector2(colw + 8, lh)), i])
		# the set perk and where to buy, on the right (or under, for one column)
		var bx := o.x + W * 0.68
		var bw := W - (bx - o.x) - pad
		var by := o.y + pad + fz(r, 30) * 1.9
		var boxc := Color(acc, 0.14) if not light_text else Color(0, 0, 0, 0.35)
		ci.draw_rect(Rect2(Vector2(bx - fs * 0.6, by - fs * 0.6), Vector2(bw + fs * 1.2, H * 0.5)), boxc)
		ci.draw_rect(Rect2(Vector2(bx - fs * 0.6, by - fs * 0.6), Vector2(bw + fs * 1.2, H * 0.5)), acc, false, maxf(1.0, H * 0.003))
		tx(ci, "headb", Vector2(bx, by + fs), tr("BOLT ON %d") % M.SET_AT, fs, acc)
		tx(ci, "headb", Vector2(bx, by + fs * 2.3), str(mi.get("perk_name", "")), int(fs * 1.4), ink)
		var hh := para(ci, "body", Vector2(bx, by + fs * 3.0), tr(str(mi.get("perk", ""))), bw, fs, ink, 4)
		para(ci, "ibody", Vector2(bx, by + fs * 3.6 + hh), tr("Ask at the counter at Parts-R-Us. Prices change with your grade and with our sales."), bw, int(fs * 0.85), Color(ink, 0.8), 5)
		Logos.draw_logo(ci, M.logo(m), Vector2(bx + bw * 0.5, o.y + H - pad - H * 0.08), H * 0.06)
		var owned := tr("● = you own one")
		tx(ci, "body", Vector2(x, o.y + H - pad * 0.45), owned, maxi(5, int(fs * 0.8)), Color(ink if not light_text else ink, 0.7))

	# ---- a part's page

	func _part_page(ci: CanvasItem, r: Rect2, base: String) -> void:
		var W := r.size.x
		var H := r.size.y
		var o := r.position
		var M = GameData.Makers
		var g: int = clampi(GameData.my_grade(), 1, 5)
		var d: Dictionary = GameData.part_def(GameData.graded_id(base, g))
		var d1: Dictionary = GameData.part_def(base)
		var pr := pic_rect(r, {})
		var trc := _text_rect(r)
		var light_text := m in ["volta", "kane", "menagerie"]
		# the picture's backdrop
		match m:
			"scrapworks":
				_photo(ci, pr)
			"oldiron":
				_halftone(ci, pr, acc)
				ci.draw_rect(Rect2(Vector2(pr.position.x, pr.end.y - H * 0.02), Vector2(pr.size.x, H * 0.012)), ink)
			"brassworks":
				_oval(ci, pr)
			"hellfire":
				_scorch(ci, pr.get_center(), pr.size.y * 0.5)
				ci.draw_set_transform(pr.position + Vector2(pr.size.x * 0.05, pr.size.y * 0.95), -0.2, Vector2.ONE)
				tx(ci, "stencil", Vector2.ZERO, tr("HEAVY"), fz(r, 70), Color(0, 0, 0, 0.08))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"volta":
				_sun(ci, Vector2(pr.get_center().x, o.y + H * 0.64), H * 0.27)
			"nimbus":
				var sz := float(d1.get("size", 1.0))
				_dims(ci, pr.grow(-H * 0.04), "%d" % int(round(sz * 820.0 / 10.0) * 10.0), "%d" % int(round(sz * 640.0 / 10.0) * 10.0))
			"kane":
				_spot(ci, pr)
			"tenryu":
				_tenryu_panels(ci, r, pr, trc, d)
			"menagerie":
				_burst(ci, pr.get_center(), pr.size.y * 0.9)
				var pc := pr.get_center() + Vector2(0, pr.size.y * 0.36)
				ci.draw_rect(Rect2(pc - Vector2(pr.size.x * 0.22, 0), Vector2(pr.size.x * 0.44, pr.size.y * 0.1)), Color(0.75, 0.12, 0.12))
				ci.draw_rect(Rect2(pc - Vector2(pr.size.x * 0.22, 0), Vector2(pr.size.x * 0.44, pr.size.y * 0.1)), acc, false, maxf(1.5, H * 0.004))
				ci.draw_rect(Rect2(pc - Vector2(pr.size.x * 0.24, pr.size.y * 0.02), Vector2(pr.size.x * 0.48, pr.size.y * 0.025)), acc)
		if m != "tenryu":
			ci.draw_set_transform(pr.get_center() + Vector2(0, pr.size.y * 0.42), 0.0, Vector2(1.0, 0.18))
			ci.draw_circle(Vector2.ZERO, pr.size.x * 0.28, Color(0, 0, 0, 0.16 if not light_text else 0.35))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the words
		var x := trc.position.x
		var y := trc.position.y
		var w := trc.size.x
		var fs := fz(r, 15)
		var k := str(d["kind"])
		var num := 0
		for i in pages.size():
			if str(pages[i].get("id", "")) == base:
				num = i + 1
		var head_col := acc if m in ["oldiron", "volta", "menagerie", "hellfire", "kane"] else ink
		if m == "volta":
			ci.draw_rect(Rect2(trc.position - Vector2(fs, fs), trc.size + Vector2(fs * 2.0, fs * 1.6)), Color(0.05, 0.02, 0.12, 0.72))
		if m == "tenryu":
			ci.draw_rect(trc.grow(fs * 0.4), Color.WHITE)
			ci.draw_rect(trc.grow(fs * 0.4), ink, false, maxf(2.0, H * 0.005))
		var kind_line := tr(KIND_WORD.get(k, k.to_upper())) + "  ·  " + (tr("No. %d") % num if m != "brassworks" else tr("Plate %d") % num)
		if m == "kane":
			spaced(ci, "head", Vector2(x, y + fs), kind_line.to_upper(), int(fs * 0.85), acc, fs * 0.25)
		else:
			tx(ci, "headb", Vector2(x, y + fs), kind_line, int(fs * 0.9), head_col)
		y += fs * 1.5
		var name := M.ad_name(d1)
		var nf := "script" if m == "brassworks" else ("stencil" if m in ["hellfire", "scrapworks"] else ("italic" if m in ["volta", "tenryu"] else "headb"))
		var nsz := fz(r, 34) if m != "kane" else fz(r, 26)
		if m == "volta":
			y += _chrome_wrap(ci, Vector2(x, y), name.to_upper(), w, nsz)
		elif m == "menagerie":
			y += nsz * 0.1
			outlined(ci, "headb", Vector2(x, y + nsz), name.to_upper(), nsz, acc, Color(0.25, 0.03, 0.03), maxi(2, int(nsz * 0.12)), w)
			y += nsz * 1.25
		elif m == "kane":
			y += para(ci, "head", Vector2(x, y), name.to_upper(), w, nsz, ink, 2)
		else:
			y += para(ci, nf, Vector2(x, y), name.to_upper() if m != "brassworks" else name, w, nsz, ink if m != "oldiron" else ink, 2)
		y += fs * 0.4
		if m == "oldiron":
			ci.draw_rect(Rect2(Vector2(x, y), Vector2(w, maxf(2.0, H * 0.006))), acc)
			y += fs * 0.6
		# the sales line
		var ads: Array = M.ADS.get(m, ["%s"])
		var ad: String = tr(str(ads[absi(hash(base + issue)) % ads.size()])) % name
		if m == "menagerie":
			ad = tr("See the %s!") % name + " " + ad
		var af := "ibody" if m in ["brassworks", "nimbus", "scrapworks", "menagerie"] else "body"
		y += para(ci, af, Vector2(x, y), ad, w, fs, ink if not m == "kane" else Color(ink, 0.85), 2 if m == "tenryu" else 4) + fs * (0.4 if m == "tenryu" else 0.7)
		# the stats: icon and number, two columns
		var stats: Array = [["hp", "%d" % int(d["hp"])]]
		stats.append_array(GameData.part_stats(d, true))
		stats = stats.filter(func(s): return str(s[1]) != "")
		var colw := w * 0.5
		var ih := fs * 1.15
		for i in stats.size():
			var s: Array = stats[i]
			var sx := x + (i % 2) * colw
			var sy := y + (i / 2) * ih * 1.25
			var icol: Color = ink if st["mono"] else StatIcons.color_of(str(s[0]))
			StatIcons.draw_icon(ci, str(s[0]), Rect2(Vector2(sx, sy), Vector2(ih, ih)), icol)
			tx(ci, "headb", Vector2(sx + ih * 1.25, sy + ih * 0.82), str(s[1]), fs, ink, colw - ih * 1.4)
		y += int(ceil(stats.size() / 2.0)) * ih * 1.25 + fs * 0.4
		# the grades it comes in
		var stock: Array = GameData.stock_grades(base)
		var gx := x
		var gs := maxi(5, int(fs * 0.78))
		tx(ci, "headb", Vector2(gx, y + gs), tr("COMES IN"), gs, Color(ink, 0.7))
		gx += text_w("headb", tr("COMES IN"), gs) + gs * 0.8
		for gi in range(1, 6):
			var gn := tr(GameData.GRADES[gi]).to_upper()
			var on := gi == g
			var gw := text_w("headb", gn, gs)
			if gx + gw > x + w:
				gx = x
				y += gs * 1.5
			if on:
				ci.draw_rect(Rect2(Vector2(gx - gs * 0.25, y - gs * 0.05), Vector2(gw + gs * 0.5, gs * 1.35)), acc)
			tx(ci, "headb", Vector2(gx, y + gs), gn, gs, (paper if not light_text else Color(0.05, 0.02, 0.1)) if on else Color(ink, 0.6))
			if stock.has(gi):
				ci.draw_circle(Vector2(gx + gw * 0.5, y + gs * 1.55), gs * 0.18, acc if not on else ink)
			gx += gw + gs * 0.9
		y += gs * 2.2
		# the price, at your grade
		var gid: String = GameData.graded_id(base, g)
		var price: int = GameData.price_of(gid)
		var full := int(GameData.part_def(gid).get("cost", 0))
		var psz := fz(r, 30)
		match m:
			"scrapworks":
				# biro on the photocopy, circled
				ci.draw_set_transform(Vector2(x + w * 0.05, y + psz), -0.06, Vector2.ONE)
				tx(ci, "script", Vector2.ZERO, money(price), psz, acc)
				var pw := text_w("script", money(price), psz)
				ci.draw_set_transform(Vector2(x + w * 0.05 + pw * 0.5, y + psz * 0.7), -0.06, Vector2(1.0, 0.55))
				ci.draw_arc(Vector2.ZERO, pw * 0.68, 0.3, TAU + 0.1, 40, acc, maxf(1.5, H * 0.004))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				tx(ci, "script", Vector2(x + w * 0.05 + pw * 1.25, y + psz), tr("or best offer"), int(fs * 0.85), acc)
			"brassworks":
				tx(ci, "script", Vector2(x, y + psz * 0.8), tr("Price"), int(psz * 0.7), ink)
				var pw2 := text_w("headb", money(price), psz)
				var dx := x + text_w("script", tr("Price"), int(psz * 0.7)) + fs * 0.5
				while dx < x + w - pw2 - fs * 0.5:
					ci.draw_circle(Vector2(dx, y + psz * 0.7), maxf(0.6, fs * 0.07), ink)
					dx += fs * 0.5
				tx(ci, "headb", Vector2(x + w - pw2, y + psz * 0.8), money(price), psz, ink)
			"volta":
				tx(ci, "num", Vector2(x, y + psz), money(price), int(psz * 1.3), Color(str(st["acc2"])))
			"kane":
				spaced(ci, "head", Vector2(x, y + psz * 0.8), money(price), int(psz * 0.8), acc, fs * 0.2)
			"tenryu":
				# the price shouts from a burst in the splash panel's corner
				var bc := pr.position + Vector2(pr.size.x * 0.2, pr.size.y * 0.86)
				var pts := PackedVector2Array()
				for k2 in 22:
					var a := TAU * k2 / 22.0
					pts.append(bc + Vector2(cos(a) * psz * 2.6, sin(a) * psz * 1.3) * (1.0 if k2 % 2 == 0 else 0.78))
				ci.draw_colored_polygon(pts, acc)
				pts.append(pts[0])
				ci.draw_polyline(pts, ink, maxf(2.0, H * 0.005))
				outlined(ci, "italic", bc + Vector2(-psz * 2.0, psz * 0.35), money(price), psz, Color.WHITE, ink, maxi(2, int(psz * 0.12)), psz * 4.0, HORIZONTAL_ALIGNMENT_CENTER)
			"hellfire":
				ci.draw_rect(Rect2(Vector2(x, y), Vector2(text_w("stencil", money(price), psz) + fs, psz * 1.2)), ink)
				tx(ci, "stencil", Vector2(x + fs * 0.5, y + psz), money(price), psz, paper)
			_:
				tx(ci, "headb", Vector2(x, y + psz), money(price), psz, acc if m in ["oldiron", "menagerie", "tenryu"] else ink)
		if price < full and m != "tenryu":
			var ow := text_w("headb", money(full), fs)
			var ox := x + w - ow
			tx(ci, "headb", Vector2(ox, y + psz * 0.5), money(full), fs, Color(ink, 0.6))
			ci.draw_line(Vector2(ox - 2, y + psz * 0.5 - fs * 0.3), Vector2(ox + ow + 2, y + psz * 0.5 - fs * 0.3), Color(ink, 0.8), 2.0)
			tx(ci, "headb", Vector2(ox, y + psz * 0.5 + fs * 1.1), tr("SALE") if GameData.sale_pct(m) > 0 else tr("YOUR PRICE"), int(fs * 0.8), acc)
		if m == "tenryu":
			pass
		else:
			tx(ci, "body", Vector2(x, y + psz * 1.55), tr("%s grade, the grade you fight in.") % tr(GameData.GRADES[g]), maxi(5, int(fs * 0.75)), Color(ink, 0.65), w)
		if not d1.get("shop", false) and m != "tenryu":
			tx(ci, "headb", Vector2(x, y + psz * 1.55 + fs * 1.1), tr("RARE: TURNS UP NOW AND THEN"), maxi(5, int(fs * 0.8)), acc, w)
		# page number at the foot
		var pn := "%d" % num
		tx(ci, "headb", Vector2(o.x + (W * 0.06 if not m == "tenryu" else W * 0.92), o.y + H - H * 0.035), pn, fz(r, 12), Color(ink, 0.6) if m != "volta" else Color(1, 1, 1, 0.6))

	## Stamps over the picture: OWNED, ON THE SHELF.
	func draw_over(ci: CanvasItem, r: Rect2, pg: Dictionary) -> void:
		if str(pg["t"]) != "part":
			return
		var base := str(pg["id"])
		var pr := pic_rect(r, pg)
		var H := r.size.y
		if GameData.owns_design(base):
			var c := pr.position + Vector2(pr.size.x * 0.78, pr.size.y * 0.16)
			var red := Color(0.78, 0.1, 0.1, 0.8) if m != "kane" else Color(acc, 0.85)
			ci.draw_set_transform(c, -0.25, Vector2.ONE)
			var fs := fz(r, 22)
			var w := text_w("stencil", tr("OWNED"), fs) + fs
			ci.draw_rect(Rect2(Vector2(-w * 0.5, -fs * 0.85), Vector2(w, fs * 1.3)), red, false, maxf(2.0, H * 0.006))
			tx(ci, "stencil", Vector2(-w * 0.5 + fs * 0.5, fs * 0.25), tr("OWNED"), fs, red)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not GameData.stock_grades(base).is_empty():
			var fs2 := fz(r, 13)
			var txt := tr("ON THE SHELF THIS WEEK")
			var w2 := text_w("headb", txt, fs2) + fs2
			var p := pr.position + (Vector2(pr.size.x - w2, 0) if m == "tenryu" else Vector2(0, pr.size.y - fs2 * 1.6))
			ci.draw_rect(Rect2(p, Vector2(w2, fs2 * 1.5)), acc if m != "hellfire" else ink)
			tx(ci, "headb", p + Vector2(fs2 * 0.5, fs2 * 1.1), txt, fs2, paper if not m in ["volta", "kane", "menagerie"] else Color(0.05, 0.03, 0.08))

	## The part, big, at `c` (the spinning view's origin).
	func draw_part_pic(ci: CanvasItem, c: Vector2, span: float, base: String) -> void:
		var g: int = clampi(GameData.my_grade(), 1, 5)
		var d: Dictionary = GameData.part_def(GameData.graded_id(base, g))
		if d.is_empty():
			return
		var k := str(d["kind"])
		if k in ["head", "torso", "arm", "leg"]:
			PartIcon.draw_part_at(ci, c, span, d, 1.0, 0.0, Color(0.85, 0.85, 0.9), str(st["light"]))
		elif k == "reactor":
			var col := Color(d["color"])
			var rr := span * 0.32
			ci.draw_circle(c, rr * 1.12, Color(0.12, 0.12, 0.14))
			ci.draw_circle(c, rr, col.darkened(0.55))
			ci.draw_circle(c, rr * 0.74, col)
			ci.draw_circle(c + Vector2(-rr * 0.2, -rr * 0.2), rr * 0.3, Color(1, 1, 1, 0.45))
			ci.draw_circle(c, rr * 0.22, Color(1, 1, 1, 0.9))
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * rr * 0.92, rr * 0.06, Color(0.75, 0.75, 0.8))
		else:
			PartIcon.draw_part(ci, Rect2(c - Vector2(span, span) * 0.5, Vector2(span, span)), d, 1.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ---- the "more soon" page

	func _soon(ci: CanvasItem, r: Rect2) -> void:
		var H := r.size.y
		var c := r.get_center()
		var col := ink if not m in ["volta", "kane", "menagerie"] else acc
		if m == "tenryu":
			_speed(ci, r, c, 50)
			_balloon(ci, Rect2(c - Vector2(r.size.x * 0.3, H * 0.18), Vector2(r.size.x * 0.6, H * 0.36)), tr("TO BE CONTINUED!"), fz(r, 30))
			return
		if m == "menagerie":
			_burst(ci, c, H * 0.9)
		tx(ci, str(st["title"]), Vector2(r.position.x, c.y - H * 0.04), tr("MORE ON THE WAY"), fz(r, 40), col, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		tx(ci, "body", Vector2(r.position.x, c.y + H * 0.06), tr("Our workshop is busy. New parts next season."), fz(r, 16), ink, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		Logos.draw_logo(ci, GameData.Makers.logo(m), c + Vector2(0, H * 0.22), H * 0.07)

	# ---- decorations

	func _halftone(ci: CanvasItem, b: Rect2, col: Color) -> void:
		var step := b.size.y / 22.0
		var c := b.get_center()
		var y := b.position.y + step * 0.5
		while y < b.end.y:
			var x := b.position.x + step * 0.5
			while x < b.end.x:
				var d := Vector2((x - c.x) / (b.size.x * 0.5), (y - c.y) / (b.size.y * 0.5)).length()
				var rr := step * 0.46 * clampf(1.05 - d, 0.0, 1.0)
				if rr > 0.4:
					ci.draw_circle(Vector2(x, y), rr, Color(col, 0.35))
				x += step
			y += step

	func _oval(ci: CanvasItem, b: Rect2) -> void:
		var c := b.get_center()
		var sx := b.size.x * 0.46
		var sy := b.size.y * 0.48
		ci.draw_set_transform(c, 0.0, Vector2(sx / sy, 1.0))
		ci.draw_circle(Vector2.ZERO, sy, Color(1.0, 0.95, 0.8, 0.35))
		ci.draw_arc(Vector2.ZERO, sy, 0, TAU, 64, ink, maxf(1.5, sy * 0.012))
		ci.draw_arc(Vector2.ZERO, sy * 0.96, 0, TAU, 64, ink, maxf(1.0, sy * 0.005))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# engraved hatching at the bottom of the oval
		for i in 14:
			var yy := c.y + sy * (0.45 + i * 0.035)
			var half := sx * sqrt(maxf(0.0, 1.0 - pow((yy - c.y) / sy, 2.0))) * 0.95
			ci.draw_line(Vector2(c.x - half, yy), Vector2(c.x + half, yy), Color(ink, 0.25), 1.0)

	func _scorch(ci: CanvasItem, c: Vector2, rr: float) -> void:
		for k in 6:
			ci.draw_circle(c, rr * (1.0 - k * 0.14), Color(0.15, 0.05, 0.0, 0.07))
		# a spray-painted target ring
		ci.draw_arc(c, rr * 0.82, 0, TAU, 48, Color(0, 0, 0, 0.5), rr * 0.05)

	func _sun(ci: CanvasItem, c: Vector2, rr: float) -> void:
		# a striped sun sitting on the horizon (only its top half shows)
		for i in 16:
			var a := float(i) / 16.0
			var y := c.y - rr + a * rr
			var hw := sqrt(maxf(0.0, rr * rr - pow(c.y - y, 2.0)))
			var gap := i >= 9 and (i % 2 == 1)
			if not gap:
				ci.draw_rect(Rect2(Vector2(c.x - hw, y), Vector2(hw * 2.0, rr / 16.0 + 0.5)), Color("#ffd166").lerp(Color("#ff3ea5"), a))
		ci.draw_circle(c - Vector2(0, rr * 0.5), rr * 1.3, Color(1.0, 0.4, 0.7, 0.06))

	func _dims(ci: CanvasItem, b: Rect2, wtxt: String, htxt: String) -> void:
		var lc := Color(acc, 0.85)
		var fs := maxi(5, int(b.size.y * 0.045))
		# centre lines
		var c := b.get_center()
		var y := b.position.y
		while y < b.end.y:
			ci.draw_line(Vector2(c.x, y), Vector2(c.x, minf(b.end.y, y + fs * 0.9)), Color(lc, 0.35), 1.0)
			y += fs * 1.5
		var x := b.position.x
		while x < b.end.x:
			ci.draw_line(Vector2(x, c.y), Vector2(minf(b.end.x, x + fs * 0.9), c.y), Color(lc, 0.35), 1.0)
			x += fs * 1.5
		# width under, height on the left, with arrow heads
		var by := b.end.y - fs * 0.2
		ci.draw_line(Vector2(b.position.x + b.size.x * 0.15, by), Vector2(b.end.x - b.size.x * 0.15, by), lc, 1.5)
		for s in [-1.0, 1.0]:
			var e := Vector2(c.x + s * b.size.x * 0.35, by)
			ci.draw_colored_polygon(PackedVector2Array([e, e - Vector2(s * fs * 0.6, fs * 0.25), e - Vector2(s * fs * 0.6, -fs * 0.25)]), lc)
		tx(ci, "head", Vector2(c.x - fs * 3.0, by - fs * 0.4), "W " + wtxt + " mm", fs, lc)
		var lx := b.position.x + fs * 0.4
		ci.draw_line(Vector2(lx, b.position.y + b.size.y * 0.12), Vector2(lx, b.end.y - b.size.y * 0.12), lc, 1.5)
		ci.draw_set_transform(Vector2(lx - fs * 0.3, c.y + fs * 2.5), -PI * 0.5, Vector2.ONE)
		tx(ci, "head", Vector2.ZERO, "H " + htxt + " mm", fs, lc)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _spot(ci: CanvasItem, b: Rect2) -> void:
		var c := b.get_center()
		ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - b.size.x * 0.08, b.position.y - b.size.y * 0.2), Vector2(c.x + b.size.x * 0.08, b.position.y - b.size.y * 0.2),
				Vector2(c.x + b.size.x * 0.42, b.end.y), Vector2(c.x - b.size.x * 0.42, b.end.y)]), Color(1.0, 0.95, 0.8, 0.05))
		ci.draw_set_transform(Vector2(c.x, b.end.y - b.size.y * 0.04), 0.0, Vector2(1.0, 0.16))
		ci.draw_circle(Vector2.ZERO, b.size.x * 0.42, Color(1.0, 0.92, 0.7, 0.07))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _burst(ci: CanvasItem, c: Vector2, rr: float) -> void:
		var n := 28
		for i in n:
			var a0 := TAU * i / n + t * 0.05
			var a1 := a0 + TAU / n
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rr, c + Vector2(cos(a1), sin(a1)) * rr]),
					Color(acc, 0.22) if i % 2 == 0 else Color(0.5, 0.05, 0.05, 0.25))
		for i in 7:
			var a := TAU * i / 7.0 + 0.3
			_star(ci, c + Vector2(cos(a), sin(a)) * rr * 0.42, rr * 0.03, acc)

	func _star(ci: CanvasItem, c: Vector2, rr: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * rr * (1.0 if k % 2 == 0 else 0.45))
		ci.draw_colored_polygon(pts, col)

	func _photo(ci: CanvasItem, b: Rect2) -> void:
		var c := b.get_center()
		var w := b.size.x * 0.48
		var h := b.size.y * 0.47
		var rot := -0.035
		var ax := Vector2(cos(rot), sin(rot))
		var ay := Vector2(-ax.y, ax.x)
		var outer := PackedVector2Array([c - ax * w - ay * h, c + ax * w - ay * h, c + ax * w + ay * h, c - ax * w + ay * h])
		ci.draw_colored_polygon(outer, Color(0.97, 0.97, 0.95))
		var k := 0.93
		var inner := PackedVector2Array([c - ax * w * k - ay * h * k, c + ax * w * k - ay * h * k, c + ax * w * k + ay * h * 0.8, c - ax * w * k + ay * h * 0.8])
		ci.draw_colored_polygon(inner, Color(0.62, 0.62, 0.6))
		_tape(ci, c - ay * h + ax * w * 0.1, b.size.y * 0.16, b.size.y * 0.05, 0.1)

	func _speed(ci: CanvasItem, b: Rect2, c: Vector2, n: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(m + "speed")
		var far := b.size.length()
		for i in n:
			var a := TAU * rng.randf()
			var near := rng.randf_range(0.18, 0.42) * b.size.y
			var w := rng.randf_range(0.004, 0.016)
			var p0 := c + Vector2(cos(a), sin(a)) * near
			var p1 := c + Vector2(cos(a + w), sin(a + w)) * far
			var p2 := c + Vector2(cos(a - w), sin(a - w)) * far
			var poly := Geometry2D.intersect_polygons(PackedVector2Array([p0, p1, p2]), PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]))
			for pp in poly:
				ci.draw_colored_polygon(pp, Color(0, 0, 0, 0.85))

	func _screentone(ci: CanvasItem, b: Rect2, dense: float) -> void:
		var step := maxf(3.0, b.size.y / 40.0)
		var y := b.position.y
		var row := 0
		while y < b.end.y:
			var x := b.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
			while x < b.end.x:
				ci.draw_circle(Vector2(x, y), step * 0.18 * dense, Color(0, 0, 0, 0.75))
				x += step
			y += step * 0.866
			row += 1

	## A speech balloon (spiky when it shouts) with its words.
	func _balloon(ci: CanvasItem, b: Rect2, s: String, fs: int, shout: bool = false, tail: Vector2 = Vector2.INF) -> void:
		var c := b.get_center()
		var pts := PackedVector2Array()
		var n := 26 if shout else 40
		for k in n:
			var a := TAU * k / n
			var f := (1.0 if k % 2 == 0 else 0.84) if shout else 1.0
			pts.append(c + Vector2(cos(a) * b.size.x * 0.5, sin(a) * b.size.y * 0.5) * f)
		if tail != Vector2.INF:
			var dir := (tail - c).normalized()
			var side := Vector2(-dir.y, dir.x) * b.size.y * 0.1
			var root := c + dir * b.size.y * 0.35
			ci.draw_colored_polygon(PackedVector2Array([root + side, tail, root - side]), Color.WHITE)
			ci.draw_line(root + side, tail, ink, 2.0)
			ci.draw_line(root - side, tail, ink, 2.0)
		ci.draw_colored_polygon(pts, Color.WHITE)
		pts.append(pts[0])
		ci.draw_polyline(pts, ink, maxf(2.0, b.size.y * 0.025))
		var f := font("italic" if shout else "headb")
		var inner := b.size.x * (0.62 if shout else 0.74)
		var hh := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, inner, fs, 4).y
		ci.draw_multiline_string(f, Vector2(c.x - inner * 0.5, c.y - hh * 0.5 + f.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_CENTER, inner, fs, 4, ink)

	## The manga page: a big splash panel on the right (read first), the pilot shouting the part's name
	## top left, and the specs box under it.
	func _tenryu_panels(ci: CanvasItem, r: Rect2, pr: Rect2, trc: Rect2, d: Dictionary) -> void:
		var H := r.size.y
		var bw := maxf(2.5, H * 0.008)
		ci.draw_rect(pr, Color.WHITE)
		_speed(ci, pr, pr.get_center(), 70)
		# screentone in the splash's corners
		_screentone(ci, Rect2(pr.position, Vector2(pr.size.x * 0.22, pr.size.y * 0.2)), 1.0)
		_screentone(ci, Rect2(pr.end - Vector2(pr.size.x * 0.22, pr.size.y * 0.2), Vector2(pr.size.x * 0.22, pr.size.y * 0.2)), 1.0)
		ci.draw_rect(pr, ink, false, bw)
		# the pilot panel
		var pad := H * 0.07
		var pp := Rect2(Vector2(r.position.x + pad, r.position.y + pad), Vector2(pr.position.x - r.position.x - pad * 1.4, r.size.y * 0.39 - pad - pad * 0.55))
		ci.draw_rect(pp, Color.WHITE)
		_screentone(ci, Rect2(pp.position + Vector2(0, pp.size.y * 0.6), Vector2(pp.size.x, pp.size.y * 0.4)), 0.7)
		var face := pp.position + Vector2(pp.size.x * 0.24, pp.size.y * 0.62)
		var was: String = PilotArt.light
		PilotArt.light = ""
		PilotArt.draw_head(ci, face, pp.size.y * 0.24, GameData.pilot_look, 1.0, 1.0)
		PilotArt.light = was
		var name := GameData.Makers.ad_name(d).to_upper() + "!!"
		_balloon(ci, Rect2(pp.position + Vector2(pp.size.x * 0.4, pp.size.y * 0.06), Vector2(pp.size.x * 0.58, pp.size.y * 0.62)), name, fz(r, 17), true, face + Vector2(pp.size.y * 0.18, -pp.size.y * 0.1))
		ci.draw_rect(pp, ink, false, bw)

	# ---- chrome type (Volta)

	func _chrome(ci: CanvasItem, pos: Vector2, s: String, sz: int) -> void:
		var f := font("italic")
		ci.draw_string(f, pos + Vector2(3, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#2b0a3d"))
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, maxi(2, int(sz * 0.06)), Color(str(st["acc2"])))
		ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#dfe9ff"))
		ci.draw_string(f, pos - Vector2(0, sz * 0.04), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, 0.5))
		ci.draw_line(pos + Vector2(0, -sz * 0.32), pos + Vector2(text_w("italic", s, sz), -sz * 0.32), Color(0.4, 0.95, 1.0, 0.55), maxf(1.0, sz * 0.04))

	func _chrome_wrap(ci: CanvasItem, top: Vector2, s: String, w: float, sz: int) -> float:
		var words := s.split(" ")
		var line := ""
		var y := top.y
		for wd in words:
			var test := wd if line == "" else line + " " + wd
			if text_w("italic", test, sz) > w and line != "":
				_chrome(ci, Vector2(top.x, y + sz), line, sz)
				y += sz * 1.05
				line = wd
			else:
				line = test
		if line != "":
			_chrome(ci, Vector2(top.x, y + sz), line, sz)
			y += sz * 1.15
		return y - top.y
