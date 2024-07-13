@tool class_name TypingBar extends Control

@export var font: Font :
	set(val):
		font = val
		custom_minimum_size.y = calc_height()
		reset_size()
@export var font_size: int = 20
@export var color_text: Color = Color.WHITE
@export var color_dis_text: Color = Color.SLATE_GRAY
@export var color_highlight: Color = Color.DIM_GRAY
@export var color_autofill: Color = Color(Color.DARK_GRAY,.5)
@export var color_bg: Color = Color8(0x25,0x25,0x25)
@export var color_dis_bg: Color = Color8(0x25,0x25,0x25)
@export var blink_rate: float = 0.5
@export var clear_text_on_send := true
@export var store_history := true
@export var disabled := false :
	set(val):
		if disabled != val:
			queue_redraw()
			disabled = val
			focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
@export var pwd_mode := false :
	set(val):
		if pwd_mode != val:
			pwd_mode = val
			queue_redraw()

var cmd_manager: CommandManager = null
var autofill_rect: StringBar

const VMARGIN: float = 6
const HMARGIN: float = 6
const AUTOFILL_HMARGIN: float = 30

func calc_height() -> float:
	return font.get_height(font_size) + (2*VMARGIN)

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

var _history: Array[String] = []
var _hist_indx := 0
func history_step(by: int) -> void:
	if not store_history: return
	if by == 0 or (_hist_indx >= _history.size() if by > 0 else _hist_indx <= 0):
		return
	_hist_indx = clamp(_hist_indx+by, 0, _history.size())
	if _hist_indx < _history.size():
		retype(_history[_hist_indx])
	else:
		retype("")
func history_add(s: String) -> void:
	if not store_history: return
	if _history.is_empty() or s != _history.back():
		_history.append(s)
	_hist_indx = _history.size()
func history_clear() -> void:
	_history.clear()
	_hist_indx = 0
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
func retype(s: String) -> void:
	text = s
	text_pos = text.length()
	clear_select()

func _ready():
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
		show_bar(visible)
	# Add autofill rect
	autofill_rect = load("res://godot_ap/ui/stringbar.tscn").instantiate()
	add_child(autofill_rect)
	autofill_rect.position.y = 0
	autofill_rect.clicked.connect(func(indx: int):
		auto_complete(_tab_completions[indx]))
	custom_minimum_size.y = calc_height()
func _process(_delta):
	update_mouse()

func _draw():
	var draw_text: String = text
	if pwd_mode:
		draw_text = "*".repeat(draw_text.length())
	if disabled: _unfocus()
	draw_rect(Rect2(Vector2.ZERO, size), color_dis_bg if disabled else color_bg)
	if _tab_completions and had_focus:
		draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), _tab_completions[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_autofill)
		if _tab_completions.size() > 1:
			autofill_rect.position.x = AUTOFILL_HMARGIN
			autofill_rect.position.y = 0
			autofill_rect.size.x = size.x - 2*AUTOFILL_HMARGIN
			autofill_rect.size.y = 0
			autofill_rect.queue_redraw()
	var h = font.get_height(font_size)
	var pre_w := font.get_string_size(draw_text.substr(0, low_pos), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if had_focus and has_select():
		var rw = font.get_string_size(draw_text.substr(0, high_pos), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - pre_w
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,rw,h), color_highlight)
		
	draw_string(font, Vector2(HMARGIN,VMARGIN+font.get_ascent(font_size)), draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color_dis_text if disabled else color_text)
	if had_focus and showing_cursor:
		draw_rect(Rect2(HMARGIN+pre_w-1,VMARGIN,2.0,h), color_highlight)

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if disabled or not visible: return
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
						if event.is_command_or_control_pressed():
							var ws := RegEx.new()
							ws.compile("^[ \t\r\n]+$")
							var alphanum := RegEx.new()
							alphanum.compile("^[a-zA-Z0-9_]+$")
							var other := RegEx.new()
							other.compile("^[^ \t\r\na-zA-Z0-9_]+$")
							for reg in [ws, alphanum, other]:
								if reg.search(text[text_pos-1]):
									while text_pos2 > 0 and reg.search(text[text_pos2-1]):
										text_pos2 -= 1
									break
						else:
							text_pos2 -= 1
						type("")
						updated_text = true
				KEY_DELETE:
					if has_select():
						type("")
					elif text_pos < text.length():
						if event.is_command_or_control_pressed():
							var ws := RegEx.new()
							ws.compile("^[ \t\r\n]+$")
							var alphanum := RegEx.new()
							alphanum.compile("^[a-zA-Z0-9_]+$")
							var other := RegEx.new()
							other.compile("^[^ \t\r\na-zA-Z0-9_]+$")
							for reg in [ws, alphanum, other]:
								if reg.search(text[text_pos]):
									while text_pos2 < text.length() and reg.search(text[text_pos2]):
										text_pos2 += 1
									break
						else:
							text_pos2 += 1
						type("")
						updated_text = true
				KEY_LEFT:
					if text_pos:
						if event.is_command_or_control_pressed():
							var ws := RegEx.new()
							ws.compile("^[ \t\r\n]+$")
							var alphanum := RegEx.new()
							alphanum.compile("^[a-zA-Z0-9_]+$")
							var other := RegEx.new()
							other.compile("^[^ \t\r\na-zA-Z0-9_]+$")
							for reg in [ws, alphanum, other]:
								if reg.search(text[text_pos-1]):
									while text_pos > 0 and reg.search(text[text_pos-1]):
										text_pos -= 1
									break
						else:
							text_pos -= 1
				KEY_RIGHT:
					if text_pos < text.length():
						if event.is_command_or_control_pressed():
							var ws := RegEx.new()
							ws.compile("^[ \t\r\n]+$")
							var alphanum := RegEx.new()
							alphanum.compile("^[a-zA-Z0-9_]+$")
							var other := RegEx.new()
							other.compile("^[^ \t\r\na-zA-Z0-9_]+$")
							for reg in [ws, alphanum, other]:
								if reg.search(text[text_pos]):
									while text_pos < text.length() and reg.search(text[text_pos]):
										text_pos += 1
									break
						else:
							text_pos += 1
				KEY_UP:
					history_step(-1)
					updated_text = true
				KEY_DOWN:
					history_step(1)
					updated_text = true
				KEY_HOME:
					text_pos = 0
				KEY_END:
					text_pos = text.length()
				KEY_ENTER, KEY_KP_ENTER:
					history_add(text)
					send_text.emit(text)
					if clear_text_on_send:
						text = ""
						text_pos = 0
						clear_select()
						updated_text = true
				KEY_TAB:
					if _tab_completions:
						auto_complete(_tab_completions[0])
						updated_text = true
				KEY_ESCAPE:
					clear_select()
				_:
					var did_something := false
					if event.is_command_or_control_pressed():
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
	if cmd_manager:
		if had_focus:
			_tab_completions.assign(cmd_manager.autofill(text, 10))
			if _tab_completions and _tab_completions[0] == text:
				_tab_completions.clear()
		else:
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
	if disabled or not visible: return _unfocus()
	if not had_focus:
		had_focus = true
		update()
		queue_redraw()
func _unfocus():
	if Engine.is_editor_hint(): return
	if had_focus:
		had_focus = false
		update()
		queue_redraw()

func set_pwd_mode(state: bool) -> void:
	pwd_mode = state
func set_show_pwd(state: bool) -> void:
	pwd_mode = not state

func show_bar(state: bool) -> void:
	visible = state
	focus_mode = Control.FOCUS_ALL if state else Control.FOCUS_NONE
