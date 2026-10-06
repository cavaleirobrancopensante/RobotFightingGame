extends RefCounted
## The career: a year-round league table in four divisions, plus cups on the side.
##
##   Scrapyard Qualifiers  the bottom: where nobodies start. Top 4 go up to the Scrap Heap League.
##   Scrap Heap League     3rd division.  Top 4 up to the Regional, bottom 4 down to the Qualifiers.
##   Port Ferrum Regional  2nd division.  Top 4 up to the Championship, bottom 4 down.
##   Kane Championship     the top. OVERLORD defends its title here every year. Bottom 4 down.
##
## Every division has 48 pilots and fights a round every other Saturday (weeks 1, 3 ... 47): 24
## fights a year each. A win is 1 point; level on points, the one who destroyed more parts is
## ahead. Top 3 get medals. Weeks 48-52 are the off-season (cups and pickups still run).
## Cups: 8-pilot knockout brackets on Wednesday nights, on the side.
##
## An event is a plain dictionary (saved as JSON):
##   {stage, name, year, weeks: [week of each round], round, phase: league/playoffs/done,
##    pilots: [{id, pilot, rival | wid | bot, str}], fixtures: [[[a, b], ...] per round],
##    schedule: [your opponent per round], table: {id: [wins, losses, points, parts]},
##    bracket: {...} (cups), medals: {id: 1/2/3}}
## Pilot id 0 is always you (only in your own division).

const I18n = preload("res://i18n.gd")
const World = preload("res://world.gd")
const WEEKS_PER_YEAR := 52
const DIVISION_SIZE := 48
const ROUNDS := 24
const UP_DOWN := 4    # promoted / relegated straight from the table each year
const PLAYOFF_WEEKS := [49, 50, 51]   # the promotion and relegation playoffs (Saturdays)

const STAGES := {
	"open": {"name": "Open Trials", "short": "OPEN TRIALS", "start": 49, "size": 16, "playoff": 0,
		"rivals": [], "rival_rounds": [], "reward": [180, 300], "budget": [0, 300], "level": [0.0, 0.4],
		"prizes": [300, 200, 100], "arenas": ["scrap_ring"], "crowds": ["scrappers"]},
	"qualifiers": {"name": "Scrapyard Qualifiers", "short": "QUALIFIERS", "start": 1, "size": 64, "playoff": 0,
		"rivals": [], "rival_rounds": [], "reward": [340, 540], "budget": [0, 400], "level": [0.0, 0.5],
		"prizes": [400, 250, 150], "arenas": ["scrap_ring"], "crowds": ["scrappers"]},
	"scrap": {"name": "Scrap Heap League", "short": "SCRAP LEAGUE", "start": 1, "size": 48, "playoff": 0,
		"rivals": [0, 1, 2], "rival_rounds": [1, 9, 17], "reward": [420, 700], "budget": [250, 650], "level": [0.0, 0.9],
		"prizes": [1500, 900, 500], "arenas": ["fish_market", "docks", "cannery"], "crowds": ["fishmongers", "dockers", "punks"]},
	"regional": {"name": "Port Ferrum Regional", "short": "REGIONAL", "start": 1, "size": 40, "playoff": 0,
		"rivals": [3, 4, 5], "rival_rounds": [1, 9, 17], "reward": [900, 1500], "budget": [900, 2100], "level": [1.0, 2.0],
		"prizes": [6000, 3500, 2000], "arenas": ["test_track", "harbor", "substation"], "crowds": ["suits", "families", "ravers"]},
	"championship": {"name": "Kane Championship", "short": "CHAMPIONSHIP", "start": 1, "size": 32, "playoff": 0,
		"rivals": [6, 7, 8], "rival_rounds": [2, 10, 18], "boss": 9, "boss_round": 23, "reward": [2000, 3400], "budget": [2200, 4800], "level": [2.0, 3.4],
		"prizes": [25000, 12000, 7000], "arenas": ["steelworks", "rooftop", "dry_dock"], "crowds": ["bikers", "robots", "packed"]},
}
## The pyramid, bottom to top: the unranked pool ("open": no league, pickups and cups, and the
## Open Trials at the end of the year), then the four divisions.
const ORDER := ["open", "qualifiers", "scrap", "regional", "championship"]
const MEDALS := ["", "GOLD", "SILVER", "BRONZE"]

const PILOT_NAMES := ["DEX", "LUPE", "KOVAC", "BRIGGS", "NELL", "OKAFOR", "TAM", "VASQUEZ", "IVO", "PETRA", "RUSTY JOE",
		"MAMA KAY", "SPROCKET", "TEO", "NADIA", "BIG HUGO", "WREN", "COBALT KID", "FENWICK", "SAOIRSE", "MARCO", "JUNO",
		"OLD PIKE", "BRYN", "HARLOW", "ZEKE", "MILA", "DUNCAN", "AKO", "RAFA", "GRETA", "OTIS", "FINN", "YARA"]


# ---------------------------------------------------------------- building events

