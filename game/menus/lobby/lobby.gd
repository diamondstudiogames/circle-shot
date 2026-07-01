class_name Lobby
extends Control

## Лобби игры.
##
## Здесь игрок выбирает событие и карту, оружие, скин и навык, а также
## общается с другими игроками.[br]
## [b]Внимание[/b]: после изменения свойств [code]selected_*[/code] нужно обновить отображаемые
## иконки с помощью [method update_selected].

## Издаётся, когда изменяется админ комнаты.
signal admin_changed
## Издаётся, когда меняются параметры окружения (карта, событие, параметры).
signal environment_changed

## Причина, по которой запрос на старт игры был отклонён.
enum StartRejectReason {
	## Всё ОК.
	OK = 0,
	## Слишком мало игроков.
	TOO_FEW_PLAYERS = 1,
	## Слишком много игроков.
	TOO_MANY_PLAYERS = 2,
	## Количеситво игроков не делится на значение, указанное в текущем событии.
	INDIVISIBLE_NUMBER_OF_PLAYERS = 3,
	## Команды разделены неправильно (игроков одной команды больше другой).
	BAD_TEAMS = 4,
}
## Перечисление действий админа.
enum AdminAction {
	## Выгнать из комнаты.
	KICK = 0,
	## Выгнать из комнаты и забанить по IP-адресу.
	BAN = 1,
	## Передать права админа.
	TRANSFER_ADMIN_RIGHTS = 2,
}
## Перечисление действий с командами.
enum TeamAction {
	## Добавить игрока в красную команду.
	RED_TEAM = 0,
	## Добавить игрока в синюю команду.
	BLUE_TEAM = 1,
	## Убрать игрока из команды.
	REMOVE_TEAM = 2,
}

## Выбранное событие.
var selected_event: int
## Выбранная карта. Не сохраняется, используется только для хранения текущего состояния комнаты.
var selected_map: int
## Массив с выбранными картами для определённых событий, где индекс - ID события.
var selected_maps: Array[int]
## Параметры для выбранного события. Не сохраняется, используется только для хранения
## текущего состояния комнаты.
var selected_event_parameters: Dictionary[String, int]
## Массив с выбранными параметрами для определённых событий, где индекс - ID события.
var selected_events_parameters: Array[Dictionary]
## Модификаторы для выбранного события. Не сохраняется, используется только для хранения
## текущего состояния комнаты.
var selected_event_modifiers: Array[int]
## Массив с выбранными параметрами для определённых событий, где индекс - ID события.
var selected_events_modifiers: Array[Array]

## Словарь с подключёнными игроками в формате <ID игрока> - <имя игрока>.
## Доступно только на сервере.
var players: Dictionary[int, String]
## Словарь с подключёнными игроками в формате <ID игрока> - <команда игрока>.
## Доступно только на сервере.
var players_teams: Dictionary[int, int]
## Идентификатор админа.
var admin_id: int = -1

var _broadcast_lobby_id: int = 0
var _udp_peers: Array[PacketPeerUDP]
var _client_timers: Dictionary[int, Timer]
var _player_entry_scene: PackedScene = load("uid://dj0mx5ui2wu4n")

## Ссылка на [EquipSelector].
@onready var equip_selector: EquipSelector = %EquipSelector
@onready var _item_selector: Window = %EquipSelector/ItemSelector
@onready var _items_grid: ItemsGrid = %EquipSelector/%ItemsGrid

@onready var _game: Game = get_parent()
@onready var _players_container: GridContainer = %PlayersContainer
@onready var _chat: Chat = $Main/Panels/Chat
@onready var _countdown_timer: Timer = $CountdownTimer


func _ready() -> void:
	_game.created.connect(_on_game_created)
	_game.joined.connect(_on_game_joined)
	_game.closed.connect(_on_game_closed)
	_game.started.connect(_on_game_started)
	_game.ended.connect(_on_game_ended)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	
	selected_maps = Globals.get_variant("selected_maps", [] as Array[int])
	if selected_maps.size() < Globals.items_db.events.size():
		selected_maps.resize(Globals.items_db.events.size())
	selected_events_parameters = Globals.get_variant("selected_events_parameters",
			[] as Array[Dictionary])
	if selected_events_parameters.size() < Globals.items_db.events.size():
		for idx: int in range(selected_events_parameters.size(), Globals.items_db.events.size()):
			var parameters: Dictionary[String, int]
			parameters = Globals.items_db.events[idx].get_default_parameters()
			selected_events_parameters.append(parameters)
	selected_events_modifiers = Globals.get_variant("selected_events_modifiers", [] as Array[Array])
	if selected_events_modifiers.size() < Globals.items_db.events.size():
		# не resize чтобы были именно Array[int]
		for idx: int in range(selected_events_modifiers.size(), Globals.items_db.events.size()):
			selected_events_modifiers.append([] as Array[int])
	
	# Инициализируем состояние исходя из последнего сохранённого
	selected_event = Globals.get_int("selected_event")
	selected_map = selected_maps[selected_event]
	# во избежание редактирования сохранённых словаря и массива
	selected_event_parameters = selected_events_parameters[selected_event]
	selected_event_modifiers = selected_events_modifiers[selected_event]
	
	_validate_selected_environment()
	_update_environment()
	_items_grid.item_selected.connect(_on_item_selected)
	
	if Globals.get_setting_bool("broadcast"):
		_find_ips_for_broadcast()
	
	if Globals.console:
		Globals.console.command_processors.append(_process_console_command)
		Globals.console.help_processors.append(_print_help)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when _game.state == Game.State.LOBBY:
			_on_leave_pressed()


