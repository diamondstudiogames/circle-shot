extends Node2D


signal picked_up

enum EquipType {
	SKIN = 0,
	SKILL = 1,
	WEAPON = 2,
}

@export var equip_type := EquipType.SKIN
@export var visual_size_x := 256.0

@export_group("Equip Data")
@export var skin_data: SkinData
@export var skill_data: SkillData
@export var weapon_data: WeaponData
@export var weapon_type := Weapon.Type.LIGHT


func _ready() -> void:
	reset_physics_interpolation()
	var image_path: String
	match equip_type:
		EquipType.SKIN:
			image_path = skin_data.image_path
		EquipType.SKILL:
			image_path = skill_data.image_path
		EquipType.WEAPON:
			image_path = weapon_data.image_path
	($Sprite2D as Sprite2D).texture = load(image_path)
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
	picked_up.emit()


func _on_interactible_interacted(who: Player) -> void:
	if not multiplayer.is_server():
		return
	_equip_item.rpc(who.id)
	queue_free()
