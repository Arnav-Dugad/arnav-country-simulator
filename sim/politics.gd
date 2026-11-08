class_name Politics
extends RefCounted
## The player's hold on power, by system of government (see Government):
## elections and campaigns in democracies, leadership reviews in one-party states,
## the army's patience in military governments, and unrest everywhere.
## Thresholds live in sim/economy.gd (UNREST_*, COUP_*, REVIEW_*).

const E = preload("res://sim/economy.gd")

var kind_override := ""          # set when the player reforms the system (free_elections law)
var months_to_election := 48     # also used as "months to the next review" without elections
var campaign_year := 0           # absolute month of the election already campaigned for
var campaign_open := false       # campaign offered, not yet launched (the cabinet launches it if you don't)
var elections_won := 0
var reviews_passed := 0
var low_stability_months := 0
var unrest_months := 0
var army_warned := false
var start_military_share := 0.0
# Term limits (see Government.TERM_LIMITS).
var leader_from := 0             # elections_won when the current leader took office
var limit_asked := false         # the "last term" choice was offered this term
var limit_lifted := false        # the constitution was changed: no limit any more
var successor := false           # your party runs a new candidate at the next election
var retiring := false            # you step down at the next election


func reset(player: int) -> void:
	kind_override = ""
	elections_won = 0
	reviews_passed = 0
	campaign_year = 0
	campaign_open = false
	low_stability_months = 0
	unrest_months = 0
	army_warned = false
	start_military_share = float(Game.me().budget.get("military", 0.0)) if Game.me() else 0.0
	leader_from = 0
	limit_asked = false
	limit_lifted = false
	successor = false
	retiring = false
	months_to_election = _cycle_months(player)


func _cycle_months(i: int) -> int:
	if Government.has_elections(i):
		return 12 * Government.term_years(i)
	var r := Government.review_years(i)
	return 12 * r if r > 0 else 0


## Months until the next election or review (0 = none scheduled).
func months_left() -> int:
	return months_to_election if _cycle_months(Game.player) > 0 else 0


## Absolute year of the next election/review, or 0 when there is none.
func next_year() -> int:
	if months_left() <= 0:
		return 0
	return Game.year + int((Game.month - 1 + months_to_election) / 12)


## Terms the current leader has won since taking office (fatigue, term limits).
func terms_served() -> int:
	return maxi(elections_won - leader_from, 0)


## Voter fatigue at the next election: the leader's own terms, or for a new
## candidate the "fresh face" penalty plus half the party's years in power
## (voters tire of parties too, not just leaders).
func fatigue() -> float:
	var sev := Difficulty.severity()
	if successor:
		return E.SUCCESSOR_PENALTY * sev + 0.5 * E.ELECTION_FATIGUE * sev * elections_won
	return E.ELECTION_FATIGUE * sev * terms_served()


func term_limit() -> int:
	var ct := Constitution.term_limit()
	if ct >= 0:
		return ct
	return 0 if limit_lifted else Government.term_limit(Game.player)


## The current term is the last one the constitution allows.
func last_term() -> bool:
	var l := term_limit()
	return l > 0 and terms_served() + 1 >= l


func amend_chance() -> float:
	return clampf((Game.me().approval - E.AMEND_BASE) / E.AMEND_SPAN, E.AMEND_MIN, E.AMEND_MAX)


## The player's answer to the term-limit question: "retire", "successor" or "amend".
func term_choice(what: String) -> void:
	match what:
		"retire":
			retiring = true
			Game.add_feed("You will step down at the %d election" % next_year(), "flag", "gold")
		"successor":
			successor = true
			Game.add_feed("Your party will run a new candidate in %d" % next_year(), "users", "accent")
		"amend":
			if Game.rng.randf() < amend_chance():
				limit_lifted = true
				Game.add_feed("Term limits scrapped: you can run again", "landmark", "orange")
				Game.add_milestone("Changed the constitution to run again", "landmark", "orange")
			else:
				successor = true
				Game.me().shocks.approval = float(Game.me().shocks.approval) - 3.0
				Game.add_feed("The courts block your bid for another term. Your party will run a new candidate.", "landmark", "red")


