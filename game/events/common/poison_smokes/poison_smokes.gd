class_name PoisonSmokes
extends Attack

## Ядовитые облака, что покрывают карту через некоторое время.

## Перечисление сторон.
enum Side {
	## Лево.
	LEFT = 1,
	## Право.
	RIGHT = 2,
	## Верх.
	TOP = 4,
	## Низ.
	BOTTOM = 8,
}

## Время, за которое облака покрывают карту.
@export var duration := 400.0
## Дистанция, с которой начинают подступать облака.
@export var start_distance := 4800.0
## Стороны, с которых подступают облака.
@export_flags("Left:1", "Right:2", "Top:4", "Bottom:8") var sides: int = 15
## Повышение урона за каждый нанесённый "удар".
@export var damage_increase: int = 10

var _remained_distance: float
var _damage_increase_for_entity: Dictionary[StringName, int]
var _damage_increase_timers: Dictionary[StringName, float]


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	if sides & Side.LEFT != 0:
		tween.tween_property($Left as Node2D, ^":position", Vector2.ZERO, duration).from(
				Vector2.LEFT * start_distance)
	else:
		$Left.queue_free()
	if sides & Side.RIGHT != 0:
		tween.tween_property($Right as Node2D, ^":position", Vector2.ZERO, duration).from(
				Vector2.RIGHT * start_distance)
	else:
		$Right.queue_free()
	if sides & Side.TOP != 0:
		tween.tween_property($Top as Node2D, ^":position", Vector2.ZERO, duration).from(
				Vector2.UP * start_distance)
	else:
		$Top.queue_free()
	if sides & Side.BOTTOM != 0:
		tween.tween_property($Bottom as Node2D, ^":position", Vector2.ZERO, duration).from(
				Vector2.DOWN * start_distance)
	else:
		$Bottom.queue_free()
	
	tween.tween_property(self, ^":_remained_distance", 0.0, duration).from(start_distance)
	tween.custom_step(0.01) # сразу ставим в нужные места облака
	
	_draw_box()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	super(delta)
	for entity: StringName in _damage_increase_timers.keys():
		_damage_increase_timers[entity] -= delta
		if _damage_increase_timers[entity] <= 0.0:
			_damage_increase_timers.erase(entity)
			_damage_increase_for_entity.erase(entity)
	_draw_box()


func _deal_damage(entity: Entity, amount: int) -> int:
	var old_damage: int = _damage_increase_for_entity.get_or_add(entity.name, 0)
	_damage_increase_for_entity[entity.name] += damage_increase
	_damage_increase_timers[entity.name] = damage_interval + 0.1
	return amount + old_damage


## Возвращает расстояние облаков до центра.
func get_remained_distance() -> float:
	return _remained_distance


func _draw_box() -> void:
	if not Globals.get_setting_bool("minimap"):
		return
	
	if sides & Side.LEFT:
		var line: Line2D = $Left/MinimapMarker/Line
		var current_distance: float = -($Left as Node2D).position.x
		line.position.x = -current_distance
		var points: PackedVector2Array = line.points
		points[0].x = -current_distance - World.BLOCK_SIZE if sides & Side.TOP else -start_distance
		points[1].x = current_distance + World.BLOCK_SIZE if sides & Side.BOTTOM else start_distance
		line.points = points
	if sides & Side.RIGHT:
		var line: Line2D = $Right/MinimapMarker/Line
		var current_distance: float = ($Right as Node2D).position.x
		line.position.x = current_distance
		var points: PackedVector2Array = line.points
		points[0].x = -current_distance - World.BLOCK_SIZE \
				if sides & Side.BOTTOM else -start_distance
		points[1].x = current_distance + World.BLOCK_SIZE if sides & Side.TOP else start_distance
		line.points = points
	if sides & Side.TOP:
		var line: Line2D = $Top/MinimapMarker/Line
		var current_distance: float = -($Top as Node2D).position.y
		line.position.y = -current_distance
		var points: PackedVector2Array = line.points
		points[0].x = -current_distance - World.BLOCK_SIZE \
				if sides & Side.RIGHT else -start_distance
		points[1].x = current_distance + World.BLOCK_SIZE if sides & Side.LEFT else start_distance
		line.points = points
	if sides & Side.BOTTOM:
		var line: Line2D = $Bottom/MinimapMarker/Line
		var current_distance: float = ($Bottom as Node2D).position.y
		line.position.y = current_distance
		var points: PackedVector2Array = line.points
		points[0].x = -current_distance - World.BLOCK_SIZE if sides & Side.LEFT else -start_distance
		points[1].x = current_distance + World.BLOCK_SIZE if sides & Side.RIGHT else start_distance
		line.points = points
