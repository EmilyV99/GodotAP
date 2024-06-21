class_name TrackerLocation

var identifier ## int id or String name
var status_rules: Dictionary
var pack: TrackerPack_Base

func get_loc() -> APLocation:
	if identifier is int:
		return TrackerTab.get_location(identifier)
	elif identifier is String:
		return TrackerTab.get_loc_by_name(identifier)
	return APLocation.nil()

func get_status() -> String:
	if status_rules.is_empty():
		return "Reachable" if TrackerTab.default_access else "Unreachable"
	var statuses_in_order
	if pack is TrackerPack_Data:
		statuses_in_order = pack.statuses
	else:
		statuses_in_order = [LocationStatus.ACCESS_FOUND,LocationStatus.ACCESS_UNREACHABLE,LocationStatus.ACCESS_LOGIC_BREAK,LocationStatus.ACCESS_REACHABLE]
	for status in statuses_in_order:
		var rule: TrackerLogicNode = status_rules.get(status.text)
		if rule and rule.can_access():
			return status
	if TrackerTab.default_access and status_rules.keys() == ["Found"]:
		return "Reachable"
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
	var data: Dictionary = {"id": identifier}
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
