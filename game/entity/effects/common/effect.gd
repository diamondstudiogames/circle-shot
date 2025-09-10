class_name Effect
extends Node2D

## Эффект для сущности.
##
## Продолжительный либо постоянный эффект для сущности.
## Содержит константы с UID эффектов и их описанием.

## Изменение скорости. В [code]data[/code] требует один [float] - новый множитель скорости.
const SPEED_CHANGE := "uid://dkyu57ilvneen"
## Невидимость. Не требует ничего в [code]data[/code].
const INVISIBILITY := "uid://66w5ixijgn51"
## Оглушение. Не требует ничего в [code]data[/code].
const STUN := "uid://of54uwtr1ice"
## Обездвиживание. Не требует ничего в [code]data[/code].
const IMMOBILITY := "uid://dvb6a8p7615dy"
## Изменение исходящего урона. В [code]data[/code] требует один [float] - новый множитель урона.
const DAMAGE_CHANGE := "uid://bxgpbuysxjefr"
## Изменение входящего урона. В [code]data[/code] требует один [float] - новый множитель урона.
const DEFENSE_CHANGE := "uid://cf24vsbhb6f8g"
## Отбрасывание. В [code]data[/code] требует один [Vector2] - направление и сила отбрасывания.
const KNOCKBACK := "uid://dmd6vxl6v7ri2"
## Отравление. В [code]data[/code] требует один [int] - кол-во урона за интервал.
## Можно задать сущность, нанёсшую урон, передав её ID как [int] вторым элементом массива.
## По умолчанию ID сущности равен -1.
## Длительность интервала можно задать, если указать [float] третьим элементом массива.
## По умолчанию длительность интервала - 1 секунда.
const POISON := "uid://ujm5kn81ax1c"
## Кровотечение. Полностью аналогично отравлению, но другая внешность, и интервал нанесения урона
## по умолчанию - 0.8 секунды.
const BLEEDING := "uid://r5y32nuhfqet"

## Может ли эффект стакаться на сущности. Если нет, то повторная попытка наложить этот же эффект
## просто продлит время его действия (или увеличит [member timeless_counter]).
@export var stackable := true
## Является ли этот эффект негативным.
@export var negative := false
## Счётчик для постоянного эффекта. Эффект будет удалён только тогда, когда время действия
## закончилось и этот счётчик ниже 1.
var timeless_counter: int = 0:
	set(value):
		timeless_counter = value
		if value <= 0 and _timer.is_stopped():
			clear()
## UID эффекта.
var uid: String
## Данные эффекта, переданные в [method initialize].
var data: Array
## Сущность, переданная в [method initialize].
var entity: Entity
@onready var _timer: Timer = $Timer


## Инициализирует эффект сущностью [param to_entity] и UID эффекта [param effet_uid].
## Опционально указываются:[br]
## - Данные для эффекта в массиве [param effect_data].[br]
## - Является ли этот эффект постоянным в [param timeless].[br]
## - Длительность эффекта (если он не постоянный) в [param duration].
func initialize(to_entity: Entity, effect_uid: String, effect_data := [],
		timeless := false, duration := 1.0) -> void:
	uid = effect_uid
	data = effect_data
	entity = to_entity
	if timeless:
		timeless_counter += 1
	else:
		if duration <= 0.0:
			queue_free()
			return
		add_duration(duration)
	
	_start_effect()


## Очищает эффект.
func clear() -> void:
	_end_effect()
	queue_free()


## Добавляет длительность, указанную в [param time].
func add_duration(time: float) -> void:
	_timer.start(_timer.time_left + time)


## Метод для переопределения. Вызывается, когда эффект начинает действовать.
func _start_effect() -> void:
	pass


## Метод для переопределения. Вызывается, когда эффект закончил действовать.
func _end_effect() -> void:
	pass


func _on_timer_timeout() -> void:
	if timeless_counter <= 0:
		clear()
