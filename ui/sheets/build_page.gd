class_name BuildPage
extends SheetPage
## Construction projects (see Projects): what's being built, what you could
## build next, and what your country already has.

var _summary: Label
var _speed: Label
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0
var _tab := 0               # 0 build, 1 defence, 2 research, 3 programmes
var _tabs: SegmentedControl
var _prog_box: VBoxContainer
var _units: VBoxContainer
var _won_box: VBoxContainer
var _group := ""           # Build tab: "" = overview, else one category
var _banner: Control


func _init() -> void:
	super._init()
	title = "Build"


func _build() -> void:
	_banner = Illustration.banner("tech", "flask-conical", DS.PURPLE, 124.0)
	add_child(_banner)
	_tabs = SegmentedControl.new().setup(["Build", "Defence", "Research", "Projects"], [], 0)
	_tabs.plain = true
	_tabs.compact = false
	_tabs.fill = true
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.changed.connect(func(i: int) -> void:
		_tab = i
		_group = ""
		Haptics.select()
		refresh())
	add_child(_tabs)
	_units = VBoxContainer.new()
	_units.add_theme_constant_override(&"separation", DS.S4)
	add_child(_units)
	_prog_box = VBoxContainer.new()
	_prog_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_prog_box)
	_won_box = VBoxContainer.new()
	_won_box.add_theme_constant_override(&"separation", DS.S4)
	_prog_box.add_child(_won_box)
	_summary = Label.new()
	_summary.theme_type_variation = &"Subhead"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prog_box.add_child(_summary)
	_speed = note("", _prog_box)
	_filter = SegmentedControl.new().setup(["Can build", "Building", "Built"], [], 0)
	_filter.changed.connect(func(i: int) -> void:
		_mode = i
		refresh())
	_prog_box.add_child(_filter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S4)
	_prog_box.add_child(_list)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_prog_box.visible = _tab == 3
	_units.visible = _tab != 3
	_banner.visible = _tab >= 2
	if _banner is Photo and _tab >= 2:
		var key := "tech" if _tab == 2 else "construction"
		if Photo.has_scene(key):
			_banner.set(&"texture", load("res://assets/scenes/%s.webp" % key))
	if _tab == 2:
		_fill_research(c)
		return
	if _tab != 3:
		_fill_units(c)
		return
	_wonders()
	var building := Projects.count_building(c)
	var spend := Projects.spending_pct(c)
	_summary.text = ("%d %s under construction · %s a year" % [building, "project" if building == 1 else "projects",
		DS.money(c.gdp * spend / 100.0)]) if building > 0 else "Nothing under construction. Projects create jobs now and growth for decades."
	var sp := Projects.speed(c)
	var over := Projects.overrun(c)
	var bits: Array[String] = []
	bits.append("Crews work at %d%% speed (more Infrastructure budget = faster)" % roundi(sp * 100.0))
	if over > 0.05:
		bits.append("Corruption adds about %d%% to costs" % roundi(over * 100.0))
	_speed.text = ". ".join(bits) + "."
	for ch in _list.get_children():
		ch.queue_free()
	var shown := 0
	for g in Projects.GROUPS:
		var items := Projects.ALL.filter(func(p: Dictionary) -> bool:
			if p.group != g:
				return false
			if _mode == 0:
				return not c.projects.has(p.id)
			if _mode == 1:
				return Projects.is_building(c, p.id)
			return Projects.is_done(c, p.id))
		if items.is_empty():
			continue
		var box := section(g, _list)
		for p in items:
			box.add_child(_card(c, p))
			shown += 1
	if shown == 0:
		note(["Everything on offer is built or under way.", "Nothing is being built right now. Pick a project under Can build.",
			"Nothing finished yet."][_mode], _list)


func _card(c: CountryState, p: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(top)
	var done := Projects.is_done(c, p.id)
	var building := Projects.is_building(c, p.id)
	var why := Projects.blocked_reason(c, p) if not done and not building else ""
	top.add_child(ListRow.icon_tile(str(p.icon), DS.GREEN if done else (DS.ORANGE if building else (DS.TEXT_3 if why != "" else DS.ACCENT))))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = str(p.title)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.text = str(p.desc) if why == "" else why
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if why != "":
		d.add_theme_color_override(&"font_color", DS.TEXT_3)
	mid.add_child(d)
	if done:
		var st: Dictionary = c.projects[p.id]
		var badge := Label.new()
		badge.theme_type_variation = &"BadgeLabel"
		badge.text = "Since before you" if bool(st.get("start", false)) else ("Opened %d" % int(st.get("year", Game.year)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(badge)
	if building:
		var prog := Projects.progress(c, p.id)
		var left := int(ceil((float(p.months) - float(c.projects[p.id].progress)) / Projects.speed(c)))
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			var w := bar.size.x
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 1, w, 6))
			var fill: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			fill.bg_color = DS.ORANGE
			bar.draw_style_box(fill, Rect2(0, 1, maxf(w * prog, 6.0), 6)))
		v.add_child(bar)
		var cap := Label.new()
		cap.theme_type_variation = &"Caption"
		cap.text = "%d%% built · about %d %s to go" % [roundi(prog * 100.0), left, "month" if left == 1 else "months"]
		v.add_child(cap)
	if why != "":
		return v
	# What it does
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	v.add_child(chips)
	if not done and not building:
		chips.add_child(_chip("Costs %s" % DS.money(Projects.price(c, p)), DS.ORANGE))
		chips.add_child(_chip("%d months" % Projects.build_months(c, p), DS.TEXT_2))
	if not bool(c.projects.get(p.id, {}).get("start", false)):
		for k in p.fx:
			var val := float(p.fx[k])
			var good: bool = (val > 0.0) == bool(Laws.FX_GOOD_UP[k])
			chips.add_child(_chip("%s %s" % [Laws.FX_LABELS[k], _num(val)], DS.GREEN if good else DS.RED))
		if Climate.CUTS.has(p.id):
			chips.add_child(_chip("CO₂ −%d%%" % roundi(float(Climate.CUTS[p.id]) * 100.0), DS.GREEN))
		if float(p.upkeep) > 0.0:
			chips.add_child(_chip("Upkeep %s/yr" % DS.money(c.gdp * float(p.upkeep) / 100.0), DS.TEXT_2))
	if done:
		return v
	var b: AppButton
	if building:
		b = AppButton.make("Stop construction", &"GhostButton", "x")
		b.pressed.connect(_confirm_cancel.bind(p))
	else:
		b = AppButton.make("Build", &"PrimaryButton", "hammer")
		b.pressed.connect(_confirm_build.bind(p))
	v.add_child(b)
	return v


