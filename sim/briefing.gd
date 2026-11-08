class_name Briefing
extends RefCounted
## Turns monthly changes into calm, newspaper-style headlines. Each headline key
## fires once (Game.headlines_seen) so the feed never repeats itself.

const GDP_MILESTONES := [1e11, 2.5e11, 5e11, 1e12, 2e12, 3e12, 5e12, 1e13, 2e13, 3e13, 5e13, 1e14]


## Returns at most one headline {key, text, icon, good} for this month, or {}.
static func headline() -> Dictionary:
	var c := Game.me()
	var h: Dictionary = Game.history
	var seen: Dictionary = Game.headlines_seen
	var cands: Array = []
	var gdp: PackedFloat32Array = h.get("gdp", PackedFloat32Array())
	if gdp.size() >= 2:
		for m in GDP_MILESTONES:
			if gdp[gdp.size() - 2] < m and c.gdp >= m:
				cands.append(_h("gdp_%d" % int(m / 1e9), "GDP passes %s" % DS.money(m, 0), "trending-up", true))
	var infl: PackedFloat32Array = h.get("inflation", PackedFloat32Array())
	if infl.size() > 12:
		var lowest := INF
		for i in infl.size() - 1:
			lowest = minf(lowest, infl[i])
		if c.inflation < lowest - 0.05 and c.inflation < 4.0:
			cands.append(_h("infl_low_%d" % int(c.inflation * 2), "Inflation falls to %s, the lowest since %d" % [
				DS.pct(c.inflation), Game.START_YEAR], "flame", true))
	if infl.size() >= 2 and infl[infl.size() - 2] < 10.0 and c.inflation >= 10.0:
		cands.append(_h("infl_10_%d" % Game.year, "Inflation hits double digits", "flame", false))
	var appr: PackedFloat32Array = h.get("approval", PackedFloat32Array())
	if appr.size() >= 2:
		if appr[appr.size() - 2] < 50.0 and c.approval >= 50.0:
			cands.append(_h("appr_up_%d" % Game.year, "Majority now backs your government", "vote", true))
		elif appr[appr.size() - 2] >= 50.0 and c.approval < 50.0:
			cands.append(_h("appr_down_%d" % Game.year, "Support slips below half", "vote", false))
	var debt: PackedFloat32Array = h.get("debt_pct", PackedFloat32Array())
	if debt.size() >= 2 and debt[debt.size() - 2] < 100.0 and c.debt_pct() >= 100.0:
		cands.append(_h("debt_100_%d" % Game.year, "Debt passes the size of the whole economy", "alert", false))
	var u: PackedFloat32Array = h.get("unemployment", PackedFloat32Array())
	if u.size() > 7 and c.unemployment < u[u.size() - 7] - 0.8:
		cands.append(_h("jobs_%d_%d" % [Game.year, Game.month / 4], "Jobs boom: unemployment down to %s" % DS.pct(c.unemployment), "users", true))
	var r := c.rating()
	if Game.last_rating == "":
		Game.last_rating = r
	elif r != Game.last_rating:
		var up := Economy.RATING_GRADES.map(func(g: Array) -> String: return str(g[1])).find(r) \
			< Economy.RATING_GRADES.map(func(g: Array) -> String: return str(g[1])).find(Game.last_rating)
		Game.last_rating = r
		cands.push_front(_h("rating_%s_%d_%d" % [r, Game.year, Game.month],
			"Credit rating %s to %s" % ["upgraded" if up else "downgraded", r], "landmark", up))
	# Records against the real world: the best this country has done in modern data.
	# (Starting values are close to records for most; beating them means a lot.)
	var happy: PackedFloat32Array = h.get("happiness", PackedFloat32Array())
	if happy.size() > 24:
		var best_h := -INF
		for k in happy.size() - 1:
			best_h = maxf(best_h, happy[k])
		if c.happiness > best_h + 0.3 and c.happiness > float(c.base.happiness) + 4.0:
			cands.append(_h("happy_rec_%d" % int(c.happiness), "People are the happiest they've been in your time in office", "heart", true))
	if u.size() > 24 and c.unemployment < float(c.base.unemployment) - 1.0:
		var low_u := INF
		for k in u.size() - 1:
			low_u = minf(low_u, u[k])
		if c.unemployment < low_u - 0.05:
			cands.append(_h("u_rec_%d" % int(c.unemployment * 4.0), "Unemployment at a record low: %s" % DS.pct(c.unemployment), "users", true))
	var m0 := Migration.start_rate(Game.player)
	var m := Migration.rate(c)
	if m0 < -0.5 and m > 0.3:
		cands.append(_h("mig_in", "More people now move to %s than leave" % World.the_name(Game.player), "plane-landing", true))
	elif m0 > 0.5 and m < -0.3:
		cands.append(_h("mig_out", "More people now leave %s than arrive" % World.the_name(Game.player), "plane-takeoff", false))
	for deg in [1.5, 1.75, 2.0]:
		if Climate.warming() >= deg and Climate.start_warming() < deg:
			cands.append(_h("warm_%d" % int(deg * 100.0), "The world passes %s °C of warming" % String.num(deg, 2 if deg == 1.75 else 1),
				"thermometer-sun", false))
	# The newer systems: universities, schools, the clock, unity, hospital waits.
	if Game.dip.has("edu"):
		var rk := int(Education.ranks()[0])
		var rk0 := int(Education.ranks(true)[0])
		for top in [100, 10, 1]:
			if rk <= top and rk0 > top:
				cands.append(_h("uni_top%d" % top, ("%s is now the world's best university" if top == 1 else "%s enters the world top " + str(top)) % Education.UNIS[0], "graduation-cap", true))
		for lvl in [450, 500, 550]:
			if Education.score() >= lvl and float(Education.st().score0) < lvl:
				cands.append(_h("learn_%d" % lvl, "Pupils' test scores pass %d" % lvl, "school", true))
	if Game.dip.has("nuke"):
		for sec in [60, 120]:
			if Nuclear.clock() < sec and Economy.NUC_CLOCK_START >= sec:
				cands.append(_h("clock_%d" % sec, "The Doomsday Clock moves to %d seconds to midnight" % roundi(Nuclear.clock()), "clock", false))
			if Nuclear.clock() >= sec and Economy.NUC_CLOCK_START < sec:
				cands.append(_h("clock_up_%d" % sec, "The Doomsday Clock moves back past %d seconds" % sec, "clock", true))
	if Game.dip.has("reg") and Regions.unity() < 55.0:
		cands.append(_h("unity_low_%d" % Game.year, "Polls show the country drifting apart", "map-pin", false))
	if Game.dip.has("hlth") and Health.wait() <= float(Health.st().wait0) * 0.6:
		cands.append(_h("waits_cut", "Hospital waits fall to %d weeks" % roundi(Health.wait()), "hourglass", true))
	if Government.has_elections(Game.player) and Game.months_to_election == 6:
		cands.append(_h("elect6_%d" % Game.year, "Six months until the election", "vote", true))
	for cand in cands:
		if not seen.has(cand.key):
			seen[cand.key] = true
			return cand
	return {}


## Summary of the last 12 months for the Year in Review card.
static func year_review() -> Dictionary:
	var h: Dictionary = Game.history
	var n: int = (h.get("gdp", PackedFloat32Array()) as PackedFloat32Array).size()
	if n < 13:
		return {}
	var rows: Array = []
	for spec in [["gdp", "GDP", true, "money"], ["growth", "Growth", true, "pct"], ["inflation", "Inflation", false, "pct"],
			["unemployment", "Unemployment", false, "pct"], ["approval", "Approval", true, "pct"],
			["debt_pct", "Debt", false, "pct"]]:
		var arr: PackedFloat32Array = h[spec[0]]
		rows.append({"label": spec[1], "from": arr[n - 13], "to": arr[n - 1], "good_up": spec[2], "kind": spec[3]})
	var score := 0
	for r in rows:
		var up: bool = float(r.to) > float(r.from)
		score += 1 if up == bool(r.good_up) else -1
	var title := "A strong year" if score >= 3 else ("A mixed year" if score >= -1 else "A tough year")
	return {"year": Game.year - 1, "title": title, "rows": rows}


static func _h(key: String, text: String, icon: String, good: bool) -> Dictionary:
	return {"key": key, "text": text, "icon": icon, "good": good}
