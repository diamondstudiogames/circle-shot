extends Gun


func _make_current() -> void:
	super()
	($Visual/Base/Rocket as Node2D).visible = ammo > 0


func get_ammo_text() -> String:
	return "Осталось: %d" % (ammo + ammo_in_stock)
