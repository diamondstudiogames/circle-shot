@tool
extends Control


const ITEM_IDX_TO_REWARD: Array[String] = [
	"coins",
	"weapon",
	"skill",
	"skin",
	"equip_box",
	"equip_elite_box",
	"skin_box",
	"skin_elite_box",
]

var _settings_file := ConfigFile.new()
var _settings_file_path: String
var _last_offer_id: int

var _export_dialog: EditorFileDialog
var _import_dialog: EditorFileDialog

var _patch_scene: PackedScene = load("uid://q1jf18fe8nwk")
var _promocode_scene: PackedScene = load("uid://eybqhu8u4udd")
var _offer_scene: PackedScene = load("uid://dkwe2kjrkbt70")
var _reward_scene: PackedScene = load("uid://d0bbhj2qr3xf5")


func _ready() -> void:
	if not is_node_ready():
		($AddPatchDialog as AcceptDialog).register_text_enter($AddPatchDialog/LineEdit as LineEdit)
		($AddPromocodeDialog as AcceptDialog).register_text_enter(
				$AddPromocodeDialog/LineEdit as LineEdit)
	
	_settings_file_path = EditorInterface.get_editor_paths().get_project_settings_dir().path_join(
			"server_data_configuration.cfg")
	_settings_file.load(_settings_file_path)
	_last_offer_id = _settings_file.get_value("editor", "last_offer_id", 999)
	
	var default_config_path: String = \
			OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("data.cfg")
	_export_dialog = EditorFileDialog.new()
	_export_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_export_dialog.disable_overwrite_warning = true
	_export_dialog.add_filter("*.cfg", "Server Data Config")
	_export_dialog.current_path = \
			_settings_file.get_value("editor", "export_path", default_config_path)
	_export_dialog.file_selected.connect(_on_export_dialog_file_selected)
	_export_dialog.name = &"ExportDialog"
	add_child(_export_dialog)
	
	_import_dialog = EditorFileDialog.new()
	_import_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_import_dialog.add_filter("*.cfg", "Server Data Config")
	_import_dialog.current_path = \
			_settings_file.get_value("editor", "import_path", default_config_path)
	_import_dialog.file_selected.connect(_on_import_dialog_file_selected)
	_import_dialog.name = &"ImportDialog"
	add_child(_import_dialog)
	
	(%StableVersionEdit as LineEdit).text = _settings_file.get_value("versions", "stable", "")
	(%BetaVersionEdit as LineEdit).text = _settings_file.get_value("versions", "beta", "")
	
	for patch: Node in %PatchesList.get_children():
		%PatchesList.remove_child(patch)
		patch.queue_free()
	if _settings_file.has_section("patches"):
		for key: String in _settings_file.get_section_keys("patches"):
			_list_patch(key)
	
	for promocode: Node in %PromocodesList.get_children():
		%PromocodesList.remove_child(promocode)
		promocode.queue_free()
	for offer: Node in %OffersList.get_children():
		%OffersList.remove_child(offer)
		offer.queue_free()
	for section: String in _settings_file.get_sections():
		if section.begins_with("promocode_"):
			var promocode: String = section.right(-10)
			_list_promocode(promocode)
		elif section.begins_with("offer_"):
			var offer_id: String = section.right(-6)
			_list_offer(offer_id)


func _exit_tree() -> void:
	_save_settings()


func _list_patch(version: String) -> void:
	var patch_version: int = _settings_file.get_value("patches", version, 1)
	var patch: HBoxContainer = _patch_scene.instantiate()
	(patch.get_node(^"Version") as Label).text = version
	(patch.get_node(^"PatchVersionSpinBox") as Range).value_changed.connect(
			_on_patch_version_value_changed.bind(version))
	(patch.get_node(^"PatchVersionSpinBox") as Range).value = patch_version
	(patch.get_node(^"Delete") as BaseButton).pressed.connect(
			_on_delete_patch_pressed.bind(version))
	patch.name = version.validate_node_name()
	%PatchesList.add_child(patch)


