extends Node
const PlayLog = preload("res://playlog.gd")   # (1.87) the playtest log

# helper scripts, loaded by path so the game also runs without an editor scan
## The game's version, shown on the main menu. Bump it with every change (1.1, 1.2, ...).
const VERSION := "1.89"
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
const SAVE_SLOTS := 8
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 7   # 7: part HP x3 torso, x2 head/arms/legs. 6: part grades. 5: Scrap/Rust/Iron/Steel + the Championship cup (older saves are converted on load)
const START_MONEY := -1000   # default: you start in debt (back rent to Gus) and climb out
const MONTH_WEEKS := 4        # every 4 weeks...
const LIVING_COST := 1000     # ...rent and food come out of your balance (default)
## Money difficulty (Settings), separate from CPU difficulty
const START_MONEY_OPTIONS := [1000, 300, 0, -1000, -2000, -3000]
const LIVING_COST_OPTIONS := [0, 250, 500, 1000, 1500, 2000]
const DEFAULT_ROBOT := "ECHO"
const Career = preload("res://career.gd")
const World = preload("res://world.gd")
const Social = preload("res://social.gd")
const Contracts = preload("res://contracts.gd")
const Clips = preload("res://clips.gd")
const PILOT_NAMES := ["Rook", "Marisol", "Dex", "Kit", "Juno", "Tavi", "Bram", "Nia", "Otto", "Zara", "Lio", "Mags",
		"Finn", "Ines", "Cass", "Rafa", "Wren", "Bo", "Sully", "Pia", "Grit", "Nova", "Ash", "Teo"]
const ROBOT_FIRST := ["ECHO", "RUSTY", "BOLT", "PISTON", "SPARKY", "TANK", "GIZMO", "COPPER", "TORQUE", "DYNAMO",
		"SPROCKET", "ZIPPY", "BRUISER", "WIDGET", "AXLE", "NUTS", "BLITZ", "CRANK"]
const ROBOT_LAST := ["", "", "", " JR", " MK II", " 3000", "-9", " PRIME", " ZERO", "-X"]

# Robot slots. Front = the side facing the camera (drawn in front).
const SLOTS := ["head", "head2", "torso", "arm_front", "arm_back", "arm_front2", "arm_back2", "leg_front", "leg_back", "back", "reactor", "reactor2"]
const SLOT_NAMES := {"head": "Head", "head2": "Second Head", "torso": "Torso", "arm_front": "Left Arm", "arm_back": "Right Arm",
		"arm_front2": "Lower Left Arm", "arm_back2": "Lower Right Arm",
		"leg_front": "Left Leg", "leg_back": "Right Leg", "back": "Back Gear", "reactor": "Reactor", "reactor2": "Second Reactor"}
const SLOT_KIND := {"head": "head", "head2": "head", "torso": "torso", "arm_front": "arm", "arm_back": "arm",
		"arm_front2": "arm", "arm_back2": "arm", "leg_front": "leg", "leg_back": "leg", "back": "back", "reactor": "reactor", "reactor2": "reactor"}
const EXTRA_SLOTS := ["head2", "arm_front2", "arm_back2", "reactor2"]   # only exist on torsos with mount points (four-arm torsos also take a second reactor)
## Off-label fitting (1.54): when you're poor and out of parts, anything goes, at a price.
##   a reactor in an arm slot: no arm on that side, the reactor gives OFF_REACTOR of its output
##   a leg in an arm slot: punches with a foot, OFF_LEG_ARM damage and speed points off
##   an arm in a leg slot: walks on its fist, OFF_ARM_LEG speed and damage points off
const OFF_REACTOR := 0.5
const OFF_LEG_ARM := {"damage": -35, "speed": -20}
const OFF_ARM_LEG := {"damage": -30, "speed": -35}
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
	{"id": "torso_box",    "kind": "torso", "name": "Tin Box",     "cost": 200,  "hp": 100, "armor": 5,  "speed": 0,   "draw": 2, "shape": "box",    "color": "#5b6f8a"},
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
	{"id": "arm_rod",      "kind": "arm", "name": "Rebar Arm",   "cost": 150,  "hp": 45, "armor": 5,  "damage": 10, "speed": 5,   "draw": 2, "shape": "rod",    "color": "#8f9aa6"},
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
	{"id": "leg_steel",    "kind": "leg", "name": "Strut Leg",   "cost": 150,  "hp": 50,  "armor": 5,  "damage": 5,  "speed": 5,   "draw": 2, "shape": "rod",     "color": "#8f9aa6"},
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
const EXHIBITION_REWARD := 30000
## Story rivals fight in their own league's grade: Scrap 0-2, Rust 3-5, Iron 6-8, OVERLORD Steel.
const RIVAL_GRADE := [1, 1, 1, 2, 2, 2, 3, 3, 3, 4]


## A story rival's robot, in the grade of the league it fights in.
func rival(idx: int) -> Dictionary:
	var o: Dictionary = OPPONENTS[idx].duplicate(true)
	var g: int = RIVAL_GRADE[clampi(idx, 0, RIVAL_GRADE.size() - 1)]
	for slot in o["parts"]:
		o["parts"][slot] = graded_id(str(o["parts"][slot]), g)
	o["rival"] = true   # a story rival: a level sharper with the crosshair
	if idx == OPPONENTS.size() - 1:
		o["aim_level"] = 5
	# story rivals bring dents like anyone in their league
	World.league_wear(o, ["scrap", "rust", "iron", "steel"][clampi(idx / 3, 0, 3)], "rival%d" % idx)
	return o
const SETUP_SLOTS := 4
const CIRCUIT_NAMES := ["Rust Belt Cup", "Neon Night League", "Dockside Brawl", "Chrome Crown", "Scrapheap Classic",
		"Thunderdome Trials", "Gearhead Gauntlet", "Iron Harbor Open", "Voltage Vault Cup", "Junkyard Jamboree"]
const BOT_PREFIX := ["RUST", "IRON", "VOLT", "SCRAP", "STEEL", "CHROME", "MAG", "TURBO", "GRIM", "NEON", "BOLT", "HEX",
		"COG", "SLAG", "OHM", "TITAN", "BUZZ", "ROT"]
const BOT_SUFFIX := ["JAW", "FIST", "KING", "BITE", "WRECK", "TRON", "BUSTER", "CRUSH", "HOWL", "DOZER", "SPARK", "FANG",
		"BOX", "MAW", "GRINDER", "BARON", "HULK", "VIPER"]
