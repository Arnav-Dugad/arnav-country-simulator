class_name Education
extends RefCounted
## Schools & universities.
##   Learning score   how well 15-year-olds read, count and reason (an
##                    international test, 300-600). Starts from real literacy and
##                    income; moves slowly with the education budget and reforms.
##                    A better-schooled workforce grows faster, a generation later.
##   Universities     three flagships with a world rank. Funding, research
##                    budgets and university campuses push them up the table;
##                    top universities bring research, foreign students and prestige.
##   Brain drain      the share of graduates who leave each year. Poorer countries
##                    and weak universities lose more; talent-return grants help.
## Effects count only the change since you took office (the start is in the real data).
## State: Game.dip.edu {score0, score, q0, q, drain0, drain, fund, reforms: {}, prize}.
## Constants in sim/economy.gd (EDU_*).

const E = preload("res://sim/economy.gd")

const FUNDING := ["current", "boost", "world"]
const FUNDING_INFO := {
	"current": {"title": "Current", "cost": 0.0, "q": 0.0},
	"boost": {"title": "Boost", "cost": 0.12, "q": 10.0},
	"world": {"title": "World-class", "cost": 0.35, "q": 22.0},
}

## id -> {title, desc, icon, cost (% GDP a year), capital (one-off), score, drain}
const REFORMS := {
	"teachers": {"title": "Pay teachers more", "desc": "Better teachers stay in the job.", "icon": "graduation-cap",
		"cost": 0.2, "capital": 0.0, "score": 14.0},
	"curriculum": {"title": "Modern curriculum", "desc": "Problem solving, languages and science first.", "icon": "book-open",
		"cost": 0.0, "capital": 15.0, "score": 8.0},
	"digital": {"title": "A laptop for every pupil", "desc": "Digital skills from age ten.", "icon": "laptop",
		"cost": 0.05, "capital": 0.0, "score": 6.0},
	"return": {"title": "Talent return grants", "desc": "Pays graduates abroad to come home and start up.", "icon": "plane-landing",
		"cost": 0.04, "capital": 0.0, "drain": -6.0},
}

const UNIS := ["National University", "Institute of Technology", "Medical School"]

## Researched starting points (see data/SOURCES.md). Learning score: PISA 2022
## mean of maths, reading and science (rounded; China and India estimated).
const PISA := {"SGP": 560, "JPN": 533, "KOR": 523, "TWN": 525, "HKG": 520, "EST": 516, "IRL": 504, "CHE": 498,
	"CAN": 497, "GBR": 494, "FIN": 490, "AUS": 490, "DNK": 489, "USA": 489, "BEL": 488, "NZL": 488, "POL": 487,
	"AUT": 487, "SWE": 484, "NLD": 482, "DEU": 480, "FRA": 476, "ESP": 474, "ITA": 471, "NOR": 470, "PRT": 470,
	"VNM": 469, "CZE": 487, "HUN": 475, "ISR": 460, "TUR": 457, "GRC": 441, "CHL": 431, "ARE": 422, "MEX": 410,
	"COL": 401, "THA": 398, "MYS": 396, "ARG": 393, "BRA": 390, "SAU": 380, "IDN": 369, "MAR": 357, "PHL": 355,
	"CHN": 500, "IND": 355, "RUS": 480, "UKR": 450, "KAZ": 400, "PER": 395, "URY": 410, "QAT": 410, "JOR": 360,
	"EGY": 350, "PAK": 330, "NGA": 320, "ZAF": 360}
## Best university's approximate world rank (major international tables, 2024-25).
const UNI_RANK := {"USA": 1, "GBR": 2, "CHE": 7, "SGP": 8, "CHN": 12, "AUS": 14, "HKG": 17, "CAN": 20, "FRA": 24,
	"DEU": 25, "JPN": 28, "KOR": 30, "NLD": 50, "SWE": 50, "BEL": 60, "MYS": 60, "NZL": 65, "TWN": 70, "ARG": 70,
	"DNK": 80, "BRA": 90, "RUS": 90, "ISR": 100, "MEX": 100, "CHL": 100, "IRL": 100, "FIN": 115, "IND": 118,
	"NOR": 120, "ITA": 130, "AUT": 140, "ESP": 150, "SAU": 150, "ZAF": 150, "KAZ": 150, "ARE": 200, "IDN": 200,
	"THA": 200, "POL": 250, "CZE": 250, "PRT": 250, "TUR": 300, "PAK": 300, "EGY": 350, "VNM": 400, "IRN": 400,
	"GRC": 400, "NGA": 1000}
