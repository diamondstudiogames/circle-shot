class_name EventUI
extends CanvasLayer

## Интерфейс события.

## Максимум видимых сообщений чата в предпросмотре.
@export var messages_visible_limit: int = 4
## Время, в течении которого сообщения чата видно в предпросмотре.
@export var messages_visible_time := 3.0

var _input_method: Globals.InputMethod
var _reward_scene: PackedScene = preload("uid://b1ipe4g6uueie")

## Чат.
@onready var chat: Chat = $Main/ChatPanel
## Ссылка на [Event].
@onready var event: Event = get_parent()
@onready var _chat_button: Button = chat.get_node(chat.chat_button_path)


func _ready() -> void:
	_input_method = Globals.get_controls_int("input_method") as Globals.InputMethod
	($QuitDialog as AcceptDialog).dialog_text = "Ты действительно хочешь покинуть игру?"
	if multiplayer.is_server():
		($QuitDialog as AcceptDialog).dialog_text += "\nВнимание: ты являешься ХОСТОМ! \
В случае твоего выхода игра прервётся у ВСЕХ!"
	
	if not Globals.get_setting_bool("chat_in_game"):
		($Main/Chat as CanvasItem).hide()


func _input(input_event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if _chat_button.button_pressed:
		if _input_method == Globals.InputMethod.KEYBOARD_AND_MOUSE \
				and input_event.is_action_pressed(&"close_chat"):
			_chat_button.button_pressed = false
		elif _input_method == Globals.InputMethod.CONTROLLER \
				and input_event.is_action_pressed(&"c_close_chat"):
			_chat_button.button_pressed = false


func _unhandled_input(input_event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if not _chat_button.button_pressed:
		if _input_method == Globals.InputMethod.KEYBOARD_AND_MOUSE \
				and input_event.is_action_pressed(&"chat"):
			_chat_button.button_pressed = true
		elif _input_method == Globals.InputMethod.CONTROLLER \
				and input_event.is_action_pressed(&"c_chat"):
			_chat_button.button_pressed = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			($QuitDialog as Window).popup_centered()


## Показывает заставку события.
func show_intro() -> void:
	($Intro/AnimationPlayer as AnimationPlayer).play(&"intro")
	($Intro/AnimationPlayer as AnimationPlayer).advance(0.0) # костыль


## Перемещает анимацию заставки события на указанное время.
func seek_intro(at_time: float) -> void:
	($Intro/AnimationPlayer as AnimationPlayer).seek(at_time)


## Показывает награды из словаря [param rewards]. В [param total] находится сумма полученных монет.
## Для подробностей см. [method Event._get_rewards].
func show_rewards(rewards: Dictionary[String, int], total: int) -> void:
	($Main/RewardsPanel as CanvasItem).show()
	var tween: Tween = create_tween()
	tween.tween_property($Main/RewardsPanel as CanvasItem, ^":modulate", Color.WHITE, 0.5).from(
			Color.TRANSPARENT)
	
	for reason: String in rewards:
		var reward: HBoxContainer = _reward_scene.instantiate()
		(reward.get_node(^"Reason") as Label).text = reason
		(reward.get_node(^"Count") as Label).text = str(rewards[reason])
		reward.modulate = Color.TRANSPARENT
		%Rewards.add_child(reward)
		tween.tween_property(reward, ^":modulate", Color.WHITE, 0.4)
	
	(%Rewards/Total as CanvasItem).move_to_front()
	tween.tween_interval(0.4)
	tween.tween_method(func(val: int) -> void: (%Rewards/Total/Count as Label).text = str(val),
			0, total, 1.0)
	tween.tween_interval(3.5)
	tween.tween_property($Main/RewardsPanel as CanvasItem, ^":modulate", Color.TRANSPARENT, 0.4)


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