const TIER_BUDGET := [500, 1500, 4500, 13500, 40000]
## Cups (tier 1-5): a round pays this (more each round); the winner's prize is CUP_PRIZE.
const CUP_PURSE := [400, 1200, 3600, 11000, 33000]
const CUP_PRIZE := [1500, 4500, 13500, 40000, 120000]
## Running costs: Gus's rent in the gutter and Scrap, then a mechanic, a crew, travel... (x the Settings amount / $1,000)
const RUNNING := {"open": 0.5, "scrap": 1.0, "rust": 2.8, "iron": 9.0, "steel": 28.0}

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
const CUSTOM_POINT_PRICE := 60   # x3 per grade: the workshop builds in your league's grade
const CUSTOM_GADGET_PRICE := 250
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
var spare_controllers: Array = []   # dug-up controllers waiting in Storage (1.54): add one to your gear, or sell it
var tips_seen: Array = []
var opening_replay := false   # the opening cutscene was asked for again (BotMedia): back to the bay after it
var social := {}      # BotMedia: posts, follows, your followers (social.gd)
var films := {}       # (1.75) key -> a whole filmed fight (its own file, films_path(); the newest FILMS_KEEP)
var films_dirty := false
var clips_dirty := false
var film_index := {}  # (1.75) key -> {clips, ko, secs}: what came of each filmed fight
var film_pending: Array = []   # (1.75) background films still to make (survive a reload)
var films_seen: Array = []     # (1.75) "stage:year:round" nights already picked through
var clips := {}       # (1.74) id -> clip (clips.gd). Posted clips stay forever; "temp" ones wait on the post you haven't made yet
var contracts := {}   # sponsor contracts and offers (contracts.gd)
var alerts_unseen := 0   # new BotMedia alerts (the rail lights up)
var tips_log: Array = []   # Gus's fight tips as he said them ({"id", "text"}, oldest first): the pause screen lists them
const DIGS_PER_FIGHT := 1
var digs_left := DIGS_PER_FIGHT   # scrapyard digs: one a day
## The chance a dig finds anything (1.53): +15% for every day you leave the pile alone, up to 90%.
## Digging spends it. DIG_RARE_SHARE of it can be something rare; of the rest, DIG_GOOD is good
## gear, DIG_DECENT decent, the remainder junk. Digging for one kind of part: odds x DIG_KIND_K.
const DIG_LUCK_STEP := 0.2
const DIG_LUCK_MAX := 0.9
const DIG_LUCK_START := 0.45   # a new game: the pile's been waiting for you
const DIG_RARE_SHARE := 0.08
const DIG_GOOD := 0.2
const DIG_DECENT := 0.45
const DIG_KIND_K := 0.5
var dig_luck := DIG_LUCK_START
var forfeit := false   # the fight being recorded was quit (counts as a loss, pays nothing)   # Gus's one-time tips (fight and garage) already shown
var inventory: Array = []   # [{uid, id, hp}]
var equipped := {}          # slot -> uid (-1 = empty)
var gantries := 0          # gantries bought for backup robots (each one is a robot more, and more rent)
const GANTRY_PRICE := 1500     # the first; each further gantry costs double
const GANTRY_RENT := 0.35      # each gantry adds this share of your running costs every month
var wingmen: Array = [{}, {}]   # extra robots for team fights, built from spares: [{slot: uid}, ...]
var sending := -1           # which robot fights the next 1-on-1: -1 = your main robot, 0/1 = a backup robot
var next_uid := 1
var paint := 0
var fight_index := 0        # (old saves) story fights won; the career now lives in year/week/event
var year := 1
var week := 1
var day := "mon"            # today: "mon".."sun" (cup rounds on "wed", leagues on "sat", pickups any day)
const DAYS := ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
var rank := "open"          # your level: open (the gutter, no league) / scrap / rust / iron / steel
var event := {}             # the league or playoffs you're in (see career.gd)
## Your dad's trophies: on the office wall from day one, yours go up beside them.
const DAD_TROPHIES := [
	{"kind": "scrap", "medal": 1, "name": "Scrap League", "dad": true, "run": 0},
	{"kind": "rust", "medal": 1, "name": "Rust League", "dad": true, "run": 1},
	{"kind": "iron", "medal": 2, "name": "Iron League", "dad": true, "run": 2},
]
## Your dad's runs behind those trophies (1.63): the season, the record, the fights people still talk
## about ([week, won, robot, pilot, note]) and what Gus remembers. Shown when you tap one in the office.
const DAD_RUNS := [
	{"season": 2039, "w": 21, "l": 3, "fights": [
		[4, true, "RUSTBUCKET", "JONNO PRICE", "His first league win. ECHO had one working arm."],
		[11, false, "GRINDLE", "MAGS OKAFOR", "His first loss. He watched the tape all night."],
		[19, true, "GRINDLE", "MAGS OKAFOR", "The rematch. Over in forty seconds."],
		[47, true, "TALLBOY", "RUI SANTOS", "Won the title with a round to spare."]],
		"gus": "Nobody gave him a chance. He fixed that robot on my floor with parts he dug himself."},
	{"season": 2040, "w": 20, "l": 4, "fights": [
		[4, false, "CLADDAGH", "IRONCLAD MAE", "Lost the first three. People said he'd peaked."],
		[10, true, "CLADDAGH", "IRONCLAD MAE", "Started a run of seventeen wins in a row."],
		[33, true, "BULLFROG", "TEO VARGA", "Tore off both arms, both whole. The crowd stood up."],
		[50, true, "WRECKONER", "SAL DUNNE", "Gold. He gave the purse to the pilots' fund."]],
		"gus": "Seventeen in a row. I stopped locking the bay at night, he never went home anyway."},
	{"season": 2041, "w": 19, "l": 5, "fights": [
		[6, true, "HAMMERHEAD", "LENA BRANDT", "Out jabbed the best guard in the league."],
		[24, false, "VANTAGE", "OTTO KRUSE", "Beaten on a split decision. Still says he won."],
		[46, true, "SLEDGE", "KOVAC", "The uppercut. SLEDGE's head is still in the rafters."],
		[50, false, "VANTAGE", "OTTO KRUSE", "Second on parts torn off. One part short."]],
		"gus": "Silver, one part short of gold. The next season Kane changed everything."},
]
var trophies: Array = []    # [{kind: scrap/regional/championship/cup, medal: 1-3, name, year}]
var career_stats := {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
var story_queue: Array = [] # more story scenes to show after the current one
var bay_stories: Array = [] # story scenes the garage plays when you get back (post-fight talk, medals)
var converted_note := false   # this save was converted to the year-round tables (Gus explains once)
var leagues: Dictionary = {}
var title_seeds: Array = []     # who's in next year's Titanium Championship (event entries, best first; "player" = you)
var h2h: Dictionary = {}        # world pilot wid -> [your wins, your losses] against them
var rivals: Array = []          # wids of the pilots who've become your rivals
var rel: Dictionary = {}        # wid -> -100 (nemesis) .. +100 (best friend): what's between you two (1.58)
var nemeses: Array = []         # wids that crossed REL_NEMESIS: they stay rivals till you beat them
var pending_talk: Array = []    # emergent lines waiting for the garage (hate mail etc.)
var inbox: Array = []           # everything anyone said to you, oldest first: {y, w, d, ph, who, text, kind, look}
const INBOX_MAX := 400
var tour := -1                  # Gus's tour of the bay after the first fight: the step you're on (-1 = done / none)
var inbox_seen := 0             # how much of the inbox you've looked at (the rail shows a star for new)
const REL_RIVAL := -40.0        # at or below: a rival (taunts, revenge, hate mail)
const REL_NEMESIS := -80.0      # at or below: your nemesis (stuck at -40 or worse until you beat them)
const REL_FRIEND := 40.0        # at or above: a friend (greets you, teams up, cheers you on)
const REL_BEST := 80.0          # at or above: a best friend
const REL_SOCIAL_CAP := 40.0    # likes, reposts and replies alone only get you this far: the rest is earned in the ring
const REL_FIGHT_K := 10.0       # a fight moves it this much x what the fight meant
var streak := 0                 # + wins in a row, - losses in a row
var pub_seen := ""              # the day you last walked into The Rusty Bolt (the patron says hi once)
const Talk = preload("res://talk_lines.gd")   # this year's division tables: stage -> event (yours is also `event`)
var pending_stories: Array = []   # scenes the last result unlocked (shown after the fight)
var last_ko := ""
var bills_note := 0         # living costs charged since the garage last showed them
var fight_log: Array = []   # every fight: {y, w, opp, won, mode, title} - for the calendar
var bets: Array = []        # this week's bets: {on: "event"/"cup"/"self", round, pick, vs, stake, odds}
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
var test_drive := {}          # Scrapyard Test Drive: {"junker": id, "try": part id or "", "slot": slot} - never saved, no damage
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
# Grades: every common part design comes in all five, and the grade sets how big its numbers are.
# Each grade up multiplies HP and hit damage by the Pecking Order (Settings) and the price by 3.
# Grade 1 (Scrap) is the plain id; higher grades end in "^2".."^5". Junk is grade 0.
const GRADES := ["Junk", "Scrap", "Rust", "Iron", "Steel", "Titanium"]
const GRADE_COLORS := ["#8a8f98", "#9a6a4a", "#d0702c", "#7d8794", "#6fa8dc", "#e0c25a"]
const GRADE_PRICE := 3.0
const PECKING := [{"name": "Underdog", "k": 1.4}, {"name": "Standard", "k": 1.5}, {"name": "Brutal", "k": 1.6}]
## A league's grade: the gutter and Scrap use Scrap grade, then one grade per league.
const RANK_GRADE := {"open": 1, "scrap": 1, "rust": 2, "iron": 3, "steel": 4}
# Weight class = total power your parts draw. [name, max power]
const WEIGHT_CLASSES := [["LIGHTWEIGHT", 12], ["MIDDLEWEIGHT", 22], ["HEAVYWEIGHT", 9999]]
# A team shares one heavyweight's worth of power: 2 robots get half each, 3 get a third.
const TEAM_POWER := 40.0
var style := "striker"        # fighting style: tank, striker, mechanic, specialist
var style_locked := false     # one style change between fights (no switching to Mechanic just to repair cheap)
var shop_stock: Array = []    # part ids for sale right now (new stock every Sunday)
var chip_stock: Array = []    # training chips the dealer has right now (rolled with the parts)
const CHIP_ORDER_MARKUP := 2.0   # ordering a chip made to order costs double
var scout := {}               # scouting report on the next opponent: {key, spied_back, change}
var owned_chips: Array = []   # special-move chips bought
var chips: Array = []         # chips installed (only the first chip_slots() of them run)
var last_result := {}       # handed from the fight to the garage
var story_key := ""         # which story scene to show next
var story_return := ""      # scene to go to after the story
const DEFAULT_SETTINGS := {"sound": true, "music": true, "shake": true, "button_size": 1, "difficulty": 1, "layout": {}, "team_controls": "linked", "battery_saver": false, "rev": 3,
		"start_money": START_MONEY, "living_cost": LIVING_COST, "coaching": 2, "lang": "en", "pecking": 1, "edges": 0, "text": UI.TEXT_DEFAULT}
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
	if _save_due >= 0.0 and Time.get_ticks_msec() / 1000.0 >= _save_due:
		_save_due = -1.0
		save_game()
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
		if (d["mounts"] as Array).has("arm_front2") and not (d["mounts"] as Array).has("reactor2"):
			d["mounts"] = (d["mounts"] as Array) + ["reactor2"]   # a four-arm frame has room for a second reactor
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
		d["hp"] = int(round(float(d["hp"]) * hp_mult(str(d["kind"]))))   # 1.40 numbers -> the tougher 1.41 parts
		d["cost_v5"] = int(d["cost"])   # the price before grades (old saves get their grade from it)
		d["cost"] = grade_one_price(int(d["cost"]))
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
	build_grades()
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
	places_been = ["home"]
	pilot_at = "home"
	owned_controllers = ["gamepad"]
	spare_controllers = []
	tips_seen = []
	tips_log = []
	h2h = {}
	rivals = []
	rel = {}
	nemeses = []
	pending_talk = []
	inbox = []
	day_log = {}
	ledger = []
	bet_log = []
	patched_week = -1
	loan = {}
	gus_alerts = []
	inbox_seen = 0
	social = {}
	clips = {}
	clips_dirty = true
	films = {}
	films_dirty = true
	film_index = {}
	film_pending = []
	films_seen = []
	if get_tree() != null and get_node_or_null("/root/Film") != null:
		get_node("/root/Film").clear()
	contracts = {}
	alerts_unseen = 0
	tour = 0
	streak = 0
	pub_seen = ""
	digs_left = DIGS_PER_FIGHT
	dig_luck = DIG_LUCK_START
	day = "mon"
	robot_name = DEFAULT_ROBOT
	inventory = []
	equipped = {}
	wingmen = [{}, {}]
	gantries = 0
	bay_level = 0
	sending = -1
	phase = 0
	jobs = []
	bolted = {}
	mechanics = 0
	overtime = false
	next_uid = 1
	for slot in SLOTS:
		equipped[slot] = add_part(STARTER[slot]) if STARTER.has(slot) else -1
	paint = 0
	fight_index = 0
	year = 1
	week = 1
	rank = "open"   # the gutter: no league yet. A few pickups at the Rusty Bolt, then the Open Trials
	title_seeds = []
	trophies = []
	career_stats = {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
	watching = {}
	World.create(randi())
	leagues = {}
	event = {}
	start_year()
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
	style_locked = false
	scout = {}
	shop_stock = []
	quick = {}
	test_drive = {}
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
	bolt_everything()


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


## The grade the dealer stocks for you: your league's (Titanium once you're the champion).
func my_grade() -> int:
	return 5 if champion else int(RANK_GRADE.get(rank, 1))


## Restock the shop: mostly parts of your grade, a few one grade up, and one "special order"
## from the grade above that (cheapest end of it).
func roll_stock() -> void:
	var g := my_grade()
	var here: Array = []
	var up: Array = []
	for id in ALL_PARTS:
		var d: Dictionary = PARTS[id]
		if not d["shop"] or d["cost"] <= 0:
			continue
		if int(d.get("grade", 0)) == g:
			here.append(id)
		elif int(d.get("grade", 0)) == g + 1:
			up.append(id)
	here.shuffle()
	up.shuffle()
	var n_up := 2 if not up.is_empty() else 0
	shop_stock = here.slice(0, STOCK_SIZE - n_up) + up.slice(0, n_up)
	# training chips are just more stock: one or two the dealer happens to have
	var max_cost := 600 + progress() * 380
	var chips_pool: Array = chip_ids().filter(func(id): return not owned_chips.has(id) and int(Specials.MOVES[id]["cost"]) <= max_cost * 1.6)
	chips_pool.shuffle()
	chip_stock = chips_pool.slice(0, 1 + (1 if randf() < 0.5 else 0))


func reroll_cost() -> int:
	return int(REROLL_COST * pow(GRADE_PRICE, my_grade() - 1))


func reroll_stock() -> String:
	if money < reroll_cost():
		return tr("Restocking costs $%d.") % reroll_cost()
	book("parts", -(reroll_cost()))
	roll_stock()
	return "The dealer wheeled in a fresh load of parts."


## Is this slot usable right now? Extra slots need a torso with the right mount.
## Can this part go in this slot? Its own kind always; off-label (1.54): a reactor or a leg in an
## arm slot, an arm in a leg slot (never the extra lower arms' slots for legs, the frame won't take them).
func fits(d: Dictionary, slot: String) -> bool:
	var sk: String = SLOT_KIND.get(slot, "")
	var k := str(d.get("kind", ""))
	if k == sk:
		return true
	if sk == "arm" and k == "reactor":
		return true
	if sk == "arm" and k == "leg" and not slot.ends_with("2"):
		return true
	if sk == "leg" and k == "arm":
		return true
	return false


## "" for a part in its own kind of slot, else "reactor_arm" / "leg_arm" / "arm_leg".
func off_label(d: Dictionary, slot: String) -> String:
	var sk: String = SLOT_KIND.get(slot, "")
	var k := str(d.get("kind", ""))
	if k == sk:
		return ""
	return k + "_" + sk


## What an off-label fit costs you, in one line ("" when it's a normal fit).
func off_label_text(d: Dictionary, slot: String) -> String:
	match off_label(d, slot):
		"reactor_arm":
			return tr("No arm on that side, and the reactor only gives half its power (%d).") % int(float(d.get("output", 0)) * OFF_REACTOR)
		"leg_arm":
			return tr("Punches with a foot: damage %d, speed %d.") % [int(OFF_LEG_ARM["damage"]), int(OFF_LEG_ARM["speed"])]
		"arm_leg":
			return tr("Walks on its fist: speed %d, kicks %d.") % [int(OFF_ARM_LEG["speed"]), int(OFF_ARM_LEG["damage"])]
	return ""


## Which off-label fits the robot is running: ["leg_arm", "reactor_arm", ...] (no repeats).
func off_label_kinds(eq: Dictionary = {}) -> Array:
	if eq.is_empty():
		eq = equipped
	var out: Array = []
	for slot in BODY_SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if not p.is_empty():
			var o := off_label(part_def(p["id"]), slot)
			if o != "" and not out.has(o):
				out.append(o)
	return out


## Is anything on this robot fitted off-label?
func has_off_label(eq: Dictionary = {}) -> bool:
	if eq.is_empty():
		eq = equipped
	for slot in BODY_SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if not p.is_empty() and off_label(part_def(p["id"]), slot) != "":
			return true
	return false


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


## How whole the robot is (all body parts together, by HP), as it stands.
func robot_hp_ratio() -> float:
	var have := 0.0
	var full := 0.0
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if p.is_empty():
			continue
		have += float(p["hp"])
		full += float(part_def(p["id"])["hp"])
	return 1.0 if full <= 0.0 else clampf(have / full, 0.0, 1.0)


func hp_ratio(p: Dictionary) -> float:
	var mx: float = part_def(p["id"])["hp"]
	return 1.0 if mx <= 0.0 else clampf(p["hp"] / mx, 0.0, 1.0)


func buy(id: String) -> String:
	var d := part_def(id)
	if money < d["cost"]:
		return "Not enough money."
	book("parts", -(d["cost"]))
	shop_stock.erase(id)
	Contracts.on_buy()
	var uid := add_part(id)
	for slot in SLOTS:
		if SLOT_KIND[slot] == d["kind"] and equipped[slot] == -1 and slot_available(slot) and slot != "reactor2":
			equipped[slot] = uid
			return tr("Bought %s and fitted it to the %s.") % [d["name"], tr(SLOT_NAMES[slot])]
	return tr("Bought %s. It's in your Spares, equip it from there.") % d["name"]


func equip(uid: int, slot: String) -> String:
	var p := inst(uid)
	if p.is_empty():
		return "That part is gone."
	release_from_wingman(uid)
	p.erase("dug")   # fitted: it's not a fresh find any more
	var d := part_def(p["id"])
	if is_wreck(p):
		return tr("%s is a wreck. Rebuild it first.") % d["name"]
	if not fits(d, slot):
		return tr("A %s doesn't fit the %s.") % [d["name"], tr(SLOT_NAMES[slot])]
	if not slot_available(slot):
		return tr("Your torso has no mount for a %s.") % str(SLOT_NAMES[slot]).to_lower()
	var old_slot := slot_of_uid(uid)
	if old_slot != "":
		equipped[old_slot] = equipped[slot] if old_slot != slot else -1
	equipped[slot] = uid
	if slot == "torso":
		drop_unmounted()
	sync_swaps()
	var sj := swap_job("m", slot)
	if not sj.is_empty():
		return tr("%s goes on the %s: about %s to bolt it on (Bay > Job board).") % [d["name"], tr(SLOT_NAMES[slot]), hours_text(float(sj["total"]))]
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
	if missing <= 0.0 or not repair_job(int(p["uid"])).is_empty():
		return 0
	var discount := 0.6 if style == "mechanic" else 1.0   # mechanics fix things cheaper
	if is_wreck(p):
		return maxi(20, int(d["cost"] * WRECK_SHARE * discount))   # rebuilding a wreck
	return maxi(1, ceili(missing * maxf(30.0, d["cost"] * REPAIR_SHARE) * discount))


## Fixing a part is paid up front and goes on Gus's job board: the bay works on it as time passes.
func repair(uid: int) -> String:
	var p := inst(uid)
	var c := repair_cost(p)
	if c == 0:
		return "Already in perfect shape." if repair_job(uid).is_empty() else "It's already on the bench."
	if not can_repair(c):
		return "Not enough cash. No repairs on credit. Fight with the dents and win some money."
	book("repairs", -(c))
	var h := queue_repair(p, c)
	return tr("%s is on the bench: $%d, about %s of work.") % [part_def(p["id"])["name"], c, hours_text(h)]


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
		return "Your robot is in perfect shape." if not has_work("m") else "Everything's already on the job board."
	if not can_repair(c):
		return tr("Repairing everything costs $%d. You don't have the cash. Fix the worst parts one at a time, or fight with the dents.") % c
	var h := 0.0
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty() and repair_cost(p) > 0:
			h += queue_repair(p, repair_cost(p))
	book("repairs", -(c))
	return tr("Everything's on the job board: $%d, about %s of work.") % [c, hours_text(h)]


# ---------------------------------------------------------------- time in the bay
# Every repair and every part you bolt on takes hours of work. The bay works 4 hours in the
# morning and 4 in the afternoon (overtime: 8 more at night). Gus is one pair of hands; each
# mechanic you hire works one more job at the same time. Fights are in the evening: whatever
# isn't finished by the bell goes in as it is.

const PHASE_NAMES := ["MORNING", "AFTERNOON", "EVENING"]
const SHIFT_HOURS := 4.0           # morning shift, afternoon shift
const NIGHT_HOURS := 8.0           # overtime
const REPAIR_HOURS := {"head": 6.0, "arm": 6.0, "leg": 6.0, "torso": 12.0, "reactor": 3.0, "back": 3.0}   # 0 to full (1.53: x2)
const SWAP_HOURS := {"head": 1.5, "arm": 1.5, "leg": 1.5, "torso": 6.0, "reactor": 3.0, "back": 3.0}   # (1.53: x1.5)
## What a full repair costs, as a share of the part's price (1.53: was 0.2, which made fixing a dug
## part and selling it a money printer: parts sell for 40%). A wreck's rebuild costs WRECK_SHARE.
const REPAIR_SHARE := 0.25
const WRECK_SHARE := 0.6
const SELL_SHARE := 0.25   # what a part sells for, at full health (1.53: was 0.4)
## Passive repair (1.53): Gus tinkers in the quiet hours. Every part on your robots (and on the
## shelf) gets this share of its HP back each day, wrecks excepted. The bay upgrades (Bay > Job board)
## raise it a step at a time; each step puts the rent up.
const PASSIVE_BASE := 0.01
const PASSIVE_STEP := 0.01
const BAY_LEVELS := 4
const BAY_NAMES := ["Gus's bench", "Parts washer", "Welding rig", "Hydraulic hoist", "Diagnostic computer"]
const BAY_RENT := 0.15     # each level adds this share of the running costs every month
const BAY_PRICE := [0.6, 1.0, 1.5, 2.2]   # each level's price, in months of running costs
var bay_level := 0
const GRADE_TIME := 0.25           # each grade up takes a quarter longer
const WRECK_TIME := 1.5            # rebuilding a wreck
const MECHANIC_WAGE := 0.3         # a mechanic's monthly wage: this share of your running costs
const OVERTIME_PRICE := 80         # per pair of hands per night, x3 a grade
var phase := 0                     # 0 morning, 1 afternoon, 2 evening (fights are in the evening)
var places_been: Array = ["home"]   # (1.83) places you've been to (quick buttons over the map)
var pilot_at := "home"             # (1.77) where your pilot is in Port Ferrum (the City map)
var pilot_used := 0.0              # (1.77) hours of this part of the day your pilot has spent going places
var jobs: Array = []               # the job board, in order: {kind: "repair"/"swap", uid, robot, slot, total, done, rush, start}
var bolted := {}                   # robot ("m", "w0", "w1") -> {slot: uid} fully bolted on
var mechanics := 0
var overtime := false              # work through tonight


func hands() -> int:
	return 1 + mechanics


func max_mechanics() -> int:
	return 2 + gantries   # the bay only fits so many people


func mechanic_wage() -> int:
	return int(int(settings.get("living_cost", LIVING_COST)) * float(RUNNING.get(rank, 1.0)) * MECHANIC_WAGE / 10.0) * 10


func hire_mechanic() -> String:
	if mechanics >= max_mechanics():
		return "No room for another mechanic. More gantries make a bigger bay."
	mechanics += 1
	return tr("A new mechanic picks up a wrench. $%d a month on the running costs.") % mechanic_wage()


func fire_mechanic() -> String:
	if mechanics <= 0:
		return ""
	mechanics -= 1
	return "You let a mechanic go. Fewer hands, smaller bills."


func overtime_cost() -> int:
	return int(OVERTIME_PRICE * hands() * pow(GRADE_PRICE, my_grade() - 1))


## Hours of bay work to fix a part from where it is now to full (what queue_repair will book).
func repair_hours(p: Dictionary) -> float:
	var d := part_def(p["id"])
	return (1.0 - hp_ratio(p)) * float(REPAIR_HOURS.get(d["kind"], 3.0)) * time_factor(d) * (WRECK_TIME if is_wreck(p) else 1.0)


## Hours of bay work to bolt a part on.
func swap_hours(d: Dictionary) -> float:
	return float(SWAP_HOURS.get(d["kind"], 1.0)) * time_factor(d)


## Hours of work Repair all would book.
func repair_all_hours() -> float:
	var h := 0.0
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty() and repair_cost(p) > 0:
			h += repair_hours(p)
	return h


func time_factor(d: Dictionary) -> float:
	return 1.0 + GRADE_TIME * maxi(0, int(d.get("grade", 1)) - 1)


func hours_text(h: float) -> String:
	if h < 1.0:
		return tr("%d min") % maxi(10, int(round(h * 6.0)) * 10)
	return tr("%.1f h") % h if h < 10.0 else tr("%d h") % int(round(h))


func repair_job(uid: int) -> Dictionary:
	for j in jobs:
		if j["kind"] == "repair" and int(j["uid"]) == uid:
			return j
	return {}


func swap_job(robot: String, slot: String) -> Dictionary:
	for j in jobs:
		if j["kind"] == "swap" and j["robot"] == robot and j["slot"] == slot:
			return j
	return {}


func has_work(robot: String) -> bool:
	sync_swaps()
	for j in jobs:
		if j["kind"] == "swap" and j["robot"] == robot:
			return true
		if j["kind"] == "repair" and robot_uids(robot).has(int(j["uid"])):
			return true
	return false


func robot_eq(robot: String) -> Dictionary:
	if robot == "m":
		return equipped
	var k := int(robot.substr(1))
	return wingmen[k] if k < wingmen.size() else {}


func robot_uids(robot: String) -> Array:
	var out: Array = []
	var eq := robot_eq(robot)
	for slot in eq:
		if int(eq[slot]) >= 0:
			out.append(int(eq[slot]))
	return out


## Put a repair on the board (or top it up). Returns the hours it adds.
func queue_repair(p: Dictionary, paid: int = 0) -> float:
	var d := part_def(p["id"])
	var mx := float(d["hp"])
	var missing := 1.0 - hp_ratio(p)
	if missing <= 0.0:
		return 0.0
	var h: float = missing * float(REPAIR_HOURS.get(d["kind"], 3.0)) * time_factor(d) * (WRECK_TIME if is_wreck(p) else 1.0)
	jobs.append({"kind": "repair", "uid": int(p["uid"]), "robot": "", "slot": "", "total": h, "done": 0.0, "rush": false,
			"start": float(p["hp"]), "to": mx, "paid": paid})
	return h


## What's given back for a repair job that's called off: the share of the price not worked yet.
func job_refund(j: Dictionary) -> int:
	if j["kind"] != "repair":
		return 0
	return int(float(j.get("paid", 0)) * clampf(1.0 - float(j["done"]) / maxf(0.01, float(j["total"])), 0.0, 1.0))


## Call off a repair job: the money for the hours not worked comes back; the HP already done stays.
func cancel_job(i: int) -> String:
	if i < 0 or i >= jobs.size() or jobs[i]["kind"] != "repair":
		return ""
	var j: Dictionary = jobs[i]
	var back := job_refund(j)
	book("repairs", back)
	jobs.remove_at(i)
	var p := inst(int(j["uid"]))
	return tr("Called off: %s. $%d back for the hours not worked.") % [part_def(p["id"])["name"] if not p.is_empty() else "?", back]


## Anything fitted that isn't bolted on yet gets a swap job; jobs for parts that came off are dropped.
## (Taking a part off is quick: only bolting one on takes time.)
func sync_swaps() -> void:
	var robots := ["m"]
	for k in wingmen.size():
		robots.append("w%d" % k)
	for r in robots:
		if not bolted.has(r):
			bolted[r] = {}
		var eq := robot_eq(r)
		var bt: Dictionary = bolted[r]
		for slot in SLOTS:
			var uid := int(eq.get(slot, -1))
			if uid < 0 or inst(uid).is_empty():
				bt.erase(slot)
				_drop_swap(r, slot)
				continue
			if int(bt.get(slot, -1)) == uid:
				_drop_swap(r, slot)
				continue
			var j := swap_job(r, slot)
			if not j.is_empty() and int(j["uid"]) == uid:
				continue
			_drop_swap(r, slot)
			bt.erase(slot)
			var d := part_def(inst(uid)["id"])
			jobs.append({"kind": "swap", "uid": uid, "robot": r, "slot": slot, "total": float(SWAP_HOURS.get(d["kind"], 1.0)) * time_factor(d),
					"done": 0.0, "rush": false, "start": 0.0, "to": 0.0})
	# repairs of parts that were sold or lost
	jobs = jobs.filter(func(j): return j["kind"] != "repair" or not inst(int(j["uid"])).is_empty())


func _drop_swap(r: String, slot: String) -> void:
	jobs = jobs.filter(func(j): return not (j["kind"] == "swap" and j["robot"] == r and j["slot"] == slot))


## Everything as it stands is bolted on and fixed (new games, old saves).
func bolt_everything() -> void:
	bolted = {}
	jobs = []
	sync_swaps()
	for j in jobs:
		bolted[j["robot"]][j["slot"]] = int(j["uid"])
	jobs = []


## How far a part being bolted on is (1.0 = done, or no job).
func fit_progress(robot: String, slot: String) -> float:
	var j := swap_job(robot, slot)
	if j.is_empty():
		return 1.0
	return clampf(float(j["done"]) / maxf(0.01, float(j["total"])), 0.0, 1.0)


## Work `hours` on the board: the top unfinished jobs get a pair of hands each (one hand per job,
## so more mechanics means more jobs at once, not a faster single job).
## With apply = false nothing changes and the result is each job's progress afterwards.
func work(hours: float, apply: bool = true, board: Array = []) -> Array:
	sync_swaps()
	var list: Array = board if not board.is_empty() else (jobs if apply else jobs.duplicate(true))
	# in quarter hours: the top jobs on the board get a pair of hands each (rush jobs go twice as fast)
	var steps := int(round(hours / 0.25))
	for st in steps:
		var n := 0
		for j in list:
			if n >= hands():
				break
			if float(j["done"]) >= float(j["total"]) - 0.001:
				continue
			j["done"] = minf(float(j["total"]), float(j["done"]) + 0.25 * (2.0 if j["rush"] else 1.0))
			n += 1
	if apply:
		_apply_jobs()
	return list


func _apply_jobs() -> void:
	var keep: Array = []
	for j in jobs:
		var done := float(j["done"]) >= float(j["total"]) - 0.001
		if j["kind"] == "repair":
			var p := inst(int(j["uid"]))
			if p.is_empty():
				continue
			# the HP paid for arrives as the hours go by (dents taken in the meantime stay)
			var per_h := (float(j["to"]) - float(j["start"])) / maxf(0.01, float(j["total"]))
			var add := (float(j["done"]) - float(j.get("applied", 0.0))) * per_h
			j["applied"] = float(j["done"])
			p["hp"] = minf(float(part_def(p["id"])["hp"]), float(p["hp"]) + add)
		elif done:
			if not bolted.has(j["robot"]):
				bolted[j["robot"]] = {}
			bolted[j["robot"]][j["slot"]] = int(j["uid"])
		if not done:
			keep.append(j)
	jobs = keep


## What the board looks like when the bell rings tonight: [{job, progress}] for unfinished work.
## Hours of bay work left before tonight's bell.
func hours_to_bell() -> float:
	return SHIFT_HOURS * float(maxi(0, 2 - phase))


## Jobs still unfinished after `h` more hours of work (default: at the bell), with their progress.
func at_the_bell(h: float = -1.0) -> Array:
	if h < 0.0:
		h = hours_to_bell()
	var list := work(h, false)
	var out: Array = []
	for j in list:
		if float(j["done"]) < float(j["total"]) - 0.001:
			out.append({"job": j, "progress": clampf(float(j["done"]) / maxf(0.01, float(j["total"])), 0.0, 1.0)})
	return out


## A part's health when the bell rings tonight (its repair job worked up to then).
func bell_hp_ratio(p: Dictionary, h: float = -1.0) -> float:
	var j := repair_job(int(p["uid"]))
	if j.is_empty():
		return hp_ratio(p)
	if h < 0.0:
		h = hours_to_bell()
	for x in work(h, false):
		if x["kind"] == "repair" and int(x["uid"]) == int(p["uid"]):
			var per_h := (float(x["to"]) - float(x["start"])) / maxf(0.01, float(x["total"]))
			var hp := minf(float(part_def(p["id"])["hp"]), float(p["hp"]) + (float(x["done"]) - float(x.get("applied", 0.0))) * per_h)
			return clampf(hp / maxf(1.0, float(part_def(p["id"])["hp"])), 0.0, 1.0)
	return 1.0   # finished before the bell


## Move the clock on one step (morning -> afternoon -> evening -> next morning), working the bay.
func advance_phase() -> void:
	pilot_used = 0.0
	if phase < 2:
		work(SHIFT_HOURS)
		phase += 1
		return
	if overtime:
		work(NIGHT_HOURS)
		overtime = false
	next_day()


## After a fight: the night goes by (overtime, if booked, is worked), and it's tomorrow morning.
func end_fight_night() -> void:
	phase = 2
	advance_phase()


## Up to the evening (fights): the day's remaining shifts get worked.
func to_evening() -> void:
	while phase < 2:
		advance_phase()


func buy_overtime() -> String:
	if overtime:
		return "The crew's already staying tonight."
	var c := overtime_cost()
	if money < c:
		return tr("Overtime tonight costs $%d.") % c
	book("repairs", -(c))
	overtime = true
	return tr("The crew works through the night: $%d, 8 more hours on the board.") % c


## Pay to double the speed of one job (repairs: twice the repair price again; bolting on: a fee).
func rush_cost(j: Dictionary) -> int:
	var p := inst(int(j["uid"]))
	if p.is_empty():
		return 0
	var d := part_def(p["id"])
	if j["kind"] == "repair":
		var left := 1.0 - float(j["done"]) / maxf(0.01, float(j["total"]))
		var mx := float(d["hp"])
		var c := maxf(20.0, float(d["cost"]) * (0.5 if is_wreck(p) else 0.2)) * ((float(j["to"]) - float(j["start"])) / maxf(1.0, mx)) * left
		return maxi(10, int(c * 2.0 * (0.6 if style == "mechanic" else 1.0)))
	return maxi(20, int(float(d["cost"]) * 0.1))


func rush_job(idx: int) -> String:
	if idx < 0 or idx >= jobs.size() or jobs[idx]["rush"]:
		return ""
	var c := rush_cost(jobs[idx])
	if money < c:
		return tr("A rush job costs $%d.") % c
	book("repairs", -(c))
	jobs[idx]["rush"] = true
	return tr("Rush job: twice as fast, $%d.") % c


func job_up(idx: int) -> void:
	if idx > 0 and idx < jobs.size():
		var j = jobs[idx]
		jobs[idx] = jobs[idx - 1]
		jobs[idx - 1] = j


## A fight is starting: work up to the bell, then the robot goes in as it is. Parts not even half
## bolted on stay off; parts more than half bolted on are on but loose (half their HP in the fight).
func bench_spec(spec: Dictionary, robot: String) -> Dictionary:
	sync_swaps()
	for slot in spec["parts"]:
		var pr := fit_progress(robot, slot)
		if pr >= 1.0 or (spec["parts"][slot] as Dictionary).is_empty():
			continue
		if pr < 0.5 and not (slot == "torso" or slot.begins_with("head")):
			spec["parts"][slot] = {}   # not on yet: fight without it (a torso or head goes in loose)
		else:
			var pp: Dictionary = spec["parts"][slot]
			var before := float(pp["hp"])
			pp["max_hp"] = float(pp["max_hp"]) * 0.5
			pp["hp"] = minf(before, float(pp["max_hp"]))
			pp["loose"] = true
			pp["loose_cut"] = before - float(pp["hp"])
	return spec


## Damaged parts sell for less; even junk and wrecks are worth something as scrap metal.
func sell_value(p: Dictionary) -> int:
	var h := hp_ratio(p)
	return maxi(int(part_def(p["id"])["cost"] * SELL_SHARE * h), int(10 + 15 * h))


func sell(uid: int) -> String:
	var p := inst(uid)
	if p.is_empty() or slot_of_uid(uid) != "":
		return "Unequip it before selling."
	if wingman_of_uid(uid) != -1:
		return "A wingman is using that part."
	var v := sell_value(p)
	# nothing left on the board for a part that's gone (unworked repair hours are paid back)
	for j in jobs:
		if int(j["uid"]) == uid:
			v += job_refund(j)
	book("sales", v)
	inventory.erase(p)
	jobs = jobs.filter(func(j): return int(j["uid"]) != uid)
	return tr("Sold %s for $%d.") % [part_def(p["id"])["name"], v]


## Power for the fight (the tank): the reactor's output, plus whatever your parts don't use -
## a light robot on a big reactor has power to spare.
static func fight_tank(output: float, used: float) -> float:
	return output + maxf(0.0, output - used)


## cur_hp >= 0: a real part's health is shown as HP now/max.
# ---------------------------------------------------------------- heads: aiming and scanning
## Every head has an Aim time (how long before you can put the crosshair on a part again) and a
## Scan time (how long it takes to find the weakest part). The kind comes from the shape: junk heads
## are slow at both, snipers aim fast, scanners find weak spots fast; the aim stat and the grade
## make any head quicker.
const HEAD_KIND := {"bucket": "plain", "box": "plain", "skull": "plain", "tall": "allround", "dome": "allround",
		"horned": "allround", "knight": "allround", "orb": "allround", "cyclops": "sniper", "visor": "sniper",
		"wedge": "sniper", "laser": "sniper", "dish": "scanner", "tv": "scanner", "bulb": "scanner", "speaker": "scanner"}
const HEAD_TIMES := {"junk": [5.0, 8.0], "plain": [2.5, 4.0], "sniper": [0.6, 5.0], "scanner": [3.0, 1.0], "allround": [1.5, 2.0]}


func head_kind(d: Dictionary) -> String:
	if int(d.get("cost", 0)) <= 0 and not d.get("custom", false):
		return "junk"
	return str(HEAD_KIND.get(str(d.get("shape", "")), "plain"))


## [aim seconds, scan seconds] for a head part.
func head_times(d: Dictionary) -> Array:
	var base: Array = HEAD_TIMES[head_kind(d)]
	var k := (1.0 - clampf(float(d.get("aim", 0)), 0.0, 40.0) / 100.0) * pow(0.9, maxi(0, int(d.get("grade", 1)) - 1))
	return [maxf(0.3, float(base[0]) * k), maxf(0.6, float(base[1]) * k)]


## A computer pilot's aim level, 1 (gutter rookie) to 5 (champion): how fast they aim and scan
## and how cleverly they pick what to aim at. Story rivals are a level sharper.
const AIM_LEVEL_K := [1.6, 1.3, 1.0, 0.8, 0.6]   # x the head's times, levels 1-5


## A pilot's Read in dots (1-5): world pilots from their Read, story and quick-fight robots from "smart".
func pilot_aim_level(o: Dictionary) -> int:
	if o.has("aim_level"):
		return clampi(int(o["aim_level"]), 1, 5)
	var lv := World.read_dots(float(o["read"])) if o.has("read") else clampi(1 + int(float(o.get("smart", 0.3)) * 5.5), 1, 5)
	if o.get("rival", false) or (o.has("wid") and is_rival(int(o["wid"]))):
		lv = mini(5, lv + 1)
	return lv


func aim_dots(lv: int) -> String:
	return "●".repeat(clampi(lv, 1, 5)) + "○".repeat(5 - clampi(lv, 1, 5))


func part_stat_text(d: Dictionary, cur_hp: float = -1.0) -> String:
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
	if cur_hp >= 0.0:
		var lost := 100 - ceili(cur_hp / maxf(1.0, float(d["hp"])) * 100.0)
		bits = [tr("HP %d/%d") % [ceili(cur_hp), d["hp"]] + ((tr(" (-%d%%)") % lost) if lost > 0 else "")]
	if float(d.get("gm", 1.0)) > 1.001:
		bits.append(tr("HIT x%.1f") % float(d["gm"]))   # the grade: every hit with it lands this much harder
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
	if d["kind"] == "head":
		var ht := head_times(d)
		bits.append(tr("AIM IN %.1fs") % ht[0])
		bits.append(tr("SCAN %.1fs") % ht[1])
	if d["kind"] == "head" and d["chips"] > 0:
		bits.append(tr("CHIPS %d") % d["chips"])
	if d["kind"] in ["head", "torso", "arm", "leg"]:
		bits.append(tr(SIZE_NAMES.get(d.get("size_class", "M"), "Medium")))
	if d["kind"] in ["arm", "leg"]:
		bits.append(tr("REACH %d%%") % reach_pct(d))
	if d["kind"] == "torso":
		var mt: Array = d["mounts"]
		bits.append(tr("ARMS %d") % (4 if mt.has("arm_front2") else 2))
		bits.append(tr("HEADS %d") % (2 if mt.has("head2") else 1))
		if mt.has("reactor2"):
			bits.append(tr("REACTORS 2"))
	bits.append(tr("Power %d") % d["draw"])
	return "  ".join(bits) + g + trait_line(d)


## How far an arm or leg reaches, against a standard Rebar Arm / Strut Leg (100%): bigger parts reach further.
func reach_pct(d: Dictionary) -> int:
	var sz := float(d.get("size", 1.0))
	if d["kind"] == "leg":
		var ld: Array = RobotArt.LEGS.get(str(d.get("shape", "rod")), RobotArt.LEGS["rod"])
		return int(round(float(ld[0]) / 60.0 * sz * 100.0))
	return int(round(sz * 100.0))


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


## Every chip that can be bought (signature moves come with a fighting style instead).
static func chip_ids() -> Array:
	return Specials.MOVES.keys().filter(func(x): return not Specials.MOVES[x].has("style"))


func chip_price(id: String, ordered: bool = false) -> int:
	return int(int(Specials.MOVES[id]["cost"]) * (CHIP_ORDER_MARKUP if ordered else 1.0))


## Buy a chip from the dealer's stock, or (ordered = true) have any chip made to order for double.
func buy_chip(id: String, ordered: bool = false) -> String:
	var m: Dictionary = Specials.MOVES[id]
	if owned_chips.has(id):
		return tr("You already own %s.") % tr(m["name"])
	var price := chip_price(id, ordered)
	if money < price:
		return "Not enough money."
	book("parts", -(price))
	chip_stock.erase(id)
	owned_chips.append(id)
	if chips.size() < chip_slots():
		chips.append(id)
		return tr("Downloaded %s into %s. Input: %s") % [tr(m["name"]), robot_name, Specials.seq_text(m["seq"])]
	return tr("Bought %s. Your chip slots are full. Uninstall a chip to make room.") % tr(m["name"])


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
	var arm_gm := 0.0
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
		var off := off_label(d, slot)
		used += d["draw"]
		output += int(float(d["output"]) * (OFF_REACTOR if off == "reactor_arm" else 1.0))
		if off == "reactor_arm":
			continue   # a reactor strapped where an arm should be: power, no arm
		match SLOT_KIND[slot]:
			"arm":
				arms += 1
				arm_dmg += d["damage"] + (int(OFF_LEG_ARM["damage"]) if off == "leg_arm" else 0)
				arm_gm += float(d.get("gm", 1.0))
			"leg":
				legs += 1
				leg_spd += d["speed"] + (int(OFF_ARM_LEG["speed"]) if off == "arm_leg" else 0)
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
	var damage := (100.0 + arm_dmg / maxf(1, arms)) * eff * (arm_gm / arms) if arms > 0 else 0.0
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
	var pods := {}
	for slot in BODY_SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if p.is_empty():
			parts[slot] = {}
		else:
			var d := part_def(p["id"])
			var off := off_label(d, slot)
			if off == "reactor_arm":
				parts[slot] = {}
				pods[slot] = Color(d["color"])   # drawn strapped to the shoulder
				continue
			parts[slot] = {"id": d["id"], "hp": p["hp"], "max_hp": float(d["hp"]), "armor": d["armor"],
					"damage": d["damage"], "speed": d["speed"], "aim": d["aim"], "draw": float(d["draw"]),
					"shape": d["shape"], "size": d["size"], "color": Color(d["color"]),
					"trait": d["trait"], "trait_lv": d["trait_lv"], "gm": float(d.get("gm", 1.0))}
			if off == "leg_arm":
				parts[slot]["damage"] = int(d["damage"]) + int(OFF_LEG_ARM["damage"])
				parts[slot]["speed"] = int(d["speed"]) + int(OFF_LEG_ARM["speed"])
				parts[slot]["swap"] = "leg"
			elif off == "arm_leg":
				parts[slot]["damage"] = int(d["damage"]) + int(OFF_ARM_LEG["damage"])
				parts[slot]["speed"] = int(d["speed"]) + int(OFF_ARM_LEG["speed"])
				parts[slot]["swap"] = "arm"
	var s := stats(eq)
	var gadgets: Array = []
	for slot in SLOTS:
		var p := inst(int(eq.get(slot, -1)))
		if not p.is_empty() and part_def(p["id"])["gimmick"] != "":
			gadgets.append({"id": part_def(p["id"])["gimmick"], "slot": slot})
	var back := inst(int(eq.get("back", -1)))
	var reactor := inst(int(eq.get("reactor", -1)))
	return {"name": robot_name if label == "" else label, "parts": parts, "efficiency": s["efficiency"], "damage_mult": 1.0,
			"power": fight_tank(float(s["power_output"]), float(s["power_used"])),
			"speed_mult": 1.0, "scale": 1.0, "trim": Color(PAINTS[paint]["color"]),
			"eye": Color(part_def(reactor["id"])["color"]) if not reactor.is_empty() else Color(0.4, 0.9, 1.0),
			"back": {} if back.is_empty() else {"shape": part_def(back["id"])["shape"], "color": Color(part_def(back["id"])["color"])},
			"gadgets": gadgets, "specials": active_chips() if eq == equipped else [], "style": style,
			"controller": str(pilot_look.get("controller", "gamepad")),
			"stickers": Contracts.stickers() if eq == equipped else {},
			"pods": pods,
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
	if not test_drive.is_empty():
		return "test"
	if not quick.is_empty():
		return "quick"
	if not watching.is_empty():
		return "watch"
	if day == "wed" and cup_round_this_week():
		return "circuit"
	if not event.is_empty() and day_index() == Career.fight_day(event) and event.get("phase", "") != "done" and Career.player_opponent(event) != -1 \
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


## apply_scout = false: the robot as your scout saw it (before they swapped a part on you).
func current_opponent(apply_scout: bool = true) -> Dictionary:
	if fight_mode() == "test":
		return junker(str(test_drive["junker"]))
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
			if pickup.get("tag", false):
				o = tag_opponent()
			elif pickup.has("wid") and not World.pilot(int(pickup["wid"])).is_empty():
				o = World.robot(int(pickup["wid"]))
			else:
				o = (pickup["enemy"] as Dictionary).duplicate(true)
		"exhibition":
			o = rival(OPPONENTS.size() - 1)
			o["pilot"] = ""
		_:
			return {}
	o["reward"] = current_reward_for(o)
	# if they caught our scout, they changed something
	if apply_scout and scouted() and scout.get("spied_back", false):
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
	book("scout", -(cost))
	var o := current_opponent()
	scout = {"key": scout_key(), "spied_back": false, "change": {}}
	if randf() < 0.3:
		# spotted! They'll swap one part before the bell, so the report will be wrong about it
		var slots: Array = []
		for slot in ["arm_front", "arm_back", "leg_front", "leg_back", "head", "torso"]:
			if o["parts"].get(slot, "") != "":
				slots.append(slot)
		var slot: String = slots[randi() % slots.size()]
		var old := part_def(o["parts"][slot])
		var opts: Array = []
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["kind"] == old["kind"] and id != old["id"] and int(d.get("grade", 0)) == maxi(1, int(old.get("grade", 0))) and d.get("mounts", []).is_empty():
				opts.append(id)
		if opts.is_empty():
			for id in ALL_PARTS:
				if PARTS[id]["kind"] == old["kind"] and id != old["id"] and PARTS[id].get("mounts", []).is_empty():
					opts.append(id)
		if not opts.is_empty():
			scout["spied_back"] = true
			scout["change"] = {"type": "part", "slot": slot, "id": opts[randi() % opts.size()]}
			return "Their crew spotted your scout! They'll swap something before the bell. One thing in this report won't be what shows up."
	return "Clean scouting run. They never saw you."



## What a defeat pays: in the scrapyard you pay the winner, in the Regional and cups you get nothing,
## in the Championship (and exhibitions) you still get a small purse.
## What a pickup against the pilot at the bar pays, by their division (stars pay more, and hit harder).
const PICKUP_PURSE := {"open": 150, "scrap": 250, "rust": 750, "iron": 2200, "steel": 6500}


## The crowd at the Rusty Bolt gets bored of the same face (1.53): the first two pickups of a week pay
## the full purse, then each one pays less.
const PICKUP_FATIGUE := [1.0, 1.0, 0.8, 0.6, 0.45, 0.35]


func pickups_this_week() -> int:
	var n := 0
	for e in fight_log:
		if int(e["y"]) == year and int(e["w"]) == week and str(e.get("mode", "")) == "pickup":
			n += 1
	return n


## A pickup's purse against a pilot from `tier`, this week.
func pickup_purse(tier: String) -> int:
	var k: float = PICKUP_FATIGUE[mini(pickups_this_week(), PICKUP_FATIGUE.size() - 1)]
	return int(float(PICKUP_PURSE.get(tier, 120)) * k / 10.0) * 10


const SHOW_MONEY := {"scrap": 0.15, "rust": 0.2, "iron": 0.25, "steel": 0.3, "title": 0.3}


func loss_pay(base: int) -> int:
	match fight_mode():
		"pickup":
			return -int(base * 0.5)
		"story":
			# (1.82) league losers get show money (a loser paying out in a league kept broke pilots broke)
			return int(base * float(SHOW_MONEY.get(str(event.get("stage", "")), 0.0)))
		"exhibition":
			return int(base * 0.25)
	return 0


func current_reward() -> int:
	var o := current_opponent()
	return 0 if o.is_empty() else int(o["reward"])


## Prize money for the fight against o (league rounds pay a bit more as the season goes on, playoffs more).
func current_reward_for(o: Dictionary) -> int:
	match fight_mode():
		"quick", "test":
			return 0
		"exhibition":
			return EXHIBITION_REWARD
		"pickup":
			if pickup.has("tier"):
				return pickup_purse(str(pickup["tier"]))
			return pickup_purse(rank)
		"circuit":
			return int(CUP_PURSE[clampi(int(circuit["tier"]) - 1, 0, CUP_PURSE.size() - 1)] * (1.0 + 0.25 * int(circuit["round"])))
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
		"test":
			return tr("TEST DRIVE")
		"quick":
			return tr("QUICK FIGHT")
		"watch":
			var wev := watch_event()
			return tr("%s VS %s") % [str(watch_robot(0)["pilot"]), str(watch_robot(1)["pilot"])] + " · " + (tr(str(wev["name"])).to_upper() if wev["stage"] == "cup" else tr(Career.STAGES[wev["stage"]]["short"]))
		"circuit":
			return tr("%s · %s") % [str(circuit["name"]).to_upper(), tr(Career.round_name(circuit))]
		"exhibition":
			return tr("EXHIBITION")
		"pickup":
			return tr("TAG TEAM PICKUP") if pickup.get("tag", false) else tr("PICKUP FIGHT")
		"story":
			return tr("%s · %s") % [tr(Career.STAGES[event["stage"]]["short"]), tr(Career.round_name(event)).to_upper()]
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
			if watching["on"] != "cup":
				var wev := watch_event()
				return Arena.career_venue(wev["stage"], Career.round_name(wev))
			rng.seed = int(circuit["seed"]) + int(circuit["round"]) * 7
		"pickup", "test":
			return ["scrap_ring", "scrappers"]
		"exhibition":
			return ["champ_gala", "high_society"]
		"circuit":
			rng.seed = int(circuit["seed"]) + int(circuit["round"]) * 7
		_:
			rng.randomize()
	return [Arena.ARENAS.keys()[rng.randi() % Arena.ARENAS.size()], Arena.CROWDS.keys()[rng.randi() % Arena.CROWDS.size()]]


## Who's drinking at The Rusty Bolt today: a real pilot from the rankings. Usually someone
## from your own division, sometimes a nobody from below, now and then a big name from the top.
## They're today's pickup fight. (Not someone with a league fight of their own tonight.)
func patron_today() -> Dictionary:
	var all := patrons_today()
	return all[0] if not all.is_empty() else {}


## Everyone in The Rusty Bolt today: 2 to 5 real pilots from the rankings. Mostly your own
## division, some from below, now and then a star from the top; someone who hates you likes
## to turn up too. Nobody with a league fight of their own tonight. The first is at the bar.
## The bar fills up as the day goes (1.52): in the morning one or two of last night's crowd are
## still there, sleeping it off ("hungover"); in the afternoon one or two early drinkers (the first
## of tonight's crowd); in the evening the whole night crowd, 3 to 6 of them.
func patrons_today() -> Array:
	if phase >= 2:
		return night_patrons(year, week, day_index())
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 100000 + week * 10 + day_index() + 7 + phase * 31
	var n := rng.randi_range(1, 2)
	if phase == 1:
		return night_patrons(year, week, day_index()).slice(0, n)
	# morning: yesterday's crowd, the ones who never made it home
	var yw := week
	var yd := day_index() - 1
	if yd < 0:
		yd = 6
		yw -= 1
	var out: Array = []
	for p in night_patrons(year, yw, yd):
		if out.size() >= n:
			break
		if World.look_of(int(p["wid"])).get("female", false):
			continue   # (1.79) the ones sleeping it off on the floor are the men
		var q: Dictionary = p.duplicate()
		q["hungover"] = true
		out.append(q)
	return out


## Everyone at the bar on the night of (y, w, di).
func night_patrons(y: int, w: int, di: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = y * 100000 + w * 10 + di + 99
	var count := rng.randi_range(3, 6)
	var tonight := {}
	for x in league_night():
		for e in x[1]["pilots"]:
			if e.has("wid"):
				tonight[int(e["wid"])] = true
	var out: Array = []
	var taken := {}
	var ri := maxi(0, rank_index())
	# someone who can't stand you, now and then, or a friend (one roll each a night, not one per
	# pilot, so the same sore loser isn't propping up the bar every night)
	for want in ["rival", "friend"]:
		var who: Array = []
		for key in rel:
			if str(key).begins_with("_"):
				continue
			var wid := int(key)
			var p := World.pilot(wid)
			var r := rel_of(wid)
			var ok := r <= REL_RIVAL if want == "rival" else r >= 15.0
			if ok and not p.is_empty() and not p["retired"] and not tonight.has(wid) and not taken.has(wid):
				who.append(p)
		who.sort_custom(func(a, b): return int(a["wid"]) < int(b["wid"]))
		if not who.is_empty() and rng.randf() < (0.2 if want == "rival" else 0.3):
			var h: Dictionary = who[rng.randi() % who.size()]
			out.append(h)
			taken[int(h["wid"])] = true
	var guard := 0
	while out.size() < count and guard < 40:
		guard += 1
		var r := rng.randf()
		var ti := ri
		if r < 0.12:
			ti = Career.ORDER.size() - 1
		elif r < 0.32:
			ti = mini(ri + 1, Career.ORDER.size() - 1)
		elif r > 0.78:
			ti = maxi(ri - 1, 0)
		var pool: Array = World.active(Career.ORDER[ti]).filter(func(p): return not tonight.has(int(p["wid"])) and not taken.has(int(p["wid"])))
		if pool.is_empty():
			continue
		pool.sort_custom(func(a, b): return int(a["wid"]) < int(b["wid"]))
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		out.append(pick)
		taken[int(pick["wid"])] = true
	return out


## "4th in the Titanium Championship", "a spare at the qualifiers"
func pilot_standing(wid: int) -> String:
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		for e in ev.get("pilots", []):
			if int(e.get("wid", -1)) == wid:
				var pos: int = Career.standings(ev).find(int(e["id"])) + 1
				return tr("%s in the %s") % [ordinal(pos), tr(str(ev["name"]))]
	var p := World.pilot(wid)
	return tr("hanging around the %s") % tr(str(Career.STAGES.get(str(p.get("tier", "open")), {}).get("name", "")))


## (1.87) "#12 in the Rust League" (shown where Read used to be), "Unranked, in the gutter".
func pilot_rank(wid: int) -> String:
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		if str(ev.get("stage", stage)) in ["open", "title"] or not ev.has("table"):
			continue
		for e in ev.get("pilots", []):
			if int(e.get("wid", -1)) == wid:
				var pos: int = Career.standings(ev).find(int(e["id"])) + 1
				return tr("#%d in the %s") % [pos, tr(str(ev["name"]))]
	var p := World.pilot(wid)
	var tier := str(p.get("tier", "open"))
	if tier == "open" or p.is_empty():
		return tr("Unranked, in the gutter")
	return tr("In the %s") % tr(str(Career.STAGES.get(tier, {}).get("name", "")))


## Your own place, the same way.
func my_rank() -> String:
	var ev: Dictionary = leagues.get(rank, {}) if rank != "open" else {}
	if not ev.is_empty() and ev.has("table"):
		var pos := Career.standings(ev).find(0)
		if pos >= 0:
			return tr("#%d in the %s") % [pos + 1, tr(str(ev["name"]))]
	return tr("Unranked, in the gutter") if rank == "open" else tr("In the %s") % tr(str(Career.STAGES.get(rank, {}).get("name", "")))


func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, tr(suffix)]


## A line said by a world pilot (shown on a video call, or as a bubble if they're in the scene).
func pilot_line(wid: int, text: String) -> Array:
	var p := World.pilot(wid)
	return [str(p.get("name", "?")), text, {"look": World.look_of(wid), "wid": wid}]


## What's between you and a world pilot: -100 (your nemesis) .. 0 (strangers) .. +100 (best friends).
func rel_of(wid: int) -> float:
	return float(rel.get(str(wid), 0.0))


## Move it. Likes, reposts and replies pass cap = REL_SOCIAL_CAP (they never push it past that on
## their own); fights and teaming up pass 100. A nemesis stays at -40 or worse until you beat them.
func rel_add(wid: int, amount: float, cap: float = 100.0) -> void:
	if wid < 0 or World.pilot(wid).is_empty():
		return
	var v0 := rel_of(wid)
	var v := v0
	if amount > 0.0:
		v = maxf(v, minf(v + amount, cap))
	else:
		v += amount
	v = clampf(v, -100.0, 100.0)
	if nemeses.has(wid):
		v = minf(v, -40.0)
	rel[str(wid)] = v
	var name := str(World.pilot(wid)["name"])
	if v <= REL_NEMESIS and not nemeses.has(wid):
		nemeses.append(wid)
		pending_talk.append({"lines": [["GUS", tr(Talk.pick(Talk.GUS_NEMESIS, name)) % name, {}]]})
	elif v0 < REL_FRIEND and v >= REL_FRIEND:
		pending_talk.append({"lines": [pilot_line(wid, tr(Talk.pick(Talk.FRIEND_BORN, name)) % pilot_name)]})


## "(+52)" green / "(-61)" red as BBCode (with_word: "(+52) FRIEND"), or "" while you're strangers.
func rel_bb(wid: int, with_word: bool = false) -> String:
	var v := roundi(rel_of(wid))
	if absi(v) < 5:
		return ""
	var w := rel_word(wid)
	return "[color=#%s]%s[/color]" % [rel_color(wid).to_html(false), rel_text(wid) + (" " + tr(w) if with_word and w != "" else "")]


## "(+52)", "(-61)" or "" (plain text).
func rel_text(wid: int) -> String:
	var v := roundi(rel_of(wid))
	if absi(v) < 5:
		return ""
	return "(%s%d)" % ["+" if v > 0 else "", v]


func rel_color(wid: int) -> Color:
	return Color(0.45, 0.95, 0.5) if rel_of(wid) > 0.0 else Color(1.0, 0.42, 0.3)


## The word for it: NEMESIS, RIVAL, COLD, COLLEAGUE, FRIEND, BEST FRIEND, or "".
func rel_word(wid: int) -> String:
	var v := rel_of(wid)
	if v <= REL_NEMESIS or nemeses.has(wid):
		return "NEMESIS"
	if v <= REL_RIVAL:
		return "RIVAL"
	if v <= -15.0:
		return "COLD"
	if v >= REL_BEST:
		return "BEST FRIEND"
	if v >= REL_FRIEND:
		return "FRIEND"
	if v >= 15.0:
		return "COLLEAGUE"
	return ""


## Rivals: they taunt you, hunt the rematch and their aim is a level sharper against you.
func is_rival(wid: int) -> bool:
	return rel_of(wid) <= REL_RIVAL


func hates_me(wid: int) -> bool:
	return rel_of(wid) <= REL_RIVAL


func is_friend(wid: int) -> bool:
	return rel_of(wid) >= REL_FRIEND


## The milestones (1.67): three on each side. Once reached, a relationship settles there instead
## of fading back to 0 (COLLEAGUE +15, FRIEND +40, BEST FRIEND +80; COLD -15, RIVAL -40, NEMESIS -80).
## Where a value settles: the milestone between it and 0 (0 if it hasn't reached one).
func rel_floor(v: float) -> float:
	if v > 0.0:
		for m in [80.0, 40.0, 15.0]:
			if v >= m:
				return m
	elif v < 0.0:
		for m in [-80.0, -40.0, -15.0]:
			if v <= m:
				return m
	return 0.0


## Every week what sits between milestones fades toward the milestone below it (toward 0 only
## before the first one). A nemesis stays at -40 or worse.
func rel_drift(k: float) -> void:
	for key in rel.keys():
		if str(key).begins_with("_"):
			continue
		var v := float(rel[key])
		var fl := rel_floor(v)
		v = fl + (v - fl) * k
		if nemeses.has(int(key)):
			v = minf(v, -40.0)
		if absf(v) < 1.0:
			rel.erase(key)
		else:
			rel[key] = v


## How much tonight's fight matters to one side (1 = an ordinary night). League: fighting to stay
## up (bottom 8), for promotion or the title (top 8), and it all counts more late in the year.
## Cups: semis and finals. Pickups: not much, unless a star loses to a nobody (pride).
func fight_stakes(ev: Dictionary, id: int, mode: String, wid: int = -1) -> float:
	match mode:
		"story":
			if ev.is_empty():
				return 1.0
			if ev.get("phase", "") == "finals":
				return 3.0 + float(ev.get("po_round", 0))   # a playoff: a whole year on one night
			var order := Career.standings(ev)
			var pos := order.find(id)
			var n := order.size()
			var s := 1.0
			if pos >= n - 13:
				s += 1.5
			if pos >= 0 and pos < 13:
				s += 1.0
			return s * (1.0 + maxf(0.0, float(ev["round"]) - 12.0) / 12.0)
		"circuit":
			return {"FINAL": 3.0, "SEMIFINAL": 2.0}.get(Career.round_name(ev), 1.2)
		"pickup":
			if wid >= 0 and Career.ORDER.find(str(World.pilot(wid).get("tier", ""))) > rank_index():
				return 1.4   # a star beaten by somebody from a lower league
			return 0.6
	return 0.8


## Stories nobody wrote. Every fight pushes what's between you and them down (1.58: one number,
## -100 nemesis .. +100 best friend), harder when the fight mattered more, and harder again if it's
## the same person beating the other over and over. Friends take it half as hard. Crossing the
## rival line sets off talk: gloats, rivalries, revenge, "I'll get you next time".
func emergent_talk(o: Dictionary, won: bool) -> void:
	streak = (maxi(streak, 0) + 1) if won else (mini(streak, 0) - 1)
	var lines: Array = []
	var wid := int(o.get("wid", -1))
	var mode := fight_mode()
	var seed_text := "%d:%d:%s:%d" % [year, week, day, wid]
	var roll := float(absi(hash(seed_text + "r")) % 1000) / 1000.0
	if wid >= 0 and not World.pilot(wid).is_empty():
		var key := str(wid)
		var rec: Array = h2h.get(key, [0, 0])
		rec = [int(rec[0]) + (1 if won else 0), int(rec[1]) + (0 if won else 1)]
		h2h[key] = rec
		var ev: Dictionary = event if mode == "story" else (circuit if mode == "circuit" else {})
		var their_id := Career.player_opponent(ev) if not ev.is_empty() else -1
		var r0 := rel_of(wid)
		var settled := false
		if won and nemeses.has(wid):
			# you beat your nemesis: the score's settled, back to plain rivals
			nemeses.erase(wid)
			rel[key] = maxf(r0, -60.0)
			settled = true
		else:
			var stakes := fight_stakes(ev, their_id, mode, wid) if won else fight_stakes(ev, 0, mode)
			var again := 1.0 + 0.5 * mini(4, maxi(0, int(rec[0 if won else 1]) - 1))
			var hit := REL_FIGHT_K * stakes * again * (1.0 if won else 0.8)
			if r0 > 0.0:
				hit *= 0.5   # friends take it better
			rel_add(wid, -hit)
		var r1 := rel_of(wid)
		var name := str(World.pilot(wid)["name"])
		var me := pilot_name
		if settled:
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.REVENGE, seed_text)) % me))
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_NEMESIS_DOWN, seed_text)) % name, {}])
		elif r0 >= 15.0:
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.FRIEND_FIGHT_LOST if won else Talk.FRIEND_FIGHT_WON, seed_text)) % me))
		elif not won and losses == 1:
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.GLOAT, seed_text)) % me))
		elif not won and r0 > REL_RIVAL and r1 <= REL_RIVAL:
			if not rivals.has(wid):
				rivals.append(wid)
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.RIVAL_BORN, seed_text)) % me))
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_RIVAL, seed_text)) % name, {}])
		elif won and r0 > REL_RIVAL and r1 <= REL_RIVAL:
			if not rivals.has(wid):
				rivals.append(wid)
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.THEY_HATE, seed_text)) % me))
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_THEY_HATE, seed_text)) % name, {}])
		elif won and r0 <= REL_RIVAL and int(rec[1]) > 0 and roll < 0.5:
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.REVENGE, seed_text)) % me))
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_REVENGE, seed_text)) % name, {}])
		elif won and r0 <= REL_RIVAL and roll < minf(0.9, -r1 / 60.0):
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.NEXT_TIME, seed_text)) % me))
		elif not won and r0 <= REL_RIVAL and roll < 0.5:
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.RIVAL_AGAIN, seed_text)) % me))
		elif won and Career.ORDER.find(str(World.pilot(wid).get("tier", ""))) > rank_index():
			lines.append(["GUS", tr(Talk.pick(Talk.GIANT_KILL, seed_text)) % [name, tr(Career.STAGES[World.pilot(wid)["tier"]]["name"])], {}])
		elif not won and roll < minf(0.35, -r1 / 100.0):
			lines.append(pilot_line(wid, tr(Talk.pick(Talk.GLOAT, seed_text)) % me))   # a gloat, now and then
	if lines.is_empty():
		if streak == -3:
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_LOSING, seed_text)), {}])
		elif streak == 5:
			lines.append(["GUS", tr(Talk.pick(Talk.GUS_WINNING, seed_text)), {}])
	if not lines.is_empty():
		pending_stories.append({"lines": lines})


