extends Node
## QA fuzz: plays many long games with different player styles and checks every
## month for broken numbers, runaway values and imbalances. Prints one line per
## problem found and a summary per style.
## Run: godot --headless --path . res://tools/qa_fuzz.tscn -- --runs=12 --years=40 --seed=1 [--styles=builder,maxer]

const COUNTRIES := ["IND", "USA", "CHN", "DEU", "NGA", "BRA", "JPN", "EGY", "IDN", "GBR", "MEX", "RUS", "ZAF", "SAU",
	"BGD", "VNM", "ARG", "TUR", "KEN", "NOR", "ISL", "CHL", "PAK", "ETH", "FRA", "KOR", "IRN", "COD", "AUS", "PHL"]
const STYLES := ["passive", "builder", "maxer", "random", "austerity", "spender", "exploiter"]
const DIFFS := ["easy", "standard", "hard"]

var _issues := {}          # kind -> [count, example]
var _summary := {}         # style -> Array of end states
var _run_issues: Array = []
var _trace := false


func _top(c: CountryState, metric: String, n: int) -> String:
	var terms: Array = (c.why.get(metric, []) as Array).duplicate()
	terms.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[1])) > absf(float(b[1])))
	var out: PackedStringArray = []
	for t in terms.slice(0, n):
		out.append("%s %+.1f" % [str(t[0]), float(t[1])])
	return ", ".join(out)


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.split("=", true, 1)[1]
	return d


func _issue(kind: String, detail: String) -> void:
	if not _issues.has(kind):
		_issues[kind] = [0, detail]
	_issues[kind][0] = int(_issues[kind][0]) + 1
	_run_issues.append(kind)


func _bad(x: float) -> bool:
	return is_nan(x) or is_inf(x)


func _run() -> void:
	Settings.tutorial_done = true
	var runs := int(_arg("runs", "12"))
	var years := int(_arg("years", "40"))
	var seed0 := int(_arg("seed", "1"))
	var styles: Array = Array(_arg("styles", ",".join(STYLES)).split(","))
	var r := RandomNumberGenerator.new()
	r.seed = seed0
	var t0 := Time.get_ticks_msec()
	var only := _arg("only", "")
	if only != "":
		# One game, traced: --only=ISO:style:diff
		var p := only.split(":")
		_trace = true
		_play(p[0], p[1], p[2], seed0, years, r)
		_report()
		get_tree().quit()
		return
	for k in runs:
		var iso: String = COUNTRIES[r.randi() % COUNTRIES.size()]
		var style: String = styles[k % styles.size()]
		var diff: String = DIFFS[r.randi() % DIFFS.size()]
		_play(iso, style, diff, seed0 * 1000 + k, years, r)
	print("QA: %d runs in %d s" % [runs, (Time.get_ticks_msec() - t0) / 1000])
	_report()
	get_tree().quit()


