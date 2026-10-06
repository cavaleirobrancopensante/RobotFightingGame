extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const UI = preload("res://ui.gd")
## Settings: screen shake, touch button size, CPU difficulty, delete save.

const SIZE_NAMES := ["Small", "Medium", "Large"]
const DIFF_NAMES := ["Easy", "Normal", "Hard"]

var sound_button: Button
var music_button: Button
var shake_button: Button
var size_button: Button
var diff_button: Button
var delete_button: Button
var team_button: Button
var battery_button: Button
var errors_button: Button
var log_overlay: Control
var copy_button: Button
var start_money_button: Button
var coach_button: Button
const COACH_NAMES := ["OFF", "A little", "Normal", "Lots (easier)"]
var living_button: Button
var pecking_button: Button
var edges_button: Button
const EDGE_NAMES := ["OFF", "Small", "Medium", "Large"]   # dark bars down the sides, for phone buttons that never hide


var diff_overlay: Control
var reset_button: Button
var reset_armed := false


## A little flag to pick the language.
class Flag extends Button:
	var lang := "en"
	var selected := false

	func _draw() -> void:
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		match lang:
			"en":   # USA: stripes and a blue canton with stars
				for k in 7:
					draw_rect(Rect2(r.position.x, r.position.y + k * r.size.y / 7.0, r.size.x, r.size.y / 7.0 + 0.5), Color(0.7, 0.13, 0.2) if k % 2 == 0 else Color.WHITE)
				var c := Rect2(r.position, Vector2(r.size.x * 0.42, r.size.y * 4.0 / 7.0))
				draw_rect(c, Color(0.24, 0.23, 0.43))
				for y in 3:
					for x in 4:
						draw_circle(c.position + Vector2((x + 0.5) * c.size.x / 4.0, (y + 0.5) * c.size.y / 3.0), 1.4, Color.WHITE)
			"pt":   # Brazil: green, yellow diamond, blue globe
				draw_rect(r, Color(0.0, 0.6, 0.29))
				var m := r.get_center()
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 5, m.y), Vector2(m.x, r.position.y + 4),
						Vector2(r.end.x - 5, m.y), Vector2(m.x, r.end.y - 4)]), Color(1.0, 0.87, 0.0))
				draw_circle(m, r.size.y * 0.26, Color(0.0, 0.15, 0.5))
				draw_line(m + Vector2(-r.size.y * 0.25, -1), m + Vector2(r.size.y * 0.25, 2), Color.WHITE, 1.5)
			"es":   # Spain: red, yellow, red
				draw_rect(r, Color(0.78, 0.07, 0.11))
				draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.25, r.size.x, r.size.y * 0.5), Color(1.0, 0.77, 0.0))
		draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)
		if selected:
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 0.85, 0.3), false, 3.0)


