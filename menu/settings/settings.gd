extends Control


enum RendereringMethod {
	GL_COMPATIBILITY = 0,
	MOBILE = 1,
}
const AIM_VISUAL_MAX_SIZE := 360.0

@export_multiline var help_messages: Array[String]

var _override_file := ConfigFile.new()
var _should_apply_controls_settings := false
var _save_import_path: String

@onready var _aim_visual: ColorRect = %AimVisual


func _ready() -> void:
	show_section("General")
	
	_override_file.load("user://engine_settings.cfg")
	var preffered_renderering_method: RendereringMethod
	if _override_file.get_value("rendering", "renderer/rendering_method") == "mobile":
		preffered_renderering_method = RendereringMethod.MOBILE
	else:
		preffered_renderering_method = RendereringMethod.GL_COMPATIBILITY
	(%RendererOptions as OptionButton).selected = preffered_renderering_method
	
	var driver: String = RenderingServer.get_current_rendering_driver_name().capitalize()
	var method: String = RenderingServer.get_current_rendering_method().capitalize()
	if method == "Mobile":
		method = "Forward Mobile"
	method = method.replace("Gl", "GL")
	method = method.replace(" Plus", "+")
	driver = driver.replace("gl", "GL")
	driver = driver.replace("Es", "ES")
	driver = driver.replace("Angle", "ANGLE")
	driver = driver.replace("D 3D", "Direct3D")
	(%CurrentRenderer as Label).text = "Текущий метод отрисовки: %s (%s)" % [method, driver]
	
	# Основное
	(%UpdatesCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("check_updates"))
	_on_updates_check_toggled((%UpdatesCheck as BaseButton).button_pressed)
	(%BetasCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("check_betas"))
	(%PatchesCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("check_patches"))
	# Сеть
	(%BroadcastCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("broadcast"))
	(%RejectPlayersCheck as BaseButton).set_pressed_no_signal(
			Globals.get_setting_bool("reject_players"))
	(%UPNPCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("upnp"))
	_on_upnp_check_toggled((%UPNPCheck as BaseButton).button_pressed)
	# Игра
	(%ChatInGameCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("chat_in_game"))
	(%ShowMinimapCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("minimap"))
	(%ShowDebugCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("debug_info"))
	(%DodgeOptions as OptionButton).selected = int(Globals.get_setting_bool("aim_dodge"))
	(%VibrationCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("vibration"))
	(%AdvicesCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("advices"))
	# Графика
	(%LowGraphicsCheck as BaseButton).set_pressed_no_signal(
			Globals.get_setting_bool("low_graphics"))
	(%FullscreenCheck as BaseButton).set_pressed_no_signal(Globals.get_setting_bool("fullscreen"))
	(%FPSSlider as Range).value = Globals.get_setting_int("max_fps")
	# Звук
	(%MasterVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("master_volume"))
	(%MusicVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("music_volume"))
	(%SFXVolumeSlider as Range).set_value_no_signal(Globals.get_setting_float("sfx_volume"))
	(%CustomTracksCheck as BaseButton).set_pressed_no_signal(
			Globals.get_setting_bool("custom_tracks"))
	_on_custom_tracks_check_toggled((%CustomTracksCheck as BaseButton).button_pressed, false)
	(%OfficialTracksCheck as BaseButton).set_pressed_no_signal(
			Globals.get_setting_bool("official_tracks"))
	if Globals.get_setting_bool("menu_tracks"):
		if Globals.get_setting_bool("separate_menu_tracks"):
			(%MenuTracksOptions as OptionButton).selected = 2
		else:
			(%MenuTracksOptions as OptionButton).selected = 1
	else:
		(%MenuTracksOptions as OptionButton).selected = 0
	# Управление
	(%InputOptions as OptionButton).selected = Globals.get_controls_int("input_method")
	_toggle_input_method_settings_visibility(Globals.get_controls_int("input_method"))
	(%FollowMouseCheck as BaseButton).set_pressed_no_signal(
			Globals.get_controls_bool("follow_mouse"))
	(%FireModeOptions as OptionButton).selected = int(Globals.get_controls_bool("joystick_fire"))
	(%SneakSlider as Range).value = Globals.get_controls_float("sneak_multiplier")
	(%AimDZoneSlider as Range).value = Globals.get_controls_float("aim_deadzone")
	(%AimZoneSlider as Range).set_value_no_signal(Globals.get_controls_float("aim_zone"))
	(%AlwaysAimCheck as BaseButton).set_pressed_no_signal(
			Globals.get_controls_bool("always_show_aim"))
	(%JoysticksAlphaSlider as Range).value = Globals.get_controls_float("joysticks_alpha")
	(%DeadzoneSlider as Range).value = Globals.get_controls_float("deadzone")
	
	_update_aim_visual_size()
	get_window().size_changed.connect(_update_aim_visual_size)
	_update_connected_joypads()
	
	# Инфа о сохранении
	(%SaveInfo/Name as Label).text = Globals.get_string("player_name")
	(%SaveInfo/SaveId as Label).text = "ID сохранения: %s" % Globals.get_string("save_id")
	_show_played_time()
	(Globals.get_node(^"PlayedTimeTimer") as Timer).timeout.connect(_show_played_time)
	
	# UPnP
	var upnp_status := "Отключён"
	if Globals.upnp:
		match Globals.upnp.status:
			UPNPManager.Status.INACTIVE:
				upnp_status = "Неактивен"
			_:
				upnp_status = "Активен"
	(%UPNPStatus as Label).text = upnp_status
	
	# Кастомные треки
	(%CustomTracksPath as Label).text = "Путь к папке с треками: %s" % Globals.main.music_path
	if not Globals.main.custom_tracks.is_empty():
		for node: Node in %LoadedTracks.get_children():
			node.queue_free()
		
		for track: String in Globals.main.custom_tracks:
			var label := Label.new()
			label.text = track
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			%LoadedTracks.add_child(label)
	
	(%MenuTracks as CanvasItem).visible = Globals.get_setting_bool("separate_menu_tracks")
	(%MenuTracksPath as Label).text = "Путь к папке с треками для меню: %s" \
			% Globals.main.menu_music_path
	if not Globals.main.custom_menu_tracks.is_empty():
		for node: Node in %LoadedMenuTracks.get_children():
			node.queue_free()
		
		for track: String in Globals.main.custom_menu_tracks:
			var label := Label.new()
			label.text = track
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			%LoadedMenuTracks.add_child(label)
	
	# Скрытие настроек
	if not OS.has_feature("pc"):
		(%FullscreenCheck.get_parent().get_parent() as CanvasItem).hide()
	if not OS.has_feature("mobile") and Input.get_connected_joypads().is_empty():
		(%VibrationCheck.get_parent().get_parent() as CanvasItem).hide()
	if OS.has_feature("editor"):
		(%PatchesCheck.get_parent().get_parent() as CanvasItem).hide()
		(%ClearPatches.get_parent() as CanvasItem).hide()
	if "--disable-update-check" in OS.get_cmdline_user_args():
		(%UpdatesCheck.get_parent().get_parent() as CanvasItem).hide()
		(%BetasCheck.get_parent().get_parent() as CanvasItem).hide()