func _list_promocode(promocode_name: String) -> void:
	var promocode: VBoxContainer = _promocode_scene.instantiate()
	(promocode.get_node(^"Promocode") as Label).text = promocode_name
	(promocode.get_node(^"Comment/LineEdit") as LineEdit).text = \
			_settings_file.get_value("promocode_" + promocode_name, "comment")
	(promocode.get_node(^"Comment/LineEdit") as LineEdit).text_changed.connect(
			_on_promocode_comment_text_changed.bind(promocode_name))
	if _settings_file.has_section_key("promocode_" + promocode_name, "only_for_ids"):
		var only_for_ids: Array[String] = _settings_file.get_value("promocode_" + promocode_name,
				"only_for_ids", [] as Array[String])
		(promocode.get_node(^"OnlyForIds/LineEdit") as LineEdit).text = ", ".join(only_for_ids)
	(promocode.get_node(^"OnlyForIds/LineEdit") as LineEdit).text_changed.connect(
			_on_promocode_only_for_ids_text_changed.bind(promocode_name))
	(promocode.get_node(^"Buttons/AddReward") as BaseButton).pressed.connect(
			_on_add_reward_promocode_pressed.bind(promocode_name))
	(promocode.get_node(^"Buttons/Delete") as BaseButton).pressed.connect(
			_on_delete_promocode_pressed.bind(promocode_name))
	promocode.name = promocode_name.validate_node_name()
	%PromocodesList.add_child(promocode)
	_list_rewards(promocode.get_node(^"Rewards"), "promocode_" + promocode_name)


func _list_offer(offer_id: String) -> void:
	var offer: VBoxContainer = _offer_scene.instantiate()
	(offer.get_node(^"Offer") as Label).text += offer_id
	
	(offer.get_node(^"Name/LineEdit") as LineEdit).text = \
			_settings_file.get_value("offer_" + offer_id, "name")
	(offer.get_node(^"Name/LineEdit") as LineEdit).text_changed.connect(
			_on_offer_name_text_changed.bind(offer_id))
	(offer.get_node(^"Cost/SpinBox") as Range).value = \
			_settings_file.get_value("offer_" + offer_id, "cost")
	(offer.get_node(^"Cost/SpinBox") as Range).value_changed.connect(
			_on_offer_cost_value_changed.bind(offer_id))
	(offer.get_node(^"Sale/SpinBox") as Range).value = \
			_settings_file.get_value("offer_" + offer_id, "sale")
	(offer.get_node(^"Sale/SpinBox") as Range).value_changed.connect(
			_on_offer_sale_value_changed.bind(offer_id))
	if _settings_file.has_section_key("offer_" + offer_id, "only_for_ids"):
		var only_for_ids: Array[String] = _settings_file.get_value("offer_" + offer_id,
				"only_for_ids", [] as Array[String])
		(offer.get_node(^"OnlyForIds/LineEdit") as LineEdit).text = ", ".join(only_for_ids)
	(offer.get_node(^"OnlyForIds/LineEdit") as LineEdit).text_changed.connect(
			_on_offer_only_for_ids_text_changed.bind(offer_id))
	
	(offer.get_node(^"Buttons/AddReward") as BaseButton).pressed.connect(
			_on_add_reward_offer_pressed.bind(offer_id))
	(offer.get_node(^"Buttons/Delete") as BaseButton).pressed.connect(
			_on_delete_offer_pressed.bind(offer_id))
	offer.name = offer_id.validate_node_name()
	%OffersList.add_child(offer)
	_list_rewards(offer.get_node(^"Rewards"), "offer_" + offer_id)


