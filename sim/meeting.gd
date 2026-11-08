class_name Meeting
extends RefCounted
## The cabinet meeting: every six months your ministers bring a few concrete
## proposals drawn from the state of the country (long hospital waits, a
## restless region, water running short…). Each is one tap to approve or skip,
## so the deeper systems are easy to use without hunting through pages.
## State: Game.dip.meet {last (month of the last meeting), open (month it became available)}.

const EVERY := 6
const EXPIRES := 3


static func st() -> Dictionary:
	if not Game.dip.has("meet"):
		Game.dip["meet"] = {"last": 0, "open": -1}
	return Game.dip.meet


## [{id, post, title, why, cost}] at most one per minister, most useful first.
static func proposals() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var c := Game.me()
	var gdp := c.gdp
	# Health & welfare.
	if Game.dip.has("hlth") and Health.wait() > float(Health.st().wait0) * 1.12 and str(Health.st().train) != "double":
		out.append({"id": "train", "post": "social", "title": "Train more doctors",
			"why": "Hospital waits are up to %d weeks. More medical school places bring new doctors in six years." % roundi(Health.wait()),
			"cost": "%s a year" % DS.money(gdp * 0.04 / 100.0)})
	elif Game.dip.has("edu") and not Education.has_reform("teachers") and (Education.score() < 470.0 or c.share_delta("education") < 0.0):
		out.append({"id": "teachers", "post": "social", "title": "Pay teachers more",
			"why": "Pupils score %d on the international test. Better-paid teachers raise it over the years, and the economy with it." % roundi(Education.score()),
			"cost": "%s a year" % DS.money(gdp * float(Education.REFORMS.teachers.cost) / 100.0)})
	elif Game.dip.has("edu") and Education.drain() > 12.0 and not Education.has_reform("return"):
		out.append({"id": "return", "post": "social", "title": "Talent return grants",
			"why": "%d%% of graduates leave each year. Grants bring them home to work and start companies." % roundi(Education.drain()),
			"cost": "%s a year" % DS.money(gdp * float(Education.REFORMS["return"].cost) / 100.0)})
	# Interior.
	var w := Regions.weakest() if Game.dip.has("reg") else -1
	if w >= 0 and float(Regions.list()[w].loyalty) < 52.0 and Regions.can_fund(Regions.list()[w]):
		var g: Dictionary = Regions.list()[w]
		out.append({"id": "fund:%d" % w, "post": "interior", "title": "A development fund for %s" % (("the " + str(g.name).substr(4)) if str(g.name).begins_with("The ") else ("the " + str(g.name).to_lower())),
			"why": "%s feels left behind (loyalty %d, incomes %d%% of average). Three years of investment help it catch up." % [str(g.name), roundi(float(g.loyalty)), roundi(float(g.wealth) * 100.0)],
			"cost": "%s a year for 3 years" % DS.money(gdp * Economy.REG_FUND_COST / 100.0)})
	elif Game.dip.has("food") and not bool(Food.st().fill) and Food.self_sufficiency() < 80.0 and Food.reserve() < 4.0:
		out.append({"id": "fill", "post": "interior", "title": "Fill the grain reserve",
			"why": "We grow only %d%% of our food. A full reserve protects families when world prices spike." % roundi(Food.self_sufficiency()),
			"cost": "%s a year while filling" % DS.money(gdp * Economy.FOOD_SEC_FILL_COST / 100.0)})
	elif Game.dip.has("air") and Air.pm() >= 30.0:
		for aid in ["stoves", "vehicles", "industry", "burning"]:
			if Air.available(aid) and not Air.has(aid):
				out.append({"id": "air:" + aid, "post": "interior", "title": str(Air.POLICIES[aid].title),
					"why": "The air is %s (%d µg/m³ of fine dust). %s" % [Air.label(Air.pm()).to_lower(), roundi(Air.pm()), str(Air.POLICIES[aid].desc)],
					"cost": "%s a year" % DS.money(gdp * float(Air.POLICIES[aid].cost) / 100.0)})
				break
	# Finance (infrastructure).
	if Game.dip.has("water") and Water.stress() >= 2.8 and Water.can_desal():
		out.append({"id": "desal", "post": "finance", "title": "Build a desalination plant",
			"why": "Water stress is %s of 5 (%s). A plant turns sea water into drinking water." % [String.num(Water.stress(), 1), Water.label(Water.stress()).to_lower()],
			"cost": "%s a year for 3 years" % DS.money(gdp * Economy.WAT_DESAL_COST / 100.0)})
	elif Game.dip.has("water") and Water.stress() >= 2.2 and not bool(Water.st().drip):
		out.append({"id": "drip", "post": "finance", "title": "Drip irrigation for farms",
			"why": "Farms use most of our water. Drip irrigation saves a lot of it.",
			"cost": "%s a year" % DS.money(gdp * Economy.WAT_DRIP_COST / 100.0)})
	elif Game.dip.has("edu") and str(Education.st().fund) == "current" and int(Education.ranks()[0]) > 20 and c.treasury > 0.0:
		out.append({"id": "uni", "post": "finance", "title": "Invest in the universities",
			"why": "Our best university ranks #%d in the world. Better funding brings research and talent." % int(Education.ranks()[0]),
			"cost": "%s a year" % DS.money(gdp * float(Education.FUNDING_INFO.boost.cost) / 100.0)})
	# Foreign affairs.
	var foreign := false
	if Game.dip.has("sea") and SeaLanes.can_escort() and c.trade_openness >= 0.4:
		for id in SeaLanes.st().open:
			if not (SeaLanes.st().escort as Dictionary).has(id):
				out.append({"id": "escort:" + str(id), "post": "foreign", "title": "Send the navy to the %s" % str(SeaLanes.LANES[id].title),
					"why": "Ships are being diverted and freight costs are rising. An escort mission reopens the strait sooner and wins friends.",
					"cost": "%s a year while it lasts" % DS.money(gdp * Economy.SEA_ESCORT_COST / 100.0)})
				foreign = true
				break
	if Game.dip.has("water") and not foreign:
		for rv in Water.my_rivers():
			if not bool(rv.up) and (Water.st().dams as Dictionary).has(rv.id) and not (Water.st().treaty as Dictionary).has(rv.id) and Capital.can(10.0):
				out.append({"id": "treaty:" + str(rv.id), "post": "foreign", "title": "A water treaty on %s" % str(rv.title),
					"why": "A dam upstream is cutting our share. A treaty halves the loss.", "cost": "10 political capital"})
				break
	return out


static func available() -> bool:
	if not Game.has_game():
		return false
	var s := st()
	if int(s.open) >= 0:
		if Game.months_played - int(s.open) > EXPIRES:
			s.open = -1
			s.last = Game.months_played
			return false
		return true
	if Game.months_played >= 12 and Game.months_played - int(s.last) >= EVERY and not proposals().is_empty():
		s.open = Game.months_played
		return true
	return false


static func done() -> void:
	st().open = -1
	st().last = Game.months_played


static func approve(id: String) -> void:
	var p := id.split(":")
	match p[0]:
		"train":
			Health.set_train("more" if str(Health.st().train) == "current" else "double")
		"teachers", "return":
			Education.reform(p[0])
		"uni":
			Education.set_fund("boost")
		"fund":
			Regions.fund(int(p[1]))
		"fill":
			Food.set_fill(true)
		"desal":
			Water.build_desal()
		"drip":
			Water.set_drip(true)
		"treaty":
			Water.apply(id)
		"escort":
			SeaLanes.set_escort(p[1], true)
		"air":
			if not Air.has(p[1]):
				Air.toggle(p[1])
	Simulation.update_finances(Game.me())
