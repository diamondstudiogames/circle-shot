extends Control


const SPECIAL_OFFERS_START_ID: int = 500
const ONLINE_OFFERS_START_ID: int = 1000
const ITEMS_NAMES: Dictionary[String, String] = {
	"coins": "Монеты",
	"weapon": "Оружие",
	"skill": "Навык",
	"skin": "Скин",
	"skin_box": "Ящик со скином",
	"skin_elite_box": "Элитный ящик со скином",
	"equip_box": "Ящик с экипировкой",
	"equip_elite_box": "Элитный ящик с экипировкой",
}

@export_multiline var box_info_text := ""
# См. Loot для подробностей, и держите в синхронизации с ним
@export_group("Box Chances", "box_chance_")
@export_range(0.0, 100.0, 0.01) var box_chance_rare := 67.0
@export_range(0.0, 100.0, 0.01) var box_chance_epic := 26.0
@export_range(0.0, 100.0, 0.01) var box_chance_legendary := 7.0
@export_range(0.0, 100.0, 0.01) var box_chance_increase := 10.0

@export_group("Elite Box Chances", "elite_box_chance_")
@export_range(0.0, 100.0, 0.01) var elite_box_chance_rare := 40.0
@export_range(0.0, 100.0, 0.01) var elite_box_chance_epic := 45.0
@export_range(0.0, 100.0, 0.01) var elite_box_chance_legendary := 15.0
@export_range(0.0, 100.0, 0.01) var elite_box_chance_increase := 17.0

@export_group("Items Costs")
@export_subgroup("Equip", "cost_equip_")
@export var cost_equip_rare: int = 160
@export var cost_equip_epic: int = 700
@export var cost_equip_legendary: int = 2500
@export var cost_equip_box: int = 200
@export var cost_equip_elite_box: int = 500
@export_subgroup("Skin", "cost_skin_")
@export var cost_skin_rare: int = 65
@export var cost_skin_epic: int = 280
@export var cost_skin_legendary: int = 1000
@export var cost_skin_box: int = 80
@export var cost_skin_elite_box: int = 200

var _listed_offers: Dictionary[int, Array]

var _items_offer_icons: Dictionary[String, Texture2D] = {
	"coins": load("uid://dmpm2a2wq3u4p"),
	"skin_box": load("uid://u3uysy5do7nd"),
	"skin_elite_box": load("uid://bagp5s7stcybl"),
	"equip_box": load("uid://dx36ekj6pm8tr"),
	"equip_elite_box": load("uid://1e2hpb4yqrq3"),
}
var _offer_scene: PackedScene = load("uid://dn1f63651tgy0")
var _offer_item_scene: PackedScene = load("uid://dbnx3sb61pp2")
@onready var _purchase_dialog: ConfirmationDialog = $Purchase


func _ready() -> void:
	_list_online_offers()
	_list_special_offers()
	
	var current_day: int = Time.get_datetime_dict_from_system()["day"]
	if Globals.get_int("last_daily_offers_day", -1) != current_day \
			and Globals.get_int("last_daily_offers_ut", -1) < Time.get_unix_time_from_system():
		Globals.set_int("last_daily_offers_day", current_day)
		Globals.set_int("last_daily_offers_ut", int(Time.get_unix_time_from_system()))
		_generate_daily_offers()
	_list_daily_offers()
	
	Globals.main.loot_received.connect(_update_shop)
	_update_shop()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST when visible:
			_on_quit_pressed()


