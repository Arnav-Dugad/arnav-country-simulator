class_name GoalsCard
extends PanelContainer
## Your three national goals with progress rings (see Goals).

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
	var head := HBoxContainer.new()
	_box.add_child(head)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "National goals"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var n := Goals.done_count()
	var cnt := Label.new()
	cnt.theme_type_variation = &"Subhead"
	cnt.text = "%d reached" % n if n > 0 else ""
	cnt.add_theme_color_override(&"font_color", DS.GOLD)
	head.add_child(cnt)
	for g in Goals.active():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		_box.add_child(row)
		var p := Goals.progress(g)
		var ring := Control.new()
		ring.custom_minimum_size = Vector2(38, 38)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_name := str(Goals.SPECS[g.id].icon)
		ring.draw.connect(func() -> void:
			var c := ring.size * 0.5
			ring.draw_arc(c, 16.0, 0.0, TAU, 48, Color(1, 1, 1, 0.1), 3.0, true)
			if p > 0.0:
				ring.draw_arc(c, 16.0, -PI / 2.0, -PI / 2.0 + TAU * p, 48, DS.GOLD if p >= 0.999 else DS.ACCENT_SOFT, 3.0, true)
			)
		row.add_child(ring)
		var ic := TextureRect.new()
		ic.texture = DS.icon(icon_name)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(10, 10)
		ic.size = Vector2(18, 18)
		ic.modulate = DS.TEXT_2
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", -1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var tl := Label.new()
		tl.theme_type_variation = &"Subhead"
		tl.text = Goals.title(g)
		col.add_child(tl)
		var dl := Label.new()
		dl.theme_type_variation = &"Caption"
		dl.text = Goals.describe(g)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(dl)
		var pl := Label.new()
		pl.theme_type_variation = &"StatSmall"
		pl.text = "%d%%" % roundi(p * 100.0)
		pl.add_theme_color_override(&"font_color", DS.ACCENT_SOFT)
		row.add_child(pl)
