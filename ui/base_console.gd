@tool class_name BaseConsole extends Control

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
@export var COLOR_UI_MSG: Color = Color(.7,.7,.3)

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

func get_font(flags: FontFlags = null) -> Font:
	if not flags: flags = FontFlags.new()
	if flags.bold:
		if flags.italic:
			return font_bold_italic
		else: return font_bold
	elif flags.italic:
		return font_italic
	else: return font
func get_font_height(flags: FontFlags = null) -> float:
	return get_font(flags).get_height(font_size)
func get_line_height() -> float:
	var h := 0.0
	for f in [font,font_bold,font_italic,font_bold_italic]:
		h = maxf(h,f.get_height(font_size))
	return SPACING+h
func get_font_ascent(flags: FontFlags = null) -> float:
	return get_font(flags).get_ascent(font_size)
func get_string_size(text: String, flags: FontFlags = null) -> Vector2:
	return get_font(flags).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

@onready var tooltip_bg: ColorRect = $TooltipBG
@onready var tooltip_label: Label = $TooltipBG/Tooltip
class ConsoleDrawData:
	var l: float
	var t: float
	var r: float
	var b: float
	
	var x: float :
		set(val):
			x = val
			if not Util.approx_eq(x, l):
				reset_y = null
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
	var reset_y: Variant
	
	func show_y(ty: float) -> void:
		ty -= t
		if ty > max_shown_y:
			max_shown_y = ty;
	func max_scroll() -> float:
		var s := max_shown_y - b
		return 0.0 if s <= 0 else s
	func newline(c: BaseConsole, count := 1):
		var at_start := Util.approx_eq(x, l)
		x = l
		if count > 0:
			if at_start:
				reset_y = y
			else: reset_y = y + c.get_line_height()
		y += c.get_line_height() * count
	
class ConsolePart:
	func draw(_c: BaseConsole, _data: ConsoleDrawData) -> void:
		pass
	func draw_hover(_c: BaseConsole, _data: ConsoleDrawData) -> void:
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
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		var text_pos = 0
		var trim_pos: int
		hitboxes.clear()
		while true:
			if text_pos >= text.length():
				break
			if text[text_pos] == "\n":
				data.newline(c)
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
			trim_pos = text.find("\n", text_pos)
			if trim_pos < 0: trim_pos = text.length()
			var subtext := text.substr(text_pos,trim_pos-text_pos)
			var str_sz := c.get_string_size(subtext, _font_flags)
			while data.x < data.r and data.x + str_sz.x >= data.r and trim_pos > text_pos:
				while trim_pos > text_pos and not text[trim_pos-1].lstrip(" \t"):
					trim_pos -= 1
				while trim_pos > text_pos and text[trim_pos-1].lstrip(" \t"):
					trim_pos -= 1
				subtext = text.substr(text_pos,trim_pos-text_pos)
				str_sz = c.get_string_size(subtext, _font_flags)
			if trim_pos <= text_pos: # No space at all, window is too thin
				break # abort to avoid infinite loop
			if data.x >= data.r: # no space! next line!
				data.newline(c)
				while text_pos < text.length() and not text[text_pos].lstrip("\n"):
					text_pos += 1
				continue
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
	func _ttip_calc_size(c: BaseConsole, data: ConsoleDrawData, clip := false) -> void:
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
	func draw_hover(c: BaseConsole, data: ConsoleDrawData) -> void:
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
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		data.newline(c, break_count)
class SpacingPart extends ConsolePart:
	var spacing := Vector2.ZERO
	var reset_line := true
	var from_reset_y := false
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if reset_line and not Util.approx_eq(data.x, data.l):
			data.newline(c)
		if from_reset_y:
			if data.reset_y == null:
				data.newline(c)
			var r_y: float = data.reset_y
			data.x = data.l + spacing.x
			if not Util.approx_eq(r_y, data.t):
				data.y = max(data.y, r_y + spacing.y) # max to avoid reducing space
		else:
			data.x += spacing.x
			if not Util.approx_eq(data.y, data.t):
				data.y += spacing.y
class IndentPart extends ConsolePart:
	var indent: float = 0.0
	func draw(_c: BaseConsole, data: ConsoleDrawData) -> void:
		if Util.approx_eq(data.x, data.l):
			data.x += indent
		data.l += indent


