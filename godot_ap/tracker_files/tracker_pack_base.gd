class_name TrackerPack_Base

func get_type() -> String: return "BASE_PACK"

var saved_path: String = ""

var game: String
var env: PackEnvironment

func load_image(relpath: String) -> Image:
	var dir = env.open()
	if dir is DirAccess:
		if not dir.file_exists(relpath):
			return null
		var file_path: String = dir.get_current_dir() + "/" + relpath
		return Image.load_from_file(file_path)
	elif dir is ZIPReader:
		var bytes: PackedByteArray = dir.read_file(relpath)
		if bytes.is_empty():
			dir.close()
			return null
		var ret := Image.new()
		if relpath.ends_with(".png"):
			ret.load_png_from_buffer(bytes)
		elif relpath.ends_with(".jpg") or relpath.ends_with(".jpeg"):
			ret.load_jpg_from_buffer(bytes)
		elif relpath.ends_with(".bmp"):
			ret.load_bmp_from_buffer(bytes)
		elif relpath.ends_with(".webp"):
			ret.load_webp_from_buffer(bytes)
		else: ret = null
		dir.close()
		return ret
	return null

signal instantiated(scene: TrackerScene_Root)
signal readied(scene: TrackerScene_Root)
func _done_instantiating(scene: TrackerScene_Root) -> void:
	instantiated.emit(scene)
	await scene.ready
	readied.emit(scene)

func instantiate() -> TrackerScene_Root:
	assert(false) # Override with a valid return!
	return null

func save_as(path: String) -> Error:
	var err := OK
	if path.ends_with(".zip"):
		var writer := ZIPPacker.new()
		err = writer.open(path)
		if err: return err

		err = writer.start_file("pack.json")
		if err:
			writer.close()
			return err
		var data: Dictionary = {}
		err = _save_file(data)
		if err:
			writer.close()
			return err
		var s := JSON.stringify(data, "\t", false)
		err = writer.write_file(s.to_ascii_buffer())
		if not err:
			err = writer.close_file()
		var ret = writer.close()
		if err: return err
		return ret
	elif path.ends_with(".json"):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file: return FileAccess.get_open_error()

		var data: Dictionary = {}
		err = _save_file(data)
		if not err:
			var s := JSON.stringify(data, "\t", false)
			file.store_string(s)
			err = file.get_error()
		file.close()
		if not err:
			saved_path = path
		return err
	else:
		return ERR_FILE_BAD_PATH

func resave() -> Error:
	if not saved_path:
		return ERR_FILE_BAD_PATH
	return save_as(saved_path)

func _save_file(data: Dictionary) -> Error:
	data["game"] = game
	data["type"] = get_type()
	return OK

class PackEnvironment:
	var path: String
	var is_zip: bool
	func _init(dirpath: String, zip: bool):
		path = dirpath
		is_zip = zip
	func open() -> Variant: # Returns ZIPReader, DirAccess, or Error
		if is_zip:
			var reader := ZIPReader.new()
			var err := reader.open(path)
			if err: return err
			return reader
		else:
			var dir := DirAccess.open(path)
			if dir: return dir
			return ERR_FILE_CANT_OPEN

static var load_error := ""
static func load_from(path: String) -> TrackerPack_Base:
	load_error = ""
	if path.ends_with(".zip"):
		var reader := ZIPReader.new()
		var err := reader.open(path)
		if err:
			load_error = str(err)
			return null

		var bytes := reader.read_file("pack.json")
		if bytes.is_empty():
			load_error = "Error loading 'pack.json'"
			reader.close()
			return null
		var text := bytes.get_string_from_ascii()
		var ret := load_json_string(text)
		if ret:
			ret.saved_path = path
			ret.env = PackEnvironment.new(path, true)
		if load_error:
			load_error.insert(0, "Error loading 'pack.json':\n")
		reader.close()
		return ret
	elif path.ends_with(".json"):
		var dir := DirAccess.open(path.get_base_dir())
		if not dir:
			load_error = "Can't open dir"
			return null
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			load_error = "Can't open file"
			return null
		var text := file.get_as_text()
		var ret := load_json_string(text)
		if ret:
			ret.saved_path = path
			ret.env = PackEnvironment.new(path.get_base_dir(), false)
		return ret
	else:
		load_error = "Unrecognized Extension"
		return null

static func load_json_string(text: String) -> TrackerPack_Base:
	load_error = ""
	var json_parser := JSON.new()
	var json = null
	if json_parser.parse(text):
		load_error = "Invalid JSON: Line %d, %s" % [json_parser.get_error_line(), json_parser.get_error_message()]
		return null
	else:
		json = json_parser.data

	if not json is Dictionary:
		if not json:
			load_error = "Invalid JSON"
		else:
			load_error = "JSON root is not object"
		return null
	if json.get("game", "").is_empty():
		load_error = "'game' must be a valid game name"
		return null
	var type: String = json.get("type", "")
	var ret := _make_type(type)
	if ret:
		if ret._load_file(json):
			return null
	return ret
static func _make_type(type: String) -> TrackerPack_Base:
	match type:
		"BASE_PACK":
			return TrackerPack_Base.new()
		"SCENE":
			return TrackerPack_Scene.new()
		"DATA_PACK":
			return TrackerPack_Data.new()
	return null


func _load_file(json: Dictionary) -> Error:
	game = json.get("game", "")
	if game.is_empty(): return ERR_INVALID_DATA
	return OK

