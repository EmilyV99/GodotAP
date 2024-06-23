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
		return TrackerTab.get_location(identifier)
	elif identifier is String:
		return TrackerTab.get_loc_by_name(identifier)
	return APLocation.nil()

func get_status() -> String:
	if status_rules.is_empty():
		return "Unknown"
	var statuses_in_order
	if pack is TrackerPack_Data:
		statuses_in_order = pack.statuses
	else:
		statuses_in_order = [LocationStatus.ACCESS_UNKNOWN,LocationStatus.ACCESS_FOUND,LocationStatus.ACCESS_UNREACHABLE,LocationStatus.ACCESS_LOGIC_BREAK,LocationStatus.ACCESS_REACHABLE]
	var found_something := false
	for status in Util.reversed(statuses_in_order):
		var rule: TrackerLogicNode = status_rules.get(status.text)
		if not rule: continue
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
	var ret := TrackerLocation.new()
	ret.identifier = id
	return ret
static func make_name(name: String) -> TrackerLocation:
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
	for k in status_rules.keys():
		if k == "Found": continue
		data[k] = status_rules[k]._to_json_val()
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
			for status in parent.statuses_by_name.keys():
				if status in ["Found","Unreachable"]: continue
				var rule = TrackerLogicNode.from_json_val(s.get(status))
				if rule:
					ret.add_rule(status, rule)
			ret.add_rule("Found", TrackerLogicLocCollected.make(ret.identifier))
	return ret

func _to_string():
	return "%s (reqs %s)" % [identifier, status_rules]

func get_loc_name() -> String:
	return TrackerTab.get_location(identifier).get_display_name()
