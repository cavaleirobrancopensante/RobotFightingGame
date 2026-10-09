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
