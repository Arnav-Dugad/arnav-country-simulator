class_name Enterprise
extends RefCounted
## State firms, the sovereign wealth fund and the national stock market.
##   State firms   the oil company, power utility, railways, airline, banks…
##                 Who owns what at the start follows how open the country is
##                 (WGI voice & accountability) and each sector's tradition.
##                 State firms pay dividends but run less efficiently; selling
##                 one raises cash and growth but costs jobs and votes; taking
##                 one over is popular but scares investors (expropriating it
##                 for free scares them a lot). Professional managers lift
##                 efficiency. Only changes since you took office count.
##   Wealth fund   park money abroad in bonds and global stocks; returns either
##                 stay in the fund or go to the budget ("spend the returns").
##                 Big oil exporters start with one.
##   Stock market  a national index (100 = when you took office) driven by
##                 growth, interest rates, stability and world markets. It sets
##                 privatisation prices and gives a small wealth effect.
## State: Game.dip.ent {firms: {id: {own, own0, eff}}, fund: {value, stocks, spend,
## ret_year}, index, world, hist: [index...]}. Constants in sim/economy.gd (ENT_*).

const E = preload("res://sim/economy.gd")

## id -> {title, icon, size (% of GDP), trad (how often states own it), oil}
const FIRMS := {
	"oil": {"title": "National oil company", "icon": "fuel", "size": 0.0, "trad": 0.6, "oil": true},
	"utility": {"title": "Power utility", "icon": "zap", "size": 3.0, "trad": 0.5},
	"rail": {"title": "National railways", "icon": "train-front", "size": 1.5, "trad": 0.6},
	"post": {"title": "Postal service", "icon": "mail", "size": 0.4, "trad": 0.7},
	"airline": {"title": "Flag-carrier airline", "icon": "plane", "size": 0.6, "trad": 0.3},
	"telecom": {"title": "Telecoms", "icon": "radio-tower", "size": 2.0, "trad": 0.25},
	"bank": {"title": "State bank", "icon": "landmark", "size": 4.0, "trad": 0.25},
	"steel": {"title": "Steel & heavy industry", "icon": "factory", "size": 1.0, "trad": 0.2},
	"mining": {"title": "Mining company", "icon": "pickaxe", "size": 1.0, "trad": 0.3},
	"arms": {"title": "Defence manufacturer", "icon": "shield", "size": 0.6, "trad": 0.4},
}


static func _statism(i: int) -> float:
	return clampf(0.5 - 0.25 * World.stat(i, "voice_wgi", 0.0), 0.0, 1.0)


static func st() -> Dictionary:
	if not Game.dip.has("ent"):
		Game.dip["ent"] = _fresh()
	return Game.dip.ent


static func _fresh() -> Dictionary:
	var i := Game.player
	var c := Game.me()
	var s := _statism(i)
	var firms := {}
	var clean := Corruption.value(c) if c != null else 50.0
	for id in FIRMS:
		var f: Dictionary = FIRMS[id]
		if bool(f.get("oil", false)) and World.stat(i, "fuel_exports_pct", 0.0) < 12.0:
			continue
		var own := float(f.trad) + s * 0.6 > 0.62
		firms[id] = {"own": own, "own0": own, "eff": clampf(E.ENT_EFF_BASE + E.ENT_EFF_CLEAN * clean / 100.0, 0.3, 0.9)}
	var fund := 0.0
	var fuel := World.stat(i, "fuel_exports_pct", 0.0)
	if fuel >= 30.0 and c != null:
		fund = c.gdp * clampf(fuel / 100.0 * 1.6 * Economy.income_level(c.gdp_per_capita()), 0.0, 3.0)
	return {"firms": firms, "fund": {"value": fund, "stocks": 0.6, "spend": false, "ret_year": 0.0},
		"index": 100.0, "world": 100.0, "hist": [100.0], "rate0": c.interest_rate if c != null else 3.0}


## Value of a firm (dollars). The oil company scales with fuel exports.
static func value(id: String) -> float:
	var c := Game.me()
	var f: Dictionary = FIRMS[id]
	var pct := float(f.size)
	if bool(f.get("oil", false)):
		pct = World.stat(Game.player, "fuel_exports_pct", 0.0) * World.stat(Game.player, "trade_pct", 30.0) / 100.0 * 0.5
	if id == "steel":
		pct *= clampf(World.stat(Game.player, "manufacturing_pct", 15.0) / 15.0, 0.4, 2.0)
	return c.gdp * pct / 100.0


