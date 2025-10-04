extends Attack


func safe_free() -> void:
	if multiplayer.is_server():
		queue_free()
