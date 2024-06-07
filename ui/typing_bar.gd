@tool class_name TypingBar extends ColorRect

@export var font: Font
@export var font_size: int = 20
@export var color_text: Color = Color.WHITE
@export var color_highlight: Color = Color.DIM_GRAY
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
var had_focus := false
var mouse_down := false
var showing_cursor := false :
	set(val):
		if not had_focus:
			val = false
		if showing_cursor != val:
			showing_cursor = val
			queue_redraw()
var _tab_completions: Array[String] = []

var text_pos := 0 :
	set(val):
		text_pos = val
		queue_redraw()
var text_pos2 := 0 :
	set(val):
		text_pos2 = val
		queue_redraw()
var low_pos: int :
	get: return min(text_pos,text_pos2)
	set(_val): assert(false)
var high_pos: int :
	get: return max(text_pos,text_pos2)
	set(_val): assert(false)

func has_select() -> bool:
	return had_focus and text_pos != text_pos2

func clear_select() -> void:
	text_pos2 = text_pos

func sel_text() -> String:
	return text.substr(low_pos,high_pos-low_pos)

func type(s: String) -> void:
	var t := text.substr(0,low_pos) + s
	text = t + text.substr(high_pos)
	text_pos = t.length()
	clear_select()

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

func _process(_delta):
	update_mouse()

func _draw():
	if _tab_completions:
		draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), _tab_completions[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_autofill)
		if _tab_completions.size() > 1:
			autofill_rect.position.x = AUTOFILL_HMARGIN
			autofill_rect.size.x = get_parent().size.x - 2*AUTOFILL_HMARGIN
			autofill_rect.queue_redraw()
	var h = font.get_height(font_size)
	var pre_w := font.get_string_size(text.substr(0, low_pos), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if had_focus and has_select():
		var rw = font.get_string_size(text.substr(0, high_pos), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - pre_w
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,rw,h), color_highlight)
	draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_text)
	if had_focus and showing_cursor:
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,2.0,h), color_highlight)

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var new_sel: bool = event.pressed and not mouse_down and not Input.is_key_pressed(KEY_SHIFT)
			var o1 := text_pos
			var o2 := text_pos2
			mouse_down = event.pressed
			update_mouse()
			if new_sel: # Clear selection on first click if shift not held
				text_pos = text_pos2
			else: # Order it to select cleaner
				if abs(o1-text_pos2) > abs(o2-text_pos2):
					text_pos = o1
				else:
					text_pos = o2
	elif event is InputEventKey:
		if event.pressed:
			var updated_text := false
			var moved_pos := true
			match event.keycode:
				KEY_BACKSPACE:
					if has_select():
						type("")
					elif text_pos > 0:
						text_pos2 -= 1
						type("")
						updated_text = true
				KEY_DELETE:
					if has_select():
						type("")
					elif text_pos < text.length():
						text_pos2 += 1
						type("")
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
					text_pos = text.length()
				KEY_ENTER, KEY_KP_ENTER:
					send_text.emit(text)
					text = ""
					text_pos = 0
					clear_select()
					updated_text = true
				KEY_TAB:
					if _tab_completions:
						text = _tab_completions[0]
						text_pos = text.length()
						clear_select()
						updated_text = true
				KEY_ESCAPE:
					clear_select()
				_:
					var did_something := false
					if event.ctrl_pressed:
						did_something = true
						match event.keycode:
							KEY_A:
								text_pos = 0
								text_pos2 = text.length()
								moved_pos = false
							KEY_C:
								moved_pos = false
								if has_select():
									DisplayServer.clipboard_set(sel_text())
							KEY_X:
								moved_pos = false
								if has_select():
									DisplayServer.clipboard_set(sel_text())
									type("")
							KEY_V:
								if had_focus and DisplayServer.clipboard_has():
									type(DisplayServer.clipboard_get())
									updated_text = true
							_:
								did_something = false
					if not did_something:
						var c = char(event.unicode)
						if c:
							type(c)
							updated_text = true
						else: moved_pos = false
			if moved_pos and not event.shift_pressed:
				clear_select()
			if updated_text:
				update()

func update() -> void:
	if autofill:
		_tab_completions.assign(autofill.autofill(text))
		if _tab_completions and _tab_completions[0] == text:
			_tab_completions.clear()
		autofill_rect.set_strings(_tab_completions)
func update_mouse() -> void:
	if not mouse_down: return
	var pos := get_viewport().get_mouse_position() + Util.MOUSE_OFFSET - global_position
	var found := text.length()
	for q in text.length():
		if font.get_string_size(text.substr(0, q+1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x >= pos.x:
			found = q
			break
	text_pos2 = found
	
func auto_complete(msg: String):
	text = msg
	text_pos = text.length()
	clear_select()
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
