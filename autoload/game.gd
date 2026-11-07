extends Node
## Game session. (Phase 3 stub — the full simulation arrives in phase 4.)

signal started

var player := -1


func new_game(country_index: int) -> void:
	player = country_index
	started.emit()


func has_game() -> bool:
	return player >= 0
