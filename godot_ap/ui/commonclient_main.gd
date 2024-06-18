extends ColorRect
## Directly opens the CommonClient Console in the current SceneTree
## Used for standalone client applications

func _ready():
	Archipelago.AP_CLIENT_VERSION = Version.val(0,0,2) # GodotAP CommonClient version
	Archipelago.set_tags(["TextOnly"])
	Archipelago.AP_ITEM_HANDLING = Archipelago.ItemHandling.ALL
	
	if Archipelago.output_console:
		Archipelago.close_console()
	get_window().min_size = Vector2(750,400)
	get_window().title = "AP Text Client"
	Archipelago.load_packed_console_as_scene(get_tree(), load("res://godot_ap/ui/commonclient_console.tscn"))

