@tool class_name ConsoleLabel extends Label

static var _scene := preload("res://godot_ap/ui/console/console_label.tscn") as PackedScene

signal clicked(index: MouseButton)
signal changed_rich_color(color: AP.RichColor)

func _get_color() -> Color:
	return AP.get_rich_color(self, rich_color)

var bold: bool = false :
	set(val):
		if bold == val: return
		bold = val
		_notification(NOTIFICATION_THEME_CHANGED)
var italic: bool = false :
	set(val):
		if italic == val: return
		italic = val
		_notification(NOTIFICATION_THEME_CHANGED)
var wrapping: bool = true :
	set(val):
		if wrapping == val: return
		wrapping = val
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if val:
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		refresh()
var rich_color := AP.RichColor.NIL : set = set_rich_color, get = get_rich_color
var color_override := ""

func get_rich_color() -> AP.RichColor:
	return rich_color
func set_rich_color(c: AP.RichColor) -> void:
	rich_color = c
	refresh()
	changed_rich_color.emit(c)

func _init() -> void:
	theme_type_variation = "Console_Label"
	color_override = ""
	_notification(NOTIFICATION_THEME_CHANGED)

func _ready() -> void:
	refresh()
func _process(_delta) -> void:
	refresh()
func refresh() -> void:
	if color_override.is_empty():
		if rich_color == AP.RichColor.NIL:
			if has_theme_color_override("font_color"):
				remove_theme_color_override("font_color")
				queue_redraw()
		elif (not has_theme_color_override("font_color") or
			get_theme_color("font_color") != _get_color()):
			add_theme_color_override("font_color", _get_color())
			queue_redraw()
	else:
		var c := AP.color_from_name(self, color_override)
		if get_theme_color("font_color") != c:
			add_theme_color_override("font_color", c)
			queue_redraw()

	var minsz := Vector2()
	if not wrapping:
		minsz = get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size"))
		if global_position.x + minsz.x > _parent_global_rect.end.x:
			minsz.x = _parent_global_rect.end.x - global_position.x
		if global_position.y + minsz.y > _parent_global_rect.end.y:
			minsz.y = _parent_global_rect.end.y - global_position.y
	if not minsz.is_equal_approx(custom_minimum_size):
		custom_minimum_size = minsz
func set_content(new_text: String, new_ttip := "") -> void:
	text = new_text
	tooltip_text = new_ttip

static func make(txt: String, ttip := "") -> ConsoleLabel:
	var ret := _scene.instantiate()
	ret.set_content(txt, ttip)
	return ret

static func make_rich(txt: String, col: AP.RichColor, ttip := "") -> ConsoleLabel:
	var ret := make(txt, ttip)
	ret.rich_color = col
	return ret
static func make_special(txt: String, col: AP.SpecialColor, ttip := "") -> ConsoleLabel:
	var ret := make(txt, ttip)
	ret.rich_color = AP.special_to_rich_color(col, ret.rich_color)
	return ret
static func make_custom(txt: String, col, ttip := "") -> ConsoleLabel:
	var ret := make(txt, ttip)
	ret.color_override = str(col)
	return ret
static func make_col(txt: String, col: AP.ComplexColor, ttip := "") -> ConsoleLabel:
	if col == null:
		return make(txt, ttip)
	if col.rich != null:
		return make_rich(txt, col.rich, ttip)
	if col.special != null:
		return make_special(txt, col.special, ttip)
	return make_custom(txt, col.plain, ttip)
func set_color(col: AP.ComplexColor) -> void:
	color_override = ""
	if col.rich:
		rich_color = col.rich
	elif col.special:
		rich_color = AP.special_to_rich_color(col.special)
	else:
		color_override = str(col.plain)

var __theme_changing: bool = false
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not __theme_changing:
		__theme_changing = true
		remove_theme_font_override("font")
		if BaseConsole.console_label_fonts and (bold or italic):
			add_theme_font_override("font", BaseConsole.console_label_fonts.get_font(bold, italic))
		refresh()
		__theme_changing = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			clicked.emit(event.button_index)
			accept_event()

func centered() -> ConsoleLabel:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return self

var _parent_global_rect: Rect2
func handle_sizing(parent: Control) -> void:
	_parent_global_rect = parent.get_global_rect()
	if parent is HFlowContainer:
		wrapping = false
	if (global_position.x + custom_minimum_size.x > _parent_global_rect.end.x or
		global_position.y + custom_minimum_size.y > _parent_global_rect.end.y):
		refresh()

func make_dupe() -> ConsoleLabel:
	var dupe: ConsoleLabel = duplicate()
	dupe.text = ""
	dupe.rich_color = rich_color
	dupe.bold = bold
	dupe.italic = italic
	dupe.wrapping = wrapping
	return dupe
