extends Node

# helper scripts, loaded by path so the game also runs without an editor scan
const Arena = preload("res://arena.gd")
const I18n = preload("res://i18n.gd")
const Catalog = preload("res://catalog.gd")
const PilotArt = preload("res://pilot_art.gd")
const RobotArt = preload("res://robot_art.gd")
const Specials = preload("res://specials.gd")
const Story = preload("res://story_data.gd")
const UI = preload("res://ui.gd")
## Global game state (autoload "GameData"):
## parts catalog, inventory of part instances (each with its own health), what's equipped,
## championship progress, money, story progress, save/load, settings.

const OLD_SAVE_PATH := "user://savegame.json"   # single save from earlier versions -> becomes slot 1
const SAVE_SLOTS := 3
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 3
const START_MONEY := -1000   # default: you start in debt (back rent to Gus) and climb out
const MONTH_WEEKS := 4        # every 4 weeks...
const LIVING_COST := 1000     # ...rent and food come out of your balance (default)
## Money difficulty (Settings), separate from CPU difficulty
const START_MONEY_OPTIONS := [1000, 300, 0, -1000, -2000, -3000]
const LIVING_COST_OPTIONS := [0, 250, 500, 1000, 1500, 2000]
const DEFAULT_ROBOT := "ECHO"
const Career = preload("res://career.gd")
const World = preload("res://world.gd")
const PILOT_NAMES := ["Rook", "Marisol", "Dex", "Kit", "Juno", "Tavi", "Bram", "Nia", "Otto", "Zara", "Lio", "Mags",
		"Finn", "Ines", "Cass", "Rafa", "Wren", "Bo", "Sully", "Pia", "Grit", "Nova", "Ash", "Teo"]
const ROBOT_FIRST := ["ECHO", "RUSTY", "BOLT", "PISTON", "SPARKY", "TANK", "GIZMO", "COPPER", "TORQUE", "DYNAMO",
		"SPROCKET", "ZIPPY", "BRUISER", "WIDGET", "AXLE", "NUTS", "BLITZ", "CRANK"]
const ROBOT_LAST := ["", "", "", " JR", " MK II", " 3000", "-9", " PRIME", " ZERO", "-X"]

# Robot slots. Front = the side facing the camera (drawn in front).
const SLOTS := ["head", "head2", "torso", "arm_front", "arm_back", "arm_front2", "arm_back2", "leg_front", "leg_back", "back", "reactor"]
const SLOT_NAMES := {"head": "Head", "head2": "Second Head", "torso": "Torso", "arm_front": "Front Arm", "arm_back": "Back Arm",
		"arm_front2": "Lower Front Arm", "arm_back2": "Lower Back Arm",
		"leg_front": "Front Leg", "leg_back": "Back Leg", "back": "Back Gear", "reactor": "Reactor"}
const SLOT_KIND := {"head": "head", "head2": "head", "torso": "torso", "arm_front": "arm", "arm_back": "arm",
		"arm_front2": "arm", "arm_back2": "arm", "leg_front": "leg", "leg_back": "leg", "back": "back", "reactor": "reactor"}
const EXTRA_SLOTS := ["head2", "arm_front2", "arm_back2"]   # only exist on torsos with mount points
const KINDS := ["head", "torso", "arm", "leg", "back", "reactor"]
const KIND_NAMES := {"head": "Heads", "torso": "Torsos", "arm": "Arms", "leg": "Legs", "back": "Back", "reactor": "Reactors"}
const UNDAMAGEABLE := ["reactor", "back"]   # kinds that sit inside/behind the robot and never take damage
const BODY_SLOTS := ["head", "head2", "torso", "arm_front", "arm_back", "arm_front2", "arm_back2", "leg_front", "leg_back"]
const STOCK_SIZE := 10
const REROLL_COST := 150

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
#   chips    - (heads) how many special-move chips the robot can run
#   gimmick  - a gadget (see Specials.GADGETS): active ones get a button in fights
#   shape    - how it looks; size - how big it's drawn; shop - false = only from salvage
const PART_LIST := [
	# ---- heads
	{"id": "junk_head",    "kind": "head", "name": "Junk Bucket",   "cost": 0,    "hp": 30, "armor": 0,  "aim": 0,  "draw": 1, "chips": 1, "shape": "bucket",  "color": "#8a8f98"},
	{"id": "head_box",     "kind": "head", "name": "Sensor Box",    "cost": 150,  "hp": 40, "armor": 5,  "aim": 5,  "draw": 2, "chips": 2, "shape": "box",     "color": "#6d7f91"},
	{"id": "head_dome",    "kind": "head", "name": "Dome Scanner",  "cost": 400,  "hp": 45, "armor": 10, "aim": 10, "draw": 2, "chips": 2, "shape": "dome",    "color": "#4fa3d1"},
	{"id": "head_cyclops", "kind": "head", "name": "Cyclops Eye",   "cost": 850,  "hp": 40, "armor": 5,  "aim": 25, "draw": 3, "chips": 3, "shape": "cyclops", "color": "#c94f4f"},
	{"id": "head_visor",   "kind": "head", "name": "Visor Helm",    "cost": 1300, "hp": 60, "armor": 20, "aim": 10, "draw": 3, "chips": 2, "shape": "visor",   "color": "#3f5f8f"},
	{"id": "head_horned",  "kind": "head", "name": "Horned Crown",  "cost": 2400, "hp": 75, "armor": 25, "aim": 15, "draw": 5, "chips": 3, "shape": "horned",  "color": "#d4af37"},
	{"id": "head_jaw",     "kind": "head", "name": "Bear-Trap Jaw", "cost": 900,  "hp": 55, "armor": 10, "aim": 5,  "draw": 3, "chips": 2, "shape": "skull",   "color": "#8c6239", "shop": false},
	{"id": "head_wedge",   "kind": "head", "name": "Shark Wedge",   "cost": 1000, "hp": 55, "armor": 15, "aim": 10, "draw": 3, "chips": 2, "shape": "wedge",   "color": "#3f5f8f", "shop": false},
	{"id": "head_bulb",    "kind": "head", "name": "Tesla Bulb",    "cost": 1100, "hp": 45, "armor": 5,  "aim": 20, "draw": 3, "chips": 3, "shape": "bulb",    "color": "#d4c21f", "shop": false},
	{"id": "head_tv",      "kind": "head", "name": "CRT Head",      "cost": 600,  "hp": 45, "armor": 5,  "aim": 10, "draw": 2, "chips": 3, "shape": "tv",      "color": "#5a6b4a"},
	{"id": "head_dish",    "kind": "head", "name": "Radar Dish",    "cost": 1600, "hp": 40, "armor": 5,  "aim": 20, "draw": 3, "chips": 4, "shape": "dish",    "color": "#9aa4ad"},
	{"id": "head_laser",   "kind": "head", "name": "Laser Eye",     "cost": 1800, "hp": 50, "armor": 10, "aim": 15, "draw": 4, "chips": 2, "shape": "laser",   "color": "#7a1f2b", "gimmick": "laser"},
	{"id": "head_mast",    "kind": "head", "name": "Command Mast",  "cost": 2800, "hp": 70, "armor": 20, "aim": 30, "draw": 5, "chips": 4, "shape": "tall",    "color": "#1a1a2e", "shop": false},
	# ---- torsos (the torso is the robot's core: if it breaks, it's a knockout)
	{"id": "junk_torso",   "kind": "torso", "name": "Oil Drum",      "cost": 0,    "hp": 80,  "armor": 0,  "speed": 0,   "draw": 1, "shape": "barrel", "color": "#7d7466"},
	{"id": "torso_box",    "kind": "torso", "name": "Steel Box",     "cost": 200,  "hp": 100, "armor": 5,  "speed": 0,   "draw": 2, "shape": "box",    "color": "#5b6f8a"},
	{"id": "torso_vee",    "kind": "torso", "name": "Vee Frame",     "cost": 600,  "hp": 115, "armor": 10, "speed": 5,   "draw": 3, "shape": "vee",    "color": "#3d8f6a"},
	{"id": "torso_plate",  "kind": "torso", "name": "Plated Barrel", "cost": 1200, "hp": 140, "armor": 15, "speed": 0,   "draw": 4, "shape": "barrel", "color": "#8f6b3d", "size": 1.15},
	{"id": "torso_core",   "kind": "torso", "name": "Reactor Chest", "cost": 1500, "hp": 125, "armor": 10, "speed": 0,   "draw": 3, "shape": "core",   "color": "#2e7c9e", "output": 6},
	{"id": "torso_tank",   "kind": "torso", "name": "Tank Hull",     "cost": 2800, "hp": 180, "armor": 25, "speed": -10, "draw": 6, "shape": "tank",   "color": "#b8860b"},
	{"id": "torso_rib",    "kind": "torso", "name": "Ribcage Frame", "cost": 500,  "hp": 90,  "armor": 0,  "speed": 15,  "draw": 2, "shape": "ribcage", "color": "#9a9184"},
	{"id": "torso_hex",    "kind": "torso", "name": "Hex Bunker",    "cost": 2000, "hp": 160, "armor": 20, "speed": -5,  "draw": 5, "shape": "hex",    "color": "#4a5568"},
	{"id": "torso_cannon", "kind": "torso", "name": "Chest Cannon",  "cost": 2200, "hp": 120, "armor": 10, "speed": 0,   "draw": 5, "shape": "cannon", "color": "#6b4f2a", "gimmick": "cannon"},
	{"id": "torso_slim",   "kind": "torso", "name": "Racing Frame",  "cost": 1000, "hp": 95,  "armor": 5,  "speed": 15,  "draw": 3, "shape": "slim",   "color": "#d4c21f", "shop": false},
	# ---- arms
	{"id": "junk_arm",     "kind": "arm", "name": "Pipe Arm",    "cost": 0,    "hp": 30, "armor": 0,  "damage": 0,  "speed": 0,   "draw": 1, "shape": "rod",    "color": "#8a7f74", "size": 0.8},
	{"id": "arm_rod",      "kind": "arm", "name": "Steel Rod",   "cost": 150,  "hp": 45, "armor": 5,  "damage": 10, "speed": 5,   "draw": 2, "shape": "rod",    "color": "#8f9aa6"},
	{"id": "arm_piston",   "kind": "arm", "name": "Piston Arm",  "cost": 450,  "hp": 55, "armor": 10, "damage": 25, "speed": 0,   "draw": 3, "shape": "piston", "color": "#6c8fb3"},
	{"id": "arm_claw",     "kind": "arm", "name": "Claw Arm",    "cost": 700,  "hp": 50, "armor": 5,  "damage": 20, "speed": 15,  "draw": 3, "shape": "claw",   "color": "#3d8f6a"},
	{"id": "arm_spike",    "kind": "arm", "name": "Spike Fist",  "cost": 1200, "hp": 55, "armor": 10, "damage": 40, "speed": 5,   "draw": 4, "shape": "spike",  "color": "#c0392b"},
	{"id": "arm_bulky",    "kind": "arm", "name": "Brawler Arm", "cost": 1500, "hp": 75, "armor": 15, "damage": 35, "speed": 0,   "draw": 4, "shape": "bulky",  "color": "#7a4fb3"},
	{"id": "arm_hammer",   "kind": "arm", "name": "Hammer Arm",  "cost": 2500, "hp": 80, "armor": 15, "damage": 60, "speed": -15, "draw": 6, "shape": "hammer", "color": "#e0a526"},
	{"id": "arm_rocket",   "kind": "arm", "name": "Rocket Fist", "cost": 1100, "hp": 50, "armor": 5,  "damage": 20, "speed": 0,   "draw": 4, "shape": "rocket", "color": "#d0562b", "gimmick": "rocket_fist"},
	{"id": "arm_grapple",  "kind": "arm", "name": "Grapple Claw","cost": 1000, "hp": 55, "armor": 10, "damage": 15, "speed": 5,   "draw": 4, "shape": "grapple","color": "#4a8f8a", "gimmick": "grapple"},
	{"id": "arm_saw",      "kind": "arm", "name": "Buzzsaw Arm", "cost": 1900, "hp": 55, "armor": 5,  "damage": 45, "speed": 10,  "draw": 5, "shape": "saw",    "color": "#b0b6bd"},
	{"id": "arm_drill",    "kind": "arm", "name": "Drill Arm",   "cost": 2000, "hp": 60, "armor": 10, "damage": 50, "speed": 5,   "draw": 5, "shape": "drill",  "color": "#9aa0a6", "shop": false},
	# ---- legs (damage = kick power)
	{"id": "junk_leg",     "kind": "leg", "name": "Stilt Leg",   "cost": 0,    "hp": 35,  "armor": 0,  "damage": 0,  "speed": -5,  "draw": 1, "shape": "rod",     "color": "#77706a", "size": 0.8},
	{"id": "leg_steel",    "kind": "leg", "name": "Steel Leg",   "cost": 150,  "hp": 50,  "armor": 5,  "damage": 5,  "speed": 5,   "draw": 2, "shape": "rod",     "color": "#8f9aa6"},
	{"id": "leg_piston",   "kind": "leg", "name": "Piston Leg",  "cost": 450,  "hp": 60,  "armor": 10, "damage": 15, "speed": 10,  "draw": 3, "shape": "piston",  "color": "#4f86c6"},
	{"id": "leg_spring",   "kind": "leg", "name": "Spring Leg",  "cost": 800,  "hp": 50,  "armor": 5,  "damage": 5,  "speed": 30,  "draw": 3, "shape": "spring",  "color": "#2fb58a"},
	{"id": "leg_raptor",   "kind": "leg", "name": "Raptor Leg",  "cost": 1300, "hp": 60,  "armor": 10, "damage": 25, "speed": 25,  "draw": 4, "shape": "reverse", "color": "#c4501f"},
	{"id": "leg_pillar",   "kind": "leg", "name": "Pillar Leg",  "cost": 2000, "hp": 100, "armor": 25, "damage": 30, "speed": -10, "draw": 5, "shape": "pillar",  "color": "#c9a227"},
	{"id": "leg_pogo",     "kind": "leg", "name": "Pogo Leg",    "cost": 900,  "hp": 45,  "armor": 0,  "damage": 10, "speed": 10,  "draw": 3, "shape": "pogo",    "color": "#e05a9a", "gimmick": "high_jump"},
	{"id": "leg_wheel",    "kind": "leg", "name": "Wheel Leg",   "cost": 1400, "hp": 55,  "armor": 10, "damage": 0,  "speed": 45,  "draw": 4, "shape": "wheel",   "color": "#444a55"},
	{"id": "leg_tread",    "kind": "leg", "name": "Tread Leg",   "cost": 2300, "hp": 110, "armor": 30, "damage": 20, "speed": -5,  "draw": 6, "shape": "tread",   "color": "#556b2f"},
	{"id": "leg_thick",    "kind": "leg", "name": "Crusher Leg", "cost": 1400, "hp": 85,  "armor": 20, "damage": 20, "speed": 0,   "draw": 4, "shape": "thick",   "color": "#5e6b7d", "shop": false},
	# Junk you can build your first robot from on the new-game screen: same weak stats as the
	# junk parts above, different looks. Not sold.
	{"id": "junk_head_box",   "kind": "head", "name": "Scrap Crate",     "cost": 0, "hp": 30, "armor": 0, "aim": 0, "draw": 1, "chips": 1, "shape": "box",   "color": "#7f7a6e", "shop": false},
	{"id": "junk_head_tv",    "kind": "head", "name": "Busted TV",       "cost": 0, "hp": 30, "armor": 0, "aim": 0, "draw": 1, "chips": 1, "shape": "tv",    "color": "#6b6352", "shop": false},
	{"id": "junk_head_dome",  "kind": "head", "name": "Salad Bowl",      "cost": 0, "hp": 30, "armor": 0, "aim": 0, "draw": 1, "chips": 1, "shape": "dome",  "color": "#8c9196", "shop": false},
	{"id": "junk_torso_box",  "kind": "torso", "name": "Old Toolbox",    "cost": 0, "hp": 80, "armor": 0, "speed": 0, "draw": 1, "shape": "box",     "color": "#8a4b3a", "shop": false},
	{"id": "junk_torso_crate", "kind": "torso", "name": "Fruit Crate",   "cost": 0, "hp": 80, "armor": 0, "speed": 0, "draw": 1, "shape": "crate",   "color": "#8d7350", "shop": false},
	{"id": "junk_torso_rib",  "kind": "torso", "name": "Bed Frame",      "cost": 0, "hp": 80, "armor": 0, "speed": 0, "draw": 1, "shape": "ribcage", "color": "#7b7b80", "shop": false},
	{"id": "junk_arm_piston", "kind": "arm", "name": "Shock Absorber",   "cost": 0, "hp": 30, "armor": 0, "damage": 0, "speed": 0, "draw": 1, "shape": "piston", "color": "#7a7f86", "size": 0.8, "shop": false},
	{"id": "junk_arm_claw",   "kind": "arm", "name": "Grabber Tongs",    "cost": 0, "hp": 30, "armor": 0, "damage": 0, "speed": 0, "draw": 1, "shape": "claw",   "color": "#6f7a6a", "size": 0.8, "shop": false},
	{"id": "junk_arm_blade",  "kind": "arm", "name": "Bent Shovel",      "cost": 0, "hp": 30, "armor": 0, "damage": 0, "speed": 0, "draw": 1, "shape": "blade",  "color": "#6e6458", "size": 0.8, "shop": false},
	{"id": "junk_leg_piston", "kind": "leg", "name": "Jack Stand",       "cost": 0, "hp": 35, "armor": 0, "damage": 0, "speed": -5, "draw": 1, "shape": "piston", "color": "#7a6f62", "size": 0.8, "shop": false},
	{"id": "junk_leg_wheel",  "kind": "leg", "name": "Cart Wheel",       "cost": 0, "hp": 35, "armor": 0, "damage": 0, "speed": -5, "draw": 1, "shape": "wheel",  "color": "#5d5a55", "size": 0.8, "shop": false},
	{"id": "junk_leg_thick",  "kind": "leg", "name": "Fence Post",       "cost": 0, "hp": 35, "armor": 0, "damage": 0, "speed": -5, "draw": 1, "shape": "thick",  "color": "#6b5d4c", "size": 0.8, "shop": false},
	# ---- reactors (inside the torso: never damaged)
	# Margo's forklift parts (TIN CAN): as weak as junk, but they look the part. Not sold, only salvaged.
	{"id": "fork_head",    "kind": "head", "name": "Forklift Cab",     "cost": 90,  "hp": 30, "armor": 2, "aim": 0, "draw": 1, "chips": 1, "shape": "box", "color": "#e0a81c", "shop": false},
	{"id": "fork_torso",   "kind": "torso", "name": "Forklift Chassis", "cost": 120, "hp": 82, "armor": 3, "speed": -5, "draw": 1, "shape": "crate", "color": "#e0a81c", "shop": false},
	{"id": "fork_arm",     "kind": "arm", "name": "Lift Fork",          "cost": 80,  "hp": 30, "armor": 0, "damage": 2, "speed": -5, "draw": 1, "shape": "blade", "color": "#5a5a5a", "size": 0.9, "shop": false},
	{"id": "fork_leg",     "kind": "leg", "name": "Forklift Wheel",     "cost": 90,  "hp": 34, "armor": 2, "damage": 0, "speed": 0, "draw": 1, "shape": "wheel", "color": "#2b2b2b", "size": 0.9, "shop": false},
	{"id": "junk_reactor",   "kind": "reactor", "name": "Car Battery", "cost": 0,    "output": 10, "color": "#ff9a3c"},
	{"id": "reactor_diesel", "kind": "reactor", "name": "Diesel Core", "cost": 300,  "output": 18, "color": "#ff5533"},
	{"id": "reactor_cell",   "kind": "reactor", "name": "Fuel Cell",   "cost": 900,  "output": 26, "color": "#ffd23f"},
	{"id": "reactor_fusion", "kind": "reactor", "name": "Fusion Core", "cost": 1800, "output": 36, "color": "#2ec4ff"},
	{"id": "reactor_arc",    "kind": "reactor", "name": "Arc Reactor", "cost": 3200, "output": 48, "color": "#7fffd4"},
	{"id": "reactor_cap",    "kind": "reactor", "name": "Capacitor Bank",  "cost": 1300, "output": 24, "color": "#b388ff", "gimmick": "emp"},
	{"id": "reactor_over",   "kind": "reactor", "name": "Overcharge Core", "cost": 1500, "output": 30, "color": "#ff2a6d", "gimmick": "overcharge"},
	{"id": "reactor_regen",  "kind": "reactor", "name": "Regen Core",      "cost": 2000, "output": 28, "color": "#5cff9d", "gimmick": "regen"},
	# ---- back gear (worn on the back: never damaged)
	{"id": "back_battery",   "kind": "back", "name": "Battery Pack",     "cost": 700,  "draw": 0, "output": 6, "shape": "battery", "color": "#c9a227"},
	{"id": "back_spikes",    "kind": "back", "name": "Spike Armor",      "cost": 600,  "draw": 1, "shape": "spikes",  "color": "#8a8f98", "gimmick": "thorns"},
	{"id": "back_booster",   "kind": "back", "name": "Booster Rockets",  "cost": 900,  "draw": 3, "shape": "booster", "color": "#c94f4f", "gimmick": "booster"},
	{"id": "back_jet",       "kind": "back", "name": "Jet Pack",         "cost": 1200, "draw": 3, "shape": "jet",     "color": "#6d7f91", "gimmick": "double_jump"},
	{"id": "back_shield",    "kind": "back", "name": "Shield Generator", "cost": 1700, "draw": 5, "shape": "shield",  "color": "#4fa3d1", "gimmick": "shield"},
]

