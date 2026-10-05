extends Control
## Garage: money, robot overview, part shop, and the next championship fight.

var current_slot := "arms"
var title_label: Label
var money_label: Label
var stats_box: VBoxContainer
var list_box: VBoxContainer
var msg_label: Label
var preview: RobotPreview
var fight_button: Button
var slot_buttons := {}


func _ready() -> void:
	UI.background(self)
	var m := UI.margin(self, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	m.add_child(root)

	# top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	title_label = UI.label("", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	money_label = UI.label("", 32, Color(0.95, 0.85, 0.2))
	top.add_child(money_label)

	# middle: robot on the left, shop on the right
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	root.add_child(mid)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 6)
	mid.add_child(left)
	preview = RobotPreview.new()
	preview.custom_minimum_size = Vector2(340, 160)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	stats_box = VBoxContainer.new()
	left.add_child(stats_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	mid.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for slot in GameData.SLOTS:
		var b := UI.button(GameData.SLOT_NAMES[slot], _on_slot.bind(slot), 22, Vector2(0, 52))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		slot_buttons[slot] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	msg_label = UI.label("", 22, Color(0.6, 0.9, 1.0))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(msg_label)

	# bottom bar
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	bottom.add_child(UI.button("Main Menu", _on_menu, 24, Vector2(180, 60)))
	bottom.add_child(UI.button("Save", _on_save, 24, Vector2(140, 60)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	fight_button = UI.button("", _on_fight, 26, Vector2(380, 60))
	bottom.add_child(fight_button)

	show_last_result()
	refresh()


func show_last_result() -> void:
	var r := GameData.last_result
	if r.is_empty():
		msg_label.text = "Buy parts to upgrade your robot. Parts need reactor power."
		return
	if r.get("quit", false):
		msg_label.text = "You walked out on %s. No pay." % r["opponent"]
	elif r.get("champion", false):
		msg_label.text = "YOU ARE THE CHAMPION! Beat %s and earned $%d." % [r["opponent"], r["reward"]]
	elif r["won"]:
		msg_label.text = "Victory over %s! Earned $%d. (Game saved)" % [r["opponent"], r["reward"]]
	else:
		msg_label.text = "Lost to %s. Earned $%d for the show. Upgrade and try again." % [r["opponent"], r["reward"]]
	GameData.last_result = {}


func refresh() -> void:
	money_label.text = "$%d" % GameData.money
	if GameData.champion:
		title_label.text = "GARAGE  -  Champion! (%dW / %dL)" % [GameData.wins, GameData.losses]
		fight_button.text = "Championship won!"
		fight_button.disabled = true
	else:
		var o := GameData.current_opponent()
		title_label.text = "GARAGE  -  Fight %d of %d" % [GameData.fight_index + 1, GameData.OPPONENTS.size()]
		fight_button.text = "FIGHT: %s  ($%d)" % [o["name"], o["reward"]]
		fight_button.disabled = false

	preview.look = GameData.look()
	preview.queue_redraw()

	# stats
	for c in stats_box.get_children():
		c.queue_free()
	var s := GameData.stats()
	add_stat("Durability", s["max_hp"], 200, "%d HP" % s["max_hp"], Color(0.4, 0.85, 0.4))
	add_stat("Damage", s["damage"], 170, "%d%%" % s["damage"], Color(0.95, 0.4, 0.3))
	add_stat("Speed", s["speed"], 150, "%d%%" % s["speed"], Color(0.35, 0.7, 1.0))
	add_stat("Power", s["power_used"], s["power_output"], "%d / %d" % [s["power_used"], s["power_output"]], Color(1.0, 0.8, 0.3))

	# shop list for the selected slot
	for slot in slot_buttons:
		slot_buttons[slot].button_pressed = slot == current_slot
	for c in list_box.get_children():
		c.queue_free()
	for p in GameData.PARTS[current_slot]:
		list_box.add_child(make_part_row(p))


func add_stat(title: String, value: float, max_value: float, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_child(UI.label(title, 20))
	row.get_child(0).custom_minimum_size = Vector2(110, 0)
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var v := UI.label(text, 20)
	v.custom_minimum_size = Vector2(90, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	stats_box.add_child(row)


func make_part_row(p: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = Color(p["color"])
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(p["name"], 24))
	info.add_child(UI.label(GameData.part_stat_text(p), 18, Color(0.75, 0.75, 0.8)))
	row.add_child(info)

	var id: String = p["id"]
	var b: Button
	if GameData.equipped[current_slot] == id:
		b = UI.button("Equipped", func(): pass, 22, Vector2(170, 56))
		b.disabled = true
	elif GameData.owned.has(id):
		b = UI.button("Equip", _on_equip.bind(id), 22, Vector2(170, 56))
	else:
		b = UI.button("Buy $%d" % p["cost"], _on_buy.bind(id), 22, Vector2(170, 56))
		b.disabled = GameData.money < p["cost"]
	row.add_child(b)
	return panel


func _on_slot(slot: String) -> void:
	current_slot = slot
	refresh()


func _on_buy(id: String) -> void:
	var before := GameData.money
	msg_label.text = GameData.buy(id)
	if GameData.money < before:
		Sfx.play("buy")
		if GameData.equipped[current_slot] == id:
			Sfx.play("equip")
	else:
		Sfx.play("error")
	refresh()


func _on_equip(id: String) -> void:
	msg_label.text = GameData.equip(id)
	Sfx.play("equip" if GameData.equipped[current_slot] == id else "error")
	refresh()


func _on_save() -> void:
	msg_label.text = "Game saved." if GameData.save_game() else "Couldn't save!"


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_fight() -> void:
	GameData.save_game()
	get_tree().change_scene_to_file("res://fight.tscn")
