class_name Wonders
extends RefCounted
## World wonders: one-of-a-kind megaprojects. Only one nation can ever finish
## each; the great powers race for them too. Building one takes years and a big
## share of GDP; finishing it brings a lasting bonus and a burst of national
## pride and soft power. If a rival finishes first, your work is lost (half the
## money is refunded as the site is sold).
## State: Game.dip.won {id: {owner (iso), m}} for finished; Game.dip.won_me {id, start, price};
## Game.dip.won_ai {id: {iso, progress}}. Constants in sim/economy.gd (WON_*).

const E = preload("res://sim/economy.gd")

## id -> {title, icon, desc, cost (% of GDP), months, tech ("" = none), fx (lasting targets), soft}
const ALL := {
	"grand_canal": {"title": "The Grand Canal", "icon": "ship", "cost": 6.0, "months": 72, "tech": "",
		"desc": "A canal between two seas that reshapes world trade.", "fx": {"growth": 0.6}, "soft": 6.0, "coast": true},
	"world_library": {"title": "World Digital Library", "icon": "book-open", "cost": 2.5, "months": 48, "tech": "ai",
		"desc": "Every book, film and song ever made, free to the world.", "fx": {"happiness": 2.0}, "rp": 4.0, "soft": 8.0},
	"arcology": {"title": "Arcology City", "icon": "building-2", "cost": 5.0, "months": 84, "tech": "smart_grid",
		"desc": "A whole city in one green tower: zero emissions, a million homes.", "fx": {"happiness": 2.0, "growth": 0.3}, "co2": 0.08, "soft": 7.0},
	"fusion_grid": {"title": "Continental Fusion Grid", "icon": "atom", "cost": 7.0, "months": 96, "tech": "fusion",
		"desc": "Endless clean power, sold to your neighbours.", "fx": {"growth": 0.8, "inflation": -0.6}, "co2": 0.25, "soft": 6.0},
	"genome_vault": {"title": "Human Genome Vault", "icon": "dna", "cost": 2.0, "months": 48, "tech": "genomics",
		"desc": "Cures for rare diseases, shared with the world.", "fx": {"happiness": 1.5}, "life": 2.0, "soft": 7.0},
	"space_elevator": {"title": "Space Elevator", "icon": "rocket", "cost": 9.0, "months": 120, "tech": "station",
		"desc": "A cable to orbit: space travel for the price of a train ticket.", "fx": {"growth": 0.7}, "rp": 6.0, "soft": 14.0},
	"great_green_wall": {"title": "The Great Green Wall", "icon": "trees", "cost": 3.0, "months": 72, "tech": "",
		"desc": "A forest across a continent that halts the deserts.", "fx": {"happiness": 1.5, "stability": 1.5}, "co2": 0.05, "soft": 8.0},
	"world_games_city": {"title": "Eternal Games City", "icon": "medal", "cost": 3.5, "months": 60, "tech": "",
		"desc": "The permanent home of the Summer Games.", "fx": {"happiness": 1.5, "growth": 0.2}, "soft": 9.0},
}

const AI_RIVALS := ["USA", "CHN", "IND", "DEU", "JPN", "GBR", "FRA", "BRA", "RUS", "KOR", "SAU", "ARE"]


static func done() -> Dictionary:
	if not Game.dip.has("won"):
		Game.dip["won"] = {}
	return Game.dip.won


static func mine() -> Dictionary:
	return Game.dip.get("won_me", {})


static func ai() -> Dictionary:
	if not Game.dip.has("won_ai"):
		Game.dip["won_ai"] = {}
	return Game.dip.won_ai


static func owner(id: String) -> String:
	return str(done().get(id, {}).get("owner", ""))


static func have(id: String) -> bool:
	return owner(id) == World.iso(Game.player)


static func cost(id: String) -> float:
	return Game.me().gdp * float(ALL[id].cost) / 100.0


static func blocked(id: String) -> String:
	var w: Dictionary = ALL[id]
	if owner(id) != "":
		return "Built by %s" % World.map.names[World.index_of(owner(id))] if World.index_of(owner(id)) >= 0 else "Already built"
	if not mine().is_empty():
		return "You're already building a wonder"
	if str(w.tech) != "" and not Tech.has(str(w.tech)):
		return "Needs research: %s" % str(Tech.ALL[str(w.tech)].title)
	if bool(w.get("coast", false)) and World.landlocked(Game.player):
		return "Needs a coastline"
	if Game.me().gdp < E.WON_MIN_GDP:
		return "Needs an economy above %s" % DS.money(E.WON_MIN_GDP)
	return ""