func _exit_tree() -> void:
	if Globals.console:
		Globals.console.command_processors.erase(_process_console_command)
		Globals.console.help_processors.erase(_print_help)


## Запрашивает сервер сменить окружение на событие с идентификатором [param event_idx] и на карту
## с идентификатором [param map_idx], а также задать параметры события [param event_parameters]
## и модификаторы события [param event_modifiers].[br]
## [b]Примечание[/b]: этот метод должен вызываться только как RPC к серверу
## ([constant MultiplayerPeer.TARGET_PEER_SERVER]).
@rpc("any_peer", "reliable", "call_local", 1)
func request_set_environment(event_idx: int, map_idx: int,
		event_parameters: Dictionary[String, int], event_modifiers: Array[int]) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != admin_id:
		push_warning("Set environment request rejected: player %d is not admin." % sender_id)
		return
	
	if not _countdown_timer.is_stopped():
		push_warning("Set environment request rejected: counting down.")
		return
	
	if event_idx < 0 or event_idx >= Globals.items_db.events.size():
		push_warning("Rejected set environment request from %d. Incorrect event index: %d." % [
			sender_id,
			event_idx,
		])
		return
	if map_idx < 0 or map_idx >= Globals.items_db.events[event_idx].maps.size():
		push_warning("Rejected set environment request from %d. Incorrect map index: %d." % [
			sender_id,
			map_idx,
		])
		return
	if not Globals.items_db.events[event_idx].is_parameters_valid(event_parameters):
		push_warning("Rejected set environment request from %d. Incorrect event parameters: %s." % [
			sender_id,
			event_parameters,
		])
		return
	if not Globals.items_db.events[event_idx].is_modifiers_valid(event_modifiers):
		push_warning("Rejected set environment request from %d. Incorrect event modifiers: %s." % [
			sender_id,
			event_modifiers,
		])
		return
	
	_game.max_players = Globals.items_db.events[event_idx].max_players
	print_verbose("Accepted set environment request. \
Event index: %d, map index: %d, event parameters: %s, event modifiers: %s." % [
		event_idx,
		map_idx,
		event_parameters,
		event_modifiers,
	])
	_set_environment.rpc(event_idx, map_idx, event_parameters, event_modifiers)


## Запрашивает сервер выполнить действие админа [param action] по отношению к игроку с
## идентификатором [param id].[br]
## [b]Примечание[/b]: этот метод должен вызываться только как RPC к серверу
## ([constant MultiplayerPeer.TARGET_PEER_SERVER]).
@rpc("any_peer", "reliable", "call_local", 1)
func request_admin_action(id: int, action: AdminAction) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in [admin_id, MultiplayerPeer.TARGET_PEER_SERVER]:
		push_warning("Admin action request rejected: player %d is not admin." % sender_id)
		return
	if id == admin_id:
		push_warning("Can't do admin actions on admin.")
		return
	if _game.state != Game.State.LOBBY:
		push_warning("Can't do admin actions if not in lobby.")
		return
	if not id in players and id != MultiplayerPeer.TARGET_PEER_SERVER:
		push_warning("Can't do admin actions on non-existent player %d." % id)
		return
	
	match action:
		AdminAction.KICK, AdminAction.BAN:
			if id == MultiplayerPeer.TARGET_PEER_SERVER:
				push_warning("Can't kick or ban server.")
				return
			var message: String
			if action == AdminAction.BAN:
				print_verbose("Accepted ban request. Banning: %d." % id)
				var ip: String = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(
						id).get_remote_address()
				_game.banned_ips.append(ip)
				message = "[outline_size=4][color=green]%s[/color][/outline_size] банит игрока \
[outline_size=4][color=red]%s[/color][/outline_size]!"
			else:
				print_verbose("Accepted kick request. Kicking: %d." % id)
				message = "[outline_size=4][color=green]%s[/color][/outline_size] выгоняет игрока \
[outline_size=4][color=red]%s[/color][/outline_size]!"
			
			(multiplayer as SceneMultiplayer).disconnect_peer(id)
			_chat.post_message.rpc("> " + message % [players[admin_id], players[id]])
			_unregister_player(id)
		AdminAction.TRANSFER_ADMIN_RIGHTS:
			print_verbose("Accepted transfer admin rights request. New admin: %d." % id)
			admin_id = id
			_set_admin.rpc(admin_id)
		_:
			push_warning("Invalid admin action requested.")


