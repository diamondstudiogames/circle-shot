extends PlayerSkin


var _heal_sfx: AudioStream = preload("uid://bjevk1ku6ayn4")
var _hurt_sfx: AudioStream = preload("uid://1n8dth4b0keb")
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _sfx: AudioStreamPlayer2D = $Sfx


func _initialize() -> void:
	player.health_changed.connect(_on_player_health_changed)


func _on_player_health_changed(old: int, new: int) -> void:
	if new < old:
		if _anim.current_animation != "Hurt":
			_anim.play(&"Hurt")
		if not _sfx.playing or _sfx.stream != _hurt_sfx:
			_sfx.stream = _hurt_sfx
			_sfx.play()
	elif new > old:
		if _anim.current_animation != "Heal":
			_anim.play(&"Heal")
		if not _sfx.playing or _sfx.stream != _heal_sfx:
			_sfx.stream = _heal_sfx
			_sfx.play()
