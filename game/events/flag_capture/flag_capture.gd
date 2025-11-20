class_name FlagCapture
extends Event

## Событие "Захват флага".

## Длительность матча.
@export var match_time: int = 180
## Время, через которое возвращаются павшие игроки.
@export var comeback_time: int = 3

@export_group("Rewards")
## Количество монет, которое получит игрок при победе.
@export var coins_for_win: int = 80
## Количество монет, которое получит игрок при ничье.
@export var coins_for_draw: int = 60
## Количество монет, которое получит игрок при поражении.
@export var coins_for_defeat: int = 40
## Количество монет, которое получит игрок за каждый захваченный флаг.
@export var coins_for_flag_captured: int = 12
## Количество монет, которое получит игрок за каждое убийство.
@export var coins_for_kill: int = 5
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin: int = 10

## Количество флагов, захваченных красной командой.
var red_flags_captured: int = 0
## Количество флагов, захваченных синей командой.
var blue_flags_captured: int = 0
## Количество флагов, захваченных локальным игроком.
var flags_captured: int = 0

var _spawn_counter_red: int = 0
var _spawn_counter_blue: int = 0
var _time_remained: int
var _team_won: int

var _red_flag_scene: PackedScene = load("uid://cc2mkoa1fingr")
var _blue_flag_scene: PackedScene = load("uid://cyudg7uces0wb")

@onready var _spawn_points_red: Array[Node] = $Map/SpawnPoints0.get_children()
@onready var _spawn_points_blue: Array[Node] = $Map/SpawnPoints1.get_children()
@onready var _red_flag_spawn_point: Node2D = $Map/RedFlag
@onready var _blue_flag_spawn_point: Node2D = $Map/BlueFlag
@onready var _flag_capture_ui: FlagCaptureUI = $UI


func _initialize() -> void:
	_spawn_points_blue.shuffle()
	_spawn_points_red.shuffle()
	
	_flag_capture_ui.set_time(match_time)
	_flag_capture_ui.set_flags(red_flags_captured, blue_flags_captured)
	_time_remained = match_time
	
	if multiplayer.is_server():
		_spawn_counter_red = randi() % 5
		_spawn_counter_blue = randi() % 5
	
	($FlagZoneRed as Node2D).global_position = _red_flag_spawn_point.global_position
	($FlagZoneBlue as Node2D).global_position = _blue_flag_spawn_point.global_position


func _make_teams() -> void:
	var places: Array[int]
	places.append(floori(players_names.size() / 2.0))
	places.append(floori(players_names.size() / 2.0))
	if places[0] + places[1] != players_names.size():
		places[randi() % 2] += 1
	
	for id: int in players_teams:
		places[players_teams[id]] -= 1
		if places[players_teams[id]] < 0:
			# где-то ошиблись, вернём к нулю и вычтем из другого
			places[players_teams[id]] = 0
			places[1 - players_teams[id]] = 0
	
	var ids: Array[int]
	ids.assign(players_names.keys())
	ids.shuffle()
	for id: int in ids:
		if id in players_teams:
			continue
		
		if places[0] > 0:
			players_teams[id] = 0
			places[0] -= 1
		elif places[1] > 0:
			players_teams[id] = 1
			places[1] -= 1
		else:
			# по идее такого быть не должно, запихаем в красную
			players_teams[id] = 0


func _finish_start() -> void:
	if multiplayer.is_server():
		if not (players_teams.find_key(0) and players_teams.find_key(1)):
			_time_remained = 1
		($MatchTimer as Timer).start()
		_spawn_flag(false)
		_spawn_flag(true)


func _get_spawn_point(id: int) -> Vector2:
	var pos: Vector2
	if players_teams[id] == 0:
		pos = (_spawn_points_red[_spawn_counter_red % 5] as Node2D).global_position
		_spawn_counter_red += 1
	else:
		pos = (_spawn_points_blue[_spawn_counter_blue % 5] as Node2D).global_position
		_spawn_counter_blue += 1
	return pos


func _local_player_died() -> void:
	_flag_capture_ui.show_comeback(comeback_time)


