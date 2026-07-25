class_name Chat
extends PanelContainer

## Чат для общения.
##
## Используйте [member players_names] и [member players_teams] (второе необязательно)
## для регистрации игроков перед тем, как они начнут отправлять сообщения.

## Издаётся когда в чате появляется новое сообщение с текстом [param message].
signal message_posted(message: String)
## Максимальная длина сообщения.
const MAX_MESSAGE_LENGTH: int = 80
## Путь к кнопке, которая будет моргать при новом сообщении.
@export_node_path("Button") var chat_button_path: NodePath
## Словарь имён игроков, в формате <ID> - <имя>.
var players_names: Dictionary[int, String]
## Словарь команд игроков, в формате <ID> - <команда>. Используется для раскраски ников.
var players_teams: Dictionary[int, Entity.Team]
@onready var _chat_button: Button = get_node(chat_button_path)
@onready var _messages: RichTextLabel = $VBoxContainer/Messages
@onready var _chat_edit: LineEdit = $VBoxContainer/HBoxContainer/LineEdit


func _ready() -> void:
	if Globals.console:
		Globals.console.command_processors.append(_process_command)


func _exit_tree() -> void:
	if Globals.console:
		Globals.console.command_processors.erase(_process_command)


## Постит сообщение. Должно вызываться только сервером.
@rpc("call_local", "authority", "reliable", 2)
func post_message(message: String) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_messages.append_text(message + '\n')
	message_posted.emit(message)
	print_verbose('Posted message: "%s".' % message)
	if not visible:
		var tween: Tween = create_tween()
		tween.tween_property(_chat_button, ^":self_modulate", Color.GREEN, 0.25)
		tween.tween_property(_chat_button, ^":self_modulate", Color.WHITE, 0.25)


## Очищает чат.
func clear_chat() -> void:
	_messages.text = ""


## Отправляет набранное сообщение. Автоматически очищает от лишних пробелов и прочих знаков.
func send_message() -> void:
	var message: String = Utils.strip_string(_chat_edit.text)
	_chat_edit.clear()
	_chat_edit.edit.call_deferred()
	
	if message.is_empty():
		return
	_request_post_message.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, message)
	print_verbose('Sent message: "%s".' % message)


@rpc("any_peer", "call_local", "reliable", 2)
func _request_post_message(message: String) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not sender_id in players_names:
		push_warning("Received post message request from unknown peer (%d)." % sender_id)
		return
	
	message = Utils.strip_string(message).replace("[", "[lb]")
	if message.is_empty():
		return
	if message.length() > MAX_MESSAGE_LENGTH:
		push_warning("Player %d posted message with length %d, which is more than allowed (%d)." % [
			sender_id,
			message.length(),
			MAX_MESSAGE_LENGTH,
		])
		message = message.left(MAX_MESSAGE_LENGTH)
	if sender_id in players_teams:
		message = "[outline_size=4][color=#%s]%s[/color][/outline_size]: %s" % [
			Entity.TEAM_COLORS[players_teams[sender_id]].to_html(false),
			players_names[sender_id],
			message,
		]
	else:
		message = "[outline_size=4][color=red]%s[/color][/outline_size]: %s" \
				% [players_names[sender_id], message]
	post_message.rpc(message)


func _process_command(command: PackedStringArray) -> bool:
	if not Globals.main.game.state in [Game.State.EVENT, Game.State.LOBBY]:
		return false
	if command[0] == "post" and command.size() > 1:
		if multiplayer.is_server() and Globals.headless:
			players_names[1] = Globals.get_string("player_name", "Server")
		_request_post_message.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, ' '.join(command.slice(1)))
		if multiplayer.is_server() and Globals.headless:
			players_names.erase(1)
		return true
	return false


func _on_chat_toggled(toggled_on: bool) -> void:
	visible = toggled_on
	if toggled_on:
		_chat_edit.grab_focus()
