extends GrenadeProjectile


@export var shake_max_amplitude := 32.0
@export var shake_max_duration := 1.0
@export var shake_max_distance := 3200.0
@onready var _explosion_timer: Timer = $ExplosionTimer


func _ready() -> void:
	super()
	var tween: Tween = create_tween()
	tween.tween_property($Grenade/Flame as Node2D, ^":position", Vector2(0.0, -42.0), 1.5)
	($Explosion as Node2D).rotation = randf_range(-PI, PI)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	
	_current_speed -= damping * delta
	if _current_speed < 0.0:
		_current_speed = 0.0
		_explosion_timer.stop()
		_explosion_timer.timeout.emit()
		return
	_anim.speed_scale = _current_speed / speed
	
	var collision: KinematicCollision2D = move_and_collide(_current_speed * direction * delta)
	if collision:
		_explosion_timer.stop()
		_explosion_timer.timeout.emit()


func _explode() -> void:
	($Explosion/AnimationPlayer as AnimationPlayer).play(&"explode")
	var camera: SmartCamera = get_viewport().get_camera_2d()
	var multiplier: float = maxf(
			0.0, (shake_max_distance - global_position.distance_to(camera.global_position)) 
			/ shake_max_distance
	)
	camera.shake(shake_max_amplitude * multiplier, shake_max_duration * multiplier)


func _on_extinguish_area_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"anti_fire"):
		($Explosion/AnimationPlayer as AnimationPlayer).seek(7.45)
