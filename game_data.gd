extends Node
## Global game state (autoload "GameData"):
## parts catalog, inventory of part instances (each with its own health), what's equipped,
## championship progress, money, story progress, save/load, settings.

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 2
const START_MONEY := 300
const ROBOT_NAME := "ECHO"

# Robot slots. Front = the side facing the camera (drawn in front).
const SLOTS := ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back", "reactor"]
const SLOT_NAMES := {"head": "Head", "torso": "Torso", "arm_front": "Front Arm", "arm_back": "Back Arm",
		"leg_front": "Front Leg", "leg_back": "Back Leg", "reactor": "Reactor"}
const SLOT_KIND := {"head": "head", "torso": "torso", "arm_front": "arm", "arm_back": "arm",
		"leg_front": "leg", "leg_back": "leg", "reactor": "reactor"}
const KINDS := ["head", "torso", "arm", "leg", "reactor"]
const KIND_NAMES := {"head": "Heads", "torso": "Torsos", "arm": "Arms", "leg": "Legs", "reactor": "Reactors"}
const BODY_SLOTS := ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]

const PAINTS := [
	{"name": "Chrome", "color": "#d9d9e0"}, {"name": "Hazard", "color": "#f2c230"},
	{"name": "Fire", "color": "#ff5a2a"}, {"name": "Toxic", "color": "#7cf05a"},
	{"name": "Ice", "color": "#6fd3ff"}, {"name": "Royal", "color": "#9a6bff"},
	{"name": "Bubblegum", "color": "#ff7ac8"}, {"name": "Shadow", "color": "#3a3a46"},
]

