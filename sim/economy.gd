class_name Economy
extends RefCounted
## ============================================================================
##  ECONOMY MODEL — every formula and tweakable constant lives in this file.
## ============================================================================
## Design goals: believable, not academic. Monthly ticks. Each country starts in
## equilibrium with its real-world numbers ("calibration offsets"), so nothing
## drifts unless policies, events or the world change. Policy effects are
## measured RELATIVE TO THE COUNTRY'S STARTING POLICY, so e.g. Denmark with high
## taxes isn't instantly punished for being Denmark.
##
## Variables (per CountryState): gdp (nominal USD/yr), growth (%/yr),
## unemployment (%), inflation (%/yr), core_inflation, debt (USD), treasury (USD),
## interest rate (policy, %), approval / happiness / stability (0–100),
## military (0–100 index), population.

# ------------------------------------------------------------------ TIME -----
const MONTHS_PER_YEAR := 12.0
## Real seconds per in-game month at 1x speed (2x, 4x divide this).
const SECONDS_PER_MONTH := 2.0

# ----------------------------------------------------------------- GROWTH ----
## How fast actual growth chases its target each month (0..1).
const GROWTH_ADJUST := 0.15
## Long-run trend growth by income: poor countries converge faster.
const TREND_RICH := 1.4          # %/yr at ~$60k per capita
const TREND_POOR := 4.8          # %/yr at ~$1k per capita
## Starting growth is pulled toward trend over the years (business cycles fade).
const TREND_PULL := 0.004        # per month
## Each +1 pt of income tax above the starting level cuts growth by this much.
const INCOME_TAX_DRAG := 0.045
const CORP_TAX_DRAG := 0.06
## Interest rate above neutral slows growth (per pt, capped by RATE_GAP_CAP).
const RATE_GROWTH_DRAG := 0.18
const RATE_GAP_CAP := 8.0
## Fiscal multiplier: +1 pt of GDP in spending adds this to growth (short run).
const FISCAL_MULTIPLIER := 0.35
## Budget-share effects on growth, per +10 pts of share vs start.
const INFRA_GROWTH := 0.30
const RESEARCH_GROWTH := 0.45
const EDUCATION_GROWTH := 0.20
## Trade: fully open vs fully closed (0..1 slider, 0.5 = start).
const TRADE_GROWTH := 1.2        # %/yr between fully closed and fully open
const TRADE_DEAL_GROWTH := 0.12  # per active trade deal
const SANCTION_GROWTH := 0.35    # per country sanctioning you
## Debt above this % of GDP drags growth and raises borrowing costs.
const DEBT_SAFE := 90.0
const DEBT_GROWTH_DRAG := 0.02   # per pt above DEBT_SAFE
## Instability drag: below this stability, growth suffers.
const STABILITY_FLOOR := 35.0
const STABILITY_GROWTH_DRAG := 0.05

# -------------------------------------------------------------- INFLATION ----
const INFLATION_TARGET := 2.0
const INFLATION_ADJUST := 0.12
## Core (expected) inflation decays toward target each month...
const CORE_DECAY := 0.015
## ...faster when policy is tight (per pt the rate is above neutral).
const CORE_TIGHT_DECAY := 0.006
## ...and rises when policy is loose.
const CORE_LOOSE_RISE := 0.05
const RATE_INFLATION_EFFECT := 0.35  # per pt of (rate - neutral), capped
const DEMAND_INFLATION := 0.35       # per pt growth above trend
const DEFICIT_INFLATION := 0.25      # per pt deficit above DEFICIT_SAFE
const DEFICIT_SAFE := 3.0
const PROTECTION_INFLATION := 2.0    # fully protectionist trade adds this

# ---------------------------------------------------------- INTEREST RATE ----
const NEUTRAL_BASE := 2.5
const NEUTRAL_PER_CORE := 0.25   # neutral rate rises with core inflation...
const NEUTRAL_CORE_CAP := 40.0   # ...up to this much core inflation
const RATE_MIN := 0.0
const RATE_MAX := 40.0

# ----------------------------------------------------------- UNEMPLOYMENT ----
const UNEMP_ADJUST := 0.08
const OKUN := 0.45               # pts of unemployment per pt growth gap
const RATE_UNEMP := 0.12         # per pt rate above neutral (capped)
const EDUCATION_UNEMP := 0.25    # per +10 pts share, lowers natural rate (slowly)
const UNEMP_MIN := 1.0
const UNEMP_MAX := 45.0

# ------------------------------------------------------------ PUBLIC FINANCE --
## Revenue = GDP × (income_tax × K_INCOME + corp_tax × K_CORP + other)
const K_INCOME := 0.38
const K_CORP := 0.16
## Laffer curvature: effective yield falls at very high rates.
const LAFFER := 0.45
## Average interest paid on debt chases (policy rate + risk premium).
const DEBT_RATE_ADJUST := 0.02
const RISK_PREMIUM_PER_DEBT := 0.04  # per pt of debt above DEBT_SAFE
const RISK_PREMIUM_INSTABILITY := 0.03
## Treasury keeps a cash buffer of this many months of spending; deficits are
## financed by issuing bonds (debt) to maintain it.
const TREASURY_BUFFER_MONTHS := 1.0
## Debt crisis: monthly probability once debt is above DEBT_CRISIS_START.
const DEBT_CRISIS_START := 100.0
const DEBT_CRISIS_PROB := 0.0005  # per pt above start, per month

