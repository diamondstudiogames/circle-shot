@tool
extends Attack

@export var shake_max_amplitude := 32.0
@export var shake_max_duration := 1.0
@export var shake_max_distance := 3200.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 400.0, Color.WHITE)


func safe_free() -> void:
	if multiplayer.is_server():
		queue_free()


func shake() -> void:
	var camera: SmartCamera = get_viewport().get_camera_2d()
	var multiplier: float = maxf(
			0.0, (shake_max_distance - global_position.distance_to(camera.global_position))
			/ shake_max_distance
	)
	camera.shake(shake_max_amplitude * multiplier, shake_max_duration * multiplier)
