extends Interactible


func _should_ignore_player(player: Player) -> bool:
	return player.team != Entity.Team.BLUE


func _can_player_interact(player: Player) -> bool:
	return not player.player_input.shooting and player.can_use_weapon()
