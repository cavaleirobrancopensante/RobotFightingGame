extends RefCounted
const I18n = preload("res://i18n.gd")
## Extra content: manufacturer brands (with signature traits), fighting styles,
## and the generator that turns brands into parts.
##
## Every brand makes a head, torso, arm and leg in two models (Mk I and a stronger X model),
## each using different shapes, so brands look as different as they play.
## Traits are the brand's special ability; X models have the stronger version (level 2).

const TRAITS := {
	"reactive": {"name": "Reactive Armor", "desc": "%d%% chance to shrug off a hit to this part.", "values": [12, 20]},
	"stun": {"name": "Shock", "desc": "%d%% chance to stun on hit.", "values": [8, 14]},
	"burn": {"name": "Burn", "desc": "Hits set the target part on fire for %d damage over 3s.", "values": [6, 11]},
	"chill": {"name": "Frost", "desc": "Hits slow the enemy by 35%% for %0.1fs.", "values": [1.5, 2.5]},
	"magnet": {"name": "Magnet", "desc": "+%d reach, and hits pull the enemy closer.", "values": [16, 28]},
	"crit": {"name": "Precision", "desc": "%d%% chance for double damage.", "values": [10, 16]},
	"dodge": {"name": "Evasion", "desc": "%d%% chance to dodge hits completely.", "values": [6, 10]},
	"leech": {"name": "Leech", "desc": "Repairs your torso by %d%% of the damage you deal.", "values": [10, 18]},
	"explosive": {"name": "Volatile", "desc": "Explodes for %d damage when it's destroyed.", "values": [15, 26]},
	"plating": {"name": "Plating", "desc": "+%d armor on your torso.", "values": [8, 14]},
	# (1.97) Old Iron and Scrapworks
	"ram": {"name": "Ram", "desc": "Your hits push %d%% further.", "values": [40, 70]},
	"crush": {"name": "Crush", "desc": "Hits clamp on: %d damage to that part over 2s.", "values": [8, 13]},
	"anchored": {"name": "Anchored", "desc": "Knockback on this robot cut by %d%%.", "values": [50, 80]},
	"flywheel": {"name": "Flywheel", "desc": "Once the tank is full, stores up to %d%% more as spare power.", "values": [25, 40]},
	# (1.98) Brassworks
	"pressure": {"name": "Pressure", "desc": "Builds Pressure as it fights (%d%% speed). Full, the next hit vents: big damage and a cloud of steam.", "values": [70, 100]},
	"vent": {"name": "Vent", "desc": "Hits puff steam in their face: %d%% chance to knock their crosshair off.", "values": [25, 40]},
	# (1.99) Hellfire Heavy
	"dazzle": {"name": "Dazzle", "desc": "A flashing beacon: enemies aim at you %d%% slower.", "values": [25, 40]},
	"stomp": {"name": "Stomp", "desc": "Landing from a jump next to them hits their legs for %d and staggers them.", "values": [8, 13]},
	# (1.100) Volta Motor
	"hover": {"name": "Mag-Lev", "desc": "Floats just over the floor: low hits do %d%% less.", "values": [35, 55]},
	# (1.101) Nimbus Aerial
	"frostskin": {"name": "Frost Skin", "desc": "Hits on its body chill the attacker: 35%% slower for %0.1fs.", "values": [1.0, 1.6]},
	"gust": {"name": "Gust", "desc": "Hits blow them back %d%% further.", "values": [60, 90]},
	"glide": {"name": "Glide", "desc": "Falls %d%% slower after a jump: a short glide.", "values": [35, 50]},
	"tarp": {"name": "Tarp", "desc": "The tarp hides your weak spot: the enemy's first scans find nothing (%d of them).", "values": [1, 2]},
}

