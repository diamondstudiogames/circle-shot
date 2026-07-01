extends EventModifier


func _initialize() -> void:
	(event.get_node(^"UI/Main/PlayerUI/Controller/HealthBar") as CanvasItem).hide()


func _customize_player_server(player: Player) -> void:
	player.max_health = 1
