extends Node
## Headless sanity test for the economy: plays N years with the player making no
## changes, prints a few countries yearly, and flags unbelievable outcomes.
## Run (as a scene so autoloads exist):
##   godot --headless --path . res://tools/sim_test.tscn -- --years=25 --player=USA

@onready var _world: Node = World
@onready var _game: Node = Game


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var years := int(args.get("years", "25"))
	var player: int = _world.index_of(args.get("player", "USA"))
	_game.new_game(player, 42)
	var watch := ["USA", "IND", "CHN", "DEU", "JPN", "ARG", "VEN", "NGA", "BRA", "TUR"]
	var t0 := Time.get_ticks_usec()
	for y in years:
		for m in 12:
			_game.advance_month()
		if y % 5 == 4 or y == 0:
			print("--- year %d" % _game.year)
			for code in watch:
				_print_row(code)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("Simulated %d months for %d countries in %.0f ms (%.2f ms/month)" % [years * 12,
		_game.countries.filter(func(c: Variant) -> bool: return c != null).size(), ms, ms / (years * 12)])
	var bad := 0
	for c in _game.countries:
		if c == null:
			continue
		var issues := []
		for f in ["gdp", "growth", "inflation", "unemployment", "approval", "debt"]:
			if is_nan(float(c.get(f))) or is_inf(float(c.get(f))):
				issues.append("%s is NaN/inf" % f)
		if c.inflation > 60.0:
			issues.append("inflation %.0f" % c.inflation)
		if c.debt_pct() > 300.0:
			issues.append("debt %.0f%%" % c.debt_pct())
		if c.growth < -10.0 or c.growth > 15.0:
			issues.append("growth %.1f" % c.growth)
		var gdp_ratio: float = c.gdp_per_capita() / float(c.base.gdp_pc)
		if gdp_ratio < 0.5 or gdp_ratio > 8.0:
			issues.append("gdp/pc x%.2f" % gdp_ratio)
		if not issues.is_empty():
			bad += 1
			print("FLAG %s: %s" % [_world.map.iso3[c.idx], ", ".join(issues)])
	print("Flagged %d countries" % bad)
	get_tree().quit()


func _print_row(code: String) -> void:
	var i: int = _world.index_of(code)
	var c: CountryState = _game.countries[i]
	if c == null:
		return
	print("%s gdp %s g %5.1f u %5.1f pi %6.1f i %5.2f debt %5.0f%% bal %5.1f%% appr %4.0f hap %4.0f stab %4.0f mil %4.0f" % [
		code, DS.money(c.gdp), c.growth, c.unemployment, c.inflation, c.interest_rate, c.debt_pct(),
		c.balance_pct(), c.approval, c.happiness, c.stability, c.military])
