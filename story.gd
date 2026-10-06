extends Control

# helper scripts, loaded by path so the game also runs without an editor scan
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")
const Story = preload("res://story_data.gd")
const UI = preload("res://ui.gd")
const GarageArt = preload("res://garage_art.gd")
## Story screen: shows the scene in GameData.story_key line by line, then goes to GameData.story_return.
## Tap to reveal / advance. "Skip" jumps to the end.

const CHARS_PER_SEC := 55.0
const SCREEN_CHARS := 300   # one speaker's lines share a screen up to about five lines of text

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
var trophy_view: TrophyPic


## A trophy shown under the text while someone talks about it (line extra {"trophy": kind}).
class TrophyPic extends Control:
	var kind := "scrap"
	var medal := 1
	func _draw() -> void:
		var s := size.y / 46.0
		draw_circle(Vector2(size.x * 0.5, size.y * 0.55), size.y * 0.5, Color(1.0, 0.9, 0.6, 0.07))
		GarageArt.draw_trophy(self, Vector2(size.x * 0.5, size.y - 4.0), kind, medal, s)


class Portrait extends Control:
	## Simple drawn faces for the humans; ECHO is drawn as the player's robot.
	var who := ""
	var face_look := {}      # a world pilot's face (emergent talk), when they aren't in Story.SPEAKERS
	var place := ""          # where the scene is: the announcer dresses for the venue
	var robot_look := {}
	var t := 0.0
	var talking := false

	var _redraw_t := 0.0

	func _process(delta: float) -> void:
		t += delta
		_redraw_t -= delta
		if _redraw_t <= 0.0 and is_visible_in_tree():
			_redraw_t = 1.0 / 30.0   # 30 fps is plenty for a little animated icon
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
				# work shirt and overalls, with the Kane-built robot arm on his right
				draw_rect(Rect2(c.x - r * 1.25, c.y + r * 0.8, r * 2.5, size.y - c.y - r * 0.8), Color(0.55, 0.42, 0.3))
				draw_rect(Rect2(c.x - r * 0.8, c.y + r * 1.25, r * 1.6, size.y - c.y - r * 1.25), Color(0.2, 0.3, 0.45))
				draw_line(c + Vector2(-r * 0.6, r * 0.85), c + Vector2(-r * 0.6, r * 1.35), Color(0.2, 0.3, 0.45), r * 0.18)
				draw_line(c + Vector2(r * 0.6, r * 0.85), c + Vector2(r * 0.6, r * 1.35), Color(0.2, 0.3, 0.45), r * 0.18)
				draw_circle(c + Vector2(-r * 0.6, r * 1.3), r * 0.08, Color(0.85, 0.75, 0.3))
				draw_circle(c + Vector2(r * 0.6, r * 1.3), r * 0.08, Color(0.85, 0.75, 0.3))
				draw_rect(Rect2(c.x - r * 0.35, c.y + r * 1.55, r * 0.7, r * 0.45), Color(0.17, 0.26, 0.4))   # bib pocket
				draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.7, r * 0.6, r * 0.3), Color(0.42, 0.27, 0.18))     # neck
				draw_circle(c, r, Color(0.42, 0.27, 0.18))
				draw_rect(Rect2(c.x - r * 1.1, c.y - r * 1.05, r * 2.2, r * 0.5), Color(0.2, 0.3, 0.45))   # cap
				draw_rect(Rect2(c.x - r * 0.2, c.y - r * 0.65, r * 1.5, r * 0.18), Color(0.2, 0.3, 0.45))
				draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_circle(c + Vector2(0, r * 0.55), r * 0.55, Color(0.75, 0.75, 0.75))   # beard
				draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.35, r * 0.6, mouth), Color(0.2, 0.1, 0.08))
				draw_rect(Rect2(c.x + r * 1.05, c.y + r * 0.9, r * 0.45, r * 1.5), Color(0.6, 0.6, 0.65))   # robot arm
				draw_circle(c + Vector2(r * 1.27, r * 0.95), r * 0.24, Color(0.45, 0.45, 0.5))
				draw_circle(c + Vector2(r * 1.27, r * 1.65), r * 0.12, Color(1.0, 0.6, 0.2))
				draw_rect(Rect2(c.x - r * 1.5, c.y + r * 0.9, r * 0.45, r * 1.5), Color(0.55, 0.42, 0.3))    # flesh arm, sleeve
			"KANE":
				draw_circle(c + Vector2(0, -r * 0.15), r * 1.05, Color(0.08, 0.08, 0.1))  # hair
				draw_circle(c, r * 0.85, Color(0.93, 0.8, 0.72))
				draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.9, r * 1.9, r * 0.5), Color(0.08, 0.08, 0.1))
				draw_line(c + Vector2(-r * 0.5, -r * 0.15), c + Vector2(-r * 0.15, -r * 0.05), Color.BLACK, 3.0)
				draw_line(c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.15, -r * 0.05), Color.BLACK, 3.0)
				draw_rect(Rect2(c.x - r * 0.25, c.y + r * 0.35, r * 0.5, mouth * 0.7), Color(0.75, 0.1, 0.2))
				draw_rect(Rect2(c.x - r * 1.2, c.y + r * 0.95, r * 2.4, r), Color(0.15, 0.15, 0.2))  # suit
				for side in [-1.0, 1.0]:
					draw_arc(c + Vector2(side * r * 0.45, r * 1.25), r * 0.32, PI * 0.15, PI * 0.85, 10, Color(0.06, 0.06, 0.09), maxf(1.5, r * 0.06))
			"YOU":
				draw_face(GameData.pilot_look, c, r, mouth)
				PilotArt.draw_controller(self, c + Vector2(0, r * 1.45), r / 14.0, str(GameData.pilot_look.get("controller", "gamepad")), talking, t)
			"ANNOUNCER" when place.contains("SCRAP"):
				# the scrap heap's announcer: sunburnt, stubbled, bandana, sleeveless vest, a dented megaphone
				draw_rect(Rect2(c.x - r * 1.15, c.y + r * 0.9, r * 2.3, r * 1.1), Color(0.36, 0.38, 0.22))   # vest
				draw_rect(Rect2(c.x - r * 1.45, c.y + r * 0.95, r * 0.35, r * 0.9), Color(0.72, 0.48, 0.34))  # bare arms
				draw_rect(Rect2(c.x + r * 1.1, c.y + r * 0.95, r * 0.35, r * 0.9), Color(0.72, 0.48, 0.34))
				draw_circle(c, r, Color(0.72, 0.48, 0.34))
				for k in 14:   # stubble
					var a := PI * (0.15 + 0.7 * k / 13.0)
					draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.78, r * 0.035, Color(0.2, 0.15, 0.12))
				draw_rect(Rect2(c.x - r * 1.05, c.y - r * 1.0, r * 2.1, r * 0.42), Color(0.75, 0.15, 0.12))  # bandana
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.9, -r * 0.8), c + Vector2(r * 1.4, -r * 0.5), c + Vector2(r * 1.2, -r * 0.2)]), Color(0.75, 0.15, 0.12))
				draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.1, Color.WHITE)
				draw_line(c + Vector2(r * 0.15, -r * 0.12), c + Vector2(r * 0.55, -r * 0.08), Color(0.25, 0.15, 0.1), r * 0.1)   # squint
				draw_line(c + Vector2(r * 0.1, -r * 0.45), c + Vector2(r * 0.6, r * 0.15), Color(0.55, 0.3, 0.25), 2.0)          # scar
				draw_rect(Rect2(c.x - r * 0.4, c.y + r * 0.3, r * 0.8, mouth * 1.3), Color(0.3, 0.05, 0.05))
				# the megaphone
				var mp := c + Vector2(r * 1.05, r * 0.45)
				draw_colored_polygon(PackedVector2Array([mp, mp + Vector2(r * 0.9, -r * 0.45), mp + Vector2(r * 0.9, r * 0.55), mp + Vector2(0, r * 0.2)]), Color(0.85, 0.7, 0.2))
				draw_rect(Rect2(mp + Vector2(-r * 0.25, r * 0.05), Vector2(r * 0.3, r * 0.15)), Color(0.3, 0.3, 0.3))
			"ANNOUNCER" when place.contains("KANE") or place.contains("GRAND"):
				# the Championship's announcer: tuxedo, bow tie, silver slicked hair, a gold microphone
				draw_rect(Rect2(c.x - r * 1.2, c.y + r * 0.9, r * 2.4, r * 1.1), Color(0.07, 0.07, 0.09))     # jacket
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, r * 0.9), c + Vector2(r * 0.4, r * 0.9), c + Vector2(0, r * 1.7)]), Color(0.95, 0.95, 0.95))   # shirt
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.95), c + Vector2(0, r * 1.05), c + Vector2(-r * 0.3, r * 1.15)]), Color(0.6, 0.05, 0.1))   # bow tie
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.3, r * 0.95), c + Vector2(0, r * 1.05), c + Vector2(r * 0.3, r * 1.15)]), Color(0.6, 0.05, 0.1))
				draw_circle(c, r, Color(0.92, 0.78, 0.66))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.2), c + Vector2(-r * 0.9, -r * 0.9), c + Vector2(0, -r * 1.15),
						c + Vector2(r * 0.95, -r * 0.8), c + Vector2(r, -r * 0.3), c + Vector2(r * 0.3, -r * 0.7)]), Color(0.78, 0.8, 0.84))   # slicked hair
				draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.09, Color(0.2, 0.2, 0.25))
				draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.09, Color(0.2, 0.2, 0.25))
				draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.35, r * 0.6, mouth), Color(0.45, 0.1, 0.1))
				draw_rect(Rect2(c.x + r * 0.62, c.y + r * 0.42, r * 0.12, r * 0.8), Color(0.75, 0.6, 0.2))   # gold mic
				draw_circle(c + Vector2(r * 0.68, r * 0.35), r * 0.19, Color(0.95, 0.8, 0.3))
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
				var face: Dictionary = Story.SPEAKERS.get(who, {}).get("face", face_look)
				if face.is_empty():
					draw_string(ThemeDB.fallback_font, Vector2(0, c.y + 20), "...", HORIZONTAL_ALIGNMENT_CENTER, size.x, 60, Color(0.5, 0.5, 0.55))
				else:
					draw_face(face, c, r, mouth)

	## Rival pilots: a face built from a few traits in Story.SPEAKERS.
	func draw_face(f: Dictionary, c: Vector2, r: float, mouth: float) -> void:
		var outfit := Color(f.get("outfit", "#34495e"))
		var twin: bool = f.get("twin", false)
		var centers: Array = [c] if not twin else [c + Vector2(-r * 0.62, r * 0.1), c + Vector2(r * 0.62, -r * 0.05)]
		var rr := r if not twin else r * 0.62
		for cc in centers:
			draw_rect(Rect2(cc.x - rr * 1.1, cc.y + rr * 0.95, rr * 2.2, rr), outfit)
			if f.get("female", false):
				for side in [-1.0, 1.0]:
					draw_arc(cc + Vector2(side * rr * 0.45, rr * 1.25), rr * 0.32, PI * 0.15, PI * 0.85, 10, outfit.darkened(0.45), maxf(1.5, rr * 0.06))
			PilotArt.draw_head(self, cc, rr, f, 0.0, mouth * (0.7 if not twin else 0.45))


