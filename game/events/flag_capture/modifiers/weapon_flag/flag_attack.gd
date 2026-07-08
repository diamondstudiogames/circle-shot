extends Attack


@export var shoot_interval := 1.3
var _player: Player
var _shoot_timer: float
@onready var _flag: Flag = get_parent()
@onready var _event: Event = get_tree().get_first_node_in_group(&"world")
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if multiplayer.is_server():
		_flag.picked_up.connect(_on_picked_up)
		_flag.dropped.connect(_on_dropped)


func _physics_process(delta: float) -> void:
	super(delta)
	if not multiplayer.is_server():
		return
	_shoot_timer -= delta
	if not is_instance_valid(_player):
		return
	if _player.player_input.shooting and not _player.is_disarmed() and _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval
		_shoot.rpc()


@rpc("call_local", "reliable", "authority", 5)
func _shoot() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_anim.play(&"attack")
	_anim.seek(0.0)


func _on_picked_up(by: int) -> void:
	if not by in _event.players:
		return
	_player = _event.players[by]
	who = _player.id
	team = _player.team


func _on_dropped(_by: int) -> void:
	_player = null
