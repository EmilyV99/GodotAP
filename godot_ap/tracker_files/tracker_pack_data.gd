class_name TrackerPack_Data extends TrackerPack_Base

func get_type() -> String: return "DATA_PACK"
# TODO set up a structure for listing location reqs, map images, etc etc
var locations: Array[TrackerLocation] = []
var named_rules: Dictionary = {}
var statuses: Array[LocationStatus] = []
var statuses_by_name: Dictionary = {}
var starting_variables: Dictionary = {}

var _variable_ops: Dictionary = {}

var description_bar: String = ""
var description_ttip: String = ""

func instantiate() -> TrackerScene_Base:
	var scene: TrackerScene_Default = load("res://godot_ap/tracker_files/default_tracker.tscn").instantiate()
	scene.datapack = self
	scene.item_register.connect(register_item)
	TrackerTab.variables.clear()
	TrackerTab.variables.merge(starting_variables)
	if description_bar.is_empty():
		scene.labeltext = "Showing DataTracker for '%s'" % game
	else:
		scene.labeltext = description_bar
	if not description_ttip.is_empty():
		scene.labelttip = description_ttip
	
	TrackerTab.load_tracker_locations(locations)
	TrackerTab.load_named_rules(named_rules)
	TrackerTab.load_statuses(statuses)
	return scene

signal _item_register(name: String)
func register_item(name: String) -> void:
	_item_register.emit(name)

func _save_file(data: Dictionary) -> Error:
	var err := super(data)
	if err: return err
	var loc_vals: Array[Dictionary] = []
	for loc in locations:
		loc_vals.append(loc.save_dict())
	var stat_vals: Array[Dictionary] = []
	for stat in statuses:
		if stat.text == "Not Found" and stat.tooltip.is_empty() and stat.colorname == "red":
			continue
		stat_vals.append(stat.save_dict())
	data["description_bar"] = description_bar
	data["description_ttip"] = description_ttip
	data["statuses"] = stat_vals
	data["locations"] = loc_vals
	var rules_dict = {}
	for name in named_rules.keys():
		rules_dict[name] = named_rules[name]._to_json_val()
	data["named_rules"] = rules_dict
	data["variables"] = _variable_ops
	return OK

func _load_file(json: Dictionary) -> Error:
	var err := super(json)
	if err: return err
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
		named_rules[name] = TrackerLogicNode.from_json_val(dict[name])
	
	_variable_ops = json.get("variables", {})
	for varname in _variable_ops.keys():
		var varvals: Dictionary = _variable_ops[varname]
		starting_variables[varname] = varvals.get("value", 0)
		var itemtrigs: Dictionary = varvals.get("item_triggers", {})
		for iname in itemtrigs.keys():
			var op: Dictionary = itemtrigs[iname]
			match op.get("type"):
				"+":
					_item_register.connect(func(name):
						if name == iname:
							TrackerTab.variables[varname] += op.get("value", 0))
				"-":
					_item_register.connect(func(name):
						if name == iname:
							TrackerTab.variables[varname] -= op.get("value", 0))
				"*":
					_item_register.connect(func(name):
						if name == iname:
							TrackerTab.variables[varname] *= op.get("value", 1))
				"/":
					_item_register.connect(func(name):
						if name == iname:
							TrackerTab.variables[varname] /= op.get("value", 1))
		
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
	
	var to_add = []
	var by_name = {}
	for js in status_json:
		var name: String = js.get("name", "")
		if name.is_empty(): continue
		to_add.append(LocationStatus.new(name, js.get("ttip", ""), js.get("color", "white")))
		by_name[name] = to_add.back()
	
	var found = by_name.get("Found")
	if not found:
		to_add.push_front(LocationStatus.ACCESS_FOUND)
		found = 0
	else:
		found = to_add.find(found)
	
	var unknown = by_name.get("Unknown")
	if not unknown:
		to_add.insert(found+1, LocationStatus.ACCESS_UNKNOWN)
		unknown = found+1
	else:
		unknown = to_add.find(unknown)
	
	var unreachable = by_name.get("Unreachable")
	if not unreachable:
		to_add.insert(unknown+1, LocationStatus.ACCESS_UNREACHABLE)
		unreachable = unknown+1
	else:
		unreachable = to_add.find(unreachable)
	
	var not_found = by_name.get("Not Found")
	if not not_found:
		to_add.insert(unreachable+1, LocationStatus.ACCESS_NOT_FOUND)
		not_found = unreachable+1
	else:
		not_found = to_add.find(not_found)
	
	var logic_break = by_name.get("Out of Logic")
	if not logic_break:
		to_add.insert(not_found+1, LocationStatus.ACCESS_LOGIC_BREAK)
		logic_break = not_found+1
	else:
		logic_break = to_add.find(logic_break)
	
	var reachable = by_name.get("Out of Logic")
	if not reachable:
		to_add.insert(logic_break+1, LocationStatus.ACCESS_REACHABLE)
		reachable = logic_break+1
	else:
		reachable = to_add.find(reachable)
	
	var q := 0
	for stat in to_add:
		stat.id = q
		statuses.append(stat)
		statuses_by_name[stat.text] = stat
		q += 1
