extends EventModifier


func _customize_player_server(player: Player) -> void:
	player.equip_data[3] = -1
