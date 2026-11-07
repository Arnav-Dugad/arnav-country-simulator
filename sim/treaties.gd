class_name Treaties
extends RefCounted
## Treaties and blocs with their real 2025 members. Members at the start are the
## baseline (like laws): joining adds a treaty's effects, leaving takes them away.
## AI countries occasionally join open blocs too (news). Blocs also define the
## camps that react to UN votes and summits (see GROUPS and Events "bloc_relations").

const ALL := [
	{"id": "climate", "title": "Paris climate agreement", "icon": "sun", "kind": "Climate",
		"desc": "Nearly every country's promise to cut emissions.", "open": "all", "months": 3,
		"fx": {"happiness": 0.6, "growth": -0.05}, "join_rel": 3.0, "leave_rel": -6.0,
		"members_except": ["USA", "IRN", "LBY", "YEM"]},
	{"id": "eu", "title": "European Union", "icon": "landmark", "kind": "Single market",
		"desc": "A single market of 27 countries, with shared rules and budgets.", "open": "Europe", "months": 24,
		"min_relation": 30.0, "fx": {"growth": 0.3, "inflation": -0.1, "stability": 0.5}, "join_rel": 6.0, "leave_rel": -10.0,
		"members": ["AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL",
			"ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"]},
	{"id": "nato", "title": "NATO", "icon": "shield", "kind": "Defence alliance",
		"desc": "An attack on one is an attack on all.", "open": "nato", "months": 12, "min_relation": 35.0,
		"fx": {"stability": 1.5}, "join_rel": 5.0, "leave_rel": -8.0, "rivals": ["RUS", "BLR", "CHN", "IRN", "PRK"],
		"members": ["ALB", "BEL", "BGR", "CAN", "HRV", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "ISL",
			"ITA", "LVA", "LTU", "LUX", "MNE", "NLD", "MKD", "NOR", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE",
			"TUR", "GBR", "USA"]},
	{"id": "asean", "title": "ASEAN", "icon": "handshake", "kind": "Regional bloc",
		"desc": "Southeast Asia's free-trade and cooperation club.", "open": "South-Eastern Asia", "months": 12,
		"min_relation": 15.0, "fx": {"growth": 0.2}, "join_rel": 4.0, "leave_rel": -6.0,
		"members": ["BRN", "KHM", "IDN", "LAO", "MYS", "MMR", "PHL", "SGP", "THA", "VNM", "TLS"]},
	{"id": "mercosur", "title": "Mercosur", "icon": "handshake", "kind": "Trade bloc",
		"desc": "South America's common market.", "open": "South America", "months": 18, "min_relation": 15.0,
		"fx": {"growth": 0.15}, "join_rel": 4.0, "leave_rel": -6.0, "members": ["ARG", "BRA", "PRY", "URY", "BOL"]},
	{"id": "afcfta", "title": "African Free Trade Area", "icon": "handshake", "kind": "Trade bloc",
		"desc": "One market for a whole continent.", "open": "Africa", "months": 6, "fx": {"growth": 0.12},
		"join_rel": 3.0, "leave_rel": -4.0, "members_region": "Africa", "members_except": ["ERI", "SDS", "LBR", "SOM", "BEN"]},
	{"id": "usmca", "title": "USMCA", "icon": "handshake", "kind": "Trade deal",
		"desc": "Free trade between the US, Mexico and Canada.", "open": "", "fx": {"growth": 0.2},
		"join_rel": 0.0, "leave_rel": -8.0, "members": ["USA", "MEX", "CAN"]},
	{"id": "gcc", "title": "Gulf Cooperation Council", "icon": "landmark", "kind": "Regional bloc",
		"desc": "The Gulf monarchies' economic and security union.", "open": "", "fx": {"growth": 0.15, "stability": 0.5},
		"join_rel": 0.0, "leave_rel": -8.0, "members": ["SAU", "ARE", "QAT", "KWT", "BHR", "OMN"]},
	{"id": "brics", "title": "BRICS", "icon": "globe", "kind": "Economic club",
		"desc": "Big emerging economies working together.", "open": "brics", "months": 12, "min_relation": 10.0,
		"fx": {"growth": 0.1}, "join_rel": 4.0, "leave_rel": -5.0, "rivals": ["USA"],
		"members": ["BRA", "RUS", "IND", "CHN", "ZAF", "EGY", "ETH", "IRN", "ARE", "IDN"]},
	{"id": "eaeu", "title": "Eurasian Economic Union", "icon": "handshake", "kind": "Trade bloc",
		"desc": "A customs union around Russia.", "open": "eaeu", "months": 12, "min_relation": 20.0,
		"fx": {"growth": 0.1}, "join_rel": 4.0, "leave_rel": -8.0, "members": ["RUS", "BLR", "KAZ", "KGZ", "ARM"]},
	{"id": "csto", "title": "CSTO", "icon": "shield", "kind": "Defence alliance",
		"desc": "A Russia-led defence pact.", "open": "eaeu", "months": 12, "min_relation": 25.0,
		"fx": {"stability": 1.0}, "join_rel": 4.0, "leave_rel": -10.0, "rivals": ["USA", "GBR"],
		"members": ["RUS", "BLR", "KAZ", "KGZ", "TJK", "ARM"]},
]

