class_name WeaponData
extends Resource

## Ресурс с данными оружия.
##
## Содержит данные об оружии, такие как редкость, имя, описание и прочее.

## Имя оружия.
@export var name: String
## Редкость оружия. Смотрите [enum ItemsDB.Rarity].
@export var rarity := ItemsDB.Rarity.COMMON
## ID оружия. Должно быть уникальным.
@export var id: String

@export_group("About")
## Словарь с различными статистиками оружия (урон, боезапас, ...).
## В [member damage_text], [member ammo_text] и [member description] можно подставлять значения
## отсюда, если написать в них [code]{<нужная статистика>}[/code].
@export var stats: Dictionary[String, String] = {
	"dps": "",
	"damage": "",
	"ammo_per_load": "",
	"ammo_total": "",
	"reload_time": "",
}
## Текст, кратко говорящий об уроне оружия. Чаще всего "Урон/с" или просто "Урон".
@export var damage_text := "Урон/с: {dps}"
## Текст, кратко говорящий об боеприпасах оружия. Чаще всего в формате "ХХ/ХХХ"
@export var ammo_text := "{ammo_per_load}/{ammo_total}"
## Полное описание оружия, включающее в себя почти всю информацию о нём. Для форматирования можно
## использовать BBCode.
@export_multiline var description := """Урон/с: [color=red]{dps}[/color]
Урон/снаряд: [color=red]{damage}[/color]

Боеприпасы: [color=blue]{ammo_per_load}/{ammo_total}[/color]
Перезарядка: [color=blue]{reload_time} с[/color]

Описание"""
## Множитель скорости игрока, когда это оружие является текущим.
@export_range(0.5, 2.0, 0.01) var speed_multiplier_when_current := 1.0

@export_group("Paths")
## Путь к сцене оружия.
@export_file("PackedScene") var scene_path: String
## Путь к картинке оружия, желательно с разрешением 256 пикселей по большей стороне. 
@export_file("Texture2D") var image_path: String
## Массив путей к сценам, относящихся конкретно к этому оружию, которые должны синхронизироваться
## при появлении. Например, сцена пули или гранаты.
@export_file("PackedScene") var spawnable_scenes_paths: Array[String]

## Индекс оружия в массиве [ItemsDB]. Задаётся при инициализации [ItemsDB].
var idx_in_db: int = -1
