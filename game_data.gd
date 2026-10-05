extends Node
## Global game state (autoload "GameData"):
## parts catalog, player robot, championship progress, money, save/load, settings.

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.json"
const START_MONEY := 300
const BASE_HP := 60
const SLOTS := ["head", "torso", "arms", "legs", "reactor"]
const SLOT_NAMES := {"head": "Head", "torso": "Torso", "arms": "Arms", "legs": "Legs", "reactor": "Reactor"}
const TRIM_COLOR := "#d9d9e0"

# durability -> extra max HP, damage -> % damage bonus, speed -> % speed bonus,
# draw -> reactor power the part needs. Reactors give "output" instead.
# Total draw of all parts must stay within the reactor's output.
const PARTS := {
	"head": [
		{"id": "head_scrap",  "name": "Scrap Head",     "cost": 0,    "durability": 5,  "damage": 0,  "speed": 0, "draw": 2, "color": "#8a8f98"},
		{"id": "head_sensor", "name": "Sensor Dome",    "cost": 300,  "durability": 8,  "damage": 0,  "speed": 6, "draw": 4, "color": "#4fa3d1"},
		{"id": "head_target", "name": "Targeting Head", "cost": 900,  "durability": 10, "damage": 10, "speed": 6, "draw": 6, "color": "#c94f4f"},
		{"id": "head_titan",  "name": "Titan Helm",     "cost": 2000, "durability": 22, "damage": 6,  "speed": 0, "draw": 8, "color": "#d4af37"},
	],
	"torso": [
		{"id": "torso_scrap",     "name": "Scrap Chassis",   "cost": 0,    "durability": 25, "damage": 0, "speed": 0, "draw": 3,  "color": "#7d7466"},
		{"id": "torso_steel",     "name": "Steel Frame",     "cost": 400,  "durability": 40, "damage": 0, "speed": 0, "draw": 5,  "color": "#5b6f8a"},
		{"id": "torso_composite", "name": "Composite Frame", "cost": 1100, "durability": 55, "damage": 0, "speed": 5, "draw": 7,  "color": "#3d8f6a"},
		{"id": "torso_titan",     "name": "Titan Core",      "cost": 2600, "durability": 80, "damage": 0, "speed": 0, "draw": 10, "color": "#b8860b"},
	],
	"arms": [
		{"id": "arms_scrap",     "name": "Scrap Arms",      "cost": 0,    "durability": 0, "damage": 0,  "speed": 0,  "draw": 3,  "color": "#8a7f74"},
		{"id": "arms_piston",    "name": "Piston Arms",     "cost": 350,  "durability": 0, "damage": 15, "speed": 0,  "draw": 6,  "color": "#6c8fb3"},
		{"id": "arms_hydraulic", "name": "Hydraulic Fists", "cost": 1000, "durability": 5, "damage": 30, "speed": 0,  "draw": 9,  "color": "#c0392b"},
		{"id": "arms_hammer",    "name": "Hammer Arms",     "cost": 2400, "durability": 8, "damage": 50, "speed": -5, "draw": 13, "color": "#e0a526"},
	],
	"legs": [
		{"id": "legs_scrap",    "name": "Scrap Legs",    "cost": 0,    "durability": 5,  "damage": 0, "speed": 0,  "draw": 2,  "color": "#77706a"},
		{"id": "legs_servo",    "name": "Servo Legs",    "cost": 300,  "durability": 5,  "damage": 0, "speed": 15, "draw": 5,  "color": "#4f86c6"},
		{"id": "legs_sprinter", "name": "Sprinter Legs", "cost": 950,  "durability": 8,  "damage": 0, "speed": 30, "draw": 8,  "color": "#2fb58a"},
		{"id": "legs_gyro",     "name": "Gyro Legs",     "cost": 2200, "durability": 20, "damage": 0, "speed": 22, "draw": 10, "color": "#c9a227"},
	],
	"reactor": [
		{"id": "reactor_scrap",  "name": "Scrap Reactor", "cost": 0,    "output": 12, "color": "#ff9a3c"},
		{"id": "reactor_diesel", "name": "Diesel Core",   "cost": 400,  "output": 22, "color": "#ff5533"},
		{"id": "reactor_fusion", "name": "Fusion Cell",   "cost": 1200, "output": 34, "color": "#2ec4ff"},
		{"id": "reactor_arc",    "name": "Arc Reactor",   "cost": 2800, "output": 48, "color": "#7fffd4"},
	],
}

