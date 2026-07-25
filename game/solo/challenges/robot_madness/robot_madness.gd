class_name RobotMadness
extends Challenge

## Испытание "Рубка роботов".

## Издаётся, когда волна начинается.
signal wave_started
## Издаётся, когда волна заканчивается.
signal wave_ended
## Издаётся, когда игрок прокачивается.
signal player_upgraded

@export_group("Tweaks")
## Общее количество волн.
@export var total_waves_count: int = 20
## Кривая множителя урона, где домен - волна, значение - множитель.
@export var damage_multiplier_curve: Curve
## Кривая множителя здоровья, где домен - волна, значение - множитель.
@export var health_multiplier_curve: Curve
## Кривая множителя скорости, где домен - волна, значение - множитель.
@export var speed_multiplier_curve: Curve
## Кривая интервала появления роботов, где домен - волна, значение - интервал.
@export var spawn_interval_curve: Curve
## Кривая количества роботов в волне, где домен - волна, значение - количество.
@export var count_curve: Curve
## Минимальное расстояние до игрока, на котором должен находиться появившийся робот. Если не
## соблюдено, выбирается другая точка.
@export var safe_player_distance := 960.0
## Максимальное случайное отклонение от количества создаваемых роботов на волне.
@export var spawn_count_randomization: int = 1
## Максимальное случайное отклонение от интервала между появлением роботов.
@export var spawn_interval_randomization := 1.0

@export_group("Points")
## Сколько очков получит игрок за убийство, умножённое на [member Entity.speed_mulitplier] жертвы.
@export var points_for_speed_multiplier_base := 8.0
## Сколько очков получит игрок за убийство, умножённое на [member Entity.damage_mulitplier] жертвы.
@export var points_for_damage_multiplier_base := 15.0
## Сколько очков получит игрок за убийство, умножённое на [member Entity.max_health] жертвы.
@export var points_for_health_base := 0.1
## Раз в сколько очков появляется аптечка.
@export var points_for_heal_box: int = 50
## Раз в сколько очков появляется коробка с боеприпасами.
@export var points_for_ammo_box: int = 120

@export_group("Upgrades")
@export_subgroup("Health", "health_")
## На сколько процентов повышается здоровье за каждую прокачку.
@export var health_increase_per_upgrade := 0.2
## Базовая цена прокачки здоровья.
@export var health_cost_base: int = 20
## На сколько цена будет становиться больше за каждую прокачку здоровья.
@export var health_cost_per_upgrade: int = 5
## Максимальное количество прокачек здоровья.
@export var health_max_upgrades: int = 15

@export_subgroup("Damage", "damage_")
## На сколько процентов повышается урон за каждую прокачку.
@export var damage_increase_per_upgrade := 0.15
## Базовая цена прокачки урона.
@export var damage_cost_base: int = 25
## На сколько цена будет становиться больше за каждую прокачку урона.
@export var damage_cost_per_upgrade: int = 8
## Максимальное количество прокачек урона.
@export var damage_max_upgrades: int = 20

@export_subgroup("Defense", "defense_")
## На сколько будет повышаться защита за каждую прокачку.
@export var defense_increase_per_upgrade: int = 1
## Базовая цена прокачки защиты.
@export var defense_cost_base: int = 20
## На сколько цена будет становиться больше за каждую прокачку защиты.
@export var defense_cost_per_upgrade: int = 8
## Максимальное количество прокачек защиты.
@export var defense_max_upgrades: int = 10

@export_subgroup("Speed", "speed_")
## На сколько процентов будет повышаться скорость за каждую прокачку.
@export var speed_increase_per_upgrade := 0.1
## Базовая цена прокачки скорости.
@export var speed_cost_base: int = 30
## На сколько цена будет становиться больше за каждую прокачку скорости.
@export var speed_cost_per_upgrade: int = 10
## Максимальное количество прокачек скорости.
@export var speed_max_upgrades: int = 10

@export_group("Restore")
## Стоимость восстановления всех ОЗ.
@export var health_restore_cost_per_wave: int = 30
## Стоимость восстановления всех боеприпасов.
@export var ammo_restore_cost_per_wave: int = 25
## Сцена коробки с исцелением.
@export var _heal_box_scene: PackedScene
## Сцена коробки с боеприпасами.
@export var _ammo_box_scene: PackedScene

@export_group("Rewards")
## Сколько монет получит игрок за полное прохождение испытания.
@export var total_coins: int = 350
## Кривая сглаживания, по которой будет вычислена награда за пройденные волны.
@export_exp_easing var total_coins_ease := 2.0
## Сколько нужно получить очков, чтобы получить монету.
@export var points_for_coin := 5.0
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin := 50.0

## Текущая волна.
var current_wave: int = 0
## Сколько всего очков набрал игрок.
var total_points: int = 0
## Сколько очков сейчас на балансе.
var points: int = 0

