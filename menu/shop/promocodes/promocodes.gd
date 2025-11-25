extends Window


# ключ - промокод в нижнем регистре, значение - награды через запятую, точка с запятой, комментарий
@export var promocodes: Dictionary[String, String]

var _promocodes_rewards: Dictionary[String, Array]
var _promocodes_comments: Dictionary[String, String]

@onready var _comment: Label = $MarginContainer/VBoxContainer/Comment
@onready var _line_edit: LineEdit = $MarginContainer/VBoxContainer/LineEdit


func _ready() -> void:
	for promocode: String in promocodes:
		var promocode_stripped: String = Utils.strip_string(promocode)
		if promocode_stripped.is_empty():
			print_verbose("Found invalid promocode, ignoring.")
			continue
		var splits: PackedStringArray = promocodes[promocode].split(';')
		if splits.size() != 2:
			print_verbose("Found invalid promocode %s, ignoring." % promocode_stripped)
			continue
		var rewards: Array[String]
		rewards.assign(splits[0].split(','))
		_promocodes_rewards[promocode_stripped] = rewards
		_promocodes_comments[promocode_stripped] = splits[1]
	
	if not Globals.remote_data_file:
		return
	for section: String in Globals.remote_data_file.get_sections():
		if not section.begins_with("promocode_"):
			continue
		var promocode: String = Utils.strip_string(section.right(-10))
		if promocode.is_empty():
			print_verbose("Found invalid online promocode, ignoring.")
			continue
		
		if not (Globals.remote_data_file.has_section_key(section, "comment") \
				and typeof(Globals.remote_data_file.get_value(section, "comment")) == TYPE_STRING):
			print_verbose("Found invalid online promocode %s: no comment, ignoring." % promocode)
			continue
		var comment: String = Globals.remote_data_file.get_value(section, "comment")
		
		if not (Globals.remote_data_file.has_section_key(section, "rewards") \
				and typeof(Globals.remote_data_file.get_value(section, "rewards")) == TYPE_ARRAY):
			print_verbose("Found invalid online promocode %s: no rewards, ignoring." % promocode)
			continue
		var rewards: Array = Globals.remote_data_file.get_value(section, "rewards")
		if rewards.get_typed_builtin() != TYPE_STRING:
			print_verbose("Found invalid online promocode %s: no rewards, ignoring." % promocode)
			continue
		
		if Globals.remote_data_file.has_section_key(section, "only_for_ids") and \
				typeof(Globals.remote_data_file.get_value(section, "only_for_ids")) == TYPE_ARRAY:
			var only_for_ids: Array = Globals.remote_data_file.get_value(section, "only_for_ids")
			if only_for_ids.get_typed_builtin() == TYPE_STRING \
					and not Globals.get_string("save_id") in only_for_ids:
				# нам не предназначен
				continue
		
		_promocodes_rewards[promocode] = rewards
		_promocodes_comments[promocode] = comment


func activate_promocode(promocode: String) -> void:
	promocode = Utils.strip_string(promocode).to_lower()
	if not promocode in _promocodes_comments:
		_comment.text = "Введён неверный промокод"
		print_verbose("Promocode %s not found." % promocode)
		return
	var used_promocodes: Array[String] = Globals.get_variant("used_promocodes", [] as Array[String])
	if promocode in used_promocodes:
		_comment.text = "Этот промокод уже использован"
		print_verbose("Promocode %s was already used." % promocode)
		return
	
	used_promocodes.append(promocode)
	Globals.set_variant("used_promocodes", used_promocodes)
	_comment.text = _promocodes_comments[promocode]
	print_verbose("Used promocode %s." % promocode)
	_line_edit.clear()
	
	hide()
	await Globals.main.receive_loot(_promocodes_rewards[promocode])
	show()


func _on_activate_pressed() -> void:
	activate_promocode(_line_edit.text)
