class_name Main
extends Node

## Главный класс игры.
##
## Отвечает за переключение между сценами, загрузку игры и прочее.

## Внутренний сигнал, используемый при загрузке.
signal loading_stage_finished(success: bool)
## URL сервера с данными для игры (патчами, предложениями в магазине, ...).
const SERVER_URL := "https://diamondstudiogames.ru/circle-shot"
## Максимальное отношение ширины к высоте, превысив которое содержимое окна начнёт обрезаться.
const MAX_ASPECT_RATIO := 2.34
## Минимальное отношение ширины к высоте, пренизив которое содержимое окна начнёт обрезаться.
const MIN_ASPECT_RATIO := 1.5
## Разрешённые расширения файлов для загрузки в качестве пользовательских треков.
const ALLOWED_MUSIC_FILE_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]
## Максимальная длина названия файла пользовательского трека. Лишнее обрезается.
const MAX_MUSIC_FILE_NAME_LENGTH: int = 45
## Максимальный размер файла пользовательского трека. Если размер больше максимального,
## он не будет загружен.
const MAX_MUSIC_FILE_SIZE_MB := 15.0
## Максимальное количество пользовательских треков.
const MAX_CUSTOM_TRACKS: int = 20

## Список путей к ресурсам для загрузки в память при запуске игры.
## Ускоряет последующую загрузку этих ресурсов.
@export_file("Resource") var resources_to_preload_paths: Array[String]
## Ссылка на [Game]. Может отсутствовать.
var game: Game
## Ссылка на [Menu]. Может отсутствовать.
var menu: Menu
## Список открытых на данный момент экранов.
var screens: Array[Control]
## Ссылка на узел воспроизведения музыки меню.
var menu_music: AudioStreamPlayer
## Словарь загруженных пользовательских треков в формате "<имя файла> - <ресурс трека>".
var custom_tracks: Dictionary[String, AudioStream]
var _preloaded_resources: Array[Resource]
var _download_http: HTTPRequest

## Путь до папки с пользовательскими треками.
@onready var music_path: String = OS.get_system_dir(OS.SYSTEM_DIR_MUSIC).path_join(
		str(ProjectSettings.get_setting("application/config/name")))
@onready var _default_window_content_width: int = \
		ProjectSettings.get_setting("display/window/size/viewport_width")
@onready var _default_window_content_height: int = \
		ProjectSettings.get_setting("display/window/size/viewport_height")
@onready var _load_status_label: Label = $LoadingScreen/StatusLabel
@onready var _load_progress_bar: ProgressBar = $LoadingScreen/ProgressBar


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _download_http.get_body_size() > 0:
		_load_progress_bar.value = _download_http.get_downloaded_bytes() * 100.0 \
				/ _download_http.get_body_size()


func _input(event: InputEvent) -> void:
	if OS.has_feature("pc") and event.is_action(&"fullscreen") \
			and event.is_pressed() and Globals.save_file:
		Globals.set_setting_bool("fullscreen", not Globals.get_setting_bool("fullscreen"))
		Globals.apply_settings()


## Открывает меню. Закрывает все остальное.
func open_menu() -> void:
	if is_instance_valid(menu):
		push_error("Menu is already opened.")
		return
	
	if is_instance_valid(game):
		game.queue_free()
	for screen: Node in screens:
		screen.queue_free()
	
	var menu_scene: PackedScene = load("uid://4wb77emq8t5p")
	menu = menu_scene.instantiate()
	add_child(menu)
	print_verbose("Opened menu.")


## Открывает игру с меню локальной игры. Закрывает всё остальное.
func open_local_game() -> void:
	if is_instance_valid(game):
		push_error("Game is already opened.")
		return
	
	if is_instance_valid(menu):
		menu.queue_free()
	for screen: Node in screens:
		screen.queue_free()
	
	var game_scene: PackedScene = load("uid://scqgxynxowrb")
	game = game_scene.instantiate()
	add_child(game)
	game.init_connect_local()
	print_verbose("Opened game with local menu.")


## Открывает экран, указанный в [param screen_scene], и регистрирует его в [member screens].
## Возвращает узел этого экрана или [code]null[/code], если такой экран уже открыт.
func open_screen(screen_scene: PackedScene) -> Control:
	var screen: Control = screen_scene.instantiate()
	if has_node(NodePath(screen.name)):
		push_error("Screen %s is already opened." % screen.name)
		return null
	screen.tree_exited.connect(_on_screen_tree_exited.bind(screen))
	add_child(screen)
	if not screens.is_empty():
		screens[-1].hide()
	elif is_instance_valid(menu):
		menu.hide()
	screens.append(screen)
	print_verbose("Opened screen: %s." % screen.name)
	return screen


