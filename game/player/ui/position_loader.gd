extends Node


@export var id: String

var _default_anchor_left: float
var _default_anchor_right: float
var _default_anchor_top: float
var _default_anchor_bottom: float

var _default_offset_left: float
var _default_offset_right: float
var _default_offset_top: float
var _default_offset_bottom: float


func _enter_tree() -> void:
	var parent: Control = get_parent()
	
	_default_anchor_left = parent.anchor_left
	_default_anchor_right = parent.anchor_right
	_default_anchor_top = parent.anchor_top
	_default_anchor_bottom = parent.anchor_bottom
	
	_default_offset_left = parent.offset_left
	_default_offset_right = parent.offset_right
	_default_offset_top = parent.offset_top
	_default_offset_bottom = parent.offset_bottom
	
	Globals.controls_settings_applied.connect(_ready)


func _ready() -> void:
	var parent: Control = get_parent()
	
	if Globals.get_current_input_method() != Globals.InputMethod.TOUCH:
		parent.anchor_left = _default_anchor_left
		parent.anchor_right = _default_anchor_right
		parent.anchor_top = _default_anchor_top
		parent.anchor_bottom = _default_anchor_bottom
		
		parent.offset_left = _default_offset_left
		parent.offset_right = _default_offset_right
		parent.offset_top = _default_offset_top
		parent.offset_bottom = _default_offset_bottom
		return
	
	var anchors_preset: Control.LayoutPreset = \
			Globals.get_controls_int("anchors_preset_%s" % id) as Control.LayoutPreset
	parent.set_anchors_preset(anchors_preset)
	
	parent.set_begin(Globals.get_controls_vector2("offsets_lt_%s" % id))
	parent.set_end(Globals.get_controls_vector2("offsets_rb_%s" % id))
