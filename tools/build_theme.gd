extends SceneTree
## Generates res://ui/theme/main_theme.tres from the tokens in ui/theme/tokens.gd.
## Run:  godot --headless --path . --script res://tools/build_theme.gd
## Never hand-edit main_theme.tres — change tokens or this file and re-run.

const OUT := "res://ui/theme/main_theme.tres"
const FONT_PATH := "res://assets/fonts/InterVariable.ttf"

var th := Theme.new()
var base_font: Font
var ts := TextServerManager.get_primary_interface()


func _init() -> void:
	base_font = load(FONT_PATH)
	th.default_font = _font(400, 14)
	th.default_font_size = DS.FS_BODY
	_labels()
	_buttons()
	_panels()
	_fields()
	_scroll()
	_misc()
	var err := ResourceSaver.save(th, OUT)
	print("build_theme: saved %s (err=%d)" % [OUT, err])
	quit(err)


## Font variation of Inter at a given weight / optical size / tracking.
func _font(weight: int, opsz: int, tracking: int = 0, tabular: bool = false) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base_font
	f.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("opsz"): opsz}
	f.spacing_glyph = tracking
	if tabular:
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
	return f


func _label_variant(name: StringName, font: Font, size: int, color: Color) -> void:
	th.set_type_variation(name, &"Label")
	th.set_font(&"font", name, font)
	th.set_font_size(&"font_size", name, size)
	th.set_color(&"font_color", name, color)


func _labels() -> void:
	th.set_color(&"font_color", &"Label", DS.TEXT)
	th.set_font(&"font", &"Label", _font(400, 14))
	th.set_font_size(&"font_size", &"Label", DS.FS_BODY)
	th.set_constant(&"line_spacing", &"Label", 2)
	# Type scale. Titles get tight tracking, as on iOS.
	_label_variant(&"LargeTitle", _font(700, 32, -1), DS.FS_LARGE_TITLE, DS.TEXT)
	_label_variant(&"Title", _font(700, 28, -1), DS.FS_TITLE, DS.TEXT)
	_label_variant(&"Title2", _font(650, 22, 0), DS.FS_TITLE_2, DS.TEXT)
	_label_variant(&"Headline", _font(600, 17), DS.FS_HEADLINE, DS.TEXT)
	_label_variant(&"Body", _font(400, 16), DS.FS_BODY, DS.TEXT)
	_label_variant(&"BodySecondary", _font(400, 16), DS.FS_BODY, DS.TEXT_2)
	_label_variant(&"Subhead", _font(500, 15), DS.FS_SUBHEAD, DS.TEXT_2)
	_label_variant(&"Footnote", _font(400, 13), DS.FS_FOOTNOTE, DS.TEXT_2)
	_label_variant(&"Caption", _font(500, 12), DS.FS_CAPTION, DS.TEXT_3)
	_label_variant(&"Overline", _font(600, 12, 1), DS.FS_CAPTION, DS.TEXT_3)
	_label_variant(&"StatValue", _font(650, 22, -1, true), DS.FS_TITLE_2, DS.TEXT)
	_label_variant(&"StatSmall", _font(600, 16, 0, true), DS.FS_SUBHEAD, DS.TEXT)
	_label_variant(&"Numeric", _font(500, 14, 0, true), DS.FS_FOOTNOTE, DS.TEXT)
	_label_variant(&"MapLabel", _font(600, 14, 1), 11, Color(1, 1, 1, 0.78))
	th.set_color(&"font_outline_color", &"MapLabel", Color(0.01, 0.03, 0.07, 0.75))
	th.set_constant(&"outline_size", &"MapLabel", 4)