func _player_killed(_by: int, player: Player) -> void:
	_respawn_player(player.id)


func _player_disconnected(_id: int) -> void:
	if _time_remained <= 0:
		return
	# Недостаточно участников команд
	if not (players_teams.find_key(0) and players_teams.find_key(1)):
		_time_remained = 1


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	var result_coins: int
	if _team_won == local_team:
		result_coins = coins_for_win
	elif _team_won < 0:
		result_coins = coins_for_draw
	else:
		result_coins = coins_for_defeat
	rewards["Результат"] = result_coins
	rewards["Захваченные флаги"] = flags_captured * coins_for_flag_captured
	rewards["Убийства"] = kills * coins_for_kill
	rewards["Нанесённый урон"] = roundi(damaged / float(damage_for_coin))
	return rewards


func _get_event_status() -> String:
	return "осталось времени: %d:%02d" % [floori(_time_remained / 60.0), _time_remained % 60]


@rpc("unreliable_ordered", "call_local", "authority", 3)
func _update_time(remained: int) -> void:
	_time_remained = remained
	_flag_capture_ui.set_time(remained)


@rpc("reliable", "call_local", "authority", 3)
func _update_score(red: int, blue: int, blue_captured: bool) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	red_flags_captured = red
	blue_flags_captured = blue
	_flag_capture_ui.set_flags(red_flags_captured, blue_flags_captured)
	_flag_capture_ui.show_flag_captured(blue_captured)
	print_verbose("Team %d captured flag." % int(blue_captured))
	print_verbose("Current score: %d - %d." % [red_flags_captured, blue_flags_captured])


@rpc("reliable", "call_local", "authority", 3)
func _show_winner(team: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_team_won = team
	end_event(team == local_team)
	_flag_capture_ui.show_winner(team)
	print_verbose("Team won: %d." % team)


@rpc("reliable", "call_local", "authority", 6)
func _increment_flags_captured() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	flags_captured += 1


func _respawn_player(id: int) -> void:
	var comeback_timer := Timer.new()
	comeback_timer.one_shot = true
	comeback_timer.name = "ComebackTimer%d" % id
	add_child(comeback_timer)
	
	comeback_timer.start(comeback_time)
	await comeback_timer.timeout
	comeback_timer.queue_free()
	if _time_remained > 0 and id in players_names:
		spawn_player(id)


func _spawn_flag(blue: bool) -> void:
	var flag: Flag = (_blue_flag_scene if blue else _red_flag_scene).instantiate()
	flag.name += str(randi())
	flag.position = (_blue_flag_spawn_point if blue else _red_flag_spawn_point).global_position
	$Other.add_child(flag, true)


func _end_event() -> void:
	if not players_teams.find_key(0): # Нет красных больше
		_show_winner.rpc(1)
	elif not players_teams.find_key(1): # Нет синих больше
		_show_winner.rpc(0)
	elif red_flags_captured > blue_flags_captured:
		_show_winner.rpc(0)
	elif blue_flags_captured > red_flags_captured:
		_show_winner.rpc(1)
	else:
		_show_winner.rpc(-1)
	freeze_players.rpc()
	
	_event_timer.start(6.5)
	await _event_timer.timeout
	cleanup()
	_event_timer.start(0.5)
	await _event_timer.timeout
	end.rpc()


func _on_match_timer_timeout() -> void:
	_time_remained -= 1
	_update_time.rpc(_time_remained)
	if _time_remained <= 0:
		($MatchTimer as Timer).stop()
		_end_event()


func _on_flag_zone_red_flag_captured(by: int) -> void:
	red_flags_captured += 1
	if by > 0:
		_increment_flags_captured.rpc_id(by)
	_update_score.rpc(red_flags_captured, blue_flags_captured, false)
	_spawn_flag.call_deferred(true)


func _on_flag_zone_blue_flag_captured(by: int) -> void:
	blue_flags_captured += 1
	if by > 0:
		_increment_flags_captured.rpc_id(by)
	_update_score.rpc(red_flags_captured, blue_flags_captured, true)
	_spawn_flag.call_deferred(false)
