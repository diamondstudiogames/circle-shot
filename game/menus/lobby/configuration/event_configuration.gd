extends Window


var _current_listed_event: int = -1

var _parameter_check_button_scene: PackedScene = load("uid://bj8ovestjfmnq")
var _parameter_slider_scene: PackedScene = load("uid://bdp88ihuwkaci")
var _parameter_spin_box_scene: PackedScene = load("uid://dv76erm78qdtx")
var _modifier_scene: PackedScene = load("uid://ccs5qwjfxl3ks")

@onready var _lobby: Lobby = get_parent()


func _list_parameters() -> void:
	for child: Node in %ParametersContainer.get_children():
		%ParametersContainer.remove_child(child)
		child.queue_free()
	for parameter_id: String in Globals.items_db.events[_lobby.selected_event].parameters:
		var parameter: EventParameter = \
				Globals.items_db.events[_lobby.selected_event].parameters[parameter_id]
		var parameter_node: HBoxContainer
		match parameter.type:
			EventParameter.Type.CHECK_BUTTON:
				parameter_node = _parameter_check_button_scene.instantiate()
				var check_button: CheckButton = parameter_node.get_node(^"Value/CheckButton")
				check_button.disabled = not _lobby.is_admin()
				check_button.button_pressed = _lobby.selected_event_parameters[parameter_id] == 1
				check_button.toggled.connect(_on_param_check_button_toggled.bind(parameter_id))
			EventParameter.Type.SLIDER:
				parameter_node = _parameter_slider_scene.instantiate()
				var slider: HSlider = parameter_node.get_node(^"Value/Slider")
				var value_label: Label = parameter_node.get_node(^"Value/Value")
				slider.editable = _lobby.is_admin()
				slider.min_value = parameter.range_min
				slider.max_value = parameter.range_max
				slider.step = parameter.range_step
				slider.value = _lobby.selected_event_parameters[parameter_id]
				value_label.text = parameter.get_parameter_as_string(
						_lobby.selected_event_parameters[parameter_id])
				slider.value_changed.connect(
						_on_param_slider_value_changed.bind(parameter_id, value_label))
			EventParameter.Type.SPIN_BOX:
				parameter_node = _parameter_spin_box_scene.instantiate()
				var spin_box: SpinBox = parameter_node.get_node(^"Value/SpinBox")
				spin_box.editable = _lobby.is_admin()
				spin_box.min_value = parameter.range_min
				spin_box.max_value = parameter.range_max
				spin_box.step = parameter.range_step
				spin_box.prefix = parameter.prefix
				spin_box.suffix = parameter.suffix
				spin_box.value = _lobby.selected_event_parameters[parameter_id]
				spin_box.value_changed.connect(_on_param_spin_box_value_changed.bind(parameter_id))
		parameter_node.name = StringName(parameter_id.to_pascal_case())
		(parameter_node.get_node(^"Info/Name") as Label).text = parameter.name
		(parameter_node.get_node(^"Info/Icon") as TextureRect).texture = load(parameter.icon_path)
		%ParametersContainer.add_child(parameter_node)


func _update_parameters() -> void:
	for parameter_id: String in Globals.items_db.events[_lobby.selected_event].parameters:
		var parameter_node: HBoxContainer = %ParametersContainer.get_node(
				NodePath(parameter_id.to_pascal_case()))
		match Globals.items_db.events[_lobby.selected_event].parameters[parameter_id].type:
			EventParameter.Type.CHECK_BUTTON:
				(parameter_node.get_node(^"Value/CheckButton") as BaseButton).button_pressed = \
						bool(_lobby.selected_event_parameters[parameter_id])
			EventParameter.Type.SLIDER:
				(parameter_node.get_node(^"Value/Slider") as Range).value = \
						_lobby.selected_event_parameters[parameter_id]
			EventParameter.Type.SPIN_BOX:
				(parameter_node.get_node(^"Value/SpinBox") as Range).value = \
						_lobby.selected_event_parameters[parameter_id]


func _update_parameters_read_only_state() -> void:
	for parameter_id: String in Globals.items_db.events[_lobby.selected_event].parameters:
		var parameter_node: HBoxContainer = %ParametersContainer.get_node(
				NodePath(parameter_id.to_pascal_case()))
		match Globals.items_db.events[_lobby.selected_event].parameters[parameter_id].type:
			EventParameter.Type.CHECK_BUTTON:
				(parameter_node.get_node(^"Value/CheckButton") as BaseButton).disabled = \
						not _lobby.is_admin()
			EventParameter.Type.SLIDER:
				(parameter_node.get_node(^"Value/Slider") as Slider).editable = \
						_lobby.is_admin()
			EventParameter.Type.SPIN_BOX:
				(parameter_node.get_node(^"Value/SpinBox") as SpinBox).editable = _lobby.is_admin()


