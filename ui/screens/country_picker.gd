extends Control
## Country picker: live map preview (flies to and highlights the selection) with
## a glass bottom sheet holding search, region chips and the country list.

const NEXT := "res://ui/screens/game.tscn"
const GROUPS := ["All", "Africa", "Americas", "Asia", "Europe", "Oceania"]

var _map: MapView
var _sheet: BottomSheet
var _search: LineEdit
var _chips: Array[AppButton] = []
var _group := "All"
var _list: VBoxContainer
var _scroll: ScrollContainer
var _rows := {}               # map index -> ListRow
var _selected := -1
var _sel_name: Label
var _sel_flag: Flag
var _sel_meta: Label
var _lead: AppButton
var _empty: Label
var _sort: SegmentedControl


func _ready() -> void:
	add_child(OceanBackground.new())
	_map = MapView.new()
	_map.interactive = false
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_map)

	_sheet = BottomSheet.new()
	_sheet.allow_dismiss = false
	_sheet.stops = [BottomSheet.Snap.HALF, BottomSheet.Snap.FULL]
	_sheet.half_ratio = 0.6
	_sheet.dim_when_full = false
	add_child(_sheet)
	_build_header()
	_build_list()
	_build_footer()
	_sheet.snapped.connect(func(_s: int) -> void: _frame_map())
	resized.connect(_frame_map)

	_select(_default_country(), false)
	_reveal_selected.call_deferred()
	_sheet.open.call_deferred(BottomSheet.Snap.HALF)


func _build_header() -> void:
	var title := Label.new()
	title.text = "Choose your nation"
	title.theme_type_variation = &"Title"
	_sheet.header.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search %d countries" % World.playable.size()
	_search.right_icon = DS.icon("search")
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _apply_filter())
	_search.focus_entered.connect(func() -> void: _sheet.snap_to(BottomSheet.Snap.FULL))
	_sheet.header.add_child(_search)
	var chip_scroll := ScrollContainer.new()
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chip_scroll.custom_minimum_size = Vector2(0, 36)
	_sheet.header.add_child(chip_scroll)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override(&"separation", DS.S2)
	chip_scroll.add_child(chips)
	var chall := AppButton.make("Challenges", &"Chip", "crown")
	chall.pressed.connect(_show_challenges)
	chips.add_child(chall)
	var surprise := AppButton.make("Surprise me", &"Chip", "sparkles")
	surprise.pressed.connect(_surprise)
	chips.add_child(surprise)
	for g in GROUPS:
		var c := AppButton.make(g, &"ChipSelected" if g == _group else &"Chip")
		c.pressed.connect(_on_chip.bind(g))
		chips.add_child(c)
		_chips.append(c)
	_sort = SegmentedControl.new().setup(["A–Z", "Biggest", "Richest", "Hardest"], [], 0)
	_sort.plain = true
	_sort.fill = true
	_sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort.changed.connect(_apply_sort)
	_sheet.header.add_child(_sort)


func _build_list() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.body.add_child(scroll)
	_scroll = scroll
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	for i in World.playable:
		var s: Dictionary = World.stats[i]
		var diff := Economy.difficulty(s)
		var row := ListRow.new()
		row.setup(World.map.names[i],
			"%s  ·  %s people" % [World.group_of(i), DS.compact(s.get("population", 0.0))],
			DS.money(s.get("gdp", 0.0)),
			Economy.DIFFICULTY_LABELS[diff])
		row.trailing_sub_label.add_theme_color_override(&"font_color", [DS.GREEN, DS.TEXT_2, DS.ORANGE][diff])
		row.set_leading(Flag.new().show_country(i, 22.0))
		row.tapped.connect(_select.bind(i, true))
		_list.add_child(row)
		_rows[i] = row
	_empty = Label.new()
	_empty.text = "No countries match your search."
	_empty.theme_type_variation = &"Footnote"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	_list.add_child(_empty)


func _build_footer() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", DS.S3)
	_sheet.body.add_child(bar)
	_sel_flag = Flag.new()
	bar.add_child(_sel_flag)
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	_sel_name = Label.new()
	_sel_name.theme_type_variation = &"Headline"
	_sel_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_sel_name)
	_sel_meta = Label.new()
	_sel_meta.theme_type_variation = &"Caption"
	_sel_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_sel_meta)
	_lead = AppButton.make("Lead", &"PrimaryButton", "crown")
	_lead.custom_minimum_size = Vector2(130, 50)
	_lead.pressed.connect(_start)
	bar.add_child(_lead)


