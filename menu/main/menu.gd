class_name Menu
extends Control

## Меню игры.
##
## Класс главного меню игры.

func _ready() -> void:
	($About as Window).title = "Об игре (версия: %s)" % Globals.version
	if Globals.get_string("player_name").is_empty():
		($NameDialog as Window).popup_centered()
		return
	
	check_updates()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when visible:
			_on_quit_pressed()


## Проверяет наличие обновлений.
func check_updates() -> bool:
	if "--disable-update-check" in OS.get_cmdline_user_args() \
			or not Globals.get_setting_bool("check_updates"):
		print_verbose("Updates check disabled.")
		return false
	if not Globals.remote_data_file:
		print_verbose("Updates check failed: data is not available.")
		return false
	if Globals.remote_data_file.has_section_key("versions", "checked"):
		var betas_checked: bool = Globals.remote_data_file.get_value("versions", "checked")
		if not betas_checked or Globals.get_setting_bool("check_betas"):
			print_verbose("Updates already checked.")
			return false
	
	Globals.remote_data_file.set_value("versions", "checked",
			Globals.get_setting_bool("check_betas"))
	var remote_version: String = Globals.remote_data_file.get_value(
			"versions", "stable", Globals.version)
	var beta := false
	if (
			Globals.get_setting_bool("check_betas")
			and _is_version_newer_than(
			str(Globals.remote_data_file.get_value("versions", "beta", Globals.version)),
			remote_version)
	):
		remote_version = Globals.remote_data_file.get_value("versions", "beta", Globals.version)
		beta = true
	
	if _is_version_newer_than(remote_version, Globals.version):
		var text := "Доступна новая {prefix}версия игры: {version}!".format({
			"prefix": "бета-" if beta else "",
			"version": remote_version,
		})
		($UpdateDialog as AcceptDialog).dialog_text = text
		($UpdateDialog as Window).popup_centered()
		print_verbose("Found new version: %s." % remote_version)
		return true
	
	print_verbose("Updates check done. Version is up to date.")
	return false


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


func _on_update_dialog_visibility_changed() -> void:
	($TutorialDialog as Window).popup_centered.call_deferred()


func _on_play_solo_pressed() -> void:
	Globals.main.open_solo_game()


func _on_play_network_pressed() -> void:
	Globals.main.open_local_game()


func _on_inventory_pressed() -> void:
	Globals.main.open_screen(load("uid://c2x58lim4381g") as PackedScene)


func _on_shop_pressed() -> void:
	Globals.main.open_screen(load("uid://bj723c8k8la6y") as PackedScene)


func _on_settings_pressed() -> void:
	Globals.main.open_screen(load("uid://c2leb2h0qjtmo") as PackedScene)


func _on_name_dialog_name_accepted() -> void:
	var updates_found: bool = check_updates()
	if updates_found:
		($UpdateDialog as Window).visibility_changed.connect(_on_update_dialog_visibility_changed)
	else:
		($TutorialDialog as Window).popup_centered()


func _on_update_dialog_confirmed() -> void:
	OS.shell_open("https://t.me/dsgames31")


func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_tutorial_dialog_confirmed() -> void:
	Globals.main.open_solo_game()
	Globals.main.game.load_solo_world("uid://cbue2vn1da0il")


func _on_quit_pressed() -> void:
	Globals.quit()
