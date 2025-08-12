class_name EquipSelector
extends GridContainer

## Интерфейс выбора экипировки.
##
## Здесь игрок выбирает оружие, скин и навык.[br]
## [b]Внимание[/b]: после изменения свойств [code]selected_*[/code] нужно обновить отображаемые
## иконки с помощью [method update_selected].

## Издаётся, когда какой-то из выбранных предметов меняется на другой.
signal items_changed

## Выбранный скин.
var selected_skin: String
## Выбранный навык.
var selected_skill: String
## Выбранное лёгкое оружие.
var selected_light_weapon: String
## Выбранное тяжёлое оружие.
var selected_heavy_weapon: String
## Выбранное оружие поддержки.
var selected_support_weapon: String
## Выбранное ближнее оружие.
var selected_melee_weapon: String

@onready var _item_selector: Window = $ItemSelector
@onready var _items_grid: ItemsGrid = %ItemsGrid


func _ready() -> void:
	selected_skin = Globals.get_string("selected_skin")
	selected_skill = Globals.get_string("selected_skill")
	selected_light_weapon = Globals.get_string("selected_light_weapon")
	selected_heavy_weapon = Globals.get_string("selected_heavy_weapon")
	selected_support_weapon = Globals.get_string("selected_support_weapon")
	selected_melee_weapon = Globals.get_string("selected_melee_weapon")
	
	_validate_selected_equip()
	_update_equip()


## Обновляет иконки выбранных предметов экипировки.
func update_selected() -> void:
	_save_selected_equip()
	_update_equip()


func _validate_selected_equip() -> void:
	var changed := false
	
	if not selected_skin in Globals.items_db.skins_by_id \
			or Globals.items_db.skins_by_id[selected_skin] in Globals.items_db.other_skins \
			or not Globals.items_db.has_equip_item(selected_skin, ItemsDB.Item.SKIN):
		push_warning("Incorrect selected skin: %s. Reverting to default." % selected_skin)
		selected_skin = Globals.items_db.default_skin
		changed = true
	
	if not selected_skill in Globals.items_db.skills_by_id \
			or Globals.items_db.skills_by_id[selected_skill] in Globals.items_db.other_skills \
			or not Globals.items_db.has_equip_item(selected_skill, ItemsDB.Item.SKILL):
		push_warning("Incorrect selected skill: %s. Reverting to default." % selected_skill)
		selected_skill = Globals.items_db.default_skill
		changed = true
	
	if (
			not selected_light_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_light_weapon]
			in Globals.items_db.weapons_light
			or not Globals.items_db.has_equip_item(selected_light_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected light weapon: %s. Reverting to default."
				% selected_light_weapon)
		selected_light_weapon = Globals.items_db.default_light_weapon
		changed = true
	
	if (
			not selected_heavy_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_heavy_weapon]
			in Globals.items_db.weapons_heavy
			or not Globals.items_db.has_equip_item(selected_heavy_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected heavy weapon: %s. Reverting to default."
				% selected_heavy_weapon)
		selected_heavy_weapon = Globals.items_db.default_heavy_weapon
		changed = true
	
	if (
			not selected_support_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_support_weapon]
			in Globals.items_db.weapons_support
			or not Globals.items_db.has_equip_item(selected_support_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected support weapon: %s. Reverting to default."
				% selected_support_weapon)
		selected_support_weapon = Globals.items_db.default_support_weapon
		changed = true
	
	if (
			not selected_melee_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_melee_weapon]
			in Globals.items_db.weapons_melee
			or not Globals.items_db.has_equip_item(selected_melee_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected melee weapon: %s. Reverting to default."
				% selected_melee_weapon)
		selected_melee_weapon = Globals.items_db.default_melee_weapon
		changed = true
	
	if changed:
		_save_selected_equip()


func _save_selected_equip() -> void:
	Globals.set_string("selected_skin", selected_skin)
	Globals.set_string("selected_skill", selected_skill)
	Globals.set_string("selected_light_weapon", selected_light_weapon)
	Globals.set_string("selected_heavy_weapon", selected_heavy_weapon)
	Globals.set_string("selected_support_weapon", selected_support_weapon)
	Globals.set_string("selected_melee_weapon", selected_melee_weapon)


