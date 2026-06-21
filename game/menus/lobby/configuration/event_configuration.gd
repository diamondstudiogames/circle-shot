extends Window


var _selected_event: int = -1
@onready var _lobby: Lobby = get_parent()


func _save_and_close() -> void:
	# save and send to server
	hide()


func _on_change_map_pressed() -> void:
	_save_and_close()
	(%EquipSelector/ItemSelector as Window).title = "Выбор карты"
	(%EquipSelector/ItemSelector as Window).popup_centered()
	(%EquipSelector/%ItemsGrid as ItemsGrid).list_maps_of_event(
			_lobby.selected_event, _lobby.selected_map)


func _on_admin_changed() -> void:
	($Base/ClientHint as CanvasItem).visible = not _lobby.is_admin()
	($Base/ChangeMap as BaseButton).disabled = not _lobby.is_admin()


func _on_environment_changed() -> void:
	pass # Replace with function body.
