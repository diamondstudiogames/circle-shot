extends GrenadeProjectile


@export var unmute_duration := 1.0
var _previous_sfx_db: float
var _previous_music_db: float
var _muted := false


func _exit_tree() -> void:
	if _muted:
		unmute()


func _explode() -> void:
	($AnimationPlayer as AnimationPlayer).play(&"explode")
	($AnimationPlayer as AnimationPlayer).advance(0.0) # Мгновенно показываем спрайт взрыва
	var world: World = get_tree().get_first_node_in_group(&"world")
	if ($VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D).is_on_screen():
		if world.local_team != team and is_instance_valid(world.local_player):
			var music_idx: int = AudioServer.get_bus_index(&"Music")
			var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
			_previous_music_db = AudioServer.get_bus_volume_db(music_idx)
			_previous_sfx_db = AudioServer.get_bus_volume_db(sfx_idx)
			AudioServer.set_bus_mute(music_idx, true)
			AudioServer.set_bus_mute(sfx_idx, true)
			($Stun/Sound as AudioStreamPlayer).volume_db = _previous_sfx_db
			_muted = true
			
			# Ждём кадр чтобы запечатлить, где был взрыв флешки
			await get_tree().process_frame
			var screen: Image = get_viewport().get_texture().get_image()
			($Stun/Effect/Texture as TextureRect).texture = ImageTexture.create_from_image(screen)
			($Stun/AnimationPlayer as AnimationPlayer).play(&"stun")
		else:
			($Stun/AnimationPlayer as AnimationPlayer).play(&"friendly_stun")


func unmute() -> void:
	_muted = false
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_mute(music_idx, false)
	AudioServer.set_bus_mute(sfx_idx, false)
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(music_idx, db),
			-60.0, _previous_music_db, unmute_duration)
	tween.parallel()
	tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(sfx_idx, db),
			-60.0, _previous_sfx_db, unmute_duration)
