extends Projectile


func _ready() -> void:
	super()
	($Explosion as Attack).team = team
	($Explosion as Attack).damage_multiplier = damage_multiplier
	($Explosion as Attack).who = who


func _process_hit(where: Vector2, what: Entity) -> void:
	if multiplayer.is_server():
		($Explosion as Node2D).global_position = where
		($Explosion/AreaDetector/CollisionShape2D as CollisionShape2D).disabled = false
		($Explosion/Timer as Timer).start()
	super(where, what)
