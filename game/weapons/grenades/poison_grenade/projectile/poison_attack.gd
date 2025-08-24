extends Attack

@export var poison_damage: int = 10
@export var poison_damage_interval := 1.0
@export var poison_duration := 2.0

func _deal_damage(entity: Entity, amount: int) -> int:
	entity.add_effect.rpc(Effect.POISON, poison_duration,
			[poison_damage, who, poison_damage_interval], false)
	return amount
