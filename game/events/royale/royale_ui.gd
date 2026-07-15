class_name RoyaleUI
extends EventUI

var _spectating_player: Player
var _alive_players: Array[Player]

## Устанавливает количество живых игроков.
func set_alive_players(count: int) -> void:
	($Main/PlayerCounter as Label).text = str(count)


## Показывает победителя. [param won] - победил ли локальный игрок, [param winner_name] - имя
## победителя.
func show_winner(won: bool, winner_name: String) -> void:
	($Main/GameEnd as Label).text = "ТЫ ПОБЕДИЛ!!!" if won else "ПОБЕДИТЕЛЬ: %s" % winner_name
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"victory")
	($Main/SpectatorMenu as CanvasItem).hide()


## Убивает игрока. Используется для функции наблюдения. [param alive_players] это список живых
## игроков, [param which] - ID убитого, [param killer] - ID убийцы.
func kill_player(alive_players: Array[int], which: int, killer: int) -> void:
	if Globals.headless:
		return
	
	_alive_players.clear()
	for id: int in alive_players:
		_alive_players.append(event.players[id])
	if which != _spectating_player.id and _spectating_player.id in alive_players \
			or _alive_players.is_empty():
		return
	if killer == 0:
		_set_player_to_spectate(randi() % _alive_players.size())
		return
	for idx: int in _alive_players.size():
		if _alive_players[idx].id == killer:
			_set_player_to_spectate(idx)
			return
	_set_player_to_spectate(randi() % _alive_players.size())


## Показывает поражение.
func show_defeat() -> void:
	($Main/GameEnd as Label).text = "ПОРАЖЕНИЕ!"
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"defeat")
	($Main/SpectatorMenu as CanvasItem).show()


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
