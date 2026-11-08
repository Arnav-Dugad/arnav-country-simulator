class_name PowerIndex
extends RefCounted
## World powers: one composite score per country (0-100) from the size of its
## economy, its military, its soft power, nuclear weapons and its people's
## skills. A league table to climb; your starting rank is remembered.

## Score for country i.
static func score(i: int) -> float:
	var c: CountryState = Game.state(i)
	if c == null or World.is_absorbed(i):
		return 0.0
	var econ := clampf((log(maxf(c.gdp, 1e9)) / log(10.0) - 9.0) / 4.5, 0.0, 1.0)     # $1B .. $30T
	var mil := clampf(c.military / 100.0, 0.0, 1.0)
	var soft := clampf((Tourism.soft_power(i, i == Game.player) if Game.dip.has("tour") else 30.0) / 100.0, 0.0, 1.0)
	var nuke := clampf(log(float(Nuclear.warheads(i)) + 1.0) / log(6000.0), 0.0, 1.0)
	var skill := clampf((Education.score_of(i) - 300.0) / 260.0, 0.0, 1.0)
	return 100.0 * (0.42 * econ + 0.2 * mil + 0.16 * soft + 0.1 * nuke + 0.12 * skill)


## [[index, score], …] best first (cached once a month, not saved).
static var _cache: Array = []
static var _cache_m := -1
static var _cache_seed := -1


static func table() -> Array:
	if _cache_m == Game.months_played and _cache_seed == Game.rng.seed and not _cache.is_empty():
		return _cache
	var t: Array = []
	for i in World.playable:
		if Game.state(i) != null and not World.is_absorbed(i):
			t.append([i, score(i)])
	t.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	_cache = t
	_cache_m = Game.months_played
	_cache_seed = Game.rng.seed
	if int(Game.dip.get("power_start", 0)) == 0:
		Game.dip["power_start"] = rank_in(t)
	return t


static func rank_in(t: Array) -> int:
	for k in t.size():
		if int(t[k][0]) == Game.player:
			return k + 1
	return t.size()


static func rank() -> int:
	var r := rank_in(table())
	if r <= 3 and int(Game.dip.get("power_start", 0)) > 3:
		Achievements.unlock("top_power")
	return r


static func start_rank() -> int:
	table()
	return int(Game.dip.get("power_start", rank_in(table())))