func _list_rewards(parent: Node, section: String) -> void:
	for node: Node in parent.get_children():
		node.queue_free()
	var rewards: Array[String] = _settings_file.get_value(section, "rewards")
	for idx: int in rewards.size():
		var slices: PackedStringArray = rewards[idx].split(':')
		var reward: HBoxContainer = _reward_scene.instantiate()
		(reward.get_node(^"Type") as OptionButton).select(ITEM_IDX_TO_REWARD.find(slices[0]))
		(reward.get_node(^"Type") as OptionButton).item_selected.connect(
				_on_reward_type_item_selected.bind(section, idx))
		(reward.get_node(^"Value") as LineEdit).text = slices[1]
		(reward.get_node(^"Value") as LineEdit).text_changed.connect(
				_on_reward_value_text_changed.bind(section, idx))
		(reward.get_node(^"Delete") as BaseButton).pressed.connect(
				_on_reward_delete_pressed.bind(section, idx, parent))
		reward.name = str(idx)
		parent.add_child(reward)


func _save_settings() -> void:
	_settings_file.set_value("editor", "last_offer_id", _last_offer_id)
	_settings_file.set_value("editor", "export_path", _export_dialog.current_path)
	_settings_file.set_value("editor", "import_path", _import_dialog.current_path)
	_settings_file.save(_settings_file_path)


func _on_patch_version_value_changed(value: float, version: String) -> void:
	_settings_file.set_value("patches", version, int(value))


func _on_delete_patch_pressed(version: String) -> void:
	_settings_file.erase_section_key("patches", version)
	%PatchesList.get_node(version.validate_node_name()).queue_free()


func _on_promocode_comment_text_changed(new_text: String, promocode: String) -> void:
	_settings_file.set_value("promocode_" + promocode,
			"comment", new_text.strip_edges().strip_escapes())


func _on_promocode_only_for_ids_text_changed(new_text: String, promocode: String) -> void:
	new_text = new_text.strip_edges().strip_escapes()
	if new_text.is_empty():
		if _settings_file.has_section_key("promocode_" + promocode, "only_for_ids"):
			_settings_file.erase_section_key("promocode_" + promocode, "only_for_ids")
		return
	var ids_packed: PackedStringArray = new_text.split(',', false)
	var ids: Array[String]
	for id: String in ids_packed:
		ids.append(id.strip_edges().strip_escapes())
	_settings_file.set_value("promocode_" + promocode, "only_for_ids", ids)


func _on_add_reward_promocode_pressed(promocode: String) -> void:
	var rewards: Array[String] = _settings_file.get_value("promocode_" + promocode, "rewards")
	rewards.append("coins:")
	_list_rewards(%PromocodesList.get_node(promocode.validate_node_name() + "/Rewards"),
			"promocode_" + promocode)


func _on_delete_promocode_pressed(promocode: String) -> void:
	_settings_file.erase_section("promocode_" + promocode)
	%PromocodesList.get_node(promocode.validate_node_name()).queue_free()


func _on_offer_name_text_changed(new_text: String, offer_id: String) -> void:
	_settings_file.set_value("offer_" + offer_id, "name", new_text.strip_edges().strip_escapes())


func _on_offer_cost_value_changed(value: float, offer_id: String) -> void:
	_settings_file.set_value("offer_" + offer_id, "cost", int(value))


func _on_offer_sale_value_changed(value: float, offer_id: String) -> void:
	_settings_file.set_value("offer_" + offer_id, "sale", int(value))


func _on_offer_only_for_ids_text_changed(new_text: String, offer_id: String) -> void:
	new_text = new_text.strip_edges().strip_escapes()
	if new_text.is_empty():
		if _settings_file.has_section_key("offer_" + offer_id, "only_for_ids"):
			_settings_file.erase_section_key("offer_" + offer_id, "only_for_ids")
		return
	var ids_packed: PackedStringArray = new_text.split(',', false)
	var ids: Array[String]
	for id: String in ids_packed:
		ids.append(id.strip_edges().strip_escapes())
	_settings_file.set_value("offer_" + offer_id, "only_for_ids", ids)


func _on_add_reward_offer_pressed(offer_id: String) -> void:
	var rewards: Array[String] = _settings_file.get_value("offer_" + offer_id, "rewards")
	rewards.append("coins:")
	_list_rewards(%OffersList.get_node(offer_id.validate_node_name() + "/Rewards"),
			"offer_" + offer_id)