# Part fields:
#   hp       - part health; reaching 0 destroys (rips off) the part
#   armor    - % less damage this part takes
#   damage   - % extra damage for attacks made with this arm/leg
#   speed    - % speed (legs: movement, arms: punch speed, torso: everything)
#   aim      - % extra damage on hits that land on the part you're targeting (heads)
#   draw     - reactor power the part needs. output - power a reactor (or reactor chest) gives
#   shape    - how it looks; size - how big it's drawn; shop - false = only from salvage
const PART_LIST := [
	# ---- heads
	{"id": "junk_head",    "kind": "head", "name": "Junk Bucket",   "cost": 0,    "hp": 30, "armor": 0,  "aim": 0,  "draw": 1, "shape": "bucket",  "color": "#8a8f98"},
	{"id": "head_box",     "kind": "head", "name": "Sensor Box",    "cost": 150,  "hp": 40, "armor": 5,  "aim": 5,  "draw": 2, "shape": "box",     "color": "#6d7f91"},
	{"id": "head_dome",    "kind": "head", "name": "Dome Scanner",  "cost": 400,  "hp": 45, "armor": 10, "aim": 10, "draw": 2, "shape": "dome",    "color": "#4fa3d1"},
	{"id": "head_cyclops", "kind": "head", "name": "Cyclops Eye",   "cost": 850,  "hp": 40, "armor": 5,  "aim": 25, "draw": 3, "shape": "cyclops", "color": "#c94f4f"},
	{"id": "head_visor",   "kind": "head", "name": "Visor Helm",    "cost": 1300, "hp": 60, "armor": 20, "aim": 10, "draw": 3, "shape": "visor",   "color": "#3f5f8f"},
	{"id": "head_horned",  "kind": "head", "name": "Horned Crown",  "cost": 2400, "hp": 75, "armor": 25, "aim": 15, "draw": 5, "shape": "horned",  "color": "#d4af37"},
	{"id": "head_jaw",     "kind": "head", "name": "Bear-Trap Jaw", "cost": 900,  "hp": 55, "armor": 10, "aim": 5,  "draw": 3, "shape": "skull",   "color": "#8c6239", "shop": false},
	{"id": "head_wedge",   "kind": "head", "name": "Shark Wedge",   "cost": 1000, "hp": 55, "armor": 15, "aim": 10, "draw": 3, "shape": "wedge",   "color": "#3f5f8f", "shop": false},
	{"id": "head_bulb",    "kind": "head", "name": "Tesla Bulb",    "cost": 1100, "hp": 45, "armor": 5,  "aim": 20, "draw": 3, "shape": "bulb",    "color": "#d4c21f", "shop": false},
	{"id": "head_mast",    "kind": "head", "name": "Command Mast",  "cost": 2800, "hp": 70, "armor": 20, "aim": 30, "draw": 5, "shape": "tall",    "color": "#1a1a2e", "shop": false},
	# ---- torsos (the torso is the robot's core: if it breaks, it's a knockout)
	{"id": "junk_torso",   "kind": "torso", "name": "Oil Drum",      "cost": 0,    "hp": 80,  "armor": 0,  "speed": 0,   "draw": 1, "shape": "barrel", "color": "#7d7466"},
	{"id": "torso_box",    "kind": "torso", "name": "Steel Box",     "cost": 200,  "hp": 100, "armor": 5,  "speed": 0,   "draw": 2, "shape": "box",    "color": "#5b6f8a"},
	{"id": "torso_vee",    "kind": "torso", "name": "Vee Frame",     "cost": 600,  "hp": 115, "armor": 10, "speed": 5,   "draw": 3, "shape": "vee",    "color": "#3d8f6a"},
	{"id": "torso_plate",  "kind": "torso", "name": "Plated Barrel", "cost": 1200, "hp": 140, "armor": 15, "speed": 0,   "draw": 4, "shape": "barrel", "color": "#8f6b3d", "size": 1.15},
	{"id": "torso_core",   "kind": "torso", "name": "Reactor Chest", "cost": 1500, "hp": 125, "armor": 10, "speed": 0,   "draw": 3, "shape": "core",   "color": "#2e7c9e", "output": 6},
	{"id": "torso_tank",   "kind": "torso", "name": "Tank Hull",     "cost": 2800, "hp": 180, "armor": 25, "speed": -10, "draw": 6, "shape": "tank",   "color": "#b8860b"},
	{"id": "torso_slim",   "kind": "torso", "name": "Racing Frame",  "cost": 1000, "hp": 95,  "armor": 5,  "speed": 15,  "draw": 3, "shape": "slim",   "color": "#d4c21f", "shop": false},
	# ---- arms
	{"id": "junk_arm",     "kind": "arm", "name": "Pipe Arm",    "cost": 0,    "hp": 30, "armor": 0,  "damage": 0,  "speed": 0,   "draw": 1, "shape": "rod",    "color": "#8a7f74", "size": 0.8},
	{"id": "arm_rod",      "kind": "arm", "name": "Steel Rod",   "cost": 150,  "hp": 45, "armor": 5,  "damage": 10, "speed": 5,   "draw": 2, "shape": "rod",    "color": "#8f9aa6"},
	{"id": "arm_piston",   "kind": "arm", "name": "Piston Arm",  "cost": 450,  "hp": 55, "armor": 10, "damage": 25, "speed": 0,   "draw": 3, "shape": "piston", "color": "#6c8fb3"},
	{"id": "arm_claw",     "kind": "arm", "name": "Claw Arm",    "cost": 700,  "hp": 50, "armor": 5,  "damage": 20, "speed": 15,  "draw": 3, "shape": "claw",   "color": "#3d8f6a"},
	{"id": "arm_spike",    "kind": "arm", "name": "Spike Fist",  "cost": 1200, "hp": 55, "armor": 10, "damage": 40, "speed": 5,   "draw": 4, "shape": "spike",  "color": "#c0392b"},
	{"id": "arm_bulky",    "kind": "arm", "name": "Brawler Arm", "cost": 1500, "hp": 75, "armor": 15, "damage": 35, "speed": 0,   "draw": 4, "shape": "bulky",  "color": "#7a4fb3"},
	{"id": "arm_hammer",   "kind": "arm", "name": "Hammer Arm",  "cost": 2500, "hp": 80, "armor": 15, "damage": 60, "speed": -15, "draw": 6, "shape": "hammer", "color": "#e0a526"},
	{"id": "arm_drill",    "kind": "arm", "name": "Drill Arm",   "cost": 2000, "hp": 60, "armor": 10, "damage": 50, "speed": 5,   "draw": 5, "shape": "drill",  "color": "#9aa0a6", "shop": false},
	# ---- legs (damage = kick power)
	{"id": "junk_leg",     "kind": "leg", "name": "Stilt Leg",   "cost": 0,    "hp": 35,  "armor": 0,  "damage": 0,  "speed": -5,  "draw": 1, "shape": "rod",     "color": "#77706a", "size": 0.8},
	{"id": "leg_steel",    "kind": "leg", "name": "Steel Leg",   "cost": 150,  "hp": 50,  "armor": 5,  "damage": 5,  "speed": 5,   "draw": 2, "shape": "rod",     "color": "#8f9aa6"},
	{"id": "leg_piston",   "kind": "leg", "name": "Piston Leg",  "cost": 450,  "hp": 60,  "armor": 10, "damage": 15, "speed": 10,  "draw": 3, "shape": "piston",  "color": "#4f86c6"},
	{"id": "leg_spring",   "kind": "leg", "name": "Spring Leg",  "cost": 800,  "hp": 50,  "armor": 5,  "damage": 5,  "speed": 30,  "draw": 3, "shape": "spring",  "color": "#2fb58a"},
	{"id": "leg_raptor",   "kind": "leg", "name": "Raptor Leg",  "cost": 1300, "hp": 60,  "armor": 10, "damage": 25, "speed": 25,  "draw": 4, "shape": "reverse", "color": "#c4501f"},
	{"id": "leg_pillar",   "kind": "leg", "name": "Pillar Leg",  "cost": 2000, "hp": 100, "armor": 25, "damage": 30, "speed": -10, "draw": 5, "shape": "pillar",  "color": "#c9a227"},
	{"id": "leg_thick",    "kind": "leg", "name": "Crusher Leg", "cost": 1400, "hp": 85,  "armor": 20, "damage": 20, "speed": 0,   "draw": 4, "shape": "thick",   "color": "#5e6b7d", "shop": false},
	# ---- reactors (inside the torso: never damaged)
	{"id": "junk_reactor",   "kind": "reactor", "name": "Car Battery", "cost": 0,    "output": 10, "color": "#ff9a3c"},
	{"id": "reactor_diesel", "kind": "reactor", "name": "Diesel Core", "cost": 300,  "output": 18, "color": "#ff5533"},
	{"id": "reactor_cell",   "kind": "reactor", "name": "Fuel Cell",   "cost": 900,  "output": 26, "color": "#ffd23f"},
	{"id": "reactor_fusion", "kind": "reactor", "name": "Fusion Core", "cost": 1800, "output": 36, "color": "#2ec4ff"},
	{"id": "reactor_arc",    "kind": "reactor", "name": "Arc Reactor", "cost": 3200, "output": 48, "color": "#7fffd4"},
]