## A new day: someone who hates you might get in touch (more likely the more they hate you).
func daily_hate_mail() -> void:
	var best := -1
	var best_r := 0.0
	for key in rel:
		if str(key).begins_with("_"):
			continue
		var r := rel_of(int(key))
		if r <= REL_RIVAL * 0.8 and r < best_r and not World.pilot(int(key)).get("retired", true):
			best = int(key)
			best_r = r
	if best < 0 or Social.is_blocked("w:%d" % best):
		return
	var roll := float(absi(hash("%d:%d:%s:mail" % [year, week, day])) % 1000) / 1000.0
	# at most one letter every three weeks, and even then only now and then
	if week + year * 100 - int(rel.get("_mail", -99)) < 3:
		return
	if roll < minf(0.06, -best_r / 800.0):
		rel["_mail"] = week + year * 100
		var t := tr(Talk.pick(Talk.HATE_MAIL, "%d:%d:%s" % [year, week, day]))
		var last_w := week
		for e in fight_log:
			if str(e.get("opp", "")) == str(World.robot(best).get("name", "")) and bool(e["won"]):
				last_w = int(e["w"])
		t = t.replace("%d", str(last_w)).replace("%s", pilot_name)
		pending_talk.append({"lines": [pilot_line(best, t)]})


## Your rival calls before your fight with them (a short taunt), or [] if they aren't one.
func rival_taunt() -> Array:
	var o := current_opponent()
	var wid := int(o.get("wid", -1))
	if wid < 0 or not is_rival(wid) or Social.is_blocked("w:%d" % wid):
		return []
	return [pilot_line(wid, tr(Talk.pick(Talk.TAUNT, "%d:%d:%d" % [year, week, wid])) % pilot_name)]


## The pilot at the bar says hello (once a day): what they say depends on who they are to you.
func pub_greeting() -> Array:
	var stamp := "%d:%d:%s:%d" % [year, week, day, phase]   # the crowd changes through the day
	if pub_seen == stamp:
		return []
	var all := patrons_today()
	if all.is_empty():
		return []
	pub_seen = stamp
	var pat: Dictionary = all[0]
	for p in all:
		if is_rival(int(p["wid"])) or rel_of(int(p["wid"])) >= 15.0:
			pat = p
	var wid := int(pat["wid"])
	var list: Array = Talk.PUB_PEER
	var ti := Career.ORDER.find(str(pat["tier"]))
	if pat.get("hungover", false):
		list = Talk.PUB_HUNGOVER
	elif is_rival(wid):
		list = Talk.PUB_RIVAL
	elif rel_of(wid) >= 15.0:
		list = Talk.PUB_FRIEND
	elif ti > rank_index():
		list = Talk.PUB_STAR
	elif ti < rank_index():
		list = Talk.PUB_ROOKIE
	return [pilot_line(wid, tr(Talk.pick(list, stamp)) % pilot_name)]


