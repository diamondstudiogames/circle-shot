class_name EventModifierData
extends Resource

## Данные о модификаторе события.

## Имя модификатора.
@export var name: String
## Краткое описание модификатора.
@export var brief_description: String
## Путь до сцены модификатора.
@export_file("PackedScene") var scene_path: String
## Путь до иконки модификатора. Размер - 128 на 128.
@export_file("Texture2D") var icon_path: String

## Индекс навыка в массиве [ItemsDB]. Задаётся при инициализации [ItemsDB].
var idx_in_db: int = -1
