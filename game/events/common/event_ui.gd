class_name EventUI
extends CanvasLayer

## Интерфейс события.

## Максимум видимых сообщений чата в предпросмотре.
@export var messages_visible_limit: int = 4
## Время, в течении которого сообщения чата видно в предпросмотре.
@export var messages_visible_time := 3.0

var _reward_scene: PackedScene = load("uid://b1ipe4g6uueie")

## Чат.
@onready var chat: Chat = $Main/ChatPanel
## Ссылка на [Event].
@onready var event: Event = get_parent()

@onready var _chat_button: Button = chat.get_node(chat.chat_button_path)
@onready var _rewards_total: Label = %Rewards/Total/Count
@onready var _emotions_container: VFlowContainer = %EmotionsContainer


func _ready() -> void:
	if not Globals.get_setting_bool("chat_in_game"):
		($Main/Chat as CanvasItem).hide()
		return
	for idx: int in event.emotions.size():
		var button := Button.new()
		button.name = "Emotion%d" % idx
		button.icon = event.emotions[idx]
		button.add_theme_constant_override(&"icon_max_width", 64)
		button.pressed.connect(_on_emotion_button_pressed.bind(idx))
		_emotions_container.add_child(button)


func _input(input_event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if _chat_button.button_pressed:
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE \
				and input_event.is_action_pressed(&"pause"):
			_chat_button.button_pressed = false
			get_viewport().set_input_as_handled()
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER \
				and input_event.is_action_pressed(&"c_pause"):
			_chat_button.button_pressed = false
			get_viewport().set_input_as_handled()


func _unhandled_input(input_event: InputEvent) -> void:
	if not _chat_button.visible:
		return
	if not _chat_button.button_pressed:
		if Globals.get_current_input_method() == Globals.InputMethod.KEYBOARD_AND_MOUSE \
				and input_event.is_action_pressed(&"chat"):
			_chat_button.button_pressed = true
			get_viewport().set_input_as_handled()
		elif Globals.get_current_input_method() == Globals.InputMethod.CONTROLLER \
				and input_event.is_action_pressed(&"c_chat"):
			_chat_button.button_pressed = true
			get_viewport().set_input_as_handled()


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
	var current_coins: int = Globals.get_int("coins") - total # монеты уже добавлены
	_rewards_total.text = "%d (+%d)" % [current_coins, 0]
	
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
	tween.tween_method(func(val: int) -> void: 
		_rewards_total.text = "%d (+%d)" % [current_coins + val, val], 0, total, 1.0)
	tween.tween_interval(3.5)
	tween.tween_property($Main/RewardsPanel as CanvasItem, ^":modulate", Color.TRANSPARENT, 0.4)


func _on_emotion_button_pressed(idx: int) -> void:
	_chat_button.button_pressed = false
	event.send_emotion(idx)


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


func _on_quit_pressed() -> void:
	if multiplayer.is_server():
		($PauseDialog/QuitDialog as Window).popup_centered()
	else:
		_on_quit_dialog_confirmed()


func _on_quit_dialog_confirmed() -> void:
	Globals.main.game.close()
