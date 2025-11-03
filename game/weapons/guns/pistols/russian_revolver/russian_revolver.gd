extends Gun


@export_range(0.0, 1.0, 0.01) var blank_chance := 0.5
@export var bonus_damage := 0.75
@export var self_damage: int = 9
@export var red_per_blank := 0.2
var _blank_shots: int = 0


func _can_use_additional_button() -> bool:
	return ammo > 0


func additional_button(blank := true) -> void:
	ammo -= 1
	block_shooting()
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, ^":rotation", 0.0, to_aim_time)
	
	_anim.play(&"self_shoot")
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"self_shoot":
		unblock_shooting()
		return
	
	var to_play: StringName
	if blank:
		_blank_shots += 1
		to_play = &"self_shoot_blank"
	else:
		_blank_shots = 0
		player.damage(self_damage)
		to_play = &"self_shoot_live"
	_update_blank_shots()
	
	_anim.play(to_play)
	anim_name = await _anim.animation_finished
	if anim_name != to_play:
		unblock_shooting()
		return
	
	_anim.play(&"post_self_shoot")
	_turn_tween = create_tween()
	_turn_tween.tween_method(_lerp_to_aim, 0.0, 1.0, to_aim_time)
	await _turn_tween.finished
	unblock_shooting()


func get_additional_button_args() -> Array:
	return [randf() < blank_chance]


func has_additional_button() -> bool:
	return true


func _shoot() -> void:
	super()
	_blank_shots = 0
	_update_blank_shots()


func _create_projectile() -> void:
	player.damage_multiplier *= (1.0 + bonus_damage * _blank_shots)
	super()
	player.damage_multiplier /= (1.0 + bonus_damage * _blank_shots)


func _update_blank_shots() -> void:
	($Visual/Base/Cylinder as CanvasItem).set_instance_shader_parameter(&"power",
			red_per_blank * _blank_shots)
