extends RefCounted
const PlayLog = preload("res://playlog.gd")   # (1.87) the playtest log
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
	if key.begins_with("sp:mk:"):
		return account(key.substr(3))   # a maker's contract talks from the maker's own account
	if key.begins_with("sp:"):
		var sp: Dictionary = GameData.Contracts.sp(key.substr(3))
		return {"name": str(sp.get("name", "?")), "handle": str(sp.get("handle", "?")), "fol": int(sp.get("fol", 5000)),
				"verified": true, "logo": key.substr(3)}
	if key.begins_with("mk:"):
		# (1.95) a maker's account
		var m := key.substr(3)
		var M = GameData.Makers
		return {"name": str(M.info(m).get("name", "?")), "handle": M.handle(m), "fol": int(M.FOLLOWERS.get(m, 20000)),
				"verified": true, "logo": M.logo(m), "maker": m}
	if key.begins_with("mf:"):
		# (1.95) a fan loyal to one maker: "mf:<maker>:<n>"
		var bits := key.split(":")
		var fl: Array = GameData.Makers.FANS.get(bits[1], ["fan"])
		var nm := str(fl[int(bits[2]) % fl.size()]) if bits.size() > 2 else str(fl[0])
		return {"name": nm, "handle": nm, "fol": 60 + absi(hash(nm)) % 2400, "fan": true, "maker": bits[1]}
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
static func post(by: String, text: String, args: Array = [], card: Dictionary = {}, tags: Array = [], mention: bool = false, ctx: String = "") -> Dictionary:
	if by == "me":
		PlayLog.add("post", (text % args) if args.size() > 0 and text.count("%") >= args.size() else text)
	var s := st()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["next"]) * 977 + GameData.year
	var fol := float(account(by).get("fol", 100))
	var likes := int(fol * rng.randf_range(0.008, 0.035) * (1.6 if mention else 1.0)) + rng.randi_range(0, 6)
	var p := {"id": int(s["next"]), "at": now_t(), "y": GameData.year, "w": GameData.week, "d": GameData.day,
			"by": by, "text": text, "args": args, "card": card, "tags": tags, "likes": likes,
			"reposts": int(likes * rng.randf_range(0.04, 0.14)), "replies": int(likes * rng.randf_range(0.02, 0.09)),
			"mention": mention}
	if ctx != "":
		p["ctx"] = ctx   # (1.85) what the post is about: the replies you can give depend on it
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
	elif field == "replies" and p.has("thread"):
		for r in p["thread"]:
			if str(r["by"]) == "me" or int(r.get("at", 0)) > int(p.get("at", 0)) + 3:
				mine += 1   # your replies and the answers that came later count on top
	elif field == "reposts" and reposted(int(p["id"])):
		mine = 1
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
				ok = by == "me" or follows(by) or p.get("mention", false) or (by.begins_with("mk:") and str(p.get("ctx", "")) == "maker_ad" and (p.get("card", {}) as Dictionary).get("kind", "") == "mkad")   # (1.95) maker adverts show up like sponsored posts
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
		# (1.58) liking a pilot's post warms them up a little: once a day per pilot
		var wid := wid_of_post(id)
		var seen: Dictionary = st().get("rel_like", {})
		st()["rel_like"] = seen
		var today := "%d:%d:%s" % [GameData.year, GameData.week, GameData.day]
		if wid >= 0 and str(seen.get(str(wid), "")) != today:
			seen[str(wid)] = today
			GameData.rel_add(wid, REL_LIKE, GameData.REL_SOCIAL_CAP)


## (1.87) A like on a reply in a thread: kept on the reply; a pilot's reply warms them like a post does.
static func toggle_reply_like(r: Dictionary) -> void:
	if r.get("liked", false):
		r.erase("liked")
		r["likes"] = maxi(0, int(r.get("likes", 0)) - 1)
		return
	r["liked"] = true
	r["likes"] = int(r.get("likes", 0)) + 1
	var by := str(r.get("by", ""))
	if not by.begins_with("w:"):
		return
	var wid := int(by.substr(2))
	var seen: Dictionary = st().get("rel_like", {})
	st()["rel_like"] = seen
	var today := "%d:%d:%s" % [GameData.year, GameData.week, GameData.day]
	if str(seen.get(str(wid), "")) != today:
		seen[str(wid)] = today
		GameData.rel_add(wid, REL_LIKE, GameData.REL_SOCIAL_CAP)


## What a like, a repost, a reply or a post does to what's between you (1.58).
const REL_LIKE := 1.0
const REL_REPOST := 3.0
const REL_REPLY_FRIENDLY := 5.0
const REL_REPLY_CUTTING := -8.0
const REL_TRASH := -10.0
const REL_HUMBLE := 4.0
const REL_HYPE_WATCHED := 6.0
const REL_HUMBLE_WATCHED := 3.0


## The world pilot behind a post (-1 = not a pilot).
static func wid_of_post(id: int) -> int:
	var p := find_post(id)
	if p.is_empty():
		return -1
	var by := str(p["by"])
	return int(by.substr(2)) if by.begins_with("w:") else -1


static func reposted(id: int) -> bool:
	return st().get("reposted", {}).has(str(id))


## Repost somebody's post: it shows on your profile, counts as a post, and the pilot likes it.
static func repost(id: int) -> void:
	var p := find_post(id)
	if p.is_empty() or reposted(id) or str(p["by"]) == "me":
		return
	var r: Dictionary = st().get("reposted", {})
	st()["reposted"] = r
	r[str(id)] = true
	var acc := account(str(p["by"]))
	post("me", "Reposted @%s", [str(acc["handle"])], {"kind": "quote", "id": id}, p.get("tags", []))
	count_post()
	var wid := wid_of_post(id)
	if wid >= 0:
		rel_social(wid, REL_REPOST, day_factor(str(p["by"])), GameData.REL_SOCIAL_CAP)


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

## How many followers a pilot can expect in each league (1.53): gains slow down as you get close
## and almost stop past it, so following grows with your league, not with the number of fights.
const FOL_CEIL := {"open": 2500, "scrap": 15000, "rust": 60000, "iron": 250000, "steel": 1000000, "title": 2000000}


static func fol_change(f: int, won: bool, destroyed: int, intact: int, lost_parts: int, stage: String) -> int:
	var key := stage
	var k_pick := 1.0
	if not FOL_CEIL.has(key):
		key = str(GameData.rank) if FOL_CEIL.has(str(GameData.rank)) else "scrap"
		k_pick = 0.5 if stage == "pickup" else 1.0   # a pickup at the pub is half the news of a league night
	var flat: float = float(FOL_FLAT.get(key, 50)) * k_pick
	var room := clampf(1.0 - float(f) / float(FOL_CEIL[key]), 0.03, 1.0)
	var x := float(f)
	var gain := 0.0
	if won:
		gain += x * 0.03 * k_pick + flat
	else:
		x -= x * 0.03
	gain += destroyed * (float(f) * 0.01 + flat / 5.0) + intact * float(f) * 0.01
	x += gain * room
	x -= lost_parts * float(f) * 0.01
	return maxi(0, int(round(x)))


## Two world pilots fought: followers move, and the notable ones make a noise.
const STAGE_VENUE := {"open": "scrap_ring", "scrap": "scrap_ring", "rust": "regional_hall", "iron": "regional_final", "steel": "champ_arena", "title": "champ_gala", "cup": "regional_hall"}


static func world_fight(rng: RandomNumberGenerator, winner: Dictionary, loser: Dictionary, stage: String) -> void:
	if winner.is_empty() or loser.is_empty():
		return
	var ripped := rng.randi_range(0, 2)
	# (1.95) a win in one maker's parts: the maker (or one of its fans) says so now and then
	var wm: String = GameData.Makers.main_of(winner.get("bot", {}).get("parts", {}).values())
	if wm != "" and stage != "pickup" and rng.randf() < 0.08:
		post("mk:" + wm, GameData.Makers.SHOUT[rng.randi() % GameData.Makers.SHOUT.size()], [GameData.Makers.label(wm), winner["name"]], {}, [], false, "maker_ad")
	elif wm != "" and stage != "pickup" and rng.randf() < 0.06:
		post(mfan(wm, rng), GameData.Makers.FAN_CHEER[rng.randi() % GameData.Makers.FAN_CHEER.size()], [winner["name"], GameData.Makers.label(wm)], {}, [], false, "fan_top")
	winner["fol"] = fol_change(pilot_fol(winner), true, ripped, 0, 0, str(winner.get("tier", stage)))
	loser["fol"] = fol_change(pilot_fol(loser), false, 0, 0, ripped, str(loser.get("tier", stage)))
	# an upset: two Read dots or more below, and won anyway
	var dw := World.read_dots(World.read_of(winner))
	var dl := World.read_dots(World.read_of(loser))
	if dl - dw >= 2 and stage != "pickup":
		var tag := tag_for(stage)
		post("w:%d" % int(winner["wid"]), ["Nobody gave me a chance against %s. Nobody.", "Write it down: I beat %s.",
				"Who's laughing now, %s?"][rng.randi() % 3], [loser["name"]], {"kind": "still", "wa": int(winner["wid"]), "wb": int(loser["wid"]), "won": true, "an": winner["name"], "bn": loser["name"],
				"venue": STAGE_VENUE.get(stage, "scrap_ring")}, [tag, "UpsetOfTheWeek"], false, "pilot_upset")
		post(fan_key(rng.randi()), ["%s just beat %s. I need to sit down.", "Upset of the week: %s over %s.",
				"My bet slip is crying. %s beat %s."][rng.randi() % 3], [winner["name"], loser["name"]], {}, ["UpsetOfTheWeek"], false, "fan_upset")


