extends Attack

@export var stun_duration := 3.0

func _deal_damage(entity: Entity, amount: int) -> int:
	entity.add_effect.rpc(Effect.STUN, stun_duration)
	return amount
