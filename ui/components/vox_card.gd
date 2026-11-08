class_name VoxCard
extends PanelContainer
## "What people are saying": three short quotes from invented citizens about
## what matters most right now (see sim/vox_pop.gd).

var _list: VBoxContainer


func _init() -> void:
	theme_type_variation = &"GroupPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	add_child(v)
	var h := Label.new()
	h.theme_type_variation = &"Headline"
	h.text = "What people are saying"
	v.add_child(h)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(_list)


func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	for q in VoxPop.quotes(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		_list.add_child(row)
		var bar := ColorRect.new()
		bar.color = Color(DS.GREEN if bool(q.good) else DS.ORANGE, 0.8)
		bar.custom_minimum_size = Vector2(3, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var t := Label.new()
		t.theme_type_variation = &"Body"
		t.text = "“%s”" % str(q.text)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(60, 0)
		col.add_child(t)
		var w := Label.new()
		w.theme_type_variation = &"Caption"
		w.text = str(q.who)
		col.add_child(w)
