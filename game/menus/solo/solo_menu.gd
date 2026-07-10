extends Control


var selected_challenge: int
var selected_maps: Array[int]

@onready var _game: Game = get_parent()
@onready var _equip_selector: EquipSelector = %EquipSelector
@onready var _item_selector: Window = %EquipSelector/ItemSelector
@onready var _items_grid: ItemsGrid = %EquipSelector/%ItemsGrid


func _ready() -> void:
	_game.started.connect(_on_game_started)
	_game.closed.connect(_on_game_closed)
	
	selected_challenge = Globals.get_int("selected_challenge")
	selected_maps = Globals.get_variant("selected_challenge_maps", [] as Array[int])
	if selected_maps.size() < Globals.items_db.challenges.size():
		selected_maps.resize(Globals.items_db.challenges.size())
	
	_validate_selected_environment()
	_update_environment()
	_items_grid.item_selected.connect(_on_item_selected)


func _notification(what: int) -> void:
	if _game.state != Game.State.CLOSED:
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when ($Challenges as CanvasItem).visible:
			_on_quit_challenges_pressed()
		NOTIFICATION_WM_GO_BACK_REQUEST when ($Base as CanvasItem).visible:
			_on_quit_pressed.call_deferred()


func _validate_selected_environment() -> void:
	var changed := false
	if selected_challenge < 0 or selected_challenge >= Globals.items_db.challenges.size():
		push_warning("Incorrect selected challenge: %d. Reverting to default." % selected_challenge)
		selected_challenge = 0
		changed = true
	for challenge_idx: int in Globals.items_db.challenges.size():
		if selected_maps[challenge_idx] < 0 or selected_maps[challenge_idx] \
				>= Globals.items_db.challenges[challenge_idx].maps.size():
			push_warning("Incorrect selected map for challenge %d: %d. Reverting to default." % [
				challenge_idx,
				selected_maps[challenge_idx],
			])
			selected_maps[challenge_idx] = 0
			changed = true
	
	if changed:
		_save_selected_environment()


func _save_selected_environment() -> void:
	Globals.set_int("selected_challenge", selected_challenge)
	Globals.set_variant("selected_challenge_maps", selected_maps)


func _update_environment() -> void:
	var challenge: ChallengeData = Globals.items_db.challenges[selected_challenge]
	(%Challenge as TextureRect).texture = load(challenge.image_path)
	(%Challenge/Container/Name as Label).text = challenge.name
	(%Challenge/Container/Description as Label).text = challenge.brief_description
	
	(%Map/Container/Name as Label).text = challenge.maps[selected_maps[selected_challenge]].name
	(%Map/Container/Description as Label).text = \
			challenge.maps[selected_maps[selected_challenge]].brief_description
	(%Map as TextureRect).texture = \
			load(challenge.maps[selected_maps[selected_challenge]].image_path)


func _on_game_started() -> void:
	hide()


func _on_game_closed() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	_equip_selector._ready() # обновляем экипировку, выбранную вне этого меню


func _on_item_selected(type: ItemsDB.Item, idx: int) -> void:
	match type:
		ItemsDB.Item.CHALLENGE:
			selected_challenge = idx
		ItemsDB.Item.MAP:
			selected_maps[selected_challenge] = idx
	_save_selected_environment()
	_update_environment()


func _on_story_pressed() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	pass


func _on_challenges_pressed() -> void:
	($Base as CanvasItem).hide()
	($Challenges as CanvasItem).show()


func _on_training_pressed() -> void:
	_game.load_solo_world("uid://f6bay2nx1wy3")
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_quit_pressed() -> void:
	Globals.main.open_menu()


func _on_tutorial_dialog_confirmed() -> void:
	_game.load_solo_world("uid://cbue2vn1da0il")
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_quit_challenges_pressed() -> void:
	($Base as CanvasItem).show()
	($Challenges as CanvasItem).hide()


func _on_start_challenge_pressed() -> void:
	_game.load_challenge(selected_challenge, selected_maps[selected_challenge], [
		Globals.items_db.skins_by_id[_equip_selector.selected_skin].idx_in_db,
		Globals.items_db.skills_by_id[_equip_selector.selected_skill].idx_in_db,
		Globals.items_db.weapons_by_id[_equip_selector.selected_light_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[_equip_selector.selected_heavy_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[_equip_selector.selected_support_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[_equip_selector.selected_melee_weapon].idx_in_db,
	])
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_change_challenge_pressed() -> void:
	_item_selector.title = "Выбор испытания"
	_item_selector.popup_centered()
	_items_grid.list_items(ItemsDB.Item.CHALLENGE, selected_challenge)


func _on_change_map_pressed() -> void:
	_item_selector.title = "Выбор карты"
	_item_selector.popup_centered()
	_items_grid.list_maps_of_challenge(selected_challenge, selected_maps[selected_challenge])
