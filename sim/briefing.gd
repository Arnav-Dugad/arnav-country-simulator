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
