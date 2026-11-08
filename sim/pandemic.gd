class_name Pandemic
extends RefCounted
## Pandemics. Rarely (about once in a long career) a new disease appears in one
## country and spreads along trade and travel routes. Each country runs a simple
## outbreak model on shares of its people: susceptible -> infected -> immune,
## plus vaccinated. Your tools:
##   lockdown   none / partial / full: slows spread a lot, costs growth, jobs and
##              patience (fatigue builds the longer it lasts)
##   masks      cheap, modest effect
##   borders    keeps new cases out, hurts trade and tourism
##   testing    trace and isolate: costs money, slows spread
##   vaccine    a world vaccine arrives after a year or more; with mRNA research
##              you can make your own much sooner. Vaccination speed follows your
##              clinics and hospitals.
## Hospitals: when infections outrun capacity (health builds), more people die.
## Other countries respond on their own. The pandemic ends when cases fade
## worldwide. State: Game.dip.pandemic. Constants in sim/economy.gd (PAN_*).

const E = preload("res://sim/economy.gd")

const NAMES := ["Meridian flu", "Kestrel virus", "Grey fever", "Halcyon syndrome", "Novara virus", "Ashfall flu"]

const LOCKDOWN := ["None", "Partial", "Full"]


static func st() -> Dictionary:
	if not Game.dip.has("pandemic"):
		Game.dip["pandemic"] = {"active": false, "count": 0}
	return Game.dip.pandemic


static func active() -> bool:
	return bool(st().get("active", false))


## Start an outbreak (also used by the dev tools).
static func start(origin: int = -1) -> Dictionary:
	var s := st()
	if origin < 0:
		# Big, connected countries are likelier sources.
		var tries := 0
		while tries < 30:
			tries += 1
			var cand: int = World.playable[Game.rng.randi() % World.playable.size()]
			var c: CountryState = Game.state(cand)
			if c != null and c.population > 2e7 and cand != Game.player:
				origin = cand
				break
		if origin < 0:
			origin = World.playable[0]
	var sev := Game.rng.randf_range(0.6, 1.4)
	for k in ["first_case", "warned", "ended_m"]:
		s.erase(k)
	s.merge({"active": true, "name": NAMES[(int(s.get("count", 0)) + Game.rng.randi()) % NAMES.size()],
		"start": Game.months_played, "origin": origin, "severity": sev,
		"r": E.PAN_SPREAD * Game.rng.randf_range(0.85, 1.25),
		"inf": {str(origin): 0.002}, "imm": {}, "vac": {}, "deaths": 0.0, "peak": 0.0,
		"lockdown": 0, "masks": false, "borders": false, "testing": false, "lock_months": 0, "player_set": false,
		"vaccine_world": 0.0, "vaccine_own": -1.0, "vaccinating": false, "fade": 0}, true)
	s.count = int(s.get("count", 0)) + 1
	return s


static func share(i: int, key: String) -> float:
	return float((st().get(key, {}) as Dictionary).get(str(i), 0.0))


## Infected share of your people now.
static func infected() -> float:
	return share(Game.player, "inf")


## Your policies' combined effect on spread (0 = none, 1 = stops it).
static func measures() -> float:
	var s := st()
	var m: float = [0.0, E.PAN_LOCK_PARTIAL, E.PAN_LOCK_FULL][int(s.get("lockdown", 0))]
	if bool(s.get("masks", false)):
		m += E.PAN_MASKS
	if bool(s.get("testing", false)):
		m += E.PAN_TESTING
	return clampf(m, 0.0, 0.85)


## Hospital capacity: infected share the health system can treat well.
static func capacity(c: CountryState) -> float:
	var cov := 0.5
	if not c.builds.is_empty():
		cov = (Builds.coverage_of(c, "hospital", float(Builds.count(c, "hospital")))
			+ Builds.coverage_of(c, "clinic", float(Builds.count(c, "clinic")))) * 0.5
	return E.PAN_CAPACITY * (0.4 + cov)


## Does your country have its own vaccine (mRNA research), and how far along?
static func own_vaccine_possible() -> bool:
	return Tech.has("mrna")


static func vaccine_ready() -> bool:
	var s := st()
	return float(s.get("vaccine_world", 0.0)) >= 1.0 or float(s.get("vaccine_own", -1.0)) >= 1.0


