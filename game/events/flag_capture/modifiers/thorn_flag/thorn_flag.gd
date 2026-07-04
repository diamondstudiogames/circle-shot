extends EventModifier

@export var damage: int = 5
@export var damage_interval := 1.0

func _initialize() -> void:
	if multiplayer.is_server():
		event.get_node(^"Other").child_entered_tree.connect(_on_other_child_entered_tree)


func _start_effect(target: int) -> void:
	if not target in event.players:
		return
	var player: Player = event.players[target]
	player.add_timeless_effect.rpc(Effect.BLEEDING, [damage, -1, damage_interval])


func _stop_effect(target: int) -> void:
	if not target in event.players:
		return
	var player: Player = event.players[target]
	player.remove_timeless_effect.rpc(Effect.BLEEDING)


func _on_other_child_entered_tree(child: Node) -> void:
	var flag := child as Flag
	if not flag:
		return
	flag.picked_up.connect(_start_effect)
	flag.dropped.connect(_stop_effect)
