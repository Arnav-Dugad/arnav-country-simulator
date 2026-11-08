class_name Manifesto
extends RefCounted
## Elections, deeper.
##   Pledges     when you campaign, make up to two promises. Each wins votes
##               from the groups that care about it now, and is judged at the
##               next election: kept pledges earn trust and votes, broken ones
##               cost both. The Promises card shows whether each is on track.
##   Campaign    during the three months before a vote, hit the campaign trail:
##   trail       rallies win over one voter group, TV ads cost money, a big
##               final rally fires up the base. Three actions per campaign.
##   Coalitions  in parliamentary systems a narrow loss can still end in power:
##               a smaller party offers to govern with you if you accept its
##               demand. Break it and the coalition falls apart.
## State: Game.dip.manif {pledges: [{id, at, base}], trail: {used, last_vote}, coalition: {...}}.
## Constants in sim/economy.gd (MANI_*).

const E = preload("res://sim/economy.gd")

## id -> {title, icon, desc, groups (who cheers), check}
const PLEDGES := {
	"no_new_taxes": {"title": "No new taxes", "icon": "coins", "groups": ["business", "workers"],
		"desc": "Income, business and sales tax won't go up."},
	"jobs": {"title": "More jobs", "icon": "users", "groups": ["workers", "youth"],
		"desc": "Unemployment a point lower by the next election."},
	"prices": {"title": "Stable prices", "icon": "flame", "groups": ["retirees", "workers"],
		"desc": "Inflation under 3% at the next election."},
	"budget": {"title": "Balance the books", "icon": "wallet", "groups": ["business", "retirees"],
		"desc": "A deficit under 1% of GDP by the next election."},
	"homes": {"title": "Homes people can afford", "icon": "house", "groups": ["youth", "workers"],
		"desc": "Housing 5 points more affordable."},
	"safety": {"title": "Safer streets", "icon": "siren", "groups": ["retirees", "rural"],
		"desc": "Crime 5 points lower."},
	"health": {"title": "Better hospitals", "icon": "heart-pulse", "groups": ["retirees", "workers"],
		"desc": "Health spending up by a tenth."},
	"green": {"title": "A greener country", "icon": "leaf", "groups": ["youth"],
		"desc": "Emissions per person down 10%."},
	"waits": {"title": "Shorter hospital waits", "icon": "hourglass", "groups": ["retirees", "workers"],
		"desc": "Waiting times for operations down a fifth."},
	"air": {"title": "Clean air", "icon": "wind", "groups": ["youth", "workers"],
		"desc": "Air pollution down 15%."},
	"schools": {"title": "Better schools", "icon": "school", "groups": ["youth", "workers"],
		"desc": "Pupils' test scores up 10 points."},
}

const TRAIL := {
	"rally": {"title": "Rally", "icon": "megaphone", "desc": "Win over one voter group"},
	"ads": {"title": "TV ads", "icon": "tv", "desc": "Reach everyone, for a price"},
	"door": {"title": "Knock on doors", "icon": "house", "desc": "Slow, honest, works with the undecided"},
}


static func st() -> Dictionary:
	if not Game.dip.has("manif"):
		Game.dip["manif"] = {"pledges": [], "trail": {"used": 0, "for": -1}, "coalition": {}, "kept": 0, "broken": 0, "rallies": {}}
	return Game.dip.manif


# ------------------------------------------------------------------ pledges ---
static func _snap(c: CountryState) -> Dictionary:
	return {"income": c.income_tax, "corp": c.corp_tax, "vat": Taxes.rate(c, "vat") if not c.taxes.is_empty() else 0.0,
		"unemp": c.unemployment, "afford": Population.afford() if Game.dip.has("pop") else 100.0,
		"crime": Crime.value() if Game.dip.has("crime") else 0.0, "health": c.effort("health"), "co2": Climate.co2_pc(c),
		"wait": Health.wait() if Game.dip.has("hlth") else 10.0, "pm": Air.pm() if Game.dip.has("air") else 20.0,
		"learn": Education.score() if Game.dip.has("edu") else 400.0}


static func make(ids: Array) -> float:
	var s := st()
	var c := Game.me()
	s.pledges = []
	var gain := 0.0
	for id in ids.slice(0, 2):
		(s.pledges as Array).append({"id": str(id), "at": Game.months_played, "base": _snap(c)})
		var sz := Blocs.sizes(c.idx)
		for g in PLEDGES[str(id)].groups:
			gain += E.MANI_PLEDGE_BOOST * float(sz.get(g, 0.2))
	c.shocks.approval = float(c.shocks.approval) + gain
	return gain


