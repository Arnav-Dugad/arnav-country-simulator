class_name Diaspora
extends RefCounted
## Diaspora & remittances: the money people working abroad send home (World
## Bank data, % of GDP). For Tajikistan or Nepal it is a pillar of the economy;
## Gulf states, where many migrants work, see money flow out instead.
##   Remittances   rise when the diaspora grows (emigration, brain drain) and
##                 when host economies boom; they fall in world recessions.
##   Policies      cut transfer fees (more arrives), diaspora bonds (cheap money
##                 from abroad, once every five years), votes and dual
##                 citizenship (loyalty and soft power), or, where money flows
##                 out, a tax on outgoing transfers (revenue; sending countries object).
## Effects count only the change since you took office.
## State: Game.dip.dias {r0, r, fees, vote, tax, bond (month)}. Constants in sim/economy.gd (DIAS_*).

const E = preload("res://sim/economy.gd")

## Personal remittances received, % of GDP (World Bank, 2023, rounded).
const IN := {"TJK": 48, "TON": 41, "LBN": 28, "NPL": 26, "HND": 26, "SLV": 24, "WSM": 21, "GMB": 21, "HTI": 21,
	"LSO": 20, "JAM": 19, "GTM": 19, "KGZ": 19, "YEM": 19, "XKX": 15, "GEO": 15, "MDA": 13, "LBR": 13, "NIC": 27,
	"ARM": 10, "BIH": 10, "SEN": 10, "PHL": 9, "JOR": 9, "ALB": 9, "PAK": 8, "MAR": 8, "LKA": 8, "SRB": 8,
	"UZB": 14, "UKR": 7, "GHA": 6, "EGY": 5, "BGD": 5, "DOM": 10, "MEX": 4, "NGA": 4, "IND": 3, "VNM": 3,
	"KEN": 3, "COL": 3, "ECU": 4, "BOL": 3, "TUN": 6, "ZWE": 8, "SOM": 30, "PSE": 15, "MNE": 12, "MKD": 8}
## Remittances sent abroad, % of GDP (host countries).
const OUT := {"SAU": 4, "ARE": 7, "KWT": 7, "QAT": 6, "OMN": 8, "BHR": 6, "CHE": 2, "LUX": 4, "MYS": 1, "SGP": 1,
	"RUS": 1, "USA": 0.3, "ISR": 1}


static func st() -> Dictionary:
	if not Game.dip.has("dias"):
		var iso := World.iso(Game.player)
		var r := float(IN.get(iso, 0.0)) - float(OUT.get(iso, 0.0))
		if r == 0.0:
			var lvl := Economy.income_level(Game.me().gdp_per_capita()) if Game.me() != null else 0.5
			r = clampf(4.0 * (0.5 - lvl), 0.0, 3.0)
		Game.dip["dias"] = {"r0": r, "r": r, "fees": false, "vote": false, "tax": false, "bond": -99}
	return Game.dip.dias


static func rate() -> float:
	return float(st().r)


## True where money flows out (a host country).
static func host() -> bool:
	return float(st().r0) < 0.0


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("dias"):
		return 0.0
	return E.DIAS_FEES_COST if bool(st().fees) else 0.0


static func revenue_pct() -> float:
	if not Game.has_game() or not Game.dip.has("dias") or not bool(st().tax):
		return 0.0
	return absf(rate()) * E.DIAS_TAX_RATE


static func set_fees(on: bool) -> void:
	st().fees = on


static func set_tax(on: bool) -> void:
	st().tax = on and host()


static func can_vote() -> bool:
	return not bool(st().vote) and Capital.can(E.DIAS_VOTE_CAPITAL)


static func give_vote() -> bool:
	if not can_vote() or not Capital.spend(E.DIAS_VOTE_CAPITAL):
		return false
	st().vote = true
	Game.add_feed("Citizens abroad can now vote and keep two passports", "vote", "accent")
	return true


static func bond_wait() -> int:
	return maxi(0, int(st().bond) + 60 - Game.months_played)


## Diaspora bonds: borrow from your own people abroad at a low rate.
static func bond_size() -> float:
	return Game.me().gdp * clampf(rate(), 0.0, 30.0) / 100.0 * E.DIAS_BOND_SHARE


static func issue_bond() -> bool:
	if host() or bond_wait() > 0 or rate() < 1.0:
		return false
	var c := Game.me()
	var v := bond_size()
	c.treasury += v
	c.debt += v
	st().bond = Game.months_played
	Game.add_feed("Diaspora bonds raise %s from citizens abroad" % DS.money(v), "hand-coins", "green")
	return true


static func target() -> float:
	var s := st()
	var r0 := float(s.r0)
	var t := r0
	if r0 > 0.0:
		t *= 1.0 + (E.DIAS_FEES_BOOST if bool(s.fees) else 0.0) + (0.05 if bool(s.vote) else 0.0)
		t *= 1.0 + clampf(-Migration.rate(Game.me()) - maxf(-Migration.start_rate(Game.player), 0.0), -2.0, 4.0) * 0.03
		if Game.dip.has("edu"):
			t *= 1.0 + clampf(Education.drain() - float(Education.st().drain0), -5.0, 10.0) * 0.01
		t *= 1.0 + Game.markets.world_cycle * 0.04
	else:
		t *= 1.0 - (E.DIAS_TAX_DETER if bool(s.tax) else 0.0)
	return t


static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	s.r = float(s.r) + (target() - float(s.r)) * 0.05
	if bool(s.tax):
		for iso in IN:
			var j := World.index_of(str(iso))
			if j >= 0 and j != Game.player:
				Game.relations[j] = clampf(Game.relations[j] - 0.03, -100.0, 100.0)


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("dias"):
		return {}
	var s := st()
	var d := rate() - float(s.r0)
	var out := {"happiness": clampf(d * 0.15, -1.0, 1.2), "growth": clampf(d * 0.04, -0.4, 0.4)}
	if bool(s.vote):
		out["approval"] = 0.5
	return out


static func prestige() -> float:
	if not Game.dip.has("dias"):
		return 0.0
	return 2.0 if bool(st().vote) else 0.0
