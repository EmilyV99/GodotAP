class_name TrackerLogicLocCollected extends TrackerLogicNode

var identifier ## int id or String name

static func make_id(id: int) -> TrackerLogicLocCollected:
	var ret := TrackerLogicLocCollected.new()
	ret.identifier = id
	return ret
static func make_name(name: String) -> TrackerLogicLocCollected:
	var ret := TrackerLogicLocCollected.new()
	ret.identifier = name
	return ret
static func make(identifier: Variant) -> TrackerLogicLocCollected:
	if identifier is int:
		return make_id(identifier)
	if identifier is String:
		return make_name(identifier)
	return null

func can_access() -> bool:
	var id: int = identifier if identifier is int else Archipelago.conn.get_gamedata_for_player().get_loc_id(identifier)
	return Archipelago.location_checked(id)

func _to_dict() -> Dictionary:
	return {
		"type": "LOCATION_COLLECTED",
		"is_name": not identifier is int,
		"value": identifier,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "LOCATION_COLLECTED": return TrackerLogicNode.from_dict(vals)
	var is_name: bool = vals.get("is_name", true)
	
	var ret := TrackerLogicItem.new()
	if is_name:
		ret.identifier = str(vals.get("value"))
	else:
		ret.identifier = int(vals.get("value"))
		
	return ret
