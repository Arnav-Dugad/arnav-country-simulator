class_name Daily
extends RefCounted
## The daily challenge: one country and one twist per calendar day, the same for
## every player (seeded by the date). You have four years; when they're up the
## game ends and your legacy grade is your score. Best grade per day is kept in
## user://career.cfg.

const YEARS := 4
const TWISTS := [
	{"id": "recession", "title": "Recession", "desc": "The economy is shrinking as you take office.",
		"apply": {"growth": -2.5, "unemployment": 2.0}},
	{"id": "debt", "title": "Debt mountain", "desc": "Debt is 40 points of GDP higher than in reality.",
		"apply": {"debt_pct": 40.0}},
	{"id": "inflation", "title": "Prices out of control", "desc": "Inflation has jumped by 10 points.",
		"apply": {"inflation": 10.0}},
	{"id": "unpopular", "title": "Unpopular start", "desc": "Your government starts at 32% approval.",
		"apply": {"approval_set": 32.0}},
	{"id": "unrest", "title": "Restless streets", "desc": "Stability is 18 points lower.",
		"apply": {"stability": -18.0}},
	{"id": "oil", "title": "Oil shock", "desc": "World oil prices are 60% above normal.",
		"apply": {"oil": 0.47}},
	{"id": "boom", "title": "Boom times", "desc": "Growth is roaring. Can you keep it from overheating?",
		"apply": {"growth": 3.0, "inflation": 3.0}},
]


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


static func seed_for(date: String) -> int:
	return absi(hash("acs-daily-" + date))


## Today's scenario: {date, country, twist}.
static func scenario(date: String = "") -> Dictionary:
	if date == "":
		date = today()
	var s := seed_for(date)
	# Only countries with full real data (no estimates) for a fair challenge.
	var pool: Array[int] = []
	for i in World.playable:
		if (World.stats[i].get("estimated", []) as Array).is_empty() and World.stat(i, "population") > 3e6:
			pool.append(i)
	var country: int = pool[s % pool.size()]
	var twist: Dictionary = TWISTS[(s / 13) % TWISTS.size()]
	return {"date": date, "country": country, "twist": twist}


static func start(date: String = "") -> void:
	var sc := scenario(date)
	Game.new_game(int(sc.country), seed_for(str(sc.date)), "standard")
	Game.daily = str(sc.date)
	var c := Game.me()
	var fx: Dictionary = sc.twist.apply
	if fx.has("growth"):
		c.growth += float(fx.growth)
		c.growth_anchor += float(fx.growth) * 0.5
	if fx.has("unemployment"):
		c.unemployment += float(fx.unemployment)
	if fx.has("inflation"):
		c.inflation += float(fx.inflation)
		c.core_inflation += float(fx.inflation)
	if fx.has("debt_pct"):
		c.debt += c.gdp * float(fx.debt_pct) / 100.0
	if fx.has("approval_set"):
		c.approval = float(fx.approval_set)
	if fx.has("stability"):
		c.stability = maxf(c.stability + float(fx.stability), 5.0)
	if fx.has("oil"):
		Game.markets.oil = float(fx.oil)
	Simulation.update_finances(c)
	c.refresh_explainer()
	Game.add_feed("Daily challenge: %s. You have %d years." % [str(sc.twist.title).to_lower(), YEARS], "calendar", "gold")


static func over() -> bool:
	return Game.daily != "" and Game.months_played >= YEARS * 12


static func best(date: String = "") -> String:
	var c := ConfigFile.new()
	c.load(Career.PATH)
	return str(c.get_value("daily", date if date != "" else today(), ""))


static func record(date: String, grade: String) -> bool:
	var c := ConfigFile.new()
	c.load(Career.PATH)
	var prev := str(c.get_value("daily", date, ""))
	if prev != "" and Career.GRADE_ORDER.find(grade) <= Career.GRADE_ORDER.find(prev):
		return false
	c.set_value("daily", date, grade)
	c.save(Career.PATH)
	return true
