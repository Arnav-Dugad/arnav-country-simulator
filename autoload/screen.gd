extends Node
## Safe-area helper. Converts DisplayServer's physical-pixel safe area into
## viewport (logical point) insets, so UI can avoid notches, cut-outs and the
## gesture bar on any aspect ratio.

signal insets_changed

## Simulated insets for desktop testing (logical points). Zero on device.
const DESKTOP_SIM := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

var top := 0.0
var bottom := 0.0
var left := 0.0
var right := 0.0


func _ready() -> void:
	get_tree().root.size_changed.connect(_recompute)
	_recompute.call_deferred()


func _recompute() -> void:
	var vp := get_tree().root
	var vsize := vp.get_visible_rect().size
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
			return
		var sx := vsize.x / float(win.x)
		var sy := vsize.y / float(win.y)
		top = maxf(0.0, safe.position.y) * sy
		left = maxf(0.0, safe.position.x) * sx
		bottom = maxf(0.0, float(win.y - safe.end.y)) * sy
		right = maxf(0.0, float(win.x - safe.end.x)) * sx
	else:
		top = DESKTOP_SIM.top
		bottom = DESKTOP_SIM.bottom
		left = DESKTOP_SIM.left
		right = DESKTOP_SIM.right
	insets_changed.emit()


## Viewport size in logical points.
func size() -> Vector2:
	return get_tree().root.get_visible_rect().size
