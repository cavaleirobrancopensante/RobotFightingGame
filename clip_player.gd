extends Control
## (1.74) Plays a clip (clips.gd): the fight scene in replay mode, drawn off screen at the size the
## fight was recorded at and shown here scaled to fit. Loops; controls() gives the buttons under
## it (sound on / off, x1 / x2, Again, Close).

const FightScene = preload("res://fight.tscn")
const UI = preload("res://ui.gd")

var clip := {}
var sv: SubViewport
var tex: TextureRect
var fight: Node
var muted := false
var fast := false
var playlist: Array = []   # (1.76) more than one: each plays once, then the next (the Rusty Bolt's TV)
var pi := 0
var loop := false          # (1.87) the TV: go round forever
var lowres := false        # (1.76) drawn at a third of the size (a small screen doesn't need more)


func _ready() -> void:
	clip_contents = true
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 180)
	sv = SubViewport.new()
	if clip.is_empty() and not playlist.is_empty():
		clip = playlist[0]
	_size_sv()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.gui_disable_input = true
	sv.handle_input_locally = true
	add_child(sv)
	tex = TextureRect.new()
	tex.texture = sv.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex)
	restart()


func _size_sv() -> void:
	var scr: Array = clip.get("scr", [1152, 648])
	var full := Vector2i(int(scr[0]), int(scr[1]))
	if lowres:
		sv.size = full / 3
		sv.size_2d_override = full
		sv.size_2d_override_stretch = true
	else:
		sv.size = full


func _process(_d: float) -> void:
	# a playlist moves on when a clip reaches its end
	if playlist.size() > 1 and fight != null and fight.rp_hold > 0.0:
		pi = (pi + 1) % playlist.size()
		clip = playlist[pi]
		_size_sv()
		restart()


## (1.87) A single clip plays once and stops on its last frame (Again, or a tap, plays it again);
## a playlist (the Rusty Bolt's TV) moves on instead.
func finished() -> bool:
	return fight != null and fight.rp_done


func _gui_input(e: InputEvent) -> void:
	if finished() and ((e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)):
		restart()
		accept_event()


func restart() -> void:
	if fight != null:
		fight.queue_free()
	fight = FightScene.instantiate()
	fight.rp_once = playlist.size() <= 1 and not loop
	fight.replay = clip
	fight.rp_mute = muted
	fight.rp_speed = 2.0 if fast else 1.0
	sv.add_child(fight)


func set_muted(on: bool) -> void:
	muted = on
	if fight:
		fight.rp_mute = on


func set_fast(on: bool) -> void:
	fast = on
	if fight:
		fight.rp_speed = 2.0 if on else 1.0


## The row of buttons that goes under the player.
func controls(on_close: Callable = Callable()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var snd := UI.button("", func(): pass, 14, Vector2(110, 44))
	var spd := UI.button("", func(): pass, 14, Vector2(80, 44))
	var paint := func():
		snd.text = tr("SOUND OFF") if muted else tr("SOUND ON")
		spd.text = "x2" if fast else "x1"
	snd.pressed.connect(func():
		set_muted(not muted)
		paint.call())
	spd.pressed.connect(func():
		set_fast(not fast)
		paint.call())
	paint.call()
	row.add_child(snd)
	row.add_child(spd)
	row.add_child(UI.button(tr("Again"), restart, 14, Vector2(90, 44)))
	if on_close.is_valid():
		row.add_child(UI.button(tr("Close"), on_close, 14, Vector2(90, 44)))
	return row
