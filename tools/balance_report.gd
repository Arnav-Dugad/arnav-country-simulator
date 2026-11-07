extends Node
## Balance report: plays many bot games per difficulty and summarises how they go,
## so tuning (sim/economy.gd, sim/difficulty.gd) is driven by data.
## The bot plays like a sensible, not perfect, player: lets the central bank work,
## trims big deficits, sweetens voters before elections, builds a project now and
## then, and takes the cabinet's recommended choice on every event.
##
## Run (CI: .github/workflows/balance.yml):
##   godot --headless --path . res://tools/balance_report.tscn -- --games=100 --months=96 --out=report.md

var _over := false
var _reason := ""
var _elections := 0
var _won := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var games := int(args.get("games", "100"))
	var months := int(args.get("months", "96"))
	var out_path := str(args.get("out", ""))
	Settings.decisions = "inbox"
	Game.election_held.connect(func(r: Dictionary) -> void:
		_elections += 1
		_won += 1 if r.won else 0
		Game.continue_after_election(r.won))
	Game.army_warning.connect(func() -> void: Game.resume_after_modal())
	Game.game_over.connect(func(s: Dictionary) -> void:
		_over = true
		_reason = str(s.reason))
	var md := PackedStringArray()
	md.append("# Balance report")
	md.append("")
	md.append("%d games per difficulty, %d months each, random playable countries, sensible bot." % [games, months])
	md.append("")
	md.append("| Difficulty | Survived | Elections won | Ends (reason: n) | Avg growth %/yr | Debt change pts | Approval end | Defaults | Events/yr |")
	md.append("|---|---|---|---|---|---|---|---|---|")
	var event_counts := {}
	var t0 := Time.get_ticks_msec()
	for level in Difficulty.LEVELS:
		# Same countries and seeds at every level, so levels compare like for like.
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000
		var survived := 0
		var reasons := {}
		var growth_sum := 0.0
		var debt_sum := 0.0
		var appr_sum := 0.0
		var defaults := 0
		var events := 0
		var el := 0
		var won := 0
		for g in games:
			var country: int = World.playable[rng.randi() % World.playable.size()]
			_over = false
			_reason = ""
			_elections = 0
			_won = 0
			Game.new_game(country, rng.randi(), level)
			var gdp0 := Game.me().gdp
			var debt0 := Game.me().debt_pct()
			var crises := [0]
			var on_crisis := func(i: int) -> void:
				if i == Game.player:
					crises[0] += 1
			Game.debt_crisis.connect(on_crisis)
			var log0 := 0
			for m in months:
				if _over:
					break
				_bot(rng)
				Game.advance_month()
				while Game.director.has_open():
					var ev := Game.director.first()
					event_counts[str(ev.id)] = int(event_counts.get(str(ev.id), 0)) + 1
					Game.director.resolve(ev, Game.director.recommended(ev))
				if Game.speed == 0 and not _over:
					Game.set_speed(1)
			Game.debt_crisis.disconnect(on_crisis)
			events += Game.event_log.size() - log0
			el += _elections
			won += _won
			defaults += crises[0]
			if not _over:
				survived += 1
			else:
				reasons[_reason] = int(reasons.get(_reason, 0)) + 1
			var c := Game.me()
			var yrs := maxf(Game.months_played / 12.0, 0.5)
			growth_sum += (pow(maxf(c.real_gdp_per_capita() * c.population, 1.0) / maxf(gdp0, 1.0), 1.0 / yrs) - 1.0) * 100.0
			debt_sum += c.debt_pct() - debt0
			appr_sum += c.approval
			Game.end_session()
		var reason_txt := ", ".join(reasons.keys().map(func(k: String) -> String: return "%s: %d" % [k, reasons[k]])) if not reasons.is_empty() else "none"
		md.append("| %s | %d%% | %s | %s | %.2f | %+.1f | %.0f | %d | %.1f |" % [Difficulty.TITLES[level],
			roundi(100.0 * survived / games), ("%d%% of %d" % [roundi(100.0 * won / maxf(el, 1)), el]) if el > 0 else "n/a",
			reason_txt, growth_sum / games, debt_sum / games, appr_sum / games, defaults,
			events / (games * months / 12.0)])
		print("balance: %s done (%d ms)" % [level, Time.get_ticks_msec() - t0])
	md.append("")
	md.append("## Event frequency (all difficulties)")
	md.append("")
	var ids := event_counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(event_counts[a]) > int(event_counts[b]))
	md.append("| Event | Times |")
	md.append("|---|---|")
	for id in ids:
		md.append("| %s | %d |" % [id, int(event_counts[id])])
	var text := "\n".join(md)
	print(text)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(text + "\n")
	print("BALANCE REPORT OK (%d ms)" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


## A sensible player: one small adjustment a quarter.
func _bot(rng: RandomNumberGenerator) -> void:
	if Game.month % 3 != 0:
		return
	var c := Game.me()
	var deficit := -c.balance_pct()
	var allowed := maxf(4.0, float(c.base.get("deficit_pct", 3.0)) + 1.0)
	var elections := Government.has_elections(Game.player)
	var m_left := Game.politics.months_left()
	if deficit > allowed or c.debt_pct() > 130.0:
		c.spending_pct = maxf(c.spending_pct - 0.4, 8.0)
		if not elections or m_left > 18:
			c.income_tax = minf(c.income_tax + 0.3, 55.0)
	elif deficit < allowed - 3.0 and c.approval < 55.0:
		c.spending_pct = minf(c.spending_pct + 0.3, 60.0)
	if elections and m_left <= 18 and c.approval < 50.0:
		c.income_tax = maxf(c.income_tax - 0.4, 5.0)
		c.set_budget_share("health", float(c.budget.health) + 0.01)
	if not elections and c.stability < 35.0:
		c.set_budget_share("military", float(c.budget.military) + 0.01)
	# Build something affordable now and then.
	if Projects.count_building(c) == 0 and deficit < allowed and rng.randf() < 0.3:
		var options := Projects.ALL.filter(func(p: Dictionary) -> bool:
			return not c.projects.has(p.id) and Projects.blocked_reason(c, p) == "")
		if not options.is_empty():
			Projects.start(c, str(options[rng.randi() % options.size()].id))
	Simulation.update_finances(c)
