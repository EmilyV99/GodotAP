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
static func make(iden: Variant) -> TrackerLogicLocCollected:
	if iden is int:
		return make_id(iden)
	if iden is String:
		return make_name(iden)
	return null

func get_id() -> int:
	return identifier if identifier is int else Archipelago.conn.get_gamedata_for_player().get_loc_id(identifier)
func get_name() -> String:
	return identifier if identifier is String else Archipelago.conn.get_gamedata_for_player().get_loc_name(identifier)

func can_access() -> Variant:
	return Archipelago.location_checked(get_id())

func _to_dict() -> Dictionary:
	return {
		"type": "LOCATION_COLLECTED",
		"value": identifier,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "LOCATION_COLLECTED": return TrackerLogicNode.from_dict(vals)
	return make(vals.get("value"))

func get_repr(indent := 0) -> String:
	return "\t".repeat(indent) + "LOCATION_COLLECTED '%s': %s" % [identifier, can_access()]
