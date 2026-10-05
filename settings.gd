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

	var title := UI.label("SETTINGS", 30, Color(1.0, 0.45, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

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
	diff_button = UI.button("", _on_diff, 19, Vector2(470, 50))
	delete_button = UI.button("", _on_delete, 19, Vector2(470, 50))
	team_button = UI.button("", _on_team, 19, Vector2(470, 50))
	battery_button = UI.button("", _on_battery, 19, Vector2(470, 50))
	for b in [sound_button, music_button, shake_button, battery_button, size_button,
			UI.button("Edit controls (move & resize)", _on_controls, 19, Vector2(470, 50)), team_button, diff_button]:
		grid.add_child(b)
	grid.add_child(delete_button)
	# money difficulty: how deep in the hole you start, and what living costs each month
	start_money_button = UI.button("", _on_start_money, 19, Vector2(470, 50))
	living_button = UI.button("", _on_living, 19, Vector2(470, 50))
	coach_button = UI.button("", _on_coach, 19, Vector2(470, 50))
	grid.add_child(coach_button)
	grid.add_child(start_money_button)
	grid.add_child(living_button)
	errors_button = UI.button("", _on_errors, 19, Vector2(470, 50))
	grid.add_child(errors_button)
	grid.add_child(UI.button("Back", _on_back, 19, Vector2(470, 50)))
	refresh()


func refresh() -> void:
	var s := GameData.settings
	sound_button.text = "Sound effects: %s" % ("ON" if s["sound"] else "OFF")
	music_button.text = "Music: %s" % ("ON" if s["music"] else "OFF")
	shake_button.text = "Screen shake: %s" % ("ON" if s["shake"] else "OFF")
	size_button.text = "Touch buttons: %s" % SIZE_NAMES[s["button_size"]]
	diff_button.text = "CPU difficulty: %s" % DIFF_NAMES[s["difficulty"]]
	var n := GameData.error_count()
	errors_button.text = "Error log (%d)" % n if n > 0 else "Error log (no errors)"
	battery_button.text = "Battery saver: %s" % ("ON (30 fps)" if s.get("battery_saver", false) else "OFF (60 fps)")
	team_button.text = "Team controls: %s" % ("SPLIT (a pad per robot)" if s.get("team_controls", "split") == "split" else "LINKED (one pad for all)")
	delete_button.text = "Manage save files"
	coach_button.text = "Gus's coaching: %s" % COACH_NAMES[clampi(int(s.get("coaching", 2)), 0, 3)]
	start_money_button.text = "Starting money: %s (new games)" % GameData.money_text(int(s.get("start_money", GameData.START_MONEY)))
	var lc := int(s.get("living_cost", GameData.LIVING_COST))
	living_button.text = "Rent & food: %s" % ("none" if lc == 0 else "$%d a month" % lc)


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
	GameData.settings["team_controls"] = "linked" if GameData.settings.get("team_controls", "split") == "split" else "split"
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


func _on_living() -> void:
	var opts: Array = GameData.LIVING_COST_OPTIONS
	var i := opts.find(int(GameData.settings.get("living_cost", GameData.LIVING_COST)))
	GameData.settings["living_cost"] = opts[(i + 1) % opts.size()]
	GameData.save_settings()
	refresh()


func _on_delete() -> void:
	GameData.slot_mode = "load"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
