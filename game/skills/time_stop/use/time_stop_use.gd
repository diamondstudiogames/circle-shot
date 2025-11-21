extends Node2D

@onready var _world: World = get_tree().get_first_node_in_group(&"world")

func _exit_tree() -> void:
	if _world.process_mode != PROCESS_MODE_INHERIT:
		resume_time()


func stop_time() -> void:
	_world.get_node(^"UI").process_mode = Node.PROCESS_MODE_PAUSABLE
	_world.get_node(^"Camera").process_mode = Node.PROCESS_MODE_PAUSABLE
	_world.process_mode = Node.PROCESS_MODE_DISABLED


func resume_time() -> void:
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	_world.get_node(^"UI").process_mode = Node.PROCESS_MODE_INHERIT
	_world.get_node(^"Camera").process_mode = Node.PROCESS_MODE_INHERIT


func safe_free() -> void:
	if multiplayer.is_server():
		queue_free()
