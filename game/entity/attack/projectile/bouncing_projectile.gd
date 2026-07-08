extends Projectile

@export var bounce_margin := 8.0
@export var max_bounces: int = 999
var _bounces: int = 0

func _process_hit(where: Vector2, what: Entity) -> void:
	var normal: Vector2 = ray_detectors[0].get_collision_normal()
	if what or normal.is_zero_approx() or max_bounces == _bounces:
		if multiplayer.is_server():
			destroy.rpc(where, not what)
		else:
			destroy(where, not what)
		return
	
	var remainder: float = where.distance_to(global_position)
	direction = direction.bounce(normal)
	rotation = direction.angle()
	global_position = where + (remainder + bounce_margin) * direction
	_bounces += 1
	
	var vfx: Node2D = hit_wall_vfx_scene.instantiate()
	vfx.position = where
	_vfx_parent.add_child(vfx)
