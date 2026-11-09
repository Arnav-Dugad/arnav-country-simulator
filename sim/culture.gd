class_name Culture
extends RefCounted
## Culture & values: what your society believes, on three axes (-100 .. +100):
##   progress    traditional (-) … progressive (+)
##   openness    inward-looking (-) … open to the world (+)
##   faith       religious (-) … secular (+)
## Starting values come from real data (income, voice & accountability, urban
## share, region). Laws that fit the culture are more popular; laws that clash
## cost extra approval when they pass. Over decades your choices (education,
## openness, the laws you keep) slowly shift the culture itself, and culture
## campaigns can nudge it on purpose.
## State: Game.dip.cult {progress, openness, faith, start: {...}, push: {axis: month}}.
## Constants in sim/economy.gd (CULT_*).

const E = preload("res://sim/economy.gd")

const AXES := {
	"progress": {"neg": "Traditional", "pos": "Progressive", "icon": "sparkles"},
	"openness": {"neg": "Inward-looking", "pos": "Open to the world", "icon": "globe"},
	"faith": {"neg": "Religious", "pos": "Secular", "icon": "landmark"},
}

## Law -> how it sits on each axis (+ = fits a high value).
const LAW_LEAN := {
	"free_university": {"progress": 0.5},
	"parental_leave": {"progress": 0.6},
	"basic_income": {"progress": 0.7},
	"carbon_tax": {"progress": 0.6, "openness": 0.3},
	"coal_phaseout": {"progress": 0.5},
	"ev_subsidy": {"progress": 0.4},
	"skilled_visas": {"openness": 1.0},
	"export_zones": {"openness": 0.6},
	"border_control": {"openness": -1.0, "progress": -0.4},
	"press_freedom": {"progress": 0.4, "openness": 0.3},
	"free_elections": {"progress": 0.4, "openness": 0.3},
	"police_reform": {"progress": 0.5},
	"pension_age": {"progress": 0.2},
	"universal_health": {"progress": 0.3},
	"four_day_week": {"progress": 0.6},
	"rent_control": {"progress": 0.3},
	"plastic_ban": {"progress": 0.4, "openness": 0.1},
}


static func st() -> Dictionary:
	if not Game.dip.has("cult"):
		var c := Game.me()
		var i := Game.player
		var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
		var voice := World.stat(i, "voice_wgi", 0.0)
		var urban := World.stat(i, "urban_pct", 55.0)
		var grp := World.group_of(i)
		var prog := clampf(-40.0 + 60.0 * lvl + 25.0 * voice + 0.2 * (urban - 55.0), -90.0, 90.0)
		var open := clampf(-20.0 + 40.0 * lvl + 15.0 * voice + 0.3 * (World.stat(i, "trade_pct", 60.0) - 60.0), -90.0, 90.0)
		var faith := clampf(-50.0 + 80.0 * lvl + (25.0 if grp == "Europe" else 0.0) - (50.0 if World.map.subregions[i].contains("Western Asia") or World.map.subregions[i].contains("Northern Africa") else 0.0)
			+ 10.0 * voice, -90.0, 90.0)
		var v := {"progress": prog, "openness": open, "faith": faith}
		Game.dip["cult"] = {"progress": prog, "openness": open, "faith": faith, "start": v.duplicate(), "push": {}}
	return Game.dip.cult


static func value(axis: String) -> float:
	return float(st()[axis])


static func label(axis: String) -> String:
	var v := value(axis)
	var a: Dictionary = AXES[axis]
	if absf(v) < 15.0:
		return "Mixed"
	var strength := "Strongly " if absf(v) >= 55.0 else ("Fairly " if absf(v) >= 30.0 else "Slightly ")
	return strength + str(a.pos if v > 0.0 else a.neg).to_lower()


## How well a law fits the culture: + popular, - controversial (approval points).
static func law_fit(id: String) -> float:
	if not Game.has_game() or not Game.dip.has("cult") or not LAW_LEAN.has(id):
		return 0.0
	var f := 0.0
	for axis in LAW_LEAN[id]:
		f += float(LAW_LEAN[id][axis]) * value(str(axis)) / 100.0
	return clampf(f * E.CULT_LAW_FIT, -4.0, 4.0)


## A short phrase for the law card ("" when neutral).
static func fit_text(id: String) -> String:
	var f := law_fit(id)
	if f >= 1.0:
		return "Fits your culture"
	if f <= -1.0:
		return "Clashes with your culture"
	return ""


static func campaign_wait(axis: String) -> int:
	return maxi(0, int((st().push as Dictionary).get(axis, -99)) + 24 - Game.months_played)


## A culture campaign nudges one axis (+1 or -1) over the next years.
static func campaign(axis: String, dir: int) -> bool:
	if campaign_wait(axis) > 0 or not Capital.spend(E.CULT_CAMPAIGN_CAPITAL):
		return false
	var s := st()
	(s.push as Dictionary)[axis] = Game.months_played
	s[axis + "_dir"] = dir
	Game.me().treasury -= Game.me().gdp * E.CULT_CAMPAIGN_COST / 100.0
	Game.add_feed("A national campaign to make the country %s begins" % str(AXES[axis].pos if dir > 0 else AXES[axis].neg).to_lower(), str(AXES[axis].icon), "accent")
	return true


## Monthly: very slow drift from education, openness and the laws in force; campaigns.
static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	var c := Game.me()
	var drift := {"progress": 0.0, "openness": 0.0, "faith": 0.0}
	drift.progress += E.CULT_EDU_DRIFT * clampf(c.share_delta("education") / 10.0, -1.0, 1.0) + E.CULT_WEALTH_DRIFT
	drift.faith += E.CULT_WEALTH_DRIFT
	drift.openness += E.CULT_TRADE_DRIFT * clampf((c.trade_openness - float(c.base.get("trade", c.trade_openness))) * 5.0, -1.0, 1.0)
	for id in LAW_LEAN:
		if Laws.is_active(c, str(id)) and not c.laws_start.has(id):
			for axis in LAW_LEAN[id]:
				drift[axis] = float(drift[axis]) + E.CULT_LAW_DRIFT * float(LAW_LEAN[id][axis])
	for axis in AXES:
		var pm := int((s.push as Dictionary).get(axis, -99))
		if Game.months_played - pm < 24:
			drift[axis] = float(drift[axis]) + E.CULT_CAMPAIGN_DRIFT * float(s.get(str(axis) + "_dir", 1))
		s[axis] = clampf(float(s[axis]) + float(drift[axis]), -100.0, 100.0)
