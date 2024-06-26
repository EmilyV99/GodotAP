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
static func make(iden: Variant, item_count := 1) -> TrackerLogicItem:
	if iden is String: return make_name(iden, item_count)
	elif iden is int: return make_id(iden, item_count)
	return null

func get_id() -> int:
	return identifier if identifier is int else Archipelago.conn.get_gamedata_for_player().get_item_id(identifier)
func get_name() -> String:
	return identifier if identifier is String else Archipelago.conn.get_gamedata_for_player().get_item_name(identifier)

func can_access() -> Variant:
	var id := get_id()
	var found := 0
	for item in Archipelago.conn.received_items:
		if item.id == id:
			found += 1
			if found >= count:
				return true
	return false

func _to_dict() -> Dictionary:
	var data := {
		"type": "ITEM",
		"value": identifier,
	}
	if count != 1:
		data["count"] = count
	return data

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "ITEM": return TrackerLogicNode.from_dict(vals)
	return make(vals.get("value"), vals.get("count", 1))

func get_repr(indent := 0) -> String:
	return "\t".repeat(indent) + "ITEM '%s' x%d: %s" % [identifier, count, can_access()]
