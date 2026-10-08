extends RefCounted
## BotMedia, Port Ferrum's social network: accounts, posts, follows, likes, followers.
## Design: "Robot Fighting · Pilot Skill & BotMedia Study". Every post comes from something that
## really happened (a result, a table, a purchase, a Read change, a grudge, a contract), voiced by
## the account that would say it. Posts are stored as an English template plus values and are
## translated when shown (like World news). State lives in GameData.social (saved):
##   {"posts": [post], "next": int, "follows": [account key], "followers": int (yours),
##    "draft": {} (your post after a fight), "notes": [note], "posts_week": {abs week: n}, "liked": {id: true}}
## post: {id, at (time tick), y, w, d, by (account key), text, args, card {}, tags [], likes, reposts,
##        replies, mention (bool: it names you), replied (bool)}
## Account keys: "me", "gus", "botmedia", "kane", "mic_scrap", "mic_grand", "rustybolt", "partsrus",
##   "w:<wid>" (a world pilot), "fan:<n>", "sp:<sponsor id>".

const World = preload("res://world.gd")
const I18n = preload("res://i18n.gd")

const MAX_POSTS := 300
const ACCOUNTS := {
	"gus": {"name": "Gus", "handle": "gus_fixes", "fol": 900},
	"botmedia": {"name": "BotMedia News", "handle": "botmedia", "fol": 140000, "verified": true, "logo": "botmedia"},
	"kane": {"name": "Kane Dynamics", "handle": "KaneDynamics", "fol": 2400000, "verified": true, "logo": "kane"},
	"mic_scrap": {"name": "Scrap Heap Mic", "handle": "scrapheap_mic", "fol": 18000, "logo": "mic"},
	"mic_grand": {"name": "Grand Hall Voice", "handle": "grandhall_voice", "fol": 95000, "verified": true, "logo": "mic"},
	"rustybolt": {"name": "The Rusty Bolt", "handle": "therustybolt", "fol": 3200, "logo": "rustybolt"},
	"partsrus": {"name": "Parts-R-Us", "handle": "partsrus", "fol": 8800, "logo": "partsrus"},
}
const FANS := ["dockrat_92", "ironfan_lucia", "craneboy", "rivetqueen", "boltcounter", "scrapheap_sam", "nightshift_nell",
		"oilcan_omar", "gearhead_gil", "rustlover", "pf_ultras", "cheapseats_cal", "tinmother", "sparky_dee", "harbour_hank", "liftkid"]

## Followers per win, by league (the flat part); a share of what you have comes on top.
const FOL_FLAT := {"open": 20, "scrap": 50, "rust": 150, "iron": 400, "steel": 1000, "title": 1000, "cup": 150}
const FOL_START := {"open": 80, "scrap": 500, "rust": 2500, "iron": 12000, "steel": 50000}


static func st() -> Dictionary:
	var s: Dictionary = GameData.social
	for k in ["posts", "follows", "notes"]:
		if not s.has(k):
			s[k] = []
	for k in ["draft", "posts_week", "liked"]:
		if not s.has(k):
			s[k] = {}
	if not s.has("next"):
		s["next"] = 1
	if not s.has("followers"):
		s["followers"] = 30
	if not s.has("seeded"):
		s["seeded"] = true
		s["follows"] = ["gus", "botmedia", "rustybolt", "mic_scrap"]
	return s


## Now, in thirds of a day (morning / afternoon / evening): likes grow with it.
static func now_t() -> int:
	return ((GameData.year * 52 + GameData.week) * 7 + GameData.day_index()) * 3 + int(GameData.phase)


# ---------------------------------------------------------------- accounts

