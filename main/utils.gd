class_name Utils

## Класс с различными вспомогательными методами.

## Проверяет имя игрока и исправляет при необходимости. Если [param id] равен 0, не печатает
## никаких предупреждений. В [param valid] можно передать массив, который после выполнения
## функции будет содержать [code]true[/code], если имя игрока допустимо.[br]
## Недопустимое имя заменяется на "Игрок[[param id], если указан]".
static func validate_player_name(player_name: String, id: int = 0,
		valid: Array[bool] = []) -> String:
	# Там, где якобы пусто, стоит пустой символ
	player_name = strip_string(player_name)
	valid.append(not player_name.is_empty())
	if player_name.is_empty():
		var new_name: String = "Игрок%d" % id if id != 0 else "Игрок"
		if id != 0:
			push_warning("Client's %d player name length is invalid. Falling back to %s." % [
				id,
				new_name,
			])
		return new_name
	elif player_name.length() > Game.MAX_PLAYER_NAME_LENGTH:
		if id != 0:
			push_warning("Client's %d player name length (%d) is more than allowed (%d)." % [
				id,
				player_name.length(),
				Game.MAX_PLAYER_NAME_LENGTH,
			])
		return player_name.left(Game.MAX_PLAYER_NAME_LENGTH)
	return player_name


