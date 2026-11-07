extends Control
## Developer screen that shows every design-system primitive over a busy
## background, to check glass blur, type scale and button states on device.


func _ready() -> void:
	add_child(OceanBackground.new())
	# Colourful shapes behind the glass so the blur is visible.
	var blobs := Control.new()
	blobs.set_anchors_preset(Control.PRESET_FULL_RECT)
	blobs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blobs.draw.connect(func() -> void:
		blobs.draw_circle(Vector2(90, 220), 90, DS.ACCENT, true, -1.0, true)
		blobs.draw_circle(Vector2(320, 330), 110, DS.PURPLE, true, -1.0, true)
		blobs.draw_circle(Vector2(140, 560), 80, DS.GREEN, true, -1.0, true)
		blobs.draw_circle(Vector2(300, 700), 90, DS.ORANGE, true, -1.0, true))
	add_child(blobs)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, DS.S4)
	margin.add_theme_constant_override("margin_top", DS.S8 + int(Screen.top))
	margin.add_theme_constant_override("margin_bottom", DS.S8 + int(Screen.bottom))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", DS.S4)
	margin.add_child(col)

	var panel := GlassPanel.new()
	col.add_child(panel)
	var inner := VBoxContainer.new()
	panel.add_child(inner)
	for pair in [["LargeTitle", "Large Title"], ["Title", "Title"], ["Title2", "Title 2"],
			["Headline", "Headline"], ["Body", "Body text reads clearly through glass."],
			["Subhead", "Subhead"], ["Footnote", "Footnote"], ["Caption", "CAPTION"],
			["StatValue", "$27.36T"]]:
		var l := Label.new()
		l.theme_type_variation = pair[0]
		l.text = pair[1]
		inner.add_child(l)

	var card := GlassPanel.new()
	card.theme_type_variation = &"GlassCard"
	col.add_child(card)
	var buttons := VBoxContainer.new()
	card.add_child(buttons)
	buttons.add_child(AppButton.make("Primary action", &"PrimaryButton", "check"))
	buttons.add_child(AppButton.make("Secondary", &"", "settings"))
	buttons.add_child(AppButton.make("Sanction", &"DestructiveButton", "ban"))
	buttons.add_child(AppButton.make("Ghost button", &"GhostButton"))
	var chips := HBoxContainer.new()
	buttons.add_child(chips)
	chips.add_child(AppButton.make("Political", &"ChipSelected"))
	chips.add_child(AppButton.make("GDP", &"Chip"))
	chips.add_child(AppButton.make("Happiness", &"Chip"))
	var field := LineEdit.new()
	field.placeholder_text = "Search countries"
	buttons.add_child(field)

	var bar := GlassPanel.new()
	bar.theme_type_variation = &"GlassBar"
	col.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	for ic in ["landmark", "wallet", "globe", "zap", "settings"]:
		var b := AppButton.make("", &"DockButton", ic)
		b.custom_minimum_size = Vector2(56, 48)
		row.add_child(b)
