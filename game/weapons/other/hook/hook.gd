extends Weapon


enum State {
	IDLE = 0,
	THROW = 1,
	ATTRACT = 2,
	RESET = 3,
	RELOAD = 4,
	NO_AMMO = 5,
}

@export var hook_speed := 1600.0
@export var attract_speed := 1280.0
@export var min_distance := 168.0
@export var reset_speed := 3200.0
@export var min_reset_time := 0.2
@export var additional_stun_time := 1.0
@export var aim_time := 0.15

var _state := State.IDLE
var _attracting_enemy := false
var _throw_direction := Vector2.RIGHT
var _target: Entity
var _target_hook_offset: Vector2
var _target_position: Vector2
var _previous_knockback := Vector2.ZERO

var _previous_physics_hook_position: Vector2
var _reset_tween: Tween
var _attract_user_texture: Texture2D = load("uid://dqqohrw8x4ie4")
var _attract_enemy_texture: Texture2D = load("uid://drf8asi0s3yc1")

@onready var _hook: Sprite2D = $Visual/Hook
@onready var _chain: Line2D = $Visual/Chain
@onready var _visual: Node2D = $Visual
@onready var _aim: Line2D = $Aim
@onready var _anim: AnimationPlayer = $AnimationPlayer

@onready var _ray_cast: RayCast2D = $Visual/Hook/RayCast2D
@onready var _reset_point: Marker2D = $Visual/ResetPoint
@onready var _reload_timer: Timer = $ReloadTimer
@onready var _throw_timer: Timer = $ThrowTimer
@onready var _attract_timer: Timer = $AttractTimer
@onready var _sync_position_timer: Timer = $SyncPositionTimer


func _physics_process(delta: float) -> void:
	if can_shoot() and multiplayer.is_server() and player.player_input.shooting \
			and ammo_in_stock > 0 and _state == State.IDLE:
		shoot(player.entity_input.aim_direction)
	
	_previous_physics_hook_position = _hook.global_position
	match _state:
		State.THROW:
			_hook.global_position += hook_speed * delta * _throw_direction
			if _ray_cast.is_colliding():
				var entity := _ray_cast.get_collider() as Entity
				if entity and entity.team == player.team:
					_ray_cast.add_exception(entity)
					return
				
				var success := true
				if _attracting_enemy:
					if entity:
						_target = entity
						_target_hook_offset = entity.global_position - _hook.global_position
					else:
						success = false
				else:
					_target = null
					_target_position = _ray_cast.get_collision_point()
				
				if is_instance_valid(entity):
					if entity.global_position.distance_to(player.global_position) <= min_distance:
						success = false
				elif player.global_position.distance_to(_target_position) <= min_distance:
					success = false
				
				if success:
					ammo_in_stock -= 1
					_state = State.ATTRACT
					_throw_timer.stop()
					_attract_timer.start()
					if is_instance_valid(_target):
						if multiplayer.is_server():
							_target.add_timeless_effect.rpc(Effect.STUN)
					else:
						if multiplayer.is_server():
							player.add_timeless_effect.rpc(Effect.IMMOBILITY)
				else:
					_reset_throwing()
		
		State.ATTRACT:
			if _attracting_enemy:
				if is_instance_valid(_target):
					_target.knockback -= _previous_knockback
					_previous_knockback = attract_speed \
							* _target.global_position.direction_to(player.global_position)
					_target.knockback += _previous_knockback
					_hook.global_position = _target.global_position - _target_hook_offset
					if player.global_position.distance_to(_target.global_position) <= min_distance:
						_reset_attraction()
				else:
					_reset_attraction()
			else:
				player.knockback -= _previous_knockback
				_previous_knockback = attract_speed \
							* player.global_position.direction_to(_target_position)
				player.knockback += _previous_knockback
				if player.global_position.distance_to(_target_position) <= min_distance:
					_reset_attraction()
			_hook.rotation = player.global_position.angle_to_point(_hook.global_position)


func _process(_delta: float) -> void:
	_aim.hide()
	
	if can_shoot():
		_aim.visible = player.player_input.showing_aim
		_aim.rotation = _calculate_aim_angle()
	
	_chain.visible = _state in [State.ATTRACT, State.THROW, State.RESET]
	if _chain.visible:
		_chain.points[1] = _chain.to_local(_previous_physics_hook_position.lerp(
				_hook.global_position, Engine.get_physics_interpolation_fraction()))


func _exit_tree() -> void:
	if _state == State.ATTRACT:
		_reset_attraction(true)
	_reload_timer.queue_free()


func _initialize() -> void:
	_previous_physics_hook_position = _hook.global_position
	_reload_timer.name += name
	_reload_timer.reparent(player)


