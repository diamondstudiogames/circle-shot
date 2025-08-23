class_name Loot
extends Control

## Класс, отвечающий за показ наград и открытие ящиков и кейсов.
##
## Изменяя значения шансов, не забудьте их изменить и в сцене магазина.

## Внутренний сигнал, издаётся при нажатии по экрану (или другой клавиши для продолжения).
signal proceeded

@export_group("Box Chances", "box_chance_")
## Шанс на редкий предмет из ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var box_chance_rare := 67.0
## Шанс на эпический предмет из ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var box_chance_epic := 26.0
## Шанс на легендарный предмет из ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var box_chance_legendary := 7.0
## Шанс на секретный предмет из ящика, в процентах. Не идёт в сумму 100% с тремя предыдущими.
@export_range(0.0, 100.0, 0.01) var box_chance_secret := 3.0
## На сколько повышаются шансы дургих редкостей, когда игрок не выбивает предмет из ящика.
@export_range(0.0, 100.0, 0.01) var box_chance_increase := 10.0

@export_group("Elite Box Chances", "elite_box_chance_")
## Шанс на редкий предмет из элитного ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var elite_box_chance_rare := 40.0
## Шанс на эпический предмет из элитного ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var elite_box_chance_epic := 45.0
## Шанс на легендарный предмет из элитного ящика, в процентах.
@export_range(0.0, 100.0, 0.01) var elite_box_chance_legendary := 15.0
## Шанс на секретный предмет из элитного ящика, в процентах.
## Не идёт в сумму 100% с тремя предыдущими.
@export_range(0.0, 100.0, 0.01) var elite_box_chance_secret := 8.0
## На сколько повышаются шансы других редкостей, когда игрок не выбивает предмет из элитного ящика.
@export_range(0.0, 100.0, 0.01) var elite_box_chance_increase := 17.0

@export_group("Coins Compensation")
@export_subgroup("Skins", "coins_per_skin_")
## Компенсация в монетах за редкий скин.
@export var coins_per_skin_rare: int = 50
## Компенсация в монетах за эпический скин.
@export var coins_per_skin_epic: int = 200
## Компенсация в монетах за легендарный скин.
@export var coins_per_skin_legendary: int = 750
@export_subgroup("Equip", "coins_per_equip_")
## Компенсация в монетах за редкую экипировку.
@export var coins_per_equip_rare: int = 125
## Компенсация в монетах за эпическую экипировку.
@export var coins_per_equip_epic: int = 500
## Компенсация в монетах за легендарную экипировку.
@export var coins_per_equip_legendary: int = 1875

@export_group("Scroll Animation", "scroll_anim_")
## Минимальный индекс предмета из всех прокручиваемых, который может выпасть игроку.
@export var scroll_anim_min_reward_idx: int = 50
## Максимальный индекс предмета из всех прокручиваемых, который может выпасть игроку.
@export var scroll_anim_max_reward_idx: int = 80
## Количество предметов, которое создаётся для анимации прокрутки.
@export var scroll_anim_items_count: int = 100
## Изначальный множитель скорости прокрутки.
@export var scroll_anim_start_speed := 3168.0
## Ширина предмета в анимации прокрутки.
@export var scroll_anim_item_width := 192.0
## Зазор между предметами в анимации прокрутки.
@export var scroll_anim_gap_between_items := 6.0
## Индекс предмета, на котором изначально находится указатель.
@export var scroll_anim_start_idx: int = 4
## Позиция по оси X контейнера с прокручиваемыми предметами в начале.
@export var scroll_anim_start_x_position := 0.0

var _scroll_tween: Tween
var _scroll_offset: float

var _scroll_current_idx: int = 0
var _scroll_textures: Array[Texture2D]
var _scroll_names: Array[String]
var _scroll_rarities: Array[ItemsDB.Rarity]

