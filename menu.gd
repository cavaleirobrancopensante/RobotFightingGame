extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotPreview = preload("res://robot_preview.gd")
const RobotArt = preload("res://robot_art.gd")
const UI = preload("res://ui.gd")
const GUI = preload("res://garage_ui.gd")
const Arena = preload("res://arena.gd")
const Scoreboard = preload("res://scoreboard.gd")
## Main menu, dressed like the game: the Kane Championship Arena behind it, two robots squaring
## off in the ring, the title on the arena's boards ("ROBOT" in the Championship's red LED dots,
## "FIGHTING" on the Regional's flip tiles), and every button from a different corner of the game:
##   Quick Fight - Regional / cups flip tiles      New Game - Championship red LED dots
##   Load Game   - Gus's garage (stencil, hazard)   Settings - a riveted workshop plate
##   Quit Game   - a crooked plank sign from the Scrap Heap Ring (quitting's for the scrap heap)

const ARENA_ID := "champ_arena"
const CROWD_ID := "champ_fans"

var new_button: Button
var msg: Label


## The arena, the ring and the two robots, filling the screen behind the menu.
class ArenaBackdrop extends Control:
	var crowd: Array = []
	var looks: Array = []
	var t := 0.0
	var _rt := 0.0

	func _process(delta: float) -> void:
		t += delta
		_rt -= delta
		if _rt <= 0.0:
			_rt = 1.0 / 24.0
			queue_redraw()

	func _draw() -> void:
		var screen := size
		var floor_y := screen.y * 0.8
		if crowd.is_empty():
			crowd = Arena.make_crowd(CROWD_ID, screen)
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.07, 0.11))
		Arena.draw_backdrop(self, ARENA_ID, screen, floor_y, t, Vector2.ZERO)
		Arena.draw_crowd(self, crowd, CROWD_ID, screen, t, 0.6 + 0.4 * sin(t * 0.7), Vector2.ZERO)
		var ar: Dictionary = Arena.ARENAS[ARENA_ID]
		var lc := Color(ar["light"])
		for k in 14:
			draw_circle(Vector2(screen.x * (k + 0.5) / 14.0, screen.y * 0.21), 5.0, Color(lc, 0.45))
		Arena.draw_floor(self, ARENA_ID, screen, floor_y, t, Vector2.ZERO)
		# the ring: corner posts and three ropes
		var wl := screen.x * 0.07
		var wr := screen.x * 0.93
		for x in [wl, wr]:
			draw_rect(Rect2(x - 6, floor_y - 190, 12, 190), Color(ar["post"]))
		for k in 3:
			var y := floor_y - 70.0 - k * 50.0
			draw_line(Vector2(wl, y), Vector2(wr, y + sin(t + k) * 1.5), Color(ar["rope"]), 4.0)
		# spotlights sweeping the ring
		for k in 2:
			var cx := screen.x * (0.5 + 0.3 * sin(t * 0.4 + k * PI))
			draw_colored_polygon(PackedVector2Array([Vector2(screen.x * (0.3 + 0.4 * k), 0), Vector2(cx - 90, floor_y), Vector2(cx + 90, floor_y)]),
					Color(lc, 0.06))
		# two robots squaring off
		for k in looks.size():
			var g := RobotArt.geom(looks[k])
			var tall: float = -(g["head"] as Rect2).position.y + 30.0
			var sc: float = screen.y * 0.5 / tall / float(looks[k].get("scale", 1.0))
			RobotArt.draw(self, Vector2(screen.x * (0.17 if k == 0 else 0.83), floor_y + 6), looks[k],
					{"scale": sc, "facing": 1 if k == 0 else -1, "time": t + k})
		# darken the middle a touch so the menu reads
		draw_rect(Rect2(screen.x * 0.3, 0, screen.x * 0.4, screen.y), Color(0, 0, 0, 0.35))


