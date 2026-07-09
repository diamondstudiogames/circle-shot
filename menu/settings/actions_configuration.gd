extends Window


var _action_events: Dictionary[StringName, Array] # Array[EncodedInputEvent]

var _waiting_for_input := false
var _editing_action: StringName
var _editing_action_event_idx: int
var _event_candidate: EncodedInputEvent
var _pending_actions: Array[StringName]

var _action_event_scene: PackedScene = load("uid://b8cprl60iu2or")


func _ready() -> void:
	if not OS.has_feature("pc"):
		(%Actions/Fullscreen as CanvasItem).hide()
	($EventSelector as AcceptDialog).get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_keys_from_map()


func add_action_event(action: StringName) -> void:
	edit_action_event(action, _action_events[action].size())
	($EventSelector as Window).title = 'Добавление клавиши к действию "%s"...' % \
			(%Actions.get_node(action.to_pascal_case()).get_node(^"Container/Name") as Label).text


func edit_action_event(action: StringName, event_idx: int) -> void:
	_editing_action = action
	_editing_action_event_idx = event_idx
	_waiting_for_input = true
	($EventSelector as AcceptDialog).get_ok_button().hide()
	($EventSelector as ConfirmationDialog).get_cancel_button().hide()
	($EventSelector as Window).title = 'Редактирование действия "%s"...' % \
			(%Actions.get_node(action.to_pascal_case()).get_node(^"Container/Name") as Label).text
	($EventSelector as AcceptDialog).dialog_text = "Ожидание ввода..."
	($EventSelector as Window).popup_centered()


func remove_action_event(action: StringName, event_idx: int) -> void:
	var events_container: VBoxContainer = %Actions.get_node(
				action.to_pascal_case()).get_node(^"Container/Events")
	var event: Control = events_container.get_child(event_idx)
	if event.is_ancestor_of(get_viewport().gui_get_focus_owner()):
		($VBoxContainer/Buttons/Save as Control).grab_focus()
	event.queue_free()
	events_container.remove_child(event)
	_action_events[action].remove_at(event_idx)
	
	for i: int in range(event_idx, _action_events[action].size()):
		var encoded_event: EncodedInputEvent = _action_events[action][i]
		encoded_event.idx = i
		(events_container.get_child(i).get_node(^"Edit") as BaseButton).pressed.disconnect(
				edit_action_event)
		(events_container.get_child(i).get_node(^"Edit") as BaseButton).pressed.connect(
				edit_action_event.bind(action, i))
		(events_container.get_child(i).get_node(^"Remove") as BaseButton).pressed.disconnect(
				remove_action_event)
		(events_container.get_child(i).get_node(^"Remove") as BaseButton).pressed.connect(
				remove_action_event.bind(action, i))
	
	if not action in _pending_actions:
		_pending_actions.append(action)
	($VBoxContainer/Buttons/Save as BaseButton).disabled = false
	($VBoxContainer/Buttons/Discard as BaseButton).disabled = false


func _load_keys_from_map() -> void:
	_action_events.clear()
	for action: PanelContainer in %Actions.get_children():
		action.hide()
	for action: StringName in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue
		
		(%Actions.get_node(action.to_pascal_case()) as CanvasItem).show()
		var events_container: VBoxContainer = %Actions.get_node(
				action.to_pascal_case()).get_node(^"Container/Events")
		for child: Node in events_container.get_children():
			child.queue_free()
		
		_action_events[action] = [] as Array[EncodedInputEvent]
		var idx: int = 0
		for event: InputEvent in InputMap.action_get_events(action):
			var encoded_event := EncodedInputEvent.new()
			encoded_event.idx = idx
			var mb := event as InputEventMouseButton
			if mb:
				encoded_event.type = Globals.EncodedInputEventType.MOUSE_BUTTON
				encoded_event.value = mb.button_index
			var key := event as InputEventKey
			if key:
				encoded_event.type = Globals.EncodedInputEventType.KEY
				encoded_event.value = key.keycode
			var jb := event as InputEventJoypadButton
			if jb:
				encoded_event.type = Globals.EncodedInputEventType.JOYPAD_BUTTON
				encoded_event.value = jb.button_index
			var jm := event as InputEventJoypadMotion
			if jm:
				encoded_event.type = Globals.EncodedInputEventType.JOYPAD_MOTION
				encoded_event.value = jm.axis * 2
				if jm.axis_value > 0.0:
					encoded_event.value += 1
			
			_action_events[action].append(encoded_event)
			_create_action_event(action, events_container, encoded_event)
			idx += 1


func _set_event_candidate(encoded_event: EncodedInputEvent) -> void:
	_event_candidate = encoded_event
	($EventSelector as AcceptDialog).dialog_text = _encoded_input_event_as_text(encoded_event)
	($EventSelector as AcceptDialog).get_ok_button().show()
	($EventSelector as AcceptDialog).get_ok_button().grab_focus()
	($EventSelector as ConfirmationDialog).get_cancel_button().show()


