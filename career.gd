extends RefCounted
## The career: a calendar year of leagues, playoffs and cups.
##
##   Scrap Heap League   weeks 1-5    6 pilots, 5 fights. Top 3 get medals; a medal = into the Regional.
##   Port Ferrum Regional weeks 8-17  9 pilots, 8 league fights, then semifinal / final / bronze match.
##                                    Reaching the semifinals = into the Championship.
##   Kane Championship    weeks 22-41 18 pilots, 17 league fights, then top 7 + OVERLORD (the defending
##                                    champion) play quarterfinal / semifinal / final. Once a year.
##   Cups                 open weeks  8-pilot knockout brackets with medals, once you've won a medal.
##
## An event is a plain dictionary (saved as JSON):
##   {stage, name, year, weeks: [week of each round], round, phase: league/playoffs/done,
##    pilots: [{id, pilot, rival | bot, str}], schedule: [opponent id per league round],
##    table: {id: [wins, losses, points, parts]}, bracket: {...}, medals: {id: 1/2/3}}
## Pilot id 0 is always you.

const I18n = preload("res://i18n.gd")
const WEEKS_PER_YEAR := 52

const STAGES := {
	"scrap": {"name": "Scrap Heap League", "short": "SCRAP LEAGUE", "start": 1, "size": 6, "playoff": 0,
		"rivals": [0, 1, 2], "rival_rounds": [0, 2, 4], "reward": [120, 220], "budget": [250, 650], "level": [0.0, 0.9],
		"prizes": [600, 350, 200], "arenas": ["fish_market", "docks", "cannery"], "crowds": ["fishmongers", "dockers", "punks"]},
	"regional": {"name": "Port Ferrum Regional", "short": "REGIONAL", "start": 8, "size": 9, "playoff": 4,
		"rivals": [3, 4, 5], "rival_rounds": [1, 3, 6], "reward": [380, 700], "budget": [900, 2100], "level": [1.0, 2.0],
		"prizes": [3000, 1800, 1000], "arenas": ["test_track", "harbor", "substation"], "crowds": ["suits", "families", "ravers"]},
	"championship": {"name": "Kane Championship", "short": "CHAMPIONSHIP", "start": 22, "size": 18, "playoff": 8,
		"rivals": [6, 7, 8], "rival_rounds": [1, 8, 15], "boss": 9, "reward": [800, 1500], "budget": [2200, 4800], "level": [2.0, 3.4],
		"prizes": [12000, 6000, 3500], "arenas": ["steelworks", "rooftop", "dry_dock"], "crowds": ["bikers", "robots", "packed"]},
}
const ORDER := ["scrap", "regional", "championship"]
const MEDALS := ["", "GOLD", "SILVER", "BRONZE"]

const PILOT_NAMES := ["DEX", "LUPE", "KOVAC", "BRIGGS", "NELL", "OKAFOR", "TAM", "VASQUEZ", "IVO", "PETRA", "RUSTY JOE",
		"MAMA KAY", "SPROCKET", "TEO", "NADIA", "BIG HUGO", "WREN", "COBALT KID", "FENWICK", "SAOIRSE", "MARCO", "JUNO",
		"OLD PIKE", "BRYN", "HARLOW", "ZEKE", "MILA", "DUNCAN", "AKO", "RAFA", "GRETA", "OTIS", "FINN", "YARA"]


# ---------------------------------------------------------------- building events

