class_name TrackerLogicNode

func can_access() -> bool:
	return TrackerTab.default_access

func _to_string() -> String:
	return JSON.stringify(_to_dict(), "", false)
func _to_dict() -> Dictionary:
	return {"type": "DEFAULT"}

const DEFAULT_NODE_STRING = "{DEFNODE: DEFAULT}"
static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	match vals.get("type"):
		"DEFAULT":
			return TrackerLogicNode.new()
		"ANY":
			return TrackerLogicAny.from_dict(vals)
		"ALL":
			return TrackerLogicAll.from_dict(vals)
		"ITEM":
			return TrackerLogicItem.from_dict(vals)
		"NAMED_RULE":
			return TrackerLogicNamedRule.from_dict(vals)
	return null
