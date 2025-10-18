class_name World
extends Node

## Основной узел игровой части.
##
## Базовый класс для игровой части. Досутп к нему можно получить через
## [member Game.world] (только для неигровой части) или через
## [code](get_tree().get_first_node_in_group(&"world") as World)[/code].

## Издаётся, когда был установлен локальный игрок через [method set_local_player].
signal local_player_created(player: Player)
## Издаётся, когда была установлена команда локального игрока через [method set_local_team].
signal local_team_set(team: int)
## Издаётся, когда какая-либо статистика (нанесённый урон и/или убийства) меняется.
signal stats_changed

## Издаётся при начале кат-сцены.
signal cutscene_started
## Издаётся при конце кат-сцены.
signal cutscene_ended

## Амплитуда вибрации при нанесении урона.
const HIT_VIBRATION_AMPLITUDE := 0.04
## Длительность вибрации при нанесении урона.
const HIT_VIBRATION_DURATION_MS: int = 100
## Амплитуда вибрации при убийстве.
const KILL_VIBRATION_AMPLITUDE := 0.12
## Длительность вибрации при убийстве.
const KILL_VIBRATION_DURATION_MS: int = 300

## Сцены сущностей для предзагрузки.
@export var entity_scenes: Array[PackedScene]
## Официальные треки. Могут дополняться (или заменяться) кастомными.
@export var tracks: Array[AudioStream]

## Локальный игрок. Может быть [code]null[/code].
var local_player: Player
## Команда локального игрока.
var local_team: int = -1

## Сколько игрок нанёс урона за эту сессию.
var damaged: int = 0
## Сколько игрок убил сущностей за эту сессию.
var kills: int = 0
## Сколько раз игрок умер за эту сессию.
var deaths: int = 0

## Словарь формата <ID игрока> - <объект игрока>.
var players: Dictionary[int, Player]
## Словарь формата <ID сущности> - <объект сущности>.
var entities: Dictionary[int, Entity]
## Список кэшированных ресурсов.
var cached_resources: Array[Resource]

var _vibration_enabled: bool
var _queued_hits: Array[Hit]
var _cutscene_tween: Tween

var _hit_marker_scene: PackedScene = load("uid://c2f0n1b5sfpdh")
var _kill_marker_scene: PackedScene = load("uid://blhm6uka1p287")


