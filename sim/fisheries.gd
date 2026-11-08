class_name Fisheries
extends RefCounted
## Fisheries & oceans (coastal countries).
##   Fish stocks   health of the fish in your waters (0-100). Catching more than
##                 the sea can replace runs them down; below 25 a stock can
##                 collapse, as Newfoundland's cod did in 1992, and take years
##                 to come back.
##   Quota         Maximum catch (more income now) · Sustainable · Rebuild
##                 (less now, more later).
##   Protected seas  share of your waters closed to fishing: stocks and divers'
##                 tourism recover; a little less catch.
##   Foreign fleets  distant-water fleets sometimes fish your waters illegally.
## Effects count only the change since you took office.
## State: Game.dip.fish {stock0, stock, quota, mpa, collapsed (month)}. Constants in sim/economy.gd (FISH_*).

const E = preload("res://sim/economy.gd")

## Fishing and seafood as a share of GDP (%, FAO / national accounts, rounded).
const SHARE := {"ISL": 7.0, "MDV": 5.0, "KIR": 9.0, "FSM": 8.0, "MRT": 6.0, "SLB": 5.0, "SEN": 3.0, "PER": 1.5,
	"NOR": 1.5, "CHL": 1.2, "VNM": 2.5, "IDN": 2.5, "PHL": 1.5, "BGD": 3.0, "MMR": 2.0, "THA": 1.0, "ECU": 1.5,
	"NZL": 0.8, "MAR": 1.5, "NAM": 3.0, "MOZ": 2.0, "GHA": 1.2, "SLE": 3.0, "GMB": 3.0, "LKA": 1.2, "IND": 1.0,
	"CHN": 1.0, "JPN": 0.3, "KOR": 0.4, "RUS": 0.3, "USA": 0.1, "CAN": 0.2, "GBR": 0.1, "ESP": 0.3, "FRA": 0.1}
## Regions whose fish stocks start in poor shape (heavily fished seas).
const OVERFISHED := ["Southern Europe", "Western Africa", "Eastern Asia", "South-Eastern Asia", "Western Asia", "Northern Africa"]

const QUOTAS := ["max", "sustain", "rebuild"]
const QUOTA_INFO := {
	"max": {"title": "Max catch", "catch": 0.15, "stock": -2.5},
	"sustain": {"title": "Sustainable", "catch": 0.0, "stock": 0.2},
	"rebuild": {"title": "Rebuild", "catch": -0.2, "stock": 2.0},
}
const MPAS := [0, 10, 30]


static func coastal() -> bool:
	return not World.landlocked(Game.player)


static func st() -> Dictionary:
	if not Game.dip.has("fish"):
		var stock := 55.0 if World.map.subregions[Game.player] in OVERFISHED else 68.0
		Game.dip["fish"] = {"stock0": stock, "stock": stock, "quota": "sustain", "mpa": 0, "collapsed": -999}
	return Game.dip.fish


static func share_gdp() -> float:
	return float(SHARE.get(World.iso(Game.player), 0.4))


static func stock() -> float:
	return float(st().stock)


static func label(v: float) -> String:
	if v >= 75.0:
		return "Healthy"
	if v >= 55.0:
		return "Fair"
	if v >= 35.0:
		return "Overfished"
	return "Near collapse"


static func color(v: float) -> Color:
	return DS.GREEN if v >= 75.0 else (DS.ACCENT if v >= 55.0 else (DS.ORANGE if v >= 35.0 else DS.RED))


static func collapsed() -> bool:
	return Game.months_played - int(st().collapsed) < E.FISH_COLLAPSE_MONTHS


## Catch relative to the start (1 = as when you took office).
static func catch_index() -> float:
	var s := st()
	var k := 1.0 + float(QUOTA_INFO[str(s.quota)].catch) - float(s.mpa) / 100.0 * 0.3
	k *= clampf(0.55 + 0.45 * stock() / maxf(float(s.stock0), 1.0), 0.4, 1.3)
	if collapsed():
		k *= 1.0 - E.FISH_COLLAPSE_LOSS
	return k


static func set_quota(q: String) -> void:
	st().quota = q


static func set_mpa(p: int) -> void:
	st().mpa = p


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null or not coastal():
		return out
	var s := st()
	var d := float(QUOTA_INFO[str(s.quota)].stock) + float(s.mpa) / 10.0 * 0.4
	if Treaties.is_member(Game.player, "high_seas"):
		d += 0.3
	if Game.dip.has("water") and Climate.warming() > float(Water.st().get("w0", Climate.warming())) + 0.2:
		d -= 0.3      # warmer seas
	s.stock = clampf(float(s.stock) + d / 12.0, 5.0, 100.0)
	if float(s.stock) < E.FISH_COLLAPSE_AT and not collapsed():
		s.collapsed = Game.months_played
		Game.add_milestone("Fish stocks collapsed", "fish", "red")
		out.append({"text": "Fish stocks collapse: the fleet stays in port and fishing towns despair", "icon": "fish", "good": false, "big": true})
	if stock() >= 85.0 and float(s.stock0) < 75.0:
		Achievements.unlock("full_nets")
	return out


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("fish") or not coastal():
		return {}
	var dk := catch_index() - 1.0
	var out := {"growth": clampf(dk * share_gdp() * E.FISH_GROWTH, -0.6, 0.3),
		"happiness": clampf(dk * share_gdp() * 0.3, -1.5, 0.5)}
	if collapsed():
		out["approval"] = -1.0
	return out


## Divers and marine parks: a little soft power from protected seas.
static func prestige() -> float:
	if not Game.dip.has("fish"):
		return 0.0
	return float(st().mpa) / 10.0
