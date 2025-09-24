extends Node2D


func _ready() -> void:
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	($MinimapMarker/Visual as CanvasItem).visible = is_visible_in_tree()