func _ready() -> void:
	Globals.main.menu_music.process_mode = Node.PROCESS_MODE_DISABLED
	if multiplayer.is_server():
		get_tree().physics_frame.connect(_flush_queued_hits)
	
	_vibration_enabled = Globals.get_setting_bool("vibration")
	if Globals.get_setting_bool("minimap"):
		($MinimapViewport as SubViewport).world_2d = get_viewport().find_world_2d()
		($UI/Main/Minimap as TextureRect).texture = ($MinimapViewport as SubViewport).get_texture()
	else:
		($MinimapViewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		($UI/Main/Minimap as CanvasItem).hide()
	
	if Globals.get_setting_bool("custom_tracks"):
		if not Globals.get_setting_bool("official_tracks"):
			tracks.clear()
		tracks.append_array(Globals.main.custom_tracks.values())
	
	var entities_spawner: MultiplayerSpawner = $EntitiesSpawner
	for scene: PackedScene in entity_scenes:
		entities_spawner.add_spawnable_scene(scene.resource_path)
	var projectiles_spawner: MultiplayerSpawner = $ProjectilesSpawner
	for path: String in Globals.items_db.spawnable_projectiles_paths:
		projectiles_spawner.add_spawnable_scene(path)
	var other_spawner: MultiplayerSpawner = $OtherSpawner
	for path: String in Globals.items_db.spawnable_other_paths:
		other_spawner.add_spawnable_scene(path)
	
	_initialize()


func _exit_tree() -> void:
	Globals.main.menu_music.process_mode = Node.PROCESS_MODE_INHERIT


## Задаёт локального игрока.
func set_local_player(player: Player) -> void:
	player.died.connect(_on_local_player_died)
	local_player = player
	local_player_created.emit(player)
	set_local_team(player.team)
	
	_local_player_created(player)


## Задаёт команду локального игрока.
func set_local_team(team: int) -> void:
	local_team = team
	local_team_set.emit(team)


## Уничтожает всех сущностей, все снаряды и остальные объекты, появляющиеся во время игры.[br]
## [b]Примечание[/b]: этот метод должен вызываться только на сервере.
func cleanup() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	for entity: Node in $Entities.get_children():
		entity.queue_free()
	for projectile: Node in $Projectiles.get_children():
		projectile.queue_free()
	for other: Node in $Other.get_children():
		other.queue_free()


## Начинает кат-сцену: управление игроком прерывается и интерфейс скрывается.
func start_cutscene() -> void:
	if is_instance_valid(_cutscene_tween):
		_cutscene_tween.kill()
	_cutscene_tween = create_tween()
	_cutscene_tween.tween_property($UI/Main as CanvasItem,
			^":modulate", Color.TRANSPARENT, 0.5).from(Color.WHITE)
	_cutscene_tween.tween_callback(($UI/Main as CanvasItem).hide)
	cutscene_started.emit()


## Заканчивает кат-сцену: возвращает управление игроком и показывает интерфейс.
func end_cutscene() -> void:
	if is_instance_valid(_cutscene_tween):
		_cutscene_tween.kill()
	($UI/Main as CanvasItem).show()
	_cutscene_tween = create_tween()
	_cutscene_tween.tween_property($UI/Main as CanvasItem,
			^":modulate", Color.WHITE, 0.5)
	cutscene_ended.emit()


@rpc("unreliable", "call_local", "authority", 6)
func _register_hit(where: Vector2, amount: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	damaged += amount
	stats_changed.emit()
	
	var marker: Node2D = _hit_marker_scene.instantiate()
	marker.position = where
	$Vfx.add_child(marker)
	
	if _vibration_enabled:
		Input.vibrate_handheld(HIT_VIBRATION_DURATION_MS, HIT_VIBRATION_AMPLITUDE)
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, HIT_VIBRATION_AMPLITUDE, 0.0,
					HIT_VIBRATION_DURATION_MS / 1000.0)
			break


@rpc("reliable", "call_local", "authority", 6)
func _register_kill(where: Vector2, damaged_amount: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	damaged += damaged_amount
	kills += 1
	stats_changed.emit()
	
	var marker: Node2D = _kill_marker_scene.instantiate()
	marker.position = where
	$Vfx.add_child(marker)
	
	if _vibration_enabled:
		Input.vibrate_handheld(KILL_VIBRATION_DURATION_MS, KILL_VIBRATION_AMPLITUDE)
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, KILL_VIBRATION_AMPLITUDE, 0.0,
					KILL_VIBRATION_DURATION_MS / 1000.0)
			break


func _flush_queued_hits() -> void:
	for hit: Hit in _queued_hits:
		if hit.by != MultiplayerPeer.TARGET_PEER_SERVER and not hit.by in multiplayer.get_peers():
			continue
		if hit.fatal:
			_register_kill.rpc_id(hit.by, hit.where, hit.amount)
		else:
			_register_hit.rpc_id(hit.by, hit.where, hit.amount)
	_queued_hits.clear()


## Метод для переопределения. Вызывается сразу после [method Node._ready] и на клиенте,
## и на сервере.
func _initialize() -> void:
	pass


## Метод для переопределения. Вызывается сразу после [method set_local_player]. Поведение по
## умолчанию - камера перемещается к игроку.
func _local_player_created(player: Player) -> void:
	($Camera as SmartCamera).pan_to_target(player.camera_target, 0.3)


## Метод для переопределения. Вызывается в момент смерти локального игрока.
func _local_player_died() -> void:
	pass


func _on_entity_damaged(by: int, amount: int, entity: Entity) -> void:
	if by == MultiplayerPeer.TARGET_PEER_SERVER or by in multiplayer.get_peers():
		var hit_position: Vector2 = entity.global_position
		var should_add := true
		for hit: Hit in _queued_hits:
			if hit.by == by and hit.where.is_equal_approx(hit_position):
				hit.amount += amount
				should_add = false
				break
		if should_add:
			_queued_hits.append(Hit.new(by, hit_position, amount, false))


func _on_entity_killed(by: int, remained_health: int, entity: Entity) -> void:
	if by == MultiplayerPeer.TARGET_PEER_SERVER or by in multiplayer.get_peers():
		var kill_position: Vector2 = entity.global_position
		var should_add := true
		for hit: Hit in _queued_hits:
			if hit.by == by and hit.where.is_equal_approx(kill_position):
				hit.fatal = true
				hit.amount += remained_health
				should_add = false
				break
		if should_add:
			_queued_hits.append(Hit.new(by, kill_position, remained_health, true))
	
	entities.erase(entity.id)
	if entity is Player:
		players.erase(entity.id)


func _on_entities_child_entered_tree(node: Node) -> void:
	var entity := node as Entity
	if not entity:
		return
	await node.ready
	entity.damaged.connect(_on_entity_damaged.bind(entity))
	entity.killed.connect(_on_entity_killed.bind(entity))
	if entity.id < 0 and entity.id in entities:
		var id: int = entity.id - 1
		while id in entities:
			id -= 1
		entity.id = id
	entities[entity.id] = entity
	if entity is Player:
		players[entity.id] = entity


func _on_entities_child_exiting_tree(node: Node) -> void:
	var entity := node as Entity
	if not entity:
		return
	entities.erase(entity.id)
	if entity is Player:
		players.erase(entity.id)


func _on_local_player_died() -> void:
	deaths += 1
	stats_changed.emit()
	_local_player_died()


class Hit:
	var by: int
	var where: Vector2
	var amount: int
	var fatal: bool
	
	func _init(by_value: int, where_value: Vector2, amount_value: int, fatal_value: bool) -> void:
		by = by_value
		where = where_value
		fatal = fatal_value
		amount = amount_value
