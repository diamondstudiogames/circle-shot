extends Gun

@export var bullets_in_shot: int = 6
var _interrupting_reload := false
var _reloading := false

func _physics_process(delta: float) -> void:
	super(delta)
	if multiplayer.is_server() and _reloading \
			and player.player_input.shooting and not _interrupting_reload:
		_interrupt_reload.rpc(ammo)


func reload() -> void:
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, ^":rotation", 0.0, to_aim_time)
	block_shooting()
	_anim.play(&"start_reload")
	
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"start_reload":
		unblock_shooting()
		return
	
	_reloading = true
	while ammo != ammo_per_load and ammo_in_stock > 0:
		_anim.play(&"reload")
		anim_name = await _anim.animation_finished
		if anim_name != &"reload":
			_reloading = false
			_interrupting_reload = false
			unblock_shooting()
			return
		
		ammo += 1
		ammo_in_stock -= 1
		
		if _interrupting_reload:
			break
	
	_reloading = false
	_interrupting_reload = false
	_anim.play(&"end_reload")
	anim_name = await _anim.animation_finished
	if anim_name != &"end_reload":
		unblock_shooting()
		return
	
	_anim.play(&"post_reload")
	_turn_tween = create_tween()
	_turn_tween.tween_method(_lerp_to_aim, 0.0, 1.0, to_aim_time)
	
	await _turn_tween.finished
	unblock_shooting()


@rpc("call_local", "authority", "reliable", 5)
func _interrupt_reload(current_ammo: int) -> void:
	_interrupting_reload = true
	ammo = current_ammo


func _create_projectile() -> void:
	for i: int in bullets_in_shot:
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.position = _shoot_point.global_position
		projectile.damage_multiplier = player.damage_multiplier
		projectile.rotation = player.entity_input.aim_direction.angle() \
				+ deg_to_rad(_calculate_spread() * (-1 + 2.0 / (bullets_in_shot - 1) * i)) \
				+ deg_to_rad(_calculate_recoil()) * signf(player.entity_input.aim_direction.x)
		projectile.team = player.team
		projectile.who = player.id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)
