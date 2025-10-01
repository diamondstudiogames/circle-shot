extends Attack

@export var knockback_power := 640.0
@export var knockback_duration := 0.5

func _deal_damage(entity: Entity, amount: int) -> int:
	entity.add_effect.rpc(Effect.KNOCKBACK, knockback_duration,
			[global_position.direction_to(entity.global_position) * knockback_power])
	return amount
