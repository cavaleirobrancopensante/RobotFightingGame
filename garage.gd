extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const Catalog = preload("res://catalog.gd")
const PartIcon = preload("res://part_icon.gd")
const PilotArt = preload("res://pilot_art.gd")
const Logos = preload("res://logos.gd")
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
var stats_panel: PanelContainer
## The robot's stats panel only shows where the robot is being looked at, fixed or fitted - not
## at the pub, in the office, on the scrapyard pile or in the crew bay.
const STATS_SCENES := ["build", "moves", "paint", "storage", "shop", "workshop"]
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
		if pv.front and not pv.look.is_empty():
			# where the robot's shoulders and head are, so the gantry's chains reach them
			var k: float = pv._sc * float(pv.look.get("scale", 1.0))
			var fg := RobotArt.front_geom(pv.look)
			var sh: Vector2 = fg["shoulder"]
			var top: float = minf((fg["head"] as Rect2).position.y, (fg["head2"] as Rect2).position.y if pv.look["parts"].get("head2", {}).has("shape") else 0.0)
			info["gantry"] = {"left": pv._base + Vector2(-sh.x, sh.y) * k, "right": pv._base + sh * k,
					"top": pv._base.y + top * k, "reach": (sh.x + 38.0) * k}
		GarageArt.draw_back(self, size, stage, garage.scene, t, info)
		GarageArt.draw_front(self, stage, garage.scene, t, info, pv._base, pv.robot_height)
		# where everyone's head is on screen, for the speech bubbles
		var xf := get_global_transform()
		var heads: Dictionary = info.get("heads", {})
		garage.heads = {}
		for k in heads:
			garage.heads[k] = xf * (stage.position + heads[k])
var fight_button: Button
var rail_buttons := {}   # section -> its rail button (the tour points at them)
var tour_arrow: Control
var tour_said := -1
var tour_clock := ""   # the time when the current tour step started (the NEXT step waits for it to move)


func clock_key() -> String:
	return "%d/%d/%s/%d" % [GameData.year, GameData.week, GameData.day, GameData.phase]
var body_map: BodyMap
var rail_box: VBoxContainer
var date_button: Button
var bell_button: Button
var repair_all_btn: Button
var dig_button: Button   # Scrapyard: Dig anywhere (the tour points at it)   # Bay > Robot: Repair all, at the top of the part list   # bottom left: how ready the robot will be tonight; opens the job board
var left_col: VBoxContainer
var bubble
const GUI = preload("res://garage_ui.gd")
const PartNotes = preload("res://part_notes.gd")
const RobotArt = preload("res://robot_art.gd")


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
var send_button: Button
var overlay: Control
var popup_scroll: ScrollContainer   # the open pop-up's contents (scrolls when they don't fit)
var popup_footer: VBoxContainer     # the open pop-up's pinned buttons
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
	date_button.add_theme_font_size_override("font_size", UI.px(24))
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
	preview.callout_font = GUI.bold()
	preview.background_tapped.connect(_on_backdrop_tapped)
	left_col.add_child(preview)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	var sp := GUI.box(Color(0.03, 0.04, 0.03, 0.85), 10, 8)
	sp.content_margin_left = 12
	sp.content_margin_right = 12
	sp.border_color = Color(0.14, 0.19, 0.16)
	sp.set_border_width_all(1)
	stats_panel = PanelContainer.new()
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
	# SHOW_NEVER, not DISABLED: a row that's still too wide gets clipped at the panel's edge
	# instead of pushing the whole screen wider than the phone
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	UI.drag_scroll(scroll, func(): return overlay != null and is_instance_valid(overlay) and overlay.visible)
	right.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 5)
	scroll.add_child(list_box)

	# people talk over the scene: Gus and you in bubbles, rivals on a video call, the narrator in a caption
	bubble = GUI.TalkBox.new()
	bubble.text_label.add_theme_font_override("font", GUI.bold())
	bubble.name_label.add_theme_font_override("font", GUI.headb())
	bubble.visible = false
	bubble.tapped.connect(_on_talk_tap)
	bubble.checked.connect(_talk_next)
	add_child(bubble)
	# the detail pane: covers the scene on the left with whatever you tapped in a list
	detail_panel = PanelContainer.new()
	var dps := GUI.box(Color(0.055, 0.055, 0.075, 0.95), 12, 12)
	dps.border_color = Color(0.227, 0.227, 0.282)
	dps.set_border_width_all(2)
	detail_panel.add_theme_stylebox_override("panel", dps)
	detail_panel.visible = false
	add_child(detail_panel)
	move_child(detail_panel, bubble.get_index())
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 8)
	detail_panel.add_child(dcol)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dcol.add_child(dscroll)
	detail_box = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 6)
	dscroll.add_child(detail_box)
	# the buttons stay put at the bottom, never scrolled away
	detail_footer = GridContainer.new()
	detail_footer.columns = 2
	detail_footer.add_theme_constant_override("h_separation", 6)
	detail_footer.add_theme_constant_override("v_separation", 6)
	dcol.add_child(detail_footer)
	msg_label = bubble.text_label

	# bottom: repair, which robot goes in, the damage map and the FIGHT button
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	bell_button = UI.button("", _on_bell, 15, Vector2(230, 46))
	bell_button.add_theme_font_override("font", GUI.num())
	bell_button.add_theme_font_size_override("font_size", UI.px(22))
	bottom.add_child(bell_button)
	send_button = UI.button("", _on_send, 14, Vector2(150, 46))
	bottom.add_child(send_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
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
	# what the fight brought home is a note (the results screen already told the story); Gus only
	# speaks up when he has advice
	note(msg_label.text)
	msg_label.text = ""
	say(GameData.garage_tip())
	refresh()
	# story moments play right here: what happened at the fight, and Gus's first welcome to the bay
	var keys: Array = GameData.bay_stories
	GameData.bay_stories = []
	keys.append("first_garage")
	if GameData.converted_note:
		GameData.converted_note = false
		keys.append({"lines": [["GUS", tr("Big news, kid. The leagues changed. Now it's one table a year, every other Saturday, a point a win. Top four go up, bottom four go down. We start this year in the %s.") % tr(Career.STAGES[GameData.rank]["name"]), {}]]})
	play_story(keys)
	# back from Gus explaining something (older saves): open it for you
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
	# in the order of a day: the robot, its parts, the week's plan, the town, your phone, the crew
	var t := ["Bay", "Storage", "Parts"]
	if GameData.unlocked("season"):
		t.append("Season")
	t += ["Pub", "Feed"]
	if GameData.team_unlocked():
		t.append("Crew")
	return t


const SECTION_LABELS := {"Bay": "Bay", "Storage": "Storage", "Parts": "Get Parts", "Pub": "Rusty Bolt", "Feed": "BotMedia", "Season": "Season", "Crew": "Crew"}
const SECTION_ICONS := {"Bay": "bay", "Storage": "storage", "Parts": "parts", "Pub": "pub", "Feed": "feed", "Season": "season", "Crew": "crew"}
## Where each feature lives now: [section, toggle]. Gus's unlock scene returns you there.
const FEATURE_PLACE := {"scrapyard": ["Parts", "scrap"], "storage": ["Storage", ""], "style": ["Bay", "style"],
		"shop": ["Parts", "dealer"], "season": ["Season", "calendar"], "scout": ["", "scout"], "moves": ["Bay", "chips"],
		"cups": ["Season", "cups"], "team": ["Crew", "backups"], "workshop": ["Parts", "order"], "pilot": ["Feed", "gear"],
		"paint": ["Bay", "style"], "setups": ["Bay", "setups"], "randomize": ["Bay", "robot"]}


## A section's toggle bar: [key, label, feature that unlocks it (for its star)].
func segs_of(t: String) -> Array:
	var out: Array = []
	match t:
		"Bay":
			out.append(["robot", tr("Robot"), ""])
			out.append(["jobs", tr("Job board %d") % GameData.jobs.size() if not GameData.jobs.is_empty() else tr("Job board"), ""])
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
			out.append(["pilots", tr("Pilots"), ""])
		"Feed":
			# BotMedia: the feed, Explore, Alerts, your DMs and your profile (Looks, Gear and
			# Contracts open from the profile; hidden = no button on the bar)
			out.append(["home", tr("Home"), ""])
			out.append(["explore", tr("Explore"), ""])
			out.append(["alerts", tr("Alerts %d") % GameData.alerts_unseen if GameData.alerts_unseen > 0 else tr("Alerts"), ""])
			out.append(["all", tr("DMs"), ""])
			out.append(["profile", tr("Profile"), ""])
			out.append(["looks", tr("Looks"), "", true])
			if GameData.unlocked("pilot"):
				out.append(["gear", tr("Gear"), "pilot", true])
			out.append(["contracts", tr("Contracts"), "", true])
		"Pub":
			# The Rusty Bolt: the scene stays the same pub while you switch between these
			out.append(["bar", tr("Bar"), ""])
			out.append(["bets", tr("Bets"), ""])
			out.append(["jukebox", tr("Jukebox"), ""])
		"Crew":
			if GameData.team_unlocked():
				out.append(["backups", tr("Backups"), "team"])

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
		"Feed":
			if GameData.inbox.size() > GameData.inbox_seen or GameData.alerts_unseen > 0 or not GameData.Social.drafts().is_empty():
				return true
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
		GUI.mark_new(b, section_new(t))
		b.font = GUI.head()
		b.pressed.connect(func(): Sfx.play("click", 0.05); _on_tab(t))
		rail_box.add_child(b)
		rail_buttons[t] = b
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
## The big yellow button's text shrinks until it fits beside the Bell chip (long labels, big text,
## Portuguese and Spanish).
func fit_fight_font() -> void:
	var f: Font = GUI.stencil()
	var room := get_viewport_rect().size.x - 92.0 - bell_button.get_combined_minimum_size().x - 52.0 - 60.0
	if send_button.visible:
		room -= send_button.get_combined_minimum_size().x + 8.0
	var fs := UI.tsz(18)
	while fs > 11 and f.get_string_size(fight_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0 > room:
		fs -= 1
	fight_button.add_theme_font_size_override("font_size", fs)


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
		if sg.size() > 3 and sg[3]:
			continue   # opens from somewhere else (BotMedia's profile)
		var on: bool = sg[0] == seg() or (tab == "Feed" and sg[0] == "profile" and seg() in ["looks", "gear", "contracts"])
		var b := UI.button(str(sg[1]), _on_seg.bind(sg[0]), 13, Vector2(0, 34))
		GUI.mark_new(b, seg_new(sg[0], sg[2]) or (tab == "Feed" and sg[0] == "home" and not GameData.Social.drafts().is_empty())
				or (tab == "Feed" and sg[0] == "profile" and (seg_new("gear", "pilot") and GameData.unlocked("pilot") or contracts_new())))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# long names (big text, Portuguese) shrink instead of pushing the panel off the screen
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = str(sg[1])
		var st := GUI.seg_style(on)
		for k in ["normal", "disabled"]:
			b.add_theme_stylebox_override(k, st[0])
		for k in ["hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, st[1])
		b.add_theme_color_override("font_color", Color.WHITE if on else GUI.MUTED)
		tabs_box.add_child(b)
	if tab == "Bay" and seg() == "robot":
		if GameData.unlocked("setups"):
			tabs_box.add_child(marked(UI.button(tr("Setups ▾"), _on_open_setups, 12, Vector2(96, 34)), "setups"))
		if GameData.unlocked("randomize"):
			tabs_box.add_child(marked(UI.button(tr("Randomize"), _on_randomize, 12, Vector2(100, 34)), "randomize"))


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
		bills = (tr(" End of the month: rent and food, -$%d.") if GameData.rank_index() < 2 else tr(" End of the month: rent, crew and travel, -$%d.")) % GameData.bills_note
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
			bits.append(tr("CUP OVER: %s.") % r["cup_done"])
		if r.get("event_done", "") != "":
			bits.append(tr("SEASON OVER: %s. See the Season tab.") % str(r["event_done"]).trim_suffix("!").trim_suffix("."))
		if r.get("trophy", "") != "":
			bits.append(tr("Trophy part: %s.") % r["trophy"])
		if not r.get("lost", []).is_empty():
			bits.append(tr("Lost: %s.") % ", ".join(r["lost"]))
		if not r.get("wrecked", []).is_empty():
			bits.append(tr("Wrecked: %s (rebuild in Storage).") % ", ".join(r["wrecked"]))
		if not r.get("salvaged", []).is_empty():
			bits.append(tr("Salvaged: %s.") % ", ".join(r["salvaged"]))
		if r.get("out_of_debt", false):
			bits.append(tr("OUT OF THE HOLE! You don't owe Gus a cent!"))
		msg_label.text = " ".join(bits) + bills
	GameData.last_result = {}


## What just happened (bought, fitted, sold, not enough money...): a short note at the bottom of
## the scene that fades by itself. Gus's bubbles are kept for things worth hearing from him.
var toast: PanelContainer
var toast_label: Label
var toast_t := 0.0


func note(text: String, sound: String = "") -> void:
	text = text.trim_prefix(tr("GUS: ")).trim_prefix("GUS: ").strip_edges()
	if sound != "":
		Sfx.play(sound)
	if text == "":
		return
	if toast == null:
		toast = PanelContainer.new()
		var st := GUI.box(Color(0.05, 0.05, 0.07, 0.92), 10, 8)
		st.border_color = Color(GUI.YELLOW, 0.7)
		st.set_border_width_all(2)
		st.content_margin_left = 14
		st.content_margin_right = 14
		toast.add_theme_stylebox_override("panel", st)
		toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast_label = UI.label("", 15, Color(0.95, 0.93, 0.85))
		toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast.add_child(toast_label)
		add_child(toast)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55) if sound == "error" else Color(0.95, 0.93, 0.85))
	toast_label.text = text
	toast_t = clampf(2.4 + text.length() * 0.04, 2.4, 8.0)
	toast.visible = true
	move_child(toast, -1)
	_place_toast()


func _place_toast() -> void:
	if toast == null or left_col == null or preview == null:
		return
	var w := minf(left_col.size.x - 24.0, UI.tsz(15) * 30.0)
	var tw := toast_label.get_theme_font("font").get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, toast_label.get_theme_font_size("font_size")).x + 32.0
	toast.size = Vector2(minf(w, tw), 0)
	toast.size = toast.get_combined_minimum_size().max(Vector2(minf(w, tw), 0))
	toast.position = left_col.global_position + Vector2((left_col.size.x - toast.size.x) * 0.5, preview.size.y - toast.size.y - 14.0)
	toast.modulate.a = clampf(toast_t * 2.5, 0.0, 1.0)


## Gus says something worth hearing (advice, his tour, the story). During a story scene it waits its turn.
func say(text: String, sound: String = "") -> void:
	text = text.trim_prefix(tr("GUS: ")).trim_prefix("GUS: ").strip_edges()
	if sound != "":
		Sfx.play(sound)
	if text == "":
		return
	GameData.log_talk("GUS", text, "gus")
	# lines queue up behind the one on screen (nothing gets lost); the ✓ shows how many are waiting
	if not talk_lines.is_empty() and str(talk_lines[-1][1]) == text:
		return
	talk_lines.append(["GUS", text, {}])
	if talk_lines.size() > 40:
		talk_lines = [talk_lines[0]] + talk_lines.slice(talk_lines.size() - 39)
	if talk_lines.size() == 1 or not bubble.visible:
		_talk_show()
	else:
		_talk_count()


func _talk_count() -> void:
	if bubble:
		bubble.ok.count = maxi(0, talk_lines.size() - 1)
		GUI.mark_new(bubble.ok, bubble.ok.count > 0)   # more to hear: tap on
		bubble.ok.queue_redraw()


# ---------------------------------------------------------------- talking

const Story = preload("res://story_data.gd")
const TALK_CPS := 55.0
var heads := {}              # who -> where their head is on screen (filled in by the backdrop)
var talk_lines: Array = []   # [who, text, extra] still to show; the first one is on screen
var repair_tapped := false     # the tour's first stop is done once you've tried Repair all
var dad_talk := false        # Gus is pointing at your dad's trophies (office, first visit)
var talk_story := false      # a story scene is playing (lines stay up longer, Skip shows)
var talk_after := Callable() # what happens when the scene is over (pre-fight talk: start the fight)
var talk_shown := 0.0
var talk_left := 0.0
var talk_life := 1.0
var talk_beep := 0.0


## Plays story scenes right here in the garage. Scenes already seen are skipped. False if nothing to play.
func play_story(keys: Array, after: Callable = Callable()) -> bool:
	var lines: Array = []
	for k in keys:
		if typeof(k) == TYPE_DICTIONARY:
			lines += talk_screens(k.get("lines", []))   # emergent talk: rivals, the pub, streaks
		elif Story.SCENES.has(k) and (not GameData.story_seen.has(k) or str(k).begins_with("stay_") or str(k).begins_with("down") or str(k).begins_with("up_") or str(k).begins_with("title_")):
			lines += story_screens(k)
			GameData.mark_story_seen(k)
	if lines.is_empty():
		return false
	for l in lines:
		GameData.log_talk(str(l[0]), str(l[1]), "story" if str(l[2].get("place", "")) != "*" else "talk", l[2].get("look", {}), int(l[2].get("wid", -1)))
	if talk_story:
		talk_lines += lines   # a scene already playing finishes first
	else:
		talk_lines = lines + talk_lines   # messages that were waiting come back after the scene
	talk_story = true
	if after.is_valid() or not talk_after.is_valid():
		talk_after = after
	_talk_show()
	GameData.request_save()
	return true


## Ready-made lines ([who, text, extra]) from GameData's emergent talk: already translated.
func talk_screens(raw: Array) -> Array:
	var out: Array = []
	for l in raw:
		var extra: Dictionary = (l[2] as Dictionary).duplicate() if l.size() > 2 else {}
		extra["place"] = "*"
		out.append([str(l[0]), str(l[1]).replace("ECHO", GameData.robot_name), extra])
	return out


## A scene's lines, translated, with the lines that depend on your game filled in.
func story_screens(key: String) -> Array:
	var out: Array = []
	var place: String = Story.SCENES[key].get("place", "")
	for l in Story.SCENES[key]["lines"]:
		var who: String = l[0]
		var text := str(l[1])
		text = GameData.story_dynamic(text.substr(1, text.length() - 2)) if text.begins_with("{") else tr(text)
		text = text.replace("ECHO", GameData.robot_name)
		if text == "":
			continue
		if not out.is_empty() and out[-1][0] == who and str(out[-1][1]).length() + text.length() < 170:
			out[-1][1] = str(out[-1][1]) + " " + text
		else:
			out.append([who, text, {"place": place}])
	return out


func talk_mode(who: String) -> String:
	if who in ["GUS", "YOU"] or (heads.has(who) and not Story.SPEAKERS.has(who)):
		return "bubble"   # (a pilot standing in the scene, like the one at the bar, talks in a bubble)
	if who in ["NARRATOR", "ECHO"]:
		return "caption"
	return "call"


func _talk_show() -> void:
	if talk_lines.is_empty():
		_talk_end()
		return
	var who: String = talk_lines[0][0]
	var mode := talk_mode(who)
	var accent := Color(Story.SPEAKERS.get(who, {"color": "#ffffff"})["color"])
	bubble.set_mode(mode, accent)
	var shown_name := who
	if who == "YOU":
		shown_name = GameData.pilot_name.to_upper()
	elif who == "ECHO":
		shown_name = GameData.robot_name
	bubble.name_label.text = "" if who == "NARRATOR" else ("● " + shown_name if mode == "call" else shown_name)
	bubble.text_label.add_theme_font_override("font", GUI.num() if who == "ECHO" else GUI.bold())
	bubble.text_label.add_theme_font_size_override("font_size", UI.px(21 if who == "ECHO" else 17))
	bubble.text_label.text = str(talk_lines[0][1])
	bubble.text_label.visible_characters = 0
	for c in bubble.face_slot.get_children():
		c.queue_free()
	if mode == "call":
		var face = StoryScript.Portrait.new()
		face.who = who
		face.face_look = talk_lines[0][2].get("look", {})
		face.place = str(talk_lines[0][2].get("place", ""))
		face.robot_look = GameData.player_look()
		face.talking = true
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.face_slot.add_child(face)
	talk_shown = 0.0
	talk_beep = 0.0
	var n: int = bubble.text_label.text.length()
	talk_life = (5.0 + n * 0.07) if talk_story else (3.5 + n * 0.05)
	talk_left = talk_life
	bubble.bar.visible = false
	_talk_count()
	bubble.visible = true
	move_child(bubble, -1)
	_place_talk()


func _talk_typing() -> bool:
	return bubble.text_label.visible_characters >= 0 and bubble.text_label.visible_characters < bubble.text_label.text.length()


## Tapping the box: show the whole line first, then move on.
func _on_talk_tap() -> void:
	if _talk_typing():
		bubble.text_label.visible_characters = -1
	else:
		_talk_next()


func _talk_next() -> void:
	if not talk_lines.is_empty():
		talk_lines.pop_front()
	_talk_show()


## Skip the rest of the story scene (any message that was waiting still shows).
func _talk_skip() -> void:
	talk_lines = talk_lines.filter(func(l): return l[2].has("place") == false)
	talk_story = false
	_talk_end_story()
	_talk_show()


func _talk_end() -> void:
	bubble.visible = false
	_talk_end_story()


func _talk_end_story() -> void:
	talk_story = false
	if dad_talk:
		dad_talk = false
		refresh()
	if talk_after.is_valid():
		var after := talk_after
		talk_after = Callable()
		after.call()


## Bubbles sit above the speaker's head with the tail pointing at it; calls and captions go
## across the top of the scene.
func _place_talk() -> void:
	if left_col == null or preview == null:
		return
	var area := Rect2(left_col.global_position, Vector2(left_col.size.x, preview.size.y))
	var who: String = talk_lines[0][0] if not talk_lines.is_empty() else "GUS"
	if bubble.mode != "bubble":
		bubble.size = Vector2(area.size.x - 20.0, 0)
		bubble.size = bubble.get_combined_minimum_size().max(Vector2(area.size.x - 20.0, 0))
		bubble.position = area.position + Vector2(10, 10)
		return
	bubble.size = bubble.get_combined_minimum_size()
	var sz: Vector2 = bubble.size
	if not heads.has(who):
		bubble.position = area.position + Vector2(14, 10)
		bubble.tail = Vector2.INF
		bubble.queue_redraw()
		return
	var head: Vector2 = heads[who]
	var pos := Vector2(head.x - sz.x * 0.3, head.y - sz.y - 34.0)
	if pos.y < area.position.y + 6.0:
		# no room above: sit beside the head instead, on whichever side has more room
		pos.y = clampf(head.y - sz.y * 0.5, area.position.y + 6.0, area.end.y - sz.y - 6.0)
		pos.x = head.x + 40.0 if head.x < area.get_center().x else head.x - 40.0 - sz.x
	pos.x = clampf(pos.x, area.position.x + 6.0, maxf(area.position.x + 6.0, area.end.x - sz.x - 6.0))
	bubble.position = pos
	bubble.tail = head - pos
	bubble.queue_redraw()


func _process(delta: float) -> void:
	update_jukebox()
	update_tour()
	if toast and toast.visible:
		toast_t -= delta
		toast.visible = toast_t > 0.0
		_place_toast()
	if detail_panel and detail_panel.visible and left_col:
		detail_panel.position = left_col.global_position
		detail_panel.size = left_col.size
	if bubble == null or not bubble.visible:
		return
	_place_talk()
	if _talk_typing():
		talk_shown += delta * TALK_CPS
		bubble.text_label.visible_characters = int(talk_shown)
		talk_beep -= delta
		# every line that types out talks, not just story scenes (narrator captions stay silent)
		if talk_beep <= 0.0 and not talk_lines.is_empty() and talk_lines[0][0] != "NARRATOR":
			talk_beep = 0.07
			Sfx.voice(str(talk_lines[0][0]))
		return
	# no timer: a line stays up until you tap ✓ (the number on it says how many more are waiting)


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if not GameData.pending_talk.is_empty() and not talk_story and bubble != null:
		var mail: Array = GameData.pending_talk
		GameData.pending_talk = []
		(func(): play_story(mail)).call_deferred()
	money_label.text = GameData.money_text(GameData.money)
	money_label.add_theme_color_override("font_color", GUI.RED if GameData.money < 0 else GUI.AMBER)
	date_button.text = tr("%s %s · WK %d") % [tr(DAY_NAMES[GameData.day_index()]), tr(PHASE_SHORT[GameData.phase]), GameData.week]
	# the bell chip: how ready the robot will be by tonight, and how much is on the job board
	var ready := bell_readiness()
	var njobs := GameData.jobs.size()
	bell_button.text = tr("BY TONIGHT %d%%") % roundi(ready * 100.0) + (tr(" · %d JOBS") % njobs if njobs > 0 else "")
	var bc: Color = GUI.GREEN if ready >= 0.9 else (GUI.AMBER if ready >= 0.6 else GUI.RED)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		bell_button.add_theme_color_override(c, bc)
	bell_button.tooltip_text = tr("How much of the robot will be fit to fight by tonight's bell. Tap for the job board.")
	# a fight tonight and the robot won't be ready: that's something to do
	var mode := GameData.fight_mode()   # "open": nothing booked tonight, pickups are your choice (the Rusty Bolt)
	GUI.mark_new(bell_button, mode != "open" and ready < 0.6)
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
	# one button for whatever comes next: the clock until the evening, then tonight's fight (or tomorrow)
	if GameData.phase < 2 or mode == "open":
		# says what the tap does: the bay works this part of the day (or you call it a night)
		fight_button.text = tr(["WORK THE MORNING ▸", "WORK THE AFTERNOON ▸", "CALL IT A NIGHT ▸"][GameData.phase])
		if GameData.phase < 2 and mode != "open":
			fight_button.text += tr(" FIGHT TONIGHT")
		fight_button.disabled = talk_after.is_valid()
	elif not GameData.can_send():
		fight_button.text = tr("FIGHT NIGHT: CHECK THE ROBOT")
		fight_button.disabled = talk_after.is_valid()
	else:
		fight_button.disabled = talk_after.is_valid()   # the rival's still talking; the fight starts after
		var label: String = {"story": "FIGHT: %s ($%d)", "circuit": "CUP FIGHT: %s ($%d)", "exhibition": "REMATCH: %s ($%d)",
				"pickup": "PICKUP FIGHT: %s ($%d)"}.get(mode, "FIGHT: %s ($%d)")
		fight_button.text = tr(label) % [o["name"], GameData.current_reward()]
		if o.has("team_label"):
			fight_button.text += tr(" · %s") % o["team_label"]
		if GameData.sending >= 0 and not GameData.is_team_fight():
			fight_button.text = tr("%s fights %s ($%d)") % [GameData.sending_name(), o["name"], GameData.current_reward()]
		elif not core.is_empty() and GameData.hp_ratio(core) < 0.35:
			fight_button.text += tr(" · core damaged!")

	fit_fight_font()
	preview.look = GameData.player_look()
	body_map.health = body_health()
	body_map.queue_redraw()
	if not tab_list().has(tab):
		tab = "Bay"
	set_seg(seg())
	set_scene_for_tab()
	preview.highlight = selected if tab == "Bay" and seg() == "robot" else ""
	preview.callouts = part_callouts(preview.highlight)
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
				"jobs":
					build_jobs_view()
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
		"Feed":
			if seg() != "alerts":
				alerts_fresh = 0
			match seg():
				"home":
					build_home()
				"explore":
					build_explore()
				"alerts":
					build_alerts()
				"profile":
					profile_bar()
					build_my_posts()
				"looks":
					profile_bar()
					build_pilot_looks()
				"gear":
					profile_bar()
					build_controllers()
				"contracts":
					profile_bar()
					build_contracts()
				_:
					build_feed()
		"Pub":
			match seg():
				"bets":
					build_bets()
				"jukebox":
					build_jukebox()
				_:
					build_pub_cards()
		"Crew":
			if seg() == "pilot":
				build_pilot_view()
			else:
				build_team_tab()
	build_detail()
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
	# core: blocks of 25 HP, like every part; power: one block per point of power
	stat_cell(grid, "Core", _seg(s["core"], s["core_max"], GUI.HP_UNIT, GUI.GREEN), "%d/%d" % [s["core"], s["core_max"]], GUI.GREEN)
	stat_cell(grid, "Power", _seg(s["power_used"], s["power_output"], 1.0, GUI.RED if over else GUI.CYAN), "%d/%d" % [s["power_used"], s["power_output"]], GUI.RED if over else GUI.CYAN)
	# 1 block = 10%
	var dmg_bar := GUI.BlockBar.new()
	dmg_bar.setup(float(s["damage"]), 10.0, maxf(170.0, float(s["damage"])), GUI.RED)
	stat_cell(grid, "Damage", dmg_bar, "%d%%" % s["damage"], Color(1.0, 0.6, 0.5))
	var spd_bar := GUI.BlockBar.new()
	spd_bar.setup(float(s["speed"]), 10.0, maxf(150.0, float(s["speed"])), GUI.CYAN)
	stat_cell(grid, "Speed", spd_bar, "%d%%" % s["speed"], GUI.CYAN)
	if over:
		stats_box.add_child(GUI.text(tr("OVERLOADED: %d%% performance!") % int(s["efficiency"] * 100), 11, GUI.RED, "headb"))
	var spare: int = maxi(0, int(s["power_output"]) - int(s["power_used"]))
	var tank: float = GameData.fight_tank(float(s["power_output"]), float(s["power_used"])) * (1.25 if GameData.style == "tank" else 1.0)
	var pl := GUI.text(tr("%s · fight power %d (+%d unused)") % [tr(GameData.weight_class(s["power_used"])), int(tank), spare], 10, GUI.MUTED, "headb")
	pl.tooltip_text = "In a fight your power output is your tank, and power your parts don't use is added on top. Every move spends some; it refills when you stop attacking. Empty = burnout."
	stats_box.add_child(pl)