const STARTER := {"head": "junk_head", "torso": "junk_torso", "arm_front": "junk_arm", "arm_back": "junk_arm",
		"leg_front": "junk_leg", "leg_back": "junk_leg", "reactor": "junk_reactor"}

# The championship: 10 fights, each harder than the last.
# think = seconds between CPU decisions, block = chance to block your attacks,
# smart = chance the CPU aims at your weakest part, scale = how big it is.
const OPPONENTS := [
	{"name": "TIN CAN", "hp": 0.8, "damage": 0.80, "speed": 0.90, "scale": 0.90, "think": 0.60, "block": 0.10, "smart": 0.0, "reward": 300,
	 "body": "#9a9a9a", "trim": "#5a5a5a", "eye": "#ffcc00",
	 "parts": {"head": "junk_head", "torso": "junk_torso", "arm_front": "junk_arm", "arm_back": "junk_arm", "leg_front": "junk_leg", "leg_back": "junk_leg"}},
	{"name": "RIVET", "hp": 0.9, "damage": 0.85, "speed": 0.95, "scale": 0.95, "think": 0.55, "block": 0.15, "smart": 0.1, "reward": 450,
	 "body": "#6d8b74", "trim": "#3e4f42", "eye": "#c6ff4d",
	 "parts": {"head": "head_box", "torso": "torso_box", "arm_front": "arm_rod", "arm_back": "arm_rod", "leg_front": "leg_steel", "leg_back": "leg_steel"}},
	{"name": "SCRAPJAW", "hp": 0.95, "damage": 0.90, "speed": 1.0, "scale": 1.0, "think": 0.50, "block": 0.20, "smart": 0.2, "reward": 600,
	 "body": "#8c6239", "trim": "#4a3420", "eye": "#ff7b00",
	 "parts": {"head": "head_jaw", "torso": "torso_vee", "arm_front": "arm_claw", "arm_back": "arm_claw", "leg_front": "leg_piston", "leg_back": "leg_piston"}},
	{"name": "GEARBOX", "hp": 1.0, "damage": 0.90, "speed": 0.90, "scale": 1.05, "think": 0.45, "block": 0.30, "smart": 0.3, "reward": 750,
	 "body": "#5e6b7d", "trim": "#c0c8d2", "eye": "#00e5ff",
	 "parts": {"head": "head_visor", "torso": "torso_plate", "arm_front": "arm_piston", "arm_back": "arm_piston", "leg_front": "leg_thick", "leg_back": "leg_thick"}},
	{"name": "HAMMERHEAD", "hp": 1.0, "damage": 0.92, "speed": 1.0, "scale": 1.0, "think": 0.40, "block": 0.30, "smart": 0.4, "reward": 900,
	 "body": "#3f5f8f", "trim": "#a0b4d0", "eye": "#ff3355",
	 "parts": {"head": "head_wedge", "torso": "torso_box", "arm_front": "arm_hammer", "arm_back": "arm_piston", "leg_front": "leg_piston", "leg_back": "leg_piston"}},
	{"name": "VOLTAGE", "hp": 1.0, "damage": 0.95, "speed": 1.15, "scale": 0.95, "think": 0.35, "block": 0.35, "smart": 0.5, "reward": 1100,
	 "body": "#d4c21f", "trim": "#2b2b2b", "eye": "#00b7ff",
	 "parts": {"head": "head_bulb", "torso": "torso_slim", "arm_front": "arm_claw", "arm_back": "arm_claw", "leg_front": "leg_spring", "leg_back": "leg_spring"}},
	{"name": "SLEDGE", "hp": 1.05, "damage": 0.95, "speed": 0.95, "scale": 1.10, "think": 0.30, "block": 0.42, "smart": 0.55, "reward": 1300,
	 "body": "#7a2e2e", "trim": "#d6c9a8", "eye": "#ffe14d",
	 "parts": {"head": "head_box", "torso": "torso_tank", "arm_front": "arm_hammer", "arm_back": "arm_hammer", "leg_front": "leg_pillar", "leg_back": "leg_pillar"}},
	{"name": "BRIMSTONE", "hp": 1.1, "damage": 1.00, "speed": 1.15, "scale": 1.05, "think": 0.26, "block": 0.48, "smart": 0.65, "reward": 1500,
	 "body": "#c4501f", "trim": "#1f1f1f", "eye": "#ffd000",
	 "parts": {"head": "head_horned", "torso": "torso_core", "arm_front": "arm_spike", "arm_back": "arm_spike", "leg_front": "leg_raptor", "leg_back": "leg_raptor"}},
	{"name": "JUGGERNAUT", "hp": 1.2, "damage": 1.05, "speed": 1.05, "scale": 1.20, "think": 0.22, "block": 0.54, "smart": 0.75, "reward": 1750,
	 "body": "#2f3a2f", "trim": "#8f9f8f", "eye": "#ff2020",
	 "parts": {"head": "head_visor", "torso": "torso_tank", "arm_front": "arm_bulky", "arm_back": "arm_bulky", "leg_front": "leg_pillar", "leg_back": "leg_pillar"}},
	{"name": "OVERLORD", "hp": 1.3, "damage": 1.10, "speed": 1.20, "scale": 1.25, "think": 0.18, "block": 0.60, "smart": 0.9, "reward": 2200,
	 "body": "#1a1a2e", "trim": "#e0b84a", "eye": "#ff00aa",
	 "parts": {"head": "head_mast", "torso": "torso_core", "arm_front": "arm_drill", "arm_back": "arm_hammer", "leg_front": "leg_raptor", "leg_back": "leg_raptor"}},
]
const EXHIBITION_REWARD := 900