## Запрашивает сервер выполнить действие с командами [param action] по отношению к игроку с
## идентификатором [param id].[br]
## [b]Примечание[/b]: этот метод должен вызываться только как RPC к серверу
## ([constant MultiplayerPeer.TARGET_PEER_SERVER]).
@rpc("any_peer", "reliable", "call_local", 1)
func request_team_action(id: int, action: TeamAction) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in [admin_id, MultiplayerPeer.TARGET_PEER_SERVER]:
		push_warning("Team action request rejected: player %d is not admin." % sender_id)
		return
	if _game.state != Game.State.LOBBY:
		push_warning("Can't do team actions if not in lobby.")
		return
	if not id in players and id != MultiplayerPeer.TARGET_PEER_SERVER:
		push_warning("Can't do team actions on non-existent player %d." % id)
		return
	
	match action:
		TeamAction.RED_TEAM:
			players_teams[id] = 0
			_update_player_entry_team.rpc(id, 0)
			print_verbose("Added player %d to red team." % id)
		TeamAction.BLUE_TEAM:
			players_teams[id] = 1
			_update_player_entry_team.rpc(id, 1)
			print_verbose("Added player %d to blue team." % id)
		TeamAction.REMOVE_TEAM:
			players_teams[id] = -1
			_update_player_entry_team.rpc(id, -1)
			print_verbose("Removed player %d from team." % id)
		_:
			push_warning("Invalid team action requested.")


## Запрашивает сервер начать событие.[br]
## [b]Примечание[/b]: этот метод должен вызываться только как RPC к серверу
## ([constant MultiplayerPeer.TARGET_PEER_SERVER]).
@rpc("any_peer", "reliable", "call_local", 1)
func request_start_event() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != admin_id:
		push_warning("Start request rejected: player %d is not admin." % sender_id)
		return
	
	if _game.state != Game.State.LOBBY:
		push_warning("Start request rejected: current state game is not lobby.")
		return
	if not _countdown_timer.is_stopped():
		push_warning("Start request rejected: counting down already.")
		return
	
	var start_reject_reason: StartRejectReason = _get_start_reject_reason()
	if start_reject_reason != StartRejectReason.OK:
		_reject_start_event.rpc_id(sender_id, start_reject_reason, players.size())
		return
	
	print_verbose("Accepted start event request. Starting countdown...")
	_countdown_timer.start()
	_show_countdown.rpc()


## Обновляет иконки выбранных карт и событий.
func update_selected() -> void:
	_save_selected_environment()
	_update_environment()


## Возвращает [code]true[/code], если текущий клиент - админ.
func is_admin() -> bool:
	return admin_id == multiplayer.get_unique_id()


@rpc("reliable", "call_local", "authority", 1)
func _add_player_entry(id: int, player_name: String, player_team: int = -1) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	var player_entry: Node = _player_entry_scene.instantiate()
	player_entry.name = str(id)
	
	var name_label: Label = player_entry.get_node(^"Name")
	name_label.text = player_name
	if player_team >= 0:
		name_label.add_theme_constant_override(&"outline_size", 4)
		name_label.add_theme_color_override(&"font_outline_color", Entity.TEAM_COLORS[player_team])
	
	var admin_actions: MenuButton = player_entry.get_node(^"AdminActions")
	if id == multiplayer.get_unique_id():
		(player_entry.get_node(^"Name") as Label).add_theme_color_override(
				&"font_color", Color.CORNFLOWER_BLUE)
		admin_actions.disabled = true
		admin_actions.self_modulate = Color.TRANSPARENT
		admin_actions.focus_mode = Control.FOCUS_NONE
	if id == MultiplayerPeer.TARGET_PEER_SERVER:
		# Сервер нельзя выгнать/забанить
		admin_actions.get_popup().set_item_disabled(0, true)
		admin_actions.get_popup().set_item_disabled(1, true)
	admin_actions.visible = is_admin()
	admin_actions.get_popup().id_pressed.connect(_on_admin_actions_menu_id_pressed.bind(id))
	
	var team_actions: MenuButton = player_entry.get_node(^"TeamActions")
	team_actions.visible = is_admin() and Globals.items_db.events[selected_event].team_event
	team_actions.get_popup().id_pressed.connect(_on_team_actions_menu_id_pressed.bind(id))
	
	_players_container.add_child(player_entry)
	print_verbose("Added player %d entry with name %s in team %d." % [id, player_name, player_team])


@rpc("reliable", "call_local", "authority", 1)
func _update_player_entry_team(id: int, player_team: int = -1) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	var name_label: Label = _players_container.get_node(str(id)).get_node(^"Name")
	if player_team >= 0:
		name_label.add_theme_constant_override(&"outline_size", 4)
		name_label.add_theme_color_override(&"font_outline_color", Entity.TEAM_COLORS[player_team])
	else:
		name_label.remove_theme_constant_override(&"outline_size")
		name_label.remove_theme_color_override(&"font_outline_color")
	print_verbose("Updated player %d entry with team %d." % [id, player_team])


