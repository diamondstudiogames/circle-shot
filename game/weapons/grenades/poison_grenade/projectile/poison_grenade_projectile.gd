extends GrenadeProjectile


func _explode() -> void:
	($Explosion/AnimationPlayer as AnimationPlayer).play(&"explode")
