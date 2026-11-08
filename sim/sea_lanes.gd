class_name SeaLanes
extends RefCounted
## Sea lanes: the narrow straits most of the world's trade squeezes through.
## Now and then one is disrupted (a blockade, attacks on ships, a grounded
## giant container ship, a drought that lowers a canal). Ships detour, freight
## and insurance costs jump, and countries that trade a lot feel it in growth
## and prices; Hormuz hits oil importers hardest. Canal owners lose tolls.
##   Naval escort    join an international mission to reopen a strait sooner
##                   (needs a real navy; costs money; friends abroad notice).
##   Canal tolls     if you own a canal (Egypt, Panama): cheap tolls keep ships
##                   coming and partners happy; high tolls earn more per ship.
## Disruptions only touch your country's numbers (the world's markets stay as they are).
## State: Game.dip.sea {open: {id: until month}, escort: {id: true}, toll, last}.
## Constants in sim/economy.gd (SEA_*).

const E = preload("res://sim/economy.gd")

## id -> {title, owner (iso, "" = shared), oil (share of world oil through it), trade (share of trade), causes}
const LANES := {
	"hormuz": {"title": "Strait of Hormuz", "owner": "", "oil": 1.0, "trade": 0.3,
		"causes": ["Tankers are attacked in the Strait of Hormuz", "A standoff closes the Strait of Hormuz"]},
	"suez": {"title": "Suez Canal", "owner": "EGY", "oil": 0.2, "trade": 1.0, "rev": 2.5,
		"causes": ["A giant container ship blocks the Suez Canal", "Shipping avoids the Suez route after attacks"]},
	"bab": {"title": "Bab el-Mandeb", "owner": "", "oil": 0.25, "trade": 0.8,
		"causes": ["Missile attacks on ships in the Red Sea", "Shipping flees the Bab el-Mandeb strait"]},
	"panama": {"title": "Panama Canal", "owner": "PAN", "oil": 0.0, "trade": 0.6, "rev": 5.0,
		"causes": ["Drought lowers the Panama Canal: fewer ships can pass"]},
	"malacca": {"title": "Strait of Malacca", "owner": "", "oil": 0.4, "trade": 1.0,
		"causes": ["Piracy and a naval standoff slow the Strait of Malacca"]},
	"bosporus": {"title": "Bosporus", "owner": "", "oil": 0.1, "trade": 0.3, "food": 1.0,
		"causes": ["Grain ships are stuck at the Bosporus"]},
}

## Where each strait is (longitude, latitude) for the map.
const POS := {"hormuz": Vector2(56.4, 26.5), "suez": Vector2(32.4, 30.6), "bab": Vector2(43.4, 12.6),
	"panama": Vector2(-79.7, 9.1), "malacca": Vector2(100.5, 3.0), "bosporus": Vector2(29.0, 41.1)}

const TOLLS := ["low", "normal", "high"]
const TOLL_INFO := {"low": {"title": "Low", "rev": 0.8, "rel": 0.05}, "normal": {"title": "Normal", "rev": 1.0, "rel": 0.0},
	"high": {"title": "High", "rev": 1.2, "rel": -0.05}}


static func st() -> Dictionary:
	if not Game.dip.has("sea"):
		Game.dip["sea"] = {"open": {}, "escort": {}, "toll": "normal", "last": 0}
	return Game.dip.sea


static func disrupted(id: String) -> bool:
	return (st().open as Dictionary).has(id)


static func months_left(id: String) -> int:
	return maxi(0, int((st().open as Dictionary).get(id, 0)) - Game.months_played)


## The canal you own ("" if none).
static func my_canal() -> String:
	var iso := World.iso(Game.player)
	for id in LANES:
		if str(LANES[id].owner) == iso:
			return str(id)
	return ""


static func can_escort() -> bool:
	return Game.me().military >= E.SEA_ESCORT_MIL


static func set_escort(id: String, on: bool) -> void:
	var e: Dictionary = st().escort
	if on:
		e[id] = true
		Game.add_feed("Your navy joins the escort mission in the %s" % str(LANES[id].title), "ship", "accent")
	else:
		e.erase(id)


static func set_toll(t: String) -> void:
	st().toll = t


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("sea"):
		return 0.0
	return E.SEA_ESCORT_COST * float((st().escort as Dictionary).size())


## Canal tolls relative to the start (owners only; % of GDP).
static func revenue_pct() -> float:
	if not Game.has_game() or not Game.dip.has("sea"):
		return 0.0
	var id := my_canal()
	if id == "":
		return 0.0
	var base := float(LANES[id].rev)
	var now := base * float(TOLL_INFO[str(st().toll)].rev)
	if disrupted(id) or (id == "suez" and disrupted("bab")):
		now *= 1.0 - E.SEA_CANAL_LOSS
	return now - base


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var o: Dictionary = s.open
	for id in o.keys():
		# An escort mission (yours counts) clears it faster.
		if (s.escort as Dictionary).has(id) and Game.months_played % 2 == 0:
			o[id] = int(o[id]) - 1
		if int(o[id]) <= Game.months_played:
			o.erase(id)
			(s.escort as Dictionary).erase(id)
			out.append({"text": "Ships pass freely through the %s again" % str(LANES[id].title), "icon": "ship", "good": true, "big": false})
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "sea"])
	if Game.months_played >= 6 and o.size() < 2 and r.randf() < E.SEA_CHANCE:
		var ids: Array = LANES.keys()
		var id2: String = ids[r.randi() % ids.size()]
		if not o.has(id2):
			o[id2] = Game.months_played + r.randi_range(E.SEA_MIN_MONTHS, E.SEA_MAX_MONTHS)
			var causes: Array = LANES[id2].causes
			out.append({"text": str(causes[r.randi() % causes.size()]), "icon": "ship", "good": false, "big": true})
	# Toll diplomacy for canal owners.
	if my_canal() != "":
		var rel := float(TOLL_INFO[str(s.toll)].rel)
		if rel != 0.0:
			for i in Game.relations.size():
				if i != Game.player:
					Game.relations[i] = clampf(Game.relations[i] + rel, -100.0, 100.0)
	return out


## Effects on your targets while lanes are disrupted.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("sea"):
		return {}
	var c := Game.me()
	var open := clampf(c.trade_openness, 0.0, 1.5)
	var oilx := clampf(-WorldMarkets.oil_exposure(Game.player), -0.5, 1.0)
	var foodx := WorldMarkets.food_exposure(Game.player)
	var g := 0.0
	var infl := 0.0
	for id in st().open:
		var l: Dictionary = LANES[id]
		g -= E.SEA_TRADE_HIT * float(l.trade) * open
		infl += E.SEA_PRICE_HIT * (float(l.trade) * open * 0.5 + float(l.oil) * maxf(oilx, 0.0) + float(l.get("food", 0.0)) * foodx)
		g += E.SEA_OIL_GAIN * float(l.oil) * maxf(-oilx, 0.0)      # exporters elsewhere sell dearer
	var out := {"growth": clampf(g, -1.0, 0.5), "inflation": clampf(infl, 0.0, 1.5)}
	for id in st().escort:
		out["stability"] = float(out.get("stability", 0.0)) + 0.3     # the nation proud of its navy
	return out