## Your fight: followers, a post from your opponent, from Gus when you win, from a fan or two,
## and your own post waiting for you on BotMedia.
static func my_fight(o: Dictionary, won: bool, destroyed: int, intact: int, own_lost: int, stage: String) -> void:
	var s := st()
	var before := int(s["followers"])
	s["followers"] = fol_change(before, won, destroyed, intact, own_lost, stage if stage != "" else GameData.rank)
	if int(s["followers"]) > before and GameData.Makers.sets(GameData.equipped_ids().values()).has("menagerie"):
		s["followers"] = before + int((int(s["followers"]) - before) * 1.25)   # (1.90) Menagerie set: the crowd loves a show
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
					"Lost to %s. I'll be back."][rng.randi() % 3], [GameData.pilot_name], card, [tag], true, "opp_lost")
		else:
			post("w:%d" % wid, ["Too easy. %s, call me when you've grown up.", "Thanks for the warm-up, %s.",
					"Another win. Sorry, %s."][rng.randi() % 3], [GameData.pilot_name], card, [tag], true, "opp_won")
	if won:
		post("gus", ["Good night at the bay. Kid did alright.", "Dents to fix, money in the jar. Good night.",
				"Told you that robot still had it."][rng.randi() % 3], [], {}, [], false, "gus_win")
	post(fan_key(rng.randi()), ["%s is the real deal. Saw it from the cheap seats.", "Did anyone else see %s tonight?",
			"Keep an eye on %s."][rng.randi() % 3] if won else ["Rough one for %s tonight.", "%s will be back. Probably.",
			"Not %s's night."][rng.randi() % 3], [GameData.pilot_name], {}, [tag], false, "fan_me_win" if won else "fan_me_loss")
	if destroyed > 0 and won:
		post(fan_key(rng.randi() + 3), "%s tore %d parts off tonight. Somebody call a scrap man.", [GameData.pilot_name, destroyed], {}, [tag], false, "fan_me_win")
	# a robot bolted together off-label gets people talking (1.54)
	var odd: Array = GameData.off_label_kinds()
	if not odd.is_empty():
		var lines := {"leg_arm": ["%s just punched somebody with a FOOT. Broke or genius?", "Is that a leg where %s's arm should be? Asking for a friend."],
				"arm_leg": ["Saw %s walk on its fists tonight. I can't unsee it.", "%s's robot is standing on its hands. Nobody tell the league."],
				"reactor_arm": ["Is that a battery strapped to %s's shoulder? Bold.", "%s fights one arm short with a reactor taped on. Respect."]}
		var k: String = odd[rng.randi() % odd.size()]
		var pick: Array = lines[k]
		var oddp := post(fan_key(rng.randi() + 7), pick[rng.randi() % pick.size()], [GameData.pilot_name], {}, [tag, "ScrapEngineering"], false, "fan_offlabel")
		oddp["likes"] = int(oddp["likes"]) * 3 + 20   # people love a mess
		if won:
			post("gus", ["It's not pretty, but it won. That's engineering.", "Don't tell anyone how we bolted that together."][rng.randi() % 2], [], {}, [], false, "gus_win")
	maker_after_fight(won, rng)   # (1.95)
	# your own post: three drafts to pick from on BotMedia
	s["draft"] = {"opp": opp_name, "wid": wid, "won": won, "tag": tag, "at": now_t()}
	if int(s["followers"]) != before:
		note("Followers: %s (%s).", [str(s["followers"]), ("+" if int(s["followers"]) > before else "") + str(int(s["followers"]) - before)])


## The drafts for your post after a fight: [tone, text template].
static func drafts() -> Array:
	var d: Dictionary = st()["draft"]
	if d.is_empty() or now_t() - int(d.get("at", 0)) > 9:
		return []   # three days on, nobody cares any more
	if d.get("watch", false):
		# a fight you watched from ringside (1.56): winner, loser
		# (1.57) five options: trash talk the winner, the loser, or both
		var w_opts := [["humble", "Watched %s beat %s from ringside. Respect to both."], ["hype", "%s over %s! Somebody put that on the big screen."],
				["trash_w", "%s beat %s and still looked slow. Lucky night."],
				["trash_l", "%s won, sure. But %s was never going to. Retire."],
				["trash", "%s beat %s and still looked slow. I'd take either of them."]]
		if d.get("gloat", false):
			w_opts.push_front(["gloat", "Backed %s against %s at long odds. Payday."])   # (1.73) a big live bet paid
		return w_opts
	if d["won"]:
		return [["humble", "Good fight, %s. I got lucky with that last one."], ["hype", "ANOTHER ONE. %s didn't know what hit them."],
				["trash", "%s, go back to the scrapyard. I'll be here when you're ready."]]
	return [["humble", "%s was better tonight. Back to the bay."], ["hype", "That's one loss. Watch what happens next, %s."],
			["trash", "%s got lucky. Everyone saw it."]]


## What fills the draft's %s: your opponent, or the winner and the loser of a fight you watched.
static func draft_args() -> Array:
	var d: Dictionary = st()["draft"]
	return d.get("args", [d.get("opp", "")])


## A fight you watched: a post waiting about it (the draft replaces any older one).
static func watched_fight(winner: String, loser: String, wid: int, stage: String, lwid: int = -1) -> void:
	st()["draft"] = {"watch": true, "opp": winner, "args": [winner, loser], "wid": wid, "lwid": lwid, "won": true, "tag": tag_for(stage), "at": now_t()}


## The pilot ids behind draft_args() (-1 = not a world pilot), to mark rivals in the drafts.
static func draft_wids() -> Array:
	var d: Dictionary = st()["draft"]
	if d.get("watch", false):
		return [int(d.get("wid", -1)), int(d.get("lwid", -1))]
	return [int(d.get("wid", -1))]


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
	var watched: bool = d.get("watch", false)
	var w1 := int(d.get("wid", -1))
	var w2 := int(d.get("lwid", -1)) if watched else -1
	# (1.67) diminishing gains: the same pilot (or, with nobody named, the same tag) counts less each time today
	var k1 := day_factor("w:%d" % w1 if w1 >= 0 else "#" + str(d.get("tag", "")))
	var k2 := day_factor("w:%d" % w2) if w2 >= 0 else 1.0
	match tone:
		"humble":
			f *= 1.0 + 0.005 * k1
			# kind words: your opponent (or both of them, when you watched) warm up a little
			rel_social(w1, REL_HUMBLE_WATCHED if watched else REL_HUMBLE, k1, GameData.REL_SOCIAL_CAP)
			rel_social(w2, REL_HUMBLE_WATCHED, k2, GameData.REL_SOCIAL_CAP)
		"hype":
			f *= (1.0 + 0.02 * k1) if d["won"] else 0.98
			if watched:
				rel_social(w1, REL_HYPE_WATCHED, k1, GameData.REL_SOCIAL_CAP)   # the winner loves it
		"gloat":
			f *= 1.0 + 0.015 * k1
			rel_social(w1, 2.0, k1, GameData.REL_SOCIAL_CAP)   # the pilot you backed likes the money talk
		"trash", "trash_w", "trash_l":
			f *= 1.0 + 0.01 * k1
			# who takes it personally: your opponent; when you watched, the winner, the loser or both
			if tone != "trash_l":
				rel_social(w1, REL_TRASH, k1)
			if tone != "trash_w":
				rel_social(w2, REL_TRASH, k2)
	s["followers"] = int(round(f))
	var pic: Dictionary = d.get("pic", {})
	if str(pic.get("kind", "")) == "clip":
		GameData.keep_clip(str(pic.get("id", "")))   # (1.74) a posted clip is kept for good
	var mine := post("me", text, draft_args(), pic, [str(d.get("tag", ""))])
	if str(pic.get("kind", "")) == "clip":
		mine["likes"] = int(mine["likes"] * 1.6)   # people stop scrolling for a clip
		mine["reposts"] = int(mine["reposts"] * 2.0)
	if not watched and w1 >= 0:
		mine["opp_wid"] = w1   # your opponent can turn up in the thread
	count_post()
	GameData.Contracts.on_post(tone)
	s["draft"] = {}


static func count_post() -> void:
	var pw: Dictionary = st()["posts_week"]
	var k := str(World.abs_week())
	pw[k] = int(pw.get(k, 0)) + 1


static func posts_this_week() -> int:
	return int(st()["posts_week"].get(str(World.abs_week()), 0))


# ---------------------------------------------------------------- threads (1.67)
# Every post has a thread: a few world replies made up when it's first opened (seeded by the post,
# so they stay the same), your replies, and pilots answering you a part of the day later. A reply is
# {r (number in the thread), by (account key), text (English template), args, at, to (the reply it
# answers, -1 = the post), likes}. Replies are always picked from tones, never typed.

