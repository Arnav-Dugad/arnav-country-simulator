class_name Leaders
extends RefCounted
## Fictional people: every AI country is led by an original, made-up leader with
## a name typical of its region, a portrait (AI-generated art of fictional people,
## assets/portraits) and a personality that shapes diplomacy. No real people.
## A new leader takes over whenever WorldNews reports a change at the top.

const PERSONALITIES := {
	"trader": {"label": "Trader", "desc": "Loves a good trade deal", "deal": 0.15},
	"nationalist": {"label": "Nationalist", "desc": "Puts their country first, wary of deals", "deal": -0.12, "alliance": -0.08},
	"hawk": {"label": "Hawk", "desc": "Tough, suspicious of outsiders", "alliance": -0.1, "drift": -0.04},
	"peacemaker": {"label": "Peacemaker", "desc": "Seeks friends everywhere", "alliance": 0.08, "drift": 0.04},
	"reformer": {"label": "Reformer", "desc": "Modernising and open to new partners", "deal": 0.06},
	"pragmatist": {"label": "Pragmatist", "desc": "Weighs every offer on its merits"},
}
const KEYS := ["trader", "nationalist", "hawk", "peacemaker", "reformer", "pragmatist"]
## Portrait groups, nearest alternatives first (for variety without repeats).
const NEAREST := {"Europe": ["Europe", "Americas", "Oceania", "Middle"], "Americas": ["Americas", "Europe", "Oceania", "Africa"],
	"Africa": ["Africa", "Middle", "Americas", "South"], "South": ["South", "Middle", "East", "Africa"],
	"East": ["East", "South", "Oceania", "Middle"], "Middle": ["Middle", "South", "Europe", "Africa"],
	"Oceania": ["Oceania", "East", "Americas", "Europe"]}


## Name group for any country (Cabinet.NAMES keys).
static func group_of(i: int) -> String:
	var sub: String = World.map.subregions[i]
	match World.group_of(i):
		"Europe":
			return "Europe"
		"Americas":
			return "Americas"
		"Africa":
			return "Middle" if sub == "Northern Africa" else "Africa"
		"Oceania":
			return "Oceania"
	if sub == "Southern Asia":
		return "South"
	if sub in ["Western Asia", "Central Asia"]:
		return "Middle"
	return "East"


static func portrait_key(group: String, female: bool) -> String:
	return "%s_%s" % [group.to_lower(), "f" if female else "m"]


static func _term(i: int) -> int:
	return int(Game.dip.get("leader_terms", {}).get(World.iso(i), 0))


## The current leader of an AI country: {name, title, female, personality, portrait}.
static func leader(i: int) -> Dictionary:
	var g := group_of(i)
	var names: Array = Names.pool(i)
	var h := absi(hash("%s#%d" % [World.iso(i), _term(i)]))
	var firsts: Array = names[0]
	var lasts: Array = names[1]
	var fi: int = h % firsts.size()
	var li: int = (h / 7) % lasts.size()
	var female: bool = fi % 2 == 0          # first-name lists alternate female / male
	var p: String = KEYS[(h / 131) % KEYS.size()]
	return {"name": Names.full(i, fi, li), "title": Government.leader_title(i),
		"female": female, "personality": p, "portrait": portrait_key(g, female)}


static func new_leader(i: int) -> Dictionary:
	if not Game.dip.has("leader_terms"):
		Game.dip["leader_terms"] = {}
	Game.dip.leader_terms[World.iso(i)] = _term(i) + 1
	return leader(i)


## Diplomacy bonus from the other side's leader ("deal" / "alliance").
static func bonus(i: int, kind: String) -> float:
	if i == Game.player:
		return 0.0
	return float(PERSONALITIES[leader(i).personality].get(kind, 0.0))


## Monthly relation drift toward/away from you by the AI leader's personality.
static func drift(i: int) -> float:
	return float(PERSONALITIES[leader(i).personality].get("drift", 0.0))


## Portrait for a minister or candidate ({name, female, group}).
static func portrait_for(person: Dictionary) -> String:
	if person.has("female") and person.has("group"):
		return portrait_key(str(person.group), bool(person.female))
	return portrait_for_name(str(person.get("name", "")))


