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

## Таймер отката навыка. Если меньше или равно нулю, навык можно использовать.
var cooldown_timer := 0.0
## Оставшиеся использования навыка.
var remaining_uses: int

var _persistent_data_cooldown_timer: String
var _persistent_data_remaining_uses: String
var _blocked_cooldown_counter: int = 0
@warning_ignore("unused_private_class_variable") # Для дочерних классов
@onready var _other_parent: Node2D = \
		(get_tree().get_first_node_in_group(&"world") as World).other_parent


func _physics_process(delta: float) -> void:
	if not is_cooldown_blocked() and player.can_use_weapon():
		cooldown_timer -= delta


func _exit_tree() -> void:
	# сохраняем в persistent_data
	player.persistent_data[_persistent_data_cooldown_timer] = ceili(cooldown_timer)
	player.persistent_data[_persistent_data_remaining_uses] = remaining_uses


## Инициализирует навык игроком [param to_player] и данными [param skill_data]. Если 
## [param reset_state] равен [code]true[/code], то сохранённое состояние навыка будет сброшено.
func initialize(to_player: Player, skill_data: SkillData, reset_state := false) -> void:
	data = skill_data
	player = to_player
	player.disarmed.connect(_player_disarmed)
	player.armed.connect(_player_armed)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	
	_persistent_data_cooldown_timer = data.id + "_cooldown_timer"
	if _persistent_data_cooldown_timer in player.persistent_data and not reset_state:
		cooldown_timer = player.persistent_data[_persistent_data_cooldown_timer]
	else:
		cooldown_timer = 0.0
	_persistent_data_remaining_uses = data.id + "_remaining_uses"
	if _persistent_data_remaining_uses in player.persistent_data and not reset_state:
		remaining_uses = player.persistent_data[_persistent_data_remaining_uses]
	else:
		remaining_uses = use_times
	
	_initialize()


## Использует навык.
func use(args: Array) -> void:
	cooldown_timer = use_cooldown
	remaining_uses -= 1
	_use.callv(args)


## Приостанавливает откат навыка.
func block_cooldown() -> void:
	_blocked_cooldown_counter += 1


## Продолжает откат навыка.
func unblock_cooldown() -> void:
	_blocked_cooldown_counter = maxi(_blocked_cooldown_counter - 1, 0)


## Возвращает [code]true[/code], если навык может откатываться.
func is_cooldown_blocked() -> bool:
	return _blocked_cooldown_counter > 0


## Возвращает [code]true[/code], если навык можно использовать.
func can_use() -> bool:
	return player.can_use_weapon() and remaining_uses > 0 \
			and cooldown_timer <= 0 and _can_use()


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
