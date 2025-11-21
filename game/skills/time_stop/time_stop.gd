extends Skill

var _use_scene: PackedScene = load("uid://bquhtboou21kv")
@onready var _timer: Timer = $Timer

func _use() -> void:
	block_cooldown()
	player.make_immobile()
	player.block_weapon_usage()
	player.block_turning()
	
	($AnimationPlayer as AnimationPlayer).play(&"use")
	_timer.start(1.0)
	await _timer.timeout
	
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if multiplayer.is_server():
		var time_stop_use: Node2D = _use_scene.instantiate()
		time_stop_use.position = player.global_position
		_other_parent.add_child(time_stop_use, true)
		time_stop_use.tree_exiting.connect(_on_time_stop_use_tree_exiting)
	
	_timer.start(1.0)
	await _timer.timeout
	player.unmake_immobile()
	player.unblock_weapon_usage()
	player.unblock_turning()
	player.z_index = 10


func _player_disarmed() -> void:
	if is_equal_approx(_timer.wait_time, 0.5): # тайм стоп ещё не начался
		_timer.paused = true
		$AnimationPlayer.process_mode = Node.PROCESS_MODE_DISABLED


func _player_armed() -> void:
	if is_equal_approx(_timer.wait_time, 0.5):
		_timer.paused = false
		$AnimationPlayer.process_mode = Node.PROCESS_MODE_INHERIT


@rpc("reliable", "authority", "call_local", 3)
func _end_time_stop() -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.z_index = 0
	unblock_cooldown()


func _on_time_stop_use_tree_exiting() -> void:
	if not is_queued_for_deletion() and multiplayer.has_multiplayer_peer():
		_end_time_stop.rpc()
