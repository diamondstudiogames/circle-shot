extends Mob


enum WeaponType {
	NONE = -1,
	DESERT_EAGLE = 0,
	AK74 = 1,
	SNIPER_RIFLE = 2,
	GRENADE = 3,
	KNIFE = 4,
}

@export var min_distance := 400.0
@export var random_point_from_target_distance := 1280.0
@export_range(0.01, 1.0, 0.01, "exp") var aim_angle_rotation_weight := 0.08

@export_group("Attacks", "attack_")
@export var attack_interval_min := 0.8
@export var attack_interval_max := 1.5
@export var attack_time_after_equip := 0.2

@export_subgroup("Desert Eagle", "attack_desert_eagle_")
@export var attack_desert_eagle_spread := 2.0
@export var attack_desert_eagle_distance := 960.0
@export var attack_desert_eagle_shoot_times_min: int = 2
@export var attack_desert_eagle_shoot_times_max: int = 4
@export var attack_desert_eagle_shoot_interval := 1.1
@export var attack_desert_eagle_projectile_scene: PackedScene

@export_subgroup("AK74", "attack_ak_74_")
@export var attack_ak_74_spread := 6.0
@export var attack_ak_74_distance := 1120.0
@export var attack_ak_74_shoot_times_min: int = 4
@export var attack_ak_74_shoot_times_max: int = 7
@export var attack_ak_74_shoot_interval := 0.18
@export var attack_ak_74_projectile_scene: PackedScene

@export_subgroup("Sniper Rifle", "attack_sniper_rifle_")
@export var attack_sniper_rifle_spread := 2.0
@export var attack_sniper_rifle_distance := 1280.0
@export var attack_sniper_rifle_shoot_times: int = 1
@export var attack_sniper_rifle_shoot_interval := 1.5
@export var attack_sniper_rifle_aim_time := 1.0
@export var attack_sniper_rifle_projectile_speed := 3200.0
@export var attack_sniper_rifle_projectile_scene: PackedScene

@export_subgroup("Grenade", "attack_grenade_")
@export var attack_grenade_spread := 3.0
@export var attack_grenade_distance := 1600.0
@export var attack_grenade_projectile_speed := 1600.0
@export var attack_grenade_projectile_damping := 600.0
@export var attack_grenade_projectile_explosion_time := 2.5
@export var attack_grenade_projectile_scene: PackedScene

@export_subgroup("Knife", "attack_knife_")
@export var attack_knife_distance := 280.0
@export var attack_knife_interval := 0.8

@export_subgroup("Bandits", "attack_bandits_")
@export var attack_bandits_count: int = 2
@export var attack_bandits_distance := 1760.0
@export var attack_bandits_spawn_area_radius := 2560.0
@export var attack_bandits_health_difference_to_spawn: int = 200
@export var attack_bandits_scenes: Array[PackedScene]
@export var attack_bandits_heal_box_scene: PackedScene
@export var attack_bandits_ammo_box_scene: PackedScene

var _attacking := false
var _standing := false
var _retreating := false
var _attack_timer := 0.0
var _aiming := true
var _last_health_on_bandits_spawn: int
var _bandits_spawn_idx: int = 0

var _current_weapon_type := WeaponType.NONE
var _updating_weapons_rotations := true
var _turn_tween: Tween

@onready var _weapon_desert_eagle: Node2D = $Visual/Weapon/DesertEagle
@onready var _shoot_point_desert_eagle: Marker2D = $Visual/Weapon/DesertEagle/ShootPoint
@onready var _weapon_anim_desert_eagle: AnimationPlayer = $Visual/Weapon/DesertEagle/AnimationPlayer

@onready var _weapon_ak_74: Node2D = $Visual/Weapon/AK74
@onready var _shoot_point_ak_74: Marker2D = $Visual/Weapon/AK74/ShootPoint
@onready var _weapon_anim_ak_74: AnimationPlayer = $Visual/Weapon/AK74/AnimationPlayer

@onready var _weapon_sniper_rifle: Node2D = $Visual/Weapon/SniperRifle
@onready var _shoot_point_sniper_rifle: Marker2D = $Visual/Weapon/SniperRifle/ShootPoint
@onready var _weapon_anim_sniper_rifle: AnimationPlayer = $Visual/Weapon/SniperRifle/AnimationPlayer
@onready var _aim_sniper_rifle: Line2D = $Visual/Weapon/SniperRifle/AimLine

