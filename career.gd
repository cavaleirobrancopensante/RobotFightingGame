extends RefCounted
## The career: a pyramid of four leagues, the open dates at the start of the year, and cups.
##
##   the gutter ("open")  no league at all: pilots live on pickups and cups. At the start of the
##                        year the best 16 fight the Open Trials (two wins in, two losses out): 8 go up to Scrap.
##   Scrap League   64    the bottom league.
##   Rust League    48
##   Iron League    40
##   Steel League   32    the top. OVERLORD is in it, your last fight of a Steel year.
##   Titanium Championship    the title: a knockout for the top 8 of last year's Steel League,
##                        on the open dates at the start of the year (QF, SF, final + bronze).
##
## Each league fights a round every other Saturday, weeks 4, 6 ... 50 (24 fights a year). A win is
## 1 point; level on points, the one who destroyed more parts is ahead. Top 3 get medals and money,
## 4th money. Top 5 go up (in Steel: into the Championship), 6th-13th play a playoff for 3 more
## (8 in all); bottom 5 go down, the 8 above them play a playoff where 3 more go down (8 in all).
## The playoffs: week 51 Wednesday and Saturday, week 52 Saturday.
## Cups: 8-pilot knockout brackets on Wednesday nights, on the side.
##
## An event is a plain dictionary (saved as JSON):
##   {stage, name, year, weeks: [week of each round], round, phase: league/finals/playoffs/done,
##    pilots: [{id, pilot, rival | wid | bot, str}], fixtures: [[[a, b], ...] per round],
##    schedule: [your opponent per round], table: {id: [wins, losses, points, parts]},
##    finals: {up/down: {rounds}} + slots: [[week, day], ...] (playoffs, trials),
##    bracket: {...} (cups, the Championship), medals: {id: 1/2/3}}
## Pilot id 0 is always you (only in your own events).

const I18n = preload("res://i18n.gd")
const World = preload("res://world.gd")
const WEEKS_PER_YEAR := 52
const ROUNDS := 24
const UP_DOWN := 5     # straight up / down from the table each year (plus 3 through a playoff)
const PLAYOFF_SLOTS := [[51, 2], [51, 5], [52, 5]]   # [week, day]: Wednesday and Saturday of week 51, Saturday of week 52
const PLAYOFF_WEEKS := [51, 52]
const TRIALS_SLOTS := [[1, 5], [2, 5], [3, 5]]       # the Open Trials: Saturdays of weeks 1-3 (three chances)
const TITLE_WEEKS := [1, 2, 3]                       # the Titanium Championship: Saturdays of weeks 1-3
const LEAGUE_START := 4

const STAGES := {
	"open": {"name": "Open Trials", "short": "OPEN TRIALS", "size": 16,
		"rivals": [], "rival_rounds": [], "reward": [250, 350], "budget": [0, 300], "level": [0.0, 0.4],
		"prizes": [900, 600, 300], "arenas": ["scrap_ring"], "crowds": ["scrappers"]},
	"scrap": {"name": "Scrap League", "short": "SCRAP LEAGUE", "size": 64,
		"rivals": [0, 1, 2], "rival_rounds": [1, 9, 17], "reward": [600, 1000], "budget": [100, 750], "level": [0.0, 0.6],
		"prizes": [3000, 1800, 1000], "arenas": ["fish_market", "docks", "cannery"], "crowds": ["fishmongers", "dockers", "punks"]},
	"rust": {"name": "Rust League", "short": "RUST LEAGUE", "size": 48,
		"rivals": [3, 4, 5], "rival_rounds": [1, 9, 17], "reward": [1800, 3000], "budget": [750, 2250], "level": [0.4, 1.3],
		"prizes": [9000, 5400, 3000], "arenas": ["test_track", "harbor", "substation"], "crowds": ["suits", "families", "ravers"]},
	"iron": {"name": "Iron League", "short": "IRON LEAGUE", "size": 40,
		"rivals": [6, 7, 8], "rival_rounds": [2, 10, 18], "reward": [5500, 8500], "budget": [2250, 6750], "level": [1.2, 2.4],
		"prizes": [27000, 16000, 9000], "arenas": ["steelworks", "rooftop", "dry_dock"], "crowds": ["bikers", "robots", "packed"]},
	"steel": {"name": "Steel League", "short": "STEEL LEAGUE", "size": 32,
		"rivals": [], "rival_rounds": [], "boss": 9, "boss_round": 23, "reward": [17000, 25000], "budget": [6750, 20000], "level": [2.2, 3.4],
		"prizes": [80000, 48000, 27000], "arenas": ["champ_arena"], "crowds": ["champ_fans"]},
	"title": {"name": "Titanium Championship", "short": "CHAMPIONSHIP", "size": 8,
		"rivals": [], "rival_rounds": [], "reward": [60000, 150000], "budget": [20000, 40000], "level": [2.5, 3.5],
		"prizes": [300000, 150000, 75000], "arenas": ["champ_gala"], "crowds": ["high_society"]},
}
## The pyramid, bottom to top (the gutter, then the four leagues). "title" is the Championship cup.
const ORDER := ["open", "scrap", "rust", "iron", "steel"]
## Everything with fight nights, in order of importance (the TV shows the last one fighting tonight).
const EVENTS := ["open", "scrap", "rust", "iron", "steel", "title"]
const MEDALS := ["", "GOLD", "SILVER", "BRONZE"]

const PILOT_NAMES := ["DEX", "LUPE", "KOVAC", "BRIGGS", "NELL", "OKAFOR", "TAM", "VASQUEZ", "IVO", "PETRA", "RUSTY JOE",
		"MAMA KAY", "SPROCKET", "TEO", "NADIA", "BIG HUGO", "WREN", "COBALT KID", "FENWICK", "SAOIRSE", "MARCO", "JUNO",
		"OLD PIKE", "BRYN", "HARLOW", "ZEKE", "MILA", "DUNCAN", "AKO", "RAFA", "GRETA", "OTIS", "FINN", "YARA"]


# ---------------------------------------------------------------- building events

