class_name NetworkHint
## A hint for an item.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#hint
 
## Priority information for the hint.
enum Status {
	## No priority specified
	UNSPECIFIED = 0,
	## Item is unimportant.
	NON_PRIORITY = 10,
	## Item is detrimental and to be avoided
	AVOID = 20,
	## Item is important and should be prioritized
	PRIORITY = 30,

	## The location has been found.
	FOUND = -2, # Special case, not actually a status value but used for the same GUI column
	NOT_FOUND = -1, # Compat, can probaly remove soon
}


## A mapping of [enum Status] to [String]s for display purposes.
static var status_names: Dictionary[Status, String] = {
	Status.FOUND: "Found",
	Status.UNSPECIFIED: "Unspecified",
	Status.NON_PRIORITY: "No Priority",
	Status.AVOID: "Avoid",
	Status.PRIORITY: "Priority",
	Status.NOT_FOUND: "Not Found",
}


## A mapping of [enum Status] to [enum AP.RichColor] for display purposes.
static var status_colors: Dictionary[Status, AP.RichColor] = {
	Status.FOUND: AP.RichColor.GREEN,
	Status.UNSPECIFIED: AP.RichColor.NIL,
	Status.NON_PRIORITY: AP.RichColor.SLATEBLUE,
	Status.AVOID: AP.RichColor.SALMON,
	Status.PRIORITY: AP.RichColor.PLUM,
	Status.NOT_FOUND: AP.RichColor.RED,
}


## The item that has been hinted.
var item: NetworkItem
## The entrance the item's location is behind.
var entrance: String
## The priority of the hinted item.
var status: Status = Status.NOT_FOUND


## Deserialize a received hint.
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


## Returns [code]true[/code] if [member item] is found in the client's world, and [code]false[/code]
## if it's found in another player's world.
func is_local() -> bool:
	return item.is_local()


## Create a label displaying this object's [member status].
func make_status() -> ConsoleLabel:
	return NetworkHint.make_hint_status(status)


## Create a label displaying the given [enum Status] value.
static func make_hint_status(targ_status: Status) -> ConsoleLabel:
	var txt = NetworkHint.status_names.get(targ_status, "Unknown")
	var color: AP.RichColor = NetworkHint.status_colors.get(targ_status, AP.RichColor.RED)
	return BaseConsole.make_text(txt, "", AP.ComplexColor.as_rich(color))


## Update label [param part] to display a different [enum Status].
static func update_hint_status(targ_status: Status, part: ConsoleLabel):
	part.text = NetworkHint.status_names.get(targ_status, "Unknown")
	part.rich_color = NetworkHint.status_colors.get(targ_status, AP.RichColor.RED)


## Create a plain text description of this hint.
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
