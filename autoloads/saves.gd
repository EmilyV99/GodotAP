extends Node

var open_save: SaveFile = SaveFile.new()
var open_save_ind := -1

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves/")

func save() -> void:
	write_save(open_save_ind)

func read_save(ind: int) -> bool:
	if ind < 0: return false
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.READ)
	if not file:
		var f2 = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
		if not f2: return false
		f2.close()
		open_save.clear()
	else:
		if not open_save.read(file):
			open_save.clear()
		file.close()
	open_save_ind = ind
	return true

func write_save(ind: int) -> bool:
	if ind < 0: return false
	var file: FileAccess = FileAccess.open("user://saves/%d.dat" % ind, FileAccess.WRITE)
	open_save.write(file)
	file.close()
	return true

func delete_save(ind: int):
	DirAccess.remove_absolute("user://saves/%d.dat" % ind)