## The very first fight of a new game: a coached pickup against Old Pike, the gutter's softest
## touch (junk robot, slow hands). Monday evening at the Rusty Bolt.
func start_first_fight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bot := random_bot(rng, 0.0, 0.0)
	for slot in bot["parts"].keys():
		bot["parts"][slot] = {"head": "junk_head_box", "torso": "junk_torso_crate", "arm_front": "junk_arm", "arm_back": "junk_arm",
				"leg_front": "junk_leg_thick", "leg_back": "junk_leg_thick", "reactor": "junk_reactor"}.get(slot, bot["parts"][slot])
	bot.erase("back")
	bot["parts"].erase("back")
	bot.merge({"name": "FENCEPOST", "pilot": "OLD PIKE", "hp": 0.75, "damage": 0.7, "speed": 0.85, "think": 0.9, "block": 0.05, "smart": 0.0,
			"specials": [], "style": "striker", "body": "#6b5d4c", "trim": "#3a332b", "eye": "#ffcc33"}, true)
	pickup = {"enemy": bot, "week": week, "year": year, "tier": "open", "first": true}
	phase = 2   # the bell's tonight


## There's always a pickup fight going: whoever is in the pub today.
func start_pickup(wid: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 1000 + week * 10 + day_index()
	var pat := patron_today() if wid < 0 else World.pilot(wid)
	if not pat.is_empty():
		pickup = {"wid": int(pat["wid"]), "enemy": World.robot(int(pat["wid"])), "week": week, "year": year, "tier": str(pat["tier"])}
		return
	var lv := 0.3 + rank_index() * 0.8
	# someone from your tier hanging around the scrapyard (not one of this week's league pilots)
	var busy := World.busy_ids()
	var p := World.pick_pickup(rng, rank, busy.keys())
	if not p.is_empty():
		pickup = {"wid": int(p["wid"]), "enemy": World.robot(int(p["wid"])), "week": week, "year": year}
		return
	var bot := random_bot(rng, [200.0, 300.0, 900.0, 2700.0, 8000.0][clampi(rank_index(), 0, 4)], lv)
	bot["pilot"] = Career.PILOT_NAMES[rng.randi() % Career.PILOT_NAMES.size()]
	pickup = {"enemy": bot, "week": week, "year": year}


# ---------------------------------------------------------------- tag teams (1.58)
# A pilot at the bar who likes you well enough (not cold) will team up: you and them against two
# others from tonight's crowd (or anyone hanging around their league). The purse is a pickup's.
# Fighting side by side is the best way to make a friend: +8, +15 if you win.

const REL_TAG := 8.0
const REL_TAG_WIN := 15.0
const REL_TAG_MIN := -15.0   # colder than this, they won't fight beside you


func is_tag() -> bool:
	return fight_mode() == "pickup" and pickup.get("tag", false)


func can_team_up(wid: int) -> bool:
	return rel_of(wid) > REL_TAG_MIN


## Book a tag team pickup with `ally`. Returns "" or why not.
func start_tag(ally: int) -> String:
	if not can_team_up(ally):
		return tr("They won't fight beside you.")
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 1000 + week * 10 + day_index() + ally * 7
	var tier := str(World.pilot(ally).get("tier", rank))
	var foes: Array = []
	for p in patrons_today():
		var w := int(p["wid"])
		if w != ally and not p.get("hungover", false) and not is_friend(w) and foes.size() < 2:
			foes.append(w)
	var busy: Array = World.busy_ids().keys()
	var guard := 0
	while foes.size() < 2 and guard < 10:
		guard += 1
		var p := World.pick_pickup(rng, tier, busy + foes + [ally])
		if p.is_empty():
			p = World.pick_pickup(rng, rank if rank != "" else "open", busy + foes + [ally])
		if not p.is_empty():
			foes.append(int(p["wid"]))
	if foes.size() < 2:
		return tr("Nobody wants to take on the two of you tonight.")
	var top := tier
	for w in foes:
		var t := str(World.pilot(w).get("tier", tier))
		if Career.ORDER.find(t) > Career.ORDER.find(top):
			top = t
	pickup = {"tag": true, "ally": ally, "wid": int(foes[0]), "foes": foes, "enemy": World.robot(int(foes[0])), "week": week, "year": year, "tier": top}
	return ""


## A world pilot's robot built down to a tag team member (two robots share one heavyweight's power).
func tag_bot(wid: int) -> Dictionary:
	var b := World.robot(wid)
	var mods: Dictionary = TEAM_MODS[2]
	b["hp"] = float(b["hp"]) * float(mods["hp"])
	b["damage"] = float(b["damage"]) * float(mods["damage"])
	b["power_share"] = TEAM_POWER / 2.0
	return b


## The two across the ring: the first is the lead (their pilot is "the opponent" for posts and talk).
func tag_opponent() -> Dictionary:
	var foes: Array = pickup.get("foes", [])
	if foes.size() < 2 or World.pilot(int(foes[0])).is_empty() or World.pilot(int(foes[1])).is_empty():
		return {}
	var a := tag_bot(int(foes[0]))
	var b := tag_bot(int(foes[1]))
	a["bot_name"] = a["name"]
	a["name"] = tr("%s & %s") % [a["name"], b["name"]]
	a["pilot"] = tr("%s & %s") % [str(World.pilot(int(foes[0]))["name"]), str(World.pilot(int(foes[1]))["name"])]
	a["team"] = [b]
	a["team_label"] = TEAM_MODS[2]["label"]
	a["ally"] = int(pickup.get("ally", -1))
	return a


## After a tag fight: your partner likes you more (a lot more if you won), the second robot across the
## ring takes it like a loss to you, and your partner says something.
func tag_after(won: bool) -> void:
	var ally := int(pickup.get("ally", -1))
	var foes: Array = pickup.get("foes", [])
	if ally >= 0 and not World.pilot(ally).is_empty():
		rel_add(ally, REL_TAG_WIN if won else REL_TAG)
		var p := World.pilot(ally)
		if won:
			p["w"] = int(p.get("w", 0)) + 1
		else:
			p["l"] = int(p.get("l", 0)) + 1
		var seed_text := "%d:%d:%s:tag" % [year, week, day]
		pending_stories.append({"lines": [pilot_line(ally, tr(Talk.pick(Talk.TAG_WON if won else Talk.TAG_LOST, seed_text)) % pilot_name)]})
		if won:
			Social.post("w:%d" % ally, ["Tag team with %s tonight. We cleaned house.", "Me and %s, unbeatable. Who's next?"][absi(hash(seed_text)) % 2],
					[pilot_name], {}, ["TagTeam"], true, "pilot_tag")
	if foes.size() >= 2 and won:
		rel_add(int(foes[1]), -REL_FIGHT_K * 0.5)


# ---------------------------------------------------------------- calendar

## Two fight nights a week: cups on Wednesday, leagues (and pickups, exhibitions) on Saturday.
## Is there a cup round for you this Wednesday?
func cup_round_this_week() -> bool:
	return not circuit.is_empty() and circuit.get("phase", "") != "done" and Career.player_opponent(circuit) != -1 \
			and Career.week_of_round(circuit) == week


## Today as 0 (Monday) .. 6 (Sunday).
func day_index() -> int:
	return maxi(0, DAYS.find(day))


## The clock moves on a day (after a fight, or when you let a free day go). After Sunday a new
## week starts on Monday.
func next_day() -> void:
	phase = 0
	pilot_at = "home"   # (1.77) every day starts at Gus's
	passive_repair()
	# every day the pile settles a little more: the odds of finding something go up (a dig spends them)
	dig_luck = minf(DIG_LUCK_MAX, dig_luck + DIG_LUCK_STEP)
	digs_left = DIGS_PER_FIGHT
	if day == "sun":
		advance_week(1)
	else:
		day = DAYS[day_index() + 1]
		catch_up_leagues()
	daily_hate_mail()
	Social.daily()


# ---------------------------------------------------------------- (1.82) Gus's patch job
## No credit means a broke pilot can't repair, and a wrecked robot loses, and losing keeps you broke.
## Gus breaks that circle: on the morning of a league, Trials or cup fight, if you can't pay for the
## repairs he patches every part up to PATCH_HP of its health for nothing, and a missing limb gets a
## piece of junk from his bench. Once a week at most. It's ugly, but it fights.
const PATCH_HP := 0.4
var patched_week := -1
## (1.82) Gus's big cards waiting for the garage: [{title, text, go}] (go: "money", "table", "contracts" or "")
var gus_alerts: Array = []


func gus_alert(title: String, text: String, go: String = "") -> void:
	for a in gus_alerts:
		if a["title"] == title:
			return
	gus_alerts.append({"title": title, "text": text, "go": go})


func gus_patch() -> void:
	if not ["story", "circuit"].has(fight_mode()):
		return
	if patched_week == year * 100 + week:
		return
	var need := repair_all_cost()
	var empty: Array = []
	for slot in ["arm_front", "arm_back", "leg_front", "leg_back", "head"]:
		if slot_available(slot) and equipped_inst(slot).is_empty():
			empty.append(slot)
	if robot_hp_ratio() >= 0.6 and empty.is_empty():
		return
	if money >= need and empty.is_empty():
		return   # you can pay for it: your call
	var did := false
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if p.is_empty():
			continue
		var mx := float(part_def(p["id"])["hp"])
		if float(p["hp"]) < mx * PATCH_HP:
			p["hp"] = mx * PATCH_HP
			did = true
	for slot in empty:
		var kind: String = SLOT_KIND[slot]
		var opts: Array = STARTER_OPTIONS.get(kind, [])
		if opts.is_empty():
			continue
		var uid := add_part(str(opts[0]), 0.6)
		equipped[slot] = uid
		if not bolted.has("m"):
			bolted["m"] = {}
		bolted["m"][slot] = uid   # Gus bolted it on himself, first thing
		did = true
	if not did:
		return
	patched_week = year * 100 + week
	if not story_seen.has("gus_patch_info"):
		mark_story_seen("gus_patch_info")
		gus_alert(tr("I patched it up"), tr("We couldn't pay for repairs, so I patched every part to hold together and bolted junk where bits were missing. It's free, once a week, on a league night. It's ugly. Win and we fix it properly."))
	var line := tr("Couldn't send you out like that. Patched it up on the house, junk where we're missing bits. Win us some money.")
	pending_talk.append({"lines": [["GUS", line, {}]]})
	log_day(tr("Gus patched the robot up for free."), "good")


## Is one of your own fights (a cup round, a league round) still to come this week?
func my_fight_ahead() -> bool:
	if cup_round_this_week() and day_index() <= 2:
		return true
	return not event.is_empty() and event.get("phase", "") != "done" and Career.player_opponent(event) != -1 \
			and Career.week_of_round(event) == week and day_index() <= Career.fight_day(event)


## Can you let today go? Not when your own cup or league fight is tonight.
func can_pass_day() -> bool:
	return not ["story", "circuit"].has(fight_mode())


## The rest of today goes by (the bay works its shifts, and the night if you paid overtime).
func pass_rest_of_day() -> void:
	to_evening()
	advance_phase()


## One step of the clock: morning -> afternoon -> evening, then (if tonight's free) tomorrow.
func next_phase() -> String:
	if phase < 2:
		advance_phase()
		save_game()
		return tr("%s. The bay put in %d hours.") % [tr(PHASE_NAMES[phase]).capitalize(), int(SHIFT_HOURS)]
	return pass_day()


## Nothing for you tonight (or you skip the pickup): on to tomorrow.
func pass_day() -> String:
	if not can_pass_day():
		return "Your fight is tonight. No skipping it."
	refund_self_bets()
	pickup = {}
	pass_rest_of_day()
	save_game()
	return tr("On to %s.") % tr(DAY_FULL[day_index()])


## Straight to the next day with a fight of yours on it (this week), passing the free days.
func skip_to_fight_night() -> String:
	if not my_fight_ahead():
		return "No fight of yours left this week."
	refund_self_bets()
	pickup = {}
	var guard := 0
	while can_pass_day() and guard < 7:
		pass_rest_of_day()
		guard += 1
	save_game()
	return tr("Fight night: %s.") % tr(DAY_FULL[day_index()])


## The first night of yours with a fight on it between now and (w, idx), as a day name ("" = none).
func next_fight_before(w: int, idx: int) -> String:
	var ww := week
	var dd := day_index()
	var guard := 0
	while (ww < w or (ww == w and dd < idx)) and guard < 400:
		var k := str(week_plan(year, ww, DAYS[dd])["kind"])
		if k in ["league", "playoff", "cup"]:
			return tr(DAY_FULL[dd])
		dd += 1
		if dd > 6:
			dd = 0
			ww += 1
		guard += 1
	return ""


## Jump ahead to a later day (this week or any later week this year), letting the free days in
## between go. Stops early at a night with your own fight on it.
func skip_to_day(idx: int, w: int = -1) -> String:
	if w < 0:
		w = week
	refund_self_bets()
	pickup = {}
	var y0 := year
	var guard := 0
	while year == y0 and (week < w or (week == w and day_index() < idx)) and can_pass_day() and guard < 400:
		pass_rest_of_day()
		guard += 1
	save_game()
	return tr("It's %s.") % tr(DAY_FULL[day_index()])


const DAY_FULL := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


## Every line anyone says to you goes in the inbox (Messages): kind = story / talk (pilots,
## hate mail, pub) / gus (his remarks on what you do) / news.
# ---------------------------------------------------------------- (1.84) the loan shark
## No credit at Gus's, so a broke pilot borrows from Lucky Varga down at the Docks: at most
## LOAN_MONTHS of your running costs, one loan at a time, LOAN_FEE on top. Half of every purse,
## prize, salvage bonus and sponsor fee goes to him until it's paid (LOAN_GARNISH), and you can pay
## early. It's due LOAN_WEEKS after you take it; after that what's owed grows LOAN_LATE a week, and
## from LOAN_SEIZE weeks late his people take a part a week (the best spare in storage, else a limb).
## loan = {owed, took (abs week), due (abs week), late (weeks late so far)}
const LOAN_FEE := 0.4
const LOAN_MONTHS := 2.0
const LOAN_WEEKS := 4
const LOAN_LATE := 0.1
const LOAN_SEIZE := 2
const LOAN_GARNISH := 0.5
const GARNISH_CATS := ["fights", "prizes", "salvage", "sponsors"]
const LENDER := "LUCKY VARGA"
var loan := {}


func abs_week() -> int:
	return year * 53 + week


func loan_max() -> int:
	return int(living_cost() * LOAN_MONTHS / 10.0) * 10


## "" or why you can't borrow right now.
func loan_block() -> String:
	if not loan.is_empty():
		return tr("Pay off the loan you've got first.")
	if wins + losses < 1:
		return tr("Varga lends to pilots, not to rookies. Fight once first.")
	return ""


func take_loan(amount: int) -> String:
	if loan_block() != "":
		return loan_block()
	amount = clampi(amount, 0, loan_max())
	if amount <= 0:
		return ""
	var owe := int(round(amount * (1.0 + LOAN_FEE)))
	loan = {"owed": owe, "took": abs_week(), "due": abs_week() + LOAN_WEEKS, "late": 0, "lent": amount}
	book("loan", amount)
	log_talk(LENDER, tr("$%d, kid. You owe me $%d in %d weeks. Half of every purse comes to me till then. Don't make me come to the bay.") % [amount, owe, LOAN_WEEKS], "loan")
	log_day(tr("Borrowed $%d from Lucky Varga. $%d owed.") % [amount, owe], "bad")
	return tr("Borrowed $%d. You owe Varga $%d.") % [amount, owe]


## Pay some or all of it back (taken: the purse cut, already off the money).
func loan_pay_off(amount: int, taken: bool = false) -> void:
	if loan.is_empty() or amount <= 0:
		return
	amount = mini(amount, int(loan["owed"]))
	if not taken:
		book("loan", -amount)
	else:
		_ledger_add("loan", -amount)
	loan["owed"] = int(loan["owed"]) - amount
	if int(loan["owed"]) <= 0:
		loan = {}
		log_talk(LENDER, tr("Paid in full. Pleasure doing business. You know where I am."), "loan")
		log_day(tr("The loan is paid off."), "good")


## A week goes by: interest when it's late, and from LOAN_SEIZE weeks late his people take a part.
func loan_week() -> void:
	if loan.is_empty() or abs_week() <= int(loan["due"]):
		return
	loan["late"] = int(loan["late"]) + 1
	var add := int(ceil(int(loan["owed"]) * LOAN_LATE))
	loan["owed"] = int(loan["owed"]) + add
	if int(loan["late"]) == 1:
		log_talk(LENDER, tr("You're late, kid. That's $%d more on top. Every week.") % add, "loan")
		gus_alert(tr("Varga wants his money"), tr("The loan's overdue. It grows by a tenth every week now, and in two weeks his people come for our parts. Pay him off from the Money page."), "money")
	elif int(loan["late"]) >= LOAN_SEIZE:
		var took := loan_seize()
		if took != "":
			log_talk(LENDER, tr("My boys took the %s. That's off what you owe. Pay up before they come back.") % took, "loan")
			log_day(tr("Varga's people took the %s.") % took, "bad")


## The best spare in storage, else a fitted arm or leg. Its sale value comes off the debt.
func loan_seize() -> String:
	var best := {}
	for p in spares():
		if best.is_empty() or sell_value(p) > sell_value(best):
			best = p
	if best.is_empty():
		for slot in ["arm_back", "leg_back", "arm_front", "leg_front"]:
			var p := equipped_inst(slot)
			if not p.is_empty():
				equipped[slot] = -1
				best = p
				break
	if best.is_empty():
		return ""
	var name := str(part_def(best["id"])["name"])
	var v := sell_value(best) * 2
	inventory.erase(best)
	loan["owed"] = maxi(0, int(loan["owed"]) - v)
	if int(loan["owed"]) <= 0:
		loan = {}
	return name


## (1.79) The money book: every dollar in or out, with what it was for. ledger = [[y, w, d, cat, amount]],
## the last LEDGER_WEEKS weeks kept (Season > Money reads it back). Same day + same cat are merged.
const LEDGER_WEEKS := 16
const LEDGER_CATS := ["fights", "prizes", "salvage", "sponsors", "sales", "bets", "loan", "parts", "repairs", "bay", "bills", "scout", "other"]
const LEDGER_NAMES := {"fights": "Purses", "prizes": "Prizes", "salvage": "Salvage bonus", "sponsors": "Sponsors",
		"sales": "Parts sold", "bets": "Bets", "parts": "Parts bought", "repairs": "Repairs & bay work",
		"bay": "Bay upgrades", "bills": "Rent & running costs", "scout": "Scouting", "loan": "Loan", "other": "Other"}
var ledger: Array = []
## (1.87) Every bet once it's settled, newest last (the last BET_LOG_KEEP): {y, w, d, what, pick, vs,
## stake, odds, won, pay, spec (a fight you can watch again: see watch_past), live}.
var bet_log: Array = []
const BET_LOG_KEEP := 80


func log_bet(what: String, pick: String, vs: String, stake: int, odds: float, won: bool, pay: int, spec: Array = [], live: bool = false) -> void:
	bet_log.append({"y": year, "w": week, "d": day_index(), "what": what, "pick": pick, "vs": vs, "stake": stake,
			"odds": snappedf(odds, 0.01), "won": won, "pay": pay, "spec": spec, "live": live})
	while bet_log.size() > BET_LOG_KEEP:
		bet_log.pop_front()


func book(cat: String, amount: int) -> void:
	if amount != 0 and not world.is_empty():
		PlayLog.add("money", "%s %+d (cash %d)" % [cat, amount, money + amount])
	# (1.84) a loan takes its cut of whatever you win or earn first
	if amount > 0 and not loan.is_empty() and GARNISH_CATS.has(cat):
		var cut := mini(int(loan["owed"]), int(amount * LOAN_GARNISH))
		if cut > 0:
			amount -= cut
			loan_pay_off(cut, true)
	money += amount
	_ledger_add(cat, amount)


func _ledger_add(cat: String, amount: int) -> void:
	if amount == 0:
		return
	var d := day_index()
	if not ledger.is_empty():
		var l: Array = ledger[-1]
		if int(l[0]) == year and int(l[1]) == week and int(l[2]) == d and str(l[3]) == cat and (int(l[4]) < 0) == (amount < 0):
			l[4] = int(l[4]) + amount
			return
	ledger.append([year, week, d, cat, amount])
	var oldest := (year * 53 + week) - LEDGER_WEEKS
	while not ledger.is_empty() and int(ledger[0][0]) * 53 + int(ledger[0][1]) < oldest:
		ledger.pop_front()


## Money in / out by category between two weeks (inclusive), as {cat: [in, out]} plus "_net".
func ledger_sum(y0: int, w0: int, y1: int, w1: int) -> Dictionary:
	var out := {}
	var net := 0
	for l in ledger:
		var k := int(l[0]) * 53 + int(l[1])
		if k < y0 * 53 + w0 or k > y1 * 53 + w1:
			continue
		var c := str(l[3])
		if not out.has(c):
			out[c] = [0, 0]
		var a := int(l[4])
		if a >= 0:
			out[c][0] += a
		else:
			out[c][1] -= a
		net += a
	out["_net"] = net
	return out


## The day book: everything that happened, day by day (the calendar's day pop-up reads it back).
## "y/w/d" -> [{"ph": phase, "text": ..., "c": "good"/"bad"/"info"}]. The last DAY_LOG_DAYS days are kept.
const DAY_LOG_DAYS := 120
var day_log := {}


func day_key(y: int, w: int, d: int) -> String:
	return "%d/%d/%d" % [y, w, d]


func log_day(text: String, c: String = "info", y: int = -1, w: int = -1, d: int = -1, ph: int = -1) -> void:
	if text.strip_edges() == "":
		return
	var k := day_key(year if y < 0 else y, week if w < 0 else w, day_index() if d < 0 else d)
	if not day_log.has(k):
		day_log[k] = []
		if day_log.size() > DAY_LOG_DAYS:
			var keys: Array = day_log.keys()
			keys.sort_custom(func(a, b): return _day_num(a) < _day_num(b))
			day_log.erase(keys[0])
	day_log[k].append({"ph": phase if ph < 0 else ph, "text": text, "c": c})


static func _day_num(k: String) -> int:
	var p := k.split("/")
	return (int(p[0]) * 52 + int(p[1])) * 7 + int(p[2])


func log_talk(who: String, text: String, kind: String, look: Dictionary = {}, wid: int = -1) -> void:
	if text.strip_edges() == "":
		return
	if not inbox.is_empty() and inbox[-1]["text"] == text and inbox[-1]["who"] == who:
		return
	var e := {"y": year, "w": week, "d": day, "ph": phase, "who": who, "text": text, "kind": kind}
	if not look.is_empty():
		e["look"] = look
	if wid >= 0:
		e["wid"] = wid   # a world pilot: their name opens the pilot card
	inbox.append(e)
	if inbox.size() > INBOX_MAX:
		inbox = inbox.slice(inbox.size() - INBOX_MAX)


## Kept for old callers: let Wednesday go.
func skip_wednesday() -> String:
	return pass_day()


## The week moves on (after Saturday's fight, or when you rest). Sunday: the dealer restocks and the
## scrapyard gets fresh junk. New leagues start on their week.
func advance_week(n: int = 1) -> void:
	for k in n:
		World.week_passed(year, week, World.busy_ids())   # the rest of Port Ferrum fights and shops too
		weekly_rumour()
		rel_drift(0.96)
		feuds_week()
		loan_week()
		Contracts.week_end()
		if week % MONTH_WEEKS == 0:
			book("bills", -(living_cost()))   # end of the month: cost of living
			bills_note += living_cost()
			var fees := Contracts.month_end()
			if fees > 0:
				log_day(tr("Sponsors paid $%d.") % fees, "good")
		catch_up_leagues()
		week += 1
		if week > Career.WEEKS_PER_YEAR:
			week = 1
			year += 1
			new_year()
	if n > 0:
		roll_stock()
		digs_left = DIGS_PER_FIGHT
		day = "mon"
		catch_up_leagues()
		Contracts.weekly_offers()


## A year ends: pilots move up and down by last year's tables, then the new tables are drawn.
func new_year() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 104729
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		var guard := 0
		while ["league", "finals"].has(str(ev.get("phase", ""))) and guard < 40:
			guard += 1
			if Career.has_player(ev) and Career.player_opponent(ev) != -1:
				Career.after_player_fight(ev, false, 0)   # (a playoff you never turned up for)
				continue
			Career.play_npc_round(ev)
	# who's in next year's Titanium Championship: the 8 who made it from the Steel League
	title_seeds = []
	var steel: Dictionary = leagues.get("steel", {})
	for id in steel.get("promoted", []):
		var e: Dictionary = Career.pilot(steel, int(id)).duplicate()
		if int(id) == 0:
			e = {"player": true, "pilot": "YOU", "str": 1.0}
		elif e.has("wid") and World.pilot(int(e["wid"])).get("retired", false):
			continue
		title_seeds.append(e)
	World.year_end(rng, leagues)
	rel_drift(0.7)   # time heals a bit, but only down to the last milestone reached
	start_year()


func living_cost() -> int:
	return int(int(settings.get("living_cost", LIVING_COST)) * float(RUNNING.get(rank, 1.0)) * (1.0 + GANTRY_RENT * gantries + BAY_RENT * bay_level) / 10.0) * 10 \
			+ mechanics * mechanic_wage()


# ---------------------------------------------------------------- passive repair and the bay upgrades

## How much HP every part on your robots gets back each day, as a share of its max.
func passive_rate() -> float:
	return PASSIVE_BASE + PASSIVE_STEP * bay_level


## A day goes by: Gus tinkers. Parts on your robots heal a little (wrecks need a real rebuild).
func passive_repair() -> void:
	var rate := passive_rate()
	var uids: Array = []
	for slot in BODY_SLOTS:
		var p := equipped_inst(slot)
		if not p.is_empty():
			uids.append(int(p["uid"]))
	for wm in wingmen:
		for slot in wm:
			uids.append(int(wm[slot]))
	for uid in uids:
		var p := inst(uid)
		if p.is_empty() or float(p["hp"]) <= 0.0:
			continue
		var mx: float = float(part_def(p["id"])["hp"])
		p["hp"] = minf(mx, float(p["hp"]) + mx * rate)


## What one more bay level adds to the monthly bill.
func bay_rent() -> int:
	return int(int(settings.get("living_cost", LIVING_COST)) * float(RUNNING.get(rank, 1.0)) * BAY_RENT / 10.0) * 10


func bay_price() -> int:
	if bay_level >= BAY_LEVELS:
		return 0
	var base := maxf(500.0, float(settings.get("living_cost", LIVING_COST))) * float(RUNNING.get(rank, 1.0))
	return int(base * float(BAY_PRICE[bay_level]) / 10.0) * 10


func buy_bay_upgrade() -> String:
	if bay_level >= BAY_LEVELS:
		return "The bay's as good as it gets."
	var c := bay_price()
	if money < c:
		return tr("The %s costs $%d. No credit at Gus's.") % [tr(BAY_NAMES[bay_level + 1]), c]
	book("bay", -(c))
	bay_level += 1
	return tr("Gus installs the %s: $%d. Parts heal %d%% a day now, and the rent goes up $%d a month.") % [tr(BAY_NAMES[bay_level]), c, int(round(passive_rate() * 100.0)), bay_rent()]


## What one more gantry adds to the monthly bill.
func gantry_rent() -> int:
	return int(int(settings.get("living_cost", LIVING_COST)) * float(RUNNING.get(rank, 1.0)) * GANTRY_RENT / 10.0) * 10


func gantry_price() -> int:
	return GANTRY_PRICE * int(pow(2, gantries))


## A backup robot needs its own gantry in the crew bay, and a bigger bay costs more rent.
func buy_gantry() -> String:
	if gantries >= wingmen.size():
		return "The crew bay is full. No room for another gantry."
	var c := gantry_price()
	if money < c:
		return tr("A gantry costs $%d. No credit at Gus's.") % c
	book("bay", -(c))
	gantries += 1
	return tr("Gus bolts a new gantry into the crew bay. $%d, and the rent goes up $%d a month.") % [c, gantry_rent()]


func sell_gantry() -> String:
	if gantries <= 0:
		return ""
	if not wingmen[gantries - 1].is_empty():
		return "Take the backup robot off that gantry first (Disband)."
	gantries -= 1
	var back := gantry_price() / 2
	book("bay", back)
	return tr("Gus unbolts a gantry and sells it on for $%d. The rent goes back down.") % back


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


## A new year: the divisions are drawn up from the world (the best pilots of each tier), you
## take your place in yours, and the fixture lists are made.
func start_year() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 7919 + randi() % 1000
	leagues = {}
	for stage in Career.ORDER:
		if stage == "scrap":
			continue   # drawn up when the Open Trials are over (8 of its places come from there)
		var mine: bool = stage == rank
		var wids := tier_pick(stage, mine)
		if stage == "open":
			# the gutter: no table, just the Open Trials on the open dates (weeks 1-2)
			leagues[stage] = Career.new_trials(year, rng.randi(), mine, wids)
			continue
		leagues[stage] = Career.new_event(stage, year, rng.randi(), mine, wids)
	# the Titanium Championship: last year's top of the Steel League (a brand-new world: its best 8)
	var entries: Array = title_seeds.duplicate(true)
	if entries.is_empty():
		entries.append({"rival": 9, "pilot": "KANE DYNAMICS", "str": 9.0})
		var pool: Array = World.active("steel")
		pool.sort_custom(func(a, b): return World.rating(World.robot(int(a["wid"])), a["skill"]) > World.rating(World.robot(int(b["wid"])), b["skill"]))
		for p in pool.slice(0, 7):
			entries.append({"wid": int(p["wid"]), "pilot": str(p["name"])})
	leagues["title"] = Career.new_title(year, rng.randi(), entries)
	title_seeds = []
	if trials_over():
		build_scrap()
	sync_event()


## The best world pilots of a tier for its table (minus places for you, story rivals, OVERLORD).
func tier_pick(stage: String, mine: bool) -> Array:
	var info: Dictionary = Career.STAGES[stage]
	var need: int = int(info["size"]) - (1 if mine else 0) - (info["rivals"].size() if mine else 0) - (1 if info.has("boss") else 0)
	var pool: Array = World.active(stage)
	pool.sort_custom(func(a, b): return World.rating(World.robot(int(a["wid"])), a["skill"]) > World.rating(World.robot(int(b["wid"])), b["skill"]))
	var wids: Array = []
	for p in pool.slice(0, need):
		wids.append(int(p["wid"]))
	wids.shuffle()
	return wids


## (1.79) You're in this year's Open Trials and still fighting for a place (not in, not out yet).
func trials_pending() -> bool:
	if rank != "open" or trials_over():
		return false
	var tr_ev: Dictionary = leagues.get("open", {})
	var rec: Array = Career.trials_record(tr_ev, 0)
	return int(rec[0]) < 2 and int(rec[1]) < 2


func trials_over() -> bool:
	var tr_ev: Dictionary = leagues.get("open", {})
	return tr_ev.is_empty() or tr_ev.get("phase", "") == "done"


## The Open Trials are over: the 8 winners join the Scrap League, and its table is drawn up.
func build_scrap() -> void:
	if leagues.has("scrap"):
		return
	var tr_ev: Dictionary = leagues.get("open", {})
	for id in tr_ev.get("promoted", []):
		var e := Career.pilot(tr_ev, int(id))
		var p := World.pilot(int(e.get("wid", -1)))
		if not p.is_empty() and not p["retired"]:
			World.move_tier(p, "scrap")
	World.fit_tier("scrap")
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 4111 + 7
	leagues["scrap"] = Career.new_event("scrap", year, rng.randi(), rank == "scrap", tier_pick("scrap", rank == "scrap"))


## Which event is "yours" right now: the Titanium Championship while you're still in it, otherwise
## your league (or the Open Trials, in the gutter).
func sync_event() -> void:
	var t: Dictionary = leagues.get("title", {})
	if not t.is_empty() and Career.has_player(t) and t.get("phase", "") != "done":
		event = t
	else:
		event = leagues.get(rank, {})


## Kept for old callers: the year's tables exist (made at New Game and every new year).
func ensure_event() -> void:
	if leagues.is_empty() or int(leagues.values()[0].get("year", 0)) != year:
		start_year()
	sync_event()


## Every division whose league night has gone by plays its round (yours is played by your fight;
## if you somehow missed yours, it's a forfeit). Bets on those fights are settled.
## BotMedia's sports desk: who's on top of the big leagues after a round.
func league_news(stage: String, ev: Dictionary) -> void:
	if not ["steel", "iron", "title"].has(stage) or ev.get("phase", "") == "done":
		return
	var order: Array = Career.standings(ev)
	if order.is_empty():
		return
	var top: Dictionary = Career.pilot(ev, int(order[0]))
	if stage == "title":
		World.news("Titanium Championship: %s is still standing.", [str(top.get("pilot", "?"))])
		return
	var pts: int = int(ev["table"].get(str(order[0]), [0])[0])
	World.news("%s, round %d: %s leads the table, %d pts.", ["stage:" + stage, int(ev["round"]), str(top.get("pilot", "?")), pts])


## Rumours from the docks, one most weeks: who's broke, who's spending, who Kane is watching.
const RUMOURS := [
	"Rumour at the docks: %s was seen at the dealer's with a fat wallet.",
	"They say %s is sleeping in the garage to save on rent.",
	"Kane scouts were spotted in the stands watching %s.",
	"Word is %s wants a rematch with somebody. Nobody will say who.",
	"%s's crew walked out over unpaid wages. Or so they say.",
	"Somebody saw %s at the scrapyard at 3 a.m., digging.",
]


func weekly_rumour() -> void:
	var all := World.active()
	if all.is_empty() or randf() > 0.6:
		return
	var p: Dictionary = all[randi() % all.size()]
	World.news(RUMOURS[randi() % RUMOURS.size()], [str(p["name"])])


func catch_up_leagues() -> Array:
	var lines: Array = []
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		var guard := 0
		while Career.round_due(ev, week, day_index()) and guard < Career.ROUNDS:
			guard += 1
			if Career.has_player(ev):
				if (ev["phase"] == "finals" or ev["phase"] == "playoffs") and Career.player_opponent(ev) == -1:
					# you're out (or not in this round) but it goes on without you
					Career.play_npc_round(ev)
					lines += settle_bets("event", ev)["lines"]
					if ev["phase"] == "done":
						pending_talk.append({"lines": [["GUS", finish_title(ev) if stage == "title" else finish_event(ev), {}]]})
					continue
				var res: Dictionary = Career.after_player_fight(ev, false, 0)   # didn't turn up: a loss
				losses += 1
				if res["phase_changed"]:
					league_end(ev)
				if res["done"]:
					if stage == "title":
						finish_title(ev)
					else:
						finish_event(ev)
				bets = bets.filter(func(b): return b["on"] != "event")
				continue
			Career.play_npc_round(ev)
			league_news(stage, ev)
			if str(ev.get("phase", "")) != "league" and not ev.get("trials", false) and stage != "title":
				Social.podium(ev, "league")
			lines += settle_bets("div:" + stage, ev)["lines"]
	if trials_over() and not leagues.has("scrap") and not leagues.is_empty():
		build_scrap()
	sync_event()
	queue_night_films()   # (1.75) the night's best fights get filmed in the background
	return lines


## Your division: [stage, week of your next league night, weeks from now] (stage "" if none left).
func next_event_info() -> Array:
	if not event.is_empty() and event.get("phase", "") == "league":
		return [event["stage"], Career.week_of_round(event), maxi(0, Career.week_of_round(event) - week)]
	return ["", 0, 0]


## The league runs all year: nothing to skip ahead to.
func skip_to_next_event() -> String:
	return "The league runs all year. Your next league night is on the calendar."


## Your division this year (the only league you play).
func enters_stage(stage: String) -> bool:
	return stage == rank


func rest_week() -> String:
	if my_fight_ahead():
		return "Your fight's still to come this week. No resting yet."
	refund_self_bets()
	pickup = {}
	var w := week
	var guard := 0
	while week == w and guard < 8:
		pass_rest_of_day()
		guard += 1
	save_game()
	return tr("A quiet week. Year %d, week %d.") % [year, week]


## What's on your calendar in a week of this year: {kind, text}
##   kind: done (a fight you had), league, playoff, cup, open (quiet week), past (nothing happened)
func week_plan(y: int, w: int, d: String = "sat") -> Dictionary:
	for e in fight_log:
		if int(e["y"]) == y and int(e["w"]) == w and str(e.get("d", "sat")) == d:
			return {"kind": "done", "won": e["won"], "text": tr("WON vs %s" if e["won"] else "LOST vs %s") % e["opp"], "title": e["title"], "stage": log_stage(e)}
	var di := DAYS.find(d)
	if y < year or (y == year and (w < week or (w == week and di < day_index()))):
		return {"kind": "past", "text": ""}
	var this_week := y == year and w == week
	if d == "wed" and y == year and not circuit.is_empty() and circuit.get("phase", "") != "done" and circuit["weeks"].has(w) \
			and Career.player_opponent(circuit) != -1:
		return {"kind": "cup", "text": "%s" % circuit["name"], "stage": "cup"}
	if y == year:
		for key in ["title", "open", rank]:
			var ev: Dictionary = leagues.get(key, {})
			if ev.is_empty() or not Career.has_player(ev):
				continue
			var p := plan_for(ev, w, di)
			if not p.is_empty():
				return p
	if this_week or d == "sat":
		# a free night: there's always a pickup fight down at the Rusty Bolt
		return {"kind": "open", "text": "pickup fight", "stage": "pickup"}
	return {"kind": "none", "text": ""}


## Your fight in one of your events on week w, day di (or {}).
func plan_for(ev: Dictionary, w: int, di: int) -> Dictionary:
	var stage := str(ev["stage"])
	var short: String = tr(Career.STAGES[stage]["short"])
	match str(ev.get("phase", "")):
		"league":
			if di == 5 and ev["weeks"].has(w):
				var k: int = ev["weeks"].find(w)
				if k >= int(ev["round"]) and k < ev["schedule"].size():
					var o := Career.robot_of(ev, int(ev["schedule"][k]))
					return {"kind": "league", "text": tr("%s R%d\nvs %s") % [short, k + 1, o.get("name", "?")], "stage": stage, "round": k}
			for sl in Career.PLAYOFF_SLOTS:
				if int(sl[0]) == w and int(sl[1]) == di:
					return {"kind": "playoff", "text": tr("%s\nplayoffs (if you qualify)") % short, "stage": stage}
		"finals":
			var slots: Array = ev.get("slots", Career.PLAYOFF_SLOTS)
			for r in range(int(ev["po_round"]), slots.size()):
				if int(slots[r][0]) == w and int(slots[r][1]) == di:
					if r == int(ev["po_round"]):
						if Career.player_opponent(ev) != -1:
							return {"kind": "playoff", "text": tr(Career.round_name(ev)), "stage": stage}
					elif Career.finals_side(ev, 0) != "":
						return {"kind": "playoff", "text": tr("%s\n(if you get through)") % short, "stage": stage}
		"playoffs":
			for r in range(int(ev["round"]), ev["weeks"].size()):
				if int(ev["weeks"][r]) == w and di == 5:
					if r == int(ev["round"]):
						if Career.player_opponent(ev) != -1:
							return {"kind": "playoff", "text": tr(Career.round_name(ev)), "stage": stage}
					else:
						return {"kind": "playoff", "text": tr("%s\n(if you get through)") % short, "stage": stage}
	return {}


## Which kind of fight a logged result was (scrap / regional / championship / cup / pickup / exhibition).
func log_stage(e: Dictionary) -> String:
	var st := str(e.get("stage", ""))
	if st != "":
		return st
	match str(e.get("mode", "")):
		"circuit":
			return "cup"
		"pickup", "exhibition":
			return str(e["mode"])
	var t := str(e.get("title", "")).to_upper()
	for stage in Career.ORDER:
		if t.begins_with(tr(Career.STAGES[stage]["short"]).to_upper()):
			return stage
	return "pickup" if t.contains("PICKUP") else ("cup" if str(e.get("d", "sat")) == "wed" else "scrap")


# ---------------------------------------------------------------- betting

## The event you can bet on this week ("event" or "cup"), "self" (a pickup or exhibition: the
## bookies only take bets on you), or "" (nothing).
func bet_target() -> String:
	match fight_mode():
		"story":
			return "event"
		"circuit":
			return "cup"
		"pickup", "exhibition":
			return "self"
	return ""


## The event a bet / watch key points at: "event" (your division), "cup", "div:<stage>".
func ev_for(on: String) -> Dictionary:
	if on == "event":
		return event
	if on == "cup":
		return circuit
	if on.begins_with("div:"):
		return leagues.get(on.substr(4), {})
	return {}


## Tonight's league card: every division fighting tonight that you can bet on / watch, as
## [key, event] (yours first). Only on a league Saturday, before the round is played.
func league_night() -> Array:
	var out: Array = []
	for stage in Career.EVENTS:
		var ev: Dictionary = leagues.get(stage, {})
		if not ["league", "finals", "playoffs"].has(str(ev.get("phase", ""))) or (ev["phase"] == "league" and int(ev["round"]) >= ev["weeks"].size()) \
				or Career.week_of_round(ev) != week or Career.fight_day(ev) != day_index() or Career.round_matches(ev).is_empty():
			continue
		if Career.has_player(ev):
			if fight_mode() == "story":
				out.insert(0, ["event", ev])
		else:
			out.append(["div:" + stage, ev])
	return out


## The best fight on tonight's top card (the TV in the pub shows it): the highest division
## fighting tonight, its two pilots with the most points between them.
func headline_match() -> Dictionary:
	var night := league_night()
	if night.is_empty():
		return {}
	var best: Array = night[night.size() - 1]
	for x in night:
		if Career.EVENTS.find(str(x[1]["stage"])) > Career.EVENTS.find(str(best[1]["stage"])):
			best = x
	var ev: Dictionary = best[1]
	var top: Array = []
	var score := -1
	for pr in Career.round_matches(ev):
		if int(pr[0]) == 0 or int(pr[1]) == 0:
			continue
		var ta: Array = ev["table"].get(str(pr[0]), [0, 0, 0, 0])
		var tb: Array = ev["table"].get(str(pr[1]), [0, 0, 0, 0])
		var sc := int(ta[2]) + int(tb[2])
		if sc > score:
			score = sc
			top = pr
	if top.is_empty():
		return {}
	return {"on": best[0], "ev": ev, "a": int(top[0]), "b": int(top[1])}


## A bet on any match on tonight's card (`on` = "event" / "cup" / "div:<stage>").
## Bet sizes grow with your league, like everything else.
func stakes() -> Array:
	var m := pow(GRADE_PRICE, my_grade() - 1)
	var out: Array = []
	for st in [10, 50, 100, 250, 500]:
		out.append(int(st * m))
	return out


func place_bet_on(on: String, pick: int, vs: int, stake: int) -> String:
	var ev := ev_for(on)
	if ev.is_empty():
		return "Nothing to bet on this week."
	if vs == 0:
		return "Betting against yourself? Gus would never speak to you again."
	if money < stake:
		return tr("You need $%d in cash to place that bet.") % stake
	var o := Career.odds(ev, pick, vs)
	book("bets", -(stake))
	bets.append({"on": on, "round": Career.round_key(ev), "pick": pick, "vs": vs, "stake": stake, "odds": o})
	var who: String = pilot_name if pick == 0 else str(Career.pilot(ev, pick).get("pilot", "?"))
	return tr("$%d on %s at %.2fx, pays $%d if they win.") % [stake, who, o, int(stake * o)]


## The bookies' price on you winning your next pickup or exhibition fight.
func self_odds() -> float:
	var o := current_opponent()
	var p := 0.5
	if o.has("parts"):
		var mine := World.rating({"parts": equipped_ids(), "hp": 1.0, "damage": 1.0}, 0.5)
		var skill := 0.3
		if o.has("wid"):
			skill = float(World.pilot(int(o["wid"])).get("skill", 0.3))
		elif fight_mode() == "exhibition":
			skill = 0.95
		p = World.win_chance(mine, World.rating(o, skill))
	return snappedf(maxf(1.05, 0.9 / clampf(p, 0.08, 0.92)), 0.05)


## Bets on yourself in a pickup or exhibition fight that never happened go back to you.
func refund_self_bets() -> void:
	for b in bets:
		if b["on"] == "self":
			book("bets", int(b["stake"]))
	bets = bets.filter(func(b): return b["on"] != "self")


func settle_self_bets(won: bool) -> Dictionary:
	var out := {"paid": 0, "staked": 0, "lines": []}
	for b in bets:
		if b["on"] != "self":
			continue
		out["staked"] += b["stake"]
		var opp_n := str(current_opponent(false).get("pilot", current_opponent(false).get("name", "?")))
		if won:
			var pay := int(b["stake"] * b["odds"])
			book("bets", pay)
			out["paid"] += pay
			out["lines"].append(tr("Bet on %s: +$%d") % [pilot_name, pay])
			log_bet("self", pilot_name, opp_n, int(b["stake"]), float(b["odds"]), true, pay)
		else:
			out["lines"].append(tr("Bet on %s: lost $%d") % [pilot_name, b["stake"]])
			log_bet("self", pilot_name, opp_n, int(b["stake"]), float(b["odds"]), false, 0)
	bets = bets.filter(func(b): return b["on"] != "self")
	return out


func bet_event() -> Dictionary:
	return event if bet_target() == "event" else (circuit if bet_target() == "cup" else {})


## Put money on pilot `pick` beating `vs` this round. Needs real cash.
func place_bet(pick: int, vs: int, stake: int) -> String:
	if bet_target() == "self":
		if money < stake:
			return tr("You need $%d in cash to place that bet.") % stake
		var so := self_odds()
		book("bets", -(stake))
		bets.append({"on": "self", "round": 0, "pick": 0, "vs": -1, "stake": stake, "odds": so})
		return tr("$%d on %s at %.2fx, pays $%d if they win.") % [stake, pilot_name, so, int(stake * so)]
	var ev := bet_event()
	if ev.is_empty():
		return "Nothing to bet on this week."
	if vs == 0:
		return "Betting against yourself? Gus would never speak to you again."
	if money < stake:
		return tr("You need $%d in cash to place that bet.") % stake
	var o := Career.odds(ev, pick, vs)
	book("bets", -(stake))
	bets.append({"on": bet_target(), "round": Career.round_key(ev), "pick": pick, "vs": vs, "stake": stake, "odds": o})
	var who: String = pilot_name if pick == 0 else str(Career.pilot(ev, pick).get("pilot", "?"))
	return tr("$%d on %s at %.2fx, pays $%d if they win.") % [stake, who, o, int(stake * o)]


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
		var vs_n: String = pilot_name if b["vs"] == 0 else str(Career.pilot(ev, b["vs"]).get("pilot", "?"))
		# a fight between two computer pilots in a league can be filmed again later (Watch)
		var spec: Array = []
		var stg := str(ev.get("stage", ""))
		if is_same(leagues.get(stg, {}), ev) and b["pick"] != 0 and b["vs"] != 0 and winner >= 0:
			var parts := 1
			for x in res["list"]:
				if (int(x["a"]) == b["pick"] and int(x["b"]) == b["vs"]) or (int(x["b"]) == b["pick"] and int(x["a"]) == b["vs"]):
					parts = int(x.get("p", 1))
			spec = [stg, year, int(res["round"]), int(b["pick"]), int(b["vs"]), winner, parts]
		var what := "cup" if on == "cup" else "league"
		if winner == b["pick"]:
			var pay := int(b["stake"] * b["odds"])
			book("bets", pay)
			out["paid"] += pay
			out["lines"].append(tr("Bet on %s: +$%d") % [who, pay])
			log_bet(what, who, vs_n, int(b["stake"]), float(b["odds"]), true, pay, spec)
		else:
			out["lines"].append(tr("Bet on %s: lost $%d") % [who, b["stake"]])
			log_bet(what, who, vs_n, int(b["stake"]), float(b["odds"]), false, 0, spec)
	bets = keep
	return out


# ---------------------------------------------------------------- watching other pilots' fights

## Fights are on in the evening of their own night: that's the only time you can watch one.
func watch_time(ev: Dictionary) -> bool:
	if ev.is_empty() or phase < 2:
		return false
	var fd := 2 if is_same(ev, circuit) else Career.fight_day(ev)   # cups fight on Wednesdays
	return Career.week_of_round(ev) == week and fd == day_index()


## Can you watch a & b fight this round? Computer pilots only, once per match, and Kane Dynamics
## keeps OVERLORD's fights behind closed doors.
func can_watch(ev: Dictionary, a: int, b: int) -> bool:
	if ev.is_empty() or a == 0 or b == 0 or not watch_time(ev):
		return false
	for id in [a, b]:
		if int(Career.pilot(ev, id).get("rival", -1)) == OPPONENTS.size() - 1 or Career.retired(ev, id):
			return false
	for f in ev.get("forced", []):
		if int(f["round"]) == int(ev["round"]) and ((int(f["a"]) == a and int(f["b"]) == b) or (int(f["a"]) == b and int(f["b"]) == a)):
			return false
	return true


func start_watch(a: int, b: int, on: String = "") -> void:
	if on == "":
		on = bet_target()
	var ev := ev_for(on)
	watching = {"on": on, "round": Career.round_key(ev), "a": a, "b": b}


func watch_event() -> Dictionary:
	if watching.is_empty():
		return {}
	return ev_for(str(watching["on"]))


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
	ev["forced"].append({"round": Career.round_key(ev), "a": a, "b": b, "w": w})
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
	var loser_name := str(Career.robot_of(ev, l).get("pilot", Career.pilot(ev, l).get("pilot", "?")))
	Social.watched_fight(winner_name, loser_name, int(Career.pilot(ev, w).get("wid", -1)), stage, int(Career.pilot(ev, l).get("wid", -1)))   # a post waiting on BotMedia
	watching = {}
	save_game()
	return {"winner": winner_name}


func cups_unlocked() -> bool:
	return unlocked("cups") or rank_index() >= 2 or not trophies.is_empty()


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
	if fight_mode() == "test":
		return [test_drive_spec()]
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
		var solo := bench_spec(player_spec(wingmen[sending], wingman_name(sending)), "w%d" % sending)
		solo["wingman"] = sending
		return [solo]
	var team: Array = [bench_spec(player_spec(), "m")]
	if is_tag():
		# a tag team: you and a pilot from the bar, two against two
		var ab := tag_bot(int(pickup["ally"]))
		var aspec := opponent_spec_from(ab, 1.0)
		aspec["ally"] = int(pickup["ally"])
		aspec["ai_src"] = World.robot(int(pickup["ally"]))
		team.append(aspec)
	elif is_team_fight():
		for k in wingmen.size():
			if wingman_ready(k):
				var spec := bench_spec(player_spec(wingmen[k], wingman_name(k)), "w%d" % k)
				spec["wingman"] = k
				team.append(spec)
	# weight classes: a team shares one heavyweight's power. Big parts on a team robot overload it.
	if team.size() > 1:
		var mods: Dictionary = TEAM_MODS[team.size()]
		var share := TEAM_POWER / team.size()
		for spec in team:
			if spec.has("ally"):
				continue   # your tag partner's robot already fights at team strength (tag_bot)
			spec["damage_mult"] = spec["damage_mult"] * mods["damage"]
			spec["hp_scale"] = mods["hp"]
			var st := stats(wingmen[spec["wingman"]] if spec.has("wingman") else equipped)
			var out := minf(float(st["power_output"]), share)
			spec["efficiency"] = 1.0 if st["power_used"] <= out else out / float(st["power_used"])
			spec["power"] = fight_tank(out, float(st["power_used"]))
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
## Saving: the garage asks for a save after every change; it's written a moment later (one write
## for a burst of taps), and right away when the app is closed or sent to the background.
var _save_due := -1.0


func request_save() -> void:
	if save_slot < 0 or not quick.is_empty() or not watching.is_empty() or not test_drive.is_empty():
		return
	if _save_due < 0.0:
		_save_due = Time.get_ticks_msec() / 1000.0 + 0.6


func flush_save() -> void:
	if _save_due >= 0.0:
		_save_due = -1.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush_save()


## Gus told you something in a fight: keep it for the pause screen's GUS'S TIPS (one per id).
func log_tip(id: String, text: String) -> void:
	for t in tips_log:
		if str(t.get("id", "")) == id:
			return
	tips_log.append({"id": id, "text": text})
	if tips_log.size() > 60:
		tips_log = tips_log.slice(tips_log.size() - 60)


func tip_once(id: String) -> bool:
	if tips_seen.has(id):
		return false
	tips_seen.append(id)
	return true


## Wins needed for each feature: one new thing per win, so Gus can explain each one on its own.
const UNLOCKS := {"scrapyard": 0, "season": 0, "style": 1, "shop": 2, "moves": 2, "scout": 3, "cups": 5, "team": 6,
		"workshop": 7, "pilot": 8, "paint": 9, "setups": 10, "randomize": 11}


## Wins, and always a fight after the one that earned it: your first visit to the bay is just
## the bay and the scrapyard; after that one new thing per fight.
func unlocked(feature: String) -> bool:
	var need := int(UNLOCKS.get(feature, 0))
	return champion or (wins >= need and (need == 0 or wins + losses >= need + 1))


## Things that open up in the garage. Each one shows up with a star; the first tap plays a short
## Gus scene ("unlock_<feature>") and then opens it. [feature, garage tab or "" for a button,
## the old one-line tip id (saves from before the scenes count it as already explained)]
const UNLOCK_SCENES := [["scrapyard", "", "scrapyard"], ["storage", "", ""], ["style", "", "style"],
		["shop", "Shop", "shop"], ["season", "Season", "season"], ["scout", "", "scout"], ["moves", "", "moves"],
		["cups", "Cups", ""], ["team", "Team", "backup"], ["workshop", "", "workshop"], ["pilot", "", "pilot"],
		["paint", "", "pilot"], ["setups", "", "setups"], ["randomize", "", "setups"]]
const TAB_FEATURES := {"Shop": "shop", "Season": "season",
		"Cups": "cups", "Team": "team"}
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
## Your dad, as the opening and the trophy wall show him: a rugged old pilot with your skin.
func dad_look() -> Dictionary:
	return {"skin": str(pilot_look.get("skin", "#b07a52")), "eyes": str(pilot_look.get("eyes", "#5b3a1e")), "hair": "#2a1d14",
			"hat": "headband", "beard": "chinstrap", "beard_color": "#3a2e28", "scar": true, "outfit": "#5a3a22",
			"glasses": "none", "controller": "arcade", "long_hair": false}


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
				return tr("Rent's paid up, kid, and that's every cent you've got.") + " " + heap
			if living > 0 and money < living:
				return (tr("$%d to your name, kid. That won't even cover next month.") % money) + " " + heap
			return (tr("$%d in the bank, kid. Nice cushion. In this business it won't last.") % money) + " " + heap
		"RENT_GARAGE":
			var t := ""
			if money < 0:
				t = tr("You still owe me $%d in back rent, kid.") % -money + " "
			t += (tr("Rent and food are $%d a month.") % living) if living > 0 else tr("Rent's on the house for now. Don't get used to it.")
			if money < 0:
				t += " " + tr("No repairs on credit, so for now we fight with the dents.")
			return t
		"PC_KEYS":
			# only on a computer (no touchscreen): point them at the pause screen, where every key is listed
			if DisplayServer.is_touchscreen_available():
				return ""
			return tr("On a computer, kid? Press Esc to pause the fight any time. The pause screen lists every key. Much easier than guessing.")
	return ""


## Gus's one-line garage tips (the bigger news gets a scene of its own, see unlock_scenes).
func garage_tip() -> String:
	# after your first loss: there's no shame in turning the difficulty down
	if losses >= 1 and tip_once("difficulty"):
		return tr("GUS: ") + tr("Lost one? Happens to the best of them. If the fights feel too hard, go to Menu > Settings > Difficulty and turn it down. No shame in it, kid.")
	if repair_all_cost() > 0 and unlocked("shop") and tip_once("repair"):
		return tr("GUS: ") + tr("Damage carries over between fights. Hit Repair all before the next one, or fix parts one by one.")
	return ""


## (Every section that used to have a one-line tip now has Gus's unlock scene instead, so there
## are none left: one explanation per thing, never two.)
const TAB_TIPS := {}


func tab_tip(tab: String) -> String:
	if TAB_FEATURES.has(tab):
		return ""   # Gus explains these in a scene the first time you open them
	if TAB_TIPS.has(tab) and tip_once("tab_" + tab):
		return tr(TAB_TIPS[tab]).replace("ECHO", robot_name)
	return ""




## One dig in the scrapyard. kind = "" digs anywhere (better odds of something good), or
## "head" / "torso" / "arm" / "leg" digs for that part - you get one, but it's mostly junk.
## A dig (1.53): nothing is guaranteed. dig_luck is the chance you find anything at all; it builds
## every day you leave the pile alone (DIG_LUCK_STEP a day, up to DIG_LUCK_MAX) and a dig spends it.
## Only a slice of it (DIG_RARE_SHARE) can be something rare: a chip, or a part a grade above yours.
## Digging for one kind of part halves your odds. What you do find is mostly junk.
func dig_scrap(kind: String = "") -> Dictionary:
	if digs_left <= 0:
		return {"text": "You've dug today. Come back tomorrow.", "part": ""}
	digs_left -= 1
	var chance := dig_luck * (DIG_KIND_K if kind != "" else 1.0)
	dig_luck = 0.0
	var roll := randf()
	if kind == "extras" and roll < chance:
		return dig_extras()
	if roll >= chance:
		var none := ["Nothing. An hour of digging and all you've got is rust under your nails.",
				"Nothing worth carrying home. The good stuff's been picked over.",
				"Gus pulls out a bent spoon and a dead rat. Not today, kid."]
		return {"text": tr(none[randi() % none.size()]), "part": "", "grade": "none"}
	# something turned up: the luckiest slice of the odds is something rare
	if roll < chance * DIG_RARE_SHARE:
		var free_chips: Array = chip_ids().filter(func(id): return not owned_chips.has(id))
		if kind == "" and not free_chips.is_empty() and randf() < 0.35:
			var lc: String = free_chips[randi() % free_chips.size()]
			owned_chips.append(lc)
			return {"text": tr("Lucky dig! A training chip, %s, and it still works. It's yours (see Chips).") % tr(Specials.MOVES[lc]["name"]), "part": "", "chip": lc, "grade": "chip"}
		var up := mini(5, my_grade() + 1)
		var lpool: Array = []
		for lid in ALL_PARTS:
			var ld: Dictionary = PARTS[lid]
			if ld["shop"] and int(ld.get("grade", 0)) == up and not UNDAMAGEABLE.has(ld["kind"]) and (kind == "" or ld["kind"] == kind):
				lpool.append(lid)
		if not lpool.is_empty():
			var lid2: String = lpool[randi() % lpool.size()]
			var luid := add_part(lid2, randf_range(0.2, 0.45))
			inst(luid)["dug"] = true
			return {"text": tr("Lucky dig! A %s, a grade above anything the dealer sells you. Battered, but it's ours (in Storage).") % part_def(lid2)["name"], "part": lid2, "grade": "rare", "uid": luid}
	var r := randf()
	var pool: Array = []
	var grade := "junk"
	if r < DIG_GOOD:
		grade = "good"
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["shop"] and int(d.get("grade", 0)) == 1 and d["cost"] >= 250 and not UNDAMAGEABLE.has(d["kind"]) and (kind == "" or d["kind"] == kind):
				pool.append(id)
	elif r < DIG_GOOD + DIG_DECENT:
		grade = "decent"
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["shop"] and int(d.get("grade", 0)) == 1 and d["cost"] <= 250 and not UNDAMAGEABLE.has(d["kind"]) and (kind == "" or d["kind"] == kind):
				pool.append(id)
	if pool.is_empty():
		grade = "junk"
		for k in STARTER_OPTIONS:
			if kind == "" or k == kind:
				pool += STARTER_OPTIONS[k]
	var id: String = pool[randi() % pool.size()]
	var dug_uid := add_part(id, randf_range(0.12, 0.45))
	inst(dug_uid)["dug"] = true   # shown on the Scrapyard screen; fight salvage only goes to Storage
	var name: String = part_def(id)["name"]
	match grade:
		"good":
			return {"text": tr("Jackpot! A %s, buried under a dead robot. Banged up, but it's real gear (in Storage).") % name, "part": id, "grade": grade, "uid": dug_uid}
		"decent":
			return {"text": tr("Found a %s. Dented, but decent (in Storage).") % name, "part": id, "grade": grade, "uid": dug_uid}
	var meh := ["More junk: a %s. Rusty, but it bolts on.", "A %s, half eaten by rust. Better than nothing.", "Dug out a %s. Gus says he's seen worse. Not much worse."]
	return {"text": (tr(meh[randi() % meh.size()]) % name) + tr(" (in Storage)"), "part": id, "grade": grade, "uid": dug_uid}


## Digging for extras (1.54): half the odds of a normal dig, and what turns up is power or a pad.
## Mostly a dead car battery, sometimes a real reactor, now and then a controller someone threw out.
func dig_extras() -> Dictionary:
	var r := randf()
	if r < 0.12:
		# any controller can turn up; one you already own is a spare to sell
		var all_c: Array = CONTROLLER_INFO.keys().filter(func(c): return int(CONTROLLER_INFO[c]["cost"]) > 0)
		var cid: String = all_c[randi() % all_c.size()]
		var cname := tr(PilotArt.CONTROLLER_NAMES.get(cid, cid))
		spare_controllers.append(cid)   # in Storage, like a part: keep it for your gear or sell it
		return {"text": tr("Under a pile of tyres, a controller: %s! Sticky buttons, but it works. It's in Storage.") % cname, "part": "", "grade": "controller", "controller": cid}
	var pool: Array = []
	if r < 0.45:
		for id in ALL_PARTS:
			var d: Dictionary = PARTS[id]
			if d["kind"] == "reactor" and d["shop"] and int(d.get("grade", 0)) == 1:
				pool.append(id)
	var id2: String = pool[randi() % pool.size()] if not pool.is_empty() else "junk_reactor"
	var uid := add_part(id2, 1.0)
	inst(uid)["dug"] = true
	if id2 == "junk_reactor":
		return {"text": tr("A car battery, still holding a charge. Better than nothing (in Storage)."), "part": id2, "grade": "junk", "uid": uid}
	return {"text": tr("A %s, buried under a dead robot and still humming (in Storage).") % part_def(id2)["name"], "part": id2, "grade": "good", "uid": uid}


## What a spare controller fetches: the same share as a part.
func controller_sell_value(id: String) -> int:
	return int(float(CONTROLLER_INFO.get(id, {}).get("cost", 0)) * SELL_SHARE / 10.0) * 10


## A controller from Storage onto your gear shelf (only if you don't have that one yet).
func take_controller(id: String) -> String:
	if not spare_controllers.has(id) or owned_controllers.has(id):
		return ""
	spare_controllers.erase(id)
	owned_controllers.append(id)
	return tr("The %s is on your gear shelf (BotMedia > Gear).") % tr(PilotArt.CONTROLLER_NAMES.get(id, id))


func sell_spare_controller(id: String) -> String:
	if not spare_controllers.has(id):
		return ""
	spare_controllers.erase(id)
	var v := controller_sell_value(id)
	book("sales", v)
	return tr("Sold the spare %s for $%d.") % [tr(PilotArt.CONTROLLER_NAMES.get(id, id)), v]


func buy_controller(id: String) -> String:
	var info: Dictionary = CONTROLLER_INFO[id]
	if owned_controllers.has(id):
		pilot_look["controller"] = id
		return tr("Your pilot picks up the %s.") % tr(PilotArt.CONTROLLER_NAMES[id])
	if money < int(info["cost"]):
		return tr("The %s costs $%d.") % [tr(PilotArt.CONTROLLER_NAMES[id]), info["cost"]]
	book("parts", -(int(info["cost"])))
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
	if k >= gantries:
		return "No gantry for it. Buy one first."
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
	book("repairs", -(c))
	var h := 0.0
	for slot in wingmen[k]:
		var p := inst(int(wingmen[k][slot]))
		if not p.is_empty() and repair_cost(p) > 0:
			h += queue_repair(p, repair_cost(p))
	return tr("%s is on the job board: $%d, about %s of work.") % [wingman_name(k), c, hours_text(h)]


## Hours of bay work to fix a backup robot.
func wingman_repair_hours(k: int) -> float:
	var h := 0.0
	for slot in wingmen[k]:
		var p := inst(int(wingmen[k][slot]))
		if not p.is_empty() and repair_cost(p) > 0:
			h += repair_hours(p)
	return h


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


# ---------------------------------------------------------------- Scrapyard Test Drive

## Gus's silly practice robots, built from scrapyard junk. He pilots them himself (badly, on purpose).
## junk = how they behave in the ring (see fight.gd junk_input).
const JUNKERS := {
	"fridge": {"name": "THE FRIDGE", "junk": "fridge", "body": "#e8ecef", "style": "tank",
		"desc": "Only ever blocks. Practise breaking a guard: hold PUNCH or KICK for a full charge.",
		"parts": {"head": "junk_head_box", "torso": "junk_torso_box", "arm_front": "junk_arm", "arm_back": "junk_arm", "leg_front": "junk_leg_thick", "leg_back": "junk_leg_thick"}},
	"toaster": {"name": "TOASTER TIM", "junk": "toaster", "body": "#c0c4c8", "style": "striker",
		"desc": "Throws one slow punch every couple of seconds. Practise blocking, then hitting back.",
		"parts": {"head": "junk_head_tv", "torso": "junk_torso_box", "arm_front": "junk_arm_piston", "arm_back": "junk_arm_piston", "leg_front": "junk_leg_wheel", "leg_back": "junk_leg_wheel"}},
	"mower": {"name": "LAWNMOWER LARRY", "junk": "mower", "body": "#3f9a3a", "style": "mechanic",
		"desc": "Wanders about the ring and bumps into things. Practise chasing and aiming at parts.",
		"parts": {"head": "junk_head_dome", "torso": "junk_torso_crate", "arm_front": "junk_arm_claw", "arm_back": "junk_arm_claw", "leg_front": "junk_leg_wheel", "leg_back": "junk_leg_wheel"}},
	"mop": {"name": "MOP BUCKET", "junk": "dummy", "body": "#e0c25a", "style": "tank",
		"desc": "Stands still and never breaks. Practise your combos and special moves.",
		"parts": {"head": "junk_head", "torso": "junk_torso", "arm_front": "junk_arm", "arm_back": "junk_arm", "leg_front": "junk_leg", "leg_back": "junk_leg"}},
}


## A Junker as an opponent robot.
func junker(id: String) -> Dictionary:
	var j: Dictionary = JUNKERS.get(id, JUNKERS["mop"])
	var parts: Dictionary = j["parts"].duplicate()
	parts["reactor"] = "junk_reactor"
	return {"name": tr(j["name"]), "pilot": "GUS", "junk": j["junk"], "hp": 1.0, "damage": 0.6, "speed": 0.7, "scale": 1.0,
			"think": 1.0, "block": 0.0, "smart": 0.0, "body": j["body"], "trim": "#555a60", "eye": "#ffb340",
			"parts": parts, "specials": [], "style": j["style"], "reward": 0}


## Your robot for a test drive: at full health (nothing that happens here sticks), with the part
## you're trying out bolted on in its slot.
func test_drive_spec() -> Dictionary:
	var eq := equipped.duplicate()
	var temp := -1
	var try_id := str(test_drive.get("try", ""))
	if try_id != "" and not part_def(try_id).is_empty():
		temp = add_part(try_id)
		eq[str(test_drive["slot"])] = temp
	var spec := player_spec(eq, robot_name)
	if temp >= 0:
		inventory.erase(inst(temp))
		next_uid -= 1
	spec["specials"] = active_chips()
	for slot in spec["parts"]:
		var p: Dictionary = spec["parts"][slot]
		if not p.is_empty():
			p["hp"] = p["max_hp"]
	return spec


func start_test_drive(junker_id: String, try_id: String = "", slot: String = "") -> void:
	test_drive = {"junker": junker_id, "try": try_id, "slot": slot}


## Set up a Quick Fight: two random robots of the same strength.
func start_quick_fight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var budget := exp(rng.randf_range(log(150.0), log(15000.0)))   # per part: any grade, Scrap to Steel, same for both
	var level := rng.randf_range(0.5, 3.0)
	quick = {"player": random_bot(rng, budget, level), "enemy": random_bot(rng, budget, level)}
	# sometimes a team fight: tag teams and swarms, on either side (or both)
	# mostly one on one: 1v1 six times in nine, two-robot fights twice, three-robot fights once
	var r := rng.randf() * 9.0
	var fmt: Array = [1, 1]
	if r >= 8.0:
		fmt = [[1, 3], [3, 1], [3, 3], [2, 3], [3, 2]][rng.randi() % 5]
	elif r >= 6.0:
		fmt = [[1, 2], [2, 1], [2, 2]][rng.randi() % 3]
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
	return opponent_spec_from(rival(index), 1.0)


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
				"trait": d["trait"], "trait_lv": d["trait_lv"], "gm": float(d.get("gm", 1.0))}
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
	var drawn := 0.0
	for slot in o["parts"]:
		if o["parts"][slot] != "":
			drawn += float(part_def(o["parts"][slot])["draw"])
	var eff := 1.0
	if o.has("power_share"):
		var used := 0.0
		for slot in o["parts"]:
			if o["parts"][slot] != "":
				used += part_def(o["parts"][slot])["draw"]
		eff = minf(1.0, float(o["power_share"]) / maxf(1.0, used))
	return {"name": o.get("bot_name", o["name"]), "parts": parts, "efficiency": eff, "damage_mult": o["damage"], "power": fight_tank(output, drawn),
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
					"color": p["color"], "health": clampf(p["hp"] / p["max_hp"], 0.0, 1.0),
					"grade": GameData.grade_of(str(p["id"])) if p.has("id") else 3, "swap": str(p.get("swap", ""))}
	for slot in spec.get("pods", {}):
		parts[slot] = {"alive": false, "shape": "pod", "pod": spec["pods"][slot]}
	return {"parts": parts, "trim": spec["trim"], "eye": spec["eye"], "scale": spec["scale"],
			"back": spec.get("back", {}), "stickers": spec.get("stickers", {})}


