extends RefCounted
## The pilot world: every computer pilot in Port Ferrum lives here between fights.
## They have money, a robot made of real parts that wears down, a record, a skill and a
## spending habit. Every month they pay to live, repair, upgrade or sell off parts, and some
## retire (broke, or rich enough to quit) while rookies show up at the scrapyard. Leagues, cups
## and pickup fights draw their pilots from here, and fights between them are decided by their
## robots and skill, not a coin flip.
##
## State lives in GameData.world (saved with the game):
##   {"next": int, "pilots": {"<wid>": pilot}, "news": [{y, w, text}], "season": {tier: [y, week]}}
## pilot: {wid, name, tier, cash, skill, habit, age, w, l, sw, sl, retired, ret_y, ret_why, bot, wear}

const I18n = preload("res://i18n.gd")

## The pyramid, bottom to top. "open" is the unranked pool: pilots with no league at all, who
## live on pickups, cups and the Open Trials at the start of the year.
const TIERS := ["open", "scrap", "rust", "iron", "steel"]
const TIER_SIZE := {"open": 40, "scrap": 64, "rust": 48, "iron": 40, "steel": 32}
## Robot value (sum of part prices) when the world is made: [low, high, skew]. Skew > 1 = most
## pilots near the low end, a few rich ones near the top.
const TIER_VALUE := {"open": [0.0, 900.0, 2.6], "scrap": [300.0, 3000.0, 1.8], "rust": [2500.0, 9000.0, 1.6], "iron": [8000.0, 27000.0, 1.5], "steel": [25000.0, 80000.0, 1.4]}
const TIER_SKILL := {"open": [0.0, 0.1], "scrap": [0.0, 0.16], "rust": [0.1, 0.32], "iron": [0.28, 0.58], "steel": [0.55, 0.95]}
## Per month: what living costs, and what the day job / sponsors pay.
const LIVING := {"open": 300, "scrap": 600, "rust": 1600, "iron": 5000, "steel": 15000}
const INCOME := {"open": [250, 450], "scrap": [400, 800], "rust": [900, 1700], "iron": [1500, 3000], "steel": [4000, 8000]}
## Signing-on money from a sponsor when a pilot moves up a tier.
const SPONSOR := {"scrap": 600, "rust": 3000, "iron": 15000, "steel": 45000}
## Robots stop getting upgrades past this value (a league's robots stay in its grade; the rest of
## the money piles up, and rich pilots retire).
const VALUE_CAP := {"open": 1000.0, "scrap": 2600.0, "rust": 7500.0, "iron": 22000.0, "steel": 66000.0}
## Cash at which a pilot might cash out and retire.
const RICH := {"open": 4000, "scrap": 9000, "rust": 27000, "iron": 80000, "steel": 250000}
## What a league fight pays the winner.
const FIGHT_PAY := {"open": 300, "scrap": 800, "rust": 2400, "iron": 7000, "steel": 21000, "title": 90000, "cup": 2000}
const HABITS := ["saver", "spender", "gambler"]
const SPEND_CHANCE := {"saver": 0.3, "spender": 0.75, "gambler": 0.5}
const UPGRADE_SLOTS := ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back", "reactor", "back"]
const RETIRED_KEEP := 30   # retired pilots kept on the books (oldest are forgotten)

## Names that belong to women (a "JR" / "II" after a name keeps it).
const FEMALE := ["LUPE", "NELL", "PETRA", "MAMA KAY", "NADIA", "WREN", "SAOIRSE", "JUNO", "MILA", "GRETA", "YARA",
		"LOLA", "SVETA", "ROXY", "IMOGEN", "PAZ", "NOOR", "BEA", "ODETTE", "KIT", "PIA", "TOVA", "INES", "SUKI", "MAEVE",
		"DORA", "ZORA", "RINA", "FIFI", "ANYA", "OONA", "TESS", "IRIS", "VERA", "LIV", "KIKI"]
const NAMES := ["DEX", "LUPE", "KOVAC", "BRIGGS", "NELL", "OKAFOR", "TAM", "VASQUEZ", "IVO", "PETRA", "RUSTY JOE",
		"MAMA KAY", "SPROCKET", "TEO", "NADIA", "BIG HUGO", "WREN", "COBALT KID", "FENWICK", "SAOIRSE", "MARCO", "JUNO",
		"OLD PIKE", "BRYN", "HARLOW", "ZEKE", "MILA", "DUNCAN", "AKO", "RAFA", "GRETA", "OTIS", "FINN", "YARA",
		"LOLA", "BENNY", "KENJI", "SVETA", "DIEGO", "ROXY", "CAL", "IMOGEN", "TULLY", "PAZ", "ARLO", "NOOR", "GUNNAR",
		"BEA", "SAL", "ODETTE", "KIT", "MORRIS", "PIA", "LEON", "TOVA", "JAX", "INES", "BARNABY", "SUKI", "ROLF",
		"MAEVE", "ELIO", "DORA", "HANK", "ZORA", "PADDY", "LUCA", "RINA", "BOSCO", "FIFI", "WALT", "ANYA", "DUKE",
		"NICO", "OONA", "GIL", "TESS", "BAZ", "IRIS", "CORMAC", "VERA", "MAC", "LIV", "POPS", "KIKI", "RUFUS"]