func _confirm_build(p: Dictionary) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(p.icon), DS.ACCENT, "New project", str(p.title))
	var price := Projects.price(c, p)
	var months := Projects.build_months(c, p)
	var per_month := price / maxf(float(months), 1.0)
	m.body("%s\n\nIt will cost about %s over %d months (%s a month), employing thousands while it's built. Once open it keeps paying off every year." % [
		str(p.desc), DS.money(price), months, DS.money(per_month)])
	if c.treasury < per_month * 3.0:
		var warn := m.body("Your treasury is low: this will be paid with new borrowing.")
		warn.add_theme_color_override(&"font_color", DS.ORANGE)
	m.choice("Start building", "", &"PrimaryButton", func() -> void:
		if Projects.start(c, p.id):
			Simulation.update_finances(c)
			var gs := get_tree().current_scene
			if gs and gs.has_method("learned"):
				gs.learned("build")
			Haptics.success()
			Audio.play("success", -6.0)
		m.dismiss()
		_mode = 1
		_filter.select(1, false)
		refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _confirm_cancel(p: Dictionary) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("construction", DS.RED, "Stop construction", str(p.title))
	m.body("The money already spent is lost and the workers are laid off.")
	m.choice("Stop it", "", &"DestructiveButton", func() -> void:
		Projects.cancel(c, p.id)
		Simulation.update_finances(c)
		Haptics.warning()
		m.dismiss()
		refresh())
	m.choice("Keep building", "", &"GhostButton", m.dismiss)


## +0.25, +0.5, +1.2 (no trailing zeros).
static func _num(v: float) -> String:
	var t := String.num(absf(v), 2)
	return ("+" if v >= 0.0 else "−") + t


func _chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ForecastChip"
	var lbl := Label.new()
	lbl.theme_type_variation = &"ChipValue"
	lbl.add_theme_color_override(&"font_color", color)
	lbl.text = text
	p.add_child(lbl)
	return p


# ------------------------------------------------------------ countable builds ---
## Category -> AI scene (assets/scenes) used for its tile and header.
const GROUP_SCENE := {"Transport": "transport", "Energy": "energy", "Health & care": "hospital", "Education": "school",
	"Housing & cities": "city", "Economy": "port", "Culture & sport": "stadium", "Defence": "defence"}
const GROUP_ICON := {"Transport": "route", "Energy": "zap", "Health & care": "heart-pulse", "Education": "graduation-cap",
	"Housing & cities": "building-2", "Economy": "factory", "Culture & sport": "trophy", "Defence": "shield"}
const GROUP_BLURB := {"Transport": "Roads, rail, ports and airports move people and goods.",
	"Energy": "Clean, cheap power keeps prices down and factories running.",
	"Health & care": "Hospitals and clinics: longer, healthier lives.",
	"Education": "Schools and universities: skills, jobs and research.",
	"Housing & cities": "Homes, water and parks: fairer, happier cities.",
	"Economy": "Industry and trade: jobs and growth.",
	"Culture & sport": "Stadiums, museums and arenas: national pride.",
	"Defence": "Forces you build add to military strength."}

static func _n(v: float) -> String:
	return DS.compact(roundf(v)).trim_suffix(".0").replace(".0K", "K").replace(".0M", "M")


static func _plural(title: String, n: int) -> String:
	var t := title.to_lower()
	if n == 1:
		return t
	if t.ends_with("y") and not t.ends_with("ay"):
		return t.left(t.length() - 1) + "ies"
	return t + ("es" if t.ends_with("s") or t.ends_with("ch") else "s")


func _clear_units() -> void:
	for ch in _units.get_children():
		ch.queue_free()


func _fill_units(c: CountryState) -> void:
	_clear_units()
	if _tab == 1:
		_fill_group(c, "Defence")
	elif _group != "":
		_fill_group(c, _group)
	else:
		_fill_overview(c)


## Tap handler that ignores drags (lists scroll under the finger).
func _on_tap(ctrl: Control, cb: Callable) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := {"p": Vector2.ZERO, "down": false}
	ctrl.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.p = e.global_position
				st.down = true
			elif st.down:
				st.down = false
				if e.global_position.distance_to(st.p) < 10.0:
					Haptics.tap()
					cb.call()
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.p) >= 10.0:
			st.down = false)


func _go_group(g: String) -> void:
	_group = g
	Haptics.select()
	refresh()
	var p := get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p is ScrollContainer:
		(p as ScrollContainer).scroll_vertical = 0


