<div align="center">

<img src="assets/branding/icon_512.png" width="128" alt="Arnav Country Simulator icon" />

# Arnav Country Simulator

**Lead any real nation on a living world map.**
A calm, realistic country simulator for Android. Every country starts from real 2025 data.

### [Download the latest APK](https://github.com/Arnav-Dugad/arnav-country-simulator/releases/latest)

<sub>Android 7.0+ · 64-bit (arm64) · free · no ads · works offline</sub>

</div>

---

## What it is

Pick any of **185 real countries** and run it month by month. Population, GDP, unemployment,
inflation, debt and stability all start from World Bank and IMF figures. Then it's up to you.

- **See why.** Tap any number to see exactly what's pushing it up or down, in plain words.
- **Try before you commit.** Move a tax or budget slider and a live 12-month forecast shows the effect,
  and *Undo* takes it all back.
- **Economy and budget.** Set taxes, the interest rate and trade policy, then split spending across
  healthcare, education, infrastructure, military, welfare and research.
- **Laws and reforms.** Universal healthcare, free university, a carbon tax, the pension age and more.
  Each takes months to pass and has clear tradeoffs.
- **A living world.** Trade deals, alliances, aid and sanctions with every country; a credit rating
  from AAA to C; and your world rank.
- **36 events.** Floods, hurricanes and droughts where they really happen, oil booms and busts for
  oil states, and story chains that play out over months.
- **Elections.** Plan a campaign on your record, then watch election night unfold.
  At the end you get a legacy grade from A+ to F.
- **Made with care.** Glass interface, original sound and music, haptics, a guided first game,
  text-size, colour-blind and reduced-transparency options, cloud saves and offline play.

The world map is real (Natural Earth, Equal Earth projection), with pinch-zoom, soft springy edges,
capital cities, real flags and five map views.

## Screenshots

<p align="center">
  <img src="docs/screenshots/1_home.png" width="32%" alt="Home" />
  <img src="docs/screenshots/2_map.png" width="32%" alt="World map" />
  <img src="docs/screenshots/3_economy.png" width="32%" alt="Economy" />
</p>
<p align="center">
  <img src="docs/screenshots/4_event.png" width="32%" alt="Event with tradeoffs" />
  <img src="docs/screenshots/5_laws.png" width="32%" alt="Laws and reforms" />
  <img src="docs/screenshots/6_campaign.png" width="32%" alt="Election campaign" />
</p>

## Install on Android

1. On your phone, open **[Releases → Latest](https://github.com/Arnav-Dugad/arnav-country-simulator/releases/latest)**
   and tap the `.apk` file to download it.
2. Open the downloaded file. If Android asks, allow your browser or file manager to
   **Install unknown apps** (Settings → Apps → Special access → Install unknown apps).
3. Tap **Install**, then open **Arnav Country Simulator**.

**Updates:** the app checks for new versions on launch. You can also go to Settings → *Check for updates*.
Tap **Update now** and the new version installs over the old one, keeping your saves.

## Cloud saves (optional)

You can play as a guest with no sign-up, or add an email account to keep your saves on any device.
Saves are always written to the phone first and sync when you're back online. Cloud saves use
Firebase (Authentication + Cloud Firestore) on the free Spark plan.

## Building from source

- Godot **4.7.2** (standard build, GDScript only), Compatibility renderer.
- Android export uses the Gradle build: JDK 17, Android SDK (platform 36, build-tools 36.1.0).
- See [`CLAUDE.md`](CLAUDE.md) for the project structure, conventions and dev commands,
  and [`data/SOURCES.md`](data/SOURCES.md) for how the map and data are generated.
- Releases are built by GitHub Actions when a `vX.Y.Z` tag is pushed
  ([`.github/workflows/release.yml`](.github/workflows/release.yml)).

## Credits & licenses

| | Source | License |
|---|---|---|
| Country borders | [Natural Earth](https://www.naturalearthdata.com/) 1:50m Admin 0, v5.1.2 | Public domain |
| Economic data | [World Bank](https://data.worldbank.org/) WDI & WGI | CC BY 4.0 |
| Debt & fiscal data | [IMF](https://www.imf.org/external/datamapper/) World Economic Outlook | Free with attribution |
| Font | [Inter](https://rsms.me/inter/) by Rasmus Andersson | SIL Open Font License 1.1 |
| Icons | [Lucide](https://lucide.dev/) | ISC |
| Sound & music | Original, synthesized in-house (`tools/make_audio.py`) | Same as the game |
| Flags | [flag-icons](https://github.com/lipis/flag-icons) | MIT |
| Engine | [Godot Engine](https://godotengine.org/) | MIT |

Starting values for a few small states use regional estimates; the game marks them as estimated.
The simulation is a game model, not a forecast.

© 2026 Arnav Dugad. Game code and art in this repository are by the author.
