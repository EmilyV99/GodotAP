class_name TrackerPack_Base

func get_type() -> String: return "BASE_PACK"

var saved_path: String = ""

var game: String

func instantiate() -> TrackerScene_Base:
	assert(false) # Override with a valid return!
	return null

func save_as(path: String) -> Error:
	if not path.ends_with(".godotap_tracker"):
		path += ".godotap_tracker"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	var ret := save_file(file)
	file.close()
	return ret

func resave() -> Error:
	if not saved_path:
		return ERR_FILE_BAD_PATH
	return save_as(saved_path)

const FILE_KEY := "[GodotAP TrackerPack]"
func save_file(file: FileAccess) -> Error:
	file.store_line(FILE_KEY)
	file.store_line(get_type())
	file.store_line(game)
	return file.get_error()

func save_json_file(file: FileAccess) -> Error:
	var data: Dictionary = {}
	var err := _save_json_file(data)
	if err: return err
	var s := JSON.stringify(data, "\t", false)
	file.store_string(s)
	return file.get_error()
func _save_json_file(data: Dictionary) -> Error:
	data["game"] = game
	data["type"] = get_type()
	return OK
	

static var load_error := ""
static func load_from(path: String) -> TrackerPack_Base:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return null
	return load_file(file)
static func load_file_json(file: FileAccess) -> TrackerPack_Base:
	load_error = ""
	var text := file.get_as_text()
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
	if json.get("game", "").is_empty(): return null
	var type: String = json.get("type", "")
	var ret := _make_type(type)
	if ret:
		if ret._load_json_file(json):
			return null
	return ret
static func load_file(file: FileAccess) -> TrackerPack_Base:
	load_error = ""
	var path := file.get_path()
	if path.ends_with(".json"):
		return load_file_json(file)
	elif not path.ends_with(".godotap_tracker"):
		load_error = "Unrecognized Extension"
		return null
	if file.get_line() != FILE_KEY:
		load_error = "Invalid File Header"
		return null
	var type := file.get_line()
	var ret := _make_type(type)
	if ret:
		if ret._load_file(file):
			load_error = "File load error"
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


func _load_file(file: FileAccess) -> Error:
	game = file.get_line()
	return file.get_error()

func _load_json_file(json: Dictionary) -> Error:
	game = json.get("game", "")
	if game.is_empty(): return ERR_INVALID_DATA
	return OK