## On track? (+1 kept so far, -1 broken/off track) and a short status line.
static func status(p: Dictionary) -> Array:
	var c := Game.me()
	var b: Dictionary = p.base
	match str(p.id):
		"no_new_taxes":
			var up := c.income_tax > float(b.income) + 0.5 or c.corp_tax > float(b.corp) + 0.5 \
				or (not c.taxes.is_empty() and Taxes.rate(c, "vat") > float(b.vat) + 0.5)
			return [-1 if up else 1, "A tax went up" if up else "No tax rises so far"]
		"jobs":
			var d := float(b.unemp) - c.unemployment
			return [1 if d >= 1.0 else -1, "Unemployment %s (goal %s)" % [DS.pct(c.unemployment), DS.pct(float(b.unemp) - 1.0)]]
		"prices":
			return [1 if c.inflation < 3.0 else -1, "Inflation %s (goal under 3%%)" % DS.pct(c.inflation)]
		"budget":
			var def := -c.balance_pct()
			return [1 if def < 1.0 else -1, "Deficit %s (goal under 1%%)" % DS.pct(maxf(def, 0.0))]
		"homes":
			var a := Population.afford() if Game.dip.has("pop") else 100.0
			return [1 if a >= float(b.afford) + 5.0 else -1, "Affordability %d (goal %d)" % [roundi(a), roundi(float(b.afford) + 5.0)]]
		"safety":
			var cr := Crime.value() if Game.dip.has("crime") else 0.0
			return [1 if cr <= float(b.crime) - 5.0 else -1, "Crime %d (goal %d)" % [roundi(cr), roundi(float(b.crime) - 5.0)]]
		"health":
			var h := c.effort("health")
			return [1 if h >= float(b.health) * 1.1 else -1, "Health spending %+d%% (goal +10%%)" % roundi((h / maxf(float(b.health), 0.001) - 1.0) * 100.0)]
		"green":
			var co := Climate.co2_pc(c)
			return [1 if co <= float(b.co2) * 0.9 else -1, "Emissions %+d%% (goal -10%%)" % roundi((co / maxf(float(b.co2), 0.001) - 1.0) * 100.0)]
		"waits":
			var w := Health.wait()
			var w0 := float(b.get("wait", w))
			return [1 if w <= w0 * 0.8 else -1, "Waits %d weeks (goal %d)" % [roundi(w), roundi(w0 * 0.8)]]
		"air":
			var a2 := Air.pm()
			var a0 := float(b.get("pm", a2))
			return [1 if a2 <= a0 * 0.85 else -1, "Fine dust %d µg (goal %d)" % [roundi(a2), roundi(a0 * 0.85)]]
		"schools":
			var l := Education.score()
			var l0 := float(b.get("learn", l))
			return [1 if l >= l0 + 10.0 else -1, "Test scores %d (goal %d)" % [roundi(l), roundi(l0 + 10.0)]]
	return [0, ""]


## At the election: judge every pledge from the last campaign. Returns [kept, broken] and applies the effects.
static func judge() -> Array:
	var s := st()
	var kept := 0
	var broken := 0
	for p in s.pledges:
		if Game.months_played - int(p.at) < 12:
			continue                 # made this campaign: judged next time
		if int(status(p)[0]) > 0:
			kept += 1
		else:
			broken += 1
	var c := Game.me()
	c.approval = clampf(c.approval + E.MANI_KEPT * kept - E.MANI_BROKEN * broken, 0.0, 100.0)
	Press.apply_cred(4.0 * kept - 6.0 * broken)
	s.kept = int(s.kept) + kept
	s.broken = int(s.broken) + broken
	s.pledges = (s.pledges as Array).filter(func(p: Dictionary) -> bool: return Game.months_played - int(p.at) < 12)
	return [kept, broken]


# ----------------------------------------------------------- campaign trail ---
static func trail_left() -> int:
	var t: Dictionary = st().trail
	var election_at := Game.months_played + Game.politics.months_to_election
	if int(t.get("for", -1)) != election_at:
		t["for"] = election_at
		t["used"] = 0
	return maxi(E.MANI_TRAIL_ACTIONS - int(t.used), 0)


static func trail_open() -> bool:
	return Government.has_elections(Game.player) and Game.politics.months_to_election <= Campaign.MONTHS_BEFORE \
		and Game.politics.months_to_election > 0


