class_name Migration
extends RefCounted
## People moving in and out. Every country starts at its real net migration
## (UN World Population Prospects via the World Bank, 2019-2023 average, per
## 1,000 people a year). It then shifts with what pulls people in or pushes them
## out: real incomes, happiness, unrest and jobs compared with the start, plus
## visa and border laws. Only the CHANGE from the starting rate matters, so the
## real baseline stays as it is (population growth already includes it).
##
## Effects of extra arrivals: faster population growth, a larger workforce
## (more growth, most of all in ageing countries) and, at first, a little more
## competition for jobs. Constants live in sim/economy.gd (MIG_*).

const E = preload("res://sim/economy.gd")


## Starting net migration, per 1,000 people a year.
static func start_rate(i: int) -> float:
	return clampf(World.stat(i, "net_migration_rate", 0.0), -E.MIG_CAP, E.MIG_CAP)


## +1 if the law was added during play, -1 if a starting law was scrapped, else 0.
static func _law(c: CountryState, id: String) -> float:
	var on := Laws.is_active(c, id)
	var was := c.laws_start.has(id)
	return 1.0 if on and not was else (-1.0 if was and not on else 0.0)


## Change from the starting rate, per 1,000 people a year.
static func delta(c: CountryState) -> float:
	var i := c.idx
	var b: Dictionary = c.base
	var pc0 := World.stat(i, "gdp", c.gdp) / maxf(World.stat(i, "population", c.population), 1000.0)
	# Income counts against the world's: everyone else is getting richer too.
	var world := pow(1.0 + E.MIG_WORLD_GROWTH, Game.months_played / 12.0)
	var d := E.MIG_INCOME * log(maxf(c.real_gdp_per_capita(), 1.0) / maxf(pc0 * world, 1.0)) / log(2.0)
	d += E.MIG_HAPPY * (c.happiness - float(b.happiness)) / 10.0
	d += E.MIG_UNREST * minf(c.stability - float(b.stability), 0.0) / 10.0
	d -= E.MIG_JOBS * maxf(c.unemployment - float(b.unemployment), 0.0)
	d += E.MIG_VISAS * _law(c, "skilled_visas")
	d -= E.MIG_BORDER * _law(c, "border_control")
	return clampf(d, -E.MIG_CAP, E.MIG_CAP)


## Net migration now, per 1,000 people a year.
static func rate(c: CountryState) -> float:
	return start_rate(c.idx) + delta(c)


## Extra population growth, % a year, for a given delta().
static func pop_effect(d: float) -> float:
	return d / 10.0


## Growth from a bigger (or smaller) workforce, % a year.
static func growth_effect(c: CountryState, d: float) -> float:
	var ageing := 1.5 if World.stat(c.idx, "age65_pct", 10.0) > 18.0 else 1.0
	return E.MIG_GROWTH * d * ageing


## A short-run rise in joblessness when arrivals jump.
static func jobs_effect(d: float) -> float:
	return E.MIG_UNEMP * maxf(d, 0.0)


## "Migration +8.3 per 1,000 a year: more arrive than leave"
static func describe(c: CountryState) -> String:
	var r := rate(c)
	if absf(r) < 0.3:
		return "Migration: about as many arrive as leave"
	return "Migration %s%s per 1,000 a year: more %s" % ["+" if r > 0.0 else "−", String.num(absf(r), 1),
		"arrive than leave" if r > 0.0 else "leave than arrive"]