## League weeks: a round every other Saturday, weeks 4, 6 ... 50.
static func league_weeks() -> Array:
	var out: Array = []
	for k in ROUNDS:
		out.append(LEAGUE_START + k * 2)
	return out


## A division's year: 48 pilots (you, if `with_player`; story rivals in your division; OVERLORD at
## the top; world pilots of this tier for the rest) and a fixture list where everyone meets 24
## different opponents. Story rivals are slotted so you meet them on their story rounds.
static func new_event(stage: String, year: int, seed_value: int, with_player: bool = true, wids: Array = []) -> Dictionary:
	var info: Dictionary = STAGES[stage]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n: int = int(info["size"])
	# fixtures on slots 0..n-1 (circle method: every round everyone fights, nobody twice)
	var slots: Array = range(n)
	var fixtures: Array = []
	var rot: Array = range(1, n)
	for r in ROUNDS:
		var line: Array = [0] + rot
		var pairs: Array = []
		for k in n / 2:
			pairs.append([line[k], line[n - 1 - k]])
		fixtures.append(pairs)
		rot.push_front(rot.pop_back())
	# who sits in each slot: slot 0 is you (or a world pilot)
	var occupant := {}
	var fixed: Array = []   # [rival index, round]
	if with_player:
		for k in info["rivals"].size():
			fixed.append([int(info["rivals"][k]), int(info["rival_rounds"][k])])
	if info.has("boss"):
		fixed.append([int(info["boss"]), int(info["boss_round"]) if with_player else -1])
	for f in fixed:
		var slot := -1
		if int(f[1]) >= 0:
			for pr in fixtures[int(f[1])]:
				if int(pr[0]) == 0:
					slot = int(pr[1])
				elif int(pr[1]) == 0:
					slot = int(pr[0])
		if slot == -1 or occupant.has(slot):
			var free: Array = slots.filter(func(x): return x != 0 and not occupant.has(x))
			slot = free[rng.randi() % free.size()]
		occupant[slot] = {"rival": int(f[0])}
	var pool: Array = wids.duplicate()
	for slot in slots:
		if occupant.has(slot) or (slot == 0 and with_player):
			continue
		if not pool.is_empty():
			occupant[slot] = {"wid": int(pool.pop_front())}
	# ids: you are 0, everyone else 1..n-1 in slot order
	var pilots: Array = []
	var id_of := {}
	var next_id := 1
	for slot in slots:
		var id := 0 if (slot == 0 and with_player) else next_id
		if id != 0:
			next_id += 1
		id_of[slot] = id
		var e := {"id": id}
		if id == 0:
			e.merge({"pilot": "YOU", "player": true, "str": 1.0})
		elif occupant.has(slot) and occupant[slot].has("rival"):
			var idx: int = occupant[slot]["rival"]
			e["rival"] = idx
			e["pilot"] = str(GameData.OPPONENTS[idx].get("pilot", "")) if str(GameData.OPPONENTS[idx].get("pilot", "")) != "" else "KANE DYNAMICS"
			e["str"] = 0.6 + idx * 0.22
		elif occupant.has(slot):
			e["wid"] = int(occupant[slot]["wid"])
			e["pilot"] = str(World.pilot(int(e["wid"])).get("name", "?"))
		else:
			var lv: float = lerpf(info["level"][0], info["level"][1], rng.randf())
			var budget: float = lerpf(info["budget"][0], info["budget"][1], rng.randf())
			e["bot"] = World.build_bot(rng, budget * 4.0, lv / 3.6)
			e["pilot"] = PILOT_NAMES[rng.randi() % PILOT_NAMES.size()]
			e["str"] = 0.5 + lv * 0.45
		pilots.append(e)
	var fx: Array = []
	for r in fixtures:
		var pairs: Array = []
		for pr in r:
			pairs.append([int(id_of[pr[0]]), int(id_of[pr[1]])])
		fx.append(pairs)
	var schedule: Array = []
	if with_player:
		for r in fx:
			for pr in r:
				if int(pr[0]) == 0:
					schedule.append(int(pr[1]))
				elif int(pr[1]) == 0:
					schedule.append(int(pr[0]))
	var table := {}
	for e in pilots:
		table[str(e["id"])] = [0, 0, 0, 0]
	return {"stage": stage, "name": info["name"], "year": year, "seed": seed_value, "weeks": league_weeks(), "round": 0,
			"phase": "league", "pilots": pilots, "fixtures": fx, "schedule": schedule, "table": table, "bracket": {},
			"medals": {}, "news": [], "mine": with_player}


static func has_player(ev: Dictionary) -> bool:
	return bool(ev.get("mine", true)) and not pilot(ev, 0).is_empty()