func player_look() -> Dictionary:
	return look_from_spec(player_spec())


# ---------------------------------------------------------------- fight results

## Called when a championship match ends.
## part_hp: slot -> remaining hp for the player's parts. destroyed: number of enemy parts ripped off.
## salvage_ids: enemy part ids that were ripped off (some may be salvaged).
func record_result(won: bool, part_hp: Dictionary, destroyed: int, salvage_ids: Array, team_hp: Array = [], own_rips: Dictionary = {}) -> Dictionary:
	var o := current_opponent()
	var base: int = current_reward()
	var reward: int = base if won else loss_pay(base)
	var forfeited := forfeit
	if fight_mode() != "test" and fight_mode() != "quick" and fight_mode() != "watch":
		Contracts.check_bell(robot_hp_ratio())
	if forfeit:
		reward = 0   # threw in the towel: no pay
		forfeit = false
	log_day((tr("Threw in the towel against %s.") if forfeited else (tr("Beat %s. $%d.") if won else tr("Lost to %s. $%d."))) % ([str(o.get("name", "?"))] if forfeited else [str(o.get("name", "?")), reward]),
			"good" if won else "bad")
	# dismantle bonus: every part you tore off pays $50, plus a tenth of what that part is worth
	var bonus := 0
	for sv in salvage_ids:
		bonus += dismantle_pay(str(sv.get("id", "")))
	if salvage_ids.is_empty():
		bonus = destroyed * 50
	var was_in_debt := money < 0
	book("fights", reward)
	book("salvage", bonus)
	fight_log.append({"y": year, "w": week, "d": day, "opp": str(o.get("name", "?")), "wid": int(o.get("wid", -1)), "won": won, "mode": fight_mode(), "title": fight_title(),
			"stage": str(event.get("stage", "")) if fight_mode() == "story" else ("cup" if fight_mode() == "circuit" else fight_mode())})
	if fight_log.size() > 400:
		fight_log.pop_front()
	emergent_talk(o, won)
	if is_tag():
		tag_after(won)

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
			if bool(own_rips.get(slot, randf() < 0.5)):
				# it came off whole: your crew dragged the wreck out of the ring, rebuild it for half price
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
			# parts that came off whole are yours (you saw them lying in the ring); shattered ones are scrap
			var whole: bool = bool(sv.get("intact", randf() < (0.75 if sv["aimed"] else 0.25)))
			if not whole and style == "specialist" and randf() < 0.15:
				whole = true   # specialists pick the bits up and make something of them
			if whole:
				add_part(sv["id"], 0.35 if sv["aimed"] else 0.2)
				cards.append({"id": sv["id"], "what": "salvaged", "health": 0.35 if sv["aimed"] else 0.2})
				salvaged.append(part_def(sv["id"])["name"] + (tr(" (aimed)") if sv["aimed"] else ""))
			else:
				cards.append({"id": sv["id"], "what": "shattered", "health": 0.0})

	# trophy: sometimes the beaten robot's crew hands over one of its parts
	var trophy := ""
	var trophy_id := ""
	# (only from parts still on their robot: nothing you tore off - each part exists once)
	var intact: Array = []
	for slot in o["parts"]:
		if o["parts"][slot] != "":
			intact.append(o["parts"][slot])
	for sv in salvage_ids:
		intact.erase(str(sv.get("id", "")))   # erase() removes one copy: two identical arms, one torn off -> one left
	if won and randf() < (0.15 if fight_mode() == "pickup" else 0.3) and not intact.is_empty():   # (1.53: pickups half as often)
		var id: String = intact[randi() % intact.size()]
		var d := part_def(id)
		add_part(id, 1.0 if UNDAMAGEABLE.has(d["kind"]) else 0.5)
		cards.append({"id": id, "what": "trophy", "health": 1.0 if UNDAMAGEABLE.has(d["kind"]) else 0.5})
		trophy = d["name"]
		trophy_id = id

	# the pilot you fought lives on: their robot keeps the dents, their wallet moves
	if o.has("wid"):
		var stage := "pickup"
		match fight_mode():
			"story":
				stage = str(event["stage"])
			"circuit":
				stage = "cup"
		World.after_player_fight(int(o["wid"]), won, last_enemy_hp, salvage_ids, stage)
		# the part their crew handed over is gone from their robot too
		var wp := World.pilot(int(o["wid"]))
		if trophy_id != "" and not wp.is_empty():
			for s in wp["bot"]["parts"]:
				if wp["bot"]["parts"][s] == trophy_id and s != "torso":
					var rng := RandomNumberGenerator.new()
					rng.randomize()
					World.lose_part(rng, wp, s)
					break
	# BotMedia and sponsors hear about it
	var social_stage := "pickup"
	match fight_mode():
		"story":
			social_stage = str(event.get("stage", rank))
		"circuit":
			social_stage = "cup"
	var intact_rips := salvage_ids.filter(func(sv): return bool(sv.get("intact", false))).size()
	Social.my_fight(o, won, destroyed, intact_rips, lost.size() + wrecked.size(), social_stage)
	var sponsor_pay := Contracts.after_fight(won, destroyed, forfeited)
	if sponsor_pay > 0:
		log_day(tr("Sponsors paid $%d.") % sponsor_pay, "good")
	style_locked = false         # a fight later, you may switch style again
	var was_champion := champion
	var mode := fight_mode()
	var cup_done := ""
	var event_done := ""
	var bet_result := {}
	pending_stories = pending_stories.filter(func(k): return typeof(k) == TYPE_DICTIONARY)   # keep the emergent talk
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
			if res["phase_changed"]:
				event_done = league_end(event)
			if event.get("trials", false) and not res["done"]:
				# the Open Trials: two wins and we're in, two losses and we're out
				var rec: Array = Career.trials_record(event, 0)
				var line := ""
				if int(rec[0]) >= 2:
					line = tr("That's two! We're in the Scrap League, kid. The Trials finish without us, the league starts in week 4.")
				elif int(rec[1]) >= 2:
					line = tr("Two losses. That's the Trials done for us. A year in the gutter, kid. We dig, we fight pickups, we come back stronger.")
				elif won:
					line = tr("One down. One more win next Saturday and we're in the Scrap League.")
				elif int(rec[0]) == 0:
					line = tr("Lost it. Shake it off: win the next two and we're still in.")
				else:
					line = tr("One each. Next Saturday decides it: win and we're in, lose and it's a year in the gutter.")
				pending_talk.append({"lines": [["GUS", line, {}]]})
			if res["done"]:
				event_done = finish_title(event) if event.get("stage", "") == "title" else finish_event(event)
				if event.get("stage", "") == "open":
					build_scrap()
			sync_event()
			end_fight_night()
		"circuit":
			Career.after_player_fight(circuit, won, destroyed)
			bet_result = settle_bets("cup", circuit)
			if circuit["phase"] == "done":
				cup_done = finish_cup()
			end_fight_night()   # Wednesday's done: Thursday's next
		"exhibition", "pickup":
			bet_result = settle_self_bets(won)
			end_fight_night()
	exhibition = false
	pickup = {}
	scout = {}
	last_result = {"won": won, "reward": reward, "bonus": bonus, "opponent": o["name"], "lost": lost, "wrecked": wrecked,
			"salvaged": salvaged, "champion": champion and not was_champion,
			"trophy": trophy, "cup_done": cup_done, "event_done": event_done, "out_of_debt": was_in_debt and money >= 0, "cards": cards, "bets": bet_result}
	save_game()
	return last_result


