@tool
extends Node2D

# Этот узел генерирует чанки в виде NavigationRegion2D в качестве дочерних.

@export_tool_button("Generate Navigation Regions", "Add") var generate_action: Callable = \
		generate_navigation_regions
@export_tool_button("Bake Navigation Regions", "Bake") var bake_action: Callable = \
		bake_navigation_regions

@export_group("Parameters")
# количество чанков по одной оси, должно быть нечётным
@export var chunks_per_axis: int = 5
# размер карты в блоках
@export var map_size := Vector2i(50, 50)
# размер блока
@export var block_size := 160.0

# настройки navigationpolygon
@export var parsed_geometry_type := NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
@export_flags_2d_physics var parsed_collision_mask: int = 1 + 8 + 16
@export var source_geometry_mode := NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
@export var source_geometry_group_name := &"navigation_polygon_source"
@export_flags_2d_navigation var navigation_layers: int = 1
@export var agent_radius := 77.0


func generate_navigation_regions() -> void:
	for node: Node in get_children():
		remove_child(node)
		node.queue_free()
	
	for x: int in range(-floori(chunks_per_axis / 2.0), ceili(chunks_per_axis / 2.0)):
		for y: int in range(-floori(chunks_per_axis / 2.0), ceili(chunks_per_axis / 2.0)):
			var nav_polygon := NavigationPolygon.new()
			nav_polygon.parsed_geometry_type = parsed_geometry_type
			nav_polygon.parsed_collision_mask = parsed_collision_mask
			nav_polygon.source_geometry_mode = source_geometry_mode
			nav_polygon.source_geometry_group_name = source_geometry_group_name
			nav_polygon.agent_radius = agent_radius
			
			var chunk_size := Vector2(map_size * block_size / chunks_per_axis) \
					+ Vector2.ONE * block_size * 2
			nav_polygon.add_outline(PackedVector2Array([
				-chunk_size / 2,
				chunk_size * Vector2(1.0, -1.0) / 2,
				chunk_size / 2,
				chunk_size * Vector2(-1.0, 1.0) / 2,
			]))
			nav_polygon.baking_rect = Rect2(-chunk_size / 2, chunk_size)
			nav_polygon.border_size = block_size
			
			var nav_region := NavigationRegion2D.new()
			nav_region.name = &"NavigationRegion2D"
			nav_region.navigation_layers = navigation_layers
			nav_region.position = Vector2((chunk_size.x - block_size * 2) * x,
					(chunk_size.y - block_size * 2) * y)
			if chunks_per_axis % 2 == 0:
				nav_region.position += chunk_size / 2 - Vector2(block_size, block_size)
			nav_region.navigation_polygon = nav_polygon
			nav_region.add_to_group(&"navigation_region", true)
			add_child(nav_region, true)
			nav_region.owner = owner
			
			nav_region.bake_navigation_polygon(false)


func bake_navigation_regions() -> void:
	for node: Node in get_children():
		var nav_region := node as NavigationRegion2D
		if not nav_region:
			push_error("Найден узел не типа NavigationRegion2D: %s." % node.name)
			continue
		nav_region.bake_navigation_polygon(false)
