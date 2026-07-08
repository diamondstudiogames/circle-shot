extends Node2D


@export var margin := 120.0
@export var arrow_margin := 16.0
@export var show_when_on_screen := true

var _screen_angle: float

@onready var _marker: Node2D = $Marker
@onready var _icon: Sprite2D = $Marker/Icon
@onready var _arrow: Sprite2D = $Marker/Arrow
@onready var _arrow_icon: Sprite2D = $Marker/Arrow/Icon


func _ready() -> void:
	_screen_angle = (get_viewport_rect().size - get_viewport_rect().size / 2).angle()
	_process(0.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	
	var screen_pos: Vector2 = get_global_transform_with_canvas() * Vector2.ZERO
	var screen_rect: Rect2 = get_viewport_rect()
	
	var marker_on_screen_position: Vector2
	if screen_rect.grow(-margin).has_point(screen_pos):
		_arrow.hide()
		_icon.visible = show_when_on_screen
		marker_on_screen_position = screen_pos
	else:
		_arrow.show()
		_icon.hide()
		
		var angle: float = (screen_pos - screen_rect.size / 2).angle()
		_arrow.rotation = angle
		_arrow_icon.global_rotation = 0.0
		
		if screen_rect.grow(-arrow_margin).has_point(screen_pos):
			marker_on_screen_position = screen_pos
		else:
			var half_x: float = get_viewport_rect().size.x / 2 - arrow_margin
			var half_y: float = get_viewport_rect().size.y / 2 - arrow_margin
			marker_on_screen_position = get_viewport_rect().size / 2
			if angle <= _screen_angle and angle >= -_screen_angle:
				# Смотрит вправо 
				marker_on_screen_position.x += half_x
				marker_on_screen_position.y += tan(angle) * half_x
			elif angle < -_screen_angle and angle > -PI + _screen_angle:
				# Смотрит вверх
				marker_on_screen_position.y -= half_y
				marker_on_screen_position.x += tan(angle + PI / 2) * half_y
			elif angle > -_screen_angle and angle < PI - _screen_angle:
				# Смотрит вниз
				marker_on_screen_position.y += half_y
				marker_on_screen_position.x -= tan(angle - PI / 2) * half_y
			else:
				# Смотрит влево
				marker_on_screen_position.x -= half_x
				marker_on_screen_position.y -= tan(angle + PI) * half_x
	
	_marker.scale = Vector2.ONE / get_canvas_transform().get_scale()
	_marker.global_position = get_canvas_transform().affine_inverse() * marker_on_screen_position
