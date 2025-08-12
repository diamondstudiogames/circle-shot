extends PanelContainer

@export var idx: int
var equip_selector: EquipSelector

func _ready() -> void:
	($RenameDialog as AcceptDialog).register_text_enter(%NameEdit as LineEdit)
	
	_validate_preset()
	if not Globals.get_string("preset_%d_name" % idx).is_empty():
		_show_data()
	else:
		_show_empty()


func _show_data() -> void:
	($Main as CanvasItem).show()
	($Empty as CanvasItem).hide()
	var data: Array[String] = Globals.get_variant("preset_%d_data" % idx, [] as Array[String])
	(%Skill as TextureRect).texture = load(Globals.items_db.skills_by_id[data[0]].image_path)
	(%Light as TextureRect).texture = load(Globals.items_db.weapons_by_id[data[1]].image_path)
	(%Heavy as TextureRect).texture = load(Globals.items_db.weapons_by_id[data[2]].image_path)
	(%Support as TextureRect).texture = load(Globals.items_db.weapons_by_id[data[3]].image_path)
	(%Melee as TextureRect).texture = load(Globals.items_db.weapons_by_id[data[4]].image_path)
	(%PresetName as Label).text = Globals.get_string("preset_%d_name" % idx)


func _show_empty() -> void:
	($Main as CanvasItem).hide()
	($Empty as CanvasItem).show()


func _validate_preset() -> void:
	if Globals.get_string("preset_%d_name" % idx).is_empty():
		return
	
	var changed := false
	
	var data: Array[String] = Globals.get_variant("preset_%d_data" % idx, [] as Array[String])
	var selected_skill: String = data[0]
	var selected_light_weapon: String = data[1]
	var selected_heavy_weapon: String = data[2]
	var selected_support_weapon: String = data[3]
	var selected_melee_weapon: String = data[4]
	
	if not selected_skill in Globals.items_db.skills_by_id \
			or Globals.items_db.skills_by_id[selected_skill] in Globals.items_db.other_skills \
			or not Globals.items_db.has_equip_item(selected_skill, ItemsDB.Item.SKILL):
		push_warning("Incorrect selected skill %s in preset %d. Reverting to default." 
				% [selected_skill, idx])
		selected_skill = Globals.items_db.default_skill
		changed = true
	
	if (
			not selected_light_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_light_weapon]
			in Globals.items_db.weapons_light
			or not Globals.items_db.has_equip_item(selected_light_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected light weapon %s in preset %d. Reverting to default."
				% [selected_light_weapon, idx])
		selected_light_weapon = Globals.items_db.default_light_weapon
		changed = true
	
	if (
			not selected_heavy_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_heavy_weapon]
			in Globals.items_db.weapons_heavy
			or not Globals.items_db.has_equip_item(selected_heavy_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected heavy weapon %s in preset %d. Reverting to default."
				% [selected_heavy_weapon, idx])
		selected_heavy_weapon = Globals.items_db.default_heavy_weapon
		changed = true
	
	if (
			not selected_support_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_support_weapon]
			in Globals.items_db.weapons_support
			or not Globals.items_db.has_equip_item(selected_support_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected support weapon %s in preset %d. Reverting to default."
				% [selected_support_weapon, idx])
		selected_support_weapon = Globals.items_db.default_support_weapon
		changed = true
	
	if (
			not selected_melee_weapon in Globals.items_db.weapons_by_id
			or not Globals.items_db.weapons_by_id[selected_melee_weapon]
			in Globals.items_db.weapons_melee
			or not Globals.items_db.has_equip_item(selected_melee_weapon, ItemsDB.Item.WEAPON)
	):
		push_warning("Incorrect selected melee weapon %s in preset %d. Reverting to default."
				% [selected_melee_weapon, idx])
		selected_melee_weapon = Globals.items_db.default_melee_weapon
		changed = true
	
	if changed:
		Globals.set_variant("preset_%d_data" % idx, [
			selected_skill,
			selected_light_weapon,
			selected_heavy_weapon,
			selected_support_weapon,
			selected_melee_weapon,
		] as Array[String])


func _on_add_pressed() -> void:
	Globals.set_string("preset_%d_name" % idx, "Предустановка %d" % idx)
	Globals.set_variant("preset_%d_data" % idx, [
		equip_selector.selected_skill,
		equip_selector.selected_light_weapon,
		equip_selector.selected_heavy_weapon,
		equip_selector.selected_support_weapon,
		equip_selector.selected_melee_weapon,
	] as Array[String])
	_show_data()


func _on_save_pressed() -> void:
	Globals.set_variant("preset_%d_data" % idx, [
		equip_selector.selected_skill,
		equip_selector.selected_light_weapon,
		equip_selector.selected_heavy_weapon,
		equip_selector.selected_support_weapon,
		equip_selector.selected_melee_weapon,
	] as Array[String])
	_show_data()


func _on_load_pressed() -> void:
	var data: Array[String] = Globals.get_variant("preset_%d_data" % idx, [] as Array[String])
	if (
			equip_selector.selected_skill == data[0]
			and equip_selector.selected_light_weapon == data[1]
			and equip_selector.selected_heavy_weapon == data[2]
			and equip_selector.selected_support_weapon == data[3]
			and equip_selector.selected_melee_weapon == data[4]
	):
		return
	equip_selector.selected_skill = data[0]
	equip_selector.selected_light_weapon = data[1]
	equip_selector.selected_heavy_weapon = data[2]
	equip_selector.selected_support_weapon = data[3]
	equip_selector.selected_melee_weapon = data[4]
	equip_selector.update_selected()
	equip_selector.items_changed.emit()


func _on_rename_pressed() -> void:
	(%NameEdit as LineEdit).clear()
	(%NameEdit as LineEdit).placeholder_text = "Новое имя..."
	($RenameDialog as Window).title = 'Переименовывание "%s"' \
			% Globals.get_string("preset_%d_name" % idx)
	($RenameDialog as Window).popup_centered()
	(%NameEdit as LineEdit).grab_focus()


func _on_delete_pressed() -> void:
	Globals.set_string("preset_%d_name" % idx, "")
	Globals.set_variant("preset_%d_data" % idx, [] as Array[String])
	_show_empty()


func _on_rename_dialog_confirmed() -> void:
	var new_name: String = Utils.strip_string((%NameEdit as LineEdit).text)
	if new_name.is_empty():
		(%NameEdit as LineEdit).clear()
		(%NameEdit as LineEdit).placeholder_text = "Недопустимое имя!"
		return
	
	Globals.set_string("preset_%d_name" % idx, new_name)
	(%PresetName as Label).text = Globals.get_string("preset_%d_name" % idx)
	($RenameDialog as Window).hide()
