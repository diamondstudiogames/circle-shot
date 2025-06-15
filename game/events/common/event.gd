class_name Event
extends Node

## Основной узел события.
##
## Базовый класс для всех событий в игре. Досутп к нему можно получить через
## [member Game.event] (только для неигровой части) или через
## [code](get_tree().get_first_node_in_group(&"Event") as Event)[/code].

## Издаётся, когда событие началось (т. е. после вызова [method _finish_start).
signal started
## Издаётся, когда событие закончилось.
signal ended
## Издаётся, когда был установлен локальный игрок через [method set_local_player].
signal local_player_created(player: Player)
## Издаётся, когда была установлена команда локального игрока через [method set_local_team].
signal local_team_set(team: int)

## Интенсивность вибрации при нанесении урона.
const HIT_VIBRATION_INTENSITY := 0.07
## Длительность вибрации при нанесении урона.
const HIT_VIBRATION_DURATION_MS: int = 100
## Интенсивность вибрации при убийстве.
const KILL_VIBRATION_INTENSITY := 0.15
## Длительность вибрации при убийстве.
const KILL_VIBRATION_DURATION_MS: int = 300

## Определяет максимум случайного расстояния от заданной точки появления.
@export var spawn_point_randomness := 40.0
## Сцены игроков для предзагрузки.
@export var player_scenes: Array[PackedScene]
## Официальные треки.
@export var tracks: Array[AudioStream]

## Локальный игрок. Может быть [code]null[/code].
var local_player: Player
## Команда локального игрока.
var local_team: int = -1
## Началось ли событие.
var was_started := false
## Количество тиков в момент создания события. Используется для корректировки анимации начала.
var created_ticks_msec: int
## Список кэшированных сцен.
var cached_scenes: Array[PackedScene]
## Словарь формата <ID игрока> - <массив данных об экипировке> (см. [member Player.equip_data]).
var players_equip_data: Dictionary[int, Array]
## Словарь формата <ID игрока> - <имя игрока>.
var players_names: Dictionary[int, String]
## Словарь формата <ID игрока> - <команда игрока>. Доступно только на сервере.
var players_teams: Dictionary[int, int]
## Словарь формата <ID игрока> - <объект игрока>.
var players: Dictionary[int, Player]
var _players_skill_vars: Dictionary[int, Array]

var _vibration_enabled: bool
var _queued_hits: Array[Hit]
var _hit_marker_scene: PackedScene = load("uid://c2f0n1b5sfpdh")
var _kill_marker_scene: PackedScene = load("uid://blhm6uka1p287")

## Ссылка на [EventUI].
@onready var _event_ui: EventUI = $UI


func _ready() -> void:
	Globals.main.menu_music.stream_paused = true
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		get_tree().process_frame.connect(_on_process_frame)
	
	_vibration_enabled = Globals.get_setting_bool("vibration")
	if not Globals.get_setting_bool("chat_in_game"):
		($UI/Main/Chat as CanvasItem).hide()
	
	var entities_spawner: MultiplayerSpawner = $EntitiesSpawner
	for scene: PackedScene in player_scenes:
		entities_spawner.add_spawnable_scene(scene.resource_path)
	var projectiles_spawner: MultiplayerSpawner = $ProjectilesSpawner
	for path: String in Globals.items_db.spawnable_projectiles_paths:
		projectiles_spawner.add_spawnable_scene(path)
	var other_spawner: MultiplayerSpawner = $OtherSpawner
	for path: String in Globals.items_db.spawnable_other_paths:
		other_spawner.add_spawnable_scene(path)
	
	_initialize()
	if multiplayer.is_server():
		_setup()
	
	_event_ui.show_intro()


func _exit_tree() -> void:
	Globals.main.menu_music.stream_paused = false


## Создаёт игрока с идентификатором [param id]. Если событие ещё не началось, то этот игрок будет
## обезоружен и обездвижен.
func spawn_player(id: int) -> void:
	var player: Player = _get_player_scene(id).instantiate()
	player.position = _get_spawn_point(id) + Vector2(
			randf_range(-spawn_point_randomness, spawn_point_randomness),
			randf_range(-spawn_point_randomness, spawn_point_randomness)
	)
	player.team = players_teams[id]
	player.id = id
	player.player_name = players_names[id]
	player.equip_data = players_equip_data[id].duplicate()
	player.equip_data.append(-1)
	if id in _players_skill_vars:
		player.skill_vars = _players_skill_vars[id].duplicate()
	player.name = "Player%d" % id
	_customize_player(player)
	players[id] = player
	$Entities.add_child(player)
	player.damaged.connect(_on_player_damaged)
	player.killed.connect(_on_player_killed)
	player.tree_exiting.connect(_on_player_tree_exiting.bind(player))
	if not was_started:
		player.block_weapon_usage()
		player.make_immobile()
		player.block_turning()


