extends Entity


@export_range(0.01, 2.0, 0.01) var area_damage_multiplier := 1.0
@export_range(0.01, 2.0, 0.01) var area_speed_multiplier := 1.0
@export var fireball_scene: PackedScene
@export var fireballs_count: int = 8
@export var heal_box_scene: PackedScene
@export var ammo_box_scene: PackedScene

var _entities: Array[Entity]

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _projectiles_spawn_point: Marker2D = $ProjectilesSpawnPoint
@onready var _projectiles_parent: Node2D = get_tree().get_first_node_in_group(&"projectiles_parent")


func _health_changed(_old_value: int, _new_value: int) -> void:
	if not _anim.is_playing():
		_anim.play(&"hurt")


func _on_power_area_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	var entity := body as Entity
	if entity and entity.team == team and entity != self:
		entity.add_timeless_effect.rpc(Effect.DAMAGE_CHANGE, [area_damage_multiplier])
		entity.add_timeless_effect.rpc(Effect.SPEED_CHANGE, [area_speed_multiplier])
		_entities.append(entity)


func _on_power_area_body_exited(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	var entity := body as Entity
	if entity and entity in _entities:
		_entities.erase(entity)
		entity.remove_timeless_effect.rpc(Effect.DAMAGE_CHANGE)
		entity.remove_timeless_effect.rpc(Effect.SPEED_CHANGE)


func _on_projectiles_timer_timeout() -> void:
	var angle_interval: float = PI * 2 / fireballs_count
	var base_angle: float = randf_range(0.0, angle_interval)
	for i: int in fireballs_count:
		var fireball: Projectile = fireball_scene.instantiate()
		fireball.position = _projectiles_spawn_point.global_position
		fireball.rotation = base_angle + angle_interval * i
		fireball.team = team
		fireball.who = id
		fireball.damage_multiplier = damage_multiplier
		fireball.name += str(randi())
		_projectiles_parent.add_child(fireball)


func _on_killed(_by: int, _remained_health: int) -> void:
	var heal_box: Node2D = heal_box_scene.instantiate()
	heal_box.position = global_position + Vector2.RIGHT * World.BLOCK_SIZE
	heal_box.name += str(randi())
	get_tree().get_first_node_in_group(&"other_parent").add_child(heal_box, true)
	
	var ammo_box: Node2D = ammo_box_scene.instantiate()
	ammo_box.position = global_position + Vector2.LEFT * World.BLOCK_SIZE
	ammo_box.name += str(randi())
	get_tree().get_first_node_in_group(&"other_parent").add_child(ammo_box, true)
