class_name Game
extends Node

## Главный класс игровой части.
##
## Управляет сетью и переходами между состояниями игры. 

## Издаётся при создании комнаты.
signal created
## Издаётся при успешном подключении к игре.
signal joined
## Издаётся при закрытии игры.
signal closed
## Издаётся при успешном старте игры.
signal started
## Издаётся при окончании игры.
signal ended
## Перечисление причин отклонения подключения.
enum FailReason {
	## Разные версии.
	DIFFERENT_VERSION = 1,
	## Полная комната.
	FULL_ROOM = 2,
	## Уже в игре.
	IN_GAME = 3,
	## Игрок забанен.
	BANNED = 4,
}
## Перечисление состояний игры.
enum State {
	## Игра закрыта.
	CLOSED = 0,
	## Подключение.
	CONNECTING = 1,
	## Подключено, в лобби.
	LOBBY = 2,
	## Подключено, загрузка игры.
	LOADING = 3,
	## Подключено, находится в событии.
	EVENT = 4,
	## Одиночная игра, загрузка.
	SOLO_LOADING = 5,
	## Одиночная игра.
	SOLO = 6,
}
## Порт для подключения по умолчанию.
const DEFAULT_PORT: int = 7415
## Порт, через который ищутся игры по локальной сети.
const LISTEN_PORT: int = 7414
## Базовое время, определяющее через сколько соединение должно быть прервано (в мс).
## За подробностями - [method ENetPacketPeer.set_timeout].
const BASE_TIMEOUT: int = 2000
## Максимальное число клиентов. Используется при создании сервера.
const MAX_CLIENTS: int = 11 # Ещё один чтобы успешно отклонять.
## Максимальная длина имени игрока.
const MAX_PLAYER_NAME_LENGTH: int = 24
## Список префиксов локальных IP-адресов.
const LOCAL_IP_PREFIXES: Array[String] = [
	"192.168.",
	"10.",
]

## Максимальное число игроков, превысив которое сервер начнёт отклонять соединения.
## Задаётся лобби на основе выбранного события. Не имеет эффекта на клиентах.
var max_players: int = 10
## Текущее состояние игры.
var state := State.CLOSED
## Ссылка на мир.
var world: World
## IP-адреса заблокированных игроков. Не имеет эффекта на клиентах.
## Сбрасывается после смены админа.
var banned_ips: Array[String]

var _scene_multiplayer: SceneMultiplayer

var _players_names: Dictionary[int, String]
var _players_teams: Dictionary[int, int]
var _players_equip_data: Dictionary[int, Array]

var _preloading_equip := false
var _players_not_ready: Array[int]
@onready var _loader: Loader = $Loader


func _ready() -> void:
	_scene_multiplayer = multiplayer
	_scene_multiplayer.auth_callback = _authenticate_callback
	if Globals.console:
		Globals.console.command_processors.append(_process_console_command)
		Globals.console.help_processors.append(_print_help)


func _physics_process(_delta: float) -> void:
	# Проверка на неожиданные отключения
	if multiplayer.has_multiplayer_peer() \
			and multiplayer.multiplayer_peer.get_connection_status() \
			!= MultiplayerPeer.CONNECTION_CONNECTED \
			and not state in [State.CONNECTING, State.CLOSED]:
		push_warning("Peer disconnected, closing.")
		close()
	
	multiplayer.poll()


func _exit_tree() -> void:
	if Globals.console:
		Globals.console.command_processors.erase(_process_console_command)
		Globals.console.help_processors.erase(_print_help)
	# Очистка на всякий случай
	if multiplayer.has_multiplayer_peer():
		close()


## Инициализирует меню подключения к локальной игре и лобби.
func init_connect_local() -> void:
	var menu_scene: PackedScene = load("uid://wgln4clkkuuk")
	var menu: Control = menu_scene.instantiate()
	add_child(menu)
	print_verbose("Created connect local menu.")
	_init_lobby()


