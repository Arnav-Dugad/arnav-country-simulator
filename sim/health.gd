class_name Health
extends RefCounted
## The health system.
##   Coverage       how many people get the care they need (WHO's universal
##                  health coverage index, 0-100). Rises with the health budget
##                  and a universal health law.
##   Doctors        per 1,000 people. Training more takes six years to show
##                  (medical school); recruiting abroad is quicker but costly.
##   Waiting times  weeks for a routine operation. They grow with an ageing
##                  population and epidemics, and shrink with doctors and budget.
##   Medicine prices  pay market prices, negotiate as one buyer (savings; the
##                  drug firms object), or switch to generics (bigger savings,
##                  less research).
## Effects count only the change since you took office.
## State: Game.dip.hlth {uhc0, uhc, docs0, docs, wait0, wait, old0, train, abroad, drugs, pipe: [[month, add]]}.
## Constants in sim/economy.gd (HLTH_*).

const E = preload("res://sim/economy.gd")

## WHO UHC service coverage index (2021, rounded).
const UHC := {"CAN": 91, "KOR": 89, "GBR": 88, "DEU": 88, "AUS": 87, "NOR": 87, "USA": 86, "CHE": 86, "NLD": 86,
	"SWE": 85, "ESP": 85, "FRA": 84, "ITA": 84, "JPN": 83, "DNK": 85, "FIN": 83, "NZL": 85, "ISR": 84, "SGP": 89,
	"CHN": 81, "TUR": 79, "BRA": 80, "RUS": 79, "ARG": 79, "CHL": 80, "MEX": 75, "THA": 82, "VNM": 68, "IRN": 74,
	"SAU": 74, "ARE": 78, "EGY": 70, "ZAF": 71, "IND": 63, "IDN": 55, "PHL": 55, "BGD": 52, "PAK": 45, "NGA": 38,
	"ETH": 35, "KEN": 53, "COD": 41, "UKR": 76, "POL": 80, "COL": 80}
## Doctors per 1,000 people (WHO / World Bank, latest, rounded).
const DOCS := {"AUT": 5.4, "NOR": 5.0, "DEU": 4.5, "ESP": 4.4, "SWE": 4.3, "ITA": 4.1, "RUS": 3.8, "CHE": 4.4,
	"AUS": 4.0, "FRA": 3.2, "GBR": 3.2, "USA": 2.7, "CAN": 2.5, "JPN": 2.6, "KOR": 2.5, "CHN": 2.4, "BRA": 2.3,
	"MEX": 2.5, "TUR": 2.2, "SAU": 2.7, "IND": 0.7, "IDN": 0.6, "PAK": 1.1, "NGA": 0.4, "ETH": 0.1, "EGY": 0.7,
	"ZAF": 0.8, "ARG": 4.1, "ISR": 3.6, "POL": 3.4}

const TRAIN := ["current", "more", "double"]
const TRAIN_INFO := {
	"current": {"title": "Current", "cost": 0.0, "rate": 0.0},
	"more": {"title": "More places", "cost": 0.03, "rate": 0.025},
	"double": {"title": "Double", "cost": 0.07, "rate": 0.05},
}
const DRUGS := ["market", "negotiate", "generic"]
const DRUGS_INFO := {
	"market": {"title": "Market prices", "save": 0.0, "desc": "Drug firms set the prices."},
	"negotiate": {"title": "Negotiate", "save": 0.08, "desc": "The state bargains as one buyer. Drug firms object."},
	"generic": {"title": "Generics", "save": 0.14, "desc": "Cheap copies wherever patents allow. Less research."},
}


static func st() -> Dictionary:
	if not Game.dip.has("hlth"):
		Game.dip["hlth"] = _fresh()
	return Game.dip.hlth


static func _fresh() -> Dictionary:
	var c := Game.me()
	var iso := World.iso(Game.player)
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	var uhc := float(UHC.get(iso, clampf(32.0 + 56.0 * lvl, 25.0, 90.0)))
	var docs := float(DOCS.get(iso, clampf(0.15 + 3.6 * pow(lvl, 1.3), 0.1, 5.5)))
	var wait := clampf(18.0 - 10.0 * lvl, 6.0, 20.0)
	return {"uhc0": uhc, "uhc": uhc, "docs0": docs, "docs": docs, "wait0": wait, "wait": wait, "lvl0": lvl,
		"old0": Ageing.share(c) if c != null else 10.0, "train": "current", "abroad": false, "drugs": "market", "pipe": []}


