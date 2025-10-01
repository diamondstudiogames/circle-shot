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

@onready var _demon_fight_ui: DemonFightUI = $UI


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
	goat.team = 4
	goat.id = -randi()
	goat.name += str(goat.id)
	$Entities.add_child(goat, true)
	goat.died.connect(_on_goat_died)
	_demon_fight_ui.set_boss(goat)
	goat.make_immobile()
	goat.make_disarmed()
	await started
	goat.unmake_disarmed()
	goat.unmake_immobile()


func _on_goat_died() -> void:
	_goat_defeated = true
	_goat_defeated_first_time = not Globals.get_bool("goat_defeated")
	# TODO: катсцена
	Globals.set_bool("goat_defeated", true)
