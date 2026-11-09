class_name Minerals
extends RefCounted
## Critical minerals: what batteries, wind turbines and chips are made of.
## A handful of countries produce most of the world's supply (USGS 2024
## shares). Demand climbs as the world electrifies; prices swing.
##   Expand mines      more output and export earnings, but local protests and
##                     dirtier air and water.
##   Supply deals      sign with the West or with China: better prices and a
##                     friend, at the cost of the other camp's goodwill.
##   Process at home   ban raw exports (as Indonesia did with nickel): earnings
##                     drop for a few years, then refineries and factories come.
##   Survey            prospect for new deposits; sometimes you strike it rich.
## Effects count only the change since you took office.
## State: Game.dip.min {share: {m: s0}, extra: {m: s}, deal: {m: camp}, ban: {m: month}, price: {m: idx}, survey}.
## Constants in sim/economy.gd (MIN_*).

const E = preload("res://sim/economy.gd")

## mineral -> {title, icon, value (world market, USD bn a year), producers (iso: world share %)}
const ALL := {
	"lithium": {"title": "Lithium", "icon": "battery-charging", "value": 40.0,
		"producers": {"AUS": 47, "CHL": 24, "CHN": 18, "ARG": 6, "BRA": 3, "ZWE": 2}},
	"cobalt": {"title": "Cobalt", "icon": "atom", "value": 12.0,
		"producers": {"COD": 74, "IDN": 7, "RUS": 4, "AUS": 3, "PHL": 2, "CAN": 2}},
	"rare_earths": {"title": "Rare earths", "icon": "magnet", "value": 15.0,
		"producers": {"CHN": 70, "USA": 12, "MMR": 8, "AUS": 5, "THA": 2, "VNM": 1}},
	"nickel": {"title": "Nickel", "icon": "cog", "value": 35.0,
		"producers": {"IDN": 50, "PHL": 10, "RUS": 6, "CAN": 4, "AUS": 3, "BRA": 2}},
	"copper": {"title": "Copper", "icon": "cable", "value": 230.0,
		"producers": {"CHL": 24, "PER": 11, "COD": 11, "CHN": 8, "USA": 5, "RUS": 4, "IDN": 4, "AUS": 4, "ZMB": 3}},
}


static func st() -> Dictionary:
	if not Game.dip.has("min"):
		var iso := World.iso(Game.player)
		var share := {}
		var price := {}
		for m in ALL:
			price[m] = 100.0
			var p: Dictionary = ALL[m].producers
			if p.has(iso):
				share[m] = float(p[iso])
		Game.dip["min"] = {"share": share, "extra": {}, "deal": {}, "ban": {}, "price": price, "survey": -99, "build": {}}
	return Game.dip.min


## Your share of world output now (%).
static func share(m: String) -> float:
	var s := st()
	return float((s.share as Dictionary).get(m, 0.0)) + float((s.extra as Dictionary).get(m, 0.0))


static func mine_list() -> Array:
	var out: Array = []
	for m in ALL:
		if share(m) > 0.0:
			out.append(m)
	return out


## Export earnings from a mineral, % of GDP.
static func earnings_pct(m: String) -> float:
	var s := st()
	var v := float(ALL[m].value) * 1e9 * share(m) / 100.0 * float(s.price[m]) / 100.0
	if (s.deal as Dictionary).has(m):
		v *= 1.0 + E.MIN_DEAL_PREMIUM
	if (s.ban as Dictionary).has(m) and Game.months_played - int(s.ban[m]) < E.MIN_BAN_DIP_MONTHS:
		v *= 1.0 - E.MIN_BAN_DIP
	return v / maxf(Game.me().gdp, 1.0) * 100.0


static func start_earnings_pct(m: String) -> float:
	var p := float((st().share as Dictionary).get(m, 0.0))
	return float(ALL[m].value) * 1e9 * p / 100.0 / maxf(Game.me().gdp, 1.0) * 100.0


static func revenue_pct() -> float:
	if not Game.has_game() or not Game.dip.has("min") or Game.me() == null:
		return 0.0
	var d := 0.0
	for m in ALL:
		if share(m) > 0.0:
			d += earnings_pct(m) - start_earnings_pct(m)
	return d * E.MIN_STATE_TAKE


static func expanding(m: String) -> bool:
	return (st().build as Dictionary).has(m)


static func can_expand(m: String) -> bool:
	return share(m) > 0.0 and not expanding(m) and float((st().extra as Dictionary).get(m, 0.0)) < float((st().share as Dictionary).get(m, 1.0)) * 1.5 + 6.0