func _seg(value: float, maximum: float, unit: float, col: Color) -> Control:
	var b := GUI.SegBar.new()
	b.setup(value * GUI.HP_UNIT / unit, maximum * GUI.HP_UNIT / unit, col)
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

func make_row(icon: Control, title: String, subtitle: String, parent: Control = null, tag: String = "") -> Container:
	var panel := PanelContainer.new()
	(parent if parent else list_box).add_child(panel)
	var row := GUI.WrapRow.new()
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
	if subtitle.contains("[color="):
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.scroll_active = false
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rl.add_theme_font_override("normal_font", GUI.body())
		rl.add_theme_font_size_override("normal_font_size", UI.px(11))
		rl.add_theme_color_override("default_color", Color(0.68, 0.68, 0.75))
		rl.text = subtitle
		info.add_child(rl)
	elif subtitle != "":
		var sl := GUI.text(subtitle, 11, Color(0.68, 0.68, 0.75))
		if wrap:
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			sl.clip_text = true
		info.add_child(sl)
	return info


## A whole-row button (tap anywhere on it), with an icon, two lines of text and extra widgets.
func make_tap_row(icon: Control, title: String, subtitle: String, cb: Callable, tag: String = "", sel: bool = false) -> Container:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05))
	b.pressed.connect(cb)
	var n := GUI.box(GUI.ROW, 10, 4)
	GUI.mark_new(b, sel)   # the open row: the same marching stripes as the part picked on the gantry
	var h := GUI.box(GUI.ROW.lightened(0.05), 10, 4)
	var pr := GUI.box(GUI.ROW, 10, 4)
	pr.border_color = GUI.YELLOW
	pr.set_border_width_all(2)
	for st in [["normal", n], ["hover", h], ["pressed", pr], ["hover_pressed", pr]]:
		b.add_theme_stylebox_override(st[0], st[1])
	list_box.add_child(b)
	var row := GUI.WrapRow.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -8
	row.offset_top = 5
	row.offset_bottom = -5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# the button grows with the row when its buttons drop to a second line
	row.minimum_size_changed.connect(func(): b.custom_minimum_size.y = maxf(62.0, row.get_combined_minimum_size().y + 10.0))
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(row_text(title, subtitle, tag, true))
	return row


## The notes drawn off the selected part in the bay (what it is, who made it, what's wrong with it).
func part_callouts(slot: String) -> Array:
	if slot == "":
		return []
	var inst := GameData.equipped_inst(slot)
	if inst.is_empty() or not inst.has("id"):
		return [tr("Empty. Tap to fit a part")]
	var d := GameData.part_def(inst["id"])
	var out: Array = []
	for n in PartNotes.notes(d, str(d.get("kind", GameData.SLOT_KIND.get(slot, ""))), GameData.hp_ratio(inst), str(inst.get("uid", inst["id"]))):
		var warn := str(n).begins_with("!")
		out.append(("!" if warn else "") + tr(str(n).trim_prefix("!")))
	return out


# ---------------------------------------------------------------- detail pane

var detail := {}          # what's open in the detail pane: {"src": "inv", "uid": n} or {"src": "shop", "id": id}
var detail_ctx := ""      # where you were when you opened it (moving elsewhere closes it)
var detail_panel: PanelContainer
var detail_box: VBoxContainer
var detail_footer: GridContainer

const SHORT_SLOT := {"arm_front": "Left", "arm_back": "Right", "arm_front2": "Low L", "arm_back2": "Low R",
		"leg_front": "Left", "leg_back": "Right"}
# [key, label, unit, lower is better]
const COMPARE_STATS := {
	"head": [["hp", "HP", "", false], ["armor", "Armor", "%", false], ["aim", "Aim", "%", false], ["chips", "Chips", "", false], ["draw", "Power use", "", true]],
	"torso": [["hp", "HP", "", false], ["armor", "Armor", "%", false], ["speed", "Speed", "%", false], ["draw", "Power use", "", true]],
	"arm": [["hp", "HP", "", false], ["armor", "Armor", "%", false], ["damage", "Damage", "%", false], ["speed", "Speed", "%", false], ["reach", "Reach", "%", false], ["draw", "Power use", "", true]],
	"leg": [["hp", "HP", "", false], ["armor", "Armor", "%", false], ["damage", "Damage", "%", false], ["speed", "Speed", "%", false], ["reach", "Reach", "%", false], ["draw", "Power use", "", true]],
	"back": [["output", "Power out", "", false], ["draw", "Power use", "", true]],
	"reactor": [["output", "Power out", "", false]],
}


func _ctx() -> String:
	return "%s/%s/%s" % [tab, seg(), selected]


func is_detail(src: String, key) -> bool:
	if detail.get("src", "") != src:
		return false
	return str(detail.get("uid" if src == "inv" else "id", "")) == str(key)


func _on_detail(d: Dictionary) -> void:
	detail = {} if detail == d else d   # tapping the open one again closes it
	detail_ctx = _ctx()
	refresh()


func _on_detail_close() -> void:
	detail = {}
	refresh()


## The slots a part of this kind can go in right now.
func slots_for(kind: String) -> Array:
	return GameData.SLOTS.filter(func(sl): return GameData.SLOT_KIND[sl] == kind and GameData.slot_available(sl))


## Slots this part could go in off-label (1.54): a reactor or a leg in an arm slot, an arm in a leg slot.
func off_slots(d: Dictionary) -> Array:
	return GameData.SLOTS.filter(func(sl): return GameData.SLOT_KIND[sl] != str(d["kind"]) and GameData.fits(d, sl) and GameData.slot_available(sl))


## Where a new part of this kind should go: an empty slot first, else the one with the cheapest part on it.
func best_slot(kind: String) -> String:
	var best := ""
	var best_v := INF
	for sl in slots_for(kind):
		var cur := GameData.equipped_inst(sl)
		var v: float = -1.0 if cur.is_empty() else float(GameData.part_def(cur["id"])["cost"]) + GameData.hp_ratio(cur)
		if v < best_v:
			best_v = v
			best = sl
	return best


func _stat_val(d: Dictionary, key: String) -> float:
	if d.is_empty():
		return 0.0
	if key == "reach":
		return float(GameData.reach_pct(d)) if d.get("kind", "") in ["arm", "leg"] else 0.0
	return float(d.get(key, 0))


## "HP +12 · DMG -5%" against what's in the slot now, green when it's better, red when it's worse.
func delta_text(d: Dictionary, slot: String) -> String:
	var cur := GameData.equipped_inst(slot)
	var cd: Dictionary = {} if cur.is_empty() else GameData.part_def(cur["id"])
	var bits: Array = []
	for st in COMPARE_STATS.get(str(d["kind"]), []):
		var diff := _stat_val(d, st[0]) - _stat_val(cd, st[0])
		if absf(diff) < 0.5:
			continue
		var good: bool = (diff < 0.0) if st[3] else (diff > 0.0)
		bits.append("[color=%s]%s %+d%s[/color]" % ["#8dffa6" if good else "#ff7a5a", tr(st[1]), int(diff), st[2]])
	if bits.is_empty():
		return tr("Same as what's on now")
	return tr("vs fitted: ") + " · ".join(bits)


## Fills the detail pane (or hides it): the part big, its notes, how it compares with every slot it
## could go in (green better, red worse), and big buttons for everything you can do with it.
func build_detail() -> void:
	if not detail.is_empty() and detail_ctx != _ctx():
		detail = {}
	var p := {}
	var d := {}
	if detail.get("src", "") == "inv":
		p = GameData.inst(int(detail["uid"]))
		if not p.is_empty():
			d = GameData.part_def(p["id"])
	elif detail.get("src", "") == "shop" and GameData.shop_stock.has(detail["id"]):
		d = GameData.part_def(detail["id"])
	if d.is_empty():
		detail = {}
		if tab == "Season" and seg() == "calendar":
			detail_panel.visible = false   # the office wall (trophies) stays in view; tonight's fight is a strip above the month
		else:
			detail_panel.visible = false
		return
	detail_panel.visible = true
	for c in detail_box.get_children() + detail_footer.get_children():
		c.queue_free()
	var kind := str(d["kind"])
	var inv := not p.is_empty()
	var health := GameData.hp_ratio(p) if inv else 1.0
	# header: icon, name, kind, close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	detail_box.add_child(head)
	var icon := part_icon(d, health)
	icon.custom_minimum_size = Vector2(72, 72)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	names.add_child(GUI.text(tr(kind.to_upper()) + ("" if d["shop"] else "  ·  " + tr("RARE")), 11, GUI.MUTED, "headb"))
	var nl := GUI.text(str(d["name"]), 18, GUI.TEXT, "headb")
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(nl)
	if inv and not GameData.UNDAMAGEABLE.has(kind):
		names.add_child(hp_widget(p))
	elif not inv:
		names.add_child(GUI.readout("$%d" % int(d["cost"]), 22, GUI.AMBER))
	var x := UI.button("×", _on_detail_close, 16, Vector2(40, 40))
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(x)
	# notes and extras (traits, gadgets)
	for n in PartNotes.notes(d, kind, health, str(p.get("uid", d["id"]))):
		var warn := str(n).begins_with("!")
		detail_box.add_child(GUI.text(tr(str(n).trim_prefix("!")), 12, GUI.RED if warn else GUI.MUTED))
	var extra: Array = GameData.part_stat_text(d).split("  |  ")
	for k in range(1, extra.size()):
		var el := GUI.text(str(extra[k]), 12, GUI.CYAN)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(el)
	# compare with each slot it could go in
	var slots := slots_for(kind)
	var stats: Array = COMPARE_STATS.get(kind, [])
	if not slots.is_empty() and not stats.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2 + slots.size()
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 2)
		detail_box.add_child(grid)
		grid.add_child(GUI.text("", 11, GUI.MUTED))
		grid.add_child(GUI.text(tr("This"), 11, GUI.MUTED, "headb"))
		for sl in slots:
			var cur := GameData.equipped_inst(sl)
			var mark: bool = inv and cur.get("uid", -2) == p["uid"]
			grid.add_child(GUI.text((tr("vs %s") % tr(SHORT_SLOT.get(sl, "fitted"))) + (" ●" if mark else ""), 11, GUI.MUTED, "headb"))
		if not GameData.UNDAMAGEABLE.has(kind):
			# the health they have right now (a battered spare against a fresh one, and the other way round)
			grid.add_child(GUI.text(tr("HP now"), 12, GUI.MUTED))
			var hv: float = float(p["hp"]) if inv else float(d["hp"])
			grid.add_child(GUI.readout("%d" % ceili(hv), 17, GUI.TEXT))
			for sl in slots:
				var cur := GameData.equipped_inst(sl)
				var ch: float = 0.0 if cur.is_empty() else float(cur["hp"])
				var dh := hv - ch
				grid.add_child(GUI.readout("=" if absf(dh) < 0.5 else "%+d" % int(round(dh)), 17, GUI.MUTED if absf(dh) < 0.5 else (GUI.GREEN if dh > 0.0 else GUI.RED)))
		for st in stats:
			grid.add_child(GUI.text(tr(st[1]), 12, GUI.MUTED))
			var v := _stat_val(d, st[0])
			grid.add_child(GUI.readout("%d%s" % [int(v), st[2]], 17, GUI.TEXT))
			for sl in slots:
				var cur := GameData.equipped_inst(sl)
				var cd: Dictionary = {} if cur.is_empty() else GameData.part_def(cur["id"])
				var diff := v - _stat_val(cd, st[0])
				var good: bool = (diff < 0.0) if st[3] else (diff > 0.0)
				var txt := "=" if absf(diff) < 0.5 else "%+d" % int(diff)
				grid.add_child(GUI.readout(txt, 17, GUI.MUTED if absf(diff) < 0.5 else (GUI.GREEN if good else GUI.RED)))
	# what's in each slot now, so the columns mean something
	for sl in slots:
		var cur := GameData.equipped_inst(sl)
		var what := tr("empty") if cur.is_empty() else str(GameData.part_def(cur["id"])["name"])
		detail_box.add_child(GUI.text(tr("%s now: %s") % [tr(GameData.SLOT_NAMES[sl]), what], 11, GUI.MUTED))
	# big buttons
	var fitted_slot := ""
	if inv:
		for sl in GameData.SLOTS:
			if GameData.equipped.get(sl, -1) == p["uid"]:
				fitted_slot = sl
	var btns := detail_footer
	var add_btn := func(text: String, cb: Callable, enabled: bool, col: Color = GUI.TEXT) -> void:
		var b := UI.button(text, cb, 14, Vector2(0, 46))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not enabled
		b.add_theme_color_override("font_color", col)
		btns.add_child(b)
	if inv:
		var wreck := GameData.is_wreck(p)
		if fitted_slot != "":
			detail_box.add_child(GUI.text(tr("Fitted to the %s.") % tr(GameData.SLOT_NAMES[fitted_slot]), 12, GUI.GREEN))
		for sl in slots:
			if sl != fitted_slot:
				add_btn.call(tr("Fit: %s · %s") % [tr(GameData.SLOT_NAMES[sl]), GameData.hours_text(GameData.swap_hours(d))], _on_detail_fit.bind(int(p["uid"]), sl), not wreck, GUI.YELLOW)
		# off-label: when you're short of the right part, this one can stand in (with a price)
		var offs := off_slots(d)
		if not offs.is_empty():
			var ol := GUI.text(tr("OFF-LABEL") + ": " + GameData.off_label_text(d, offs[0]), 12, GUI.AMBER)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_box.add_child(ol)
			for sl in offs:
				if sl != fitted_slot:
					add_btn.call(tr("Off-label: %s · %s") % [tr(GameData.SLOT_NAMES[sl]), GameData.hours_text(GameData.swap_hours(d))], _on_detail_fit.bind(int(p["uid"]), sl), not wreck, GUI.AMBER)
		var c := GameData.repair_cost(p)
		if c > 0:
			add_btn.call((tr("Rebuild $%d · %s") if wreck else tr("Fix $%d · %s")) % [c, GameData.hours_text(GameData.repair_hours(p))], _on_repair.bind(int(p["uid"])), GameData.can_repair(c), GUI.AMBER)
		if fitted_slot == "":
			add_btn.call(tr("Sell $%d") % GameData.sell_value(p), _on_sell.bind(int(p["uid"])), true)
	else:
		var cost := int(d["cost"])
		for sl in slots:
			add_btn.call(tr("Buy & fit: %s · %s") % [tr(GameData.SLOT_NAMES[sl]), GameData.hours_text(GameData.swap_hours(d))], _on_buy_fit.bind(str(d["id"]), sl), GameData.money >= cost, GUI.YELLOW)
		add_btn.call(tr("Buy to storage $%d") % cost, _on_buy_keep.bind(str(d["id"])), GameData.money >= cost)
		# try before you buy: bolt it on for a practice round against Toaster Tim
		if not slots.is_empty() and kind in ["head", "torso", "arm", "leg", "back", "reactor"]:
			add_btn.call(tr("Test drive"), _on_test_drive.bind("toaster", str(d["id"]), best_slot(kind), "dealer"), GameData.can_fight(), GUI.CYAN)


## Above the calendar: tonight in one line (who, purse, odds) and the button to act on it.
func tonight_strip(mode: String) -> void:
	var bar := action_bar()
	var o := GameData.current_opponent()
	var text := ""
	if o.is_empty():
		text = tr("TONIGHT: nothing booked. Pickups at the Rusty Bolt if you want one.")
	else:
		text = tr("TONIGHT: %s · %s") % [GameData.fight_title(), str(o.get("name", "?"))] + "   " + tr("Purse $%d") % GameData.current_reward()
		var mb := my_fight_bet()
		if not mb.is_empty():
			text += "   " + tr("odds %.2fx") % float(mb["odds"])
	var l := GUI.text(text, 14, GUI.YELLOW, "headb")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(l)
	if o.is_empty():
		row_button(bar, tr("Find a fight ›"), go_to.bind("Pub", "bar"), true, 150)
	else:
		GUI.mark_new(row_button(bar, tr("Bell Check ›"), open_fight_popup, true, 150), true)


## Off to the scrapyard ring for a practice round (nothing that happens there sticks).
func _on_test_drive(junker_id: String, try_id: String, slot: String, from: String) -> void:
	GameData.flush_save()
	GameData.start_test_drive(junker_id, try_id, slot)
	GameData.test_drive["from"] = from
	Sfx.play("click")
	Loading.go("res://fight.tscn")


func _on_detail_fit(uid: int, slot: String) -> void:
	note(GameData.equip(uid, slot), "equip")
	detail = {}
	refresh()


## Buy a part and bolt it straight on.
func _on_buy_fit(id: String, slot: String) -> void:
	var before := GameData.money
	var text := GameData.buy(id)
	if GameData.money >= before and GameData.part_def(id)["cost"] > 0:
		note(text, "error")
		return
	var uid: int = GameData.next_uid - 1
	if GameData.equipped.get(slot, -1) != uid:
		GameData.equip(uid, slot)
	note(tr("Bought %s and fitted it to the %s.") % [GameData.part_def(id)["name"], tr(GameData.SLOT_NAMES[slot])], "buy")
	Sfx.play("equip", 0.1)
	spark_at = Time.get_ticks_msec() / 1000.0
	detail = {}
	refresh()


## Buy a part as a spare: it goes to Storage even if a slot is empty.
func _on_buy_keep(id: String) -> void:
	var before := GameData.money
	var text := GameData.buy(id)
	if GameData.money >= before and GameData.part_def(id)["cost"] > 0:
		note(text, "error")
		return
	var uid: int = GameData.next_uid - 1
	for sl in GameData.SLOTS:
		if GameData.equipped.get(sl, -1) == uid:
			GameData.unequip(sl)
	note(tr("Bought %s. It's in Storage.") % GameData.part_def(id)["name"], "buy")
	detail = {}
	refresh()


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
	var t := GameData.part_stat_text(d).replace("  |  ", "  ")
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


## A row of buttons that wraps onto a second line when it doesn't fit (big text, narrow screens).
func flow_bar(parent: Control = null) -> HFlowContainer:
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	bar.add_theme_constant_override("v_separation", 6)
	(parent if parent else list_box).add_child(bar)
	return bar


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
	ob.add_theme_font_size_override("font_size", UI.px(17))
	ob.get_popup().add_theme_font_size_override("font_size", UI.px(22))
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
	note(tr("Sold for $%d.") % total, "buy")
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
	key.add_theme_constant_override("separation", 6)
	list_box.add_child(key)
	# Repair all sits right by the damage it fixes, with its price and its hours
	var total := GameData.repair_all_cost()
	repair_all_btn = UI.button((tr("Repair all $%d · %s") % [total, GameData.hours_text(GameData.repair_all_hours())]) if total > 0
			else (tr("On the job board") if GameData.has_work("m") else tr("All repaired")), _on_repair_all, 14, Vector2(0, 38))
	repair_all_btn.disabled = total <= 0
	GUI.mark_new(repair_all_btn, total > 0 and GameData.can_repair(total))
	repair_all_btn.add_theme_color_override("font_color", GUI.AMBER)
	key.add_child(repair_all_btn)
	var kgap := Control.new()
	kgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.add_child(kgap)
	var blk := ColorRect.new()
	blk.color = GUI.GREEN
	blk.custom_minimum_size = Vector2(6, 11)
	blk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.add_child(blk)
	key.add_child(GUI.text(tr("= 25 HP"), 10, GUI.MUTED, "headb"))
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
		var off_note := GameData.off_label_text(d, slot)
		var row := make_tap_row(part_icon(d, GameData.hp_ratio(p)), d["name"], job_line("m", slot, p) + (part_info(d) if off_note == "" else "[color=#f2b84a]%s[/color]" % (tr("OFF-LABEL") + ": " + off_note)), _on_slot.bind(slot), slot_name)
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(p))
			var c := GameData.repair_cost(p)
			if c > 0:
				var fb := UI.button(tr("Fix $%d · %s") % [c, GameData.hours_text(GameData.repair_hours(p))], _on_repair.bind(p["uid"]), 13, Vector2(120, 36))
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


## What the bay is doing to a fitted part right now ("" if nothing).
func job_line(robot: String, slot: String, p: Dictionary) -> String:
	GameData.sync_swaps()
	var out := ""
	var sj := GameData.swap_job(robot, slot)
	if not sj.is_empty():
		out += tr("BOLTING ON %d%%, %s left. ") % [int(GameData.fit_progress(robot, slot) * 100), GameData.hours_text((float(sj["total"]) - float(sj["done"])) / (2.0 if sj["rush"] else 1.0))]
	var rj := GameData.repair_job(int(p["uid"]))
	if not rj.is_empty():
		out += tr("ON THE BENCH, %s left. ") % GameData.hours_text((float(rj["total"]) - float(rj["done"])) / (2.0 if rj["rush"] else 1.0))
	return out


## When each job on the board will be done, if nothing changes: "today, afternoon", "Tue morning"...
func job_etas() -> Array:
	var board: Array = GameData.jobs.duplicate(true)
	var out: Array = []
	for j in board:
		out.append("")
	var ph := GameData.phase
	var di := GameData.day_index()
	var night_ot := GameData.overtime
	for step in 40:
		var hrs := 0.0
		if ph < 2:
			hrs = GameData.SHIFT_HOURS
		elif night_ot:
			hrs = GameData.NIGHT_HOURS
		night_ot = night_ot and ph < 2
		if hrs > 0.0:
			# only unfinished jobs take hands
			var open: Array = board.filter(func(x): return float(x["done"]) < float(x["total"]) - 0.001)
			if open.is_empty():
				break
			GameData.work(hrs, false, open)
		ph += 1
		if ph > 2:
			ph = 0
			di = (di + 1) % 7
		for k in board.size():
			if out[k] == "" and float(board[k]["done"]) >= float(board[k]["total"]) - 0.001:
				var when := tr(["MORNING", "AFTERNOON", "EVENING"][ph]).to_lower()
				out[k] = (tr("today") if di == GameData.day_index() and step < 3 else tr(DAY_NAMES[di]).capitalize()) + " " + when
	return out


# ---------------------------------------------------------------- Gus's tour (new games)
# After the first fight Gus walks you round the bay one thing at a time, and a bouncing arrow
# points at what to tap. Each step ends when you've done it.

func tour_steps() -> Array:
	# short on purpose: one line per stop, and only the stops you can't find by yourself
	return [
		{"target": "repair", "text": tr("The robot's dented. Repair all puts the dents on the job board. Check the price, then tap it.")},
		{"target": "next", "text": tr("Time only moves when you press the big yellow button. The bay works on the jobs while it runs.")},
		{"target": "rail:Parts", "text": tr("Get Parts. The scrapyard's out back, one free dig a day.")},
		{"target": "dig", "text": tr("Tap Dig anywhere. Some days there's nothing, but it's free.")},
		{"target": "fight", "text": tr("Saturday is the Open Trials. Two wins put us in the Scrap League, two losses and we're out. Practise at the Rusty Bolt.")},
	]


func tour_done(i: int) -> bool:
	match i:
		0:
			return GameData.repair_all_cost() == 0 or GameData.has_work("m") or repair_tapped
		1:
			return tour_clock != "" and tour_clock != clock_key()
		2:
			return tab == "Parts"
		3:
			return GameData.digs_left <= 0 or tab != "Parts"
		4:
			return GameData.wins + GameData.losses > 1
	return true


func tour_target(i: int) -> Control:
	var t: String = tour_steps()[i]["target"]
	match t:
		"repair":
			return repair_all_btn if is_instance_valid(repair_all_btn) else null
		"next":
			return fight_button
		"fight":
			return fight_button
		"dig":
			return dig_button if is_instance_valid(dig_button) else null
	if t.begins_with("rail:") and rail_buttons.has(t.substr(5)) and is_instance_valid(rail_buttons[t.substr(5)]):
		return rail_buttons[t.substr(5)]
	return null


func update_tour() -> void:
	var i := GameData.tour
	if i < 0 or not GameData.story_seen.has("first_garage") or talk_story:
		if tour_arrow:
			tour_arrow.visible = false
		return
	while i < tour_steps().size() and tour_done(i) and i != tour_said:
		i += 1
	if i != GameData.tour:
		GameData.tour = i
		GameData.request_save()
	if i >= tour_steps().size():
		GameData.tour = -1
		if tour_arrow:
			tour_arrow.visible = false
		return
	if tour_said != i:
		tour_said = i
		tour_clock = clock_key()
		say(tour_steps()[i]["text"])
		return
	if tour_done(i):
		GameData.tour = i + 1
		GameData.request_save()
		return
	if tour_arrow == null:
		tour_arrow = GUI.TourArrow.new()
		tour_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tour_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tour_arrow)
	var target := tour_target(i)
	tour_arrow.visible = target != null and target.is_visible_in_tree() and overlay == null
	if tour_arrow.visible:
		tour_arrow.target = Rect2(target.global_position, target.size)
		move_child(tour_arrow, -1)
		tour_arrow.queue_redraw()


