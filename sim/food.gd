class_name Food
extends RefCounted
## Food security.
##   Self-sufficiency  food grown at home as a share of what the country eats
##                     (cereals, FAO data). Above 100 % you export; far below,
##                     world price spikes hit hard.
##   Grain reserve     months of food in store. A full reserve is released
##                     automatically when world prices spike, softening the blow.
##   Farm support      subsidies raise output over the years and please rural
##                     voters, at a cost and some lost efficiency.
##   Export ban        exporters can stop selling abroad in a spike: cheaper food
##                     at home, angry customers abroad.
## Effects count only the change since you took office (the start is in the
## real data). Water stress and warming slowly cut harvests.
## State: Game.dip.food {ss0, ss, r0, r, support, fill, ban, w0}. Constants in sim/economy.gd (FOOD_SEC_*).

const E = preload("res://sim/economy.gd")

## Cereal self-sufficiency, % (FAO, recent years, rounded).
const SELF := {"ARG": 280, "AUS": 230, "UKR": 290, "KAZ": 200, "CAN": 180, "RUS": 150, "FRA": 180, "USA": 120,
	"BRA": 125, "THA": 140, "VNM": 115, "IND": 105, "PAK": 105, "MMR": 115, "DEU": 110, "POL": 115, "ROU": 160,
	"HUN": 190, "BGR": 230, "CHN": 95, "IDN": 85, "TUR": 95, "ETH": 90, "NGA": 85, "BGD": 90, "MEX": 60, "PHL": 75,
	"GBR": 90, "ITA": 65, "ESP": 60, "EGY": 50, "IRN": 70, "IRQ": 55, "MAR": 50, "DZA": 30, "TUN": 35, "JPN": 28,
	"KOR": 22, "TWN": 25, "SAU": 10, "ARE": 3, "QAT": 2, "KWT": 2, "ISR": 8, "JOR": 5, "LBN": 15, "YEM": 15,
	"LBY": 10, "OMN": 5, "SGP": 0, "NLD": 15, "BEL": 40, "CHE": 50, "NOR": 50, "PRT": 25, "COL": 45, "PER": 50,
	"VEN": 45, "CHL": 55, "KEN": 70, "ZAF": 95, "SDN": 75, "AFG": 70}

const SUPPORT := ["none", "some", "generous"]
const SUPPORT_INFO := {
	"none": {"title": "Market", "cost": 0.0, "ss": 0.0},
	"some": {"title": "Support", "cost": 0.12, "ss": 8.0},
	"generous": {"title": "Generous", "cost": 0.3, "ss": 16.0},
}


static func st() -> Dictionary:
	if not Game.dip.has("food"):
		var iso := World.iso(Game.player)
		var agri := World.stat(Game.player, "agriculture_pct", 8.0)
		var ss := float(SELF.get(iso, clampf(35.0 + 6.0 * agri - (40.0 if Profiles.food_importer(Game.player) else 0.0), 2.0, 200.0)))
		Game.dip["food"] = {"ss0": ss, "ss": ss, "r0": E.FOOD_SEC_RESERVE_START, "r": E.FOOD_SEC_RESERVE_START,
			"support": "none", "fill": false, "ban": false, "w0": Climate.warming()}
	return Game.dip.food


## Food self-sufficiency of any country (yours live).
static func ss_of(i: int) -> float:
	if i == Game.player and Game.has_game() and Game.dip.has("food"):
		return self_sufficiency()
	var iso := World.iso(i)
	if SELF.has(iso):
		return float(SELF[iso])
	return clampf(35.0 + 6.0 * World.stat(i, "agriculture_pct", 8.0) - (40.0 if Profiles.food_importer(i) else 0.0), 2.0, 200.0)


static func self_sufficiency() -> float:
	return float(st().ss)


static func reserve() -> float:
	return float(st().r)


static func spike() -> bool:
	return Game.markets.food_gap() > E.FOOD_SEC_SPIKE


static func label(ss: float) -> String:
	if ss >= 110.0:
		return "Food exporter"
	if ss >= 90.0:
		return "Feeds itself"
	if ss >= 60.0:
		return "Imports some food"
	if ss >= 25.0:
		return "Relies on imports"
	return "Imports nearly all its food"


static func set_support(s: String) -> void:
	st().support = s


static func set_fill(on: bool) -> void:
	st().fill = on


static func can_ban() -> bool:
	return self_sufficiency() >= 100.0


static func set_ban(on: bool) -> void:
	st().ban = on and can_ban()
	if bool(st().ban):
		Game.add_feed("Food exports banned", "wheat", "orange")


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("food"):
		return 0.0
	var s := st()
	var p := float(SUPPORT_INFO[str(s.support)].cost)
	p += maxf(reserve() - float(s.r0), 0.0) * E.FOOD_SEC_RESERVE_COST
	if bool(s.fill) and reserve() < E.FOOD_SEC_RESERVE_MAX:
		p += E.FOOD_SEC_FILL_COST
	return p


static func ss_target() -> float:
	var s := st()
	var t := float(s.ss0) * (1.0 + float(SUPPORT_INFO[str(s.support)].ss) / 100.0)
	if Game.dip.has("water"):
		if bool(Water.st().drip):
			t *= 1.04
		t *= 1.0 - E.FOOD_SEC_WATER * maxf(Water.stress() - float(Water.st().s0), 0.0)
	t *= 1.0 - E.FOOD_SEC_WARMING * maxf(Climate.warming() - float(s.w0), 0.0)
	return clampf(t, 0.0, 400.0)


## Multiplier on how hard world food prices hit you (1 = as at the start).
static func shield() -> float:
	if not Game.has_game() or not Game.dip.has("food"):
		return 1.0
	var s := st()
	var m := 1.0 - (reserve() - float(s.r0)) * 0.08
	m -= clampf((self_sufficiency() - float(s.ss0)) / 100.0, -0.4, 0.4) * 0.8
	if bool(s.ban) and spike():
		m *= 0.6
	return clampf(m, 0.3, 1.4)


static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	s.ss = float(s.ss) + (ss_target() - float(s.ss)) * 0.02
	if spike() and reserve() > 0.0:
		s.r = maxf(reserve() - E.FOOD_SEC_RELEASE, 0.0)        # the reserve is released
	elif bool(s.fill):
		s.r = minf(reserve() + E.FOOD_SEC_FILL_RATE, E.FOOD_SEC_RESERVE_MAX)
	if bool(s.ban):
		if not spike():
			s.ban = false
			Game.add_feed("Food export ban lifted as prices calm", "wheat", "accent")
		else:
			for i in Game.relations.size():
				if i != Game.player and Profiles.food_importer(i):
					Game.relations[i] = clampf(Game.relations[i] - 0.15, -100.0, 100.0)
	if reserve() >= 6.0 and self_sufficiency() >= 100.0:
		Achievements.unlock("granary")


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("food"):
		return {}
	var sup := str(st().support)
	return {"approval": {"some": 0.5, "generous": 1.0}.get(sup, 0.0), "growth": {"some": -0.03, "generous": -0.08}.get(sup, 0.0)}