var _chances_up_texture: Texture2D = load("uid://bwb6b5osacj7d")
var _coins_textures: Array[Texture2D] = [
	load("uid://com744p7pvw4r"),
	load("uid://to0f0otv0eap"),
	load("uid://cbs68u50ugaxe"),
	load("uid://bouq57xti1igf"),
]
var _boxes_textures: Dictionary[String, Texture2D] = {
	"equip_box": load("uid://df15gv2o3a8aw"),
	"equip_box_open": load("uid://ccbjbqofep5wi"),
	"equip_elite_box": load("uid://dfl5s6nvc5xe1"),
	"equip_elite_box_open": load("uid://dbwb0ulffmga0"),
	"skin_box": load("uid://jh8hm5do8ejn"),
	"skin_box_open": load("uid://bb4gghr2j6tbm"),
	"skin_elite_box": load("uid://ccm58rdshl6fo"),
	"skin_elite_box_open": load("uid://csl8clc04rvsv"),
}
var _coins_compensation_textures: Array[Texture2D] = [
	load("uid://chh1k6qqdvm64"),
	load("uid://bxpqam74ij4tw"),
	load("uid://ddu7wg5cv2gn5"),
]
var _cached_textures: Array[Texture2D]

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _scroll_container: HBoxContainer = $Box/Scroll/Container
@onready var _wait_timer: Timer = $WaitTimer


func _ready() -> void:
	($Proceed as Control).grab_focus.call_deferred()
	set_process(false)


func _process(_delta: float) -> void:
	var item_total_width: float = scroll_anim_item_width + scroll_anim_gap_between_items
	_scroll_container.position.x = scroll_anim_start_x_position \
			- fposmod(_scroll_offset, item_total_width)
	var current_idx: int = floori(_scroll_offset / item_total_width)
	if current_idx != _scroll_current_idx:
		_scroll_current_idx = current_idx
		_update_scroll_textures()


## Показывает добычу из [param loot]. Этот метод - корутина, его можно подождать с помощью
## [code]await[/code].
func show_loot(loot: Array[String]) -> void:
	for item: String in loot:
		_hide_screens()
		
		var splits: PackedStringArray = item.split(':')
		var type: String = splits[0]
		var value: String = splits[1]
		match type:
			"coins":
				_show_screen(^"Coins")
				var amount: int = int(value)
				_anim.play(&"coins")
				_anim.seek(0.0, true)
				($Coins/Visual/Count as Label).text = "x %s" % value
				if amount < 60:
					($Coins/Visual/Texture as TextureRect).texture = _coins_textures[0]
				elif amount < 150:
					($Coins/Visual/Texture as TextureRect).texture = _coins_textures[1]
				elif amount < 300:
					($Coins/Visual/Texture as TextureRect).texture = _coins_textures[2]
				else:
					($Coins/Visual/Texture as TextureRect).texture = _coins_textures[3]
				await proceeded
			
			"weapon", "skill", "skin":
				_show_screen(^"Equip")
				_anim.play(&"equip")
				
				var item_rarity: ItemsDB.Rarity
				var item_name: String
				var item_description: String
				var item_type: String
				var image: Texture2D
				
				if type == "weapon":
					var data: WeaponData = Globals.items_db.weapons_by_id[value]
					item_type = "Оружие"
					item_name = data.name
					item_description = data.damage_text.format(data.stats) \
							+ '\n' + data.ammo_text.format(data.stats)
					item_rarity = data.rarity
					image = load(data.image_path)
				elif type == "skill":
					var data: SkillData = Globals.items_db.skills_by_id[value]
					item_type = "Навык"
					item_name = data.name
					item_description = data.brief_description.format(data.stats) \
							+ '\n' + data.usage_text.format(data.stats)
					item_rarity = data.rarity
					image = load(data.image_path)
				elif type == "skin":
					var data: SkinData = Globals.items_db.skins_by_id[value]
					item_type = "Скин"
					item_name = data.name
					item_description = data.brief_description
					item_rarity = data.rarity
					image = load(data.image_path)
				
				($Equip/Info/Name as Label).text = item_name
				($Equip/Info/Description as Label).text = item_description
				($Equip/Info/Type as Label).text = item_type
				($Equip/Info/Rarity as Label).text = ItemsDB.RARITY_NAMES[item_rarity]
				($Equip/Info/Rarity as Label).add_theme_color_override(&"font_color",
						ItemsDB.RARITY_COLORS[item_rarity])
				($Equip/Item as TextureRect).texture = image
				($Background as ColorRect).color = ItemsDB.RARITY_COLORS[item_rarity]
				
				($Equip/ScreenGlitch as CanvasItem).visible = item_rarity == ItemsDB.Rarity.SECRET
				_anim.get_animation(&"equip").track_set_enabled(0,
						item_rarity != ItemsDB.Rarity.SECRET)
				_anim.get_animation(&"equip").track_set_enabled(1,
						item_rarity == ItemsDB.Rarity.SECRET)
				_anim.seek(0.0, true) # сначала задаём значение трекам, потом только воспроизводим
				
				match item_rarity:
					ItemsDB.Rarity.COMMON, ItemsDB.Rarity.RARE:
						($Equip/Glow/Glow as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.5)
						($Equip/Glow/EquipLight as CanvasItem).hide()
						($Equip/Glow/Stars as CanvasItem).hide()
					ItemsDB.Rarity.EPIC:
						($Equip/Glow/Glow as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.4)
						($Equip/Glow/Stars as CanvasItem).show()
						($Equip/Glow/EquipLight as CanvasItem).hide()
					ItemsDB.Rarity.LEGENDARY:
						($Equip/Glow/Glow as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.6)
						($Equip/Glow/EquipLight as CanvasItem).show()
						($Equip/Glow/EquipLight as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.4)
						($Equip/Glow/Stars as CanvasItem).show()
					ItemsDB.Rarity.SECRET, ItemsDB.Rarity.SPECIAL:
						($Equip/Glow/Glow as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.3)
						($Equip/Glow/EquipLight as CanvasItem).show()
						($Equip/Glow/EquipLight as CanvasItem).self_modulate = \
								ItemsDB.RARITY_COLORS[item_rarity].lightened(0.1)
						($Equip/Glow/Stars as CanvasItem).show()
				
				_wait_timer.start(1.3)
				await _wait_timer.timeout
				await proceeded
			
			"equip_box", "skin_box", "equip_elite_box", "skin_elite_box":
				for i: int in int(value):
					_hide_screens()
					_show_screen(^"Box")
					_anim.play(&"box")
					_anim.seek(0.0, true)
					get_viewport().gui_snap_controls_to_pixels = false
					
					($Box/Anchor/Box/Normal as TextureRect).texture = _boxes_textures[type]
					($Box/Anchor/Box/Open as TextureRect).texture = _boxes_textures[type + "_open"]
					if "elite" in type:
						($Box/Anchor/Box/Stars as CanvasItem).show()
						($Box/Anchor/Box/Stars as CPUParticles2D).restart()
					else:
						($Box/Anchor/Box/Stars as CanvasItem).hide()
						($Box/Anchor/Box/Stars as CPUParticles2D).emitting = false
					
					await proceeded
					get_viewport().gui_snap_controls_to_pixels = true
					_anim.play(&"box_open")
					await _anim.animation_finished
					
					var reward: String = _open_box(type)
					_anim.play(&"box_open_end")
					set_process(true)
					await _scroll_tween.finished
					set_process(false)
					get_viewport().gui_snap_controls_to_pixels = true
					_wait_timer.start(0.7)
					await _wait_timer.timeout
					
					if reward.is_empty():
						($Box/Continue as CanvasItem).show()
						await proceeded
					else:
						if '?' in reward:
							reward = reward.replace('?', '')
							_anim.play(&"box_secret_item")
							await _anim.animation_finished
						await Globals.main.receive_loot([reward])
						($Proceed as Control).grab_focus()


