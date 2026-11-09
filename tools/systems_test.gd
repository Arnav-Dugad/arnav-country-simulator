extends Node
## Headless checks for the society, resource and power systems: real-data seeds,
## save/load round trips, and guards against free exploits found in review.
## Run: godot --headless --path . res://tools/systems_test.tscn

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL  ", what)


func _run() -> void:
	Settings.tutorial_done = true
	# Real-data seeds.
	Game.new_game(World.index_of("USA"), 7)
	_check(Nuclear.warheads(Game.player) > 4000, "US starts with its arsenal")
	_check(int(Education.ranks()[0]) <= 3, "US has a top-3 university")
	Game.new_game(World.index_of("IND"), 7)
	_check(Air.pm() > 40.0, "India's air starts unhealthy")
	_check(Water.stress() > 3.5, "India's water stress starts high")
	_check(not Water.my_rivers().is_empty(), "India shares rivers")
	_check(Regions.list().size() == 5, "India has five regions")

	# Exploit guards.
	var a0 := float(Game.me().shocks.approval)
	for k in 10:
		Air.toggle("stoves")
	_check(float(Game.me().shocks.approval) - a0 <= 1.01, "clean-air toggles give approval once")
	var c0 := Corruption.value(Game.me())
	for k in 10:
		Digital.set_egov(true)
		Digital.set_egov(false)
	_check(Corruption.value(Game.me()) - c0 <= 3.01, "e-government boosts clean government once")
	Game.new_game(World.index_of("CHL"), 7)
	var us := World.index_of("USA")
	var r0 := Game.relations[us]
	for k in 10:
		Minerals.set_deal("copper", "west")
		Minerals.set_deal("copper", "east")
	Minerals.set_deal("copper", "west")
	_check(absf(Game.relations[us] - r0 - Economy.MIN_DEAL_FRIEND) < 0.01, "flipping mineral deals farms no goodwill")
	Game.new_game(World.index_of("IRN"), 7)
	Capital.add(50.0)
	Nuclear.start(true)
	Nuclear.abandon()
	Nuclear.apply("press")
	_check(not Nuclear.building(), "a stale nuclear decision does not restart the programme")
	Game.new_game(World.index_of("ESP"), 7)
	var p0 := Game.me().population
	var sh := float(Regions.list()[1].share) + float(Regions.list()[2].share)
	Regions._secede(1, 60.0)
	Regions._secede(2, 60.0)
	_check(absf(Game.me().population / p0 - (1.0 - sh)) < 0.005, "two secessions remove the right population")

	# Power adds up: building far beyond the old "coverage" still adds supply.
	Game.new_game(World.index_of("IND"), 7)
	var sb: Dictionary = Game.me().builds.solar_farm
	var s1 := Energy.supply()
	sb.n = float(sb.n0) + Builds.need_at_start(Game.me(), "solar_farm") * 4.0
	var s2 := Energy.supply()
	sb.n = float(sb.n0) + Builds.need_at_start(Game.me(), "solar_farm") * 8.0
	var s3 := Energy.supply()
	_check(s3 - s2 > (s2 - s1) * 0.9, "every power plant keeps adding supply (no saturation)")

	# Every key the game saves through Settings must be a declared setting (else it is silently dropped).
	Settings.set_value("sections_open", {"Test/x": true})
	_check(bool((Settings.get_value("sections_open", {}) as Dictionary).get("Test/x", false)), "folded-section choices are remembered")
	Settings.set_value("sections_open", {})

	# Long, cheat-heavy saves: values come back into range on load and stay there.
	Game.new_game(World.index_of("IND"), 7)
	var dd: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))
	var me: Dictionary = dd.countries.IND
	me.growth_anchor = 53.0
	me.trend = 46.0
	me.stability = 104.0
	Game.load_dict(dd)
	_check(Game.me().growth_anchor <= Economy.ANCHOR_MAX and Game.me().trend <= Economy.TREND_MAX, "runaway growth paths are capped on load")
	_check(Game.me().stability <= 100.0, "stability is capped on load")
	for k in 3:
		GameEvents.apply_effects({"stability": 30.0, "happiness": 30.0}, -1)
		Game.advance_month()
	_check(Game.me().stability <= 100.0 and Game.me().happiness <= 100.0, "events can't push stability or happiness past 100")

	# Save / load round trip, then keep playing.
	Game.new_game(World.index_of("EGY"), 7)
	Capital.add(80.0)
	Regions.fund(1)
	Water.build_desal()
	Food.set_fill(true)
	DigitalMoney.buy(Game.me().gdp * 0.001)
	for m in 14:
		Game.advance_month()
		while Game.director.has_open():
			var ev := Game.director.first()
			Game.director.resolve(ev, Game.director.recommended(ev), true)
	var before := [Regions.unity(), Education.score(), Health.wait(), Water.stress(), Food.reserve(), DigitalMoney.holding(), Air.pm()]
	var d: Variant = JSON.parse_string(JSON.stringify(Game.to_dict()))
	Game.load_dict(d)
	var after := [Regions.unity(), Education.score(), Health.wait(), Water.stress(), Food.reserve(), DigitalMoney.holding(), Air.pm()]
	for k in before.size():
		_check(absf(float(before[k]) - float(after[k])) < 0.001, "save round trip keeps value %d" % k)
	for m in 24:
		Game.advance_month()
		while Game.director.has_open():
			var ev := Game.director.first()
			Game.director.resolve(ev, Game.director.recommended(ev), true)
		if Meeting.available():
			for p in Meeting.proposals():
				Meeting.approve(str(p.id))
			Meeting.done()
	_check(VoxPop.quotes(3).size() == 3, "three citizen quotes")
	_check(not ComingUp.items().is_empty(), "something is coming up")
	_check(PowerIndex.rank() >= 1, "power rank exists")
	print("SYSTEMS TEST OK (0 failures)" if _fails == 0 else "SYSTEMS TEST FAILED (%d)" % _fails)
	get_tree().quit()
