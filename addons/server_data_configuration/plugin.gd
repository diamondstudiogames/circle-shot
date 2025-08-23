@tool
extends EditorPlugin

var _main_screen: Control

func _enter_tree() -> void:
	_main_screen = (load("uid://dnjgmcyoyd44a") as PackedScene).instantiate()
	EditorInterface.get_editor_main_screen().add_child(_main_screen)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_main_screen):
		_main_screen.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_main_screen):
		_main_screen.visible = visible


func _get_plugin_name() -> String:
	return "Сервер"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"GDScript", &"EditorIcons")
