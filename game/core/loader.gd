class_name Loader
extends CanvasLayer

## Класс, который занимается загрузкой.
##
## В комбинации с [Game], загружает события и прочее.

## Внутренний сигнал, издаётся при завершении загрузки.
signal loaded(success: bool)

var _requested_paths: Array[String]
var _loaded_paths: Array[String]

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _bar: ProgressBar = $Screen/ProgressBar
@onready var _status_text: Label = $Screen/ProgressBar/Label


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	var total_progress := 0.0
	for path: String in _requested_paths:
		if path in _loaded_paths:
			total_progress += 1.0
			continue
		var progress: Array[float]
		var status: ResourceLoader.ThreadLoadStatus = \
				ResourceLoader.load_threaded_get_status(path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				total_progress += 1.0
				_loaded_paths.append(path)
				print_verbose("Done loading resource %s." % path)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				total_progress += progress[0]
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				print_verbose("Failed loading resource %s." % path)
				loaded.emit(false)
				return
	
	_bar.value = total_progress / _requested_paths.size() * 100.0
	print_verbose("Status of loading paths: %d%%" % roundi(_bar.value))
	if _loaded_paths.size() == _requested_paths.size():
		loaded.emit(true)


## Загружает события и карту по [param event_idx] и [param map_idx] соответственно. Возвращает
## [Event], если загрузка прошла удачно, иначе возвращает [code]null[/code].[br]
## [b]Внимание[/b]: этот метод - [b]корутина[/b], так что Вам необходимо подождать его с помощью
## [code]await[/code].
func load_event(event_idx: int, map_idx: int) -> Event:
	_anim.play(&"start_load")
	_status_text.text = "Загрузка события и карты..."
	_requested_paths.clear()
	_loaded_paths.clear()
	
	var event_path: String = Globals.items_db.events[event_idx].scene_path
	print_verbose("Requesting load for event %s." % event_path)
	var err: Error = ResourceLoader.load_threaded_request(
			event_path, "", false, ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if err != OK:
		push_error("Load request for event %s failed with error: %s." % [
			event_path,
			error_string(err),
		])
		finish_load(false)
		return null
	_requested_paths.append(event_path)
	
	var map_path: String = Globals.items_db.events[event_idx].maps[map_idx].scene_path
	print_verbose("Requesting load for map %s." % map_path)
	err = ResourceLoader.load_threaded_request(
			map_path, "", false, ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if err != OK:
		push_error("Load request for map %s failed with error: %s." % [
			map_path,
			error_string(err),
		])
		finish_load(false)
		return null
	_requested_paths.append(map_path)
	
	set_process(true)
	var success: bool = await loaded
	if not success:
		push_error("Failed loading of event and/or map.")
		finish_load(false)
		return null
	
	print_verbose("Done loading resources.")
	var event_scene: PackedScene = ResourceLoader.load_threaded_get(event_path)
	var map_scene: PackedScene = ResourceLoader.load_threaded_get(map_path)
	var event: Event = event_scene.instantiate()
	var map: Map = map_scene.instantiate()
	event.add_child(map)
	
	set_process(false)
	_bar.value = 100.0
	_status_text.text = "Ожидание других игроков..."
	print_verbose("Done loading event.")
	return event


## Загружает испытание и карту по [param challenge_idx] и [param map_idx] соответственно. Возвращает
## [Challenge], если загрузка прошла удачно, иначе возвращает [code]null[/code].[br]
## [b]Внимание[/b]: этот метод - [b]корутина[/b], так что Вам необходимо подождать его с помощью
## [code]await[/code].
func load_challenge(challenge_idx: int, map_idx: int) -> Challenge:
	_anim.play(&"start_load")
	_status_text.text = "Загрузка испытания и карты..."
	_requested_paths.clear()
	_loaded_paths.clear()
	
	var challenge_path: String = Globals.items_db.challenges[challenge_idx].scene_path
	print_verbose("Requesting load for challenge %s." % challenge_path)
	var err: Error = ResourceLoader.load_threaded_request(
			challenge_path, "", false, ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if err != OK:
		push_error("Load request for challenge %s failed with error: %s." % [
			challenge_path,
			error_string(err),
		])
		finish_load(false)
		return null
	_requested_paths.append(challenge_path)
	
	var map_path: String = Globals.items_db.challenges[challenge_idx].maps[map_idx].scene_path
	print_verbose("Requesting load for map %s." % map_path)
	err = ResourceLoader.load_threaded_request(
			map_path, "", false, ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if err != OK:
		push_error("Load request for map %s failed with error: %s." % [
			map_path,
			error_string(err),
		])
		finish_load(false)
		return null
	_requested_paths.append(map_path)
	
	set_process(true)
	var success: bool = await loaded
	if not success:
		push_error("Failed loading of challenge and/or map.")
		finish_load(false)
		return null
	
	print_verbose("Done loading resources.")
	var challenge_scene: PackedScene = ResourceLoader.load_threaded_get(challenge_path)
	var map_scene: PackedScene = ResourceLoader.load_threaded_get(map_path)
	var challenge: Challenge = challenge_scene.instantiate()
	var map: Map = map_scene.instantiate()
	challenge.add_child(map)
	
	set_process(false)
	_bar.value = 100.0
	_status_text.text = "Ожидание..."
	print_verbose("Done loading challenge.")
	return challenge


## Загружает мир по данному [param path]. Возвращает [World], если загрузка прошла удачно,
## иначе возвращает [code]null[/code].[br]
## [b]Внимание[/b]: этот метод - [b]корутина[/b], так что Вам необходимо подождать его с помощью
## [code]await[/code].
func load_world(path: String) -> World:
	_anim.play(&"start_load")
	_status_text.text = "Загрузка..."
	_requested_paths.clear()
	_loaded_paths.clear()
	
	print_verbose("Requesting load for world %s." % path)
	var err: Error = ResourceLoader.load_threaded_request(
			path, "", false, ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if err != OK:
		push_error("Load request for world %s failed with error: %s." % [
			path,
			error_string(err),
		])
		finish_load(false)
		return null
	_requested_paths.append(path)
	
	set_process(true)
	var success: bool = await loaded
	if not success:
		push_error("Failed loading of world.")
		finish_load(false)
		return null
	
	print_verbose("Done loading resources.")
	var world_scene: PackedScene = ResourceLoader.load_threaded_get(path)
	var world: World = world_scene.instantiate()
	
	set_process(false)
	_bar.value = 100.0
	_status_text.text = "Ожидание..."
	print_verbose("Done loading world.")
	return world


## Предзагружает пушки по указанным в параметрах индексам. Возвращает список [PackedScene],
## если загрузка прошла удачно, иначе возвращаемый список будет пуст.[br]
## [b]Внимание[/b]: этот метод - [b]корутина[/b], так что Вам необходимо подождать его с помощью
## [code]await[/code].
func preload_equip(skins: Array[int], skills: Array[int],
		weapons: Array[int]) -> Array[PackedScene]:
	_status_text.text = "Предзагрузка экипировки..."
	_requested_paths.clear()
	_loaded_paths.clear()
	var result: Array[PackedScene]
	
	for idx: int in skins:
		var path: String = Globals.items_db.skins[idx].scene_path
		if not path in _requested_paths:
			_requested_paths.append(path)
	for idx: int in skills:
		var path: String = Globals.items_db.skills[idx].scene_path
		if not path in _requested_paths:
			_requested_paths.append(path)
	for idx: int in weapons:
		var path: String = Globals.items_db.weapons[idx].scene_path
		if not path in _requested_paths:
			_requested_paths.append(path)
	
	for path: String in _requested_paths:
		print_verbose("Requesting load for equip %s." % path)
		var err: Error = ResourceLoader.load_threaded_request(
				path, "", false, ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		if err != OK:
			push_error("Load request for equip %s failed with error: %s." % [
				path,
				error_string(err),
			])
			finish_load(false)
			return result
	
	set_process(true)
	var success: bool = await loaded
	if not success:
		push_error("Failed preloading equip.")
		finish_load(false)
		return result
	
	print_verbose("Done loading resources.")
	for path: String in _requested_paths:
		result.append(ResourceLoader.load_threaded_get(path))
	
	set_process(false)
	_bar.value = 100.0
	_status_text.text = "Ожидание других игроков..."
	print_verbose("Done preloading equip.")
	return result


## Завершает загрузку, а именно анимацию.
func finish_load(success: bool) -> void:
	_anim.play(&"end_load")
	if success:
		_status_text.text = "Готово!"
		print_verbose("Load finished.")
	else:
		set_process(false)
		_status_text.text = "Ошибка загрузки!"
		print_verbose("Load failed.")


func _on_game_closed() -> void:
	if is_processing():
		print_verbose("Game closed, aborting load.")
		loaded.emit(false)
