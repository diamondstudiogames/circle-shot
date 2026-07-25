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

## Количество раундов для победы.
var rounds_to_win: int = 2
## Количество раундов, выигранных красной командой.
var red_rounds_won: int = 0
## Количество раундов, выигранных синей командой.
var blue_rounds_won: int = 0
## Текущий раунд. Отсчёт начинается с единицы.
var current_round: int = 0

var _ended := false
var _poison_smokes: PoisonSmokes
var _poison_smokes_scene: PackedScene = load("uid://b4h27swncrquh")

@onready var _duel_ui: DuelUI = $UI


func _initialize() -> void:
	rounds_to_win = parameters["rounds_to_win"]
	_duel_ui.set_rounds_to_win(rounds_to_win)


func _make_teams() -> void:
	var prev_team: int = -1
	for player: int in players_names:
		if prev_team < 0:
			players_teams[player] = randi() % 2
			prev_team = players_teams[player]
		else:
			players_teams[player] = 1 - prev_team


func _finish_start() -> void:
	if multiplayer.is_server():
		_setup_round()
		if players_names.size() != 2:
			_player_disconnected(0)


func _get_spawn_point(id: int) -> Vector2:
	if players_teams[id] == 0:
		return ($Map/SpawnPoint0 as Node2D).global_position
	else:
		return ($Map/SpawnPoint1 as Node2D).global_position


func _customize_player(player: Player) -> void:
	if parameters["weapon_restrictions"] == 0:
		return
	# в момент создания игроков раунд на 1 ниже, чем будет
	var real_round: int = current_round + 1
	if real_round == rounds_to_win * 2 - 1: # последний раунд
		player.equip_data[2] = -1
		player.equip_data[3] = -1
	elif real_round % 2 != 0:
		player.equip_data[3] = -1
	elif real_round % 2 == 0:
		player.equip_data[2] = -1


func _player_killed(_by: int, player: Player) -> void:
	# достаём таким костылём потому что by может быть равным 0
	var players_ids := players_names.keys() as Array[int]
	players_ids.erase(player.id)
	_finish_round(players_ids[0])


func _player_disconnected(_id: int) -> void:
	if _ended or not was_started:
		return
	var remained_player: int = players_names.keys()[0]
	_finish_round(remained_player, true)


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	var won_rounds: int = red_rounds_won if local_team == 0 else blue_rounds_won
	var lost_rounds: int = blue_rounds_won if local_team == 0 else red_rounds_won
	
	rewards["Результаты раундов"] = won_rounds * coins_for_won_round \
			+ lost_rounds * coins_for_lost_round
	rewards["Убийства"] = kills * coins_for_kill
	rewards["Нанесённый урон"] = roundi(damaged / float(damage_for_coin))
	return rewards


func _get_event_status() -> String:
	return "раунд %d" % current_round


func get_game_zone() -> Rect2:
	var map_zone: Rect2 = super()
	if not is_instance_valid(_poison_smokes):
		return map_zone
	var smokes_distance: float = _poison_smokes.get_remained_distance()
	var smokes_zone := Rect2(-Vector2.ONE * smokes_distance, Vector2.ONE * smokes_distance * 2)
	return map_zone.intersection(smokes_zone)


@rpc("reliable", "call_local", "authority", 3)
func _set_rounds_won(red: int, blue: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	red_rounds_won = red
	blue_rounds_won = blue
	_duel_ui.set_rounds_won(red, blue)


@rpc("reliable", "call_local", "authority", 3)
func _start_round() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	current_round += 1
	_duel_ui.start_round(current_round)
	print_verbose("Round %d started." % current_round)
	
	_poison_smokes = _poison_smokes_scene.instantiate()
	_poison_smokes.duration = parameters["smoke_fill_time"]
	_poison_smokes.start_distance = maxi(map.data.size.x, map.data.size.y) * BLOCK_SIZE / 2
	_poison_smokes.start_distance += BLOCK_SIZE * 5 # небольшой запас
	add_child(_poison_smokes)
	var tween: Tween = _poison_smokes.create_tween()
	tween.tween_property(_poison_smokes, ^":modulate",
			_poison_smokes.modulate, 0.3).from(Color.TRANSPARENT)
	round_started.emit()


@rpc("reliable", "call_local", "authority", 3)
func _end_round(win_team: int, winner: int, ends := false) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_duel_ui.end_round(winner, ends)
	print_verbose("Round %d ended. Team won: %d." % [current_round, win_team])
	if ends:
		_ended = true
		print_verbose("Winner: %d." % winner)
		end_event(winner == multiplayer.get_unique_id())
	
	if is_instance_valid(_poison_smokes):
		var tween: Tween = _poison_smokes.create_tween()
		tween.tween_property(_poison_smokes, ^":modulate", Color.TRANSPARENT, 0.3)
		tween.tween_callback(_poison_smokes.queue_free)
	
	round_ended.emit(win_team)
	if not multiplayer.is_server():
		return
	freeze_entities.rpc()
	
	_event_timer.start(3.5)
	await _event_timer.timeout
	if ends:
		_event_timer.start(3.0)
		await _event_timer.timeout
	cleanup()
	_event_timer.start(0.5)
	await _event_timer.timeout
	if ends:
		end.rpc()
		return
	_setup_round()


func _setup_round() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	if _ended:
		# мб игра уже кончилась
		return
	
	if current_round != 0: # на первом раунде игроки уже есть
		for player: int in players_names:
			spawn_player(player)
	_start_round.rpc()


func _finish_round(winner: int, ends := false) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var team_won: int = players_teams[winner]
	if team_won == 0:
		red_rounds_won += 1
	else:
		blue_rounds_won += 1
	_set_rounds_won.rpc(red_rounds_won, blue_rounds_won)
	if red_rounds_won >= rounds_to_win or blue_rounds_won >= rounds_to_win:
		ends = true
	
	_end_round.rpc(team_won, winner, ends)
