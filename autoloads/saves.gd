extends Node

var open_save: SaveFile = SaveFile.new()
var open_save_ind := 0

func _init():
	DirAccess.make_dir_recursive_absolute("user://saves/")
	read_save(open_save_ind)

func save():
	write_save(open_save_ind)

func read_save(ind: int):
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.READ)
	if not file:
		var f2 = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
		if not f2: return
		f2.close()
		open_save.clear()
	else:
		if not open_save.read(file):
			open_save.clear()
		file.close()
	open_save_ind = ind

func write_save(ind: int):
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
	open_save.write(file)
	file.close()

