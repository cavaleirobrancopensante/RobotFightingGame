## (1.147) Moves from parts. A part brings its own hits: every maker's arm and leg replaces the two
## outer hits of its button (PUNCH up / down, KICK up / down) with moves of its own shape, the torso's
## maker gives two command moves (back + PUNCH, back + KICK), gripping arms can throw (PUNCH + KICK
## together, up close), and three parts from one maker wake two signature specials (specials.gd,
## "set_sig"). The buttons never move: up is always up, down always down, the middle hit stays the
## limb's own (or its technique chip). A move here is an ATTACKS entry over its base hit: the base's
## numbers, then these changes; "pose" = the hit it's drawn and struck with.
class_name PartMoves

## shape -> [[base hit, id, name, changes], ...]
const SHAPE := {
	# Scrapworks
	"wrench": [["uppercut", "pm_spanner_twist", "Spanner Twist", {"damage": 12.0, "through": 0.3}],
		["low_punch", "pm_knuckle_tap", "Knuckle Tap", {"startup": 0.05, "damage": 5.0, "recovery": 0.16}]],
	"grabber": [["uppercut", "pm_snatch_up", "Snatch Up", {"launch": -760.0, "damage": 9.0}],
		["low_punch", "pm_ankle_grab", "Ankle Grab", {"knock": -260.0, "stun": 0.4, "damage": 5.0}]],
	"pipe": [["high_kick", "pm_pipe_swing", "Pipe Swing", {"pose": "roundhouse", "damage": 11.0, "zone": "arms"}],
		["sweep", "pm_clatter_sweep", "Clatter Sweep", {"damage": 7.0, "knock": 300.0, "stun": 0.45}]],
	"wheel": [["high_kick", "pm_wheelie", "Wheelie", {"pose": "knee", "damage": 12.0, "launch": -520.0}],
		["sweep", "pm_roll_over", "Roll Over", {"damage": 9.0, "active": 0.2, "push": 80.0}]],
	# Old Iron Foundry
	"anvil": [["uppercut", "pm_anvil_drop", "Anvil Drop", {"pose": "overhand", "height": "overhead", "damage": 17.0, "startup": 0.26, "stun": 0.6, "telegraph": true}],
		["low_punch", "pm_floor_pound", "Floor Pound", {"damage": 10.0, "startup": 0.14, "knock": 500.0}]],
	"crane": [["uppercut", "pm_hoist", "Hoist", {"launch": -820.0, "damage": 10.0, "startup": 0.16}],
		["low_punch", "pm_hook_haul", "Hook and Haul", {"knock": -380.0, "damage": 7.0, "stun": 0.45}]],
	"stomper": [["high_kick", "pm_stamp_kick", "Stamp Kick", {"pose": "push_kick", "damage": 9.0, "knock": 1100.0, "push": 120.0}],
		["sweep", "pm_ground_shaker", "Ground Shaker", {"damage": 11.0, "startup": 0.18, "stun": 0.55, "knock": 200.0}]],
	"tread": [["high_kick", "pm_track_ram", "Track Ram", {"pose": "push_kick", "damage": 8.0, "knock": 900.0}],
		["sweep", "pm_grind", "Grind", {"damage": 6.0, "active": 0.3, "stun": 0.4}]],
	# Brassworks & Sons
	"gauntlet": [["uppercut", "pm_piston_upper", "Piston Upper", {"damage": 15.0, "startup": 0.16, "launch": -760.0, "steam": 0.6}],
		["low_punch", "pm_valve_jab", "Valve Jab", {"damage": 6.0, "steam": 0.5}]],
	"riveter": [["uppercut", "pm_rivet_burst", "Rivet Burst", {"pose": "punch", "damage": 9.0, "startup": 0.05, "active": 0.16, "recovery": 0.18}],
		["low_punch", "pm_rivet_spray", "Rivet Spray", {"damage": 5.0, "startup": 0.04, "recovery": 0.14}]],
	"bellows": [["high_kick", "pm_bellows_blast", "Bellows Blast", {"pose": "push_kick", "knock": 1200.0, "push": 140.0, "steam": 0.8, "damage": 3.0}],
		["sweep", "pm_wheeze_sweep", "Wheeze Sweep", {"damage": 8.0, "stun": 0.5}]],
	"tripod": [["high_kick", "pm_tripod_thrust", "Tripod Thrust", {"pose": "push_kick", "damage": 9.0, "knock": 700.0}],
		["sweep", "pm_third_leg", "Third Leg", {"damage": 7.0, "startup": 0.08}]],
	# Hellfire Heavy
	"wrecker": [["uppercut", "pm_wrecking_swing", "Wrecking Swing", {"pose": "overhand", "damage": 20.0, "startup": 0.3, "recovery": 0.5, "knock": 700.0, "telegraph": true}],
		["low_punch", "pm_chain_drag", "Chain Drag", {"knock": -420.0, "damage": 8.0}]],
	"torch": [["uppercut", "pm_flare_up", "Flare Up", {"damage": 10.0, "burn": 4.0}],
		["low_punch", "pm_floor_torch", "Floor Torch", {"damage": 6.0, "burn": 3.0, "zone": "sweep"}]],
	"excavator": [["high_kick", "pm_bucket_lift", "Bucket Lift", {"pose": "knee", "launch": -700.0, "damage": 12.0}],
		["sweep", "pm_dig_in", "Dig In", {"damage": 10.0, "startup": 0.16, "stun": 0.6}]],
	"hydraulic": [["high_kick", "pm_ram_kick", "Ram Kick", {"pose": "push_kick", "damage": 10.0, "knock": 1000.0}],
		["sweep", "pm_piston_stamp", "Piston Stamp", {"pose": "axe_kick", "height": "overhead", "damage": 14.0, "startup": 0.22}]],
	# Volta Motor
	"arcfist": [["uppercut", "pm_arc_upper", "Arc Upper", {"damage": 12.0, "stun": 0.7}],
		["low_punch", "pm_spark_jab", "Spark Jab", {"damage": 6.0, "stun": 0.38, "startup": 0.05}]],
	"magclamp": [["uppercut", "pm_mag_lift", "Mag Lift", {"launch": -900.0, "damage": 8.0}],
		["low_punch", "pm_attract", "Attract", {"knock": -520.0, "damage": 4.0, "stun": 0.3}]],
	"hotrod": [["high_kick", "pm_spring_heel", "Spring Heel", {"damage": 13.0, "startup": 0.12}],
		["sweep", "pm_burnout", "Burnout", {"damage": 8.0, "active": 0.22, "push": 120.0}]],
	"maglev": [["high_kick", "pm_glide_kick", "Glide Kick", {"pose": "roundhouse", "damage": 11.0}],
		["sweep", "pm_skid", "Skid", {"damage": 7.0, "startup": 0.08, "knock": 400.0}]],
	# Nimbus Aerial
	"wingblade": [["uppercut", "pm_wing_cut", "Wing Cut", {"pose": "hook", "through": 0.5, "damage": 10.0}],
		["low_punch", "pm_trim_tab", "Trim Tab", {"damage": 7.0, "startup": 0.05, "recovery": 0.14}]],
	"turbine": [["uppercut", "pm_updraft", "Updraft", {"launch": -950.0, "damage": 7.0}],
		["low_punch", "pm_jet_wash", "Jet Wash", {"pose": "shove", "knock": 1100.0, "push": 140.0, "damage": 3.0}]],
	"gear": [["high_kick", "pm_touchdown", "Touchdown", {"pose": "axe_kick", "height": "overhead", "damage": 13.0}],
		["sweep", "pm_taxi_sweep", "Taxi Sweep", {"damage": 7.0, "active": 0.2}]],
	"ductfan": [["high_kick", "pm_fan_kick", "Fan Kick", {"pose": "roundhouse", "damage": 10.0, "knock": 600.0}],
		["sweep", "pm_downdraft", "Downdraft", {"damage": 6.0, "stun": 0.5, "push": 90.0}]],
	# Kane Dynamics
	"executor": [["uppercut", "pm_drill_upper", "Drill Upper", {"damage": 14.0, "through": 0.4}],
		["low_punch", "pm_bore", "Bore", {"damage": 8.0, "startup": 0.06}]],
	"lancet": [["uppercut", "pm_lance_rise", "Lance Rise", {"damage": 12.0, "launch": -650.0}],
		["low_punch", "pm_long_thrust", "Long Thrust", {"pose": "punch", "damage": 10.0, "startup": 0.1}]],
	"stride": [["high_kick", "pm_precision_kick", "Precision Kick", {"damage": 13.0, "startup": 0.13}],
		["sweep", "pm_clean_sweep", "Clean Sweep", {"damage": 9.0, "stun": 0.45}]],
	"gravpad": [["high_kick", "pm_grav_lift", "Grav Lift", {"pose": "knee", "launch": -800.0, "damage": 10.0}],
		["sweep", "pm_null_field", "Null Field", {"damage": 6.0, "stun": 0.6}]],
	# Tenryu Mecha Works
	"rocket": [["uppercut", "pm_rising_rocket", "Rising Rocket", {"damage": 15.0, "launch": -900.0, "startup": 0.14}],
		["low_punch", "pm_booster_jab", "Booster Jab", {"damage": 8.0, "knock": 500.0}]],
	"beamsword": [["uppercut", "pm_rising_slash", "Rising Slash", {"damage": 16.0, "through": 0.6, "startup": 0.14}],
		["low_punch", "pm_low_slash", "Low Slash", {"damage": 9.0, "zone": "sweep", "through": 0.4}]],
	"greaves": [["high_kick", "pm_thruster_kick", "Thruster Kick", {"damage": 14.0, "knock": 600.0}],
		["sweep", "pm_flash_sweep", "Flash Sweep", {"damage": 9.0, "startup": 0.08}]],
	"hakama": [["high_kick", "pm_iai_kick", "Iai Kick", {"pose": "axe_kick", "height": "overhead", "damage": 14.0}],
		["sweep", "pm_rooted_sweep", "Rooted Sweep", {"damage": 10.0, "stun": 0.55}]],
	# Menagerie Mechanica
	"gorilla": [["uppercut", "pm_ape_upper", "Ape Upper", {"damage": 16.0, "launch": -800.0, "startup": 0.18}],
		["low_punch", "pm_knuckle_drag", "Knuckle Drag", {"damage": 10.0, "knock": 500.0}]],
	"tentacle": [["uppercut", "pm_tentacle_lash", "Tentacle Lash", {"damage": 10.0, "through": 0.6}],
		["low_punch", "pm_sucker_grab", "Sucker Grab", {"knock": -460.0, "damage": 6.0, "stun": 0.4}]],
	"arachnid": [["high_kick", "pm_fang_kick", "Fang Kick", {"pose": "knee", "damage": 13.0}],
		["sweep", "pm_web_sweep", "Web Sweep", {"damage": 7.0, "stun": 0.7}]],
	"gecko": [["high_kick", "pm_tail_whip", "Tail Whip", {"pose": "roundhouse", "damage": 11.0, "zone": "arms"}],
		["sweep", "pm_wall_kick", "Wall Kick", {"pose": "push_kick", "damage": 6.0, "knock": 900.0}]],
}