@onready var _weapon_grenade: Node2D = $Visual/Weapon/HEGrenade
@onready var _weapon_grenade_visual: Node2D = $Visual/Weapon/HEGrenade
@onready var _weapon_anim_grenade: AnimationPlayer = $Visual/Weapon/HEGrenade/AnimationPlayer
@onready var _weapon_throw_pivot_grenade: Marker2D = $Visual/Weapon/HEGrenade/ThrowPivot
@onready var _weapon_throw_point_grenade: Marker2D = $Visual/Weapon/HEGrenade/ThrowPivot/ThrowPoint

@onready var _weapon_knife: Node2D = $Visual/Weapon/Knife
@onready var _weapon_anim_knife: AnimationPlayer = $Visual/Weapon/Knife/AnimationPlayer
@onready var _attack_node_knife: Attack = $Visual/Weapon/Knife/Attack

@onready var _weapon_parent: Node2D = $Visual/Weapon
@onready var _timer: Timer = $Timer
@onready var _grenade_reload_timer: Timer = $GrenadeReloadTimer


func _ready() -> void:
	_attack_timer = attack_interval_max
	_last_health_on_bandits_spawn = max_health
	super()


func _process(_delta: float) -> void:
	if not is_disarmed():
		_update_weapons()


func _process_logic() -> void:
	var distance_to_target: float = target.global_position.distance_to(global_position)
	var direction_to_target: Vector2 = global_position.direction_to(target.global_position)
	if distance_to_target < min_distance:
		_retreating = true
	
	if _retreating:
		entity_input.move_direction = -direction_to_target
	elif _standing:
		entity_input.move_direction = Vector2.ZERO
	elif not agent.is_navigation_finished():
		entity_input.move_direction = global_position.direction_to(agent.get_next_path_position())
	
	if _aiming:
		entity_input.aim_direction = Vector2.from_angle(lerp_angle(
				entity_input.aim_direction.angle(), direction_to_target.angle(),
				aim_angle_rotation_weight))
	
	if not is_disarmed():
		_attack_timer -= get_physics_process_delta_time()
		if _attack_timer <= 0.0 and _attacking:
			_attack_timer = randf_range(attack_interval_min, attack_interval_max)
			_select_attack()
		elif distance_to_target < attack_knife_distance and _attack_timer < attack_interval_min:
			_attack_timer = 0.0


func _process_logic_no_target() -> void:
	if _standing:
		entity_input.move_direction = Vector2.ZERO
	elif not agent.is_navigation_finished():
		entity_input.move_direction = global_position.direction_to(agent.get_next_path_position())


func _target_updated() -> void:
	var distance_to_target: float = global_position.distance_to(target.global_position)
	if distance_to_target < attack_bandits_distance and _last_health_on_bandits_spawn \
			- current_health >= attack_bandits_health_difference_to_spawn:
		_attack_timer = randf_range(attack_interval_min, attack_interval_max)
		_last_health_on_bandits_spawn = current_health
		_attack_spawn_bandits()
		return
	
	entity_input.turn_with_aim = true
	var max_attack_distance: float = max(attack_desert_eagle_distance, attack_ak_74_distance,
			attack_sniper_rifle_distance, attack_grenade_distance, attack_knife_distance)
	_attacking = distance_to_target <= max_attack_distance and not target_ray_cast.is_colliding()
	_retreating = false


func _target_reset() -> void:
	_retreating = false
	entity_input.turn_with_aim = false
	if agent.is_navigation_finished() and is_inside_tree():
		_on_agent_navigation_finished()


func _disarmed() -> void:
	_timer.paused = true
	$Visual/AnimationPlayer.process_mode = Node.PROCESS_MODE_DISABLED
	_weapon_anim_desert_eagle.process_mode = Node.PROCESS_MODE_DISABLED
	_weapon_anim_ak_74.process_mode = Node.PROCESS_MODE_DISABLED
	_weapon_anim_sniper_rifle.process_mode = Node.PROCESS_MODE_DISABLED
	_weapon_anim_grenade.process_mode = Node.PROCESS_MODE_DISABLED
	if _weapon_anim_knife.is_playing() and _weapon_anim_knife.current_animation != &"equip":
		_weapon_anim_knife.play(&"RESET")


