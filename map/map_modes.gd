class_name MapModes
extends RefCounted
## Map colouring modes. Data modes take normalised values (0..1, NAN = no data)
## and map them through calm, dark-mode-friendly ramps.

enum Mode { POLITICAL, WEALTH, RELATIONS, HAPPINESS, STABILITY, GROWTH, DEBT, BLOCS, EMISSIONS }

const LABELS := ["Political", "GDP per capita", "Relations", "Happiness", "Stability", "Growth", "Debt", "Blocs", "CO₂ per person"]
const SHORT := ["Political", "Wealth", "Relations", "Happiness", "Stability", "Growth", "Debt", "Blocs", "Emissions"]
const ICONS := ["map", "coins", "handshake", "heart", "shield", "trending-up", "piggy-bank", "users", "factory"]

## Blocs view: the bloc each country is drawn in (first match wins), and its colour.
const BLOC_ORDER := ["eu", "nato", "brics", "eaeu", "asean", "gcc", "mercosur", "afcfta", "usmca"]
const BLOC_COLORS := {
	"eu": Color("2f6fd6"), "nato": Color("5b8fd9"), "brics": Color("c2453c"), "eaeu": Color("8e3a59"),
	"asean": Color("2aa38f"), "gcc": Color("c99a2e"), "mercosur": Color("44a35a"), "afcfta": Color("b5763a"),
	"usmca": Color("6b7fb3"),
}
const BLOC_NAMES := {"eu": "EU", "nato": "NATO", "brics": "BRICS", "eaeu": "Eurasian Union", "asean": "ASEAN",
	"gcc": "Gulf", "mercosur": "Mercosur", "afcfta": "African FTA", "usmca": "USMCA"}

## Muted political palette (adjacent countries never share a colour).
const POLITICAL := [
	Color("2f4566"), Color("2d5a5c"), Color("4a5571"), Color("3c4a6e"),
	Color("335d6e"), Color("4d4f6b"), Color("3d5d55"),
]
## Store map themes (cosmetic). Same graph colouring, different palette.
const THEMES := {
	"gold": [Color("6b5527"), Color("7a6a3a"), Color("5c4a2a"), Color("8a6d33"), Color("6e5f3c"), Color("594628"), Color("7d6a45")],
	"aurora": [Color("1f5a57"), Color("2a6b52"), Color("1d4f66"), Color("2f6e6a"), Color("245f45"), Color("1f4a5c"), Color("2e5f5a")],
	"graphite": [Color("3a3d44"), Color("4a4d55"), Color("2f3238"), Color("55585f"), Color("41444b"), Color("36393f"), Color("4e5158")],
	"ember": [Color("6e4136"), Color("7d5a3e"), Color("5e3a33"), Color("85603f"), Color("6b4a3a"), Color("5a3c2e"), Color("7a5545")],
}

const RAMP_SEQ := [Color("1f2b45"), Color("1d4f73"), Color("1f7a7a"), Color("4fa07a"), Color("c9c27a")]
const RAMP_DIV := [Color("b5434b"), Color("6e3a4a"), Color("323c55"), Color("2f6b5a"), Color("3fae7a")]
const NO_DATA := Color("1b2436")
## Colour-blind friendly: luminance rises steadily; blue -> orange avoids red/green.
const RAMP_SEQ_CB := [Color("1d2a4a"), Color("38457a"), Color("6b6e7e"), Color("a89a6b"), Color("f2d25a")]
const RAMP_DIV_CB := [Color("d97a1f"), Color("8a5a3a"), Color("333c55"), Color("3a6aa0"), Color("5aa8e8")]


static func seq_ramp() -> Array:
	return RAMP_SEQ_CB if Settings.colorblind else RAMP_SEQ


static func div_ramp() -> Array:
	return RAMP_DIV_CB if Settings.colorblind else RAMP_DIV

static var _political_cache: PackedColorArray
static var _cache_theme := ""


static func political(md: MapData) -> PackedColorArray:
	var theme := active_theme()
	if _political_cache.size() == md.count() and _cache_theme == theme:
		return _political_cache
	_cache_theme = theme
	var palette: Array = THEMES.get(theme, POLITICAL)
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
		var start := absi(hash(md.iso3[i])) % palette.size()
		for k in palette.size():
			var cidx := (start + k) % palette.size()
			if not used.has(cidx):
				assigned[i] = cidx
				break
		if assigned[i] < 0:
			assigned[i] = start
	var out := PackedColorArray()
	out.resize(md.count())
	for i in md.count():
		var c: Color = palette[assigned[i]]
		# Tiny per-country lightness jitter so neighbours with equal hue still read apart.
		var j := (float(absi(hash(md.iso3[i] + "j")) % 100) / 100.0 - 0.5) * 0.08
		out[i] = c.lightened(j) if j > 0 else c.darkened(-j)
		if md.iso3[i] == "ATA":
			out[i] = Color("2a3346")
	_political_cache = out
	return out


## The selected store theme if it is owned, else the default palette.
static func active_theme() -> String:
	var t := str(Settings.map_theme)
	return t if THEMES.has(t) and Store.owns("theme_" + t) else "default"


static func ramp(stops: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0) * (stops.size() - 1)
	var i := mini(int(t), stops.size() - 2)
	return (stops[i] as Color).lerp(stops[i + 1], t - i)


## values: normalised 0..1 per country (NAN = no data).
static func data_colors(mode: int, values: PackedFloat32Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(values.size())
	var stops := div_ramp() if mode in [Mode.RELATIONS, Mode.GROWTH] else seq_ramp()
	if mode in [Mode.DEBT, Mode.EMISSIONS]:
		stops = seq_ramp().duplicate()
		stops.reverse()      # more debt = darker/redder
	for i in values.size():
		var v := values[i]
		out[i] = NO_DATA if is_nan(v) else ramp(stops, v)
	return out


static func legend_stops(mode: int) -> Array:
	if mode in [Mode.DEBT, Mode.EMISSIONS]:
		var s := seq_ramp().duplicate()
		s.reverse()
		return s
	return div_ramp() if mode in [Mode.RELATIONS, Mode.GROWTH] else seq_ramp()


## Blocs view: one colour per bloc, everyone else dim.
static func bloc_colors(md: MapData) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(md.count())
	for i in md.count():
		var col := NO_DATA
		var host := i if World.is_playable(i) else World.sovereign_of(i)
		if host >= 0 and Game.has_game():
			for b in BLOC_ORDER:
				if Treaties.is_member(host, b):
					col = BLOC_COLORS[b]
					break
		out[i] = col
	return out
