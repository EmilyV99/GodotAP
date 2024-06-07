@tool class_name ConsoleWindow extends Window

@onready var bg = $BG
@onready var console_margin = $ConsoleMargin
@onready var console = $ConsoleMargin/Console
@onready var typing_bar = $TypingBar
# Called when the node enters the scene tree for the first time.
func _ready():
	size_changed.connect(update_cont_size)
	update_cont_size()
	console_margin.grab_focus()

func update_cont_size():
	bg.size = size*2
	var console_size = size
	
	typing_bar.size.x = size.x
	console_size.y -= typing_bar.size.y
	typing_bar.position.y = size.y - typing_bar.size.y
	
	console_margin.custom_minimum_size = console_size
	console_margin.reset_size()

func _on_close_requested():
	queue_free()
