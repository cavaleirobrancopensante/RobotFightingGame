extends Control
## Garage, organised in sections:
##   BUILD    - your robot slot by slot. Tap a slot (or a part on the robot picture) to swap,
##              repair or remove it. Setups, Paint and Storage open as popups.
##   SHOP     - buy parts by type
##   WORKSHOP - design your own custom part (costs a bit more)
##   MOVES    - special-move training chips
##   CUPS     - championships, once the story is done

const STAT_NAMES := {"hp": "Health", "armor": "Armor", "damage": "Damage", "speed": "Speed", "aim": "Aim", "chips": "Chip slots"}

var tab := "Build"
var selected := ""          # Build tab: "" = overview, a slot name, or "storage"
var shop_kind := "arm"
var ws := {}                # workshop design in progress
var title_label: Label
var money_label: Label
var stats_box: VBoxContainer
var list_box: VBoxContainer
var scroll: ScrollContainer
var tabs_box: HBoxContainer
var msg_label: Label
var preview: RobotPreview
var fight_button: Button
var scout_button: Button
var send_button: Button
var overlay: Control
var last_view := ""


class ChipIcon extends Control:
	var installed := false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.14))
		var r := Rect2(size * 0.2, size * 0.6)
		for k in 4:
			var y := r.position.y + 4 + k * (r.size.y - 8) / 3.0
			draw_line(Vector2(r.position.x - 7, y), Vector2(r.end.x + 7, y), Color(0.8, 0.7, 0.3), 3.0)
		draw_rect(r, Color(0.1, 0.45, 0.25) if installed else Color(0.2, 0.3, 0.25))
		draw_rect(r.grow(-6), Color(0.15, 0.15, 0.15))
		draw_circle(r.get_center(), 4.0, Color(0.4, 1.0, 0.6) if installed else Color(0.4, 0.4, 0.4))


