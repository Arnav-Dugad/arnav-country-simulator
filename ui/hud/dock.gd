class_name Dock
extends GlassPanel
## Floating glass dock: Economy, Budget, Diplomacy, Events, Settings.

signal opened(page: String)

const ITEMS := [
	["economy", "Economy", "chart"],
	["budget", "Budget", "wallet"],
	["laws", "Laws", "gavel"],
	["diplomacy", "World", "globe"],
	["events", "Events", "zap"],
	["settings", "Settings", "settings"],
]

var _buttons := {}
var _badges := {}
var active := ""


func _ready() -> void:
	theme_type_variation = &"GlassBar"
	super._ready()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	add_child(row)
	for it in ITEMS:
		var b := AppButton.make(it[1], &"DockButton", it[2])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func() -> void: opened.emit(it[0]))
		row.add_child(b)
		_buttons[it[0]] = b
	for k in _buttons:
		var badge := Panel.new()
		badge.theme_type_variation = &"Badge"
		badge.custom_minimum_size = Vector2(9, 9)
		badge.size = Vector2(9, 9)
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buttons[k].add_child(badge)
		_buttons[k].resized.connect(func() -> void: badge.position = Vector2(_buttons[k].size.x * 0.5 + 8, 4))
		_badges[k] = badge


func button_rect(page: String) -> Rect2:
	return (_buttons[page] as Control).get_global_rect()


func set_active(page: String) -> void:
	active = page
	for k in _buttons:
		var b: AppButton = _buttons[k]
		var on: bool = k == page
		for c in [&"font_color", &"icon_normal_color", &"font_hover_color", &"icon_hover_color",
				&"font_pressed_color", &"icon_pressed_color"]:
			if on:
				b.add_theme_color_override(c, DS.ACCENT_SOFT)
			else:
				b.remove_theme_color_override(c)


## Small red dot on a dock item ("events" pending, "economy" needs attention).
func set_badge(show_it: bool, page: String = "events") -> void:
	_badges[page].visible = show_it