# ---------------------------------------------------------------- championships (after the story)

## What tearing one part off the other robot pays: $50, plus 10% of the part's price.
func dismantle_pay(id: String) -> int:
	return 50 + int(float(part_def(id).get("cost", 0)) * 0.1) if id != "" else 50


## A trophy for the bay wall, with when you won it and the fights that got you there.
## The office wall: your dad's three, then yours.
func wall_trophies() -> Array:
	return DAD_TROPHIES + trophies


func trophy_record(ev: Dictionary, kind: String, medal: int) -> Dictionary:
	var fights: Array = []
	var wk: Array = ev.get("weeks", [])
	for e in fight_log:
		if int(e["y"]) == int(ev.get("year", year)) and wk.has(int(e["w"])) and (e["mode"] == "story" or e["mode"] == "circuit"):
			fights.append({"opp": e["opp"], "won": e["won"], "w": int(e["w"])})
	return {"kind": kind, "medal": medal, "name": ev["name"], "year": year, "week": week, "fights": fights}


## Your division's table is final (round 24): medals and prize money for the top 3 (4th gets
## money only), and whether you're up, down, safe, or into a playoff.
func league_end(ev: Dictionary) -> String:
	var info: Dictionary = Career.STAGES[ev["stage"]]
	var m := Career.medal_of(ev, 0)
	var pos := Career.standings(ev).find(0)
	var text := tr("%s: %s") % [tr(str(ev["name"])), Career.finish_text(ev)]
	Social.podium(ev, "league")
	if m > 0:
		Contracts.podium(m)
		var prize: int = info["prizes"][m - 1]
		book("prizes", prize)
		trophies.append(trophy_record(ev, ev["stage"], m))
		text += tr(". Prize $%d and a trophy for the office wall!") % prize
	elif pos == 3:
		book("prizes", Career.fourth_prize(ev["stage"]))
		text += tr(". Fourth place pays $%d.") % Career.fourth_prize(ev["stage"])
	else:
		text += "."
	var steel: bool = ev["stage"] == "steel"
	match Career.zone(ev, pos):
		"up":
			if steel:
				text += " " + tr("Into the Titanium Championship!")
			else:
				text += " " + tr("Straight up to the %s!") % tr(Career.STAGES[Career.ORDER[Career.ORDER.find(str(ev["stage"])) + 1]]["name"])
		"up_po":
			text += " " + (tr("Into the title playoff: three more get into the Championship.") if steel else tr("Into the promotion playoff: three more go up."))
		"down_po":
			text += " " + tr("Into the relegation playoff: three more go down.")
		"down":
			text += " " + tr("Relegated.")
	return text