## (1.85) What you can say depends on what you're answering. Every post and every reply has a
## context (ctx): set where it's made (post(..., ctx)), or worked out from who wrote it (ctx_of).
## CTX_REPLIES[ctx] = [[tone, line, relationship move], ...]; %s = their name. Tones that ask for
## something: "rematch" / "ring" (a fight), "team" (a tag team): the pilot may say yes, and their
## answer carries the offer (a button in the thread books it).
const CTX_REPLIES := {
	# your opponent, about your fight
	"opp_lost": [["respect", "Good fight, %s. You made me work for every bolt.", 6.0], ["rematch", "Any time, %s. Name the night.", 0.0],
			["gloat", "Lucky? The replay says otherwise, %s.", -6.0], ["trash", "Back to the scrapyard, %s.", -10.0]],
	"opp_won": [["respect", "Fair win, %s. You earned it.", 6.0], ["rematch", "Run it back, %s. Any night you like.", -1.0],
			["doubt", "One night, %s. Don't get used to it.", -4.0], ["trash", "Enjoy it, %s. It won't happen twice.", -8.0]],
	# pilots about themselves
	"pilot_upset": [["congrats", "Nobody saw that coming, %s. Well fought.", 5.0], ["joke", "Somebody check %s's robot for magnets.", 2.0],
			["doubt", "Even a broken clock, %s.", -4.0], ["trash", "Do it twice and I'll care, %s.", -8.0]],
	"pilot_champ": [["congrats", "Earned every bit of it, %s.", 5.0], ["joke", "Save me a spot on that podium next year, %s.", 2.0],
			["doubt", "Enjoy the view, %s. I'm coming up.", -3.0], ["trash", "Weak year, %s. Lucky you.", -8.0]],
	"pilot_readup": [["team", "Spar with me one night, %s? Tag team at the Bolt.", 3.0], ["joke", "Reading fights or reading the paper, %s?", 2.0],
			["doubt", "Show it in the ring, %s.", -3.0], ["trash", "Read this, %s: you're still slow.", -8.0]],
	"pilot_sponsor": [["friendly", "Looks good on you, %s.", 4.0], ["joke", "How many cans of that do they pay you in, %s?", 2.0],
			["trash", "Sellout, %s.", -6.0]],
	"pilot_tag": [["friendly", "Good team. Do it again soon, %s.", 5.0], ["team", "Next time take me along, %s.", 3.0],
			["joke", "Two on two and you still needed help, %s?", -2.0]],
	"pilot_feud": [["calm", "Leave it in the ring, %s.", 3.0], ["joke", "Somebody get these two a room. A ring. Whatever.", 0.0],
			["trash", "You're both bums, %s.", -8.0]],
	"pilot": [["friendly", "Respect, %s. See you in the ring.", 5.0], ["joke", "%s, save some of that for Saturday.", 2.0],
			["doubt", "We'll see about that, %s.", -4.0], ["trash", "Big words for someone with your record, %s.", -10.0]],
	# fans
	"fan_me_win": [["thanks", "Thanks, %s. The noise helps more than you think.", 0.0], ["hype", "Wait till you see the next one, %s.", 0.0],
			["humble", "All Gus. I just push the buttons.", 0.0]],
	"fan_me_loss": [["promise", "We'll be back, %s. Stick around.", 0.0], ["joke", "The robot took it worse than me. Barely.", 0.0],
			["fire", "Keep watching, %s. This isn't the end of it.", 0.0]],
	"fan_doubt": [["promise", "Watch this space, %s.", 0.0], ["joke", "My mum says I'm talented, %s.", 0.0], ["mock", "Who are you again, %s?", 0.0]],
	"fan_offlabel": [["proud", "Broke AND genius. Why not both?", 0.0], ["joke", "Gus calls it engineering. I call it Tuesday.", 0.0],
			["humble", "It's what we had. It worked.", 0.0]],
	"fan_top": [["agree", "Couldn't agree more, %s.", 0.0], ["hype", "Ask me again after I fight them, %s.", 0.0], ["doubt", "Hard disagree, %s.", 0.0]],
	"fan_upset": [["agree", "Told you. Anything can happen in that ring.", 0.0], ["joke", "Somebody owes somebody a lot of money tonight.", 0.0]],
	"fan_rattled": [["kind", "Everyone has bad weeks. They'll come back.", 0.0], ["joke", "Rattled is my default setting, %s.", 0.0],
			["mock", "Kick them while they're down, %s. Classy.", 0.0]],
	"fan": [["agree", "Couldn't agree more, %s.", 0.0], ["joke", "%s, you need a hobby. Oh, wait.", 0.0], ["doubt", "Hard disagree, %s.", 0.0]],
	# news, announcers, adverts
	"news_me": [["humble", "Just doing the work.", 0.0], ["hype", "Write it down. There's more coming.", 0.0], ["joke", "Finally famous. Mum, I'm on the news.", 0.0]],
	"news_me_good": [["shill", "Proud of this one. Big things coming.", 0.0], ["humble", "Grateful. Back to the bay.", 0.0]],
	"news_me_bad": [["calm", "It happens. We move on.", 0.0], ["joke", "Their loss. I wasn't drinking it anyway.", 0.0]],
	"news_podium": [["congrats", "Big year for all three. Respect.", 0.0], ["hype", "Next year that's my name up there.", 0.0], ["doubt", "Weak field this year.", 0.0]],
	"news_clip": [["wow", "I've watched this ten times.", 0.0], ["joke", "My robot felt that one from here.", 0.0], ["doubt", "Overrated. Seen better at the scrap ring.", 0.0]],
	"news_slump": [["kind", "Everyone slips. Watch them come back.", 0.0], ["doubt", "Called it months ago.", 0.0]],
	"news": [["agree", "Called it.", 0.0], ["joke", "My toaster could do better. Actually, my toaster fights.", 0.0],
			["doubt", "Not buying it. Wait for the next round.", 0.0]],
	"announcer": [["hype", "I'll be there. Front row.", 0.0], ["joke", "Bring earplugs? Bring a helmet.", 0.0]],
	"kane_ad": [["doubt", "Programs don't feel the crowd.", 0.0], ["mock", "Kane, sell me a toaster instead.", 0.0], ["agree", "Can't argue with results.", 0.0]],
	"shop_ad": [["shill", "Save me something good.", 0.0], ["mock", "Last week's stock fell apart in a week.", 0.0]],
	"sponsor_welcome": [["shill", "Proud to wear your colours.", 0.0], ["hype", "Let's win some together.", 0.0]],
	"ad": [["shill", "Good stuff. I'd know.", 0.0], ["mock", "Nobody asked, %s.", 0.0]],
	"maker_ad": [["shill", "Running your parts. No complaints.", 0.0], ["agree", "Best in Port Ferrum, %s.", 0.0], ["mock", "Overpriced and you know it, %s.", 0.0]],
	"fan_maker": [["agree", "Couldn't agree more, %s.", 0.0], ["joke", "Maker wars again? Get a hobby, %s.", 0.0], ["doubt", "It's the pilot, not the parts, %s.", 0.0]],
	"gus_win": [["thanks", "Couldn't do it without you, Gus.", 0.0], ["joke", "Gus, put the phone down and fix my arm.", 0.0],
			["hype", "Next week we go bigger.", 0.0]],
	"gus": [["friendly", "Best boss in Port Ferrum.", 0.0], ["joke", "Gus, put the phone down and fix my arm.", 0.0]],
	# answering a pilot who answered you (the conversation goes on)
	"answer_bite": [["double", "Saturday then, %s. Bring a spare head.", -8.0], ["ring", "Talk's cheap. Book it, %s.", -2.0],
			["laugh", "Ha. You're funnier when you lose, %s.", 1.0], ["calm", "Easy, %s. It's just talk.", 4.0]],
	"answer_warm": [["drink", "First round's on me at the Bolt, %s.", 5.0], ["team", "We should team up one night, %s.", 3.0],
			["joke", "Careful, %s. People will think we're friends.", 2.0]],
	"answer_cool": [["push", "Noted? That's all you've got, %s?", -3.0], ["friendly", "Fair enough. Good luck out there, %s.", 3.0]],
	"answer_yes": [["thanks", "See you there, %s.", 2.0], ["hype", "Bring everything you've got, %s.", -1.0]],
	"answer_no": [["push", "Scared, %s?", -4.0], ["calm", "Another time then, %s.", 2.0]],
}
## Tones that make a pilot bite back, and tones that ask for something.
const BITE_TONES := ["doubt", "trash", "gloat", "double", "push", "mock"]
const ASK_TONES := {"rematch": "rematch", "ring": "rematch", "team": "tag"}
## Followers a reply wins you (a share of what you have), by tone.
const REPLY_FOL := {"friendly": 0.002, "joke": 0.004, "doubt": 0.003, "trash": 0.01, "agree": 0.002, "shill": 0.002, "mock": 0.005,
		"respect": 0.003, "gloat": 0.008, "rematch": 0.005, "congrats": 0.002, "hype": 0.004, "thanks": 0.002, "humble": 0.002,
		"double": 0.008, "ring": 0.006, "laugh": 0.004, "proud": 0.004, "wow": 0.003, "fire": 0.004, "promise": 0.003}

## World replies made up when a thread is first opened.
const FAN_LINES := ["Facts.", "This is why I watch.", "No chance.", "Saturday can't come soon enough.", "Who asked?", "Big if true.",
		"Legend.", "Overrated, and I'll say it again.", "I was there. Loudest night of the year.", "My dad says the old pilots were better."]
