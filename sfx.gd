extends Node
## Sound effects and music (autoload "Sfx").
##   Sfx.play("hit")          - one-shot sound effect (files in sfx/, made by tools/make_sounds.py)
##   Sfx.music("menu")        - looping music track (files in music/, made by tools/make_music.py)

const NAMES := ["click", "buy", "equip", "error", "swing", "uppercut", "hit", "hit_big",
		"block", "jump", "land", "step", "ko", "round", "fight", "victory", "defeat",
		"crowd_cheer", "crowd_ooh", "break", "repair", "sell", "target", "untarget",
		"talk", "talk_robot", "time", "spark",
		"voice_gravel", "voice_high", "voice_smooth", "voice_nasal", "voice_boom"]
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
		elif FileAccess.file_exists(path):
			# not imported (a fresh copy of the project in an editor): read the .wav itself
			var w := AudioStreamWAV.load_from_file(path)
			if w:
				streams[n] = w
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
const MENU_SOUNDS := ["click", "buy", "equip", "error", "sell", "repair", "talk", "talk_robot", "voice_gravel", "voice_high", "voice_smooth", "voice_nasal", "voice_boom"]


## Everyone who talks has their own blip: [sound, pitch]. Gus growls, Margo chirps, the
## announcers boom. Unknown speakers get the plain "talk" blip.
const VOICE_OF := {
	"GUS": ["voice_gravel", 1.0],
	"YOU": ["talk", 1.08],
	"ECHO": ["talk_robot", 1.0],
	"MARGO": ["voice_high", 1.18],
	"BRUNO": ["talk", 0.78],
	"SKAR": ["voice_high", 0.88],
	"DR. VOSS": ["voice_nasal", 1.0],
	"KANE": ["voice_smooth", 1.15],
	"ROSA": ["talk", 1.25],
	"NIK & NAT": ["voice_high", 1.4],
	"BULL": ["voice_gravel", 0.82],
	"IRONSIDE": ["voice_gravel", 1.2],
	"ANNOUNCER": ["voice_boom", 1.0],          # regional / cups, red jacket
	"ANNOUNCER_SCRAP": ["voice_gravel", 1.45],  # the scrap heap's rough guy with the megaphone
	"ANNOUNCER_GRAND": ["voice_smooth", 0.8],   # the Championship's man in the tux
}
const VOICE_DB := -5.0   # blips sit under the music but stay audible on phone speakers


## One talking blip for `who` (call it every ~0.07s while their line types out).
func voice(who: String) -> void:
	# pilots from around Port Ferrum: one of the voices, pitched by their name
	var v: Array = VOICE_OF.get(who, [["talk", "voice_high", "voice_gravel", "voice_nasal"][absi(hash(who)) % 4], 0.85 + float(absi(hash(who + "p")) % 35) / 100.0])
	play(v[0], 0.06, VOICE_DB, float(v[1]))


var tap := Callable()   # (1.74) a fight being recorded hears every sound (fight.rec_sound)


func play(sound: String, pitch_jitter: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if tap.is_valid():
		tap.call(sound, pitch_jitter, volume_db, pitch)
	play_raw(sound, pitch_jitter, volume_db, pitch)


## Plays without being recorded (a clip playing its own sounds back).
var silent := 0   # (1.75) > 0 while a fight is filmed off screen: it's heard by its recording only


func play_raw(sound: String, pitch_jitter: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if silent > 0:
		return
	if not GameData.settings.get("sound", true):
		return
	if quiet > 0 and not MENU_SOUNDS.has(sound):
		return
	if not streams.has(sound):
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.volume_db = volume_db + SFX_DB
	p.play()


## Playlists rotate through their songs; a single track name just loops that track.
const PLAYLISTS := {
	"menu": ["menu", "rain_docks", "chiptune_cafe", "harbour_waltz", "night_shift", "lounge", "bossa", "workshop", "rust_shuffle", "sunset_drive", "gamelan", "anthem", "garage"],
	"garage": ["garage", "rust_shuffle", "sunset_drive", "rain_docks", "workshop", "bossa", "chiptune_cafe", "gamelan", "lounge", "night_shift", "harbour_waltz", "menu"],
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
	["overture", "Port Ferrum Overture", "The opening"],
	["rain_docks", "Rain on the Docks", "Menus and garage"],
	["harbour_waltz", "Harbour Waltz", "Menus and garage"],
	["rust_shuffle", "Rust Belt Shuffle", "Menus and garage"],
	["bossa", "Dockside Bossa", "Menus and garage"],
	["gamelan", "Junkyard Gamelan", "Menus and garage"],
	["night_shift", "Night Shift", "Menus and garage"],
	["kane_tower", "Kane Tower", "Kane's scenes"],
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
	var s = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):
		s = AudioStreamOggVorbis.load_from_file(path)
	if s == null:
		return
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
