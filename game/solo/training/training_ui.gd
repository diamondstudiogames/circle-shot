extends CanvasLayer


var _selected_event: int = -1
var _selected_challenge: int = -1
var _selected_map: int = -1
var _selecting_event: int
var _selecting_challenge: int

var _prev_map_data: PackedByteArray
var _prev_enemies_data: Array[Dictionary]

@onready var _training: Training = get_parent()
@onready var _stats: Label = $Main/Stats

@onready var _equip_selector: EquipSelector = %EquipSelector
@onready var _item_selector: Window = %EquipSelector/ItemSelector
@onready var _items_grid: ItemsGrid = %EquipSelector/%ItemsGrid


func _ready() -> void:
	_items_grid.item_selected.connect(_on_item_selected)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when ($UI/Main as CanvasItem).visible:
			($QuitDialog as Window).popup_centered()


func _change_map() -> void:
	(%CurrentMap as Label).text = "Загрузка карты..."
	(%ReturnToTraining as CanvasItem).show()
	(%TrainingMap/Manage as CanvasItem).hide()
	(%TrainingMap/CantEdit as CanvasItem).show()
	(%MapPreview as CanvasItem).hide()
	
	await get_tree().process_frame
	if _selected_event >= 0:
		await _training.load_map(_selected_event, _selected_map, false)
		(%CurrentMap as Label).text = \
				Globals.items_db.events[_selected_event].maps[_selected_map].name
	elif _selected_challenge >= 0:
		await _training.load_map(_selected_challenge, _selected_map, true)
		(%CurrentMap as Label).text = \
				Globals.items_db.challenges[_selected_challenge].maps[_selected_map].name


func _on_item_selected(type: ItemsDB.Item, idx: int) -> void:
	match type:
		ItemsDB.Item.EVENT:
			_item_selector.title = "Выбор карты"
			_item_selector.show()
			_selecting_event = idx
			_items_grid.list_maps_of_event(_selecting_event,
					_selected_map if _selected_event == _selecting_event else -1)
		ItemsDB.Item.CHALLENGE:
			_item_selector.title = "Выбор карты"
			_item_selector.show()
			_selecting_challenge = idx
			_items_grid.list_maps_of_challenge(_selecting_challenge,
					_selected_map if _selected_challenge == _selecting_challenge else -1)
		ItemsDB.Item.MAP:
			if _selecting_event != -1 and _selecting_event == _selected_event \
					and _selected_map == idx:
				return
			elif _selecting_challenge != -1 and _selecting_challenge == _selected_challenge \
					and _selected_map == idx:
				return
			_selected_map = idx
			if _selecting_event >= 0:
				_selected_event = _selecting_event
				_selected_challenge = -1
			elif _selecting_challenge >= 0:
				_selected_event = -1
				_selected_challenge = _selecting_challenge
			_change_map()


func _on_quit_dialog_confirmed() -> void:
	Globals.main.game.close()


func _on_heal_pressed() -> void:
	_training.player_restore_health()


func _on_ammo_pressed() -> void:
	_training.player_restore_ammo()


func _on_skill_pressed() -> void:
	_training.player_restore_skill()


func _on_teleport_to_spawn_pressed() -> void:
	_training.player_teleport_to_spawn()


func _on_menu_pressed() -> void:
	($Menu as CanvasItem).show()
	($Main as CanvasItem).hide()
	get_tree().paused = true


func _on_close_pressed() -> void:
	($Menu as CanvasItem).hide()
	($Main as CanvasItem).show()
	get_tree().paused = false


func _on_close_note_pressed() -> void:
	get_tree().paused = false
	($Main as CanvasItem).show()
	($Guide as CanvasItem).hide()


func _on_equip_selector_items_changed() -> void:
	_training.player_update_equip(_equip_selector.selected_skin, _equip_selector.selected_skill,
			_equip_selector.selected_light_weapon, _equip_selector.selected_heavy_weapon,
			_equip_selector.selected_support_weapon, _equip_selector.selected_melee_weapon)


func _on_training_stats_changed() -> void:
	_stats.text = "Нанесённый урон: %d\nУбийств: %d\nСмертей: %d" % [
		_training.damaged,
		_training.kills,
		_training.deaths,
	]


func _on_return_to_training_pressed() -> void:
	_selected_event = -1
	_selected_map = -1
	(%CurrentMap as Label).text = "Загрузка карты..."
	(%ReturnToTraining as CanvasItem).hide()
	(%TrainingMap/Manage as CanvasItem).show()
	(%TrainingMap/CantEdit as CanvasItem).hide()
	(%MapPreview as CanvasItem).show()
	
	await get_tree().process_frame
	await _training.load_default_map()
	(%CurrentMap as Label).text = "Тренировка"


func _on_map_from_event_pressed() -> void:
	($SelectMap as Window).hide()
	_selecting_event = -1
	_selecting_challenge = -1
	_items_grid.list_items(ItemsDB.Item.EVENT, _selected_event)
	_item_selector.title = "Выбор события"
	_item_selector.popup_centered()


func _on_map_from_challenge_pressed() -> void:
	($SelectMap as Window).hide()
	_selecting_event = -1
	_selecting_challenge = -1
	_items_grid.list_items(ItemsDB.Item.CHALLENGE, _selected_challenge)
	_item_selector.title = "Выбор испытания"
	_item_selector.popup_centered()


func _on_map_changed() -> void:
	if not (%MapPreview as CanvasItem).visible:
		return
	
	var map_data: PackedByteArray = _training.get_map_data()
	var image := Image.create_empty(Training.MAP_SIZE.x, Training.MAP_SIZE.y,
			false, Image.FORMAT_RGBA8)
	
	var enemies_coords: Array[Vector2i]
	for enemy_data: Training.EnemyData in _training.enemies_data:
		enemies_coords.append(enemy_data.coords)
	
	for x: int in Training.MAP_SIZE.x:
		for y: int in Training.MAP_SIZE.y:
			var coords := Vector2i(x, y)
			if coords in enemies_coords:
				image.set_pixelv(coords, Color.RED)
			else:
				image.set_pixelv(coords,
						Training.BLOCK_COLORS[map_data[y * Training.MAP_SIZE.x + x]])
	
	var img_tex := ImageTexture.create_from_image(image)
	(%MapPreview as TextureRect).texture = img_tex


func _on_destroy_enemies_pressed() -> void:
	_training.enemies_destroy()


func _on_respawn_enemies_pressed() -> void:
	_training.enemies_respawn()


func _on_edit_map_pressed() -> void:
	($Menu/PanelContainer/MainMenu as CanvasItem).hide()
	($Menu/PanelContainer/MapEditor as CanvasItem).show()
	get_viewport().gui_snap_controls_to_pixels = false
	
	_prev_map_data = Globals.get_variant("custom_training_map", PackedByteArray())
	_prev_enemies_data = Globals.get_variant("custom_training_map_enemies",
			[{}] as Array[Dictionary])


func _on_close_map_editor_pressed() -> void:
	($Menu/PanelContainer/MainMenu as CanvasItem).show()
	($Menu/PanelContainer/MapEditor as CanvasItem).hide()
	get_viewport().gui_snap_controls_to_pixels = true
	
	if _prev_map_data != Globals.get_variant("custom_training_map", PackedByteArray()) \
			or _prev_enemies_data != Globals.get_variant("custom_training_map_enemies", [{}]):
		(%CurrentMap as Label).text = "Загрузка карты..."
		await get_tree().process_frame
		await _training.load_default_map()
		(%CurrentMap as Label).text = "Тренировка"


func _on_reset_stats_pressed() -> void:
	_training.reset_stats()