## The junk your first robot can be built from (new-game screen): all equally weak.
const STARTER_OPTIONS := {"head": ["junk_head", "junk_head_box", "junk_head_tv", "junk_head_dome"],
		"torso": ["junk_torso", "junk_torso_box", "junk_torso_crate", "junk_torso_rib"],
		"arm": ["junk_arm", "junk_arm_piston", "junk_arm_claw", "junk_arm_blade"],
		"leg": ["junk_leg", "junk_leg_piston", "junk_leg_wheel", "junk_leg_thick"]}
const STARTER := {"head": "junk_head", "torso": "junk_torso", "arm_front": "junk_arm", "arm_back": "junk_arm",
		"leg_front": "junk_leg", "leg_back": "junk_leg", "reactor": "junk_reactor"}

# The championship: 10 fights, each harder than the last.
# think = seconds between CPU decisions, block = chance to block your attacks,
# smart = chance the CPU aims at your weakest part, scale = how big it is.
const OPPONENTS := [
	{"name": "TIN CAN", "pilot": "MARGO", "style": "striker", "hp": 0.8, "damage": 0.80, "speed": 0.90, "scale": 0.90, "think": 0.60, "block": 0.10, "smart": 0.0, "reward": 300,
	 "body": "#e0a81c", "trim": "#2b2b2b", "eye": "#ff6a00",
	 "parts": {"head": "fork_head", "torso": "fork_torso", "arm_front": "fork_arm", "arm_back": "fork_arm", "leg_front": "fork_leg", "leg_back": "fork_leg"}, "specials": []},
	{"name": "RIVET", "pilot": "BRUNO", "style": "tank", "hp": 0.9, "damage": 0.85, "speed": 0.95, "scale": 0.95, "think": 0.55, "block": 0.15, "smart": 0.1, "reward": 450,
	 "body": "#6d8b74", "trim": "#3e4f42", "eye": "#c6ff4d",
	 "parts": {"head": "head_box", "torso": "torso_rib", "arm_front": "arm_rod", "arm_back": "arm_rod", "leg_front": "leg_steel", "leg_back": "leg_steel"}, "specials": ["shoulder_charge"]},
	{"name": "SCRAPJAW", "pilot": "SKAR", "style": "mechanic", "hp": 0.95, "damage": 0.90, "speed": 1.0, "scale": 1.0, "think": 0.50, "block": 0.20, "smart": 0.2, "reward": 600,
	 "body": "#8c6239", "trim": "#4a3420", "eye": "#ff7b00",
	 "parts": {"head": "head_jaw", "torso": "scrap_hydra", "head2": "head_box", "arm_front": "arm_claw", "arm_back": "arm_claw", "leg_front": "leg_piston", "leg_back": "leg_piston"}, "specials": ["grab_slam", "bolt_toss"]},
	{"name": "GEARBOX", "pilot": "", "style": "tank", "hp": 1.0, "damage": 0.90, "speed": 0.90, "scale": 1.05, "think": 0.45, "block": 0.30, "smart": 0.3, "reward": 750,
	 "body": "#5e6b7d", "trim": "#c0c8d2", "eye": "#00e5ff",
	 "parts": {"head": "head_visor", "torso": "torso_plate", "arm_front": "arm_piston", "arm_back": "arm_piston", "leg_front": "leg_thick", "leg_back": "leg_thick", "back": "back_spikes"}, "specials": ["counter_protocol", "shoulder_charge"]},
	{"name": "HAMMERHEAD", "pilot": "ROSA", "style": "striker", "hp": 1.0, "damage": 0.92, "speed": 1.0, "scale": 1.0, "think": 0.40, "block": 0.30, "smart": 0.4, "reward": 900,
	 "body": "#3f5f8f", "trim": "#a0b4d0", "eye": "#ff3355",
	 "parts": {"head": "head_wedge", "torso": "torso_box", "arm_front": "arm_hammer", "arm_back": "arm_rocket", "leg_front": "leg_piston", "leg_back": "leg_piston"}, "specials": ["haymaker", "rocket_punch"]},
	{"name": "VOLTAGE", "pilot": "NIK & NAT", "style": "specialist", "hp": 1.0, "damage": 0.95, "speed": 1.15, "scale": 0.95, "think": 0.35, "block": 0.35, "smart": 0.5, "reward": 1100,
	 "body": "#d4c21f", "trim": "#2b2b2b", "eye": "#00b7ff",
	 "parts": {"head": "head_bulb", "torso": "torso_slim", "arm_front": "arm_claw", "arm_back": "arm_claw", "leg_front": "leg_pogo", "leg_back": "leg_spring", "back": "back_jet", "reactor": "reactor_cap"}, "specials": ["lightning_legs", "emp_pulse", "dive_stomp"]},
	{"name": "SLEDGE", "pilot": "BULL", "style": "tank", "hp": 1.05, "damage": 0.95, "speed": 0.95, "scale": 1.10, "think": 0.30, "block": 0.42, "smart": 0.55, "reward": 1300,
	 "body": "#7a2e2e", "trim": "#d6c9a8", "eye": "#ffe14d",
	 "parts": {"head": "head_tv", "torso": "torso_hex", "arm_front": "arm_hammer", "arm_back": "arm_hammer", "leg_front": "leg_pillar", "leg_back": "leg_pillar", "reactor": "reactor_over"}, "specials": ["haymaker", "grab_slam"]},
	{"name": "BRIMSTONE", "pilot": "", "style": "striker", "hp": 1.1, "damage": 1.00, "speed": 1.15, "scale": 1.05, "think": 0.26, "block": 0.48, "smart": 0.65, "reward": 1500,
	 "body": "#c4501f", "trim": "#1f1f1f", "eye": "#ffd000",
	 "parts": {"head": "head_laser", "torso": "torso_core", "arm_front": "arm_spike", "arm_back": "arm_saw", "leg_front": "leg_raptor", "leg_back": "leg_raptor", "back": "back_booster"}, "specials": ["tornado_kick", "rocket_punch", "bolt_toss"]},
	{"name": "JUGGERNAUT", "pilot": "IRONSIDE", "style": "mechanic", "hp": 1.2, "damage": 1.05, "speed": 1.05, "scale": 1.20, "think": 0.22, "block": 0.54, "smart": 0.75, "reward": 1750,
	 "body": "#2f3a2f", "trim": "#8f9f8f", "eye": "#ff2020",
	 "parts": {"head": "head_visor", "torso": "torso_monster", "head2": "ironclad_head_1", "arm_front2": "arm_piston", "arm_back2": "arm_piston", "arm_front": "arm_bulky", "arm_back": "arm_grapple", "leg_front": "leg_tread", "leg_back": "leg_tread", "back": "back_shield"}, "specials": ["shoulder_charge", "grab_slam", "scissor_sweep"]},
	{"name": "OVERLORD", "pilot": "", "style": "specialist", "hp": 1.3, "damage": 1.10, "speed": 1.20, "scale": 1.25, "think": 0.18, "block": 0.60, "smart": 0.9, "reward": 2200,
	 "body": "#1a1a2e", "trim": "#e0b84a", "eye": "#ff00aa",
	 "parts": {"head": "head_mast", "torso": "torso_cannon", "arm_front": "arm_drill", "arm_back": "arm_rocket", "leg_front": "leg_raptor", "leg_back": "leg_raptor", "back": "back_shield", "reactor": "reactor_over"}, "specials": ["scrap_fury", "rising_piston", "piston_barrage", "rocket_punch"]},
]
const EXHIBITION_REWARD := 900
const SETUP_SLOTS := 4
const CIRCUIT_NAMES := ["Rust Belt Cup", "Neon Night League", "Dockside Brawl", "Chrome Crown", "Scrapheap Classic",
		"Thunderdome Trials", "Gearhead Gauntlet", "Iron Harbor Open", "Voltage Vault Cup", "Junkyard Jamboree"]
const BOT_PREFIX := ["RUST", "IRON", "VOLT", "SCRAP", "STEEL", "CHROME", "MAG", "TURBO", "GRIM", "NEON", "BOLT", "HEX",
		"COG", "SLAG", "OHM", "TITAN", "BUZZ", "ROT"]
const BOT_SUFFIX := ["JAW", "FIST", "KING", "BITE", "WRECK", "TRON", "BUSTER", "CRUSH", "HOWL", "DOZER", "SPARK", "FANG",
		"BOX", "MAW", "GRINDER", "BARON", "HULK", "VIPER"]
const TIER_BUDGET := [350, 900, 1600, 2600, 4000]

# ---- custom part workshop
# Each grade gives stat points to spend. Every point costs more than in the shop: you pay for choice.
const CUSTOM_GRADES := [{"name": "Basic", "points": 6}, {"name": "Pro", "points": 10},
		{"name": "Elite", "points": 14}, {"name": "Legend", "points": 18}]
const CUSTOM_KINDS := {
	"head": {"base_hp": 30, "stats": ["hp", "armor", "aim", "chips"], "gadgets": ["laser"]},
	"torso": {"base_hp": 75, "stats": ["hp", "armor", "speed"], "gadgets": ["cannon"]},
	"arm": {"base_hp": 30, "stats": ["hp", "armor", "damage", "speed"], "gadgets": ["rocket_fist", "grapple"]},
	"leg": {"base_hp": 35, "stats": ["hp", "armor", "damage", "speed"], "gadgets": ["high_jump"]},
}
const CUSTOM_STEP := {"hp": 8, "armor": 4, "damage": 7, "speed": 6, "aim": 6, "chips": 1}
const CUSTOM_MAX_PER_STAT := 6
const CUSTOM_POINT_PRICE := 170
const CUSTOM_GADGET_PRICE := 600
const CUSTOM_COLORS := ["#c0392b", "#e67e22", "#f1c40f", "#2ecc71", "#1abc9c", "#3498db", "#9b59b6",
		"#e84393", "#ecf0f1", "#7f8c8d", "#2d3436", "#8d6e63"]

var PARTS := {}          # id -> part definition (built from PART_LIST)

var money := START_MONEY
var save_slot := 1          # which save file (1..SAVE_SLOTS) this game uses
var slot_mode := "load"     # what the save-slot screen is for: "new" or "load"
var pilot_name := "Rook"
var robot_name := DEFAULT_ROBOT
const DEFAULT_PILOT_LOOK := {"skin": "#b07a52", "hair": "#d9482f", "eyes": "#5b3a1e", "hat": "beanie", "outfit": "#3e5c4f",
		"beard": "none", "glasses": "none", "controller": "gamepad"}