const FAN_TO_ME := ["Let's go, %s!", "Proud of you, %s.", "%s for the Titanium. Calling it now."]
const FAN_DOUBT_ME := ["Rookie luck, %s. Prove me wrong.", "One good night doesn't make a pilot, %s.", "Still think that robot's held together with tape, %s."]
const OPP_FRIEND := ["Good fight. Next one's mine.", "Respect. I'll buy you a drink at the Bolt."]
const OPP_RIVAL := ["Enjoy it while it lasts.", "Lucky. Everyone saw it."]
const OPP_PLAIN := ["Fair enough. See you around.", "Not bad, rookie."]
## A pilot answering you: by the kind of answer, and whether it's about your fight ("fight") or not.
const ANSWERS := {
	"warm": ["Ha. Fair point.", "See you at the Bolt, %s.", "You're all right, %s.", "Respect goes both ways, %s.", "Ha. Alright, alright."],
	"warm_fight": ["Next one's mine though, %s.", "You fought clean, %s. I'll give you that.", "Good scrap, %s. My bay's still smoking."],
	"bite": ["Say that to my face on Saturday.", "Keep talking, %s. It suits you.", "Cute. Real cute.", "My robot remembers faces, %s."],
	"bite_fight": ["Run your mouth now, %s. Saturday you won't.", "I've watched the tape. I know your tells now, %s.", "One lucky night and you're a star, %s?"],
	"bite_hard": ["That's it. You and me, %s. Name the night.", "Enough talk. The Bolt, tonight, %s. Unless you're busy hiding.",
			"You want it that bad, %s? Come and get it.", "I'm done typing, %s. Ring. Tonight."],
	"cool": ["We'll see.", "Noted.", "Sure, %s.", "If you say so."],
	"friends": ["You know what, %s? You're alright. Drinks are on me.", "We should do this more often, %s. In the ring and out of it."],
	"yes_rematch": ["You're on, %s. The Bolt, tonight.", "Done. Tonight. Don't be late, %s."],
	"no_rematch": ["Not tonight, %s. Got my own fights.", "Find someone your own size, %s."],
	"yes_tag": ["Tonight then, %s. Two on two at the Bolt.", "Why not. Meet me at the Bolt, %s."],
	"no_tag": ["Not tonight, %s. Maybe another time.", "Busy, %s. Ask me next week."],
}
const REL_ANSWER_WARM := 1.0
const REL_ANSWER_BITE := -3.0
## Old saves' answers (1.67) kept working.
const ANSWER_WARM := ["Ha. Fair point.", "See you at the Bolt, %s.", "You're all right, %s."]
const ANSWER_BITE := ["Say that to my face on Saturday.", "Keep talking, %s. It suits you.", "Cute. Real cute."]
const ANSWER_COOL := ["We'll see.", "Noted."]


## What kind of account this is, for the replies it gets.
static func kind_of(key: String) -> String:
	if key.begins_with("w:"):
		return "pilot"
	if key.begins_with("fan:") or key.begins_with("mf:"):
		return "fan"
	if key.begins_with("sp:") or key.begins_with("mk:") or key in ["kane", "partsrus", "rustybolt"]:
		return "ad"
	if key == "gus":
		return "gus"
	return "news"


## What a post is about (1.85): its own ctx, else worked out from who wrote it.
static func ctx_of(p: Dictionary) -> String:
	var c := str(p.get("ctx", ""))
	if c != "":
		return c
	var k := kind_of(str(p.get("by", "")))
	match k:
		"pilot":
			return "pilot"
		"fan":
			return "fan"
		"ad":
			return "ad"
		"gus":
			return "gus"
	return "news"


## The context of what you'd be answering: the post (to = -1) or a reply in its thread.
static func reply_ctx(p: Dictionary, to: int = -1) -> String:
	if to < 0:
		return ctx_of(p)
	var r := find_reply(p, to)
	var c := str(r.get("ctx", ""))
	if c != "":
		return c
	return {"pilot": "pilot", "fan": "fan", "ad": "ad", "gus": "gus"}.get(kind_of(str(r.get("by", ""))), "news")


## The replies you can give: [tone, line, relationship move].
static func reply_options(p: Dictionary, to: int = -1) -> Array:
	var c := reply_ctx(p, to)
	return CTX_REPLIES.get(c, CTX_REPLIES.get({"pilot": "pilot", "fan": "fan", "ad": "ad", "gus": "gus"}.get(c.split("_")[0], "news"), CTX_REPLIES["news"]))


## Kept for old callers: the replies for an account's own posts.
static func reply_options_for(key: String) -> Array:
	return CTX_REPLIES.get(kind_of(key), CTX_REPLIES["news"])


## The thread of a post (made up the first time it's opened).
static func thread(p: Dictionary) -> Array:
	if not p.has("thread"):
		var out: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = int(p["id"]) * 7919 + 17
		var by := str(p["by"])
		var n := clampi(int(p.get("replies", 0)), 0, 4)
		if by == "me":
			n = maxi(n, 2)
		var rn := 0
		# your opponent answers a post about your fight
		var opp := int(p.get("opp_wid", -1)) if by == "me" else -1
		if opp >= 0 and not World.pilot(opp).is_empty():
			var r := GameData.rel_of(opp)
			var pool: Array = OPP_FRIEND if r >= GameData.REL_FRIEND else (OPP_RIVAL if r <= -15.0 else OPP_PLAIN)
			var mine_won: bool = str((p.get("card", {}) as Dictionary).get("a", "")) == GameData.pilot_name or bool(p.get("won", true))
			out.append({"r": rn, "by": "w:%d" % opp, "text": pool[rng.randi() % pool.size()], "args": [], "at": int(p["at"]) + 1, "to": -1, "likes": rng.randi_range(5, 80),
					"ctx": "opp_lost" if mine_won else "opp_won"})
			rn += 1
		for i in n:
			var fk := fan_key(rng.randi())
			if by == "me" and rng.randf() < 0.6:
				var doubt := rng.randf() < 0.35
				var fp: Array = FAN_DOUBT_ME if doubt else FAN_TO_ME
				out.append({"r": rn, "by": fk, "text": fp[rng.randi() % fp.size()], "args": [GameData.pilot_name], "at": int(p["at"]) + rng.randi_range(0, 2), "to": -1, "likes": rng.randi_range(0, 30),
						"ctx": "fan_doubt" if doubt else "fan_me_win"})
			else:
				out.append({"r": rn, "by": fk, "text": FAN_LINES[rng.randi() % FAN_LINES.size()], "args": [], "at": int(p["at"]) + rng.randi_range(0, 2), "to": -1, "likes": rng.randi_range(0, 30)})
			rn += 1
		p["thread"] = out
		p["rn"] = rn
	return p["thread"]


## How many replies a thread has that it doesn't show ("+31 more").
static func more_replies(p: Dictionary) -> int:
	return maxi(0, grown(p, "replies") - thread(p).size())


static func reply_text(r: Dictionary) -> String:
	return World.news_text({"text": r["text"], "args": r.get("args", [])})


static func find_reply(p: Dictionary, rid: int) -> Dictionary:
	for r in thread(p):
		if int(r["r"]) == rid:
			return r
	return {}


## Diminishing gains (1.67): what you do toward the same pilot or account counts in full the first
## time each day, then half, a quarter, then nothing until tomorrow. peek = don't count this one.
const DAY_GAIN := [1.0, 0.5, 0.25, 0.0]
static func day_factor(target: String, peek: bool = false) -> float:
	if target == "":
		return 1.0
	var today := "%d:%d:%s" % [GameData.year, GameData.week, GameData.day]
	var dg: Dictionary = st().get("day_gain", {})
	if str(dg.get("_day", "")) != today:
		dg = {"_day": today}
		st()["day_gain"] = dg
	var n := int(dg.get(target, 0))
	if not peek:
		dg[target] = n + 1
	return DAY_GAIN[mini(n, DAY_GAIN.size() - 1)]


## A relationship move from something you posted, shrunk by how often you've aimed at them today.
static func rel_social(wid: int, amount: float, k: float, cap: float = 100.0) -> void:
	if wid < 0 or absf(amount * k) < 0.01:
		return
	GameData.rel_add(wid, amount * k, cap if amount > 0.0 else 100.0)


## Reply to a post (to = -1) or to a reply in its thread. Followers and the relationship move by the
## tone (shrunk by today's diminishing gains); a pilot may answer you later.
static func reply(id: int, tone: String, to: int = -1) -> void:
	var p := find_post(id)
	if p.is_empty():
		return
	var th := thread(p)
	var target := str(p["by"]) if to < 0 else str(find_reply(p, to).get("by", ""))
	if target == "" or target == "me":
		return
	var acc := account(target)
	var line := ""
	var move := 0.0
	for r in reply_options(p, to):
		if r[0] == tone:
			line = r[1]
			move = float(r[2])
	if line == "":
		return
	var k := day_factor(target)
	var wid := int(acc.get("wid", -1))
	if wid >= 0 and move != 0.0:
		rel_social(wid, move, k, GameData.REL_SOCIAL_CAP)
	st()["followers"] = int(followers() * (1.0 + float(REPLY_FOL.get(tone, 0.002)) * k))
	if tone in ["trash", "double", "gloat"]:
		GameData.Contracts.on_post("trash")
	elif tone == "shill" and target.begins_with("sp:"):
		GameData.Contracts.on_post("humble")
	var rid := int(p.get("rn", th.size()))
	p["rn"] = rid + 1
	# how deep the conversation is: your reply sits one under what it answers
	var depth := 0 if to < 0 else int(find_reply(p, to).get("depth", 0)) + 1
	th.append({"r": rid, "by": "me", "text": line, "args": [str(acc["name"])], "at": now_t(), "to": to, "likes": 0, "tone": tone, "depth": depth})
	p["replied"] = true
	count_post()
	if wid >= 0:
		_plan_answer(p, id, rid, target, wid, tone, depth)


