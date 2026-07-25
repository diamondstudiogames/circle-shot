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


## Начинает раунд с номером [param round_num].
func start_round(round_num: int) -> void:
	($Main/RoundInfo/AnimationPlayer as AnimationPlayer).play(&"round_start")
	($Main/RoundInfo as Label).text = "Раунд %d начался!" % round_num


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
	($Main/RoundInfo/AnimationPlayer as AnimationPlayer).play(&"round_end")
	if winner == multiplayer.get_unique_id():
		($Main/RoundInfo as Label).text = "Раунд выигран!"
	else:
		($Main/RoundInfo as Label).text = "Раунд проигран!"