## Возвращает текстовое представление закодированного в двух числах (тип и значение) события ввода.
static func encoded_input_event_as_text(type: Globals.EncodedInputEventType, value: int) -> String:
	match type:
		Globals.EncodedInputEventType.KEY:
			return OS.get_keycode_string(value)
		Globals.EncodedInputEventType.MOUSE_BUTTON:
			match value:
				MOUSE_BUTTON_LEFT:
					return "ЛКМ"
				MOUSE_BUTTON_MIDDLE:
					return "СКМ"
				MOUSE_BUTTON_RIGHT:
					return "ПКМ"
				MOUSE_BUTTON_XBUTTON1:
					return "X1"
				MOUSE_BUTTON_XBUTTON2:
					return "X2"
				MOUSE_BUTTON_WHEEL_DOWN:
					return "Колесо вниз"
				MOUSE_BUTTON_WHEEL_LEFT:
					return "Колесо влево"
				MOUSE_BUTTON_WHEEL_RIGHT:
					return "Колесо вправо"
				MOUSE_BUTTON_WHEEL_UP:
					return "Колесо вверх"
		Globals.EncodedInputEventType.JOYPAD_MOTION:
			match int(value / 2.0):
				JOY_AXIS_LEFT_X:
					return "Левый стик влево" if value % 2 == 0 else "Левый стик вправо"
				JOY_AXIS_LEFT_Y:
					return "Левый стик вверх" if value % 2 == 0 else "Левый стик вниз"
				JOY_AXIS_RIGHT_X:
					return "Правый стик влево" if value % 2 == 0 else "Правый стик вправо"
				JOY_AXIS_RIGHT_Y:
					return "Правый стик вверх" if value % 2 == 0 else  "Правый стик вниз"
				JOY_AXIS_TRIGGER_LEFT:
					return "Левый триггер"
				JOY_AXIS_TRIGGER_RIGHT:
					return "Правый триггер"
		Globals.EncodedInputEventType.JOYPAD_BUTTON:
			const GAMEPAD_SCHEME_XBOX: int = 0
			const GAMEPAD_SCHEME_PLAYSTATION: int = 1
			const GAMEPAD_SCHEME_NINTENDO: int = 2
			const GAMEPAD_SCHEME_UNKNOWN: int = 3
			const SCHEME_IDENTIFIERS: Dictionary[int, Array] = {
				GAMEPAD_SCHEME_NINTENDO: ["nintendo", "joy-con", "gamecube"],
				GAMEPAD_SCHEME_PLAYSTATION: ["sony", "playstation", "dualshock",
					"ps1", "ps2", "ps3", "ps4", "ps5"],
				GAMEPAD_SCHEME_XBOX: ["xbox", "microsoft"]
			}
			
			var gamepad_scheme: int = GAMEPAD_SCHEME_UNKNOWN
			var connected_devices: Array[int] = Input.get_connected_joypads()
			if not connected_devices.is_empty():
				var gamepad_name: String = Input.get_joy_name(connected_devices[0])
				for scheme: int in SCHEME_IDENTIFIERS:
					for scheme_term: String in SCHEME_IDENTIFIERS[scheme]:
						if gamepad_name.containsn(scheme_term):
							gamepad_scheme = scheme
							break
			
			match value:
				JOY_BUTTON_DPAD_UP:
					return "D-Pad вверх"
				JOY_BUTTON_DPAD_DOWN:
					return "D-Pad вниз"
				JOY_BUTTON_DPAD_LEFT:
					return "D-Pad влево"
				JOY_BUTTON_DPAD_RIGHT:
					return "D-Pad вправо"
				JOY_BUTTON_TOUCHPAD:
					return "Тачпад"
				JOY_BUTTON_PADDLE1:
					return "Paddle 1"
				JOY_BUTTON_PADDLE2:
					return "Paddle 2"
				JOY_BUTTON_PADDLE3:
					return "Paddle 3"
				JOY_BUTTON_PADDLE4:
					return "Paddle 4"
				
				JOY_BUTTON_MISC1:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "Микрофон"
						GAMEPAD_SCHEME_XBOX:
							return "Поделиться"
						GAMEPAD_SCHEME_NINTENDO:
							return "Захват"
					return "Misc 1"
				JOY_BUTTON_LEFT_STICK:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "L3"
						GAMEPAD_SCHEME_XBOX:
							return "L/LS"
					return "Левый стик"
				JOY_BUTTON_RIGHT_STICK:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "R3"
						GAMEPAD_SCHEME_XBOX:
							return "R/RS"
					return "Правый стик"
				JOY_BUTTON_LEFT_SHOULDER:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "L1"
						GAMEPAD_SCHEME_XBOX:
							return "LB"
					return "Левый бампер"
				JOY_BUTTON_RIGHT_SHOULDER:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "R1"
						GAMEPAD_SCHEME_XBOX:
							return "RB"
					return "Правый бампер"
				JOY_BUTTON_START:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "Настройки"
						GAMEPAD_SCHEME_XBOX:
							return "Меню"
						GAMEPAD_SCHEME_NINTENDO:
							return '+'
					return "Старт"
				JOY_BUTTON_GUIDE:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "Playstation"
						GAMEPAD_SCHEME_XBOX, GAMEPAD_SCHEME_NINTENDO:
							return "Домой"
					return "Управление"
				JOY_BUTTON_BACK:
					match gamepad_scheme:
						GAMEPAD_SCHEME_PLAYSTATION:
							return "Выбор"
						GAMEPAD_SCHEME_NINTENDO:
							return '-'
					return "Назад"
				
				JOY_BUTTON_A:
					match gamepad_scheme:
						GAMEPAD_SCHEME_NINTENDO:
							return 'B'
						GAMEPAD_SCHEME_PLAYSTATION:
							return '⨯'
						GAMEPAD_SCHEME_XBOX:
							return 'A'
					return "Нижнее действие"
				JOY_BUTTON_B:
					match gamepad_scheme:
						GAMEPAD_SCHEME_NINTENDO:
							return 'A'
						GAMEPAD_SCHEME_PLAYSTATION:
							return '○'
						GAMEPAD_SCHEME_XBOX:
							return 'B'
					return "Правое действие"
				JOY_BUTTON_X:
					match gamepad_scheme:
						GAMEPAD_SCHEME_NINTENDO:
							return 'Y'
						GAMEPAD_SCHEME_PLAYSTATION:
							return '□'
						GAMEPAD_SCHEME_XBOX:
							return 'X'
					return "Левое действие"
				JOY_BUTTON_Y:
					match gamepad_scheme:
						GAMEPAD_SCHEME_NINTENDO:
							return 'X'
						GAMEPAD_SCHEME_PLAYSTATION:
							return '△'
						GAMEPAD_SCHEME_XBOX:
							return 'Y'
					return "Верхнее действие"
	return "НЕИЗВЕСТНО"


## Возвращает [code]true[/code], если указанный адрес в [param address] может использоваться
## для подключения к серверу. Если [param check_domain] равняется [code]true[/code], то
## также выполняется проверка существования домена (если указан не IP-адрес).
static func is_valid_address(address: String, check_domain: bool) -> bool:
	return (
			address.is_valid_ip_address()
			or (address.count('.') > 0 and address.find('.') > 0
			and address.rfind('.') < address.length() - 1)
			and not (check_domain and IP.resolve_hostname(address).is_empty())
	)