# Pilot controllers: bought in the shop, each changes how your robots fight.
# mods: atk_speed / move / damage (+%), gadget_cd (x), aim (+% aim accuracy), combo (+s combo window),
#       seq (+s special-move input window), jump (+%), block (x damage taken while blocking)
const CONTROLLER_INFO := {
	"gamepad": {"cost": 0, "desc": "The pad you started with. No tricks.", "mods": {}},
	"brick": {"cost": 250, "desc": "Old retro pad, clicky buttons: +0.25s to keep combos going.", "mods": {"combo": 0.25}},
	"keyboard": {"cost": 600, "desc": "Every move on its own key: special-move inputs get +0.3s.", "mods": {"seq": 0.3}},
	"arcade": {"cost": 900, "desc": "Real arcade buttons: attacks 7% faster.", "mods": {"atk_speed": 0.07}},
	"radio": {"cost": 1000, "desc": "Long-range RC radio: gadgets recharge 20% faster.", "mods": {"gadget_cd": 0.8}},
	"wheel": {"cost": 1100, "desc": "Racing wheel: walks 12% faster.", "mods": {"move": 0.12}},
	"joysticks": {"cost": 1200, "desc": "Twin sticks, one per arm: blocked hits do 35% less damage.", "mods": {"block": 0.65}},
	"yoke": {"cost": 1400, "desc": "Flight yoke: jumps 12% higher and steers better in the air.", "mods": {"jump": 0.12}},
	"tablet": {"cost": 1500, "desc": "Targeting tablet: aimed hits land on your target 15% more often.", "mods": {"aim": 15}},
	"gloves": {"cost": 2600, "desc": "Motion gloves, the robot copies your hands: +6% damage and +4% attack speed.", "mods": {"damage": 0.06, "atk_speed": 0.04}},
}
var pilot_look := DEFAULT_PILOT_LOOK.duplicate()   # how your pilot looks in the corner and in the story
var owned_controllers: Array = ["gamepad"]
var tips_seen: Array = []
const DIGS_PER_FIGHT := 1
var digs_left := DIGS_PER_FIGHT   # scrapyard digs; refilled after every fight   # Gus's one-time tips (fight and garage) already shown
var inventory: Array = []   # [{uid, id, hp}]
var equipped := {}          # slot -> uid (-1 = empty)
var wingmen: Array = [{}, {}]   # extra robots for team fights, built from spares: [{slot: uid}, ...]
var sending := -1           # which robot fights the next 1-on-1: -1 = your main robot, 0/1 = a backup robot
var next_uid := 1
var paint := 0
var fight_index := 0        # (old saves) story fights won; the career now lives in year/week/event
var year := 1
var week := 1
var rank := "scrap"         # the highest league you've qualified for: scrap / regional / championship
var event := {}             # the league or playoffs you're in (see career.gd)
var trophies: Array = []    # [{kind: scrap/regional/championship/cup, medal: 1-3, name, year}]
var career_stats := {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
var story_queue: Array = [] # more story scenes to show after the current one
var pending_stories: Array = []   # scenes the last result unlocked (shown after the fight)
var last_ko := ""
var bills_note := 0         # living costs charged since the garage last showed them
var fight_log: Array = []   # every fight: {y, w, opp, won, mode, title} - for the calendar
var bets: Array = []        # this week's bets: {on: "event"/"cup", round, pick, vs, stake, odds}
var wins := 0
var losses := 0
var champion := false
var story_seen: Array = []
var circuit := {}             # active championship: {name, tier, seed, index, size}
var circuit_offers: Array = []  # championships you can enter
var circuits_won := 0
var exhibition := false       # an OVERLORD rematch is queued
var pickup := {}              # a scrapyard pickup fight in a quiet week: {enemy, week, year}
var world := {}               # every computer pilot, their money and robots (see world.gd)
var watching := {}            # a computer-vs-computer fight you're watching: {on, round, a, b}
var last_enemy_hp := {}       # the enemy's part health when the last fight ended: {slot: [hp, max]}
var quick := {}               # Quick Fight from the menu: {player, enemy} random bots, never saved
var setups: Array = []        # saved builds: {} or {name, equipped, chips, paint}
var custom_parts: Array = []  # part definitions you designed in the workshop
var ALL_PARTS: Array = []     # every catalog part id (classic + brand parts, and their Mini / Heavy sizes)

# Every head, torso, arm and leg comes in three sizes. Mini parts are weak, quick and cheap to power;
# Heavy parts are tough and hit hard but drink power. Variant ids end in "~S" or "~L".
const SIZE_CLASSES := {
	"S": {"name": "Mini", "hp": 0.7, "armor": -3, "damage": 0.75, "speed": 10, "draw": 0.5, "cost": 0.7, "size": 0.8},
	"L": {"name": "Heavy", "hp": 1.4, "armor": 4, "damage": 1.35, "speed": -10, "draw": 1.75, "cost": 1.5, "size": 1.22},
}
const SIZE_NAMES := {"S": "Small", "M": "Medium", "L": "Large"}
# Weight class = total power your parts draw. [name, max power]
const WEIGHT_CLASSES := [["LIGHTWEIGHT", 12], ["MIDDLEWEIGHT", 22], ["HEAVYWEIGHT", 9999]]
# A team shares one heavyweight's worth of power: 2 robots get half each, 3 get a third.
const TEAM_POWER := 40.0
var style := "striker"        # fighting style: tank, striker, mechanic, specialist
var shop_stock: Array = []    # part ids for sale right now (changes after every fight)
var scout := {}               # scouting report on the next opponent: {key, spied_back, change}
var owned_chips: Array = []   # special-move chips bought
var chips: Array = []         # chips installed (only the first chip_slots() of them run)
var last_result := {}       # handed from the fight to the garage
var story_key := ""         # which story scene to show next
var story_return := ""      # scene to go to after the story
const DEFAULT_SETTINGS := {"sound": true, "music": true, "shake": true, "button_size": 1, "difficulty": 1, "layout": {}, "team_controls": "split", "battery_saver": false,
		"start_money": START_MONEY, "living_cost": LIVING_COST, "coaching": 2, "lang": "en"}
var settings := DEFAULT_SETTINGS.duplicate(true)


# ---------------------------------------------------------------- error log
# Every error the game hits is kept here and saved to user://error_log.txt (so it survives a crash).
# Settings > Error log shows them with a "Copy all" button.

const ERROR_LOG_PATH := "user://error_log.txt"
const ERROR_LOG_OLD_PATH := "user://error_log_previous.txt"
const ERROR_LOG_MAX := 300


class ErrorCatcher extends Logger:
	var lines: Array = []
	var dirty := false
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		var kinds := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]
		var text := tr("[%s] %s: %s\n    at %s:%d (%s)") % [Time.get_time_string_from_system(), kinds[clampi(error_type, 0, 3)],
				rationale if rationale != "" else code, file, line, function]
		for bt in script_backtraces:
			if bt != null and bt.has_method("format"):
				text += "\n" + str(bt.format())
		add(text)

	func _log_message(message: String, error: bool) -> void:
		if error:
			add(tr("[%s] %s") % [Time.get_time_string_from_system(), message.strip_edges()])

	func add(text: String) -> void:
		mutex.lock()
		lines.append(text)
		if lines.size() > ERROR_LOG_MAX:
			lines = lines.slice(lines.size() - ERROR_LOG_MAX)
		dirty = true
		mutex.unlock()

	func snapshot() -> Array:
		mutex.lock()
		var out := lines.duplicate()
		mutex.unlock()
		return out


var error_catcher := ErrorCatcher.new()
var _error_flush_t := 0.0


func start_error_log() -> void:
	# keep the last session's log (that's the one with the crash in it)
	if FileAccess.file_exists(ERROR_LOG_PATH):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(ERROR_LOG_PATH), ProjectSettings.globalize_path(ERROR_LOG_OLD_PATH))
	OS.add_logger(error_catcher)
	write_project_log()   # a fresh log for this session (also proves the game started)


func _process(delta: float) -> void:
	_error_flush_t -= delta
	if error_catcher.dirty and _error_flush_t <= 0.0:
		_error_flush_t = 1.0
		flush_error_log()


func flush_error_log() -> void:
	error_catcher.dirty = false
	var f := FileAccess.open(ERROR_LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n\n".join(error_catcher.snapshot()))
	write_project_log()


## When the game runs from the Godot editor, also put the log in the project folder
## (logs/last_session.txt) so it goes to GitHub with your next MGit push and Claude can read it.
const PROJECT_LOG_PATH := "res://logs/last_session.txt"


func write_project_log() -> void:
	if not OS.has_feature("editor"):
		return   # exported builds can't write into the project
	if not DirAccess.dir_exists_absolute("res://logs"):
		if DirAccess.make_dir_recursive_absolute("res://logs") != OK:
			return
	var f := FileAccess.open(PROJECT_LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(error_log_text())


## Everything for the Error log screen: this session, then the previous one.
func error_log_text() -> String:
	var now: Array = error_catcher.snapshot()
	var text := tr("ROBOT FIGHTING GAME - error log (%s, Godot %s)\n\n== THIS SESSION: %d ==\n") % [
			Time.get_datetime_string_from_system(false, true), Engine.get_version_info()["string"], now.size()]
	text += "\n\n".join(now) if not now.is_empty() else "(no errors)"
	if FileAccess.file_exists(ERROR_LOG_OLD_PATH):
		var old := FileAccess.get_file_as_string(ERROR_LOG_OLD_PATH)
		text += "\n\n== PREVIOUS SESSION ==\n" + (old if old.strip_edges() != "" else "(no errors)")
	return text


func error_count() -> int:
	return error_catcher.snapshot().size()


func clear_error_log() -> void:
	error_catcher.mutex.lock()
	error_catcher.lines.clear()
	error_catcher.mutex.unlock()
	flush_error_log()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ERROR_LOG_OLD_PATH))


func _ready() -> void:
	start_error_log()
	for p in PART_LIST + Catalog.generate():
		var d: Dictionary = p.duplicate()
		ALL_PARTS.append(d["id"])
		if not d.has("trait"):
			d["trait"] = ""
			d["trait_lv"] = 0
		if not d.has("mounts"):
			d["mounts"] = []
		if d["kind"] == "head" and not d.has("chips"):
			d["chips"] = 1
		for k in ["hp", "armor", "damage", "speed", "aim", "draw", "output", "chips"]:
			if not d.has(k):
				d[k] = 0
		if not d.has("shop"):
			d["shop"] = true
		if not d.has("size"):
			d["size"] = 1.0
		if not d.has("shape"):
			d["shape"] = ""
		if not d.has("gimmick"):
			d["gimmick"] = ""
		if not d.has("size_class"):
			d["size_class"] = "M"
		PARTS[d["id"]] = d
	# Mini and Heavy versions of every body part
	var base_ids := ALL_PARTS.duplicate()
	for c in ["S", "L"]:
		for id in base_ids:
			var d: Dictionary = PARTS[id]
			if d["kind"] in ["head", "torso", "arm", "leg"] and d["cost"] > 0 and d["shop"]:
				var v := sized_variant(d, c)
				PARTS[v["id"]] = v
				ALL_PARTS.append(v["id"])
	for id in PARTS:
		PARTS[id]["name_en"] = PARTS[id]["name"]
	load_settings()
	set_language(str(settings.get("lang", "en")))
	apply_performance()
	migrate_old_save()
	get_tree().root.theme = UI.make_theme()
	new_game()   # sensible defaults so any scene can run on its own


# ---------------------------------------------------------------- inventory

