class_name BigShotHunting
extends Challenge

## Испытание "Большая шишка".

@export_group("Rewards")
## Сколько игрок получит монет за устранение Большой шишки.
@export var coins_for_win: int = 30
## Сколько игрок получит монет за убийство.
@export var coins_for_kill: int = 2
## Сколько нужно нанести урона, чтобы получить монету.
@export var damage_for_coin := 50.0

var _big_shot_killed := false

@onready var _big_shot_hunting_ui: BigShotHuntingUI = $UI


func _local_player_died() -> void:
	end_challenge(false)


func _finish_start() -> void:
	spawn_big_shot()


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	rewards["Устранение цели"] = coins_for_win if _big_shot_killed else 0
	rewards["Убийства"] = coins_for_kill * kills
	rewards["Нанесённый урон"] = roundi(damaged / damage_for_coin)
	return rewards


## Создаёт Большую шишку.
func spawn_big_shot() -> void:
	var big_shot: Entity = entity_scenes[1].instantiate()
	big_shot.position = ($Map/BigShotSpawnPoint as Node2D).global_position
	big_shot.team = 3
	big_shot.id = -randi()
	big_shot.name += str(big_shot.id)
	$Entities.add_child(big_shot, true)
	big_shot.died.connect(_on_big_shot_died)
	_big_shot_hunting_ui.set_boss(big_shot)


func _on_big_shot_died() -> void:
	_big_shot_killed = true
	end_challenge(true)