## Инициализирует меню одиночной игры.
func init_solo() -> void:
	var menu_scene: PackedScene = load("uid://behtxlo4s5s3")
	var menu: Control = menu_scene.instantiate()
	add_child(menu)
	print_verbose("Created solo menu.")


## Создаёт сервер.
func create(port: int = DEFAULT_PORT) -> void:
	if state != State.CLOSED:
		push_error("Can't create server: game isn't closed.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		show_error("Невозможно создать сервер! Ошибка: %s" % error_string(error))
		push_error("Can't create server with error: %s." % error_string(error))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_scene_multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	_scene_multiplayer.peer_authentication_failed.connect(_on_peer_authentication_failed)
	state = State.LOBBY
	created.emit()
	print_verbose("Created server at port %d." % port)


## Пытается подключиться к серверу по [param address].
func join(address: String, port: int = DEFAULT_PORT) -> void:
	if state != State.CLOSED:
		push_error("Can't join to server: game isn't closed.")
		return
	if not Utils.is_valid_address(address, true):
		show_error("Введён некорректный адрес сервера!")
		return
	
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)
	if error != OK:
		show_error("Невозможно начать подключение! Ошибка: %s" % error_string(error))
		push_warning("Can't initiate connection with error: %s." % error_string(error))
		return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		show_error("Невозможно начать подключение!")
		push_warning("Can't initiate connection.")
		return
	
	# Уменьшаем время тайм-аута
	peer.get_peer(MultiplayerPeer.TARGET_PEER_SERVER).set_timeout(
			BASE_TIMEOUT, BASE_TIMEOUT * 2, BASE_TIMEOUT * 3)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	_scene_multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	_scene_multiplayer.peer_authentication_failed.connect(_on_peer_authentication_failed)
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	
	($ConnectingDialog as AcceptDialog).dialog_text = "Подключение к %s..." % address
	($ConnectingDialog as Window).popup_centered(Vector2i.ONE)
	print_verbose("Connecting to %s..." % address)


## Закрывает игру.
func close() -> void:
	if state == State.CLOSED:
		push_error("Can't close because game is already closed.")
		return
	
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if _scene_multiplayer.peer_authenticating.is_connected(_on_peer_authenticating):
		_scene_multiplayer.peer_authenticating.disconnect(_on_peer_authenticating)
	if _scene_multiplayer.peer_authentication_failed.is_connected(_on_peer_authentication_failed):
		_scene_multiplayer.peer_authentication_failed.disconnect(_on_peer_authentication_failed)
	
	multiplayer.multiplayer_peer.close()
	multiplayer.set_deferred(&"multiplayer_peer", null)
	if is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_DISABLED # Чтобы _process не вызывались
		world.queue_free()
		print_verbose("Event deleted.")
	
	if state != State.CONNECTING: # Комната ещё не создана, нечего закрывать
		state = State.CLOSED # Не можем установить раньше - перезапишем текущее
		closed.emit()
	state = State.CLOSED
	print_verbose("Closed.")


## Загружает событие по данным [param event_idx] и [param map_idx]. Если вызвано сервером
## без игрока, [param player_name] и [param equip_data] можно не указывать.
func load_event(event_idx: int, map_idx: int, player_name := "",
		equip_data: Array[int] = []) -> void:
	state = State.LOADING
	if multiplayer.is_server():
		_preloading_equip = false
		_players_not_ready.assign(multiplayer.get_peers())
		_players_not_ready.append(1)
		_players_equip_data.clear()
		_players_names.clear()
		($WaitPlayersTimer as Timer).start()
	world = await _loader.load_event(event_idx, map_idx)
	if not is_instance_valid(world):
		show_error("Ошибка при загрузке события! Отключаюсь.")
		push_error("Loading failed. Disconnecting.")
		if state != State.CLOSED:
			close()
		return
	closed.connect(_loader.finish_load.bind(false), CONNECT_ONE_SHOT)
	if multiplayer.is_server() and Globals.headless:
		_players_not_ready.erase(MultiplayerPeer.TARGET_PEER_SERVER)
		_check_players_ready()
		return
	print_verbose("Sending data. Name: %s, equip data: %s." % [player_name, str(equip_data)])
	_send_player_data.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, player_name, equip_data)


