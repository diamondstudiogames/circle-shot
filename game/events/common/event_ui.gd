class_name EventUI
extends CanvasLayer

## Интерфейс события.

## Максимум видимых сообщений чата в предпросмотре.
@export var messages_visible_limit: int = 4
## Время, в течении которого сообщения чата видно в предпросмотре.
@export var messages_visible_time := 3.0
## Чат.
@onready var chat: Chat = $Main/ChatPanel
@onready var _chat_button: Button = chat.get_node(chat.chat_button_path)


func _ready() -> void:
	($QuitDialog as AcceptDialog).dialog_text = "Ты действительно хочешь покинуть игру?"
	if multiplayer.is_server():
		($QuitDialog as AcceptDialog).dialog_text += "\nВнимание: ты являешься ХОСТОМ! \
В случае твоего выхода игра прервётся у ВСЕХ!"
	
	if Globals.get_setting_bool("minimap"):
		($MinimapViewport as SubViewport).world_2d = get_viewport().find_world_2d()
	else:
		($MinimapViewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		($Main/Minimap as CanvasItem).hide()


func _input(event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if event.is_action_pressed(&"close_chat") and _chat_button.button_pressed:
		_chat_button.button_pressed = false


func _unhandled_input(event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if event.is_action_pressed(&"chat") and not _chat_button.button_pressed:
		_chat_button.button_pressed = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			($QuitDialog as Window).popup_centered()


func show_intro() -> void:
	($Intro/AnimationPlayer as AnimationPlayer).play(&"Intro")
	($Intro/AnimationPlayer as AnimationPlayer).advance(0.0) # костыль


func seek_intro(at_time: float) -> void:
	($Intro/AnimationPlayer as AnimationPlayer).seek(at_time)


func _on_message_posted(message: String) -> void:
	if _chat_button.button_pressed or not _chat_button.visible:
		return
	if $Main/ChatPreview.get_child_count() >= messages_visible_limit:
		$Main/ChatPreview.get_child(0).queue_free()
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.fit_content = true
	rtl.text = message
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.add_theme_constant_override(&"outline_size", 4)
	rtl.add_theme_color_override(&"default_color", Color.WHITE)
	$Main/ChatPreview.add_child(rtl)
	var tween: Tween = rtl.create_tween()
	tween.tween_interval(messages_visible_time)
	tween.tween_property(rtl, ^":modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(rtl.queue_free)


func _on_chat_toggled(toggled_on: bool) -> void:
	if toggled_on:
		for rtl: Node in $Main/ChatPreview.get_children():
			rtl.queue_free()


func _on_quit_dialog_confirmed() -> void:
	Globals.main.game.close()
