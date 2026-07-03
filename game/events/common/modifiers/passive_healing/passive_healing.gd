extends EventModifier

var _passive_healing_scene: PackedScene = load("uid://doab10yvwt3ic")

func _customize_player_server(player: Player) -> void:
	player.add_child(_passive_healing_scene.instantiate())
