extends Node2D


@export var gravity := 160.0
@export var despawn_time := 1.0
@export var max_velocity := Vector2(320.0, 80.0)
var _velocity: Vector2


func _ready() -> void:
	_velocity = Vector2(
			randf_range(-max_velocity.x, max_velocity.x),
			randf_range(-max_velocity.y, max_velocity.y)
	)
	var tween: Tween = create_tween()
	tween.tween_interval(despawn_time / 2)
	tween.tween_property(self, ^":modulate", Color.TRANSPARENT, despawn_time / 2)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_velocity.y += gravity * delta
	position += _velocity * delta