## A pilot you answered may answer back a part of the day later (one at a time per pilot per thread).
## What they say depends on your tone, how they feel about you, what the post was about, and how
## long the back-and-forth has gone on: a few rounds of insults and they call you out to fight; a few
## rounds of kind words and they count you a friend. Asking for a fight or a team-up gets a yes or a no.
static func _plan_answer(p: Dictionary, id: int, rid: int, target: String, wid: int, tone: String, depth: int) -> void:
	var rel := GameData.rel_of(wid)
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 131 + rid * 17 + GameData.week
	var bite := BITE_TONES.has(tone)
	var ask: String = ASK_TONES.get(tone, "")
	var kind := "cool"
	var chance := 0.0
	if ask != "":
		# a yes needs nothing booked tonight, and they mustn't hate you (a rival likes a fight, though)
		var free: bool = GameData.fight_mode() == "open"
		var yes := false
		if ask == "rematch":
			yes = free and (rel <= -15.0 or rng.randf() < 0.6)
		else:
			yes = free and rel > -15.0 and rng.randf() < (0.5 + rel / 100.0)
		kind = ("yes_" if yes else "no_") + ask
		chance = 1.0
	elif bite:
		kind = "bite_hard" if depth >= 2 or GameData.nemeses.has(wid) else "bite"
		chance = (0.5 + (0.4 if rel <= GameData.REL_RIVAL else 0.0))
		if GameData.nemeses.has(wid) or depth >= 2:
			chance = 1.0
	else:
		kind = "friends" if depth >= 2 and rel >= 15.0 else ("warm" if tone not in ["calm", "push"] else "cool")
		chance = 0.4 + (0.3 if rel >= 15.0 else 0.0) + (0.2 if depth >= 1 else 0.0)
	if is_blocked(target) or rng.randf() >= chance:
		return
	var ans: Array = st().get("answers", [])
	st()["answers"] = ans
	for a in ans:
		if int(a["post"]) == id and str(a["by"]) == target:
			return   # one answer at a time from each pilot in a thread
	var fight: bool = str(p.get("ctx", "")).begins_with("opp_") or str(p.get("ctx", "")) == "pilot_feud"
	ans.append({"post": id, "to": rid, "by": target, "kind": kind, "fight": fight, "depth": depth + 1, "due": now_t() + 1})


## Answers that are due arrive (called when BotMedia opens and every morning).
static func tick() -> void:
	dm_tick()
	var ans: Array = st().get("answers", [])
	if ans.is_empty():
		return
	var keep: Array = []
	for a in ans:
		if int(a["due"]) > now_t():
			keep.append(a)
			continue
		var p := find_post(int(a["post"]))
		if p.is_empty():
			continue
		var th := thread(p)
		var kind := str(a["kind"])
		var pool_key := kind
		if (kind == "warm" or kind == "bite") and bool(a.get("fight", false)):
			pool_key = kind + "_fight"
		var pool: Array = ANSWERS.get(pool_key, ANSWERS.get(kind, ANSWER_COOL))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(a["post"]) * 31 + int(a["to"])
		var rid := int(p.get("rn", th.size()))
		p["rn"] = rid + 1
		# a line they haven't used in this thread yet, if there is one
		var said: Array = th.filter(func(x): return str(x["by"]) == str(a["by"])).map(func(x): return str(x["text"]))
		var fresh: Array = pool.filter(func(x): return not said.has(x))
		var use: Array = fresh if not fresh.is_empty() else pool
		var rep := {"r": rid, "by": str(a["by"]), "text": use[rng.randi() % use.size()], "args": [GameData.pilot_name], "at": now_t(), "to": int(a["to"]),
				"likes": rng.randi_range(2, 40), "depth": int(a.get("depth", 1))}
		# what you can say back to this answer
		if kind.begins_with("yes_"):
			rep["ctx"] = "answer_yes"
			rep["offer"] = kind.substr(4)   # a button in the thread books it
		elif kind.begins_with("no_"):
			rep["ctx"] = "answer_no"
		elif kind == "bite_hard":
			rep["ctx"] = "answer_bite"
			rep["offer"] = "rematch"   # they called you out
		elif kind == "bite":
			rep["ctx"] = "answer_bite"
		elif kind == "warm" or kind == "friends":
			rep["ctx"] = "answer_warm"
		else:
			rep["ctx"] = "answer_cool"
		th.append(rep)
		var wid := int(str(a["by"]).substr(2)) if str(a["by"]).begins_with("w:") else -1
		if kind.begins_with("bite"):
			GameData.rel_add(wid, REL_ANSWER_BITE)
		elif kind == "warm":
			GameData.rel_add(wid, REL_ANSWER_WARM, GameData.REL_SOCIAL_CAP)
		elif kind == "friends":
			GameData.rel_add(wid, 4.0, GameData.REL_SOCIAL_CAP)
		note("%s answered you.", [account(str(a["by"]))["name"]], int(p["id"]))
	st()["answers"] = keep


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
			{"kind": "podium", "names": names}, [tag, "Podium"], false, "news_podium")
	var win_id := int(order[0])
	if win_id == 0:
		st()["draft"] = {"opp": str(ev.get("name", "")), "wid": -1, "won": true, "tag": tag, "at": now_t()}
	else:
		var e0: Dictionary = GameData.Career.pilot(ev, win_id)
		if int(e0.get("wid", -1)) >= 0:
			post("w:%d" % int(e0["wid"]), "Champions of the %s. Thank you, Port Ferrum.", [str(ev.get("name", ""))], {}, [tag, "Podium"], false, "pilot_champ")


## A pilot's Read moved a whole dot, or they're rattled / steady again.
static func read_event(p: Dictionary, kind: String) -> void:
	if GameData.world.is_empty():
		return
	var key := "w:%d" % int(p["wid"])
	var big: bool = str(p.get("tier", "")) in ["iron", "steel"] or follows(key)
	match kind:
		"up":
			if big or randf() < 0.3:
				post(key, ["Sparring paid off. I'm reading fights better than ever.", "Something clicked this month. Watch me.",
						"Better every week. Ask my last opponent."][int(p["wid"]) % 3], [], {"kind": "rank", "wid": int(p["wid"])}, ["OnTheRise"], false, "pilot_readup")
		"down":
			if big:
				post("botmedia", "%s has lost a step.", [p["name"]], {"kind": "rank", "wid": int(p["wid"])}, ["LostAStep"], false, "news_slump")
		"rattled":
			if big or randf() < 0.35:
				post(fan_key(int(p["wid"]) + GameData.week), "%s looks RATTLED. Three bad nights and counting.", [p["name"]], {"kind": "rattled"},
						[str(p["name"]).replace(" ", "") + "Rattled"], false, "fan_rattled")
		"steady":
			if big:
				post(key, "Head's clear again. Next.", [], {}, [])


## Every morning: the announcers call fight night, Kane runs adverts, the dealer shouts about stock,
## a fan or two chatters, and now and then a pilot shows off a sponsor.
static func daily() -> void:
	tick()
	dm_daily()
	var rng := RandomNumberGenerator.new()
	rng.seed = GameData.year * 4099 + GameData.week * 31 + GameData.day_index()
	maker_daily(rng)
	var day: String = GameData.day
	if day == "sat":
		var hm: Dictionary = GameData.headline_match()
		if not hm.is_empty():
			var ev: Dictionary = hm["ev"]
			post("mic_grand", "TONIGHT: %s against %s. Be there.", [str(GameData.Career.pilot(ev, int(hm["a"])).get("pilot", "?")),
					str(GameData.Career.pilot(ev, int(hm["b"])).get("pilot", "?"))], {}, ["FightNight", tag_for(str(ev.get("stage", "")))], false, "announcer")
		post("mic_scrap", "Scrap Heap tonight! Bring earplugs and a spare bolt.", [], {}, ["FightNight"], false, "announcer")
	if day == "mon" and GameData.week % 2 == 0:
		post("kane", ["Programs don't ask for a cut. OVERLORD, every Saturday.", "Why trust a tired pilot? Trust Kane Dynamics.",
				"OVERLORD has never missed a punch. Ever.", "The future fights alone. Kane Dynamics."][(GameData.week / 2) % 4], [], {"kind": "ad"}, ["OVERLORD"], false, "kane_ad")
	if day == "sun":
		post("partsrus", "New stock is in. First come, first bolted.", [], {}, ["SundayStock"], false, "shop_ad")
	# a fan reacts to someone at the top
	var tops := World.active("steel") + World.active("iron")
	if not tops.is_empty() and rng.randf() < 0.7:
		var p: Dictionary = tops[rng.randi() % tops.size()]
		post(fan_key(rng.randi()), ["Is %s overrated? Asking for a friend.", "%s is the best pilot in this city and it's not close.",
				"Saw %s at the docks. Shorter than I thought.", "Someone tell %s to stop spending and start winning."][rng.randi() % 4],
				[p["name"]], {}, [], false, "fan_top")
	# now and then a pilot shows off a sponsor
	if rng.randf() < 0.25 and not tops.is_empty():
		var p2: Dictionary = tops[rng.randi() % tops.size()]
		var ids: Array = GameData.Contracts.SPONSORS.keys().filter(func(k): return k != "kane" and k != "rustybolt")
		var sp: String = ids[rng.randi() % ids.size()]
		post("w:%d" % int(p2["wid"]), "Proud to fight in %s colours this season.", [GameData.Contracts.SPONSORS[sp]["name"]], {"kind": "logo", "logo": sp}, [str(GameData.Contracts.SPONSORS[sp]["tag"])], false, "pilot_sponsor")


