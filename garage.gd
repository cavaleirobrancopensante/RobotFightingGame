extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const Catalog = preload("res://catalog.gd")
const PartIcon = preload("res://part_icon.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotPreview = preload("res://robot_preview.gd")
const Specials = preload("res://specials.gd")
const UI = preload("res://ui.gd")
const MoveDemo = preload("res://move_demo.gd")
## Garage, organised in sections:
##   BUILD    - your robot slot by slot. Tap a slot (or a part on the robot picture) to swap,
##              repair or remove it. Setups, Paint and Storage open as popups.
##   SHOP     - buy parts by type
##   WORKSHOP - design your own custom part (costs a bit more)
##   MOVES    - special-move training chips
##   CUPS     - championships, once the story is done

const POWER_COLOR := Color(0.25, 0.8, 1.0)   # electric blue: power, same as the bar in fights
const STAT_NAMES := {"hp": "Health", "armor": "Armor", "damage": "Damage", "speed": "Speed", "aim": "Aim", "chips": "Chip slots"}

var tab := "Bay"            # section: Bay, Storage, Parts (Get Parts), Season, Crew
var selected := ""          # Bay > Robot: "" = all slots, or the slot that is open
var segs_on := {"Bay": "robot", "Parts": "scrap", "Crew": "backups"}   # each section's toggle (Season uses season_view)
var shop_kind := "arm"
var shop_filter := "all"      # Shop/Storage category dropdowns: "all", a part kind, "chip" or "pilot"
var storage_filter := "all"
var ws := {}                # workshop design in progress
var title_label: Label
var money_label: Label
var stats_box: VBoxContainer
var list_box: VBoxContainer
var scroll: ScrollContainer
var tabs_box: HBoxContainer
var msg_label: Label
var preview: RobotPreview
var backdrop: Control
var scene := "build"          # which garage scene is behind the menus (see garage_art.gd)
var paint_open := false
var spark_at := -99.0
var dig_at := -99.0
var dig_found := ""
const GarageArt = preload("res://garage_art.gd")
const Career = preload("res://career.gd")
const TAB_SCENES := {"Build": "build", "Season": "build", "Shop": "shop", "Workshop": "workshop", "Moves": "moves", "Team": "team",
		"Cups": "cups"}


## The living scene behind the whole garage screen. The robot panel is see-through, so the robot
## stands in the scene with Gus and the pilot around it.
class Backdrop extends Control:
	const ZOOM := 1.15
	var garage
	var t := 0.0
	var _rt := 0.0

	func _process(delta: float) -> void:
		t += delta
		_rt -= delta
		if _rt <= 0.0 and is_visible_in_tree():
			_rt = 1.0 / 30.0
			queue_redraw()

	func _draw() -> void:
		if garage == null or garage.preview == null:
			return
		var pv: Control = garage.preview
		# (positions before the zoom below is applied)
		var pv_at: Vector2 = pv.global_position - pv.pivot_offset * (Vector2.ONE - pv.scale)
		var my_at: Vector2 = global_position - pivot_offset * (Vector2.ONE - scale)
		var stage := Rect2(pv_at - my_at, pv.size)
		# the bay is drawn zoomed in a bit, anchored at the left of the robot panel, a little below the middle, so Gus,
		# the pilot and the scoreboard read better; the robot preview gets the same zoom
		var pivot := Vector2(6.0, pv.size.y * 0.62)
		if pv.scale.x != ZOOM or pv.pivot_offset != pivot:
			pv.pivot_offset = pivot
			pv.scale = Vector2(ZOOM, ZOOM)
		if scale.x != ZOOM or pivot_offset != stage.position + pivot:
			pivot_offset = stage.position + pivot
			scale = Vector2(ZOOM, ZOOM)
		var info: Dictionary = garage.scene_info()
		GarageArt.draw_back(self, size, stage, garage.scene, t, info)
		GarageArt.draw_front(self, stage, garage.scene, t, info, pv._base, pv.robot_height)
var fight_button: Button
var body_map: BodyMap
var rail_box: VBoxContainer
var date_button: Button
var repair_button: Button
var left_col: VBoxContainer
var bubble
const GUI = preload("res://garage_ui.gd")


## The little green body next to the fight button (same as in the arena): what's hurt, what's missing.
class BodyMap extends Control:
	var health := {}

	func _draw() -> void:
		var k := minf(size.x / 56.0, size.y / 64.0)
		var at := Vector2(size.x * 0.5, (size.y - 60.0 * k) * 0.5 + 2.0 * k)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.13))
		for slot in RobotPreview.MAP_BOXES:
			if not health.has(slot):
				continue
			var r: Rect2 = RobotPreview.MAP_BOXES[slot]
			r = Rect2(at + r.position * k, r.size * k)
			var h: float = health[slot]
			if h < 0.0:
				draw_rect(r, Color(0.15, 0.15, 0.17))
				draw_rect(r, Color(1.0, 0.25, 0.2), false, 1.5)
				continue
			draw_rect(r, Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.9, 0.35), h) if h < 1.0 else Color(0.3, 0.9, 0.35))
var scout_button: Button
var send_button: Button
var overlay: Control
var last_view := ""


