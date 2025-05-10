class_name Lobby
extends Control

## Лобби игры.
##
## Здесь игрок выбирает событие и карту, оружие, скин и навык, а также общается с другими игроками.

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
}
## Перечисления действий администратора.
enum AdminAction {
	## Выгнать из комнаты.
	KICK = 0,
	## Выгнать из комнаты и забанить по IP-адресу.
	BAN = 1,
	## Передать права админа.
	TRANSFER_ADMIN_RIGHTS = 2,
}

var selected_event: int
var selected_map: int
var selected_maps: Array[int]

var selected_skin: int
var selected_skill: int
var selected_light_weapon: int
var selected_heavy_weapon: int
var selected_support_weapon: int
var selected_melee_weapon: int

var _players: Dictionary[int, String]
var _admin := false
var _admin_id: int = -1

var _broadcast_lobby_id: int = 0
var _udp_peers: Array[PacketPeerUDP]
var _client_timers: Dictionary[int, Timer]
var _player_entry_scene: PackedScene = preload("uid://dj0mx5ui2wu4n")

@onready var _game: Game = get_parent()
@onready var _players_container: GridContainer = %PlayersContainer
@onready var _items_grid: ItemsGrid = %ItemsGrid
@onready var _item_selector: Window = $ItemSelector
@onready var _chat: Chat = $Panels/Chat
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
	
	selected_event = Globals.get_int("selected_event")
	selected_maps = Globals.get_variant("selected_maps", [] as Array[int])
	if selected_maps.size() < Globals.items_db.events.size():
		selected_maps.resize(Globals.items_db.events.size())
	
	selected_skin = Globals.get_int("selected_skin")
	selected_skill = Globals.get_int("selected_skill")
	selected_light_weapon = Globals.get_int("selected_light_weapon")
	selected_heavy_weapon = Globals.get_int("selected_heavy_weapon")
	selected_support_weapon = Globals.get_int("selected_support_weapon")
	selected_melee_weapon = Globals.get_int("selected_melee_weapon")
	
	_validate_selected_items()
	_update_equip()
	_update_environment()
	
	if Globals.get_setting_bool("broadcast"):
		_find_ips_for_broadcast()
	
	if Globals.main.console:
		Globals.main.console.command_processors.append(_process_console_command)
		Globals.main.console.help_processors.append(_print_help)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when _game.state == Game.State.LOBBY:
			_on_leave_pressed()


func _exit_tree() -> void:
	if Globals.main.console:
		Globals.main.console.command_processors.erase(_process_console_command)
		Globals.main.console.help_processors.erase(_print_help)


@rpc("reliable", "call_local", "authority", 1)
func _add_player_entry(id: int, player_name: String) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	var player_entry: Node = _player_entry_scene.instantiate()
	player_entry.name = str(id)
	(player_entry.get_node(^"Name") as Label).text = player_name
	var admin_actions: MenuButton = player_entry.get_node(^"AdminActions")
	
	if id == multiplayer.get_unique_id():
		(player_entry.get_node(^"Name") as Label).add_theme_color_override(
				&"font_color", Color.CORNFLOWER_BLUE)
		admin_actions.disabled = true
		admin_actions.self_modulate = Color.TRANSPARENT
	if id == MultiplayerPeer.TARGET_PEER_SERVER:
		# Сервер нельзя выгнать/забанить
		admin_actions.get_popup().set_item_disabled(0, true)
		admin_actions.get_popup().set_item_disabled(1, true)
	
	admin_actions.visible = _admin
	admin_actions.get_popup().id_pressed.connect(_on_admin_actions_menu_id_pressed.bind(id))
	_players_container.add_child(player_entry)
	print_verbose("Added player %d entry with name %s." % [id, player_name])


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
	if sender_id in _players:
		push_warning("Player %d is already registered.")
		return
	
	if sender_id in _client_timers:
		_client_timers[sender_id].queue_free()
		_client_timers.erase(sender_id)
	for id: int in _players:
		_add_player_entry.rpc_id(sender_id, id, _players[id])
	_set_environment.rpc_id(sender_id, selected_event, selected_map)
	player_name = Game.validate_player_name(player_name, sender_id)
	_players[sender_id] = player_name
	_add_player_entry.rpc(sender_id, player_name)
	
	_chat.post_message.rpc("> [color=green]%s[/color] подключается!" % player_name)
	_chat.players_names[sender_id] = player_name
	var new_team: int
	for i in 10:
		if not i in _chat.players_teams.values():
			new_team = i
			break
	_chat.players_teams[sender_id] = new_team
	
	if _admin_id < 0:
		_admin_id = sender_id
	_set_admin.rpc_id(sender_id, _admin_id)
	
	print_verbose("Registered player %d with name %s." % [sender_id, player_name])


