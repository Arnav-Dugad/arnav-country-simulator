extends Node
## Headless bot playthrough: random policies, diplomacy, event choices, elections,
## save/load round-trips. Exercises every gameplay code path to catch runtime errors.
## Run: godot --headless --path . res://tools/playtest.tscn -- --years=30 --player=BRA --seed=7

var _events := 0
var _elections := 0
var _over := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args.get("seed", "7"))
	Game.new_game(World.index_of(args.get("player", "BRA")), rng.seed)
	Game.event_started.connect(func(_e: Dictionary) -> void: _events += 1)
	Game.election_held.connect(func(r: Dictionary) -> void:
		_elections += 1
		print("  election %d: won=%s share=%.1f approval=%.1f" % [r.year, r.won, r.share, r.approval])
		if r.won:
			Game.continue_after_election(true)
		else:
			_over = true)
	Game.game_over.connect(func(s: Dictionary) -> void:
		_over = true
		print("  game over: ", s.reason))
	var seen_ids := {}
	var years := int(args.get("years", "30"))
	for m in years * 12:
		if _over:
			break
		Game.advance_month()
		if not Game.pending_event.is_empty():
			seen_ids[Game.pending_event.id] = true
			Game.resolve_event(rng.randi() % Game.pending_event.choices.size())
		if m % 5 == 0:
			_random_policy(rng)
		if m % 7 == 0:
			_random_diplomacy(rng)
		if m % 9 == 0:
			var l: Dictionary = Laws.ALL[rng.randi() % Laws.ALL.size()]
			if Laws.pending_months(Game.me(), l.id) > 0:
				Laws.cancel(Game.me(), l.id)
			else:
				Laws.start(Game.me(), l.id)
		if m % 61 == 0:  # save/load round-trip
			var d := Game.to_dict()
			var txt := JSON.stringify(d)
			assert(Game.load_dict(JSON.parse_string(txt)), "load_dict failed")
	# Force every event once so all effect handlers run.
	for e in GameEvents.EVENTS:
		var ev := GameEvents.instance(e, World.playable[rng.randi() % World.playable.size()])
		Game.trigger_event(ev)
		Game.resolve_event(rng.randi() % ev.choices.size())
	var c := Game.me()
	print("Played %d months: %d events (%d kinds), %d elections. GDP %s, debt %.0f%%, approval %.0f, stab %.0f" % [
		Game.months_played, _events, seen_ids.size(), _elections, DS.money(c.gdp), c.debt_pct(), c.approval, c.stability])
	print("Diplomacy: ", Diplomacy.summary())
	print("Laws in force: ", Game.me().laws.keys(), "  modifiers: ", Laws.modifiers(Game.me()))
	print("PLAYTEST OK")
	get_tree().quit()


func _random_policy(rng: RandomNumberGenerator) -> void:
	var c := Game.me()
	c.income_tax = clampf(c.income_tax + rng.randf_range(-2, 2), 0, 60)
	c.corp_tax = clampf(c.corp_tax + rng.randf_range(-2, 2), 0, 50)
	c.interest_rate = clampf(c.interest_rate + rng.randf_range(-0.5, 0.5), 0, 40)
	c.spending_pct = clampf(c.spending_pct + rng.randf_range(-1, 1), 8, 60)
	c.trade_openness = clampf(c.trade_openness + rng.randf_range(-0.1, 0.1), 0, 1)
	var k: String = CountryState.BUDGET_KEYS[rng.randi() % 6]
	c.set_budget_share(k, c.budget[k] + rng.randf_range(-0.03, 0.03))


func _random_diplomacy(rng: RandomNumberGenerator) -> void:
	var i: int = World.playable[rng.randi() % World.playable.size()]
	if i == Game.player:
		return
	match rng.randi() % 6:
		0: Diplomacy.propose_deal(i)
		1: Diplomacy.propose_alliance(i)
		2: Diplomacy.send_aid(i)
		3: Diplomacy.sanction(i)
		4: Diplomacy.lift_sanction(i)
		5: Diplomacy.cancel_deal(i)
