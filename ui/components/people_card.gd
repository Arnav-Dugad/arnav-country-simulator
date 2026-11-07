class_name PeopleCard
extends PanelContainer
## "Your voters": support in each group (see Blocs) with its size and the
## biggest reason behind it. Bars animate to their new values.

var _box: VBoxContainer
var _bars := {}
var _vals := {}


func _ready() -> void:
	theme_type_variation = &"GroupPanel"
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S2)
	add_child(_box)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Your voters" if Government.has_elections(Game.player) else "Your people"
	_box.add_child(t)
	var sz := Blocs.sizes(Game.player)
	for g in Blocs.IDS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override(&"separation", 2)
		_box.add_child(row)
		var top := HBoxContainer.new()
		top.add_theme_constant_override(&"separation", DS.S2)
		row.add_child(top)
		var ic := TextureRect.new()
		ic.texture = DS.icon(str(Blocs.INFO[g].icon))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(18, 18)
		ic.modulate = Blocs.color(g)
		top.add_child(ic)
		var name := Label.new()
		name.theme_type_variation = &"Subhead"
		name.text = "%s  ·  %d%% of people" % [Blocs.INFO[g].title, roundi(float(sz[g]) * 100.0)]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.custom_minimum_size = Vector2(20, 0)
		top.add_child(name)
		var pct := Label.new()
		pct.theme_type_variation = &"StatSmall"
		pct.name = "Pct"
		top.add_child(pct)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := Blocs.color(g)
		bar.draw.connect(func() -> void:
			var w := bar.size.x
			var v := float(_vals.get(g, 0.0)) / 100.0
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, w, 6))
			var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			f.bg_color = col
			bar.draw_style_box(f, Rect2(0, 0, maxf(w * v, 6.0), 6))
			bar.draw_rect(Rect2(w * 0.5 - 0.5, -2, 1, 10), Color(1, 1, 1, 0.35)))
		row.add_child(bar)
		var why := Label.new()
		why.theme_type_variation = &"Caption"
		why.name = "Why"
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		why.custom_minimum_size = Vector2(20, 0)
		row.add_child(why)
		_bars[g] = [bar, pct, why]
	refresh()


func refresh() -> void:
	if _bars.is_empty() or not Game.has_game():
		return
	var c := Game.me()
	var sup := Blocs.support(c)
	for g in Blocs.IDS:
		var parts: Array = _bars[g]
		var target := float(sup[g])
		(parts[1] as Label).text = "%d%%" % roundi(target)
		(parts[1] as Label).add_theme_color_override(&"font_color", DS.GREEN if target >= 50.0 else (DS.ORANGE if target >= 35.0 else DS.RED))
		(parts[2] as Label).text = Blocs.top_reason(c, g)
		var from := float(_vals.get(g, target))
		var bar: Control = parts[0]
		if is_inside_tree() and absf(from - target) > 0.1 and not Settings.reduce_motion:
			var t := create_tween()
			DS.ease_out(t)
			t.tween_method(func(v: float) -> void:
				_vals[g] = v
				bar.queue_redraw(), from, target, 0.5)
		else:
			_vals[g] = target
			bar.queue_redraw()
