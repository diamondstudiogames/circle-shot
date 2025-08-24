extends VBoxContainer


enum Mode {
	MOVE_CAMERA = 0,
	DRAW = 1,
	LINE = 2,
	RECT = 3,
	PLACING_ENEMIES = 4,
}
const DEADZONE := 16.0
const MAX_ENEMIES_COUNT: int = 15

var _mode := Mode.MOVE_CAMERA
var _prev_mode: Mode
var _drag_start_mouse_position: Vector2
var _drag_start_main_view_scroll: Vector2
var _dragging := false

var _block_type: Training.BlockType
var _enemy_type: Training.EnemyType

var _map_data: PackedByteArray
var _enemies_data: Array[Training.EnemyData]
var _editing_enemy_idx: int
var _moving_enemy := false

var _map_image: Image
var _map_image_texture: ImageTexture
var _map_image_dirty := false

@onready var _training: Training = owner
@onready var _map: TextureRect = $Main/MainView/MapHolder/Map
@onready var _main_view: ScrollContainer = $Main/MainView
@onready var _status: Label = $EditorStatus


func _process(_delta: float) -> void:
	if _map_image_dirty:
		_map_image_texture.update(_map_image)
		_map_image_dirty = false


func _initialize() -> void:
	_map_data = _training.get_map_data().duplicate()
	_map_image = Image.create_empty(Training.MAP_SIZE.x, Training.MAP_SIZE.y,
			false, Image.FORMAT_RGBA8)
	for x: int in Training.MAP_SIZE.x:
		for y: int in Training.MAP_SIZE.y:
			if _is_safe_coord(x, y):
				_map_image.set_pixel(x, y,
						Training.BLOCK_COLORS[_map_data[y * Training.MAP_SIZE.x + x]])
			else:
				_map_image.set_pixel(x, y, Color.RED)
	
	_map_image_texture = ImageTexture.create_from_image(_map_image)
	_map.texture = _map_image_texture
	
	_enemies_data.clear()
	# копируем чтобы избежать неприятностей
	for enemy_data: Training.EnemyData in _training.enemies_data:
		var new_enemy_data := Training.EnemyData.new(enemy_data.type, enemy_data.coords)
		new_enemy_data.health = enemy_data.health
		new_enemy_data.damage_multiplier = enemy_data.damage_multiplier
		new_enemy_data.speed_multiplier = enemy_data.speed_multiplier
		_enemies_data.append(new_enemy_data)
	
	_update_enemies()
	if _mode == Mode.PLACING_ENEMIES:
		_status.text = "Врагов размещено: %d/%d" % [_enemies_data.size(), MAX_ENEMIES_COUNT]


func _draw_line(from: Vector2, to: Vector2) -> void:
	var start_coord := Vector2i(from.floor())
	start_coord.x = clampi(start_coord.x, 0, Training.MAP_SIZE.x - 1)
	start_coord.y = clampi(start_coord.y, 0, Training.MAP_SIZE.y - 1)
	var end_coord := Vector2i(to.floor())
	end_coord.x = clampi(end_coord.x, 0, Training.MAP_SIZE.x - 1)
	end_coord.y = clampi(end_coord.y, 0, Training.MAP_SIZE.y - 1)
	
	var points: Array[Vector2i] = Geometry2D.bresenham_line(start_coord, end_coord)
	for point: Vector2i in points:
		if not _is_safe_coord(point.x, point.y):
			continue
		_map_image.set_pixel(point.x, point.y, Training.BLOCK_COLORS[_block_type])
		_map_data[point.y * Training.MAP_SIZE.x + point.x] = _block_type
	_map_image_dirty = true
	
	if _block_type == Training.BlockType.GRASS:
		return # на траву врагам пофигу
	
	var enemies_to_remove: Array[int] = []
	for idx: int in _enemies_data.size():
		if _enemies_data[idx].coords in points:
			enemies_to_remove.append(idx)
	enemies_to_remove.reverse()
	for idx_to_remove: int in enemies_to_remove:
		_enemies_data.remove_at(idx_to_remove)
	
	if not enemies_to_remove.is_empty():
		_update_enemies()


