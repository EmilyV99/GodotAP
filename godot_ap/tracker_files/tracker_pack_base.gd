class_name TrackerPack_Base

func get_type() -> String: return "BASE_PACK"

var saved_path: String = ""

var game: String

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
		var ret := load_json_string(text, reader)
		if ret: ret.saved_path = path
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
		var ret := load_json_string(text, dir)
		if ret: ret.saved_path = path
		return ret
	else:
		load_error = "Unrecognized Extension"
		return null

static func load_json_string(text: String, _environment: Variant) -> TrackerPack_Base:
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
	Archipelago.output_console.add_line(s, ttip, Archipelago.rich_colors["red"])
	AP.log(s)
	if not ttip.is_empty():
		AP.log(ttip)
static func _expect_keys(dict: Dictionary, expected: Array[String]):
	var found: Array[String] = []
	found.assign(dict.keys())
	found.sort()
	if found != expected:
		_output_error("Invalid Keys", "Type '%s' expected keys %s, not %s!" % [dict.get("type", "NULL"), expected, found])
		return false
	return true
