class_name WorldMarkets
extends RefCounted
## The world economy every country shares:
##   oil and food prices   slow random walks with mean reversion and rare shocks;
##                         exporters gain and importers pay (real fuel-export and
##                         food-import data decide who is who)
##   contagion             each month the world's and each region's economic
##                         "temperature" (growth vs. trend, GDP-weighted) is measured;
##                         open economies catch it, and trade partners pass it on
## Constants live in sim/economy.gd (MARKET_*, OIL_*, FOOD_*, CONTAGION_*).

const E = preload("res://sim/economy.gd")
const HISTORY := 240

var oil := 0.0        # log price index: 0 = normal (~$75 a barrel)
var food := 0.0       # log price index: 0 = normal (FAO index ~ 120)
var oil_hist := PackedFloat32Array()
var food_hist := PackedFloat32Array()
var world_cycle := 0.0                 # GDP-weighted (growth - underlying growth), points
var region_cycle := {}                 # subregion -> same, for neighbours' contagion


func reset(rng: RandomNumberGenerator) -> void:
	oil = rng.randf_range(-0.08, 0.08)
	food = rng.randf_range(-0.05, 0.05)
	oil_hist = PackedFloat32Array([oil_price()])
	food_hist = PackedFloat32Array([food_index()])
	world_cycle = 0.0
	region_cycle = {}


## Dollars per barrel.
func oil_price() -> float:
	return E.OIL_BASE_PRICE * exp(oil)


## Food price index (FAO style, 2014-16 = 100; normal now ~120).
func food_index() -> float:
	return E.FOOD_BASE_INDEX * exp(food)


## Price vs. normal, -1..+1.5 (0.2 = 20 % above normal).
func oil_gap() -> float:
	return exp(oil) - 1.0


func food_gap() -> float:
	return exp(food) - 1.0


## Monthly: move prices, measure the world's economic temperature.
## Returns a headline string when something big happened ("" otherwise).
var food_news := false


func monthly(rng: RandomNumberGenerator) -> String:
	var news := ""
	food_news = false
	oil += -oil * E.OIL_REVERSION + rng.randfn(0.0, E.OIL_VOLATILITY)
	food += -food * E.FOOD_REVERSION + rng.randfn(0.0, E.FOOD_VOLATILITY)
	if rng.randf() < E.OIL_SHOCK_CHANCE:
		var up := rng.randf() < 0.6
		oil += E.OIL_SHOCK * (1.0 if up else -1.0)
		news = "Oil prices %s to $%d a barrel" % ["jump" if up else "crash", roundi(E.OIL_BASE_PRICE * exp(oil))]
	if rng.randf() < E.FOOD_SHOCK_CHANCE:
		food += E.FOOD_SHOCK
		news = "Poor harvests push world food prices up"
		food_news = true
	oil = clampf(oil, -0.9, 0.9)
	food = clampf(food, -0.5, 0.7)
	oil_hist.append(oil_price())
	food_hist.append(food_index())
	if oil_hist.size() > HISTORY:
		oil_hist.remove_at(0)
		food_hist.remove_at(0)
	_measure()
	return news


## Boom or bust: growth against the country's own recent average. Slow
## structural drags (ageing, debt) lower that average instead of counting as a
## recession forever, so the world cycle always returns to calm.
static func cycle_gap(c: CountryState) -> float:
	return clampf(c.growth - float(c.base.get("g_ema", c.growth_anchor)), -8.0, 8.0)


