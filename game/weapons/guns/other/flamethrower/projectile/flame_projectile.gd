extends Projectile


func _process_hit(_where: Vector2, _what: Entity) -> void:
	direction = Vector2.ZERO
