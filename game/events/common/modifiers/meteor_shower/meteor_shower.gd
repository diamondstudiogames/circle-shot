extends EventModifier

@export var meteor_scene: PackedScene

func _initialize() -> void:
	if multiplayer.is_server():
		($Timer as Timer).start()


func _spawn_meteor() -> void:
	var game_zone: Rect2 = event.get_game_zone()
	var meteor: Attack = meteor_scene.instantiate()
	meteor.position = game_zone.get_center() \
			+ game_zone.size * Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	meteor.name += str(randi())
	get_tree().get_first_node_in_group(&"other_parent").add_child(meteor, true)


func _on_timer_timeout() -> void:
	_spawn_meteor()