static func account(key: String) -> Dictionary:
	if key == "me":
		return {"name": GameData.pilot_name, "handle": handle_of(GameData.pilot_name, GameData.robot_name), "fol": followers(), "me": true}
	if ACCOUNTS.has(key):
		return ACCOUNTS[key]
	if key.begins_with("w:"):
		var p := World.pilot(int(key.substr(2)))
		if p.is_empty():
			return {"name": "?", "handle": "deleted", "fol": 0}
		return {"name": str(p["name"]), "handle": handle_of(str(p["name"]), str(p["bot"].get("name", ""))), "fol": pilot_fol(p),
				"wid": int(p["wid"]), "read": World.read_of(p), "rattled": int(p.get("rattled", 0)) > 0}
	if key.begins_with("fan:"):
		var n: String = FANS[int(key.substr(4)) % FANS.size()]
		return {"name": n, "handle": n, "fol": 40 + absi(hash(n)) % 900, "fan": true}
	if key.begins_with("sp:"):
		var sp: Dictionary = GameData.Contracts.SPONSORS.get(key.substr(3), {})
		return {"name": str(sp.get("name", "?")), "handle": str(sp.get("handle", "?")), "fol": int(sp.get("fol", 5000)),
				"verified": true, "logo": key.substr(3)}
	return {"name": key, "handle": key, "fol": 0}


static func handle_of(name: String, robot: String) -> String:
	var h := (name + "_" + robot).to_lower().replace(" ", "").replace(".", "").replace("'", "")
	return h.substr(0, 20)


static func followers() -> int:
	return int(st()["followers"])


## 950, 12.4K, 2.4M.
static func fol_text(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%dK" % int(n / 1000)
	if n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)


static func pilot_fol(p: Dictionary) -> int:
	if not p.has("fol"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(p["wid"]) * 131 + 7
		var base: int = FOL_START.get(str(p["tier"]), 100)
		p["fol"] = int(base * rng.randf_range(0.5, 1.6) + int(p.get("w", 0)) * FOL_FLAT.get(str(p["tier"]), 20))
	return int(p["fol"])


static func follows(key: String) -> bool:
	return st()["follows"].has(key)


static func follow(key: String, on: bool) -> void:
	var f: Array = st()["follows"]
	if on and not f.has(key):
		f.append(key)
	elif not on:
		f.erase(key)


# ---------------------------------------------------------------- posts

## Post something. text is an English template (translated when shown); args fill its %s / %d.
static func post(by: String, text: String, args: Array = [], card: Dictionary = {}, tags: Array = [], mention: bool = false) -> Dictionary:
	var s := st()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["next"]) * 977 + GameData.year
	var fol := float(account(by).get("fol", 100))
	var likes := int(fol * rng.randf_range(0.008, 0.035) * (1.6 if mention else 1.0)) + rng.randi_range(0, 6)
	var p := {"id": int(s["next"]), "at": now_t(), "y": GameData.year, "w": GameData.week, "d": GameData.day,
			"by": by, "text": text, "args": args, "card": card, "tags": tags, "likes": likes,
			"reposts": int(likes * rng.randf_range(0.04, 0.14)), "replies": int(likes * rng.randf_range(0.02, 0.09)),
			"mention": mention}
	s["next"] = int(s["next"]) + 1
	(s["posts"] as Array).append(p)
	if (s["posts"] as Array).size() > MAX_POSTS:
		s["posts"] = (s["posts"] as Array).slice((s["posts"] as Array).size() - MAX_POSTS)
	if mention:
		note("%s mentioned you.", [account(by)["name"]], int(p["id"]))
	return p


static func text_of(p: Dictionary) -> String:
	return World.news_text({"text": p["text"], "args": p.get("args", [])})


## Likes, reposts and replies climb over the day after a post goes up.
static func grown(p: Dictionary, field: String) -> int:
	var age := now_t() - int(p.get("at", now_t()))
	var k := clampf(0.35 + 0.22 * age, 0.35, 1.0)
	var mine := 0
	if field == "likes" and st()["liked"].has(str(p["id"])):
		mine = 1
	elif field == "replies" and p.get("replied", false):
		mine = 1   # your own reply counts
	return int(float(p.get(field, 0)) * k) + mine


static func when_text(p: Dictionary) -> String:
	var age := now_t() - int(p.get("at", now_t()))
	if age <= 0:
		return I18n.t("now")
	if age < 3:
		return I18n.t("today")
	if age < 6:
		return I18n.t("yesterday")
	if age < 21:
		return I18n.t("%d days") % int(age / 3)
	return I18n.t("week %d") % int(p.get("w", 1))


