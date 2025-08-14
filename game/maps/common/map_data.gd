class_name MapData
extends Resource

## Ресурс с данными карты.
## 
## Содержит данные карты, такие как имя, описание, путь к карте и картинке.

## Имя карты.
@export var name: String
## Краткое описание карты.
@export var brief_description: String
## Путь до сцены с картой.
@export_file("PackedScene") var scene_path: String
## Путь до картинки-обложки карты. Разрешение: 784 на 160.
@export_file("Texture2D") var image_path: String
