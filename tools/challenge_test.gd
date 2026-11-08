extends Node
## Challenge balance test: for each challenge, a bot plays the obvious strategy and
## must reach the goal in time (guards against balance changes making goals impossible).
## Run: godot --headless --path . res://tools/challenge_test.tscn
func _ready() -> void:
	var missed := 0
	var seeds := [1, 2, 3]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.trim_prefix("--seeds=").split(",")).map(func(x: String) -> int: return int(x))
	for sd in seeds:
		for ch in Challenges.ALL:
			Game.new_challenge(str(ch.id), sd)
			Game.me().cb_auto = false   # the test plays a hands-on leader
			var c := Game.me()
			var won_at := -1
			for m in int(ch.years) * 12:
				match str(ch.id):
					"arg_inflation":
						c.interest_rate = clampf(Economy.neutral_rate(c.core_inflation) + 6.0, 0, 40)
						c.spending_pct = maxf(c.spending_pct - 0.05, 15.0)
					"ind_10t":
						c.set_budget_share("infrastructure", 0.2)
						c.set_budget_share("research", 0.1)
						c.trade_openness = 0.9
					"zaf_jobs":
						c.interest_rate = maxf(Economy.neutral_rate(c.core_inflation) - 1.5, 0.0)
						c.set_budget_share("education", 0.25)
						c.trade_openness = 0.85
						if m == 0:
							Laws.start(c, "export_zones")
							Laws.start(c, "free_university")
					"ita_budget", "grc_debt":
						c.spending_pct = maxf(c.spending_pct - 0.08, 25.0)
						c.income_tax = minf(c.income_tax + 0.03, 45.0)
					"nga_stability":
						c.set_budget_share("health", 0.25)
						c.set_budget_share("welfare", 0.25)
						c.set_budget_share("military", 0.15)
						if m == 0:
							Laws.start(c, "anti_corruption")
							Laws.start(c, "police_reform")
					"pol_coal", "aus_green":
						if m == 0:
							for id in ["coal_phaseout", "carbon_tax", "ev_subsidy"]:
								if not Laws.is_active(c, id):
									Laws.start(c, id)
							for id in ["solar", "wind"]:
								Projects.start(c, id)
						if m == 30:
							Projects.start(c, "rail")
					"bih_stay":
						c.set_budget_share("health", 0.22)
						c.set_budget_share("education", 0.22)
						c.trade_openness = 0.85
						if m == 0:
							Laws.start(c, "skilled_visas")
							Laws.start(c, "anti_corruption")
							Laws.start(c, "export_zones")
				Game.advance_month()
				if not Game.pending_event.is_empty():
					Game.resolve_event(0)
				if Game.months_to_election == 12 * Government.term_years(Game.player) and Game.speed == 0:
					Game.continue_after_election(true)
				if Game.politics.campaign_open:
					Game.finish_campaign(["economy", "prices"])
				if Game.challenge.get("state", "") == "won" and won_at < 0:
					won_at = Game.months_played
			missed += 0 if won_at > 0 else 1
			print("seed %d %-15s %s  final %s  %s" % [sd, ch.id, "WON at month %d" % won_at if won_at > 0 else "missed",
				Challenges.format_value(ch, Challenges.current_value(ch)), "(running)" if Game.running else "(game over)"])
	print("CHALLENGE TEST %s (%d missed)" % ["OK" if missed == 0 else "FAILED", missed])
	get_tree().quit()