func _play(iso: String, style: String, diff: String, sd: int, years: int, r: RandomNumberGenerator) -> void:
	_run_issues = []
	Game.new_game(World.index_of(iso), sd)
	Game.difficulty = diff
	var c := Game.me()
	var start_pc := c.real_gdp_per_capita()
	var ended := ""
	var g_hist: Array = []
	var pinned := {}
	var months := years * 12
	for m in months:
		_act(style, m, r)
		Game.advance_month()
		c = Game.me()
		while Game.director.has_open():
			var ev := Game.director.first()
			var ch := Game.director.recommended(ev) if style != "random" else r.randi() % maxi(ev.choices.size(), 1)
			if _trace:
				print("  M%d event %s -> %d  spend %.1f" % [m, str(ev.get("id", "?")), ch, c.spending_pct])
			Game.director.resolve(ev, ch, true)
		if Meeting.available():
			for p in Meeting.proposals():
				if style in ["maxer", "builder", "random"]:
					Meeting.approve(str(p.id))
			Meeting.done()
		if Game.politics.campaign_open:
			Game.finish_campaign(["economy", "prices"])
		if Game.months_to_election == 12 * Government.term_years(Game.player) and Game.speed == 0:
			Game.continue_after_election(true)
		if not Game.running:
			ended = "ended at month %d" % m
			break
		_check_month(c, m)
		if _trace and m % 24 == 23:
			print("Y%02d g %.1f u %.1f infl %.1f appr %d happy %d stab %d debt %d%% pc×%.2f anchor %.2f trend %.2f" % [m / 12 + 1, c.growth, c.unemployment, c.inflation, roundi(c.approval), roundi(c.happiness), roundi(c.stability), roundi(c.debt_pct()), c.real_gdp_per_capita() / start_pc, c.growth_anchor, c.trend_now()])
			var gs: Array = []
			for o in Game.countries:
				if o != null and o.idx != Game.player:
					gs.append(o.growth)
			gs.sort()
			print("   world cycle %.2f  AI growth median %.1f  p10 %.1f  spend %.1f (base %.1f)" % [Game.markets.world_cycle, gs[gs.size() / 2], gs[gs.size() / 10], c.spending_pct, float(c.base.spending_pct)])
			if _arg("ai", "") != "":
				for ai_iso in _arg("ai", "").split(","):
					var o: CountryState = Game.state(World.index_of(ai_iso))
					print("   AI %s g %.1f anchor %.1f debt %d%% u %.1f infl %.1f spend %.1f/%.1f rev %.1f outlay %.1f int %.1f rate %.1f pens %.1f itax %.1f bal %.1f" % [ai_iso, o.growth, o.growth_anchor, roundi(o.debt_pct()), o.unemployment, o.inflation, o.spending_pct, float(o.base.spending_pct), o.revenue_pct(), o.spending / o.gdp * 100.0, o.interest_cost / o.gdp * 100.0, o.debt_rate, Ageing.pension_cost(o), o.income_tax, o.balance_pct()])
					var oc := o.clone()
					var tr := RandomNumberGenerator.new()
					Simulation.tick(oc, tr, true)
					print("      growth: %s" % _top(oc, "growth", 9))
			for metric in ["growth", "unemployment", "approval", "stability", "happiness"]:
				print("   %s: %s" % [metric, _top(c, metric, 7)])
		g_hist.append(c.growth)
		for key in ["happiness", "stability", "approval"]:
			if float(c.get(key)) >= 99.5:
				pinned[key] = int(pinned.get(key, 0)) + 1
	_check_end(c, start_pc, g_hist, pinned, months, ended)
	var row := {"iso": iso, "diff": diff, "years": Game.months_played / 12.0, "ended": ended,
		"pc_x": c.real_gdp_per_capita() / maxf(start_pc, 1.0), "growth10": _avg(g_hist.slice(maxi(g_hist.size() - 120, 0))),
		"approval": c.approval, "happiness": c.happiness, "stability": c.stability, "debt": c.debt_pct(),
		"infl": c.inflation, "unemp": c.unemployment, "short": Energy.shortage(), "issues": _run_issues.size()}
	if not _summary.has(style):
		_summary[style] = []
	(_summary[style] as Array).append(row)
	print("RUN %-9s %s %-8s %4.1fy pc×%-7.1f g10 %5.1f appr %3d happy %3d stab %3d debt %4d%% infl %5.1f unemp %4.1f power-gap %.2f %s issues %d %s" % [
		style, iso, diff, row.years, row.pc_x, row.growth10, roundi(c.approval), roundi(c.happiness), roundi(c.stability),
		roundi(c.debt_pct()), c.inflation, c.unemployment, Energy.shortage(), ended, _run_issues.size(),
		str(_uniq(_run_issues))])