func new_game() -> void:
	money = int(settings.get("start_money", START_MONEY))
	pilot_name = "Rook"
	pilot_look = DEFAULT_PILOT_LOOK.duplicate()
	owned_controllers = ["gamepad"]
	tips_seen = []
	digs_left = DIGS_PER_FIGHT
	robot_name = DEFAULT_ROBOT
	inventory = []
	equipped = {}
	next_uid = 1
	for slot in SLOTS:
		equipped[slot] = add_part(STARTER[slot]) if STARTER.has(slot) else -1
	paint = 0
	fight_index = 0
	year = 1
	week = 1
	rank = "scrap"
	trophies = []
	career_stats = {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
	watching = {}
	World.create(randi())
	event = Career.new_event("scrap", 1, randi())
	wins = 0
	losses = 0
	champion = false
	story_seen = []
	owned_chips = []
	chips = []
	for d in custom_parts:
		PARTS.erase(d["id"])
	custom_parts = []
	style = "striker"
	scout = {}
	shop_stock = []
	quick = {}
	circuit = {}
	circuit_offers = []
	circuits_won = 0
	exhibition = false
	pickup = {}
	bills_note = 0
	fight_log = []
	bets = []
	setups = []
	for k in SETUP_SLOTS:
		setups.append({})
	last_result = {}
	roll_stock()


## New-game screen: swap one starter slot group (head / torso / arm / leg) to another junk part.
func set_starter(kind: String, id: String) -> void:
	for slot in SLOTS:
		if SLOT_KIND.get(slot, "") == kind and STARTER.has(slot):
			var p := inst(int(equipped.get(slot, -1)))
			if not p.is_empty():
				p["id"] = id
				p["hp"] = float(part_def(id)["hp"])


func starter_id(kind: String) -> String:
	for slot in SLOTS:
		if SLOT_KIND.get(slot, "") == kind and STARTER.has(slot):
			var p := inst(int(equipped.get(slot, -1)))
			if not p.is_empty():
				return p["id"]
	return ""


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
		if slot_of_uid(p["uid"]) == "" and wingman_of_uid(p["uid"]) == -1:
			out.append(p)
	return out


func wingman_of_uid(uid: int) -> int:
	for k in wingmen.size():
		for slot in wingmen[k]:
			if int(wingmen[k][slot]) == uid:
				return k
	return -1


func release_from_wingman(uid: int) -> void:
	var k := wingman_of_uid(uid)
	if k == -1:
		return
	for slot in wingmen[k].keys():
		if int(wingmen[k][slot]) == uid:
			wingmen[k].erase(slot)


func shop_parts(kind: String) -> Array:
	var out: Array = []
	for id in ALL_PARTS:
		var d: Dictionary = PARTS[id]
		if d["kind"] == kind and d["shop"]:
			out.append(d)
	return out


## Free junk, always available so you can never get stuck without a part.
func scrap_bin() -> Array:
	var out: Array = []
	for id in ALL_PARTS:
		if PARTS[id]["cost"] == 0:
			out.append(PARTS[id])
	return out


## How far along you are (unlocks better stock in the shop).
func progress() -> int:
	return mini(wins, 30) / 3 + rank_index() * 2 + circuits_won * 2 + (2 if champion else 0)


## Restock the shop with a random selection. Better parts show up as you progress.
func roll_stock() -> void:
	var max_cost := 600 + progress() * 380
	var pool: Array = []
	for id in ALL_PARTS:
		var d: Dictionary = PARTS[id]
		if d["shop"] and d["cost"] > 0 and d["cost"] <= max_cost:
			pool.append(id)
	pool.shuffle()
	shop_stock = pool.slice(0, STOCK_SIZE)
	# one "special order" a bit above your level, if there is one
	var stretch: Array = []
	for id in ALL_PARTS:
		var d: Dictionary = PARTS[id]
		if d["shop"] and d["cost"] > max_cost and d["cost"] <= max_cost * 1.6:
			stretch.append(id)
	if not stretch.is_empty():
		shop_stock.append(stretch[randi() % stretch.size()])


func reroll_stock() -> String:
	if money < REROLL_COST:
		return tr("Restocking costs $%d.") % REROLL_COST
	money -= REROLL_COST
	roll_stock()
	return "The dealer wheeled in a fresh load of parts."


## Is this slot usable right now? Extra slots need a torso with the right mount.
func slot_available(slot: String) -> bool:
	if not EXTRA_SLOTS.has(slot):
		return true
	var t := equipped_inst("torso")
	return not t.is_empty() and part_def(t["id"])["mounts"].has(slot)


## After a torso swap, extra parts the new torso can't hold go back to storage.
func drop_unmounted() -> void:
	for slot in EXTRA_SLOTS:
		if not slot_available(slot):
			equipped[slot] = -1


func is_wreck(p: Dictionary) -> bool:
	return not UNDAMAGEABLE.has(part_def(p["id"])["kind"]) and p["hp"] <= 0.0


func hp_ratio(p: Dictionary) -> float:
	var mx: float = part_def(p["id"])["hp"]
	return 1.0 if mx <= 0.0 else clampf(p["hp"] / mx, 0.0, 1.0)


func buy(id: String) -> String:
	var d := part_def(id)
	if money < d["cost"]:
		return "Not enough money."
	money -= d["cost"]
	shop_stock.erase(id)
	var uid := add_part(id)
	for slot in SLOTS:
		if SLOT_KIND[slot] == d["kind"] and equipped[slot] == -1 and slot_available(slot):
			equipped[slot] = uid
			return tr("Bought %s and fitted it to the %s.") % [d["name"], tr(SLOT_NAMES[slot])]
	return tr("Bought %s. It's in your Spares - equip it from there.") % d["name"]


func equip(uid: int, slot: String) -> String:
	var p := inst(uid)
	if p.is_empty():
		return "That part is gone."
	release_from_wingman(uid)
	p.erase("dug")   # fitted: it's not a fresh find any more
	var d := part_def(p["id"])
	if is_wreck(p):
		return tr("%s is a wreck. Rebuild it first.") % d["name"]
	if SLOT_KIND[slot] != d["kind"]:
		return tr("A %s doesn't fit the %s.") % [d["name"], tr(SLOT_NAMES[slot])]
	if not slot_available(slot):
		return tr("Your torso has no mount for a %s.") % str(SLOT_NAMES[slot]).to_lower()
	var old_slot := slot_of_uid(uid)
	if old_slot != "":
		equipped[old_slot] = equipped[slot] if old_slot != slot else -1
	equipped[slot] = uid
	if slot == "torso":
		drop_unmounted()
	return tr("Fitted %s to the %s.") % [d["name"], tr(SLOT_NAMES[slot])]


func unequip(slot: String) -> void:
	if slot == "back":
		equipped[slot] = -1
		return
	if slot != "reactor":
		equipped[slot] = -1
	if slot == "torso":
		drop_unmounted()


func repair_cost(p: Dictionary) -> int:
	var d := part_def(p["id"])
	var missing := 1.0 - hp_ratio(p)
	if missing <= 0.0:
		return 0
	var discount := 0.6 if style == "mechanic" else 1.0   # mechanics fix things cheaper
	if is_wreck(p):
		return maxi(20, int(d["cost"] * 0.5 * discount))   # rebuilding a wreck
	return maxi(1, ceili(missing * maxf(20.0, d["cost"] * 0.2) * discount))


func repair(uid: int) -> String:
	var p := inst(uid)
	var c := repair_cost(p)
	if c == 0:
		return "Already in perfect shape."
	if not can_repair(c):
		return "Not enough cash - no repairs on credit. Fight with the dents and win some money."
	money -= c
	p["hp"] = float(part_def(p["id"])["hp"])
	return tr("Repaired %s for $%d.") % [part_def(p["id"])["name"], c]


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
	if not can_repair(c):
		return tr("Repairing everything costs $%d. You don't have the cash - fix the worst parts one at a time, or fight with the dents.") % c
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty():
			p["hp"] = float(part_def(p["id"])["hp"])
	money -= c
	return tr("Fully repaired for $%d.") % c


## Damaged parts sell for less; even junk and wrecks are worth something as scrap metal.
func sell_value(p: Dictionary) -> int:
	var h := hp_ratio(p)
	return maxi(int(part_def(p["id"])["cost"] * 0.4 * h), int(10 + 15 * h))


func sell(uid: int) -> String:
	var p := inst(uid)
	if p.is_empty() or slot_of_uid(uid) != "":
		return "Unequip it before selling."
	if wingman_of_uid(uid) != -1:
		return "A wingman is using that part."
	var v := sell_value(p)
	money += v
	inventory.erase(p)
	return tr("Sold %s for $%d.") % [part_def(p["id"])["name"], v]


func part_stat_text(d: Dictionary) -> String:
	var g := gimmick_text(d)
	if d["kind"] == "reactor":
		return tr("Power output %d") % d["output"] + g + trait_line(d)
	if d["kind"] == "back":
		var b: Array = []
		if d["output"] > 0:
			b.append(tr("Power +%d") % d["output"])
		if d["draw"] > 0:
			b.append(tr("Power %d") % d["draw"])
		return "  ".join(b) + g + trait_line(d)
	var bits: Array = [tr("HP %d") % d["hp"]]
	if d["armor"] != 0:
		bits.append(tr("ARM %d%%") % d["armor"])
	if d["damage"] != 0:
		bits.append(tr("DMG %+d%%") % d["damage"])
	if d["speed"] != 0:
		bits.append(tr("SPD %+d%%") % d["speed"])
	if d["aim"] != 0:
		bits.append(tr("AIM %+d%%") % d["aim"])
	if d["output"] != 0:
		bits.append(tr("PWR +%d") % d["output"])
	if d["kind"] == "head" and d["chips"] > 0:
		bits.append(tr("CHIPS %d") % d["chips"])
	if d["kind"] in ["head", "torso", "arm", "leg"]:
		bits.append(tr(SIZE_NAMES.get(d.get("size_class", "M"), "Medium")))
	bits.append(tr("Power %d") % d["draw"])
	if not d["mounts"].is_empty():
		var m: Array = []
		for slot in d["mounts"]:
			m.append(tr(str(SLOT_NAMES[slot])).to_lower())
		bits.append(tr("| Mounts: ") + ", ".join(m))
	return "  ".join(bits) + g + trait_line(d)


func trait_line(d: Dictionary) -> String:
	return "" if d.get("trait", "") == "" else "  |  " + Catalog.trait_text(d)


func gimmick_text(d: Dictionary) -> String:
	if d["gimmick"] == "":
		return ""
	return "  |  " + tr(Specials.GADGETS[d["gimmick"]]["desc"])


# ---------------------------------------------------------------- chips (special moves)

func chip_slots() -> int:
	var n := 0
	for slot in ["head", "head2"]:
		var h := equipped_inst(slot)
		if not h.is_empty() and not is_wreck(h):
			n += int(part_def(h["id"])["chips"])
	if n > 0 and style == "specialist":
		n += 1
	return n


func active_chips() -> Array:
	return chips.slice(0, chip_slots())


func buy_chip(id: String) -> String:
	var m: Dictionary = Specials.MOVES[id]
	if owned_chips.has(id):
		return tr("You already own %s.") % tr(m["name"])
	if money < m["cost"]:
		return "Not enough money."
	money -= m["cost"]
	owned_chips.append(id)
	if chips.size() < chip_slots():
		chips.append(id)
		return tr("Downloaded %s into %s. Input: %s") % [tr(m["name"]), robot_name, Specials.seq_text(m["seq"])]
	return tr("Bought %s. Your chip slots are full - uninstall a chip to make room.") % tr(m["name"])


func install_chip(id: String) -> String:
	if chips.has(id):
		return "Already installed."
	if chips.size() >= chip_slots():
		return "No free chip slots. A better head has more slots."
	chips.append(id)
	return tr("Installed %s.") % tr(Specials.MOVES[id]["name"])


func uninstall_chip(id: String) -> String:
	chips.erase(id)
	return tr("Removed %s.") % tr(Specials.MOVES[id]["name"])


# ---------------------------------------------------------------- stats

func can_fight() -> bool:
	return (equipped["head"] != -1 or equipped["head2"] != -1) and equipped["torso"] != -1


func stats(eq: Dictionary = {}) -> Dictionary:
	if eq.is_empty():
		eq = equipped
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
		var p := inst(int(eq.get(slot, -1)))
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
				aim = maxf(aim, d["aim"])
		if not UNDAMAGEABLE.has(SLOT_KIND[slot]):
			armor += d["armor"]
			parts += 1
	var eff := 1.0 if used <= output or used == 0 else float(output) / used
	var leg_factor: float = [0.35, 0.65, 1.0][mini(legs, 2)]
	var speed := (100.0 + (leg_spd / maxf(1, legs)) + torso_spd) * leg_factor * eff
	var damage := (100.0 + arm_dmg / maxf(1, arms)) * eff if arms > 0 else 0.0
	var t := inst(int(eq.get("torso", -1)))
	return {
		"power_used": used, "power_output": output, "efficiency": eff,
		"core": 0.0 if t.is_empty() else t["hp"], "core_max": 0.0 if t.is_empty() else float(part_def(t["id"])["hp"]),
		"damage": damage, "speed": speed, "aim": aim, "armor": armor / maxf(1, parts),
		"arms": arms, "legs": legs,
	}


## Everything the fight needs to build the player's robot.
func player_spec(eq: Dictionary = {}, label: String = "") -> Dictionary:
	if eq.is_empty():
		eq = equipped
	var parts := {}
	for slot in BODY_SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if p.is_empty():
			parts[slot] = {}
		else:
			var d := part_def(p["id"])
			parts[slot] = {"id": d["id"], "hp": p["hp"], "max_hp": float(d["hp"]), "armor": d["armor"],
					"damage": d["damage"], "speed": d["speed"], "aim": d["aim"], "draw": float(d["draw"]),
					"shape": d["shape"], "size": d["size"], "color": Color(d["color"]),
					"trait": d["trait"], "trait_lv": d["trait_lv"]}
	var s := stats(eq)
	var gadgets: Array = []
	for slot in SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if not p.is_empty() and part_def(p["id"])["gimmick"] != "":
			gadgets.append({"id": part_def(p["id"])["gimmick"], "slot": slot})
	var back := inst(int(eq.get("back", -1)))
	var reactor := inst(int(eq.get("reactor", -1)))
	return {"name": robot_name if label == "" else label, "parts": parts, "efficiency": s["efficiency"], "damage_mult": 1.0,
			"power": float(s["power_output"]),
			"speed_mult": 1.0, "scale": 1.0, "trim": Color(PAINTS[paint]["color"]),
			"eye": Color(part_def(reactor["id"])["color"]) if not reactor.is_empty() else Color(0.4, 0.9, 1.0),
			"back": {} if back.is_empty() else {"shape": part_def(back["id"])["shape"], "color": Color(part_def(back["id"])["color"])},
			"gadgets": gadgets, "specials": active_chips() if eq == equipped else [], "style": style,
			"controller": str(pilot_look.get("controller", "gamepad")),
			"traits": global_traits(ids_of(eq))}


func ids_of(eq: Dictionary) -> Dictionary:
	var out := {}
	for slot in eq:
		var p := inst(int(eq[slot]))
		if not p.is_empty():
			out[slot] = p["id"]
	return out


func equipped_ids() -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty():
			out[slot] = p["id"]
	return out


## Traits from reactor and back gear (they don't take hits, so they work robot-wide).
func global_traits(ids: Dictionary) -> Array:
	var out: Array = []
	for slot in ["reactor", "back"]:
		if ids.has(slot) and ids[slot] != "":
			var d := part_def(ids[slot])
			if d.get("trait", "") != "":
				out.append({"trait": d["trait"], "trait_lv": d["trait_lv"]})
	return out


func fight_mode() -> String:
	if not quick.is_empty():
		return "quick"
	if not watching.is_empty():
		return "watch"
	if not circuit.is_empty() and circuit.get("phase", "") != "done":
		return "circuit"
	if not event.is_empty() and event.get("phase", "") != "done" and Career.player_opponent(event) != -1 \
			and week >= Career.week_of_round(event):
		return "story"
	if exhibition:
		return "exhibition"
	if not pickup.is_empty():
		return "pickup"
	return "open"   # no fight this week: rest, skip ahead, or enter a cup


## The story rival you're about to fight (0-9), or -1 for anyone else.
func current_opponent_index() -> int:
	match fight_mode():
		"story":
			var e := Career.pilot(event, Career.player_opponent(event))
			return int(e.get("rival", -1))
		"exhibition":
			return OPPONENTS.size() - 1
	return -1


func current_opponent() -> Dictionary:
	if fight_mode() == "quick":
		return quick["enemy"]
	if fight_mode() == "watch":
		return watch_robot(1)
	var o: Dictionary
	match fight_mode():
		"circuit":
			o = Career.robot_of(circuit, Career.player_opponent(circuit))
		"story":
			o = Career.robot_of(event, Career.player_opponent(event))
		"pickup":
			if pickup.has("wid") and not World.pilot(int(pickup["wid"])).is_empty():
				o = World.robot(int(pickup["wid"]))
			else:
				o = (pickup["enemy"] as Dictionary).duplicate(true)
		"exhibition":
			o = OPPONENTS[OPPONENTS.size() - 1].duplicate(true)
			o["pilot"] = ""
		_:
			return {}
	o["reward"] = current_reward_for(o)
	# if they caught our scout, they changed something
	if scouted() and scout.get("spied_back", false):
		o = o.duplicate(true)
		var ch: Dictionary = scout["change"]
		match ch["type"]:
			"part":
				o["parts"][ch["slot"]] = ch["id"]
			"armor":
				o["armor_bonus"] = 8
			"smart":
				o["smart"] = minf(1.0, o["smart"] + 0.3)
				o["block"] = minf(0.8, o["block"] + 0.1)
	return o


# ---------------------------------------------------------------- scouting

func scout_key() -> String:
	match fight_mode():
		"story":
			return "ev:%d:%s:%d" % [year, event["stage"], int(event["round"])]
		"circuit":
			return "cup:%d:%d" % [int(circuit["seed"]), int(circuit["round"])]
		"exhibition":
			return "exhibition:%d" % wins
		"pickup":
			return "pickup:%d:%d" % [year, week]
	return ""


func scout_cost() -> int:
	return maxi(60, int(current_reward() * 0.15))


func scouted() -> bool:
	return scout_key() != "" and scout.get("key", "") == scout_key()


## Pay to look at the next opponent. 30% of the time their crew spots the scout and adapts.
func do_scout() -> String:
	if scouted():
		return "You already have a scouting report."
	var cost := scout_cost()
	if money < cost:
		return tr("Scouting costs $%d.") % cost
	money -= cost
	var o := current_opponent()
	scout = {"key": scout_key(), "spied_back": false, "change": {}}
	if randf() < 0.3:
		var change := {}
		var r := randf()
		if r < 0.45:
			# swap one part for something nastier
			var slots: Array = []
			for slot in ["arm_front", "arm_back", "leg_front", "leg_back", "head"]:
				if o["parts"].has(slot):
					slots.append(slot)
			var slot: String = slots[randi() % slots.size()]
			var old := part_def(o["parts"][slot])
			var better := ""
			for id in ALL_PARTS:
				var d: Dictionary = PARTS[id]
				if d["kind"] == old["kind"] and d["cost"] > old["cost"] and d["cost"] <= old["cost"] * 2.0 + 600 and d["gimmick"] == "" and (better == "" or randf() < 0.4):
					better = id
			if better != "":
				change = {"type": "part", "slot": slot, "id": better,
						"text": tr("swapped their %s for a %s") % [str(SLOT_NAMES[slot]).to_lower(), part_def(better)["name"]]}
		if change.is_empty() and r < 0.75:
			change = {"type": "armor", "text": "bolted extra armor plates onto every part"}
		if change.is_empty():
			change = {"type": "smart", "text": "studied your robot - they'll block more and aim at your weak spots"}
		scout["spied_back"] = true
		scout["change"] = change
		return tr("Their crew spotted your scout! They %s.") % change["text"]
	return "Clean scouting run - they never saw you."



## What a defeat pays: in the scrapyard you pay the winner, in the Regional and cups you get nothing,
## in the Championship (and exhibitions) you still get a small purse.
func loss_pay(base: int) -> int:
	match fight_mode():
		"pickup":
			return -int(base * 0.5)
		"story":
			match str(event.get("stage", "")):
				"scrap":
					return -int(base * 0.5)
				"championship":
					return int(base * 0.3)
			return 0
		"exhibition":
			return int(base * 0.25)
	return 0


func current_reward() -> int:
	var o := current_opponent()
	return 0 if o.is_empty() else int(o["reward"])


## Prize money for the fight against o (league rounds pay a bit more as the season goes on, playoffs more).
func current_reward_for(o: Dictionary) -> int:
	match fight_mode():
		"quick":
			return 0
		"exhibition":
			return EXHIBITION_REWARD
		"pickup":
			return 70 + 50 * rank_index()
		"circuit":
			return 200 + 250 * int(circuit["tier"]) + 100 * int(circuit["round"])
		"story":
			var info: Dictionary = Career.STAGES[event["stage"]]
			var n: float = maxf(1.0, event["weeks"].size() - 1)
			var r: float = lerpf(info["reward"][0], info["reward"][1], float(event["round"]) / n)
			if Career.is_playoff(event):
				r *= 1.6
			return int(r / 10.0) * 10 + (100 if o.has("team") else 0)
	return 0


func fight_title() -> String:
	match fight_mode():
		"quick":
			return tr("QUICK FIGHT")
		"watch":
			var wev := watch_event()
			return tr("%s VS %s") % [str(watch_robot(0)["pilot"]), str(watch_robot(1)["pilot"])] + " - " + (tr(str(wev["name"])).to_upper() if wev["stage"] == "cup" else tr(Career.STAGES[wev["stage"]]["short"]))
		"circuit":
			return tr("%s - %s") % [str(circuit["name"]).to_upper(), tr(Career.round_name(circuit))]
		"exhibition":
			return tr("EXHIBITION")
		"pickup":
			return tr("SCRAPYARD PICKUP FIGHT")
		"story":
			return tr("%s - %s") % [tr(Career.STAGES[event["stage"]]["short"]), tr(Career.round_name(event)).to_upper()]
	return tr("YEAR %d, WEEK %d") % [year, week]


## Arena and crowd for the next fight: story rivals in their own venues, league fights in the
## league's venues, cups and quick fights anywhere.
func fight_is_final() -> bool:
	match fight_mode():
		"story":
			return Career.round_name(event) == "FINAL"
		"circuit":
			return Career.round_name(circuit) == "FINAL"
	return false


func current_arena() -> Array:
	var rng := RandomNumberGenerator.new()
	match fight_mode():
		"story":
			return Arena.career_venue(event["stage"], Career.round_name(event))
		"watch":
			if watching["on"] == "event":
				return Arena.career_venue(event["stage"], Career.round_name(event))
			rng.seed = int(circuit["seed"]) + int(circuit["round"]) * 7
		"pickup":
			return ["scrap_ring", "scrappers"]
		"exhibition":
			return ["champ_gala", "high_society"]
		"circuit":
			rng.seed = int(circuit["seed"]) + int(circuit["round"]) * 7
		_:
			rng.randomize()
	return [Arena.ARENAS.keys()[rng.randi() % Arena.ARENAS.size()], Arena.CROWDS.keys()[rng.randi() % Arena.CROWDS.size()]]


## Quiet weeks: there's always a pickup fight at the scrapyard for a few dollars.
func start_pickup() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 1000 + week
	var lv := 0.3 + rank_index() * 0.8
	# someone from your tier hanging around the scrapyard (not one of this week's league pilots)
	var busy := World.busy_ids()
	var p := World.pick_pickup(rng, rank, busy.keys())
	if not p.is_empty():
		pickup = {"wid": int(p["wid"]), "enemy": World.robot(int(p["wid"])), "week": week, "year": year}
		return
	var bot := random_bot(rng, 300.0 + rank_index() * 500.0, lv)
	bot["pilot"] = Career.PILOT_NAMES[rng.randi() % Career.PILOT_NAMES.size()]
	pickup = {"enemy": bot, "week": week, "year": year}


# ---------------------------------------------------------------- calendar

## The week moves on (after every fight, or when you rest). New leagues start on their week.
func advance_week(n: int = 1) -> void:
	for k in n:
		World.week_passed(year, week, World.busy_ids())   # the rest of Port Ferrum fights and shops too
		if week % MONTH_WEEKS == 0:
			money -= living_cost()   # end of the month: cost of living
			bills_note += living_cost()
		week += 1
		if week > Career.WEEKS_PER_YEAR:
			week = 1
			year += 1
		ensure_event()


func living_cost() -> int:
	return int(settings.get("living_cost", LIVING_COST))


## Weeks until the next living-cost bill.
func weeks_to_bills() -> int:
	return MONTH_WEEKS - ((week - 1) % MONTH_WEEKS)


## "$420" or "-$1000"
static func money_text(v: int) -> String:
	return ("-$%d" % -v) if v < 0 else ("$%d" % v)


## No credit: repairs (like everything else) need real cash. In debt, you fight with the dents.
func can_repair(cost: int) -> bool:
	return money >= cost


func rank_index() -> int:
	return Career.ORDER.find(rank)


## Start your next league when its week comes round (if you're qualified for it).
func ensure_event() -> void:
	if not event.is_empty() and event.get("phase", "") != "done":
		return
	for stage in Career.ORDER:
		var info: Dictionary = Career.STAGES[stage]
		if int(info["start"]) != week:
			continue
		var idx := Career.ORDER.find(stage)
		var enter: bool = idx == rank_index() if stage == "scrap" else idx <= rank_index()
		# each year you start from the highest league you've reached
		if stage == "regional" and rank_index() >= 2:
			enter = false
		if enter:
			event = Career.new_event(stage, year, randi())
			return


## Your next league: [stage, start week, weeks from now] (stage "" if none).
func next_event_info() -> Array:
	if not event.is_empty() and event.get("phase", "") != "done":
		return [event["stage"], Career.week_of_round(event), maxi(0, Career.week_of_round(event) - week)]
	for add in range(1, Career.WEEKS_PER_YEAR + 2):
		var w := (week + add - 1) % Career.WEEKS_PER_YEAR + 1
		for stage in Career.ORDER:
			if int(Career.STAGES[stage]["start"]) == w:
				var idx := Career.ORDER.find(stage)
				var rk := rank_index()
				var enter: bool = idx == rk if stage == "scrap" else (idx <= rk and not (stage == "regional" and rk >= 2))
				if enter:
					return [stage, w, add]
	return ["", 0, 0]


func rest_week() -> String:
	pickup = {}
	advance_week(1)
	digs_left = DIGS_PER_FIGHT
	save_game()
	return tr("A quiet week. Year %d, week %d.") % [year, week]


func skip_to_next_event() -> String:
	var nxt := next_event_info()
	if nxt[0] == "":
		return "Nothing on the calendar."
	pickup = {}
	advance_week(int(nxt[2]))
	digs_left = DIGS_PER_FIGHT
	save_game()
	return tr("Skipped ahead to week %d: the %s.") % [week, tr(Career.STAGES[event.get("stage", nxt[0])]["name"])]


## Will you play this league this year? (You only see leagues you've qualified for.)
func enters_stage(stage: String) -> bool:
	var idx := Career.ORDER.find(stage)
	var rk := rank_index()
	if stage == "scrap":
		return idx == rk
	return idx <= rk and not (stage == "regional" and rk >= 2)


## What's on your calendar in a week of this year: {kind, text}
##   kind: done (a fight you had), league, playoff, cup, open (quiet week), past (nothing happened)
func week_plan(y: int, w: int) -> Dictionary:
	for e in fight_log:
		if int(e["y"]) == y and int(e["w"]) == w:
			return {"kind": "done", "won": e["won"], "text": tr("WON vs %s" if e["won"] else "LOST vs %s") % e["opp"], "title": e["title"]}
	if y < year or (y == year and w < week):
		return {"kind": "past", "text": ""}
	if not circuit.is_empty() and circuit.get("phase", "") != "done" and circuit["weeks"].has(w):
		return {"kind": "cup", "text": "%s" % circuit["name"]}
	if not event.is_empty() and event.get("phase", "") != "done" and int(event.get("year", year)) == y and event["weeks"].has(w):
		var k: int = event["weeks"].find(w)
		var short: String = tr(Career.STAGES[event["stage"]]["short"])
		if k < event["schedule"].size():
			var o := Career.robot_of(event, int(event["schedule"][k]))
			return {"kind": "league", "text": tr("%s R%d\nvs %s") % [short, k + 1, o.get("name", "?")]}
		if event["phase"] == "playoffs" or Career.player_opponent(event) != -1:
			return {"kind": "playoff", "text": tr("%s\nPLAYOFFS") % short}
		return {"kind": "playoff", "text": tr("%s\nplayoffs (if you qualify)") % short}
	if y == year:
		for stage in Career.ORDER:
			var info: Dictionary = Career.STAGES[stage]
			var start: int = info["start"]
			var length: int = int(info["size"]) - 1 + Career.playoff_rounds(int(info["playoff"]))
			if w >= start and w < start + length and w > week and enters_stage(stage) and (event.is_empty() or event.get("phase", "") == "done" or event["stage"] != stage):
				return {"kind": "league", "text": tr("%s\n(qualified)") % tr(info["short"])}
	return {"kind": "open", "text": "pickup fight"}


# ---------------------------------------------------------------- betting

## The event you can bet on this week ("event" or "cup"), or "".
func bet_target() -> String:
	match fight_mode():
		"story":
			return "event"
		"circuit":
			return "cup"
	return ""


func bet_event() -> Dictionary:
	return event if bet_target() == "event" else (circuit if bet_target() == "cup" else {})


## Put money on pilot `pick` beating `vs` this round. Needs real cash.
func place_bet(pick: int, vs: int, stake: int) -> String:
	var ev := bet_event()
	if ev.is_empty():
		return "Nothing to bet on this week."
	if vs == 0:
		return "Betting against yourself? Gus would never speak to you again."
	if money < stake:
		return tr("You need $%d in cash to place that bet.") % stake
	var o := Career.odds(ev, pick, vs)
	money -= stake
	bets.append({"on": bet_target(), "round": int(ev["round"]), "pick": pick, "vs": vs, "stake": stake, "odds": o})
	var who: String = pilot_name if pick == 0 else str(Career.pilot(ev, pick).get("pilot", "?"))
	return tr("$%d on %s at %.2fx - pays $%d if they win.") % [stake, who, o, int(stake * o)]


## After the round: pay out winning bets. Returns {won, lost, net, lines}.
func settle_bets(on: String, ev: Dictionary) -> Dictionary:
	var out := {"paid": 0, "staked": 0, "lines": []}
	var res: Dictionary = ev.get("results", {})
	var keep: Array = []
	for b in bets:
		if b["on"] != on or res.is_empty() or int(b["round"]) != int(res["round"]):
			keep.append(b)
			continue
		var winner := -1
		for x in res["list"]:
			if (int(x["a"]) == b["pick"] and int(x["b"]) == b["vs"]) or (int(x["b"]) == b["pick"] and int(x["a"]) == b["vs"]):
				winner = int(x["w"])
		out["staked"] += b["stake"]
		var who: String = pilot_name if b["pick"] == 0 else str(Career.pilot(ev, b["pick"]).get("pilot", "?"))
		if winner == b["pick"]:
			var pay := int(b["stake"] * b["odds"])
			money += pay
			out["paid"] += pay
			out["lines"].append(tr("Bet on %s: +$%d") % [who, pay])
		else:
			out["lines"].append(tr("Bet on %s: lost $%d") % [who, b["stake"]])
	bets = keep
	return out


# ---------------------------------------------------------------- watching other pilots' fights

## Can you watch a & b fight this round? Computer pilots only, once per match, and Kane Dynamics
## keeps OVERLORD's fights behind closed doors.
func can_watch(ev: Dictionary, a: int, b: int) -> bool:
	if ev.is_empty() or a == 0 or b == 0:
		return false
	for id in [a, b]:
		if int(Career.pilot(ev, id).get("rival", -1)) == OPPONENTS.size() - 1 or Career.retired(ev, id):
			return false
	for f in ev.get("forced", []):
		if int(f["round"]) == int(ev["round"]) and ((int(f["a"]) == a and int(f["b"]) == b) or (int(f["a"]) == b and int(f["b"]) == a)):
			return false
	return true


func start_watch(a: int, b: int) -> void:
	var ev := bet_event()
	watching = {"on": bet_target(), "round": int(ev["round"]), "a": a, "b": b}


func watch_event() -> Dictionary:
	if watching.is_empty():
		return {}
	return event if watching["on"] == "event" else circuit


## side 0 = the pilot on the left (a), 1 = the right (b)
func watch_robot(side: int) -> Dictionary:
	var ev := watch_event()
	var id: int = watching["a"] if side == 0 else watching["b"]
	var o := Career.robot_of(ev, id)
	if str(o.get("pilot", "")) == "":
		o["pilot"] = str(Career.pilot(ev, id).get("pilot", ""))
	o["reward"] = 0
	return o


## A watched fight is over: it's the real result. Their robots keep the damage from the ring,
## money and records move, and the round will count it when it's played.
func record_watch(a_won: bool, hp: Array, ripped: Array) -> Dictionary:
	var ev := watch_event()
	var a: int = watching["a"]
	var b: int = watching["b"]
	var w := a if a_won else b
	var l := b if a_won else a
	if not ev.has("forced"):
		ev["forced"] = []
	ev["forced"].append({"round": int(ev["round"]), "a": a, "b": b, "w": w})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stage := "cup" if watching["on"] == "cup" else str(ev["stage"])
	var pw := World.pilot(int(Career.pilot(ev, w).get("wid", -1)))
	var pl := World.pilot(int(Career.pilot(ev, l).get("wid", -1)))
	World.after_fight(rng, pw, pl, stage)
	for side in 2:
		var p := World.pilot(int(Career.pilot(ev, a if side == 0 else b).get("wid", -1)))
		if p.is_empty():
			continue
		p["wear"] = {}
		for slot in hp[side]:
			var mx: float = hp[side][slot][1]
			if mx > 0.0 and float(hp[side][slot][0]) < mx:
				p["wear"][slot] = clampf(float(hp[side][slot][0]) / mx, 0.15, 1.0)
		for sv in ripped[side]:
			for s2 in p["bot"]["parts"]:
				if p["bot"]["parts"][s2] == str(sv.get("id", "")) and s2 != "torso":
					if rng.randf() < 0.6:
						World.lose_part(rng, p, s2)
					break
	var winner_name := str(Career.robot_of(ev, w).get("pilot", Career.pilot(ev, w).get("pilot", "?")))
	watching = {}
	save_game()
	return {"winner": winner_name}


func cups_unlocked() -> bool:
	return unlocked("cups") or rank_index() >= 1 or not trophies.is_empty()


# ---------------------------------------------------------------- multibot teams

# Team robots also fight with less health and punch (on top of their smaller parts).
# sizes: which part sizes CPU teams build with (they fit their share of the power).
const TEAM_MODS := {
	2: {"hp": 0.8, "damage": 0.85, "sizes": ["S", "M"], "label": "TAG TEAM"},
	3: {"hp": 0.65, "damage": 0.75, "sizes": ["S"], "label": "SWARM"},
}
const WINGMAN_NAMES := ["JR", "MK2"]


## A team of smaller robots that share one robot's budget: 2 medium bots or 3 small, weaker bots.
func random_team(rng: RandomNumberGenerator, budget: float, level: float, size: int) -> Dictionary:
	var mods: Dictionary = TEAM_MODS[size]
	var team: Array = []
	var share := budget / size * (1.5 if size == 2 else 1.7)   # small bots buy cheap parts, so a bit more each
	for k in size:
		var b := random_bot(rng, share, level, mods["sizes"])
		b["hp"] = b["hp"] * mods["hp"]
		b["damage"] = b["damage"] * mods["damage"]
		b["power_share"] = TEAM_POWER / size
		team.append(b)
	var lead: Dictionary = team[0].duplicate(true)
	var word: String = BOT_SUFFIX[rng.randi() % BOT_SUFFIX.size()].strip_edges()
	lead["name"] = (tr("THE %sS") % word.to_upper()) if size == 3 else tr("%s & %s") % [team[0]["name"], team[1]["name"]]
	lead["bot_name"] = team[0]["name"]
	lead["team"] = team.slice(1)   # the lead's own fields describe bot 1; "team" holds the others
	lead["team_label"] = mods["label"]
	return lead


func is_team_fight() -> bool:
	return current_opponent().has("team")


## Specs for every enemy robot in the next fight (1 for normal fights).
func current_opponent_team() -> Array:
	if fight_mode() == "quick" and quick.has("enemies"):
		var out: Array = []
		for b in quick["enemies"]:
			out.append(opponent_spec_from(b, 1.0))
		return out
	var specs: Array = [current_opponent_spec()]
	var o := current_opponent()
	for b in o.get("team", []):
		specs.append(opponent_spec_from(b, 1.0))
	return specs


## Specs for the player's side: you, plus your wingmen in team fights.
func fight_player_team() -> Array:
	if fight_mode() == "watch":
		var wa := watch_robot(0)
		var ws: Array = [opponent_spec_from(wa, 1.0)]
		for b in wa.get("team", []):
			ws.append(opponent_spec_from(b, 1.0))
		return ws
	if fight_mode() == "quick":
		var out: Array = []
		for b in quick.get("players", [quick["player"]]):
			var spec := opponent_spec_from(b, 1.0)
			spec["damage_mult"] = b.get("damage", 1.0) if quick.has("players") else 1.0
			spec["speed_mult"] = 1.0
			out.append(spec)
		return out
	# a 1-on-1 can be fought by a backup robot while your main robot sits out
	if not is_team_fight() and sending >= 0 and wingman_ready(sending):
		var solo := player_spec(wingmen[sending], wingman_name(sending))
		solo["wingman"] = sending
		return [solo]
	var team: Array = [player_spec()]
	if is_team_fight():
		for k in wingmen.size():
			if wingman_ready(k):
				var spec := player_spec(wingmen[k], wingman_name(k))
				spec["wingman"] = k
				team.append(spec)
	# weight classes: a team shares one heavyweight's power. Big parts on a team robot overload it.
	if team.size() > 1:
		var mods: Dictionary = TEAM_MODS[team.size()]
		var share := TEAM_POWER / team.size()
		for spec in team:
			spec["damage_mult"] = spec["damage_mult"] * mods["damage"]
			spec["hp_scale"] = mods["hp"]
			var st := stats(wingmen[spec["wingman"]] if spec.has("wingman") else equipped)
			var out := minf(float(st["power_output"]), share)
			spec["efficiency"] = 1.0 if st["power_used"] <= out else out / float(st["power_used"])
			spec["power"] = out
	return team


## Power each robot gets in a team of n (n = 1: no limit).
func team_share(n: int) -> float:
	return TEAM_POWER / n if n > 1 else 9999.0


## Can the robot you're sending into the next fight actually fight?
func can_send() -> bool:
	if not is_team_fight() and sending >= 0:
		return wingman_ready(sending)
	return can_fight()


func sending_name() -> String:
	return wingman_name(sending) if sending >= 0 and not is_team_fight() else robot_name


## Backup robots and the Team tab unlock after the second story fight.
func team_unlocked() -> bool:
	return unlocked("team")


## True the first time a tip is asked for (then it's marked as seen).
func tip_once(id: String) -> bool:
	if tips_seen.has(id):
		return false
	tips_seen.append(id)
	return true


## Wins needed for each feature: one new thing per win, so Gus can explain each one on its own.
const UNLOCKS := {"scrapyard": 0, "style": 1, "shop": 2, "season": 3, "scout": 4, "moves": 5, "cups": 6, "team": 7,
		"workshop": 8, "pilot": 9, "paint": 10, "setups": 11, "randomize": 12}


## Wins, and always a fight after the one that earned it: your first visit to the bay is just
## the bay and the scrapyard; after that one new thing per fight.
func unlocked(feature: String) -> bool:
	var need := int(UNLOCKS.get(feature, 0))
	return champion or (wins >= need and (need == 0 or wins + losses >= need + 1))


## Things that open up in the garage. Each one shows up with a star; the first tap plays a short
## Gus scene ("unlock_<feature>") and then opens it. [feature, garage tab or "" for a button,
## the old one-line tip id (saves from before the scenes count it as already explained)]
const UNLOCK_SCENES := [["scrapyard", "Scrapyard", "scrapyard"], ["storage", "", ""], ["style", "", "style"],
		["shop", "Shop", "shop"], ["season", "Season", "season"], ["scout", "", "scout"], ["moves", "Moves", "moves"],
		["cups", "Cups", ""], ["team", "Team", "backup"], ["workshop", "Workshop", "workshop"], ["pilot", "", "pilot"],
		["paint", "", "pilot"], ["setups", "", "setups"], ["randomize", "", "setups"]]
const TAB_FEATURES := {"Scrapyard": "scrapyard", "Shop": "shop", "Season": "season", "Moves": "moves",
		"Cups": "cups", "Team": "team", "Workshop": "workshop"}
var open_tab := ""      # garage tab to open after an unlock scene
var open_action := ""   # garage button to press after an unlock scene (style, pilot, paint, ...)


## Still has its star: unlocked, and Gus hasn't explained it yet.
func is_new(feature: String) -> bool:
	return not story_seen.has("unlock_" + feature) and Story.SCENES.has("unlock_" + feature)


## Saves from before the unlock scenes: what the old one-line tips explained counts as seen.
func migrate_unlock_scenes() -> void:
	for u in UNLOCK_SCENES:
		if u[2] != "" and tips_seen.has(u[2]) and not story_seen.has("unlock_" + u[0]):
			story_seen.append("unlock_" + u[0])
		if u[1] != "" and tips_seen.has("tab_" + str(u[1])) and not story_seen.has("unlock_" + u[0]):
			story_seen.append("unlock_" + u[0])


## Lines in the story that depend on your game: {RENT_INTRO} and {RENT_GARAGE} follow the
## starting money and rent settings.
func story_dynamic(key: String) -> String:
	var living := living_cost()
	match key:
		"RENT_INTRO":
			var heap := tr("Tell me that heap still does something.")
			if money < 0:
				var owed := -money
				if living > 0 and owed % living == 0:
					var months := owed / living
					if months == 1:
						return tr("A month behind on rent, kid.") + " " + heap
					return (tr("%d months behind on rent, kid.") % months) + " " + heap
				return (tr("You owe me $%d in back rent, kid.") % owed) + " " + heap
			if money == 0:
				return tr("Rent's paid up, kid - and that's every cent you've got.") + " " + heap
			if living > 0 and money < living:
				return (tr("$%d to your name, kid. That won't even cover next month.") % money) + " " + heap
			return (tr("$%d in the bank, kid. Nice cushion. In this business it won't last.") % money) + " " + heap
		"RENT_GARAGE":
			var t := ""
			if money < 0:
				t = tr("And kid - you still owe me $%d in back rent.") % -money + " "
			t += (tr("Rent and food are $%d every month.") % living) if living > 0 else tr("Rent's on the house for now - don't get used to it.")
			return t + " " + tr("No repairs on credit: when we're in the hole, we fight with the dents.")
	return ""


## Gus's one-line garage tips (the bigger news gets a scene of its own, see unlock_scenes).
func garage_tip() -> String:
	if repair_all_cost() > 0 and unlocked("shop") and tip_once("repair"):
		return tr("GUS: ") + tr("Damage carries over between fights. Hit Repair all before the next one - or fix parts one by one.")
	return ""


const TAB_TIPS := {
	"Scrapyard": "GUS: Free junk is always lying around. Digging deeper finds better stuff - but it's beaten up, so budget for repairs.",
	"Shop": "GUS: The dealer's stock changes after every fight. Mini parts sip power, Heavy parts hit hard but drink it.",
	"Workshop": "GUS: Design your own part here. Costs more than the dealer, but it's exactly what you want.",
	"Moves": "GUS: Training chips teach special moves. Better heads hold more chips.",
	"Cups": "GUS: Cups are three-week knockouts in the quiet weeks. Eight pilots, medals for the top three. Some come in tag teams and swarms - your backups fight beside you then.",
	"Season": "GUS: The calendar. Fight nights are Saturdays, rent's due the last Sunday of the month. The league table's the other button - a win is 3 points.",
	"Team": "GUS: Teams share one heavyweight's power, so team robots run small. Mini parts are your friend here.",
}


func tab_tip(tab: String) -> String:
	if TAB_FEATURES.has(tab):
		return ""   # Gus explains these in a scene the first time you open them
	if TAB_TIPS.has(tab) and tip_once("tab_" + tab):
		return tr(TAB_TIPS[tab]).replace("ECHO", robot_name)
	return ""


## Dig through the scrapyard pile. Returns {"text", "part"} (part = id found, or "").
## One dig = one part, always beaten up. Mostly junk, sometimes something decent, rarely a real find.
func dig_scrap() -> Dictionary:
	if digs_left <= 0:
		return {"text": "Too tired to dig. The pile will still be here after the next fight.", "part": ""}
	digs_left -= 1
	var r := randf()
	var pool: Array = []
	var grade := "junk"
	if r < 0.08:
		grade = "good"
		var top := 900 + progress() * 250
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["shop"] and d["cost"] >= 400 and d["cost"] <= top and not UNDAMAGEABLE.has(d["kind"]):
				pool.append(id)
	elif r < 0.35:
		grade = "decent"
		var top := 300 + progress() * 80
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["shop"] and d["cost"] > 0 and d["cost"] <= top and not UNDAMAGEABLE.has(d["kind"]):
				pool.append(id)
	if pool.is_empty():
		grade = "junk"
		for kind in STARTER_OPTIONS:
			pool += STARTER_OPTIONS[kind]
	var id: String = pool[randi() % pool.size()]
	var dug_uid := add_part(id, randf_range(0.15, 0.5))
	inst(dug_uid)["dug"] = true   # shown on the Scrapyard screen; fight salvage only goes to Storage
	var name: String = part_def(id)["name"]
	match grade:
		"good":
			return {"text": tr("Jackpot! A %s, buried under a dead robot. Banged up, but it's real gear (in Storage).") % name, "part": id, "grade": grade}
		"decent":
			return {"text": tr("Found a %s. Dented, but decent (in Storage).") % name, "part": id, "grade": grade}
	var meh := ["More junk: a %s. Rusty, but it bolts on.", "A %s, half eaten by rust. Better than nothing.", "Dug out a %s. Gus says he's seen worse. Not much worse."]
	return {"text": (tr(meh[randi() % meh.size()]) % name) + tr(" (in Storage)"), "part": id, "grade": grade}


func buy_controller(id: String) -> String:
	var info: Dictionary = CONTROLLER_INFO[id]
	if owned_controllers.has(id):
		pilot_look["controller"] = id
		return tr("Your pilot picks up the %s.") % tr(PilotArt.CONTROLLER_NAMES[id])
	if money < int(info["cost"]):
		return tr("The %s costs $%d.") % [tr(PilotArt.CONTROLLER_NAMES[id]), info["cost"]]
	money -= int(info["cost"])
	owned_controllers.append(id)
	pilot_look["controller"] = id
	return tr("Bought the %s! %s") % [tr(PilotArt.CONTROLLER_NAMES[id]), tr(info["desc"])]


func wingman_name(k: int) -> String:
	return tr("%s %s") % [robot_name, WINGMAN_NAMES[k]]


func wingman_ready(k: int) -> bool:
	var w: Dictionary = wingmen[k]
	if w.is_empty():
		return false
	var has_head := false
	for slot in ["head", "head2"]:
		if w.has(slot) and not inst(int(w[slot])).is_empty() and not is_wreck(inst(int(w[slot]))):
			has_head = true
	return has_head and w.has("torso") and not inst(int(w["torso"])).is_empty()


## Build a wingman out of the best spare parts you have.
func build_wingman(k: int) -> String:
	clear_wingman(k)
	var w := {}
	var free := spares().filter(func(p): return not is_wreck(p))
	free.sort_custom(func(a, b): return part_def(a["id"])["cost"] * hp_ratio(a) > part_def(b["id"])["cost"] * hp_ratio(b))
	var order := ["torso", "head", "reactor", "arm_front", "arm_back", "leg_front", "leg_back", "back"]
	# stay inside a team robot's share of the power: best parts that still leave room for the rest
	var budget := team_share(2)
	var used := 0.0
	for i in order.size():
		var slot: String = order[i]
		var room := budget - used - (order.size() - 1 - i) * 1.0
		var pick := {}
		var lightest := {}
		for p in free:
			var d := part_def(p["id"])
			if d["kind"] != SLOT_KIND[slot] or w.values().has(p["uid"]):
				continue
			if lightest.is_empty() or d["draw"] < part_def(lightest["id"])["draw"]:
				lightest = p
			if pick.is_empty() and d["draw"] <= room:
				pick = p   # list is sorted best-first
		if pick.is_empty():
			pick = lightest
		if not pick.is_empty():
			w[slot] = pick["uid"]
			used += part_def(pick["id"])["draw"]
	if w.has("torso"):
		for slot in part_def(inst(int(w["torso"]))["id"])["mounts"]:
			for p in free:
				if part_def(p["id"])["kind"] == SLOT_KIND[slot] and not w.values().has(p["uid"]):
					w[slot] = p["uid"]
					break
	wingmen[k] = w
	if not wingman_ready(k):
		wingmen[k] = {}
		return "Not enough spare parts: a wingman needs at least a head and a torso from your Spares."
	var n := w.size()
	return tr("%s is built from %d spare parts.") % [wingman_name(k), n]


func clear_wingman(k: int) -> void:
	wingmen[k] = {}
	if sending == k:
		sending = -1


func wingman_repair_cost(k: int) -> int:
	var total := 0
	for slot in wingmen[k]:
		var p := inst(int(wingmen[k][slot]))
		if not p.is_empty():
			total += repair_cost(p)
	return total


func repair_wingman(k: int) -> String:
	var c := wingman_repair_cost(k)
	if c == 0:
		return tr("%s is in perfect shape.") % wingman_name(k)
	if not can_repair(c):
		return tr("Repairing %s costs $%d.") % [wingman_name(k), c]
	money -= c
	for slot in wingmen[k]:
		var p := inst(int(wingmen[k][slot]))
		if not p.is_empty():
			p["hp"] = float(part_def(p["id"])["hp"])
	return tr("Repaired %s for $%d.") % [wingman_name(k), c]


## After a team fight: wingmen keep their damage, destroyed parts can be lost.
func apply_wingman_damage(k: int, part_hp: Dictionary, lost: Array, wrecked: Array, cards: Array = []) -> void:
	for slot in part_hp:
		if not wingmen[k].has(slot):
			continue
		var p := inst(int(wingmen[k][slot]))
		if p.is_empty():
			continue
		p["hp"] = maxf(0.0, part_hp[slot])
		if slot == "torso":
			p["hp"] = maxf(1.0, p["hp"])
		if p["hp"] <= 0.0:
			wingmen[k].erase(slot)
			if randf() < 0.5:
				wrecked.append(part_def(p["id"])["name"])
				cards.append({"id": p["id"], "what": "wrecked", "health": 0.0})
			else:
				lost.append(tr("%s (%s)") % [part_def(p["id"])["name"], wingman_name(k)])
				cards.append({"id": p["id"], "what": "lost", "health": 0.0})
				inventory.erase(p)


## Set up a Quick Fight: two random robots of the same strength.
func start_quick_fight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var budget := rng.randf_range(400.0, 4000.0)
	var level := rng.randf_range(0.5, 3.0)
	quick = {"player": random_bot(rng, budget, level), "enemy": random_bot(rng, budget, level)}
	# sometimes a team fight: tag teams and swarms, on either side (or both)
	var formats := [[1, 1], [1, 1], [1, 1], [1, 2], [1, 3], [2, 1], [3, 1], [2, 2], [3, 3], [2, 3], [3, 2]]
	var fmt: Array = formats[rng.randi() % formats.size()]
	if fmt[0] > 1:
		var t := random_team(rng, budget, level, fmt[0])
		quick["players"] = [t] + t["team"]
		quick["player"] = t
	if fmt[1] > 1:
		var t := random_team(rng, budget, level, fmt[1])
		quick["enemies"] = [t] + t["team"]
		quick["enemy"] = t


func fight_player_spec() -> Dictionary:
	if fight_mode() == "quick":
		var spec := opponent_spec_from(quick["player"], 1.0)
		spec["damage_mult"] = 1.0
		spec["speed_mult"] = 1.0
		return spec
	return player_spec()


func current_opponent_spec() -> Dictionary:
	if fight_mode() == "quick":
		return opponent_spec_from(quick["enemy"], 1.0)
	return opponent_spec_from(current_opponent(), 1.0)


func opponent_spec(index: int) -> Dictionary:
	return opponent_spec_from(OPPONENTS[index], 1.0)


func opponent_spec_from(o: Dictionary, _unused: float) -> Dictionary:
	var body := Color(o["body"])
	var parts := {}
	for slot in BODY_SLOTS:
		if not o["parts"].has(slot) or o["parts"][slot] == "":
			parts[slot] = {}
			continue
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
		var now: float = mx * clampf(float(o.get("wear", {}).get(slot, 1.0)), 0.15, 1.0)   # it arrives with last fight's dents
		parts[slot] = {"id": d["id"], "hp": now, "max_hp": mx, "armor": d["armor"] + o.get("armor_bonus", 0),
				"damage": d["damage"], "speed": d["speed"], "aim": d["aim"], "draw": float(d["draw"]),
				"shape": d["shape"], "size": d["size"], "color": c,
				"trait": d["trait"], "trait_lv": d["trait_lv"]}
	var gadgets: Array = []
	for slot in o["parts"]:
		var g: String = part_def(o["parts"][slot])["gimmick"]
		if g != "":
			gadgets.append({"id": g, "slot": slot})
	var back := {}
	if o["parts"].has("back"):
		var bd := part_def(o["parts"]["back"])
		back = {"shape": bd["shape"], "color": Color(bd["color"])}
	# the reactor (and any battery) sets how much power it has in a fight
	var output := 0.0
	for slot in o["parts"]:
		if o["parts"][slot] != "":
			output += float(part_def(o["parts"][slot])["output"])
	if output <= 0.0:
		output = 10.0
	if o.has("power_share"):
		output = minf(output, float(o["power_share"]))
	var eff := 1.0
	if o.has("power_share"):
		var used := 0.0
		for slot in o["parts"]:
			if o["parts"][slot] != "":
				used += part_def(o["parts"][slot])["draw"]
		eff = minf(1.0, float(o["power_share"]) / maxf(1.0, used))
	return {"name": o.get("bot_name", o["name"]), "parts": parts, "efficiency": eff, "damage_mult": o["damage"], "power": output,
			"speed_mult": o["speed"], "scale": o["scale"], "trim": Color(o["trim"]), "eye": Color(o["eye"]),
			"back": back, "gadgets": gadgets, "specials": o["specials"], "style": o.get("style", "striker"),
			"traits": global_traits(o["parts"])}


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
	return {"parts": parts, "trim": spec["trim"], "eye": spec["eye"], "scale": spec["scale"],
			"back": spec.get("back", {})}


func player_look() -> Dictionary:
	return look_from_spec(player_spec())


# ---------------------------------------------------------------- fight results

## Called when a championship match ends.
## part_hp: slot -> remaining hp for the player's parts. destroyed: number of enemy parts ripped off.
## salvage_ids: enemy part ids that were ripped off (some may be salvaged).
func record_result(won: bool, part_hp: Dictionary, destroyed: int, salvage_ids: Array, team_hp: Array = []) -> Dictionary:
	var o := current_opponent()
	var base: int = current_reward()
	var reward: int = base if won else loss_pay(base)
	var bonus := destroyed * 75
	var was_in_debt := money < 0
	money += reward + bonus
	fight_log.append({"y": year, "w": week, "opp": str(o.get("name", "?")), "won": won, "mode": fight_mode(), "title": fight_title()})
	if fight_log.size() > 400:
		fight_log.pop_front()

	# carry the damage over, lose destroyed parts
	var lost: Array = []
	var wrecked: Array = []
	var cards: Array = []   # parts won and lost, shown with pictures on the results screen
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
				cards.append({"id": p["id"], "what": "wrecked", "health": 0.0})
			else:
				lost.append(tr("%s (%s)") % [part_def(p["id"])["name"], tr(SLOT_NAMES[slot])])
				cards.append({"id": p["id"], "what": "lost", "health": 0.0})
				inventory.erase(p)

	for e in team_hp:
		apply_wingman_damage(int(e["wingman"]), e["part_hp"], lost, wrecked, cards)

	# salvage: winners get a chance to keep ripped-off enemy parts
	var salvaged: Array = []
	if won:
		for sv in salvage_ids:
			# parts you aimed at come off cleanly: much better odds
			var chance := 0.75 if sv["aimed"] else 0.25
			if style == "specialist":
				chance += 0.15
			if randf() < chance:
				add_part(sv["id"], 0.35 if sv["aimed"] else 0.2)
				cards.append({"id": sv["id"], "what": "salvaged", "health": 0.35 if sv["aimed"] else 0.2})
				salvaged.append(part_def(sv["id"])["name"] + (tr(" (aimed)") if sv["aimed"] else ""))

	# trophy: sometimes the beaten robot's crew hands over one of its parts
	var trophy := ""
	if won and randf() < 0.3:
		var ids: Array = o["parts"].values().filter(func(x): return x != "")
		var id: String = ids[randi() % ids.size()]
		var d := part_def(id)
		add_part(id, 1.0 if UNDAMAGEABLE.has(d["kind"]) else 0.5)
		cards.append({"id": id, "what": "trophy", "health": 1.0 if UNDAMAGEABLE.has(d["kind"]) else 0.5})
		trophy = d["name"]

	# the pilot you fought lives on: their robot keeps the dents, their wallet moves
	if o.has("wid"):
		var stage := "pickup"
		match fight_mode():
			"story":
				stage = str(event["stage"])
			"circuit":
				stage = "cup"
		World.after_player_fight(int(o["wid"]), won, last_enemy_hp, salvage_ids, stage)
	digs_left = DIGS_PER_FIGHT   # the scrapyard pile gets fresh junk after every fight
	var was_champion := champion
	var mode := fight_mode()
	var cup_done := ""
	var event_done := ""
	var bet_result := {}
	pending_stories = []
	# the scoreboard: what you tore off them
	for sv in salvage_ids:
		var kind: String = part_def(sv["id"])["kind"]
		career_stats["parts"] = int(career_stats.get("parts", 0)) + 1
		if kind == "head" or kind == "arm" or kind == "leg":
			career_stats[kind + "s"] = int(career_stats.get(kind + "s", 0)) + 1
	if won and last_ko == "CORE DESTROYED":
		career_stats["cores"] = int(career_stats.get("cores", 0)) + 1
	if won:
		wins += 1
	else:
		losses += 1
	match mode:
		"story":
			var res: Dictionary = Career.after_player_fight(event, won, destroyed)
			bet_result = settle_bets("event", event)
			if res["phase_changed"] and event["stage"] == "regional" and event.get("qualified", []).has(0) and rank_index() < 2:
				rank = "championship"
				pending_stories.append("regional_semis")
			if res["done"]:
				event_done = finish_event(event)
			advance_week(1)
		"circuit":
			Career.after_player_fight(circuit, won, destroyed)
			bet_result = settle_bets("cup", circuit)
			if circuit["phase"] == "done":
				cup_done = finish_cup()
			advance_week(1)
		"exhibition", "pickup":
			advance_week(1)
	exhibition = false
	pickup = {}
	scout = {}
	roll_stock()
	last_result = {"won": won, "reward": reward, "bonus": bonus, "opponent": o["name"], "lost": lost, "wrecked": wrecked,
			"salvaged": salvaged, "champion": champion and not was_champion,
			"trophy": trophy, "cup_done": cup_done, "event_done": event_done, "out_of_debt": was_in_debt and money >= 0, "cards": cards, "bets": bet_result}
	save_game()
	return last_result


# ---------------------------------------------------------------- championships (after the story)

## An event is over: medals, prize money, trophies, and what you've qualified for.
func finish_event(ev: Dictionary) -> String:
	var info: Dictionary = Career.STAGES[ev["stage"]]
	var m := Career.medal_of(ev, 0)
	var text := tr("%s: %s") % [ev["name"], Career.finish_text(ev)]
	if m > 0:
		var prize: int = info["prizes"][m - 1]
		money += prize
		trophies.append({"kind": ev["stage"], "medal": m, "name": ev["name"], "year": year})
		text += tr(" - prize $%d and a trophy for the bay!") % prize
	match ev["stage"]:
		"scrap":
			if m > 0 and rank_index() < 1:
				rank = "regional"
				pending_stories.append("scrap_medal")
				make_offers()
			elif m == 0:
				pending_stories.append("scrap_out")
		"regional":
			if not ev.get("qualified", []).has(0):
				pending_stories.append("regional_out")
		"championship":
			if m == 1:
				champion = true
				make_offers()
			elif ev.get("qualified", []).has(0) == false:
				pending_stories.append("champ_out")
	return text


func finish_cup() -> String:
	var m := Career.medal_of(circuit, 0)
	var text := tr("%s: %s") % [circuit["name"], Career.finish_text(circuit)]
	if m > 0:
		var prize: int = int(int(circuit["prize"]) * [0, 1.0, 0.5, 0.3][m])
		money += prize
		trophies.append({"kind": "cup", "medal": m, "name": circuit["name"], "year": year})
		text += tr(" - $%d") % prize
		if m == 1:
			circuits_won += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = int(circuit["seed"]) + 1
			var part := random_part_id(rng, ["head", "torso", "arm", "leg", "back", "reactor"][rng.randi() % 6], 99999)
			add_part(part)
			text += tr(" and a brand new %s!") % part_def(part)["name"]
	circuit = {}
	make_offers()
	return text


func make_offers() -> void:
	circuit_offers = []
	var base := clampi(1 + rank_index() + int(circuits_won / 2.0) + (1 if champion else 0), 1, 5)
	for k in 3:
		var tier := clampi(base - 1 + k, 1, 5)
		var seed := randi()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		circuit_offers.append({"name": CIRCUIT_NAMES[rng.randi() % CIRCUIT_NAMES.size()], "tier": tier,
				"seed": seed, "prize": 1000 * tier})


## A cup takes 3 weeks; it has to fit before your next league starts.
func cup_fits() -> bool:
	var nxt := next_event_info()
	if not event.is_empty() and event.get("phase", "") != "done":
		return false
	return nxt[0] == "" or int(nxt[2]) >= 3


func enter_circuit(k: int) -> void:
	var off: Dictionary = circuit_offers[k]
	pickup = {}
	circuit = Career.new_cup(off["name"], int(off["tier"]), int(off["seed"]), week, year, int(off["prize"]))
	circuit_offers.remove_at(k)


func abandon_circuit() -> void:
	circuit = {}
	bets = bets.filter(func(b): return b["on"] != "cup")
	if circuit_offers.size() < 3:
		make_offers()


func random_bot(rng: RandomNumberGenerator, budget: float, level: float, sizes: Array = []) -> Dictionary:
	var parts := {}
	for slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back", "reactor"]:
		parts[slot] = random_part_id(rng, SLOT_KIND[slot], budget, sizes)
	if rng.randf() < 0.15 + level * 0.15:
		var b := random_part_id(rng, "back", budget)
		if b != "":
			parts["back"] = b
	if rng.randf() < 0.5:   # matching pairs look more like a real build
		parts["arm_back"] = parts["arm_front"] if rng.randf() < 0.5 else parts["arm_back"]
		parts["leg_back"] = parts["leg_front"]
	for slot in part_def(parts["torso"])["mounts"]:
		parts[slot] = random_part_id(rng, SLOT_KIND[slot], budget, sizes)
	var specials: Array = []
	var ids: Array = Specials.MOVES.keys().filter(func(x): return not Specials.MOVES[x].has("style"))
	for k in clampi(int(level) + rng.randi_range(0, 1), 0, 5):
		var id: String = ids[rng.randi() % ids.size()]
		if not specials.has(id):
			specials.append(id)
	var body := Color.from_hsv(rng.randf(), rng.randf_range(0.25, 0.75), rng.randf_range(0.3, 0.75))
	return {
		"name": BOT_PREFIX[rng.randi() % BOT_PREFIX.size()] + BOT_SUFFIX[rng.randi() % BOT_SUFFIX.size()],
		"hp": 0.8 + level * 0.11, "damage": 0.8 + level * 0.07, "speed": 0.9 + level * 0.05 + rng.randf_range(-0.05, 0.08),
		"scale": 1.0 if not sizes.is_empty() else rng.randf_range(0.95, 1.15), "think": maxf(0.16, 0.6 - level * 0.09), "block": minf(0.65, 0.1 + level * 0.11),
		"smart": minf(0.95, 0.1 + level * 0.18), "body": "#" + body.to_html(false),
		"trim": "#" + Color.from_hsv(rng.randf(), 0.3, rng.randf_range(0.2, 0.9)).to_html(false),
		"eye": "#" + Color.from_hsv(rng.randf(), 0.9, 1.0).to_html(false),
		"parts": parts, "specials": specials, "style": Catalog.STYLES.keys()[rng.randi() % 4],
	}


func sized_variant(d: Dictionary, c: String) -> Dictionary:
	var m: Dictionary = SIZE_CLASSES[c]
	var v := d.duplicate(true)
	v["id"] = "%s~%s" % [d["id"], c]
	v["name"] = tr("%s %s") % [tr(m["name"]), d["name"]]
	v["variant_of"] = d["id"]
	v["size_prefix"] = tr(m["name"])
	v["size_class"] = c
	v["hp"] = maxi(10, int(d["hp"] * m["hp"]))
	v["armor"] = maxi(0, int(d["armor"]) + int(m["armor"]))
	if d["damage"] > 0:
		v["damage"] = int(d["damage"] * m["damage"])
	if d["kind"] != "head":
		v["speed"] = int(d["speed"]) + int(m["speed"])
	v["draw"] = maxi(1, roundi(d["draw"] * m["draw"]))
	v["cost"] = maxi(10, int(d["cost"] * m["cost"] / 10.0) * 10)
	v["size"] = d["size"] * m["size"]
	return v


## Weight class from the power a build draws.
static func weight_class(power: float) -> String:
	for w in WEIGHT_CLASSES:
		if power <= w[1]:
			return I18n.t(w[0])
	return I18n.t("HEAVYWEIGHT")


func random_part_id(rng: RandomNumberGenerator, kind: String, budget: float, sizes: Array = []) -> String:
	var options: Array = []
	for id in ALL_PARTS:
		var p: Dictionary = PARTS[id]
		if p["kind"] == kind and p["cost"] <= budget and (sizes.is_empty() or not kind in ["head", "torso", "arm", "leg"] or sizes.has(p["size_class"])):
			options.append(p["id"])
	if options.is_empty():
		if kind == "back":
			return ""   # can't afford any back gear: go without
		for id in ALL_PARTS:
			if PARTS[id]["kind"] == kind:
				options.append(id)
				break
	options.sort_custom(func(a, b): return PARTS[a]["cost"] < PARTS[b]["cost"])
	# favour the better parts the budget allows, with some randomness
	var lo := maxi(0, options.size() - 4)
	return options[rng.randi_range(lo, options.size() - 1)]


# ---------------------------------------------------------------- custom part workshop

static func custom_shapes(kind: String) -> Array:
	match kind:
		"head":
			return RobotArt.HEADS.keys()
		"torso":
			return RobotArt.TORSOS.keys()
		"arm":
			return RobotArt.ARMS.keys().filter(func(k): return not k in ["rocket", "grapple"])
		_:
			return RobotArt.LEGS.keys()


## Turn a workshop design into a part definition. cfg: {kind, shape, color, size, grade, alloc, gadget, name}
func custom_def(cfg: Dictionary) -> Dictionary:
	var kind: String = cfg["kind"]
	var info: Dictionary = CUSTOM_KINDS[kind]
	var alloc: Dictionary = cfg["alloc"]
	var pts := custom_points_used(cfg)
	var hp_step: int = CUSTOM_STEP["hp"] * (2 if kind == "torso" else 1)
	var shape: String = cfg["shape"]
	if kind == "arm" and cfg["gadget"] == "rocket_fist":
		shape = "rocket"
	elif kind == "arm" and cfg["gadget"] == "grapple":
		shape = "grapple"
	var d := {
		"id": "", "kind": kind, "name": cfg.get("name", ""), "cost": custom_price(cfg), "shop": false, "custom": true,
		"hp": info["base_hp"] + alloc.get("hp", 0) * hp_step,
		"armor": alloc.get("armor", 0) * CUSTOM_STEP["armor"],
		"damage": alloc.get("damage", 0) * CUSTOM_STEP["damage"],
		"speed": alloc.get("speed", 0) * CUSTOM_STEP["speed"],
		"aim": alloc.get("aim", 0) * CUSTOM_STEP["aim"],
		"chips": (1 + alloc.get("chips", 0)) if kind == "head" else 0,
		"draw": 1 + int(pts / 4.0) + (2 if cfg["gadget"] != "" else 0), "output": 0,
		"shape": shape, "size": cfg["size"], "color": cfg["color"], "gimmick": cfg["gadget"],
	}
	if d["name"] == "":
		d["name"] = tr("Custom %s %s") % [shape.capitalize(), kind.capitalize()]
	# workshop parts are sized by the size slider: small, medium or large
	d["size_class"] = "S" if cfg["size"] < 0.9 else ("L" if cfg["size"] > 1.1 else "M")
	return fill_defaults(d)


## Every part definition gets every field, whatever made it (catalog, workshop, old saves).
static func fill_defaults(d: Dictionary) -> Dictionary:
	var defaults := {"trait": "", "trait_lv": 0, "mounts": [], "hp": 0, "armor": 0, "damage": 0, "speed": 0,
			"aim": 0, "draw": 0, "output": 0, "chips": 0, "shop": true, "size": 1.0, "shape": "", "gimmick": "", "size_class": "M"}
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k] if typeof(defaults[k]) != TYPE_ARRAY else []
	if d.get("kind", "") == "head" and d["chips"] == 0 and not d.get("custom", false):
		d["chips"] = 1
	return d


