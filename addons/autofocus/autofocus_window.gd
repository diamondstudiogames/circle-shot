extends Node

# Focuses specified Control on parent window shown. Also hides window on ui_cancel.

@export_node_path("Control") var focus_target: NodePath
var _queued_show := false
@onready var _control: Control = get_node_or_null(focus_target)
@onready var _window: Window = get_parent()


func _ready() -> void:
	_window.window_input.connect(_on_window_input)
	if not _control:
		return
	_control.visibility_changed.connect(_on_control_visibility_changed)
	_window.visibility_changed.connect(_on_window_visibility_changed)
	await get_tree().process_frame
	if _control.visible:
		if _window.visible:
			_control.grab_focus.call_deferred()
		else:
			_queued_show = true


func _on_control_visibility_changed() -> void:
	if _control.visible:
		if _window.visible:
			_control.grab_focus()
		else:
			_queued_show = true


func _on_window_visibility_changed() -> void:
	if _window.visible and _queued_show:
		_control.grab_focus()


func _on_window_input(event: InputEvent) -> void:
	if _window.visible and _window.has_focus() \
			and event.is_action(&"ui_cancel") and event.is_pressed():
		_window.close_requested.emit()
