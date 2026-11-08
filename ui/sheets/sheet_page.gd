class_name SheetPage
extends VBoxContainer
## Base for bottom-sheet pages. Subclasses build UI in _build() and update it in
## refresh() (called when opened and every simulated month while visible).

var title := ""
## Snap stop the sheet opens at for this page.
var open_at := BottomSheet.Snap.HALF


func _init() -> void:
	add_theme_constant_override(&"separation", DS.S4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


func _build() -> void:
	pass


func refresh() -> void:
	pass


## Called when the page becomes visible.
func on_open() -> void:
	refresh()


# ---------------------------------------------------------------- helpers ---
## Grouped card with an overline header. Returns the inner VBox to fill.
func section(header: String, parent: Control = self) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override(&"separation", DS.S2)
	parent.add_child(wrap)
	if header != "":
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = header.to_upper()
		wrap.add_child(h)
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	wrap.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(inner)
	return inner


func grid(parent: Control, columns: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	parent.add_child(g)
	return g


## Thin progress meter: solid fill to a, lighter "pending" fill to b.
func meter(a: float, b: float, color: Color, h: float = 6.0) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, w, h))
		var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		if b > a:
			f.bg_color = Color(color, 0.35)
			bar.draw_style_box(f, Rect2(0, 0, maxf(w * clampf(b, 0.0, 1.0), h), h))
		f.bg_color = color
		if a > 0.0:
			bar.draw_style_box(f, Rect2(0, 0, maxf(w * clampf(a, 0.0, 1.0), h), h)))
	return bar


## Photo with a title and caption over its lower edge.
func photo_header(scene: String, title_text: String, sub: String, h: float) -> Control:
	var ph := Photo.scene(scene, h, true)
	ph.set(&"fade_bottom", 0.55)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = DS.S4
	v.offset_right = -DS.S4
	v.offset_bottom = -DS.S3
	var t := Label.new()
	t.theme_type_variation = &"PhotoTitle"
	t.text = title_text
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.theme_type_variation = &"PhotoCaption"
		s.text = sub
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(40, 0)
		v.add_child(s)
	return ph


func note(text: String, parent: Control = self) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Footnote"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## Value one year ago from the player's history (NAN if not available).
static func year_ago(key: String) -> float:
	var h: PackedFloat32Array = Game.history.get(key, PackedFloat32Array())
	return h[h.size() - 13] if h.size() > 12 else NAN


static func fmt_pct(v: float) -> String:
	return String.num(v, 1) + "%"


static func fmt_pts(d: float) -> String:
	return String.num(absf(d), 1) + " pts"
