class_name DemonFightUI
extends ChallengeUI

## Интерфейс испытания "Битва с демоном".

## Издаётся при окончании диалога.
signal dialog_shown

## Интервал между появлениями символов на экране.
@export var character_type_interval := 0.02
## Длительность грамматической паузы (запятые, точки, ...).
@export var grammar_pause := 0.5

var _characters_count: int
var _time_remainder := 0.0
var _parsed_text: String
@onready var _rtl: RichTextLabel = $RichTextLabel


func _process(delta: float) -> void:
	if _rtl.visible_characters != -1:
		_time_remainder += delta
		while _time_remainder >= character_type_interval:
			_rtl.visible_characters += 1
			if _rtl.visible_characters >= _characters_count:
				_rtl.visible_characters = -1
				dialog_shown.emit()
				return
			if _parsed_text[_rtl.visible_characters - 1] in [',', '.', '-', ';', ':']:
				_time_remainder -= grammar_pause
			_time_remainder -= character_type_interval


## Задаёт босса для полоски здоровья.
func set_boss(boss: Entity) -> void:
	($Main/BossHealthBar as BossHealthBar).set_boss(boss, "Козёл")
	($Main/BossHealthBar as CanvasItem).show()
	($Main/BossHealthBar as CanvasItem).modulate = Color.TRANSPARENT
	
	var tween: Tween = create_tween()
	tween.tween_property($Main/BossHealthBar as CanvasItem, ^":modulate", Color.WHITE, 0.5)


## Показывает диалог с текстом [param text].
func show_dialog(text: String) -> void:
	_rtl.text = text
	_rtl.visible_characters = 0
	_parsed_text = _rtl.get_parsed_text()
	_characters_count = _parsed_text.length()
	_time_remainder = 0.0
