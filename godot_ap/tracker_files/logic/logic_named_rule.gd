class_name TrackerLogicNamedRule extends TrackerLogicNode

var name: String

func _init(rule_name: String) -> void:
	name = rule_name

func can_access() -> Variant:
	var rule := TrackerManager.get_named_rule(name)
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
	if not v is String: return TrackerLogicNode.from_json_val(v)
	return TrackerLogicNamedRule.new(v)
static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "NAMED_RULE": return TrackerLogicNode.from_dict(vals)
	return TrackerLogicNamedRule.new(vals.get("name", ""))

func get_repr(indent := 0) -> String:
	var rule := TrackerManager.get_named_rule(name)
	if not rule:
		return "\t".repeat(indent) + "ERROR"
	if rule is TrackerLogicNamedRule:
		return rule._get_joint_repr({name: rule}, indent)
	var rule_repr: String = rule.get_repr(indent)
	var name_repr: String = " NAMED '%s'" % name
	var first_nl = rule_repr.find("\n")
	if first_nl < 0:
		return rule_repr + name_repr
	return rule_repr.insert(first_nl, name_repr)

func _get_joint_repr(dict, indent := 0):
	var repeated = name in dict.keys()
	var rule := TrackerManager.get_named_rule(name)
	if rule and not repeated: dict[name] = rule
	var names: Array[String] = []
	names.assign(dict.keys())
	if repeated:
		return "\t".repeat(indent) + "NAMED %s -> SELF-LOOP" % names
	if not rule:
		return "\t".repeat(indent) + "NAMED %s -> ERROR" % names
	if rule is TrackerLogicNamedRule:
		return rule._get_joint_repr(dict, indent)
	var rule_repr: String = rule.get_repr(indent)
	var name_repr: String = " NAMED [%s]" % (", ".join(names))
	var first_nl = rule_repr.find("\n")
	if first_nl < 0:
		return rule_repr + name_repr
	return rule_repr.insert(first_nl, name_repr)