static func owned(id: String) -> bool:
	return bool((st().firms as Dictionary).get(id, {}).get("own", false))


## Yearly dividend a state firm pays (profit x efficiency x payout).
static func dividend(id: String) -> float:
	var f: Dictionary = st().firms[id]
	var oil_boost := 1.0
	if bool(FIRMS[id].get("oil", false)) and Game.markets != null:
		oil_boost = clampf(1.0 + Game.markets.oil_gap(), 0.4, 2.2)
	return value(id) * E.ENT_RETURN * float(f.eff) * E.ENT_PAYOUT * oil_boost


## Dividends now minus dividends from the firms the state owned at the start (yearly $).
static func dividend_change() -> float:
	var d := 0.0
	for id in st().firms:
		var f: Dictionary = st().firms[id]
		var now := dividend(id) if bool(f.own) else 0.0
		var then := value(id) * E.ENT_RETURN * clampf(E.ENT_EFF_BASE + E.ENT_EFF_CLEAN * Corruption.start(Game.player) / 100.0, 0.3, 0.9) \
			* E.ENT_PAYOUT if bool(f.own0) else 0.0
		d += now - then
	return d


## Share of GDP sold since the start (negative = taken over).
static func privatised_pct() -> float:
	var p := 0.0
	for id in st().firms:
		var f: Dictionary = st().firms[id]
		if bool(f.own0) != bool(f.own):
			p += value(id) / maxf(Game.me().gdp, 1.0) * 100.0 * (1.0 if bool(f.own0) else -1.0)
	return p


## What investors would pay for a state firm now.
static func sale_price(id: String) -> float:
	var mood := sqrt(clampf(float(st().index) / 100.0, 0.3, 3.0))
	var trust := 0.7 + 0.3 * Corruption.value(Game.me()) / 100.0
	return value(id) * mood * trust


static func buy_price(id: String) -> float:
	return value(id) * sqrt(clampf(float(st().index) / 100.0, 0.3, 3.0)) * E.ENT_TAKEOVER_PREMIUM


static func privatise(id: String) -> float:
	if not owned(id):
		return 0.0
	var c := Game.me()
	var cash := sale_price(id)
	c.treasury += cash
	st().firms[id].own = false
	c.shocks.approval = float(c.shocks.approval) - E.ENT_SELL_APPROVAL
	c.shocks.unemployment = float(c.shocks.unemployment) + E.ENT_SELL_JOBS * value(id) / maxf(c.gdp, 1.0) * 100.0
	Game.add_feed("Sold: the %s goes to private investors for %s" % [str(FIRMS[id].title).to_lower(), DS.money(cash)], str(FIRMS[id].icon), "accent")
	Game.add_milestone("Privatised the %s" % str(FIRMS[id].title).to_lower(), str(FIRMS[id].icon), "accent")
	return cash


## Take a firm into state hands: pay for it, or seize it for free.
static func nationalise(id: String, seize: bool) -> void:
	if owned(id) or not st().firms.has(id):
		return
	var c := Game.me()
	if not seize:
		c.treasury -= buy_price(id)
	else:
		c.shocks.growth = float(c.shocks.growth) - E.ENT_SEIZE_GROWTH
		for j in World.playable:
			if j != Game.player and Government.is_democracy(j):
				Game.relations[j] = clampf(Game.relations[j] - E.ENT_SEIZE_RELATIONS, -100.0, 100.0)
		Game.relations_changed.emit()
		st().index = float(st().index) * (1.0 - E.ENT_SEIZE_CRASH)
	st().firms[id].own = true
	st().firms[id].eff = minf(float(st().firms[id].eff), E.ENT_EFF_BASE + 0.15)
	c.shocks.approval = float(c.shocks.approval) + E.ENT_TAKE_APPROVAL
	Game.add_feed(("Seized: the state takes over the %s without compensation" if seize else "Nationalised: the state buys the %s")
		% str(FIRMS[id].title).to_lower(), str(FIRMS[id].icon), "orange" if seize else "accent")
	Game.add_milestone("Nationalised the %s" % str(FIRMS[id].title).to_lower(), str(FIRMS[id].icon), "orange")


