@tool class_name TypingBar extends LineEdit

@export var clear_text_on_send := true
@export var store_history := true
@export var disabled := false :
	set(val):
		disabled = val
		editable = not val
		if val: _unfocus()
		queue_redraw()
		focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL

@export_group("Nodes")
@export var autofill_rect: StringBar
@export var autofill_edit: LineEdit
@export_group("")

var cmd_manager: CommandManager = null

const VMARGIN: float = 6
const HMARGIN: float = 6
const AUTOFILL_HMARGIN: float = 30

func calc_height() -> float:
	return get_theme_font("font").get_height(get_theme_font_size("font_size")) + (2*VMARGIN)

signal send_text(msg: String)

var had_focus := false
var _tab_completions: Array[String] = []

var _history: Array[String] = []
var _hist_indx := 0
func history_step(by: int) -> void:
	if not store_history: return
	if by == 0 or (_hist_indx >= _history.size() if by > 0 else _hist_indx <= 0):
		return
	_hist_indx = clamp(_hist_indx+by, 0, _history.size())
	if _hist_indx < _history.size():
		update_text(_history[_hist_indx])
	else:
		update_text("")
func history_add(s: String) -> void:
	if not store_history: return
	if _history.is_empty() or s != _history.back():
		_history.append(s)
	_hist_indx = _history.size()
func history_clear() -> void:
	_history.clear()
	_hist_indx = 0

func _ready():
	if not Engine.is_editor_hint():
		# Connect focus
		focus_entered.connect(_focus)
		focus_exited.connect(_unfocus)
		text_submitted.connect(_submit_text)
		text_changed.connect(update.unbind(1))
		show_bar(visible)

	custom_minimum_size.y = calc_height()
	await get_tree().process_frame
	autofill_rect.position = Vector2(AUTOFILL_HMARGIN, 0)
	autofill_rect.size = Vector2(size.x - 2*AUTOFILL_HMARGIN, 0)
	autofill_rect.clicked.connect(func(indx: int):
		update_text(_tab_completions[indx]))

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if disabled or not visible: return
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_TAB:
					if _tab_completions:
						update_text(_tab_completions[0])
					accept_event()
				KEY_UP:
					history_step(-1)
					accept_event()
				KEY_DOWN:
					history_step(1)
					accept_event()

func update() -> void:
	if cmd_manager:
		if had_focus:
			_tab_completions.assign(cmd_manager.autofill(text, 10))
			if _tab_completions and _tab_completions[0] == text:
				_tab_completions.clear()
		else:
			_tab_completions.clear()
		autofill_rect.set_strings(_tab_completions)

		if _tab_completions:
			autofill_edit.text = _tab_completions[0]
		else:
			autofill_edit.text = ""

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

func show_bar(state: bool) -> void:
	visible = state
	focus_mode = Control.FOCUS_ALL if state else Control.FOCUS_NONE

func _submit_text(submitted_text: String) -> void:
	history_add(submitted_text)
	send_text.emit(submitted_text)
	if clear_text_on_send:
		update_text("")

func update_text(new_text: String) -> void:
	text = new_text
	caret_column = text.length()
	update()