@rpc("reliable", "call_local", "authority", 1)
func _set_admin(admin_id: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	var admin: bool = admin_id == multiplayer.get_unique_id()
	(%AdminPanel as CanvasItem).visible = admin
	(%ClientHint as CanvasItem).visible = not admin
	for entry: Node in _players_container.get_children():
		(entry.get_node(^"AdminActions") as CanvasItem).visible = admin
		(entry.get_node(^"Admin") as CanvasItem).visible = int(entry.name) == admin_id
	if admin:
		# Просим сервер установить выбранные ранее НАМИ событие и карту
		_request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				Globals.get_int("selected_event"), selected_maps[Globals.get_int("selected_event")])
	else:
		(%ClientHint as Label).text = "Начать игру может только админ."
	_admin = admin
	print_verbose("Admin set: %d (this client: %s)." % [admin_id, str(admin)])


@rpc("any_peer", "reliable", "call_local", 1)
func _request_set_environment(event_id: int, map_id: int) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != _admin_id:
		push_warning("Set environment request rejected: player %d is not admin." % sender_id)
		return
	
	if not _countdown_timer.is_stopped():
		push_warning("Set environment request rejected: counting down.")
		return
	
	if event_id < 0 or event_id >= Globals.items_db.events.size():
		push_warning("Rejected set environment request from %d. Incorrect event ID: %d." % [
			sender_id,
			event_id,
		])
		return
	if map_id < 0 or map_id >= Globals.items_db.events[event_id].maps.size():
		push_warning("Rejected set environment request from %d. Incorrect map ID: %d." % [
			sender_id,
			map_id,
		])
		return
	
	_game.max_players = Globals.items_db.events[event_id].max_players
	print_verbose("Accepted set environment request. Event ID: %d, Map ID: %d." % [
		event_id,
		map_id,
	])
	_set_environment.rpc(event_id, map_id)