## Bring in professional managers (political capital): efficiency up.
static func reform(id: String) -> bool:
	var f: Dictionary = st().firms.get(id, {})
	if f.is_empty() or not bool(f.own) or float(f.eff) >= E.ENT_EFF_MAX - 0.01 or not Capital.spend(E.CAPITAL_FIRM_REFORM):
		return false
	f.eff = minf(float(f.eff) + E.ENT_REFORM_GAIN, E.ENT_EFF_MAX)
	Game.add_feed("New managers at the %s promise leaner, better service" % str(FIRMS[id].title).to_lower(), "briefcase", "accent")
	return true


# ------------------------------------------------------------- wealth fund ---
static func fund() -> Dictionary:
	return st().fund


static func deposit(amount: float) -> void:
	var c := Game.me()
	amount = maxf(amount, 0.0)
	c.treasury -= amount
	fund().value = float(fund().value) + amount


static func withdraw(amount: float) -> void:
	amount = clampf(amount, 0.0, float(fund().value))
	Game.me().treasury += amount
	fund().value = float(fund().value) - amount


## Expected yearly return of the fund's mix (for the UI).
static func expected_return() -> float:
	var s := float(fund().stocks)
	return s * E.ENT_STOCK_DRIFT * 12.0 + (1.0 - s) * E.ENT_BOND_RETURN


# -------------------------------------------------------------- monthly ---
## Markets move, the fund earns, dividends flow. Returns headlines [{text, icon, good}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var c := Game.me()
	var s := st()
	# World stocks: drift + noise, shaken by oil shocks.
	var wr := E.ENT_STOCK_DRIFT + Game.rng.randfn(0.0, E.ENT_STOCK_VOL)
	if Game.markets != null:
		wr -= 0.15 * maxf(Game.markets.oil_gap() - 0.3, 0.0) / 12.0
	s.world = float(s.world) * exp(wr)
	# Home index: world market + your economy.
	var home := 0.6 * wr + E.ENT_INDEX_GROWTH * clampf(c.growth - c.growth_anchor, -6.0, 6.0) / 12.0 \
		- E.ENT_INDEX_RATES * (c.interest_rate - float(s.get("rate0", c.interest_rate))) / 12.0 \
		+ E.ENT_INDEX_STABILITY * (c.stability - float(c.base.get("stability", c.stability))) / 12.0 \
		+ Game.rng.randfn(0.0, E.ENT_STOCK_VOL * 0.8) + E.ENT_STOCK_DRIFT * 0.4
	var before := float(s.index)
	s.index = clampf(before * exp(home), 5.0, 5000.0)
	(s.hist as Array).append(float(s.index))
	if (s.hist as Array).size() > 240:
		(s.hist as Array).remove_at(0)
	var month_move := float(s.index) / before - 1.0
	if month_move <= -0.12:
		out.append({"text": "Stock market slump: shares fall %d%% in a month" % roundi(-month_move * 100.0), "icon": "trending-down", "good": false})
	elif month_move >= 0.12:
		out.append({"text": "Stock market rally: shares up %d%% this month" % roundi(month_move * 100.0), "icon": "trending-up", "good": true})
	# Wealth fund.
	var f := fund()
	if float(f.value) > 0.0:
		var stocks := float(f.stocks)
		var r := stocks * (exp(wr) - 1.0) + (1.0 - stocks) * E.ENT_BOND_RETURN / 12.0
		var gain := float(f.value) * r
		f.value = maxf(float(f.value) + gain, 0.0)
		f.ret_year = float(f.ret_year) * (11.0 / 12.0) + gain
		if bool(f.spend):
			var take := float(f.value) * E.ENT_SPEND_RULE / 12.0
			f.value = float(f.value) - take
			c.treasury += take
	# Dividends beyond (or short of) what the state earned at the start.
	c.treasury += dividend_change() / 12.0
	return out


## Target offsets: privatisation lifts growth and costs jobs; a booming market
## makes people feel richer.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("ent"):
		return {}
	var p := privatised_pct()
	var out := {}
	if absf(p) > 0.001:
		out["growth"] = E.ENT_PRIV_GROWTH * p
		out["unemployment"] = E.ENT_PRIV_UNEMP * p
	var idx := float(st().index)
	out["happiness"] = clampf(E.ENT_WEALTH_HAPPY * log(idx / 100.0) / log(2.0), -2.0, 2.0)
	return out
