class_name Blocs
extends RefCounted
## Voter groups: who supports you and why. Five groups sized from each country's
## real demographics (World Bank: over-65 share, urban share). Each group feels
## your policies differently (taxes, jobs, prices, pensions, schools, laws…);
## their moods are then shifted together so the weighted average always equals
## your overall approval: a breakdown of the number the simulation already
## computes, so it never changes the balance of the game.

const IDS := ["workers", "business", "youth", "retirees", "rural"]
const INFO := {
	"workers": {"title": "Workers", "icon": "hammer", "color": "accent"},
	"business": {"title": "Business", "icon": "building-2", "color": "gold"},
	"youth": {"title": "Young people", "icon": "graduation-cap", "color": "purple"},
	"retirees": {"title": "Retirees", "icon": "heart", "color": "teal"},
	"rural": {"title": "Rural voters", "icon": "tractor", "color": "green"},
}
## Laws each group loves (+) or hates (-): approval points within the group.
const LAW_FX := {
	"min_wage": {"workers": 6.0, "business": -6.0, "youth": 3.0},
	"wealth_tax": {"workers": 3.0, "business": -8.0},
	"privatisation": {"business": 6.0, "workers": -5.0},
	"export_zones": {"business": 5.0, "rural": -2.0},
	"skilled_visas": {"business": 5.0, "youth": 2.0, "rural": -3.0, "retirees": -2.0},
	"universal_health": {"retirees": 5.0, "workers": 4.0, "business": -2.0},
	"free_university": {"youth": 8.0, "business": -1.0},
	"parental_leave": {"youth": 4.0, "workers": 2.0, "business": -2.0},
	"basic_income": {"workers": 4.0, "youth": 4.0, "business": -5.0},
	"pension_age": {"retirees": -10.0, "business": 4.0, "youth": 1.0},
	"carbon_tax": {"youth": 5.0, "rural": -6.0, "business": -3.0},
	"coal_phaseout": {"youth": 5.0, "workers": -3.0, "rural": -2.0},
	"ev_subsidy": {"youth": 3.0, "rural": -1.0},
	"anti_corruption": {"business": 2.0, "youth": 3.0},
	"press_freedom": {"youth": 3.0},
	"border_control": {"retirees": 4.0, "rural": 3.0, "youth": -3.0},
	"police_reform": {"youth": 4.0, "retirees": -1.0},
	"free_elections": {"youth": 6.0, "workers": 2.0},
	"four_day_week": {"workers": 6.0, "youth": 4.0, "business": -6.0},
	"sugar_tax": {"retirees": 1.0, "workers": -2.0, "business": -2.0},
	"rent_control": {"youth": 6.0, "workers": 3.0, "business": -5.0, "retirees": -1.0},
	"plastic_ban": {"youth": 4.0, "business": -2.0},
	"ai_safety": {"retirees": 2.0, "workers": 3.0, "business": -3.0},
}


## Share of the population in each group (sums to 1).
static func sizes(i: int) -> Dictionary:
	var old := clampf(World.stat(i, "age65_pct", 10.0) / 100.0, 0.02, 0.32)
	var rural := clampf(1.0 - World.stat(i, "urban_pct", 55.0) / 100.0, 0.05, 0.8) * 0.75
	var young := clampf(0.12 + (0.2 - old) * 0.6, 0.1, 0.3)
	var business := 0.08
	var workers := maxf(1.0 - old - rural - young - business, 0.15)
	var tot := old + rural + young + business + workers
	return {"workers": workers / tot, "business": business / tot, "youth": young / tot,
		"retirees": old / tot, "rural": rural / tot}


