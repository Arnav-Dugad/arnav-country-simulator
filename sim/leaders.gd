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
	var names: Array = Cabinet.NAMES[g]
	var h := absi(hash("%s#%d" % [World.iso(i), _term(i)]))
	var firsts: Array = names[0]
	var lasts: Array = names[1]
	var fi: int = h % firsts.size()
	var li: int = (h / 7) % lasts.size()
	var female: bool = fi % 2 == 0          # first-name lists alternate female / male
	var p: String = KEYS[(h / 131) % KEYS.size()]
	return {"name": "%s %s" % [firsts[fi], lasts[li]], "title": Government.leader_title(i),
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


## Portrait for a person from their first name (cabinet members, saved games).
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
		var key := portrait_for_name(str(mn.get("name", "")))
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
