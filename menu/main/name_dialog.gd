extends Window


signal name_accepted
@export var easter_eggs: Dictionary[String, String]
@onready var _label: Label = $MarginContainer/VBoxContainer/Label


func _on_confirm_pressed() -> void:
	var result: Array[bool]
	var player_name: String = Utils.validate_player_name((%LineEdit as LineEdit).text, 0, result)
	(%LineEdit as LineEdit).clear()
	if not result[0]:
		(%LineEdit as LineEdit).placeholder_text = "Недопустимое имя!"
		return
	Globals.set_string("player_name", player_name)
	hide()
	name_accepted.emit()
	print_verbose("Name set: %s." % player_name)


func _on_line_edit_text_changed(new_text: String) -> void:
	new_text = new_text.to_lower()
	if new_text.is_valid_ip_address() and new_text != ":":
		_label.text = "Что я тебе сделал?("
	elif new_text == "i'm blue":
		_label.add_theme_color_override(&"font_color", Color.BLUE)
		_label.text = "Дабуди-дабудай"
	elif new_text in ["dead circle", "666", "die"]:
		_label.text = "DIEEEEEEEEE"
		($CanvasModulate as CanvasItem).show()
	elif new_text in ["блять", "сука"] or "хуй" in new_text or "пизд" in new_text \
			or "пидор" in new_text or "хуё" in new_text or "пидр" in new_text or "хуе" in new_text \
			or new_text.begins_with("еб") or new_text.begins_with("ёб"):
		_label.text = "Нехорошо материться!"
	elif new_text == "разраб клоун":
		(%LineEdit as LineEdit).text = "Сам такой!"
		($AnimationPlayer as AnimationPlayer).play(&"RESET")
	elif new_text.begins_with("разраб"):
		($AnimationPlayer as AnimationPlayer).play(&"developer")
	elif new_text in easter_eggs:
		_label.text = easter_eggs[new_text]
	else:
		_label.text = ""
		_label.remove_theme_color_override(&"font_color")
		($AnimationPlayer as AnimationPlayer).play(&"RESET")
		($CanvasModulate as CanvasItem).hide()


func _on_about_to_popup() -> void:
	if not DisplayServer.has_hardware_keyboard():
		set_indexed.call_deferred(^"position:y", 80)
	(%LineEdit as Control).grab_focus.call_deferred()
