extends Node

var open_save: SaveFile = SaveFile.new()

func _init():
	DirAccess.make_dir_recursive_absolute("user://saves/")
	Archipelago.aplock = open_save.aplock
	read_save(0)

func read_save(ind: int):
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.READ)
	if not file:
		return
	open_save.read(file)
	Archipelago.aplock = open_save.aplock
func write_save(ind: int):
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
	open_save.write(file)