static func _cov_color(cov: float) -> Color:
	return DS.GREEN if cov >= 0.8 else (DS.ACCENT if cov >= 0.5 else (DS.ORANGE if cov >= 0.25 else DS.RED))


func _caption(text: String, parent: Control, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Caption"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(40, 0)
	if color.a > 0.0:
		l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


# ---- overview ---------------------------------------------------------------
func _fill_overview(c: CountryState) -> void:
	var spend := Builds.building_pct(c) + Projects.building_pct(c)
	_units.add_child(photo_header("construction", "Build your nation",
		("Building now: %s a year" % DS.money(c.gdp * spend / 100.0)) if spend > 0.0 else "Choose how many of anything to build", 150.0))
	_dashboard(c)
	# Best value now.
	var best := Builds.best_value(c, 3)
	if not best.is_empty():
		var box := section("Best value now", _units)
		for id in best:
			box.add_child(_suggestion_row(c, str(id)))
	# Categories.
	var head := Label.new()
	head.theme_type_variation = &"Overline"
	head.text = "CATEGORIES"
	_units.add_child(head)
	var g := grid(_units, 2)
	for grp in Builds.GROUPS:
		g.add_child(_group_tile(c, str(grp)))
	_queue_section(c)


func _dashboard(c: CountryState) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	_units.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S2)
	card.add_child(v)
	# Builders' capacity.
	var ld := Builds.work_load(c)
	var col := DS.GREEN if ld < 0.8 else (DS.ORANGE if ld <= 1.0 else DS.RED)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(r1)
	r1.add_child(ListRow.icon_tile("hard-hat", col))
	var c1 := VBoxContainer.new()
	c1.add_theme_constant_override(&"separation", 0)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(c1)
	var t1 := Label.new()
	t1.theme_type_variation = &"Headline"
	t1.text = "Builders"
	c1.add_child(t1)
	_caption("Can take on %s of work a year" % DS.money(c.gdp * Builds.capacity_pct(c) / 100.0), c1)
	var p1 := Label.new()
	p1.theme_type_variation = &"StatSmall"
	p1.text = "%d%%" % roundi(ld * 100.0)
	p1.add_theme_color_override(&"font_color", col)
	r1.add_child(p1)
	v.add_child(meter(minf(ld, 1.0), 0.0, col))
	if ld > 1.0:
		_caption("Over capacity: everything builds %d%% slower and the boom adds %s to inflation." % [
			roundi((1.0 - Builds.pace(c)) * 100.0), DS.pct(Builds.overheat(c), 1)], v, DS.ORANGE)
	else:
		_caption("A bigger Infrastructure budget means more and faster crews.", v)
	# Condition.
	var cond := Builds.condition()
	var tgt := Builds.condition_target(c)
	var cc := DS.GREEN if cond >= 0.99 else (DS.ORANGE if cond >= 0.95 else DS.RED)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(r2)
	r2.add_child(ListRow.icon_tile("wrench", cc))
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override(&"separation", 0)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(c2)
	var t2 := Label.new()
	t2.theme_type_variation = &"Headline"
	t2.text = "Condition"
	c2.add_child(t2)
	_caption("Improving" if tgt > cond + 0.002 else ("Wearing out: raise the Infrastructure budget" if tgt < cond - 0.002 else "Steady"), c2,
		DS.ORANGE if tgt < cond - 0.002 else Color(0, 0, 0, 0))
	var p2 := Label.new()
	p2.theme_type_variation = &"StatSmall"
	p2.text = "%d%%" % roundi(cond * 100.0)
	p2.add_theme_color_override(&"font_color", cc)
	r2.add_child(p2)
	v.add_child(meter((cond - 0.8) / 0.25, (tgt - 0.8) / 0.25, cc))


func _suggestion_row(c: CountryState, id: String) -> Control:
	var s := Builds.spec(id)
	var q := maxi(1, mini(int(ceil(Builds.need(c, id) * 0.1)), Builds.max_more(c, id)))
	var have := float(Builds.count(c, id) + Builds.building(c, id))
	var d := Builds.coverage_of(c, id, have + q) - Builds.coverage_of(c, id, have)
	var parts: PackedStringArray = []
	for k in s.fx:
		if Laws.FX_LABELS.has(k):
			var val := float(s.fx[k]) * d * Economy.BUILD_FX_SCALE
			if absf(val) >= 0.01:
				parts.append("%s %+.2f" % [str(Laws.FX_LABELS[k]).to_lower(), val])
	var row := ListRow.new().setup(str(s.title), "%s for %s  ·  %s" % [_n(q), DS.money(Builds.unit_price(c, id) * q), ", ".join(parts)], "›")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
	row.set_leading(ListRow.icon_tile(str(s.icon), DS.GOLD))
	row.tapped.connect(_order.bind(id, q))
	return row


