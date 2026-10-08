extends RefCounted
## Sponsor contracts: made-up companies read your followers, form and league and send offers to
## your DMs; you sign, refuse or haggle. A signed contract shows on the robot (their paint, their
## sticker) and comes with rules. Design: "Robot Fighting · Pilot Skill & BotMedia Study", Contracts.
## State lives in GameData.contracts (saved): {"active": [contract], "offers": [offer], "mood": {sp: float},
##   "next": int, "dealer_buys": int}
## contract: {sp, role ("title" / "partner"), slot (sticker), fee (a month), sign, win, rip, podium,
##   weeks (left), reqs [req], strikes, fought_week (bool)}
## offer = contract + {id, want, patience, ceiling, k (money vs base), asks, played (rival card used),
##   sleeping, expires (abs week), reply (what they said last)}

const World = preload("res://world.gd")
const I18n = preload("res://i18n.gd")

const MAX_PARTNERS := 2
## Monthly fee for a partner sticker at each league (a title deal pays double).
const FEE_BASE := {"open": 90, "scrap": 220, "rust": 700, "iron": 2000, "steel": 6000}   # (1.53: x0.75)
## A first broken rule is usually a friendly reminder; sometimes they fine you straight away.
const FIRST_FINE_CHANCE := 0.25
## Offers (1.53): a Monday offer comes 35% of the time, and only once you've won this many fights.
const OFFER_CHANCE := 0.35
const OFFER_MIN_WINS := 3
const STICKER_SLOTS := ["head", "arm_front", "arm_back", "leg_front", "leg_back"]

## The companies. paint = index in GameData.PAINTS a title deal asks for; asks = the rules they like.
const SPONSORS := {
	"boltcola": {"name": "Bolt Cola", "handle": "BoltCola", "tag": "BoltCola", "line": "drink", "paint": 2, "mult": 1.2, "min_fol": 2000,
			"title": true, "asks": ["posts", "wins"], "fol": 220000, "colors": ["#e8352c", "#ffffff"]},
	"voltaic": {"name": "Voltaic Cells", "handle": "VoltaicCells", "tag": "Voltaic", "line": "power", "paint": 1, "mult": 1.0, "min_fol": 4000,
			"title": true, "asks": ["wins", "no_forfeit"], "fol": 64000, "colors": ["#f2c230", "#141414"]},
	"ferrum": {"name": "Ferrum Freight", "handle": "FerrumFreight", "tag": "FerrumFreight", "line": "shipping", "paint": 4, "mult": 0.9, "min_fol": 1000,
			"title": true, "asks": ["active"], "fol": 31000, "colors": ["#2f6fd6", "#e8eef8"]},
	"rustbuster": {"name": "Rustbuster Oil", "handle": "RustbusterOil", "tag": "Rustbuster", "line": "oil", "paint": 3, "mult": 0.8, "min_fol": 600,
			"title": false, "asks": ["repaired"], "fol": 12000, "colors": ["#2fae6b", "#ffffff"]},
	"gearhead": {"name": "Gearhead Garage", "handle": "GearheadGarage", "tag": "Gearhead", "line": "parts", "paint": 1, "mult": 0.9, "min_fol": 1000,
			"title": false, "asks": ["dealer"], "fol": 18000, "colors": ["#f07a1a", "#ffffff"]},
	"neon": {"name": "Neon Arcade", "handle": "NeonArcade", "tag": "NeonArcade", "line": "controllers", "paint": 6, "mult": 1.1, "min_fol": 6000,
			"title": false, "asks": ["controller", "followers"], "fol": 47000, "colors": ["#ff4fb8", "#1a1a2a"]},
	"nova": {"name": "Nova Noodles", "handle": "NovaNoodles", "tag": "NovaNoodles", "line": "food", "paint": 2, "mult": 0.7, "min_fol": 300,
			"title": false, "asks": ["posts"], "fol": 26000, "colors": ["#8a5cf0", "#ffd84a"]},
	"harbour": {"name": "Harbour Mutual", "handle": "HarbourMutual", "tag": "HarbourMutual", "line": "insurance", "paint": 4, "mult": 1.0, "min_fol": 5000,
			"title": false, "asks": ["no_trash", "no_forfeit"], "fol": 22000, "colors": ["#e05a5a", "#f6efe0"]},
	"rustybolt": {"name": "The Rusty Bolt", "handle": "therustybolt", "tag": "RustyBolt", "line": "pub", "paint": 2, "mult": 0.5, "min_fol": 100,
			"title": false, "asks": ["active"], "fol": 3200, "colors": ["#ff7a33", "#2a0e0e"]},
	"kane": {"name": "Kane Dynamics", "handle": "KaneDynamics", "tag": "KaneDynamics", "line": "all", "paint": 7, "mult": 4.0, "min_fol": 30000,
			"title": true, "asks": ["wins", "exclusive"], "fol": 2400000, "colors": ["#c8102e", "#141414"]},
}


