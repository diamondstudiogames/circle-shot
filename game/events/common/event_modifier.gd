class_name EventModifier
extends Node
## Модификатор события.

## Данные этого модификатора.
var data: EventModifierData
## Ссылка на [Event].
@onready var event: Event = get_parent()

## Инициализирует модификтор. Метод предназначен для вызова из [Event].
func initialize() -> void:
	_initialize()


## Настраивает игрока. Метод предназначен для вызова из [Event]. Если [param server_only] равен
## [code]true[/code], то настройка игрока будет выполнена до добавления в дерево и только
## на сервере, иначе - на всех клиентах в момент добавления игрока в дерево.
func customize_player(player: Player, server_only: bool) -> void:
	if server_only:
		_customize_player_server(player)
	else:
		_customize_player(player)


## Метод для переопределения. Вызывается в момент инициализации события. Используйте его для
## инициализации модификатора, подключения к нужным сигналам и тому подобному.
func _initialize() -> void:
	pass


## Метод для переопределения. Используйте для настройки игрока до добавления в дерево на сервере.
## Например, забрать или поменять оружие, изменить максимальное здоровье.
func _customize_player_server(_player: Player) -> void:
	pass


## Метод для переопределения. Используйте для настройки игрока сразу после добавления в дерево.
## Вызывается на всех клиентах.
func _customize_player(_player: Player) -> void:
	pass
