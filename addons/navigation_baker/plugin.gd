@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("NavigationBaker", "Node2D", load("uid://88uadq3srjl6"),
			EditorInterface.get_editor_theme().get_icon(&"Node2D", &"EditorIcons"))


func _exit_tree() -> void:
	remove_custom_type("NavigationBaker")
