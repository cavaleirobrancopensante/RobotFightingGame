extends RefCounted
## Touch button layout, shared by the fight and the layout editor in Settings.
##
## Default: two mirrored diamonds, movement on the left (up / down set the height of a hit, down alone
## crouches) and actions on the right (BLOCK top, PUNCH left, KICK right, JUMP bottom), gadgets in the
## bottom middle. Players can drag and resize every button in Settings > Edit controls; those
## changes are saved in GameData.settings["layout"] as
##   {button name: {"x": 0..1 of screen width, "y": 0..1 of screen height, "s": size factor}}
##
## pads = how many movement pads (multibot teams with split controls get one pad per robot).
## Extra pads use names like "left_1", "up_2"; pad 0 is just "left", "up"...

const UI_SCALE := 1.25
const BUTTON_SCALES := [0.8, 1.0, 1.25]
const MIN_SIZE := 0.55
const MAX_SIZE := 1.9
const MOVE_NAMES := ["left", "right", "up", "down"]
const MOVE_LABELS := {"left": "◀ LEFT", "right": "RIGHT ▶", "up": "▲ HIGH", "down": "▼ LOW"}


static func base_radius(screen: Vector2) -> float:
	return clampf(screen.y * 0.085, 34.0, 60.0) * BUTTON_SCALES[int(GameData.settings.get("button_size", 1))] * UI_SCALE


static func pad_name(dir: String, pad: int) -> String:
	return dir if pad == 0 else "%s_%d" % [dir, pad]


## Which movement pad a button belongs to (-1 = not a movement button).
static func pad_of(button_name: String) -> int:
	var bits := button_name.split("_")
	if not MOVE_NAMES.has(bits[0]):
		return -1
	return 0 if bits.size() == 1 else int(bits[1])


static func dir_of(button_name: String) -> String:
	return button_name.split("_")[0]


## The default layout before any custom edits.
static func default_buttons(screen: Vector2, gadget_labels: Array, pads: int = 1) -> Array:
	var h := screen.y
	var w := screen.x
	var r := base_radius(screen)
	var out: Array = []
	var pr := r if pads == 1 else r * (0.85 if pads == 2 else 0.72)   # extra pads: a bit smaller so they fit
	for pad in pads:
		var c := Vector2(pr * 2.75 + pad * pr * 5.4, h - pr * 2.4)
		var tag := "" if pads == 1 else " %d" % (pad + 1)
		out.append({"name": pad_name("left", pad), "pos": c + Vector2(-pr * 1.55, 0), "r": pr, "label": "◀" + tag if pads > 1 else MOVE_LABELS["left"]})
		out.append({"name": pad_name("right", pad), "pos": c + Vector2(pr * 1.55, 0), "r": pr, "label": tag + "▶" if pads > 1 else MOVE_LABELS["right"]})
		out.append({"name": pad_name("up", pad), "pos": c + Vector2(0, -pr * 1.55), "r": pr, "label": "▲" + tag if pads > 1 else MOVE_LABELS["up"]})
		out.append({"name": pad_name("down", pad), "pos": c + Vector2(0, pr * 1.3), "r": pr, "label": "▼" + tag if pads > 1 else MOVE_LABELS["down"]})
	var rc := Vector2(w - r * 2.75, h - r * 2.4)
	out.append({"name": "punch", "pos": rc + Vector2(-r * 1.55, 0), "r": r, "label": "PUNCH"})
	out.append({"name": "kick", "pos": rc + Vector2(r * 1.55, 0), "r": r, "label": "KICK"})
	out.append({"name": "block", "pos": rc + Vector2(0, -r * 1.55), "r": r, "label": "BLOCK"})
	out.append({"name": "jump", "pos": rc + Vector2(0, r * 1.3), "r": r, "label": "JUMP"})
	var gr := r * 0.72
	for k in gadget_labels.size():
		var gp: Vector2
		if pads >= 3:
			# three movement pads fill the bottom: stack gadgets in a column beside the action pad
			gp = Vector2(w - r * 5.4 - gr, h - gr * 1.25 - k * gr * 2.3)
		else:
			var gx := w * 0.5 + (pr * 2.6 if pads == 2 else 0.0)
			gp = Vector2(gx + (k - (gadget_labels.size() - 1) * 0.5) * gr * 2.4, h - gr * 1.25)
		out.append({"name": "gadget%d" % k, "pos": gp, "r": gr, "label": gadget_labels[k]})
	return out


## The layout with the player's custom edits applied.
static func make_buttons(screen: Vector2, gadget_labels: Array, pads: int = 1) -> Array:
	var out := default_buttons(screen, gadget_labels, pads)
	var custom: Dictionary = GameData.settings.get("layout", {})
	for b in out:
		var key := layout_key(b["name"], pads)
		if custom.has(key):
			var c: Dictionary = custom[key]
			b["pos"] = Vector2(float(c.get("x", 0.5)) * screen.x, float(c.get("y", 0.5)) * screen.y)
			b["r"] = b["r"] * clampf(float(c.get("s", 1.0)), MIN_SIZE, MAX_SIZE)
	return out


## Movement pads are laid out separately for 1, 2 and 3 pads (split multibot controls).
static func layout_key(button_name: String, pads: int) -> String:
	if pads > 1 and (pad_of(button_name) >= 0 or button_name.begins_with("gadget")):
		return "%s@%d" % [button_name, pads]
	return button_name


## Save one button's position and size (size relative to its default).
static func store(button_name: String, pads: int, pos: Vector2, size_factor: float, screen: Vector2) -> void:
	if not GameData.settings.has("layout") or typeof(GameData.settings["layout"]) != TYPE_DICTIONARY:
		GameData.settings["layout"] = {}
	GameData.settings["layout"][layout_key(button_name, pads)] = {
		"x": clampf(pos.x / screen.x, 0.0, 1.0), "y": clampf(pos.y / screen.y, 0.0, 1.0),
		"s": clampf(size_factor, MIN_SIZE, MAX_SIZE)}


static func size_factor(button_name: String, pads: int) -> float:
	var custom: Dictionary = GameData.settings.get("layout", {})
	var key := layout_key(button_name, pads)
	return clampf(float(custom[key].get("s", 1.0)), MIN_SIZE, MAX_SIZE) if custom.has(key) else 1.0


static func reset(pads: int) -> void:
	var custom: Dictionary = GameData.settings.get("layout", {})
	for key in custom.keys():
		var is_multi: bool = "@" in key
		if (pads == 1 and not is_multi) or (pads > 1 and key.ends_with("@%d" % pads)):
			custom.erase(key)