func _avg(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(a.size(), 1)


func _uniq(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not x in out:
			out.append(x)
	return out


## Player styles.
func _act(style: String, m: int, r: RandomNumberGenerator) -> void:
	var c := Game.me()
	match style:
		"builder":
			_build_best(c)
		"maxer":
			_build_best(c)
			if m % 6 == 0:
				for l in Laws.ALL:
					if Laws.available(c, l) and not Laws.is_active(c, str(l.id)) and Laws.pending_months(c, str(l.id)) == 0 and str(l.id) != "pension_age":
						Capital.add(10.0)
						Laws.start(c, str(l.id))
						break
			if m == 1:
				Capital.add(80.0)
				Health.set_train("double")
				Education.set_fund("world")
				for id in Education.REFORMS:
					Education.reform(str(id))
				for id in Air.POLICIES:
					if Air.available(str(id)) and not Air.has(str(id)):
						Air.toggle(str(id))
				Water.set_drip(true)
				Water.set_recycle(true)
				Food.set_fill(true)
				Food.set_support("generous")
				Digital.set_egov(true)
				Digital.set_cyber(true)
				Digital.launch_id()
				Diaspora.set_fees(true)
				Population.set_family("generous")
				CultureExports.set_fund("big")
			if m % 24 == 0 and Water.can_desal():
				Water.build_desal()
			if m % 36 == 0:
				var w := Regions.weakest()
				if w >= 0:
					Regions.fund(w)
		"random":
			for k in r.randi_range(0, 3):
				_random_action(c, r)
		"austerity":
			c.spending_pct = maxf(c.spending_pct - 0.1, 10.0)
			c.income_tax = minf(c.income_tax + 0.05, 55.0)
		"exploiter":
			# Known abuse patterns, repeated: they must stay bounded.
			_build_best(c)
			if m % 12 == 3:
				for id in Enterprise.FIRMS:
					if Enterprise.st().firms.has(id):
						if Enterprise.owned(str(id)):
							Enterprise.privatise(str(id))
						else:
							Enterprise.nationalise(str(id), true)
			if m % 12 == 9:
				for id in Enterprise.FIRMS:
					if Enterprise.st().firms.has(id) and Enterprise.owned(str(id)):
						Enterprise.privatise(str(id))
			if m % 3 == 0:
				Enterprise.fund().stocks = 1.0
				Enterprise.deposit(c.gdp * 0.02)
				Enterprise.fund().spend = true
			if m % 6 == 0:
				for j in World.playable:
					if j != Game.player and Diplomacy.aid_cooldown(j) == 0 and c.treasury > 0.0:
						Diplomacy.send_aid(j)
					if Diplomacy.can_propose_deal(j):
						Diplomacy.propose_deal(j)
			if m == 2:
				for j in World.playable:
					if j != Game.player and Game.state(j) != null and Game.state(j).gdp < c.gdp * 0.02:
						Tariffs.impose(j)
			Simulation.update_finances(c)
		"spender":
			c.spending_pct = minf(c.spending_pct + 0.1, 55.0)
			c.income_tax = maxf(c.income_tax - 0.05, 5.0)
			_build_best(c)


func _build_best(c: CountryState) -> void:
	for id in Builds.best_value(c, 3):
		var q := maxi(1, mini(int(ceil(Builds.need(c, str(id)) * 0.1)), Builds.max_more(c, str(id))))
		if c.treasury > Builds.unit_price(c, str(id)) * q and Builds.work_load(c) < 1.0:
			Builds.order(c, str(id), q)


func _random_action(c: CountryState, r: RandomNumberGenerator) -> void:
	match r.randi() % 22:
		0: c.income_tax = clampf(c.income_tax + r.randf_range(-3, 3), 0.0, 60.0)
		1: c.corp_tax = clampf(c.corp_tax + r.randf_range(-3, 3), 0.0, 60.0)
		2: c.spending_pct = clampf(c.spending_pct + r.randf_range(-2, 2), 8.0, 60.0)
		3:
			var keys: Array = c.budget.keys()
			var k: String = keys[r.randi() % keys.size()]
			c.set_budget_share(k, clampf(float(c.budget[k]) + r.randf_range(-0.05, 0.05), 0.01, 0.6))
		4:
			c.cb_auto = false
			c.interest_rate = clampf(c.interest_rate + r.randf_range(-1.5, 1.5), Economy.RATE_MIN, Economy.RATE_MAX)
		5:
			var l: Dictionary = Laws.ALL[r.randi() % Laws.ALL.size()]
			if Laws.available(c, l):
				Laws.start(c, str(l.id))
		6:
			var ids: Array = Builds.ALL.keys()
			var id: String = ids[r.randi() % ids.size()]
			if Builds.available(c, id) == "" and Builds.max_more(c, id) > 0:
				Builds.order(c, id, maxi(1, mini(int(ceil(Builds.need(c, id) * r.randf_range(0.02, 0.3))), Builds.max_more(c, id))))
		7: Health.set_train(str(Health.TRAIN[r.randi() % Health.TRAIN.size()]))
		8: Air.toggle(str(Air.POLICIES.keys()[r.randi() % Air.POLICIES.size()]))
		9: Food.set_support(str(Food.SUPPORT[r.randi() % Food.SUPPORT.size()]))
		10: DigitalMoney.set_mode(str(DigitalMoney.MODES[r.randi() % DigitalMoney.MODES.size()]))
		11: DigitalMoney.buy(c.gdp * 0.005)
		12: Fisheries.set_quota(str(Fisheries.QUOTAS[r.randi() % Fisheries.QUOTAS.size()]))
		13: Minerals.survey()
		14:
			var w := Regions.weakest()
			if w >= 0:
				[Regions.fund(w), Regions.grant_autonomy(w), Regions.crack(w)][r.randi() % 3]
		15: Education.set_fund(str(Education.FUNDING[r.randi() % Education.FUNDING.size()]))
		16:
			if Water.can_desal():
				Water.build_desal()
		17: Nuclear.start(r.randf() < 0.5)
		18:
			var t: Dictionary = Treaties.ALL[r.randi() % Treaties.ALL.size()]
			if Treaties.join_blocker(str(t.id)) == "":
				Treaties.start_join(str(t.id))
		19: Population.set_family(str(Population.FAMILY[r.randi() % Population.FAMILY.size()]))
		20:
			var wid: String = Wonders.ALL.keys()[r.randi() % Wonders.ALL.size()]
			Wonders.start(wid)
		21: Digital.set_egov(r.randf() < 0.5)
	Simulation.update_finances(c)


## Every month: broken numbers.
func _check_month(c: CountryState, m: int) -> void:
	for key in ["gdp", "population", "approval", "happiness", "stability", "inflation", "unemployment", "growth", "treasury", "debt", "military", "gini", "interest_rate", "debt_rate"]:
		if _bad(float(c.get(key))):
			_issue("nan:" + key, "month %d" % m)
	for key in ["approval", "happiness", "stability", "military"]:
		var v := float(c.get(key))
		if v < -0.01 or v > 100.01:
			_issue("range:" + key, "%.2f at month %d" % [v, m])
	if c.unemployment < 0.0 or c.unemployment > 60.0:
		_issue("range:unemployment", "%.1f" % c.unemployment)
	if (c.inflation > 200.0 and m > 24) or c.inflation < -15.0:    # some countries start in hyperinflation
		_issue("range:inflation", "%.1f" % c.inflation)
	if c.population <= 0.0:
		_issue("range:population", "%.0f" % c.population)
	var sys := {"unity": Regions.unity(), "learn": Education.score(), "wait": Health.wait(), "uhc": Health.uhc(),
		"pm": Air.pm(), "water": Water.stress(), "food": Food.self_sufficiency(), "fish": Fisheries.stock(),
		"online": Digital.online(), "remit": Diaspora.rate(), "crypto": DigitalMoney.price(), "clock": Nuclear.clock(),
		"capital": Capital.value(), "clean": Corruption.value(c), "life": Outcomes.life(c), "soft": Tourism.soft_power(Game.player),
		"demand": Energy.demand(), "supply": Energy.supply(), "co2": Climate.co2_pc(c), "warming": Climate.warming()}
	for k in sys:
		if _bad(float(sys[k])):
			_issue("nan:" + k, "month %d" % m)
	if float(sys.uhc) > 100.01 or float(sys.online) > 100.01 or float(sys.fish) > 100.01 or float(sys.unity) > 100.01:
		_issue("range:system>100", str(sys))
	if float(sys.life) > 100.0 or float(sys.life) < 30.0:
		_issue("range:life", "%.1f" % float(sys.life))
	if float(sys.wait) < 0.5 or float(sys.wait) > 80.0:
		_issue("range:wait", "%.1f" % float(sys.wait))


## At the end: imbalances.
func _check_end(c: CountryState, start_pc: float, g_hist: Array, pinned: Dictionary, months: int, ended: String) -> void:
	var g10 := _avg(g_hist.slice(maxi(g_hist.size() - 120, 0)))
	if g10 > 9.0:
		_issue("runaway growth (10-yr avg > 9%)", "%.1f" % g10)
	var frontier := 0.0
	for i in World.playable:
		var o: CountryState = Game.state(i)
		if o != null and i != Game.player:
			frontier = maxf(frontier, o.gdp_per_capita())
	if c.gdp_per_capita() > frontier * 3.0:
		_issue("income > 3x the richest other country", "%s vs %s" % [DS.money(c.gdp_per_capita()), DS.money(frontier)])
	if Energy.shortage() > 1.0:
		_issue("unfixable power gap (shortage > 100%)", "%.1f" % Energy.shortage())
	for k in pinned:
		if int(pinned[k]) > months * 0.5:
			_issue("pinned at 100: " + str(k), "%d months" % int(pinned[k]))
	if c.debt_pct() > 400.0:
		_issue("debt > 400%", "%d" % roundi(c.debt_pct()))
	if Air.pm() > 120.0:
		_issue("air > 120 µg", "%d" % roundi(Air.pm()))
	if Climate.co2_pc(c) > 40.0:
		_issue("co2 per person > 40 t", "%.1f" % Climate.co2_pc(c))
	if Population.fertility() > 7.0 or Population.fertility() < 0.6:
		_issue("fertility out of range", "%.2f" % Population.fertility())


func _report() -> void:
	print("==== ISSUES (kind: count, example) ====")
	var keys: Array = _issues.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_issues[a][0]) > int(_issues[b][0]))
	for k in keys:
		print("ISSUE %-45s x%-5d e.g. %s" % [k, int(_issues[k][0]), str(_issues[k][1])])
	print("==== BY STYLE (medians) ====")
	for s in _summary:
		var rows: Array = _summary[s]
		var med := func(key: String) -> float:
			var v: Array = rows.map(func(x: Dictionary) -> float: return float(x[key]))
			v.sort()
			return float(v[v.size() / 2])
		var ended := rows.filter(func(x: Dictionary) -> bool: return str(x.ended) != "").size()
		print("STYLE %-9s n=%d ended %d  pc×%.1f  g10 %.1f  appr %d  happy %d  stab %d  debt %d%%  infl %.1f  unemp %.1f  power-gap %.2f" % [
			s, rows.size(), ended, med.call("pc_x"), med.call("growth10"), roundi(med.call("approval")), roundi(med.call("happiness")),
			roundi(med.call("stability")), roundi(med.call("debt")), med.call("infl"), med.call("unemp"), med.call("short")])
	print("QA DONE")
