extends Map

@export var background_color: Color
var _previous_color: Color

func _initialize() -> void:
	_previous_color = RenderingServer.get_default_clear_color()
	if Globals.get_setting_bool("low_graphics"):
		($TileMapLayers/Floor as CanvasItem).material = null
		($TileMapLayers/Walls as CanvasItem).material = null
		RenderingServer.set_default_clear_color(background_color)


func _exit_tree() -> void:
	if RenderingServer.get_default_clear_color() != _previous_color:
		RenderingServer.set_default_clear_color(_previous_color)
