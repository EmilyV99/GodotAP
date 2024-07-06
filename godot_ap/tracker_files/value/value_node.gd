class_name TrackerValueNode

func calculate() -> Variant:
	return null

func _to_string() -> String:
	return JSON.stringify(_to_dict(), "", false)
func _to_dict() -> Dictionary:
	return {"type": "DEFAULT"}
func _to_json_val() -> Variant:
	return _to_dict()

const DEFAULT_NODE_STRING = "{DEFNODE: DEFAULT}"
static func from_json_val(val: Variant) -> TrackerValueNode:
	if val is Dictionary: return from_dict(val)
	if val is int:
		return TrackerValueInt.from_json_val(val)
	if val is float and Util.approx_eq(val, roundi(val)):
		return TrackerValueInt.from_json_val(roundi(val))
	if val is String:
		return TrackerValueNamed.from_json_val(val)
	return null
static func from_dict(vals: Dictionary) -> TrackerValueNode:
	match vals.get("type"):
		"DEFAULT":
			return TrackerValueNode.new()
		"ITEMCOUNT":
			return TrackerValueItemCount.from_dict(vals)
		"NAMED_VAL":
			return TrackerValueNamed.from_dict(vals)
		"OP":
			return TrackerValueOperator.from_dict(vals)
		"VAR":
			return TrackerValueVariable.from_dict(vals)
		"SWITCH":
			return TrackerValueSwitch.from_dict(vals)
		"SLOT_DATA":
			return TrackerValueSlotData.from_dict(vals)
		"COND":
			return TrackerValueCond.from_dict(vals)
	return null
