class_name CommonClientMain extends ColorRect
## Directly opens the CommonClient Console in the current SceneTree
## Used for standalone client applications

func _ready():
	if OS.is_debug_build():
		Archipelago.cmd_manager.debug_hidden = false

	Archipelago.AP_CLIENT_VERSION = Version.val(0,1,0) # GodotAP CommonClient version
	AP.log(Archipelago.AP_CLIENT_VERSION)
	Archipelago.set_tags(["TextOnly"])
	Archipelago.AP_ITEM_HANDLING = Archipelago.ItemHandling.ALL
	Archipelago.creds.updated.connect(CommonClientMain.save_connection)
	CommonClientMain.load_connection()

	if Archipelago.output_console:
		Archipelago.close_console()
	get_window().min_size = Vector2(750,400)
	get_window().title = "AP Text Client"
	Archipelago.load_packed_console_as_scene(get_tree(), load("res://godot_ap/ui/common_client.tscn"))

static func load_connection():
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.READ)
	if not conn_info_file: return
	var ip = conn_info_file.get_line()
	var port = conn_info_file.get_line()
	var slot = conn_info_file.get_line()
	Archipelago.creds.update(ip, port, slot, "")
	conn_info_file.close()
static func save_connection(creds: APCredentials):
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.WRITE)
	if not conn_info_file: return
	conn_info_file.store_line(creds.ip)
	conn_info_file.store_line(creds.port)
	conn_info_file.store_line(creds.slot)
	conn_info_file.close()
