class_name Government
extends RefCounted
## How each country is governed (as of 2025): its system, the leader's title, how
## often national elections happen, and whether they are free.
##
## Sources: national constitutions (term lengths), EIU Democracy Index 2024 and
## Freedom House 2025 (free vs managed elections), news of the 2020–2025 coups
## (Sahel, Guinea, Sudan, Myanmar, Madagascar). Countries not listed fall back to
## their region's most common system (Europe: parliamentary, 4 years; elsewhere:
## presidential, 5 years).
##
## What changes with the system:
##   free       elections every term; you need a majority (see Economy.WIN_*)
##   managed    elections every term, tilted in your favour; they only turn
##              against you when support collapses, and disputed wins cost stability
##   none       no elections: legitimacy rests on stability and support. Some
##              systems hold a periodic review (a Party Congress …) and the
##              military can remove leaders who cut its budget. Collapse of order
##              ends your rule (revolution) instead of an election defeat.

const KINDS := {
	"presidential": {"name": "Presidential democracy", "leader": "President", "elections": "free"},
	"semi_presidential": {"name": "Semi-presidential republic", "leader": "President", "elections": "free"},
	"parliamentary": {"name": "Parliamentary democracy", "leader": "Prime Minister", "elections": "free"},
	"monarchy_parl": {"name": "Constitutional monarchy", "leader": "Prime Minister", "elections": "free"},
	"managed": {"name": "Dominant-party state", "leader": "President", "elections": "managed"},
	"one_party": {"name": "One-party state", "leader": "General Secretary", "elections": "none",
		"review": 5, "review_name": "Party Congress"},
	"monarchy": {"name": "Absolute monarchy", "leader": "King", "elections": "none"},
	"theocracy": {"name": "Theocratic republic", "leader": "Supreme Leader", "elections": "none",
		"review": 8, "review_name": "Council review"},
	"military": {"name": "Military government", "leader": "Military ruler", "elections": "none", "army": true},
	"transitional": {"name": "Transitional government", "leader": "Interim leader", "elections": "none"},
}

