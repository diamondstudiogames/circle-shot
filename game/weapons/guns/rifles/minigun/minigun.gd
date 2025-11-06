extends Gun


@export var charge_time := 0.8
@export var handle_max_rotation := -30.0
@export var handle_rotation_speed := 37.5

var _charge_timer := 0.0
@onready var _handle: Sprite2D = $Visual/Base/Handle


func _physics_process(delta: float) -> void:
	_shoot_timer -= delta
	if player.player_input.shooting and can_shoot():
		_charge_timer += delta
		_handle.rotation_degrees = move_toward(_handle.rotation_degrees, handle_max_rotation,
				handle_rotation_speed * delta)
	else:
		_charge_timer = clampf(_charge_timer - delta, 0.0, charge_time)
		_handle.rotation_degrees = move_toward(_handle.rotation_degrees, 0,
				handle_rotation_speed * delta)
	
	if multiplayer.is_server() and can_shoot() and player.player_input.shooting \
			and ammo >= ammo_per_shot and _charge_timer >= charge_time and _shoot_timer <= 0.0:
		_update_rotation()
		_update_rotation_position()
		shoot()
	if player.is_local() and can_reload() and ammo < ammo_per_shot:
		player.try_reload_weapon()


func _unmake_current() -> void:
	super()
	_charge_timer = 0.0
