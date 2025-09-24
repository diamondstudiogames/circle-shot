class_name RobotMadness
extends Challenge

## Испытание "Рубка роботов".

@export_group("Tweaks")
## Кривая множителя урона, где домен - время, значение - множитель.
@export var damage_multiplier_curve: Curve
## Кривая множителя здоровья, где домен - время, значение - множитель.
@export var health_multiplier_curve: Curve
## Кривая множителя скорости, где домен - время, значение - множитель.
@export var speed_multiplier_curve: Curve
## Кривая интервала между появлениями роботов, где домен - время, значение - интервал.
@export var spawn_interval_curve: Curve
## Раз в сколько очков появляется аптечка.
@export var points_for_heal_box: int = 50
## Раз в сколько очков появляется коробка с боеприпасами.
@export var points_for_ammo_box: int = 120

@export_group("Rewards")
## Сколько нужно выжить в секундах, чтобы получить монету.
@export var seconds_survived_for_coin := 2.0
## Сколько нужно получить очков, чтобы получить монету.
@export var points_for_coin := 5.0
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin := 50.0
## Сколько очков получит игрок за убийство, умножённое на [member Entity.speed_mulitplier] жертвы.
@export var points_for_speed_multiplier_base := 8.0
## Сколько очков получит игрок за убийство, умножённое на [member Entity.damage_mulitplier] жертвы.
@export var points_for_damage_multiplier_base := 15.0
## Сколько очков получит игрок за убийство, умножённое на [member Entity.max_health] жертвы.
@export var points_for_health_base := 0.1

## Сколько секунд игрок прожил.
var time_survived: int = 0
## Сколько очков набрал игрок.
var points: int = 0

var _spawn_points: Array[Node2D]
var _spawn_points_counter: int = 0
var _robot_counter: int = 0

var _heal_box_points_counter: int = 0
var _ammo_box_points_counter: int = 0
var _heal_box_scene: PackedScene = load("uid://bysyaaj2r7stt")
var _ammo_box_scene: PackedScene = load("uid://bdtqr6mv231py")

## Интерфейс этого испытания.
@onready var robot_madness_ui: RobotMadnessUI = $UI
@onready var _survived_timer: Timer = $SurvivedTimer
@onready var _spawn_timer: Timer = $SpawnTimer


func _initialize() -> void:
	_spawn_points.assign($Map/RobotsSpawnPoints.get_children())
	_spawn_points.shuffle()


func _finish_start() -> void:
	_survived_timer.start()
	_spawn_timer.start(spawn_interval_curve.sample(0.0))


func _local_player_died() -> void:
	end_challenge(false)
	_spawn_timer.stop()
	_survived_timer.stop()


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	rewards["Прожито времени"] = roundi(time_survived / seconds_survived_for_coin)
	rewards["Очки"] = roundi(points / points_for_coin)
	rewards["Нанесённый урон"] = roundi(damaged / damage_for_coin)
	return rewards


func _spawn_robot() -> void:
	var robot: Entity = entity_scenes[1 + _robot_counter].instantiate()
	robot.position = _spawn_points[_spawn_points_counter].global_position
	robot.team = 1
	robot.id = -randi()
	robot.name += str(robot.id)
	robot.max_health = roundi(robot.max_health * health_multiplier_curve.sample(time_survived))
	robot.damage_multiplier = damage_multiplier_curve.sample(time_survived)
	robot.speed_multiplier = speed_multiplier_curve.sample(time_survived)
	robot.died.connect(_on_robot_died.bind(robot))
	$Entities.add_child(robot, true)
	
	_spawn_points_counter += 1
	if _spawn_points_counter == _spawn_points.size():
		_spawn_points_counter = 0
		_spawn_points.shuffle()
	_robot_counter += 1
	if _robot_counter == entity_scenes.size() - 1:
		_robot_counter = 0


func _spawn_heal_box(where: Vector2) -> void:
	var heal_box: Node2D = _heal_box_scene.instantiate()
	heal_box.position = where
	heal_box.name += str(randi())
	$Other.add_child(heal_box, true)


func _spawn_ammo_box(where: Vector2) -> void:
	var ammo_box: Node2D = _ammo_box_scene.instantiate()
	ammo_box.position = where
	ammo_box.name += str(randi())
	$Other.add_child(ammo_box, true)


func _on_robot_died(robot: Entity) -> void:
	var got_points: int = roundi(robot.damage_multiplier * points_for_damage_multiplier_base) \
			+ roundi(robot.speed_multiplier * points_for_speed_multiplier_base) \
			+ roundi(robot.max_health * points_for_health_base)
	points += got_points
	stats_changed.emit()
	
	_heal_box_points_counter += got_points
	_ammo_box_points_counter += got_points
	if _heal_box_points_counter >= points_for_heal_box \
			and _ammo_box_points_counter < points_for_ammo_box:
		_heal_box_points_counter = 0
		_spawn_heal_box(robot.global_position)
	elif _ammo_box_points_counter < points_for_ammo_box \
			and _heal_box_points_counter >= points_for_heal_box:
		_ammo_box_points_counter = 0
		_spawn_ammo_box(robot.global_position)
	elif _heal_box_points_counter >= points_for_heal_box \
			and _ammo_box_points_counter >= points_for_ammo_box:
		if _ammo_box_points_counter > _heal_box_points_counter:
			_spawn_ammo_box(robot.global_position)
		elif _heal_box_points_counter > _ammo_box_points_counter:
			_spawn_heal_box(robot.global_position)
		else:
			if randi() % 2 == 0:
				_spawn_heal_box(robot.global_position)
			else:
				_spawn_ammo_box(robot.global_position)
		_ammo_box_points_counter = 0
		_heal_box_points_counter = 0


func _on_stats_changed() -> void:
	robot_madness_ui.set_stats(damaged, points, time_survived)


func _on_survived_timer_timeout() -> void:
	time_survived += 1
	stats_changed.emit()


func _on_spawn_timer_timeout() -> void:
	_spawn_robot()
	_spawn_timer.start(spawn_interval_curve.sample(time_survived))
