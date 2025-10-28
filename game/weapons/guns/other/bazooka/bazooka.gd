extends Gun


func _make_current() -> void:
	super()
	($Visual/Base/Rocket as Node2D).visible = ammo > 0


func _unmake_current() -> void:
	super()
	if ammo + ammo_in_stock <= 0 and player.current_weapon_type == Weapon.Type.ADDITIONAL:
		player.set_weapon.call_deferred(Weapon.Type.ADDITIONAL, null)


func get_ammo_text() -> String:
	return "Осталось: %d" % (ammo + ammo_in_stock)
