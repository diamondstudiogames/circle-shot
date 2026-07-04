extends EventModifier

@export_range(1.0, 2.0, 0.01) var speed_multiplier := 1.25

func _customize_player(player: Player) -> void:
	player.speed_multiplier *= speed_multiplier
