class_name Challenge
extends World

## Основной узел испытания.
##
## Базовый класс для всех испытаний в игре. Доступ к нему можно получить через
## [member Game.world] (только для неигровой части) или через
## [code](get_tree().get_first_node_in_group(&"world") as Challenge)[/code].

## Издаётся, когда испытание началось (т. е. после вызова [method _start]).
signal started

## Карта этого испытания.
var map: Map
## Данные об этом испытании.
var data: ChallengeData
## Началось ли испытание.
var was_started := false

## Ссылка на [ChallengeUI].
@onready var challenge_ui: ChallengeUI = $UI
@onready var _challenge_timer: Timer = $ChallengeTimer


func _ready() -> void:
	super()
	
	spawn_player()
	challenge_ui.show_intro()
	_challenge_timer.start(5.0)
	await _challenge_timer.timeout
	_start()


func _local_player_created(player: Player) -> void:
	if was_started:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 0.3)
	else:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 4.0)


func get_game_zone() -> Rect2:
	return Rect2(-map.data.size * BLOCK_SIZE / 2, map.data.size * BLOCK_SIZE)


## Создаёт игрока. Если испытание ещё не началось, то этот игрок будет обезоружен и обездвижен.
func spawn_player() -> void:
	var player: Player = entity_scenes[0].instantiate()
	player.position = ($Map/SoloSpawnPoint as Node2D).global_position
	player.team = Entity.Team.RED
	player.id = multiplayer.get_unique_id()
	player.player_name = Globals.get_string("player_name")
	player.equip_data = [
		Globals.items_db.skins_by_id[Globals.get_string("selected_skin")].idx_in_db,
		Globals.items_db.skills_by_id[Globals.get_string("selected_skill")].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.get_string("selected_light_weapon")].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.get_string("selected_heavy_weapon")].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.get_string("selected_support_weapon")].idx_in_db,
		Globals.items_db.weapons_by_id[Globals.get_string("selected_melee_weapon")].idx_in_db,
	]
	player.equip_data.append(-1)
	player.name = "Player%d" % player.id
	if player.id in players_persistent_data:
		player.persistent_data = players_persistent_data[player.id]
	_customize_player(player)
	entities_parent.add_child(player, true)
	if not was_started:
		player.block_weapon_usage()
		player.make_immobile()
		player.block_turning()


## Останавливает, обезоруживает и делает неуязвимыми все сущности.
func freeze_entities() -> void:
	get_tree().call_group(&"entity", &"make_disarmed")
	get_tree().call_group(&"entity", &"make_immobile")
	get_tree().call_group(&"entity", &"make_immune")
	get_tree().call_group(&"entity", &"block_turning")


## Отменяет действие [method freeze_entities].
func unfreeze_entities() -> void:
	get_tree().call_group(&"entity", &"unmake_disarmed")
	get_tree().call_group(&"entity", &"unmake_immobile")
	get_tree().call_group(&"entity", &"unmake_immune")
	get_tree().call_group(&"entity", &"unblock_turning")


## Заканчивает событие победой или поражением.
func end_challenge(victory: bool) -> void:
	freeze_entities()
	($Music as AudioStreamPlayer).stop()
	if victory:
		($VictoryMusic as AudioStreamPlayer).play()
		challenge_ui.show_victory()
	else:
		($DefeatMusic as AudioStreamPlayer).play()
		challenge_ui.show_defeat()
	
	# Ждём пока вся информация прилетит
	($ShowRewardsTimer as Timer).start()
	await ($ShowRewardsTimer as Timer).timeout
	
	var rewards: Dictionary[String, int] = _get_rewards()
	var coins_got: int = rewards.values().reduce(
			func(accum: int, num: int) -> int: return accum + num)
	Globals.set_int("coins", Globals.get_int("coins") + coins_got)
	challenge_ui.show_rewards(rewards, coins_got)
	
	_challenge_timer.start(5.5)
	await _challenge_timer.timeout
	print_verbose("Challenge ended.")
	Globals.main.game.close()


func _start() -> void:
	if not tracks.is_empty():
		($Music as AudioStreamPlayer).stream = tracks.pick_random()
		($Music as AudioStreamPlayer).play()
	
	_finish_start()
	if multiplayer.is_server():
		get_tree().call_group(&"player", &"unblock_weapon_usage")
		get_tree().call_group(&"player", &"unmake_immobile")
		get_tree().call_group(&"player", &"unblock_turning")
	else:
		local_player.unblock_weapon_usage()
		local_player.unmake_immobile()
		local_player.unblock_turning()
	started.emit()
	was_started = true
	
	print_verbose("Challenge started.")


## Метод для переопределения. Вызывается в момент старта испытания.
func _finish_start() -> void:
	pass


## Может быть переопределён для настройки игрока ДО добавления в сцену.
func _customize_player(_player: Player) -> void:
	pass


## Метод для переопределения. Вызывается и на сервере и на клиенте. Должен вернуть словарь,
## где ключи - строки с причиной награды, а значения - размер награды в монетах.
func _get_rewards() -> Dictionary[String, int]:
	return {}
