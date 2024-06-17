class_name NetworkHint

enum Status {
	FOUND = 0,
	UNSPECIFIED = 1,
	NON_PRIORITY = 10,
	AVOID = 20,
	PRIORITY = 30,
	NOT_FOUND = 9999999, # Deprecated by new hint status code, still supported for now
}

static var status_names: Dictionary = {
	Status.FOUND: "Found",
	Status.UNSPECIFIED: "Unspecified",
	Status.NON_PRIORITY: "No Priority",
	Status.AVOID: "Avoid",
	Status.PRIORITY: "Priority",
	Status.NOT_FOUND: "Not Found",
}
static var status_colors: Dictionary = {
	Status.FOUND: "green",
	Status.UNSPECIFIED: "white",
	Status.NON_PRIORITY: "slateblue",
	Status.AVOID: "salmon",
	Status.PRIORITY: "plum",
	Status.NOT_FOUND: "red",
}

var item: NetworkItem
var entrance: String
var status: Status = Status.NOT_FOUND

static func from(json: Dictionary) -> NetworkHint:
	if json["class"] != "Hint":
		return null
	var hint := NetworkHint.new()
	hint.item = NetworkItem.from_hint(json)
	if json.get("found", false):
		hint.status = Status.FOUND
	else:
		hint.status = json.get("status", Status.NOT_FOUND)
	hint.entrance = json.get("entrance", "")
	return hint
	
func is_local() -> bool:
	return item.is_local()

func make_status(c: BaseConsole) -> BaseConsole.CenterTextPart:
	var txt = NetworkHint.status_names.get(status, "Unknown")
	var colname = NetworkHint.status_colors.get(status, "red")
	return c.make_text(txt, "", Archipelago.rich_colors[colname])


func _to_string():
	return "%d %d %d %d %d" % [item.src_player_id,item.id,item.dest_player_id,item.loc_id,status]