## Устанавливает команды игроков. Должно вызываться только на сервере.
func set_players_teams(players_teams: Dictionary[int, int]) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	_players_teams.clear()
	for id: int in players_teams:
		if players_teams[id] >= 0:
			_players_teams[id] = players_teams[id]


## Загружает мир по данному [param path].
func load_solo_world(path: String) -> void:
	state = State.SOLO_LOADING
	world = await _loader.load_world(path)
	if not is_instance_valid(world):
		show_error("Ошибка при загрузке мира!")
		push_error("Loading failed.")
		state = State.CLOSED
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	add_child(world)
	_loader.finish_load(true)
	started.emit()
	state = State.SOLO


## Загружает испытание по данному [param challenge_idx] и [param map_idx].
func load_challenge(challenge_idx: int, map_idx: int, equip_data: Array[int] = []) -> void:
	state = State.SOLO_LOADING
	world = await _loader.load_challenge(challenge_idx, map_idx)
	if not is_instance_valid(world):
		show_error("Ошибка при загрузке испытания!")
		push_error("Loading failed.")
		state = State.CLOSED
		return
	
	var equip_scenes: Array[PackedScene] = await _loader.preload_equip(
			equip_data.slice(0, 1), equip_data.slice(1, 2), equip_data.slice(2))
	if equip_scenes.is_empty():
		show_error("Ошибка при предзагрузке экипировки!")
		push_error("Preload equip failed.")
		state = State.CLOSED
		world.queue_free()
		return
	world.cached_resources.append_array(equip_scenes)
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	add_child(world)
	_loader.finish_load(true)
	started.emit()
	state = State.SOLO


## Показывает диалог с ошибкой.
func show_error(error_text: String) -> void:
	($ErrorDialog as AcceptDialog).dialog_text = error_text
	($ErrorDialog as AcceptDialog).popup_centered(Vector2i.ONE)


@rpc("any_peer", "reliable", "call_local", 1)
func _send_player_data(player_name: String, equip_data: Array[int]) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in _players_not_ready:
		push_warning("Equip data from client %d already received." % sender_id)
		return
	
	var default_equip_data: Array[int] = [
		Globals.items_db.skins_by_id[Globals.items_db.default_skin].idx_in_db,
		Globals.items_db.skills_by_id[Globals.items_db.default_skill].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.items_db.default_light_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.items_db.default_heavy_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.items_db.default_support_weapon].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.items_db.default_melee_weapon].idx_in_db,
	]
	
	player_name = Utils.validate_player_name(player_name, sender_id)
	if equip_data.size() != 6:
		push_warning("Client %d has invalid equip data size: %d." % [
			sender_id,
			equip_data.size(),
		])
		equip_data = default_equip_data
	
	if equip_data[0] < 0 or equip_data[0] >= Globals.items_db.skins.size() \
			or Globals.items_db.skins[equip_data[0]] in Globals.items_db.other_skins:
		push_warning("Client's %d skin has invalid idx: %d." % [sender_id, equip_data[0]])
		equip_data[0] = default_equip_data[0]
	if equip_data[1] < 0 or equip_data[1] >= Globals.items_db.skills.size() \
			or Globals.items_db.skills[equip_data[1]] in Globals.items_db.other_skills:
		push_warning("Client's %d skill has invalid idx: %d." % [sender_id, equip_data[1]])
		equip_data[1] = default_equip_data[1]
	
	if equip_data[2] < 0 or equip_data[2] >= Globals.items_db.weapons.size() \
			or not Globals.items_db.weapons[equip_data[2]] in Globals.items_db.weapons_light:
		push_warning("Client's %d light weapon has invalid idx: %d." % [sender_id, equip_data[2]])
		equip_data[2] = default_equip_data[2]
	if equip_data[3] < 0 or equip_data[3] >= Globals.items_db.weapons.size() \
			or not Globals.items_db.weapons[equip_data[3]] in Globals.items_db.weapons_heavy:
		push_warning("Client's %d heavy weapon has invalid idx: %d." % [sender_id, equip_data[3]])
		equip_data[3] = default_equip_data[3]
	if equip_data[4] < 0 or equip_data[4] >= Globals.items_db.weapons.size() \
			or not Globals.items_db.weapons[equip_data[4]] in Globals.items_db.weapons_support:
		push_warning("Client's %d support weapon has invalid idx: %d." % [sender_id, equip_data[4]])
		equip_data[4] = default_equip_data[4]
	if equip_data[5] < 0 or equip_data[5] >= Globals.items_db.weapons.size() \
			or not Globals.items_db.weapons[equip_data[5]] in Globals.items_db.weapons_melee:
		push_warning("Client's %d melee weapon has invalid idx: %d." % [sender_id, equip_data[5]])
		equip_data[5] = default_equip_data[5]
	
	_players_names[sender_id] = player_name
	_players_equip_data[sender_id] = equip_data
	_players_not_ready.erase(sender_id)
	print_verbose("Player %d sent data. Name: %s, equip data: %s." % [
		sender_id,
		player_name,
		str(equip_data),
	])
	_check_players_ready()


