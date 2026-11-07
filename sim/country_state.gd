class_name CountryState
extends RefCounted
## Live state of one country: economy, politics and the player's policy levers.
## `base` holds the real-world starting point every effect is measured against.

const BUDGET_KEYS := ["health", "education", "infrastructure", "military", "welfare", "research"]
const BUDGET_LABELS := {"health": "Healthcare", "education": "Education", "infrastructure": "Infrastructure",
	"military": "Military", "welfare": "Welfare", "research": "Research"}
const BUDGET_ICONS := {"health": "stethoscope", "education": "graduation-cap", "infrastructure": "construction",
	"military": "shield", "welfare": "hand-coins", "research": "flask-conical"}

var idx := -1

# Economy
var population := 0.0
var gdp := 0.0                 # nominal, USD per year
var growth := 0.0              # real, % per year
var growth_anchor := 0.0       # underlying growth; drifts toward trend
var trend := 2.0
var unemployment := 5.0
var u_natural := 5.0
var inflation := 2.0
var core_inflation := 2.0
var interest_rate := 3.0
var debt := 0.0                # USD
var debt_rate := 3.0           # average interest paid on debt, %
var treasury := 0.0            # USD cash reserve
var revenue := 0.0             # USD/yr (derived each tick)
var spending := 0.0
var interest_cost := 0.0
var balance := 0.0
var other_rev_pct := 10.0      # VAT, tariffs, fees … (% of GDP)
var pop_growth := 1.0
var price_index := 1.0         # cumulative USD price level, for real income

# Politics & society (0–100)
var approval := 50.0
var happiness := 50.0
var stability := 50.0
var military := 30.0

# Policy levers
var income_tax := 20.0         # %
var corp_tax := 20.0           # %
var spending_pct := 30.0       # primary spending, % of GDP
var budget := {}               # key -> share (0..1), sums to 1
var trade_openness := 0.5      # 0 protectionist … 1 fully open
var cb_auto := true            # an independent central bank sets interest rates (AI.central_bank)

# Diplomacy aggregates (maintained by Game)
var trade_deals := 0
var sanctioned_by := 0
var alliances := 0

var base := {}                 # starting values (see init_from_stats)
var shocks := {"growth": 0.0, "inflation": 0.0, "unemployment": 0.0, "happiness": 0.0,
	"approval": 0.0, "stability": 0.0}
var estimated: Array = []
var laws := {}         # id -> {state: active|passing|repealing, months_left}
var laws_start := {}   # laws in force at the start (baseline; see Laws)
var laws_ver := 0      # bump when `laws` changes (invalidates the modifier cache)
var projects := {}     # id -> {state: building|done, progress (months), price (USD), start?}
var projects_ver := 0
var lx_cache := {}
var lx_ver := -1

# Explainer data from the latest tick (player only, not saved): see Simulation.tick.
var why := {}
var targets := {}


func init_from_stats(i: int, s: Dictionary) -> CountryState:
	idx = i
	estimated = s.get("estimated", [])
	population = maxf(s.get("population", 1e6), 1000.0)
	gdp = maxf(s.get("gdp", 1e9), 1e7)
	growth = clampf(s.get("gdp_growth", 2.0), -8.0, 12.0)
	unemployment = clampf(s.get("unemployment", 6.0), 1.0, 40.0)
	u_natural = unemployment
	inflation = clampf(s.get("inflation", 3.0), -2.0, 300.0)
	core_inflation = inflation
	interest_rate = Economy.start_interest_rate(inflation)
	var debt_pct := clampf(s.get("debt_pct", 50.0), 0.0, 300.0)
	debt = gdp * debt_pct / 100.0
	debt_rate = clampf(interest_rate * 0.7 + 1.0, 0.5, 20.0)
	var pc := Economy.per_capita(gdp, population)
	trend = Economy.trend_growth(pc)
	growth_anchor = clampf(growth, trend - Economy.ANCHOR_BELOW_TREND, trend + Economy.ANCHOR_ABOVE_TREND)
	pop_growth = Economy.population_growth(pc)

	var revenue_pct := clampf(s.get("revenue_pct", 25.0), 8.0, 55.0)
	income_tax = Economy.start_income_tax(revenue_pct)
	corp_tax = Economy.start_corp_tax(revenue_pct)
	var tax_pct := 100.0 * (Economy.tax_yield(income_tax, Economy.K_INCOME) + Economy.tax_yield(corp_tax, Economy.K_CORP))
	other_rev_pct = maxf(revenue_pct - tax_pct, 1.0)
	var interest_pct := debt_pct * debt_rate / 100.0
	spending_pct = clampf(revenue_pct - interest_pct - s.get("budget_balance_pct", -3.0), 8.0, 65.0)

	budget = Economy.start_budget(s, spending_pct)
	trade_openness = Economy.start_trade_openness(s.get("trade_pct", 60.0))
	trend += Economy.demography_trend(s.get("age65_pct", 10.0))

	happiness = Economy.start_happiness(s)
	stability = Economy.start_stability(s)
	approval = Economy.start_approval(happiness, stability)
	military = Economy.military_index(gdp * s.get("military_pct", 1.8) / 100.0)

	laws_start = Laws.starting_set(self)
	for id in laws_start:
		laws[id] = {"state": "active"}
	projects = Projects.starting_set(self)
	Simulation.update_finances(self)
	treasury = spending / 12.0 * Economy.TREASURY_BUFFER_MONTHS
	_capture_base()
	return self


