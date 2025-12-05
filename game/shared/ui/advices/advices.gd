extends PanelContainer

@export_multiline var advices: Array[String]
var current_idx: int = 0

func _ready() -> void:
	if not Globals.get_setting_bool("advices"):
		queue_free()
		return
	
	advices.shuffle()
	update_advice()


func update_advice() -> void:
	($SwitchTimer as Timer).start()
	(%Advice as Label).text = advices[current_idx]


func _on_next_pressed() -> void:
	current_idx = (current_idx + 1) % advices.size()
	update_advice()


func _on_previous_pressed() -> void:
	current_idx = (advices.size() + current_idx - 1) % advices.size()
	update_advice()


func _on_switch_timer_timeout() -> void:
	current_idx = (current_idx + 1) % advices.size()
	update_advice()
