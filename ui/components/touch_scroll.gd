class_name TouchScroll
extends ScrollContainer
## Vertical scroll view with its own drag-to-scroll: the list follows the finger
## 1:1 after an 8 pt slop, and keeps gliding after a flick. Works on every device
## (it does not rely on the engine's touchscreen detection) and with controls
## inside, which use MOUSE_FILTER_PASS so drags reach this container.
## Children decide their own direction first (sliders/charts claim horizontal drags).

const SLOP := 8.0
const FRICTION := 5.5

var _tracking := false
var _dragging := false
var _press_y := 0.0
var _from := 0.0
var _vel := 0.0
var _last_y := 0.0
var _last_t := 0.0
var _glide := 0.0          # exact float scroll position while gliding
## Horizontal mode (e.g. a row of chips) scrolls sideways instead.
var horizontal := false


static func make_horizontal() -> ScrollContainer:
	var t: ScrollContainer = load("res://ui/components/touch_scroll.gd").new()
	t.set(&"horizontal", true)
	t.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	t.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	t.size_flags_vertical = Control.SIZE_FILL
	return t


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_deadzone = 10000   # turn off the engine's own touch dragging (we do it)


func _ready() -> void:
	_let_through(self)
	get_tree().node_added.connect(_on_node_added)


## Inside a scroll view, cards/panels/buttons/decorations must not swallow a swipe
## (PanelContainer and plain Control default to MOUSE_FILTER_STOP). Text fields
## and native sliders keep their own handling.
func _let_through(n: Node) -> void:
	for c in n.get_children():
		_fix(c)
		_let_through(c)


func _on_node_added(n: Node) -> void:
	if n is Control and is_ancestor_of(n):
		_fix(n)


static func _fix(n: Node) -> void:
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP 			and not (n is LineEdit or n is TextEdit or n is Range or n is ScrollContainer):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS


func _axis(v: Vector2) -> float:
	return v.x if horizontal else v.y


func _get_scroll() -> int:
	return scroll_horizontal if horizontal else scroll_vertical


func _set_scroll(v: int) -> void:
	if horizontal:
		scroll_horizontal = v
	else:
		scroll_vertical = v


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_tracking = true
			_dragging = false
			_vel = 0.0
			_press_y = _axis(e.position)
			_from = _get_scroll()
			_last_y = _axis(e.position)
			_last_t = Time.get_ticks_msec() / 1000.0
		else:
			if _dragging:
				_glide = _get_scroll()
				# A finger that rested before lifting shouldn't fling.
				if Time.get_ticks_msec() / 1000.0 - _last_t > 0.1:
					_vel = 0.0
				accept_event()
			else:
				_vel = 0.0
			_tracking = false
			_dragging = false
	elif e is InputEventMouseMotion and _tracking:
		var p := _axis(e.position)
		var dy: float = p - _press_y
		if not _dragging and absf(dy) > SLOP:
			_dragging = true
			_press_y += SLOP * signf(dy)   # no jump when the drag starts
			dy = p - _press_y
		if _dragging:
			_set_scroll(int(round(_from - dy)))
			var now := Time.get_ticks_msec() / 1000.0
			var dt := maxf(now - _last_t, 1.0 / 240.0)
			_vel = lerpf(_vel, -(p - _last_y) / dt, 0.35)
			_last_y = p
			_last_t = now
			accept_event()


func _process(delta: float) -> void:
	if _tracking or absf(_vel) < 20.0:
		return
	_glide += _vel * delta
	_vel *= exp(-FRICTION * delta)
	var bar: ScrollBar = get_h_scroll_bar() if horizontal else get_v_scroll_bar()
	var max_scroll := bar.max_value - bar.page
	if _glide < 0.0 or _glide > max_scroll:
		_glide = clampf(_glide, 0.0, maxf(max_scroll, 0.0))
		_vel = 0.0
	_set_scroll(int(round(_glide)))
