@tool class_name CustomConsole extends Control

class FontFlags:
	var bold := false
	var italic := false

@export var font: SystemFont :
	set(val):
		font = val
		font_bold = null
		queue_redraw()
@export var font_size: int = 20 :
	set(val):
		font_size = val
		queue_redraw()
@export var font_color: Color = Color.WHITE :
	set(val):
		font_color = val
		queue_redraw()
@export var SCROLL_MULT: float = 3
@export var SPACING = 0 :
	set(val):
		SPACING = val
		queue_redraw()

signal send_text(msg: String)

var font_bold: SystemFont :
	get:
		if font_bold: return font_bold
		font_bold = font.duplicate()
		font_bold.font_weight *= 2
		return font_bold
var font_italic: SystemFont :
	get:
		if font_italic: return font_italic
		font_italic = font.duplicate()
		font_italic.font_italic = true
		return font_italic
var font_bold_italic: SystemFont :
	get:
		if font_bold_italic: return font_bold_italic
		font_bold_italic = font.duplicate()
		font_bold_italic.font_italic = true
		font_bold_italic.font_weight *= 2
		return font_bold_italic

func get_font(flags: FontFlags) -> Font:
	if flags.bold:
		if flags.italic:
			return font_bold_italic
		else: return font_bold
	elif flags.italic:
		return font_italic
	else: return font
func get_font_height(flags: FontFlags) -> float:
	return get_font(flags).get_height(font_size)
func get_line_height() -> float:
	var h := 0.0
	for f in [font,font_bold,font_italic,font_bold_italic]:
		h = maxf(h,f.get_height(font_size))
	return SPACING+h
func get_font_ascent(flags: FontFlags) -> float:
	return get_font(flags).get_ascent(font_size)
func get_string_size(text: String, flags: FontFlags) -> Vector2:
	return get_font(flags).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

@onready var tooltip_bg: ColorRect = $TooltipBG
@onready var tooltip_label: Label = $TooltipBG/Tooltip
class ConsoleDrawData:
	var l: float
	var t: float
	var r: float
	var b: float
	var x: float
	var y: float
	var w: float:
		get:
			return r-l
	var h: float:
		get:
			return b-t
	var cx: float:
		get:
			return l + w/2
	var cy: float:
		get:
			return t + h/2
	var max_shown_y: float = 0.0
	func show_y(ty: float) -> void:
		ty -= t
		if ty > max_shown_y:
			max_shown_y = ty;
	func max_scroll() -> float:
		var s := max_shown_y - b
		return 0.0 if s <= 0 else s
class ConsolePart:
	func draw(_c: CustomConsole, _data: ConsoleDrawData) -> void:
		pass
	func draw_hover(_c: CustomConsole, _data: ConsoleDrawData) -> void:
		pass
	func needs_hover() -> bool:
		return false
	func get_hitboxes() -> Array[Rect2]:
		return []