@rpc("reliable", "call_local", "authority", 1)
func _delete_player_entry(id: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_players_container.get_node(str(id)).queue_free()
	print_verbose("Deleted player %d entry." % id)


@rpc("any_peer", "reliable", "call_local", 1)
func _register_new_player(player_name: String) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id in players:
		push_warning("Player %d is already registered.")
		return
	
	if sender_id in _client_timers:
		_client_timers[sender_id].queue_free()
		_client_timers.erase(sender_id)
	for id: int in players:
		_add_player_entry.rpc_id(sender_id, id, players[id], players_teams[id])
	_set_environment.rpc_id(sender_id, selected_event, selected_map,
			selected_event_parameters, selected_event_modifiers)
	player_name = Utils.validate_player_name(player_name, sender_id)
	players[sender_id] = player_name
	players_teams[sender_id] = -1
	_add_player_entry.rpc(sender_id, player_name, -1)
	
	_chat.post_message.rpc(
			"> [outline_size=4][color=green]%s[/color][/outline_size] подключается!" % player_name)
	_chat.players_names[sender_id] = player_name
	var new_team: int
	for i: int in 10:
		if not i in _chat.players_teams.values():
			new_team = i
			break
	_chat.players_teams[sender_id] = new_team
	
	if admin_id < 0:
		admin_id = sender_id
	_set_admin.rpc_id(sender_id, admin_id)
	
	print_verbose("Registered player %d with name %s." % [sender_id, player_name])


@rpc("reliable", "call_local", "authority", 1)
func _set_admin(admin: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	admin_id = admin
	(%AdminPanel as CanvasItem).visible = is_admin()
	(%ClientPanel as CanvasItem).visible = not is_admin()
	(%WaitingForServer as CanvasItem).hide()
	for entry: Node in _players_container.get_children():
		(entry.get_node(^"AdminActions") as CanvasItem).visible = is_admin()
		(entry.get_node(^"Admin") as CanvasItem).visible = int(entry.name) == admin_id
		(entry.get_node(^"TeamActions") as CanvasItem).visible = is_admin() \
				and Globals.items_db.events[selected_event].team_event
	if is_admin():
		# Просим сервер установить выбранные ранее НАМИ событие, карту и параметры
		# дублируем чтобы не изменять локальный словарь
		request_set_environment.rpc_id(
				MultiplayerPeer.TARGET_PEER_SERVER, Globals.get_int("selected_event"),
				selected_maps[Globals.get_int("selected_event")],
				selected_events_parameters[Globals.get_int("selected_event")].duplicate(),
				selected_events_modifiers[Globals.get_int("selected_event")].duplicate()
		)
		_request_set_reject_players.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				Globals.get_setting_bool("reject_players"))
	
	if multiplayer.is_server():
		_game.banned_ips.clear()
	admin_changed.emit()
	print_verbose("Admin set: %d (this client: %s)." % [admin_id, is_admin()])


@rpc("call_local", "reliable", "authority", 1)
func _set_environment(event_idx: int, map_idx: int,
		event_parameters: Dictionary[String, int], event_modifiers: Array[int]) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	selected_event = event_idx
	selected_map = map_idx
	selected_event_parameters = event_parameters
	selected_event_modifiers = event_modifiers
	if is_admin():
		selected_maps[event_idx] = map_idx
		# дублируем чтобы отвязать сохранённые от редактируемых
		selected_events_parameters[event_idx] = event_parameters.duplicate()
		selected_events_modifiers[event_idx] = event_modifiers.duplicate()
		_save_selected_environment()
	
	for entry: Node in _players_container.get_children():
		var team_event: bool = Globals.items_db.events[selected_event].team_event
		(entry.get_node(^"TeamActions") as CanvasItem).visible = is_admin() and team_event
		var name_label: Label = entry.get_node(^"Name")
		if name_label.has_theme_constant_override(&"outline_size"):
			name_label.add_theme_constant_override(&"outline_size", 4 if team_event else 0)
	
	environment_changed.emit()
	print_verbose("Environment set: event index - %d, map index - %d, \
event parameters - %s, event modifiers - %s." % [
		event_idx,
		map_idx,
		event_parameters,
		event_modifiers,
	])
	_update_environment()


@rpc("any_peer", "call_local", "reliable", 1)
func _request_set_reject_players(reject_players: bool) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != admin_id:
		push_warning("Set reject players request rejected: player %d is not admin." % sender_id)
		return
	_game.reject_players = reject_players


@rpc("call_local", "reliable", "authority", 1)
func _show_countdown() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if is_admin():
		(%AdminPanel as CanvasItem).hide()
	else:
		(%ClientPanel as CanvasItem).hide()
	(%Countdown as CanvasItem).show()
	(%Countdown/AnimationPlayer as AnimationPlayer).play(&"countdown")


@rpc("call_local", "reliable", "authority", 1)
func _hide_countdown() -> void:
	if _game.state == Game.State.CLOSED or is_admin():
		(%AdminPanel as CanvasItem).show()
	if _game.state == Game.State.CLOSED or not is_admin():
		(%ClientPanel as CanvasItem).show()
	(%Countdown as CanvasItem).hide()
	(%Countdown/AnimationPlayer as AnimationPlayer).stop()


@rpc("reliable", "call_local", "authority", 1)
func _reject_start_event(reason: StartRejectReason, players_count: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	match reason:
		StartRejectReason.OK:
			push_warning("This method can't be called with OK reject reason.")
		StartRejectReason.TOO_FEW_PLAYERS:
			_game.show_error("Невозможно начать игру: слишком мало игроков (%d) \
при минимуме в %d!" % [players_count, Globals.items_db.events[selected_event].min_players])
			print_verbose("Start rejected: too few players (%d) with minimum %d." % [
				players_count,
				Globals.items_db.events[selected_event].min_players,
			])
		StartRejectReason.TOO_MANY_PLAYERS:
			_game.show_error("Невозможно начать игру: слишком много игроков (%d) \
при максимуме в %d!" % [players_count, Globals.items_db.events[selected_event].max_players])
			print_verbose("Start rejected: too many players (%d) with maximum %d." % [
				players_count,
				Globals.items_db.events[selected_event].max_players,
			])
		StartRejectReason.BAD_TEAMS:
			_game.show_error("Невозможно начать игру: игроков в одной команде больше чем в другой.")
			print_verbose("Start rejected: one team has more players than in other.")
		_:
			push_warning("Received invalid reject reason.")


@rpc("call_local", "reliable", "authority", 1)
func _start_event(event_idx: int, map_idx: int,
		event_parameters: Dictionary[String, int], event_modifiers: Array[int]) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_chat.clear_chat()
	if not ($BroadcastTimer as Timer).is_stopped():
		($BroadcastTimer as Timer).stop()
	if not ($UpdateBroadcastTimer as Timer).is_stopped():
		($UpdateBroadcastTimer as Timer).stop()
	if multiplayer.is_server():
		($ViewIPDialog as Window).hide()
		for id: int in multiplayer.get_peers():
			if not id in players:
				(multiplayer as SceneMultiplayer).disconnect_peer(id)
				if id in _client_timers:
					_client_timers[id].queue_free()
					_client_timers.erase(id)
				push_warning("Start event: peer %d kicked as not registered." % id)
		if Globals.items_db.events[event_idx].team_event:
			_game.set_players_teams(players_teams)
		if Globals.headless:
			_game.load_event(event_idx, map_idx, event_parameters, event_modifiers)
			return
	_item_selector.hide()
	($PresetManager as Window).hide()
	($QuickSettings as Window).hide()
	($EventConfiguration as Window).hide()
	
	_game.load_event(
			event_idx, map_idx, event_parameters, event_modifiers,
			Globals.get_string("player_name"), [
				Globals.items_db.skins_by_id[equip_selector.selected_skin].idx_in_db,
				Globals.items_db.skills_by_id[equip_selector.selected_skill].idx_in_db,
				Globals.items_db.weapons_by_id[equip_selector.selected_light_weapon].idx_in_db,
				Globals.items_db.weapons_by_id[equip_selector.selected_heavy_weapon].idx_in_db,
				Globals.items_db.weapons_by_id[equip_selector.selected_support_weapon].idx_in_db,
				Globals.items_db.weapons_by_id[equip_selector.selected_melee_weapon].idx_in_db,
			]
	)


func _unregister_player(id: int) -> void:
	_chat.players_names.erase(id)
	_chat.players_teams.erase(id)
	players.erase(id)
	players_teams.erase(id)
	if id == admin_id:
		if not players.is_empty():
			admin_id = players.keys()[0]
			_set_admin.rpc(admin_id)
		else:
			admin_id = -1
	_delete_player_entry.rpc(id)
	
	if players.is_empty():
		_chat.clear_chat()


func _get_start_reject_reason() -> StartRejectReason:
	var start_reject_reason := StartRejectReason.OK
	if players.size() < Globals.items_db.events[selected_event].min_players:
		start_reject_reason = StartRejectReason.TOO_FEW_PLAYERS
		print_verbose("Rejecting start: too few players (%d), need %d." % [
			players.size(),
			Globals.items_db.events[selected_event].min_players,
		])
	elif players.size() > Globals.items_db.events[selected_event].max_players:
		start_reject_reason = StartRejectReason.TOO_MANY_PLAYERS
		print_verbose("Rejecting start: too many players (%d), max %d." % [
			players.size(),
			Globals.items_db.events[selected_event].max_players,
		])
	elif Globals.items_db.events[selected_event].team_event:
		var red_team: int = 0
		var blue_team: int = 0
		for id: int in players_teams:
			if players_teams[id] == 0:
				red_team += 1
			elif players_teams[id] == 1:
				blue_team += 1
		if roundi(players.size() / 2.0) < maxi(red_team, blue_team):
			start_reject_reason = StartRejectReason.BAD_TEAMS
			print_verbose("Rejecting start: one team has more players than in other.")
	
	return start_reject_reason


func _find_ips_for_broadcast() -> void:
	_udp_peers.clear()
	print_verbose("Finding IPs for broadcast...")
	# Отсылаем пакеты по всем локальным адресам
	for ip: String in IP.get_local_addresses():
		for prefix: String in Game.LOCAL_IP_PREFIXES:
			if ip.begins_with(prefix):
				var udp := PacketPeerUDP.new()
				udp.set_broadcast_enabled(true)
				# Меняем конец IP на 255 для получения широковещательного адреса
				var broadcast_ip: String = ip.rsplit('.', true, 1)[0] + ".255"
				udp.set_dest_address(broadcast_ip, Game.LISTEN_PORT)
				print_verbose("Found IP to broadcast: %s." % broadcast_ip)
				_udp_peers.append(udp)
				break
	
	if _udp_peers.is_empty():
		print_verbose("No IPs found.")


func _do_broadcast() -> void:
	if _udp_peers.is_empty():
		return
	var data := PackedByteArray()
	data.append(_broadcast_lobby_id)
	data.append(players.size())
	data.append(_game.max_players)
	data.append(selected_event)
	data.append_array(Globals.get_string("player_name", "Server").to_utf8_buffer()) # Имя
	for peer: PacketPeerUDP in _udp_peers:
		peer.put_packet(data)
	print_verbose("Broadcast of lobby %d done. Data sent: %s (%d/%d), event: %s (index: %d)." % [
		_broadcast_lobby_id,
		Globals.get_string("player_name", "Server"),
		players.size(),
		_game.max_players,
		Globals.items_db.events[selected_event].name,
		selected_event,
	])


func _validate_selected_environment() -> void:
	var changed := false
	if selected_event < 0 or selected_event >= Globals.items_db.events.size():
		push_warning("Incorrect selected event: %d. Reverting to default." % selected_event)
		selected_event = 0
		changed = true
	for event_idx: int in Globals.items_db.events.size():
		if selected_maps[event_idx] < 0 \
				or selected_maps[event_idx] >= Globals.items_db.events[event_idx].maps.size():
			push_warning("Incorrect selected map for event %d: %d. Reverting to default." % [
				event_idx,
				selected_maps[event_idx],
			])
			selected_maps[event_idx] = 0
			changed = true
	for event_idx: int in Globals.items_db.events.size():
		if not Globals.items_db.events[event_idx].is_parameters_valid(
				selected_events_parameters[event_idx]):
			push_warning("Incorrect parameters for event %d: %s. Reverting to default." % [
				selected_event,
				selected_events_parameters[event_idx],
			])
			selected_events_parameters[event_idx] = \
					Globals.items_db.events[event_idx].get_default_parameters()
			changed = true
	for event_idx: int in Globals.items_db.events.size():
		if not Globals.items_db.events[event_idx].is_modifiers_valid(
				selected_events_modifiers[event_idx]):
			push_warning("Incorrect modifiers for event %d: %d. Reverting to default." % [
				event_idx,
				selected_events_modifiers[event_idx],
			])
			selected_events_modifiers[event_idx].clear()
			changed = true
	
	if changed:
		_save_selected_environment()


func _save_selected_environment() -> void:
	Globals.set_int("selected_event", selected_event)
	Globals.set_variant("selected_maps", selected_maps)
	Globals.set_variant("selected_events_parameters", selected_events_parameters)
	Globals.set_variant("selected_events_modifiers", selected_events_modifiers)


func _update_environment() -> void:
	var event: EventData = Globals.items_db.events[selected_event]
	(%Event as TextureRect).texture = load(event.image_path)
	(%Event/Container/Name as Label).text = event.name
	(%Event/Container/Description as Label).text = event.brief_description
	
	(%Map as TextureRect).texture = load(event.maps[selected_map].image_path)
	(%Map/Container/Name as Label).text = event.maps[selected_map].name
	(%Map/Container/Description as Label).text = \
			event.maps[selected_map].brief_description


func _process_console_command(command: PackedStringArray) -> bool:
	if _game.state != Game.State.LOBBY:
		return false
	var recognized := false
	match command[0]:
		"list-players" when command.size() == 1:
			recognized = true
			if not multiplayer.is_server():
				printerr("This command only available on server.")
				return recognized
			print("Connected players:")
			for id: int in players:
				prints(id, players[id])
			if admin_id in players:
				print("Current admin: %d (%s)." % [admin_id, players[admin_id]])
			else:
				print("Current admin: %d." % admin_id)
			if Globals.headless:
				print("Server ID is always 1.")
		"list-environment" when command.size() == 1:
			recognized = true
			print("Available events:")
			for event_idx: int in Globals.items_db.events.size():
				print("%s%d: %s. Maps:" % [
					"> " if selected_event == event_idx else "",
					event_idx,
					Globals.items_db.events[event_idx].name,
				])
				for map_idx: int in Globals.items_db.events[event_idx].maps.size():
					print("\t%s%d: %s" % [
						"> " if selected_event == event_idx and selected_map == map_idx else "",
						map_idx,
						Globals.items_db.events[event_idx].maps[map_idx].name,
					])
		"list-parameters" when command.size() == 1:
			recognized = true
			print("Current event parameters:")
			for parameter_id: String in selected_event_parameters:
				var parameter: EventParameter = \
						Globals.items_db.events[selected_event].parameters[parameter_id]
				print("{parameter_id}: {name}, range: {min}-{max} with step {step}. \
Current value: {current}.".format({
					"parameter_id": parameter_id,
					"name": parameter.name,
					"min": parameter.range_min,
					"max": parameter.range_max,
					"step": parameter.range_step,
					"current": selected_event_parameters[parameter_id],
				}))
		"list-modifiers" when command.size() == 1:
			recognized = true
			print("Current event modifiers: %s." % str(selected_event_modifiers))
			for modifier: EventModifierData in \
					Globals.items_db.events[selected_event].get_modifiers():
				print("%d: %s - %s" % [
					modifier.idx_in_db,
					modifier.name,
					modifier.brief_description,
				])
		
		"set-environment" when command.size() in [2, 3]:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			if command.size() == 2:
				request_set_environment.rpc_id(
						MultiplayerPeer.TARGET_PEER_SERVER, int(command[1]), 0,
						selected_events_parameters[int(command[1])],
						selected_events_modifiers[int(command[1])],
				)
			else:
				request_set_environment.rpc_id(
						MultiplayerPeer.TARGET_PEER_SERVER, int(command[1]), int(command[2]),
						selected_events_parameters[int(command[1])],
						selected_events_modifiers[int(command[1])],
				)
		"set-parameter" when command.size() == 3:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			selected_event_parameters[command[1]] = int(command[2])
			request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, selected_event,
					selected_map, selected_event_parameters, selected_event_modifiers)
		"reset-parameters" when command.size() == 1:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			request_set_environment.rpc_id(
					MultiplayerPeer.TARGET_PEER_SERVER, selected_event, selected_map,
					Globals.items_db.events[selected_event].get_default_parameters(),
					selected_event_modifiers
			)
		"set-modifiers":
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			selected_event_modifiers.clear()
			for modifier_str: String in command.slice(1):
				selected_event_modifiers.append(int(modifier_str))
			request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, selected_event,
					selected_map, selected_event_parameters, selected_event_modifiers)
		
		
		"start" when command.size() == 1:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			request_start_event.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		"admin", "admin-id" when command.size() <= 2:
			recognized = true
			if not is_admin() and not multiplayer.is_server():
				printerr("This command only available for admins.")
				return recognized
			if command.size() == 1:
				request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
						MultiplayerPeer.TARGET_PEER_SERVER, AdminAction.TRANSFER_ADMIN_RIGHTS)
			else:
				var id: int
				if command[0] == "admin":
					id = _get_player_id(command[1])
				else:
					id = int(command[1])
				request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
						id, AdminAction.TRANSFER_ADMIN_RIGHTS)
		"kick", "kick-id" when command.size() == 2:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			var id: int
			if command[0] == "kick":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, AdminAction.KICK)
		"ban", "ban-id" when command.size() == 2:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			var id: int
			if command[0] == "ban":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, AdminAction.BAN)
		
		"red-team", "red-team-id" when command.size() == 2:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			var id: int
			if command[0] == "red-team":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			request_team_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, TeamAction.RED_TEAM)
		"blue-team", "blue-team-id" when command.size() == 2:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			var id: int
			if command[0] == "blue-team":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			request_team_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, TeamAction.BLUE_TEAM)
		"remove-team", "remove-team-id" when command.size() == 2:
			recognized = true
			if not is_admin():
				printerr("This command only available for admins.")
				return recognized
			var id: int
			if command[0] == "remove-team":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			request_team_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, TeamAction.REMOVE_TEAM)
	
	return recognized


