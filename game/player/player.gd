class_name Player
extends Entity

## Узел игрока.
##
## Может иметь оружие, скин и навык.

## Издаётся, когда игрок меняет оружие.
signal weapon_changed(type: Weapon.Type)
## Издаётся, когда игрок экипирует новый навык.
signal skin_equipped(data: SkinData)
## Издаётся, когда игрок экипирует новый навык.
signal skill_equipped(data: SkillData)
## Издаётся, когда игрок экипирует новое оружие.
signal weapon_equipped(type: Weapon.Type, data: WeaponData)
## Издаётся, когда текст с информацией о боеприпасах текущего оружия был обновлён.
signal ammo_text_updated(text: String)

## Имя игрока.
var player_name: String
## Массив идентификаторов экипировки. Порядок: скин, навык, лёгкое оружие, тяжёлое оружие,
## оружие поддержки, ближнее оружие, дополнительное оружие. Если ID равен -1, то оружие/навык не
## экипирован. Если же равен -2, то оружие/навык экипирован, но он отсутствует в [ItemsDB].
var equip_data: Array[int]
## Массив из двух элементов. Первый - количество оставшихся использований, второй - откат.
var skill_vars: Array[int]
## Ссылка на скин.
var skin: PlayerSkin
## Ссылка на текущее оружие. Может быть равной [code]null[/code].
var current_weapon: Weapon
## Тип текущего оружия.
var current_weapon_type := Weapon.Type.LIGHT
## Ссылка на экипированный навык. Может быть равной [code]null[/code].
var skill: Skill

var _blocked_weapon_usage_counter: int = 0

## Узел, содержащий ввод игрока.
@onready var player_input: PlayerInput = $Input
## Узел крови.
@onready var blood: CPUParticles2D = $Visual/Blood
## Узел с позицией для камеры.
@onready var camera_target: Marker2D = $CameraTarget
## Родительский узел всех оружий. Используйте [method get_child] на нём с [enum Weapon.Type] в
## качестве параметра, чтобы получить оружие нужного типа.
@onready var weapons: Node2D = $Visual/Weapons


func _ready() -> void:
	super()
	
	($Info/Name as Label).text = player_name
	($Info/Name as CanvasItem).self_modulate = TEAM_COLORS[team]
	if is_local():
		world.set_local_player(self)
		world.set_local_team(team)
		($ControlIndicator as CanvasItem).show()
		($ControlIndicator as CanvasItem).self_modulate = TEAM_COLORS[team]
		($AudioListener2D as AudioListener2D).make_current()
	
	set_skin(Globals.items_db.skins[equip_data[0]])
	set_skill(Globals.items_db.skills[equip_data[1]] if equip_data[1] >= 0 else null)
	
	set_weapon(Weapon.Type.LIGHT,
			Globals.items_db.weapons[equip_data[2]] if equip_data[2] >= 0 else null)
	set_weapon(Weapon.Type.HEAVY,
			Globals.items_db.weapons[equip_data[3]] if equip_data[3] >= 0 else null)
	set_weapon(Weapon.Type.SUPPORT,
			Globals.items_db.weapons[equip_data[4]] if equip_data[4] >= 0 else null)
	set_weapon(Weapon.Type.MELEE,
			Globals.items_db.weapons[equip_data[5]] if equip_data[5] >= 0 else null)
	set_weapon(Weapon.Type.ADDITIONAL,
			Globals.items_db.weapons[equip_data[6]] if equip_data[6] >= 0 else null)
	
	_update_health_bar_visibility(world.local_team)
	world.local_team_set.connect(_update_health_bar_visibility)


func _process(_delta: float) -> void:
	if not is_local():
		return
	
	if is_instance_valid(current_weapon) and player_input.showing_aim \
			and current_weapon.can_shoot():
		camera_target.position = player_input.aim_direction * current_weapon.aim_camera_distance
	else:
		camera_target.position = Vector2.ZERO


func _health_changed(_old_value: int, new_value: int) -> void:
	blood.emitting = new_value < max_health / 3.0


func _disarmed() -> void:
	block_weapon_usage()


func _armed() -> void:
	unblock_weapon_usage()


