extends Node
## Sound effects and music (autoload "Sfx").
##   Sfx.play("hit")          - one-shot sound effect (files in sfx/, made by tools/make_sounds.py)
##   Sfx.music("menu")        - looping music track (files in music/, made by tools/make_music.py)

const NAMES := ["click", "buy", "equip", "error", "swing", "uppercut", "hit", "hit_big",
		"block", "jump", "land", "step", "ko", "round", "fight", "victory", "defeat",
		"crowd_cheer", "crowd_ooh", "break", "repair", "sell", "target", "untarget",
		"talk", "talk_robot", "time", "spark"]
const VOICES := 12
const MUSIC_DB := -9.0

var streams := {}
var players: Array = []
var next := 0
var music_player: AudioStreamPlayer
var current_track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_DB
	add_child(music_player)
	music_player.finished.connect(func(): music_player.play())   # loop


## pitch_jitter: random pitch variation (0.1 = +/-10%) so repeated sounds don't get boring.
func play(sound: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	if not GameData.settings.get("sound", true):
		return
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Switch music track. Calling with the track that's already playing does nothing.
func music(track: String) -> void:
	if not GameData.settings.get("music", true):
		stop_music()
		current_track = track
		return
	if track == current_track and music_player.playing:
		return
	current_track = track
	var path := "res://music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = true
	music_player.stream = s
	music_player.volume_db = -40.0
	music_player.play()
	create_tween().tween_property(music_player, "volume_db", MUSIC_DB, 0.8)


func stop_music() -> void:
	music_player.stop()


## Re-apply the music setting (called when it's toggled).
func refresh_music() -> void:
	var t := current_track
	current_track = ""
	if GameData.settings.get("music", true):
		music(t)
	else:
		stop_music()
		current_track = t