@rpc("call_local", "reliable", "authority", 1)
func _preload_equip(skins: Array[int], skills: Array[int], weapons: Array[int]) -> void:
	closed.disconnect(_loader.finish_load)
	if multiplayer.is_server():
		_preloading_equip = true
		_players_not_ready.assign(multiplayer.get_peers())
		_players_not_ready.append(1)
	var equip_scenes: Array[PackedScene] = await _loader.preload_equip(skins, skills, weapons)
	if equip_scenes.is_empty():
		show_error("Ошибка при предзагрузке экипировки! Отключаюсь.")
		push_error("Preload equip failed. Disconnecting.")
		if state != State.CLOSED:
			close()
		return
	world.cached_resources.append_array(equip_scenes)
	closed.connect(_loader.finish_load.bind(false), CONNECT_ONE_SHOT)
	if multiplayer.is_server() and Globals.headless:
		_players_not_ready.erase(MultiplayerPeer.TARGET_PEER_SERVER)
		_check_players_ready()
		return
	_send_ready.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


@rpc("any_peer", "reliable", "call_local", 1)
func _send_ready() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	print_verbose("Player %d done loading." % sender_id)
	_players_not_ready.erase(sender_id)
	_check_players_ready()


@rpc("call_local", "reliable", "authority") # нулевой канал чтобы заспавнились игроки корректно
func _start_event(players_names: Dictionary[int, String],
		players_equip_data: Dictionary[int, Array]) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	print_verbose("Starting event...")
	closed.disconnect(_loader.finish_load)
	var event: Event = world
	event.ended.connect(_on_event_ended)
	event.players_names = players_names
	event.players_equip_data = players_equip_data
	if multiplayer.is_server():
		event.players_teams = _players_teams.duplicate()
		_players_teams.clear()
	event.created_ticks_msec = Time.get_ticks_msec()
	add_child(event)
	_loader.finish_load(true)
	started.emit()
	state = State.EVENT
	print_verbose("Event loaded. Starting...")


func _check_players_ready() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	print_verbose("Waiting for players: %s." % str(_players_not_ready))
	if _players_not_ready.is_empty():
		if not _players_names.is_empty():
			if _preloading_equip:
				($WaitPlayersTimer as Timer).stop()
				_start_event.rpc(_players_names.duplicate(), _players_equip_data.duplicate())
				_players_names.clear()
				_players_equip_data.clear()
			else:
				_determine_equip_to_preload()
		else:
			print_verbose("All players disconnected, returning to lobby.")
			closed.disconnect(_loader.finish_load)
			_loader.finish_load(true)
			world.queue_free()
			# Как будто всё хорошо
			started.emit()
			ended.emit()
			state = State.LOBBY