## Сколько раз было прокачено здоровье.
var health_upgrades: int = 0
## Сколько раз был прокачен урон.
var damage_upgrades: int = 0
## Сколько раз была прокачена скорость.
var speed_upgrades: int = 0
## Сколько раз была прокачена защита.
var defense_upgrades: int = 0

var _spawn_points: Array[Node2D]
var _spawn_points_counter: int = 0
var _robot_counter: int = 0
var _alive_robots_counter: int = 0

var _heal_box_points_counter: int = 0
var _ammo_box_points_counter: int = 0

## Интерфейс этого испытания.
@onready var _robot_madness_ui: RobotMadnessUI = $UI
@onready var _spawn_timer: Timer = $SpawnTimer


func _initialize() -> void:
	_spawn_points.assign($Map/RobotsSpawnPoints.get_children())
	_spawn_points.shuffle()


func _finish_start() -> void:
	start_wave()


func _local_player_died() -> void:
	end_challenge(false)
	_spawn_timer.stop()


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	if is_instance_valid(local_player):
		rewards["Зачищенные волны"] = total_coins
	else:
		rewards["Зачищенные волны"] = roundi(total_coins
				* ease((current_wave - 1.0) / total_waves_count, total_coins_ease))
	rewards["Заработанные очки"] = roundi(total_points / points_for_coin)
	rewards["Нанесённый урон"] = roundi(damaged / damage_for_coin)
	return rewards


## Начинает следующую волну.
func start_wave() -> void:
	if current_wave != 0:
		unfreeze_entities()
		other_parent.process_mode = Node.PROCESS_MODE_INHERIT
	current_wave += 1
	wave_started.emit()
	_robot_madness_ui.start_wave()
	
	var robot_count: int = roundi(count_curve.sample(current_wave)) \
			+ randi_range(-spawn_count_randomization, spawn_count_randomization)
	var spawn_interval: float = spawn_interval_curve.sample(current_wave)
	_alive_robots_counter = robot_count
	for i: int in robot_count:
		if not is_instance_valid(local_player):
			break
		_spawn_robot()
		if i != robot_count - 1:
			_spawn_timer.start(spawn_interval
					+ randf_range(-spawn_interval_randomization, spawn_interval_randomization))
			await _spawn_timer.timeout


## Возвращает стоимоить прокачки здоровья.
## Возвращает [code]-1[/code], если достигнут максимум улучшений.
func get_health_upgrade_cost() -> int:
	if health_upgrades >= health_max_upgrades:
		return -1
	return health_cost_base + health_cost_per_upgrade * health_upgrades


## Возвращает стоимоить прокачки урона.
## Возвращает [code]-1[/code], если достигнут максимум улучшений.
func get_damage_upgrade_cost() -> int:
	if damage_upgrades >= damage_max_upgrades:
		return -1
	return damage_cost_base + damage_cost_per_upgrade * damage_upgrades


## Возвращает стоимоить прокачки здоровья.
## Возвращает [code]-1[/code], если достигнут максимум улучшений.
func get_defense_upgrade_cost() -> int:
	if defense_upgrades >= defense_max_upgrades:
		return -1
	return defense_cost_base + defense_cost_per_upgrade * defense_upgrades


## Возвращает стоимоить прокачки скорости.
## Возвращает [code]-1[/code], если достигнут максимум улучшений.
func get_speed_upgrade_cost() -> int:
	if speed_upgrades >= speed_max_upgrades:
		return -1
	return speed_cost_base + speed_cost_per_upgrade * speed_upgrades


## Прокачивает здоровье у игрока.
func upgrade_health() -> void:
	if not is_instance_valid(local_player):
		return
	local_player.max_health = get_player_max_health(true)
	health_upgrades += 1
	local_player.max_health = roundi(local_player.max_health
			* (1.0 + health_upgrades * health_increase_per_upgrade))
	local_player.heal(roundi(get_player_max_health(true) * health_increase_per_upgrade))
	player_upgraded.emit()


## Прокачивает урон у игрока.
func upgrade_damage() -> void:
	if not is_instance_valid(local_player):
		return
	local_player.damage_multiplier /= 1.0 + damage_upgrades * damage_increase_per_upgrade
	damage_upgrades += 1
	local_player.damage_multiplier *= 1.0 + damage_upgrades * damage_increase_per_upgrade
	player_upgraded.emit()


## Прокачивает скорость у игрока.
func upgrade_speed() -> void:
	if not is_instance_valid(local_player):
		return
	local_player.speed /= 1.0 + speed_upgrades * speed_increase_per_upgrade
	speed_upgrades += 1
	local_player.speed *= 1.0 + speed_upgrades * speed_increase_per_upgrade
	player_upgraded.emit()


## Прокачивает защиту у игрока.
func upgrade_defense() -> void:
	if not is_instance_valid(local_player):
		return
	defense_upgrades += 1
	local_player.get_node(^"Defense").set(
			&"defense", defense_upgrades * defense_increase_per_upgrade)
	player_upgraded.emit()


