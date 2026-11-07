class_name TrendCard
extends PanelContainer
## "Over the last year": each key number's change with a tiny sparkline and the
## biggest force pushing it (from the simulation's named terms, see Simulation).
## Answers "what's happening and why?" at a glance.

const ROWS := [
	["growth", "Growth", "%", true], ["inflation", "Inflation", "%", false],
	["unemployment", "Jobless", "%", false], ["approval", "Approval", "%", true],
	["happiness", "Happiness", "", true],
]

var _box: VBoxContainer


func _ready() -> void:
	theme_type_variation = &"GroupPanel"
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S2)
	add_child(_box)
	refresh()


func refresh() -> void:
	if _box == null or not Game.has_game():
		return
	for ch in _box.get_children():
		ch.queue_free()
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Over the last year"
	_box.add_child(t)
	var c := Game.me()
	for r in ROWS:
		var key: String = r[0]
		var hist: PackedFloat32Array = Game.history.get(key, PackedFloat32Array())
		if hist.size() < 2:
			continue
		var back := mini(12, hist.size() - 1)
		var then := hist[hist.size() - 1 - back]
		var now := hist[hist.size() - 1]
		var d := now - then
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", DS.S2)
		_box.add_child(line)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", -1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var name := Label.new()
		name.theme_type_variation = &"Subhead"
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.custom_minimum_size = Vector2(20, 0)
		var label := str(r[1]) if key != "approval" else Government.support_word(Game.player)
		name.text = "%s  %s" % [label, (String.num(now, 1) + str(r[2])) if str(r[2]) == "%" else String.num(now, 0)]
		col.add_child(name)
		var why := Label.new()
		why.theme_type_variation = &"Caption"
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		why.custom_minimum_size = Vector2(20, 0)
		why.text = _driver(c, key)
		col.add_child(why)
		var spark := LineChart.new()
		spark.minimal = true
		spark.window = 13
		spark.line_width = 1.6
		spark.custom_minimum_size = Vector2(52, 30)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var good: bool = (d >= 0.0) == bool(r[3])
		var flat := absf(d) < 0.15
		spark.set_color(DS.TEXT_3 if flat else (DS.GREEN if good else DS.RED))
		line.add_child(spark)
		spark.set_data(hist)
		var delta := Label.new()
		delta.theme_type_variation = &"StatSmall"
		delta.custom_minimum_size = Vector2(54, 0)
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		delta.text = "No change" if flat else "%s%s" % ["▲ " if d > 0.0 else "▼ ", String.num(absf(d), 1)]
		delta.add_theme_color_override(&"font_color", DS.TEXT_3 if flat else (DS.GREEN if good else DS.RED))
		line.add_child(delta)


## The biggest named force on a metric right now (from the last tick's terms).
static func _driver(c: CountryState, key: String) -> String:
	var terms: Array = c.why.get(key, [])
	var best := ""
	var best_v := 0.0
	for t in terms.slice(1):    # skip the baseline term (starting level / anchor)
		var v := float(t[1])
		if absf(v) > absf(best_v):
			best_v = v
			best = str(t[0])
	if key == "approval" and best == "":
		return "Holding steady"
	if best == "" or absf(best_v) < 0.05:
		return "Holding steady"
	var up := best_v > 0.0
	return "%s %s" % ["Lifted by" if up else "Held back by", best.to_lower()]
