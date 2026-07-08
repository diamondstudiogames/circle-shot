extends Mob


@export var min_distance := 400.0
@export var random_point_from_target_distance := 1280.0
@export var altar_scene: PackedScene

@export_group("Attacks", "attack_")
@export var attack_interval_min := 0.8
@export var attack_interval_max := 1.5
@export var attack_final_need_health: int = 150
@export var attack_final_scene: PackedScene

@export_subgroup("Dash", "attack_dash_")
@export var attack_dash_speed := 1040.0
@export var attack_dash_dash_duration := 1.0
@export var attack_dash_duration := 2.1
@export var attack_dash_select_distance := 320.0

@export_subgroup("Daggers", "attack_daggers_")
@export var attack_daggers_count_min: int = 5
@export var attack_daggers_count_max: int = 6
@export var attack_daggers_summon_count_max: int = 2
@export var attack_daggers_summon_duration := 1.0
@export var attack_daggers_prediction_time_min := 0.1
@export var attack_daggers_prediction_time_max := 1.0
@export var attack_daggers_spread := 2.0
@export var attack_daggers_spawn_radius_min := 240.0
@export var attack_daggers_spawn_radius_max := 400.0
@export var attack_daggers_count_min2: int = 7
@export var attack_daggers_count_max2: int = 8
@export var attack_daggers_summon_count_max2: int = 3
@export var attack_daggers_projectile_scene: PackedScene
@export_subgroup("Daggers/Sword", "attack_daggers_sword_")
@export var attack_daggers_sword_summon_duration := 2.0
@export var attack_daggers_sword_projectile_scene: PackedScene

@export_subgroup("Lightnings", "attack_lightnings_")
@export var attack_lightnings_duration := 0.5
@export var attack_lightnings_spawn_interval := 0.1
@export var attack_lightnings_count: int = 5
@export var attack_lightnings_count2: int = 8
@export var attack_lightnings_scene: PackedScene
@export var attack_lightnings_scene2: PackedScene

@export_subgroup("Fireballs", "attack_fireballs_")
@export var attack_fireballs_summon_count: int = 3
@export var attack_fireballs_summon_count2: int = 5
@export var attack_fireballs_summon_duration := 0.7
@export var attack_fireballs_count: int = 5
@export var attack_fireballs_count2: int = 7
@export var attack_fireballs_angle_interval := 15.0
@export var attack_fireballs_spread := 7.0
@export var attack_fireballs_projectile_scene: PackedScene

@export_subgroup("Pentagrams", "attack_pentagrams_")
@export var attack_pentagrams_count: int = 12
@export var attack_pentagrams_count2: int = 16
@export var attack_pentagrams_summon_duration := 0.7
@export var attack_pentagrams_scene: PackedScene
@export var attack_pentagrams_scene2: PackedScene

@export_subgroup("Cultists", "attack_cultists_")
@export var attack_cultists_count: int = 2
@export var attack_cultists_count2: int = 4
@export var attack_cultists_summon_duration := 1.0
@export var attack_cultists_attacks_interval: int = 20
@export var attack_cultists_scenes: Array[PackedScene]
@export var attack_cultists_boxes_scenes: Array[PackedScene]

@export_subgroup("Big Shot", "attack_big_")
@export var attack_big_summon_duration := 1.3
@export var attack_big_summon_count: int = 1
@export var attack_big_summon_count2: int = 3
@export var attack_big_second_phase_speedup := 1.5
@export var attack_big_projectile_scene: PackedScene

@export_subgroup("Floor Pentagrams", "attack_floor_")
@export var attack_floor_count: int = 3
@export var attack_floor_summon_duration := 1.5
@export var attack_floor_scene: PackedScene

@export_subgroup("Big Shots Down", "attack_down_")
@export var attack_down_duration := 0.5
@export var attack_down_spawn_interval := 0.1
@export var attack_down_count: int = 7
@export var attack_down_scene: PackedScene