## Camps for UN votes and summits.
const WEST_EXTRA := ["JPN", "KOR", "AUS", "NZL", "CHE", "ISR"]
const G20 := ["ARG", "AUS", "BRA", "CAN", "CHN", "FRA", "DEU", "IND", "IDN", "ITA", "JPN", "KOR", "MEX", "RUS",
	"SAU", "ZAF", "TUR", "GBR", "USA"]
const FORMER_USSR := ["RUS", "BLR", "KAZ", "KGZ", "TJK", "TKM", "UZB", "ARM", "AZE", "GEO", "MDA", "UKR"]

static var _base_cache := {}


static func by_id(id: String) -> Dictionary:
	for t in ALL:
		if t.id == id:
			return t
	return {}


## Real membership at the start (before anything the player or AI did).
static func base_member(i: int, id: String) -> bool:
	var key := "%s:%d" % [id, i]
	if _base_cache.has(key):
		return _base_cache[key]
	var t := by_id(id)
	var iso := World.iso(i)
	var m := false
	if t.has("members"):
		m = iso in t.members
	elif t.has("members_region"):
		m = World.group_of(i) == str(t.members_region) and not iso in t.get("members_except", [])
	elif t.has("members_except"):
		m = World.is_playable(i) and not iso in t.members_except
	_base_cache[key] = m
	return m


static func _state() -> Dictionary:
	if not Game.dip.has("treaties"):
		Game.dip["treaties"] = {"joined": {}, "left": {}, "pending": {}}
	return Game.dip.treaties


static func is_member(i: int, id: String) -> bool:
	var st := _state()
	var iso := World.iso(i)
	if st.left.has("%s:%s" % [id, iso]):
		return false
	if st.joined.has("%s:%s" % [id, iso]):
		return true
	return base_member(i, id)


static func pending_months(id: String) -> int:
	return int(_state().pending.get(id, 0))


static func members(id: String) -> Array[int]:
	var out: Array[int] = []
	for i in World.playable:
		if is_member(i, id):
			out.append(i)
	return out


static func memberships(i: int) -> Array:
	return ALL.filter(func(t: Dictionary) -> bool: return is_member(i, t.id))


## Why the player can't join ("" = can).
static func join_blocker(id: String) -> String:
	var t := by_id(id)
	var p := Game.player
	if is_member(p, id):
		return "You are a member"
	if pending_months(id) > 0:
		return "Joining in %d months" % pending_months(id)
	var open := str(t.get("open", ""))
	match open:
		"":
			return "Closed to new members"
		"all":
			pass
		"nato":
			if not (World.group_of(p) == "Europe" or World.map.subregions[p] == "Northern America"):
				return "Only for Europe and North America"
			if Government.kind(p) in ["one_party", "monarchy", "military", "theocracy"]:
				return "Members must be democracies"
		"brics":
			if Game.me().gdp < 3e11:
				return "Needs an economy above $300B"
		"eaeu":
			if not World.iso(p) in FORMER_USSR:
				return "Only for former Soviet states"
		_:
			if World.group_of(p) != open and World.map.subregions[p] != open:
				return "Only for %s" % open
	var need := float(t.get("min_relation", 0.0))
	if need > 0.0:
		var avg := average_relation(id)
		if avg < need:
			return "Members' average opinion of you: %d (needs %d)" % [roundi(avg), roundi(need)]
	for r in t.get("rivals", []):
		var ri := World.index_of(str(r))
		if ri == p:
			return "Not open to you"
	return ""


static func average_relation(id: String) -> float:
	var tot := 0.0
	var n := 0
	for i in members(id):
		if i != Game.player:
			tot += Game.relations[i]
			n += 1
	return tot / maxf(n, 1)


static func start_join(id: String) -> void:
	var t := by_id(id)
	_state().pending[id] = maxi(int(t.get("months", 6)), 1)
	Game.add_feed("You applied to join the %s" % str(t.title), str(t.icon), "accent")


