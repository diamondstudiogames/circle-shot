extends TextureRect

@export var textures: Array[Texture2D]

func _on_visibility_changed() -> void:
	texture = textures.pick_random()
