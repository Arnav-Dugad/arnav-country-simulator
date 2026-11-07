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


## Friendlier names for the map data's abbreviations (shown everywhere).
const NAME_FIX := {"SSD": "South Sudan", "KOR": "South Korea", "PRK": "North Korea", "COG": "Congo",
	"COD": "DR Congo", "CAF": "Central African Republic", "DOM": "Dominican Republic",
	"BIH": "Bosnia and Herzegovina", "GNQ": "Equatorial Guinea", "VCT": "St Vincent and the Grenadines",
	"ATG": "Antigua and Barbuda", "SLB": "Solomon Islands", "MHL": "Marshall Islands", "USA": "United States"}
## Countries whose name takes "the" in a sentence ("the United States").
const THE := ["USA", "GBR", "NLD", "PHL", "ARE", "CAF", "DOM", "BHS", "GMB", "MDV", "SLB", "MHL", "COM", "CZE"]


func _ready() -> void:
	map = load(MAP_PATH)
	for i in map.count():
		var fix: String = NAME_FIX.get(map.iso3[i], "")
		if fix != "":
			map.names[i] = fix
			map.names_long[i] = fix
	var parsed: Variant = JsonUtil.parse(FileAccess.get_file_as_string(COUNTRIES_PATH), "countries.json")
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


## Flag texture for a map index (null if none). Cached by ResourceLoader.
func flag_of(i: int) -> Texture2D:
	if i < 0:
		return null
	var path := "res://assets/flags/%s.svg" % map.iso2[i].to_lower()
	return load(path) if ResourceLoader.exists(path) else null


## Sovereign index for territories (e.g. Greenland -> Denmark), else itself.
func sovereign_of(i: int) -> int:
	var s: Variant = stats[i].get("sovereign")
	return index_of(s) if s is String else i


## The name as used mid-sentence: "the United States", "India".
func the_name(i: int) -> String:
	return ("the " + map.names[i]) if iso(i) in THE else map.names[i]


## Sentence start: "The United States", "India".
func The_name(i: int) -> String:
	return ("The " + map.names[i]) if iso(i) in THE else map.names[i]


func iso(i: int) -> String:
	return map.iso3[i] if i >= 0 and i < map.iso3.size() else ""


## A starting statistic (World Bank/IMF snapshot), or `fallback` if unknown.
func stat(i: int, key: String, fallback: float = 0.0) -> float:
	if i < 0 or i >= stats.size():
		return fallback
	var v: Variant = stats[i].get(key)
	return float(v) if v != null else fallback


## Countries with no sea coast (UN list; Caspian shores count as landlocked).
const LANDLOCKED := ["AFG", "AND", "ARM", "AUT", "AZE", "BDI", "BFA", "BLR", "BOL", "BTN", "BWA", "CAF",
	"CHE", "CZE", "ETH", "HUN", "KAZ", "KGZ", "KOS", "LAO", "LIE", "LSO", "LUX", "MDA", "MKD", "MLI",
	"MNG", "MWI", "NER", "NPL", "PRY", "RWA", "SDS", "SMR", "SRB", "SSD", "SVK", "SWZ", "TCD", "TJK",
	"TKM", "UGA", "UZB", "VAT", "ZMB", "ZWE"]
const ISLANDS := ["ATG", "BHS", "BHR", "BRB", "CPV", "COM", "CUB", "CYP", "DMA", "DOM", "FJI", "FSM",
	"GRD", "HTI", "IDN", "IRL", "ISL", "JAM", "JPN", "KIR", "KNA", "LCA", "LKA", "MDG", "MDV", "MHL",
	"MLT", "MUS", "NRU", "NZL", "PHL", "PLW", "PNG", "SGP", "SLB", "STP", "SYC", "TLS", "TON", "TTO",
	"TUV", "TWN", "VCT", "VUT", "WSM", "GBR", "BRN", "AUS"]


func landlocked(i: int) -> bool:
	return iso(i) in LANDLOCKED


func island(i: int) -> bool:
	return iso(i) in ISLANDS


## Short facts that shape how a country plays (shown in the picker and country sheet).
func traits(i: int) -> Array[String]:
	var out: Array[String] = []
	if stat(i, "fuel_exports_pct") >= 30.0:
		out.append("Oil & gas exporter")
	if stat(i, "tourism_pct") >= 15.0:
		out.append("Tourism economy")
	if stat(i, "manufacturing_pct") >= 20.0:
		out.append("Manufacturing power")
	if stat(i, "agriculture_pct") >= 20.0:
		out.append("Farming economy")
	if stat(i, "age65_pct") >= 18.0:
		out.append("Ageing population")
	elif stat(i, "age65_pct", 10.0) <= 4.0:
		out.append("Very young population")
	if stat(i, "gini") >= 45.0:
		out.append("Very unequal")
	if landlocked(i):
		out.append("Landlocked")
	elif island(i):
		out.append("Island nation")
	return out