func _ready() -> void:
	Sfx.music("menu")
	UI.background(self)
	var m := UI.margin(self, 24)
	var center := CenterContainer.new()
	m.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var title := UI.label("SETTINGS", 30, Color(1.0, 0.45, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	# language flags (also on the main menu, where everyone sees them first)
	for lang in ["en", "pt", "es"]:
		var f := Flag.new()
		f.lang = lang
		f.selected = GameData.settings.get("lang", "en") == lang
		f.custom_minimum_size = Vector2(66, 46)
		f.flat = true
		f.focus_mode = Control.FOCUS_NONE
		f.pressed.connect(_on_lang.bind(lang))
		head.add_child(f)

	# two columns so everything fits on a phone screen
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	sound_button = UI.button("", _on_sound, 19, Vector2(470, 50))
	music_button = UI.button("", _on_music, 19, Vector2(470, 50))
	shake_button = UI.button("", _on_shake, 19, Vector2(470, 50))
	size_button = UI.button("", _on_size, 19, Vector2(470, 50))
	delete_button = UI.button("", _on_walkin, 19, Vector2(470, 50))   # (save files live under Load Game)
	team_button = UI.button("", _on_team, 19, Vector2(470, 50))
	battery_button = UI.button("", _on_battery, 19, Vector2(470, 50))
	errors_button = UI.button("", _on_errors, 19, Vector2(470, 50))
	reset_button = UI.button("", _on_reset, 19, Vector2(470, 50))
	edges_button = UI.button("", _on_edges, 19, Vector2(470, 50))
	for b in [sound_button, music_button, shake_button, battery_button, size_button, edges_button,
			UI.button("Edit controls (move & resize)", _on_controls, 19, Vector2(470, 50)), team_button,
			UI.button("Difficulty...", _on_difficulty, 19, Vector2(470, 50)), delete_button, errors_button, reset_button]:
		grid.add_child(b)
	grid.add_child(UI.button("Back", _on_back, 19, Vector2(470, 50)))
	refresh()


func refresh() -> void:
	var s := GameData.settings
	sound_button.text = tr("Sound effects: %s") % tr("ON" if s["sound"] else "OFF")
	music_button.text = tr("Music: %s") % tr("ON" if s["music"] else "OFF")
	shake_button.text = tr("Screen shake: %s") % tr("ON" if s["shake"] else "OFF")
	size_button.text = tr("Touch buttons: %s") % tr(SIZE_NAMES[s["button_size"]])
	edges_button.text = tr("Screen edges: %s") % tr(EDGE_NAMES[clampi(int(s.get("edges", 0)), 0, EDGE_NAMES.size() - 1)])
	var n := GameData.error_count()
	errors_button.text = tr("Error log (%d)") % n if n > 0 else tr("Error log (no errors)")
	battery_button.text = tr("Battery saver: %s") % tr("ON (30 fps)" if s.get("battery_saver", false) else "OFF (60 fps)")
	team_button.text = tr("Team controls: %s") % tr("SPLIT (a pad per robot)" if s.get("team_controls", "linked") == "split" else "LINKED (one pad for all)")
	delete_button.text = tr("Walk-in show: %s") % tr("OFF (straight to the countdown)" if s.get("skip_intros", false) else "ON")
	reset_button.text = tr("Sure? Tap again to reset") if reset_armed else tr("Restore default settings")
	if diff_button:
		diff_button.text = tr("CPU difficulty: %s") % tr(DIFF_NAMES[s["difficulty"]])
		coach_button.text = tr("Gus's coaching: %s") % tr(COACH_NAMES[clampi(int(s.get("coaching", 2)), 0, 3)])
		start_money_button.text = tr("Starting money: %s (new games)") % GameData.money_text(int(s.get("start_money", GameData.START_MONEY)))
		var lc := int(s.get("living_cost", GameData.LIVING_COST))
		living_button.text = tr("Rent & food: %s") % (tr("none") if lc == 0 else tr("$%d a month") % lc)
		var pk: Dictionary = GameData.PECKING[clampi(int(s.get("pecking", 1)), 0, GameData.PECKING.size() - 1)]
		pecking_button.text = tr("Pecking Order: %s (x%.1f a grade)") % [tr(pk["name"]), float(pk["k"])]


func _on_lang(lang: String) -> void:
	GameData.set_language(lang)
	GameData.save_settings()
	Sfx.play("click")
	get_tree().reload_current_scene()   # rebuild everything in the new language


func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		Sfx.play("error")
		refresh()
		return
	reset_armed = false
	GameData.reset_settings()
	Sfx.refresh_music()
	Sfx.play("buy")
	get_tree().reload_current_scene()


## Every difficulty setting in one place: the CPU, Gus's coaching, and the money.
func _on_difficulty() -> void:
	Sfx.play("click")
	diff_overlay = ColorRect.new()
	(diff_overlay as ColorRect).color = Color(0.06, 0.06, 0.09, 0.97)
	diff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	diff_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(diff_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	diff_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)
	var t := UI.label("DIFFICULTY", 28, Color(1.0, 0.45, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var note := UI.label("Fighting and money are separate: make the fights easy and the money hard, or the other way round.", 14, Color(0.7, 0.7, 0.78))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	col.add_child(note)
	diff_button = UI.button("", _on_diff, 19, Vector2(560, 52))
	coach_button = UI.button("", _on_coach, 19, Vector2(560, 52))
	start_money_button = UI.button("", _on_start_money, 19, Vector2(560, 52))
	living_button = UI.button("", _on_living, 19, Vector2(560, 52))
	pecking_button = UI.button("", _on_pecking, 19, Vector2(560, 52))
	for b in [diff_button, coach_button, start_money_button, living_button, pecking_button]:
		col.add_child(b)
	var pnote := UI.label("Pecking Order: how much tougher and harder hitting each part grade is. Underdog lets a good pilot punch above their grade; Brutal means a robot two grades up flattens you in seconds.", 13, Color(0.65, 0.65, 0.72))
	pnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pnote.custom_minimum_size = Vector2(560, 0)
	col.add_child(pnote)
	col.add_child(UI.button("Done", _on_close_difficulty, 19, Vector2(560, 52)))
	refresh()


func _on_close_difficulty() -> void:
	if diff_overlay:
		diff_overlay.queue_free()
		diff_overlay = null
		diff_button = null
	refresh()


func _on_sound() -> void:
	GameData.settings["sound"] = not GameData.settings["sound"]
	GameData.save_settings()
	refresh()
	Sfx.play("buy")


func _on_music() -> void:
	GameData.settings["music"] = not GameData.settings["music"]
	GameData.save_settings()
	Sfx.refresh_music()
	refresh()


func _on_shake() -> void:
	GameData.settings["shake"] = not GameData.settings["shake"]
	GameData.save_settings()
	refresh()


func _on_size() -> void:
	GameData.settings["button_size"] = (GameData.settings["button_size"] + 1) % SIZE_NAMES.size()
	GameData.save_settings()
	refresh()


## Every error the game has hit, with a one-tap "Copy all" so it can be pasted anywhere.
func _on_errors() -> void:
	Sfx.play("click")
	GameData.flush_error_log()
	log_overlay = ColorRect.new()
	(log_overlay as ColorRect).color = Color(0.06, 0.06, 0.09, 1.0)
	log_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	log_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(log_overlay)
	var m := UI.margin(log_overlay, 16)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var title := UI.label("ERROR LOG", 24, Color(1.0, 0.45, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	copy_button = UI.button("Copy all", _on_copy_errors, 18, Vector2(150, 48))
	top.add_child(copy_button)
	top.add_child(UI.button("Clear", _on_clear_errors, 18, Vector2(110, 48)))
	top.add_child(UI.button("Close", _on_close_errors, 18, Vector2(110, 48)))
	var box := TextEdit.new()
	box.text = GameData.error_log_text()
	box.editable = false
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14)
	sb.set_content_margin_all(10)
	box.add_theme_stylebox_override("normal", sb)
	box.add_theme_stylebox_override("read_only", sb)
	col.add_child(box)


func _on_copy_errors() -> void:
	DisplayServer.clipboard_set(GameData.error_log_text())
	Sfx.play("buy")
	copy_button.text = "Copied!"


func _on_clear_errors() -> void:
	GameData.clear_error_log()
	_on_close_errors()
	refresh()


func _on_close_errors() -> void:
	if log_overlay:
		log_overlay.queue_free()
		log_overlay = null
	refresh()


func _on_battery() -> void:
	GameData.settings["battery_saver"] = not GameData.settings.get("battery_saver", false)
	GameData.apply_performance()
	GameData.save_settings()
	refresh()
	Sfx.play("click")


func _on_team() -> void:
	GameData.settings["team_controls"] = "linked" if GameData.settings.get("team_controls", "linked") == "split" else "split"
	GameData.save_settings()
	refresh()
	Sfx.play("click")


func _on_controls() -> void:
	Sfx.play("click")
	get_tree().change_scene_to_file("res://controls_editor.tscn")


func _on_diff() -> void:
	GameData.settings["difficulty"] = (GameData.settings["difficulty"] + 1) % DIFF_NAMES.size()
	GameData.save_settings()
	refresh()


func _on_coach() -> void:
	GameData.settings["coaching"] = (int(GameData.settings.get("coaching", 2)) + 1) % COACH_NAMES.size()
	GameData.save_settings()
	refresh()


func _on_start_money() -> void:
	var opts: Array = GameData.START_MONEY_OPTIONS
	var i := opts.find(int(GameData.settings.get("start_money", GameData.START_MONEY)))
	GameData.settings["start_money"] = opts[(i + 1) % opts.size()]
	GameData.save_settings()
	refresh()


func _on_edges() -> void:
	GameData.settings["edges"] = (int(GameData.settings.get("edges", 0)) + 1) % EDGE_NAMES.size()
	GameData.save_settings()
	Loading.apply_edges()
	refresh()


func _on_pecking() -> void:
	GameData.set_pecking((int(GameData.settings.get("pecking", 1)) + 1) % GameData.PECKING.size())
	GameData.save_settings()
	refresh()


func _on_living() -> void:
	var opts: Array = GameData.LIVING_COST_OPTIONS
	var i := opts.find(int(GameData.settings.get("living_cost", GameData.LIVING_COST)))
	GameData.settings["living_cost"] = opts[(i + 1) % opts.size()]
	GameData.save_settings()
	refresh()


func _on_walkin() -> void:
	GameData.settings["skip_intros"] = not GameData.settings.get("skip_intros", false)
	GameData.save_settings()
	refresh()


func _on_delete() -> void:
	GameData.slot_mode = "load"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
