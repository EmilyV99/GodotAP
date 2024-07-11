class_name APConfigManager extends Node

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

func _ready():
	load_cfg()

func load_cfg() -> bool:
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.READ)
	if not file:
		return false
	_load_cfg(file)
	file.close()
	return true
func save_cfg() -> void:
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.WRITE)
	_save_cfg(file)
	file.close()

func _load_cfg(file: FileAccess):
	var byte = file.get_8()
	is_tracking = (byte & 0b00000001) != 0
	verbose_trackerpack = (byte & 0b00000010) != 0
	hide_finished_map_squares = (byte & 0b00000100) != 0
func _save_cfg(file: FileAccess):
	var byte = 0
	if is_tracking: byte |= 0b00000001
	if verbose_trackerpack: byte |= 0b00000010
	if hide_finished_map_squares: byte |= 0b00000100
	file.store_8(byte)
