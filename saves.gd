extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const UI = preload("res://ui.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotPreview = preload("res://robot_preview.gd")
const StoryScript = preload("res://story.gd")
## Save slots. GameData.slot_mode decides what we're doing:
##   "new"  - pick a slot for a new game (empty, or overwrite), then name your pilot and robot
##   "load" - load or delete a save

var mode := "load"
var col: VBoxContainer
var confirm := {}      # slot -> action waiting for a second tap
var chosen_slot := 1
var pilot_edit: LineEdit
var robot_edit: LineEdit
var pilot_box: VBoxContainer   # the pilot editor (left)
var robot_box: VBoxContainer   # the robot editor (right)
var robot_preview: RobotPreview


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
	naming = false
	clear()
	title("NEW GAME: pick a save slot" if mode == "new" else "LOAD GAME")
	# eight slots: they scroll
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(900, minf(get_viewport_rect().size.y - 190.0 * UI.SCALE, 8 * 74.0 * UI.SCALE))
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for slot in range(1, GameData.SAVE_SLOTS + 1):
		var info := GameData.slot_info(slot)
		var panel := PanelContainer.new()
		list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if info.is_empty():
			text.add_child(UI.label(tr("Slot %d: empty") % slot, 20))
		elif info.get("broken", false):
			text.add_child(UI.label(tr("Slot %d: damaged file") % slot, 20, Color(1.0, 0.5, 0.4)))
		else:
			text.add_child(UI.label(tr("Slot %d: %s & %s") % [slot, info["pilot"], info["robot"]], 20))
			var cups := tr(", %d cups") % info["cups"] if info["cups"] > 0 else ""
			text.add_child(UI.label(tr("AUTOSAVE: %s%s  ·  %s  ·  %s") % [info["progress"], cups, GameData.money_text(info["money"]), info["saved"]], 14, Color(0.72, 0.72, 0.78)))
			var mi := GameData.slot_info(slot, true)
			if not mi.is_empty() and not mi.get("broken", false) and mode != "new":
				var mrow := HBoxContainer.new()
				mrow.add_theme_constant_override("separation", 8)
				text.add_child(mrow)
				var ml := UI.label(tr("YOUR SAVE: %s  ·  %s  ·  %s") % [mi["progress"], GameData.money_text(mi["money"]), mi["saved"]], 14, Color(0.55, 1.0, 0.65))
				ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				mrow.add_child(ml)
				mrow.add_child(UI.button("Load your save", _on_load.bind(slot, true), 15, Vector2(190, 44)))
		var waiting: String = confirm.get(slot, "")
		if mode == "new":
			if info.is_empty():
				row.add_child(UI.button("Use", _on_pick.bind(slot), 18, Vector2(150, 52)))
			else:
				row.add_child(UI.button("Sure? Tap again" if waiting == "overwrite" else "Overwrite", _on_overwrite.bind(slot), 18, Vector2(190, 52)))
		else:
			var load_b := UI.button("Load latest", _on_load.bind(slot), 18, Vector2(150, 52))
			load_b.disabled = info.is_empty() or info.get("broken", false)
			row.add_child(load_b)
			var del := UI.button("Sure? Tap again" if waiting == "delete" else "Delete", _on_delete.bind(slot), 18, Vector2(190, 52))
			del.disabled = info.is_empty()
			row.add_child(del)
	col.add_child(UI.button("Back", _on_back, 20, Vector2(0, 52)))


## New game: name your pilot and robot, and build both. Names, faces and robots each have their
## own Random button - rolling one never changes the others.
func show_names() -> void:
	naming = true
	clear()
	GameData.new_game()   # a fresh draft: the default pilot and ECHO in its usual junk
	title(tr("NEW GAME: slot %d") % chosen_slot)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 16)
	col.add_child(names)
	pilot_edit = name_row("Pilot", pilot_name_default(), _on_random_pilot, names)
	robot_edit = name_row("Robot", GameData.DEFAULT_ROBOT, _on_random_robot, names)
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 16)
	col.add_child(panels)
	pilot_box = VBoxContainer.new()
	pilot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels.add_child(panel_around(pilot_box))
	robot_box = VBoxContainer.new()
	robot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels.add_child(panel_around(robot_box))
	build_pilot_editor()
	build_robot_editor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var back := UI.button("Back", show_slots, 20, Vector2(200, 52))
	row.add_child(back)
	# how hard: the same settings as Menu > Settings > Difficulty, right here before you start
	diff_button = UI.button("", _on_open_difficulty, 18, Vector2(330, 52))
	row.add_child(diff_button)
	update_diff_button()
	var start := UI.button("START", _on_start, 24, Vector2(0, 52))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start)


