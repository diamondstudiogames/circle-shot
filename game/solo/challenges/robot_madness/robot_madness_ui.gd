class_name RobotMadnessUI
extends ChallengeUI

## Интерфейс испытания "Рубка роботов".

@onready var _stats_label: Label = $Main/Stats

## Устанавливает текущие показатели.
func set_stats(damaged: int, points: int, time: int) -> void:
	var minutes: int = floori(time / 60.0)
	var seconds: int = time % 60
	_stats_label.text = "Нанесено урона: %d" % damaged
	_stats_label.text += "\nОчки: %d" % points
	_stats_label.text += "\nВремени прожито: %02d:%02d" % [minutes, seconds]
