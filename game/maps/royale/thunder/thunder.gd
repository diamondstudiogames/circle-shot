extends Map

@export var lightning_bolt_scene: PackedScene

func _initialize() -> void:
	if world and multiplayer.is_server():
		($LightningBoltTimer as Timer).start()


@rpc("reliable", "authority", "call_local", 3)
func _summon_ligtning_bolt(where: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	var lightning: Attack = lightning_bolt_scene.instantiate()
	lightning.position = where
	lightning.name += str(randi())
	world.other_parent.add_child(lightning, true)


func _on_lightning_bolt_timer_timeout() -> void:
	var game_zone: Rect2 = world.get_game_zone()
	_summon_ligtning_bolt.rpc(game_zone.get_center()
			+ game_zone.size * Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)))