var _target_covered := false
var _standing := false
var _attack_timer := 0.0
var _second_phase := false
var _did_final_attack := false

var _dash_direction: Vector2
var _spawn_sword := false
var _attacks_counter: int = 0
var _cultist_idx: int = 0
var _box_idx: int = 0
var _big_shot_aim_target: Entity

@onready var _anim_tree: AnimationTree = $Visual/AnimationTree
@onready var _anim_timer: Timer = $AnimationTimer
@onready var _timer: Timer = $Timer

@onready var _shoot_point: Marker2D = $Visual/Goat/Base/ShootPoint
@onready var _knockback_attack: Attack = $Visual/DashAttacks/KnockbackAttack
@onready var _stun_attack: Attack = $Visual/DashAttacks/StunAttack


func _ready() -> void:
	_attack_timer = attack_interval_max
	_anim_tree.set(&"parameters/IdleWalkTransition/transition_request", "idle")
	super()


func _process(_delta: float) -> void:
	if get_real_velocity().is_zero_approx():
		if _anim_tree.get(&"parameters/IdleWalkTransition/current_state") != "idle":
			_anim_tree.set(&"parameters/IdleWalkTransition/transition_request", "idle")
	else:
		if _anim_tree.get(&"parameters/IdleWalkTransition/current_state") != "walk":
			_anim_tree.set(&"parameters/IdleWalkTransition/transition_request", "walk")
		_anim_tree.set(&"parameters/WalkTimeScale/scale", get_real_velocity().length() / speed)
	if is_instance_valid(_big_shot_aim_target):
		var direction: Vector2 = _shoot_point.global_position.direction_to(
				_big_shot_aim_target.global_position)
		_shoot_point.rotation = _calculate_aim_angle(direction)
		if _big_shot_aim_target.global_position.x < global_position.x:
			visual.scale.x = -1.0
		else:
			visual.scale.x = 1.0


func _process_logic() -> void:
	_process_logic_no_target()
	
	if not is_disarmed():
		_attack_timer -= get_physics_process_delta_time()
		if _attack_timer <= 0.0:
			_attack_timer = randf_range(attack_interval_min, attack_interval_max)
			_select_attack()


func _process_logic_no_target() -> void:
	if _standing:
		entity_input.move_direction = Vector2.ZERO
	elif not agent.is_navigation_finished():
		entity_input.move_direction = global_position.direction_to(agent.get_next_path_position())


func _target_updated() -> void:
	_target_covered = target_ray_cast.is_colliding()


func _target_reset() -> void:
	if agent.is_navigation_finished() and is_inside_tree():
		_on_agent_navigation_finished()


func _health_changed(_old_value: int, new_value: int) -> void:
	if new_value * 2 < max_health and not _second_phase:
		_second_phase = true
		if multiplayer.is_server():
			_spawn_altar()
	if new_value <= attack_final_need_health and not _did_final_attack:
		_final_attack()


func _disarmed() -> void:
	_timer.paused = true
	$Visual/DashAttacks/KnockbackAttack/AreaDetector.process_mode = Node.PROCESS_MODE_DISABLED
	$Visual/DashAttacks/StunAttack/AreaDetector.process_mode = Node.PROCESS_MODE_DISABLED
	_anim_tree.set(&"parameters/DaggersTimeScale/scale", 0.0)
	_anim_tree.set(&"parameters/SummonTimeScale/scale", 0.0)
	_anim_tree.set(&"parameters/PentagramsTimeScale/scale", 0.0)
	_anim_tree.set(&"parameters/CultistsTimeScale/scale", 0.0)
	_anim_tree.set(&"parameters/BigTimeScale/scale", 0.0)
	_anim_tree.set(&"parameters/FloorTimeScale/scale", 0.0)