func _armed() -> void:
	_timer.paused = false
	$Visual/AnimationPlayer.process_mode = Node.PROCESS_MODE_INHERIT
	_weapon_anim_desert_eagle.process_mode = Node.PROCESS_MODE_INHERIT
	_weapon_anim_ak_74.process_mode = Node.PROCESS_MODE_INHERIT
	_weapon_anim_sniper_rifle.process_mode = Node.PROCESS_MODE_INHERIT
	_weapon_anim_grenade.process_mode = Node.PROCESS_MODE_INHERIT


@rpc("reliable", "authority", "call_local", 5)
func _select_weapon(weapon: WeaponType) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if is_instance_valid(_turn_tween):
		_turn_tween.finished.emit()
		_turn_tween.kill()
	
	match _current_weapon_type:
		WeaponType.DESERT_EAGLE:
			_weapon_desert_eagle.hide()
			_weapon_desert_eagle.process_mode = Node.PROCESS_MODE_DISABLED
			_weapon_anim_desert_eagle.play(&"RESET")
			_weapon_anim_desert_eagle.advance(0.01)
		WeaponType.AK74:
			_weapon_ak_74.hide()
			_weapon_ak_74.process_mode = Node.PROCESS_MODE_DISABLED
			_weapon_anim_ak_74.play(&"RESET")
			_weapon_anim_ak_74.advance(0.01)
		WeaponType.SNIPER_RIFLE:
			_weapon_sniper_rifle.hide()
			_weapon_sniper_rifle.process_mode = Node.PROCESS_MODE_DISABLED
			_weapon_anim_sniper_rifle.play(&"RESET")
			_weapon_anim_sniper_rifle.advance(0.01)
		WeaponType.GRENADE:
			_weapon_grenade.hide()
			_weapon_grenade.process_mode = Node.PROCESS_MODE_DISABLED
			_weapon_anim_grenade.play(&"RESET")
			_weapon_anim_grenade.advance(0.01)
		WeaponType.KNIFE:
			_weapon_knife.hide()
			_weapon_knife.process_mode = Node.PROCESS_MODE_DISABLED
			_weapon_anim_knife.play(&"RESET")
			_weapon_anim_knife.advance(0.01)
	
	_updating_weapons_rotations = false
	_current_weapon_type = weapon
	match _current_weapon_type:
		WeaponType.DESERT_EAGLE:
			_weapon_desert_eagle.show()
			_weapon_desert_eagle.rotation = 0.0
			_weapon_desert_eagle.process_mode = Node.PROCESS_MODE_INHERIT
			_update_weapons()
			_weapon_anim_desert_eagle.play(&"equip")
			_weapon_anim_desert_eagle.advance(0.0)
			var anim_name: StringName = await _weapon_anim_desert_eagle.animation_finished
			if anim_name == &"equip":
				_weapon_anim_desert_eagle.play(&"post_equip")
				_turn_tween = create_tween()
				_turn_tween.tween_method(_lerp_to_aim.bind(_weapon_desert_eagle), 0.0, 1.0,
						_weapon_anim_desert_eagle.get_animation(&"post_equip").length)
				
				await _turn_tween.finished
		WeaponType.AK74:
			_weapon_ak_74.show()
			_weapon_ak_74.rotation = 0.0
			_weapon_ak_74.process_mode = Node.PROCESS_MODE_INHERIT
			_update_weapons()
			_weapon_anim_ak_74.play(&"equip")
			_weapon_anim_ak_74.advance(0.0)
			var anim_name: StringName = await _weapon_anim_ak_74.animation_finished
			if anim_name == &"equip":
				_weapon_anim_ak_74.play(&"post_equip")
				_turn_tween = create_tween()
				_turn_tween.tween_method(_lerp_to_aim.bind(_weapon_ak_74), 0.0, 1.0,
						_weapon_anim_ak_74.get_animation(&"post_equip").length)
				
				await _turn_tween.finished
		WeaponType.SNIPER_RIFLE:
			_weapon_sniper_rifle.show()
			_weapon_sniper_rifle.rotation = 0.0
			_weapon_sniper_rifle.process_mode = Node.PROCESS_MODE_INHERIT
			_update_weapons()
			_weapon_anim_sniper_rifle.play(&"equip")
			_weapon_anim_sniper_rifle.advance(0.0)
			var anim_name: StringName = await _weapon_anim_sniper_rifle.animation_finished
			if anim_name == &"equip":
				_weapon_anim_sniper_rifle.play(&"post_equip")
				_turn_tween = create_tween()
				_turn_tween.tween_method(_lerp_to_aim.bind(_weapon_sniper_rifle), 0.0, 1.0,
						_weapon_anim_sniper_rifle.get_animation(&"post_equip").length)
				
				await _turn_tween.finished
		WeaponType.GRENADE:
			_weapon_grenade.show()
			_weapon_grenade.process_mode = Node.PROCESS_MODE_INHERIT
			_weapon_anim_grenade.play(&"equip")
			_weapon_anim_grenade.advance(0.0)
		WeaponType.KNIFE:
			_weapon_knife.show()
			_weapon_knife.rotation = 0.0
			_weapon_knife.process_mode = Node.PROCESS_MODE_INHERIT
			_update_weapons()
			_weapon_anim_knife.play(&"equip")
			_weapon_anim_knife.advance(0.0)
			var anim_name: StringName = await _weapon_anim_knife.animation_finished
			if anim_name == &"equip":
				_weapon_anim_knife.play(&"post_equip")
				_turn_tween = create_tween()
				_turn_tween.tween_method(_lerp_to_aim.bind(_weapon_knife), 0.0, 1.0,
						_weapon_anim_knife.get_animation(&"post_equip").length)
				
				await _turn_tween.finished
	
	_updating_weapons_rotations = true