func _group_tile(c: CountryState, g: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var ph := Photo.scene(str(GROUP_SCENE[g]), 64.0, false)
	ph.set(&"radius", 12.0)
	v.add_child(ph)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = DS.icon(str(GROUP_ICON[g]))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(16, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = DS.RED if g == "Defence" else DS.ACCENT
	top.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Subhead"
	t.add_theme_color_override(&"font_color", DS.TEXT)
	t.text = g
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(30, 0)
	top.add_child(t)
	var cov := Builds.group_coverage(c, g)
	var q := Builds.group_building(c, g)
	var sub := ("Strength %d" % roundi(c.military)) if g == "Defence" else ("%d%% covered" % roundi(cov * 100.0))
	if q > 0:
		sub += "  ·  %s building" % _n(q)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.text = sub
	cap.clip_text = true
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.custom_minimum_size = Vector2(30, 0)
	v.add_child(cap)
	var m := c.military / 100.0 if g == "Defence" else cov
	v.add_child(meter(m, 0.0, DS.RED if g == "Defence" else _cov_color(cov), 4.0))
	_on_tap(p, func() -> void:
		if g == "Defence":
			_tab = 1
			_tabs.select(1, false)
			_go_group("")
		else:
			_go_group(g))
	return p


func _queue_section(c: CountryState) -> void:
	var q := Builds.queue(c)
	if q.is_empty():
		return
	var box := section("Under construction", _units)
	var shown := 0
	for it in q:
		if shown >= 6:
			note("And %d more batches." % (q.size() - shown), box)
			break
		box.add_child(_batch_row(c, it))
		shown += 1


func _batch_row(c: CountryState, it: Dictionary) -> Control:
	var id := str(it.id)
	var s := Builds.spec(id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(h)
	h.add_child(ListRow.icon_tile(str(s.icon), DS.ORANGE))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "%s %s" % [_n(int(it.n)), _plural(str(s.title), int(it.n))]
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(40, 0)
	mid.add_child(t)
	_caption("%d%% built  ·  %d mo left%s" % [roundi(float(it.frac) * 100.0), int(it.months), "  ·  rushed" if bool(it.rush) else ""], mid)
	if not bool(it.rush):
		var cost := Builds.rush_cost(c, id, int(it.k))
		var b := AppButton.make("Rush", &"Chip", "zap")
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_confirm_rush.bind(id, int(it.k), cost))
		h.add_child(b)
	v.add_child(meter(float(it.frac), 0.0, DS.GOLD if bool(it.rush) else DS.ORANGE, 4.0))
	return v


func _confirm_rush(id: String, k: int, cost: float) -> void:
	var c := Game.me()
	var s := Builds.spec(id)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("zap", DS.GOLD, "Rush order", str(s.title))
	m.body("Double shifts and extra crews finish this batch %s as fast. It costs %s more, paid now." % [
		"twice" if is_equal_approx(Economy.BUILD_RUSH_SPEED, 2.0) else "%.1f times" % Economy.BUILD_RUSH_SPEED, DS.money(cost)])
	if c.treasury < cost:
		var w := m.body("Your treasury is short: the rest will be borrowed.")
		w.add_theme_color_override(&"font_color", DS.ORANGE)
	m.choice("Rush it", DS.money(cost), &"PrimaryButton", func() -> void:
		if Builds.rush(c, id, k):
			Simulation.update_finances(c)
			Haptics.success()
			Audio.play("success", -8.0)
		m.dismiss()
		refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


# ---- one category -----------------------------------------------------------
func _fill_group(c: CountryState, g: String) -> void:
	if g != "Defence":
		var back := AppButton.make("All categories", &"Chip", "chevron-left")
		back.pressed.connect(_go_group.bind(""))
		var bar := HBoxContainer.new()       # in a VBox the chip would clip its text
		bar.add_child(back)
		_units.add_child(bar)
	var sub := ""
	if g == "Defence":
		sub = "Military strength %d / 100. Your Military budget keeps forces ready." % roundi(c.military)
	else:
		sub = "%d%% covered on average  ·  %s" % [roundi(Builds.group_coverage(c, g) * 100.0), str(GROUP_BLURB[g])]
	_units.add_child(photo_header(str(GROUP_SCENE[g]), g, sub, 140.0))
	if g == "Energy":
		_energy_card(c)
	var open: Array = []
	var locked: Array = []
	for id in Builds.ids_in(g):
		if Builds.available(c, str(id)) == "":
			open.append(id)
		else:
			locked.append(id)
	var box := section("", _units)
	for i in open.size():
		box.add_child(_unit_card(c, str(open[i])))
		if i < open.size() - 1:
			var sep := HSeparator.new()
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(sep)
	if not locked.is_empty():
		var lb := section("Not yet available", _units)
		for id in locked:
			var s := Builds.spec(str(id))
			var row := ListRow.new().setup(str(s.title), Builds.available(c, str(id)))
			row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			row.set_leading(ListRow.icon_tile("lock", DS.TEXT_3))
			lb.add_child(row)


func _unit_card(c: CountryState, id: String) -> Control:
	var s := Builds.spec(id)
	var n := Builds.count(c, id)
	var q := Builds.building(c, id)
	var cov := Builds.coverage_of(c, id, float(n))
	var cov2 := Builds.coverage_of(c, id, float(n + q))
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", DS.S3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var tint := DS.ORANGE if q > 0 else (DS.RED if str(s.group) == "Defence" else _cov_color(cov))
	h.add_child(ListRow.icon_tile(str(s.icon), tint))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mid)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = str(s.title)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(40, 0)
	mid.add_child(t)
	var line := "%s built" % _n(n)
	if q > 0:
		line += "  ·  +%s building" % _n(q)
	line += "  ·  %s each" % DS.money(Builds.unit_price(c, id), 0)
	var cap := _caption(line, mid)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	cap.clip_text = true
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	var pct := Label.new()
	pct.theme_type_variation = &"StatSmall"
	pct.text = "%d%%" % roundi(cov * 100.0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pct)
	var pc := Label.new()
	pc.theme_type_variation = &"Caption"
	pc.text = "of need"
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(pc)
	v.add_child(meter(cov, cov2, tint, 4.0))
	_on_tap(v, _order.bind(id, 0))
	return v


# ---- order sheet -------------------------------------------------------------
## Coverage curve: diminishing returns made visible. Dots at what you have and
## where this order takes you; the shaded slice is what you gain.
func _curve(c: CountryState, id: String, have: float, st: Dictionary) -> Control:
	var cv := Control.new()
	cv.custom_minimum_size = Vector2(0, 92)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := get_theme_font(&"font", &"Caption")
	cv.draw.connect(func() -> void:
		var w := cv.size.x
		var h := cv.size.y - 16.0
		var need := Builds.need(c, id)
		var xmax := need * 3.0
		var k := float(st.v)
		var pts := PackedVector2Array()
		for i in 49:
			var x := xmax * i / 48.0
			pts.append(Vector2(w * i / 48.0, h - h * (1.0 - exp(-x / need))))
		# 100 % line
		cv.draw_dashed_line(Vector2(0, 2), Vector2(w, 2), DS.TEXT_3 * Color(1, 1, 1, 0.5), 1.0, 4.0)
		var x0 := w * clampf(have / xmax, 0.0, 1.0)
		var x1 := w * clampf((have + k) / xmax, 0.0, 1.0)
		var y0 := h - h * Builds.coverage_of(c, id, have)
		var y1 := h - h * Builds.coverage_of(c, id, have + k)
		# gain slice
		var poly := PackedVector2Array([Vector2(x0, h), Vector2(x0, y0)])
		for p in pts:
			if p.x > x0 and p.x < x1:
				poly.append(p)
		poly.append(Vector2(x1, y1))
		poly.append(Vector2(x1, h))
		if x1 - x0 > 1.0 and poly.size() >= 3:
			cv.draw_colored_polygon(poly, Color(DS.GREEN, 0.22))
		cv.draw_polyline(pts, Color(DS.TEXT_2, 0.8), 2.0, true)
		cv.draw_line(Vector2(0, h), Vector2(w, h), Color(1, 1, 1, 0.12), 1.0)
		cv.draw_circle(Vector2(x0, y0), 4.5, DS.TEXT)
		cv.draw_circle(Vector2(x1, y1), 5.5, DS.GREEN)
		cv.draw_string(font, Vector2(0, cv.size.y - 2), "Coverage grows fast at first, then levels off", HORIZONTAL_ALIGNMENT_LEFT, w, 11, DS.TEXT_3))
	return cv


func _order(id: String, preset: int = 0) -> void:
	var c := Game.me()
	var s := Builds.spec(id)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(s.icon), DS.RED if str(s.group) == "Defence" else DS.ORANGE, str(s.group), str(s.title))
	var n := Builds.count(c, id)
	var price := Builds.unit_price(c, id)
	var months := Builds.months(c, id)
	m.body("You have %s (%d%% of what %s needs). Each %s costs %s and takes about %d months." % [
		_n(n), roundi(Builds.coverage_of(c, id, float(n)) * 100.0), World.the_name(c.idx),
		str(s.unit), DS.money(price, 0), int(ceil(float(months) / Builds.pace(c)))])
	var most := Builds.max_more(c, id)
	var info := Label.new()
	info.theme_type_variation = &"Footnote"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(60, 0)
	var cap_l := Label.new()
	cap_l.theme_type_variation = &"Caption"
	cap_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_l.custom_minimum_size = Vector2(60, 0)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	var start_q := preset if preset > 0 else int(ceil(Builds.need(c, id) * 0.1))
	var qty := {"v": clampi(start_q, 1, maxi(most, 1))}
	var ui := {"confirm": null, "curve": null}
	var have := n + Builds.building(c, id)
	var load0 := Builds.work_load(c)
	var cap_pct := Builds.capacity_pct(c)
	var update := func() -> void:
		var k := int(qty.v)
		var total := price * k
		var cov0 := Builds.coverage_of(c, id, float(have))
		var cov1 := Builds.coverage_of(c, id, float(have + k))
		var per_year := total / float(maxi(int(s.months), 1)) * 12.0 / c.gdp * 100.0
		info.text = "%s × %s = %s (%s of GDP a year while it's built). Coverage %d%% → %d%%. Upkeep afterwards: %s a year." % [
			_n(k), DS.money(price, 0), DS.money(total), DS.pct(per_year, 2), roundi(cov0 * 100.0), roundi(cov1 * 100.0),
			DS.money(total * float(s.upkeep), 0)]
		var load1 := load0 + per_year / maxf(cap_pct, 0.1)
		cap_l.text = "Builders %d%% → %d%% busy%s" % [roundi(load0 * 100.0), roundi(load1 * 100.0),
			("  ·  over capacity: all work slows and prices rise" if load1 > 1.0 else "")]
		cap_l.add_theme_color_override(&"font_color", DS.ORANGE if load1 > 1.0 else DS.TEXT_3)
		for ch in chips.get_children():
			ch.queue_free()
		var d := cov1 - cov0
		for key in s.fx:
			if key == "relations_soft":
				continue
			var val := float(s.fx[key]) * d * Economy.BUILD_FX_SCALE
			if absf(val) >= 0.01:
				var good: bool = (val > 0.0) == bool(Laws.FX_GOOD_UP.get(key, true))
				chips.add_child(_chip("%s %+.2f" % [Laws.FX_LABELS.get(key, key), val], DS.GREEN if good else DS.RED))
		if s.has("mil"):
			chips.add_child(_chip("Military %+.1f" % (float(s.mil) * d), DS.GREEN))
		if s.has("life"):
			chips.add_child(_chip("Life expectancy %+.2f yrs" % (float(s.life) * d * Economy.BUILD_FX_SCALE), DS.GREEN))
		if s.has("co2") and float(s.co2) > 0.0:
			chips.add_child(_chip("CO₂ −%s%%" % String.num(float(s.co2) * d * 100.0, 1), DS.GREEN))
		var cvc: Control = ui.curve
		if is_instance_valid(cvc):
			cvc.queue_redraw()
		var cb: Control = ui.confirm
		if is_instance_valid(cb):
			for b in cb.find_children("*", "Button", true, false):
				(b as Button).text = "Build %s" % _n(k)
				break
	if most <= 0:
		m.body("You already have all the %s your country could use." % _plural(str(s.title), 2))
	else:
		ui.curve = _curve(c, id, float(have), qty)
		m.content.add_child(ui.curve)
		var slider := AppSlider.new().setup("How many", 1, maxf(most, 1), 1, float(qty.v))
		slider.formatter = func(v: float) -> String: return _n(v)
		slider.value_changed.connect(func(v: float) -> void:
			qty.v = maxi(1, roundi(v))
			update.call())
		m.content.add_child(slider)
		var presets := HBoxContainer.new()
		presets.add_theme_constant_override(&"separation", DS.S2)
		m.content.add_child(presets)
		for p in [1, 10, 100, 1000]:
			if p > most:
				continue
			var b := AppButton.make(_n(p), &"Chip")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void:
				qty.v = p
				slider.set_value(float(p), false)
				update.call())
			presets.add_child(b)
		var full := mini(most, int(ceil(-Builds.need(c, id) * log(0.1))) - have)
		if full > 1:
			var fb := AppButton.make("To 90%", &"Chip")
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fb.pressed.connect(func() -> void:
				qty.v = full
				slider.set_value(float(full), false)
				update.call())
			presets.add_child(fb)
		m.content.add_child(info)
		m.content.add_child(cap_l)
		m.content.add_child(chips)
		ui.confirm = m.choice("Build", "", &"PrimaryButton", func() -> void:
			if Builds.order(c, id, int(qty.v)):
				Haptics.success()
				Audio.play("success", -8.0)
				Simulation.update_finances(c)
				var gs := get_tree().current_scene
				if gs and gs.has_method("learned"):
					gs.learned("build")
			m.dismiss()
			refresh())
		update.call()
	# Under construction (rush or stop), and demolition.
	var bt: Array = c.builds.get(id, {}).get("batches", [])
	for k in bt.size():
		var bd: Dictionary = bt[k]
		if not bool(bd.get("rush", false)):
			var rc := Builds.rush_cost(c, id, k)
			m.choice("Rush %s (%d mo left)" % [_n(float(bd.n)), Builds.batch_months(c, bd)],
				"Twice as fast for %s more" % DS.money(rc), &"GhostButton", func() -> void:
					m.dismiss()
					_confirm_rush(id, k, rc))
		m.choice("Stop building %s" % _n(float(bd.n)),
			"Money already spent is lost", &"GhostButton", func() -> void:
				Builds.cancel(c, id, k)
				Haptics.tap()
				Simulation.update_finances(c)
				m.dismiss()
				refresh())
	if n > 0:
		m.choice("Demolish some", "Saves upkeep; you lose their benefits", &"GhostButton", func() -> void:
			m.dismiss()
			_demolish(id))
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _demolish(id: String) -> void:
	var c := Game.me()
	var s := Builds.spec(id)
	var n := Builds.count(c, id)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("x", DS.RED, "Demolish", str(s.title))
	var qty := {"v": maxi(1, n / 10)}
	var slider := AppSlider.new().setup("How many", 1, maxf(n, 1), 1, float(qty.v))
	slider.formatter = func(v: float) -> String: return _n(v)
	slider.value_changed.connect(func(v: float) -> void: qty.v = maxi(1, roundi(v)))
	m.content.add_child(slider)
	m.body("Coverage drops and the benefits go with it. Only upkeep for units built since you took office is saved.")
	m.choice("Demolish", "", &"DestructiveButton", func() -> void:
		Builds.demolish(c, id, int(qty.v))
		Haptics.warning()
		Simulation.update_finances(c)
		m.dismiss()
		refresh())
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------------ research ---
func _fill_research(c: CountryState) -> void:
	for ch in _units.get_children():
		ch.queue_free()
	var rp := Tech.income(c)
	var head := PanelContainer.new()
	head.theme_type_variation = &"GroupPanel"
	_units.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override(&"separation", DS.S2)
	head.add_child(hv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	hv.add_child(row)
	row.add_child(ListRow.icon_tile("flask-conical", DS.PURPLE))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	var cur := str(Tech.st().current)
	t.text = str(Tech.ALL[cur].title) if cur != "" else "Choose what to research"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(40, 0)
	col.add_child(t)
	var sub := Label.new()
	sub.theme_type_variation = &"Caption"
	sub.text = ("About %d months to go  ·  %s research points a month" % [Tech.months_left(cur), String.num(rp, 1)]) if cur != "" \
		else "%s research points a month. Tap any technology below." % String.num(rp, 1)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(40, 0)
	col.add_child(sub)
	if cur != "":
		var frac := float(Tech.st().progress) / float(Tech.ALL[cur].cost)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, bar.size.x, 6))
			var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			f.bg_color = DS.PURPLE
			bar.draw_style_box(f, Rect2(0, 0, maxf(bar.size.x * frac, 6.0), 6)))
		hv.add_child(bar)
	var why := Label.new()
	why.theme_type_variation = &"Caption"
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(40, 0)
	var parts: PackedStringArray = []
	for term in Tech.income_terms(c):
		if float(term[1]) >= 0.05:
			parts.append("%s %s" % [str(term[0]).to_lower(), String.num(float(term[1]), 1)])
	why.text = "From " + ", ".join(parts) + ". Raise the Research budget or build universities and labs for more."
	hv.add_child(why)
	_space_outposts()
	# Space race standings.
	var firsts: Dictionary = Tech.st().firsts
	if not firsts.is_empty():
		var sr := section("Space race", _units)
		for id in Tech.ALL:
			if firsts.has(id):
				var i := World.index_of(str(firsts[id]))
				var r := ListRow.new().setup(str(Tech.ALL[id].title), "First: %s" % World.map.names[i])
				r.set_leading(ListRow.icon_tile(str(Tech.ALL[id].icon), DS.GOLD if i == Game.player else DS.TEXT_3))
				sr.add_child(r)
	for br in Tech.BRANCHES:
		var box := section(br, _units)
		for id in Tech.ALL:
			if str(Tech.ALL[id].branch) == br:
				box.add_child(_tech_row(str(id)))