## The torso's maker: [back + PUNCH, back + KICK] = [base hit, id, name, changes]
const COMMANDS := {
	"scrapworks": [["punch", "cm_scrap_shove", "Scrap Shove", {"pose": "shove", "knock": 1000.0, "push": 150.0, "damage": 3.0}],
		["kick", "cm_rusty_knee", "Rusty Knee", {"pose": "knee", "damage": 13.0}]],
	"oldiron": [["punch", "cm_piston_elbow", "Piston Elbow", {"pose": "elbow", "damage": 14.0, "knock": 400.0}],
		["kick", "cm_boiler_stomp", "Boiler Stomp", {"pose": "axe_kick", "height": "overhead", "damage": 15.0, "startup": 0.26}]],
	"brassworks": [["punch", "cm_steam_push", "Steam Push", {"pose": "shove", "steam": 1.0, "knock": 900.0, "push": 130.0, "damage": 3.0}],
		["kick", "cm_gear_knee", "Gear Knee", {"pose": "knee", "damage": 13.0}]],
	"hellfire": [["punch", "cm_fire_haymaker", "Fire Haymaker", {"pose": "overhand", "burn": 4.0, "damage": 15.0, "telegraph": true}],
		["kick", "cm_bulldozer_kick", "Bulldozer Kick", {"pose": "push_kick", "knock": 1200.0, "push": 160.0, "damage": 5.0}]],
	"volta": [["punch", "cm_spark_backfist", "Spark Backfist", {"pose": "hook", "stun": 0.5, "damage": 9.0}],
		["kick", "cm_kickstart", "Kickstart", {"pose": "roundhouse", "damage": 12.0}]],
	"nimbus": [["punch", "cm_banking_elbow", "Banking Elbow", {"pose": "elbow", "damage": 11.0}],
		["kick", "cm_barrel_roll_kick", "Barrel Roll Kick", {"pose": "roundhouse", "damage": 12.0, "knock": 600.0}]],
	"kane": [["punch", "cm_executive_order", "Executive Order", {"pose": "punch", "damage": 13.0, "startup": 0.12, "through": 0.3}],
		["kick", "cm_hostile_takeover", "Hostile Takeover", {"pose": "axe_kick", "height": "overhead", "damage": 15.0}]],
	"tenryu": [["punch", "cm_spirit_palm", "Spirit Palm", {"pose": "shove", "knock": 1100.0, "push": 150.0, "damage": 6.0}],
		["kick", "cm_crescent_kick", "Crescent Kick", {"pose": "roundhouse", "damage": 13.0}]],
	"menagerie": [["punch", "cm_beast_shove", "Beast Shove", {"pose": "shove", "knock": 1000.0, "push": 140.0, "damage": 4.0}],
		["kick", "cm_hoof_kick", "Hoof Kick", {"pose": "push_kick", "damage": 10.0, "knock": 900.0}]],
}

