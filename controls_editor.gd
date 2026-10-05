extends Node2D

# helper scripts, loaded by path so the game also runs without an editor scan
const Arena = preload("res://arena.gd")
const Controls = preload("res://controls.gd")
const RobotArt = preload("res://robot_art.gd")
## Settings > Edit controls: a fight scene with the touch buttons on top.
## Drag any button to move it, tap SMALLER / BIGGER to resize the selected one,
## ALL - / ALL + to resize everything. "1 PAD / 2 PADS / 3 PADS" edits the split-control
## layouts used when you fight with a multibot team. Saved as soon as you leave.

const TOOLS := ["smaller", "bigger", "all_smaller", "all_bigger", "pads", "reset", "done"]
const TOOL_LABELS := {"smaller": "− SMALLER", "bigger": "BIGGER +", "all_smaller": "ALL −", "all_bigger": "ALL +",
		"reset": "RESET", "done": "DONE"}
const STEP := 0.1

var screen := Vector2(1152, 648)
var floor_y := 420.0
var font: Font
var clock := 0.0
var pads := 1
var buttons: Array = []
var selected := ""
var dragging := ""
var drag_offset := Vector2.ZERO
var drag_id := -99
var tool_rects := {}
var player_look := {}
var enemy_look := {}
var crowd: Array = []
var touch_device := false
var flash := ""
var flash_t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	touch_device = DisplayServer.is_touchscreen_available()
	Sfx.music("garage")
	player_look = GameData.player_look()
	player_look["scale"] = 1.3
	enemy_look = GameData.look_from_spec(GameData.opponent_spec(clampi(GameData.current_opponent_index(), 0, GameData.OPPONENTS.size() - 1)))
	enemy_look["scale"] = minf(enemy_look["scale"] * 1.3, 1.5)
	layout()
	crowd = Arena.make_crowd("packed", screen)


func layout() -> void:
	screen = get_viewport_rect().size
	floor_y = screen.y * 0.68
	buttons = Controls.make_buttons(screen, ["GADGET 1", "GADGET 2", "GADGET 3"], pads)
	# toolbar along the top
	var n := TOOLS.size()
	var gap := 8.0
	var bw := minf(150.0, (screen.x - 40.0 - gap * (n - 1)) / n)
	var x := (screen.x - (bw * n + gap * (n - 1))) * 0.5
	tool_rects.clear()
	for t in TOOLS:
		tool_rects[t] = Rect2(x, 12.0, bw, 50.0)
		x += bw + gap


func _process(delta: float) -> void:
	clock += delta
	flash_t = maxf(0.0, flash_t - delta)
	var old := screen
	screen = get_viewport_rect().size
	if old != screen:
		layout()
	queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			press(event.position, event.index)
		elif event.index == drag_id:
			release()
	elif event is InputEventScreenDrag:
		if event.index == drag_id:
			drag(event.position)
	elif not touch_device:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press(event.position, -1)
			else:
				release()
		elif event is InputEventMouseMotion and drag_id == -1:
			drag(event.position)


func press(p: Vector2, id: int) -> void:
	for t in tool_rects:
		if (tool_rects[t] as Rect2).has_point(p):
			use_tool(t)
			return
	# topmost button under the finger (generous hit area so small buttons are easy to grab)
	for k in range(buttons.size() - 1, -1, -1):
		var b: Dictionary = buttons[k]
		if p.distance_to(b["pos"]) <= maxf(b["r"], 30.0):
			selected = b["name"]
			dragging = b["name"]
			drag_offset = b["pos"] - p
			drag_id = id
			Sfx.play("click")
			return
	selected = ""


func drag(p: Vector2) -> void:
	if dragging == "":
		return
	var b := find(dragging)
	if b.is_empty():
		return
	var r: float = b["r"]
	b["pos"] = Vector2(clampf(p.x + drag_offset.x, r * 0.5, screen.x - r * 0.5), clampf(p.y + drag_offset.y, 70.0 + r * 0.5, screen.y - r * 0.5))


func release() -> void:
	if dragging != "":
		var b := find(dragging)
		if not b.is_empty():
			Controls.store(dragging, pads, b["pos"], Controls.size_factor(dragging, pads), screen)
			GameData.save_settings()
	dragging = ""
	drag_id = -99


