extends Node

## Глобальный класс игры.
##
## Этот класс содержит в себе то, что используется по всей игре. Также отвечает за сохранения.

## Путь к файлу сохранения.
const SAVE_FILE_PATH := "user://save.cfg"
## Пароль файла сохранения.
const SAVE_FILE_PASSWORD := "circle-shot"
## Стандартная секция файла сохранения.
const DEFAULT_SAVE_FILE_SECTION := "save"
## Секция файла сохранения для настроек.
const SETTINGS_SAVE_FILE_SECTION := "settings"
## Секция файла сохранения для настроек управления (в частности переназначения клавиш).
const CONTROLS_SAVE_FILE_SECTION := "controls"
## Ссылка на [Main]. Сокращение от [code]get_tree().current_scene as Main[/code].
var main: Main
## Версия игры. Извлекается из [ProjectSettings].
var version: String = ProjectSettings.get_setting("application/config/version")
## Находится ли игра в "безголовом режиме". Если да, то сервер создаётся без игрока.
## Если этот режим будет включён на запуске, то игра автоматически создаст сервер.
var headless := false
## База данных всех предметов. Смотри [ItemsDB].
var items_db: ItemsDB
## Файл сохранения. Предпочитайте методы [code]get_*/set_*[/code] для его модификации.
var save_file: ConfigFile
## Файл с данными, которые загружаются с сервера. Проверяйте на [code]null[/code]
## перед использованием!
var data_file: ConfigFile


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_PREDELETE, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if save_file:
				save_file.save_encrypted_pass(SAVE_FILE_PATH, SAVE_FILE_PASSWORD)
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit()


## Инициализирует глобальный синглтон с объектом [param main] класса [Main].
func initialize(main_node: Main) -> void:
	save_file = ConfigFile.new()
	save_file.load_encrypted_pass(SAVE_FILE_PATH, SAVE_FILE_PASSWORD)
	
	items_db = load("uid://pwq1e7l2ckos")
	items_db.initialize()
	
	main = main_node


## Выходит из игры. Если [param restart] равен [code]true[/code], перезапускает игру с аргументами,
## указанными в [param args].
func quit(restart := false, args := PackedStringArray()) -> void:
	if save_file:
		set_int("window_size_x", get_window().size.x)
		set_int("window_size_y", get_window().size.y)
		set_int("window_pos_x", get_window().position.x)
		set_int("window_pos_y", get_window().position.y)
		save_file.save_encrypted_pass(SAVE_FILE_PATH, SAVE_FILE_PASSWORD)
	if main and main.upnp:
		main.upnp.finalize()
	
	if args.is_empty() and restart:
		var all_args: PackedStringArray = OS.get_cmdline_args()
		var user_args: PackedStringArray = OS.get_cmdline_user_args()
		for arg: String in all_args:
			if not arg in user_args:
				args.append(arg)
		args.append("++")
		args.append_array(user_args)
	if main and main.console:
		if restart:
			OS.create_instance(args)
		OS.kill(OS.get_process_id())
	else:
		OS.set_restart_on_exit(restart, args)
		get_tree().quit()


#region Функции задавания и получения значений
## Получает значение типа [Variant] по [param id]. Если его нет, вернёт [param default_value].
func get_variant(id: String, default_value: Variant) -> Variant:
	return save_file.get_value(DEFAULT_SAVE_FILE_SECTION, id, default_value)


## Задаёт значение типа [Variant] под [param id].
func set_variant(id: String, value: Variant) -> void:
	save_file.set_value(DEFAULT_SAVE_FILE_SECTION, id, value)


