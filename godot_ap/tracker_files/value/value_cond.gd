class_name TrackerValueCond extends TrackerValueNode

class CondNode:
	var rule: TrackerLogicNode
	var val: TrackerValueNode
	
	static func from_dict(dict: Dictionary) -> CondNode:
		if dict.keys() != ["rule", "val"]:
			return null
		var ret := CondNode.new()
		ret.rule = TrackerLogicNode.from_json_val(dict["rule"])
		ret.val = TrackerValueNode.from_json_val(dict["val"])
		if not (ret.rule and ret.val):
			return null
		return ret
	func _to_dict() -> Dictionary:
		return {
			"rule": rule._to_json_val(),
			"val": val._to_json_val()
		}
	func _to_string() -> String:
		return "{%s -> %s}" % [rule, val]

var vals: Array[CondNode]

func calculate() -> Variant:
	for v in vals:
		if v.rule.can_access():
			return v.val.calculate()
	return null

func _to_dict() -> Dictionary:
	var val_arr = []
	for val in vals:
		val_arr.append(val._to_dict())
	return {
		"type": "COND",
		"values": val_arr
	}

static func from_dict(dict: Dictionary) -> TrackerValueNode:
	if dict.get("type") != "COND": return TrackerValueNode.from_dict(dict)
	var ret := TrackerValueCond.new()
	var arr = dict.get("values")
	if not arr is Array: return null
	for subdict in arr:
		var cond := CondNode.from_dict(subdict)
		if not cond: return null
		ret.vals.append(cond)
	return ret

func _to_string() -> String:
	return "{COND: %s}" % [vals]
