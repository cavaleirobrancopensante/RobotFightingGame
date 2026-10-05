extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const RobotPreview = preload("res://robot_preview.gd")
const UI = preload("res://ui.gd")
## Main menu: New Game, Load Game, Settings, Quit.

var new_button: Button
var msg: Label


func _ready() -> void:
	Sfx.music("menu")
	UI.background(self)
	var m := UI.margin(self, 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	m.add_child(row)

	var left := RobotPreview.new()
	left.look = random_look()
	left.show_floor = false
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	row.add_child(col)

	var title := UI.label("ROBOT FIGHTING", 46, Color(1.0, 0.45, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var spacer := Control.new()   # breathing room between the title and the buttons
	spacer.custom_minimum_size = Vector2(0, 20 * UI.SCALE)
	col.add_child(spacer)

	col.add_child(UI.button("Quick Fight", _on_quick, 26, Vector2(0, 56)))
	new_button = UI.button("New Game", _on_new, 26, Vector2(0, 56))
	col.add_child(new_button)
	var load_button := UI.button("Load Game", _on_load, 26, Vector2(0, 56))
	load_button.disabled = not GameData.any_save()
	col.add_child(load_button)
	col.add_child(UI.button("Settings", _on_settings, 26, Vector2(0, 56)))
	col.add_child(UI.button("Quit Game", _on_quit, 26, Vector2(0, 56)))

	msg = UI.label("", 22, Color(1.0, 0.8, 0.4))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)

	var right := RobotPreview.new()
	right.look = random_look()
	right.facing = -1
	right.show_floor = false
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)


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
