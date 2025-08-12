extends Effect

var should_be_partially_visible := false

func _start_effect() -> void:
	var world: World = get_tree().get_first_node_in_group(&"world")
	if world:
		should_be_partially_visible = world.local_team == entity.team
	
	($Smoke as CPUParticles2D).restart()
	var tween: Tween = create_tween()
	if should_be_partially_visible:
		tween.tween_property(entity.visual, ^":modulate", Color(1.0, 1.0, 1.0, 0.5), 0.5)
	else:
		tween.tween_property(entity, ^":modulate", Color.TRANSPARENT, 0.5)


func _end_effect() -> void:
	var tween: Tween = entity.create_tween()
	if should_be_partially_visible:
		tween.tween_property(entity.visual, ^":modulate", Color.WHITE, 0.3)
	else:
		tween.tween_property(entity, ^":modulate", Color.WHITE, 0.3)