## Monthly: spread, deaths, vaccines, the end. Returns headlines [{text, icon, good, big}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var s := st()
	if not active():
		if Game.months_played > 24 and not Game.no_events and not Game.sandbox \
				and Game.rng.randf() < E.PAN_CHANCE * Difficulty.severity() \
				and Game.months_played - int(s.get("ended_m", -999)) > 120:
			start()
			out.append({"text": "A new disease, the %s, is spreading in %s" % [str(s.name), World.the_name(int(s.origin))],
				"icon": "biohazard", "good": false, "big": true})
		return out
	var inf: Dictionary = s.inf
	var imm: Dictionary = s.imm
	var vac: Dictionary = s.vac
	var world := 0.0
	var world_n := 0
	for k in inf:
		world += float(inf[k])
		world_n += 1
	world /= float(maxi(World.playable.size(), 1))
	# Spread inside each infected country, and to new ones.
	var new_inf := {}
	for i in World.playable:
		var key := str(i)
		var c: CountryState = Game.state(i)
		if c == null:
			continue
		var I := float(inf.get(key, 0.0))
		var R := float(imm.get(key, 0.0))
		var V := float(vac.get(key, 0.0))
		var S := maxf(1.0 - I - R - V, 0.0)
		var m := 0.0
		if i == Game.player:
			m = measures()
		elif I > 0.004:
			m = 0.4                                     # other governments act too
		var beta := float(s.r) * (1.0 - m)
		# Imported cases: open, connected countries catch it first.
		var imp := 0.0
		if I < 0.0005 and world > 0.0:
			var open := clampf(World.stat(i, "trade_pct", 60.0) / 100.0, 0.2, 1.5)
			if i == Game.player and bool(s.get("borders", false)):
				open *= 1.0 - E.PAN_BORDERS
			if Game.rng.randf() < clampf(world * 60.0 * open, 0.0, 0.6):
				imp = 0.0004
		var grow := beta * I * S + imp
		var rec := I * E.PAN_RECOVER
		var I2 := clampf(I + grow - rec, 0.0, 0.6)
		if I2 < 0.00002:
			I2 = 0.0
		R = clampf(R + rec, 0.0, 1.0)
		if I2 > 0.0:
			new_inf[key] = I2
		imm[key] = R
		# Vaccination once available.
		if vaccine_ready():
			var pace := E.PAN_VAX_RATE * (0.5 + Economy.income_level(c.gdp_per_capita()))
			if i == Game.player:
				pace = E.PAN_VAX_RATE * (0.3 + capacity(c) / E.PAN_CAPACITY) if bool(s.get("vaccinating", false)) else 0.0
			vac[key] = clampf(V + pace * S, 0.0, 0.9)
		# Deaths and economic damage (player handled in effects()).
		if i != Game.player and I2 > 0.002:
			c.shocks.growth = float(c.shocks.growth) - E.PAN_AI_GROWTH * minf(I2 * 50.0, 1.0)
	s.inf = new_inf
	# Your country: deaths, peak, lockdown fatigue.
	var me := Game.me()
	var Im := infected()
	var cap := capacity(me)
	var over := maxf(Im - cap, 0.0) / maxf(cap, 0.001)
	var dead := Im * E.PAN_RECOVER * E.PAN_IFR * float(s.severity) * (1.0 + minf(over, 1.5)) * me.population * (1.0 - float(vac.get(str(Game.player), 0.0)))
	s.deaths = float(s.deaths) + dead
	me.population = maxf(me.population - dead, 1.0)
	# Every death is felt: grief and anger at the government.
	me.shocks.approval = float(me.shocks.approval) - dead / maxf(me.population, 1.0) * E.PAN_GRIEF
	me.shocks.happiness = float(me.shocks.happiness) - dead / maxf(me.population, 1.0) * E.PAN_GRIEF
	s.peak = maxf(float(s.peak), Im)
	s.lock_months = int(s.lock_months) + 1 if int(s.get("lockdown", 0)) > 0 else maxi(int(s.lock_months) - 1, 0)
	if over > 0.0 and int(s.get("warned", -99)) < Game.months_played - 6:
		s.warned = Game.months_played
		out.append({"text": "Hospitals overwhelmed: %s's wards are full" % World.the_name(Game.player), "icon": "hospital", "good": false, "big": true})
	if Im > 0.0 and not s.has("first_case"):
		s.first_case = Game.months_played
		out.append({"text": "First %s cases confirmed in %s" % [str(s.name), World.the_name(Game.player)], "icon": "biohazard", "good": false, "big": true})
	# Vaccines.
	var months := Game.months_played - int(s.start)
	if float(s.vaccine_world) < 1.0:
		s.vaccine_world = minf(float(s.vaccine_world) + 1.0 / E.PAN_VACCINE_MONTHS, 1.0)
		if float(s.vaccine_world) >= 1.0:
			out.append({"text": "A vaccine against the %s is approved worldwide" % str(s.name), "icon": "syringe", "good": true, "big": true})
	if own_vaccine_possible() and float(s.vaccine_own) < 1.0 and float(s.vaccine_world) < 1.0:
		s.vaccine_own = minf(maxf(float(s.vaccine_own), 0.0) + 1.0 / E.PAN_OWN_VACCINE_MONTHS, 1.0)
		if float(s.vaccine_own) >= 1.0:
			me.shocks.approval = float(me.shocks.approval) + 3.0
			for j in World.playable:
				if j != Game.player:
					Game.relations[j] = clampf(Game.relations[j] + 3.0, -100.0, 100.0)
			out.append({"text": "Your scientists' vaccine works: %s leads the world out of the %s" % [World.the_name(Game.player), str(s.name)],
				"icon": "syringe", "good": true, "big": true})
	# Until you take charge, your cabinet responds: partial lockdown and masks once
	# cases climb, lifted when they fall.
	if not bool(s.get("player_set", false)):
		if Im > 0.005 and int(s.get("lockdown", 0)) == 0:
			s.lockdown = 1
			s.masks = true
			out.append({"text": "Your cabinet orders a partial lockdown and masks in public", "icon": "shield", "good": true, "big": false})
		elif Im < 0.001 and int(s.get("lockdown", 0)) > 0:
			s.lockdown = 0
			s.masks = false
			out.append({"text": "Cases are falling: your cabinet lifts the lockdown", "icon": "shield", "good": true, "big": false})
	if vaccine_ready() and not bool(s.get("vaccinating", false)):
		s.vaccinating = true                    # the cabinet starts the campaign right away
	# The end: cases fade everywhere for a few months.
	var total := 0.0
	for k in s.inf:
		total += float(s.inf[k])
	total /= float(maxi(World.playable.size(), 1))      # average share infected worldwide
	s.fade = int(s.fade) + 1 if total < 0.0003 and months > 6 else 0
	if int(s.fade) >= 3 or months > 72:
		out.append({"text": "The %s pandemic is over. %s lives were lost in %s" % [str(s.name), DS.compact(float(s.deaths)), World.the_name(Game.player)],
			"icon": "heart-pulse", "good": true, "big": true})
		Game.add_milestone("Came through the %s pandemic" % str(s.name), "heart-pulse", "accent")
		s.active = false
		s.ended_m = Game.months_played
		s.inf = {}
		s.lockdown = 0
		s.borders = false
		s.testing = false
		s.masks = false
	return out


