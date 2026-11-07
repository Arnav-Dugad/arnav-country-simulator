class_name GameEvents
extends RefCounted
## Random events. Each has a condition, a weight, and 2–3 choices with real
## tradeoffs. Effects (applied by apply_effects):
##   growth / inflation / unemployment / happiness / approval / stability:
##       half applied immediately, full value as a decaying shock (see Economy.SHOCK_DECAY)
##   cost:      one-off spend, % of GDP (taken from the treasury)
##   gdp:       permanent change to GDP level, %
##   rate:      change to the interest rate, pts
##   corp_tax / income_tax / spending: policy changes, pts
##   share_research / share_health …: budget share change, pts
##   relation:  change in relations with the event's other country
##   deal / sanction_me: diplomacy outcomes with the other country

## Chance per month that a random event fires (if none is pending).
const MONTHLY_CHANCE := 0.16
const MIN_GAP_MONTHS := 3

const EVENTS := [
	{"id": "recession", "title": "Global slowdown", "icon": "trending-down", "tint": "orange", "weight": 2.3,
		"body": "Demand is falling across the world and {country}'s exporters are cutting jobs. Economists warn of a recession.",
		"choices": [
			{"label": "Stimulus package", "detail": "Costs 2% of GDP · supports growth and jobs",
				"effects": {"cost": 2.0, "growth": 1.6, "unemployment": -0.8, "approval": 2.0, "inflation": 0.6}},
			{"label": "Cut interest rates", "detail": "Rate −1 pt · cheaper money, some inflation",
				"effects": {"rate": -1.0, "growth": 0.8, "inflation": 0.8}},
			{"label": "Ride it out", "detail": "No cost · growth and jobs suffer",
				"effects": {"growth": -1.8, "unemployment": 1.2, "approval": -3.0}}],
		"next": {"id": "recovery_boom", "in": 12}},
	{"id": "floods", "title": "Severe floods", "icon": "cloud", "tint": "teal", "weight": 2.0,
		"body": "Days of rain have flooded towns and farmland across {country}. Thousands are displaced.",
		"choices": [
			{"label": "Full relief effort", "detail": "Costs 0.8% of GDP · people feel protected",
				"effects": {"cost": 0.8, "happiness": 2.0, "approval": 4.0, "growth": -0.3}},
			{"label": "Limited aid", "detail": "Costs 0.2% of GDP · resentment grows",
				"effects": {"cost": 0.2, "happiness": -3.0, "approval": -4.0, "growth": -0.6}},
			{"label": "Ask allies for help", "detail": "Needs an ally · small cost, some pride lost",
				"needs": "ally", "effects": {"cost": 0.25, "approval": 1.0, "stability": -1.0, "growth": -0.4}}]},
	{"id": "tech_boom", "title": "Tech boom", "icon": "zap", "tint": "accent", "weight": 1.6,
		"body": "Start-ups in {country} are attracting record investment. Valuations are soaring.",
		"choices": [
			{"label": "Tax the windfall", "detail": "Corporate tax +2 pts · more revenue, slower boom",
				"effects": {"corp_tax": 2.0, "growth": 0.4, "approval": 1.0}},
			{"label": "Let it run", "detail": "Growth now · prices heat up",
				"effects": {"growth": 1.6, "inflation": 0.9, "happiness": 1.0}},
			{"label": "Fund research", "detail": "Research share +2 pts · lasting growth",
				"effects": {"share_research": 2.0, "growth": 0.8, "cost": 0.1}}]},
	{"id": "protests", "title": "Cost-of-living protests", "icon": "users", "tint": "red", "weight": 2.5,
		"cond": "unhappy",
		"body": "Crowds fill the streets of {country}'s cities, angry about prices and wages.",
		"choices": [
			{"label": "Offer concessions", "detail": "Costs 0.5% of GDP · calms the streets",
				"effects": {"cost": 0.5, "approval": 4.0, "stability": 4.0, "happiness": 2.0}},
			{"label": "Open talks", "detail": "No cost · slow to cool down",
				"effects": {"approval": 1.0, "stability": -2.0}},
			{"label": "Crack down", "detail": "Order restored · deep resentment, allies object",
				"effects": {"stability": 3.0, "approval": -7.0, "happiness": -4.0, "relations_all": -3.0}}]},
	{"id": "scandal", "title": "Corruption scandal", "icon": "gavel", "tint": "orange", "weight": 2.0,
		"body": "Leaked documents show a senior minister steering contracts to friends.",
		"choices": [
			{"label": "Fire the minister", "detail": "Short-term hit · shows integrity",
				"effects": {"approval": -1.5, "stability": 1.0}},
			{"label": "Independent inquiry", "detail": "Small cost · trust slowly returns",
				"effects": {"cost": 0.02, "approval": -0.5, "happiness": 1.0}, "next": {"id": "inquiry_result", "in": 4}},
			{"label": "Stand by them", "detail": "Loyalty kept · public trust falls",
				"effects": {"approval": -6.0, "stability": -2.0}}]},
	{"id": "pandemic", "title": "New virus spreading", "icon": "activity", "tint": "red", "weight": 0.6,
		"body": "A fast-spreading respiratory virus has reached {country}. Hospitals are filling.",
		"choices": [
			{"label": "Lockdown", "detail": "Saves lives · economy stalls",
				"effects": {"growth": -3.5, "unemployment": 2.2, "happiness": -3.0, "approval": 3.0}},
			{"label": "Targeted measures", "detail": "Balanced · some strain on hospitals",
				"effects": {"growth": -1.2, "happiness": -2.0, "approval": -1.0}},
			{"label": "Mass vaccination drive", "detail": "Costs 1% of GDP · fastest recovery",
				"effects": {"cost": 1.0, "growth": -0.6, "approval": 3.0, "share_health": 1.5}}],
		"next": {"id": "vaccine_race", "in": 5}},
	{"id": "oil_shock", "title": "Oil price spike", "icon": "flame", "tint": "orange", "weight": 1.8,
		"body": "Conflict abroad has sent oil prices soaring. Fuel and food costs in {country} are climbing.",
		"choices": [
			{"label": "Subsidise fuel", "detail": "Costs 0.6% of GDP · keeps prices down",
				"effects": {"cost": 0.6, "inflation": 0.6, "approval": 2.0}},
			{"label": "Let prices rise", "detail": "No cost · inflation and anger",
				"effects": {"inflation": 2.4, "approval": -3.0, "happiness": -2.0}},
			{"label": "Raise rates", "detail": "Rate +1 pt · cools prices, slows growth",
				"effects": {"rate": 1.0, "inflation": 1.0, "growth": -0.6}}]},
	{"id": "strike", "title": "General strike", "icon": "construction", "tint": "orange", "weight": 1.5,
		"body": "Unions in {country} have called a nationwide strike over pay.",
		"choices": [
			{"label": "Raise wages", "detail": "Costs 0.3% of GDP · prices tick up",
				"effects": {"cost": 0.3, "inflation": 0.9, "approval": 2.0, "happiness": 1.5}},
			{"label": "Hold firm", "detail": "No cost · lost output and tension",
				"effects": {"growth": -0.9, "approval": -2.0, "stability": -2.0}}]},
	{"id": "resources", "title": "Major resource discovery", "icon": "sparkles", "tint": "gold", "weight": 0.7,
		"body": "Geologists have confirmed large mineral deposits in {country}'s interior.",
		"choices": [
			{"label": "State-owned mining", "detail": "GDP +1.5% · revenue for the treasury",
				"effects": {"gdp": 1.5, "approval": 2.0, "cost": -0.4}},
			{"label": "License private firms", "detail": "GDP +2.5% · faster growth, less control",
				"effects": {"gdp": 2.5, "growth": 0.6, "happiness": -0.5}},
			{"label": "Protect the land", "detail": "No gain · environmental goodwill",
				"effects": {"happiness": 2.0, "approval": 1.0}}]},
	{"id": "investment", "title": "Foreign investment offer", "icon": "building-2", "tint": "accent", "weight": 1.4,
		"body": "A global manufacturer wants to build a large factory in {country}, asking for tax breaks.",
		"choices": [
			{"label": "Offer tax breaks", "detail": "Corporate tax −1 pt · jobs and growth",
				"effects": {"corp_tax": -1.0, "growth": 0.9, "unemployment": -0.6}},
			{"label": "Decline", "detail": "No change",
				"effects": {}}]},
	{"id": "sports", "title": "Sporting triumph", "icon": "crown", "tint": "gold", "weight": 1.0,
		"body": "{country}'s national team has won a major international tournament. The country is celebrating.",
		"choices": [
			{"label": "Declare a holiday", "detail": "Small output cost · national pride",
				"effects": {"happiness": 3.0, "approval": 3.0, "growth": -0.2}},
			{"label": "Invest in youth sport", "detail": "Costs 0.05% of GDP · lasting goodwill",
				"effects": {"cost": 0.05, "happiness": 2.0, "approval": 1.5}}]},
	{"id": "cyberattack", "title": "Cyberattack", "icon": "lock", "tint": "red", "weight": 1.0,
		"body": "Hackers have disrupted banks and hospitals across {country}.",
		"choices": [
			{"label": "Build cyber defences", "detail": "Costs 0.2% of GDP · security up",
				"effects": {"cost": 0.2, "stability": 2.0, "approval": 1.0}},
			{"label": "Quiet clean-up", "detail": "No cost · risk of more attacks",
				"effects": {"stability": -2.0, "growth": -0.3}}]},
	{"id": "refugees", "title": "Refugees at the border", "icon": "users", "tint": "teal", "weight": 1.0,
		"body": "Thousands fleeing conflict nearby are seeking shelter in {country}.",
		"choices": [
			{"label": "Welcome them", "detail": "Costs 0.2% of GDP · praised abroad",
				"effects": {"cost": 0.2, "relations_all": 2.0, "approval": -1.5, "gdp": 0.2}},
			{"label": "Close the border", "detail": "Popular at home · criticised abroad",
				"effects": {"approval": 1.5, "relations_all": -2.0, "stability": 1.0}}]},
	{"id": "trade_offer", "title": "Trade deal offer", "icon": "handshake", "tint": "green", "weight": 1.6,
		"cond": "friend_without_deal",
		"body": "{other} proposes a free-trade agreement with {country}.",
		"choices": [
			{"label": "Sign the deal", "detail": "Growth up · some local industries object",
				"effects": {"deal": true, "relation": 6.0, "approval": -0.5}},
			{"label": "Decline politely", "detail": "Relations cool slightly",
				"effects": {"relation": -5.0}}]},
	{"id": "sanction_threat", "title": "Sanctions threatened", "icon": "ban", "tint": "red", "weight": 1.4,
		"cond": "hostile",
		"body": "{other} threatens to impose sanctions on {country} unless you change course.",
		"choices": [
			{"label": "Make concessions", "detail": "Relations improve · looks weak at home",
				"effects": {"relation": 15.0, "approval": -3.0}},
			{"label": "Stand firm", "detail": "They sanction you · a rally at home",
				"effects": {"sanction_me": true, "relation": -10.0, "approval": 2.5}}]},
	# ---- Story chains (weight 0: only scheduled by an earlier choice) --------
	{"id": "vaccine_race", "title": "A vaccine is ready", "icon": "stethoscope", "tint": "green", "weight": 0.0,
		"body": "Scientists have a working vaccine against the virus that hit {country}. Supplies are limited.",
		"choices": [
			{"label": "Buy early at a premium", "detail": "Costs 0.4% of GDP · fastest recovery",
				"effects": {"cost": 0.4, "growth": 1.8, "happiness": 3.0, "approval": 3.0}},
			{"label": "Join the global sharing scheme", "detail": "Slower here · goodwill abroad",
				"effects": {"growth": 0.8, "relations_all": 3.0, "approval": 1.0}},
			{"label": "Make our own", "detail": "Costs 0.2% of GDP · research boost, slower start",
				"effects": {"cost": 0.2, "share_research": 1.0, "growth": 0.6, "happiness": 1.0}}]},
	{"id": "inquiry_result", "title": "Inquiry reports back", "icon": "gavel", "tint": "orange", "weight": 0.0,
		"body": "The independent inquiry into the contracts scandal has published its findings.",
		"choices": [
			{"label": "Publish everything", "detail": "Painful now · trust rebuilt",
				"effects": {"approval": -2.0, "stability": 2.0, "happiness": 2.0}},
			{"label": "Act on its advice quietly", "detail": "Steady · little credit",
				"effects": {"stability": 1.0, "approval": 0.5}}]},
	{"id": "recovery_boom", "title": "The economy roars back", "icon": "trending-up", "tint": "green", "weight": 0.0,
		"body": "Pent-up demand after the crisis is flooding shops and factories in {country}.",
		"choices": [
			{"label": "Let it run", "detail": "Fast growth · prices rise",
				"effects": {"growth": 2.0, "inflation": 1.5, "approval": 2.0}},
			{"label": "Lean against it", "detail": "Rate +0.5 pt · steadier recovery",
				"effects": {"rate": 0.5, "growth": 1.0, "inflation": 0.4}}]},
	# ---- Regional events -----------------------------------------------------
	{"id": "monsoon", "title": "Monsoon floods", "icon": "cloud", "tint": "teal", "weight": 2.2,
		"where": ["Southern Asia", "South-Eastern Asia"],
		"body": "An unusually heavy monsoon has flooded farmland and cities across {country}.",
		"choices": [
			{"label": "Emergency relief and rebuilding", "detail": "Costs 0.6% of GDP · people protected",
				"effects": {"cost": 0.6, "happiness": 1.5, "approval": 3.0, "growth": -0.3}},
			{"label": "Build flood defences for the future", "detail": "Costs 1% of GDP · fewer floods later",
				"effects": {"cost": 1.0, "share_infrastructure": 1.0, "approval": 1.0, "growth": -0.4}},
			{"label": "Minimal response", "detail": "No cost · anger and losses",
				"effects": {"growth": -0.9, "happiness": -3.0, "approval": -4.0, "stability": -2.0}}]},
	{"id": "hurricane", "title": "Hurricane makes landfall", "icon": "cloud", "tint": "red", "weight": 2.0,
		"where": ["Caribbean", "Central America", "Northern America", "Melanesia", "Polynesia", "Micronesia"],
		"body": "A powerful storm has torn through {country}'s coast, cutting power to millions.",
		"choices": [
			{"label": "Rebuild stronger", "detail": "Costs 0.8% of GDP · resilient grid",
				"effects": {"cost": 0.8, "approval": 3.0, "growth": -0.2}},
			{"label": "Ask for international aid", "detail": "Small cost · relies on friends",
				"effects": {"cost": 0.2, "relations_all": 1.0, "approval": 0.5, "growth": -0.5}},
			{"label": "Leave it to insurers", "detail": "No cost · slow, uneven recovery",
				"effects": {"growth": -0.8, "happiness": -2.5, "approval": -3.5}}]},
	{"id": "heatwave", "title": "Record heatwave", "icon": "flame", "tint": "orange", "weight": 1.8,
		"where": ["Southern Europe", "Western Europe", "Eastern Europe", "Northern Africa", "Western Asia"],
		"body": "Temperatures above 45 °C are straining hospitals and the power grid in {country}.",
		"choices": [
			{"label": "Cooling centres and alerts", "detail": "Costs 0.1% of GDP · lives saved",
				"effects": {"cost": 0.1, "happiness": 1.0, "approval": 2.0}},
			{"label": "Invest in a greener grid", "detail": "Costs 0.5% of GDP · future-proof",
				"effects": {"cost": 0.5, "share_infrastructure": 0.8, "happiness": 1.5}},
			{"label": "Business as usual", "detail": "No cost · blackouts and anger",
				"effects": {"growth": -0.4, "happiness": -2.0, "approval": -3.0}}]},
	{"id": "earthquake", "title": "Strong earthquake", "icon": "activity", "tint": "red", "weight": 1.2,
		"where": ["Eastern Asia", "South-Eastern Asia", "Western Asia", "South America", "Central America",
			"Southern Europe", "Southern Asia", "Australia and New Zealand"],
		"body": "A magnitude 7 earthquake has shaken {country}. Buildings have collapsed in several towns.",
		"choices": [
			{"label": "Full rescue and rebuild", "detail": "Costs 0.7% of GDP · strong leadership",
				"effects": {"cost": 0.7, "approval": 4.0, "stability": 2.0, "growth": -0.4}},
			{"label": "Accept foreign rescue teams", "detail": "Small cost · goodwill both ways",
				"effects": {"cost": 0.2, "relations_all": 2.0, "approval": 2.0, "growth": -0.6}}]},
	{"id": "drought", "title": "Severe drought", "icon": "flame", "tint": "orange", "weight": 1.6,
		"where": ["Eastern Africa", "Western Africa", "Middle Africa", "Southern Africa", "Northern Africa",
			"Australia and New Zealand", "Southern Asia", "Western Asia"],
		"body": "Two failed rainy seasons have dried out {country}'s farms. Food prices are climbing.",
		"choices": [
			{"label": "Food aid and water trucks", "detail": "Costs 0.4% of GDP · hunger avoided",
				"effects": {"cost": 0.4, "happiness": 1.0, "approval": 2.5, "inflation": 0.5}},
			{"label": "Irrigation programme", "detail": "Costs 0.8% of GDP · protects future harvests",
				"effects": {"cost": 0.8, "share_infrastructure": 1.0, "growth": -0.2}},
			{"label": "Import food on credit", "detail": "Debt +0.5% of GDP · prices calm",
				"effects": {"debt_gdp": 0.5, "inflation": -0.3, "approval": 1.0}}]},
	# ---- Data-driven events ----------------------------------------------------
	{"id": "oil_windfall", "title": "Oil price windfall", "icon": "coins", "tint": "gold", "weight": 2.0,
		"cond": "oil_exporter",
		"body": "Global oil prices have jumped, and money is pouring into {country}'s treasury.",
		"choices": [
			{"label": "Save it in a wealth fund", "detail": "Pays down debt · steady future",
				"effects": {"debt_gdp": -3.0, "growth": 0.3, "approval": 0.5}},
			{"label": "Spend it on the people", "detail": "Popular now · prices rise",
				"effects": {"cost": -1.5, "happiness": 3.0, "approval": 4.0, "inflation": 1.2}},
			{"label": "Diversify the economy", "detail": "New industries · slower payoff",
				"effects": {"cost": -1.0, "share_research": 1.0, "share_education": 1.0, "growth": 0.5}}]},
	{"id": "oil_crash", "title": "Oil prices collapse", "icon": "trending-down", "tint": "red", "weight": 1.6,
		"cond": "oil_exporter",
		"body": "A global glut has sent oil prices tumbling. {country}'s budget has a hole in it.",
		"choices": [
			{"label": "Cut spending", "detail": "Spending −1.5 pts · unpopular",
				"effects": {"spending": -1.5, "approval": -4.0, "growth": -0.8}},
			{"label": "Borrow to fill the gap", "detail": "Debt +2% of GDP · calm for now",
				"effects": {"debt_gdp": 2.0, "growth": -0.6}},
			{"label": "Devalue the currency", "detail": "Exports cheaper · prices jump",
				"effects": {"inflation": 4.0, "growth": -0.2, "approval": -2.0}}],
		"next": {"id": "recovery_boom", "in": 14}},
	{"id": "brain_drain", "title": "Doctors and engineers leaving", "icon": "plane-takeoff", "tint": "orange",
		"weight": 1.3, "cond": "developing",
		"body": "Thousands of {country}'s best-trained young people are moving abroad for higher pay.",
		"choices": [
			{"label": "Pay them to stay", "detail": "Costs 0.3% of GDP · keeps talent",
				"effects": {"cost": 0.3, "growth": 0.3, "happiness": 1.0}},
			{"label": "Train many more", "detail": "Education share +1.5 pts · long-term fix",
				"effects": {"share_education": 1.5, "approval": 1.0}},
			{"label": "Let them go", "detail": "No cost · they send money home",
				"effects": {"growth": -0.3, "happiness": -1.0}}]},
	{"id": "housing", "title": "Housing crisis", "icon": "building-2", "tint": "orange", "weight": 1.4,
		"cond": "rich",
		"body": "Rents in {country}'s cities have doubled in five years. Young people can't afford a home.",
		"choices": [
			{"label": "Build public housing", "detail": "Costs 0.5% of GDP · lasting relief",
				"effects": {"cost": 0.5, "happiness": 2.5, "approval": 3.0, "growth": 0.2}},
			{"label": "Rent controls", "detail": "No cost · fewer new homes later",
				"effects": {"happiness": 1.5, "approval": 2.0, "growth": -0.3}},
			{"label": "Leave it to the market", "detail": "No cost · frustration grows",
				"effects": {"approval": -3.0, "happiness": -2.0}}]},
	{"id": "automation", "title": "Robots on the factory floor", "icon": "zap", "tint": "accent", "weight": 1.2,
		"cond": "rich",
		"body": "AI and robots are replacing jobs across {country}, while profits soar.",
		"choices": [
			{"label": "Retrain workers", "detail": "Costs 0.3% of GDP · smoother change",
				"effects": {"cost": 0.3, "unemployment": -0.6, "growth": 0.4, "approval": 1.5}},
			{"label": "Tax the robots", "detail": "Revenue up · slower adoption",
				"effects": {"corp_tax": 1.5, "growth": -0.2, "approval": 1.0}},
			{"label": "Embrace it fully", "detail": "Big growth · job losses",
				"effects": {"growth": 1.2, "unemployment": 1.2, "approval": -2.0}}]},
	{"id": "games_bid", "title": "Host the world games?", "icon": "crown", "tint": "gold", "weight": 0.6,
		"body": "{country} has been invited to host a major international sporting event.",
		"choices": [
			{"label": "Host it", "detail": "Costs 1% of GDP · pride and tourism",
				"effects": {"cost": 1.0, "happiness": 3.0, "approval": 3.0, "growth": 0.5, "relations_all": 2.0}},
			{"label": "Decline politely", "detail": "No cost",
				"effects": {}}]},
	{"id": "tourism", "title": "Tourism boom", "icon": "plane-takeoff", "tint": "green", "weight": 1.0,
		"body": "{country} is suddenly the world's favourite holiday spot.",
		"choices": [
			{"label": "Invest in airports and hotels", "detail": "Costs 0.3% of GDP · growth lasts",
				"effects": {"cost": 0.3, "growth": 0.8, "unemployment": -0.4}},
			{"label": "Add a tourist tax", "detail": "Revenue up · fewer visitors",
				"effects": {"cost": -0.2, "growth": 0.3}}]},
	# --- Shaped by how the country is governed (see Government) -------------------
	{"id": "coalition_crisis", "title": "Coalition wobbles", "icon": "users", "tint": "orange", "weight": 1.4,
		"cond": "parliamentary",
		"body": "A junior partner in {country}'s governing coalition threatens to walk out over a key bill.",
		"choices": [
			{"label": "Give them a ministry", "detail": "Coalition holds · looks weak",
				"effects": {"stability": 2.0, "approval": -1.0}},
			{"label": "Call their bluff", "detail": "Risky · voters like strength",
				"effects": {"stability": -3.0, "approval": 2.0}},
			{"label": "Water down the bill", "detail": "Peace now · less done",
				"effects": {"stability": 1.0, "growth": -0.2}}]},
	{"id": "budget_standoff", "title": "Budget standoff", "icon": "landmark", "tint": "orange", "weight": 1.3,
		"cond": "presidential",
		"body": "Lawmakers refuse to pass {country}'s budget. A government shutdown looms.",
		"choices": [
			{"label": "Compromise on spending", "detail": "Spending −1 pt · deal done",
				"effects": {"spending": -1.0, "approval": 1.0, "stability": 1.0}},
			{"label": "Govern by decree", "detail": "Gets things moving · critics cry foul",
				"effects": {"approval": 1.0, "stability": -3.0}},
			{"label": "Let it shut down", "detail": "Pressure on them · everyone suffers",
				"effects": {"growth": -0.5, "approval": -3.0}}]},
	{"id": "court_ruling", "title": "Court strikes down a policy", "icon": "scale", "tint": "accent", "weight": 1.0,
		"cond": "democracy",
		"body": "{country}'s highest court rules that one of your policies breaks the constitution.",
		"choices": [
			{"label": "Respect the ruling", "detail": "Rule of law · a small defeat",
				"effects": {"stability": 2.0, "approval": -1.0}},
			{"label": "Attack the judges", "detail": "Rallies supporters · alarms allies",
				"effects": {"approval": 1.5, "stability": -3.0, "relations_all": -1.5}}]},
	{"id": "dissident", "title": "A famous critic is arrested", "icon": "lock", "tint": "red", "weight": 1.3,
		"cond": "autocracy",
		"body": "Police in {country} detain a well-known critic of the government. The world is watching.",
		"choices": [
			{"label": "Release them", "detail": "Goodwill abroad · looks soft at home",
				"effects": {"stability": -2.0, "relations_all": 2.5, "happiness": 1.0}},
			{"label": "House arrest", "detail": "A quiet middle way",
				"effects": {"relations_all": -1.0, "stability": 0.5}},
			{"label": "Long prison sentence", "detail": "Order kept · anger at home and abroad",
				"effects": {"stability": 2.0, "approval": -3.0, "relations_all": -3.5}}]},
	{"id": "democracy_movement", "title": "Students demand elections", "icon": "megaphone", "tint": "orange",
		"weight": 1.2, "cond": "autocracy",
		"body": "Thousands of students march in {country}'s capital calling for free elections.",
		"choices": [
			{"label": "Promise gradual reform", "detail": "Hope rises · expectations too",
				"effects": {"approval": 3.0, "stability": -2.0, "relations_all": 1.0}},
			{"label": "Open a dialogue", "detail": "Buys time",
				"effects": {"approval": 1.0, "stability": -0.5}},
			{"label": "Disperse the crowds", "detail": "Order restored · deep resentment",
				"effects": {"stability": 3.0, "approval": -5.0, "happiness": -2.0, "relations_all": -4.0}}]},
	{"id": "succession", "title": "Succession question", "icon": "crown", "tint": "gold", "weight": 0.9,
		"cond": "monarchy",
		"body": "Rival branches of {country}'s royal family quarrel over who should be the next heir.",
		"choices": [
			{"label": "Name an heir now", "detail": "Certainty · some royals sulk",
				"effects": {"stability": 3.0, "approval": 1.0}},
			{"label": "Let the council decide", "detail": "Slower, more legitimate",
				"effects": {"stability": 1.0, "approval": 2.0, "growth": -0.1}},
			{"label": "Delay the decision", "detail": "Uncertainty lingers",
				"effects": {"stability": -2.5}}]},
	{"id": "generals", "title": "The generals want more", "icon": "shield", "tint": "red", "weight": 1.3,
		"cond": "army",
		"body": "Senior officers in {country} demand a bigger budget and more say in government.",
		"choices": [
			{"label": "Raise the army's budget", "detail": "Military share +3 pts · loyalty bought",
				"effects": {"share_military": 3.0, "stability": 2.0, "cost": 0.2}},
			{"label": "Promote loyal officers", "detail": "A reshuffle at the top",
				"effects": {"stability": 1.0, "approval": -1.0}},
			{"label": "Refuse", "detail": "Asserts control · risky",
				"effects": {"stability": -3.0, "approval": 1.5}}]},
	{"id": "party_purge", "title": "Graft inside the party", "icon": "gavel", "tint": "orange", "weight": 1.2,
		"cond": "one_party",
		"body": "Investigators find officials of {country}'s ruling party taking bribes on a large scale.",
		"choices": [
			{"label": "A sweeping clean-up", "detail": "Popular · officials grow cautious",
				"effects": {"approval": 3.0, "stability": -1.0, "growth": -0.2}},
			{"label": "Quiet warnings", "detail": "No fuss · the rot stays",
				"effects": {"approval": -1.5}},
			{"label": "Target your rivals", "detail": "Power secured · cynicism grows",
				"effects": {"stability": 2.0, "approval": -2.0, "happiness": -1.0}}]},
	{"id": "observers", "title": "Election observers", "icon": "search", "tint": "accent", "weight": 1.0,
		"cond": "managed",
		"body": "International monitors ask to observe {country}'s next election.",
		"choices": [
			{"label": "Welcome them", "detail": "Credibility abroad · less control",
				"effects": {"relations_all": 3.0, "stability": -1.0}},
			{"label": "Say no", "detail": "Raised eyebrows abroad",
				"effects": {"relations_all": -2.0, "stability": 1.0}}]},
	{"id": "royal_wedding", "title": "A royal wedding", "icon": "heart", "tint": "gold", "weight": 0.7,
		"cond": "royals",
		"body": "{country}'s royal family announces a wedding. The whole country is excited.",
		"choices": [
			{"label": "A grand public celebration", "detail": "Costs 0.05% of GDP · joy and tourists",
				"effects": {"cost": 0.05, "happiness": 2.5, "approval": 1.5, "growth": 0.1}},
			{"label": "Keep it modest", "detail": "No cost · respectful",
				"effects": {"approval": 0.5}}]},
	# --- Shaped by the country itself -----------------------------------------------
	{"id": "pensions", "title": "Pension funds run short", "icon": "users", "tint": "orange", "weight": 1.3,
		"cond": "ageing",
		"body": "{country} has more retirees every year, and the pension system can no longer pay its way.",
		"choices": [
			{"label": "Raise contributions", "detail": "Income tax +1 pt · fair but felt",
				"effects": {"income_tax": 1.0, "approval": -2.0}},
			{"label": "Borrow to cover it", "detail": "Debt +1.5% of GDP · no pain today",
				"effects": {"debt_gdp": 1.5}},
			{"label": "Trim benefits", "detail": "Saves money · pensioners are furious",
				"effects": {"cost": -0.3, "happiness": -2.0, "approval": -3.5}}]},
	{"id": "blackout", "title": "Nationwide blackout", "icon": "plug-zap", "tint": "red", "weight": 1.4,
		"cond": "weak_power",
		"body": "The power grid collapses across {country}. Factories stop and cities go dark.",
		"choices": [
			{"label": "Emergency generators", "detail": "Costs 0.3% of GDP · lights back on",
				"effects": {"cost": 0.3, "approval": 1.0, "growth": -0.2}},
			{"label": "Ration power", "detail": "No cost · businesses suffer",
				"effects": {"growth": -0.6, "happiness": -2.0, "approval": -2.0}}]},
	{"id": "youth_jobs", "title": "Young and jobless", "icon": "graduation-cap", "tint": "orange", "weight": 1.2,
		"cond": "young",
		"body": "Millions of young people are entering {country}'s job market, and there aren't enough jobs.",
		"choices": [
			{"label": "Apprenticeship drive", "detail": "Costs 0.3% of GDP · skills and jobs",
				"effects": {"cost": 0.3, "unemployment": -0.6, "growth": 0.2}},
			{"label": "Public works", "detail": "Costs 0.5% of GDP · jobs now",
				"effects": {"cost": 0.5, "unemployment": -0.9, "approval": 1.5}},
			{"label": "Let the market sort it out", "detail": "No cost · frustration grows",
				"effects": {"stability": -2.0, "approval": -2.0}}]},
	{"id": "overrun", "title": "Contractors want more", "icon": "construction", "tint": "orange", "weight": 1.5,
		"cond": "building",
		"body": "The builders of {country}'s {project} say costs have soared and demand more money.",
		"choices": [
			{"label": "Pay up", "detail": "Costs 0.15% of GDP · work goes on",
				"effects": {"cost": 0.15}},
			{"label": "Renegotiate", "detail": "No extra cost · four months' delay",
				"effects": {"project_delay": 4.0}},
			{"label": "Investigate the contract", "detail": "Popular · six months' delay",
				"effects": {"project_delay": 6.0, "approval": 1.0}}]},
	# --- Crises in stages: your first answer decides what comes next ------------------
	{"id": "bank_wobble", "title": "A big bank wobbles", "icon": "landmark", "tint": "orange", "weight": 1.2,
		"cond": "bank_risk",
		"body": "One of {country}'s largest banks admits to heavy losses. Savers are nervous.",
		"choices": [
			{"label": "Guarantee all deposits", "detail": "Costs 0.3% of GDP · calm returns",
				"effects": {"cost": 0.3, "stability": 1.0}},
			{"label": "Order a quiet merger", "detail": "No cost now · may not hold",
				"effects": {"growth": -0.2}, "next": {"id": "bank_run", "in": 3}},
			{"label": "Let it fail", "detail": "Discipline · risky",
				"effects": {"growth": -0.6, "approval": -2.0}, "next": {"id": "bank_run", "in": 2}}]},
	{"id": "bank_run", "title": "Bank run", "icon": "alert", "tint": "red", "weight": 0.0,
		"body": "Queues stretch around bank branches across {country}. The panic is spreading to other banks.",
		"choices": [
			{"label": "Close the banks for a week", "detail": "Stops the panic · business stalls",
				"effects": {"growth": -1.2, "stability": 2.0, "approval": -3.0}},
			{"label": "Central bank lends without limit", "detail": "Panic eases · inflation risk",
				"effects": {"inflation": 1.5, "growth": -0.4}, "next": {"id": "bailout_vote", "in": 4}},
			{"label": "Ride it out", "detail": "No cost · could get much worse",
				"effects": {"growth": -2.0, "unemployment": 1.2, "stability": -4.0, "approval": -5.0}}]},
	{"id": "bailout_vote", "title": "The bailout bill", "icon": "gavel", "tint": "orange", "weight": 0.0,
		"body": "Rescuing the banks for good will cost billions. Taxpayers are furious; markets are watching.",
		"choices": [
			{"label": "Full bailout", "detail": "Costs 2% of GDP · banks are safe",
				"effects": {"cost": 2.0, "growth": 0.8, "approval": -4.0, "stability": 2.0}},
			{"label": "Bail out, but take ownership", "detail": "Costs 1.2% of GDP · popular",
				"effects": {"cost": 1.2, "growth": 0.5, "approval": 2.0}},
			{"label": "Make the bondholders pay", "detail": "No cost · investors flee",
				"effects": {"debt_rate": 1.0, "growth": -0.5, "approval": 3.0}}]},
	{"id": "currency_slide", "title": "The currency slides", "icon": "trending-down", "tint": "orange", "weight": 1.2,
		"cond": "currency_risk",
		"body": "{country}'s currency has lost a tenth of its value in a month. Import prices are rising.",
		"choices": [
			{"label": "Raise interest rates sharply", "detail": "Rate +2 pts · defends the currency",
				"effects": {"rate": 2.0, "growth": -0.6, "inflation": -0.5}},
			{"label": "Spend reserves to defend it", "detail": "Costs 0.5% of GDP · buys time",
				"effects": {"cost": 0.5}, "next": {"id": "currency_crisis", "in": 4}},
			{"label": "Let it fall", "detail": "Exports get cheaper · prices jump",
				"effects": {"inflation": 2.5, "growth": 0.3}, "next": {"id": "currency_crisis", "in": 6}}]},
	{"id": "currency_crisis", "title": "Currency crisis", "icon": "flame", "tint": "red", "weight": 0.0,
		"body": "The currency is in free fall and fuel is running short in {country}. Lenders want guarantees.",
		"choices": [
			{"label": "Call in the IMF", "detail": "Tough conditions · stability returns",
				"effects": {"spending": -2.0, "approval": -5.0, "stability": 2.0, "inflation": -2.0},
				"next": {"id": "imf_review", "in": 12}},
			{"label": "Capital controls", "detail": "Stops money leaving · investors angry",
				"effects": {"growth": -1.0, "inflation": 1.0, "relations_all": -1.5}},
			{"label": "Print money to pay bills", "detail": "Easy now · prices explode",
				"effects": {"inflation": 8.0, "approval": -3.0, "stability": -3.0}}]},
	{"id": "imf_review", "title": "IMF review", "icon": "search", "tint": "accent", "weight": 0.0,
		"body": "The IMF checks whether {country} kept its promises. A good report unlocks cheaper loans.",
		"choices": [
			{"label": "Show the reforms", "detail": "Borrowing gets cheaper",
				"effects": {"debt_rate": -1.5, "growth": 0.4, "approval": -1.0}},
			{"label": "Ask for more time", "detail": "Patience has limits",
				"effects": {"debt_rate": 0.5, "approval": 1.0}}]},
	{"id": "heat_grid", "title": "Heat strains the grid", "icon": "plug-zap", "tint": "orange", "weight": 1.0,
		"cond": "hot",
		"body": "A long heatwave has air conditioners running flat out across {country}. The grid is near its limit.",
		"choices": [
			{"label": "Rolling blackouts now", "detail": "Controlled · unpopular",
				"effects": {"approval": -2.0, "growth": -0.2}},
			{"label": "Import emergency power", "detail": "Costs 0.2% of GDP",
				"effects": {"cost": 0.2}},
			{"label": "Hope it holds", "detail": "No cost · it may not",
				"effects": {}, "next": {"id": "blackout", "in": 1}}]},
	{"id": "debt_crisis", "title": "Bond markets panic", "icon": "alert", "tint": "red", "weight": 0.0,
		"body": "Investors are dumping {country}'s government bonds. Borrowing costs are spiking.",
		"choices": [
			{"label": "IMF programme", "detail": "Spending −3 pts · stability returns",
				"effects": {"spending": -3.0, "approval": -6.0, "growth": -1.0, "stability": 2.0, "debt_rate": -2.0}},
			{"label": "Austerity budget", "detail": "Spending −2, income tax +2 · deeply unpopular",
				"effects": {"spending": -2.0, "income_tax": 2.0, "approval": -8.0, "growth": -0.8}},
			{"label": "Print money", "detail": "Inflation erodes the debt · prices explode",
				"effects": {"inflation": 9.0, "debt_gdp": -8.0, "approval": -4.0, "stability": -4.0}}]},
]


