extends Control
## Main menu: New Game, Load Game, Settings, Quit.

var new_button: Button
var msg: Label
var confirm_new := false


func _ready() -> void:
	Sfx.music("menu")
	UI.background(self)
	var m := UI.margin(self, 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	m.add_child(row)

	var left := RobotPreview.new()
	left.look = GameData.player_look()
	left.show_floor = false
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	row.add_child(col)

	var title := UI.label("ROBOT FIGHTING", 56, Color(1.0, 0.45, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UI.label("The Scrap Championship", 26, Color(0.75, 0.75, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	new_button = UI.button("New Game", _on_new, 30)
	col.add_child(new_button)
	var load_button := UI.button("Load Game", _on_load, 30)
	load_button.disabled = not GameData.has_save()
	col.add_child(load_button)
	col.add_child(UI.button("Settings", _on_settings, 30))
	col.add_child(UI.button("Quit Game", _on_quit, 30))

	msg = UI.label("", 22, Color(1.0, 0.8, 0.4))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)

	var right := RobotPreview.new()
	right.look = GameData.look_from_spec(GameData.opponent_spec(9))
	right.facing = -1
	right.show_floor = false
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)


func _on_new() -> void:
	if GameData.has_save() and not confirm_new:
		confirm_new = true
		new_button.text = "Overwrite save? Tap again"
		return
	GameData.new_game()
	GameData.save_game()
	GameData.queue_story("intro", "res://garage.tscn")
	get_tree().change_scene_to_file("res://story.tscn")


func _on_load() -> void:
	var err := GameData.load_game()
	if err == "":
		get_tree().change_scene_to_file("res://garage.tscn")
	else:
		msg.text = err
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")


func _on_quit() -> void:
	get_tree().quit()
