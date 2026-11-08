class_name Constitution
extends RefCounted
## The constitution: eight articles you can amend. Each option has trade-offs
## (some voters cheer, others worry; faster government vs. checks on power).
## Amending costs political capital. In free democracies an amendment goes to a
## referendum (it can fail); elsewhere it passes by decree, which democracies
## abroad and the opposition at home dislike.
## State: Game.dip.const {article: option}. Constants in sim/economy.gd (CONST_*).

const E = preload("res://sim/economy.gd")

## article -> {title, icon, options: [[id, title, desc, fx]]}. fx keys: approval,
## stability, happiness, clean, law_speed (share faster), coalition (easier),
## youth, relations, disaster (harm cut), term (limit), cred.
const ARTICLES := {
	"terms": {"title": "Term limits", "icon": "calendar", "options": [
		["one", "One term", "A single term, then step aside.", {"approval": 2.0, "term": 1, "relations": 2.0}],
		["two", "Two terms", "The common rule in democracies.", {"term": 2}],
		["none", "No limit", "Lead as long as voters let you.", {"approval": -2.0, "term": 0, "relations": -2.0, "cred": -3.0}]]},
	"voting_age": {"title": "Voting age", "icon": "vote", "options": [
		["21", "21", "Only older voters.", {"youth": -6.0}],
		["18", "18", "The usual voting age.", {}],
		["16", "16", "Young people get a say.", {"youth": 5.0, "approval": 0.5}]]},
	"electoral": {"title": "Electoral system", "icon": "landmark", "options": [
		["fptp", "First past the post", "Winner takes each seat: strong single-party governments.", {"stability": 1.5, "coalition": -1.0}],
		["mixed", "Mixed", "Some seats local, some by party share.", {"coalition": 0.5}],
		["pr", "Proportional", "Seats match votes: fairer, coalitions are common.", {"happiness": 1.0, "coalition": 1.0, "stability": -1.0}]]},
	"upper_house": {"title": "Upper house", "icon": "building-2", "options": [
		["none", "None", "One chamber: laws pass faster.", {"law_speed": 0.2, "stability": -1.0}],
		["elected", "Elected senate", "A second elected chamber checks the first.", {"law_speed": -0.15, "stability": 1.5}],
		["appointed", "Appointed council", "Experts and elders appointed for life.", {"law_speed": -0.05, "approval": -1.0, "clean": -2.0}]]},
	"courts": {"title": "Courts", "icon": "gavel", "options": [
		["independent", "Independent judges", "Courts can overrule the government.", {"clean": 6.0, "relations": 2.0, "law_speed": -0.05}],
		["appointed", "Judges you appoint", "Courts that rarely stand in your way.", {"clean": -8.0, "relations": -4.0, "law_speed": 0.1, "cred": -4.0}]]},
	"federal": {"title": "Structure of the state", "icon": "map", "options": [
		["unitary", "Unitary", "Decisions made in the capital.", {"law_speed": 0.05}],
		["devolved", "Devolved", "Regions run schools, health and transport.", {"happiness": 1.0, "stability": 1.0}],
		["federal", "Federal", "Strong states with their own laws.", {"stability": 2.0, "law_speed": -0.1, "happiness": 0.5}]]},
	"emergency": {"title": "Emergency powers", "icon": "siren", "options": [
		["limited", "Limited", "Emergencies need parliament's approval.", {"cred": 2.0}],
		["broad", "Broad", "Act fast in a crisis, with fewer checks.", {"disaster": 0.12, "relations": -2.0, "happiness": -0.5}]]},
	"rights": {"title": "Bill of rights", "icon": "scroll-text", "options": [
		["basic", "Basic rights", "The essentials.", {}],
		["strong", "Strong rights", "Free speech, privacy and equal treatment, enforceable in court.", {"happiness": 1.5, "stability": 0.5, "relations": 2.0, "law_speed": -0.05}]]},
}


static func st() -> Dictionary:
	if not Game.dip.has("const"):
		Game.dip["const"] = _start()
	return Game.dip.const


