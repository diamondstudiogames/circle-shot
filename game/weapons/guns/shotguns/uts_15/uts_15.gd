extends Shotgun


@export var bullets_in_shot_far: int = 4
@export var projectile_far_scene: PackedScene
@export var spread_far := 12.0
var _far_mode := false
var _default_bullets_in_shot: int
var _default_spread: float
var _default_projectile_scene: PackedScene
@onready var _aim_sprite: Sprite2D = $Visual/Base/Aim


func _initialize() -> void:
	super()
	_default_bullets_in_shot = bullets_in_shot
	_default_spread = spread_base
	_default_projectile_scene = projectile_scene


func additional_button() -> void:
	_far_mode = not _far_mode
	_aim_sprite.visible = _far_mode
	
	bullets_in_shot = bullets_in_shot_far if _far_mode else _default_bullets_in_shot
	spread_base = spread_far if _far_mode else _default_spread
	projectile_scene = projectile_far_scene if _far_mode else _default_projectile_scene


func has_additional_button() -> bool:
	return true
