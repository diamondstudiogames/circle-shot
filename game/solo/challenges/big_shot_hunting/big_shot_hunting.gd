class_name BigShotHunting
extends Challenge

## Испытание "Большая шишка".

@onready var _big_shot_hunting_ui: BigShotHuntingUI = $UI


func _initialize() -> void:
	await get_tree().create_timer(5.0).timeout
	spawn_bandit(6)
	pass


func _local_player_died() -> void:
	pass


func _finish_start() -> void:
	pass


func _get_rewards() -> Dictionary[String, int]:
	var rewards: Dictionary[String, int]
	return rewards


func spawn_bandit(idx: int) -> void:
	var bandit: Entity = entity_scenes[idx].instantiate()
	bandit.position = Vector2(randf_range(-1600.0, 1600.0), randf_range(-1600.0, 1600.0))
	bandit.team = 1
	bandit.id = -randi()
	bandit.name += str(bandit.id)
	$Entities.add_child(bandit, true)
