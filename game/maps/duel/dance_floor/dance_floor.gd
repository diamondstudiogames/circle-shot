extends Map

@export var background_color: Color
var _previous_color: Color
@onready var _anim: AnimationPlayer = $TileMapLayers/WallsColored/AnimationPlayer

func _initialize() -> void:
	_previous_color = RenderingServer.get_default_clear_color()
	if Globals.get_setting_bool("low_graphics"):
		RenderingServer.set_default_clear_color(background_color)
	
	var duel := world as Duel
	if duel:
		duel.round_started.connect(_on_round_started)
		duel.round_ended.connect(_on_round_ended)
	else:
		_on_round_started()


func _exit_tree() -> void:
	if RenderingServer.get_default_clear_color() != _previous_color:
		RenderingServer.set_default_clear_color(_previous_color)


func _on_round_started() -> void:
	_anim.play(&"dance")


func _on_round_ended(team_won: Entity.Team) -> void:
	if team_won == Entity.Team.RED:
		_anim.play(&"red_won")
	else:
		_anim.play(&"blue_won")