static func leave(id: String) -> void:
	var t := by_id(id)
	var st := _state()
	var iso := World.iso(Game.player)
	_relations_to_members(id, float(t.leave_rel))
	st.joined.erase("%s:%s" % [id, iso])
	if base_member(Game.player, id):
		st.left["%s:%s" % [id, iso]] = Game.months_played
	Game.me().shocks.approval = float(Game.me().shocks.approval) - 1.5
	Game.me().laws_ver += 1      # treaty modifiers are cached with laws
	Game.add_feed("You left the %s" % str(t.title), str(t.icon), "orange")


static func _relations_to_members(id: String, delta: float) -> void:
	for i in members(id):
		if i != Game.player:
			Diplomacy.change_relation(i, delta)
	for r in by_id(id).get("rivals", []):
		var ri := World.index_of(str(r))
		if ri >= 0 and ri != Game.player:
			Diplomacy.change_relation(ri, -delta * 0.6)


## Monthly: finish pending accessions; AI countries sometimes join open blocs.
## Returns the ids the player just joined.
static func monthly(rng: RandomNumberGenerator) -> Array:
	var st := _state()
	var done: Array = []
	for id in st.pending.keys():
		st.pending[id] = int(st.pending[id]) - 1
		if int(st.pending[id]) <= 0:
			st.pending.erase(id)
			var iso := World.iso(Game.player)
			st.left.erase("%s:%s" % [id, iso])
			if not base_member(Game.player, id):
				st.joined["%s:%s" % [id, iso]] = Game.months_played
			_relations_to_members(id, float(by_id(id).join_rel))
			Game.me().laws_ver += 1
			done.append(id)
	if Game.month == 6 and rng.randf() < 0.35:
		_ai_joins(rng)
	return done


## AI blocs grow over time: an eligible, friendly country joins an open bloc.
static func _ai_joins(rng: RandomNumberGenerator) -> void:
	var open_ids := ["brics", "asean", "afcfta", "mercosur"]
	var id: String = open_ids[rng.randi() % open_ids.size()]
	var t := by_id(id)
	var cands: Array[int] = []
	for i in World.playable:
		if i == Game.player or is_member(i, id):
			continue
		var c: CountryState = Game.state(i)
		if c == null:
			continue
		match id:
			"brics":
				if c.gdp > 4e11 and not base_member(i, "nato") and not base_member(i, "eu"):
					cands.append(i)
			"asean":
				if World.map.subregions[i] == "South-Eastern Asia":
					cands.append(i)
			"afcfta":
				if World.group_of(i) == "Africa":
					cands.append(i)
			"mercosur":
				if World.map.subregions[i] == "South America":
					cands.append(i)
	if cands.is_empty():
		return
	var j: int = cands[rng.randi() % cands.size()]
	_state().joined["%s:%s" % [id, World.iso(j)]] = Game.months_played
	if WorldNews.is_notable(j) or rng.randf() < 0.3:
		WorldNews.add(j, "%s joins %s" % [World.map.names[j], str(t.title)], str(t.icon), true)


## Target offsets for the player: treaties joined minus treaties left.
static func modifiers(c: CountryState) -> Dictionary:
	var out := {}
	if c.idx != Game.player:
		return out
	for t in ALL:
		var now := 1 if is_member(c.idx, t.id) else 0
		var then := 1 if base_member(c.idx, t.id) else 0
		var d := now - then
		if d == 0:
			continue
		for k in t.fx:
			out[k] = float(out.get(k, 0.0)) + float(t.fx[k]) * d
	return out


## Countries in a camp (for UN votes / summits): "west", "east", "south", "region".
static func camp(name: String) -> Array[int]:
	var out: Array[int] = []
	for i in World.playable:
		if i == Game.player:
			continue
		var iso := World.iso(i)
		var west := is_member(i, "nato") or is_member(i, "eu") or iso in WEST_EXTRA
		var east := is_member(i, "brics") or is_member(i, "csto") or is_member(i, "eaeu")
		match name:
			"west":
				if west:
					out.append(i)
			"east":
				if east and not west:
					out.append(i)
			"south":
				if not west and not east:
					out.append(i)
			"region":
				if World.map.subregions[i] == World.map.subregions[Game.player]:
					out.append(i)
	return out


static func summit_name() -> String:
	var iso := World.iso(Game.player)
	if iso in G20:
		return "G20"
	for t in memberships(Game.player):
		match str(t.id):
			"eu":
				return "European Council"
			"asean":
				return "ASEAN"
			"gcc":
				return "Gulf"
			"mercosur":
				return "Mercosur"
			"afcfta":
				return "African Union"
	return "regional"
