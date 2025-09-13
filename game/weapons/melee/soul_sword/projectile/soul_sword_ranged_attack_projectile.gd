extends Projectile


func _process_hit(_where: Vector2, what: Entity) -> void:
	if multiplayer.is_server():
		destroy.rpc(global_position, not what)
	else:
		destroy(global_position, not what)
