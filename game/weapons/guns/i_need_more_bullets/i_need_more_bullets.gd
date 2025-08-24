extends Gun


@export var single_shoot_interval := 0.5
@export var single_ammo_per_shot: int = 1
@export var single_projectile_scene: PackedScene

var _in_single_mode := false

@onready var _default_shoot_interval: float = shoot_interval
@onready var _default_ammo_per_shot: int = ammo_per_shot
@onready var _default_projectile_scene: PackedScene = projectile_scene

@onready var _shooting_timer: Timer = $ShootingTimer
@onready var _shooting_sfx: AudioStreamPlayer2D = $ShootingSfx
@onready var _switch_sfx: AudioStreamPlayer2D = $SwitchSfx
@onready var _switch_single_sfx: AudioStreamPlayer2D = $SwitchSingleSfx
@onready var _aim_device: Sprite2D = $Visual/Base/Aim


func _shoot() -> void:
	super()
	if _in_single_mode:
		_anim.play(&"single_shot")
	else:
		if not _shooting_sfx.playing:
			_shooting_sfx.play()
		_shooting_timer.start(shoot_interval + 0.08)


func additional_button() -> void:
	_in_single_mode = not _in_single_mode
	_aim_device.visible = _in_single_mode
	shoot_on_joystick_release = _in_single_mode
	if not (_switch_sfx.playing or _switch_single_sfx.playing):
		_switch_sfx.playing = not _in_single_mode
		_switch_single_sfx.playing = _in_single_mode
	
	if _in_single_mode:
		shoot_interval = single_shoot_interval
		projectile_scene = single_projectile_scene
		ammo_per_shot = single_ammo_per_shot
		if not _shooting_timer.is_stopped():
			_shooting_timer.stop()
			_shooting_sfx.stop()
	else:
		shoot_interval = _default_shoot_interval
		projectile_scene = _default_projectile_scene
		ammo_per_shot = _default_ammo_per_shot


func has_additional_button() -> bool:
	return true