func find(button_name: String) -> Dictionary:
	for b in buttons:
		if b["name"] == button_name:
			return b
	return {}


func resize(button_name: String, change: float) -> void:
	var b := find(button_name)
	if b.is_empty():
		return
	Controls.store(button_name, pads, b["pos"], Controls.size_factor(button_name, pads) + change, screen)


func use_tool(t: String) -> void:
	Sfx.play("click")
	match t:
		"smaller", "bigger":
			if selected == "":
				say("Tap a button first")
				return
			resize(selected, STEP if t == "bigger" else -STEP)
		"all_smaller", "all_bigger":
			for b in buttons:
				resize(b["name"], STEP if t == "all_bigger" else -STEP)
		"pads":
			pads = pads % 3 + 1
			selected = ""
			say("Editing the layout for %s" % ["one robot", "a team of 2 (split controls)", "a team of 3 (split controls)"][pads - 1])
		"reset":
			Controls.reset(pads)
			say("Back to the default layout")
		"done":
			GameData.save_settings()
			get_tree().change_scene_to_file("res://settings.tscn")
			return
	GameData.save_settings()
	layout()


func say(text: String) -> void:
	flash = text
	flash_t = 2.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var arena_id := "harbor"
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.07, 0.11))
	Arena.draw_backdrop(self, arena_id, screen, floor_y, clock, Vector2.ZERO)
	Arena.draw_crowd(self, crowd, "packed", screen, clock, 0.0, Vector2.ZERO)
	Arena.draw_floor(self, arena_id, screen, floor_y, clock, Vector2.ZERO)
	var wl := screen.x * 0.07
	var wr := screen.x * 0.93
	for k in 3:
		var y := floor_y - 70.0 - k * 50.0
		draw_line(Vector2(wl, y), Vector2(wr, y), Color(0.9, 0.9, 0.95, 0.6), 4.0)
	# the two robots, where they stand when a fight starts
	RobotArt.draw(self, Vector2(screen.x * 0.3, floor_y), player_look, {"facing": 1, "time": clock})
	RobotArt.draw(self, Vector2(screen.x * 0.7, floor_y), enemy_look, {"facing": -1, "time": clock})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in buttons:
		var sel: bool = b["name"] == selected
		var gadget := str(b["name"]).begins_with("gadget")
		var col := Color(0.4, 0.8, 1.0) if gadget else Color.WHITE
		draw_circle(b["pos"], b["r"], Color(1.0, 0.8, 0.2, 0.35) if sel else Color(col.r, col.g, col.b, 0.14))
		draw_arc(b["pos"], b["r"], 0.0, TAU, 40, Color(1.0, 0.8, 0.2) if sel else Color(col.r, col.g, col.b, 0.6), 4.0 if sel else 2.0)
		var size := 21 if str(b["label"]).length() <= 5 else 17
		size = int(size * clampf(b["r"] / 70.0, 0.6, 1.3))
		draw_string(font, b["pos"] + Vector2(-b["r"] - 10, size * 0.35), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0 + 20, size, Color(col.r, col.g, col.b, 0.9))

	for t in TOOLS:
		var r: Rect2 = tool_rects[t]
		var label: String = "%d PAD%s" % [pads, "" if pads == 1 else "S"] if t == "pads" else TOOL_LABELS[t]
		var on: bool = t == "done" or ((t == "smaller" or t == "bigger") and selected != "")
		draw_rect(r, Color(0.1, 0.1, 0.14, 0.85))
		draw_rect(r, Color(1.0, 0.45, 0.2) if t == "done" else (Color(1, 1, 1, 0.7) if on or not t in ["smaller", "bigger"] else Color(1, 1, 1, 0.3)), false, 2.0)
		draw_string(font, r.position + Vector2(0, 33), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE)

	var hint := "Drag a button to move it. Tap one, then SMALLER / BIGGER to resize it."
	if selected != "":
		hint = "%s: size %d%%" % [find(selected).get("label", selected), int(round(Controls.size_factor(selected, pads) * 100))]
	if flash_t > 0.0:
		hint = flash
	draw_string(font, Vector2(0, 96), hint, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 22, Color(1, 1, 1, 0.9))
