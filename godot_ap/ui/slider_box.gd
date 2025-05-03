class_name SliderBox extends MarginContainer

@export var total_slide_dur: float = 0.5
@onready var row: HBoxContainer = $Row
@onready var handle: Control = $Row/Handle
@onready var handle_label: CustomLabel = $Row/Handle/Margin/CustomLabel
@onready var box: Control = $Row/Box
@onready var connect_btn: Button = $Row/Box/Margins/VBox/ButtonRow/ConnectBtn
@onready var disconnect_btn: Button = $Row/Box/Margins/VBox/ButtonRow/DisconnectBtn
var is_open := false :
	set(val):
		if is_open != val:
			is_open = val
			handle_label.text = "🞂" if is_open else "🞀"
var _slide_tween: Tween = null
func _ready():
	handle.gui_input.connect(_button_input)
	row.custom_minimum_size.x = handle.size.x + box.size.x
	row.custom_minimum_size.y = max(handle.size.y, box.size.y)
	row.add_theme_constant_override("separation", 0)
	row.reset_size()
	custom_minimum_size = Vector2.ZERO
	reset_size()
	Archipelago.connected.connect(func(_conn, _json):
		connect_btn.disabled = true
		disconnect_btn.disabled = false
		if Archipelago.AP_CONSOLE_CONNECTION_AUTO:
			slide_to(false))
	Archipelago.disconnected.connect(func():
		connect_btn.disabled = false
		disconnect_btn.disabled = true
		if Archipelago.AP_CONSOLE_CONNECTION_AUTO:
			slide_to(true))
	if Archipelago.AP_CONSOLE_CONNECTION_AUTO or Archipelago.AP_CONSOLE_CONNECTION_OPEN:
		is_open = true
	_set_open_x(0 if is_open else (box.size.x as int))

func slide_to(open: bool) -> void:
	if open == is_open: return
	is_open = open
	_slide()

func _set_open_x(x: int) -> void:
	add_theme_constant_override("margin_left", x)
	add_theme_constant_override("margin_right", -x)
	queue_sort()

func _slide():
	var x: int = get_theme_constant("margin_left")
	var w: int = ceili(box.size.x)
	var targ_x: int = 0 if is_open else w
	var dur: float = total_slide_dur * absf(x - targ_x) / w
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_method(_set_open_x, x, targ_x, dur)
func _button_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			slide_to(not is_open)

func get_closed_width() -> float:
	return handle.size.x
