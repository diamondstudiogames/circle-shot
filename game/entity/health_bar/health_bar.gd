extends TextureRect


var _health_immediate_bar_tween: Tween

@onready var _entity: Entity = owner
@onready var _health_bar: TextureProgressBar = $Health
@onready var _health_amount: Label = $Amount
@onready var _health_immediate_bar: TextureProgressBar = $Health/HealthImmediate


func _ready() -> void:
	_health_bar.modulate = Entity.TEAM_COLORS[_entity.team]
	_health_amount.add_theme_color_override(&"font_color", Entity.TEAM_COLORS[_entity.team])
	_on_entity_health_changed(_entity.current_health, _entity.max_health)


func _on_entity_health_changed(old_value: int, new_value: int) -> void:
	_health_bar.max_value = _entity.max_health
	_health_bar.value = new_value
	_health_immediate_bar.max_value = _entity.max_health
	_health_amount.text = "%d/%d" % [new_value, _entity.max_health]
	if not visible:
		return
	
	if new_value < old_value:
		if is_instance_valid(_health_immediate_bar_tween):
			_health_immediate_bar_tween.kill()
		_health_immediate_bar_tween = create_tween()
		if _health_immediate_bar.value < old_value:
			_health_immediate_bar.value = old_value
		_health_immediate_bar_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_health_immediate_bar_tween.tween_interval(0.3)
		_health_immediate_bar_tween.tween_property(_health_immediate_bar, ^":value", new_value, 0.5)
	elif new_value == old_value:
		if is_instance_valid(_health_immediate_bar_tween):
			_health_immediate_bar_tween.kill()
		_health_immediate_bar.value = old_value
