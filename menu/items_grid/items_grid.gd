class_name ItemsGrid
extends GridContainer

## Сеточный контейнер с предметами.
##
## Этот контейнер может отобразить все предметы одного типа с помощью [method list_items].

## Этот сигнал издаётся, когда один из отображённых предметов нажат. Сигнал содержит
## тип предмета в [param type] и индекс предмета в [param id].
signal item_selected(type: ItemsDB.Item, idx: int)
## Этот сигнал издаётся после отображения предметов методами [code]list_*[/code]. Сигнал содержит
## тип отображаемых предметов в [param type].
signal items_listed(type: ItemsDB.Item)
## Цвет неразблокированных предметов.
const LOCKED_ITEM_TINT := Color.WEB_GRAY

var _item_big_scene: PackedScene = preload("uid://ck5uq0aa1ov56")
var _item_small_scene: PackedScene = preload("uid://c07pym82q5utt")


## Очищает существующие предметы и отображает новые того типа, который указан в [param type].
## Опционально можно предоставить индекс в базе данных в [param selected_idx],
## чтобы выделить зелёным выбранный предмет.[br]
## Чтобы показать скины из определённой линейки, оружия определённого типа,
## карты определённого события или карты определённого испытания, используйте
## [method list_skins_line], [method list_weapons_by_type], [method list_maps_of_event]
## или [method list_maps_of_challenge] соответственно.[br]
## Если [param hide_locked] равен [code]false[/code], неразблокированные предметы будут показаны,
## но затемнены. Не применяется к событиям и испытаниям.
func list_items(type: ItemsDB.Item, selected_idx: int = -1, hide_locked := true) -> void:
	for child: Node in get_children():
		child.queue_free()
	
	var has_selected := false
	match type:
		ItemsDB.Item.EVENT:
			columns = 1
			var counter: int = 0
			for event: EventData in Globals.items_db.events:
				var item: TextureRect = _item_big_scene.instantiate()
				item.texture = load(event.image_path)
				(item.get_node(^"Container/Name") as Label).text = event.name
				(item.get_node(^"Container/Description") as Label).text = event.brief_description
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, counter))
				add_child(item)
				
				if selected_idx == counter:
					(item.get_node(^"Container/Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
				counter += 1
		ItemsDB.Item.EVENT_MODIFIER:
			columns = 3
			for event_modifier: EventModifierData in Globals.items_db.event_modifiers:
				var item: TextureRect = _item_small_scene.instantiate()
				item.texture = load(event_modifier.icon_path)
				(item.get_node(^"Name") as Label).text = event_modifier.name
				(item.get_node(^"RarityFill") as ColorRect).color = Color.WHITE
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, event_modifier.idx_in_db))
				add_child(item)
				
				if selected_idx == event_modifier.idx_in_db:
					(item.get_node(^"Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
		ItemsDB.Item.CHALLENGE:
			columns = 1
			var counter: int = 0
			for challenge: ChallengeData in Globals.items_db.challenges:
				var item: TextureRect = _item_big_scene.instantiate()
				item.texture = load(challenge.image_path)
				(item.get_node(^"Container/Name") as Label).text = challenge.name
				(item.get_node(^"Container/Description") as Label).text = \
						challenge.brief_description
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, counter))
				add_child(item)
				
				if selected_idx == counter:
					(item.get_node(^"Container/Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
				counter += 1
		ItemsDB.Item.SKINS_LINE:
			columns = 1
			var counter: int = 0
			for skins_line: SkinsLineData in Globals.items_db.skins_lines:
				var locked := true
				for skin: SkinData in skins_line.skins:
					if Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN):
						locked = false
						break
				if hide_locked and locked:
					counter += 1
					continue
				
				var item: TextureRect = _item_big_scene.instantiate()
				item.texture = load(skins_line.image_path)
				(item.get_node(^"Container/Name") as Label).text = skins_line.name
				(item.get_node(^"Container/Description") as Label).text = \
						skins_line.brief_description
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, counter))
				add_child(item)
				
				if locked:
					(item as CanvasItem).modulate = LOCKED_ITEM_TINT
				if selected_idx == counter:
					(item.get_node(^"Container/Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
				counter += 1
		ItemsDB.Item.SKIN:
			columns = 3
			for skin: SkinData in Globals.items_db.skins:
				if skin in Globals.items_db.other_skins:
					continue
				var locked: bool = not Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN)
				if locked and (hide_locked or skin.rarity in [
					ItemsDB.Rarity.SECRET,
					ItemsDB.Rarity.SPECIAL
				]):
					continue
				
				var item: TextureRect = _item_small_scene.instantiate()
				item.texture = load(skin.image_path)
				(item.get_node(^"Name") as Label).text = skin.name
				(item.get_node(^"Description") as Label).text = skin.brief_description
				(item.get_node(^"Description") as Label).horizontal_alignment = \
						HORIZONTAL_ALIGNMENT_CENTER
				(item.get_node(^"RarityFill") as ColorRect).color = \
						ItemsDB.RARITY_COLORS[skin.rarity]
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, skin.idx_in_db))
				add_child(item)
				
				if locked:
					(item as CanvasItem).modulate = LOCKED_ITEM_TINT
					(item.get_node(^"Description") as Label).text = "Не открыто"
				if selected_idx == skin.idx_in_db:
					(item.get_node(^"Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
		ItemsDB.Item.SKILL:
			columns = 3
			for skill: SkillData in Globals.items_db.skills:
				if skill in Globals.items_db.other_skills:
					continue
				var locked: bool = not Globals.items_db.has_equip_item(skill.id, ItemsDB.Item.SKILL)
				if locked and (hide_locked or skill.rarity in [
					ItemsDB.Rarity.SECRET,
					ItemsDB.Rarity.SPECIAL
				]):
					continue
				
				var item: TextureRect = _item_small_scene.instantiate()
				item.texture = load(skill.image_path)
				(item.get_node(^"Name") as Label).text = skill.name
				(item.get_node(^"Description") as Label).text = "%s\n%s" % [
					skill.brief_description.format(skill.stats),
					skill.usage_text.format(skill.stats),
				]
				(item.get_node(^"RarityFill") as ColorRect).color = \
						ItemsDB.RARITY_COLORS[skill.rarity]
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, skill.idx_in_db))
				add_child(item)
				
				if locked:
					(item as CanvasItem).modulate = LOCKED_ITEM_TINT
					(item.get_node(^"Description") as Label).text = "Не открыто"
				if selected_idx == skill.idx_in_db:
					(item.get_node(^"Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
		ItemsDB.Item.WEAPON:
			columns = 3
			for weapon: WeaponData in Globals.items_db.weapons:
				if weapon in Globals.items_db.other_weapons:
					continue
				var locked: bool = not Globals.items_db.has_equip_item(weapon.id,
						ItemsDB.Item.WEAPON)
				if locked and (hide_locked or weapon.rarity in [
					ItemsDB.Rarity.SECRET,
					ItemsDB.Rarity.SPECIAL
				]):
					continue
				
				var item: TextureRect = _item_small_scene.instantiate()
				item.texture = load(weapon.image_path)
				(item.get_node(^"Name") as Label).text = weapon.name
				(item.get_node(^"Description") as Label).text = "%s\n%s" % [
					weapon.ammo_text.format(weapon.stats),
					weapon.damage_text.format(weapon.stats),
				]
				(item.get_node(^"RarityFill") as ColorRect).color = \
						ItemsDB.RARITY_COLORS[weapon.rarity]
				(item.get_node(^"Click") as BaseButton).pressed.connect(
						_on_item_pressed.bind(type, weapon.idx_in_db))
				add_child(item)
				
				if locked:
					(item as CanvasItem).modulate = LOCKED_ITEM_TINT
					(item.get_node(^"Description") as Label).text = "Не открыто"
				if selected_idx == weapon.idx_in_db:
					(item.get_node(^"Name") as Label).add_theme_color_override(
							&"font_color", Color.GREEN)
					(item.get_node(^"Click") as Control).grab_focus()
					has_selected = true
		ItemsDB.Item.MAP:
			push_error("Use list_maps_of_event() or list_maps_of_challenge() instead.")
		_:
			push_error("Invalid type specified: %d." % type)
	
	if not has_selected and get_child_count() > 0:
		# фокусим первое для удобства
		await get_tree().process_frame # ждём queue_free вьбымфзкицуокфдывсзщйио
		(get_child(0).get_node(^"Click") as BaseButton).grab_focus()
	items_listed.emit(type)


## Очищает существующие предметы и отображает карты события, индекс которого указан
## в [param event_idx]. Опционально можно предоставить индекс в базе данных в [param selected_idx],
## чтобы выделить зелёным выбранную карту.
func list_maps_of_event(event_idx: int, selected_idx: int = -1) -> void:
	for child: Node in get_children():
		child.queue_free()
	
	columns = 1
	var counter: int = 0
	var has_selected := false
	for map: MapData in Globals.items_db.events[event_idx].maps:
		var item: TextureRect = _item_big_scene.instantiate()
		item.texture = load(map.image_path)
		(item.get_node(^"Container/Name") as Label).text = map.name
		(item.get_node(^"Container/Description") as Label).text = map.brief_description
		(item.get_node(^"Click") as BaseButton).pressed.connect(
				_on_item_pressed.bind(ItemsDB.Item.MAP, counter))
		add_child(item)
		
		if selected_idx == counter:
			(item.get_node(^"Container/Name") as Label).add_theme_color_override(
					&"font_color", Color.GREEN)
			(item.get_node(^"Click") as Control).grab_focus()
			has_selected = true
		counter += 1
	
	if not has_selected and get_child_count() > 0:
		# фокусим первое для удобства
		await get_tree().process_frame # ждём queue_free вьбымфзкицуокфдывсзщйио
		(get_child(0).get_node(^"Click") as BaseButton).grab_focus()
	items_listed.emit(ItemsDB.Item.MAP)


## Очищает существующие предметы и отображает карты испытания, индекс которого указан
## в [param challenge_idx]. Опционально можно предоставить индекс в базе данных в
## [param selected_idx], чтобы выделить зелёным выбранную карту.
func list_maps_of_challenge(challenge_idx: int, selected_idx: int = -1) -> void:
	for child: Node in get_children():
		child.queue_free()
	
	columns = 1
	var counter: int = 0
	var has_selected := false
	for map: MapData in Globals.items_db.challenges[challenge_idx].maps:
		var item: TextureRect = _item_big_scene.instantiate()
		item.texture = load(map.image_path)
		(item.get_node(^"Container/Name") as Label).text = map.name
		(item.get_node(^"Container/Description") as Label).text = map.brief_description
		(item.get_node(^"Click") as BaseButton).pressed.connect(
				_on_item_pressed.bind(ItemsDB.Item.MAP, counter))
		add_child(item)
		
		if selected_idx == counter:
			(item.get_node(^"Container/Name") as Label).add_theme_color_override(
					&"font_color", Color.GREEN)
			(item.get_node(^"Click") as Control).grab_focus()
			has_selected = true
		counter += 1
	
	if not has_selected and get_child_count() > 0:
		# фокусим первое для удобства
		await get_tree().process_frame # ждём queue_free вьбымфзкицуокфдывсзщйио
		(get_child(0).get_node(^"Click") as BaseButton).grab_focus()
	items_listed.emit(ItemsDB.Item.MAP)


## Очищает существующие предметы и отображает оружия, тип которых указан в [param type].
## Опционально можно предоставить индекс в базе данных в [param selected_idx],
## чтобы выделить зелёным выбранное оружие.[br]
## Если [param hide_locked] равен [code]false[/code], неразблокированные предметы будут показаны,
## но затемнены.
func list_weapons_by_type(type: Weapon.Type, selected_idx: int = -1, hide_locked := true) -> void:
	for child: Node in get_children():
		child.queue_free()
	
	var weapons_to_list: Array[WeaponData]
	match type:
		Weapon.Type.LIGHT:
			weapons_to_list = Globals.items_db.weapons_light
		Weapon.Type.HEAVY:
			weapons_to_list = Globals.items_db.weapons_heavy
		Weapon.Type.SUPPORT:
			weapons_to_list = Globals.items_db.weapons_support
		Weapon.Type.MELEE:
			weapons_to_list = Globals.items_db.weapons_melee
		_:
			push_error("Specified weapon type %d is invalid." % type)
			return
	
	columns = 3
	var has_selected := false
	for weapon: WeaponData in weapons_to_list:
		var locked: bool = not Globals.items_db.has_equip_item(weapon.id, ItemsDB.Item.WEAPON)
		if locked and (hide_locked or weapon.rarity in [
			ItemsDB.Rarity.SECRET,
			ItemsDB.Rarity.SPECIAL
		]):
			continue
		
		var item: TextureRect = _item_small_scene.instantiate()
		item.texture = load(weapon.image_path)
		(item.get_node(^"Name") as Label).text = weapon.name
		(item.get_node(^"Description") as Label).text = "%s\n%s" % [
			weapon.ammo_text.format(weapon.stats),
			weapon.damage_text.format(weapon.stats),
		]
		(item.get_node(^"RarityFill") as ColorRect).color = \
				ItemsDB.RARITY_COLORS[weapon.rarity]
		(item.get_node(^"Click") as BaseButton).pressed.connect(
				_on_item_pressed.bind(ItemsDB.Item.WEAPON, weapon.idx_in_db))
		add_child(item)
		
		if locked:
			(item as CanvasItem).modulate = LOCKED_ITEM_TINT
			(item.get_node(^"Description") as Label).text = "Не открыто"
		if selected_idx == weapon.idx_in_db:
			(item.get_node(^"Name") as Label).add_theme_color_override(
					&"font_color", Color.GREEN)
			(item.get_node(^"Click") as Control).grab_focus()
			has_selected = true
	
	if not has_selected and get_child_count() > 0:
		# фокусим первое для удобства
		await get_tree().process_frame # ждём queue_free вьбымфзкицуокфдывсзщйио
		(get_child(0).get_node(^"Click") as BaseButton).grab_focus()
	items_listed.emit(ItemsDB.Item.WEAPON)


## Очищает существующие предметы и отображает скины из линейки, индекс которой указан
## в [param line_idx]. Опционально можно предоставить индекс в базе данных в [param selected_idx],
## чтобы выделить зелёным выбранный скин.[br]
## Если [param hide_locked] равен [code]false[/code], неразблокированные предметы будут показаны,
## но затемнены.
func list_skins_line(line_idx: int, selected_idx: int = -1, hide_locked := true) -> void:
	for child: Node in get_children():
		child.queue_free()
	
	columns = 3
	var has_selected := false
	for skin: SkinData in Globals.items_db.skins_lines[line_idx].skins:
		var locked: bool = not Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN)
		if locked and (hide_locked or skin.rarity in [
			ItemsDB.Rarity.SECRET,
			ItemsDB.Rarity.SPECIAL
		]):
			continue
		
		var item: TextureRect = _item_small_scene.instantiate()
		item.texture = load(skin.image_path)
		(item.get_node(^"Name") as Label).text = skin.name
		(item.get_node(^"Description") as Label).text = skin.brief_description
		(item.get_node(^"Description") as Label).horizontal_alignment = \
				HORIZONTAL_ALIGNMENT_CENTER
		(item.get_node(^"RarityFill") as ColorRect).color = \
				ItemsDB.RARITY_COLORS[skin.rarity]
		(item.get_node(^"Click") as BaseButton).pressed.connect(
				_on_item_pressed.bind(ItemsDB.Item.SKIN, skin.idx_in_db))
		add_child(item)
		
		if locked:
			(item as CanvasItem).modulate = LOCKED_ITEM_TINT
			(item.get_node(^"Description") as Label).text = "Не открыто"
		if selected_idx == skin.idx_in_db:
			(item.get_node(^"Name") as Label).add_theme_color_override(
					&"font_color", Color.GREEN)
			(item.get_node(^"Click") as Control).grab_focus()
			has_selected = true
		items_listed.emit(ItemsDB.Item.SKIN)
	
	if not has_selected and get_child_count() > 0:
		# фокусим первое для удобства
		await get_tree().process_frame # ждём queue_free вьбымфзкицуокфдывсзщйио
		(get_child(0).get_node(^"Click") as BaseButton).grab_focus()


func _on_item_pressed(type: ItemsDB.Item, idx: int) -> void:
	item_selected.emit(type, idx)