## Portrait from a first name (older saves without gender/group).
static func portrait_for_name(full_name: String) -> String:
	var first := full_name.split(" ")[0]
	for g in Cabinet.NAMES:
		var k: int = Cabinet.NAMES[g][0].find(first)
		if k >= 0:
			return portrait_key(g, k % 2 == 0)
	return ""


## Distinct portraits for your four ministers (nearest region with the same
## gender when two would look alike).
static func cabinet_portraits() -> Dictionary:
	var out := {}
	var used := {}
	for post in Cabinet.POSTS:
		var mn: Dictionary = Game.cabinet.ministers.get(post, {})
		var key := portrait_for(mn)
		if key == "":
			continue
		var parts := key.split("_")
		var g := parts[0].capitalize()
		var sex := parts[1]
		for alt in NEAREST.get(g, [g]):
			var k2 := "%s_%s" % [str(alt).to_lower(), sex]
			if not used.has(k2):
				key = k2
				break
		used[key] = true
		out[post] = key
	return out


## The player's own chosen portrait ("" = initials avatar).
static func player_portrait() -> String:
	return str(Settings.get_value("leader_portrait", ""))


static func all_portraits() -> Array:
	var out: Array = []
	for g in ["Europe", "Americas", "Africa", "South", "East", "Middle", "Oceania"]:
		for f in [true, false]:
			out.append(portrait_key(g, f))
	return out


# --------------------------------------------------------------- calls ------
## Phone another leader. Their personality decides how each tone lands.
const CALL_COOLDOWN := 6
const CALLS := {
	"warm": {"label": "Talk about shared history", "desc": "Friendly small talk and kind words"},
	"firm": {"label": "Press them on a dispute", "desc": "Look strong at home, risk a chill"},
	"ask": {"label": "Ask them to invest", "desc": "Their companies could bring jobs"},
}
## personality -> tone -> [relation change, approval change, growth shock]
const CALL_FX := {
	"trader": {"warm": [3.0, 0.0, 0.0], "firm": [-3.0, 1.0, 0.0], "ask": [1.0, 0.0, 0.35]},
	"nationalist": {"warm": [2.0, 0.0, 0.0], "firm": [-5.0, 1.5, 0.0], "ask": [-2.0, 0.0, 0.1]},
	"hawk": {"warm": [1.0, 0.0, 0.0], "firm": [2.0, 1.0, 0.0], "ask": [-1.0, 0.0, 0.15]},
	"peacemaker": {"warm": [6.0, 0.5, 0.0], "firm": [-4.0, 0.5, 0.0], "ask": [2.0, 0.0, 0.2]},
	"reformer": {"warm": [3.0, 0.0, 0.0], "firm": [-2.0, 1.0, 0.0], "ask": [2.0, 0.0, 0.25]},
	"pragmatist": {"warm": [2.0, 0.0, 0.0], "firm": [-1.0, 1.0, 0.0], "ask": [0.0, 0.0, 0.2]},
}


static func call_wait(i: int) -> int:
	var last := int(Game.dip.get("calls", {}).get(World.iso(i), -100))
	return maxi(0, last + CALL_COOLDOWN - Game.months_played)


## Makes the call; returns {relation, approval, growth, line} for the result card.
static func make_call(i: int, tone: String) -> Dictionary:
	var ld := leader(i)
	var fx: Array = CALL_FX[ld.personality][tone]
	var rel := float(fx[0])
	var appr := float(fx[1])
	var grow := float(fx[2]) * (1.0 if Game.relations[i] >= 10.0 else 0.4)
	Diplomacy.change_relation(i, rel)
	var me := Game.me()
	me.shocks.approval = float(me.shocks.approval) + appr
	me.shocks.growth = float(me.shocks.growth) + grow
	if not Game.dip.has("calls"):
		Game.dip["calls"] = {}
	Game.dip.calls[World.iso(i)] = Game.months_played
	if Game.dip.calls.size() >= 5:
		Achievements.unlock("hotline")
	var first := str(ld.name).split(" ")[0]
	var line := ""
	if rel >= 4.0:
		line = "%s loved the call and promises closer ties." % first
	elif rel > 0.0:
		line = "%s appreciated the call." % first
	elif rel > -3.0:
		line = "%s listened politely, but little changed." % first
	else:
		line = "%s ended the call coldly." % first
	if grow >= 0.2:
		line += " Their companies will look at investing."
	return {"relation": rel, "approval": appr, "growth": grow, "line": line}


