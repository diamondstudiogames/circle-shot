class_name GrenadeProjectile
extends AnimatableBody2D

## Узел снаряда гранаты.

## Вызывается в момент взрыва гранаты.
signal exploded

## Скорость снаряда гранаты.
@export var speed := 800.0
## Замедление снаряда гранаты.
@export var damping := 200.0
## Направление снаряда.
var direction: Vector2
## Команда игрока, бросившего гранату.
var team: int

var _current_speed: float
var _exploded := false
@onready var _anim: AnimationPlayer = $Grenade/AnimationPlayer


func _ready() -> void:
	reset_physics_interpolation()
	_current_speed = speed
	($Grenade/AnimationPlayer as AnimationPlayer).play(
			&"rotation" if direction.x > 0.0 else &"inverted_rotation")
	($Grenade as CanvasItem).set_instance_shader_parameter(&"outline_color",
			Entity.TEAM_COLORS[team])


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	
	_current_speed -= damping * delta
	if _current_speed < 0.0:
		_current_speed = 0.0
	_anim.speed_scale = _current_speed / speed
	
	var collision: KinematicCollision2D = move_and_collide(_current_speed * direction * delta)
	if collision:
		direction = direction.bounce(collision.get_normal())


## Выполняет [method Node.queue_free] только когда вызван на сервере.
func safe_free() -> void:
	if multiplayer.is_server():
		queue_free()


## Вызывается при истечении таймера взрыва.
func _explode() -> void:
	pass


func _on_explosion_timer_timeout() -> void:
	_exploded = true
	exploded.emit()
	_explode()
