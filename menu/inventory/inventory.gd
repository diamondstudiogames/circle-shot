extends Control


var _hide_locked := false
var _type_to_list := ItemsDB.Item.WEAPON
var _weapon_type_filter := Weapon.Type.INVALID # все
var _skins_line_filter: int = -1 # все
var _event_map_filter: int = -1 # пока никакое
var _challenge_map_filter: int = -1 # пока никакое

var _selected_item_type := ItemsDB.Item.EVENT
var _selected_item_idx: int = -1

@onready var _items_grid: ItemsGrid = %ItemsGrid


func _ready() -> void:
	(%Description as CanvasItem).hide()
	
	for skins_line: SkinsLineData in Globals.items_db.skins_lines:
		(%Filters/SkinsFilter as OptionButton).add_item(skins_line.name)
	
	_update_items_grid()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when visible:
			_on_quit_pressed()


func _update_items_grid() -> void:
	if _type_to_list == ItemsDB.Item.WEAPON and _weapon_type_filter != Weapon.Type.INVALID:
		_items_grid.list_weapons_by_type(_weapon_type_filter, -1, _hide_locked)
	elif _type_to_list == ItemsDB.Item.SKIN and _skins_line_filter >= 0:
		_items_grid.list_skins_line(_skins_line_filter, -1, _hide_locked)
	elif _type_to_list == ItemsDB.Item.MAP:
		if _event_map_filter >= 0:
			_items_grid.list_maps_of_event(_event_map_filter)
		elif _challenge_map_filter >= 0:
			_items_grid.list_maps_of_challenge(_challenge_map_filter)
	else:
		_items_grid.list_items(_type_to_list, -1, _hide_locked)


