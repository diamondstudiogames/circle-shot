extends Node2D

@export var maps_to_items: Dictionary[MapData, NodePath]
@onready var _training: Training = get_parent()

func _ready() -> void:
	if Time.get_datetime_dict_from_system()["hour"] != 3 or Globals.get_bool("quest_completed"):
		queue_free()
		return
	(get_node(^"../Music") as AudioStreamPlayer).volume_db = -60.0
	for map: MapData in maps_to_items:
		if not has_node(maps_to_items[map]):
			continue
		(get_node(maps_to_items[map]) as CanvasItem).hide()
		(get_node(maps_to_items[map]) as CanvasItem).hide()
		(get_node(maps_to_items[map]) as CanvasItem).process_mode = Node.PROCESS_MODE_DISABLED


func _player_start_ritual() -> void:
	_training.player.block_turning()
	_training.player.block_weapon_usage()
	_training.player.make_immobile()
	_training.player.make_immune()
	_training.player.visual.scale.x = 1.0
	$Pentagram/Interactible.process_mode = Node.PROCESS_MODE_DISABLED
	
	var book_anim: Node2D = (load("uid://8lxygh47wdpr") as PackedScene).instantiate()
	_training.player.visual.add_child(book_anim)
	
	var tween: Tween = create_tween()
	tween.tween_callback($"../UI/Main".set.bind(&"process_mode", PROCESS_MODE_DISABLED))
	tween.tween_property($"../UI/Main" as CanvasItem, ^":modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(($"../UI/Main" as CanvasItem).hide)


func _player_end_ritual() -> void:
	var tween: Tween = create_tween()
	tween.tween_callback(($"../UI/Main" as CanvasItem).show)
	tween.tween_property($"../UI/Main" as CanvasItem, ^":modulate", Color.WHITE, 1.0)
	tween.tween_callback($"../UI/Main".set.bind(&"process_mode", PROCESS_MODE_INHERIT))
	Globals.set_bool("quest_portal_opened", true)
	_update_pentagram()
	await tween.finished
	
	_training.player.unblock_turning()
	_training.player.unblock_weapon_usage()
	_training.player.unmake_immobile()
	_training.player.unmake_immune()
	$Pentagram/Interactible.process_mode = Node.PROCESS_MODE_INHERIT


func _update_pentagram() -> void:
	if not (
			Globals.get_bool("quest_item_chalk_collected")
			or Globals.get_bool("quest_item_candles_collected")
			or Globals.get_bool("quest_item_cross_collected")
			or Globals.get_bool("quest_item_book_collected")
	):
		$Pentagram/Interactible.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		$Pentagram/Interactible.process_mode = Node.PROCESS_MODE_INHERIT
	
	($Pentagram/Pentagram as CanvasItem).visible = Globals.get_bool("quest_item_chalk_collected")
	($Pentagram/Candles as CanvasItem).visible = Globals.get_bool("quest_item_candles_collected")
	($Pentagram/Cross as CanvasItem).visible = Globals.get_bool("quest_item_cross_collected")
	
	if Globals.get_bool("quest_portal_opened"):
		($Pentagram/AnimationPlayer as AnimationPlayer).play(&"ritual_done")
		($Pentagram/AnimationPlayer as AnimationPlayer).advance(0.0)
		($Pentagram/Interactible as Interactible).set_text("Войти в портал")
	elif not (
			Globals.get_bool("quest_item_chalk_collected")
			and Globals.get_bool("quest_item_candles_collected")
			and Globals.get_bool("quest_item_cross_collected")
			and Globals.get_bool("quest_item_book_collected")
	):
		($Pentagram/Interactible as Interactible).set_text("Собраны не все предметы")
	else:
		($Pentagram/Interactible as Interactible).set_text("Начать ритуал")


func _on_pentagram_interactible_interacted(_who: Player) -> void:
	if Globals.get_bool("quest_portal_opened"):
		_training.queue_free()
		await _training.tree_exited
		Globals.main.menu_music.process_mode = Node.PROCESS_MODE_DISABLED
		Globals.main.game.load_solo_world("uid://d37b6qih7jixf")
	elif (
			Globals.get_bool("quest_item_chalk_collected")
			and Globals.get_bool("quest_item_candles_collected")
			and Globals.get_bool("quest_item_cross_collected")
			and Globals.get_bool("quest_item_book_collected")
	):
		($Pentagram/AnimationPlayer as AnimationPlayer).play(&"ritual")


func _on_note_interactible_interacted(_who: Player) -> void:
	_training.show_note(true)


func _on_training_map_changed() -> void:
	# добавляем visible тк queue_free не моментален
	if not _training.current_map is Map and visible:
		_training.current_map.get_node(^"GuideNote").process_mode = Node.PROCESS_MODE_DISABLED
		(_training.current_map.get_node(^"GuideNote") as CanvasItem).hide()
		$Note.process_mode = Node.PROCESS_MODE_INHERIT
		($Note as CanvasItem).show()
		$Pentagram.process_mode = Node.PROCESS_MODE_INHERIT
		($Pentagram as CanvasItem).show()
		_update_pentagram()
		return
	$Pentagram.process_mode = Node.PROCESS_MODE_DISABLED
	($Pentagram as CanvasItem).hide()
	$Note.process_mode = Node.PROCESS_MODE_DISABLED
	($Note as CanvasItem).hide()
	
	var current_map: MapData = (_training.current_map as Map).data
	for map: MapData in maps_to_items:
		if not has_node(maps_to_items[map]):
			continue
		(get_node(maps_to_items[map]) as CanvasItem).visible = map == current_map
		(get_node(maps_to_items[map]) as CanvasItem).process_mode = \
				Node.PROCESS_MODE_INHERIT if map == current_map else Node.PROCESS_MODE_DISABLED
