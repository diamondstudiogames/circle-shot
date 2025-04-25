extends Effect

@export var shake_amplitude := 8.0
@export var shake_speed := 0.3
var _shake_tween: Tween

func _start_effect() -> void:
	entity.make_immobile()
	entity.make_disarmed()
	entity.block_turning()
	_shake_tween = create_tween()
	_shake_tween.set_loops()
	_shake_tween.tween_property(entity.visual, ^":position:x", shake_amplitude, shake_speed)
	_shake_tween.tween_property(entity.visual, ^":position:x", -shake_amplitude, shake_speed)


func _end_effect() -> void:
	_shake_tween.kill()
	var tween: Tween = entity.create_tween()
	tween.tween_property(entity.visual, ^":position:x", 0.0, shake_speed)
	entity.unmake_immobile()
	entity.unmake_disarmed()
	entity.unblock_turning()
