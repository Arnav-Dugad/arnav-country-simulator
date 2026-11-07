class_name Goals
extends RefCounted
## National goals: three personal milestones picked at the start from your
## country's real weaknesses (high inflation, joblessness, debt, unrest, low
## income…), each relative to where you started so they're always reachable
## but never free. Reaching one gives a small approval boost, a celebration and
## points toward your legacy grade. When one is done, a new one takes its place.

const SLOTS := 3
const REWARD_APPROVAL := 2.5

## id -> spec. "need" says when it's a sensible goal; target is computed at pick time.
const SPECS := {
	"inflation": {"icon": "flame", "title": "Tame prices", "fmt": "pct", "metric": "inflation", "dir": -1},
	"jobs": {"icon": "users", "title": "More jobs", "fmt": "pct", "metric": "unemployment", "dir": -1},
	"debt": {"icon": "piggy-bank", "title": "Cut the debt", "fmt": "pct0", "metric": "debt_pct", "dir": -1},
	"stability": {"icon": "shield", "title": "A calmer country", "fmt": "num", "metric": "stability", "dir": 1},
	"happiness": {"icon": "heart", "title": "Happier people", "fmt": "num", "metric": "happiness", "dir": 1},
	"income": {"icon": "coins", "title": "Raise incomes", "fmt": "money", "metric": "gdp_pc", "dir": 1},
	"surplus": {"icon": "wallet", "title": "Balance the budget", "fmt": "pct_signed", "metric": "balance_pct", "dir": 1},
	"growth": {"icon": "trending-up", "title": "Grow faster", "fmt": "pct", "metric": "growth", "dir": 1},
	"builder": {"icon": "hammer", "title": "Build the nation", "fmt": "count", "metric": "projects", "dir": 1},
	"friends": {"icon": "handshake", "title": "Open for business", "fmt": "count", "metric": "deals", "dir": 1},
	"rating": {"icon": "landmark", "title": "Win the markets' trust", "fmt": "rating", "metric": "rating", "dir": 1},
	"greener": {"icon": "leaf", "title": "Cut emissions", "fmt": "co2", "metric": "co2_pc", "dir": -1},
}


static func value(metric: String) -> float:
	var c := Game.me()
	match metric:
		"debt_pct":
			return c.debt_pct()
		"balance_pct":
			return c.balance_pct()
		"gdp_pc":
			return c.real_gdp_per_capita()
		"projects":
			return float(c.projects.values().filter(func(p: Dictionary) -> bool:
				return str(p.state) == "done" and not bool(p.get("start", false))).size())
		"deals":
			return float(c.trade_deals)
		"rating":
			return c.rating_score()
		"co2_pc":
			return Climate.co2_pc(c)
	return float(c.get(metric))


## Candidate goals for this country, most needed first: [[id, target], …].
static func candidates() -> Array:
	var c := Game.me()
	var b: Dictionary = c.base
	var out: Array = []
	if c.inflation > 5.0:
		out.append([10.0, "inflation", maxf(c.inflation * 0.6, 3.0)])
	if c.unemployment > 6.0:
		out.append([8.0, "jobs", maxf(c.unemployment - 2.0, c.unemployment * 0.75)])
	if c.debt_pct() > 70.0:
		out.append([7.0, "debt", c.debt_pct() - 15.0])
	if c.stability < 45.0:
		out.append([9.0, "stability", c.stability + 12.0])
	if -c.balance_pct() > 3.0:
		out.append([6.0, "surplus", -1.0])
	if c.happiness < 60.0:
		out.append([5.0, "happiness", c.happiness + 8.0])
	if Economy.income_level(c.gdp_per_capita()) < 0.6:
		out.append([6.5, "income", c.real_gdp_per_capita() * 1.25])
	if c.growth < 2.5:
		out.append([4.0, "growth", c.trend + 1.0])
	if c.rating_score() < 80.0:
		out.append([3.0, "rating", c.rating_score() + 12.0])
	if World.stat(c.idx, "co2_pc", 0.0) > 6.0:
		out.append([3.5, "greener", Climate.co2_pc(c) * 0.85])
	# Always-available ambitions.
	out.append([2.0, "builder", value("projects") + 3.0])
	out.append([1.5, "friends", value("deals") + 3.0])
	out.append([1.0, "happiness", c.happiness + 6.0])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	return out.map(func(x: Array) -> Array: return [x[1], x[2]])


static func _state() -> Dictionary:
	if not Game.dip.has("goals"):
		Game.dip["goals"] = {"active": [], "done": []}
	return Game.dip.goals


static func active() -> Array:
	return _state().active


static func done_count() -> int:
	return _state().done.size()


## Fill empty slots (start of game, or after a goal is reached).
static func refill() -> void:
	var st := _state()
	var taken: Array = st.active.map(func(g: Dictionary) -> String: return str(g.id))
	for d in st.done.slice(maxi(0, st.done.size() - 3)):
		taken.append(str(d.id))     # not the same goal again right away
	for cand in candidates():
		if st.active.size() >= SLOTS:
			break
		if str(cand[0]) in taken:
			continue
		var spec: Dictionary = SPECS[cand[0]]
		st.active.append({"id": cand[0], "target": float(cand[1]), "from": value(str(spec.metric)), "since": Game.months_played})
		taken.append(str(cand[0]))


## 0..1 progress from where you started toward the target.
static func progress(g: Dictionary) -> float:
	var spec: Dictionary = SPECS[g.id]
	var now := value(str(spec.metric))
	var from := float(g.from)
	var target := float(g.target)
	if absf(target - from) < 0.0001:
		return 1.0
	return clampf((now - from) / (target - from), 0.0, 1.0)


static func met(g: Dictionary) -> bool:
	var spec: Dictionary = SPECS[g.id]
	var now := value(str(spec.metric))
	return now <= float(g.target) if int(spec.dir) < 0 else now >= float(g.target)


## Monthly: completes goals that are met. Returns the ones just reached.
static func monthly() -> Array:
	var st := _state()
	var reached: Array = []
	for g in st.active.duplicate():
		if met(g):
			st.active.erase(g)
			var rec: Dictionary = g.duplicate()
			rec["year"] = Game.year
			st.done.append(rec)
			reached.append(g)
			Game.me().shocks.approval = float(Game.me().shocks.approval) + REWARD_APPROVAL
	if not reached.is_empty() or st.active.size() < SLOTS:
		refill()
	return reached


static func title(g: Dictionary) -> String:
	return str(SPECS[g.id].title)


static func fmt(g: Dictionary, v: float) -> String:
	match str(SPECS[g.id].fmt):
		"pct":
			return DS.pct(v)
		"pct0":
			return DS.pct(v, 0)
		"pct_signed":
			return ("surplus" if v >= 0.0 else "deficit %s" % DS.pct(-v)) if v < 0.0 or v > 0.0 else "balanced"
		"money":
			return DS.money(v, 0)
		"count":
			return str(roundi(v))
		"rating":
			return Economy.rating_grade(v)
		"co2":
			return "%s t" % String.num(v, 1)
	return String.num(v, 0)


## "Inflation 9.4% → 5.6%"
static func describe(g: Dictionary) -> String:
	var spec: Dictionary = SPECS[g.id]
	var now := value(str(spec.metric))
	return "Now %s  ·  Goal %s" % [fmt(g, now), fmt(g, float(g.target))]
