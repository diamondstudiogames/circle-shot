extends Skill


@export_range(0.0, 1.0) var speed_boost := 0.15
@export_range(0.0, 1.0) var damage_boost := 0.1
@export_range(0.0, 1.0) var defense_boost := 0.1
@export var boost_duration := 5.0
@export var shake_amplitude := 32.0
@export var shake_duration := 0.6

var _use_vfx_scene: PackedScene = load("uid://c7rmbgdh6weme")
@onready var _timer: Timer = $Timer


func _use() -> void:
	var use_vfx: Node2D = _use_vfx_scene.instantiate()
	player.visual.add_child(use_vfx)
	
	block_cooldown()
	player.block_weapon_usage()
	_timer.start(1.25)
	await _timer.timeout
	if multiplayer.is_server():
		player.add_effect.rpc(Effect.DEFENSE_CHANGE, boost_duration, [1.0 - defense_boost])
		player.add_effect.rpc(Effect.SPEED_CHANGE, boost_duration, [1.0 + speed_boost])
		player.add_effect.rpc(Effect.DAMAGE_CHANGE, boost_duration, [1.0 + damage_boost])
	if player.is_local():
		(get_viewport().get_camera_2d() as SmartCamera).shake(shake_amplitude, shake_duration)
	_timer.start(0.35)
	await _timer.timeout
	player.unblock_weapon_usage()
	_timer.start(boost_duration - 0.35)
	await _timer.timeout
	unblock_cooldown()


func _player_disarmed() -> void:
	if player.visual.has_node(^"EnergyDrinkUseVfx"):
		player.visual.get_node(^"EnergyDrinkUseVfx").process_mode = Node.PROCESS_MODE_DISABLED
	if is_equal_approx(_timer.wait_time, 1.25): # эффект ещё не наложен
		_timer.paused = true


func _player_armed() -> void:
	if player.visual.has_node(^"EnergyDrinkUseVfx"):
		player.visual.get_node(^"EnergyDrinkUseVfx").process_mode = Node.PROCESS_MODE_INHERIT
	if is_equal_approx(_timer.wait_time, 1.25):
		_timer.paused = false
