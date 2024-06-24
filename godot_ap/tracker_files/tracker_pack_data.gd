class_name TrackerPack_Data extends TrackerPack_Base

static var DEFAULT_GUI = {"type": "Column", "children": [{"type": "LocationConsole"}]}

func get_type() -> String: return "DATA_PACK"
# TODO set up a structure for listing location reqs, map images, etc etc
var locations: Array[TrackerLocation] = []
var named_rules: Dictionary = {}
var statuses: Array[LocationStatus] = []
var statuses_by_name: Dictionary = {}
var starting_variables: Dictionary = {}

var gui_layout: Dictionary = TrackerPack_Data.DEFAULT_GUI.duplicate(true)

var _variable_ops: Dictionary = {}

var description_bar: String = ""
var description_ttip: String = ""

func validate_gui_element(elem) -> bool:
	if not elem is Dictionary:
		TrackerPack_Base._output_error("Bad element!", "Found a non-Dictionary type when looking for a gui element!")
		return false
	if elem.is_empty(): return true
	var type = elem.get("type")
	match type:
		"Column", "Row":
			if not TrackerPack_Base._expect_keys(elem, ["children","type"]):
				return false
			var children = elem.get("children")
			if not children is Array:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'children' to be 'Array'!" % type)
				return false
			for child in children:
				if not validate_gui_element(child):
					return false
			return true
		"HSplit", "VSplit":
			if not TrackerPack_Base._expect_keys(elem, ["children","type"]):
				return false
			var children = elem.get("children")
			if not children is Array:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'children' to be 'Array'!" % type)
				return false
			if children.size() > 2:
				TrackerPack_Base._output_error("Invalid Array Size", "Type '%s' expected 'children' to be size 2 or less!" % type)
				return false
			for child in children:
				if not validate_gui_element(child):
					return false
			return true
		"Margin":
			if not TrackerPack_Base._expect_keys(elem, ["bottom","child","color","left","right","top","type"]):
				return false
			var child = elem.get("child")
			if not validate_gui_element(child):
				return false
			for side in ["top","bottom","left","right"]:
				var val = elem.get(side)
				if not (val is int or (val is float and (Util.approx_eq(roundi(val),val)))):
					TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected '%s' to be 'int'!" % [side,type])
					return false
			var colname = elem.get("color")
			if not colname is String:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'color' to be 'String'!" % type)
				return false
			if AP.color_from_name(colname, Color.WHITE) == Color.WHITE and \
				AP.color_from_name(colname, Color.BLACK) == Color.BLACK:
				TrackerPack_Base._output_error("Invalid Color", "Color '%s' could not be parsed as a color!" % colname)
				return false
			return true
		"Tabs":
			if not TrackerPack_Base._expect_keys(elem, ["tabs","type"]):
				return false
			var tabs = elem.get("tabs")
			if not tabs is Dictionary:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'tabs' to be 'Dictionary'!" % type)
				return false
			for child in tabs.values():
				if not validate_gui_element(child):
					return false
			return true
		"LocationConsole":
			if not TrackerPack_Base._expect_keys(elem, ["hint_status", "type"]):
				return false
			if not elem.get("hint_status") is bool:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'hint_status' to be 'bool'!" % type)
				return false
			return true
		"LocationMap":
			if not TrackerPack_Base._expect_keys(elem, ["id", "image", "some_reachable_color", "type"]):
				return false
			if not elem.get("id") is String:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'id' to be 'String'!" % type)
				return false
			if not elem.get("image") is String:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'image' to be 'String'!" % type)
				return false
			if not elem.get("some_reachable_color") is String:
				TrackerPack_Base._output_error("Invalid Key Type", "Type '%s' expected 'some_reachable_color' to be 'String'!" % type)
				return false
			return true
		_:
			if type == null:
				TrackerPack_Base._output_error("No Type Specified", "Object requires 'type' field!")
			else:
				TrackerPack_Base._output_error("Unrecognized Type", "Type '%s' is not recognized as a valid GUI object type!" % type)
			return false