@rpc("reliable", "authority", "call_local", 5)
func _shoot_desert_eagle() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_update_weapons()
	_weapon_anim_desert_eagle.play(&"shoot")
	_weapon_anim_desert_eagle.seek(0.0)
	
	if multiplayer.is_server():
		var projectile: Projectile = attack_desert_eagle_projectile_scene.instantiate()
		projectile.position = _shoot_point_desert_eagle.global_position
		projectile.damage_multiplier = damage_multiplier
		projectile.rotation = entity_input.aim_direction.angle() \
				+ deg_to_rad(randf_range(-attack_desert_eagle_spread, attack_desert_eagle_spread))
		projectile.team = team
		projectile.who = id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)


@rpc("reliable", "authority", "call_local", 5)
func _shoot_ak_74() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_update_weapons()
	_weapon_anim_ak_74.play(&"shoot")
	_weapon_anim_ak_74.seek(0.0)
	
	if multiplayer.is_server():
		var projectile: Projectile = attack_ak_74_projectile_scene.instantiate()
		projectile.position = _shoot_point_ak_74.global_position
		projectile.damage_multiplier = damage_multiplier
		projectile.rotation = entity_input.aim_direction.angle() \
				+ deg_to_rad(randf_range(-attack_ak_74_spread, attack_ak_74_spread))
		projectile.team = team
		projectile.who = id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)


@rpc("unreliable", "authority", "call_local", 5)
func _toggle_aim_sniper_rifle(visibility: bool) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_aim_sniper_rifle.visible = visibility


@rpc("reliable", "authority", "call_local", 5)
func _shoot_sniper_rifle() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_update_weapons()
	_weapon_anim_sniper_rifle.play(&"shoot")
	_weapon_anim_sniper_rifle.seek(0.0)
	_aim_sniper_rifle.hide()
	
	if multiplayer.is_server():
		var projectile: Projectile = attack_sniper_rifle_projectile_scene.instantiate()
		projectile.position = _shoot_point_sniper_rifle.global_position
		projectile.damage_multiplier = damage_multiplier
		projectile.rotation = entity_input.aim_direction.angle() \
				+ deg_to_rad(randf_range(-attack_sniper_rifle_spread, attack_sniper_rifle_spread))
		projectile.team = team
		projectile.who = id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)