# name: brand name. trait: signature. colors: [Mk I, X]. mods: stat changes. cost: price multiplier.
# shapes: [Mk I shape, X shape] per kind. models: model names per kind.
const BRANDS := [
	{"id": "scrap", "name": "Scrapworks", "trait": "", "colors": ["#8d6e63", "#a1887f"], "cost": 0.55,
	 "mods": {"hp": -0.1},
	 "shapes": {"head": ["bucket", "tv"], "torso": ["crate", "barrel"], "arm": ["rod", "claw"], "leg": ["rod", "pillar"]},
	 "models": {"head": "Peeper", "torso": "Crate Body", "arm": "Wrench Arm", "leg": "Pipe Leg"}},
	{"id": "ironclad", "name": "Ironclad", "trait": "reactive", "colors": ["#5d6d7e", "#2c3e50"], "cost": 1.15,
	 "mods": {"hp": 0.3, "armor": 12, "speed": -8},
	 "shapes": {"head": ["knight", "visor"], "torso": ["hex", "tank"], "arm": ["bulky", "hammer"], "leg": ["tread", "pillar"]},
	 "models": {"head": "Bastion Helm", "torso": "Rampart Hull", "arm": "Bulwark Arm", "leg": "Fortress Leg"}},
	{"id": "volta", "name": "Volta", "trait": "stun", "colors": ["#f1c40f", "#00b7ff"], "cost": 1.0,
	 "mods": {"speed": 12},
	 "shapes": {"head": ["bulb", "laser"], "torso": ["slim", "core"], "arm": ["claw", "spike"], "leg": ["spring", "blade"]},
	 "models": {"head": "Arc Lens", "torso": "Coil Frame", "arm": "Shock Fist", "leg": "Sprint Leg"}},
	{"id": "pyro", "name": "Pyro Labs", "trait": "burn", "colors": ["#e74c3c", "#e67e22"], "cost": 1.05,
	 "mods": {"damage": 12},
	 "shapes": {"head": ["skull", "horned"], "torso": ["furnace", "vee"], "arm": ["flame", "spike"], "leg": ["reverse", "piston"]},
	 "models": {"head": "Ember Skull", "torso": "Furnace Chest", "arm": "Flamer Arm", "leg": "Cinder Leg"}},
	{"id": "frost", "name": "Frostbyte", "trait": "chill", "colors": ["#74b9ff", "#dfe6e9"], "cost": 1.0,
	 "mods": {"armor": 5},
	 "shapes": {"head": ["dome", "orb"], "torso": ["orb", "hex"], "arm": ["blade", "piston"], "leg": ["blade", "hover"]},
	 "models": {"head": "Glacier Dome", "torso": "Cryo Core", "arm": "Icicle Arm", "leg": "Glide Leg"}},
	{"id": "magnetica", "name": "Magnetica", "trait": "magnet", "colors": ["#9b59b6", "#c0392b"], "cost": 1.05,
	 "mods": {},
	 "shapes": {"head": ["dish", "speaker"], "torso": ["core", "orb"], "arm": ["magnet", "magnet"], "leg": ["spider", "thick"]},
	 "models": {"head": "Field Dish", "torso": "Dynamo Core", "arm": "Mag Arm", "leg": "Crawler Leg"}},
	{"id": "kane", "name": "Kane Dynamics", "trait": "crit", "colors": ["#1a1a2e", "#e0b84a"], "cost": 1.45,
	 "mods": {"hp": 0.15, "armor": 6, "damage": 10, "speed": 6, "aim": 8},
	 "shapes": {"head": ["tall", "visor"], "torso": ["core", "vee"], "arm": ["drill", "saw"], "leg": ["reverse", "hover"]},
	 "models": {"head": "Sentinel", "torso": "Paragon Frame", "arm": "Executor Arm", "leg": "Stride Leg"}},
	{"id": "nimbus", "name": "Nimbus", "trait": "dodge", "colors": ["#ecf0f1", "#81ecec"], "cost": 1.0,
	 "mods": {"hp": -0.15, "speed": 20},
	 "shapes": {"head": ["orb", "dome"], "torso": ["slim", "ribcage"], "arm": ["rod", "blade"], "leg": ["hover", "blade"]},
	 "models": {"head": "Cirrus Eye", "torso": "Zephyr Frame", "arm": "Feather Arm", "leg": "Drift Leg"}},
	{"id": "medix", "name": "Medix", "trait": "leech", "colors": ["#b5893b", "#c27b4a"], "cost": 1.05,
	 "mods": {"hp": 0.1},
	 "shapes": {"head": ["speaker", "cyclops"], "torso": ["orb", "box"], "arm": ["piston", "claw"], "leg": ["piston", "spider"]},
	 "models": {"head": "Gauge Helm", "torso": "Boiler Core", "arm": "Piston Gauntlet", "leg": "Bellows Leg"}},
	{"id": "boom", "name": "Boomstick Bros", "trait": "explosive", "colors": ["#d35400", "#2d3436"], "cost": 0.9,
	 "mods": {"damage": 18, "hp": -0.1},
	 "shapes": {"head": ["tv", "bucket"], "torso": ["crate", "barrel"], "arm": ["hammer", "bulky"], "leg": ["thick", "tread"]},
	 "models": {"head": "Fuse Box", "torso": "Powder Keg", "arm": "Blaster Arm", "leg": "Stomper Leg"}},
]

