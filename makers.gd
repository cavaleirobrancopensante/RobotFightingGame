extends RefCounted
## (1.90) The makers: the companies that build every part in Port Ferrum (study: "Robot Fighting ·
## Parts & Makers Study" doc). Each part's definition carries "maker" (one of MAKERS' ids, or ""
## for nameless junk). A maker has a look (colours, logo, finish), a fight trait family, and a set
## perk that wakes up when 3 or more of its parts are on a robot.

const SET_AT := 3

const MAKERS := {
	"scrapworks": {"label": "Scrapworks", "name": "Scrapworks", "short": "SCRAPWORKS", "logo": "mk_scrapworks", "color": "#a1887f", "ink": "#3b2a22",
		"pitch": "Found, fixed, and good enough. Cheap to buy, cheap to mend.",
		"perk": "Repairs cost a third less.", "perk_name": "PATCH JOB"},
	"oldiron": {"label": "Old Iron", "name": "Old Iron Foundry", "short": "OLD IRON", "logo": "mk_oldiron", "color": "#c0392b", "ink": "#2b2b2b",
		"pitch": "Cast iron and big bolts since 1951. Built to take it.",
		"perk": "Launchers can't knock the robot down.", "perk_name": "IRON FEET"},
	"brassworks": {"label": "Brassworks", "name": "Brassworks & Sons", "short": "BRASSWORKS", "logo": "mk_brassworks", "color": "#c9a227", "ink": "#3a2a10",
		"pitch": "Hand built in Old Town. Brass, steam and patience.",
		"perk": "Power refills a quarter faster.", "perk_name": "FULL STEAM"},
	"hellfire": {"label": "Hellfire", "name": "Hellfire Heavy", "short": "HELLFIRE", "logo": "mk_hellfire", "color": "#e67e22", "ink": "#1f1f1f",
		"pitch": "Demolition gear. If it isn't on fire, it isn't trying.",
		"perk": "Burns last twice as long, and exploding parts blast half again harder.", "perk_name": "FIREPROOF"},
	"volta": {"label": "Volta", "name": "Volta Motor", "short": "VOLTA", "logo": "mk_volta", "color": "#00b7ff", "ink": "#101828",
		"pitch": "Chrome, neon and a charge in every punch.",
		"perk": "Every hit has a 6% extra chance to shock.", "perk_name": "LIVE WIRE"},
	"nimbus": {"label": "Nimbus", "name": "Nimbus Aerial", "short": "NIMBUS", "logo": "mk_nimbus", "color": "#81ecec", "ink": "#16323a",
		"pitch": "Aerospace engineering for the ring. Light, cool, hard to hit.",
		"perk": "Falls slowly after a jump: a short glide.", "perk_name": "TAILWIND"},
	"kane": {"label": "Kane", "name": "Kane Dynamics", "short": "KANE", "logo": "kane", "color": "#e0b84a", "ink": "#141414",
		"pitch": "The future, delivered. For those who can afford it.",
		"perk": "Aim and scan a quarter faster.", "perk_name": "KANE OPTICS"},
	"tenryu": {"label": "Tenryu", "name": "Tenryu Mecha Works", "short": "TENRYU", "logo": "mk_tenryu", "color": "#e63946", "ink": "#1d3557",
		"pitch": "Hero machines from across the sea. Strike a pose, call your move.",
		"perk": "Special moves cost a quarter less power.", "perk_name": "COMBINATION"},
	"menagerie": {"label": "Menagerie", "name": "Menagerie Mechanica", "short": "MENAGERIE", "logo": "mk_menagerie", "color": "#d63031", "ink": "#2a1010",
		"pitch": "Roll up, roll up! Machines with a wild side.",
		"perk": "The crowd loves it: followers grow faster from your wins.", "perk_name": "SHOWSTOPPER"},
}

const ORDER := ["scrapworks", "oldiron", "brassworks", "hellfire", "volta", "nimbus", "kane", "tenryu", "menagerie"]

