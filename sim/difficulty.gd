class_name Difficulty
extends RefCounted
## Three ways to play, picked when starting a game (stored in Game.difficulty).
##   relaxed    fewer and milder crises, friendlier world, easier elections
##   standard   the real numbers, as designed
##   realistic  more frequent, harsher crises and tougher voters
## Tuned with tools/balance_report (100 bot games per level).

const LEVELS := ["relaxed", "standard", "realistic"]
const TITLES := {"relaxed": "Relaxed", "standard": "Standard", "realistic": "Realistic"}
const BLURBS := {
	"relaxed": "Fewer crises, friendlier neighbours, forgiving voters.",
	"standard": "Real-world numbers. The intended experience.",
	"realistic": "Frequent shocks and tough voters. For experienced leaders.",
}

## Chance per month that a random event starts (when nothing else is pending).
const EVENT_CHANCE := {"relaxed": 0.08, "standard": 0.115, "realistic": 0.16}
## Multiplier on the harmful part of event effects (negative shocks and costs).
const SEVERITY := {"relaxed": 0.7, "standard": 1.0, "realistic": 1.35}
## Added to the approval needed to win a free election (Economy.WIN_*).
const ELECTION_SHIFT := {"relaxed": -6.0, "standard": 2.0, "realistic": 8.0}
## Added to every starting relation with the player.
const RELATION_SHIFT := {"relaxed": 8.0, "standard": 0.0, "realistic": -6.0}
## Starting treasury multiplier.
const TREASURY := {"relaxed": 2.0, "standard": 1.0, "realistic": 0.75}


static func level() -> String:
	var l := str(Game.difficulty)
	return l if l in LEVELS else "standard"


static func event_chance() -> float:
	return float(EVENT_CHANCE[level()])


static func severity() -> float:
	return float(SEVERITY[level()])


static func election_shift() -> float:
	return float(ELECTION_SHIFT[level()])


static func relation_shift() -> float:
	return float(RELATION_SHIFT[level()])


static func treasury_mult() -> float:
	return float(TREASURY[level()])