## The title: ROBOT on a red dot-matrix board, FIGHTING on split-flap tiles.
class TitleArt extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		# One line: ROBOT on the Championship's red LED board, FIGHTING on the Regional's flip
		# tiles beside it, same height. Wider than the button column, so it draws past its edges.
		var p := 8.0
		var h := 7 * p + 22
		var text_w := (5 * 6 - 1) * p
		var board_w := text_w + 32
		var tiles_w := 400.0
		var gap := 18.0
		var x0 := (size.x - (board_w + gap + tiles_w)) * 0.5
		var y0 := (size.y - h) * 0.5
		var board := Rect2(x0, y0, board_w, h)
		draw_rect(board.grow(4), Color(0.1, 0.1, 0.11))
		draw_rect(board.grow(1), Color(0.02, 0.02, 0.02))
		draw_rect(board, Color(0.05, 0.01, 0.01))
		var inner := Rect2(board.position + Vector2(12, 11), Vector2(board.size.x - 24, 7 * p))
		Scoreboard.dot_grid(self, Rect2(inner.position - Vector2(4, 0), inner.size + Vector2(8, 0)), p, 7)
		var pulse := 0.85 + 0.15 * sin(t * 3.0)
		Scoreboard.dot_text(self, "ROBOT", board.position.x + 16, inner.position.y, p, inner.position.x - p, inner.end.x + p,
				Color(1.0, 0.24 * pulse, 0.14 * pulse))
		var tiles := Rect2(board.end.x + gap, y0, tiles_w, h)
		draw_rect(tiles.grow(4), Color(0.38, 0.39, 0.41))
		draw_rect(tiles.grow(2), Color(0.04, 0.04, 0.05))
		Scoreboard.flap_row(self, tiles.grow(-2), "FIGHTING", GUI.headb(), Color(1, 1, 1))


