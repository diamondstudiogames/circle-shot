extends EventModifier

@export var flags_attacks_scenes: Array[PackedScene]

func _initialize() -> void:
	event.get_node(^"Other").child_entered_tree.connect(_on_other_child_entered_tree)


func _on_other_child_entered_tree(child: Node) -> void:
	var flag := child as Flag
	if not flag:
		return
	var flag_attack: Attack = flags_attacks_scenes[flag.team].instantiate()
	flag.add_child(flag_attack, true)
