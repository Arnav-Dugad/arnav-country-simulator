class_name FrontPage
extends VBoxContainer
## A newspaper front page for the year in review: a fictional paper named after
## your capital, a masthead with rules, the big headline written from your real
## numbers, a scene photo, a stats strip and two short stories (your biggest
## decision and the world's biggest story). Calm, cream-on-dark newsprint look.

const PAPERS := ["Evening Courier", "Morning Ledger", "Daily Bulletin", "Weekly Observer", "Evening Record"]
const INK := Color(0.96, 0.94, 0.88)


static func paper_name() -> String:
	var i := Game.player
	var cap := ""
	if i < World.map.capital_name.size():
		cap = str(World.map.capital_name[i])
	if cap == "":
		cap = World.map.names[i]
	return "The %s %s" % [cap, PAPERS[absi(hash(World.iso(i))) % PAPERS.size()]]


## The big headline from the year's numbers.
static func headline(r: Dictionary) -> String:
	var best := ""
	var worst := ""
	var best_v := 0.0
	var worst_v := 0.0
	for row in r.rows:
		var a := float(row.from)
		var b := float(row.to)
		var d := (b - a) / maxf(absf(a), 1.0) if row.kind == "money" else (b - a)
		var good := (d > 0.0) == bool(row.good_up)
		if good and absf(d) > best_v:
			best_v = absf(d)
			best = str(row.label)
		elif not good and absf(d) > worst_v:
			worst_v = absf(d)
			worst = str(row.label)
	var lines := {
		"GDP": ["ECONOMY SURGES AHEAD", "ECONOMY SHRINKS"],
		"Growth": ["GROWTH ROARS BACK", "GROWTH STALLS"],
		"Inflation": ["PRICES FINALLY COOL", "PRICES SOAR"],
		"Unemployment": ["JOBS BOOM", "JOB LOSSES MOUNT"],
		"Approval": ["LEADER RIDES HIGH", "LEADER UNDER FIRE"],
		"Debt": ["DEBT FALLS", "DEBT PILES UP"],
	}
	if str(r.title) == "A tough year" and worst != "":
		return str(lines.get(worst, ["", "A HARD YEAR"])[1])
	if best != "":
		return str(lines.get(best, ["A GOOD YEAR", ""])[0])
	return "A YEAR OF HOLDING STEADY"


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(10, 0)


func build(r: Dictionary) -> FrontPage:
	var year := int(r.year)
	# Masthead
	_rule(2.0)
	var mast := Label.new()
	mast.theme_type_variation = &"Title2"
	mast.text = paper_name().to_upper()
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mast.add_theme_color_override(&"font_color", INK)
	mast.add_theme_constant_override(&"outline_size", 0)
	add_child(mast)
	var dl := Label.new()
	dl.theme_type_variation = &"Caption"
	dl.text = "SPECIAL EDITION  ·  1 JANUARY %d" % (year + 1)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.add_theme_color_override(&"font_color", Color(INK, 0.6))
	add_child(dl)
	_rule(1.0)
	# Headline
	var h := Label.new()
	h.theme_type_variation = &"LargeTitle"
	h.text = headline(r)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_color_override(&"font_color", INK)
	add_child(h)
	var sub := Label.new()
	sub.theme_type_variation = &"BodySecondary"
	var who := str(Settings.leader_name).strip_edges()
	sub.text = "%s's %d: %s, says the %s's team" % [World.map.names[Game.player], year, str(r.title).to_lower(),
		Government.leader_title(Game.player).to_lower()] if who == "" else "%s's %d: %s, says %s %s" % [
		World.map.names[Game.player], year, str(r.title).to_lower(), Government.leader_title(Game.player), who]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	# Photo
	var scene := "celebration" if str(r.title) == "A strong year" else ("protest" if str(r.title) == "A tough year" else "parliament")
	if Photo.has_scene(scene):
		var ph := Photo.scene(scene, 118.0, true)
		ph.set(&"radius", 6.0)
		add_child(ph)
	# Numbers strip
	var strip := GridContainer.new()
	strip.columns = 3
	strip.custom_minimum_size = Vector2(10, 0)
	strip.add_theme_constant_override(&"h_separation", DS.S2)
	strip.add_theme_constant_override(&"v_separation", 4)
	add_child(strip)
	for row in r.rows:
		var a := float(row.from)
		var b := float(row.to)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override(&"separation", -2)
		strip.add_child(col)
		var k := Label.new()
		k.theme_type_variation = &"Overline"
		k.text = {"Unemployment": "JOBLESS"}.get(str(row.label), str(row.label).to_upper())
		k.clip_text = true
		k.custom_minimum_size = Vector2(10, 0)
		col.add_child(k)
		var v := Label.new()
		v.theme_type_variation = &"StatSmall"
		v.text = DS.money(b) if row.kind == "money" else DS.pct(b)
		var up := b > a
		var flat := absf(b - a) < (absf(a) * 0.005 if row.kind == "money" else 0.05)
		v.add_theme_color_override(&"font_color", DS.TEXT_2 if flat else (DS.GREEN if up == bool(row.good_up) else DS.RED))
		col.add_child(v)
	_rule(1.0)
	# Two short stories
	var stories := HBoxContainer.new()
	stories.add_theme_constant_override(&"separation", DS.S3)
	add_child(stories)
	var mine := ""
	for e in Game.event_log:
		if str(e.date).ends_with(str(year)) and not bool(e.get("cabinet", false)):
			mine = "%s: you %s." % [str(e.title), GameEvents.chose(str(e.choice))]
			break
	if mine == "":
		mine = "A quiet year at home: no big decisions made the front page."
	var world := ""
	for n in Game.news:
		if str(n.date).ends_with(str(year)):
			world = str(n.text) + "."
			break
	if world == "":
		world = "The rest of the world had a calm year."
	_story(stories, "AT HOME", mine)
	_story(stories, "THE WORLD", world)
	# The planet and its people: warming, your emissions, who's moving.
	var me := Game.me()
	var planet := "The world is %s °C warmer than before factories. Your emissions: %s since %d. %s." % [
		String.num(Climate.warming(), 2), Climate._pct(Climate.change(me)), Calendar.START_YEAR, Migration.describe(me)]
	_rule(1.0)
	var row := HBoxContainer.new()
	add_child(row)
	_story(row, "THE PLANET", planet)
	# History made this year (the biggest milestone).
	for m in Game.dip.get("story", []):
		if str(m.get("date", "")).ends_with(str(year)):
			_story(row, "HISTORY MADE", str(m.text) + ".")
			break
	return self


func _story(parent: Control, kicker: String, text: String) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override(&"separation", 2)
	parent.add_child(col)
	var k := Label.new()
	k.theme_type_variation = &"Overline"
	k.text = kicker
	k.add_theme_color_override(&"font_color", DS.GOLD)
	col.add_child(k)
	var t := Label.new()
	t.theme_type_variation = &"Footnote"
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(60, 0)
	t.add_theme_color_override(&"font_color", Color(INK, 0.85))
	col.add_child(t)


func _rule(w: float) -> void:
	var r := ColorRect.new()
	r.color = Color(INK, 0.55 if w > 1.5 else 0.3)
	r.custom_minimum_size = Vector2(0, w)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
