extends Gun


const BLUR_SPREAD_MULTIPLIER := 0.2

@export var aim_slowdown := 0.8
@export var no_aim_spread := 8.0
@export var aim_camera_time := 0.7
@export var unaim_camera_time := 0.4

var _aiming := false
var _owns_camera := false

@onready var _aim_ray: RayCast2D = $ShootPoint/AimRay
@onready var _aim_target: Marker2D = $ShootPoint/AimTarget
@onready var _aim_point: Sprite2D = $AimPoint
@onready var _end_aim: Marker2D = $ShootPoint/EndAim
@onready var _aim_texture_material: ShaderMaterial = ($Aim/Base/Aim as CanvasItem).material


func _process(delta: float) -> void:
	super(delta)
	if _aiming:
		_aim_ray.force_raycast_update()
		_aim_point.visible = _aim_ray.is_colliding()
		_aim_point.global_position = _aim_ray.get_collision_point()
		if player.is_local():
			_aim_target.global_position = _calculate_aim_target_position()
			_aim_texture_material.set_shader_parameter(&"radius",
					_calculate_spread() * BLUR_SPREAD_MULTIPLIER)
		if not player.can_use_weapon():
			end_aim()


func _exit_tree() -> void:
	if _aiming:
		end_aim()


func _initialize() -> void:
	super()
	($ShootPoint as CanvasItem).hide()
	($AimPoint as CanvasItem).hide()


func _unmake_current() -> void:
	super()
	if _aiming:
		end_aim()


func reload() -> void:
	if _aiming:
		end_aim()
	super()


func has_additional_button() -> bool:
	return true


func additional_button() -> void:
	if _aiming:
		end_aim()
	else:
		start_aim()


func _calculate_spread() -> float:
	if _aiming:
		return super()
	return super() + no_aim_spread


func start_aim() -> void:
	_aiming = true
	player.speed_multiplier *= aim_slowdown
	($AimPoint as CanvasItem).show()
	if not player.is_local():
		return
	
	($Aim as CanvasLayer).show()
	($ShootPoint as CanvasItem).show()
	
	var camera: SmartCamera = get_viewport().get_camera_2d()
	camera.pan_to_target(_aim_target, aim_camera_time)
	camera.position_smoothing_enabled = false
	camera.global_position = _calculate_aim_target_position()
	camera.target_changed.connect(_on_camera_target_changed.bind(camera))
	_owns_camera = true


func end_aim() -> void:
	_aiming = false
	player.speed_multiplier /= aim_slowdown
	($AimPoint as CanvasItem).hide()
	if not player.is_local():
		return
	
	($Aim as CanvasLayer).hide()
	($ShootPoint as CanvasItem).hide()
	
	var camera: SmartCamera = get_viewport().get_camera_2d()
	if not is_instance_valid(camera):
		return
	
	if _owns_camera:
		camera.position_smoothing_enabled = true
		camera.pan_to_target(player.camera_target, unaim_camera_time)


func _calculate_aim_target_position() -> Vector2:
	var ratio: float = (_aim_ray.get_collision_point() - _aim_ray.global_position).length() \
			/ absf(_aim_ray.position.x - _end_aim.position.x) if _aim_ray.is_colliding() else 1.0
	return _aim_ray.global_position.lerp(_end_aim.global_position,
			minf(player.entity_input.aim_direction.length(), ratio))


func _on_camera_target_changed(new_target: Node2D, camera: SmartCamera) -> void:
	if _aim_target == new_target:
		return
	camera.position_smoothing_enabled = true
	camera.target_changed.disconnect(_on_camera_target_changed)
	_owns_camera = false
