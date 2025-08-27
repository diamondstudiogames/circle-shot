extends Weapon


@export var teleport_distance := 800.0

var _reloading := false
var _no_ammo := false
var _teleport_vfx_scene: PackedScene = load("uid://2p44r4a1hf7")

@onready var _buttons: Node2D = $Visual/Base/Buttons
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _aim: Sprite2D = $Aim
@onready var _collision_check: ShapeCast2D = $CollisionCheck
@onready var _border_check: RayCast2D = $BorderCheck
@onready var _reload_timer: Timer = $ReloadTimer
@onready var _reload_indicator: TextureProgressBar = $Visual/Base/ReloadIndicator


func _process(_delta: float) -> void:
	_aim.visible = can_shoot() and player.player_input.showing_aim
	
	if _aim.visible:
		_update_casts()
		_aim.global_position = _collision_check.global_position
		_aim.self_modulate = Color.RED if _collision_check.is_colliding() or \
				_border_check.is_colliding() else Color.WHITE
	
	if _reload_indicator.visible:
		if player.is_local():
			_reload_indicator.value = 1.0 - _reload_timer.time_left / _reload_timer.wait_time
		else:
			_reload_indicator.value = 0.0


func _physics_process(_delta: float) -> void:
	if can_shoot() and multiplayer.is_server() and player.player_input.shooting \
			and ammo_in_stock > 0 and not _reloading:
		_update_casts()
		shoot(not _collision_check.is_colliding() and not _border_check.is_colliding())


func _initialize() -> void:
	_collision_check.add_exception(player)


func _shoot(success := false) -> void:
	if not success:
		block_shooting()
		_anim.play(&"fail")
		await _anim.animation_finished
		unblock_shooting()
		return
	
	var destination: Vector2
	if multiplayer.is_server():
		destination = player.global_position + player.entity_input.aim_direction * teleport_distance
	
	block_shooting()
	_anim.play("use%d" % (randi() % 3))
	var anim_name: StringName = await _anim.animation_finished
	if not anim_name.begins_with("use"):
		unblock_shooting()
		return
	
	if multiplayer.is_server():
		_show_teleport_vfx.rpc(player.global_position, false)
		player.teleport_to.rpc(destination)
		_show_teleport_vfx.rpc(destination)
	
	_anim.play(&"post_use")
	
	_buttons.modulate = Color.WEB_GRAY
	ammo_in_stock -= 1
	_reloading = true
	_reload_timer.start()
	_reload_indicator.show()
	_reload_indicator.value = 0.0


func _make_current() -> void:
	_anim.play(&"equip")
	_anim.advance(0.0)
	if ammo_in_stock > 0 and not _reloading:
		block_shooting()
		await _anim.animation_finished
		unblock_shooting()


func _unmake_current() -> void:
	_anim.play(&"RESET")
	_anim.advance(0.01)


func _can_reload() -> bool:
	return false


func _player_disarmed() -> void:
	# нет смысла пропускать
	if _anim.is_playing() and not _anim.current_animation in [&"equip", &"post_use"]:
		_anim.play(&"RESET")
	_reload_timer.paused = true


func _player_armed() -> void:
	_reload_timer.paused = false


func _ammo_changed(in_stock: bool) -> void:
	if not in_stock:
		return
	if _no_ammo and ammo_in_stock > 0:
		_no_ammo = false
		unblock_shooting()
		_buttons.modulate = Color.WHITE


func get_ammo_text() -> String:
	return "Осталось: %d" % ammo_in_stock


@rpc("unreliable", "authority", "call_local", 5)
func _show_teleport_vfx(where: Vector2, play_sfx := true) -> void:
	var teleport_vfx: Node2D = _teleport_vfx_scene.instantiate()
	teleport_vfx.position = where
	if not play_sfx:
		teleport_vfx.get_node(^"AudioStreamPlayer2D").free()
	get_tree().get_first_node_in_group(&"vfx_parent").add_child(teleport_vfx)


func _update_casts() -> void:
	_collision_check.global_position = player.global_position \
			+ player.entity_input.aim_direction * teleport_distance
	_collision_check.force_shapecast_update()
	
	_border_check.global_position = player.global_position
	_border_check.target_position = player.entity_input.aim_direction * teleport_distance
	_border_check.force_raycast_update()


func _on_cooldown_timer_timeout() -> void:
	_reloading = false
	_reload_indicator.hide()
	if ammo_in_stock > 0:
		unblock_shooting()
		_buttons.modulate = Color.WHITE
	else:
		_no_ammo = true
