class_name Attack
extends Node2D

## Узел атаки.
##
## Узел, отвечающий за нанесения урона сущностям. Для работы добавьте дочерний
## узел типа [AreaDetector], [ShapeDetector] или [RayDetector]. 
## [b]Заметка[/b]: не забывайте вызывать [code]super()[/code] в [method Node._physics_process],
## если Вы переопределяете его (если, конечно, не хотите перезаписать существующую логику).

## Урон, который будет нанесён сущности.
@export var damage: int
## Интервал между нанесениями урона сущностям, попавших под эту атаку.
@export var damage_interval := 0.3
## Команда, которой принадлежит эта атака. Урон сущности не будет нанесён, если её команда
## совпадает с командой атаки.
@export var team := Entity.Team.ENVIRONMENT

## [Entity.id] сущности, которой принадлежит эта атака. Если меньше либо равен 0, в сообщении о
## смерти не будет указано имя убийцы.
var who: int = 0
## Множитель наносимого урона для удобства. При перемножение используется стандартное округление.
var damage_multiplier := 1.0
## [RayDetector]-ы этой атаки.
var ray_detectors: Array[RayDetector]
## [ShapeDetector]-ы этой атаки.
var shape_detectors: Array[ShapeDetector]
## [AreaDetector]-ы этой атаки.
var area_detectors: Array[AreaDetector]

var _exceptions: Dictionary[StringName, float]


func _physics_process(delta: float) -> void:
	for exception: StringName in _exceptions.keys():
		_exceptions[exception] -= delta
		if _exceptions[exception] <= 0.0:
			_exceptions.erase(exception)


## Наносит урон сущности [param entity]. Опционально можно изменить количество наносимого урона
## с помощью [param amount], НО [member damage_multiplier] все равно будет учтён.[br]
## Возвращает [code]true[/code], если урон был успешно нанесён, иначе [code]false[/code].
func deal_damage(entity: Entity, amount: int = damage) -> bool:
	if not can_deal_damage(entity):
		return false
	amount = _deal_damage(entity, roundi(amount * damage_multiplier))
	if amount <= 0:
		return false
	entity.damage(amount, who)
	_exceptions[entity.name] = damage_interval
	return true


## Определяет, можно ли нанести урон сущности [param entity]. Возвращает [code]true[/code]
## если можно, иначе возвращает [code]false[/code].
func can_deal_damage(entity: Entity) -> bool:
	return not entity.name in _exceptions and entity.team != team and _can_deal_damage(entity)


## Очищает список сущностей, которым не может нанести урон эта атака
## (из-за [member damage_interval]).
func clear_exceptions() -> void:
	_exceptions.clear()
	for rd: RayDetector in ray_detectors:
		rd.clear_exceptions()
	for sd: ShapeDetector in shape_detectors:
		sd.clear_exceptions()


## Метод для переопределения. Здесь можно добавить логику при нанесении урона. Метод должен
## возвращать значение типа [int] - количество наносимого урона. Чаще всего достаточно просто
## вернуть аргумент [param amount].
func _deal_damage(_entity: Entity, amount: int) -> int:
	return amount


## Метод для переопределения. Здесь можно добавить условия для нанесения урона.
## Возвращайте [code]true[/code] если можно, иначе возвращайте [code]false[/code].
func _can_deal_damage(_entity: Entity) -> bool:
	return true
