class_name Outcomes
extends RefCounted
## What your budget buys people, measured: life expectancy and adult literacy.
## Both start at real values (World Bank SP.DYN.LE00.IN, SE.ADT.LITR.ZS) and
## move slowly toward targets set by health and education spending and real
## incomes. They change over years, as they do in reality. Longer lives make
## people happier; a more literate workforce lifts long-run growth.
## Player only, stored in Game.dip.outcomes {life, literacy}. Constants in
## sim/economy.gd (LIFE_*, LIT_*).

const E = preload("res://sim/economy.gd")


static func start_life(i: int) -> float:
	return clampf(World.stat(i, "life_expectancy", 72.0), 45.0, 86.0)


static func start_lit(i: int) -> float:
	return clampf(World.stat(i, "literacy_pct", 85.0), 20.0, 99.5)


static func _st() -> Dictionary:
	if not Game.dip.has("outcomes"):
		Game.dip["outcomes"] = {"life": start_life(Game.player), "literacy": start_lit(Game.player)}
	return Game.dip.outcomes


static func _log2(now: float, then: Variant) -> float:
	var t := float(then)
	return log(now / t) / log(2.0) if t > 0.0 and now > 0.0 else 0.0


static func life_target(c: CountryState) -> float:
	var b: Dictionary = c.base
	var t := start_life(c.idx) + E.LIFE_HEALTH * _log2(c.effort("health"), b.get("health_effort", 0.0)) \
		+ E.LIFE_INCOME * _log2(c.real_gdp_per_capita(), World.stat(c.idx, "gdp", c.gdp) / maxf(World.stat(c.idx, "population", c.population), 1.0))
	if Projects.is_done(c, "hospitals") and not bool(c.projects.get("hospitals", {}).get("start", false)):
		t += 1.0
	if Projects.is_done(c, "water") and not bool(c.projects.get("water", {}).get("start", false)):
		t += 1.2
	if Laws.is_active(c, "universal_health") and not c.laws_start.has("universal_health"):
		t += 1.5
	if not c.builds.is_empty():
		t += float(Builds.modifiers(c).get("life", 0.0))
	if not c.taxes.is_empty():
		t += float(Taxes.modifiers(c).get("life", 0.0))
	if c.idx == Game.player and Game.dip.has("tech"):
		t += float(Tech.modifiers().get("life", 0.0))
	return clampf(t, 40.0, 90.0)


static func lit_target(c: CountryState) -> float:
	var b: Dictionary = c.base
	var s0 := start_lit(c.idx)
	# Gains shrink near 100 %: each push closes part of the remaining gap.
	var push := E.LIT_EDUCATION * _log2(c.effort("education"), b.get("education_effort", 0.0))
	if Projects.is_done(c, "schools") and not bool(c.projects.get("schools", {}).get("start", false)):
		push += 6.0
	if not c.builds.is_empty():
		push += float(Builds.modifiers(c).get("lit", 0.0))
	return clampf(s0 + push * (100.0 - s0) / 30.0, 10.0, 99.7)


static func monthly() -> void:
	var c := Game.me()
	var st := _st()
	st.life = float(st.life) + (life_target(c) - float(st.life)) * E.LIFE_ADJUST
	st.literacy = float(st.literacy) + (lit_target(c) - float(st.literacy)) * E.LIT_ADJUST
	# The last 13 months, for "in a year" deltas on the Economy page.
	for k in ["life", "literacy"]:
		var h: Array = st.get("hist_" + k, [])
		h.append(snappedf(float(st[k]), 0.001))
		if h.size() > 13:
			h.pop_front()
		st["hist_" + k] = h


## The value a year ago (NAN if not yet known).
static func year_ago(key: String) -> float:
	var h: Array = _st().get("hist_" + key, [])
	return float(h[0]) if h.size() >= 13 else NAN


static func life(c: CountryState) -> float:
	return float(_st().life) if c != null and c.idx == Game.player and Game.has_game() else start_life(c.idx)


static func literacy(c: CountryState) -> float:
	return float(_st().literacy) if c != null and c.idx == Game.player and Game.has_game() else start_lit(c.idx)


## Happiness from living longer than at the start.
static func happiness_effect(c: CountryState) -> float:
	if c.idx != Game.player:
		return 0.0
	return E.LIFE_HAPPY * (life(c) - start_life(c.idx))


## Growth from a more (or less) literate workforce.
static func growth_effect(c: CountryState) -> float:
	if c.idx != Game.player:
		return 0.0
	return E.LIT_GROWTH * (literacy(c) - start_lit(c.idx))