## Задаёт локального игрока.
func set_local_player(player: Player) -> void:
	local_player = player
	local_player_created.emit(player)
	set_local_team(player.team)
	
	if was_started:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 0.3)
	else:
		if not multiplayer.is_server():
			local_player.block_weapon_usage()
			local_player.make_immobile()
			local_player.block_turning()
		var offset: float = (Time.get_ticks_msec() - created_ticks_msec) / 1000.0
		($Camera as SmartCamera).pan_to_target(player.camera_target, maxf(4.0 - offset, 1.0))
		_event_ui.seek_intro(offset)


## Задаёт команду локального игрока.
func set_local_team(team: int) -> void:
	local_team = team
	local_team_set.emit(team)


## Заканчивает событие победой или поражением.
func end_event(victory: bool) -> void:
	($Music as AudioStreamPlayer).stop()
	if victory:
		($VictoryMusic as AudioStreamPlayer).play()
	else:
		($DefeatMusic as AudioStreamPlayer).play()


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


## Останавливает, обезоруживает и делает неуязвимыми всех игроков.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("reliable", "call_local", "authority", 3)
func freeze_players() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	get_tree().call_group(&"Player", &"block_weapon_usage")
	get_tree().call_group(&"Player", &"make_immobile")
	get_tree().call_group(&"Player", &"make_immune")
	get_tree().call_group(&"Player", &"block_turning")


## Заканчивает событие и возвращает в лобби.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 3)
func end() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	print_verbose("Event ended.")
	ended.emit()
	queue_free()


@rpc("call_local", "reliable", "authority", 3)
func _start() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if Globals.get_setting_bool("custom_tracks"):
		if not Globals.get_setting_bool("official_tracks"):
			tracks.clear()
		tracks.append_array(Globals.main.custom_tracks.values())
	if not tracks.is_empty():
		($Music as AudioStreamPlayer).stream = tracks.pick_random()
		($Music as AudioStreamPlayer).play()
	
	_finish_start()
	if multiplayer.is_server():
		get_tree().call_group(&"Player", &"unblock_weapon_usage")
		get_tree().call_group(&"Player", &"unmake_immobile")
		get_tree().call_group(&"Player", &"unblock_turning")
	else:
		local_player.unblock_weapon_usage()
		local_player.unmake_immobile()
		local_player.unblock_turning()
	started.emit()
	was_started = true
	
	print_verbose("Event started.")


