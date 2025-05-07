class_name Util

const MOUSE_OFFSET := Vector2(0,-2)
const GAMMA = 0.0001
static func get_mag(v: Vector2) -> float:
	return sqrt(abs(v.x)**2 + abs(v.y)**2)

static func current_scene(tree: SceneTree) -> Node:
	if Engine.is_editor_hint():
		return tree.edited_scene_root
	else:
		return tree.current_scene

static func for_every_node(tree: SceneTree, proc: Callable) -> Node:
	return for_all_nodes(current_scene(tree), proc)
static func for_all_nodes(node: Node, proc: Callable) -> Node:
	if proc.call(node):
		return node
	if node != null:
		for child in node.get_children():
			var ret = for_all_nodes(child, proc)
			if ret: return ret
	return null

static var logging_file = null
static func open_logger() -> void:
	logging_file = FileAccess.open("user://logs/log.log",FileAccess.WRITE)
static func close_logger() -> void:
	if logging_file:
		logging_file.close()
		logging_file = null
static func log(s: Variant) -> void:
	if logging_file:
		logging_file.store_line(str(s))
		if OS.is_debug_build(): logging_file.flush()
	print("%s" % str(s))
static func dblog(s: Variant) -> void:
	if not OS.is_debug_build(): return
	Util.log(s)

static func freeze_popup(tree: SceneTree, title: String, text: String, cancel := true) -> AcceptDialog:
	return freeze_sub_popup(tree.root, title, text, cancel)
static func freeze_sub_popup(node: Node, title: String, text: String, cancel := true) -> AcceptDialog:
	var popup = AcceptDialog.new()
	node.add_child(popup)
	var tree: SceneTree = node.get_tree()
	popup.title = title
	popup.dialog_text = text
	popup.keep_title_visible = true
	popup.extend_to_title = true
	popup.transient = true
	popup.popup_window = false
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.paused = true
	var unfreeze: Callable = func():
		tree.paused = false
	popup.confirmed.connect(unfreeze)
	popup.canceled.connect(unfreeze)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	if cancel:
		popup.add_cancel_button("Cancel")
	popup.min_size = Vector2i(200,0)
	return popup

static func standard_popup(tree: SceneTree, title: String, text: String, cancel := true) -> AcceptDialog:
	return standard_sub_popup(tree.root, title, text, cancel)
static func standard_sub_popup(node: Node, title: String, text: String, cancel := true) -> AcceptDialog:
	var popup = AcceptDialog.new()
	node.add_child(popup)
	popup.title = title
	popup.dialog_text = text
	popup.keep_title_visible = true
	popup.extend_to_title = true
	popup.transient = true
	popup.popup_window = false
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	if cancel:
		popup.add_cancel_button("Cancel")
	popup.min_size = Vector2i(200,0)
	return popup

static func on_closed(popup: Window):
	if popup is AcceptDialog:
		popup.confirmed.connect(func(): popup.close_requested.emit())
		popup.canceled.connect(func(): popup.close_requested.emit())
	await popup.close_requested

static func load_new_scene(tree: SceneTree, path: String) -> void:
	load_scene(tree, load(path))
static func load_scene(tree: SceneTree, scene: PackedScene) -> void:
	tree.change_scene_to_packed(scene)

static func is_zero_vec(vec: Vector2) -> bool:
	return abs(vec.x) < GAMMA and abs(vec.y) < GAMMA


static func unsigned_to_signed(unsigned: int, bits: int):
	return (unsigned + (1 << (bits-1))) % (1 << bits) - (1 << (bits-1))
static func unsigned_to_signed_8(unsigned: int):
	return unsigned_to_signed(unsigned, 8)
static func unsigned_to_signed_16(unsigned: int):
	return unsigned_to_signed(unsigned, 16)
static func unsigned_to_signed_32(unsigned: int):
	return unsigned_to_signed(unsigned, 32)

static func bit_count(val: int) -> int:
	var ret = 0
	for v in 64:
		if val & (1<<v): ret += 1
	return ret

static func approx_eq(v1: float, v2: float) -> bool:
	return abs(v1-v2) < GAMMA
