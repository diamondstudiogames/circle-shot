class_name Flag
extends Area2D

## Флаг для события "Захват флага".

## Команда, которой принадлежит этот флаг.
@export var team: int = 0
## Время, за которое флаг возвращается на базу при нахождении на земле.
@export_range(1.0, 20.0, 0.01) var return_time := 5.0

## Игрок, который держит этот флаг.
var player: Player

var _base_position: Vector2
var _return_timer := 0.0

@onready var _timer_progress: TextureProgressBar = $TimerProgress
@onready var _event: FlagCapture = get_tree().get_first_node_in_group(&"world")


func _ready() -> void:
	reset_physics_interpolation()
	if _event.local_team != team:
		($ScreenMarker as CanvasItem).hide()
		$ScreenMarker.queue_free()
	
	_base_position = position


func _exit_tree() -> void:
	if is_instance_valid(player):
		drop()


func _process(delta: float) -> void:
	if _return_timer > 0.0:
		_return_timer -= delta
		_timer_progress.value = _return_timer / return_time
		if _return_timer <= 0.0:
			_timer_progress.hide()
			if multiplayer.is_server():
				teleport_to_base.rpc()


@rpc("reliable", "call_local", "authority", 3)
func carry(id: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	if not id in _event.players:
		return
	
	_return_timer = 0.0
	_timer_progress.hide()
	player = _event.players[id]
	player.block_weapon_usage()
	if multiplayer.is_server():
		player.tree_exiting.connect(_drop)
	
	$CarryInteractible.process_mode = Node.PROCESS_MODE_DISABLED
	$DropInteractible.process_mode = Node.PROCESS_MODE_INHERIT
	
	var rt := RemoteTransform2D.new()
	rt.name = &"FlagRemote"
	rt.update_rotation = false
	rt.update_scale = false
	player.add_child(rt)
	rt.remote_path = get_path()
	rt.reset_physics_interpolation()
	print_verbose("Flag of team %d picked up by %d." % [team, player.id])


@rpc("reliable", "call_local", "authority", 3)
func drop(where: Vector2 = position) -> void:
	print_verbose("Flag of team %d dropped." % team)
	_return_timer = return_time
	_timer_progress.show()
	position = where
	reset_physics_interpolation()
	
	if not is_queued_for_deletion(): # обход ошибки движка
		$CarryInteractible.process_mode = Node.PROCESS_MODE_INHERIT
		$DropInteractible.process_mode = Node.PROCESS_MODE_DISABLED
	
	if not is_instance_valid(player):
		return
	if multiplayer.is_server():
		player.tree_exiting.disconnect(_drop)
	
	(player.get_node(^"FlagRemote") as RemoteTransform2D).remote_path = ^""
	player.get_node(^"FlagRemote").queue_free()
	player.unblock_weapon_usage()
	player = null


@rpc("reliable", "call_local", "authority", 3)
func teleport_to_base() -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	print_verbose("Teleporting team's %d flag to base." % team)
	position = _base_position
	reset_physics_interpolation()


func _drop() -> void:
	drop.rpc(position)


func _on_carry_interactible_interacted(who: Player) -> void:
	if multiplayer.is_server():
		carry.rpc(who.id)


func _on_drop_interactible_interacted(_who: Player) -> void:
	if multiplayer.is_server():
		_drop()