## A new league for this stage. Rivals from the story fill some places, generated pilots the rest.
static func new_event(stage: String, year: int, seed_value: int) -> Dictionary:
	var info: Dictionary = STAGES[stage]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pilots: Array = [{"id": 0, "pilot": "YOU", "player": true, "str": 1.0}]
	var names := PILOT_NAMES.duplicate()
	for k in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = names[k]
		names[k] = names[j]
		names[j] = tmp
	var n: int = info["size"]
	for i in range(1, n):
		var e := {"id": i}
		var r := i - 1
		if r < info["rivals"].size():
			var idx: int = info["rivals"][r]
			e["rival"] = idx
			e["pilot"] = str(GameData.OPPONENTS[idx].get("pilot", "")) if str(GameData.OPPONENTS[idx].get("pilot", "")) != "" else "KANE DYNAMICS"
			e["str"] = 0.6 + idx * 0.22
		else:
			var lv: float = lerpf(info["level"][0], info["level"][1], rng.randf())
			var budget: float = lerpf(info["budget"][0], info["budget"][1], rng.randf())
			var bot: Dictionary = GameData.random_bot(rng, budget, lv)
			e["bot"] = bot
			e["pilot"] = names[r % names.size()]
			e["str"] = 0.5 + lv * 0.45 + rng.randf() * 0.3
		pilots.append(e)
	# your league schedule: you fight everyone once; story rivals on their story rounds
	var others: Array = []
	for e in pilots:
		if e["id"] != 0 and not e.has("rival"):
			others.append(e["id"])
	var schedule: Array = []
	schedule.resize(n - 1)
	for k in info["rivals"].size():
		schedule[info["rival_rounds"][k]] = k + 1   # rival pilots have ids 1..3
	for k in schedule.size():
		if schedule[k] == null:
			schedule[k] = others.pop_front()
	var table := {}
	for e in pilots:
		table[str(e["id"])] = [0, 0, 0, 0]
	var weeks: Array = []
	var rounds := n - 1 + playoff_rounds(info["playoff"])
	for k in rounds:
		weeks.append(int(info["start"]) + k)
	return {"stage": stage, "name": info["name"], "year": year, "seed": seed_value, "weeks": weeks, "round": 0,
			"phase": "league", "pilots": pilots, "schedule": schedule, "table": table, "bracket": {}, "medals": {}, "news": []}


