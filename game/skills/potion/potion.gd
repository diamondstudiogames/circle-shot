extends Skill

@export var heal_amount: int = 60
var _use_vfx_scene: PackedScene = load("uid://c1jxj44vodfa7")
@onready var _timer: Timer = $Timer

func _use() -> void:
	var use_vfx: Node2D = _use_vfx_scene.instantiate()
	player.visual.add_child(use_vfx)
	if player.is_local():
		(use_vfx.get_node(^"Tint/AnimationPlayer") as AnimationPlayer).play(&"tint")
	
	block_cooldown()
	player.block_weapon_usage()
	if multiplayer.is_server():
		_timer.start(1.25)
		await _timer.timeout
		player.heal(ceili(heal_amount / 3.0))
		_timer.start(0.2)
		await _timer.timeout
		player.heal(roundi(heal_amount / 3.0))
		_timer.start(0.2)
		await _timer.timeout
		player.heal(floori(heal_amount / 3.0))
		_timer.start(1.05)
		await _timer.timeout
	else:
		_timer.start(2.5)
		await _timer.timeout
	player.unblock_weapon_usage()
	unblock_cooldown()


func _can_use() -> bool:
	return player.current_health != player.max_health


func _player_disarmed() -> void:
	if player.visual.has_node(^"PotionUseVfx"):
		player.visual.get_node(^"PotionUseVfx").process_mode = Node.PROCESS_MODE_DISABLED
	_timer.paused = true


func _player_armed() -> void:
	if player.visual.has_node(^"PotionUseVfx"):
		player.visual.get_node(^"PotionUseVfx").process_mode = Node.PROCESS_MODE_INHERIT
	_timer.paused = false
