extends Node
# Focuses Control parent on show.

@onready var _control: Control = get_parent()

func _ready() -> void:
	_control.visibility_changed.connect(_on_control_visibility_changed)
	await get_tree().process_frame
	if _control.is_visible_in_tree():
		_control.grab_focus.call_deferred()


func _on_control_visibility_changed() -> void:
	if _control.is_visible_in_tree():
		_control.grab_focus()
