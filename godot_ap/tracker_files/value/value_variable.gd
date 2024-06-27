class_name TrackerValueVariable extends TrackerValueNode

var name: String

func _init(varname: String):
	name = varname

func calculate() -> Variant:
	return TrackerManager.get_variable(name)

func _to_dict() -> Dictionary:
	return {
		"type": "VAR",
		"name": name,
	}

func _to_string() -> String:
	return "{VARIABLE: %s}" % name

static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "VAR": return TrackerValueNode.from_dict(vals)
	return TrackerValueVariable.new(vals.get("name"))