var diff_box: VBoxContainer
var diff_button: Button
var diff_cover: Control
var naming := false   # (1.111) on the names / looks page (Back goes to the slots)
const SETTINGS = preload("res://settings.gd")


func update_diff_button() -> void:
	var s := GameData.settings
	var pk: Dictionary = GameData.PECKING[clampi(int(s.get("pecking", 1)), 0, GameData.PECKING.size() - 1)]
	diff_button.text = tr("Difficulty: %s · %s ›") % [tr(SETTINGS.DIFF_NAMES[int(s["difficulty"])]), tr(pk["name"])]


## Difficulty, picked before the first fight: the CPU, Gus's coaching, the money you start with
## and the Pecking Order, in a window over the new-game screen. Each button cycles; the same
## choices live in Settings > Difficulty.
func _on_open_difficulty() -> void:
	Sfx.play("click")
	diff_cover = ColorRect.new()
	(diff_cover as ColorRect).color = Color(0.06, 0.06, 0.09, 0.97)
	diff_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	diff_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(diff_cover)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	diff_cover.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	var t := UI.label(tr("DIFFICULTY"), 28, Color(1.0, 0.45, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	diff_box = VBoxContainer.new()
	diff_box.add_theme_constant_override("separation", 8)
	box.add_child(diff_box)
	var note := UI.label(tr("Pecking Order: how much tougher and harder hitting each part grade is. Underdog lets a good pilot punch above their grade; Brutal means a robot two grades up flattens you in seconds.") + "\n" + tr("You can change all of this later in Settings > Difficulty."), 13, Color(0.65, 0.65, 0.72))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	box.add_child(UI.button("Done", _on_close_difficulty, 19, Vector2(560, 52)))
	build_difficulty()


func _on_close_difficulty() -> void:
	if diff_cover:
		diff_cover.queue_free()
		diff_cover = null
	update_diff_button()


func build_difficulty() -> void:
	for c in diff_box.get_children():
		c.queue_free()
	var s := GameData.settings
	var pk: Dictionary = GameData.PECKING[clampi(int(s.get("pecking", 1)), 0, GameData.PECKING.size() - 1)]
	var items := [
		[tr("CPU difficulty: %s") % tr(SETTINGS.DIFF_NAMES[int(s["difficulty"])]), _on_diff_step.bind("difficulty")],
		[tr("Auto-aim: %s") % tr(SETTINGS.AIM_NAMES[clampi(int(s.get("auto_aim", 0)), 0, 1)]), _on_diff_step.bind("auto_aim")],
		[tr("Gus's coaching: %s") % tr(SETTINGS.COACH_NAMES[clampi(int(s.get("coaching", 2)), 0, 3)]), _on_diff_step.bind("coaching")],
		[tr("Starting money: %s (new games)") % GameData.money_text(int(s.get("start_money", GameData.START_MONEY))), _on_diff_step.bind("start_money")],
		[tr("Rent & food: %s") % (tr("none") if int(s.get("living_cost", GameData.LIVING_COST)) == 0 else tr("$%d a month") % int(s.get("living_cost", GameData.LIVING_COST))), _on_diff_step.bind("living_cost")],
		[tr("Pecking Order: %s (x%.1f a grade)") % [tr(pk["name"]), float(pk["k"])], _on_diff_step.bind("pecking")],
	]
	for it in items:
		diff_box.add_child(UI.button(it[0], it[1], 19, Vector2(560, 52)))


func _on_diff_step(key: String) -> void:
	var s := GameData.settings
	match key:
		"difficulty":
			s["difficulty"] = (int(s["difficulty"]) + 1) % SETTINGS.DIFF_NAMES.size()
		"coaching":
			s["coaching"] = (int(s.get("coaching", 2)) + 1) % SETTINGS.COACH_NAMES.size()
		"auto_aim":
			s["auto_aim"] = 1 - clampi(int(s.get("auto_aim", 0)), 0, 1)
		"start_money":
			var opts: Array = GameData.START_MONEY_OPTIONS
			s["start_money"] = opts[(opts.find(int(s.get("start_money", GameData.START_MONEY))) + 1) % opts.size()]
			GameData.money = int(s["start_money"])
		"living_cost":
			var lopts: Array = GameData.LIVING_COST_OPTIONS
			s["living_cost"] = lopts[(lopts.find(int(s.get("living_cost", GameData.LIVING_COST))) + 1) % lopts.size()]
		"pecking":
			GameData.set_pecking((int(s.get("pecking", 1)) + 1) % GameData.PECKING.size())
	GameData.save_settings()
	Sfx.play("click")
	build_difficulty()


func pilot_name_default() -> String:
	return GameData.random_pilot_name()


func panel_around(inner: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p


## A "< value >" row. value_color draws a color swatch instead of text.
func choice_row(parent: Control, label: String, value: String, cb_prev: Callable, cb_next: Callable, swatch: String = "") -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	parent.add_child(bar)
	var t := UI.label(label, 14)
	t.custom_minimum_size = Vector2(62, 0)
	bar.add_child(t)
	bar.add_child(UI.button("<", cb_prev, 16, Vector2(40, 32)))
	if swatch != "":
		var sw := ColorRect.new()
		sw.color = Color(swatch)
		sw.custom_minimum_size = Vector2(96, 24)
		sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(sw)
	else:
		var v := UI.label(value, fitting_size(value, 13, 104.0), Color(0.85, 0.85, 0.9))
		v.custom_minimum_size = Vector2(110, 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.clip_text = true
		bar.add_child(v)
	bar.add_child(UI.button(">", cb_next, 16, Vector2(40, 32)))


## Shrink a label's font until the text fits the box (long values like "Long hair + scar").
func fitting_size(text: String, size: int, width: float) -> int:
	var f := ThemeDB.fallback_font
	while size > 9 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * UI.SCALE)).x > width:
		size -= 1
	return size


# ---------------------------------------------------------------- pilot

const PILOT_ROWS := [["Skin", "skin"], ["Eyes", "eyes"], ["Hair", "hair"], ["Jacket", "outfit"],
		["Head", "hat"], ["Beard", "beard"], ["Glasses", "glasses"], ["Extras", "extras"]]


func build_pilot_editor() -> void:
	for c in pilot_box.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pilot_box.add_child(row)
	var face = StoryScript.Portrait.new()
	face.who = "YOU"
	face.custom_minimum_size = Vector2(165, 0)
	face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(face)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rows)
	var look: Dictionary = GameData.pilot_look
	for r in PILOT_ROWS:
		var key: String = r[1]
		var value := ""
		var swatch := ""
		match key:
			"skin":
				swatch = look["skin"]
			"eyes":
				value = tr(PilotArt.EYE_NAMES[maxi(0, PilotArt.EYES.find(look.get("eyes", PilotArt.EYES[0])))])
			"hair", "outfit":
				swatch = look[key]
			"hat":
				value = tr(PilotArt.HAT_NAMES.get(look["hat"], "?"))
			"beard":
				value = tr(PilotArt.BEARD_NAMES.get(look["beard"], "?"))
			"glasses":
				value = tr(PilotArt.GLASSES_NAMES.get(look["glasses"], "?"))
			"extras":
				var ex := []
				for e in ["long_hair", "scar"]:
					if look.get(e, false):
						ex.append(e.replace("_", " "))
				value = "none" if ex.is_empty() else " + ".join(ex)
		choice_row(rows, r[0], value, _on_pilot_step.bind(key, -1), _on_pilot_step.bind(key, 1), swatch)
	pilot_box.add_child(UI.button("Random face", _on_random_face, 16, Vector2(0, 40)))


func cycle(list: Array, cur, step: int):
	var i := list.find(cur)
	return list[posmod((0 if i < 0 else i) + step, list.size())]


func _on_pilot_step(key: String, step: int) -> void:
	var look: Dictionary = GameData.pilot_look
	match key:
		"skin":
			look["skin"] = cycle(PilotArt.SKINS, look["skin"], step)
		"eyes":
			look["eyes"] = cycle(PilotArt.EYES, look.get("eyes", PilotArt.EYES[0]), step)
		"hair", "outfit":
			look[key] = cycle(PilotArt.COLORS, look[key], step)
		"hat":
			look["hat"] = cycle(PilotArt.HATS, look["hat"], step)
		"beard":
			look["beard"] = cycle(PilotArt.BEARDS, look["beard"], step)
		"glasses":
			look["glasses"] = cycle(PilotArt.GLASSES, look["glasses"], step)
		"extras":
			var cur := []
			for e in ["long_hair", "scar"]:
				if look.get(e, false):
					cur.append(e)
			var k := 0
			for i in PilotArt.EXTRAS.size():
				if PilotArt.EXTRAS[i] == cur:
					k = i
			var nxt: Array = PilotArt.EXTRAS[posmod(k + step, PilotArt.EXTRAS.size())]
			for e in ["long_hair", "scar"]:
				look[e] = nxt.has(e)
	Sfx.play("click")
	build_pilot_editor()


func _on_random_face() -> void:
	PilotArt.randomize_look(GameData.pilot_look)
	Sfx.play("equip")
	build_pilot_editor()


# ---------------------------------------------------------------- robot

const ROBOT_ROWS := [["Head", "head"], ["Body", "torso"], ["Arms", "arm"], ["Legs", "leg"]]


func build_robot_editor() -> void:
	for c in robot_box.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	robot_box.add_child(row)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rows)
	robot_preview = RobotPreview.new()
	robot_preview.custom_minimum_size = Vector2(140, 0)
	robot_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	robot_preview.look = GameData.player_look()
	row.add_child(robot_preview)
	for r in ROBOT_ROWS:
		var kind: String = r[1]
		choice_row(rows, r[0], GameData.part_def(GameData.starter_id(kind))["name"], _on_robot_step.bind(kind, -1), _on_robot_step.bind(kind, 1))
	choice_row(rows, "Paint", tr(GameData.PAINTS[GameData.paint]["name"]), _on_paint_step.bind(-1), _on_paint_step.bind(1), "")
	var note := UI.label("All junk to start with. Every choice is just as weak. Better parts come from the scrapyard and the shop.", 12, Color(0.65, 0.65, 0.72))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(note)
	robot_box.add_child(UI.button("Random robot", _on_random_build, 16, Vector2(0, 40)))


