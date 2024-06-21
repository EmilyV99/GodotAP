class_name TrackerLocation

var identifier ## int id or String name
var rule: TrackerLogicNode

func get_loc() -> APLocation:
	if identifier is int:
		return TrackerTab.get_location(identifier)
	elif identifier is String:
		return TrackerTab.get_loc_by_name(identifier)
	return APLocation.nil()

func can_access() -> bool:
	return rule.can_access() if rule else true

static func make_id(id: int, new_rule: TrackerLogicNode = null) -> TrackerLocation:
	var ret := TrackerLocation.new()
	ret.identifier = id
	ret.rule = new_rule if new_rule else TrackerLogicNode.new()
	return ret
static func make_name(name: String, new_rule: TrackerLogicNode = null) -> TrackerLocation:
	var ret := TrackerLocation.new()
	ret.identifier = name
	ret.rule = new_rule if new_rule else TrackerLogicNode.new()
	return ret

func save_dict() -> Dictionary:
	return {"id": identifier, "rule": rule._to_dict()}

static func load_dict(s: Dictionary) -> TrackerLocation:
	var id = s.get("id")
	var ret: TrackerLocation = null
	if id is int:
		ret = make_id(id, TrackerLogicNode.from_dict(s.get("rule")))
	elif id is String:
		ret = make_name(id, TrackerLogicNode.from_dict(s.get("rule")))
	return ret

func _to_string():
	return "%s (reqs %s)" % [identifier, rule]
