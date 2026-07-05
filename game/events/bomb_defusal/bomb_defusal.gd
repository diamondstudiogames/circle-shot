class_name BombDefusal
extends Event

## Событие "Закладка бомбы".

## Издаётся, когда раунд начинается.
signal round_started
## Издаётся, когда раунд заканчивается.
signal round_ended

@export_group("Rewards")
## Количество монет, которое получит игрок за выигранный раунд.
@export var coins_for_won_round: int = 17
## Количество монет, которое получит игрок за проигранный раунд.
@export var coins_for_lost_round: int = 5
## Количество монет, которое получит игрок за каждое убийство.
@export var coins_for_kill: int = 5
## Количество монет, которое получит игрок за каждую установленную/обезвреженную бомбу.
@export var coins_for_bomb: int = 10
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin: int = 20

## Длительность раунда (если бомба не была заложена).
var round_time: int = 80
## Сколько раундов нужно выиграть, чтобы победить.
var rounds_to_win: int = 4

## Количество раундов, выигранной красной командой.
var red_rounds_won: int = 0
## Количество раундов, выигранной синей командой.
var blue_rounds_won: int = 0
## Количество бомб, установленных/обезвреженных локальным игроком.
var bombs_planted_defused: int = 0

var _spawn_counter_red: int = 0
var _spawn_counter_blue: int = 0
var _time_remained: int
var _current_round: int = 0
var _round_ended := false

var _bomb_carrier: int
var _bomb_planted: bool

var _bomb_data: WeaponData = load("uid://cjgoqhsfs8s1g")
var _bomb_dropped_scene: PackedScene = load("uid://dpugjjonr8i0u")
var _bomb_planted_scene: PackedScene = load("uid://cb533eb27cteb")

@onready var _spawn_points_red: Array[Node] = $Map/SpawnPoints0.get_children()
@onready var _spawn_points_blue: Array[Node] = $Map/SpawnPoints1.get_children()
@onready var _round_timer: Timer = $RoundTimer
@onready var _bomb_defusal_ui: BombDefusalUI = $UI


func _initialize() -> void:
	_spawn_points_blue.shuffle()
	_spawn_points_red.shuffle()
	
	rounds_to_win = parameters["rounds_to_win"]
	round_time = parameters["round_time"]
	
	_bomb_defusal_ui.set_score(red_rounds_won, blue_rounds_won)
	_bomb_defusal_ui.set_rounds_to_win(rounds_to_win)
	
	if multiplayer.is_server():
		_spawn_counter_red = randi() % 5
		_spawn_counter_blue = randi() % 5


func _make_teams() -> void:
	Utils.make_teams(players_names, players_teams)
	_pick_bomb_carrier()


func _finish_setup() -> void:
	_init_round(true)


func _finish_start() -> void:
	if multiplayer.is_server():
		_round_timer.start()
		_start_round.rpc()


func _get_spawn_point(id: int) -> Vector2:
	var pos: Vector2
	if players_teams[id] == 0:
		pos = (_spawn_points_red[_spawn_counter_red % 5] as Node2D).global_position
		_spawn_counter_red += 1
	else:
		pos = (_spawn_points_blue[_spawn_counter_blue % 5] as Node2D).global_position
		_spawn_counter_blue += 1
	return pos


func _customize_player(player: Player) -> void:
	if _bomb_carrier == player.id:
		player.equip_data[6] = _bomb_data.idx_in_db
		player.tree_exiting.connect(_on_bomb_player_tree_exiting.bind(player))


func _player_killed(_by: int, player: Player) -> void:
	if player.id == _bomb_carrier:
		_bomb_carrier = -1
		var pickable: PickableEquipItem = _bomb_dropped_scene.instantiate()
		pickable.position = player.global_position
		pickable.picked_up.connect(_on_bomb_picked_up)
		$Other.add_child(pickable, true)
	_remove_player(player.id)
	_check_alive_players()


