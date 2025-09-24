extends StandardMob


@export var projectile_scene: PackedScene
@export var spread := 3.0

@onready var _throw_pivot: Marker2D = $Visual/Weapon/ThrowPivot
@onready var _throw_point: Marker2D = $Visual/Weapon/ThrowPivot/ThrowPoint

@onready var _ammo_parent: Node2D = $Visual/Weapon/BloodyDaggers
@onready var _throw_ammo: Node2D = $Visual/Weapon/BloodyDaggers/ToThrow
@onready var _throw_ammo_anim: AnimationPlayer = \
		$Visual/Weapon/BloodyDaggers/ToThrow/AnimationPlayer


func _process(_delta: float) -> void:
	if not is_disarmed():
		_throw_pivot.rotation = _calculate_aim_angle()


func _shoot() -> void:
	_throw_ammo.show()
	var throw_anim: Animation = _throw_ammo_anim.get_animation(&"pre_throw")
	throw_anim.track_set_key_value(0, 1, _throw_ammo.to_local(_throw_pivot.global_position))
	_throw_ammo_anim.play(&"pre_throw")
	await _throw_ammo_anim.animation_finished
	
	block_turning()
	var angle: float = entity_input.aim_direction.angle()
	var post_throw_anim: Animation = _throw_ammo_anim.get_animation(&"throw")
	post_throw_anim.track_set_key_value(0, 0, _throw_ammo.to_local(_throw_pivot.global_position))
	post_throw_anim.track_set_key_value(0, 1, _throw_ammo.to_local(_throw_point.global_position))
	var parent_angle: float = _ammo_parent.rotation + _throw_ammo.rotation
	post_throw_anim.track_set_key_value(1, 1, _calculate_aim_angle() - parent_angle)
	_throw_ammo_anim.play(&"throw")
	await _throw_ammo_anim.animation_finished
	unblock_turning()
	
	_throw_ammo.hide()
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.position = _throw_point.global_position
	projectile.damage_multiplier = damage_multiplier
	projectile.rotation = angle + deg_to_rad(randf_range(-spread, spread))
	projectile.scale.y = -1 if projectile.rotation > PI / 2 or projectile.rotation < -PI / 2 else 1
	projectile.team = team
	projectile.who = id
	projectile.name += str(randi())
	_projectiles_parent.add_child(projectile, true)


func _disarmed() -> void:
	_throw_ammo_anim.process_mode = Node.PROCESS_MODE_DISABLED


func _armed() -> void:
	_throw_ammo_anim.process_mode = Node.PROCESS_MODE_INHERIT