func add_text(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	var part := TextPart.new()
	part.text = text
	part.tooltip = ttip
	part.color = col
	parts.append(part)
	queue_redraw()
	return part

func add_line(text: String, ttip := "", col := Color.TRANSPARENT) -> TextPart:
	var ret = add_text(text, ttip, col)
	ensure_newline()
	return ret

func add_linebreak(count := 1) -> LineBreakPart:
	var part = LineBreakPart.new()
	part.break_count = count
	parts.append(part)
	#no redraw needed for pure spacing
	return part
func add_spacing(spacing: Vector2, reset_line := true, from_reset_y := false) -> SpacingPart:
	var part = SpacingPart.new()
	part.spacing = spacing
	part.reset_line = reset_line
	part.from_reset_y = from_reset_y
	parts.append(part)
	#no redraw needed for pure spacing
	return part

func add_header_spacing(vspace: float = -0.5) -> SpacingPart:
	if vspace < 0: vspace = get_line_height() * abs(vspace)
	return add_spacing(Vector2(0,vspace), false, true)

func add_indent(indent: float) -> IndentPart:
	var part = IndentPart.new()
	part.indent = indent
	parts.append(part)
	#no redraw needed for pure spacing
	return part

func ensure_newline(): # Returns SpacingPart | null
	if not parts.is_empty():
		var last_part = parts.back()
		if last_part is SpacingPart:
			if last_part.reset_line or last_part.from_reset_y:
				return #already ensured
	return add_header_spacing(0)

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

func _get_mouse_pos() -> Vector2:
	return get_viewport().get_mouse_position() - global_position + Util.MOUSE_OFFSET

func refocus_part():
	if Engine.is_editor_hint(): return
	var pos := _get_mouse_pos()
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
	_draw_data.reset_y = _draw_data.t
	tooltip_bg.visible = false
	tooltip_label.text = ""
	for part in parts:
		#if part is TextPart:
			#part.color = Color.RED if part == hovered_part else Color.WHITE
		part.draw(self, _draw_data)
	if hovered_part:
		hovered_part.draw_hover(self, _draw_data)
	
	if Engine.is_editor_hint(): return
	
	var max_scroll = _draw_data.max_scroll()
	if scroll > max_scroll:
		scroll = max_scroll
		call_deferred("queue_redraw")
	elif scroll < max_scroll and is_max_scroll:
		scroll = _draw_data.max_scroll()
		call_deferred("queue_redraw")
	if Util.approx_eq(scroll,_draw_data.max_scroll()):
		is_max_scroll = true
	#var mpos = _get_mouse_pos()
	#draw_rect(Rect2(mpos.x-1,mpos.y-1,2,2), Color.REBECCA_PURPLE)

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
	while p and not p is ConsoleContainer:
		p = p.get_parent()
	if p:
		p.close()

func send_msg(msg: String):
	send_text.emit(msg)
	scroll_by_abs(_draw_data.max_scroll())

func clear() -> void:
	parts.clear()
	queue_redraw()

func printjson_command(json: Dictionary) -> String:
	var s := ""
	var output_data := false
	var pre_space := false
	var post_space := false
	match json.get("type"):
		"Chat":
			var msg = json.get("message","")
			var name_part := AP.out_player(self, json["slot"], Archipelago.conn)
			name_part.text += ": "
			if not msg.is_empty():
				add_text(msg)
				s += name_part.text + msg
		"CommandResult", "AdminCommandResult", "Goal", "Release", "Collect", "Tutorial":
			pre_space = true
			post_space = true
			output_data = true
		"Countdown":
			if int(json["countdown"]) == 0:
				post_space = true
			output_data = true
		"ItemSend", "ItemCheat":
			if not Archipelago.AP_HIDE_NONLOCAL_ITEMSENDS:
				output_data = true
			elif int(json["receiving"]) == Archipelago.conn.player_id:
				output_data = true
			else:
				var ni := NetworkItem.from(json["item"], Archipelago.conn, true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Hint":
			if int(json["receiving"]) == Archipelago.conn.player_id:
				output_data = true
			else:
				var ni := NetworkItem.from(json["item"], Archipelago.conn, true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Join", "Part":
			var data: Array = json["data"]
			var elem: Dictionary = data.pop_front()
			var txt: String = elem["text"]
			var plyr := Archipelago.conn.get_player(json["slot"])
			var spl := txt.split(plyr.get_name(), true, 1)
			if spl.size() == 2:
				elem.text = spl[0]
				s += printjson_out([elem])
				plyr.output(self)
				elem.text = spl[1]
				s += printjson_out([elem])
				s += printjson_out(data)
			else: output_data = true
		_:
			output_data = true
	if pre_space and output_data:
		add_header_spacing()
	if output_data:
		s += printjson_out(json["data"])
	if post_space and output_data:
		add_header_spacing()
	ensure_newline()
	return s

func printjson_out(elems: Array) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		s += txt
		match elem.get("type", "text"):
			"player_name":
				add_text(txt, "Arbitrary Player Name", Archipelago.COLOR_PLAYER)
			"item_name":
				add_text(txt, "Arbitrary Item Name", Archipelago.COLOR_ITEM)
			"location_name":
				add_text(txt, "Arbitrary Location Name", Archipelago.COLOR_LOCATION)
			"entrance_name":
				add_text(txt, "Arbitrary Entrance Name", Archipelago.COLOR_LOCATION)
			"player_id":
				var plyr_id = int(txt)
				Archipelago.conn.get_player(plyr_id).output(self)
			"item_id":
				var item_id = int(txt)
				var plyr_id = int(elem["player"])
				var data := Archipelago.conn.get_gamedata_for_player(plyr_id)
				var flags := int(elem["flags"])
				AP.out_item(self, item_id, flags, data)
			"location_id":
				var loc_id = int(txt)
				var plyr_id = int(elem["player"])
				var data := Archipelago.conn.get_gamedata_for_player(plyr_id)
				AP.out_location(self, loc_id, data)
			"text":
				add_text(txt)
			"color":
				var part := add_text(txt)
				var col_str: String = elem["color"]
				if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
					col_str = col_str.substr(0,col_str.length()-3)
				match col_str:
					"red":
						part.color = Color8(0xEE,0x00,0x00)
					"green":
						part.color = Color8(0x00,0xFF,0x7F)
					"yellow":
						part.color = Color8(0xFA,0xFA,0xD2)
					"blue":
						part.color = Color8(0x64,0x95,0xED)
					"magenta":
						part.color = Color8(0xEE,0x00,0xEE)
					"cyan":
						part.color = Color8(0x00,0xEE,0xEE)
					"white":
						part.color = Color.WHITE
					"black":
						part.color = Color.BLACK
					"slateblue":
						part.color = Color8(0x6D,0x8B,0xE8)
					"plum":
						part.color = Color8(0xAF,0x99,0xEF)
					"salmon":
						part.color = Color8(0xFA,0x80,0x72)
					"orange":
						part.color = Color8(0xFF,0x77,0x00)
					"bold":
						part.bold = true
					"underline":
						part.underline = true
	return s

static func printjson_str(elems: Array) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		s += txt
	return s
