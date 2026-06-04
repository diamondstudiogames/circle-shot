extends PlayerSkin

var _additional_rotation := 0.0

func _initialize() -> void:
	var tween: Tween = create_tween()
	tween.set_loops(0)
	tween.tween_interval(randf_range(0.6, 1.1))
	tween.tween_property(self, ^":_additional_rotation", 16.0, 0.15)
	tween.tween_interval(randf_range(0.5, 1.0))
	tween.tween_property(self, ^":_additional_rotation", -20.0, 0.2)
	tween.tween_interval(randf_range(0.7, 1.2))
	tween.tween_property(self, ^":_additional_rotation", -4.0, 0.15)


func _process(_delta: float) -> void:
	if not player.can_turn():
		return
	var aim_direction: Vector2 = player.entity_input.aim_direction
	aim_direction.x = absf(aim_direction.x)
	rotation = aim_direction.angle() + deg_to_rad(_additional_rotation)