func _show_item(type: ItemsDB.Item, idx: int) -> void:
	(%Description as CanvasItem).show()
	(%NothingSelected as CanvasItem).hide()
	(%Description/SmallItem as CanvasItem).hide()
	(%Description/BigItem as CanvasItem).hide()
	(%Description/ShowItems as CanvasItem).hide()
	
	_selected_item_type = type
	_selected_item_idx = idx
	
	var item_name: String
	var description: String
	var unlocked := true
	match type:
		ItemsDB.Item.EVENT:
			var event: EventData = Globals.items_db.events[idx]
			item_name = event.name
			description = "[center]%s[/center]" % event.brief_description
			description += '\n'
			description += "\nМинимум игроков: [color=red]%d[/color]" % event.min_players
			description += "\nМаксимум игроков: [color=red]%d[/color]" % event.max_players
			description += "\nДелитель игроков: [color=red]%d[/color]" % event.players_divider
			description += "\nКомандное: [color=%s]%s[/color]" % \
					(["lime_green", "Да"] if event.team_event else ["red", "Нет"])
			description += '\n'
			description += '\n' + event.description
			description += '\n'
			description += "\nКоличество карт: [color=lime_green]%d[/color]" % event.maps.size()
			
			(%Description/BigItem as CanvasItem).show()
			(%Description/BigItem as TextureRect).texture = load(event.image_path)
			
			(%Description/ShowItems as CanvasItem).show()
			(%Description/ShowItems as Button).text = "Просмотреть карты"
		ItemsDB.Item.CHALLENGE:
			var challenge: ChallengeData = Globals.items_db.challenges[idx]
			item_name = challenge.name
			description = "[center]%s[/center]" % challenge.brief_description
			description += '\n'
			description += '\n' + challenge.description
			description += '\n'
			description += "\nКоличество карт: [color=lime_green]%d[/color]" % challenge.maps.size()
			
			(%Description/BigItem as CanvasItem).show()
			(%Description/BigItem as TextureRect).texture = load(challenge.image_path)
			
			(%Description/ShowItems as CanvasItem).show()
			(%Description/ShowItems as Button).text = "Просмотреть карты"
		ItemsDB.Item.MAP:
			var map: MapData
			if _event_map_filter >= 0:
				map = Globals.items_db.events[_event_map_filter].maps[idx]
			elif _challenge_map_filter >= 0:
				map = Globals.items_db.challenges[_challenge_map_filter].maps[idx]
			item_name = map.name
			description = "[center]%s[/center]" % map.brief_description
			description += '\n'
			description += "\nРазмер карты: [color=blue]%d на %d[/color]" % [map.size.x, map.size.y]
			description += '\n'
			if _event_map_filter >= 0:
				description += "\nСобытие: [color=red]%s[/color]" \
						% Globals.items_db.events[_event_map_filter].name
			elif _challenge_map_filter >= 0:
				description += "\nИспытание: [color=red]%s[/color]" \
						% Globals.items_db.challenges[_challenge_map_filter].name
			
			(%Description/BigItem as CanvasItem).show()
			(%Description/BigItem as TextureRect).texture = load(map.image_path)
			
			(%Description/ShowItems as CanvasItem).show()
			if _event_map_filter >= 0:
				(%Description/ShowItems as Button).text = "Просмотреть событие"
			elif _challenge_map_filter >= 0:
				(%Description/ShowItems as Button).text = "Просмотреть испытание"
		ItemsDB.Item.SKIN:
			var skin: SkinData = Globals.items_db.skins[idx]
			item_name = skin.name
			if not Globals.items_db.has_equip_item(skin.id, type):
				description = "Ещё не открыто"
				unlocked = false
			else:
				description = "[center]%s[/center]" % skin.brief_description
				description += '\n'
				description += "\nОсобый эффект получения урона: %s" % (
						"[color=lime_green]есть[/color]"
						if skin.custom_hurt_vfx else
						"[color=red]нет[/color]"
				)
				description += "\nОсобый эффект смерти: %s" % (
						"[color=lime_green]есть[/color]"
						if skin.custom_death_vfx else
						"[color=red]нет[/color]"
				)
				description += "\nОсобый эффект лечения: %s" % (
						"[color=lime_green]есть[/color]"
						if skin.custom_heal_vfx else
						"[color=red]нет[/color]"
				)
				description += "\nОсобый эффект истекания кровью: %s" % (
						"[color=lime_green]есть[/color]"
						if skin.custom_blood_vfx else
						"[color=red]нет[/color]"
				)
				description += "\nОсобые анимации: %s" % (
						"[color=lime_green]есть[/color]"
						if skin.custom_animations else
						"[color=red]нет[/color]"
				)
			description += "\n\nЛинейка: [color=red]%s[/color]" \
					% Globals.items_db.skins_lines[_find_skins_line_idx(idx)].name
			
			description += "\n\nРедкость: [outline_size=2][color=#%s]%s[/color][/outline_size]" % [
				ItemsDB.RARITY_COLORS[skin.rarity].to_html(false),
				ItemsDB.RARITY_NAMES[skin.rarity],
			]
			
			(%Description/SmallItem as CanvasItem).show()
			(%Description/SmallItem as ColorRect).color = ItemsDB.RARITY_COLORS[skin.rarity]
			(%Description/SmallItem/Texture as TextureRect).texture = load(skin.image_path)
			
			(%Description/ShowItems as CanvasItem).show()
			(%Description/ShowItems as Button).text = "Просмотреть линейку"
		ItemsDB.Item.SKILL:
			var skill: SkillData = Globals.items_db.skills[idx]
			item_name = skill.name
			if not Globals.items_db.has_equip_item(skill.id, type):
				description = "Ещё не открыто"
				unlocked = false
			else:
				description = skill.description.format(skill.stats)
			
			description += "\n\nРедкость: [outline_size=2][color=#%s]%s[/color][/outline_size]" % [
				ItemsDB.RARITY_COLORS[skill.rarity].to_html(false),
				ItemsDB.RARITY_NAMES[skill.rarity],
			]
			
			(%Description/SmallItem as CanvasItem).show()
			(%Description/SmallItem as ColorRect).color = ItemsDB.RARITY_COLORS[skill.rarity]
			(%Description/SmallItem/Texture as TextureRect).texture = load(skill.image_path)
		ItemsDB.Item.WEAPON:
			var weapon: WeaponData = Globals.items_db.weapons[idx]
			item_name = weapon.name
			if not Globals.items_db.has_equip_item(weapon.id, type):
				description = "Ещё не открыто"
				unlocked = false
			else:
				description = weapon.description.format(weapon.stats)
			
			description += "\n\nРедкость: [outline_size=2][color=#%s]%s[/color][/outline_size]" % [
				ItemsDB.RARITY_COLORS[weapon.rarity].to_html(false),
				ItemsDB.RARITY_NAMES[weapon.rarity],
			]
			
			(%Description/SmallItem as CanvasItem).show()
			(%Description/SmallItem as ColorRect).color = ItemsDB.RARITY_COLORS[weapon.rarity]
			(%Description/SmallItem/Texture as TextureRect).texture = load(weapon.image_path)
		ItemsDB.Item.SKINS_LINE:
			var skins_line: SkinsLineData = Globals.items_db.skins_lines[idx]
			item_name = skins_line.name
			description = "[center]%s[/center]" % skins_line.brief_description
			
			description += "\n\nВсего скинов: [color=red]%d[/color]" % skins_line.skins.size()
			var unlocked_count: int = 0
			for skin: SkinData in skins_line.skins:
				if Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN):
					unlocked_count += 1
			if unlocked_count == 0:
				unlocked = false
			description += "\nОткрыто скинов: [color=lime_green]%d[/color]" % unlocked_count
			
			(%Description/BigItem as CanvasItem).show()
			(%Description/BigItem as TextureRect).texture = load(skins_line.image_path)
			
			if not _hide_locked or unlocked_count > 0:
				(%Description/ShowItems as CanvasItem).show()
				(%Description/ShowItems as Button).text = "Просмотреть скины"
	
	(%Description/Name as Label).text = item_name
	(%Description/Text as RichTextLabel).text = description
	(%Description/SmallItem as CanvasItem).modulate = \
			Color.WHITE if unlocked else ItemsGrid.LOCKED_ITEM_TINT
	(%Description/BigItem as CanvasItem).modulate = \
			Color.WHITE if unlocked else ItemsGrid.LOCKED_ITEM_TINT


