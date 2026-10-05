extends Control
## Garage: your robot, repairs, the part shop, spare parts, paint, and the next fight.

const TABS := ["Robot", "Shop", "Spares", "Paint"]

var tab := "Robot"
var shop_kind := "arm"
var title_label: Label
var money_label: Label
var stats_box: VBoxContainer
var list_box: VBoxContainer
var sub_tabs: HBoxContainer
var msg_label: Label
var preview: RobotPreview
var fight_button: Button
var tab_buttons := {}


func _ready() -> void:
	Sfx.music("menu")
	UI.background(self)
	var m := UI.margin(self, 14)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	m.add_child(root)

	# top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	title_label = UI.label("", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	money_label = UI.label("", 32, Color(0.95, 0.85, 0.2))
	top.add_child(money_label)

	# middle: robot + stats on the left, tabs on the right
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 4)
	mid.add_child(left)
	preview = RobotPreview.new()
	preview.custom_minimum_size = Vector2(330, 150)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	left.add_child(stats_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	mid.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for t in TABS:
		var b := UI.button(t, _on_tab.bind(t), 24, Vector2(0, 52))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_buttons[t] = b
	sub_tabs = HBoxContainer.new()
	right.add_child(sub_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)
	msg_label = UI.label("", 20, Color(0.6, 0.9, 1.0))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(msg_label)

	# bottom bar
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	bottom.add_child(UI.button("Menu", _on_menu, 22, Vector2(110, 56)))
	bottom.add_child(UI.button("Save", _on_save, 22, Vector2(110, 56)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	fight_button = UI.button("", _on_fight, 24, Vector2(420, 56))
	bottom.add_child(fight_button)

	show_last_result()
	refresh()


func show_last_result() -> void:
	var r := GameData.last_result
	if r.is_empty():
		msg_label.text = "Welcome to the garage. Tap the tabs to repair, shop, swap parts and paint."
		return
	if r.get("quit", false):
		msg_label.text = "You walked out on %s. No pay, and the dents came home with you." % r["opponent"]
	else:
		var bits: Array = []
		if r.get("champion", false):
			bits.append("CHAMPION! You beat %s." % r["opponent"])
		elif r["won"]:
			bits.append("Beat %s!" % r["opponent"])
		else:
			bits.append("Lost to %s." % r["opponent"])
		bits.append("Earned $%d." % (r["reward"] + r.get("bonus", 0)))
		if not r.get("lost", []).is_empty():
			bits.append("Lost: %s." % ", ".join(r["lost"]))
		if not r.get("wrecked", []).is_empty():
			bits.append("Wrecked: %s (rebuild in Spares)." % ", ".join(r["wrecked"]))
		if not r.get("salvaged", []).is_empty():
			bits.append("Salvaged: %s (in Spares)." % ", ".join(r["salvaged"]))
		msg_label.text = " ".join(bits)
	GameData.last_result = {}


func say(text: String, sound: String = "") -> void:
	msg_label.text = text
	if sound != "":
		Sfx.play(sound)


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	money_label.text = "$%d" % GameData.money
	var o := GameData.current_opponent()
	if GameData.champion:
		title_label.text = "GARAGE  -  Champion! (%dW / %dL)" % [GameData.wins, GameData.losses]
	else:
		title_label.text = "GARAGE  -  Fight %d of %d" % [GameData.fight_index + 1, GameData.OPPONENTS.size()]
	var core := GameData.equipped_inst("torso")
	if not GameData.can_fight():
		fight_button.text = "Need a head and a torso to fight"
		fight_button.disabled = true
	else:
		fight_button.disabled = false
		var label := "EXHIBITION: %s ($%d)" if GameData.champion else "FIGHT: %s ($%d)"
		fight_button.text = label % [o["name"], GameData.current_reward()]
		if not core.is_empty() and GameData.hp_ratio(core) < 0.35:
			fight_button.text += "  - core damaged!"

	preview.look = GameData.player_look()
	refresh_stats()
	for t in tab_buttons:
		tab_buttons[t].button_pressed = t == tab
	for c in sub_tabs.get_children():
		c.queue_free()
	for c in list_box.get_children():
		c.queue_free()
	match tab:
		"Robot":
			build_robot_tab()
		"Shop":
			build_shop_tab()
		"Spares":
			build_spares_tab()
		"Paint":
			build_paint_tab()


func refresh_stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var s := GameData.stats()
	add_stat("Core", s["core"], s["core_max"], "%d/%d" % [s["core"], s["core_max"]], Color(0.4, 0.85, 0.4))
	add_stat("Damage", s["damage"], 170, "%d%%" % s["damage"], Color(0.95, 0.4, 0.3))
	add_stat("Speed", s["speed"], 150, "%d%%" % s["speed"], Color(0.35, 0.7, 1.0))
	add_stat("Aim", s["aim"], 30, "+%d%%" % s["aim"], Color(1.0, 0.45, 0.7))
	var over: bool = s["power_used"] > s["power_output"]
	add_stat("Power", s["power_used"], s["power_output"], "%d/%d" % [s["power_used"], s["power_output"]],
			Color(1.0, 0.35, 0.2) if over else Color(1.0, 0.8, 0.3))
	if over:
		var w := UI.label("OVERLOADED: %d%% performance. Get a bigger reactor!" % int(s["efficiency"] * 100), 16, Color(1.0, 0.5, 0.3))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_box.add_child(w)


func add_stat(title: String, value: float, max_value: float, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var t := UI.label(title, 18)
	t.custom_minimum_size = Vector2(80, 0)
	row.add_child(t)
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, max_value)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var v := UI.label(text, 18)
	v.custom_minimum_size = Vector2(84, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	stats_box.add_child(row)


# ---------------------------------------------------------------- row helpers

func make_row(def: Dictionary, title: String, subtitle: String, health: float = 1.0) -> HBoxContainer:
	var panel := PanelContainer.new()
	list_box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := PartIcon.new()
	icon.part = def
	icon.health = health
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := UI.label(title, 22)
	t.clip_text = true
	info.add_child(t)
	var s := UI.label(subtitle, 16, Color(0.72, 0.72, 0.78))
	s.clip_text = true
	info.add_child(s)
	row.add_child(info)
	return row


func row_button(row: HBoxContainer, text: String, cb: Callable, enabled: bool = true, width: float = 120.0) -> Button:
	var b := UI.button(text, cb, 18, Vector2(width, 54))
	b.disabled = not enabled
	row.add_child(b)
	return b


func health_text(p: Dictionary) -> String:
	var d := GameData.part_def(p["id"])
	if d["kind"] == "reactor":
		return GameData.part_stat_text(d)
	return "Condition %d/%d   %s" % [ceili(p["hp"]), d["hp"], GameData.part_stat_text(d)]


# ---------------------------------------------------------------- tabs

func build_robot_tab() -> void:
	var total := GameData.repair_all_cost()
	var head := HBoxContainer.new()
	list_box.add_child(head)
	var l := UI.label("Equipped parts" if total == 0 else "Damage to fix: $%d" % total, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	row_button(head, "Repair all $%d" % total, _on_repair_all, total > 0, 190)

	for slot in GameData.SLOTS:
		var p := GameData.equipped_inst(slot)
		var slot_name: String = GameData.SLOT_NAMES[slot]
		if p.is_empty():
			var empty := make_row({}, "%s: EMPTY" % slot_name, "Buy one in the Shop or fit one from Spares.")
			row_button(empty, "Shop", _on_go_shop.bind(GameData.SLOT_KIND[slot]))
			continue
		var d := GameData.part_def(p["id"])
		var row := make_row(d, "%s: %s" % [slot_name, d["name"]], health_text(p), GameData.hp_ratio(p))
		if slot != "reactor":
			var c := GameData.repair_cost(p)
			row_button(row, "Fix $%d" % c if c > 0 else "Perfect", _on_repair.bind(p["uid"]), c > 0, 110)
			row_button(row, "Remove", _on_unequip.bind(slot), true, 100)


func build_shop_tab() -> void:
	for kind in GameData.KINDS:
		var b := UI.button(GameData.KIND_NAMES[kind], _on_shop_kind.bind(kind), 18, Vector2(0, 44))
		b.toggle_mode = true
		b.button_pressed = kind == shop_kind
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_tabs.add_child(b)
	for d in GameData.shop_parts(shop_kind):
		var row := make_row(d, d["name"], GameData.part_stat_text(d))
		row_button(row, "Buy $%d" % d["cost"] if d["cost"] > 0 else "Free", _on_buy.bind(d["id"]), GameData.money >= d["cost"], 130)


func build_spares_tab() -> void:
	var list := GameData.spares()
	if list.is_empty():
		var l := UI.label("No spare parts. Parts you buy while your slots are full, parts you remove and parts you salvage end up here.", 20, Color(0.7, 0.7, 0.75))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(l)
		return
	for p in list:
		var d := GameData.part_def(p["id"])
		var wreck := GameData.is_wreck(p)
		var tag := "  (WRECKED)" if wreck else ("" if d["shop"] else "  (salvaged)")
		var row := make_row(d, d["name"] + tag, health_text(p), GameData.hp_ratio(p))
		var c := GameData.repair_cost(p)
		if wreck:
			row_button(row, "Rebuild $%d" % c, _on_repair.bind(p["uid"]), GameData.money >= c, 150)
			row_button(row, "Scrap", _on_sell.bind(p["uid"]), true, 90)
			continue
		match d["kind"]:
			"arm":
				row_button(row, "Front", _on_equip.bind(p["uid"], "arm_front"), true, 80)
				row_button(row, "Back", _on_equip.bind(p["uid"], "arm_back"), true, 80)
			"leg":
				row_button(row, "Front", _on_equip.bind(p["uid"], "leg_front"), true, 80)
				row_button(row, "Back", _on_equip.bind(p["uid"], "leg_back"), true, 80)
			_:
				row_button(row, "Fit", _on_equip.bind(p["uid"], d["kind"]), true, 80)
		if c > 0:
			row_button(row, "Fix $%d" % c, _on_repair.bind(p["uid"]), GameData.money >= c, 100)
		var v := GameData.sell_value(p)
		row_button(row, "Sell $%d" % v if v > 0 else "Scrap", _on_sell.bind(p["uid"]), true, 110)


func build_paint_tab() -> void:
	list_box.add_child(UI.label("Paint job (trim and highlights). Free!", 20))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list_box.add_child(grid)
	for k in GameData.PAINTS.size():
		var paint: Dictionary = GameData.PAINTS[k]
		var b := UI.button(paint["name"], _on_paint.bind(k), 20, Vector2(150, 64))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(paint["color"]).darkened(0.35)
		sb.border_color = Color.WHITE if k == GameData.paint else Color(paint["color"])
		sb.set_border_width_all(4 if k == GameData.paint else 2)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		grid.add_child(b)


# ---------------------------------------------------------------- actions

func _on_tab(t: String) -> void:
	tab = t
	refresh()


func _on_shop_kind(kind: String) -> void:
	shop_kind = kind
	refresh()


func _on_go_shop(kind: String) -> void:
	tab = "Shop"
	shop_kind = kind
	refresh()


func _on_buy(id: String) -> void:
	var before := GameData.money
	var text := GameData.buy(id)
	say(text, "buy" if GameData.money < before or GameData.part_def(id)["cost"] == 0 else "error")
	refresh()


func _on_equip(uid: int, slot: String) -> void:
	say(GameData.equip(uid, slot), "equip")
	refresh()


func _on_unequip(slot: String) -> void:
	GameData.unequip(slot)
	say("Removed the %s. It's in your Spares." % GameData.SLOT_NAMES[slot], "equip")
	refresh()


func _on_repair(uid: int) -> void:
	var before := GameData.money
	var text := GameData.repair(uid)
	say(text, "repair" if GameData.money < before else "error")
	refresh()


func _on_repair_all() -> void:
	var before := GameData.money
	var text := GameData.repair_all()
	say(text, "repair" if GameData.money < before else "error")
	refresh()


func _on_sell(uid: int) -> void:
	say(GameData.sell(uid), "sell")
	refresh()


func _on_paint(k: int) -> void:
	GameData.paint = k
	say("Painted %s." % GameData.PAINTS[k]["name"], "equip")
	refresh()


func _on_save() -> void:
	if GameData.save_game():
		say("Game saved.", "buy")
	else:
		say("Couldn't save!", "error")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_fight() -> void:
	GameData.save_game()
	if not GameData.champion and GameData.queue_story("pre_%d" % GameData.fight_index, "res://fight.tscn"):
		get_tree().change_scene_to_file("res://story.tscn")
	else:
		get_tree().change_scene_to_file("res://fight.tscn")