## UN General Assembly votes: each pleases one camp and annoys another.
const UN_VOTES := [
	{"id": "un_sanctions", "title": "UN vote: sanctions on an aggressor", "body": "The General Assembly votes to condemn an invasion and back sanctions. Everyone is watching how {country} votes.",
		"choices": [{"label": "Vote yes", "effects": {"bloc_relations": {"west": 4.0, "east": -4.0}}},
			{"label": "Abstain", "effects": {"bloc_relations": {"west": -1.0, "east": 1.0}}},
			{"label": "Vote no", "effects": {"bloc_relations": {"west": -5.0, "east": 4.0}}}]},
	{"id": "un_climate", "title": "UN vote: climate finance", "body": "Poorer countries ask the rich to pay into a fund for climate damage.",
		"choices": [{"label": "Vote yes and pledge money", "effects": {"cost": 0.05, "bloc_relations": {"south": 4.0}, "happiness": 0.5}},
			{"label": "Vote yes, pledge nothing", "effects": {"bloc_relations": {"south": 1.5}}},
			{"label": "Vote no", "effects": {"bloc_relations": {"south": -4.0, "west": 0.5}}}]},
	{"id": "un_ceasefire", "title": "UN vote: a ceasefire call", "body": "A resolution demands an immediate ceasefire in a bloody war.",
		"choices": [{"label": "Vote yes", "effects": {"bloc_relations": {"south": 3.0, "east": 1.0, "west": -1.0}, "happiness": 0.5}},
			{"label": "Abstain", "effects": {"bloc_relations": {"south": -1.0}}}]},
	{"id": "un_rights", "title": "UN vote: human rights inquiry", "body": "A resolution would send investigators to look into abuses by a government.",
		"choices": [{"label": "Vote yes", "effects": {"bloc_relations": {"west": 3.0, "east": -2.0}}},
			{"label": "Vote no: no meddling", "effects": {"bloc_relations": {"west": -3.0, "east": 2.0, "south": 1.0}}}]},
	{"id": "un_ocean", "title": "UN vote: protect the high seas", "body": "A treaty would make a third of the world's oceans protected areas.",
		"choices": [{"label": "Vote yes", "effects": {"relations_all": 1.0, "happiness": 0.5, "growth": -0.05}},
			{"label": "Vote no: fishing jobs first", "effects": {"relations_all": -1.0, "unemployment": -0.1}}]},
	{"id": "un_ai", "title": "UN vote: rules for artificial intelligence", "body": "The first global rules for powerful AI systems are put to a vote.",
		"choices": [{"label": "Vote yes", "effects": {"bloc_relations": {"west": 1.5, "south": 1.0}, "growth": -0.03}},
			{"label": "Vote no: don't slow innovation", "effects": {"bloc_relations": {"west": -1.0}, "growth": 0.05}}]},
]