func buy(cost: int, rewards_str: String, offer_id: int = -1) -> void:
	var rewards: Array[String]
	rewards.assign(rewards_str.split(','))
	print_verbose("Purchase of %s with cost %d (offer ID: %d) requested." % [
		str(rewards),
		cost,
		offer_id,
	])
	rewards = Globals.main.verify_loot(rewards)
	if rewards.is_empty():
		print_verbose("Nothing to purchase, ignoring.")
		return
	
	if cost > Globals.get_int("coins"):
		print_verbose("Not enough coins.")
		($NoCoins/AnimationPlayer as AnimationPlayer).play(&"not_enough")
		($NoCoins/AnimationPlayer as AnimationPlayer).seek(0.0)
		return
	if cost <= 0:
		_on_purchase_confirmed(cost, rewards, offer_id)
		return
	
	_purchase_dialog.dialog_text = "Ты действительно хочешь купить:\n"
	for reward: String in rewards:
		var type: String = Utils.strip_string(reward.get_slice(':', 0))
		var value: String = Utils.strip_string(reward.get_slice(':', 1))
		var description: String
		match type:
			"coins":
				description = value
			"skin_box", "skin_elite_box", "equip_box", "equip_elite_box":
				description = "%s шт." % value
			"weapon":
				description = Globals.items_db.weapons_by_id[value].name
			"skill":
				description = Globals.items_db.skills_by_id[value].name
			"skin":
				description = Globals.items_db.skins_by_id[value].name
		_purchase_dialog.dialog_text += "- %s: %s\n" % [ITEMS_NAMES[type], description]
	
	_purchase_dialog.dialog_text += "за монеты: %d?" % cost
	if _purchase_dialog.confirmed.is_connected(_on_purchase_confirmed):
		_purchase_dialog.confirmed.disconnect(_on_purchase_confirmed)
	_purchase_dialog.confirmed.connect(_on_purchase_confirmed.bind(cost, rewards, offer_id))
	_purchase_dialog.popup_centered(Vector2i(_purchase_dialog.size.x, 0))
	print_verbose("Waiting for purchase confirmation...")


func show_box_info(type: String) -> void:
	($BoxInfo/VBoxContainer/BoxType as Label).text = ITEMS_NAMES[type]
	
	var chances: Array[float]
	var chance_increase: float
	if "elite" in type:
		chances = Utils.calculate_box_chances(
				elite_box_chance_rare, elite_box_chance_epic, elite_box_chance_legendary,
				elite_box_chance_increase, Globals.get_int(type + "_rare_got"),
				Globals.get_int(type + "_epic_got"), Globals.get_int(type + "_legendary_got")
		)
		chance_increase = elite_box_chance_increase
	else:
		chances = Utils.calculate_box_chances(
				box_chance_rare, box_chance_epic, box_chance_legendary, box_chance_increase,
				Globals.get_int(type + "_rare_got"), Globals.get_int(type + "_epic_got"),
				Globals.get_int(type + "_legendary_got")
		)
		chance_increase = box_chance_increase
	
	($BoxInfo/VBoxContainer/RichTextLabel as RichTextLabel).text = box_info_text.format({
		"rare_color": ItemsDB.RARITY_COLORS[ItemsDB.Rarity.RARE].to_html(false),
		"rare_chance": "%d" % chances[0] if is_equal_approx(chances[0], int(chances[0]))
				else "%.2f" % chances[0],
		"epic_color": ItemsDB.RARITY_COLORS[ItemsDB.Rarity.EPIC].to_html(false),
		"epic_chance": "%d" % chances[1] if is_equal_approx(chances[1], int(chances[1]))
				else "%.2f" % chances[1],
		"legendary_color": ItemsDB.RARITY_COLORS[ItemsDB.Rarity.LEGENDARY].to_html(false),
		"legendary_chance": "%d" % chances[2] if is_equal_approx(chances[2], int(chances[2]))
				else "%.2f" % chances[2],
		"chance_increase": str(int(chance_increase))
				if is_equal_approx(chance_increase, int(chance_increase)) else str(chance_increase),
	})
	
	($BoxInfo as Window).popup_centered()