class ControllerIcon extends Control:
	var kind := "gamepad"
	var t := 0.0

	var _redraw_t := 0.0

	func _process(delta: float) -> void:
		t += delta
		_redraw_t -= delta
		if _redraw_t <= 0.0 and is_visible_in_tree():
			_redraw_t = 1.0 / 30.0   # 30 fps is plenty for a little animated icon
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.17))
		PilotArt.draw_controller(self, size * 0.5 + Vector2(0, 4), minf(size.x, size.y) / 30.0, kind, int(t * 2.0) % 2 == 0, t)


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
	# first time in the bay after a fight: Gus explains how things work around here.
	# Everything else that opens up waits with a star; Gus explains it when you first tap it.
	if GameData.wins + GameData.losses > 0 and GameData.queue_story("first_garage", "res://garage.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://story.tscn")
		return
	if GameData.open_tab != "" and tab_list().has(GameData.open_tab):
		tab = GameData.open_tab
	GameData.open_tab = ""
	Sfx.music("garage")
	reset_workshop("arm")
	theme = GUI.theme()
	backdrop = Backdrop.new()
	backdrop.garage = self
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var whole := HBoxContainer.new()
	whole.set_anchors_preset(Control.PRESET_FULL_RECT)
	whole.add_theme_constant_override("separation", 0)
	add_child(whole)

	# the side rail: one button per section, Menu at the foot (under the left thumb)
	var rail_panel := PanelContainer.new()
	var rs := GUI.box(Color(0.055, 0.055, 0.075, 0.97), 0, 6)
	rs.border_color = Color(0.17, 0.17, 0.22)
	rs.border_width_right = 1
	rail_panel.add_theme_stylebox_override("panel", rs)
	whole.add_child(rail_panel)
	rail_box = VBoxContainer.new()
	rail_box.add_theme_constant_override("separation", 4)
	rail_panel.add_child(rail_box)

	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in [["left", 12], ["right", 12], ["top", 6], ["bottom", 6]]:
		m.add_theme_constant_override("margin_" + side[0], side[1])
	whole.add_child(m)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	m.add_child(root)

	# top strip: the date (tap it for the calendar), room for ads in the middle, money on the right
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	date_button = Button.new()
	date_button.focus_mode = Control.FOCUS_NONE
	date_button.add_theme_font_override("font", GUI.num())
	date_button.add_theme_font_size_override("font_size", 24)
	var ds := GUI.box(Color(0.043, 0.055, 0.043), 18, 4)
	ds.content_margin_left = 16
	ds.content_margin_right = 16
	ds.border_color = Color(0.17, 0.23, 0.18)
	ds.set_border_width_all(1)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		date_button.add_theme_stylebox_override(st, ds)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		date_button.add_theme_color_override(c, GUI.GREEN)
	date_button.pressed.connect(func(): _on_tab("Season"); season_view = "calendar"; refresh())
	top.add_child(date_button)
	title_label = UI.label("", 22)   # kept empty: the middle of the top strip is space for ads
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	money_label = GUI.readout("", 32, GUI.AMBER)
	top.add_child(money_label)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)

	# left: the robot in the scene, and its stats
	left_col = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(420, 0)
	left_col.add_theme_constant_override("separation", 4)
	mid.add_child(left_col)
	preview = RobotPreview.new()
	preview.interactive = true
	preview.custom_minimum_size = Vector2(300, 110)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.part_tapped.connect(_on_part_tapped)
	preview.background_tapped.connect(_on_backdrop_tapped)
	left_col.add_child(preview)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	var sp := GUI.box(Color(0.03, 0.04, 0.03, 0.85), 10, 8)
	sp.content_margin_left = 12
	sp.content_margin_right = 12
	sp.border_color = Color(0.14, 0.19, 0.16)
	sp.set_border_width_all(1)
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", sp)
	stats_panel.add_child(stats_box)
	left_col.add_child(stats_panel)

	# right: the section's toggle bar and its list
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	var right_glass := PanelContainer.new()
	right_glass.add_theme_stylebox_override("panel", GUI.box(GUI.PANEL, 14, 8))
	right_glass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_glass.add_child(right)
	mid.add_child(right_glass)
	var seg_panel := PanelContainer.new()
	seg_panel.add_theme_stylebox_override("panel", GUI.box(Color(0.1, 0.1, 0.133), 10, 4))
	right.add_child(seg_panel)
	tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 4)
	seg_panel.add_child(tabs_box)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.drag_scroll(scroll, func(): return overlay != null and is_instance_valid(overlay) and overlay.visible)
	right.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 5)
	scroll.add_child(list_box)

	# Gus talks in a speech bubble over the scene (results, tips, what just happened)
	bubble = GUI.GusBubble.new()
	bubble.label.add_theme_font_override("font", GUI.bold())
	bubble.visible = false
	add_child(bubble)
	msg_label = bubble.label

	# bottom: repair, which robot goes in, the damage map and the FIGHT button
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	repair_button = UI.button("", _on_repair_all, 15, Vector2(170, 46))
	bottom.add_child(repair_button)
	send_button = UI.button("", _on_send, 14, Vector2(150, 46))
	bottom.add_child(send_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	scout_button = UI.button("", _on_open_scout, 17, Vector2(150, 48))
	scout_button.visible = false
	bottom.add_child(scout_button)
	body_map = BodyMap.new()
	body_map.custom_minimum_size = Vector2(52, 62)
	body_map.tooltip_text = "Green = healthy, red = hurt, dark with a red edge = missing."
	bottom.add_child(body_map)
	var hz := GUI.HazardFrame.new()
	bottom.add_child(hz)
	fight_button = UI.button("", _on_fight, 18, Vector2(300, 46))
	fight_button.add_theme_font_override("font", GUI.stencil())
	var fs := GUI.box(GUI.YELLOW, 8, 4)
	var fp := GUI.box(Color(0.84, 0.67, 0.13), 8, 4)
	var fd := GUI.box(Color(0.35, 0.33, 0.27), 8, 4)
	for st in [["normal", fs], ["hover", fs], ["pressed", fp], ["hover_pressed", fp], ["disabled", fd]]:
		fight_button.add_theme_stylebox_override(st[0], st[1])
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		fight_button.add_theme_color_override(c, Color(0.08, 0.08, 0.08))
	fight_button.add_theme_color_override("font_disabled_color", Color(0.75, 0.73, 0.65))
	hz.add_child(fight_button)

	show_last_result()
	var tip := GameData.garage_tip()
	if tip != "":
		msg_label.text = tip if msg_label.text == "" else msg_label.text + "\n" + tip
	say(msg_label.text.replace("\n" + tr("GUS: "), "\n"))
	refresh()
	# back from Gus explaining something: open it for you
	var act := GameData.open_action
	GameData.open_action = ""
	match act:
		"setups":
			_on_open_setups()
		"scout":
			open_fight_popup()   # Gus explained scouting: back to the pre-fight window
		"":
			pass
		_:
			set_seg(act)
			refresh()

## The rail's sections, as they unlock. "Parts" is shown as Get Parts.
func tab_list() -> Array:
	var t := ["Bay", "Storage", "Parts"]
	if GameData.unlocked("season"):
		t.append("Season")
	if GameData.team_unlocked() or GameData.unlocked("pilot"):
		t.append("Crew")
	return t


const SECTION_LABELS := {"Bay": "Bay", "Storage": "Storage", "Parts": "Get Parts", "Season": "Season", "Crew": "Crew"}
const SECTION_ICONS := {"Bay": "bay", "Storage": "storage", "Parts": "parts", "Season": "season", "Crew": "crew"}
## Where each feature lives now: [section, toggle]. Gus's unlock scene returns you there.
const FEATURE_PLACE := {"scrapyard": ["Parts", "scrap"], "storage": ["Storage", ""], "style": ["Bay", "style"],
		"shop": ["Parts", "dealer"], "season": ["Season", "calendar"], "scout": ["", "scout"], "moves": ["Bay", "chips"],
		"cups": ["Season", "cups"], "team": ["Crew", "backups"], "workshop": ["Parts", "order"], "pilot": ["Crew", "pilot"],
		"paint": ["Bay", "style"], "setups": ["Bay", "setups"], "randomize": ["Bay", "robot"]}


## A section's toggle bar: [key, label, feature that unlocks it (for its star)].
func segs_of(t: String) -> Array:
	var out: Array = []
	match t:
		"Bay":
			out.append(["robot", tr("Robot"), ""])
			if GameData.unlocked("moves"):
				out.append(["chips", tr("Chips %d/%d") % [GameData.active_chips().size(), GameData.chip_slots()], "moves"])
			if GameData.unlocked("style"):
				out.append(["style", tr("Style & paint") if GameData.unlocked("paint") else tr("Style"), "style"])
		"Parts":
			out.append(["scrap", tr("Scrapyard"), "scrapyard"])
			if GameData.unlocked("shop"):
				out.append(["dealer", tr("Dealer"), "shop"])
			if GameData.unlocked("workshop"):
				out.append(["order", tr("Made to order"), "workshop"])
		"Season":
			out.append(["calendar", tr("Calendar"), ""])
			out.append(["table", tr("Standings"), ""])
			if GameData.cups_unlocked():
				out.append(["cups", tr("Cups"), "cups"])
			if GameData.bet_target() != "":
				out.append(["bets", tr("Bets"), ""])
			out.append(["pilots", tr("Pilots"), ""])
		"Crew":
			if GameData.team_unlocked():
				out.append(["backups", tr("Backups"), "team"])
			if GameData.unlocked("pilot"):
				out.append(["pilot", tr("Pilot"), "pilot"])
	return out


func seg() -> String:
	return season_view if tab == "Season" else str(segs_on.get(tab, ""))


## Switch the current section's toggle (falls back to the first one if that toggle isn't there yet).
func set_seg(key: String) -> void:
	var keys: Array = segs_of(tab).map(func(x): return x[0])
	if not keys.has(key):
		key = keys[0] if not keys.is_empty() else ""
	if tab == "Season":
		season_view = key
	else:
		segs_on[tab] = key


## Does a section (or toggle) still carry a star? New features Gus hasn't explained, or a fresh dig.
func seg_new(key: String, feature: String) -> bool:
	if key == "scrap" and GameData.digs_left > 0:
		return true
	if key == "style" and GameData.unlocked("paint") and GameData.is_new("paint"):
		return true
	return feature != "" and GameData.is_new(feature)


func section_new(t: String) -> bool:
	match t:
		"Storage":
			return GameData.is_new("storage")
		"Season":
			if GameData.is_new("season"):
				return true
		"Bay":
			if (GameData.unlocked("setups") and GameData.is_new("setups")) or (GameData.unlocked("randomize") and GameData.is_new("randomize")):
				return true
	for sg in segs_of(t):
		if seg_new(sg[0], sg[2]):
			return true
	return false


## The rail, rebuilt on every refresh (sections appear as they unlock).
func build_rail() -> void:
	for c in rail_box.get_children():
		c.queue_free()
	for t in tab_list():
		var b := GUI.RailButton.new()
		b.kind = SECTION_ICONS[t]
		b.label = tr(SECTION_LABELS[t])
		b.on = t == tab
		b.star = section_new(t)
		b.font = GUI.head()
		b.pressed.connect(func(): Sfx.play("click", 0.05); _on_tab(t))
		rail_box.add_child(b)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_box.add_child(gap)
	var mb := GUI.RailButton.new()
	mb.kind = "menu"
	mb.label = tr("Menu")
	mb.font = GUI.head()
	mb.pressed.connect(func(): Sfx.play("click", 0.05); _on_menu())
	rail_box.add_child(mb)


## The toggle bar along the top of the list.
func build_seg_bar() -> void:
	for c in tabs_box.get_children():
		c.queue_free()
	var list := segs_of(tab)
	if list.is_empty() or tab == "Storage":
		var t := GUI.text(tr("STORAGE") if tab == "Storage" else tr(SECTION_LABELS[tab]).to_upper(), 18, GUI.TEXT, "headb")
		t.custom_minimum_size = Vector2(0, 40)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs_box.add_child(t)
		return
	for sg in list:
		var on: bool = sg[0] == seg()
		var b := UI.button(str(sg[1]) + (" ★" if seg_new(sg[0], sg[2]) else ""), _on_seg.bind(sg[0]), 13, Vector2(0, 34))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := GUI.seg_style(on)
		for k in ["normal", "disabled"]:
			b.add_theme_stylebox_override(k, st[0])
		for k in ["hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, st[1])
		b.add_theme_color_override("font_color", Color.WHITE if on else GUI.MUTED)
		tabs_box.add_child(b)
	if tab == "Bay" and seg() == "robot":
		if GameData.unlocked("setups"):
			tabs_box.add_child(UI.button(star(tr("Setups ▾"), "setups"), _on_open_setups, 12, Vector2(96, 34)))
		if GameData.unlocked("randomize"):
			tabs_box.add_child(UI.button(star(tr("Randomize"), "randomize"), _on_randomize, 12, Vector2(100, 34)))


func _on_seg(key: String) -> void:
	for sg in segs_of(tab):
		if sg[0] == key:
			var feature: String = sg[2]
			if key == "style" and not GameData.is_new("style") and GameData.unlocked("paint") and GameData.is_new("paint"):
				feature = "paint"
			if feature != "" and gus_explains(feature):
				return
	set_seg(key)
	if tab == "Bay":
		selected = ""
	var tip := GameData.tab_tip({"scrap": "Scrapyard", "dealer": "Shop", "order": "Workshop", "chips": "Moves"}.get(key, ""))
	if tip != "":
		say(tip)
	refresh()

func show_last_result() -> void:
	var r := GameData.last_result
	var bills := ""
	if GameData.bills_note > 0:
		bills = tr(" End of the month: rent and food, -$%d.") % GameData.bills_note
		GameData.bills_note = 0
	if r.is_empty():
		msg_label.text = bills.strip_edges()
		return
	if r.get("quit", false):
		msg_label.text = tr("You walked out on %s. No pay, and the dents came home with you.") % r["opponent"]
	else:
		var bits: Array = []
		if r.get("champion", false):
			bits.append(tr("CHAMPION! You beat %s!") % r["opponent"])
		elif r["won"]:
			bits.append(tr("Beat %s!") % r["opponent"])
		else:
			bits.append(tr("Lost to %s.") % r["opponent"])
		var total: int = r["reward"] + r.get("bonus", 0)
		if total < 0:
			bits.append(tr("Paid the winner $%d.") % -total)
		elif total > 0:
			bits.append(tr("Earned $%d.") % total)
		var bt: Dictionary = r.get("bets", {})
		if not bt.is_empty() and int(bt.get("staked", 0)) > 0:
			bits.append(tr("Bets: %s.") % ", ".join(bt["lines"]))
		if r.get("cup_done", "") != "":
			bits.append(tr("CUP OVER - %s.") % r["cup_done"])
		if r.get("event_done", "") != "":
			bits.append(tr("SEASON OVER - %s. See the Season tab.") % str(r["event_done"]).trim_suffix("!").trim_suffix("."))
		if r.get("trophy", "") != "":
			bits.append(tr("Trophy part: %s.") % r["trophy"])
		if not r.get("lost", []).is_empty():
			bits.append(tr("Lost: %s.") % ", ".join(r["lost"]))
		if not r.get("wrecked", []).is_empty():
			bits.append(tr("Wrecked: %s (rebuild in Storage).") % ", ".join(r["wrecked"]))
		if not r.get("salvaged", []).is_empty():
			bits.append(tr("Salvaged: %s.") % ", ".join(r["salvaged"]))
		if r.get("out_of_debt", false):
			bits.append(tr("OUT OF THE HOLE - you don't owe Gus a cent!"))
		msg_label.text = " ".join(bits) + bills
	GameData.last_result = {}


func say(text: String, sound: String = "") -> void:
	bubble.say(text.trim_prefix(tr("GUS: ")).trim_prefix("GUS: "))
	if sound != "":
		Sfx.play(sound)


## Gus's bubble sits over the top of the scene, next to the robot.
func _process(_delta: float) -> void:
	if bubble and bubble.visible and left_col:
		bubble.position = left_col.global_position + Vector2(14, 10)
		bubble.size.x = 0


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	money_label.text = GameData.money_text(GameData.money)
	money_label.add_theme_color_override("font_color", GUI.RED if GameData.money < 0 else GUI.AMBER)
	date_button.text = (tr("WED · WK %d") if GameData.day == "wed" else tr("SAT · WK %d")) % GameData.week
	var total := GameData.repair_all_cost()
	repair_button.text = tr("Repair all $%d") % total if total > 0 else tr("All repaired")
	repair_button.disabled = total <= 0   # (short on cash? pressing it has Gus explain)
	repair_button.add_theme_color_override("font_color", GUI.AMBER)
	var mode := GameData.fight_mode()
	if mode == "open":
		GameData.start_pickup()   # a quiet week: there's always a pickup fight down at the scrapyard
		mode = GameData.fight_mode()
	title_label.text = ""   # the top strip is kept free (space for ads); the date lives in the Season calendar
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
	send_button.text = tr("Send: %s") % (tr("main robot") if GameData.sending < 0 else GameData.WINGMAN_NAMES[GameData.sending])
	if not GameData.can_send():
		fight_button.text = "Need a head and a torso"
		fight_button.disabled = true
	else:
		fight_button.disabled = false
		var label: String = {"story": "FIGHT: %s ($%d)", "circuit": "CUP FIGHT: %s ($%d)", "exhibition": "REMATCH: %s ($%d)",
				"pickup": "PICKUP FIGHT: %s ($%d)"}.get(mode, "FIGHT: %s ($%d)")
		fight_button.text = tr(label) % [o["name"], GameData.current_reward()]
		if o.has("team_label"):
			fight_button.text += tr(" - %s") % o["team_label"]
		if GameData.sending >= 0 and not GameData.is_team_fight():
			fight_button.text = tr("%s fights %s ($%d)") % [GameData.sending_name(), o["name"], GameData.current_reward()]
		elif not core.is_empty() and GameData.hp_ratio(core) < 0.35:
			fight_button.text += tr(" - core damaged!")

	scout_button.visible = false   # scouting lives in the pre-fight popup now
	scout_button.text = star(tr("Scout report") if GameData.scouted() else tr("Scout $%d") % GameData.scout_cost(), "scout")
	preview.look = GameData.player_look()
	body_map.health = body_health()
	body_map.queue_redraw()
	if not tab_list().has(tab):
		tab = "Bay"
	set_seg(seg())
	set_scene_for_tab()
	preview.highlight = selected if tab == "Bay" and seg() == "robot" else ""
	refresh_stats()
	build_rail()
	build_seg_bar()

	# keep the scroll position when the same view is rebuilt (e.g. tapping + in the workshop)
	var view := tab + "/" + seg() + "/" + selected + "/" + shop_kind
	var keep := scroll.scroll_vertical if view == last_view else 0
	last_view = view
	for c in list_box.get_children():
		c.queue_free()
	match tab:
		"Bay":
			match seg():
				"chips":
					build_moves_tab()
				"style":
					build_style_view()
				_:
					if selected == "":
						build_overview()
					else:
						build_slot(selected)
		"Storage":
			build_storage()
		"Parts":
			match seg():
				"dealer":
					build_dealer()
				"order":
					build_order()
				_:
					build_scrapyard_tab()
		"Season":
			build_season_tab()
		"Crew":
			if seg() == "pilot":
				build_pilot_view()
			else:
				build_team_tab()
	GameData.request_save()
	scroll.set_deferred("scroll_vertical", keep)


func refresh_stats() -> void:
	for c in stats_box.get_children():
		c.queue_free()
	var s := GameData.stats()
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	stats_box.add_child(grid)
	var over: bool = s["power_used"] > s["power_output"]
	# core: blocks of 10 HP, like every part; power: one block per point of power
	stat_cell(grid, "Core", _seg(s["core"], s["core_max"], 10.0, GUI.GREEN), "%d/%d" % [s["core"], s["core_max"]], GUI.GREEN)
	stat_cell(grid, "Power", _seg(s["power_used"], s["power_output"], 1.0, GUI.RED if over else GUI.CYAN), "%d/%d" % [s["power_used"], s["power_output"]], GUI.RED if over else GUI.CYAN)
	stat_cell(grid, "Damage", make_bar(s["damage"], 170, GUI.RED), "%d%%" % s["damage"], Color(1.0, 0.6, 0.5))
	stat_cell(grid, "Speed", make_bar(s["speed"], 150, GUI.CYAN), "%d%%" % s["speed"], GUI.CYAN)
	if over:
		stats_box.add_child(GUI.text(tr("OVERLOADED: %d%% performance!") % int(s["efficiency"] * 100), 11, GUI.RED, "headb"))
	var spare: int = maxi(0, int(s["power_output"]) - int(s["power_used"]))
	var tank: float = GameData.fight_tank(float(s["power_output"]), float(s["power_used"])) * (1.25 if GameData.style == "tank" else 1.0)
	var pl := GUI.text(tr("%s · fight power %d (+%d unused)") % [tr(GameData.weight_class(s["power_used"])), int(tank), spare], 10, GUI.MUTED, "headb")
	pl.tooltip_text = "In a fight your power output is your tank, and power your parts don't use is added on top. Every move spends some; it refills when you stop attacking. Empty = burnout."
	stats_box.add_child(pl)


func _seg(value: float, maximum: float, unit: float, col: Color) -> Control:
	var b := GUI.SegBar.new()
	b.setup(value * 10.0 / unit, maximum * 10.0 / unit, col)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func stat_cell(grid: GridContainer, title: String, bar: Control, value: String, col: Color) -> void:
	var t := GUI.text(tr(title).to_upper(), 10, GUI.MUTED, "headb")
	t.custom_minimum_size = Vector2(52, 0)
	grid.add_child(t)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(bar)
	var v := GUI.readout(value, 17, col)
	v.custom_minimum_size = Vector2(52, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(v)


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

func make_row(icon: Control, title: String, subtitle: String, parent: Control = null, tag: String = "") -> HBoxContainer:
	var panel := PanelContainer.new()
	(parent if parent else list_box).add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(row_text(title, subtitle, tag, true))
	return row


## A part's name (with its slot as a small tag) over one line of details.
func row_text(title: String, subtitle: String, tag: String, wrap: bool) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tag != "":
		var tg := GUI.text(tag.to_upper(), 10, GUI.MUTED, "headb")
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(tg)
	var t := GUI.text(title, 15, GUI.TEXT, "bold")
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(t)
	info.add_child(line)
	if subtitle != "":
		var sl := GUI.text(subtitle, 11, Color(0.68, 0.68, 0.75))
		if wrap:
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			sl.clip_text = true
		info.add_child(sl)
	return info


## A whole-row button (tap anywhere on it), with an icon, two lines of text and extra widgets.
func make_tap_row(icon: Control, title: String, subtitle: String, cb: Callable, tag: String = "") -> HBoxContainer:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05))
	b.pressed.connect(cb)
	var n := GUI.box(GUI.ROW, 10, 4)
	var h := GUI.box(GUI.ROW.lightened(0.05), 10, 4)
	var pr := GUI.box(GUI.ROW, 10, 4)
	pr.border_color = GUI.YELLOW
	pr.set_border_width_all(2)
	for st in [["normal", n], ["hover", h], ["pressed", pr], ["hover_pressed", pr]]:
		b.add_theme_stylebox_override(st[0], st[1])
	list_box.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(row_text(title, subtitle, tag, false))
	return row


## Health as a block bar (1 block = 10 HP) with the numbers glowing next to it.
func hp_widget(p: Dictionary) -> HBoxContainer:
	var d := GameData.part_def(p["id"])
	var h := GameData.hp_ratio(p)
	var col := GUI.GREEN if h > 0.7 else (GUI.AMBER if h > 0.4 else GUI.RED)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := GUI.SegBar.new()
	bar.setup(float(p["hp"]), float(d["hp"]), col)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)
	var n := GUI.readout("%d/%d" % [ceili(p["hp"]), d["hp"]], 17, col)
	n.custom_minimum_size = Vector2(62, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(n)
	return box


## A part's details without its health (the block bar shows that).
func part_info(d: Dictionary) -> String:
	var t := GameData.part_stat_text(d)
	var hp := tr("HP %d") % d["hp"]
	if t.begins_with(hp):
		t = t.substr(hp.length()).strip_edges()
	return t.replace("  ", " · ")


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


## A "Show: All parts (10) v" dropdown. entries: [[key, label, count], ...] - empty categories are left out.
## Returns the key actually in use (falls back to "all" when the chosen category ran empty).
func category_dropdown(entries: Array, current: String, cb: Callable, bar: HBoxContainer = null) -> String:
	var shown: Array = entries.filter(func(e): return e[0] == "all" or int(e[2]) > 0)
	if not shown.any(func(e): return e[0] == current):
		current = "all"
	if bar == null:
		bar = action_bar()
	var l := UI.label(tr("Show:"), 16, Color(0.8, 0.8, 0.85))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(260, 48)
	ob.add_theme_font_size_override("font_size", 17)
	ob.get_popup().add_theme_font_size_override("font_size", 22)
	ob.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for i in shown.size():
		ob.add_item(tr("%s (%d)") % [tr(shown[i][1]), int(shown[i][2])], i)
		if shown[i][0] == current:
			ob.select(i)
	ob.item_selected.connect(func(i): cb.call(shown[i][0]))
	bar.add_child(ob)
	return current


func kind_entries(kinds: Array, all_label: String) -> Array:
	var out := [["all", all_label, kinds.size()]]
	for k in GameData.KINDS:
		out.append([k, GameData.KIND_NAMES[k], kinds.count(k)])
	return out


func _on_shop_filter(key: String) -> void:
	shop_filter = key
	refresh()


var selling := false        # Storage: ticking parts to sell several at once
var sell_picks: Array = []


func _on_select_mode() -> void:
	selling = not selling
	sell_picks = []
	refresh()


func _on_pick_sell(on: bool, uid: int) -> void:
	if on and not sell_picks.has(uid):
		sell_picks.append(uid)
	elif not on:
		sell_picks.erase(uid)
	refresh()


## Sell everything ticked - after one "are you sure?".
func _on_sell_picked() -> void:
	var total := 0
	var names: Array = []
	for uid in sell_picks:
		var p := GameData.inst(uid)
		if not p.is_empty():
			total += GameData.sell_value(p)
			names.append(GameData.part_def(p["id"])["name"])
	var col := open_popup(tr("SELL THESE?"))
	var l := UI.label(tr("Sell %d parts for $%d? They're gone for good.") % [names.size(), total] + "\n" + ", ".join(names), 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var nav := action_bar(col)
	var yes := UI.button(tr("Sell all $%d") % total, _on_sell_picked_confirmed, 17, Vector2(0, 48))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(yes)
	var no := UI.button("Keep them", close_popup, 17, Vector2(0, 48))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(no)


func _on_sell_picked_confirmed() -> void:
	close_popup()
	var total := 0
	for uid in sell_picks.duplicate():
		var p := GameData.inst(uid)
		if p.is_empty():
			continue
		total += GameData.sell_value(p)
		GameData.sell(uid)
	sell_picks = []
	selling = false
	say(tr("Sold for $%d.") % total, "buy")
	refresh()


## Jump to a section (and one of its toggles).
func go_to(t: String, key: String = "") -> void:
	tab = t
	if key != "":
		set_seg(key)
	if t == "Bay" and (key == "" or key == "robot"):
		selected = ""
	refresh()


func _on_storage_filter(key: String) -> void:
	storage_filter = key
	refresh()


func health_text(p: Dictionary) -> String:
	var d := GameData.part_def(p["id"])
	if GameData.UNDAMAGEABLE.has(d["kind"]):
		return GameData.part_stat_text(d)
	return GameData.part_stat_text(d, float(p["hp"]))


# ---------------------------------------------------------------- BUILD

func build_overview() -> void:
	var key := HBoxContainer.new()
	key.alignment = BoxContainer.ALIGNMENT_END
	key.add_theme_constant_override("separation", 6)
	list_box.add_child(key)
	var blk := ColorRect.new()
	blk.color = GUI.GREEN
	blk.custom_minimum_size = Vector2(6, 11)
	blk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.add_child(blk)
	key.add_child(GUI.text(tr("= 10 HP"), 10, GUI.MUTED, "headb"))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(100, 0)
	key.add_child(pad)
	for slot in GameData.SLOTS:
		if not GameData.slot_available(slot):
			continue   # extra heads/arms need a torso with mounts for them
		var p := GameData.equipped_inst(slot)
		var slot_name: String = tr(GameData.SLOT_NAMES[slot])
		if p.is_empty():
			var opt: bool = slot == "back" or GameData.EXTRA_SLOTS.has(slot)
			make_tap_row(part_icon({}), tr("Empty"), tr("Tap to fit or buy one") + (tr(" (optional)") if opt else ""), _on_slot.bind(slot), slot_name)
			continue
		var d := GameData.part_def(p["id"])
		var row := make_tap_row(part_icon(d, GameData.hp_ratio(p)), d["name"], part_info(d), _on_slot.bind(slot), slot_name)
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(p))
			var c := GameData.repair_cost(p)
			if c > 0:
				var fb := UI.button(tr("Fix $%d") % c, _on_repair.bind(p["uid"]), 13, Vector2(80, 36))
				fb.disabled = not GameData.can_repair(c)
				fb.add_theme_color_override("font_color", GUI.AMBER)
				fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(fb)
			else:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(80 * UI.SCALE, 0)
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(gap)
		else:
			var gap2 := Control.new()
			gap2.custom_minimum_size = Vector2(80 * UI.SCALE, 0)
			gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap2)


