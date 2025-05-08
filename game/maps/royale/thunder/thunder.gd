extends Map

var _lightning_bolt_scene: PackedScene = preload("uid://dm2xehxg7nb8e")

func _initialize() -> void:
	if multiplayer.is_server():
		($LightningBoltTimer as Timer).start()


@rpc("reliable", "authority", "call_local", 3)
func _summon_ligtning_bolt(where: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	var lightning: Attack = _lightning_bolt_scene.instantiate()
	lightning.position = where
	add_child(lightning)


func _on_lightning_bolt_timer_timeout() -> void:
	# Зона где нет дыма
	var game_zone: float = maxf(($"../PoisonSmokes/Right" as Node2D).position.x - 240.0, 0.0)
	_summon_ligtning_bolt.rpc(
			Vector2(randf_range(-game_zone, game_zone), randf_range(-game_zone, game_zone)))