## Выдаёт критическую ошибку, которая останавливает всю игру. Использовать только в безвыходных
## ситуациях. Если [param info] не пустое, отображает дополнительную информацию.
func show_critical_error(info := "", log_error := "") -> void:
	get_tree().paused = true
	var dialog := AcceptDialog.new()
	dialog.title = "Критическая ошибка!"
	dialog.dialog_text = "Произошла критическая ошибка. Подробности можно найти в логах. \
Игра будет завершена при закрытии этого диалога."
	if not info.is_empty():
		dialog.dialog_text += "\nИнформация: %s." % info
	if not log_error.is_empty():
		push_error(log_error)
	dialog.canceled.connect(Globals.quit)
	dialog.confirmed.connect(Globals.quit)
	dialog.transient = true
	dialog.exclusive = true
	dialog.process_mode = PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.popup_centered()


func _update_window_stretch_aspect() -> void:
	if get_window().size.aspect() > MAX_ASPECT_RATIO:
		get_window().content_scale_size = Vector2i(
				roundi(_default_window_content_height * MAX_ASPECT_RATIO),
				_default_window_content_height
		)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	elif get_window().size.aspect() < MIN_ASPECT_RATIO:
		get_window().content_scale_size = Vector2i(
				_default_window_content_width,
				roundi(_default_window_content_width / MIN_ASPECT_RATIO)
		)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	else:
		get_window().content_scale_size = \
				Vector2i(_default_window_content_width, _default_window_content_height)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _start_load() -> void:
	$SplashScreen.queue_free()
	($LoadingScreen/AnimationPlayer as AnimationPlayer).play(&"Begin")
	
	_loading_init()
	await ($LoadingScreen/AnimationPlayer as AnimationPlayer).animation_finished
	
	_loading_check_server()
	if await loading_stage_finished:
		_loading_download_data()
		if await loading_stage_finished:
			_loading_check_patches()
			await loading_stage_finished
	
	_loading_apply_patch()
	await loading_stage_finished
	
	_loading_init_systems()
	await loading_stage_finished
	
	if not Globals.headless:
		_loading_custom_tracks()
		await loading_stage_finished
		
		_loading_preload_resources()
		await loading_stage_finished
	
	_loading_upnp()
	await loading_stage_finished
	
	print_verbose("Loading completed. Game version: %s" % Globals.version)
	print_verbose('Run game with "++ --help" to see game specific arguments.')
	_loading_open_menu()
	await loading_stage_finished
	$LoadingScreen.queue_free()
	
	if Globals.headless:
		open_local_game()
		game.create()
		var http: HTTPRequest = game.get_node(^"Lobby/ViewIPDialog/HTTPRequest")
		http.request("https://ipv4.icanhazip.com/")


func _loading_init() -> void:
	print_verbose("Initializing...")
	_load_status_label.text = "Инициализация..."
	_load_progress_bar.value = 0.0
	
	if "--help" in OS.get_cmdline_user_args():
		print("Game specific arguments:")
		print()
		print("--upnp: Enables UPnP regardless of current settings.")
		print("--disable-update-check: Disables update check and hides settings related to it.")
		print("--console: Enables built-in console.")
		print("--reset-window: Don't restore saved window state.")
		print()
		print("These arguments should be written after ++ or -- separator.")
		print("You always can use engine arguments, such as --headless and --verbose.")
		if OS.get_name() == "Windows":
			print("Note: to use --console on Windows, you must launch game from *.console.exe \
file, otherwise it will NOT function.")
	
	Globals.initialize()
	if DisplayServer.get_name() == "headless":
		print("Running in headless mode.")
		Globals.headless = true
	
	_update_window_stretch_aspect()
	get_window().size_changed.connect(_update_window_stretch_aspect)
	if not "--reset-window" in OS.get_cmdline_user_args():
		get_window().size.x = Globals.get_int("window_size_x", get_window().size.x)
		get_window().size.y = Globals.get_int("window_size_y", get_window().size.y)
		get_window().position.x = Globals.get_int("window_pos_x", get_window().position.x)
		get_window().position.y = Globals.get_int("window_pos_y", get_window().position.y)
	
	multiplayer.multiplayer_peer = null # Чтобы убрать OfflineMultiplayerPeer
	get_viewport().set_canvas_cull_mask_bit(1, false)
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().multiplayer_poll = false
	
	await get_tree().process_frame
	print_verbose("Done initializing.")
	loading_stage_finished.emit(true)


