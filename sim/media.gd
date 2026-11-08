class_name Media
extends RefCounted
## Media & propaganda. Two levers:
##   Press stance  free press / guided / state-run. The further toward state
##                 control, the friendlier the coverage (approval, stability) but
##                 people are less happy, credibility is capped lower, government
##                 gets less clean, growth suffers (investors and innovators want
##                 open information) and democracies cool on you. Effects count
##                 relative to where your country started.
##   Campaigns     six-month state media campaigns (pride, health, order, green
##                 habits, investment, rallying behind the troops, or a smear of
##                 the opposition). Their effect = base x reach (higher with more
##                 state control) x trust (press credibility). Repeating a message
##                 within two years wears thin, and every campaign but health
##                 costs a little credibility. A smear can leak, and a free press
##                 is far more likely to find it.
## State: Game.dip.media {stance, start, campaign: {id, start}, last: {id: month}, leaks}.
## Constants in sim/economy.gd (MEDIA_*).

const E = preload("res://sim/economy.gd")

const STANCES := ["free", "guided", "state"]
const STANCE := {
	"free": {"title": "Free press", "icon": "newspaper", "desc": "Independent papers and broadcasters; they hold you to account."},
	"guided": {"title": "Guided", "icon": "radio", "desc": "Friendly owners, licences and quiet pressure keep coverage gentle."},
	"state": {"title": "State-run", "icon": "tv", "desc": "The state controls the big outlets; critics are pushed out."},
}

## id -> {title, icon, desc, fx (full effect at reach x trust = 1), cost (% of GDP, paid at launch)}
const CAMPAIGNS := {
	"pride": {"title": "Proud nation", "icon": "flag", "desc": "Anthems, achievements and national heroes on every screen.",
		"fx": {"approval": 3.0, "stability": 1.0}, "cost": 0.08},
	"health": {"title": "Healthy lives", "icon": "heart-pulse", "desc": "Vaccines, exercise and quitting smoking. Honest and popular.",
		"fx": {"happiness": 1.5, "life": 0.3}, "cost": 0.06, "honest": true},
	"order": {"title": "Calm and order", "icon": "shield", "desc": "Reassurance, safety tips and praise for the police.",
		"fx": {"stability": 4.0}, "cost": 0.08},
	"green": {"title": "Green habits", "icon": "leaf", "desc": "Save energy, take the train, recycle.",
		"fx": {"co2": 0.03, "happiness": 0.5}, "cost": 0.05, "honest": true},
	"invest": {"title": "Invest in us", "icon": "trending-up", "desc": "Glossy ads abroad selling your country to investors and tourists.",
		"fx": {"growth": 0.3}, "cost": 0.12},
	"troops": {"title": "Behind our troops", "icon": "swords", "desc": "Rally the country behind the war effort.",
		"fx": {"approval": 3.0, "stability": 3.0}, "cost": 0.06, "war": true},
	"smear": {"title": "Discredit the opposition", "icon": "eye-off", "desc": "Leaks, attack ads and friendly columnists go after your opponents. Risky.",
		"fx": {"approval": 4.0}, "cost": 0.04, "smear": true},
}


static func st() -> Dictionary:
	if not Game.dip.has("media"):
		var s0 := start_stance()
		Game.dip["media"] = {"stance": s0, "start": s0, "campaign": {}, "last": {}, "leaks": 0}
	return Game.dip.media


## Where the country starts: free press in free democracies with press laws,
## guided in other democracies, state-run under closed systems.
static func start_stance() -> String:
	var c := Game.me()
	if c != null and Laws.is_active(c, "press_freedom"):
		return "free"
	if Government.is_free(Game.player):
		return "free" if Economy.income_level(c.gdp_per_capita()) > 0.45 else "guided"
	return "state"


static func stance() -> String:
	return str(st().stance)


static func rank(s: String) -> int:
	return STANCES.find(s)


## Steps toward state control since you took office (negative = freer).
static func steps() -> int:
	return rank(stance()) - rank(str(st().start))


## Reach of state messaging (campaign multiplier).
static func reach() -> float:
	return [E.MEDIA_REACH_FREE, E.MEDIA_REACH_GUIDED, E.MEDIA_REACH_STATE][rank(stance())]


## Highest credibility people grant a press that isn't free.
static func cred_cap() -> float:
	return [100.0, E.MEDIA_CRED_CAP_GUIDED, E.MEDIA_CRED_CAP_STATE][rank(stance())]


## "" if you can switch to this stance now, else why not.
static func blocked(s: String) -> String:
	if s == stance():
		return "Current"
	var c := Game.me()
	if rank(s) > 0 and Laws.is_active(c, "press_freedom"):
		return "Repeal the press freedom guarantee first"
	if rank(s) > rank(stance()) and not Capital.can(E.CAPITAL_MEDIA_CONTROL):
		return "Needs %d political capital" % int(E.CAPITAL_MEDIA_CONTROL)
	return ""


