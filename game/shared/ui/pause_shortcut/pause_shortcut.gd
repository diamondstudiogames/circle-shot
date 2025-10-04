extends Shortcut

@export var controller_event: InputEvent
@export var keyboard_and_mouse_event: InputEvent

func _setup_local_to_scene() -> void:
	match Globals.get_current_input_method():
		Globals.InputMethod.KEYBOARD_AND_MOUSE:
			events = [keyboard_and_mouse_event]
		Globals.InputMethod.CONTROLLER:
			events = [controller_event]
		Globals.InputMethod.TOUCH:
			events = []
