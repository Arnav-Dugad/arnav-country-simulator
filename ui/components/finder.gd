class_name Finder
extends RefCounted
## "Find anything": a search over every feature in the game. Type a few letters
## (or tap a popular one) and jump straight to the page and section.

## [title, page, section ("" = top), icon, words people might type]
const INDEX := [
	["State of the nation dashboard", "dashboard", "", "layout-dashboard", "dashboard overview summary everything stats numbers glance"],
	["Taxes", "economy", "Taxes", "coins", "income tax business vat property payroll fuel tariff sin tax rates"],
	["Interest rates & central bank", "economy", "Central bank", "landmark", "interest rate inflation money central bank"],
	["Trade policy", "economy", "Trade policy", "ship", "trade openness tariffs protection"],
	["Address the nation", "economy", "", "mic", "speech address tv"],
	["National goals", "economy", "", "crown", "goals targets"],
	["Pandemic response", "economy", "", "biohazard", "pandemic virus lockdown masks vaccine disease"],
	["Disaster response", "economy", "", "siren", "disaster flood hurricane earthquake relief rebuild"],
	["Stock market & wealth fund", "firms", "Stock market", "trending-up", "stock market shares index wealth fund sovereign"],
	["State firms: privatise or nationalise", "firms", "State firms", "landmark", "privatise nationalise state firms companies oil airline bank"],
	["Industries & subsidies", "industries", "", "factory", "industry industries sectors subsidies factories chips farming"],
	["Trading partners", "industries", "Biggest trading partners", "ship", "partners exports imports"],
	["Robots, AI & jobs", "industries", "Robots & AI", "bot", "robots ai automation jobs retraining robot tax four day week"],
	["Elections, promises & campaign", "economy", "", "vote", "election poll campaign promises pledges rally coalition"],
	["People, births & ageing", "population", "", "users", "population births fertility ageing pensions old"],
	["Family policy", "population", "Family policy", "baby", "family childcare child benefit babies"],
	["Housing & zoning", "population", "Cities & housing", "house", "housing rent homes zoning cities urban"],
	["Budget: where the money goes", "budget", "Where the money goes", "wallet", "budget spending health education military infrastructure welfare research"],
	["Quick budget plans", "budget", "Quick plans", "wallet", "balance deficit plan"],
	["Build hospitals, schools, roads…", "build", "", "hammer", "build hospital school road rail stadium power plant housing police prison"],
	["Military forces", "build", "", "shield", "military army tanks fighters navy defence forces"],
	["Research & technology", "build", "", "flask-conical", "research technology tech science ai fusion"],
	["Space race", "build", "", "rocket", "space moon mars rockets satellites"],
	["Space colonies", "build", "Space colonies", "moon", "moon base mars colony asteroid mining orbital space outposts"],
	["National projects", "build", "", "construction", "projects programmes national"],
	["Digital money", "firms", "Digital money", "bitcoin", "crypto bitcoin digital currency cbdc legal tender ban reserve blockchain"],
	["Diaspora & remittances", "population", "Diaspora & remittances", "plane-landing", "diaspora remittances migrants abroad money sent home bonds vote abroad"],
	["Culture exports", "tourism", "Culture exports", "clapperboard", "culture films music series games hits k-pop creative industries soft power"],
	["Digital nation", "industries", "Digital nation", "wifi", "digital internet online broadband digital id e-government cyber hackers ransomware"],
	["Critical minerals", "industries", "Critical minerals", "battery-charging", "minerals lithium cobalt rare earths nickel copper mines mining survey refine export ban"],
	["Fisheries & oceans", "industries", "Fisheries & oceans", "fish", "fish fishing fisheries ocean sea quota marine protected areas stocks"],
	["Food security", "industries", "Food security", "wheat", "food farming farms grain reserve harvest subsidies export ban hunger"],
	["World powers", "diplomacy", "World powers", "crown", "power ranking superpower league table strongest countries"],
	["Sea lanes", "diplomacy", "Sea lanes", "ship", "sea lanes shipping suez panama hormuz malacca canal strait navy escort tolls"],
	["Water", "diplomacy", "Water", "droplets", "water drought rivers dams desalination irrigation shortage nile indus mekong"],
	["Nuclear weapons", "diplomacy", "Nuclear weapons", "atom", "nuclear weapons bomb warheads deterrence treaty npt doomsday clock disarmament arms control"],
	["Air quality", "population", "Air quality", "wind", "air quality pollution smog pm2.5 dust clean air vehicles factories stoves"],
	["Health system", "population", "Health system", "stethoscope", "health hospitals doctors waiting times coverage medicine drug prices nurses"],
	["Schools & universities", "population", "Schools & universities", "graduation-cap", "education schools universities teachers learning test brain drain students"],
	["Regions", "population", "Regions", "map-pin", "regions separatism independence referendum autonomy provinces north south capital"],
	["World wonders", "build", "World wonders", "landmark", "wonders megaprojects canal space elevator arcology library"],
	["Power grid & blackouts", "build", "", "zap", "energy power electricity blackouts grid"],
	["Oil, gas, coal & minerals", "build", "", "fuel", "oil gas coal minerals reserves mining explore"],
	["Laws & reforms", "laws", "", "gavel", "laws reforms pass repeal"],
	["Your cabinet", "laws", "Your cabinet", "users", "cabinet ministers reshuffle"],
	["Power brokers: army, business, unions…", "laws", "Power brokers", "shield", "factions army generals business unions strikes religious clergy civil service coup loyalty"],
	["Culture & values", "laws", "Culture & values", "sparkles", "culture values religion tradition progressive secular openness society"],
	["Constitution", "laws", "Constitution", "scroll-text", "constitution term limits voting age electoral system senate courts federal rights amendment"],
	["Royal family", "laws", "Royal family", "crown", "royal king queen monarch heir first family spouse"],
	["Clean government", "laws", "Clean government", "gavel", "corruption crackdown clean"],
	["Media & propaganda", "laws", "Media & propaganda", "tv", "media press propaganda campaign censorship"],
	["Crime & policing", "laws", "Crime & justice", "siren", "crime police prisons justice gangs"],
	["Black market & smuggling", "laws", "Black market & smuggling", "package", "smuggling black market customs legalise cannabis"],
	["Your rival", "diplomacy", "Your rival", "swords", "rival"],
	["World markets: oil & food", "diplomacy", "World markets", "fuel", "oil price food price markets"],
	["Wars & the war room", "diplomacy", "At war", "swords", "war battle army front peace"],
	["Wars between other countries", "diplomacy", "Wars around the world", "swords", "mediate sell arms world wars"],
	["Your empire & vassals", "diplomacy", "Your empire", "crown", "empire annexed vassal independence"],
	["Security & threats", "diplomacy", "Security", "shield", "threat deterrence security"],
	["Intelligence & spies", "diplomacy", "Intelligence", "eye", "spies intelligence covert operations agency"],
	["Climate & emissions", "diplomacy", "Climate", "leaf", "climate emissions co2 warming pledge cop"],
	["Climate adaptation", "diplomacy", "Climate adaptation", "waves", "sea walls adaptation early warning firebreaks"],
	["United Nations", "diplomacy", "United Nations", "landmark", "un united nations security council resolution peacekeepers"],
	["Treaties & blocs", "diplomacy", "Treaties & blocs", "handshake", "treaties blocs eu nato join alliance"],
	["Tourism & soft power", "tourism", "", "plane-takeoff", "tourism tourists soft power fame"],
	["Host the World Cup or the Games", "tourism", "World events", "trophy", "host bid world cup olympics games expo"],
	["World heritage", "tourism", "World heritage", "landmark", "heritage unesco sites"],
	["Sport & national teams", "sports", "", "trophy", "sport football world cup olympics medals teams"],
	["Trophy cabinet", "sports", "Trophy cabinet", "trophy", "trophies titles"],
	["Inbox & decisions", "events", "", "bell", "inbox decisions events news"],
	["Hall of fame & achievements", "achievements", "", "crown", "achievements hall of fame rank points"],
	["Leaderboards & friends", "achievements", "", "users", "leaderboard friends ranking online"],
	["Settings", "settings", "", "settings", "settings options"],
	["Text size", "settings", "", "type", "text size font bigger smaller"],
	["Cheats", "settings", "", "wand-sparkles", "cheats sandbox money"],
	["Store", "store", "", "store", "store buy themes"],
]

