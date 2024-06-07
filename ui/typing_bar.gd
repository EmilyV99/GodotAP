class_name TypingBar extends ColorRect

@export var font: Font
@export var font_size: int = 20
@export var text_color: Color = Color.WHITE
@export var blink_rate: float = 0.5

const VMARGIN: float = 4
const HMARGIN: float = 6

signal send_text(msg: String)

var text := "" :
	set(val):
		text = val
		queue_redraw()
var text_pos := 0 :
	set(val):
		text_pos = val
		queue_redraw()
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
	size.y = font.get_height(font_size)+2*VMARGIN
	# Blink the cursor
	var timer = Timer.new()
	add_child(timer)
	timer.one_shot = false
	timer.wait_time = blink_rate
	timer.timeout.connect(func():
		showing_cursor = not showing_cursor)
	timer.start()

func _draw():
	var h = font.get_height(font_size)
	var pre_pos_text = text.substr(0, text_pos)
	draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if had_focus and showing_cursor:
		var pre_w := font.get_string_size(pre_pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,2,h), text_color)

func _gui_input(event):
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_BACKSPACE:
					if text_pos > 0:
						text = text.substr(0,text_pos-1) + text.substr(text_pos)
						text_pos -= 1
				KEY_DELETE:
					if text_pos < text.length():
						text = text.substr(0,text_pos) + text.substr(text_pos+1)
				KEY_LEFT:
					if text_pos:
						text_pos -= 1
				KEY_RIGHT:
					if text_pos < text.length():
						text_pos += 1
				KEY_HOME:
					text_pos = 0
				KEY_END:
					text_pos = text.length()-1
				KEY_ENTER:
					send_text.emit(text)
					text = ""
					text_pos = 0
				_:
					var c = char(event.unicode)
					if c:
						text = text.substr(0,text_pos) + c + text.substr(text_pos)
						text_pos += 1

func _focus():
	if not had_focus:
		had_focus = true
		queue_redraw()
func _unfocus():
	if had_focus:
		had_focus = false
		queue_redraw()