## Меняет оружие на тип [param to].[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 5)
func change_weapon(to: Weapon.Type) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	if is_instance_valid(current_weapon):
		current_weapon.ammo_changed.disconnect(_on_current_weapon_ammo_changed)
		current_weapon.unmake_current()
	
	_set_current_weapon(to)


## Перезаряжает оружие.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 5)
func reload_weapon(current_ammo: int, current_ammo_in_stock: int, args: Array) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	current_weapon.ammo = current_ammo
	current_weapon.ammo_in_stock = current_ammo_in_stock
	current_weapon.reload.callv(args)
	print_verbose("%s started reloading." % name)


## Активирует дополнительную кнопку оружия.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 5)
func additional_button_weapon(args: Array) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	current_weapon.additional_button.callv(args)
	print_verbose("%s used additional button." % name)


## Восстанавливает [param ratio] боеприпасов на оружии типа [param type], где [param ratio] - 
## значение от [code]0.0[/code] (не восстанавливать боеприпасы) до [code]1.0[/code] (восстанавливает
## все боеприпасы). Округление происходит вверх.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 5)
func add_ammo_to_weapon(type: Weapon.Type, ratio: float) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	var target_weapon: Weapon = weapons.get_child(type)
	target_weapon.ammo_in_stock = mini(
			target_weapon.ammo_in_stock + ceili(target_weapon.ammo_total * ratio),
			target_weapon.ammo_total - target_weapon.ammo_per_load
	)
	print_verbose("Added %f of ammo to weapon of type %d of %s." % [ratio, type, name])


## Использует навык.[br]
## [b]Примечание[/b]: этот метод должен вызываться только сервером и только как RPC.
@rpc("call_local", "reliable", "authority", 5)
func use_skill(args: Array) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	skill.use(args)
	print_verbose("%s used skill." % name)


## Отсылает запрос на смену оружия на тип [param to].
func try_change_weapon(to: Weapon.Type) -> void:
	if to == current_weapon_type:
		return
	_request_change_weapon.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, to)


## Отсылает запрос на перезарядку.
func try_reload_weapon() -> void:
	_request_reload.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## Отсылает запрос на использование дополнительной кнопки оружия.
func try_use_additional_button_weapon() -> void:
	_request_additional_button.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## Отсылает запрос на перезарядку навыка.
func try_use_skill() -> void:
	_request_use_skill.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


## Устанавливает скин из [param data].
func set_skin(data: SkinData) -> void:
	for old_skin: PlayerSkin in $Visual/Skin.get_children():
		old_skin.finalize()
	
	var skin_scene: PackedScene = load(data.scene_path)
	skin = skin_scene.instantiate()
	$Visual/Skin.add_child(skin)
	skin.initialize(self, data)
	_health_changed(current_health, current_health) # обновить истекание кровью
	equip_data[0] = data.idx_in_db if data.idx_in_db >= 0 else -2 # если нет в БД
	skin_equipped.emit(data)
	print_verbose("Skin %s with index %d on %s set." % [data.id, data.idx_in_db, name])


## Устанавливает оружие из [param data] типа [param type].
func set_weapon(type: Weapon.Type, data: WeaponData) -> void:
	var old_weapon: Node = weapons.get_child(type)
	if old_weapon == current_weapon:
		(old_weapon as Weapon).unmake_current()
	# чтобы не мешало при возни с индексами и move_child
	weapons.remove_child(old_weapon)
	old_weapon.queue_free()
	
	if not data:
		var placeholder := Node.new()
		placeholder.name = "NoWeapon%d" % type
		weapons.add_child(placeholder)
		weapons.move_child(placeholder, type)
		equip_data[2 + type] = -1
		weapon_equipped.emit(type, null)
		print_verbose("Removed weapon with type %d on %s." % [type, name])
		
		if current_weapon_type == type:
			_set_current_weapon(type)
		return
	
	var weapon_scene: PackedScene = load(data.scene_path)
	var weapon: Weapon = weapon_scene.instantiate()
	weapons.add_child(weapon)
	weapons.move_child(weapon, type)
	weapon.initialize(self, data)
	equip_data[2 + type] = data.idx_in_db if data.idx_in_db >= 0 else -2 # если нет в БД
	
	weapon_equipped.emit(type, data)
	print_verbose("Set weapon %s with index %d with type %d on %s." % [
		data.id,
		data.idx_in_db,
		type,
		name,
	])
	
	if current_weapon_type == type or not current_weapon:
		_set_current_weapon(type)