func _print_help() -> void:
	# Помошь по post здесь, потому что в Chat она будет дублироваться
	if _game.state != Game.State.LOBBY:
		if _game.state == Game.State.EVENT:
			print("post <message> - Posts message in chat.")
		return
	print("post <message> - Posts message in chat.")
	print("list-players - List all connected players. Works only on server.")
	print("list-environment - Lists events and maps.")
	print("list-parameters - Lists event parameters.")
	print("list-modifiers - Lists event modifiers.")
	
	print("These commands only available if you are admin:")
	print("set-environment <event-id> [map-id] - Sets event and map to specified values.")
	print("set-parameter <parameter-id> <value> - Sets event parameter to specified value.")
	print("reset-parameters - Resets event parameters to default values.")
	print("set-modifiers [modifier1] [modifier2] ... - Sets events modifiers to specified array.")
	
	print("start - Starts event.")
	print("admin [player] - Makes specified player admin. Current admin loses his rights. \
Note: you can always set admin to yourself if you are server.")
	print("admin-id [id] - Same as admin, but uses player ID.")
	print("kick <player> - Kicks specified player.")
	print("kick-id <id> - Same as kick, but uses player ID.")
	print("ban <player> - Bans specified player.")
	print("ban-id <id> - Same as ban, but uses player ID.")
	
	print("red-team <player> - Adds specified player to red team.")
	print("red-team-id <id> - Same as red-team, but uses player ID.")
	print("blue-team <player> - Adds specified player to blue team.")
	print("blue-team-id <id> - Same as blue-team, but uses player ID.")
	print("remove-team <player> - Removes specified player from team.")
	print("remove-team-id <id> - Same as remove-team, but uses player ID.")