func _list_online_offers() -> void:
	if not Globals.data_file:
		print_verbose("Online offers are not available.")
		return
	print_verbose("Listing online offers...")
	
	for section: String in Globals.data_file.get_sections():
		if not section.begins_with("offer_"):
			continue
		var offer: String = Utils.strip_string(section.right(-6))
		if offer.is_empty() or not offer.is_valid_int():
			print_verbose("Found invalid online offer, ignoring.")
			continue
		var offer_id := int(offer)
		if offer_id < ONLINE_OFFERS_START_ID:
			print_verbose("Found invalid online offer %s: ID should start from %d." % [
				offer,
				ONLINE_OFFERS_START_ID,
			])
			continue
		if offer_id in Globals.get_variant("used_online_offers", [] as Array[int]):
			print_verbose("Found already used offer with ID %d." % offer_id)
			continue
		
		if not (Globals.data_file.has_section_key(section, "name") \
				and typeof(Globals.data_file.get_value(section, "name")) == TYPE_STRING):
			print_verbose("Found invalid online offer %s: no name, ignoring." % offer)
			continue
		var offer_name: String = Globals.data_file.get_value(section, "name")
		
		if not (Globals.data_file.has_section_key(section, "cost") \
				and typeof(Globals.data_file.get_value(section, "cost")) == TYPE_INT):
			print_verbose("Found invalid online offer %s: no cost, ignoring." % offer)
			continue
		var cost: int = Globals.data_file.get_value(section, "cost")
		
		if not (Globals.data_file.has_section_key(section, "sale") \
				and typeof(Globals.data_file.get_value(section, "sale")) == TYPE_INT):
			print_verbose("Found invalid online offer %s: no sale, ignoring." % offer)
			continue
		var sale: int = Globals.data_file.get_value(section, "sale")
		
		if not (Globals.data_file.has_section_key(section, "rewards") \
				and typeof(Globals.data_file.get_value(section, "rewards")) == TYPE_ARRAY):
			print_verbose("Found invalid online offer %s: no rewards, ignoring." % offer)
			continue
		var rewards: Array = Globals.data_file.get_value(section, "rewards")
		if rewards.get_typed_builtin() != TYPE_STRING:
			print_verbose("Found invalid online offer %s: no rewards, ignoring." % offer)
			continue
		if rewards != Globals.main.verify_loot(rewards):
			print_verbose("Found online offer %s with incorrect or already obtained items." % offer)
			continue
		
		if Globals.data_file.has_section_key(section, "only_for_ids") \
				and typeof(Globals.data_file.get_value(section, "only_for_ids")) == TYPE_ARRAY:
			var only_for_ids: Array = Globals.data_file.get_value(section, "only_for_ids")
			if only_for_ids.get_typed_builtin() == TYPE_STRING \
					and not Globals.get_string("save_id") in only_for_ids:
				# нам не предназначен
				continue
		
		_list_offer(cost, ','.join(rewards), offer_name, sale, offer_id)
	
	print_verbose("Done listing online offers.")


func _list_special_offers() -> void:
	print_verbose("Listing special offers...")
	var special_offers: Array[Dictionary] = \
			Globals.get_variant("special_offers", [] as Array[Dictionary])
	for offer: Dictionary in special_offers:
		var offer_id: int = offer["id"]
		if offer_id < SPECIAL_OFFERS_START_ID:
			print_verbose("Found special offer with ID less than %d." % SPECIAL_OFFERS_START_ID)
			continue
		var offer_name: String = offer["name"]
		var cost: int = offer["cost"]
		var sale: int = offer["sale"]
		var rewards: Array[String] = offer["rewards"]
		_list_offer(cost, ','.join(rewards), offer_name, sale, offer_id)
	print_verbose("Done listing special offers.")


func _list_daily_offers() -> void:
	print_verbose("Listing daily offers...")
	var daily_offers: Array[Dictionary] = \
			Globals.get_variant("daily_offers", [] as Array[Dictionary])
	for offer: Dictionary in daily_offers:
		var offer_id: int = offer["id"]
		if offer_id >= SPECIAL_OFFERS_START_ID:
			print_verbose("Found daily offer with ID greater than %d." % SPECIAL_OFFERS_START_ID)
			continue
		var offer_name: String = offer["name"]
		var cost: int = offer["cost"]
		var sale: int = offer["sale"]
		var rewards: Array[String] = offer["rewards"]
		_list_offer(cost, ','.join(rewards), offer_name, sale, offer_id)
	print_verbose("Done listing daily offers.")


