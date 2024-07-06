class_name TrackerValueSwitch extends TrackerValueNode

var keynode: TrackerValueNode
var cases: Dictionary

func calculate() -> Variant:
	var v = keynode.calculate()
	if v is int or v is float: v = str(v)
	var node = cases.get(v)
	if node:
		return node.calculate()
	return null

func _to_dict() -> Dictionary:
	var out_vals := {}
	for k in cases.keys():
		var c = cases[k]
		out_vals[k] = c._to_json_val() if c is TrackerValueNode else c
	return {
		"type": "SWITCH",
		"val": keynode._to_json_val(),
		"cases": out_vals,
	}

static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "SWITCH": return TrackerValueNode.from_dict(vals)
	var ret := TrackerValueSwitch.new()
	ret.keynode = TrackerValueNode.from_json_val(vals.get("val"))
	var dict = vals.get("cases")
	if not dict is Dictionary: return null
	for key in dict.keys():
		var child := TrackerValueNode.from_json_val(dict[key])
		if not child: return null
		ret.cases[key] = child
	return ret

func _to_string() -> String:
	return "{SWITCH: (%s) %s}" % [keynode._to_string(), cases]