func _unhandled_input(event: InputEvent) -> void:
	if Globals.get_controls_int("input_method") == Globals.InputMethod.KEYBOARD_AND_MOUSE \
			and event.is_action(&"fullscreen") and event.is_pressed():
		(%FullscreenCheck as BaseButton).set_pressed_no_signal(
				Globals.get_setting_bool("fullscreen"))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when visible:
			_on_quit_pressed()
		NOTIFICATION_EXIT_TREE when _should_apply_controls_settings:
			Globals.apply_controls_settings()


func show_section(section_name: String) -> void:
	for section: CanvasItem in %Sections.get_children():
		section.hide()
	
	(%Sections.get_node(section_name) as CanvasItem).show()


func show_help(help_idx: int) -> void:
	($HelpDialog as AcceptDialog).dialog_text = help_messages[help_idx]
	# Устанавливает минимальную высоту
	($HelpDialog as Window).popup_centered(Vector2i(($HelpDialog as Window).size.x, 0))


func remove_recursive(path: String) -> void:
	var dir_access := DirAccess.open(path)
	if dir_access:
		for file: String in dir_access.get_files():
			dir_access.remove(file)
		for dir: String in dir_access.get_directories():
			remove_recursive(dir_access.get_current_dir().path_join(dir))
		
		dir_access.remove(dir_access.get_current_dir())