@rpc("reliable", "authority", "call_local", 5)
func _shoot_grenade(throw_direction := Vector2.RIGHT) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	block_turning()
	visual.scale.x = -1.0 if throw_direction.x < 0.0 else 1.0
	_weapon_throw_pivot_grenade.rotation = _calculate_aim_angle(throw_direction)
	_weapon_anim_grenade.play(&"pre_throw")
	await _weapon_anim_grenade.animation_finished
	
	var animation: Animation = _weapon_anim_grenade.get_animation(&"throw")
	animation.track_set_key_value(0, 0,
			_weapon_grenade_visual.to_local(_weapon_throw_pivot_grenade.global_position))
	animation.track_set_key_value(0, 1,
			_weapon_grenade_visual.to_local(_weapon_throw_point_grenade.global_position))
	_weapon_anim_grenade.play(&"throw")
	await _weapon_anim_grenade.animation_finished
	unblock_turning()
	
	if multiplayer.is_server():
		var projectile: GrenadeProjectile = attack_grenade_projectile_scene.instantiate()
		projectile.position = _weapon_throw_point_grenade.global_position
		projectile.direction = throw_direction.normalized().rotated(deg_to_rad(
				randf_range(-attack_grenade_spread, attack_grenade_spread)))
		projectile.speed *= minf(throw_direction.length(), 1.0)
		projectile.team = team
		projectile.name += str(randi())
		var attack: Attack = projectile.get_node(^"Explosion/Attack")
		attack.who = id
		attack.team = team
		attack.damage_multiplier = damage_multiplier
		_projectiles_parent.add_child(projectile, true)
	
	_weapon_anim_grenade.play(&"RESET")
	_weapon_anim_grenade.advance(0.01)
	_weapon_grenade.hide()
	_weapon_grenade.process_mode = Node.PROCESS_MODE_DISABLED


@rpc("reliable", "authority", "call_local", 5)
func _shoot_knife(direction := Vector2.RIGHT) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_weapon_anim_knife.play(&"attack")
	_weapon_anim_knife.seek(0.0)
	block_turning()
	visual.scale.x = -1.0 if direction.x < 0.0 else 1.0
	_weapon_knife.rotation = _calculate_aim_angle(direction)
	
	if multiplayer.is_server():
		_attack_node_knife.damage_multiplier = damage_multiplier
		_attack_node_knife.team = team
		_attack_node_knife.who = id
		_attack_node_knife.clear_exceptions()
	
	await _weapon_anim_knife.animation_finished
	unblock_turning()


func _select_attack() -> void:
	var distance_to_target: float = global_position.distance_to(target.global_position)
	var attack_pool: Array[Callable]
	
	if distance_to_target < attack_desert_eagle_distance:
		attack_pool.append(_attack_desert_eagle)
		attack_pool.append(_attack_desert_eagle)
	if distance_to_target < attack_ak_74_distance:
		attack_pool.append(_attack_ak_74)
		attack_pool.append(_attack_ak_74)
	if distance_to_target < attack_sniper_rifle_distance:
		attack_pool.append(_attack_sniper_rifle)
	if distance_to_target < attack_grenade_distance and _grenade_reload_timer.is_stopped():
		attack_pool.append(_attack_grenade)
	if distance_to_target < attack_knife_distance:
		attack_pool = [_attack_knife]
	
	if attack_pool.is_empty():
		return
	var selected_attack: Callable = attack_pool.pick_random()
	selected_attack.call()


func _attack_desert_eagle() -> void:
	var shoot_times: int = randi_range(attack_desert_eagle_shoot_times_min,
			attack_desert_eagle_shoot_times_max)
	_attack_timer += shoot_times * attack_desert_eagle_shoot_interval
	
	if _current_weapon_type != WeaponType.DESERT_EAGLE:
		_select_weapon.rpc(WeaponType.DESERT_EAGLE)
		_attack_timer += _weapon_anim_desert_eagle.get_animation(&"equip").length
		_attack_timer += _weapon_anim_desert_eagle.get_animation(&"post_equip").length
		_attack_timer += attack_time_after_equip
		var anim_name: StringName = await _weapon_anim_desert_eagle.animation_finished
		if anim_name != &"equip":
			return
		await _weapon_anim_desert_eagle.animation_finished
		
		_timer.start(attack_time_after_equip)
		await _timer.timeout
	
	for i: int in shoot_times:
		_shoot_desert_eagle.rpc()
		
		if i != shoot_times - 1:
			_timer.start(attack_desert_eagle_shoot_interval)
			await _timer.timeout


