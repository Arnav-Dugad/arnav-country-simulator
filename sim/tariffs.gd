class_name Tariffs
extends RefCounted
## Trade wars. Put tariffs on one country's goods: your factories get a little
## shelter and the treasury collects duties, but prices rise and they may hit
## back. How hard depends on how big they are next to you and how open your
## economy is. They retaliate when they're big enough, proud enough
## (nationalists, hawks) or already cold toward you; traders rarely do.
## Evidence: the 2018-19 US-China tariffs were passed almost fully to US
## consumer prices (Amiti, Redding & Weinstein 2019; Fajgelbaum et al. 2020),
## and retaliation hit exporters, farmers above all.
## State: Game.dip.tariffs {idx: start month}, Game.dip.tariffs_back {idx: month}.

const RELATION_LOSS := 12.0
const LIFT_GAIN := 6.0
## Per unit of "weight" (their GDP vs yours x your trade openness, capped):
const INFLATION := 0.5        # points of inflation from dearer imports
const REVENUE := 0.15         # % of GDP collected in duties
const SHELTER_JOBS := -0.08   # unemployment points (protected factories)
const RETALIATION_GROWTH := -0.35   # growth points when they hit back
const RETALIATION_RURAL := -4.0     # rural voters' support (farm exports hit first)


static func _d() -> Dictionary:
	if not Game.dip.has("tariffs"):
		Game.dip["tariffs"] = {}
		Game.dip["tariffs_back"] = {}
	return Game.dip


static func has(i: int) -> bool:
	return _d().tariffs.has(str(i))


static func retaliating(i: int) -> bool:
	return _d().tariffs_back.has(str(i))


static func count() -> int:
	return _d().tariffs.size()


## How much trade with this country matters to you (0.05 .. 1.5).
static func weight(i: int) -> float:
	var them: CountryState = Game.state(i)
	if them == null:
		return 0.0
	return clampf(them.gdp / maxf(Game.me().gdp, 1.0), 0.0, 1.5) * clampf(Game.me().trade_openness * 1.6, 0.3, 1.4)


## Chance they hit back (0..1).
static func retaliation_chance(i: int) -> float:
	var ld := Leaders.leader(i)
	var p := 0.35 + 0.35 * clampf(weight(i), 0.0, 1.0)
	match str(ld.personality):
		"nationalist", "hawk":
			p += 0.25
		"trader":
			p -= 0.2
		"peacemaker":
			p -= 0.1
	if Game.relations[i] < -20.0:
		p += 0.15
	return clampf(p, 0.05, 0.95)


## Puts tariffs on country i. Returns true if they retaliate.
static func impose(i: int) -> bool:
	if has(i):
		return false
	_d().tariffs[str(i)] = Game.months_played
	Diplomacy.change_relation(i, -RELATION_LOSS)
	if Diplomacy.has_deal(i):
		Diplomacy.cancel_deal(i)
	var back := Game.rng.randf() < retaliation_chance(i)
	if back:
		_d().tariffs_back[str(i)] = Game.months_played
		var ld := Leaders.leader(i)
		Game.add_feed("%s hits back with tariffs on %s's exports" % [World.map.names[i], World.map.names[Game.player]],
			"ban", "red")
		Game.feed[0]["face"] = str(ld.portrait)
	Simulation.update_finances(Game.me())
	return back


static func lift(i: int) -> void:
	if not has(i):
		return
	_d().tariffs.erase(str(i))
	if _d().tariffs_back.has(str(i)):
		_d().tariffs_back.erase(str(i))
		Game.add_feed("%s drops its counter-tariffs" % World.map.names[i], "handshake", "green")
	Diplomacy.change_relation(i, LIFT_GAIN)
	Simulation.update_finances(Game.me())


## Target offsets for the player: {growth, inflation, unemployment, revenue}.
static func modifiers(c: CountryState) -> Dictionary:
	var out := {"growth": 0.0, "inflation": 0.0, "unemployment": 0.0, "revenue": 0.0}
	if c.idx != Game.player or not Game.dip.has("tariffs"):
		return out
	for k in Game.dip.tariffs:
		var i := int(k)
		var w := weight(i)
		out.inflation += INFLATION * w
		out.revenue += REVENUE * w
		out.unemployment += SHELTER_JOBS * w
		if retaliating(i):
			out.growth += RETALIATION_GROWTH * w
	return out


## Rural voters lose most when others retaliate (see Blocs).
static func rural_hit() -> float:
	if not Game.dip.has("tariffs_back"):
		return 0.0
	var h := 0.0
	for k in Game.dip.tariffs_back:
		h += RETALIATION_RURAL * clampf(weight(int(k)), 0.2, 1.0)
	return h
