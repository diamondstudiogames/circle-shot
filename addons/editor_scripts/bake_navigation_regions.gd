@tool
extends EditorScript

# Этот скрипт запекает все дочерние к выбранному узлу NavigationRegion2D.

func _run() -> void:
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	if selected_nodes.size() != 1:
		push_error("Должен быть выбран только один узел.")
		return
	var parent: Node = selected_nodes[0]
	for node: Node in parent.get_children():
		var nav_region := node as NavigationRegion2D
		if not nav_region:
			push_error("Найден узел не типа NavigationRegion2D: %s." % node.name)
			continue
		nav_region.bake_navigation_polygon(false)
