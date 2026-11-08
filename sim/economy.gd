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
## 6 s: a year takes about a minute and a quarter at 1x, so there's time to read
## the map and react (players found 2 s far too fast).
const SECONDS_PER_MONTH := 6.0

# ----------------------------------------------------------------- GROWTH ----
## How fast actual growth chases its target each month (0..1).
const GROWTH_ADJUST := 0.15
## Long-run trend growth by income: poor countries converge faster.
const TREND_RICH := 1.5          # %/yr at ~$60k per capita
const TREND_POOR := 6.0          # %/yr at ~$1k per capita
## Starting growth is pulled toward trend over the years (business cycles fade).
const TREND_PULL := 0.01         # per month (~5-year half-life)
## Starting underlying growth is clamped to trend -3 … +4 pts (booms/busts fade).
const ANCHOR_BELOW_TREND := 3.0
const ANCHOR_ABOVE_TREND := 4.0
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
const EDUCATION_UNEMP := 1.5     # per +10 pts education share: natural rate falls this many pts/yr
## Hysteresis: the "normal" unemployment rate slowly follows actual unemployment
## (long spells of high or low joblessness become structural).
const UNEMP_HYSTERESIS := 0.012  # per month
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
const RISK_PREMIUM_PER_DEBT := 0.04  # per pt of debt above max(DEBT_SAFE, starting debt + DEBT_TOLERANCE)
## Debt can rise this many points above a country's starting level before
## markets charge more (they already price in where it is today).
const DEBT_TOLERANCE := 10.0
const RISK_PREMIUM_INSTABILITY := 0.03
## Treasury keeps a cash buffer of this many months of spending; deficits are
## financed by issuing bonds (debt) to maintain it.
const TREASURY_BUFFER_MONTHS := 1.0
## Debt crisis: monthly probability once debt is above DEBT_CRISIS_START.
const DEBT_CRISIS_START := 100.0
const DEBT_CRISIS_PROB := 0.0005  # per pt above start, per month
const RISK_PREMIUM_CAP := 6.0
## Sovereign default: above this debt % of GDP debts are restructured.
const DEFAULT_THRESHOLD := 250.0
const DEFAULT_HAIRCUT := 0.4      # share of debt written off
## Inflation above this erodes local-currency debt (interest is paid in real terms).
const DEBT_EROSION_FLOOR := 3.0

# ----------------------------------------------------- WELL-BEING & POLITICS --
const HAPPY_ADJUST := 0.06
const APPROVAL_ADJUST := 0.10
const STABILITY_ADJUST := 0.05
## Happiness inputs (relative to start).
## Service effects compare policy effort (spending % of GDP x budget share) with the start.
const HEALTH_HAPPY := 9.0        # per doubling of health effort
const WELFARE_HAPPY := 7.0
const EDUCATION_HAPPY := 4.0
const UNEMP_HAPPY := 0.9         # per pt above start
const INFLATION_HAPPY := 0.35    # per pt above start (capped at 60)
const INCOME_HAPPY := 10.0       # per doubling of REAL GDP per capita
## Hedonic adaptation: the income people compare against drifts toward today's.
const INCOME_ADAPTATION := 0.004 # per month
const HAPPY_MAX := 96.0
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
## Voters tire of long-serving governments: each election already won counts as
## this many approval points against you at the next one (x Difficulty.severity).
## Tuned with tools/balance_report: without it a sensible player won ~99 % of elections.
const ELECTION_FATIGUE := 4.5
## A tilted ("managed") election won below this approval is disputed: protests.
const DISPUTED_BELOW := 35.0