func _loading_check_server() -> void:
	print_verbose("Checking connection to server...")
	_load_status_label.text = "Проверка соединения с сервером..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	var http := HTTPRequest.new()
	http.timeout = 5.0
	http.request_completed.connect(_on_check_http_request_completed.bind(http))
	add_child(http)
	
	var err: Error = http.request(SERVER_URL.path_join("check.txt"))
	if err != OK:
		http.request_completed.disconnect(_on_check_http_request_completed)
		push_warning("Can't connect to server. Error: %s." % error_string(err))
		loading_stage_finished.emit(false)
		http.queue_free()


func _loading_download_data() -> void:
	print_verbose("Downloading data...")
	_load_status_label.text = "Загрузка данных..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.request_completed.connect(_on_data_http_request_completed.bind(http))
	add_child(http)
	
	var err: Error = http.request(SERVER_URL.path_join("data.cfg"))
	if err != OK:
		http.request_completed.disconnect(_on_data_http_request_completed)
		push_warning("Can't download data. Error: %s." % error_string(err))
		loading_stage_finished.emit(false)
		http.queue_free()


func _loading_check_patches() -> void:
	if not Globals.get_setting_bool("check_patches") or OS.has_feature("editor"):
		print_verbose("Not checking patches: disabled.")
		loading_stage_finished.emit.call_deferred(false) # Ждём await
		return
	
	print_verbose("Checking remote patches...")
	await get_tree().process_frame
	
	var patches: Dictionary[String, int] = \
			Globals.get_variant("patches", {} as Dictionary[String, int])
	var remote_patch_code: int = Globals.data_file.get_value("patches", Globals.version, 0)
	var local_patch_code: int = patches.get(Globals.version, 0)
	print_verbose("Local patch version: %d, remote: %d." % [local_patch_code, remote_patch_code])
	
	if remote_patch_code > local_patch_code:
		print_verbose("New version of patch detected (%d), downloading..." % remote_patch_code)
		_load_status_label.text = "Загрузка патча..."
		if not DirAccess.dir_exists_absolute("user://patches"):
			DirAccess.make_dir_recursive_absolute("user://patches")
		var http := HTTPRequest.new()
		http.timeout = 20.0
		http.download_file = "user://patches/tmp.pck"
		http.request_completed.connect(
				_on_patch_http_request_completed.bind(http, remote_patch_code))
		add_child(http)
		_download_http = http
		set_process(true)
		
		var err: Error = http.request(
				SERVER_URL.path_join("patches").path_join("%s.pck" % Globals.version))
		if err != OK:
			http.request_completed.disconnect(_on_patch_http_request_completed)
			push_warning("Can't download patch. Error: %s." % error_string(err))
			http.queue_free()
			set_process(false)
			loading_stage_finished.emit(false)
	else:
		loading_stage_finished.emit(true)


func _loading_apply_patch() -> void:
	if not Globals.get_setting_bool("check_patches") or OS.has_feature("editor"):
		print_verbose("Not applying patches: disabled.")
		loading_stage_finished.emit.call_deferred(false) # Ждём await
		return
	
	print_verbose("Checking patch to apply...")
	await get_tree().process_frame
	
	var patches: Dictionary[String, int] = \
			Globals.get_variant("patches", {} as Dictionary[String, int])
	if Globals.version in patches:
		var patch_path := "user://patches/%s.pck" % Globals.version
		if FileAccess.file_exists(patch_path):
			_load_status_label.text = "Применение патча..."
			_load_progress_bar.value = 100.0
			await get_tree().process_frame
			ProjectSettings.load_resource_pack(patch_path)
			print_verbose("Patch with code %d applied." % patches[Globals.version])
			Globals.version += "-patched%d" % patches[Globals.version]
		else:
			push_warning("Patch entry exists, but file not found.")
			patches.erase(Globals.version)
			Globals.set_variant("patches", patches)
	else:
		print_verbose("No patch to apply.")
	loading_stage_finished.emit(true)


