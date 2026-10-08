extends Node
## (1.75) Films fights that were decided on the books (autoload "Film"). One fight at a time, off
## screen (fight.gd with `sim` set, in a SubViewport that never draws), a few milliseconds a frame
## so the game doesn't stutter; a fight someone is waiting to watch gets a bigger slice.
##
## job = {key, a, b (robot dicts), w (0 / 1 side that won), p (parts the loser lost, -1 any),
##        arena, crowd, title, now (someone is waiting), info (anything the caller wants back)}
## When a job is done `filmed(job, out)` fires (out: fight.sim_out: w, ko, rips, secs, film, clips)
## and, for the night's background fights, GameData.film_done(job, out) keeps what's worth keeping.

const FightScene = preload("res://fight.tscn")
var bg_ms := 4.0          # background: this much of each frame
var now_ms := 40.0         # someone is waiting (the screen shows a bar)

signal filmed(job: Dictionary, out: Dictionary)

var jobs: Array = []
var cur := {}
var fight: Node = null
var sv: SubViewport = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sv = SubViewport.new()
	sv.size = Vector2i(1152, 648)
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv.gui_disable_input = true
	sv.handle_input_locally = true
	sv.disable_3d = true
	add_child(sv)


func add(job: Dictionary) -> void:
	for j in jobs:
		if j["key"] == job["key"]:
			if job.get("now", false):
				j["now"] = true
				jobs.erase(j)
				jobs.push_front(j)
			return
	if not cur.is_empty() and cur["key"] == job["key"]:
		if job.get("now", false):
			cur["now"] = true
		return
	if job.get("now", false):
		jobs.push_front(job)
		if not cur.is_empty() and not cur.get("now", false):
			# someone's waiting: the background film starts again later
			var back := cur
			_drop()
			jobs.insert(1, back)
	else:
		jobs.append(job)


func busy_with(key: String) -> bool:
	return (not cur.is_empty() and cur["key"] == key) or jobs.any(func(j): return j["key"] == key)


## 0..1 for the job with this key (0 while it waits its turn).
func progress(key: String) -> float:
	if not cur.is_empty() and cur["key"] == key and fight != null:
		return fight.sim_progress()
	return 0.0


## Background jobs not in keys are dropped (someone waiting is never dropped).
func retain(keys: Array) -> void:
	jobs = jobs.filter(func(j): return j.get("now", false) or keys.has(j["key"]))


func clear() -> void:
	jobs.clear()
	_drop()


func _drop() -> void:
	if fight != null:
		fight.queue_free()
	fight = null
	cur = {}


func _process(_delta: float) -> void:
	if cur.is_empty():
		if jobs.is_empty():
			return
		# a real fight on screen has the stage to itself (unless someone's waiting for a film)
		if _in_fight() and not jobs[0].get("now", false):
			return
		cur = jobs.pop_front()
		fight = FightScene.instantiate()
		fight.sim = {"a": cur["a"], "b": cur["b"], "w": cur["w"], "p": cur.get("p", -1), "arena": cur.get("arena", "scrap_ring"),
				"crowd": cur.get("crowd", "scrappers"), "title": cur.get("title", "")}
		sv.add_child(fight)
		fight.set_process(false)   # (after _ready, which turns processing on) Film steps it instead
		return
	if _in_fight() and not cur.get("now", false):
		return
	if fight.sim_run(now_ms if cur.get("now", false) else bg_ms):
		var job := cur
		var out: Dictionary = fight.sim_out
		_drop()
		if job.get("bg", false):
			GameData.film_done(job, out)
		filmed.emit(job, out)


func _in_fight() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.get_script() != null and str(sc.get_script().resource_path).ends_with("fight.gd")