static func st() -> Dictionary:
	var s: Dictionary = GameData.contracts
	for k in ["active", "offers"]:
		if not s.has(k):
			s[k] = []
	if not s.has("mood"):
		s["mood"] = {}
	if not s.has("next"):
		s["next"] = 1
	if not s.has("dealer_buys"):
		s["dealer_buys"] = 0
	return s


static func sp(id: String) -> Dictionary:
	return SPONSORS.get(id, {})


static func sp_name(c: Dictionary) -> String:
	return str(sp(str(c["sp"])).get("name", "?"))


# ---------------------------------------------------------------- what's on the robot

## The stickers on your robot: {slot: sponsor id}. Titles go on the torso.
static func stickers() -> Dictionary:
	var out := {}
	for c in st()["active"]:
		out[str(c["slot"])] = str(c["sp"])
	return out


## The paint a title contract asks for (-1 = none).
static func paint_required() -> int:
	for c in st()["active"]:
		for r in c["reqs"]:
			if r["kind"] == "paint":
				return int(r["paint"])
	return -1


static func title_held() -> bool:
	return st()["active"].any(func(c): return c["role"] == "title")


static func partners_held() -> int:
	return st()["active"].filter(func(c): return c["role"] == "partner").size()


static func free_slots() -> Array:
	var used := stickers()
	return STICKER_SLOTS.filter(func(s): return not used.has(s))


# ---------------------------------------------------------------- offers

static func fee_base() -> int:
	return int(FEE_BASE.get(str(GameData.rank), 300))


## How much a sponsor wants you: your followers against what they look for, and your form.
static func want_of(id: String) -> float:
	var target := maxf(50.0, float(sp(id)["min_fol"]) * 2.0)
	var w := clampf(float(GameData.Social.followers()) / target, 0.2, 1.4)
	w += clampf(float(GameData.streak) * 0.05, -0.2, 0.2)
	w += float(st()["mood"].get(id, 0.0))
	return clampf(w, 0.1, 1.6)


static func can_offer(id: String) -> bool:
	var s := st()
	var d := sp(id)
	if s["active"].any(func(c): return c["sp"] == id) or s["offers"].any(func(o): return o["sp"] == id):
		return false
	if float(s["mood"].get(id, 0.0)) < -0.6:
		return false   # they're done with you, for now
	if s["active"].any(func(c): return sp(str(c["sp"]))["line"] == d["line"] or c["sp"] == "kane"):
		return false   # exclusivity: one drink sponsor, and Kane wants you to themselves
	if id == "kane" and (GameData.rank_index() < 3 or not s["active"].is_empty()):
		return false
	if id == "rustybolt" and GameData.rank_index() > 1:
		return false
	return GameData.Social.followers() >= int(d["min_fol"])


## A new offer from a sponsor: money from your league and how much they want you, rules from what they like.
static func make_offer(id: String) -> Dictionary:
	var s := st()
	var d := sp(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["next"]) * 7717 + GameData.year * 13 + GameData.week
	var role := "title" if d["title"] and not title_held() else "partner"
	if role == "partner" and partners_held() >= MAX_PARTNERS:
		return {}
	var want := want_of(id)
	var k := clampf(0.75 + 0.35 * want, 0.6, 1.4)
	var fee := int(fee_base() * float(d["mult"]) * (2.0 if role == "title" else 1.0) * k)
	var slots := free_slots()
	var reqs: Array = []
	if role == "title":
		reqs.append({"kind": "paint", "paint": int(d["paint"])})
	for a in d["asks"]:
		reqs.append(make_req(str(a), rng))
	var o := {"id": int(s["next"]), "sp": id, "role": role, "slot": "torso" if role == "title" else (slots[rng.randi() % slots.size()] if not slots.is_empty() else "head"),
			"fee": fee, "sign": int(fee * rng.randf_range(0.5, 1.2)), "win": int(fee * 0.15), "rip": int(fee * 0.05), "podium": fee * 3,
			"weeks": [8, 12, 16, 26][rng.randi() % 4], "reqs": reqs, "strikes": 0, "want": want,
			"patience": rng.randi_range(2, 4), "ceiling": k * (1.15 + 0.35 * want), "k": k, "asks": 0, "played": false,
			"sleeping": false, "expires": World.abs_week() + 1, "reply": ""}
	s["next"] = int(s["next"]) + 1
	return o


