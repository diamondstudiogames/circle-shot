extends CanvasLayer


@export var character_type_interval := 0.02
@export var grammar_pause := 0.5

var _characters_count: int
var _time_remainder := 0.0
var _parsed_text: String

@onready var _remained_time: Label = $Main/RemainedTime
@onready var _rtl: RichTextLabel = $Main/RichTextLabel
@onready var _dialog_timer: Timer = $DialogTimer


func _process(delta: float) -> void:
	if _rtl.visible_characters != -1:
		_time_remainder += delta
		while _time_remainder >= character_type_interval:
			_rtl.visible_characters += 1
			if _rtl.visible_characters == _characters_count:
				_rtl.visible_characters = -1
				return
			if _parsed_text[_rtl.visible_characters - 1] in [',', '.', '-', ';', ':']:
				_time_remainder -= grammar_pause
			_time_remainder -= character_type_interval


func show_dialog(text: String) -> void:
	_rtl.text = text
	_rtl.visible_characters = 0
	_parsed_text = _rtl.get_parsed_text()
	_characters_count = _parsed_text.length()
	_time_remainder = 0.0


func _on_pause_pressed() -> void:
	get_tree().paused = true
	($PauseDialog as Window).popup_centered()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	($PauseDialog as Window).hide()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	Globals.main.game.close()


func _on_cultists_fight_ended(victory: bool) -> void:
	_dialog_timer.start(0.7)
	await _dialog_timer.timeout
	if Globals.get_bool("goat_defeated"):
		if victory:
			show_dialog("Неплохо... Кстати, [color=red]он[/color] просил передать, \
что ты действительно силён.")
		else:
			show_dialog("Ты смог одолеть [color=red]его[/color], но не смог нас? Позор!")
	elif Globals.get_bool("quest_completed"):
		if victory:
			show_dialog("Раз за разом ты побеждаешь нас... \
Лучше попробуй одолеть [color]его[/color].")
		else:
			show_dialog("Странно... Может, в прошлый раз \
ты победил нас [color=yellow]случайно[/color]?")
	else:
		if victory:
			show_dialog("А ты достаточно силён... \
Возможно, [color=red]он[/color] захочет взглянуть на тебя.")
			_dialog_timer.start(4.0)
			await _dialog_timer.timeout
			show_dialog("(появилось новое испытание!)")
		else:
			show_dialog("Ты ещё слишком слаб... Не достоин ты [color=red]его[/color] чести.")
			_dialog_timer.start(3.5)
			await _dialog_timer.timeout
			show_dialog("Возвращайся, как будешь [color=yellow]готов[/color].")


func _on_time_changed(remained_time: int) -> void:
	_remained_time.text = "%d:%02d" % [floori(remained_time / 60.0), remained_time % 60]