# ---------------------------------------------------------------- the world

static func w() -> Dictionary:
	return GameData.world


static func create(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	GameData.world = {"next": 1, "pilots": {}, "news": [], "season": {}}
	for tier in TIERS:
		for k in TIER_SIZE[tier]:
			var r: Array = TIER_VALUE[tier]
			var value: float = lerpf(r[0], r[1], pow(rng.randf(), r[2]))
			var s: Array = TIER_SKILL[tier]
			var p := new_pilot(rng, tier, value, rng.randf_range(s[0], s[1]))
			p["age"] = rng.randi_range(0, 52 * 6)
			p["w"] = rng.randi_range(0, 4) + p["age"] / 26
			p["l"] = rng.randi_range(0, 4) + p["age"] / 30
	return GameData.world


static func new_pilot(rng: RandomNumberGenerator, tier: String, value: float, skill: float) -> Dictionary:
	var wd := w()
	var wid := int(wd["next"])
	wd["next"] = wid + 1
	var living: int = LIVING[tier]
	var p := {"wid": wid, "name": unique_name(rng), "tier": tier, "cash": rng.randi_range(-living, living * 3),
			"skill": skill, "habit": HABITS[rng.randi() % HABITS.size()], "age": 0, "w": 0, "l": 0, "sw": 0, "sl": 0,
			"retired": false, "bot": {}, "wear": {}}
	p["bot"] = build_bot(rng, value, skill)
	wd["pilots"][str(wid)] = p
	p["look"] = make_look(wid, str(p["name"]))
	return p


static func unique_name(rng: RandomNumberGenerator) -> String:
	var taken := {}
	for p in w()["pilots"].values():
		taken[p["name"]] = true
	var pool := NAMES.filter(func(n): return not taken.has(n))
	if not pool.is_empty():
		return pool[rng.randi() % pool.size()]
	for k in 50:   # everybody's used: a son or daughter takes up the family trade
		var n: String = NAMES[rng.randi() % NAMES.size()] + [" JR", " II", " III"][rng.randi() % 3]
		if not taken.has(n):
			return n
	return "PILOT %d" % int(w()["next"])


static func pilot(wid: int) -> Dictionary:
	return w().get("pilots", {}).get(str(wid), {})


static func active(tier: String = "") -> Array:
	var out: Array = []
	for p in w().get("pilots", {}).values():
		if not p["retired"] and (tier == "" or p["tier"] == tier):
			out.append(p)
	return out


## News is stored as an English template plus its values, and translated when it's shown.
## Values "part:<id>" and "stage:<id>" show as that part's / league's name in the current language.
static func news(text: String, args: Array = []) -> void:
	var n: Array = w()["news"]
	n.append({"y": GameData.year, "w": GameData.week, "text": text, "args": args})
	if n.size() > 40:
		n.pop_front()


# ---------------------------------------------------------------- robots

static var _kinds := {}   # kind -> catalog part ids, cheapest first (built once)


static func by_kind(kind: String) -> Array:
	if _kinds.is_empty():
		for id in GameData.ALL_PARTS:
			var k: String = GameData.PARTS[id]["kind"]
			if not _kinds.has(k):
				_kinds[k] = []
			_kinds[k].append(id)
		for k in _kinds:
			_kinds[k].sort_custom(func(a, b): return GameData.PARTS[a]["cost"] < GameData.PARTS[b]["cost"])
	return _kinds.get(kind, [])

## A robot worth about `budget` dollars of parts. The money is shared out over the slots, each
## slot gets the best grade its share buys (most robots are mostly one grade); some pilots blow
## a big piece of it on one part a grade up (that's what Gus warns you about).
static func build_bot(rng: RandomNumberGenerator, budget: float, skill: float) -> Dictionary:
	var bot: Dictionary = GameData.random_bot(rng, 0.0, skill * 3.6)
	var parts: Dictionary = {}
	var slots := ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back", "reactor"]
	for slot in slots:
		parts[slot] = cheapest(rng, GameData.SLOT_KIND[slot])
	bot["parts"] = parts
	var tg := grade_for_value(budget)
	bot["tg"] = tg
	var left := budget
	if budget > 300.0 and rng.randf() < 0.3:
		var slot: String = ["arm_front", "arm_front", "arm_back", "torso", "head", "leg_front"][rng.randi() % 6]
		var big := best_under(GameData.SLOT_KIND[slot], left * rng.randf_range(0.3, 0.5), slot, mini(5, tg + 1))
		if big != "":
			left -= part_cost(big)
			set_part(rng, bot, slot, big)
	var weights := {"head": 0.9, "torso": 1.4, "arm_front": 1.0, "arm_back": 1.0, "leg_front": 0.9, "leg_back": 0.9, "reactor": 0.8}
	var open_w := 0.0
	for slot in slots:
		if part_cost(parts[slot]) <= 0.0:
			open_w += weights[slot]
	for slot in slots:
		if part_cost(parts[slot]) > 0.0 or open_w <= 0.0:
			continue
		var share: float = left * weights[slot] / open_w
		var pick := pick_for(rng, GameData.SLOT_KIND[slot], share, tg)
		if pick != "":
			set_part(rng, bot, slot, pick)
	if rng.randf() < 0.12 and budget > 1500.0:
		var bk := pick_for(rng, "back", budget * 0.08, tg)
		if bk != "":
			parts["back"] = bk
	if rng.randf() < 0.5:   # matching pairs look more like a real build
		for pair in [["arm_front", "arm_back"], ["leg_front", "leg_back"]]:
			var a: String = parts[pair[0]]
			var b: String = parts[pair[1]]
			if part_cost(a) < part_cost(b):
				parts[pair[0]] = b
			elif part_cost(b) < part_cost(a):
				parts[pair[1]] = a
	fit_mounts(rng, bot)
	return bot


## A part of `kind` for about `money`: the best grade (up to max_g) that money buys, then any
## design of that grade it can pay for.
static func pick_for(rng: RandomNumberGenerator, kind: String, money: float, max_g: int) -> String:
	for g in range(max_g, 0, -1):
		var opts: Array = []
		for id in by_kind(kind):
			var d: Dictionary = GameData.PARTS[id]
			if int(d.get("grade", 0)) == g and d["shop"] and float(d["cost"]) <= money:
				opts.append(id)
		if opts.size() >= 2 or (g == 1 and not opts.is_empty()):
			# favour the better half of what fits
			return opts[rng.randi_range(opts.size() / 2, opts.size() - 1)]
	return ""


## The part grade a robot worth `value` is built from (a full Scrap robot is about $2,000, x3 a grade).
static func grade_for_value(value: float) -> int:
	if value < 2500.0:
		return 1
	if value < 8000.0:
		return 2
	if value < 24000.0:
		return 3
	if value < 72000.0:
		return 4
	return 5


## Spend `left` dollars making the robot better, one part at a time (up to grade max_g). Returns what's left.
static func upgrade_loop(rng: RandomNumberGenerator, bot: Dictionary, left: float, tries: int, max_g: int = 5) -> float:
	for k in tries:
		if left < 40.0:
			break
		var slot := pick_upgrade_slot(rng, bot)
		var cur: String = bot["parts"].get(slot, "")
		var cur_cost := part_cost(cur)
		var opts: Array = []
		for id in by_kind(GameData.SLOT_KIND[slot]):
			var c: float = GameData.PARTS[id]["cost"]
			if c - cur_cost > left:
				break
			if c > cur_cost and int(GameData.PARTS[id].get("grade", 0)) <= max_g and GameData.PARTS[id]["shop"]:
				opts.append(id)
		if opts.is_empty():
			continue
		# usually a modest step up, sometimes the best they can afford
		var lo := 0
		var hi := mini(opts.size() - 1, maxi(2, opts.size() / 3))
		var id: String = opts[rng.randi_range(lo, hi)] if rng.randf() < 0.8 else opts[opts.size() - 1]
		left -= part_cost(id) - cur_cost
		set_part(rng, bot, slot, id)
	return left


## Power first: if the parts draw more than the reactor gives, the reactor is next.
static func pick_upgrade_slot(rng: RandomNumberGenerator, bot: Dictionary) -> String:
	if draw_of(bot) > output_of(bot) + 2 and rng.randf() < 0.7:
		return "reactor"
	if rng.randf() < 0.12:
		return "back"
	if rng.randf() < 0.6:
		# most pilots fix their weakest part first, so robots stay fairly even
		var low := ""
		for slot in ["head", "torso", "arm_front", "arm_back", "leg_front", "leg_back"]:
			if low == "" or part_cost(bot["parts"].get(slot, "")) < part_cost(bot["parts"].get(low, "")):
				low = slot
		return low
	return UPGRADE_SLOTS[rng.randi() % 7]


static func set_part(rng: RandomNumberGenerator, bot: Dictionary, slot: String, id: String) -> void:
	bot["parts"][slot] = id
	if slot == "torso":
		fit_mounts(rng, bot)


## Torsos with extra mounts (second head, lower arms) get cheap parts on them; mounts the torso
## doesn't have are cleared.
static func fit_mounts(rng: RandomNumberGenerator, bot: Dictionary) -> void:
	var parts: Dictionary = bot["parts"]
	var mounts: Array = GameData.part_def(parts["torso"]).get("mounts", [])
	for slot in ["head2", "arm_front2", "arm_back2"]:
		if mounts.has(slot):
			if parts.get(slot, "") == "":
				parts[slot] = cheapest(rng, GameData.SLOT_KIND[slot])
		else:
			parts.erase(slot)
	if bot.has("wear"):
		for slot in bot["wear"].keys():
			if not parts.has(slot):
				bot["wear"].erase(slot)


static func cheapest(rng: RandomNumberGenerator, kind: String) -> String:
	if kind == "back":
		return ""
	var all := by_kind(kind)
	if all.is_empty():
		return ""
	var low: float = GameData.PARTS[all[0]]["cost"]
	var opts: Array = []
	for id in all:
		if GameData.PARTS[id]["cost"] > low:
			break
		opts.append(id)
	return opts[rng.randi() % opts.size()]


static func best_under(kind: String, money: float, _slot: String, max_g: int = 5) -> String:
	var best := ""
	for id in by_kind(kind):
		if GameData.PARTS[id]["cost"] > money:
			break
		if int(GameData.PARTS[id].get("grade", 0)) <= max_g:
			best = id
	return best


static func part_cost(id: String) -> float:
	if id == "":
		return 0.0
	return float(GameData.part_def(id).get("cost", 0))


static func bot_value(bot: Dictionary) -> float:
	var v := 0.0
	for slot in bot.get("parts", {}):
		v += part_cost(bot["parts"][slot])
	return v


static func draw_of(bot: Dictionary) -> int:
	var n := 0
	for slot in bot["parts"]:
		if bot["parts"][slot] != "":
			n += int(GameData.part_def(bot["parts"][slot]).get("draw", 0))
	return n


static func output_of(bot: Dictionary) -> int:
	var n := 0
	for slot in bot["parts"]:
		if bot["parts"][slot] != "":
			n += int(GameData.part_def(bot["parts"][slot]).get("output", 0))
	return maxi(n, 10)


## The opponent dictionary the fight and the garage use, for a world pilot: their robot, its
## wear (it starts the fight dented), and fighting numbers from the pilot's skill.
static func robot(wid: int) -> Dictionary:
	var p := pilot(wid)
	if p.is_empty():
		return {}
	var o: Dictionary = (p["bot"] as Dictionary).duplicate(true)
	o["wear"] = (p.get("wear", {}) as Dictionary).duplicate()
	o["pilot"] = p["name"]
	o["wid"] = wid
	var lv: float = float(p["skill"]) * 3.6
	o["hp"] = 0.8 + lv * 0.11
	o["damage"] = 0.8 + lv * 0.07
	o["think"] = maxf(0.16, 0.6 - lv * 0.09)
	o["block"] = minf(0.65, 0.1 + lv * 0.11)
	o["smart"] = minf(0.95, 0.1 + lv * 0.18)
	return o


## How dangerous a robot + pilot is. Parts (worn parts count less), the robot's multipliers and
## the pilot's skill. Used for computer-vs-computer fights and for the betting odds.
static func rating(o: Dictionary, skill: float) -> float:
	var value := 0.0
	var wear: Dictionary = o.get("wear", {})
	for slot in o.get("parts", {}):
		var id: String = o["parts"][slot]
		if id == "":
			continue
		value += part_cost(id) * (0.35 + 0.65 * float(wear.get(slot, 1.0)))
	return sqrt(400.0 + value) * float(o.get("hp", 1.0)) * float(o.get("damage", 1.0)) * (0.8 + 0.4 * skill)


static func win_chance(ra: float, rb: float) -> float:
	var a := pow(ra, 2.4)
	var b := pow(rb, 2.4)
	return clampf(a / (a + b), 0.04, 0.96)


## The single part that stands out on a robot (much better than the rest of it), or "".
static func standout_slot(parts: Dictionary) -> String:
	var best := ""
	var best_cost := 0.0
	var second := 0.0
	var total := 0.0
	var n := 0
	for slot in GameData.BODY_SLOTS:
		var id: String = parts.get(slot, "")
		if id == "":
			continue
		var c := part_cost(id)
		total += c
		n += 1
		if c > best_cost:
			second = best_cost
			best_cost = c
			best = slot
		elif c > second:
			second = c
	if n < 2 or best_cost < 400.0:
		return ""
	var others := (total - best_cost) / float(n - 1)
	# one part that towers over the rest of the robot (a matched pair of good arms doesn't count)
	return best if best_cost >= others * 3.0 + 200.0 and second <= best_cost * 0.6 else ""


# ---------------------------------------------------------------- fights

## A fight between two world pilots happened (simulated, or watched): money, wear, records.
## `stage` = scrap / regional / championship / cup / pickup.
static func after_fight(rng: RandomNumberGenerator, winner: Dictionary, loser: Dictionary, stage: String) -> void:
	var pay: int = FIGHT_PAY.get(stage, 100)
	if stage == "pickup":
		pay = int(GameData.PICKUP_PURSE.get(str(winner.get("tier", loser.get("tier", "rust"))), 250))
	if not winner.is_empty():
		winner["cash"] = int(winner["cash"]) + pay
		winner["w"] = int(winner["w"]) + 1
		winner["sw"] = int(winner.get("sw", 0)) + 1
		winner["skill"] = minf(1.0, float(winner["skill"]) + 0.006)
		wear_down(rng, winner, rng.randi_range(1, 2), 0.05, 0.3, 0.0)
	if not loser.is_empty():
		match stage:
			"scrap", "pickup":
				loser["cash"] = int(loser["cash"]) - pay / 2
			"steel":
				loser["cash"] = int(loser["cash"]) + int(pay * 0.3)
		loser["l"] = int(loser["l"]) + 1
		loser["sl"] = int(loser.get("sl", 0)) + 1
		loser["skill"] = minf(1.0, float(loser["skill"]) + 0.003)
		wear_down(rng, loser, rng.randi_range(2, 4), 0.15, 0.6, 0.06)


static func wear_down(rng: RandomNumberGenerator, p: Dictionary, n: int, lo: float, hi: float, lose_chance: float) -> void:
	var bot: Dictionary = p["bot"]
	var slots: Array = bot["parts"].keys().filter(func(s): return GameData.BODY_SLOTS.has(s) and bot["parts"][s] != "")
	if slots.is_empty():
		return
	if not p.has("wear"):
		p["wear"] = {}
	for k in n:
		var slot: String = slots[rng.randi() % slots.size()]
		p["wear"][slot] = maxf(0.15, float(p["wear"].get(slot, 1.0)) - rng.randf_range(lo, hi))
	if rng.randf() < lose_chance:
		var slot: String = slots[rng.randi() % slots.size()]
		if slot != "torso":
			lose_part(rng, p, slot)


## A part was torn off for good: a junk part goes on in its place.
static func lose_part(rng: RandomNumberGenerator, p: Dictionary, slot: String) -> void:
	var old: String = p["bot"]["parts"].get(slot, "")
	if old == "":
		return
	if part_cost(old) >= 300.0:
		news("%s lost a %s in the ring.", [p["name"], "part:" + old])
	p["bot"]["parts"][slot] = cheapest(rng, GameData.SLOT_KIND[slot])
	p["wear"].erase(slot)


## Your fight against a world pilot: their robot keeps the dents you gave it, the parts you
## tore off are gone, and their wallet and record move like any other fight.
static func after_player_fight(wid: int, player_won: bool, enemy_hp: Dictionary, ripped: Array, stage: String) -> void:
	var p := pilot(wid)
	if p.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pay: int = FIGHT_PAY.get(stage, 100)
	if player_won:
		p["l"] = int(p["l"]) + 1
		p["sl"] = int(p.get("sl", 0)) + 1
		if stage == "scrap" or stage == "pickup":
			p["cash"] = int(p["cash"]) - pay / 2
	else:
		p["w"] = int(p["w"]) + 1
		p["sw"] = int(p.get("sw", 0)) + 1
		p["cash"] = int(p["cash"]) + pay
	p["skill"] = minf(1.0, float(p["skill"]) + 0.004)
	if not p.has("wear"):
		p["wear"] = {}
	for slot in enemy_hp:
		var mx: float = enemy_hp[slot][1]
		if mx > 0.0:
			p["wear"][slot] = clampf(float(enemy_hp[slot][0]) / mx, 0.15, 1.0)
	for sv in ripped:
		var slot := ""
		for s in p["bot"]["parts"]:
			if p["bot"]["parts"][s] == str(sv.get("id", "")) and s != "torso":
				slot = s
				break
		if slot != "" and rng.randf() < 0.6:   # some get bolted back on after the fight
			lose_part(rng, p, slot)


# ---------------------------------------------------------------- the calendar

## A week went by: every tier whose league is on fights a round in the background (pilots
## busy in your league or cup fight there instead), and quiet pilots take pickup fights.
static func week_passed(y: int, wk: int, busy: Dictionary) -> void:
	if w().is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = y * 1000 + wk * 7 + 13
	# league fights happen in the division tables (GameData.leagues); pilots without a league
	# night this week (and the spares) take pickup fights at the scrapyard now and then
	for tier in TIERS:
		var pool: Array = active(tier).filter(func(p): return not busy.has(int(p["wid"])))
		if wk % 2 == 1:
			pool = pool.filter(func(p): return not in_division(int(p["wid"])))
		for p in pool:
			if rng.randf() < 0.3:
				var foes: Array = pool.filter(func(q): return q != p)
				if not foes.is_empty():
					fight_pair(rng, p, foes[rng.randi() % foes.size()], "pickup")
	if wk % GameData.MONTH_WEEKS == 0:
		month_passed(rng, busy)


static func in_division(wid: int) -> bool:
	for ev in GameData.leagues.values():
		for e in ev.get("pilots", []):
			if int(e.get("wid", -1)) == wid:
				return true
	return false


static func fight_pair(rng: RandomNumberGenerator, a: Dictionary, b: Dictionary, stage: String) -> void:
	var ca := win_chance(rating(robot(int(a["wid"])), a["skill"]), rating(robot(int(b["wid"])), b["skill"]))
	if rng.randf() < ca:
		after_fight(rng, a, b, stage)
	else:
		after_fight(rng, b, a, stage)


## The year is over: the tables and the playoffs decide who moves (7 up and 7 down in each
## division: 4 straight from the table, 3 through the playoffs) (the player is moved by GameData). Then every tier is topped back up to its size.
static func year_end(rng: RandomNumberGenerator, leagues: Dictionary) -> void:
	var moves: Array = []   # [pilot, tier]
	for stage in leagues:
		var ev: Dictionary = leagues[stage]
		var idx := TIERS.find(stage)
		if idx <= 0 or ev.get("pilots", []).is_empty():
			continue   # (the Open Trials move their winners up as soon as they're over; "title" is a cup)
		var up: Array = ev.get("promoted", [])
		var down: Array = ev.get("relegated", [])
		for e in ev["pilots"]:
			if not e.has("wid"):
				continue
			var p := pilot(int(e["wid"]))
			if p.is_empty() or p["retired"]:
				continue
			if up.has(int(e["id"])) and idx < TIERS.size() - 1:
				moves.append([p, TIERS[idx + 1]])
			elif down.has(int(e["id"])) and idx > 0:
				moves.append([p, TIERS[idx - 1]])
	for m in moves:
		move_tier(m[0], m[1])
	for p in active():
		p["sw"] = 0
		p["sl"] = 0
	refill(rng, true)


## After the Open Trials: the Scrap League back to its size (any extra places go to the best of
## the gutter; too many, and the weakest drop back down).
static func fit_tier(tier: String) -> void:
	var k := TIERS.find(tier)
	var here := active(tier)
	if here.size() > TIER_SIZE[tier] and k > 0:
		here.sort_custom(func(a, b): return rating(robot(int(a["wid"])), a["skill"]) < rating(robot(int(b["wid"])), b["skill"]))
		for i in here.size() - TIER_SIZE[tier]:
			move_tier(here[i], TIERS[k - 1])
	var guard := 0
	while active(tier).size() < TIER_SIZE[tier] and guard < 60 and k > 0:
		guard += 1
		var below := active(TIERS[k - 1])
		if below.is_empty():
			break
		below.sort_custom(func(a, b): return rating(robot(int(a["wid"])), a["skill"]) > rating(robot(int(b["wid"])), b["skill"]))
		move_tier(below[0], tier)


static func move_tier(p: Dictionary, tier: String) -> void:
	var up := TIERS.find(tier) > TIERS.find(p["tier"])
	p["tier"] = tier
	if up:
		news("%s moved up to the %s.", [p["name"], "stage:" + tier])
		p["cash"] = int(p["cash"]) + int(SPONSOR.get(tier, 0))   # a sponsor signs them up
	else:
		news("%s dropped down to the %s.", [p["name"], "stage:" + tier])


## End of the month for every pilot: bills, repairs, shopping, selling, retiring.
static func month_passed(rng: RandomNumberGenerator, busy: Dictionary) -> void:
	for p in active():
		var tier: String = p["tier"]
		var living: int = LIVING[tier]
		p["age"] = int(p["age"]) + GameData.MONTH_WEEKS
		p["cash"] = int(p["cash"]) - living + rng.randi_range(INCOME[tier][0], INCOME[tier][1])
		p["cash"] = int(p["cash"]) - int(bot_value(p["bot"]) * 0.03)   # oil, bolts, upkeep: dear robots cost dear
		var reserve: int = {"saver": living * 2, "spender": 0, "gambler": -living / 2}[p["habit"]]
		# repairs, worst part first, while the money lasts
		var worn: Array = p["wear"].keys()
		worn.sort_custom(func(a, b): return float(p["wear"][a]) < float(p["wear"][b]))
		for slot in worn:
			var cost := int(maxf(20.0, part_cost(p["bot"]["parts"].get(slot, "")) * 0.2) * (1.0 - float(p["wear"][slot])))
			if int(p["cash"]) - cost < reserve:
				break
			p["cash"] = int(p["cash"]) - cost
			p["wear"].erase(slot)
		# scrap pilots dig the scrapyard like you do: now and then a usable part turns up
		if (tier == "rust" or tier == "scrap" or tier == "open") and rng.randf() < 0.45:
			var slot: String = UPGRADE_SLOTS[rng.randi() % 6]
			var cur := part_cost(p["bot"]["parts"].get(slot, ""))
			var found := best_under(GameData.SLOT_KIND[slot], rng.randf_range(80.0, 420.0), slot)
			if found != "" and part_cost(found) > cur:
				set_part(rng, p["bot"], slot, found)
				p["wear"][slot] = rng.randf_range(0.35, 0.7)
		var spare: int = int(p["cash"]) - reserve - living
		var value := bot_value(p["bot"])
		var cap: float = VALUE_CAP.get(tier, 3000.0)
		if spare > 200 and value < cap and rng.randf() < SPEND_CHANCE[p["habit"]]:
			if spare > value * 1.5 + 800.0 and rng.randf() < 0.3:
				# a whole new robot: the old one is sold off
				var budget := minf(value * 0.4 + spare * 0.8, cap)
				var old_name: String = p["bot"]["name"]
				var nb := build_bot(rng, budget, float(p["skill"]))
				p["cash"] = int(p["cash"]) - int(spare * 0.8)
				p["bot"] = nb
				p["wear"] = {}
				news("%s sold %s and built a brand-new robot: %s.", [p["name"], old_name, nb["name"]])
			else:
				var budget := minf(spare * rng.randf_range(0.4, 0.9), cap - value)
				var left := upgrade_loop(rng, p["bot"], budget, 3, int(GameData.RANK_GRADE.get(str(p["tier"]), 1)))
				var spent := int(budget - left)
				if spent > 0:
					p["cash"] = int(p["cash"]) - spent   # (the price difference: the old part is traded in)
					if spent >= 500:
						news("%s spent $%s upgrading %s.", [p["name"], str(spent), p["bot"]["name"]])
		elif int(p["cash"]) < -living * 2:
			sell_off(rng, p)
		# retiring
		var chance := 0.002 + float(p["age"]) / 52.0 * 0.0015
		if int(p["cash"]) < -living * 4:
			chance += 0.3
		elif int(p["cash"]) > RICH[tier]:
			chance += 0.18
		if not busy.has(int(p["wid"])) and rng.randf() < chance:
			retire(p, "broke" if int(p["cash"]) < 0 else ("rich" if int(p["cash"]) > RICH[tier] else "old"))
	refill(rng)
	# forget the oldest retired pilots
	var gone: Array = w()["pilots"].values().filter(func(p): return p["retired"])
	if gone.size() > RETIRED_KEEP:
		gone.sort_custom(func(a, b): return int(a.get("ret_y", 0)) * 100 + int(a.get("ret_w", 0)) < int(b.get("ret_y", 0)) * 100 + int(b.get("ret_w", 0)))
		for k in gone.size() - RETIRED_KEEP:
			if not busy.has(int(gone[k]["wid"])):
				w()["pilots"].erase(str(gone[k]["wid"]))


## Deep in debt: the best part goes to pay the bills, junk goes on in its place.
static func sell_off(rng: RandomNumberGenerator, p: Dictionary) -> void:
	var best := ""
	for slot in p["bot"]["parts"]:
		if slot == "torso" and rng.randf() < 0.5:
			continue
		if best == "" or part_cost(p["bot"]["parts"][slot]) > part_cost(p["bot"]["parts"][best]):
			best = slot
	if best == "" or part_cost(p["bot"]["parts"][best]) < 100.0:
		return
	var id: String = p["bot"]["parts"][best]
	p["cash"] = int(p["cash"]) + int(part_cost(id) * 0.4)
	news("%s sold a %s to pay the bills.", [p["name"], "part:" + id])
	p["bot"]["parts"][best] = cheapest(rng, GameData.SLOT_KIND[best])
	p["wear"].erase(best)
	if best == "torso":
		fit_mounts(rng, p["bot"])


static func retire(p: Dictionary, why: String) -> void:
	p["retired"] = true
	p["ret_y"] = GameData.year
	p["ret_w"] = GameData.week
	p["ret_why"] = why
	var text: String = {"broke": "%s is broke and has retired.", "rich": "%s cashed out and retired rich.",
			"old": "%s hung up the controller and retired."}[why]
	news(text, [p["name"]])


## Keep every tier full: rookies turn up at the scrapyard qualifiers (now and then a rich kid
## buys their way straight into the Scrap Heap League). Between seasons (`rebalance`), empty
## places higher up go to the best pilots below and overfull tiers send their weakest down.
static func refill(rng: RandomNumberGenerator, rebalance: bool = false) -> void:
	if rebalance:
		for k in range(TIERS.size() - 1, 0, -1):
			var tier: String = TIERS[k]
			var here := active(tier)
			if here.size() > TIER_SIZE[tier]:
				here.sort_custom(func(a, b): return rating(robot(int(a["wid"])), a["skill"]) < rating(robot(int(b["wid"])), b["skill"]))
				for i in here.size() - TIER_SIZE[tier]:
					move_tier(here[i], TIERS[k - 1])
			if k == 1:
				continue   # the Scrap League is topped up by the Open Trials, not by the table
			var guard := 0
			while active(tier).size() < TIER_SIZE[tier] and guard < 60:
				guard += 1
				var below := active(TIERS[k - 1])
				if below.is_empty():
					break
				below.sort_custom(func(a, b): return rating(robot(int(a["wid"])), a["skill"]) > rating(robot(int(b["wid"])), b["skill"]))
				move_tier(below[0], tier)
	var guard2 := 0
	while active("open").size() < TIER_SIZE["open"] and guard2 < 80:
		guard2 += 1
		var tier := "open"
		var s: Array = TIER_SKILL[tier]
		var r: Array = TIER_VALUE[tier]
		var p := new_pilot(rng, tier, rng.randf_range(r[0], lerpf(r[0], r[1], 0.6)), rng.randf_range(s[0], lerpf(s[0], s[1], 0.6)))
		p["cash"] = rng.randi_range(0, 300) if tier == "open" else rng.randi_range(500, 1500)
		news("New pilot at the %s: %s, with %s.", ["stage:" + tier, p["name"], p["bot"]["name"]])


# ---------------------------------------------------------------- picking pilots for events

## Pilots of a tier sorted weakest first (by rating), skipping the ones in `exclude`.
static func by_rating(tier: String, exclude: Array = []) -> Array:
	var pool := active(tier).filter(func(p): return not exclude.has(int(p["wid"])))
	pool.sort_custom(func(a, b): return rating(robot(int(a["wid"])), a["skill"]) < rating(robot(int(b["wid"])), b["skill"]))
	return pool


## `n` pilots from a tier for your league: a spread from weak to strong, returned weakest first
## (so the season gets harder as it goes on).
static func pick_for_league(rng: RandomNumberGenerator, tier: String, n: int) -> Array:
	var pool := by_rating(tier)
	if pool.size() <= n:
		return pool
	var out: Array = []
	for k in n:
		# one pilot from each slice of the table, weakest slice first
		var lo := int(float(k) / n * pool.size())
		var hi := maxi(lo, int(float(k + 1) / n * pool.size()) - 1)
		out.append(pool[rng.randi_range(lo, hi)])
	return out


## Seven cup entrants for a cup tier (1-5): scrap pilots in the small cups, champions in the big ones.
static func pick_for_cup(rng: RandomNumberGenerator, tier: int, exclude: Array) -> Array:
	var tiers: Array = [["open", "scrap", "rust"], ["rust"], ["rust", "iron"], ["iron", "steel"], ["steel"]][clampi(tier - 1, 0, 4)]
	var pool: Array = []
	for t in tiers:
		pool += active(t).filter(func(p): return not exclude.has(int(p["wid"])))
	if tiers.size() == 2:
		# a mixed cup: the better half of the lower tier, the lower half of the upper one
		var lower := by_rating(tiers[0], exclude)
		var upper := by_rating(tiers[1], exclude)
		pool = lower.slice(lower.size() / 2) + upper.slice(0, upper.size() / 2 + 1)
	pool.shuffle()
	return pool.slice(0, 7)


## Someone from your tier hanging around the scrapyard for a pickup fight.
static func pick_pickup(rng: RandomNumberGenerator, tier: String, exclude: Array) -> Dictionary:
	var pool := active(tier).filter(func(p): return not exclude.has(int(p["wid"])))
	if pool.is_empty():
		return {}
	return pool[rng.randi() % pool.size()]


## World pilots who are tied up with you right now (your league, your cup, your pickup): they
## don't fight in the background that week, and they can't retire mid-event.
static func busy_ids() -> Dictionary:
	var out := {}
	for ev in [GameData.circuit] + GameData.leagues.values():
		if ev.is_empty() or ev.get("phase", "") == "done":
			continue
		for e in ev.get("pilots", []):
			if e.has("wid"):
				out[int(e["wid"])] = true
	if not GameData.pickup.is_empty() and GameData.pickup.has("wid"):
		out[int(GameData.pickup["wid"])] = true
	return out


## Display name: "(retired)" after a pilot who has left the game.
static func news_text(n: Dictionary) -> String:
	var args: Array = []
	for a in n.get("args", []):
		var s := str(a)
		if s.begins_with("part:"):
			args.append(str(GameData.part_def(s.substr(5)).get("name", "?")))
		elif s.begins_with("stage:"):
			args.append(I18n.t(str(GameData.Career.STAGES.get(s.substr(6), {}).get("name", s.substr(6)))))
		else:
			args.append(s)
	var t := I18n.t(str(n["text"]))
	return t % args if args.size() == t.count("%s") + t.count("%d") else t


static func is_female_name(name: String) -> bool:
	return FEMALE.has(name.replace(" JR", "").replace(" III", "").replace(" II", ""))


## What a world pilot looks like. Made once and saved with them, so a pilot always looks the same.
static func look_of(wid: int) -> Dictionary:
	var p := pilot(wid)
	if p.is_empty():
		return make_look(wid, "")
	if not p.has("look"):
		p["look"] = make_look(wid, str(p["name"]))
	return p["look"]


static func make_look(wid: int, name: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = wid * 7349 + 17
	var PilotArt = load("res://pilot_art.gd")
	var female := is_female_name(name)
	var look := {"skin": PilotArt.SKINS[rng.randi() % PilotArt.SKINS.size()], "hair": PilotArt.COLORS[rng.randi() % PilotArt.COLORS.size()],
			"hat": PilotArt.HATS[rng.randi() % PilotArt.HATS.size()], "outfit": PilotArt.COLORS[rng.randi() % PilotArt.COLORS.size()],
			"eyes": PilotArt.EYES[rng.randi() % PilotArt.EYES.size()],
			"beard": PilotArt.BEARDS[rng.randi() % PilotArt.BEARDS.size()] if rng.randf() < 0.45 else "none",
			"glasses": PilotArt.GLASSES[rng.randi() % PilotArt.GLASSES.size()] if rng.randf() < 0.3 else "none"}
	for x in PilotArt.EXTRAS[rng.randi() % PilotArt.EXTRAS.size()]:
		look[x] = true
	if female:
		look["female"] = true
		look["beard"] = "none"
		if rng.randf() < 0.6:
			look["long_hair"] = true
	return look


static func shown_name(wid: int, fallback: String) -> String:
	var p := pilot(wid)
	if p.is_empty():
		return fallback
	return p["name"] + (I18n.t(" (retired)") if p["retired"] else "")