## The old brands, each now made by one of the makers.
const BRAND_MAKER := {"scrap": "scrapworks", "ironclad": "oldiron", "volta": "volta", "magnetica": "volta",
		"pyro": "hellfire", "boom": "hellfire", "frost": "nimbus", "nimbus": "nimbus", "medix": "brassworks", "kane": "kane"}

## The house parts and the extras, each moved to the maker whose look it has.
const PART_MAKER := {
	"head_box": "oldiron", "head_dome": "nimbus", "head_cyclops": "brassworks", "head_visor": "volta", "head_horned": "tenryu",
	"head_jaw": "menagerie", "head_wedge": "nimbus", "head_bulb": "volta", "head_tv": "volta", "head_dish": "nimbus",
	"head_laser": "kane", "head_mast": "kane",
	"torso_box": "oldiron", "torso_vee": "tenryu", "torso_plate": "oldiron", "torso_core": "brassworks", "torso_tank": "oldiron",
	"torso_rib": "scrapworks", "torso_hex": "hellfire", "torso_cannon": "hellfire", "torso_slim": "nimbus",
	"arm_rod": "oldiron", "arm_piston": "brassworks", "arm_claw": "oldiron", "arm_spike": "hellfire", "arm_bulky": "oldiron",
	"arm_hammer": "hellfire", "arm_rocket": "tenryu", "arm_grapple": "brassworks", "arm_saw": "hellfire", "arm_drill": "kane",
	"leg_steel": "oldiron", "leg_piston": "brassworks", "leg_spring": "volta", "leg_raptor": "kane", "leg_pillar": "oldiron",
	"leg_pogo": "volta", "leg_wheel": "nimbus", "leg_tread": "oldiron", "leg_thick": "hellfire",
	"reactor_diesel": "oldiron", "reactor_cell": "nimbus", "reactor_fusion": "kane", "reactor_arc": "volta",
	"reactor_cap": "brassworks", "reactor_over": "hellfire", "reactor_regen": "brassworks",
	"back_battery": "oldiron", "back_spikes": "hellfire", "back_booster": "tenryu", "back_jet": "nimbus", "back_shield": "kane",
	"volta_reactor": "volta", "pyro_reactor": "hellfire", "frost_reactor": "nimbus", "kane_reactor": "kane",
	"medix_reactor": "brassworks", "boom_reactor": "hellfire", "ironclad_back": "oldiron", "nimbus_back": "nimbus",
	"magnetica_back": "volta", "torso_hydra": "brassworks", "torso_quad": "oldiron", "torso_monster": "hellfire",
	"scrap_hydra": "scrapworks", "scrap_quad": "scrapworks",
}


