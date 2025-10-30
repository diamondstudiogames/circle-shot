# meta-name: Атака
# meta-description: Простейший скрипт для расширения логики атаки.
# meta-default: true
extends _BASE_


func _deal_damage(entity: Entity, amount: int) -> int:
_TS_# Пишите логику здесь
_TS_return amount


#func _can_deal_damage(entity: Entity) -> bool:
_TS_#return # Пишите условия здесь


# Удалите, если базовый класс не Projectile
#func _process_hit(where: Vector2, what: Entity) -> void:
_TS_# Пишите особую логику здесь


# Удалите, если базовый класс не Projectile
#func _create_vfx(where: Vector2, wall: bool) -> void:
_TS_# Пишите особую логику здесь