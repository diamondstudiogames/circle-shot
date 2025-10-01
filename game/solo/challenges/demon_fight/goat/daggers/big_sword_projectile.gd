extends Projectile

var target: Entity
var _rotating := true

func _process(_delta: float) -> void:
	if _rotating and is_instance_valid(target):
		look_at(target.global_position)


func _stop_rotating() -> void:
	_rotating = false
	direction = Vector2.from_angle(rotation)
