extends World


@export_multiline var texts: Array[String]

var _prev_joystick_fire: bool
var _player: Player

var _picked_up_items: int = 0
var _skill_used: int = 0
var _conditions_met: int = 0


func _enter_tree() -> void:
	_prev_joystick_fire = Globals.get_controls_bool("joystick_fire")
	Globals.set_controls_bool("joystick_fire", false)


func _exit_tree() -> void:
	super()
	Globals.set_controls_bool("joystick_fire", _prev_joystick_fire)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			($UI/QuitDialog as Window).popup_centered()


func _initialize() -> void:
	($Music as AudioStreamPlayer).stream = tracks.pick_random()
	($Music as AudioStreamPlayer).play()
	
	for spawn_point: Marker2D in $Map/DummySpawnPoints.get_children():
		spawn_dummy(spawn_point.global_position)
	spawn_player()
	stats_changed.connect(_on_stats_changed)
	
	match Globals.get_current_input_method():
		Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[0] % [
				_action_as_string("move_left"),
				_action_as_string("move_right"),
				_action_as_string("move_up"),
				_action_as_string("move_down"),
				_action_as_string("sneak"),
			])
		Globals.InputMethod.TOUCH:
			show_text(texts[1])
		Globals.InputMethod.CONTROLLER:
			show_text(texts[25] % [
				_action_as_string("c_move_left"),
				_action_as_string("c_move_right"),
				_action_as_string("c_move_up"),
				_action_as_string("c_move_down"),
			])


func show_text(text: String) -> void:
	($UI/Main/RichTextLabel as RichTextLabel).text = text


func spawn_player() -> void:
	var player: Player = entity_scenes[0].instantiate()
	player.position = ($Map/SpawnPoint as Node2D).global_position
	player.team = 0
	player.id = multiplayer.get_unique_id()
	player.player_name = Globals.get_string("player_name")
	player.equip_data = [
		Globals.items_db.skins_by_id[Globals.get_string("selected_skin")].idx_in_db,
		-1,
		-1,
		-1,
		-1,
		-1,
		-1,
	]
	player.name = "Player%d" % player.id
	player.weapon_changed.connect(_on_player_weapon_changed)
	_player = player
	entities_parent.add_child(player, true)


func spawn_dummy(where: Vector2) -> void:
	var enemy: Entity = entity_scenes[1].instantiate()
	enemy.position = where
	enemy.team = 1
	enemy.id = -randi()
	enemy.name += str(enemy.id)
	entities_parent.add_child(enemy, true)


func _action_as_string(action: String) -> String:
	var encoded_input_event_types: Array[Globals.EncodedInputEventType] = \
			Globals.get_controls_variant("action_%s_event_types" % action, [] as Array[int])
	var encoded_input_event_values: Array[int] = \
			Globals.get_controls_variant("action_%s_event_values" % action, [] as Array[int])
	
	var string: String = "не выбрано"
	var first := true
	for idx: int in encoded_input_event_types.size():
		var encoded_input_event_type: Globals.EncodedInputEventType = encoded_input_event_types[idx]
		var encoded_input_event_value: int = encoded_input_event_values[idx]
		var event_as_string: String = Utils.encoded_input_event_as_text(encoded_input_event_type,
				encoded_input_event_value)
		if first:
			string = event_as_string
		if not first:
			string += "/"
			string += event_as_string
	
	return string


