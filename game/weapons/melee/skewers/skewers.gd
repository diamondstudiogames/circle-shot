extends Melee


@export var damage_second: int
@export var damage_both: int

var _current_combo: int = 0
@onready var _pivot: Node2D = $Visual/Pivot
@onready var _pivot2: Node2D = $Visual/Pivot2
@onready var _sparks_pivot: Node2D = $Visual/SparksPivot
@onready var _timer: Timer = $Timer
@onready var _shape_detector: ShapeDetector = $Attack/ShapeDetector
@onready var _attack_polygon: Polygon2D = $AttackPolygon


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_pivot.rotation = rotation
		_pivot2.rotation = rotation
		_sparks_pivot.rotation = rotation
		_shape_detector.rotation = rotation
		_aim.rotation = rotation
		_attack_polygon.rotation = rotation
		set_notify_local_transform(false)
		rotation = 0.0
		set_notify_local_transform(true)


func _physics_process(delta: float) -> void:
	_shoot_timer -= delta
	if multiplayer.is_server() and can_shoot() \
			and player.player_input.shooting and _shoot_timer <= 0.0:
		shoot(player.entity_input.aim_direction, _current_combo)


func _exit_tree() -> void:
	_timer.queue_free()


func _initialize() -> void:
	set_notify_local_transform(true)
	_timer.name += name
	_timer.reparent(player)


func _shoot(direction := Vector2.RIGHT, combo: int = 0) -> void:
	_shoot_timer = shoot_interval
	match combo:
		0:
			_anim.play(&"attack")
			_attack.damage = damage
		1:
			_anim.play(&"attack_second")
			_attack.damage = damage_second
		2:
			_anim.play(&"attack_both")
			_attack.damage = damage_both
	_anim.seek(0.0)
	block_shooting()
	player.block_turning()
	player.visual.scale.x = -1.0 if direction.x < 0.0 else 1.0
	rotation = _calculate_aim_angle(direction)
	
	if multiplayer.is_server():
		_attack.damage_multiplier = player.damage_multiplier
		_attack.team = player.team
		_attack.who = player.id
		_attack.clear_exceptions()
		_current_combo = (_current_combo + 1) % 3
		_timer.start()
	
	await _anim.animation_finished
	unblock_shooting()
	player.unblock_turning()


func _on_timer_timeout() -> void:
	_current_combo = 0
