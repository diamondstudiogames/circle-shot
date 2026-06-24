class_name EventParameter
extends Resource

## Параметр события.
##
## Ресурс с информацией о каком-либо параметре события. Используется в [EventData].

## Перечисление типов параметра события.
enum Type {
	## Переключатель. Будет использован [CheckButton]. Значения [member range_min],
	## [member range_max] и [member range_step] будут приняты за [code]0[/code], [code]1[/code]
	## и [code]1[/code] соответственно.
	CHECK_BUTTON = 0,
	## Поле ввода со стрелочками. Будет использован [SpinBox].
	SPIN_BOX = 1,
	## Ползунок. Будет использован [HSlider].
	SLIDER = 2,
}

## Название параметра события.
@export var name: String
## Тип параметра события.
@export var type := Type.CHECK_BUTTON
## Значение по умолчанию.
@export var default_value: int

@export_group("Range", "range_")
## Минимальное значение области допустимых значений.
@export var range_min: int = 0
## Максимальное значение области допустимых значений.
@export var range_max: int = 1
## Шаг между значениями в допустимой области.
@export var range_step: int = 1

@export_group("Visuals")
## Путь до иконки параметра события, размером 80 на 80.
@export_file("Texture2D") var icon_path: String
## Префикс значения этого параметра. Используется для отображения значения при настройке.
@export var prefix: String
## Суффикс значения этого параметра. Используется для отображения значения при настройке.
@export var suffix: String


## Возвращает [code]true[/code], если предоставленный параметр допустим.
func is_parameter_valid(parameter: int) -> bool:
	return parameter >= range_min and parameter <= range_max \
			and (parameter - range_min) % range_step == 0


## Возвращает строку с параметром [param parameter], заключённым между суффиксом и префиксом.
func get_parameter_as_string(parameter: int) -> String:
	return prefix + str(parameter) + suffix
