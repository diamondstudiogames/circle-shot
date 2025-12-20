class_name ChallengeData
extends Resource

## Ресурс с данными испытания.
##
## Этот ресурс содержит в себе данные о испытании, такие как имя, описание, пути к картинке,
## сцене и другое.

## Имя события.
@export var name: String
## Краткое описание испытания.
@export var brief_description: String
## Полное описание испытания.
@export_multiline var description: String
## Здоровье игрока в этом испытании (по умолчанию).
@export var default_player_health: int = 100
## Путь до сцены с испытанием.
@export_file("PackedScene") var scene_path: String
## Путь до картинки-обложки испытания. Разрешение: 784 на 160.
@export_file("Texture2D") var image_path: String
## Массив карт данного испытания.
@export var maps: Array[MapData]
