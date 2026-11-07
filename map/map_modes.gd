class_name MapModes
extends RefCounted
## Map colouring modes. Data modes take normalised values (0..1, NAN = no data)
## and map them through calm, dark-mode-friendly ramps.

enum Mode { POLITICAL, WEALTH, RELATIONS, HAPPINESS, STABILITY }

const LABELS := ["Political", "GDP per capita", "Relations", "Happiness", "Stability"]
const SHORT := ["Political", "Wealth", "Relations", "Happiness", "Stability"]
const ICONS := ["map", "coins", "handshake", "heart", "shield"]

## Muted political palette (adjacent countries never share a colour).
const POLITICAL := [
	Color("2f4566"), Color("2d5a5c"), Color("4a5571"), Color("3c4a6e"),
	Color("335d6e"), Color("4d4f6b"), Color("3d5d55"),
]
const RAMP_SEQ := [Color("1f2b45"), Color("1d4f73"), Color("1f7a7a"), Color("4fa07a"), Color("c9c27a")]
const RAMP_DIV := [Color("b5434b"), Color("6e3a4a"), Color("323c55"), Color("2f6b5a"), Color("3fae7a")]
const NO_DATA := Color("1b2436")

static var _political_cache: PackedColorArray


static func political(md: MapData) -> PackedColorArray:
	if _political_cache.size() == md.count():
		return _political_cache
	# Greedy graph colouring, most-connected first.
	var order := range(md.count())
	order.sort_custom(func(a: int, b: int) -> bool: return md.neighbours[a].size() > md.neighbours[b].size())
	var assigned := PackedInt32Array()
	assigned.resize(md.count())
	assigned.fill(-1)
	for i in order:
		var used := {}
		for j in md.neighbours[i]:
			used[assigned[j]] = true
		var start := absi(hash(md.iso3[i])) % POLITICAL.size()
		for k in POLITICAL.size():
			var cidx := (start + k) % POLITICAL.size()
			if not used.has(cidx):
				assigned[i] = cidx
				break
		if assigned[i] < 0:
			assigned[i] = start
	var out := PackedColorArray()
	out.resize(md.count())
	for i in md.count():
		var c: Color = POLITICAL[assigned[i]]
		# Tiny per-country lightness jitter so neighbours with equal hue still read apart.
		var j := (float(absi(hash(md.iso3[i] + "j")) % 100) / 100.0 - 0.5) * 0.08
		out[i] = c.lightened(j) if j > 0 else c.darkened(-j)
		if md.iso3[i] == "ATA":
			out[i] = Color("2a3346")
	_political_cache = out
	return out


static func ramp(stops: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0) * (stops.size() - 1)
	var i := mini(int(t), stops.size() - 2)
	return (stops[i] as Color).lerp(stops[i + 1], t - i)


## values: normalised 0..1 per country (NAN = no data).
static func data_colors(mode: int, values: PackedFloat32Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(values.size())
	var stops := RAMP_DIV if mode == Mode.RELATIONS else RAMP_SEQ
	for i in values.size():
		var v := values[i]
		out[i] = NO_DATA if is_nan(v) else ramp(stops, v)
	return out


static func legend_stops(mode: int) -> Array:
	return RAMP_DIV if mode == Mode.RELATIONS else RAMP_SEQ