# --------------------------------------------------- HOLD ON POWER (Politics) ---
## Any system: stability below COLLAPSE_STABILITY for COLLAPSE_MONTHS ends your rule.
## Fragile countries that start near it get headroom: the line is at most
## (starting stability - COLLAPSE_HEADROOM).
const COLLAPSE_STABILITY := 8.0
const COLLAPSE_HEADROOM := 10.0
const COLLAPSE_MONTHS := 6
## Without elections: low stability AND low support for UNREST_MONTHS = revolution.
const UNREST_STABILITY := 18.0
const UNREST_SUPPORT := 30.0
const UNREST_MONTHS := 5
## Leadership reviews (Party Congress …): you stay if support or stability holds.
const REVIEW_SUPPORT := 30.0
const REVIEW_STABILITY := 45.0
## Military governments: cutting the army's budget share by more than this
## fraction, or letting stability fall below COUP_STABILITY, risks a coup.
const COUP_BUDGET_CUT := 0.3
const COUP_PER_CUT := 0.08        # monthly coup chance per 100 % cut beyond the limit
const COUP_STABILITY := 25.0
const COUP_PER_STABILITY := 0.004 # monthly coup chance per stability point below
## Without elections, order rests more on security forces than on approval.
const AUTOCRACY_APPROVAL_WEIGHT := 0.6   # x STABILITY_FROM_APPROVAL
const AUTOCRACY_MILITARY_WEIGHT := 2.0   # x STABILITY_MILITARY

# ------------------------------------------------------------ WORLD MARKETS ---
## Oil and food prices (WorldMarkets): log random walks with mean reversion.
const OIL_BASE_PRICE := 75.0      # $ per barrel at index 0
const FOOD_BASE_INDEX := 120.0    # FAO food price index at index 0
const OIL_REVERSION := 0.04       # per month, pull back toward normal
const OIL_VOLATILITY := 0.06      # monthly std-dev of log price (~ ±20 % typical swings)
const FOOD_REVERSION := 0.04
const FOOD_VOLATILITY := 0.03
const OIL_SHOCK_CHANCE := 0.012   # per month: a war, an OPEC cut, a glut
const OIL_SHOCK := 0.35
const FOOD_SHOCK_CHANCE := 0.008  # per month: a global harvest failure
const FOOD_SHOCK := 0.18
## Effects per unit of price gap (0.2 = 20 % above normal) x exposure (see WorldMarkets).
const OIL_GROWTH := 4.0           # growth pts for a pure exporter (exposure 1)
const OIL_INFLATION := 2.5        # inflation pts for an importer
const OIL_REVENUE := 3.0          # % of GDP of government revenue for a pure exporter
const FOOD_INFLATION := 3.0
const FOOD_HAPPY := 4.0
## Contagion: share of the world's / your region's / your partners' boom or bust you catch.
const CONTAGION_WORLD := 0.25     # x trade openness
const CONTAGION_REGION := 0.2
const CONTAGION_PARTNERS := 0.15

# ------------------------------------------------------------ SOCIETY DETAIL ---
## Welfare matters more where incomes are unequal (Gini): x(1 + (gini-35)/GINI_SCALE).
const GINI_SCALE := 40.0
## Demography: trend growth -/+ per point of over-65 share above/below the band.
const AGEING_DRAG := 0.04              # per pt above 16 %
const YOUTH_BONUS := 0.05              # per pt below 7 %

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


## Starting budget split from real spending (World Bank): health, education and
## R&D (about a third of R&D is public) as shares of primary spending; military
## from SIPRI/WB; welfare and infrastructure share the rest 68/32.
static func start_budget(s: Dictionary, spending_pct: float) -> Dictionary:
	var sp := maxf(spending_pct, 5.0)
	var b := {
		"military": clampf(float(s.get("military_pct", 1.8)) / sp, 0.02, 0.4),
		"health": clampf(float(s.get("health_pct", 4.0)) / sp, 0.05, 0.4),
		"education": clampf(float(s.get("education_pct", 4.0)) / sp, 0.05, 0.35),
		"research": clampf(float(s.get("research_pct", 0.8)) * 0.35 / sp, 0.01, 0.1),
	}
	var used := 0.0
	for k in b:
		used += float(b[k])
	if used > 0.8:   # leave room for welfare and infrastructure
		for k in b:
			b[k] = float(b[k]) * 0.8 / used
		used = 0.8
	b["welfare"] = (1.0 - used) * 0.68
	b["infrastructure"] = (1.0 - used) * 0.32
	return b


