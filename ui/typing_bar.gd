class_name TypingBar extends ColorRect

@export var font: Font
@export var font_size: int = 20
@export var text_color: Color = Color.WHITE
@export var blink_rate: float = 0.5

const MARGIN: float = 4

var had_focus := false
var showing_cursor := false :
	set(val):
		if not had_focus:
			val = false
		if showing_cursor != val:
			showing_cursor = val
			queue_redraw()
func _ready():
	focus_entered.connect(_focus)
	focus_exited.connect(_unfocus)
	size.y = font.get_height(font_size)+2*MARGIN
	# Blink the cursor
	var timer = Timer.new()
	add_child(timer)
	timer.one_shot = false
	timer.wait_time = blink_rate
	timer.timeout.connect(func():
		showing_cursor = not showing_cursor)
	timer.start()

func _draw():
	var x = MARGIN
	var y = MARGIN
	var h = font.get_height(font_size)
	if had_focus and showing_cursor:
		draw_rect(Rect2(x,y,2,h), text_color)

func _focus():
	if not had_focus:
		had_focus = true
		queue_redraw()
func _unfocus():
	if had_focus:
		had_focus = false
		queue_redraw()
