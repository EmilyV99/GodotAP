class_name TrackerValueNamed extends TrackerValueNode

var name: String

func _init(rule_name: String) -> void:
	name = rule_name

func calculate() -> Variant:
	var val := TrackerManager.get_named_value(name)
	if not val: return null
	return val.calculate()

func _to_json_val() -> Variant:
	return name
func _to_dict() -> Dictionary:
	return {
		"type": "NAMED_RULE",
		"name": name,
	}

func _to_string() -> String:
	return "\"%s\"" % name

static func from_json_val(v: Variant) -> TrackerValueNode:
	if not v is String: return TrackerValueNode.from_json_val(v)
	return TrackerValueNamed.new(v)
static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "NAMED_VAL": return TrackerValueNode.from_dict(vals)
	return TrackerValueNamed.new(vals.get("name", ""))
