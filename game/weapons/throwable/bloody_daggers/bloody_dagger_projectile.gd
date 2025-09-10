extends Projectile

@export var bleeding_duration := 3.0
@export var bleeding_damage_per_interval: int = 4

func _deal_damage(entity: Entity, amount: int) -> int:
	entity.add_effect.rpc(Effect.BLEEDING, bleeding_duration, [bleeding_damage_per_interval, who])
	return amount
