class_name Cabinet
extends RefCounted
## Your cabinet: four ministers, each with two traits that shape the game a
## little (a Technocrat lifts growth but sounds cold, a Reformer passes laws
## faster, a Diplomat warms the world to you…). Ministers are fictional people
## with names typical of your region. Reshuffles cost a little approval and each
## post can change at most every 6 months. The cabinet you start with is the
## baseline (calibrated), so only changes you make move the numbers.

const POSTS := ["finance", "foreign", "interior", "social"]
const POST_TITLES := {"finance": "Finance", "foreign": "Foreign affairs", "interior": "Interior", "social": "Health & welfare"}
const POST_ICONS := {"finance": "wallet", "foreign": "globe", "interior": "shield", "social": "stethoscope"}
const RESHUFFLE_COOLDOWN := 6
const RESHUFFLE_APPROVAL := -1.0

## fx: target offsets per year; bonus: special abilities (see bonus()).
const TRAITS := {
	"technocrat": {"label": "Technocrat", "good": true, "desc": "Growth +0.12, sounds cold (approval −0.4)", "fx": {"growth": 0.12, "approval": -0.4}},
	"populist": {"label": "Populist", "good": true, "desc": "Approval +1, loose with money (inflation +0.15)", "fx": {"approval": 1.0, "inflation": 0.15}},
	"reformer": {"label": "Reformer", "good": true, "desc": "Laws pass 25% faster", "bonus": {"law_speed": 0.25}},
	"hawk": {"label": "Hawk", "good": true, "desc": "Stability +1, other countries cool on you", "fx": {"stability": 1.0}, "bonus": {"relation_drift": -0.03}},
	"diplomat": {"label": "Diplomat", "good": true, "desc": "Deals more likely, the world warms to you", "bonus": {"deal_acceptance": 0.08, "relation_drift": 0.03}},
	"cautious": {"label": "Cautious", "good": true, "desc": "Crises hit 12% softer", "bonus": {"event_severity": -0.12}},
	"builder": {"label": "Builder", "good": true, "desc": "Projects build 20% faster", "bonus": {"project_speed": 0.2}},
	"popular": {"label": "Popular", "good": true, "desc": "Approval +0.8", "fx": {"approval": 0.8}},
	"veteran": {"label": "Veteran", "good": true, "desc": "Stability +0.5, growth +0.03", "fx": {"stability": 0.5, "growth": 0.03}},
	"economist": {"label": "Economist", "good": true, "desc": "Inflation −0.15", "fx": {"inflation": -0.15}},
	"scandal_prone": {"label": "Scandal-prone", "good": false, "desc": "May drag you into a scandal", "fx": {"approval": -0.3}, "bonus": {"scandal": 0.012}},
	"inexperienced": {"label": "Inexperienced", "good": false, "desc": "Growth −0.05", "fx": {"growth": -0.05}},
}
const GOOD := ["technocrat", "populist", "reformer", "hawk", "diplomat", "cautious", "builder", "popular", "veteran", "economist"]
const BAD := ["scandal_prone", "inexperienced"]

## Fictional names by region (first, last), mixed genders.
const NAMES := {
	"Europe": [["Anna", "Lukas", "Sofia", "Mateo", "Elena", "Jonas", "Clara", "Pietro", "Maja", "Henrik", "Ines", "Tomas"],
		["Weber", "Rossi", "Novak", "Lindqvist", "Moreau", "Kowalski", "Jansen", "Petrov", "Silva", "Horvat", "Dubois", "Berg"]],
	"Americas": [["Lucia", "Daniel", "Camila", "Andres", "Grace", "Miguel", "Valeria", "James", "Renata", "Diego", "Paula", "Marcus"],
		["Ortiz", "Carvalho", "Mendoza", "Reyes", "Walker", "Costa", "Herrera", "Bennett", "Rojas", "Fuentes", "Morgan", "Pereira"]],
	"Africa": [["Amara", "Kwame", "Zainab", "Tendai", "Fatou", "Kofi", "Nia", "Thabo", "Aisha", "Sipho", "Wanjiru", "Moussa"],
		["Mensah", "Okafor", "Diallo", "Ndlovu", "Kamau", "Traore", "Abebe", "Banda", "Osei", "Mwangi", "Keita", "Adeyemi"]],
	"South": [["Priya", "Arjun", "Ananya", "Rahul", "Meera", "Vikram", "Sana", "Imran", "Kavya", "Rohan", "Nadia", "Farhan"],
		["Sharma", "Iyer", "Khan", "Reddy", "Perera", "Chowdhury", "Nair", "Rahman", "Gupta", "Joshi", "Shrestha", "Malik"]],
	"East": [["Mei", "Hiroshi", "Ji-woo", "Wei", "Yuki", "Minh", "Siti", "Kenji", "Lan", "Arif", "Haruka", "Bao"],
		["Chen", "Tanaka", "Kim", "Nguyen", "Wang", "Sato", "Park", "Tan", "Lim", "Santos", "Wijaya", "Li"]],
	"Middle": [["Layla", "Omar", "Yasmin", "Karim", "Noor", "Tariq", "Leila", "Hassan", "Dina", "Murat", "Selin", "Reza"],
		["Haddad", "Mansour", "Aziz", "Yilmaz", "Rahimi", "Khalil", "Nasser", "Demir", "Saleh", "Farouk", "Kaya", "Hosseini"]],
	"Oceania": [["Olivia", "Jack", "Mia", "Liam", "Aroha", "Noah", "Isla", "Tane", "Ruby", "Leo", "Mere", "Finn"],
		["Taylor", "Wilson", "Ngata", "Brown", "Clarke", "Tuilagi", "Murphy", "Walsh", "Parata", "Kelly", "Reid", "Hughes"]],
}

