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
## Wide screen (phone turned sideways): the design size flips to 844 x 390 so
## everything keeps its size, and panels move to the side.
var landscape := false
const PORTRAIT_SIZE := Vector2i(390, 844)
const LANDSCAPE_SIZE := Vector2i(844, 390)


func _ready() -> void:
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	get_tree().root.size_changed.connect(_recompute)
	_recompute.call_deferred()


func _recompute() -> void:
	var win_size := DisplayServer.window_get_size()
	var wide := win_size.x > win_size.y
	if wide != landscape or get_tree().root.content_scale_size != (LANDSCAPE_SIZE if wide else PORTRAIT_SIZE):
		landscape = wide
		get_tree().root.content_scale_size = LANDSCAPE_SIZE if wide else PORTRAIT_SIZE
		_recompute.call_deferred()   # the visible rect updates next frame
		return
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


## Landscape: move a bottom card to the right side and shrink it to fit the
## short screen (portrait: no change). Call after positioning it for portrait.
func fit_card(card: Control, host: Control) -> void:
	if not landscape:
		card.scale = Vector2.ONE
		return
	var h := card.size.y
	var avail := host.size.y - top - bottom - DS.S3 * 2.0
	var s := clampf(avail / maxf(h, 1.0), 0.55, 1.0)
	card.pivot_offset = Vector2.ZERO
	card.scale = Vector2.ONE * s
	card.position = Vector2(host.size.x - card.size.x * s - DS.S4 - right, top + DS.S3 + (avail - h * s) * 0.5)


## Viewport size in logical points.
func size() -> Vector2:
	return get_tree().root.get_visible_rect().size
