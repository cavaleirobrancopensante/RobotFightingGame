extends Control
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

	sound_button = UI.button("", _on_sound, 20, Vector2(0, 42))
	col.add_child(sound_button)
	music_button = UI.button("", _on_music, 20, Vector2(0, 42))
	col.add_child(music_button)
	shake_button = UI.button("", _on_shake, 20, Vector2(0, 42))
	size_button = UI.button("", _on_size, 20, Vector2(0, 42))
	diff_button = UI.button("", _on_diff, 20, Vector2(0, 42))
	delete_button = UI.button("", _on_delete, 20, Vector2(0, 42))
	col.add_child(shake_button)
	col.add_child(size_button)
	col.add_child(UI.button("Edit controls (move & resize buttons)", _on_controls, 20, Vector2(0, 42)))
	team_button = UI.button("", _on_team, 20, Vector2(0, 42))
	col.add_child(team_button)
	col.add_child(diff_button)
	col.add_child(delete_button)
	col.add_child(UI.button("Back", _on_back, 20, Vector2(0, 42)))
	refresh()


func refresh() -> void:
	var s := GameData.settings
	sound_button.text = "Sound effects: %s" % ("ON" if s["sound"] else "OFF")
	music_button.text = "Music: %s" % ("ON" if s["music"] else "OFF")
	shake_button.text = "Screen shake: %s" % ("ON" if s["shake"] else "OFF")
	size_button.text = "Touch buttons: %s" % SIZE_NAMES[s["button_size"]]
	diff_button.text = "CPU difficulty: %s" % DIFF_NAMES[s["difficulty"]]
	team_button.text = "Team controls: %s" % ("SPLIT (a pad per robot)" if s.get("team_controls", "split") == "split" else "LINKED (one pad for all)")
	delete_button.text = "Manage save files"


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


func _on_delete() -> void:
	GameData.slot_mode = "load"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
