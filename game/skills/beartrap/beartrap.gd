extends Skill

@export var trap_scene: PackedScene
var _use_vfx_scene: PackedScene = preload("uid://dxfkmwyd21cng")

func _use() -> void:
	var use_vfx: Node2D = _use_vfx_scene.instantiate()
	player.visual.add_child(use_vfx)
	block_cooldown()
	($PlaceTimer as Timer).start()


func _on_place_timer_timeout() -> void:
	unblock_cooldown()
	if not multiplayer.is_server():
		return
	var trap: Attack = trap_scene.instantiate()
	trap.position = player.global_position + Vector2.DOWN * 40
	trap.team = player.team
	trap.who = player.id
	trap.damage_multiplier = player.damage_multiplier
	trap.name += str(randi())
	_other_parent.add_child(trap, true)


func _player_disarmed() -> void:
	if player.visual.has_node(^"BeartrapUseVfx"):
		player.visual.get_node(^"BeartrapUseVfx").process_mode = Node.PROCESS_MODE_DISABLED
	($PlaceTimer as Timer).paused = true


func _player_armed() -> void:
	if player.visual.has_node(^"BeartrapUseVfx"):
		player.visual.get_node(^"BeartrapUseVfx").process_mode = Node.PROCESS_MODE_INHERIT
	($PlaceTimer as Timer).paused = false
