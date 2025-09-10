# meta-name: Событие
# meta-description: Содержит методы, переопределив которые можно создать новое событие.
# meta-default: true
class_name <NewEventName>
extends _BASE_

@onready var _<new_event_name>_ui: <NewEventName>UI = $UI

func _initialize() -> void:
_TS_pass


func _make_teams() -> void:
_TS_pass


func _finish_setup() -> void:
_TS_pass


func _finish_start() -> void:
_TS_pass


#func _get_player_scene(id: int) -> PackedScene:
_TS_#return # пишите логику здесь


func _get_spawn_point(id: int) -> Vector2:
_TS_return # пишите логику здесь


#func _customize_player(player: Player) -> void:
_TS_#pass


#func _local_player_died() -> void:
_TS_#pass


#func _player_killed(by: int, player: Player) -> void:
_TS_#pass


#func _player_disconnected(id: int) -> void:
_TS_#pass


func _get_rewards() -> Dictionary[String, int]:
_TS_var rewards: Dictionary[String, int]
_TS_return rewards


func _get_event_status() -> String:
_TS_return ""