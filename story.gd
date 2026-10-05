extends Control
## Story screen: shows the scene in GameData.story_key line by line, then goes to GameData.story_return.
## Tap to reveal / advance. "Skip" jumps to the end.

const CHARS_PER_SEC := 55.0

var lines: Array = []
var index := 0
var shown := 0.0
var talk_timer := 0.0
var place_label: Label
var name_label: Label
var text_label: Label
var hint_label: Label
var portrait: Portrait
var skip_button: Button
var last_tap := 0


class Portrait extends Control:
	## Simple drawn faces for the humans; ECHO is drawn as the player's robot.
	var who := ""
	var robot_look := {}
	var t := 0.0
	var talking := false

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.17))
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		var mouth := 4.0 + (6.0 * absf(sin(t * 18.0)) if talking else 0.0)
		match who:
			"ECHO":
				var g := RobotArt.geom(robot_look)
				var tall: float = -(g["head"] as Rect2).position.y + 30.0
				RobotArt.draw(self, Vector2(c.x, size.y - 10.0), robot_look, {"scale": (size.y - 20.0) / tall, "time": t})
			"GUS":
				draw_circle(c, r, Color(0.42, 0.27, 0.18))
				draw_rect(Rect2(c.x - r * 1.1, c.y - r * 1.05, r * 2.2, r * 0.5), Color(0.2, 0.3, 0.45))   # cap
				draw_rect(Rect2(c.x - r * 0.2, c.y - r * 0.65, r * 1.5, r * 0.18), Color(0.2, 0.3, 0.45))
				draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_circle(c + Vector2(0, r * 0.55), r * 0.55, Color(0.75, 0.75, 0.75))   # beard
				draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.35, r * 0.6, mouth), Color(0.2, 0.1, 0.08))
				draw_rect(Rect2(c.x + r * 0.9, c.y + r * 0.9, r * 0.5, r * 0.9), Color(0.6, 0.6, 0.65))  # robot arm
			"KANE":
				draw_circle(c + Vector2(0, -r * 0.15), r * 1.05, Color(0.08, 0.08, 0.1))  # hair
				draw_circle(c, r * 0.85, Color(0.93, 0.8, 0.72))
				draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.9, r * 1.9, r * 0.5), Color(0.08, 0.08, 0.1))
				draw_line(c + Vector2(-r * 0.5, -r * 0.15), c + Vector2(-r * 0.15, -r * 0.05), Color.BLACK, 3.0)
				draw_line(c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.15, -r * 0.05), Color.BLACK, 3.0)
				draw_rect(Rect2(c.x - r * 0.25, c.y + r * 0.35, r * 0.5, mouth * 0.7), Color(0.75, 0.1, 0.2))
				draw_rect(Rect2(c.x - r * 1.2, c.y + r * 0.95, r * 2.4, r), Color(0.15, 0.15, 0.2))  # suit
			"YOU":
				draw_face(GameData.pilot_look, c, r, mouth)
			"ANNOUNCER":
				draw_circle(c, r, Color(0.85, 0.65, 0.5))
				draw_rect(Rect2(c.x - r, c.y - r * 1.05, r * 2.0, r * 0.45), Color(0.1, 0.1, 0.1))
				draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_rect(Rect2(c.x - r * 0.35, c.y + r * 0.3, r * 0.7, mouth * 1.2), Color(0.3, 0.05, 0.05))
				draw_rect(Rect2(c.x + r * 0.6, c.y + r * 0.4, r * 0.15, r * 0.9), Color(0.2, 0.2, 0.2))  # mic
				draw_circle(c + Vector2(r * 0.68, r * 0.35), r * 0.2, Color(0.5, 0.5, 0.55))
				draw_rect(Rect2(c.x - r * 1.1, c.y + r * 0.95, r * 2.2, r), Color(0.6, 0.1, 0.15))
			_:
				var face: Dictionary = Story.SPEAKERS.get(who, {}).get("face", {})
				if face.is_empty():
					draw_string(ThemeDB.fallback_font, Vector2(0, c.y + 20), "...", HORIZONTAL_ALIGNMENT_CENTER, size.x, 60, Color(0.5, 0.5, 0.55))
				else:
					draw_face(face, c, r, mouth)

	## Rival pilots: a face built from a few traits in Story.SPEAKERS.
	func draw_face(f: Dictionary, c: Vector2, r: float, mouth: float) -> void:
		var skin := Color(f.get("skin", "#c8946e"))
		var hair := Color(f.get("hair", "#2a1d14"))
		var outfit := Color(f.get("outfit", "#34495e"))
		var twin: bool = f.get("twin", false)
		var centers: Array = [c] if not twin else [c + Vector2(-r * 0.62, r * 0.1), c + Vector2(r * 0.62, -r * 0.05)]
		var rr := r if not twin else r * 0.62
		for cc in centers:
			draw_rect(Rect2(cc.x - rr * 1.1, cc.y + rr * 0.95, rr * 2.2, rr), outfit)
			if f.get("long_hair", false):
				draw_rect(Rect2(cc.x - rr * 1.05, cc.y - rr * 0.6, rr * 2.1, rr * 1.4), hair)
			draw_circle(cc, rr, skin)
			match str(f.get("hat", "")):
				"cap":
					draw_rect(Rect2(cc.x - rr * 1.05, cc.y - rr * 1.05, rr * 2.1, rr * 0.5), hair)
					draw_rect(Rect2(cc.x - rr * 0.2, cc.y - rr * 0.65, rr * 1.4, rr * 0.16), hair)
				"beanie":
					draw_rect(Rect2(cc.x - rr, cc.y - rr * 1.05, rr * 2.0, rr * 0.6), hair)
				"mohawk":
					draw_rect(Rect2(cc.x - rr * 0.18, cc.y - rr * 1.6, rr * 0.36, rr * 0.8), hair)
				"helmet":
					draw_arc(cc, rr * 1.05, PI, TAU, 16, hair, rr * 0.35)
				"bun":
					draw_circle(cc + Vector2(0, -rr * 1.05), rr * 0.35, hair)
					draw_rect(Rect2(cc.x - rr, cc.y - rr * 1.0, rr * 2.0, rr * 0.35), hair)
				"bald":
					pass
				_:
					draw_rect(Rect2(cc.x - rr, cc.y - rr * 1.0, rr * 2.0, rr * 0.4), hair)
			draw_circle(cc + Vector2(-rr * 0.35, -rr * 0.08), rr * 0.1, Color.WHITE)
			draw_circle(cc + Vector2(rr * 0.35, -rr * 0.08), rr * 0.1, Color.WHITE)
			if f.get("glasses", false):
				draw_arc(cc + Vector2(-rr * 0.35, -rr * 0.08), rr * 0.2, 0, TAU, 12, Color(0.1, 0.1, 0.1), 2.0)
				draw_arc(cc + Vector2(rr * 0.35, -rr * 0.08), rr * 0.2, 0, TAU, 12, Color(0.1, 0.1, 0.1), 2.0)
			if f.get("goggles", false):
				draw_rect(Rect2(cc.x - rr * 0.75, cc.y - rr * 0.3, rr * 1.5, rr * 0.4), Color(0.2, 0.5, 0.6, 0.85))
			if f.get("beard", false):
				draw_circle(cc + Vector2(0, rr * 0.55), rr * 0.5, hair.lightened(0.15))
			if f.get("scar", false):
				draw_line(cc + Vector2(rr * 0.15, -rr * 0.5), cc + Vector2(rr * 0.6, rr * 0.2), Color(0.6, 0.25, 0.2), 3.0)
			draw_rect(Rect2(cc.x - rr * 0.25, cc.y + rr * 0.38, rr * 0.5, mouth * (0.7 if not twin else 0.45)), Color(0.25, 0.08, 0.06))


