extends Interactible

@onready var _flag: Flag = get_parent()

func _can_player_interact(player: Player) -> bool:
	return not player.is_immune()


func _should_ignore_player(player: Player) -> bool:
	return is_instance_valid(_flag.player) or player.team == _flag.team
