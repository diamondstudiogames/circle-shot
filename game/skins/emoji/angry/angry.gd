extends PlayerSkin

@onready var _anim: AnimationPlayer = $AnimationPlayer

func _initialize() -> void:
	player.health_changed.connect(_on_player_health_changed)


func _on_player_health_changed(old: int, new: int) -> void:
	if old > new:
		_anim.play(&"hurt")
		_anim.seek(0.0)
