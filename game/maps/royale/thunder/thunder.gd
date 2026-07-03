extends Map

var _lightning_bolt_scene: PackedScene = load("uid://dm2xehxg7nb8e")

func _initialize() -> void:
	if world is Event and multiplayer.is_server():
		($LightningBoltTimer as Timer).start()


@rpc("reliable", "authority", "call_local", 3)
func _summon_ligtning_bolt(where: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	var lightning: Attack = _lightning_bolt_scene.instantiate()
	lightning.position = where
	lightning.name += str(randi())
	get_tree().get_first_node_in_group(&"other_parent").add_child(lightning, true)


func _on_lightning_bolt_timer_timeout() -> void:
	if not is_instance_valid(world):
		return
	var game_zone: Rect2 = world.get_game_zone()
	_summon_ligtning_bolt.rpc(game_zone.get_center()
			+ game_zone.size * Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)))
