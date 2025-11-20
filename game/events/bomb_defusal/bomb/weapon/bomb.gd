extends Weapon


const CANT_PLANT_TINT := Color(0.702, 0.524, 0.524, 1.0)

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _ray_cast: RayCast2D = $RayCast2D
@onready var _bomb_defusal: BombDefusal = get_tree().get_first_node_in_group(&"world")


func _physics_process(_delta: float) -> void:
	if _can_plant():
		modulate = Color.WHITE
	else:
		modulate = CANT_PLANT_TINT


func _make_current() -> void:
	_ray_cast.force_raycast_update()
	player.player_input.shooting_started.connect(_on_player_shooting_started)
	player.player_input.shooting_ended.connect(_on_player_shooting_ended)
	block_shooting()
	_anim.play(&"equip")
	_anim.advance(0.0)
	await _anim.animation_finished
	unblock_shooting()


func _unmake_current() -> void:
	_anim.play(&"RESET")
	_anim.advance(0.0)
	player.player_input.shooting_started.disconnect(_on_player_shooting_started)
	player.player_input.shooting_ended.disconnect(_on_player_shooting_ended)


func _can_reload() -> bool:
	return false


func _player_disarmed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_DISABLED


func _player_armed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_INHERIT


func get_ammo_text() -> String:
	return "Бомба"


@rpc("reliable", "authority", "call_local", 5)
func _remove_weapon() -> void:
	player.unmake_immobile()
	player.set_weapon(Weapon.Type.ADDITIONAL, null)


func _can_plant() -> bool:
	return _ray_cast.is_colliding() and can_shoot() and \
			(_ray_cast.get_collider() as Node).is_in_group(&"plant_zone")


func _on_player_shooting_started() -> void:
	if not _can_plant():
		return
	player.make_immobile()
	_anim.play(&"plant")
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"plant":
		player.unmake_immobile()
		return
	
	if multiplayer.is_server():
		_bomb_defusal.bomb_plant(global_position + Vector2.DOWN * 32
				+ Vector2.LEFT * 32 * player.visual.scale.x)
		_remove_weapon.rpc()
	if player.is_local():
		_bomb_defusal.bombs_planted_defused += 1


func _on_player_shooting_ended() -> void:
	_anim.play(&"RESET")
