class_name RobotMadnessUI
extends ChallengeUI
## Интерфейс испытания "Рубка роботов".

@onready var _robot_madness: RobotMadness = get_parent()
@onready var _stats_label: Label = $Main/Stats

## Обновляет текущие показатели.
func update_stats() -> void:
	_stats_label.text = "Нанесено урона: %d" % _robot_madness.damaged
	_stats_label.text += "\nОчки: %d" % _robot_madness.points
	_stats_label.text += "\nВолна: %d" % _robot_madness.current_wave


## Начинает волну: скрывает магазин и показывает сообщение о начале волны.
## Также вызывает [method update_stats].
func start_wave() -> void:
	update_stats()
	($Main/WaveInfo/AnimationPlayer as AnimationPlayer).play(&"wave_start")
	($Main/WaveInfo as Label).text = "Волна %d началась!" % _robot_madness.current_wave
	($Main/Shop as CanvasItem).hide()


## Заканчивает волну: показывает сообщение, а затем и магазин.
func end_wave() -> void:
	($Main/WaveInfo/AnimationPlayer as AnimationPlayer).play(&"wave_end")
	($Main/WaveInfo as Label).text = "Волна зачищена!"
	await ($Main/WaveInfo/AnimationPlayer as AnimationMixer).animation_finished
	($Main/Shop as CanvasItem).show()
	_update_upgrades()


func _update_upgrades() -> void:
	var restore_health: Button = %Restore/Health
	var restore_health_cost: int = _robot_madness.get_health_restore_cost()
	restore_health.disabled = restore_health_cost < 0 or _robot_madness.points < restore_health_cost
	restore_health.text = "Восстановить ОЗ (%s)" % \
			("%d очк." % restore_health_cost if restore_health_cost > 0 else "макс.")
	
	var restore_ammo: Button = %Restore/Ammo
	var restore_ammo_cost: int = _robot_madness.get_ammo_restore_cost()
	restore_ammo.disabled = restore_ammo_cost < 0 or _robot_madness.points < restore_ammo_cost
	restore_ammo.text = "Восстановить боеприпасы (%s)" % \
			("%d очк." % restore_ammo_cost if restore_ammo_cost > 0 else "макс.")
	
	var health_label: Label = %Health/Container/Label
	var health_upgrade: Button = %Health/Container/Upgrade
	var health_upgrade_cost: int = _robot_madness.get_health_upgrade_cost()
	health_label.text = "Здоровье: %d" % _robot_madness.get_player_max_health(false)
	health_upgrade.disabled = health_upgrade_cost < 0 or _robot_madness.points < health_upgrade_cost
	health_upgrade.text = "+%d (%s)" % [
		_robot_madness.get_player_max_health(true) * _robot_madness.health_increase_per_upgrade,
		"%d очк." % health_upgrade_cost if health_upgrade_cost > 0 else "макс.",
	]
	
	var defense_label: Label = %Defense/Container/Label
	var defense_upgrade: Button = %Defense/Container/Upgrade
	var defense_upgrade_cost: int = _robot_madness.get_defense_upgrade_cost()
	defense_label.text = "Защита: %d" % \
			(_robot_madness.defense_upgrades * _robot_madness.defense_increase_per_upgrade)
	defense_upgrade.disabled = defense_upgrade_cost < 0 \
			or _robot_madness.points < defense_upgrade_cost
	defense_upgrade.text = "+%d (%s)" % [
		_robot_madness.defense_increase_per_upgrade,
		"%d очк." % defense_upgrade_cost if defense_upgrade_cost > 0 else "макс.",
	]
	
	var damage_label: Label = %Damage/Container/Label
	var damage_upgrade: Button = %Damage/Container/Upgrade
	var damage_upgrade_cost: int = _robot_madness.get_damage_upgrade_cost()
	damage_label.text = "Урон: +%d%%" % roundi(100 * _robot_madness.damage_upgrades
			* _robot_madness.damage_increase_per_upgrade)
	damage_upgrade.disabled = damage_upgrade_cost < 0 or _robot_madness.points < damage_upgrade_cost
	damage_upgrade.text = "+%d%% (%s)" % [
		roundi(_robot_madness.damage_increase_per_upgrade * 100),
		"%d очк." % damage_upgrade_cost if damage_upgrade_cost > 0 else "макс.",
	]
	
	var speed_label: Label = %Speed/Container/Label
	var speed_upgrade: Button = %Speed/Container/Upgrade
	var speed_upgrade_cost: int = _robot_madness.get_speed_upgrade_cost()
	speed_label.text = "Скорость: +%d%%" % roundi(100 * _robot_madness.speed_upgrades
			* _robot_madness.speed_increase_per_upgrade)
	speed_upgrade.disabled = speed_upgrade_cost < 0 or _robot_madness.points < speed_upgrade_cost
	speed_upgrade.text = "+%d%% (%s)" % [
		roundi(_robot_madness.speed_increase_per_upgrade * 100),
		"%d очк." % speed_upgrade_cost if speed_upgrade_cost > 0 else "макс.",
	]


func _on_player_upgraded() -> void:
	_update_upgrades()


func _on_next_wave_pressed() -> void:
	_robot_madness.start_wave()


func _on_restore_health_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_health_restore_cost()
	_robot_madness.restore_health()
	update_stats()
	_update_upgrades()


func _on_restore_ammo_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_ammo_restore_cost()
	_robot_madness.restore_ammo()
	update_stats()
	_update_upgrades()


func _on_upgrade_health_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_health_upgrade_cost()
	_robot_madness.upgrade_health()
	update_stats()


func _on_upgrade_damage_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_damage_upgrade_cost()
	_robot_madness.upgrade_damage()
	update_stats()


func _on_upgrade_defense_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_defense_upgrade_cost()
	_robot_madness.upgrade_defense()
	update_stats()


func _on_upgrade_speed_pressed() -> void:
	_robot_madness.points -= _robot_madness.get_speed_upgrade_cost()
	_robot_madness.upgrade_speed()
	update_stats()