func _generate_daily_offers() -> void:
	print_verbose("Generating daily offers...")
	var daily_offers: Array[Dictionary]
	
	var gift_offer := {
		"name": "Подарок",
		"cost": 0,
		"sale": 0,
		"id": 0,
	}
	var gift_rewards: Array[String]
	match randi() % 4:
		0, 1: # монеты
			gift_rewards.append("coins:%d" % (randi_range(7, 25) * 10))
		2: # ящик с экипировкой
			gift_rewards.append("equip_box:1")
		3: # ящик со скином
			gift_rewards.append("skin_box:1")
	gift_offer["rewards"] = gift_rewards
	daily_offers.append(gift_offer)
	
	var locked_skins: Array[SkinData]
	var locked_weapons: Array[WeaponData]
	var locked_skills: Array[SkillData]
	for skin: SkinData in Globals.items_db.skins:
		if skin in Globals.items_db.other_skins:
			continue
		if not skin.rarity in [
			ItemsDB.Rarity.RARE,
			ItemsDB.Rarity.EPIC,
			ItemsDB.Rarity.LEGENDARY
		]:
			continue
		if Globals.items_db.has_equip_item(skin.id, ItemsDB.Item.SKIN):
			continue
		locked_skins.append(skin)
	for weapon: WeaponData in Globals.items_db.weapons:
		if weapon in Globals.items_db.other_weapons:
			continue
		if not weapon.rarity in [
			ItemsDB.Rarity.RARE,
			ItemsDB.Rarity.EPIC,
			ItemsDB.Rarity.LEGENDARY
		]:
			continue
		if Globals.items_db.has_equip_item(weapon.id, ItemsDB.Item.WEAPON):
			continue
		locked_weapons.append(weapon)
	for skill: SkillData in Globals.items_db.skills:
		if skill in Globals.items_db.other_skills:
			continue
		if not skill.rarity in [
			ItemsDB.Rarity.RARE,
			ItemsDB.Rarity.EPIC,
			ItemsDB.Rarity.LEGENDARY
		]:
			continue
		if Globals.items_db.has_equip_item(skill.id, ItemsDB.Item.SKILL):
			continue
		locked_skills.append(skill)
	
	var offers_count: int = randi_range(3, 6)
	var offers_types: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3]
	if not locked_skins.is_empty():
		offers_types.append_array([4, 4])
		if locked_skins.size() >= 2:
			offers_types.append(5)
	if not locked_weapons.is_empty() or not locked_skills.is_empty():
		offers_types.append_array([6, 6])
		if not locked_weapons.is_empty() and not locked_skills.is_empty():
			offers_types.append(7)
	if not locked_skins.is_empty() and \
			(not locked_weapons.is_empty() or not locked_skills.is_empty()):
		offers_types.append(8)
	
	var existing_rewards: Array[Array]
	while true:
		if existing_rewards.size() == offers_count:
			break
		var offer := {}
		match offers_types.pick_random():
			0: # Ящик
				offer["name"] = "Акция"
				var discount: float = [0.9, 0.9, 0.8, 0.75].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var count: int = randi_range(1, 3)
				if randi() % 2 == 0:
					offer["cost"] = int(cost_equip_box * discount) * count
					offer["rewards"] = ["equip_box:%d" % count] as Array[String]
				else:
					offer["cost"] = int(cost_skin_box * discount) * count
					offer["rewards"] = ["skin_box:%d" % count] as Array[String]
			1: # Элитный ящик
				offer["name"] = "Акция"
				var discount: float = [0.95, 0.95, 0.9, 0.85].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var count: int = randi_range(1, 2)
				if randi() % 2 == 0:
					offer["cost"] = int(cost_equip_elite_box * discount) * count
					offer["rewards"] = ["equip_elite_box:%d" % count] as Array[String]
				else:
					offer["cost"] = int(cost_skin_elite_box * discount) * count
					offer["rewards"] = ["skin_elite_box:%d" % count] as Array[String]
			2: # Два ящика разных типов
				offer["name"] = "Двойная акция"
				var discount: float = [0.85, 0.85, 0.75, 0.7].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var count_skin: int = randi_range(1, 2)
				var count_equip: int = randi_range(1, 2)
				offer["cost"] = int((cost_equip_box * count_equip + cost_skin_box * count_skin)
						* discount)
				offer["rewards"] = [
					"equip_box:%d" % count_equip,
					"skin_box:%d" % count_skin,
				] as Array[String]
			3: # Два элитных ящика разных типов
				offer["name"] = "Двойная акция"
				var discount: float = [0.9, 0.9, 0.85, 0.8].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var count_skin: int = randi_range(1, 2)
				var count_equip: int = randi_range(1, 2)
				offer["cost"] = int((cost_equip_elite_box * count_equip
						+ cost_skin_elite_box * count_skin) * discount)
				offer["rewards"] = [
					"equip_elite_box:%d" % count_equip,
					"skin_elite_box:%d" % count_skin,
				] as Array[String]
			4: # Скин
				offer["name"] = "Скин"
				offer["sale"] = 0
				var skin: SkinData = locked_skins.pick_random()
				match skin.rarity:
					ItemsDB.Rarity.RARE:
						offer["cost"] = cost_skin_rare
					ItemsDB.Rarity.EPIC:
						offer["cost"] = cost_skin_epic
					ItemsDB.Rarity.LEGENDARY:
						offer["cost"] = cost_skin_legendary
				offer["rewards"] = ["skin:%s" % skin.id] as Array[String]
			5: # Два скина
				offer["name"] = "Набор скинов"
				var discount: float = [0.95, 0.95, 0.9, 0.85].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				locked_skins.shuffle()
				var skin0: SkinData = locked_skins[0]
				var skin1: SkinData = locked_skins[1]
				var cost: int = 0
				match skin0.rarity:
					ItemsDB.Rarity.RARE:
						cost += cost_skin_rare
					ItemsDB.Rarity.EPIC:
						cost += cost_skin_epic
					ItemsDB.Rarity.LEGENDARY:
						cost += cost_skin_legendary
				match skin1.rarity:
					ItemsDB.Rarity.RARE:
						cost += cost_skin_rare
					ItemsDB.Rarity.EPIC:
						cost += cost_skin_epic
					ItemsDB.Rarity.LEGENDARY:
						cost += cost_skin_legendary
				offer["cost"] = int(cost * discount)
				offer["rewards"] = ["skin:%s" % skin0.id, "skin:%s" % skin1.id] as Array[String]
			6: # Экипировка
				offer["name"] = "Экипировка"
				offer["sale"] = 0
				var equip: Resource = (locked_weapons + locked_skills).pick_random()
				var weapon := equip as WeaponData
				if weapon:
					match weapon.rarity:
						ItemsDB.Rarity.RARE:
							offer["cost"] = cost_equip_rare
						ItemsDB.Rarity.EPIC:
							offer["cost"] = cost_equip_epic
						ItemsDB.Rarity.LEGENDARY:
							offer["cost"] = cost_equip_legendary
					offer["rewards"] = ["weapon:%s" % weapon.id] as Array[String]
				else:
					var skill := equip as SkillData
					match skill.rarity:
						ItemsDB.Rarity.RARE:
							offer["cost"] = cost_equip_rare
						ItemsDB.Rarity.EPIC:
							offer["cost"] = cost_equip_epic
						ItemsDB.Rarity.LEGENDARY:
							offer["cost"] = cost_equip_legendary
					offer["rewards"] = ["skill:%s" % skill.id] as Array[String]
			7: # Экипировка (навык И оружие)
				offer["name"] = "Набор экипировки"
				var discount: float = [0.95, 0.95, 0.9, 0.85].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var weapon: WeaponData = locked_weapons.pick_random()
				var skill: SkillData = locked_skills.pick_random()
				var cost: int = 0
				match weapon.rarity:
					ItemsDB.Rarity.RARE:
						cost += cost_equip_rare
					ItemsDB.Rarity.EPIC:
						cost += cost_equip_epic
					ItemsDB.Rarity.LEGENDARY:
						cost += cost_equip_legendary
				match skill.rarity:
					ItemsDB.Rarity.RARE:
						cost += cost_equip_rare
					ItemsDB.Rarity.EPIC:
						cost += cost_equip_epic
					ItemsDB.Rarity.LEGENDARY:
						cost += cost_equip_legendary
				offer["cost"] = int(cost * discount)
				offer["rewards"] = ["skill:%s" % skill.id, "weapon:%s" % weapon.id] as Array[String]
			8: # Скин и экипировка
				offer["name"] = "Набор"
				var discount: float = [0.95, 0.95, 0.9, 0.85].pick_random()
				offer["sale"] = 100 - int(100 * discount)
				var cost: int = 0
				var offer_rewards: Array[String]
				
				var skin: SkinData = locked_skins.pick_random()
				match skin.rarity:
					ItemsDB.Rarity.RARE:
						cost += cost_skin_rare
					ItemsDB.Rarity.EPIC:
						cost += cost_skin_epic
					ItemsDB.Rarity.LEGENDARY:
						cost += cost_skin_legendary
				offer_rewards.append("skin:%s" % skin.id)
				
				var equip: Resource = (locked_weapons + locked_skills).pick_random()
				var weapon := equip as WeaponData
				if weapon:
					match weapon.rarity:
						ItemsDB.Rarity.RARE:
							cost += cost_equip_rare
						ItemsDB.Rarity.EPIC:
							cost += cost_equip_epic
						ItemsDB.Rarity.LEGENDARY:
							cost += cost_equip_legendary
					offer_rewards.append("weapon:%s" % weapon.id)
				else:
					var skill := equip as SkillData
					match skill.rarity:
						ItemsDB.Rarity.RARE:
							cost += cost_equip_rare
						ItemsDB.Rarity.EPIC:
							cost += cost_equip_epic
						ItemsDB.Rarity.LEGENDARY:
							cost += cost_equip_legendary
					offer_rewards.append("skill:%s" % skill.id)
				
				offer["cost"] = int(cost * discount)
				offer["rewards"] = offer_rewards
		
		var rewards: Array[String] = offer["rewards"]
		rewards.sort()
		offer["rewards"] = rewards
		if rewards in existing_rewards:
			continue
		existing_rewards.append(rewards)
		offer["id"] = existing_rewards.size()
		daily_offers.append(offer)
	
	Globals.set_variant("daily_offers", daily_offers)


