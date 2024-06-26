class_name TrackerPack_Data extends TrackerPack_Base

static var DEFAULT_GUI = {"type": "Column", "children": [{"type": "LocationConsole"}]}

func get_type() -> String: return "DATA_PACK"
# TODO set up a structure for listing location reqs, map images, etc etc
var locations: Array[TrackerLocation] = []
var named_rules: Dictionary = {}
var named_values: Dictionary = {}
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
	
	var type = elem.get("type")
	#region Handle optional values that are always present
	var global_optionals := {"halign": "EXPAND_FILL", "valign": "EXPAND_FILL"}
	match type:
		"Label":
			global_optionals["halign"] = "SHRINK_CENTER"
			global_optionals["valign"] = "SHRINK_CENTER"
	
	elem.merge(global_optionals)
	if not TrackerPack_Base._expect_size_flag(elem, "halign"):
		return false
	if not TrackerPack_Base._expect_size_flag(elem, "valign"):
		return false
	#endregion
	match type:
		"Column", "Row":
			if not TrackerPack_Base._expect_keys(elem, ["children", "type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "children", TYPE_ARRAY):
				return false
			for child in elem.get("children"):
				if not validate_gui_element(child):
					return false
			return true
		"Grid":
			if not TrackerPack_Base._expect_keys(elem, ["children", "columns",
				"type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "columns", TYPE_INT):
				return false
			if elem.get("columns") < 1:
				elem["columns"] = 1
			if not TrackerPack_Base._expect_type(elem, "children", TYPE_ARRAY):
				return false
			for child in elem.get("children"):
				if not validate_gui_element(child):
					return false
			return true
		"HSplit", "VSplit":
			if not TrackerPack_Base._expect_keys(elem, ["children", "type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "children", TYPE_ARRAY):
				return false
			var children = elem.get("children")
			if children.size() > 2:
				TrackerPack_Base._output_error("Invalid Array Size", "Type '%s' expected 'children' to be size 2 or less!" % type)
				return false
			for child in children:
				if not validate_gui_element(child):
					return false
			return true
		"Margin":
			if not TrackerPack_Base._expect_keys(elem, ["bottom", "child",
				"color", "left", "right", "top", "type", "halign", "valign"]):
				return false
			var child = elem.get("child")
			if not validate_gui_element(child):
				return false
			for side in ["top","bottom","left","right"]:
				if not TrackerPack_Base._expect_type(elem, side, TYPE_INT):
					return false
			if not TrackerPack_Base._expect_color(elem, "color"):
				return false
			return true
		"Tabs":
			if not TrackerPack_Base._expect_keys(elem, ["tabs", "type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "tabs", TYPE_DICTIONARY):
				return false
			for child in elem.get("tabs").values():
				if not validate_gui_element(child):
					return false
			return true
		"LocationConsole":
			if not TrackerPack_Base._expect_keys(elem, ["hint_status", "type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "hint_status", TYPE_BOOL):
				return false
			return true
		"ItemConsole":
			if not TrackerPack_Base._expect_keys(elem, ["show_index", "show_percent",
				"show_totals", "type", "values", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "show_totals", TYPE_BOOL):
				return false
			if not TrackerPack_Base._expect_type(elem, "show_index", TYPE_BOOL):
				return false
			if not TrackerPack_Base._expect_type(elem, "show_percent", TYPE_BOOL):
				return false
			if not TrackerPack_Base._expect_type(elem, "values", TYPE_ARRAY):
				return false
			for val in elem.get("values"):
				var valty = val.get("type")
				match valty:
					"ITEM":
						var name = val.get("name")
						if not name is String:
							TrackerPack_Base._output_error("Invalid ItemConsole Key", "Type '%s' expected 'name' to be 'String'!" % valty)
							return false
						if not TrackerPack_Base._check_int(val.get("flags")):
							TrackerPack_Base._output_error("Invalid ItemConsole Key", "Type '%s' expected 'flags' to be 'int'!" % valty)
							return false
						var total = val.get("total")
						if total != null and TrackerValueNode.from_json_val(total) == null:
							TrackerPack_Base._output_error("Invalid ValueNode", "DISPLAY_VAR '%s' encounted bad 'total' ValueNode!" % name)
							return false
					"DISPLAY_VAR":
						var name = val.get("name")
						if not name is String:
							TrackerPack_Base._output_error("Invalid ItemConsole Key", "Type '%s' expected 'name' to be 'String'!" % valty)
							return false
						var count = val.get("count")
						if TrackerValueNode.from_json_val(count) == null:
							TrackerPack_Base._output_error("Invalid ValueNode", "DISPLAY_VAR '%s' encounted bad 'count' ValueNode!" % name)
							return false
						var total = val.get("total")
						if total != null and TrackerValueNode.from_json_val(total) == null:
							TrackerPack_Base._output_error("Invalid ValueNode", "DISPLAY_VAR '%s' encounted bad 'total' ValueNode!" % name)
							return false
						if val.get("tooltip") != null and not val.get("tooltip") is String:
							TrackerPack_Base._output_error("Invalid ItemConsole Key", "Type '%s' expected 'tooltip' to be 'null' or 'String'!" % valty)
							return false
						if val.get("color") != null and not val.get("color") is String:
							TrackerPack_Base._output_error("Invalid ItemConsole Key", "Type '%s' expected 'tooltip' to be 'null' or 'ColorName'!" % valty)
							return false
					_:
						TrackerPack_Base._output_error("Invalid ItemConsole Value", "Expected 'ITEM' or 'DISPLAY_VAR', not '%s'" % str(valty))
						return false
			return true
		"LocationMap":
			if not TrackerPack_Base._expect_keys(elem, ["id", "image",
				"some_reachable_color", "type", "halign", "valign"]):
				return false
			if not TrackerPack_Base._expect_type(elem, "id", TYPE_STRING):
				return false
			if not TrackerPack_Base._expect_type(elem, "image", TYPE_STRING):
				return false
			if not TrackerPack_Base._expect_type(elem, "some_reachable_color", TYPE_STRING):
				return false
			return true
		"Label":
			if not TrackerPack_Base._expect_keys(elem, ["size", "text", "type",
				"halign", "valign"], {"color": "white"}):
				return false
			if not TrackerPack_Base._expect_type(elem, "size", TYPE_INT):
				return false
			if elem["size"] < 0:
				elem["size"] = absi(elem["size"])
			elif elem["size"] == 0:
				elem["size"] = 20
			if not TrackerPack_Base._expect_type(elem, "text", TYPE_STRING):
				return false
			if not TrackerPack_Base._expect_color(elem, "color"):
				return false
			return true
		null:
			elem["type"] = "Empty"
			if not TrackerPack_Base._expect_keys(elem, ["type", "halign", "valign"]):
				elem.erase("type")
				return false
			elem.erase("type")
			return true
		_:
			TrackerPack_Base._output_error("Unrecognized Type", "Type '%s' is not recognized as a valid GUI object type!" % type)
			return false
func _instantiate_gui_element(elem: Dictionary) -> Node:
	if elem.is_empty(): return null
	var type = elem.get("type")
	match type:
		"Column":
			var cont := VBoxContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"Row":
			var cont := HBoxContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"Grid":
			var cont := GridContainer.new()
			cont.columns = elem.get("columns", 2)
			cont.add_theme_constant_override("h_separation", 0)
			cont.add_theme_constant_override("v_separation", 0)
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"HSplit":
			var cont := HSplitContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			var children: Array = elem.get("children")
			for child in children:
				var child_elem = _instantiate_gui_element(child)
				if child_elem:
					cont.add_child(child_elem)
			return cont
		"VSplit":
			var cont := VSplitContainer.new()
			cont.add_theme_constant_override("separation", 0)
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
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
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
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
			cont.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			cont.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
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
			scene.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			scene.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			scene.show_hint_status = elem["hint_status"]
			return scene
		"ItemConsole":
			var scene: TrackerScene_ItemDefault = load("res://godot_ap/tracker_files/default_item_tracker.tscn").instantiate()
			scene.datapack = self
			scene.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			scene.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			scene.show_totals = elem["show_totals"]
			scene.base_values.assign(elem["values"])
			return scene
		"LocationMap":
			var scene: TrackerScene_Map = load("res://godot_ap/tracker_files/map_tracker.tscn").instantiate()
			scene.datapack = self
			scene.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			scene.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			scene.image_path = elem.get("image")
			scene.map_id = elem.get("id")
			scene.some_reachable_color = elem.get("some_reachable_color")
			return scene
		"Label":
			var lbl := Label.new()
			lbl.text = elem["text"]
			var ls = LabelSettings.new()
			lbl.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "SHRINK_CENTER"))
			lbl.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "SHRINK_CENTER"))
			var font: SystemFont = load("res://godot_ap/ui/console_font.tres")
			ls.font = font
			ls.font_size = elem["size"]
			ls.font_color = AP.color_from_name(elem.get("color", "white"), Color.WHITE)
			lbl.label_settings = ls
			return lbl
		null:
			var node := Control.new()
			node.size_flags_horizontal = TrackerPack_Base.get_size_flag(elem.get("halign", "EXPAND_FILL"))
			node.size_flags_vertical = TrackerPack_Base.get_size_flag(elem.get("valign", "EXPAND_FILL"))
			return node
	assert(false)
	return null
func instantiate() -> TrackerScene_Root:
	var scene := TrackerScene_Root.new()
	scene.item_register.connect(register_item)
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
	TrackerManager.load_named_values(named_values)
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
	var vals_dict = {}
	for name in named_values.keys():
		vals_dict[name] = named_values[name]._to_json_val()
	data["named_values"] = vals_dict
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
	var name_dict: Dictionary = json.get("named_rules", {})
	for name in name_dict.keys():
		named_rules[name] = TrackerLogicNode.from_json_val(name_dict[name])
	named_values.clear()
	var val_dict: Dictionary = json.get("named_values", {})
	for name in val_dict.keys():
		named_values[name] = TrackerValueNode.from_json_val(val_dict[name])
	
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

func set_named_val(name: String, val: TrackerValueNode) -> void:
	if not val:
		named_values.erase(name)
	else: named_values[name] = val

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
