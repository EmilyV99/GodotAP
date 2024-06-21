class_name TrackerLogicItem extends TrackerLogicNode

var identifier ## int id or String name
var count := 1

static func make_id(id: int, item_count := 1) -> TrackerLogicItem:
	var ret := TrackerLogicItem.new()
	ret.identifier = id
	ret.count = item_count
	return ret
static func make_name(name: String, item_count := 1) -> TrackerLogicItem:
	var ret := TrackerLogicItem.new()
	ret.identifier = name
	ret.count = item_count
	return ret

func can_access() -> bool:
	var id: int = identifier if identifier is int else Archipelago.conn.get_gamedata_for_player().get_item_id(identifier)
	var found := 0
	for item in Archipelago.conn.received_items:
		if item.id == id:
			found += 1
			if found >= count:
				return true
	return false

func _to_dict() -> Dictionary:
	return {
		"type": "ITEM",
		"is_name": not identifier is int,
		"count": count,
		"value": identifier,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "ITEM": return TrackerLogicNode.from_dict(vals)
	var is_name: bool = vals.get("is_name", true)
	
	var ret := TrackerLogicItem.new()
	if is_name:
		ret.identifier = str(vals.get("value"))
	else:
		ret.identifier = int(vals.get("value"))
	ret.count = vals.get("count", 1)
		
	return ret