# The championship: 10 fights, each harder than the last.
# think = seconds between CPU decisions (lower = faster reactions)
# block = chance the CPU blocks when you attack near it
const OPPONENTS := [
	{"name": "TIN CAN",    "hp": 70,  "damage": 0.80, "speed": 0.90, "think": 0.60, "block": 0.10, "reward": 200,  "body": "#9a9a9a", "trim": "#5a5a5a", "eye": "#ffcc00"},
	{"name": "RIVET",      "hp": 82,  "damage": 0.88, "speed": 0.93, "think": 0.55, "block": 0.15, "reward": 320,  "body": "#6d8b74", "trim": "#3e4f42", "eye": "#c6ff4d"},
	{"name": "SCRAPJAW",   "hp": 95,  "damage": 0.96, "speed": 0.97, "think": 0.50, "block": 0.20, "reward": 440,  "body": "#8c6239", "trim": "#4a3420", "eye": "#ff7b00"},
	{"name": "GEARBOX",    "hp": 108, "damage": 1.04, "speed": 1.00, "think": 0.45, "block": 0.25, "reward": 560,  "body": "#5e6b7d", "trim": "#c0c8d2", "eye": "#00e5ff"},
	{"name": "HAMMERHEAD", "hp": 120, "damage": 1.12, "speed": 1.04, "think": 0.40, "block": 0.30, "reward": 680,  "body": "#3f5f8f", "trim": "#a0b4d0", "eye": "#ff3355"},
	{"name": "VOLTAGE",    "hp": 132, "damage": 1.20, "speed": 1.12, "think": 0.35, "block": 0.35, "reward": 800,  "body": "#d4c21f", "trim": "#2b2b2b", "eye": "#00b7ff"},
	{"name": "SLEDGE",     "hp": 146, "damage": 1.30, "speed": 1.08, "think": 0.30, "block": 0.42, "reward": 920,  "body": "#7a2e2e", "trim": "#d6c9a8", "eye": "#ffe14d"},
	{"name": "BRIMSTONE",  "hp": 160, "damage": 1.38, "speed": 1.20, "think": 0.26, "block": 0.48, "reward": 1040, "body": "#c4501f", "trim": "#1f1f1f", "eye": "#ffd000"},
	{"name": "JUGGERNAUT", "hp": 178, "damage": 1.48, "speed": 1.22, "think": 0.22, "block": 0.54, "reward": 1160, "body": "#2f3a2f", "trim": "#8f9f8f", "eye": "#ff2020"},
	{"name": "OVERLORD",   "hp": 200, "damage": 1.60, "speed": 1.32, "think": 0.18, "block": 0.60, "reward": 1500, "body": "#1a1a2e", "trim": "#e0b84a", "eye": "#ff00aa"},
]

var money := START_MONEY
var owned: Array = []
var equipped := {}
var fight_index := 0     # next championship fight (0..9); 10 = finished
var wins := 0
var losses := 0
var champion := false
var last_result := {}    # handed from the fight to the garage
var settings := {"sound": true, "shake": true, "button_size": 1, "difficulty": 1}


func _ready() -> void:
	load_settings()
	new_game()   # sensible defaults so any scene can run on its own


# ---------------------------------------------------------------- game state

func new_game() -> void:
	money = START_MONEY
	owned = []
	equipped = {}
	for slot in SLOTS:
		var starter: Dictionary = PARTS[slot][0]
		owned.append(starter["id"])
		equipped[slot] = starter["id"]
	fight_index = 0
	wins = 0
	losses = 0
	champion = false
	last_result = {}


func get_part(id: String) -> Dictionary:
	for slot in SLOTS:
		for p in PARTS[slot]:
			if p["id"] == id:
				return p
	return {}


func slot_of(id: String) -> String:
	for slot in SLOTS:
		for p in PARTS[slot]:
			if p["id"] == id:
				return slot
	return ""


func tier_of(id: String) -> int:
	var slot := slot_of(id)
	var list: Array = PARTS[slot]
	for k in list.size():
		if list[k]["id"] == id:
			return k
	return 0