# ---------------------------------------------------------------- the makers on BotMedia (1.95)

## A maker's fan account ("mf:<maker>:<n>").
static func mfan(m: String, rng: RandomNumberGenerator) -> String:
	return "mf:%s:%d" % [m, rng.randi() % 2]


## Fill a template with as many args as it has %s / %d.
static func _fit(line: String, args: Array) -> Array:
	var n := line.count("%s") + line.count("%d")
	return args.slice(0, n)


## Every day: an advert most days (with a part in their colours), a sale on Mondays now and then,
## a maker sniping at its rival, and fans of two makers going at it.
static func maker_daily(rng: RandomNumberGenerator) -> void:
	var M = GameData.Makers
	var s := st()
	if not s.has("sales"):
		s["sales"] = {}
	var aw: int = GameData.abs_week()
	var g: int = GameData.my_grade()
	if GameData.day == "mon" and rng.randf() < 0.3:
		var m: String = M.ORDER[rng.randi() % M.ORDER.size()]
		var pct: int = [10, 15, 20, 25][rng.randi() % 4]
		s["sales"][m] = [aw, pct]
		var pid: String = M.part_at(m, g, rng)
		post("mk:" + m, M.SALE[rng.randi() % M.SALE.size()], [M.label(m).to_upper(), pct, M.label(m)],
				{"kind": "mkad", "maker": m, "id": pid, "sale": pct}, [str(M.info(m)["label"]).replace(" ", "") + "Sale"], false, "maker_ad")
	if rng.randf() < 0.75:
		var m2: String = M.ORDER[(GameData.day_index() + GameData.week * 3 + rng.randi() % 3) % M.ORDER.size()]
		var pid2: String = M.part_at(m2, g, rng)
		if pid2 != "":
			var lines: Array = M.ADS[m2]
			post("mk:" + m2, lines[rng.randi() % lines.size()], [M.ad_name(GameData.part_def(pid2))],
					{"kind": "mkad", "maker": m2, "id": pid2, "sale": GameData.sale_pct(m2)}, [str(M.info(m2)["label"]).replace(" ", "")], false, "maker_ad")
	if rng.randf() < 0.12:
		var m3: String = M.ORDER[rng.randi() % M.ORDER.size()]
		var snipes: Array = M.SNIPES[m3]
		var line: String = snipes[rng.randi() % snipes.size()]
		post("mk:" + m3, line, _fit(line, [M.label(str(M.RIVAL[m3]))]), {}, [], false, "maker_ad")
	if rng.randf() < 0.25:
		var a: String = M.ORDER[rng.randi() % M.ORDER.size()]
		var b: String = str(M.RIVAL[a])
		post(mfan(a, rng), M.FAN_ARGUE[rng.randi() % M.FAN_ARGUE.size()], [M.label(b)], {}, ["MakerWars"], false, "fan_maker")
		post(mfan(b, rng), M.FAN_ANSWER[rng.randi() % M.FAN_ANSWER.size()], [M.label(a)], {}, ["MakerWars"], false, "fan_maker")


## After your fight: your main maker's fans cheer or sulk, the maker shouts you out on a win, a rival
## maker's fan has a dig, and the old maker's fans notice when you switch.
static func maker_after_fight(won: bool, rng: RandomNumberGenerator) -> void:
	var M = GameData.Makers
	var s := st()
	var mm: String = M.main_of(GameData.equipped_ids().values())
	var prev := str(s.get("my_maker", ""))
	if prev != "" and mm != "" and prev != mm:
		post(mfan(prev, rng), M.FAN_SWITCH[rng.randi() % M.FAN_SWITCH.size()], [M.label(mm), GameData.pilot_name], {}, ["MakerWars"], true, "fan_maker")
	s["my_maker"] = mm
	if mm == "":
		return
	var held: bool = not GameData.Contracts.maker_contract(mm).is_empty()
	if won:
		post(mfan(mm, rng), M.FAN_CHEER[rng.randi() % M.FAN_CHEER.size()], [GameData.pilot_name, M.label(mm)], {}, [], true, "fan_me_win")
		if held or rng.randf() < 0.4:
			post("mk:" + mm, M.SHOUT[rng.randi() % M.SHOUT.size()], [M.label(mm), GameData.pilot_name], {"kind": "logo", "logo": "mk:" + mm}, [], true, "maker_ad")
		if rng.randf() < 0.35:
			post(mfan(str(M.RIVAL[mm]), rng), M.FAN_RIVAL_WIN[rng.randi() % M.FAN_RIVAL_WIN.size()], [GameData.pilot_name, M.label(mm)], {}, ["MakerWars"], true, "fan_doubt")
	elif rng.randf() < 0.5:
		post(mfan(mm, rng), M.FAN_SULK[rng.randi() % M.FAN_SULK.size()], [GameData.pilot_name, M.label(mm)], {}, [], true, "fan_me_loss")


# ---------------------------------------------------------------- posting any time (1.68)
# New post: pick a topic from what's going on, then a tone. No daily limit; what you aim at the
# same pilot (or the same topic) counts less each time today (day_factor).

## [tone, line]; %s = the topic's name (an opponent, a part, a place in the table, a pilot, a sponsor).
const COMPOSE := {
	"fight_won": [["humble", "Good fight tonight, %s. Back to the bay."], ["hype", "Another one down. %s never saw it coming."],
			["funny", "My robot is held together with tape and spite. Still won."], ["trash", "%s, go back to the scrapyard."]],
	"fight_lost": [["humble", "%s was better. I'll be back."], ["hype", "One loss. Watch what happens next."],
			["funny", "Lost a fight, kept my dignity. Mostly."], ["trash", "%s got lucky. Everyone saw it."]],
	"next": [["humble", "Big one coming against %s. Respect."], ["hype", "%s, I'm coming for you."],
			["funny", "Gus says I need sleep before fighting %s. Gus is wrong."], ["trash", "%s won't last three minutes."]],
	"part": [["hype", "New %s on the robot. Watch this."], ["funny", "Found a %s. Gus says it's fine. Gus says that a lot."],
			["humble", "Saving up paid off. One %s, bolted on."]],
	"trophy": [["humble", "%s. Couldn't have done it without Gus."], ["hype", "%s. And I'm only getting started."]],
	"table": [["humble", "%s in the table. Long way to go."], ["hype", "%s in the table and climbing."], ["funny", "%s in the table. My mum is very proud."]],
	"pilot": [["friendly", "Shout out to %s. Class act."], ["hype", "%s is the real deal. Watch them."], ["trash", "%s is all talk."]],
	"sponsor": [["shill", "Proud to fight in %s colours."], ["funny", "%s pays for the bolts. I pay for the dents."]],
	"bay": [["humble", "Long night in the bay with Gus. Worth it."], ["funny", "Gus fell asleep on the welder again."], ["hype", "The robot has never looked better."]],
	"fans": [["thanks", "Thank you for every follow. Port Ferrum, this is for you."]],
	# (1.87) moments from the season
	"first_league": [["humble", "First night in the %s. Nervous. Ready."], ["hype", "The %s starts tonight. So do I."],
			["funny", "First %s fight tonight. Gus has ironed his overalls."]],
	"trials": [["humble", "The Open Trials: %s. Every fight counts."], ["hype", "Trials record %s. Not done yet."],
			["funny", "Trials %s. My robot and I are both running on hope."]],
	"promoted": [["humble", "Up to the %s. Thank you, Gus. Thank you, everyone."], ["hype", "%s, here we come. Make room."],
			["funny", "Promoted to the %s. Rent's going up, apparently."]],
	"streak": [["humble", "%s wins in a row. Not getting comfortable."], ["hype", "%s in a row. Who's next?"],
			["funny", "%s wins in a row and the robot still squeaks."]],
	"comeback": [["humble", "Lost last time, won tonight. Back on track against %s."], ["hype", "Down, then up. %s found that out."],
			["funny", "Bounced back against %s. Gus bounced too, mostly off the ceiling."]],
	"rival": [["humble", "Tonight it's %s. No words needed."], ["hype", "%s, tonight we settle it."], ["trash", "%s, enjoy the walk-in. It's the best part of your night."]],
	"new_sponsor": [["shill", "Signed with %s. Proud to wear their colours."], ["thanks", "Big thanks to %s for backing the bay."],
			["funny", "%s are paying for the bolts now. Gus is thrilled."]],
}
const COMPOSE_FOL := {"humble": 0.004, "hype": 0.008, "funny": 0.006, "trash": 0.01, "friendly": 0.003, "shill": 0.003, "thanks": 0.004}
const COMPOSE_REL := {"humble": 3.0, "hype": 4.0, "friendly": 4.0, "trash": -10.0}
const COMPOSE_TAG := {"bay": "BayLife", "part": "NewParts", "trophy": "Podium", "sponsor": "Sponsored", "fans": "ThankYou", "table": "Standings",
		"first_league": "Debut", "trials": "OpenTrials", "promoted": "MovingUp", "streak": "OnFire", "comeback": "Comeback", "rival": "BadBlood", "new_sponsor": "Sponsored"}