## Arms that can grip, so they can throw: PUNCH + KICK together, up close. Beats a guard, loses to any hit.
const GRIP := ["crane", "grabber", "magclamp", "tentacle", "gorilla", "claw", "grapple"]
const THROW := {"startup": 0.12, "active": 0.08, "recovery": 0.45, "reach": 60.0, "damage": 12.0, "height": "mid", "stun": 0.7,
		"limb": "arm", "zone": "torso", "family": "punch", "pose": "punch", "unblockable": true, "launch": -480.0, "knock": -200.0, "throw": true}
const THROW_RANGE := 120.0
const MAX_INPUTS := 6   # specials with their own inputs on one robot (chips + signatures)

const NAMES := {"throw": "Throw"}


## Every part move as an ATTACKS entry (built over its base hit).
static func attacks(base: Dictionary) -> Dictionary:
	var out := {"throw": THROW.duplicate()}
	for shape in SHAPE:
		for m in SHAPE[shape]:
			out[m[1]] = _build(base, m)
	for mk in COMMANDS:
		for m in COMMANDS[mk]:
			out[m[1]] = _build(base, m)
	return out


static func _build(base: Dictionary, m: Array) -> Dictionary:
	var d: Dictionary = (base[m[0]] as Dictionary).duplicate()
	d["pose"] = m[0]
	for k in m[3]:
		d[k] = m[3][k]
	d["name"] = m[2]
	return d