func _find_skins_line_idx(skin_idx: int) -> int:
	var skins_line_idx: int = 0
	for skins_line: SkinsLineData in Globals.items_db.skins_lines:
		for skin: SkinData in skins_line.skins:
			if skin.idx_in_db == skin_idx:
				return skins_line_idx
		skins_line_idx += 1
	return -1


func _on_quit_pressed() -> void:
	queue_free()


func _on_only_unlocked_toggled(toggled_on: bool) -> void:
	_hide_locked = toggled_on
	_update_items_grid()


func _on_main_filter_item_selected(index: int) -> void:
	(%Description as CanvasItem).hide()
	(%NothingSelected as CanvasItem).show()
	(%Filters/WeaponsFilter as CanvasItem).hide()
	(%Filters/SkinsFilter as CanvasItem).hide()
	(%OnlyUnlocked as CanvasItem).hide()
	
	match index:
		0:
			_type_to_list = ItemsDB.Item.WEAPON
			(%Filters/WeaponsFilter as CanvasItem).show()
			(%OnlyUnlocked as CanvasItem).show()
		1:
			_type_to_list = ItemsDB.Item.SKILL
			(%OnlyUnlocked as CanvasItem).show()
		2:
			_type_to_list = ItemsDB.Item.SKIN
			(%Filters/SkinsFilter as CanvasItem).show()
			(%OnlyUnlocked as CanvasItem).show()
		3:
			_type_to_list = ItemsDB.Item.SKINS_LINE
			(%OnlyUnlocked as CanvasItem).show()
		4:
			_type_to_list = ItemsDB.Item.EVENT
		5:
			_type_to_list = ItemsDB.Item.CHALLENGE
	
	_update_items_grid()


func _on_weapons_filter_item_selected(index: int) -> void:
	if index == 0:
		_weapon_type_filter = Weapon.Type.INVALID
	else:
		_weapon_type_filter = index - 1 as Weapon.Type
	_update_items_grid()


func _on_skins_filter_item_selected(index: int) -> void:
	_skins_line_filter = index - 1
	_update_items_grid()


func _on_items_grid_item_selected(type: ItemsDB.Item, idx: int) -> void:
	_show_item(type, idx)


func _on_show_items_pressed() -> void:
	match _selected_item_type:
		ItemsDB.Item.SKINS_LINE:
			_skins_line_filter = _selected_item_idx
			(%Filters/SkinsFilter as OptionButton).select(_selected_item_idx + 1)
			(%Filters/MainFilter as OptionButton).select(2)
			_on_main_filter_item_selected(2)
		ItemsDB.Item.EVENT:
			(%Description as CanvasItem).hide()
			(%NothingSelected as CanvasItem).show()
			_event_map_filter = _selected_item_idx
			_challenge_map_filter = -1
			_type_to_list = ItemsDB.Item.MAP
			_update_items_grid()
		ItemsDB.Item.CHALLENGE:
			(%Description as CanvasItem).hide()
			(%NothingSelected as CanvasItem).show()
			_event_map_filter = -1
			_challenge_map_filter = _selected_item_idx
			_type_to_list = ItemsDB.Item.MAP
			_update_items_grid()
		ItemsDB.Item.MAP:
			if _event_map_filter >= 0:
				_type_to_list = ItemsDB.Item.EVENT
			elif _challenge_map_filter >= 0:
				_type_to_list = ItemsDB.Item.CHALLENGE
			_update_items_grid()
			if _event_map_filter >= 0:
				_show_item(ItemsDB.Item.EVENT, _event_map_filter)
			elif _challenge_map_filter >= 0:
				_show_item(ItemsDB.Item.CHALLENGE, _challenge_map_filter)
		ItemsDB.Item.SKIN:
			(%Filters/MainFilter as OptionButton).select(3)
			_on_main_filter_item_selected(3)
			_show_item(ItemsDB.Item.SKINS_LINE, _find_skins_line_idx(_selected_item_idx))