## BotMedia > DMs: everything anyone ever said to you, newest first (Gus, pilots, hate mail,
## sponsors, the story). Nothing that pops up in a bubble is lost.
func build_feed() -> void:
	var view := seg()
	GameData.inbox_seen = GameData.inbox.size()
	# Messages: one list, with a filter (who said it)
	var fbar := flow_bar()
	fbar.add_child(GUI.text(tr("Show:"), 14, GUI.MUTED))
	for f in [["all", tr("Everyone")], ["gus", tr("Gus")], ["pilots", tr("Pilots")], ["sponsors", tr("Sponsors")], ["story", tr("Story")]]:
		var fb := row_button(fbar, str(f[1]), _on_msg_filter.bind(str(f[0])), true, 0)
		fb.toggle_mode = true
		fb.button_pressed = msg_filter == str(f[0])
	view = msg_filter
	if view == "story":
		# the opening cutscene, any time you want to see it again
		var ob := action_bar()
		row_button(ob, tr("Watch the opening ▸"), _on_watch_opening, true, 0)
	var shown := 0
	var last_day := ""
	for i in range(GameData.inbox.size() - 1, -1, -1):
		var e: Dictionary = GameData.inbox[i]
		var who := str(e["who"])
		var kind := str(e.get("kind", "talk"))
		match view:
			"gus":
				if who != "GUS":
					continue
			"pilots":
				if who in ["GUS", "YOU", "NARRATOR", "ECHO"] or kind == "story" or kind.begins_with("sponsor:"):
					continue
			"sponsors":
				if not kind.begins_with("sponsor:"):
					continue
			"story":
				if kind != "story":
					continue
		var stamp := tr("%s · WEEK %d · YEAR %d") % [tr(DAY_FULL_UP[maxi(0, GameData.DAYS.find(str(e.get("d", "mon"))))]), int(e["w"]), int(e["y"])]
		if stamp != last_day:
			last_day = stamp
			var h := GUI.text(stamp, 12, GUI.MUTED, "headb")
			list_box.add_child(h)
		var face = StoryScript.Portrait.new()
		face.who = who
		face.face_look = e.get("look", {})
		face.robot_look = GameData.player_look()
		var shown_name := who
		if who == "YOU":
			shown_name = GameData.pilot_name.to_upper()
		elif who == "ECHO":
			shown_name = GameData.robot_name
		elif who == "NARRATOR":
			shown_name = tr("NARRATOR")
		if kind.begins_with("sponsor:"):
			face.queue_free()
			make_tap_row(Logos.LogoIcon.new(kind.substr(8), 52), shown_name, str(e["text"]), go_to.bind("Feed", "contracts"), tr("sponsor"))
		elif e.has("wid"):
			make_tap_row(face, shown_name, str(e["text"]), open_pilot.bind(int(e["wid"])))
		else:
			make_row(face, shown_name, str(e["text"]), null, {"story": tr("story"), "gus": "", "talk": ""}.get(kind, ""))
		shown += 1
		if shown >= 150:
			break
	if shown == 0:
		section(tr("Nothing here yet."))


var msg_filter := "all"


func _on_watch_opening() -> void:
	GameData.opening_replay = true
	GameData.save_game()
	Loading.go("res://opening.tscn")


func _on_msg_filter(f: String) -> void:
	msg_filter = f
	refresh()


# ---------------------------------------------------------------- BotMedia (Social / Contracts)

var feed_focus := ""     # Explore: a "#tag" or an account key being looked at ("" = the Explore page)
var feed_shown := 30     # how many posts the feed shows before "Show more"
var alerts_fresh := 0    # how many alerts were new when you opened Alerts


## A round avatar: a logo for companies and announcers, a face for pilots (and you), Gus as Gus,
## an initial on a colour for fans.
class Avatar extends Control:
	var key := ""
	var acc := {}

	func _init(k: String = "", a: Dictionary = {}) -> void:
		key = k
		acc = a
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		if acc.has("logo"):
			draw_circle(c, r, Color(0.94, 0.93, 0.9))
			load("res://logos.gd").draw_logo(self, str(acc["logo"]), c, r * 0.86)
			return
		draw_circle(c, r, Color(0.16, 0.17, 0.22))
		var PA = load("res://pilot_art.gd")
		if key == "me":
			PA.draw_head(self, c + Vector2(0, r * 0.18), r * 0.6, GameData.pilot_look, 1.0, 0.0)
		elif acc.has("wid"):
			PA.draw_head(self, c + Vector2(0, r * 0.18), r * 0.6, GameData.World.look_of(int(acc["wid"])), 1.0, 0.0)
		elif key == "gus":
			# grey stubble, cap, the face that's been under robots for forty years
			draw_circle(c, r, Color(0.32, 0.26, 0.2))
			draw_circle(c + Vector2(0, r * 0.12), r * 0.52, Color(0.86, 0.68, 0.52))
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.62), Vector2(r * 1.2, r * 0.36)), Color(0.85, 0.3, 0.2))
			draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.3), Vector2(r * 0.6, r * 0.2)), Color(0.7, 0.7, 0.72))
			draw_circle(c + Vector2(-r * 0.2, 0), r * 0.07, Color(0.1, 0.1, 0.1))
			draw_circle(c + Vector2(r * 0.2, 0), r * 0.07, Color(0.1, 0.1, 0.1))
		else:
			var h := absi(hash(key))
			draw_circle(c, r, Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.55))
			var f: Font = GUI.headb()
			var ch := str(acc.get("name", "?")).substr(0, 1).to_upper()
			var fsz := int(r * 1.1)
			draw_string(f, Vector2(0, c.y + fsz * 0.36), ch, HORIZONTAL_ALIGNMENT_CENTER, size.x, fsz, Color.WHITE)


## Small drawn icons (the fonts have no hearts): "like", "liked", "repost", "reply", "check".
class Glyph extends Control:
	var kind := "like"
	var col := Color.WHITE

	func _init(k: String = "like", c: Color = Color.WHITE, px: float = 16.0) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		match kind:
			"like", "liked":
				var pts := PackedVector2Array()
				for i in 33:
					var t := TAU * i / 32.0
					var x := 16.0 * pow(sin(t), 3)
					var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
					pts.append(o + Vector2(s * 0.5, s * 0.46) + Vector2(x, y) * s / 36.0)
				if kind == "liked":
					draw_colored_polygon(pts, col)
				else:
					draw_polyline(pts, col, 1.6, true)
			"repost":
				var a := o + Vector2(s * 0.15, s * 0.35)
				draw_polyline(PackedVector2Array([a + Vector2(0, s * 0.25), a, a + Vector2(s * 0.6, 0)]), col, 1.6)
				draw_colored_polygon(PackedVector2Array([a + Vector2(s * 0.6, -s * 0.14), a + Vector2(s * 0.75, 0), a + Vector2(s * 0.6, s * 0.14)]), col)
				var b := o + Vector2(s * 0.85, s * 0.65)
				draw_polyline(PackedVector2Array([b - Vector2(0, s * 0.25), b, b - Vector2(s * 0.6, 0)]), col, 1.6)
				draw_colored_polygon(PackedVector2Array([b - Vector2(s * 0.6, -s * 0.14), b - Vector2(s * 0.75, 0), b - Vector2(s * 0.6, s * 0.14)]), col)
			"reply":
				draw_rect(Rect2(o + Vector2(s * 0.12, s * 0.18), Vector2(s * 0.76, s * 0.5)), col, false, 1.6)
				draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.3, s * 0.68), o + Vector2(s * 0.5, s * 0.68), o + Vector2(s * 0.28, s * 0.88)]), col)
			"check":
				draw_circle(o + Vector2(s, s) * 0.5, s * 0.5, col)
				draw_polyline(PackedVector2Array([o + Vector2(s * 0.26, s * 0.52), o + Vector2(s * 0.44, s * 0.7), o + Vector2(s * 0.76, s * 0.32)]), Color(0.1, 0.1, 0.12), 2.0)


func avatar_for(key: String, px: float = 46.0) -> Control:
	var av := Avatar.new(key, GameData.Social.account(key))
	av.custom_minimum_size = Vector2(px, px)
	return av


## Look at an account (Explore shows its header and its posts).
func open_account(key: String) -> void:
	if key == "me":
		go_to("Feed", "profile")
		return
	feed_focus = key
	feed_shown = 30
	go_to("Feed", "explore")


func open_tag(tag: String) -> void:
	feed_focus = "#" + tag
	feed_shown = 30
	go_to("Feed", "explore")


## One post: avatar, name, handle and when, the text, its card, and like / repost / reply.
func post_row(p: Dictionary, parent: Control = null) -> void:
	var S = GameData.Social
	var by := str(p["by"])
	var acc: Dictionary = S.account(by)
	var panel := PanelContainer.new()
	var sb := GUI.box(GUI.ROW, 10, 8)
	if p.get("mention", false) and by != "me":
		sb.border_color = GUI.YELLOW.darkened(0.3)
		sb.border_width_left = 3
	panel.add_theme_stylebox_override("panel", sb)
	(parent if parent else list_box).add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var avb := Button.new()
	avb.flat = true
	avb.focus_mode = Control.FOCUS_NONE
	avb.custom_minimum_size = Vector2(48, 48)
	avb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var av := avatar_for(by, 46)
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	avb.add_child(av)
	avb.pressed.connect(open_account.bind(by))
	row.add_child(avb)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var nm := GUI.text(str(acc["name"]), 14, GUI.YELLOW if by == "me" else GUI.TEXT, "headb")
	head.add_child(nm)
	if acc.get("verified", false):
		var g := Glyph.new("check", GUI.CYAN, 14)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(g)
	var hl := GUI.text("@%s · %s" % [acc["handle"], S.when_text(p)], 11, GUI.MUTED)
	hl.clip_text = true
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hl)
	var tx := GUI.text(S.text_of(p), 14, GUI.TEXT)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tx)
	var tags: Array = p.get("tags", [])
	if not tags.is_empty():
		var tb := HFlowContainer.new()
		tb.add_theme_constant_override("h_separation", 8)
		col.add_child(tb)
		for t in tags:
			if str(t) == "":
				continue
			var b := Button.new()
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.text = "#" + str(t)
			b.add_theme_font_size_override("font_size", UI.tsz(12))
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(c, GUI.CYAN)
			b.pressed.connect(open_tag.bind(str(t)))
			tb.add_child(b)
	post_card(p.get("card", {}), col)
	# like, repost, reply
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 16)
	col.add_child(acts)
	var id := int(p["id"])
	var lb := Button.new()
	lb.flat = true
	lb.focus_mode = Control.FOCUS_NONE
	var liked: bool = S.st()["liked"].has(str(id))
	var lh := HBoxContainer.new()
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lh.add_theme_constant_override("separation", 4)
	lb.add_child(lh)
	var lg := Glyph.new("liked" if liked else "like", GUI.RED if liked else GUI.MUTED, 20)
	lh.add_child(lg)
	var lc := GUI.text(S.fol_text(S.grown(p, "likes")), 13, GUI.RED if liked else GUI.MUTED)
	lh.add_child(lc)
	lb.custom_minimum_size = Vector2(84, 40)   # a finger-sized target
	lh.position = Vector2(4, 10)
	lb.pressed.connect(func():
		S.toggle_like(id)
		var on: bool = S.st()["liked"].has(str(id))
		lg.kind = "liked" if on else "like"
		lg.col = GUI.RED if on else GUI.MUTED
		lg.queue_redraw()
		lc.text = S.fol_text(S.grown(p, "likes"))
		lc.add_theme_color_override("font_color", GUI.RED if on else GUI.MUTED)
		Sfx.play("click", 0.05))
	acts.add_child(lb)
	for f in [["repost", "reposts"], ["reply", "replies"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.add_child(Glyph.new(f[0], GUI.MUTED, 20))
		h.add_child(GUI.text(S.fol_text(S.grown(p, f[1])), 13, GUI.MUTED))
		acts.add_child(h)
	if p.get("mention", false) and by != "me" and not p.get("replied", false) and not acc.has("logo"):
		var rb := UI.button(tr("Reply"), open_reply.bind(id), 12, Vector2(80, 28))
		acts.add_child(rb)


## The picture under a post: a result, a podium, a Read change, a sponsor's logo.
func post_card(card: Dictionary, parent: Control) -> void:
	if card.is_empty():
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GUI.box(GUI.BG, 8, 8))
	parent.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	match str(card.get("kind", "")):
		"result":
			h.add_child(GUI.text(tr("WIN"), 13, GUI.GREEN, "headb"))
			h.add_child(GUI.text(str(card.get("a", "?")), 14, GUI.TEXT, "headb"))
			h.add_child(GUI.text(tr("beat"), 12, GUI.MUTED))
			h.add_child(GUI.text(str(card.get("b", "?")), 14, GUI.TEXT, "headb"))
		"podium":
			var names: Array = card.get("names", [])
			var cols := [Color(1.0, 0.84, 0.3), Color(0.8, 0.82, 0.86), Color(0.85, 0.55, 0.3)]
			for i in mini(3, names.size()):
				h.add_child(GUI.text("%d. %s" % [i + 1, names[i]], 13, cols[i], "headb"))
		"read":
			h.add_child(GUI.text(tr("READ"), 12, GUI.MUTED, "headb"))
			h.add_child(GUI.readout(GameData.aim_dots(int(card.get("dots", 1))), 18, GUI.GREEN))
		"rattled":
			h.add_child(GUI.text(tr("RATTLED"), 14, GUI.RED, "headb"))
		"logo":
			h.add_child(Logos.LogoIcon.new(str(card.get("logo", "")), 36))
			h.add_child(GUI.text(str(GameData.Contracts.sp(str(card.get("logo", ""))).get("name", "")), 14, GUI.TEXT, "headb"))
		"ad":
			h.add_child(Logos.LogoIcon.new("kane", 36))
			h.add_child(GUI.text(tr("SPONSORED"), 11, GUI.MUTED, "headb"))
		_:
			panel.queue_free()


func feed_list(kind: String) -> void:
	var posts: Array = GameData.Social.feed(kind, feed_shown + 1)
	if posts.is_empty():
		section(tr("Nothing here yet."))
		return
	for i in mini(posts.size(), feed_shown):
		post_row(posts[i])
	if posts.size() > feed_shown:
		var bar := action_bar()
		row_button(bar, tr("Show more"), func(): feed_shown += 30; refresh(), true, 160)


## Home: your post waiting after a fight (three drafts), then everyone you follow.
func build_home() -> void:
	var S = GameData.Social
	var drafts: Array = S.drafts()
	if not drafts.is_empty():
		var panel := PanelContainer.new()
		var sb := GUI.box(GUI.ROW.lightened(0.04), 10, 10)
		sb.border_color = GUI.YELLOW
		sb.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", sb)
		list_box.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		col.add_child(top)
		top.add_child(avatar_for("me", 40))
		var t := GUI.text(tr("POST ABOUT TONIGHT? Pick one."), 15, GUI.YELLOW, "headb")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		var opp := str(S.st()["draft"].get("opp", ""))
		var hints := {"humble": tr("Safe. Sponsors like it."), "hype": tr("Big if you keep winning."), "trash": tr("Fans love it. They won't.")}
		var names := {"humble": tr("HUMBLE"), "hype": tr("HYPE"), "trash": tr("TRASH TALK")}
		var no_trash: bool = GameData.Contracts.st()["active"].any(func(c): return c["reqs"].any(func(r): return r["kind"] == "no_trash"))
		for d in drafts:
			var tone := str(d[0])
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 58)
			for k in ["normal", "hover", "pressed", "hover_pressed"]:
				var st := GUI.box(GUI.BG if k == "normal" else GUI.BG.lightened(0.08), 8, 6)
				b.add_theme_stylebox_override(k, st)
			b.pressed.connect(_on_publish.bind(tone))
			col.add_child(b)
			var v := VBoxContainer.new()
			v.set_anchors_preset(Control.PRESET_FULL_RECT)
			v.offset_left = 10
			v.offset_right = -10
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 0)
			b.add_child(v)
			var warn := tone == "trash" and no_trash
			v.add_child(GUI.text(str(names[tone]) + "  ·  " + (tr("Breaks your Harbour Mutual deal!") if warn else str(hints[tone])), 11, GUI.RED if warn or tone == "trash" else GUI.MUTED, "headb"))
			var dt := GUI.text(tr(str(d[1])) % opp, 13, GUI.TEXT)
			dt.clip_text = true
			v.add_child(dt)
		var bar := action_bar(col)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(sp)
		var skip := UI.button(tr("Say nothing"), _on_skip_post, 12, Vector2(130, 32))
		bar.add_child(skip)
	feed_list("home")


func _on_publish(tone: String) -> void:
	var before: int = GameData.Social.followers()
	GameData.Social.publish(tone)
	var d: int = GameData.Social.followers() - before
	note(tr("Posted. Followers %s%d.") % ["+" if d >= 0 else "", d], "equip")
	feed_shown = 30
	GameData.save_game()
	refresh()


func _on_skip_post() -> void:
	GameData.Social.st()["draft"] = {}
	refresh()


## Explore: trending tags, who to follow, everything; or one tag / one account.
func build_explore() -> void:
	var S = GameData.Social
	if feed_focus != "":
		var bar := action_bar()
		row_button(bar, tr("‹ Explore"), func(): feed_focus = ""; feed_shown = 30; refresh(), true, 130)
		if feed_focus.begins_with("#"):
			var tl := GUI.text(feed_focus, 18, GUI.CYAN, "headb")
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.add_child(tl)
		else:
			account_header(feed_focus)
		feed_list(feed_focus)
		return
	section(tr("TRENDING IN PORT FERRUM"))
	var fb := flow_bar()
	for t in S.trending(8):
		var b := UI.button("#" + str(t), open_tag.bind(str(t)), 13, Vector2(0, 36))
		fb.add_child(b)
	var sugg: Array = S.suggestions(5)
	if not sugg.is_empty():
		section(tr("WHO TO FOLLOW"))
		for k in sugg:
			var acc: Dictionary = S.account(k)
			var row := make_tap_row(avatar_for(k), str(acc["name"]), "@%s · %s" % [acc["handle"], tr("%s followers") % S.fol_text(int(acc["fol"]))], open_account.bind(k))
			row_button(row, tr("Follow"), _on_follow.bind(k, true), true, 110)
	section(tr("EVERYTHING ON BOTMEDIA"))
	feed_list("all")


## An account's header in Explore: avatar, name, handle, followers, Follow, and the pilot card.
func account_header(key: String) -> void:
	var S = GameData.Social
	var acc: Dictionary = S.account(key)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GUI.box(GUI.ROW, 10, 10))
	list_box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(avatar_for(key, 72))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(GUI.text(str(acc["name"]), 18, GUI.TEXT, "headb"))
	col.add_child(GUI.text("@" + str(acc["handle"]), 12, GUI.MUTED))
	col.add_child(GUI.readout(tr("%s FOLLOWERS") % S.fol_text(int(acc["fol"])), 20, GUI.GREEN))
	if acc.has("wid"):
		var line := tr("Read %s") % GameData.aim_dots(GameData.World.read_dots(float(acc["read"])))
		if acc.get("rattled", false):
			line += "  " + tr("RATTLED")
		col.add_child(GUI.text(line, 13, GUI.RED if acc.get("rattled", false) else GUI.TEXT))
	var bx := VBoxContainer.new()
	bx.add_theme_constant_override("separation", 6)
	row.add_child(bx)
	var on: bool = S.follows(key)
	bx.add_child(UI.button(tr("Following") if on else tr("Follow"), _on_follow.bind(key, not on), 13, Vector2(120, 38)))
	if acc.has("wid"):
		bx.add_child(UI.button(tr("Pilot card"), open_pilot.bind(int(acc["wid"])), 13, Vector2(120, 38)))
	if key.begins_with("sp:"):
		bx.add_child(UI.button(tr("Contracts"), go_to.bind("Feed", "contracts"), 13, Vector2(120, 38)))


func _on_follow(key: String, on: bool) -> void:
	GameData.Social.follow(key, on)
	Sfx.play("click", 0.05)
	refresh()


## Alerts: mentions, follower jumps, offers, rule warnings. Opening it clears the count.
func build_alerts() -> void:
	var S = GameData.Social
	if GameData.alerts_unseen > 0:
		alerts_fresh = GameData.alerts_unseen   # stays marked while you look (refreshes don't clear it)
		GameData.alerts_unseen = 0
	var fresh := alerts_fresh
	var offers: Array = GameData.Contracts.st()["offers"]
	if not offers.is_empty():
		var row := make_tap_row(Logos.LogoIcon.new(str(offers[0]["sp"]), 52), tr("Sponsor offers waiting: %d") % offers.size(), tr("Read them before they run out."), go_to.bind("Feed", "contracts"))
		GUI.mark_new(row.get_parent(), true)
	var notes: Array = S.st()["notes"]
	if notes.is_empty():
		section(tr("No alerts yet. Win a fight and Port Ferrum will notice."))
		return
	var n := 0
	for i in range(notes.size() - 1, -1, -1):
		var e: Dictionary = notes[i]
		var pid := int(e.get("post", -1))
		var txt: String = S.note_text(e)
		var sub := S.when_text({"at": e.get("at", 0), "w": e.get("w", 1)})
		var icon: Control
		if str(e.get("icon", "")) != "":
			icon = Logos.LogoIcon.new(str(e["icon"]), 52)
		elif pid >= 0:
			icon = avatar_for(str(S.find_post(pid).get("by", "botmedia")))
		else:
			icon = Glyph.new("like", GUI.YELLOW, 40)
		var row: Container
		if pid >= 0 and not S.find_post(pid).is_empty():
			row = make_tap_row(icon, txt, sub, open_post.bind(pid))
		else:
			row = make_row(icon, txt, sub)
		if n < fresh:
			GUI.mark_new(row.get_parent(), true)
		n += 1
		if n >= 60:
			break


## One post on its own (from an alert): the post, and a reply if it named you.
func open_post(id: int) -> void:
	var p: Dictionary = GameData.Social.find_post(id)
	if p.is_empty():
		return
	var col := open_popup(tr("POST"))
	post_row(p, col)
	popup_footer.add_child(UI.button(tr("Close"), close_popup, 16, Vector2(0, 46)))


## Reply to a post that names you: friendly, cool or cutting.
func open_reply(id: int) -> void:
	var S = GameData.Social
	var p: Dictionary = S.find_post(id)
	if p.is_empty():
		return
	var acc: Dictionary = S.account(str(p["by"]))
	var col := open_popup(tr("REPLY TO @%s") % acc["handle"])
	post_row(p, col)
	var hints := {"friendly": tr("Cools a grudge."), "cool": tr("Says nothing, looks calm."), "cutting": tr("Fans love it. So do grudges.")}
	for r in S.reply_options():
		var b := UI.button((tr(str(r[1])) % ("@" + str(acc["handle"]))) + "\n" + str(hints[r[0]]), _on_reply.bind(id, str(r[0])), 13, Vector2(0, 58))
		col.add_child(b)
	popup_footer.add_child(UI.button(tr("Back"), close_popup, 16, Vector2(0, 46)))


func _on_reply(id: int, tone: String) -> void:
	GameData.Social.reply(id, tone)
	close_popup()
	note(tr("Replied."), "equip")
	GameData.save_game()
	refresh()


