class_name DuelUI
extends EventUI

## Интерфейс события "Дуэль".

## Начинает раунд с индексом [param idx].
func start_round(idx: int) -> void:
	($Main/RoundEnd as CanvasItem).hide()
	(get_node("Main/Round%d" % idx) as CanvasItem).modulate = Color.WHITE


## Заканчивает раунд с индексом [param idx]. [param win_team] должен сожержать победившую команду,
## [param winner] - ID победителя, [param end] означает конец события.
func end_round(idx: int, win_team: int, winner: int, end := false) -> void:
	var round_tex: TextureRect = get_node("Main/Round%d" % idx)
	round_tex.modulate = Entity.TEAM_COLORS[win_team]
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