## iso3 -> [kind, term years, leader title override ("" = the kind's default)]
const COUNTRIES := {
	# Americas
	"USA": ["presidential", 4, ""], "MEX": ["presidential", 6, ""], "BRA": ["presidential", 4, ""],
	"ARG": ["presidential", 4, ""], "CHL": ["presidential", 4, ""], "COL": ["presidential", 4, ""],
	"PER": ["presidential", 5, ""], "ECU": ["presidential", 4, ""], "BOL": ["presidential", 5, ""],
	"PRY": ["presidential", 5, ""], "URY": ["presidential", 5, ""], "CRI": ["presidential", 4, ""],
	"PAN": ["presidential", 5, ""], "DOM": ["presidential", 4, ""], "GTM": ["presidential", 4, ""],
	"HND": ["presidential", 4, ""], "SLV": ["managed", 5, ""], "NIC": ["managed", 5, ""],
	"VEN": ["managed", 6, ""], "CUB": ["one_party", 5, "First Secretary"], "HTI": ["transitional", 5, ""],
	"GUY": ["presidential", 5, ""], "SUR": ["presidential", 5, ""], "JAM": ["monarchy_parl", 5, ""],
	"TTO": ["parliamentary", 5, ""], "BHS": ["monarchy_parl", 5, ""], "BLZ": ["monarchy_parl", 5, ""],
	"BRB": ["parliamentary", 5, ""], "CAN": ["monarchy_parl", 4, ""],
	# Europe
	"GBR": ["monarchy_parl", 5, ""], "IRL": ["parliamentary", 5, "Taoiseach"], "FRA": ["semi_presidential", 5, ""],
	"DEU": ["parliamentary", 4, "Chancellor"], "AUT": ["parliamentary", 5, "Chancellor"],
	"CHE": ["parliamentary", 4, "President of the Confederation"], "ITA": ["parliamentary", 5, ""],
	"ESP": ["monarchy_parl", 4, ""], "PRT": ["parliamentary", 4, ""], "NLD": ["monarchy_parl", 4, ""],
	"BEL": ["monarchy_parl", 5, ""], "LUX": ["monarchy_parl", 5, ""], "DNK": ["monarchy_parl", 4, ""],
	"NOR": ["monarchy_parl", 4, ""], "SWE": ["monarchy_parl", 4, ""], "FIN": ["parliamentary", 4, ""],
	"ISL": ["parliamentary", 4, ""], "EST": ["parliamentary", 4, ""], "LVA": ["parliamentary", 4, ""],
	"LTU": ["semi_presidential", 4, ""], "POL": ["parliamentary", 4, ""], "CZE": ["parliamentary", 4, ""],
	"SVK": ["parliamentary", 4, ""], "HUN": ["parliamentary", 4, ""], "SVN": ["parliamentary", 4, ""],
	"HRV": ["parliamentary", 4, ""], "BIH": ["parliamentary", 4, "Chair of the Council of Ministers"],
	"SRB": ["parliamentary", 4, ""], "MNE": ["parliamentary", 4, ""], "MKD": ["parliamentary", 4, ""],
	"ALB": ["parliamentary", 4, ""], "KOS": ["parliamentary", 4, ""], "GRC": ["parliamentary", 4, ""],
	"CYP": ["presidential", 5, ""], "MLT": ["parliamentary", 5, ""], "ROU": ["semi_presidential", 4, ""],
	"BGR": ["parliamentary", 4, ""], "MDA": ["parliamentary", 4, ""], "UKR": ["semi_presidential", 5, ""],
	"BLR": ["managed", 5, ""], "RUS": ["managed", 6, ""], "GEO": ["managed", 4, "Prime Minister"],
	"ARM": ["parliamentary", 5, ""], "AZE": ["managed", 7, ""], "TUR": ["managed", 5, ""],
	# Middle East & North Africa
	"ISR": ["parliamentary", 4, ""], "PSX": ["transitional", 4, "President"], "LBN": ["parliamentary", 4, ""],
	"JOR": ["monarchy", 4, "King"], "SYR": ["transitional", 5, "Interim President"],
	"IRQ": ["parliamentary", 4, ""], "IRN": ["theocracy", 4, ""], "SAU": ["monarchy", 4, "King"],
	"ARE": ["monarchy", 5, "President"], "QAT": ["monarchy", 4, "Emir"], "KWT": ["monarchy", 4, "Emir"],
	"BHR": ["monarchy", 4, "King"], "OMN": ["monarchy", 4, "Sultan"], "YEM": ["transitional", 4, "Council Chairman"],
	"EGY": ["managed", 6, ""], "LBY": ["transitional", 4, ""], "TUN": ["managed", 5, ""], "DZA": ["managed", 5, ""],
	"MAR": ["monarchy", 5, "King"],
	# Sub-Saharan Africa
	"MRT": ["presidential", 5, ""], "SEN": ["presidential", 5, ""], "GMB": ["presidential", 5, ""],
	"GNB": ["presidential", 5, ""], "GIN": ["military", 7, "Transitional President"], "SLE": ["presidential", 5, ""],
	"LBR": ["presidential", 6, ""], "CIV": ["managed", 5, ""], "GHA": ["presidential", 4, ""],
	"TGO": ["managed", 6, "President of the Council"], "BEN": ["presidential", 5, ""], "NGA": ["presidential", 4, ""],
	"NER": ["military", 5, "Transitional President"], "MLI": ["military", 5, "Transitional President"],
	"BFA": ["military", 5, "Captain-President"], "TCD": ["managed", 5, ""], "CMR": ["managed", 7, ""],
	"CAF": ["managed", 7, ""], "GAB": ["managed", 7, ""], "GNQ": ["managed", 7, ""], "COG": ["managed", 5, ""],
	"COD": ["managed", 5, ""], "AGO": ["managed", 5, ""], "NAM": ["presidential", 5, ""],
	"BWA": ["parliamentary", 5, "President"], "ZAF": ["parliamentary", 5, "President"],
	"LSO": ["monarchy_parl", 5, ""], "SWZ": ["monarchy", 5, "King"], "MOZ": ["managed", 5, ""],
	"MWI": ["presidential", 5, ""], "ZMB": ["presidential", 5, ""], "ZWE": ["managed", 5, ""],
	"TZA": ["managed", 5, ""], "KEN": ["presidential", 5, ""], "UGA": ["managed", 5, ""],
	"RWA": ["managed", 5, ""], "BDI": ["managed", 7, ""], "SDS": ["transitional", 5, "President"],
	"SDN": ["military", 5, "Council Chairman"], "ETH": ["managed", 5, "Prime Minister"],
	"ERI": ["one_party", 5, "President"], "DJI": ["managed", 5, ""], "SOM": ["presidential", 4, ""],
	"MDG": ["military", 5, "Transitional President"], "MUS": ["parliamentary", 5, ""],
	"CPV": ["parliamentary", 5, ""], "COM": ["managed", 5, ""], "STP": ["semi_presidential", 4, ""],
	# Asia
	"CHN": ["one_party", 5, ""], "JPN": ["monarchy_parl", 4, ""], "KOR": ["presidential", 5, ""],
	"PRK": ["one_party", 5, "Supreme Leader"], "TWN": ["presidential", 4, ""], "MNG": ["parliamentary", 4, ""],
	"IND": ["parliamentary", 5, ""], "PAK": ["managed", 5, "Prime Minister"], "BGD": ["parliamentary", 5, ""],
	"LKA": ["presidential", 5, ""], "NPL": ["parliamentary", 5, ""], "BTN": ["monarchy_parl", 5, ""],
	"AFG": ["theocracy", 5, ""], "IDN": ["presidential", 5, ""], "MYS": ["monarchy_parl", 5, ""],
	"SGP": ["parliamentary", 5, ""], "THA": ["monarchy_parl", 4, ""], "VNM": ["one_party", 5, ""],
	"LAO": ["one_party", 5, ""], "KHM": ["managed", 5, "Prime Minister"],
	"MMR": ["military", 5, "Commander-in-Chief"], "PHL": ["presidential", 6, ""],
	"TLS": ["semi_presidential", 5, ""], "BRN": ["monarchy", 5, "Sultan"], "KAZ": ["managed", 7, ""],
	"UZB": ["managed", 7, ""], "TKM": ["managed", 7, ""], "TJK": ["managed", 7, ""], "KGZ": ["managed", 6, ""],
	# Oceania
	"AUS": ["monarchy_parl", 3, ""], "NZL": ["monarchy_parl", 3, ""], "PNG": ["monarchy_parl", 5, ""],
	"FJI": ["parliamentary", 4, ""], "SLB": ["monarchy_parl", 4, ""], "VUT": ["parliamentary", 4, ""],
	"WSM": ["parliamentary", 5, ""],
}

