class_name BigShotHuntingUI
extends ChallengeUI
## Интерфейс испытания "Большая шишка".

func set_boss(boss: Entity) -> void:
	($Main/BossHealthBar as BossHealthBar).set_boss(boss, "Большая шишка")
	($Main/BossHealthBar as CanvasItem).show()
	($Main/BossHealthBar as CanvasItem).modulate = Color.TRANSPARENT
	
	var tween: Tween = create_tween()
	tween.tween_property($Main/BossHealthBar as CanvasItem, ^":modulate", Color.WHITE, 0.5)
