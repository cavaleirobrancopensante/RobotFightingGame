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
const FIGHT_MUSIC_DB := -13.5   # fight songs are mixed hot: play them quieter so they don't blast
const SFX_DB := -3.0            # overall level for sound effects

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
	music_player.finished.connect(_on_music_finished)


## pitch_jitter: random pitch variation (0.1 = +/-10%) so repeated sounds don't get boring.
var quiet := 0   # > 0 while a move showcase plays in the garage: only menu sounds get through
const MENU_SOUNDS := ["click", "buy", "equip", "error", "sell", "repair"]


func play(sound: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	if not GameData.settings.get("sound", true):
		return
	if quiet > 0 and not MENU_SOUNDS.has(sound):
		return
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db + SFX_DB
	p.play()


## Playlists rotate through their songs; a single track name just loops that track.
const PLAYLISTS := {
	"menu": ["menu", "chiptune_cafe", "lounge", "workshop", "sunset_drive", "anthem", "garage"],
	"garage": ["garage", "sunset_drive", "workshop", "chiptune_cafe", "lounge", "menu"],
	"story": ["story", "lounge"],
}
## Fight themes, picked per opponent (boss gets its own).
const FIGHT_TRACKS := ["fight", "fight_pump", "fight_rush", "fight_heavy", "fight_neon", "fight_chrome", "fight_scrapyard", "fight_thunder"]

var playlist: Array = []
var playlist_pos := 0

## The jukebox at The Rusty Bolt: every song in the game, by name, with where you hear it.
## [file, title, where it plays]
const JUKEBOX := [
	["menu", "Port Ferrum Nights", "Main menu"],
	["garage", "Gus's Bay", "The garage"],
	["workshop", "Sparks and Solder", "The garage"],
	["sunset_drive", "Sunset Drive", "Menus and garage"],
	["chiptune_cafe", "Chiptune Cafe", "Menus and garage"],
	["lounge", "Rusty Bolt Lounge", "Menus, garage and story"],
	["story", "The Dead Man's Robot", "Story scenes"],
	["walkin_scrap", "Settle Down, You Lot", "Walk-in: the Scrap Heap Ring"],
	["walkin_arena", "Fight Night Fanfare", "Walk-in: Regional and cups"],
	["walkin_grand", "The Grand Hall", "Walk-in: the Championship"],
	["fight", "First Bell", "Fights"],
	["fight_pump", "Pump the Pistons", "Fights"],
	["fight_rush", "Overclock Rush", "Fights"],
	["fight_heavy", "Heavy Metal, Literally", "Fights"],
	["fight_neon", "Neon Knockout", "Fights"],
	["fight_chrome", "Chrome Fists", "Fights"],
	["fight_scrapyard", "Scrapyard Brawl", "Fights"],
	["fight_thunder", "Thunder Gallop", "Fights"],
	["boss", "OVERLORD", "Boss fights and finals"],
	["anthem", "Champion of the Docks", "The finale"],
]


## Jukebox: play one song, then carry on down the list (it keeps going until you press Stop).
func jukebox(index: int) -> void:
	var names: Array = JUKEBOX.map(func(x): return x[0])
	playlist = names
	playlist_pos = clampi(index, 0, names.size() - 1)
	current_track = "jukebox"
	if not GameData.settings.get("music", true):
		return
	_play_current()


func jukebox_index() -> int:
	if current_track != "jukebox":
		return -1
	return playlist_pos


## Where the song is (seconds) and how long it is.
func music_position() -> Vector2:
	if not music_player.playing or music_player.stream == null:
		return Vector2.ZERO
	return Vector2(music_player.get_playback_position(), music_player.stream.get_length())


## Play a playlist ("menu", "garage", "story") or loop one track ("boss", "fight_rush"...).
## Asking for what's already playing does nothing, so the song doesn't restart between screens.
func music(name: String) -> void:
	var list: Array = PLAYLISTS.get(name, [name])
	if name == current_track and music_player.playing:
		return
	# moving between menu screens: keep the current song if the new playlist has it
	if music_player.playing and list.size() > 1 and list.has(now_playing()):
		playlist_pos = list.find(now_playing())
		playlist = list
		current_track = name
		return
	current_track = name
	playlist = list
	playlist_pos = randi() % list.size() if list.size() > 1 else 0
	if not GameData.settings.get("music", true):
		stop_music()
		return
	_play_current()


func _play_current() -> void:
	var path := "res://music/%s.ogg" % playlist[playlist_pos]
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = playlist.size() == 1
	music_player.stream = s
	music_player.volume_db = -40.0
	music_player.play()
	# fight music fades in gently instead of hitting at full volume
	var fight: bool = FIGHT_TRACKS.has(playlist[playlist_pos]) or playlist[playlist_pos] == "boss"
	create_tween().tween_property(music_player, "volume_db", FIGHT_MUSIC_DB if fight else MUSIC_DB, 2.0 if fight else 0.8)


func _on_music_finished() -> void:
	if playlist.is_empty() or not GameData.settings.get("music", true):
		return
	playlist_pos = (playlist_pos + 1) % playlist.size()
	_play_current()


func now_playing() -> String:
	return "" if playlist.is_empty() else str(playlist[playlist_pos])


func stop_music() -> void:
	music_player.stop()


## Re-apply the music setting (called when it's toggled).
func refresh_music() -> void:
	if GameData.settings.get("music", true):
		if not playlist.is_empty():
			_play_current()
	else:
		stop_music()