# base stats per kind for [Mk I, X]
const BASE := {
	"head": {"hp": [42, 58], "armor": [5, 12], "aim": [8, 18], "chips": [2, 3], "draw": [2, 4], "cost": [450, 1500]},
	"torso": {"hp": [105, 140], "armor": [6, 14], "speed": [0, 4], "draw": [2, 4], "cost": [500, 1700]},
	"arm": {"hp": [46, 62], "armor": [5, 10], "damage": [15, 32], "speed": [3, 6], "draw": [2, 4], "cost": [450, 1500]},
	"leg": {"hp": [52, 70], "armor": [5, 10], "damage": [10, 22], "speed": [8, 16], "draw": [2, 4], "cost": [450, 1500]},
}

# Extra one-offs: brand reactors and back gear, and torsos with extra mount points.
const EXTRAS := [
	{"id": "volta_reactor", "kind": "reactor", "name": "Volta Battery Stack", "cost": 1100, "output": 28, "color": "#f1c40f"},
	{"id": "pyro_reactor", "kind": "reactor", "name": "Hellfire Burner", "cost": 1600, "output": 34, "color": "#ff6b35"},
	{"id": "frost_reactor", "kind": "reactor", "name": "Cryo Cell", "cost": 1400, "output": 30, "color": "#74b9ff"},
	{"id": "kane_reactor", "kind": "reactor", "name": "Kane Fusion X", "cost": 4200, "output": 58, "color": "#e0b84a"},
	{"id": "medix_reactor", "kind": "reactor", "name": "Brassworks Firebox", "cost": 2400, "output": 30, "color": "#2ecc71", "gimmick": "regen"},
	{"id": "boom_reactor", "kind": "reactor", "name": "Unstable Barrel", "cost": 900, "output": 40, "color": "#d35400", "trait": "explosive", "trait_lv": 1},
	{"id": "ironclad_back", "kind": "back", "name": "Old Iron Plating", "cost": 1000, "draw": 2, "shape": "plating", "color": "#5d6d7e", "trait": "plating", "trait_lv": 1},
	{"id": "nimbus_back", "kind": "back", "name": "Nimbus Wings", "cost": 1500, "draw": 3, "shape": "wings", "color": "#ecf0f1", "gimmick": "double_jump"},
	{"id": "magnetica_back", "kind": "back", "name": "Volta Mag Coil Pack", "cost": 1300, "draw": 3, "shape": "battery", "color": "#9b59b6", "output": 8},
	# torsos with extra mounts: a second head, two extra arms, or both
	{"id": "torso_hydra", "kind": "torso", "name": "Hydra Yoke", "cost": 1800, "hp": 130, "armor": 10, "draw": 4, "shape": "yoke", "color": "#16a085", "mounts": ["head2"]},
	{"id": "torso_quad", "kind": "torso", "name": "Quad Frame", "cost": 2100, "hp": 125, "armor": 8, "speed": -5, "draw": 5, "shape": "quad", "color": "#8e44ad", "mounts": ["arm_front2", "arm_back2"]},
	{"id": "torso_monster", "kind": "torso", "name": "Monster Chassis", "cost": 3900, "hp": 165, "armor": 14, "speed": -10, "draw": 7, "shape": "monster", "color": "#c0392b", "mounts": ["head2", "arm_front2", "arm_back2"]},
	{"id": "scrap_hydra", "kind": "torso", "name": "Scrapworks Two-Neck", "cost": 900, "hp": 95, "armor": 2, "draw": 3, "shape": "yoke", "color": "#8d6e63", "mounts": ["head2"]},
	{"id": "scrap_quad", "kind": "torso", "name": "Scrapworks Octo-Rig", "cost": 1100, "hp": 90, "armor": 2, "speed": -5, "draw": 3, "shape": "quad", "color": "#a1887f", "mounts": ["arm_front2", "arm_back2"]},
]