func _tech_row(id: String) -> Control:
	var tt: Dictionary = Tech.ALL[id]
	var done := Tech.has(id)
	var can := Tech.can_research(id)
	var cur := str(Tech.st().current) == id
	var sub := str(tt.desc)
	if done:
		sub = "Researched  ·  " + sub
	elif cur:
		sub = "Researching  ·  about %d months" % Tech.months_left(id)
	elif not can:
		var need: PackedStringArray = []
		for r in tt.req:
			if not Tech.has(str(r)):
				need.append(str(Tech.ALL[str(r)].title))
		sub = "Needs " + " and ".join(need)
	else:
		sub = "%d points (about %d months)  ·  %s" % [int(tt.cost), Tech.months_left(id), sub]
	if tt.has("unlock") and not done:
		sub += "  ·  unlocks a new build"
	var row := ListRow.new().setup(str(tt.title), sub, "›" if can and not cur else "")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var tint := DS.GREEN if done else (DS.PURPLE if cur else (DS.ACCENT if can else DS.TEXT_3))
	row.set_leading(ListRow.icon_tile(str(tt.icon), tint))
	if can and not cur:
		row.tapped.connect(func() -> void:
			Tech.choose(id)
			Haptics.select()
			refresh())
	return row


# ------------------------------------------------------- energy & resources ---
func _energy_card(c: CountryState) -> void:
	# The grid: demand vs supply.
	var box := section("Power grid", _units)
	var dm := Energy.demand()
	var sp := Energy.supply()
	var use := dm / maxf(sp + Economy.EN_MARGIN, 0.01)
	var short := Energy.shortage()
	var col := DS.GREEN if use < 0.9 else (DS.ORANGE if short <= 0.0 else DS.RED)
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(r)
	r.add_child(ListRow.icon_tile("zap-off" if short > 0.0 else "zap", col))
	var cc := VBoxContainer.new()
	cc.add_theme_constant_override(&"separation", 0)
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(cc)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Rolling blackouts" if short > 0.0 else ("Running tight" if use >= 0.9 else "Enough power")
	cc.add_child(t)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	cap.text = "Demand %+d%% since you took office, supply %+d%%" % [roundi((dm - 1.0) * 100.0), roundi((sp - 1.0) * 100.0)]
	cc.add_child(cap)
	var v := Label.new()
	v.theme_type_variation = &"StatSmall"
	v.text = "%d%%" % roundi(use * 100.0)
	v.add_theme_color_override(&"font_color", col)
	r.add_child(v)
	box.add_child(meter(minf(use, 1.0), 0.0, col, 4.0))
	note("A growing economy needs more electricity. Build power plants, solar and wind farms, dams or grid lines below to stay ahead." if short <= 0.0
		else "Factories and homes are losing power. Every energy build below adds supply.", box)
	# Natural resources.
	var res: Dictionary = Energy.st().res
	var rb := section("Natural resources", _units)
	if res.is_empty():
		note("Your country has no big oil, gas, coal or mineral reserves. Exploration might find some.", rb)
	for id in res:
		var info: Dictionary = Energy.RESOURCES[id]
		var rr: Dictionary = res[id]
		var yrs := float(rr.years)
		var row := ListRow.new().setup(str(info.title), ("Exhausted" if yrs <= 0.0 else "About %d years left  ·  %s of GDP a year" % [
			roundi(yrs), DS.pct(Energy.rent(str(id)), 1)]))
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.set_leading(ListRow.icon_tile(str(info.icon), DS.TEXT_3 if yrs <= 0.0 else (DS.RED if yrs < 8.0 else DS.GOLD)))
		rb.add_child(row)
		if yrs <= 0.0:
			continue
		rb.add_child(meter(yrs / maxf(float(rr.years0), 1.0), 0.0, DS.RED if yrs < 8.0 else DS.GOLD, 3.0))
		var labels := PackedStringArray()
		for p in Energy.POLICIES:
			labels.append(str(Energy.POLICY_TITLE[p]))
		var seg := SegmentedControl.new().setup(labels, [], Energy.POLICIES.find(str(rr.policy)))
		seg.fill = true
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rid := str(id)
		seg.changed.connect(func(k: int) -> void:
			Energy.set_policy(rid, str(Energy.POLICIES[k]))
			Simulation.update_finances(Game.me())
			Haptics.select()
			refresh())
		rb.add_child(seg)
	note("Expanding earns more now but runs out sooner and adds emissions. When a reserve runs dry its income stops: save some in the wealth fund.", rb)
	var wait := Energy.explore_wait()
	var eb := AppButton.make("Explore  ·  %s" % DS.money(Energy.explore_cost()), &"", "search")
	eb.disabled = wait > 0
	eb.pressed.connect(func() -> void:
		var text := Energy.explore()
		Simulation.update_finances(Game.me())
		var gs := get_tree().current_scene
		if gs and gs.has_method("_notify"):
			gs._notify(text, "search", DS.GOLD if text.begins_with("Discovery") else DS.TEXT_2, false)
		if text.begins_with("Discovery"):
			Haptics.success()
		refresh())
	rb.add_child(eb)
	if wait > 0:
		note("Next survey possible in %d months." % wait, rb)