func _get_player_id(player: String) -> int:
	for id: int in players:
		if players[id].begins_with(player):
			return id
	return -1


func _on_client_timer_timeout(id: int) -> void:
	(multiplayer as SceneMultiplayer).disconnect_peer(id)
	push_warning("Peer %d kicked for inactivity." % id)
	_client_timers[id].queue_free()
	_client_timers.erase(id)


func _on_game_created() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	(%ControlButtons/ConnectedToIP as CanvasItem).hide()
	(%ControlButtons/ViewIP as CanvasItem).show()
	players.clear()
	players_teams.clear()
	if not Globals.headless:
		_register_new_player.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				Globals.get_string("player_name"))
	if Globals.get_setting_bool("broadcast"):
		($BroadcastTimer as Timer).start()
		($UpdateBroadcastTimer as Timer).start()
		_broadcast_lobby_id = absi(Globals.get_string("player_name", "Server").hash()
				* OS.get_unique_id().hash() + OS.get_process_id())
		_broadcast_lobby_id %= 256
		_do_broadcast()


func _on_game_joined() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	(%AdminPanel as CanvasItem).hide()
	(%ClientPanel as CanvasItem).show()
	(%WaitingForServer as CanvasItem).show()
	(%ControlButtons/ConnectedToIP as CanvasItem).show()
	(%ControlButtons/ConnectedToIP as LinkButton).text = "Подключено к %s" % \
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(
			MultiplayerPeer.TARGET_PEER_SERVER).get_remote_address()
	(%ControlButtons/ViewIP as CanvasItem).hide()
	_register_new_player.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
			Globals.get_string("player_name"))


