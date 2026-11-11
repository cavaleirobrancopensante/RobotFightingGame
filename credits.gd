## (1.153) The credits, after the Titanium Championship's scene. Your robot in your dad's blue and gold
## under a spotlight, the names rolling up, the anthem playing. A tap speeds it up, Esc / Enter / A
## skips; then "The career goes on" and back to the bay (the save carries on: defend the title).
extends Node2D
const UI = preload("res://ui.gd")
const GUI = preload("res://garage_ui.gd")
const RobotArt = preload("res://robot_art.gd")

const SPEED := 46.0          # pixels a second
const FAST := 4.0            # holding a tap / key
const LINES := [
	["big", "ROBOT FIGHTING"],
	["", ""],
	["head", "A GAME BY"],
	["name", "Salgadoido"],
	["", ""],
	["head", "STORY AND DESIGN"],
	["name", "Salgadoido"],
	["head", "CODE, ART AND MUSIC"],
	["name", "Made with Claude"],
	["note", "drawn and composed by the game's own code"],
	["head", "ENGINE"],
	["name", "Godot Engine"],
	["head", "FONTS"],
	["name", "Chakra Petch, Public Sans, VT323, Saira Stencil One"],
	["note", "(SIL Open Font License)"],
	["", ""],
	["head", "THE CAST"],
	["name", "Gus"],
	["name", "Your dad"],
	["name", "ECHO"],
	["name", "Old Pike and FENCEPOST"],
	["name", "Margo, Bruno, Skar, Dr. Voss, Rosa"],
	["name", "Nik & Nat, Bull, Ironside"],
	["name", "Father Tomas, Silas, Magda, Dex"],
	["name", "Captain Wren, Ms. Vale, Haru, Ringmaster Esme"],
	["name", "Lucky Varga"],
	["name", "Kane"],
	["name", "OVERLORD"],
	["", ""],
	["head", "PLAYTESTERS"],
	["name", "Friends in Brazil, America and Ireland"],
	["", ""],
	["head", "IN MEMORY OF EVERY PILOT KANE EVER FIRED"],
	["", ""],
	["big", "THANK YOU FOR PLAYING"],
	["", ""],
	["", ""],
	["end", "The career goes on. Next year the whole Steel League wants your belt."],
]

var y0 := 0.0
var t := 0.0
var fast := false
var done := false
var look := {}


func _ready() -> void:
	Sfx.music("anthem")
	OS.low_processor_usage_mode = false
	# your robot in your dad's blue and gold, every part whole (the opening's repaint)
	look = GameData.look_from_spec(GameData.player_spec()).duplicate(true)
	look.erase("stickers")
	for slot in look.get("parts", {}):
		var p: Dictionary = look["parts"][slot]
		if p.has("shape"):
			p["color"] = Color("#24467a").lightened(0.12) if slot.begins_with("arm") else (Color("#24467a").darkened(0.18) if slot.begins_with("leg") else Color("#24467a"))
			p["health"] = 1.0
			p["alive"] = true
	look["trim"] = Color("#e0b030")
	y0 = get_viewport_rect().size.y + 20.0


func _process(delta: float) -> void:
	t += delta
	y0 -= delta * SPEED * (FAST if fast else 1.0)
	if y0 + height() < get_viewport_rect().size.y * 0.35:
		leave()
	queue_redraw()


func height() -> float:
	var h := 0.0
	for l in LINES:
		h += row_h(str(l[0]))
	return h


func row_h(kind: String) -> float:
	match kind:
		"big": return UI.px(40) + 30.0
		"head": return UI.px(16) + 30.0
		"name": return UI.px(22) + 10.0
		"note": return UI.px(14) + 10.0
		"end": return UI.px(20) + 20.0
	return 34.0


func _draw() -> void:
	var sz := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), GUI.BG)
	# the spotlight and your robot on the left, standing proud
	var c := Vector2(sz.x * 0.22, sz.y * 0.82)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -sz.y * 0.82), c + Vector2(40, -sz.y * 0.82), c + Vector2(150, 0), c + Vector2(-150, 0)]), Color(1.0, 0.92, 0.7, 0.06))
	draw_set_transform(c + Vector2(0, 10), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 150.0, Color(1.0, 0.9, 0.6, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not look.is_empty():
		RobotArt.draw(self, c, look, {"facing": 1, "state": "idle", "time": t, "light": "champ_arena", "entry": "fists_up", "sx": 1.25, "sy": 1.25})
	# the names roll up on the right
	var x := sz.x * 0.42
	var w := sz.x * 0.54
	var y := y0
	for l in LINES:
		var kind := str(l[0])
		var txt := tr(str(l[1]))
		var h := row_h(kind)
		if y > -h and y < sz.y + h:
			match kind:
				"big": draw_string(GUI.stencil(), Vector2(x, y + UI.px(40)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.px(40), GUI.YELLOW)
				"head": draw_string(GUI.headb(), Vector2(x, y + 12.0 + UI.px(16)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.px(16), GUI.HEAD)
				"name": draw_string(GUI.body(), Vector2(x, y + UI.px(22)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.px(22), GUI.TEXT)
				"note": draw_string(GUI.body(), Vector2(x, y + UI.px(14)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.px(14), GUI.MUTED)
				"end": draw_multiline_string(GUI.body(), Vector2(x, y + UI.px(20)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.px(20), -1, GUI.GREEN)
		y += h
	draw_string(GUI.body(), Vector2(0, sz.y - 10.0), tr("Hold to speed up · Esc to skip"), HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 16.0, UI.px(12), GUI.MUTED)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		fast = event.pressed
	elif event is InputEventKey and not event.echo:
		if event.pressed and event.physical_keycode in [KEY_ESCAPE, KEY_ENTER]:
			leave()
		elif event.physical_keycode == KEY_SPACE:
			fast = event.pressed
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		leave()


func on_back() -> void:
	leave()


func leave() -> void:
	if done:
		return
	done = true
	GameData.story_seen.append("credits")
	GameData.save_game()
	Loading.go("res://garage.tscn")