func _draw_rect(from: Vector2, to: Vector2) -> void:
	var start_coord := Vector2i(floori(minf(from.x, to.x)), floori(minf(from.y, to.y)))
	start_coord.x = clampi(start_coord.x, 0, Training.MAP_SIZE.x - 1)
	start_coord.y = clampi(start_coord.y, 0, Training.MAP_SIZE.y - 1)
	var end_coord := Vector2i(floori(maxf(from.x, to.x)), floori(maxf(from.y, to.y)))
	end_coord.x = clampi(end_coord.x, 0, Training.MAP_SIZE.x - 1)
	end_coord.y = clampi(end_coord.y, 0, Training.MAP_SIZE.y - 1)
	
	for x: int in range(start_coord.x, end_coord.x + 1):
		for y: int in range(start_coord.y, end_coord.y + 1):
			if not _is_safe_coord(x, y):
				continue
			_map_image.set_pixel(x, y, Training.BLOCK_COLORS[_block_type])
			_map_data[y * Training.MAP_SIZE.x + x] = _block_type
	_map_image_dirty = true
	
	if _block_type == Training.BlockType.GRASS:
		return # на траву врагам пофигу
	
	var enemies_to_remove: Array[int] = []
	for idx: int in _enemies_data.size():
		var enemy_coords: Vector2i = _enemies_data[idx].coords
		if enemy_coords.x < start_coord.x or enemy_coords.x > end_coord.x \
				or enemy_coords.y < start_coord.y or enemy_coords.y > end_coord.y:
			continue
		enemies_to_remove.append(idx)
	enemies_to_remove.reverse()
	for idx_to_remove: int in enemies_to_remove:
		_enemies_data.remove_at(idx_to_remove)
	
	if not enemies_to_remove.is_empty():
		_update_enemies()


func _place_enemy(where: Vector2) -> void:
	if _enemies_data.size() >= MAX_ENEMIES_COUNT:
		_status.text = "Превышение максимального количества в %d врагов" % MAX_ENEMIES_COUNT
		return
	
	var coords := Vector2i(where.floor())
	if not _is_safe_coord(coords.x, coords.y):
		return
	if _map_data[coords.y * Training.MAP_SIZE.x + coords.x] != Training.BlockType.GRASS:
		return
	
	var enemy_data := Training.EnemyData.new(_enemy_type, coords)
	_enemies_data.append(enemy_data)
	_status.text = "Врагов размещено: %d/%d" % [_enemies_data.size(), MAX_ENEMIES_COUNT]
	
	_update_enemies()


func _move_enemy(where: Vector2) -> void:
	var coords := Vector2i(where.floor())
	if not _is_safe_coord(coords.x, coords.y):
		return
	if _map_data[coords.y * Training.MAP_SIZE.x + coords.x] != Training.BlockType.GRASS:
		return
	
	for idx: int in _enemies_data.size():
		if idx == _editing_enemy_idx:
			continue
		if _enemies_data[idx].coords == coords:
			return
	
	_enemies_data[_editing_enemy_idx].coords = coords
	_moving_enemy = false
	_update_enemies()
	
	_status.text = "Перемещено успешно."


func _cancel_move_enemy() -> void:
	for enemy_tb: TextureButton in _map.get_children():
		enemy_tb.self_modulate = Color.WHITE
		enemy_tb.mouse_filter = Control.MOUSE_FILTER_PASS
	_moving_enemy = false


func _update_enemies() -> void:
	for child: Node in _map.get_children():
		_map.remove_child(child)
		child.queue_free()
	
	for idx: int in _enemies_data.size():
		var enemy_data: Training.EnemyData = _enemies_data[idx]
		var tb := TextureButton.new()
		tb.mouse_filter = Control.MOUSE_FILTER_PASS
		tb.texture_normal = _training.enemies_icons[enemy_data.type]
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		tb.size = Vector2.ONE * 64
		tb.scale = Vector2.ONE / _map.scale
		tb.pivot_offset = Vector2.ONE * 32
		_map.add_child(tb)
		tb.position = Vector2(enemy_data.coords) + Vector2.ONE * 0.5
		tb.position -= Vector2.ONE * 32 # компенсируем pivot_offset
		
		tb.pressed.connect(_edit_enemy.bind(idx))


