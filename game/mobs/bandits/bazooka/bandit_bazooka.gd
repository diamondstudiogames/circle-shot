extends StandardMob


@export var projectile_scene: PackedScene
@export var spread := 3.0

@onready var _weapon: Node2D = $Visual/Weapon/Bazooka
@onready var _weapon_parent: Node2D = $Visual/Weapon
@onready var _shoot_point: Marker2D = $Visual/Weapon/Bazooka/ShootPoint
@onready var _weapon_anim: AnimationPlayer = $Visual/Weapon/Bazooka/AnimationPlayer


func _process(_delta: float) -> void:
	if not is_disarmed():
		_update_weapon()


func _shoot() -> void:
	_update_weapon()
	_weapon_anim.play(&"shoot")
	_weapon_anim.seek(0.0)
	
	if multiplayer.is_server():
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.position = _shoot_point.global_position
		projectile.damage_multiplier = damage_multiplier
		projectile.rotation = entity_input.aim_direction.angle() \
				+ deg_to_rad(randf_range(-spread, spread))
		projectile.team = team
		projectile.who = id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)


func _disarmed() -> void:
	_weapon_anim.pause()


func _armed() -> void:
	_weapon_anim.play()


func _update_weapon() -> void:
	_weapon.rotation = _calculate_aim_angle()
	_weapon.position = Gun.calculate_gun_position(_weapon.rotation,
			_shoot_point.position.y, _weapon_parent.position)