## Получает значение типа [int] по [param id]. Если его нет, вернёт [param default_value].
func get_int(id: String, default_value: int = 0) -> int:
	var value: int = save_file.get_value(DEFAULT_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение типа [int] под [param id].
func set_int(id: String, value: int) -> void:
	save_file.set_value(DEFAULT_SAVE_FILE_SECTION, id, value)


## Получает значение типа [float] по [param id]. Если его нет, вернёт [param default_value].
func get_float(id: String, default_value := 0.0) -> float:
	var value: float = save_file.get_value(DEFAULT_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение типа [float] под [param id].
func set_float(id: String, value: float) -> void:
	save_file.set_value(DEFAULT_SAVE_FILE_SECTION, id, value)


## Получает значение типа [bool] по [param id]. Если его нет, вернёт [param default_value].
func get_bool(id: String, default_value := false) -> bool:
	var value: bool = save_file.get_value(DEFAULT_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение типа [bool] под [param id].
func set_bool(id: String, value: bool) -> void:
	save_file.set_value(DEFAULT_SAVE_FILE_SECTION, id, value)


## Получает значение типа [String] по [param id]. Если его нет, вернёт [param default_value].
func get_string(id: String, default_value := "") -> String:
	var value: String = save_file.get_value(DEFAULT_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение типа [String] под [param id].
func set_string(id: String, value: String) -> void:
	save_file.set_value(DEFAULT_SAVE_FILE_SECTION, id, value)
#endregion


#region Функции задавания и получения настроек
## Получает значение настройки типа [Variant] по [param id].
## Если его нет, вернёт [param default_value].
func get_setting_variant(id: String, default_value: Variant) -> Variant:
	return save_file.get_value(SETTINGS_SAVE_FILE_SECTION, id, default_value)


## Задаёт значение настройки типа [Variant] под [param id].
func set_setting_variant(id: String, value: Variant) -> void:
	save_file.set_value(SETTINGS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки типа [int] по [param id].
## Если его нет, вернёт [param default_value].
func get_setting_int(id: String, default_value: int = 0) -> int:
	var value: int = save_file.get_value(SETTINGS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки типа [int] под [param id].
func set_setting_int(id: String, value: int) -> void:
	save_file.set_value(SETTINGS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки типа [float] по [param id].
## Если его нет, вернёт [param default_value].
func get_setting_float(id: String, default_value := 0.0) -> float:
	var value: float = save_file.get_value(SETTINGS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки типа [float] под [param id].
func set_setting_float(id: String, value: float) -> void:
	save_file.set_value(SETTINGS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки типа [bool] по [param id].
## Если его нет, вернёт [param default_value].
func get_setting_bool(id: String, default_value := false) -> bool:
	var value: bool = save_file.get_value(SETTINGS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки типа [bool] под [param id].
func set_setting_bool(id: String, value: bool) -> void:
	save_file.set_value(SETTINGS_SAVE_FILE_SECTION, id, value)
#endregion


#region Функции задавания и получения настроек управления
## Получает значение настройки управления типа [Variant] по [param id].
## Если его нет, вернёт [param default_value].
func get_controls_variant(id: String, default_value: Variant) -> Variant:
	return save_file.get_value(CONTROLS_SAVE_FILE_SECTION, id, default_value)


## Задаёт значение настройки управления типа [Variant] под [param id].
func set_controls_variant(id: String, value: Variant) -> void:
	save_file.set_value(CONTROLS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки управления типа [float] по [param id].
## Если его нет, вернёт [param default_value].
func get_controls_float(id: String, default_value := 0.0) -> float:
	var value: float = save_file.get_value(CONTROLS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки управления типа [float] под [param id].
func set_controls_float(id: String, value: float) -> void:
	save_file.set_value(CONTROLS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки управления типа [int] по [param id].
## Если его нет, вернёт [param default_value].
func get_controls_int(id: String, default_value: int = 0) -> int:
	var value: int = save_file.get_value(CONTROLS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки управления типа [int] под [param id].
func set_controls_int(id: String, value: int) -> void:
	save_file.set_value(CONTROLS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки управления типа [bool] по [param id].
## Если его нет, вернёт [param default_value].
func get_controls_bool(id: String, default_value := false) -> bool:
	var value: bool = save_file.get_value(CONTROLS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки управления типа [bool] под [param id].
func set_controls_bool(id: String, value: bool) -> void:
	save_file.set_value(CONTROLS_SAVE_FILE_SECTION, id, value)


## Получает значение настройки управления типа [Vector2] по [param id].
## Если его нет, вернёт [param default_value].
func get_controls_vector2(id: String, default_value := Vector2.ZERO) -> Vector2:
	var value: Vector2 = save_file.get_value(CONTROLS_SAVE_FILE_SECTION, id, default_value)
	return value


## Задаёт значение настройки управления типа [Vector2] под [param id].
func set_controls_vector2(id: String, value: Vector2) -> void:
	save_file.set_value(CONTROLS_SAVE_FILE_SECTION, id, value)
#endregion
