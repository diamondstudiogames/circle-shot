extends Attack


@export var shake_amplitude := 32.0
@export var fireball_scene: PackedScene
@export var big_shot_scene: PackedScene
@export var fireball_back_scene: PackedScene
@export var lightning_scene: PackedScene

@export var fireballs_count: int = 18
@export var big_shots_count: int = 10
@export var fireballs_circles_count: int = 3
@export var fireballs_circles_shift_per_spawn := 11.0
@export var lightnings_speed_scale := 1.0

var _fireballs_circles_angle := 0.0
@onready var _projectiles_parent: Node2D = get_tree().get_first_node_in_group(&"projectiles_parent")


func shake_camera(duration: float) -> void:
	(get_viewport().get_camera_2d() as SmartCamera).shake(shake_amplitude, duration, false)


func spawn_fireballs_back() -> void:
	if not multiplayer.is_server():
		return
	var angle_interval: float = PI * 2 / fireballs_count
	var base_angle: float = randf_range(0.0, angle_interval)
	for i: int in fireballs_count:
		var fireball: Projectile = fireball_back_scene.instantiate()
		fireball.position = global_position
		fireball.rotation = base_angle + angle_interval * i
		fireball.team = team
		fireball.who = who
		fireball.damage_multiplier = damage_multiplier
		fireball.name += str(randi())
		_projectiles_parent.add_child(fireball)


func spawn_circle_fireballs() -> void:
	if not multiplayer.is_server():
		return
	var angle_interval: float = PI * 2 / fireballs_circles_count
	for i: int in fireballs_circles_count:
		var fireball: Projectile = fireball_scene.instantiate()
		fireball.position = global_position
		fireball.rotation = _fireballs_circles_angle + angle_interval * i
		fireball.team = team
		fireball.who = who
		fireball.damage_multiplier = damage_multiplier
		fireball.name += str(randi())
		_projectiles_parent.add_child(fireball)
	_fireballs_circles_angle += deg_to_rad(fireballs_circles_shift_per_spawn)


func spawn_lightning_bolt() -> void:
	if not multiplayer.is_server():
		return
	var lightning: Attack = lightning_scene.instantiate()
	lightning.position = NavigationServer2D.map_get_random_point(
			get_world_2d().navigation_map, 1, false)
	lightning.damage_multiplier = damage_multiplier
	lightning.who = who
	lightning.team = team
	lightning.name += str(randi())
	lightning.scale = Vector2.ONE / lightnings_speed_scale
	(lightning.get_node(^"AnimationPlayer") as AnimationPlayer).speed_scale = lightnings_speed_scale
	_projectiles_parent.add_child(lightning)


func spawn_big_shots() -> void:
	if not multiplayer.is_server():
		return
	var angle_interval: float = PI * 2 / big_shots_count
	var base_angle: float = randf_range(0.0, angle_interval)
	for i: int in big_shots_count:
		var big_shot: Projectile = big_shot_scene.instantiate()
		big_shot.position = global_position
		big_shot.rotation = base_angle + angle_interval * i
		big_shot.team = team
		big_shot.who = who
		big_shot.damage_multiplier = damage_multiplier
		big_shot.name += str(randi())
		_projectiles_parent.add_child(big_shot)