func _space_outposts() -> void:
	var box := section("Space colonies", _units)
	note("After the space race: permanent outposts that bring research, prestige and, in time, money. Each takes years to build and costs upkeep.", box)
	for id in Space.OUTPOSTS:
		var spec: Dictionary = Space.OUTPOSTS[id]
		var stt := Space.status(str(id))
		var why := Space.blocked(str(id))
		var sub := ""
		var col := DS.ACCENT
		match stt:
			"done":
				sub = "Open  ·  %d%% grown  ·  +%s research a month" % [roundi(Space.growth(str(id)) * 100.0), String.num(float(spec.rp) * (0.5 + 0.5 * Space.growth(str(id))), 1)]
				col = DS.GOLD
			"building":
				sub = "Building  ·  %d%%" % roundi(Space.progress(str(id)) * 100.0)
				col = DS.ORANGE
			_:
				sub = why if why != "" else "%s  ·  %d years  ·  %s" % [DS.money(Space.cost(str(id))), int(spec.months) / 12, str(spec.desc)]
				col = DS.TEXT_3 if why != "" else DS.ACCENT
		var row := ListRow.new().setup(str(spec.title), sub, "›" if stt == "none" and why == "" else "")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(spec.icon), col))
		if stt == "none" and why == "":
			var oid := str(id)
			row.tapped.connect(func() -> void:
				if Space.start(oid):
					Simulation.update_finances(Game.me())
					Haptics.success()
				refresh())
		box.add_child(row)
		if stt == "building":
			box.add_child(meter(Space.progress(str(id)), 0.0, DS.ORANGE, 3.0))


