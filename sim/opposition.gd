class_name Opposition
extends RefCounted
## The opposition leader you face at elections: an original, fictional person
## with a face, a party and a line of attack on your weakest record. Only in
## countries that hold elections. A new one takes over after every election
## you win (losing leaders rarely survive). Generation counter: Game.dip.opp_gen.

## Fictional parties, one picked per opposition leader.
## "base": the voter groups it pulls away from you (support points, see Blocs).
const PARTIES := [
	{"party": "People's Voice", "pitch": "Power back to ordinary people", "base": {"workers": -5.0, "rural": -5.0}},
	{"party": "Green Alliance", "pitch": "A cleaner, fairer future", "base": {"youth": -8.0}},
	{"party": "Enterprise Party", "pitch": "Lower taxes, more jobs", "base": {"business": -8.0}},
	{"party": "Labour Movement", "pitch": "Fair wages and strong public services", "base": {"workers": -7.0, "youth": -2.0}},
	{"party": "National Union", "pitch": "Order, family and pride", "base": {"retirees": -6.0, "rural": -5.0}},
	{"party": "Renewal Party", "pitch": "Fresh faces, honest government", "base": {"youth": -5.0, "business": -2.0}},
]
## Lines of attack, by your weakest record (see attack()).
const ATTACKS := {
	"inflation": ["Prices are out of control and this government shrugs.", "Ask anyone at the checkout: life costs too much."],
	"jobs": ["Too many people are out of work. It's time for a change.", "Every closed factory is a promise they broke."],
	"debt": ["They're borrowing money our children will have to repay.", "The national credit card is maxed out."],
	"unrest": ["The streets are angry. This government has lost control.", "People don't feel safe, and the government doesn't listen."],
	"growth": ["The economy is stuck in neutral, and they have no plan.", "Our neighbours are growing. Why aren't we?"],
	"taxes": ["Working people are paying more tax than ever.", "They take more from every paycheck and give less back."],
	"happiness": ["People feel worse off than when this government came in.", "Ask yourself: is life better than it was?"],
}
const ATTACK_GAP := 5          # months between attacks, at least
const ATTACK_CHANCE := 0.35    # monthly chance once the gap has passed


static func active() -> bool:
	return Game.has_game() and Government.has_elections(Game.player)


static func _gen() -> int:
	return int(Game.dip.get("opp_gen", 0))


## {name, female, portrait, party, pitch}
static func leader() -> Dictionary:
	var i := Game.player
	var h := absi(hash("%s#opp#%d" % [World.iso(i), _gen()]))
	var names: Array = Names.pool(i)
	var fi: int = h % (names[0] as Array).size()
	var li: int = absi(hash("%s#opp-last#%d" % [World.iso(i), _gen()])) % (names[1] as Array).size()
	var female: bool = fi % 2 == 0          # first-name lists alternate female / male
	var group := Leaders.group_of(i)
	var full := Names.full(i, fi, li)
	var v := Leaders.variant_for(full)
	var portrait := Leaders.portrait_key(group, female, v)
	if portrait == Leaders.player_portrait():
		# Never the same face as yours: the other face for this region.
		portrait = Leaders.portrait_key(group, female, v + 1)
	# The party stays; its leaders change.
	var p: Dictionary = PARTIES[absi(hash("%s#opp-party" % World.iso(i))) % PARTIES.size()]
	return {"name": full, "female": female, "portrait": portrait,
		"party": str(p.party), "pitch": str(p.pitch), "base": p.base}


## After an election you won: the opposition picks someone new.
static func replace() -> void:
	if not active():
		return
	Game.dip["opp_gen"] = _gen() + 1
	var ld := leader()
	Game.add_feed("The %s picks a new leader to take you on: %s" % [str(ld.party), str(ld.name)], "users", "accent")
	Game.feed[0]["face"] = str(ld.portrait)


## Your weakest record right now, or "" when there's nothing to attack.
static func weakness(c: CountryState) -> String:
	var b: Dictionary = c.base
	var cands: Array = []
	if c.inflation > maxf(5.0, float(b.inflation) + 2.0):
		cands.append([c.inflation - float(b.inflation), "inflation"])
	if c.unemployment > float(b.unemployment) + 1.5:
		cands.append([(c.unemployment - float(b.unemployment)) * 1.5, "jobs"])
	if c.debt_pct() > float(b.debt_pct) + 10.0:
		cands.append([(c.debt_pct() - float(b.debt_pct)) * 0.2, "debt"])
	if c.stability < float(b.stability) - 8.0:
		cands.append([(float(b.stability) - c.stability) * 0.3, "unrest"])
	if c.growth < 0.5:
		cands.append([2.0 - c.growth, "growth"])
	if c.income_tax > float(b.income_tax) + 4.0:
		cands.append([(c.income_tax - float(b.income_tax)) * 0.5, "taxes"])
	if c.happiness < float(b.happiness) - 5.0:
		cands.append([(float(b.happiness) - c.happiness) * 0.4, "happiness"])
	if cands.is_empty():
		return ""
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	return str(cands[0][1])


## Monthly: now and then the opposition leader goes after your weakest record.
static func monthly() -> void:
	if not active() or Game.months_played - int(Game.dip.get("opp_last", -99)) < ATTACK_GAP:
		return
	if Game.rng.randf() > ATTACK_CHANCE:
		return
	var w := weakness(Game.me())
	if w == "":
		return
	Game.dip["opp_last"] = Game.months_played
	var ld := leader()
	var lines: Array = ATTACKS[w]
	Game.add_feed("Opposition leader %s: \"%s\"" % [str(ld.name), str(lines[Game.rng.randi() % lines.size()])], "megaphone", "orange")
	Game.feed[0]["face"] = str(ld.portrait)