## Country from the device locale (e.g. "en_IN" -> India), else a sensible default.
func _default_country() -> int:
	var parts := OS.get_locale().split("_")
	if parts.size() > 1:
		var code := parts[1].substr(0, 2).to_upper()
		for i in World.playable:
			if World.map.iso2[i] == code:
				return i
	var fallback := World.index_of("USA")
	return fallback if World.is_playable(fallback) else World.playable[0]


func _select(i: int, from_tap: bool) -> void:
	if _selected >= 0 and _rows.has(_selected):
		_rows[_selected].selected = false
	_selected = i
	_rows[i].selected = true
	var s: Dictionary = World.stats[i]
	_sel_name.text = World.map.names_long[i]
	_sel_flag.show_country(i, 30.0)
	var pc := Economy.per_capita(s.get("gdp", 0.0), s.get("population", 1.0))
	_sel_meta.text = "GDP/person %s  ·  Debt %s of GDP" % [DS.money(pc, 0), DS.pct(s.get("debt_pct", 0.0), 0)]
	_lead.text = "Lead"
	_map.set_player(i)
	_frame_map()
	if from_tap:
		Haptics.select()


func _reveal_selected() -> void:
	await get_tree().create_timer(0.5).timeout  # after the sheet settles
	if _selected >= 0 and is_inside_tree():
		_scroll.ensure_control_visible(_rows[_selected])


func _frame_map() -> void:
	if _selected < 0 or _sheet == null:
		return
	# Frame the country in the space above the sheet.
	_map.frame_insets = Vector4(DS.S6, Screen.top + DS.S6, DS.S6, size.y - _sheet.top_for(_sheet.state) + DS.S4)
	_map.focus_country(_selected, 0.9)


func _on_chip(g: String) -> void:
	_group = g
	for c in _chips:
		c.theme_type_variation = &"ChipSelected" if c.text == g else &"Chip"
	_apply_filter()


func _apply_filter() -> void:
	var q := _search.text.strip_edges().to_lower()
	var shown := 0
	for i in _rows:
		var ok := _group == "All" or World.group_of(i) == _group
		if ok and q != "":
			ok = World.map.names[i].to_lower().contains(q) or World.map.names_long[i].to_lower().contains(q) \
				or World.map.iso3[i].to_lower() == q
		_rows[i].visible = ok
		shown += 1 if ok else 0
	_empty.visible = shown == 0
	_scroll.scroll_vertical = 0


## Re-orders the list: 0 A–Z, 1 biggest economy, 2 richest per person, 3 hardest.
func _apply_sort(mode: int) -> void:
	var idx: Array = _rows.keys()
	var key := func(i: int) -> float:
		var s: Dictionary = World.stats[i]
		match mode:
			1:
				return -float(s.get("gdp", 0.0))
			2:
				return -Economy.per_capita(s.get("gdp", 0.0), s.get("population", 1.0))
			3:
				return -float(Economy.difficulty(s)) * 1e9 - float(s.get("inflation", 0.0))
		return 0.0
	if mode == 0:
		idx.sort_custom(func(a: int, b: int) -> bool: return World.name_of(a).naturalnocasecmp_to(World.name_of(b)) < 0)
	else:
		idx.sort_custom(func(a: int, b: int) -> bool: return key.call(a) < key.call(b))
	for k in idx.size():
		_list.move_child(_rows[idx[k]], k)
	_list.move_child(_empty, _list.get_child_count() - 1)
	_scroll.scroll_vertical = 0
	Haptics.tap()


func _show_challenges() -> void:
	Haptics.tap()
	var m := ModalCard.new()
	add_child(m)
	m.header("crown", DS.GOLD, "Challenges", "A real country, one goal")
	m.body("Pick a challenge. You can keep governing after you win or run out of time.")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(size.y * 0.5, 420.0))
	m.content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for ch in Challenges.ALL:
		var i := World.index_of(str(ch.country))
		var row := ListRow.new().setup(str(ch.title), str(ch.desc))
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.set_leading(Flag.new().show_country(i, 22.0))
		row.tapped.connect(func() -> void:
			Haptics.success()
			Game.new_challenge(str(ch.id))
			m.dismiss()
			Router.goto(NEXT))
		list.add_child(row)
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _surprise() -> void:
	var visible_rows: Array = _rows.keys().filter(func(i: int) -> bool: return _rows[i].visible and i != _selected)
	if visible_rows.is_empty():
		return
	var i: int = visible_rows[randi() % visible_rows.size()]
	_select(i, true)
	await get_tree().process_frame
	_scroll.ensure_control_visible(_rows[i])


func _start() -> void:
	if _selected < 0:
		return
	Haptics.success()
	Game.new_game(_selected)
	Router.goto(NEXT)