func _toggle_input_method_settings_visibility(method: Globals.InputMethod) -> void:
	(%KeyboardSettings as CanvasItem).hide()
	(%TouchSettings as CanvasItem).hide()
	(%ControllerSettings as CanvasItem).hide()
	match method:
		Globals.InputMethod.KEYBOARD_AND_MOUSE:
			(%KeyboardSettings as CanvasItem).show()
		Globals.InputMethod.TOUCH:
			(%TouchSettings as CanvasItem).show()
		Globals.InputMethod.CONTROLLER:
			(%ControllerSettings as CanvasItem).show()


func _update_aim_visual_size() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x >= viewport_size.y:
		_aim_visual.custom_minimum_size.x = AIM_VISUAL_MAX_SIZE
		_aim_visual.custom_minimum_size.y = 1.0 / viewport_size.aspect() * AIM_VISUAL_MAX_SIZE
	else:
		_aim_visual.custom_minimum_size.y = AIM_VISUAL_MAX_SIZE
		_aim_visual.custom_minimum_size.x = viewport_size.aspect() * AIM_VISUAL_MAX_SIZE


func _show_played_time() -> void:
	var played_time: String
	var secs: int = Globals.get_int("played_time")
	var mins: int = 0
	var hours: int = 0
	if secs < 60:
		played_time = "%02d:%02d" % [mins, secs]
	elif secs < 60 * 60:
		mins = floori(secs / 60.0)
		secs -= mins * 60
		played_time = "%02d:%02d" % [mins, secs]
	else:
		hours = floori(secs / 60.0 / 60.0)
		secs -= hours * 60 * 60
		mins = floori(secs / 60.0)
		secs -= mins * 60
		played_time = "%d:%02d:%02d" % [hours, mins, secs]
	
	(%SaveInfo/PlayedTime as Label).text = "Проведено времени в игре: %s" % played_time


func _update_connected_joypads() -> void:
	var text: String
	var connected_joypads: Array[int] = Input.get_connected_joypads()
	if connected_joypads.is_empty():
		text = "Нет подключённых контроллеров"
	else:
		text = "Подключённые контроллеры:\n"
		for device: int in connected_joypads:
			text += Input.get_joy_name(device)
			text += '\n'
		if connected_joypads.size() > 1:
			text += "Подключено больше одного контроллера.\nИспользован будет первый из них."
	(%ConnectedJoypads as Label).text = text


func _on_request_permissions_result(permission: String, granted: bool, lambda: Callable) -> void:
	print_verbose("Permission %s granted: %s." % [permission, str(granted)])
	lambda.call_deferred(granted)


func _on_quit_pressed() -> void:
	if is_instance_valid(Globals.main.menu):
		Globals.main.menu.check_updates()
	queue_free()


#region Основное
func _on_updates_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("check_updates", toggled_on)
	(%BetasCheck.get_parent().get_parent() as CanvasItem).visible = toggled_on


func _on_betas_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("check_betas", toggled_on)


func _on_patches_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("check_patches", toggled_on)


func _on_clear_patches_pressed() -> void:
	remove_recursive("user://patches")
	Globals.set_variant("patches", {} as Dictionary[String, int])
	Globals.quit(true)


func _on_restart_game_pressed() -> void:
	Globals.quit(true)


func _on_copy_save_id_pressed() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(Globals.get_string("save_id"))


func _on_change_name_pressed() -> void:
	($ManageSaveDialog/Dialogs/NameDialog as Window).title = \
			"Смена имени (текущее: %s)" % Globals.get_string("player_name")
	($ManageSaveDialog/Dialogs/NameDialog as Window).popup_centered()


func _on_name_dialog_name_accepted() -> void:
	(%SaveInfo/Name as Label).text = Globals.get_string("player_name")


func _on_reset_controls_dialog_confirmed() -> void:
	Globals.save_file.erase_section(Globals.CONTROLS_SAVE_FILE_SECTION)
	Globals.setup_controls_settings()
	Globals.apply_controls_settings()
	
	name = &"OldSettings"
	queue_free()
	Globals.main.open_screen(load("uid://c2leb2h0qjtmo") as PackedScene)


