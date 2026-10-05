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


func _ready() -> void:
	Sfx.music("menu")
	UI.background(self)
	var m := UI.margin(self, 24)
	var center := CenterContainer.new()
	m.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)

	var title := UI.label("SETTINGS", 36, Color(1.0, 0.45, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	sound_button = UI.button("", _on_sound, 22, Vector2(0, 48))
	col.add_child(sound_button)
	music_button = UI.button("", _on_music, 22, Vector2(0, 48))
	col.add_child(music_button)
	shake_button = UI.button("", _on_shake, 22, Vector2(0, 48))
	size_button = UI.button("", _on_size, 22, Vector2(0, 48))
	diff_button = UI.button("", _on_diff, 22, Vector2(0, 48))
	delete_button = UI.button("", _on_delete, 22, Vector2(0, 48))
	col.add_child(shake_button)
	col.add_child(size_button)
	col.add_child(diff_button)
	col.add_child(delete_button)
	col.add_child(UI.button("Back", _on_back, 22, Vector2(0, 48)))
	refresh()


func refresh() -> void:
	var s := GameData.settings
	sound_button.text = "Sound effects: %s" % ("ON" if s["sound"] else "OFF")
	music_button.text = "Music: %s" % ("ON" if s["music"] else "OFF")
	shake_button.text = "Screen shake: %s" % ("ON" if s["shake"] else "OFF")
	size_button.text = "Touch buttons: %s" % SIZE_NAMES[s["button_size"]]
	diff_button.text = "CPU difficulty: %s" % DIFF_NAMES[s["difficulty"]]
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


func _on_diff() -> void:
	GameData.settings["difficulty"] = (GameData.settings["difficulty"] + 1) % DIFF_NAMES.size()
	GameData.save_settings()
	refresh()


func _on_delete() -> void:
	GameData.slot_mode = "load"
	get_tree().change_scene_to_file("res://saves.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
