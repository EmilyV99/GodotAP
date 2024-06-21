class_name TrackerPack_Data extends TrackerPack_Base

func get_type() -> String: return "DATA_PACK"
# TODO set up a structure for listing location reqs, map images, etc etc
var locations: Array[TrackerLocation] = []
var named_rules: Dictionary = {}
var statuses: Array[LocationStatus] = []
var statuses_by_name: Dictionary = {}
var default_access := true

var description_bar: String = ""
var description_ttip: String = ""

func instantiate() -> TrackerScene_Base:
	var scene: TrackerScene_Default = load("res://godot_ap/tracker_files/default_tracker.tscn").instantiate()
	scene.datapack = self
	if description_bar.is_empty():
		scene.labeltext = "Showing DataTracker for '%s'" % game
	else:
		scene.labeltext = description_bar
	if not description_ttip.is_empty():
		scene.labelttip = description_ttip
	
	TrackerTab.load_tracker_locations(locations)
	TrackerTab.load_named_rules(named_rules)
	TrackerTab.load_statuses(statuses)
	TrackerTab.default_access = default_access
	return scene

func save_as(path: String) -> Error:
	if not path.ends_with(".json"):
		path += ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	return save_file(file)

func save_file(file: FileAccess) -> Error:
	return save_json_file(file)
func _save_json_file(data: Dictionary) -> Error:
	var err := super(data)
	if err: return err
	var loc_vals: Array[Dictionary] = []
	for loc in locations:
		loc_vals.append(loc.save_dict())
	var stat_vals: Array[Dictionary] = []
	for stat in statuses:
		stat_vals.append(stat.save_dict())
	data["description_bar"] = description_bar
	data["description_ttip"] = description_ttip
	data["default"] = default_access
	data["statuses"] = stat_vals
	data["locations"] = loc_vals
	var rules_dict = {}
	for name in named_rules.keys():
		rules_dict[name] = named_rules[name]._to_dict()
	data["named_rules"] = rules_dict
	return OK

func _load_file(_file: FileAccess) -> Error:
	return ERR_INVALID_DATA

func _load_json_file(json: Dictionary) -> Error:
	var err := super(json)
	if err: return err
	default_access = json.get("default_access", true)
	description_bar = json.get("description_bar", "")
	description_ttip = json.get("description_ttip", "")
	setup_statuses(json.get("statuses", []))
	var vals: Array[Dictionary] = []
	vals.assign(json.get("locations", []))
	locations.clear()
	for v in vals:
		locations.append(TrackerLocation.load_dict(v, self))
	named_rules.clear()
	var dict: Dictionary = json.get("named_rules", {})
	for name in dict.keys():
		named_rules[name] = TrackerLogicNode.from_dict(dict[name])
	return OK

func get_or_create_loc(identifier) -> TrackerLocation:
	for loc in locations:
		if loc.identifier == identifier:
			return loc
	var ret := TrackerLocation.make_id(identifier) if identifier is int else TrackerLocation.make_name(identifier)
	locations.append(ret)
	return ret

func set_named_rule(name: String, rule: TrackerLogicNode) -> void:
	if not rule:
		named_rules.erase(name)
	else: named_rules[name] = rule

func _to_string():
	return ("TrackerPack_Data(game=%s, locations=%s, named_rules=%s)" % [game,
		JSON.stringify(locations, "\t"), JSON.stringify(named_rules, "\t")]).replace("\\\"", "\"")


func setup_statuses(status_json: Array) -> void:
	statuses.clear()
	statuses_by_name.clear()
	var pre_add = [LocationStatus.ACCESS_FOUND, LocationStatus.ACCESS_UNREACHABLE]
	var post_add = [LocationStatus.ACCESS_LOGIC_BREAK, LocationStatus.ACCESS_REACHABLE]
	for stat in status_json:
		for v in pre_add:
			if stat.get("name", "") == v.text:
				pre_add.erase(v)
		for v in post_add:
			if stat.get("name", "") == v.text:
				post_add.erase(v)
	var q := 0
	for stat in pre_add:
		stat.id = q
		statuses.append(stat)
		statuses_by_name[stat.text] = stat
		q += 1
	for js in status_json:
		var name: String = js.get("name", "")
		if name.is_empty(): continue
		var stat := LocationStatus.new(name, js.get("ttip", ""), js.get("color", "white"))
		stat.id = q
		statuses.append(stat)
		statuses_by_name[stat.text] = stat
		q += 1
	for stat in post_add:
		stat.id = q
		statuses.append(stat)
		statuses_by_name[stat.text] = stat
		q += 1
