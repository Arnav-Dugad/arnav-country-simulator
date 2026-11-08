extends Node
## Achievements: quiet milestones that persist across games (user://achievements.cfg).

signal unlocked(id: String)

const PATH := "user://achievements.cfg"
const ALL := [
	{"id": "first_month", "icon": "calendar", "title": "Day one", "desc": "Lead your nation for a month."},
	{"id": "first_law", "icon": "gavel", "title": "Lawmaker", "desc": "Pass your first law."},
	{"id": "reformer", "icon": "gavel", "title": "Reformer", "desc": "Have five of your own laws in force."},
	{"id": "first_deal", "icon": "handshake", "title": "Open for business", "desc": "Sign a trade deal."},
	{"id": "trader", "icon": "handshake", "title": "Trading nation", "desc": "Have five trade deals at once."},
	{"id": "first_ally", "icon": "shield", "title": "Allies", "desc": "Form an alliance."},
	{"id": "peacemaker", "icon": "globe", "title": "Peacemaker", "desc": "Be on excellent terms (60+) with ten countries."},
	{"id": "generous", "icon": "hand-coins", "title": "Generous", "desc": "Send foreign aid five times."},
	{"id": "re_elected", "icon": "vote", "title": "Four more years", "desc": "Win an election."},
	{"id": "three_terms", "icon": "crown", "title": "Dynasty", "desc": "Win three elections in one game."},
	{"id": "landslide", "icon": "vote", "title": "Landslide", "desc": "Win an election with over 60% of the vote."},
	{"id": "aaa", "icon": "landmark", "title": "Triple A", "desc": "Earn a AAA credit rating (starting below it)."},
	{"id": "tamed", "icon": "flame", "title": "Price tamer", "desc": "Bring inflation below 3% from above 8%."},
	{"id": "full_jobs", "icon": "users", "title": "Full employment", "desc": "Get unemployment below 4% (starting above 5%)."},
	{"id": "boom", "icon": "trending-up", "title": "Economic miracle", "desc": "Reach 7% growth, two points faster than when you started."},
	{"id": "doubled", "icon": "trending-up", "title": "Twice as rich", "desc": "Double your country's GDP."},
	{"id": "happy", "icon": "heart", "title": "Happy nation", "desc": "Raise happiness to 80 (starting below 75)."},
	{"id": "debt_slayer", "icon": "piggy-bank", "title": "Debt slayer", "desc": "Cut debt by 20 points of GDP."},
	{"id": "surplus", "icon": "wallet", "title": "In the black", "desc": "Turn a budget deficit into a surplus."},
	{"id": "decade", "icon": "calendar", "title": "A decade in power", "desc": "Lead for ten years."},
	{"id": "all_views", "icon": "layers", "title": "Cartographer", "desc": "Look at the world in five different map views."},
	{"id": "curious", "icon": "info", "title": "Curious mind", "desc": "Check what's moving a number five times."},
	{"id": "challenger", "icon": "crown", "title": "Challenger", "desc": "Complete a challenge."},
	{"id": "ribbon", "icon": "hammer", "title": "Ribbon cutting", "desc": "Finish your first construction project."},
	{"id": "builder", "icon": "construction", "title": "Master builder", "desc": "Finish five projects in one game."},
	{"id": "mandate", "icon": "landmark", "title": "Renewed mandate", "desc": "Survive a leadership review."},
	{"id": "democrat", "icon": "vote", "title": "Power to the people", "desc": "Bring free elections to your country."},
	{"id": "goal_getter", "icon": "crown", "title": "Goal getter", "desc": "Reach five national goals in one game."},
	{"id": "straight_talker", "icon": "megaphone", "title": "Straight talker", "desc": "Earn press credibility of 85 or more."},
	{"id": "hotline", "icon": "message-circle", "title": "Hotline", "desc": "Call five different world leaders."},
	{"id": "storm", "icon": "shield", "title": "Weathered the storm", "desc": "See a bank run or currency crisis through to the end."},
	{"id": "bloc_member", "icon": "handshake", "title": "Joiner", "desc": "Join a treaty or bloc."},
	{"id": "globetrotter", "icon": "plane-takeoff", "title": "Globetrotter", "desc": "Make state visits to three countries."},
	{"id": "victor", "icon": "swords", "title": "Victor", "desc": "Win a war on your terms."},
	{"id": "peacemaker", "icon": "flag", "title": "Peacemaker", "desc": "End a war on the old borders."},
	{"id": "handover", "icon": "flag", "title": "Peaceful handover", "desc": "Step down when your term limit comes."},
	{"id": "promise_kept", "icon": "leaf", "title": "Promise kept", "desc": "Meet a climate pledge made at a COP."},
]

