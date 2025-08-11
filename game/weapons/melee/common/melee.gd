class_name Melee
extends Weapon

## Узел оружия класса "Ближнее".

## Урон, наносимый этим оружием.
@export var damage: int
## Интервал между ударами.
@export var shoot_interval := 1.0
## Время, за которое оружие поворачивается в направление прицела.
@export var to_aim_time := 0.15
var _shoot_timer: float = 0.0
var _turn_tween: Tween
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _aim: Node2D = $Aim
@onready var _attack: Attack = $Attack


func _process(_delta: float) -> void:
	_aim.hide()
	if can_shoot():
		_aim.visible = player.player_input.showing_aim
		rotation = _calculate_aim_angle()


func _physics_process(delta: float) -> void:
	_shoot_timer -= delta
	if multiplayer.is_server() and can_shoot() \
			and player.player_input.shooting and _shoot_timer <= 0.0:
		shoot(player.entity_input.aim_direction)


func _shoot(direction := Vector2.RIGHT) -> void:
	_shoot_timer = shoot_interval
	_anim.play(&"attack")
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
	
	await _anim.animation_finished
	unblock_shooting()
	player.unblock_turning()


func _make_current() -> void:
	_attack.damage = damage
	
	block_shooting()
	_anim.play(&"equip")
	_anim.advance(0.0)
	
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"equip":
		unblock_shooting()
		return
	
	_anim.play(&"post_equip")
	_turn_tween = create_tween()
	_turn_tween.tween_method(_lerp_to_aim, 0.0, 1.0, to_aim_time)
	
	await _turn_tween.finished
	unblock_shooting()


func _unmake_current() -> void:
	if is_instance_valid(_turn_tween):
		_turn_tween.finished.emit()
		_turn_tween.kill()
	
	rotation = 0.0
	_anim.play(&"RESET")
	_anim.advance(0.01)


func _player_disarmed() -> void:
	if _anim.is_playing() and _anim.current_animation != &"equip": # нет смысла пропускать
		_anim.play(&"RESET")


func _can_reload() -> bool:
	return false


func get_ammo_text() -> String:
	return "Не ограничено"