## Your division's year is over (playoffs included): where you'll be next year.
const NEWCOMER_MONTHS := 1.5
## What a league pays a pilot coming up into it: NEWCOMER_MONTHS of its running costs (the gutter's
## Trials winners get the Scrap League's).
func promotion_grant(to_rank: String) -> int:
	return int(int(settings.get("living_cost", LIVING_COST)) * float(RUNNING.get(to_rank, 1.0)) * NEWCOMER_MONTHS / 10.0) * 10


func finish_event(ev: Dictionary) -> String:
	var idx := Career.ORDER.find(str(ev["stage"]))
	var text := ""
	if ev["stage"] == "steel" and ev.get("promoted", []).has(0):
		text = tr("We're in the Titanium Championship! Next year, on the open dates.")
		pending_stories.append("title_in")
	elif ev.get("promoted", []).has(0) and idx < Career.ORDER.size() - 1:
		rank = Career.ORDER[idx + 1]
		text = tr("Promoted to the %s!") % tr(Career.STAGES[rank]["name"])
		# (1.82) the league pays its newcomers a settling-in purse: the robot has to catch up a grade
		var grant := promotion_grant(rank)
		if grant > 0:
			book("prizes", grant)
			text += " " + tr("The league's newcomer purse: +$%d.") % grant
		pending_stories.append("up_" + rank)
		Social.st()["promo"] = {"to": rank, "aw": abs_week()}   # (1.87) a moment to post about
		make_offers()
	elif ev.get("relegated", []).has(0) and idx > 0:
		rank = Career.ORDER[idx - 1]
		if rank == "open":
			text = tr("Out of the leagues. Next year it's pickups, cups, and the Open Trials.")
			pending_stories.append("down_open")
		else:
			text = tr("Relegated to the %s.") % tr(Career.STAGES[rank]["name"])
			pending_stories.append("down")
	else:
		text = tr("Another year in the %s.") % tr(str(ev["name"]))
		pending_stories.append("stay_" + str(ev["stage"]))
	return text


## The Titanium Championship is over: medals, prize money, and the title.
func finish_title(ev: Dictionary) -> String:
	var info: Dictionary = Career.STAGES["title"]
	var m := Career.medal_of(ev, 0)
	var text := tr("%s: %s") % [tr(str(ev["name"])), Career.finish_text(ev)]
	Social.podium(ev, "title")
	if m > 0:
		Contracts.podium(m)
		var prize: int = info["prizes"][m - 1]
		book("prizes", prize)
		trophies.append(trophy_record(ev, "title", m))
		text += tr(". Prize $%d and a trophy for the office wall!") % prize
	if m == 1:
		if not champion:
			pending_stories.append("post_9")
		champion = true
		make_offers()
	else:
		pending_stories.append("title_out")
	sync_event()
	return text


func finish_cup() -> String:
	var m := Career.medal_of(circuit, 0)
	var text := tr("%s: %s") % [circuit["name"], Career.finish_text(circuit)]
	Social.podium(circuit, "cup")
	if m > 0:
		var prize: int = int(int(circuit["prize"]) * [0, 1.0, 0.5, 0.3][m])
		book("prizes", prize)
		trophies.append(trophy_record(circuit, "cup", m))
		text += tr(", $%d") % prize
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
	var base := clampi(rank_index() + int(circuits_won / 2.0) + (1 if champion else 0), 1, 5)
	for k in 3:
		var tier := clampi(base - 1 + k, 1, 5)
		var seed := randi()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		circuit_offers.append({"name": CIRCUIT_NAMES[rng.randi() % CIRCUIT_NAMES.size()], "tier": tier,
				"seed": seed, "prize": CUP_PRIZE[clampi(tier - 1, 0, CUP_PRIZE.size() - 1)]})


## A cup takes 3 Wednesdays, starting next week. Leagues are on Saturdays, so the two never clash -
## it just has to finish before the year ends.
## Cups run between the open dates and the playoffs (weeks 4 to 50).
func cup_fits() -> bool:
	return cup_start_week() >= Career.LEAGUE_START and cup_start_week() + 2 <= Career.PLAYOFF_SLOTS[0][0] - 1


func cup_start_week() -> int:
	return week if day_index() <= 2 else week + 1


func enter_circuit(k: int) -> void:
	var off: Dictionary = circuit_offers[k]
	circuit = Career.new_cup(off["name"], int(off["tier"]), int(off["seed"]), cup_start_week(), year, int(off["prize"]))
	circuit_offers.remove_at(k)
	if day == "wed":
		# entered on a Wednesday: round one is tonight, instead of the pickup fight (earlier in the week: it's this Wednesday)
		refund_self_bets()
		pickup = {}


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


## Since 1.41 parts are tougher (fights last 1-2 minutes): torsos x3, heads, arms and legs x2.
## Repairs are priced and timed by the share of health missing, so the economy doesn't move.
const HP_MULT := {"torso": 3.0, "head": 2.0, "arm": 2.0, "leg": 2.0}


static func hp_mult(kind: String) -> float:
	return float(HP_MULT.get(kind, 1.0))


## The old catalog spread prices from $150 to $4,200 for parts that were only 2-3x better.
## Inside one grade the spread is squeezed (about $150 to $600 at Scrap grade): the grade is what costs.
static func grade_one_price(c: int) -> int:
	if c <= 150:
		return c
	return int(150.0 * pow(c / 150.0, 0.42) / 10.0) * 10


## The Pecking Order (Settings): how much tougher and harder hitting each grade is.
func pecking_k() -> float:
	return float(PECKING[clampi(int(settings.get("pecking", 1)), 0, PECKING.size() - 1)]["k"])


## HP and hit-damage multiplier of a grade (grade 1 = Scrap = x1).
func grade_mult(g: int) -> float:
	return pow(pecking_k(), maxi(0, g - 1))


func grade_of(id: String) -> int:
	return int(part_def(id).get("grade", 0))


## Same design, another grade ("" if the part has no grades: junk).
func graded_id(id: String, g: int) -> String:
	var d := part_def(id)
	if d.is_empty() or int(d.get("grade", 0)) == 0:
		return id
	var base: String = str(d.get("grade_base", id))
	var out := base if g <= 1 else "%s^%d" % [base, clampi(g, 2, GRADES.size() - 1)]
	return out if PARTS.has(out) else id


## Grades 2-5 of every part that costs something (salvage-only parts too, so rivals can carry them).
func build_grades() -> void:
	var base_ids := ALL_PARTS.duplicate()
	for id in base_ids:
		var d: Dictionary = PARTS[id]
		if int(d["cost"]) <= 0 or d.get("custom", false):
			d["grade"] = 0
			d["gm"] = 1.0
			continue
		d["grade"] = 1
		d["gm"] = 1.0
		d["hp_base"] = d["hp"]
		d["out_base"] = d["output"]
		for g in range(2, GRADES.size()):
			var v := d.duplicate(true)
			v["id"] = "%s^%d" % [id, g]
			v["grade"] = g
			v["grade_base"] = id
			v["cost"] = int(d["cost"] * pow(GRADE_PRICE, g - 1) / 10.0) * 10
			v["output"] = int(round(d["output"] * (1.0 + 0.2 * (g - 1))))
			PARTS[v["id"]] = v
			ALL_PARTS.append(v["id"])
	apply_pecking()


## (Re)apply the Pecking Order to every graded part. Parts you own keep their health ratio.
func apply_pecking() -> void:
	var ratios := {}
	for p in inventory:
		ratios[p["uid"]] = hp_ratio(p) if PARTS.has(p["id"]) else 1.0
	for id in PARTS:
		var d: Dictionary = PARTS[id]
		var g := int(d.get("grade", 0))
		if g < 1:
			continue
		var base: Dictionary = PARTS[str(d.get("grade_base", id))]
		var m := grade_mult(g)
		d["gm"] = m
		if g > 1:
			d["hp"] = maxi(1, int(round(float(base["hp_base"]) * m)))
	for p in inventory:
		if PARTS.has(p["id"]):
			p["hp"] = float(part_def(p["id"])["hp"]) * float(ratios.get(p["uid"], 1.0))


func set_pecking(k: int) -> void:
	settings["pecking"] = clampi(k, 0, PECKING.size() - 1)
	apply_pecking()


## A part's name with its grade ("Iron Piston Arm"). Scrap grade and junk show the plain name.
func grade_name(g: int) -> String:
	return I18n.t(GRADES[clampi(g, 0, GRADES.size() - 1)])


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
	v["cost_v5"] = int(int(d.get("cost_v5", d["cost"])) * float(m["cost"]))
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
	var hp_step: int = int(CUSTOM_STEP["hp"] * (2 if kind == "torso" else 1) * hp_mult(kind))
	var shape: String = cfg["shape"]
	if kind == "arm" and cfg["gadget"] == "rocket_fist":
		shape = "rocket"
	elif kind == "arm" and cfg["gadget"] == "grapple":
		shape = "grapple"
	var d := {
		"id": "", "kind": kind, "name": cfg.get("name", ""), "cost": custom_price(cfg), "shop": false, "custom": true,
		"hp": int(info["base_hp"] * hp_mult(kind)) + alloc.get("hp", 0) * hp_step,
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
	# made in your league's grade
	var g := my_grade()
	d["grade"] = g
	d["gm"] = grade_mult(g)
	d["hp_base"] = d["hp"]
	d["hp"] = maxi(1, int(round(d["hp"] * grade_mult(g))))
	if g > 1:
		d["name"] = I18n.t("{grade} {name}").format({"grade": grade_name(g), "name": d["name"]})
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
	var base := 60 + custom_points_used(cfg) * CUSTOM_POINT_PRICE + (CUSTOM_GADGET_PRICE if cfg["gadget"] != "" else 0)
	return int(base * pow(GRADE_PRICE, my_grade() - 1) / 10.0) * 10


func forge_custom(cfg: Dictionary) -> String:
	var d := custom_def(cfg)
	if money < d["cost"]:
		return tr("Not enough money. This design costs $%d.") % d["cost"]
	book("parts", -(d["cost"]))
	d["id"] = "custom_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	custom_parts.append(d)
	PARTS[d["id"]] = d
	var uid := add_part(d["id"])
	for slot in SLOTS:
		if SLOT_KIND[slot] == d["kind"] and equipped[slot] == -1:
			equipped[slot] = uid
			return tr("Forged %s and fitted it to the %s!") % [d["name"], tr(SLOT_NAMES[slot])]
	return tr("Forged %s! It's in your Storage, fit it from there.") % d["name"]


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
	return "Random build assembled!" + ("" if best_over <= 0 else " (It's overloaded. You need a bigger reactor for this one.)")


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


## (1.79) Your own save in a slot (Menu > Save game), kept apart from the autosave that's written
## after every change. Loading it rolls the slot back to that moment.
static func mine_path(slot: int) -> String:
	return "user://save_%d_mine.json" % slot


func has_mine(slot: int = -1) -> bool:
	return FileAccess.file_exists(mine_path(save_slot if slot < 0 else slot))


func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(save_slot if slot < 0 else slot))


func any_save() -> bool:
	for k in range(1, SAVE_SLOTS + 1):
		if has_save(k):
			return true
	return false