## Trade slider start (0 closed .. 1 open) from trade as % of GDP.
static func start_trade_openness(trade_pct: float) -> float:
	return clampf(0.3 + trade_pct / 250.0, 0.25, 0.85)


static func demography_trend(age65_pct: float) -> float:
	return -AGEING_DRAG * maxf(0.0, age65_pct - 16.0) + YOUTH_BONUS * maxf(0.0, 7.0 - age65_pct)


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
	# Floor of 38: a new leader gets a short honeymoon even in hard countries.
	return clampf(44.0 + (happiness - 50.0) * 0.35 + (stability - 50.0) * 0.1, 38.0, 64.0)


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

# ----------------------------------------------------------- LEGACY GRADE ---
## End-of-term grade: 50 + parts below, then A+ 90 / A 80 / B 68 / C 55 / D 42 / F.
const LEGACY_GRADES := [[90.0, "A+"], [80.0, "A"], [68.0, "B"], [55.0, "C"], [42.0, "D"], [-INF, "F"]]
const LEGACY_TITLES := {"A+": "A historic leader", "A": "A great leader", "B": "A good leader",
	"C": "A steady hand", "D": "A difficult term", "F": "A term to forget"}


## [[label, points], …] for a finished term (see Game.summary()).
static func legacy_parts(s: Dictionary) -> Array:
	var years := float(s.years)
	# Short terms prove less: performance counts fully only after two years.
	var w := clampf(years / 2.0, 0.15, 1.0)
	return [
		["Economic growth", w * clampf((float(s.avg_growth) - float(s.trend)) * 6.0 + 4.0, -20.0, 20.0)],
		["People's happiness", w * clampf((float(s.happiness_end) - float(s.happiness_start)) * 1.2, -20.0, 20.0)],
		["Public debt", w * clampf(-(float(s.debt_end) - float(s.debt_start)) * 0.3, -15.0, 15.0)],
		["Elections won" if int(s.get("reviews_passed", 0)) == 0 else "Mandates renewed",
			minf((float(s.elections_won) + float(s.get("reviews_passed", 0))) * 6.0, 24.0)],
		["Time in office", minf(years * 1.5, 15.0)],
		["National goals reached", minf(float(s.get("goals_done", 0)) * 3.0, 15.0)],
		["Final approval", clampf((float(s.approval) - 45.0) * 0.4, -8.0, 8.0)],
		["Short term", -12.0 * (1.0 - w)],
	] + ([["Peaceful handover", HANDOVER_LEGACY]] if str(s.get("reason", "")) == "retired" else [])


static func legacy_grade(score: float) -> String:
	for g in LEGACY_GRADES:
		if score >= float(g[0]):
			return str(g[1])
	return "F"


# ---------------------------------------------------------- CREDIT RATING ---
## Score → letter grade. Weights were fitted (grid search) so the 2025 starting
## values of 30 countries land within ~1 notch of their real S&P ratings on
## average, while keeping debt and deficits meaningful for play.
const RATING_BASE := 70.0
const RATING_DEBT := 0.1          # per pt of debt above 40 % of GDP
const RATING_DEFICIT := 2.0       # per pt of deficit above 3 % of GDP
const RATING_STABILITY := 1.1     # per pt of stability below 50
const RATING_INFLATION := 0.5     # per pt of inflation above 5 % (capped at 60 pts)
const RATING_GROWTH := 1.0        # per pt growth vs 2 % (±2 pts)
const RATING_WEALTH := 25.0       # times income level (0..1)
const RATING_GRADES := [[88.0, "AAA"], [78.0, "AA"], [68.0, "A"], [58.0, "BBB"], [48.0, "BB"],
	[38.0, "B"], [28.0, "CCC"], [18.0, "CC"], [-INF, "C"]]


