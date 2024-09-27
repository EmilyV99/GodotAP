@tool class_name ConsoleContainer extends VBoxContainer

@onready var console_cont = $Cont
@onready var console: BaseConsole = $Cont/ConsoleMargin/Row/Console
var typing_bar: TypingBar = null

func _ready():
	sort_children.connect(update_cont_size)
	typing_bar = get_node_or_null("TypingBar")

func update_cont_size():
	var console_size = size
	var bar_height = typing_bar.calc_height() if typing_bar and typing_bar.visible else 0.0
	console_size.y -= bar_height

	if typing_bar:
		fit_child_in_rect(typing_bar, Rect2(Vector2(0,console_size.y),Vector2(size.x,bar_height)))
	fit_child_in_rect(console_cont, Rect2(Vector2.ZERO,console_size))
