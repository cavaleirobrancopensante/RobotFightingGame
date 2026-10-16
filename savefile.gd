extends Node
## (1.126) Save files you can download and upload, like the old browser games: a slot's autosave,
## your own save and its clips packed into one small file (gzip JSON, .rfsave).
##   Web: the browser downloads it / opens its file picker.
##   Computers and phones: the system's file dialog; where there's none, a save code on the clipboard.
## A plain save_N.json from the game's folder can be uploaded too.

const UI = preload("res://ui.gd")
const PlayLog = preload("res://playlog.gd")
const EXT := "rfsave"
const CODE_HEAD := "RFSAVE1:"

var _done := Callable()
var _js_cb = null   # keeps the browser callback alive while the picker is open
var _slot := 1


# ---------------------------------------------------------------- packing

static func bundle(slot: int) -> PackedByteArray:
	var d := {"robotfighting_save": 1, "game_version": GameData.VERSION, "slot_save": _read("user://save_%d.json" % slot)}
	var mine := _read("user://save_%d_mine.json" % slot)
	if mine != "":
		d["mine"] = mine
	var clips := _read("user://clips_%d.json" % slot)
	if clips != "" and clips != "[]" and clips != "{}":
		d["clips"] = clips
	return JSON.stringify(d).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## A file's bytes (or a pasted code) -> the bundle, or {"error": "..."}.
static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {"error": "That file is empty."}
	var text := ""
	if bytes.size() > 2 and bytes[0] == 0x1f and bytes[1] == 0x8b:
		# gzip: grow the buffer until it fits (saves are a few hundred KB)
		var raw := PackedByteArray()
		for k in [8, 24, 64, 160]:
			raw = bytes.decompress(bytes.size() * k, FileAccess.COMPRESSION_GZIP)
			if raw.size() > 0 and raw.size() < bytes.size() * k:
				break
		text = raw.get_string_from_utf8()
	else:
		text = bytes.get_string_from_utf8().strip_edges()
		if text.begins_with(CODE_HEAD):
			return unpack(Marshalls.base64_to_raw(text.substr(CODE_HEAD.length()).strip_edges()))
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return {"error": "That isn't a Robot Fighting save file."}
	if not d.has("slot_save"):
		d = {"slot_save": text}   # a plain save_N.json
	var save = JSON.parse_string(str(d["slot_save"]))
	if typeof(save) != TYPE_DICTIONARY or not save.has("version") or not save.has("pilot_name"):
		return {"error": "That isn't a Robot Fighting save file."}
	if int(save["version"]) > GameData.SAVE_VERSION:
		return {"error": "That save comes from a newer version of the game. Update the game first."}
	d["info"] = {"pilot": str(save.get("pilot_name", "?")), "robot": str(save.get("robot_name", "?")),
			"year": int(save.get("year", 1)), "week": int(save.get("week", 1))}
	return d


## Write a bundle into a slot (replacing what was there). "" on success.
static func install(slot: int, d: Dictionary) -> String:
	var files := {"user://save_%d.json" % slot: str(d["slot_save"]),
			"user://clips_%d.json" % slot: str(d.get("clips", "[]"))}
	for path in files:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return "Couldn't write the save."
		f.store_string(files[path])
	var mine_p := "user://save_%d_mine.json" % slot
	if d.has("mine"):
		var fm := FileAccess.open(mine_p, FileAccess.WRITE)
		if fm:
			fm.store_string(str(d["mine"]))
	elif FileAccess.file_exists(mine_p):
		DirAccess.remove_absolute(mine_p)
	if FileAccess.file_exists("user://films_%d.json" % slot):
		DirAccess.remove_absolute("user://films_%d.json" % slot)   # whole filmed fights are made again when needed
	PlayLog.add("save", "uploaded a save into slot %d" % slot)
	return ""


static func file_name(slot: int) -> String:
	var info := GameData.slot_info(slot)
	var who := "%s-%s" % [str(info.get("pilot", "pilot")), str(info.get("robot", "robot"))]
	var clean := ""
	for ch in who:
		clean += ch if (ch.is_valid_identifier() or ch == "-" or (ch >= "0" and ch <= "9")) else "_"
	var date := Time.get_date_string_from_system().replace("-", "")
	return "RobotFighting-%s-%s.%s" % [clean, date, EXT]


static func web() -> bool:
	return OS.has_feature("web")


static func native_dialog() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## The save code: the same file as text, for when there's no file dialog (copy, paste, send).
static func code(slot: int) -> String:
	return CODE_HEAD + Marshalls.raw_to_base64(bundle(slot))


# ---------------------------------------------------------------- download

## Download a slot's save. done(message) gets what happened, to show the player.
static func export_slot(host: Node, slot: int, done: Callable) -> void:
	var bytes := bundle(slot)
	var name := file_name(slot)
	PlayLog.add("save", "download slot %d (%d KB)" % [slot, bytes.size() / 1024])
	if web():
		JavaScriptBridge.download_buffer(bytes, name, "application/octet-stream")
		done.call(TranslationServer.translate("Save file downloaded: %s") % name, true)
		return
	var sf := new()
	sf._done = done
	sf._slot = slot
	host.add_child(sf)
	sf._save_dialog(bytes, name)


