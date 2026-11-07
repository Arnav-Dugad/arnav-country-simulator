extends Control
## Main game screen: full-screen world map with floating glass chrome.

var map: MapView
var modes: SegmentedControl
var info: GlassPanel
var _info_title: Label
var _info_sub: Label
var _mode := MapModes.Mode.POLITICAL


func _ready() -> void:
	add_child(OceanBackground.new())
	map = MapView.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.country_tapped.connect(_on_country_tapped)

	modes = SegmentedControl.new().setup(MapModes.SHORT, MapModes.ICONS, 0)
	add_child(modes)
	modes.changed.connect(_on_mode_changed)

	info = GlassPanel.new()
	info.theme_type_variation = &"GlassCard"
	info.visible = false
	add_child(info)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	info.add_child(v)
	_info_title = Label.new()
	_info_title.theme_type_variation = &"Title2"
	v.add_child(_info_title)
	_info_sub = Label.new()
	_info_sub.theme_type_variation = &"Subhead"
	v.add_child(_info_sub)

	Screen.insets_changed.connect(_layout)
	resized.connect(_layout)
	_layout.call_deferred()
	var start := Game.player if Game.player >= 0 else map.data.index_of("IND")
	map.set_player(start)
	map.focus_country.call_deferred(start, 0.01)


func _layout() -> void:
	var w := size.x
	modes.reset_size()
	modes.position = Vector2((w - modes.get_combined_minimum_size().x) * 0.5, Screen.top + DS.S3)
	info.size = Vector2(w - DS.S4 * 2, 0)
	info.position = Vector2(DS.S4, size.y - Screen.bottom - DS.S4 - info.get_combined_minimum_size().y)
	map.frame_insets = Vector4(DS.S4, Screen.top + 64, DS.S4, Screen.bottom + 140)


func _on_country_tapped(i: int) -> void:
	map.select(i)
	if i < 0:
		_hide_info()
		return
	Haptics.select()
	var md := map.data
	_info_title.text = md.names_long[i]
	var gdp := md.gdp_md[i] * 1e6
	_info_sub.text = "%s  ·  Pop. %s  ·  GDP %s" % [md.subregions[i], DS.compact(md.pop_est[i]), DS.money(gdp)]
	_show_info()


func _show_info() -> void:
	var was_visible := info.visible
	info.visible = true
	_layout()
	if was_visible:
		return
	var y := info.position.y
	info.modulate.a = 0.0
	info.position.y = y + 24
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(info, "modulate:a", 1.0, Settings.dur(DS.DUR))
	t.tween_property(info, "position:y", y, Settings.dur(DS.DUR))


func _hide_info() -> void:
	if not info.visible:
		return
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(info, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.tween_property(info, "position:y", info.position.y + 24, Settings.dur(DS.DUR_FAST))
	t.chain().tween_callback(func() -> void: info.visible = false)


func _on_mode_changed(m: int) -> void:
	_mode = m
	map.set_colors(_colors_for(m))


## Phase-2 placeholder values from Natural Earth estimates. Replaced by live
## simulation values (GameState) in phase 4.
func _colors_for(m: int) -> PackedColorArray:
	var md := map.data
	if m == MapModes.Mode.POLITICAL:
		return MapModes.political(md)
	var vals := PackedFloat32Array()
	vals.resize(md.count())
	for i in md.count():
		var pc := md.gdp_md[i] * 1e6 / maxf(md.pop_est[i], 1.0)
		var wealth := clampf((log(maxf(pc, 1.0)) / log(10.0) - 2.7) / 2.3, 0.0, 1.0)
		var h := float(absi(hash(md.iso3[i] + str(m))) % 1000) / 1000.0
		match m:
			MapModes.Mode.WEALTH:
				vals[i] = wealth if md.pop_est[i] > 0 else NAN
			MapModes.Mode.RELATIONS:
				vals[i] = h
			_:
				vals[i] = clampf(wealth * 0.6 + h * 0.4, 0.0, 1.0)
		if md.iso3[i] == "ATA":
			vals[i] = NAN
	return MapModes.data_colors(m, vals)
