class_name Console
extends Node

## Внутриигровая консоль.

## Размер буфера ввода.
const BUFFER_SIZE: int = 16384
## Список функций, в которые этот класс будет передавать введённую пользователем команду в виде
## [PackedStringArray]. Должны возвращать [code]true[/code], если команда распознана
## (не важно правильно ли введена).
var command_processors: Array[Callable]
## Список функций, которые выполняет этот класс, когда пользователем была введена команда "help".
var help_processors: Array[Callable]


func _ready() -> void:
	WorkerThreadPool.add_task(_command_thread, true)


func _command_thread() -> void:
	while true:
		var command: String = OS.read_string_from_stdin(BUFFER_SIZE)
		if not command.is_empty():
			_process_command.call_deferred(command)
		OS.delay_msec(100)


func _process_command(command_str: String) -> void:
	var command: PackedStringArray = command_str.split(' ')
	if command[0] == "help" and command.size() == 1:
		print("Help")
		print("Legend: [arg] - optional, <arg> - required. \
Players are specified by starting letters of their names (case-sensitive).")
		print("Always available commands:")
		print("quit - Quits game.")
		print("restart [args] - Restarts game with given args.")
		print("Note: restarting with --console may not work as expected.")
		print("Current available commands:")
		for callable: Callable in help_processors:
			callable.call()
	elif command[0] == "quit" and command.size() == 1:
		Globals.quit()
	elif command[0] == "restart":
		var args: PackedStringArray = command.slice(1)
		Globals.quit(true, args)
	else:
		var recognized := false
		for callable: Callable in command_processors:
			recognized = callable.call(command) or recognized
		
		if not recognized:
			printerr('Command "%s" not recognized. Use "help" to see available.' % command_str)
