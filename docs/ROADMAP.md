# Roadmap: Arnav Country Simulator, v0.1 → 1.0

> **North star:** the most beautiful, believable country simulator on a phone.
> Every number is real, every choice is felt, and every screen stays calm.

This is the working spec. Each milestone ships as a tagged release with its own CHANGELOG section,
passes the existing test suite (`sim_test`, `playtest`, `cloud_test`), and gets a device check
(screenshots plus a hands-on pass) before tagging.

---

## 0. Design principles (the bar for every item)

1. **Cause and effect are always visible.** Any number can explain itself in one tap, and no stat changes without a reason the player can find.
2. **Calm by default, depth on demand.** The map is the hero, depth sits one tap away, and nothing ever shouts.
3. **Real data, honest model.** Starting values are real, estimates are flagged, and formulas are documented in one place.
4. **Feels native.** 60 fps, spring motion, purposeful haptics, under 3 s from launch to map, full offline play.
5. **One design system.** Every new visual becomes a token or theme variation, with no one-off styling.
6. **Respect the player.** No ads, dark patterns, nagging or tracking by default.

---

## 1. Honest audit of v0.1.1

| Area | Today | Gap |
|---|---|---|
| Device feel | Touch and render verified on the emulator | Pinch and sheet drag not verified on hardware; pan stops at a hard clamp (no rubber band) |
| Map | Real borders, 5 modes, glow, labels | Flat ocean, no capitals, no flags, labels can sit under the HUD, one level of detail for all zooms |
| Legibility | Stat tiles, 4 charts | The player can't see *why* a number moved, no preview before committing a policy, charts can't be scrubbed |
| Gameplay depth | 4 levers, 6 budget shares, diplomacy, 16 events, elections | No laws or reforms, no political actors, few events, no goals, no difficulty, the world doesn't change on its own |
| Presentation | Glass UI, motion, haptics | **No sound at all**, no cinematic moments (elections, year end), no share card |
| Reach | English, phone portrait | No localization, screen reader, text sizes, colour-blind palettes, or tablet layout |
| Platform | GitHub APK and in-app updater | No Play Store build, no in-app account deletion (Play policy), no privacy policy page |
| Engineering | Headless tests, CI release | Tests don't run on every push, no save-format migrations, `game.gd` is getting large |

---

## v0.2 "Feel": hardware-grade polish  *(priority: highest, effort: M)*

The basics should feel finished before anything new is added.

### Gestures and camera
- [ ] **Real-device gesture pass** (pinch, two-finger pan, fling, double-tap, sheet drag), with tuning notes recorded.
- [ ] **Rubber-band edges:** panning past the world gives soft resistance (0.35× drag) and springs back on release, instead of a hard stop.
- [ ] **Zoom inertia:** a pinch-release carries a little zoom momentum (decays in about 180 ms), anchored at the pinch midpoint.
- [ ] **Two-finger tap** zooms out one level, and **long-press** on a country opens its sheet at half height with a haptic "select".
- [ ] **Smart framing:** `focus_country` avoids the top bar, mode control and open sheet using real measured insets.
- [ ] **120 Hz aware:** inertia uses real frame delta; tested at 60, 90 and 120 Hz.

