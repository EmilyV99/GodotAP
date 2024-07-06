class_name TrackerValueOperator extends TrackerValueNode

var op: String
var values: Array[TrackerValueNode]

func calculate() -> Variant:
	if values.is_empty():
		return 0
	if values.size() == 1:
		return values.back().calculate()
	var v = values.front().calculate()
	if v == null: return null
	for q in range(1,values.size()):
		var op2 = values[q].calculate()
		if op2 == null: return null
		match op:
			"+":
				v += op2
			"-":
				v -= op2
			"*":
				v *= op2
			"/":
				v /= op2
	return v

func _to_dict() -> Dictionary:
	return {
		"type": "OP",
		"op": op,
		"vals": values.map(func(v: TrackerValueNode): return v._to_json_val()),
	}

static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "OP": return TrackerValueNode.from_dict(vals)
	var ret := TrackerValueOperator.new()
	ret.op = vals.get("op", "")
	for subnode in vals.get("vals", []):
		var child := TrackerValueNode.from_json_val(subnode)
		if not child: return null
		ret.values.append(child)
	return ret

func _to_string() -> String:
	return "{OP: %s %s}" % [op, values]
