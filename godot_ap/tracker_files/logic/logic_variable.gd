class_name TrackerLogicVariable extends TrackerLogicNode

var iden: String
var op: String
var val: Variant

func _init(name: String, operator: String, value: Variant) -> void:
	iden = name
	op = operator
	val = value

func can_access() -> Variant:
	var curval = TrackerManager.variables.get(iden)
	if curval is String:
		match op:
			"==":
				return curval == str(val)
			_: AP.log("Invalid operator '%s' on type String" % op)
	elif curval is int or curval is float:
		var fl := curval is float or val is float
		match op:
			"==":
				return Util.approx_eq(curval, val) if fl else (curval == val)
			"!=":
				return not Util.approx_eq(curval, val) if fl else (curval == val)
			">":
				return curval > val
			"<":
				return curval < val
			">=":
				return curval >= val
			"<=":
				return curval <= val
			_: AP.log("Invalid operator '%s' on type int/float" % op)
	else:
		AP.log("Bad variable datatype '%s'" % typeof(curval))
	return null

func _to_dict() -> Dictionary:
	return {
		"type": "VAR",
		"name": iden,
		"op": op,
		"value": val,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "VAR": return TrackerLogicNode.from_dict(vals)
	
	return TrackerLogicVariable.new(str(vals.get("name")), vals.get("op", "NULL"), vals.get("value"))

func get_repr(indent := 0) -> String:
	return "\t".repeat(indent) + "VAR '%s' %s %s: %s" % [iden, op, val, can_access()]
