class_name VoxPop
extends RefCounted
## What people are saying: short quotes from invented citizens about whatever
## matters most right now (prices, jobs, rents, hospital waits, the air, a dam,
## a hit song…). Picked by how far each thing has moved since you took office,
## so the voices always point at what to look at next. Names are fictional.

const JOBS := ["nurse", "teacher", "taxi driver", "student", "farmer", "shop owner", "engineer", "retiree", "cook",
	"builder", "office worker", "fisher", "doctor", "factory worker", "delivery rider", "accountant"]


## [salience, quote, good] candidates from the current state.
static func _candidates() -> Array:
	var c := Game.me()
	var b: Dictionary = c.base
	var out: Array = []
	var di := c.inflation - float(b.inflation)
	if di > 2.0:
		out.append([di, "Everything at the market costs more every week. My wages don't.", false])
	elif di < -1.5 and c.inflation < 4.0:
		out.append([-di, "Prices have finally calmed down. I can plan my shopping again.", true])
	var du := c.unemployment - float(b.unemployment)
	if du > 1.5:
		out.append([du * 1.3, "Three months of applications and not one interview.", false])
	elif du < -1.5:
		out.append([-du * 1.3, "There are job ads everywhere. My son got hired in a week.", true])
	if Game.dip.has("pop") and Population.afford() < 92.0:
		out.append([(100.0 - Population.afford()) / 3.0, "Half my salary goes on rent, and the landlord wants more.", false])
	if Game.dip.has("hlth"):
		var w0 := float(Health.st().wait0)
		var dw := Health.wait() - w0
		if dw > 2.0:
			out.append([dw * 0.8, "I've waited %d weeks for my operation. Still no date." % roundi(Health.wait()), false])
		elif dw < -2.0:
			out.append([-dw * 0.8, "I got my hip operation in a few weeks. Unthinkable a few years ago.", true])
	if Game.dip.has("air"):
		var da := Air.pm() - float(Air.st().pm0)
		if da < -4.0:
			out.append([-da * 0.4, "I can see the mountains from my window again. The smog is gone.", true])
		elif Air.pm() >= 45.0:
			out.append([Air.pm() / 15.0, "My daughter's asthma is worse every winter. The air here is poison.", false])
	if Game.dip.has("water") and Water.stress() > float(Water.st().s0) + 0.2:
		out.append([(Water.stress() - float(Water.st().s0)) * 8.0, "The taps ran dry again this morning.", false])
	if Game.dip.has("reg"):
		var wk := Regions.weakest()
		if wk >= 0 and float(Regions.list()[wk].loyalty) < 40.0:
			out.append([(45.0 - float(Regions.list()[wk].loyalty)) / 2.0, "Nobody in the capital cares about %s. Maybe we'd be better off on our own." % Regions.in_text(Regions.list()[wk]), false])
	if Game.dip.has("cx") and not CultureExports.recent(6).is_empty():
		var h: Dictionary = CultureExports.recent(6)[-1]
		out.append([5.0, "Everyone abroad is talking about “%s”. I've never been prouder." % str(h.title), true])
	if Game.dip.has("fish") and Fisheries.coastal() and Fisheries.collapsed():
		out.append([7.0, "My father fished these waters, and his father. Now the boats just sit in port.", false])
	if War.at_war():
		out.append([8.0, "My brother is at the front. Every phone call I hold my breath.", false])
	if Game.dip.has("pandemic") and Pandemic.active() and Pandemic.infected() > 0.002:
		out.append([6.0, "Half my street is sick. When will this end?", false])
	var dh := c.happiness - float(b.happiness)
	if dh > 4.0:
		out.append([dh * 0.5, "Honestly? Life's good right now. Better than when I was young.", true])
	elif dh < -4.0:
		out.append([-dh * 0.5, "Everyone I know is tired and angry. Something has to change.", false])
	if c.growth > c.trend + 1.5:
		out.append([c.growth - c.trend, "Business is booming. I've hired two more people this year.", true])
	# Everyday voices on the general mood (low weight: only fill the gaps).
	if c.approval >= 55.0:
		out.append([0.5, "I didn't vote for this government, but I'll admit they're doing all right.", true])
	elif c.approval < 40.0:
		out.append([0.5, "Politicians promise everything and deliver nothing. Same as always.", false])
	if c.growth >= 2.0:
		out.append([0.4, "My shop had its best year since I opened it.", true])
	elif c.growth < 0.5:
		out.append([0.4, "Customers are counting every coin. It's a slow year.", false])
	if c.inflation < 3.0:
		out.append([0.3, "At least the price of bread hasn't moved.", true])
	if Game.dip.has("edu") and Education.drain() > 10.0:
		out.append([0.35, "Half my classmates are planning to work abroad after graduation.", false])
	if c.stability >= 60.0:
		out.append([0.2, "It's a safe, calm place to raise children.", true])
	out.append([0.1, "Work, family, football on Sunday. Life goes on.", true])
	out.append([0.05, "I just want the buses to run on time.", false])
	return out


## Up to n quotes: [{text, who, good}], most important first.
static func quotes(n: int = 3) -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var cands := _candidates()
	cands.sort_custom(func(a: Array, b2: Array) -> bool: return float(a[0]) > float(b2[0]))
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.year, Game.month / 3, "vox"])
	for cnd in cands.slice(0, n):
		var p := Names.pool(Game.player)
		var first: String = (p[0] as Array)[r.randi() % (p[0] as Array).size()]
		var age := r.randi_range(19, 78)
		var job: String = JOBS[r.randi() % JOBS.size()] if age < 67 else "retiree"
		out.append({"text": str(cnd[1]), "who": "%s, %d, %s" % [first, age, job], "good": bool(cnd[2])})
	if out.is_empty():
		out.append({"text": "Things are fine, I suppose. Quiet. Quiet is good.", "who": "%s, %d, %s" % [str((Names.pool(Game.player)[0] as Array)[0]), 45, "shop owner"], "good": true})
	return out