static func un_vote(rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = UN_VOTES[rng.randi() % UN_VOTES.size()].duplicate(true)
	e.merge({"icon": "globe", "tint": "accent", "weight": 0.0})
	return instance(e)


## A disaster abroad: the other country's leader asks you for help.
static func aid_request(i: int, kind: String) -> Dictionary:
	var ld := Leaders.leader(i)
	var them: CountryState = Game.state(i)
	var big := them != null and them.gdp > Game.me().gdp * 0.5
	var what: String = {"hurricane": "a hurricane", "monsoon": "monsoon floods", "heatwave": "a deadly heatwave",
		"earthquake": "an earthquake", "drought": "a drought", "floods": "floods"}.get(kind, "a disaster")
	var e := {"id": "aid_request", "title": "%s asks for help" % World.map.names[i], "icon": "hand-coins",
		"tint": "teal", "weight": 0.0, "face": str(ld.portrait), "scene_hint": kind,
		"body": "%s, %s of %s, calls you after %s: \"Our people need help. Can we count on {country}?\"" % [
			str(ld.name), str(ld.title).to_lower(), World.map.names[i], what],
		"choices": [
			{"label": "Send generous aid", "detail": "Costs 0.08% of GDP · a friend for life",
				"effects": {"cost": 0.08, "relation": 14.0, "happiness": 0.3}},
			{"label": "Send rescue teams and supplies", "detail": "Costs 0.02% of GDP",
				"effects": {"cost": 0.02, "relation": 7.0}},
			{"label": "Send condolences", "detail": "No cost" + (" · they'll remember" if not big else ""),
				"effects": {"relation": -3.0 if not big else -1.0}}]}
	return instance(e, i)


## A yearly summit: pick the agenda you push.
static func summit(rng: RandomNumberGenerator) -> Dictionary:
	var name := Treaties.summit_name()
	var host := World.map.names[World.playable[rng.randi() % World.playable.size()]]
	var e := {"id": "summit", "title": "%s summit" % name.capitalize() if name == "regional" else "%s summit" % name,
		"icon": "users", "tint": "gold", "weight": 0.0,
		"body": "Leaders meet in %s. What will {country} push for?" % host,
		"choices": [
			{"label": "Trade and investment", "effects": {"growth": 0.3, "bloc_relations": {"region": 2.0}}},
			{"label": "Climate action", "effects": {"happiness": 1.0, "bloc_relations": {"south": 2.0}}},
			{"label": "Security", "effects": {"stability": 1.5, "bloc_relations": {"west": 1.0, "east": -1.0}}},
			{"label": "Help for poorer countries", "effects": {"cost": 0.04, "bloc_relations": {"south": 3.5}, "approval": 0.5}}]}
	return instance(e)


static func tint(name: String) -> Color:
	return {"orange": DS.ORANGE, "teal": DS.TEAL, "accent": DS.ACCENT, "red": DS.RED, "gold": DS.GOLD,
		"green": DS.GREEN}.get(name, DS.ACCENT)


static func by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e.id == id:
			return e
	return {}


## Picks a random eligible event (or {} if none). Returns an instance with the
## "other" country resolved and the text filled in.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var me := Game.me()
	var pool: Array = []
	var weights: Array[float] = []
	for e in EVENTS:
		var w := float(e.weight)
		if w <= 0.0:
			continue
		var other := -1
		# Natural risks: the researched profile decides where it has one, else the region list.
		var risk_known := Profiles.at_risk(Game.player, str(RISK_OF.get(e.id, "")))
		if risk_known == 0 and RISK_OF.has(e.id):
			continue
		if risk_known != 1 and e.has("where") and not World.map.subregions[Game.player] in e.where:
			continue
		w *= Profiles.event_weight(Game.player, str(e.id))
		match e.get("cond", ""):
			"oil_exporter":
				if float(World.stats[Game.player].get("fuel_exports_pct", 0.0)) < 30.0:
					continue
			"rich":
				if Economy.income_level(me.gdp_per_capita()) < 0.6:
					continue
			"developing":
				if Economy.income_level(me.gdp_per_capita()) > 0.5:
					continue
			"unhappy":
				if me.approval > 45.0 and me.inflation < float(me.base.inflation) + 3.0:
					w *= 0.2
			"friend_without_deal":
				other = _pick_country(rng, func(i: int) -> bool:
					return Game.relations[i] >= 35.0 and not Diplomacy.has_deal(i) and not Diplomacy.is_sanctioning(i))
				if other < 0:
					continue
			"democracy":
				if not Government.is_free(Game.player):
					continue
			"autocracy":
				if Government.has_elections(Game.player):
					continue
			"parliamentary":
				if not Government.kind(Game.player) in ["parliamentary", "monarchy_parl"]:
					continue
			"presidential":
				if not Government.kind(Game.player) in ["presidential", "semi_presidential"]:
					continue
			"managed":
				if Government.elections(Game.player) != "managed":
					continue
			"monarchy":
				if Government.kind(Game.player) != "monarchy":
					continue
			"royals":
				if not Government.kind(Game.player) in ["monarchy", "monarchy_parl"]:
					continue
			"army":
				if not Government.army_rules(Game.player):
					continue
			"one_party":
				if Government.kind(Game.player) != "one_party":
					continue
			"ageing":
				if World.stat(Game.player, "age65_pct", 10.0) < 15.0:
					continue
			"young":
				if World.stat(Game.player, "age65_pct", 10.0) > 6.0:
					continue
			"weak_power":
				if World.stat(Game.player, "electricity_pct", 100.0) >= 90.0 or Projects.is_done(me, "power_grid"):
					continue
			"building":
				if Projects.count_building(me) == 0:
					continue
			"bank_risk":
				if me.debt_pct() < 80.0 and me.growth > 0.5 and not Profiles.has_strength(Game.player, "finance"):
					continue
			"currency_risk":
				if me.inflation < 8.0 and -me.balance_pct() < 6.0:
					continue
			"hot":
				if Profiles.at_risk(Game.player, "heatwave") == 0:
					continue
				if Profiles.at_risk(Game.player, "heatwave") == -1 and not World.map.subregions[Game.player] in ["Southern Asia", "Western Asia", "Northern Africa", "Southern Europe", "South-Eastern Asia"]:
					continue
			"hostile":
				other = _pick_country(rng, func(i: int) -> bool:
					return Game.relations[i] <= -50.0 and not Diplomacy.sanctions_me(i))
				if other < 0:
					continue
		pool.append([e, other])
		weights.append(w)
	if pool.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += w
	var pick := rng.randf() * total
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0.0:
			return instance(pool[k][0], pool[k][1])
	return instance(pool[0][0], pool[0][1])


static func instance(e: Dictionary, other: int = -1) -> Dictionary:
	var name := World.map.names[Game.player]
	var other_name := World.map.names[other] if other >= 0 else ""
	var choices: Array = []
	for ch in e.choices:
		if ch.get("needs", "") == "ally" and Diplomacy.summary().alliances == 0:
			continue
		choices.append(ch)
	return {"id": e.id, "title": e.title, "icon": e.icon, "tint": e.tint, "other": other, "next": e.get("next", {}),
		"face": e.get("face", ""), "scene_hint": e.get("scene_hint", ""),
		"body": String(e.body).format({"country": name, "other": other_name, "project": _building_name()}), "choices": choices}


static func _building_name() -> String:
	var c := Game.me()
	if c == null:
		return "project"
	for id in c.projects:
		if str(c.projects[id].state) == "building":
			return str(Projects.by_id(id).get("title", "project")).to_lower()
	return "project"


static func _pick_country(rng: RandomNumberGenerator, ok: Callable) -> int:
	var cands: Array[int] = []
	for i in World.playable:
		if i != Game.player and ok.call(i):
			cands.append(i)
	return cands[rng.randi() % cands.size()] if not cands.is_empty() else -1


const _BAD_UP := {"growth": false, "inflation": true, "unemployment": true, "happiness": false,
	"approval": false, "stability": false}


const DISASTERS := ["floods", "monsoon", "hurricane", "heatwave", "earthquake", "drought"]
## Event -> the natural risk it needs (Profiles.risks).
const RISK_OF := {"floods": "flood", "monsoon": "monsoon", "hurricane": "hurricane", "heatwave": "heatwave",
	"earthquake": "earthquake", "drought": "drought"}


static func apply_effects(fx: Dictionary, other: int, ev_id: String = "") -> void:
	var c := Game.me()
	var sev := Difficulty.severity() * Profiles.mult(Game.player, "event_severity") * (1.0 + Cabinet.bonus("event_severity"))
	# People forgive a trusted leader more: low credibility makes bad news hit harder.
	sev *= lerpf(1.15, 0.9, Press.credibility() / 100.0)
	# Flood defences soften natural disasters.
	var soften := 0.7 if ev_id in DISASTERS and Projects.is_done(c, "flood_defences") else 1.0
	for k in fx:
		var v: Variant = fx[k]
		match k:
			"growth", "inflation", "unemployment", "happiness", "approval", "stability":
				var x := float(v)
				if (x > 0.0) == bool(_BAD_UP[k]):    # harmful part scales with difficulty
					x *= sev * soften
				c.set(k, float(c.get(k)) + x * 0.5)
				c.shocks[k] = float(c.shocks[k]) + x
			"cost":
				c.treasury -= c.gdp * float(v) / 100.0 * (sev if float(v) > 0.0 else 1.0)
			"gdp":
				c.gdp *= 1.0 + float(v) / 100.0
			"rate":
				c.interest_rate = clampf(c.interest_rate + float(v), Economy.RATE_MIN, Economy.RATE_MAX)
			"corp_tax", "income_tax":
				c.set(k, clampf(float(c.get(k)) + float(v), 0.0, 60.0))
			"spending":
				c.spending_pct = clampf(c.spending_pct + float(v), 8.0, 60.0)
			"debt_rate":
				c.debt_rate = maxf(c.debt_rate + float(v), 0.5)
			"debt_gdp":
				c.debt = maxf(c.debt + c.gdp * float(v) / 100.0, 0.0)
			"relation":
				if other >= 0:
					Diplomacy.change_relation(other, float(v))
			"relations_all":
				for i in Game.relations.size():
					if i != Game.player:
						Game.relations[i] = clampf(Game.relations[i] + float(v), -100.0, 100.0)
				Game.relations_changed.emit()
			"deal":
				if other >= 0 and not Diplomacy.has_deal(other):
					Game.dip.deals[str(other)] = Game.months_played
			"sanction_me":
				if other >= 0:
					Game.dip.sanctioned_by[str(other)] = Game.months_played
			"bloc_relations":
				for camp_name in (v as Dictionary):
					for j in Treaties.camp(str(camp_name)):
						Game.relations[j] = clampf(Game.relations[j] + float(v[camp_name]), -100.0, 100.0)
				Game.relations_changed.emit()
			"press_cred":
				Press.apply_cred(float(v))
			"project_delay":
				for id in c.projects:
					if str(c.projects[id].state) == "building":
						c.projects[id].progress = maxf(float(c.projects[id].progress) - float(v), 0.0)
						break
			_:
				if String(k).begins_with("share_"):
					var key := String(k).trim_prefix("share_")
					c.set_budget_share(key, float(c.budget[key]) + float(v) / 100.0)
	Diplomacy._apply_counts()
	Simulation.update_finances(c)


const _CHIP := {"growth": ["Growth", true], "inflation": ["Inflation", false], "unemployment": ["Jobless", false],
	"happiness": ["Happiness", true], "approval": ["Approval", true], "stability": ["Stability", true],
	"relations_all": ["World relations", true], "relation": ["Relations", true]}


## Short, honest chips for a choice's effects: [[text, good], …] (largest first).
static func effect_chips(fx: Dictionary) -> Array:
	var out: Array = []
	var c := Game.me()
	for k in fx:
		var v: Variant = fx[k]
		if (v is float or v is int) and absf(float(v)) < 0.001:
			continue
		match k:
			"cost":
				var money := c.gdp * absf(float(v)) / 100.0
				out.append([("Costs %s" if float(v) > 0.0 else "Gains %s") % DS.money(money, 0), float(v) < 0.0, absf(float(v)) * 3.0])
			"debt_gdp":
				out.append([("Debt +%s" if float(v) > 0.0 else "Debt −%s") % DS.money(c.gdp * absf(float(v)) / 100.0, 0),
					float(v) < 0.0, absf(float(v))])
			"rate":
				out.append(["Interest rate %+.1f" % float(v), false, absf(float(v)) * 2.0])
			"corp_tax", "income_tax", "spending":
				out.append(["%s %+.1f pts" % [{"corp_tax": "Business tax", "income_tax": "Income tax",
					"spending": "Spending"}[k], float(v)], k == "spending" and float(v) > 0.0, absf(float(v))])
			"deal":
				out.append(["Trade deal", true, 2.0])
			"project_delay":
				out.append(["Project delayed %d mo" % int(v), false, float(v) * 0.3])
			"press_cred":
				out.append(["Credibility %+d" % roundi(float(v)), float(v) > 0.0, absf(float(v)) * 0.25])
			"bloc_relations":
				var names := {"west": "The West", "east": "Russia & China's camp", "south": "Global South", "region": "Neighbours"}
				for camp_name in (v as Dictionary):
					var d := float(v[camp_name])
					out.append(["%s %+d" % [names.get(camp_name, camp_name), roundi(d)], d > 0.0, absf(d) * 0.8])
			"sanction_me":
				out.append(["Sanctions on you", false, 3.0])
			"gdp":
				out.append(["Economy +%s%%" % String.num(float(v), 1), true, absf(float(v)) * 2.0])
			_:
				if _CHIP.has(k):
					var good: bool = (float(v) > 0.0) == bool(_CHIP[k][1])
					out.append(["%s %+.1f" % [_CHIP[k][0], float(v)], good, absf(float(v))])
				elif String(k).begins_with("share_"):
					var key := String(k).trim_prefix("share_")
					out.append(["%s budget %+.1f%%" % [CountryState.BUDGET_LABELS.get(key, key), float(v)], true, absf(float(v))])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) > float(b[2]))
	return out.slice(0, 4)