## Raw feelings per group (before shifting to match overall approval):
## [[reason, points], …] per group.
static func reasons(c: CountryState) -> Dictionary:
	var b: Dictionary = c.base
	var d_inc := c.income_tax - float(b.income_tax)
	var d_corp := c.corp_tax - float(b.corp_tax)
	var d_u := c.unemployment - float(b.unemployment)
	var d_pi := clampf(c.inflation - float(b.inflation), -10.0, 30.0)
	var d_welfare := c.share_delta("welfare")
	var d_health := c.share_delta("health")
	var d_edu := c.share_delta("education")
	var d_infra := c.share_delta("infrastructure")
	var g_gap := c.growth - c.growth_anchor
	var out := {}
	for k in IDS:
		out[k] = []
	_add(out, "workers", "Jobs", -2.5 * d_u)
	_add(out, "workers", "Income tax", -1.2 * d_inc)
	_add(out, "workers", "Prices", -0.6 * d_pi)
	_add(out, "workers", "Welfare spending", 0.5 * d_welfare)
	_add(out, "business", "Business tax", -1.6 * d_corp)
	_add(out, "business", "Growth", 3.0 * g_gap)
	_add(out, "business", "Infrastructure", 0.4 * d_infra)
	_add(out, "business", "Income tax", -0.4 * d_inc)
	_add(out, "youth", "Jobs", -2.0 * d_u)
	_add(out, "youth", "Schools & universities", 0.8 * d_edu)
	_add(out, "youth", "Prices", -0.4 * d_pi)
	_add(out, "retirees", "Prices", -1.2 * d_pi)
	_add(out, "retirees", "Healthcare", 0.9 * d_health)
	_add(out, "retirees", "Welfare & pensions", 0.7 * d_welfare)
	_add(out, "rural", "Prices", -0.8 * d_pi)
	_add(out, "rural", "Roads & services", 0.6 * d_infra)
	_add(out, "rural", "Trade openness", -6.0 * (c.trade_openness - float(b.trade)))
	for id in c.laws:
		var now := Laws.is_active(c, id)
		var then := c.laws_start.has(id)
		if now == then or not LAW_FX.has(id):
			continue
		var sign := 1.0 if now else -1.0
		var t := Laws.title_of(c, Laws.law(id)) if now else "Scrapping " + Laws.title_of(c, Laws.law(id)).to_lower()
		for g in LAW_FX[id]:
			_add(out, g, t, float(LAW_FX[id][g]) * sign)
	# Laws repealed from the starting set count too.
	for id in c.laws_start:
		if not c.laws.has(id) and LAW_FX.has(id):
			for g in LAW_FX[id]:
				_add(out, g, "Scrapping " + Laws.title_of(c, Laws.law(id)).to_lower(), -float(LAW_FX[id][g]))
	if Projects.is_done(c, "rural_roads") and not bool(c.projects.get("rural_roads", {}).get("start", false)):
		_add(out, "rural", "New rural roads", 4.0)
	if c.idx == Game.player and Game.has_game():
		_add(out, "rural", "Trade war", Tariffs.rural_hit())
		_add(out, "workers", "Tariff protection", 1.5 * minf(Tariffs.count(), 2))
		_add(out, "business", "Tariffs", -2.0 * minf(Tariffs.count(), 2))
	# The opposition's heartland leans away from you.
	if c.idx == Game.player and Opposition.active():
		var opp := Opposition.leader()
		for g in opp.base:
			_add(out, str(g), "Lean to the %s" % str(opp.party), float(opp.base[g]))
	if Projects.is_done(c, "housing") and not bool(c.projects.get("housing", {}).get("start", false)):
		_add(out, "youth", "Affordable homes", 4.0)
	if c.idx == Game.player and Game.dip.has("const"):
		_add(out, "youth", "Voting age", Constitution.fx("youth"))
	if c.idx == Game.player and Game.dip.has("manif"):
		for g in IDS:
			_add(out, str(g), "Your campaign rally", Manifesto.rally_bonus(str(g)))
	return out


static func _add(out: Dictionary, g: String, reason: String, v: float) -> void:
	if absf(v) >= 0.3:
		out[g].append([reason, v])


## Support per group (0..100), shifted so the weighted mean equals approval.
static func support(c: CountryState) -> Dictionary:
	var sz := sizes(c.idx)
	var why := reasons(c)
	var raw := {}
	var mean := 0.0
	for g in IDS:
		var s := 0.0
		for r in why[g]:
			s += float(r[1])
		raw[g] = s
		mean += s * float(sz[g])
	var out := {}
	for g in IDS:
		out[g] = clampf(c.approval + float(raw[g]) - mean, 2.0, 98.0)
	return out


