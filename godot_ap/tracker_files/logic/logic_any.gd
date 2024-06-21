class_name TrackerLogicAny extends TrackerLogicNode

var rules: Array[TrackerLogicNode] = []

func can_access() -> bool:
	for rule in rules:
		if rule.can_access():
			return true
	return false

func add(rule: TrackerLogicNode) -> TrackerLogicAny:
	rules.append(rule)
	return self

func _to_dict() -> Dictionary:
	var rule_arr = []
	for rule in rules:
		rule_arr.append(rule._to_dict())
	return {
		"type": "ANY",
		"rules": rule_arr,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "ANY": return TrackerLogicNode.from_dict(vals)
	var ret := TrackerLogicAny.new()
	for data in vals.get("rules", []):
		var node := TrackerLogicNode.from_dict(data)
		if node:
			ret.add(node)
	return ret