static func _output_error(s: String, ttip: String = "") -> void:
	if not (Archipelago.config.verbose_trackerpack and Archipelago.output_console):
		return
	Archipelago.output_console.add_line(s, ttip, AP.color_from_name("red"))
	AP.log(s)
	if not ttip.is_empty():
		AP.log(ttip)
static func _expect_gui_keys(dict: Dictionary, expected: Array[String], optional: Dictionary = {}) -> bool:
	return _expect_keys("Type '%s'" % dict.get("type", "NULL"),  dict, expected, optional)
static func _expect_keys(pref: String, dict: Dictionary, expected: Array[String], optional: Dictionary = {}) -> bool:
	var found: Array[String] = []
	found.assign(dict.keys())
	var missing: Array[String] = expected.duplicate(true)
	var extra: Array[String] = []
	var to_add: Dictionary = optional.duplicate(true)
	for s in found:
		if s in expected:
			missing.erase(s)
			continue
		if s in optional:
			to_add.erase(s)
			continue
		if not (s in expected):
			extra.append(s)
	if not (missing.is_empty() and extra.is_empty()):
		var strs := [pref]
		if missing:
			strs.append("missing keys %s" % str(missing))
		if extra:
			strs.append(" unexpected keys %s" % str(extra))
		_output_error("Invalid Keys", " ".join(strs))
		return false
	for s in to_add.keys(): # Handle optional values
		dict[s] = to_add[s]
	return true

static func _type_name(type: int) -> String:
	match type:
		TYPE_NIL: return "NULL"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
	return "??"

static func _expect_gui_type(dict: Dictionary, key: String, type: int, custom_name := "") -> bool:
	return _expect_type("Type '%s'" % dict.get("type", "NULL"),  dict, key, type, custom_name)
static func _expect_type(pref: String, dict: Dictionary, key: String, type: int, custom_name := "") -> bool:
	if type == TYPE_INT:
		var v = dict.get(key)
		if v is float and _check_int(v):
			dict[key] = roundi(v)
	if typeof(dict.get(key)) != type:
		if custom_name.is_empty():
			custom_name = _type_name(type)
		_output_error("Invalid Key Type", "%s expected '%s' to be '%s'!" % [pref, key, custom_name])
		return false
	return true

static func _expect_gui_color(dict: Dictionary, key: String, allow_default := false) -> bool:
	return _expect_color("Type '%s'" % dict.get("type", "NULL"), dict, key, allow_default)
static func _expect_color(pref: String, dict: Dictionary, key: String, allow_default := false) -> bool:
	if not _expect_type(pref, dict, key, TYPE_STRING, "ColorName"):
		return false
	var cname = dict.get(key)
	if allow_default and cname == "default": return true
	if AP.color_from_name(cname, Color.WHITE) == Color.WHITE and \
		AP.color_from_name(cname, Color.BLACK) == Color.BLACK:
		TrackerPack_Base._output_error("Invalid Color", "%s: Color '%s' could not be parsed as a color!" % [pref, cname])
		return false
	return true

static var size_flags_by_name := {
	"FILL": Control.SIZE_FILL,
	"EXPAND": Control.SIZE_EXPAND,
	"EXPAND_FILL": Control.SIZE_EXPAND_FILL,
	"SHRINK_BEGIN": Control.SIZE_SHRINK_BEGIN,
	"SHRINK_CENTER": Control.SIZE_SHRINK_CENTER,
	"SHRINK_END": Control.SIZE_SHRINK_END,
}
static func _expect_gui_size_flag(dict: Dictionary, key: String) -> bool:
	return _expect_size_flag("Type '%s'" % dict.get("type", "NULL"), dict, key)
static func _expect_size_flag(pref: String, dict: Dictionary, key: String) -> bool:
	if not _expect_type(pref, dict, key, TYPE_STRING, "SizeFlag"):
		return false
	if not (dict[key] in size_flags_by_name.keys()):
		TrackerPack_Base._output_error("Invalid SizeFlag", "Type '%s': Value '%s' is not one of %s!" % [dict.get("type", "NULL"), dict[key], size_flags_by_name.keys()])
		return false
	return true

static func get_size_flag(name: String) -> int:
	return size_flags_by_name.get(name, Control.SIZE_EXPAND_FILL)

static var draw_filters_by_name := {
	"INHERIT": CanvasItem.TEXTURE_FILTER_PARENT_NODE,
	"LINEAR": CanvasItem.TEXTURE_FILTER_LINEAR,
	"NEAREST": CanvasItem.TEXTURE_FILTER_NEAREST,
}
static func _expect_gui_drawfilter(dict: Dictionary, key: String) -> bool:
	return _expect_drawfilter("Type '%s'" % dict.get("type", "NULL"), dict, key)
static func _expect_drawfilter(pref: String, dict: Dictionary, key: String) -> bool:
	if not _expect_type(pref, dict, key, TYPE_STRING, "DrawFilter"):
		return false
	if not (dict[key] in draw_filters_by_name.keys()):
		TrackerPack_Base._output_error("Invalid DrawFilter", "Type '%s': Value '%s' is not one of %s!" % [dict.get("type", "NULL"), dict[key], draw_filters_by_name.keys()])
		return false
	return true

static func get_draw_filter(name: String) -> CanvasItem.TextureFilter:
	return draw_filters_by_name.get(name, CanvasItem.TEXTURE_FILTER_PARENT_NODE)

static func _check_int(val: Variant) -> bool:
	return val is int or (val is float and Util.approx_eq(val, roundi(val)))
