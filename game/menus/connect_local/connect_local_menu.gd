extends Control


var _udp := UDPServer.new()
var _local_lobby_entry_scene: PackedScene = load("uid://bs4vk7wdu27eo")
@onready var _game: Game = get_parent()
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _lobbies_container: VBoxContainer = %LobbiesContainer
@onready var _no_lobbies_label: Label = %NoLobbiesLabel


func _ready() -> void:
	_game.created.connect(_on_game_created)
	_game.joined.connect(_on_game_joined)
	_game.closed.connect(_on_game_closed)
	
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		var clipboard_text: String = \
				_cleanup_address(DisplayServer.clipboard_get().get_slice('\n', 0))
		if Utils.is_valid_address(clipboard_text, false):
			_address_edit.text = clipboard_text
	
	_udp.listen(Game.LISTEN_PORT)
	print_verbose("Started listening.")


func _process(_delta: float) -> void:
	if not _udp.is_listening():
		return
	
	_udp.poll()
	if _udp.is_connection_available():
		var peer: PacketPeerUDP = _udp.take_connection()
		var data: PackedByteArray = peer.get_packet()
		if data.size() < 4:
			print_verbose("Found invalid lobby packet.")
			return
		var id_nodepath := NodePath("Lobby%d" % data[0])
		var player_name: String = Utils.validate_player_name(data.slice(4).get_string_from_utf8())
		var players: int = data[1]
		var max_players: int = data[2]
		if data[3] < 0 or data[3] >= Globals.items_db.events.size():
			print_verbose("Found lobby packet with invalid event index.")
			return
		var event: String = Globals.items_db.events[data[3]].name
		print_verbose("Found lobby: %s (%d/%d) with ID %d with event %s (index: %d) at IP: %s." % [
			player_name,
			players,
			max_players,
			data[0],
			event,
			data[3],
			peer.get_packet_ip(),
		])
		
		if _lobbies_container.has_node(id_nodepath):
			var local_lobby_entry: Button = _lobbies_container.get_node(id_nodepath)
			(local_lobby_entry.get_node(^"Timer") as Timer).start()
			local_lobby_entry.text = "%s (%d/%d)\n%s" % [player_name, players, max_players, event]
			local_lobby_entry.pressed.disconnect(_game.join)
			local_lobby_entry.pressed.connect(_game.join.bind(peer.get_packet_ip()))
			print_verbose("Lobby %d already in list. Updating IP and timer." % data[0])
		else:
			var local_lobby_entry: Button = _local_lobby_entry_scene.instantiate()
			local_lobby_entry.name = id_nodepath.get_concatenated_names() # Конвертация в StringName
			local_lobby_entry.text = "%s (%d/%d)\n%s" % [player_name, players, max_players, event]
			local_lobby_entry.pressed.connect(_game.join.bind(peer.get_packet_ip()))
			_lobbies_container.add_child(local_lobby_entry)
			print_verbose("Lobby %d added to the list." % data[0])
	
	_no_lobbies_label.visible = _lobbies_container.get_child_count() == 0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when _game.state == Game.State.CLOSED:
			_on_quit_pressed.call_deferred() # Избегаем мгновенное закрытие


func _cleanup_address(address: String) -> String:
	address = Utils.strip_string(address)
	if ' ' in address:
		address = address.get_slice(' ', 0)
	
	if address.begins_with("https://"):
		address = address.right(-8) # Длина https://
	if address.begins_with("http://"):
		address = address.right(-7) # Аналогично
	
	if '/' in address:
		address = address.get_slice('/', 0)
	address = Utils.strip_string(address)
	
	# Проверка на указания порта
	if ':' in address:
		var last_colon_idx: int = address.rfind(':')
		var last_bracket_idx: int = address.rfind(']')
		if '.' in address:
			address = address.left(last_colon_idx)
		elif last_bracket_idx > -1 and last_bracket_idx < last_colon_idx:
			address = address.left(last_colon_idx)
		address = Utils.strip_string(address)
	
	# На случай если IPv6
	address = address.lstrip('[')
	address = address.rstrip(']')
	address = Utils.strip_string(address)
	
	return address


func _on_game_created() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_udp.stop()
	print_verbose("Listening stopped.")


func _on_game_joined() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	_udp.stop()
	print_verbose("Listening stopped.")


func _on_game_closed() -> void:
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	_udp.listen(Game.LISTEN_PORT)
	print_verbose("Listening restarted.")


func _on_create_pressed() -> void:
	_game.create()


func _on_join_pressed() -> void:
	_address_edit.text = _cleanup_address(_address_edit.text)
	_game.join(_address_edit.text)


func _on_quit_pressed() -> void:
	Globals.main.open_menu()