@rpc("call_local", "reliable", "authority", 1)
func _set_environment(event_id: int, map_id: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	selected_event = event_id
	selected_map = map_id
	if _admin:
		selected_maps[event_id] = map_id
		_save_selected_items(true)
	print_verbose("Environment set: Event ID - %d, Map ID - %d." % [event_id, map_id])
	_update_environment()


@rpc("any_peer", "reliable", "call_local", 1)
func _request_admin_action(id: int, action: AdminAction) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in [_admin_id, MultiplayerPeer.TARGET_PEER_SERVER]:
		push_warning("Admin action request rejected: player %d is not admin." % sender_id)
		return
	if id == _admin_id:
		push_warning("Can't do admin actions on admin.")
		return
	if _game.state != Game.State.LOBBY:
		push_warning("Can't do admin actions if not in lobby.")
		return
	if not id in _players and id != MultiplayerPeer.TARGET_PEER_SERVER:
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
				message = "> [color=green]%s[/color] банит игрока [color=red]%s[/color]!"
			else:
				print_verbose("Accepted kick request. Kicking: %d." % id)
				message = "> [color=green]%s[/color] выгоняет игрока [color=red]%s[/color]!"
			
			(multiplayer as SceneMultiplayer).disconnect_peer(id)
			_chat.post_message.rpc(message % [_players[_admin_id], _players[id]])
			_unregister_player(id)
		AdminAction.TRANSFER_ADMIN_RIGHTS:
			print_verbose("Accepted transfer admin rights request. New admin: %d." % id)
			_admin_id = id
			_set_admin.rpc(_admin_id)
		_:
			push_warning("Invalid admin action requested.")


@rpc("any_peer", "reliable", "call_local", 1)
func _request_start_event() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != _admin_id:
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
		_reject_start_event.rpc_id(sender_id, start_reject_reason, _players.size())
		return
	
	print_verbose("Accepted start event request. Starting countdown...")
	_countdown_timer.start()
	_show_countdown.rpc()


@rpc("call_local", "reliable", "authority", 1)
func _show_countdown() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if _admin:
		(%AdminPanel as CanvasItem).hide()
	else:
		(%ClientHint as CanvasItem).hide()
	(%Countdown as CanvasItem).show()
	(%Countdown/AnimationPlayer as AnimationPlayer).play(&"Countdown")


@rpc("call_local", "reliable", "authority", 1)
func _hide_countdown() -> void:
	if _admin:
		(%AdminPanel as CanvasItem).show()
	else:
		(%ClientHint as CanvasItem).show()
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
		StartRejectReason.INDIVISIBLE_NUMBER_OF_PLAYERS:
			_game.show_error("Невозможно начать игру: количество игроков (%d) не делится на %d!" % [
				players_count,
				Globals.items_db.events[selected_event].players_divider,
			])
			print_verbose("Start rejected: number of players (%d) doesn't divide on %d." % [
				players_count,
				Globals.items_db.events[selected_event].players_divider,
			])
		_:
			push_warning("Received invalid reject reason.")


func _unregister_player(id: int) -> void:
	_chat.players_names.erase(id)
	_chat.players_teams.erase(id)
	_players.erase(id)
	if id == _admin_id:
		if not _players.is_empty():
			_admin_id = _players.keys()[0]
			_set_admin.rpc(_admin_id)
		else:
			_admin_id = -1
	_delete_player_entry.rpc(id)
	
	if _players.is_empty():
		_chat.clear_chat()


@rpc("call_local", "reliable", "authority", 1)
func _start_event(event_id: int, map_id: int) -> void:
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
			if not id in _players.keys():
				(multiplayer as SceneMultiplayer).disconnect_peer(id)
				if id in _client_timers:
					_client_timers[id].queue_free()
					_client_timers.erase(id)
				push_warning("Start event: peer %d kicked as not registered." % id)
		if Globals.headless:
			_game.load_event(event_id, map_id)
			return
	_item_selector.hide()
	
	_game.load_event(event_id, map_id, Globals.get_string("player_name"), [
		selected_skin,
		selected_skill,
		selected_light_weapon,
		selected_heavy_weapon,
		selected_support_weapon,
		selected_melee_weapon,
	])


func _validate_selected_items() -> void:
	if selected_event < 0 or selected_event >= Globals.items_db.events.size():
		push_warning("Incorrect selected event: %d. Reverting to default." % selected_event)
		selected_event = 0
	if selected_map < 0 or selected_map >= Globals.items_db.events[selected_event].maps.size():
		push_warning("Incorrect selected map for event %d: %d. Reverting to default." % [
			selected_event,
			selected_map,
		])
		selected_map = 0
	for event_idx: int in Globals.items_db.events.size():
		if selected_maps[event_idx] < 0 \
				or selected_maps[event_idx] >= Globals.items_db.events[event_idx].maps.size():
			push_warning("Incorrect selected map for event %d: %d. Reverting to default." % [
				event_idx,
				selected_maps[event_idx],
			])
			selected_maps[event_idx] = 0
	
	if selected_skin < 0 or selected_skin >= Globals.items_db.skins.size():
		push_warning("Incorrect selected skin: %d. Reverting to default." % selected_skin)
		selected_skin = 0
	if selected_skill < 0 or selected_skill >= Globals.items_db.skills.size():
		push_warning("Incorrect selected skill: %d. Reverting to default." % selected_skill)
		selected_skill = 0
	if selected_light_weapon < 0 \
			or selected_light_weapon >= Globals.items_db.weapons_light.size():
		push_warning("Incorrect selected light weapon: %d. Reverting to default."
				% selected_light_weapon)
		selected_light_weapon = 0
	if selected_heavy_weapon < 0 \
			or selected_heavy_weapon >= Globals.items_db.weapons_heavy.size():
		push_warning("Incorrect selected heavy weapon: %d. Reverting to default."
				% selected_heavy_weapon)
		selected_heavy_weapon = 0
	if selected_support_weapon < 0 \
			or selected_support_weapon >= Globals.items_db.weapons_support.size():
		push_warning("Incorrect selected support weapon: %d. Reverting to default."
				% selected_support_weapon)
		selected_support_weapon = 0
	if selected_melee_weapon < 0 \
			or selected_melee_weapon >= Globals.items_db.weapons_melee.size():
		push_warning("Incorrect selected melee weapon: %d. Reverting to default."
				% selected_melee_weapon)
		selected_melee_weapon = 0
	
	_save_selected_items(true)


func _save_selected_items(save_environment := false) -> void:
	if save_environment:
		Globals.set_int("selected_event", selected_event)
		Globals.set_variant("selected_maps", selected_maps)
	Globals.set_int("selected_skin", selected_skin)
	Globals.set_int("selected_skill", selected_skill)
	Globals.set_int("selected_light_weapon", selected_light_weapon)
	Globals.set_int("selected_heavy_weapon", selected_heavy_weapon)
	Globals.set_int("selected_support_weapon", selected_support_weapon)
	Globals.set_int("selected_melee_weapon", selected_melee_weapon)


func _update_environment() -> void:
	var event: EventData = Globals.items_db.events[selected_event]
	(%Event as TextureRect).texture = load(event.image_path)
	(%Event/Container/Name as Label).text = event.name
	(%Event/Container/Description as Label).text = event.brief_description
	
	(%Map as TextureRect).texture = load(event.maps[selected_map].image_path)
	(%Map/Container/Name as Label).text = event.maps[selected_map].name
	(%Map/Container/Description as Label).text = \
			event.maps[selected_map].brief_description


func _update_equip() -> void:
	var skin: SkinData = Globals.items_db.skins[selected_skin]
	(%Skin/Name as Label).text = skin.name
	(%Skin/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[skin.rarity]
	(%Skin as TextureRect).texture = load(skin.image_path)
	
	var skill: SkillData = Globals.items_db.skills[selected_skill]
	(%Skill/Name as Label).text = skill.name
	(%Skill/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[skill.rarity]
	(%Skill as TextureRect).texture = load(skill.image_path)
	
	var light_weapon: WeaponData = Globals.items_db.weapons_light[selected_light_weapon]
	(%LightWeapon/Name as Label).text = light_weapon.name
	(%LightWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[light_weapon.rarity]
	(%LightWeapon as TextureRect).texture = load(light_weapon.image_path)
	
	var heavy_weapon: WeaponData = Globals.items_db.weapons_heavy[selected_heavy_weapon]
	(%HeavyWeapon/Name as Label).text = heavy_weapon.name
	(%HeavyWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[heavy_weapon.rarity]
	(%HeavyWeapon as TextureRect).texture = load(heavy_weapon.image_path)
	
	var support_weapon: WeaponData = Globals.items_db.weapons_support[selected_support_weapon]
	(%SupportWeapon/Name as Label).text = support_weapon.name
	(%SupportWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[support_weapon.rarity]
	(%SupportWeapon as TextureRect).texture = load(support_weapon.image_path)
	
	var melee_weapon: WeaponData = Globals.items_db.weapons_melee[selected_melee_weapon]
	(%MeleeWeapon/Name as Label).text = melee_weapon.name
	(%MeleeWeapon/RarityFill as ColorRect).color = ItemsDB.RARITY_COLORS[melee_weapon.rarity]
	(%MeleeWeapon as TextureRect).texture = load(melee_weapon.image_path)


func _get_start_reject_reason() -> StartRejectReason:
	var start_reject_reason := StartRejectReason.OK
	if _players.size() < Globals.items_db.events[selected_event].min_players:
		start_reject_reason = StartRejectReason.TOO_FEW_PLAYERS
		print_verbose("Rejecting start: too few players (%d), need %d." % [
			_players.size(),
			Globals.items_db.events[selected_event].min_players,
		])
	elif _players.size() > Globals.items_db.events[selected_event].max_players:
		start_reject_reason = StartRejectReason.TOO_MANY_PLAYERS
		print_verbose("Rejecting start: too many players (%d), max %d." % [
			_players.size(),
			Globals.items_db.events[selected_event].max_players,
		])
	elif _players.size() % Globals.items_db.events[selected_event].players_divider != 0:
		start_reject_reason = StartRejectReason.INDIVISIBLE_NUMBER_OF_PLAYERS
		print_verbose("Rejecting start: indivisible number of players (%d), must divide on %d." % [
			_players.size(),
			Globals.items_db.events[selected_event].players_divider,
		])
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
	data.append(_players.size())
	data.append(_game.max_players)
	data.append(selected_event)
	data.append_array(Globals.get_string("player_name", "Server").to_utf8_buffer()) # Имя
	for peer: PacketPeerUDP in _udp_peers:
		peer.put_packet(data)
	print_verbose("Broadcast of lobby %d done. Data sent: %s (%d/%d), event: %s (ID: %d)." % [
		_broadcast_lobby_id,
		Globals.get_string("player_name", "Server"),
		_players.size(),
		_game.max_players,
		Globals.items_db.events[selected_event].name,
		selected_event,
	])


func _process_console_command(command: PackedStringArray) -> bool:
	if _game.state != Game.State.LOBBY:
		return false
	var recognized := false
	if command[0] == "list-players" and command.size() == 1:
		recognized = true
		if not multiplayer.is_server():
			printerr("This command only available on server.")
			return recognized
		print("Connected players:")
		for id: int in _players:
			prints(id, _players[id])
		if _admin_id in _players:
			print("Current admin: %d (%s)." % [_admin_id, _players[_admin_id]])
		else:
			print("Current admin: %d." % _admin_id)
		if Globals.headless:
			print("Server ID is always 1.")
	elif command[0] == "set-environment" and command.size() < 4:
		recognized = true
		if not _admin:
			printerr("This command only available for admins.")
			return recognized
		if command.size() == 2:
			_request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, int(command[1]), 0)
		else:
			_request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, int(command[1]),
					int(command[2]))
	elif command[0] == "start" and command.size() == 1:
		recognized = true
		if not _admin:
			printerr("This command only available for admins.")
			return recognized
		_request_start_event.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
	elif (command[0] == "admin" or command[0] == "admin-id") and command.size() < 3:
		recognized = true
		if not _admin and not multiplayer.is_server():
			printerr("This command only available for admins.")
			return recognized
		if command.size() == 1:
			_request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					MultiplayerPeer.TARGET_PEER_SERVER, AdminAction.TRANSFER_ADMIN_RIGHTS)
		else:
			var id: int
			if command[0] == "admin":
				id = _get_player_id(command[1])
			else:
				id = int(command[1])
			_request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, AdminAction.TRANSFER_ADMIN_RIGHTS)
	elif (command[0] == "kick" or command[0] == "kick-id") and command.size() == 2:
		recognized = true
		if not _admin:
			printerr("This command only available for admins.")
			return recognized
		var id: int
		if command[0] == "kick":
			id = _get_player_id(command[1])
		else:
			id = int(command[1])
		_request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				id, AdminAction.KICK)
	elif (command[0] == "ban" or command[0] == "ban-id") and command.size() == 2:
		recognized = true
		if not _admin:
			printerr("This command only available for admins.")
			return recognized
		var id: int
		if command[0] == "ban":
			id = _get_player_id(command[1])
		else:
			id = int(command[1])
		_request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				id, AdminAction.BAN)
	
	return recognized


