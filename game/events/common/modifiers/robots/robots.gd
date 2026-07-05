extends EventModifier

@export var robots_scenes: Array[PackedScene]
@export var boxes_scenes: Array[PackedScene]
var _box_idx: int = 0

func _initialize() -> void:
	if multiplayer.is_server():
		($Timer as Timer).start()


func _spawn_robot() -> void:
	var spawn_pos: Vector2 = _get_robot_spawn_position()
	if spawn_pos.is_zero_approx():
		return # ну негде
	
	var robot_scene: PackedScene = robots_scenes.pick_random()
	var robot: Mob = robot_scene.instantiate()
	robot.team = 10
	robot.position = spawn_pos
	robot.id = -randi()
	robot.name += str(robot.id)
	robot.died.connect(_on_robot_died, CONNECT_APPEND_SOURCE_OBJECT)
	get_tree().get_first_node_in_group(&"entities_parent").add_child(robot, true)


func _get_robot_spawn_position() -> Vector2:
	var game_zone: Rect2 = event.get_game_zone()
	var test_shape := RectangleShape2D.new()
	test_shape.size = Vector2.ONE * 76
	var tested_points: Array[Vector2]
	while true:
		var point: Vector2 = game_zone.get_center() \
				+ game_zone.size * Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		point = point.snappedf(World.BLOCK_SIZE) + Vector2.ONE * World.BLOCK_SIZE / 2
		if point in tested_points:
			break # нельзя такое
		
		var params := PhysicsShapeQueryParameters2D.new()
		params.collide_with_areas = true
		params.collision_mask = 49 # World, Fence и Items
		params.shape = test_shape
		params.transform = Transform2D(0.0, point)
		var results: Array[Dictionary] = PhysicsServer2D.space_get_direct_state(
				get_viewport().find_world_2d().space).intersect_shape(params, 1)
		if results.is_empty():
			return point
		tested_points.append(point)
	
	return Vector2()


func _on_robot_died(robot: Mob) -> void:
	var box: Node2D = boxes_scenes[_box_idx].instantiate()
	box.position = robot.global_position
	box.name += str(randi())
	get_tree().get_first_node_in_group(&"other_parent").add_child(box, true)
	
	_box_idx += 1
	if _box_idx == boxes_scenes.size():
		_box_idx = 0


func _on_timer_timeout() -> void:
	_spawn_robot()
