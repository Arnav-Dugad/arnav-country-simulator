class_name Names
extends RefCounted
## Fictional people's names that sound right for each country: big countries
## have their own pool, everyone else uses their sub-region's pool. First names
## alternate female / male (even index = female), which Leaders relies on for
## portraits. Common names only, combined at random: nobody real is meant.

const COUNTRY := {
	"USA": [["Emily", "James", "Sarah", "Michael", "Jessica", "Robert", "Megan", "David", "Ashley", "Daniel"], ["Walker", "Bennett", "Hayes", "Carter", "Brooks", "Reed", "Parker", "Coleman", "Foster", "Hughes"]],
	"GBR": [["Charlotte", "Oliver", "Amelia", "Harry", "Sophie", "George", "Eleanor", "Thomas", "Grace", "William"], ["Ashworth", "Pemberton", "Holloway", "Fletcher", "Whitmore", "Bradley", "Cartwright", "Hargreaves", "Lockwood", "Thornton"]],
	"IRL": [["Aoife", "Cian", "Niamh", "Seán", "Siobhán", "Darragh", "Róisín", "Eoin", "Ciara", "Pádraig"], ["Byrne", "Gallagher", "Kavanagh", "Brennan", "Doherty", "Flanagan", "Keane", "Moran", "Quinn", "Lynch"]],
	"FRA": [["Camille", "Julien", "Claire", "Antoine", "Juliette", "Mathieu", "Élise", "Nicolas", "Margaux", "Pierre"], ["Lefèvre", "Moreau", "Girard", "Rousseau", "Bonnet", "Fontaine", "Chevalier", "Lambert", "Mercier", "Garnier"]],
	"DEU": [["Katharina", "Lukas", "Johanna", "Felix", "Annika", "Tobias", "Miriam", "Stefan", "Leonie", "Matthias"], ["Brandt", "Hoffmann", "Krüger", "Vogel", "Schreiber", "Lange", "Hartmann", "Wolff", "Neumann", "Franke"]],
	"ITA": [["Giulia", "Matteo", "Chiara", "Lorenzo", "Francesca", "Davide", "Elena", "Alessandro", "Sara", "Giorgio"], ["Bianchi", "Ferraro", "Colombo", "Esposito", "Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti"]],
	"ESP": [["Lucía", "Javier", "Carmen", "Pablo", "Marta", "Álvaro", "Elena", "Sergio", "Paula", "Diego"], ["García", "Navarro", "Moreno", "Ortega", "Delgado", "Castro", "Romero", "Herrera", "Vidal", "Serrano"]],
	"POL": [["Agnieszka", "Piotr", "Katarzyna", "Tomasz", "Magdalena", "Krzysztof", "Joanna", "Marek", "Ewa", "Paweł"], ["Nowak", "Wiśniewski", "Kowalczyk", "Zieliński", "Kamiński", "Lewandowski", "Dąbrowski", "Mazur", "Krawczyk", "Wójcik"]],
	"RUS": [["Anna", "Dmitri", "Elena", "Sergei", "Olga", "Mikhail", "Tatiana", "Andrei", "Irina", "Nikolai"], ["Volkov", "Sokolov", "Morozov", "Lebedev", "Kozlov", "Novikov", "Pavlov", "Orlov", "Belov", "Zaitsev"]],
	"UKR": [["Oksana", "Taras", "Iryna", "Bohdan", "Olena", "Andriy", "Natalia", "Yuriy", "Kateryna", "Mykola"], ["Kovalenko", "Bondarenko", "Shevchuk", "Tkachenko", "Kravchenko", "Melnyk", "Lysenko", "Savchenko", "Hrytsenko", "Moroz"]],
	"TUR": [["Elif", "Mehmet", "Zeynep", "Emre", "Ayşe", "Burak", "Selin", "Can", "Derya", "Kerem"], ["Yılmaz", "Kaya", "Demir", "Şahin", "Çelik", "Aydın", "Öztürk", "Arslan", "Doğan", "Koç"]],
	"CHN": [["Li Na", "Wang Wei", "Zhang Min", "Liu Yang", "Chen Jing", "Zhao Lei", "Yang Fang", "Huang Jun", "Zhou Hui", "Wu Gang"], [""]],
	"JPN": [["Yuki", "Hiroshi", "Aiko", "Kenji", "Haruka", "Takeshi", "Naomi", "Daisuke", "Emi", "Satoshi"], ["Tanaka", "Watanabe", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada", "Sasaki", "Inoue"]],
	"KOR": [["Ji-woo", "Min-jun", "Seo-yeon", "Ji-hoon", "Ha-eun", "Do-hyun", "Su-bin", "Hyun-woo", "Ye-jin", "Sung-min"], ["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim"]],
	"IND": [["Priya", "Arjun", "Ananya", "Rahul", "Meera", "Vikram", "Kavya", "Rohan", "Sneha", "Aditya"], ["Sharma", "Iyer", "Reddy", "Nair", "Gupta", "Joshi", "Menon", "Patel", "Rao", "Banerjee"]],
	"PAK": [["Ayesha", "Imran", "Fatima", "Bilal", "Sana", "Hamza", "Mahnoor", "Usman", "Zara", "Faisal"], ["Khan", "Malik", "Qureshi", "Chaudhry", "Butt", "Sheikh", "Mirza", "Rana", "Siddiqui", "Abbasi"]],
	"BGD": [["Nusrat", "Rafiq", "Farzana", "Tanvir", "Sharmin", "Kamal", "Nasrin", "Habib", "Shirin", "Arif"], ["Rahman", "Hossain", "Chowdhury", "Islam", "Ahmed", "Sarker", "Uddin", "Haque", "Karim", "Talukder"]],
	"IDN": [["Siti", "Budi", "Dewi", "Agus", "Putri", "Rizky", "Ayu", "Hendra", "Ratna", "Joko"], ["Wijaya", "Santoso", "Hidayat", "Saputra", "Kusuma", "Pratama", "Gunawan", "Halim", "Setiawan", "Nugroho"]],
	"VNM": [["Lan", "Minh", "Hương", "Tuấn", "Mai", "Đức", "Thảo", "Hùng", "Linh", "Quang"], ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô"]],
	"PHL": [["Maria", "Jose", "Angelica", "Miguel", "Kristine", "Carlo", "Patricia", "Paolo", "Bea", "Rafael"], ["Santos", "Reyes", "Cruz", "Bautista", "Garcia", "Mendoza", "Villanueva", "Aquino", "Castillo", "Ramos"]],
	"BRA": [["Ana", "João", "Beatriz", "Lucas", "Mariana", "Pedro", "Larissa", "Rafael", "Camila", "Gustavo"], ["Silva", "Santos", "Oliveira", "Souza", "Costa", "Pereira", "Almeida", "Carvalho", "Ribeiro", "Barbosa"]],
	"MEX": [["Ximena", "Alejandro", "Fernanda", "Diego", "Valeria", "Emiliano", "Daniela", "Santiago", "Regina", "Mateo"], ["Hernández", "López", "Martínez", "Ramírez", "Flores", "Torres", "Vázquez", "Morales", "Jiménez", "Ruiz"]],
	"ARG": [["Sofía", "Martín", "Valentina", "Joaquín", "Agustina", "Facundo", "Lucía", "Tomás", "Florencia", "Nicolás"], ["González", "Fernández", "Gómez", "Díaz", "Sosa", "Álvarez", "Romero", "Medina", "Acosta", "Benítez"]],
	"NGA": [["Chiamaka", "Emeka", "Ngozi", "Tunde", "Funmilayo", "Ibrahim", "Aisha", "Chinedu", "Bisola", "Yusuf"], ["Okafor", "Adeyemi", "Bello", "Nwosu", "Okonkwo", "Balogun", "Eze", "Abubakar", "Afolabi", "Danjuma"]],
	"ZAF": [["Thandiwe", "Sipho", "Lerato", "Thabo", "Naledi", "Bongani", "Zanele", "Pieter", "Anele", "Johan"], ["Ndlovu", "Mokoena", "Dlamini", "Nkosi", "van der Merwe", "Khumalo", "Botha", "Mahlangu", "Pretorius", "Zulu"]],
	"EGY": [["Nour", "Ahmed", "Mariam", "Omar", "Yasmin", "Karim", "Salma", "Mostafa", "Hana", "Tarek"], ["Hassan", "Mahmoud", "Ibrahim", "Abdelrahman", "El-Sayed", "Farouk", "Mansour", "Fahmy", "Soliman", "Naguib"]],
	"SAU": [["Noura", "Faisal", "Lama", "Abdullah", "Reem", "Khalid", "Haya", "Saud", "Dana", "Turki"], ["Al-Otaibi", "Al-Qahtani", "Al-Ghamdi", "Al-Harbi", "Al-Shehri", "Al-Dosari", "Al-Mutairi", "Al-Zahrani", "Al-Anazi", "Al-Shammari"]],
	"IRN": [["Maryam", "Reza", "Shirin", "Ali", "Leila", "Mehdi", "Nasrin", "Hossein", "Parisa", "Amir"], ["Hosseini", "Rahimi", "Karimi", "Moradi", "Ahmadi", "Jafari", "Rezaei", "Sadeghi", "Kazemi", "Mousavi"]],
	"AUS": [["Olivia", "Jack", "Chloe", "Liam", "Matilda", "Lachlan", "Isla", "Cooper", "Ruby", "Hamish"], ["Taylor", "Mitchell", "Campbell", "Murray", "Kelly", "Ryan", "Morrison", "Fraser", "Doyle", "Harrison"]],
	"CAN": [["Émilie", "Liam", "Avery", "Nathan", "Chloé", "Owen", "Maya", "Benoît", "Claire", "Ryan"], ["Tremblay", "MacDonald", "Gagnon", "Campbell", "Roy", "Anderson", "Côté", "Stewart", "Bouchard", "Fraser"]],
}

## Sub-region pools (Natural Earth subregions).
const SUBREGION := {
	"Northern Europe": [["Ingrid", "Erik", "Astrid", "Lars", "Freja", "Mikkel", "Sigrid", "Johan", "Linnea", "Henrik"], ["Lindqvist", "Hansen", "Berg", "Nielsen", "Johansson", "Larsen", "Virtanen", "Dahl", "Halvorsen", "Sørensen"]],
	"Western Europe": [["Sanne", "Jeroen", "Marie", "Luc", "Fleur", "Thijs", "Anouk", "Bram", "Lotte", "Maarten"], ["de Vries", "Jansen", "Peeters", "Dubois", "Bakker", "Visser", "Martin", "Smit", "Maes", "Huber"]],
	"Southern Europe": [["Maria", "Nikos", "Ana", "Luka", "Eleni", "Marko", "Ivana", "Giorgos", "Teresa", "Rui"], ["Papadopoulos", "Horvat", "Silva", "Kovačević", "Georgiou", "Marković", "Santos", "Nikolaidis", "Popović", "Ferreira"]],
	"Eastern Europe": [["Andreea", "Mihai", "Jana", "Petr", "Zsófia", "Bence", "Mariya", "Ivan", "Lucie", "Radu"], ["Popescu", "Novák", "Horváth", "Ivanova", "Dvořák", "Nagy", "Petrov", "Svoboda", "Ionescu", "Szabó"]],
	"South America": [["Valentina", "Sebastián", "Isabella", "Andrés", "Gabriela", "Felipe", "Natalia", "Camilo", "Paola", "Ricardo"], ["Rojas", "Vargas", "Castillo", "Mendoza", "Quispe", "Paredes", "Salazar", "Cárdenas", "Ríos", "Guerrero"]],
	"Central America": [["María José", "Carlos", "Andrea", "Luis", "Gabriela", "Jorge", "Karla", "Óscar", "Sofía", "Manuel"], ["Pérez", "López", "Aguilar", "Castro", "Mejía", "Rivera", "Solís", "Chávez", "Cruz", "Orellana"]],
	"Caribbean": [["Shanice", "Andre", "Kezia", "Marcus", "Tamika", "Devon", "Yolanda", "Rafael", "Nadia", "Jean-Pierre"], ["Campbell", "Joseph", "Thomas", "Baptiste", "Williams", "Pierre", "Charles", "Brown", "Martínez", "Henry"]],
	"Northern America": [["Emily", "James", "Sarah", "Michael", "Jessica", "Robert", "Megan", "David", "Ashley", "Daniel"], ["Walker", "Bennett", "Hayes", "Carter", "Brooks", "Reed", "Parker", "Coleman", "Foster", "Hughes"]],
	"Western Africa": [["Aminata", "Kwame", "Fatou", "Moussa", "Ama", "Kofi", "Mariama", "Ousmane", "Adjoa", "Seydou"], ["Diallo", "Mensah", "Traoré", "Keita", "Owusu", "Coulibaly", "Sow", "Asante", "Camara", "Boateng"]],
	"Eastern Africa": [["Wanjiru", "Tendai", "Amina", "Juma", "Grace", "Abebe", "Zawadi", "Musa", "Hirut", "Baraka"], ["Kamau", "Mwangi", "Otieno", "Bekele", "Mutasa", "Nyerere", "Haile", "Kiprop", "Ochieng", "Tesfaye"]],
	"Middle Africa": [["Grâce", "Patrice", "Esther", "Didier", "Chantal", "Félix", "Josiane", "Serge", "Nadège", "Hervé"], ["Mbala", "Ngoma", "Kabila", "Mukendi", "Tshibanda", "Biya", "Nzinga", "Ilunga", "Mbeki", "Kasongo"]],
	"Southern Africa": [["Thandiwe", "Sipho", "Lerato", "Thabo", "Naledi", "Bongani", "Kagiso", "Tumelo", "Palesa", "Lungile"], ["Ndlovu", "Mokoena", "Dlamini", "Nkosi", "Moyo", "Khumalo", "Banda", "Phiri", "Sithole", "Mabuza"]],
	"Northern Africa": [["Amira", "Youssef", "Salma", "Karim", "Leila", "Mehdi", "Nadia", "Hamza", "Imane", "Rachid"], ["Benali", "El Amrani", "Haddad", "Bouzid", "Mansouri", "Cherif", "Belkacem", "Tazi", "Saidi", "Trabelsi"]],
	"Western Asia": [["Layla", "Omar", "Yasmin", "Karim", "Noor", "Tariq", "Dina", "Hassan", "Rania", "Fadi"], ["Haddad", "Khalil", "Nasser", "Aziz", "Saleh", "Mansour", "Darwish", "Khoury", "Hamdan", "Rashid"]],
	"Central Asia": [["Aigerim", "Nurlan", "Dilnoza", "Rustam", "Madina", "Timur", "Gulnara", "Daniyar", "Zarina", "Azamat"], ["Nurlanov", "Karimov", "Abdullaev", "Tokayev", "Sultanov", "Rakhimov", "Ismailov", "Aliyev", "Bekov", "Usmanov"]],
	"Southern Asia": [["Priya", "Arjun", "Ananya", "Rahul", "Meera", "Vikram", "Sana", "Imran", "Kavya", "Rohan"], ["Sharma", "Perera", "Khan", "Shrestha", "Rahman", "Fernando", "Gurung", "Chowdhury", "Silva", "Thapa"]],
	"Eastern Asia": [["Mei", "Hiroshi", "Ji-woo", "Wei", "Yuki", "Min-jun", "Lan", "Kenji", "Bolor", "Batbayar"], ["Chen", "Tanaka", "Kim", "Wang", "Sato", "Park", "Lin", "Ganbaatar", "Huang", "Li"]],
	"South-Eastern Asia": [["Siti", "Arif", "Ploy", "Somchai", "Linh", "Minh", "Nurul", "Kiet", "Mya", "Thant"], ["Wijaya", "Tan", "Srisuk", "Nguyen", "Lim", "Rahman", "Chua", "Phan", "Aung", "Saelim"]],
	"Australia and New Zealand": [["Olivia", "Jack", "Aroha", "Liam", "Mia", "Tane", "Ruby", "Noah", "Mere", "Finn"], ["Taylor", "Wilson", "Ngata", "Brown", "Clarke", "Parata", "Murphy", "Walsh", "Kelly", "Reid"]],
	"Melanesia": [["Mere", "Joseph", "Grace", "Peter", "Ruth", "John", "Esther", "Michael", "Naomi", "Samuel"], ["Kaputin", "Tari", "Waigani", "Sope", "Natapei", "Lini", "Kalsakau", "Bainimarama", "Rabuka", "Tuilagi"]],
}


## [firsts, lasts] for country i.
static func pool(i: int) -> Array:
	var iso := World.iso(i)
	if COUNTRY.has(iso):
		return COUNTRY[iso]
	var sub: String = World.map.subregions[i]
	if SUBREGION.has(sub):
		return SUBREGION[sub]
	return Cabinet.NAMES[Leaders.group_of(i)]


## A full name. Chinese names are family-name-first and already complete.
static func full(i: int, first_idx: int, last_idx: int) -> String:
	var p := pool(i)
	var firsts: Array = p[0]
	var lasts: Array = p[1]
	var f: String = firsts[first_idx % firsts.size()]
	var l: String = lasts[last_idx % lasts.size()]
	return f if l == "" else "%s %s" % [f, l]
