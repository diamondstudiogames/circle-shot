@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("Autofocus", "Node", load("uid://bhnfvhb1jy21u"),
			EditorInterface.get_editor_theme().get_icon(&"Node", &"EditorIcons"))
	add_custom_type("AutofocusWindow", "Node", load("uid://cexyawmlyqo3w"),
			EditorInterface.get_editor_theme().get_icon(&"Node", &"EditorIcons"))


func _exit_tree() -> void:
	remove_custom_type("Autofocus")
	remove_custom_type("AutofocusWindow")