static func make_req(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"wins":
			return {"kind": "wins", "n": 3, "m": 5, "won": 0, "played": 0}
		"posts":
			return {"kind": "posts", "n": 1}
		"followers":
			return {"kind": "followers", "n": int(GameData.Social.followers() * 0.9)}
		"dealer":
			return {"kind": "dealer", "n": 2}
		"controller":
			return {"kind": "controller", "id": "arcade"}
		"repaired":
			return {"kind": "repaired", "pct": 70}
	return {"kind": kind}


## Monday: offers that ran out leave; a sponsor that likes you may send a new one.
static func weekly_offers() -> void:
	var s := st()
	var aw := World.abs_week()
	var kept: Array = []
	for o in s["offers"]:
		if int(o["expires"]) >= aw:
			kept.append(o)
	s["offers"] = kept
	if GameData.wins < OFFER_MIN_WINS or s["offers"].size() >= 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = aw * 31 + GameData.Social.followers()
	if rng.randf() > OFFER_CHANCE:
		return
	var pool: Array = SPONSORS.keys().filter(func(k): return can_offer(k))
	if pool.is_empty():
		return
	pool.sort_custom(func(a, b): return want_of(a) * float(sp(a)["mult"]) > want_of(b) * float(sp(b)["mult"]))
	var pick: String = pool[rng.randi() % mini(3, pool.size())]
	var o := make_offer(pick)
	if o.is_empty():
		return
	s["offers"].append(o)
	var d := sp(pick)
	GameData.log_talk(str(d["name"]).to_upper(), I18n.t("We'd like %s to wear our colours. Offer inside: $%d a month.") % [GameData.robot_name, int(o["fee"])], "sponsor:" + pick)
	GameData.Social.note("New offer from %s.", [d["name"]], -1, pick)


## What Gus says about an offer, in one line.
static func gus_line(o: Dictionary) -> String:
	if o["sp"] == "kane":
		return I18n.t("Kane money. Over my dead body, kid. Your call.")
	var per_base := float(o["fee"]) / maxf(1.0, fee_base() * float(sp(o["sp"])["mult"]) * (2.0 if o["role"] == "title" else 1.0))
	var hard: bool = o["reqs"].any(func(r): return r["kind"] in ["wins", "followers", "no_trash"])
	if per_base >= 1.15:
		return I18n.t("That's good money. Sign before they wake up.")
	if per_base <= 0.85:
		return I18n.t("Cheap. They think we're desperate. Push them.")
	if hard:
		return I18n.t("Fair money, but read the rules twice.")
	if o["role"] == "title":
		return I18n.t("Fair money. Shame about the paint.")
	return I18n.t("Fair. A sticker never hurt anybody.")


## How they seem (the hidden numbers, as a hint).
static func mood_text(o: Dictionary) -> String:
	var w := float(o["want"])
	var p := int(o["patience"])
	var a := I18n.t("They really want you.") if w >= 1.0 else (I18n.t("They're interested.") if w >= 0.6 else I18n.t("They're lukewarm."))
	var b := I18n.t("Plenty of patience.") if p >= 3 else (I18n.t("Patience wearing thin.") if p == 2 else I18n.t("One more push and they walk."))
	return a + " " + b


static func find_offer(id: int) -> int:
	var offers: Array = st()["offers"]
	for i in offers.size():
		if int(offers[i]["id"]) == id:
			return i
	return -1


## Ask for more: "fee", "sign", "term" or "drop" (drop a rule). Returns what they say.
static func ask(id: int, what: String) -> String:
	var i := find_offer(id)
	if i < 0:
		return ""
	var o: Dictionary = st()["offers"][i]
	var chance := clampf(0.25 + 0.45 * float(o["want"]) - 0.12 * int(o["asks"]), 0.05, 0.9)
	if what == "drop":
		chance *= 0.8
	o["asks"] = int(o["asks"]) + 1
	var at_ceiling: bool = float(o["k"]) >= float(o["ceiling"]) and (what == "fee" or what == "sign")
	if not at_ceiling and randf() < chance:
		match what:
			"fee", "sign":
				var up := randf_range(1.08, 1.2)
				var k2 := minf(float(o["ceiling"]), float(o["k"]) * up)
				var r := k2 / float(o["k"])
				o["k"] = k2
				if what == "fee":
					o["fee"] = int(o["fee"] * r)
					o["win"] = int(o["fee"] * 0.15)
					o["rip"] = int(o["fee"] * 0.05)
					o["podium"] = int(o["fee"]) * 3
				else:
					o["sign"] = int(o["sign"] * r * 1.1)
				o["reply"] = I18n.t("Alright. We can do that.")
			"term":
				o["weeks"] = maxi(6, int(o["weeks"]) - 4)
				o["reply"] = I18n.t("Shorter it is.")
			"drop":
				var opt: Array = o["reqs"].filter(func(r): return r["kind"] != "paint" and r["kind"] != "exclusive")
				if opt.is_empty():
					o["reply"] = I18n.t("There's nothing left to drop.")
				else:
					o["reqs"].erase(opt[0])
					o["reply"] = I18n.t("Fine. We'll drop that one.")
		return str(o["reply"])
	o["patience"] = int(o["patience"]) - 1
	if int(o["patience"]) <= 0:
		walk(i)
		return I18n.t("That's our final word. Goodbye.")
	o["reply"] = I18n.t("That's as far as we go.") if at_ceiling else I18n.t("No. Take it or leave it.")
	return str(o["reply"])


## Play another offer against this one. Real if you have another offer; a bluff if you don't.
static func mention(id: int) -> String:
	var i := find_offer(id)
	if i < 0:
		return ""
	var o: Dictionary = st()["offers"][i]
	if o["played"]:
		return I18n.t("You already told us that.")
	o["played"] = true
	var real: bool = st()["offers"].size() > 1
	if real or randf() > 0.6 - float(o["want"]) * 0.3:
		var up := randf_range(1.1, 1.2) if real else 1.1
		o["fee"] = int(o["fee"] * up)
		o["k"] = float(o["k"]) * up
		o["ceiling"] = maxf(float(o["ceiling"]), float(o["k"]))
		o["reply"] = I18n.t("We'll match it, and a bit more.")
		return str(o["reply"])
	walk(i)
	return I18n.t("Then sign with them. Good luck.")


static func sleep_on(id: int) -> void:
	var i := find_offer(id)
	if i >= 0:
		st()["offers"][i]["sleeping"] = true
		st()["offers"][i]["expires"] = World.abs_week() + 1


static func refuse(id: int) -> void:
	var i := find_offer(id)
	if i < 0:
		return
	var o: Dictionary = st()["offers"][i]
	st()["mood"][o["sp"]] = float(st()["mood"].get(o["sp"], 0.0)) - 0.1
	st()["offers"].remove_at(i)


static func walk(i: int) -> void:
	var o: Dictionary = st()["offers"][i]
	st()["mood"][o["sp"]] = float(st()["mood"].get(o["sp"], 0.0)) - 0.2
	st()["offers"].remove_at(i)


## Sign it. Returns what happened (or why not).
static func sign(id: int) -> String:
	var s := st()
	var i := find_offer(id)
	if i < 0:
		return ""
	var o: Dictionary = s["offers"][i]
	if o["role"] == "title" and title_held():
		return I18n.t("You already have a title sponsor.")
	if o["role"] == "partner" and partners_held() >= MAX_PARTNERS:
		return I18n.t("No room for another sticker.")
	if o["role"] == "partner" and stickers().has(str(o["slot"])):
		var fs := free_slots()
		if fs.is_empty():
			return I18n.t("No room for another sticker.")
		o["slot"] = fs[0]
	s["offers"].remove_at(i)
	var c := o.duplicate(true)
	for k in ["want", "patience", "ceiling", "k", "asks", "played", "sleeping", "expires", "reply"]:
		c.erase(k)
	c["fought_week"] = false
	s["active"].append(c)
	GameData.book("sponsors", int(c["sign"]))
	for r in c["reqs"]:
		if r["kind"] == "paint":
			GameData.paint = int(r["paint"])   # the crew repaints it for free
		elif r["kind"] == "controller" and not GameData.owned_controllers.has(str(r["id"])):
			GameData.owned_controllers.append(str(r["id"]))   # they send the stick round
			GameData.pilot_look["controller"] = str(r["id"])
	var d := sp(str(c["sp"]))
	GameData.Social.post("sp:" + str(c["sp"]), "Welcome to the family, %s. #%s", ["@" + GameData.Social.account("me")["handle"], d["tag"]], {"kind": "logo", "logo": c["sp"]}, [d["tag"]], true)
	GameData.Social.post("botmedia", "%s signs with %s.", [GameData.pilot_name, d["name"]], {"kind": "logo", "logo": c["sp"]}, [d["tag"]])
	if c["sp"] == "kane":
		var s2: Dictionary = GameData.Social.st()
		s2["followers"] = int(int(s2["followers"]) * 0.8)   # the pilots' fans don't forgive this
		GameData.log_talk("GUS", I18n.t("You signed with Kane. I don't want to talk about it."), "gus")
	return I18n.t("Signed with %s. $%d up front.") % [d["name"], int(c["sign"])]


# ---------------------------------------------------------------- the rules

static func req_text(r: Dictionary) -> String:
	match str(r["kind"]):
		"paint":
			return I18n.t("Paint the robot %s") % I18n.t(str(GameData.PAINTS[int(r["paint"])]["name"]))
		"wins":
			return I18n.t("Win %d of your next %d fights (%d of %d so far)") % [int(r["n"]), int(r["m"]), int(r.get("won", 0)), int(r.get("played", 0))]
		"posts":
			return I18n.t("Post on BotMedia at least once a week")
		"followers":
			return I18n.t("Stay above %s followers") % str(int(r["n"]))
		"dealer":
			return I18n.t("Buy %d parts a month from the dealer") % int(r["n"])
		"controller":
			return I18n.t("Fight with the %s") % I18n.t(str(GameData.PilotArt.CONTROLLER_NAMES.get(str(r["id"]), "Arcade stick")))
		"repaired":
			return I18n.t("The robot at %d%% or better at every bell") % int(r["pct"])
		"no_forfeit":
			return I18n.t("Never throw in the towel")
		"no_trash":
			return I18n.t("No trash talk on BotMedia")
		"active":
			return I18n.t("Fight every week")
		"exclusive":
			return I18n.t("No other sponsors")
	return str(r["kind"])


static func slot_text(slot: String) -> String:
	return I18n.t({"torso": "on the torso", "head": "on the head", "arm_front": "on the left shoulder", "arm_back": "on the right shoulder",
			"leg_front": "on the left hip", "leg_back": "on the right hip"}.get(slot, slot))


## Broke a rule: a warning, then a fine, then the contract is torn up.
static func strike(c: Dictionary, why: String) -> void:
	c["strikes"] = int(c.get("strikes", 0)) + 1
	var d := sp(str(c["sp"]))
	var who := str(d["name"]).to_upper()
	match int(c["strikes"]):
		1:
			if randf() < FIRST_FINE_CHANCE:
				# some sponsors don't do friendly reminders (1.53)
				var fine1 := int(int(c["fee"]) / 4)
				GameData.book("sponsors", -(fine1))
				GameData.log_talk(who, I18n.t("We don't do reminders: %s. That's a $%d fine. Next time it's worse.") % [why, fine1], "sponsor:" + str(c["sp"]))
			else:
				GameData.log_talk(who, I18n.t("A friendly reminder: %s. Don't make us say it twice.") % why, "sponsor:" + str(c["sp"]))
		2:
			var fine := int(int(c["fee"]) / 4)
			GameData.book("sponsors", -(fine))
			GameData.log_talk(who, I18n.t("Second time: %s. That's a $%d fine.") % [why, fine], "sponsor:" + str(c["sp"]))
			GameData.gus_alert(I18n.t("One more and %s walks") % str(d["name"]), I18n.t("%s fined us for the second time: %s. The next broken rule tears the contract up. Check what they want on the Contracts page.") % [str(d["name"]), why], "contracts")
		_:
			st()["active"].erase(c)
			st()["mood"][c["sp"]] = float(st()["mood"].get(c["sp"], 0.0)) - 0.3
			GameData.log_talk(who, I18n.t("We're done. Contract torn up, sticker off."), "sponsor:" + str(c["sp"]))
			GameData.Social.post("botmedia", "%s and %s part ways.", [d["name"], GameData.pilot_name], {"kind": "logo", "logo": c["sp"]}, [d["tag"]])
	GameData.Social.note("%s: %s", [d["name"], why], -1, str(c["sp"]))


## At the bell (before the damage of the fight): paint, controller, repairs.
static func check_bell(hp_ratio: float) -> void:
	for c in st()["active"].duplicate():
		for r in c["reqs"]:
			match str(r["kind"]):
				"paint":
					if GameData.paint != int(r["paint"]):
						strike(c, I18n.t("the robot wasn't in our paint"))
				"controller":
					if str(GameData.pilot_look.get("controller", "")) != str(r["id"]):
						strike(c, I18n.t("you didn't use our controller"))
				"repaired":
					if hp_ratio * 100.0 < float(r["pct"]):
						strike(c, I18n.t("the robot went in a wreck"))


## After your fight: bonuses, win targets, forfeits.
static func after_fight(won: bool, ripped: int, forfeited: bool) -> int:
	var paid := 0
	for c in st()["active"].duplicate():
		c["fought_week"] = true
		if won:
			paid += int(c["win"])
		paid += ripped * int(c["rip"])
		for r in c["reqs"]:
			match str(r["kind"]):
				"wins":
					r["played"] = int(r.get("played", 0)) + 1
					if won:
						r["won"] = int(r.get("won", 0)) + 1
					if int(r["played"]) >= int(r["m"]):
						if int(r["won"]) < int(r["n"]):
							strike(c, I18n.t("not enough wins"))
						r["played"] = 0
						r["won"] = 0
				"no_forfeit":
					if forfeited:
						strike(c, I18n.t("you threw in the towel"))
	# offers you slept on move with the result
	for o in st()["offers"]:
		if o.get("sleeping", false):
			var f := 1.08 if won else 0.92
			o["fee"] = int(o["fee"] * f)
			o["want"] = float(o["want"]) + (0.1 if won else -0.1)
			o["sleeping"] = false
	GameData.book("sponsors", paid)
	return paid


static func podium(medal: int) -> int:
	var paid := 0
	for c in st()["active"]:
		paid += int(c["podium"]) / medal
	GameData.book("sponsors", paid)
	return paid


static func on_post(tone: String) -> void:
	if not tone.begins_with("trash"):
		return
	for c in st()["active"].duplicate():
		for r in c["reqs"]:
			if r["kind"] == "no_trash":
				strike(c, I18n.t("trash talk on BotMedia"))


static func on_buy() -> void:
	st()["dealer_buys"] = int(st()["dealer_buys"]) + 1


## End of the week (Sunday into Monday): posts, followers, fighting every week, the term runs down.
static func week_end() -> void:
	for c in st()["active"].duplicate():
		for r in c["reqs"]:
			match str(r["kind"]):
				"posts":
					if GameData.Social.posts_this_week() < int(r["n"]):
						strike(c, I18n.t("no post this week"))
				"followers":
					if GameData.Social.followers() < int(r["n"]):
						strike(c, I18n.t("your followers dropped"))
				"active":
					if not c.get("fought_week", false):
						strike(c, I18n.t("a week without a fight"))
		c["fought_week"] = false
		if not st()["active"].has(c):
			continue
		c["weeks"] = int(c["weeks"]) - 1
		if int(c["weeks"]) <= 0:
			st()["active"].erase(c)
			st()["mood"][c["sp"]] = float(st()["mood"].get(c["sp"], 0.0)) + (0.15 if int(c.get("strikes", 0)) == 0 else 0.0)
			GameData.log_talk(sp_name(c).to_upper(), I18n.t("Our contract's up. Thanks for the ride. We'll be in touch."), "sponsor:" + str(c["sp"]))


## End of the month: fees paid, the dealer rule checked.
static func month_end() -> int:
	var paid := 0
	for c in st()["active"].duplicate():
		for r in c["reqs"]:
			if r["kind"] == "dealer" and int(st()["dealer_buys"]) < int(r["n"]):
				strike(c, I18n.t("not enough parts bought from the dealer"))
		if st()["active"].has(c):
			paid += int(c["fee"])
	st()["dealer_buys"] = 0
	GameData.book("sponsors", paid)
	return paid


## What a contract pays in a month, roughly (fee only).
static func monthly_total() -> int:
	var t := 0
	for c in st()["active"]:
		t += int(c["fee"])
	return t