func _save_dialog(bytes: PackedByteArray, name: String) -> void:
	var on_path := func(path: String) -> void:
		if path == "":
			_finish("")
			return
		if not path.ends_with("." + EXT):
			path += "." + EXT
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			DisplayServer.clipboard_set(code(_slot))
			_finish(TranslationServer.translate("Couldn't write there. The save code is on your clipboard instead: paste it somewhere safe."), true)
			return
		f.store_buffer(bytes)
		f.close()
		_finish(TranslationServer.translate("Save file written: %s") % path.get_file())
	if native_dialog():
		var cb := func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			on_path.call(paths[0] if ok and not paths.is_empty() else "")
		var err := DisplayServer.file_dialog_show(TranslationServer.translate("Download save file"), _start_dir(), name, false,
				DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.%s ; Robot Fighting save" % EXT]), cb)
		if err == OK:
			return
	if OS.has_feature("mobile"):
		# no system dialog: hand over the save code instead
		DisplayServer.clipboard_set(code(_slot))
		_finish(TranslationServer.translate("Your phone has no file picker here. The save code is on your clipboard: paste it into a note or a message to keep it."))
		return
	var fd := _godot_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	fd.current_file = name
	fd.file_selected.connect(func(p: String): on_path.call(p))
	fd.canceled.connect(func(): on_path.call(""))
	fd.popup_centered_ratio(0.8)


# ---------------------------------------------------------------- upload

## Pick a save file and put it into a slot. done(message, ok) says what happened.
static func import_slot(host: Node, slot: int, done: Callable) -> void:
	var sf := new()
	sf._done = done
	sf._slot = slot
	host.add_child(sf)
	sf._pick()


func _pick() -> void:
	if web():
		_web_pick()
		return
	if native_dialog():
		var cb := func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if not ok or paths.is_empty():
				_finish("")
			else:
				_got_path(paths[0])
		var err := DisplayServer.file_dialog_show(TranslationServer.translate("Upload a save file"), _start_dir(), "", false,
				DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.%s, *.json ; Robot Fighting save" % EXT]), cb)
		if err == OK:
			return
	if OS.has_feature("mobile"):
		_got_bytes(DisplayServer.clipboard_get().to_utf8_buffer(), true)   # paste the save code
		return
	var fd := _godot_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	fd.file_selected.connect(func(p: String): _got_path(p))
	fd.canceled.connect(func(): _finish(""))
	fd.popup_centered_ratio(0.8)


func _web_pick() -> void:
	_js_cb = JavaScriptBridge.create_callback(_on_web_file)
	var win = JavaScriptBridge.get_interface("window")
	win.rfSaveCb = _js_cb
	JavaScriptBridge.eval("""
	(function(){
		var i = document.createElement('input');
		i.type = 'file'; i.accept = '.%s,.json';
		i.onchange = function(){
			var f = i.files[0];
			if (!f) { window.rfSaveCb(''); return; }
			var r = new FileReader();
			r.onload = function(){
				var b = new Uint8Array(r.result), s = '';
				for (var k = 0; k < b.length; k += 32768) { s += String.fromCharCode.apply(null, b.subarray(k, k + 32768)); }
				window.rfSaveCb(btoa(s));
			};
			r.readAsArrayBuffer(f);
		};
		i.click();
	})();
	""" % EXT, true)


func _on_web_file(args: Array) -> void:
	var b64 := str(args[0]) if not args.is_empty() else ""
	if b64 == "":
		_finish("")
		return
	_got_bytes(Marshalls.base64_to_raw(b64))


func _got_path(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_finish(TranslationServer.translate("Couldn't open that file."), true)
		return
	_got_bytes(f.get_buffer(f.get_length()))


func _got_bytes(bytes: PackedByteArray, from_clipboard: bool = false) -> void:
	var d := unpack(bytes)
	if d.has("error"):
		var msg := TranslationServer.translate(str(d["error"]))
		if from_clipboard:
			msg = TranslationServer.translate("Your phone has no file picker here. Copy a save code first, then tap Upload again.")
		_finish(msg, true)
		return
	var err := install(_slot, d)
	if err != "":
		_finish(TranslationServer.translate(err), true)
		return
	var info: Dictionary = d["info"]
	_finish(TranslationServer.translate("Uploaded into slot %d: %s & %s, year %d, week %d.") % [_slot, info["pilot"], info["robot"], info["year"], info["week"]])


# ---------------------------------------------------------------- shared

func _godot_dialog(mode: int) -> FileDialog:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = mode
	fd.filters = PackedStringArray(["*.%s, *.json ; Robot Fighting save" % EXT])
	fd.current_dir = _start_dir()
	fd.title = TranslationServer.translate("Upload a save file" if mode == FileDialog.FILE_MODE_OPEN_FILE else "Download save file")
	add_child(fd)
	return fd


static func _start_dir() -> String:
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return dl if dl != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


func _finish(msg: String, failed: bool = false) -> void:
	# callbacks from the system dialog can arrive off the main loop: hand back on it
	(func():
		if _done.is_valid():
			_done.call(msg, not failed)
		queue_free()).call_deferred()
