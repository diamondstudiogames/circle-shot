extends Window


func _ready() -> void:
	(%MasterVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("master_volume"))
	(%MusicVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("music_volume"))
	(%SFXVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("sfx_volume"))
	(%FullscreenCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("fullscreen"))
	(%ShowDebugCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("debug_info"))
	(%InputOptions as OptionButton).selected = Globals.get_controls_int("input_method")
	_toggle_input_method_visibility(Globals.get_controls_int("input_method"))
	_update_input_methods()
	Globals.input_method_changed.connect(_update_input_methods)
	
	if OS.has_feature("pc"):
		(%FullscreenCheck.get_parent().get_parent() as CanvasItem).show()


func _toggle_input_method_visibility(input_method: Globals.InputMethod) -> void:
	(%InputMethodAuto as CanvasItem).visible = input_method == Globals.InputMethod.AUTO
	_update_input_methods()


func _update_input_methods() -> void:
	(%InputMethodAuto as Label).text = "Определённый тип управления: %s" \
			% (%InputOptions as OptionButton).get_item_text(Globals.get_current_input_method())


func _on_master_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("master_volume", value)
	Globals.apply_settings()


func _on_music_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("music_volume", value)
	Globals.apply_settings()


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("sfx_volume", value)
	Globals.apply_settings()


func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("fullscreen", toggled_on)
	Globals.apply_settings()


func _on_show_debug_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("debug_info", toggled_on)
	Globals.apply_settings()


func _on_input_options_item_selected(index: int) -> void:
	Globals.set_controls_int("input_method", index)
	Globals.update_current_input_method(false) # сами обновим настройки
	Globals.apply_controls_settings()
	_toggle_input_method_visibility(index)
