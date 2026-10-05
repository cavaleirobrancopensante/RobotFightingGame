extends Control
## Save slots. GameData.slot_mode decides what we're doing:
##   "new"  - pick a slot for a new game (empty, or overwrite), then name your pilot and robot
##   "load" - load or delete a save

var mode := "load"
var col: VBoxContainer
var confirm := {}      # slot -> action waiting for a second tap
var chosen_slot := 1
var pilot_edit: LineEdit
var robot_edit: LineEdit


func _ready() -> void:
	Sfx.music("menu")
	mode = GameData.slot_mode
	UI.background(self)
	var m := UI.margin(self, 24)
	var center := CenterContainer.new()
	m.add_child(center)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(900, 0)
	center.add_child(col)
	show_slots()


func clear() -> void:
	for c in col.get_children():
		c.queue_free()


func title(text: String) -> void:
	var t := UI.label(text, 32, Color(1.0, 0.45, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)


func show_slots() -> void:
	clear()
	title("NEW GAME - pick a save slot" if mode == "new" else "LOAD GAME")
	for slot in range(1, GameData.SAVE_SLOTS + 1):
		var info := GameData.slot_info(slot)
		var panel := PanelContainer.new()
		col.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if info.is_empty():
			text.add_child(UI.label("Slot %d - empty" % slot, 20))
		elif info.get("broken", false):
			text.add_child(UI.label("Slot %d - damaged file" % slot, 20, Color(1.0, 0.5, 0.4)))
		else:
			text.add_child(UI.label("Slot %d - %s & %s" % [slot, info["pilot"], info["robot"]], 20))
			var cups := ", %d cups" % info["cups"] if info["cups"] > 0 else ""
			text.add_child(UI.label("%s%s  -  $%d  -  saved %s" % [info["progress"], cups, info["money"], info["saved"]], 14, Color(0.72, 0.72, 0.78)))
		var waiting: String = confirm.get(slot, "")
		if mode == "new":
			if info.is_empty():
				row.add_child(UI.button("Use", _on_pick.bind(slot), 18, Vector2(150, 52)))
			else:
				row.add_child(UI.button("Sure? Tap again" if waiting == "overwrite" else "Overwrite", _on_overwrite.bind(slot), 18, Vector2(190, 52)))
		else:
			var load_b := UI.button("Load", _on_load.bind(slot), 18, Vector2(120, 52))
			load_b.disabled = info.is_empty() or info.get("broken", false)
			row.add_child(load_b)
			var del := UI.button("Sure? Tap again" if waiting == "delete" else "Delete", _on_delete.bind(slot), 18, Vector2(190, 52))
			del.disabled = info.is_empty()
			row.add_child(del)
	col.add_child(UI.button("Back", _on_back, 20, Vector2(0, 52)))


func show_names() -> void:
	clear()
	title("NEW GAME - slot %d" % chosen_slot)
	pilot_edit = name_row("Pilot name", GameData.random_pilot_name(), _on_random_pilot)
	robot_edit = name_row("Robot name", GameData.DEFAULT_ROBOT, _on_random_robot)
	var hint := UI.label("Your robot is the one you dig out of the scrapyard. The story calls it by this name.", 14, Color(0.72, 0.72, 0.78))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var back := UI.button("Back", show_slots, 20, Vector2(200, 56))
	row.add_child(back)
	var start := UI.button("START", _on_start, 24, Vector2(0, 56))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start)


func name_row(label: String, value: String, random_cb: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var l := UI.label(label, 20)
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.max_length = 16
	edit.add_theme_font_size_override("font_size", int(22 * UI.SCALE))
	edit.custom_minimum_size = Vector2(0, 56 * UI.SCALE)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.select_all_on_focus = true
	row.add_child(edit)
	row.add_child(UI.button("Random", random_cb, 18, Vector2(130, 56)))
	return edit


func _on_pick(slot: int) -> void:
	chosen_slot = slot
	show_names()


func _on_overwrite(slot: int) -> void:
	if confirm.get(slot, "") == "overwrite":
		_on_pick(slot)
		return
	confirm = {slot: "overwrite"}
	Sfx.play("error")
	show_slots()


func _on_load(slot: int) -> void:
	var err := GameData.load_game(slot)
	if err == "":
		get_tree().change_scene_to_file("res://garage.tscn")
	else:
		var l := UI.label(err, 16, Color(1.0, 0.6, 0.4))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		Sfx.play("error")


func _on_delete(slot: int) -> void:
	if confirm.get(slot, "") == "delete":
		GameData.delete_save(slot)
		confirm = {}
		Sfx.play("break")
	else:
		confirm = {slot: "delete"}
		Sfx.play("error")
	show_slots()


func _on_random_pilot() -> void:
	pilot_edit.text = GameData.random_pilot_name()


func _on_random_robot() -> void:
	robot_edit.text = GameData.random_robot_name()


func _on_start() -> void:
	var pilot := pilot_edit.text.strip_edges()
	var robot := robot_edit.text.strip_edges().to_upper()
	GameData.new_game()
	GameData.save_slot = chosen_slot
	GameData.pilot_name = pilot if pilot != "" else GameData.random_pilot_name()
	GameData.robot_name = robot if robot != "" else GameData.DEFAULT_ROBOT
	GameData.save_game()
	GameData.queue_story("intro", "res://garage.tscn")
	get_tree().change_scene_to_file("res://story.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
