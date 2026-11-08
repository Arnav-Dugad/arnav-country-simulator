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
	{"id": "moonshot", "icon": "flag", "title": "Moonshot", "desc": "Win the new space race to the Moon."},
	{"id": "blue_skies", "icon": "wind", "title": "Blue skies", "desc": "Cut air pollution by 40% in a polluted country."},
	{"id": "full_nets", "icon": "fish", "title": "Full nets", "desc": "Bring overfished seas back to health (85+)."},
	{"id": "cultural_wave", "icon": "music", "title": "Cultural wave", "desc": "Five worldwide hits from your country."},
	{"id": "granary", "icon": "wheat", "title": "Full granary", "desc": "Feed yourself with six months of food in store."},
	{"id": "water_wise", "icon": "droplets", "title": "Water wise", "desc": "Cut your water stress by a full point."},
	{"id": "ploughshares", "icon": "handshake", "title": "Swords to ploughshares", "desc": "Give up your nuclear weapons."},
	{"id": "midnight", "icon": "clock", "title": "Back from the brink", "desc": "Turn the Doomsday Clock back to 150 seconds."},
	{"id": "ivory_tower", "icon": "graduation-cap", "title": "Ivory tower", "desc": "Have a university in the world top 10."},
	{"id": "prize", "icon": "award", "title": "Laureate", "desc": "One of your scientists wins the World Science Prize."},
	{"id": "one_nation", "icon": "map-pin", "title": "One nation", "desc": "Win back a separatist region: every region loyal (70+)."},
	{"id": "wonder", "icon": "landmark", "title": "Wonder of the world", "desc": "Complete a world wonder."},
	{"id": "spacefarer", "icon": "rocket", "title": "Spacefarer", "desc": "Open an outpost in space."},
	{"id": "champions", "icon": "trophy", "title": "Champions", "desc": "Win a World Cup or top a Games medal table."},
	{"id": "empire", "icon": "crown", "title": "Empire builder", "desc": "Annex a whole country."},
	{"id": "victor", "icon": "swords", "title": "Victor", "desc": "Win a war on your terms."},
	{"id": "ceasefire", "icon": "flag", "title": "Olive branch", "desc": "End a war on the old borders, or broker peace between others."},
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
	Game.month_passed.connect(_check_more)
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
	for a2 in MORE:
		if a2.id == id:
			return a2
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