var PARTS := {}          # id -> part definition (built from PART_LIST)

var money := START_MONEY
var inventory: Array = []   # [{uid, id, hp}]
var equipped := {}          # slot -> uid (-1 = empty)
var next_uid := 1
var paint := 0
var fight_index := 0        # next championship fight (0..9); 10 = finished
var wins := 0
var losses := 0
var champion := false
var story_seen: Array = []
var last_result := {}       # handed from the fight to the garage
var story_key := ""         # which story scene to show next
var story_return := ""      # scene to go to after the story
var settings := {"sound": true, "music": true, "shake": true, "button_size": 1, "difficulty": 1}


func _ready() -> void:
	for p in PART_LIST:
		var d: Dictionary = p.duplicate()
		for k in ["hp", "armor", "damage", "speed", "aim", "draw", "output"]:
			if not d.has(k):
				d[k] = 0
		if not d.has("shop"):
			d["shop"] = true
		if not d.has("size"):
			d["size"] = 1.0
		if not d.has("shape"):
			d["shape"] = ""
		PARTS[d["id"]] = d
	load_settings()
	new_game()   # sensible defaults so any scene can run on its own


# ---------------------------------------------------------------- inventory

func new_game() -> void:
	money = START_MONEY
	inventory = []
	equipped = {}
	next_uid = 1
	for slot in SLOTS:
		equipped[slot] = add_part(STARTER[slot])
	paint = 0
	fight_index = 0
	wins = 0
	losses = 0
	champion = false
	story_seen = []
	last_result = {}