## Избавляет строку от различных вспомогательных символов (пробелы, ...).
static func strip_string(string: String) -> String:
	return string.strip_edges().strip_escapes().lstrip('⁣').rstrip('⁣')


## Считает шансы для ящиков, где [param *_base] - базовые шансы, [param *_got] - сколько предметов
## определённых редкостей было получено без награды, [param chance_increase] - на сколько процентов
## относительно базового повышается шанс на редкость за каждое открытие без награды.
## Возвращает массив из трёх элементов - непосредственно шансы. Всё указывается в процентах.
static func calculate_box_chances(rare_base: float, epic_base: float, legendary_base: float,
		chance_increase: float, rare_got: int, epic_got: int, legendary_got: int) -> Array[float]:
	const MIN_CHANCE := 0.2
	var chances: Array[float]
	chances.append(rare_base)
	chances.append(epic_base)
	chances.append(legendary_base)
	
	for i: int in legendary_got:
		var rare_increase: float = rare_base * chance_increase / 100.0
		var epic_increase: float = epic_base * chance_increase / 100.0
		var decrease: float = minf(rare_increase + epic_increase,
				chances[2] - legendary_base * MIN_CHANCE)
		if is_zero_approx(decrease):
			continue
		rare_increase = decrease / (rare_increase + epic_increase) * rare_increase
		epic_increase = decrease / (rare_increase + epic_increase) * epic_increase
		chances[0] += rare_increase
		chances[1] += epic_increase
		chances[2] -= decrease
	
	for i: int in epic_got:
		var rare_increase: float = rare_base * chance_increase / 100.0
		var legendary_increase: float = legendary_base * chance_increase / 100.0
		var decrease: float = minf(rare_increase + legendary_increase,
				chances[1] - epic_base * MIN_CHANCE)
		if is_zero_approx(decrease):
			continue
		rare_increase = decrease / (rare_increase + legendary_increase) * rare_increase
		legendary_increase = decrease / (rare_increase + legendary_increase) * legendary_increase
		chances[0] += rare_increase
		chances[1] -= decrease
		chances[2] += legendary_increase
	
	for i: int in rare_got:
		var epic_increase: float = epic_base * chance_increase / 100.0
		var legendary_increase: float = legendary_base * chance_increase / 100.0
		var decrease: float = minf(epic_increase + legendary_increase,
				chances[0] - rare_base * MIN_CHANCE)
		if is_zero_approx(decrease):
			continue
		epic_increase = decrease / (epic_increase + legendary_increase) * epic_increase
		legendary_increase = decrease / (epic_increase + legendary_increase) * legendary_increase
		chances[0] -= decrease
		chances[1] += epic_increase
		chances[2] += legendary_increase
	
	return chances


## Распределяет игроков на 2 команды, опираясь на уже распределённых игроков (если есть).
## [param players_names] - словарь вида ID - имя игрока,
## [param players_teams] - словарь вида ID - команда игрока.
static func make_teams(players_names: Dictionary[int, String],
		players_teams: Dictionary[int, Entity.Team]) -> void:
	var places: Dictionary[Entity.Team, int]
	places[Entity.Team.RED] = floori(players_names.size() / 2.0)
	places[Entity.Team.BLUE] = floori(players_names.size() / 2.0)
	# если нечётное колво игроков, к случайной команде добавляем место
	if places[Entity.Team.RED] + places[Entity.Team.BLUE] != players_names.size():
		places[randi() % 2] += 1
	
	for id: int in players_teams:
		places[players_teams[id]] -= 1
		if places[players_teams[id]] < 0:
			# где-то ошиблись, вернём к нулю и вычтем из другого
			places[players_teams[id]] = 0
			places[1 - players_teams[id]] = 0
	
	var ids: Array[int]
	ids.assign(players_names.keys())
	ids.shuffle()
	for id: int in ids:
		if id in players_teams:
			continue
		
		if places[Entity.Team.RED] > 0:
			players_teams[id] = Entity.Team.RED
			places[Entity.Team.RED] -= 1
		elif places[Entity.Team.BLUE] > 0:
			players_teams[id] = Entity.Team.BLUE
			places[Entity.Team.BLUE] -= 1
		else:
			# по идее такого быть не должно, запихаем в красную
			players_teams[id] = Entity.Team.RED
			push_error("Places were exhausted, but player %d remained. Moving to red team." % id)
