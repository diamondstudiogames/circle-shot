extends Shortcut


func _init() -> void:
	_setup_shortcut()
	Globals.input_method_changed.connect(_setup_shortcut)


func _setup_shortcut() -> void:
	match Globals.get_current_input_method():
		Globals.InputMethod.KEYBOARD_AND_MOUSE:
			var event := InputEventAction.new()
			event.action = &"pause"
			event.pressed = true
			events = [event]
		Globals.InputMethod.CONTROLLER:
			var event := InputEventAction.new()
			event.action = &"c_pause"
			event.pressed = true
			events = [event]
		Globals.InputMethod.TOUCH:
			events = []