static func rating_parts(debt_pct: float, deficit_pct: float, stability: float, inflation: float,
		growth: float, gdp_pc: float) -> Array:
	return [
		["Starting point", RATING_BASE],
		["Wealth", RATING_WEALTH * income_level(gdp_pc)],
		["Debt", -RATING_DEBT * maxf(0.0, debt_pct - 40.0)],
		["Budget deficit", -RATING_DEFICIT * maxf(0.0, deficit_pct - 3.0)],
		["Stability", -RATING_STABILITY * maxf(0.0, 50.0 - stability)],
		["Inflation", -minf(RATING_INFLATION * maxf(0.0, inflation - 5.0), 60.0)],
		["Growth", RATING_GROWTH * clampf(growth - 2.0, -2.0, 2.0)],
	]


static func rating_grade(score: float) -> String:
	for g in RATING_GRADES:
		if score >= float(g[0]):
			return str(g[1])
	return "C"


## Laffer-shaped revenue share of GDP for a given tax rate (percent).
static func tax_yield(rate: float, k: float) -> float:
	var r := rate / 100.0
	return r * k * (1.0 - LAFFER * r * r)


# ------------------------------------------------------------------ builds ---
## Countable builds (sim/builds.gd): each type's fx is the effect of going from
## 0 to full coverage; this scale makes a build programme about as rewarding per
## dollar as the national projects. Military and CO2 effects are not scaled.
const BUILD_FX_SCALE := 3.5
## Construction capacity: new building work (builds + projects) your builders can
## take on, % of GDP a year, at normal crew speed. Above it, work slows in
## proportion and the construction boom pushes up prices.
const BUILD_CAPACITY_PCT := 2.5
const BUILD_OVERHEAT_INFL := 1.5   # inflation points per 100 % of capacity overload
const BUILD_OVERHEAT_MAX := 4.0
## Rush order: pay this share of a batch's remaining cost again to build it this much faster.
const BUILD_RUSH_PREMIUM := 0.5
const BUILD_RUSH_SPEED := 2.0
## Condition of everything built: drifts toward 1 + (infrastructure budget share
## change, points) / BUILD_COND_PER_POINT, within MIN..MAX. Worn-out roads and
## hospitals deliver less (their units count times the condition).
const BUILD_COND_PER_POINT := 50.0
const BUILD_COND_MIN := 0.9
const BUILD_COND_MAX := 1.04
const BUILD_COND_ADJUST := 1.0 / 30.0


# ---------------------------------------------------------------- research ---
# See sim/tech.gd. Research points (RP) a month.
const RP_PER_RESEARCH := 3.0     # per % of GDP of research effort (spending x research share)
const RP_LABS := 4.0             # at full university and lab coverage
const RP_SCALE := 1.5            # per factor of 10 in GDP above $10B (big economies research more)
const RP_AI_SPACE := 4.0         # AI powers' space-race points a month at a $1T economy


