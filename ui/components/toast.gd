class_name Toast
extends GlassPanel
## A calm headline banner: slides down under the top chrome, stays a few seconds,
## then fades away. Tap to dismiss early.
## Only ever one on screen (Material snackbar rule): others wait in a short queue,
## duplicates are merged, and calm mode keeps a gap between banners.

const HOLD := 3.6
const MAX_QUEUE := 3
const GAP_CALM := 4.0     # seconds between banners in calm mode
const GAP_ALL := 0.5

static var _queue: Array = []       # [[parent, text, icon, tint, top]]
static var _busy := false
static var _last_end_ms := -100000

var _label: Label
var _icon: Control


static func show_headline(parent: Control, text: String, icon_name: String, tint: Color, top: float) -> void:
	for q in _queue:
		if str(q[1]) == text:
			return
	if _busy:
		_queue.append([parent, text, icon_name, tint, top])
		if _queue.size() > MAX_QUEUE:
			_queue.pop_front()
		return
	var gap := GAP_CALM if str(Settings.get_value("banners", "calm")) == "calm" else GAP_ALL
	var wait := gap - (Time.get_ticks_msec() - _last_end_ms) / 1000.0
	_busy = true
	if wait > 0.0 and is_instance_valid(parent) and parent.is_inside_tree():
		parent.get_tree().create_timer(wait).timeout.connect(func() -> void: _spawn(parent, text, icon_name, tint, top))
	else:
		_spawn(parent, text, icon_name, tint, top)


static func _spawn(parent: Control, text: String, icon_name: String, tint: Color, top: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		_busy = false
		_queue.clear()
		return
	var t: GlassPanel = load("res://ui/components/toast.gd").new()
	parent.add_child(t)
	t.call(&"_present", text, icon_name, tint, top)


static func _done() -> void:
	_busy = false
	_last_end_ms = Time.get_ticks_msec()
	if not _queue.is_empty():
		var q: Array = _queue.pop_front()
		show_headline(q[0], q[1], q[2], q[3], q[4])


## Forget queued banners (e.g. when leaving the game screen).
static func clear_queue() -> void:
	_queue.clear()
	_busy = false


func _present(text: String, icon_name: String, icon_tint: Color, top: float) -> void:
	theme_type_variation = &"GlassPill"
	tint = DS.GLASS_TINT_STRONG
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = ListRow.icon_tile(icon_name, icon_tint)
	_icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(_icon)
	_label = Label.new()
	_label.theme_type_variation = &"Headline"
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(10, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	var parent_w := (get_parent() as Control).size.x
	var w := minf(parent_w - DS.S4 * 2.0, 380.0)
	size = Vector2(w, 0)
	await get_tree().process_frame
	size = Vector2(w, get_combined_minimum_size().y)
	position = Vector2((parent_w - w) * 0.5, top - 16.0)
	modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	DS.spring(t)
	t.tween_property(self, "position:y", top, Settings.dur(DS.DUR_SLOW))
	DS.ease_out(t)
	t.tween_property(self, "modulate:a", 1.0, Settings.dur(DS.DUR))
	get_tree().create_timer(HOLD).timeout.connect(_leave)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed:
			_leave())


func _exit_tree() -> void:
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:   # freed without leaving (screen change)
		_done()


func _leave() -> void:
	if not is_inside_tree() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(self, "position:y", position.y - 12.0, Settings.dur(DS.DUR_FAST))
	t.tween_property(self, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.chain().tween_callback(func() -> void:
		_done()
		queue_free())