func _measure() -> void:
	for c0 in Game.countries:
		if c0 != null:
			var cs := c0 as CountryState
			var ema := float(cs.base.get("g_ema", cs.growth_anchor))
			cs.base["g_ema"] = ema + (cs.growth - ema) * E.CYCLE_EMA
	var tot := 0.0
	var w := 0.0
	var reg := {}
	var world := 0.0
	for c0 in Game.countries:
		if c0 != null:
			world += (c0 as CountryState).gdp
	var cap := maxf(world * E.WORLD_CYCLE_WEIGHT_CAP, 1.0)
	for i in Game.countries.size():
		var c: CountryState = Game.countries[i]
		if c == null:
			continue
		var gap := cycle_gap(c)
		var wt := minf(c.gdp, cap)
		tot += gap * wt
		w += wt
		var sub: String = World.map.subregions[i]
		var r: Array = reg.get(sub, [0.0, 0.0])
		r[0] += gap * wt
		r[1] += wt
		reg[sub] = r
	world_cycle = tot / maxf(w, 1.0)
	region_cycle = {}
	for k in reg:
		region_cycle[k] = float(reg[k][0]) / maxf(float(reg[k][1]), 1.0)


## How exposed a country is to oil: + exporter (gains when prices rise), - importer.
static func oil_exposure(i: int) -> float:
	var fuel := World.stat(i, "fuel_exports_pct", 5.0) / 100.0
	var importer := 0.0 if fuel > 0.25 else (1.0 if Profiles.has_challenge(i, "energy_imports") else 0.6)
	var shield := Climate.oil_shield(Game.state(i)) if Game.has_game() else 1.0
	return fuel - importer * (1.0 - fuel) * 0.5 * Profiles.mult(i, "oil_import_exposure") * shield


static func food_exposure(i: int) -> float:
	var poor := 1.0 - Economy.income_level(maxf(World.stat(i, "gdp", 1e9) / maxf(World.stat(i, "population", 1e6), 1.0), 100.0))
	var importer := 1.0 if Profiles.food_importer(i) else 0.4
	var shield := Food.shield() if Game.has_game() and i == Game.player else 1.0
	return importer * (0.4 + 0.6 * poor) * Profiles.mult(i, "food_exposure") * shield


## Target offsets for one country from world markets and contagion (named terms,
## shown in the "Why?" explainer). Keys: growth, inflation, happiness, revenue.
func effects(c: CountryState) -> Dictionary:
	var i := c.idx
	var og := oil_gap()
	var fg := food_gap()
	var ox := oil_exposure(i)
	var open := clampf(c.trade_openness, 0.0, 1.0)
	var growth := E.OIL_GROWTH * ox * og
	var infl := E.OIL_INFLATION * maxf(-ox, 0.0) * og + E.FOOD_INFLATION * food_exposure(i) * fg
	var happy := -E.FOOD_HAPPY * food_exposure(i) * maxf(fg, 0.0)
	var revenue := E.OIL_REVENUE * maxf(ox, 0.0) * og
	# Contagion: the world's mood, your region's mood, and your partners'.
	var reg := float(region_cycle.get(World.map.subregions[i], 0.0))
	var world := E.CONTAGION_WORLD * open * world_cycle + E.CONTAGION_REGION * reg
	if i == Game.player:
		var partners := 0.0
		var n := 0
		for k in Game.dip.get("deals", {}):
			var p: CountryState = Game.state(int(k))
			if p:
				partners += cycle_gap(p)
				n += 1
		if n > 0:
			world += E.CONTAGION_PARTNERS * partners / n
	return {"growth": growth, "inflation": infl, "happiness": happy, "revenue": revenue, "world": world}


func to_dict() -> Dictionary:
	return {"oil": oil, "food": food, "oil_hist": Array(oil_hist), "food_hist": Array(food_hist),
		"world_cycle": world_cycle, "region_cycle": region_cycle}


func load_dict(d: Dictionary) -> void:
	oil = float(d.get("oil", 0.0))
	food = float(d.get("food", 0.0))
	oil_hist = PackedFloat32Array(d.get("oil_hist", []))
	food_hist = PackedFloat32Array(d.get("food_hist", []))
	if oil_hist.is_empty():
		oil_hist.append(oil_price())
		food_hist.append(food_index())
	world_cycle = float(d.get("world_cycle", 0.0))
	region_cycle = d.get("region_cycle", {})
