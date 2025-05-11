@tool class_name BaseConsole extends Control

@export_group("Nodes")
@export var scroll_cont: ScrollContainer
@export var parts_cont: VBoxContainer
@export_group("")
@export var spacing: int :
	set(val):
		spacing = val
		if parts_cont:
			parts_cont.add_theme_constant_override(&"separation", spacing)
	get:
		if not parts_cont:
			return spacing
		return parts_cont.get_theme_constant(&"separation")

static var console_label_fonts: FontStorage

func pop_dropdown(target: Control) -> VBoxContainer:
	var parent_window := get_window()
	var window := Window.new()
	window.min_size = Vector2.ZERO
	window.reset_size()
	window.transient = true
	window.exclusive = true
	window.unresizable = true
	window.borderless = true
	window.popup_window = true
	window.visible = false
	window.focus_exited.connect(window.queue_free)
	window.close_requested.connect(window.queue_free)
	parent_window.close_requested.connect(window.queue_free)
	var vbox := VBoxContainer.new()
	var resize_window: Callable = func():
		var hb := target.get_rect()
		window.size.x = roundi(hb.size.x)
		window.size.y = ceili(vbox.size.y)
		var vbwid := ceili(vbox.size.x)
		var diff := 0
		if window.size.x < vbwid:
			diff = vbwid - window.size.x
			window.size.x = vbwid
		window.position.x = roundi(global_position.x + hb.position.x)
		window.position.y = roundi(global_position.y + hb.position.y + hb.size.y)
		if diff:
			if window.position.x > parent_window.size.x / 2.0:
				window.position.x = max(0, window.position.x - diff)
			if window.position.x + window.size.x > parent_window.size.x:
				var diff2 = (window.position.x + window.size.x) - parent_window.size.x
				window.position.x = max(0, window.position.x - diff2)

		if not window.visible: window.visible = true
	target.resized.connect(resize_window)
	window.add_child(vbox)
	window.ready.connect(resize_window)
	#window.tree_exiting.connect(func(): resized.disconnect(resize_window))
	add_child.call_deferred(window) # Defer adding it, to allow caller to add things to the vbox
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	return vbox

func add(part: Control) -> Control:
	if not part: return
	parts_cont.add_child(part)
	queue_redraw()
	return part

static func make_text(text: String, ttip := "", col := AP.ComplexColor.NIL) -> ConsoleLabel:
	return ConsoleLabel.make_col(text, col, ttip)

static func make_c_text(text: String, ttip := "", col := AP.ComplexColor.NIL) -> ConsoleLabel:
	var part := make_text(text, ttip, col)
	part.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return part

static func make_spacing(space: Vector2) -> Control:
	var part = Control.new()
	part.custom_minimum_size = space
	return part

func get_line_height() -> float:
	var font_size: int = get_theme_font_size(&"font_size", "ConsoleLabel")
	var fonts: Array[Font]
	fonts.append(console_label_fonts.base_font)
	fonts.append(console_label_fonts.bold_font)
	fonts.append(console_label_fonts.italic_font)
	fonts.append(console_label_fonts.bold_italic_font)
	var h := 0.0
	for f in fonts:
		h = maxf(h,f.get_height(font_size))
	return h
func make_header_spacing(vspace: float = -0.5) -> Control:
	if vspace < 0:
		vspace = get_line_height() * abs(vspace)
	return make_spacing(Vector2(0,vspace))
func add_header_spacing(vspace: float = -0.5) -> Control:
	return add(make_header_spacing(vspace))

static func make_indent(indent: int) -> MarginContainer:
	var part := MarginContainer.new()
	part.add_theme_constant_override(&"margin_left", indent)
	part.add_theme_constant_override(&"margin_right", 0)
	part.add_theme_constant_override(&"margin_top", 0)
	part.add_theme_constant_override(&"margin_bottom", 0)
	return part