func _ready() -> void:
	Sfx.music("anthem" if GameData.story_key == "post_9" else "story")
	var scene: Dictionary = Story.SCENES.get(GameData.story_key, {"place": "", "lines": []})
	lines = build_screens(scene["lines"])
	for l in lines:
		GameData.log_talk(str(l[0]), str(l[1]), "story")
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
	portrait.place = str(scene.get("place", ""))
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
	trophy_view = TrophyPic.new()
	trophy_view.custom_minimum_size = Vector2(0, 170)
	trophy_view.visible = false
	box.add_child(trophy_view)

	hint_label = UI.label("Tap to continue", 20, Color(0.6, 0.6, 0.65))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint_label)

	if lines.is_empty():
		_finish.call_deferred()
		return
	show_line()


## Lines -> screens: translated, with lines that depend on your game ({RENT_INTRO}...) filled in,
## and a speaker's lines in a row sharing one screen (so there's less tapping).
func build_screens(raw: Array) -> Array:
	var out: Array = []
	for l in raw:
		var who: String = l[0]
		var text := str(l[1])
		text = GameData.story_dynamic(text.substr(1, text.length() - 2)) if text.begins_with("{") else tr(text)
		text = text.replace("ECHO", GameData.robot_name)
		if text == "":
			continue
		var extra: Dictionary = l[2] if l.size() > 2 else {}
		if not out.is_empty() and out[-1][0] == who and str(out[-1][1]).length() + text.length() < SCREEN_CHARS:
			out[-1][1] = str(out[-1][1]) + " " + text
			if not extra.is_empty():
				out[-1][2] = extra
		else:
			out.append([who, text, extra])
	return out


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
	text_label.text = str(lines[index][1])
	var extra: Dictionary = lines[index][2] if lines[index].size() > 2 else {}
	trophy_view.visible = extra.has("trophy")
	if extra.has("trophy"):
		trophy_view.kind = str(extra["trophy"])
		trophy_view.medal = 1
		for t in GameData.trophies:   # the medal you actually won there
			if str(t.get("kind", "")) == trophy_view.kind:
				trophy_view.medal = int(t.get("medal", 1))
		trophy_view.queue_redraw()
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
				Sfx.voice(who)
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
	# a new game goes straight from the intro into the first fight - the garage comes after
	if not GameData.story_queue.is_empty():
		GameData.story_key = GameData.story_queue.pop_front()
		GameData.save_game()
		Loading.go("res://story.tscn")
		return
	if GameData.story_key == "intro" and GameData.wins + GameData.losses == 0 and GameData.rank == "open":
		# a new game: a few words, then straight into a coached pickup fight. The bay comes after.
		GameData.start_first_fight()
		if GameData.queue_story("first_fight", "res://fight.tscn"):
			GameData.save_game()
			Loading.go("res://story.tscn")
			return
	if GameData.story_key == "intro" and GameData.wins + GameData.losses == 0 and GameData.current_opponent_index() == 0 \
			and GameData.queue_story("pre_0", "res://fight.tscn"):
		GameData.save_game()
		Loading.go("res://story.tscn")
		return
	GameData.save_game()
	var target := GameData.story_return if GameData.story_return != "" else "res://garage.tscn"
	Loading.go(target)