func _attack_ak_74() -> void:
	var shoot_times: int = randi_range(attack_ak_74_shoot_times_min,
			attack_ak_74_shoot_times_max)
	_attack_timer += shoot_times * attack_ak_74_shoot_interval
	
	if _current_weapon_type != WeaponType.AK74:
		_select_weapon.rpc(WeaponType.AK74)
		_attack_timer += _weapon_anim_ak_74.get_animation(&"equip").length
		_attack_timer += attack_time_after_equip
		var anim_name: StringName = await _weapon_anim_ak_74.animation_finished
		if anim_name != &"equip":
			return
		await _weapon_anim_ak_74.animation_finished
		
		_timer.start(attack_time_after_equip)
		await _timer.timeout
	
	for i: int in shoot_times:
		_shoot_ak_74.rpc()
		
		if i != shoot_times - 1:
			_timer.start(attack_ak_74_shoot_interval)
			await _timer.timeout


func _attack_sniper_rifle() -> void:
	_attack_timer += attack_sniper_rifle_shoot_times \
			* (attack_sniper_rifle_shoot_interval + attack_sniper_rifle_aim_time)
	
	if _current_weapon_type != WeaponType.SNIPER_RIFLE:
		_select_weapon.rpc(WeaponType.SNIPER_RIFLE)
		_attack_timer += _weapon_anim_sniper_rifle.get_animation(&"equip").length
		_attack_timer += attack_time_after_equip
		var anim_name: StringName = await _weapon_anim_sniper_rifle.animation_finished
		if anim_name != &"equip":
			return
		await _weapon_anim_sniper_rifle.animation_finished
		
		_timer.start(attack_time_after_equip)
		await _timer.timeout
	
	_standing = true
	for i: int in attack_sniper_rifle_shoot_times:
		if not is_instance_valid(target):
			_standing = false
			return
		_aiming = false
		_toggle_aim_sniper_rifle.rpc(true)
		var predicted_target_position: Vector2 = (
				target.global_position + target.get_real_velocity()
				* (global_position.distance_to(target.global_position)
				/ attack_sniper_rifle_projectile_speed + attack_sniper_rifle_aim_time)
		)
		entity_input.aim_direction = global_position.direction_to(predicted_target_position)
		
		_timer.start(attack_sniper_rifle_aim_time)
		await _timer.timeout
		if not target_ray_cast.is_colliding():
			_shoot_sniper_rifle.rpc()
		_toggle_aim_sniper_rifle.rpc(false)
		_aiming = true
		
		if i != attack_sniper_rifle_shoot_times - 1:
			_timer.start(attack_sniper_rifle_shoot_interval)
			await _timer.timeout
	_standing = false


func _attack_grenade() -> void:
	_select_weapon.rpc(WeaponType.GRENADE)
	_attack_timer += _weapon_anim_grenade.get_animation(&"equip").length
	_attack_timer += _weapon_anim_grenade.get_animation(&"pre_throw").length
	_attack_timer += _weapon_anim_grenade.get_animation(&"throw").length
	_attack_timer += attack_time_after_equip
	var anim_name: StringName = await _weapon_anim_grenade.animation_finished
	if anim_name != &"equip":
		return
	
	_timer.start(attack_time_after_equip)
	await _timer.timeout
	if not is_instance_valid(target):
		return
	
	var need_speed: float = global_position.distance_to(target.global_position) \
			/ attack_grenade_projectile_explosion_time + attack_grenade_projectile_damping \
			* attack_grenade_projectile_explosion_time / 2
	entity_input.aim_direction = (global_position.direction_to(target.global_position)
			* need_speed / attack_grenade_projectile_speed).limit_length(1.0)
	
	_shoot_grenade.rpc(entity_input.aim_direction)
	_grenade_reload_timer.start()


