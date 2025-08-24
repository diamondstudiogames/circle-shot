extends Node

@export var id: String

func _ready() -> void:
	if Globals.get_current_input_method() != Globals.InputMethod.TOUCH:
		return
	
	var parent: Control = get_parent()
	
	var anchors_preset: Control.LayoutPreset = \
			Globals.get_controls_int("anchors_preset_%s" % id) as Control.LayoutPreset
	parent.set_anchors_preset(anchors_preset)
	
	parent.set_begin(Globals.get_controls_vector2("offsets_lt_%s" % id))
	parent.set_end(Globals.get_controls_vector2("offsets_rb_%s" % id))