## The feed: "home" (who you follow, and you), "all", a #tag, or one account's posts.
static func feed(kind: String, n: int = 60) -> Array:
	var out: Array = []
	var posts: Array = st()["posts"]
	for i in range(posts.size() - 1, -1, -1):
		var p: Dictionary = posts[i]
		var by := str(p["by"])
		var ok := false
		match kind:
			"home":
				ok = by == "me" or follows(by) or p.get("mention", false)
			"all":
				ok = true
			_:
				if kind.begins_with("#"):
					ok = (p.get("tags", []) as Array).has(kind.substr(1))
				else:
					ok = by == kind
		if ok:
			out.append(p)
			if out.size() >= n:
				break
	return out


static func find_post(id: int) -> Dictionary:
	for p in st()["posts"]:
		if int(p["id"]) == id:
			return p
	return {}


static func toggle_like(id: int) -> void:
	var liked: Dictionary = st()["liked"]
	if liked.has(str(id)):
		liked.erase(str(id))
	else:
		liked[str(id)] = true


## Hashtags most used over the last two weeks.
static func trending(n: int = 6) -> Array:
	var counts := {}
	var since := now_t() - 42
	for p in st()["posts"]:
		if int(p.get("at", 0)) < since:
			continue
		for t in p.get("tags", []):
			counts[t] = int(counts.get(t, 0)) + 1 + int(p.get("likes", 0)) / 2000
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	return keys.slice(0, n)


## Accounts worth following that you don't follow yet: the biggest pilots, the busiest accounts.
static func suggestions(n: int = 6) -> Array:
	var pool: Array = []
	for p in World.active():
		if int(p.get("fol", 0)) > 0 or str(p["tier"]) in ["steel", "iron"]:
			pool.append("w:%d" % int(p["wid"]))
	for k in ["mic_grand", "partsrus", "kane"]:
		pool.append(k)
	pool = pool.filter(func(k): return not follows(k))
	pool.sort_custom(func(a, b): return int(account(a)["fol"]) > int(account(b)["fol"]))
	return pool.slice(0, n)


static func note(text: String, args: Array = [], post_id: int = -1, icon: String = "") -> void:
	var notes: Array = st()["notes"]
	notes.append({"at": now_t(), "w": GameData.week, "y": GameData.year, "text": text, "args": args, "post": post_id, "icon": icon})
	if notes.size() > 80:
		st()["notes"] = notes.slice(notes.size() - 80)
	GameData.alerts_unseen += 1


static func note_text(n: Dictionary) -> String:
	return World.news_text({"text": n["text"], "args": n.get("args", [])})


static func tag_for(stage: String) -> String:
	return {"open": "OpenTrials", "scrap": "ScrapLeague", "rust": "RustLeague", "iron": "IronLeague", "steel": "SteelLeague",
			"title": "TitaniumChampionship", "cup": "CupNight", "pickup": "RustyBoltPickup"}.get(stage, "PortFerrum")


static func fan_key(seed: int) -> String:
	return "fan:%d" % (absi(seed) % FANS.size())


# ---------------------------------------------------------------- followers

static func fol_change(f: int, won: bool, destroyed: int, intact: int, lost_parts: int, stage: String) -> int:
	var flat: int = FOL_FLAT.get(stage, 50)
	var x := float(f)
	if won:
		x += x * 0.03 + flat
	else:
		x -= x * 0.03
	x += destroyed * (float(f) * 0.01 + flat / 5.0) + intact * float(f) * 0.01
	x -= lost_parts * float(f) * 0.01
	return maxi(0, int(round(x)))


