class_name TrackerLogicBool extends TrackerLogicNode

var val: bool

func _init(v: bool) -> void:
	val = v

func can_access() -> bool:
	return val

func _to_json_val() -> Variant:
	return val

static func from_json_val(v: Variant) -> TrackerLogicNode:
	if v is Dictionary: return TrackerLogicNode.from_dict(v)
	return TrackerLogicBool.new(v)