## Presidential term limits in force (2025): the most terms in a row a leader may
## serve. Countries not listed have no limit, or their head of government is a
## prime minister. Sources: national constitutions via the Comparative
## Constitutions Project (constituteproject.org). Where a leader may return after
## sitting out a term (Chile, Peru, Uruguay, Costa Rica, Panama) the limit is 1.
const TERM_LIMITS := {
	"USA": 2, "MEX": 1, "BRA": 2, "ARG": 2, "CHL": 1, "COL": 1, "PER": 1, "ECU": 2, "BOL": 2, "PRY": 1,
	"URY": 1, "CRI": 1, "PAN": 1, "DOM": 2, "GTM": 1, "GUY": 2,
	"FRA": 2, "LTU": 2, "ROU": 2, "UKR": 2, "CYP": 2,
	"SEN": 2, "GHA": 2, "NGA": 2, "BEN": 2, "LBR": 2, "SLE": 2, "KEN": 2, "MWI": 2, "ZMB": 2, "NAM": 2,
	"MRT": 2, "ZAF": 2, "BWA": 2,
	"KOR": 1, "TWN": 2, "PHL": 1, "IDN": 2, "LKA": 2,
}

## The reform that opens a closed system up to free elections (see Laws "free_elections").
const REFORM_TO := "presidential"