func build_slot(slot: String) -> void:
	var kind: String = GameData.SLOT_KIND[slot]
	var bar := action_bar()
	row_button(bar, tr("‹ Robot"), _on_slot.bind(""), true, 120)
	var title := GUI.text(tr(GameData.SLOT_NAMES[slot]).to_upper(), 18, GUI.YELLOW, "headb")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	var p := GameData.equipped_inst(slot)
	section("Fitted now:")
	if p.is_empty():
		make_row(part_icon({}), "Nothing", "This slot is empty.")
	else:
		var d := GameData.part_def(p["id"])
		var row := make_row(part_icon(d, GameData.hp_ratio(p)), d["name"], part_info(d))
		var c := GameData.repair_cost(p)
		if c > 0:
			row_button(row, tr("Fix $%d") % c, _on_repair.bind(p["uid"]), GameData.can_repair(c), 95).add_theme_color_override("font_color", GUI.AMBER)
		if slot != "reactor":
			row_button(row, "Remove", _on_unequip.bind(slot), true, 95)
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			var hw := hp_widget(p)
			row.add_child(hw)
			row.move_child(hw, 2)

	var options: Array = []
	var wrecks: Array = []
	for sp in GameData.spares():
		if GameData.part_def(sp["id"])["kind"] == kind:
			(wrecks if GameData.is_wreck(sp) else options).append(sp)
	section("Swap in from storage:" if not options.is_empty() else tr("No spare %s in storage.") % str(GameData.KIND_NAMES[kind]).to_lower())
	for sp in options:
		var d := GameData.part_def(sp["id"])
		var row := make_row(part_icon(d, GameData.hp_ratio(sp)), d["name"] + ("" if d["shop"] else tr("  (rare)")), part_info(d))
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(sp))
		row_button(row, "Fit", _on_equip.bind(sp["uid"], slot), true, 80)
		var v := GameData.sell_value(sp)
		row_button(row, tr("Sell $%d") % v, _on_sell.bind(sp["uid"]), true, 95)
	for sp in wrecks:
		var d := GameData.part_def(sp["id"])
		var c := GameData.repair_cost(sp)
		var row := make_row(part_icon(d, 0.0), d["name"] + tr("  (WRECKED)"), "Rebuild it to use it again.")
		row_button(row, tr("Rebuild $%d") % c, _on_repair.bind(sp["uid"]), GameData.can_repair(c), 130)
		row_button(row, tr("Sell $%d") % GameData.sell_value(sp), _on_sell.bind(sp["uid"]), true, 95)
	# never stuck: if this slot is empty and there's nothing to fit, Gus has some junk lying around
	if p.is_empty() and options.is_empty() and slot in ["head", "torso"]:
		section("Gus's emergency junk:")
		var jd := GameData.part_def(GameData.STARTER[slot])
		var row := make_row(part_icon(jd, 0.4), jd["name"], "Rusty and half broken, but it'll get you in the ring. Free.")
		row_button(row, "Take", _on_emergency_junk.bind(slot), true, 95)
	var for_sale: Array = GameData.shop_stock.filter(func(id): return GameData.part_def(id)["kind"] == kind)
	if not GameData.unlocked("shop"):
		for_sale = []
	if not for_sale.is_empty():
		section("In the dealer's stock right now:")
		for id in for_sale:
			var d := GameData.part_def(id)
			var row := make_row(part_icon(d), d["name"], GameData.part_stat_text(d))
			row_button(row, tr("Buy $%d") % d["cost"], _on_buy.bind(id), GameData.money >= d["cost"], 115)
	var more := action_bar()
	if GameData.unlocked("shop"):
		row_button(more, "Dealer's stock", _on_go_shop.bind(kind), true, 200)
	else:
		row_button(more, "Dig in the Scrapyard", go_to.bind("Parts", "scrap"), true, 220)
	if GameData.CUSTOM_KINDS.has(kind) and GameData.unlocked("workshop"):
		row_button(more, "Order your own part", _on_go_workshop.bind(kind), true, 270)


