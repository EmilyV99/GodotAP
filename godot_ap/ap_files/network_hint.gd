class_name NetworkHint

enum Status {
	UNSPECIFIED = 0,
	NON_PRIORITY = 10,
	AVOID = 20,
	PRIORITY = 30,

	FOUND = -2, # Special case, not actually a status value but used for the same GUI column
	NOT_FOUND = -1, # Compat, can probaly remove soon
}

static var status_names: Dictionary[Status, String] = {
	Status.FOUND: "Found",
	Status.UNSPECIFIED: "Unspecified",
	Status.NON_PRIORITY: "No Priority",
	Status.AVOID: "Avoid",
	Status.PRIORITY: "Priority",
	Status.NOT_FOUND: "Not Found",
}
static var status_colors: Dictionary[Status, AP.RichColor] = {
	Status.FOUND: AP.RichColor.GREEN,
	Status.UNSPECIFIED: AP.RichColor.NIL,
	Status.NON_PRIORITY: AP.RichColor.SLATEBLUE,
	Status.AVOID: AP.RichColor.SALMON,
	Status.PRIORITY: AP.RichColor.PLUM,
	Status.NOT_FOUND: AP.RichColor.RED,
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

func make_status() -> ConsoleLabel:
	return NetworkHint.make_hint_status(status)

static func make_hint_status(targ_status: Status) -> ConsoleLabel:
	var txt = NetworkHint.status_names.get(targ_status, "Unknown")
	var color: AP.RichColor = NetworkHint.status_colors.get(targ_status, AP.RichColor.RED)
	return BaseConsole.make_text(txt, "", AP.ComplexColor.as_rich(color))

static func update_hint_status(targ_status: Status, part: ConsoleLabel):
	part.text = NetworkHint.status_names.get(targ_status, "Unknown")
	part.rich_color = NetworkHint.status_colors.get(targ_status, AP.RichColor.RED)

func as_plain_string() -> String:
	return "%s %s '%s' (%s) for %s at '%s'" % [
		Archipelago.conn.get_player_name(item.src_player_id),
		"found" if status == Status.FOUND else "will find",
		item.get_name(), item.get_classification(),
		Archipelago.conn.get_player_name(item.dest_player_id),
		Archipelago.conn.get_gamedata_for_player(item.src_player_id).get_loc_name(item.loc_id)
	]

func _to_string():
	return "HINT(%d %d %d %d %d)" % [item.src_player_id,item.id,item.dest_player_id,item.loc_id,status]