func part_def(id: String) -> Dictionary:
	return PARTS.get(id, {})


func add_part(id: String, hp_ratio: float = 1.0) -> int:
	var uid := next_uid
	next_uid += 1
	inventory.append({"uid": uid, "id": id, "hp": float(part_def(id)["hp"]) * hp_ratio})
	return uid


func inst(uid: int) -> Dictionary:
	for p in inventory:
		if p["uid"] == uid:
			return p
	return {}


func equipped_inst(slot: String) -> Dictionary:
	return inst(equipped.get(slot, -1))


func slot_of_uid(uid: int) -> String:
	for slot in SLOTS:
		if equipped[slot] == uid:
			return slot
	return ""


func spares() -> Array:
	var out: Array = []
	for p in inventory:
		if slot_of_uid(p["uid"]) == "":
			out.append(p)
	return out


func shop_parts(kind: String) -> Array:
	var out: Array = []
	for p in PART_LIST:
		if p["kind"] == kind and PARTS[p["id"]]["shop"]:
			out.append(PARTS[p["id"]])
	return out


func is_wreck(p: Dictionary) -> bool:
	return part_def(p["id"])["kind"] != "reactor" and p["hp"] <= 0.0


func hp_ratio(p: Dictionary) -> float:
	var mx: float = part_def(p["id"])["hp"]
	return 1.0 if mx <= 0.0 else clampf(p["hp"] / mx, 0.0, 1.0)


func buy(id: String) -> String:
	var d := part_def(id)
	if money < d["cost"]:
		return "Not enough money."
	money -= d["cost"]
	var uid := add_part(id)
	for slot in SLOTS:
		if SLOT_KIND[slot] == d["kind"] and equipped[slot] == -1:
			equipped[slot] = uid
			return "Bought %s and fitted it to the %s." % [d["name"], SLOT_NAMES[slot]]
	return "Bought %s. It's in your Spares - equip it from there." % d["name"]