## Two world pilots fought: followers move, and the notable ones make a noise.
static func world_fight(rng: RandomNumberGenerator, winner: Dictionary, loser: Dictionary, stage: String) -> void:
	if winner.is_empty() or loser.is_empty():
		return
	var ripped := rng.randi_range(0, 2)
	winner["fol"] = fol_change(pilot_fol(winner), true, ripped, 0, 0, str(winner.get("tier", stage)))
	loser["fol"] = fol_change(pilot_fol(loser), false, 0, 0, ripped, str(loser.get("tier", stage)))
	# an upset: two Read dots or more below, and won anyway
	var dw := World.read_dots(World.read_of(winner))
	var dl := World.read_dots(World.read_of(loser))
	if dl - dw >= 2 and stage != "pickup":
		var tag := tag_for(stage)
		post("w:%d" % int(winner["wid"]), ["Nobody gave me a chance against %s. Nobody.", "Write it down: I beat %s.",
				"Who's laughing now, %s?"][rng.randi() % 3], [loser["name"]], {"kind": "result", "a": winner["name"], "b": loser["name"]}, [tag, "UpsetOfTheWeek"])
		post(fan_key(rng.randi()), ["%s just beat %s. I need to sit down.", "Upset of the week: %s over %s.",
				"My bet slip is crying. %s beat %s."][rng.randi() % 3], [winner["name"], loser["name"]], {}, ["UpsetOfTheWeek"])


## Your fight: followers, a post from your opponent, from Gus when you win, from a fan or two,
## and your own post waiting for you on BotMedia.
static func my_fight(o: Dictionary, won: bool, destroyed: int, intact: int, own_lost: int, stage: String) -> void:
	var s := st()
	var before := int(s["followers"])
	s["followers"] = fol_change(before, won, destroyed, intact, own_lost, stage if stage != "" else GameData.rank)
	var opp_name := str(o.get("pilot", o.get("name", "?")))
	if opp_name == "":
		opp_name = str(o.get("name", "?"))
	var wid := int(o.get("wid", -1))
	var rng := RandomNumberGenerator.new()
	rng.seed = GameData.year * 9999 + GameData.week * 77 + GameData.day_index()
	var tag := tag_for(stage)
	var card := {"kind": "result", "a": GameData.pilot_name if won else opp_name, "b": opp_name if won else GameData.pilot_name}
	if wid >= 0:
		follow("w:%d" % wid, true)
		if won:
			post("w:%d" % wid, ["Tough night. %s was sharper. Back to the bay.", "%s got lucky. Rematch, any time.",
					"Lost to %s. I'll be back."][rng.randi() % 3], [GameData.pilot_name], card, [tag], true)
		else:
			post("w:%d" % wid, ["Too easy. %s, call me when you've grown up.", "Thanks for the warm-up, %s.",
					"Another win. Sorry, %s."][rng.randi() % 3], [GameData.pilot_name], card, [tag], true)
	if won:
		post("gus", ["Good night at the bay. Kid did alright.", "Dents to fix, money in the jar. Good night.",
				"Told you that robot still had it."][rng.randi() % 3], [], {}, [])
	post(fan_key(rng.randi()), ["%s is the real deal. Saw it from the cheap seats.", "Did anyone else see %s tonight?",
			"Keep an eye on %s."][rng.randi() % 3] if won else ["Rough one for %s tonight.", "%s will be back. Probably.",
			"Not %s's night."][rng.randi() % 3], [GameData.pilot_name], {}, [tag])
	if destroyed > 0 and won:
		post(fan_key(rng.randi() + 3), "%s tore %d parts off tonight. Somebody call a scrap man.", [GameData.pilot_name, destroyed], {}, [tag])
	# your own post: three drafts to pick from on BotMedia
	s["draft"] = {"opp": opp_name, "wid": wid, "won": won, "tag": tag, "at": now_t()}
	if int(s["followers"]) != before:
		note("Followers: %s (%s).", [str(s["followers"]), ("+" if int(s["followers"]) > before else "") + str(int(s["followers"]) - before)])


## The drafts for your post after a fight: [tone, text template].
static func drafts() -> Array:
	var d: Dictionary = st()["draft"]
	if d.is_empty() or now_t() - int(d.get("at", 0)) > 9:
		return []   # three days on, nobody cares any more
	if d["won"]:
		return [["humble", "Good fight, %s. I got lucky with that last one."], ["hype", "ANOTHER ONE. %s didn't know what hit them."],
				["trash", "%s, go back to the scrapyard. I'll be here when you're ready."]]
	return [["humble", "%s was better tonight. Back to the bay."], ["hype", "That's one loss. Watch what happens next, %s."],
			["trash", "%s got lucky. Everyone saw it."]]