## Your profile, on top of Posts / Looks / Gear / Contracts.
func profile_bar() -> void:
	var S = GameData.Social
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GUI.box(GUI.ROW, 10, 10))
	list_box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(avatar_for("me", 64))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(GUI.text(GameData.pilot_name, 18, GUI.YELLOW, "headb"))
	col.add_child(GUI.text("@%s · %s" % [S.account("me")["handle"], tr("Record %d-%d") % [GameData.wins, GameData.losses]], 12, GUI.MUTED))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	right.add_child(GUI.readout(S.fol_text(S.followers()), 28, GUI.GREEN))
	right.add_child(GUI.text(tr("FOLLOWERS"), 10, GUI.MUTED, "headb"))
	var bar := flow_bar()
	var subs := [["profile", tr("Posts")], ["looks", tr("Looks")]]
	if GameData.unlocked("pilot"):
		subs.append(["gear", tr("Gear")])
	var nc: int = GameData.Contracts.st()["offers"].size()
	subs.append(["contracts", tr("Contracts %d") % nc if nc > 0 else tr("Contracts")])
	for sb in subs:
		var b := UI.button(str(sb[1]), go_to.bind("Feed", str(sb[0])), 13, Vector2(110, 36))
		var st := GUI.seg_style(seg() == sb[0])
		for k in ["normal", "disabled"]:
			b.add_theme_stylebox_override(k, st[0])
		for k in ["hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, st[1])
		GUI.mark_new(b, (sb[0] == "gear" and seg_new("gear", "pilot")) or (sb[0] == "contracts" and contracts_new()))
		bar.add_child(b)


func build_my_posts() -> void:
	var S = GameData.Social
	section(tr("Posts this week: %d. Your posts go out after fights: win, lose, the fans want to hear it.") % S.posts_this_week())
	feed_list("me")


## Offers waiting that you haven't opened yet.
func contracts_new() -> bool:
	return GameData.Contracts.st()["offers"].any(func(o): return not o.get("seen", false))


# ---------------------------------------------------------------- contracts

func build_contracts() -> void:
	var C = GameData.Contracts
	var s: Dictionary = C.st()
	section(tr("SPONSORS pay to put their name on your robot: one title sponsor (their paint, their logo on the chest) and up to two stickers. Break their rules and you get a warning, then a fine, then the deal is off."))
	if s["active"].is_empty():
		section(tr("No sponsors yet."))
	else:
		var tl := GUI.readout(tr("SPONSORS PAY $%d A MONTH") % C.monthly_total(), 20, GUI.GREEN)
		list_box.add_child(tl)
	for c in s["active"]:
		var d: Dictionary = C.sp(str(c["sp"]))
		var role := tr("TITLE SPONSOR") if c["role"] == "title" else tr("PARTNER")
		var sub := tr("$%d a month · $%d a win · %d weeks left · sticker %s") % [int(c["fee"]), int(c["win"]), int(c["weeks"]), C.slot_text(str(c["slot"]))]
		make_row(Logos.LogoIcon.new(str(c["sp"]), 52), str(d["name"]), sub, null, role)
		for r in c["reqs"]:
			var ok := req_ok(r)
			var rh := HBoxContainer.new()
			rh.add_theme_constant_override("separation", 8)
			list_box.add_child(rh)
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(16, 0)
			rh.add_child(pad)
			var gl := Glyph.new("check", GUI.GREEN if ok else GUI.AMBER.darkened(0.4), 16)
			gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rh.add_child(gl)
			var l := GUI.text(C.req_text(r), 13, GUI.TEXT if ok else GUI.AMBER)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rh.add_child(l)
		var strikes := int(c.get("strikes", 0))
		if strikes > 0:
			list_box.add_child(GUI.text("    " + (tr("WARNED once.") if strikes == 1 else tr("FINED. One more and it's over.")), 13, GUI.RED, "headb"))
	section(tr("OFFERS"))
	if s["offers"].is_empty():
		section(tr("No offers right now. Win fights and grow your followers: sponsors are watching. Offers come on Mondays."))
	for o in s["offers"]:
		var d2: Dictionary = C.sp(str(o["sp"]))
		var role2 := tr("TITLE") if o["role"] == "title" else tr("PARTNER")
		var row := make_tap_row(Logos.LogoIcon.new(str(o["sp"]), 52), str(d2["name"]),
				tr("$%d a month · $%d to sign · %d weeks") % [int(o["fee"]), int(o["sign"]), int(o["weeks"])] + ("  ·  " + tr("sleeping on it") if o.get("sleeping", false) else ""),
				open_offer.bind(int(o["id"])), role2)
		GUI.mark_new(row.get_parent(), not o.get("seen", false))
		row_button(row, tr("Open"), open_offer.bind(int(o["id"])), true, 90)


## Is a rule being kept right now? (for the tick in the list)
func req_ok(r: Dictionary) -> bool:
	match str(r["kind"]):
		"paint":
			return GameData.paint == int(r["paint"])
		"controller":
			return str(GameData.pilot_look.get("controller", "")) == str(r["id"])
		"posts":
			return GameData.Social.posts_this_week() >= int(r["n"])
		"followers":
			return GameData.Social.followers() >= int(r["n"])
		"dealer":
			return int(GameData.Contracts.st()["dealer_buys"]) >= int(r["n"])
		"repaired":
			return GameData.robot_hp_ratio() * 100.0 >= float(r["pct"])
		"wins":
			return int(r.get("played", 0)) - int(r.get("won", 0)) <= int(r["m"]) - int(r["n"])
	return true


var offer_ask_open := false


## An offer up close: the money, the rules, what Gus thinks, how they seem; and the haggling.
func open_offer(id: int) -> void:
	var C = GameData.Contracts
	var i: int = C.find_offer(id)
	if i < 0:
		close_popup()
		refresh()
		return
	var o: Dictionary = C.st()["offers"][i]
	o["seen"] = true
	var d: Dictionary = C.sp(str(o["sp"]))
	var col := open_popup(str(d["name"]).to_upper())
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	top.add_child(Logos.LogoIcon.new(str(o["sp"]), 84))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(GUI.text(tr("TITLE SPONSOR: their paint, their logo on the chest.") if o["role"] == "title" else tr("PARTNER: a sticker %s.") % C.slot_text(str(o["slot"])), 14, GUI.YELLOW, "headb"))
	var tagline := GUI.text("@%s · %s" % [d["handle"], tr("%s followers") % GameData.Social.fol_text(int(d["fol"]))], 12, GUI.MUTED)
	tv.add_child(tagline)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	col.add_child(grid)
	for t in [[tr("Signing bonus"), "$%d" % int(o["sign"])], [tr("Every month"), "$%d" % int(o["fee"])], [tr("Every win"), "$%d" % int(o["win"])],
			[tr("Every part you tear off"), "$%d" % int(o["rip"])], [tr("A medal"), tr("$%d (gold)") % int(o["podium"])], [tr("Term"), tr("%d weeks") % int(o["weeks"])]]:
		grid.add_child(GUI.text(t[0], 14, GUI.MUTED))
		grid.add_child(GUI.readout(t[1], 20, GUI.GREEN))
	col.add_child(GUI.text(tr("THE RULES"), 14, GUI.YELLOW, "headb"))
	for r in o["reqs"]:
		var l := GUI.text("· " + C.req_text(r), 14, GUI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var gus := GUI.text(tr("GUS: %s") % C.gus_line(o), 14, GUI.AMBER)
	gus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(gus)
	col.add_child(GUI.text(C.mood_text(o), 13, GUI.MUTED))
	if str(o.get("reply", "")) != "":
		var rl := GUI.text("\"%s\"" % o["reply"], 15, GUI.CYAN, "headb")
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(rl)
	# haggling
	var fb := flow_bar(col)
	if offer_ask_open:
		for a in [["fee", tr("More a month")], ["sign", tr("Bigger signing bonus")], ["term", tr("Shorter term")], ["drop", tr("Drop a rule")]]:
			fb.add_child(UI.button(str(a[1]), _on_offer_ask.bind(id, str(a[0])), 13, Vector2(0, 40)))
		fb.add_child(UI.button(tr("Cancel"), func(): offer_ask_open = false; open_offer(id), 13, Vector2(0, 40)))
	else:
		fb.add_child(UI.button(tr("Ask for more ▾"), func(): offer_ask_open = true; open_offer(id), 13, Vector2(0, 40)))
		var mb := UI.button(tr("Mention another offer"), _on_offer_mention.bind(id), 13, Vector2(0, 40))
		mb.disabled = o.get("played", false)
		fb.add_child(mb)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	popup_footer.add_child(foot)
	for b in [[tr("Refuse"), _on_offer_refuse.bind(id)], [tr("Sleep on it"), _on_offer_sleep.bind(id)], [tr("Back"), func(): offer_ask_open = false; close_popup(); refresh()]]:
		var bb := UI.button(str(b[0]), b[1], 14, Vector2(0, 46))
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(bb)
	var sg := UI.button(tr("SIGN"), _on_offer_sign.bind(id), 16, Vector2(0, 46))
	sg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["normal", "hover", "pressed", "hover_pressed"]:
		sg.add_theme_stylebox_override(k, GUI.box(GUI.YELLOW if k == "normal" else GUI.YELLOW.lightened(0.15), 8, 6))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		sg.add_theme_color_override(k, Color(0.08, 0.08, 0.1))
	foot.add_child(sg)


func _on_offer_ask(id: int, what: String) -> void:
	offer_ask_open = false
	var said: String = GameData.Contracts.ask(id, what)
	Sfx.play("click", 0.05)
	if GameData.Contracts.find_offer(id) < 0:
		close_popup()
		note(said)
		refresh()
		return
	open_offer(id)


func _on_offer_mention(id: int) -> void:
	var said: String = GameData.Contracts.mention(id)
	if GameData.Contracts.find_offer(id) < 0:
		close_popup()
		note(said)
		refresh()
		return
	open_offer(id)


func _on_offer_sleep(id: int) -> void:
	GameData.Contracts.sleep_on(id)
	close_popup()
	note(tr("You'll sleep on it. Your next fight will move their number, one way or the other."))
	refresh()


func _on_offer_refuse(id: int) -> void:
	confirm(tr("REFUSE?"), tr("They won't ask again for a while."), tr("Refuse"), func():
		GameData.Contracts.refuse(id)
		GameData.save_game()
		refresh(), tr("Keep it"))


func _on_offer_sign(id: int) -> void:
	var C = GameData.Contracts
	var i: int = C.find_offer(id)
	if i < 0:
		return
	var o: Dictionary = C.st()["offers"][i]
	var paint_line := ""
	for r in o["reqs"]:
		if r["kind"] == "paint" and GameData.paint != int(r["paint"]):
			paint_line = " " + tr("The crew repaints the robot %s.") % tr(str(GameData.PAINTS[int(r["paint"])]["name"]))
	confirm(tr("SIGN WITH %s?") % str(C.sp(str(o["sp"]))["name"]).to_upper(), tr("You get $%d now and $%d every month for %d weeks.") % [int(o["sign"]), int(o["fee"]), int(o["weeks"])] + paint_line,
			tr("Sign"), func():
		var said: String = C.sign(id)
		offer_ask_open = false
		note(said, "buy")
		GameData.save_game()
		refresh(), tr("Not yet"))


## Bay > Job board: everything being fixed or bolted on, in order, with the hands that work it.
func build_jobs_view() -> void:
	GameData.sync_swaps()
	var hands := GameData.hands()
	section(tr("THE JOB BOARD. Repairs and new parts take hours, and whatever isn't done by the bell goes in as it is. Gus works one job at a time, each mechanic one more."))
	# rows wrap onto a second line on narrow screens / big text (a wide row pushed the whole layout off screen)
	var hl := GUI.text(tr("HANDS: %d (Gus + %d mechanic%s)") % [hands, GameData.mechanics, "" if GameData.mechanics == 1 else "s"], 15, GUI.YELLOW, "headb")
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(hl)
	var bar := flow_bar()
	row_button(bar, tr("Hire $%d/mo") % GameData.mechanic_wage(), _on_hire_mechanic, GameData.mechanics < GameData.max_mechanics(), 150)
	row_button(bar, tr("Let one go"), _on_fire_mechanic, GameData.mechanics > 0, 130)
	var ot := GUI.text(tr("Tonight the crew stays on: 8 more hours.") if GameData.overtime else tr("Overtime: work through tonight, 8 more hours for every pair of hands."), 13, GUI.MUTED)
	ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(ot)
	var bar2 := flow_bar()
	row_button(bar2, tr("Overtime $%d") % GameData.overtime_cost() if not GameData.overtime else tr("Booked"), _on_overtime, not GameData.overtime and GameData.money >= GameData.overtime_cost(), 150)
	# the bay itself: passive repair, and the upgrades that speed it up (each one puts the rent up)
	var bl := GUI.text(tr("THE BAY: %s. Parts on your robots heal %d%% a day on their own.") % [tr(GameData.BAY_NAMES[GameData.bay_level]), int(round(GameData.passive_rate() * 100.0))], 15, GUI.YELLOW, "headb")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(bl)
	var lv := GUI.BlockBar.new()   # 1 block = 1% a day
	lv.block_w = 22.0
	lv.setup(GameData.passive_rate() * 100.0, 1.0, (GameData.PASSIVE_BASE + GameData.PASSIVE_STEP * GameData.BAY_LEVELS) * 100.0, GUI.GREEN)
	list_box.add_child(lv)
	if GameData.bay_level < GameData.BAY_LEVELS:
		var up_l := GUI.text(tr("Next: %s. %d%% a day, rent +$%d a month.") % [tr(GameData.BAY_NAMES[GameData.bay_level + 1]), int(round((GameData.passive_rate() + GameData.PASSIVE_STEP) * 100.0)), GameData.bay_rent()], 13, GUI.MUTED)
		up_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(up_l)
		var bar3 := flow_bar()
		row_button(bar3, tr("Install $%d") % GameData.bay_price(), _on_bay_upgrade, GameData.money >= GameData.bay_price(), 150)
	if GameData.jobs.is_empty():
		section(tr("Nothing on the board. Everything's fixed and bolted on."))
		return
	var etas := job_etas()
	for i in GameData.jobs.size():
		var j: Dictionary = GameData.jobs[i]
		var p := GameData.inst(int(j["uid"]))
		if p.is_empty():
			continue
		var d := GameData.part_def(p["id"])
		var title := ""
		if j["kind"] == "repair":
			title = tr("Fix: %s") % d["name"]
		else:
			var who: String = GameData.robot_name if j["robot"] == "m" else GameData.wingman_name(int(str(j["robot"]).substr(1)))
			title = tr("Bolt on: %s (%s, %s)") % [d["name"], tr(GameData.SLOT_NAMES[j["slot"]]), who]
		var left := (float(j["total"]) - float(j["done"])) / (2.0 if j["rush"] else 1.0)
		var sub := tr("%s left of %s") % [GameData.hours_text(left), GameData.hours_text(float(j["total"]))]
		if etas[i] != "":
			sub += "  ·  " + tr("done %s") % etas[i]
		if i < hands:
			sub += "  ·  " + tr("being worked on")
		if j["rush"]:
			sub += "  ·  " + tr("RUSH")
		make_tap_row(part_icon(d, GameData.hp_ratio(p)), title, sub, _on_detail.bind({"src": "inv", "uid": int(j["uid"])}), tr("#%d") % (i + 1))
		# second line: the hours as blocks, then the buttons (wraps when it doesn't fit)
		var line := flow_bar()
		var bb := GUI.BlockBar.new()   # 1 block = 1 hour of work
		bb.block_w = 14.0
		bb.setup(float(j["done"]), 1.0, maxf(1.0, ceilf(float(j["total"]))), GUI.CYAN if j["kind"] == "swap" else GUI.GREEN)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bb)
		var rc := GameData.rush_cost(j)
		row_button(line, tr("Rush $%d") % rc if not j["rush"] else tr("Rushed"), _on_rush.bind(i), not j["rush"] and GameData.money >= rc, 110)
		row_button(line, tr("Up"), _on_job_up.bind(i), i > 0, 60)
		if j["kind"] == "repair":
			row_button(line, tr("Cancel +$%d") % GameData.job_refund(j), _on_cancel_job.bind(i), true, 120)


func _on_bay_upgrade() -> void:
	confirm(tr(GameData.BAY_NAMES[GameData.bay_level + 1]).to_upper(), tr("Install the %s for $%d? Parts heal faster, and the rent goes up $%d a month for good.") % [tr(GameData.BAY_NAMES[GameData.bay_level + 1]), GameData.bay_price(), GameData.bay_rent()], tr("Install"), func():
		note(GameData.buy_bay_upgrade(), "buy")
		GameData.save_game()
		refresh())


func _on_cancel_job(i: int) -> void:
	note(GameData.cancel_job(i), "sell")
	GameData.save_game()
	refresh()


func _on_hire_mechanic() -> void:
	note(GameData.hire_mechanic(), "buy")
	GameData.save_game()
	refresh()


func _on_fire_mechanic() -> void:
	note(GameData.fire_mechanic(), "click")
	GameData.save_game()
	refresh()


func _on_overtime() -> void:
	note(GameData.buy_overtime(), "buy")
	GameData.save_game()
	refresh()


func _on_rush(i: int) -> void:
	note(GameData.rush_job(i), "repair")
	GameData.save_game()
	refresh()


func _on_job_up(i: int) -> void:
	GameData.job_up(i)
	refresh()


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
		var off_t := GameData.off_label_text(d, slot)
		var row := make_row(part_icon(d, GameData.hp_ratio(p)), d["name"], part_info(d) if off_t == "" else "[color=#f2b84a]%s[/color]" % (tr("OFF-LABEL") + ": " + off_t))
		var c := GameData.repair_cost(p)
		if c > 0:
			row_button(row, tr("Fix $%d · %s") % [c, GameData.hours_text(GameData.repair_hours(p))], _on_repair.bind(p["uid"]), GameData.can_repair(c), 130).add_theme_color_override("font_color", GUI.AMBER)
		if slot != "reactor":
			row_button(row, "Remove", _on_unequip_ask.bind(slot), true, 95)
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			var hw := hp_widget(p)
			row.add_child(hw)
			row.move_child(hw, 2)

	var options: Array = []
	var wrecks: Array = []
	for sp in GameData.spares():
		if GameData.part_def(sp["id"])["kind"] == kind:
			(wrecks if GameData.is_wreck(sp) else options).append(sp)
	section("Swap in from storage:" if not options.is_empty() else tr("No spare %s in storage.") % tr(str(GameData.KIND_NAMES[kind])).to_lower())
	for sp in options:
		var d := GameData.part_def(sp["id"])
		var row := make_tap_row(part_icon(d, GameData.hp_ratio(sp)), d["name"] + ("" if d["shop"] else tr("  (rare)")), delta_text(d, slot),
				_on_detail.bind({"src": "inv", "uid": sp["uid"]}), "", is_detail("inv", sp["uid"]))
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(sp))
		row_button(row, tr("Fit · %s") % GameData.hours_text(GameData.swap_hours(d)), _on_equip.bind(sp["uid"], slot), true, 110)
	for sp in wrecks:
		var d := GameData.part_def(sp["id"])
		var c := GameData.repair_cost(sp)
		var row := make_tap_row(part_icon(d, 0.0), d["name"] + tr("  (WRECKED)"), tr("Rebuild it to use it again."),
				_on_detail.bind({"src": "inv", "uid": sp["uid"]}), "", is_detail("inv", sp["uid"]))
		row_button(row, tr("Rebuild $%d · %s") % [c, GameData.hours_text(GameData.repair_hours(sp))], _on_repair.bind(sp["uid"]), GameData.can_repair(c), 160).add_theme_color_override("font_color", GUI.AMBER)
	# off-label: other kinds of part that can stand in here (a leg for an arm, a reactor on the shoulder...)
	var offs: Array = []
	for sp in GameData.spares():
		var od := GameData.part_def(sp["id"])
		if od["kind"] != kind and GameData.fits(od, slot) and not GameData.is_wreck(sp):
			offs.append(sp)
	if not offs.is_empty():
		section(tr("Off-label, for when you're short:"))
		for sp in offs:
			var d := GameData.part_def(sp["id"])
			var row := make_tap_row(part_icon(d, GameData.hp_ratio(sp)), d["name"], "[color=#f2b84a]" + GameData.off_label_text(d, slot) + "[/color]",
					_on_detail.bind({"src": "inv", "uid": sp["uid"]}), tr(str(d["kind"]).to_upper()), is_detail("inv", sp["uid"]))
			row_button(row, tr("Fit · %s") % GameData.hours_text(GameData.swap_hours(d)), _on_equip.bind(sp["uid"], slot), true, 110)
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
			var row := make_tap_row(part_icon(d), d["name"], delta_text(d, slot), _on_detail.bind({"src": "shop", "id": id}), "", is_detail("shop", id))
			row_button(row, tr("Buy & fit $%d · %s") % [d["cost"], GameData.hours_text(GameData.swap_hours(d))], _on_buy_fit.bind(id, slot), GameData.money >= d["cost"], 180)
	var more := flow_bar()
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
		var picked: bool = sell_picks.has(p["uid"])
		var cb_tap: Callable = _on_pick_sell.bind(not picked, p["uid"]) if selling else _on_detail.bind({"src": "inv", "uid": p["uid"]})
		var row := make_tap_row(part_icon(d, GameData.hp_ratio(p)), str(d["name"]) + tag, part_info(d), cb_tap, tr(str(d["kind"]).to_upper()),
				is_detail("inv", p["uid"]) or (selling and picked))
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			row.add_child(hp_widget(p))
		if selling:
			var cb := CheckBox.new()
			cb.button_pressed = picked
			cb.focus_mode = Control.FOCUS_NONE
			cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cb.text = tr("$%d") % GameData.sell_value(p)
			row.add_child(cb)


# ---------------------------------------------------------------- popups (setups, paint)

func open_popup(title: String) -> VBoxContainer:
	close_popup()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	if bubble:
		move_child(bubble, -1)   # people keep talking over windows
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
	# title and Close on top, the contents in a scroll box, and a footer pinned at the bottom for
	# the buttons that matter (FIGHT): a long window never pushes them off the screen
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := GUI.text(tr(title), 22, GUI.YELLOW, "headb")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.button("Close", close_popup, 16, Vector2(90, 44)))
	outer.add_child(GUI.HazardStrip.new())
	popup_scroll = ScrollContainer.new()
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer.add_child(popup_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(560, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_scroll.add_child(col)
	popup_footer = VBoxContainer.new()
	popup_footer.add_theme_constant_override("separation", 6)
	outer.add_child(popup_footer)
	_fit_popup.call_deferred()
	return col


## Sizes the pop-up's scroll box to its contents, but never taller than the screen allows.
func _fit_popup() -> void:
	if popup_scroll == null or not is_instance_valid(popup_scroll) or popup_scroll.get_child_count() == 0:
		return
	var col: Control = popup_scroll.get_child(0)
	popup_scroll.custom_minimum_size.x = col.get_combined_minimum_size().x
	var room := get_viewport_rect().size.y - 150.0 - popup_footer.get_combined_minimum_size().y
	popup_scroll.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, maxf(120.0, room))


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
			"spark": now - spark_at, "dig": now - dig_at, "found": dig_found, "bet": now - bet_at, "juke": Sfx.jukebox_index() >= 0,
			"medals": GameData.trophies, "wall": GameData.wall_trophies(), "gus_point": dad_talk and talk_story, "backup": backup, "stats": GameData.career_stats,
			"wins": GameData.wins, "losses": GameData.losses, "champion": GameData.champion,
			"patron": patron_info() if scene == "pub" else {}, "tv": tv_info() if scene == "pub" else {},
			"controllers": GameData.owned_controllers, "using": str(GameData.pilot_look.get("controller", "gamepad"))}


## The pilots in the pub today: the first sits at the bar, the rest stand around.
func patron_info() -> Dictionary:
	var all := GameData.patrons_today()
	if all.is_empty():
		return {}
	var crowd: Array = []
	for p in all.slice(1):
		crowd.append({"look": GameData.World.look_of(int(p["wid"])), "name": str(p["name"]), "hungover": p.get("hungover", false)})
	return {"look": GameData.World.look_of(int(all[0]["wid"])), "name": str(all[0]["name"]), "crowd": crowd,
			"hungover": all[0].get("hungover", false)}


## What's on the pub TV: tonight's headline league fight, or the table on quiet nights.
func tv_info() -> Dictionary:
	var hm := GameData.headline_match()
	if not hm.is_empty():
		var ev: Dictionary = hm["ev"]
		return {"live": true, "title": tr(Career.STAGES[ev["stage"]]["short"]) + " · " + tr(Career.round_name(ev)),
				"a": str(Career.pilot(ev, int(hm["a"])).get("pilot", "?")), "b": str(Career.pilot(ev, int(hm["b"])).get("pilot", "?"))}
	var champ: Dictionary = GameData.leagues.get("steel", {})
	if champ.is_empty():
		return {}
	var order := Career.standings(champ)
	var lead := Career.pilot(champ, int(order[0]))
	return {"live": false, "title": tr("STEEL LEAGUE TABLE"), "a": "1. %s  %d" % [str(lead.get("pilot", "?")), int(champ["table"][str(order[0])][2])], "b": ""}


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


## Crew > Controllers: the pads and gadgets your pilot fights with.
func build_pilot_view() -> void:
	build_controllers()


