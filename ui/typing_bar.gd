@tool class_name TypingBar extends ColorRect

@export var font: Font
@export var font_size: int = 20
@export var color_text: Color = Color.WHITE
@export var color_autofill: Color = Color(Color.DARK_GRAY,.5)
@export var blink_rate: float = 0.5

var autofill: AutofillHandler = null
var autofill_rect: StringBar

const VMARGIN: float = 4
const HMARGIN: float = 6
const AUTOFILL_HMARGIN: float = 30

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
var _tab_completions: Array[String] = []
func _ready():
	size.y = font.get_height(font_size)+2*VMARGIN
	if not Engine.is_editor_hint():
		# Connect focus
		focus_entered.connect(_focus)
		focus_exited.connect(_unfocus)
		# Blink the cursor
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = false
		timer.wait_time = blink_rate
		timer.timeout.connect(func():
			showing_cursor = not showing_cursor)
		timer.start()
	# Add autofill rect
	autofill_rect = load("res://ui/stringbar.tscn").instantiate()
	add_child(autofill_rect)
	autofill_rect.position.y = 0
	autofill_rect.clicked.connect(func(indx: int):
		auto_complete(_tab_completions[indx]))

func _draw():
	var h = font.get_height(font_size)
	var pre_pos_text = text.substr(0, text_pos)
	if _tab_completions:
		draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), _tab_completions[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_autofill)
		if _tab_completions.size() > 1:
			autofill_rect.position.x = AUTOFILL_HMARGIN
			autofill_rect.size.x = get_parent().size.x - 2*AUTOFILL_HMARGIN
			autofill_rect.queue_redraw()
	draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_text)
	if had_focus and showing_cursor:
		var pre_w := font.get_string_size(pre_pos_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,2,h), color_text)

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventKey:
		if event.pressed:
			var updated_text := false
			match event.keycode:
				KEY_BACKSPACE:
					if text_pos > 0:
						text = text.substr(0,text_pos-1) + text.substr(text_pos)
						text_pos -= 1
						updated_text = true
				KEY_DELETE:
					if text_pos < text.length():
						text = text.substr(0,text_pos) + text.substr(text_pos+1)
						updated_text = true
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
				KEY_ENTER, KEY_KP_ENTER:
					send_text.emit(text)
					text = ""
					text_pos = 0
					updated_text = true
				KEY_TAB:
					if _tab_completions:
						text = _tab_completions[0]
						text_pos = text.length()
						updated_text = true
				_:
					var c = char(event.unicode)
					if c:
						text = text.substr(0,text_pos) + c + text.substr(text_pos)
						text_pos += 1
						updated_text = true
			if updated_text:
				update()

func update():
	if autofill:
		_tab_completions.assign(autofill.autofill(text))
		if _tab_completions and _tab_completions[0] == text:
			_tab_completions.clear()
		autofill_rect.set_strings(_tab_completions)

func auto_complete(msg: String):
	text = msg
	text_pos = text.length()
	update()

func _focus():
	if Engine.is_editor_hint(): return
	if not had_focus:
		had_focus = true
		queue_redraw()
func _unfocus():
	if Engine.is_editor_hint(): return
	if had_focus:
		had_focus = false
		queue_redraw()
