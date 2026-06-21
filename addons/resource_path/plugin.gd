@tool
extends EditorPlugin

var _inspector: ResourcePathInspectorPlugin

func _enter_tree() -> void:
	_inspector = ResourcePathInspectorPlugin.new()
	add_inspector_plugin(_inspector)


func _exit_tree() -> void:
	if _inspector:
		remove_inspector_plugin(_inspector)


class NoCreateEditorResourcePicker extends EditorResourcePicker:
	func _set_create_options(_menu_node: Object) -> void:
		pass


class ResourcePathEditorProperty extends EditorProperty:
	var _picker := NoCreateEditorResourcePicker.new()
	var _current_path: String
	
	func _init(base_type: String) -> void:
		_picker.base_type = base_type
		_picker.resource_changed.connect(_on_resource_changed)
		_picker.resource_selected.connect(_on_resource_selected)
		add_child(_picker)
	
	
	func _update_property() -> void:
		var path: String = get_edited_object()[get_edited_property()]
		if _current_path != path:
			_current_path = path
			_pick(path)
	
	
	func _pick(path: String) -> void:
		if ResourceLoader.exists(path, _picker.base_type):
			_picker.edited_resource = ResourceLoader.load(path)
		else:
			_picker.edited_resource = null
	
	
	func _on_resource_changed(resource: Resource) -> void:
		if not resource:
			return
		
		if ResourceLoader.exists(resource.resource_path, _picker.base_type):
			var id: int = ResourceLoader.get_resource_uid(resource.resource_path)
			if id != ResourceUID.INVALID_ID:
				emit_changed(get_edited_property(), ResourceUID.id_to_text(id))
			else:
				push_warning("UID missing for %s, defaulting to res://." % resource.resource_name)
				emit_changed(get_edited_property(), resource.resource_path)
		else:
			_pick(_current_path)
			push_error('Property "%s" must be assigned a resource with a filename.' % label)
	
	
	func _on_resource_selected(resource: Resource, _inspect: bool) -> void:
		EditorInterface.edit_resource.call_deferred(resource)


class ResourcePathInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(_object: Object) -> bool:
		return true
	
	
	func _parse_property(_object: Object, _type: Variant.Type, name: String,
			hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
		if hint_type == PROPERTY_HINT_FILE and _is_class(hint_string):
			add_property_editor(name, ResourcePathEditorProperty.new(hint_string))
			return true
		return false
	
	
	func _is_class(name_class: String) -> bool:
		if ClassDB.class_exists(name_class):
			return true
		for item: Dictionary in ProjectSettings.get_global_class_list():
			if item["class"] == name_class:
				return true
		return false
