extends Attack

@export var fireball_scene: PackedScene
@export var fireballs_count: int = 8

func spawn_fireballs() -> void:
	if not multiplayer.is_server():
		return
	var angle_interval: float = PI * 2 / fireballs_count
	var base_angle: float = randf_range(0.0, angle_interval)
	for i: int in fireballs_count:
		var fireball: Projectile = fireball_scene.instantiate()
		fireball.position = global_position
		fireball.rotation = base_angle + angle_interval * i
		fireball.team = team
		fireball.who = who
		fireball.damage_multiplier = damage_multiplier
		fireball.name += str(randi())
		get_parent().add_child(fireball)


func safe_free() -> void:
	if multiplayer.is_server():
		queue_free()