## Switch stance. Tightening control costs capital and sparks protest (more in
## free systems); loosening it wins trust and happiness.
static func set_stance(s: String) -> void:
	if blocked(s) != "":
		return
	var c := Game.me()
	var d := rank(s) - rank(stance())
	if d > 0:
		Capital.spend(E.CAPITAL_MEDIA_CONTROL)
		var free := Government.is_free(Game.player)
		c.shocks.stability = float(c.shocks.stability) - E.MEDIA_CRACKDOWN_STAB * d * (1.5 if free else 0.7)
		c.shocks.approval = float(c.shocks.approval) - E.MEDIA_CRACKDOWN_APPR * d * (1.5 if free else 0.5)
		Press.apply_cred(-8.0 * d)
		for j in World.playable:
			if j != Game.player and Government.is_democracy(j):
				Game.relations[j] = clampf(Game.relations[j] - E.MEDIA_DEMOCRACY_REL * d, -100.0, 100.0)
		Game.relations_changed.emit()
		Game.add_feed("Media crackdown: %s" % ("broadcasters brought under state control" if s == "state" else "pressure on newsrooms grows"), "tv", "orange")
	else:
		Press.apply_cred(6.0 * -d)
		c.shocks.happiness = float(c.shocks.happiness) + 1.5 * -d
		Game.add_feed("Press freedom restored: newsrooms celebrate" if s == "free" else "State grip on the media loosens", "newspaper", "green")
	st().stance = s
	Game.add_milestone("Media: %s" % str(STANCE[s].title).to_lower(), str(STANCE[s].icon), "orange" if d > 0 else "accent")


# ----------------------------------------------------------------- campaigns ---
static func campaign() -> Dictionary:
	return st().campaign


static func months_left() -> int:
	var cp := campaign()
	if cp.is_empty():
		return 0
	return maxi(0, int(cp.start) + E.MEDIA_CAMPAIGN_MONTHS - Game.months_played)


static func cost(id: String) -> float:
	return Game.me().gdp * float(CAMPAIGNS[id].cost) / 100.0


## "" if this campaign can start, else why not.
static func can_launch(id: String) -> String:
	var cp: Dictionary = CAMPAIGNS[id]
	if not campaign().is_empty():
		return "Another campaign is running"
	if bool(cp.get("war", false)) and not War.at_war():
		return "Only in wartime"
	if bool(cp.get("smear", false)) and not Opposition.active():
		return "No organised opposition to attack"
	return ""


## Effect multiplier: reach x trust x freshness (a repeated message wears thin).
static func power(id: String) -> float:
	var trust := 0.5 + Press.credibility() / 100.0           # 0.5 .. 1.5
	var last := int((st().last as Dictionary).get(id, -1000))
	var fresh := E.MEDIA_REPEAT_MULT if Game.months_played - last < 24 else 1.0
	return reach() * trust * fresh


static func launch(id: String) -> bool:
	if can_launch(id) != "":
		return false
	var c := Game.me()
	c.treasury -= cost(id)
	st().campaign = {"id": id, "start": Game.months_played, "power": power(id)}
	(st().last as Dictionary)[id] = Game.months_played
	if not bool(CAMPAIGNS[id].get("honest", false)):
		Press.apply_cred(-E.MEDIA_CAMPAIGN_CRED)
	Game.add_feed("Campaign launched: %s" % str(CAMPAIGNS[id].title), str(CAMPAIGNS[id].icon), "accent")
	return true


## Chance a smear leaks, per month.
static func leak_chance() -> float:
	return [E.MEDIA_LEAK_FREE, E.MEDIA_LEAK_GUIDED, E.MEDIA_LEAK_STATE][rank(stance())]


## Monthly: credibility settles under the cap; campaigns run out; smears may leak.
## Returns headlines [{text, icon, good}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var cap := cred_cap()
	if Press.credibility() > cap:
		Press.apply_cred(-minf(2.0, Press.credibility() - cap))
	var cp := campaign()
	if cp.is_empty():
		return out
	var id := str(cp.id)
	if bool(CAMPAIGNS[id].get("smear", false)) and not bool(cp.get("leaked", false)) and Game.rng.randf() < leak_chance():
		cp["leaked"] = true
		st().leaks = int(st().leaks) + 1
		var c := Game.me()
		c.shocks.approval = float(c.shocks.approval) - E.MEDIA_LEAK_APPR
		Press.apply_cred(-E.MEDIA_LEAK_CRED)
		out.append({"text": "Leaked: reporters expose the government's smear campaign against the opposition", "icon": "eye-off", "good": false})
	if months_left() <= 0:
		out.append({"text": "The %s campaign has ended" % str(CAMPAIGNS[id].title).to_lower(), "icon": str(CAMPAIGNS[id].icon), "good": true})
		st().campaign = {}
	return out


## Target offsets from your media policy and the campaign running now.
static func modifiers() -> Dictionary:
	var out := {}
	if not Game.has_game() or not Game.dip.has("media"):
		return out
	var d := float(steps())
	if d != 0.0:
		out["approval"] = E.MEDIA_STEP_APPROVAL * d
		out["stability"] = E.MEDIA_STEP_STABILITY * d
		out["happiness"] = -E.MEDIA_STEP_HAPPY * d
		out["growth"] = -E.MEDIA_STEP_GROWTH * d
	var cp := campaign()
	if not cp.is_empty() and not bool(cp.get("leaked", false)):
		var p := float(cp.get("power", 1.0))
		var fx: Dictionary = CAMPAIGNS[str(cp.id)].fx
		for k in fx:
			out[k] = float(out.get(k, 0.0)) + float(fx[k]) * p
	return out


## Clean-government target offset (points): a captured press hides graft.
static func clean_offset() -> float:
	return -E.MEDIA_STEP_CLEAN * float(steps())
