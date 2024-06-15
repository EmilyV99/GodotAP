extends ColorRect
## Directly opens the CommonClient Console in the current SceneTree
## Used for standalone client applications

func _ready():
	if Archipelago.output_console:
		Archipelago.close_console()
	get_window().min_size = Vector2(400,400)
	get_window().title = "AP Text Client"
	Archipelago.load_packed_console_as_scene(get_tree(), load("res://ui/commonclient_console.tscn"))