var _got := {}        # id -> unix time
var _counters := {}
var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		_got = _cfg.get_value("a", "got", {})
		_counters = _cfg.get_value("a", "counters", {})
	Game.month_passed.connect(_check_month)
	Game.election_held.connect(func(r: Dictionary) -> void:
		if r.won:
			unlock("re_elected")
			if float(r.share) > 60.0:
				unlock("landslide")
			if Game.elections_won >= 3:
				unlock("three_terms"))
	Game.project_finished.connect(func(_id: String) -> void:
		unlock("ribbon")
		var c := Game.me()
		var own := c.projects.values().filter(func(p: Dictionary) -> bool:
			return str(p.state) == "done" and not bool(p.get("start", false))).size()
		if own >= 5:
			unlock("builder"))
	Game.review_held.connect(func(_r: Dictionary) -> void: unlock("mandate"))
	Game.goal_reached.connect(func(_g: Dictionary) -> void:
		if Goals.done_count() >= 5:
			unlock("goal_getter"))
	Game.treaty_joined.connect(func(_id: String) -> void: unlock("bloc_member"))
	Game.event_resolved.connect(func(ev: Dictionary, _c: int, _b: bool) -> void:
		if str(ev.get("id", "")) in ["bailout_vote", "imf_review"]:
			unlock("storm")
		if str(ev.get("id", "")) == "press" and Press.credibility() >= 85.0:
			unlock("straight_talker"))
	Game.law_finished.connect(func(id: String, repealed: bool) -> void:
		if not repealed and id == "free_elections":
			unlock("democrat")
		if not repealed:
			unlock("first_law")
			var c := Game.me()
			var own := c.laws.keys().filter(func(k: String) -> bool:
				return Laws.is_active(c, k) and not c.laws_start.has(k)).size()
			if own >= 5:
				unlock("reformer"))


func has(id: String) -> bool:
	return _got.has(id)


func count() -> int:
	return _got.size()


func unlock(id: String) -> void:
	# Cheated games don't earn achievements.
	if _got.has(id) or not Game.has_game() or Game.cheats_used:
		return
	_got[id] = int(Time.get_unix_time_from_system())
	_save()
	unlocked.emit(id)


## Counted actions (map views, explainers, aid) -> unlock at a threshold.
func bump(counter: String, value: Variant = 1) -> void:
	match counter:
		"map_view":
			var seen: Array = _counters.get("views", [])
			if not value in seen:
				seen.append(value)
			_counters["views"] = seen
			if seen.size() >= 5:
				unlock("all_views")
		"explainer":
			_counters["explainers"] = int(_counters.get("explainers", 0)) + 1
			if int(_counters.explainers) >= 5:
				unlock("curious")
		"aid":
			_counters["aid"] = int(_counters.get("aid", 0)) + 1
			if int(_counters.aid) >= 5:
				unlock("generous")
	_save()


func info(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


func _check_month() -> void:
	var c := Game.me()
	if c == null:
		return
	var b: Dictionary = c.base
	unlock("first_month")
	if c.trade_deals >= 1:
		unlock("first_deal")
	if c.trade_deals >= 5:
		unlock("trader")
	if c.alliances >= 1:
		unlock("first_ally")
	var s: Dictionary = Game.start_snapshot
	if c.rating() == "AAA" and str(s.get("rating", "AAA")) != "AAA":
		unlock("aaa")
	if float(Game.start_snapshot.get("inflation", b.inflation)) > 8.0 and c.inflation < 3.0:
		unlock("tamed")
	if c.unemployment < 4.0 and float(s.get("unemployment", 0.0)) >= 5.0:
		unlock("full_jobs")
	if c.growth > 7.0 and c.growth >= float(s.get("growth", 99.0)) + 2.0:
		unlock("boom")
	if c.gdp >= float(Game.start_snapshot.get("gdp", c.gdp)) * 2.0:
		unlock("doubled")
	if c.happiness >= 80.0 and float(s.get("happiness", 99.0)) < 75.0:
		unlock("happy")
	if c.debt_pct() <= float(Game.start_snapshot.get("debt_pct", 0.0)) - 20.0:
		unlock("debt_slayer")
	if c.balance > 0.0 and float(s.get("balance", 1.0)) < 0.0:
		unlock("surplus")
	if Game.months_played >= 120:
		unlock("decade")
	var friends := 0
	for i in World.playable:
		if i != Game.player and Game.relations[i] >= 60.0:
			friends += 1
	if friends >= 10:
		unlock("peacemaker")


func _save() -> void:
	_cfg.set_value("a", "got", _got)
	_cfg.set_value("a", "counters", _counters)
	_cfg.save(PATH)