func _determine_equip_to_preload() -> void:
	var skins: Array[int]
	var skills: Array[int]
	var weapons: Array[int]
	
	for equip_data: Array in _players_equip_data.values():
		if not equip_data[0] in skins:
			skins.append(equip_data[0])
		if not equip_data[1] in skills:
			skills.append(equip_data[1])
		if not equip_data[2] in weapons:
			weapons.append(equip_data[2])
		if not equip_data[3] in weapons:
			weapons.append(equip_data[3])
		if not equip_data[4] in weapons:
			weapons.append(equip_data[4])
		if not equip_data[5] in weapons:
			weapons.append(equip_data[5])
	
	_preload_equip.rpc(skins, skills, weapons)


func _init_lobby() -> void:
	var lobby_scene: PackedScene = load("uid://cmwb81du1kbtm")
	var lobby: Control = lobby_scene.instantiate()
	add_child(lobby)
	print_verbose("Created lobby.")


func _process_console_command(command: PackedStringArray) -> bool:
	var recognized := false
	if command[0] == "close" and command.size() == 1:
		recognized = true
		close()
	elif command[0] == "create" and command.size() < 3:
		recognized = true
		if command.size() == 1:
			create()
		else:
			create(int(command[1]))
	elif command[0] == "join" and command.size() > 1 and command.size() < 4:
		recognized = true
		if command.size() == 2:
			join(command[1])
		else:
			join(command[1], int(command[2]))
	elif command[0] == "unban" and command.size() == 2:
		if not multiplayer.is_server():
			printerr("This command only available on server.")
			return recognized
		recognized = true
		banned_ips.erase(command[1])
	elif command[0] == "unban-all" and command.size() == 1:
		if not multiplayer.is_server():
			printerr("This command only available on server.")
			return recognized
		recognized = true
		banned_ips.clear()
	return recognized


func _print_help() -> void:
	print("close - Closes server or client.")
	print("join <address> [port] - Joins server by address and port.")
	print("create [port] - Creates server at specified port.")
	print("unban <ip> - Unbans player with specified IP. Only available on server.")
	print("unban-all - Unbans all players. Only available on server.")


func _authenticate_callback(peer: int, data: PackedByteArray) -> void:
	if not peer in _scene_multiplayer.get_authenticating_peers():
		push_warning("Unexpected authenticating message: peer %d is not authenticating." % peer)
		return
	
	if not multiplayer.is_server():
		if peer != MultiplayerPeer.TARGET_PEER_SERVER:
			push_warning("Unexpected authenticating message. Peer: %d." % peer)
			return
		if data.is_empty():
			push_error("Invalid data received: data is empty.")
			return
		match data[0]:
			OK:
				_scene_multiplayer.complete_auth(peer)
				return
			FailReason.DIFFERENT_VERSION:
				($ConnectingDialog as Window).hide()
				show_error("Невозможно подключиться! \
Версия сервера (%s) не совпадает с твоей (%s)." % [
					data.slice(1).get_string_from_utf8(),
					Globals.version,
				])
				push_warning("Can't connect: different versions (%s - local and %s - server)." % [
					Globals.version,
					data.slice(1).get_string_from_utf8(),
				])
			FailReason.FULL_ROOM:
				($ConnectingDialog as Window).hide()
				show_error("Невозможно подключиться! Комната уже заполнена.")
				push_warning("Can't connect: full room.")
			FailReason.IN_GAME:
				($ConnectingDialog as Window).hide()
				show_error("Невозможно подключиться! Игра уже началась.")
				push_warning("Can't connect: game already started.")
			FailReason.BANNED:
				($ConnectingDialog as Window).hide()
				show_error("Невозможно подключиться! Ты забанен в этой комнате.")
				push_warning("Can't connect: banned.")
			_:
				push_error("Invalid data received: data is not AuthState.")
		close()
		return
	
	if data != Globals.version.to_utf8_buffer():
		_scene_multiplayer.send_auth(peer,
				PackedByteArray([FailReason.DIFFERENT_VERSION]) + Globals.version.to_utf8_buffer())
		print_verbose("Rejecting %d: different version (%s - local, %s - client)." % [
			peer,
			Globals.version,
			data.get_string_from_utf8(),
		])
		return
	if (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer).get_remote_address() \
			in banned_ips:
		_scene_multiplayer.send_auth(peer, PackedByteArray([FailReason.BANNED]))
		print_verbose("Rejecting %d: banned." % peer)
		return
	if multiplayer.get_peers().size() + int(not Globals.headless) + 1 > max_players \
			and Globals.get_setting_bool("reject_players"):
		_scene_multiplayer.send_auth(peer, PackedByteArray([FailReason.FULL_ROOM]))
		print_verbose("Rejecting %d: full room." % peer)
		return
	if state != State.LOBBY:
		_scene_multiplayer.send_auth(peer, PackedByteArray([FailReason.IN_GAME]))
		print_verbose("Rejecting %d: already in game." % peer)
		return
	
	_scene_multiplayer.send_auth(peer, PackedByteArray([OK]))
	_scene_multiplayer.complete_auth(peer)
	print_verbose("Completing authentication for peer %d." % peer)