func _player_disconnected(id: int) -> void:
	_remove_player(id)
	if was_started and not _round_ended:
		_check_alive_players()


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	var rounds_won: int
	var rounds_lost: int
	if local_team == 0:
		rounds_won = red_rounds_won
		rounds_lost = blue_rounds_won
	else:
		rounds_won = blue_rounds_won
		rounds_lost = red_rounds_won
	rewards["Результаты раундов"] = rounds_won * coins_for_won_round \
			+ rounds_lost * coins_for_lost_round
	if local_team == 0:
		rewards["Заложенные бомбы"] = bombs_planted_defused * coins_for_bomb
	else:
		rewards["Обезвреженные бомбы"] = bombs_planted_defused * coins_for_bomb
	rewards["Убийства"] = kills * coins_for_kill
	rewards["Нанесённый урон"] = roundi(damaged / float(damage_for_coin))
	return rewards


func _get_event_status() -> String:
	if _round_ended:
		return "конец раунда %d" % _current_round
	return "раунд %d, осталось времени: %d:%02d" % [
		_current_round,
		floori(_time_remained / 60.0),
		_time_remained % 60,
	]


## Бросает бомбу на пол в позиции, указанной в [param where].
func bomb_drop(where: Vector2) -> void:
	_bomb_carrier = -1
	var pickable: PickableEquipItem = _bomb_dropped_scene.instantiate()
	pickable.position = where
	pickable.picked_up.connect(_on_bomb_picked_up)
	$Other.add_child(pickable, true)


## Закладывает бомбу в точке [param where]. [param by] должен содержать ID игрока, заложившего
## бомбу.
func bomb_plant(where: Vector2, by: int) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	_round_timer.stop()
	_bomb_planted = true
	_bomb_carrier = -1
	_bomb_plant.rpc(by)
	
	var bomb: Node2D = _bomb_planted_scene.instantiate()
	bomb.position = where
	$Other.add_child(bomb, true)


## Устанавливает время до взрыва.
func bomb_set_time(remained: int) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	_update_time.rpc(remained, true)


## Взрывает бомбу, оканчивая раунд победой красной команды.
func bomb_explode() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	_finalize_round(false)


## Обезвреживает бомбу, оканчивая раунд победой синей команды. В [param by] лежит ID игрока,
## обезвредившего бомбу.
func bomb_defuse(by: int) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	_finalize_round(true, false, by)


@rpc("reliable", "authority", "call_local", 3)
func _start_round() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_current_round += 1
	round_started.emit()
	print_verbose("Round %d started." % _current_round)


@rpc("reliable", "authority", "call_local", 3)
func _end_round(defused_by: int = -1) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_bomb_defusal_ui.set_spectate_visible(false)
	round_ended.emit()
	if defused_by > 0:
		_bomb_defusal_ui.show_bomb_state(true)
		if defused_by == multiplayer.get_unique_id():
			bombs_planted_defused += 1
		print_verbose("Bomb has been defused by %d." % defused_by)
	print_verbose("Round %d ended." % _current_round)


@rpc("reliable", "authority", "call_local", 3)
func _show_round_result(blue_won: bool, final: bool) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if blue_won:
		print_verbose("Blue team won round.")
		blue_rounds_won += 1
	else:
		print_verbose("Red team won round.")
		red_rounds_won += 1
	print_verbose("Score: %d - %d." % [red_rounds_won, blue_rounds_won])
	_bomb_defusal_ui.set_score(red_rounds_won, blue_rounds_won)
	if final:
		_bomb_defusal_ui.show_winner(blue_won)
		end_event(blue_won and local_team == 1 or not blue_won and local_team == 0)
	else:
		_bomb_defusal_ui.show_round_end(blue_won and local_team == 1
				or not blue_won and local_team == 0)


