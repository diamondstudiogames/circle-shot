class_name EventData
extends Resource

## Ресурс с данными события.
##
## Этот ресурс содержит в себе данные о событии, такие как имя, описание, пути к картинке,
## сцене и другое.

## Имя события.
@export var name: String
## Краткое описание события.
@export var brief_description: String

@export_group("Info")
## Полное описание события.
@export_multiline var description: String
## Здоровье игрока в этом событии (по умолчанию).
@export var default_player_health: int = 100
## Минимальное число игроков (от 2 до 10).
@export_range(2, 10, 1) var min_players: int = 2
## Максимальное число игроков (от 2 до 10).
@export_range(2, 10, 1) var max_players: int = 10
## Допустимый делитель числа игроков.
## Например, если игроков 3, а делитель - 2, то игру начать будет невозможно,
## так как 3 не делится нацело на 2.
@export_range(1, 5, 1) var players_divider: int = 1
## Если равно [code]true[/code], то у админа будет возможность назначать игрокам команды.
@export var team_event := false

@export_group("Parameters")
## Словарь параметров события, где ключ - ID параметра.
@export var parameters: Dictionary[String, EventParameter]

@export_group("Paths")
## Путь до сцены с событием.
@export_file("PackedScene") var scene_path: String
## Путь до картинки-обложки события. Разрешение: 784 на 160.
@export_file("Texture2D") var image_path: String
## Массив карт данного события.
@export var maps: Array[MapData]


## Возвращает словарь параметров события по умолчанию.
func get_default_parameters() -> Dictionary[String, int]:
	var default_parameters: Dictionary[String, int]
	for parameter_id: String in parameters:
		default_parameters[parameter_id] = parameters[parameter_id].default_value
	return default_parameters


## Возвращает [code]true[/code], если все предоставленные параметры допустимы.
func is_parameters_valid(parameters_to_check: Dictionary[String, int]) -> bool:
	if parameters_to_check.size() != parameters.size():
		return false
	for parameter_id: String in parameters:
		if not parameter_id in parameters_to_check:
			return false
		if not parameters[parameter_id].is_parameter_valid(parameters_to_check[parameter_id]):
			return false
	return true