@rpc("reliable", "call_local", "authority", 6)
func _register_hit(where: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if _vibration_enabled:
		Input.vibrate_handheld(HIT_VIBRATION_DURATION_MS, HIT_VIBRATION_INTENSITY)
	var marker: Node2D = _hit_marker_scene.instantiate()
	marker.position = where
	$Vfx.add_child(marker)


@rpc("reliable", "call_local", "authority", 6)
func _register_kill(where: Vector2) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if _vibration_enabled:
		Input.vibrate_handheld(KILL_VIBRATION_DURATION_MS, KILL_VIBRATION_INTENSITY)
	var marker: Node2D = _kill_marker_scene.instantiate()
	marker.position = where
	$Vfx.add_child(marker)


func _setup() -> void:
	_make_teams()
	_event_ui.chat.players_names = players_names
	_event_ui.chat.players_teams = players_teams
	for player_id: int in players_names:
		spawn_player(player_id)
	_finish_setup()
	
	await get_tree().create_timer(5.0 - (Time.get_ticks_msec() - created_ticks_msec)
			/ 1000.0, false).timeout
	_start.rpc()


## Метод для переопределения. Вызывается сразу после [method Node._ready] и на клиенте,
## и на сервере.
func _initialize() -> void:
	pass


## Метод для переопределения. В нём требуется заполнить [member players_teams].
## Вызывается только на сервере. Обязателен.
func _make_teams() -> void:
	pass


## Метод для переопределения. Вызывается после распределения команд и создания всех игроков,
## но только на сервере.
func _finish_setup() -> void:
	pass


## Метод для переопределения. Вызывается в момент старта события и на клиентах, и на сервере.
func _finish_start() -> void:
	pass


## Можно переопределить, чтобы возвращать другую сцену для определённого игрока. По умолчанию
## возвращает первую сцену в [member player_scenes].
func _get_player_scene(_id: int) -> PackedScene:
	return player_scenes[0]


## Метод для переопределения. Он должен возвращать позицию появления для игрока с идентификатором
## [param id]. Вызывается только на сервере. Обязателен.
func _get_spawn_point(_id: int) -> Vector2:
	return Vector2()


## Может быть переопределён для настройки игрока ДО добавления в сцену.
## Вызывается только на сервере.
func _customize_player(_player: Player) -> void:
	pass


## Метод для переопределения. Вызывается на сервере при убийстве игрока. В [param _who]
## содержится [member Entity.id] умершего игрока, в [param _by] - убийцы.
func _player_killed(_who: int, _by: int) -> void:
	pass


## Метод для переопределения. Вызывается на сервере при отключении игрока. В [param _who]
## содержится его [member Entity.id].
func _player_disconnected(_id: int) -> void:
	pass


func _on_player_damaged(who: int, by: int) -> void:
	if by in players:
		var hit_position: Vector2 = players[who].global_position
		if not _queued_hits.any(func(hit: Hit) -> bool:
				return hit.by == by and hit.where.is_equal_approx(hit_position)):
			_queued_hits.append(Hit.new(by, hit_position, false))


func _on_player_killed(who: int, by: int) -> void:
	var message_text: String
	if by > 0:
		message_text = "[outline_size=4][color=#%s]%s[/color][/outline_size] убивает игрока \
[outline_size=4][color=#%s]%s[/color][/outline_size]!" % [
			Entity.TEAM_COLORS[players_teams[by]].to_html(false),
			players_names[by],
			Entity.TEAM_COLORS[players_teams[who]].to_html(false),
			players_names[who],
		]
	else:
		message_text = "[outline_size=4][color=#%s]%s[/color][/outline_size] умирает!" % [
			Entity.TEAM_COLORS[players_teams[who]].to_html(false),
			players_names[who],
		]
	_event_ui.chat.post_message.rpc("> " + message_text)
	
	if by in players:
		var kill_position: Vector2 = players[who].global_position
		var should_add := true
		for hit: Hit in _queued_hits:
			if hit.by == by and hit.where.is_equal_approx(kill_position):
				hit.fatal = true
				should_add = false
				break
		if should_add:
			_queued_hits.append(Hit.new(by, kill_position, true))
	
	_player_killed(who, by)
	players.erase(who)


func _on_player_tree_exiting(player: Player) -> void:
	if not player.id in players_names:
		return
	players.erase(player.id)
	_players_skill_vars[player.id] = player.skill_vars


func _on_peer_disconnected(id: int) -> void:
	var message_text: String = "[outline_size=4][color=#%s]%s[/color][/outline_size] отключается!" \
			% [Entity.TEAM_COLORS[players_teams[id]].to_html(false), players_names[id]]
	_event_ui.chat.post_message.rpc("> " + message_text)
	if id in players:
		players[id].queue_free()
		players.erase(id)
	players_names.erase(id)
	players_equip_data.erase(id)
	players_teams.erase(id)
	_players_skill_vars.erase(id)
	if players_names.is_empty():
		end.rpc()
		return
	_player_disconnected(id)


func _on_process_frame() -> void:
	for hit: Hit in _queued_hits:
		if hit.fatal:
			_register_kill.rpc_id(hit.by, hit.where)
		else:
			_register_hit.rpc_id(hit.by, hit.where)
	_queued_hits.clear()


func _on_entities_spawner_spawned(node: Node) -> void:
	var player := node as Player
	if player:
		players[player.id] = player


func _on_entities_spawner_despawned(node: Node) -> void:
	var player := node as Player
	if player:
		players.erase(player.id)


class Hit:
	var by: int
	var where: Vector2
	var fatal: bool
	
	func _init(by_value: int, where_value: Vector2, fatal_value: bool) -> void:
		by = by_value
		where = where_value
		fatal = fatal_value
