extends RefCounted
## Special moves (sold as training chips) and gadget parts.
##
## Special moves are triggered by an input sequence ending in a button:
##   F = toward the enemy, B = away, D = down, U = up, P = punch, K = kick
## e.g. ["D", "F", "P"] = down, toward, punch. Tap the directions one after another, quickly.
##
## Move fields (all optional except the ones every move needs):
##   pose      - which animation to show: punch / kick / uppercut / sweep / block
##   limb      - "arm" or "leg": needs a working limb of that kind (and uses its damage bonus)
##   startup / active / recovery - timing in seconds
##   hits, interval - multi-hit moves
##   damage, reach, height (high/mid/low), zone (which parts it can hit), stun, knock, launch
##   dash      - forward speed while active; rise - upward speed at start (jumping moves)
##   unblockable, emp (stun seconds), projectile, counter (seconds), air (only in the air)

const SEQ_WINDOW := 0.7    # max seconds between inputs of a sequence (generous for touch screens)

const MOVES := {
	"rocket_punch": {"name": "Rocket Punch", "seq": ["D", "F", "P"], "cost": 400, "cd": 3.0,
		"desc": "Dash forward with a flying punch.",
		"pose": "punch", "limb": "arm", "startup": 0.12, "active": 0.22, "recovery": 0.25, "dash": 700.0,
		"damage": 15.0, "reach": 85.0, "height": "mid", "zone": "punch", "knock": 420.0, "stun": 0.35},
	"shoulder_charge": {"name": "Shoulder Charge", "seq": ["F", "F", "P"], "cost": 300, "cd": 4.0,
		"desc": "Charge in shoulder-first and bulldoze the enemy back.",
		"pose": "block", "startup": 0.1, "active": 0.3, "recovery": 0.25, "dash": 820.0,
		"damage": 11.0, "reach": 70.0, "height": "mid", "zone": "torso", "knock": 700.0, "stun": 0.4},
	"haymaker": {"name": "Haymaker", "seq": ["B", "F", "P"], "cost": 600, "cd": 5.0,
		"desc": "Big wind-up punch that always lands on your target.",
		"pose": "punch", "limb": "arm", "startup": 0.35, "active": 0.1, "recovery": 0.3,
		"damage": 24.0, "reach": 92.0, "height": "mid", "zone": "punch", "knock": 520.0, "stun": 0.5, "sure_aim": true},
	"piston_barrage": {"name": "Piston Barrage", "seq": ["F", "B", "F", "P"], "cost": 900, "cd": 5.0,
		"desc": "Five rapid-fire jabs.",
		"pose": "punch", "limb": "arm", "startup": 0.08, "active": 0.6, "recovery": 0.2, "hits": 5, "interval": 0.11,
		"damage": 5.0, "reach": 88.0, "height": "mid", "zone": "punch", "knock": 120.0, "stun": 0.22, "jab": true},
	"tornado_kick": {"name": "Tornado Kick", "seq": ["D", "B", "K"], "cost": 800, "cd": 5.0,
		"desc": "Three spinning kicks that carry you forward.",
		"pose": "kick", "limb": "leg", "startup": 0.1, "active": 0.5, "recovery": 0.25, "hits": 3, "interval": 0.16,
		"dash": 260.0, "damage": 7.0, "reach": 100.0, "height": "mid", "zone": "kick", "knock": 200.0, "stun": 0.3, "spin": true},
	"scissor_sweep": {"name": "Scissor Sweep", "seq": ["D", "D", "K"], "cost": 500, "cd": 4.0,
		"desc": "Two low sweeps that knock the enemy off balance. Block it crouching!",
		"pose": "sweep", "limb": "leg", "startup": 0.1, "active": 0.36, "recovery": 0.3, "hits": 2, "interval": 0.17,
		"damage": 8.0, "reach": 112.0, "height": "low", "zone": "sweep", "knock": 150.0, "stun": 0.6},
	"bolt_toss": {"name": "Bolt Toss", "seq": ["B", "B", "P"], "cost": 350, "cd": 2.5,
		"desc": "Throw a red-hot bolt across the ring.",
		"pose": "punch", "limb": "arm", "startup": 0.15, "active": 0.05, "recovery": 0.2,
		"projectile": "bolt", "damage": 9.0, "zone": "punch", "speed": 900.0},
	"emp_pulse": {"name": "EMP Pulse", "seq": ["D", "D", "P"], "cost": 1000, "cd": 8.0,
		"desc": "Short-range electric shock that stuns the enemy. Can't be blocked.",
		"pose": "block", "startup": 0.15, "active": 0.15, "recovery": 0.3,
		"damage": 4.0, "reach": 140.0, "height": "mid", "zone": "head_torso", "unblockable": true, "emp": 1.2, "knock": 80.0},
	"grab_slam": {"name": "Grab & Slam", "seq": ["F", "B", "P"], "cost": 1100, "cd": 6.0,
		"desc": "Grab the enemy and slam it down. Ignores blocks.",
		"pose": "punch", "limb": "arm", "startup": 0.1, "active": 0.1, "recovery": 0.4,
		"damage": 18.0, "reach": 75.0, "height": "mid", "zone": "torso", "unblockable": true, "launch": -520.0, "stun": 0.7, "knock": -150.0},
	"dive_stomp": {"name": "Dive Stomp", "seq": ["D", "K"], "cost": 700, "cd": 3.0, "air": true,
		"desc": "In mid-air only: dive down feet-first onto the enemy.",
		"pose": "kick", "limb": "leg", "startup": 0.05, "active": 0.45, "recovery": 0.15, "dash": 420.0, "dive": 950.0,
		"damage": 15.0, "reach": 95.0, "height": "mid", "zone": "head_torso", "knock": 300.0, "stun": 0.45},
	"counter_protocol": {"name": "Counter Protocol", "seq": ["B", "B", "K"], "cost": 900, "cd": 6.0,
		"desc": "Brace for 0.6s. If you get hit, take no damage and strike back hard.",
		"pose": "block", "startup": 0.0, "active": 0.6, "recovery": 0.2, "counter": 0.6,
		"damage": 16.0, "reach": 120.0, "height": "mid", "zone": "punch", "knock": 500.0, "stun": 0.5},
	"rising_piston": {"name": "Rising Piston", "seq": ["F", "D", "F", "P"], "cost": 1400, "cd": 5.0,
		"desc": "Jumping uppercut. Briefly invincible, launches the enemy.",
		"pose": "uppercut", "limb": "arm", "startup": 0.05, "active": 0.28, "recovery": 0.3, "rise": 680.0, "dash": 200.0,
		"damage": 17.0, "reach": 82.0, "height": "mid", "zone": "uppercut", "launch": -760.0, "stun": 0.6, "invuln": 0.22},
	"lightning_legs": {"name": "Lightning Legs", "seq": ["F", "F", "K"], "cost": 1000, "cd": 5.0,
		"desc": "A flurry of four lightning-fast kicks.",
		"pose": "kick", "limb": "leg", "startup": 0.08, "active": 0.6, "recovery": 0.22, "hits": 4, "interval": 0.14,
		"damage": 6.0, "reach": 102.0, "height": "mid", "zone": "kick", "knock": 140.0, "stun": 0.25, "jab": true},
	"scrap_fury": {"name": "Scrap Fury", "seq": ["D", "F", "D", "F", "P"], "cost": 2500, "cd": 12.0,
		"desc": "ULTIMATE: a six-hit frenzy that ends in a launcher.",
		"pose": "punch", "limb": "arm", "startup": 0.1, "active": 0.9, "recovery": 0.35, "hits": 6, "interval": 0.14,
		"dash": 140.0, "damage": 6.0, "reach": 90.0, "height": "mid", "zone": "punch", "knock": 100.0, "stun": 0.3,
		"jab": true, "finisher": true},

	# --- signature moves: every fighting style knows one for free (not sold as chips)
	"bulwark_slam": {"name": "Bulwark Slam", "seq": ["B", "F", "K"], "cost": 0, "cd": 7.0, "style": "tank",
		"desc": "TANK SIGNATURE: a shoulder slam that flattens the enemy and hardens your armor (+15) for 4s.",
		"pose": "block", "startup": 0.18, "active": 0.22, "recovery": 0.3, "dash": 520.0,
		"damage": 16.0, "reach": 80.0, "height": "mid", "zone": "torso", "knock": 650.0, "stun": 0.55, "effect": "armor_up"},
	"flurry": {"name": "Striker Flurry", "seq": ["D", "F", "K"], "cost": 0, "cd": 7.5, "style": "striker",
		"desc": "STRIKER SIGNATURE: four lightning jabs ending in a launcher.",
		"pose": "punch", "limb": "arm", "startup": 0.06, "active": 0.56, "recovery": 0.22, "hits": 4, "interval": 0.13,
		"damage": 5.0, "reach": 92.0, "height": "mid", "zone": "punch", "knock": 160.0, "stun": 0.28, "jab": true, "finisher": true},
	"field_repair": {"name": "Field Repair", "seq": ["B", "D", "P"], "cost": 0, "cd": 14.0, "style": "mechanic",
		"desc": "MECHANIC SIGNATURE: weld yourself back together. Repairs your torso and your most damaged part. Do it at a distance!",
		"pose": "block", "startup": 0.1, "active": 0.5, "recovery": 0.2, "damage": 0.0, "nohit": true, "effect": "repair"},
	# --- part signatures (1.104): come with a pair of parts, never sold as chips
	"chest_pound": {"name": "Chest Pound", "seq": ["D", "U", "P"], "cost": 0, "cd": 12.0, "part_sig": true,
		"desc": "GORILLA SIGNATURE: pound the chest and roar. Thick plating for a few seconds, anyone close is shoved back and loses their aim.",
		"pose": "block", "startup": 0.12, "active": 0.75, "recovery": 0.25, "damage": 0.0, "nohit": true, "effect": "chest_pound"},
	"dragon_crest": {"name": "Dragon Crest", "seq": ["B", "F", "B", "F", "P"], "cost": 0, "cd": 14.0, "part_sig": true,
		"desc": "PROTOTYPE SIGNATURE: the crest blazes and you rise through five strikes, the last one a launcher.",
		"pose": "uppercut", "limb": "arm", "startup": 0.08, "active": 0.75, "recovery": 0.35, "hits": 5, "interval": 0.14,
		"dash": 220.0, "damage": 8.0, "reach": 92.0, "height": "mid", "zone": "uppercut", "knock": 120.0, "stun": 0.3,
		"jab": true, "finisher": true, "launch": -700.0},
	"overclock": {"name": "Overclock", "seq": ["F", "B", "K"], "cost": 0, "cd": 16.0, "style": "specialist",
		"desc": "SPECIALIST SIGNATURE: instantly recharge every gadget and move 30% faster for 4s.",
		"pose": "uppercut", "startup": 0.05, "active": 0.2, "recovery": 0.15, "damage": 0.0, "nohit": true, "effect": "overclock"},
}