# ---------------------------------------------------------------- the big list ---
## More achievements, checked every month by condition. Each has a category and
## a tier (bronze 10, silver 25, gold 50, platinum 100 points).
const MORE := [
	# Economy
	{"id": "trillion", "cat": "Economy", "tier": 1, "icon": "coins", "title": "Trillion-dollar club", "desc": "Grow a smaller economy past $1 trillion.", "check": "trillion"},
	{"id": "ten_trillion", "cat": "Economy", "tier": 3, "icon": "coins", "title": "Economic giant", "desc": "Reach a $10 trillion economy.", "check": "ten_trillion"},
	{"id": "tripled", "cat": "Economy", "tier": 2, "icon": "trending-up", "title": "Three times richer", "desc": "Triple your country's GDP.", "check": "tripled"},
	{"id": "rich_nation", "cat": "Economy", "tier": 2, "icon": "gem", "title": "Rich nation", "desc": "Reach $50,000 per person, starting below $30,000.", "check": "rich_nation"},
	{"id": "debt_free", "cat": "Economy", "tier": 3, "icon": "piggy-bank", "title": "Debt free", "desc": "Bring debt below 10% of GDP, starting above 40%.", "check": "debt_free"},
	{"id": "bull_run", "cat": "Economy", "tier": 1, "icon": "trending-up", "title": "Bull run", "desc": "Double the stock market.", "check": "bull_run"},
	{"id": "sovereign_giant", "cat": "Economy", "tier": 2, "icon": "piggy-bank", "title": "Sovereign giant", "desc": "Grow your wealth fund to half your GDP.", "check": "fund_half"},
	{"id": "industrial", "cat": "Economy", "tier": 1, "icon": "factory", "title": "Industrial powerhouse", "desc": "Get any industry to 80 competitiveness.", "check": "industrial"},
	{"id": "tourism_magnet", "cat": "Economy", "tier": 1, "icon": "plane-takeoff", "title": "Tourism magnet", "desc": "Double tourism's share of the economy.", "check": "tourism2x"},
	{"id": "black_market_bust", "cat": "Economy", "tier": 1, "icon": "package", "title": "Smugglers' nightmare", "desc": "Shrink the shadow economy by 15 points.", "check": "black_bust"},
	# People
	{"id": "joyful", "cat": "People", "tier": 2, "icon": "heart", "title": "Joyful nation", "desc": "Raise happiness to 90 (starting below 80).", "check": "happy90"},
	{"id": "beloved", "cat": "People", "tier": 2, "icon": "thumbs-up", "title": "Beloved leader", "desc": "Reach 80% approval.", "check": "approval80"},
	{"id": "rock_solid", "cat": "People", "tier": 1, "icon": "shield", "title": "Rock solid", "desc": "Raise stability to 90 (starting below 80).", "check": "stable90"},
	{"id": "fair_society", "cat": "People", "tier": 2, "icon": "scale", "title": "Fair society", "desc": "Cut inequality by 5 Gini points.", "check": "fair"},
	{"id": "long_lives", "cat": "People", "tier": 2, "icon": "heart-pulse", "title": "Long lives", "desc": "Raise life expectancy by 3 years.", "check": "life3"},
	{"id": "safe_streets", "cat": "People", "tier": 1, "icon": "siren", "title": "Safe streets", "desc": "Cut crime by 15 points.", "check": "crime15"},
	{"id": "home_for_all", "cat": "People", "tier": 1, "icon": "house", "title": "A home for everyone", "desc": "Make housing 10% more affordable.", "check": "housing"},
	{"id": "baby_boom", "cat": "People", "tier": 2, "icon": "baby", "title": "Baby boom", "desc": "Raise the birth rate by 0.3 children per woman.", "check": "babies"},
	{"id": "squeaky_clean", "cat": "People", "tier": 2, "icon": "gavel", "title": "Squeaky clean", "desc": "Reach a clean-government score of 85.", "check": "clean85"},
	{"id": "trusted", "cat": "People", "tier": 1, "icon": "newspaper", "title": "Trusted voice", "desc": "Press credibility of 95.", "check": "cred95"},
	# World
	{"id": "superpower", "cat": "World", "tier": 2, "icon": "shield-check", "title": "Superpower", "desc": "Build your military up to 95 (starting below 85).", "check": "mil95"},
	{"id": "conqueror", "cat": "World", "tier": 3, "icon": "crown", "title": "Conqueror", "desc": "Rule three annexed countries at once.", "check": "annex3"},
	{"id": "united", "cat": "World", "tier": 2, "icon": "handshake", "title": "Better together", "desc": "Unite peacefully with a neighbour.", "check": "union"},
	{"id": "overlord", "cat": "World", "tier": 2, "icon": "crown", "title": "Overlord", "desc": "Have two vassals at once.", "check": "vassals2"},
	{"id": "council_seat", "cat": "World", "tier": 1, "icon": "landmark", "title": "At the top table", "desc": "Win a seat on the UN Security Council.", "check": "council"},
	{"id": "world_conscience", "cat": "World", "tier": 2, "icon": "landmark", "title": "World conscience", "desc": "UN standing of 85.", "check": "un85"},
	{"id": "soft_power_10", "cat": "World", "tier": 2, "icon": "sparkles", "title": "Admired", "desc": "Reach the world's top 10 in soft power.", "check": "soft10"},
	{"id": "no_enemies", "cat": "World", "tier": 2, "icon": "globe", "title": "No enemies", "desc": "No country below -20 relations (after five years).", "check": "no_enemies"},
	{"id": "alliance_web", "cat": "World", "tier": 1, "icon": "shield", "title": "Alliance web", "desc": "Five alliances at once.", "check": "allies5"},
	{"id": "spymaster", "cat": "World", "tier": 1, "icon": "eye", "title": "Spymaster", "desc": "Catch three foreign spy rings.", "check": "spies3"},
	# Science
	{"id": "lab_nation", "cat": "Science", "tier": 1, "icon": "flask-conical", "title": "Lab nation", "desc": "Research 10 technologies.", "check": "tech10"},
	{"id": "future", "cat": "Science", "tier": 3, "icon": "atom", "title": "The future is here", "desc": "Research every technology.", "check": "tech_all"},
	{"id": "red_planet", "cat": "Science", "tier": 3, "icon": "rocket", "title": "Red planet", "desc": "Complete a crewed Mars mission.", "check": "mars"},
	{"id": "fusion_age", "cat": "Science", "tier": 2, "icon": "atom", "title": "Star in a jar", "desc": "Switch on a fusion power plant.", "check": "fusion"},
	{"id": "green_grid", "cat": "Science", "tier": 2, "icon": "leaf", "title": "Green grid", "desc": "Get renewables above 60% of your energy.", "check": "renew60"},
	{"id": "net_zero_path", "cat": "Science", "tier": 2, "icon": "leaf", "title": "On the path", "desc": "Halve emissions per person.", "check": "co2_half"},
	# Sport
	{"id": "world_champions", "cat": "Sport", "tier": 3, "icon": "trophy", "title": "World champions", "desc": "Win the football World Cup.", "check": "world_cup"},
	{"id": "medal_haul", "cat": "Sport", "tier": 2, "icon": "medal", "title": "Medal haul", "desc": "Win 100 Games medals over a career in one game.", "check": "medals100"},
	{"id": "golden_games", "cat": "Sport", "tier": 2, "icon": "medal", "title": "Golden Games", "desc": "Win 30 medals at one Summer Games.", "check": "medals30"},
	{"id": "trophy_room", "cat": "Sport", "tier": 3, "icon": "trophy", "title": "Trophy room", "desc": "Five titles in your trophy cabinet.", "check": "titles5"},
	{"id": "hosts", "cat": "Sport", "tier": 2, "icon": "medal", "title": "Perfect hosts", "desc": "Host the Summer Games.", "check": "hosted_games"},
	# Crises
	{"id": "pandemic_hero", "cat": "Crises", "tier": 3, "icon": "syringe", "title": "Pandemic hero", "desc": "Come through a pandemic losing under 0.05% of your people.", "check": "pandemic"},
	{"id": "first_responder", "cat": "Crises", "tier": 2, "icon": "siren", "title": "First responder", "desc": "Lead a disaster relief effort at full strength.", "check": "relief"},
	{"id": "ready", "cat": "Crises", "tier": 2, "icon": "waves", "title": "Ready for anything", "desc": "Build every climate adaptation project.", "check": "adapted"},
	{"id": "never_dark", "cat": "Crises", "tier": 1, "icon": "zap", "title": "Lights stay on", "desc": "Ten years without a blackout.", "check": "no_blackout"},
	{"id": "survivor", "cat": "Crises", "tier": 1, "icon": "shield", "title": "Survivor", "desc": "Keep power through a recession.", "check": "recession"},
	# Builder
	{"id": "heritage5", "cat": "Builder", "tier": 2, "icon": "landmark", "title": "Living museum", "desc": "Five world heritage sites.", "check": "heritage5"},
	{"id": "modern_nation", "cat": "Builder", "tier": 2, "icon": "building-2", "title": "Modern nation", "desc": "80% average coverage across all civilian builds.", "check": "coverage80"},
	{"id": "crowned", "cat": "Builder", "tier": 1, "icon": "crown", "title": "Long live the monarch", "desc": "Celebrate a royal jubilee or coronation.", "check": "royal"},
	# Time
	{"id": "quarter_century", "cat": "Time", "tier": 2, "icon": "calendar", "title": "Quarter century", "desc": "Lead for 25 years.", "check": "years25"},
	{"id": "half_century", "cat": "Time", "tier": 3, "icon": "calendar", "title": "Half a century", "desc": "Lead for 50 years.", "check": "years50"},
	{"id": "centenarian", "cat": "Time", "tier": 4, "icon": "hourglass", "title": "A hundred years", "desc": "Lead for a century.", "check": "years100"},
	{"id": "legendary", "cat": "Time", "tier": 4, "icon": "crown", "title": "Legend", "desc": "Earn an A+ legacy grade.", "check": ""},
]