## BotMedia > Profile: your pilot's looks. The close-up behind the menu is the mirror.
func build_pilot_looks() -> void:
	var col := list_box
	section("Your profile. This is the face Port Ferrum sees: in your corner during fights, in the story, and on BotMedia.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
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
		["Body", "female", tr("Woman") if look.get("female", false) else tr("Man"), ""],
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


func _on_pilot_change(what: String, step: int) -> void:
	var look: Dictionary = GameData.pilot_look
	match what:
		"female":
			look["female"] = not look.get("female", false)
			if look["female"]:
				look["beard"] = "none"
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
	close_popup()
	note(GameData.buy_controller(id), "buy")
	refresh()


## A controller up close: what it is, what it does to the robot in a fight, and swap to it.
func open_controller(id: String) -> void:
	var cinfo: Dictionary = GameData.CONTROLLER_INFO[id]
	var col := open_popup(tr(PilotArt.CONTROLLER_NAMES[id]).to_upper())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var icon := ControllerIcon.new()
	icon.kind = id
	icon.custom_minimum_size = Vector2(220, 150)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var d := GUI.text(tr(cinfo["desc"]), 16, GUI.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(320, 0)
	info.add_child(d)
	var names := {"combo": tr("Combo window +%.2fs"), "seq": tr("Special-move inputs +%.1fs"), "atk_speed": tr("Attack speed +%d%%"),
			"gadget_cd": tr("Gadget recharge -%d%%"), "move": tr("Walking speed +%d%%"), "block": tr("Blocked hits -%d%% damage"),
			"jump": tr("Jump height +%d%%"), "aim": tr("Aimed hits +%d%% more often"), "damage": tr("Damage +%d%%")}
	for k in cinfo["mods"]:
		var v: float = float(cinfo["mods"][k])
		var txt: String = names.get(k, k)
		if k == "gadget_cd" or k == "block":
			v = (1.0 - v) * 100.0
		elif k in ["atk_speed", "move", "jump", "damage"]:
			v *= 100.0
		info.add_child(GUI.text("• " + (txt % v if txt.contains("%.") else txt % int(round(v))), 15, GUI.GREEN))
	if cinfo["mods"].is_empty():
		info.add_child(GUI.text(tr("No tricks. It just works."), 15, GUI.MUTED))
	var using: bool = GameData.pilot_look.get("controller", "gamepad") == id
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	var act: Button
	if using:
		act = UI.button(tr("In your hands"), close_popup, 16, Vector2(0, 50))
		act.disabled = true
	elif GameData.owned_controllers.has(id):
		act = UI.button(tr("Swap to it"), _on_controller.bind(id), 16, Vector2(0, 50))
	else:
		act = UI.button(tr("Buy $%d") % int(cinfo["cost"]), _on_controller.bind(id), 16, Vector2(0, 50))
		act.disabled = GameData.money < int(cinfo["cost"])
	act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(act)


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
			scene = {"cups": "cups"}.get(seg(), "office")
		"Pub":
			scene = "pub"
		"Feed":
			scene = "phone"
		"Crew":
			scene = "team"
	stats_panel.visible = STATS_SCENES.has(scene)
	preview.spot = GarageArt.robot_spot(scene)
	preview.facing = 1 if scene == "paint" else -1
	preview.front = scene == "build"   # in the bay the robot hangs on Gus's gantry, facing you
	preview.light = "bay" if scene in ["build", "moves", "storage", "workshop", "team"] else "neutral"   # Gus's building: the work lamp
	preview.hide_robot = scene in ["pub", "office", "phone"]  # the robot stays in the bay when you're at the pub or in the office
	preview.queue_redraw()
	if scene == "pub" and not talk_story:
		var hello := GameData.pub_greeting()
		if not hello.is_empty():
			# wait a frame: the bar draws first, so the patron's head is known for the bubble
			(func(): play_story([{"lines": hello}])).call_deferred()
	# the first time in the office, Gus shows you your dad's trophies
	dad_talk = dad_talk and scene == "office"
	if scene == "office" and GameData.story_seen.has("first_garage") and not GameData.story_seen.has("dad_trophies"):
		dad_talk = true
		# the left pane steps aside so the shelves are in view while he talks
		(func():
			play_story(["dad_trophies"])
			detail_panel.visible = false).call_deferred()


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
		section(tr("Any training chip, made to order, at double the dealer's price."))
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
	row_button(bar, tr("Restock $%d") % GameData.reroll_cost(), _on_reroll, GameData.money >= GameData.reroll_cost(), 140)
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
		var row := make_tap_row(part_icon(d), d["name"], part_info(d), _on_detail.bind({"src": "shop", "id": id}), tr(str(d["kind"]).to_upper()), is_detail("shop", id))
		var hb := GUI.SegBar.new()
		if not GameData.UNDAMAGEABLE.has(d["kind"]):
			hb.setup(float(d["hp"]), float(d["hp"]), GUI.GREEN)
			hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(hb)
		var target := best_slot(str(d["kind"]))
		if target != "":
			row_button(row, tr("Buy & fit $%d · %s") % [d["cost"], GameData.hours_text(GameData.swap_hours(d))], _on_buy_fit.bind(id, target), GameData.money >= d["cost"], 180)
		else:
			row_button(row, tr("Buy $%d") % d["cost"], _on_buy.bind(id), GameData.money >= d["cost"], 150)
	if (f == "all" or f == "chip") and not chips.is_empty():
		section("TRAINING CHIPS: each one teaches your robot a special move.")
		for id in chips.duplicate():
			chip_row(id, false)


## Pilot gear: controllers change how your robots fight. Bought and picked in Crew > Pilot.
func build_controllers() -> void:
	section("PILOT GEAR: controllers change how your robots fight.")
	for id in PilotArt.CONTROLLERS:
		var cinfo: Dictionary = GameData.CONTROLLER_INFO[id]
		var icon := ControllerIcon.new()
		icon.kind = id
		var row := make_tap_row(icon, tr(PilotArt.CONTROLLER_NAMES[id]), tr(cinfo["desc"]), open_controller.bind(id), tr("in use") if GameData.pilot_look.get("controller", "gamepad") == id else (tr("yours") if GameData.owned_controllers.has(id) else ""))
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
	var info := GUI.text(tr("One dig a day, and nothing is guaranteed. Every day you stay away, the odds of finding something go up. Digging for one kind of part, or for extras (reactors, controllers), halves them."), 12, GUI.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var luck := VBoxContainer.new()
	luck.add_child(GUI.text(tr("FIND CHANCE"), 12, GUI.MUTED, "headb"))
	luck.add_child(GUI.readout("%d%%" % roundi(GameData.dig_luck * 100.0), 26, GUI.GREEN if GameData.dig_luck > 0.0 else GUI.MUTED))
	var lb := GUI.BlockBar.new()   # 1 block = one day left alone
	lb.setup(GameData.dig_luck * 100.0, GameData.DIG_LUCK_STEP * 100.0, GameData.DIG_LUCK_MAX * 100.0, GUI.GREEN)
	luck.add_child(lb)
	luck.add_child(GUI.text(tr("rare %.1f%%") % (GameData.dig_luck * GameData.DIG_RARE_SHARE * 100.0), 12, GUI.MUTED))
	bar.add_child(luck)
	if GameData.digs_left <= 0:
		row_button(bar, tr("Dug today. Back tomorrow"), _on_dig.bind(""), false, 270)
	else:
		dig_button = row_button(bar, tr("Dig anywhere"), _on_dig.bind(""), true, 150)
		GUI.mark_new(dig_button, true)   # today's dig is waiting
		var kinds := flow_bar()
		kinds.add_child(UI.label(tr("Dig for:"), 16, Color(1.0, 0.8, 0.4)))
		for k in ["head", "torso", "arm", "leg", "extras"]:
			var b := row_button(kinds, tr({"head": "Head", "torso": "Torso", "arm": "Arm", "leg": "Leg", "extras": "Extras"}[k]), _on_dig.bind(k), true, 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if k == "extras":
				b.tooltip_text = tr("Reactors and controllers. Often nothing.")
	# Test Drive: Gus's silly practice robots, behind the pile
	section(tr("TEST DRIVE: Gus pilots his Junkers so you can practise. No damage, no prize, nothing saved."))
	for jid in GameData.JUNKERS:
		var j: Dictionary = GameData.JUNKERS[jid]
		var row := make_row(bot_preview(GameData.junker(jid)), tr(j["name"]), tr(j["desc"]))
		row_button(row, "Test drive", _on_test_drive.bind(jid, "", "", "scrap"), GameData.can_fight(), 130)
	# what the pile has given you so far (spare parts that still need fixing)
	var finds: Array = GameData.spares().filter(func(p): return p.get("dug", false))
	if not finds.is_empty():
		section("Fresh from the pile. Keep it in Storage or sell it (damaged parts sell cheaper).")
		for p in finds:
			var d := GameData.part_def(p["id"])
			var row := make_tap_row(part_icon(d, GameData.hp_ratio(p)), d["name"], part_info(d), _on_detail.bind({"src": "inv", "uid": p["uid"]}),
					tr(str(d["kind"]).to_upper()), is_detail("inv", p["uid"]))
			row.add_child(hp_widget(p))
			row_button(row, "To Storage", _on_keep_find.bind(p["uid"]), true, 120)


## Keep a scrapyard find: it leaves the pile list and waits in Storage like any other part.
func _on_keep_find(uid: int) -> void:
	var p := GameData.inst(uid)
	if p.is_empty():
		return
	p.erase("dug")
	note(tr("%s is in Storage.") % GameData.part_def(p["id"])["name"], "equip")
	GameData.save_game()
	refresh()


func _on_emergency_junk(slot: String) -> void:
	var uid := GameData.add_part(GameData.STARTER[slot], 0.4)
	GameData.equip(uid, slot)
	note(tr("Gus digs a rusty %s out from under the bench. \"It'll hold. Probably.\"") % GameData.part_def(GameData.STARTER[slot])["name"], "equip")
	refresh()


func _on_dig(kind: String = "") -> void:
	var res := GameData.dig_scrap(kind)
	dig_at = Time.get_ticks_msec() / 1000.0
	dig_found = tr("Found something!") if res["part"] != "" else ""
	note(res["text"], "buy" if res.has("chip") or res.has("controller") else ("break" if res["part"] != "" else "land"))
	GameData.log_day(str(res["text"]), "good" if str(res.get("grade", "")) in ["rare", "good", "chip"] else "info")
	GameData.save_game()
	refresh()
	if res.has("uid"):
		show_find(int(res["uid"]), str(res["grade"]))


## The part you just dug up, right there in your hands: what it is, how beaten up, what next.
func show_find(uid: int, grade: String) -> void:
	var p := GameData.inst(uid)
	if p.is_empty():
		return
	var d := GameData.part_def(p["id"])
	var title: String = {"rare": tr("A RARE FIND!"), "good": tr("JACKPOT!"), "decent": tr("FOUND SOMETHING")}.get(grade, tr("MORE JUNK"))
	var col := open_popup(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var icon := part_icon(d, GameData.hp_ratio(p))
	icon.custom_minimum_size = Vector2(150, 150)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(GUI.text(str(d["name"]), 22, GUI.YELLOW, "headb"))
	var kind_line := GUI.text(tr(GameData.KIND_NAMES.get(d["kind"], "")).to_upper() + "  ·  " + (tr("%s grade") % GameData.grade_name(int(d.get("grade", 0))) if int(d.get("grade", 0)) > 0 else tr("junk")), 13, GUI.MUTED, "headb")
	info.add_child(kind_line)
	var st := GUI.text(GameData.part_stat_text(d, float(p["hp"])), 14, GUI.TEXT)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(st)
	if not GameData.UNDAMAGEABLE.has(d["kind"]):
		var hp := GUI.SegBar.new()
		hp.setup(float(p["hp"]), float(d["hp"]), GUI.GREEN if GameData.hp_ratio(p) > 0.5 else GUI.AMBER)
		info.add_child(hp)
		info.add_child(GUI.text(tr("%d%% health. Fixing it costs $%d.") % [int(GameData.hp_ratio(p) * 100), GameData.repair_cost(p)], 13, GUI.MUTED))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	var look := UI.button(tr("Take a closer look"), func(): plan_after_find = false; close_popup(); _on_detail({"src": "inv", "uid": uid}), 16, Vector2(0, 50))
	look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(look)
	var keep := UI.button(tr("Into storage"), func():
		close_popup()
		_on_keep_find(uid)
		if plan_after_find:
			plan_after_find = false
			open_day_plan(), 16, Vector2(0, 50))
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(keep)


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
	var kinds := flow_bar()
	for k in GameData.CUSTOM_KINDS:
		var b := row_button(kinds, str(k).capitalize(), _on_ws_kind.bind(k), true, 0)
		b.toggle_mode = true
		b.button_pressed = k == ws["kind"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section("Shape")
	var grid := flow_bar()
	for sh in GameData.custom_shapes(ws["kind"]):
		var b := UI.button(str(sh).capitalize(), _on_ws_set.bind("shape", sh), 13, Vector2(100, 40))
		b.toggle_mode = true
		b.button_pressed = sh == ws["shape"]
		grid.add_child(b)

	section("Colour")
	var colors := flow_bar()
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
	var sizes := flow_bar()
	for opt in [[0.85, "Small"], [1.0, "Normal"], [1.15, "Large"]]:
		var b := row_button(sizes, opt[1], _on_ws_set.bind("size", opt[0]), true, 0)
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(ws["size"], opt[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grades := flow_bar()
	for g in GameData.CUSTOM_GRADES.size():
		var gr: Dictionary = GameData.CUSTOM_GRADES[g]
		var b := row_button(grades, tr("%s (%d pts)") % [tr(gr["name"]), gr["points"]], _on_ws_grade.bind(g), true, 0)
		b.toggle_mode = true
		b.button_pressed = g == ws["grade"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section(tr("Stats: %d point%s left") % [left, "" if left == 1 else "s"])
	for stat in GameData.CUSTOM_KINDS[ws["kind"]]["stats"]:
		var n: int = ws["alloc"].get(stat, 0)
		var row := action_bar()
		var l := UI.label(STAT_NAMES[stat], 16)
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		row_button(row, "-", _on_ws_stat.bind(stat, -1), n > 0, 54)
		var bar := GUI.BlockBar.new()
		bar.block_w = 22.0
		bar.height = 18.0
		bar.setup(float(n), 1.0, float(GameData.CUSTOM_MAX_PER_STAT), Color(0.4, 0.8, 1.0))   # 1 block = 1 point
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row_button(row, "+", _on_ws_stat.bind(stat, 1), left > 0 and n < GameData.CUSTOM_MAX_PER_STAT, 54)

	section(tr("Gadget (+$%d)") % int(GameData.CUSTOM_GADGET_PRICE * pow(GameData.GRADE_PRICE, GameData.my_grade() - 1)))
	var gad := flow_bar()
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
	section(tr("Chips teach special moves. Slots used: %d/%d, better heads hold more. In the inputs, → means toward the enemy, ← away.")
			% [GameData.active_chips().size(), GameData.chip_slots()])
	var chip_ids: Array = GameData.owned_chips.duplicate()
	if chip_ids.is_empty():
		section(tr("No chips yet. The dealer, Made to order and the scrapyard all have them."))
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
		var l := UI.label(tr("%s %s · %s · gold $%d") % [c["name"], "★".repeat(int(c["tier"])), tr(Career.round_name(c)), int(c["prize"])], 16, Color(1.0, 0.8, 0.4))
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
		section(tr("Cups: 8 pilots, a three-week knockout on Wednesday nights. Your Saturday league fights carry on as normal. Gold, silver and bronze go on the trophy wall in the office.") + " " + (tr("Enter tonight and your first round is tonight.") if GameData.day == "wed" else tr("Your first round is next Wednesday.")))
	if GameData.circuit_offers.is_empty():
		GameData.make_offers()
	for k in GameData.circuit_offers.size():
		var off: Dictionary = GameData.circuit_offers[k]
		var preview_cup := Career.new_cup(off["name"], int(off["tier"]), int(off["seed"]), GameData.week, GameData.year, int(off["prize"]))
		var row := make_row(bot_preview(Career.robot_of(preview_cup, 1 + int(off["seed"]) % 7)), tr("%s  %s") % [off["name"], "★".repeat(int(off["tier"]))],
				tr("8 pilots, 3 weeks. Gold $%d + a new part, silver $%d, bronze $%d.") % [int(off["prize"]), int(off["prize"] * 0.5), int(off["prize"] * 0.3)])
		row_button(row, "Enter", _on_enter_cup.bind(k), fits, 100)
	if GameData.champion:
		var row := make_row(bot_preview(GameData.rival(GameData.OPPONENTS.size() - 1)), "OVERLORD rematch",
				tr("Exhibition bout in the Grand Hall for $%d. Any free night.") % GameData.EXHIBITION_REWARD)
		row_button(row, "Book it", _on_rematch, free and not GameData.exhibition, 100)


# ---------------------------------------------------------------- season

var season_view := "calendar"   # Season tab: "calendar" (main) or "table" (league table / bracket)
var cal_month := -1              # month shown on the calendar (0-12); -1 = this month
var cal_seen_month := -1         # the month it was when the page was last turned to "now"

const MONTH_NAMES := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
		"OCTOBER", "NOVEMBER", "DECEMBER", "YEAR'S END"]
const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const DAY_FULL_UP := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
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
		"jukebox":
			build_jukebox()
		"cups":
			build_cups_tab()
		_:
			build_league_view()


## A wall calendar: 4-week months, cups on Wednesday nights, everything else on Saturday nights,
## new stock and fresh scrapyard junk every Sunday, rent on the last Sunday.
## Only what you're actually in shows up - leagues you haven't qualified for aren't there.
func build_calendar() -> void:
	var cur_month := (GameData.week - 1) / GameData.MONTH_WEEKS
	if cal_month < 0 or cur_month != cal_seen_month:
		# a new month turns the page by itself
		cal_month = cur_month
		cal_seen_month = cur_month
	var mode := GameData.fight_mode()
	tonight_strip(mode)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list_box.add_child(head)
	head.add_child(UI.button("<", _on_cal_month.bind(-1), 18, Vector2(56, 36)))
	var t := UI.label(tr("%s  ·  YEAR %d") % [tr(MONTH_NAMES[cal_month]), GameData.year], 19, Color(1.0, 0.8, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.button(">", _on_cal_month.bind(1), 18, Vector2(56, 36)))
	# a month page with every day the same size: symbols say what's on, tap a day to see it
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 3)
	list_box.add_child(hdr)
	for k in 7:
		var dn: String = DAY_NAMES[k]
		var l := GUI.text(tr(dn), 11, GUI.YELLOW if k == 5 else (Color(0.78, 0.6, 1.0) if k == 2 else GUI.MUTED), "headb")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		hdr.add_child(l)
	for row in GameData.MONTH_WEEKS:
		var w: int = cal_month * GameData.MONTH_WEEKS + row + 1
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		list_box.add_child(line)
		for day in 7:
			line.add_child(cal_cell(w, row, day))
	# the key to the symbols
	var key := HFlowContainer.new()
	key.add_theme_constant_override("h_separation", 12)
	list_box.add_child(key)
	for k in [["open", "Open Trials"], ["scrap", "Scrap League"], ["rust", "Rust League"], ["iron", "Iron League"], ["steel", "Steel League"], ["title", "Championship"], ["cup", "Cup"],
			["pickup", "Pickup booked"], ["rent", "Rent"], ["stock", "New stock"]]:
		var it := HBoxContainer.new()
		it.add_theme_constant_override("separation", 4)
		it.add_child(GUI.EventIcon.new(k[0], 18.0))
		it.add_child(GUI.text(tr(k[1]), 12, GUI.MUTED))
		key.add_child(it)
	var info := tr("Record %d-%d.  Medals %d.") % [GameData.wins, GameData.losses, GameData.trophies.size()]
	section(info)
	section(tr("Tap a day to see what's on, or to go straight to it. Time moves with the big yellow button."))


## One calendar day, all the same size: the date, a symbol for each thing on, W / L after your fight.
class CalDay extends Button:
	var date := 1
	var icons: Array = []      # [kind, playoff ring]
	var result := ""           # "W" / "L"
	var tonight := false
	var this_week := false
	var past := false
	var fight_night := ""      # "wed" / "sat" / ""

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 62)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var GUI = load("res://garage_ui.gd")
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color(0.12, 0.12, 0.15, 0.92)
		if fight_night == "sat":
			bg = Color(0.19, 0.11, 0.08, 0.95)
		elif fight_night == "wed":
			bg = Color(0.15, 0.12, 0.2, 0.95)
		if this_week:
			bg = bg.lightened(0.06)
		if is_hovered():
			bg = bg.lightened(0.08)
		var a := 0.5 if past else 1.0
		var sb: StyleBoxFlat = GUI.box(Color(bg, bg.a * a), 6, 0)
		draw_style_box(sb, r)
		draw_string(GUI.num(), Vector2(6, 16), str(date), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(16), Color(GUI.MUTED, a))
		if result != "":
			var rc: Color = GUI.GREEN if result == "W" else GUI.RED
			var badge := Rect2(size.x - 22, 4, 18, 16)
			draw_rect(badge, Color(rc, 0.25 * a))
			draw_string(GUI.headb(), Vector2(badge.position.x, badge.position.y + 13), result, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, UI.px(12), Color(rc, a))
		var n := icons.size()
		if n > 0:
			var rad := minf(13.0, minf(size.x / (n * 2.6 + 0.4), size.y * 0.24))
			var gap := rad * 2.6
			var x0 := size.x * 0.5 - gap * (n - 1) * 0.5
			for k in n:
				GUI.draw_event_icon(self, str(icons[k][0]), Vector2(x0 + gap * k, size.y * 0.6), rad, bool(icons[k][1]))
		if tonight:
			draw_string(GUI.headb(), Vector2(0, size.y - 4), tr("TONIGHT"), HORIZONTAL_ALIGNMENT_CENTER, size.x, UI.px(9), GUI.YELLOW)
		if past:
			# crossed off with a red marker, like the calendar on Gus's wall
			var red := Color(0.85, 0.16, 0.12, 0.75)
			var m := Vector2(minf(size.x, size.y) * 0.18, minf(size.x, size.y) * 0.16)
			draw_line(Vector2(m.x, m.y + 2), Vector2(size.x - m.x, size.y - m.y), red, 3.0, true)
			draw_line(Vector2(size.x - m.x - 2, m.y), Vector2(m.x + 2, size.y - m.y - 1), red, 3.0, true)


func cal_cell(w: int, row: int, day: int) -> Button:
	var c := CalDay.new()
	c.date = row * 7 + day + 1
	c.this_week = w == GameData.week
	c.past = w < GameData.week or (c.this_week and day < GameData.day_index())
	c.fight_night = "sat" if day == 5 else ("wed" if day == 2 else "")
	for e in day_events(w, day):
		if str(e.get("icon", "")) != "" and e.get("cell", true):
			c.icons.append([e["icon"], bool(e.get("playoff", false))])
		if e.has("won"):
			c.result = "W" if e["won"] else "L"
		if e.get("tonight", false):
			c.tonight = true
	if c.this_week and day == GameData.day_index():
		c.tonight = true
	GUI.mark_new(c, c.tonight)   # today: the marching stripes, "you are here"
	c.pressed.connect(_on_cal_day.bind(w, day))
	return c


## What's on a calendar day: [{icon, playoff, title, text, tonight, won, matches: [{ev, a, b, bet}]}]
## Your fights (past, tonight and coming), pickup nights, the rent, the Sunday restock, and on past
## Saturdays what happened around Port Ferrum.
func day_events(w: int, day: int) -> Array:
	var out: Array = []
	var y := GameData.year
	var this_week := w == GameData.week
	var mode := GameData.fight_mode()
	if day <= 6:
		var d: String = GameData.DAYS[day]
		var plan := GameData.week_plan(y, w, d)
		var kind := str(plan["kind"])
		var stage := str(plan.get("stage", ""))
		var tonight: bool = this_week and GameData.day == d and kind != "done"
		match kind:
			"done":
				out.append({"icon": stage, "title": str(plan.get("title", "")), "text": str(plan["text"]), "won": bool(plan["won"])})
			"cup":
				var e := {"icon": "cup", "playoff": true, "title": tr(str(GameData.circuit["name"])).to_upper(), "tonight": tonight,
						"text": tr(Career.round_name(GameData.circuit)) if tonight else tr("Cup night"), "matches": []}
				if tonight and mode == "circuit":
					for pr in Career.round_matches(GameData.circuit):
						e["matches"].append({"ev": GameData.circuit, "a": int(pr[0]), "b": int(pr[1]), "bet": true, "on": "cup"})
				out.append(e)
			"league", "playoff":
				var e := {"icon": stage, "playoff": kind == "playoff", "tonight": tonight, "matches": [],
						"title": tr(Career.STAGES[stage]["name"]).to_upper() if Career.STAGES.has(stage) else "",
						"text": tr(str(plan["text"])).replace("\n", "  ")}
				if tonight and mode == "story":
					e["text"] = GameData.fight_title()
					var ev0: Dictionary = GameData.event
					var card := Career.round_matches(ev0)
					var mine0: Array = card.slice(0, 1)
					var rest: Array = card.slice(1)
					rest.sort_custom(func(p1, p2): return int(ev0["table"][str(p1[0])][2]) + int(ev0["table"][str(p1[1])][2]) > int(ev0["table"][str(p2[0])][2]) + int(ev0["table"][str(p2[1])][2]))
					for pr in mine0 + rest.slice(0, 4):
						e["matches"].append({"ev": ev0, "a": int(pr[0]), "b": int(pr[1]), "bet": true, "on": "event"})
				elif plan.has("round") and not GameData.leagues.get(GameData.rank, {}).is_empty():
					var my_ev: Dictionary = GameData.leagues[GameData.rank]
					var opp := int(my_ev["schedule"][int(plan["round"])])
					e["matches"].append({"ev": my_ev, "a": 0, "b": opp, "bet": false})
				out.append(e)
			"open":
				# pickups are impromptu (whoever's at the bar): only one you've booked gets a mark
				if tonight and mode == "pickup":
					var e := {"icon": "pickup", "tonight": tonight, "title": tr("PICKUP FIGHT"),
							"text": tr("Booked at the Rusty Bolt."), "matches": [{"pickup": true, "a": 0, "b": -1, "bet": true}]}
					out.append(e)
		if day == 5 and y == GameData.year:
			# the other divisions fight the same Saturdays: the top of their card
			for dstage in Career.EVENTS:
				var ev: Dictionary = GameData.leagues.get(dstage, {})
				if ev.is_empty() or Career.has_player(ev) or not ev["weeks"].has(w) or ev.get("phase", "") == "done":
					continue
				var r: int = ev["weeks"].find(w)
				var cur_r: int = int(ev["po_round"]) if ev.get("phase", "") == "finals" else int(ev["round"])
				var label := tr("League round %d/%d") % [r + 1, ev["weeks"].size()] if ev.get("phase", "") == "league" else tr("Round %d") % (r + 1)
				var ent := {"icon": dstage, "cell": dstage == "title" or dstage == "steel", "title": tr(str(ev["name"])).to_upper(), "matches": [], "text": label}
				if r < cur_r:
					ent["text"] += "  ·  " + tr("played")
				elif this_week and GameData.day_index() <= 5 and r == cur_r:
					ent["tonight"] = this_week and GameData.day == "sat"
					var pairs := Career.round_matches(ev)
					pairs.sort_custom(func(p1, p2): return int(ev["table"][str(p1[0])][2]) + int(ev["table"][str(p1[1])][2]) > int(ev["table"][str(p2[0])][2]) + int(ev["table"][str(p2[1])][2]))
					for pr in pairs.slice(0, 3):
						ent["matches"].append({"ev": ev, "a": int(pr[0]), "b": int(pr[1]), "bet": ent["tonight"], "on": "div:" + dstage})
				out.append(ent)
		if day == 5 and w < GameData.week:
			var lines: Array = []
			for n in GameData.world.get("news", []):
				if int(n.get("y", 0)) == y and int(n.get("w", 0)) == w:
					lines.append(GameData.World.news_text(n))
			if not lines.is_empty():
				out.append({"icon": "", "title": tr("AROUND PORT FERRUM"), "text": "\n".join(lines.slice(0, 8))})
	if day == 6:
		if (w - 1) % GameData.MONTH_WEEKS == GameData.MONTH_WEEKS - 1 and GameData.living_cost() > 0:
			if GameData.rank_index() < 2:
				out.append({"icon": "rent", "title": tr("RENT & FOOD"), "text": tr("Gus takes $%d for the bay and the groceries.") % GameData.living_cost()})
			else:
				out.append({"icon": "rent", "title": tr("RUNNING COSTS"), "text": tr("Rent, the crew, the truck and the league fees: $%d.") % GameData.living_cost()})
		out.append({"icon": "stock", "title": tr("NEW STOCK"), "text": tr("The dealer restocks and fresh junk lands on the scrapyard pile.")})
	return out


var cal_popup_day := Vector2i(-1, -1)


func _on_cal_day(w: int, day: int) -> void:
	Sfx.play("click")
	cal_popup_day = Vector2i(w, day)
	var col := open_popup(tr("%s %d  ·  WEEK %d") % [tr(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"][day]),
			((w - 1) % GameData.MONTH_WEEKS) * 7 + day + 1, w])
	var events := day_events(w, day)
	# the day book: what happened that day (jobs finished, digs, fights, bills, mail)
	var logged: Array = GameData.day_log.get(GameData.day_key(GameData.year, w, day), [])
	if not logged.is_empty():
		col.add_child(GUI.text(tr("WHAT HAPPENED"), 15, GUI.YELLOW, "headb"))
		for le in logged:
			var lc: Color = {"good": GUI.GREEN, "bad": GUI.RED}.get(str(le.get("c", "info")), GUI.TEXT)
			var ll := GUI.text(tr(PHASE_SHORT[clampi(int(le.get("ph", 0)), 0, 2)]) + "  " + str(le["text"]), 14, lc)
			ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(ll)
		col.add_child(GUI.HazardStrip.new())
	if events.is_empty() and logged.is_empty():
		col.add_child(GUI.text(tr("Nothing on. A quiet day in the bay."), 16, GUI.MUTED))
	# league nights have a lot on: the list scrolls
	var n_rows := 0
	for e0 in events:
		n_rows += 1 + e0.get("matches", []).size()
	if n_rows > 6:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(0, minf(460.0, get_viewport_rect().size.y - 200.0))
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(sc)
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 8)
		sc.add_child(inner)
		col = inner
	for i in events.size():
		var e: Dictionary = events[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		if str(e.get("icon", "")) != "":
			row.add_child(GUI.EventIcon.new(str(e["icon"]), 34.0, bool(e.get("playoff", false))))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var tcol: Color = GUI.EVENT_COLORS.get(str(e.get("icon", "")), GUI.YELLOW)
		var title := str(e.get("title", ""))
		if e.get("tonight", false):
			title = tr("TONIGHT") + "  ·  " + title
		v.add_child(GUI.text(title, 16, tcol, "headb"))
		if e.has("won"):
			v.add_child(GUI.text(str(e["text"]), 15, GUI.GREEN if e["won"] else GUI.RED, "bold"))
		elif str(e.get("text", "")) != "":
			var l := GUI.text(str(e["text"]), 14, GUI.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		for k in e.get("matches", []).size():
			var m: Dictionary = e["matches"][k]
			var b := UI.button(match_label(m), _on_cal_match.bind(w, day, i, k), 14, Vector2(0, 40))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			v.add_child(b)
	# a later day: you can jump straight to it (it stops at a night with your own fight)
	if (w > GameData.week or (w == GameData.week and day > GameData.day_index())) and GameData.can_pass_day():
		var stop := GameData.next_fight_before(w, day)
		if stop != "":
			col.add_child(GUI.text(tr("Your %s fight comes first. The clock stops there.") % stop, 13, GUI.MUTED))
		col.add_child(UI.button(tr("Go to %s") % tr(GameData.DAY_FULL[day]), _on_go_to_day.bind(day, w), 16, Vector2(0, 44)))


## "ROOK · ECHO  vs  MARGO · TIN CAN" for a match button.
func match_label(m: Dictionary) -> String:
	if m.get("pickup", false):
		var o := GameData.current_opponent() if GameData.fight_mode() == "pickup" else {}
		return tr("%s  vs  %s") % [who({}, 0), str(o.get("name", tr("someone at the scrapyard")))]
	var ev: Dictionary = m["ev"]
	var a := int(m["a"])
	var b := int(m["b"])
	return tr("%s  vs  %s") % [who(ev, a), who(ev, b)] + ("   %.2fx / %.2fx" % [Career.odds(ev, a, b), Career.odds(ev, b, a)] if m.get("bet", false) else "")


## A single fight from the calendar: both robots side by side, records and odds. Betting lives at the
## Rusty Bolt (one desk for every bet), so on fight night this sends you there; Watch for other people's fights.
func _on_cal_match(w: int, day: int, i: int, k: int) -> void:
	var events := day_events(w, day)
	if i >= events.size() or k >= events[i].get("matches", []).size():
		return
	var m: Dictionary = events[i]["matches"][k]
	Sfx.play("click")
	var col := open_popup(str(events[i].get("title", "")))
	var pickup: bool = m.get("pickup", false)
	if pickup and GameData.pickup.is_empty():
		# nothing booked: pickups are whoever's at the bar that day
		var l := GUI.text(tr("No fight booked. Whoever's at the Rusty Bolt that night will take you on, if you want a fight."), 15, GUI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		var nav := HBoxContainer.new()
		nav.add_theme_constant_override("separation", 8)
		popup_footer.add_child(nav)
		nav.add_child(UI.button(tr("< Back"), _on_cal_day.bind(w, day), 15, Vector2(110, 44)))
		if w == GameData.week and day == GameData.day_index():
			var fb := UI.button(tr("Find a fight ›"), func(): close_popup(); go_to("Pub", "bar"), 15, Vector2(0, 44))
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav.add_child(fb)
		return
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 14)
	col.add_child(sides)
	var ev: Dictionary = {} if pickup else m["ev"]
	var a := int(m["a"])
	var b := int(m["b"])
	var bet: bool = m.get("bet", false)
	for side in 2:
		var id := a if side == 0 else b
		var other := b if side == 0 else a
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 3)
		sides.add_child(v)
		var pv: RobotPreview
		var o: Dictionary = {}
		if id == 0:
			pv = RobotPreview.new()
			pv.look = GameData.player_look()
			pv.facing = 1
			pv.anim = false
		else:
			o = GameData.current_opponent() if pickup else Career.robot_of(ev, id)
			pv = bot_preview(o)
		pv.custom_minimum_size = Vector2(220, 170)
		v.add_child(pv)
		var name_t := who(ev, id) if not pickup or id == 0 else tr("%s · %s") % [str(o.get("pilot", "?")), str(o.get("name", "?"))]
		var wid := -1
		if id != 0:
			wid = int(o.get("wid", -1)) if pickup else int(Career.pilot(ev, id).get("wid", -1))
		v.add_child(name_button(name_t, wid, 16, GUI.YELLOW if id == 0 else GUI.TEXT))
		var info := ""
		if not pickup:
			var t: Array = ev["table"].get(str(id), [0, 0, 0, 0])
			info = tr("Record %d-%d") % [int(t[0]), int(t[1])]
			info += "   " + tr("odds %.2fx") % Career.odds(ev, id, other)
		elif id == 0:
			info = tr("odds %.2fx") % GameData.self_odds()
		else:
			info = tr("Parts worth $%d") % int(GameData.World.bot_value(o)) if o.has("parts") else ""
		v.add_child(GUI.text(info, 14, GUI.MUTED))
	if not bet:
		col.add_child(GUI.text(tr("Betting opens on fight night, at the Rusty Bolt."), 14, GUI.MUTED))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	popup_footer.add_child(foot)
	foot.add_child(UI.button(tr("< Back"), _on_cal_day.bind(w, day), 15, Vector2(110, 44)))
	if bet and w == GameData.week:
		var bb := UI.button(tr("Bet at the Rusty Bolt ›"), func(): close_popup(); go_to("Pub", "bets"), 15, Vector2(0, 44))
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(bb)
	if bet and not pickup and a != 0 and GameData.can_watch(ev, a, b):
		foot.add_child(UI.button(tr("Watch"), _on_watch.bind(a, b, str(m.get("on", ""))), 15, Vector2(110, 44)))
	elif bet and not pickup and a != 0 and GameData.phase < 2:
		col.add_child(GUI.text(tr("The fights start in the evening. Come back then to watch."), 14, GUI.MUTED))


var bet_stake := 50
var bet_at := -100.0   # when you last placed a bet (the pilot pushes coins over the bar)


var bet_div := "event"   # which division's card the Bets screen shows on a league night


## The Rusty Bolt: who's at the bar (today's pickup fight), what's on the TV (tonight's top league
## fight, watch it), and the bookies: bets on any division fighting tonight, the cup, or yourself.
func build_bets() -> void:
	# every bet still open, wherever it was placed
	if not GameData.bets.is_empty():
		section(tr("YOUR OPEN BETS"))
		for x in GameData.bets:
			section("  " + bet_line(x))
	# every board the bookies have up tonight: the league tables, the cup, your own pickup
	var boards: Array = []
	for x in GameData.league_night():
		var k := str(x[0])
		boards.append([k, tr("Your division") if k == "event" else tr(Career.STAGES[x[1]["stage"]]["short"]).capitalize()])
	if GameData.bet_target() == "cup":
		boards.append(["cup", tr("Cup")])
	elif GameData.bet_target() == "self":
		boards.append(["self", tr("Your fight")])
	if boards.is_empty():
		section("No fights to bet on tonight. League nights are every other Saturday, cups on Wednesdays.")
		var tv := tv_info()
		if not tv.is_empty():
			section(tr("ON THE TV: %s") % str(tv["title"]) + "   " + str(tv["a"]))
		return
	var keys: Array = boards.map(func(x): return str(x[0]))
	if not keys.has(bet_div):
		bet_div = keys[0]
	if boards.size() > 1:
		var tabs := action_bar()
		for x in boards:
			var b := row_button(tabs, str(x[1]), _on_bet_div.bind(str(x[0])), true, 0)
			b.toggle_mode = true
			b.button_pressed = str(x[0]) == bet_div
	match bet_div:
		"self":
			build_self_bets()
		"cup":
			bet_card("cup", GameData.circuit)
		_:
			bet_card(bet_div, GameData.ev_for(bet_div))


## "$50 on ROOK at 1.80x, pays $90 (Rust League)"
func bet_line(x: Dictionary) -> String:
	var on := str(x["on"])
	var who_name := GameData.pilot_name
	var where := tr("your fight")
	if on != "self":
		var ev := GameData.ev_for(on)
		if int(x["pick"]) != 0:
			who_name = str(Career.pilot(ev, int(x["pick"])).get("pilot", "?"))
		where = tr(str(ev.get("name", "?")))
	return tr("$%d on %s at %.2fx, pays $%d (%s)") % [int(x["stake"]), who_name, float(x["odds"]), int(float(x["stake"]) * float(x["odds"])), where]


func _on_bet_div(k: String) -> void:
	bet_div = k
	refresh()


## A pilot's name you can tap: opens their pilot card. wid < 0 (you, a story rival, nobody) = plain text.
func name_button(text: String, wid: int, size: int = 16, col: Color = GUI.TEXT) -> Control:
	if wid < 0 or GameData.World.pilot(wid).is_empty():
		return GUI.text(text, size, col, "headb")
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", GUI.headb())
	b.add_theme_font_size_override("font_size", UI.tsz(size))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, col)
	b.tooltip_text = tr("Pilot card")
	b.pressed.connect(open_pilot.bind(wid))
	return b


class PilotFace extends Control:
	var look := {}
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1))
		load("res://pilot_art.gd").draw_head(self, size * 0.5 + Vector2(0, 6), minf(size.x, size.y) * 0.32, look, 1.0, 0.0)


## The pilot card: who they are, how they're doing, what's between the two of you, and their robot.
## Opens from any pilot's name: tables, the pub, messages, the calendar.
func open_pilot(wid: int) -> void:
	var W = GameData.World
	var p: Dictionary = W.pilot(wid)
	if p.is_empty():
		return
	Sfx.play("click")
	var col := open_popup(str(p["name"]) + (("  " + grudge_tag(wid)) if grudge_tag(wid) != "" else ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var face := PilotFace.new()
	face.look = W.look_of(wid)
	face.custom_minimum_size = Vector2(120, 140)
	row.add_child(face)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	info.add_child(GUI.text(GameData.pilot_standing(wid), 16, GUI.YELLOW, "headb"))
	info.add_child(GUI.text(tr("Career record %d-%d · this season %d-%d") % [int(p.get("w", 0)), int(p.get("l", 0)), int(p.get("sw", 0)), int(p.get("sl", 0))], 14, GUI.TEXT))
	var wo: Dictionary = W.robot(wid)
	info.add_child(GUI.text(tr("Read %s") % GameData.aim_dots(GameData.pilot_aim_level(wo)) + ("  " + tr("RATTLED") if wo.get("rattled", false) else ""), 14, GUI.RED if wo.get("rattled", false) else GUI.TEXT))
	info.add_child(GUI.text(tr("%s followers on BotMedia") % GameData.Social.fol_text(GameData.Social.pilot_fol(p)), 14, GUI.CYAN))
	var h: Array = GameData.h2h.get(str(wid), [0, 0])
	if int(h[0]) + int(h[1]) > 0:
		info.add_child(GUI.text(tr("Against you: you %d, them %d") % [int(h[0]), int(h[1])], 14, GUI.AMBER))
	else:
		info.add_child(GUI.text(tr("You've never fought."), 14, GUI.MUTED))
	var g := grudge_tag(wid)
	if g != "":
		var gl := GUI.text({tr("(bad blood)"): tr("Bad blood both ways. Neither of you has forgotten."), tr("(rival)"): tr("You've got a score to settle with them."),
				tr("(hates you)"): tr("They hold a grudge against you.")}.get(g, ""), 14, GUI.RED)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(gl)
	var bot: Dictionary = W.robot(wid)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 14)
	col.add_child(brow)
	var pv := bot_preview(bot)
	pv.custom_minimum_size = Vector2(160, 130)
	brow.add_child(pv)
	var bi := VBoxContainer.new()
	bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(bi)
	bi.add_child(GUI.text(str(bot.get("name", "?")), 16, GUI.TEXT, "headb"))
	bi.add_child(GUI.text(tr("Parts worth $%d") % int(W.bot_value(p.get("bot", {}))), 14, GUI.MUTED))
	# BotMedia: follow them, or read what they've been posting
	var sbar := HBoxContainer.new()
	sbar.add_theme_constant_override("separation", 8)
	popup_footer.add_child(sbar)
	var key := "w:%d" % wid
	var fol_on: bool = GameData.Social.follows(key)
	var fbt := UI.button(tr("Following") if fol_on else tr("Follow"), func():
		GameData.Social.follow(key, not GameData.Social.follows(key))
		open_pilot(wid), 14, Vector2(0, 42))
	fbt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbar.add_child(fbt)
	var bmb := UI.button(tr("BotMedia ›"), func(): close_popup(); open_account(key), 14, Vector2(0, 42))
	bmb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbar.add_child(bmb)
	# at the bar tonight? then you can take them on from here
	if GameData.patrons_today().any(func(x): return int(x["wid"]) == wid) and GameData.can_pass_day():
		var cb := UI.button(tr("Challenge ($%d)") % GameData.pickup_purse(str(p["tier"])), func(): close_popup(); _on_challenge(wid), 16, Vector2(0, 46))
		popup_footer.add_child(cb)


## How you two feel about each other: "(rival)" (you resent them), "(hates you)" (they resent
## you), "(bad blood)" (both), or "".
func grudge_tag(wid: int) -> String:
	var mine := GameData.is_rival(wid)
	var theirs := GameData.hates_me(wid)
	if mine and theirs:
		return tr("(bad blood)")
	if mine:
		return tr("(rival)")
	if theirs:
		return tr("(hates you)")
	return ""


## Today's pilots in the pub and the TV.
func build_pub_cards() -> void:
	var pats := GameData.patrons_today()
	if GameData.phase == 0:
		section(tr("THE MORNING AFTER. A few of last night's crowd never made it home.") if not pats.is_empty() else tr("THE MORNING AFTER. Nobody here but the bartender."))
	elif GameData.phase == 1:
		section(tr("A QUIET AFTERNOON. The crowd comes in tonight."))
	else:
		section(tr("IN THE RUSTY BOLT TONIGHT. Anyone here will take a pickup fight."))
	var can := GameData.can_pass_day()
	for pat in pats:
		var wid := int(pat["wid"])
		var o := GameData.World.robot(wid)
		var rec: Array = GameData.h2h.get(str(wid), [0, 0])
		var sub := GameData.pilot_standing(wid) + "   " + tr("Record %d-%d") % [int(pat["w"]), int(pat["l"])]
		if int(rec[0]) + int(rec[1]) > 0:
			sub += "   " + tr("You vs them: %d-%d") % [int(rec[0]), int(rec[1])]
		var tag := grudge_tag(wid)
		if tag != "":
			sub += "   " + tag
		if pat.get("hungover", false):
			sub += "   " + tr("(sleeping it off)")
		var row := make_tap_row(bot_preview(o), tr("%s · %s") % [str(pat["name"]), str(o.get("name", "?"))], sub, open_pilot.bind(wid))
		var purse: int = GameData.pickup_purse(str(pat["tier"]))
		row_button(row, tr("Challenge ($%d)") % purse if can else tr("Your fight's tonight"), _on_challenge.bind(wid), can, 150)
		if tag != "":
			# a pilot with something to say to you: the stripes say "go and talk"
			var host: Node = row
			while host != null and not (host is Button):
				host = host.get_parent()
			if host:
				GUI.mark_new(host, true)
	if GameData.pickups_this_week() >= 2:
		section(tr("You've fought %d pickups this week. The crowd's seen you, so purses are smaller till Monday.") % GameData.pickups_this_week())
	var tv := tv_info()
	if not tv.is_empty():
		var hm := GameData.headline_match()
		var bar := action_bar()
		var l := GUI.text(tr("ON THE TV: %s") % str(tv["title"]) + "   " + str(tv["a"]) + ("  vs  " + str(tv["b"]) if str(tv["b"]) != "" else ""), 14, GUI.AMBER, "bold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		bar.add_child(l)
		if not hm.is_empty():
			row_button(bar, "Watch", _on_watch.bind(int(hm["a"]), int(hm["b"]), str(hm["on"])), GameData.can_watch(hm["ev"], int(hm["a"]), int(hm["b"])), 100)


## Challenge the pilot at the bar: tonight's pickup fight is against them.
func _on_challenge(wid: int = -1) -> void:
	GameData.start_pickup(wid)
	GameData.save_game()
	refresh()
	open_fight_popup()


## One division's (or the cup's) card tonight: every match with odds, Bet and Watch.
func bet_card(on: String, ev: Dictionary) -> void:
	if ev.is_empty():
		return
	section(tr("%s · %s. Odds come from the table and the robots, so a pilot nobody rates pays big. Watch a fight and its result is the real one.") % [tr(str(ev["name"])), tr(Career.round_name(ev))])
	if not GameData.watch_time(ev):
		section(tr("The fights start in the evening. Come back then to watch."))
	var bar := action_bar()
	bar.add_child(UI.label("Stake:", 16))
	for st in GameData.stakes():
		var b := row_button(bar, "$%d" % st, _on_stake.bind(st), true, 80)
		b.toggle_mode = true
		b.button_pressed = st == bet_stake
	for pr in Career.round_matches(ev):
		var a: int = pr[0]
		var b: int = pr[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list_box.add_child(row)
		bet_side(row, ev, a, b, on)
		var vs := UI.label("vs", 15, Color(0.6, 0.6, 0.65))
		vs.custom_minimum_size = Vector2(28, 0)
		vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(vs)
		bet_side(row, ev, b, a, on)
		if a != 0:
			row_button(row, "Watch", _on_watch.bind(a, b, on), GameData.can_watch(ev, a, b), 80)
	var mine: Array = GameData.bets.filter(func(x): return x["on"] == on and int(x["round"]) == Career.round_key(ev))
	if not mine.is_empty():
		section("Your bets this round:")
		for x in mine:
			var who: String = GameData.pilot_name if x["pick"] == 0 else str(Career.pilot(ev, x["pick"]).get("pilot", "?"))
			section(tr("  $%d on %s at %.2fx  ->  pays $%d") % [x["stake"], who, x["odds"], int(x["stake"] * x["odds"])])


## No league round this week: the bookies still take money on your own fight.
func build_self_bets() -> void:
	var o := GameData.current_opponent()
	section("No league round tonight, but the bookies will still take money on your pickup fight. Bets need real cash.")
	var bar := action_bar()
	bar.add_child(UI.label("Stake:", 16))
	for st in GameData.stakes():
		var b := row_button(bar, "$%d" % st, _on_stake.bind(st), true, 80)
		b.toggle_mode = true
		b.button_pressed = st == bet_stake
	var odds := GameData.self_odds()
	var row := make_row(bot_preview(o), tr("%s vs %s") % [GameData.pilot_name, str(o.get("name", "?"))],
			tr("%s to win: %.2fx. A $%d bet pays $%d.") % [GameData.pilot_name, odds, bet_stake, int(bet_stake * odds)])
	row_button(row, "Bet", _on_bet.bind(0, -1), GameData.money >= bet_stake, 80)
	var mine: Array = GameData.bets.filter(func(x): return x["on"] == "self")
	if not mine.is_empty():
		section("Your bets on this fight:")
		for x in mine:
			section(tr("  $%d on %s at %.2fx  ->  pays $%d") % [x["stake"], GameData.pilot_name, x["odds"], int(x["stake"] * x["odds"])])


## One side of a match: pilot, robot, record, odds and a Bet button.
func bet_side(row: HBoxContainer, ev: Dictionary, id: int, other: int, on: String = "") -> void:
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
		row_button(box, "Bet", _on_bet_on.bind(on, id, other), GameData.money >= bet_stake, 64)


func _on_bet_on(on: String, pick: int, vs: int) -> void:
	if on == "":
		_on_bet(pick, vs)
		return
	var before := GameData.money
	note(GameData.place_bet_on(on, pick, vs, bet_stake), "buy")
	if GameData.money < before:
		bet_at = Time.get_ticks_msec() / 1000.0
	GameData.save_game()
	refresh()


func _on_watch(a: int, b: int, on: String = "") -> void:
	GameData.start_watch(a, b, on)
	Sfx.play("click")
	Loading.go("res://fight.tscn")


## Every pilot in Port Ferrum: who's on top, who's broke, who's moved up, who retired - and the news.
# ---------------------------------------------------------------- the jukebox (The Rusty Bolt)

var juke_bar: GUI.BlockBar
var juke_time: Label
var juke_shown := -2
var juke_lengths := {}


func juke_length(file: String) -> float:
	if not juke_lengths.has(file):
		var path := "res://music/%s.ogg" % file
		juke_lengths[file] = (load(path) as AudioStream).get_length() if ResourceLoader.exists(path) else 0.0
	return float(juke_lengths[file])


func mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


## The scrap jukebox: every song in the game by name. Tap one to play it; it carries on down the list.
func build_jukebox() -> void:
	var cur := Sfx.jukebox_index()
	juke_shown = cur
	# now playing
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", GUI.box(Color(0.1, 0.06, 0.05, 0.92), 10, 12))
	list_box.add_child(np)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	np.add_child(col)
	col.add_child(GUI.text(tr("THE RUSTY BOLT JUKEBOX"), 12, GUI.AMBER, "headb"))
	var title := tr("Pick a song") if cur < 0 else tr(Sfx.JUKEBOX[cur][1])
	col.add_child(GUI.text(title, 22, GUI.TEXT, "headb"))
	col.add_child(GUI.text("" if cur < 0 else tr(Sfx.JUKEBOX[cur][2]), 12, GUI.MUTED))
	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 10)
	col.add_child(prog)
	juke_bar = GUI.BlockBar.new()
	juke_bar.block_w = 4.0
	juke_bar.height = 10.0
	juke_bar.setup(0.0, 1.0, 40.0, GUI.AMBER)   # 40 blocks across the song
	juke_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	juke_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.add_child(juke_bar)
	juke_time = GUI.readout("0:00 / 0:00", 18, GUI.AMBER)
	prog.add_child(juke_time)
	var ctrl := action_bar(col)
	row_button(ctrl, "‹ Prev", _on_juke_step.bind(-1), true, 110)
	if cur < 0:
		row_button(ctrl, "Play", _on_juke_play.bind(0), true, 140).add_theme_color_override("font_color", GUI.YELLOW)
	else:
		row_button(ctrl, "Stop", _on_juke_stop, true, 140).add_theme_color_override("font_color", GUI.RED)
	row_button(ctrl, "Next ›", _on_juke_step.bind(1), true, 110)
	if not GameData.settings.get("music", true):
		col.add_child(GUI.text(tr("Music is switched off in Settings."), 12, GUI.RED))
	# the list
	section(tr("Every song in Port Ferrum. Tap one to play it."))
	for k in Sfx.JUKEBOX.size():
		var e: Array = Sfx.JUKEBOX[k]
		var num := GUI.readout("%02d" % (k + 1), 20, GUI.AMBER if k == cur else GUI.MUTED)
		num.custom_minimum_size = Vector2(52, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row := make_tap_row(num, tr(e[1]), tr(e[2]), _on_juke_play.bind(k), "", k == cur)
		var ln := GUI.readout(mmss(juke_length(e[0])), 17, GUI.MUTED)
		ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ln)


func update_jukebox() -> void:
	if juke_bar == null or not is_instance_valid(juke_bar) or not juke_bar.is_visible_in_tree():
		return
	if Sfx.jukebox_index() != juke_shown:
		refresh()   # the song changed by itself (next in the list)
		return
	var pos := Sfx.music_position()
	juke_bar.set_fill(40.0 * pos.x / pos.y if pos.y > 0.0 else 0.0)
	juke_time.text = "%s / %s" % [mmss(pos.x), mmss(pos.y)]


func _on_juke_play(k: int) -> void:
	Sfx.jukebox(k)
	refresh()


func _on_juke_step(step: int) -> void:
	var cur := Sfx.jukebox_index()
	Sfx.jukebox(posmod((cur if cur >= 0 else 0) + step, Sfx.JUKEBOX.size()))
	refresh()


func _on_juke_stop() -> void:
	Sfx.stop_music()
	Sfx.current_track = ""
	Sfx.music("garage")
	refresh()


func build_pilots_view() -> void:
	var World = GameData.World
	section("Port Ferrum's pilots, ranked by the bookies. Tap a pilot for their card. The town's news is on BotMedia.")
	var order: Array = [GameData.rank] + World.TIERS.filter(func(t): return t != GameData.rank)
	var widths := [34, 0, 70, 78, 96]
	for tier in order:
		section(tr(Career.STAGES[tier]["name"]).to_upper())
		table_row(["#", "PILOT · ROBOT", "W-L", "PARTS", "WALLET"], widths, Color(0.7, 0.7, 0.75), Color(0, 0, 0, 0))
		var pool: Array = World.by_rating(tier)
		pool.reverse()
		# you're one of the pilots too: slot in by the same rating the bookies use
		var me := -1
		if tier == GameData.rank:
			var mine := World.rating({"parts": GameData.equipped_ids(), "hp": 1.0, "damage": 1.0}, 0.5)
			me = pool.size()
			for k in pool.size():
				if mine >= World.rating(World.robot(int(pool[k]["wid"])), pool[k]["skill"]):
					me = k
					break
			pool.insert(me, {"you": true})
		for k in pool.size():
			var p: Dictionary = pool[k]
			var living: int = World.LIVING[tier]
			if p.has("you"):
				var cash_me := GameData.money
				var my_living := maxi(1, GameData.living_cost())
				var my_wallet := tr("in debt") if cash_me < 0 else (tr("rich") if cash_me > my_living * 12 else (tr("comfortable") if cash_me > my_living * 3 else tr("getting by")))
				table_row([str(k + 1), tr("%s · %s (you)") % [GameData.pilot_name.to_upper(), GameData.robot_name.to_upper()], "%d-%d" % [GameData.wins, GameData.losses],
						"$%d" % int(World.bot_value({"parts": GameData.equipped_ids()})), my_wallet], widths,
						Color(1, 0.55, 0.5) if cash_me < 0 else GUI.YELLOW, Color(0.95, 0.75, 0.1, 0.12))
				continue
			var cash := int(p["cash"])
			var wallet := tr("in debt") if cash < 0 else (tr("rich") if cash > living * 12 else (tr("comfortable") if cash > living * 3 else tr("getting by")))
			var col := Color(1, 0.55, 0.5) if cash < 0 else Color(0.9, 0.9, 0.95)
			table_row([str(k + 1), tr("%s · %s") % [p["name"], p["bot"]["name"]], "%d-%d" % [int(p["w"]), int(p["l"])],
					"$%d" % int(World.bot_value(p["bot"])), wallet], widths, col, Color(0, 0, 0, 0), int(p["wid"]))
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
	var before := GameData.money
	note(GameData.place_bet(pick, vs, bet_stake), "buy")
	if GameData.money < before:
		bet_at = Time.get_ticks_msec() / 1000.0
	GameData.save_game()
	refresh()


## "SATURDAY NIGHT", "TUESDAY NIGHT"...
func tonight_name() -> String:
	return tr("%s NIGHT") % tr(GameData.DAY_FULL[GameData.day_index()]).to_upper()


func _on_go_to_day(idx: int, w: int = -1) -> void:
	close_popup()
	time_begin()
	GameData.skip_to_day(idx, w)
	refresh()
	time_end()




const PHASE_SHORT := ["AM", "PM", "EVE"]


# ---------------------------------------------------------------- the day plan
# Before the clock moves: one window that shows what the bay will get done (a ruler of hours, one
# block per hour, with the bell on it), tonight, the things you can still do before the time goes
# (done right there), and the next few days. The big button in it moves the clock; the same window
# then turns into the report of what happened (TIME PASSES), which also goes in the day book.

class DayRuler extends Control:
	var hours := 8            # slots on the ruler (1 = one hour)
	var bell := -1            # slot where the bell rings (-1: no bell on this ruler)
	var night_from := 8       # first night (overtime) slot
	var overtime := false
	var shifts: Array = []    # [[label, from, to], ...]
	var rows: Array = []      # [{"label", "color", "fill": [0..1 per slot], "done": slot it finishes or -1}]
	var font: Font

	func _ready() -> void:
		custom_minimum_size = Vector2(560, 44 + rows.size() * 24 + 8)

	func _draw() -> void:
		var lw := 150.0
		var sw := (size.x - lw - 6.0) / maxf(1.0, float(hours))
		var f: Font = font if font else ThemeDB.fallback_font
		# the shifts along the top
		for sh in shifts:
			var x0: float = lw + float(sh[1]) * sw
			var x1: float = lw + float(sh[2]) * sw
			var night: bool = int(sh[1]) >= night_from
			draw_rect(Rect2(x0 + 1, 4, x1 - x0 - 2, 22), Color(0.2, 0.2, 0.26) if not night else Color(0.12, 0.12, 0.2))
			draw_string(f, Vector2(x0, 20), str(sh[0]), HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, UI.px(11), Color(0.85, 0.85, 0.9) if not night or overtime else Color(0.5, 0.5, 0.6))
		# an hour tick per slot
		for k in hours + 1:
			draw_line(Vector2(lw + k * sw, 30), Vector2(lw + k * sw, 34), Color(0.4, 0.4, 0.45), 1.0)
		var y := 40.0
		for r in rows:
			draw_string(f, Vector2(0, y + 15), str(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, lw - 8, UI.px(12), Color(0.85, 0.85, 0.9))
			var fill: Array = r["fill"]
			for k in hours:
				var cell := Rect2(lw + k * sw + 1, y + 2, sw - 2, 16)
				var a: float = float(fill[k]) if k < fill.size() else 0.0
				var night: bool = k >= night_from
				draw_rect(cell, Color(0.16, 0.16, 0.2))
				if a > 0.0:
					var c: Color = r["color"]
					if night and not overtime:
						c = Color(c, 0.3)   # only with overtime
					draw_rect(Rect2(cell.position, Vector2(cell.size.x * clampf(a, 0.15, 1.0), cell.size.y)), c)
			var dk: int = int(r["done"])
			if dk >= 0:
				var tx := lw + (dk + 1) * sw - 2
				draw_polyline(PackedVector2Array([Vector2(tx - 11, y + 10), Vector2(tx - 7, y + 15), Vector2(tx - 1, y + 4)]), Color(0.553, 1.0, 0.651), 2.5)
			y += 24.0
		# the bell
		if bell >= 0:
			var bx := lw + bell * sw
			draw_line(Vector2(bx, 2), Vector2(bx, size.y - 2), Color(1.0, 0.35, 0.3), 3.0)
			draw_string(f, Vector2(bx + 4, size.y - 4), tr("BELL"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.px(11), Color(1.0, 0.45, 0.4))


var plan_open := false


## The big button: the day plan (in the evening with your fight booked, the Bell Check instead).
func open_day_plan() -> void:
	var evening := GameData.phase == 2
	if evening and not GameData.can_pass_day():
		open_fight_popup()
		return
	plan_open = true
	var col := open_popup(tr("%s %s") % [tr(DAY_FULL_UP[GameData.day_index()]), tr(GameData.PHASE_NAMES[GameData.phase])])
	col.custom_minimum_size = Vector2(720, 0)
	var mode := GameData.fight_mode()
	var to_bell := GameData.hours_to_bell()
	# 1. the bay: a ruler of hours, the job board laid out on it
	var lead := tr("The bay puts in %d hours, then it's %s.") % [int(GameData.SHIFT_HOURS), tr(["the afternoon", "the evening", "tomorrow morning"][GameData.phase])]
	if evening:
		lead = tr("The day's done. The bay only works tonight if you pay for overtime.")
	col.add_child(GUI.text(lead, 14, GUI.CYAN))
	GameData.sync_swaps()
	if GameData.jobs.is_empty():
		col.add_child(GUI.text(tr("Nothing on the job board: the bay has nothing to do."), 14, GUI.MUTED))
	else:
		var ruler := DayRuler.new()
		ruler.font = GUI.headb()
		ruler.hours = int(to_bell + GameData.NIGHT_HOURS)
		ruler.night_from = int(to_bell)
		ruler.bell = int(to_bell) if (not evening and mode != "open") else -1
		ruler.overtime = GameData.overtime
		var sh: Array = []
		var at := 0
		for ph in range(GameData.phase, 2):
			sh.append([tr(GameData.PHASE_NAMES[ph]), at, at + int(GameData.SHIFT_HOURS)])
			at += int(GameData.SHIFT_HOURS)
		sh.append([tr("NIGHT (OVERTIME)") if not GameData.overtime else tr("NIGHT · OVERTIME BOOKED"), at, at + int(GameData.NIGHT_HOURS)])
		ruler.shifts = sh
		# each job's progress hour by hour (projected; night hours assume overtime)
		var proj: Array = [GameData.jobs.duplicate(true)]
		for k in ruler.hours:
			proj.append(GameData.work(float(k + 1), false))
		for i in mini(GameData.jobs.size(), 7):
			var j: Dictionary = GameData.jobs[i]
			var p := GameData.inst(int(j["uid"]))
			var nm: String = GameData.part_def(p["id"])["name"] if not p.is_empty() else "?"
			var fill: Array = []
			var done_at := -1
			for k in ruler.hours:
				var a: float = float(proj[k][i]["done"])
				var b: float = float(proj[k + 1][i]["done"])
				fill.append(clampf(b - a, 0.0, 1.0))
				if done_at < 0 and b >= float(j["total"]) - 0.001 and a < float(j["total"]) - 0.001:
					done_at = k
			ruler.rows.append({"label": (tr("Fix %s") if j["kind"] == "repair" else tr("Bolt on %s")) % nm, "color": GUI.GREEN if j["kind"] == "repair" else GUI.CYAN, "fill": fill, "done": done_at})
		col.add_child(ruler)
		col.add_child(GUI.text(tr("1 block = 1 hour of work · ✓ = finished"), 11, GUI.MUTED, "headb"))
	# 2. tonight (or tomorrow, at night)
	col.add_child(GUI.HazardStrip.new())
	if not evening:
		var o := GameData.current_opponent()
		if o.is_empty():
			var n := GameData.patrons_today().size()
			var trow := action_bar(col)
			var tl := GUI.text(tr("TONIGHT: nothing booked. %d pilots at the Rusty Bolt will take you on.") % n, 15, GUI.YELLOW, "headb")
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			trow.add_child(tl)
			row_button(trow, tr("Find a fight ›"), func(): close_popup(); go_to("Pub", "bar"), true, 150)
		else:
			col.add_child(GUI.text(tr("TONIGHT: %s · %s · purse $%d") % [GameData.fight_title(), str(o.get("name", "?")), GameData.current_reward()], 15, GUI.YELLOW, "headb"))
			var now := bell_readiness(0.0)
			var after := bell_readiness(GameData.SHIFT_HOURS)
			var bell_r := bell_readiness()
			var rl := GUI.text(tr("Robot ready: now %d%% · after this shift %d%% · at the bell %d%%") % [roundi(now * 100), roundi(after * 100), roundi(bell_r * 100)], 14,
					GUI.GREEN if bell_r >= 0.9 else (GUI.AMBER if bell_r >= 0.6 else GUI.RED))
			col.add_child(rl)
	else:
		var tom := (GameData.day_index() + 1) % 7
		var tw := GameData.week + (1 if tom == 0 else 0)
		var bits: Array = []
		for e in day_events(tw, tom):
			bits.append(str(e.get("title", "")))
		col.add_child(GUI.text(tr("TOMORROW: %s") % (", ".join(bits) if not bits.is_empty() else tr("nothing on")), 15, GUI.YELLOW, "headb"))
	# 3. before you go: what you can still do, done right here
	var todo := VBoxContainer.new()
	todo.add_theme_constant_override("separation", 6)
	var cost := GameData.repair_all_cost()
	if cost > 0:
		var r := action_bar(todo)
		var rt := GUI.text(tr("The robot's damaged: fix it all for $%d, about %s of work.") % [cost, GameData.hours_text(GameData.repair_all_hours())], 14, GUI.TEXT)
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(rt)
		GUI.mark_new(row_button(r, tr("Repair all $%d") % cost, _plan_do.bind("repair"), GameData.can_repair(cost), 170), GameData.can_repair(cost))
	if not GameData.jobs.is_empty() and not GameData.overtime:
		var r2 := action_bar(todo)
		var ot := GUI.text(tr("Overtime: the crew works through tonight, 8 more hours for every pair of hands."), 14, GUI.TEXT)
		ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r2.add_child(ot)
		row_button(r2, tr("Overtime $%d") % GameData.overtime_cost(), _plan_do.bind("overtime"), GameData.money >= GameData.overtime_cost(), 170)
	if GameData.digs_left > 0:
		var r3 := action_bar(todo)
		var dt := GUI.text(tr("Today's dig at the scrapyard is still there. Chance of finding something: %d%%. Leave it and tomorrow it's %d%%.") % [roundi(GameData.dig_luck * 100), roundi(minf(GameData.DIG_LUCK_MAX, GameData.dig_luck + GameData.DIG_LUCK_STEP) * 100)], 14, GUI.TEXT)
		dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r3.add_child(dt)
		GUI.mark_new(row_button(r3, tr("Dig now"), _plan_do.bind("dig"), true, 170), true)
	var unread := GameData.inbox.size() - GameData.inbox_seen
	if unread > 0:
		var r4 := action_bar(todo)
		var ut := GUI.text(tr("%d messages you haven't read.") % unread, 14, GUI.TEXT)
		ut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r4.add_child(ut)
		row_button(r4, tr("Read them ›"), func(): close_popup(); go_to("Feed", "all"), true, 170)
	var offers_n: int = GameData.Contracts.st()["offers"].size()
	if offers_n > 0:
		var r6 := action_bar(todo)
		var ot := GUI.text(tr("Sponsor offers waiting: %d") % offers_n, 14, GUI.TEXT)
		ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r6.add_child(ot)
		row_button(r6, tr("Contracts ›"), func(): close_popup(); go_to("Feed", "contracts"), true, 170)
	if not GameData.Social.drafts().is_empty():
		var r7 := action_bar(todo)
		var pt := GUI.text(tr("The fans are waiting for your post about the fight."), 14, GUI.TEXT)
		pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r7.add_child(pt)
		row_button(r7, tr("Post ›"), func(): close_popup(); go_to("Feed", "home"), true, 170)
	if not GameData.league_night().is_empty() and not evening:
		var r5 := action_bar(todo)
		var bt := GUI.text(tr("League night: the bookies close when the bell rings."), 14, GUI.TEXT)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r5.add_child(bt)
		row_button(r5, tr("Bets ›"), func(): close_popup(); go_to("Pub", "bets"), true, 170)
	if GameData.day_index() == 6:
		var r6 := action_bar(todo)
		var st := GUI.text(tr("The dealer restocks tomorrow: last chance for this week's stock."), 14, GUI.TEXT)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r6.add_child(st)
		row_button(r6, tr("Dealer ›"), func(): close_popup(); go_to("Parts", "dealer"), GameData.unlocked("shop"), 170)
	if todo.get_child_count() > 0:
		col.add_child(GUI.HazardStrip.new())
		col.add_child(GUI.text(tr("BEFORE THE TIME GOES"), 15, GUI.YELLOW, "headb"))
		col.add_child(todo)
	# 4. coming up: the next three days in one line each
	var soon: Array = []
	for k in range(1, 4):
		var di := GameData.day_index() + k
		var w := GameData.week + di / 7
		var d := di % 7
		var bits2: Array = []
		for e in day_events(w, d):
			var t := str(e.get("title", ""))
			if str(e.get("icon", "")) == "rent" and GameData.money < GameData.living_cost():
				t += " " + tr("(you're short!)")
			bits2.append(t)
		if not bits2.is_empty():
			soon.append(tr(DAY_NAMES[d]) + ": " + ", ".join(bits2))
	if not soon.is_empty():
		col.add_child(GUI.HazardStrip.new())
		col.add_child(GUI.text(tr("COMING UP"), 15, GUI.YELLOW, "headb"))
		for line in soon:
			var sl := GUI.text(str(line), 13, GUI.TEXT)
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(sl)
	if GameData.can_pass_day():
		# days or weeks ahead: pick the day on the calendar
		var r7 := action_bar(col)
		var sk := GUI.text(tr("Skip days or weeks: tap a day on the calendar."), 13, GUI.MUTED)
		sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r7.add_child(sk)
		row_button(r7, tr("Calendar ›"), func(): close_popup(); go_to("Season", "calendar"), true, 170)
	# the decision
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	popup_footer.add_child(row)
	var no := UI.button(tr("Not yet"), close_popup, 17, Vector2(0, 52))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	var go := UI.button(fight_button.text, _on_next_phase, 18, Vector2(0, 52))
	go.add_theme_font_override("font", GUI.stencil())
	var fs := GUI.box(GUI.YELLOW, 8, 4)
	for st2 in ["normal", "hover", "pressed", "hover_pressed"]:
		go.add_theme_stylebox_override(st2, fs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		go.add_theme_color_override(c, Color(0.08, 0.08, 0.08))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.size_flags_stretch_ratio = 2.0
	row.add_child(go)


## Things done right inside the day plan; the plan comes back afterwards (a dig shows its find first).
func _plan_do(what: String) -> void:
	match what:
		"repair":
			_on_repair_all()
		"overtime":
			note(GameData.buy_overtime(), "buy")
			GameData.save_game()
		"dig":
			close_popup()
			plan_after_find = true
			_on_dig("")
			if overlay == null:
				plan_after_find = false
				open_day_plan()
			return
	refresh()
	open_day_plan()


var plan_after_find := false


func _on_next_phase() -> void:
	plan_open = false
	close_popup()
	if GameData.phase == 2 and not GameData.can_pass_day():
		note(tr("Your fight is tonight."), "error")
		return
	time_begin()
	GameData.next_phase()
	refresh()
	time_end()




func _on_cal_month(step: int) -> void:
	cal_month = clampi(cal_month + step, 0, MONTH_NAMES.size() - 1)
	refresh()


## Secondary view: the league you're in - table and bracket.
var table_div := ""   # which division's table the Standings screen shows ("" = yours)


## Standings: the year's table for any of the four divisions. 1 point a win, ties go to the
## pilot who destroyed more parts. Top 4 go up, bottom 4 go down.
func build_league_view() -> void:
	var stage := table_div if table_div != "" else GameData.rank
	var tabs := flow_bar()
	for st in Career.EVENTS:
		var label := tr(Career.STAGES[st]["short"]).capitalize() + (" ●" if st == GameData.rank or (st == "title" and Career.has_player(GameData.leagues.get("title", {}))) else "")
		var b := row_button(tabs, label, _on_table_div.bind(st), true, 0)
		b.toggle_mode = true
		b.button_pressed = st == stage
	var ev: Dictionary = GameData.leagues.get(stage, {})
	if ev.is_empty():
		section("No table yet.")
		return
	var status := tr("%s, year %d: ") % [tr(str(ev["name"])), int(ev["year"])]
	if ev["phase"] == "league":
		status += tr(Career.round_name(ev))
	elif ev["phase"] == "finals":
		status += tr("FINAL TABLE · PLAYOFFS")
	else:
		status += tr("FINAL TABLE")
	section(status)
	var n: int = ev["pilots"].size()
	var rule := ""
	match stage:
		"open":
			rule = tr("The gutter: pilots with no league live on pickups and cups. On the open dates at the start of the year the best 16 fight the Open Trials over three Saturdays: two wins and you're in the Scrap League, two losses and you're out for the year.")
		"title":
			rule = tr("The Titanium Championship: the top 8 of last year's Steel League, a knockout on the open dates at the start of the year. Win the final and you're the champion of Port Ferrum.")
		"steel":
			rule = tr("1 point a win, ties go to more parts destroyed. Top 5 go into the Titanium Championship, 6th to 13th play off for 3 more places. Bottom 5 go down and %s to %s play off, 3 more go down.") % [GameData.ordinal(n - 12), GameData.ordinal(n - 5)]
		_:
			rule = tr("1 point a win, ties go to more parts destroyed. Top 3 win trophies and prize money, 4th gets money. Top 5 go up and 6th to 13th play off for 3 more places. Bottom 5 go down and %s to %s play off, 3 more go down.") % [GameData.ordinal(n - 12), GameData.ordinal(n - 5)]
	section(rule)
	if stage == "title":
		if not ev.get("bracket", {}).is_empty():
			show_bracket(ev)
		return
	if ev.has("finals"):
		show_finals(ev)
	if not ev.get("trials", false):
		show_table(ev)


## The promotion and relegation playoffs: every match so far, who went up, who went down.
func show_finals(ev: Dictionary) -> void:
	for side in ["up", "down"]:
		if not ev["finals"].has(side):
			continue
		var head := tr("RELEGATION PLAYOFF (3 go down)")
		if side == "up":
			head = tr("OPEN TRIALS (every winner goes up)") if ev.get("trials", false) else (tr("TITLE PLAYOFF (3 more into the Championship)") if ev["stage"] == "steel" else tr("PROMOTION PLAYOFF (3 go up)"))
		section(head)
		var rounds: Array = ev["finals"][side]["rounds"]
		for r in rounds.size():
			for m in rounds[r]:
				var a: int = m["a"]
				var b: int = m["b"]
				var w: int = m["w"]
				var txt := tr(Career.finals_round_name(ev, side, r)) + ":  " + tr("%s  vs  %s") % [who(ev, a), who(ev, b)]
				if w >= 0:
					txt += "   ->  " + (GameData.pilot_name if w == 0 else str(Career.pilot(ev, w).get("pilot", "?")))
				var mine := a == 0 or b == 0
				table_row([txt], [0], GUI.YELLOW if mine else (Color(0.8, 0.8, 0.85) if w >= 0 else Color(1, 1, 1)),
						Color(1.0, 0.7, 0.2, 0.15) if mine else Color(0, 0, 0, 0))
	if ev.has("promoted") or ev.has("relegated"):
		var up: Array = ev.get("promoted", []).map(func(i): return str(Career.pilot(ev, int(i)).get("pilot", "?")) if int(i) != 0 else GameData.pilot_name)
		var down: Array = ev.get("relegated", []).map(func(i): return str(Career.pilot(ev, int(i)).get("pilot", "?")) if int(i) != 0 else GameData.pilot_name)
		if not up.is_empty():
			section(tr("GOING UP: %s") % ", ".join(up))
		if not down.is_empty():
			section(tr("GOING DOWN: %s") % ", ".join(down))


func _on_table_div(st: String) -> void:
	table_div = st
	refresh()


func show_table(ev: Dictionary) -> void:
	var widths := [34, 0, 70, 46, 56]
	table_row(["#", "PILOT · ROBOT", "W-L", "PTS", "PARTS"], widths, Color(0.7, 0.7, 0.75), Color(0, 0, 0, 0))
	var order := Career.standings(ev)
	for pos in order.size():
		var id: int = order[pos]
		var e := Career.pilot(ev, id)
		var t: Array = ev["table"].get(str(id), [0, 0, 0, 0])
		var z := Career.zone(ev, pos)
		var col := Color(1, 1, 1)
		var bg := Color(0, 0, 0, 0)
		match z:
			"up":
				bg = Color(0.3, 0.9, 0.4, 0.16)
				col = Color(0.75, 1.0, 0.8)
			"up_po":
				bg = Color(0.3, 0.9, 0.4, 0.06)
				col = Color(0.85, 1.0, 0.88)
			"down_po":
				bg = Color(1.0, 0.55, 0.2, 0.07)
				col = Color(1.0, 0.86, 0.75)
			"down":
				bg = Color(1.0, 0.35, 0.3, 0.16)
				col = Color(1.0, 0.75, 0.72)
		if id == 0:
			col = GUI.YELLOW
			bg = Color(1.0, 0.7, 0.2, 0.2)
		var medal := Career.medal_of(ev, id)
		var mark: String = tr(["", " (GOLD)", " (SILVER)", " (BRONZE)"][medal])
		if e.has("wid"):
			var tg := grudge_tag(int(e["wid"]))
			if tg != "":
				mark += "  " + tg
		table_row([str(pos + 1), who(ev, id) + mark, "%d-%d" % [t[0], t[1]], str(t[2]), str(t[3])], widths, col, bg, int(e.get("wid", -1)))


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
		return tr("%s · %s") % [GameData.pilot_name.to_upper(), GameData.robot_name]
	var e := Career.pilot(ev, id)
	var o := Career.robot_of(ev, id)
	var pilot: String = str(o.get("pilot", e.get("pilot", "")))
	if pilot == "":
		pilot = str(e.get("pilot", "?"))
	return tr("%s · %s") % [pilot, o.get("name", "?")]


func table_row(cells: Array, widths: Array, col: Color, bg: Color, wid: int = -1) -> void:
	var p := PanelContainer.new()
	if wid >= 0:
		# a pilot's row: tap it for their pilot card
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(func(e):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				open_pilot(wid))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	p.add_child(row)
	var grow := float(UI.tsz(15)) / (15.0 * UI.SCALE)   # the columns widen with the text size
	for k in cells.size():
		var l := UI.label(str(cells[k]), 15, col)
		l.clip_text = true
		if int(widths[k]) > 0:
			l.custom_minimum_size = Vector2(float(widths[k]) * grow, 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	list_box.add_child(p)




# ---------------------------------------------------------------- time passing
# Jumping ahead isn't a blink: a window shows the clock running, a bar filling one block per
# shift that went by, and then what happened meanwhile (work done, bills, mail, the town).

var tp := {}   # the world as it was when the clock started moving


func clock_steps() -> int:
	return ((GameData.year * 52 + GameData.week) * 7 + GameData.day_index()) * 3 + GameData.phase


func job_label(j: Dictionary) -> String:
	var p := GameData.inst(int(j["uid"]))
	var n: String = GameData.part_def(p["id"])["name"] if not p.is_empty() else "?"
	if j["kind"] == "repair":
		return tr("%s is fixed.") % n
	return tr("%s is bolted on (%s).") % [n, tr(GameData.SLOT_NAMES.get(j["slot"], ""))]


func time_begin() -> void:
	var jobs := {}
	for j in GameData.jobs:
		jobs["%s/%d/%s/%s" % [j["kind"], int(j["uid"]), j["robot"], j["slot"]]] = job_label(j)
	tp = {"steps": clock_steps(), "jobs": jobs, "money": GameData.money, "bills": GameData.bills_note,
			"pending": GameData.pending_talk.size(), "news": (GameData.world.get("news", []) as Array).size(),
			"week": GameData.week, "label": date_label(), "y": GameData.year, "d": GameData.day_index(), "ph": GameData.phase}


func date_label() -> String:
	return tr("%s %s · WEEK %d") % [tr(DAY_FULL_UP[GameData.day_index()]), tr(GameData.PHASE_NAMES[GameData.phase]), GameData.week]


## The clock has moved: the window that shows it. False if no time went by.
func time_end() -> bool:
	if tp.is_empty():
		return false
	var steps: int = clock_steps() - int(tp["steps"])
	if steps <= 0:
		tp = {}
		return false
	var lines: Array = []   # [text, colour]
	# work on the board
	var still := {}
	for j in GameData.jobs:
		still["%s/%d/%s/%s" % [j["kind"], int(j["uid"]), j["robot"], j["slot"]]] = true
	for k in tp["jobs"]:
		if not still.has(k):
			lines.append([str(tp["jobs"][k]), GUI.GREEN])
	var done_lines := lines.size()
	if not GameData.jobs.is_empty():
		lines.append([tr("Still on the board: %d jobs.") % GameData.jobs.size() if GameData.jobs.size() != 1 else tr("Still on the board: 1 job."), GUI.CYAN])
	var before_money := lines.size()
	# money
	if GameData.bills_note > int(tp["bills"]):
		lines.append([(tr("Rent and food: -$%d.") if GameData.rank_index() < 2 else tr("Rent, crew and travel: -$%d.")) % (GameData.bills_note - int(tp["bills"])), GUI.RED])
		GameData.bills_note = 0
	if GameData.week != int(tp["week"]):
		lines.append([tr("Sunday: the dealer restocked."), GUI.AMBER])
	# mail and the town
	var mail: int = GameData.pending_talk.size() - int(tp["pending"])
	if mail > 0:
		lines.append([tr("%d new messages. Gus will pass them on.") % mail if mail != 1 else tr("A new message. Gus will pass it on."), GUI.YELLOW])
	var news: Array = GameData.world.get("news", [])
	var fresh: int = mini(news.size() - int(tp["news"]), 4)
	for i in range(news.size() - fresh, news.size()):
		if i >= 0:
			lines.append([GameData.World.news_text(news[i]), GUI.MUTED])
	if lines.is_empty():
		lines.append([tr("A quiet stretch. Nothing much happened."), GUI.MUTED])
	# into the day book (the calendar's day pop-up), under the day it started
	for l in lines:
		if l[1] != GUI.MUTED and l[1] != GUI.CYAN:
			GameData.log_day(str(l[0]), "good" if l[1] == GUI.GREEN else ("bad" if l[1] == GUI.RED else "info"), int(tp["y"]), int(tp["week"]), int(tp["d"]), int(tp["ph"]))
	var from_label: String = tp["label"]
	tp = {}
	show_time_passing(from_label, steps, lines)
	return true


func show_time_passing(from_label: String, steps: int, lines: Array) -> void:
	var col := open_popup(tr("TIME PASSES"))
	var clock := GUI.readout(from_label, 26, GUI.GREEN)
	col.add_child(clock)
	var bar := GUI.BlockBar.new()   # one block per shift (morning, afternoon, evening)
	bar.block_w = 14.0 if steps <= 21 else 7.0
	bar.setup(0.0, 1.0, float(steps), GUI.AMBER)
	col.add_child(bar)
	col.add_child(GUI.text(tr("1 block = one part of a day (morning, afternoon, evening)"), 11, GUI.MUTED, "headb"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.modulate.a = 0.0
	col.add_child(list)
	for l in lines:
		var t := GUI.text("• " + str(l[0]), 15, l[1])
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(560, 0)
		list.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var msgs := UI.button(tr("BotMedia"), func(): close_popup(); _on_tab("Feed"), 16, Vector2(0, 46))
	msgs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msgs)
	var ok := UI.button(tr("OK"), close_popup, 16, Vector2(0, 46))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	var to_label := date_label()
	var dur := clampf(0.25 * steps, 0.5, 2.5)
	var tw := bar.create_tween()   # dies with the window if you close it early
	tw.tween_method(bar.set_fill, 0.0, float(steps), dur)
	tw.tween_callback(func():
		clock.text = to_label
		Sfx.play("time", 0.0, -8.0))
	tw.tween_property(list, "modulate:a", 1.0, 0.3)


func bills_text() -> String:
	if GameData.bills_note <= 0:
		return ""
	var t := (tr(" Rent and food: -$%d.") if GameData.rank_index() < 2 else tr(" Rent, crew and travel: -$%d.")) % GameData.bills_note
	GameData.bills_note = 0
	return t
	refresh()


func _on_rematch() -> void:
	GameData.pickup = {}
	GameData.exhibition = true
	GameData.save_game()
	note("Booked: OVERLORD, in the Grand Hall. Hit the fight button when you're ready.", "fight")
	refresh()


func build_team_tab() -> void:
	section(tr("Backups are built from your spare parts and keep their damage. Each one needs a gantry, and every gantry puts the rent up. Send puts one in when the main robot is too beat up."))
	var ms := GameData.stats()
	section(tr("A team shares %d power: 2 robots get %d each, 3 get %d. Your robot alone: %s, %d power.")
			% [int(GameData.TEAM_POWER), int(GameData.team_share(2)), int(GameData.team_share(3)), tr(GameData.weight_class(ms["power_used"])), ms["power_used"]])
	var bar := action_bar()
	var split: bool = GameData.settings.get("team_controls", "linked") == "split"
	var b := row_button(bar, tr("Team controls: %s") % ("SPLIT: each robot gets its own movement pad" if split else "LINKED: every robot follows one pad"), _on_team_controls, true, 0)
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
					" (too heavy, it will be overloaded)" if ws["power_used"] > share else ""]
			sub = tr("READY. " if GameData.wingman_ready(k) else "CAN'T FIGHT: missing a head or torso. ") + power + ", ".join(names)
		else:
			pv.look = {}
		if k >= GameData.gantries:
			var rowg := make_row(pv, name, tr("No gantry for it yet. Every backup robot needs its own gantry in the crew bay: $%d, and the rent goes up $%d a month.") % [GameData.gantry_price(), GameData.gantry_rent()])
			if k == GameData.gantries:
				row_button(rowg, tr("Buy gantry $%d") % GameData.gantry_price(), _on_buy_gantry, GameData.money >= GameData.gantry_price(), 170)
			continue
		var row := make_row(pv, name, sub)
		row_button(row, tr("Rebuild") if not w.is_empty() else tr("Build"), _on_build_wingman.bind(k), true, 100)
		if w.is_empty() and k == GameData.gantries - 1:
			row_button(row, tr("Sell gantry"), _on_sell_gantry, true, 120)
		if not w.is_empty():
			var c := GameData.wingman_repair_cost(k)
			row_button(row, (tr("Fix $%d · %s") % [c, GameData.hours_text(GameData.wingman_repair_hours(k))]) if c > 0 else (tr("On the job board") if GameData.has_work("w%d" % k) else tr("All repaired")), _on_repair_wingman.bind(k), c > 0 and GameData.can_repair(c), 150)
			row_button(row, "Disband", _on_disband_wingman.bind(k), true, 100)


func _on_team_controls() -> void:
	var split: bool = GameData.settings.get("team_controls", "linked") == "split"
	GameData.settings["team_controls"] = "linked" if split else "split"
	GameData.save_settings()
	note(tr("Team controls: %s.") % ("LINKED: all your robots follow one movement pad" if split else "SPLIT: one movement pad per robot, shared attack buttons. Move the pads in Settings > Edit controls"), "click")
	refresh()


func _on_buy_gantry() -> void:
	note(GameData.buy_gantry(), "buy")
	GameData.save_game()
	refresh()


func _on_sell_gantry() -> void:
	note(GameData.sell_gantry(), "click")
	GameData.save_game()
	refresh()


func _on_build_wingman(k: int) -> void:
	note(GameData.build_wingman(k), "equip")
	refresh()


func _on_repair_wingman(k: int) -> void:
	note(GameData.repair_wingman(k), "repair")
	refresh()


func _on_disband_wingman(k: int) -> void:
	confirm(tr("DISBAND %s?") % GameData.wingman_name(k), tr("Its parts go back to Storage. Building it again means bolting every part on again."), tr("Disband"), _do_disband.bind(k))


func _do_disband(k: int) -> void:
	GameData.clear_wingman(k)
	note(tr("%s's parts went back to your Spares.") % GameData.wingman_name(k), "click")
	refresh()


func bot_preview(o: Dictionary) -> RobotPreview:
	var pv := RobotPreview.new()
	pv.look = GameData.look_from_spec(GameData.opponent_spec_from(o, 1.0))
	pv.facing = -1
	pv.anim = false
	return pv


# ---------------------------------------------------------------- actions

## New things carry marching stripes: the first tap has Gus explain them (a short scene), then opens them.
## The first time you open something new, Gus explains it in his bubble while you look at it.
## Returns true only when the caller should wait (block = true) instead of going ahead.
func gus_explains(feature: String, block: bool = false) -> bool:
	if not GameData.is_new(feature):
		return false
	play_story(["unlock_" + feature])
	return block


func star(text: String, feature: String) -> String:
	return text   # (new things get marching stripes now: marked())


## New things get the marching hazard stripes round them: "here, something to do".
func marked(c: Control, feature: String) -> Control:
	GUI.mark_new(c, GameData.is_new(feature))
	return c


## A rail button. The first visit to a section Gus hasn't shown you yet plays his scene first.
func _on_tab(t: String) -> void:
	var first: String = {"Storage": "storage", "Season": "season", "Parts": "scrapyard"}.get(t, "")
	if t == "Crew":
		first = "team" if GameData.team_unlocked() else "pilot"
	if first == "season" and GameData.is_new("season") and not GameData.story_seen.has("dad_trophies") and GameData.story_seen.has("first_garage"):
		GameData.mark_story_seen("unlock_season")   # Gus's first words in his office are about your dad's trophies
	if first == "scrapyard" and GameData.tour >= 0 and GameData.is_new("scrapyard"):
		GameData.mark_story_seen("unlock_scrapyard")   # the tour's line already said it
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
	if scene == "phone":
		# the gear shelf behind your pilot: tap a controller to look at it
		for sp in GarageArt.gear_spots(preview.size, GameData.owned_controllers):
			if Rect2(Vector2(sp[1]) + Vector2(-22, -18), Vector2(44, 36)).has_point(pos):
				Sfx.play("click")
				open_controller(str(sp[0]))
				return
		return
	if scene != "office":
		return
	for s in GarageArt.trophy_spots(preview.size, GameData.wall_trophies().size()):
		var base: Vector2 = s[1]
		if Rect2(base + Vector2(-18, -50), Vector2(36, 52)).has_point(pos):
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


## i indexes the office wall (GameData.wall_trophies): your dad's three first, then yours.
func open_trophy(i: int) -> void:
	var tr_: Dictionary = GameData.wall_trophies()[i]
	var medal := int(tr_.get("medal", 1))
	var col := open_popup(tr("%s · %s") % [tr(Career.MEDALS[medal]), tr(str(tr_.get("name", "")))])
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
	if tr_.get("dad", false):
		info.add_child(UI.label(tr("Your dad's. Won before you were born."), 17, Color(1.0, 0.85, 0.4)))
		var gus := UI.label(tr("Gus: He'd want you to put yours up next to it. Then beat it."), 14, Color(0.75, 0.75, 0.8))
		gus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(gus)
		return
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


func _on_go_shop(kind: String) -> void:
	shop_kind = kind
	shop_filter = kind
	go_to("Parts", "dealer")


func _on_order_kind(k: String) -> void:
	order_kind = k
	refresh()


func _on_go_workshop(kind: String) -> void:
	reset_workshop(kind)
	order_kind = "part"
	tab = "Parts"
	_on_seg("order")


func _on_reroll() -> void:
	var before := GameData.money
	note(GameData.reroll_stock(), "buy" if GameData.money < before else "error")
	refresh()


## Bay > Style & paint: pick a fighting style (watch each signature move first), and a paint job.
func build_style_view() -> void:
	var col := list_box
	section(tr("FIGHTING STYLE") + " · " + tr("Your style changes how ECHO fights and gives it a free signature move.").replace("ECHO", GameData.robot_name), col)
	if GameData.style_locked:
		section("You've already switched style since your last fight. One switch between fights. Fight with it first.", col)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)
	# on top: the signature move, looping, so you know what it looks like before a fight
	var left := VBoxContainer.new()
	body.add_child(left)
	style_demo = MoveDemo.new()
	style_demo.custom_minimum_size = Vector2(400, 225)
	left.add_child(style_demo)
	style_demo_label = UI.label("", 14, Color(0.5, 0.9, 1.0))
	style_demo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_demo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	style_demo_label.text = tr("%s · %s: %s") % [tr(st["name"]).to_upper(), tr(sig["name"]), Specials.seq_text(sig["seq"])]


func _on_pick_style(id: String) -> void:
	if GameData.style_locked:
		return
	GameData.style = id
	GameData.style_locked = true
	close_popup()
	note(tr("Fighting style: %s. Signature move: %s.") % [tr(Catalog.STYLES[id]["name"]), tr(Specials.MOVES[Catalog.STYLES[id]["signature"]]["name"])], "equip")
	refresh()


func _on_open_scout() -> void:
	if GameData.scout_key() == "":
		return   # nothing booked tonight: nobody to scout
	if gus_explains("scout"):
		return
	var msg := ""
	if not GameData.scouted():
		var before := GameData.money
		msg = GameData.do_scout()
		if GameData.money == before:
			note(msg, "error")
			open_fight_popup()
			return
		Sfx.play("buy")
		refresh()
	# the report shows what the scout saw - if they spotted him, one part will be different on the night
	var o := GameData.current_opponent(false)
	if o.is_empty():
		return   # nothing booked tonight: nobody to scout
	var spec := GameData.opponent_spec_from(o, 1.0)
	var col := open_popup(tr("SCOUTING REPORT: ") + str(o["name"]))
	if msg == "":
		msg = "Their crew spotted your scout! They'll swap something before the bell. One thing in this report won't be what shows up." if GameData.scout.get("spied_back", false) else "Clean scouting run. They never saw you."
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
			line += "  · " + tr(Catalog.TRAITS[d["trait"]]["name"])
		if d["gimmick"] != "":
			line += "  · " + tr(Specials.GADGETS[d["gimmick"]]["name"])
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
				extra = "  · " + tr(Catalog.TRAITS[d["trait"]]["name"])
			elif d["gimmick"] != "":
				extra = "  · " + tr(Specials.GADGETS[d["gimmick"]]["name"])
			info.add_child(UI.label(tr("%s: %s%s") % [tr(GameData.SLOT_NAMES[slot]), d["name"], extra], 12))
	var moves: Array = []
	for id in o["specials"]:
		moves.append(tr(Specials.MOVES[id]["name"]))
	moves.append(tr(Specials.MOVES[Catalog.STYLES[st]["signature"]]["name"]) + tr(" (signature)"))
	var ml := UI.label("Moves: " + ", ".join(moves), 13, Color(0.5, 0.9, 1.0))
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ml)
	if weak != "":
		info.add_child(UI.label(tr("Weak point: %s. Aim there!") % tr(GameData.SLOT_NAMES[weak]), 15, Color(1.0, 0.9, 0.3)))
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
	note(text, "buy" if GameData.money < before or GameData.part_def(id)["cost"] == 0 else "error")
	refresh()


func _on_equip(uid: int, slot: String) -> void:
	note(GameData.equip(uid, slot), "equip")
	refresh()


func _on_unequip(slot: String) -> void:
	GameData.unequip(slot)
	note(tr("Removed the %s. It's in Storage.") % tr(GameData.SLOT_NAMES[slot]), "equip")
	refresh()


func _on_repair(uid: int) -> void:
	spark_at = Time.get_ticks_msec() / 1000.0
	var before := GameData.money
	var text := GameData.repair(uid)
	note(text, "repair" if GameData.money < before or GameData.has_work("m") else "error")
	refresh()


func _on_repair_all() -> void:
	repair_tapped = true
	spark_at = Time.get_ticks_msec() / 1000.0
	var before := GameData.money
	var text := GameData.repair_all()
	note(text, "repair" if GameData.money < before else "error")
	refresh()


## A yes/no window for things that can't be undone.
func confirm(title: String, text: String, yes_text: String, cb: Callable, no_text: String = "") -> void:
	var col := open_popup(title)
	var l := GUI.text(text, 16, GUI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	popup_footer.add_child(row)
	var yes := UI.button(yes_text, func(): close_popup(); cb.call(), 17, Vector2(0, 48))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	var no := UI.button(no_text if no_text != "" else tr("Keep it"), close_popup, 17, Vector2(0, 48))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)


## Taking a part off is quick, but putting one back (or another) means bolting it on again from scratch.
func _on_unequip_ask(slot: String) -> void:
	var p := GameData.equipped_inst(slot)
	if p.is_empty():
		return
	var col := open_popup(tr("TAKE IT OFF?"))
	var d := GameData.part_def(p["id"])
	var l := GUI.text(tr("%s comes off and goes to Storage. Bolting it back on, or anything else in that slot, takes %s of bay work from scratch.") % [d["name"], GameData.hours_text(GameData.swap_hours(d))], 16, GUI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	popup_footer.add_child(row)
	var yes := UI.button(tr("Take it off"), func(): close_popup(); _on_unequip(slot), 17, Vector2(0, 48))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	var no := UI.button(tr("Leave it on"), close_popup, 17, Vector2(0, 48))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)


func _on_randomize() -> void:
	if gus_explains("randomize"):
		return
	var before := bolting_left()
	var t := GameData.randomize_robot()
	note(t + bolting_note(before), "equip")
	Sfx.play("repair", 0.2)
	refresh()


## Hours of bolting on still to do for the main robot.
func bolting_left() -> float:
	GameData.sync_swaps()
	var h := 0.0
	for j in GameData.jobs:
		if j["kind"] == "swap" and j["robot"] == "m":
			h += float(j["total"]) - float(j["done"])
	return h


## " That's 6 h of bolting on the job board." when a change added work.
func bolting_note(before: float) -> String:
	var added := bolting_left() - before
	return (" " + tr("That's %s more bolting on the job board.") % GameData.hours_text(added)) if added > 0.05 else ""


func _on_save_setup(k: int) -> void:
	note(GameData.save_setup(k), "buy")
	refresh()
	_on_open_setups()


func _on_load_setup(k: int) -> void:
	var before := bolting_left()
	var t := GameData.load_setup(k)
	note(t + bolting_note(before), "equip")
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
	note(GameData.sell(uid), "sell")
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
	note(text, "buy" if GameData.money < before else "error")
	refresh()


func _on_install_chip(id: String) -> void:
	note(GameData.install_chip(id), "equip")
	refresh()


func _on_uninstall_chip(id: String) -> void:
	note(GameData.uninstall_chip(id), "untarget")
	refresh()


func _on_paint(k: int) -> void:
	GameData.paint = k
	var need: int = GameData.Contracts.paint_required()
	if need >= 0 and need != k:
		note(tr("Painted %s. Your title sponsor wants %s at the bell!") % [tr(GameData.PAINTS[k]["name"]), tr(GameData.PAINTS[need]["name"])], "error")
	else:
		note(tr("Painted %s.") % tr(GameData.PAINTS[k]["name"]), "equip")
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
		note(text, "repair")
		Sfx.play("buy")
		reset_workshop(ws["kind"])
	else:
		note(text, "error")
	refresh()


func _on_enter_cup(k: int) -> void:
	GameData.enter_circuit(k)
	GameData.save_game()
	var first: Dictionary = Career.robot_of(GameData.circuit, Career.player_opponent(GameData.circuit)) if Career.player_opponent(GameData.circuit) != -1 else {}
	note(tr("Entered the %s! First opponent: %s.") % [GameData.circuit["name"], str(first.get("name", "?"))], "fight")
	refresh()


func _on_abandon() -> void:
	confirm(tr("LEAVE THE CUP?"), tr("You're out of it for good, and any bets on it are off."), tr("Leave the cup"), _do_abandon)


func _do_abandon() -> void:
	GameData.abandon_circuit()
	GameData.save_game()
	note("Left the cup.", "error")
	refresh()


func _on_menu() -> void:
	GameData.save_game()   # leaving always saves
	get_tree().change_scene_to_file("res://main.tscn")


func _on_send() -> void:
	var options: Array = [-1]
	for k in GameData.wingmen.size():
		if GameData.wingman_ready(k):
			options.append(k)
	GameData.sending = options[(options.find(GameData.sending) + 1) % options.size()]
	note(tr("%s will fight the next 1-on-1. %s") % [GameData.sending_name(),
			tr("Its damage stays on it. Your main robot sits this one out.") if GameData.sending >= 0 else ""], "click")
	refresh()


## What's wrong with the robot before a fight: missing limbs, a hurt core, parts hanging off.
func damage_report() -> Array:
	var out: Array = []
	var robot := "m"
	var eq: Dictionary = GameData.equipped
	if GameData.sending >= 0 and not GameData.is_team_fight():
		robot = "w%d" % GameData.sending   # the backup robot fights this one
		eq = GameData.wingmen[GameData.sending]
	# the job board as it will stand when the bell rings
	var swaps := {}
	var fixes := {}
	for e in GameData.at_the_bell():
		var j: Dictionary = e["job"]
		if j["kind"] == "swap" and j["robot"] == robot:
			swaps[j["slot"]] = float(e["progress"])
		elif j["kind"] == "repair":
			fixes[int(j["uid"])] = j
	for slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		var p := GameData.inst(int(eq.get(slot, -1)))
		var name: String = tr(GameData.SLOT_NAMES[slot])
		if p.is_empty():
			out.append(tr("No %s fitted!") % name.to_lower())
			continue
		if swaps.has(slot):
			var pr: float = swaps[slot]
			if pr < 0.5 and not (slot == "torso" or slot.begins_with("head")):
				out.append(tr("%s: only %d%% bolted on by the bell. It fights WITHOUT it.") % [name, int(pr * 100)])
			else:
				out.append(tr("%s: %d%% bolted on by the bell. It goes in loose, at half its HP.") % [name, int(pr * 100)])
		var h := GameData.bell_hp_ratio(p)
		if (slot == "torso" and h < 0.75) or h < 0.5:
			out.append(tr("%s at %d%% health by the bell") % [name, int(h * 100)] + (tr(" (still on the bench)") if not GameData.repair_job(int(p["uid"])).is_empty() else ""))
	return out


## Fight! Always a last look first: who it is, a chance to scout them, and what's wrong with your robot.
func _on_fight() -> void:
	# the one button: time moves on until the evening; then tonight's fight, or on to tomorrow
	if GameData.phase < 2 or GameData.fight_mode() == "open":
		open_day_plan()
		return
	open_fight_popup()


## The bell chip: straight to the job board.
func _on_bell() -> void:
	Sfx.play("click")
	go_to("Bay", "jobs")


## How fit to fight the robot going in tonight will be at the bell, 0..1: each body part's HP by
## the bell against its full HP (a limb less than half bolted on counts as gone, a loose one half).
func bell_readiness(h: float = -1.0) -> float:
	var robot := "m"
	var eq: Dictionary = GameData.equipped
	if GameData.sending >= 0 and not GameData.is_team_fight() and GameData.sending < GameData.wingmen.size():
		robot = "w%d" % GameData.sending
		eq = GameData.wingmen[GameData.sending]
	var swaps := {}
	for e in GameData.at_the_bell(h):
		var j: Dictionary = e["job"]
		if j["kind"] == "swap" and j["robot"] == robot:
			swaps[j["slot"]] = float(e["progress"])
	var have := 0.0
	var full := 0.0
	for slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
		var p := GameData.inst(int(eq.get(slot, -1)))
		if p.is_empty():
			full += 50.0   # a missing part counts against you
			continue
		var mx := float(GameData.part_def(p["id"])["hp"])
		full += mx
		var hp := GameData.bell_hp_ratio(p, h) * mx
		if swaps.has(slot):
			hp *= 0.0 if (float(swaps[slot]) < 0.5 and not (slot == "torso" or slot == "head")) else 0.5
		have += hp
	return clampf(have / maxf(1.0, full), 0.0, 1.0)


func open_fight_popup() -> void:
	var keep_scroll := popup_scroll.scroll_vertical if overlay != null and is_instance_valid(popup_scroll) else 0
	var o := GameData.current_opponent()
	var mode := GameData.fight_mode()
	var col := open_popup(tr("BELL CHECK · %s") % tonight_name() + (" · " + tr("CUP") if mode == "circuit" else ""))
	col.custom_minimum_size = Vector2(640, 0)
	fight_popup_open = true
	if mode == "story" and GameData.event.get("trials", false):
		# the Open Trials: the whole year hangs on this
		var rec: Array = Career.trials_record(GameData.event, 0)
		col.add_child(GUI.text(tr("MAKE OR BREAK"), 22, GUI.RED, "stencil"))
		var ml := GUI.text(tr("Two wins and we're in the Scrap League. Two losses and it's a whole year in the gutter: pickups and cups, no league, no league money.") + " " +
				tr("Our record: %d-%d.") % [int(rec[0]), int(rec[1])], 15, GUI.AMBER)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(ml)
	# who, and for how much
	var who_p := str(o.get("pilot", ""))
	col.add_child(GUI.text(GameData.fight_title(), 14, GUI.MUTED, "headb"))
	var opp_line := HBoxContainer.new()
	opp_line.add_theme_constant_override("separation", 10)
	col.add_child(opp_line)
	opp_line.add_child(name_button(tr("%s, piloted by %s") % [o.get("name", "?"), who_p] if who_p != "" else str(o.get("name", "?")), int(o.get("wid", -1)), 18, GUI.YELLOW))
	opp_line.add_child(GUI.readout(tr("Purse $%d") % GameData.current_reward(), 20, GUI.AMBER))
	if who_p != "" or o.has("wid"):
		col.add_child(GUI.text(tr("Their Read %s: how fast they aim and find your weak spots.") % GameData.aim_dots(GameData.pilot_aim_level(o)), 14, GUI.TEXT))
		if o.get("rattled", false):
			col.add_child(GUI.text(tr("RATTLED: a bad run has got to them. Their Read is down for now."), 14, GUI.GREEN))
	# sponsors check their rules at the bell
	for c in GameData.Contracts.st()["active"]:
		for r in c["reqs"]:
			if str(r["kind"]) in ["paint", "controller", "repaired"] and not req_ok(r):
				var sl := GUI.text(tr("%s wants: %s") % [GameData.Contracts.sp_name(c), GameData.Contracts.req_text(r)], 14, GUI.AMBER)
				sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				col.add_child(sl)
	if mode != "story" and mode != "circuit" and GameData.day_index() < 5 and ["league", "playoff"].has(str(GameData.week_plan(GameData.year, GameData.week, "sat")["kind"])):
		var warn := GUI.text(tr("Your big fight is this Saturday. Whatever breaks tonight has to be fixed (and paid for) by then."), 14, GUI.CYAN)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(warn)
	# the robot as it will be when the bell rings
	var ready := bell_readiness()
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	col.add_child(rrow)
	rrow.add_child(GUI.text(tr("AT THE BELL"), 15, GUI.YELLOW, "headb"))
	var rb := GUI.BlockBar.new()   # 1 block = 5%
	rb.setup(ready * 100.0, 5.0, 100.0, GUI.GREEN if ready >= 0.9 else (GUI.AMBER if ready >= 0.6 else GUI.RED))
	rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rrow.add_child(rb)
	rrow.add_child(GUI.readout("%d%%" % roundi(ready * 100.0), 20, GUI.GREEN if ready >= 0.9 else (GUI.AMBER if ready >= 0.6 else GUI.RED)))
	var issues := damage_report()
	for line in issues:
		col.add_child(GUI.text("• " + str(line), 15, GUI.RED))
	if GameData.phase < 2:
		var left_h: int = [8, 4, 0][GameData.phase]
		var cl := GUI.text(tr("The bell rings this evening: the bay gets %d more hours on the job board before it.") % left_h, 14, GUI.CYAN)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(cl)
	# scouting: pay a kid with a camera to look at their robot first
	if GameData.scout_key() != "" and GameData.unlocked("scout"):
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		col.add_child(srow)
		var sl := GUI.text(tr("You know what they're bringing.") if GameData.scouted() else tr("Scout them first? A kid at the docks sneaks a camera into their garage."), 14, GUI.TEXT)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(sl)
		var sb := marked(UI.button(tr("Scouting report") if GameData.scouted() else tr("Scout $%d") % GameData.scout_cost(), _on_open_scout, 16, Vector2(170, 44)), "scout")
		sb.disabled = not GameData.scouted() and GameData.money < GameData.scout_cost()
		srow.add_child(sb)
	prefight_bet(col)
	# the decision
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	popup_footer.add_child(row)
	if mode == "pickup" or mode == "exhibition":
		var off := UI.button(tr("Call it off"), _on_call_off, 16, Vector2(0, 50))
		off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(off)
	var back := UI.button(tr("Back to the bay"), close_popup, 16, Vector2(0, 50))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	var go_text := tr("FIGHT!") if issues.is_empty() else tr("Fight anyway")
	if GameData.phase < 2:
		go_text = tr("FIGHT TONIGHT (%d h of bay work first)") % [8, 4, 0][GameData.phase]
	var go := UI.button(go_text, _start_fight, 18, Vector2(0, 50))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = not GameData.can_send()
	if not GameData.can_send():
		go.text = tr("Needs a head and a torso")
	row.add_child(go)
	if keep_scroll > 0:
		(func(): popup_scroll.scroll_vertical = keep_scroll).call_deferred()


## A booked pickup (or the rematch) is called off: no fight tonight.
func _on_call_off() -> void:
	close_popup()
	GameData.refund_self_bets()
	GameData.pickup = {}
	GameData.exhibition = false
	GameData.save_game()
	note(tr("Called it off. No fight tonight."))
	refresh()


## Bet on yourself right in the pre-fight window: pick a stake, tap Bet.
func prefight_bet(col: VBoxContainer) -> void:
	var mb := my_fight_bet()
	if mb.is_empty():
		return
	col.add_child(GUI.HazardStrip.new())
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var t := GUI.text(tr("BET ON YOURSELF"), 15, GUI.YELLOW, "headb")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(GUI.readout(tr("odds %.2fx") % float(mb["odds"]), 20, GUI.GREEN))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	col.add_child(bar)
	for st in GameData.stakes():
		var b := UI.button("$%d" % st, _on_prefight_stake.bind(st), 14, Vector2(64, 42))
		b.toggle_mode = true
		b.button_pressed = st == bet_stake
		bar.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	var bet := UI.button(tr("Bet $%d · pays $%d") % [bet_stake, int(bet_stake * float(mb["odds"]))], _on_prefight_bet, 15, Vector2(200, 42))
	bet.disabled = GameData.money < bet_stake
	bar.add_child(bet)
	var placed := 0
	for x in GameData.bets:
		if x["on"] == GameData.bet_target() and int(x["pick"]) == 0:
			placed += int(x["stake"])
	if placed > 0:
		col.add_child(GUI.text(tr("Already on yourself: $%d") % placed, 13, GUI.MUTED))


## Your own fight in this week's betting: who you're up against and the price on you. {} = no bets this time.
func my_fight_bet() -> Dictionary:
	var target := GameData.bet_target()
	if target == "":
		return {}
	if target == "self":
		return {"vs": -1, "odds": GameData.self_odds()}
	var ev := GameData.bet_event()
	if ev.is_empty():
		return {}
	for pr in Career.round_matches(ev):
		if int(pr[0]) == 0 or int(pr[1]) == 0:
			var vs: int = int(pr[1]) if int(pr[0]) == 0 else int(pr[0])
			return {"vs": vs, "odds": Career.odds(ev, 0, vs)}
	return {}


func _on_prefight_stake(st: int) -> void:
	bet_stake = st
	open_fight_popup()


func _on_prefight_bet() -> void:
	var mb := my_fight_bet()
	if mb.is_empty():
		return
	var before := GameData.money
	note(GameData.place_bet(0, int(mb["vs"]), bet_stake), "buy")
	if GameData.money < before:
		bet_at = Time.get_ticks_msec() / 1000.0
	GameData.save_game()
	refresh()
	open_fight_popup()




func _start_fight() -> void:
	close_popup()
	GameData.to_evening()   # the bay works the rest of the day; the bell rings in the evening
	GameData.save_game()
	var idx := GameData.current_opponent_index()
	# the rival calls in to talk trash first, then it's fight time
	if idx >= 0 and play_story(["pre_%d" % idx], _go_fight):
		fight_button.disabled = true
		return
	var taunt := GameData.rival_taunt()
	if not taunt.is_empty() and play_story([{"lines": taunt}], _go_fight):
		fight_button.disabled = true
		return
	_go_fight()


func _go_fight() -> void:
	GameData.flush_save()
	Loading.go("res://fight.tscn")
