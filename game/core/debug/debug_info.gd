extends CanvasLayer


var _sent_ticks_msec: int
var _last_ping: int
@onready var _ping_label: Label = $PingLabel
@onready var _ping_timer: Timer = $PingLabel/PingTimer
@onready var _fps_label: Label = $FPSLabel


func _ready() -> void:
	Globals.settings_applied.connect(_on_settings_applied)
	if not Globals.get_setting_bool("debug_info"):
		hide()
		if not OS.is_debug_build():
			process_mode = Node.PROCESS_MODE_DISABLED
			return
	
	if OS.is_debug_build():
		Performance.add_custom_monitor(&"Network/Ping", get.bind(&"_last_ping"))


func _exit_tree() -> void:
	if OS.is_debug_build():
		Performance.remove_custom_monitor(&"Network/Ping")


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


@rpc("any_peer", "reliable", "call_remote", 10)
func _process_ping() -> void:
	_ping_response.rpc_id(multiplayer.get_remote_sender_id())


@rpc("reliable", "authority", "call_remote", 10)
func _ping_response() -> void:
	var ping_msec: int = Time.get_ticks_msec() - _sent_ticks_msec
	_last_ping = ping_msec
	_ping_label.text = "Пинг: %d мс" % ping_msec
	_ping_timer.start()


func _do_ping() -> void:
	_sent_ticks_msec = Time.get_ticks_msec()
	_process_ping.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _on_settings_applied() -> void:
	visible = Globals.get_setting_bool("debug_info")
	if not OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_ALWAYS if Globals.get_setting_bool("debug_info") \
				else Node.PROCESS_MODE_DISABLED


func _on_game_joined() -> void:
	_ping_timer.start()
	_ping_label.text = ""
	_ping_label.show()


func _on_game_closed() -> void:
	_ping_timer.stop()
	_ping_label.hide()
	_last_ping = 0


func _on_ping_timer_timeout() -> void:
	_do_ping()
