extends CanvasLayer
## Scene changes go through here: Loading.go("res://garage.tscn").
## A loading cover (LOADING... and a block bar) shows only when the scene is slow to open: the
## first time a heavy scene loads, or whenever it took a noticeable moment last time. Quick
## changes stay instant.

const UI = preload("res://ui.gd")
const I18n = preload("res://i18n.gd")
const SLOW := 0.2                 # seconds: anything slower than this gets the cover next time
const HEAVY := ["res://garage.tscn", "res://fight.tscn"]   # covered the first time, until we know better

var took := {}                    # path -> seconds it took last time
var cover: ColorRect
var bar
var busy := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	# phones: full screen hides the back / home / apps buttons (they slide back in with a swipe)
	if OS.get_name() == "Android":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	base_size = get_tree().root.content_scale_size
	get_tree().root.size_changed.connect(apply_edges)
	apply_edges.call_deferred()
	cover = ColorRect.new()
	cover.color = Color(0.07, 0.07, 0.1, 0.97)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.visible = false
	add_child(cover)
	var title := UI.label(I18n.t("LOADING..."), 30, Color(1.0, 0.45, 0.2))
	title.name = "Title"
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.42
	title.anchor_bottom = 0.42
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(title)
	bar = load("res://garage_ui.gd").BlockBar.new()   # loading fills up in blocks, like every other bar
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


# ---------------------------------------------------------------- screen edges
## Settings > Screen edges: for phones whose buttons never hide, the game shrinks a little and
## leaves dark bars down both sides. 0 = off, 1-3 = small, medium, large.
const EDGE_SIDE := [0.0, 0.035, 0.06, 0.09]   # share of the screen width kept free on each side
var base_size := Vector2i(1152, 648)


func apply_edges() -> void:
	var root := get_tree().root
	var lvl := clampi(int(GameData.settings.get("edges", 0)), 0, EDGE_SIDE.size() - 1)
	if lvl == 0:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_size = base_size
		return
	var screen := Vector2(DisplayServer.window_get_size())
	if screen.y <= 0.0:
		return
	var w := float(base_size.y) * screen.x / screen.y * (1.0 - 2.0 * float(EDGE_SIDE[lvl]))
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(int(w), base_size.y)


func go(path: String) -> void:
	if busy:
		return
	var slow: bool = float(took.get(path, 1.0 if HEAVY.has(path) else 0.0)) > SLOW
	var t0 := Time.get_ticks_usec()
	if not slow:
		get_tree().change_scene_to_file(path)
		await get_tree().process_frame
		await get_tree().process_frame
		took[path] = (Time.get_ticks_usec() - t0) / 1000000.0
		return
	busy = true
	(cover.get_node("Title") as Label).text = I18n.t("LOADING...")
	bar.set_fill(0.0)
	cover.visible = true
	# let the cover draw before the heavy work starts
	await get_tree().process_frame
	await get_tree().process_frame
	t0 = Time.get_ticks_usec()
	ResourceLoader.load_threaded_request(path)
	var progress: Array = []
	var packed: PackedScene = null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(path)
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		bar.set_fill(float(progress[0]) * 15.0 if not progress.is_empty() else 0.0)
		await get_tree().process_frame
	bar.set_fill(17.0)
	await get_tree().process_frame
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)
	# the new scene builds itself (its _ready) on the next frame: keep the cover up until it has
	await get_tree().process_frame
	bar.set_fill(25.0)
	await get_tree().process_frame
	took[path] = (Time.get_ticks_usec() - t0) / 1000000.0
	cover.visible = false
	busy = false