func _box(bg: Color, radius: int, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.8
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _button_states(type: StringName, normal: Color, hover: Color, pressed: Color, radius: int,
		font: Font, size: int, color: Color, pad_h := 18, pad_v := 12) -> void:
	th.set_stylebox(&"normal", type, _box(normal, radius, pad_h, pad_v))
	th.set_stylebox(&"hover", type, _box(hover, radius, pad_h, pad_v))
	th.set_stylebox(&"pressed", type, _box(pressed, radius, pad_h, pad_v))
	th.set_stylebox(&"hover_pressed", type, _box(pressed, radius, pad_h, pad_v))
	var dis := normal
	dis.a *= 0.5
	th.set_stylebox(&"disabled", type, _box(dis, radius, pad_h, pad_v))
	th.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	th.set_font(&"font", type, font)
	th.set_font_size(&"font_size", type, size)
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
			&"font_hover_pressed_color", &"icon_normal_color", &"icon_hover_color",
			&"icon_pressed_color", &"icon_focus_color", &"icon_hover_pressed_color"]:
		th.set_color(c, type, color)
	var dc := color
	dc.a *= 0.4
	th.set_color(&"font_disabled_color", type, dc)
	th.set_color(&"icon_disabled_color", type, dc)
	th.set_constant(&"h_separation", type, 8)
	th.set_constant(&"icon_max_width", type, 20)


func _buttons() -> void:
	var f := _font(600, 17)
	# Default Button = secondary, translucent fill.
	_button_states(&"Button", DS.FILL_2, Color(1, 1, 1, 0.17), DS.FILL, DS.R_BUTTON, f, DS.FS_HEADLINE, DS.TEXT)
	for v in [&"PrimaryButton", &"DestructiveButton", &"GhostButton", &"IconButton", &"DockButton",
			&"Chip", &"ChipSelected", &"Segment", &"SegmentSelected", &"ListButton"]:
		th.set_type_variation(v, &"Button")
	var a := DS.ACCENT
	_button_states(&"PrimaryButton", a, a.lightened(0.08), a.darkened(0.12), DS.R_BUTTON, f, DS.FS_HEADLINE, DS.TEXT)
	var r := DS.RED
	_button_states(&"DestructiveButton", Color(r, 0.18), Color(r, 0.24), Color(r, 0.12), DS.R_BUTTON, f, DS.FS_HEADLINE, r)
	_button_states(&"GhostButton", Color(1, 1, 1, 0), DS.FILL_3, DS.FILL, DS.R_BUTTON, f, DS.FS_HEADLINE, DS.ACCENT_SOFT)
	_button_states(&"IconButton", Color(1, 1, 1, 0), DS.FILL_3, DS.FILL, DS.R_PILL, f, DS.FS_BODY, DS.TEXT, 10, 10)
	th.set_constant(&"icon_max_width", &"IconButton", 20)
	var df := _font(500, 12)
	_button_states(&"DockButton", Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.06), DS.R_BUTTON, df, 11, DS.TEXT_2, 6, 6)
	th.set_constant(&"icon_max_width", &"DockButton", 22)
	var cf := _font(600, 14)
	_button_states(&"Chip", DS.FILL, DS.FILL_2, DS.FILL_3, DS.R_PILL, cf, 14, DS.TEXT_2, 14, 7)
	_button_states(&"ChipSelected", Color(1, 1, 1, 0.92), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), DS.R_PILL, cf, 14, Color("0b1324"), 14, 7)
	_button_states(&"Segment", Color(1, 1, 1, 0), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.02), DS.R_PILL, cf, 13, DS.TEXT_2, 12, 7)
	_button_states(&"SegmentSelected", Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0), DS.R_PILL, cf, 13, DS.TEXT, 12, 7)
	# Compact segments for tight spaces (top-bar speed control).
	for v in [&"SegmentTight", &"SegmentTightSelected"]:
		th.set_type_variation(v, &"Button")
	_button_states(&"SegmentTight", Color(1, 1, 1, 0), Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.02), DS.R_PILL, cf, 13, DS.TEXT_2, 7, 7)
	_button_states(&"SegmentTightSelected", Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0), DS.R_PILL, cf, 13, DS.TEXT, 7, 7)
	var lf := _font(500, 16)
	_button_states(&"ListButton", Color(1, 1, 1, 0), DS.FILL_3, DS.FILL, DS.R_FIELD, lf, DS.FS_BODY, DS.TEXT, 14, 12)
	th.set_constant(&"align_to_largest_stylebox", &"ListButton", 0)


