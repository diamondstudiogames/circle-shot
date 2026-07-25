extends Area2D


signal flag_captured(by: int)

@export var team := Entity.Team.RED
@export var area_color := Color(1.0, 1.0, 1.0, 0.25)
@export var area_size := 480.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, area_size, area_color)


func _on_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server():
		return
	var flag := area as Flag
	if flag and flag.team != team:
		if is_instance_valid(flag.player):
			flag_captured.emit(flag.player.id)
		else:
			flag_captured.emit(0)
		flag.queue_free()
