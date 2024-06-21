class_name TrackerLogicBool extends TrackerLogicNode

var val: bool

func _init(v: bool) -> void:
	val = v

func can_access() -> Variant:
	return val

func _to_json_val() -> Variant:
	return val

func _to_string() -> String:
	return "{%s}" % val

static func from_json_val(v: Variant) -> TrackerLogicNode:
	if not v is bool: return TrackerLogicNode.from_dict(v)
	return TrackerLogicBool.new(v)
