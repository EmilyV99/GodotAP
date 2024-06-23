class_name TrackerLogicAll extends TrackerLogicNode

var rules: Array[TrackerLogicNode] = []

func can_access() -> Variant:
	var ret = true
	for rule in rules:
		var v = rule.can_access()
		if v == null:
			ret = null
		elif not v:
			return false
	return ret

func add(rule: TrackerLogicNode) -> TrackerLogicAll:
	rules.append(rule)
	return self

func _to_dict() -> Dictionary:
	var rule_arr = []
	for rule in rules:
		rule_arr.append(rule._to_json_val())
	return {
		"type": "ALL",
		"rules": rule_arr,
	}

static func from_dict(vals: Dictionary) -> TrackerLogicNode:
	if vals.get("type") != "ALL": return TrackerLogicNode.from_dict(vals)
	var ret := TrackerLogicAll.new()
	for data in vals.get("rules", []):
		var node := TrackerLogicNode.from_json_val(data)
		if node:
			ret.add(node)
	return ret

func get_repr(indent := 0) -> String:
	var s: String = "\t".repeat(indent) + ("ALL: %s" % can_access())
	for r in rules:
		s += "\n" + r.get_repr(indent+1)
	return s