const RANK_K := 17.0


static func st() -> Dictionary:
	if not Game.dip.has("edu"):
		Game.dip["edu"] = _fresh()
	return Game.dip.edu


static func _fresh() -> Dictionary:
	var c := Game.me()
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	var lit := World.stat(Game.player, "literacy_pct", 60.0 + 40.0 * lvl)
	var score := clampf(335.0 + 175.0 * lvl + 0.9 * (lit - 85.0) + 12.0 * World.stat(Game.player, "voice_wgi", 0.0), 300.0, 560.0)
	var iso := World.iso(Game.player)
	if PISA.has(iso):
		score = float(PISA[iso])
	var size := clampf(log(maxf((c.gdp if c != null else 1e11) / 1e11, 0.05)) / log(10.0), -1.3, 2.4)
	var q := clampf(5.0 + 40.0 * lvl + 8.0 * size, 2.0, 95.0)
	if UNI_RANK.has(iso):
		q = -RANK_K * log(float(UNI_RANK[iso]) / 1000.0)
	var e := {"score0": score, "score": score, "q0": q, "q": q, "fund": "current", "reforms": {}, "prize": -99, "lvl0": lvl}
	e["drain0"] = _drain_target(e, lvl)
	e["drain"] = e.drain0
	return e


static func _drain_target(e: Dictionary, lvl: float) -> float:
	var d := 26.0 - 28.0 * lvl - 0.12 * (float(e.q) - 40.0)
	if (e.reforms as Dictionary).has("return"):
		d += float(REFORMS["return"].drain)
	return clampf(d, 1.0, 40.0)


## Best university's world rank for any country (yours live).
static func rank_of(i: int) -> int:
	if i == Game.player and Game.has_game() and Game.dip.has("edu"):
		return int(ranks()[0])
	var iso := World.iso(i)
	if UNI_RANK.has(iso):
		return int(UNI_RANK[iso])
	var c: CountryState = Game.state(i)
	if c == null:
		return 1500
	var lvl := Economy.income_level(c.gdp_per_capita())
	var size := clampf(log(maxf(c.gdp / 1e11, 0.05)) / log(10.0), -1.3, 2.4)
	var q := clampf(5.0 + 40.0 * lvl + 8.0 * size, 2.0, 95.0)
	return clampi(roundi(1000.0 * exp(-q / RANK_K)), 1, 1500)


## Learning score of any country (yours live; others from PISA or an income estimate).
static func score_of(i: int) -> float:
	if i == Game.player and Game.has_game() and Game.dip.has("edu"):
		return score()
	var iso := World.iso(i)
	if PISA.has(iso):
		return float(PISA[iso])
	var c: CountryState = Game.state(i)
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.4
	return clampf(335.0 + 175.0 * lvl + 0.9 * (World.stat(i, "literacy_pct", 60.0 + 40.0 * lvl) - 85.0), 300.0, 560.0)


static func has_reform(id: String) -> bool:
	return (st().reforms as Dictionary).has(id)


static func score() -> float:
	return float(st().score)


static func quality() -> float:
	return float(st().q)


static func drain() -> float:
	return float(st().drain)


## World rank of each flagship (best first); at_start = when you took office.
static func ranks(at_start: bool = false) -> Array:
	var q := float(st().q0) if at_start else quality()
	var out: Array = []
	for k in UNIS.size():
		out.append(clampi(roundi(1000.0 * exp(-(q - 9.0 * k) / RANK_K)), 1, 1500))
	return out


static func score_text(s: float) -> String:
	if s >= 520.0:
		return "World-leading"
	if s >= 490.0:
		return "Strong"
	if s >= 450.0:
		return "Average"
	if s >= 400.0:
		return "Weak"
	return "Very weak"


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("edu"):
		return 0.0
	var p := float(FUNDING_INFO[str(st().fund)].cost)
	for id in st().reforms:
		p += float(REFORMS[id].cost)
	return p