## Cups: 8 pilots, straight into a knockout bracket.
static func new_cup(name: String, tier: int, seed_value: int, start_week: int, year: int, prize: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var exclude: Array = []
	if not GameData.event.is_empty() and GameData.event.get("phase", "") != "done":
		for e in GameData.event["pilots"]:
			if e.has("wid"):
				exclude.append(int(e["wid"]))
	var picks: Array = World.pick_for_cup(rng, tier, exclude)
	var pilots: Array = [{"id": 0, "pilot": "YOU", "player": true, "str": 1.0}]
	for i in range(1, 8):
		if i - 1 < picks.size():
			pilots.append({"id": i, "wid": int(picks[i - 1]["wid"]), "pilot": picks[i - 1]["name"]})
			continue
		var lv := clampf(tier - 1 + rng.randf() * 1.2, 0.0, 5.0)
		var budget: float = GameData.TIER_BUDGET[clampi(tier - 1, 0, 4)] * rng.randf_range(2.0, 4.0)
		var bot: Dictionary = World.build_bot(rng, budget, lv / 5.0)
		if rng.randf() < 0.25:
			bot = GameData.random_team(rng, budget / 4.0, lv, 2 if rng.randf() < 0.55 else 3)
		pilots.append({"id": i, "pilot": PILOT_NAMES[(seed_value + i * 7) % PILOT_NAMES.size()], "bot": bot, "str": 0.5 + lv * 0.45})
	var ev := {"stage": "cup", "name": name, "tier": tier, "year": year, "seed": seed_value, "prize": prize,
			"weeks": [start_week, start_week + 1, start_week + 2], "round": 0, "phase": "playoffs", "pilots": pilots,
			"schedule": [], "table": {}, "bracket": {}, "medals": {}, "news": []}
	# seeded by strength: the favourites are kept apart until late, so the cup gets harder as you
	# go (you're the 2nd or 3rd seed: an underdog first, the big names in the semis and final)
	var seeds: Array = range(1, 8)
	seeds.sort_custom(func(a, b): return rating_of(ev, a) > rating_of(ev, b))
	seeds.insert(rng.randi_range(1, 2), 0)
	start_bracket(ev, seeds)
	return ev


static func playoff_rounds(n: int) -> int:
	return {0: 0, 4: 2, 8: 3}.get(n, 0)


# ---------------------------------------------------------------- queries

static func pilot(ev: Dictionary, id: int) -> Dictionary:
	for e in ev["pilots"]:
		if int(e["id"]) == id:
			return e
	return {}


## The robot (opponent definition) a pilot brings.
static func robot_of(ev: Dictionary, id: int) -> Dictionary:
	var e := pilot(ev, id)
	var o: Dictionary
	if e.has("rival"):
		o = GameData.rival(int(e["rival"]))
	elif e.has("wid") and not World.pilot(int(e["wid"])).is_empty():
		o = World.robot(int(e["wid"]))
		o["pilot"] = World.shown_name(int(e["wid"]), str(e.get("pilot", "")))
		return o
	elif e.has("bot"):
		o = (e["bot"] as Dictionary).duplicate(true)
	else:
		return {}
	if not e.has("rival"):
		o["pilot"] = e.get("pilot", "")   # story rivals keep their own pilot (or none)
	return o


## The other league pairings this round (everyone except you and your opponent), from the
## fixture list (older events without one draw them when the round begins).
static func round_pairs(ev: Dictionary) -> Array:
	var r: int = ev["round"]
	if ev.has("fixtures"):
		if r >= ev["fixtures"].size():
			return []
		var out: Array = []
		for pr in ev["fixtures"][r]:
			if int(pr[0]) != 0 and int(pr[1]) != 0:
				out.append([int(pr[0]), int(pr[1])])
		return out
	var cached: Dictionary = ev.get("pairs", {})
	if not cached.is_empty() and int(cached["round"]) == r:
		return cached["list"]
	var opp := player_opponent(ev)
	var free: Array = []
	for e in ev["pilots"]:
		var id: int = e["id"]
		if id != 0 and id != opp:
			free.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ev["seed"]) * 17 + r * 389 + 1
	for k in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = free[k]
		free[k] = free[j]
		free[j] = tmp
	var list: Array = []
	while free.size() >= 2:
		list.append([free.pop_back(), free.pop_back()])
	ev["pairs"] = {"round": r, "list": list}
	return list


## This round's matches to bet on: [[a, b], ...] - yours first.
static func round_matches(ev: Dictionary) -> Array:
	var out: Array = []
	match ev.get("phase", ""):
		"league":
			var opp := player_opponent(ev)
			if opp != -1:
				out.append([0, opp])
			out += round_pairs(ev)
		"finals":
			for pr in finals_matches(ev):
				out.append([pr[0], pr[1]])
		"playoffs":
			var br: Dictionary = ev["bracket"]
			for x in br["rounds"][br["r"]]:
				if int(x["w"]) == -1:
					var pair := [int(x["a"]), int(x["b"])]
					if pair[1] == 0:
						pair = [0, pair[0]]
					if pair[0] == 0:
						out.insert(0, pair)
					else:
						out.append(pair)
	return out


## Bookmaker's odds (payout multiplier) on pilot a beating b, from their records in this event.
static func odds(ev: Dictionary, a: int, b: int) -> float:
	var ta: Array = ev["table"].get(str(a), [0, 0, 0, 0])
	var tb: Array = ev["table"].get(str(b), [0, 0, 0, 0])
	var ra := (float(ta[0]) + 1.0) / (float(ta[0] + ta[1]) + 2.0)
	var rb := (float(tb[0]) + 1.0) / (float(tb[0] + tb[1]) + 2.0)
	if pilot(ev, a).get("rival", -1) == 9:
		ra = 0.95   # everyone knows OVERLORD
	if pilot(ev, b).get("rival", -1) == 9:
		rb = 0.95
	# the bookmaker looks at the robots and pilots too, not just the table
	var p := clampf(0.4 * ra / (ra + rb) + 0.6 * World.win_chance(rating_of(ev, a), rating_of(ev, b)), 0.08, 0.92)
	return snappedf(maxf(1.05, 0.9 / p), 0.05)


static func is_playoff(ev: Dictionary) -> bool:
	return ev.get("phase", "") == "playoffs" or ev.get("phase", "") == "finals"


## Who you fight this round (-1 = you're not fighting in this round).
static func player_opponent(ev: Dictionary) -> int:
	match ev.get("phase", ""):
		"league":
			var r: int = ev["round"]
			if r < ev["schedule"].size() and has_player(ev):
				return int(ev["schedule"][r])
		"playoffs":
			var m := player_match(ev)
			if not m.is_empty():
				return int(m["b"]) if int(m["a"]) == 0 else int(m["a"])
		"finals":
			if has_player(ev):
				var m2 := finals_match_of(ev, 0)
				if not m2.is_empty():
					return int(m2["b"]) if int(m2["a"]) == 0 else int(m2["a"])
	return -1


static func player_match(ev: Dictionary) -> Dictionary:
	var br: Dictionary = ev["bracket"]
	if br.is_empty():
		return {}
	for m in br["rounds"][br["r"]]:
		if int(m["w"]) == -1 and (int(m["a"]) == 0 or int(m["b"]) == 0):
			return m
	return {}