# --------------------------------------------------------------------- war ---
# See sim/war.gd. Shares are of a country's territory (0..1).
const WAR_DECLARE_CAPITAL := 30.0
const WAR_REACH_MIL := 70.0          # military needed to fight a non-neighbour overseas
const WAR_ALLY_JOIN_RELATION := 55.0
const WAR_ALLY_SHARE := 0.35         # share of allies' military that fights with you
const WAR_DEFENDER_BONUS := 1.25
const WAR_FAR_PENALTY := 0.7
const WAR_MOBILIZE_BOOST := 1.25
const WAR_MOBILIZE_MONTHS := 6
const WAR_MOBILIZE_CAPITAL := 10.0
const WAR_SWING_MIN := 0.01          # ground changing hands per battle
const WAR_SWING_MAX := 0.05
const WAR_MAX_OCC := 0.8
const WAR_BIG_BATTLE := 0.06
const WAR_MORALE_HIT := 0.06
const WAR_MORALE_GAIN := 0.02
const WAR_WEARINESS := 0.012         # morale lost every month of war
const WAR_SURRENDER_OCC := 0.45      # holding this much forces peace talks
const WAR_ANNEX_SHARE := 0.6         # share of occupied land kept in an annexing peace
const WAR_REPARATIONS := 0.03        # of the loser's GDP
const WAR_RALLY := 6.0               # approval: rally round the flag
const WAR_WEARY_APPROVAL := 0.25     # approval lost per month after the first six
const WAR_GROWTH := 1.2              # growth points lost per war (scaled by enemy size)
const WAR_INFLATION := 1.0
const WAR_COST_PCT := 2.0            # % of GDP a year
const WAR_WORLD_ANGER := 8.0         # relations lost with everyone when you attack
const WAR_ANNEX_ANGER := 10.0
const WAR_SYMPATHY := 5.0            # relations gained when you are attacked
const WAR_AI_HOSTILITY := -70.0      # relations at or below which a neighbour may attack
const WAR_AI_ADVANTAGE := 1.4        # ... if its military is this much stronger
const WAR_AI_CHANCE := 0.003         # monthly chance then
const WORLD_WAR_CHANCE := 0.025      # monthly chance a war breaks out between two other countries
const WORLD_WARS_MAX := 3            # at most this many at once


# ---------------------------------------------------------------- security ---
# See sim/security.gd. Military strength is the 0-100 index.
## Relations below this count as hostile.
const SEC_HOSTILE := -30.0
## Share of each ally's military that deters threats to you.
const SEC_ALLY_SHARE := 0.35
## Per 10 points of threat beyond deterrence: growth (investors wary) and stability.
const SEC_GROWTH := 0.06
const SEC_STABILITY := 0.6


# -------------------------------------------------------- political capital ---
# See sim/capital.gd. Points 0..CAPITAL_MAX.
const CAPITAL_START := 50.0
const CAPITAL_MAX := 100.0
## Monthly income: BASE + PER_SUPPORT x (support - 45), clamped.
const CAPITAL_BASE := 2.0
const CAPITAL_PER_SUPPORT := 0.12
const CAPITAL_MIN_GAIN := 0.5
const CAPITAL_MAX_GAIN := 4.5
## One-off boosts.
const CAPITAL_ELECTION_WIN := 25.0
const CAPITAL_MANDATE_RENEWED := 15.0
const CAPITAL_GOAL := 6.0
## Costs. A law costs BASE - PER_POLITICS x its politics score (backlash raises it).
const CAPITAL_LAW_BASE := 12.0
const CAPITAL_LAW_PER_POLITICS := 3.0
const CAPITAL_RESHUFFLE := 10.0
const CAPITAL_CRACKDOWN := 20.0
const CAPITAL_MEDIA_CONTROL := 20.0   # per step toward state control of the media
const CAPITAL_FIRM_REFORM := 10.0     # professional managers for a state firm


# ------------------------------------------------------------ intelligence ---
# See sim/intel.gd. Per budget level (Small, Standard, Large, Massive):
const INTEL_COST := [0.03, 0.08, 0.18, 0.35]       # % of GDP a year (Standard is the baseline)
const INTEL_LEVEL_MULT := [0.6, 1.0, 1.35, 1.7]   # agency strength multiplier
const INTEL_MAX_OPS := [1, 2, 3, 4]               # operations at once
const INTEL_WAR_EDGE := 1.15                      # war strength vs a country you've studied
const INTEL_TECH_POINTS := 25.0                   # research points from a successful theft (scaled by their wealth)
const INTEL_SABOTAGE_GROWTH := 1.0                # one-off growth hit
const INTEL_SABOTAGE_MIL := 3.0                   # military strength points
const INTEL_MEDDLE_REL := 18.0
const INTEL_REBELS_STAB := 10.0
const INTEL_EXPOSED_REL := 35.0                   # relations lost with the target when caught
const INTEL_EXPOSED_FRIENDS := 6.0                # with its friendly neighbours
const INTEL_EXPOSED_APPROVAL := 2.0
const INTEL_FOREIGN_CHANCE := 0.06                # monthly chance a hostile country spies on you