static func _entry(i: int) -> Array:
	var iso: String = World.map.iso3[i] if i >= 0 else ""
	if COUNTRIES.has(iso):
		return COUNTRIES[iso]
	if i >= 0 and World.group_of(i) == "Europe":
		return ["parliamentary", 4, ""]
	return ["presidential", 5, ""]


## The system in force for country i (the player's may have been reformed).
static func kind(i: int) -> String:
	if i >= 0 and i == Game.player and Game.politics.kind_override != "":
		return Game.politics.kind_override
	return str(_entry(i)[0])


static func info(i: int) -> Dictionary:
	return KINDS[kind(i)]


static func system_name(i: int) -> String:
	return str(info(i).name)


static func leader_title(i: int) -> String:
	var e := _entry(i)
	var k := kind(i)
	if k != str(e[0]):          # reformed: the new system's default title
		return str(KINDS[k].leader)
	return str(e[2]) if str(e[2]) != "" else str(KINDS[k].leader)


## "President Arnav Dugad" for the player once a name is set, else the title.
static func leader_display(i: int) -> String:
	var t := leader_title(i)
	if i == Game.player and str(Settings.leader_name).strip_edges() != "":
		return "%s %s" % [t, str(Settings.leader_name).strip_edges()]
	return t


static func party() -> String:
	var p := str(Settings.party_name).strip_edges()
	return p if p != "" else "your party"


static func term_years(i: int) -> int:
	return int(_entry(i)[1])


static func elections(i: int) -> String:
	return str(info(i).elections)


static func has_elections(i: int) -> bool:
	return elections(i) != "none"


static func is_free(i: int) -> bool:
	return elections(i) == "free"


static func is_democracy(i: int) -> bool:
	return is_free(i)


## Most terms in a row (0 = no limit). Only free elections enforce one; a system
## the player reformed into a democracy gets the common two-term rule.
static func term_limit(i: int) -> int:
	if elections(i) != "free":
		return 0
	if i == Game.player and Game.has_game() and Game.politics.kind_override != "":
		return 2
	return int(TERM_LIMITS.get(World.iso(i), 0))


## Years between leadership reviews for systems without elections (0 = none).
static func review_years(i: int) -> int:
	return int(info(i).get("review", 0))


static func review_name(i: int) -> String:
	return str(info(i).get("review_name", "Review"))


## The armed forces can remove this leader (military governments).
static func army_rules(i: int) -> bool:
	return bool(info(i).get("army", false))


## What "approval" means here: votes in a democracy, support elsewhere.
static func support_word(i: int) -> String:
	return "Approval" if has_elections(i) else "Support"


## Vote share at an election, given approval. Managed elections are tilted:
## the ruling party wins comfortably unless support has collapsed.
static func vote_share(i: int, approval: float, rng: RandomNumberGenerator) -> float:
	var noise := rng.randf_range(-2.5, 2.5)
	if elections(i) == "managed":
		return clampf(30.0 + approval * 0.65 + noise, 20.0, 88.0)
	return clampf(50.0 + (approval - 42.5) * 0.9 + noise, 22.0, 78.0)


## Probability of winning at a given approval (free elections: Economy.WIN_*).
static func win_chance(i: int, approval: float) -> float:
	if elections(i) == "managed":
		return clampf((approval - 15.0) / 15.0, 0.0, 1.0)
	var shift := Difficulty.election_shift() if i == Game.player else 0.0
	return clampf((approval - Economy.WIN_NONE - shift) / (Economy.WIN_SAFE - Economy.WIN_NONE), 0.0, 1.0)


## Short description for the country sheet / picker.
static func describe(i: int) -> String:
	var k := kind(i)
	match elections(i):
		"free":
			return "%s · elections every %d years" % [system_name(i), term_years(i)]
		"managed":
			return "%s · elections every %d years, tilted to the ruling party" % [system_name(i), term_years(i)]
	if review_years(i) > 0:
		return "%s · no elections; %s every %d years" % [system_name(i), review_name(i), review_years(i)]
	if k == "military" or k == "transitional":
		return "%s · elections promised, not scheduled" % system_name(i)
	return "%s · no elections" % system_name(i)