## A menu button drawn in one of the game's styles (see the top of the file).
class ThemedButton extends Button:
	var look := "plate"
	var caption := ""
	var t := 0.0

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _process(delta: float) -> void:
		t += delta
		if look == "dots" or look == "scrap" or is_hovered():
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() and not disabled
		var down := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		if down:
			r.position.y += 2
		var dim := 0.45 if disabled else 1.0
		var label := caption.to_upper()
		match look:
			"flip":
				draw_rect(r, Color(0.38, 0.39, 0.41))
				draw_rect(r.grow(-2), Color(0.04, 0.04, 0.05))
				var ink := Color(1.0, 0.85, 0.35) if hot else Color(1, 1, 1)
				Scoreboard.flap_row(self, r.grow(-6), label, GUI.headb(), Color(ink, dim))
			"dots":
				draw_rect(r, Color(0.1, 0.1, 0.11))
				draw_rect(r.grow(-2), Color(0.05, 0.01, 0.01))
				var lit := Color(1.0, 0.55, 0.15) if hot else Color(1.0, 0.24, 0.14)
				var area := r.grow(-8)
				var cols := label.length() * 6 - 1
				var p := minf(area.size.y / 7.0, area.size.x / cols)
				var tx := area.position.x + (area.size.x - cols * p) * 0.5
				var ty := area.position.y + (area.size.y - 7 * p) * 0.5
				Scoreboard.dot_grid(self, Rect2(area.position.x, ty, area.size.x, 7 * p), p, 7)
				Scoreboard.dot_text(self, label, tx, ty, p, area.position.x, area.end.x, Color(lit, dim))
			"garage":
				# hazard frame, yellow stencil plate (like the garage's FIGHT button)
				draw_rect(r, Color(0.08, 0.08, 0.08))
				var x := -r.size.y
				while x < r.size.x:
					var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 10, r.end.y), Vector2(x + 10 + r.size.y, r.position.y), Vector2(x + r.size.y, r.position.y)])
					for i in pts.size():
						pts[i].x = clampf(pts[i].x, 0.0, r.size.x)
					draw_colored_polygon(pts, Color(0.95, 0.76, 0.19, dim))
					x += 20.0
				var inner := r.grow(-5)
				draw_rect(inner, Color(0.98, 0.82, 0.25, dim) if hot else Color(0.95, 0.76, 0.19, dim))
				_center_text(inner, label, GUI.stencil(), Color(0.08, 0.08, 0.08))
			"plate":
				# a riveted steel plate from Gus's workshop
				draw_rect(r, Color(0.32, 0.34, 0.38, dim))
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), Color(0.4, 0.42, 0.46, dim))
				draw_rect(r, Color(0.18, 0.19, 0.22), false, 2.0)
				for c in [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8), r.end - Vector2(8, 8)]:
					draw_circle(c, 3.0, Color(0.62, 0.64, 0.68))
					draw_circle(c + Vector2(-0.8, -0.8), 1.2, Color(0.85, 0.86, 0.9))
				_center_text(r, label, GUI.headb(), Color(1.0, 0.85, 0.35) if hot else Color(0.95, 0.95, 0.97))
			"scrap":
				# a crooked plank sign on rusty chains - the Scrap Heap Ring's way of saying goodbye
				var c := r.get_center()
				var swing := sin(t * 1.6) * 0.012 + (0.03 if hot else 0.0)
				draw_set_transform(c, -0.05 + swing, Vector2.ONE)
				var b := Rect2(-r.size.x * 0.46, -r.size.y * 0.36, r.size.x * 0.92, r.size.y * 0.78)
				for k in 3:
					var plank := Rect2(b.position.x, b.position.y + k * b.size.y / 3.0, b.size.x + (k - 1) * 6.0, b.size.y / 3.0 - 2)
					draw_rect(plank, Color(0.42, 0.29, 0.17).darkened(k * 0.08))
					draw_line(plank.position + Vector2(10, plank.size.y * 0.5), plank.position + Vector2(plank.size.x * 0.4, plank.size.y * 0.45), Color(0.3, 0.2, 0.1), 1.0)
				for nx in [b.position.x + 8, b.end.x - 8]:
					for ny in [b.position.y + 6, b.end.y - 6]:
						draw_circle(Vector2(nx, ny), 2.2, Color(0.25, 0.22, 0.2))
				draw_rect(Rect2(b.end.x - 30, b.position.y + 4, 18, 10), Color(0.55, 0.25, 0.1, 0.6))   # rust patch
				var f := GUI.headb()
				var fs := 22
				var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var ink := Color(1.0, 0.95, 0.85) if hot else Color(0.92, 0.88, 0.8)
				draw_string(f, Vector2(-tw * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, dim))
				draw_string(f, Vector2(-tw * 0.5 + 1, fs * 0.36 + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, dim * 0.35))   # brush smudge
				# the chains it hangs from
				for cx in [b.position.x + 20, b.end.x - 20]:
					for k in 3:
						draw_arc(Vector2(cx, b.position.y - 4 - k * 7), 3.0, 0, TAU, 8, Color(0.5, 0.4, 0.3), 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _center_text(r: Rect2, text: String, f: Font, col: Color) -> void:
		var fs := 22
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.get_center().y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func themed(text: String, look: String, cb: Callable) -> ThemedButton:
	var b := ThemedButton.new()
	b.look = look
	b.caption = tr(text)
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(func(): Sfx.play("click"))
	b.pressed.connect(cb)
	return b


func _ready() -> void:
	Sfx.music("menu")
	var bg := ArenaBackdrop.new()
	bg.looks = [random_look(), random_look()]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var m := UI.margin(self, 18)
	var row := HBoxContainer.new()
	m.add_child(row)
	var l := Control.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(460, 0)
	row.add_child(col)

	var title := TitleArt.new()
	title.custom_minimum_size = Vector2(460, 96)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap)

	col.add_child(themed("Quick Fight", "flip", _on_quick))
	var nb := themed("New Game", "dots", _on_new)
	new_button = nb
	col.add_child(nb)
	var load_button := themed("Load Game", "garage", _on_load)
	load_button.disabled = not GameData.any_save()
	col.add_child(load_button)
	col.add_child(themed("Settings", "plate", _on_settings))
	col.add_child(themed("Quit Game", "scrap", _on_quit))
	var ver := GUI.text("Salgadoido's version " + GameData.VERSION, 14, Color(0.75, 0.75, 0.82), "body")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ver.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	col.add_child(ver)

	msg = UI.label("", 22, Color(1.0, 0.8, 0.4))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)

	var r := Control.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(r)


## Two random robots, one fight, nothing saved.
func _on_quick() -> void:
	GameData.start_quick_fight()
	get_tree().change_scene_to_file("res://fight.tscn")


func _on_new() -> void:
	GameData.slot_mode = "new"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_load() -> void:
	GameData.slot_mode = "load"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")


func _on_quit() -> void:
	get_tree().quit()


## A freshly built random robot every time the menu opens.
func random_look() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bot := GameData.random_bot(rng, rng.randf_range(300.0, 4000.0), rng.randf_range(0.0, 4.0))
	return GameData.look_from_spec(GameData.opponent_spec_from(bot, 1.0))