## The picture a composed post carries (1.70).
static func compose_pic(topic: String) -> Dictionary:
	match topic:
		"fight_won", "fight_lost":
			return st().get("last_pic", {})
		"part":
			if not GameData.inventory.is_empty():
				var it: Dictionary = GameData.inventory[-1]
				return {"kind": "part", "id": str(it.get("id", "")), "hp": GameData.hp_ratio(it)}
		"trophy":
			if not GameData.trophies.is_empty():
				var t: Dictionary = GameData.trophies[-1]
				return {"kind": "trophy", "t": str(t.get("kind", "scrap")), "medal": int(t.get("medal", 1))}
		"comeback", "streak":
			return st().get("last_pic", {})
		"promoted":
			if not GameData.trophies.is_empty():
				var t2: Dictionary = GameData.trophies[-1]
				return {"kind": "trophy", "t": str(t2.get("kind", "scrap")), "medal": int(t2.get("medal", 1))}
			return {"kind": "shot", "look": GameData.player_look()}
		"bay", "sponsor", "fans", "first_league", "trials", "rival", "new_sponsor":
			return {"kind": "shot", "look": GameData.player_look()}
	return {}


## What you could post about right now: [topic, label, arg, wid].
static func topics() -> Array:
	var out: Array = []
	if not GameData.fight_log.is_empty():
		var f: Dictionary = GameData.fight_log[-1]
		out.append(["fight_won" if f.get("won", false) else "fight_lost", I18n.t("Your last fight"), str(f.get("opp", "?")), int(f.get("wid", -1))])
	if GameData.fight_mode() in ["story", "circuit", "pickup"]:
		var o: Dictionary = GameData.current_opponent(false)
		var wid := int(o.get("wid", -1))
		var nm := str(World.pilot(wid).get("name", o.get("name", "?"))) if wid >= 0 else str(o.get("pilot", o.get("name", "?")))
		out.append(["next", I18n.t("Tonight's fight"), nm, wid])
	if not GameData.inventory.is_empty():
		var it: Dictionary = GameData.inventory[-1]
		out.append(["part", I18n.t("Your newest part"), I18n.t(str(GameData.PARTS.get(str(it.get("id", "")), {}).get("name", "part"))), -1])
	if not GameData.trophies.is_empty():
		out.append(["trophy", I18n.t("Your latest trophy"), I18n.t(str(GameData.trophies[-1].get("name", "Trophy"))), -1])
	var ev: Dictionary = GameData.event
	if not ev.is_empty() and ev.has("table"):
		var order: Array = GameData.Career.standings(ev)
		var place := order.find(0)
		if place >= 0:
			out.append(["table", I18n.t("The league table"), "#%d" % (place + 1), -1])
	if (st()["follows"] as Array).any(func(k): return str(k).begins_with("w:")):
		out.append(["pilot", I18n.t("A pilot you follow"), "", -1])
	var act: Array = GameData.Contracts.st()["active"]
	if not act.is_empty():
		out.append(["sponsor", I18n.t("Your sponsor"), str(GameData.Contracts.sp(str(act[0]["sp"])).get("name", "?")), -1])
	# (1.87) moments: they come first in the list when they're there
	var moments: Array = []
	var mode := GameData.fight_mode()
	if mode == "story" and not ev.is_empty():
		var stg := str(ev.get("stage", ""))
		if stg == "open":
			var rec: Array = GameData.Career.trials_record(ev, 0)
			moments.append(["trials", I18n.t("The Open Trials"), "%d-%d" % [int(rec[0]), int(rec[1])], -1])
		elif stg in ["scrap", "rust", "iron", "steel"] and not GameData.fight_log.any(func(e): return GameData.log_stage(e) == stg):
			moments.append(["first_league", I18n.t("Your first league night"), I18n.t(str(ev.get("name", ""))), -1])
	if mode in ["story", "circuit", "pickup"]:
		var o2: Dictionary = GameData.current_opponent(false)
		var w2 := int(o2.get("wid", -1))
		if w2 >= 0 and GameData.rel_of(w2) <= -40.0:
			moments.append(["rival", I18n.t("Your rival tonight"), str(World.pilot(w2).get("name", "?")), w2])
	var promo: Dictionary = st().get("promo", {})
	if not promo.is_empty() and GameData.abs_week() - int(promo.get("aw", 0)) <= 3:
		moments.append(["promoted", I18n.t("Your promotion"), I18n.t(str(GameData.Career.STAGES.get(str(promo.get("to", "")), {}).get("name", ""))), -1])
	var streak := 0
	for i in range(GameData.fight_log.size() - 1, -1, -1):
		if not GameData.fight_log[i].get("won", false):
			break
		streak += 1
	if streak >= 3:
		moments.append(["streak", I18n.t("Your winning streak"), str(streak), -1])
	var fl: Array = GameData.fight_log
	if fl.size() >= 2 and fl[-1].get("won", false) and not fl[-2].get("won", false):
		moments.append(["comeback", I18n.t("Bouncing back"), str(fl[-1].get("opp", "?")), int(fl[-1].get("wid", -1))])
	for c in act:
		if GameData.abs_week() - int(c.get("signed_aw", -99)) <= 2:
			moments.append(["new_sponsor", I18n.t("Your new sponsor"), str(GameData.Contracts.sp(str(c["sp"])).get("name", "?")), -1])
			break
	out = moments + out
	out.append(["bay", I18n.t("The bay"), "", -1])
	if followers() >= 500:
		out.append(["fans", I18n.t("Your fans"), "", -1])
	return out


## Post it: followers and the relationship move by the tone, shrunk by today's gains.
static func compose(topic: String, tone: String, arg: String, wid: int) -> void:
	var line := ""
	for c in COMPOSE.get(topic, []):
		if c[0] == tone:
			line = c[1]
	if line == "":
		return
	var target := "w:%d" % wid if wid >= 0 else "topic:" + topic
	var k := day_factor(target)
	st()["followers"] = int(followers() * (1.0 + float(COMPOSE_FOL.get(tone, 0.003)) * k)) + (1 if k > 0.0 else 0)
	if wid >= 0:
		var move := float(COMPOSE_REL.get(tone, 0.0))
		rel_social(wid, move, k, GameData.REL_SOCIAL_CAP)
	var tag: String = COMPOSE_TAG.get(topic, "")
	if topic in ["fight_won", "fight_lost", "next"]:
		tag = tag_for(str(GameData.event.get("stage", ""))) if not GameData.event.is_empty() else "FightNight"
	var p := post("me", line, [arg] if line.contains("%s") else [], compose_pic(topic), [tag] if tag != "" else [])
	if wid >= 0:
		p["opp_wid"] = wid
	count_post()
	GameData.Contracts.on_post(tone)


# ---------------------------------------------------------------- DMs as conversations (1.68)
# The inbox (GameData.inbox) grouped by who: Gus, each pilot ("w:<wid>"), each sponsor ("sp:<id>"),
# the story, anyone else by name. You answer with chips (never typed); pilots write back a part of
# the day later. Rivals sometimes DM a threat before your fight with them. Block stops a pilot's
# messages, threats, hate mail and thread replies (st "blocked").

const DM_LINES := {
	"hi": "Hey. Good luck this week.", "fire": "Talk is cheap. See you in the ring.", "laugh": "Ha. Get some sleep.",
	"tag": "Fancy a tag team tonight?", "rematch": "Rematch? Name the night.", "run": "What are you running these days?",
	"sorry": "Look, I'm sorry about before.", "thanks": "Got it, Gus.", "why": "Why?", "support": "Thanks for the support.",
}
const DM_REL := {"hi": 2.0, "fire": -6.0, "laugh": 3.0, "sorry": 12.0, "support": 0.0}
const DM_WARM := ["Hey yourself. Good luck too.", "Thanks. See you at the Bolt.", "Hey. Saw your last fight. Not bad at all.",
		"Hey. Gus still feeding you that awful coffee?", "Good to hear from you. Keep your guard up."]
const DM_COLD := ["What do you want?", "Not now.", "Busy.", "Do I know you?"]
const DM_FIRE := ["Saturday. You and me.", "Keep running your mouth.", "Talk is all you've got.", "My robot's been waiting for yours."]
const DM_LAUGH := ["Whatever.", "Ha. Fine.", "Ha. Alright, you got me.", "Funny. We'll see who's laughing at the bell."]
const DM_TAG_YES := "You're on. Tonight at the Bolt."
const DM_TAG_NO := "Not tonight."
const DM_REMATCH_YES := "Tonight then. Don't be late."
const DM_REMATCH_NO := "Find someone your own size."
const DM_RUN := "Running a %s these days. Why, scared?"
const DM_SORRY_YES := "Fine. Water under the bridge."
const DM_SORRY_NO := "Too late for that."
const GUS_WHY := ["Because I've seen kids lose arms over less.", "Because your dad would have. Trust me.", "Because the bell doesn't wait for anyone."]
const THREATS := ["See you tonight. Bring spare parts.", "I've watched your fights. You drop your left.", "Tonight I take something off that robot. Your pick.",
		"Hope Gus has a spare head lying around.", "Tonight your robot learns some humility.", "I don't lose twice to the same pilot."]