## You picked a draft (or a reply): followers move, grudges move, contracts may care.
static func publish(tone: String) -> void:
	var s := st()
	var d: Dictionary = s["draft"]
	if d.is_empty():
		return
	var text := ""
	for dr in drafts():
		if dr[0] == tone:
			text = dr[1]
	var f := float(s["followers"])
	match tone:
		"humble":
			f *= 1.005
		"hype":
			f *= 1.02 if d["won"] else 0.98
		"trash":
			f *= 1.01
			if int(d.get("wid", -1)) >= 0:
				GameData.grudge_bump(int(d["wid"]), 1.5)
	s["followers"] = int(round(f))
	post("me", text, [d["opp"]], {}, [str(d.get("tag", ""))])
	count_post()
	GameData.Contracts.on_post(tone)
	s["draft"] = {}


static func count_post() -> void:
	var pw: Dictionary = st()["posts_week"]
	var k := str(World.abs_week())
	pw[k] = int(pw.get(k, 0)) + 1


static func posts_this_week() -> int:
	return int(st()["posts_week"].get(str(World.abs_week()), 0))


## Replies to a post that names you: [tone, text].
static func reply_options() -> Array:
	return [["friendly", "Respect, %s. See you in the ring."], ["cool", "We'll see, %s."], ["cutting", "Big words for someone with your record, %s."]]


static func reply(id: int, tone: String) -> void:
	var p := find_post(id)
	if p.is_empty() or p.get("replied", false):
		return
	p["replied"] = true
	var acc := account(str(p["by"]))
	var text := ""
	for r in reply_options():
		if r[0] == tone:
			text = r[1]
	var wid := int(acc.get("wid", -1))
	match tone:
		"friendly":
			if wid >= 0:
				GameData.grudge_bump(wid, -1.0)
		"cool":
			st()["followers"] = int(followers() * 1.003)
		"cutting":
			st()["followers"] = int(followers() * 1.01)
			if wid >= 0:
				GameData.grudge_bump(wid, 1.0)
			GameData.Contracts.on_post("trash")
	post("me", text, ["@" + str(acc["handle"])], {}, p.get("tags", []))
	count_post()


## A league, the Championship or a cup is over: the top three get a big boost and a post.
static func podium(ev: Dictionary, kind: String) -> void:
	if ev.get("podium_posted", false):
		return
	ev["podium_posted"] = true
	var order: Array = [-1, -1, -1]
	for k in ev.get("medals", {}):
		var m := int(ev["medals"][k])
		if m >= 1 and m <= 3:
			order[m - 1] = int(k)
	if order.has(-1):
		if kind == "cup" or kind == "title":
			return
		order = GameData.Career.standings(ev)
		if order.size() < 3:
			return
	var names: Array = []
	var flat: int = FOL_FLAT.get(kind if kind in ["title", "cup"] else str(ev.get("stage", "scrap")), 50)
	var boost := [[0.5, 10], [0.35, 6], [0.25, 4]] if kind != "cup" else [[0.15, 2], [0.1, 2], [0.05, 2]]
	for k in 3:
		var id := int(order[k])
		var add_k: float = boost[k][0]
		var add_flat: int = int(boost[k][1]) * flat
		if id == 0:
			names.append(GameData.pilot_name)
			var before := followers()
			st()["followers"] = int(before * (1.0 + add_k)) + add_flat
			note("Podium! Followers: %s (+%s).", [str(followers()), str(followers() - before)])
		else:
			var e: Dictionary = GameData.Career.pilot(ev, id)
			names.append(str(e.get("pilot", "?")))
			var wid := int(e.get("wid", -1))
			var p := World.pilot(wid) if wid >= 0 else {}
			if not p.is_empty():
				p["fol"] = int(pilot_fol(p) * (1.0 + add_k)) + add_flat
	var tag := tag_for(kind if kind in ["title", "cup"] else str(ev.get("stage", "")))
	post("botmedia", "%s is over. Gold: %s. Silver: %s. Bronze: %s.", [str(ev.get("name", "")), names[0], names[1], names[2]],
			{"kind": "podium", "names": names}, [tag, "Podium"])
	var win_id := int(order[0])
	if win_id == 0:
		st()["draft"] = {"opp": str(ev.get("name", "")), "wid": -1, "won": true, "tag": tag, "at": now_t()}
	else:
		var e0: Dictionary = GameData.Career.pilot(ev, win_id)
		if int(e0.get("wid", -1)) >= 0:
			post("w:%d" % int(e0["wid"]), "Champions of the %s. Thank you, Port Ferrum.", [str(ev.get("name", ""))], {}, [tag, "Podium"])