func _attack_knife() -> void:
	_attack_timer += attack_knife_interval
	if _current_weapon_type != WeaponType.KNIFE:
		_select_weapon.rpc(WeaponType.KNIFE)
		_attack_timer += _weapon_anim_knife.get_animation(&"equip").length
		_attack_timer += attack_time_after_equip
		var anim_name: StringName = await _weapon_anim_knife.animation_finished
		if anim_name != &"equip":
			return
		await _weapon_anim_knife.animation_finished
		
		_timer.start(attack_time_after_equip)
		await _timer.timeout
	
	if is_disarmed():
		await disarmed
	if not is_instance_valid(target):
		return
	_shoot_knife.rpc(global_position.direction_to(target.global_position))


func _attack_spawn_bandits() -> void:
	($Visual/AnimationPlayer as AnimationPlayer).play(&"spawn_bandits")
	_attack_timer += \
			($Visual/AnimationPlayer as AnimationPlayer).get_animation(&"spawn_bandits").length


func _spawn_bandits() -> void:
	if not multiplayer.is_server() or not is_instance_valid(target):
		return
	
	for i: int in attack_bandits_count:
		var bandit_scene: PackedScene = attack_bandits_scenes[_bandits_spawn_idx]
		var bandit: Mob = bandit_scene.instantiate()
		bandit.position = NavigationServer2D.map_get_closest_point(
				get_world_2d().navigation_map,
				Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
				* randf_range(0.0, attack_bandits_spawn_area_radius) + target.global_position
		)
		bandit.team = team
		bandit.id = -randi()
		bandit.name += str(bandit.id)
		get_parent().add_child(bandit, true)
		bandit.died.connect(_on_bandit_died.bind(bandit, i))
		_bandits_spawn_idx += 1
		if _bandits_spawn_idx == attack_bandits_scenes.size():
			_bandits_spawn_idx = 0


func _update_weapons() -> void:
	match _current_weapon_type:
		WeaponType.DESERT_EAGLE:
			if _updating_weapons_rotations:
				_weapon_desert_eagle.rotation = _calculate_aim_angle()
			_weapon_desert_eagle.position = Gun.calculate_gun_position(
					_weapon_desert_eagle.rotation, _shoot_point_desert_eagle.position.y,
					_weapon_parent.position)
		WeaponType.AK74:
			if _updating_weapons_rotations:
				_weapon_ak_74.rotation = _calculate_aim_angle()
			_weapon_ak_74.position = Gun.calculate_gun_position(_weapon_ak_74.rotation,
					_shoot_point_ak_74.position.y, _weapon_parent.position)
		WeaponType.SNIPER_RIFLE:
			if _updating_weapons_rotations:
				_weapon_sniper_rifle.rotation = _calculate_aim_angle()
			_weapon_sniper_rifle.position = Gun.calculate_gun_position(
					_weapon_sniper_rifle.rotation, _shoot_point_sniper_rifle.position.y,
					_weapon_parent.position)
		WeaponType.KNIFE:
			if _updating_weapons_rotations:
				_weapon_knife.rotation = _calculate_aim_angle()
	# TODO: остальные пушки


func _lerp_to_aim(weight: float, what: Node2D) -> void:
	what.rotation = _calculate_aim_angle() * weight


func _on_bandit_died(bandit: Entity, idx: int) -> void:
	if idx % 2 == 0:
		var ammo_box: Node2D = attack_bandits_ammo_box_scene.instantiate()
		ammo_box.position = bandit.global_position
		ammo_box.name += str(randi())
		world.other_parent.add_child(ammo_box, true)
	else:
		var heal_box: Node2D = attack_bandits_heal_box_scene.instantiate()
		heal_box.position = bandit.global_position
		heal_box.name += str(randi())
		world.other_parent.add_child(heal_box, true)


func _on_change_move_direction_timer_timeout() -> void:
	var destination: Vector2
	if not is_instance_valid(target):
		destination = NavigationServer2D.map_get_random_point(
				get_world_2d().navigation_map, 1, false)
	else:
		destination = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
				* randf_range(0.0, random_point_from_target_distance) + target.global_position
		destination = NavigationServer2D.map_get_closest_point(
				get_world_2d().navigation_map, destination)
	agent.target_position = destination


func _on_agent_navigation_finished() -> void:
	_on_change_move_direction_timer_timeout()
	($ChangeMoveDirectionTimer as Timer).start()