static func week_of_round(ev: Dictionary) -> int:
	if ev.get("phase", "") == "finals":
		var slots: Array = ev.get("slots", PLAYOFF_SLOTS)
		return int(slots[mini(int(ev["po_round"]), slots.size() - 1)][0])
	var k: int = ev["round"]
	return int(ev["weeks"][mini(k, ev["weeks"].size() - 1)])


## Which day of the week this event's next round is fought (5 = Saturday).
static func fight_day(ev: Dictionary) -> int:
	if ev.get("phase", "") == "finals":
		var slots: Array = ev.get("slots", PLAYOFF_SLOTS)
		return int(slots[mini(int(ev["po_round"]), slots.size() - 1)][1])
	return 5


static func round_name(ev: Dictionary) -> String:
	if ev["phase"] == "finals":
		var side := finals_side(ev, 0) if has_player(ev) else "up"
		return finals_round_name(ev, side if side != "" else "up")
	if ev["phase"] == "league":
		return I18n.t("League round %d/%d") % [mini(int(ev["round"]) + 1, ev["weeks"].size()), ev["weeks"].size()]
	var br: Dictionary = ev["bracket"]
	if br.is_empty():
		return ""
	var m := player_match(ev)
	if not m.is_empty() and m.get("bronze", false):
		return "BRONZE MATCH"
	var main := 0   # matches in this round that aren't the bronze match
	for x in br["rounds"][br["r"]]:
		if not x.get("bronze", false):
			main += 1
	return {4: "QUARTERFINAL", 2: "SEMIFINAL", 1: "FINAL"}.get(main, "PLAYOFF")


## Standings: pilot ids, best first (points, then parts destroyed, then wins).
static func standings(ev: Dictionary) -> Array:
	var ids: Array = []
	for e in ev["pilots"]:
		ids.append(int(e["id"]))
	var t: Dictionary = ev["table"]
	ids.sort_custom(func(a, b):
		var ta: Array = t.get(str(a), [0, 0, 0, 0])
		var tb: Array = t.get(str(b), [0, 0, 0, 0])
		if ta[2] != tb[2]:
			return ta[2] > tb[2]
		if ta[3] != tb[3]:
			return ta[3] > tb[3]
		return a < b)
	return ids


# ---------------------------------------------------------------- results

## How strong a pilot in this event is (robot + skill). You count as average for your tier.
static func rating_of(ev: Dictionary, id: int) -> float:
	var e := pilot(ev, id)
	if id == 0:
		var spec := {"parts": GameData.equipped_ids(), "hp": 1.0, "damage": 1.0}
		return World.rating(spec, 0.5)
	if e.has("rival"):
		var idx := int(e["rival"])
		return World.rating(GameData.rival(idx), 0.25 + idx * 0.075)
	var o := robot_of(ev, id)
	if o.is_empty():
		return 10.0
	if e.has("wid"):
		return World.rating(o, float(World.pilot(int(e["wid"])).get("skill", 0.3)))
	return World.rating(o, clampf(float(e.get("str", 1.0)) / 2.0, 0.0, 1.0))


static func retired(ev: Dictionary, id: int) -> bool:
	var e := pilot(ev, id)
	return e.has("wid") and bool(World.pilot(int(e["wid"])).get("retired", false))


## Who wins a fight between two computer pilots: their robots and skill decide (a watched fight
## has already been decided in the ring). The fight wears their robots and moves their money.
static func simulate(ev: Dictionary, a: int, b: int, rng: RandomNumberGenerator) -> int:
	var pa := pilot(ev, a)
	var pb := pilot(ev, b)
	for f in ev.get("forced", []):
		if int(f["round"]) == round_key(ev) and ((int(f["a"]) == a and int(f["b"]) == b) or (int(f["a"]) == b and int(f["b"]) == a)):
			return int(f["w"])   # watched: the world side was already updated by the fight
	var w := -1
	if pa.get("rival", -1) == 9 or pb.get("rival", -1) == 9:
		# OVERLORD hardly ever loses to computer pilots (about one night in eight)
		var boss_side := a if pa.get("rival", -1) == 9 else b
		w = boss_side if rng.randf() < 0.87 else (b if boss_side == a else a)
	elif retired(ev, a) != retired(ev, b):
		w = b if retired(ev, a) else a   # a retired pilot doesn't turn up: walkover
	else:
		w = a if rng.randf() < World.win_chance(rating_of(ev, a), rating_of(ev, b)) else b
	var l := b if w == a else a
	var pw := pilot(ev, w)
	var pl := pilot(ev, l)
	if not retired(ev, l):
		World.after_fight(rng, World.pilot(int(pw.get("wid", -1))), World.pilot(int(pl.get("wid", -1))), str(ev["stage"]))
	return w


## (1.75) Every round's results are kept for the season (ev "history": [{r, w (week), d (day), list
## [[a, b, winner, parts the winner took off, -1 = not known]]}]), so any fight can be watched later.
static func log_results(ev: Dictionary, wk: int, d: int) -> void:
	var res: Dictionary = ev.get("results", {})
	if res.is_empty():
		return
	if not ev.has("history"):
		ev["history"] = []
	var list: Array = []
	for r in res.get("list", []):
		list.append([int(r["a"]), int(r["b"]), int(r["w"]), int(r.get("p", -1))])
	(ev["history"] as Array).append({"r": int(res["round"]), "w": wk, "d": d, "list": list})


static func add_result(ev: Dictionary, winner: int, loser: int, parts: int) -> void:
	var t: Dictionary = ev["table"]
	if not t.has(str(winner)):
		return
	t[str(winner)][0] += 1
	t[str(winner)][2] += 1   # a win is a point
	t[str(winner)][3] += parts
	t[str(loser)][1] += 1


