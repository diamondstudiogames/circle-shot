extends Throwable


@export var throw_interval_fast := 0.12
@export var spread_fast := 17.0
@export var projectile_fast_scene: PackedScene
var _fast_mode := false
var _default_spread: float
var _default_throw_interval: float
var _default_projectile_scene: PackedScene


func _initialize() -> void:
	super()
	_default_throw_interval = throw_interval
	_default_spread = spread_base
	_default_projectile_scene = projectile_scene


func _make_current() -> void:
	_anim.play(&"equip_fast" if _fast_mode else &"equip")
	_anim.advance(0.0)
	block_shooting()
	await _anim.animation_finished
	unblock_shooting()


func additional_button() -> void:
	_fast_mode = not _fast_mode
	
	throw_interval = throw_interval_fast if _fast_mode else _default_throw_interval
	spread_base = spread_fast if _fast_mode else _default_spread
	projectile_scene = projectile_fast_scene if _fast_mode else _default_projectile_scene
	
	block_shooting()
	_anim.play(&"switch_to_fast" if _fast_mode else &"switch_to_normal")
	await _anim.animation_finished
	unblock_shooting()


func has_additional_button() -> bool:
	return true