func _list_offer(cost: int, rewards_str: String, offer_name: String, sale: int, id: int) -> void:
	var offer: PanelContainer = _offer_scene.instantiate()
	offer.name = str(id)
	(offer.get_node(^"VBox/Name") as Label).text = offer_name
	if sale != 0:
		(offer.get_node(^"VBox/Buy/Sale") as CanvasItem).show()
		(offer.get_node(^"VBox/Buy/Sale/Amount") as Label).text = \
				('-' if sale > 0 else '+') + str(sale) + '%'
	if cost <= 0:
		(offer.get_node(^"VBox/Buy") as Button).text = "Бесплатно"
		(offer.get_node(^"VBox/Buy") as Button).icon = null
	else:
		(offer.get_node(^"VBox/Buy") as Button).text = str(cost)
	(offer.get_node(^"VBox/Buy") as BaseButton).pressed.connect(buy.bind(cost, rewards_str, id))
	
	var rewards: Array[String]
	rewards.assign(rewards_str.split(','))
	(offer.get_node(^"VBox/Items") as GridContainer).columns = ceili(rewards.size() / 2.0)
	for reward: String in rewards:
		var offer_item: ColorRect = _offer_item_scene.instantiate()
		
		var type: String = Utils.strip_string(reward.get_slice(':', 0))
		var value: String = Utils.strip_string(reward.get_slice(':', 1))
		var description: String
		var icon: Texture2D
		match type:
			"coins":
				description = value
				icon = _items_offer_icons[type]
			"skin_box", "skin_elite_box", "equip_box", "equip_elite_box":
				description = "%s шт." % value
				icon = _items_offer_icons[type]
			"weapon":
				description = Globals.items_db.weapons_by_id[value].name
				icon = load(Globals.items_db.weapons_by_id[value].image_path)
				offer_item.color = \
						ItemsDB.RARITY_COLORS[Globals.items_db.weapons_by_id[value].rarity]
			"skill":
				description = Globals.items_db.skills_by_id[value].name
				icon = load(Globals.items_db.skills_by_id[value].image_path)
				offer_item.color = \
						ItemsDB.RARITY_COLORS[Globals.items_db.skills_by_id[value].rarity]
			"skin":
				description = Globals.items_db.skins_by_id[value].name
				icon = load(Globals.items_db.skins_by_id[value].image_path)
				offer_item.color = \
						ItemsDB.RARITY_COLORS[Globals.items_db.skins_by_id[value].rarity]
		
		(offer_item.get_node(^"Name") as Label).text = ITEMS_NAMES[type]
		(offer_item.get_node(^"Description") as Label).text = description
		(offer_item.get_node(^"Icon") as TextureRect).texture = icon
		offer.get_node(^"VBox/Items").add_child(offer_item)
	
	if id >= SPECIAL_OFFERS_START_ID:
		%SpecialOffersContainer.add_child(offer)
	else:
		%DailyOffersContainer.add_child(offer)
	_listed_offers[id] = rewards
	print_verbose("Listed offer %s with ID %d: cost - %d, rewards - %s, sale - %d." % [
		offer_name,
		id,
		cost,
		str(rewards),
		sale,
	])


