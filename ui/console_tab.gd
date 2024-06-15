class_name ConsoleTab extends VBoxContainer

@onready var console_cont = $Cont
@onready var console: BaseConsole = $Cont/ConsoleMargin/Console
@onready var typing_bar = $TypingBar

func _ready():
	sort_children.connect(update_cont_size)
	

func update_cont_size():
	assert(typing_bar)
	var console_size = size
	var bar_height = typing_bar.calc_height()
	console_size.y = console_size.y - bar_height
	
	fit_child_in_rect(typing_bar, Rect2(Vector2(0,console_size.y),Vector2(size.x,bar_height)))
	fit_child_in_rect(console_cont, Rect2(Vector2.ZERO,console_size))
