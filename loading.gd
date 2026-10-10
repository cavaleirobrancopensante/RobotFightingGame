extends CanvasLayer
const PlayLog = preload("res://playlog.gd")   # (1.87) the playtest log
## Scene changes go through here: Loading.go("res://garage.tscn").
## A loading cover (LOADING... and a block bar) shows only when the scene is slow to open: the
## first time a heavy scene loads, or whenever it took a noticeable moment last time. Quick
## changes stay instant.

const UI = preload("res://ui.gd")
const I18n = preload("res://i18n.gd")
const SLOW := 0.2                 # seconds: anything slower than this gets the cover next time
const HEAVY := ["res://garage.tscn", "res://fight.tscn"]   # covered the first time, until we know better

var took := {}                    # path -> seconds it took last time
var cover: Control
var bar
var title_label: Label
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
	cover = Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.visible = false
	add_child(cover)
	var parts := build_screen(cover)
	title_label = parts[0]
	bar = parts[1]


## (1.115) The loading screen, the same everywhere (the boot screen too): the splash picture, and
## LOADING with a yellow block bar on a dark plate over its hazard band. Returns [title, bar].
func build_screen(parent: Control) -> Array:
	var GUI = load("res://garage_ui.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var pic := TextureRect.new()
	pic.texture = load("res://store/splash.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	var plate := PanelContainer.new()
	var ps: StyleBoxFlat = GUI.box(Color(0.04, 0.045, 0.06, 0.92), 12, 10)
	ps.border_color = Color(0.25, 0.25, 0.3)
	ps.set_border_width_all(2)
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	plate.add_theme_stylebox_override("panel", ps)
	plate.anchor_left = 0.2
	plate.anchor_right = 0.8
	plate.anchor_top = 1.0
	plate.anchor_bottom = 1.0
	plate.offset_top = -100.0
	plate.offset_bottom = -14.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(col)
	var title := Label.new()
	title.text = I18n.t("LOADING...")
	title.add_theme_font_override("font", GUI.stencil())
	title.add_theme_font_size_override("font_size", UI.tsz(20))
	title.add_theme_color_override("font_color", GUI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var b = GUI.BlockBar.new()   # loading fills up in blocks, like every other bar
	b.custom_minimum_size = Vector2(0, 22)
	b.height = 20.0
	b.n = 25
	b.color = GUI.YELLOW
	col.add_child(b)
	return [title, b]


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


## Cover the screen while something slow runs right here (a new game builds the whole world):
## LOADING... shows first, then the work runs, then the cover goes. await Loading.run(work)
func run(work: Callable) -> void:
	if busy:
		return
	busy = true
	title_label.text = I18n.t("LOADING...")
	bar.set_fill(6.0)
	cover.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	work.call()
	bar.set_fill(25.0)
	await get_tree().process_frame
	cover.visible = false
	busy = false


func go(path: String) -> void:
	PlayLog.add("scene", path.get_file())
	PlayLog.flush()   # (1.115) on disk before the new scene, in case it never arrives
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
	title_label.text = I18n.t("LOADING...")
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