func _armed() -> void:
	_timer.paused = false
	$Visual/DashAttacks/KnockbackAttack/AreaDetector.process_mode = Node.PROCESS_MODE_INHERIT
	$Visual/DashAttacks/StunAttack/AreaDetector.process_mode = Node.PROCESS_MODE_INHERIT
	_anim_tree.set(&"parameters/DaggersTimeScale/scale", 1.0)
	_anim_tree.set(&"parameters/SummonTimeScale/scale", 1.0)
	_anim_tree.set(&"parameters/PentagramsTimeScale/scale", 1.0)
	_anim_tree.set(&"parameters/CultistsTimeScale/scale", 1.0)
	_anim_tree.set(&"parameters/BigTimeScale/scale",
			attack_big_second_phase_speedup if _second_phase else 1.0)
	_anim_tree.set(&"parameters/FloorTimeScale/scale", 1.0)


@rpc("reliable", "authority", "call_local", 5)
func _do_dash(direction: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_anim_tree.set(&"parameters/DashOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	make_immobile()
	block_turning()
	visual.scale.x = -1.0 if direction.x < 0 else 1.0
	_anim_timer.start(_anim_tree.get_animation(&"dash").length)
	await _anim_timer.timeout
	unmake_immobile()
	unblock_turning()


@rpc("reliable", "authority", "call_local", 5)
func _do_daggers() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/DaggersOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


@rpc("reliable", "authority", "call_local", 5)
func _do_summon() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/SummonOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


@rpc("reliable", "authority", "call_local", 5)
func _do_fireballs(angle: float) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/FireballsOneShot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	block_turning()
	visual.scale.x = 1.0 if Vector2.from_angle(deg_to_rad(angle)).x >= 0.0 else -1.0
	_anim_timer.start(0.4)
	await _anim_timer.timeout
	unblock_turning()


@rpc("reliable", "authority", "call_local", 5)
func _do_pentagrams() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/PentagramsOneShot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


@rpc("reliable", "authority", "call_local", 5)
func _do_cultists() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/CultistsOneShot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


@rpc("reliable", "authority", "call_local", 5)
func _do_big_shot(target_id: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	block_turning()
	_anim_tree.set(&"parameters/BigOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var entity: Entity = \
			(get_tree().get_first_node_in_group(&"world") as World).entities.get(target_id)
	if is_instance_valid(entity):
		_big_shot_aim_target = entity
	_anim_tree.set(&"parameters/BigTimeScale/scale",
			attack_big_second_phase_speedup if _second_phase else 1.0)


@rpc("reliable", "authority", "call_local", 5)
func _do_floor_pentagrams() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_anim_tree.set(&"parameters/FloorOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _select_attack() -> void:
	if _attacks_counter == attack_cultists_attacks_interval:
		_attacks_counter = 0
		_attack_cultists()
		return
	
	var attacks: Array[Callable] = [
		_attack_dash,
		_attack_daggers,
		_attack_fireballs,
		_attack_big_shot,
	]
	var attacks_target_covered: Array[Callable] = [
		_attack_lightnings,
		_attack_pentagrams,
	]
	if _second_phase:
		attacks_target_covered.append_array([
			_attack_floor_pentagrams,
			_attack_big_shots_down,
		])
	
	var attack: Callable = (attacks_target_covered if _target_covered
			else attacks_target_covered + attacks + attacks).pick_random()
	if global_position.distance_to(target.global_position) < attack_dash_select_distance:
		attack = _attack_dash
	attack.call()
	_attacks_counter += 1


func _attack_dash() -> void:
	var dashes_count: int = 2 if _second_phase else 1
	_attack_timer += dashes_count * attack_dash_duration
	for i: int in dashes_count:
		if not is_instance_valid(target):
			return
		_dash_direction = global_position.direction_to(target.global_position)
		_do_dash.rpc(_dash_direction)
		if i + 1 != dashes_count:
			_timer.start(attack_dash_duration)
			await _timer.timeout


func _start_dash() -> void:
	if not multiplayer.is_server():
		return
	
	var current_attack: Attack
	if _second_phase:
		_knockback_attack.process_mode = Node.PROCESS_MODE_DISABLED
		_stun_attack.process_mode = Node.PROCESS_MODE_INHERIT
		current_attack = _stun_attack
	else:
		_knockback_attack.process_mode = Node.PROCESS_MODE_INHERIT
		_stun_attack.process_mode = Node.PROCESS_MODE_DISABLED
		current_attack = _knockback_attack
	current_attack.team = team
	current_attack.who = id
	current_attack.damage_multiplier = damage_multiplier
	current_attack.clear_exceptions()
	
	add_effect.rpc(Effect.KNOCKBACK, attack_dash_dash_duration,
			[_dash_direction * attack_dash_speed])


func _attack_daggers() -> void:
	var summons_count: int = randi_range(1, attack_daggers_summon_count_max2
			if _second_phase else attack_daggers_summon_count_max)
	var summon_sword: bool = _second_phase
	_attack_timer += summons_count * attack_daggers_summon_duration
	if summon_sword:
		_attack_timer += attack_daggers_sword_summon_duration
	for i: int in summons_count:
		if not is_instance_valid(target):
			return
		_do_daggers.rpc()
		_standing = true
		_timer.start(_anim_tree.get_animation(&"daggers").length)
		await _timer.timeout
		_standing = false
		if i + 1 != summons_count and not summon_sword:
			_timer.start(attack_daggers_summon_duration
					- _anim_tree.get_animation(&"daggers").length)
			await _timer.timeout
	if summon_sword:
		if not is_instance_valid(target):
			return
		_do_daggers.rpc()
		_spawn_sword = true
		_standing = true
		_timer.start(_anim_tree.get_animation(&"daggers").length)
		await _timer.timeout
		_standing = false


func _spawn_daggers() -> void:
	if not multiplayer.is_server() or not is_instance_valid(target):
		return
	if _spawn_sword:
		_spawn_sword = false
		var sword: Projectile = attack_daggers_sword_projectile_scene.instantiate()
		sword.position = global_position
		sword.damage_multiplier = damage_multiplier
		sword.team = team
		sword.who = id
		sword.name += str(randi())
		sword.set(&"target", target)
		_projectiles_parent.add_child(sword, true)
	else:
		var count: int = (
				randi_range(attack_daggers_count_min2, attack_daggers_count_max2)
				if _second_phase else
				randi_range(attack_daggers_count_min, attack_daggers_count_max)
		)
		for i: int in count:
			var spawn_local_pos := Vector2(randf_range(-1.0, 1.0),
					randf_range(-1.0, 1.0)).normalized() \
					* randf_range(attack_daggers_spawn_radius_min, attack_daggers_spawn_radius_max)
			var predicted_pos: Vector2 = randf_range(attack_daggers_prediction_time_min,
					attack_daggers_prediction_time_max) * target.get_real_velocity() \
					+ target.global_position
			var dagger: Projectile = attack_daggers_projectile_scene.instantiate()
			dagger.position = global_position + spawn_local_pos
			dagger.damage_multiplier = damage_multiplier
			dagger.rotation = dagger.position.direction_to(predicted_pos).angle() \
					+ deg_to_rad(randf_range(-attack_daggers_spread, attack_daggers_spread))
			dagger.scale.y = -1 if dagger.rotation > PI / 2 or dagger.rotation < -PI / 2 else 1
			dagger.team = team
			dagger.who = id
			dagger.name += str(randi())
			_projectiles_parent.add_child(dagger, true)


func _attack_lightnings() -> void:
	var count: int = attack_lightnings_count2 if _second_phase else attack_lightnings_count
	_attack_timer += attack_lightnings_duration
	_attack_timer += attack_lightnings_spawn_interval * count
	_do_summon.rpc()
	_timer.start(_anim_tree.get_animation(&"summon").length)
	await _timer.timeout
	for i: int in count:
		var lightning: Attack = (attack_lightnings_scene2 if _second_phase
				else attack_lightnings_scene).instantiate()
		lightning.position = NavigationServer2D.map_get_random_point(
				get_world_2d().navigation_map, 1, false)
		lightning.damage_multiplier = damage_multiplier
		lightning.who = id
		lightning.team = team
		lightning.name += str(randi())
		_projectiles_parent.add_child(lightning)
		if i + 1 != count:
			_timer.start(attack_lightnings_spawn_interval)
			await _timer.timeout


func _attack_fireballs() -> void:
	var summons: int = attack_fireballs_summon_count2 if _second_phase \
			else attack_fireballs_summon_count
	_attack_timer += summons * attack_fireballs_summon_duration
	for c: int in summons:
		if not is_instance_valid(target):
			return
		var base_angle: float = rad_to_deg(global_position.angle_to_point(target.global_position)) \
				+ randf_range(-attack_fireballs_spread, attack_fireballs_spread)
		_do_fireballs.rpc(base_angle)
		var count: int = attack_fireballs_count2 if _second_phase else attack_fireballs_count
		var max_additional_angle: float = (count - 1) * attack_fireballs_angle_interval / 2
		for i: int in count:
			var additional_angle: float = (-1 + 2.0 / (count - 1) * i) * max_additional_angle
			var fireball: Attack = attack_fireballs_projectile_scene.instantiate()
			fireball.position = _shoot_point.global_position
			fireball.damage_multiplier = damage_multiplier
			fireball.who = id
			fireball.team = team
			fireball.name += str(randi())
			fireball.rotation = deg_to_rad(base_angle + additional_angle)
			_projectiles_parent.add_child(fireball)
		if c + 1 != summons:
			_timer.start(attack_fireballs_summon_duration)
			await _timer.timeout


func _attack_pentagrams() -> void:
	_attack_timer += attack_pentagrams_summon_duration
	_standing = true
	_do_pentagrams.rpc()
	_timer.start(attack_pentagrams_summon_duration)
	await _timer.timeout
	_standing = false


func _spawn_pentagrams() -> void:
	if not multiplayer.is_server():
		return
	var count: int = attack_pentagrams_count2 if _second_phase else attack_pentagrams_count
	var angle_interval: float = PI * 2 / count
	var base_angle: float = randf_range(0.0, angle_interval)
	for i: int in count:
		var pentagram: Projectile = (attack_pentagrams_scene2 if _second_phase
				else attack_pentagrams_scene).instantiate()
		pentagram.position = global_position
		pentagram.rotation = base_angle + angle_interval * i
		pentagram.team = team
		pentagram.who = id
		pentagram.damage_multiplier = damage_multiplier
		pentagram.name += str(randi())
		_projectiles_parent.add_child(pentagram)


func _attack_cultists() -> void:
	_attack_timer += attack_cultists_summon_duration
	_standing = true
	_do_cultists.rpc()
	_timer.start(attack_cultists_summon_duration)
	await _timer.timeout
	_standing = false


func _spawn_cultists() -> void:
	if not multiplayer.is_server():
		return
	for i: int in attack_cultists_count2 if _second_phase else attack_cultists_count:
		var cultist_scene: PackedScene = attack_cultists_scenes[_cultist_idx]
		var cultist: Mob = cultist_scene.instantiate()
		cultist.position = NavigationServer2D.map_get_random_point(
				get_world_2d().navigation_map, 1, false)
		cultist.team = team
		cultist.id = -randi()
		cultist.name += str(cultist.id)
		get_parent().add_child(cultist, true)
		cultist.died.connect(_on_cultist_died.bind(cultist))
		_cultist_idx += 1
		if _cultist_idx == attack_cultists_scenes.size():
			_cultist_idx = 0


func _attack_big_shot() -> void:
	var count: int = attack_big_summon_count2 if _second_phase else attack_big_summon_count
	var divider: float = attack_big_second_phase_speedup if _second_phase else 1.0
	_attack_timer += count * attack_big_summon_duration / divider
	for i: int in count:
		if not is_instance_valid(target):
			return
		_do_big_shot.rpc(target.id)
		if i + 1 != count:
			_timer.start(attack_big_summon_duration / divider)
			await _timer.timeout


func _spawn_big_shot() -> void:
	_big_shot_aim_target = null
	unblock_turning()
	if not multiplayer.is_server():
		return
	var direction: Vector2
	if is_instance_valid(target):
		direction = _shoot_point.global_position.direction_to(target.global_position)
	else:
		direction = Vector2.from_angle(_shoot_point.rotation)
		direction.x = visual.scale.x
	var big_shot: Attack = attack_big_projectile_scene.instantiate()
	big_shot.position = _shoot_point.global_position
	big_shot.damage_multiplier = damage_multiplier
	big_shot.who = id
	big_shot.team = team
	big_shot.name += str(randi())
	big_shot.rotation = direction.angle()
	_projectiles_parent.add_child(big_shot)


func _attack_floor_pentagrams() -> void:
	_attack_timer += attack_floor_summon_duration
	_standing = true
	_do_floor_pentagrams.rpc()
	_timer.start(attack_floor_summon_duration)
	await _timer.timeout
	_standing = false


func _spawn_floor_pentagrams() -> void:
	if not multiplayer.is_server():
		return
	for i: int in attack_floor_count:
		var spawn_position: Vector2 = NavigationServer2D.map_get_random_point(
				get_world_2d().navigation_map, 1, false)
		if i == 0 and is_instance_valid(target):
			spawn_position = target.global_position
		var pentagram: Attack = attack_floor_scene.instantiate()
		pentagram.position = spawn_position
		pentagram.team = team
		pentagram.who = id
		pentagram.damage_multiplier = damage_multiplier
		pentagram.name += str(randi())
		_projectiles_parent.add_child(pentagram)


func _attack_big_shots_down() -> void:
	_attack_timer += attack_down_duration
	_attack_timer += attack_down_spawn_interval * attack_down_count
	_do_summon.rpc()
	_timer.start(_anim_tree.get_animation(&"summon").length)
	await _timer.timeout
	for i: int in attack_down_count:
		var big_shot_down: Attack = attack_down_scene.instantiate()
		big_shot_down.position = NavigationServer2D.map_get_random_point(
				get_world_2d().navigation_map, 1, false)
		big_shot_down.damage_multiplier = damage_multiplier
		big_shot_down.who = id
		big_shot_down.team = team
		big_shot_down.name += str(randi())
		_projectiles_parent.add_child(big_shot_down)
		if i + 1 != attack_down_count:
			_timer.start(attack_down_spawn_interval)
			await _timer.timeout


func _spawn_altar() -> void:
	var altar: Entity = altar_scene.instantiate()
	altar.id = -randi()
	altar.name += str(altar.id)
	altar.team = team
	altar.position = Vector2.ZERO
	get_parent().add_child(altar, true)


func _final_attack() -> void:
	make_immune()
	($CollisionShape2D as CollisionShape2D).disabled = true
	process_mode = Node.PROCESS_MODE_DISABLED
	
	var tween: Tween = get_parent().create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, ^":global_position", Vector2.ZERO, 1.0)
	await tween.finished
	hide()
	
	var final: Attack = attack_final_scene.instantiate()
	final.position = Vector2.ZERO
	final.team = team
	final.who = id
	final.damage_multiplier = damage_multiplier
	_projectiles_parent.add_child(final, true)
	
	await final.tree_exiting
	show()
	unmake_immune()
	($CollisionShape2D as CollisionShape2D).disabled = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_did_final_attack = true


func _on_cultist_died(cultist: Entity) -> void:
	var box: Node2D = attack_cultists_boxes_scenes[_box_idx].instantiate()
	box.position = cultist.global_position
	box.name += str(randi())
	world.other_parent.add_child(box, true)
	_box_idx += 1
	if _box_idx == attack_cultists_boxes_scenes.size():
		_box_idx = 0


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