## League weeks: a round every other Saturday, weeks 1, 3 ... 47.
static func league_weeks() -> Array:
	var out: Array = []
	for k in ROUNDS:
		out.append(1 + k * 2)
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
		o = GameData.OPPONENTS[int(e["rival"])].duplicate(true)
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
		return int(PLAYOFF_WEEKS[mini(int(ev["po_round"]), PLAYOFF_WEEKS.size() - 1)])
	var k: int = ev["round"]
	return int(ev["weeks"][mini(k, ev["weeks"].size() - 1)])


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
		return World.rating(GameData.OPPONENTS[idx], 0.25 + idx * 0.075)
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
	if ev.get("phase", "") == "finals":
		play_finals_round(ev, rng)
		return
	if ev.get("phase", "") != "league":
		return
	var results: Array = []
	for pr in round_pairs(ev):
		var a: int = pr[0]
		var b: int = pr[1]
		var w := simulate(ev, a, b, rng)
		add_result(ev, w, b if w == a else a, rng.randi_range(0, 4))
		results.append({"a": a, "b": b, "w": w})
	ev["results"] = {"round": int(ev["round"]), "list": results}
	ev["round"] = int(ev["round"]) + 1
	if ev["round"] >= ev["weeks"].size():
		finish_league(ev)


## Has this division's current round been due (its Saturday has gone by)?
static func round_due(ev: Dictionary, week: int, day_index: int) -> bool:
	var wk := 0
	if ev.get("phase", "") == "finals":
		wk = week_of_round(ev)
		return wk < week or (wk == week and day_index > 5)
	if ev.get("phase", "") != "league" or int(ev["round"]) >= ev["weeks"].size():
		return false
	wk = int(ev["weeks"][int(ev["round"])])
	return wk < week or (wk == week and day_index > 5)


## The table's zones: "up" (top 4: promoted), "up_po" (5th-12th: promotion playoff),
## "down_po" (37th-44th: relegation playoff), "down" (bottom 4: relegated), or "".
static func zone(ev: Dictionary, pos: int) -> String:
	var n: int = ev["pilots"].size()
	var top: bool = ev["stage"] != "championship"
	var bottom: bool = ev["stage"] != "open"
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
	if ev["stage"] != "championship":
		var seeds: Array = order.slice(UP_DOWN, UP_DOWN + 8)
		fin["up"] = {"rounds": [_qf(seeds)]}
	if ev["stage"] != "open":
		var seeds2: Array = order.slice(n - UP_DOWN - 8, n - UP_DOWN)
		fin["down"] = {"rounds": [_qf(seeds2)]}
	ev["finals"] = fin
	ev["po_round"] = 0
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
	if ev["po_round"] >= PLAYOFF_WEEKS.size():
		end_finals(ev)
	return results


## Who's going up and down: the straight places plus the three from each playoff.
static func end_finals(ev: Dictionary) -> void:
	var order := standings(ev)
	var n := order.size()
	var up: Array = []
	var down: Array = []
	if ev["finals"].has("up"):
		up = [] if ev.get("trials", false) else order.slice(0, UP_DOWN)
		var rounds: Array = ev["finals"]["up"]["rounds"]
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


## The Open Trials: 16 pilots from the unranked pool, three Saturdays at the end of the year.
## Round 1: 8 fights. Round 2: the winners fight, and those 4 winners go up to the Qualifiers;
## the 4 losers get a last chance in round 3, and its 2 winners go up too.
static func new_trials(year: int, seed_value: int, with_player: bool, wids: Array) -> Dictionary:
	var pilots: Array = []
	var ids: Array = []
	var next_id := 1
	if with_player:
		pilots.append({"id": 0, "pilot": "YOU", "player": true, "str": 1.0})
		ids.append(0)
	for wid in wids:
		if pilots.size() >= 16:
			break
		pilots.append({"id": next_id, "wid": int(wid), "pilot": str(World.pilot(int(wid)).get("name", "?"))})
		ids.append(next_id)
		next_id += 1
	while ids.size() % 2 == 1 or ids.size() < 2:
		ids.append(ids[0])   # (never happens with a full pool)
	var table := {}
	for e in pilots:
		table[str(e["id"])] = [0, 0, 0, 0]
	var first: Array = []
	for k in ids.size() / 2:
		first.append({"a": int(ids[k]), "b": int(ids[ids.size() - 1 - k]), "w": -1})
	return {"stage": "open", "name": STAGES["open"]["name"], "year": year, "seed": seed_value, "weeks": PLAYOFF_WEEKS.duplicate(),
			"round": 0, "phase": "finals", "po_round": 0, "trials": true, "pilots": pilots, "fixtures": [], "schedule": [],
			"table": table, "bracket": {}, "medals": {}, "news": [], "mine": with_player, "finals": {"up": {"rounds": [first]}}}


## What a playoff match is called: "PROMOTION QUARTERFINAL", "LAST TICKET", "SURVIVAL SEMIFINAL"...
static func finals_round_name(ev: Dictionary, side: String) -> String:
	var r: int = ev.get("po_round", 0)
	if ev.get("trials", false):
		return ["OPEN TRIALS ROUND 1", "OPEN TRIALS ROUND 2", "OPEN TRIALS LAST CHANCE"][mini(r, 2)]
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