func _edit_enemy(idx: int) -> void:
	(%HealthSlider/Slider as Range).value = _enemies_data[idx].health
	(%DamageSlider/Slider as Range).value = _enemies_data[idx].damage_multiplier
	(%SpeedSlider/Slider as Range).value = _enemies_data[idx].speed_multiplier
	
	($EditEnemy as Window).popup_centered()
	_editing_enemy_idx = idx


func _is_safe_coord(x: int, y: int) -> bool:
	return x < (Training.MAP_SIZE.x / 2.0) - 2 or x > (Training.MAP_SIZE.x / 2.0) + 1 \
			or y < (Training.MAP_SIZE.y / 2.0) - 2 or y > (Training.MAP_SIZE.y / 2.0) + 1


func _on_edit_map_pressed() -> void:
	_initialize()


func _on_save_pressed() -> void:
	if _moving_enemy:
		_cancel_move_enemy()
	
	Globals.set_variant("custom_training_map", _map_data)
	
	var enemies_data_array: Array[Dictionary]
	for enemy_data: Training.EnemyData in _enemies_data:
		enemies_data_array.append({
			"type": enemy_data.type,
			"health": enemy_data.health,
			"damage_multiplier": enemy_data.damage_multiplier,
			"speed_multiplier": enemy_data.speed_multiplier,
			"coords": enemy_data.coords,
		})
	Globals.set_variant("custom_training_map_enemies", enemies_data_array)
	_status.text = "Изменения сохранены."


func _on_reset_dialog_confirmed() -> void:
	if _moving_enemy:
		_cancel_move_enemy()
	
	Globals.set_variant("custom_training_map", PackedByteArray())
	Globals.set_variant("custom_training_map_enemies", [{}] as Array[Dictionary])
	($Header/CloseMapEditor as BaseButton).pressed.emit()
	_status.text = "Сброшено до варианта карты по умолчанию."


func _on_zoom_in_pressed() -> void:
	_map.scale += Vector2.ONE * 2.5
	_map.scale = _map.scale.clampf(10.0, 30.0)
	_map.get_parent_control().custom_minimum_size = _map.scale.x * Training.MAP_SIZE
	
	for child: Control in _map.get_children():
		child.scale = Vector2.ONE / _map.scale


func _on_zoom_out_pressed() -> void:
	_map.scale -= Vector2.ONE * 2.5
	_map.scale = _map.scale.clampf(10.0, 30.0)
	_map.get_parent_control().custom_minimum_size = _map.scale.x * Training.MAP_SIZE
	
	for child: Control in _map.get_children():
		child.scale = Vector2.ONE / _map.scale


func _on_map_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if _dragging:
			_drag_start_mouse_position = mb.global_position
			_drag_start_main_view_scroll = \
					Vector2(_main_view.scroll_horizontal, _main_view.scroll_vertical)
		else:
			if _moving_enemy:
				_move_enemy(mb.position)
				return
			match _mode:
				Mode.DRAW:
					_draw_line(mb.position, mb.position)
				Mode.RECT:
					_map.queue_redraw()
					_draw_rect(_map.get_global_transform().affine_inverse()
							* _drag_start_mouse_position, mb.position)
				Mode.LINE:
					_map.queue_redraw()
					_draw_line(_map.get_global_transform().affine_inverse()
							* _drag_start_mouse_position, mb.position)
				Mode.PLACING_ENEMIES:
					var mouse_difference: Vector2 = mb.global_position - _drag_start_mouse_position
					if mouse_difference.length() <= DEADZONE and not ($EditEnemy as Window).visible:
						_place_enemy(mb.position)
	
	if _dragging:
		var mm := event as InputEventMouseMotion
		if mm:
			match _mode:
				Mode.MOVE_CAMERA, Mode.PLACING_ENEMIES:
					var mouse_difference: Vector2 = mm.global_position - _drag_start_mouse_position
					if mouse_difference.length() >= DEADZONE:
						mouse_difference -= mouse_difference.normalized() * DEADZONE
						_main_view.scroll_horizontal = \
								roundi(_drag_start_main_view_scroll.x - mouse_difference.x)
						_main_view.scroll_vertical = \
								roundi(_drag_start_main_view_scroll.y - mouse_difference.y)
				Mode.DRAW:
					_draw_line(mm.position - mm.relative, mm.position)
				Mode.RECT, Mode.LINE:
					_map.queue_redraw()