func custom_points_used(cfg: Dictionary) -> int:
	var n := 0
	for k in cfg["alloc"]:
		n += int(cfg["alloc"][k])
	return n


func custom_price(cfg: Dictionary) -> int:
	return 100 + custom_points_used(cfg) * CUSTOM_POINT_PRICE + (CUSTOM_GADGET_PRICE if cfg["gadget"] != "" else 0)


func forge_custom(cfg: Dictionary) -> String:
	var d := custom_def(cfg)
	if money < d["cost"]:
		return tr("Not enough money - this design costs $%d.") % d["cost"]
	money -= d["cost"]
	d["id"] = "custom_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	custom_parts.append(d)
	PARTS[d["id"]] = d
	var uid := add_part(d["id"])
	for slot in SLOTS:
		if SLOT_KIND[slot] == d["kind"] and equipped[slot] == -1:
			equipped[slot] = uid
			return tr("Forged %s and fitted it to the %s!") % [d["name"], tr(SLOT_NAMES[slot])]
	return tr("Forged %s! It's in your storage - fit it from the Build tab.") % d["name"]


# ---------------------------------------------------------------- randomize & saved setups

## Build a random robot out of every working part you own. Tries to stay within reactor power.
func randomize_robot() -> String:
	var pool := {}
	for p in inventory:
		if is_wreck(p):
			continue
		var kind: String = part_def(p["id"])["kind"]
		if not pool.has(kind):
			pool[kind] = []
		pool[kind].append(p["uid"])
	var old := equipped.duplicate()
	var best := {}
	var best_over := 9999
	for attempt in 80:
		var used := {}
		var trial := {}
		for slot in ["torso"] + SLOTS.filter(func(x): return x != "torso"):
			var choices: Array = pool.get(SLOT_KIND[slot], []).filter(func(u): return not used.has(u))
			if slot == "back" and randf() < 0.25:
				choices = []
			if EXTRA_SLOTS.has(slot) and (trial.get("torso", -1) == -1 or not part_def(inst(trial["torso"])["id"])["mounts"].has(slot)):
				choices = []
			if choices.is_empty():
				trial[slot] = -1
			else:
				trial[slot] = choices[randi() % choices.size()]
				used[trial[slot]] = true
		equipped = trial
		var s := stats()
		var over: int = s["power_used"] - s["power_output"]
		if over < best_over and can_fight():
			best_over = over
			best = trial.duplicate()
			if over <= 0:
				break
	if best.is_empty():
		equipped = old
		return "Not enough parts to build a robot."
	equipped = best
	return "Random build assembled!" + ("" if best_over <= 0 else " (It's overloaded - you need a bigger reactor for this one.)")