static func make_indented_block(s: String, indent: float) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.theme_type_variation = "Console_VBox"
	var container: VBoxContainer
	var spl = s.split("\n")
	var indent_depth: int = -1
	for line in spl:
		var sz: int = line.length()
		line = line.lstrip("\t")
		sz -= line.length()
		if sz != indent_depth:
			container = VBoxContainer.new()
			var margin := MarginContainer.new()
			margin.add_child(container)
			margin.add_theme_constant_override(&"margin_left", ceili(indent * sz))
			margin.add_theme_constant_override(&"margin_top", 0)
			margin.add_theme_constant_override(&"margin_right", 0)
			margin.add_theme_constant_override(&"margin_bottom", 0)
			indent_depth = sz
			root.add_child(margin)

		container.add_child(make_text(line, ""))
	return root

static func make_location(id: int, data: DataCache) -> ConsoleLabel:
	return make_text(data.get_loc_name(id), "", AP.ComplexColor.as_special(AP.SpecialColor.LOCATION))
static func make_item(id: int, flags: int, data: DataCache) -> ConsoleLabel:
	var ttip = "Type: %s" % AP.get_item_classification(flags)
	var color := AP.ComplexColor.as_rich(AP.get_item_class_color(flags))
	return make_text(data.get_item_name(id), ttip, color)

static func make_player(id: int) -> ConsoleLabel:
	var player: NetworkPlayer = Archipelago.conn.get_player(id)
	var ttip = "Game: %s" % Archipelago.conn.get_slot(id).game
	if not player.alias.is_empty():
		ttip += "\nSlot: %s" % player.name
	var color := (AP.SpecialColor.OWN_PLAYER if id == Archipelago.conn.player_id else
		AP.SpecialColor.ANY_PLAYER)
	return make_text(player.name, ttip, AP.ComplexColor.as_special(color))

static func make_foldable(text: String, ttip := "", color := AP.ComplexColor.NIL) -> ConsoleFoldableContainer:
	return ConsoleFoldableContainer.make(text, ttip, color)

var is_max_scroll := false

func _ready():
	theme_changed.connect(queue_redraw)
	if Engine.is_editor_hint():
		add(make_text("Test Font\n"))
		add(make_text("Bold Font\n")).bold = true
		add(make_text("Italic Font\n")).italic = true
		var v: ConsoleLabel = add(make_text("BoldItalic Font\n"))
		v.bold = true
		v.italic = true
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if not console_label_fonts:
			console_label_fonts = FontStorage.new(get_theme_font(&"font", "ConsoleLabel"))
		else:
			console_label_fonts.populate(get_theme_font(&"font", "ConsoleLabel"))

func _get_mouse_pos() -> Vector2:
	return get_viewport().get_mouse_position() - global_position + Util.MOUSE_OFFSET

func scroll_bottom() -> void:
	scroll_cont.scroll_vertical = 9999999
func scroll_top() -> void:
	scroll_cont.scroll_vertical = 0
func scroll_by_abs(amnt: float) -> void:
	scroll_cont.scroll_vertical += roundi(amnt)
func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_HOME:
					scroll_top()
				KEY_END:
					scroll_bottom()
				KEY_UP:
					scroll_by_abs(-get_line_height())
				KEY_DOWN:
					scroll_by_abs(get_line_height())
				KEY_PAGEUP:
					scroll_by_abs(-size.y)
				KEY_PAGEDOWN:
					scroll_by_abs(size.y)

func queue_locked_redraw() -> void:
	is_max_scroll = false
	queue_redraw()

func close() -> void:
	if Engine.is_editor_hint(): return
	var p = self
	while p and not p is ConsoleWindowContainer:
		p = p.get_parent()
	if p:
		p.close()

func clear() -> void:
	for part in parts_cont.get_children():
		part.queue_free()
	queue_redraw()