# -------------------------------------------------------- state firms & fund ---
# See sim/enterprise.gd.
const ENT_RETURN := 0.08           # yearly profit of a well-run firm, share of its value
const ENT_PAYOUT := 0.6            # share of profit paid to the state as dividends
const ENT_EFF_BASE := 0.4          # state-firm efficiency at a clean score of 0 ...
const ENT_EFF_CLEAN := 0.4         # ... plus this much at a clean score of 100
const ENT_EFF_MAX := 0.95
const ENT_REFORM_GAIN := 0.15
const ENT_TAKEOVER_PREMIUM := 1.2  # buying out private owners costs a premium
const ENT_SELL_APPROVAL := 1.5     # one-off approval loss per sale (unions, "selling the family silver")
const ENT_SELL_JOBS := 0.25        # one-off unemployment points per % of GDP sold (layoffs)
const ENT_TAKE_APPROVAL := 1.0     # nationalisation is popular at first
const ENT_SEIZE_GROWTH := 1.5      # one-off growth hit from seizing a firm (investor flight)
const ENT_SEIZE_RELATIONS := 6.0   # relations lost with every democracy
const ENT_SEIZE_CRASH := 0.15      # share-price fall on a seizure
const ENT_PRIV_GROWTH := 0.06      # growth points per % of GDP privatised (efficiency)
const ENT_PRIV_UNEMP := 0.04       # unemployment points per % of GDP privatised (leaner payrolls)
## Markets. Monthly log returns: drift and volatility of world stocks; the home
## index adds growth, interest-rate and stability effects (per point, per year).
const ENT_STOCK_DRIFT := 0.005
const ENT_STOCK_VOL := 0.04
const ENT_BOND_RETURN := 0.03      # yearly
const ENT_SPEND_RULE := 0.03       # "spend the returns": share of the fund paid to the budget a year
const ENT_INDEX_GROWTH := 0.06
const ENT_INDEX_RATES := 0.05
const ENT_INDEX_STABILITY := 0.004
const ENT_WEALTH_HAPPY := 0.8      # happiness points per doubling of the index


# ------------------------------------------------------------------- media ---
# See sim/media.gd. Per step toward state control (free -> guided -> state-run),
# relative to where your country started:
const MEDIA_STEP_APPROVAL := 2.0     # friendlier coverage
const MEDIA_STEP_STABILITY := 1.5
const MEDIA_STEP_HAPPY := 2.0        # people resent being told what to think
const MEDIA_STEP_GROWTH := 0.12      # investors and innovators want open information
const MEDIA_STEP_CLEAN := 5.0        # clean-government target points: a captured press hides graft
const MEDIA_CRACKDOWN_STAB := 4.0    # one-off stability hit per step tightened (x1.5 in free systems)
const MEDIA_CRACKDOWN_APPR := 2.0    # one-off approval hit per step tightened
const MEDIA_DEMOCRACY_REL := 4.0     # relations lost with every democracy per step tightened
const MEDIA_CRED_CAP_GUIDED := 70.0  # most credibility a guided press can have
const MEDIA_CRED_CAP_STATE := 40.0
## Campaign reach by stance, and how a repeat within two years lands.
const MEDIA_REACH_FREE := 0.7
const MEDIA_REACH_GUIDED := 1.0
const MEDIA_REACH_STATE := 1.35
const MEDIA_REPEAT_MULT := 0.6
const MEDIA_CAMPAIGN_MONTHS := 6
const MEDIA_CAMPAIGN_CRED := 3.0     # credibility each campaign costs (health and green are free)
## Smear campaigns: monthly leak chance by stance, and the damage when one leaks.
const MEDIA_LEAK_FREE := 0.12
const MEDIA_LEAK_GUIDED := 0.06
const MEDIA_LEAK_STATE := 0.02
const MEDIA_LEAK_APPR := 6.0
const MEDIA_LEAK_CRED := 15.0
const CAPITAL_TARIFF := 8.0
const CAPITAL_AMEND := 35.0