func _print_help() -> void:
	# Помошь по post здесь, потому что в Chat она будет дублироваться
	if _game.state != Game.State.LOBBY:
		if _game.state == Game.State.EVENT:
			print("post <message> - Posts message in chat.")
		return
	print("post <message> - Posts message in chat.")
	print("list-players - List all connected players. Works only on server.")
	print("These commands only available if you are admin:")
	print("set-environment <event-id> [map-id] - Sets event and map to specified values.")
	print("start - Starts event.")
	print("admin [player] - Makes specified player admin. Current admin loses his rights. \
Note: you can always set admin to yourself if you are server.")
	print("admin-id [id] - Same as admin, but uses player ID.")
	print("kick <player> - Kicks specified player.")
	print("kick-id <id> - Same as kick, but uses player ID.")
	print("ban <player> - Bans specified player.")
	print("ban-id <id> - Same as ban, but uses player ID.")


func _get_player_id(player: String) -> int:
	for id: int in _players:
		if _players[id].begins_with(player):
			return id
	return -1


func _on_client_timer_timeout(id: int) -> void:
	(multiplayer as SceneMultiplayer).disconnect_peer(id)
	push_warning("Peer %d kicked for inactivity." % id)
	_client_timers[id].queue_free()
	_client_timers.erase(id)