func _on_robot_step(kind: String, step: int) -> void:
	GameData.set_starter(kind, cycle(GameData.STARTER_OPTIONS[kind], GameData.starter_id(kind), step))
	Sfx.play("equip")
	build_robot_editor()


func _on_paint_step(step: int) -> void:
	GameData.paint = posmod(GameData.paint + step, GameData.PAINTS.size())
	Sfx.play("click")
	build_robot_editor()


func _on_random_build() -> void:
	for kind in GameData.STARTER_OPTIONS:
		var opts: Array = GameData.STARTER_OPTIONS[kind]
		GameData.set_starter(kind, opts[randi() % opts.size()])
	GameData.paint = randi() % GameData.PAINTS.size()
	Sfx.play("equip")
	build_robot_editor()


func name_row(label: String, value: String, random_cb: Callable, parent: Control) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var l := UI.label(label, 20)
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.max_length = 16
	edit.add_theme_font_size_override("font_size", UI.tsz(22))
	edit.custom_minimum_size = Vector2(0, 48 * UI.SCALE)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.select_all_on_focus = true
	row.add_child(edit)
	row.add_child(UI.button("Random", random_cb, 16, Vector2(110, 48)))
	return edit


func _on_pick(slot: int) -> void:
	chosen_slot = slot
	# a new game builds the whole world (hundreds of pilots and their robots): cover the wait
	await Loading.run(show_names)