## (1.92) How each maker's robots move (the robot moves like the maker with the most parts on it).
## bob = walk bounce, cad = step rhythm (looks only, not speed), lean = walking lean, flinch = how far
## a hit knocks it back, squash = landing squash, idle / twitch = guard bob and shoulder twitches,
## fx = its own touch: rattle, stomp (the floor shakes), steam (a chuff each step), lurch (leans into
## everything), bounce (springy, sparks), float (soft landings, a slight hover), glide (no bob at all),
## hero (hero landings, thruster flare on jumps), sway (an animal sway).
const MOTION := {
	"scrapworks": {"bob": 1.1, "cad": 1.0, "lean": 1.0, "flinch": 1.25, "squash": 1.1, "idle": 1.3, "twitch": 2.6, "fx": "rattle"},
	"oldiron": {"bob": 1.7, "cad": 0.78, "lean": 0.6, "flinch": 0.45, "squash": 1.5, "idle": 0.5, "twitch": 0.2, "fx": "stomp"},
	"brassworks": {"bob": 0.9, "cad": 0.95, "lean": 0.7, "flinch": 0.8, "squash": 1.0, "idle": 0.8, "twitch": 0.3, "fx": "steam"},
	"hellfire": {"bob": 1.2, "cad": 0.9, "lean": 2.4, "flinch": 1.0, "squash": 1.2, "idle": 1.0, "twitch": 0.8, "fx": "lurch"},
	"volta": {"bob": 2.0, "cad": 1.25, "lean": 1.0, "flinch": 1.2, "squash": 1.3, "idle": 1.7, "twitch": 1.5, "fx": "bounce"},
	"nimbus": {"bob": 0.5, "cad": 1.05, "lean": 0.8, "flinch": 1.1, "squash": 0.35, "idle": 0.9, "twitch": 0.3, "fx": "float"},
	"kane": {"bob": 0.0, "cad": 1.0, "lean": 0.4, "flinch": 0.6, "squash": 0.5, "idle": 0.3, "twitch": 0.0, "fx": "glide"},
	"tenryu": {"bob": 0.8, "cad": 1.1, "lean": 1.2, "flinch": 0.9, "squash": 1.0, "idle": 1.1, "twitch": 0.4, "fx": "hero"},
	"menagerie": {"bob": 1.0, "cad": 0.95, "lean": 1.0, "flinch": 1.0, "squash": 1.0, "idle": 1.2, "twitch": 0.6, "fx": "sway"},
}
const MOTION_PLAIN := {"bob": 1.0, "cad": 1.0, "lean": 1.0, "flinch": 1.0, "squash": 1.0, "idle": 1.0, "twitch": 1.0, "fx": ""}


## Whose motion and sounds a robot takes: the maker with the most parts (2 or more), a tie going to
## the torso's maker, else the first in ORDER. "" = a mixed robot or junk: the plain motion.
static func motion_maker(ids: Array, torso_id: String = "") -> String:
	var c := counts(ids)
	var best := 0
	for m in c:
		best = maxi(best, int(c[m]))
	if best < 2:
		return ""
	var tm := str(GameData.part_def(torso_id).get("maker", "")) if torso_id != "" else ""
	if tm != "" and int(c.get(tm, 0)) == best:
		return tm
	for m in ORDER:
		if int(c.get(m, 0)) == best:
			return m
	return ""


static func motion(m: String) -> Dictionary:
	return MOTION.get(m, MOTION_PLAIN)


# ---------------------------------------------------------------- the makers out in the world (1.95)

## BotMedia: handles, followers, paint preset (index in GameData.PAINTS, from PAINT_AT), price lean.
const HANDLE := {"scrapworks": "scrapworks", "oldiron": "oldironfoundry", "brassworks": "brassworks_sons", "hellfire": "hellfireheavy",
		"volta": "voltamotor", "nimbus": "nimbusaerial", "kane": "kanedynamics_parts", "tenryu": "tenryumecha", "menagerie": "menagerie"}
const FOLLOWERS := {"scrapworks": 6400, "oldiron": 41000, "brassworks": 23000, "hellfire": 52000, "volta": 88000, "nimbus": 61000,
		"kane": 1200000, "tenryu": 74000, "menagerie": 19000}
const PAINT_AT := 8   # GameData.PAINTS: the makers' colours follow the eight house paints, in ORDER
const MULT := {"scrapworks": 0.6, "oldiron": 0.9, "brassworks": 1.0, "hellfire": 1.0, "volta": 1.0, "nimbus": 1.05, "kane": 1.6, "tenryu": 1.15, "menagerie": 1.0}
## Who they snipe at.
const RIVAL := {"volta": "nimbus", "nimbus": "volta", "oldiron": "kane", "kane": "oldiron", "tenryu": "kane", "hellfire": "brassworks",
		"brassworks": "hellfire", "scrapworks": "kane", "menagerie": "tenryu"}

