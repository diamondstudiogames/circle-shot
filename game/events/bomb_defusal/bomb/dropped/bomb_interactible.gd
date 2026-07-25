extends Interactible


func _should_ignore_player(player: Player) -> bool:
	return player.team != Entity.Team.RED
