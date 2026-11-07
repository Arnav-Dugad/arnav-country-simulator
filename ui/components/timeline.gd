class_name Timeline
extends VBoxContainer
## A vertical timeline: a soft line connecting milestone dots (newest first).
## items: [{date, text, icon, tint (Color)}]

const DOT := 26.0


func build(items: Array) -> Timeline:
	add_theme_constant_override(&"separation", 0)
	for k in items.size():
		var it: Dictionary = items[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		add_child(row)
		var rail := Control.new()
		rail.custom_minimum_size = Vector2(DOT, 0)
		rail.size_flags_vertical = Control.SIZE_FILL
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var first := k == 0
		var last := k == items.size() - 1
		var tint: Color = it.get("tint", DS.ACCENT)
		rail.draw.connect(func() -> void:
			var cx := rail.size.x * 0.5
			var cy := DOT * 0.5 + 6.0
			if not first:
				rail.draw_line(Vector2(cx, 0), Vector2(cx, cy), Color(1, 1, 1, 0.14), 2.0, true)
			if not last:
				rail.draw_line(Vector2(cx, cy), Vector2(cx, rail.size.y), Color(1, 1, 1, 0.14), 2.0, true)
			rail.draw_circle(Vector2(cx, cy), DOT * 0.5, Color(tint, 0.22), true, -1.0, true)
			rail.draw_circle(Vector2(cx, cy), DOT * 0.5, Color(tint, 0.7), false, 1.5, true))
		row.add_child(rail)
		var ic := TextureRect.new()
		ic.texture = DS.icon(str(it.get("icon", "sparkles")))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(6, 12)
		ic.size = Vector2(14, 14)
		ic.modulate = tint.lightened(0.35)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var d := Label.new()
		d.theme_type_variation = &"Caption"
		d.text = str(it.get("date", ""))
		col.add_child(d)
		var t := Label.new()
		t.theme_type_variation = &"Body"
		t.text = str(it.get("text", ""))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(20, 0)
		col.add_child(t)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(0, DS.S3)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pad)
	return self