# ------------------------------------------------------------- reactions ----
## Foreign leaders comment on your big moves (shown in the Inbox with their
## portrait). Who comments: your partners, neighbours and the big economies;
## what they say depends on their personality and how much they like you.
const REACTIONS := {
	"law_green": [["Bold climate leadership. The world should follow.", "A costly gamble with your economy."],
		["peacemaker", "reformer"], ["nationalist", "trader"]],
	"law_social": [["A government that looks after its people. Admirable.", "Generous, but who will pay for it?"],
		["peacemaker", "reformer"], ["trader", "pragmatist"]],
	"law_market": [["Good for business, good for trade.", "The workers will pay for this."],
		["trader", "reformer"], ["peacemaker", "nationalist"]],
	"law_democracy": [["A historic step for freedom.", "Interference in the natural order of things."],
		["peacemaker", "reformer", "pragmatist"], ["hawk", "nationalist"]],
	"treaty_join": [["Welcome to the family. We'll be good partners.", "Choosing sides has consequences."],
		["trader", "peacemaker", "pragmatist"], ["nationalist", "hawk"]],
	"treaty_leave": [["A sad day. The door stays open.", "Finally, some independence."],
		["peacemaker", "trader"], ["nationalist"]],
	"sanction": [["Firm and necessary.", "Sanctions hurt ordinary people."],
		["hawk", "nationalist"], ["peacemaker", "trader"]],
	"election": [["Congratulations on a clear mandate.", "Let's hope the next term is better."],
		["trader", "peacemaker", "pragmatist", "reformer"], ["hawk"]],
}
const LAW_KIND := {"carbon_tax": "law_green", "coal_phaseout": "law_green", "ev_subsidy": "law_green",
	"universal_health": "law_social", "free_university": "law_social", "basic_income": "law_social",
	"parental_leave": "law_social", "min_wage": "law_social", "wealth_tax": "law_social",
	"privatisation": "law_market", "export_zones": "law_market", "pension_age": "law_market",
	"free_elections": "law_democracy", "press_freedom": "law_democracy", "anti_corruption": "law_democracy"}


static func _commentators(target: int, n: int) -> Array:
	var pool: Array = []
	for i in World.playable:
		if i == Game.player or i == target or Game.state(i) == null:
			continue
		var w := 0.0
		if Diplomacy.has_deal(i) or Diplomacy.has_alliance(i):
			w += 3.0
		if i in World.map.neighbours[Game.player]:
			w += 2.0
		if Game.state(i).gdp > 1e12:
			w += 1.5
		if w > 0.0:
			pool.append([i, w + Game.rng.randf() * 1.5])
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return pool.slice(0, n).map(func(x: Array) -> int: return int(x[0]))


## Post 1–2 reactions to the Inbox for a kind of move (see REACTIONS).
static func react(kind: String, target: int = -1) -> void:
	if not REACTIONS.has(kind) or not Game.has_game():
		return
	var spec: Array = REACTIONS[kind]
	for i in _commentators(target, 1 + int(Game.rng.randf() < 0.5)):
		var ld := leader(i)
		var likes: bool = ld.personality in spec[1]
		var dislikes: bool = ld.personality in spec[2]
		if not likes and not dislikes:
			likes = Game.relations[i] >= 15.0
		if likes and dislikes:
			likes = Game.relations[i] >= 0.0
		var quote: String = spec[0][0] if likes else spec[0][1]
		var delta := 1.5 if likes else -1.5
		Diplomacy.change_relation(i, delta)
		Game.add_feed("%s of %s: \"%s\"" % [str(ld.name), World.map.names[i], quote], "message-circle",
			"green" if likes else "orange")
		Game.feed[0]["face"] = str(ld.portrait)
		Game.feed[0]["country"] = World.iso(i)