func equip(uid: int, slot: String) -> String:
	var p := inst(uid)
	if p.is_empty():
		return "That part is gone."
	var d := part_def(p["id"])
	if is_wreck(p):
		return "%s is a wreck. Rebuild it first." % d["name"]
	if SLOT_KIND[slot] != d["kind"]:
		return "A %s doesn't fit the %s." % [d["name"], SLOT_NAMES[slot]]
	var old_slot := slot_of_uid(uid)
	if old_slot != "":
		equipped[old_slot] = equipped[slot] if old_slot != slot else -1
	equipped[slot] = uid
	return "Fitted %s to the %s." % [d["name"], SLOT_NAMES[slot]]


func unequip(slot: String) -> void:
	if slot != "reactor":
		equipped[slot] = -1


func repair_cost(p: Dictionary) -> int:
	var d := part_def(p["id"])
	var missing := 1.0 - hp_ratio(p)
	if missing <= 0.0:
		return 0
	if is_wreck(p):
		return maxi(30, int(d["cost"] * 0.5))   # rebuilding a wreck
	return maxi(1, ceili(missing * maxf(20.0, d["cost"] * 0.2)))


func repair(uid: int) -> String:
	var p := inst(uid)
	var c := repair_cost(p)
	if c == 0:
		return "Already in perfect shape."
	if money < c:
		return "Not enough money to repair."
	money -= c
	p["hp"] = float(part_def(p["id"])["hp"])
	return "Repaired %s for $%d." % [part_def(p["id"])["name"], c]


func repair_all_cost() -> int:
	var total := 0
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty():
			total += repair_cost(p)
	return total


func repair_all() -> String:
	var c := repair_all_cost()
	if c == 0:
		return "Your robot is in perfect shape."
	if money < c:
		return "Repairing everything costs $%d. You can't afford it - repair parts one at a time." % c
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty():
			p["hp"] = float(part_def(p["id"])["hp"])
	money -= c
	return "Fully repaired for $%d." % c


func sell_value(p: Dictionary) -> int:
	return int(part_def(p["id"])["cost"] * 0.4 * hp_ratio(p))


func sell(uid: int) -> String:
	var p := inst(uid)
	if p.is_empty() or slot_of_uid(uid) != "":
		return "Unequip it before selling."
	var v := sell_value(p)
	money += v
	inventory.erase(p)
	return "Sold %s for $%d." % [part_def(p["id"])["name"], v]


func part_stat_text(d: Dictionary) -> String:
	if d["kind"] == "reactor":
		return "Power output %d" % d["output"]
	var bits: Array = ["HP %d" % d["hp"]]
	if d["armor"] != 0:
		bits.append("ARM %d%%" % d["armor"])
	if d["damage"] != 0:
		bits.append("DMG %+d%%" % d["damage"])
	if d["speed"] != 0:
		bits.append("SPD %+d%%" % d["speed"])
	if d["aim"] != 0:
		bits.append("AIM %+d%%" % d["aim"])
	if d["output"] != 0:
		bits.append("PWR +%d" % d["output"])
	bits.append("Power %d" % d["draw"])
	return "  ".join(bits)


# ---------------------------------------------------------------- stats

func can_fight() -> bool:
	return equipped["head"] != -1 and equipped["torso"] != -1


