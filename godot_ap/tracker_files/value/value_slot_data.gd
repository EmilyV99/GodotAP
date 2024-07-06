class_name TrackerValueSlotData extends TrackerValueNode

var keys: Array

func calculate() -> Variant:
	if Archipelago.is_not_connected(): return null
	var data = Archipelago.conn.slot_data
	for k in keys:
		if TrackerPack_Base._check_int(k):
			k = roundi(k)
			if data is Array:
				if data.size() <= k:
					data = null
				else: data = data[k]
			elif data is Dictionary:
				data = data.get(k)
			else: data = null
		elif k is String:
			if data is Dictionary:
				data = data.get(k)
			else: data = null
		else: data = null
		if data == null: break
	return data

func _to_dict() -> Dictionary:
	return {
		"type": "SLOT_DATA",
		"keys": keys,
	}

static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "SLOT_DATA": return TrackerValueNode.from_dict(vals)
	var ret := TrackerValueSlotData.new()
	var arr = vals.get("keys")
	if not arr is Array: return null
	ret.keys = arr.duplicate(true)
	return ret

func _to_string() -> String:
	return "{SLOT_DATA: %s}" % [keys]
