class_name Interactible
extends Area2D

## Объект, с которым можно взаимодействовать.
##
## По умолчанию не несёт в себе формы столкновения, добавьте её вручную дочерним
## [CollisionShape2D].

## Издаётся после успешного взаимодействия. В [param who] хранится игрок,
## который провзаимодействовал.
signal interacted(who: Player)

## Название действия взаимодействия (клавиатура и мышь).
const INTERACT_ACTION_NAME_KEYBOARD_AND_MOUSE := &"interact"
## Название действия взаимодействия (контроллер).
const INTERACT_ACTION_NAME_CONTROLLER := &"c_interact"

## Текст, появляющийся над стрелкой взаимодействия.
@export_multiline var text: String
## Время, которое должна быть зажата кнопка для взаимодействия.
@export var hold_interaction_time := -1.0

var _players: Array[Player]
var _local_player: Player
var _hold_interaction_timers: Dictionary[Player, float]
var _arrow_tween: Tween
var _interact_tween: Tween

@onready var _label: Label = $Visual/Label
@onready var _interact_info: Label = $Visual/Label/InteractInfo
@onready var _arrow: Sprite2D = $Visual/Arrow
@onready var _hold_timer_progress: TextureProgressBar = $Visual/Label/InteractInfo/HoldTimerProgress
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	_visual.hide()
	set_text(text)
	Globals.input_method_changed.connect(_update_interact_info)


func _process(delta: float) -> void:
	if _hold_interaction_timers.is_empty():
		return
	
	for player: Player in _hold_interaction_timers.keys():
		if not _can_player_interact(player):
			_hold_interaction_timers.erase(player)
			if player == _local_player:
				_reset_hold_interaction()
			continue
		_hold_interaction_timers[player] -= delta
		if player == _local_player:
			_hold_timer_progress.value = 1.0 - _hold_interaction_timers[player] \
					/ hold_interaction_time
			_hold_timer_progress.self_modulate = \
					Color.WHITE.lerp(Color.GREEN, _hold_timer_progress.value)
		
		if _hold_interaction_timers[player] <= 0.0:
			_interact(player)
			_hold_interaction_timers.erase(player)
			if player == _local_player:
				_reset_hold_interaction()


## Задаёт текст над стрелкой взаимодействия.
func set_text(new_text: String) -> void:
	_label.text = new_text
	_update_interact_info()


func _interact(player: Player) -> void:
	interacted.emit(player)
	if player != _local_player:
		return
	
	if is_instance_valid(_interact_tween):
		_interact_tween.kill()
	_interact_tween = create_tween()
	_interact_tween.tween_property(_arrow, ^":self_modulate", Color.WHITE, 0.5).from(Color.GREEN)


func _reset_hold_interaction() -> void:
	_hold_timer_progress.value = 0.0
	_hold_timer_progress.self_modulate = Color.WHITE


func _update_interact_info() -> void:
	var action: StringName
	var events: Array[String]
	match Globals.get_current_input_method():
		Globals.InputMethod.KEYBOARD_AND_MOUSE:
			action = INTERACT_ACTION_NAME_KEYBOARD_AND_MOUSE
		Globals.InputMethod.CONTROLLER:
			action = INTERACT_ACTION_NAME_CONTROLLER
	if not action.is_empty():
		var event_types: Array[Globals.EncodedInputEventType] = \
				Globals.get_controls_variant("action_%s_event_types" % action, [] as Array[int]) 
		var event_values: Array[int] = \
				Globals.get_controls_variant("action_%s_event_values" % action, [] as Array[int])
		for i: int in event_types.size():
			events.append(Utils.encoded_input_event_as_text(event_types[i], event_values[i]))
	
	if events.is_empty():
		if hold_interaction_time > 0.0:
			_interact_info.text = "(удерживай)\n"
		else:
			_interact_info.text = ""
	else:
		if hold_interaction_time > 0.0:
			_interact_info.text = "(%s - удерживай)\n" % '/'.join(events)
		else:
			_interact_info.text = "(%s)\n" % '/'.join(events)


## Метод для переопределения. Если он возвращает [code]false[/code], игрок будет видеть, что можно
## провзаимодействовать с этим объектом, но не сможет этого сделать, а текущий прогресс (в случае
## с продолжительным взаимодействием) сбросится, если в прошлый кадр метод возвращал
## [code]true[/code].
func _can_player_interact(_player: Player) -> bool:
	return true


## Метод для переопределения. Если он возвращает [code]true[/code], этот предмет будет полностью
## игнорировать этого игрока.
func _should_ignore_player(_player: Player) -> bool:
	return false


func _on_player_input_interaction_started(player: Player) -> void:
	if hold_interaction_time < 0.0 and _can_player_interact(player):
		_interact(player)
		return
	_hold_interaction_timers[player] = hold_interaction_time


func _on_player_input_interaction_ended(player: Player) -> void:
	if hold_interaction_time < 0.0:
		return
	if player == _local_player:
		_reset_hold_interaction()
	_hold_interaction_timers.erase(player)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return
	if _should_ignore_player(player):
		return
	
	player.player_input.interaction_started.connect(
			_on_player_input_interaction_started.bind(player))
	player.player_input.interaction_ended.connect(
			_on_player_input_interaction_ended.bind(player))
	if player.is_local():
		player.player_input.add_interactible()
		_visual.show()
		_arrow_tween = create_tween()
		_arrow.position = Vector2.UP * 24
		_arrow_tween.tween_property(_arrow, ^":position", Vector2.UP * 16, 1.0)
		_arrow_tween.tween_property(_arrow, ^":position", Vector2.UP * 24, 1.0)
		_arrow_tween.set_loops(0)
		_local_player = player
	
	_players.append(player)


func _on_body_exited(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return
	if not player in _players:
		return
	
	player.player_input.interaction_started.disconnect(
			_on_player_input_interaction_started)
	player.player_input.interaction_ended.disconnect(
			_on_player_input_interaction_ended)
	if player == _local_player:
		player.player_input.remove_interactible()
		_visual.hide()
		_arrow_tween.kill()
		_local_player = null
		_reset_hold_interaction()
	
	_hold_interaction_timers.erase(player)
	_players.erase(player)
