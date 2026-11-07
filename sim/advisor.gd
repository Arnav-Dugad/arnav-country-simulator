class_name Advisor
extends RefCounted
## Plain-language advice: the most important things for the player to do right now.
## Each item: {level: 0 tip / 1 watch / 2 urgent, title, detail, page, icon}.


static func advice(c: CountryState) -> Array:
	var out: Array = []
	var b: Dictionary = c.base
	var deficit := -c.balance_pct()
	var m_left := Game.months_to_election

	if c.inflation > maxf(6.0, float(b.inflation) + 2.0) and c.inflation > 4.0:
		out.append(_item(2 if c.inflation > 12.0 else 1, "Prices are rising fast (%s)" % DS.pct(c.inflation),
			"Raise the interest rate a little to cool inflation. It slows growth for a while.", "economy", "flame"))
	if c.unemployment > float(b.unemployment) + 2.0:
		out.append(_item(1, "Jobs are disappearing (%s jobless)" % DS.pct(c.unemployment),
			"Lower the interest rate or spend a bit more to get people back to work.", "economy", "users"))
	if c.approval < 45.0 and m_left <= 18:
		out.append(_item(2, "Election in %d months, approval %s" % [m_left, DS.pct(c.approval, 0)],
			"Win back voters: avoid income-tax rises, fund healthcare and welfare, keep prices calm.", "budget", "vote"))
	elif c.approval < 40.0:
		out.append(_item(1, "Approval is low (%s)" % DS.pct(c.approval, 0),
			"People back leaders who keep them happy. Check what is pulling approval down.", "economy", "vote"))
	if deficit > maxf(6.0, float(b.get("deficit_pct", 3.0)) + 2.0):
		out.append(_item(1 if c.debt_pct() < 110.0 else 2, "Big budget deficit (%s of GDP)" % DS.pct(deficit),
			"Trim spending or raise taxes gently. Large deficits add to debt and inflation.", "budget", "wallet"))
	if c.debt_pct() > maxf(120.0, float(b.debt_pct) + 10.0):
		out.append(_item(2, "Debt is getting dangerous (%s of GDP)" % DS.pct(c.debt_pct(), 0),
			"Above about 100% markets may panic. Run a smaller deficit for a few years.", "budget", "alert"))
	if c.stability < 30.0:
		out.append(_item(2, "Unrest is growing (stability %d)" % int(c.stability),
			"Raise approval and happiness, and bring unemployment down.", "economy", "shield"))
	if c.happiness < float(b.happiness) - 5.0:
		out.append(_item(1, "People are unhappier than when you started",
			"More healthcare, welfare or education spending usually helps.", "budget", "heart"))
	if c.growth < c.trend - 1.5 and c.inflation < 4.0:
		out.append(_item(1, "The economy is sluggish (%s growth)" % DS.pct(c.growth),
			"Cut the interest rate, or invest in infrastructure and research.", "economy", "trending-down"))
	if c.trade_deals == 0 and m_left > 6:
		out.append(_item(0, "Sign a trade deal",
			"Trade deals add growth and goodwill. Friendly countries are most likely to say yes.", "diplomacy", "handshake"))
	if out.is_empty() or out.all(func(x: Dictionary) -> bool: return int(x.level) == 0):
		out.append(_item(0, "Things are steady",
			"A good moment to invest in research or education for long-term growth.", "budget", "sparkles"))
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.level) > int(y.level))
	return out


## 2 = thriving, 1 = okay, 0 = struggling
static func health(c: CountryState) -> int:
	var urgent := 0
	var watch := 0
	for a in advice(c):
		urgent += 1 if int(a.level) == 2 else 0
		watch += 1 if int(a.level) == 1 else 0
	if urgent > 0 or watch >= 3:
		return 0
	return 1 if watch > 0 else 2


const HEALTH_TEXT := ["Struggling", "Doing okay", "Thriving"]


static func _item(level: int, title: String, detail: String, page: String, icon: String) -> Dictionary:
	return {"level": level, "title": title, "detail": detail, "page": page, "icon": icon}