func printjson_command(json: Dictionary) -> String:
	var s := ""
	var output_data := false
	var pre_space := false
	var post_space := false
	var flowbox := ConsoleHFlow.new()
	match json.get("type"):
		"Chat":
			var msg = json.get("message","")
			var name_part: ConsoleLabel = Archipelago.conn.get_player(json["slot"]).output()
			flowbox.add_text_split(name_part)
			name_part.text += ": "
			if not msg.is_empty():
				var lbl := make_text(msg)
				flowbox.add_text_split(lbl)
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
				var ni := NetworkItem.from(json["item"], true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Hint":
			if int(json["receiving"]) == Archipelago.conn.player_id:
				output_data = true
			else:
				var ni := NetworkItem.from(json["item"], true)
				if ni.src_player_id == Archipelago.conn.player_id:
					output_data = true
		"Join", "Part":
			var data: Array = json["data"]
			var elem: Dictionary = data.pop_front()
			var plyr: NetworkPlayer = Archipelago.conn.get_player(json["slot"])
			var spl := (elem["text"] as String).split(plyr.get_name(), true, 1)
			if spl.size() == 2:
				elem["text"] = spl[0]
				s += printjson_out([elem], flowbox)
				var plyr_lbl := plyr.output()
				flowbox.add_text_split(plyr_lbl)
				s += plyr_lbl.text
				elem["text"] = spl[1]
				s += printjson_out([elem], flowbox)
				s += printjson_out(data, flowbox)
			else: output_data = true
		_:
			output_data = true
	if flowbox.get_child_count() > 0:
		add(flowbox)
		flowbox = null
	if pre_space and output_data:
		add_header_spacing()
	if output_data:
		if not flowbox: flowbox = ConsoleHFlow.new()
		s += printjson_out(json["data"], flowbox)
		add(flowbox)
	if post_space and output_data:
		add_header_spacing()
	return s

func printjson_out(elems: Array, flowbox: ConsoleHFlow) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		if txt.is_empty():
			continue
		s += txt
		var part: ConsoleLabel
		match elem.get("type", "text"):
			"hint_status":
				var stat = elem["hint_status"] as NetworkHint.Status
				var stat_name: String = NetworkHint.status_names.get(stat, "(unknown)")
				var color: AP.RichColor = NetworkHint.status_colors.get(stat, AP.RichColor.RED)

				part = make_text(txt, stat_name, AP.ComplexColor.as_rich(color))
			"player_name":
				part = make_text(txt, "Arbitrary Player Name", AP.ComplexColor.as_special(AP.SpecialColor.ANY_PLAYER))
			"item_name":
				part = make_text(txt, "Arbitrary Item Name", AP.ComplexColor.as_special(AP.SpecialColor.ITEM))
			"location_name":
				part = make_text(txt, "Arbitrary Location Name", AP.ComplexColor.as_special(AP.SpecialColor.LOCATION))
			"entrance_name":
				part = make_text(txt, "Arbitrary Entrance Name", AP.ComplexColor.as_special(AP.SpecialColor.LOCATION))
			"player_id":
				var plyr_id = int(txt)
				part = Archipelago.conn.get_player(plyr_id).output()
			"item_id":
				var item_id = int(txt)
				var plyr_id = int(elem["player"])
				var data: DataCache = Archipelago.conn.get_gamedata_for_player(plyr_id)
				var flags := int(elem["flags"])
				part = make_item(item_id, flags, data)
			"location_id":
				var loc_id = int(txt)
				var plyr_id = int(elem["player"])
				var data: DataCache = Archipelago.conn.get_gamedata_for_player(plyr_id)
				part = make_location(loc_id, data)
			"text":
				part = make_text(txt)
			"color":
				part = make_text(txt)
				var col_str: String = elem["color"]
				if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
					col_str = col_str.substr(0,col_str.length()-3)
				match col_str:
					"bold":
						part.bold = true
					"underline":
						pass #part.underline = true
					_:
						part.color = AP.color_from_name(part, col_str, part.color)
		flowbox.add_text_split(part)
	return s

static func printjson_str(elems: Array) -> String:
	var s := ""
	for elem in elems:
		var txt: String = elem["text"]
		s += txt
	return s
