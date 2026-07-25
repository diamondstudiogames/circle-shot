extends Node

# Умная реализация защиты
# для каждого очка защиты выполняется следующий алгоритм
# - для каждого значения из thresholds (от 0 до 1) выполняется следующее
# - - если текущий урон меньше максимального здоровья сущности, умноженный на это значение,
#     то от этого урона отнимается значение из reduce_per_defense с индексом значения из thresholds
# - если значение thresholds не было найдено, то отнимается reduce_per_defense[-1]

@export var defense: int = 0
@export_range(0.01, 0.99, 0.001) var thresholds: Array[float] # должны быть в порядке возрастания
@export var reduce_per_defense: Array[int] = [1]
@export var min_damage: int = 1


func _ready() -> void:
	(get_parent() as Entity).change_health_modifiers.append(_change_health_modifier)


func _exit_tree() -> void:
	(get_parent() as Entity).change_health_modifiers.erase(_change_health_modifier)


func _change_health_modifier(entity: Entity, change: int) -> int:
	if change > 0:
		return change
	var amount: int = -change # проще в положительных
	for i: int in defense:
		var found_threshold := false
		for idx: int in thresholds.size():
			if amount < entity.max_health * thresholds[idx]:
				found_threshold = true
				amount -= reduce_per_defense[idx]
				break
		if not found_threshold:
			amount -= reduce_per_defense[-1]
	return -maxi(amount, min_damage)
