class_name CultureExports
extends RefCounted
## Cultural exports: now and then a film, series, song, game or novel from your
## country becomes a worldwide hit (think of the K-wave). Countries with big
## creative industries score more often; a creative industries fund raises the
## odds anywhere. Each hit lifts soft power and tourism for a few years.
## All titles are invented.
## State: Game.dip.cx {fund, hits: [{m, kind, title}]}. Constants in sim/economy.gd (CX_*).

const E = preload("res://sim/economy.gd")

## Monthly chance of a global hit before any fund (big creative industries).
const BASE := {"USA": 0.05, "KOR": 0.035, "JPN": 0.025, "GBR": 0.025, "IND": 0.02, "FRA": 0.015, "NGA": 0.015,
	"ESP": 0.012, "BRA": 0.012, "MEX": 0.012, "CHN": 0.012, "DEU": 0.01, "SWE": 0.01, "CAN": 0.01, "AUS": 0.008,
	"ITA": 0.008, "TUR": 0.012, "COL": 0.01, "PRI": 0.01, "THA": 0.008, "PHL": 0.008, "EGY": 0.008, "ZAF": 0.006}

const KINDS := {
	"series": {"title": "TV series", "icon": "tv"},
	"film": {"title": "film", "icon": "clapperboard"},
	"song": {"title": "song", "icon": "music"},
	"game": {"title": "video game", "icon": "gamepad-2"},
	"novel": {"title": "novel", "icon": "book-open"},
}
const ADJ := ["Last", "Silent", "Golden", "Hidden", "Midnight", "Paper", "Crimson", "Northern", "Electric", "Quiet",
	"Burning", "Little", "Endless", "Broken", "Velvet", "Seventh", "Wild", "Glass"]
const NOUN := ["Harbour", "Garden", "Kingdom", "River", "Summer", "Signal", "Lanterns", "Orchard", "Station", "Island",
	"Tide", "Mountain", "Market", "Winter", "Bridge", "Sky", "Moon", "Letters"]

const FUNDS := ["none", "some", "big"]
const FUND_INFO := {"none": {"title": "None", "cost": 0.0, "mult": 1.0},
	"some": {"title": "Fund", "cost": 0.03, "mult": 1.8}, "big": {"title": "Big push", "cost": 0.08, "mult": 3.0}}


static func st() -> Dictionary:
	if not Game.dip.has("cx"):
		Game.dip["cx"] = {"fund": "none", "hits": []}
	return Game.dip.cx


static func chance() -> float:
	var c := Game.me()
	var base := float(BASE.get(World.iso(Game.player), 0.0))
	if base == 0.0:
		base = 0.002 + 0.004 * Economy.income_level(c.gdp_per_capita())
	return clampf(base * float(FUND_INFO[str(st().fund)].mult), 0.0, 0.12)


static func set_fund(f: String) -> void:
	st().fund = f


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("cx"):
		return 0.0
	return float(FUND_INFO[str(st().fund)].cost)


static func recent(months: int = E.CX_LASTS) -> Array:
	var out: Array = []
	for h in st().hits:
		if Game.months_played - int(h.m) < months:
			out.append(h)
	return out


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "hits"])
	if Game.months_played >= 3 and r.randf() < chance():
		var kinds: Array = KINDS.keys()
		var k: String = kinds[r.randi() % kinds.size()]
		var title := "%s %s" % [ADJ[r.randi() % ADJ.size()], NOUN[r.randi() % NOUN.size()]]
		if r.randf() < 0.5:
			title = "The " + title
		(s.hits as Array).append({"m": Game.months_played, "kind": k, "title": title})
		if (s.hits as Array).size() > 30:
			(s.hits as Array).pop_front()
		if (s.hits as Array).size() >= 5:
			Achievements.unlock("cultural_wave")
		out.append({"text": "“%s”, a %s from %s, is a worldwide hit" % [title, str(KINDS[k].title), World.the_name(Game.player)],
			"icon": str(KINDS[k].icon), "good": true, "big": true})
	return out


## Soft power from recent hits (fading over CX_LASTS months).
static func prestige() -> float:
	if not Game.dip.has("cx"):
		return 0.0
	var p := 0.0
	for h in recent():
		p += E.CX_SOFT * (1.0 - float(Game.months_played - int(h.m)) / float(E.CX_LASTS))
	return minf(p, 12.0)


## Extra tourism appeal from recent hits.
static func appeal() -> float:
	if not Game.dip.has("cx"):
		return 0.0
	return minf(float(recent(24).size()) * E.CX_APPEAL, 0.15)
