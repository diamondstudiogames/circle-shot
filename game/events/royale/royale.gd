class_name Royale
extends Event

## Событие "Королевская битва".

## Базовый интервал появления аптечек.
@export var heal_box_spawn_interval_base := 30.0
## Увеличение интервала появления аптечек за каждого живого игрока.
@export var heal_box_spawn_interval_per_player := 2.0
## Базовый интервал появления коробок с боеприпасами.
@export var ammo_box_spawn_interval_base := 40.0
## Увеличение интервала появления коробок с боеприпасами за каждого живого игрока.
@export var ammo_box_spawn_interval_per_player := 2.5
## Базовый интервал появления подбираемых оружий.
@export var weapon_box_spawn_interval_base := 50.0
## Увеличение интервала появления подбираемых оружий за каждого живого игрока.
@export var weapon_box_spawn_interval_per_player := 10.0

@export_group("Rewards")
## Количество монет, которое получит игрок за последнее место.
@export var coins_for_last_place: int = 20
## Базовое оличество монет, которое получит игрок за первое место.
@export var coins_for_first_place_base: int = 40
## Количество монет, умноженное на количество игроков, которое добавляется
## к [member coins_for_first_place].
@export var coins_for_first_place_per_player: int = 5
## Количество монет, которое получит игрок за каждое убийство.
@export var coins_for_kill: int = 8
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin: int = 10

## Массив с ID живых игроков.
var alive_players: Array[int]

var _spawn_counter: int = 0
var _heal_box_counter: int = 0
var _ammo_box_counter: int = 0
var _weapon_box_counter: int = 0

var _places: int
var _place_got: int

var _heal_box_scene: PackedScene = load("uid://bysyaaj2r7stt")
var _ammo_box_scene: PackedScene = load("uid://bdtqr6mv231py")
var _weapon_box_scene: PackedScene = load("uid://d0d83mi7scscc")
var _poison_smokes_scene: PackedScene = load("uid://cr1m37xm3w88w")

@onready var _spawn_points: Array[Node] = $Map/SpawnPoints.get_children()
@onready var _heal_box_points: Array[Node] = $Map/HealPoints.get_children()
@onready var _ammo_box_points: Array[Node] = $Map/AmmoPoints.get_children()
@onready var _weapon_box_points: Array[Node] = $Map/WeaponBoxPoints.get_children()
@onready var _royale_ui: RoyaleUI = $UI


func _initialize() -> void:
	if multiplayer.is_server():
		_spawn_points.shuffle()
		_heal_box_points.shuffle()
		_ammo_box_points.shuffle()
		_weapon_box_points.shuffle()
	alive_players = players_names.keys()
	_royale_ui.set_alive_players(alive_players.size())


func _finish_start() -> void:
	var smokes: Node2D = _poison_smokes_scene.instantiate()
	add_child(smokes)
	var tween: Tween = smokes.create_tween()
	tween.tween_property(smokes, ^":modulate", smokes.modulate, 0.3).from(Color.TRANSPARENT)
	_places = alive_players.size()
	if multiplayer.is_server():
		($HealBoxSpawnTimer as Timer).start(heal_box_spawn_interval_base
				+ heal_box_spawn_interval_per_player * alive_players.size())
		($AmmoBoxSpawnTimer as Timer).start(ammo_box_spawn_interval_base
				+ ammo_box_spawn_interval_per_player * alive_players.size())
		($WeaponBoxSpawnTimer as Timer).start(weapon_box_spawn_interval_base
				+ weapon_box_spawn_interval_per_player * alive_players.size())
		_check_for_end()


func _make_teams() -> void:
	var counter: int = 0
	var teams: Array = range(0, 10)
	teams.shuffle()
	for player: int in players_names:
		players_teams[player] = teams[counter]
		counter += 1


func _get_spawn_point(_id: int) -> Vector2:
	var pos: Vector2 = (_spawn_points[_spawn_counter] as Node2D).global_position
	_spawn_counter += 1
	return pos


func _player_killed(by: int, player: Player) -> void:
	_kill_player.rpc(player.id, by)
	_check_for_end()