## What a country starts with (from its government type).
static func _start() -> Dictionary:
	var i := Game.player
	var free := Government.is_free(i)
	var k := Government.kind(i)
	var lim := Government.term_limit(i)
	return {
		"terms": "two" if lim == 2 else ("one" if lim == 1 else "none"),
		"voting_age": "18",
		"electoral": "pr" if k in ["parliamentary", "monarchy_parl"] and World.group_of(i) == "Europe" else ("mixed" if k == "parliamentary" else "fptp"),
		"upper_house": "elected" if free else "appointed",
		"courts": "independent" if free and World.stat(i, "voice_wgi", 0.0) > -0.3 else "appointed",
		"federal": "federal" if World.iso(i) in ["USA", "DEU", "IND", "BRA", "CAN", "AUS", "MEX", "ARG", "NGA", "RUS", "CHE", "AUT", "BEL", "MYS", "PAK", "ETH", "ARE"] else "unitary",
		"emergency": "limited" if free else "broad",
		"rights": "strong" if free and World.stat(i, "voice_wgi", 0.0) > 0.5 else "basic",
		"_start": {},
	}


static func choice(a: String) -> String:
	return str(st().get(a, ""))


static func option(a: String, o: String) -> Array:
	for opt in ARTICLES[a].options:
		if str(opt[0]) == o:
			return opt
	return []


## Sum of an effect over the articles, counting only changes since the start.
static func fx(key: String) -> float:
	if not Game.has_game() or not Game.dip.has("const"):
		return 0.0
	var s := st()
	var start: Dictionary = s.get("_orig", {})
	var v := 0.0
	for a in ARTICLES:
		var now := option(str(a), choice(str(a)))
		if now.is_empty():
			continue
		v += float((now[3] as Dictionary).get(key, 0.0))
		var was := option(str(a), str(start.get(a, choice(str(a)))))
		if not was.is_empty():
			v -= float((was[3] as Dictionary).get(key, 0.0))
	return v


static func amend_blocked() -> String:
	if not Capital.can(E.CONST_CAPITAL):
		return "Needs %d political capital" % int(E.CONST_CAPITAL)
	if Game.months_played - int(st().get("last_m", -99)) < E.CONST_GAP:
		return "One amendment every %d months: next in %d" % [E.CONST_GAP, int(st().get("last_m", -99)) + E.CONST_GAP - Game.months_played]
	return ""


## Chance a referendum on this change passes (free democracies).
static func yes_chance(a: String, o: String) -> float:
	var c := Game.me()
	var p := 0.35 + (c.approval - 50.0) / 60.0
	var f: Dictionary = option(a, o)[3]
	p += 0.04 * float(f.get("happiness", 0.0)) + 0.03 * float(f.get("approval", 0.0)) - 0.02 * maxf(-float(f.get("relations", 0.0)), 0.0)
	return clampf(p, 0.1, 0.9)


static func amend(a: String, o: String) -> Dictionary:
	var why := amend_blocked()
	if why != "":
		return {"ok": false, "text": why}
	var s := st()
	if not s.has("_orig") or (s._orig as Dictionary).is_empty():
		var orig := {}
		for k in ARTICLES:
			orig[k] = choice(str(k))
		s._orig = orig
	Capital.spend(E.CONST_CAPITAL)
	s.last_m = Game.months_played
	var c := Game.me()
	var title := "%s: %s" % [str(ARTICLES[a].title), str(option(a, o)[1]).to_lower()]
	if Government.is_free(Game.player):
		if Game.rng.randf() > yes_chance(a, o):
			c.shocks.approval = float(c.shocks.approval) - 1.5
			Game.add_feed("Referendum rejects the amendment (%s)" % title.to_lower(), "vote", "orange")
			return {"ok": false, "text": "The people vote no: %s" % title.to_lower()}
		Game.add_milestone("Constitution amended by referendum: %s" % title.to_lower(), "scroll-text", "gold")
	else:
		c.shocks.stability = float(c.shocks.stability) - 1.0
		Diplomacy.democracies_react(-2.0)
		Game.add_milestone("Constitution amended by decree: %s" % title.to_lower(), "scroll-text", "orange")
	s[a] = o
	if a == "terms":
		Game.politics.limit_lifted = o == "none"
	return {"ok": true, "text": "Amendment passed: %s" % title.to_lower()}


## Term limit from the constitution (0 = none), or -1 to leave it to Government.
static func term_limit() -> int:
	if not Game.dip.has("const") or not (st().get("_orig", {}) as Dictionary).has("terms"):
		return -1
	return int(option("terms", choice("terms"))[3].get("term", 0))


static func modifiers() -> Dictionary:
	return {"approval": fx("approval"), "stability": fx("stability"), "happiness": fx("happiness")}
