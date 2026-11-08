class_name Corruption
extends RefCounted
## How clean government is, 0 (deeply corrupt) to 100 (very clean), shown like
## a perceptions index. Every country starts from its real World Bank "Control
## of Corruption" score (WGI, -2.5 .. +2.5). It moves slowly toward a target set
## by laws (anti-corruption agency, press freedom, free elections), stability,
## and anti-corruption drives you launch (one every DRIVE_GAP months).
## Cleaner government lifts growth (investors trust it), cuts project overruns
## and makes scandals rarer. Constants in sim/economy.gd (CORR_*).
## The player's value lives in Game.dip.clean {value, drives: [month, …]}.

const E = preload("res://sim/economy.gd")

const LAW_CLEAN := {"anti_corruption": 12.0, "press_freedom": 6.0, "free_elections": 5.0}
const DRIVE_GAP := 24
const DRIVE_BOOST := 7.0          # target points per drive (fades over DRIVE_YEARS)
const DRIVE_YEARS := 8.0


static func start(i: int) -> float:
	return clampf(50.0 + 20.0 * World.stat(i, "corruption_wgi", 0.0), 5.0, 95.0)


static func _st() -> Dictionary:
	if not Game.dip.has("clean"):
		Game.dip["clean"] = {"value": start(Game.player), "drives": []}
	return Game.dip.clean


## The current score (the player's moves; AI countries keep their real score).
static func value(c: CountryState) -> float:
	if c == null:
		return 50.0
	if c.idx != Game.player or not Game.has_game():
		return start(c.idx)
	return float(_st().value)


static func target(c: CountryState) -> float:
	var t := start(c.idx)
	for id in LAW_CLEAN:
		var on := Laws.is_active(c, id)
		if on != c.laws_start.has(id):
			t += float(LAW_CLEAN[id]) * (1.0 if on else -1.0)
	t += E.CORR_STABILITY * (c.stability - float(c.base.get("stability", c.stability)))
	if c.idx == Game.player and Game.dip.has("media"):
		t += Media.clean_offset()
	for m in _st().drives:
		var age := (Game.months_played - int(m)) / 12.0
		t += DRIVE_BOOST * clampf(1.0 - age / DRIVE_YEARS, 0.0, 1.0)
	return clampf(t, 2.0, 98.0)


static func monthly() -> void:
	var st := _st()
	st.value = float(st.value) + (target(Game.me()) - float(st.value)) * E.CORR_ADJUST


static func change(c: CountryState) -> float:
	return value(c) - start(c.idx)


## Growth from cleaner (or dirtier) government than at the start.
static func growth_effect(c: CountryState) -> float:
	return E.CORR_GROWTH * change(c) / 10.0


## Multiplier on scandal odds (1 = as at the start).
static func scandal_mult(c: CountryState) -> float:
	return clampf(1.0 - change(c) / 40.0, 0.3, 1.8)


## A one-off nudge to the score (e.g. prosecuting a bribery ring).
static func boost(points: float) -> void:
	var st := _st()
	st.value = clampf(float(st.value) + points, 2.0, 98.0)


static func drive_wait() -> int:
	var d: Array = _st().drives
	if d.is_empty():
		return 0
	return maxi(0, int(d[d.size() - 1]) + DRIVE_GAP - Game.months_played)


## Launch an anti-corruption drive: the elite pushes back now, it pays off later.
static func launch_drive() -> void:
	(_st().drives as Array).append(Game.months_played)
	var c := Game.me()
	c.shocks.approval = float(c.shocks.approval) - 1.0
	c.shocks.stability = float(c.shocks.stability) - 1.5
	Press.apply_cred(3.0)
	Game.add_feed("You launch an anti-corruption drive. Officials are nervous.", "gavel", "accent")
	Game.add_milestone("Launched an anti-corruption drive", "gavel", "accent")


static func label(v: float) -> String:
	if v >= 75.0:
		return "very clean"
	if v >= 60.0:
		return "fairly clean"
	if v >= 45.0:
		return "some corruption"
	if v >= 30.0:
		return "widespread corruption"
	return "deeply corrupt"
