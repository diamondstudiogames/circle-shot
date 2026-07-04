extends EventModifier

@export var heal_box_scene: PackedScene

func _customize_player_server(player: Player) -> void:
	player.died.connect(_on_player_died, CONNECT_APPEND_SOURCE_OBJECT)


func _on_player_died(player: Player) -> void:
	var heal_box: Node2D = heal_box_scene.instantiate()
	heal_box.position = player.global_position
	get_tree().get_first_node_in_group(&"other_parent").add_child(heal_box)
