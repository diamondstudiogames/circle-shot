class_name Duel
extends Event

## Событие "Дуэль".

## Издаётся когда раунд начался.
signal round_started
## Издаётся когда раунд закончился. [param team_won] - ID победившей команды.
signal round_ended(team_won: int)

## Сколько монет получает игрок за убийство противника.
@export var coins_for_kill: int = 10
## Сколько монет получает игрок за выигранный раунд.
@export var coins_for_won_round: int = 40
## Сколько монет получает игрок за проигранный раунд.
@export var coins_for_lost_round: int = 20
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin: int = 10

## Количество раундов, выигранных красной командой.
var red_rounds_won: int = 0
## Количество раундов, выигранных синей командой.
var blue_rounds_won: int = 0
## Текущий раунд, от 0 до 2. 3 означает конец игры.
var current_round: int = 0

var _poison_smokes_scene: PackedScene = preload("uid://cp5ag64gc1s3k")

@onready var _duel_ui: DuelUI = $UI


func _make_teams() -> void:
	var prev_team: int = -1
	var players_ids: Array[int] = players_names.keys()
	players_ids.shuffle()
	for player: int in players_ids:
		if prev_team < 0:
			players_teams[player] = randi() % 2
			prev_team = players_teams[player]
		else:
			players_teams[player] = 1 - prev_team


func _finish_start() -> void:
	if multiplayer.is_server():
		_start_round.rpc()


func _get_spawn_point(id: int) -> Vector2:
	if players_teams[id] == 0:
		return ($Map/SpawnPoint0 as Node2D).global_position
	else:
		return ($Map/SpawnPoint1 as Node2D).global_position


func _customize_player(player: Player) -> void:
	match current_round:
		0:
			player.equip_data[3] = -1
		1:
			player.equip_data[2] = -1
		2:
			player.equip_data[2] = -1
			player.equip_data[3] = -1


func _player_killed(_by: int, player: Player) -> void:
	var team_won: int = 1 - players_teams[player.id]
	if team_won == 1:
		blue_rounds_won += 1
	else:
		red_rounds_won += 1
	_set_rounds_won.rpc(red_rounds_won, blue_rounds_won)
	
	if current_round == 2 or blue_rounds_won >= 2 or red_rounds_won >= 2:
		if blue_rounds_won > red_rounds_won:
			_end_round.rpc(team_won, players_teams.find_key(1), true)
		else:
			_end_round.rpc(team_won, players_teams.find_key(0), true)
	else:
		_end_round.rpc(team_won, players_teams.find_key(team_won))


func _player_disconnected(_id: int) -> void:
	if current_round > 2: # Игра завершена
		return
	if not was_started:
		return
	if players_teams.values()[0] == 0:
		red_rounds_won += 1
	else:
		blue_rounds_won += 1
	_set_rounds_won.rpc(red_rounds_won, blue_rounds_won)
	_end_round.rpc(players_teams.values()[0], players_teams.keys()[0], true)


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	var won_rounds: int = red_rounds_won if local_team == 0 else blue_rounds_won
	var lost_rounds: int = blue_rounds_won if local_team == 0 else red_rounds_won
	if won_rounds == 2 and lost_rounds == 0:
		won_rounds += 1
	elif lost_rounds == 2 and won_rounds == 0:
		lost_rounds += 1
	
	rewards["Результаты раундов"] = won_rounds * coins_for_won_round \
			+ lost_rounds * coins_for_lost_round
	rewards["Убийства"] = kills * coins_for_kill
	rewards["Нанесённый урон"] = roundi(damaged / float(damage_for_coin))
	return rewards


@rpc("reliable", "call_remote", "authority", 3)
func _set_rounds_won(red: int, blue: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	red_rounds_won = red
	blue_rounds_won = blue


@rpc("reliable", "call_local", "authority", 3)
func _start_round() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_duel_ui.start_round(current_round)
	print_verbose("Round %d started." % current_round)
	
	var smokes: Node2D = _poison_smokes_scene.instantiate()
	add_child(smokes)
	var tween: Tween = smokes.create_tween()
	tween.tween_property(smokes, ^":modulate", smokes.modulate, 0.3).from(Color.TRANSPARENT)
	round_started.emit()
	
	if multiplayer.is_server() and players_names.size() == 1:
		_player_disconnected(0)


@rpc("reliable", "call_local", "authority", 3)
func _end_round(win_team: int, winner: int, ends := false) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_duel_ui.end_round(current_round, win_team, winner, ends)
	print_verbose("Round %d ended. Team won: %d." % [current_round, win_team])
	if ends:
		print_verbose("Winner: %d." % winner)
		end_event(winner == multiplayer.get_unique_id())
		current_round = 3
	else:
		current_round += 1
	
	if has_node(^"PoisonSmokes"):
		var tween: Tween = $PoisonSmokes.create_tween()
		tween.tween_property($PoisonSmokes, ^":modulate", Color.TRANSPARENT, 0.3)
		tween.tween_callback($PoisonSmokes.queue_free)
	
	get_tree().call_group(&"player", &"block_weapon_usage")
	get_tree().call_group(&"player", &"make_immobile")
	get_tree().call_group(&"player", &"make_immune")
	get_tree().call_group(&"player", &"block_turning")
	
	round_ended.emit(win_team)
	if not multiplayer.is_server():
		return
	
	await get_tree().create_timer(3.5).timeout
	if ends:
		await get_tree().create_timer(3.0).timeout
	cleanup()
	await get_tree().create_timer(0.5).timeout
	if ends:
		end.rpc()
	elif current_round < 3:
		for player: int in players_names:
			spawn_player(player)
		_start_round.rpc()
