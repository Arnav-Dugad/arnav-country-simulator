class_name Water
extends RefCounted
## Water: scarcity at home and rivers shared with neighbours.
##   Stress       how much of the renewable water a country uses each year
##                (WRI Aqueduct baseline water stress, 0-5). It rises with
##                population and warming; shortages cut happiness and harvests.
##   Answers      desalination plants (one at a time, three years each), drip
##                irrigation for farms, recycling city water.
##   Rivers       real shared rivers. An upstream country can build a mega-dam:
##                clean power and secure water for it, less water downstream and
##                furious neighbours. Upstream powers may dam your river too:
##                negotiate a water treaty, go to the UN, or warn them off.
## Effects count only the change since you took office.
## State: Game.dip.water {s0, s, pop0, w0, desal, desal_build (month or -1), drip, recycle,
##                         dams: {river: iso of builder}, my_dam {river, start}, treaty: {river: true}}.
## Constants in sim/economy.gd (WAT_*).

const E = preload("res://sim/economy.gd")

## WRI Aqueduct 2019 baseline water stress (0-5), rounded; others estimated.
const STRESS := {"QAT": 4.97, "ISR": 4.82, "LBN": 4.82, "IRN": 4.57, "JOR": 4.56, "LBY": 4.55, "KWT": 4.43,
	"SAU": 4.35, "ERI": 4.33, "ARE": 4.26, "BHR": 4.13, "IND": 4.12, "PAK": 4.05, "TKM": 4.04, "OMN": 4.04,
	"BWA": 4.02, "CHL": 3.98, "CYP": 3.96, "YEM": 3.94, "MAR": 3.89, "BEL": 3.82, "MEX": 3.86, "UZB": 3.71,
	"GRC": 3.69, "AFG": 3.60, "ESP": 3.74, "DZA": 3.56, "TUN": 3.42, "SYR": 3.38, "TUR": 3.33, "EGY": 3.22,
	"ITA": 3.22, "IRQ": 3.17, "PRT": 3.10, "ZAF": 2.95, "CHN": 2.85, "AUS": 2.44, "USA": 2.20, "DEU": 1.80,
	"FRA": 1.75, "GBR": 1.10, "JPN": 1.70, "KOR": 2.60, "TWN": 2.10, "THA": 1.80, "VNM": 1.10, "IDN": 1.40,
	"ETH": 1.40, "SDN": 2.70, "NGA": 0.90, "BRA": 0.90, "RUS": 0.60, "CAN": 0.60, "ARG": 1.50, "PER": 2.40,
	"BGD": 1.50, "KAZ": 2.80, "KGZ": 3.30, "TJK": 2.60, "LAO": 0.30, "KHM": 0.40, "MMR": 0.40, "NPL": 3.20,
	"SWE": 0.60, "NOR": 0.30, "FIN": 0.40, "POL": 2.10, "UKR": 1.90, "NLD": 2.00, "CHE": 1.10}

## Shared rivers: upstream country -> downstream countries.
const RIVERS := {
	"nile": {"title": "the Nile", "up": "ETH", "down": ["SDN", "EGY"]},
	"indus": {"title": "the Indus", "up": "IND", "down": ["PAK"]},
	"brahmaputra": {"title": "the Brahmaputra", "up": "CHN", "down": ["IND", "BGD"]},
	"mekong": {"title": "the Mekong", "up": "CHN", "down": ["LAO", "THA", "KHM", "VNM"]},
	"euphrates": {"title": "the Tigris and Euphrates", "up": "TUR", "down": ["SYR", "IRQ"]},
	"ganges": {"title": "the Ganges", "up": "IND", "down": ["BGD"]},
	"amu_darya": {"title": "the Amu Darya", "up": "TJK", "down": ["UZB", "TKM"]},
	"syr_darya": {"title": "the Syr Darya", "up": "KGZ", "down": ["UZB", "KAZ"]},
	"colorado": {"title": "the Colorado", "up": "USA", "down": ["MEX"]},
	"jordan": {"title": "the Jordan", "up": "ISR", "down": ["JOR"]},
	"niger": {"title": "the Niger", "up": "MLI", "down": ["NER", "NGA"]},
}

## Big dams already built by 2026 (already part of everyone's starting stress).
const EXISTING := {"nile": "ETH", "euphrates": "TUR", "mekong": "CHN", "colorado": "USA", "amu_darya": "TJK",
	"syr_darya": "KGZ", "ganges": "IND", "jordan": "ISR"}