## Your fight is over: record it, play the rest of the round, move the event on.
## Returns what happened: {"phase_changed": bool, "done": bool, "out": bool}
static func after_player_fight(ev: Dictionary, won: bool, parts: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ev["seed"]) * 31 + int(ev["round"]) * 977 + 5
	var out := {"phase_changed": false, "done": false, "out": false}
	var opp := player_opponent(ev)
	var wk0 := week_of_round(ev)   # (1.75) the night it happened, for the results history
	var d0 := fight_day(ev)
	if ev["phase"] == "league":
		var mp: int = parts if won else rng.randi_range(0, 3)
		add_result(ev, 0 if won else opp, opp if won else 0, mp)
		var results: Array = [{"a": 0, "b": opp, "w": 0 if won else opp, "p": mp}]
		# everyone else plays someone this round too (the pairings were set when the round began)
		for pr in round_pairs(ev):
			var a: int = pr[0]
			var b: int = pr[1]
			var w := simulate(ev, a, b, rng)
			var np := rng.randi_range(0, 4)   # parts the winner took off the loser
			add_result(ev, w, b if w == a else a, np)
			results.append({"a": a, "b": b, "w": w, "p": np})
		ev["results"] = {"round": int(ev["round"]), "list": results}
		log_results(ev, wk0, d0)
		ev["round"] = int(ev["round"]) + 1
		if ev["round"] >= ev["weeks"].size():
			out["phase_changed"] = true
			finish_league(ev)
			if ev["phase"] == "done":
				out["done"] = true
			elif ev["phase"] == "finals":
				out["out"] = player_opponent(ev) == -1   # (not in a playoff: they play on without you)
			elif player_opponent(ev) == -1:
				out["out"] = true
				run_out(ev, rng)
				out["done"] = true
		return out
	if ev["phase"] == "finals":
		var fm := finals_match_of(ev, 0)
		if not fm.is_empty():
			fm["w"] = 0 if won else opp
		play_finals_round(ev, rng)
		log_results(ev, wk0, d0)
		out["done"] = ev["phase"] == "done"
		return out
	# playoffs
	var m := player_match(ev)
	if not m.is_empty():
		m["w"] = 0 if won else opp
	var br: Dictionary = ev["bracket"]
	var cur_r: int = br["r"]
	var played_round: int = ev["round"]
	play_round(ev, rng)
	var res: Array = []
	for x in br["rounds"][cur_r]:
		res.append({"a": int(x["a"]), "b": int(x["b"]), "w": int(x["w"])})
	ev["results"] = {"round": played_round, "list": res}
	log_results(ev, wk0, d0)
	if ev["phase"] == "done":
		out["done"] = true
	elif player_opponent(ev) == -1:
		out["out"] = true
		run_out(ev, rng)
		out["done"] = true
	return out


## A round of a division you're not fighting in (or that you watched from the pub): every
## fixture is decided by the robots and the pilots.
static func play_npc_round(ev: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ev["seed"]) * 31 + round_key(ev) * 977 + 11
	var wk0 := week_of_round(ev)
	var d0 := fight_day(ev)
	if ev.get("phase", "") == "finals":
		play_finals_round(ev, rng)
		log_results(ev, wk0, d0)
		return
	if ev.get("phase", "") == "playoffs":
		# a knockout (the Championship): this round's fights, then the next round is drawn
		var played: int = ev["round"]
		play_round(ev, rng)
		var res: Array = []
		var br: Dictionary = ev["bracket"]
		for x in br["rounds"][mini(br["r"], br["rounds"].size() - 1) if ev["phase"] == "done" else maxi(0, br["r"] - 1)]:
			res.append({"a": int(x["a"]), "b": int(x["b"]), "w": int(x["w"])})
		ev["results"] = {"round": played, "list": res}
		log_results(ev, wk0, d0)
		if ev["phase"] == "done":
			award_world(ev)
		return
	if ev.get("phase", "") != "league":
		return
	var results: Array = []
	for pr in round_pairs(ev):
		var a: int = pr[0]
		var b: int = pr[1]
		var w := simulate(ev, a, b, rng)
		var np := rng.randi_range(0, 4)
		add_result(ev, w, b if w == a else a, np)
		results.append({"a": a, "b": b, "w": w, "p": np})
	ev["results"] = {"round": int(ev["round"]), "list": results}
	log_results(ev, wk0, d0)
	ev["round"] = int(ev["round"]) + 1
	if ev["round"] >= ev["weeks"].size():
		finish_league(ev)


## Has this division's current round been due (its Saturday has gone by)?
static func round_due(ev: Dictionary, week: int, day_index: int) -> bool:
	var wk := 0
	if ev.get("phase", "") == "finals":
		wk = week_of_round(ev)
		return wk < week or (wk == week and day_index > fight_day(ev))
	if ev.get("phase", "") == "playoffs":
		# a knockout bracket (the Championship)
		wk = int(ev["weeks"][mini(int(ev["round"]), ev["weeks"].size() - 1)])
		return wk < week or (wk == week and day_index > 5)
	if ev.get("phase", "") != "league" or int(ev["round"]) >= ev["weeks"].size():
		return false
	wk = int(ev["weeks"][int(ev["round"])])
	return wk < week or (wk == week and day_index > 5)


## The table's zones: "up" (top 5: promoted, or into the Championship from Steel), "up_po"
## (6th-13th: the playoff for 3 more), "down_po" (the 8 above the bottom 5: relegation playoff),
## "down" (bottom 5: relegated), or "".
static func zone(ev: Dictionary, pos: int) -> String:
	var n: int = ev["pilots"].size()
	var top: bool = ev.has("fixtures") and not ev.get("trials", false)
	var bottom: bool = top
	if top and pos < UP_DOWN:
		return "up"
	if top and pos < UP_DOWN + 8:
		return "up_po"
	if bottom and pos >= n - UP_DOWN:
		return "down"
	if bottom and pos >= n - UP_DOWN - 8:
		return "down_po"
	return ""


# ---------------------------------------------------------------- the playoffs (weeks 49-51)
##
## Promotion playoff (5th-12th): quarterfinals 5v12, 6v11, 7v10, 8v9. The two semifinal winners go
## up; the semifinal losers play the last-ticket final, and its winner goes up too (3 up).
## Relegation playoff (37th-44th), the mirror: quarterfinal winners are safe; the losers play the
## survival semis, both losers go down; the winners play a last match, and its loser goes down (3 down).
## ev["finals"] = {"up": {"rounds": [[{a, b, w}], ...]}, "down": {...}}, ev["po_round"] = 0..2.

