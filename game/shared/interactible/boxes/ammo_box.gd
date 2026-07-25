extends Node2D

@export_range(0.0, 1.0) var ammo_restore_ratio := 0.2

func _ready() -> void:
	reset_physics_interpolation()


func _on_interactible_interacted(who: Player) -> void:
	if not multiplayer.is_server():
		return
	who.add_ammo_to_weapon.rpc(Weapon.Type.LIGHT, ammo_restore_ratio)
	who.add_ammo_to_weapon.rpc(Weapon.Type.HEAVY, ammo_restore_ratio)
	who.add_ammo_to_weapon.rpc(Weapon.Type.SUPPORT, ammo_restore_ratio)
	who.add_ammo_to_weapon.rpc(Weapon.Type.MELEE, ammo_restore_ratio)
	queue_free()


func _on_despawn_timer_timeout() -> void:
	($AnimationPlayer as AnimationPlayer).play(&"despawn")
	if multiplayer.is_server():
		await ($AnimationPlayer as AnimationMixer).animation_finished
		queue_free()
