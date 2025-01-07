class_name Menu
extends Control
## Меню игры.
##
## Класс главного меню игры.

var _name_accepted := false

func _ready() -> void:
	($About as Window).title = "Об игре (версия: %s)" % Globals.version
	if Globals.get_string("player_name").is_empty():
		($NameDialog as Window).popup_centered()
		return
	
	check_updates()


## Проверяет наличие обновлений.
func check_updates() -> void:
	if not Globals.data_file:
		print_verbose("Updates check failed: data is not available.")
		return
	if Globals.data_file.has_section_key("versions", "checked"):
		var betas_checked: bool = Globals.data_file.get_value("versions", "checked")
		if int(betas_checked) >= int(Globals.get_setting_bool("check_betas")):
			print_verbose("Updates check interrupted: already checked.")
			return
	if "--disable-update-check" in OS.get_cmdline_args() \
			or not Globals.get_setting_bool("check_updates"):
		print_verbose("Updates check disabled.")
		return
	
	Globals.data_file.set_value("versions", "checked", Globals.get_setting_bool("check_betas"))
	var remote_version: String = Globals.data_file.get_value("versions", "beta", Globals.version) \
			if Globals.get_setting_bool("check_betas") \
			else Globals.data_file.get_value("versions", "stable", Globals.version)
	if _is_version_newer_than(remote_version, Globals.version):
		var beta: bool = remote_version \
				== Globals.data_file.get_value("versions", "beta", Globals.version)
		var text := "Доступна новая {prefix}версия игры: {version}!".format({
			"prefix": "бета-" if beta else "",
			"version": remote_version,
		})
		($UpdateDialog as AcceptDialog).dialog_text = text
		($UpdateDialog as Window).popup_centered()
		print_verbose("Found new version: %s." % remote_version)
	else:
		print_verbose("Updates check done. Version is up to date.")


func _is_version_newer_than(first: String, second: String) -> bool:
	if '-' in first:
		first = first.left(first.find('-'))
	if '-' in second:
		second = second.left(second.find('-'))
	var first_splits: PackedStringArray = first.split('.')
	var second_splits: PackedStringArray = second.split('.')
	for i: int in mini(first_splits.size(), second_splits.size()):
		if i == 3: # Особая обработка для бета версий
			if int(first_splits[i][0]) != int(second_splits[i][0]):
				return int(first_splits[i][0]) > int(second_splits[i][0])
			var first_split: String = first_splits[i].erase(0)
			var second_split: String = second_splits[i].erase(0)
			return int(first_split) > int(second_split)
		if int(first_splits[i]) != int(second_splits[i]):
			return int(first_splits[i]) > int(second_splits[i])
	return first_splits.size() < second_splits.size()


func _on_name_dialog_visibility_changed() -> void:
	if not ($NameDialog as Window).visible and not _name_accepted:
		($NameDialog as Window).popup_centered.call_deferred()


func _on_play_network_pressed() -> void:
	Globals.main.open_local_game()


func _on_settings_pressed() -> void:
	Globals.main.open_screen(load("uid://c2leb2h0qjtmo") as PackedScene)


func _on_name_dialog_name_accepted() -> void:
	_name_accepted = true
	check_updates.call_deferred() # избегаем exclusive child moment


func _on_update_dialog_confirmed() -> void:
	OS.shell_open("https://t.me/dsgames31")


func _on_quit_pressed() -> void:
	get_tree().quit()
