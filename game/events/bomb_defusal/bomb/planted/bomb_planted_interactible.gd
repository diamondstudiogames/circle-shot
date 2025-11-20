extends Interactible


func _should_ignore_player(player: Player) -> bool:
	return player.team != 1


func _can_player_interact(player: Player) -> bool:
	return not player.player_input.shooting and not player.is_disarmed()
