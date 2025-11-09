extends Melee


@export var projectile_scene: PackedScene
var _lunge_attack := false
@onready var _bullets_points_swing: Node2D = $Visual/BulletsSpawnPointsSwing
@onready var _bullets_points_lunge: Node2D = $Visual/BulletsSpawnPointsLunge
@onready var _aim_swing: Line2D = $Aim
@onready var _aim_lunge: Line2D = $AimLunge


func _shoot_bullets() -> void:
	if ammo_in_stock <= 0:
		return
	ammo_in_stock -= 1
	var points: Node2D = _bullets_points_lunge if _lunge_attack else _bullets_points_swing
	for point: Node2D in points.get_children():
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.position = point.global_position
		projectile.damage_multiplier = player.damage_multiplier
		projectile.rotation = point.global_rotation
		projectile.team = player.team
		projectile.who = player.id
		projectile.name += str(randi())
		_projectiles_parent.add_child(projectile, true)


func additional_button() -> void:
	_lunge_attack = not _lunge_attack
	_aim.hide()
	if _lunge_attack:
		_aim = _aim_lunge
		_anim.get_animation_library(&"").rename_animation(&"attack", &"attack_swing")
		_anim.get_animation_library(&"").rename_animation(&"attack_lunge", &"attack")
	else:
		_aim = _aim_swing
		_anim.get_animation_library(&"").rename_animation(&"attack", &"attack_lunge")
		_anim.get_animation_library(&"").rename_animation(&"attack_swing", &"attack")


func has_additional_button() -> bool:
	return true


func get_ammo_text() -> String:
	return "Атак с пулями: %d" % ammo_in_stock
