class_name DashboardPage
extends SheetPage
## State of the nation: every important number on one screen. Each tile shows
## the value, a 12-month sparkline, the change over the year and a colour that
## says good or bad; tap a tile to go where you can do something about it.

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "State of the nation"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


## [title, history key or "", value getter, formatter, higher is better?, page, section, icon]
func _specs() -> Array:
	var c := Game.me()
	return [
		["Economy", [
			["GDP", "gdp", c.gdp, func(v: float) -> String: return DS.money(v), true, "economy", "", "coins"],
			["Per person", "gdp_pc", c.gdp_per_capita(), func(v: float) -> String: return DS.money(v, 0), true, "economy", "", "wallet"],
			["Growth", "growth", c.growth, func(v: float) -> String: return DS.pct(v, 1), true, "economy", "", "trending-up"],
			["Jobless", "unemployment", c.unemployment, func(v: float) -> String: return DS.pct(v, 1), false, "economy", "", "users"],
			["Prices", "inflation", c.inflation, func(v: float) -> String: return DS.pct(v, 1), false, "economy", "Central bank", "flame"],
			["Debt", "debt_pct", c.debt_pct(), func(v: float) -> String: return DS.pct(v, 0), false, "budget", "", "piggy-bank"],
		]],
		["People", [
			["Approval", "approval", c.approval, func(v: float) -> String: return "%d%%" % roundi(v), true, "economy", "", "thumbs-up"],
			["Happiness", "happiness", c.happiness, func(v: float) -> String: return str(roundi(v)), true, "budget", "", "heart"],
			["Stability", "stability", c.stability, func(v: float) -> String: return str(roundi(v)), true, "laws", "", "shield"],
			["Life expectancy", "life", Outcomes.life(c), func(v: float) -> String: return "%s yrs" % String.num(v, 1), true, "build", "", "heart-pulse"],
			["Inequality", "gini", c.gini, func(v: float) -> String: return "Gini %d" % roundi(v), false, "economy", "Taxes", "scale"],
			["Crime", "crime", Crime.value() if Game.dip.has("crime") else 0.0, func(v: float) -> String: return str(roundi(v)), false, "laws", "Crime & justice", "siren"],
		]],
		["World & planet", [
			["Military", "military", c.military, func(v: float) -> String: return str(roundi(v)), true, "build", "", "shield-check"],
			["CO₂ per person", "co2", Climate.co2_pc(c), func(v: float) -> String: return "%s t" % String.num(v, 1), false, "diplomacy", "Climate", "leaf"],
			["Soft power", "", Tourism.soft_power(Game.player) if Game.dip.has("tour") else 0.0, func(v: float) -> String: return "#%d" % Tourism.rank() if Game.dip.has("tour") else "-", true, "tourism", "", "sparkles"],
			["Credit rating", "", c.rating_score(), func(_v: float) -> String: return c.rating(), true, "budget", "", "landmark"],
			["Stock market", "", float(Enterprise.st().index) if Game.dip.has("ent") else 100.0, func(v: float) -> String: return str(roundi(v)), true, "firms", "", "trending-up"],
			["Treasury", "treasury", c.treasury, func(v: float) -> String: return DS.money(v), true, "budget", "", "wallet"],
		]],
	]


func refresh() -> void:
	if Game.me() == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	var h := Advisor.health(Game.me())
	var hl := Label.new()
	hl.theme_type_variation = &"Title2"
	hl.text = "Your nation is %s" % str(Advisor.HEALTH_TEXT[h]).to_lower()
	hl.add_theme_color_override(&"font_color", [DS.RED, DS.ORANGE, DS.GREEN][h])
	_box.add_child(hl)
	note("Every important number in one place. Arrows compare with a year ago; tap any tile to act on it.", _box)
	for group in _specs():
		var head := Label.new()
		head.theme_type_variation = &"Overline"
		head.text = str(group[0]).to_upper()
		_box.add_child(head)
		var g := grid(_box, 2)
		for sp in group[1]:
			g.add_child(_tile(sp))


func _tile(sp: Array) -> Control:
	var key := str(sp[1])
	var val := float(sp[2])
	var fmt: Callable = sp[3]
	var up_good := bool(sp[4])
	var hist: PackedFloat32Array = Game.history.get(key, PackedFloat32Array()) if key != "" else PackedFloat32Array()
	var series := hist.slice(maxi(hist.size() - 13, 0))
	var ago := float(series[0]) if series.size() >= 2 else NAN
	var d := val - ago if not is_nan(ago) else 0.0
	var rel := d / maxf(absf(ago), 1.0) if not is_nan(ago) else 0.0
	var good := (d > 0.0) == up_good
	var flat := absf(rel) < 0.005 or is_nan(ago)
	var col := DS.TEXT_3 if flat else (DS.GREEN if good else DS.RED)
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = DS.icon(str(sp[7]))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(14, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = DS.TEXT_3
	top.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Caption"
	t.text = str(sp[0]).to_upper()
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(30, 0)
	top.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var val_l := Label.new()
	val_l.theme_type_variation = &"StatSmall"
	val_l.text = str(fmt.call(val))
	val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_l.clip_text = true
	val_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	val_l.custom_minimum_size = Vector2(30, 0)
	row.add_child(val_l)
	if not flat:
		var ar := Label.new()
		ar.theme_type_variation = &"Caption"
		ar.text = ("▲" if d > 0.0 else "▼")
		ar.add_theme_color_override(&"font_color", col)
		row.add_child(ar)
	# Sparkline.
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(0, 22)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts := series.duplicate()
	spark.draw.connect(func() -> void:
		if pts.size() < 2:
			spark.draw_line(Vector2(0, 11), Vector2(spark.size.x, 11), Color(1, 1, 1, 0.12), 1.0)
			return
		var lo := pts[0]
		var hi := pts[0]
		for x in pts:
			lo = minf(lo, x)
			hi = maxf(hi, x)
		var span := maxf(hi - lo, absf(hi) * 0.02 + 0.0001)
		var line := PackedVector2Array()
		for k in pts.size():
			line.append(Vector2(spark.size.x * k / float(pts.size() - 1), 20.0 - 18.0 * (pts[k] - lo) / span))
		spark.draw_polyline(line, Color(col, 0.9), 1.6, true)
		spark.draw_circle(line[line.size() - 1], 2.5, col))
	v.add_child(spark)
	var page := str(sp[5])
	var sec := str(sp[6])
	var st := {"p": Vector2.ZERO, "down": false}
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.p = e.global_position
				st.down = true
			elif st.down:
				st.down = false
				if e.global_position.distance_to(st.p) < 10.0:
					Haptics.tap()
					Finder.go(get_tree().current_scene, page, sec)
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.p) >= 10.0:
			st.down = false)
	return p
