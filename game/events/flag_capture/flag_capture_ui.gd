class_name FlagCaptureUI
extends EventUI

## Интерфейс события "Захват флага".

## Устанавливает счёт команд (т.е. количество захваченных флагов).
func set_flags(red: int, blue: int) -> void:
	($Main/RedCount as Label).text = str(red)
	($Main/BlueCount as Label).text = str(blue)


## Устанавливает количество флагов для победы, отображая его под счётом.
func set_flags_to_win(flags_to_win: int) -> void:
	($Main/RedCount/ToWin as Label).text = "/%d" % flags_to_win
	($Main/BlueCount/ToWin as Label).text = "/%d" % flags_to_win


## Показывает победившую команду. [code]-1[/code] означает ничью.
func show_winner(team: int) -> void:
	if team < 0:
		($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"draw")
		return
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"victory")
	($Main/GameEnd/Team as Label).text = "Красная" if team == 0 else "Синяя"
	($Main/GameEnd/Team as Control).add_theme_color_override(&"font_color",
			Entity.TEAM_COLORS[team])


## Показывает команду, захватившую флаг.
func show_flag_captured(blue: bool) -> void:
	($Main/FlagCaptured/AnimationPlayer as AnimationPlayer).play(&"flag_captured")
	($Main/FlagCaptured/AnimationPlayer as AnimationPlayer).seek(0.0)
	($Main/FlagCaptured/Team as Label).text = "Синих" if blue else "Красных"
	($Main/FlagCaptured/Team as Control).add_theme_color_override(&"font_color",
			Entity.TEAM_COLORS[int(blue)])


## Устанавливает время на таймере сверху.
func set_time(time: int) -> void:
	($Main/Timer as Label).text = "%d:%02d" % [floori(time / 60.0), time % 60]


## Запускает таймер возвращения после смерти длительностью [param time].
func show_comeback(time: int) -> void:
	var comeback: Label = $Main/Comeback
	comeback.show()
	
	var countdown: int = time
	($ComebackTimer as Timer).start()
	while countdown > 0:
		comeback.text = "Возвращение через %d..." % countdown
		await ($ComebackTimer as Timer).timeout
		countdown -= 1
	($ComebackTimer as Timer).stop()
	
	comeback.hide()
