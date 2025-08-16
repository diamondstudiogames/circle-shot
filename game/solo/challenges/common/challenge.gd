class_name Challenge
extends World

## Основной узел испытания.
##
## Базовый класс для всех испытаний в игре. Доступ к нему можно получить через
## [member Game.world] (только для неигровой части) или через
## [code](get_tree().get_first_node_in_group(&"world") as Challenge)[/code].

## Издаётся, когда испытание началось (т. е. после вызова [method _start]).
signal started
## Началось ли испытание.
var was_started := false
var _player_skill_vars: Array[int]
## Ссылка на [ChallengeUI].
@onready var challenge_ui: ChallengeUI = $UI


func _ready() -> void:
	super()
	
	spawn_player()
	challenge_ui.show_intro()
	await get_tree().create_timer(5.0, false).timeout
	_start()


func _local_player_created(player: Player) -> void:
	if was_started:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 0.3)
	else:
		($Camera as SmartCamera).pan_to_target(player.camera_target, 4.0)


## Создаёт игрока с идентификатором [param id]. Если событие ещё не началось, то этот игрок будет
## обезоружен и обездвижен.
func spawn_player() -> void:
	var player: Player = entity_scenes[0].instantiate()
	player.position = ($Map/SoloSpawnPoint as Node2D).global_position
	player.team = 0
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
	if not _player_skill_vars.is_empty():
		player.skill_vars = _player_skill_vars.duplicate()
	player.name = "Player%d" % player.id
	_customize_player(player)
	$Entities.add_child(player)
	player.tree_exiting.connect(_on_player_tree_exiting.bind(player))
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


## Заканчивает событие победой или поражением.
func end_challenge(victory: bool) -> void:
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
	
	await get_tree().create_timer(5.5, false).timeout
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


func _on_player_tree_exiting(player: Player) -> void:
	_player_skill_vars = player.skill_vars