func build_storage() -> void:
	var list := GameData.spares()
	if list.is_empty():
		section("Storage is empty. Parts you remove, extra purchases, trophies and salvage end up here.")
		return
	var kinds: Array = list.map(func(p): return GameData.part_def(p["id"])["kind"])
	var top_bar := action_bar()
	storage_filter = category_dropdown(kind_entries(kinds, "All parts"), storage_filter, _on_storage_filter, top_bar)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(gap)
	if selling:
		var total := 0
		for uid in sell_picks:
			var sp := GameData.inst(uid)
			if not sp.is_empty():
				total += GameData.sell_value(sp)
		var sb := row_button(top_bar, tr("Sell %d · $%d") % [sell_picks.size(), total], _on_sell_picked, not sell_picks.is_empty(), 150)
		sb.add_theme_color_override("font_color", GUI.AMBER)
		row_button(top_bar, "Cancel", _on_select_mode, true, 90)
		section("Tick the parts to sell, then tap Sell.")
	else:
		row_button(top_bar, "Select", _on_select_mode, true, 90)
	for p in list:
		var d := GameData.part_def(p["id"])
		if storage_filter != "all" and d["kind"] != storage_filter:
			continue
		var wreck := GameData.is_wreck(p)
		var tag := tr("  (WRECKED)") if wreck else ("" if d["shop"] else tr("  (rare)"))
		var row := make_row(part_icon(d, GameData.hp_ratio(p)), str(d["name"]) + tag, part_info(d), null, tr(str(d["kind"]).to_upper()))
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(p))
		if selling:
			var cb := CheckBox.new()
			cb.button_pressed = sell_picks.has(p["uid"])
			cb.focus_mode = Control.FOCUS_NONE
			cb.text = tr("$%d") % GameData.sell_value(p)
			cb.toggled.connect(_on_pick_sell.bind(p["uid"]))
			row.add_child(cb)
			continue
		var fits: Array = GameData.SLOTS.filter(func(sl): return GameData.SLOT_KIND[sl] == d["kind"] and GameData.slot_available(sl))
		if not fits.is_empty():
			row_button(row, "Fit", _on_fit_choose.bind(p["uid"], fits), not wreck, 70)
		var c := GameData.repair_cost(p)
		if c > 0:
			var fx := row_button(row, (tr("Rebuild $%d") if wreck else tr("Fix $%d")) % c, _on_repair.bind(p["uid"]), GameData.can_repair(c), 110)
			fx.add_theme_color_override("font_color", GUI.AMBER)
		var v := GameData.sell_value(p)
		row_button(row, tr("Sell $%d") % v, _on_sell.bind(p["uid"]), true, 90)


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
	sb.bg_color = Color(0.098, 0.098, 0.129)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	sb.border_color = Color(0.227, 0.227, 0.282)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(560, 0)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := GUI.text(tr(title), 22, GUI.YELLOW, "headb")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.button("Close", close_popup, 16, Vector2(90, 44)))
	col.add_child(GUI.HazardStrip.new())
	return col


## A dark see-through panel around a control, so the garage scene shows behind the menus.
func glass(inner: Control, alpha: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, alpha)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p


func scene_info() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var backup := {}
	for k in GameData.wingmen.size():
		if GameData.wingman_ready(k):
			backup = GameData.look_from_spec(GameData.player_spec(GameData.wingmen[k], GameData.wingman_name(k)))
			break
	return {"pilot": GameData.pilot_look, "paint": Color(GameData.PAINTS[GameData.paint]["color"]),
			"spark": now - spark_at, "dig": now - dig_at, "found": dig_found,
			"medals": GameData.trophies, "backup": backup, "stats": GameData.career_stats,
			"wins": GameData.wins, "losses": GameData.losses, "champion": GameData.champion}


var fight_popup_open := false


## Keyboard (computers): Esc closes a window, F gets you to the pre-fight window, Enter there starts the fight.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if overlay:
				close_popup()
				get_viewport().set_input_as_handled()
		KEY_F:
			if overlay == null and not fight_button.disabled:
				_on_fight()
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if fight_popup_open and overlay:
				get_viewport().set_input_as_handled()
				_start_fight()


func close_popup() -> void:
	fight_popup_open = false
	if paint_open:
		paint_open = false
		set_scene_for_tab()
	if overlay:
		overlay.queue_free()
		overlay = null