func _ready() -> void:
	Sfx.music("anthem" if GameData.story_key == "post_9" else "story")
	var scene: Dictionary = Story.SCENES.get(GameData.story_key, {"place": "", "lines": []})
	lines = scene["lines"]
	UI.background(self)
	var m := UI.margin(self, 24)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	place_label = UI.label(scene["place"], 26, Color(1.0, 0.45, 0.2))
	place_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(place_label)
	skip_button = UI.button("Skip", _finish, 22, Vector2(120, 50))
	top.add_child(skip_button)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(260, 260)
	portrait.robot_look = GameData.player_look()
	row.add_child(portrait)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)
	name_label = UI.label("", 34)
	box.add_child(name_label)
	text_label = UI.label("", 30)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)

	hint_label = UI.label("Tap to continue", 20, Color(0.6, 0.6, 0.65))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint_label)

	if lines.is_empty():
		_finish.call_deferred()
		return
	show_line()


func show_line() -> void:
	var who: String = lines[index][0]
	var info: Dictionary = Story.SPEAKERS.get(who, {"color": "#ffffff"})
	var shown_name := who
	if who == "YOU":
		shown_name = GameData.pilot_name.to_upper()
	elif who == "ECHO":
		shown_name = GameData.robot_name
	name_label.text = "" if who == "NARRATOR" else shown_name
	name_label.add_theme_color_override("font_color", Color(info["color"]))
	# the story was written for ECHO: use whatever the player named their robot
	text_label.text = str(lines[index][1]).replace("ECHO", GameData.robot_name)
	text_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8) if who == "NARRATOR" else Color.WHITE)
	text_label.visible_characters = 0
	shown = 0.0
	portrait.who = who
	portrait.visible = who != "NARRATOR"


func _process(delta: float) -> void:
	if lines.is_empty() or index >= lines.size():
		return
	var total := text_label.get_total_character_count()
	if text_label.visible_characters < total:
		shown += delta * CHARS_PER_SEC
		text_label.visible_characters = int(shown)
		portrait.talking = true
		talk_timer -= delta
		if talk_timer <= 0.0:
			talk_timer = 0.07
			var who: String = lines[index][0]
			if who != "NARRATOR":
				Sfx.play("talk_robot" if Story.SPEAKERS.get(who, {}).get("robot", false) else "talk", 0.15, -6.0)
	else:
		portrait.talking = false
	hint_label.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)


func _input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
		pos = Vector2.ZERO
	else:
		return
	if skip_button.get_global_rect().has_point(pos):
		return   # the Skip button handles itself
	# a phone tap arrives as both a touch and a mouse click: only count it once
	var now := Time.get_ticks_msec()
	if now - last_tap < 200:
		return
	last_tap = now
	advance()


func advance() -> void:
	if index >= lines.size():
		return
	if text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters = -1
		shown = 9999.0
		return
	index += 1
	if index >= lines.size():
		_finish()
	else:
		show_line()


func _finish() -> void:
	if index > lines.size():
		return
	index = lines.size() + 1
	GameData.mark_story_seen(GameData.story_key)
	GameData.save_game()
	var target := GameData.story_return if GameData.story_return != "" else "res://garage.tscn"
	get_tree().change_scene_to_file(target)