func save_setup(k: int) -> String:
	setups[k] = {"name": tr("Setup %d") % (k + 1), "equipped": equipped.duplicate(), "chips": chips.duplicate(), "paint": paint}
	return tr("Saved this build as Setup %d.") % (k + 1)


func load_setup(k: int) -> String:
	var st: Dictionary = setups[k]
	if st.is_empty():
		return "That setup slot is empty."
	var missing: Array = []
	var taken := {}
	for slot in SLOTS:
		var uid := int(st["equipped"].get(slot, -1))
		var p := inst(uid)
		if uid == -1:
			equipped[slot] = -1
		elif p.is_empty() or is_wreck(p) or taken.has(uid):
			missing.append(tr(SLOT_NAMES[slot]))
			equipped[slot] = -1 if slot != "reactor" else equipped[slot]
		else:
			equipped[slot] = uid
			taken[uid] = true
	chips = []
	for id in st.get("chips", []):
		if owned_chips.has(id):
			chips.append(id)
	paint = int(st.get("paint", paint))
	if missing.is_empty():
		return tr("Loaded Setup %d.") % (k + 1)
	return tr("Loaded Setup %d, but these parts are gone or wrecked: %s.") % [k + 1, ", ".join(missing)]


# ---------------------------------------------------------------- story

