class_name TrackerLogicNamedRule extends TrackerLogicNode

var name: String

func _init(rule_name: String) -> void:
	name = rule_name

func can_access() -> Variant:
	var rule := TrackerTab.get_named_rule(name)
	if not rule: return null
	return rule.can_access()

func _to_json_val() -> Variant:
	return name
func _to_dict() -> Dictionary:
	return {
		"type": "NAMED_RULE",
		"name": name,
	}

static func from_json_val(v: Variant) -> TrackerLogicNode:
	if not v is String: return TrackerLogicNode.from_dict(v)
	return TrackerLogicNamedRule.new(v)
static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "NAMED_RULE": return TrackerLogicNode.from_dict(vals)
	return TrackerLogicNamedRule.new(vals.get("name", ""))
