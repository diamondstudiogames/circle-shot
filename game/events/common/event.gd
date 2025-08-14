class_name Event
extends World

## Основной узел события.
##
## Базовый класс для всех событий в игре. Доступ к нему можно получить через
## [member Game.world] (только для неигровой части) или через
## [code](get_tree().get_first_node_in_group(&"world") as Event)[/code].

## Издаётся, когда событие началось (т. е. после вызова [method _finish_start]).
signal started
## Издаётся, когда событие закончилось.
signal ended

## Определяет максимум случайного расстояния от заданной точки появления.
@export var spawn_point_randomness := 40.0

## Началось ли событие.
var was_started := false
## Количество тиков в момент создания события. Используется для корректировки анимации начала.
var created_ticks_msec: int
## Словарь формата <ID игрока> - <массив данных об экипировке> (см. [member Player.equip_data]).
var players_equip_data: Dictionary[int, Array]
## Словарь формата <ID игрока> - <имя игрока>.
var players_names: Dictionary[int, String]
## Словарь формата <ID игрока> - <команда игрока>. Доступно только на сервере.
var players_teams: Dictionary[int, int]

var _players_skill_vars: Dictionary[int, Array]

## Ссылка на [EventUI].
@onready var event_ui: EventUI = $UI


func _ready() -> void:
	super()
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_setup()
	event_ui.show_intro()


func _local_player_created(player: Player) -> void:
	if was_started:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 0.3)
	else:
		if not multiplayer.is_server():
			local_player.block_weapon_usage()
			local_player.make_immobile()
			local_player.block_turning()
		var offset: float = (Time.get_ticks_msec() - created_ticks_msec) / 1000.0
		($Camera as SmartCamera).pan_to_target(player.camera_target, maxf(4.0 - offset, 1.0))
		event_ui.seek_intro(offset)


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
	$Entities.add_child(player)
	player.killed.connect(_on_player_killed.bind(player))
	player.tree_exiting.connect(_on_player_tree_exiting.bind(player))
	if not was_started:
		player.block_weapon_usage()
		player.make_immobile()
		player.block_turning()


## Останавливает, обезоруживает и делает неуязвимыми всех игроков.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("reliable", "call_local", "authority", 3)
func freeze_players() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	get_tree().call_group(&"player", &"block_weapon_usage")
	get_tree().call_group(&"player", &"make_immobile")
	get_tree().call_group(&"player", &"make_immune")
	get_tree().call_group(&"player", &"block_turning")


## Останавливает, обезоруживает и делает неуязвимыми все сущности.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("reliable", "call_local", "authority", 3)
func freeze_entities() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	get_tree().call_group(&"entity", &"make_disarmed")
	get_tree().call_group(&"entity", &"make_immobile")
	get_tree().call_group(&"entity", &"make_immune")
	get_tree().call_group(&"entity", &"block_turning")


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


## Заканчивает событие победой или поражением.
func end_event(victory: bool) -> void:
	($Music as AudioStreamPlayer).stop()
	if victory:
		($VictoryMusic as AudioStreamPlayer).play()
	else:
		($DefeatMusic as AudioStreamPlayer).play()
	
	if not Globals.headless:
		# Ждём пока вся информация прилетит
		($ShowRewardsTimer as Timer).start()
		await ($ShowRewardsTimer as Timer).timeout
		
		var rewards: Dictionary[String, int] = _get_rewards()
		var coins_got: int = rewards.values().reduce(
				func(accum: int, num: int) -> int: return accum + num)
		Globals.set_int("coins", Globals.get_int("coins") + coins_got)
		
		event_ui.show_rewards(rewards, coins_got)


@rpc("call_local", "reliable", "authority", 3)
func _start() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if not tracks.is_empty():
		($Music as AudioStreamPlayer).stream = tracks.pick_random()
		($Music as AudioStreamPlayer).play()
	
	_finish_start()
	if multiplayer.is_server():
		get_tree().call_group(&"player", &"unblock_weapon_usage")
		get_tree().call_group(&"player", &"unmake_immobile")
		get_tree().call_group(&"player", &"unblock_turning")
	else:
		local_player.unblock_weapon_usage()
		local_player.unmake_immobile()
		local_player.unblock_turning()
	started.emit()
	was_started = true
	
	print_verbose("Event started.")


func _setup() -> void:
	_make_teams()
	event_ui.chat.players_names = players_names
	event_ui.chat.players_teams = players_teams
	for player_id: int in players_names:
		spawn_player(player_id)
	_finish_setup()
	
	await get_tree().create_timer(5.0 - (Time.get_ticks_msec() - created_ticks_msec)
			/ 1000.0, false).timeout
	_start.rpc()


## Метод для переопределения. В нём требуется заполнить [member players_teams]. Он может быть уже
## заранее частично заполненным, если в [EventData] этого события [member EventData.team_event]
## равен [code]true[/code].[br]
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
	return entity_scenes[0]


## Метод для переопределения. Он должен возвращать позицию появления для игрока с идентификатором
## [param id]. Вызывается только на сервере. Обязателен.
func _get_spawn_point(_id: int) -> Vector2:
	return Vector2()


## Может быть переопределён для настройки игрока ДО добавления в сцену.
## Вызывается только на сервере.
func _customize_player(_player: Player) -> void:
	pass


## Метод для переопределения. Вызывается на сервере при убийстве игрока. В [param _player]
## содержится объект умершего игрока, в [param _by] - ID убийцы.
func _player_killed(_by: int, _player: Player) -> void:
	pass


## Метод для переопределения. Вызывается на сервере при отключении игрока. В [param _id]
## содержится его ID.
func _player_disconnected(_id: int) -> void:
	pass


## Метод для переопределения. Вызывается и на сервере и на клиенте. Должен вернуть словарь,
## где ключи - строки с причиной награды, а значения - размер награды в монетах.
func _get_rewards() -> Dictionary[String, int]:
	return {}


func _on_player_killed(by: int, _remained_health: int, player: Player) -> void:
	var message_text: String
	if by > 0:
		message_text = "[outline_size=4][color=#%s]%s[/color][/outline_size] убивает игрока \
[outline_size=4][color=#%s]%s[/color][/outline_size]!" % [
			Entity.TEAM_COLORS[players_teams[by]].to_html(false),
			players_names[by],
			Entity.TEAM_COLORS[players_teams[player.id]].to_html(false),
			players_names[player.id],
		]
	else:
		message_text = "[outline_size=4][color=#%s]%s[/color][/outline_size] умирает!" % [
			Entity.TEAM_COLORS[players_teams[player.id]].to_html(false),
			players_names[player.id],
		]
	event_ui.chat.post_message.rpc("> " + message_text)
	_player_killed(by, player)


func _on_player_tree_exiting(player: Player) -> void:
	if not player.id in players_names:
		return
	_players_skill_vars[player.id] = player.skill_vars


func _on_peer_disconnected(id: int) -> void:
	var message_text: String = "[outline_size=4][color=#%s]%s[/color][/outline_size] отключается!" \
			% [Entity.TEAM_COLORS[players_teams[id]].to_html(false), players_names[id]]
	event_ui.chat.post_message.rpc("> " + message_text)
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
