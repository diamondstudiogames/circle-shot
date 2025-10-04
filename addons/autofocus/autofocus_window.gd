extends Node
# Focuses specified Control on parent window shown. Also hides window on ui_cancel.

@export_node_path("Control") var focus_target: NodePath
@onready var _control: Control = get_node_or_null(focus_target)
@onready var _window: Window = get_parent()

func _ready() -> void:
	_window.window_input.connect(_on_window_input)
	if not _control:
		return
	_control.visibility_changed.connect(_on_control_visibility_changed)
	await get_tree().process_frame
	if _control.visible:
		_control.grab_focus.call_deferred()


func _on_control_visibility_changed() -> void:
	if _control.visible:
		_control.grab_focus()


func _on_window_input(event: InputEvent) -> void:
	print(event.as_text())
	if _window.visible and _window.has_focus() \
			and event.is_action(&"ui_cancel") and event.is_pressed():
		_window.hide()
