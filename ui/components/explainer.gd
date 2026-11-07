class_name Explainer
extends ModalCard
## "Why?" card for a stat: plain meaning, where it is heading, every factor that
## pushes it (exact terms from Simulation.tick), and what the player can do.

const INFO := {
	"growth": {"title": "Economic growth", "unit": "%", "good_up": true, "icon": "trending-up", "tint": "accent",
		"meaning": "How fast your economy grows each year, after inflation. 2–3% is healthy for rich countries; poorer countries can grow faster.",
		"tips": ["Lower taxes or interest rates for a quick boost.",
			"Spend more on infrastructure, research and education for growth that lasts.",
			"Open up trade and sign trade deals."]},
	"inflation": {"title": "Inflation", "unit": "%", "good_up": false, "icon": "flame", "tint": "orange",
		"meaning": "How fast prices rise each year. Around 2% is ideal. High inflation makes people poorer and angry.",
		"tips": ["Raise the interest rate to cool prices (it slows growth for a while).",
			"Shrink the budget deficit.", "Avoid trade barriers, which push prices up."]},
	"unemployment": {"title": "Unemployment", "unit": "%", "good_up": false, "icon": "users", "tint": "purple",
		"meaning": "The share of people who want a job but can't find one.",
		"tips": ["A faster-growing economy creates jobs.", "Very high interest rates cost jobs.",
			"Education lowers unemployment over the long run."]},
	"happiness": {"title": "Happiness", "unit": "", "good_up": true, "icon": "heart", "tint": "red",
		"meaning": "How satisfied people are with their lives, from 0 to 100.",
		"tips": ["Spend more on healthcare, welfare and education.",
			"Keep prices stable and jobs plentiful.", "Avoid raising income tax."]},
	"approval": {"title": "Approval", "unit": "%", "good_up": true, "icon": "vote", "tint": "green",
		"meaning": "The share of voters who back you. Above 50% at election time and you win.",
		"tips": ["Happy people approve of their leader.", "Keep inflation low and the economy moving.",
			"Income tax rises are unpopular; trade deals and alliances help a little."]},
	"stability": {"title": "Stability", "unit": "", "good_up": true, "icon": "shield", "tint": "teal",
		"meaning": "How calm and orderly your country is, from 0 to 100. If it stays very low, your government can fall.",
		"tips": ["Keep approval and happiness up.", "Keep unemployment down.",
			"More military spending adds a little stability."]},
}

var metric := "growth"


static func open(parent: Node, metric_: String) -> ModalCard:
	var e: ModalCard = load("res://ui/components/explainer.gd").new()
	e.set(&"metric", metric_)
	parent.add_child(e)
	return e


func _ready() -> void:
	var c := Game.me()
	var info: Dictionary = INFO[metric]
	var now := float(c.get(metric))
	var target := float(c.targets.get(metric, now))
	header(str(info.icon), GameEvents.tint(str(info.tint)), "Why is it moving?",
		"%s  %s" % [info.title, _fmt(now, info.unit)])
	body(str(info.meaning))

	# Direction line
	var dir := target - now
	var dir_label := Label.new()
	dir_label.theme_type_variation = &"Headline"
	dir_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if absf(dir) < 0.05:
		dir_label.text = "Holding steady around %s" % _fmt(target, info.unit)
		dir_label.add_theme_color_override(&"font_color", DS.TEXT_2)
	else:
		var good: bool = (dir > 0.0) == bool(info.good_up)
		dir_label.text = "%s toward %s" % ["Rising" if dir > 0.0 else "Falling", _fmt(target, info.unit)]
		dir_label.add_theme_color_override(&"font_color", DS.GREEN if good else DS.RED)
	content.add_child(dir_label)

	# Factors
	var terms: Array = c.why.get(metric, [])
	if not terms.is_empty():
		var cap := Label.new()
		cap.theme_type_variation = &"Overline"
		cap.text = "WHAT'S PUSHING IT"
		content.add_child(cap)
		var base: Array = terms[0]
		var rest := terms.slice(1).filter(func(t: Array) -> bool: return absf(float(t[1])) >= 0.05)
		rest.sort_custom(func(x: Array, y: Array) -> bool: return absf(float(x[1])) > absf(float(y[1])))
		var biggest := 0.1
		for t in rest:
			biggest = maxf(biggest, absf(float(t[1])))
		content.add_child(_row(str(base[0]), _fmt(float(base[1]), info.unit), 0.0, DS.TEXT_2, true))
		for t in rest.slice(0, 6):
			var v := float(t[1])
			var good: bool = (v > 0.0) == bool(info.good_up)
			content.add_child(_row(str(t[0]), ("+" if v > 0.0 else "") + _fmt(v, info.unit),
				absf(v) / biggest, DS.GREEN if good else DS.RED, false))
		if rest.is_empty():
			note_label("Nothing is pushing it away from its usual level right now.")

	# Tips
	var tip_cap := Label.new()
	tip_cap.theme_type_variation = &"Overline"
	tip_cap.text = "WHAT YOU CAN DO"
	content.add_child(tip_cap)
	for tip in info.tips:
		note_label("•  " + str(tip))
	choice("Got it", "", &"PrimaryButton", dismiss)
	super._ready()


func note_label(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"Footnote"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)


func _row(label: String, value: String, frac: float, color: Color, is_base: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	var h := HBoxContainer.new()
	box.add_child(h)
	var l := Label.new()
	l.theme_type_variation = &"Subhead" if is_base else &"Body"
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.theme_type_variation = &"StatSmall"
	v.text = value
	v.add_theme_color_override(&"font_color", color if not is_base else DS.TEXT)
	h.add_child(v)
	if not is_base:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 5)
		bar.draw.connect(func() -> void:
			var track := get_theme_stylebox(&"track", &"AppSlider")
			bar.draw_style_box(track, Rect2(0, 0, bar.size.x, 5))
			var fill: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			fill.bg_color = color
			bar.draw_style_box(fill, Rect2(0, 0, maxf(bar.size.x * frac, 5.0), 5)))
		box.add_child(bar)
	return box


static func _fmt(v: float, unit: String) -> String:
	if unit == "%":
		return String.num(v, 1) + "%"
	return String.num(v, 1 if absf(v) < 10.0 else 0)