func _capture_base() -> void:
	base = {
		"income_tax": income_tax, "corp_tax": corp_tax, "spending_pct": spending_pct,
		"budget": budget.duplicate(), "trade": trade_openness,
		"gdp_pc": gdp_per_capita(), "growth": growth, "inflation": inflation,
		"unemployment": unemployment, "debt_pct": debt_pct(), "deficit_pct": -balance_pct(),
		"happiness": happiness, "approval": approval, "stability": stability,
		"health_effort": effort("health"), "education_effort": effort("education"),
		"welfare_effort": effort("welfare"),
	}


# ----------------------------------------------------------------- derived ---
func gdp_per_capita() -> float:
	return gdp / maxf(population, 1.0)


func debt_pct() -> float:
	return debt / maxf(gdp, 1.0) * 100.0


func balance_pct() -> float:
	return balance / maxf(gdp, 1.0) * 100.0


func revenue_pct() -> float:
	return revenue / maxf(gdp, 1.0) * 100.0


## [[label, points], …] that add up to the credit score (see Economy.RATING_*).
func rating_parts() -> Array:
	return Economy.rating_parts(debt_pct(), -balance_pct(), stability, inflation, growth, gdp_per_capita())


func rating_score() -> float:
	var s := 0.0
	for p in rating_parts():
		s += float(p[1])
	return s


func rating() -> String:
	return Economy.rating_grade(rating_score())


func real_gdp_per_capita() -> float:
	return gdp_per_capita() / maxf(price_index, 0.01)


## Policy effort for a budget area: spending as % of GDP x share.
func effort(key: String) -> float:
	return spending_pct * budget.get(key, 0.0)


func spend_per_capita(key: String) -> float:
	return gdp * spending_pct / 100.0 * budget.get(key, 0.0) / maxf(population, 1.0)


func share_delta(key: String) -> float:
	## Change in budget share vs start, in percentage points.
	return (budget.get(key, 0.0) - base.get("budget", {}).get(key, 0.0)) * 100.0


func set_budget_share(key: String, share: float) -> void:
	## Sets one share and rescales the others proportionally so the total stays 1.
	share = clampf(share, 0.0, 0.9)
	var others := 0.0
	for k in BUDGET_KEYS:
		if k != key:
			others += budget[k]
	budget[key] = share
	for k in BUDGET_KEYS:
		if k != key:
			budget[k] = (budget[k] / others * (1.0 - share)) if others > 0.0 else (1.0 - share) / 5.0


## Deep copy (dictionaries included) — safe to simulate forward without
## touching the original.
func clone() -> CountryState:
	var c := CountryState.from_dict(to_dict().duplicate(true))
	c.idx = idx
	return c


## Fills `why`/`targets` without advancing time (used right after a new game or load).
func refresh_explainer() -> void:
	var probe := clone()
	var rng := RandomNumberGenerator.new()
	Simulation.tick(probe, rng, true)
	why = probe.why
	targets = probe.targets


# ----------------------------------------------------------------- persist ---
const SAVE_FIELDS := ["idx", "population", "gdp", "growth", "growth_anchor", "trend", "unemployment",
	"u_natural", "inflation", "core_inflation", "interest_rate", "debt", "debt_rate", "treasury",
	"other_rev_pct", "pop_growth", "price_index", "approval", "happiness", "stability", "military", "income_tax",
	"corp_tax", "spending_pct", "budget", "trade_openness", "trade_deals", "sanctioned_by",
	"alliances", "base", "shocks", "estimated", "laws", "laws_start", "projects", "cb_auto"]


func to_dict() -> Dictionary:
	var d := {}
	for f in SAVE_FIELDS:
		d[f] = get(f)
	return d


static func from_dict(d: Dictionary) -> CountryState:
	var c := CountryState.new()
	for f in SAVE_FIELDS:
		if d.has(f):
			c.set(f, d[f])
	c.idx = int(c.idx)
	c.trade_deals = int(c.trade_deals)
	c.sanctioned_by = int(c.sanctioned_by)
	c.alliances = int(c.alliances)
	Simulation.update_finances(c)
	return c