func stats_for(loadout: Dictionary) -> Dictionary:
	var dur := 0
	var dmg := 0
	var spd := 0
	var used := 0
	var out := 0
	for slot in SLOTS:
		var p := get_part(loadout[slot])
		if slot == "reactor":
			out = p["output"]
		else:
			dur += p["durability"]
			dmg += p["damage"]
			spd += p["speed"]
			used += p["draw"]
	return {"max_hp": BASE_HP + dur, "damage": 100 + dmg, "speed": 100 + spd,
			"power_used": used, "power_output": out}


func stats() -> Dictionary:
	return stats_for(equipped)


func can_equip(id: String) -> bool:
	var trial := equipped.duplicate()
	trial[slot_of(id)] = id
	var s := stats_for(trial)
	return s["power_used"] <= s["power_output"]


func equip(id: String) -> String:
	if not owned.has(id):
		return "You don't own that part."
	if not can_equip(id):
		if slot_of(id) == "reactor":
			return "%s is too weak to power your current parts." % get_part(id)["name"]
		return "Not enough reactor power for %s. Upgrade your reactor." % get_part(id)["name"]
	equipped[slot_of(id)] = id
	return "Equipped %s." % get_part(id)["name"]


func buy(id: String) -> String:
	var p := get_part(id)
	if owned.has(id):
		return equip(id)
	if money < p["cost"]:
		return "Not enough money."
	money -= p["cost"]
	owned.append(id)
	if can_equip(id):
		equipped[slot_of(id)] = id
		return "Bought and equipped %s." % p["name"]
	return "Bought %s, but it needs more reactor power to equip." % p["name"]


func part_stat_text(p: Dictionary) -> String:
	if p.has("output"):
		return "Power output %d" % p["output"]
	var bits: Array = []
	if p["durability"] != 0:
		bits.append("DUR %+d" % p["durability"])
	if p["damage"] != 0:
		bits.append("DMG %+d%%" % p["damage"])
	if p["speed"] != 0:
		bits.append("SPD %+d%%" % p["speed"])
	bits.append("Power %d" % p["draw"])
	return "   ".join(bits)


func look() -> Dictionary:
	return {
		"head": Color(get_part(equipped["head"])["color"]),
		"torso": Color(get_part(equipped["torso"])["color"]),
		"arms": Color(get_part(equipped["arms"])["color"]),
		"legs": Color(get_part(equipped["legs"])["color"]),
		"trim": Color(TRIM_COLOR),
		"eye": Color(get_part(equipped["reactor"])["color"]),
		"fist": 11.0 + tier_of(equipped["arms"]) * 2.0,
	}


func current_opponent() -> Dictionary:
	return OPPONENTS[clampi(fight_index, 0, OPPONENTS.size() - 1)]


func opponent_look(index: int) -> Dictionary:
	var o: Dictionary = OPPONENTS[clampi(index, 0, OPPONENTS.size() - 1)]
	var body := Color(o["body"])
	return {
		"head": body, "torso": body, "arms": body.lightened(0.12), "legs": body.darkened(0.15),
		"trim": Color(o["trim"]), "eye": Color(o["eye"]),
		"fist": 11.0 + index * 0.7,
	}


## Called when a championship match ends. Returns the money earned.
func record_result(won: bool) -> int:
	var o := current_opponent()
	var reward: int = o["reward"] if won else int(o["reward"] * 0.25)
	money += reward
	if won:
		wins += 1
		fight_index += 1
		if fight_index >= OPPONENTS.size():
			champion = true
	else:
		losses += 1
	last_result = {"won": won, "reward": reward, "opponent": o["name"], "champion": champion and won}
	save_game()
	return reward


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"money": money, "owned": owned, "equipped": equipped,
		"fight_index": fight_index, "wins": wins, "losses": losses, "champion": champion,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_game()
	money = int(data.get("money", START_MONEY))
	for id in data.get("owned", []):
		if not get_part(id).is_empty() and not owned.has(id):
			owned.append(id)
	var eq: Dictionary = data.get("equipped", {})
	for slot in SLOTS:
		if eq.has(slot) and owned.has(eq[slot]) and slot_of(eq[slot]) == slot:
			equipped[slot] = eq[slot]
	fight_index = int(data.get("fight_index", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	champion = bool(data.get("champion", false))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		for k in settings.keys():
			if data.has(k):
				settings[k] = data[k]
		settings["button_size"] = int(settings["button_size"])
		settings["difficulty"] = int(settings["difficulty"])