static func start_finals(ev: Dictionary) -> void:
	var order := standings(ev)
	var n := order.size()
	var fin := {}
	if true:
		var seeds: Array = order.slice(UP_DOWN, UP_DOWN + 8)
		fin["up"] = {"rounds": [_qf(seeds)]}
	if true:
		var seeds2: Array = order.slice(n - UP_DOWN - 8, n - UP_DOWN)
		fin["down"] = {"rounds": [_qf(seeds2)]}
	ev["finals"] = fin
	ev["po_round"] = 0
	ev["slots"] = PLAYOFF_SLOTS.duplicate(true)
	ev["phase"] = "finals"


static func _qf(seeds: Array) -> Array:
	var out: Array = []
	for k in 4:
		out.append({"a": int(seeds[k]), "b": int(seeds[7 - k]), "w": -1})
	return out


static func _pairs(ids: Array, last: bool) -> Array:
	var out: Array = []
	for k in range(0, ids.size() - 1, 2):
		out.append({"a": int(ids[k]), "b": int(ids[k + 1]), "w": -1, "last": last})
	return out


## The Open Trials so far: {id: [wins, losses]} from every match with a winner.
static func _trials_records(ev: Dictionary) -> Dictionary:
	var rec := {}
	for rd in ev.get("finals", {}).get("up", {}).get("rounds", []):
		for m in rd:
			if int(m["w"]) == -1:
				continue
			var w := int(m["w"])
			var l := _loser(m)
			if not rec.has(w):
				rec[w] = [0, 0]
			if not rec.has(l):
				rec[l] = [0, 0]
			rec[w][0] += 1
			rec[l][1] += 1
	return rec


static func trials_record(ev: Dictionary, id: int) -> Array:
	return _trials_records(ev).get(id, [0, 0])


static func _loser(m: Dictionary) -> int:
	return int(m["b"]) if int(m["w"]) == int(m["a"]) else int(m["a"])


## The matches still to fight in this playoff round: [[a, b, "up"/"down"], ...], yours first.
static func finals_matches(ev: Dictionary) -> Array:
	var out: Array = []
	if ev.get("phase", "") != "finals":
		return out
	var r: int = ev["po_round"]
	for side in ev["finals"]:
		var rounds: Array = ev["finals"][side]["rounds"]
		if r >= rounds.size():
			continue
		for m in rounds[r]:
			if int(m["w"]) == -1:
				var pr := [int(m["a"]), int(m["b"]), side]
				if pr[0] == 0 or pr[1] == 0:
					out.insert(0, pr)
				else:
					out.append(pr)
	return out


static func finals_match_of(ev: Dictionary, id: int) -> Dictionary:
	if ev.get("phase", "") != "finals":
		return {}
	var r: int = ev["po_round"]
	for side in ev["finals"]:
		var rounds: Array = ev["finals"][side]["rounds"]
		if r < rounds.size():
			for m in rounds[r]:
				if int(m["w"]) == -1 and (int(m["a"]) == id or int(m["b"]) == id):
					return m
	return {}


## Is this pilot still in a playoff ("up" / "down"), or ""?
static func finals_side(ev: Dictionary, id: int) -> String:
	for side in ev.get("finals", {}):
		for m in ev["finals"][side]["rounds"][0]:
			if int(m["a"]) == id or int(m["b"]) == id:
				return side
	return ""


## Play this playoff round (your match must already have its winner), then draw the next one.
## When the last round is done: who goes up and down, and the division's year is over.
static func play_finals_round(ev: Dictionary, rng: RandomNumberGenerator) -> Array:
	var results: Array = []
	var r: int = ev["po_round"]
	for side in ev["finals"]:
		var rounds: Array = ev["finals"][side]["rounds"]
		if r >= rounds.size():
			continue
		for m in rounds[r]:
			if int(m["w"]) == -1:
				m["w"] = simulate(ev, int(m["a"]), int(m["b"]), rng)
			results.append({"a": int(m["a"]), "b": int(m["b"]), "w": int(m["w"])})
		var cur: Array = rounds[r]
		if r + 1 >= ev.get("slots", PLAYOFF_SLOTS).size():
			continue   # that was the last round
		if ev.get("trials", false):
			# the Open Trials (1.53): two wins and you're in, two losses and you're out. Round 2 pairs
			# the winners with winners (2-0 = in) and the losers with losers (0-2 = out); round 3 is
			# the decider for everyone at 1-1.
			var rec := _trials_records(ev)
			var nxt: Array = []
			if r == 0:
				var wins: Array = []
				var losses: Array = []
				for m in cur:
					wins.append(int(m["w"]))
					losses.append(_loser(m))
				nxt = _pairs(wins, false) + _pairs(losses, false)
			else:
				var mid: Array = []
				for id in rec:
					if int(rec[id][0]) == 1 and int(rec[id][1]) == 1:
						mid.append(int(id))
				mid.sort()
				nxt = _pairs(mid, true)
			if not nxt.is_empty():
				rounds.append(nxt)
			continue
		if r == 0:
			# semis: promotion = quarterfinal winners; relegation = quarterfinal losers
			var go: Array = []
			for m in cur:
				go.append(int(m["w"]) if side == "up" else _loser(m))
			rounds.append(_pairs(go, false))
		elif r == 1:
			# last match: promotion = the semifinal losers; relegation = the semifinal winners
			var go2: Array = []
			for m in cur:
				go2.append(_loser(m) if side == "up" else int(m["w"]))
			rounds.append(_pairs(go2, true))
	ev["results"] = {"round": round_key(ev), "list": results}
	ev["po_round"] = r + 1
	if ev["po_round"] >= ev.get("slots", PLAYOFF_SLOTS).size():
		end_finals(ev)
	return results


