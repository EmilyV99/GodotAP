class_name TrackerLocation

var identifier ## int id or String name
var descriptive_name: String = ""
var status_rules: Dictionary
var map_spots: Array[MapSpot] = []

var pack: TrackerPack_Base

class MapSpot:
	var id: String
	var x: int
	var y: int
	func _to_dict() -> Dictionary:
		return {"id": id, "x": x, "y": y}
	static func from_dict(dict: Dictionary) -> MapSpot:
		var ret := MapSpot.new()
		ret.id = dict.get("id", "")
		ret.x = dict.get("x", 0)
		ret.y = dict.get("y", 0)
		return ret

func get_loc() -> APLocation:
	if identifier is int:
		return TrackerManager.get_location(identifier)
	elif identifier is String:
		return TrackerManager.get_loc_by_name(identifier)
	return APLocation.nil()

func _iter_statuses(only_relevant := true) -> Array[LocationStatus]:
	var s
	if pack is TrackerPack_Data:
		s = pack.statuses
	else:
		s = [LocationStatus.ACCESS_UNKNOWN,LocationStatus.ACCESS_FOUND,
			LocationStatus.ACCESS_UNREACHABLE,LocationStatus.ACCESS_LOGIC_BREAK,
			LocationStatus.ACCESS_REACHABLE]
	if only_relevant:
		s = s.filter(func(loc: LocationStatus): return loc.text in status_rules.keys())
	return Util.reversed(s)

func get_status() -> String:
	if status_rules.is_empty():
		return "Unknown"
	var found_something := false
	for status in _iter_statuses():
		var rule: TrackerLogicNode = status_rules.get(status.text)
		#if not rule: continue #_iter_statuses handles this case
		var v = rule.can_access()
		if v == null: continue
		if status.text != "Found":
			found_something = true
		if v: return status.text
	if not found_something:
		return "Unknown"
	return "Unreachable"

func add_rule(name: String, rule: TrackerLogicNode):
	status_rules[name] = rule

static func make_id(id: int) -> TrackerLocation:
	if id < 0: return null
	var ret := TrackerLocation.new()
	ret.identifier = id
	return ret
static func make_name(name: String) -> TrackerLocation:
	if name.is_empty(): return null
	var ret := TrackerLocation.new()
	ret.identifier = name
	return ret

func save_dict() -> Dictionary:
	var data: Dictionary = {"id": identifier,"visname": descriptive_name}
	if map_spots:
		var spots: Array = []
		for spot in map_spots:
			spots.append(spot._to_dict())
		data["map_spots"] = spots
	for k in _iter_statuses():
		if k.text == "Found": continue
		data[k.text] = status_rules[k.text]._to_json_val()
	return data

static func load_dict(s: Dictionary, parent: TrackerPack_Base) -> TrackerLocation:
	var id = s.get("id")
	var ret: TrackerLocation = null
	if id is int:
		ret = make_id(id)
	elif id is String:
		ret = make_name(id)
	if ret:
		ret.descriptive_name = s.get("visname", "")
		var spots: Array = s.get("map_spots", [])
		for dict in spots:
			ret.map_spots.append(MapSpot.from_dict(dict))
		ret.pack = parent
		if parent is TrackerPack_Data:
			var dict := s.duplicate()
			dict.erase("id")
			dict.erase("visname")
			dict.erase("map_spots")
			for status in parent.statuses_by_name.keys():
				if status in ["Found","Unreachable","Not Found"]: continue
				var rule = TrackerLogicNode.from_json_val(dict.get(status))
				if rule:
					dict.erase(status)
					ret.add_rule(status, rule)
			ret.add_rule("Found", TrackerLogicLocCollected.make(ret.identifier))
			if dict and Archipelago.config.verbose_trackerpack:
				var src: String = "Location '%s' will ignore its' rule for this status!" % ret.identifier
				for e in dict.keys():
					var txt: String = "Status '%s' has not been defined in the 'statuses' section!" % str(e)
					AP.log(txt)
					if Archipelago.output_console:
						Archipelago.output_console.add_line(txt, src, Archipelago.rich_colors["orange"])
					AP.log("\t"+src)
	else:
		if Archipelago.config.verbose_trackerpack:
			var txt: String = "Error loading location!"
			var src: String = "Must include 'id' of type 'int' >=0 or 'String' non-empty!\n" + JSON.stringify(s, "    ", false)
			AP.log(txt)
			if Archipelago.output_console:
				Archipelago.output_console.add_line(txt, src, Archipelago.rich_colors["orange"])
			AP.log(("    "+src).replace("\n", "\n    "))
	return ret

func _to_string():
	return "%s (reqs %s)" % [identifier, status_rules]

func get_loc_name() -> String:
	var disp_name := TrackerManager.get_location(identifier).get_display_name()
	if disp_name.is_empty():
		return identifier if identifier is String else Archipelago.get_gamedata_for_player().get_loc_name(identifier)
	return disp_name
