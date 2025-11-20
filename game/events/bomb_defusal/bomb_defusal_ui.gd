class_name BombDefusalUI
extends EventUI

## Интерфейс события "Закладка бомбы".

## Устанавливает счёт команд (т.е. количество выигранных раундов).
func set_score(red: int, blue: int) -> void:
	($Main/RedCount as Label).text = str(red)
	($Main/BlueCount as Label).text = str(blue)


## Показывает победившую команду.
func show_winner(blue_won: bool) -> void:
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"victory")
	($Main/GameEnd/Team as Label).text = "Синяя" if blue_won else "Красная"
	($Main/GameEnd/Team as Control).add_theme_color_override(&"font_color",
			Entity.TEAM_COLORS[int(blue_won)])


## Показывает результат раунда ("Раунд выигран/проигран!").
func show_round_end(won: bool) -> void:
	($Main/RoundEnd/AnimationPlayer as AnimationPlayer).play(&"round_end")
	($Main/RoundEnd/AnimationPlayer as AnimationPlayer).seek(0.0)
	($Main/RoundEnd as Label).text = "Раунд выигран!" if won else "Раунд проигран!"


## Показывает состояние бомбы: "Бомба была заложена!", если [param defused] равен
## [code]false[\code], иначе "Бомба быда обезврежена!".
func show_bomb_state(defused: bool) -> void:
	($Main/BombState as Label).add_theme_color_override(&"font_color",
			Color.LIME_GREEN if defused else Color.RED)
	($Main/BombState as Label).text = \
			"Бомба была обезврежена!" if defused else "Бомба была заложена!"
	($Main/BombState/AnimationPlayer as AnimationPlayer).play(&"bomb_state")
	($Main/BombState/AnimationPlayer as AnimationPlayer).seek(0.0)


## Устанавливает время на таймере сверху. Если [param bomb] равен [code]true[/code], таймер
## отображается в виде "Взрыв через Х:ХХ" и становится красного цвета.
func set_time(time: int, bomb: bool) -> void:
	var time_str: String = "%d:%02d" % [floori(time / 60.0), time % 60]
	if bomb:
		($Main/Timer as Label).text = "Взрыв через %s" % time_str
		($Main/Timer as Label).add_theme_color_override(&"font_color", Color.RED)
	else:
		($Main/Timer as Label).text = time_str
		($Main/Timer as Label).remove_theme_color_override(&"font_color")
