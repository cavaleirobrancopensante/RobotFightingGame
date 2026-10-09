extends RefCounted
## Flavour for the bay's callouts: short notes about what a part is, how it's built and how
## beaten up it is. Shown next to the part you tap on the robot hanging on Gus's gantry.
## Each shape has two notes (a part shows one, picked by its id, so parts of the same shape differ),
## brands add one, and damage adds a warning. Edit freely - keep notes short (they sit in a small box).

const SHAPE := {
	# heads
	"head:bucket": ["Actual bucket. Still holds water", "Eye holes drilled by hand"],
	"head:box": ["Sheet steel, riveted square", "Antenna picks up the radio"],
	"head:dome": ["Pressed steel dome", "Wide-angle eye strip"],
	"head:cyclops": ["One big lens, 180° sweep", "Iris motor whirs when it aims"],
	"head:visor": ["Full-width optic visor", "Night vision, mostly"],
	"head:horned": ["Horns are welded rebar", "Horns: decorative. Allegedly"],
	"head:skull": ["Jaw bolted shut", "Teeth are filed bolts"],
	"head:wedge": ["Wedge nose splits punches", "Fin keeps it pointed forward"],
	"head:tall": ["Antenna mast, 3 bands", "Tall head, long sight lines"],
	"head:bulb": ["Glass dome, hot filament", "Do not tap the glass"],
	"head:tv": ["Old CRT, warm-up 2 s", "Face is a screensaver"],
	"head:dish": ["Radar dish tracks moves", "Dish pings 4 times a second"],
	"head:laser": ["Laser rangefinder", "Red dot never misses (it says)"],
	"head:knight": ["Visor slit, 6 mm", "Plume mount, no plume"],
	"head:orb": ["Sealed sphere, no seams", "Gyro keeps the eye level"],
	"head:speaker": ["Woofer face, 400 W", "Plays the crowd back at them"],
	"head:rivet": ["Cast pail, 200 rivets", "Porthole glass, 2 cm thick"],
	"head:grille": ["Radiator grille for a jaw", "Brow plate takes the punches"],
	"head:peeper": ["Periscope looks over guards", "Bucket, now with a view"],
	"head:busted": ["Screen cracked, still works", "Hit it twice when it flickers"],
	"head:periscope": ["Periscope sees over guards", "Lens ground by hand"],
	"head:divingbell": ["Copper helmet, 12 bolts", "Built for the harbour floor"],
	"head:welder": ["Welding mask, shade 12 glass", "Spits a flame with every hit"],
	"head:beacon": ["Hazard beacon, always turning", "Hard to aim at a flashing light"],
	# torsos
	"torso:barrel": ["Oil drum, two hoops", "Still smells of diesel"],
	"torso:box": ["Boxed steel frame", "Hatch for the battery"],
	"torso:vee": ["V-chest, wide shoulders", "Tapered for a lower stance"],
	"torso:core": ["Glowing core, keep clear", "Core hums at 50 Hz"],
	"torso:tank": ["Riveted tank plating", "Heavy, slow, hard to dent"],
	"torso:slim": ["Slim frame, all spine", "Light chassis, quick turns"],
	"torso:ribcage": ["Open ribs, easy to fix", "Wires run through the ribs"],
	"torso:hex": ["Hex-cell armor shell", "Each cell takes a hit alone"],
	"torso:cannon": ["Chest cannon (blank rounds)", "Muzzle doubles as a vent"],
	"torso:crate": ["Shipping crate, cross-braced", "Stencil still says FRAGILE"],
	"torso:furnace": ["Coal furnace, 600 °C", "Grill doubles as a toaster"],
	"torso:orb": ["Ball chassis, rolls with hits", "Glancing hits slide off"],
	"torso:yoke": ["Two necks, one spine", "Second head mount"],
	"torso:quad": ["Four shoulder mounts", "Extra arms bolt on low"],
	"torso:monster": ["Every mount there is", "Spikes are load-bearing"],
	"torso:engine": ["Straight-six block, cast 1951", "Fins keep it cool under fire"],
	"torso:loco": ["Smokebox door, hand-painted", "Cowcatcher clears the ring"],
	"torso:drum": ["Oil drum, three ribs", "Dents add character, says Gus"],
	"torso:boiler": ["Copper boiler, coal fired", "Watch the gauge, not the fire"],
	"torso:clockwork": ["Gears wound by hand", "Every tick feeds the core"],
	"torso:fueltank": ["Fuel tank, mostly full", "Do not puncture. They will"],
	"torso:hull": ["Bulldozer hull, 4 cm plate", "Hazard stripes, earned"],
	# arms
	"arm:rod": ["Steel pipe, ball fist", "Elbow is a door hinge"],
	"arm:piston": ["Hydraulic piston, 2 t push", "Piston stroke 30 cm"],
	"arm:claw": ["Two-finger claw grip", "Claw closes in 0.2 s"],
	"arm:spike": ["Spiked knuckles", "Spikes hardened twice"],
	"arm:bulky": ["Heavy forearm, big fist", "Fist alone weighs 40 kg"],
	"arm:hammer": ["Sledgehammer head", "Head swings on a pivot"],
	"arm:drill": ["Drill at 1,800 rpm", "Tungsten drill bit"],
	"arm:rocket": ["Rocket fist, it comes back", "Fist launches on a cable"],
	"arm:grapple": ["Grapple hook, 3 m line", "Pulls them in for a hold"],
	"arm:saw": ["Saw spins at 3,200 rpm", "Blade guard removed"],
	"arm:blade": ["Forearm blade, honed", "Blade folds for transport"],
	"arm:flame": ["Flamer nozzle, pilot light on", "Fuel line runs to the torso"],
	"arm:magnet": ["Electromagnet, 1 t pull", "Keep your keys away"],
	"arm:anvil": ["Forged anvil, 90 kg", "The horn finds the gaps"],
	"arm:crane": ["Crane hook, 5 t rated", "Clamps on and won't let go"],
	"arm:wrench": ["36 mm wrench, never lost", "Tightens bolts between rounds"],
	"arm:grabber": ["Litter picker, long reach", "Jaws snap shut on a spring"],
	"arm:gauntlet": ["Brass gauntlet, steam piston", "Valve lets off a puff each hit"],
	"arm:riveter": ["Pneumatic riveter, 9 a second", "Hose runs back to the boiler"],
	"arm:wrecker": ["Wrecking ball, 2 t of iron", "Slow to swing, worse to catch"],
	"arm:torch": ["Cutting torch, 3,000 °C", "Blue flame means it's ready"],
	# legs
	"leg:rod": ["Pipe leg, rubber foot", "Knee is a bike hub"],
	"leg:piston": ["Piston knee, soft landing", "Hydraulic shock absorber"],
	"leg:spring": ["Coil spring, bouncy step", "Spring steel, 40 coils"],
	"leg:reverse": ["Reverse knee, big jumps", "Bird-leg joint"],
	"leg:pillar": ["Solid pillar, won't budge", "Concrete-filled shin"],
	"leg:thick": ["Thick plated leg", "Wide foot, steady stance"],
	"leg:pogo": ["Pogo stick shin", "Boing"],
	"leg:wheel": ["Wheel foot, fast on flat", "Bearings packed in grease"],
	"leg:tread": ["Tank tread, all terrain", "Treads grip the canvas"],
	"leg:blade": ["Blade runner foot", "Carbon spring blade"],
	"leg:hover": ["Hover pad, 5 cm lift", "Fan intake, keep fingers out"],
	"leg:spider": ["Spider leg, low stance", "Three joints, all wobbly"],
	"leg:stomper": ["Cast boot, size 60", "Ankle ram stamps it flat"],
	"leg:pipe": ["Copper pipe, elbow knee", "Leaks a little in the rain"],
	"leg:bellows": ["Leather bellows shin", "Every step puffs"],
	"leg:tripod": ["Three toes, never tips", "Telescoping brass strut"],
	"leg:excavator": ["Excavator track, 12 t rated", "Hydraulics hiss on every step"],
	"leg:hydraulic": ["Hydraulic ram, lands like a press", "Jump, land, feel it in your teeth"],
	# back gear
	"back:battery": ["Spare battery pack", "Hot-swappable cells"],
	"back:spikes": ["Back spikes, no hugs", "Spikes face the grabber"],
	"back:booster": ["Twin boosters", "Burns for a dash"],
	"back:jet": ["Jet pack, two nozzles", "Fuel for a few hops"],
	"back:plating": ["Bolt-on back plating", "Armor where they grab you"],
	"back:wings": ["Folding wings, double jump", "Flaps for balance"],
	"back:shield": ["Pop-up shield arm", "Shield on a swing mount"],
	"back:flywheel": ["Flywheel stores spare power", "Spins up while it rests"],
	"back:tarp": ["Tarp hides what's broken", "Grommets, rope, hope"],
	"back:smokestack": ["Chimney, swept weekly", "One pull and they can't see you"],
	"back:exhaust": ["Truck stacks, straight pipe", "Lights up for a flame dash"],
}