static func start(id: String) -> bool:
	if blocked(id) != "":
		return false
	Game.dip["won_me"] = {"id": id, "start": Game.months_played, "price": cost(id)}
	Game.add_feed("Work begins on %s" % str(ALL[id].title), str(ALL[id].icon), "gold")
	return true


static func progress() -> float:
	var m := mine()
	if m.is_empty():
		return 0.0
	return clampf(float(Game.months_played - int(m.start)) / float(ALL[str(m.id)].months), 0.0, 1.0)


## Yearly spending while building (% of GDP).
static func spending_pct() -> float:
	if not Game.has_game() or Game.me() == null:
		return 0.0
	var m := mine()
	if m.is_empty():
		return 0.0
	return float(m.price) / maxf(Game.me().gdp, 1.0) * 100.0 / (float(ALL[str(m.id)].months) / 12.0)


static func abandon() -> void:
	var m := mine()
	if m.is_empty():
		return
	Game.me().treasury += float(m.price) * progress() * E.WON_REFUND
	Game.dip.erase("won_me")


## Monthly: your build, and the great powers' race. Headlines.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var c := Game.me()
	var m := mine()
	if not m.is_empty() and progress() >= 1.0:
		var id := str(m.id)
		done()[id] = {"owner": World.iso(Game.player), "m": Game.months_played}
		Game.dip.erase("won_me")
		ai().erase(id)
		c.shocks.approval = float(c.shocks.approval) + E.WON_PRIDE
		c.shocks.happiness = float(c.shocks.happiness) + E.WON_PRIDE
		Game.add_milestone("Completed %s" % str(ALL[id].title), str(ALL[id].icon), "gold")
		Achievements.unlock("wonder")
		out.append({"text": "%s completes %s, a wonder of the world!" % [World.The_name(Game.player), str(ALL[id].title)],
			"icon": str(ALL[id].icon), "good": true, "big": true, "celebrate": true})
	# The great powers pick projects and work on them (own random stream).
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "wonders"])
	if Game.months_played >= 12 and ai().size() < 3 and r.randf() < E.WON_AI_START:
		var free: Array = []
		for id in ALL:
			if owner(str(id)) == "" and not ai().has(id):
				free.append(id)
		if not free.is_empty():
			var iso: String = AI_RIVALS[r.randi() % AI_RIVALS.size()]
			if World.index_of(iso) >= 0 and World.index_of(iso) != Game.player and not World.is_absorbed(World.index_of(iso)):
				var wid := str(free[r.randi() % free.size()])
				ai()[wid] = {"iso": iso, "start": Game.months_played}
				if not mine().is_empty() and str(mine().id) == wid:
					out.append({"text": "Race on: %s also starts building %s" % [World.The_name(World.index_of(iso)), str(ALL[wid].title)],
						"icon": str(ALL[wid].icon), "good": false, "big": true})
	for wid in ai().keys():
		var a: Dictionary = ai()[wid]
		var months := float(ALL[wid].months) * E.WON_AI_SLOWER
		if Game.months_played - int(a.start) >= months:
			done()[wid] = {"owner": str(a.iso), "m": Game.months_played}
			ai().erase(wid)
			var who := World.index_of(str(a.iso))
			var text := "%s completes %s" % [World.The_name(who), str(ALL[wid].title)]
			if not mine().is_empty() and str(mine().id) == wid:
				c.treasury += float(mine().price) * progress() * E.WON_REFUND
				Game.dip.erase("won_me")
				c.shocks.approval = float(c.shocks.approval) - 2.0
				text += ". They beat you to it: your site is sold off"
			out.append({"text": text, "icon": str(ALL[wid].icon), "good": false, "big": true})
	return out


## Lasting effects of wonders you own.
static func modifiers() -> Dictionary:
	var out := {}
	if not Game.has_game() or not Game.dip.has("won"):
		return out
	for id in done():
		if not have(str(id)):
			continue
		for k in ALL[id].fx:
			out[k] = float(out.get(k, 0.0)) + float(ALL[id].fx[k])
		for k in ["co2", "life", "rp"]:
			if ALL[id].has(k):
				out[k] = float(out.get(k, 0.0)) + float(ALL[id][k])
	return out


static func prestige() -> float:
	var p := 0.0
	if not Game.dip.has("won"):
		return p
	for id in done():
		if have(str(id)):
			p += float(ALL[id].soft)
	return p