func _on_map_draw() -> void:
	if not _dragging:
		return
	
	var start_mouse_pos: Vector2 = \
			_map.get_global_transform().affine_inverse() * _drag_start_mouse_position
	var mouse_pos: Vector2 = _map.get_local_mouse_position()
	var color: Color = Training.BLOCK_COLORS[_block_type]
	color = color.darkened(0.5)
	color.a = 0.5
	
	match _mode:
		Mode.RECT:
			var rect := Rect2(
					minf(mouse_pos.x, start_mouse_pos.x),
					minf(mouse_pos.y, start_mouse_pos.y),
					absf(mouse_pos.x - start_mouse_pos.x),
					absf(mouse_pos.y - start_mouse_pos.y),
			)
			_map.draw_rect(rect, color)
		Mode.LINE:
			_map.draw_line(start_mouse_pos, mouse_pos, color, 1.0)


func _on_mode_type_pressed(mode: Mode) -> void:
	_mode = mode
	match _mode:
		Mode.MOVE_CAMERA:
			_status.text = "Перемещение камеры"
		Mode.DRAW:
			_status.text = "Рисование произвольной линией"
		Mode.LINE:
			_status.text = "Рисование прямой линией"
		Mode.RECT:
			_status.text = "Рисование прямоугольником"


func _on_place_block_pressed(type: Training.BlockType) -> void:
	if _moving_enemy:
		_cancel_move_enemy()
	
	_block_type = type
	if _mode == Mode.PLACING_ENEMIES:
		_mode = _prev_mode
	(%Modes as CanvasItem).show()
	
	match _block_type:
		Training.BlockType.GRASS:
			_status.text = "Трава"
		Training.BlockType.WALL:
			_status.text = "Стена"
		Training.BlockType.HOLE:
			_status.text = "Дыра"
		Training.BlockType.SPIKES:
			_status.text = "Шипы"


func _on_place_enemy_pressed(type: Training.EnemyType) -> void:
	if _moving_enemy:
		_cancel_move_enemy()
	
	_enemy_type = type
	_prev_mode = _mode
	_mode = Mode.PLACING_ENEMIES
	(%Modes as CanvasItem).hide()
	
	match type:
		Training.EnemyType.DUMMY:
			_status.text = "Манекен"
		Training.EnemyType.ROBOT_P350:
			_status.text = "Робот с P350"
		Training.EnemyType.ROBOT_AK_74:
			_status.text = "Робот с AK-74"
		Training.EnemyType.ROBOT_SWORD:
			_status.text = "Робот с мечом"
	
	_status.text += " / Врагов размещено: %d/%d" % [_enemies_data.size(), MAX_ENEMIES_COUNT]


func _on_health_slider_value_changed(value: float) -> void:
	(%HealthSlider/Value as Label).text = str(int(value))


func _on_damage_slider_value_changed(value: float) -> void:
	(%DamageSlider/Value as Label).text = "x%.1f" % value


func _on_speed_slider_value_changed(value: float) -> void:
	(%SpeedSlider/Value as Label).text = "x%.1f" % value


func _on_delete_enemy_pressed() -> void:
	_enemies_data.remove_at(_editing_enemy_idx)
	_update_enemies()


func _on_save_enemy_pressed() -> void:
	_enemies_data[_editing_enemy_idx].health = int((%HealthSlider/Slider as Range).value)
	_enemies_data[_editing_enemy_idx].damage_multiplier = (%DamageSlider/Slider as Range).value
	_enemies_data[_editing_enemy_idx].speed_multiplier = (%SpeedSlider/Slider as Range).value


func _on_move_enemy_pressed() -> void:
	_moving_enemy = true
	_status.text = "Выберите, куда переместить врага"
	for enemy_tb: TextureButton in _map.get_children():
		enemy_tb.self_modulate = Color(1.0, 1.0, 1.0, 0.5)
		enemy_tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_map.get_child(_editing_enemy_idx) as CanvasItem).self_modulate = Color.WHITE


func _on_close_map_editor_pressed() -> void:
	if _moving_enemy:
		_cancel_move_enemy()
