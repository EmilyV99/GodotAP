@tool class_name ConsoleWindow extends Window

@onready var cont = $Container
@onready var console = $Container/Console
# Called when the node enters the scene tree for the first time.
func _ready():
	size_changed.connect(update_cont_size)
	update_cont_size()

func update_cont_size():
	cont.custom_minimum_size = size
	console.queue_redraw()

func _on_close_requested():
	queue_free()
