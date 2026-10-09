extends Control
## A little window that loops one special move: your robot does it on a training dummy, over and
## over (the fight scene in demo mode, rendered off-screen). Used by the Style popup and the Moves tab.

const FightScene = preload("res://fight.tscn")

var move := ""
var res := Vector2i(640, 360)   # (1.93) inline demos in lists render smaller
var sv: SubViewport
var tex: TextureRect
var fight: Node


func _ready() -> void:
	clip_contents = true
	sv = SubViewport.new()
	sv.size = res
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
	if move != "":
		_start()


func show_move(id: String) -> void:
	if id == move and fight != null:
		return
	move = id
	if is_inside_tree():
		_start()


func _start() -> void:
	if fight != null:
		fight.queue_free()
		fight = null
	if move == "":
		return
	fight = FightScene.instantiate()
	fight.demo_move = move
	sv.add_child(fight)