static func set_fund(f: String) -> void:
	st().fund = f


static func can_reform(id: String) -> bool:
	return not has_reform(id) and Capital.can(float(REFORMS[id].capital))


static func reform(id: String) -> bool:
	if has_reform(id) or not Capital.spend(float(REFORMS[id].capital)):
		return false
	(st().reforms as Dictionary)[id] = Game.months_played
	Game.add_feed("Education reform: %s" % str(REFORMS[id].title).to_lower(), str(REFORMS[id].icon), "accent")
	return true


static func cancel(id: String) -> void:
	(st().reforms as Dictionary).erase(id)


## How much richer the country is than when this system began (income level, 0..1 scale).
static func income_gain() -> float:
	var e := st()
	if not e.has("lvl0"):
		# Older saves: measure from the country's real 2026 income.
		var pc := World.stat(Game.player, "gdp", 1e11) / maxf(World.stat(Game.player, "population", 1e7), 1.0)
		e["lvl0"] = Economy.income_level(pc)
	return maxf(Economy.income_level(Game.me().gdp_per_capita()) - float(e.lvl0), 0.0)


static func score_target() -> float:
	var e := st()
	var t := float(e.score0) + E.EDU_SCORE_PER_SHARE * Game.me().share_delta("education") + E.EDU_INCOME_SCORE * income_gain()
	for id in e.reforms:
		t += float(REFORMS[id].get("score", 0.0))
	return clampf(t, 280.0, 590.0)


static func q_target() -> float:
	var e := st()
	var c := Game.me()
	var t := float(e.q0) + float(FUNDING_INFO[str(e.fund)].q) + E.EDU_Q_PER_RESEARCH * c.share_delta("research") + E.EDU_INCOME_Q * income_gain()
	if not c.builds.is_empty():
		t += 8.0 * Builds.coverage_of(c, "university", float(Builds.count(c, "university")))
	if Projects.is_done(c, "universities"):
		t += 5.0
	t += (score() - float(e.score0)) * 0.08
	return clampf(t, 2.0, 130.0)


## Monthly: slow, generational change; the occasional world science prize.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var e := st()
	var c := Game.me()
	e.score = float(e.score) + (score_target() - float(e.score)) * E.EDU_SCORE_SPEED
	e.q = float(e.q) + (q_target() - float(e.q)) * E.EDU_Q_SPEED
	e.drain = float(e.drain) + (_drain_target(e, Economy.income_level(c.gdp_per_capita())) - float(e.drain)) * 0.05
	if ranks()[0] <= 10:
		Achievements.unlock("ivory_tower")
	if Game.month == 10 and Game.months_played - int(e.prize) >= 24:
		var r := RandomNumberGenerator.new()
		r.seed = hash([Game.rng.seed, Game.months_played, "prize"])
		if r.randf() < clampf((quality() - 45.0) / 180.0, 0.0, 0.3):
			e.prize = Game.months_played
			c.shocks.approval = float(c.shocks.approval) + 1.5
			Achievements.unlock("prize")
			var field: String = ["physics", "medicine", "chemistry", "economics"][r.randi() % 4]
			Game.add_milestone("A World Science Prize in %s" % field, "award", "gold")
			out.append({"text": "A scientist at the %s wins the World Science Prize in %s" % [UNIS[r.randi() % UNIS.size()], field],
				"icon": "award", "good": true, "big": true, "celebrate": true})
	return out


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("edu"):
		return {}
	var e := st()
	var g := clampf((score() - float(e.score0)) / 40.0 * E.EDU_GROWTH_PER_40, -0.4, 0.7)
	g -= clampf((drain() - float(e.drain0)) / 10.0 * 0.15, -0.3, 0.3)
	return {"growth": g, "happiness": clampf((score() - float(e.score0)) / 40.0 * 0.4, -0.5, 0.8)}


## Research points a month from better universities.
static func research() -> float:
	if not Game.dip.has("edu"):
		return 0.0
	return clampf((quality() - float(st().q0)) / 10.0 * E.EDU_RP_PER_10, -1.0, 4.0)


static func prestige() -> float:
	if not Game.dip.has("edu"):
		return 0.0
	return clampf((quality() - float(st().q0)) / 5.0, -3.0, 8.0)