func _open_box(type: String) -> String:
	var chances: Array[float]
	var secret_chance: float
	if "elite" in type:
		chances = Utils.calculate_box_chances(
				elite_box_chance_rare, elite_box_chance_epic, elite_box_chance_legendary,
				elite_box_chance_increase, Globals.get_int(type + "_rare_got"),
				Globals.get_int(type + "_epic_got"), Globals.get_int(type + "_legendary_got")
		)
		secret_chance = elite_box_chance_secret
	else:
		chances = Utils.calculate_box_chances(
				box_chance_rare, box_chance_epic, box_chance_legendary, box_chance_increase,
				Globals.get_int(type + "_rare_got"), Globals.get_int(type + "_epic_got"),
				Globals.get_int(type + "_legendary_got")
		)
		secret_chance = box_chance_secret
	
	print_verbose("Opening %s, chances: %s, secret chance: %f." % [
		type,
		str(chances),
		secret_chance,
	])
	var reward := ""
	var reward_rarity := _get_idx_weighted(chances) + 1 as ItemsDB.Rarity
	var reward_secret: bool = randf_range(0.0, 100.0) < secret_chance
	var reward_idx: int = randi_range(scroll_anim_min_reward_idx, scroll_anim_max_reward_idx)
	var increase_chances := false
	
	_scroll_rarities.clear()
	_scroll_textures.clear()
	_scroll_names.clear()
	_scroll_rarities.resize(scroll_anim_items_count)
	_scroll_textures.resize(scroll_anim_items_count)
	_scroll_names.resize(scroll_anim_items_count)
	var locked_rare: Array[Resource]
	var locked_epic: Array[Resource]
	var locked_legendary: Array[Resource]
	var locked_secret: Array[Resource]
	if "skin" in type:
		for skin: SkinData in Globals.items_db.skins:
			if skin in Globals.items_db.other_skins \
					or Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN):
				continue
			match skin.rarity:
				ItemsDB.Rarity.RARE:
					locked_rare.append(skin)
				ItemsDB.Rarity.EPIC:
					locked_epic.append(skin)
				ItemsDB.Rarity.LEGENDARY:
					locked_legendary.append(skin)
				ItemsDB.Rarity.SECRET:
					locked_secret.append(skin)
	else:
		for skill: SkillData in Globals.items_db.skills:
			if skill in Globals.items_db.other_skills \
					or Globals.items_db.has_equip_item(skill.id, ItemsDB.Item.SKILL):
				continue
			match skill.rarity:
				ItemsDB.Rarity.RARE:
					locked_rare.append(skill)
				ItemsDB.Rarity.EPIC:
					locked_epic.append(skill)
				ItemsDB.Rarity.LEGENDARY:
					locked_legendary.append(skill)
				ItemsDB.Rarity.SECRET:
					locked_secret.append(skill)
		for weapon: WeaponData in Globals.items_db.weapons:
			if weapon in Globals.items_db.other_weapons \
					or Globals.items_db.has_equip_item(weapon.id, ItemsDB.Item.WEAPON):
				continue
			match weapon.rarity:
				ItemsDB.Rarity.RARE:
					locked_rare.append(weapon)
				ItemsDB.Rarity.EPIC:
					locked_epic.append(weapon)
				ItemsDB.Rarity.LEGENDARY:
					locked_legendary.append(weapon)
				ItemsDB.Rarity.SECRET:
					locked_secret.append(weapon)
	
	var reward_in_coins: bool = locked_rare.is_empty() and locked_epic.is_empty() \
			and locked_legendary.is_empty()
	var reward_data: Resource
	match reward_rarity:
		ItemsDB.Rarity.RARE:
			if locked_rare.is_empty():
				increase_chances = true
			else:
				reward_data = locked_rare.pick_random()
		ItemsDB.Rarity.EPIC:
			if locked_epic.is_empty():
				increase_chances = true
			else:
				reward_data = locked_epic.pick_random()
		ItemsDB.Rarity.LEGENDARY:
			if locked_legendary.is_empty():
				increase_chances = true
			else:
				reward_data = locked_legendary.pick_random()
	
	if reward_secret:
		if not locked_secret.is_empty():
			reward_data = locked_secret.pick_random()
		else:
			reward_secret = false
	if reward_data:
		if reward_data is SkinData:
			reward = "skin:" + (reward_data as SkinData).id
		if reward_data is SkillData:
			reward = "skill:" + (reward_data as SkillData).id
		if reward_data is WeaponData:
			reward = "weapon:" + (reward_data as WeaponData).id
		if reward_secret:
			reward = '?' + reward
	if reward_in_coins and not reward_secret:
		increase_chances = false
		reward = "coins:" + str(_get_coins_compensation(reward_rarity, type)) 
	
	for idx: int in scroll_anim_items_count:
		var item_rarity := _get_idx_weighted(chances) + 1 as ItemsDB.Rarity
		_scroll_rarities[idx] = item_rarity
		if reward_in_coins:
			_fill_scroll_idx_with_coins(idx, item_rarity, type)
		else:
			var item_data: Resource
			match item_rarity:
				ItemsDB.Rarity.RARE:
					if not locked_rare.is_empty():
						item_data = locked_rare.pick_random()
				ItemsDB.Rarity.EPIC:
					if not locked_epic.is_empty():
						item_data = locked_epic.pick_random()
				ItemsDB.Rarity.LEGENDARY:
					if not locked_legendary.is_empty():
						item_data = locked_legendary.pick_random()
			if item_data:
				_fill_scroll_idx_with_item(idx, item_data)
			else:
				_scroll_textures[idx] = _chances_up_texture
				_scroll_names[idx] = "Повышение шансов"
	
	if not reward_secret:
		_scroll_rarities[reward_idx] = reward_rarity
		if reward_data:
			_fill_scroll_idx_with_item(reward_idx, reward_data)
		elif reward_in_coins:
			_fill_scroll_idx_with_coins(reward_idx, reward_rarity, type)
		else:
			_scroll_textures[reward_idx] = _chances_up_texture
			_scroll_names[reward_idx] = "Повышение шансов"
	
	if increase_chances:
		match reward_rarity:
			ItemsDB.Rarity.RARE:
				Globals.set_int(type + "_rare_got", Globals.get_int(type + "_rare_got") + 1)
			ItemsDB.Rarity.EPIC:
				Globals.set_int(type + "_epic_got", Globals.get_int(type + "_epic_got") + 1)
			ItemsDB.Rarity.LEGENDARY:
				Globals.set_int(type + "_legendary_got",
						Globals.get_int(type + "_legendary_got") + 1)
	
	_scroll_current_idx = 0
	_update_scroll_textures()
	_scroll_offset = 0.0
	_scroll_container.position.x = scroll_anim_start_x_position
	var distance: float = (reward_idx - scroll_anim_start_idx) \
			* (scroll_anim_item_width + scroll_anim_gap_between_items) \
			+ randf_range(-scroll_anim_item_width, scroll_anim_item_width) / 2
	var duration: float = 2 * distance / scroll_anim_start_speed
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(self, ^":_scroll_offset", distance, duration)
	
	if not reward.is_empty() and not '?' in reward:
		Globals.set_int(type + "_rare_got", 0)
		Globals.set_int(type + "_epic_got", 0)
		Globals.set_int(type + "_legendary_got", 0)
	return reward