static func expand(m: String) -> bool:
	if not can_expand(m):
		return false
	(st().build as Dictionary)[m] = Game.months_played
	Game.add_feed("New %s mines open up for investment" % str(ALL[m].title).to_lower(), str(ALL[m].icon), "accent")
	return true


static func set_deal(m: String, camp: String) -> void:
	var d: Dictionary = st().deal
	var prev := str(d.get(m, ""))
	if prev == camp:
		return
	if prev != "":
		_deal_relations(prev, -1.0)      # the old partner feels jilted
	if camp == "":
		d.erase(m)
		Game.relations_changed.emit()
		return
	d[m] = camp
	_deal_relations(camp, 1.0)
	Game.relations_changed.emit()
	Game.add_feed("%s supply deal signed with %s" % [str(ALL[m].title), "the West" if camp == "west" else "China and its partners"], "handshake", "accent")


static func _deal_relations(camp: String, sign: float) -> void:
	var other := "east" if camp == "west" else "west"
	for i in Treaties.camp(camp):
		Game.relations[i] = clampf(Game.relations[i] + sign * E.MIN_DEAL_FRIEND, -100.0, 100.0)
	for i in Treaties.camp(other):
		Game.relations[i] = clampf(Game.relations[i] - sign * E.MIN_DEAL_RIVAL, -100.0, 100.0)


static func ban(m: String) -> void:
	var b: Dictionary = st().ban
	if b.has(m):
		b.erase(m)
	else:
		b[m] = Game.months_played
		Game.add_feed("Raw %s exports banned: refine it at home" % str(ALL[m].title).to_lower(), "factory", "orange")


static func survey_wait() -> int:
	return maxi(0, int(st().survey) + 36 - Game.months_played)


static func survey() -> String:
	if survey_wait() > 0 or not Capital.spend(E.MIN_SURVEY_CAPITAL):
		return ""
	var s := st()
	s.survey = Game.months_played
	Game.me().treasury -= Game.me().gdp * E.MIN_SURVEY_COST / 100.0
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "survey"])
	if r.randf() < E.MIN_SURVEY_CHANCE:
		var ids: Array = ALL.keys()
		var m: String = ids[r.randi() % ids.size()]
		var add := r.randf_range(1.0, 4.0)
		(s.extra as Dictionary)[m] = float((s.extra as Dictionary).get(m, 0.0)) + add
		Game.add_milestone("Discovered %s deposits" % str(ALL[m].title).to_lower(), str(ALL[m].icon), "gold")
		Game.intel_news.emit({"text": "Geologists strike %s: enough for %s of world supply" % [str(ALL[m].title).to_lower(), DS.pct(add, 0)],
			"icon": str(ALL[m].icon), "good": true, "big": true, "celebrate": true})
		return m
	Game.add_feed("The mineral survey finds nothing worth mining this time", "search", "accent")
	return "-"


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("min"):
		return 0.0
	return E.MIN_EXPAND_COST * float((st().build as Dictionary).size())


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "minerals"])
	for m in ALL:
		var p := float(s.price[m])
		var step := E.MIN_DRIFT + r.randfn(0.0, E.MIN_VOL) - (p / 100.0 - 1.0) * 0.01
		s.price[m] = clampf(p * exp(step), 30.0, 400.0)
	for m in (s.build as Dictionary).keys():
		if Game.months_played - int(s.build[m]) >= E.MIN_EXPAND_MONTHS:
			(s.build as Dictionary).erase(m)
			var add := float((s.share as Dictionary).get(m, 2.0)) * 0.25 + 1.0
			(s.extra as Dictionary)[m] = float((s.extra as Dictionary).get(m, 0.0)) + add
			Game.me().shocks.approval = float(Game.me().shocks.approval) - E.MIN_PROTEST
			out.append({"text": "New %s mines open: output up, but nearby towns protest the dust" % str(ALL[m].title).to_lower(),
				"icon": str(ALL[m].icon), "good": true, "big": false})
	return out


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("min") or Game.me() == null:
		return {}
	var g := 0.0
	var s := st()
	for m in s.ban:
		if Game.months_played - int(s.ban[m]) >= E.MIN_BAN_DIP_MONTHS:
			g += E.MIN_PROCESSING_GROWTH * clampf(share(m) / 20.0, 0.2, 1.5)
		else:
			g -= 0.05
	var extra := 0.0
	for m in s.extra:
		extra += float(s.extra[m])
	return {"growth": clampf(g + revenue_pct() * 0.3, -0.5, 1.0), "happiness": -clampf(extra * 0.02, 0.0, 0.8)}