## Short description of a save file for the save-slot screen ({} if empty).
func slot_info(slot: int, mine: bool = false) -> Dictionary:
	if not (has_mine(slot) if mine else has_save(slot)):
		return {}
	var f := FileAccess.open(mine_path(slot) if mine else slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	var progress := "Champion" if data.get("champion", false) else tr("Year %d, week %d") % [int(data.get("year", 1)), int(data.get("week", 1))]
	if data.has("event") and typeof(data["event"]) == TYPE_DICTIONARY and not data["event"].is_empty() and not data.get("champion", false):
		progress += " · " + str(Career.STAGES.get(str(data["event"].get("stage", "")), {}).get("short", "")).capitalize()
	return {"pilot": data.get("pilot_name", "Rook"), "robot": data.get("robot_name", DEFAULT_ROBOT), "progress": progress,
			"money": int(data.get("money", 0)), "saved": data.get("saved_at", ""),
			"cups": int(data.get("circuits_won", 0))}


## Move a save from the old single-file version into slot 1.
func migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not has_save(1):
		DirAccess.rename_absolute(OLD_SAVE_PATH, slot_path(1))


## Save your own copy (the autosave goes on as always).
func save_mine() -> bool:
	return save_game(mine_path(save_slot))


func save_game(path: String = "") -> bool:
	PlayLog.flush()
	var data := {
		"version": SAVE_VERSION, "pilot_name": pilot_name, "robot_name": robot_name,
		"saved_at": Time.get_datetime_string_from_system(false, true), "money": money, "inventory": inventory, "equipped": equipped,
		"next_uid": next_uid, "gantries": gantries, "bay_level": bay_level, "phase": phase, "jobs": jobs, "bolted": bolted, "mechanics": mechanics, "overtime": overtime, "paint": paint, "fight_index": fight_index, "wins": wins,
		"losses": losses, "champion": champion, "story_seen": story_seen,
		"owned_chips": owned_chips, "chips": chips, "circuit": circuit, "circuit_offers": circuit_offers,
		"circuits_won": circuits_won, "pickup": pickup, "setups": setups, "custom_parts": custom_parts,
		"year": year, "week": week, "day": day, "rank": rank, "event": {}, "leagues": leagues, "title_seeds": title_seeds, "trophies": trophies, "career_stats": career_stats,
		"pecking_k": pecking_k(), "style": style, "style_locked": style_locked, "shop_stock": shop_stock, "chip_stock": chip_stock, "scout": scout, "wingmen": wingmen, "sending": sending, "pilot_look": pilot_look, "owned_controllers": owned_controllers, "spare_controllers": spare_controllers, "tips_seen": tips_seen, "tips_log": tips_log, "h2h": h2h, "rivals": rivals, "rel": rel, "nemeses": nemeses, "pending_talk": pending_talk, "inbox": inbox, "inbox_seen": inbox_seen, "social": social, "pilot_at": pilot_at, "places_been": places_been, "pilot_used": pilot_used, "film_index": film_index, "film_pending": film_pending, "films_seen": films_seen, "contracts": contracts, "alerts_unseen": alerts_unseen, "day_log": day_log, "ledger": ledger, "bet_log": bet_log, "patched_week": patched_week, "loan": loan, "gus_alerts": gus_alerts, "tour": tour, "streak": streak, "pub_seen": pub_seen, "digs_left": digs_left, "dig_luck": dig_luck, "bills_note": bills_note, "fight_log": fight_log, "bets": bets, "world": world,
	}
	var f := FileAccess.open(slot_path(save_slot) if path == "" else path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	if clips_dirty:
		# (1.75) clips live in their own file too, written only when they change
		var cfw := FileAccess.open(clips_path(), FileAccess.WRITE)
		if cfw != null:
			cfw.store_string(JSON.stringify(clips))
			clips_dirty = false
	if films_dirty:
		# (1.75) whole filmed fights are big: their own file, written only when one is added
		var ff := FileAccess.open(films_path(), FileAccess.WRITE)
		if ff != null:
			ff.store_string(JSON.stringify(films))
			films_dirty = false
	return true


## Returns "" on success, or an error message.
func load_game(slot: int = -1, mine: bool = false) -> String:
	if slot > 0:
		save_slot = slot
	if not (has_mine() if mine else has_save()):
		return "No save file."
	var f := FileAccess.open(mine_path(save_slot) if mine else slot_path(save_slot), FileAccess.READ)
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
		if int(data.get("version", 1)) < 7:
			cd["hp"] = int(round(cd["hp"] * hp_mult(str(cd["kind"]))))
			if cd.has("hp_base"):
				cd["hp_base"] = int(round(float(cd["hp_base"]) * hp_mult(str(cd["kind"]))))
		custom_parts.append(cd)
		PARTS[cd["id"]] = cd
	inventory = []
	for p in data.get("inventory", []):
		if not part_def(str(p.get("id", ""))).is_empty():
			inventory.append({"uid": int(p["uid"]), "id": str(p["id"]), "hp": float(p["hp"])})
			if bool(p.get("dug", false)):
				inventory[inventory.size() - 1]["dug"] = true
	var save_v := int(data.get("version", 1))
	if save_v < 7:
		# 1.41: parts got tougher (torso x3, head/arms/legs x2); every part keeps its health ratio
		for p in inventory:
			var pd := part_def(str(p["id"]))
			p["hp"] = float(p["hp"]) * hp_mult(str(pd.get("kind", "")))
	if save_v < 6:
		# before grades: every part gets the grade its old price fits, and keeps its health ratio
		for p in inventory:
			var nid := v5_graded(str(p["id"]))
			if nid != p["id"]:
				p["hp"] = float(p["hp"]) * grade_mult(grade_of(nid))
				p["id"] = nid
	elif absf(float(data.get("pecking_k", pecking_k())) - pecking_k()) > 0.001:
		# saved under another Pecking Order: same health ratio, new numbers
		var old_k := float(data.get("pecking_k", pecking_k()))
		for p in inventory:
			var g := grade_of(str(p["id"]))
			if g > 1:
				p["hp"] = float(p["hp"]) * grade_mult(g) / pow(old_k, g - 1)
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
	style_locked = bool(data.get("style_locked", false))
	sending = int(data.get("sending", -1))
	pilot_look = DEFAULT_PILOT_LOOK.duplicate()
	if typeof(data.get("pilot_look")) == TYPE_DICTIONARY:
		pilot_look.merge(data["pilot_look"], true)
	pilot_look = PilotArt.normalize(pilot_look)
	tips_seen = data.get("tips_seen", []).duplicate()
	tips_log = data.get("tips_log", []).duplicate()
	h2h = data.get("h2h", {})
	rivals = data.get("rivals", []).map(func(x): return int(x))
	rel = data.get("rel", {})
	nemeses = data.get("nemeses", []).map(func(x): return int(x))
	if not data.has("rel"):
		# (1.58) the old grudges [yours, theirs] become one number: 3 + 3 = -84
		for key in data.get("grudge", {}):
			var g = data["grudge"][key]
			if str(key).begins_with("_") or typeof(g) != TYPE_ARRAY:
				continue
			var v := -14.0 * (float(g[0]) + float(g[1]))
			if v <= -1.0:
				rel[str(key)] = maxf(-100.0, v)
	pending_talk = data.get("pending_talk", [])
	day_log = data.get("day_log", {})
	ledger = data.get("ledger", [])
	bet_log = data.get("bet_log", [])
	patched_week = int(data.get("patched_week", -1))
	loan = data.get("loan", {})
	gus_alerts = data.get("gus_alerts", [])
	inbox = []
	for e in data.get("inbox", []):
		if typeof(e) == TYPE_DICTIONARY:
			e["y"] = int(e.get("y", 1))
			e["w"] = int(e.get("w", 1))
			e["ph"] = int(e.get("ph", 0))
			inbox.append(e)
	inbox_seen = mini(int(data.get("inbox_seen", inbox.size())), inbox.size())
	social = data.get("social", {})
	clips = {}
	if data.has("clips"):
		clips = data["clips"]   # (a 1.74 save kept them inside; from 1.75 they have their own file)
		clips_dirty = true
	else:
		var cf := FileAccess.open(clips_path(), FileAccess.READ)
		if cf != null:
			var cd0 = JSON.parse_string(cf.get_as_text())
			if typeof(cd0) == TYPE_DICTIONARY:
				clips = cd0
		clips_dirty = false
	pilot_at = str(data.get("pilot_at", "home"))
	places_been = data.get("places_been", ["home"])
	pilot_used = float(data.get("pilot_used", 0.0))
	film_index = data.get("film_index", {})
	film_pending = data.get("film_pending", [])
	films_seen = data.get("films_seen", [])
	films = {}
	var fl := FileAccess.open(films_path(), FileAccess.READ)
	if fl != null:
		var fd = JSON.parse_string(fl.get_as_text())
		if typeof(fd) == TYPE_DICTIONARY:
			films = fd
	films_dirty = false
	contracts = data.get("contracts", {})
	alerts_unseen = int(data.get("alerts_unseen", 0))
	tour = int(data.get("tour", -1))
	streak = int(data.get("streak", 0))
	pub_seen = str(data.get("pub_seen", ""))
	digs_left = int(data.get("digs_left", DIGS_PER_FIGHT))
	dig_luck = float(data.get("dig_luck", 0.0))
	bills_note = int(data.get("bills_note", 0))
	bets = []
	for b in data.get("bets", []):
		if typeof(b) == TYPE_DICTIONARY:
			bets.append({"on": str(b["on"]), "round": int(b["round"]), "pick": int(b["pick"]), "vs": int(b["vs"]),
					"stake": int(b["stake"]), "odds": float(b["odds"])})
	fight_log = []
	for e in data.get("fight_log", []):
		if typeof(e) == TYPE_DICTIONARY:
			fight_log.append({"y": int(e.get("y", 1)), "w": int(e.get("w", 1)), "d": str(e.get("d", "sat")), "opp": str(e.get("opp", "?")), "won": bool(e.get("won", false)),
					"mode": str(e.get("mode", "")), "stage": str(e.get("stage", "")), "title": str(e.get("title", ""))})
	spare_controllers = []
	for c in data.get("spare_controllers", []):
		if CONTROLLER_INFO.has(str(c)):
			spare_controllers.append(str(c))
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
	gantries = clampi(int(data.get("gantries", -1)), -1, wingmen.size())
	bay_level = clampi(int(data.get("bay_level", 0)), 0, BAY_LEVELS)
	if gantries < 0:   # a save from before gantries: every backup you'd built already has one
		gantries = 0
		for k in wingmen.size():
			if not wingmen[k].is_empty():
				gantries = k + 1
	phase = clampi(int(data.get("phase", 0)), 0, 2)
	mechanics = int(data.get("mechanics", 0))
	overtime = bool(data.get("overtime", false))
	if typeof(data.get("bolted")) == TYPE_DICTIONARY:
		bolted = {}
		for r in data["bolted"]:
			bolted[str(r)] = {}
			for sl in data["bolted"][r]:
				bolted[str(r)][str(sl)] = int(data["bolted"][r][sl])
		jobs = []
		for j in data.get("jobs", []):
			if typeof(j) == TYPE_DICTIONARY:
				jobs.append({"kind": str(j["kind"]), "uid": int(j["uid"]), "robot": str(j.get("robot", "")), "slot": str(j.get("slot", "")),
						"total": float(j["total"]), "done": float(j["done"]), "rush": bool(j.get("rush", false)),
						"start": float(j.get("start", 0.0)), "to": float(j.get("to", 0.0)), "applied": float(j.get("applied", 0.0)),
						"paid": int(j.get("paid", 0))})
				if int(data.get("version", 1)) < 7 and str(j["kind"]) == "repair" and not inst(int(j["uid"])).is_empty():
					var hm := hp_mult(str(part_def(str(inst(int(j["uid"]))["id"])).get("kind", "")))
					jobs[-1]["start"] = float(jobs[-1]["start"]) * hm
					jobs[-1]["to"] = float(jobs[-1]["to"]) * hm
		sync_swaps()
	else:
		bolt_everything()   # a save from before time in the bay: everything's on and fixed as it was
	if not Catalog.STYLES.has(style):
		style = "striker"
	shop_stock = data.get("shop_stock", []).filter(func(id): return PARTS.has(id))
	chip_stock = data.get("chip_stock", []).filter(func(id): return Specials.MOVES.has(id) and not owned_chips.has(id))
	if shop_stock.is_empty():
		roll_stock()
	scout = data.get("scout", {})
	circuit = data.get("circuit", {})
	if not circuit.is_empty() and not circuit.has("pilots"):
		circuit = {}   # an old-style cup: start fresh
	if not circuit.is_empty() and circuit.get("phase", "") != "done" and Career.week_of_round(circuit) < week:
		# a cup from before Wednesday nights: its next round moves to this week
		var shift := week - Career.week_of_round(circuit)
		for i in circuit["weeks"].size():
			circuit["weeks"][i] = int(circuit["weeks"][i]) + shift
	circuit_offers = data.get("circuit_offers", [])
	circuits_won = int(data.get("circuits_won", 0))
	pickup = data.get("pickup", {})
	if pickup.has("wid"):
		pickup["wid"] = int(pickup["wid"])
	trophies = data.get("trophies", [])
	career_stats = {"heads": 0, "arms": 0, "legs": 0, "cores": 0, "parts": 0}
	if typeof(data.get("career_stats")) == TYPE_DICTIONARY:
		career_stats.merge(data["career_stats"], true)
	var old_career: bool = int(data.get("version", 1)) < 5 or not data.has("leagues")
	if data.has("event"):
		year = int(data.get("year", 1))
		week = int(data.get("week", 1))
		day = str(data.get("day", "mon"))
		if not DAYS.has(day):
			day = "mon"
		rank = str(data.get("rank", "scrap"))
	else:
		year = 1
		rank = "scrap" if fight_index < 3 else ("rust" if fight_index < 6 else "iron")
	_fix_numbers(circuit)
	migrate_unlock_scenes()
	if old_career:
		# a save from before the year-round tables: you keep your robot, parts, money and story,
		# and a new year starts in the division you'd reached (with a fresh Port Ferrum around you)
		# the old league names: Qualifiers / Scrap Heap / Regional / Championship (or before that,
		# the one-year career) become Scrap / Rust / Iron / Steel
		var v := int(data.get("version", 1))
		if v == 4:
			rank = {"open": "open", "qualifiers": "scrap", "scrap": "rust", "regional": "iron", "championship": "steel"}.get(rank, "scrap")
		else:
			rank = {"scrap": "scrap", "regional": "rust", "championship": "iron"}.get(rank, "scrap")
		if champion:
			rank = "steel"
		if not Career.ORDER.has(rank):
			rank = "scrap"
		title_seeds = []
		for bt in bets:
			money += int(bt.get("stake", 0))
		bets = []
		circuit = {}
		pickup = {}
		watching = {}
		week = 1
		day = "mon"
		start_year()
		converted_note = true
	else:
		if typeof(data.get("world")) == TYPE_DICTIONARY and not (data["world"] as Dictionary).get("pilots", {}).is_empty():
			world = data["world"]
			_fix_world()
		leagues = data.get("leagues", {})
		for st in leagues:
			_fix_numbers(leagues[st])
		if save_v < 6:
			for p in world.get("pilots", {}).values():
				_v5_bot(p.get("bot", {}))
			for st in leagues:
				for e in leagues[st].get("pilots", []):
					_v5_bot(e.get("bot", {}))
			for e in circuit.get("pilots", []):
				_v5_bot(e.get("bot", {}))
			_v5_bot(pickup.get("enemy", {}))
			roll_stock()
		title_seeds = data.get("title_seeds", [])
		sync_event()
		if leagues.is_empty():
			start_year()
	# (an older save keeps the fresh world new_game() made)
	var saved_setups: Array = data.get("setups", [])
	for k in mini(saved_setups.size(), SETUP_SLOTS):
		setups[k] = saved_setups[k]
	if champion and circuit.is_empty() and circuit_offers.is_empty():
		make_offers()
	if mine:
		save_game()   # the slot rolls back to your save: the autosave follows
	return ""


## A part id from before grades -> the same design in the grade its old price fits.
func v5_graded(id: String) -> String:
	var d := part_def(id)
	if d.is_empty() or int(d.get("grade", 0)) != 1:
		return id
	var c := int(d.get("cost_v5", d["cost"]))
	var g := 1 if c < 400 else (2 if c < 1200 else (3 if c < 3000 else 4))
	return graded_id(id, g)


func _v5_bot(bot: Dictionary) -> void:
	for slot in bot.get("parts", {}).keys():
		bot["parts"][slot] = v5_graded(str(bot["parts"][slot]))
	for b in bot.get("team", []):
		_v5_bot(b)


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
	for k in ["round", "year", "seed", "tier", "prize", "po_round"]:
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
		for fp in ["user://films_%d.json" % (save_slot if slot < 0 else slot), "user://clips_%d.json" % (save_slot if slot < 0 else slot), mine_path(save_slot if slot < 0 else slot)]:
			if FileAccess.file_exists(fp):
				DirAccess.remove_absolute(fp)


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
	UI.set_text_level(int(settings["text"]))
	apply_look()
	apply_performance()
	apply_pecking()


## Settings > Robot look: the new lit style or the old flat one (only while the restyle is under way).
func apply_look() -> void:
	RobotArt.classic = false   # (1.62) the Classic look switch is gone: the art restyle is done


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
		if d.has("variant_of") and PARTS.has(d["variant_of"]) and not d.has("grade_base"):
			d["name"] = "%s %s" % [I18n.t(str(d["size_prefix"])), PARTS[d["variant_of"]]["name"]]
	for id in PARTS:
		var d: Dictionary = PARTS[id]
		if d.has("grade_base") and PARTS.has(d["grade_base"]):
			d["name"] = I18n.t("{grade} {name}").format({"grade": grade_name(int(d["grade"])), "name": PARTS[d["grade_base"]]["name"]})


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
		settings["pecking"] = clampi(int(settings.get("pecking", 1)), 0, PECKING.size() - 1)
		settings["start_money"] = int(settings["start_money"])
		settings["living_cost"] = int(settings["living_cost"])
		settings["coaching"] = int(settings["coaching"])
		settings["lang"] = str(settings.get("lang", "en"))
		settings["text"] = clampi(int(settings.get("text", UI.TEXT_DEFAULT)), 0, UI.TEXT_LEVELS.size() - 1)
		UI.set_text_level(settings["text"])
		apply_look()
		if typeof(settings["layout"]) != TYPE_DICTIONARY:
			settings["layout"] = {}
		# settings from before 1.37: team fights now start with every robot on one pad
		if int(data.get("rev", 1)) < 2:
			settings["team_controls"] = "linked"
		# settings from before 1.40: the fight buttons changed (JUMP took GRAB's spot), so old layouts reset once
		if int(data.get("rev", 1)) < 3:
			settings["layout"] = {}
		settings["rev"] = 3


# ---------------------------------------------------------------- clips (1.74)

## A fight's best moments (fight.rec_cut): they wait, marked temp, for the post about it. A new
## fight's clips replace the last fight's unposted ones; a posted clip is kept for good.
func add_fresh_clips(list: Array) -> void:
	for id in clips.keys():
		if clips[id].get("temp", false):
			clips.erase(id)
	var n := 0
	for c in list:
		var cl: Dictionary = c
		n += 1
		cl["id"] = "c%d_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000, n]
		cl["temp"] = true
		clips[cl["id"]] = cl
	clips_dirty = true


func fresh_clip_ids() -> Array:
	var out: Array = []
	for id in clips:
		if clips[id].get("temp", false):
			out.append(id)
	out.sort_custom(func(a, b): return float(clips[a].get("score", 0.0)) > float(clips[b].get("score", 0.0)))
	return out


func clip(id: String) -> Dictionary:
	return clips.get(id, {})


func keep_clip(id: String) -> void:
	if clips.has(id):
		clips[id].erase("temp")
		clips_dirty = true


# ---------------------------------------------------------------- filmed fights (1.75)
# Fights between computer pilots are decided on the books (Career.simulate). The interesting ones
# of each night are filmed in the background afterwards (the Film autoload; fight.gd "filming"),
# steered to the result on the books: their best moment goes on BotMedia as a clip. Any other
# fight of the season can be filmed when someone asks to watch it (garage.watch_past).

const FILMS_KEEP := 10          # whole fights kept (watching one again shows the same fight)
const WORLD_CLIPS_KEEP := 24    # world clips kept (unless saved); older ones fall back to a still
const NIGHT_FILMS := 8          # fights filmed from each night
const FILM_POST := {"ko": ["%s put %s away last night. Watch it again.", "Lights out. %s finishes %s.", "%s against %s. It didn't go the distance."],
		"comeback": ["%s was nearly finished and came back to beat %s.", "Don't count out %s. Ask %s."],
		"rip": ["%s took a piece of %s home last night.", "%s tore a part off %s. Somebody call a welder."],
		"finisher": ["%s landed the big one on %s.", "The finisher. %s on %s."], "special": ["%s landed the big one on %s.", "%s pulled out the special move on %s."],
		"down": ["%s put %s on the floor last night.", "Flat on its back. %s floors %s."], "guard": ["%s smashed straight through %s's guard."],
		"combo": ["%s took %s apart, one hit after another."], "close": ["%s and %s went the distance."]}
const FEUD_LINE := -40.0


func films_path() -> String:
	return "user://films_%d.json" % save_slot


func clips_path() -> String:
	return "user://clips_%d.json" % save_slot


static func film_key(stage: String, y: int, r: int, a: int, b: int) -> String:
	return "%s:%d:%d:%d:%d" % [stage, y, r, mini(a, b), maxi(a, b)]


## How much a fight is worth filming: the league, the night, the table, the people you care about,
## bad blood between them, an upset, parts flying.
func fight_interest(ev: Dictionary, stage: String, a: int, b: int, w: int, p: int, pos: Dictionary) -> float:
	var sc: float = float({"open": 4, "scrap": 6, "rust": 9, "iron": 13, "steel": 18, "title": 40}.get(stage, 6))
	if str(ev.get("phase", "")) in ["finals", "playoffs"]:
		sc += 25.0
	var n: int = maxi(1, pos.size())
	var top := 0
	for id in [a, b]:
		var k := int(pos.get(id, n))
		if k < 4:
			top += 1
		elif k >= n - 6:
			sc += 5.0
		var wid := int(Career.pilot(ev, id).get("wid", -1))
		if wid < 0:
			continue
		if absf(rel_of(wid)) >= 15.0:
			sc += 12.0
		if Social.follows("w:%d" % wid):
			sc += 8.0
		var wp := World.pilot(wid)
		sc += log(maxf(10.0, float(wp.get("fol", 10)))) / log(10.0) * 2.5
	if top == 2:
		sc += 12.0
	var wa := int(Career.pilot(ev, a).get("wid", -1))
	var wb := int(Career.pilot(ev, b).get("wid", -1))
	var fe := feud_of(wa, wb)
	if fe <= FEUD_LINE:
		sc += 20.0
	elif fe <= -15.0:
		sc += 8.0
	var l := b if w == a else a
	if World.win_chance(Career.rating_of(ev, w), Career.rating_of(ev, l)) < 0.35:
		sc += 16.0
	if p >= 3:
		sc += 5.0
	return sc


## New nights in the results history: pick the best fights and queue them for filming.
func queue_night_films() -> void:
	var cands: Array = []
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		var pos := {}
		var order: Array = Career.standings(ev) if ev.has("table") else []
		for k in order.size():
			pos[int(order[k])] = k
		for h in ev.get("history", []):
			var rk := "%s:%d:%d" % [stage, year, int(h["r"])]
			if films_seen.has(rk):
				continue
			films_seen.append(rk)
			if week - int(h["w"]) > 1:
				continue   # an old night: watchable on request, not filmed by itself
			for x in h["list"]:
				var a := int(x[0])
				var b := int(x[1])
				if not film_ok(ev, a, b, int(h["r"])):
					continue
				cands.append({"score": fight_interest(ev, stage, a, b, int(x[2]), int(x[3]), pos) + randf() * 4.0,
						"spec": [stage, year, int(h["r"]), a, b, int(x[2]), int(x[3]), int(h["w"]), int(h["d"])]})
	if films_seen.size() > 120:
		films_seen = films_seen.slice(films_seen.size() - 120)
	cands.sort_custom(func(x, y): return float(x["score"]) > float(y["score"]))
	for c in cands.slice(0, NIGHT_FILMS):
		if float(c["score"]) < 12.0:
			break
		film_pending.append(c["spec"])
	if film_pending.size() > NIGHT_FILMS + 4:
		film_pending = film_pending.slice(film_pending.size() - NIGHT_FILMS - 4)   # skipped weeks: the newest nights win
	resume_films()


## Computer pilots only (your own fights are recorded as you fight them), not OVERLORD (Kane keeps
## its fights behind closed doors), not a fight you watched live.
func film_ok(ev: Dictionary, a: int, b: int, r: int) -> bool:
	if a == 0 or b == 0:
		return false
	for id in [a, b]:
		if int(Career.pilot(ev, id).get("rival", -1)) == OPPONENTS.size() - 1:
			return false
	for f in ev.get("forced", []):
		if int(f["round"]) == r and ((int(f["a"]) == a and int(f["b"]) == b) or (int(f["a"]) == b and int(f["b"]) == a)):
			return false
	return true


## Hand the waiting background films to the Film autoload (after a reload too).
func resume_films() -> void:
	var film_node := get_node_or_null("/root/Film")
	if film_node == null:
		return
	var keep: Array = []
	for spec in film_pending:
		if int(spec[1]) != year or week - int(spec[7]) > 2:
			continue
		var job := film_job(spec, false)
		if job.is_empty():
			continue
		keep.append(spec)
		if not film_node.busy_with(job["key"]):
			film_node.add(job)
	film_pending = keep
	var keys: Array = []
	for spec in keep:
		keys.append(film_key(str(spec[0]), int(spec[1]), int(spec[2]), int(spec[3]), int(spec[4])))
	film_node.retain(keys)


## spec = [stage, year, round, a, b, winner, parts, week, day]
func film_job(spec: Array, now: bool) -> Dictionary:
	var stage := str(spec[0])
	var ev: Dictionary = leagues.get(stage, {})
	if ev.is_empty():
		return {}
	var a := int(spec[3])
	var b := int(spec[4])
	var oa := Career.robot_of(ev, a)
	var ob := Career.robot_of(ev, b)
	if oa.is_empty() or ob.is_empty():
		return {}
	for k in 2:
		var o: Dictionary = [oa, ob][k]
		if str(o.get("pilot", "")) == "":
			o["pilot"] = str(Career.pilot(ev, [a, b][k]).get("pilot", ""))
	var venue: Array = Arena.career_venue(stage, "")
	return {"key": film_key(stage, int(spec[1]), int(spec[2]), a, b), "a": oa, "b": ob, "w": 0 if int(spec[5]) == a else 1,
			"p": int(spec[6]), "arena": venue[0], "crowd": venue[1], "title": tr(str(ev.get("name", ""))).to_upper(),
			"now": now, "bg": not now, "spec": spec}


func store_film(key: String, film: Dictionary) -> void:
	if film.is_empty():
		return
	film["fkey"] = key
	films.erase(key)
	films[key] = film
	while films.size() > FILMS_KEEP:
		films.erase(films.keys()[0])
	films_dirty = true


## A background film is ready: keep the fight, put its best moment (two if it had a lot in it) on
## BotMedia as a clip, and bad blood grows between pilots who tore into each other.
func film_done(job: Dictionary, out: Dictionary) -> void:
	var spec: Array = job.get("spec", [])
	var key: String = job["key"]
	film_pending = film_pending.filter(func(sp): return film_key(str(sp[0]), int(sp[1]), int(sp[2]), int(sp[3]), int(sp[4])) != key)
	store_film(key, out.get("film", {}))
	var ev: Dictionary = leagues.get(str(spec[0]), {}) if not spec.is_empty() else {}
	var wi := int(out.get("w", 0))
	var oa: Dictionary = job["a"]
	var ob: Dictionary = job["b"]
	var wo: Dictionary = oa if wi == 0 else ob
	var lo: Dictionary = ob if wi == 0 else oa
	var wwid := int(wo.get("wid", -1))
	var lwid := int(lo.get("wid", -1))
	var cl: Array = out.get("clips", [])
	var keep_n := 2 if cl.size() >= 2 and float(cl[1].get("score", 0.0)) >= 90.0 else 1
	var ids: Array = []
	var n := 0
	for c in cl.slice(0, keep_n):
		var cd: Dictionary = c
		n += 1
		cd["id"] = "w%d_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000, n]
		cd["world"] = true
		cd["fkey"] = key
		cd["wids"] = [wwid, lwid]
		cd["still"] = {"kind": "still", "wa": wwid, "wb": lwid, "won": true, "an": str(wo.get("pilot", "")), "bn": str(lo.get("pilot", "")),
				"venue": str(job.get("arena", "scrap_ring")), "ko": str(out.get("ko", ""))}
		clips[cd["id"]] = cd
		ids.append(cd["id"])
		clips_dirty = true
	film_index[key] = {"clips": ids, "ko": str(out.get("ko", "")), "secs": float(out.get("secs", 0.0)), "spec": spec}
	if not ids.is_empty():
		var c0: Dictionary = clips[ids[0]]
		var lines0: Array = FILM_POST.get(str(c0.get("kind", "")), FILM_POST["close"])
		var line: String = lines0[absi(hash(key)) % lines0.size()]
		var stage := str(spec[0]) if not spec.is_empty() else ""
		var p := Social.post("botmedia", line, [str(wo.get("pilot", "?")), str(lo.get("pilot", "?"))], {"kind": "clip", "id": ids[0]},
				[Social.tag_for(stage), "FightNight"], false, "news_clip")
		p["likes"] = int(int(p["likes"]) * 1.6)
		p["reposts"] = int(int(p["reposts"]) * 2.0)
	# bad blood: a fight that tore parts off (or ended in a K.O.) leaves a mark between them
	var rips_l: int = int((out.get("rips", [0, 0]) as Array)[1 - wi])
	var before := feud_of(wwid, lwid)
	var hit := 4.0 + 4.0 * rips_l + (6.0 if str(out.get("ko", "")) != "TIME!" and str(out.get("ko", "")) != "" else 0.0)
	feud_add(wwid, lwid, -hit)
	if before > FEUD_LINE and feud_of(wwid, lwid) <= FEUD_LINE and wwid >= 0 and lwid >= 0:
		World.news("Bad blood between %s and %s.", [str(wo.get("pilot", "?")), str(lo.get("pilot", "?"))])
		Social.post("w:%d" % wwid, "Told you, %s. Every time.", [str(lo.get("pilot", "?"))], {}, ["BadBlood"], false, "pilot_feud")
		Social.post("w:%d" % lwid, "Enjoy it, %s. Next time I take your arm home.", [str(wo.get("pilot", "?"))], {}, ["BadBlood"], false, "pilot_feud")
	prune_world_clips()
	save_game()


## Only the newest world clips stay (and any you saved): an older post shows its still instead.
func prune_world_clips() -> void:
	var world_ids: Array = []
	for id in clips:
		var c: Dictionary = clips[id]
		if c.get("world", false) and not c.get("saved", false):
			world_ids.append(id)
	if world_ids.size() <= WORLD_CLIPS_KEEP:
		return
	var drop: Array = world_ids.slice(0, world_ids.size() - WORLD_CLIPS_KEEP)
	for id in drop:
		var still: Dictionary = clips[id].get("still", {})
		for p in Social.st().get("posts", []):
			var card: Dictionary = p.get("card", {})
			if str(card.get("kind", "")) == "clip" and str(card.get("id", "")) == id:
				p["card"] = still
		clips.erase(id)
	clips_dirty = true


## (1.76) The week's best clips (yours you posted and the world's), best first.
func clips_week(n: int = 8) -> Array:
	var now := World.abs_week()
	var out: Array = []
	for id in clips:
		var c: Dictionary = clips[id]
		if c.get("temp", false) or now - int(c.get("wk", 0)) > 1:
			continue
		out.append(c)
	out.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return out.slice(0, n)


## (1.76) A pilot's highlights: world clips they're in, best first.
func clips_of_pilot(wid: int, n: int = 3) -> Array:
	var out: Array = []
	for id in clips:
		var c: Dictionary = clips[id]
		if (c.get("wids", []) as Array).any(func(x): return int(x) == wid):   # (ints come back from the file as floats)
			out.append(c)
	out.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return out.slice(0, n)


## (1.76) Your clips (the ones you posted) and the ones you saved, newest first.
func my_clips() -> Array:
	var out: Array = []
	for id in clips:
		var c: Dictionary = clips[id]
		if (c.get("mine", false) and not c.get("temp", false)) or c.get("saved", false):
			out.append(c)
	out.reverse()
	return out


## (1.75) Save a clip you like: it stays for good.
func save_clip(id: String, on: bool) -> void:
	if clips.has(id):
		if on:
			clips[id]["saved"] = true
		else:
			clips[id].erase("saved")
		clips_dirty = true
		save_game()


# Bad blood between two world pilots (-100 .. 0), kept in the world: grows when they tear into
# each other on film, fades a little every week.
func feud_of(a: int, b: int) -> float:
	if a < 0 or b < 0:
		return 0.0
	return float(world.get("feuds", {}).get("%d:%d" % [mini(a, b), maxi(a, b)], 0.0))


func feud_add(a: int, b: int, v: float) -> void:
	if a < 0 or b < 0 or a == b:
		return
	if not world.has("feuds"):
		world["feuds"] = {}
	var k := "%d:%d" % [mini(a, b), maxi(a, b)]
	world["feuds"][k] = clampf(float(world["feuds"].get(k, 0.0)) + v, -100.0, 0.0)


func feuds_week() -> void:
	var fd: Dictionary = world.get("feuds", {})
	for k in fd.keys():
		var v := float(fd[k]) * 0.97
		if v > -3.0:
			fd.erase(k)
		else:
			fd[k] = v


# ---------------------------------------------------------------- the City (1.77)
# Port Ferrum on your pilot's tablet: places on a map, grouped in districts. Gus's building is home
# and the bay is always one call away; going OUT costs the pilot's own hours (PILOT_HOURS a part of
# the day, the same 4 the bay works). When they run out, that part of the day is over. Every day
# starts at home. Fights in the evening: Gus drives you to the venue.

const PILOT_HOURS := 4.0
## place -> {name, district, pos (on the 1000 x 560 map), road (anchor on the avenue), kind,
## feature (unlocks it), venue (a landmark you fight in, not a place you go)}
const PLACES := {
	"home": {"name": "Gus's building", "district": "oldtown", "pos": [318, 300], "road": 2, "kind": "home"},
	"pub": {"name": "The Rusty Bolt", "district": "oldtown", "pos": [430, 236], "road": 3, "kind": "pub"},
	"partsrus": {"name": "Parts-R-Us", "district": "oldtown", "pos": [410, 372], "road": 3, "kind": "shop", "feature": "shop"},
	"scrapyard": {"name": "The Scrapyard", "district": "docks", "pos": [150, 452], "road": 1, "kind": "scrap"},
	"scrap_ring": {"name": "The scrap ring", "district": "docks", "pos": [246, 484], "road": 1, "kind": "venue", "venue": "scrap"},
	"sports_hall": {"name": "Ferrum Sports Hall", "district": "midtown", "pos": [596, 360], "road": 4, "kind": "venue", "venue": "rust"},
	"regional_hall": {"name": "The Regional Hall", "district": "midtown", "pos": [700, 300], "road": 5, "kind": "venue", "venue": "iron"},
	"champ_arena": {"name": "The Championship Arena", "district": "heights", "pos": [800, 236], "road": 5, "kind": "venue", "venue": "steel"},
	"kane_arena": {"name": "Kane Arena", "district": "heights", "pos": [880, 120], "road": 6, "kind": "venue", "venue": "title"},
}
const DISTRICTS := {"oldtown": "OLD TOWN", "docks": "THE DOCKS", "midtown": "MIDTOWN", "heights": "KANE HEIGHTS"}
const DISTRICT_HOURS := {"oldtown": {"docks": 1.0, "midtown": 1.0, "heights": 2.0}, "docks": {"oldtown": 1.0, "midtown": 1.5, "heights": 2.5},
		"midtown": {"oldtown": 1.0, "docks": 1.5, "heights": 1.0}, "heights": {"oldtown": 2.0, "docks": 2.5, "midtown": 1.0}}
const DIG_HOURS := 1.0


func travel_hours(from: String, to: String) -> float:
	if from == to or not PLACES.has(from) or not PLACES.has(to):
		return 0.0
	var a := str(PLACES[from]["district"])
	var b := str(PLACES[to]["district"])
	if a == b:
		return 0.5
	return float(DISTRICT_HOURS[a].get(b, 1.0))


func pilot_left() -> float:
	return maxf(0.0, PILOT_HOURS - pilot_used)


## Can you go there? "" = yes, else why not.
func place_locked(place: String) -> String:
	var pl: Dictionary = PLACES.get(place, {})
	if pl.is_empty():
		return "Nowhere."
	if pl.has("venue"):
		return "Fight nights only. Gus drives you."
	var f := str(pl.get("feature", ""))
	if f != "" and not unlocked(f):
		return "Opens after your second fight."
	return ""


## The pilot spends hours (a trip, a dig). Running out ends this part of the day (the bay works
## its shift) and the rest carries into the next. Returns how many parts of the day went by.
func spend_pilot(h: float) -> int:
	var passed := 0
	pilot_used += h
	while pilot_used >= PILOT_HOURS - 0.01 and phase < 2:
		var carry := pilot_used - PILOT_HOURS
		advance_phase()
		pilot_used = maxf(0.0, carry)
		passed += 1
	if phase == 2:
		pilot_used = minf(pilot_used, PILOT_HOURS)
	return passed


## Go somewhere: the hours it takes are spent. Returns the parts of the day that went by.
func travel_to(place: String) -> int:
	if place == pilot_at or not PLACES.has(place):
		return 0
	var h := travel_hours(pilot_at, place)
	pilot_at = place
	if not places_been.has(place):
		places_been.append(place)   # (1.83) the City's quick buttons
	var passed := spend_pilot(h)
	save_game()
	return passed
