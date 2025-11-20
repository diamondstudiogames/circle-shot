extends Node2D


@export var explosion_time: int = 30
@export var max_countdown_interval := 1.0
@export var min_countdown_interval := 0.1

var _time_remained: int
var _tween: Tween

@onready var _bomb_defusal: BombDefusal = get_tree().get_first_node_in_group(&"world")
@onready var _countdown_timer: Timer = $CountdownTimer
@onready var _countdown_sfx: AudioStreamPlayer2D = $CountdownSfx
@onready var _light: Sprite2D = $Light


func _ready() -> void:
	_bomb_defusal.round_ended.connect(_on_round_ended)
	_time_remained = explosion_time
	_countdown_timer.start(max_countdown_interval)
	if multiplayer.is_server():
		_bomb_defusal.bomb_set_time(_time_remained)


@rpc("call_local", "authority", "reliable", 3)
func _explode() -> void:
	($Explosion as CanvasItem).show()
	($Sprite2D as CanvasItem).hide()
	($Explosion/Sfx as AudioStreamPlayer2D).play()
	($Explosion/Particles as CPUParticles2D).restart()


func _on_round_ended() -> void:
	($ExplosionTimer as Timer).stop()
	_countdown_timer.stop()
	$Interactible.process_mode = Node.PROCESS_MODE_DISABLED


func _on_explosion_timer_timeout() -> void:
	_time_remained -= 1
	if multiplayer.is_server():
		_bomb_defusal.bomb_set_time(_time_remained)
		if _time_remained <= 0:
			_explode.rpc()
			_bomb_defusal.bomb_explode()


func _on_interactible_interacted(who: Player) -> void:
	if multiplayer.is_server():
		_bomb_defusal.bomb_defuse(who.id)


func _on_countdown_timer_timeout() -> void:
	_countdown_sfx.play()
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_light, ^":scale", Vector2.ZERO, 0.3).from(Vector2.ONE * 0.2)
	_countdown_timer.start(lerpf(min_countdown_interval, max_countdown_interval,
			float(_time_remained) / explosion_time))