## The move this limb throws instead of `attack`, or "".
static func shape_move(shape: String, attack: String) -> String:
	for m in SHAPE.get(shape, []):
		if m[0] == attack:
			return m[1]
	return ""


## back + PUNCH / back + KICK for a torso by this maker, or "".
static func command(maker: String, button: String) -> String:
	for m in COMMANDS.get(maker, []):
		if m[0] == button:
			return m[1]
	return ""


static func name_of(id: String) -> String:
	if NAMES.has(id):
		return NAMES[id]
	for shape in SHAPE:
		for m in SHAPE[shape]:
			if m[1] == id:
				return m[2]
	for mk in COMMANDS:
		for m in COMMANDS[mk]:
			if m[1] == id:
				return m[2]
	return ""


## What a part brings, for the shop and the detail pane: [[button text, move name], ...]
static func of_part(d: Dictionary) -> Array:
	var out: Array = []
	var shape := str(d.get("shape", ""))
	var kind := str(d.get("kind", ""))
	for m in SHAPE.get(shape, []):
		out.append([{"uppercut": "PUNCH ▲", "low_punch": "PUNCH ▼", "high_kick": "KICK ▲", "sweep": "KICK ▼"}.get(m[0], ""), m[2]])
	if kind == "arm" and GRIP.has(shape):
		out.append(["PUNCH + KICK", "Throw"])
	if kind == "torso":
		for m in COMMANDS.get(str(d.get("maker", "")), []):
			out.append(["◀ + " + ("PUNCH" if m[0] == "punch" else "KICK"), m[2]])
	return out