func _delete_offer(id: int) -> void:
	_listed_offers.erase(id)
	if id >= SPECIAL_OFFERS_START_ID:
		var offer: PanelContainer = %SpecialOffersContainer.get_node(str(id))
		offer.queue_free()
	else:
		var offer: PanelContainer = %DailyOffersContainer.get_node(str(id))
		offer.queue_free()
	
	if id < ONLINE_OFFERS_START_ID:
		var offers_key := "daily_offers" if id < SPECIAL_OFFERS_START_ID else "special_offers"
		var offers: Array[Dictionary] = Globals.get_variant(offers_key, [] as Array[Dictionary])
		for idx: int in range(offers.size() - 1, -1, -1):
			var offer: Dictionary = offers[idx]
			if not "id" in offer or offer["id"] == id:
				offers.remove_at(idx)
		Globals.set_variant(offers_key, offers)
	else:
		var used_online_offers: Array[int] = \
				Globals.get_variant("used_online_offers", [] as Array[int])
		if not id in used_online_offers:
			used_online_offers.append(id)
			Globals.set_variant("used_online_offers", used_online_offers)
	
	print_verbose("Deleted offer with ID %d." % id)


func _update_shop() -> void:
	(%CoinsCount as Label).text = str(Globals.get_int("coins"))
	
	for offer_id: int in _listed_offers.keys():
		var rewards: Array[String] = _listed_offers[offer_id]
		if Globals.main.verify_loot(rewards) != rewards:
			print_verbose("Offer with ID %d contains obtained items, deleting." % offer_id)
			_delete_offer(offer_id)


