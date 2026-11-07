extends Node
## Static world data, loaded once: map geometry (MapData) + real-world starting
## statistics (data/countries.json). Indexes match MapData country indexes.

const COUNTRIES_PATH := "res://data/countries.json"
const MAP_PATH := "res://data/world_map.res"

var map: MapData
var meta: Dictionary = {}
## Per map index: Dictionary of real-world stats (empty Dictionary if none).
var stats: Array[Dictionary] = []
## Map indexes of playable countries, sorted by name.
var playable: PackedInt32Array


func _ready() -> void:
	map = load(MAP_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COUNTRIES_PATH))
	if parsed == null:
		push_error("World: failed to parse %s" % COUNTRIES_PATH)
		parsed = {"meta": {}, "countries": {}}
	meta = parsed.meta
	var by_code: Dictionary = parsed.countries
	stats.resize(map.count())
	var play: Array[int] = []
	for i in map.count():
		stats[i] = by_code.get(map.iso3[i], {})
		if stats[i].get("playable", false):
			play.append(i)
	play.sort_custom(func(a: int, b: int) -> bool: return name_of(a).naturalnocasecmp_to(name_of(b)) < 0)
	playable = PackedInt32Array(play)


func count() -> int:
	return map.count()


func index_of(code: String) -> int:
	return map.index_of(code)


func name_of(i: int) -> String:
	return map.names[i] if i >= 0 else ""


func is_playable(i: int) -> bool:
	return i >= 0 and stats[i].get("playable", false)


func is_estimated(i: int, field: String) -> bool:
	return field in stats[i].get("estimated", [])


## Continent group used for picker filters.
func group_of(i: int) -> String:
	var c := map.continents[i]
	if c == "North America" or c == "South America":
		return "Americas"
	if c == "Seven seas (open ocean)":
		return "Africa" if map.subregions[i].contains("Africa") else "Asia"
	return c


## Sovereign index for territories (e.g. Greenland -> Denmark), else itself.
func sovereign_of(i: int) -> int:
	var s: Variant = stats[i].get("sovereign")
	return index_of(s) if s is String else i