func _on_reset_settings_dialog_confirmed() -> void:
	Globals.save_file.erase_section(Globals.SETTINGS_SAVE_FILE_SECTION)
	Globals.save_file.erase_section(Globals.CONTROLS_SAVE_FILE_SECTION)
	DirAccess.remove_absolute("user://engine_settings.cfg")
	Globals.setup_settings()
	Globals.apply_settings()
	Globals.setup_controls_settings()
	Globals.apply_controls_settings()
	
	name = &"OldSettings"
	queue_free()
	Globals.main.open_screen(load("uid://c2leb2h0qjtmo") as PackedScene)


func _on_reset_data_dialog_confirmed() -> void:
	remove_recursive("user://")
	Globals.quit(true)


func _on_export_pressed() -> void:
	if OS.has_feature("android") and int(OS.get_version().get_slice('.', 0)) < 29:
		var perms: PackedStringArray = OS.get_granted_permissions()
		if not "android.permission.READ_EXTERNAL_STORAGE" in perms \
				and not "android.permission.WRITE_EXTERNAL_STORAGE" in perms:
			var lambda: Callable = func(value: bool) -> void:
				if value: _on_export_pressed()
			get_tree().on_request_permissions_result.connect(
					_on_request_permissions_result.bind(lambda), CONNECT_ONE_SHOT)
			OS.request_permissions()
			return
	
	($ManageSaveDialog/Dialogs/ExportFileDialog as FileDialog).current_path = OS.get_system_dir(
			OS.SYSTEM_DIR_DOCUMENTS).path_join(Globals.get_string("player_name") + ".cssf")
	($ManageSaveDialog/Dialogs/ExportFileDialog as Window).popup_centered()


func _on_export_file_dialog_file_selected(path: String) -> void:
	var err: Error = Globals.export_save(path)
	var info_dialog: AcceptDialog = $ManageSaveDialog/Dialogs/InfoDialog
	if err != OK:
		info_dialog.dialog_text = "При экспортировании в файл\n%s\nвозникла ошибка: %s." % [
			path,
			error_string(err),
		]
		info_dialog.title = "Ошибка экспортирования сохранения"
	else:
		info_dialog.dialog_text = "Сохранение успешно экспортировано в файл\n%s." % path
		info_dialog.title = "Экспортирование сохранения"
	info_dialog.popup_centered.call_deferred(Vector2i.ONE) # сбрасываем до минимального размера


func _on_import_pressed() -> void:
	if OS.has_feature("android"):
		if int(OS.get_version().get_slice('.', 0)) < 29:
			var perms: PackedStringArray = OS.get_granted_permissions()
			if not "android.permission.READ_EXTERNAL_STORAGE" in perms \
					and not "android.permission.WRITE_EXTERNAL_STORAGE" in perms:
				var lambda: Callable = func(value: bool) -> void:
					if value: _on_import_pressed()
				get_tree().on_request_permissions_result.connect(
						_on_request_permissions_result.bind(lambda), CONNECT_ONE_SHOT)
				OS.request_permissions()
				return
		else:
			DirAccess.make_dir_recursive_absolute(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
					.get_base_dir().path_join("Android").path_join("media")
					.path_join(Globals.PACKAGE_NAME))
			DirAccess.make_dir_recursive_absolute(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
					.get_base_dir().path_join("Android").path_join("data")
					.path_join(Globals.PACKAGE_NAME))
			
			var android_info_dialog: ConfirmationDialog = \
					$ManageSaveDialog/Dialogs/AndroidInfoDialog
			android_info_dialog.dialog_text = "\
На Android, начиная с 10 версии, ты не сможешь импортировать сохранение,
экспортированное до переустановки приложения или скачанное извне,
если оно не находится в следующих папках:\n"
			android_info_dialog.dialog_text += "Память устройства/Android/media/%s\n" \
					% Globals.PACKAGE_NAME
			android_info_dialog.dialog_text += "Память устройства/Android/data/%s\n" \
					% Globals.PACKAGE_NAME
			android_info_dialog.dialog_text += \
					"Перемести нужное сохранение туда и лишь потом импортируй."
			android_info_dialog.popup_centered()
			return
	
	($ManageSaveDialog/Dialogs/ImportFileDialog as FileDialog).current_dir = OS.get_system_dir(
			OS.SYSTEM_DIR_DOCUMENTS)
	($ManageSaveDialog/Dialogs/ImportFileDialog as Window).popup_centered()


