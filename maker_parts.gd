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
const ONE_SIZE := ["oldiron", "brassworks", "hellfire", "volta", "nimbus"]

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
	# ---- Hellfire Heavy (1.99): demolition gear. Hits hard, burns, blows up; slow and thirsty
	{"id": "pyro_head_1", "kind": "head", "name": "Welder's Mask", "cost": 800, "hp": 52, "armor": 12, "aim": 6, "draw": 3, "chips": 2,
		"shape": "welder", "color": "#3a3d42", "maker": "hellfire", "trait": "burn", "trait_lv": 1},
	{"id": "boom_head_1", "kind": "head", "name": "Hazard Beacon", "cost": 1100, "hp": 46, "armor": 8, "aim": 10, "draw": 3, "chips": 3,
		"shape": "beacon", "color": "#e0a526", "size": 0.95, "maker": "hellfire", "trait": "dazzle", "trait_lv": 1},
	{"id": "boom_torso_1", "kind": "torso", "name": "Fuel Tank", "cost": 1100, "hp": 118, "armor": 8, "speed": 2, "draw": 3,
		"shape": "fueltank", "color": "#c0392b", "maker": "hellfire", "trait": "explosive", "trait_lv": 2},
	{"id": "pyro_torso_1", "kind": "torso", "name": "Wrecking Hull", "cost": 1700, "hp": 150, "armor": 18, "speed": -6, "draw": 5,
		"shape": "hull", "color": "#e0a526", "maker": "hellfire"},
	{"id": "boom_arm_1", "kind": "arm", "name": "Wrecking Ball", "cost": 1600, "hp": 68, "armor": 10, "damage": 55, "speed": -18, "draw": 5,
		"shape": "wrecker", "color": "#3d4045", "size": 1.1, "maker": "hellfire"},
	{"id": "pyro_arm_1", "kind": "arm", "name": "Torch Arm", "cost": 1300, "hp": 52, "armor": 6, "damage": 22, "speed": 4, "draw": 4,
		"shape": "torch", "color": "#c0392b", "size": 0.95, "maker": "hellfire", "trait": "burn", "trait_lv": 2},
	{"id": "pyro_leg_1", "kind": "leg", "name": "Excavator Track", "cost": 1400, "hp": 90, "armor": 18, "damage": 24, "speed": -8, "draw": 5,
		"shape": "excavator", "color": "#e0a526", "size": 1.05, "maker": "hellfire"},
	{"id": "boom_leg_1", "kind": "leg", "name": "Hydraulic Ram", "cost": 1200, "hp": 66, "armor": 10, "damage": 26, "speed": 6, "draw": 4,
		"shape": "hydraulic", "color": "#d35400", "maker": "hellfire", "trait": "stomp", "trait_lv": 1},
	{"id": "boom_reactor", "kind": "reactor", "name": "Unstable Barrel", "cost": 900, "output": 40, "color": "#d35400", "maker": "hellfire",
		"trait": "explosive", "trait_lv": 1},
	{"id": "hell_exhaust", "kind": "back", "name": "Exhaust Stacks", "cost": 1000, "draw": 2, "shape": "exhaust", "color": "#3a3d42",
		"maker": "hellfire", "gimmick": "flame_dash"},
	{"id": "torso_monster", "kind": "torso", "name": "Monster Chassis", "cost": 3900, "hp": 165, "armor": 14, "speed": -10, "draw": 7,
		"shape": "monster", "color": "#c0392b", "mounts": ["head2", "arm_front2", "arm_back2"], "maker": "hellfire"},
	# ---- Volta Motor (1.100): 80s retro future. Chrome, neon, arcs; fast and light, shocks and magnets
	{"id": "volta_head_1", "kind": "head", "name": "Tesla Coil", "cost": 1000, "hp": 42, "armor": 5, "aim": 10, "draw": 3, "chips": 3,
		"shape": "tesla", "color": "#2a2f3a", "size": 0.95, "maker": "volta", "trait": "stun", "trait_lv": 1},
	{"id": "volta_head_2", "kind": "head", "name": "Racer Visor", "cost": 1200, "hp": 48, "armor": 8, "aim": 18, "draw": 3, "chips": 2,
		"shape": "racer", "color": "#e8e8ee", "maker": "volta"},
	{"id": "volta_torso_1", "kind": "torso", "name": "Chrome Coupe", "cost": 1300, "hp": 100, "armor": 6, "speed": 12, "draw": 3,
		"shape": "coupe", "color": "#d6dbe2", "maker": "volta"},
	{"id": "volta_torso_2", "kind": "torso", "name": "Dynamo", "cost": 1500, "hp": 110, "armor": 8, "speed": 4, "draw": 2, "output": 10,
		"shape": "dynamo", "color": "#2a2f3a", "maker": "volta"},
	{"id": "volta_arm_1", "kind": "arm", "name": "Arc Fist", "cost": 1300, "hp": 50, "armor": 6, "damage": 24, "speed": 14, "draw": 4,
		"shape": "arcfist", "color": "#00b7ff", "size": 1.1, "maker": "volta", "trait": "stun", "trait_lv": 2},
	{"id": "magnetica_arm_1", "kind": "arm", "name": "Mag Clamp", "cost": 1200, "hp": 46, "armor": 6, "damage": 14, "speed": 10, "draw": 4,
		"shape": "magclamp", "color": "#e0457b", "size": 0.9, "maker": "volta", "trait": "magnet", "trait_lv": 1},
	{"id": "leg_spring", "kind": "leg", "name": "Hot Rod Spring", "cost": 1100, "hp": 52, "armor": 5, "damage": 10, "speed": 32, "draw": 3,
		"shape": "hotrod", "color": "#d6dbe2", "maker": "volta"},
	{"id": "volta_leg_1", "kind": "leg", "name": "Mag-Lev Skid", "cost": 1300, "hp": 56, "armor": 8, "damage": 8, "speed": 24, "draw": 4,
		"shape": "maglev", "color": "#2a2f3a", "maker": "volta", "trait": "hover", "trait_lv": 1},
	{"id": "volta_reactor", "kind": "reactor", "name": "Coil Pack", "cost": 1400, "output": 30, "color": "#00e5ff", "maker": "volta",
		"trait": "stun", "trait_lv": 1},
	{"id": "magnetica_back", "kind": "back", "name": "Neon Spoiler", "cost": 1000, "draw": 2, "shape": "spoiler", "color": "#e0457b",
		"maker": "volta", "gimmick": "sprint"},
	{"id": "volta_twin", "kind": "torso", "name": "Twin Coil", "cost": 2000, "hp": 110, "armor": 6, "speed": 6, "draw": 4,
		"shape": "twincoil", "color": "#d6dbe2", "mounts": ["head2"], "maker": "volta"},
	# ---- Nimbus Aerial (1.101): aerospace. White ceramic, fins, fans, frost; the lightest and the hardest to hit
	{"id": "nimbus_head_1", "kind": "head", "name": "Cockpit Canopy", "cost": 1100, "hp": 42, "armor": 6, "aim": 12, "draw": 3, "chips": 3,
		"shape": "canopy", "color": "#ecf0f1", "maker": "nimbus"},
	{"id": "nimbus_head_2", "kind": "head", "name": "Radar Nose", "cost": 1300, "hp": 40, "armor": 5, "aim": 20, "draw": 3, "chips": 2,
		"shape": "radarnose", "color": "#dfe6e9", "size": 0.95, "maker": "nimbus"},
	{"id": "nimbus_torso_1", "kind": "torso", "name": "Fuselage", "cost": 1400, "hp": 98, "armor": 6, "speed": 14, "draw": 3,
		"shape": "fuselage", "color": "#ecf0f1", "maker": "nimbus", "trait": "dodge", "trait_lv": 2},
	{"id": "frost_torso_1", "kind": "torso", "name": "Cryo Pod", "cost": 1500, "hp": 112, "armor": 8, "speed": 4, "draw": 3,
		"shape": "cryopod", "color": "#74b9ff", "maker": "nimbus", "trait": "frostskin", "trait_lv": 1},
	{"id": "nimbus_arm_1", "kind": "arm", "name": "Wing Blade", "cost": 1200, "hp": 42, "armor": 4, "damage": 18, "speed": 30, "draw": 3,
		"shape": "wingblade", "color": "#ecf0f1", "size": 1.1, "maker": "nimbus"},
	{"id": "nimbus_arm_2", "kind": "arm", "name": "Turbine Arm", "cost": 1400, "hp": 50, "armor": 6, "damage": 16, "speed": 10, "draw": 4,
		"shape": "turbine", "color": "#b2bec3", "size": 0.95, "maker": "nimbus", "trait": "gust", "trait_lv": 1},
	{"id": "nimbus_leg_1", "kind": "leg", "name": "Landing Gear", "cost": 1200, "hp": 52, "armor": 6, "damage": 10, "speed": 22, "draw": 3,
		"shape": "gear", "color": "#dfe6e9", "maker": "nimbus", "gimmick": "high_jump"},
	{"id": "nimbus_leg_2", "kind": "leg", "name": "Ducted Fan", "cost": 1400, "hp": 46, "armor": 4, "damage": 6, "speed": 26, "draw": 4,
		"shape": "ductfan", "color": "#ecf0f1", "maker": "nimbus", "trait": "glide", "trait_lv": 1},
	{"id": "frost_reactor", "kind": "reactor", "name": "Cryo Cell", "cost": 1400, "output": 30, "color": "#74b9ff", "maker": "nimbus",
		"trait": "chill", "trait_lv": 1},
	{"id": "nimbus_back", "kind": "back", "name": "Jet Wings", "cost": 1500, "draw": 3, "shape": "jetwings", "color": "#ecf0f1",
		"maker": "nimbus", "gimmick": "double_jump"},
	{"id": "nimbus_biplane", "kind": "torso", "name": "Biplane Frame", "cost": 2100, "hp": 108, "armor": 6, "speed": 2, "draw": 4,
		"shape": "biplane", "color": "#ecf0f1", "mounts": ["arm_front2", "arm_back2"], "maker": "nimbus"},
]

