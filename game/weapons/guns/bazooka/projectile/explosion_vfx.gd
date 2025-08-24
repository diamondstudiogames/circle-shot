extends Node2D

@export var shake_max_amplitude := 32.0
@export var shake_max_duration := 1.0
@export var shake_max_distance := 3200.0

func _ready() -> void:
	var camera: SmartCamera = get_viewport().get_camera_2d()
	var multiplier: float = maxf(
			0.0, (shake_max_distance - global_position.distance_to(camera.global_position))
			/ shake_max_distance
	)
	camera.shake(shake_max_amplitude * multiplier, shake_max_duration * multiplier)
