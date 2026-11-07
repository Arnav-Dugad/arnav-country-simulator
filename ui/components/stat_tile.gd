class_name StatTile
extends PanelContainer
## Compact stat: caption, animated value, and a coloured change indicator.

var caption: Label
var number: AnimatedNumber
var delta_label: Label
## true = higher is good (green when rising); false = higher is bad.
var higher_is_good := true


func setup(title: String, fmt: Callable, good_up: bool = true) -> StatTile:
	theme_type_variation = &"TilePanel"
	higher_is_good = good_up
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	add_child(v)
	caption = Label.new()
	caption.theme_type_variation = &"Overline"
	caption.text = title.to_upper()
	v.add_child(caption)
	number = AnimatedNumber.new()
	number.formatter = fmt
	v.add_child(number)
	delta_label = Label.new()
	delta_label.theme_type_variation = &"Caption"
	v.add_child(delta_label)
	return self


## Updates the value and shows the change vs `previous` (e.g. a year ago).
func show_value(v: float, previous: float = NAN, delta_fmt: Callable = Callable()) -> void:
	number.value = v
	if is_nan(previous):
		delta_label.text = " "
		return
	var d := v - previous
	var good := (d >= 0.0) == higher_is_good
	var txt: String = delta_fmt.call(d) if delta_fmt.is_valid() else ("%+.1f" % d)
	delta_label.text = (("↑ " if d >= 0.0 else "↓ ") + txt + " in a year") if absf(d) > 0.0001 else "No change"
	delta_label.add_theme_color_override(&"font_color",
		DS.TEXT_3 if absf(d) <= 0.0001 else (DS.GREEN if good else DS.RED))