static func trail(kind: String, group: String = "") -> String:
	if not trail_open() or trail_left() <= 0:
		return ""
	var c := Game.me()
	var s := st()
	var text := ""
	match kind:
		"rally":
			var sz := float(Blocs.sizes(c.idx).get(group, 0.2))
			c.shocks.approval = float(c.shocks.approval) + E.MANI_RALLY * sz * 4.0
			(s.rallies as Dictionary)[group] = float((s.rallies as Dictionary).get(group, 0.0)) + E.MANI_RALLY * 4.0
			text = "A packed rally wins over %s" % str(Blocs.INFO[group].title).to_lower()
		"ads":
			c.treasury -= c.gdp * E.MANI_ADS_COST / 100.0
			c.shocks.approval = float(c.shocks.approval) + E.MANI_ADS
			text = "Your TV ads run on every channel"
		"door":
			var gain := E.MANI_DOOR * (1.0 + clampf((50.0 - c.approval) / 20.0, -0.5, 0.8))
			c.shocks.approval = float(c.shocks.approval) + gain
			text = "Volunteers knock on a million doors"
	s.trail.used = int(s.trail.used) + 1
	Game.add_feed(text, str(TRAIL[kind].icon), "gold")
	return text


## Rally bonus per group (for the voter breakdown; fades after the vote).
static func rally_bonus(g: String) -> float:
	return float((st().get("rallies", {}) as Dictionary).get(g, 0.0))


# --------------------------------------------------------------- coalitions ---
const PARTNERS := [
	{"name": "Green Alliance", "demand": "carbon_tax", "ask": "a carbon tax"},
	{"name": "Liberal Democrats", "demand": "press_freedom", "ask": "a press freedom guarantee"},
	{"name": "Workers' Party", "demand": "min_wage", "ask": "a minimum wage"},
	{"name": "Farmers' Union", "demand": "farm_aid", "ask": "keeping tariffs to protect farms"},
	{"name": "Reform Party", "demand": "anti_corruption", "ask": "an anti-corruption agency"},
]


## A narrow loss in a parliament: a smaller party offers a coalition (or {}).
static func coalition_offer(share: float) -> Dictionary:
	var pr := Constitution.fx("coalition") if Game.dip.has("const") else 0.0
	if Government.kind(Game.player) not in ["parliamentary", "monarchy_parl", "semi_presidential"] and pr <= 0.0:
		return {}
	if share < E.MANI_COALITION_SHARE - 2.0 * pr or share >= 50.0:
		return {}
	var c := Game.me()
	var cands: Array = []
	for p in PARTNERS:
		var d := str(p.demand)
		if d == "farm_aid" or (Laws.law(d).size() > 0 and not Laws.is_active(c, d)):
			cands.append(p)
	if cands.is_empty():
		return {}
	return cands[Game.rng.randi() % cands.size()]


static func accept_coalition(p: Dictionary) -> void:
	st().coalition = {"name": str(p.name), "demand": str(p.demand), "ask": str(p.ask), "since": Game.months_played}
	Game.add_milestone("Formed a coalition with the %s" % str(p.name), "handshake", "accent")


static func coalition() -> Dictionary:
	return st().coalition


## Is the coalition partner's demand met?
static func demand_met() -> bool:
	var co := coalition()
	if co.is_empty():
		return true
	var c := Game.me()
	if str(co.demand) == "farm_aid":
		return Tariffs.count() > 0 or (not c.taxes.is_empty() and Taxes.delta(c, "tariff") >= 0.0)
	return Laws.is_active(c, str(co.demand)) or Laws.pending_months(c, str(co.demand)) > 0


## Monthly: the coalition partner walks out if its demand isn't met within a year.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var co := coalition()
	if not co.is_empty() and Game.months_played - int(co.since) >= E.MANI_DEMAND_MONTHS and not demand_met():
		var c := Game.me()
		c.shocks.approval = float(c.shocks.approval) - 5.0
		c.shocks.stability = float(c.shocks.stability) - 6.0
		Game.politics.months_to_election = mini(Game.politics.months_to_election, 6)
		out.append({"text": "The %s quits your coalition over %s: an early election is called" % [str(co.name), str(co.ask)], "icon": "handshake", "good": false})
		st().coalition = {}
	# Rally effects fade after the vote.
	if not trail_open():
		st().rallies = {}
	return out


## Law title for a demand.
static func ask_text(p: Dictionary) -> String:
	return str(p.ask)
