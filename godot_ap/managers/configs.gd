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

func _init():
	load_cfg()

func load_cfg():
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.READ)
	if not file:
		return
	is_tracking = 0 != file.get_8()
	verbose_trackerpack = 0 != file.get_8()
	file.close()
func save_cfg():
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.WRITE)
	file.store_8(is_tracking as int)
	file.store_8(verbose_trackerpack as int)
	file.close()