## Who's going up and down: the straight places plus the three from each playoff.
static func end_finals(ev: Dictionary) -> void:
	var order := standings(ev)
	var n := order.size()
	var up: Array = []
	var down: Array = []
	if ev["finals"].has("up"):
		var rounds: Array = ev["finals"]["up"]["rounds"]
		if ev.get("trials", false):
			var rec := _trials_records(ev)
			for id in rec:
				if int(rec[id][0]) >= 2:
					up.append(int(id))
		else:
			up = order.slice(0, UP_DOWN)
			for m in rounds[1]:
				up.append(int(m["w"]))
			for m in rounds[2]:
				up.append(int(m["w"]))
	if ev["finals"].has("down"):
		down = order.slice(n - UP_DOWN, n)
		var rounds2: Array = ev["finals"]["down"]["rounds"]
		for m in rounds2[1]:
			down.append(_loser(m))
		for m in rounds2[2]:
			down.append(_loser(m))
	ev["promoted"] = up
	ev["relegated"] = down
	ev["phase"] = "done"


## The Open Trials: the best 16 of the gutter, on the open dates at the start of the year, three
## Saturdays (weeks 1-3). Two wins and you're in the Scrap League, two losses and you're out:
## round 2 pairs 1-0 with 1-0 and 0-1 with 0-1, round 3 is the decider for the eight at 1-1.
## 8 go up; the Scrap League drops its weakest to make room.
static func new_trials(year: int, seed_value: int, with_player: bool, wids: Array) -> Dictionary:
	var pilots: Array = []
	var ids: Array = []
	var next_id := 1
	if with_player:
		pilots.append({"id": 0, "pilot": "YOU", "player": true, "str": 1.0})
		ids.append(0)
	for wid in wids:
		if pilots.size() >= int(STAGES["open"]["size"]):
			break
		pilots.append({"id": next_id, "wid": int(wid), "pilot": str(World.pilot(int(wid)).get("name", "?"))})
		ids.append(next_id)
		next_id += 1
	if ids.size() % 2 == 1:
		ids.pop_back()
	var table := {}
	for e in pilots:
		table[str(e["id"])] = [0, 0, 0, 0]
	var first: Array = []
	for k in ids.size() / 2:
		first.append({"a": int(ids[k]), "b": int(ids[ids.size() - 1 - k]), "w": -1})
	return {"stage": "open", "name": STAGES["open"]["name"], "year": year, "seed": seed_value,
			"weeks": TRIALS_SLOTS.map(func(x): return int(x[0])), "slots": TRIALS_SLOTS.duplicate(true),
			"round": 0, "phase": "finals", "po_round": 0, "trials": true, "pilots": pilots, "fixtures": [], "schedule": [],
			"table": table, "bracket": {}, "medals": {}, "news": [], "mine": with_player, "finals": {"up": {"rounds": [first]}}}


## The Titanium Championship: the 8 who qualified from last year's Steel League (`entries`: their
## event entries, best first; id 0 = you), a knockout on the Saturdays of weeks 1-3.
static func new_title(year: int, seed_value: int, entries: Array) -> Dictionary:
	var pilots: Array = []
	var seeds: Array = []
	var next_id := 1
	var with_player := false
	for e0 in entries:
		var e: Dictionary = (e0 as Dictionary).duplicate()
		if e.get("player", false):
			e["id"] = 0
			with_player = true
		else:
			e["id"] = next_id
			next_id += 1
		pilots.append(e)
		seeds.append(int(e["id"]))
	var table := {}
	for e in pilots:
		table[str(e["id"])] = [0, 0, 0, 0]
	var ev := {"stage": "title", "name": STAGES["title"]["name"], "year": year, "seed": seed_value, "weeks": TITLE_WEEKS.duplicate(),
			"round": 0, "phase": "playoffs", "pilots": pilots, "schedule": [], "table": table, "bracket": {}, "medals": {},
			"news": [], "mine": with_player}
	if seeds.size() >= 2:
		start_bracket(ev, seeds)
	else:
		ev["phase"] = "done"
	return ev


## What a playoff match is called: "PROMOTION QUARTERFINAL", "LAST TICKET", "SURVIVAL SEMIFINAL"...
static func finals_round_name(ev: Dictionary, side: String, at: int = -1) -> String:
	var r: int = ev.get("po_round", 0) if at < 0 else at
	if ev.get("trials", false):
		return ["FIRST ROUND", "SECOND ROUND", "DECIDER"][mini(r, 2)]
	if ev.get("stage", "") == "steel" and side == "up":
		return ["TITLE PLAYOFF QUARTERFINAL", "TITLE PLAYOFF SEMIFINAL", "LAST TITLE TICKET"][mini(r, 2)]
	if side == "up":
		return ["PROMOTION QUARTERFINAL", "PROMOTION SEMIFINAL", "LAST TICKET UP"][mini(r, 2)]
	return ["RELEGATION QUARTERFINAL", "SURVIVAL SEMIFINAL", "LAST CHANCE"][mini(r, 2)]


## A key for "this round" (league round, or 100 + playoff round) so bets and watched fights can't mix them up.
static func round_key(ev: Dictionary) -> int:
	if ev.get("phase", "") == "finals" or ev.has("finals"):
		return 100 + int(ev.get("po_round", 0))
	return int(ev.get("round", 0))


