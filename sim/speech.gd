class_name Speech
extends RefCounted
## Address the nation: once a year, a televised speech. You choose the message;
## how well it lands depends on press credibility and whether it matches what
## people see around them (economic optimism in a recession backfires; a call
## for calm works best when things are tense). State: Game.dip.speech_last.

const COOLDOWN := 12

## id -> {label, desc, icon}
const THEMES := {
	"hope": {"label": "Better days ahead", "desc": "Optimism about jobs and prosperity", "icon": "trending-up"},
	"unity": {"label": "One nation", "desc": "Calm, unity and respect for each other", "icon": "users"},
	"truth": {"label": "Hard truths", "desc": "Level with people about the problems", "icon": "scale"},
	"pride": {"label": "Stand tall in the world", "desc": "National pride and a firm line abroad", "icon": "flag"},
}


static func wait() -> int:
	var last := int(Game.dip.get("speech_last", -100))
	return maxi(0, last + COOLDOWN - Game.months_played)


## How well each theme fits right now (-1 badly .. +1 perfectly).
static func fit(theme: String) -> float:
	var c := Game.me()
	var b: Dictionary = c.base
	match theme:
		"hope":
			var econ := clampf((c.growth - 1.0) / 3.0, -1.0, 1.0) - clampf((c.unemployment - float(b.unemployment)) / 3.0, -1.0, 1.0) * 0.5
			return clampf(econ, -1.0, 1.0)
		"unity":
			return clampf((float(b.stability) - c.stability) / 12.0 + 0.3, -0.3, 1.0)
		"truth":
			var trouble := (c.debt_pct() - float(b.debt_pct)) / 25.0 + (c.inflation - float(b.inflation)) / 6.0 + (-c.growth) / 3.0
			return clampf(trouble, -0.4, 1.0)
		"pride":
			# Lands when there's a rival to stand up to; hollow otherwise.
			var r := Rivalry.rival()
			return 0.5 if r >= 0 and Game.relations[r] < 0.0 else 0.15
	return 0.0


## Gives the speech; returns {approval, stability, cred, line, fit}.
static func give(theme: String) -> Dictionary:
	var c := Game.me()
	var f := fit(theme)
	var trust := 0.6 + 0.8 * Press.credibility() / 100.0      # 0.6 .. 1.4
	var appr := 0.0
	var stab := 0.0
	var cred := 0.0
	match theme:
		"hope":
			appr = 3.0 * f * trust
			cred = -3.0 if f < 0.0 else 0.5
		"unity":
			stab = 3.0 * (0.4 + f) * trust
			appr = 0.8 * trust
		"truth":
			cred = 5.0
			appr = (-1.0 + 1.5 * f) * trust
			stab = 0.8
		"pride":
			appr = 1.5 * trust
			stab = 0.8
			if Rivalry.rival() >= 0:
				Diplomacy.change_relation(Rivalry.rival(), -4.0)
	c.shocks.approval = float(c.shocks.approval) + appr
	c.shocks.stability = float(c.shocks.stability) + stab
	Press.apply_cred(cred)
	Game.dip["speech_last"] = Game.months_played
	var line := ""
	if appr >= 2.0 or stab >= 2.5:
		line = "The speech lands beautifully. Commentators call it the best of your career."
	elif appr >= 0.5 or stab >= 1.0:
		line = "A steady, well-received speech."
	elif appr > -0.5:
		line = "Polite applause. Not many minds changed."
	else:
		line = "It falls flat: people can see the words don't match their lives."
	Game.add_feed("Address to the nation: %s" % line.to_lower().trim_suffix("."), "mic", "green" if appr >= 0.0 else "orange")
	Game.add_milestone("Addressed the nation: %s" % str(THEMES[theme].label).to_lower(), "mic", "accent")
	return {"approval": appr, "stability": stab, "cred": cred, "line": line, "fit": f}
