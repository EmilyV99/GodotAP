class_name TrackerValueItemCount extends TrackerValueNode

var identifier ## int id or String name

static func make_id(id: int) -> TrackerValueItemCount:
	var ret := TrackerValueItemCount.new()
	ret.identifier = id
	return ret
static func make_name(name: String) -> TrackerValueItemCount:
	var ret := TrackerValueItemCount.new()
	ret.identifier = name
	return ret
static func make(iden: Variant) -> TrackerValueItemCount:
	if iden is String: return make_name(iden)
	elif iden is int: return make_id(iden)
	return null

func get_id() -> int:
	return identifier if identifier is int else Archipelago.conn.get_gamedata_for_player().get_item_id(identifier)
func get_name() -> String:
	return identifier if identifier is String else Archipelago.conn.get_gamedata_for_player().get_item_name(identifier)

func calculate() -> Variant:
	var id := get_id()
	var found := 0
	for item in Archipelago.conn.received_items:
		if item.id == id:
			found += 1
	return found

func _to_dict() -> Dictionary:
	return {
		"type": "ITEM",
		"name": identifier,
	}

func _to_string() -> String:
	return "{ITEMCOUNT: %s}" % identifier

static func from_dict(vals: Dictionary) -> TrackerValueNode:
	if vals.get("type") != "ITEMCOUNT": return TrackerValueNode.from_dict(vals)
	return make(vals.get("name"))