func _ready() -> void:
	Sfx.music("garage")
	reset_workshop("arm")
	UI.background(self)
	var m := UI.margin(self, 12)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	m.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	title_label = UI.label("", 22)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	top.add_child(title_label)
	money_label = UI.label("", 26, Color(0.95, 0.85, 0.2))
	top.add_child(money_label)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	root.add_child(mid)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 2)
	mid.add_child(left)
	preview = RobotPreview.new()
	preview.interactive = true
	preview.custom_minimum_size = Vector2(300, 110)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.part_tapped.connect(_on_part_tapped)
	left.add_child(preview)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 0)
	left.add_child(stats_box)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	mid.add_child(right)
	tabs_box = HBoxContainer.new()
	right.add_child(tabs_box)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)
	msg_label = UI.label("", 15, Color(0.6, 0.9, 1.0))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(0, 44)
	right.add_child(msg_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	bottom.add_child(UI.button("Menu", _on_menu, 18, Vector2(90, 48)))
	bottom.add_child(UI.button("Save", _on_save, 18, Vector2(90, 48)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	send_button = UI.button("", _on_send, 16, Vector2(150, 48))
	bottom.add_child(send_button)
	scout_button = UI.button("", _on_open_scout, 17, Vector2(150, 48))
	bottom.add_child(scout_button)
	fight_button = UI.button("", _on_fight, 19, Vector2(360, 48))
	bottom.add_child(fight_button)

	show_last_result()
	refresh()


func tab_list() -> Array:
	var t := ["Build", "Shop", "Workshop", "Moves"]
	if GameData.champion:
		t.append("Cups")
	if GameData.team_unlocked():
		t.append("Team")
	return t


func show_last_result() -> void:
	var r := GameData.last_result
	if r.is_empty():
		msg_label.text = "Tap a part of your robot (or a row) to swap, repair or remove it."
		return
	if r.get("quit", false):
		msg_label.text = "You walked out on %s. No pay, and the dents came home with you." % r["opponent"]
	else:
		var bits: Array = []
		if r.get("champion", false):
			bits.append("CHAMPION! You beat %s. Championships are open in the Cups tab!" % r["opponent"])
		elif r["won"]:
			bits.append("Beat %s!" % r["opponent"])
		else:
			bits.append("Lost to %s." % r["opponent"])
		bits.append("Earned $%d." % (r["reward"] + r.get("bonus", 0)))
		if r.get("cup_done", "") != "":
			bits.append("CUP WON: %s" % r["cup_done"])
		if r.get("trophy", "") != "":
			bits.append("Trophy part: %s." % r["trophy"])
		if not r.get("lost", []).is_empty():
			bits.append("Lost: %s." % ", ".join(r["lost"]))
		if not r.get("wrecked", []).is_empty():
			bits.append("Wrecked: %s (rebuild in Storage)." % ", ".join(r["wrecked"]))
		if not r.get("salvaged", []).is_empty():
			bits.append("Salvaged: %s." % ", ".join(r["salvaged"]))
		msg_label.text = " ".join(bits)
	GameData.last_result = {}


func say(text: String, sound: String = "") -> void:
	msg_label.text = text
	if sound != "":
		Sfx.play(sound)


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	money_label.text = "$%d" % GameData.money
	var mode := GameData.fight_mode()
	match mode:
		"circuit":
			title_label.text = "GARAGE - %s" % GameData.fight_title()
		"exhibition":
			title_label.text = "GARAGE - Champion! (%dW/%dL, %d cups)" % [GameData.wins, GameData.losses, GameData.circuits_won]
		_:
			title_label.text = "GARAGE - Fight %d of %d" % [GameData.fight_index + 1, GameData.OPPONENTS.size()]
	var o := GameData.current_opponent()
	var core := GameData.equipped_inst("torso")
	# which robot goes in: your main robot, or a backup robot (1-on-1 fights only)
	var backups: Array = []
	for k in GameData.wingmen.size():
		if GameData.wingman_ready(k):
			backups.append(k)
	if GameData.sending >= 0 and not backups.has(GameData.sending):
		GameData.sending = -1
	send_button.visible = not backups.is_empty() and not GameData.is_team_fight()
	send_button.text = "Send: %s" % ("main robot" if GameData.sending < 0 else GameData.WINGMAN_NAMES[GameData.sending])
	if not GameData.can_send():
		fight_button.text = "Need a head and a torso"
		fight_button.disabled = true
	else:
		fight_button.disabled = false
		var label: String = {"story": "FIGHT: %s ($%d)", "circuit": "CUP FIGHT: %s ($%d)", "exhibition": "REMATCH: %s ($%d)"}.get(mode, "FIGHT: %s ($%d)")
		fight_button.text = label % [o["name"], GameData.current_reward()]
		if o.has("team_label"):
			fight_button.text += " - %s" % o["team_label"]
		if GameData.sending >= 0 and not GameData.is_team_fight():
			fight_button.text = "%s fights %s ($%d)" % [GameData.sending_name(), o["name"], GameData.current_reward()]
		elif not core.is_empty() and GameData.hp_ratio(core) < 0.35:
			fight_button.text += " - core damaged!"

	scout_button.visible = GameData.scout_key() != ""
	scout_button.text = "Scout report" if GameData.scouted() else "Scout $%d" % GameData.scout_cost()
	preview.look = GameData.player_look()
	preview.highlight = selected if tab == "Build" else ""
	refresh_stats()
	for c in tabs_box.get_children():
		c.queue_free()
	for t in tab_list():
		var b := UI.button(t, _on_tab.bind(t), 18, Vector2(0, 46))
		b.toggle_mode = true
		b.button_pressed = t == tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs_box.add_child(b)

	# keep the scroll position when the same view is rebuilt (e.g. tapping + in the workshop)
	var view := tab + "/" + selected + "/" + shop_kind
	var keep := scroll.scroll_vertical if view == last_view else 0
	last_view = view
	for c in list_box.get_children():
		c.queue_free()
	match tab:
		"Build":
			if selected == "":
				build_overview()
			elif selected == "storage":
				build_storage()
			else:
				build_slot(selected)
		"Shop":
			build_shop_tab()
		"Workshop":
			build_workshop()
		"Moves":
			build_moves_tab()
		"Cups":
			build_cups_tab()
		"Team":
			build_team_tab()
	scroll.set_deferred("scroll_vertical", keep)


func refresh_stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var s := GameData.stats()
	add_stat("Core", s["core"], s["core_max"], "%d/%d" % [s["core"], s["core_max"]], Color(0.4, 0.85, 0.4))
	add_stat("Damage", s["damage"], 170, "%d%%" % s["damage"], Color(0.95, 0.4, 0.3))
	add_stat("Speed", s["speed"], 150, "%d%%" % s["speed"], Color(0.35, 0.7, 1.0))
	add_stat("Chips", GameData.active_chips().size(), maxf(1, GameData.chip_slots()), "%d/%d" % [GameData.active_chips().size(), GameData.chip_slots()], Color(0.75, 0.45, 1.0))
	var over: bool = s["power_used"] > s["power_output"]
	add_stat("Power", s["power_used"], s["power_output"], "%d/%d" % [s["power_used"], s["power_output"]],
			Color(1.0, 0.35, 0.2) if over else Color(1.0, 0.8, 0.3))
	if over:
		stats_box.add_child(UI.label("OVERLOADED: %d%% performance!" % int(s["efficiency"] * 100), 13, Color(1.0, 0.5, 0.3)))
	var wl := UI.label("%s  (%d power)" % [GameData.weight_class(s["power_used"]), s["power_used"]], 13, Color(0.8, 0.8, 0.9))
	wl.tooltip_text = "Weight class = the power your parts draw. Teams share one heavyweight's power."
	stats_box.add_child(wl)


func add_stat(title: String, value: float, max_value: float, text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var t := UI.label(title, 14)
	t.custom_minimum_size = Vector2(80, 0)
	row.add_child(t)
	row.add_child(make_bar(value, max_value, color))
	var v := UI.label(text, 14)
	v.custom_minimum_size = Vector2(84, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	stats_box.add_child(row)


func make_bar(value: float, max_value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, max_value)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# ---------------------------------------------------------------- row helpers

func make_row(icon: Control, title: String, subtitle: String, parent: Control = null) -> HBoxContainer:
	var panel := PanelContainer.new()
	(parent if parent else list_box).add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	icon.custom_minimum_size = Vector2(66, 66)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(title, 17)
	t.clip_text = true
	info.add_child(t)
	if subtitle != "":
		var s := UI.label(subtitle, 12, Color(0.72, 0.72, 0.78))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(s)
	row.add_child(info)
	return row


## A whole-row button (tap anywhere on it), with an icon, two lines of text and extra widgets.
func make_tap_row(icon: Control, title: String, subtitle: String, cb: Callable) -> HBoxContainer:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74 * UI.SCALE)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05))
	b.pressed.connect(cb)
	list_box.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	icon.custom_minimum_size = Vector2(66, 66)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(title, 17)
	t.clip_text = true
	info.add_child(t)
	var s := UI.label(subtitle, 12, Color(0.72, 0.72, 0.78))
	s.clip_text = true
	info.add_child(s)
	row.add_child(info)
	return row


func part_icon(def: Dictionary, health: float = 1.0) -> PartIcon:
	var icon := PartIcon.new()
	icon.part = def
	icon.health = health
	return icon


func row_button(row: Control, text: String, cb: Callable, enabled: bool = true, width: float = 100.0) -> Button:
	var b := UI.button(text, cb, 15, Vector2(width, 48))
	b.disabled = not enabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return b


func section(text: String, parent: Control = null) -> void:
	var l := UI.label(text, 15, Color(1.0, 0.8, 0.4))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else list_box).add_child(l)


func action_bar(parent: Control = null) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	(parent if parent else list_box).add_child(bar)
	return bar


func health_text(p: Dictionary) -> String:
	var d := GameData.part_def(p["id"])
	if GameData.UNDAMAGEABLE.has(d["kind"]):
		return GameData.part_stat_text(d)
	return "Condition %d/%d  %s" % [ceili(p["hp"]), d["hp"], GameData.part_stat_text(d)]


# ---------------------------------------------------------------- BUILD

func build_overview() -> void:
	var total := GameData.repair_all_cost()
	var bar := action_bar()
	row_button(bar, "Repair all $%d" % total if total > 0 else "All repaired", _on_repair_all, total > 0, 150)
	row_button(bar, "Randomize", _on_randomize, true, 120)
	row_button(bar, "Setups", _on_open_setups, true, 100)
	row_button(bar, "Paint", _on_open_paint, true, 85)
	row_button(bar, "Pilot", _on_open_pilot, true, 80)
	row_button(bar, "Style: %s" % Catalog.STYLES[GameData.style]["name"], _on_open_style, true, 150)
	row_button(bar, "Storage (%d)" % GameData.spares().size(), _on_slot.bind("storage"), true, 125)

	for slot in GameData.SLOTS:
		if not GameData.slot_available(slot):
			continue   # extra heads/arms need a torso with mounts for them
		var p := GameData.equipped_inst(slot)
		var slot_name: String = GameData.SLOT_NAMES[slot]
		if p.is_empty():
			var opt: bool = slot == "back" or GameData.EXTRA_SLOTS.has(slot)
			make_tap_row(part_icon({}), "%s: empty" % slot_name, "Tap to fit or buy one" + (" (optional)" if opt else ""), _on_slot.bind(slot))
			continue
		var d := GameData.part_def(p["id"])
		var row := make_tap_row(part_icon(d, GameData.hp_ratio(p)), "%s: %s" % [slot_name, d["name"]], GameData.part_stat_text(d), _on_slot.bind(slot))
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			var col := VBoxContainer.new()
			col.custom_minimum_size = Vector2(120, 0)
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var h := GameData.hp_ratio(p)
			col.add_child(make_bar(p["hp"], d["hp"], Color(0.9, 0.25, 0.2).lerp(Color(0.3, 0.9, 0.35), h)))
			var lbl := UI.label("%d/%d" % [ceili(p["hp"]), d["hp"]], 12)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lbl)
			row.add_child(col)
			var c := GameData.repair_cost(p)
			if c > 0:
				row_button(row, "Fix $%d" % c, _on_repair.bind(p["uid"]), GameData.money >= c, 95)


