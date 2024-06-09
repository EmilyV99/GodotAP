@tool extends VBoxContainer

@onready var console_margin = $ConsoleMargin
@onready var typing_bar = $TypingBar

func _ready():
	#pre_sort_children.connect(update_cont_size)
	sort_children.connect(update_cont_size)
	

func update_cont_size():
	var console_size = size
	var bar_height = typing_bar.calc_height()
	console_size.y = console_size.y - bar_height
	
	fit_child_in_rect(typing_bar, Rect2(Vector2(0,console_size.y),Vector2(size.x,bar_height)))
	fit_child_in_rect(console_margin, Rect2(Vector2.ZERO,console_size))