class TextPart extends ConsolePart:
	var text: String = ""
	var tooltip: String = ""
	var color: Color = Color.TRANSPARENT
	var hitboxes: Array[Rect2] = []
	var bold := false
	var underline := false
	var italic := false
	var _font_flags: FontFlags = FontFlags.new() :
		get:
			_font_flags.bold = bold
			_font_flags.italic = italic
			return _font_flags
	func draw(c: CustomConsole, data: ConsoleDrawData) -> void:
		var text_pos = 0
		var trim_pos: int
		hitboxes.clear()
		while true:
			if text_pos >= text.length():
				break
			if text[text_pos] == "\n":
				data.x = data.l
				data.y += c.get_line_height()
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
			trim_pos = text.find("\n", text_pos)
			if trim_pos < 0: trim_pos = text.length()
			var subtext := text.substr(text_pos,trim_pos-text_pos)
			var str_sz := c.get_string_size(subtext, _font_flags)
			while data.x < data.r and data.x + str_sz.x >= data.r:
				while trim_pos > text_pos and not text[trim_pos-1].lstrip(" \t"):
					trim_pos -= 1
				while trim_pos > text_pos and text[trim_pos-1].lstrip(" \t"):
					trim_pos -= 1
				subtext = text.substr(text_pos,trim_pos-text_pos)
				str_sz = c.get_string_size(subtext, _font_flags)
			if data.x >= data.r or trim_pos <= text_pos: # no space! next line!
				data.x = data.l
				data.y += c.get_line_height()
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
			subtext = text.substr(text_pos,trim_pos-text_pos)
			if subtext.lstrip(" \t"): #not all whitespace
				str_sz = c.get_string_size(subtext, _font_flags)
				var col = color if color.a8 else c.font_color
				var pos := Vector2(data.x,data.y+c.get_font_ascent(_font_flags))
				c.draw_string(c.get_font(_font_flags), pos, subtext, HORIZONTAL_ALIGNMENT_LEFT, -1, c.font_size, col)
				hitboxes.append(Rect2(Vector2(data.x,data.y), str_sz))
				if underline:
					c.draw_rect(Rect2(data.x,data.y+str_sz.y,str_sz.x,1), col)
				data.show_y(pos.y + str_sz.y)
				#c.draw_rect(hitboxes.back(), col, false, 4)
				data.x += str_sz.x
			elif trim_pos < text.length():
				# Trimmed whitespace, need to force the line down though
				data.x = data.r
			text_pos = trim_pos
	func _ttip_calc_size(c: CustomConsole, data: ConsoleDrawData, clip := false) -> void:
		if clip:
			c.tooltip_label.size = Vector2(data.w,c.tooltip_label.size.y)
			var h: int = 0 if c.tooltip_label.get_line_count() else c.tooltip_label.get_line_height()
			for q in c.tooltip_label.get_line_count():
				h += c.tooltip_label.get_line_height(q)
			c.tooltip_label.size = Vector2(c.tooltip_label.size.x,h)
		else:
			c.tooltip_label.reset_size()
		c.tooltip_bg.size = c.tooltip_label.size
		
		var cpos: Vector2 = c.hovered_hitbox.get_center()
		c.tooltip_bg.position.x = cpos.x - c.tooltip_bg.size.x/2
		if cpos.y >= data.cy:
			c.tooltip_bg.position.y = c.hovered_hitbox.position.y - c.tooltip_bg.size.y
		else:
			c.tooltip_bg.position.y = c.hovered_hitbox.position.y + c.hovered_hitbox.size.y
		#region Add border
		const HMARGIN = 2
		const VMARGIN = 2
		c.tooltip_label.position.x = HMARGIN
		c.tooltip_label.position.y = VMARGIN
		c.tooltip_bg.size.x += 2*HMARGIN
		c.tooltip_bg.size.y += 2*VMARGIN
		#endregion Add border
	func draw_hover(c: CustomConsole, data: ConsoleDrawData) -> void:
		if not tooltip: return
		#TODO Draw tooltip (Use an actual Label or something?)
		c.tooltip_bg.visible = true
		c.tooltip_label.text = tooltip
		c.tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.tooltip_label.reset_size()
		_ttip_calc_size(c,data)
		
		#region Bound tooltip in-window
		if c.tooltip_bg.size.x >= data.w: #don't let width overrun
			c.tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			c.tooltip_label.get_minimum_size() # Removing this getter breaks everything for some reason. WTF.
			_ttip_calc_size(c,data,true)
		while c.tooltip_bg.position.x < data.l:
			c.tooltip_bg.position.x += 1
		while c.tooltip_bg.position.x + c.tooltip_bg.size.x >= data.r:
			c.tooltip_bg.position.x -= 1
		while c.tooltip_bg.position.y < data.t:
			c.tooltip_bg.position.y += 1
		while c.tooltip_bg.position.y + c.tooltip_bg.size.y >= data.b:
			c.tooltip_bg.position.y -= 1
		#endregion Bound tooltip in-window
	func needs_hover() -> bool:
		return not tooltip.is_empty()
	func get_hitboxes() -> Array[Rect2]:
		return hitboxes
class LineBreakPart extends ConsolePart:
	var break_count: int = 1
	func draw(c: CustomConsole, data: ConsoleDrawData) -> void:
		data.x = data.l
		data.y += c.get_line_height() * break_count
class SpacingPart extends ConsolePart:
	var spacing := Vector2.ZERO
	func draw(c: CustomConsole, data: ConsoleDrawData) -> void:
		data.x += spacing.x
		var ly := spacing.y
		if data.x >= data.r:
			data.x = data.l
			var fh = c.get_line_height()
			if ly < fh: ly = fh
		data.y += ly