func _on_game_closed() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_item_selector.hide()
	($PresetManager as Window).hide()
	($QuickSettings as Window).hide()
	($EventConfiguration as Window).hide()
	
	if not ($BroadcastTimer as Timer).is_stopped():
		($BroadcastTimer as Timer).stop()
	if not ($UpdateBroadcastTimer as Timer).is_stopped():
		($UpdateBroadcastTimer as Timer).stop()
	if not _countdown_timer.is_stopped():
		_countdown_timer.stop()
	_hide_countdown()
	
	for entry: Node in _players_container.get_children():
		entry.queue_free()
	admin_id = -1
	
	_chat.clear_chat()
	(%ControlButtons/Chat as BaseButton).button_pressed = false


func _on_game_started() -> void:
	_hide_countdown()
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_game_ended() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	if multiplayer.is_server() and Globals.get_setting_bool("broadcast"):
		($BroadcastTimer as Timer).start()
		($UpdateBroadcastTimer as Timer).start()


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_on_client_timer_timeout.bind(id))
	add_child(timer)
	_client_timers[id] = timer


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_chat.post_message.rpc(
			"> [outline_size=4][color=green]%s[/color][/outline_size] отключается!" % players[id])
	_unregister_player(id)


func _on_admin_actions_menu_id_pressed(action: AdminAction, peer: int) -> void:
	request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, peer, action)