func _fill_scroll_idx_with_item(idx: int, item: Resource) -> void:
	if item is SkinData:
		var data := item as SkinData
		var texture: Texture2D = load(data.image_path)
		if not texture in _cached_textures:
			_cached_textures.append(texture)
		_scroll_textures[idx] = texture
		_scroll_names[idx] = data.name
	elif item is SkillData:
		var data := item as SkillData
		var texture: Texture2D = load(data.image_path)
		if not texture in _cached_textures:
			_cached_textures.append(texture)
		_scroll_textures[idx] = texture
		_scroll_names[idx] = data.name
	elif item is WeaponData:
		var data := item as WeaponData
		var texture: Texture2D = load(data.image_path)
		if not texture in _cached_textures:
			_cached_textures.append(texture)
		_scroll_textures[idx] = texture
		_scroll_names[idx] = data.name


func _fill_scroll_idx_with_coins(idx: int, rarity: ItemsDB.Rarity, type: String) -> void:
	_scroll_textures[idx] = _coins_compensation_textures[rarity - 1]
	_scroll_names[idx] = "%d монет" % _get_coins_compensation(rarity, type)


func _get_coins_compensation(rarity: ItemsDB.Rarity, type: String) -> int:
	match rarity:
		ItemsDB.Rarity.RARE:
			return coins_per_skin_rare if "skin" in type else coins_per_equip_rare
		ItemsDB.Rarity.EPIC:
			return coins_per_skin_epic if "skin" in type else coins_per_equip_epic
		ItemsDB.Rarity.LEGENDARY:
			return coins_per_equip_legendary if "skin" in type else coins_per_equip_legendary
	return 0


