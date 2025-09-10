class_name  StandardMob
extends Mob

## Стандартный моб.
##
## Довольно простой моб, преследующий цель, с разными параметрами для настройки.
## Непосредственно стрельбу не реализует - это нужно сделать в унаследованных скриптах.

## Перечисление состояний моба.
enum State {
	## Моб идёт к цели.
	CHASING = 0,
	## Моб стоит на месте.
	STANDING = 1,
	## Моб отступает.
	RETREATING = 2,
}

## Интервал между выстрелами.
@export var shoot_interval := 0.5
## Значение, на которое будет интерполироваться угол [member EntityInput.aim_direction] каждый
## физический кадр.
@export_range(0.01, 1.0, 0.01, "exp") var aim_angle_rotation_weight := 0.1

@export_group("Distances")
## При приближается к цели на указаную дистанцию моб перестаёт двигаться.
@export var optimal_distance := 480.0
## Если цель подойдёт на расстояние меньшее, чем указанное, моб начнёт отступать.
@export var min_distance := 240.0
## Дистанция, с которой моб стреляет в цель.
@export var shoot_distance := 640.0
## Радиус области, в пределах которой будет ходить моб, если у него нет цели.
@export var random_walk_area_radius := 1280.0

## Состояние моба.
var state: State

var _shooting := false
var _shoot_timer := 0.0
var _last_no_target_position: Vector2


func _ready() -> void:
	entity_input.turn_with_aim = true
	_shoot_timer = shoot_interval
	_last_no_target_position = global_position
	agent.navigation_finished.connect(_on_agent_navigation_finished)
	super()
	await get_tree().physics_frame
	_select_random_point.call_deferred()


func _process_logic() -> void:
	var distance_to_target: float = target.global_position.distance_to(global_position)
	var direction_to_target: Vector2 = global_position.direction_to(target.global_position)
	if distance_to_target < min_distance:
		state = State.RETREATING
	
	match state:
		State.STANDING:
			entity_input.move_direction = Vector2.ZERO
		State.CHASING:
			if not agent.is_navigation_finished():
				entity_input.move_direction = \
						global_position.direction_to(agent.get_next_path_position())
		State.RETREATING:
			entity_input.move_direction = -direction_to_target
	
	entity_input.aim_direction = Vector2.from_angle(lerp_angle(entity_input.aim_direction.angle(),
			direction_to_target.angle(), aim_angle_rotation_weight))
	
	if not is_disarmed():
		_shoot_timer -= get_physics_process_delta_time()
		if _shoot_timer <= 0.0 and _shooting:
			_do_shoot.rpc(_get_shoot_args())
			_shoot_timer = shoot_interval


func _process_logic_no_target() -> void:
	if not agent.is_navigation_finished():
		entity_input.move_direction = global_position.direction_to(agent.get_next_path_position())


func _target_updated() -> void:
	entity_input.turn_with_aim = true
	var distance_to_target: float = target.global_position.distance_to(global_position)
	_shooting = distance_to_target <= shoot_distance and not target_ray_cast.is_colliding()
	
	if not _shooting or distance_to_target > optimal_distance:
		agent.target_position = target.global_position
		state = State.CHASING
	else:
		state = State.STANDING


func _target_reset() -> void:
	_shooting = false
	entity_input.turn_with_aim = false
	if agent.is_navigation_finished() and is_inside_tree():
		_select_random_point()


@rpc("authority", "call_local", "reliable", 5)
func _do_shoot(args: Array) -> void:
	_shoot.callv(args)


func _select_random_point() -> void:
	var random_point := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() \
			* randf_range(0.0, random_walk_area_radius) + _last_no_target_position
	agent.target_position = NavigationServer2D.map_get_closest_point(
			get_world_2d().navigation_map, random_point)


## Виртуальный метод. Здесь должна быть размещена логика стрельбы. Вызывается на всех клиентах.
func _shoot() -> void:
	pass


## Метод для переопределения. Возвращаемые аргументы будут переданы в [method _shoot].
func _get_shoot_args() -> Array:
	return []


func _on_agent_navigation_finished() -> void:
	if is_instance_valid(target):
		return
	_select_random_point()