func _shadow_box(radius: int, pad: int, shadow: int, bg := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := _box(bg, radius, pad, pad)
	s.shadow_color = DS.SHADOW
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, shadow * 0.35)
	return s


func _panels() -> void:
	# Glass surfaces: the stylebox supplies the soft shadow + padding; GlassPanel's
	# shader draws the blurred, tinted body and the 15 % border on top of it.
	for v in [&"GlassPanel", &"GlassSheet", &"GlassBar", &"GlassCard", &"GlassPill"]:
		th.set_type_variation(v, &"PanelContainer")
	th.set_stylebox(&"panel", &"GlassPanel", _shadow_box(DS.R_PANEL, DS.S5, 24))
	th.set_stylebox(&"panel", &"GlassSheet", _shadow_box(DS.R_PANEL, DS.S5, 32))
	th.set_stylebox(&"panel", &"GlassBar", _shadow_box(DS.R_PANEL, DS.S3, 20))
	th.set_stylebox(&"panel", &"GlassCard", _shadow_box(DS.R_CARD, DS.S4, 16))
	th.set_stylebox(&"panel", &"GlassPill", _shadow_box(DS.R_PILL, DS.S1, 14))
	# Plain grouped surfaces inside glass (iOS "inset grouped" cells).
	th.set_type_variation(&"GroupPanel", &"PanelContainer")
	th.set_stylebox(&"panel", &"GroupPanel", _box(DS.FILL_3 + Color(0, 0, 0, 0.02), DS.R_CARD, DS.S4, DS.S3))
	th.set_type_variation(&"TilePanel", &"PanelContainer")
	th.set_stylebox(&"panel", &"TilePanel", _box(DS.FILL, DS.R_BUTTON, DS.S3, DS.S3))
	th.set_type_variation(&"SegmentIndicator", &"Panel")
	th.set_stylebox(&"panel", &"SegmentIndicator", _box(Color(1, 1, 1, 0.16), DS.R_PILL, 0, 0))
	th.set_type_variation(&"DemoBanner", &"PanelContainer")
	var demo := _box(Color(DS.ORANGE, 0.12), DS.R_CARD, DS.S3, DS.S3)
	demo.border_color = Color(DS.ORANGE, 0.35)
	demo.set_border_width_all(1)
	th.set_stylebox(&"panel", &"DemoBanner", demo)
	_label_variant(&"BadgeLabel", _font(650, 12), 11, DS.GOLD)
	th.set_stylebox(&"normal", &"BadgeLabel", _box(Color(DS.GOLD, 0.15), DS.R_PILL, 8, 2))
	th.set_type_variation(&"ForecastChip", &"PanelContainer")
	th.set_stylebox(&"panel", &"ForecastChip", _box(DS.FILL, DS.R_PILL, 10, 4))
	_label_variant(&"ChipValue", _font(600, 14, 0, true), 13, DS.TEXT)
	th.set_type_variation(&"Badge", &"Panel")
	th.set_stylebox(&"panel", &"Badge", _box(DS.RED, DS.R_PILL, 0, 0))
	th.set_type_variation(&"SheetHandle", &"Panel")
	th.set_stylebox(&"panel", &"SheetHandle", _box(Color(1, 1, 1, 0.28), DS.R_PILL, 0, 0))
	for v in [&"ListRow", &"ListRowSelected", &"IconTile"]:
		th.set_type_variation(v, &"PanelContainer")
	th.set_stylebox(&"panel", &"ListRow", _box(Color(1, 1, 1, 0), DS.R_FIELD, DS.S3, 10))
	var sel := _box(Color(DS.ACCENT, 0.16), DS.R_FIELD, DS.S3, 10)
	sel.border_color = Color(DS.ACCENT, 0.55)
	sel.set_border_width_all(1)
	th.set_stylebox(&"panel", &"ListRowSelected", sel)
	th.set_stylebox(&"panel", &"IconTile", _box(Color(1, 1, 1, 0.9), 10, 8, 8))
	# Custom-drawn controls read their pieces from the theme too.
	th.set_stylebox(&"track", &"AppSlider", _box(Color(1, 1, 1, 0.14), DS.R_PILL, 0, 0))
	th.set_stylebox(&"fill", &"AppSlider", _box(DS.ACCENT, DS.R_PILL, 0, 0))
	var knob := _box(Color(1, 1, 1, 1), DS.R_PILL, 0, 0)
	knob.shadow_color = Color(0, 0, 0, 0.35)
	knob.shadow_size = 6
	knob.shadow_offset = Vector2(0, 2)
	th.set_stylebox(&"knob", &"AppSlider", knob)
	th.set_stylebox(&"off", &"AppToggle", _box(Color(1, 1, 1, 0.16), DS.R_PILL, 0, 0))
	th.set_stylebox(&"on", &"AppToggle", _box(DS.GREEN, DS.R_PILL, 0, 0))
	th.set_stylebox(&"knob", &"AppToggle", knob)
	th.set_stylebox(&"panel", &"PanelContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"panel", &"Panel", StyleBoxEmpty.new())


func _fields() -> void:
	var n := _box(DS.FILL, DS.R_FIELD, 14, 12)
	n.border_color = Color(1, 1, 1, 0.06)
	n.set_border_width_all(1)
	var fo := n.duplicate()
	fo.border_color = Color(DS.ACCENT, 0.9)
	th.set_stylebox(&"normal", &"LineEdit", n)
	th.set_stylebox(&"focus", &"LineEdit", fo)
	th.set_stylebox(&"read_only", &"LineEdit", n)
	th.set_font(&"font", &"LineEdit", _font(400, 16))
	th.set_font_size(&"font_size", &"LineEdit", DS.FS_BODY)
	th.set_color(&"font_color", &"LineEdit", DS.TEXT)
	th.set_color(&"font_placeholder_color", &"LineEdit", DS.TEXT_3)
	th.set_color(&"caret_color", &"LineEdit", DS.ACCENT)
	th.set_color(&"selection_color", &"LineEdit", Color(DS.ACCENT, 0.35))
	th.set_constant(&"caret_width", &"LineEdit", 2)
	th.set_constant(&"minimum_character_width", &"LineEdit", 4)


func _scroll() -> void:
	var grab := _box(Color(1, 1, 1, 0.22), DS.R_PILL, 0, 0)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	for t in [&"VScrollBar", &"HScrollBar"]:
		th.set_stylebox(&"scroll", t, StyleBoxEmpty.new())
		th.set_stylebox(&"scroll_focus", t, StyleBoxEmpty.new())
		th.set_stylebox(&"grabber", t, grab)
		th.set_stylebox(&"grabber_highlight", t, grab)
		th.set_stylebox(&"grabber_pressed", t, grab)
	th.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"focus", &"ScrollContainer", StyleBoxEmpty.new())


func _misc() -> void:
	var sep := StyleBoxLine.new()
	sep.color = DS.SEPARATOR
	sep.thickness = 1
	th.set_stylebox(&"separator", &"HSeparator", sep)
	th.set_constant(&"separation", &"HSeparator", 1)
	th.set_constant(&"separation", &"VBoxContainer", DS.S2)
	th.set_constant(&"separation", &"HBoxContainer", DS.S2)
	th.set_stylebox(&"background", &"ProgressBar", _box(DS.FILL, DS.R_PILL, 0, 0))
	th.set_stylebox(&"fill", &"ProgressBar", _box(DS.ACCENT, DS.R_PILL, 0, 0))
	th.set_constant(&"outline_size", &"ProgressBar", 0)
	th.set_font_size(&"font_size", &"ProgressBar", 1)
	th.set_color(&"font_color", &"ProgressBar", Color(0, 0, 0, 0))
	var tip := _box(Color(0.1, 0.12, 0.17, 0.96), 12, 10, 6)
	th.set_stylebox(&"panel", &"TooltipPanel", tip)
	th.set_color(&"font_color", &"TooltipLabel", DS.TEXT)