# ------------------------------------------------------------- world wonders ---
func _wonders() -> void:
	for ch in _won_box.get_children():
		ch.queue_free()
	var box := section("World wonders", _won_box)
	note("One-of-a-kind megaprojects. Only one nation can ever finish each, and the great powers are racing for them too.", box)
	var m := Wonders.mine()
	for id in Wonders.ALL:
		var w: Dictionary = Wonders.ALL[id]
		var own := Wonders.owner(str(id))
		var building := not m.is_empty() and str(m.id) == str(id)
		var rival: Dictionary = Wonders.ai().get(id, {})
		var why := Wonders.blocked(str(id))
		var sub := ""
		var col := DS.ACCENT
		if Wonders.have(str(id)):
			sub = "Yours  ·  completed"
			col = DS.GOLD
		elif own != "":
			sub = why
			col = DS.TEXT_3
		elif building:
			sub = "Building  ·  %d%%%s" % [roundi(Wonders.progress() * 100.0), ("  ·  %s is racing you" % World.map.names[World.index_of(str(rival.iso))]) if not rival.is_empty() else ""]
			col = DS.ORANGE
		else:
			sub = "%s  ·  %d years  ·  %s" % [DS.money(Wonders.cost(str(id))), int(w.months) / 12, str(w.desc)]
			if why != "":
				sub = (str(w.desc) + "  ·  after your current wonder") if why.begins_with("You're already") else why
			if not rival.is_empty():
				sub += "  ·  %s is building it" % World.map.names[World.index_of(str(rival.iso))]
			col = DS.TEXT_3 if why != "" else DS.ACCENT
		var row := ListRow.new().setup(str(w.title), sub, "›" if why == "" and own == "" and not building else "")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(w.icon), col))
		var wid := str(id)
		if why == "" and own == "" and not building:
			row.tapped.connect(func() -> void:
				var mm := ModalCard.new()
				get_tree().current_scene.add_child(mm)
				mm.header(str(w.icon), DS.GOLD, "World wonder", str(w.title))
				mm.body("%s It takes %d years and costs %s, spread over the build. If a rival finishes first, you get half your money back." % [
					str(w.desc), int(w.months) / 12, DS.money(Wonders.cost(wid))])
				mm.choice("Begin construction", "", &"PrimaryButton", func() -> void:
					if Wonders.start(wid):
						Simulation.update_finances(Game.me())
						Haptics.success()
					mm.dismiss()
					refresh())
				mm.choice("Not now", "", &"GhostButton", mm.dismiss))
		elif building:
			row.tapped.connect(func() -> void:
				var mm2 := ModalCard.new()
				get_tree().current_scene.add_child(mm2)
				mm2.header(str(w.icon), DS.ORANGE, "World wonder", str(w.title))
				mm2.body("%d%% complete." % roundi(Wonders.progress() * 100.0))
				mm2.choice("Abandon it", "Half of what you've spent comes back", &"DestructiveButton", func() -> void:
					Wonders.abandon()
					Simulation.update_finances(Game.me())
					mm2.dismiss()
					refresh())
				mm2.choice("Keep building", "", &"GhostButton", mm2.dismiss))
		box.add_child(row)
		if building:
			box.add_child(meter(Wonders.progress(), 0.0, DS.ORANGE, 4.0))
