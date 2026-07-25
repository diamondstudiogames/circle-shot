extends Node2D

@export var team := Entity.Team.ENVIRONMENT

func _ready() -> void:
	await get_tree().process_frame # Ждём пока заработает VisibleOnScreenNotifier2D
	var world: World = get_tree().get_first_node_in_group(&"world")
	_update_minimap_marker(world.local_team)
	world.local_team_set.connect(_update_minimap_marker)


func _update_minimap_marker(local_team: Entity.Team) -> void:
	if team == local_team:
		$VisibleOnScreenNotifier2D.set_block_signals(true)
		($Visual as CanvasItem).show()
	else:
		$VisibleOnScreenNotifier2D.set_block_signals(false)
		($Visual as CanvasItem).visible = \
				($VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D).is_on_screen()
