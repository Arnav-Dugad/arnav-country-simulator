class_name LayersPopover
extends Control
## Map layers, like the layers button in a maps app: a small glass card above the
## Layers button with one tile per map mode and a legend for the active one.
## Tap outside to close.

signal mode_selected(mode: int)
signal globe_requested

const LEGEND := {
	MapModes.Mode.POLITICAL: ["Countries in calm colours. Yours glows gold.", "", ""],
	MapModes.Mode.WEALTH: ["Income per person", "Poorer", "Richer"],
	MapModes.Mode.RELATIONS: ["How each country feels about you", "Hostile", "Friendly"],
	MapModes.Mode.HAPPINESS: ["How happy people are", "Unhappy", "Happy"],
	MapModes.Mode.STABILITY: ["How stable each country is", "Unstable", "Stable"],
}

var _card: GlassPanel
var _tiles: Array[AppButton] = []
var _legend_title: Label
var _legend_bar: Control
var _lo: Label
var _hi: Label
var _mode := 0
var _anchor := Rect2()
var _globe_btn: AppButton
var _grid: GridContainer


func set_globe_state(on: bool) -> void:
	if _globe_btn:
		_globe_btn.text = "Flat map" if on else "Globe view"
		_globe_btn.icon_name = "map" if on else "earth"


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_card = GlassPanel.new()
	_card.theme_type_variation = &"GlassCard"
	_card.tint = DS.GLASS_TINT_STRONG
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	_card.add_child(v)
	var h := Label.new()
	h.theme_type_variation = &"Overline"
	h.text = "MAP"
	v.add_child(h)
	var g := GridContainer.new()
	_grid = g
	g.columns = 3
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	v.add_child(g)
	for m in MapModes.SHORT.size():
		var b := AppButton.make(MapModes.SHORT[m], &"LayerTile", MapModes.ICONS[m])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(92, 64)
		b.pressed.connect(func() -> void:
			select(m)
			mode_selected.emit(m))
		g.add_child(b)
		_tiles.append(b)
	_globe_btn = AppButton.make("Globe view", &"", "earth")
	var gb := _globe_btn
	gb.pressed.connect(func() -> void:
		close()
		globe_requested.emit())
	v.add_child(gb)
	_legend_title = Label.new()
	_legend_title.theme_type_variation = &"Footnote"
	_legend_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_legend_title)
	_legend_bar = Control.new()
	_legend_bar.custom_minimum_size = Vector2(0, 10)
	_legend_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_bar.draw.connect(_draw_legend)
	v.add_child(_legend_bar)
	var ends := HBoxContainer.new()
	v.add_child(ends)
	_lo = Label.new()
	_lo.theme_type_variation = &"Caption"
	_lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(_lo)
	_hi = Label.new()
	_hi.theme_type_variation = &"Caption"
	ends.add_child(_hi)
	select(0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		close()


func open(anchor: Rect2) -> void:
	_anchor = anchor
	_grid.columns = 5 if Screen.landscape else 3   # wide screens: one short row
	visible = true
	await get_tree().process_frame
	_card.size = Vector2.ZERO
	var s := _card.get_combined_minimum_size()
	_card.size = s
	# Fit above the button; shrink if the screen is too short (landscape).
	var room := anchor.position.y - DS.S2 - Screen.top - DS.S2
	var fit := clampf(room / maxf(s.y, 1.0), 0.6, 1.0)
	var x := clampf(anchor.end.x - s.x * fit, DS.S3, size.x - s.x * fit - DS.S3)
	_card.position = Vector2(x, anchor.position.y - s.y * fit - DS.S2)
	_card.pivot_offset = Vector2.ZERO
	set_meta(&"fit", fit)
	_card.scale = Vector2.ONE * 0.85 * fit
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	DS.spring(t)
	t.tween_property(_card, "scale", Vector2.ONE * float(get_meta(&"fit", 1.0)), Settings.dur(DS.DUR_SLOW))
	DS.ease_out(t)
	t.tween_property(_card, "modulate:a", 1.0, Settings.dur(DS.DUR_FAST))
	Haptics.tap()


func close() -> void:
	if not visible:
		return
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(_card, "scale", Vector2.ONE * 0.9, Settings.dur(DS.DUR_FAST))
	t.tween_property(_card, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.chain().tween_callback(func() -> void: visible = false)


func select(m: int) -> void:
	_mode = m
	for k in _tiles.size():
		_tiles[k].theme_type_variation = &"LayerTileSelected" if k == m else &"LayerTile"
	var info: Array = LEGEND[m]
	_legend_title.text = str(info[0])
	_lo.text = str(info[1])
	_hi.text = str(info[2])
	_legend_bar.visible = m != MapModes.Mode.POLITICAL
	_lo.get_parent().visible = _legend_bar.visible
	_legend_bar.queue_redraw()


func _draw_legend() -> void:
	var stops := MapModes.legend_stops(_mode)
	var w := _legend_bar.size.x
	var h := _legend_bar.size.y
	var n := 48
	for k in n:
		var t0 := float(k) / n
		_legend_bar.draw_rect(Rect2(w * t0, 0, w / n + 1.0, h), MapModes.ramp(stops, t0))
	# Your country's marker.
	if _mode != MapModes.Mode.RELATIONS and Game.has_game():
		var vals := Game.map_values(_mode)
		var v := vals[Game.player]
		if not is_nan(v):
			_legend_bar.draw_circle(Vector2(w * v, h * 0.5), 6.0, DS.GOLD, true, -1.0, true)
			_legend_bar.draw_circle(Vector2(w * v, h * 0.5), 6.0, Color(0, 0, 0, 0.5), false, 1.5, true)
