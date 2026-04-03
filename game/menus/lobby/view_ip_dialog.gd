extends AcceptDialog


const HIDE_IPS: Array[String] = [
	"127.0.0.1",
	"0:0:0:0:0:0:0:1",
]
var _preffered_ips: Array[String]
var _other_ips: Array[String]
var _global_ip: String
@onready var _http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	var update_button: Button = add_button("Обновить IP-адреса", false, "update_ips")
	update_button.icon = load("uid://dmuffb51jxdkm")
	var copy_button: Button = add_button("Копировать IP-адреса", true, "copy_ips")
	copy_button.icon = load("uid://cp3wl6wn8h07v")


func _on_about_to_popup() -> void:
	_find_ips()
	size.y = 0 # Устанавливает минимальную высоту


func _find_ips() -> void:
	_preffered_ips.clear()
	_other_ips.clear()
	_global_ip = ""
	
	var ip_addresses: PackedStringArray = IP.get_local_addresses()
	for ip: String in ip_addresses:
		if ip in HIDE_IPS:
			continue
		var preffered := false
		for prefix: String in Game.LOCAL_IP_PREFIXES:
			if ip.begins_with(prefix):
				_preffered_ips.append(ip)
				preffered = true
				break
		if not preffered:
			_other_ips.append(ip)
	_preffered_ips.sort()
	_other_ips.sort()
	
	dialog_text = ""
	if not _preffered_ips.is_empty():
		dialog_text += "Локальные IP-адреса: "
		var first := true
		for ip: String in _preffered_ips:
			if not first:
				dialog_text += ", "
			dialog_text += ip
			first = false
		dialog_text += '\n'
	
	if not _other_ips.is_empty():
		dialog_text += "Остальные локальные IP-адреса: "
		var first := true
		for ip: String in _other_ips:
			if not first:
				dialog_text += ", "
			dialog_text += ip
			first = false
		dialog_text += '\n'
	
	if Globals.upnp:
		if Globals.upnp.status == UPNPManager.Status.INACTIVE:
			dialog_text += "Статус UPnP: Неактивно."
		else:
			dialog_text += "Статус UPnP: Активно."
			dialog_text += '\n'
			dialog_text += "Глобальный IP-адрес UPnP: %s" % Globals.upnp.get_external_ip()
		dialog_text += '\n'
	
	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	
	var error: Error = _http_request.request("https://ipv4.icanhazip.com/")
	if error != OK:
		push_warning("Quiry global IP: can't create request. Error: %s." % error_string(error))
		
		dialog_text += "Невозможно создать запрос для получения глобального IP-адреса!
Ошибка: %s." % error_string(error)


func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Quiry global IP: result is not Success. Result: %d." % result)
		dialog_text += "Ошибка запроса глобального IP-адреса! Код ошибки: %d." % result
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning("Quiry global IP: response code is not 200. Response code: %d" % response_code)
		dialog_text += "Ошибка получения глобального IP-адреса! Код ошибки: %d." % response_code
		return
	_global_ip = body.get_string_from_utf8().strip_escapes()
	dialog_text += "Глобальный IP-адрес: %s" % _global_ip
	dialog_text += '\n'
	dialog_text += "Чтобы игроки могли подключиться по глобальному IP-адресу, \
необходимо открыть порт: %d." % Game.DEFAULT_PORT
	if Globals.headless or OS.is_stdout_verbose():
		print("Global IP: %s" % _global_ip)


func _on_custom_action(action: StringName) -> void:
	match action:
		&"update_ips":
			_find_ips()
		&"copy_ips":
			if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				return
			var to_copy := ""
			if not _global_ip.is_empty():
				to_copy += _global_ip
				to_copy += '\n'
			if not _preffered_ips.is_empty():
				var first := true
				for ip: String in _preffered_ips:
					if not first:
						to_copy += ' '
					to_copy += ip
					first = false
				to_copy += '\n'
			if not _other_ips.is_empty():
				var first := true
				for ip: String in _other_ips:
					if not first:
						to_copy += ' '
					to_copy += ip
					first = false
			DisplayServer.clipboard_set(to_copy)