const KIND := {
	"head": ["Sensors and chip slots", "Brain of the outfit"],
	"torso": ["Holds the power core", "Everything bolts to this"],
	"arm": ["Shoulder bolted at 4 points", "Wiring run inside the arm"],
	"leg": ["Hip joint greased today", "Balance motor in the knee"],
	"back": ["Bolted to the back plate", "Clips onto the spine"],
	"reactor": ["Power for every part", "Cooling fins on the casing"],
}

const BRAND := {
	"scrap": "Scrapworks: cheap, honest junk",
	"ironclad": "Old Iron: built like a bunker",
	"volta": "Volta: crackles when it moves",
	"pyro": "Hellfire: runs hot",
	"frost": "Nimbus: frost on the joints",
	"magnetica": "Volta: tools stick to it",
	"kane": "Kane Dynamics: serial filed off",
	"nimbus": "Nimbus: light as a kite",
	"medix": "Brassworks: smells of hot oil",
	"boom": "Hellfire: don't drop it",
}

## (1.90) Parts with no old brand get a line from their maker.
const MAKER := {
	"scrapworks": "Scrapworks: cheap, honest junk",
	"oldiron": "Old Iron: Gus swears by it",
	"brassworks": "Brassworks: hand built, still warm",
	"hellfire": "Hellfire: smells of scorched paint",
	"volta": "Volta: hums when it's idle",
	"nimbus": "Nimbus: lighter than it looks",
	"kane": "Kane Dynamics: serial filed off",
	"menagerie": "Menagerie: came off a circus ship",
}