static func st() -> Dictionary:
	if not Game.dip.has("water"):
		var c := Game.me()
		var iso := World.iso(Game.player)
		var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
		var s := float(STRESS.get(iso, clampf(1.2 + 0.02 * World.stat(Game.player, "agriculture_pct", 10.0) * 10.0 * (1.0 - lvl) + (1.5 if World.map.subregions[Game.player] in ["Western Asia", "Northern Africa"] else 0.0), 0.2, 4.5)))
		Game.dip["water"] = {"s0": s, "s": s, "pop0": c.population if c != null else 1.0, "w0": Climate.warming(),
			"desal": 0, "desal_build": -1, "drip": false, "recycle": false, "dams": {}, "my_dam": {}, "treaty": {}, "old": EXISTING.duplicate()}
	return Game.dip.water


static func stress() -> float:
	return float(st().s)


static func label(s: float) -> String:
	if s >= 4.0:
		return "Extremely high"
	if s >= 3.0:
		return "High"
	if s >= 2.0:
		return "Medium-high"
	if s >= 1.0:
		return "Low-medium"
	return "Low"


static func color(s: float) -> Color:
	return DS.RED if s >= 4.0 else (DS.ORANGE if s >= 3.0 else (DS.GOLD if s >= 2.0 else DS.GREEN))


## Rivers you share: [{id, title, up (bool), other isos}]
static func my_rivers() -> Array:
	var iso := World.iso(Game.player)
	var out: Array = []
	for id in RIVERS:
		var r: Dictionary = RIVERS[id]
		if str(r.up) == iso:
			out.append({"id": id, "title": r.title, "up": true, "others": r.down})
		elif iso in r.down:
			out.append({"id": id, "title": r.title, "up": false, "others": [r.up]})
	return out


# ------------------------------------------------------------------ actions ---
static func desal_relief() -> float:
	return E.WAT_DESAL_RELIEF * float(st().desal)


static func can_desal() -> bool:
	return int(st().desal_build) < 0 and int(st().desal) < E.WAT_DESAL_MAX and World.landlocked(Game.player) == false


static func build_desal() -> bool:
	if not can_desal():
		return false
	st().desal_build = Game.months_played
	Game.add_feed("Work starts on a desalination plant", "droplets", "accent")
	return true


static func set_drip(on: bool) -> void:
	st().drip = on


static func set_recycle(on: bool) -> void:
	st().recycle = on


static func drip_relief() -> float:
	return E.WAT_DRIP_RELIEF * clampf(World.stat(Game.player, "agriculture_pct", 8.0) / 10.0, 0.5, 1.5)


static func can_dam(id: String) -> bool:
	var r: Dictionary = RIVERS[id]
	return str(r.up) == World.iso(Game.player) and not (st().dams as Dictionary).has(id) and not old_dam(id) and (st().my_dam as Dictionary).is_empty()


static func old_dam(id: String) -> bool:
	return (st().get("old", {}) as Dictionary).has(id)


static func start_dam(id: String) -> bool:
	if not can_dam(id) or not Capital.spend(E.WAT_DAM_CAPITAL):
		return false
	st().my_dam = {"river": id, "start": Game.months_played}
	for iso in RIVERS[id].down:
		var j := World.index_of(str(iso))
		if j >= 0:
			Diplomacy.change_relation(j, -E.WAT_DAM_ANGER)
	Game.add_feed("Work begins on a mega-dam on %s" % str(RIVERS[id].title), "waves", "orange")
	Game.intel_news.emit({"text": "%s starts a mega-dam on %s. Downstream, %s protest." % [World.The_name(Game.player), str(RIVERS[id].title), ", ".join(_names(RIVERS[id].down))],
		"icon": "waves", "good": false, "big": true})
	return true