## Top-bar caption: "Election 2030", "Party Congress 2031", "No elections".
func milestone_text() -> String:
	var i := Game.player
	if Government.has_elections(i):
		if months_to_election <= 0:
			return "Election this month"
		if retiring:
			return "You step down %d" % next_year()
		if successor:
			return "Successor vote %d" % next_year()
		if months_to_election <= 24:
			return "Vote %d · polls %d%%" % [next_year(), roundi(poll())]
		return "Election %d" % next_year()
	if Government.review_years(i) > 0:
		return "%s %d" % [Government.review_name(i), next_year()]
	return Government.system_name(i)


## Today's opinion poll: the vote share you'd get now (no luck, with voter fatigue).
func poll() -> float:
	var i := Game.player
	var a := Game.me().approval - fatigue()
	if Government.elections(i) == "managed":
		return clampf(30.0 + a * 0.65, 20.0, 88.0)
	return clampf(50.0 + (a - 42.5) * 0.9, 22.0, 78.0)


## Called once a month after the simulation. Returns what happens next:
##   ""                       nothing
##   "campaign"               an election is 3 months away
##   "election"               election day (Game holds it)
##   "review"                 leadership review today
##   "army_warning"           the military is unhappy (first time)
##   "end:<reason>"           the player has lost power
func monthly() -> String:
	var i := Game.player
	var c := Game.me()
	# Collapse of order ends any government.
	var floor_st := minf(E.COLLAPSE_STABILITY, float(c.base.get("stability", 50.0)) - E.COLLAPSE_HEADROOM)
	low_stability_months = low_stability_months + 1 if c.stability < floor_st else 0
	if low_stability_months >= E.COLLAPSE_MONTHS:
		return "end:collapse"
	if not Government.has_elections(i):
		var unrest_st := minf(E.UNREST_STABILITY, float(c.base.get("stability", 50.0)) - E.COLLAPSE_HEADROOM)
		unrest_months = unrest_months + 1 if c.stability < unrest_st and c.approval < E.UNREST_SUPPORT else 0
		if unrest_months >= E.UNREST_MONTHS:
			return "end:revolution"
		if Government.army_rules(i):
			var r := coup_risk()
			if r > 0.0:
				if not army_warned:
					army_warned = true
					return "army_warning"
				if Game.rng.randf() < r:
					return "end:coup"
			elif army_warned and r <= 0.0:
				army_warned = false
	if _cycle_months(i) <= 0:
		return ""
	months_to_election -= 1
	if months_to_election <= 0:
		if retiring and not Game.god_mode:
			Achievements.unlock("handover")
			return "end:retired"
		return "election" if Government.has_elections(i) else "review"
	if Government.has_elections(i) and not limit_asked and not successor and not retiring \
			and months_to_election <= E.TERM_LIMIT_NOTICE and last_term():
		limit_asked = true
		return "term_limit"
	if campaign_open and months_to_election <= 1:
		return "campaign_auto"
	# Two months out: a live TV debate with the opposition leader (free elections).
	if months_to_election == 2 and Government.elections(i) == "free" and not retiring:
		return "debate"
	var election_at := Game.months_played + months_to_election
	if Government.has_elections(i) and months_to_election == Campaign.MONTHS_BEFORE and campaign_year != election_at:
		campaign_year = election_at
		campaign_open = true
		return "campaign"
	return ""


