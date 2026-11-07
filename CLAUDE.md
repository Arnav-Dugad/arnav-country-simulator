# Arnav Country Simulator — project guide

Realistic-but-simple country simulator for Android. The main UI is an interactive
world map. Design language: Apple-like, premium, calm (glass, soft motion).

## Stack (fixed)
- **Godot 4.7.2**, **GDScript only** (no C#). Editor binary: `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`
- **Android-first, portrait.** Base viewport 390×844 logical points, stretch `canvas_items`, aspect `expand`.
- **Compatibility renderer** (`gl_compatibility`) on all platforms.
- Firebase via REST only (Spark plan: Auth + Firestore). No Cloud Functions.
- Android plugin (updater): Godot v2 plugin format, Kotlin, built with Gradle.

## Folder structure
```
autoload/      Global singletons (Settings, Haptics, Screen, Router, DevTools, GameState …)
sim/           Simulation. ALL formulas + tweakable constants live in sim/economy.gd
map/           World map rendering, camera/gestures, map modes, labels
ui/theme/      tokens.gd (DS class: colors, radii, spacing, type, motion) + generated main_theme.tres
ui/shaders/    glass.gdshader, ocean.gdshader, map shaders
ui/components/ Reusable widgets: GlassPanel, AppButton, BottomSheet, LineChart, AnimatedNumber …
ui/screens/    Full screens (splash, onboarding, country picker, game, game over)
ui/sheets/     Bottom-sheet contents (economy, budget, diplomacy, events, settings, country)
services/      firebase.gd, cloud_sync.gd, save_manager.gd, updater.gd, store.gd (DEMO store); firebase_config.gd
data/          Generated data (world_map.res, countries.json) + SOURCES.md
assets/        fonts/ (Inter, OFL), icons/ (Lucide, ISC), branding/ (icon.svg + exports)
tools/         Offline build scripts (Python + Godot --script tools). Not shipped logic.
android/       Kotlin plugin source;  addons/ holds the packaged plugin
.github/       Release workflow (tag v* → signed APK → GitHub Release)
```

## Commands
```bash
G=/c/Godot/Godot_v4.7.2-stable_win64_console.exe
$G --headless --path . --import                                   # import + check
$G --headless --path . --script res://tools/build_theme.gd        # regenerate theme
$G --headless --path . --script res://tools/export_icons.gd       # regenerate app icons
$G --headless --path . --quit-after 400                           # smoke-run main scene
$G --path . -- --scene=res://ui/screens/x.tscn --shot=C:/tmp/x.png --shot-delay=2   # screenshot
```
DevTools user args (after `--`): `--scene=`, `--shot=`, `--shot-delay=`, `--size=WxH`, `--click=x,y;x,y` (window px), `--click-delay=`, game screen: `--open=<page> --scroll=<px>`, `--advance=<months>`, `--event=<id>`, `--campaign`, `--election`.

## Coding conventions
- Static typing everywhere (`var x: int`, `:=`, typed returns). Tabs for indentation.
- `class_name` for reusable components; `snake_case` files; `PascalCase` classes; signals past tense.
- Build UI in code or minimal `.tscn` (root node + script). Never hand-edit `main_theme.tres`.
- **No one-off styling.** Use `theme_type_variation` (Title, Headline, Body, Caption, PrimaryButton,
  Chip, GlassPanel, GlassSheet, …). New styles → add to `tools/build_theme.gd`, re-run it.
- Colors/radii/durations come from `DS` (ui/theme/tokens.gd). No magic hex values in UI code.
- Motion via Tweens: `DS.ease_out(tween)` (default) or `DS.spring(tween)`; 0.25–0.4 s.
  Wrap durations in `Settings.dur()` so "Reduce motion" works.
- Haptics only through the `Haptics` autoload. Safe-area insets only through `Screen`.
- Simulation constants: only in `sim/economy.gd`, documented.
- Every phase: run headless import + smoke run, fix all errors/warnings, then commit.
- **Touch & scrolling:** controls inside scroll views use MOUSE_FILTER_PASS and decide direction after an 8 px slop (vertical = let the ScrollContainer scroll). Never use STOP + accept_event on press. Guarded by tools/scroll_test (CI, xvfb).
- **Laptop resources:** do not use the emulator or run local APK/Gradle exports; push a tag and let CI build.

## Design system
- **Glass**: `GlassPanel` (PanelContainer) = theme stylebox (soft shadow, radius, padding) + internal
  ColorRect with `glass.gdshader` (screen-texture blur via `filter_linear_mipmap` + 12-tap disc,
  tint, vibrancy, grain, 15 % white rim). Variants: GlassPanel, GlassSheet, GlassBar, GlassCard, GlassPill.
- **Radius**: panels/sheets 28, cards 20, buttons 16, fields 14, chips/pills fully rounded.
- **Type** (Inter variable, OFL): LargeTitle 34/700/-1, Title 28/700/-1, Title2 22/650, Headline 17/600,
  Body 16/400, Subhead 15/500, Footnote 13, Caption 12. StatValue uses tabular numerals.
- **Color**: dark deep-ocean background; iOS dark system colors (ACCENT #0A84FF, GREEN, RED, ORANGE…);
  text white / 66 % / 38 %.
- **Icons**: Lucide (ISC), recolored white, imported as **DPITexture** (crisp at any density); tint via theme icon colors.
  No emojis anywhere.
- **Layout**: full-screen map; floating glass top bar (date, speed, treasury); floating glass dock
  (Economy, Budget, Diplomacy, Events, Settings); bottom sheets with handle + snap (peek/half/full).
- Respect safe areas (`Screen.top/bottom/left/right`).
- **Anchors:** always use `set_anchors_and_offsets_preset()`. Plain `set_anchors_preset()` on a node already in the tree keeps its old (often zero) size.

## Android, releases & services
- Export presets: **Android** (release, arm64, compressed native libs) and **Android Dev** (debug, arm64+x86_64 for the emulator).
  Gradle build needs JDK 17 (`C:\Users\rduga\.jdks\jdk-17.0.21+9`); set `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true` locally (IPv6 times out).
- Release keystore lives OUTSIDE the repo: `C:\Users\rduga\.keystores\arnav-country-simulator\` (alias `acs-release`). Never commit it.
- CI: push tag `vX.Y.Z` → `.github/workflows/release.yml` stamps version (versionCode = X*10000+Y*100+Z), exports a signed APK,
  publishes a GitHub Release with the matching CHANGELOG.md section. Secrets: ANDROID_KEYSTORE_BASE64 / _ALIAS / _PASSWORD.
- Updater plugin (Kotlin, Godot v2): `android/plugin` → `android/plugin/build_plugin.sh` → `addons/acs_updater/bin/*.aar`.
- Firebase (Spark): config in `services/firebase_config.gd` (empty = offline mode); rules in `firestore.rules`.
- The Android emulator may be shared with other projects/sessions — never kill processes by image name, only by PID.
- **Static factories:** never name a script's own `class_name` inside its static functions (e.g. `static func make() -> Foo: Foo.new()` in foo.gd when other scripts reference it). It creates a script reference cycle that leaks at exit; load by path instead.