# ------------------------------------------------------- health & schooling ---
# See sim/outcomes.gd. Effects are gentle and slow, as in reality.
## Years of life expectancy per doubling of health effort (spending x share).
const LIFE_HEALTH := 2.5
## ... and per doubling of real income per person (Preston curve, flattening).
const LIFE_INCOME := 1.5
## Monthly pull toward the target (about a 6-year half-life).
const LIFE_ADJUST := 0.01
## Literacy points per doubling of education effort (scaled by the gap to 100 %).
const LIT_EDUCATION := 8.0
const LIT_ADJUST := 0.008
## Happiness per extra year of life expectancy; growth per literacy point.
const LIFE_HAPPY := 0.6
const LIT_GROWTH := 0.03


# -------------------------------------------------------------- corruption ---
# See sim/corruption.gd (score 0..100).
## Target points per point of stability above / below the start.
const CORR_STABILITY := 0.2
## Monthly pull toward the target (institutions change over years).
const CORR_ADJUST := 0.03
## Growth per 10 points cleaner than at the start (% a year). Mauro (1995) and
## later work: less corruption, more investment and growth.
const CORR_GROWTH := 0.12


# ---------------------------------------------------- central bank independence ---
# When the government sets interest rates itself, markets and households trust
# its inflation promises less (Alesina & Summers 1993; Garriga 2016: more
# independent central banks go with lower, steadier inflation).
## Points added to the government's borrowing costs while the bank is overruled.
const CB_CAPTURE_PREMIUM := 0.6
## Inflation expectations rise this much faster when rates are held too low.
const CB_CAPTURE_EXPECT := 1.6
## Press credibility lost the moment you take control of rates.
const CB_CAPTURE_CRED := -4.0


# ----------------------------------------------------------------- ageing ---
# See sim/ageing.gd.
## Points of 65+ share added per year, from the poorest to the richest countries.
const AGEING_RATE_MIN := 0.08
const AGEING_RATE_MAX := 0.38
## Young migrants slow ageing: points per year per extra migrant per 1,000.
const AGEING_MIGRANT_RELIEF := 0.02
## Public pension and care spending per point of 65+ share (% of GDP). OECD
## Pensions at a Glance 2023: public pension spending is about 0.5 x the old-age
## share across members; we use a little less as some is already budgeted.
const PENSION_PER_PT := 0.4
## Growth lost per point of 65+ share (a smaller workforce).
const AGEING_GROWTH_DRAG := 0.05
## Raising the pension age (law) cuts both effects by this share.
const PENSION_AGE_RELIEF := 0.4


# -------------------------------------------------------------- inequality ---
# See sim/inequality.gd. Gini points per unit of change from the start.
## Welfare: per extra 1 % of GDP spent (OECD: transfers cut market-income Gini
## by about 1 point per 1 % of GDP on average across member countries).
const GINI_WELFARE := 1.0
## Income tax: per percentage point of the (mostly progressive) income-tax rate.
const GINI_INCOME_TAX := 0.12
## Joblessness: per point of unemployment above the start.
const GINI_UNEMP := 0.35
## Monthly pull toward the target (inequality moves over years, not months).
const GINI_ADJUST := 0.025
## Happiness and stability lost per Gini point above the start (gained below it).
const INEQ_HAPPY := 0.35
const INEQ_STABILITY := 0.3