## A pilot's Read moved a whole dot, or they're rattled / steady again.
static func read_event(p: Dictionary, kind: String) -> void:
	if GameData.world.is_empty():
		return
	var key := "w:%d" % int(p["wid"])
	var dots := World.read_dots(World.read_of(p))
	var big: bool = str(p.get("tier", "")) in ["iron", "steel"] or follows(key)
	match kind:
		"up":
			if big or randf() < 0.3:
				post(key, ["Sparring paid off. I'm reading fights better than ever.", "Something clicked this month. Watch me.",
						"Better every week. Ask my last opponent."][int(p["wid"]) % 3], [], {"kind": "read", "dots": dots}, ["ReadUp"])
		"down":
			if big:
				post("botmedia", "%s has lost a step. Read down to %d dots.", [p["name"], dots], {"kind": "read", "dots": dots}, ["ReadDown"])
		"rattled":
			if big or randf() < 0.35:
				post(fan_key(int(p["wid"]) + GameData.week), "%s looks RATTLED. Three bad nights and counting.", [p["name"]], {"kind": "rattled"},
						[str(p["name"]).replace(" ", "") + "Rattled"])
		"steady":
			if big:
				post(key, "Head's clear again. Next.", [], {}, [])


## Every morning: the announcers call fight night, Kane runs adverts, the dealer shouts about stock,
## a fan or two chatters, and now and then a pilot shows off a sponsor.
static func daily() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameData.year * 4099 + GameData.week * 31 + GameData.day_index()
	var day: String = GameData.day
	if day == "sat":
		var hm: Dictionary = GameData.headline_match()
		if not hm.is_empty():
			var ev: Dictionary = hm["ev"]
			post("mic_grand", "TONIGHT: %s against %s. Be there.", [str(GameData.Career.pilot(ev, int(hm["a"])).get("pilot", "?")),
					str(GameData.Career.pilot(ev, int(hm["b"])).get("pilot", "?"))], {}, ["FightNight", tag_for(str(ev.get("stage", "")))])
		post("mic_scrap", "Scrap Heap tonight! Bring earplugs and a spare bolt.", [], {}, ["FightNight"])
	if day == "mon" and GameData.week % 2 == 0:
		post("kane", ["Programs don't ask for a cut. OVERLORD, every Saturday.", "Why trust a tired pilot? Trust Kane Dynamics.",
				"OVERLORD has never missed a punch. Ever.", "The future fights alone. Kane Dynamics."][(GameData.week / 2) % 4], [], {"kind": "ad"}, ["OVERLORD"])
	if day == "sun":
		post("partsrus", "New stock is in. First come, first bolted.", [], {}, ["SundayStock"])
	# a fan reacts to someone at the top
	var tops := World.active("steel") + World.active("iron")
	if not tops.is_empty() and rng.randf() < 0.7:
		var p: Dictionary = tops[rng.randi() % tops.size()]
		post(fan_key(rng.randi()), ["Is %s overrated? Asking for a friend.", "%s is the best pilot in this city and it's not close.",
				"Saw %s at the docks. Shorter than I thought.", "Someone tell %s to stop spending and start winning."][rng.randi() % 4],
				[p["name"]], {}, [])
	# now and then a pilot shows off a sponsor
	if rng.randf() < 0.25 and not tops.is_empty():
		var p2: Dictionary = tops[rng.randi() % tops.size()]
		var ids: Array = GameData.Contracts.SPONSORS.keys().filter(func(k): return k != "kane" and k != "rustybolt")
		var sp: String = ids[rng.randi() % ids.size()]
		post("w:%d" % int(p2["wid"]), "Proud to fight in %s colours this season.", [GameData.Contracts.SPONSORS[sp]["name"]], {"kind": "logo", "logo": sp}, [str(GameData.Contracts.SPONSORS[sp]["tag"])])
