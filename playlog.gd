extends RefCounted
## (1.87) The playtest log: what the player did, written as it happens, so a playtester can copy
## it (Settings > Copy playtest log) and paste it to whoever's fixing the game. Screens opened,
## windows, buttons pressed, notes, fights and results, money, posts and errors. Kept in
## user://playtest_log.txt (the last MAX_LINES lines), written with the save and when copied.

const PATH := "user://playtest_log.txt"
const MAX_LINES := 2500

static var lines: PackedStringArray = PackedStringArray()
static var loaded := false
static var dirty := false
static var last := ""


static func _load() -> void:
	if loaded:
		return
	loaded = true
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			lines = f.get_as_text().split("\n", false)


## When in the game it happened: "Y1 W3 TUE AM" (or just the clock outside a career).
static func game_time() -> String:
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData") if Engine.get_main_loop() else null
	if gd == null or gd.world.is_empty():
		return ""
	return "Y%d W%d %s %s" % [int(gd.year), int(gd.week), str(gd.day).to_upper(), ["AM", "PM", "EVE"][clampi(int(gd.phase), 0, 2)]]


static func add(cat: String, text: String) -> void:
	_load()
	var t := text.replace("\n", " / ").strip_edges()
	if t.length() > 220:
		t = t.substr(0, 220) + "…"
	var line := "%s [%s] %s: %s" % [Time.get_time_string_from_system(), game_time(), cat, t]
	if line == last:
		return   # the same thing twice in a row (a redraw, a double signal): once is enough
	last = line
	lines.append(line)
	if lines.size() > MAX_LINES + 200:
		lines = lines.slice(lines.size() - MAX_LINES)
	dirty = true


static func flush() -> void:
	if not dirty:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		dirty = false


static func clear() -> void:
	lines = PackedStringArray()
	last = ""
	dirty = true
	flush()


## Everything, ready to paste: a header (version, device, where the career stands), the errors,
## then the log, newest last.
static func full_text(errors: Array) -> String:
	_load()
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData")
	var out: PackedStringArray = PackedStringArray()
	out.append("ROBOT FIGHTING PLAYTEST LOG")
	if gd:
		out.append("Version %s · %s · %s · screen %s" % [gd.VERSION, OS.get_name(), OS.get_model_name(), str(DisplayServer.screen_get_size())])
		if not gd.world.is_empty():
			out.append("Career: slot %d, %s, $%d, rank %s, record %d-%d, %s" % [int(gd.save_slot), game_time(), int(gd.money), str(gd.rank),
					int(gd.wins), int(gd.losses), str(gd.settings.get("lang", "en"))])
	out.append("Copied %s" % Time.get_datetime_string_from_system())
	if not errors.is_empty():
		out.append("")
		out.append("ERRORS (%d)" % errors.size())
		for e in errors.slice(maxi(0, errors.size() - 40)):
			out.append(str(e))
	out.append("")
	out.append("LOG (%d lines)" % lines.size())
	out.append_array(lines)
	return "\n".join(out)
