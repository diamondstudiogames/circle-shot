extends Projectile


func _create_vfx(_where: Vector2, wall: bool) -> void:
	super(global_position, wall)
