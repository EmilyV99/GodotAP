class_name APConfigManager

var is_tracking := false :
	set(val):
		if val != is_tracking:
			is_tracking = val
			save_cfg()
var verbose_trackerpack := false :
	set(val):
		if val != verbose_trackerpack:
			verbose_trackerpack = val
			save_cfg()
var hide_finished_map_squares := false :
	set(val):
		if val != hide_finished_map_squares:
			hide_finished_map_squares = val
			save_cfg()

func _init():
	load_cfg()

func load_cfg():
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.READ)
	if not file:
		return
	var byte = file.get_8()
	is_tracking = (byte & 0b00000001) != 0
	verbose_trackerpack = (byte & 0b00000010) != 0
	hide_finished_map_squares = (byte & 0b00000100) != 0
	file.close()
func save_cfg():
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.WRITE)
	var byte = 0
	if is_tracking: byte |= 0b00000001
	if verbose_trackerpack: byte |= 0b00000010
	if hide_finished_map_squares: byte |= 0b00000100
	file.store_8(byte)
	file.close()

