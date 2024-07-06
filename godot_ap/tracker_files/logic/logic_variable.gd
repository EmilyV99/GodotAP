class_name TrackerLogicVariable extends TrackerLogicNode

var left_val: TrackerValueNode
var op: String
var right_val: TrackerValueNode

func can_access() -> Variant:
	var curval = left_val.calculate()
	var val = right_val.calculate()
	match op:
		"==":
			return curval == val
		"!=":
			return curval == val
		">":
			if not ((curval is int or curval is float) and (val is int or val is float)): return null
			return curval > val
		"<":
			if not ((curval is int or curval is float) and (val is int or val is float)): return null
			return curval < val
		">=":
			if not ((curval is int or curval is float) and (val is int or val is float)): return null
			return curval >= val
		"<=":
			if not ((curval is int or curval is float) and (val is int or val is float)): return null
			return curval <= val
		_:
			AP.log("Invalid operator '%s'" % op)
			return 0

func _to_dict() -> Dictionary:
	return {
		"type": "VALUE",
		"left": left_val._to_json_val(),
		"op": op,
		"right": right_val._to_json_val(),
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "VALUE": return TrackerLogicNode.from_dict(vals)
	var ret := TrackerLogicVariable.new()
	ret.op = vals.get("op", "")
	ret.left_val = TrackerValueNode.from_json_val(vals.get("left"))
	ret.right_val = TrackerValueNode.from_json_val(vals.get("right"))
	return ret

func get_repr(indent := 0) -> String:
	return "\t".repeat(indent) + "VALUE %s %s %s: %s" % [left_val, op, right_val, can_access()]