### Map beauty
- [ ] **Ocean depth:** a subtle procedural depth gradient near coasts (distance field baked offline), plus a faint graticule (every 30°) that fades in at mid zoom.
- [ ] **Coastline light:** a 1 px inner highlight on land edges facing north-west, to suggest relief without textures.
- [ ] **Capitals:** Natural Earth populated places (admin-0 capitals) as 3 pt dots with a soft halo, with labels from zoom ×4 and the player's capital in gold.
- [ ] **Flags:** country flags from `flag-icons` (MIT) as SVG DPITextures with rounded 4 pt corners, in the picker rows, the country sheet header, the top bar (player) and the diplomacy list.
- [ ] **Label system v2:** keep labels clear of HUD rectangles, cross-fade between zoom bands (no popping), letter-spacing scaled to zoom, and two lines for long names ("United States / of America").
- [ ] **Selection feel:** a tap ripple at the touch point (expanding ring, 300 ms), and the raised country gets a soft 8 pt drop shadow tied to the zoom level.
- [ ] **Mode transitions:** a 450 ms colour crossfade with a legend that slides in under the mode control (gradient bar, min/max labels and the player's marker).

### Sound (new)
- [ ] **Audio system** (`Audio` autoload) with a UI bus, an ambience bus and a music bus, Settings sliders, and auto-ducking when an event card opens.
- [ ] **UI sound set** (about 12 sounds, under 60 ms, soft and pitched): tap, toggle on and off, sheet up and down, slider detent, success, warning, event chime, month tick (very quiet, optional), election drumroll and result.
- [ ] **Ambient music:** 2–3 calm loops (piano and pads) with seamless crossfades. CC0 or original only, with licences recorded in `assets/audio/LICENSES.md`.
- [ ] Respect the system's silent mode and the "Reduce motion" setting (no whooshes).

### Haptic language
- [ ] Map haptics to meaning:
  - selection is a 10 ms tick;
  - a slider crossing its starting marker gives a detent;
  - success is a double-light pulse;
  - warning is one firm pulse;
  - an election result is a short pattern.
- [ ] Prevent haptic spam during fast slider drags with a 40 ms minimum gap.

### Startup and performance
- [ ] **Bake render meshes offline** (fill, border and glow ArrayMeshes in `world_map.res`), aiming for at least 40% faster cold start, measured with `Time.get_ticks_msec()` in the splash.
- [ ] **Two map levels of detail:** a world-scale mesh (about 8k points) for low zoom and the current mesh for close zoom, crossfaded around ×3.
- [ ] **Idle redraw off:** when paused with no animation running, enter low-processor mode for battery.
- [ ] **Glass quality tiers:** 12 / 8 / 4 blur samples chosen from a measured frame time in the first 120 frames.

**Definition of done:** a 60 fps trace on a mid-range Android phone, launch to map in under 2.5 s, and every interaction producing sound plus haptics where specified.

---

## v0.3 "Understand": a legible simulation  *(priority: very high, effort: M–L)*

### "Why?" for every number
- [ ] The simulation records each term's **contribution** per tick (growth = trend + fiscal − taxes − rates ± events …) in a small ring buffer.
- [ ] Tapping any stat tile opens an **explainer sheet**: a waterfall chart (custom `_draw`) of contributors, sorted by size, coloured good or bad, with one plain-English line each ("Higher interest rates are cooling the economy: −0.6 pts").

### Live forecast while you decide
- [ ] Dragging a slider runs a **12-month projection** on a cloned `CountryState` (12 ticks of one country takes under 1 ms), throttled to 20 Hz.
- [ ] Under the slider, **delta chips** show the projected effect, for example `Growth −0.4`, `Approval −1.2`, `Revenue +$12B`, coloured by good or bad.
- [ ] On the open chart, a **dashed ghost line** shows the projected path next to history.

### Charts 2.0
- [ ] Scrubbing with a finger shows a crosshair and a value bubble that snaps to months, with haptic ticks at year boundaries.
- [ ] A time-range control (1Y, 5Y, All).
- [ ] An overlay to compare against the world median or the starting value.
- [ ] Events on the timeline: small dots on the chart where events happened, tappable to see what you chose.

### Briefings and advisors
- [ ] **Monthly briefing:** three generated headlines from the biggest changes ("Inflation falls to 3.1%, its lowest since 2026"), shown as a quiet banner that can be swiped away.
- [ ] **Cabinet advisors** (opt-in): Finance, Central Bank, Foreign Affairs and Interior. Each gives one short, contextual suggestion with a confidence level ("Rates look high for current inflation: consider −0.5 pts"). Never more than one at a time.
- [ ] **World rankings:** your rank by GDP, GDP per person, happiness and stability, with a sortable "World" list.
- [ ] **Compare:** you against any country side by side (two columns of tiles), opened from the country sheet.

**Definition of done:** a new player can answer "why did my approval drop?" in two taps.

---

## v0.4 "Depth": richer, still simple  *(priority: high, effort: L)*

### Laws and reforms (policy cards)
- [ ] About **30 laws** in 7 groups:
  - Health: universal coverage, public insurance
  - Economy: minimum wage, privatisation, wealth tax
  - Society: pension age, free university, digital ID
  - Environment: carbon tax, coal phase-out, EV subsidy
  - Security: border controls, police reform
  - Governance: anti-corruption agency, press freedom
  - Trade: export zones
- [ ] Each card shows its cost, effects, **enactment time** (3–18 months with a progress ring), and **political capital** cost.
- [ ] Real starting state where data allows (for example, which countries already have universal healthcare). Otherwise the law is off, flagged as estimated.

### Political capital and actors
- [ ] **Political capital:** earned from approval and election wins, and spent on big reforms and drastic slider moves (moves inside ±2 pts are free). This stops slider spam while keeping things simple.
- [ ] **Five voter blocs** (Workers, Business, Greens, Traditionalists, Youth). Each bloc's support reacts to specific policies, and approval becomes their weighted sum. A bloc breakdown sits in the "Why?" sheet.
- [ ] **Elections 2.0:**
  - **Campaign:** in the final 3 months, pick two themes (Economy, Security, Healthcare, Change, and so on). Themes boost the blocs they appeal to.
  - **Result:** an animated election-night sheet with bloc bars filling and the vote share counting up.

### Events 2.0
- [ ] **60+ events**, including:
  - **story chains** (pandemic → vaccine race → recovery boom; scandal → inquiry → resignation);
  - **regional flavour** (monsoon floods in South Asia, hurricanes in the Caribbean, heatwaves in Southern Europe, oil-price swings for producers);
  - **data-driven conditions** (oil exporters from World Bank fuel-export share, coastal states, ageing countries).
- [ ] Each event has a short illustration: a monochrome Lucide-style vector drawn in our own SVG style.
- [ ] Every choice shows its **expected effects** as chips (honest, rounded, with uncertainty where randomness applies).

### Economy and society depth (still one screen each)
- [ ] **Credit rating** (AAA to D) from debt, deficit, stability and growth. It drives borrowing costs, shows as a badge in the top bar, and downgrades trigger an event.
- [ ] **Global commodity index** (oil and food) moving on a seeded random walk with shocks. It hits importers and exporters differently, using real fuel and food trade shares.
- [ ] **Inequality** (Gini from the World Bank) feeding happiness and bloc support, and moved by welfare and tax policy.
- [ ] **Ageing:** a simplified old-age share that raises pension pressure over time, with real starting values.
- [ ] **Emissions and climate risk:** CO₂ per person from real data, linked to disaster frequency and green policies.

### A world that lives
- [ ] **AI-to-AI relations and blocs**, a trade network built from neighbours and real trade-partner seeds, and **recessions that spread** through trade links.
- [ ] **AI elections and leader changes**, which shift that country's relations with you, plus a world news feed of notable AI moves.
- [ ] **Diplomacy 2.0:**
  - **treaties:** climate accord, free-trade bloc, defence pact;
  - **UN votes:** quick yes, no or abstain cards with consequences;
  - **summits:** a yearly event;
  - **relation reasons:** "+12 trade deal · −8 you sanctioned their ally".
- [ ] **Security stays abstract and calm:** readiness and deterrence reduce hostile events. No combat simulation.

### Goals
- [ ] **Scenarios**, for example: "Tame Argentina's inflation below 10% in 4 years", "Make India a $10T economy by 2040", "Win three terms in Japan", "Balance Italy's budget".
- [ ] **30 achievements:** quiet glass toasts and a gallery of line-art badges.
- [ ] **Legacy score** at the end of a term (grade A+ to F) from growth, well-being, stability, debt and elections, with a breakdown.
- [ ] **Difficulty:** Relaxed, Standard or Realistic, affecting election thresholds, event severity, AI hostility and political capital income.

**Definition of done:** a full playthrough where at least one event chain, one reform and one treaty happen, and the bot playtest still reports zero errors.

---

## v0.5 "Delight": premium presentation  *(priority: high, effort: M)*

- [ ] **Home screen:** a resume card ("Continue as India · Mar 2031") over the slowly drifting map, with save slots showing **map thumbnails** captured at save time.
- [ ] **Year in review** every January: a full-screen glass card with 4 tiny sparklines, the headline of the year, best and worst decisions, and a **Share** button.
- [ ] **Share cards:** render a 1080×1350 summary image (map crop, flag, key stats) and share it through the Android share sheet (new method in the Kotlin plugin).
- [ ] **Milestone toasts:** "GDP passed $5T", "Inflation under 2%", "First trade deal".
- [ ] **Election night sequence:**
  - the map dims and the player's country pulses;
  - bloc bars fill and the vote share counts up;
  - a gold glow appears on a win.

  It stays tasteful, with no confetti.
- [ ] **Picker 2.0:**
  - **sorting:** by population, GDP or difficulty;
  - **featured nations:** "Tough starts" and "Rising powers";
  - **Surprise me**;
  - **preview tiles:** debt, inflation and stability shown before you commit.
- [ ] **Interactive tutorial** to replace the card onboarding. It uses coach marks during the first 3 months ("Tap your country", "Open Economy", "Try lowering taxes, then watch the forecast") and can be skipped and replayed from Settings.
- [ ] **Empty and loading states:** skeleton shimmer while loading cloud saves, and illustrated empty states.
- [ ] **Micro-interaction audit:** every control gets pressed, disabled, focus and loading states, and every list row gets a press highlight.
- [ ] **Android 12+ splash** via the platform splash API (icon on deep blue), which hands off seamlessly to our splash.

---

## v0.6 "Reach": everyone, every device  *(priority: medium-high, effort: M)*

- [ ] **Screen reader** (Godot AccessKit): accessible names, roles and values on every control, plus stat readouts ("Inflation, 3.1 percent, down 0.4 since last year").
- [ ] **Text size** at 85, 100, 115 or 130%, regenerating theme sizes at runtime with layouts verified at each size.
- [ ] **Colour-blind palettes** for data modes (Okabe-Ito and cividis), checked in a deuteranopia simulation.
- [ ] **Reduce transparency:** solid panels instead of glass (also faster on low-end phones).
- [ ] **Localization:** move every string to `tr()` with CSV catalogues.
  - **First wave:** Hindi, Spanish, Portuguese (BR), French, German, Indonesian, Japanese.
  - **Fonts:** Noto fallbacks (Devanagari, CJK subsets).
  - **Formats:** locale number and date formats, including the **lakh/crore** option for India.
- [ ] **Tablets and landscape:** a two-pane layout with the sheet as a right-side panel, plus foldable-aware insets.
- [ ] **Low-end mode**, auto-detected: 4-sample glass, the low-detail map only, and no glow pulse.

---

## v0.7 "Cloud and community"  *(priority: medium, effort: M)*

- [ ] **Save conflict sheet** ("This device · Mar 2031" vs "Cloud · Jan 2032"), letting the player pick and keep both.
- [ ] **In-app account deletion** (required by Play policy): deletes Firestore data then the Auth user.
- [ ] **Privacy policy** on GitHub Pages, linked in Settings and the README.
- [ ] **Leaderboards** (Spark-safe):
  - best legacy score per scenario;
  - writes validated by rules (schema, ranges, rate limit through server timestamps);
  - only a display name is shown.
- [ ] **Weekly challenge:** one seeded scenario everyone plays with identical events, then compared scores.
- [ ] **Remote tuning:** a public read-only Firestore doc that can override event weights and a few constants without a release (cached, with safe ranges).
- [ ] **Send feedback:** opt-in diagnostics (last 200 log lines plus device info) through an email or a pre-filled GitHub issue.

---

## v1.0 "Ship"  *(priority: when ready, effort: M)*

- [ ] **Play Store:**
  - an AAB build in CI next to the APK;
  - store listing assets generated by DevTools (screenshots, feature graphic);
  - the data-safety form and content rating.

  This needs your Play Console account, which costs $25 once.
- [ ] **Quality bar:**
  - zero errors or warnings in the headless import;
  - all tests green in CI on every push;
  - a crash-free 2-hour soak test (bot at 4× speed);
  - checked on a small (5"), large (6.8") and tablet screen;
  - Android 7 through 16.
- [ ] **Store-ready copy, icon and screenshots**, plus a press-kit page.

---

## Engineering foundations (runs alongside every milestone)

- [ ] **CI on every push:** headless import, `sim_test`, `playtest` (3 countries) and theme/icon regeneration checks. Tags still release.
- [ ] **Visual regression tests:** DevTools screenshots of 8 key screens compared against golden images (per-pixel tolerance) on a Linux runner using software OpenGL.
- [ ] **Save schema versioning and migrations** (`SAVE_VERSION` 2+), with a migration test that loads old fixture saves.
- [ ] **Refactor `game.gd`** into `Calendar`, `EventDirector`, `Elections` and `WorldAI` modules. Keep `sim/economy.gd` as the single home for constants.
- [ ] **Balance tooling:** `tools/balance_report` runs 100 seeded games per difficulty and outputs win rates, average approval paths and how often each event fires, so tuning is driven by data.
- [ ] **Performance HUD** (dev only): frame time graph, draw calls and memory, toggled by a three-finger tap.

---

## Recommended order and why

1. **v0.2 Feel.** Unverified gestures and no sound are the two biggest gaps from "premium".
2. **v0.3 Understand.** Being able to read cause and effect is what makes a sim addictive instead of opaque.
3. **v0.4 Depth.** Laws, blocs and events turn levers into decisions and give a reason to replay.
4. **v0.5 Delight.** The memorable moments people share.
5. **v0.6 Reach**, then **v0.7 Cloud**, then **v1.0 Ship.**

---

## Decisions needed from you

1. **Audio:** are curated CC0 tracks and sound effects OK (licences tracked), or do you want original compositions?
2. **Flags:** add real country flags (flag-icons, MIT)? Recommended.
3. **Conflict:** keep security abstract and calm (recommended), or add war mechanics?
4. **Play Store:** publish at 1.0 (needs your $25 Play Console account), or stay GitHub-only?
5. **Languages:** which go first? Suggested: Hindi, Spanish, Portuguese.
6. **Monetization:** none (recommended), or an optional "supporter" tip later?