# [a bit beaten up (under 60%), badly beaten up (under 30%)] per kind
const DAMAGE := {
	"head": [["Dented, one eye flickers", "Cracked lens"], ["Hanging by its wires", "Sees double"]],
	"torso": [["Bent frame, rattles", "Plates sprung loose"], ["Core exposed!", "Sparks in the chest"]],
	"arm": [["Elbow loose", "Fist knocked out of true"], ["Hanging by two bolts", "Shoulder half torn off"]],
	"leg": [["Bent strut", "Knee clicks"], ["Knee about to fold", "Foot dragging"]],
	"back": [["Mount bracket bent", "Rattling about"], ["Barely attached", "Leaking"]],
	"reactor": [["Running warm", "Power flickers"], ["Overheating!", "Smoke from the vents"]],
}


## The callout lines for a part: [what it is, its brand or build, damage warning ("!" = red)].
static func notes(d: Dictionary, kind: String, health: float, seed_text: String) -> Array:
	var pick := absi(hash(seed_text)) % 2
	var out: Array = []
	var shape_key := "%s:%s" % [kind, d.get("shape", "")]
	if SHAPE.has(shape_key):
		out.append(SHAPE[shape_key][pick])
	elif KIND.has(kind):
		out.append(KIND[kind][pick])
	var brand: String = d.get("brand", "")
	if BRAND.has(brand):
		out.append(BRAND[brand])
	elif MAKER.has(str(d.get("maker", ""))):
		out.append(MAKER[str(d["maker"])])
	elif KIND.has(kind) and out.size() == 1 and SHAPE.has(shape_key):
		out.append(KIND[kind][1 - pick])
	if DAMAGE.has(kind) and health < 0.6:
		out.append("!" + DAMAGE[kind][1 if health < 0.3 else 0][pick])
	return out