# Which parts a move's "zone" can land on (and how often when you're not aiming)
const ZONES := {
	"punch": {"head": 0.25, "head2": 0.12, "torso": 0.45, "arm_front": 0.25, "arm_back": 0.05, "arm_front2": 0.15, "arm_back2": 0.04},
	"uppercut": {"head": 0.6, "head2": 0.35, "torso": 0.4},
	"kick": {"torso": 0.35, "arm_front": 0.15, "arm_back": 0.05, "arm_front2": 0.12, "arm_back2": 0.04, "leg_front": 0.35, "leg_back": 0.1},
	"sweep": {"leg_front": 0.7, "leg_back": 0.3},
	"torso": {"torso": 1.0},
	"head_torso": {"head": 0.5, "head2": 0.3, "torso": 0.5},
	"arms": {"arm_front": 0.45, "arm_back": 0.25, "arm_front2": 0.3, "arm_back2": 0.15, "head": 0.15, "torso": 0.2},   # (1.93) roundhouse
	"any": {"head": 0.15, "head2": 0.08, "torso": 0.45, "arm_front": 0.15, "arm_back": 0.05, "arm_front2": 0.08, "arm_back2": 0.04, "leg_front": 0.15, "leg_back": 0.05},
}

# Gadgets come from parts. Active ones get a button in the fight (keys U, I, O on a keyboard).
const GADGETS := {
	"rocket_fist": {"name": "Rocket Fist", "short": "FIST", "active": true, "cd": 4.5,
		"desc": "Gadget: launch your fist across the ring. It flies back after."},
	"grapple": {"name": "Grapple Claw", "short": "HOOK", "active": true, "cd": 5.0,
		"desc": "Gadget: fire the claw on a cable and reel the enemy in."},
	"laser": {"name": "Eye Laser", "short": "LASER", "active": true, "cd": 3.5,
		"desc": "Gadget: fire a fast laser beam from your eye."},
	"cannon": {"name": "Chest Cannon", "short": "BOOM", "active": true, "cd": 6.0,
		"desc": "Gadget: fire a heavy shell from your chest."},
	"overcharge": {"name": "Overcharge", "short": "OVER", "active": true, "cd": 9999.0,
		"desc": "Gadget, once per fight: 6s of +50% speed and +40% damage. Then the reactor burns out: -25% speed and -15% damage for the rest of the fight."},
	"emp": {"name": "EMP Burst", "short": "EMP", "active": true, "cd": 10.0,
		"desc": "Gadget: electric burst that stuns anything close for a second."},
	"shield": {"name": "Energy Shield", "short": "SHIELD", "active": true, "cd": 9.0,
		"desc": "Gadget: a bubble that blocks all damage for 2.5s."},
	"booster": {"name": "Booster Dash", "short": "BOOST", "active": true, "cd": 4.0,
		"desc": "Gadget: rocket dash that rams the enemy. Works in mid-air."},
	"steam_burst": {"name": "Steam Burst", "short": "STEAM", "active": true, "cd": 9.0,
		"desc": "Gadget: a cloud of steam hides you for 2s. Their crosshair and scan reset, and hits can miss you in the cloud."},
	"flame_dash": {"name": "Flame Dash", "short": "FLAME", "active": true, "cd": 5.0,
		"desc": "Gadget: the exhausts roar and you ram the enemy through a wall of fire. It sets them burning. Works in mid-air."},
	"bite": {"name": "Bear-Trap Bite", "short": "BITE", "active": true, "cd": 4.0,
		"desc": "Gadget: the jaw lunges and snaps shut on anything close and holds on. The head leans in to do it, so it's easier to hit for a moment."},
	"fan": {"name": "Peacock Fan", "short": "FAN", "active": true, "cd": 10.0,
		"desc": "Gadget: the fan opens for 2.5s. Their crosshair comes off and they can't aim or scan while it's open. The crowd loves it."},
	"trunk": {"name": "Trunk Throw", "short": "THROW", "active": true, "cd": 5.0,
		"desc": "Gadget: the trunk picks up a part torn off in the ring and throws it at them."},
	"sprint": {"name": "Sprint", "short": "", "active": false,
		"desc": "Passive: keep walking the same way for half a second and you speed up by a third."},
	"double_jump": {"name": "Jet Pack", "short": "", "active": false,
		"desc": "Passive: press jump again in mid-air to jump twice."},
	"high_jump": {"name": "Pogo Spring", "short": "", "active": false,
		"desc": "Passive: jump much higher (needs this leg working)."},
	"thorns": {"name": "Spikes", "short": "", "active": false,
		"desc": "Passive: enemies that hit your torso take damage back."},
	"regen": {"name": "Self-Repair", "short": "", "active": false,
		"desc": "Passive: slowly repairs your torso during fights."},
}

const ARROWS := {"F": "→", "B": "←", "D": "↓", "U": "↑", "P": "P", "K": "K"}


static func seq_text(seq: Array) -> String:
	var bits: Array = []
	for t in seq:
		bits.append(ARROWS.get(t, t))
	return " ".join(bits)
