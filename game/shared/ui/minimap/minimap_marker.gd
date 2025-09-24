extends Node2D


func _ready() -> void:
	await get_tree().process_frame
	($Visual as CanvasItem).visible = \
				($VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D).is_on_screen()