func _shoot(direction := Vector2.RIGHT) -> void:
	block_shooting()
	player.block_turning()
	player.visual.scale.x = -1.0 if direction.x < 0 else 1.0
	
	var tween: Tween = create_tween()
	tween.tween_property(_visual, ^":rotation", _calculate_aim_angle(direction), aim_time)
	
	_anim.play(&"throw")
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"throw":
		player.unblock_turning()
		unblock_shooting()
		if is_instance_valid(tween):
			tween.kill()
		return
	
	var prev_hook_pos: Vector2 = _hook.global_position
	_hook.top_level = true
	_hook.z_index = -1
	_hook.global_position = prev_hook_pos
	_hook.rotation = direction.angle()
	_hook.scale.y = -1 if _hook.rotation > PI / 2 or _hook.rotation < -PI / 2 else 1
	_hook.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_hook.reset_physics_interpolation()
	_visual.rotation = 0.0
	
	_ray_cast.enabled = true
	_ray_cast.add_exception(player)
	_throw_direction = direction
	_state = State.THROW
	_throw_timer.start()
	if multiplayer.is_server():
		_sync_position_timer.start()


func _make_current() -> void:
	_anim.play(&"equip")
	_anim.advance(0.0)
	if _state == State.IDLE:
		block_shooting()
		await _anim.animation_finished
		unblock_shooting()


func _unmake_current() -> void:
	_anim.play(&"RESET")
	_anim.advance(0.01)
	if is_instance_valid(_reset_tween):
		_reset_tween.finished.emit()
		_reset_tween.kill()
	match _state:
		State.ATTRACT:
			_attract_timer.stop()
			_reset_attraction(true)
		State.THROW:
			_throw_timer.stop()
			_reset_throwing(true)


func _can_reload() -> bool:
	return false


func _player_disarmed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_DISABLED
	_reload_timer.paused = true
	match _state:
		State.ATTRACT:
			_attract_timer.stop()
			_reset_attraction()
		State.THROW:
			_throw_timer.stop()
			_reset_throwing()


func _player_armed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_INHERIT
	_reload_timer.paused = false


func _ammo_changed(in_stock: bool) -> void:
	if not in_stock:
		return
	if _state == State.NO_AMMO and ammo_in_stock > 0:
		_state = State.IDLE
		unblock_shooting()
		_hook.self_modulate = Color.WHITE


func has_additional_button() -> bool:
	return true


func additional_button() -> void:
	_attracting_enemy = not _attracting_enemy
	_hook.texture = _attract_enemy_texture if _attracting_enemy else _attract_user_texture


func get_ammo_text() -> String:
	return "Осталось: %d" % ammo_in_stock


@rpc("call_remote", "authority", "unreliable_ordered", 5)
func _sync_hook_position(pos: Vector2) -> void:
	if not _state in [State.THROW, State.ATTRACT]:
		return
	_hook.position = pos


func _reset_throwing(skip_animation := false) -> void:
	_throw_timer.stop()
	await _reset_common(skip_animation)
	_state = State.IDLE
	unblock_shooting()


func _reset_attraction(skip_animation := false) -> void:
	if is_instance_valid(_target):
		_target.knockback -= _previous_knockback
		if multiplayer.is_server():
			_target.add_effect.rpc(Effect.STUN, additional_stun_time)
			_target.remove_timeless_effect.rpc(Effect.STUN)
		_target = null
	else:
		player.knockback -= _previous_knockback
		if multiplayer.is_server():
			player.remove_timeless_effect.rpc(Effect.IMMOBILITY)
	
	_previous_knockback = Vector2.ZERO
	_attract_timer.stop()
	await _reset_common(skip_animation)
	_state = State.RELOAD
	_hook.self_modulate = Color.GRAY
	_reload_timer.start()


func _reset_common(skip_animation: bool) -> void:
	if multiplayer.is_server():
		_sync_position_timer.stop()
	_ray_cast.enabled = false
	_ray_cast.clear_exceptions()
	_hook.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hook.z_index = 0
	if not skip_animation:
		_state = State.RESET
		_reset_tween = create_tween()
		_reset_tween.set_ease(Tween.EASE_IN_OUT)
		_reset_tween.set_trans(Tween.TRANS_QUAD)
		_reset_tween.tween_method(
				_lerp_to_reset.bind(_hook.global_position, _hook.rotation), 0.0, 1.0,
				maxf(global_position.distance_to(_hook.global_position) / reset_speed,
				min_reset_time)
		)
		await _reset_tween.finished
	_hook.top_level = false
	_hook.position = _reset_point.position
	_hook.rotation = 0.0
	_hook.scale.y = 1
	player.unblock_turning()


func _lerp_to_reset(weight: float, from: Vector2, from_rotation: float) -> void:
	_hook.global_position = from.lerp(_reset_point.global_position, weight)
	_hook.rotation = lerp_angle(
			from_rotation, -PI / 2 + signf(player.visual.scale.x) * PI / 2, weight)


func _on_reload_timer_timeout() -> void:
	if ammo_in_stock > 0:
		unblock_shooting()
		_hook.self_modulate = Color.WHITE
		_state = State.IDLE
	else:
		_state = State.NO_AMMO


func _on_attract_timer_timeout() -> void:
	_reset_attraction()


func _on_throw_timer_timeout() -> void:
	_reset_throwing()


func _on_sync_position_timer_timeout() -> void:
	_sync_hook_position.rpc(_hook.position)