func stats() -> Dictionary:
	var used := 0
	var output := 0
	var arm_dmg := 0.0
	var arms := 0
	var leg_spd := 0.0
	var legs := 0
	var torso_spd := 0.0
	var aim := 0.0
	var armor := 0.0
	var parts := 0
	for slot in SLOTS:
		var p := equipped_inst(slot)
		if p.is_empty():
			continue
		var d := part_def(p["id"])
		used += d["draw"]
		output += d["output"]
		match SLOT_KIND[slot]:
			"arm":
				arms += 1
				arm_dmg += d["damage"]
			"leg":
				legs += 1
				leg_spd += d["speed"]
			"torso":
				torso_spd = d["speed"]
			"head":
				aim = d["aim"]
		if slot != "reactor":
			armor += d["armor"]
			parts += 1
	var eff := 1.0 if used <= output or used == 0 else float(output) / used
	var leg_factor: float = [0.35, 0.65, 1.0][legs]
	var speed := (100.0 + (leg_spd / maxf(1, legs)) + torso_spd) * leg_factor * eff
	var damage := (100.0 + arm_dmg / maxf(1, arms)) * eff if arms > 0 else 0.0
	var t := equipped_inst("torso")
	return {
		"power_used": used, "power_output": output, "efficiency": eff,
		"core": 0.0 if t.is_empty() else t["hp"], "core_max": 0.0 if t.is_empty() else float(part_def(t["id"])["hp"]),
		"damage": damage, "speed": speed, "aim": aim, "armor": armor / maxf(1, parts),
		"arms": arms, "legs": legs,
	}


## Everything the fight needs to build the player's robot.
func player_spec() -> Dictionary:
	var parts := {}
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if p.is_empty():
			parts[slot] = {}
		else:
			var d := part_def(p["id"])
			parts[slot] = {"id": d["id"], "hp": p["hp"], "max_hp": float(d["hp"]), "armor": d["armor"],
					"damage": d["damage"], "speed": d["speed"], "aim": d["aim"],
					"shape": d["shape"], "size": d["size"], "color": Color(d["color"])}
	var s := stats()
	return {"name": ROBOT_NAME, "parts": parts, "efficiency": s["efficiency"], "damage_mult": 1.0,
			"speed_mult": 1.0, "scale": 1.0, "trim": Color(PAINTS[paint]["color"]),
			"eye": Color(part_def(equipped_inst("reactor")["id"])["color"])}


func current_opponent_index() -> int:
	return OPPONENTS.size() - 1 if champion else clampi(fight_index, 0, OPPONENTS.size() - 1)


func current_opponent() -> Dictionary:
	return OPPONENTS[current_opponent_index()]


func current_reward() -> int:
	return EXHIBITION_REWARD if champion else current_opponent()["reward"]


func opponent_spec(index: int) -> Dictionary:
	var o: Dictionary = OPPONENTS[index]
	var body := Color(o["body"])
	var parts := {}
	for slot in BODY_SLOTS:
		var d := part_def(o["parts"][slot])
		var c := body
		match SLOT_KIND[slot]:
			"arm":
				c = body.lightened(0.12)
			"leg":
				c = body.darkened(0.18)
			"head":
				c = body.lerp(Color(d["color"]), 0.3)
		var mx: float = d["hp"] * o["hp"]
		parts[slot] = {"id": d["id"], "hp": mx, "max_hp": mx, "armor": d["armor"],
				"damage": d["damage"], "speed": d["speed"], "aim": d["aim"],
				"shape": d["shape"], "size": d["size"], "color": c}
	return {"name": o["name"], "parts": parts, "efficiency": 1.0, "damage_mult": o["damage"],
			"speed_mult": o["speed"], "scale": o["scale"], "trim": Color(o["trim"]), "eye": Color(o["eye"])}


## Build the look dictionary that RobotArt draws from a spec (player or opponent).
static func look_from_spec(spec: Dictionary) -> Dictionary:
	var parts := {}
	for slot in BODY_SLOTS:
		var p: Dictionary = spec["parts"][slot]
		if p.is_empty():
			parts[slot] = {"alive": false}
		else:
			parts[slot] = {"alive": p["hp"] > 0.0 or slot == "torso", "shape": p["shape"], "size": p["size"],
					"color": p["color"], "health": clampf(p["hp"] / p["max_hp"], 0.0, 1.0)}
	return {"parts": parts, "trim": spec["trim"], "eye": spec["eye"], "scale": spec["scale"]}


