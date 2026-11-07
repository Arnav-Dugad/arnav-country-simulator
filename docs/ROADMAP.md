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
6. **Respect the player.** No ads, dark patterns or tracking by default. Any paid item is clearly priced and optional.
7. **Effortless to use.** Plain words instead of jargon, one obvious next step on every screen, every control
   explained where it sits, and a guided first game. If a 12-year-old can't work it out in 10 seconds, simplify it.

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
- [x] **Rubber-band edges:** panning past the world gives soft resistance (0.35× drag) and springs back on release, instead of a hard stop.
- [x] **Zoom inertia:** a pinch-release carries a little zoom momentum (decays in about 180 ms), anchored at the pinch midpoint.
- [ ] **Two-finger tap** zooms out one level, and **long-press** on a country opens its sheet at half height with a haptic "select".
- [ ] **Smart framing:** `focus_country` avoids the top bar, mode control and open sheet using real measured insets.
- [ ] **120 Hz aware:** inertia uses real frame delta; tested at 60, 90 and 120 Hz.

### Map beauty
- [ ] **Ocean depth:** a subtle procedural depth gradient near coasts (distance field baked offline), plus a faint graticule (every 30°) that fades in at mid zoom.
- [ ] **Coastline light:** a 1 px inner highlight on land edges facing north-west, to suggest relief without textures.
- [x] **Capitals:** Natural Earth populated places (admin-0 capitals) as 3 pt dots with a soft halo, with labels from zoom ×4 and the player's capital in gold.
- [x] **Flags:** country flags from `flag-icons` 7.6.0 (MIT) as SVG DPITextures with rounded corners and a hairline edge, in the picker rows and footer, the country sheet header, the top bar (player) and the diplomacy list.
- [ ] **Distance-field player glow:** bake a signed-distance texture per country so the halo is perfectly smooth (replaces the outline-extruded glow, which still shows faint flares in very narrow inlets).
- [ ] **Label system v2:** keep labels clear of HUD rectangles, cross-fade between zoom bands (no popping), letter-spacing scaled to zoom, and two lines for long names ("United States / of America").
- [ ] **Selection feel:** a tap ripple at the touch point (expanding ring, 300 ms), and the raised country gets a soft 8 pt drop shadow tied to the zoom level.
- [ ] **Mode transitions:** a 450 ms colour crossfade with a legend that slides in under the mode control (gradient bar, min/max labels and the player's marker).

### Sound (new)
- [x] **Audio system** (`Audio` autoload) with a UI bus, an ambience bus and a music bus, Settings sliders, and auto-ducking when an event card opens.
- [x] **UI sound set** (about 12 sounds, under 60 ms, soft and pitched): tap, toggle on and off, sheet up and down, slider detent, success, warning, event chime, month tick (very quiet, optional), election drumroll and result.
- [x] **Ambient music:** 2–3 calm loops (piano and pads) with seamless crossfades. CC0 or original only, with licences recorded in `assets/audio/LICENSES.md`.
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
- [x] The simulation records each term's **contribution** per tick (growth = trend + fiscal − taxes − rates ± events …) in a small ring buffer.
- [x] Tapping any stat tile opens an **explainer sheet**: a waterfall chart (custom `_draw`) of contributors, sorted by size, coloured good or bad, with one plain-English line each ("Higher interest rates are cooling the economy: −0.6 pts").

### Live forecast while you decide
- [x] Dragging a slider runs a **12-month projection** on a cloned `CountryState` (12 ticks of one country takes under 1 ms), throttled to 20 Hz.
- [x] Under the slider, **delta chips** show the projected effect, for example `Growth −0.4`, `Approval −1.2`, `Revenue +$12B`, coloured by good or bad.
- [ ] On the open chart, a **dashed ghost line** shows the projected path next to history.

### Charts 2.0
- [x] Scrubbing with a finger shows a crosshair and a value bubble that snaps to months, with haptic ticks at year boundaries.
- [ ] A time-range control (1Y, 5Y, All).
- [ ] An overlay to compare against the world median or the starting value.
- [ ] Events on the timeline: small dots on the chart where events happened, tappable to see what you chose.

### Briefings and advisors
- [x] **Monthly briefing:** three generated headlines from the biggest changes ("Inflation falls to 3.1%, its lowest since 2026"), shown as a quiet banner that can be swiped away.
- [ ] **Cabinet advisors** (opt-in): Finance, Central Bank, Foreign Affairs and Interior. Each gives one short, contextual suggestion with a confidence level ("Rates look high for current inflation: consider −0.5 pts"). Never more than one at a time.
- [x] **World rankings:** your rank by GDP, GDP per person, happiness and stability, with a sortable "World" list.
- [ ] **Compare:** you against any country side by side (two columns of tiles), opened from the country sheet.

**Definition of done:** a new player can answer "why did my approval drop?" in two taps.

---

## v0.4 "Depth": richer, still simple  *(priority: high, effort: L)*

### Laws and reforms (policy cards)
- [x] (16 laws shipped in v0.3.0; more to come) About **30 laws** in 7 groups:
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
- [x] (campaign themes + election night shipped in v0.5.0; voter blocs still to do) **Elections 2.0:**
  - **Campaign:** in the final 3 months, pick two themes (Economy, Security, Healthcare, Change, and so on). Themes boost the blocs they appeal to.
  - **Result:** an animated election-night sheet with bloc bars filling and the vote share counting up.

### Events 2.0
- [x] (36 events in v0.4.0, with chains, regional and oil events) **60+ events**, including:
  - **story chains** (pandemic → vaccine race → recovery boom; scandal → inquiry → resignation);
  - **regional flavour** (monsoon floods in South Asia, hurricanes in the Caribbean, heatwaves in Southern Europe, oil-price swings for producers);
  - **data-driven conditions** (oil exporters from World Bank fuel-export share, coastal states, ageing countries).
- [ ] Each event has a short illustration: a monochrome Lucide-style vector drawn in our own SVG style.
- [x] Every choice shows its **expected effects** as chips (honest, rounded, with uncertainty where randomness applies).

### Economy and society depth (still one screen each)
- [x] **Credit rating** (AAA to D) from debt, deficit, stability and growth. It drives borrowing costs, shows as a badge in the top bar, and downgrades trigger an event.
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
- [x] **Legacy score** at the end of a term (grade A+ to F) from growth, well-being, stability, debt and elections, with a breakdown.
- [ ] **Difficulty:** Relaxed, Standard or Realistic, affecting election thresholds, event severity, AI hostility and political capital income.

**Definition of done:** a full playthrough where at least one event chain, one reform and one treaty happen, and the bot playtest still reports zero errors.

---

## v0.5 "Delight": premium presentation  *(priority: high, effort: M)*

- [x] **Home screen:** a resume card ("Continue as India · Mar 2031") over the slowly drifting map, with save slots showing **map thumbnails** captured at save time.
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
- [x] **Text size** at 85, 100, 115 or 130%, regenerating theme sizes at runtime with layouts verified at each size.
- [x] **Colour-blind palettes** for data modes (Okabe-Ito and cividis), checked in a deuteranopia simulation.
- [x] **Reduce transparency:** solid panels instead of glass (also faster on low-end phones).
- [ ] **English only** (decided). Still route strings through one place so wording can be polished, and offer an optional **lakh/crore** number format.
- [ ] **Tablets and landscape:** a two-pane layout with the sheet as a right-side panel, plus foldable-aware insets.
- [ ] **Low-end mode**, auto-detected: 4-sample glass, the low-detail map only, and no glow pulse.

---

## v0.7 "Cloud and community"  *(priority: medium, effort: M)*

- [ ] **Save conflict sheet** ("This device · Mar 2031" vs "Cloud · Jan 2032"), letting the player pick and keep both.
- [ ] **In-app account deletion** (good practice): deletes Firestore data then the Auth user.
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

- [ ] **GitHub-only distribution** (decided): signed APK releases plus the in-app updater. No Play Store.
- [ ] **Quality bar:**
  - zero errors or warnings in the headless import;
  - all tests green in CI on every push;
  - a crash-free 2-hour soak test (bot at 4× speed);
  - checked on a small (5"), large (6.8") and tablet screen;
  - Android 7 through 16.
- [ ] A polished GitHub Pages site (download button, screenshots, privacy policy).

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

## Decisions (2026-11-07)

| Topic | Decision |
|---|---|
| Audio | Free-to-use (CC0 / permissive) music and sound effects, licences tracked |
| Flags | Real country flags (flag-icons, MIT) |
| Conflict | Abstract and calm for now (no war mechanics) |
| Distribution | GitHub only (no Play Store) |
| Languages | English only |
| Accounts | **Always ask to create an account on first launch** (onboarding step; "Not now" plays as a backed-up guest) |
| Monetization | **Demo store** built from a genre study (docs/MONETIZATION.md): content packs, cosmetic map themes, Statesman Pass, supporter tips, Complete Edition. Real prices, simulated purchases, no dark patterns |
| UX | **Very easy to use and understand** is now a core pillar (principle 7) |

### Monetization (honest options only)
No hidden pricing, pressure timers, made-to-fail difficulty or confusing currencies. GitHub-only means no Play Billing,
and Firebase Spark can't verify purchases server-side, so:
- **Supporter tip jar:** an external link (Ko-fi, GitHub Sponsors or Razorpay) with a cosmetic thank-you (gold map theme and badge).
- **Premium pack:** only if the game ever moves to a store with real billing.

## "Easy to use" workstream (added to v0.2 and v0.3)
- [ ] **Plain-language pass on every label:** "Interest rate" gets the helper "Higher = slower prices, fewer jobs";
      "Debt / GDP" becomes "Debt (vs. economy size)"; jargon moves into an info sheet.
- [x] **(i) button on every control,** opening a 2-line explanation plus a tiny illustration.
- [x] **Guided first game:** coach marks for the first three months, one task at a time, with checkmarks.
- [ ] **"What should I do?" button:** shows the single most impactful suggestion right now.
- [ ] **Health summary:** one colour ring (Thriving, Okay, Struggling) on the top bar, tappable for the top 3 problems.
- [ ] **Bigger, fewer targets:** every tap target at least 44 pt, max 5 items per row, no hidden gestures without a visible alternative.
- [x] **Undo:** the last policy change can be undone within the same month.