static func approx_eq_vec(v1: Vector2, v2: Vector2) -> bool:
	var diff = abs(v1-v2)
	return diff.x < GAMMA and diff.y < GAMMA

static func move_toward_directional(v1: Vector2, v2: Vector2) -> Vector2:
	var ret = Vector2.ZERO
	if sign(v1.x) == sign(v2.x) and abs(v1.x) > abs(v2.x):
		ret.x = v1.x
	else: ret.x = move_toward(v1.x, v2.x, abs(v2.x)*.75)
	if sign(v1.y) == sign(v2.y) and abs(v1.y) > abs(v2.y):
		ret.y = v1.y
	else: ret.y = move_toward(v1.y, v2.y, abs(v2.y)*.75)
	return ret

static func split_args(msg: String) -> Array[String]:
	var raw_args = msg.split(" ")
	var args: Array[String] = []
	var open_quote := false
	for s in raw_args:
		if open_quote:
			args[-1] += " " + s
		else: args.append(s)
		if s.count("\"") % 2:
			open_quote = not open_quote
	return args

static func reversed(arr: Array) -> Array:
	var dup := arr.duplicate()
	dup.reverse()
	return dup

static func find_break_paren(s: String) -> int:
	var paren := 0
	var bracket := 0
	var brace := 0
	for q in s.length():
		match s[q]:
			"(": paren += 1
			"[": bracket += 1
			"{": brace += 1
			")":
				paren -= 1
				if paren < 0: return q
			"]":
				bracket -= 1
				if bracket < 0: return q
			"}":
				brace -= 1
				if brace < 0: return q
	return s.length()

static func poll_timer(timer: Timer, dur: float) -> bool:
	if timer.is_stopped():
		if dur > GAMMA:
			timer.start(dur)
		return true
	return false

static func modulate(img: Image, col: Color) -> Image:
	var ret = Image.new()
	ret.copy_from(img)
	for x in ret.get_width():
		for y in ret.get_height():
			var px = ret.get_pixel(x, y)
			if px.a8 == 255:
				ret.set_pixel(x, y, px * col)
	return ret

static func grayscale(img: Image) -> Image:
	var ret = Image.new()
	ret.copy_from(img)
	for x in ret.get_width():
		for y in ret.get_height():
			var px = ret.get_pixel(x, y)
			if px.a8 == 255:
				ret.set_pixel(x, y, gray(px))
	return ret

static func gray(c: Color) -> Color:
	var g = (c.r * 0.299) + (c.g * 0.587) + (c.b * 0.114)
	return Color(g, g, g)

static func get_pascal_string_or(file: FileAccess, default: String) -> String:
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_pascal_string()
static func get_8_or(file: FileAccess, default: int) -> int:
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_8()
static func get_16_or(file: FileAccess, default: int) -> int:
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_16()
static func get_32_or(file: FileAccess, default: int) -> int:
	if not file or file.eof_reached(): return default
	if file.get_position() >= file.get_length(): return default
	return file.get_32()

static func nil() -> void:
	pass

# Font stuff
static func font_mod(font: Font, bold: bool, italic: bool) -> Font:
	if font is FontFile:
		var _font = FontVariation.new()
		_font.base_font = font
		font = _font
	if font is FontVariation:
		if bold:
			if "weight" in _get_supported_opentype_variants(font):
				var ts = TextServerManager.get_primary_interface()
				var _dict = font.variation_opentype
				_dict[ts.name_to_tag("weight")] = 700
				font.variation_opentype = _dict
			else:
				font.variation_embolden = 0.7
		if italic: #TODO: add handling of italic opentype variant
			var slant = 0.3
			font.variation_transform = Transform2D(Vector2(1.0, slant), Vector2(0.0, 1.0), Vector2(0.0, 0.0))
	elif font is SystemFont:
		if bold:
			font.font_weight = 700
		if italic:
			font.font_italic = true
	return font
static func _get_supported_opentype_variants(fnt: FontVariation) -> Array:
	var arr = fnt.get_supported_variation_list().keys()
	var ts = TextServerManager.get_primary_interface()
	for i in range(arr.size()):
		arr[i] = ts.tag_to_name(arr[i])
	return arr