func queue_story(key: String, return_scene: String) -> bool:
	if story_seen.has(key) or not Story.SCENES.has(key):
		return false
	story_key = key
	story_return = return_scene
	story_queue = []
	return true


## Several scenes in a row (the ones already seen are skipped). False if there's nothing to show.
func queue_stories(keys: Array, return_scene: String) -> bool:
	var fresh: Array = keys.filter(func(k): return not story_seen.has(k) and Story.SCENES.has(k))
	if fresh.is_empty():
		return false
	story_key = fresh[0]
	story_queue = fresh.slice(1)
	story_return = return_scene
	return true


func mark_story_seen(key: String) -> void:
	if not story_seen.has(key):
		story_seen.append(key)


# ---------------------------------------------------------------- save / load

static func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(save_slot if slot < 0 else slot))


func any_save() -> bool:
	for k in range(1, SAVE_SLOTS + 1):
		if has_save(k):
			return true
	return false


## Short description of a save file for the save-slot screen ({} if empty).
func slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	var progress := "Champion" if data.get("champion", false) else tr("Year %d, week %d") % [int(data.get("year", 1)), int(data.get("week", 1))]
	if data.has("event") and typeof(data["event"]) == TYPE_DICTIONARY and not data["event"].is_empty() and not data.get("champion", false):
		progress += " - " + str(Career.STAGES.get(str(data["event"].get("stage", "")), {}).get("short", "")).capitalize()
	return {"pilot": data.get("pilot_name", "Rook"), "robot": data.get("robot_name", DEFAULT_ROBOT), "progress": progress,
			"money": int(data.get("money", 0)), "saved": data.get("saved_at", ""),
			"cups": int(data.get("circuits_won", 0))}