func _check_conditions() -> void:
	if _picked_up_items == 1 and _conditions_met == 0:
		_conditions_met += 1
		($UI/Main/PlayerUI/Controller/TouchControls/AimVirtualJoystick as CanvasItem).show()
		($UI/Main/PlayerUI/%ShootAreaHint as CanvasItem).show()
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[5] % [_action_as_string("show_aim"), _action_as_string("shoot")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[6])
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[26] % [
				_action_as_string("c_aim_left"),
				_action_as_string("c_aim_right"),
				_action_as_string("c_aim_up"),
				_action_as_string("c_aim_down"),
				_action_as_string("c_shoot"),
			])
	if kills == 1 and _conditions_met == 1:
		_conditions_met += 1
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[7] % [_action_as_string("reload")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[8])
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[7] % [_action_as_string("c_reload")])
		$Map/Gates/Gate.queue_free()
	if _picked_up_items == 2 and _conditions_met == 2:
		_conditions_met += 1
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[11] % [_action_as_string("weapon_heavy")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[12])
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[11] % [_action_as_string("c_weapon_heavy")])
	if kills == 4 and _conditions_met == 3:
		_conditions_met += 1
		$Map/Gates/Gate2.queue_free()
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[13] % [_action_as_string("show_weapons")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[14])
			($UI/ShootDialog as Window).popup_centered()
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[13] % [_action_as_string("c_show_weapons")])
	if kills == 8 and _picked_up_items == 4 and _conditions_met == 4:
		_conditions_met += 1
		$Map/Gates/Gate3.queue_free()
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[18] % [_action_as_string("additional_button")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[19])
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[18] % [_action_as_string("c_additional_button")])
	if _picked_up_items == 5 and _conditions_met == 5:
		_conditions_met += 1
		_player.damage(70)
		_player.skill_used.connect(_on_skill_used)
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[21] % [_action_as_string("use_skill")])
		elif Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[22])
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[21] % [_action_as_string("c_use_skill")])
	if _skill_used == 1 and _conditions_met == 6:
		_conditions_met += 1
		$Map/Gates/Gate4.queue_free()
		show_text(texts[23])


func _on_stats_changed() -> void:
	_check_conditions()


func _on_skill_used() -> void:
	_skill_used += 1
	_check_conditions()


func _on_weapon_ammo_changed(_in_stock: bool) -> void:
	if is_instance_valid(_player.current_weapon) \
			and _player.current_weapon.ammo + _player.current_weapon.ammo_in_stock == 0 \
			and _player.current_weapon.ammo_total > 0:
		_player.add_ammo_to_weapon.rpc(_player.current_weapon_type, 1.0)
		show_text(texts[4])


func _on_player_weapon_changed(_to: Weapon.Type) -> void:
	if not is_instance_valid(_player.current_weapon):
		return
	if not _player.current_weapon.ammo_changed.is_connected(_on_weapon_ammo_changed):
		_player.current_weapon.ammo_changed.connect(_on_weapon_ammo_changed)


func _on_trigger_body_entered(body: Node2D, source: Area2D, idx: int) -> void:
	if not body is Player:
		return
	source.queue_free()
	match idx:
		0 when Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[2] % _action_as_string("interact"))
		0 when Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[3])
		0 when Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[2] % _action_as_string("c_interact"))
		1 when Globals.get_current_input_method() in [
			Globals.InputMethod.KEYBOARD_AND_MOUSE,
			Globals.InputMethod.CONTROLLER,
		]:
			show_text(texts[9])
		1 when Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			show_text(texts[10])
			($UI/Main/PlayerUI/%ShootAreaHint as CanvasItem).hide()
			Globals.set_controls_bool("joystick_fire", true)
			Globals.apply_controls_settings()
		2 when Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE:
			show_text(texts[15] % [
				_action_as_string("weapon_support"),
				_action_as_string("weapon_melee"),
			])
		2 when Globals.get_current_input_method() == Globals.InputMethod.TOUCH:
			if _prev_joystick_fire:
				show_text(texts[16])
			else:
				show_text(texts[17])
		2 when Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER:
			show_text(texts[15] % [
				_action_as_string("c_weapon_support"),
				_action_as_string("c_weapon_melee"),
			])
		3:
			show_text(texts[20])
		4:
			show_text(texts[24])


func _on_pickable_equip_item_picked_up(_by: int) -> void:
	_picked_up_items += 1
	_check_conditions()


func _on_shoot_dialog_confirmed() -> void:
	Globals.set_controls_bool("joystick_fire", false)
	Globals.apply_controls_settings()


func _on_shoot_dialog_canceled() -> void:
	Globals.set_controls_bool("joystick_fire", true)
	Globals.apply_controls_settings()


func _on_finish_interactible_interacted(_who: Player) -> void:
	($UI/End/AnimationPlayer as AnimationPlayer).play(&"end")
	await ($UI/End/AnimationPlayer as AnimationPlayer).animation_finished
	Globals.main.game.close()


func _on_pause_dialog_visibility_changed() -> void:
	get_tree().paused = ($UI/PauseDialog as Window).visible


func _on_quit_pressed() -> void:
	get_tree().paused = false
	Globals.main.game.close()