func _update_equip() -> void:
	var skin: SkinData = Globals.items_db.skins_by_id[selected_skin]
	($Skin/Name as Label).text = skin.name
	($Skin/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[skin.rarity]
	($Skin as TextureRect).texture = load(skin.image_path)
	
	var skill: SkillData = Globals.items_db.skills_by_id[selected_skill]
	($Skill/Name as Label).text = skill.name
	($Skill/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[skill.rarity]
	($Skill as TextureRect).texture = load(skill.image_path)
	
	var light_weapon: WeaponData = Globals.items_db.weapons_by_id[selected_light_weapon]
	($LightWeapon/Name as Label).text = light_weapon.name
	($LightWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[light_weapon.rarity]
	($LightWeapon as TextureRect).texture = load(light_weapon.image_path)
	
	var heavy_weapon: WeaponData = Globals.items_db.weapons_by_id[selected_heavy_weapon]
	($HeavyWeapon/Name as Label).text = heavy_weapon.name
	($HeavyWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[heavy_weapon.rarity]
	($HeavyWeapon as TextureRect).texture = load(heavy_weapon.image_path)
	
	var support_weapon: WeaponData = Globals.items_db.weapons_by_id[selected_support_weapon]
	($SupportWeapon/Name as Label).text = support_weapon.name
	($SupportWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[support_weapon.rarity]
	($SupportWeapon as TextureRect).texture = load(support_weapon.image_path)
	
	var melee_weapon: WeaponData = Globals.items_db.weapons_by_id[selected_melee_weapon]
	($MeleeWeapon/Name as Label).text = melee_weapon.name
	($MeleeWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[melee_weapon.rarity]
	($MeleeWeapon as TextureRect).texture = load(melee_weapon.image_path)


func _on_change_skin_pressed() -> void:
	_item_selector.title = "Выбор скина"
	_item_selector.popup_centered()
	_items_grid.list_items(ItemsDB.Item.SKINS_LINE, Globals.items_db.skins_lines.find_custom(
			func(skins_line: SkinsLineData) -> bool:
				return Globals.items_db.skins_by_id[selected_skin] in skins_line.skins
	))


func _on_change_skill_pressed() -> void:
	_item_selector.title = "Выбор навыка"
	_item_selector.popup_centered()
	_items_grid.list_items(ItemsDB.Item.SKILL,
			Globals.items_db.skills_by_id[selected_skill].idx_in_db)


func _on_change_light_weapon_pressed() -> void:
	_item_selector.title = "Выбор лёгкого оружия"
	_item_selector.popup_centered()
	_items_grid.list_weapons_by_type(Weapon.Type.LIGHT,
			Globals.items_db.weapons_by_id[selected_light_weapon].idx_in_db)


func _on_change_heavy_weapon_pressed() -> void:
	_item_selector.title = "Выбор тяжёлого оружия"
	_item_selector.popup_centered()
	_items_grid.list_weapons_by_type(Weapon.Type.HEAVY,
			Globals.items_db.weapons_by_id[selected_heavy_weapon].idx_in_db)


func _on_change_support_weapon_pressed() -> void:
	_item_selector.title = "Выбор оружия поддержки"
	_item_selector.popup_centered()
	_items_grid.list_weapons_by_type(Weapon.Type.SUPPORT,
			Globals.items_db.weapons_by_id[selected_support_weapon].idx_in_db)


func _on_change_melee_weapon_pressed() -> void:
	_item_selector.title = "Выбор ближнего оружия"
	_item_selector.popup_centered()
	_items_grid.list_weapons_by_type(Weapon.Type.MELEE,
			Globals.items_db.weapons_by_id[selected_melee_weapon].idx_in_db)


func _on_item_selected(type: ItemsDB.Item, idx: int) -> void:
	_item_selector.hide()
	match type:
		ItemsDB.Item.SKINS_LINE:
			_item_selector.show()
			_items_grid.list_skins_line(idx, Globals.items_db.skins_by_id[selected_skin].idx_in_db)
		ItemsDB.Item.SKIN:
			if Globals.items_db.skins[idx].id != selected_skin:
				selected_skin = Globals.items_db.skins[idx].id
				items_changed.emit()
		ItemsDB.Item.SKILL:
			if Globals.items_db.skills[idx].id != selected_skill:
				selected_skill = Globals.items_db.skills[idx].id
				items_changed.emit()
		ItemsDB.Item.WEAPON:
			var selected_weapon: WeaponData = Globals.items_db.weapons[idx]
			if selected_weapon in Globals.items_db.weapons_light \
					and selected_weapon.id != selected_light_weapon:
				selected_light_weapon = selected_weapon.id
				items_changed.emit()
			elif selected_weapon in Globals.items_db.weapons_heavy \
					and selected_weapon.id != selected_heavy_weapon:
				selected_heavy_weapon = selected_weapon.id
				items_changed.emit()
			elif selected_weapon in Globals.items_db.weapons_support \
					and selected_weapon.id != selected_support_weapon:
				selected_support_weapon = selected_weapon.id
				items_changed.emit()
			elif selected_weapon in Globals.items_db.weapons_melee \
					and selected_weapon.id != selected_melee_weapon:
				selected_melee_weapon = selected_weapon.id
				items_changed.emit()
	_save_selected_equip()
	_update_equip()


func _on_items_listed(type: ItemsDB.Item) -> void:
	(%BackToSkinsLines as CanvasItem).visible = type == ItemsDB.Item.SKIN
