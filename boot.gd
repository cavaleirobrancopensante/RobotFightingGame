extends Control
## (1.115) The first screen: the splash picture stays up (the engine's own boot splash shows the same
## one while the engine starts), and a LOADING bar fills while the world is built on a worker
## thread (GameData.new_game: every pilot, robot and league), then the main menu opens.

const UI = preload("res://ui.gd")
const I18n = preload("res://i18n.gd")
const GUI = preload("res://garage_ui.gd")
const TIME_PATH := "user://boot_time.txt"   # how long the last boot took: the bar paces itself by it

var bar
var task := -1
var t := 0.0
var expect := 3.0
var done_t := -1.0


func _ready() -> void:
	bar = Loading.build_screen(self)[1]   # the same loading screen as every other
	if FileAccess.file_exists(TIME_PATH):
		expect = clampf(float(FileAccess.get_file_as_string(TIME_PATH)), 0.5, 30.0)
	if GameData.world.is_empty():
		task = WorkerThreadPool.add_task(GameData.new_game, false, "build the world")
	else:
		done_t = 0.0


func _process(delta: float) -> void:
	t += delta
	if done_t < 0.0 and task >= 0 and WorkerThreadPool.is_task_completed(task):
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		done_t = t
		var f := FileAccess.open(TIME_PATH, FileAccess.WRITE)
		if f:
			f.store_string(str(snappedf(t, 0.01)))
	# paced by the last boot: never quite full until the work is really done
	var share := 1.0 - exp(-2.2 * t / expect)
	if done_t >= 0.0:
		share = 1.0
	bar.set_fill(share * float(bar.n))
	if done_t >= 0.0 and t - done_t > 0.12:
		set_process(false)
		get_tree().change_scene_to_file("res://main.tscn")