func _loading_init_systems() -> void:
	print_verbose("Initializing systems...")
	_load_status_label.text = "Инициализация систем..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	Globals.initialize_systems()
	
	menu_music = AudioStreamPlayer.new()
	menu_music.name = &"MenuMusic"
	menu_music.bus = &"Music"
	menu_music.autoplay = true
	menu_music.stream = load("uid://dbrfe66ser7ub")
	add_child(menu_music)
	move_child(menu_music, 0)
	
	print_verbose("Done initializing systems.")
	loading_stage_finished.emit(true)


func _loading_custom_tracks() -> void:
	if not Globals.get_setting_bool("custom_tracks"):
		print_verbose("Not loading custom tracks: disabled.")
		loading_stage_finished.emit.call_deferred(false) # Ждём await
		return
	
	print_verbose("Loading custom tracks...")
	_load_status_label.text = "Загрузка пользовательских треков..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	var dir := DirAccess.open(music_path)
	if not dir:
		push_error("Failed creating DirAccess at path %s. Error: %s." % [
			music_path,
			error_string(DirAccess.get_open_error()),
		])
		loading_stage_finished.emit(false)
		return
	
	var to_load: Dictionary[String, String]
	for file: String in dir.get_files():
		if to_load.size() >= MAX_CUSTOM_TRACKS:
			break
		if file.get_extension() in ALLOWED_MUSIC_FILE_EXTENSIONS:
			to_load[dir.get_current_dir().path_join(file)] = file.get_extension()
			print_verbose("Found track: %s." % dir.get_current_dir().path_join(file))
	
	var to_load_count: int = to_load.size()
	var counter: int = 0
	var last_ticks: int = Time.get_ticks_msec()
	for path: String in to_load:
		var stream: AudioStream
		var valid := true
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			valid = false
			push_error("Failed creating FileAccess at path %s. Error: %s." % [
				path,
				error_string(FileAccess.get_open_error()),
			])
		if valid and file.get_length() > MAX_MUSIC_FILE_SIZE_MB * 1024 * 1024:
			valid = false
		if valid:
			match to_load[path]:
				"mp3":
					var mp3 := AudioStreamMP3.load_from_buffer(file.get_buffer(file.get_length()))
					if mp3:
						mp3.loop = true
						stream = mp3
					else:
						valid = false
				"ogg":
					var ogg := AudioStreamOggVorbis.load_from_buffer(
							file.get_buffer(file.get_length()))
					if ogg:
						ogg.loop = true
						stream = ogg
					else:
						valid = false
				"wav":
					var wav := AudioStreamWAV.load_from_buffer(file.get_buffer(file.get_length()))
					if wav:
						wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
						wav.loop_end = floori(wav.get_length() * wav.mix_rate)
						stream = wav
					else:
						valid = false
		
		if valid:
			print_verbose("Loaded track: %s." % path)
			custom_tracks[
				path.get_file().get_basename().left(MAX_MUSIC_FILE_NAME_LENGTH)
			] = stream
		else:
			print_verbose("Track at %s is invalid." % path)
		
		_load_progress_bar.value = 100.0 * counter / to_load_count
		counter += 1
		if Time.get_ticks_msec() - last_ticks > 16:
			await get_tree().process_frame
			last_ticks = Time.get_ticks_msec()
	
	_load_progress_bar.value = 100.0
	await get_tree().process_frame
	print_verbose("Done loading custom tracks.")
	loading_stage_finished.emit(true)


func _loading_preload_resources() -> void:
	print_verbose("Preloading resources...")
	_load_status_label.text = "Загрузка ресурсов..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	var counter: int = 1
	var to_preload: Array[String]
	to_preload.append_array(resources_to_preload_paths)
	var to_preload_count: int = to_preload.size()
	
	var last_ticks: int = Time.get_ticks_msec()
	for path: String in to_preload:
		var resource: Resource = \
				ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		_preloaded_resources.append(resource)
		_load_progress_bar.value = 100.0 * counter / to_preload_count
		counter += 1
		print_verbose("Preloaded resource: %s." % path)
		if Time.get_ticks_msec() - last_ticks > 16:
			await get_tree().process_frame
			last_ticks = Time.get_ticks_msec()
	
	_load_progress_bar.value = 100.0
	await get_tree().process_frame
	print_verbose("Done preloading resources.")
	loading_stage_finished.emit(true)