func _on_android_info_dialog_confirmed() -> void:
	($ManageSaveDialog/Dialogs/ImportFileDialog as FileDialog).current_dir = (
			OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).get_base_dir().path_join("Android")
			.path_join("media").path_join(Globals.PACKAGE_NAME)
	)
	($ManageSaveDialog/Dialogs/ImportFileDialog as Window).popup_centered()


func _on_import_file_dialog_file_selected(path: String) -> void:
	_save_import_path = path
	var import_confirm_dialog: ConfirmationDialog = $ManageSaveDialog/Dialogs/ImportConfirmDialog
	import_confirm_dialog.title = "Импортирование сохранения"
	import_confirm_dialog.dialog_text = "Ты действительно хочешь импортировать сохранение \
из следующего файла?"
	import_confirm_dialog.dialog_text += "\n%s\n" % _save_import_path
	import_confirm_dialog.dialog_text += "ВНИМАНИЕ: текущее сохранение будет утрачено безвозвратно!"
	import_confirm_dialog.dialog_text += "\nПосле импортирования игра будет перезапущена."
	# сбрасываем до минимального размера
	import_confirm_dialog.popup_centered.call_deferred(Vector2i.ONE) 


func _on_import_confirm_dialog_confirmed() -> void:
	var err: Error = Globals.import_save(_save_import_path)
	if err != OK:
		var info_dialog: AcceptDialog = $ManageSaveDialog/Dialogs/InfoDialog
		info_dialog.dialog_text = "При импортировании из файла\n%s\nвозникла ошибка: %s." % [
			_save_import_path,
			error_string(err),
		]
		info_dialog.title = "Ошибка импортирования сохранения"
		info_dialog.popup_centered(Vector2i.ONE) # сбрасываем до минимального размера
#endregion


#region Сеть
func _on_broadcast_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("broadcast", toggled_on)


func _on_reject_players_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("reject_players", toggled_on)


func _on_upnp_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("upnp", toggled_on)
	(%UPNPStatus.get_parent() as CanvasItem).visible = toggled_on
#endregion


#region Игра
func _on_show_minimap_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("minimap", toggled_on)


func _on_chat_in_game_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("chat_in_game", toggled_on)


func _on_show_debug_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("debug_info", toggled_on)


func _on_dodge_options_item_selected(index: int) -> void:
	Globals.set_setting_bool("aim_dodge", bool(index))


func _on_vibration_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("vibration", toggled_on)


func _on_advices_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("advices", toggled_on)
#endregion


#region Графика
func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("fullscreen", toggled_on)
	Globals.apply_settings()


func _on_fps_slider_value_changed(value: float) -> void:
	Globals.set_setting_int("max_fps", int(value))
	if value > 125.0:
		(%FPSValue as Label).text = "Нет"
	else:
		(%FPSValue as Label).text = "%d" % value
	Globals.apply_settings()


func _on_low_graphics_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("low_graphics", toggled_on)
	Globals.apply_settings()


func _on_renderer_options_item_selected(index: int) -> void:
	var new_renderer: String = \
			"gl_compatibility" if index == RendereringMethod.GL_COMPATIBILITY else "mobile"
	_override_file.set_value("rendering", "renderer/rendering_method", new_renderer)
	_override_file.set_value("rendering", "renderer/rendering_method.mobile", new_renderer)
	_override_file.save("user://engine_settings.cfg")
#endregion


#region Звук
func _on_master_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("master_volume", value)
	Globals.apply_settings()


func _on_music_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("music_volume", value)
	Globals.apply_settings()


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Globals.set_setting_float("sfx_volume", value)
	Globals.apply_settings()


