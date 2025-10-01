class_name DemonFightUI
extends ChallengeUI
## Интерфейс испытания "Битва с демоном".

func set_boss(boss: Entity) -> void:
	($Main/BossHealthBar as BossHealthBar).set_boss(boss, "Козёл")
	($Main/BossHealthBar as CanvasItem).show()
	($Main/BossHealthBar as CanvasItem).modulate = Color.TRANSPARENT
	
	var tween: Tween = create_tween()
	tween.tween_property($Main/BossHealthBar as CanvasItem, ^":modulate", Color.WHITE, 0.5)
