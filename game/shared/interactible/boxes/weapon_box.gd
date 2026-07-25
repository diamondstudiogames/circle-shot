extends Node2D


func _on_despawn_timer_timeout() -> void:
	($"../AnimationPlayer" as AnimationPlayer).play(&"despawn")
	if multiplayer.is_server():
		await ($"../AnimationPlayer" as AnimationMixer).animation_finished
		get_parent().queue_free()
