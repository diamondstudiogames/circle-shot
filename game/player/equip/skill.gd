class_name Skill
extends Node2D

## Узел навыка.

## Определяет, сколько раз можно использовать навык.
@export var use_times: int = 2
## Задаёт время отката навыка.
@export var use_cooldown: int = 30
## Информация о навыке.
var data: SkillData
## Ссылка на игрока.
var player: Player

var _cooldown_timer := 0.0
var _blocked_cooldown_counter: int = 0
@warning_ignore("unused_private_class_variable") # Для дочерних классов
@onready var _other_parent: Node2D = get_tree().get_first_node_in_group(&"other_parent")


func _physics_process(delta: float) -> void:
	if not is_cooldown_blocked() and player.can_use_weapon():
		if _cooldown_timer > player.skill_vars[1]:
			_cooldown_timer = player.skill_vars[1]
		_cooldown_timer -= delta
	player.skill_vars[1] = ceili(_cooldown_timer)


## Инициализирует навык игроком [param to_player] и данными [param skill_data].
func initialize(to_player: Player, skill_data: SkillData) -> void:
	data = skill_data
	player = to_player
	if player.skill_vars.is_empty():
		player.skill_vars = [use_times, 0]
	_cooldown_timer = player.skill_vars[1]
	player.disarmed.connect(_player_disarmed)
	player.armed.connect(_player_armed)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_initialize()


## Использует навык.
func use(args: Array) -> void:
	player.skill_vars[0] -= 1
	player.skill_vars[1] = use_cooldown
	_cooldown_timer = use_cooldown
	_use.callv(args)


## Приостанавливает откат навыка.
func block_cooldown() -> void:
	_blocked_cooldown_counter += 1


## Продолжает откат навыка.
func unblock_cooldown() -> void:
	_blocked_cooldown_counter -= 1


## Возвращает [code]true[/code], если навык может откатываться.
func is_cooldown_blocked() -> bool:
	return _blocked_cooldown_counter > 0


## Возвращает [code]true[/code], если навык можно использовать.
func can_use() -> bool:
	return player.can_use_weapon() and player.skill_vars[0] > 0 \
			and player.skill_vars[1] <= 0 and _can_use()


## Метод для переопределения. При получении запроса на использование навыка сервер вызовет
## [method use_skill] с аргументами из массива, возвращаемого этим методом.
func get_use_args() -> Array:
	return []


## Метод для переопределения. Вызывается при инициализации навыка.
func _initialize() -> void:
	pass


## Метод для переопределения. Поместите логику использования навыка сюда.
## Создавайте дополнительные объекты (например, ударную волну) только на сервере.
## Может принимать аргументы, возвращаемые [method get_use_args].
func _use() -> void:
	pass


## Метод для переопределения. Должен возвращать [code]true[/code], если навык можно
## использовать. Сюда можно добавлять условия для этого.
func _can_use() -> bool:
	return true


## Метод для переопределения. Вызывается, когда игрок оказывается безоружен.
## Полезно, чтобы приостановить анимацию навыка (например, анимацию выпивания зелья).
func _player_disarmed() -> void:
	pass


## Метод для переопределения. Вызывается, когда игрок обратно получает возможность атаковать.
## Здесь можно возобновить то, что было приостановлено в [method _player_disarmed].
func _player_armed() -> void:
	pass
