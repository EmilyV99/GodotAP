class_name TrackerLogicAll extends TrackerLogicNode

var rules: Array[TrackerLogicNode] = []

func can_access() -> bool:
	for rule in rules:
		if not rule.can_access():
			return false
	return true

func add(rule: TrackerLogicNode) -> TrackerLogicAll:
	rules.append(rule)
	return self

func _to_dict() -> Dictionary:
	var rule_arr = []
	for rule in rules:
		rule_arr.append(rule._to_dict())
	return {
		"type": "ALL",
		"rules": rule_arr,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "ALL": return TrackerLogicNode.from_dict(vals)
	var ret := TrackerLogicAll.new()
	for data in vals.get("rules", []):
		var node := TrackerLogicNode.from_dict(data)
		if node:
			ret.add(node)
	return ret
