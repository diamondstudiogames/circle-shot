class_name DuelUI
extends EventUI

## Интерфейс события "Дуэль".

## Устанавливает количество раундов для победы, отображая его под счётом.
func set_rounds_to_win(rounds_to_win: int) -> void:
	($Main/RedCount/ToWin as Label).text = "/%d" % rounds_to_win
	($Main/BlueCount/ToWin as Label).text = "/%d" % rounds_to_win


## Устанавливает количество выигранных раундов. [param red] содержит счёт красной команды,
## [param blue] - синей.
func set_rounds_won(red: int, blue: int) -> void:
	($Main/RedCount as Label).text = str(red)
	($Main/BlueCount as Label).text = str(blue)


## Начинает раунд.
func start_round() -> void:
	($Main/RoundEnd as CanvasItem).hide()


## Заканчивает раунд. [param winner] - ID победителя, [param end] означает конец события.
func end_round(winner: int, end := false) -> void:
	if end:
		if winner == multiplayer.get_unique_id():
			($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"victory")
			($Main/GameEnd as Label).text = "ПОБЕДА!"
		else:
			($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"defeat")
			($Main/GameEnd as Label).text = "ПОРАЖЕНИЕ!"
		return
	($Main/RoundEnd as CanvasItem).show()
	if winner == multiplayer.get_unique_id():
		($Main/RoundEnd as Label).text = "Раунд выигран!"
	else:
		($Main/RoundEnd as Label).text = "Раунд проигран!"