func _on_team_actions_menu_id_pressed(action: TeamAction, peer: int) -> void:
	request_team_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, peer, action)


func _on_item_selected(type: ItemsDB.Item, idx: int) -> void:
	match type:
		ItemsDB.Item.EVENT:
			request_set_environment.rpc_id(
					MultiplayerPeer.TARGET_PEER_SERVER, idx, selected_maps[idx],
					selected_events_parameters[idx], selected_events_modifiers[idx]
			)
		ItemsDB.Item.MAP:
			request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					selected_event, idx, selected_event_parameters, selected_event_modifiers)


func _on_countdown_timer_timeout() -> void:
	print_verbose("Countdown ended.")
	var start_reject_reason: StartRejectReason = _get_start_reject_reason()
	if start_reject_reason != StartRejectReason.OK:
		_hide_countdown.rpc()
		_reject_start_event.rpc_id(admin_id, start_reject_reason, players.size())
		return
	
	print_verbose("Starting...")
	_start_event.rpc(selected_event, selected_map,
			selected_event_parameters, selected_event_modifiers)


func _on_start_event_pressed() -> void:
	request_start_event.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _on_leave_pressed() -> void:
	_game.close()


func _on_connected_to_ip_pressed() -> void:
	DisplayServer.clipboard_set((multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(
			MultiplayerPeer.TARGET_PEER_SERVER).get_remote_address())


func _on_change_event_pressed() -> void:
	_item_selector.title = "Выбор события"
	_item_selector.popup_centered()
	_items_grid.list_items(ItemsDB.Item.EVENT, selected_event)
