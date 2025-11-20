@tool
class_name PickableEquipItem
extends Node2D

## Подбираемый предмет экипировки.

## Издаётся, когда предмет подбирается. В [param by] хранится ID игрока, подобравшего предмет.
signal picked_up(by: int)

## Тип подбираемого предмета.
enum EquipType {
	## Скин. Нужно указать [member skin_data].
	SKIN = 0,
	## Навык. Нужно указать [member skill_data].
	SKILL = 1,
	## Оружие. Нужно указать [member weapon_data] и [member weapon_type].
	WEAPON = 2,
}

## Тип подбираемого предмета. См. [enum EquipType].
@export var equip_type := EquipType.SKIN
## Размер подбираемого предмета НАИБОЛЬШЕЙ оси текстуры предмета.
@export var visual_size_x := 256.0
## Картинка оружия. Автоматически задаётся при указании [member weapon_data], [member skin_data] или
## [member skill_data].
@export var image: Texture2D

@export_group("Equip Data")
## Данные скина. Использовать вместе с [constant SKIN].
@export var skin_data: SkinData:
	set(value):
		skin_data = value
		if value and Engine.is_editor_hint():
			image = load(value.image_path)
## Данные навыка. Использовать вместе с [constant SKILL].
@export var skill_data: SkillData:
	set(value):
		skill_data = value
		if value and Engine.is_editor_hint():
			image = load(value.image_path)
## Данные оружия. Использовать вместе с [constant WEAPON].
@export var weapon_data: WeaponData:
	set(value):
		weapon_data = value
		if value and Engine.is_editor_hint():
			image = load(value.image_path)
## Тип оружия. Использовать вместе с [constant WEAPON].
@export var weapon_type := Weapon.Type.LIGHT


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	reset_physics_interpolation()
	if not image:
		var image_path: String
		match equip_type:
			EquipType.SKIN:
				image_path = skin_data.image_path
			EquipType.SKILL:
				image_path = skill_data.image_path
			EquipType.WEAPON:
				image_path = weapon_data.image_path
		($Sprite2D as Sprite2D).texture = load(image_path)
	else:
		($Sprite2D as Sprite2D).texture = image
	($Sprite2D as Node2D).scale = Vector2.ONE * visual_size_x / 256.0


@rpc("authority", "call_local", "reliable") # нулевой канал чтобы не пришло позже queue_free
func _equip_item(id: int) -> void:
	var player: Player = (get_tree().get_first_node_in_group(&"world") as World).players[id]
	match equip_type:
		EquipType.SKIN:
			player.set_skin(skin_data)
		EquipType.SKILL:
			player.set_skill(skill_data, true)
		EquipType.WEAPON:
			player.set_weapon(weapon_type, weapon_data)
	picked_up.emit(id)


func _on_interactible_interacted(who: Player) -> void:
	if not multiplayer.is_server():
		return
	_equip_item.rpc(who.id)
	queue_free()