func _on_custom_tracks_check_toggled(toggled_on: bool, update_menu_music := true) -> void:
	if toggled_on and OS.has_feature("android"):
		var perms: PackedStringArray = OS.get_granted_permissions()
		if not (
				"android.permission.READ_MEDIA_AUDIO" in perms
				or "android.permission.READ_EXTERNAL_STORAGE" in perms
				or "android.permission.WRITE_EXTERNAL_STORAGE" in perms
		):
			(%CustomTracksCheck as BaseButton).set_pressed_no_signal(false)
			var lambda: Callable = func(value: bool) -> void:
				(%CustomTracksCheck as BaseButton).button_pressed = value
			get_tree().on_request_permissions_result.connect(
					_on_request_permissions_result.bind(lambda), CONNECT_ONE_SHOT)
			OS.request_permissions()
			toggled_on = false
	(%CustomTracksSettings as CanvasItem).visible = toggled_on
	Globals.set_setting_bool("custom_tracks", toggled_on)
	if Globals.get_setting_bool("menu_tracks") and update_menu_music:
		Globals.main.update_menu_music()
	Globals.apply_settings()


func _on_official_tracks_check_toggled(toggled_on: bool) -> void:
	Globals.set_setting_bool("official_tracks", toggled_on)
	if Globals.get_setting_bool("menu_tracks"):
		Globals.main.update_menu_music()


func _on_menu_tracks_options_item_selected(index: int) -> void:
	Globals.set_setting_bool("menu_tracks", index > 0)
	Globals.set_setting_bool("separate_menu_tracks", index > 1)
	(%MenuTracks as CanvasItem).visible = index > 1
	Globals.apply_settings()
	Globals.main.update_menu_music()
#endregion


#region Управление
func _on_configure_controls_pressed() -> void:
	Globals.main.open_screen(load("uid://5wx4yqp027gq") as PackedScene)


func _on_configure_actions_pressed() -> void:
	if $ActionsConfiguration is InstancePlaceholder:
		($ActionsConfiguration as InstancePlaceholder).create_instance(true)
	($ActionsConfiguration as Window).popup_centered()


func _on_input_options_item_selected(index: int) -> void:
	Globals.set_controls_int("input_method", index)
	Globals.apply_controls_settings()
	_toggle_input_method_settings_visibility(index)


func _on_follow_mouse_check_toggled(toggled_on: bool) -> void:
	Globals.set_controls_bool("follow_mouse", toggled_on)


func _on_fire_mode_options_item_selected(index: int) -> void:
	Globals.set_controls_bool("joystick_fire", bool(index))


func _on_sneak_slider_value_changed(value: float) -> void:
	Globals.set_controls_float("sneak_multiplier", value)
	(%SneakValue as Label).text = "x%.2f" % value


func _on_aim_d_zone_slider_value_changed(value: float) -> void:
	Globals.set_controls_float("aim_deadzone", value)
	(%AimZoneSlider as Range).min_value = maxf(value + 0.1, 0.25)
	_aim_visual.queue_redraw()


func _on_aim_zone_slider_value_changed(value: float) -> void:
	Globals.set_controls_float("aim_zone", value)
	_aim_visual.queue_redraw()


func _on_always_aim_check_toggled(toggled_on: bool) -> void:
	Globals.set_controls_bool("always_show_aim", toggled_on)


func _on_joysticks_alpha_slider_value_changed(value: float) -> void:
	Globals.set_controls_float("joysticks_alpha", value)
	(%AlphaValue as Label).text = "%d%%" % roundi(value * 100)


func _on_deadzone_slider_value_changed(value: float) -> void:
	Globals.set_controls_float("deadzone", value)
	(%DeadzoneValue as Label).text = "%.2f" % value
	_should_apply_controls_settings = true


func _on_aim_visual_draw() -> void:
	var min_side: float = minf(_aim_visual.size.x, _aim_visual.size.y) / 2
	_aim_visual.draw_circle(_aim_visual.size / 2,
			min_side * Globals.get_controls_float("aim_zone"), Color.GREEN, true, -1.0, true)
	_aim_visual.draw_circle(_aim_visual.size / 2,
			min_side * Globals.get_controls_float("aim_deadzone"), Color.RED, true, -1.0, true)
	
	_aim_visual.draw_line(Vector2(_aim_visual.size.x / 2, 0.0),
			Vector2(_aim_visual.size.x / 2, _aim_visual.size.y), Color.BLACK)
	_aim_visual.draw_line(Vector2(0.0, _aim_visual.size.y / 2),
			Vector2(_aim_visual.size.x, _aim_visual.size.y / 2), Color.BLACK)
#endregion
