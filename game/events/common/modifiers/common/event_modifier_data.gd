class_name EventModifierData
extends Resource

## Данные о модификаторе события.

## Имя модификатора.
@export var name: String
## Краткое описание модификатора.
@export var brief_description: String

@export_group("Spawnable Paths")
## Массив из путей к сценам сущностей, используемых этим модификатором,
## которые должны синхронизироваться при появлении.
@export_file("PackedScene") var spawnable_entities_paths: Array[String]
## Массив из путей к сценам, используемых этим модификатором и связанных с оружием,
## которые должны синхронизироваться при появлении.
@export_file("PackedScene") var spawnable_projectiles_paths: Array[String]
## Массив из путей к сценам, используемых этим модификатором и не связанных с оружием,
## которые должны синхронизироваться при появлении.
@export_file("PackedScene") var spawnable_other_paths: Array[String]

@export_group("Paths")
## Путь до сцены модификатора.
@export_file("PackedScene") var scene_path: String
## Путь до иконки модификатора. Размер - 128 на 128.
@export_file("Texture2D") var icon_path: String

## Индекс навыка в массиве [ItemsDB]. Задаётся при инициализации [ItemsDB].
var idx_in_db: int = -1