func _on_peer_authenticating(peer: int) -> void:
	if multiplayer.is_server():
		print_verbose("Authenticating peer %d." % peer)
		return
	if peer != MultiplayerPeer.TARGET_PEER_SERVER:
		push_warning("Unexpected authenticating message! Peer: %d" % peer)
		return
	
	var data: PackedByteArray = Globals.version.to_utf8_buffer()
	_scene_multiplayer.send_auth(peer, data)
	($ConnectingDialog as AcceptDialog).dialog_text = "Аутентификация..."
	print_verbose("Sending version... (%s)" % Globals.version)


func _on_peer_authentication_failed(peer: int) -> void:
	if multiplayer.is_server():
		print_verbose("Peer authentication failed: %d." % peer)
		return
	
	($ConnectingDialog as Window).hide()
	close()
	show_error("Невозможно аутентифицироваться!")
	push_warning("Authentication failed for peer %d." % peer)


func _on_connected_to_server() -> void:
	($ConnectingDialog as Window).hide()
	multiplayer.connection_failed.disconnect(_on_connection_failed)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	state = State.LOBBY
	joined.emit()
	print_verbose("Connected to server.")


func _on_connection_failed() -> void:
	($ConnectingDialog as Window).hide()
	close()
	show_error("Невозможно подключиться к серверу!")
	push_warning("Connection failed.")


func _on_peer_connected(id: int) -> void:
	# Уменьшаем время тайм-аута
	(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id).set_timeout(
			BASE_TIMEOUT, BASE_TIMEOUT * 2, BASE_TIMEOUT * 3)
	print_verbose("Peer connected: %d." % id)


func _on_peer_disconnected(id: int) -> void:
	if id in _players_names:
		_players_names.erase(id)
		_players_equip_data.erase(id)
		_players_teams.erase(id)
	if id in _players_not_ready:
		_players_not_ready.erase(id)
		_check_players_ready()
	print_verbose("Peer disconnected: %d." % id)


func _on_server_disconnected() -> void:
	close()
	show_error("Разорвано соединение с сервером!")
	push_warning("Disconnected from server.")


func _on_event_ended() -> void:
	ended.emit()
	state = State.LOBBY


func _on_wait_players_timer_timeout() -> void:
	if MultiplayerPeer.TARGET_PEER_SERVER in _players_not_ready:
		($WaitPlayersTimer as Timer).start()
		return
	for id: int in _players_not_ready.duplicate(): # чтобы корректно итерировать
		push_warning("Disconnecting peer %d for inactivity." % id)
		_scene_multiplayer.disconnect_peer(id)
		multiplayer.peer_disconnected.emit(id)