const TIER_NAMES := ["", "Bronze", "Silver", "Gold", "Platinum"]
const TIER_POINTS := [0, 10, 25, 50, 100]
const RANKS := [[0, "Newcomer"], [100, "Councillor"], [300, "Minister"], [700, "Statesman"], [1300, "World leader"], [2200, "Legend"]]
## Older achievements: category and tier.
const CLASSIC_TIER := {"first_month": 1, "first_law": 1, "first_deal": 1, "first_ally": 1, "re_elected": 1, "curious": 1, "all_views": 1,
	"ribbon": 1, "bloc_member": 1, "decade": 2, "three_terms": 3, "aaa": 3, "doubled": 2, "moonshot": 3, "empire": 3, "champions": 2}


func all_list() -> Array:
	var out: Array = []
	for a in ALL:
		var x: Dictionary = a.duplicate()
		x["cat"] = "Classic"
		x["tier"] = int(CLASSIC_TIER.get(str(a.id), 2))
		out.append(x)
	for a in MORE:
		out.append(a)
	return out


func points() -> int:
	var p := 0
	for a in all_list():
		if _got.has(str(a.id)):
			p += int(TIER_POINTS[int(a.tier)])
	return p


func total() -> int:
	return all_list().size()


## [title, points needed for the next rank (or -1), points at this rank].
func rank() -> Array:
	var p := points()
	var cur: Array = RANKS[0]
	var nxt := -1
	for k in RANKS.size():
		if p >= int(RANKS[k][0]):
			cur = RANKS[k]
			nxt = int(RANKS[k + 1][0]) if k + 1 < RANKS.size() else -1
	return [str(cur[1]), nxt, int(cur[0])]