## League over: medals (scrap league) or a playoff bracket.
static func finish_league(ev: Dictionary) -> void:
	var info: Dictionary = STAGES[ev["stage"]]
	var order := standings(ev)
	if ev.has("fixtures"):
		# the year-round table: medals for the top 3 (4th gets prize money only), then the playoffs
		for k in mini(3, order.size()):
			ev["medals"][str(order[k])] = k + 1
		award_world(ev)
		var p4 := World.pilot(int(pilot(ev, int(order[3])).get("wid", -1))) if order.size() > 3 else {}
		if not p4.is_empty():
			p4["cash"] = int(p4["cash"]) + fourth_prize(ev["stage"])
		start_finals(ev)
		return
	if int(info.get("playoff", 0)) == 0:
		for k in mini(3, order.size()):
			ev["medals"][str(order[k])] = k + 1
		ev["phase"] = "done"
		award_world(ev)
		return
	var n: int = info["playoff"]
	var seeds: Array = order.slice(0, n)
	if info.has("boss"):
		# the defending champion waits in the playoffs, on the other side of the bracket from you
		var boss_id: int = ev["pilots"].size()
		ev["pilots"].append({"id": boss_id, "rival": int(info["boss"]), "pilot": "KANE DYNAMICS", "str": 9.0})
		ev["table"][str(boss_id)] = [0, 0, 0, 0]
		seeds = order.slice(0, n - 1)
		seeds.insert(0, boss_id)
	ev["qualified"] = seeds.duplicate()
	ev["phase"] = "playoffs"
	start_bracket(ev, seeds)


## Standard bracket from seeds (best first): 1v8, 4v5, 2v7, 3v6 / 1v4, 2v3.
## The top seed and you are put in opposite halves (so a boss meets you only in the final).
static func start_bracket(ev: Dictionary, seeds: Array) -> void:
	var order: Array
	if seeds.size() == 8:
		order = [[0, 7], [3, 4], [1, 6], [2, 5]]
	elif seeds.size() == 4:
		order = [[0, 3], [1, 2]]
	else:
		order = [[0, 1]]
	var matches: Array = []
	for o in order:
		matches.append({"a": int(seeds[o[0]]), "b": int(seeds[o[1]]), "w": -1})
	# keep you away from the top seed's half
	if seeds.size() >= 4 and int(seeds[0]) != 0:
		var half := matches.size() / 2
		var mine := -1
		for k in matches.size():
			if int(matches[k]["a"]) == 0 or int(matches[k]["b"]) == 0:
				mine = k
		if mine != -1 and mine < half:
			var swap: int = mine + half
			var tmp = matches[mine]
			matches[mine] = matches[swap]
			matches[swap] = tmp
	ev["bracket"] = {"rounds": [matches], "r": 0}


## Play every computer match of the current bracket round, then build the next round.
static func play_round(ev: Dictionary, rng: RandomNumberGenerator) -> void:
	var br: Dictionary = ev["bracket"]
	var cur: Array = br["rounds"][br["r"]]
	for m in cur:
		if int(m["w"]) == -1 and int(m["a"]) != 0 and int(m["b"]) != 0:
			m["w"] = simulate(ev, int(m["a"]), int(m["b"]), rng)
	for m in cur:
		if int(m["w"]) == -1:
			return   # your match hasn't been fought yet
	ev["round"] = int(ev["round"]) + 1
	var final_round: bool = cur.size() == 1 or (cur.size() == 2 and cur[1].get("bronze", false))
	if final_round:
		for m in cur:
			var w: int = m["w"]
			var l: int = int(m["b"]) if w == int(m["a"]) else int(m["a"])
			if m.get("bronze", false):
				ev["medals"][str(w)] = 3
			else:
				ev["medals"][str(w)] = 1
				ev["medals"][str(l)] = 2
		ev["phase"] = "done"
		return
	var nxt: Array = []
	for k in range(0, cur.size(), 2):
		nxt.append({"a": int(cur[k]["w"]), "b": int(cur[k + 1]["w"]), "w": -1})
	if cur.size() == 2:
		# semifinal losers play for bronze
		var l0: int = int(cur[0]["b"]) if int(cur[0]["w"]) == int(cur[0]["a"]) else int(cur[0]["a"])
		var l1: int = int(cur[1]["b"]) if int(cur[1]["w"]) == int(cur[1]["a"]) else int(cur[1]["a"])
		nxt.append({"a": l0, "b": l1, "w": -1, "bronze": true})
	br["rounds"].append(nxt)
	br["r"] = int(br["r"]) + 1


## You're out: the rest of the event plays out without you.
static func run_out(ev: Dictionary, rng: RandomNumberGenerator) -> void:
	var guard := 0
	while ev["phase"] == "playoffs" and guard < 8:
		play_round(ev, rng)
		guard += 1


## Computer pilots who took medals get their prize money.
static func award_world(ev: Dictionary) -> void:
	for id in ev["medals"]:
		var e := pilot(ev, int(id))
		var p := World.pilot(int(e.get("wid", -1)))
		if p.is_empty():
			continue
		var m := int(ev["medals"][id])
		var prize := 0
		if ev["stage"] == "cup":
			prize = int(int(ev.get("prize", 1000)) * [0.0, 1.0, 0.5, 0.25][m])
		else:
			prize = int(STAGES[ev["stage"]]["prizes"][m - 1])
		p["cash"] = int(p["cash"]) + prize
		if m == 1:
			World.news("%s won the %s.", [p["name"], ("stage:" + str(ev["stage"])) if ev["stage"] != "cup" else str(ev["name"])])


static func fourth_prize(stage: String) -> int:
	return int(int(STAGES[stage]["prizes"][2]) * 0.6)


static func medal_of(ev: Dictionary, id: int) -> int:
	return int(ev["medals"].get(str(id), 0))


## How far you got, in words.
static func finish_text(ev: Dictionary) -> String:
	var m := medal_of(ev, 0)
	if m > 0:
		return I18n.t("%s MEDAL") % I18n.t(MEDALS[m])
	var br: Dictionary = ev.get("bracket", {})
	if not br.is_empty():
		# knocked out: in which round?
		var last := ""
		for rnd in br["rounds"]:
			var main := 0
			var mine := false
			for x in rnd:
				if not x.get("bronze", false):
					main += 1
					if int(x["a"]) == 0 or int(x["b"]) == 0:
						mine = true
			if mine:
				last = {4: "quarterfinal", 2: "semifinal", 1: "final"}.get(main, "playoffs")
		if last != "":
			return I18n.t("out in the %s") % I18n.t(last)
	var pos := standings(ev).find(0) + 1
	var suffix := "th"
	if pos % 100 < 11 or pos % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][pos % 10]
	return I18n.t("finished %d%s") % [pos, I18n.t(suffix)]