func _on_overwrite(slot: int) -> void:
	if confirm.get(slot, "") == "overwrite":
		_on_pick(slot)
		return
	confirm = {slot: "overwrite"}
	Sfx.play("error")
	show_slots()


## Loading a save: a bar at the bottom fills up while the save is read and the garage loads
## in the background (the garage scene is the slow part the first time).
func _on_load(slot: int, mine: bool = false) -> void:
	const GARAGE := "res://garage.tscn"
	var cover := ColorRect.new()
	cover.color = Color(0.07, 0.07, 0.1, 0.96)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var title := UI.label(tr("LOADING..."), 30, Color(1.0, 0.45, 0.2))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.42
	title.anchor_bottom = 0.42
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(title)
	var bar = load("res://garage_ui.gd").BlockBar.new()   # loading fills up in blocks, like every other bar
	bar.anchor_left = 0.08
	bar.anchor_right = 0.92
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -70.0 * UI.SCALE
	bar.offset_bottom = -40.0 * UI.SCALE
	bar.height = 24.0
	bar.n = 25
	bar.color = Color(1.0, 0.55, 0.2)
	cover.add_child(bar)
	var pct := UI.label("0%", 20, Color(0.9, 0.9, 0.95))
	pct.anchor_left = 0.0
	pct.anchor_right = 1.0
	pct.anchor_top = 1.0
	pct.anchor_bottom = 1.0
	pct.offset_top = -110.0 * UI.SCALE
	pct.offset_bottom = -74.0 * UI.SCALE
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(pct)
	var show := func(v: float) -> void:
		bar.set_fill(v / 4.0)
		pct.text = "%d%%" % int(v)
	# the garage scene loads in the background while the save is read
	ResourceLoader.load_threaded_request(GARAGE)
	show.call(3.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := GameData.load_game(slot, mine)
	if err != "":
		cover.queue_free()
		var l := UI.label(err, 16, Color(1.0, 0.6, 0.4))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		Sfx.play("error")
		return
	var shown := 25.0
	show.call(shown)
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(GARAGE, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			get_tree().change_scene_to_file(GARAGE)
			return
		var target := 25.0 + 70.0 * float(progress[0] if not progress.is_empty() else 0.0)
		shown = maxf(shown, minf(target, shown + 2.5))   # fill smoothly, never backwards
		show.call(shown)
		await get_tree().process_frame
	show.call(100.0)
	await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(GARAGE)
	get_tree().change_scene_to_packed(packed)


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
	# the draft built on this screen (face, robot parts, paint) is the new game
	var pilot := pilot_edit.text.strip_edges()
	var robot := robot_edit.text.strip_edges().to_upper()
	GameData.save_slot = chosen_slot
	GameData.pilot_name = pilot if pilot != "" else GameData.random_pilot_name()
	GameData.robot_name = robot if robot != "" else GameData.DEFAULT_ROBOT
	GameData.save_game()
	# the opening cutscene, then straight into Old Pike's course
	GameData.opening_replay = false
	Loading.go("res://opening.tscn")


## (1.111) Android Back: the difficulty window, then the slots, then the main menu.
func on_back() -> void:
	if diff_cover:
		_on_close_difficulty()
	elif naming:
		show_slots()
	else:
		_on_back()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