## Move a save from the old single-file version into slot 1.
func migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not has_save(1):
		DirAccess.rename_absolute(OLD_SAVE_PATH, slot_path(1))


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION, "pilot_name": pilot_name, "robot_name": robot_name,
		"saved_at": Time.get_datetime_string_from_system(false, true), "money": money, "inventory": inventory, "equipped": equipped,
		"next_uid": next_uid, "paint": paint, "fight_index": fight_index, "wins": wins,
		"losses": losses, "champion": champion, "story_seen": story_seen,
		"owned_chips": owned_chips, "chips": chips, "circuit": circuit, "circuit_offers": circuit_offers,
		"circuits_won": circuits_won, "pickup": pickup, "setups": setups, "custom_parts": custom_parts,
		"year": year, "week": week, "rank": rank, "event": event, "trophies": trophies, "career_stats": career_stats,
		"style": style, "shop_stock": shop_stock, "scout": scout, "wingmen": wingmen, "sending": sending, "pilot_look": pilot_look, "owned_controllers": owned_controllers, "tips_seen": tips_seen, "digs_left": digs_left, "bills_note": bills_note, "fight_log": fight_log, "bets": bets, "world": world,
	}
	var f := FileAccess.open(slot_path(save_slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


## Returns "" on success, or an error message.
func load_game(slot: int = -1) -> String:
	if slot > 0:
		save_slot = slot
	if not has_save():
		return "No save file."
	var f := FileAccess.open(slot_path(save_slot), FileAccess.READ)
	if f == null:
		return "Couldn't open the save file."
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "The save file is damaged."
	if int(data.get("version", 1)) < 2:
		return "That save is from an older version of the game. Please start a New Game."
	new_game()
	for d in data.get("custom_parts", []):
		var cd: Dictionary = d
		for k in ["hp", "armor", "damage", "speed", "aim", "draw", "output", "chips", "cost"]:
			cd[k] = int(cd.get(k, 0))
		cd["size"] = float(cd.get("size", 1.0))
		fill_defaults(cd)
		custom_parts.append(cd)
		PARTS[cd["id"]] = cd
	inventory = []
	for p in data.get("inventory", []):
		if not part_def(str(p.get("id", ""))).is_empty():
			inventory.append({"uid": int(p["uid"]), "id": str(p["id"]), "hp": float(p["hp"])})
			if bool(p.get("dug", false)):
				inventory[inventory.size() - 1]["dug"] = true
	var eq: Dictionary = data.get("equipped", {})
	for sl in SLOTS:
		var uid := int(eq.get(sl, -1))
		equipped[sl] = uid if not inst(uid).is_empty() else -1
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
	pilot_name = str(data.get("pilot_name", "Rook"))
	robot_name = str(data.get("robot_name", DEFAULT_ROBOT))
	for id in data.get("owned_chips", []):
		if Specials.MOVES.has(id) and not owned_chips.has(id):
			owned_chips.append(id)
	for id in data.get("chips", []):
		if owned_chips.has(id) and not chips.has(id):
			chips.append(id)
	style = str(data.get("style", "striker"))
	sending = int(data.get("sending", -1))
	pilot_look = DEFAULT_PILOT_LOOK.duplicate()
	if typeof(data.get("pilot_look")) == TYPE_DICTIONARY:
		pilot_look.merge(data["pilot_look"], true)
	pilot_look = PilotArt.normalize(pilot_look)
	tips_seen = data.get("tips_seen", []).duplicate()
	digs_left = int(data.get("digs_left", DIGS_PER_FIGHT))
	bills_note = int(data.get("bills_note", 0))
	bets = []
	for b in data.get("bets", []):
		if typeof(b) == TYPE_DICTIONARY:
			bets.append({"on": str(b["on"]), "round": int(b["round"]), "pick": int(b["pick"]), "vs": int(b["vs"]),
					"stake": int(b["stake"]), "odds": float(b["odds"])})
	fight_log = []
	for e in data.get("fight_log", []):
		if typeof(e) == TYPE_DICTIONARY:
			fight_log.append({"y": int(e.get("y", 1)), "w": int(e.get("w", 1)), "opp": str(e.get("opp", "?")), "won": bool(e.get("won", false)),
					"mode": str(e.get("mode", "")), "title": str(e.get("title", ""))})
	owned_controllers = ["gamepad"]
	for c in data.get("owned_controllers", []):
		if CONTROLLER_INFO.has(str(c)) and not owned_controllers.has(str(c)):
			owned_controllers.append(str(c))
	if not owned_controllers.has(pilot_look["controller"]):
		pilot_look["controller"] = "gamepad"
	wingmen = [{}, {}]
	var wm: Array = data.get("wingmen", [])
	for k in mini(2, wm.size()):
		if typeof(wm[k]) == TYPE_DICTIONARY:
			for ws in wm[k]:
				var uid := int(wm[k][ws])
				if not inst(uid).is_empty():
					wingmen[k][str(ws)] = uid
	if not Catalog.STYLES.has(style):
		style = "striker"
	shop_stock = data.get("shop_stock", []).filter(func(id): return PARTS.has(id))
	if shop_stock.is_empty():
		roll_stock()
	scout = data.get("scout", {})
	circuit = data.get("circuit", {})
	if not circuit.is_empty() and not circuit.has("pilots"):
		circuit = {}   # an old-style cup: start fresh
	circuit_offers = data.get("circuit_offers", [])
	circuits_won = int(data.get("circuits_won", 0))
	pickup = data.get("pickup", {})
	if pickup.has("wid"):
		pickup["wid"] = int(pickup["wid"])
	trophies = data.get("trophies", [])
	career_stats = {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
	if typeof(data.get("career_stats")) == TYPE_DICTIONARY:
		career_stats.merge(data["career_stats"], true)
	if data.has("event"):
		year = int(data.get("year", 1))
		week = int(data.get("week", 1))
		rank = str(data.get("rank", "scrap"))
		event = data.get("event", {})
		_fix_numbers(event)
		_fix_numbers(circuit)
	else:
		# a save from before the career: put it where its story progress was
		year = 1
		rank = "scrap" if fight_index < 3 else ("regional" if fight_index < 6 else "championship")
		week = int(Career.STAGES[rank]["start"])
		event = {} if champion else Career.new_event(rank, year, randi())
		if champion:
			week = 42
	migrate_unlock_scenes()
	if typeof(data.get("world")) == TYPE_DICTIONARY and not (data["world"] as Dictionary).get("pilots", {}).is_empty():
		world = data["world"]
		_fix_world()
	# (an older save keeps the fresh world new_game() made)
	var saved_setups: Array = data.get("setups", [])
	for k in mini(saved_setups.size(), SETUP_SLOTS):
		setups[k] = saved_setups[k]
	if champion and circuit.is_empty() and circuit_offers.is_empty():
		make_offers()
	return ""


## JSON turned the world's whole numbers into floats.
func _fix_world() -> void:
	world["next"] = int(world.get("next", 1))
	for p in world["pilots"].values():
		for k in ["wid", "cash", "age", "w", "l", "sw", "sl", "ret_y", "ret_w"]:
			if p.has(k):
				p[k] = int(p[k])
		p["skill"] = float(p.get("skill", 0.3))
		p["retired"] = bool(p.get("retired", false))
		if typeof(p.get("wear")) != TYPE_DICTIONARY:
			p["wear"] = {}
		for slot in p["bot"]["parts"].keys():
			if part_def(str(p["bot"]["parts"][slot])).is_empty() and str(p["bot"]["parts"][slot]) != "":
				p["bot"]["parts"][slot] = World.cheapest(RandomNumberGenerator.new(), SLOT_KIND.get(slot, "head"))
	for n in world.get("news", []):
		n["y"] = int(n["y"])
		n["w"] = int(n["w"])


## JSON turns every number into a float; the career code wants whole numbers for ids and rounds.
func _fix_numbers(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	for k in ["round", "year", "seed", "tier", "prize"]:
		if ev.has(k):
			ev[k] = int(ev[k])
	ev["weeks"] = ev.get("weeks", []).map(func(w): return int(w))
	ev["schedule"] = ev.get("schedule", []).map(func(w): return int(w))
	for e in ev.get("pilots", []):
		e["id"] = int(e["id"])
		if e.has("rival"):
			e["rival"] = int(e["rival"])
		if e.has("wid"):
			e["wid"] = int(e["wid"])
	if typeof(ev.get("forced")) == TYPE_ARRAY:
		for f in ev["forced"]:
			for k in f:
				f[k] = int(f[k])
	else:
		ev.erase("forced")
	for key in ev.get("table", {}):
		ev["table"][key] = ev["table"][key].map(func(v): return int(v))
	if not ev.get("bracket", {}).is_empty():
		ev["bracket"]["r"] = int(ev["bracket"]["r"])
		for rnd in ev["bracket"]["rounds"]:
			for m in rnd:
				for k in ["a", "b", "w"]:
					m[k] = int(m[k])
	ev["qualified"] = ev.get("qualified", []).map(func(v): return int(v))
	if ev.has("pairs"):
		ev["pairs"]["round"] = int(ev["pairs"]["round"])
		ev["pairs"]["list"] = ev["pairs"]["list"].map(func(pr): return [int(pr[0]), int(pr[1])])
	if ev.has("results"):
		ev["results"]["round"] = int(ev["results"]["round"])
		for x in ev["results"]["list"]:
			for k in ["a", "b", "w"]:
				x[k] = int(x[k])


func delete_save(slot: int = -1) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(save_slot if slot < 0 else slot))


static func random_pilot_name() -> String:
	return PILOT_NAMES[randi() % PILOT_NAMES.size()]


static func random_robot_name() -> String:
	return ROBOT_FIRST[randi() % ROBOT_FIRST.size()] + ROBOT_LAST[randi() % ROBOT_LAST.size()]


## Frame cap: 60, or 30 in battery saver. Menus use low-power mode (only redraw when something changes).
func apply_performance() -> void:
	Engine.max_fps = 30 if settings.get("battery_saver", false) else 60
	OS.low_processor_usage_mode = true


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


## Back to how the game came out of the box (keeps the language).
func reset_settings() -> void:
	var lang: String = settings.get("lang", "en")
	settings = DEFAULT_SETTINGS.duplicate(true)
	settings["lang"] = lang
	save_settings()
	apply_performance()


func set_language(lang: String) -> void:
	if not I18n.LANGS.has(lang):
		lang = "en"
	settings["lang"] = lang
	I18n.setup(lang)
	# brand parts: the brand stays, the model is translated; then Mini / Heavy versions
	for id in PARTS:
		var d: Dictionary = PARTS[id]
		if d.has("variant_of") or d.get("custom", false):
			continue
		if d.has("model"):
			d["name"] = "%s %s%s" % [d["brand_name"], I18n.t(str(d["model"])), " X" if d.get("tier_x", false) else ""]
		else:
			d["name"] = I18n.t(str(d.get("name_en", d["name"])))
	for id in PARTS:
		var d: Dictionary = PARTS[id]
		if d.has("variant_of") and PARTS.has(d["variant_of"]):
			d["name"] = "%s %s" % [I18n.t(str(d["size_prefix"])), PARTS[d["variant_of"]]["name"]]


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
		settings["start_money"] = int(settings["start_money"])
		settings["living_cost"] = int(settings["living_cost"])
		settings["coaching"] = int(settings["coaching"])
		settings["lang"] = str(settings.get("lang", "en"))
		if typeof(settings["layout"]) != TYPE_DICTIONARY:
			settings["layout"] = {}