var ministers := {}      # post -> {name, traits: [id, id]}
var candidates := {}     # post -> [minister, …]
var last_change := {}    # post -> months_played
var base_fx := {}        # effects of the starting cabinet (baseline)
var _rng_seed := 0


func reset(rng: RandomNumberGenerator) -> void:
	ministers.clear()
	candidates.clear()
	last_change.clear()
	_rng_seed = rng.randi()
	var r := RandomNumberGenerator.new()
	r.seed = _rng_seed
	for p in POSTS:
		candidates[p] = _pool(r)
		ministers[p] = candidates[p].pop_front()
	base_fx = _fx_sum()


func _name_group() -> String:
	var i := Game.player
	var sub: String = World.map.subregions[i]
	match World.group_of(i):
		"Europe":
			return "Europe"
		"Americas":
			return "Americas"
		"Africa":
			return "Middle" if sub == "Northern Africa" else "Africa"
		"Oceania":
			return "Oceania"
	if sub in ["Southern Asia"]:
		return "South"
	if sub in ["Western Asia", "Central Asia"]:
		return "Middle"
	return "East"


func _pool(r: RandomNumberGenerator) -> Array:
	var out: Array = []
	var p: Array = Names.pool(Game.player)
	var nf: int = p[0].size()
	var nl: int = p[1].size()
	var grp := Leaders.group_of(Game.player)
	for _k in 3:
		var t1: String = GOOD[r.randi() % GOOD.size()]
		var t2: String = GOOD[r.randi() % GOOD.size()] if r.randf() < 0.6 else BAD[r.randi() % BAD.size()]
		if t2 == t1:
			t2 = BAD[r.randi() % BAD.size()]
		var fi := r.randi() % nf
		out.append({"name": Names.full(Game.player, fi, r.randi() % nl), "female": fi % 2 == 0, "group": grp,
			"traits": [t1, t2]})
	return out


func can_change(post: String) -> int:
	return maxi(0, int(last_change.get(post, -100)) + RESHUFFLE_COOLDOWN - Game.months_played)


## Appoint candidate k for a post; the outgoing minister joins the bench.
func appoint(post: String, k: int) -> void:
	var pool: Array = candidates[post]
	if k < 0 or k >= pool.size() or can_change(post) > 0:
		return
	var incoming: Dictionary = pool[k]
	pool[k] = ministers[post]
	ministers[post] = incoming
	last_change[post] = Game.months_played
	Game.me().shocks.approval = float(Game.me().shocks.approval) + RESHUFFLE_APPROVAL
	Game.me().laws_ver += 1
	Game.add_feed("%s is your new %s minister" % [incoming.name, str(POST_TITLES[post]).to_lower()], str(POST_ICONS[post]), "accent")


func _fx_sum() -> Dictionary:
	var out := {}
	for p in ministers:
		for t in ministers[p].traits:
			var fx: Dictionary = TRAITS.get(t, {}).get("fx", {})
			for k in fx:
				out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out


func _bonus_sum(key: String) -> float:
	var s := 0.0
	for p in ministers:
		for t in ministers[p].traits:
			s += float(TRAITS.get(t, {}).get("bonus", {}).get(key, 0.0))
	return s


## Target offsets vs. the starting cabinet (player only).
static func modifiers(_c: CountryState) -> Dictionary:
	var cab = Game.cabinet   # untyped: a static func must not name its own class (leak)
	var now := cab._fx_sum()
	var out := {}
	for k in now:
		out[k] = float(now[k]) - float(cab.base_fx.get(k, 0.0))
	for k in cab.base_fx:
		if not now.has(k):
			out[k] = -float(cab.base_fx[k])
	return out


static func bonus(key: String) -> float:
	return Game.cabinet._bonus_sum(key) if Game.has_game() else 0.0


func minister_for_page(page: String) -> Dictionary:
	var post: String = {"economy": "finance", "budget": "finance", "diplomacy": "foreign", "build": "interior",
		"laws": "interior"}.get(page, "social")
	return {"post": post, "m": ministers.get(post, {})}


## Monthly: relation drift from hawks/diplomats; scandal-prone ministers.
func monthly() -> void:
	var drift := _bonus_sum("relation_drift")
	if absf(drift) > 0.0:
		for i in Game.relations.size():
			if i != Game.player:
				Game.relations[i] = clampf(Game.relations[i] + drift, -100.0, 100.0)
	if Game.rng.randf() < _bonus_sum("scandal") and Game.director.inbox.size() < EventDirector.MAX_OPEN:
		var ev := GameEvents.by_id("scandal")
		if not ev.is_empty():
			Game.director.add(GameEvents.instance(ev))
	if Game.month == 1:     # fresh faces on the bench each year
		var r := RandomNumberGenerator.new()
		r.seed = _rng_seed + Game.year
		for p in POSTS:
			candidates[p] = _pool(r)


func to_dict() -> Dictionary:
	return {"ministers": ministers, "candidates": candidates, "last_change": last_change, "base_fx": base_fx, "seed": _rng_seed}


func load_dict(d: Dictionary, rng: RandomNumberGenerator) -> void:
	if d.is_empty():
		reset(rng)
		return
	ministers = d.get("ministers", {})
	candidates = d.get("candidates", {})
	last_change = d.get("last_change", {})
	base_fx = d.get("base_fx", {})
	_rng_seed = int(d.get("seed", 0))
