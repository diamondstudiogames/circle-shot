# meta-name: Испытание
# meta-description: Содержит методы, переопределив которые можно создать новое испытание.
# meta-default: true
class_name <NewChallengeName>
extends _BASE_

@onready var _<new_challenge_name>_ui: <NewChallengeName>UI = $UI

func _initialize() -> void:
_TS_pass


#func _local_player_created(player: Player) -> void:
_TS_#super(player)


func _local_player_died() -> void:
_TS_pass


func _finish_start() -> void:
_TS_pass


func _customize_player(player: Player) -> void:
_TS_pass


func _get_rewards() -> Dictionary[String, int]:
_TS_var rewards: Dictionary[String, int]
_TS_return rewards