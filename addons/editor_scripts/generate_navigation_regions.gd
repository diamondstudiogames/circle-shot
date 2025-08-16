@tool
extends EditorScript

# Этот скрипт генерирует чанки в виде NavigationRegion2D как дочерние к выбранному узлу.

# количество чанков по одной оси, должно быть нечётным TODO добавить и чётные
const CHUNKS_PER_AXIS: int = 4
# размер карты в блоках
const MAP_SIZE := Vector2i(40, 40)
# рамзер блока
const BLOCK_SIZE := 160.0

# настройки navigationpolygon
const PARSED_GEOMETRY_TYPE := NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
const PARSED_COLLISION_MASK: int = 17
const SOURCE_GEOMETRY_MODE := NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
const SOURCE_GEOMETRY_GROUP_NAME := &"navigation_polygon_source"
const AGENT_RADIUS := 77.0


func _run() -> void:
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	if selected_nodes.size() != 1:
		push_error("Должен быть выбран только один узел.")
		return
	var parent: Node = selected_nodes[0]
	for node: Node in parent.get_children():
		parent.remove_child(node)
		node.queue_free()
	
	for x: int in range(-floori(CHUNKS_PER_AXIS / 2.0), ceili(CHUNKS_PER_AXIS / 2.0)):
		for y: int in range(-floori(CHUNKS_PER_AXIS / 2.0), ceili(CHUNKS_PER_AXIS / 2.0)):
			var nav_polygon := NavigationPolygon.new()
			nav_polygon.parsed_geometry_type = PARSED_GEOMETRY_TYPE
			nav_polygon.parsed_collision_mask = PARSED_COLLISION_MASK
			nav_polygon.source_geometry_mode = SOURCE_GEOMETRY_MODE
			nav_polygon.source_geometry_group_name = SOURCE_GEOMETRY_GROUP_NAME
			nav_polygon.agent_radius = AGENT_RADIUS
			
			var chunk_size := Vector2(MAP_SIZE * BLOCK_SIZE / CHUNKS_PER_AXIS) \
					+ Vector2.ONE * BLOCK_SIZE * 2
			nav_polygon.add_outline(PackedVector2Array([
				-chunk_size / 2,
				chunk_size * Vector2(1.0, -1.0) / 2,
				chunk_size / 2,
				chunk_size * Vector2(-1.0, 1.0) / 2,
			]))
			nav_polygon.baking_rect = Rect2(-chunk_size / 2, chunk_size)
			nav_polygon.border_size = BLOCK_SIZE
			
			var nav_region := NavigationRegion2D.new()
			nav_region.name = &"NavigationRegion2D"
			nav_region.position = Vector2((chunk_size.x - BLOCK_SIZE * 2) * x,
					(chunk_size.y - BLOCK_SIZE * 2) * y)
			if CHUNKS_PER_AXIS % 2 == 0:
				nav_region.position += chunk_size / 2 - Vector2(BLOCK_SIZE, BLOCK_SIZE)
			nav_region.navigation_polygon = nav_polygon
			parent.add_child(nav_region, true)
			nav_region.owner = get_scene()
			
			nav_region.bake_navigation_polygon(false)
