extends Skill


@export var projectile_scene: PackedScene
@export var spread_base := 1.0
@export var spread_walk := 3.0
@export_range(0.0, 1.0) var spread_walk_ratio := 0.3

@onready var _aim: Line2D = $Aim
@onready var _spread_left: Line2D = $Aim/SpreadLeft
@onready var _spread_right: Line2D = $Aim/SpreadRight


func _process(_delta: float) -> void:
	if player.is_local() \
			and player.player_input.shooting_started.is_connected(_on_player_shooting_started):
		_aim.rotation = player.entity_input.aim_direction.angle()
		_aim.visible = player.player_input.showing_aim
		
		_spread_left.rotation_degrees = -_calculate_spread()
		_spread_right.rotation_degrees = _calculate_spread()


func _use() -> void:
	($ActiveMarker/AnimationPlayer as AnimationPlayer).play(&"active")
	player.player_input.shooting_started.connect(_on_player_shooting_started)
	block_cooldown()


func _can_use() -> bool:
	return is_instance_valid(player.current_weapon) \
			and not player.player_input.shooting_started.is_connected(_on_player_shooting_started)


func _calculate_spread() -> float:
	return spread_base + spread_walk * clampf((player.get_real_velocity().length() / player.speed
			- spread_walk_ratio) / (1.0 - spread_walk_ratio), 0.0, 1.0)


func _on_player_shooting_started() -> void:
	if not player.can_use_weapon():
		return
	
	player.player_input.shooting_started.disconnect(_on_player_shooting_started)
	unblock_cooldown()
	($ActiveMarker/AnimationPlayer as AnimationPlayer).play(&"RESET")
	if multiplayer.is_server():
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.position = player.global_position + 64 * Vector2.from_angle(
				player.entity_input.aim_direction.angle())
		projectile.damage_multiplier = player.damage_multiplier
		var spread: float = deg_to_rad(_calculate_spread())
		projectile.rotation = player.entity_input.aim_direction.angle() \
				+ randf_range(-spread, spread)
		projectile.team = player.team
		projectile.who = player.id
		projectile.name += str(randi())
		_other_parent.add_child(projectile, true)
	
	if player.is_local():
		_aim.hide()
