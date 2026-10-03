class_name APSaveManager 
extends Node
## Save file manager.
##
## Manages saving information stored in [SaveFile] instances to disk. If more information should be
## saved to disk, extend this class and override [method make_save_file] to return a subclass of
## [SaveFile] with the desired extra information.

## Header for save files.
@export var SAVE_HEADER: String = "GodotAP_Save_File"

## Currently open save file.
var open_save: SaveFile

## Index number of the currently open save file.
var open_save_ind := -1


## Create a new save file.
func make_save_file() -> SaveFile: 
	return SaveFile.new()


func _init() -> void:
	open_save = make_save_file()
	DirAccess.make_dir_recursive_absolute("user://saves/")


func _ready() -> void:
	if OS.is_debug_build(): # Debug commands for forcibly saving/loading via console
		Archipelago.cmd_manager.register_command(ConsoleCommand.new("/save").debug()
			.add_help("[num]", "Saves the save file, optionally to a different-numbered slot. num >= 0.")
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if command_args.size() == 1:
					save()
				elif (
						command_args.size() != 2 
						or not command_args[1].is_valid_int() 
						or int(command_args[1]) < 0
				):
						cmd.output_usage(mgr.console)
				else:
					write_save(int(command_args[1]))))
		
		Archipelago.cmd_manager.register_command(ConsoleCommand.new("/delsave").debug()
			.add_help("num", "Deletes the specified save file. num >= 0.")
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if (
						command_args.size() != 2 
						or not command_args[1].is_valid_int() 
						or int(command_args[1]) < 0
				):
					cmd.output_usage(mgr.console)
				else:
					delete_save(int(command_args[1]))))
		
		Archipelago.cmd_manager.register_command(ConsoleCommand.new("/loadsave").debug()
			.add_help("num", "Loads the specified save file. num >= 0.")
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if (
						command_args.size() != 2 
						or not command_args[1].is_valid_int() 
						or int(command_args[1]) < 0
				):
					cmd.output_usage(mgr.console)
				else:
					var is_conn: bool = Archipelago.status != AP.APStatus.DISCONNECTED
					if is_conn:
						Archipelago.ap_disconnect()
						while Archipelago.status != AP.APStatus.DISCONNECTED:
							await Archipelago.status_updated
					read_save(int(command_args[1]))
					if is_conn:
						Archipelago.ap_reconnect_to_save()))


## Write save data to [SaveFile] on disk at index [member open_save_ind].
func save() -> void:
	write_save(open_save_ind)


## Read save file at index [param ind] from disk. [param ind] must be nonnegative.
## Returns [code]true[/code] if read is successful. Save will be assigned to [member open_save] if
## successful.
func read_save(ind: int) -> bool:
	if ind < 0:
		return false
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.READ)
	if not file or file.get_pascal_string() != SAVE_HEADER:
		var f2 = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
		if not f2:
			return false
		f2.close()
		open_save.clear()
	else:
		if not open_save.read(file):
			open_save.clear()
		file.close()
	open_save_ind = ind
	Archipelago.creds = open_save.creds
	Archipelago.aplock = open_save.aplock
	return true


## Write save file to save at index [param ind] on disk. [param ind] must be nonnegative.
## Returns [code]true[/code] if successful.
func write_save(ind: int) -> bool:
	if ind < 0:
		return false
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
	file.store_pascal_string(SAVE_HEADER)
	open_save.write(file)
	file.close()
	return true


## Delete save file at index [param ind] from disk.
func delete_save(ind: int):
	DirAccess.remove_absolute("user://saves/%d.dat" % ind)
