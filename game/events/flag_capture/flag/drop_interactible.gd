extends Interactible

@onready var _flag: Flag = get_parent()

func _should_ignore_player(player: Player) -> bool:
	return player != _flag.player
