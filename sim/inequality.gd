class_name Inequality
extends RefCounted
## Income inequality as a living stat. Every country starts at its real Gini
## index (World Bank SI.POV.GINI; 0 = everyone equal, 100 = one person has it
## all). It drifts toward a target set by how you redistribute: welfare spending,
## income tax, joblessness and laws like the minimum wage or privatisation.
## Only CHANGES from the start count, so the real baseline stays as it is.
## Rising inequality costs happiness and stability (Simulation); constants in
## sim/economy.gd (GINI_*, INEQ_*).

const E = preload("res://sim/economy.gd")

## Laws added (+) or scrapped (-) since the start -> Gini points.
const LAW_GINI := {"min_wage": -1.0, "wealth_tax": -1.2, "basic_income": -2.0, "universal_health": -0.8,
	"free_university": -0.5, "parental_leave": -0.3, "privatisation": 1.0, "export_zones": 0.4, "pension_age": 0.3}


static func start(i: int) -> float:
	return clampf(World.stat(i, "gini", 35.0), 20.0, 65.0)


## Where Gini is heading, with reasons: [[label, points], …] (relative to the start).
static func terms(c: CountryState) -> Array:
	var b: Dictionary = c.base
	var out: Array = []
	var d_welfare := c.effort("welfare") - float(b.get("welfare_effort", c.effort("welfare")))
	out.append(["Welfare spending", -E.GINI_WELFARE * d_welfare])
	out.append(["Income tax", -E.GINI_INCOME_TAX * (c.income_tax - float(b.income_tax))])
	out.append(["Jobs", E.GINI_UNEMP * (c.unemployment - float(b.unemployment))])
	var laws := 0.0
	for id in LAW_GINI:
		var on := Laws.is_active(c, id)
		var was := c.laws_start.has(id)
		if on != was:
			laws += float(LAW_GINI[id]) * (1.0 if on else -1.0)
	out.append(["Laws & reforms", laws])
	if not c.builds.is_empty():
		out.append(["Affordable homes", float(Builds.modifiers(c).get("gini", 0.0))])
	if c.idx == Game.player and Game.has_game() and Game.dip.has("pop"):
		out.append(["Housing costs", float(Population.modifiers().get("gini", 0.0))])
	if not c.taxes.is_empty():
		out.append(["Other taxes", float(Taxes.modifiers(c).get("gini", 0.0))])
	return out


static func target(c: CountryState) -> float:
	var t := start(c.idx)
	for x in terms(c):
		t += float(x[1])
	return clampf(t, 18.0, 70.0)


## Monthly: move a little toward the target (inequality changes slowly).
static func tick(c: CountryState) -> void:
	if c.gini <= 0.0:
		c.gini = start(c.idx)
	c.gini += (target(c) - c.gini) * E.GINI_ADJUST


## Change since the start (positive = more unequal).
static func change(c: CountryState) -> float:
	return c.gini - start(c.idx)


static func label(g: float) -> String:
	if g < 28.0:
		return "very equal"
	if g < 34.0:
		return "fairly equal"
	if g < 40.0:
		return "moderate"
	if g < 48.0:
		return "unequal"
	return "very unequal"
