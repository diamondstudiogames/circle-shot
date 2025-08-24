extends Projectile

@export var speed_decay_time := 1.0
var base_speed: float

func _ready() -> void:
	base_speed = speed
	var tween: Tween = create_tween()
	tween.tween_property($Sprite2D as Node2D, ^":scale", Vector2.ONE, 0.3).from(Vector2.ONE * 0.5)
	tween.parallel().tween_interval(($Timer as Timer).wait_time - 0.3)
	tween.tween_callback(func() -> void: ($ShapeDetector as ShapeCast2D).enabled = false)
	tween.tween_property($Sprite2D as CanvasItem, ^":modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property($Sprite2D as Node2D, ^":scale", Vector2.ONE * 0.5, 0.3)
	tween.custom_step(0.01)
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if speed > 0.0:
		speed -= base_speed * delta / speed_decay_time
