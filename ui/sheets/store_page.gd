class_name StorePage
extends SheetPage
## DEMO store. Real prices are shown, but nothing is ever charged.

var _list: VBoxContainer
var _toast: Label


func _init() -> void:
	super._init()
	title = "Store"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	var banner := PanelContainer.new()
	banner.theme_type_variation = &"DemoBanner"
	add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	banner.add_child(row)
	row.add_child(ListRow.icon_tile("info", DS.ORANGE))
	var bl := Label.new()
	bl.theme_type_variation = &"Footnote"
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.text = "Demo store. Prices are examples; purchases are simulated and nothing is ever charged."
	row.add_child(bl)
	_toast = note("")
	_toast.visible = false
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S4)
	add_child(_list)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 0)
	add_child(footer)
	var restore := AppButton.make("Restore purchases", &"GhostButton", "refresh-cw")
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func() -> void: _flash("Purchases restored.", true))
	footer.add_child(restore)
	var reset := AppButton.make("Reset demo", &"GhostButton", "rotate-ccw")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		Store.reset_demo()
		_flash("Demo purchases cleared.", false))
	footer.add_child(reset)
	note("Every item is optional and priced in real money. No ads, no loot boxes, " +
		"no paid boosts, and nothing that changes the simulation's fairness.")
	Store.changed.connect(refresh)


func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	for sec in Store.sections():
		var box := section(sec, _list)
		for it in Store.CATALOG:
			if it.section == sec:
				box.add_child(_product_card(it))


func _product_card(it: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override(&"separation", DS.S2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(top)
	var tile := ListRow.icon_tile(str(it.icon), Store.tint(str(it.tint)))
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tile)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var title_row := HBoxContainer.new()
	mid.add_child(title_row)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = str(it.title)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(t)
	if it.has("badge"):
		var b := Label.new()
		b.theme_type_variation = &"BadgeLabel"
		b.text = str(it.badge)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(b)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.text = str(it.desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(d)
	if it.has("includes"):
		var inc := Label.new()
		inc.theme_type_variation = &"Caption"
		inc.text = "  ·  ".join(PackedStringArray(it.includes))
		inc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(inc)
	card.add_child(_action_button(it))
	return card


func _action_button(it: Dictionary) -> Control:
	var id := str(it.id)
	if it.has("theme") and Store.owns_product(id):
		var on: bool = Settings.map_theme == it.theme
		var b := AppButton.make("In use" if on else "Use this theme", &"Chip" if on else &"PrimaryButton",
			"check" if on else "")
		b.disabled = on
		b.pressed.connect(func() -> void:
			Settings.set_value("map_theme", str(it.theme))
			Haptics.success()
			refresh())
		return b
	if it.kind == "subscription" and Store.owns_product(id):
		var c := AppButton.make("Active · Cancel subscription", &"GhostButton")
		c.pressed.connect(func() -> void:
			Store.cancel_subscription()
			_flash("Subscription cancelled. (Demo)", false))
		return c
	if Store.owns_product(id):
		var o := AppButton.make("Owned" + ("  ·  arrives in a future update" if it.get("soon", false) else ""),
			&"Chip", "check")
		o.disabled = true
		return o
	var buy := AppButton.make(Store.price_text(id), &"", "")
	buy.pressed.connect(_confirm.bind(it))
	return buy


func _confirm(it: Dictionary) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(it.icon), Store.tint(str(it.tint)), "Confirm purchase", str(it.title))
	var price := Store.price_text(str(it.id))
	m.body("%s\n\n%s" % [str(it.desc), "Renews each %s until you cancel." % it.period if it.kind == "subscription" else "One-time purchase."])
	var demo := Label.new()
	demo.theme_type_variation = &"Footnote"
	demo.add_theme_color_override(&"font_color", DS.ORANGE)
	demo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo.text = "Demo store: you will not be charged."
	m.content.add_child(demo)
	m.choice("Buy for %s" % price, "", &"PrimaryButton", func() -> void:
		demo.text = "Processing…"
		var r: Dictionary = await Store.purchase(str(it.id))
		if r.ok:
			Haptics.success()
			m.dismiss()
			_flash("Thank you! %s is yours." % it.title, true))
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


func _flash(text: String, good: bool) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.add_theme_color_override(&"font_color", DS.GREEN if good else DS.TEXT_2)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