const POPULAR := ["Taxes", "Build hospitals, schools, roads…", "Wars & the war room", "Laws & reforms", "Sport & national teams", "Research & technology"]


static func search(q: String) -> Array:
	q = q.strip_edges().to_lower()
	if q == "":
		return INDEX.filter(func(e: Array) -> bool: return str(e[0]) in POPULAR)
	var words := q.split(" ", false)
	var out: Array = []
	for e in INDEX:
		var hay := (str(e[0]) + " " + str(e[4])).to_lower()
		var score := 0
		for w in words:
			if hay.contains(w):
				score += 2 if str(e[0]).to_lower().contains(w) else 1
			else:
				score = -999
		if score > 0:
			out.append([score, e])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	return out.map(func(x: Array) -> Array: return x[1])


static func open(parent: Node) -> void:
	var m := ModalCard.new()
	parent.add_child(m)
	m.header("search", DS.ACCENT, "Find anything", "What are you looking for?")
	var input := LineEdit.new()
	input.placeholder_text = "Try \"taxes\", \"army\" or \"world cup\""
	input.clear_button_enabled = true
	m.content.add_child(input)
	var results := VBoxContainer.new()
	results.add_theme_constant_override(&"separation", 2)
	m.content.add_child(results)
	var fill := func(q: String) -> void:
		for ch in results.get_children():
			ch.queue_free()
		var found := search(q)
		if found.is_empty():
			var l := Label.new()
			l.theme_type_variation = &"Footnote"
			l.text = "Nothing matches. Try another word."
			results.add_child(l)
		for e in found.slice(0, 7):
			var row := ListRow.new().setup(str(e[0]), _where(e), "›")
			row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
			row.set_leading(ListRow.icon_tile(str(e[3]), DS.ACCENT))
			var entry: Array = e
			row.tapped.connect(func() -> void:
				m.dismiss()
				go(parent, str(entry[1]), str(entry[2])))
			results.add_child(row)
	input.text_changed.connect(func(t: String) -> void: fill.call(t))
	fill.call("")
	m.choice("Close", "", &"GhostButton", m.dismiss)


static func _where(e: Array) -> String:
	var page: String = {"economy": "Economy", "firms": "Economy › Wealth & firms", "industries": "Economy › Industries",
		"population": "Economy › People & society", "budget": "Budget", "build": "Build", "laws": "Laws", "diplomacy": "World",
		"tourism": "World › Tourism", "sports": "World › Sport", "events": "Inbox", "achievements": "Hall of fame",
		"settings": "Settings", "store": "Store", "dashboard": "Dashboard"}.get(str(e[1]), str(e[1]))
	return page + (" › " + str(e[2]) if str(e[2]) != "" else "")


## Open a page and scroll to one of its sections.
static func go(gs: Node, page: String, section: String) -> void:
	if gs == null or not gs.has_method("open_page"):
		return
	gs.open_page(page)
	if section == "":
		return
	await gs.get_tree().process_frame
	await gs.get_tree().process_frame
	var p: SheetPage = gs._pages.get(page)
	if p != null:
		p.scroll_to_section(section)