static func uhc() -> float:
	return float(st().uhc)


static func docs() -> float:
	return float(st().docs)


static func wait() -> float:
	return float(st().wait)


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("hlth"):
		return 0.0
	var s := st()
	var p := float(TRAIN_INFO[str(s.train)].cost) - float(DRUGS_INFO[str(s.drugs)].save)
	if bool(s.abroad):
		p += E.HLTH_ABROAD_COST
	return p


static func set_train(t: String) -> void:
	st().train = t


static func set_drugs(d: String) -> void:
	st().drugs = d


static func set_abroad(on: bool) -> void:
	st().abroad = on


## Doctors that will graduate from places funded now (arriving in six years).
static func in_training() -> float:
	var n := 0.0
	for p in st().pipe:
		n += float(p[1])
	return n


## How much richer the country is than when this system began.
static func income_gain() -> float:
	var s := st()
	if not s.has("lvl0"):
		var pc := World.stat(Game.player, "gdp", 1e11) / maxf(World.stat(Game.player, "population", 1e7), 1.0)
		s["lvl0"] = Economy.income_level(pc)
	return maxf(Economy.income_level(Game.me().gdp_per_capita()) - float(s.lvl0), 0.0)


static func uhc_target() -> float:
	var s := st()
	var c := Game.me()
	var t := float(s.uhc0) + E.HLTH_UHC_PER_SHARE * c.share_delta("health") + E.HLTH_INCOME_UHC * income_gain()
	if Laws.is_active(c, "universal_health") and not c.laws_start.has("universal_health"):
		t += 10.0
	t += 6.0 * (docs() / maxf(float(s.docs0), 0.05) - 1.0)
	return clampf(t, 10.0, 98.0)


## Weeks of waiting: demand (ageing, epidemics) over capacity (doctors, budget).
static func wait_target() -> float:
	var s := st()
	var c := Game.me()
	var demand := 1.0 + (Ageing.share(c) - float(s.old0)) * 0.01
	if Pandemic.active():
		demand += 0.35
	var capacity := (docs() / maxf(float(s.docs0), 0.05)) * (1.0 + 0.04 * c.share_delta("health"))
	return clampf(float(s.wait0) * demand / maxf(capacity, 0.3), 1.0, 80.0)


static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	# New medical students graduate six years later.
	var rate := float(TRAIN_INFO[str(s.train)].rate)
	if rate > 0.0:
		(s.pipe as Array).append([Game.months_played + 72, float(s.docs0) * rate / 12.0])
	var keep: Array = []
	for p in s.pipe:
		if int(p[0]) <= Game.months_played:
			s.docs = float(s.docs) + float(p[1])
		else:
			keep.append(p)
	s.pipe = keep
	if bool(s.abroad):
		s.docs = float(s.docs) + float(s.docs0) * E.HLTH_ABROAD_RATE / 12.0
	# A richer country trains and pays more doctors, slowly.
	var rich_docs := float(s.docs0) + E.HLTH_INCOME_DOCS * income_gain()
	if float(s.docs) < rich_docs:
		s.docs = float(s.docs) + (rich_docs - float(s.docs)) * 0.01
	# Retirements slowly thin out a larger workforce back towards what the budget can pay for.
	s.docs = float(s.docs) - (float(s.docs) - float(s.docs0)) * 0.002
	s.uhc = float(s.uhc) + (uhc_target() - float(s.uhc)) * 0.03
	s.wait = float(s.wait) + (wait_target() - float(s.wait)) * 0.08


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("hlth"):
		return {}
	var s := st()
	var wr := (wait() - float(s.wait0)) / float(s.wait0)
	return {"happiness": clampf(-wr * 2.0, -3.0, 1.5), "approval": clampf(-wr * 1.5, -3.0, 1.0),
		"life": clampf((uhc() - float(s.uhc0)) / 10.0 * 0.6 + (docs() / float(s.docs0) - 1.0) * 1.5, -2.0, 3.0)}


## Research lost to generics (points a month).
static func research() -> float:
	if not Game.dip.has("hlth"):
		return 0.0
	return -0.6 if str(st().drugs) == "generic" else 0.0
