class_name Dock
extends GlassPanel
## Floating glass dock: Economy, Budget, Diplomacy, Events, Settings.

signal opened(page: String)

const ITEMS := [
	["economy", "Economy", "chart"],
	["budget", "Budget", "wallet"],
	["diplomacy", "Diplomacy", "globe"],
	["events", "Events", "zap"],
	["settings", "Settings", "settings"],
]

var _buttons := {}
var _badge: Panel
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
		b.pressed.connect(func() -> void: opened.emit(it[0]))
		row.add_child(b)
		_buttons[it[0]] = b
	_badge = Panel.new()
	_badge.theme_type_variation = &"Badge"
	_badge.custom_minimum_size = Vector2(9, 9)
	_badge.size = Vector2(9, 9)
	_badge.visible = false
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons["events"].add_child(_badge)
	_buttons["events"].resized.connect(_place_badge)


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


func set_badge(show_it: bool) -> void:
	_badge.visible = show_it


func _place_badge() -> void:
	var b: Control = _buttons["events"]
	_badge.position = Vector2(b.size.x * 0.5 + 8, 4)
