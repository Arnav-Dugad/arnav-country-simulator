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