## Возвращает стоимость восстановления ОЗ у игрока. Возвращает [code]-1[/code], если ОЗ
## на максимуме.
func get_health_restore_cost() -> int:
	if not is_instance_valid(local_player) \
			or local_player.current_health == local_player.max_health:
		return -1
	return health_restore_cost_per_wave * current_wave


## Возвращает стоимость восстановления боеприпасов у игрока. Возвращает [code]-1[/code], если
## боеприпасы на максимуме.
func get_ammo_restore_cost() -> int:
	if not is_instance_valid(local_player):
		return -1
	for type: Weapon.Type in [
		Weapon.Type.LIGHT,
		Weapon.Type.HEAVY,
		Weapon.Type.SUPPORT,
		Weapon.Type.MELEE,
	]:
		var weapon := local_player.weapons.get_child(type) as Weapon
		if not weapon or weapon.ammo_total <= 0:
			continue
		if weapon.ammo_in_stock != weapon.ammo_total - weapon.ammo_per_load:
			return ammo_restore_cost_per_wave * current_wave
	return -1


## Восстанавливает все ОЗ у игрока.
func restore_health() -> void:
	if not is_instance_valid(local_player):
		return
	local_player.heal(local_player.max_health)


## Восстанавливает все боеприпасы у игрока.
func restore_ammo() -> void:
	if not is_instance_valid(local_player):
		return
	
	local_player.add_ammo_to_weapon.rpc(Weapon.Type.LIGHT, 1.0)
	local_player.add_ammo_to_weapon.rpc(Weapon.Type.HEAVY, 1.0)
	local_player.add_ammo_to_weapon.rpc(Weapon.Type.SUPPORT, 1.0)
	local_player.add_ammo_to_weapon.rpc(Weapon.Type.MELEE, 1.0)


## Возвращает максимальное здоровье игрока. Если [param default] равен [code]true[/code],
## то возвращает максимальное здоровье без прокачки.
func get_player_max_health(default: bool) -> int:
	if not is_instance_valid(local_player):
		return 0
	if default:
		return roundi(local_player.max_health
				/ (1.0 + health_upgrades * health_increase_per_upgrade))
	return local_player.max_health


func _end_wave() -> void:
	wave_ended.emit()
	if current_wave == total_waves_count:
		end_challenge(true)
		return
	_robot_madness_ui.end_wave()
	freeze_entities()
	other_parent.process_mode = Node.PROCESS_MODE_DISABLED # чтобы коробки не деспавнились


func _spawn_robot() -> void:
	var robot: Entity = entity_scenes[1 + _robot_counter].instantiate()
	var spawn_pos: Vector2 = _spawn_points[_spawn_points_counter].global_position
	
	# защита от спавна за спиной
	if is_instance_valid(local_player):
		while spawn_pos.distance_to(local_player.global_position) < safe_player_distance:
			_spawn_points_counter += 1
			if _spawn_points_counter == _spawn_points.size():
				_spawn_points_counter = 0
				_spawn_points.shuffle()
			spawn_pos = _spawn_points[_spawn_points_counter].global_position
	
	robot.position = spawn_pos
	robot.team = Entity.Team.BLUE
	robot.id = -randi()
	robot.name += str(robot.id)
	robot.max_health = roundi(robot.max_health * health_multiplier_curve.sample(current_wave))
	robot.damage_multiplier = damage_multiplier_curve.sample(current_wave)
	robot.speed_multiplier = speed_multiplier_curve.sample(current_wave)
	robot.died.connect(_on_robot_died.bind(robot))
	entities_parent.add_child(robot, true)
	
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
	other_parent.add_child(heal_box, true)


func _spawn_ammo_box(where: Vector2) -> void:
	var ammo_box: Node2D = _ammo_box_scene.instantiate()
	ammo_box.position = where
	ammo_box.name += str(randi())
	other_parent.add_child(ammo_box, true)


func _on_robot_died(robot: Entity) -> void:
	var got_points: int = roundi(robot.damage_multiplier * points_for_damage_multiplier_base) \
			+ roundi(robot.speed_multiplier * points_for_speed_multiplier_base) \
			+ roundi(robot.max_health * points_for_health_base)
	points += got_points
	total_points += got_points
	stats_changed.emit()
	
	_heal_box_points_counter += got_points
	_ammo_box_points_counter += got_points
	if _heal_box_points_counter >= points_for_heal_box \
			and _ammo_box_points_counter < points_for_ammo_box:
		_heal_box_points_counter = 0
		_spawn_heal_box(robot.global_position)
	elif _ammo_box_points_counter >= points_for_ammo_box \
			and _heal_box_points_counter < points_for_heal_box:
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
	
	_alive_robots_counter -= 1
	if _alive_robots_counter == 0:
		_end_wave()


func _on_stats_changed() -> void:
	_robot_madness_ui.update_stats()
