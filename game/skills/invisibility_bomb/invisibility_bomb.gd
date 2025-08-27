extends Skill

@export var duration := 4.0
var _use_vfx_scene: PackedScene = load("uid://7yeuewjt5nf4")
@onready var _timer: Timer = $Timer

func _use() -> void:
	block_cooldown()
	var use_vfx: Node2D = _use_vfx_scene.instantiate()
	player.visual.add_child(use_vfx)
	_timer.start(0.5)
	await _timer.timeout
	if multiplayer.is_server():
		player.add_effect.rpc(Effect.INVISIBILITY, duration)
	_timer.start(duration)
	await _timer.timeout
	unblock_cooldown()


func _player_disarmed() -> void:
	if player.visual.has_node(^"InvisibilityBombUseVfx"):
		player.visual.get_node(^"InvisibilityBombUseVfx").process_mode = Node.PROCESS_MODE_DISABLED
	if not is_equal_approx(_timer.wait_time, duration): # эффект ещё не наложен
		_timer.paused = true


func _player_armed() -> void:
	if player.visual.has_node(^"InvisibilityBombUseVfx"):
		player.visual.get_node(^"InvisibilityBombUseVfx").process_mode = Node.PROCESS_MODE_INHERIT
	if not is_equal_approx(_timer.wait_time, duration):
		_timer.paused = false