func add_text(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	var part := TextPart.new()
	part.text = text
	part.tooltip = ttip
	part.color = col
	parts.append(part)
	queue_redraw()
	return part

func add_linebreak(count := 1) -> LineBreakPart:
	var part = LineBreakPart.new()
	part.break_count = count
	parts.append(part)
	#no redraw needed for pure spacing
	return part

func add_spacing(spacing: Vector2) -> SpacingPart:
	var part = SpacingPart.new()
	part.spacing = spacing
	parts.append(part)
	#no redraw needed for pure spacing
	return part

var parts: Array[ConsolePart] = []
var hovered_part: ConsolePart = null
var hovered_hitbox: Rect2
var scroll: float = 0
var is_max_scroll := true
var has_mouse := false

func _init():
	if Engine.is_editor_hint():
		add_text("Test Font\n")
		add_text("Bold Font\n").bold = true
		add_text("Italic Font\n").italic = true
		var v = add_text("BoldItalic Font\n")
		v.bold = true
		v.italic = true
		add_text("Underline Font\n").underline = true
		return
	mouse_entered.connect(func():
		has_mouse = true
		refocus_part())
	mouse_exited.connect(func():
		has_mouse = false
		refocus_part())

func _process(_delta):
	if Engine.is_editor_hint(): return
	refocus_part()

func refocus_part():
	var pos := get_viewport().get_mouse_position() + Util.MOUSE_OFFSET
	var new_hover: ConsolePart = null
	var hov_hb: Rect2
	if has_mouse:
		for part in parts:
			if not new_hover:
				for hb in part.get_hitboxes():
					if hb.has_point(pos):
						new_hover = part
						hov_hb = hb
						break
	var changed := false
	if hovered_part != new_hover:
		hovered_part = new_hover
		changed = true
	if not new_hover or not new_hover.needs_hover():
		hov_hb = Rect2()
	if hovered_hitbox != hov_hb:
		hovered_hitbox = hov_hb
		changed = true
	if changed:
		queue_redraw()

var _draw_data := ConsoleDrawData.new()
func _draw():
	if Engine.is_editor_hint() or OS.is_debug_build(): # Reload these fonts each redraw, incase they changed
		font_bold = null
		font_italic = null
		font_bold_italic = null
	_draw_data.l = 0
	_draw_data.t = -scroll
	_draw_data.r = size.x
	_draw_data.b = size.y
	_draw_data.x = _draw_data.l
	_draw_data.y = _draw_data.t
	_draw_data.max_shown_y = 0.0
	tooltip_bg.visible = false
	tooltip_label.text = ""
	for part in parts:
		#part.color = Color.RED if part == hovered_part else Color.WHITE
		part.draw(self, _draw_data)
	if hovered_part:
		hovered_part.draw_hover(self, _draw_data)
	var max_scroll = _draw_data.max_scroll()
	if scroll > max_scroll:
		scroll = max_scroll
		call_deferred("queue_redraw")
	elif scroll < max_scroll and is_max_scroll:
		scroll = _draw_data.max_scroll()
		call_deferred("queue_redraw")
	if Util.approx_eq(scroll,_draw_data.max_scroll()):
		is_max_scroll = true

func scroll_by(amount: float) -> void:
	scroll_by_abs(amount * SCROLL_MULT)
func scroll_by_abs(amount: float) -> void:
	var old_scroll := scroll
	scroll += amount
	scroll = clampf(scroll, 0, _draw_data.max_scroll())
	is_max_scroll = Util.approx_eq(scroll,_draw_data.max_scroll())
	if not Util.approx_eq(scroll,old_scroll):
		queue_redraw()
func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventMouseButton:
		var fac: float = 1.0 if event.factor < Util.GAMMA else event.factor
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-fac)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(fac)
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_HOME:
					scroll_by_abs(-scroll)
				KEY_END:
					scroll_by_abs(_draw_data.max_scroll())
				KEY_UP:
					scroll_by_abs(-get_line_height())
				KEY_DOWN:
					scroll_by_abs(get_line_height())
				KEY_PAGEUP:
					scroll_by_abs(-size.y)
				KEY_PAGEDOWN:
					scroll_by_abs(size.y)

func close() -> void:
	if Engine.is_editor_hint(): return
	var p = self
	while p and not p is Window:
		p = p.get_parent()
	if p:
		p.close_requested.emit()

func send_msg(msg: String):
	send_text.emit(msg)
	scroll_by_abs(_draw_data.max_scroll())

func clear() -> void:
	parts.clear()
	queue_redraw()
