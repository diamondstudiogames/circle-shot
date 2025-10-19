extends PlayerSkin

@onready var _anim_tree: AnimationTree = $AnimationTree
@onready var _left_pupil: Sprite2D = $LeftPupil/Sprite2D
@onready var _right_pupil: Sprite2D = $RightPupil/Sprite2D

func _process(_delta: float) -> void:
	var aim_direction: Vector2 = player.entity_input.aim_direction
	aim_direction.x = absf(aim_direction.x)
	var pupils_rotation: float = aim_direction.angle()
	_left_pupil.rotation = pupils_rotation
	_right_pupil.rotation = pupils_rotation
	
	if player.get_real_velocity().is_zero_approx():
		if _anim_tree.get(&"parameters/IdleWalkTransition/current_state") != "idle":
			_anim_tree.set(&"parameters/IdleWalkTransition/transition_request", "idle")
	else:
		if _anim_tree.get(&"parameters/IdleWalkTransition/current_state") != "walk":
			_anim_tree.set(&"parameters/IdleWalkTransition/transition_request", "walk")
		_anim_tree.set(&"parameters/WalkTimeScale/scale",
				player.get_real_velocity().length() / player.speed)


func _initialize() -> void:
	player.health_changed.connect(_on_player_health_changed)
	player.player_input.shooting_started.connect(_on_player_shooting_started)
	player.player_input.shooting_ended.connect(_on_player_shooting_ended)


func _on_player_health_changed(old: int, new: int) -> void:
	if old > new:
		_anim_tree.set(&"parameters/HurtOneShot/request",
				AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif old < new:
		_anim_tree.set(&"parameters/HealOneShot/request",
				AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_player_shooting_started() -> void:
	_anim_tree.set(&"parameters/EyesTransition/transition_request", "shooting")


func _on_player_shooting_ended() -> void:
	_anim_tree.set(&"parameters/EyesTransition/transition_request", "idle")
