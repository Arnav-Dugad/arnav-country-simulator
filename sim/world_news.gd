class_name WorldNews
extends RefCounted
## The rest of the world lives too: AI elections and leader changes (which shift
## relations with you), recessions, booms and defaults. Only countries that
## matter to the player are reported (big economies, neighbours, partners).

const MAX_ITEMS := 40
const ELECTION_CYCLE := 48       # months between AI elections
const NEW_LEADER_SWING := 18.0   # max relation change when a new leader takes office


static func is_notable(i: int) -> bool:
	if i == Game.player:
		return false
	if Diplomacy.has_deal(i) or Diplomacy.has_alliance(i) or Diplomacy.is_sanctioning(i) or Diplomacy.sanctions_me(i):
		return true
	if i in World.map.neighbours[Game.player]:
		return true
	var c: CountryState = Game.state(i)
	return c != null and c.gdp > 8e11   # roughly the world's top ~20 economies


## Called once per AI country per month (after its tick).
static func monthly(i: int, c: CountryState, prev_growth: float, rng: RandomNumberGenerator) -> void:
	if not World.is_playable(i):
		return
	var offset := absi(hash(World.map.iso3[i])) % ELECTION_CYCLE
	if (Game.months_played + offset) % ELECTION_CYCLE == 0 and Game.months_played > 0:
		_election(i, c, rng)
	if not is_notable(i):
		return
	if prev_growth >= -0.3 and c.growth < -0.3:
		add(i, "%s slips into recession" % World.map.names[i], "trending-down", false)
	elif prev_growth <= 5.5 and c.growth > 5.5 and c.gdp > 2e11:
		add(i, "%s's economy is booming" % World.map.names[i], "trending-up", true)


static func _election(i: int, c: CountryState, rng: RandomNumberGenerator) -> void:
	var p_keep := clampf((c.approval - 35.0) / 20.0, 0.1, 0.9)
	if rng.randf() < p_keep:
		c.approval = minf(c.approval + 3.0, 100.0)
		return
	# New leader: a fresh start at home and a new attitude abroad.
	c.approval = 55.0
	c.shocks.stability = float(c.shocks.stability) + 3.0
	var swing := rng.randf_range(-NEW_LEADER_SWING, NEW_LEADER_SWING)
	Game.relations[i] = clampf(Game.relations[i] + swing, -100.0, 100.0)
	var key := str(i)
	Game.dip.baseline[key] = clampf(float(Game.dip.baseline.get(key, Game.relations[i])) + swing * 0.6, -100.0, 100.0)
	if is_notable(i):
		var tone := "warmer toward you" if swing > 5.0 else ("cooler toward you" if swing < -5.0 else "")
		add(i, "%s elects a new leader%s" % [World.map.names[i], ", " + tone if tone != "" else ""], "vote", swing >= 0.0)


static func defaulted(i: int) -> void:
	if i != Game.player and is_notable(i):
		add(i, "%s defaults on its debt" % World.map.names[i], "alert", false)


static func add(i: int, text: String, icon: String, good: bool) -> void:
	Game.news.push_front({"date": Game.date_text(), "country": World.map.iso3[i], "text": text,
		"icon": icon, "good": good})
	if Game.news.size() > MAX_ITEMS:
		Game.news.pop_back()
	Game.world_news.emit(Game.news[0])
