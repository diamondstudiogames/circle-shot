extends Node2D

@export var heal_amount: int = 10
@export_range(0.0, 1.0, 0.01) var heal_restore_ratio := 0.0

func _ready() -> void:
	reset_physics_interpolation()


func _on_interactible_interacted(who: Player) -> void:
	if not multiplayer.is_server():
		return
	if not is_zero_approx(heal_restore_ratio):
		who.heal(ceili(who.max_health * heal_restore_ratio))
	else:
		who.heal(heal_amount)
	queue_free()


func _on_despawn_timer_timeout() -> void:
	($AnimationPlayer as AnimationPlayer).play(&"despawn")
	if multiplayer.is_server():
		await ($AnimationPlayer as AnimationPlayer).animation_finished
		queue_free()