func build_slot(slot: String) -> void:
	var kind: String = GameData.SLOT_KIND[slot]
	var bar := action_bar()
	row_button(bar, "< All parts", _on_slot.bind(""), true, 140)
	var title := UI.label(str(GameData.SLOT_NAMES[slot]).to_upper(), 20, Color(1.0, 0.8, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	var p := GameData.equipped_inst(slot)
	section("Fitted now:")
	if p.is_empty():
		make_row(part_icon({}), "Nothing", "This slot is empty.")
	else:
		var d := GameData.part_def(p["id"])
		var row := make_row(part_icon(d, GameData.hp_ratio(p)), d["name"], health_text(p))
		var c := GameData.repair_cost(p)
		if c > 0:
			row_button(row, "Fix $%d" % c, _on_repair.bind(p["uid"]), GameData.money >= c, 95)
		if slot != "reactor":
			row_button(row, "Remove", _on_unequip.bind(slot), true, 95)

	var options: Array = []
	var wrecks: Array = []
	for sp in GameData.spares():
		if GameData.part_def(sp["id"])["kind"] == kind:
			(wrecks if GameData.is_wreck(sp) else options).append(sp)
	section("Swap in from storage:" if not options.is_empty() else "No spare %s in storage." % str(GameData.KIND_NAMES[kind]).to_lower())
	for sp in options:
		var d := GameData.part_def(sp["id"])
		var row := make_row(part_icon(d, GameData.hp_ratio(sp)), d["name"] + ("" if d["shop"] else "  (rare)"), health_text(sp))
		row_button(row, "Fit", _on_equip.bind(sp["uid"], slot), true, 80)
		var v := GameData.sell_value(sp)
		row_button(row, "Sell $%d" % v if v > 0 else "Scrap", _on_sell.bind(sp["uid"]), true, 95)
	for sp in wrecks:
		var d := GameData.part_def(sp["id"])
		var c := GameData.repair_cost(sp)
		var row := make_row(part_icon(d, 0.0), d["name"] + "  (WRECKED)", "Rebuild it to use it again.")
		row_button(row, "Rebuild $%d" % c, _on_repair.bind(sp["uid"]), GameData.money >= c, 130)
		row_button(row, "Scrap", _on_sell.bind(sp["uid"]), true, 80)
	var for_sale: Array = GameData.shop_stock.filter(func(id): return GameData.part_def(id)["kind"] == kind)
	if not for_sale.is_empty():
		section("In the dealer's stock right now:")
		for id in for_sale:
			var d := GameData.part_def(id)
			var row := make_row(part_icon(d), d["name"], GameData.part_stat_text(d))
			row_button(row, "Buy $%d" % d["cost"], _on_buy.bind(id), GameData.money >= d["cost"], 115)
	var more := action_bar()
	row_button(more, "Dealer's stock", _on_go_shop.bind(kind), true, 200)
	if GameData.CUSTOM_KINDS.has(kind):
		row_button(more, "Design one in the Workshop", _on_go_workshop.bind(kind), true, 270)


func build_storage() -> void:
	var bar := action_bar()
	row_button(bar, "< All parts", _on_slot.bind(""), true, 140)
	var title := UI.label("STORAGE", 20, Color(1.0, 0.8, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var list := GameData.spares()
	if list.is_empty():
		section("Storage is empty. Parts you remove, extra purchases, trophies and salvage end up here.")
		return
	section("To fit a part, tap its slot on the robot. Here you can sell, scrap and rebuild.")
	for p in list:
		var d := GameData.part_def(p["id"])
		var wreck := GameData.is_wreck(p)
		var tag := "  (WRECKED)" if wreck else ("" if d["shop"] else "  (rare)")
		var row := make_row(part_icon(d, GameData.hp_ratio(p)), "%s%s  [%s]" % [d["name"], tag, d["kind"]], health_text(p))
		var c := GameData.repair_cost(p)
		if c > 0:
			row_button(row, ("Rebuild $%d" if wreck else "Fix $%d") % c, _on_repair.bind(p["uid"]), GameData.money >= c, 125)
		var v := GameData.sell_value(p)
		row_button(row, "Sell $%d" % v if v > 0 else "Scrap", _on_sell.bind(p["uid"]), true, 95)


# ---------------------------------------------------------------- popups (setups, paint)

func open_popup(title: String) -> VBoxContainer:
	close_popup()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.17)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	sb.border_color = Color(1.0, 0.45, 0.2)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := UI.label(title, 22, Color(1.0, 0.45, 0.2))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.button("Close", close_popup, 16, Vector2(90, 44)))
	return col


func close_popup() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _on_open_setups() -> void:
	var col := open_popup("SAVED SETUPS")
	section("A setup remembers your parts, chips and paint.", col)
	for k in GameData.SETUP_SLOTS:
		var st: Dictionary = GameData.setups[k]
		var row := action_bar(col)
		var name := UI.label("Setup %d: %s" % [k + 1, "empty" if st.is_empty() else "saved"], 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row_button(row, "Save here", _on_save_setup.bind(k), true, 120)
		row_button(row, "Load", _on_load_setup.bind(k), not st.is_empty(), 90)


const StoryScript = preload("res://story.gd")


## Design your pilot: they stand in your corner during fights and appear in the story.
func _on_open_pilot() -> void:
	var col := open_popup("YOUR PILOT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var face = StoryScript.Portrait.new()
	face.who = "YOU"
	face.custom_minimum_size = Vector2(190, 190)
	row.add_child(face)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 6)
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opts)
	var look: Dictionary = GameData.pilot_look
	var extras := []
	for e in ["glasses", "beard", "goggles", "long_hair", "scar"]:
		if look.get(e, false):
			extras.append(e)
	var lines := [
		["Skin", "skin", "%d/%d" % [GameData.PILOT_SKINS.find(look["skin"]) + 1, GameData.PILOT_SKINS.size()]],
		["Hair / hat color", "hair", ""],
		["Head", "hat", GameData.PILOT_HAT_NAMES.get(look["hat"], "?")],
		["Jacket", "outfit", ""],
		["Extras", "extras", "none" if extras.is_empty() else ", ".join(extras).replace("_", " ")],
	]
	for l in lines:
		var bar := action_bar(opts)
		var t := UI.label(l[0], 16)
		t.custom_minimum_size = Vector2(170, 0)
		bar.add_child(t)
		row_button(bar, "<", _on_pilot_change.bind(l[1], -1), true, 54)
		var v := UI.label(l[2], 15, Color(0.8, 0.8, 0.85))
		v.custom_minimum_size = Vector2(130, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if l[2] == "":
			var sw := ColorRect.new()
			sw.color = Color(look[l[1]])
			sw.custom_minimum_size = Vector2(130, 30)
			bar.add_child(sw)
		else:
			bar.add_child(v)
		row_button(bar, ">", _on_pilot_change.bind(l[1], 1), true, 54)
	var last := action_bar(opts)
	row_button(last, "Random", _on_pilot_random, true, 130)
	section("Your pilot stands in your corner during fights, working the controller and shouting at the robot.", col)


func _on_pilot_change(what: String, step: int) -> void:
	var look: Dictionary = GameData.pilot_look
	match what:
		"skin":
			look["skin"] = cycle(GameData.PILOT_SKINS, look["skin"], step)
		"hair", "outfit":
			look[what] = cycle(GameData.PILOT_COLORS, look[what], step)
		"hat":
			look["hat"] = cycle(GameData.PILOT_HATS, look["hat"], step)
		"extras":
			var cur := []
			for e in ["glasses", "beard", "goggles", "long_hair", "scar"]:
				if look.get(e, false):
					cur.append(e)
			var k := 0
			for i in GameData.PILOT_EXTRAS.size():
				if GameData.PILOT_EXTRAS[i] == cur:
					k = i
			var nxt: Array = GameData.PILOT_EXTRAS[posmod(k + step, GameData.PILOT_EXTRAS.size())]
			for e in ["glasses", "beard", "goggles", "long_hair", "scar"]:
				look[e] = nxt.has(e)
	Sfx.play("click")
	_on_open_pilot()


func cycle(list: Array, cur, step: int):
	var i := list.find(cur)
	return list[posmod((0 if i < 0 else i) + step, list.size())]


func _on_pilot_random() -> void:
	var look: Dictionary = GameData.pilot_look
	look["skin"] = GameData.PILOT_SKINS[randi() % GameData.PILOT_SKINS.size()]
	look["hair"] = GameData.PILOT_COLORS[randi() % GameData.PILOT_COLORS.size()]
	look["outfit"] = GameData.PILOT_COLORS[randi() % GameData.PILOT_COLORS.size()]
	look["hat"] = GameData.PILOT_HATS[randi() % GameData.PILOT_HATS.size()]
	var ex: Array = GameData.PILOT_EXTRAS[randi() % GameData.PILOT_EXTRAS.size()]
	for e in ["glasses", "beard", "goggles", "long_hair", "scar"]:
		look[e] = ex.has(e)
	Sfx.play("equip")
	_on_open_pilot()


func _on_open_paint() -> void:
	var col := open_popup("PAINT JOB")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for k in GameData.PAINTS.size():
		var paint: Dictionary = GameData.PAINTS[k]
		var b := UI.button(paint["name"], _on_paint.bind(k), 15, Vector2(110, 52))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(paint["color"]).darkened(0.35)
		sb.border_color = Color.WHITE if k == GameData.paint else Color(paint["color"])
		sb.set_border_width_all(4 if k == GameData.paint else 2)
		sb.set_corner_radius_all(6)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		grid.add_child(b)


# ---------------------------------------------------------------- SHOP

func build_shop_tab() -> void:
	var bar := action_bar()
	var info := UI.label("DEALER'S STOCK - it changes after every fight. Grab the good stuff while it's here!", 15, Color(1.0, 0.8, 0.4))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	row_button(bar, "Restock $%d" % GameData.REROLL_COST, _on_reroll, GameData.money >= GameData.REROLL_COST, 150)
	var stock: Array = GameData.shop_stock.duplicate()
	stock.sort_custom(func(a, b): return GameData.KINDS.find(GameData.part_def(a)["kind"]) < GameData.KINDS.find(GameData.part_def(b)["kind"]))
	if stock.is_empty():
		section("Sold out! New stock arrives after your next fight (or pay to restock now).")
	for id in stock:
		var d := GameData.part_def(id)
		var tag := "  [%s]" % str(d["kind"]).to_upper()
		var row := make_row(part_icon(d), d["name"] + tag, GameData.part_stat_text(d))
		row_button(row, "Buy $%d" % d["cost"], _on_buy.bind(id), GameData.money >= d["cost"], 115)
	section("SCRAP BIN - free junk, always there:")
	for d in GameData.scrap_bin():
		var row := make_row(part_icon(d), d["name"] + "  [%s]" % str(d["kind"]).to_upper(), GameData.part_stat_text(d))
		row_button(row, "Free", _on_buy.bind(d["id"]), true, 115)


# ---------------------------------------------------------------- WORKSHOP

func reset_workshop(kind: String) -> void:
	ws = {"kind": kind, "shape": GameData.custom_shapes(kind)[0], "color": GameData.CUSTOM_COLORS[0],
			"size": 1.0, "grade": 1, "alloc": {}, "gadget": ""}


func grade_points() -> int:
	return GameData.CUSTOM_GRADES[ws["grade"]]["points"]


func build_workshop() -> void:
	var d := GameData.custom_def(ws)
	var left := grade_points() - GameData.custom_points_used(ws)
	var head := make_row(part_icon(d), d["name"], GameData.part_stat_text(d))
	var forge := row_button(head, "FORGE $%d" % d["cost"], _on_forge, GameData.money >= d["cost"], 150)
	forge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

	section("Part type")
	var kinds := action_bar()
	for k in GameData.CUSTOM_KINDS:
		var b := row_button(kinds, str(k).capitalize(), _on_ws_kind.bind(k), true, 0)
		b.toggle_mode = true
		b.button_pressed = k == ws["kind"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section("Shape")
	var grid := GridContainer.new()
	grid.columns = 5
	list_box.add_child(grid)
	for sh in GameData.custom_shapes(ws["kind"]):
		var b := UI.button(str(sh).capitalize(), _on_ws_set.bind("shape", sh), 13, Vector2(100, 40))
		b.toggle_mode = true
		b.button_pressed = sh == ws["shape"]
		grid.add_child(b)

	section("Colour")
	var colors := GridContainer.new()
	colors.columns = 12
	list_box.add_child(colors)
	for c in GameData.CUSTOM_COLORS:
		var b := UI.button("", _on_ws_set.bind("color", c), 12, Vector2(40, 40))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c)
		sb.border_color = Color.WHITE if c == ws["color"] else Color(c).darkened(0.4)
		sb.set_border_width_all(4 if c == ws["color"] else 1)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		colors.add_child(b)

	section("Size and grade")
	var sizes := action_bar()
	for opt in [[0.85, "Small"], [1.0, "Normal"], [1.15, "Large"]]:
		var b := row_button(sizes, opt[1], _on_ws_set.bind("size", opt[0]), true, 0)
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(ws["size"], opt[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grades := action_bar()
	for g in GameData.CUSTOM_GRADES.size():
		var gr: Dictionary = GameData.CUSTOM_GRADES[g]
		var b := row_button(grades, "%s (%d pts)" % [gr["name"], gr["points"]], _on_ws_grade.bind(g), true, 0)
		b.toggle_mode = true
		b.button_pressed = g == ws["grade"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section("Stats - %d point%s left" % [left, "" if left == 1 else "s"])
	for stat in GameData.CUSTOM_KINDS[ws["kind"]]["stats"]:
		var n: int = ws["alloc"].get(stat, 0)
		var row := action_bar()
		var l := UI.label(STAT_NAMES[stat], 16)
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		row_button(row, "-", _on_ws_stat.bind(stat, -1), n > 0, 54)
		var bar := make_bar(n, GameData.CUSTOM_MAX_PER_STAT, Color(0.4, 0.8, 1.0))
		row.add_child(bar)
		row_button(row, "+", _on_ws_stat.bind(stat, 1), left > 0 and n < GameData.CUSTOM_MAX_PER_STAT, 54)

	section("Gadget (+$%d)" % GameData.CUSTOM_GADGET_PRICE)
	var gad := action_bar()
	var none := row_button(gad, "None", _on_ws_set.bind("gadget", ""), true, 0)
	none.toggle_mode = true
	none.button_pressed = ws["gadget"] == ""
	none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for g in GameData.CUSTOM_KINDS[ws["kind"]]["gadgets"]:
		var b := row_button(gad, Specials.GADGETS[g]["name"], _on_ws_set.bind("gadget", g), true, 0)
		b.toggle_mode = true
		b.button_pressed = ws["gadget"] == g
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ---------------------------------------------------------------- MOVES & CUPS

func build_moves_tab() -> void:
	section("Training chips teach special moves. Chip slots used: %d/%d (better heads have more). Inputs: → toward the enemy, ← away, ↓ down. Tap them quickly, then P or K."
			% [GameData.active_chips().size(), GameData.chip_slots()])
	for id in Specials.MOVES:
		var m: Dictionary = Specials.MOVES[id]
		if m.has("style"):
			continue   # signature moves come with the fighting style
		var owned := GameData.owned_chips.has(id)
		var installed := GameData.chips.has(id)
		var icon := ChipIcon.new()
		icon.installed = installed
		var row := make_row(icon, "%s    %s" % [m["name"], Specials.seq_text(m["seq"])], "%s  Cooldown %ds." % [m["desc"], int(m["cd"])])
		if not owned:
			row_button(row, "Buy $%d" % m["cost"], _on_buy_chip.bind(id), GameData.money >= m["cost"], 115)
		elif installed:
			row_button(row, "Remove", _on_uninstall_chip.bind(id), true, 115)
		else:
			row_button(row, "Install", _on_install_chip.bind(id), GameData.chips.size() < GameData.chip_slots(), 115)


func build_cups_tab() -> void:
	var c := GameData.circuit
	if not c.is_empty():
		var bar := action_bar()
		var l := UI.label("%s %s - fight %d of %d - cup prize $%d" % [c["name"], "★".repeat(int(c["tier"])),
				int(c["index"]) + 1, int(c["size"]), int(c["prize"])], 16, Color(1.0, 0.8, 0.4))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bar.add_child(l)
		row_button(bar, "Abandon", _on_abandon, true, 110)
		for i in range(int(c["index"]), int(c["size"])):
			var o := GameData.circuit_opponent(c, i)
			var specials: Array = []
			for id in o["specials"]:
				specials.append(Specials.MOVES[id]["name"])
			make_row(bot_preview(o), "%d. %s%s   ($%d)" % [i + 1, o["name"], "  [%s]" % o["team_label"] if o.has("team_label") else "", o["reward"]],
					"Moves: " + (", ".join(specials) if not specials.is_empty() else "none"))
		return
	section("Pick a championship. Robots are built at random for every cup!")
	if GameData.circuit_offers.is_empty():
		GameData.make_offers()
	for k in GameData.circuit_offers.size():
		var off: Dictionary = GameData.circuit_offers[k]
		var row := make_row(bot_preview(GameData.circuit_opponent(off, int(off["size"]) - 1)), "%s  %s" % [off["name"], "★".repeat(int(off["tier"]))],
				"%d fights. Cup prize $%d plus a free part. Final boss shown." % [int(off["size"]), int(off["prize"])])
		row_button(row, "Enter", _on_enter_cup.bind(k), true, 100)
	make_row(bot_preview(GameData.OPPONENTS[GameData.OPPONENTS.size() - 1]), "OVERLORD rematch",
			"Exhibition bout for $%d - the fight button starts it when no cup is active." % GameData.EXHIBITION_REWARD)


func build_team_tab() -> void:
	section("BACKUP ROBOTS are built from your spare parts and keep their damage, just like your robot. Main robot too beaten up and no cash to fix it? Use the Send button to put a backup robot in a 1-on-1 and earn some money. In cups they also fight beside you against tag teams and swarms.")
	var ms := GameData.stats()
	section("WEIGHT CLASSES: a robot fighting alone can be as heavy as its reactor allows. A team shares one heavyweight's power (%d): 2 robots get %d each, 3 get %d. Your robot now: %s, %d power. Mini parts are light, Heavy parts drink power - a team robot over its share gets overloaded."
			% [int(GameData.TEAM_POWER), int(GameData.team_share(2)), int(GameData.team_share(3)), GameData.weight_class(ms["power_used"]), ms["power_used"]])
	var bar := action_bar()
	var split: bool = GameData.settings.get("team_controls", "split") == "split"
	var b := row_button(bar, "Team controls: %s" % ("SPLIT - each robot gets its own movement pad" if split else "LINKED - every robot follows one pad"), _on_team_controls, true, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in GameData.wingmen.size():
		var w: Dictionary = GameData.wingmen[k]
		var name := GameData.wingman_name(k)
		var pv := RobotPreview.new()
		pv.anim = false
		var sub := "Not built yet. Tap Build to assemble it from your best spare parts (needs at least a head and a torso)."
		if not w.is_empty():
			pv.look = GameData.look_from_spec(GameData.player_spec(w, name))
			var names: Array = []
			for slot in GameData.SLOTS:
				if w.has(slot):
					var p := GameData.inst(int(w[slot]))
					if not p.is_empty():
						names.append("%s %d%%" % [GameData.part_def(p["id"])["name"], int(GameData.hp_ratio(p) * 100)])
			var ws := GameData.stats(w)
			var share := GameData.team_share(2)
			var power := "%s, %d power. In a team of 2 each robot gets %d power, in a team of 3 only %d%s. " % [
					GameData.weight_class(ws["power_used"]), ws["power_used"], int(share), int(GameData.team_share(3)),
					" - too heavy, it will be overloaded!" if ws["power_used"] > share else ""]
			sub = ("READY. " if GameData.wingman_ready(k) else "CAN'T FIGHT - missing a head or torso. ") + power + ", ".join(names)
		else:
			pv.look = {}
		var row := make_row(pv, name, sub)
		row_button(row, "Rebuild" if not w.is_empty() else "Build", _on_build_wingman.bind(k), true, 100)
		if not w.is_empty():
			var c := GameData.wingman_repair_cost(k)
			row_button(row, "Fix $%d" % c if c > 0 else "OK", _on_repair_wingman.bind(k), c > 0 and GameData.money >= c, 95)
			row_button(row, "Disband", _on_disband_wingman.bind(k), true, 100)


func _on_team_controls() -> void:
	var split: bool = GameData.settings.get("team_controls", "split") == "split"
	GameData.settings["team_controls"] = "linked" if split else "split"
	GameData.save_settings()
	say("Team controls: %s." % ("LINKED - all your robots follow one movement pad" if split else "SPLIT - one movement pad per robot, shared attack buttons. Move the pads in Settings > Edit controls"), "click")
	refresh()


func _on_build_wingman(k: int) -> void:
	say(GameData.build_wingman(k), "equip")
	refresh()


func _on_repair_wingman(k: int) -> void:
	say(GameData.repair_wingman(k), "repair")
	refresh()


func _on_disband_wingman(k: int) -> void:
	GameData.clear_wingman(k)
	say("%s's parts went back to your Spares." % GameData.wingman_name(k), "click")
	refresh()


func bot_preview(o: Dictionary) -> RobotPreview:
	var pv := RobotPreview.new()
	pv.look = GameData.look_from_spec(GameData.opponent_spec_from(o, 1.0))
	pv.facing = -1
	pv.anim = false
	return pv


# ---------------------------------------------------------------- actions

func _on_tab(t: String) -> void:
	tab = t
	if t == "Build":
		selected = ""
	refresh()


func _on_part_tapped(slot: String) -> void:
	tab = "Build"
	selected = slot
	Sfx.play("target")
	refresh()


func _on_slot(slot: String) -> void:
	selected = slot
	refresh()


func _on_shop_kind(kind: String) -> void:
	shop_kind = kind
	refresh()


func _on_go_shop(kind: String) -> void:
	tab = "Shop"
	shop_kind = kind
	refresh()


func _on_go_workshop(kind: String) -> void:
	tab = "Workshop"
	reset_workshop(kind)
	refresh()


func _on_reroll() -> void:
	var before := GameData.money
	say(GameData.reroll_stock(), "buy" if GameData.money < before else "error")
	refresh()


func _on_open_style() -> void:
	var col := open_popup("FIGHTING STYLE")
	section("Your style changes how ECHO fights and gives it a free signature move.", col)
	for id in Catalog.STYLES:
		var st: Dictionary = Catalog.STYLES[id]
		var sig: Dictionary = Specials.MOVES[st["signature"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UI.label(st["name"].to_upper() + ("   (current)" if id == GameData.style else ""), 18, Color(st["color"]).lightened(0.3)))
		var d := UI.label(st["desc"], 13)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(380, 0)
		text.add_child(d)
		text.add_child(UI.label("Signature: %s  %s" % [sig["name"], Specials.seq_text(sig["seq"])], 13, Color(0.5, 0.9, 1.0)))
		var b := UI.button("Pick", _on_pick_style.bind(id), 16, Vector2(90, 46))
		b.disabled = id == GameData.style
		row.add_child(b)


func _on_pick_style(id: String) -> void:
	GameData.style = id
	close_popup()
	say("Fighting style: %s. Signature move: %s." % [Catalog.STYLES[id]["name"], Specials.MOVES[Catalog.STYLES[id]["signature"]]["name"]], "equip")
	refresh()


func _on_open_scout() -> void:
	var msg := ""
	if not GameData.scouted():
		var before := GameData.money
		msg = GameData.do_scout()
		if GameData.money == before:
			say(msg, "error")
			return
		Sfx.play("buy")
		refresh()
	var o := GameData.current_opponent()
	var spec := GameData.current_opponent_spec()
	var col := open_popup("SCOUTING REPORT: " + str(o["name"]))
	if msg == "":
		msg = "Their crew spotted your scout! They %s." % GameData.scout["change"]["text"] if GameData.scout.get("spied_back", false) else "Clean scouting run - they never saw you."
	var m := UI.label(msg, 15, Color(1.0, 0.5, 0.3) if GameData.scout.get("spied_back", false) else Color(0.5, 1.0, 0.6))
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var pv := RobotPreview.new()
	pv.look = GameData.look_from_spec(spec)
	pv.facing = -1
	pv.custom_minimum_size = Vector2(200, 230)
	row.add_child(pv)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var st: String = spec.get("style", "striker")
	info.add_child(UI.label("Style: %s" % Catalog.STYLES[st]["name"], 16, Color(Catalog.STYLES[st]["color"]).lightened(0.3)))
	var weak := ""
	var weak_v := 1e9
	for slot in GameData.BODY_SLOTS:
		var p: Dictionary = spec["parts"].get(slot, {})
		if p.is_empty():
			continue
		var d := GameData.part_def(p["id"])
		var line := "%s: %s  (HP %d, armor %d)" % [GameData.SLOT_NAMES[slot], d["name"], int(p["max_hp"]), int(p["armor"])]
		if d.get("trait", "") != "":
			line += "  - " + Catalog.TRAITS[d["trait"]]["name"]
		if d["gimmick"] != "":
			line += "  - " + Specials.GADGETS[d["gimmick"]]["name"]
		var l := UI.label(line, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
		if slot != "torso":
			var v: float = p["max_hp"] / maxf(0.1, 1.0 - p["armor"] / 100.0) / (0.6 if slot.begins_with("head") else 1.0)
			if v < weak_v:
				weak_v = v
				weak = slot
	for slot in ["back", "reactor"]:
		if o["parts"].get(slot, "") != "":
			var d := GameData.part_def(o["parts"][slot])
			var extra := ""
			if d.get("trait", "") != "":
				extra = "  - " + Catalog.TRAITS[d["trait"]]["name"]
			elif d["gimmick"] != "":
				extra = "  - " + Specials.GADGETS[d["gimmick"]]["name"]
			info.add_child(UI.label("%s: %s%s" % [GameData.SLOT_NAMES[slot], d["name"], extra], 12))
	var moves: Array = []
	for id in o["specials"]:
		moves.append(Specials.MOVES[id]["name"])
	moves.append(Specials.MOVES[Catalog.STYLES[st]["signature"]]["name"] + " (signature)")
	var ml := UI.label("Moves: " + ", ".join(moves), 13, Color(0.5, 0.9, 1.0))
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ml)
	if weak != "":
		info.add_child(UI.label("Weak point: %s - aim there!" % GameData.SLOT_NAMES[weak], 15, Color(1.0, 0.9, 0.3)))


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
	say("Removed the %s. It's in Storage." % GameData.SLOT_NAMES[slot], "equip")
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


func _on_randomize() -> void:
	say(GameData.randomize_robot(), "equip")
	Sfx.play("repair", 0.2)
	refresh()


func _on_save_setup(k: int) -> void:
	say(GameData.save_setup(k), "buy")
	refresh()
	_on_open_setups()


func _on_load_setup(k: int) -> void:
	say(GameData.load_setup(k), "equip")
	close_popup()
	refresh()


func _on_sell(uid: int) -> void:
	say(GameData.sell(uid), "sell")
	refresh()


func _on_buy_chip(id: String) -> void:
	var before := GameData.money
	var text := GameData.buy_chip(id)
	say(text, "buy" if GameData.money < before else "error")
	refresh()


func _on_install_chip(id: String) -> void:
	say(GameData.install_chip(id), "equip")
	refresh()


func _on_uninstall_chip(id: String) -> void:
	say(GameData.uninstall_chip(id), "untarget")
	refresh()


func _on_paint(k: int) -> void:
	GameData.paint = k
	say("Painted %s." % GameData.PAINTS[k]["name"], "equip")
	refresh()
	_on_open_paint()


func _on_ws_kind(kind: String) -> void:
	reset_workshop(kind)
	refresh()


func _on_ws_set(key: String, value) -> void:
	ws[key] = value
	refresh()


func _on_ws_grade(g: int) -> void:
	ws["grade"] = g
	# trim points if the new grade has fewer
	while GameData.custom_points_used(ws) > grade_points():
		for k in ws["alloc"].keys():
			if ws["alloc"][k] > 0 and GameData.custom_points_used(ws) > grade_points():
				ws["alloc"][k] -= 1
	refresh()


func _on_ws_stat(stat: String, delta: int) -> void:
	ws["alloc"][stat] = clampi(ws["alloc"].get(stat, 0) + delta, 0, GameData.CUSTOM_MAX_PER_STAT)
	refresh()


func _on_forge() -> void:
	var before := GameData.money
	var text := GameData.forge_custom(ws)
	if GameData.money < before:
		say(text, "repair")
		Sfx.play("buy")
		reset_workshop(ws["kind"])
	else:
		say(text, "error")
	refresh()


func _on_enter_cup(k: int) -> void:
	GameData.enter_circuit(k)
	GameData.save_game()
	say("Entered the %s! First opponent: %s." % [GameData.circuit["name"], GameData.current_opponent()["name"]], "fight")
	refresh()


func _on_abandon() -> void:
	GameData.abandon_circuit()
	GameData.save_game()
	say("Left the championship.", "error")
	refresh()


func _on_save() -> void:
	if GameData.save_game():
		say("Game saved.", "buy")
	else:
		say("Couldn't save!", "error")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _on_send() -> void:
	var options: Array = [-1]
	for k in GameData.wingmen.size():
		if GameData.wingman_ready(k):
			options.append(k)
	GameData.sending = options[(options.find(GameData.sending) + 1) % options.size()]
	say("%s will fight the next 1-on-1. %s" % [GameData.sending_name(),
			"Its damage stays on it - your main robot sits this one out." if GameData.sending >= 0 else ""], "click")
	refresh()


func _on_fight() -> void:
	GameData.save_game()
	if GameData.fight_mode() == "story" and GameData.queue_story("pre_%d" % GameData.fight_index, "res://fight.tscn"):
		get_tree().change_scene_to_file("res://story.tscn")
	else:
		get_tree().change_scene_to_file("res://fight.tscn")
