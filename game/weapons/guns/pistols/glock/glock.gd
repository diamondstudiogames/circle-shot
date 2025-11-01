extends Gun

@export var shots_in_burst: int = 3
@onready var _burst_shots_interval_timer: Timer = $BurstShotsIntervalTimer

func shoot(..._args: Array) -> void:
	for i: int in shots_in_burst:
		if ammo <= 0 or not can_shoot():
			return
		super()
		_burst_shots_interval_timer.start()
		await _burst_shots_interval_timer.timeout