func _on_delete_offer_pressed(offer_id: String) -> void:
	_settings_file.erase_section("offer_" + offer_id)
	%OffersList.get_node(offer_id.validate_node_name()).queue_free()


func _on_reward_type_item_selected(item_idx: int, section: String, reward_idx: int) -> void:
	var rewards: Array[String] = _settings_file.get_value(section, "rewards")
	rewards[reward_idx] = ITEM_IDX_TO_REWARD[item_idx] + ':' + rewards[reward_idx].get_slice(':', 1)
	_settings_file.set_value(section, "rewards", rewards)


func _on_reward_value_text_changed(new_text: String, section: String, reward_idx: int) -> void:
	var rewards: Array[String] = _settings_file.get_value(section, "rewards")
	rewards[reward_idx] = rewards[reward_idx].get_slice(':', 0) + ':' \
			+ new_text.strip_edges().strip_escapes()
	_settings_file.set_value(section, "rewards", rewards)


func _on_reward_delete_pressed(section: String, idx: int, parent: Node) -> void:
	var rewards: Array[String] = _settings_file.get_value(section, "rewards")
	rewards.remove_at(idx)
	_settings_file.set_value(section, "rewards", rewards)
	_list_rewards(parent, section)


func _on_export_dialog_file_selected(path: String) -> void:
	var data_file := ConfigFile.new()
	data_file.parse(_settings_file.encode_to_text())
	data_file.erase_section("editor")
	data_file.save(path)


func _on_import_dialog_file_selected(path: String) -> void:
	var data_file := ConfigFile.new()
	var err: Error = data_file.load(path)
	if err != OK:
		return
	_settings_file = data_file
	_last_offer_id = 999
	for section: String in _settings_file.get_sections():
		if section.begins_with("offer_"):
			var offer_id: int = int(section.right(-6))
			if offer_id > _last_offer_id:
				_last_offer_id = offer_id
	_save_settings()
	_ready()


func _on_hidden() -> void:
	_save_settings()


func _on_beta_version_edit_text_changed(new_text: String) -> void:
	_settings_file.set_value("versions", "beta", new_text)


func _on_stable_version_edit_text_changed(new_text: String) -> void:
	_settings_file.set_value("versions", "stable", new_text)


func _on_add_patch_pressed() -> void:
	($AddPatchDialog as Window).popup_centered(Vector2i.ONE)
	($AddPatchDialog/LineEdit as LineEdit).clear()


func _on_add_patch_dialog_confirmed() -> void:
	var version: String = ($AddPatchDialog/LineEdit as LineEdit).text.strip_edges().strip_escapes()
	if %PatchesList.has_node(version.validate_node_name()):
		return
	_settings_file.set_value("patches", version, 1)
	_list_patch(version)


func _on_add_promocode_pressed() -> void:
	($AddPromocodeDialog as Window).popup_centered(Vector2i.ONE)
	($AddPromocodeDialog/LineEdit as LineEdit).clear()


func _on_add_promocode_dialog_confirmed() -> void:
	var promocode: String = \
			($AddPromocodeDialog/LineEdit as LineEdit).text.strip_edges().strip_escapes().to_lower()
	if %PromocodesList.has_node(promocode.validate_node_name()):
		return
	_settings_file.set_value("promocode_" + promocode, "rewards", [] as Array[String])
	_settings_file.set_value("promocode_" + promocode, "comment", "")
	_list_promocode(promocode)


func _on_add_offer_pressed() -> void:
	_last_offer_id += 1
	var offer_id: String = str(_last_offer_id)
	var section: String = "offer_" + offer_id
	_settings_file.set_value(section, "name", "Акция")
	_settings_file.set_value(section, "cost", 0)
	_settings_file.set_value(section, "sale", 0)
	_settings_file.set_value(section, "rewards", [] as Array[String])
	_list_offer(offer_id)


func _on_export_pressed() -> void:
	_export_dialog.popup_file_dialog()


func _on_import_pressed() -> void:
	_import_dialog.popup_file_dialog()