## The biggest reason a group feels the way it does ("" if nothing stands out).
static func top_reason(c: CountryState, g: String) -> String:
	var best := ""
	var bv := 0.0
	for r in reasons(c)[g]:
		if absf(float(r[1])) > absf(bv):
			bv = float(r[1])
			best = str(r[0])
	if best == "":
		return "No strong feelings"
	if best.begins_with("Lean to"):
		return best
	var mood := "Pleased with"
	if bv < 0.0:
		mood = "Angry about" if float(support(c)[g]) < 40.0 else "Worried about"
	var what := best.to_lower()
	# "Prices" pleasing someone means prices are calming down.
	if bv > 0.0 and what == "prices":
		what = "calmer prices"
	elif bv > 0.0 and what == "jobs":
		what = "more jobs"
	return "%s %s" % [mood, what]


## For law cards: who would like / dislike passing (or repealing) this law.
static func law_chips(c: CountryState, id: String, repeal: bool) -> Array:
	var out: Array = []
	var fx: Dictionary = LAW_FX.get(id, {})
	for g in fx:
		var v := float(fx[g]) * (-1.0 if repeal else 1.0)
		out.append([str(INFO[g].title), v > 0.0, absf(v)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	return out


static func color(g: String) -> Color:
	return {"accent": DS.ACCENT_SOFT, "gold": DS.GOLD, "purple": DS.PURPLE, "teal": DS.TEAL, "green": DS.GREEN}.get(
		str(INFO[g].color), DS.ACCENT)


# ------------------------------------------------------------ referendums ---
## Put a law to a public vote (free democracies only). The yes share comes from
## each voter group's reaction to the law (LAW_FX) weighted by its size, plus a
## little of your overall popularity and some luck. A win enacts it at once;
## a loss shelves it for REFERENDUM_BLOCK months and costs some approval.
const REFERENDUM_COOLDOWN := 12
const REFERENDUM_BLOCK := 24


static func can_referendum(id: String) -> String:
	if not Government.is_free(Game.player):
		return "Only democracies hold referendums"
	var last := int(Game.dip.get("last_referendum", -100))
	var wait := last + REFERENDUM_COOLDOWN - Game.months_played
	if wait > 0:
		return "Next referendum possible in %d months" % wait
	var blocked := int(Game.dip.get("ref_blocked", {}).get(id, -100))
	if Game.months_played < blocked:
		return "Voters said no; you can try again in %d months" % (blocked - Game.months_played)
	return ""


static func referendum_yes(id: String) -> float:
	var c := Game.me()
	var sz := sizes(c.idx)
	var yes := 50.0 + (c.approval - 50.0) * 0.35
	for g in LAW_FX.get(id, {}):
		yes += float(sz[g]) * float(LAW_FX[id][g]) * 3.5
	return clampf(yes + Game.rng.randf_range(-3.0, 3.0), 15.0, 85.0)


static func hold_referendum(id: String) -> Dictionary:
	var c := Game.me()
	var yes := referendum_yes(id)
	Game.dip["last_referendum"] = Game.months_played
	var won := yes >= 50.0
	var title := Laws.title_of(c, Laws.law(id))
	if won:
		c.laws[id] = {"state": "active"}
		c.laws_ver += 1
		c.shocks.approval = float(c.shocks.approval) + 1.0
		Game.law_finished.emit(id, false)
		Game.add_milestone("Referendum: %s approved with %.0f%%" % [title, yes], "vote", "gold")
	else:
		if not Game.dip.has("ref_blocked"):
			Game.dip["ref_blocked"] = {}
		Game.dip.ref_blocked[id] = Game.months_played + REFERENDUM_BLOCK
		c.shocks.approval = float(c.shocks.approval) - 2.0
		Game.add_milestone("Referendum: %s rejected (%.0f%% yes)" % [title, yes], "vote", "red")
	return {"yes": yes, "won": won, "title": title}