static func _names(isos: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for iso in isos:
		var j := World.index_of(str(iso))
		if j >= 0:
			out.append(World.map.names[j])
	return out


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("water"):
		return 0.0
	var s := st()
	var p := E.WAT_DESAL_UPKEEP * float(s.desal)
	if int(s.desal_build) >= 0:
		p += E.WAT_DESAL_COST
	if bool(s.drip):
		p += E.WAT_DRIP_COST
	if bool(s.recycle):
		p += E.WAT_RECYCLE_COST
	if not (s.my_dam as Dictionary).is_empty():
		p += E.WAT_DAM_COST
	return p


## Extra stress from dams upstream (halved by a treaty).
static func upstream_penalty() -> float:
	var s := st()
	var p := 0.0
	for r in my_rivers():
		if not bool(r.up) and (s.dams as Dictionary).has(r.id):
			p += E.WAT_DAM_DOWNSTREAM * (0.5 if (s.treaty as Dictionary).has(r.id) else 1.0)
	return p


static func target() -> float:
	var s := st()
	var c := Game.me()
	var t := float(s.s0) * pow(maxf(c.population / maxf(float(s.pop0), 1.0), 0.3), 0.35)
	t *= 1.0 + E.WAT_WARMING * (Climate.warming() - float(s.w0))
	t -= desal_relief()
	if bool(s.drip):
		t -= drip_relief()
	if bool(s.recycle):
		t -= E.WAT_RECYCLE_RELIEF
	for id in s.dams:
		if str(s.dams[id]) == World.iso(Game.player):
			t -= E.WAT_DAM_RELIEF
	t += upstream_penalty()
	return clampf(t, 0.0, 5.0)


# -------------------------------------------------------------------- events ---
static func dam_event(id: String) -> Dictionary:
	var r: Dictionary = RIVERS[id]
	var up := World.index_of(str(r.up))
	return {"id": "river_dam", "title": "A dam on %s" % str(r.title), "icon": "waves", "tint": "orange", "other": up,
		"next": {}, "face": "", "scene_hint": "",
		"body": "%s has started filling a vast new dam upstream on %s. Less water will reach %s's farms and cities." % [
			World.The_name(up), str(r.title), World.the_name(Game.player)],
		"choices": [
			{"label": "Negotiate a water treaty", "detail": "10 political capital · halves the loss",
				"effects": {"water": "treaty:" + id, "relation": 5.0}},
			{"label": "Take it to the UN", "detail": "Sympathy abroad · the loss stays",
				"effects": {"relations_all": 1.0, "approval": 1.0}},
			{"label": "Warn them off", "detail": "Relations fall · they may fill it more slowly",
				"effects": {"water": "warn:" + id, "relation": -20.0, "approval": 2.0, "stability": 1.0}},
		]}


static func score(v: String) -> float:
	if v.begins_with("treaty"):
		return 2.0 if Capital.can(10.0) else -5.0
	if v.begins_with("warn"):
		return -1.0
	return 0.0


static func apply(v: String) -> void:
	var p := v.split(":")
	if p.size() < 2:
		return
	var s := st()
	match p[0]:
		"treaty":
			if Capital.spend(10.0):
				(s.treaty as Dictionary)[p[1]] = true
				Game.add_feed("Water treaty signed on %s" % str(RIVERS[p[1]].title), "handshake", "green")
		"warn":
			var r := RandomNumberGenerator.new()
			r.seed = hash([Game.rng.seed, Game.months_played, "warn"])
			if r.randf() < 0.4:
				(s.treaty as Dictionary)[p[1]] = true
				Game.add_feed("They agree to fill the dam slowly", "waves", "green")


# ------------------------------------------------------------------- monthly ---
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	if int(s.desal_build) >= 0 and Game.months_played - int(s.desal_build) >= E.WAT_DESAL_MONTHS:
		s.desal_build = -1
		s.desal = int(s.desal) + 1
		Game.add_feed("A new desalination plant opens", "droplets", "green")
	var md: Dictionary = s.my_dam
	if not md.is_empty() and Game.months_played - int(md.start) >= E.WAT_DAM_MONTHS:
		(s.dams as Dictionary)[str(md.river)] = World.iso(Game.player)
		s.my_dam = {}
		Game.add_milestone("Opened a mega-dam on %s" % str(RIVERS[str(md.river)].title), "waves", "gold")
		out.append({"text": "%s's mega-dam on %s opens: clean power and water for decades" % [World.The_name(Game.player), str(RIVERS[str(md.river)].title)],
			"icon": "waves", "good": true, "big": true, "celebrate": true})
	# Upstream powers may dam your rivers (own random stream).
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "water"])
	if Game.months_played >= 18:
		for rv in my_rivers():
			if bool(rv.up) or (s.dams as Dictionary).has(rv.id) or old_dam(str(rv.id)):
				continue
			if r.randf() < E.WAT_AI_DAM:
				(s.dams as Dictionary)[rv.id] = str(RIVERS[rv.id].up)
				Game.director.add(dam_event(str(rv.id)))
				out.append({"text": "%s dams %s upstream of you" % [World.The_name(World.index_of(str(RIVERS[rv.id].up))), str(rv.title)],
					"icon": "waves", "good": false, "big": true})
				break
	s.s = float(s.s) + (target() - float(s.s)) * 0.04
	if stress() <= float(s.s0) - 1.0:
		Achievements.unlock("water_wise")
	return out


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("water"):
		return {}
	var d := stress() - float(st().s0)
	var g := -d * E.WAT_GROWTH
	for id in st().dams:
		if str(st().dams[id]) == World.iso(Game.player):
			g += 0.15     # hydropower
	return {"happiness": clampf(-d * 0.8, -2.5, 1.5), "growth": clampf(g, -0.5, 0.5)}