func _player_disconnected(id: int) -> void:
	_kill_player.rpc(id)
	_check_for_end()


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	var coins_for_first_place: int = coins_for_first_place_base \
			+ coins_for_first_place_per_player * _places
	rewards["Место"] = coins_for_last_place + roundi((coins_for_first_place - coins_for_last_place)
			* (1.0 - (_place_got - 1) / float(_places - 1)))
	rewards["Убийства"] = kills * coins_for_kill
	rewards["Нанесённый урон"] = roundi(damaged / float(damage_for_coin))
	return rewards


@rpc("reliable", "call_local", "authority", 3)
func _kill_player(who: int, killer: int = 0) -> void:
	alive_players.erase(who)
	print_verbose("Alive players: %s." % str(alive_players))
	_royale_ui.set_alive_players(alive_players.size())
	_royale_ui.kill_player(alive_players, who, killer)
	if who == multiplayer.get_unique_id():
		_place_got = alive_players.size() + 1
		end_event(false)
		_royale_ui.show_defeat()


@rpc("reliable", "call_local", "authority", 3)
func _show_winner(winner: int, winner_name: String) -> void:
	if winner == multiplayer.get_unique_id():
		_place_got = 1
		end_event(true)
	print_verbose("Winner: %d." % winner)
	_royale_ui.show_winner(winner == multiplayer.get_unique_id(), winner_name)


func _spawn_heal_box() -> void:
	var spawn_position: Vector2 = (_heal_box_points[_heal_box_counter] as Node2D).global_position
	var heal_box: Node2D = _heal_box_scene.instantiate()
	heal_box.position = spawn_position
	heal_box.name += str(randi())
	$Other.add_child(heal_box, true)
	_heal_box_counter += 1
	if _heal_box_counter == _heal_box_points.size():
		_heal_box_counter = 0
		_heal_box_points.shuffle()


func _spawn_ammo_box() -> void:
	var spawn_position: Vector2 = (_ammo_box_points[_ammo_box_counter] as Node2D).global_position
	var ammo_box: Node2D = _ammo_box_scene.instantiate()
	ammo_box.position = spawn_position
	ammo_box.name += str(randi())
	$Other.add_child(ammo_box, true)
	_ammo_box_counter += 1
	if _ammo_box_counter == _ammo_box_points.size():
		_ammo_box_counter = 0
		_ammo_box_points.shuffle()


func _spawn_weapon() -> void:
	var spawn_position: Vector2 = \
			(_weapon_box_points[_weapon_box_counter] as Node2D).global_position
	var weapon_box: Node2D = _weapon_box_scene.instantiate()
	weapon_box.position = spawn_position
	weapon_box.name += str(randi())
	$Other.add_child(weapon_box, true)
	_weapon_box_counter += 1
	if _weapon_box_counter == _weapon_box_points.size():
		_weapon_box_counter = 0
		_weapon_box_points.shuffle()


func _check_for_end() -> void:
	if alive_players.size() != 1:
		return
	var winner_id: int = alive_players[0]
	var winner_name: String = players_names[winner_id]
	_show_winner.rpc(winner_id, winner_name)
	freeze_players.rpc()
	($HealBoxSpawnTimer as Timer).stop()
	($AmmoBoxSpawnTimer as Timer).stop()
	($WeaponBoxSpawnTimer as Timer).stop()
	await get_tree().create_timer(6.5, false).timeout
	cleanup()
	await get_tree().create_timer(0.5, false).timeout
	end.rpc()


func _on_heal_box_spawn_timer_timeout() -> void:
	_spawn_heal_box()
	($HealBoxSpawnTimer as Timer).start(heal_box_spawn_interval_base
			+ heal_box_spawn_interval_per_player * alive_players.size())


func _on_ammo_box_spawn_timer_timeout() -> void:
	_spawn_ammo_box()
	($AmmoBoxSpawnTimer as Timer).start(ammo_box_spawn_interval_base
			+ ammo_box_spawn_interval_per_player * alive_players.size())


func _on_weapon_spawn_timer_timeout() -> void:
	_spawn_weapon()
	($WeaponBoxSpawnTimer as Timer).start(weapon_box_spawn_interval_base
			+ weapon_box_spawn_interval_per_player * alive_players.size())