func _create_action_event(action: StringName, parent: Node,
		encoded_event: EncodedInputEvent) -> void:
	var event_node: HBoxContainer = _action_event_scene.instantiate()
	event_node.name = "ActionEvent%d%d" % [encoded_event.type, encoded_event.value]
	(event_node.get_node(^"Event") as Label).text = _encoded_input_event_as_text(encoded_event)
	(event_node.get_node(^"Edit") as BaseButton).pressed.connect(
			edit_action_event.bind(action, encoded_event.idx))
	(event_node.get_node(^"Remove") as BaseButton).pressed.connect(
			remove_action_event.bind(action, encoded_event.idx))
	parent.add_child(event_node)


func _encoded_input_event_as_text(encoded_input_event: EncodedInputEvent) -> String:
	return Utils.encoded_input_event_as_text(encoded_input_event.type, encoded_input_event.value)


func _on_event_selector_window_input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	var new_event := EncodedInputEvent.new()
	new_event.idx = _editing_action_event_idx
	
	var recognized := false
	
	if Globals.get_controls_int("input_method") == Globals.InputMethod.KEYBOARD_AND_MOUSE:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index != MOUSE_BUTTON_NONE:
			recognized = true
			new_event.type = Globals.EncodedInputEventType.MOUSE_BUTTON
			new_event.value = mb.button_index
		
		var key := event as InputEventKey
		if key:
			recognized = true
			new_event.type = Globals.EncodedInputEventType.KEY
			new_event.value = key.keycode
	elif Globals.get_controls_int("input_method") == Globals.InputMethod.CONTROLLER:
		var jb := event as InputEventJoypadButton
		if jb:
			recognized = true
			new_event.type = Globals.EncodedInputEventType.JOYPAD_BUTTON
			new_event.value = jb.button_index
		
		var jm := event as InputEventJoypadMotion
		if jm and absf(jm.axis_value) > 0.5:
			recognized = true
			new_event.type = Globals.EncodedInputEventType.JOYPAD_MOTION
			new_event.value = jm.axis * 2
			if jm.axis_value > 0.0:
				new_event.value += 1
	
	if not recognized:
		return
	($EventSelector as Window).set_input_as_handled()
	
	for action: StringName in _action_events:
		for action_event: EncodedInputEvent in _action_events[action]:
			if action_event.type == new_event.type and action_event.value == new_event.value:
				if _editing_action == action:
					($EventSelector as AcceptDialog).dialog_text = \
							"Эта кнопка занята этим же действием."
				else:
					($EventSelector as AcceptDialog).dialog_text = \
							"Эта кнопка занята другим действием."
				return
	
	_waiting_for_input = false
	_set_event_candidate.call_deferred(new_event)


func _on_save_pressed() -> void:
	for action: StringName in _pending_actions:
		var encoded_input_event_types: Array[Globals.EncodedInputEventType]
		var encoded_input_event_values: Array[int]
		
		for encoded_input_event: EncodedInputEvent in _action_events[action]:
			encoded_input_event_types.append(encoded_input_event.type)
			encoded_input_event_values.append(encoded_input_event.value)
		
		Globals.set_controls_variant("action_%s_event_types" % action,
				encoded_input_event_types)
		Globals.set_controls_variant("action_%s_event_values" % action,
				encoded_input_event_values)
	
	Globals.apply_controls_settings()
	_pending_actions.clear()
	_load_keys_from_map()
	($VBoxContainer/Buttons/Save as BaseButton).disabled = true
	($VBoxContainer/Buttons/Discard as BaseButton).disabled = true


func _on_discard_pressed() -> void:
	_pending_actions.clear()
	_load_keys_from_map()
	($VBoxContainer/Buttons/Save as BaseButton).disabled = true
	($VBoxContainer/Buttons/Discard as BaseButton).disabled = true


func _on_event_selector_confirmed() -> void:
	var events_container: VBoxContainer = %Actions.get_node(
			_editing_action.to_pascal_case()).get_node(^"Container/Events")
	
	if _action_events[_editing_action].size() == _editing_action_event_idx:
		_action_events[_editing_action].append(_event_candidate)
		_create_action_event(_editing_action, events_container, _event_candidate)
	else:
		_action_events[_editing_action][_editing_action_event_idx] = _event_candidate
		(events_container.get_child(_editing_action_event_idx).get_node(^"Event") as Label).text = \
				_encoded_input_event_as_text(_event_candidate)
	
	if not _editing_action in _pending_actions:
		_pending_actions.append(_editing_action)
	($VBoxContainer/Buttons/Save as BaseButton).disabled = false
	($VBoxContainer/Buttons/Discard as BaseButton).disabled = false


func _on_event_selector_canceled() -> void:
	_editing_action = &""
	_editing_action_event_idx = -1
	_waiting_for_input = false


class EncodedInputEvent:
	var type: Globals.EncodedInputEventType
	var value: int
	var idx: int