## Устанавливает навык из [param data]. Если [param reset_skill_vars] равен [code]true[/code],
## то [member skill_vars] будет сброшен.
func set_skill(data: SkillData, reset_skill_vars := false) -> void:
	if reset_skill_vars:
		skill_vars.clear()
	
	if is_instance_valid(skill):
		remove_child(skill)
		skill.queue_free()
	
	if not data:
		skill = null
		skill_equipped.emit(data)
		print_verbose("Removed skill on %s." % name)
		return
	
	var skill_scene: PackedScene = load(data.scene_path)
	skill = skill_scene.instantiate()
	add_child(skill)
	skill.initialize(self, data)
	equip_data[1] = data.idx_in_db if data.idx_in_db >= 0 else -2 # если нет в БД
	skill_equipped.emit(data)
	print_verbose("Set skill %s with index %d on %s." % [data.id, data.idx_in_db, name])


## Блокирует использование любой экипировки и переключение между оружиями.
func block_weapon_usage() -> void:
	_blocked_weapon_usage_counter += 1


## Возвращает возможность использовать любую экипировки и переключаться между оружиями.
func unblock_weapon_usage() -> void:
	_blocked_weapon_usage_counter -= 1


## Возвращает [code]true[/code], если экипировку можно использовать.
func can_use_weapon() -> bool:
	return _blocked_weapon_usage_counter <= 0


@rpc("any_peer", "reliable", "call_local", 5)
func _request_change_weapon(to: Weapon.Type) -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if id != sender_id:
		push_warning("RPC Sender ID (%d) doesn't match with player ID (%d)." % [sender_id, id])
		return
	if not can_use_weapon() or to == current_weapon_type \
			or to == Weapon.Type.ADDITIONAL and equip_data[6] == -1 or to < 0:
		return
	
	change_weapon.rpc(to)


@rpc("any_peer", "unreliable", "call_local", 5)
func _request_reload() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if id != sender_id:
		push_warning("RPC Sender ID (%d) doesn't match with player ID (%d)." % [sender_id, id])
		return
	if not can_use_weapon() or not is_instance_valid(current_weapon) \
			or not current_weapon.can_reload():
		return
	
	reload_weapon.rpc(current_weapon.ammo, current_weapon.ammo_in_stock,
			current_weapon.get_reload_args())


@rpc("any_peer", "reliable", "call_local", 5)
func _request_additional_button() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if id != sender_id:
		push_warning("RPC Sender ID (%d) doesn't match with player ID (%d)." % [sender_id, id])
		return
	if not can_use_weapon() or not is_instance_valid(current_weapon) \
			or not current_weapon.can_use_additional_button():
		return
	
	additional_button_weapon.rpc(current_weapon.get_additional_button_args())


@rpc("any_peer", "reliable", "call_local", 5)
func _request_use_skill() -> void:
	if not multiplayer.is_server():
		push_error("Unexpected call on client.")
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	if id != sender_id:
		push_warning("RPC Sender ID (%d) doesn't match with player ID (%d)." % [sender_id, id])
		return
	if not can_use_weapon() or not is_instance_valid(skill) or not skill.can_use():
		return
	
	use_skill.rpc(skill.get_use_args())


func _set_current_weapon(to: Weapon.Type) -> void:
	current_weapon = weapons.get_child(to) as Weapon
	if current_weapon:
		current_weapon.make_current()
		current_weapon.ammo_changed.connect(_on_current_weapon_ammo_changed)
		ammo_text_updated.emit(current_weapon.get_ammo_text())
	else:
		ammo_text_updated.emit("Нет оружия")
	current_weapon_type = to
	weapon_changed.emit(to)
	print_verbose("%s changed current weapon to type %d." % [name, to])


func _update_health_bar_visibility(local_team: int) -> void:
	($Info/HealthBar as CanvasItem).visible = team == local_team and not is_local()


func _on_current_weapon_ammo_changed(_in_stock: bool) -> void:
	ammo_text_updated.emit(current_weapon.get_ammo_text())
