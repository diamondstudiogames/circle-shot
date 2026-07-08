class_name Map
extends Node2D
## Базовый класс для карт.

## Список треков для этой карты. Если не пуст, переопределяет заданные в [World].
@export var custom_tracks: Array[AudioStream]
## Данные об этой карте.
var data: MapData
## Ссылка на [World] этой карты.
@onready var world: World = get_parent()

func _ready() -> void:
	if not custom_tracks.is_empty():
		world.tracks = custom_tracks
	_initialize()


## Виртуальный метод для инициализации карты. Для доступа к миру используйте [member world],
## при необходимости приведите тип к нужному (но проверьте на [code]null[/code]
## перед использованием).
func _initialize() -> void:
	pass
