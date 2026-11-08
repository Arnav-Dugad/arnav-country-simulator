class_name DS
extends RefCounted
## Design-system tokens — the single source of truth for color, radius, spacing,
## type and motion. The Theme (main_theme.tres) is generated from these values by
## tools/build_theme.gd; components read motion/color tokens from here directly.

# ---------------------------------------------------------------- Color ------
const OCEAN_TOP := Color("0c1b30")
const OCEAN_BOTTOM := Color("030812")
const LAND := Color("26324a")
const LAND_DIM := Color("1b2436")
const BORDER := Color(0.78, 0.86, 1.0, 0.22)

const ACCENT := Color("0a84ff")
const ACCENT_SOFT := Color("4da3ff")
const GREEN := Color("30d158")
const RED := Color("ff453a")
const ORANGE := Color("ff9f0a")
const YELLOW := Color("ffd60a")
const TEAL := Color("64d2ff")
const PURPLE := Color("bf5af2")
const GOLD := Color("f2c86b")

const TEXT := Color(1, 1, 1, 1)
const TEXT_2 := Color(0.92, 0.93, 0.97, 0.72)
const TEXT_3 := Color(0.92, 0.93, 0.97, 0.5)
const SEPARATOR := Color(1, 1, 1, 0.09)
const FILL := Color(1, 1, 1, 0.08)
const FILL_2 := Color(1, 1, 1, 0.13)
const FILL_3 := Color(1, 1, 1, 0.04)

const GLASS_TINT := Color(0.075, 0.09, 0.13, 0.62)
const GLASS_TINT_STRONG := Color(0.06, 0.075, 0.11, 0.74)
const GLASS_BORDER_OPACITY := 0.15
const SHADOW := Color(0, 0, 0, 0.38)

# --------------------------------------------------------------- Radius ------
const R_PANEL := 28
const R_CARD := 20
const R_BUTTON := 16
const R_FIELD := 14
const R_PILL := 999

# -------------------------------------------------------------- Spacing ------
## 4-pt grid.
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 20
const S6 := 24
const S8 := 32
const MIN_TOUCH := 44

# ----------------------------------------------------------- Typography ------
## iOS-style scale, in logical points (viewport is 390 pt wide).
const FS_LARGE_TITLE := 34
const FS_TITLE := 28
const FS_TITLE_2 := 22
const FS_HEADLINE := 17
const FS_BODY := 16
const FS_SUBHEAD := 15
const FS_FOOTNOTE := 13
const FS_CAPTION := 12

# --------------------------------------------------------------- Motion ------
const DUR_FAST := 0.25
const DUR := 0.32
const DUR_SLOW := 0.4
const PRESS_SCALE := 0.95


## Smooth, spring-like ease-out (no overshoot). Use for most motion.
static func ease_out(t: Tween) -> Tween:
	return t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Gentle overshoot for playful "settle" moments (press release, pop-ins).
static func spring(t: Tween) -> Tween:
	return t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func icon(icon_name: String) -> Texture2D:
	var path := "res://assets/icons/%s.svg" % icon_name
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("DS.icon: missing icon '%s'" % icon_name)
	return null


## Formats large numbers compactly: 1.2K, 3.4M, 5.6B, 7.8T.
static func compact(v: float, decimals: int = 1) -> String:
	var a := absf(v)
	var s := ""
	if a >= 1e18:
		# Runaway sandbox economies: scientific notation keeps it short.
		var e := int(floor(log(a) / log(10.0)))
		s = String.num(v / pow(10.0, e), 1) + "e" + str(e)
	elif a >= 1e15:
		s = String.num(v / 1e15, decimals) + "Q"
	elif a >= 1e12:
		s = String.num(v / 1e12, decimals) + "T"
	elif a >= 1e9:
		s = String.num(v / 1e9, decimals) + "B"
	elif a >= 1e6:
		s = String.num(v / 1e6, decimals) + "M"
	elif a >= 1e3:
		s = String.num(v / 1e3, decimals) + "K"
	else:
		s = String.num(v, 0 if a >= 100 else decimals)
	return s


static func money(v: float, decimals: int = 1) -> String:
	return ("-$" if v < 0 else "$") + compact(absf(v), decimals)


static func pct(v: float, decimals: int = 1, signed: bool = false) -> String:
	var s := String.num(v, decimals) + "%"
	return ("+" + s) if signed and v > 0 else s
