extends Node2D


func _ready() -> void:
	await get_tree().process_frame
	($MinimapMarker/Visual as CanvasItem).visible = \
				($MinimapNotifier as VisibleOnScreenNotifier2D).is_on_screen()
