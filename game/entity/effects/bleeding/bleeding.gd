extends Effect

const DEFAULT_INTERVAL := 0.8
var _damage: int
var _by: int

func _start_effect() -> void:
	if not multiplayer.is_server():
		return
	_damage = data[0]
	_by = data[1] if data.size() > 1 else -1
	($IntervalTimer as Timer).wait_time = data[2] if data.size() == 3 else DEFAULT_INTERVAL
	($IntervalTimer as Timer).start()


func _on_interval_timer_timeout() -> void:
	entity.damage(_damage, _by)