func _on_game_created() -> void:
	show()
	(%ControlButtons/ConnectedToIP as CanvasItem).hide()
	(%ControlButtons/ViewIP as CanvasItem).show()
	_players.clear()
	if Globals.get_setting_bool("broadcast"):
		($BroadcastTimer as Timer).start()
		($UpdateBroadcastTimer as Timer).start()
		_broadcast_lobby_id = Globals.get_string("player_name", "Server").hash() \
				* OS.get_unique_id().hash() + OS.get_process_id()
		_broadcast_lobby_id %= 256
		_do_broadcast()
	if not Globals.headless:
		_register_new_player.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
				Globals.get_string("player_name"))


func _on_game_joined() -> void:
	show()
	(%AdminPanel as CanvasItem).hide()
	(%ClientHint as CanvasItem).show()
	(%ControlButtons/ConnectedToIP as CanvasItem).show()
	(%ControlButtons/ConnectedToIP as LinkButton).text = "Подключено к %s" % \
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(
			MultiplayerPeer.TARGET_PEER_SERVER).get_remote_address()
	(%ControlButtons/ViewIP as CanvasItem).hide()
	(%ClientHint as Label).text = "Ожидание сервера..."
	_register_new_player.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
			Globals.get_string("player_name"))


func _on_game_closed() -> void:
	hide()
	_item_selector.hide()
	
	if not ($BroadcastTimer as Timer).is_stopped():
		($BroadcastTimer as Timer).stop()
	if not ($UpdateBroadcastTimer as Timer).is_stopped():
		($UpdateBroadcastTimer as Timer).stop()
	if not _countdown_timer.is_stopped():
		_countdown_timer.stop()
	_hide_countdown()
	
	for entry: Node in _players_container.get_children():
		entry.queue_free()
	
	_chat.clear_chat()
	(%ControlButtons/Chat as BaseButton).button_pressed = false


