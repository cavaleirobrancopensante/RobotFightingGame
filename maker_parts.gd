extends RefCounted
## (1.97) The makers' own parts (study: "Robot Fighting · Parts & Makers Study" doc, "Parts by maker").
## Each maker release replaces that maker's borrowed brand and house parts with its real line: 11
## designs (2 heads, 2 torsos, 2 arms, 2 legs, 2 extras, 1 rare multi-mount torso), each drawn in the
## one size it was designed for. Where an old part was the same idea it keeps its id (saves keep
## working: an owned Claw Arm is now a Crane Hook), otherwise the new part gets a new id.
## Old parts the line replaces are RETIRED: still valid (old saves, robots already built), but no
## longer sold, dug up, picked by world pilots or shown in catalogues. They leave for good with 2.0.
##
## Numbers are written like PART_LIST's (before the 1.41 HP multiplier and the grade price squeeze).

## Makers whose parts come in one size only (no Light / Heavy copies). Scrapworks keeps loose sizes:
## odd, mismatched sizes are its character.
const ONE_SIZE := ["oldiron", "brassworks"]

const DEFS := [
	# ---- Old Iron Foundry: cast iron, big hex bolts, most HP and armour, slow, heavy on power
	{"id": "head_box", "kind": "head", "name": "Rivet Bucket", "cost": 260, "hp": 50, "armor": 10, "aim": 4, "draw": 2, "chips": 1,
		"shape": "rivet", "color": "#7d8a96", "size": 0.95, "maker": "oldiron"},
	{"id": "ironclad_head_1", "kind": "head", "name": "Bulldog Grille", "cost": 1300, "hp": 72, "armor": 22, "aim": 6, "draw": 4, "chips": 2,
		"shape": "grille", "color": "#5d6d7e", "size": 1.05, "maker": "oldiron"},
	{"id": "ironclad_torso_1", "kind": "torso", "name": "Engine Block", "cost": 1600, "hp": 150, "armor": 16, "speed": -6, "draw": 5,
		"shape": "engine", "color": "#4a5560", "maker": "oldiron", "trait": "plating", "trait_lv": 1},
	{"id": "ironclad_torso_2", "kind": "torso", "name": "Locomotive Front", "cost": 1400, "hp": 138, "armor": 12, "speed": -4, "draw": 4,
		"shape": "loco", "color": "#2c3e50", "maker": "oldiron", "trait": "ram", "trait_lv": 1},
	{"id": "ironclad_arm_2", "kind": "arm", "name": "Anvil Fist", "cost": 1500, "hp": 70, "armor": 14, "damage": 42, "speed": -12, "draw": 5,
		"shape": "anvil", "color": "#3d4650", "size": 1.15, "maker": "oldiron"},
	{"id": "arm_claw", "kind": "arm", "name": "Crane Hook", "cost": 1100, "hp": 58, "armor": 10, "damage": 18, "speed": -2, "draw": 4,
		"shape": "crane", "color": "#d4a017", "size": 0.95, "maker": "oldiron", "trait": "crush", "trait_lv": 1},
	{"id": "ironclad_leg_1", "kind": "leg", "name": "Iron Stomper", "cost": 1200, "hp": 80, "armor": 16, "damage": 24, "speed": -6, "draw": 4,
		"shape": "stomper", "color": "#4a5560", "size": 1.05, "maker": "oldiron"},
	{"id": "leg_tread", "kind": "leg", "name": "Caterpillar Track", "cost": 1500, "hp": 95, "armor": 24, "damage": 12, "speed": -10, "draw": 5,
		"shape": "tread", "color": "#556b2f", "maker": "oldiron", "trait": "anchored", "trait_lv": 2},
	{"id": "reactor_diesel", "kind": "reactor", "name": "Diesel Core", "cost": 300, "output": 18, "color": "#ff5533", "maker": "oldiron"},
	{"id": "ironclad_back", "kind": "back", "name": "Flywheel Back", "cost": 1000, "draw": 2, "shape": "flywheel", "color": "#5d6d7e",
		"maker": "oldiron", "trait": "flywheel", "trait_lv": 1},
	{"id": "torso_quad", "kind": "torso", "name": "Quad Frame", "cost": 2100, "hp": 130, "armor": 10, "speed": -6, "draw": 5,
		"shape": "quad", "color": "#7a3b2e", "mounts": ["arm_front2", "arm_back2"], "maker": "oldiron"},
	# ---- Scrapworks: found junk, everything a bit worse, cheapest to buy and to mend
	{"id": "scrap_head_1", "kind": "head", "name": "Peeper Bucket", "cost": 200, "hp": 38, "armor": 3, "aim": 6, "draw": 1, "chips": 2,
		"shape": "peeper", "color": "#8d6e63", "maker": "scrapworks"},
	{"id": "scrap_head_2", "kind": "head", "name": "Busted TV", "cost": 320, "hp": 42, "armor": 4, "aim": 10, "draw": 2, "chips": 3,
		"shape": "busted", "color": "#6b6352", "maker": "scrapworks"},
	{"id": "scrap_torso_1", "kind": "torso", "name": "Drum Body", "cost": 260, "hp": 96, "armor": 4, "speed": 0, "draw": 2,
		"shape": "drum", "color": "#7d7466", "maker": "scrapworks"},
	{"id": "scrap_torso_2", "kind": "torso", "name": "Crate Body", "cost": 300, "hp": 90, "armor": 3, "speed": 4, "draw": 2,
		"shape": "crate", "color": "#a1887f", "maker": "scrapworks"},
	{"id": "scrap_arm_1", "kind": "arm", "name": "Wrench Arm", "cost": 240, "hp": 42, "armor": 3, "damage": 16, "speed": 2, "draw": 2,
		"shape": "wrench", "color": "#8a8f98", "maker": "scrapworks"},
	{"id": "scrap_arm_2", "kind": "arm", "name": "Pipe Grabber", "cost": 300, "hp": 40, "armor": 2, "damage": 10, "speed": 4, "draw": 2,
		"shape": "grabber", "color": "#9a8a74", "size": 1.15, "maker": "scrapworks"},
	{"id": "scrap_leg_1", "kind": "leg", "name": "Pipe Leg", "cost": 220, "hp": 46, "armor": 3, "damage": 8, "speed": 6, "draw": 2,
		"shape": "pipe", "color": "#8a7f74", "maker": "scrapworks"},
	{"id": "scrap_leg_2", "kind": "leg", "name": "Cart Wheel", "cost": 320, "hp": 40, "armor": 2, "damage": 2, "speed": 30, "draw": 2,
		"shape": "wheel", "color": "#5d5a55", "maker": "scrapworks"},
	{"id": "scrap_battery", "kind": "reactor", "name": "Car Battery", "cost": 180, "output": 14, "color": "#ff9a3c", "maker": "scrapworks"},
	{"id": "scrap_tarp", "kind": "back", "name": "Tarp Cape", "cost": 350, "draw": 0, "shape": "tarp", "color": "#4d6b4a",
		"maker": "scrapworks", "trait": "tarp", "trait_lv": 1},
	{"id": "scrap_quad", "kind": "torso", "name": "Octo-Rig", "cost": 1100, "hp": 90, "armor": 2, "speed": -5, "draw": 3,
		"shape": "quad", "color": "#a1887f", "mounts": ["arm_front2", "arm_back2"], "maker": "scrapworks"},
	# ---- Brassworks & Sons (1.98): brass and copper, steam and patience; Pressure builds as it fights
	{"id": "medix_head_1", "kind": "head", "name": "Periscope Helm", "cost": 900, "hp": 46, "armor": 8, "aim": 12, "draw": 3, "chips": 3,
		"shape": "periscope", "color": "#c9a227", "size": 0.95, "maker": "brassworks"},
	{"id": "medix_head_2", "kind": "head", "name": "Diving Bell", "cost": 1200, "hp": 68, "armor": 20, "aim": 6, "draw": 3, "chips": 2,
		"shape": "divingbell", "color": "#b87333", "size": 1.05, "maker": "brassworks"},
	{"id": "medix_torso_1", "kind": "torso", "name": "Boiler Chest", "cost": 1500, "hp": 130, "armor": 12, "speed": 0, "draw": 4,
		"shape": "boiler", "color": "#b87333", "maker": "brassworks", "trait": "pressure", "trait_lv": 2},
	{"id": "medix_torso_2", "kind": "torso", "name": "Clockwork Cage", "cost": 1400, "hp": 120, "armor": 10, "speed": 4, "draw": 3,
		"shape": "clockwork", "color": "#c9a227", "maker": "brassworks", "trait": "leech", "trait_lv": 1},
	{"id": "medix_arm_1", "kind": "arm", "name": "Piston Gauntlet", "cost": 1200, "hp": 60, "armor": 10, "damage": 28, "speed": 0, "draw": 4,
		"shape": "gauntlet", "color": "#c9a227", "size": 1.1, "maker": "brassworks", "trait": "vent", "trait_lv": 1},
	{"id": "medix_arm_2", "kind": "arm", "name": "Riveter", "cost": 1000, "hp": 48, "armor": 6, "damage": 10, "speed": 30, "draw": 3,
		"shape": "riveter", "color": "#b87333", "size": 0.9, "maker": "brassworks"},
	{"id": "medix_leg_1", "kind": "leg", "name": "Bellows Leg", "cost": 1000, "hp": 62, "armor": 8, "damage": 14, "speed": 14, "draw": 3,
		"shape": "bellows", "color": "#b87333", "maker": "brassworks"},
	{"id": "medix_leg_2", "kind": "leg", "name": "Tripod Strut", "cost": 1200, "hp": 70, "armor": 14, "damage": 10, "speed": -2, "draw": 3,
		"shape": "tripod", "color": "#c9a227", "maker": "brassworks", "trait": "anchored", "trait_lv": 1},
	{"id": "medix_reactor", "kind": "reactor", "name": "Coal Firebox", "cost": 1600, "output": 30, "color": "#ff7a2a", "maker": "brassworks",
		"trait": "pressure", "trait_lv": 1},
	{"id": "brass_stack", "kind": "back", "name": "Smokestack", "cost": 900, "draw": 2, "shape": "smokestack", "color": "#6b4a2b",
		"maker": "brassworks", "gimmick": "steam_burst"},
	{"id": "torso_hydra", "kind": "torso", "name": "Hydra Yoke", "cost": 1800, "hp": 130, "armor": 10, "speed": 0, "draw": 4,
		"shape": "yoke", "color": "#b87333", "mounts": ["head2"], "maker": "brassworks"},
]

