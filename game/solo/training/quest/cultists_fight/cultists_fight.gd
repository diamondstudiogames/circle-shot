extends World


signal ended(victory: bool)
signal time_changed(remained_time: int)

@export var challenge_time: int = 210
@export var kills_to_heal_box: int = 8
@export var kills_to_ammo_box: int = 15
@export var spawn_interval_curve: Curve

@export var shake_amplitude := 5.0
@export var shake_step := 0.05

var _time_survived: int = 0
var _spawn_points_counter: int = 0
var _spawn_points: Array[Node2D]
var _shake_timer := 0.0

var _spawn_heal_box_counter: int = 0
var _spawn_ammo_box_counter: int = 0
var _heal_box_scene: PackedScene = load("uid://bysyaaj2r7stt")
var _ammo_box_scene: PackedScene = load("uid://bdtqr6mv231py")

@onready var _camera: SmartCamera = $Camera
@onready var _spawn_timer: Timer = $SpawnTimer


func _process(delta: float) -> void:
	_shake_timer += delta
	if _shake_timer > shake_step:
		_camera.offset = Vector2(randf_range(-shake_amplitude, shake_amplitude),
				randf_range(-shake_amplitude, shake_amplitude))
		_shake_timer = 0.0


func _initialize() -> void:
	_spawn_points.assign($Map/CultistsSpawnPoints.get_children())
	_spawn_points.shuffle()
	_spawn_timer.start(spawn_interval_curve.sample(0.0))
	_spawn_player()
	time_changed.emit(challenge_time)
	if not tracks.is_empty():
		($Music as AudioStreamPlayer).stream = tracks.pick_random()
		($Music as AudioStreamPlayer).play()


func _local_player_died() -> void:
	_shake_timer = -8.0
	ended.emit(false)


func _freeze_entities() -> void:
	get_tree().call_group(&"entity", &"make_disarmed")
	get_tree().call_group(&"entity", &"make_immobile")
	get_tree().call_group(&"entity", &"make_immune")
	get_tree().call_group(&"entity", &"block_turning")


func _spawn_player() -> void:
	var player: Player = entity_scenes[0].instantiate()
	player.position = ($Map/SpawnPoint as Node2D).global_position
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
	player.name = "Player%d" % player.id
	$Entities.add_child(player)


func _spawn_cultist(idx: int) -> void:
	var cultist: Entity = entity_scenes[1 + idx].instantiate()
	cultist.position = _spawn_points[_spawn_points_counter].global_position
	cultist.team = 4
	cultist.id = -randi()
	cultist.name += str(cultist.id)
	cultist.died.connect(_on_cultist_died.bind(cultist))
	$Entities.add_child(cultist, true)
	
	_spawn_points_counter += 1
	if _spawn_points_counter == _spawn_points.size():
		_spawn_points_counter = 0
		_spawn_points.shuffle()


func _spawn_heal_box(where: Vector2) -> void:
	var heal_box: Node2D = _heal_box_scene.instantiate()
	heal_box.position = where
	heal_box.name += str(randi())
	$Other.add_child(heal_box, true)


func _spawn_ammo_box(where: Vector2) -> void:
	var ammo_box: Node2D = _ammo_box_scene.instantiate()
	ammo_box.position = where
	ammo_box.name += str(randi())
	$Other.add_child(ammo_box, true)


func _on_cultist_died(cultist: Entity) -> void:
	_spawn_ammo_box_counter += 1
	_spawn_heal_box_counter += 1
	if _spawn_ammo_box_counter == kills_to_ammo_box \
			and _spawn_heal_box_counter != kills_to_heal_box:
		_spawn_ammo_box(cultist.global_position)
		_spawn_ammo_box_counter = 0
	elif _spawn_ammo_box_counter != kills_to_ammo_box \
			and _spawn_heal_box_counter == kills_to_heal_box:
		_spawn_heal_box(cultist.global_position)
		_spawn_heal_box_counter = 0
	elif _spawn_ammo_box_counter == kills_to_ammo_box \
			and _spawn_heal_box_counter == kills_to_heal_box:
		if randi() % 2 == 0:
			_spawn_heal_box(cultist.global_position)
		else:
			_spawn_ammo_box(cultist.global_position)
		_spawn_ammo_box_counter = 0
		_spawn_heal_box_counter = 0


func _on_spawn_timer_timeout() -> void:
	_spawn_cultist(randi() % 2)
	_spawn_timer.start(spawn_interval_curve.sample(_time_survived))


func _on_survived_timer_timeout() -> void:
	_time_survived += 1
	time_changed.emit(challenge_time - _time_survived)
	if _time_survived >= challenge_time:
		ended.emit(true)


func _on_ended(victory: bool) -> void:
	_freeze_entities()
	_spawn_timer.stop()
	($SurvivedTimer as Timer).stop()
	($Music as AudioStreamPlayer).stop()
	
	if victory:
		Globals.set_bool("quest_completed", true)
	
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.one_shot = true
	add_child(timer)
	await timer.timeout
	Globals.main.game.close()
