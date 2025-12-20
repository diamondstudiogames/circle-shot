extends GrenadeProjectile


func _ready() -> void:
	super()
	($Explosion/Sprite2D as CanvasItem).set_instance_shader_parameter(&"outline_color",
			Entity.TEAM_COLORS[team])


func _explode() -> void:
	($Explosion/AnimationPlayer as AnimationPlayer).play(&"explode")
