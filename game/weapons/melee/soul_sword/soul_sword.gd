extends Melee


@export var ranged_attack_projectile_scene: PackedScene
@export var damage_in_ranged_mode: int
var _ranged_mode := false
var _damage_normal: int
@onready var _shoot_point: Marker2D = $ShootPoint


func _initialize() -> void:
	_damage_normal = damage
	($Visual/Base/Ranged as CanvasItem).hide()


func additional_button() -> void:
	_ranged_mode = not _ranged_mode
	($Visual/Base/Ranged as CanvasItem).visible = _ranged_mode
	($Visual/Base/Normal as CanvasItem).visible = not _ranged_mode
	damage = damage_in_ranged_mode if _ranged_mode else _damage_normal
	_attack.damage = damage
	player.ammo_text_updated.emit(get_ammo_text())


func has_additional_button() -> bool:
	return true


func get_ammo_text() -> String:
	return "Дальних атак: %d" % ammo_in_stock if _ranged_mode else super()


func _fire_ranged_attack() -> void:
	if not _ranged_mode or ammo_in_stock <= 0:
		return
	ammo_in_stock -= 1
	if not multiplayer.is_server():
		return
	var projectile: Projectile = ranged_attack_projectile_scene.instantiate()
	projectile.position = _shoot_point.global_position
	projectile.damage_multiplier = player.damage_multiplier
	projectile.rotation = rotation if player.visual.scale.x > 0.0 else PI - rotation
	projectile.team = player.team
	projectile.who = player.id
	projectile.name += str(randi())
	_projectiles_parent.add_child(projectile, true)
