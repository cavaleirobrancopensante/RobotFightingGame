extends Node
## Draws the store art with the game's own painting code (1.62): the app icon, Android's adaptive
## icon layers, the web app icons, the boot splash and a store feature graphic. Run it as an
## autoload in a copy of the project (it saves PNGs to OUT, default the project's store/ folder):
##   the scratchpad runner: T=60 bash runtest2.sh tools/store_art.gd xvfb   (OUT=<dir> to change)

const RobotArt = preload("res://robot_art.gd")
const Arena = preload("res://arena.gd")

var out := ""
var echo := {}
var foe := {}


class Paint extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


func _ready() -> void:
	await get_tree().process_frame
	out = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/home/claude/robotfightinggame/store/"
	DirAccess.make_dir_recursive_absolute(out)
	var gd = get_node("/root/GameData")
	gd.set_language("en")
	gd.new_game()
	RobotArt.classic = false
	echo = recolor(gd.player_look(), Color("#24467a"), Color("#e0b030"))
	var spec: Dictionary = gd.opponent_spec_from(gd.OPPONENTS[6], 1.0)
	foe = gd.look_from_spec(spec)
	await render(Vector2i(512, 512), draw_icon, "icon_512.png", false)
	await render(Vector2i(192, 192), draw_icon, "icon_192.png", false)
	await render(Vector2i(180, 180), draw_icon, "icon_180.png", false)
	await render(Vector2i(144, 144), draw_icon, "icon_144.png", false)
	await render(Vector2i(432, 432), draw_adaptive_fg, "adaptive_fg_432.png", true)
	await render(Vector2i(432, 432), draw_adaptive_bg, "adaptive_bg_432.png", false)
	await render(Vector2i(1024, 500), draw_feature, "feature_1024x500.png", false, true)
	await render(Vector2i(1024, 576), draw_splash, "splash.png", false, true)
	print("STORE ART DONE ", out)
	get_tree().quit()


func recolor(look: Dictionary, body: Color, trim: Color) -> Dictionary:
	var l := look.duplicate(true)
	l.erase("stickers")
	for slot in l["parts"]:
		var p: Dictionary = l["parts"][slot]
		if p.has("shape"):
			p["color"] = body.lightened(0.12) if slot.begins_with("arm") else (body.darkened(0.18) if slot.begins_with("leg") else body)
			p["health"] = 1.0
			p["grade"] = 4
	l["trim"] = trim
	l["eye"] = Color(0.35, 1.0, 0.75)
	return l


func render(sz: Vector2i, fn: Callable, file: String, transparent: bool, title: bool = false) -> void:
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p := Paint.new()
	p.fn = func(ci): fn.call(ci, Vector2(sz))
	vp.add_child(p)
	if title:
		var ta: Control = load("res://menu.gd").TitleArt.new()
		ta.size = Vector2(sz.x, 120)
		ta.position = Vector2(0, sz.y * 0.04)
		ta.scale = Vector2.ONE * (float(sz.x) / 1024.0)
		vp.add_child(ta)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out + file)
	vp.queue_free()


## The robot's head and shoulders, front on, lit like the bay at night.
func hero(ci: CanvasItem, S: Vector2, cx: float, top: float, h: float) -> void:
	var g := RobotArt.front_geom(echo)
	var head: Rect2 = g["head"]
	var sc := h / (-head.position.y + 40.0)
	RobotArt.draw_front(ci, Vector2(cx, top + (-head.position.y) * sc), echo, {"scale": sc, "light": "champ_arena", "time": 0.4})


func backdrop(ci: CanvasItem, S: Vector2) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(S.x, 0), S, Vector2(0, S.y)]),
			PackedColorArray([Color(0.05, 0.06, 0.1), Color(0.05, 0.06, 0.1), Color(0.11, 0.1, 0.13), Color(0.11, 0.1, 0.13)]))
	# a spotlight from above, and its pool on the floor
	var k := Color(0.85, 0.92, 1.0)
	ci.draw_polygon(PackedVector2Array([Vector2(S.x * 0.44, 0), Vector2(S.x * 0.56, 0), Vector2(S.x * 0.92, S.y), Vector2(S.x * 0.08, S.y)]),
			PackedColorArray([Color(k, 0.16), Color(k, 0.16), Color(k, 0.02), Color(k, 0.02)]))


func hazard(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(0.06, 0.06, 0.06))
	var w := r.size.y * 1.1
	var x := r.position.x - w
	while x < r.end.x + w:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + w * 0.5, r.position.y), Vector2(x + w, r.position.y), Vector2(x + w * 0.5, r.end.y)]), Color(0.95, 0.76, 0.19))
		x += w
	ci.draw_rect(r, Color(0.02, 0.02, 0.02), false, maxf(1.0, r.size.y * 0.08))


func draw_icon(ci: CanvasItem, S: Vector2) -> void:
	backdrop(ci, S)
	hero(ci, S, S.x * 0.5, S.y * 0.1, S.y * 1.5)   # big: the legs go behind the stripes
	hazard(ci, Rect2(0, S.y * 0.86, S.x, S.y * 0.14))


func draw_adaptive_fg(ci: CanvasItem, S: Vector2) -> void:
	# Android crops to the middle two thirds: keep the head well inside
	hero(ci, S, S.x * 0.5, S.y * 0.2, S.y * 1.0)


func draw_adaptive_bg(ci: CanvasItem, S: Vector2) -> void:
	backdrop(ci, S)
	hazard(ci, Rect2(0, S.y * 0.8, S.x, S.y * 0.2))


func draw_feature(ci: CanvasItem, S: Vector2) -> void:
	var crowd := Arena.make_crowd("champ_fans", S)
	var floor_y := S.y * 0.86
	Arena.draw_ring_scene(ci, "champ_arena", "champ_fans", crowd, S, floor_y, 1.3, 1.2, S.x * 0.05, S.x * 0.95)
	var tall := S.y * 0.56
	for k in 2:
		var look: Dictionary = echo if k == 0 else foe
		var g := RobotArt.geom(look)
		var sc := tall / (-(g["head"] as Rect2).position.y + 30.0) / float(look.get("scale", 1.0))
		RobotArt.draw(ci, Vector2(S.x * (0.3 if k == 0 else 0.7), floor_y + 4), look,
				{"scale": sc, "facing": 1 if k == 0 else -1, "time": 0.8 + k, "light": "champ_arena", "state": "punch" if k == 0 else "idle", "attack_limb": "arm_front", "extended": k == 0})


func draw_splash(ci: CanvasItem, S: Vector2) -> void:
	backdrop(ci, S)
	hero(ci, S, S.x * 0.5, S.y * 0.33, S.y * 0.95)
	hazard(ci, Rect2(0, S.y * 0.88, S.x, S.y * 0.12))
