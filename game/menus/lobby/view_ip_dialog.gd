extends AcceptDialog


const HIDE_IPS: Array[String] = [
	"127.0.0.1",
	"0:0:0:0:0:0:0:1",
]
var _preffered_ips: Array[String]
var _other_ips: Array[String]
var _global_ip: String
var _global_ipv4: String

var _lines: Array[String] = []

@onready var _http_request: HTTPRequest = $HTTPRequest
@onready var _http_request_ipv4: HTTPRequest = $HTTPRequestIPv4


func _ready() -> void:
	var update_button: Button = add_button("Обновить IP-адреса", false, "update_ips")
	update_button.icon = load("uid://dmuffb51jxdkm")
	var copy_button: Button = add_button("Копировать IP-адреса", true, "copy_ips")
	copy_button.icon = load("uid://cp3wl6wn8h07v")


func _find_ips() -> void:
	_preffered_ips.clear()
	_other_ips.clear()
	_global_ip = ""
	_global_ipv4 = ""
	
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
	_preffered_ips.sort_custom(_sort_ips)
	_other_ips.sort_custom(_sort_ips)
	
	_clear_lines()
	if not _preffered_ips.is_empty():
		var line: String = "Локальные IP-адреса: "
		line += ", ".join(_preffered_ips)
		_add_line(line)
	
	if not _other_ips.is_empty():
		var line: String = "Остальные локальные IP-адреса: "
		line += ", ".join(_other_ips)
		_add_line(line)
	
	if _preffered_ips.is_empty() and _other_ips.is_empty():
		_add_line("Нет IP-адресов. Возможно, устройство не подключено к сети.")
		return
	
	if Globals.upnp:
		if Globals.upnp.status == UPNPManager.Status.INACTIVE:
			_add_line("Статус UPnP: Неактивно.")
		else:
			_add_line("Статус UPnP: Активно.")
			_add_line("Глобальный IP-адрес UPnP: %s" % Globals.upnp.get_external_ip())
			_add_line("Этот адрес может использован другими игроками для подключения.")
	
	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_request.cancel_request()
	_add_line("Получение глобального IP-адреса...")
	var error: Error = _http_request.request("https://icanhazip.com/")
	if error != OK:
		_remove_last_line()
		push_warning("Quiry global IP: can't create request. Error: %s." % error_string(error))
		_add_line("Невозможно создать запрос для получения глобального IP-адреса! Ошибка: %s."
				% error_string(error))


func _add_line(line: String) -> void:
	_lines.append(line)
	dialog_text = '\n'.join(_lines)


func _remove_last_line() -> void:
	_lines.pop_back()
	dialog_text = '\n'.join(_lines)


func _clear_lines() -> void:
	_lines.clear()
	dialog_text = ""


func _sort_ips(first: String, second: String) -> bool:
	if (':' in first) != (':' in second):
		return ':' in second
	return first < second


func _on_about_to_popup() -> void:
	_find_ips()
	set_deferred(&"size", Vector2i.ONE) # Устанавливает минимальную высоту


func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	if _lines[-1].begins_with("Получение"):
		_remove_last_line()
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Quiry global IP: result is not Success. Result: %d." % result)
		_add_line("Ошибка запроса глобального IP-адреса! Код ошибки: %d." % result)
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning("Quiry global IP: response code is not 200. Response code: %d" % response_code)
		_add_line("Ошибка получения глобального IP-адреса! Код ошибки: %d." % response_code)
		return
	_global_ip = body.get_string_from_utf8().strip_escapes()
	_add_line("Глобальный IP-адрес: %s" % _global_ip)
	
	if ':' in _global_ip:
		# перед нами ipv6, запустим проверку и на ipv4
		_add_line("Этот адрес может использован другими игроками для подключения.")
		
		if _http_request_ipv4.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_http_request_ipv4.cancel_request()
		_add_line("Получение глобального IPv4-адреса...")
		var error: Error = _http_request_ipv4.request("https://ipv4.icanhazip.com/")
		if error != OK:
			_remove_last_line()
			push_warning("Quiry global IPv4: can't create request. Error: %s."
					% error_string(error))
			_add_line("Невозможно создать запрос для получения глобального IPv5-адреса! Ошибка: %s."
					% error_string(error))
	else:
		# обычный ipv4
		_global_ipv4 = _global_ip
		_add_line("Чтобы игроки могли подключиться по этому адресу, необходимо открыть порт: %d."
				% Game.DEFAULT_PORT)
	
	if Globals.headless or OS.is_stdout_verbose():
		print("Global IP: %s" % _global_ip)


func _on_ipv4_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	if _lines[-1].begins_with("Получение"):
		_remove_last_line()
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Quiry global IPv4: result is not Success. Result: %d." % result)
		_add_line("Ошибка запроса глобального IPv4-адреса! Код ошибки: %d." % result)
		return
	if response_code != HTTPClient.RESPONSE_OK:
		push_warning("Quiry global IPv4: response code is not 200. Response code: %d" % response_code)
		_add_line("Ошибка получения глобального IPv4-адреса! Код ошибки: %d." % response_code)
		return
	_global_ipv4 = body.get_string_from_utf8().strip_escapes()
	_add_line("Глобальный IPv4-адрес: %s" % _global_ipv4)
	_add_line("Чтобы игроки могли подключиться по этому адресу, необходимо открыть порт: %d."
			% Game.DEFAULT_PORT)
	if Globals.headless or OS.is_stdout_verbose():
		print("Global IPv4: %s" % _global_ipv4)


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
				if _global_ip != _global_ipv4 and not _global_ipv4.is_empty():
					to_copy += _global_ipv4
					to_copy += '\n'
			if not _preffered_ips.is_empty():
				to_copy += ' '.join(_preffered_ips)
				to_copy += '\n'
			if not _other_ips.is_empty():
				to_copy += ' '.join(_other_ips)
			DisplayServer.clipboard_set(to_copy)