func _get_idx_weighted(chances: Array[float]) -> int:
	var num: float = randf_range(0.0, 100.0)
	var base := 0.0
	for idx: int in chances.size():
		if num <= chances[idx] + base:
			return idx
		base += chances[idx]
	return chances.size() - 1


func _show_screen(screen: NodePath) -> void:
	(get_node(screen) as CanvasItem).show()
	get_node(screen).process_mode = Node.PROCESS_MODE_INHERIT


func _hide_screens() -> void:
	($Coins as CanvasItem).hide()
	($Equip as CanvasItem).hide()
	($Box as CanvasItem).hide()
	
	$Coins.process_mode = Node.PROCESS_MODE_DISABLED
	$Equip.process_mode = Node.PROCESS_MODE_DISABLED
	$Box.process_mode = Node.PROCESS_MODE_DISABLED


func _update_scroll_textures() -> void:
	var idx: int = 0
	for item: ColorRect in $Box/Scroll/Container.get_children():
		var scroll_idx: int = _scroll_current_idx + idx
		item.color = ItemsDB.RARITY_COLORS[_scroll_rarities[scroll_idx]]
		(item.get_node(^"Label") as Label).text = _scroll_names[scroll_idx]
		(item.get_node(^"Texture") as TextureRect).texture = _scroll_textures[scroll_idx]
		idx += 1


func _on_proceed_pressed() -> void:
	proceeded.emit()