# --------------------------------------------------------------- migration ---
# See sim/migration.gd. Rates are net migrants per 1,000 people a year.
## Starting rates and changes are capped (war-time outflows like Ukraine's
## -31 would otherwise dominate the model).
const MIG_CAP := 15.0
## Pull and push, compared with the start: per doubling of real income, per 10
## points of happiness, per 10 points of lost stability, per point of extra
## unemployment. (Gallup potential-migration surveys: income and safety lead.)
const MIG_INCOME := 1.0
## World real income growth that a country's own is compared against (% / 100).
const MIG_WORLD_GROWTH := 0.02
const MIG_HAPPY := 0.8
const MIG_UNREST := 1.2
const MIG_JOBS := 0.4
## Laws: points-based skilled visas add arrivals; tougher borders cut them.
const MIG_VISAS := 2.0
const MIG_BORDER := 1.5
## Growth per extra migrant per 1,000 people a year (% a year). IMF WEO 2020
## ch. 4: a 1 pt rise in the migrant share of employment lifts output about
## 1 % within five years. Ageing countries gain 1.5x (Migration.growth_effect).
const MIG_GROWTH := 0.06
## Short-run joblessness per extra arrival per 1,000 (% points; fades as the
## economy adjusts through Simulation's unemployment hysteresis).
const MIG_UNEMP := 0.03


# ------------------------------------------------------------- term limits ---
# See Government.TERM_LIMITS and Politics.
## Months before the last allowed election when the player must choose.
const TERM_LIMIT_NOTICE := 12
## A new candidate is less known: approval counts this much less at their first vote.
const SUCCESSOR_PENALTY := 3.0
## Changing the constitution to run again: chance = (approval - BASE) / SPAN, clamped.
const AMEND_BASE := 30.0
const AMEND_SPAN := 40.0
const AMEND_MIN := 0.1
const AMEND_MAX := 0.8
## Legacy bonus for stepping down when the constitution says so.
const HANDOVER_LEGACY := 6.0


# ----------------------------------------------------------------- climate ---
# Used by sim/climate.gd. Starting CO2 per person and the renewable share are
# real (World Bank EN.GHG.CO2.PC.CE.AR5 and EG.FEC.RNEW.ZS, see data/SOURCES.md).

## Emissions per person rise with real income. Cross-country studies put the
## income elasticity of CO2 per person around 0.5-0.8; we use the low end
## because richer countries also clean up faster.
const CO2_INCOME_ELASTICITY := 0.6
## Carbon intensity falls on its own as technology improves: world CO2 per
## dollar of GDP fell about 2 % a year in 2010-2023 (Global Carbon Budget).
const CO2_DECARB_PER_YEAR := 0.02
## The renewable share creeps up by itself (world: about +0.4 pts a year, IEA).
const RENEWABLES_DRIFT_PER_YEAR := 0.4
## Human-made warming above pre-industrial: 1.36 C in 2024, rising 0.27 C a
## decade at today's emissions (Forster et al., Indicators of Global Climate
## Change 2024). The yearly rise scales with the world's total emissions.
const WARMING_2024 := 1.36
const WARMING_PER_YEAR := 0.027
## Weather disasters (floods, storms, heat, drought) get this much more likely
## per degree of warming beyond the start. IPCC AR6: hot extremes are already
## several times more frequent; we stay gentle so the game remains calm.
const CLIMATE_DISASTER_PER_DEG := 1.0
## Energy transitions take years: a green law or project reaches its full cut
## in emissions (and its oil-shock shield) this many months after it starts working.
const CLIMATE_RAMP_MONTHS := 48
## Climate pledges made at a COP: years until judged, and the two sizes offered.
const PLEDGE_YEARS := 6
const PLEDGE_BOLD := 0.25
const PLEDGE_MODEST := 0.10