const STORY_WHO := ["NARRATOR", "ECHO", "YOU"]


## Which conversation an inbox entry belongs to.
static func dm_key(e: Dictionary) -> String:
	if e.has("dm"):
		return str(e["dm"])
	var kind := str(e.get("kind", "talk"))
	if kind.begins_with("sponsor:"):
		return "sp:" + kind.substr(8)
	if e.has("wid"):
		return "w:%d" % int(e["wid"])
	var who := str(e["who"])
	if who == "GUS":
		return "gus"
	if kind == "story" or who in STORY_WHO:
		return "story"
	return "who:" + who


static func is_blocked(key: String) -> bool:
	return (st().get("blocked", []) as Array).has(key)


static func set_blocked(key: String, on: bool) -> void:
	var b: Array = st().get("blocked", [])
	st()["blocked"] = b
	if on and not b.has(key):
		b.append(key)
	elif not on:
		b.erase(key)


## Conversations, newest first: [{key, last (entry), n (messages), at (index of the last one)}].
static func conversations() -> Array:
	var by := {}
	var inbox: Array = GameData.inbox
	for i in inbox.size():
		var k := dm_key(inbox[i])
		if is_blocked(k):
			continue
		if not by.has(k):
			by[k] = {"key": k, "n": 0}
		by[k]["n"] = int(by[k]["n"]) + 1
		by[k]["last"] = inbox[i]
		by[k]["at"] = i
	var out: Array = by.values()
	out.sort_custom(func(a, b): return int(a["at"]) > int(b["at"]))
	return out


## One conversation's messages, oldest first (the last n).
static func messages(key: String, n: int = 40) -> Array:
	var out: Array = []
	for e in GameData.inbox:
		if dm_key(e) == key:
			out.append(e)
	return out.slice(maxi(0, out.size() - n))


## What you can answer in a conversation: [id, line, hint].
static func dm_options(key: String) -> Array:
	var out: Array = []
	if key == "gus":
		return [["thanks", DM_LINES["thanks"], ""], ["why", DM_LINES["why"], I18n.t("He'll explain.")]]
	if key.begins_with("sp:"):
		return [["support", DM_LINES["support"], ""]]
	if not key.begins_with("w:"):
		return []
	var wid := int(key.substr(2))
	var rel := GameData.rel_of(wid)
	var msgs := messages(key, 1)
	var hostile := not msgs.is_empty() and str(msgs[0]["who"]) != "YOU" and rel <= -15.0
	if hostile:
		out.append(["fire", DM_LINES["fire"], I18n.t("They won't like it (%d).") % int(DM_REL["fire"])])
		out.append(["laugh", DM_LINES["laugh"], I18n.t("Cools things down (+%d).") % int(DM_REL["laugh"])])
	else:
		out.append(["hi", DM_LINES["hi"], I18n.t("They warm up to you (+%d).") % int(DM_REL["hi"])])
	if GameData.can_pass_day() and GameData.fight_mode() == "open":
		if GameData.can_team_up(wid):
			out.append(["tag", DM_LINES["tag"], I18n.t("Books a tag team pickup tonight if they say yes.")])
		if GameData.h2h.has(str(wid)):
			out.append(["rematch", DM_LINES["rematch"], I18n.t("Books a pickup against them tonight if they say yes.")])
	out.append(["run", DM_LINES["run"], I18n.t("They might tell you a part. Rivals might lie.")])
	if rel <= -15.0 and int(st().get("sorry", {}).get(key, -99)) < World.abs_week() - 4:
		out.append(["sorry", DM_LINES["sorry"], I18n.t("Once a month. Might patch things up (+%d).") % int(DM_REL["sorry"])])
	return out


## Send one. Returns {"book": "tag" / "pickup", "wid": wid} when they agree to a fight, else {}.
static func dm_send(key: String, id: String) -> Dictionary:
	var line: String = DM_LINES.get(id, "")
	if line == "":
		return {}
	GameData.inbox.append({"y": GameData.year, "w": GameData.week, "d": GameData.day, "ph": GameData.phase, "who": "YOU", "text": I18n.t(line), "kind": "dm", "dm": key})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + id) + now_t() * 7
	if key == "gus":
		if id == "why":
			_dm_answer(key, GUS_WHY[rng.randi() % GUS_WHY.size()], [], 0)
		return {}
	if not key.begins_with("w:"):
		return {}
	var wid := int(key.substr(2))
	var rel := GameData.rel_of(wid)
	var k := day_factor(key)
	match id:
		"hi":
			rel_social(wid, DM_REL["hi"], k, GameData.REL_SOCIAL_CAP)
			_dm_answer(key, (DM_WARM if rel > -15.0 else DM_COLD)[rng.randi() % 2], [], 1)
		"fire":
			rel_social(wid, DM_REL["fire"], k)
			_dm_answer(key, DM_FIRE[rng.randi() % 2], [], 1)
		"laugh":
			rel_social(wid, DM_REL["laugh"], k, GameData.REL_SOCIAL_CAP)
			_dm_answer(key, DM_LAUGH[rng.randi() % 2], [], 1)
		"run":
			var bot: Dictionary = World.robot(wid)
			var ids: Array = []
			for slot in bot.get("parts", {}):
				ids.append(str(bot["parts"][slot]))
			if rel <= GameData.REL_RIVAL and rng.randf() < 0.4:
				ids = GameData.PARTS.keys()   # a rival might lie
			var pid: String = str(ids[rng.randi() % ids.size()]) if not ids.is_empty() else ""
			_dm_answer(key, DM_RUN, [I18n.t(str(GameData.PARTS.get(pid, {}).get("name", "something new")))], 1)
		"sorry":
			var so: Dictionary = st().get("sorry", {})
			st()["sorry"] = so
			so[key] = World.abs_week()
			if GameData.nemeses.has(wid):
				_dm_answer(key, DM_SORRY_NO, [], 1)
			else:
				GameData.rel_add(wid, DM_REL["sorry"], GameData.REL_SOCIAL_CAP)
				_dm_answer(key, DM_SORRY_YES, [], 1)
		"tag":
			if GameData.can_team_up(wid) and rng.randf() < 0.5 + rel / 100.0:
				_dm_answer(key, DM_TAG_YES, [], 0)
				return {"book": "tag", "wid": wid}
			_dm_answer(key, DM_TAG_NO, [], 0)
		"rematch":
			if rel <= GameData.REL_RIVAL or rng.randf() < 0.6:
				_dm_answer(key, DM_REMATCH_YES, [], 0)
				return {"book": "pickup", "wid": wid}
			_dm_answer(key, DM_REMATCH_NO, [], 0)
	return {}


## Their answer: now (delay 0) or a part of the day later (delivered by tick()).
static func _dm_answer(key: String, text: String, args: Array, delay: int) -> void:
	if delay <= 0:
		_dm_deliver(key, text, args)
		return
	var q: Array = st().get("dm_answers", [])
	st()["dm_answers"] = q
	q.append({"key": key, "text": text, "args": args, "due": now_t() + delay})


static func _dm_deliver(key: String, text: String, args: Array) -> void:
	if is_blocked(key):
		return
	var t := I18n.t(text)
	if not args.is_empty():
		t = t % args
	if key == "gus":
		GameData.inbox.append({"y": GameData.year, "w": GameData.week, "d": GameData.day, "ph": GameData.phase, "who": "GUS", "text": t, "kind": "dm", "dm": key})
		return
	var wid := int(key.substr(2))
	GameData.inbox.append({"y": GameData.year, "w": GameData.week, "d": GameData.day, "ph": GameData.phase, "who": str(World.pilot(wid).get("name", "?")),
			"text": t, "kind": "dm", "dm": key, "wid": wid, "look": World.look_of(wid)})
	note("%s sent you a message.", [account(key)["name"]])


## Morning: answers that are due, and now and then a rival's threat on the day you fight them.
static func dm_daily() -> void:
	var o: Dictionary = GameData.current_opponent(false) if GameData.fight_mode() in ["story", "circuit", "pickup"] else {}
	var wid := int(o.get("wid", -1))
	if wid >= 0 and GameData.rel_of(wid) <= GameData.REL_RIVAL and not is_blocked("w:%d" % wid):
		var roll := float(absi(hash("%d:%d:%s:threat" % [GameData.year, GameData.week, GameData.day])) % 1000) / 1000.0
		if roll < (0.6 if GameData.nemeses.has(wid) else 0.4):
			_dm_deliver("w:%d" % wid, THREATS[absi(hash(str(wid) + GameData.day)) % THREATS.size()], [])


static func dm_tick() -> void:
	var q: Array = st().get("dm_answers", [])
	if q.is_empty():
		return
	var keep: Array = []
	for a in q:
		if int(a["due"]) > now_t():
			keep.append(a)
		else:
			_dm_deliver(str(a["key"]), str(a["text"]), a.get("args", []))
	st()["dm_answers"] = keep
