class_name SmartCamera
extends Camera2D

## Умная камера.
##
## Предоставляет удобные методы для следования за целью, панорамированию и прочего.

## Издаётся, когда встряхивание камеры окончено.
signal shake_finished
## Издаётся, когда панорамирование камеры окончено.
signal pan_finished
## Издаётся, когда цель камеры меняется.
signal target_changed(new_target: Node2D)

## Цель, за которой следует камера.
var target: Node2D:
	set(value):
		if is_instance_valid(_pan_tween):
			_pan_tween.finished.emit()
			_pan_tween.kill()
		if is_instance_valid(value) and value.is_physics_interpolated_and_enabled():
			_physics_interpolation_previous_position = value.global_position
		target = value
		target_changed.emit(target)

var _shake_tween: Tween
var _pan_tween: Tween
var _physics_interpolation_previous_position: Vector2


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		if target.is_physics_interpolated_and_enabled():
			global_position = _physics_interpolation_previous_position.lerp(target.global_position,
					Engine.get_physics_interpolation_fraction())
		else:
			global_position = target.global_position


func _physics_process(_delta: float) -> void:
	if is_instance_valid(target) and target.is_physics_interpolated_and_enabled():
		_physics_interpolation_previous_position = target.global_position


## Панорамирует камеру из текущей позиции (если не указан [param from]) в позицию [param to]
## в течении [param duration] секунд.
## Если [param keep_target] равен [code]true[/code], текущая цель будет установлена вновь
## после окончания панорамирования.
## Можно указать [param trans_type] и [param ease_type] для более тонкой настройки.
func pan(to: Vector2, duration: float, keep_target := false, ease_type := Tween.EASE_OUT,
		trans_type := Tween.TRANS_QUAD, from: Vector2 = global_position) -> void:
	_cleanup_pan_tween()
	
	var prev_target: Node2D = target
	target = null
	
	_pan_tween = create_tween()
	_pan_tween.set_trans(trans_type).set_ease(ease_type)
	_pan_tween.tween_property(self, ^":global_position", to, duration).from(from)
	await _pan_tween.finished
	
	if keep_target and is_instance_valid(prev_target):
		target = prev_target
	pan_finished.emit()


## Панорамирует камеру из текущей позиции (если не указан [param from]) в позицию цели
## [param to] в течении [param duration] секунд. После чего задаёт [member target] на [param to].
## Можно указать [param trans_type] и [param ease_type] для более тонкой настройки.
func pan_to_target(to: Node2D, duration: float, ease_type := Tween.EASE_OUT,
		trans_type := Tween.TRANS_QUAD, from: Vector2 = global_position) -> void:
	_cleanup_pan_tween()
	
	target = null
	to.tree_exiting.connect(_cleanup_pan_tween)
	_pan_tween = create_tween()
	_pan_tween.set_trans(trans_type).set_ease(ease_type)
	_pan_tween.tween_method(_lerp_to.bind(from, to), 0.0, 1.0, duration)
	await _pan_tween.finished
	pan_finished.emit()
	if is_instance_valid(to):
		to.tree_exiting.disconnect(_cleanup_pan_tween)
		target = to


## Встряхивает камеру в течении [param duration] секунд с амплитудой колебаний [param amplitude].
## Если [param should_decay] равен [code]true[/code], то колебания затихают. Можно указать шаг
## колебаний в [param shake_step].
func shake(amplitude: float, duration: float, should_decay := true, shake_step := 0.05) -> void:
	if is_instance_valid(_shake_tween):
		_shake_tween.finished.emit()
		_shake_tween.kill()
	
	_shake_tween = create_tween()
	var steps := int(duration / shake_step)
	for i: int in steps:
		var random_vector := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var current_amplitude: float = amplitude / steps * (steps - i)
		if not should_decay:
			current_amplitude = amplitude
		_shake_tween.tween_property(self, ^":offset",
				random_vector.normalized() * current_amplitude, shake_step)
	_shake_tween.tween_property(self, ^":offset", Vector2.ZERO, shake_step)
	await _shake_tween.finished
	shake_finished.emit()


## Мгновенно телепортирует камеру в [param destination] без каких либо сглаживаний.
func teleport_to(destination: Vector2) -> void:
	if is_instance_valid(_pan_tween):
		_pan_tween.finished.emit()
		_pan_tween.kill()
	
	_physics_interpolation_previous_position = destination
	global_position = destination
	position_smoothing_enabled = false # FIXME
	reset_smoothing()
	position_smoothing_enabled = true


func _lerp_to(weight: float, from: Vector2, to: Node2D) -> void:
	global_position = from.lerp(to.global_position, weight)


func _cleanup_pan_tween() -> void:
	if is_instance_valid(_pan_tween):
		_pan_tween.finished.emit()
		_pan_tween.kill()