const STYLES := {
	"tank": {"name": "Tank", "desc": "+10 armor on every part, blocking soaks almost everything. -10% speed.",
		"signature": "bulwark_slam", "color": "#5d6d7e"},
	"striker": {"name": "Striker", "desc": "+15% damage, +10% attack speed, +5% critical hits. Takes 10% more damage.",
		"signature": "flurry", "color": "#e74c3c"},
	"mechanic": {"name": "Mechanic", "desc": "Self-repairs during fights: 20% of the damage it deals fixes its most beaten-up part (old dents too). Garage repairs 40% cheaper.",
		"signature": "field_repair", "color": "#2ecc71"},
	"specialist": {"name": "Specialist", "desc": "Gadget cooldowns -40%, +1 chip slot, aimed hits +25% and better salvage.",
		"signature": "overclock", "color": "#9b59b6"},
}


## All brand parts (plus extras), as part definitions.
static func generate() -> Array:
	var out: Array = []
	for b in BRANDS:
		for kind in ["head", "torso", "arm", "leg"]:
			for tier in 2:
				var base: Dictionary = BASE[kind]
				var mods: Dictionary = b["mods"]
				var d := {
					"id": "%s_%s_%d" % [b["id"], kind, tier + 1], "kind": kind,
					"name": "%s %s%s" % [b["name"], b["models"][kind], "" if tier == 0 else " X"],
					"cost": int(base["cost"][tier] * b["cost"] / 10.0) * 10,
					"hp": int(base["hp"][tier] * (1.0 + mods.get("hp", 0.0))),
					"armor": base["armor"][tier] + mods.get("armor", 0),
					"draw": base["draw"][tier],
					"shape": b["shapes"][kind][tier], "color": b["colors"][tier],
					"size": 1.0 if tier == 0 else 1.08, "brand": b["id"],
					"brand_name": b["name"], "model": b["models"][kind], "tier_x": tier > 0,
				}
				if base.has("damage"):
					d["damage"] = base["damage"][tier] + mods.get("damage", 0)
				if base.has("speed"):
					d["speed"] = base["speed"][tier] + mods.get("speed", 0)
				if kind == "torso":
					d["speed"] = base["speed"][tier] + int(mods.get("speed", 0) / 2.0)
				if base.has("aim"):
					d["aim"] = base["aim"][tier] + mods.get("aim", 0)
					d["chips"] = base["chips"][tier]
				if b["trait"] != "":
					d["trait"] = b["trait"]
					d["trait_lv"] = tier + 1
				out.append(d)
	for e in EXTRAS:
		out.append(e.duplicate())
	return out


static func trait_value(d: Dictionary) -> float:
	var t: String = d.get("trait", "")
	if t == "":
		return 0.0
	return float(TRAITS[t]["values"][clampi(int(d.get("trait_lv", 1)) - 1, 0, 1)])


static func trait_text(d: Dictionary) -> String:
	var t: String = d.get("trait", "")
	if t == "":
		return ""
	var info: Dictionary = TRAITS[t]
	return "%s: %s" % [I18n.t(info["name"]), I18n.t(info["desc"]) % trait_value(d)]
