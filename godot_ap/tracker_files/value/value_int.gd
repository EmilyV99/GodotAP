class_name TrackerValueInt extends TrackerValueNode

var val: int

func _init(v: int) -> void:
	val = v

func calculate() -> Variant:
	return val

func _to_json_val() -> Variant:
	return val

func _to_string() -> String:
	return str(val)

static func from_json_val(v: Variant) -> TrackerValueNode:
	if not TrackerPack_Base._check_int(v): return TrackerValueNode.from_json_val(v)
	return TrackerValueInt.new(roundi(v))
