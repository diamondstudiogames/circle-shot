extends Weapon


const CANT_PLANT_TINT := Color(0.836, 0.366, 0.366)

var _planting := false
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _ray_cast: RayCast2D = $RayCast2D
@onready var _state: Label = $State
@onready var _bomb_defusal: BombDefusal = get_tree().get_first_node_in_group(&"world")


func _process(_delta: float) -> void:
	_state.scale.x = player.visual.scale.x


func _physics_process(_delta: float) -> void:
	if _can_plant():
		modulate = Color.WHITE
		if player.is_local():
			_state.text = "Закладываю..." if _planting \
					else "Удерживай СТРЕЛЯТЬ, чтобы заложить бомбу"
	else:
		modulate = CANT_PLANT_TINT
		if _planting and multiplayer.is_server():
			_stop_planting.rpc()
		if player.is_local():
			_state.text = "Не могу заложить бомбу %s" % ("сейчас" if not can_shoot() else "здесь")


func _initialize() -> void:
	_update_screen_marker_visibility()
	player.world.local_team_set.connect(_update_screen_marker_visibility.unbind(1))


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


func has_additional_button() -> bool:
	return true


func additional_button() -> void:
	if multiplayer.is_server():
		_remove_weapon.rpc()
		_bomb_defusal.bomb_drop(player.global_position)


func _player_disarmed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_DISABLED


func _player_armed() -> void:
	_anim.process_mode = Node.PROCESS_MODE_INHERIT


func get_ammo_text() -> String:
	return "Бомба"


@rpc("reliable", "authority", "call_local", 5)
func _start_planting() -> void:
	player.make_immobile()
	_anim.play(&"plant")
	_planting = true


@rpc("reliable", "authority", "call_local", 5)
func _stop_planting() -> void:
	_planting = false
	_anim.play(&"RESET")
	player.unmake_immobile()


@rpc("reliable", "authority", "call_local", 5)
func _remove_weapon() -> void:
	player.set_weapon(Weapon.Type.ADDITIONAL, null)


func _can_plant() -> bool:
	return _ray_cast.is_colliding() and can_shoot() and \
			(_ray_cast.get_collider() as Node).is_in_group(&"plant_zone")


func _update_screen_marker_visibility() -> void:
	($MarkersBase/ScreenMarker as CanvasItem).visible = player.world.local_team == Entity.Team.RED


func _on_player_shooting_started() -> void:
	if not multiplayer.is_server():
		return
	if not _can_plant():
		return
	
	_start_planting.rpc()
	var anim_name: StringName = await _anim.animation_finished
	if _planting: # мб было прервано
		_stop_planting.rpc()
	if anim_name != &"plant":
		return
	
	_bomb_defusal.bomb_plant(global_position + Vector2.DOWN * 32
			+ Vector2.LEFT * 32 * player.visual.scale.x, player.id)
	_remove_weapon.rpc()


func _on_player_shooting_ended() -> void:
	if multiplayer.is_server() and _planting:
		_stop_planting.rpc()