func _loading_upnp() -> void:
	if not Globals.get_setting_bool("upnp") and not "--upnp" in OS.get_cmdline_user_args():
		print_verbose("UPnP disabled.")
		loading_stage_finished.emit.call_deferred(false)
		return
	
	_load_status_label.text = "Поиск устройств UPnP..."
	_load_progress_bar.value = 0.0
	await get_tree().process_frame
	
	var upnp := UPNPManager.new()
	upnp.name = &"UPNPManager"
	add_child(upnp)
	
	Globals.upnp = upnp
	
	upnp.discover()
	await upnp.status_changed
	
	if upnp.status == UPNPManager.Status.INACTIVE:
		loading_stage_finished.emit(false)
		return
	
	_load_status_label.text = "Открытие порта через UPnP..."
	_load_progress_bar.value = 50.0
	await get_tree().process_frame
	
	upnp.forward_port(Game.DEFAULT_PORT)
	await upnp.status_changed
	
	if upnp.status == UPNPManager.Status.INACTIVE:
		loading_stage_finished.emit(false)
		return
	
	if OS.is_stdout_verbose() or DisplayServer.get_name() == "headless":
		print("UPnP forwarded port. External IP: %s" % upnp.get_external_ip())
	loading_stage_finished.emit(true)


func _loading_open_menu() -> void:
	print_verbose("Opening menu...")
	_load_status_label.text = "Загрузка меню..."
	_load_progress_bar.value = 100.0
	await get_tree().process_frame
	
	open_menu()
	# Чтобы меню было под загр. экраном
	move_child($LoadingScreen, -1)
	($LoadingScreen/AnimationPlayer as AnimationPlayer).play(&"End")
	await ($LoadingScreen/AnimationPlayer as AnimationPlayer).animation_finished
	loading_stage_finished.emit(true)


func _on_screen_tree_exited(screen: Control) -> void:
	screens.erase(screen)
	if not screens.is_empty():
		screens[-1].show()
	elif is_instance_valid(menu):
		menu.show()


func _on_check_http_request_completed(result: HTTPRequest.Result,
		response_code: HTTPClient.ResponseCode, _headers: PackedStringArray, 
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Connect to server: result is not Success. Result: %d." % result)
		loading_stage_finished.emit(false)
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning(
				"Connect to server: response code is not 200. Response code: %d." % response_code)
		loading_stage_finished.emit(false)
		return
	var text: String = body.get_string_from_utf8()
	if "circleshot" in text:
		print_verbose("Connection success.")
		loading_stage_finished.emit(true)
	else:
		push_warning("Connection success, but check failed.")
		loading_stage_finished.emit(false)


func _on_data_http_request_completed(result: HTTPRequest.Result,
		response_code: HTTPClient.ResponseCode, _headers: PackedStringArray, 
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Download data: result is not Success. Result: %d." % result)
		loading_stage_finished.emit(false)
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning(
				"Download data: response code is not 200. Response code: %d." % response_code)
		loading_stage_finished.emit(false)
		return
	
	var data_file := ConfigFile.new()
	var err: Error = data_file.parse(body.get_string_from_utf8())
	if err != OK:
		push_warning("Can't parse downloaded data. Error: %s." % error_string(err))
		loading_stage_finished.emit(false)
	else:
		print_verbose("Data downloaded successfully.")
		Globals.data_file = data_file
		loading_stage_finished.emit(true)


func _on_patch_http_request_completed(result: HTTPRequest.Result,
		response_code: HTTPClient.ResponseCode, _headers: PackedStringArray, 
		_body: PackedByteArray, http: HTTPRequest, new_patch_code: int) -> void:
	http.queue_free()
	set_process(false)
	const TMP_PATCH_PATH := "user://patches/tmp.pck"
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Download patch: result is not Success. Result: %d." % result)
		if FileAccess.file_exists(TMP_PATCH_PATH):
			DirAccess.remove_absolute(TMP_PATCH_PATH)
		loading_stage_finished.emit(false)
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning(
				"Download patch: response code is not 200. Response code: %d." % response_code)
		if FileAccess.file_exists(TMP_PATCH_PATH):
			DirAccess.remove_absolute(TMP_PATCH_PATH)
		loading_stage_finished.emit(false)
		return
	
	var patch_path := "user://patches/%s.pck" % Globals.version
	if FileAccess.file_exists(patch_path):
		DirAccess.remove_absolute(patch_path)
	DirAccess.rename_absolute(TMP_PATCH_PATH, patch_path)
	var patches: Dictionary[String, int] = \
			Globals.get_variant("patches", {} as Dictionary[String, int])
	patches[Globals.version] = new_patch_code
	Globals.set_variant("patches", patches)
	loading_stage_finished.emit(true)