## Cups: 8 pilots, straight into a knockout bracket.
static func new_cup(name: String, tier: int, seed_value: int, start_week: int, year: int, prize: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pilots: Array = [{"id": 0, "pilot": "YOU", "player": true, "str": 1.0}]
	for i in range(1, 8):
		var lv := clampf(tier - 1 + rng.randf() * 1.2, 0.0, 5.0)
		var budget: float = GameData.TIER_BUDGET[clampi(tier - 1, 0, 4)] * rng.randf_range(0.75, 1.25)
		var bot: Dictionary = GameData.random_bot(rng, budget, lv)
		if rng.randf() < 0.25:
			bot = GameData.random_team(rng, budget, lv, 2 if rng.randf() < 0.55 else 3)
		pilots.append({"id": i, "pilot": PILOT_NAMES[(seed_value + i * 7) % PILOT_NAMES.size()], "bot": bot, "str": 0.5 + lv * 0.45})
	var ev := {"stage": "cup", "name": name, "tier": tier, "year": year, "seed": seed_value, "prize": prize,
			"weeks": [start_week, start_week + 1, start_week + 2], "round": 0, "phase": "playoffs", "pilots": pilots,
			"schedule": [], "table": {}, "bracket": {}, "medals": {}, "news": []}
	var seeds: Array = range(8)
	seeds.shuffle()
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
		o = GameData.OPPONENTS[int(e["rival"])].duplicate(true)
	elif e.has("bot"):
		o = (e["bot"] as Dictionary).duplicate(true)
	else:
		return {}
	if not e.has("rival"):
		o["pilot"] = e.get("pilot", "")   # story rivals keep their own pilot (or none)
	return o


## The other league pairings this round (everyone except you and your opponent), fixed when the
## round begins so you can bet on them.
static func round_pairs(ev: Dictionary) -> Array:
	var r: int = ev["round"]
	var cached: Dictionary = ev.get("pairs", {})
	if not cached.is_empty() and int(cached["round"]) == r:
		return cached["list"]
	var opp := player_opponent(ev)
	var free: Array = []
	for e in ev["pilots"]:
		var id: int = e["id"]
		if id != 0 and id != opp and not (e.get("rival", -1) == 9 and ev["stage"] == "championship" and ev["phase"] == "league"):
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
	var p := clampf(ra / (ra + rb), 0.08, 0.92)
	return snappedf(maxf(1.05, 0.9 / p), 0.05)


static func is_playoff(ev: Dictionary) -> bool:
	return ev.get("phase", "") == "playoffs"


## Who you fight this round (-1 = you're not fighting in this round).
static func player_opponent(ev: Dictionary) -> int:
	match ev.get("phase", ""):
		"league":
			var r: int = ev["round"]
			if r < ev["schedule"].size():
				return int(ev["schedule"][r])
		"playoffs":
			var m := player_match(ev)
			if not m.is_empty():
				return int(m["b"]) if int(m["a"]) == 0 else int(m["a"])
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
	var k: int = ev["round"]
	return int(ev["weeks"][mini(k, ev["weeks"].size() - 1)])


static func round_name(ev: Dictionary) -> String:
	if ev["phase"] == "league":
		return I18n.t("League round %d/%d") % [int(ev["round"]) + 1, ev["schedule"].size()]
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

## Who wins a fight between two computer pilots.
static func simulate(ev: Dictionary, a: int, b: int, rng: RandomNumberGenerator) -> int:
	var pa := pilot(ev, a)
	var pb := pilot(ev, b)
	if pa.get("rival", -1) == 9:
		return a   # OVERLORD doesn't lose to computer pilots
	if pb.get("rival", -1) == 9:
		return b
	var sa: float = pa.get("str", 1.0)
	var sb: float = pb.get("str", 1.0)
	return a if rng.randf() < sa / (sa + sb) else b


static func add_result(ev: Dictionary, winner: int, loser: int, parts: int) -> void:
	var t: Dictionary = ev["table"]
	if not t.has(str(winner)):
		return
	t[str(winner)][0] += 1
	t[str(winner)][2] += 3
	t[str(winner)][3] += parts
	t[str(loser)][1] += 1


## Your fight is over: record it, play the rest of the round, move the event on.
## Returns what happened: {"phase_changed": bool, "done": bool, "out": bool}
static func after_player_fight(ev: Dictionary, won: bool, parts: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ev["seed"]) * 31 + int(ev["round"]) * 977 + 5
	var out := {"phase_changed": false, "done": false, "out": false}
	var opp := player_opponent(ev)
	if ev["phase"] == "league":
		add_result(ev, 0 if won else opp, opp if won else 0, parts if won else rng.randi_range(0, 3))
		var results: Array = [{"a": 0, "b": opp, "w": 0 if won else opp}]
		# everyone else plays someone this round too (the pairings were set when the round began)
		for pr in round_pairs(ev):
			var a: int = pr[0]
			var b: int = pr[1]
			var w := simulate(ev, a, b, rng)
			add_result(ev, w, b if w == a else a, rng.randi_range(0, 4))
			results.append({"a": a, "b": b, "w": w})
		ev["results"] = {"round": int(ev["round"]), "list": results}
		ev["round"] = int(ev["round"]) + 1
		if ev["round"] >= ev["schedule"].size():
			out["phase_changed"] = true
			finish_league(ev)
			if ev["phase"] == "done":
				out["done"] = true
			elif player_opponent(ev) == -1:
				out["out"] = true
				run_out(ev, rng)
				out["done"] = true
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
	if ev["phase"] == "done":
		out["done"] = true
	elif player_opponent(ev) == -1:
		out["out"] = true
		run_out(ev, rng)
		out["done"] = true
	return out


## League over: medals (scrap league) or a playoff bracket.
static func finish_league(ev: Dictionary) -> void:
	var info: Dictionary = STAGES[ev["stage"]]
	var order := standings(ev)
	if info["playoff"] == 0:
		for k in mini(3, order.size()):
			ev["medals"][str(order[k])] = k + 1
		ev["phase"] = "done"
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
	return I18n.t("finished %d%s") % [pos, ["th", "st", "nd", "rd"][pos] if pos < 4 else "th"]
