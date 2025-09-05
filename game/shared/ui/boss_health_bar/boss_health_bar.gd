class_name BossHealthBar
extends TextureRect

## Полоска здоровья для босса.

var _health_bar_tween: Tween

@onready var _name: Label = $Name
@onready var _health_text: Label = $Health
@onready var _health_bar: TextureProgressBar = $HealthBar


func set_boss(boss: Entity, boss_name: String) -> void:
	boss.health_changed.connect(_on_boss_health_changed.bind(boss))
	boss.died.connect(_on_boss_died.bind(boss))
	_name.text = boss_name
	_on_boss_health_changed(boss.current_health, boss.max_health, boss)


func _change_health_bar_glow(glow: float) -> void:
	_health_bar.set_instance_shader_parameter(&"power", glow)


func _on_boss_health_changed(old_value: int, new_value: int, boss: Entity) -> void:
	_health_bar.max_value = boss.max_health
	_health_bar.value = new_value
	_health_text.text = "%d/%d" % [_health_bar.value, _health_bar.max_value]
	
	if new_value < old_value:
		var sprite := Sprite2D.new()
		sprite.texture = _health_bar.texture_progress
		sprite.position.x = new_value / float(boss.max_health) * sprite.texture.get_width() / 2
		sprite.scale *= 0.5
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect.position.x = \
				new_value / float(boss.max_health) * sprite.texture.get_width()
		sprite.region_rect.end.x = old_value / float(boss.max_health) * sprite.texture.get_width()
		sprite.region_rect.end.y = sprite.texture.get_height()
		sprite.material = _health_bar.material
		sprite.set_instance_shader_parameter(&"power", 1.0)
		add_child(sprite)
		
		var tween: Tween = sprite.create_tween()
		tween.tween_property(sprite, ^":position", Vector2(sprite.position.x, 56.0), 1.0)
		tween.parallel().tween_property(sprite, ^":self_modulate", Color.TRANSPARENT,
				1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(sprite.queue_free)
	elif new_value > old_value:
		if is_instance_valid(_health_bar_tween):
			_health_bar_tween.kill()
		_health_bar_tween = create_tween()
		_health_bar_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		_health_bar_tween.tween_method(_change_health_bar_glow, 1.0, 0.0, 1.0)
	else:
		if is_instance_valid(_health_bar_tween):
			_health_bar_tween.kill()
		_change_health_bar_glow(0.0)


func _on_boss_died(boss: Entity) -> void:
	_on_boss_health_changed(int(_health_bar.value), 0, boss)
