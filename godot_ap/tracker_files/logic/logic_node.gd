class_name TrackerLogicNode

func can_access() -> Variant:
	return null

func _to_string() -> String:
	return JSON.stringify(_to_dict(), "", false)
func _to_dict() -> Dictionary:
	return {"type": "DEFAULT"}
func _to_json_val() -> Variant:
	return _to_dict()

static func from_json_val(val: Variant) -> TrackerLogicNode:
	if val is Dictionary: return from_dict(val)
	if val is bool:
		return TrackerLogicBool.from_json_val(val)
	if val is String:
		return TrackerLogicNamedRule.from_json_val(val)
	return null
static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	match vals.get("type"):
		"DEFAULT":
			return TrackerLogicNode.new()
		"ANY":
			return TrackerLogicAny.from_dict(vals)
		"ALL":
			return TrackerLogicAll.from_dict(vals)
		"ITEM":
			return TrackerLogicItem.from_dict(vals)
		"NAMED_RULE":
			return TrackerLogicNamedRule.from_dict(vals)
		"VALUE":
			return TrackerLogicVariable.from_dict(vals)
		"LOCATION_COLLECTED":
			return TrackerLogicLocCollected.from_dict(vals)
	return null

func get_repr(indent := 0) -> String:
	return "\t".repeat(indent) + "DEFAULT: Unknown"