## Old Old Iron and Scrapworks parts the new lines replace.
const RETIRED := ["torso_box", "torso_plate", "torso_tank", "arm_rod", "arm_bulky", "leg_steel", "leg_pillar", "back_battery",
		"ironclad_head_2", "ironclad_arm_1", "ironclad_leg_2", "fork_head", "fork_torso", "fork_arm", "fork_leg",
		"scrap_hydra", "torso_rib",
		"head_cyclops", "torso_core", "arm_piston", "arm_grapple", "leg_piston", "reactor_cap", "reactor_regen"]   # (1.98) Brassworks

## The makers whose lines are in (their launch posts once on BotMedia).
const LAUNCHED := ["oldiron", "scrapworks", "brassworks"]
## (1.98) Makers with their own shop in the city: Parts-R-Us stops stocking them.
const OWN_SHOP := {"brassworks": "brassworks"}


## The part list with the makers' lines in: same ids replaced whole, new ids added, old ones retired.
static func merge(list: Array) -> Array:
	var by := {}
	for d in DEFS:
		by[str(d["id"])] = d
	var out: Array = []
	var seen := {}
	for p in list:
		var id := str(p["id"])
		if by.has(id):
			out.append((by[id] as Dictionary).duplicate(true))
			seen[id] = true
		else:
			var d: Dictionary = p.duplicate(true)
			if RETIRED.has(id):
				d["shop"] = false
				d["retired"] = true
			out.append(d)
	for d in DEFS:
		if not seen.has(str(d["id"])):
			out.append((d as Dictionary).duplicate(true))
	return out


static func one_size(d: Dictionary) -> bool:
	return ONE_SIZE.has(str(d.get("maker", "")))