@rpc("reliable", "authority", "call_local", 3)
func _bomb_plant(planted_by: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	_bomb_defusal_ui.show_bomb_state(false)
	if planted_by == multiplayer.get_unique_id():
		bombs_planted_defused += 1
	print_verbose("Bomb has been planted by %d." % planted_by)


@rpc("unreliable_ordered", "call_local", "authority", 3)
func _update_time(remained: int, bomb: bool) -> void:
	_time_remained = remained
	_bomb_defusal_ui.set_time(remained, bomb)


@rpc("reliable", "call_local", "authority", 3)
func _kill_player(who: int, alive_red_players: Array[int], alive_blue_players: Array[int]) -> void:
	var alive_players: Array[int]
	if local_team == 1 or alive_red_players.is_empty():
		alive_players = alive_blue_players
	else:
		alive_players = alive_red_players
	_bomb_defusal_ui.kill_player(who, alive_players)
	print_verbose("Player %d died. Spectating: %s." % [who, alive_players])
	if alive_players.is_empty():
		_bomb_defusal_ui.set_spectate_visible(false)
		return
	if who == multiplayer.get_unique_id():
		_bomb_defusal_ui.set_spectate_visible(true)


func _init_round(first := false) -> void:
	_bomb_planted = false
	_time_remained = round_time
	_update_time.rpc(_time_remained, false)
	if first:
		await started
	if _check_remained_players():
		return
	if not first:
		_round_ended = false
		_pick_bomb_carrier()
		_round_timer.start()
		for id: int in players_names:
			spawn_player(id)
		_start_round.rpc()


func _finalize_round(blue_won: bool, force_end := false, defused_by: int = -1) -> void:
	_round_ended = true
	_round_timer.stop()
	freeze_entities.rpc()
	_end_round.rpc(defused_by)
	if defused_by > 0:
		_event_timer.start(2.0)
		await _event_timer.timeout
	var final: bool = blue_rounds_won + int(blue_won) >= rounds_to_win \
			or red_rounds_won + int(not blue_won) >= rounds_to_win or force_end
	_show_round_result.rpc(blue_won, final)
	
	_event_timer.start(4.0)
	await _event_timer.timeout
	if not final:
		cleanup()
		_event_timer.start(0.5)
		await _event_timer.timeout
		_init_round()
	else:
		_event_timer.start(2.5)
		await _event_timer.timeout
		cleanup()
		_event_timer.start(0.5)
		await _event_timer.timeout
		end.rpc()


func _pick_bomb_carrier() -> void:
	var red_players_ids: Array = players_names.keys().filter(
			func(id: int) -> bool: return players_teams[id] == 0)
	if not red_players_ids.is_empty():
		_bomb_carrier = red_players_ids.pick_random()


func _check_remained_players() -> bool:
	if not players_teams.find_key(0): # Нет красных больше
		_finalize_round(true, true)
		return true
	elif not players_teams.find_key(1): # Нет синих больше
		_finalize_round(false, true)
		return true
	return false


func _check_alive_players() -> void:
	if _check_remained_players():
		return
	var alive_players_by_team: Array[int] = [0, 0]
	for player: Player in players.values():
		alive_players_by_team[player.team] += 1
	if alive_players_by_team[0] == 0 and not _bomb_planted:
		_finalize_round(true)
	elif alive_players_by_team[1] == 0:
		_finalize_round(false)


func _remove_player(who: int) -> void:
	var alive_red_players: Array[int]
	var alive_blue_players: Array[int]
	for id: int in players_teams:
		if id == who:
			continue
		if not id in players or players[id].is_queued_for_deletion():
			continue
		if players_teams[id] == 0:
			alive_red_players.append(id)
		else:
			alive_blue_players.append(id)
	_kill_player.rpc(who, alive_red_players, alive_blue_players)


func _on_bomb_picked_up(by: int) -> void:
	_bomb_carrier = by


func _on_bomb_player_tree_exiting(player: Player) -> void:
	if player.id != _bomb_carrier: # мб уже заплентил, а подключение осталось
		return
	if not player.id in players_names: # отключился, бросаем бомбу, иначе это обычная очистка
		bomb_drop(player.global_position)


func _on_round_timer_timeout() -> void:
	_time_remained -= 1
	_update_time.rpc(_time_remained, false)
	if _time_remained <= 0:
		_finalize_round(true)
