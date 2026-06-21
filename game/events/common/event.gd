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
## Массив эмоций, которые может отправить игрок.
@export var emotions: Array[Texture2D]

## Данные об этом событии.
var data: EventData
## Слварь параметров этого события.
var parameters: Dictionary[String, int]
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

var _emotion_cloud_scene: PackedScene = load("uid://bkyhxor5s6032")

## Ссылка на [EventUI].
@onready var event_ui: EventUI = $UI

@onready var _event_timer: Timer = $EventTimer


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
		var offset: float = (Time.get_ticks_msec() - created_ticks_msec) / 1000.0
		($Camera as SmartCamera).pan_to_target(player.camera_target, maxf(4.0 - offset, 1.0))
		event_ui.seek_intro(offset)


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
	$Entities.add_child(player, true)
	player.killed.connect(_on_player_killed.bind(player))
	player.tree_exiting.connect(_on_player_tree_exiting.bind(player))


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


## Возвращает информацию о событии (его имя и состояние: оставшееся время, живые игроки, ...).
func get_event_info() -> String:
	return "%s, %s" % [data.name, _get_event_status() if was_started else "начало"]


## Отправляет эмоцию в соответствии с данным индексом [param idx].
func send_emotion(idx: int) -> void:
	if not is_instance_valid(local_player):
		return
	_request_send_emotion.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, idx)


@rpc("call_local", "reliable", "authority", 3)
func _start() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if not tracks.is_empty():
		($Music as AudioStreamPlayer).stream = tracks.pick_random()
		($Music as AudioStreamPlayer).play()
	
	_finish_start()
	get_tree().call_group(&"entity", &"unmake_disarmed")
	get_tree().call_group(&"entity", &"unmake_immobile")
	get_tree().call_group(&"entity", &"unmake_immune")
	get_tree().call_group(&"entity", &"unblock_turning")
	
	started.emit()
	was_started = true
	print_verbose("Event started.")


@rpc("call_local", "reliable", "any_peer", 3)
func _request_send_emotion(idx: int) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in players:
		push_warning("Player %d tried to send emotion while not alive." % sender_id)
		return
	if idx < 0 or idx >= emotions.size():
		push_warning("Player %d tried to send emotion with invalid index %d." % [sender_id, idx])
		return
	
	_show_emotion.rpc(sender_id, idx)


@rpc("call_local", "reliable", "authority", 3)
func _show_emotion(player_id: int, idx: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	if not Globals.get_setting_bool("chat_in_game"):
		return
	if not player_id in players:
		push_warning("Can't show emotion on nonexistent player %d." % player_id)
		return
	
	var player: Player = players[player_id]
	var emotion_cloud: Node2D = _emotion_cloud_scene.instantiate()
	var old_emotion_cloud: Node2D = player.get_node_or_null(NodePath(emotion_cloud.name))
	if is_instance_valid(old_emotion_cloud):
		old_emotion_cloud.name += "Old"
		old_emotion_cloud.queue_free()
	(emotion_cloud.get_node(^"%Emotion") as Sprite2D).texture = emotions[idx]
	player.add_child(emotion_cloud)
	
	print_verbose("Showed emotion %d on player %d." % [idx, player_id])


func _setup() -> void:
	_make_teams()
	event_ui.chat.players_names = players_names
	event_ui.chat.players_teams = players_teams
	for player_id: int in players_names:
		spawn_player(player_id)
	_finish_setup()
	
	_event_timer.start(5.0 - (Time.get_ticks_msec() - created_ticks_msec) / 1000.0)
	await _event_timer.timeout
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


## Метод для переопределения. Должен возвращать статус события (живые игроки, оставшееся время)
## с маленькой буквы.
func _get_event_status() -> String:
	return ""


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


func _on_entities_child_entered_tree(node: Node) -> void:
	super(node)
	if was_started:
		return
	var entity := node as Entity
	if entity:
		entity.make_disarmed()
		entity.make_immobile()
		entity.make_immune()
		entity.block_turning()
