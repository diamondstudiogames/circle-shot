class_name DemonFight
extends Challenge

## Испытание "Битва с демоном".

@export_group("Rewards")
## Сколько игрок получит монет за победу над демоном.
@export var coins_for_win: int = 30
## Сколько игрок получит монет за победу над демоном в первый раз.
@export var coins_for_win_first_time: int = 30
## Сколько игрок получит монет за убийство.
@export var coins_for_kill: int = 2
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin := 50.0

var _goat_defeated := false
var _goat_defeated_first_time := true
var _nav_agent: NavigationAgent2D
var _moving_player := false

@onready var _cutscene_timer: Timer = $CutsceneTimer
@onready var _demon_fight_ui: DemonFightUI = $UI


func _physics_process(_delta: float) -> void:
	if _moving_player and not _nav_agent.is_navigation_finished():
		local_player.entity_input.move_direction = \
				local_player.global_position.direction_to(_nav_agent.get_next_path_position()) * 0.5
		local_player.entity_input.aim_direction = local_player.entity_input.move_direction


func _initialize() -> void:
	spawn_goat()


func _local_player_died() -> void:
	end_challenge(false)


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	if _goat_defeated and _goat_defeated_first_time:
		rewards["Победа над демоном"] = coins_for_win_first_time
	elif _goat_defeated:
		rewards["Победа над демоном"] = coins_for_win
	else:
		rewards["Победа над демоном"] = 0
	rewards["Убийства"] = coins_for_kill * kills
	rewards["Нанесённый урон"] = roundi(damaged / damage_for_coin)
	return rewards


## Создаёт Козла.
func spawn_goat() -> void:
	var goat: Entity = entity_scenes[1].instantiate()
	goat.position = ($Map/GoatSpawnPoint as Node2D).global_position
	goat.team = 10
	goat.id = -randi()
	goat.name += str(goat.id)
	$Entities.add_child(goat, true)
	goat.died.connect(_on_goat_died.bind(goat))
	_demon_fight_ui.set_boss(goat)
	goat.make_immobile()
	goat.make_disarmed()
	await started
	goat.unmake_disarmed()
	goat.unmake_immobile()


func _start_cutscene(goat_pos: Vector2) -> void:
	start_cutscene()
	local_player.make_immune()
	($Music as AudioStreamPlayer).stop()
	($LightStar as Node2D).global_position = goat_pos
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 16.0
	_nav_agent.target_desired_distance = 120.0
	_nav_agent.path_max_distance = 320.0
	local_player.add_child(_nav_agent)
	
	_cutscene_timer.start(3.0)
	await _cutscene_timer.timeout
	($LightStar/AnimationPlayer as AnimationPlayer).play(&"appear")
	_cutscene_timer.start(1.5)
	await _cutscene_timer.timeout
	
	_nav_agent.target_position = goat_pos
	_moving_player = true
	await _nav_agent.navigation_finished
	local_player.entity_input.move_direction = Vector2.ZERO
	_moving_player = false
	
	_cutscene_timer.start(1.0)
	await _cutscene_timer.timeout
	_demon_fight_ui.show_dialog("Прикоснувшись к этому свету, ты почувствовал нечто странное...")
	await _demon_fight_ui.dialog_shown
	_cutscene_timer.start(1.0)
	await _cutscene_timer.timeout
	($LightStar/AnimationPlayer as AnimationPlayer).play(&"disappear")
	_cutscene_timer.start(1.5)
	await _cutscene_timer.timeout
	
	_demon_fight_ui.show_dialog("...словно он озарил тебя изнутри.")
	await _demon_fight_ui.dialog_shown
	_cutscene_timer.start(1.5)
	await _cutscene_timer.timeout
	
	_demon_fight_ui.show_dialog("Может быть, даже с пустотой вместо души...")
	await _demon_fight_ui.dialog_shown
	_cutscene_timer.start(1.5)
	await _cutscene_timer.timeout
	
	_demon_fight_ui.show_dialog("...ты можешь нечто большее?..
(доступно новое оружие, загляни в магазин)")
	await _demon_fight_ui.dialog_shown
	_cutscene_timer.start(1.5)
	await _cutscene_timer.timeout
	
	_demon_fight_ui.show_dialog("")
	Globals.set_bool("goat_defeated", true)
	var offer: Dictionary = {
		"id": 500,
		"name": "Награда за испытание",
		"cost": 2000,
		"sale": 0,
		"rewards": ["weapon:soul_sword"] as Array[String],
	}
	var special_offers: Array[Dictionary] = \
			Globals.get_variant("special_offers", [] as Array[Dictionary])
	special_offers.append(offer)
	Globals.set_variant("special_offers", special_offers)
	local_player.unmake_immune()
	end_cutscene()
	end_challenge(true)


func _on_goat_died(goat: Entity) -> void:
	_goat_defeated = true
	_goat_defeated_first_time = not Globals.get_bool("goat_defeated")
	if _goat_defeated_first_time:
		get_tree().call_group(&"mob", &"queue_free")
		_start_cutscene(goat.global_position)
	else:
		end_challenge(true)