func _list_modifiers() -> void:
	for child: Node in %ModifiersContainer.get_children():
		%ModifiersContainer.remove_child(child)
		child.queue_free()
	for modifier: EventModifierData in \
			Globals.items_db.events[_lobby.selected_event].get_modifiers():
		var modifier_node: PanelContainer = _modifier_scene.instantiate()
		modifier_node.name = "Modifier%d" % modifier.idx_in_db
		(modifier_node.get_node(^"Container/Info/Name") as Label).text = modifier.name
		(modifier_node.get_node(^"Container/Info/Description") as Label).text = \
				modifier.brief_description
		(modifier_node.get_node(^"Container/Icon") as TextureRect).texture = \
				load(modifier.icon_path)
		var check_button: CheckButton = modifier_node.get_node(^"Container/CheckButton")
		check_button.disabled = not _lobby.is_admin()
		check_button.button_pressed = modifier.idx_in_db in _lobby.selected_event_modifiers
		check_button.toggled.connect(_on_modifier_check_button_toggled.bind(modifier.idx_in_db))
		%ModifiersContainer.add_child(modifier_node)


func _update_modifiers() -> void:
	for modifier: EventModifierData in \
			Globals.items_db.events[_lobby.selected_event].get_modifiers():
		var modifier_node: PanelContainer = \
				%ModifiersContainer.get_node("Modifier%d" % modifier.idx_in_db)
		(modifier_node.get_node(^"Container/CheckButton") as BaseButton).button_pressed = \
				modifier.idx_in_db in _lobby.selected_event_modifiers


func _update_modifiers_read_only_state() -> void:
	for modifier: EventModifierData in \
			Globals.items_db.events[_lobby.selected_event].get_modifiers():
		var modifier_node: PanelContainer = \
				%ModifiersContainer.get_node("Modifier%d" % modifier.idx_in_db)
		(modifier_node.get_node(^"Container/CheckButton") as BaseButton).disabled = \
				not _lobby.is_admin()


func _save_and_close() -> void:
	if _lobby.is_admin():
		_lobby.request_set_environment.rpc_id(
				MultiplayerPeer.TARGET_PEER_SERVER, _lobby.selected_event, _lobby.selected_map,
				_lobby.selected_event_parameters, _lobby.selected_event_modifiers)
	hide()


func _on_param_spin_box_value_changed(value: float, parameter_id: String) -> void:
	_lobby.selected_event_parameters[parameter_id] = int(value)


func _on_param_slider_value_changed(value: float, parameter_id: String, value_label: Label) -> void:
	_lobby.selected_event_parameters[parameter_id] = int(value)
	value_label.text = Globals.items_db.events[_lobby.selected_event].parameters[parameter_id] \
			.get_parameter_as_string(int(value))


func _on_param_check_button_toggled(toggled_on: bool, parameter_id: String) -> void:
	_lobby.selected_event_parameters[parameter_id] = int(toggled_on)


func _on_modifier_check_button_toggled(toggled_on: bool, modifier_idx: int) -> void:
	if toggled_on:
		if not modifier_idx in _lobby.selected_event_modifiers:
			_lobby.selected_event_modifiers.append(modifier_idx)
	else:
		_lobby.selected_event_modifiers.erase(modifier_idx)


func _on_change_map_pressed() -> void:
	_save_and_close()
	(%EquipSelector/ItemSelector as Window).title = "Выбор карты"
	(%EquipSelector/ItemSelector as Window).popup_centered()
	(%EquipSelector/%ItemsGrid as ItemsGrid).list_maps_of_event(
			_lobby.selected_event, _lobby.selected_map)


func _on_reset_parameters_pressed() -> void:
	_lobby.selected_event_parameters = \
			Globals.items_db.events[_lobby.selected_event].get_default_parameters()
	_update_parameters()


func _on_admin_changed() -> void:
	($Base/ClientHint as CanvasItem).visible = not _lobby.is_admin()
	($Base/Actions as CanvasItem).visible = _lobby.is_admin()
	_update_parameters_read_only_state()
	_update_modifiers_read_only_state()


func _on_environment_changed() -> void:
	if _lobby.selected_event != _current_listed_event:
		_list_parameters()
		_list_modifiers()
		_current_listed_event = _lobby.selected_event
	else:
		_update_parameters()
		_update_modifiers()
