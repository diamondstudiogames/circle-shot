class_name BombDefusalUI
extends EventUI
## Интерфейс события "Закладка бомбы".

var _spectating_player: Player
var _alive_players: Array[Player]

## Устанавливает счёт команд (т.е. количество выигранных раундов).
func set_score(red: int, blue: int) -> void:
	($Main/RedCount as Label).text = str(red)
	($Main/BlueCount as Label).text = str(blue)


## Устанавливает количество раундов для победы, отображая его под счётом.
func set_rounds_to_win(rounds_to_win: int) -> void:
	($Main/RedCount/ToWin as Label).text = "/%d" % rounds_to_win
	($Main/BlueCount/ToWin as Label).text = "/%d" % rounds_to_win


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


## Задаёт видимость интерфейса наблюдения.
func set_spectate_visible(visibility: bool) -> void:
	($Main/SpectatorMenu as CanvasItem).visible = visibility


## Убивает игрока. Используется для функции наблюдения. [param alive_players] - список живых
## игроков, за которыми можно вести наблюдение (чаще всего товарищи по команде),
## [param who] - ID убитого.
func kill_player(who: int, alive_players: Array[int]) -> void:
	if Globals.headless:
		return
	
	_alive_players.clear()
	for id: int in alive_players:
		_alive_players.append(event.players[id])
	if (
			is_instance_valid(_spectating_player) and who != _spectating_player.id \
			and _spectating_player.id in alive_players
			or _alive_players.is_empty()
	):
		return
	_set_player_to_spectate(randi() % _alive_players.size())


## Перейти к следующему игроку при наблюдении.
func next_player() -> void:
	var new_id: int = (_alive_players.find(_spectating_player) + 1) % _alive_players.size()
	_set_player_to_spectate(new_id)


## Перейти к предыдущему игроку при наблюдении.
func previous_player() -> void:
	var new_id: int = (_alive_players.find(_spectating_player) + _alive_players.size() - 1) \
			% _alive_players.size()
	_set_player_to_spectate(new_id)


func _set_player_to_spectate(idx: int) -> void:
	_spectating_player = _alive_players[idx]
	(%SpectatingName as Label).text = _spectating_player.player_name
	(get_viewport().get_camera_2d() as SmartCamera).target = _spectating_player


func _on_local_player_created(player: Player) -> void:
	super(player)
	_spectating_player = player
