class_name Ageing
extends RefCounted
## An ageing population. Every country starts at its real share of people aged
## 65+ (World Bank SP.POP.65UP.TO.ZS). The share then rises each year, faster in
## richer countries with few births, slower where young migrants arrive. Each
## extra point raises pension and care costs (spending) and shrinks the
## workforce a little (growth). Raising the pension age softens both.
## Constants in sim/economy.gd (AGEING_*, PENSION_*).

const E = preload("res://sim/economy.gd")


static func start(i: int) -> float:
	return clampf(World.stat(i, "age65_pct", 10.0), 1.0, 40.0)


## Points of 65+ share added per year (UN WPP 2024: rich ageing societies +0.3
## to +0.5 a year this decade, young low-income ones about +0.1).
static func rate(i: int) -> float:
	var pc := World.stat(i, "gdp", 1e9) / maxf(World.stat(i, "population", 1e6), 1.0)
	return E.AGEING_RATE_MIN + (E.AGEING_RATE_MAX - E.AGEING_RATE_MIN) * Economy.income_level(pc)


## Share of people aged 65+ now (%).
static func share(c: CountryState) -> float:
	var years := Game.months_played / 12.0 if Game.has_game() else 0.0
	if years <= 0.0 or c.base.is_empty():      # not started yet (or still being set up)
		return start(c.idx)
	# Finances are recomputed many times a month: work it out once per month.
	if c.has_meta(&"age_m") and int(c.get_meta(&"age_m")) == Game.months_played:
		return float(c.get_meta(&"age_v"))
	var r := rate(c.idx) - E.AGEING_MIGRANT_RELIEF * Migration.delta(c)
	# The share rises at the real early pace, then slows as it nears a ceiling.
	var s0 := start(c.idx)
	var room := maxf(E.AGEING_CEIL - s0, 1.0)
	var v := clampf(s0 + room * (1.0 - exp(-maxf(r, 0.0) * years / room)), 1.0, 45.0)
	c.set_meta(&"age_m", Game.months_played)
	c.set_meta(&"age_v", v)
	return v


## Points added since the start.
static func change(c: CountryState) -> float:
	return share(c) - start(c.idx)


static func _relief(c: CountryState) -> float:
	var added := Laws.is_active(c, "pension_age") and not c.laws_start.has("pension_age")
	return 1.0 - (E.PENSION_AGE_RELIEF if added else 0.0)


## Extra pension and care spending since the start, % of GDP.
static func pension_cost(c: CountryState) -> float:
	return E.PENSION_PER_PT * change(c) * _relief(c)


## Growth lost to a shrinking workforce, % a year.
static func growth_drag(c: CountryState) -> float:
	return -E.AGEING_GROWTH_DRAG * change(c) * _relief(c)