# ----------------------------------------------------- WELL-BEING & POLITICS --
const HAPPY_ADJUST := 0.06
const APPROVAL_ADJUST := 0.10
const STABILITY_ADJUST := 0.05
## Happiness inputs (relative to start).
const HEALTH_HAPPY := 9.0        # per doubling of health spending per person
const WELFARE_HAPPY := 7.0
const EDUCATION_HAPPY := 4.0
const UNEMP_HAPPY := 0.9         # per pt above start
const INFLATION_HAPPY := 0.35    # per pt above start (capped at 60)
const INCOME_HAPPY := 14.0       # per doubling of GDP per capita
const TAX_HAPPY := 0.35          # per pt income tax above start
## Approval inputs.
const APPROVAL_FROM_HAPPY := 0.6
const APPROVAL_GROWTH := 1.6     # per pt growth vs start
const APPROVAL_INCOME_TAX := 0.7
const APPROVAL_CORP_TAX := 0.15
const APPROVAL_INFLATION := 0.4
## Stability inputs.
const STABILITY_FROM_APPROVAL := 0.35
const STABILITY_FROM_HAPPY := 0.25
const STABILITY_MILITARY := 0.6  # per +10 pts military share
## Temporary event shocks decay by this fraction each month.
const SHOCK_DECAY := 0.12

# --------------------------------------------------------------- MILITARY ----
const MILITARY_ADJUST := 0.04
## Strength index = log-scale of annual military spend: $10M -> 0, ~$900B -> 100.
const MIL_LOG_MIN := 7.0
const MIL_LOG_MAX := 11.95

# ------------------------------------------------------------- ELECTIONS -----
const ELECTION_YEARS := 4
const WIN_SAFE := 50.0           # approval at/above this always wins
const WIN_NONE := 35.0           # approval below this always loses

# ------------------------------------------------------------- POPULATION ----
const POP_GROWTH_RICH := 0.1     # %/yr
const POP_GROWTH_POOR := 2.6     # %/yr


# =============================================================================
#  Derived starting values (from real data). Flagged as derived in SOURCES.md.
# =============================================================================

static func per_capita(gdp: float, pop: float) -> float:
	return gdp / maxf(pop, 1.0)


## 0 (poor, $1k) .. 1 (rich, $60k+), log scale.
static func income_level(pc: float) -> float:
	return clampf((log(maxf(pc, 100.0)) / log(10.0) - 3.0) / (log(60000.0) / log(10.0) - 3.0), 0.0, 1.0)


static func trend_growth(pc: float) -> float:
	return lerpf(TREND_POOR, TREND_RICH, income_level(pc))


static func neutral_rate(core_inflation: float) -> float:
	return NEUTRAL_BASE + NEUTRAL_PER_CORE * clampf(core_inflation, 0.0, NEUTRAL_CORE_CAP)


static func start_interest_rate(inflation: float) -> float:
	return clampf(neutral_rate(inflation), RATE_MIN, RATE_MAX)


static func start_income_tax(revenue_pct: float) -> float:
	return clampf(revenue_pct * 0.9, 8.0, 45.0)


static func start_corp_tax(revenue_pct: float) -> float:
	return clampf(18.0 + (revenue_pct - 25.0) * 0.3, 9.0, 32.0)


## Happiness 0–100 from income, health (life expectancy), jobs, prices, stability.
static func start_happiness(s: Dictionary) -> float:
	var pc := per_capita(s.get("gdp", 0.0), s.get("population", 1.0))
	var life: float = s.get("life_expectancy", 70.0)
	var h := 28.0 + 30.0 * income_level(pc) + clampf((life - 55.0) * 0.9, 0.0, 25.0)
	h -= clampf(s.get("unemployment", 5.0), 0.0, 40.0) * 0.6
	h -= clampf(s.get("inflation", 3.0) - 3.0, 0.0, 60.0) * 0.2
	h += clampf(s.get("stability_wgi", 0.0), -2.5, 2.5) * 3.0
	return clampf(h, 15.0, 88.0)


static func start_stability(s: Dictionary) -> float:
	return clampf((s.get("stability_wgi", 0.0) + 2.5) / 5.0 * 100.0, 5.0, 95.0)


static func start_approval(happiness: float, stability: float) -> float:
	return clampf(42.0 + (happiness - 50.0) * 0.35 + (stability - 50.0) * 0.1, 30.0, 62.0)


static func military_index(spend_usd: float) -> float:
	var l := log(maxf(spend_usd, 1.0)) / log(10.0)
	return clampf((l - MIL_LOG_MIN) / (MIL_LOG_MAX - MIL_LOG_MIN) * 100.0, 1.0, 100.0)


static func population_growth(pc: float) -> float:
	return lerpf(POP_GROWTH_POOR, POP_GROWTH_RICH, income_level(pc))


## 0 easy, 1 normal, 2 hard — shown in the country picker.
static func difficulty(s: Dictionary) -> int:
	var score := 0.0
	score += clampf((s.get("inflation", 2.0) - 6.0) / 10.0, 0.0, 3.0)
	score += clampf((s.get("debt_pct", 50.0) - 80.0) / 40.0, 0.0, 2.0)
	score += clampf((s.get("unemployment", 5.0) - 8.0) / 6.0, 0.0, 2.0)
	score += clampf(-s.get("stability_wgi", 0.0), 0.0, 2.5)
	score += clampf((-s.get("budget_balance_pct", -2.0) - 4.0) / 4.0, 0.0, 1.5)
	score += 1.0 - income_level(per_capita(s.get("gdp", 1.0), s.get("population", 1.0)))
	if score < 1.6:
		return 0
	return 1 if score < 3.2 else 2


const DIFFICULTY_LABELS := ["Easy", "Normal", "Hard"]


## Laffer-shaped revenue share of GDP for a given tax rate (percent).
static func tax_yield(rate: float, k: float) -> float:
	var r := rate / 100.0
	return r * k * (1.0 - LAFFER * r * r)
