extends Node2D

@export var item_id: String

func _ready() -> void:
	if Globals.get_bool("quest_item_%s_collected" % item_id):
		queue_free()


func _on_interactible_interacted(_who: Player) -> void:
	Globals.set_bool("quest_item_%s_collected" % item_id, true)
	queue_free()