func _on_open_setups() -> void:
	if gus_explains("setups"):
		return
	var col := open_popup(tr("SAVED SETUPS"))
	section("A setup remembers your parts, chips and paint.", col)
	for k in GameData.SETUP_SLOTS:
		var st: Dictionary = GameData.setups[k]
		var row := action_bar(col)
		var name := UI.label(tr("Setup %d: %s") % [k + 1, "empty" if st.is_empty() else "saved"], 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row_button(row, "Save here", _on_save_setup.bind(k), true, 120)
		row_button(row, "Load", _on_load_setup.bind(k), not st.is_empty(), 90)


const StoryScript = preload("res://story.gd")


## Design your pilot: they stand in your corner during fights and appear in the story.
func _on_open_pilot() -> void:
	go_to("Crew", "pilot")


func build_pilot_view() -> void:
	var col := list_box
	section("Your pilot stands in your corner during fights and shows up in the story.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var face = StoryScript.Portrait.new()
	face.who = "YOU"
	face.custom_minimum_size = Vector2(170, 210)
	row.add_child(face)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	row.add_child(grid)
	var look: Dictionary = GameData.pilot_look
	var extras := []
	for e in ["long_hair", "scar"]:
		if look.get(e, false):
			extras.append(e.replace("_", " "))
	var eye_i := maxi(0, PilotArt.EYES.find(look.get("eyes", PilotArt.EYES[0])))
	var lines := [
		["Skin", "skin", tr("%d / %d") % [PilotArt.SKINS.find(look["skin"]) + 1, PilotArt.SKINS.size()], ""],
		["Eyes", "eyes", tr(PilotArt.EYE_NAMES[eye_i]), look.get("eyes", "")],
		["Hair & hat", "hair", "", look["hair"]],
		["Jacket", "outfit", "", look["outfit"]],
		["Headwear", "hat", tr(PilotArt.HAT_NAMES.get(look["hat"], "?")), ""],
		["Beard", "beard", tr(PilotArt.BEARD_NAMES.get(look["beard"], "?")), ""],
		["Glasses", "glasses", tr(PilotArt.GLASSES_NAMES.get(look["glasses"], "?")), ""],
		["Extras", "extras", "none" if extras.is_empty() else " + ".join(extras), ""],
	]
	for l in lines:
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 4)
		grid.add_child(bar)
		var t := UI.label(l[0], 14)
		t.custom_minimum_size = Vector2(92, 0)
		bar.add_child(t)
		row_button(bar, "<", _on_pilot_change.bind(l[1], -1), true, 44)
		if l[2] == "":
			var sw := ColorRect.new()
			sw.color = Color(l[3])
			sw.custom_minimum_size = Vector2(112, 30)
			sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.add_child(sw)
		else:
			var vs := 13
			while vs > 9 and ThemeDB.fallback_font.get_string_size(l[2], HORIZONTAL_ALIGNMENT_LEFT, -1, int(vs * UI.SCALE)).x > 108.0:
				vs -= 1
			var v := UI.label(l[2], vs, Color(l[3]).lightened(0.3) if l[3] != "" else Color(0.85, 0.85, 0.9))
			v.custom_minimum_size = Vector2(112, 0)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.clip_text = true
			bar.add_child(v)
		row_button(bar, ">", _on_pilot_change.bind(l[1], 1), true, 44)
	var last := action_bar(col)
	row_button(last, "Random look", _on_pilot_random, true, 130)
	build_controllers()


func _on_pilot_change(what: String, step: int) -> void:
	var look: Dictionary = GameData.pilot_look
	match what:
		"skin":
			look["skin"] = cycle(PilotArt.SKINS, look["skin"], step)
		"eyes":
			look["eyes"] = cycle(PilotArt.EYES, look.get("eyes", PilotArt.EYES[0]), step)
		"hair", "outfit":
			look[what] = cycle(PilotArt.COLORS, look[what], step)
		"hat":
			look["hat"] = cycle(PilotArt.HATS, look["hat"], step)
		"beard":
			look["beard"] = cycle(PilotArt.BEARDS, look["beard"], step)
		"glasses":
			look["glasses"] = cycle(PilotArt.GLASSES, look["glasses"], step)
		"controller":
			look["controller"] = cycle(GameData.owned_controllers, look["controller"], step)
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
	refresh()


func cycle(list: Array, cur, step: int):
	var i := list.find(cur)
	return list[posmod((0 if i < 0 else i) + step, list.size())]


func _on_pilot_random() -> void:
	var look: Dictionary = GameData.pilot_look
	look["skin"] = PilotArt.SKINS[randi() % PilotArt.SKINS.size()]
	look["eyes"] = PilotArt.EYES[randi() % PilotArt.EYES.size()]
	look["hair"] = PilotArt.COLORS[randi() % PilotArt.COLORS.size()]
	look["outfit"] = PilotArt.COLORS[randi() % PilotArt.COLORS.size()]
	look["hat"] = PilotArt.HATS[randi() % PilotArt.HATS.size()]
	look["beard"] = PilotArt.BEARDS[randi() % PilotArt.BEARDS.size()]
	look["glasses"] = PilotArt.GLASSES[randi() % PilotArt.GLASSES.size()]
	var ex: Array = PilotArt.EXTRAS[randi() % PilotArt.EXTRAS.size()]
	for e in ["long_hair", "scar"]:
		look[e] = ex.has(e)
	Sfx.play("equip")
	refresh()


func _on_controller(id: String) -> void:
	say(GameData.buy_controller(id), "buy")
	refresh()


## Health of each body part for the little damage map over the robot (-1 = should have one, doesn't).
func body_health() -> Dictionary:
	var out := {}
	for slot in GameData.BODY_SLOTS:
		if not GameData.slot_available(slot):
			continue
		var p := GameData.equipped_inst(slot)
		if p.is_empty():
			if slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
				out[slot] = -1.0
			continue
		out[slot] = GameData.hp_ratio(p)
	return out


func set_scene_for_tab() -> void:
	match tab:
		"Bay":
			scene = {"chips": "moves", "style": "paint"}.get(seg(), "build")
		"Storage":
			scene = "storage"
		"Parts":
			scene = {"dealer": "shop", "order": "workshop"}.get(seg(), "scrap")
		"Season":
			scene = "cups" if seg() == "cups" else "build"
		"Crew":
			scene = "team"
	preview.spot = GarageArt.robot_spot(scene)
	preview.facing = 1 if scene == "paint" else -1
	preview.queue_redraw()


func _on_open_paint() -> void:
	go_to("Bay", "style")


# ---------------------------------------------------------------- SHOP

var order_kind := "part"   # Order your own: "part" or "chip"
var shop_view := "stock"   # Shop tab: "stock" (the dealer) or "order" (order your own part)


## Get Parts > Made to order: design a part, or order any training chip (both cost extra).
func build_order() -> void:
	var kinds := action_bar()
	for v in [["part", tr("A part")], ["chip", tr("A training chip")]]:
		var kb := row_button(kinds, v[1], _on_order_kind.bind(v[0]), true, 0)
		kb.toggle_mode = true
		kb.button_pressed = order_kind == v[0]
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if order_kind == "chip":
		section(tr("Any training chip, made to order - double the dealer's price."))
		var any := false
		for id in GameData.chip_ids():
			if not GameData.owned_chips.has(id):
				chip_row(id, true)
				any = true
		if not any:
			section("You own every chip there is.")
		return
	build_workshop()


## Get Parts > Dealer: this week's stock (parts and training chips), new every Sunday.
func build_dealer() -> void:
	var bar := action_bar()
	var info := GUI.text(tr("New stock every Sunday. Grab the good stuff while it's here!"), 13, GUI.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	row_button(bar, tr("Restock $%d") % GameData.REROLL_COST, _on_reroll, GameData.money >= GameData.REROLL_COST, 140)
	var stock: Array = GameData.shop_stock.duplicate()
	stock.sort_custom(func(a, b): return GameData.KINDS.find(GameData.part_def(a)["kind"]) < GameData.KINDS.find(GameData.part_def(b)["kind"]))
	var chips: Array = GameData.chip_stock if GameData.unlocked("moves") else []
	if stock.is_empty():
		section("Sold out! New stock arrives on Sunday (or pay to restock now).")
	var kinds: Array = stock.map(func(id): return GameData.part_def(id)["kind"])
	var entries := kind_entries(kinds, "All parts")
	entries[0][2] = stock.size() + chips.size()
	entries.append(["chip", "Chips", chips.size()])
	shop_filter = category_dropdown(entries, shop_filter, _on_shop_filter)
	var f := shop_filter
	for id in stock:
		var d := GameData.part_def(id)
		if f != "all" and d["kind"] != f:
			continue
		var row := make_row(part_icon(d), d["name"], part_info(d), null, tr(str(d["kind"]).to_upper()))
		var hb := GUI.SegBar.new()
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			hb.setup(float(d["hp"]), float(d["hp"]), GUI.GREEN)
			hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(hb)
		row_button(row, tr("Buy $%d") % d["cost"], _on_buy.bind(id), GameData.money >= d["cost"], 110)
	if (f == "all" or f == "chip") and not chips.is_empty():
		section("TRAINING CHIPS - each one teaches your robot a special move:")
		for id in chips.duplicate():
			chip_row(id, false)


## Pilot gear: controllers change how your robots fight. Bought and picked in Crew > Pilot.
func build_controllers() -> void:
	section("PILOT GEAR - controllers change how your robots fight:")
	for id in PilotArt.CONTROLLERS:
		var cinfo: Dictionary = GameData.CONTROLLER_INFO[id]
		var icon := ControllerIcon.new()
		icon.kind = id
		var row := make_row(icon, tr(PilotArt.CONTROLLER_NAMES[id]), tr(cinfo["desc"]))
		var using: bool = GameData.pilot_look.get("controller", "gamepad") == id
		if using:
			row_button(row, "In use", _on_controller.bind(id), false, 110)
		elif GameData.owned_controllers.has(id):
			row_button(row, "Use", _on_controller.bind(id), true, 110)
		else:
			row_button(row, tr("Buy $%d") % cinfo["cost"], _on_controller.bind(id), GameData.money >= int(cinfo["cost"]), 110)


## The scrapyard: a mountain of dead robots. Dig for free (beaten-up) parts, a few digs per fight.
func build_scrapyard_tab() -> void:
	var bar := action_bar()
	var info := UI.label(tr("A mountain of dead robots: one dig a week - fresh junk comes in every Sunday - one part per dig, always beaten up (15-50% health). Dig anywhere for the best odds of something good - or dig for the part you need, and take what the pile gives (mostly junk).") + "\n" + tr("Digging anywhere can also turn up a training chip, once in a long while - you can't dig for one."), 15, Color(1.0, 0.8, 0.4))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	if GameData.digs_left <= 0:
		row_button(bar, tr("No digging until Sunday"), _on_dig.bind(""), false, 270)
	else:
		row_button(bar, tr("Dig anywhere"), _on_dig.bind(""), true, 150)
		var kinds := action_bar()
		kinds.add_child(UI.label(tr("Dig for:"), 16, Color(1.0, 0.8, 0.4)))
		for k in ["head", "torso", "arm", "leg"]:
			var b := row_button(kinds, tr({"head": "Head", "torso": "Torso", "arm": "Arm", "leg": "Leg"}[k]), _on_dig.bind(k), true, 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# what the pile has given you so far (spare parts that still need fixing)
	var finds: Array = GameData.spares().filter(func(p): return p.get("dug", false))
	if not finds.is_empty():
		section("Fresh from the pile - keep it in Storage, or sell it (damaged parts sell cheaper):")
		for p in finds:
			var d := GameData.part_def(p["id"])
			var row := make_row(part_icon(d, GameData.hp_ratio(p)), tr("%s  [%s]") % [d["name"], tr(str(d["kind"]).to_upper())], health_text(p))
			row_button(row, "To Storage", _on_keep_find.bind(p["uid"]), true, 120)
			row_button(row, tr("Sell $%d") % GameData.sell_value(p), _on_sell.bind(p["uid"]), true, 110)


## Keep a scrapyard find: it leaves the pile list and waits in Storage like any other part.
func _on_keep_find(uid: int) -> void:
	var p := GameData.inst(uid)
	if p.is_empty():
		return
	p.erase("dug")
	say(tr("%s is in Storage.") % GameData.part_def(p["id"])["name"], "equip")
	GameData.save_game()
	refresh()


func _on_emergency_junk(slot: String) -> void:
	var uid := GameData.add_part(GameData.STARTER[slot], 0.4)
	GameData.equip(uid, slot)
	say(tr("Gus digs a rusty %s out from under the bench. \"It'll hold. Probably.\"") % GameData.part_def(GameData.STARTER[slot])["name"], "equip")
	refresh()


func _on_dig(kind: String = "") -> void:
	var res := GameData.dig_scrap(kind)
	dig_at = Time.get_ticks_msec() / 1000.0
	dig_found = tr("Found something!") if res["part"] != "" else ""
	say(res["text"], "buy" if res.has("chip") else ("break" if res["part"] != "" else "land"))
	GameData.save_game()
	refresh()


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
	var forge := row_button(head, tr("FORGE $%d") % d["cost"], _on_forge, GameData.money >= d["cost"], 150)
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
		var b := row_button(grades, tr("%s (%d pts)") % [tr(gr["name"]), gr["points"]], _on_ws_grade.bind(g), true, 0)
		b.toggle_mode = true
		b.button_pressed = g == ws["grade"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section(tr("Stats - %d point%s left") % [left, "" if left == 1 else "s"])
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

	section(tr("Gadget (+$%d)") % GameData.CUSTOM_GADGET_PRICE)
	var gad := action_bar()
	var none := row_button(gad, "None", _on_ws_set.bind("gadget", ""), true, 0)
	none.toggle_mode = true
	none.button_pressed = ws["gadget"] == ""
	none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for g in GameData.CUSTOM_KINDS[ws["kind"]]["gadgets"]:
		var b := row_button(gad, tr(Specials.GADGETS[g]["name"]), _on_ws_set.bind("gadget", g), true, 0)
		b.toggle_mode = true
		b.button_pressed = ws["gadget"] == g
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ---------------------------------------------------------------- MOVES & CUPS

var demo_chip := ""   # the move looping at the top of the Moves tab


## Your training chips: plug them into the head (better heads have more slots), watch each move loop.
func build_moves_tab() -> void:
	section(tr("Training chips teach special moves. They plug into the head: slots used %d/%d (better heads have more). Inputs: → toward the enemy, ← away, ↓ down. Tap them quickly, then P or K.")
			% [GameData.active_chips().size(), GameData.chip_slots()])
	var chip_ids: Array = GameData.owned_chips.duplicate()
	if chip_ids.is_empty():
		section("No chips yet. The dealer sells a chip or two in the Shop, you can order any chip made to order, and now and then the scrapyard coughs one up.")
		return
	if demo_chip == "" or not chip_ids.has(demo_chip):
		demo_chip = GameData.chips[0] if not GameData.chips.is_empty() else (GameData.owned_chips[0] if not GameData.owned_chips.is_empty() else chip_ids[0])
	# the selected move, looping: see it before you buy it, and get used to it before a fight
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	list_box.add_child(top)
	var demo := MoveDemo.new()
	demo.custom_minimum_size = Vector2(320, 180)
	demo.move = demo_chip
	top.add_child(demo)
	var dm: Dictionary = Specials.MOVES[demo_chip]
	var info := UI.label(tr("%s\n%s\n\n%s") % [tr(dm["name"]).to_upper(), Specials.seq_text(dm["seq"]), tr(dm["desc"])], 15, Color(0.5, 0.9, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	for id in chip_ids:
		var m: Dictionary = Specials.MOVES[id]
		var owned := true
		var installed := GameData.chips.has(id)
		var icon := ChipIcon.new()
		icon.installed = installed
		var row := make_row(icon, tr("%s    %s") % [tr(m["name"]), Specials.seq_text(m["seq"])], tr("%s  Cooldown %ds.") % [tr(m["desc"]), int(m["cd"])])
		row_button(row, "Watching" if id == demo_chip else "See it", _on_chip_demo.bind(id), id != demo_chip, 100)
		if not owned:
			row_button(row, tr("Buy $%d") % m["cost"], _on_buy_chip.bind(id), GameData.money >= m["cost"], 115)
		elif installed:
			row_button(row, "Remove", _on_uninstall_chip.bind(id), true, 115)
		else:
			row_button(row, "Install", _on_install_chip.bind(id), GameData.chips.size() < GameData.chip_slots(), 115)


func _on_chip_demo(id: String) -> void:
	demo_chip = id
	refresh()


func build_cups_tab() -> void:
	var c := GameData.circuit
	if not c.is_empty():
		var bar := action_bar()
		var l := UI.label(tr("%s %s - %s - gold $%d") % [c["name"], "★".repeat(int(c["tier"])), tr(Career.round_name(c)), int(c["prize"])], 16, Color(1.0, 0.8, 0.4))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bar.add_child(l)
		row_button(bar, "Abandon", _on_abandon, true, 110)
		show_bracket(c)
		return
	var mode := GameData.fight_mode()
	var free: bool = mode == "pickup" or mode == "open"
	var fits := GameData.cup_fits()
	if not fits:
		section("Too close to the end of the year for a three-week cup. New ones start in January.")
	else:
		section(tr("Cups: 8 pilots, a three-week knockout on Wednesday nights - your Saturday league fights carry on as normal. Gold, silver and bronze go on the bay wall.") + " " + (tr("Enter tonight and your first round is tonight.") if GameData.day == "wed" else tr("Your first round is next Wednesday.")))
	if GameData.circuit_offers.is_empty():
		GameData.make_offers()
	for k in GameData.circuit_offers.size():
		var off: Dictionary = GameData.circuit_offers[k]
		var preview_cup := Career.new_cup(off["name"], int(off["tier"]), int(off["seed"]), GameData.week, GameData.year, int(off["prize"]))
		var row := make_row(bot_preview(Career.robot_of(preview_cup, 1 + int(off["seed"]) % 7)), tr("%s  %s") % [off["name"], "★".repeat(int(off["tier"]))],
				tr("8 pilots, 3 weeks. Gold $%d + a new part, silver $%d, bronze $%d.") % [int(off["prize"]), int(off["prize"] * 0.5), int(off["prize"] * 0.3)])
		row_button(row, "Enter", _on_enter_cup.bind(k), fits, 100)
	if GameData.champion:
		var row := make_row(bot_preview(GameData.OPPONENTS[GameData.OPPONENTS.size() - 1]), "OVERLORD rematch",
				tr("Exhibition bout in the Grand Hall for $%d. Takes a week.") % GameData.EXHIBITION_REWARD)
		row_button(row, "Book it", _on_rematch, free and not GameData.exhibition, 100)


# ---------------------------------------------------------------- season

var season_view := "calendar"   # Season tab: "calendar" (main) or "table" (league table / bracket)
var cal_month := -1              # month shown on the calendar (0-12); -1 = this month

const MONTH_NAMES := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
		"OCTOBER", "NOVEMBER", "DECEMBER", "YEAR'S END"]
const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const PLAN_COLORS := {"league": Color(0.35, 0.6, 1.0), "playoff": Color(1.0, 0.75, 0.25), "cup": Color(0.75, 0.5, 1.0),
		"open": Color(0.6, 0.55, 0.45), "past": Color(0.4, 0.4, 0.45)}


func build_season_tab() -> void:
	match season_view:
		"calendar":
			build_calendar()
		"bets":
			build_bets()
		"pilots":
			build_pilots_view()
		"cups":
			build_cups_tab()
		_:
			build_league_view()


func _on_season_view(v: String) -> void:
	season_view = v
	refresh()


## A wall calendar: 4-week months, cups on Wednesday nights, everything else on Saturday nights,
## new stock and fresh scrapyard junk every Sunday, rent on the last Sunday.
## Only what you're actually in shows up - leagues you haven't qualified for aren't there.
func build_calendar() -> void:
	var cur_month := (GameData.week - 1) / GameData.MONTH_WEEKS
	if cal_month < 0:
		cal_month = cur_month
	var mode := GameData.fight_mode()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list_box.add_child(head)
	head.add_child(UI.button("<", _on_cal_month.bind(-1), 18, Vector2(56, 36)))
	var t := UI.label(tr("%s  -  YEAR %d") % [tr(MONTH_NAMES[cal_month]), GameData.year], 19, Color(1.0, 0.8, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.button(">", _on_cal_month.bind(1), 18, Vector2(56, 36)))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	list_box.add_child(grid)
	for d in DAY_NAMES:
		var l := UI.label(d, 13, Color(1.0, 0.8, 0.4) if d == "SAT" else (Color(0.75, 0.5, 1.0) if d == "WED" else Color(0.7, 0.7, 0.75)))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	for row in GameData.MONTH_WEEKS:
		var w: int = cal_month * GameData.MONTH_WEEKS + row + 1
		var this_week := w == GameData.week
		for day in 7:
			var text := ""
			var col := Color(0.85, 0.85, 0.9)
			var bg := Color(0.14, 0.14, 0.18, 0.9)
			var tonight := false
			if day == 5 or day == 2:   # Saturday: fight night. Wednesday: cup night
				var d := "sat" if day == 5 else "wed"
				var plan := GameData.week_plan(GameData.year, w, d)
				text = tr(str(plan["text"]))
				if plan["kind"] == "done":
					col = Color(0.5, 1.0, 0.6) if plan["won"] else Color(1.0, 0.45, 0.4)
				else:
					col = PLAN_COLORS.get(plan["kind"], col)
				tonight = this_week and GameData.day == d and plan["kind"] != "done"
				if tonight:
					text = tr("TONIGHT\n") + (text if mode == "open" or mode == "pickup" else GameData.fight_title())
				if day == 5 or plan["kind"] == "cup" or plan["kind"] == "done":
					bg = Color(0.2, 0.18, 0.12, 0.95)
			elif day == 6 and row == GameData.MONTH_WEEKS - 1 and GameData.living_cost() > 0:
				text = tr("RENT & FOOD\n-$%d") % GameData.living_cost()
				col = Color(1.0, 0.45, 0.4)
			if this_week:
				bg = bg.lightened(0.08)
			grid.add_child(day_cell(row * 7 + day + 1, text, col, bg, tonight))
	var info := tr("Record %d-%d.  Medals %d.") % [GameData.wins, GameData.losses, GameData.trophies.size()]
	section(info)
	if mode == "pickup" or mode == "open":
		var nxt := GameData.next_event_info()
		var league_sat := ["league", "playoff"].has(str(GameData.week_plan(GameData.year, GameData.week, "sat")["kind"]))
		if GameData.day == "wed":
			section("Wednesday night, and no cup round for you. Take a pickup fight at the scrapyard for a few dollars (Fight button), enter a cup, or skip to Saturday.")
		else:
			section("No league fight this week. Take a pickup fight at the scrapyard for a few dollars (Fight button), enter a cup if you can, or let the week pass.")
		var bar := action_bar()
		if GameData.day == "wed":
			row_button(bar, "Skip to Saturday", _on_skip_wednesday, true, 190)
		if not league_sat:
			row_button(bar, "Rest a week", _on_rest, true, 150)
		if str(nxt[0]) != "" and int(nxt[2]) > 1 and GameData.circuit.is_empty():
			row_button(bar, tr("Skip to the %s") % tr(Career.STAGES[nxt[0]]["short"]).capitalize(), _on_skip, true, 0)


func day_cell(n: int, text: String, col: Color, bg: Color, today: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(2)
	if today:
		sb.border_color = Color(1.0, 0.85, 0.3)
		sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(UI.label(str(n), 10, Color(0.6, 0.6, 0.65)))
	if text != "":
		var l := UI.label(text, 11, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return p


var bet_stake := 50


## Bets: put money on yourself, or on anyone else's fight this round. Odds come from the table.
func build_bets() -> void:
	if GameData.bet_target() == "self":
		build_self_bets()
		return
	var ev := GameData.bet_event()
	section("This round's fights. Odds come from records and robots - a pilot nobody rates pays big. Bets need real cash. Watch a fight and its result is the real one.")
	var bar := action_bar()
	bar.add_child(UI.label("Stake:", 16))
	for st in [10, 50, 100, 250, 500]:
		var b := row_button(bar, "$%d" % st, _on_stake.bind(st), true, 80)
		b.toggle_mode = true
		b.button_pressed = st == bet_stake
	for pr in Career.round_matches(ev):
		var a: int = pr[0]
		var b: int = pr[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list_box.add_child(row)
		bet_side(row, ev, a, b)
		var vs := UI.label("vs", 15, Color(0.6, 0.6, 0.65))
		vs.custom_minimum_size = Vector2(28, 0)
		vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(vs)
		bet_side(row, ev, b, a)
		if a != 0:
			row_button(row, "Watch", _on_watch.bind(a, b), GameData.can_watch(ev, a, b), 80)
	var mine: Array = GameData.bets.filter(func(x): return x["on"] == GameData.bet_target() and int(x["round"]) == int(ev["round"]))
	if not mine.is_empty():
		section("Your bets this round:")
		for x in mine:
			var who: String = GameData.pilot_name if x["pick"] == 0 else str(Career.pilot(ev, x["pick"]).get("pilot", "?"))
			section(tr("  $%d on %s at %.2fx  ->  pays $%d") % [x["stake"], who, x["odds"], int(x["stake"] * x["odds"])])


## No league round this week: the bookies still take money on your own fight.
func build_self_bets() -> void:
	var o := GameData.current_opponent()
	section("No league round this week - but the bookies at the scrapyard will still take money on you. Bets need real cash.")
	var bar := action_bar()
	bar.add_child(UI.label("Stake:", 16))
	for st in [10, 50, 100, 250, 500]:
		var b := row_button(bar, "$%d" % st, _on_stake.bind(st), true, 80)
		b.toggle_mode = true
		b.button_pressed = st == bet_stake
	var odds := GameData.self_odds()
	var row := make_row(bot_preview(o), tr("%s vs %s") % [GameData.pilot_name, str(o.get("name", "?"))],
			tr("%s to win: %.2fx - a $%d bet pays $%d.") % [GameData.pilot_name, odds, bet_stake, int(bet_stake * odds)])
	row_button(row, "Bet", _on_bet.bind(0, -1), GameData.money >= bet_stake, 80)
	var mine: Array = GameData.bets.filter(func(x): return x["on"] == "self")
	if not mine.is_empty():
		section("Your bets on this fight:")
		for x in mine:
			section(tr("  $%d on %s at %.2fx  ->  pays $%d") % [x["stake"], GameData.pilot_name, x["odds"], int(x["stake"] * x["odds"])])


## One side of a match: pilot, robot, record, odds and a Bet button.
func bet_side(row: HBoxContainer, ev: Dictionary, id: int, other: int) -> void:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)
	var t: Array = ev["table"].get(str(id), [0, 0, 0, 0])
	var odds := Career.odds(ev, id, other)
	var l := UI.label(tr("%s\n%d-%d   %.2fx") % [who(ev, id), t[0], t[1], odds], 13, Color(1.0, 0.85, 0.3) if id == 0 else Color(0.9, 0.9, 0.95))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	box.add_child(l)
	if other != 0:
		row_button(box, "Bet", _on_bet.bind(id, other), GameData.money >= bet_stake, 64)


func _on_watch(a: int, b: int) -> void:
	GameData.start_watch(a, b)
	Sfx.play("click")
	get_tree().change_scene_to_file("res://fight.tscn")


## Every pilot in Port Ferrum: who's on top, who's broke, who's moved up, who retired - and the news.
func build_pilots_view() -> void:
	var World = GameData.World
	section("Port Ferrum's pilots. Between fights they earn, repair, upgrade, sell parts - and some retire.")
	var news: Array = GameData.world.get("news", [])
	if not news.is_empty():
		section("NEWS")
		for k in range(news.size() - 1, maxi(-1, news.size() - 9), -1):
			var n: Dictionary = news[k]
			var l := UI.label(tr("Y%d W%d  %s") % [int(n["y"]), int(n["w"]), World.news_text(n)], 13, Color(0.85, 0.85, 0.9))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list_box.add_child(l)
	var order: Array = [GameData.rank] + World.TIERS.filter(func(t): return t != GameData.rank)
	var widths := [34, 0, 70, 78, 96]
	for tier in order:
		section(tr(Career.STAGES[tier]["name"]).to_upper())
		table_row(["#", "PILOT - ROBOT", "W-L", "PARTS", "WALLET"], widths, Color(0.7, 0.7, 0.75), Color(0, 0, 0, 0))
		var pool: Array = World.by_rating(tier)
		pool.reverse()
		for k in pool.size():
			var p: Dictionary = pool[k]
			var cash := int(p["cash"])
			var living: int = World.LIVING[tier]
			var wallet := tr("in debt") if cash < 0 else (tr("rich") if cash > living * 12 else (tr("comfortable") if cash > living * 3 else tr("getting by")))
			var col := Color(1, 0.55, 0.5) if cash < 0 else Color(0.9, 0.9, 0.95)
			table_row([str(k + 1), tr("%s - %s") % [p["name"], p["bot"]["name"]], "%d-%d" % [int(p["w"]), int(p["l"])],
					"$%d" % int(World.bot_value(p["bot"])), wallet], widths, col, Color(0, 0, 0, 0))
	var gone: Array = GameData.world.get("pilots", {}).values().filter(func(p): return p["retired"])
	if not gone.is_empty():
		gone.sort_custom(func(a, b): return int(a.get("ret_y", 0)) * 100 + int(a.get("ret_w", 0)) > int(b.get("ret_y", 0)) * 100 + int(b.get("ret_w", 0)))
		section("RETIRED")
		for p in gone.slice(0, 12):
			var why: String = {"broke": "broke", "rich": "cashed out", "old": "hung it up"}.get(str(p.get("ret_why", "old")), "")
			table_row(["", tr("%s (retired)") % p["name"], "%d-%d" % [int(p["w"]), int(p["l"])], tr("year %d") % int(p.get("ret_y", 1)), tr(why)],
					widths, Color(0.6, 0.6, 0.65), Color(0, 0, 0, 0))


func _on_stake(st: int) -> void:
	bet_stake = st
	refresh()


func _on_bet(pick: int, vs: int) -> void:
	say(GameData.place_bet(pick, vs, bet_stake), "buy")
	GameData.save_game()
	refresh()


func _on_skip_wednesday() -> void:
	close_popup()
	say(GameData.skip_wednesday(), "click")
	refresh()


func _on_cal_month(step: int) -> void:
	cal_month = clampi(cal_month + step, 0, MONTH_NAMES.size() - 1)
	refresh()


## Secondary view: the league you're in - table and bracket.
func build_league_view() -> void:
	var ev: Dictionary = GameData.event
	if ev.is_empty():
		section("You're not in a league right now.")
		return
	var info: Dictionary = Career.STAGES[ev["stage"]]
	var status := tr("%s, year %d - ") % [ev["name"], int(ev["year"])]
	match ev["phase"]:
		"league":
			status += tr(Career.round_name(ev))
		"playoffs":
			status += tr("PLAYOFFS: ") + tr(Career.round_name(ev))
		_:
			status += tr("FINAL RESULT: you ") + Career.finish_text(ev)
	section(status)
	var rule := "Top 3 win medals - a medal gets you into the Regional." if int(info["playoff"]) == 0 else \
			("Top 4 go to the playoffs - reaching the semifinals gets you into the Championship." if ev["stage"] == "regional" else
			"Top 7 join the defending champion in the playoffs. Win the final to be champion.")
	section(rule)
	if not ev.get("bracket", {}).is_empty():
		show_bracket(ev)
	show_table(ev)


func show_table(ev: Dictionary) -> void:
	var info: Dictionary = Career.STAGES[ev["stage"]]
	var zone: int = 3 if int(info["playoff"]) == 0 else int(info["playoff"]) - (1 if info.has("boss") else 0)
	var widths := [34, 0, 70, 46, 46]
	table_row(["#", "PILOT - ROBOT", "W-L", "PTS", "PARTS"], widths, Color(0.7, 0.7, 0.75), Color(0, 0, 0, 0))
	var pos := 0
	for id in Career.standings(ev):
		var e := Career.pilot(ev, id)
		if e.get("rival", -1) == 9 and ev["table"].get(str(id), [0, 0, 0, 0])[0] == 0 and ev["table"].get(str(id), [0, 0, 0, 0])[1] == 0:
			continue   # the defending champion doesn't play the league
		pos += 1
		var t: Array = ev["table"].get(str(id), [0, 0, 0, 0])
		var col := Color(1, 1, 1)
		var bg := Color(0, 0, 0, 0)
		if id == 0:
			col = Color(1.0, 0.85, 0.3)
			bg = Color(1.0, 0.7, 0.2, 0.15)
		elif pos <= zone:
			col = Color(0.65, 1.0, 0.7)
		var medal := Career.medal_of(ev, id)
		var mark: String = tr(["", " (GOLD)", " (SILVER)", " (BRONZE)"][medal])
		table_row([str(pos) + ("*" if pos <= zone else ""), who(ev, id) + mark, "%d-%d" % [t[0], t[1]], str(t[2]), str(t[3])], widths, col, bg)


func show_bracket(ev: Dictionary) -> void:
	var br: Dictionary = ev["bracket"]
	for r in br["rounds"].size():
		var rnd: Array = br["rounds"][r]
		var main := rnd.filter(func(m): return not m.get("bronze", false)).size()
		section(tr({4: "QUARTERFINALS", 2: "SEMIFINALS", 1: "FINAL + BRONZE MATCH" if rnd.size() == 2 else "FINAL"}.get(main, "ROUND")))
		for m in rnd:
			var a: int = m["a"]
			var b: int = m["b"]
			var w: int = m["w"]
			var txt := tr("%s%s  vs  %s") % ["BRONZE: " if m.get("bronze", false) else "", who(ev, a), who(ev, b)]
			if w >= 0:
				txt += tr("   ->  %s wins") % (GameData.pilot_name if w == 0 else str(Career.pilot(ev, w).get("pilot", "?")))
			var mine := a == 0 or b == 0
			var col := Color(1.0, 0.85, 0.3) if mine else (Color(0.8, 0.8, 0.85) if w >= 0 else Color(1, 1, 1))
			table_row([txt], [0], col, Color(1.0, 0.7, 0.2, 0.15) if mine else Color(0, 0, 0, 0))


## "PILOT - ROBOT" for the table.
func who(ev: Dictionary, id: int) -> String:
	if id == 0:
		return tr("%s - %s") % [GameData.pilot_name.to_upper(), GameData.robot_name]
	var e := Career.pilot(ev, id)
	var o := Career.robot_of(ev, id)
	var pilot: String = str(o.get("pilot", e.get("pilot", "")))
	if pilot == "":
		pilot = str(e.get("pilot", "?"))
	return tr("%s - %s") % [pilot, o.get("name", "?")]


func table_row(cells: Array, widths: Array, col: Color, bg: Color) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	p.add_child(row)
	for k in cells.size():
		var l := UI.label(str(cells[k]), 15, col)
		l.clip_text = true
		if int(widths[k]) > 0:
			l.custom_minimum_size = Vector2(widths[k], 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	list_box.add_child(p)


func _on_rest() -> void:
	say(GameData.rest_week() + bills_text(), "click")
	refresh()


func _on_skip() -> void:
	say(GameData.skip_to_next_event() + bills_text(), "click")


func bills_text() -> String:
	if GameData.bills_note <= 0:
		return ""
	var t := tr(" Rent and food: -$%d.") % GameData.bills_note
	GameData.bills_note = 0
	return t
	refresh()


func _on_rematch() -> void:
	GameData.pickup = {}
	GameData.exhibition = true
	GameData.save_game()
	say("Booked: OVERLORD, in the Grand Hall. Hit the fight button when you're ready.", "fight")
	refresh()


func build_team_tab() -> void:
	section("BACKUP ROBOTS are built from your spare parts and keep their damage, just like your robot. Main robot too beaten up and no cash to fix it? Use the Send button to put a backup robot in a 1-on-1 and earn some money. In cups they also fight beside you against tag teams and swarms.")
	var ms := GameData.stats()
	section("WEIGHT CLASSES: a robot fighting alone can be as heavy as its reactor allows. A team shares one heavyweight's power (%d): 2 robots get %d each, 3 get %d. Your robot now: %s, %d power. Mini parts are light, Heavy parts drink power - a team robot over its share gets overloaded."
			% [int(GameData.TEAM_POWER), int(GameData.team_share(2)), int(GameData.team_share(3)), tr(GameData.weight_class(ms["power_used"])), ms["power_used"]])
	var bar := action_bar()
	var split: bool = GameData.settings.get("team_controls", "split") == "split"
	var b := row_button(bar, tr("Team controls: %s") % ("SPLIT - each robot gets its own movement pad" if split else "LINKED - every robot follows one pad"), _on_team_controls, true, 0)
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
						names.append(tr("%s %d%%") % [GameData.part_def(p["id"])["name"], int(GameData.hp_ratio(p) * 100)])
			var ws := GameData.stats(w)
			var share := GameData.team_share(2)
			var power := tr("%s, %d power. In a team of 2 each robot gets %d power, in a team of 3 only %d%s. ") % [
					tr(GameData.weight_class(ws["power_used"])), ws["power_used"], int(share), int(GameData.team_share(3)),
					" - too heavy, it will be overloaded!" if ws["power_used"] > share else ""]
			sub = tr("READY. " if GameData.wingman_ready(k) else "CAN'T FIGHT - missing a head or torso. ") + power + ", ".join(names)
		else:
			pv.look = {}
		var row := make_row(pv, name, sub)
		row_button(row, tr("Rebuild") if not w.is_empty() else tr("Build"), _on_build_wingman.bind(k), true, 100)
		if not w.is_empty():
			var c := GameData.wingman_repair_cost(k)
			row_button(row, tr("Fix $%d") % c if c > 0 else tr("OK"), _on_repair_wingman.bind(k), c > 0 and GameData.can_repair(c), 95)
			row_button(row, "Disband", _on_disband_wingman.bind(k), true, 100)


func _on_team_controls() -> void:
	var split: bool = GameData.settings.get("team_controls", "split") == "split"
	GameData.settings["team_controls"] = "linked" if split else "split"
	GameData.save_settings()
	say(tr("Team controls: %s.") % ("LINKED - all your robots follow one movement pad" if split else "SPLIT - one movement pad per robot, shared attack buttons. Move the pads in Settings > Edit controls"), "click")
	refresh()


func _on_build_wingman(k: int) -> void:
	say(GameData.build_wingman(k), "equip")
	refresh()


func _on_repair_wingman(k: int) -> void:
	say(GameData.repair_wingman(k), "repair")
	refresh()


func _on_disband_wingman(k: int) -> void:
	GameData.clear_wingman(k)
	say(tr("%s's parts went back to your Spares.") % GameData.wingman_name(k), "click")
	refresh()


func bot_preview(o: Dictionary) -> RobotPreview:
	var pv := RobotPreview.new()
	pv.look = GameData.look_from_spec(GameData.opponent_spec_from(o, 1.0))
	pv.facing = -1
	pv.anim = false
	return pv


# ---------------------------------------------------------------- actions

## New things carry a star: the first tap has Gus explain them (a short scene), then opens them.
func gus_explains(feature: String, _tab_name: String = "") -> bool:
	if not GameData.is_new(feature):
		return false
	var place: Array = FEATURE_PLACE.get(feature, ["", ""])
	GameData.open_tab = place[0]
	GameData.open_action = place[1]
	if GameData.queue_story("unlock_" + feature, "res://garage.tscn"):
		Sfx.play("click")
		GameData.flush_save()
		get_tree().change_scene_to_file("res://story.tscn")
		return true
	return false


func star(text: String, feature: String) -> String:
	return text + (" ★" if GameData.is_new(feature) else "")


## A rail button. The first visit to a section Gus hasn't shown you yet plays his scene first.
func _on_tab(t: String) -> void:
	var first: String = {"Storage": "storage", "Season": "season", "Parts": "scrapyard"}.get(t, "")
	if t == "Crew":
		first = "team" if GameData.team_unlocked() else "pilot"
	if first != "" and gus_explains(first):
		return
	if t == tab and t == "Bay":
		selected = ""
	tab = t
	selling = false
	var tip := GameData.tab_tip({"Parts": "Scrapyard", "Season": "Season", "Crew": "Team"}.get(t, ""))
	if tip != "":
		say(tip)
	refresh()


## Tapping a trophy on the bay's shelf: zoom in on it.
func _on_backdrop_tapped(pos: Vector2) -> void:
	if scene != "build":
		return
	for s in GarageArt.trophy_spots(preview.size, GameData.trophies.size()):
		var base: Vector2 = s[1]
		if Rect2(base + Vector2(-13, -40), Vector2(26, 42)).has_point(pos):
			Sfx.play("click")
			open_trophy(int(s[0]))
			return


class TrophyView extends Control:
	var kind := "cup"
	var medal := 1
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size.y / 46.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1))
		# a spotlight and a slow shine
		draw_circle(Vector2(size.x * 0.5, size.y * 0.55), size.y * 0.45, Color(1.0, 0.9, 0.6, 0.06))
		GarageArt.draw_trophy(self, Vector2(size.x * 0.5, size.y - 6.0), kind, medal, s)
		var shine := fmod(t * 0.5, 1.6) - 0.3
		if shine > 0.0 and shine < 1.0:
			var x := size.x * (0.3 + shine * 0.4)
			draw_line(Vector2(x, size.y * 0.2), Vector2(x - 12, size.y * 0.8), Color(1, 1, 1, 0.25), 4.0)


func open_trophy(i: int) -> void:
	var tr_: Dictionary = GameData.trophies[i]
	var medal := int(tr_.get("medal", 1))
	var col := open_popup(tr("%s - %s") % [tr(Career.MEDALS[medal]), tr(str(tr_.get("name", "")))])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var tv := TrophyView.new()
	tv.kind = str(tr_.get("kind", "cup"))
	tv.medal = medal
	tv.custom_minimum_size = Vector2(200, 230)
	row.add_child(tv)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var when := tr("Won in year %d") % int(tr_.get("year", 1))
	if tr_.has("week"):
		when = tr("Won in year %d, week %d") % [int(tr_.get("year", 1)), int(tr_["week"])]
	info.add_child(UI.label(when, 17, Color(1.0, 0.85, 0.4)))
	var fights: Array = tr_.get("fights", [])
	if fights.is_empty():
		info.add_child(UI.label(tr("(The fight records from before this was kept are lost.)"), 13, Color(0.6, 0.6, 0.65)))
	else:
		var w := fights.filter(func(f): return f["won"]).size()
		info.add_child(UI.label(tr("Record: %d-%d") % [w, fights.size() - w], 17, Color(0.9, 0.9, 0.95)))
		for f in fights:
			var l := UI.label(tr("Week %d: %s %s") % [int(f["w"]), tr("beat") if f["won"] else tr("lost to"), str(f["opp"])], 14,
					Color(0.5, 1.0, 0.6) if f["won"] else Color(1.0, 0.55, 0.45))
			info.add_child(l)


func _on_part_tapped(slot: String) -> void:
	tab = "Bay"
	segs_on["Bay"] = "robot"
	selected = slot
	Sfx.play("target")
	refresh()


func _on_slot(slot: String) -> void:
	# (old names for places that are sections now)
	match slot:
		"storage":
			_on_tab("Storage")
			return
		"scrapyard":
			go_to("Parts", "scrap")
			return
		"chips":
			tab = "Bay"
			_on_seg("chips")
			return
	tab = "Bay"
	segs_on["Bay"] = "robot"
	selected = slot
	refresh()


func _on_shop_kind(kind: String) -> void:
	shop_kind = kind
	refresh()


func _on_go_shop(kind: String) -> void:
	shop_kind = kind
	shop_filter = kind
	go_to("Parts", "dealer")


func _on_order_kind(k: String) -> void:
	order_kind = k
	refresh()


func _on_shop_view(v: String) -> void:
	tab = "Parts"
	_on_seg("order" if v == "order" else "dealer")


func _on_go_workshop(kind: String) -> void:
	reset_workshop(kind)
	order_kind = "part"
	tab = "Parts"
	_on_seg("order")


func _on_reroll() -> void:
	var before := GameData.money
	say(GameData.reroll_stock(), "buy" if GameData.money < before else "error")
	refresh()


func _on_open_style() -> void:
	go_to("Bay", "style")


## Bay > Style & paint: pick a fighting style (watch each signature move first), and a paint job.
func build_style_view() -> void:
	var col := list_box
	section(tr("FIGHTING STYLE") + " - " + tr("Your style changes how ECHO fights and gives it a free signature move.").replace("ECHO", GameData.robot_name), col)
	if GameData.style_locked:
		section("You've already switched style since your last fight - one switch between fights. Fight with it first.", col)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	# left: the signature move, looping, so you know what it looks like before a fight
	var left := VBoxContainer.new()
	body.add_child(left)
	style_demo = MoveDemo.new()
	style_demo.custom_minimum_size = Vector2(400, 225)
	left.add_child(style_demo)
	style_demo_label = UI.label("", 14, Color(0.5, 0.9, 1.0))
	style_demo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_demo_label.custom_minimum_size = Vector2(400, 0)
	left.add_child(style_demo_label)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	body.add_child(list)
	for id in Catalog.STYLES:
		var st: Dictionary = Catalog.STYLES[id]
		var sig: Dictionary = Specials.MOVES[st["signature"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UI.label(tr(st["name"]).to_upper() + ("   (current)" if id == GameData.style else ""), 17, Color(st["color"]).lightened(0.3)))
		var d := UI.label(tr(st["desc"]), 12)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(330, 0)
		text.add_child(d)
		text.add_child(UI.label(tr("Signature: %s  %s") % [tr(sig["name"]), Specials.seq_text(sig["seq"])], 12, Color(0.5, 0.9, 1.0)))
		var btns := VBoxContainer.new()
		row.add_child(btns)
		btns.add_child(UI.button("See it", _on_style_demo.bind(id), 14, Vector2(84, 38)))
		var b := UI.button("Pick", _on_pick_style.bind(id), 14, Vector2(84, 38))
		b.disabled = id == GameData.style or GameData.style_locked
		btns.add_child(b)
	_on_style_demo(GameData.style)
	if GameData.unlocked("paint"):
		section(tr("PAINT JOB"), col)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		col.add_child(grid)
		for k in GameData.PAINTS.size():
			var paint: Dictionary = GameData.PAINTS[k]
			var b := UI.button(tr(paint["name"]), _on_paint.bind(k), 14, Vector2(110, 44))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(paint["color"]).darkened(0.35)
			sb.border_color = Color.WHITE if k == GameData.paint else Color(paint["color"])
			sb.set_border_width_all(4 if k == GameData.paint else 2)
			sb.set_corner_radius_all(8)
			for state in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(state, sb)
			grid.add_child(b)


var style_demo: Control
var style_demo_label: Label


## Loop a style's signature move in the popup's little window.
func _on_style_demo(id: String) -> void:
	var st: Dictionary = Catalog.STYLES[id]
	var sig: Dictionary = Specials.MOVES[st["signature"]]
	style_demo.show_move(st["signature"])
	style_demo_label.text = tr("%s - %s: %s") % [tr(st["name"]).to_upper(), tr(sig["name"]), Specials.seq_text(sig["seq"])]


func _on_pick_style(id: String) -> void:
	if GameData.style_locked:
		return
	GameData.style = id
	GameData.style_locked = true
	close_popup()
	say(tr("Fighting style: %s. Signature move: %s.") % [tr(Catalog.STYLES[id]["name"]), tr(Specials.MOVES[Catalog.STYLES[id]["signature"]]["name"])], "equip")
	refresh()


func _on_open_scout() -> void:
	if gus_explains("scout"):
		return
	var msg := ""
	if not GameData.scouted():
		var before := GameData.money
		msg = GameData.do_scout()
		if GameData.money == before:
			say(msg, "error")
			open_fight_popup()
			return
		Sfx.play("buy")
		refresh()
	# the report shows what the scout saw - if they spotted him, one part will be different on the night
	var o := GameData.current_opponent(false)
	var spec := GameData.opponent_spec_from(o, 1.0)
	var col := open_popup(tr("SCOUTING REPORT: ") + str(o["name"]))
	if msg == "":
		msg = "Their crew spotted your scout! They'll swap something before the bell - one thing in this report won't be what shows up." if GameData.scout.get("spied_back", false) else "Clean scouting run - they never saw you."
	msg = tr(msg)
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
	info.add_child(UI.label(tr("Style: %s") % tr(Catalog.STYLES[st]["name"]), 16, Color(Catalog.STYLES[st]["color"]).lightened(0.3)))
	var weak := ""
	var weak_v := 1e9
	for slot in GameData.BODY_SLOTS:
		var p: Dictionary = spec["parts"].get(slot, {})
		if p.is_empty():
			continue
		var d := GameData.part_def(p["id"])
		var line := tr("%s: %s  (HP %d, armor %d)") % [tr(GameData.SLOT_NAMES[slot]), d["name"], int(p["max_hp"]), int(p["armor"])]
		if d.get("trait", "") != "":
			line += "  - " + tr(Catalog.TRAITS[d["trait"]]["name"])
		if d["gimmick"] != "":
			line += "  - " + tr(Specials.GADGETS[d["gimmick"]]["name"])
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
				extra = "  - " + tr(Catalog.TRAITS[d["trait"]]["name"])
			elif d["gimmick"] != "":
				extra = "  - " + tr(Specials.GADGETS[d["gimmick"]]["name"])
			info.add_child(UI.label(tr("%s: %s%s") % [tr(GameData.SLOT_NAMES[slot]), d["name"], extra], 12))
	var moves: Array = []
	for id in o["specials"]:
		moves.append(tr(Specials.MOVES[id]["name"]))
	moves.append(tr(Specials.MOVES[Catalog.STYLES[st]["signature"]]["name"]) + tr(" (signature)"))
	var ml := UI.label("Moves: " + ", ".join(moves), 13, Color(0.5, 0.9, 1.0))
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ml)
	if weak != "":
		info.add_child(UI.label(tr("Weak point: %s - aim there!") % tr(GameData.SLOT_NAMES[weak]), 15, Color(1.0, 0.9, 0.3)))
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	col.add_child(nav)
	var back := UI.button("< Back", open_fight_popup, 17, Vector2(0, 48))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back)
	var go := UI.button(tr("FIGHT!"), _on_fight_from_report, 19, Vector2(0, 48))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(go)


## From the scouting report: still warn about damage before the bell.
func _on_fight_from_report() -> void:
	if damage_report().is_empty():
		_start_fight()
	else:
		open_fight_popup()


func _on_buy(id: String) -> void:
	var before := GameData.money
	var text := GameData.buy(id)
	say(text, "buy" if GameData.money < before or GameData.part_def(id)["cost"] == 0 else "error")
	refresh()


## Fit a part from storage: compare it with what's on the robot now, slot by slot, then pick.
func _on_fit_choose(uid: int, slots: Array) -> void:
	var p := GameData.inst(uid)
	var d := GameData.part_def(p["id"])
	var col := open_popup(tr("FIT %s") % str(d["name"]).to_upper())
	col.custom_minimum_size = Vector2(720, 0)
	col.add_child(UI.label(tr("GOING ON:"), 15, Color(0.5, 1.0, 0.6)))
	make_row(part_icon(d, GameData.hp_ratio(p)), tr("%s  [%s]") % [d["name"], tr(str(d["kind"]).to_upper())], health_text(p), col)
	col.add_child(UI.label(tr("COMING OFF:") if slots.size() == 1 else tr("COMING OFF - pick the slot:"), 15, Color(1.0, 0.7, 0.4)))
	for sl in slots:
		var cur := GameData.equipped_inst(sl)
		var row: HBoxContainer
		if cur.is_empty():
			row = make_row(part_icon({}), tr("%s: empty") % tr(GameData.SLOT_NAMES[sl]), tr("Nothing there now."), col)
		else:
			var cd := GameData.part_def(cur["id"])
			row = make_row(part_icon(cd, GameData.hp_ratio(cur)), tr("%s: %s") % [tr(GameData.SLOT_NAMES[sl]), cd["name"]], health_text(cur), col)
		row_button(row, "Fit here", _on_fit_pick.bind(uid, sl), true, 110)


func _on_fit_pick(uid: int, slot: String) -> void:
	close_popup()
	_on_equip(uid, slot)


func _on_equip(uid: int, slot: String) -> void:
	say(GameData.equip(uid, slot), "equip")
	refresh()


func _on_unequip(slot: String) -> void:
	GameData.unequip(slot)
	say(tr("Removed the %s. It's in Storage.") % tr(GameData.SLOT_NAMES[slot]), "equip")
	refresh()


func _on_repair(uid: int) -> void:
	spark_at = Time.get_ticks_msec() / 1000.0
	var before := GameData.money
	var text := GameData.repair(uid)
	say(text, "repair" if GameData.money < before else "error")
	refresh()


func _on_repair_all() -> void:
	spark_at = Time.get_ticks_msec() / 1000.0
	var before := GameData.money
	var text := GameData.repair_all()
	say(text, "repair" if GameData.money < before else "error")
	refresh()


func _on_randomize() -> void:
	if gus_explains("randomize"):
		return
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


## Selling asks first: a misplaced tap shouldn't cost you a part.
func _on_sell(uid: int) -> void:
	var p := GameData.inst(uid)
	if p.is_empty():
		return
	var col := open_popup(tr("SELL IT?"))
	var l := UI.label(tr("Sell %s for $%d? It's gone for good.") % [GameData.part_def(p["id"])["name"], GameData.sell_value(p)], 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var yes := UI.button(tr("Sell $%d") % GameData.sell_value(p), _on_sell_confirmed.bind(uid), 18, Vector2(0, 50))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	var no := UI.button("Keep it", close_popup, 18, Vector2(0, 50))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)


func _on_sell_confirmed(uid: int) -> void:
	close_popup()
	say(GameData.sell(uid), "sell")
	refresh()


## A chip for sale (from the dealer, or ordered = made to order): name, combo, what it does, a look, buy.
func chip_row(id: String, ordered: bool) -> void:
	var m: Dictionary = Specials.MOVES[id]
	var icon := ChipIcon.new()
	var row := make_row(icon, tr("%s    %s") % [tr(m["name"]), Specials.seq_text(m["seq"])], tr("%s  Cooldown %ds.") % [tr(m["desc"]), int(m["cd"])])
	row_button(row, "See it", _on_chip_preview.bind(id), true, 90)
	var price := GameData.chip_price(id, ordered)
	row_button(row, (tr("Order $%d") if ordered else tr("Buy $%d")) % price, _on_buy_chip.bind(id, ordered), GameData.money >= price, 115)


## Watch a chip's move before you buy it.
func _on_chip_preview(id: String) -> void:
	var m: Dictionary = Specials.MOVES[id]
	var col := open_popup(tr(m["name"]).to_upper())
	var demo := MoveDemo.new()
	demo.custom_minimum_size = Vector2(480, 270)
	demo.move = id
	col.add_child(demo)
	var l := UI.label(tr("%s   %s") % [Specials.seq_text(m["seq"]), tr(m["desc"])], 15, Color(0.5, 0.9, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)


func _on_buy_chip(id: String, ordered: bool = false) -> void:
	var before := GameData.money
	var text := GameData.buy_chip(id, ordered)
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
	say(tr("Painted %s.") % tr(GameData.PAINTS[k]["name"]), "equip")
	refresh()


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
	say(tr("Entered the %s! First opponent: %s.") % [GameData.circuit["name"], GameData.current_opponent()["name"]], "fight")
	refresh()


func _on_abandon() -> void:
	GameData.abandon_circuit()
	GameData.save_game()
	say("Left the cup.", "error")
	refresh()


func _on_save() -> void:
	if GameData.save_game():
		say("Game saved.", "buy")
	else:
		say("Couldn't save!", "error")


func _on_menu() -> void:
	GameData.save_game()   # leaving always saves
	get_tree().change_scene_to_file("res://main.tscn")


func _on_send() -> void:
	var options: Array = [-1]
	for k in GameData.wingmen.size():
		if GameData.wingman_ready(k):
			options.append(k)
	GameData.sending = options[(options.find(GameData.sending) + 1) % options.size()]
	say(tr("%s will fight the next 1-on-1. %s") % [GameData.sending_name(),
			tr("Its damage stays on it - your main robot sits this one out.") if GameData.sending >= 0 else ""], "click")
	refresh()


## What's wrong with the robot before a fight: missing limbs, a hurt core, parts hanging off.
func damage_report() -> Array:
	var out: Array = []
	if GameData.sending >= 0 and not GameData.is_team_fight():
		return out   # the backup robot fights this one
	for slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		var p := GameData.equipped_inst(slot)
		var name: String = tr(GameData.SLOT_NAMES[slot])
		if p.is_empty():
			out.append(tr("No %s fitted!") % name.to_lower())
			continue
		var h := GameData.hp_ratio(p)
		if (slot == "torso" and h < 0.75) or h < 0.5:
			out.append(tr("%s at %d%% health") % [name, int(h * 100)])
	return out


## Fight! Always a last look first: who it is, a chance to scout them, and what's wrong with your robot.
func _on_fight() -> void:
	open_fight_popup()


func open_fight_popup() -> void:
	var o := GameData.current_opponent()
	var col := open_popup((tr("WEDNESDAY NIGHT - CUP") if GameData.fight_mode() == "circuit" else tr("WEDNESDAY NIGHT")) if GameData.day == "wed" else tr("SATURDAY NIGHT"))
	col.custom_minimum_size = Vector2(640, 0)
	fight_popup_open = true
	var who := str(o.get("pilot", ""))
	var head := UI.label(GameData.fight_title() + "\n" + (tr("%s, piloted by %s") % [o.get("name", "?"), who] if who != "" else str(o.get("name", "?"))) + "   " + tr("Purse: $%d") % GameData.current_reward(), 18, Color(1.0, 0.85, 0.4))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	if GameData.day == "wed" and ["league", "playoff"].has(str(GameData.week_plan(GameData.year, GameData.week, "sat")["kind"])):
		var warn := UI.label(tr("Your league fight is this Saturday - whatever breaks tonight has to be fixed (and paid for) by then."), 15, Color(0.75, 0.85, 1.0))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	if GameData.day == "wed" and GameData.fight_mode() != "circuit":
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 10)
		col.add_child(wrow)
		var wl := UI.label(tr("No cup for you this Wednesday - just a pickup fight for a few dollars. Or sit it out and save the robot for Saturday."), 15, Color(0.75, 0.85, 1.0))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrow.add_child(wl)
		wrow.add_child(UI.button(tr("Skip to Saturday"), _on_skip_wednesday, 16, Vector2(190, 46)))
	# scouting: pay a kid with a camera to look at their robot first
	if GameData.scout_key() != "" and GameData.unlocked("scout"):
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		col.add_child(srow)
		var sl := UI.label(tr("You know what they're bringing.") if GameData.scouted() else tr("Scout them first? A kid at the docks sneaks a camera into their garage."), 15, Color(0.75, 0.85, 1.0))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(sl)
		var sb := UI.button(star(tr("Scouting report") if GameData.scouted() else tr("Scout $%d") % GameData.scout_cost(), "scout"), _on_open_scout, 16, Vector2(170, 46))
		sb.disabled = not GameData.scouted() and GameData.money < GameData.scout_cost()
		srow.add_child(sb)
	# damage: missing limbs, a hurt core, parts hanging off
	var issues := damage_report()
	if not issues.is_empty():
		col.add_child(UI.label(tr("YOUR ROBOT IS DAMAGED"), 17, Color(1.0, 0.45, 0.35)))
		for line in issues:
			col.add_child(UI.label("• " + str(line), 16, Color(1.0, 0.55, 0.45)))
		var hint := UI.label(tr("GUS: Fight like this and it's going to hurt. Your call, kid."), 14, Color(0.95, 0.75, 0.45))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var cost := GameData.repair_all_cost()
	if not issues.is_empty() and cost > 0 and GameData.can_repair(cost):
		var rb := UI.button(tr("Repair all $%d") % cost, _on_repair_then_fight_popup, 17, Vector2(0, 50))
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rb)
	var back := UI.button("Back to the bay", close_popup, 17, Vector2(0, 50))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	var go := UI.button(tr("FIGHT!") if issues.is_empty() else tr("Fight anyway"), _start_fight, 19, Vector2(0, 50))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)


func _on_repair_then_fight_popup() -> void:
	close_popup()
	_on_repair_all()
	open_fight_popup()


func _on_repair_then_close() -> void:
	close_popup()
	_on_repair_all()


func _start_fight() -> void:
	close_popup()
	GameData.save_game()
	var idx := GameData.current_opponent_index()
	if idx >= 0 and GameData.queue_story("pre_%d" % idx, "res://fight.tscn"):
		get_tree().change_scene_to_file("res://story.tscn")
	else:
		get_tree().change_scene_to_file("res://fight.tscn")
