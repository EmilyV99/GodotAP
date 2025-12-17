class_name APConfigManager extends Node

@warning_ignore("unused_signal")
signal config_changed
const CFG_VERSION: int = 1
const CONFIG_HEADER := "GodotAP Settings File"

var _pause_saving := false
var is_tracking := false :
	set(val):
		if val != is_tracking:
			is_tracking = val
			save_cfg()
			config_changed.emit()
var verbose_trackerpack := false :
	set(val):
		if val != verbose_trackerpack:
			verbose_trackerpack = val
			save_cfg()
			config_changed.emit()
var hide_finished_map_squares := false :
	set(val):
		if val != hide_finished_map_squares:
			hide_finished_map_squares = val
			save_cfg()
			config_changed.emit()
var window_theme_path: String :
	set(val):
		if val != window_theme_path:
			window_theme_path = val
			save_cfg()
			config_changed.emit()
var uuid: String :
	set(val):
		if val != uuid:
			uuid = val
			save_cfg()
			config_changed.emit()

static func generate_uuid() -> String:
	var ret := ""
	for q in 8:
		ret += String.num_int64(randi_range(0, 16), 16, true)
	ret += "-"
	for q in 4:
		ret += String.num_int64(randi_range(0, 16), 16, true)
	ret += "-"
	ret += "4" # '4' for uuid v4
	for q in 3:
		ret += String.num_int64(randi_range(0, 16), 16, true)
	ret += "-"
	ret += String.num_int64(randi_range(8, 12), 16, true) # 8, 9, A, B only
	for q in 3:
		ret += String.num_int64(randi_range(0, 16), 16, true)
	ret += "-"
	for q in 12:
		ret += String.num_int64(randi_range(0, 16), 16, true)
	return ret

func _ready():
	load_cfg()
	if not uuid:
		uuid = generate_uuid()

func load_cfg() -> bool:
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.READ)
	if not file:
		return false
	_pause_saving = true
	var ret := _load_cfg(file)
	file.close()
	_pause_saving = false
	return ret
func save_cfg() -> void:
	if _pause_saving: return
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var file: FileAccess = FileAccess.open("user://ap/settings.dat", FileAccess.WRITE)
	_save_cfg(file)
	file.close()

func _load_cfg(file: FileAccess) -> bool:
	if file.get_pascal_string() != CONFIG_HEADER:
		return false
	var vers := file.get_32()
	# all versions
	var byte := file.get_8()
	is_tracking = (byte & 0b00000001) != 0
	verbose_trackerpack = (byte & 0b00000010) != 0
	hide_finished_map_squares = (byte & 0b00000100) != 0
	window_theme_path = file.get_pascal_string()
	if vers >= 1:
		uuid = file.get_pascal_string()
	return true
func _save_cfg(file: FileAccess):
	file.store_pascal_string(CONFIG_HEADER)
	file.store_32(CFG_VERSION)
	var byte = 0
	if is_tracking: byte |= 0b00000001
	if verbose_trackerpack: byte |= 0b00000010
	if hide_finished_map_squares: byte |= 0b00000100
	file.store_8(byte)
	file.store_pascal_string(window_theme_path)
	# CFG_VERSION >= 1
	file.store_pascal_string(uuid)
