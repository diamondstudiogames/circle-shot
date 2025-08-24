extends Window


func _ready() -> void:
	get_tree().root.window_input.connect(_on_root_window_input)


func _on_root_window_input(event: InputEvent) -> void:
	if visible:
		return
	var key := event as InputEventKey
	if key and key.keycode == KEY_F3 and key.pressed:
		popup_centered()


func _on_get_pressed() -> void:
	(%Get/Value as Label).text = str(Globals.get_variant(
			Utils.strip_string((%Get/KeyEdit as LineEdit).text), "Значение не найдено"))


func _on_set_pressed() -> void:
	Globals.set_variant(Utils.strip_string((%Set/KeyEdit as LineEdit).text),
			str_to_var(Utils.strip_string((%Set/ValueEdit as LineEdit).text)))


func _on_get_setting_pressed() -> void:
	(%GetSetting/Value as Label).text = str(Globals.get_setting_variant(
			Utils.strip_string((%GetSetting/KeyEdit as LineEdit).text), "Значение не найдено"))


func _on_set_setting_pressed() -> void:
	Globals.set_setting_variant(Utils.strip_string((%SetSetting/KeyEdit as LineEdit).text),
			str_to_var(Utils.strip_string((%SetSetting/ValueEdit as LineEdit).text)))


func _on_get_controls_pressed() -> void:
	(%GetControls/Value as Label).text = str(Globals.get_controls_variant(
			Utils.strip_string((%GetControls/KeyEdit as LineEdit).text), "Значение не найдено"))


func _on_set_controls_pressed() -> void:
	Globals.set_controls_variant(Utils.strip_string((%SetControls/KeyEdit as LineEdit).text),
			str_to_var(Utils.strip_string((%SetControls/ValueEdit as LineEdit).text)))


func _on_receive_loot_pressed() -> void:
	var splits: PackedStringArray = (%ReceiveLoot/LootEdit as LineEdit).text.split(',')
	var loot: Array[String]
	loot.assign(splits)
	Globals.main.receive_loot(loot)


func _on_time_scale_slider_value_changed(value: float) -> void:
	Engine.time_scale = value
	(%TimeScale/Value as Label).text = "x%.1f" % value


func _on_forget_online_offers_pressed() -> void:
	Globals.set_variant("used_online_offers", [] as Array[int])


func _on_forget_promocodes_pressed() -> void:
	Globals.set_variant("used_promocodes", [] as Array[String])


func _on_forget_unlocked_items_pressed() -> void:
	Globals.set_variant("unlocked_weapons", [] as Array[String])
	Globals.set_variant("unlocked_skins", [] as Array[String])
	Globals.set_variant("unlocked_skills", [] as Array[String])


func _on_forget_current_day_pressed() -> void:
	Globals.set_int("last_daily_offers_day", -1)
	Globals.set_int("last_daily_offers_ut", -1)
