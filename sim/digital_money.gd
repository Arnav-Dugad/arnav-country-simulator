class_name DigitalMoney
extends RefCounted
## Digital money: what your country does about crypto and digital currencies.
##   Policy         None (as today) · Digital currency (a central bank digital
##                  currency: less tax evasion, some privacy worries) · Legal tender
##                  (crypto accepted everywhere, as El Salvador tried: tech
##                  investors and tourists love it, lenders and the IMF do not) ·
##                  Ban (calm, but some young voters and start-ups leave).
##   Crypto reserve put part of the treasury into crypto. The market is wild:
##                  booms, long winters and sudden crashes.
## Effects count only the change since you took office (everyone starts at None).
## State: Game.dip.dig {mode, units, cost, price, hist: [], last_news}. Constants in sim/economy.gd (DIG_*).

const E = preload("res://sim/economy.gd")

const MODES := ["none", "cbdc", "legal", "ban"]
const SHORT := ["As today", "E-money", "Legal", "Ban"]
const MODE_INFO := {
	"none": {"title": "As today", "desc": "Crypto is legal but marginal; cash and banks rule.", "capital": 0.0},
	"cbdc": {"title": "Digital currency", "desc": "The central bank issues digital cash. Less tax evasion; some worry about privacy.", "capital": 10.0},
	"legal": {"title": "Legal tender", "desc": "Crypto accepted everywhere. Tech investors and tourists love it; lenders charge more.", "capital": 20.0},
	"ban": {"title": "Ban crypto", "desc": "Calm and safe, but some start-ups and young people leave.", "capital": 10.0},
}


static func st() -> Dictionary:
	if not Game.dip.has("dig"):
		Game.dip["dig"] = {"mode": "none", "units": 0.0, "cost": 0.0, "price": 100.0, "hist": [100.0], "last_news": -99}
	return Game.dip.dig


static func mode() -> String:
	return str(st().mode)


static func price() -> float:
	return float(st().price)


static func holding() -> float:
	return float(st().units) * price()


static func set_mode(m: String) -> bool:
	if m == mode() or not Capital.spend(float(MODE_INFO[m].capital)):
		return false
	st().mode = m
	Game.add_feed("Digital money: %s" % str(MODE_INFO[m].title).to_lower(), "bitcoin" if m == "legal" else "smartphone", "accent")
	if m == "legal":
		Game.intel_news.emit({"text": "%s makes crypto legal tender. Lenders are nervous." % World.The_name(Game.player), "icon": "bitcoin", "good": false, "big": true})
	return true


static func buy(usd: float) -> void:
	var c := Game.me()
	usd = clampf(usd, 0.0, maxf(c.treasury, 0.0))
	if usd <= 0.0:
		return
	c.treasury -= usd
	st().units = float(st().units) + usd / price()
	st().cost = float(st().cost) + usd


static func sell_all() -> float:
	var v := holding()
	Game.me().treasury += v
	st().units = 0.0
	st().cost = 0.0
	return v


## Monthly: the crypto market moves (own random stream so the rest of the world is unchanged).
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "crypto"])
	var p := price()
	var step := E.DIG_DRIFT + r.randfn(0.0, E.DIG_VOL)
	var news := ""
	if r.randf() < E.DIG_CRASH:
		step -= r.randf_range(0.3, 0.55)
		news = "Crypto crashes: prices fall by a third or more in days"
	elif r.randf() < E.DIG_BOOM:
		step += r.randf_range(0.25, 0.45)
		news = "Crypto mania: prices soar to new records"
	s.price = clampf(p * exp(step), 2.0, 5000.0)
	var h: Array = s.hist
	h.append(price())
	if h.size() > 36:
		h.pop_front()
	if news != "" and (mode() == "legal" or float(s.units) > 0.0) and Game.months_played - int(s.last_news) >= 6:
		s.last_news = Game.months_played
		out.append({"text": news + (" (your reserve is now worth %s)" % DS.money(holding()) if float(s.units) > 0.0 else ""),
			"icon": "bitcoin", "good": step > 0.0, "big": true})
	# Legal tender: a crash hurts the people who hold it.
	if mode() == "legal" and step < -0.25:
		Game.me().shocks.approval = float(Game.me().shocks.approval) - 2.0
	return out


## Year-on-year change in the crypto price.
static func year_change() -> float:
	var h: Array = st().hist
	if h.size() < 13:
		return 0.0
	return float(h[h.size() - 1]) / float(h[h.size() - 13]) - 1.0


## Effects on the national targets.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("dig"):
		return {}
	match mode():
		"cbdc":
			return {"approval": -0.4, "revenue": E.DIG_CBDC_REVENUE}
		"legal":
			return {"growth": E.DIG_LEGAL_GROWTH + clampf(year_change(), -0.5, 0.5) * 0.2, "debt_rate": E.DIG_LEGAL_RATE}
		"ban":
			return {"approval": -0.3, "growth": -0.05}
	return {}
