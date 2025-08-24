extends Melee


func _initialize() -> void:
	($Visual/Base/Light as Node2D).self_modulate = Entity.TEAM_COLORS[player.team]
	($AttackPolygon as Polygon2D).color = Entity.TEAM_COLORS[player.team]