func _on_game_started() -> void:
	_hide_countdown()
	hide()


func _on_game_ended() -> void:
	show()
	if multiplayer.is_server():
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
	_chat.post_message.rpc("> [color=green]%s[/color] отключается!" % _players[id])
	_unregister_player(id)


func _on_admin_actions_menu_id_pressed(action: AdminAction, peer: int) -> void:
	_request_admin_action.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, peer, action)


func _on_countdown_timer_timeout() -> void:
	print_verbose("Countdown ended.")
	var start_reject_reason: StartRejectReason = _get_start_reject_reason()
	if start_reject_reason != StartRejectReason.OK:
		_hide_countdown.rpc()
		_reject_start_event.rpc_id(_admin_id, start_reject_reason, _players.size())
		return
	
	print_verbose("Starting...")
	_start_event.rpc(selected_event, selected_map)


func _on_start_event_pressed() -> void:
	_request_start_event.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _on_leave_pressed() -> void:
	_game.close()


func _on_connected_to_ip_pressed() -> void:
	DisplayServer.clipboard_set((multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(
			MultiplayerPeer.TARGET_PEER_SERVER).get_remote_address())


func _on_change_event_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.EVENT, selected_event)
	_item_selector.title = "Выбор события"
	_item_selector.popup_centered()


func _on_change_map_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.MAP, selected_map, selected_event)
	_item_selector.title = "Выбор карты"
	_item_selector.popup_centered()


func _on_change_skin_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.SKIN, selected_skin)
	_item_selector.title = "Выбор скина"
	_item_selector.popup_centered()


func _on_change_skill_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.SKILL, selected_skill)
	_item_selector.title = "Выбор навыка"
	_item_selector.popup_centered()


func _on_change_light_weapon_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.WEAPON_LIGHT, selected_light_weapon)
	_item_selector.title = "Выбор лёгкого оружия"
	_item_selector.popup_centered()


func _on_change_heavy_weapon_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.WEAPON_HEAVY, selected_heavy_weapon)
	_item_selector.title = "Выбор тяжёлого оружия"
	_item_selector.popup_centered()


func _on_change_support_weapon_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.WEAPON_SUPPORT, selected_support_weapon)
	_item_selector.title = "Выбор оружия поддержки"
	_item_selector.popup_centered()


func _on_change_melee_weapon_pressed() -> void:
	_items_grid.list_items(ItemsDB.Item.WEAPON_MELEE, selected_melee_weapon)
	_item_selector.title = "Выбор ближнего оружия"
	_item_selector.popup_centered()


func _on_item_selected(type: ItemsDB.Item, id: int) -> void:
	_item_selector.hide()
	match type:
		ItemsDB.Item.EVENT:
			_request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER,
					id, selected_maps[id])
			return
		ItemsDB.Item.MAP:
			_request_set_environment.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, selected_event, id)
			return
		ItemsDB.Item.SKIN:
			selected_skin = id
		ItemsDB.Item.SKILL:
			selected_skill = id
		ItemsDB.Item.WEAPON_LIGHT:
			selected_light_weapon = id
		ItemsDB.Item.WEAPON_HEAVY:
			selected_heavy_weapon = id
		ItemsDB.Item.WEAPON_SUPPORT:
			selected_support_weapon = id
		ItemsDB.Item.WEAPON_MELEE:
			selected_melee_weapon = id
	_save_selected_items()
	_update_equip()
