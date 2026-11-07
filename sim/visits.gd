class_name Visits
extends RefCounted
## State visits: once a year you can fly to another country and meet its leader.
## Pick what the trip is about; their personality decides how well it lands
## (a trader loves a business delegation, a hawk wants security talks, a
## peacemaker warms to culture). Visiting a country your people distrust builds
## bridges abroad but draws criticism at home.

const COOLDOWN := 12         # months between visits
## agenda -> {label, desc, icon, base relation gain}
const AGENDAS := {
	"trade": {"label": "Business delegation", "desc": "Bring company bosses and talk trade", "icon": "briefcase", "relation": 5.0},
	"security": {"label": "Security talks", "desc": "Borders, defence and intelligence", "icon": "shield", "relation": 4.0},
	"culture": {"label": "Culture and people", "desc": "Students, artists and a famous dinner", "icon": "heart", "relation": 6.0},
}
## personality -> agenda -> multiplier on the relation gain
const TASTE := {
	"trader": {"trade": 1.6, "security": 0.6, "culture": 0.9},
	"nationalist": {"trade": 0.6, "security": 1.2, "culture": 0.5},
	"hawk": {"trade": 0.7, "security": 1.7, "culture": 0.6},
	"peacemaker": {"trade": 1.0, "security": 0.5, "culture": 1.7},
	"reformer": {"trade": 1.3, "security": 0.7, "culture": 1.3},
	"pragmatist": {"trade": 1.2, "security": 1.0, "culture": 1.0},
}


## Months until you can travel again (0 = now).
static func wait() -> int:
	var last := int(Game.dip.get("visit_last", -100))
	return maxi(0, last + COOLDOWN - Game.months_played)


## Makes the visit; returns {relation, approval, growth, deal, line} for the result.
static func visit(i: int, agenda: String) -> Dictionary:
	var ld := Leaders.leader(i)
	var taste := float(TASTE.get(str(ld.personality), {}).get(agenda, 1.0))
	var rel := float(AGENDAS[agenda].relation) * taste
	var me := Game.me()
	var hostile := Game.relations[i] < -20.0
	var appr := 0.0
	if hostile:
		rel *= 1.5            # bridge-building counts for more
		appr -= 1.5           # …but critics at home call it a reward for bad behaviour
	Diplomacy.change_relation(i, rel)
	var grow := 0.0
	var deal := false
	match agenda:
		"trade":
			var them: CountryState = Game.state(i)
			grow = 0.12 * taste * clampf(them.gdp / maxf(me.gdp, 1.0), 0.2, 2.0) if them != null else 0.0
			me.shocks.growth = float(me.shocks.growth) + grow
			# Warm enough now? Sign a trade deal on the spot.
			if not Diplomacy.has_deal(i) and Game.relations[i] >= Diplomacy.DEAL_MIN_RELATION \
					and Game.rng.randf() < Diplomacy.acceptance(i, "deal"):
				deal = Diplomacy.propose_deal(i)
		"security":
			me.shocks.stability = float(me.shocks.stability) + 1.0 * taste
		"culture":
			me.shocks.happiness = float(me.shocks.happiness) + 0.5
	appr += 0.5 if not hostile else 0.0      # a leader on the world stage looks good
	me.shocks.approval = float(me.shocks.approval) + appr
	Game.dip["visit_last"] = Game.months_played
	if not Game.dip.has("visited"):
		Game.dip["visited"] = {}
	Game.dip.visited[World.iso(i)] = Game.months_played
	if Game.dip.visited.size() >= 3:
		Achievements.unlock("globetrotter")
	var first := str(ld.name).split(" ")[0]
	var line := ""
	if taste >= 1.5:
		line = "%s rolled out the red carpet. A great trip." % first
	elif taste >= 1.0:
		line = "A warm welcome from %s and good talks." % first
	else:
		line = "%s was polite, but the talks went nowhere special." % first
	if deal:
		line += " You signed a trade deal before flying home."
	if hostile:
		line += " Critics at home called the trip a mistake."
	Game.add_milestone("State visit to %s" % World.map.names[i], "plane-takeoff", "accent")
	return {"relation": rel, "approval": appr, "growth": grow, "deal": deal, "line": line, "taste": taste}
