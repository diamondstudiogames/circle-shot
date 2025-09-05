extends StandardMob


@onready var _weapon: Node2D = $Visual/Weapon/Sword
@onready var _weapon_anim: AnimationPlayer = $Visual/Weapon/Sword/AnimationPlayer
@onready var _attack: Attack = $Visual/Weapon/Sword/Attack

@onready var _hurt_anim: AnimationPlayer = $Visual/AnimationPlayer


func _process(_delta: float) -> void:
	if not is_disarmed():
		_weapon.rotation = _calculate_aim_angle()


func _shoot(direction := Vector2.RIGHT) -> void:
	_weapon_anim.play(&"attack")
	_weapon_anim.seek(0.0)
	block_turning()
	visual.scale.x = -1.0 if direction.x < 0.0 else 1.0
	_weapon.rotation = _calculate_aim_angle(direction)
	
	if multiplayer.is_server():
		_attack.damage_multiplier = damage_multiplier
		_attack.team = team
		_attack.who = id
		_attack.clear_exceptions()
	
	await _weapon_anim.animation_finished
	unblock_turning()


func _get_shoot_args() -> Array:
	return [entity_input.aim_direction]


func _health_changed(old_value: int, new_value: int) -> void:
	if old_value > new_value:
		_hurt_anim.play(&"hurt")
		_hurt_anim.seek(0.0)


func _disarmed() -> void:
	if _weapon_anim.is_playing():
		_weapon_anim.play(&"RESET")