## Their adverts, in their own voice (%s = one of their parts).
const ADS := {
	"scrapworks": ["Found it, fixed it, priced it to move. The %s.", "Why pay more to lose anyway? Scrapworks %s.", "Held together with pride. And tape. The %s."],
	"oldiron": ["Cast in 1951. Still standing. The %s.", "Big bolts. No nonsense. The Old Iron %s.", "They don't make them like this any more. We do. The %s."],
	"brassworks": ["Hand built in Old Town by the same family for three generations. The %s.", "Patience, brass and a little steam. The %s.", "Polished by hand. Tested by fire. The %s."],
	"hellfire": ["If it isn't on fire, it isn't trying. The %s.", "Demolition grade. Ring tested. The %s.", "Bring a fire extinguisher. The Hellfire %s."],
	"volta": ["Chrome, neon and a charge in every punch. The %s.", "Built for the night drive. The Volta %s.", "Feel the current. The %s."],
	"nimbus": ["Lighter than the wind. Harder to hit. The %s.", "Engineered at altitude. The Nimbus %s.", "They can't hit what they can't catch. The %s."],
	"kane": ["The future, delivered. The %s.", "Precision is not a luxury. It is a standard. The %s.", "For those who can afford to win. The Kane %s."],
	"tenryu": ["Strike a pose. Call your move. The %s!", "From across the sea, a hero machine. The Tenryu %s.", "Combine your spirit with the %s!"],
	"menagerie": ["Roll up, roll up! Behold the %s!", "The crowd goes wild for the %s.", "Nature built it first. We built it louder. The %s."],
}
## Snipes at their rival (%s = the rival's name).
const SNIPES := {
	"volta": ["Some of us like our robots with a pulse. Not naming names, %s.", "Fast is good. Fast and bright is better. Sorry, %s."],
	"nimbus": ["Lightweight beats loud every time. Right, %s?", "Neon doesn't help you dodge, %s."],
	"oldiron": ["We were building robots when %s was a spreadsheet.", "Cast iron doesn't need a software update, %s."],
	"kane": ["Nostalgia is not an engineering principle.", "We welcome all competition. Even the charming kind."],
	"tenryu": ["A machine without a soul is just a machine, %s.", "We challenge %s to a fair fight. Pilots, not programs."],
	"hellfire": ["Steam is for kettles, %s.", "Our parts don't need polishing. They need a fire brigade."],
	"brassworks": ["Anyone can set things on fire, %s. We build things that last.", "Craft over chaos. Always, %s."],
	"scrapworks": ["Same parts as %s. A tenth of the price. Mostly.", "%s charges you for the logo. We charge you for the bolts."],
	"menagerie": ["Robots that pose? We have robots that roar, %s.", "Heroes are boring. Animals are forever."],
}
## Loyal fans of each maker: their handles.
const FANS := {
	"scrapworks": ["TapeAndHope", "ScrapKing_Ray"], "oldiron": ["IronForever", "BigBolt_Bev"], "brassworks": ["BrassBaron", "SteamQueen_Mo"],
	"hellfire": ["BurnItDown_Kai", "HellfireHank"], "volta": ["VoltaVolta88", "NeonNights_Jo"], "nimbus": ["CloudChaser", "AirSpeed_Ana"],
	"kane": ["KaneOrNothing", "FutureIsNow_Lu"], "tenryu": ["TenryuOh_Fan", "SpiritCombine"], "menagerie": ["CircusKid", "BeastMode_Bo"],
}
## Fan and maker lines. Every line in a group takes the same arguments, in the same order.
const FAN_CHEER := ["%s wins in %s parts. Told you.", "Well fought, %s. That's what %s parts do.", "%s plus %s gear equals a win. Simple maths."]   # pilot, maker
const FAN_SULK := ["Not the parts' fault, %s. %s parts deserved better.", "Rough night, %s. %s fans will be fine. Probably."]   # pilot, maker
const FAN_RIVAL_WIN := ["%s won in %s parts. Lucky night.", "Imagine what %s could do without %s parts."]   # pilot, their maker
const FAN_ARGUE := ["%s parts are overrated and everyone knows it.", "Name one title %s ever won. I'll wait.", "%s fans when their robot loses: it was the pilot."]   # the other maker
const FAN_ANSWER := ["Says the %s fan. Cute.", "Come back when %s wins something.", "Ratio. %s fans are seething."]   # the other maker
const FAN_SWITCH := ["Sold out to %s, huh, %s?", "%s parts now? Really, %s?", "Traitor alert: %s parts on %s's robot."]   # new maker, pilot
const SHOUT := ["Another win in %s parts for %s. Proud.", "%s parts, %s's night.", "Built by %s, won by %s. Congratulations."]   # maker, pilot
const SALE := ["%s WEEK: %d%% off every %s part at Parts-R-Us. This week only.", "Sale on at %s! %d%% off %s parts all week."]   # MAKER, pct, maker