func _on_purchase_confirmed(cost: int, rewards: Array[String], offer_id: int = -1) -> void:
	print_verbose("Purchase confirmed.")
	if offer_id >= 0:
		_delete_offer(offer_id)
	Globals.set_int("coins", Globals.get_int("coins") - cost)
	Globals.main.receive_loot(rewards)


func _on_special_offers_container_child_order_changed() -> void:
	if is_queued_for_deletion():
		return
	(%SpecialOffers as CanvasItem).visible = %SpecialOffersContainer.get_child_count() > 0


func _on_daily_offers_container_child_order_changed() -> void:
	if is_queued_for_deletion():
		return
	(%NoDailyOffers as CanvasItem).visible = %DailyOffersContainer.get_child_count() == 0
	(%DailyOffersContainer as CanvasItem).visible = %DailyOffersContainer.get_child_count() > 0


func _on_update_day_timer_timeout() -> void:
	var current_day: int = Time.get_datetime_dict_from_system()["day"]
	if Globals.get_int("last_daily_offers_day", -1) == current_day \
			or Globals.get_int("last_daily_offers_ut", -1) >= Time.get_unix_time_from_system():
		return
	Globals.set_int("last_daily_offers_day", current_day)
	Globals.set_int("last_daily_offers_ut", int(Time.get_unix_time_from_system()))
	_generate_daily_offers()
	for child: Node in %DailyOffersContainer.get_children():
		child.name += "Outdated"
		child.queue_free()
	_list_daily_offers()


func _on_quit_pressed() -> void:
	queue_free()