func _instantiate_gui_element(elem: Dictionary) -> Node:
	if elem.is_empty(): return null
	var type = elem.get("type")
	match type:
		"Column":
			var cont := VBoxContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"Row":
			var cont := HBoxContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"HSplit":
			var cont := HSplitContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"VSplit":
			var cont := VSplitContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"Margin":
			var cont := MarginContainer.new()
			var colorrect := ColorRect.new()
			var color_name: String = elem["color"]
			colorrect.color = AP.color_from_name(color_name, AP.color_from_name("default"))
			cont.add_child(colorrect)
			var inner_cont := MarginContainer.new()
			cont.add_child(inner_cont)
			var sides = ["top","bottom","left","right"]
			for side in sides:
				cont.add_theme_constant_override("margin_%s" % side, 0)
				inner_cont.add_theme_constant_override("margin_%s" % side, elem.get(side))
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			colorrect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			colorrect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			inner_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inner_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var child_elem = _instantiate_gui_element(elem.get("child"))
			if child_elem:
				inner_cont.add_child(child_elem)
			return cont
		"Tabs":
			var cont := TabContainer.new()
			cont.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var bg_box := StyleBoxFlat.new()
			bg_box.bg_color = Color8(0x2C,0x2C,0x2C)
			cont.add_theme_stylebox_override("tabbar_background", bg_box)
			cont.tab_focus_mode = Control.FOCUS_NONE
			cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var tabs: Dictionary = elem.get("tabs")
			for tabname in tabs.keys():
				var child_elem = _instantiate_gui_element(tabs[tabname])
				if child_elem:
					cont.add_child(child_elem)
					child_elem.name = tabname
			return cont
		"LocationConsole":
			var scene: TrackerScene_Default = load("res://godot_ap/tracker_files/default_tracker.tscn").instantiate()
			scene.datapack = self
			scene.item_register.connect(register_item)
			scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scene.show_hint_status = elem["hint_status"]
			return scene
		"LocationMap":
			var scene: TrackerScene_Map = load("res://godot_ap/tracker_files/map_tracker.tscn").instantiate()
			scene.datapack = self
			scene.item_register.connect(register_item)
			scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scene.image_path = elem.get("image")
			scene.map_id = elem.get("id")
			scene.some_reachable_color = elem.get("some_reachable_color")
			return scene
	assert(false)
	return null
func instantiate() -> TrackerScene_Root:
	var scene := TrackerScene_Root.new()
	if description_bar.is_empty():
		scene.labeltext = "Showing DataTracker for '%s'" % game
	else:
		scene.labeltext = description_bar
	if not description_ttip.is_empty():
		scene.labelttip = description_ttip
	TrackerManager.variables.clear()
	TrackerManager.variables.merge(starting_variables)
	TrackerManager.load_tracker_locations(locations)
	TrackerManager.load_named_rules(named_rules)
	TrackerManager.load_statuses(statuses)
	
	if gui_layout.is_empty():
		gui_layout = TrackerPack_Data.DEFAULT_GUI.duplicate(true)
	var child_elem = _instantiate_gui_element(gui_layout)
	if child_elem:
		scene.add_child(child_elem)
	
	
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
	data["GUI"] = gui_layout
	data["statuses"] = stat_vals
	data["locations"] = loc_vals
	var rules_dict = {}
	for name in named_rules.keys():
		rules_dict[name] = named_rules[name]._to_json_val()
	data["named_rules"] = rules_dict
	data["variables"] = _variable_ops
	return OK

func validate_gui() -> bool:
	return validate_gui_element(gui_layout)
func _load_file(json: Dictionary) -> Error:
	var err := super(json)
	if err: return err
	var ret := OK
	description_bar = json.get("description_bar", "")
	description_ttip = json.get("description_ttip", "")
	gui_layout = json.get("GUI", TrackerPack_Data.DEFAULT_GUI)
	if not validate_gui():
		ret = ERR_INVALID_DATA
	setup_statuses(json.get("statuses", []))
	var vals: Array[Dictionary] = []
	vals.assign(json.get("locations", []))
	locations.clear()
	for v in vals:
		var loc := TrackerLocation.load_dict(v, self)
		if loc: locations.append(loc)
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
							TrackerManager.variables[varname] += op.get("value", 0))
				"-":
					_item_register.connect(func(name):
						if name == iname:
							TrackerManager.variables[varname] -= op.get("value", 0))
				"*":
					_item_register.connect(func(name):
						if name == iname:
							TrackerManager.variables[varname] *= op.get("value", 1))
				"/":
					_item_register.connect(func(name):
						if name == iname:
							TrackerManager.variables[varname] /= op.get("value", 1))
		
	return ret

func get_or_create_loc(identifier) -> TrackerLocation:
	for loc in locations:
		if loc.identifier == identifier:
			return loc
	var ret := TrackerLocation.make_id(identifier) if identifier is int else TrackerLocation.make_name(identifier)
	if ret: locations.append(ret)
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
		var color = js.get("color", "white")
		to_add.append(LocationStatus.new(name, js.get("ttip", ""), color, js.get("map_color", color)))
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
	
	var reachable = by_name.get("Reachable")
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
