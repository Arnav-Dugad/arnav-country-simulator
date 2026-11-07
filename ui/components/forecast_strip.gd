class_name ForecastStrip
extends VBoxContainer
## Live "what happens in 12 months" preview shown while a slider is being moved.
## Compares a projection of the current settings against the settings at the time
## of the last commit (page open / slider released). Throttled to ~8 updates/s.

const MONTHS := 12
## metric -> [label, higher_is_good, min |change| worth showing, formatter kind]
const METRICS := [
	["growth", "Growth", true, 0.05, "pts"],
	["inflation", "Inflation", false, 0.05, "pts"],
	["unemployment", "Jobless", false, 0.05, "pts"],
	["approval", "Approval", true, 0.1, "pts"],
	["happiness", "Happiness", true, 0.1, "pts"],
	["balance", "Budget", true, 0.0, "money"],
]

var _caption: Label
var _flow: HFlowContainer
var _policy := {}   # policy at the time of commit()
var _pending := false
var _last := 0.0


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	visible = false
	_caption = Label.new()
	_caption.theme_type_variation = &"Overline"
	_caption.text = "IN 12 MONTHS, VS. BEFORE YOUR CHANGES"
	add_child(_caption)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override(&"h_separation", 6)
	_flow.add_theme_constant_override(&"v_separation", 6)
	add_child(_flow)


const POLICY_FIELDS := ["income_tax", "corp_tax", "interest_rate", "trade_openness", "spending_pct"]


## Remember the current policy as the comparison point (and hide the strip).
func commit() -> void:
	var c := Game.me()
	if c == null:
		return
	_policy = {"budget": c.budget.duplicate()}
	for f in POLICY_FIELDS:
		_policy[f] = c.get(f)
	visible = false


## Call whenever a slider moves (cheap; work is throttled).
func request() -> void:
	if _pending:
		return
	_pending = true
	var wait := maxf(0.0, 0.12 - (Time.get_ticks_msec() / 1000.0 - _last))
	get_tree().create_timer(wait).timeout.connect(_update)


func _update() -> void:
	_pending = false
	_last = Time.get_ticks_msec() / 1000.0
	var c := Game.me()
	if c == null:
		return
	if _policy.is_empty():
		commit()
	# Same starting point, two policies: yours now vs. the committed one.
	var p := Simulation.project(c, MONTHS)
	var old := c.clone()
	for f in POLICY_FIELDS:
		old.set(f, _policy[f])
	old.budget = _policy.budget.duplicate()
	var _baseline := Simulation.project(old, MONTHS)
	for ch in _flow.get_children():
		ch.queue_free()
	var shown := 0
	for m in METRICS:
		var key: String = m[0]
		var d := float(p.get(key)) - float(_baseline.get(key))
		if key == "balance":
			d = p.balance - _baseline.balance
			if absf(d) < absf(_baseline.gdp) * 0.0005:
				continue
		elif absf(d) < float(m[3]):
			continue
		var good: bool = (d > 0.0) == bool(m[2])
		var txt := "%s %s" % [m[1], DS.money(d, 1) if m[4] == "money" else ("%+.1f" % d)]
		if m[4] == "money" and d > 0.0:
			txt = "%s +%s" % [m[1], DS.money(d, 1)]
		_flow.add_child(_chip(txt, DS.GREEN if good else DS.RED))
		shown += 1
	if shown == 0:
		_flow.add_child(_chip("No big change", DS.TEXT_2))
	if not visible:
		visible = true
		modulate.a = 0.0
		DS.ease_out(create_tween()).tween_property(self, "modulate:a", 1.0, Settings.dur(DS.DUR_FAST))


func _chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ForecastChip"
	var l := Label.new()
	l.theme_type_variation = &"ChipValue"
	l.add_theme_color_override(&"font_color", color)
	l.text = text
	p.add_child(l)
	return p
