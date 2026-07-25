@tool
extends PickableEquipItem


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if (get_tree().get_first_node_in_group(&"world") as World).local_team != Entity.Team.RED:
		($ScreenMarker as CanvasItem).hide()
		$ScreenMarker.queue_free()