func _check_more() -> void:
	var c := Game.me()
	if c == null:
		return
	var s: Dictionary = Game.start_snapshot
	var g0 := float(s.get("gdp", c.gdp))
	var b: Dictionary = c.base
	for a in MORE:
		var id := str(a.id)
		if _got.has(id) or str(a.check) == "":
			continue
		var ok := false
		match str(a.check):
			"trillion": ok = c.gdp >= 1e12 and g0 < 1e12
			"ten_trillion": ok = c.gdp >= 1e13 and g0 < 1e13
			"tripled": ok = c.gdp >= g0 * 3.0
			"rich_nation": ok = c.gdp_per_capita() >= 50000.0 and float(b.get("gdp_pc", 0.0)) < 30000.0
			"debt_free": ok = c.debt_pct() < 10.0 and float(s.get("debt_pct", 0.0)) > 40.0
			"bull_run": ok = Game.dip.has("ent") and float(Enterprise.st().index) >= 200.0
			"fund_half": ok = Game.dip.has("ent") and float(Enterprise.fund().value) >= c.gdp * 0.5
			"industrial":
				if Game.dip.has("ind"):
					for k in Industries.st().sec:
						ok = ok or float(Industries.st().sec[k].get("comp", 0.0)) >= 80.0
			"tourism2x": ok = Game.dip.has("tour") and Tourism.share() >= 2.0 * float(Tourism.st().share0)
			"black_bust": ok = Game.dip.has("black") and Smuggling.change() <= -15.0
			"happy90": ok = c.happiness >= 90.0 and float(Game.start_snapshot.get("happiness", 0.0)) < 80.0
			"approval80": ok = c.approval >= 80.0
			"stable90": ok = c.stability >= 90.0 and float(Game.start_snapshot.get("stability", 0.0)) < 80.0
			"fair": ok = Inequality.change(c) <= -5.0
			"life3": ok = Outcomes.life(c) - Outcomes.start_life(c.idx) >= 3.0
			"crime15": ok = Game.dip.has("crime") and Crime.change() <= -15.0
			"housing": ok = Game.dip.has("pop") and Population.afford() >= 110.0
			"babies": ok = Game.dip.has("pop") and Population.fertility() - float(Population.st().tfr0) >= 0.3
			"clean85": ok = Corruption.value(c) >= 85.0 and Corruption.start(c.idx) < 80.0
			"cred95": ok = Press.credibility() >= 95.0
			"mil95": ok = c.military >= 95.0 and float(Game.start_snapshot.get("military", 0.0)) < 85.0
			"annex3": ok = Annexation.my_lands().size() >= 3
			"union":
				for l in Annexation.my_lands():
					ok = ok or bool(l.peaceful)
			"vassals2": ok = Annexation.vassals().size() >= 2
			"council": ok = Game.dip.has("un") and UnitedNations.on_council() and not UnitedNations.permanent()
			"un85": ok = Game.dip.has("un") and UnitedNations.standing() >= 85.0
			"soft10": ok = Game.dip.has("tour") and Tourism.rank() <= 10
			"no_enemies":
				if Game.months_played >= 60:
					ok = true
					for j in World.playable:
						if j != Game.player and Game.relations[j] < -20.0:
							ok = false
							break
			"allies5": ok = c.alliances >= 5
			"spies3": ok = Game.dip.has("intel") and int(Intel.st().caught) >= 3
			"tech10": ok = (Tech.st().done as Array).size() >= 10
			"tech_all": ok = (Tech.st().done as Array).size() >= Tech.ALL.size()
			"mars": ok = Tech.has("mars")
			"fusion": ok = not c.builds.is_empty() and Builds.count(c, "fusion_plant") > 0
			"renew60": ok = Climate.renewables(c) >= 60.0
			"co2_half": ok = Climate.change(c) <= -0.5
			"world_cup", "titles5", "medals100", "medals30", "hosted_games":
				if Game.dip.has("sport"):
					var sp := Sports.st()
					match str(a.check):
						"world_cup":
							for t in sp.cabinet:
								ok = ok or str(t.title) == "World Cup"
						"titles5": ok = (sp.cabinet as Array).size() >= 5
						"medals100":
							var tot := 0
							for h in sp.medals_hist:
								tot += int(h.medals)
							ok = tot >= 100
						"medals30":
							for h in sp.medals_hist:
								ok = ok or (str(h.title) == "Summer Games" and int(h.medals) >= 30)
						"hosted_games": ok = Game.dip.has("tour") and "games" in (Tourism.st().hosted as Array)
			"pandemic":
				if Game.dip.has("pandemic"):
					var pd := Pandemic.st()
					ok = not Pandemic.active() and int(pd.get("count", 0)) > 0 and float(pd.get("deaths", 1e12)) < c.population * 0.0005
			"relief":
				if Game.dip.has("dis"):
					for e in Disasters.st().log:
						ok = ok or float(e.relief) >= 0.85
			"adapted":
				ok = Game.dip.has("dis")
				for k in Disasters.ADAPT:
					ok = ok and Disasters.adapted(str(k))
			"no_blackout": ok = Game.months_played >= 120 and Game.dip.has("energy") and int(Energy.st().last_blackout) < 0
			"recession": ok = c.growth < -1.0 and Game.months_played >= 24 and c.approval >= 50.0
			"heritage5": ok = Game.dip.has("tour") and (Tourism.st().sites as Array).size() >= 5
			"coverage80":
				if not c.builds.is_empty():
					var tot2 := 0.0
					var n := 0
					for g in Builds.GROUPS:
						if g != "Defence":
							tot2 += Builds.group_coverage(c, str(g))
							n += 1
					ok = tot2 / float(maxi(n, 1)) >= 0.8
			"royal": ok = Game.dip.has("hos") and int(HeadOfState.st().get("jubilee", -1)) > 0
			"years25": ok = Game.months_played >= 300
			"years50": ok = Game.months_played >= 600
			"years100": ok = Game.months_played >= 1200
		if ok:
			unlock(id)


func info_any(id: String) -> Dictionary:
	for a in all_list():
		if str(a.id) == id:
			return a
	return {}