func player_look() -> Dictionary:
	return look_from_spec(player_spec())


# ---------------------------------------------------------------- fight results

## Called when a championship match ends.
## part_hp: slot -> remaining hp for the player's parts. destroyed: number of enemy parts ripped off.
## salvage_ids: enemy part ids that were ripped off (some may be salvaged).
func record_result(won: bool, part_hp: Dictionary, destroyed: int, salvage_ids: Array) -> Dictionary:
	var o := current_opponent()
	var base: int = current_reward()
	var reward: int = base if won else int(base * 0.35)
	var bonus := destroyed * 75
	money += reward + bonus

	# carry the damage over, lose destroyed parts
	var lost: Array = []
	var wrecked: Array = []
	for slot in part_hp:
		var p := equipped_inst(slot)
		if p.is_empty():
			continue
		p["hp"] = maxf(0.0, part_hp[slot])
		if slot == "torso":
			p["hp"] = maxf(1.0, p["hp"])   # the core survives a knockout, badly dented
		if p["hp"] <= 0.0:
			equipped[slot] = -1
			if randf() < 0.5:
				# your crew dragged the wreck out of the ring: rebuild it for half price
				p["hp"] = 0.0
				wrecked.append(part_def(p["id"])["name"])
			else:
				lost.append("%s (%s)" % [part_def(p["id"])["name"], SLOT_NAMES[slot]])
				inventory.erase(p)

	# salvage: winners get a chance to keep ripped-off enemy parts
	var salvaged: Array = []
	if won:
		for id in salvage_ids:
			if randf() < 0.4:
				add_part(id, 0.25)
				salvaged.append(part_def(id)["name"])

	var was_champion := champion
	if won:
		wins += 1
		if not champion:
			fight_index += 1
			if fight_index >= OPPONENTS.size():
				champion = true
	else:
		losses += 1
	last_result = {"won": won, "reward": reward, "bonus": bonus, "opponent": o["name"], "lost": lost, "wrecked": wrecked,
			"salvaged": salvaged, "champion": champion and not was_champion}
	save_game()
	return last_result


# ---------------------------------------------------------------- story

func queue_story(key: String, return_scene: String) -> bool:
	if story_seen.has(key) or not Story.SCENES.has(key):
		return false
	story_key = key
	story_return = return_scene
	return true


func mark_story_seen(key: String) -> void:
	if not story_seen.has(key):
		story_seen.append(key)


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION, "money": money, "inventory": inventory, "equipped": equipped,
		"next_uid": next_uid, "paint": paint, "fight_index": fight_index, "wins": wins,
		"losses": losses, "champion": champion, "story_seen": story_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


## Returns "" on success, or an error message.
func load_game() -> String:
	if not has_save():
		return "No save file."
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return "Couldn't open the save file."
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "The save file is damaged."
	if int(data.get("version", 1)) != SAVE_VERSION:
		return "That save is from an older version of the game. Please start a New Game."
	new_game()
	inventory = []
	for p in data.get("inventory", []):
		if not part_def(str(p.get("id", ""))).is_empty():
			inventory.append({"uid": int(p["uid"]), "id": str(p["id"]), "hp": float(p["hp"])})
	var eq: Dictionary = data.get("equipped", {})
	for slot in SLOTS:
		var uid := int(eq.get(slot, -1))
		equipped[slot] = uid if not inst(uid).is_empty() else -1
	if equipped["reactor"] == -1:
		equipped["reactor"] = add_part("junk_reactor")
	next_uid = maxi(int(data.get("next_uid", 1)), next_uid)
	for p in inventory:
		next_uid = maxi(next_uid, p["uid"] + 1)
	money = int(data.get("money", START_MONEY))
	paint = clampi(int(data.get("paint", 0)), 0, PAINTS.size() - 1)
	fight_index = int(data.get("fight_index", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	champion = bool(data.get("champion", false))
	story_seen = data.get("story_seen", [])
	return ""


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