## Old parts the new lines replace.
const RETIRED := ["torso_box", "torso_plate", "torso_tank", "arm_rod", "arm_bulky", "leg_steel", "leg_pillar", "back_battery",
		"ironclad_head_2", "ironclad_arm_1", "ironclad_leg_2", "fork_head", "fork_torso", "fork_arm", "fork_leg",
		"scrap_hydra", "torso_rib",
		"head_cyclops", "torso_core", "arm_piston", "arm_grapple", "leg_piston", "reactor_cap", "reactor_regen",   # (1.98) Brassworks
		"torso_hex", "torso_cannon", "arm_spike", "arm_hammer", "arm_saw", "leg_thick", "reactor_over", "back_spikes",   # (1.99) Hellfire
		"pyro_head_2", "pyro_torso_2", "pyro_arm_2", "pyro_leg_2", "boom_head_2", "boom_torso_2", "boom_arm_2", "boom_leg_2", "pyro_reactor",
		"volta_arm_2", "volta_leg_2", "magnetica_head_1", "magnetica_head_2", "magnetica_torso_1", "magnetica_torso_2",   # (1.100) Volta
		"magnetica_arm_2", "magnetica_leg_1", "magnetica_leg_2", "head_visor", "head_bulb", "head_tv", "leg_pogo", "reactor_arc",
		"frost_head_1", "frost_head_2", "frost_torso_2", "frost_arm_1", "frost_arm_2", "frost_leg_1", "frost_leg_2", "nimbus_torso_2",   # (1.101) Nimbus
		"head_dome", "head_wedge", "head_dish", "torso_slim", "leg_wheel", "reactor_cell", "back_jet"]

## The makers whose lines are in (their launch posts once on BotMedia).
const LAUNCHED := ["oldiron", "scrapworks", "brassworks", "hellfire", "volta", "nimbus"]
## (1.98) Makers with their own shop in the city: Parts-R-Us stops stocking them.
const OWN_SHOP := {"brassworks": "brassworks", "hellfire": "breakers", "volta": "showroom", "nimbus": "hangar"}


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