## Monthly target offsets on you (growth, unemployment, happiness, approval, stability, cost, trade).
static func effects() -> Dictionary:
	var out := {}
	if not active():
		return out
	var s := st()
	var Im := infected()
	var lock := int(s.get("lockdown", 0))
	var fatigue := clampf(float(s.get("lock_months", 0)) / 12.0, 0.0, 1.5)
	var sick := minf(Im * 40.0, 1.0)                 # 2.5 % infected = full disruption
	var lock_g: float = [0.0, E.PAN_LOCK_GROWTH_PARTIAL, E.PAN_LOCK_GROWTH_FULL][lock]
	var lock_u: float = [0.0, 1.0, 3.0][lock]
	var lock_h: float = [0.0, 1.5, 4.0][lock]
	var lock_a: float = [0.0, 1.0, 3.0][lock]
	out["growth"] = -E.PAN_SICK_GROWTH * sick - lock_g - (E.PAN_BORDER_GROWTH if bool(s.get("borders", false)) else 0.0)
	out["unemployment"] = lock_u + sick * 1.0
	out["happiness"] = -3.0 * sick - lock_h * (1.0 + fatigue)
	# Early on people rally behind firm action; later they tire of it.
	var months := Game.months_played - int(s.start)
	out["approval"] = (2.0 if lock > 0 and months < 6 else 0.0) - lock_a * fatigue - 4.0 * sick
	out["stability"] = -2.0 * sick - (2.0 * fatigue if lock == 2 else 0.0)
	out["cost"] = (E.PAN_TESTING_COST if bool(s.get("testing", false)) else 0.0) + E.PAN_HEALTH_COST * sick
	return out


static func set_policy(key: String, v: Variant, by_player: bool = true) -> void:
	var s := st()
	s[key] = v
	if by_player:
		s.player_set = true          # from now on the cabinet leaves it to you
	if key == "lockdown" and int(v) == 0:
		s.lock_months = int(s.lock_months) / 2
