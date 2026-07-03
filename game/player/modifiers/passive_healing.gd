extends Node


@export_range(0.0, 1.0, 0.01) var heal_amount_per_heal := 0.07

@onready var _idle_timer: Timer = $IdleTimer
@onready var _healing_timer: Timer = $HealingTimer

@onready var _player: Player = get_parent()
@onready var _player_input: PlayerInput = _player.get_node(^"Input") # _ready на player ещё нет


func _ready() -> void:
	if not multiplayer.is_server():
		push_error("This node must exist only on server.")
		queue_free()
		return
	_player.health_changed.connect(_on_player_health_changed)


func _physics_process(_delta: float) -> void:
	if _player_input.shooting or not _player.get_real_velocity().is_zero_approx():
		_reset_timers()


func _reset_timers() -> void:
	_idle_timer.start()
	_healing_timer.stop()


func _on_player_health_changed(old_value: int, new_value: int) -> void:
	if old_value > new_value:
		_reset_timers()


func _on_healing_timer_timeout() -> void:
	_player.heal(roundi(_player.max_health * heal_amount_per_heal))


func _on_idle_timer_timeout() -> void:
	_healing_timer.start()
