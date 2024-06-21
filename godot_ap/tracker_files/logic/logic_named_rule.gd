class_name TrackerLogicNamedRule extends TrackerLogicNode

var name: String

func _init(rule_name: String) -> void:
	name = rule_name

func can_access() -> bool:
	var rule := TrackerTab.get_named_rule(name)
	if not rule: return TrackerTab.default_access
	return rule.can_access()

func _to_dict() -> Dictionary:
	return {
		"type": "NAMED_RULE",
		"name": name,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "NAMED_RULE": return TrackerLogicNode.from_dict(vals)
	
	return TrackerLogicNamedRule.new(vals.get("name", ""))