## Monthly chance that the army removes the player (military governments only).
func coup_risk() -> float:
	var c := Game.me()
	var share := float(c.budget.get("military", 0.0))
	var cut := maxf(0.0, 1.0 - share / maxf(start_military_share, 0.01))   # 0.3 = budget cut by 30 %
	var risk := 0.0
	if cut > E.COUP_BUDGET_CUT:
		risk += (cut - E.COUP_BUDGET_CUT) * E.COUP_PER_CUT
	# Measured against where this country started: fragile states aren't doomed on day one.
	var floor_st := minf(E.COUP_STABILITY, float(c.base.get("stability", 50.0)) - E.COLLAPSE_HEADROOM)
	if c.stability < floor_st:
		risk += (floor_st - c.stability) * E.COUP_PER_STABILITY
	return clampf(risk, 0.0, 0.25)


## Election day. Returns {won, share, year, approval, managed}.
func hold_election() -> Dictionary:
	var i := Game.player
	var a := Game.me().approval
	# Voters tire of long-serving leaders; a new candidate is fresh but less known.
	var tired := fatigue()
	var was_successor := successor
	var won := Game.rng.randf() < Government.win_chance(i, a - tired)
	var share := Government.vote_share(i, a - tired, Game.rng)
	share = maxf(share, 50.6) if won else minf(share, 49.4)
	months_to_election = _cycle_months(i)
	var managed := Government.elections(i) == "managed"
	successor = false
	retiring = false
	limit_asked = false
	if won:
		elections_won += 1
		if was_successor:
			leader_from = elections_won       # the new leader's first term starts now
		Game.me().shocks.approval += 3.0     # honeymoon
		if managed and a < E.DISPUTED_BELOW:
			# A tilted win with little real support: protests and frowns abroad.
			Game.me().shocks.stability -= 6.0
			Diplomacy.democracies_react(-4.0)
	return {"won": won, "share": share, "year": Game.year, "approval": a, "managed": managed,
		"terms": maxi(terms_served() - (1 if won else 0), 0), "successor": was_successor}


## Leadership review in systems without elections (Party Congress, …).
func hold_review() -> Dictionary:
	var c := Game.me()
	months_to_election = _cycle_months(Game.player)
	var kept := c.approval >= E.REVIEW_SUPPORT or c.stability >= E.REVIEW_STABILITY
	if kept:
		reviews_passed += 1
		c.shocks.stability += 3.0
	return {"kept": kept, "name": Government.review_name(Game.player), "year": Game.year,
		"approval": c.approval, "stability": c.stability}


## The free_elections reform has passed: the country becomes a democracy with a
## first election in 12 months.
func become_democracy() -> void:
	kind_override = Government.REFORM_TO
	months_to_election = 12
	campaign_year = 0
	army_warned = false
	unrest_months = 0


func to_dict() -> Dictionary:
	return {"kind_override": kind_override, "months_to_election": months_to_election,
		"campaign_year": campaign_year, "elections_won": elections_won, "reviews_passed": reviews_passed,
		"low_stability_months": low_stability_months, "unrest_months": unrest_months,
		"army_warned": army_warned, "start_military_share": start_military_share, "campaign_open": campaign_open,
		"leader_from": leader_from, "limit_asked": limit_asked, "limit_lifted": limit_lifted,
		"successor": successor, "retiring": retiring}


func load_dict(d: Dictionary) -> void:
	kind_override = str(d.get("kind_override", ""))
	months_to_election = int(d.get("months_to_election", 48))
	campaign_year = int(d.get("campaign_year", 0))
	elections_won = int(d.get("elections_won", 0))
	reviews_passed = int(d.get("reviews_passed", 0))
	low_stability_months = int(d.get("low_stability_months", 0))
	unrest_months = int(d.get("unrest_months", 0))
	army_warned = bool(d.get("army_warned", false))
	start_military_share = float(d.get("start_military_share", 0.0))
	campaign_open = bool(d.get("campaign_open", false))
	leader_from = int(d.get("leader_from", 0))
	limit_asked = bool(d.get("limit_asked", false))
	limit_lifted = bool(d.get("limit_lifted", false))
	successor = bool(d.get("successor", false))
	retiring = bool(d.get("retiring", false))