static func handle(m: String) -> String:
	return str(HANDLE.get(m, m))


static func paint_of(m: String) -> int:
	return PAINT_AT + maxi(0, ORDER.find(m))


## Which maker a robot's part ids mostly come from, 2 parts or more ("" otherwise): the one people talk about.
static func main_of(ids: Array) -> String:
	var c := counts(ids)
	var best := ""
	var n := 1
	for m in ORDER:
		if int(c.get(m, 0)) > n:
			n = int(c[m])
			best = m
	return best


## A part's name for an advert: no grade in front and no maker's name (the advert says who made it).
static func ad_name(d: Dictionary) -> String:
	var n := str(d.get("name", ""))
	for g in GameData.GRADES:
		if n.begins_with(str(g) + " "):
			n = n.substr(str(g).length() + 1)
	var lab := label(str(d.get("maker", "")))
	if lab != "":
		n = n.replace(lab + " ", "")
	return n.strip_edges()


## One of a maker's shop parts at a grade, picked by rng ("" if it makes none).
static func part_at(m: String, grade: int, rng: RandomNumberGenerator) -> String:
	var opts: Array = []
	for id in GameData.PARTS:
		var d: Dictionary = GameData.PARTS[id]
		if str(d.get("maker", "")) == m and int(d.get("grade", 0)) == grade and d.get("shop", false) and not d.has("variant_of"):
			opts.append(id)
	return "" if opts.is_empty() else str(opts[rng.randi() % opts.size()])


## Which maker built a part definition ("" = nameless junk).
static func of_def(d: Dictionary) -> String:
	if d.has("maker"):
		return str(d["maker"])
	var id := str(d.get("id", ""))
	if PART_MAKER.has(id):
		return PART_MAKER[id]
	var b := str(d.get("brand", ""))
	if BRAND_MAKER.has(b):
		return BRAND_MAKER[b]
	if int(d.get("cost", 0)) <= 0:
		return ""   # junk: no maker's name on it
	return "oldiron"


static func info(m: String) -> Dictionary:
	return MAKERS.get(m, {})


static func short(m: String) -> String:
	return str(MAKERS.get(m, {}).get("short", "JUNK"))


static func color(m: String) -> Color:
	return Color(str(MAKERS.get(m, {}).get("color", "#77706a")))


## The name on its parts ("Old Iron Bastion Helm").
static func label(m: String) -> String:
	return str(MAKERS.get(m, {}).get("label", ""))


static func logo(m: String) -> String:
	return str(MAKERS.get(m, {}).get("logo", ""))


## How many parts of each maker a set of part ids holds: {maker: count}.
static func counts(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		var m := str(GameData.part_def(str(id)).get("maker", ""))
		if m == "":
			continue
		out[m] = int(out.get(m, 0)) + 1
	return out


## The makers whose set perk is awake (3+ parts).
static func sets(ids: Array) -> Array:
	var out: Array = []
	var c := counts(ids)
	for m in ORDER:
		if int(c.get(m, 0)) >= SET_AT:
			out.append(m)
	return out


## The maker with the most parts (ties: the first in ORDER), or "".
static func main_maker(ids: Array) -> String:
	var c := counts(ids)
	var best := ""
	var n := 0
	for m in ORDER:
		if int(c.get(m, 0)) > n:
			n = int(c[m])
			best = m
	return best
