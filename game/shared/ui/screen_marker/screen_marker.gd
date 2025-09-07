extends Node2D


@export var margin := 120.0
@export var arrow_margin := 16.0
@export var show_when_on_screen := true
var _screen_angle: float

@onready var _visual: CanvasLayer = $Visual
@onready var _marker: Node2D = $Visual/Marker
@onready var _icon: Sprite2D = $Visual/Marker/Icon
@onready var _arrow: Sprite2D = $Visual/Marker/Arrow
@onready var _arrow_icon: Sprite2D = $Visual/Marker/Arrow/Icon


func _ready() -> void:
	_screen_angle = (get_viewport_rect().size - get_viewport_rect().size / 2).angle()


func _process(_delta: float) -> void:
	_visual.visible = is_visible_in_tree()
	if not _visual.visible:
		return
	
	var screen_pos: Vector2 = get_global_transform_with_canvas() * Vector2.ZERO
	var screen_rect: Rect2 = get_viewport_rect()
	
	if screen_rect.grow(-margin).has_point(screen_pos):
		_arrow.hide()
		_icon.visible = show_when_on_screen
		_marker.position = screen_pos
	else:
		_arrow.show()
		_icon.hide()
		
		var angle: float = (screen_pos - screen_rect.size / 2).angle()
		_arrow.rotation = angle
		_arrow_icon.global_rotation = 0.0
		
		if screen_rect.grow(-arrow_margin).has_point(screen_pos):
			_marker.position = screen_pos
		else:
			var half_x: float = get_viewport_rect().size.x / 2 - arrow_margin
			var half_y: float = get_viewport_rect().size.y / 2 - arrow_margin
			_marker.position = get_viewport_rect().size / 2
			if angle <= _screen_angle and angle >= -_screen_angle:
				# Смотрит вправо 
				_marker.position.x += half_x
				_marker.position.y += tan(angle) * half_x
			elif angle < -_screen_angle and angle > -PI + _screen_angle:
				# Смотрит вверх
				_marker.position.y -= half_y
				_marker.position.x += tan(angle + PI / 2) * half_y
			elif angle > -_screen_angle and angle < PI - _screen_angle:
				# Смотрит вниз
				_marker.position.y += half_y
				_marker.position.x -= tan(angle - PI / 2) * half_y
			else:
				# Смотрит влево
				_marker.position.x -= half_x
				_marker.position.y -= tan(angle + PI) * half_x
